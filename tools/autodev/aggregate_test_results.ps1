# aggregate_test_results.ps1
# AUTODEV Testing Infrastructure
# Purpose: Parse validation script outputs and generate test_results.json
# Created: 2026-02-22 by AUTODEV Testing Worker

param(
    [string]$OutputDir = "$PSScriptRoot\status\reviews\testing",
    [int]$Cycle = 1
)

$ErrorActionPreference = "Continue"

Write-Host "=== AUTODEV Test Result Aggregator ===" -ForegroundColor Cyan
Write-Host "Cycle: $Cycle" -ForegroundColor Yellow
Write-Host "Output: $OutputDir\test_results.json" -ForegroundColor Yellow

# Initialize result object
$results = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    cycle = $Cycle
    total_tests = 0
    passed = 0
    failed = 0
    skipped = 0
    failures = @()
    domains = @{
        parse = @{ passed = 0; failed = 0; errors = @() }
        flow_order = @{ passed = 0; failed = 0; errors = @() }
        smoke = @{ passed = 0; failed = 0; errors = @() }
        unit = @{ passed = 0; failed = 0; errors = @() }
        integration = @{ passed = 0; failed = 0; errors = @() }
    }
    validation_scripts_executed = @()
}

# Function: Parse validate_editor_parse.ps1 output
function Parse-EditorParseLog {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) {
        Write-Host "[PARSE] Log not found: $LogFile" -ForegroundColor Yellow
        return
    }

    Write-Host "[PARSE] Parsing $LogFile..." -ForegroundColor Gray
    $content = Get-Content $LogFile -Raw

    # Look for BLOCKING errors
    $blockingMatches = [regex]::Matches($content, "BLOCKING.*?ERROR.*?res://([^\s]+\.gd):(\d+)")
    foreach ($match in $blockingMatches) {
        $results.domains.parse.failed++
        $results.failures += @{
            domain = "parse"
            severity = "BLOCKING"
            file = $match.Groups[1].Value
            line = [int]$match.Groups[2].Value
            message = $match.Value
        }
    }

    # Look for parse success indicators
    if ($content -match "0 BLOCKING") {
        $results.domains.parse.passed++
    }

    $results.validation_scripts_executed += "validate_editor_parse.ps1"
}

# Function: Parse validate_flow_order.ps1 output
function Parse-FlowOrderLog {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) {
        Write-Host "[FLOW] Log not found: $LogFile" -ForegroundColor Yellow
        return
    }

    Write-Host "[FLOW] Parsing $LogFile..." -ForegroundColor Gray
    $content = Get-Content $LogFile -Raw

    # Count scenes tested
    $sceneMatches = [regex]::Matches($content, "Testing scene \d+/\d+: (.+?\.tscn)")
    foreach ($match in $sceneMatches) {
        $results.total_tests++
    }

    # Look for ERROR indicators
    $errorMatches = [regex]::Matches($content, "ERROR.*?res://([^\s]+\.gd):(\d+)")
    foreach ($match in $errorMatches) {
        $results.domains.flow_order.failed++
        $results.failures += @{
            domain = "flow_order"
            severity = "HIGH"
            file = $match.Groups[1].Value
            line = [int]$match.Groups[2].Value
            message = $match.Value
        }
    }

    # Look for success indicators
    if ($content -match "All scenes validated successfully") {
        $results.domains.flow_order.passed = $sceneMatches.Count
    } else {
        $results.domains.flow_order.passed = $sceneMatches.Count - $errorMatches.Count
    }

    $results.validation_scripts_executed += "validate_flow_order.ps1"
}

# Function: Parse smoke_test_scenes.ps1 output
function Parse-SmokeTestLog {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) {
        Write-Host "[SMOKE] Log not found: $LogFile" -ForegroundColor Yellow
        return
    }

    Write-Host "[SMOKE] Parsing $LogFile..." -ForegroundColor Gray
    $content = Get-Content $LogFile -Raw

    # Similar pattern to flow order
    $sceneMatches = [regex]::Matches($content, "Testing scene: (.+?\.tscn)")
    $results.total_tests += $sceneMatches.Count

    $errorMatches = [regex]::Matches($content, "ERROR")
    $results.domains.smoke.failed = $errorMatches.Count
    $results.domains.smoke.passed = $sceneMatches.Count - $errorMatches.Count

    $results.validation_scripts_executed += "smoke_test_scenes.ps1"
}

# Execute validation scripts and capture output
Write-Host "`n=== Executing Validation Scripts ===" -ForegroundColor Cyan

# 1. Editor Parse Validation
$parseLog = "$PSScriptRoot\logs\parse_cycle_$Cycle.log"
if (Test-Path "$PSScriptRoot\validate_editor_parse.ps1") {
    Write-Host "[EXEC] Running validate_editor_parse.ps1..." -ForegroundColor Green
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\validate_editor_parse.ps1" > $parseLog 2>&1
    Parse-EditorParseLog -LogFile $parseLog
} else {
    Write-Host "[SKIP] validate_editor_parse.ps1 not found" -ForegroundColor Yellow
}

# 2. Flow Order Validation
$flowLog = "$PSScriptRoot\logs\flow_cycle_$Cycle.log"
if (Test-Path "$PSScriptRoot\validate_flow_order.ps1") {
    Write-Host "[EXEC] Running validate_flow_order.ps1..." -ForegroundColor Green
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\validate_flow_order.ps1" > $flowLog 2>&1
    Parse-FlowOrderLog -LogFile $flowLog
} else {
    Write-Host "[SKIP] validate_flow_order.ps1 not found" -ForegroundColor Yellow
}

# 3. Smoke Tests
$smokeLog = "$PSScriptRoot\logs\smoke_cycle_$Cycle.log"
if (Test-Path "$PSScriptRoot\smoke_test_scenes.ps1") {
    Write-Host "[EXEC] Running smoke_test_scenes.ps1..." -ForegroundColor Green
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\smoke_test_scenes.ps1" > $smokeLog 2>&1
    Parse-SmokeTestLog -LogFile $smokeLog
} else {
    Write-Host "[SKIP] smoke_test_scenes.ps1 not found" -ForegroundColor Yellow
}

# Calculate totals
$results.passed = $results.domains.parse.passed + $results.domains.flow_order.passed + $results.domains.smoke.passed
$results.failed = $results.domains.parse.failed + $results.domains.flow_order.failed + $results.domains.smoke.failed

# Save results to JSON
Write-Host "`n=== Saving Results ===" -ForegroundColor Cyan
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$resultsJson = $results | ConvertTo-Json -Depth 10
$resultsJson | Set-Content -Path "$OutputDir\test_results.json" -Encoding UTF8

Write-Host "✅ Results saved to: $OutputDir\test_results.json" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total Tests: $($results.total_tests)" -ForegroundColor White
Write-Host "  Passed: $($results.passed)" -ForegroundColor Green
Write-Host "  Failed: $($results.failed)" -ForegroundColor Red
Write-Host "  Failures: $($results.failures.Count)" -ForegroundColor Yellow

exit 0
