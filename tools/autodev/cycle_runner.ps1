# cycle_runner.ps1 -- AUTODEV v3: Wave-based cycle orchestration with Game Director
# Usage: .\cycle_runner.ps1 [-MaxCycles 3] [-DryRun] [-Cycle 1]
#
# Runs 5 waves per cycle:
#   WAVE 1:   BUILD    (parallel, 5 build domains)
#   WAVE 2:   TEST     (sequential, Godot mutex)
#     2a. Merge branches + tag autodev/good_cycle_N + validate Step 0
#     2b. Screenshots (if cycle % screenshot_frequency == 0)
#     2c. Stats runner (if cycle % stats_frequency == 0)
#     2d. Smoke tests + flow order
#   WAVE 3:   REVIEW   (parallel, 3 reviewers + cross-inspection)
#   WAVE 3.5: DIRECTOR (sequential, Game Director decision)
#     -> PROCEED: continue to FIX wave
#     -> ROLLBACK: revert to last_good, restart cycle
#     -> ESCALATE: pause pipeline, wait for human
#     -> OVERRIDE: adjust FIX priorities, continue
#   WAVE 4:   FIX      (parallel, failed/targeted build domains)
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
@($statusDir, $logDir, (Join-Path $statusDir "patches"), (Join-Path $statusDir "feedback"), (Join-Path $statusDir "reviews"), (Join-Path $statusDir "messages")) | ForEach-Object {
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
    # Atomic write: temp file + rename to prevent race conditions
    $targetFile = Join-Path $statusDir "control_state.json"
    $tmpFile = "$targetFile.tmp"
    $controlState | ConvertTo-Json -Depth 3 | Set-Content $tmpFile -Encoding UTF8
    Move-Item -Path $tmpFile -Destination $targetFile -Force
}

function Show-WaveBanner {
    param([int]$CycleNum, [string]$WaveName, [int]$WaveNum, [string]$Mode = "")
    Write-Host "" -ForegroundColor Cyan
    Write-Host "[================================================================]" -ForegroundColor Cyan
    Write-Host "|  AUTODEV v3 -- Cycle $CycleNum / Wave $WaveNum : $WaveName" -ForegroundColor Cyan
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

# ── Live Dashboard Writer (replaces aggregated view windows) ─────────

function Update-LiveDashboard {
    param([int]$CycleNum = 0, [string]$Wave = "", [string]$Detail = "")
    $dashScript = Join-Path $scriptDir "write_dashboard.ps1"
    if (Test-Path $dashScript) {
        $dashArgs = @("-CycleNum", $CycleNum)
        if ($Wave) { $dashArgs += @("-Wave", $Wave) }
        if ($Detail) { $dashArgs += @("-Detail", $Detail) }
        & powershell -NoProfile -File $dashScript @dashArgs | Out-Null
    }
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

        # Update live dashboard file (VS Code auto-refreshes)
        Update-LiveDashboard -CycleNum $currentCycle -Wave $Label

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

    $defaultWorkerScript = Join-Path $scriptDir "worker.ps1"
    $swarmDir = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "tools" "swarm"
    $codexWorkerScript = Join-Path $swarmDir "codex_worker.ps1"
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

        # Swarm routing: select worker based on domain.tool field
        $domainTool = if ($d.PSObject.Properties['tool']) { $d.tool } else { "claude" }
        $workerScript = if ($domainTool -eq "codex" -and (Test-Path $codexWorkerScript)) {
            $codexWorkerScript
        } else {
            $defaultWorkerScript
        }
        $toolBadge = if ($domainTool -eq "codex") { "[CODEX]" } else { "[CLAUDE]" }

        $workerLog = Join-Path $logDir "$($d.name)_BUILD_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $statusFile = Join-Path $statusDir "$($d.name).json"

        Write-Host "[CYCLE] Launching: $toolBadge $($d.name) (mode=$mode, $($d.tasks.Count) tasks)" -ForegroundColor Green

        # Pre-create empty log so tail_log can find it quickly
        "" | Set-Content $workerLog -Encoding UTF8

        $procs[$d.name] = Start-HiddenWorker -Script $workerScript -Domain $d.name -Mode $mode -WaveLabel "BUILD" -LogFile $workerLog -IsDryRun:$DryRun
        $paneSpecs += @{ title = "$($d.name) BUILD"; logFile = $workerLog; statusFile = $statusFile }
    }

    # Monitor build processes via status files (dashboard updated at each tick)
    $statusSummary = Wait-ForProcesses -Processes $procs -Label "BUILD"

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
    $mergeArgs = @("-All", "-Cycle", $CycleNum)
    if ($config.tag_on_merge) { $mergeArgs += "-TagOnSuccess" }
    if ($DryRun) { $mergeArgs += "-DryRun" }
    & powershell -NoProfile -File $mergeScript @mergeArgs

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

    # 2e. AI Playtest (if frequency matches)
    $playtestFreq = if ($config.playtest_frequency) { $config.playtest_frequency } else { 2 }
    $doPlaytest = ($CycleNum % $playtestFreq) -eq 0
    if ($doPlaytest) {
        Write-Host "`n[CYCLE] Step 2e: AI Playtest..." -ForegroundColor Yellow
        $playtestScript = Join-Path $scriptDir "ai_playtester/run_playtest.ps1"
        if ($DryRun) {
            Write-Host "[DRY RUN] Would run AI Playtest (cycle $CycleNum)" -ForegroundColor Magenta
        } else {
            if (Test-Path $playtestScript) {
                & powershell -File $playtestScript -Cycle $CycleNum -NoLaunch
            } else {
                Write-Host "[CYCLE] AI Playtest script not found: $playtestScript" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`n[CYCLE] Step 2e: AI Playtest skipped (frequency: every $playtestFreq cycles)" -ForegroundColor Gray
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

    # Monitor review processes via status files (dashboard updated at each tick)
    $statusSummary = Wait-ForProcesses -Processes $procs -Label "REVIEW"

    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "review_done" -Message "REVIEW done (cycle $CycleNum)"

    return $statusSummary
}

# ── WAVE 3.5: DIRECTOR ─────────────────────────────────────────────────

function Invoke-DirectorWave {
    param([int]$CycleNum)

    Show-WaveBanner -CycleNum $CycleNum -WaveName "DIRECTOR" -WaveNum "3.5" -Mode "Game Director decision"
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "director" -Detail "Game Director analyzing cycle $CycleNum"

    & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") -Event "wave_start" -Message "Cycle $CycleNum Wave 3.5 DIRECTOR"

    $directorScript = Join-Path $scriptDir "director_worker.ps1"

    if (-not (Test-Path $directorScript)) {
        Write-Host "[CYCLE] director_worker.ps1 not found --skipping Director wave" -ForegroundColor Yellow
        return @{ decision = "PROCEED"; reason = "no_director_script" }
    }

    $directorLog = Join-Path $logDir "director_DIRECTOR_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    "" | Set-Content $directorLog -Encoding UTF8

    Write-Host "[CYCLE] Launching Game Director (cycle $CycleNum)..." -ForegroundColor Green

    # Director runs in visible window (single worker, important output)
    $directorArgs = @("-Cycle", $CycleNum)
    if ($DryRun) { $directorArgs += "-DryRun" }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $directorScript @directorArgs 2>&1 |
        Tee-Object -FilePath $directorLog

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host "[CYCLE] Director worker failed (exit $exitCode) --defaulting to PROCEED" -ForegroundColor Red
        return @{ decision = "PROCEED"; reason = "director_error"; exit_code = $exitCode }
    }

    # Parse the Director's decision
    $decisionFile = Join-Path $statusDir "director_decision.json"
    if (-not (Test-Path $decisionFile)) {
        Write-Host "[CYCLE] No director_decision.json --defaulting to PROCEED" -ForegroundColor Yellow
        return @{ decision = "PROCEED"; reason = "no_decision_file" }
    }

    $decision = Get-Content $decisionFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $decision -or -not $decision.decision) {
        Write-Host "[CYCLE] Could not parse director_decision.json --defaulting to PROCEED" -ForegroundColor Yellow
        return @{ decision = "PROCEED"; reason = "parse_error" }
    }

    # ConstrainedLanguage safe: PowerShell switch/eq are case-insensitive
    $dec = $decision.decision
    Write-Host "[CYCLE] Director decision: $dec (quality=$($decision.quality_score), confidence=$($decision.confidence))" -ForegroundColor Cyan

    & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") -Event "wave_complete" -Message "DIRECTOR: $dec (Q=$($decision.quality_score) C=$($decision.confidence))"

    return @{
        decision     = $dec
        quality      = $decision.quality_score
        confidence   = $decision.confidence
        rationale    = $decision.rationale
        reason       = "director_decision"
    }
}

# ── Director Decision Router ──────────────────────────────────────────

function Invoke-DirectorDecisionRoute {
    param([int]$CycleNum, $DirectorResult)

    $dec = $DirectorResult.decision

    if ($dec -eq "PROCEED") {
        Write-Host "[CYCLE] Director: PROCEED --continuing to FIX wave" -ForegroundColor Green
        return "continue"
    }

    if ($dec -eq "OVERRIDE") {
        Write-Host "[CYCLE] Director: OVERRIDE --adjusting FIX priorities, then continuing" -ForegroundColor Yellow
        return "continue"
    }

    if ($dec -eq "ROLLBACK") {
        Write-Host "[CYCLE] Director: ROLLBACK --reverting to last known good state" -ForegroundColor Red
        $rollbackScript = Join-Path $scriptDir "git_rollback.ps1"
        if (Test-Path $rollbackScript) {
            $rbArgs = @("-Action", "RollbackFull", "-Cycle", $CycleNum)
            if ($DryRun) { $rbArgs += "-DryRun" }
            & powershell -NoProfile -File $rollbackScript @rbArgs
        } else {
            Write-Host "[CYCLE] git_rollback.ps1 not found! Cannot rollback." -ForegroundColor Red
        }
        & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") -Event "rollback" -Message "Director ROLLBACK cycle $CycleNum" -Details $DirectorResult.rationale
        return "rollback"
    }

    if ($dec -eq "ESCALATE") {
        # ── Progressive escalation: check auto_diagnosis before blocking ──
        $diagFile = Join-Path $statusDir "auto_diagnosis.json"
        if (Test-Path $diagFile) {
            $diag = Get-Content $diagFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($diag -and $diag.summary -and $diag.summary.needs_human -eq $false) {
                Write-Host "[CYCLE] Director: ESCALATE overridden --auto_diagnosis says needs_human=false" -ForegroundColor Green
                Write-Host "[CYCLE]   Reason: $($diag.summary.reason) (transient=$($diag.summary.transient), permanent=$($diag.summary.permanent))" -ForegroundColor Gray
                & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") -Event "escalation_overridden" -Message "ESCALATE overridden by auto-diagnosis (all errors auto-resolvable)"
                return "continue"
            }
        }

        Write-Host "[CYCLE] Director: ESCALATE --waiting for human input" -ForegroundColor Yellow
        $escalationScript = Join-Path $scriptDir "human_escalation.ps1"

        if (-not (Test-Path $escalationScript)) {
            Write-Host "[CYCLE] human_escalation.ps1 not found --defaulting to PROCEED" -ForegroundColor Yellow
            return "continue"
        }

        $timeoutHours = 24
        if ($config.escalation_timeout_hours) { $timeoutHours = $config.escalation_timeout_hours }

        Write-Host "[CYCLE] Entering escalation wait (timeout: ${timeoutHours}h)..." -ForegroundColor Yellow
        $escArgs = @("-Action", "Wait", "-Cycle", $CycleNum, "-TimeoutHours", $timeoutHours)
        $escRawOutput = & powershell -NoProfile -File $escalationScript @escArgs
        # Filter: keep only lines that look like JSON (ConstrainedLanguage may mix error text)
        $escJsonLines = @()
        if ($escRawOutput) {
            foreach ($line in $escRawOutput) {
                $trimmed = "$line".Trim()
                if ($trimmed -match '^\{' -or $trimmed -match '^\}' -or $trimmed -match '^"' -or $trimmed -match '^\[') {
                    $escJsonLines += $trimmed
                }
            }
        }
        $escResultJson = $escJsonLines -join "`n"
        $escResult = $null
        if ($escResultJson) {
            $escResult = $escResultJson | ConvertFrom-Json -ErrorAction SilentlyContinue
        }

        if (-not $escResult) {
            Write-Host "[CYCLE] Escalation returned no result --defaulting to PROCEED" -ForegroundColor Yellow
            return "continue"
        }

        $humanDecision = $escResult.decision
        Write-Host "[CYCLE] Human response: $humanDecision (reason: $($escResult.reason))" -ForegroundColor Cyan

        if ($humanDecision -eq "proceed") { return "continue" }
        if ($humanDecision -eq "veto") { return "veto" }
        if ($humanDecision -eq "rollback") {
            $rbScript = Join-Path $scriptDir "git_rollback.ps1"
            if (Test-Path $rbScript) {
                $rbArgs2 = @("-Action", "RollbackFull", "-Cycle", $CycleNum)
                if ($DryRun) { $rbArgs2 += "-DryRun" }
                & powershell -NoProfile -File $rbScript @rbArgs2
            }
            return "rollback"
        }
        if ($humanDecision -eq "custom") {
            Write-Host "[CYCLE] Human custom: $($escResult.details)" -ForegroundColor Cyan
            $customFile = Join-Path $statusDir "feedback/human_custom.json"
            $customObj = @{ cycle = $CycleNum; details = $escResult.details; timestamp = (Get-Date -Format "o") }
            $customObj | ConvertTo-Json -Depth 3 | Set-Content $customFile -Encoding UTF8
            return "continue"
        }
        return "continue"
    }

    # Unknown decision
    Write-Host "[CYCLE] Unknown Director decision '$dec' --defaulting to PROCEED" -ForegroundColor Yellow
    return "continue"
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

    # Monitor fix processes via status files (dashboard updated at each tick)
    $statusSummary = Wait-ForProcesses -Processes $procs -Label "FIX"

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

# ── A2A: Delegation Mini-Wave ─────────────────────────────────────────

function Invoke-DelegationWave {
    param([int]$CycleNum)

    $messagesDir = Join-Path $statusDir "messages"
    if (-not (Test-Path $messagesDir)) { return }

    # Scan all inboxes for unprocessed delegation messages
    $delegations = @()
    $inboxFiles = Get-ChildItem $messagesDir -Filter "inbox_*.jsonl" -ErrorAction SilentlyContinue

    foreach ($file in $inboxFiles) {
        $lines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if (-not $line.Trim()) { continue }
            try {
                $msg = $line | ConvertFrom-Json
                if ($msg.type -eq "delegation" -and -not $msg.processed) {
                    $delegations += $msg
                }
            } catch {}
        }
    }

    if ($delegations.Count -eq 0) {
        Write-Host "[CYCLE] A2A: No pending delegations" -ForegroundColor Gray
        return
    }

    Write-Host "[CYCLE] A2A: $($delegations.Count) pending delegation(s)" -ForegroundColor Magenta
    Write-ControlState -State "running" -CycleNum $CycleNum -Wave "delegation" -Detail "Processing $($delegations.Count) A2A delegations"

    foreach ($deleg in $delegations) {
        Write-Host "[CYCLE] A2A: $($deleg.from_agent) -> $($deleg.to_agent): $($deleg.payload.action)" -ForegroundColor Magenta

        # Archive the processed delegation
        $archiveDir = Join-Path $messagesDir "_archive"
        if (-not (Test-Path $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }
        $archiveFile = Join-Path $archiveDir "cycle_${CycleNum}_delegations.jsonl"
        $deleg | ConvertTo-Json -Depth 5 -Compress | Add-Content $archiveFile -Encoding UTF8
    }

    # Process task_response messages: write feedback to requesting agent
    foreach ($file in $inboxFiles) {
        $lines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if (-not $line.Trim()) { continue }
            try {
                $msg = $line | ConvertFrom-Json
                if ($msg.type -eq "task_response" -and $msg.reply_to) {
                    Write-Host "[CYCLE] A2A: Response from $($msg.from_agent) to $($msg.to_agent) (re: $($msg.reply_to))" -ForegroundColor Green

                    # Inject response into target agent's feedback file
                    $feedbackFile = Join-Path $statusDir "feedback/$($msg.to_agent).json"
                    $existingFeedback = @{}
                    if (Test-Path $feedbackFile) {
                        try { $existingFeedback = Get-Content $feedbackFile -Raw | ConvertFrom-Json -AsHashtable } catch {}
                    }
                    if (-not $existingFeedback.a2a_responses) {
                        $existingFeedback["a2a_responses"] = @()
                    }
                    $existingFeedback["a2a_responses"] += @{
                        from = $msg.from_agent
                        reply_to = $msg.reply_to
                        payload = $msg.payload
                        timestamp = $msg.timestamp
                    }
                    $existingFeedback | ConvertTo-Json -Depth 5 | Set-Content $feedbackFile -Encoding UTF8

                    # Archive the response
                    $msg | ConvertTo-Json -Depth 5 -Compress | Add-Content $archiveFile -Encoding UTF8
                }
            } catch {}
        }
    }

    # Clear processed inboxes
    foreach ($file in $inboxFiles) {
        $remaining = @()
        $lines = Get-Content $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if (-not $line.Trim()) { continue }
            try {
                $msg = $line | ConvertFrom-Json
                if ($msg.type -ne "delegation" -and $msg.type -ne "task_response") {
                    $remaining += $line
                }
            } catch {
                $remaining += $line
            }
        }
        if ($remaining.Count -gt 0) {
            $remaining | Set-Content $file.FullName -Encoding UTF8
        } else {
            Remove-Item $file.FullName -ErrorAction SilentlyContinue
        }
    }
}

# (Wait-ForJobs replaced by Wait-ForProcesses above --visible windows)

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
Write-Host "|  M.E.R.L.I.N. AUTODEV v3 -- Wave-Based Cycle Runner           |" -ForegroundColor Cyan
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

# Dashboard: live_dashboard.md (VS Code auto-refresh, no external window)
Update-LiveDashboard -CycleNum $Cycle -Wave "starting" -Detail "Pipeline initializing"
Write-Host "[CYCLE] Live dashboard: tools/autodev/status/live_dashboard.md" -ForegroundColor Cyan

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

    # WAVE 3: REVIEW (with cross-inspection)
    $reviewResult = Invoke-ReviewWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # Feedback aggregation (between REVIEW and DIRECTOR, feeds both)
    Invoke-FeedbackAggregation -CycleNum $currentCycle
    if (Test-Veto) { break }

    # A2A: Process delegation messages between waves
    Invoke-DelegationWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # AUTO-DIAGNOSIS (between FEEDBACK and DIRECTOR — classifies errors, provides context)
    $diagScript = Join-Path $scriptDir "auto_diagnosis.ps1"
    if (Test-Path $diagScript) {
        Write-Host "`n[CYCLE] Running auto-diagnosis..." -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File $diagScript -Cycle $currentCycle
    }
    if (Test-Veto) { break }

    # WAVE 3.5: DIRECTOR
    $directorResult = Invoke-DirectorWave -CycleNum $currentCycle
    if (Test-Veto) { break }

    # Route Director's decision
    $directorRoute = Invoke-DirectorDecisionRoute -CycleNum $currentCycle -DirectorResult $directorResult

    if ($directorRoute -eq "veto") {
        Write-Host "[CYCLE] VETO from escalation. Stopping." -ForegroundColor Red
        break
    }
    if ($directorRoute -eq "rollback") {
        Write-Host "[CYCLE] ROLLBACK --skipping FIX wave, restarting cycle" -ForegroundColor Yellow
        # Don't increment cycle --retry after rollback
        # But do count it to avoid infinite loop
        $currentCycle++
        continue
    }

    # WAVE 4: FIX (domains from build failures + Director directives)
    $fixTargets = @($buildResult.failed)
    # Add Director-targeted domains (from director_directives.json)
    $directivesFile = Join-Path $statusDir "director_directives.json"
    if (Test-Path $directivesFile) {
        $directives = Get-Content $directivesFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($directives -and $directives.fix_targets) {
            foreach ($ft in $directives.fix_targets) {
                if ($ft -notin $fixTargets) { $fixTargets += $ft }
            }
        }
    }
    $fixResult = Invoke-FixWave -CycleNum $currentCycle -FailedDomains $fixTargets
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

# Final dashboard update
Update-LiveDashboard -CycleNum ($currentCycle - 1) -Wave "complete" -Detail "Pipeline finished"

Write-Host "`n[CYCLE] AUTODEV v3 pipeline complete." -ForegroundColor Green
