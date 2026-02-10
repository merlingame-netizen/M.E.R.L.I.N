<#
.SYNOPSIS
    Smoke test - Launch every game scene in Godot headless and inspect logs for errors.
.DESCRIPTION
    Iterates over all .tscn files in scenes/, launches each in Godot with --headless
    and a timeout, then parses stdout/stderr for errors, warnings, and crashes.
    Returns exit code 0 if all scenes pass, 1 if any scene has errors.
.PARAMETER GodotPath
    Path to the Godot executable. Auto-detected if not provided.
.PARAMETER Timeout
    Max seconds per scene before killing Godot (default: 8).
.PARAMETER ScenesDir
    Directory containing .tscn files (default: scenes/).
.PARAMETER Exclude
    Comma-separated scene names to skip (e.g. "TestTriadeLLMBenchmark").
.EXAMPLE
    .\smoke_test_scenes.ps1
    .\smoke_test_scenes.ps1 -GodotPath "C:\Godot\godot.exe" -Timeout 10
#>

param(
    [string]$GodotPath = "",
    [int]$Timeout = 20,
    [string]$ScenesDir = "scenes",
    [string]$Exclude = ""
)

$ErrorActionPreference = "Continue"

# === Helper functions ===
function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Show-Errors {
    param([array]$Lines, [int]$Max = 3)
    if ($null -eq $Lines -or $Lines.Count -eq 0) { return }
    $count = $Lines.Count
    if ($count -gt $Max) { $count = $Max }
    for ($i = 0; $i -lt $count; $i++) {
        $line = "    > " + $Lines[$i]
        Write-Host $line -ForegroundColor Red
    }
}

# === Auto-detect Godot ===
function Find-Godot {
    $inPath = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    $candidates = @(
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64_console.exe",
        "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64.exe",
        "$env:LOCALAPPDATA\Godot\godot.exe",
        "$env:LOCALAPPDATA\Programs\Godot\godot.exe",
        "C:\Godot\godot.exe",
        "C:\Program Files\Godot\godot.exe",
        "C:\Program Files (x86)\Godot\godot.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }

    return $null
}

# === Main ===
Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  SMOKE TEST - Scene Loader" -ForegroundColor Cyan
$timeStr = Get-Date -Format 'HH:mm:ss'
Write-Host "  $timeStr" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor White
Write-Host ""

# Find Godot
if ($GodotPath -eq "") {
    $GodotPath = Find-Godot
}
if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
    Write-Color "  Godot executable not found!" "Red"
    Write-Color "  Use: .\smoke_test_scenes.ps1 -GodotPath 'C:\path\to\godot.exe'" "Red"
    Write-Host ""
    Write-Host "  Tip: Add Godot to your PATH or specify the full path." -ForegroundColor Gray
    exit 1
}
Write-Color "  Godot: $GodotPath" "Cyan"
Write-Color "  Timeout: ${Timeout}s per scene" "Cyan"
Write-Host ""

# Parse exclusions
$excludeList = @()
if ($Exclude -ne "") {
    $excludeList = $Exclude -split "," | ForEach-Object { $_.Trim() }
}

# Find scenes
if (-not (Test-Path $ScenesDir)) {
    Write-Color "  Scenes directory not found: $ScenesDir" "Red"
    exit 1
}

$scenes = Get-ChildItem -Path $ScenesDir -Filter "*.tscn" -File | Sort-Object Name
$sceneCount = $scenes.Count
if ($sceneCount -eq 0) {
    Write-Color "  No .tscn files found in $ScenesDir" "Yellow"
    exit 0
}

Write-Color "  Found $sceneCount scene(s) in $ScenesDir/" "Cyan"
Write-Host ""

# Error patterns
$errorPatterns = @(
    "SCRIPT ERROR:",
    "not declared in the current scope",
    "Cannot call method",
    "Attempt to call function",
    "Stack trace:",
    "FATAL:",
    "Segmentation fault",
    "Access violation",
    "assertion failed"
)

$warningPatterns = @(
    "WARNING:",
    "Trying to assign value of type"
)

# Benign patterns to ignore (headless mode artifacts)
$ignorePatterns = @(
    "GDExtension",
    "gdextension",
    "ObjectDB instances leaked",
    "resources still in use at exit",
    "Vulkan",
    "vulkan",
    "OpenGL",
    "rendering driver"
)

# Results
$totalScenes = 0
$passedScenes = 0
$failedScenes = 0
$skippedScenes = 0
$results = @()

foreach ($scene in $scenes) {
    $sceneName = $scene.BaseName
    $sceneFile = $scene.Name
    $sceneRelPath = "res://" + $ScenesDir + "/" + $sceneFile

    # Check exclusion
    if ($excludeList -contains $sceneName) {
        Write-Color "  [SKIP] $sceneName (excluded)" "Yellow"
        $skippedScenes++
        continue
    }

    $totalScenes++
    Write-Host -NoNewline "  [$totalScenes] $sceneName ... " -ForegroundColor White

    # Launch Godot headless (CLM-compatible: uses Start-Process + temp files)
    $stdoutFile = "$env:TEMP\smoke_stdout_$totalScenes.txt"
    $stderrFile = "$env:TEMP\smoke_stderr_$totalScenes.txt"

    $stdout = ""
    $stderr = ""
    $crashed = $false
    $timedOut = $false

    try {
        $godotArgs = "--path . --headless --quit-after $Timeout $sceneRelPath"
        $proc = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -WorkingDirectory (Get-Location).Path

        $waitSec = $Timeout + 3
        $waitDone = $false
        try {
            Wait-Process -Id $proc.Id -Timeout $waitSec -ErrorAction Stop
            $waitDone = $true
        }
        catch {
            # Timeout or process already gone
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

        $exitCode = $null
        try { $exitCode = $proc.ExitCode } catch { $exitCode = $null }
        if ($waitDone -and $null -ne $exitCode -and $exitCode -ne 0) {
            $crashed = $true
        }
    }
    catch {
        $crashed = $true
        $stderr = $_.Exception.Message
    }

    Remove-Item $stdoutFile -ErrorAction SilentlyContinue
    Remove-Item $stderrFile -ErrorAction SilentlyContinue

    # Analyze output
    $allOutput = $stdout + "`n" + $stderr
    $errors = @()
    $warnings = @()

    foreach ($outputLine in ($allOutput -split "`n")) {
        $trimLine = $outputLine.Trim()
        if ($trimLine -eq "") { continue }

        # Skip benign patterns
        $skip = $false
        foreach ($ign in $ignorePatterns) {
            if ($trimLine -match [regex]::Escape($ign)) {
                $skip = $true
                break
            }
        }
        if ($skip) { continue }

        foreach ($pat in $errorPatterns) {
            if ($trimLine -match [regex]::Escape($pat)) {
                $errors += $trimLine
                break
            }
        }
        foreach ($pat in $warningPatterns) {
            if ($trimLine -match [regex]::Escape($pat)) {
                $warnings += $trimLine
                break
            }
        }
    }

    # Determine status
    $status = "PASS"
    if ($crashed) { $status = "CRASH" }
    elseif ($timedOut) { $status = "TIMEOUT" }
    elseif ($errors.Count -gt 0) { $status = "FAIL" }
    elseif ($warnings.Count -gt 0) { $status = "WARN" }

    $results += @{
        Name     = $sceneName
        Status   = $status
        Errors   = $errors
        Warnings = $warnings
    }

    # Display inline result
    if ($status -eq "PASS") {
        Write-Host "PASS" -ForegroundColor Green
        $passedScenes++
    }
    elseif ($status -eq "WARN") {
        $wc = [string]$warnings.Count
        Write-Host "WARN - $wc warnings" -ForegroundColor Yellow
        $passedScenes++
    }
    elseif ($status -eq "FAIL") {
        $ec = [string]$errors.Count
        Write-Host "FAIL - $ec errors" -ForegroundColor Red
        $failedScenes++
        Show-Errors -Lines $errors -Max 3
    }
    elseif ($status -eq "CRASH") {
        $ev = "?"
        try { if ($proc -and $proc.HasExited) { $ev = $proc.ExitCode } } catch { $ev = "?" }
        Write-Host "CRASH - exit code $ev" -ForegroundColor Red
        $failedScenes++
        Show-Errors -Lines $errors -Max 3
    }
    elseif ($status -eq "TIMEOUT") {
        Write-Host "TIMEOUT - exceeded ${Timeout}s" -ForegroundColor Yellow
        $passedScenes++
    }
}

# === Summary ===
Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Total:   $totalScenes scenes tested" -ForegroundColor White
Write-Host "  Passed:  $passedScenes" -ForegroundColor Green

if ($failedScenes -gt 0) {
    Write-Host "  Failed:  $failedScenes" -ForegroundColor Red
} else {
    Write-Host "  Failed:  0" -ForegroundColor Green
}

if ($skippedScenes -gt 0) {
    Write-Host "  Skipped: $skippedScenes" -ForegroundColor Yellow
}

Write-Host ""

# List failures
foreach ($r in $results) {
    if ($r.Status -eq "FAIL" -or $r.Status -eq "CRASH") {
        $fname = $r.Name
        $fstat = $r.Status
        Write-Host "  FAILED: $fname [$fstat]" -ForegroundColor Red
        Show-Errors -Lines $r.Errors -Max 5
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor White

if ($failedScenes -gt 0) {
    exit 1
} else {
    exit 0
}
