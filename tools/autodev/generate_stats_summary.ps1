# generate_stats_summary.ps1
# AUTODEV Testing Infrastructure
# Purpose: Generate stats_summary.json with coverage, performance, and Triade state metrics
# Created: 2026-02-22 by AUTODEV Testing Worker

param(
    [string]$OutputDir = "$PSScriptRoot\status\reviews\testing",
    [int]$Cycle = 1
)

$ErrorActionPreference = "Continue"

Write-Host "=== AUTODEV Stats Summary Generator ===" -ForegroundColor Cyan
Write-Host "Cycle: $Cycle" -ForegroundColor Yellow

# Initialize stats object
$stats = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    cycle = $Cycle
    coverage = @{
        unit_tests = "0%"
        integration_tests = "0%"
        e2e_tests = "0%"
        overall = "0%"
        lines_covered = 0
        lines_total = 0
    }
    performance = @{
        llm_latency_avg_ms = $null
        llm_latency_p95_ms = $null
        json_parse_success_rate = $null
        prefetch_hit_rate = $null
        fps_min = $null
        fps_avg = $null
        memory_peak_mb = $null
        scene_transition_avg_ms = $null
    }
    triade_coverage = @{
        aspect_states_tested = 0
        total_combinations = 343
        coverage_percentage = 0.0
        endings_tested = 0
        total_endings = 16
        fall_endings_tested = 0
        victory_endings_tested = 0
        secret_ending_tested = $false
    }
    edge_cases = @{
        total = 10
        tested = 0
        passed = 0
        failed = 0
        coverage_percentage = 0.0
    }
    test_execution = @{
        total_duration_seconds = 0
        slowest_test = $null
        fastest_test = $null
    }
}

# Function: Parse GUT test results (if available)
function Parse-GutResults {
    param([string]$GutLogPath)

    if (-not (Test-Path $GutLogPath)) {
        Write-Host "[GUT] GUT log not found (framework not installed)" -ForegroundColor Yellow
        return
    }

    Write-Host "[GUT] Parsing GUT test results..." -ForegroundColor Gray
    $content = Get-Content $GutLogPath -Raw

    # Extract coverage percentage (if GUT coverage plugin installed)
    if ($content -match "Total Coverage:\s+(\d+\.?\d*)%") {
        $stats.coverage.overall = "$($Matches[1])%"
        $stats.coverage.unit_tests = "$($Matches[1])%"
    }

    # Extract test counts
    if ($content -match "(\d+)\s+tests\s+passed") {
        $passed = [int]$Matches[1]
    }
    if ($content -match "(\d+)\s+tests\s+failed") {
        $failed = [int]$Matches[1]
    }

    Write-Host "[GUT] Found $passed passed, $failed failed" -ForegroundColor Gray
}

# Function: Parse LLM performance logs
function Parse-LlmPerformance {
    param([string]$LogDir)

    # Look for LLM performance logs in data/ai/logs/ or similar
    $llmLogs = Get-ChildItem -Path "$LogDir\data\ai\logs\" -Filter "llm_*.log" -ErrorAction SilentlyContinue

    if ($llmLogs.Count -eq 0) {
        Write-Host "[LLM] No LLM performance logs found" -ForegroundColor Yellow
        return
    }

    Write-Host "[LLM] Parsing LLM performance logs..." -ForegroundColor Gray
    $latencies = @()

    foreach ($log in $llmLogs) {
        $content = Get-Content $log.FullName -Raw
        # Look for latency metrics (format: "LLM latency: 2345ms")
        $matches = [regex]::Matches($content, "latency:\s+(\d+)ms")
        foreach ($match in $matches) {
            $latencies += [int]$match.Groups[1].Value
        }
    }

    if ($latencies.Count -gt 0) {
        $stats.performance.llm_latency_avg_ms = ($latencies | Measure-Object -Average).Average
        $stats.performance.llm_latency_p95_ms = ($latencies | Sort-Object)[[math]::Floor($latencies.Count * 0.95)]
        Write-Host "[LLM] Avg latency: $($stats.performance.llm_latency_avg_ms)ms" -ForegroundColor Gray
    }
}

# Function: Parse Triade state coverage from MerlinStore logs
function Parse-TriadeCoverage {
    param([string]$LogDir)

    # Look for Triade state tracking logs
    $triadeLogs = Get-ChildItem -Path "$LogDir\data\ai\logs\" -Filter "triade_*.log" -ErrorAction SilentlyContinue

    if ($triadeLogs.Count -eq 0) {
        Write-Host "[TRIADE] No Triade state logs found (tracking not implemented)" -ForegroundColor Yellow
        return
    }

    Write-Host "[TRIADE] Parsing Triade state coverage..." -ForegroundColor Gray
    $uniqueStates = @{}

    foreach ($log in $triadeLogs) {
        $content = Get-Content $log.FullName
        foreach ($line in $content) {
            # Format: "TRIADE: corps=1, ame=-2, monde=0"
            if ($line -match "corps=(-?\d+).*ame=(-?\d+).*monde=(-?\d+)") {
                $state = "$($Matches[1]),$($Matches[2]),$($Matches[3])"
                $uniqueStates[$state] = $true
            }
        }
    }

    $stats.triade_coverage.aspect_states_tested = $uniqueStates.Count
    $stats.triade_coverage.coverage_percentage = [math]::Round(($uniqueStates.Count / 343.0) * 100, 2)
    Write-Host "[TRIADE] Unique states: $($uniqueStates.Count)/343" -ForegroundColor Gray
}

# Function: Count GDScript lines for coverage denominator
function Count-GdScriptLines {
    param([string]$ScriptsDir)

    $totalLines = 0
    $gdFiles = Get-ChildItem -Path $ScriptsDir -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $gdFiles) {
        $lines = (Get-Content $file.FullName -ErrorAction SilentlyContinue).Count
        $totalLines += $lines
    }

    $stats.coverage.lines_total = $totalLines
    Write-Host "[COVERAGE] Total GDScript lines: $totalLines" -ForegroundColor Gray
}

# Execute parsers
Write-Host "`n=== Gathering Stats ===" -ForegroundColor Cyan

# GUT results
Parse-GutResults -GutLogPath "$PSScriptRoot\..\..\.gut\results.log"

# LLM performance
Parse-LlmPerformance -LogDir "$PSScriptRoot\..\.."

# Triade coverage
Parse-TriadeCoverage -LogDir "$PSScriptRoot\..\.."

# GDScript lines
Count-GdScriptLines -ScriptsDir "$PSScriptRoot\..\..\scripts"

# Placeholder values for not-yet-implemented metrics
Write-Host "`n[INFO] Some metrics are null (not yet tracked):" -ForegroundColor Yellow
Write-Host "  - JSON parse success rate (requires LLM logging)" -ForegroundColor Gray
Write-Host "  - Prefetch hit rate (requires LLM logging)" -ForegroundColor Gray
Write-Host "  - FPS metrics (requires profiler integration)" -ForegroundColor Gray
Write-Host "  - Memory usage (requires profiler integration)" -ForegroundColor Gray

# Save stats to JSON
Write-Host "`n=== Saving Stats ===" -ForegroundColor Cyan
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$statsJson = $stats | ConvertTo-Json -Depth 10
$statsJson | Set-Content -Path "$OutputDir\stats_summary.json" -Encoding UTF8

Write-Host "✅ Stats saved to: $OutputDir\stats_summary.json" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Overall Coverage: $($stats.coverage.overall)" -ForegroundColor White
Write-Host "  Triade States Tested: $($stats.triade_coverage.aspect_states_tested)/343" -ForegroundColor White
Write-Host "  Endings Tested: $($stats.triade_coverage.endings_tested)/16" -ForegroundColor White
Write-Host "  LLM Avg Latency: $($stats.performance.llm_latency_avg_ms)ms" -ForegroundColor White

exit 0
