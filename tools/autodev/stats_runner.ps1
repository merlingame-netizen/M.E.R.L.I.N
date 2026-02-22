# stats_runner.ps1 -- AUTODEV v2: Batch auto-play runs for statistical testing
# Usage: .\stats_runner.ps1 [-NumRuns 3] [-Cycle 1] [-OutputDir path]
#
# Runs the auto_play_runner N times with different strategies,
# collects JSON results, then runs batch_autoplay.gd to aggregate.

param(
    [int]$NumRuns = 3,
    [int]$Cycle = 0,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$configPath = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir = Join-Path $scriptDir "status"

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$godotExe = $config.godot_exe

if (-not $OutputDir) {
    $OutputDir = Join-Path $scriptDir "stats"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Results directory for this cycle
$cycleResultsDir = Join-Path $OutputDir "cycle_$Cycle"
if (-not (Test-Path $cycleResultsDir)) {
    New-Item -ItemType Directory -Path $cycleResultsDir -Force | Out-Null
}

# Strategies to test (rotate through)
$strategies = @("MIXED", "ALWAYS_LEFT", "ALWAYS_RIGHT")

# Validation mutex
$mutexFile = Join-Path $statusDir ".validate_mutex"

function Acquire-Mutex {
    $waited = 0
    while ((Test-Path $mutexFile) -and $waited -lt 300) {
        Write-Host "[STATS] Waiting for Godot mutex..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $waited += 10
    }
    if (Test-Path $mutexFile) {
        Write-Host "[STATS] WARN: Stale mutex, removing" -ForegroundColor Yellow
        Remove-Item $mutexFile -Force
    }
    @{ domain = "stats_runner"; timestamp = (Get-Date -Format "o") } |
        ConvertTo-Json | Set-Content $mutexFile -Encoding UTF8
}

function Release-Mutex {
    if (Test-Path $mutexFile) { Remove-Item $mutexFile -Force }
}

# Godot user data path
$godotUserDir = Join-Path $env:APPDATA "Godot/app_userdata/DRU"
if (-not (Test-Path $godotUserDir)) {
    $godotUserDir = Join-Path $env:APPDATA "Godot/app_userdata/M.E.R.L.I.N."
}

Write-Host "[STATS] ================================================" -ForegroundColor Cyan
Write-Host "[STATS]   AUTODEV Stats Runner" -ForegroundColor Cyan
Write-Host "[STATS]   Runs: $NumRuns | Cycle: $Cycle" -ForegroundColor Cyan
Write-Host "[STATS]   Strategies: $($strategies -join ', ')" -ForegroundColor Cyan
Write-Host "[STATS] ================================================" -ForegroundColor Cyan

$runResults = @()
$totalStartTime = Get-Date

Acquire-Mutex

try {
    for ($i = 0; $i -lt $NumRuns; $i++) {
        $strategyIndex = $i % $strategies.Count
        $strategy = $strategies[$strategyIndex]
        $runNum = $i + 1

        Write-Host "`n[STATS] Run $runNum/$NumRuns (strategy: $strategy)..." -ForegroundColor Green

        # Write autoplay config for this run
        $autoplayConfig = @{
            strategy    = $strategy
            output_path = "user://autoplay_results.json"
        } | ConvertTo-Json
        $autoplayConfigPath = Join-Path $godotUserDir "autoplay_config.json"

        $configDir = Split-Path $autoplayConfigPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $autoplayConfig | Set-Content $autoplayConfigPath -Encoding UTF8

        # Launch auto-play in headless mode
        $runStartTime = Get-Date
        $godotArgs = @(
            "--path", $projectRoot,
            "--headless",
            "--quit-after", "600",
            "res://scenes/TestAutoPlay.tscn"
        )

        $proc = Start-Process -FilePath $godotExe -ArgumentList $godotArgs `
            -WindowStyle Hidden -PassThru

        # Wait with timeout (10 min per run)
        $timeoutMs = 600000
        $exited = $proc.WaitForExit($timeoutMs)

        if (-not $exited) {
            Write-Host "[STATS]   TIMEOUT on run $runNum" -ForegroundColor Red
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }

        $runElapsed = ((Get-Date) - $runStartTime).TotalSeconds

        # Collect results
        $resultsFile = Join-Path $godotUserDir "autoplay_results.json"
        $runResult = @{
            run_number = $runNum
            strategy   = $strategy
            status     = "failed"
            elapsed_s  = [math]::Round($runElapsed, 1)
        }

        if (Test-Path $resultsFile) {
            $resultData = Get-Content $resultsFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($resultData) {
                # Save individual run result
                $runFileName = "run_${runNum}_${strategy}.json"
                $runFilePath = Join-Path $cycleResultsDir $runFileName
                Get-Content $resultsFile -Raw | Set-Content $runFilePath -Encoding UTF8

                $runResult.status = "ok"
                $runResult.cards_played = $resultData.cards_played
                $runResult.ending_type = $resultData.ending_type
                $runResult.output_file = $runFilePath

                Write-Host "[STATS]   OK: $($resultData.cards_played) cards, ending=$($resultData.ending_type), ${runElapsed}s" -ForegroundColor Green
            } else {
                Write-Host "[STATS]   FAIL: Invalid JSON in results" -ForegroundColor Red
            }
            Remove-Item $resultsFile -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "[STATS]   FAIL: No results file produced" -ForegroundColor Red
        }

        $runResults += $runResult

        # Check VETO between runs
        if (Test-Path (Join-Path $scriptDir "VETO")) {
            Write-Host "[STATS] VETO detected -- stopping stats runner" -ForegroundColor Red
            break
        }

        # Brief pause between runs
        Start-Sleep -Seconds 2
    }
} finally {
    Release-Mutex
}

$totalElapsed = ((Get-Date) - $totalStartTime).TotalSeconds
$successCount = ($runResults | Where-Object { $_.status -eq "ok" }).Count

Write-Host "`n[STATS] Individual runs complete: $successCount/$NumRuns OK (${totalElapsed}s total)" -ForegroundColor Cyan

# Now run batch aggregation
if ($successCount -gt 0) {
    Write-Host "[STATS] Running batch aggregation..." -ForegroundColor Green

    # Write batch config
    $batchConfig = @{
        results_dir = $cycleResultsDir.Replace("\", "/")
        output_path = "user://batch_autoplay_results.json"
    } | ConvertTo-Json
    $batchConfigPath = Join-Path $godotUserDir "batch_autoplay_config.json"
    $batchConfig | Set-Content $batchConfigPath -Encoding UTF8

    # Run batch aggregation (headless, uses SceneTree script)
    Acquire-Mutex
    try {
        $aggArgs = @(
            "--path", $projectRoot,
            "--headless",
            "--script", "res://scripts/test/batch_autoplay.gd"
        )

        $aggProc = Start-Process -FilePath $godotExe -ArgumentList $aggArgs `
            -WindowStyle Hidden -PassThru
        $aggProc.WaitForExit(120000)  # 2 min timeout

        # Collect aggregate results
        $aggResultsFile = Join-Path $godotUserDir "batch_autoplay_results.json"
        if (Test-Path $aggResultsFile) {
            $outputPath = Join-Path $statusDir "stats_summary.json"
            Copy-Item $aggResultsFile $outputPath -Force

            # Also copy to cycle dir
            Copy-Item $aggResultsFile (Join-Path $cycleResultsDir "aggregate.json") -Force

            $aggData = Get-Content $aggResultsFile -Raw | ConvertFrom-Json
            Write-Host "`n[STATS] === AGGREGATE RESULTS ===" -ForegroundColor Cyan
            Write-Host "  Total runs:     $($aggData.total_runs)" -ForegroundColor Gray
            Write-Host "  Survival rate:  $([math]::Round($aggData.survival_rate * 100, 1))%" -ForegroundColor Gray
            Write-Host "  Avg cards:      $($aggData.avg_cards_played)" -ForegroundColor Gray
            Write-Host "  Balance score:  $($aggData.balance_score)/100" -ForegroundColor $(if($aggData.balance_score -ge 60){"Green"}else{"Yellow"})
            Write-Host "  Fun score:      $($aggData.fun_score)/100" -ForegroundColor $(if($aggData.fun_score -ge 60){"Green"}else{"Yellow"})

            Remove-Item $aggResultsFile -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "[STATS] WARN: Aggregation produced no output" -ForegroundColor Yellow
        }
    } finally {
        Release-Mutex
    }
} else {
    Write-Host "[STATS] WARN: No successful runs, skipping aggregation" -ForegroundColor Yellow
}

# Write stats runner report
$statsReport = @{
    cycle         = $Cycle
    timestamp     = (Get-Date -Format "o")
    total_runs    = $NumRuns
    successful    = $successCount
    failed        = $NumRuns - $successCount
    elapsed_s     = [math]::Round($totalElapsed, 1)
    results_dir   = $cycleResultsDir
    runs          = $runResults
} | ConvertTo-Json -Depth 5
$statsReport | Set-Content (Join-Path $statusDir "stats_report.json") -Encoding UTF8

# Notify
& powershell -File (Join-Path $scriptDir "notify.ps1") `
    -Event "stats_done" `
    -Message "$successCount/$NumRuns runs OK, balance=$($aggData.balance_score) fun=$($aggData.fun_score) (cycle $Cycle)"

Write-Host "`n[STATS] Stats runner complete." -ForegroundColor Green
