# lora_training_loop.ps1 — LoRA Training Pipeline Manager for M.E.R.L.I.N. orchestrator v2
# Spawned by orchestrator when playtest_qa detects brain underperformance.
# Usage: .\lora_training_loop.ps1 -Brain narrator -TriggerMetric tone_consistency -TriggerValue 0.72 -Threshold 0.85

param(
    [Parameter(Mandatory)][string]$Brain,
    [Parameter(Mandatory)][string]$TriggerMetric,
    [Parameter(Mandatory)][float]$TriggerValue,
    [Parameter(Mandatory)][float]$Threshold,
    [int]$PollIntervalSeconds = 30,
    [int]$MaxWaitMinutes      = 120,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# STEP 0: Bootstrap
# ---------------------------------------------------------------------------

$autodevRoot = $PSScriptRoot | Split-Path -Parent          # loops → autodev
$projectRoot = $autodevRoot  | Split-Path -Parent | Split-Path -Parent  # autodev → tools → project root

$bridgePath = Join-Path $autodevRoot "agent_bridge.ps1"
if (-not (Test-Path $bridgePath)) {
    Write-Error "[LoRA] agent_bridge.ps1 not found at $bridgePath"
    exit 1
}
. $bridgePath

$memoryDir = Join-Path $autodevRoot "memory"
if (-not (Test-Path $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null }

$VALID_BRAINS = @("narrator", "gamemaster", "worker")
if ($Brain -notin $VALID_BRAINS) {
    Write-Error "[LoRA] Invalid brain '$Brain'. Must be one of: $($VALID_BRAINS -join ', ')"
    exit 1
}

# Brain → Kaggle kernel slug
$BRAIN_SLUG = @{
    narrator    = "merlin-lora-narrator-4b"
    gamemaster  = "merlin-lora-gamemaster-2b"
    worker      = "merlin-lora-worker-0.8b"
}

# Brain → adapter filename
$BRAIN_ADAPTER = @{
    narrator   = "merlin_narrator_lora.gguf"
    gamemaster = "merlin_gamemaster_lora.gguf"
    worker     = "merlin_worker_lora.gguf"
}

$kaggleSlug     = $BRAIN_SLUG[$Brain]
$adapterFilename = $BRAIN_ADAPTER[$Brain]
$stateFile      = Join-Path $projectRoot ".merlin_remote\kaggle\state.json"
$trainScript    = Join-Path $projectRoot "tools\lora\remote_kaggle_train.py"

Write-Host "[LoRA] START — brain: $Brain, trigger: $TriggerMetric = $TriggerValue (threshold: $Threshold)" -ForegroundColor Cyan

Update-AgentStatus -AgentName "lora_trainer" -State "running" -AdditionalFields @{
    brain    = $Brain
    progress = 0
}

# ---------------------------------------------------------------------------
# STEP 1: Pause Dependent Tasks
# ---------------------------------------------------------------------------

Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "broadcast" -Type "status_update" -Priority "HIGH" -Payload @{
    event                      = "lora_training_started"
    brain                      = $Brain
    action                     = "pause_dependent_tasks"
    estimated_duration_minutes = 60
}

Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "orchestrator" -Type "status_update" -Priority "HIGH" -Payload @{
    state          = "LORA_WAIT"
    brain          = $Brain
    trigger_metric = $TriggerMetric
    trigger_value  = $TriggerValue
    threshold      = $Threshold
    message        = "Starting LoRA training for $Brain brain. Dev tasks dependent on $Brain are paused."
}

# ---------------------------------------------------------------------------
# STEP 2: Launch Training
# ---------------------------------------------------------------------------

if (-not $DryRun) {
    Write-Host "[LoRA] Launching Kaggle training for $Brain ($kaggleSlug)..."
    $trainArgs    = @($trainScript, "--brain", $Brain, "--kernel-slug", $kaggleSlug, "--action", "start")
    $trainProcess = Start-Process -FilePath "python" -ArgumentList $trainArgs -PassThru -NoNewWindow

    Start-Sleep -Seconds 5

    if ($trainProcess.HasExited -and $trainProcess.ExitCode -ne 0) {
        Write-Error "[LoRA] Training launch failed (exit code $($trainProcess.ExitCode))"
        Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "orchestrator" -Type "issue_report" -Priority "CRITICAL" -Payload @{
            issue_type = "lora_launch_failed"
            brain      = $Brain
            error      = "Training process exited with code $($trainProcess.ExitCode)"
        }
        Update-AgentStatus -AgentName "lora_trainer" -State "error"
        exit 1
    }
} else {
    Write-Host "[LoRA] [DryRun] Would launch: python $trainScript --brain $Brain --kernel-slug $kaggleSlug --action start"
}

# ---------------------------------------------------------------------------
# STEP 3: Monitor Training
# ---------------------------------------------------------------------------

$maxIterations     = [int]($MaxWaitMinutes * 60 / $PollIntervalSeconds)
$monitorIteration  = 0
$kaggleStatus      = "running"

Write-Host "[LoRA] Monitoring Kaggle state (max $MaxWaitMinutes min, poll every ${PollIntervalSeconds}s)..."

while ($kaggleStatus -eq "running" -and $monitorIteration -lt $maxIterations) {
    Start-Sleep -Seconds $PollIntervalSeconds
    $monitorIteration++

    $progressPct = [int]([Math]::Min(95, ($monitorIteration / $maxIterations) * 100))
    Update-AgentStatus -AgentName "lora_trainer" -State "waiting" -AdditionalFields @{ progress = $progressPct }

    if (Test-Path $stateFile) {
        try {
            $state        = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $kaggleStatus = $state.status
            Write-Host "[LoRA] Kaggle status: $kaggleStatus (iteration $monitorIteration/$maxIterations, ~${progressPct}%)"
        } catch {
            Write-Warning "[LoRA] Failed to parse state file: $_"
        }
    } elseif ($DryRun) {
        if ($monitorIteration -ge 3) { $kaggleStatus = "completed" }
        Write-Host "[LoRA] [DryRun] Kaggle status: $kaggleStatus (iteration $monitorIteration/$maxIterations, ~${progressPct}%)"
    } else {
        Write-Warning "[LoRA] State file not found yet at $stateFile"
    }
}

# ---------------------------------------------------------------------------
# STEP 4: Handle Completion or Failure
# ---------------------------------------------------------------------------

$timedOut = ($monitorIteration -ge $maxIterations) -and ($kaggleStatus -eq "running")

if ($kaggleStatus -eq "completed") {
    Write-Host "[LoRA] COMPLETE — adapter deploying: $adapterFilename" -ForegroundColor Green

    # Read final metrics from state
    $metrics = @{}
    if (Test-Path $stateFile) {
        try {
            $finalState = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($finalState.metrics) { $metrics = $finalState.metrics }
        } catch {
            Write-Warning "[LoRA] Could not read final metrics: $_"
        }
    }

    # Deploy adapter
    $deployed = Invoke-AdapterDeploy -Brain $Brain -AdapterFilename $adapterFilename -ProjectRoot $projectRoot
    if (-not $deployed) {
        Write-Warning "[LoRA] Adapter deploy step had issues — check adapter directory"
    }

    $durationMin = [Math]::Round($monitorIteration * $PollIntervalSeconds / 60, 1)

    Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "orchestrator" -Type "model_ready" -Priority "HIGH" -Payload @{
        brain                    = $Brain
        adapter_path             = "addons/merlin_llm/adapters/$adapterFilename"
        metrics_before           = @{ $TriggerMetric = $TriggerValue }
        metrics_after            = $metrics
        improvement              = if ($metrics[$TriggerMetric]) { $metrics[$TriggerMetric] - $TriggerValue } else { $null }
        training_duration_minutes = $durationMin
    }

    # Resume tasks
    Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "broadcast" -Type "status_update" -Priority "MEDIUM" -Payload @{
        event  = "lora_training_completed"
        brain  = $Brain
        action = "resume_dependent_tasks"
    }

    Update-LoRAMemory -Brain $Brain -TriggerMetric $TriggerMetric -TriggerValue $TriggerValue `
        -MetricsAfter $metrics -DurationMin $durationMin -Outcome "success" -ProjectRoot $projectRoot

    Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "orchestrator" -Type "kb_entry" -Priority "LOW" -Payload @{
        type    = "lora_best_practice"
        title   = "LoRA training success: $Brain brain"
        pattern = "Triggered by $TriggerMetric=$TriggerValue below threshold=$Threshold"
        outcome = "Completed in ${durationMin}min with adapter $adapterFilename"
        tags    = @("lora", $Brain, $TriggerMetric)
    }

    Update-AgentStatus -AgentName "lora_trainer" -State "done" -AdditionalFields @{ progress = 100 }
    exit 0

} else {
    # Failed or timed out
    $reason = if ($timedOut) { "timeout after $MaxWaitMinutes minutes" } else { "Kaggle status: $kaggleStatus" }
    Write-Host "[LoRA] FAILED — escalating to orchestrator ($reason)" -ForegroundColor Red

    $question = "LoRA training for '$Brain' brain failed ($reason). " +
                "Trigger: $TriggerMetric=$TriggerValue (threshold=$Threshold). " +
                "Should I retry with different hyperparams, skip training, or use the previous adapter?"

    Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "orchestrator" -Type "issue_report" -Priority "CRITICAL" -Payload @{
        issue_type     = "lora_training_failed"
        brain          = $Brain
        trigger_metric = $TriggerMetric
        trigger_value  = $TriggerValue
        threshold      = $Threshold
        failure_reason = $reason
        question       = $question
    }

    Update-LoRAMemory -Brain $Brain -TriggerMetric $TriggerMetric -TriggerValue $TriggerValue `
        -MetricsAfter @{} -DurationMin ([Math]::Round($monitorIteration * $PollIntervalSeconds / 60, 1)) `
        -Outcome "failure" -ProjectRoot $projectRoot

    Update-AgentStatus -AgentName "lora_trainer" -State "error"
    exit 1
}

# ---------------------------------------------------------------------------
# STEP 5: Resume Orchestration (final broadcast — reached only on success path above)
# ---------------------------------------------------------------------------

Send-AgentMessage -FromAgent "lora_trainer" -ToAgent "broadcast" -Type "status_update" -Priority "MEDIUM" -Payload @{
    event  = "lora_training_completed"
    brain  = $Brain
    action = "resume_dependent_tasks"
}

# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

# Update-LoRAMemory — Persist training run metadata for future reference.
function Update-LoRAMemory {
    param(
        [string]$Brain,
        [string]$TriggerMetric,
        [float]$TriggerValue,
        [hashtable]$MetricsAfter,
        [float]$DurationMin,
        [string]$Outcome,
        [string]$ProjectRoot
    )

    $memFile = Join-Path $ProjectRoot "tools\autodev\memory\lora_trainer_memory.json"
    try {
        $mem = if (Test-Path $memFile) {
            Get-Content $memFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } else { $null }

        $runs = if ($mem -and $mem.runs) { [System.Collections.ArrayList]@($mem.runs) } else { [System.Collections.ArrayList]@() }

        [void]$runs.Add(@{
            brain          = $Brain
            trigger_metric = $TriggerMetric
            trigger_value  = $TriggerValue
            metrics_after  = $MetricsAfter
            duration_min   = $DurationMin
            outcome        = $Outcome
            timestamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        })

        $memHt = @{
            agent        = "lora_trainer"
            version      = "1.0"
            last_updated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            runs         = @($runs)
        }
        $memHt | ConvertTo-Json -Depth 10 | Set-Content -Path $memFile -Encoding UTF8
    } catch {
        Write-Warning "[LoRA] Could not update lora_trainer_memory.json: $_"
    }
}

# Get-BrainDatasetPath — Map brain name to training dataset file.
function Get-BrainDatasetPath {
    param([string]$Brain, [string]$ProjectRoot)

    $datasetMap = @{
        narrator   = "data\ai\training\narrator_dataset.jsonl"
        gamemaster = "data\ai\training\gamemaster_dataset.jsonl"
        worker     = "data\ai\training\worker_dataset.jsonl"
    }
    $relativePath = $datasetMap[$Brain]
    if (-not $relativePath) { return $null }
    return Join-Path $ProjectRoot $relativePath
}

# Invoke-AdapterDeploy — Copy .gguf adapter to the addons adapter directory.
function Invoke-AdapterDeploy {
    param(
        [string]$Brain,
        [string]$AdapterFilename,
        [string]$ProjectRoot
    )

    $adapterDestDir = Join-Path $ProjectRoot "addons\merlin_llm\adapters"
    if (-not (Test-Path $adapterDestDir)) {
        New-Item -ItemType Directory -Path $adapterDestDir -Force | Out-Null
    }

    # Kaggle output lands in .merlin_remote/kaggle/ by convention
    $srcFile = Join-Path $ProjectRoot ".merlin_remote\kaggle\$AdapterFilename"
    $dstFile = Join-Path $adapterDestDir $AdapterFilename

    if ($DryRun) {
        Write-Host "[LoRA] [DryRun] Would copy: $srcFile → $dstFile"
        return $true
    }

    if (-not (Test-Path $srcFile)) {
        Write-Warning "[LoRA] Adapter source not found: $srcFile — skipping copy"
        return $false
    }

    try {
        Copy-Item -Path $srcFile -Destination $dstFile -Force
        Write-Host "[LoRA] Adapter deployed: $dstFile"
        return $true
    } catch {
        Write-Warning "[LoRA] Adapter deploy failed: $_"
        return $false
    }
}
