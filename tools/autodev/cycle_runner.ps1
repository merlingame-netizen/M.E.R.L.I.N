# cycle_runner.ps1 -- AUTODEV v2: Wave-based cycle orchestration
# Usage: .\cycle_runner.ps1 [-MaxCycles 3] [-DryRun] [-Cycle 1]
#
# Runs 4 waves per cycle:
#   WAVE 1: BUILD  (parallel, 5 build domains)
#   WAVE 2: TEST   (sequential, Godot mutex)
#     2a. Merge branches + validate Step 0
#     2b. Screenshots (if cycle % screenshot_frequency == 0)
#     2c. Stats runner (if cycle % stats_frequency == 0)
#     2d. Smoke tests + flow order
#   WAVE 3: REVIEW (parallel, 3 review domains)
#   WAVE 4: FIX    (parallel, failed build domains only)
#   -> Feedback aggregation -> next cycle

param(
    [int]$MaxCycles = 3,
    [int]$Cycle = 1,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$configPath = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# Ensure directories exist
@($statusDir, $logDir, (Join-Path $statusDir "patches"), (Join-Path $statusDir "feedback"), (Join-Path $statusDir "reviews")) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$buildDomains = @($config.domains | Where-Object { $_.type -eq "build" })
$reviewDomains = @($config.domains | Where-Object { $_.type -eq "review" })

# ── Helpers ────────────────────────────────────────────────────────────

function Test-Veto {
    return (Test-Path (Join-Path $scriptDir "VETO"))
}

function Write-ControlState {
    param([string]$State, [int]$CycleNum, [string]$Wave = "", [string]$Detail = "")
    $controlState = @{
        state         = $State
        cycle         = $CycleNum
        wave          = $Wave
        detail        = $Detail
        wave_mode     = $true
        max_cycles    = $MaxCycles
        timestamp     = (Get-Date -Format "o")
        pid           = $PID
    }
    $controlState | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "control_state.json") -Encoding UTF8
}

function Show-WaveBanner {
    param([int]$CycleNum, [string]$WaveName, [int]$WaveNum, [string]$Mode = "")
    Write-Host "" -ForegroundColor Cyan
    Write-Host "[================================================================]" -ForegroundColor Cyan
    Write-Host "|  AUTODEV v2 -- Cycle $CycleNum / Wave $WaveNum : $WaveName" -ForegroundColor Cyan
    if ($Mode) { Write-Host "|  Mode: $Mode" -ForegroundColor Cyan }
    Write-Host "[================================================================]" -ForegroundColor Cyan
}

# ── WAVE 1: BUILD ──────────────────────────────────────────────────────

function Invoke-BuildWave {
    param([int]$CycleNum)

    Show-WaveBanner -CycleNum $CycleNum -WaveName "BUILD" -WaveNum 1 -Mode "$($buildDomains.Count) parallel workers"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "build" -Detail "Launching $($buildDomains.Count) build workers"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 1 BUILD: $($buildDomains.Count) workers"

    $workerScript = Join-Path $scriptDir "worker.ps1"
    $jobs = @{}
    $failedDomains = @()

    foreach ($d in $buildDomains) {
        if (Test-Veto) {
            Write-Host "[CYCLE] VETO detected, skipping $($d.name)" -ForegroundColor Red
            continue
        }

        $mode = "build"
        # Check if feedback has priority fixes -> use fix mode for cycle > 1
        if ($CycleNum -gt 1) {
            $feedbackFile = Join-Path $statusDir "feedback/$($d.name).json"
            if (Test-Path $feedbackFile) {
                $fb = Get-Content $feedbackFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($fb -and $fb.priority_fixes -and $fb.priority_fixes.Count -gt 0) {
                    $mode = "fix"
                    Write-Host "[CYCLE]   $($d.name): fix mode ($($fb.priority_fixes.Count) priority fixes)" -ForegroundColor Yellow
                }
            }
        }

        Write-Host "[CYCLE] Launching: $($d.name) (mode=$mode, $($d.tasks.Count) tasks)" -ForegroundColor Green

        if ($DryRun) {
            $jobs[$d.name] = Start-Job -ScriptBlock {
                param($script, $domain, $mode)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -Mode $mode -DryRun
            } -ArgumentList $workerScript, $d.name, $mode
        } else {
            $jobs[$d.name] = Start-Job -ScriptBlock {
                param($script, $domain, $mode)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -Mode $mode
            } -ArgumentList $workerScript, $d.name, $mode
        }
    }

    # Monitor build jobs
    $statusSummary = Wait-ForJobs -Jobs $jobs -Label "BUILD"

    # Identify failed domains
    foreach ($name in $statusSummary.Keys) {
        $s = $statusSummary[$name]
        if ($s.job_state -ne "Completed" -or $s.file_status -ne "done") {
            $failedDomains += $name
        }
    }

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_complete" -Message "BUILD done: $($jobs.Count - $failedDomains.Count) OK, $($failedDomains.Count) failed"

    # Wrap in array to prevent PS from unwrapping the hashtable
    return ,@{ status = $statusSummary; failed = $failedDomains }
}

# ── WAVE 2: TEST ───────────────────────────────────────────────────────

function Invoke-TestWave {
    param([int]$CycleNum)

    Show-WaveBanner -CycleNum $CycleNum -WaveName "TEST" -WaveNum 2 -Mode "sequential (Godot mutex)"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "test" -Detail "Merge + Validate + Screenshots + Stats"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 2 TEST"

    # 2a. Merge all completed build branches
    Write-Host "`n[CYCLE] Step 2a: Merge completed branches..." -ForegroundColor Yellow
    $mergeScript = Join-Path $scriptDir "merge_coordinator.ps1"
    if ($DryRun) {
        & powershell -File $mergeScript -All -DryRun
    } else {
        & powershell -File $mergeScript -All
    }

    if (Test-Veto) { return }

    # 2b. Screenshots (if frequency matches)
    $doScreenshots = ($CycleNum % $config.screenshot_frequency) -eq 0
    if ($doScreenshots) {
        Write-Host "`n[CYCLE] Step 2b: Screenshots..." -ForegroundColor Yellow
        $screenshotScript = Join-Path $scriptDir "screenshot_capture.ps1"
        if ($DryRun) {
            Write-Host "[DRY RUN] Would run screenshot_capture.ps1 -Cycle $CycleNum" -ForegroundColor Magenta
        } else {
            & powershell -File $screenshotScript -Cycle $CycleNum
        }
    } else {
        Write-Host "`n[CYCLE] Step 2b: Screenshots skipped (frequency: every $($config.screenshot_frequency) cycles)" -ForegroundColor Gray
    }

    if (Test-Veto) { return }

    # 2c. Stats runner (if frequency matches)
    $doStats = ($CycleNum % $config.stats_frequency) -eq 0
    if ($doStats) {
        Write-Host "`n[CYCLE] Step 2c: Stats runner..." -ForegroundColor Yellow
        $statsScript = Join-Path $scriptDir "stats_runner.ps1"
        if ($DryRun) {
            Write-Host "[DRY RUN] Would run stats_runner.ps1 -NumRuns 3 -Cycle $CycleNum" -ForegroundColor Magenta
        } else {
            & powershell -File $statsScript -NumRuns 3 -Cycle $CycleNum
        }
    } else {
        Write-Host "`n[CYCLE] Step 2c: Stats skipped (frequency: every $($config.stats_frequency) cycles)" -ForegroundColor Gray
    }

    if (Test-Veto) { return }

    # 2d. Smoke tests + flow order
    Write-Host "`n[CYCLE] Step 2d: Smoke tests + flow order..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "[DRY RUN] Would run validate.bat (smoke tests)" -ForegroundColor Magenta
    } else {
        $godotExe = $config.godot_exe
        # Editor Parse Check (Step 0 -- most reliable, fast)
        Write-Host "[CYCLE]   Editor Parse Check..." -ForegroundColor Gray
        $parseOutput = & $godotExe --editor --headless --quit 2>&1
        $hasErrors = $parseOutput | Select-String -Pattern "ERROR|SCRIPT ERROR|Could not find type" -Quiet
        if ($hasErrors) {
            Write-Host "[CYCLE]   ERRORS detected after merge!" -ForegroundColor Red
            $parseOutput | Select-String "ERROR|SCRIPT ERROR" | Select-Object -First 10 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Red
            }
        } else {
            Write-Host "[CYCLE]   Editor Parse Check: OK" -ForegroundColor Green
        }
    }

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_complete" -Message "TEST done (cycle $CycleNum)"
}

# ── WAVE 3: REVIEW ─────────────────────────────────────────────────────

function Invoke-ReviewWave {
    param([int]$CycleNum)

    Show-WaveBanner -CycleNum $CycleNum -WaveName "REVIEW" -WaveNum 3 -Mode "$($reviewDomains.Count) parallel reviewers"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "review" -Detail "Launching $($reviewDomains.Count) review workers"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 3 REVIEW: $($reviewDomains.Count) reviewers"

    $reviewScript = Join-Path $scriptDir "review_worker.ps1"
    $jobs = @{}

    foreach ($d in $reviewDomains) {
        if (Test-Veto) {
            Write-Host "[CYCLE] VETO detected, skipping $($d.name)" -ForegroundColor Red
            continue
        }

        Write-Host "[CYCLE] Launching reviewer: $($d.name)" -ForegroundColor Green

        if ($DryRun) {
            $jobs[$d.name] = Start-Job -ScriptBlock {
                param($script, $domain)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -DryRun
            } -ArgumentList $reviewScript, $d.name
        } else {
            $jobs[$d.name] = Start-Job -ScriptBlock {
                param($script, $domain)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain
            } -ArgumentList $reviewScript, $d.name
        }
    }

    # Monitor review jobs
    $statusSummary = Wait-ForJobs -Jobs $jobs -Label "REVIEW"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "review_done" -Message "REVIEW done (cycle $CycleNum)"

    return $statusSummary
}

# ── WAVE 4: FIX ────────────────────────────────────────────────────────

function Invoke-FixWave {
    param([int]$CycleNum, [array]$FailedDomains)

    if ($FailedDomains.Count -eq 0) {
        Write-Host "`n[CYCLE] Wave 4 FIX: No failed domains, skipping." -ForegroundColor Green
        return @{}
    }

    Show-WaveBanner -CycleNum $CycleNum -WaveName "FIX" -WaveNum 4 -Mode "$($FailedDomains.Count) domains to fix"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "fix" -Detail "Fixing $($FailedDomains.Count) failed domains"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 4 FIX: $($FailedDomains -join ', ')"

    $workerScript = Join-Path $scriptDir "worker.ps1"
    $jobs = @{}

    foreach ($domainName in $FailedDomains) {
        if (Test-Veto) { continue }

        Write-Host "[CYCLE] Launching fix worker: $domainName" -ForegroundColor Yellow

        if ($DryRun) {
            $jobs[$domainName] = Start-Job -ScriptBlock {
                param($script, $domain)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -Mode "fix" -DryRun
            } -ArgumentList $workerScript, $domainName
        } else {
            $jobs[$domainName] = Start-Job -ScriptBlock {
                param($script, $domain)
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -Mode "fix"
            } -ArgumentList $workerScript, $domainName
        }
    }

    $statusSummary = Wait-ForJobs -Jobs $jobs -Label "FIX"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "fix_done" -Message "FIX done (cycle $CycleNum)"

    return $statusSummary
}

# ── Feedback Aggregation ───────────────────────────────────────────────

function Invoke-FeedbackAggregation {
    param([int]$CycleNum)

    Write-Host "`n[CYCLE] Feedback aggregation for cycle $CycleNum..." -ForegroundColor Cyan
    $aggScript = Join-Path $scriptDir "feedback_aggregator.ps1"

    if ($DryRun) {
        Write-Host "[DRY RUN] Would run feedback_aggregator.ps1 -Cycle $CycleNum" -ForegroundColor Magenta
    } else {
        & powershell -File $aggScript -Cycle $CycleNum
    }
}

# ── Job Monitor ────────────────────────────────────────────────────────

function Wait-ForJobs {
    param([hashtable]$Jobs, [string]$Label)

    if ($Jobs.Count -eq 0) { return @{} }

    $tickSeconds = if ($config.cycle_tick_seconds) { $config.cycle_tick_seconds } else { 30 }
    $statusSummary = @{}

    while ($true) {
        if (Test-Veto) {
            Write-Host "[CYCLE] VETO -- stopping $Label workers" -ForegroundColor Red
            foreach ($name in $Jobs.Keys) {
                if ($Jobs[$name].State -eq "Running") {
                    Stop-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
                }
            }
            break
        }

        $runningCount = 0
        $doneCount = 0

        foreach ($name in $Jobs.Keys) {
            $job = $Jobs[$name]
            $jobState = $job.State

            $fileStatus = "unknown"
            $statusFile = Join-Path $statusDir "$name.json"
            if (Test-Path $statusFile) {
                $s = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($s) { $fileStatus = $s.status }
            }

            $statusSummary[$name] = @{ job_state = [string]$jobState; file_status = $fileStatus }

            switch ($jobState) {
                "Running"   { $runningCount++ }
                "Completed" { $doneCount++ }
                "Failed"    {
                    $doneCount++
                    $null = Receive-Job -Job $job -ErrorAction SilentlyContinue
                }
            }
        }

        # Display
        $icon = if ($runningCount -gt 0) { ".." } else { "OK" }
        Write-Host "[CYCLE] [$Label] $(Get-Date -Format 'HH:mm:ss') Running: $runningCount, Done: $doneCount/$($Jobs.Count)" -ForegroundColor Cyan

        if ($runningCount -eq 0) { break }
        Start-Sleep -Seconds $tickSeconds
    }

    # Cleanup jobs
    foreach ($name in $Jobs.Keys) {
        $null = Receive-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
        Remove-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
    }

    return $statusSummary
}

# ── Cycle Report ───────────────────────────────────────────────────────

function New-CycleReport {
    param([int]$CycleNum, $BuildResult, $ReviewResult, $FixResult)

    # Safely extract from build result (may be hashtable or PSObject)
    $buildStatus = if ($BuildResult -and $BuildResult.status) { $BuildResult.status } else { @{} }
    $buildFailed = if ($BuildResult -and $BuildResult.failed) { @($BuildResult.failed) } else { @() }

    $report = @{
        cycle           = $CycleNum
        timestamp       = (Get-Date -Format "o")
        wave_mode       = $true
        build_results   = $buildStatus
        build_failed    = $buildFailed
        review_results  = $ReviewResult
        fix_results     = $FixResult
    }

    $reportPath = Join-Path $logDir "cycle_${CycleNum}_report.json"
    $report | ConvertTo-Json -Depth 5 | Set-Content $reportPath -Encoding UTF8

    $buildOk = $buildStatus.Count - $buildFailed.Count
    Write-Host "`n[CYCLE] ==========================================" -ForegroundColor Cyan
    Write-Host "[CYCLE] Cycle $CycleNum Complete" -ForegroundColor Cyan
    Write-Host "  BUILD:  $buildOk OK, $($buildFailed.Count) failed" -ForegroundColor $(if($buildFailed.Count -eq 0){"Green"}else{"Yellow"})
    Write-Host "  REVIEW: $($ReviewResult.Count) reviewers" -ForegroundColor Green
    Write-Host "  FIX:    $($FixResult.Count) fix workers" -ForegroundColor $(if($FixResult.Count -eq 0){"Green"}else{"Yellow"})
    Write-Host "[CYCLE] ==========================================" -ForegroundColor Cyan

    return $report
}

# =====================================================================
# MAIN
# =====================================================================

Write-Host ""
Write-Host "[================================================================]" -ForegroundColor Cyan
Write-Host "|                                                                |" -ForegroundColor Cyan
Write-Host "|  M.E.R.L.I.N. AUTODEV v2 -- Wave-Based Cycle Runner           |" -ForegroundColor Cyan
Write-Host "|                                                                |" -ForegroundColor Cyan
Write-Host "|  Cycles: $MaxCycles | Build: $($buildDomains.Count) | Review: $($reviewDomains.Count)                          |" -ForegroundColor Cyan
Write-Host "|  Veto: Drop 'VETO' file in tools/autodev/ to stop             |" -ForegroundColor Cyan
Write-Host "|                                                                |" -ForegroundColor Cyan
Write-Host "[================================================================]" -ForegroundColor Cyan
Write-Host ""

# Start health monitor in background
$healthJob = $null
if (-not $DryRun) {
    $healthScript = Join-Path $scriptDir "health_monitor.ps1"
    $healthJob = Start-Job -ScriptBlock {
        param($script)
        & powershell -File $script -IntervalSeconds 120
    } -ArgumentList $healthScript
    Write-Host "[CYCLE] Health monitor started (Job $($healthJob.Id))" -ForegroundColor Gray
}

$currentCycle = $Cycle

while ($currentCycle -le ($Cycle + $MaxCycles - 1)) {
    if (Test-Veto) {
        Write-Host "[CYCLE] VETO detected. Stopping before cycle $currentCycle." -ForegroundColor Red
        break
    }

    Write-ControlState -State "running" -CycleNum $currentCycle -Wave "starting"

    # WAVE 1: BUILD
    $buildResult = Invoke-BuildWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # WAVE 2: TEST
    Invoke-TestWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # WAVE 3: REVIEW
    $reviewResult = Invoke-ReviewWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # Feedback aggregation (between REVIEW and FIX, feeds next cycle)
    Invoke-FeedbackAggregation -CycleNum $currentCycle
    if (Test-Veto) { break }

    # WAVE 4: FIX (only if build had failures)
    $fixResult = Invoke-FixWave -CycleNum $currentCycle -FailedDomains $buildResult.failed
    if (Test-Veto) { break }

    # Cycle report
    New-CycleReport -CycleNum $currentCycle -BuildResult $buildResult -ReviewResult $reviewResult -FixResult $fixResult

    # Veto delay between cycles
    $currentCycle++
    if ($currentCycle -le ($Cycle + $MaxCycles - 1)) {
        $vetoDelay = if ($config.veto_delay_seconds) { $config.veto_delay_seconds } else { 60 }
        Write-Host "`n[CYCLE] Next cycle in ${vetoDelay}s (drop VETO to cancel)..." -ForegroundColor Yellow
        $waited = 0
        while ($waited -lt $vetoDelay) {
            if (Test-Veto) {
                Write-Host "[CYCLE] VETO during delay. Stopping." -ForegroundColor Red
                break
            }
            Start-Sleep -Seconds 10
            $waited += 10
        }
        if (Test-Veto) { break }
    }
}

# Cleanup
Write-ControlState -State "idle" -CycleNum ($currentCycle - 1) -Detail "Pipeline complete"

if ($healthJob) {
    Stop-Job -Job $healthJob -ErrorAction SilentlyContinue
    Remove-Job -Job $healthJob -ErrorAction SilentlyContinue
}

Write-Host "`n[CYCLE] AUTODEV v2 pipeline complete." -ForegroundColor Green
