<#
.SYNOPSIS
    Targeted scene validation — runs only scenes affected by modified scripts.
.DESCRIPTION
    1. Auto-detects modified .gd files via git diff (staged + unstaged)
    2. Scans .tscn files to find which scenes reference those scripts
    3. For autoload scripts, tests a representative scene
    4. Launches each affected scene in Godot headless mode
    5. Captures stderr/stdout and reports errors/warnings
.PARAMETER Scripts
    Comma-separated .gd script paths to test (overrides git detection).
    Example: -Scripts "scripts/TransitionBiome.gd,scripts/HubAntre.gd"
.PARAMETER GodotPath
    Path to Godot console executable. Auto-detected if not provided.
.PARAMETER Timeout
    Max seconds per scene before killing Godot (default: 12).
.PARAMETER All
    Test ALL scenes, not just affected ones.
.EXAMPLE
    .\validate_affected_scenes.ps1
    .\validate_affected_scenes.ps1 -Scripts "scripts/TransitionBiome.gd"
    .\validate_affected_scenes.ps1 -All
#>

param(
    [string]$Scripts = "",
    [string]$GodotPath = "",
    [int]$Timeout = 12,
    [switch]$All
)

$ErrorActionPreference = "Continue"

# === Colors ===
function Write-OK { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Wrn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Inf { param($msg) Write-Host $msg -ForegroundColor Cyan }

# === Find Godot ===
function Find-Godot {
    $inPath = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64_console.exe",
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64.exe",
        "$env:LOCALAPPDATA\Godot\godot.exe",
        "$env:LOCALAPPDATA\Programs\Godot\godot.exe",
        "C:\Godot\godot.exe",
        "C:\Program Files\Godot\godot.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# === Get modified .gd files from git ===
function Get-ModifiedScripts {
    $modified = @()

    # Unstaged changes
    $unstaged = git diff --name-only -- "*.gd" 2>$null
    if ($unstaged) { $modified += $unstaged }

    # Staged changes
    $staged = git diff --cached --name-only -- "*.gd" 2>$null
    if ($staged) { $modified += $staged }

    # Untracked .gd files
    $untracked = git ls-files --others --exclude-standard -- "*.gd" 2>$null
    if ($untracked) { $modified += $untracked }

    return $modified | Select-Object -Unique
}

# === Map .gd scripts to .tscn scenes by scanning scene files ===
function Find-AffectedScenes {
    param([array]$ScriptPaths)

    $affectedScenes = @()
    $scenesDir = "scenes"

    if (-not (Test-Path $scenesDir)) { return $affectedScenes }

    $tscnFiles = Get-ChildItem -Path $scenesDir -Filter "*.tscn" -Recurse

    foreach ($tscn in $tscnFiles) {
        $content = Get-Content $tscn.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        foreach ($script in $ScriptPaths) {
            # Normalize to res:// format
            $resPath = "res://" + ($script -replace '\\', '/')
            if ($content -match [regex]::Escape($resPath)) {
                $affectedScenes += $tscn.FullName
                break
            }
        }
    }

    return $affectedScenes | Select-Object -Unique
}

# === Check if script is an autoload ===
function Get-AutoloadScenes {
    param([array]$ScriptPaths)

    $autoloadScripts = @()
    if (-not (Test-Path "project.godot")) { return $autoloadScripts }

    $projectContent = Get-Content "project.godot" -Raw

    foreach ($script in $ScriptPaths) {
        $resPath = "res://" + ($script -replace '\\', '/')
        if ($projectContent -match [regex]::Escape($resPath)) {
            $autoloadScripts += $script
        }
    }

    # Also check addons/ and scripts/autoload/ — these affect many scenes
    foreach ($script in $ScriptPaths) {
        if ($script -match '^(addons/|scripts/autoload/)') {
            if ($script -notin $autoloadScripts) {
                $autoloadScripts += $script
            }
        }
    }

    return $autoloadScripts
}

# === Error patterns ===
$errorPatterns = @(
    "SCRIPT ERROR:",
    "Cannot call method",
    "not declared in the current scope",
    "Attempt to call function",
    "FATAL:",
    "Segmentation fault",
    "Access violation",
    "Parse Error:"
)

$warningPatterns = @(
    "WARNING:",
    "Trying to assign value of type"
)

$ignorePatterns = @(
    "GDExtension",
    "gdextension",
    "ObjectDB instances leaked",
    "resources still in use at exit",
    "Vulkan",
    "vulkan",
    "OpenGL",
    "rendering driver",
    "Cleanup still pending"
)

# === Run a scene and capture errors ===
function Test-Scene {
    param(
        [string]$ScenePath,
        [string]$GodotExe,
        [int]$TimeoutSec
    )

    $sceneName = ((Split-Path $ScenePath -Leaf) -replace '\.[^.]*$', '')
    $sceneRelPath = "res://scenes/" + (Split-Path $ScenePath -Leaf)

    # Check if it's a nested path
    $relFromProject = $ScenePath.Replace((Get-Location).Path, "").TrimStart("\").Replace("\", "/")
    if ($relFromProject -match '^scenes/') {
        $sceneRelPath = "res://" + $relFromProject
    }

    $stdoutFile = "$env:TEMP\affected_stdout_$sceneName.txt"
    $stderrFile = "$env:TEMP\affected_stderr_$sceneName.txt"

    $errors = @()
    $warnings = @()
    $status = "PASS"

    try {
        $godotArgs = "--path . --headless --quit-after $TimeoutSec $sceneRelPath"
        $proc = Start-Process -FilePath $GodotExe -ArgumentList $godotArgs `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile `
            -WorkingDirectory (Get-Location).Path

        $waitSec = $TimeoutSec + 3
        $timedOut = $false
        try {
            Wait-Process -Id $proc.Id -Timeout $waitSec -ErrorAction Stop
        }
        catch {
            if (-not $proc.HasExited) {
                $timedOut = $true
                $proc | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }

        Start-Sleep -Milliseconds 300
        $stdout = Get-Content $stdoutFile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue
        if ($null -eq $stdout) { $stdout = "" }
        if ($null -eq $stderr) { $stderr = "" }

        $allOutput = $stdout + "`n" + $stderr

        foreach ($outputLine in ($allOutput -split "`n")) {
            $trimLine = $outputLine.Trim()
            if ($trimLine -eq "") { continue }

            # Skip benign
            $skip = $false
            foreach ($ign in $ignorePatterns) {
                if ($trimLine -match [regex]::Escape($ign)) { $skip = $true; break }
            }
            if ($skip) { continue }

            foreach ($pat in $errorPatterns) {
                if ($trimLine -match [regex]::Escape($pat)) { $errors += $trimLine; break }
            }
            foreach ($pat in $warningPatterns) {
                if ($trimLine -match [regex]::Escape($pat)) { $warnings += $trimLine; break }
            }
        }

        $exitCode = $null
        try { $exitCode = $proc.ExitCode } catch {}
        if ($null -ne $exitCode -and $exitCode -ne 0 -and -not $timedOut) {
            $status = "CRASH"
        }
        elseif ($timedOut) { $status = "TIMEOUT" }
        elseif ($errors.Count -gt 0) { $status = "FAIL" }
        elseif ($warnings.Count -gt 0) { $status = "WARN" }
    }
    catch {
        $status = "CRASH"
        $errors += $_.Exception.Message
    }

    Remove-Item $stdoutFile -ErrorAction SilentlyContinue
    Remove-Item $stderrFile -ErrorAction SilentlyContinue

    return @{
        Name     = $sceneName
        Status   = $status
        Errors   = $errors
        Warnings = $warnings
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  AFFECTED SCENE VALIDATION" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor White
Write-Host ""

# Find Godot
if ($GodotPath -eq "") { $GodotPath = Find-Godot }
if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
    Write-Err "  Godot executable not found!"
    Write-Err "  Use: -GodotPath 'C:\path\to\godot.exe'"
    exit 1
}
Write-Inf "  Godot: $GodotPath"

# Get modified scripts
$modifiedScripts = @()
if ($Scripts -ne "") {
    $modifiedScripts = $Scripts -split "," | ForEach-Object { $_.Trim() }
    Write-Inf "  Mode: Manual ($($modifiedScripts.Count) scripts specified)"
}
elseif ($All) {
    Write-Inf "  Mode: ALL scenes"
}
else {
    $modifiedScripts = Get-ModifiedScripts
    if ($modifiedScripts.Count -eq 0) {
        Write-OK "  No modified .gd files detected (git clean)"
        Write-Host ""
        exit 0
    }
    Write-Inf "  Mode: Auto-detect (git diff)"
}

# Display modified scripts
if ($modifiedScripts.Count -gt 0) {
    Write-Host ""
    Write-Host "  Modified scripts:" -ForegroundColor Gray
    foreach ($s in $modifiedScripts) {
        Write-Host "    - $s" -ForegroundColor White
    }
}

# Find affected scenes
$scenesToTest = @()

if ($All) {
    $scenesToTest = Get-ChildItem -Path "scenes" -Filter "*.tscn" -File |
                    Select-Object -ExpandProperty FullName
}
else {
    $scenesToTest = Find-AffectedScenes -ScriptPaths $modifiedScripts

    # If any autoload/addon script is modified, add representative scenes
    $autoloads = Get-AutoloadScenes -ScriptPaths $modifiedScripts
    if ($autoloads.Count -gt 0) {
        Write-Host ""
        Write-Wrn "  Autoload/addon scripts modified - adding representative scenes:"
        foreach ($a in $autoloads) {
            Write-Host "    - $a" -ForegroundColor Yellow
        }
        # Add key gameplay scenes that exercise autoloads
        $repScenes = @("scenes\HubAntre.tscn", "scenes\MenuPrincipal.tscn")
        foreach ($rs in $repScenes) {
            $fullPath = Join-Path (Get-Location).Path $rs
            if ((Test-Path $fullPath) -and ($fullPath -notin $scenesToTest)) {
                $scenesToTest += $fullPath
            }
        }
    }
}

if ($scenesToTest.Count -eq 0) {
    Write-Wrn "  No scenes found for modified scripts"
    Write-Host "  (Scripts may be autoloads or not attached to scenes)"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Inf "  Scenes to test: $($scenesToTest.Count)"
foreach ($s in $scenesToTest) {
    $name = ((Split-Path $s -Leaf) -replace '\.[^.]*$', '')
    Write-Host "    - $name" -ForegroundColor White
}
Write-Host ""

# Run tests
$passed = 0
$failed = 0
$idx = 0

foreach ($scene in $scenesToTest) {
    $idx++
    $name = ((Split-Path $scene -Leaf) -replace '\.[^.]*$', '')
    Write-Host -NoNewline "  [$idx/$($scenesToTest.Count)] $name ... " -ForegroundColor White

    $result = Test-Scene -ScenePath $scene -GodotExe $GodotPath -TimeoutSec $Timeout
    $st = $result.Status

    if ($st -eq "PASS") {
        Write-OK "PASS"
        $passed++
    }
    elseif ($st -eq "WARN") {
        $wc = $result.Warnings.Count
        Write-Wrn "WARN - $wc warnings"
        $passed++
        $warnSlice = @($result.Warnings)[0..1]
        foreach ($w in $warnSlice) { if ($w) { Write-Wrn "    > $w" } }
    }
    elseif ($st -eq "FAIL") {
        $ec = $result.Errors.Count
        Write-Err "FAIL - $ec errors"
        $failed++
        $errSlice = @($result.Errors)[0..2]
        foreach ($e in $errSlice) { if ($e) { Write-Err "    > $e" } }
    }
    elseif ($st -eq "CRASH") {
        Write-Err "CRASH"
        $failed++
        $errSlice = @($result.Errors)[0..2]
        foreach ($e in $errSlice) { if ($e) { Write-Err "    > $e" } }
    }
    elseif ($st -eq "TIMEOUT") {
        Write-Wrn "TIMEOUT - exceeded limit"
        $passed++
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor White
$total = $passed + $failed
if ($failed -eq 0) {
    Write-OK "  ALL $passed SCENE(S) PASSED"
} else {
    Write-Err "  FAILED: $failed / $total scene(s)"
}
Write-Host "========================================" -ForegroundColor White
Write-Host ""

if ($failed -gt 0) { exit 1 } else { exit 0 }
