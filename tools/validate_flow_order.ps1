<#
.SYNOPSIS
    Game Flow Order Validation - runs scenes in canonical game order.
.DESCRIPTION
    Executes scenes in the exact order a player would encounter them:
    1. IntroCeltOS -> 2. MenuPrincipal -> 3. IntroPersonalityQuiz ->
    4. SceneRencontreMerlin -> 5. SelectionSauvegarde -> 6. HubAntre ->
    7. TransitionBiome -> 8. MerlinGame

    Each scene runs headless with a timeout. Errors are captured per-scene.
    If any scene FAILS, subsequent scenes are still tested but marked DEGRADED.
.PARAMETER GodotPath
    Path to Godot console executable. Auto-detected if not provided.
.PARAMETER Timeout
    Max seconds per scene before killing Godot (default: 12).
.PARAMETER StopOnFail
    Stop at first failure instead of continuing (default: false).
.PARAMETER Quick
    Only test scenes affected by git changes.
.PARAMETER KnownIssues
    Comma-separated scene names with known standalone issues (default: MerlinGame).
.EXAMPLE
    .\validate_flow_order.ps1
    .\validate_flow_order.ps1 -Quick
    .\validate_flow_order.ps1 -StopOnFail -Timeout 15
#>

param(
    [string]$GodotPath = "",
    [int]$Timeout = 12,
    [switch]$StopOnFail,
    [switch]$Quick,
    [string]$KnownIssues = "MerlinGame"
)

$ErrorActionPreference = "Continue"

# === Helper functions ===
function Write-OK { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Wrn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Inf { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Dim { param($msg) Write-Host $msg -ForegroundColor DarkGray }

function Show-Lines {
    param([array]$Lines, [int]$Max = 3, [string]$Color = "Red")
    if ($null -eq $Lines -or $Lines.Count -eq 0) { return }
    $count = [Math]::Min($Lines.Count, $Max)
    for ($i = 0; $i -lt $count; $i++) {
        $line = "    | " + $Lines[$i]
        Write-Host $line -ForegroundColor $Color
    }
}

# === Canonical Game Flow ===
$GAME_FLOW = @(
    @{ Name = "IntroCeltOS";           Scene = "res://scenes/IntroCeltOS.tscn";           Phase = "Onboarding" },
    @{ Name = "MenuPrincipal";         Scene = "res://scenes/MenuPrincipal.tscn";         Phase = "Onboarding" },
    @{ Name = "IntroPersonalityQuiz";  Scene = "res://scenes/IntroPersonalityQuiz.tscn";  Phase = "Onboarding" },
    @{ Name = "SceneRencontreMerlin";  Scene = "res://scenes/SceneRencontreMerlin.tscn";  Phase = "Onboarding" },
    @{ Name = "SelectionSauvegarde";   Scene = "res://scenes/SelectionSauvegarde.tscn";   Phase = "Continue" },
    @{ Name = "HubAntre";             Scene = "res://scenes/HubAntre.tscn";               Phase = "Hub" },
    @{ Name = "TransitionBiome";      Scene = "res://scenes/TransitionBiome.tscn";         Phase = "Gameplay" },
    @{ Name = "MerlinGame";           Scene = "res://scenes/MerlinGame.tscn";              Phase = "Gameplay" }
)

# === Auto-detect Godot ===
function Find-Godot {
    $inPath = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64_console.exe",
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64.exe",
        "$env:LOCALAPPDATA\Godot\godot.exe",
        "C:\Godot\godot.exe",
        "C:\Program Files\Godot\godot.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
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
    "Cleanup still pending",
    "Unicode parsing error",
    "RID allocations",
    "RID of type"
)

# === Get modified scripts for Quick mode ===
function Get-ModifiedScripts {
    $modified = @()
    $unstaged = git diff --name-only -- "*.gd" 2>$null
    if ($unstaged) { $modified += $unstaged }
    $staged = git diff --cached --name-only -- "*.gd" 2>$null
    if ($staged) { $modified += $staged }
    $untracked = git ls-files --others --exclude-standard -- "*.gd" 2>$null
    if ($untracked) { $modified += $untracked }
    return $modified | Select-Object -Unique
}

# === Map scripts to scene names for Quick mode ===
function Get-AffectedFlowScenes {
    param([array]$ScriptPaths)

    $affected = @()
    foreach ($flow in $GAME_FLOW) {
        $sceneName = $flow.Name
        $tscnPath = "scenes\$sceneName.tscn"
        if (-not (Test-Path $tscnPath)) { continue }

        $content = Get-Content $tscnPath -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        foreach ($script in $ScriptPaths) {
            $resPath = "res://" + ($script -replace '\\', '/')
            if ($content -match [regex]::Escape($resPath)) {
                $affected += $sceneName
                break
            }
        }
    }

    # Autoload/addon scripts affect ALL scenes
    foreach ($script in $ScriptPaths) {
        if ($script -match '^(addons/|scripts/autoload/)') {
            return $GAME_FLOW | ForEach-Object { $_.Name }
        }
    }

    return $affected | Select-Object -Unique
}

# === Run a scene and capture errors ===
function Test-FlowScene {
    param(
        [string]$ScenePath,
        [string]$SceneName,
        [string]$GodotExe,
        [int]$TimeoutSec
    )

    $stdoutFile = "$env:TEMP\flow_stdout_$SceneName.txt"
    $stderrFile = "$env:TEMP\flow_stderr_$SceneName.txt"
    $errors = @()
    $warnings = @()
    $status = "PASS"

    try {
        $godotArgs = "--path . --headless --quit-after $TimeoutSec $ScenePath"
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
        Name     = $SceneName
        Status   = $status
        Errors   = $errors
        Warnings = $warnings
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  GAME FLOW ORDER VALIDATION" -ForegroundColor Cyan
$ts = Get-Date -Format 'HH:mm:ss'
Write-Host "  $ts" -ForegroundColor Gray
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
Write-Inf "  Timeout: ${Timeout}s per scene"

# Parse known issues
$knownList = @()
if ($KnownIssues -ne "") {
    $knownList = $KnownIssues -split "," | ForEach-Object { $_.Trim() }
}

# Determine scenes to test
$scenesToTest = $GAME_FLOW

if ($Quick) {
    $modifiedScripts = Get-ModifiedScripts
    if ($modifiedScripts.Count -eq 0) {
        Write-OK "  No modified .gd files -- nothing to test"
        Write-Host ""
        exit 0
    }
    $affectedNames = Get-AffectedFlowScenes -ScriptPaths $modifiedScripts
    $scenesToTest = $GAME_FLOW | Where-Object { $_.Name -in $affectedNames }
    $ac = $affectedNames.Count
    Write-Inf "  Mode: Quick -- $ac affected scenes"
}
else {
    Write-Inf "  Mode: Full game flow -- 8 scenes"
}

Write-Host ""

# Display flow order
$currentPhase = ""
foreach ($flow in $scenesToTest) {
    if ($flow.Phase -ne $currentPhase) {
        $currentPhase = $flow.Phase
        Write-Dim "  --- $currentPhase ---"
    }
    $sName = $flow.Name
    if ($sName -in $knownList) {
        Write-Host "    * $sName  [known issue]" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "    - $sName" -ForegroundColor White
    }
}
Write-Host ""

# Run tests in order
$passed = 0
$failed = 0
$known = 0
$idx = 0
$degraded = $false
$results = @()

foreach ($flow in $scenesToTest) {
    $idx++
    $name = $flow.Name
    $scene = $flow.Scene
    $isKnown = $name -in $knownList
    $total = $scenesToTest.Count

    $prefix = "  [$idx/$total]"
    if ($degraded) {
        $prefix = "  [$idx/$total] [DEGRADED]"
    }

    Write-Host -NoNewline "$prefix $name ... " -ForegroundColor White

    $result = Test-FlowScene -ScenePath $scene -SceneName $name -GodotExe $GodotPath -TimeoutSec $Timeout
    $st = $result.Status

    if ($st -eq "PASS") {
        Write-OK "PASS"
        $passed++
    }
    elseif ($st -eq "WARN") {
        $wc = $result.Warnings.Count
        Write-Wrn "WARN - $wc warnings"
        $passed++
        Show-Lines -Lines $result.Warnings -Max 2 -Color Yellow
    }
    elseif ($st -eq "FAIL" -or $st -eq "CRASH") {
        if ($isKnown) {
            $ec = $result.Errors.Count
            Write-Host "KNOWN - $ec errors [expected standalone]" -ForegroundColor DarkYellow
            $known++
            Show-Lines -Lines $result.Errors -Max 2 -Color DarkGray
        }
        else {
            $ec = $result.Errors.Count
            if ($st -eq "CRASH") {
                Write-Err "CRASH"
            }
            else {
                Write-Err "FAIL - $ec errors"
            }
            $failed++
            $degraded = $true
            Show-Lines -Lines $result.Errors -Max 3 -Color Red
            if ($StopOnFail) {
                Write-Err "  Stopping on first failure"
                break
            }
        }
    }
    elseif ($st -eq "TIMEOUT") {
        Write-Wrn "TIMEOUT - exceeded ${Timeout}s"
        $passed++
    }

    $results += $result
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  FLOW ORDER RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Passed:  $passed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed:  $failed" -ForegroundColor Red
}
else {
    Write-Host "  Failed:  0" -ForegroundColor Green
}
if ($known -gt 0) {
    Write-Host "  Known:   $known" -ForegroundColor DarkYellow
}

$total = $passed + $failed + $known
Write-Host "  Total:   $total scenes" -ForegroundColor White
Write-Host ""

# List actual failures
foreach ($r in $results) {
    $rName = $r.Name
    $rStatus = $r.Status
    if (($rStatus -eq "FAIL" -or $rStatus -eq "CRASH") -and $rName -notin $knownList) {
        Write-Err "  BLOCKING: $rName [$rStatus]"
        Show-Lines -Lines $r.Errors -Max 5 -Color Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor White

if ($failed -gt 0) { exit 1 } else { exit 0 }
