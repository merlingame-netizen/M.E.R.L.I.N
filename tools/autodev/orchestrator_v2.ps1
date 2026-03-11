# orchestrator_v2.ps1 — M.E.R.L.I.N. Studio State Machine Orchestrator v2.0
# Master coordinator: reads feature_queue, spawns specialist loops, monitors message bus,
# drives autonomous dev cycles through IDLE→PLAN→BUILD→VALIDATE→TEST→REPORT.
# Usage: .\orchestrator_v2.ps1 [-MaxCycles 99999] [-CycleIntervalSeconds 0] [-DryRun] [-OneShot] [-StartState PLAN]

param(
    [int]$MaxCycles              = 99999,
    [int]$CycleIntervalSeconds   = 0,
    [switch]$DryRun,
    [switch]$OneShot,
    [string]$StartState          = "PLAN"
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# BOOTSTRAP — paths, config, bridge, helpers
# ---------------------------------------------------------------------------

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = $scriptDir | Split-Path -Parent | Split-Path -Parent

$bridgePath = Join-Path $scriptDir "agent_bridge.ps1"
if (-not (Test-Path $bridgePath)) {
    Write-Error "[Orchestrator] FATAL: agent_bridge.ps1 not found at $bridgePath"
    exit 1
}
. $bridgePath

$helpersPath = Join-Path $scriptDir "orchestrator_v2_helpers.ps1"
if (-not (Test-Path $helpersPath)) {
    Write-Error "[Orchestrator] FATAL: orchestrator_v2_helpers.ps1 not found at $helpersPath"
    exit 1
}
. $helpersPath

$configPath    = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir     = Join-Path $scriptDir "status"
$loopsDir      = Join-Path $scriptDir "loops"
$logsDir       = Join-Path $scriptDir "logs"
$queuePath     = Join-Path $statusDir "feature_queue.json"
$sessionPath   = Join-Path $statusDir "session.json"
$metricsLatest = Join-Path $statusDir "metrics_latest.json"

foreach ($dir in @($statusDir, $logsDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$config = $null
try {
    $config = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
} catch {
    Write-Warning "[Orchestrator] config not found at $configPath — using defaults"
}
$claudeExe   = if ($config?.claude_exe)              { $config.claude_exe }              else { "claude" }
$claudeModel = if ($config?.claude_model)            { $config.claude_model }            else { "claude-sonnet-4-6" }
$permMode    = if ($config?.claude_permission_mode)  { $config.claude_permission_mode }  else { "default" }

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  M.E.R.L.I.N. Orchestrator v2.0 — State Machine            ║" -ForegroundColor Cyan
Write-Host "║  MaxCycles=$MaxCycles  DryRun=$($DryRun.IsPresent)  OneShot=$($OneShot.IsPresent)  Start=$StartState" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# MAIN STATE MACHINE — runtime variables
# ---------------------------------------------------------------------------

$cycleNumber          = 0
$state                = $StartState
$continueLoop         = $true
$currentTasks         = @()
$cycleStart           = Get-Date
$lastValidationResult = "none"
$errorsFixed          = 0
$pendingDebugIssue    = $null
$pendingLoraIssue     = $null
$pendingAssetIssue    = $null
$blockedQuestion      = $null
$lastValidationError  = $null

# Restore cycle counter from previous session
if (Test-Path $sessionPath) {
    try {
        $prevSess = Get-Content $sessionPath -Raw | ConvertFrom-Json
        if ($prevSess.cycle) { $cycleNumber = [int]$prevSess.cycle }
    } catch {}
}

Update-AgentStatus -AgentName "orchestrator" -State "running" -AdditionalFields @{
    start_state = $StartState
    dry_run     = $DryRun.IsPresent
}

# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------

while ($continueLoop -and $cycleNumber -lt $MaxCycles) {

    switch ($state) {

        # ── IDLE ─────────────────────────────────────────────────────────────
        "IDLE" {
            $pending = Get-PendingTasks
            if ($pending.Count -eq 0) {
                Write-Host "[Orchestrator] No pending tasks. Waiting..." -ForegroundColor Gray
                Update-SessionState -State "IDLE" -Cycle $cycleNumber -Objective "No pending tasks — waiting"
                if ($OneShot) { $continueLoop = $false; break }
                Start-Sleep -Seconds 30
                break
            }
            $state = "PLAN"
        }

        # ── PLAN ─────────────────────────────────────────────────────────────
        "PLAN" {
            $cycleNumber++
            $cycleStart = Get-Date
            Write-Host ""
            Write-Host "[Orchestrator] ===== CYCLE $cycleNumber =====" -ForegroundColor Cyan

            Update-SessionState -State "PLAN" -Cycle $cycleNumber
            Update-AgentStatus -AgentName "orchestrator" -State "running" -AdditionalFields @{
                cycle = $cycleNumber; current_task = "planning"
            }
            Archive-OldMessages

            $currentTasks = @(Select-NextTasks -MaxTasks 2)
            if ($currentTasks.Count -eq 0) { $state = "IDLE"; break }

            foreach ($task in $currentTasks) { Set-TaskStatus -TaskId $task.id -Status "in_progress" }

            $taskTitles = ($currentTasks | ForEach-Object { $_.title }) -join ", "
            Write-Host "[Orchestrator] Planning: $taskTitles" -ForegroundColor Yellow
            $state = "BUILD"
        }

        # ── BUILD ─────────────────────────────────────────────────────────────
        "BUILD" {
            Update-SessionState -State "BUILD" -Cycle $cycleNumber

            foreach ($task in $currentTasks) {
                Write-Host "[Orchestrator] Building: $($task.title) via $($task.agent ?? 'godot_expert')" -ForegroundColor Yellow
                if (-not $DryRun) {
                    $prompt    = Build-TaskPrompt -Task $task
                    $agentName = if ($task.agent) { $task.agent } else { "godot_expert" }
                    Invoke-ClaudeAgent -AgentName $agentName -Prompt $prompt | Out-Null
                    Set-TaskStatus -TaskId $task.id -Status "built"
                } else {
                    Write-Host "[Orchestrator] [DRY-RUN] BUILD skipped for $($task.id)" -ForegroundColor Yellow
                }
            }
            $state = "VALIDATE"
        }

        # ── VALIDATE ──────────────────────────────────────────────────────────
        "VALIDATE" {
            Update-SessionState -State "VALIDATE" -Cycle $cycleNumber
            Write-Host "[Orchestrator] Running validate.bat..." -ForegroundColor Magenta

            $validateResult       = Invoke-Validation
            $lastValidationResult = if ($validateResult.Success) { "success" } else { "failed" }

            if ($validateResult.Success) {
                Write-Host "[Orchestrator] Validation passed ($($validateResult.WarningCount) warnings)" -ForegroundColor Green
                $state = "TEST"
            } else {
                Write-Host "[Orchestrator] Validation FAILED ($($validateResult.ErrorCount) errors) → DEBUG_LOOP" -ForegroundColor Red
                $lastValidationError = @{
                    type          = "validation_fail"
                    description   = "validate.bat returned $($validateResult.ErrorCount) error(s)"
                    error_log     = $validateResult.ErrorText
                    affected_file = ""
                }
                $state = "DEBUG_LOOP"
            }
        }

        # ── TEST ──────────────────────────────────────────────────────────────
        "TEST" {
            Update-SessionState -State "TEST" -Cycle $cycleNumber
            Write-Host "[Orchestrator] Running playtest QA..." -ForegroundColor Magenta

            if (-not $DryRun) {
                $playtestResult = Invoke-PlaytestSimulator
                $issues         = @(Detect-Issues -PlaytestResult $playtestResult)
                $routed         = $false

                foreach ($issue in $issues) {
                    switch ($issue.type) {
                        "llm_performance" {
                            Write-Host "[Orchestrator] LLM issue detected → LORA_WAIT (brain: $($issue.brain))" -ForegroundColor Yellow
                            $pendingLoraIssue = $issue; $state = "LORA_WAIT"; $routed = $true
                        }
                        { $_ -in @("visual_issue", "missing_asset") } {
                            Write-Host "[Orchestrator] Visual issue detected → ASSET_GEN" -ForegroundColor Yellow
                            $pendingAssetIssue = $issue; $state = "ASSET_GEN"; $routed = $true
                        }
                        { $_ -in @("code_bug", "runtime_crash") } {
                            Write-Host "[Orchestrator] Bug detected → DEBUG_LOOP" -ForegroundColor Yellow
                            $pendingDebugIssue = $issue; $state = "DEBUG_LOOP"; $routed = $true
                        }
                    }
                    if ($routed) { break }
                }

                if (-not $routed) {
                    Write-Host "[Orchestrator] All tests passed → REPORT" -ForegroundColor Green
                    $state = "REPORT"
                }
            } else {
                Write-Host "[Orchestrator] [DRY-RUN] TEST skipped → REPORT" -ForegroundColor Yellow
                $state = "REPORT"
            }
        }

        # ── LORA_WAIT ─────────────────────────────────────────────────────────
        "LORA_WAIT" {
            Update-SessionState -State "LORA_WAIT" -Cycle $cycleNumber
            Write-Host "[Orchestrator] Starting LoRA training for $($pendingLoraIssue.brain)..." -ForegroundColor Magenta

            $loraScript = Join-Path $loopsDir "lora_training_loop.ps1"
            if (Test-Path $loraScript) {
                $loraArgs  = "-Brain `"$($pendingLoraIssue.brain)`" -TriggerMetric `"$($pendingLoraIssue.metric)`""
                $loraArgs += " -TriggerValue $($pendingLoraIssue.value) -Threshold $($pendingLoraIssue.threshold)"
                if ($DryRun) { $loraArgs += " -DryRun" }
                $loraJob = Start-Process -FilePath "powershell" -ArgumentList "-File `"$loraScript`" $loraArgs" -PassThru
                Write-Host "[Orchestrator] LoRA training started (PID $($loraJob.Id)). Working on parallel tasks..." -ForegroundColor Gray
            } else {
                Write-Warning "[Orchestrator] lora_training_loop.ps1 not found — skipping"
            }

            Invoke-ParallelWork -ExcludeDependency "llm"

            $modelReady = Wait-ForMessage -Type "model_ready" -TimeoutMinutes 130 -PollSeconds 30
            if ($modelReady) {
                Write-Host "[Orchestrator] Model ready! Returning to TEST" -ForegroundColor Green
                $state = "TEST"
            } else {
                Write-Host "[Orchestrator] LoRA timeout/failed → REPORT (with warning)" -ForegroundColor Yellow
                $state = "REPORT"
            }
        }

        # ── ASSET_GEN ─────────────────────────────────────────────────────────
        "ASSET_GEN" {
            Update-SessionState -State "ASSET_GEN" -Cycle $cycleNumber
            $assetName = if ($pendingAssetIssue.asset_name) { $pendingAssetIssue.asset_name } else { "auto" }
            Write-Host "[Orchestrator] Starting asset generation for $assetName..." -ForegroundColor Magenta

            $assetScript = Join-Path $loopsDir "asset_generation_loop.ps1"
            if (Test-Path $assetScript) {
                $assetArgs  = "-AssetName `"$assetName`""
                $assetArgs += " -AssetDescription `"$($pendingAssetIssue.description ?? '')`""
                $assetArgs += " -AssetType `"$($pendingAssetIssue.asset_type ?? '3d_model')`""
                if ($DryRun) { $assetArgs += " -DryRun" }
                Start-Process -FilePath "powershell" -ArgumentList "-File `"$assetScript`" $assetArgs" -PassThru | Out-Null
            } else {
                Write-Warning "[Orchestrator] asset_generation_loop.ps1 not found — skipping"
            }

            $assetReady = Wait-ForMessage -Type "asset_ready" -TimeoutMinutes 20 -PollSeconds 15
            if ($assetReady) {
                Write-Host "[Orchestrator] Asset ready! Path: $($assetReady.payload.asset_path). Returning to TEST" -ForegroundColor Green
                $state = "TEST"
            } else {
                Write-Host "[Orchestrator] Asset gen timeout/failed → REPORT" -ForegroundColor Yellow
                $state = "REPORT"
            }
        }

        # ── DEBUG_LOOP ────────────────────────────────────────────────────────
        "DEBUG_LOOP" {
            Update-SessionState -State "DEBUG_LOOP" -Cycle $cycleNumber

            $issue     = if ($pendingDebugIssue) { $pendingDebugIssue } else { $lastValidationError }
            $issueType = if ($issue.type)         { $issue.type }        else { "validation_fail" }
            $issueDesc = if ($issue.description)  { $issue.description } else { "Unknown error" }
            $errorLog  = if ($issue.error_log)    { $issue.error_log }   else { "" }
            $affFile   = if ($issue.affected_file){ $issue.affected_file }else { "" }

            Write-Host "[Orchestrator] Launching debug loop for $issueType..." -ForegroundColor Magenta

            $debugScript = Join-Path $loopsDir "debug_loop.ps1"
            if (-not (Test-Path $debugScript)) {
                Write-Warning "[Orchestrator] debug_loop.ps1 not found — skipping, going to REPORT"
                $state = "REPORT"
                break
            }

            $safeLog   = $errorLog.Replace('"', '`"')
            $debugArgs = "-IssueType `"$issueType`" -IssueDescription `"$issueDesc`" -ErrorLog `"$safeLog`" -MaxIterations 10"
            if ($affFile) { $debugArgs += " -AffectedFile `"$affFile`"" }
            if ($DryRun)  { $debugArgs += " -DryRun" }

            $debugProcess = Start-Process -FilePath "powershell" `
                -ArgumentList "-File `"$debugScript`" $debugArgs" -PassThru -Wait

            if ($debugProcess.ExitCode -eq 0) {
                Write-Host "[Orchestrator] Debug loop converged → VALIDATE" -ForegroundColor Green
                $errorsFixed++
                $pendingDebugIssue = $null
                $state = "VALIDATE"
            } else {
                $userQuestion = Read-PendingMessages -Type "question_for_user" -ToAgent "orchestrator" | Select-Object -First 1
                if ($userQuestion) {
                    Write-Host "[Orchestrator] Debug escalated to user → BLOCKED" -ForegroundColor Red
                    $blockedQuestion = $userQuestion
                    $state = "BLOCKED"
                } else {
                    Write-Host "[Orchestrator] Debug failed without question → REPORT" -ForegroundColor Yellow
                    $state = "REPORT"
                }
            }
        }

        # ── BLOCKED ───────────────────────────────────────────────────────────
        "BLOCKED" {
            Update-SessionState -State "BLOCKED" -Cycle $cycleNumber -Objective "User input required"
            Update-AgentStatus -AgentName "orchestrator" -State "blocked" -AdditionalFields @{
                blocked_reason = $blockedQuestion.payload.question
            }

            Write-Host ""
            Write-Host "[Orchestrator] ===== BLOCKED — User input required =====" -ForegroundColor Red
            Write-Host $blockedQuestion.payload.question -ForegroundColor Yellow
            Write-Host ""

            $sess = @{
                state          = "blocked"
                objective      = "User input required"
                cycle          = $cycleNumber
                updated_at     = (Get-Date -Format "o")
                checkpoint     = "orchestrator_v2"
                blocked_reason = $blockedQuestion.payload.question
                workers        = @(@{ name = "orchestrator"; wave = 1; status = "blocked" })
            }
            $tmp = "$sessionPath.tmp"
            $sess | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
            Move-Item $tmp $sessionPath -Force

            Mark-MessageHandled -MessageId $blockedQuestion.id
            $state = "REPORT"
        }

        # ── REPORT ────────────────────────────────────────────────────────────
        "REPORT" {
            Update-SessionState -State "REPORT" -Cycle $cycleNumber

            foreach ($task in $currentTasks) {
                $finalStatus = if ($lastValidationResult -eq "success") { "completed" } else { "failed" }
                Set-TaskStatus -TaskId $task.id -Status $finalStatus
            }

            $filesModified = @(Get-FilesModifiedThisCycle)
            $kbScript = Join-Path $loopsDir "knowledge_recorder.ps1"
            if (Test-Path $kbScript) {
                & $kbScript `
                    -CycleNumber $cycleNumber `
                    -FilesModified $filesModified `
                    -ValidationResult $lastValidationResult `
                    -ErrorsFixed $errorsFixed 2>&1 | Out-Null
            }

            $reportPath = Generate-CycleReport -CycleNumber $cycleNumber -Tasks $currentTasks -StartTime $cycleStart

            Write-Host ""
            Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║  Cycle $cycleNumber complete." -ForegroundColor Green
            Write-Host "║  Report: $(Split-Path $reportPath -Leaf)" -ForegroundColor Green
            Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
            Write-Host ""

            # Reset per-cycle state
            $pendingDebugIssue   = $null
            $pendingLoraIssue    = $null
            $pendingAssetIssue   = $null
            $blockedQuestion     = $null
            $lastValidationError = $null
            $errorsFixed         = 0

            if ($OneShot) { $continueLoop = $false; break }
            $state = "IDLE"
        }

        default {
            Write-Warning "[Orchestrator] Unknown state '$state' — resetting to IDLE"
            $state = "IDLE"
        }
    }

    if ($CycleIntervalSeconds -gt 0 -and $continueLoop) {
        Start-Sleep -Seconds $CycleIntervalSeconds
    }
}

# ---------------------------------------------------------------------------
# SHUTDOWN
# ---------------------------------------------------------------------------

Update-AgentStatus -AgentName "orchestrator" -State "done" -AdditionalFields @{ final_cycle = $cycleNumber }
Update-SessionState -State "IDLE" -Cycle $cycleNumber -Objective "Orchestrator stopped after $cycleNumber cycle(s)"

Write-Host ""
Write-Host "[Orchestrator] Stopped after $cycleNumber cycle(s)." -ForegroundColor Cyan
