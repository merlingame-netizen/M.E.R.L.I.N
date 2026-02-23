# generate_test_results.ps1
# AUTODEV Testing Infrastructure - Step 0 (Editor Parse Check) Aggregator
# Purpose: Run validate.bat Step 0 and parse output to JSON format
# ConstrainedLanguage compatible: no [math]::, no .Substring(), uses -like/-replace
# Created: 2026-02-23 by AUTODEV ui-ux worker

param(
    [string]$OutputFile = "$PSScriptRoot\status\test_results.json"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AUTODEV Test Results Aggregator" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$validateScript = Join-Path $projectRoot "tools\validate_editor_parse.ps1"
$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"

if (-not (Test-Path $validateScript)) {
    Write-Host "[ERROR] validate_editor_parse.ps1 not found at: $validateScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $GodotExe)) {
    Write-Host "[ERROR] Godot executable not found: $GodotExe" -ForegroundColor Red
    exit 1
}

# Get project name for log path
function Get-ProjectName {
    $projFile = Join-Path $projectRoot "project.godot"
    if (Test-Path $projFile) {
        $content = Get-Content $projFile -Raw
        if ($content -match 'config/name="([^"]+)"') {
            return $matches[1]
        }
    }
    return "Unknown"
}

$projectName = Get-ProjectName
$logFolder = Join-Path $env:APPDATA "Godot\app_userdata\$projectName\logs"
$logFile = Join-Path $logFolder "godot.log"

Write-Host "[INFO] Project: $projectName" -ForegroundColor Cyan
Write-Host "[INFO] Validation script: $validateScript" -ForegroundColor Cyan
Write-Host "[INFO] Log file: $logFile" -ForegroundColor Cyan
Write-Host ""

# Record log size before execution
$logLinesBefore = 0
if (Test-Path $logFile) {
    $allLogLines = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($allLogLines) {
        $logLinesBefore = $allLogLines.Count
    }
}

# Launch validate_editor_parse.ps1
Write-Host "[EXEC] Running validate.bat Step 0 (Editor Parse Check)..." -ForegroundColor Green
$tempLog = Join-Path $env:TEMP "autodev_validate_step0.log"

$proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$validateScript`"" `
    -NoNewWindow -PassThru -Wait `
    -RedirectStandardOutput $tempLog `
    -RedirectStandardError "$tempLog.err"

$exitCode = $proc.ExitCode
Write-Host "[EXEC] Validation exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })

# Parse output and log file
$errors = @()
$warnings = @()
$filesChecked = 0

# Error patterns (FATAL)
$errorPatterns = @(
    'Parse Error:',
    'Could not find type',
    'not declared in the current scope',
    'Failed to load script.*with error',
    'Cannot infer the type',
    'SCRIPT ERROR:'
)

# Warning patterns
$warningPatterns = @(
    'Integer division',
    'is declared but never used',
    'is never used in the function',
    'Unused signal',
    'Return value.*discarded',
    'Narrowing conversion',
    'standalone expression'
)

# Function: Check if line matches error patterns
function Test-IsError {
    param([string]$Line)
    foreach ($pattern in $errorPatterns) {
        if ($Line -like "*$pattern*") { return $true }
    }
    return $false
}

# Function: Check if line matches warning patterns
function Test-IsWarning {
    param([string]$Line)
    foreach ($pattern in $warningPatterns) {
        if ($Line -like "*$pattern*") { return $true }
    }
    return $false
}

# Function: Extract file path from error line (ConstrainedLanguage safe)
function Get-FilePath {
    param([string]$Line)
    if ($Line -match 'res://([^:\s]+\.gd)') {
        return $matches[1]
    }
    return ""
}

# Parse validation output
if (Test-Path $tempLog) {
    $outputLines = Get-Content $tempLog -ErrorAction SilentlyContinue
    foreach ($line in $outputLines) {
        if (Test-IsError $line) {
            $filePath = Get-FilePath $line
            $errors += @{
                file = $filePath
                message = $line.Trim()
                severity = "BLOCKING"
            }
        }
        elseif (Test-IsWarning $line) {
            $filePath = Get-FilePath $line
            $warnings += @{
                file = $filePath
                message = $line.Trim()
                severity = "WARNING"
            }
        }

        # Count files checked (line contains "Log lines analyzed")
        if ($line -like "*Log lines analyzed:*") {
            $match = [regex]::Match($line, '(\d+) new')
            if ($match.Success) {
                $filesChecked = [int]$match.Groups[1].Value
            }
        }
    }
}

# Parse NEW lines from godot.log (only lines added during this run)
if (Test-Path $logFile) {
    $allLogLines = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($allLogLines -and ($allLogLines.Count -gt $logLinesBefore)) {
        $newLogLines = $allLogLines[$logLinesBefore..($allLogLines.Count - 1)]

        foreach ($line in $newLogLines) {
            if (Test-IsError $line) {
                $filePath = Get-FilePath $line
                $errors += @{
                    file = $filePath
                    message = $line.Trim()
                    severity = "BLOCKING"
                }
            }
            elseif (Test-IsWarning $line) {
                $filePath = Get-FilePath $line
                $warnings += @{
                    file = $filePath
                    message = $line.Trim()
                    severity = "WARNING"
                }
            }
        }
    }
}

# Deduplicate errors and warnings using unique messages
$uniqueErrors = @()
$seenErrorMessages = @{}
foreach ($err in $errors) {
    $msg = $err.message
    if (-not $seenErrorMessages.ContainsKey($msg)) {
        $seenErrorMessages[$msg] = $true
        $uniqueErrors += $err
    }
}

$uniqueWarnings = @()
$seenWarningMessages = @{}
foreach ($warn in $warnings) {
    $msg = $warn.message
    if (-not $seenWarningMessages.ContainsKey($msg)) {
        $seenWarningMessages[$msg] = $true
        $uniqueWarnings += $warn
    }
}

# Build result object
$result = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    step = "validate.bat Step 0 (Editor Parse Check)"
    exit_code = $exitCode
    total_errors = $uniqueErrors.Count
    total_warnings = $uniqueWarnings.Count
    files_checked = $filesChecked
    errors = $uniqueErrors
    warnings = $uniqueWarnings
    validation_passed = ($exitCode -eq 0)
}

# Create output directory if needed
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

# Write JSON (ConstrainedLanguage safe - using ConvertTo-Json)
$jsonContent = $result | ConvertTo-Json -Depth 10
$jsonContent | Set-Content -Path $OutputFile -Encoding UTF8

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Errors:   $($uniqueErrors.Count)" -ForegroundColor $(if ($uniqueErrors.Count -gt 0) { "Red" } else { "Green" })
Write-Host "  Total Warnings: $($uniqueWarnings.Count)" -ForegroundColor $(if ($uniqueWarnings.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Files Checked:  $filesChecked" -ForegroundColor Cyan
Write-Host "  Exit Code:      $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
Write-Host "  Output:         $OutputFile" -ForegroundColor Cyan
Write-Host ""

if ($uniqueErrors.Count -gt 0) {
    Write-Host "ERRORS:" -ForegroundColor Red
    foreach ($err in $uniqueErrors) {
        Write-Host "  - $($err.file): $($err.message)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($uniqueWarnings.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($warn in $uniqueWarnings) {
        Write-Host "  - $($warn.file): $($warn.message)" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($exitCode -eq 0 -and $uniqueErrors.Count -eq 0) {
    Write-Host "✅ VALIDATION PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ VALIDATION FAILED" -ForegroundColor Red
}

Write-Host ""
exit $exitCode
