<#
.SYNOPSIS
    Editor Parse Check - Forces Godot to recompile ALL scripts and detects parse/type errors + warnings.
.DESCRIPTION
    Launches Godot in --editor --headless --quit mode, which forces a full project scan.
    Then parses godot.log for errors and warnings that appeared during this load.
    Errors: "Could not find type", "Parse Error", etc. => FAIL (exit 1)
    Warnings: "Integer division", "unused variable", etc. => WARN (exit 0 by default)
    Use --strict to make warnings fatal (exit 1).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/validate_editor_parse.ps1
    powershell -ExecutionPolicy Bypass -File tools/validate_editor_parse.ps1 --strict
#>

param(
    [switch]$strict
)

$ErrorActionPreference = "Continue"

$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"
$TimeoutSec = 45
$ProjectPath = Split-Path $PSScriptRoot -Parent

function Write-OK   { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Err  { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }

function Get-ProjectName {
    $projFile = Join-Path $ProjectPath "project.godot"
    if (Test-Path $projFile) {
        $content = Get-Content $projFile -Raw
        if ($content -match 'config/name="([^"]+)"') {
            return $matches[1]
        }
    }
    return "Unknown"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EDITOR PARSE CHECK" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $GodotExe)) {
    Write-Err "  Godot executable not found: $GodotExe"
    exit 1
}
Write-Info "  Godot: $GodotExe"

$projectName = Get-ProjectName
$logFolder = Join-Path $env:APPDATA "Godot\app_userdata\$projectName\logs"
$logFile = Join-Path $logFolder "godot.log"
Write-Info "  Project: $projectName"
Write-Info "  Log: $logFile"

# Record log size BEFORE running Godot (so we only read NEW lines)
$logLinesBefore = 0
if (Test-Path $logFile) {
    $logLinesBefore = (Get-Content $logFile -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
}

Write-Host ""
Write-Info "  Launching Godot editor (headless) to recompile all scripts..."
Write-Host ""

# Launch Godot in editor + headless + quit mode
$stderrFile = Join-Path $env:TEMP "godot_editor_parse_stderr.txt"
$stdoutFile = Join-Path $env:TEMP "godot_editor_parse_stdout.txt"

$proc = Start-Process -FilePath $GodotExe `
    -ArgumentList "--path `"$ProjectPath`" --editor --headless --quit" `
    -PassThru -NoNewWindow `
    -RedirectStandardError $stderrFile `
    -RedirectStandardOutput $stdoutFile

try {
    $proc | Wait-Process -Timeout $TimeoutSec -ErrorAction Stop
} catch {
    Write-Warn "  Godot did not exit within ${TimeoutSec}s - killing process"
    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

Start-Sleep -Milliseconds 1000

# Error patterns (FATAL)
$errorPatterns = @(
    'Parse Error:',
    'Could not find type',
    'not declared in the current scope',
    'Failed to load script.*with error',
    'Cannot infer the type',
    'SCRIPT ERROR:'
)
$errorPattern = ($errorPatterns -join '|')

# Warning patterns (non-fatal unless --strict)
$warningPatterns = @(
    'Integer division',
    'is declared but never used',
    'is never used in the function',
    'Unused signal',
    'Return value.*discarded',
    'Narrowing conversion',
    'standalone expression'
)
$warningPattern = ($warningPatterns -join '|')

$errors = @()
$warnings = @()

# Helper: classify a line as error, warning, or neither
function Classify-Line {
    param($line, $source)
    if ($line -match $errorPattern) {
        $script:errors += ($source + $line.Trim())
    }
    elseif ($line -match $warningPattern) {
        $script:warnings += ($source + $line.Trim())
    }
}

# 1. Parse NEW lines from godot.log
if (Test-Path $logFile) {
    $allLines = Get-Content $logFile -ErrorAction SilentlyContinue
    $newLines = @()
    if ($allLines.Count -gt $logLinesBefore) {
        $newLines = $allLines[$logLinesBefore..($allLines.Count - 1)]
    }

    foreach ($line in $newLines) {
        Classify-Line $line ""
    }

    Write-Host "  Log lines analyzed: $($newLines.Count) new (of $($allLines.Count) total)"
} else {
    Write-Warn "  Log file not found"
}

# 2. Check stderr output
if (Test-Path $stderrFile) {
    $stderrContent = Get-Content $stderrFile -ErrorAction SilentlyContinue
    foreach ($line in $stderrContent) {
        Classify-Line $line ""
    }
}

# 3. Check stdout output
if (Test-Path $stdoutFile) {
    $stdoutContent = Get-Content $stdoutFile -ErrorAction SilentlyContinue
    foreach ($line in $stdoutContent) {
        Classify-Line $line ""
    }
}

# Deduplicate
$uniqueErrors = $errors | Select-Object -Unique
$uniqueWarnings = $warnings | Select-Object -Unique

# Report
Write-Host ""

$hasErrors = ($uniqueErrors.Count -gt 0)
$hasWarnings = ($uniqueWarnings.Count -gt 0)

if ($hasErrors) {
    Write-Host "========================================" -ForegroundColor Red
    $msg = "  EDITOR PARSE CHECK: FAILED - " + $uniqueErrors.Count.ToString() + " error(s)"
    Write-Err $msg
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    foreach ($err in $uniqueErrors) {
        Write-Err ("  > " + $err)
    }
    Write-Host ""
    Write-Warn "  Fix these errors before committing."
    Write-Warn "  Common causes:"
    Write-Warn "    - Missing .uid file for new scripts (run editor once)"
    Write-Warn "    - Typo in type reference or class_name"
    Write-Host ""
}

if ($hasWarnings) {
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    $msg = "  WARNINGS: " + $uniqueWarnings.Count.ToString() + " warning(s)"
    Write-Warn $msg
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    foreach ($w in $uniqueWarnings) {
        Write-Warn ("  ~ " + $w)
    }
    Write-Host ""
    if ($strict) {
        Write-Warn "  --strict mode: warnings treated as errors"
    } else {
        Write-Info "  Tip: use --strict to make warnings fatal"
    }
    Write-Host ""
}

if (-not $hasErrors -and -not $hasWarnings) {
    Write-Host "========================================" -ForegroundColor Green
    Write-OK "  EDITOR PARSE CHECK: PASSED (0 errors, 0 warnings)"
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    exit 0
}
elseif (-not $hasErrors -and $hasWarnings -and -not $strict) {
    Write-Host "========================================" -ForegroundColor Green
    Write-OK "  EDITOR PARSE CHECK: PASSED (with warnings)"
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    # Errors found, or --strict with warnings
    exit 1
}
