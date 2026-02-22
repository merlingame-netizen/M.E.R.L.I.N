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

# ── Worker Launcher (hidden, writes to log file) ─────────────────────

function Start-HiddenWorker {
    param(
        [string]$Script,
        [string]$Domain,
        [string]$Mode = "build",
        [string]$WaveLabel = "BUILD",
        [string]$LogFile,
        [switch]$IsDryRun
    )

    # Build the command: run worker and tee output to log file
    $innerArgs = @("-ExecutionPolicy", "Bypass", "-File", "`"$Script`"", "-Domain", "`"$Domain`"")
    if ($Mode -and $Mode -ne "build") { $innerArgs += @("-Mode", "`"$Mode`"") }
    if ($IsDryRun) { $innerArgs += "-DryRun" }
    $innerCmd = $innerArgs -join " "

    $wrapperCmd = @(
        "& powershell $innerCmd 2>&1 | Tee-Object -FilePath '$LogFile'"
    ) -join "; "

    $proc = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile",
        "-WindowStyle", "Hidden",
        "-Command", $wrapperCmd
    ) -WindowStyle Hidden -PassThru

    Write-Host "[CYCLE]   -> PID $($proc.Id) | Log: $LogFile" -ForegroundColor Gray
    return $proc
}

# ── Aggregated View Launcher ─────────────────────────────────────────

function Start-AggregatedView {
    param(
        [array]$PaneSpecs,    # Array of @{title; logFile; statusFile}
        [string]$WaveLabel
    )

    $aggrScript = Join-Path $scriptDir "aggregated_view.ps1"
    if (-not (Test-Path $aggrScript)) {
        Write-Host "[CYCLE] aggregated_view.ps1 not found, skipping aggregator" -ForegroundColor Yellow
        return $null
    }

    # Write pane specs to a temp JSON file
    $specFile = Join-Path $statusDir "pane_specs_${WaveLabel}.json"
    $PaneSpecs | ConvertTo-Json -Depth 3 | Set-Content $specFile -Encoding UTF8

    $windowTitle = "AUTODEV - Cycle $currentCycle - $WaveLabel ($($PaneSpecs.Count) workers)"

    $proc = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile",
        "-File", $aggrScript,
        "-PaneSpecsFile", $specFile,
        "-WindowTitle", $windowTitle
    ) -PassThru

    Write-Host "[CYCLE] Aggregated view launched: $windowTitle ($($PaneSpecs.Count) panes)" -ForegroundColor Cyan
    return $proc
}

# ── Wait for visible processes ────────────────────────────────────────

function Wait-ForProcesses {
    param([hashtable]$Processes, [string]$Label)

    if ($Processes.Count -eq 0) { return @{} }

    $tickSeconds = if ($config.cycle_tick_seconds) { $config.cycle_tick_seconds } else { 30 }
    $statusSummary = @{}

    while ($true) {
        if (Test-Veto) {
            Write-Host "[CYCLE] VETO -- stopping $Label workers" -ForegroundColor Red
            foreach ($name in $Processes.Keys) {
                $p = $Processes[$name]
                if (-not $p.HasExited) {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                }
            }
            break
        }

        $runningCount = 0
        $doneCount = 0

        foreach ($name in $Processes.Keys) {
            $p = $Processes[$name]

            $fileStatus = "unknown"
            $statusFile = Join-Path $statusDir "$name.json"
            if (Test-Path $statusFile) {
                $s = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($s) { $fileStatus = $s.status }
            }

            if ($p.HasExited) {
                $doneCount++
                $exitState = if ($p.ExitCode -eq 0) { "Completed" } else { "Failed" }
                $statusSummary[$name] = @{ job_state = $exitState; file_status = $fileStatus }
            } else {
                $runningCount++
                $statusSummary[$name] = @{ job_state = "Running"; file_status = $fileStatus }
            }
        }

        # Display status in dashboard window
        Write-Host "[CYCLE] [$Label] $(Get-Date -Format 'HH:mm:ss') Running: $runningCount, Done: $doneCount/$($Processes.Count)" -ForegroundColor Cyan
        foreach ($name in $statusSummary.Keys) {
            $s = $statusSummary[$name]
            $icon = switch ($s.job_state) {
                "Running"   { "[..]" }
                "Completed" { "[OK]" }
                "Failed"    { "[!!]" }
                default     { "[??]" }
            }
            $color = switch ($s.job_state) {
                "Running"   { "Yellow" }
                "Completed" { "Green" }
                "Failed"    { "Red" }
                default     { "Gray" }
            }
            Write-Host "    $icon $name (status: $($s.file_status))" -ForegroundColor $color
        }

        if ($runningCount -eq 0) { break }
        Start-Sleep -Seconds $tickSeconds
    }

    return $statusSummary
}

# ── WAVE 1: BUILD ──────────────────────────────────────────────────────

function Invoke-BuildWave {
    param([int]$CycleNum)

    Show-WaveBanner -CycleNum $CycleNum -WaveName "BUILD" -WaveNum 1 -Mode "$($buildDomains.Count) parallel workers"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "build" -Detail "Launching $($buildDomains.Count) build workers"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 1 BUILD: $($buildDomains.Count) workers"

    $workerScript = Join-Path $scriptDir "worker.ps1"
    $procs = @{}
    $failedDomains = @()
    $paneSpecs = @()

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

        $workerLog = Join-Path $logDir "$($d.name)_BUILD_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $statusFile = Join-Path $statusDir "$($d.name).json"

        Write-Host "[CYCLE] Launching: $($d.name) (mode=$mode, $($d.tasks.Count) tasks)" -ForegroundColor Green

        # Pre-create empty log so tail_log can find it quickly
        "" | Set-Content $workerLog -Encoding UTF8

        $procs[$d.name] = Start-HiddenWorker -Script $workerScript -Domain $d.name -Mode $mode -WaveLabel "BUILD" -LogFile $workerLog -IsDryRun:$DryRun
        $paneSpecs += @{ title = "$($d.name) BUILD"; logFile = $workerLog; statusFile = $statusFile }
    }

    # Launch aggregated view (single WT window with all worker logs)
    $aggrProc = Start-AggregatedView -PaneSpecs $paneSpecs -WaveLabel "BUILD"

    # Monitor build processes via status files
    $statusSummary = Wait-ForProcesses -Processes $procs -Label "BUILD"

    # Close aggregated view when wave completes
    if ($aggrProc -and -not $aggrProc.HasExited) {
        Stop-Process -Id $aggrProc.Id -Force -ErrorAction SilentlyContinue
    }

    # Identify failed domains
    foreach ($name in $statusSummary.Keys) {
        $s = $statusSummary[$name]
        if ($s.job_state -ne "Completed" -or $s.file_status -ne "done") {
            $failedDomains += $name
        }
    }

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "wave_complete" -Message "BUILD done: $($procs.Count - $failedDomains.Count) OK, $($failedDomains.Count) failed"

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
    $procs = @{}
    $paneSpecs = @()

    foreach ($d in $reviewDomains) {
        if (Test-Veto) {
            Write-Host "[CYCLE] VETO detected, skipping $($d.name)" -ForegroundColor Red
            continue
        }

        $workerLog = Join-Path $logDir "$($d.name)_REVIEW_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $statusFile = Join-Path $statusDir "$($d.name).json"

        Write-Host "[CYCLE] Launching reviewer: $($d.name)" -ForegroundColor Green

        "" | Set-Content $workerLog -Encoding UTF8

        $procs[$d.name] = Start-HiddenWorker -Script $reviewScript -Domain $d.name -Mode "review" -WaveLabel "REVIEW" -LogFile $workerLog -IsDryRun:$DryRun
        $paneSpecs += @{ title = "$($d.name) REVIEW"; logFile = $workerLog; statusFile = $statusFile }
    }

    # Launch aggregated view for review wave
    $aggrProc = Start-AggregatedView -PaneSpecs $paneSpecs -WaveLabel "REVIEW"

    # Monitor review processes via status files
    $statusSummary = Wait-ForProcesses -Processes $procs -Label "REVIEW"

    if ($aggrProc -and -not $aggrProc.HasExited) {
        Stop-Process -Id $aggrProc.Id -Force -ErrorAction SilentlyContinue
    }

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
    $procs = @{}
    $paneSpecs = @()

    foreach ($domainName in $FailedDomains) {
        if (Test-Veto) { continue }

        $workerLog = Join-Path $logDir "${domainName}_FIX_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $statusFile = Join-Path $statusDir "${domainName}.json"

        Write-Host "[CYCLE] Launching fix worker: $domainName" -ForegroundColor Yellow

        "" | Set-Content $workerLog -Encoding UTF8

        $procs[$domainName] = Start-HiddenWorker -Script $workerScript -Domain $domainName -Mode "fix" -WaveLabel "FIX" -LogFile $workerLog -IsDryRun:$DryRun
        $paneSpecs += @{ title = "$domainName FIX"; logFile = $workerLog; statusFile = $statusFile }
    }

    # Launch aggregated view for fix wave
    $aggrProc = $null
    if ($paneSpecs.Count -gt 0) {
        $aggrProc = Start-AggregatedView -PaneSpecs $paneSpecs -WaveLabel "FIX"
    }

    $statusSummary = Wait-ForProcesses -Processes $procs -Label "FIX"

    if ($aggrProc -and -not $aggrProc.HasExited) {
        Stop-Process -Id $aggrProc.Id -Force -ErrorAction SilentlyContinue
    }

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

# (Wait-ForJobs replaced by Wait-ForProcesses above — visible windows)

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

# Launch live monitor dashboard in its own visible window
$monitorScript = Join-Path $scriptDir "monitor_dashboard.ps1"
$monitorProc = $null
if (Test-Path $monitorScript) {
    $monitorProc = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile",
        "-File", $monitorScript, "-RefreshSeconds", "5"
    ) -PassThru
    Write-Host "[CYCLE] Live monitor dashboard opened (PID $($monitorProc.Id))" -ForegroundColor Gray
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

# Close monitor dashboard
if ($monitorProc -and -not $monitorProc.HasExited) {
    Stop-Process -Id $monitorProc.Id -Force -ErrorAction SilentlyContinue
    Write-Host "[CYCLE] Monitor dashboard closed" -ForegroundColor Gray
}

Write-Host "`n[CYCLE] AUTODEV v2 pipeline complete." -ForegroundColor Green
