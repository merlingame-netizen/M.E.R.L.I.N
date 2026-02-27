# M.E.R.L.I.N. — Training Control Script
# Controle Start/Stop/Pause/Resume + Scheduler Windows nuit
#
# Usage:
#   .\tools\lora\train_control.ps1 -Action Start
#   .\tools\lora\train_control.ps1 -Action Start -StopAt 08:00 -Resume
#   .\tools\lora\train_control.ps1 -Action Stop
#   .\tools\lora\train_control.ps1 -Action Pause
#   .\tools\lora\train_control.ps1 -Action Resume
#   .\tools\lora\train_control.ps1 -Action Status
#   .\tools\lora\train_control.ps1 -Action Schedule    # Installe le scheduler 00h-08h
#   .\tools\lora\train_control.ps1 -Action Unschedule  # Desinstalle le scheduler

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start","Stop","Pause","Resume","Status","Schedule","Unschedule")]
    [string]$Action,

    [string]$StopAt = "08:00",        # Heure d'arret automatique (HH:MM)
    [int]$Epochs    = 3,              # Nombre d'epochs
    [int]$Cores     = 6,              # Limite CPU affinity (0=all)
    [string]$Dataset = "",            # Override dataset path
    [switch]$Resume,                  # Reprendre depuis le dernier checkpoint
    [switch]$ExportGguf               # Exporter GGUF apres training
)

# ── Paths ────────────────────────────────────────────────────────────────────
$PROJECT_ROOT  = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$TRAIN_SCRIPT  = Join-Path $PSScriptRoot "train_qwen_cpu.py"
$OUTPUT_DIR    = Join-Path $PROJECT_ROOT "merlin-lora-cpu-output"
$STATUS_DIR    = Join-Path $PSScriptRoot "status"
$STATE_FILE    = Join-Path $STATUS_DIR "training_state.json"
$PID_FILE      = Join-Path $STATUS_DIR "training.pid"
$STOP_FLAG     = Join-Path $OUTPUT_DIR "training_stop.flag"
$PROGRESS_FILE = Join-Path $OUTPUT_DIR "progress.json"
$TASK_NAME     = "MERLIN_Training_Nightly"

# Create dirs
New-Item -ItemType Directory -Force -Path $STATUS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-State($state, $pid_val = 0, $reason = $null) {
    $obj = [ordered]@{
        state      = $state
        pid        = $pid_val
        stop_at    = $StopAt
        started_at = if ($state -eq "running") { (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") } else { $null }
        reason     = $reason
        updated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    }
    $obj | ConvertTo-Json | Set-Content $STATE_FILE -Encoding UTF8
}

function Read-State {
    if (-not (Test-Path $STATE_FILE)) { return $null }
    try { return Get-Content $STATE_FILE -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Read-Progress {
    if (-not (Test-Path $PROGRESS_FILE)) { return $null }
    try { return Get-Content $PROGRESS_FILE -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Get-TrainingProcess {
    if (-not (Test-Path $PID_FILE)) { return $null }
    try {
        $pid_val = [int](Get-Content $PID_FILE -Raw).Trim()
        return Get-Process -Id $pid_val -ErrorAction SilentlyContinue
    } catch { return $null }
}

function Format-Eta($eta_sec) {
    if (-not $eta_sec -or $eta_sec -le 0) { return "--" }
    $h = [int]($eta_sec / 3600)
    $m = [int](($eta_sec % 3600) / 60)
    if ($h -gt 0) { return "${h}h${m}min" } else { return "${m}min" }
}

function Show-Bar($pct, $width = 30) {
    $filled = [int]($pct / 100 * $width)
    $bar = "#" * $filled + "." * ($width - $filled)
    return "[$bar] $([math]::Round($pct,1))%"
}

# ── ACTION: Start ─────────────────────────────────────────────────────────────
if ($Action -eq "Start") {
    # Check double-start
    $proc = Get-TrainingProcess
    if ($proc) {
        Write-Host "[MERLIN Training] DEJA EN COURS (PID $($proc.Id)) — utilisez -Action Status" -ForegroundColor Yellow
        exit 1
    }

    # Clean stale flag
    if (Test-Path $STOP_FLAG) { Remove-Item $STOP_FLAG -Force }

    # Build python args
    $pyArgs = @($TRAIN_SCRIPT, "--output-dir", $OUTPUT_DIR, "--epochs", $Epochs, "--cores", $Cores, "--low-priority")
    if ($StopAt)    { $pyArgs += @("--stop-at", $StopAt) }
    if ($Resume)    { $pyArgs += "--resume" }
    if ($Dataset)   { $pyArgs += @("--dataset", $Dataset) }
    if ($ExportGguf){ $pyArgs += "--export-gguf" }

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MERLIN LoRA Training — DEMARRAGE" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Epochs   : $Epochs" -ForegroundColor White
    Write-Host "  Cores    : $Cores" -ForegroundColor White
    Write-Host "  Stop-at  : $StopAt (arret automatique)" -ForegroundColor White
    Write-Host "  Resume   : $Resume" -ForegroundColor White
    Write-Host "  Output   : $OUTPUT_DIR" -ForegroundColor White
    Write-Host "  Stop     : .\tools\lora\train_control.ps1 -Action Stop" -ForegroundColor Gray
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Launch detached
    $proc = Start-Process -FilePath "python" -ArgumentList $pyArgs `
        -WorkingDirectory $PROJECT_ROOT `
        -WindowStyle Hidden -PassThru

    if (-not $proc) {
        Write-Host "[ERROR] Impossible de lancer Python" -ForegroundColor Red
        Write-State "error" 0 "launch_failed"
        exit 1
    }

    $proc.Id | Set-Content $PID_FILE -Encoding UTF8
    Write-State "running" $proc.Id
    Write-Host "  Training lance (PID $($proc.Id))" -ForegroundColor Green
    Write-Host "  Watcher: python tools/lora/train_watcher.py --output-dir $OUTPUT_DIR" -ForegroundColor Gray
    Write-Host ""
}

# ── ACTION: Stop ──────────────────────────────────────────────────────────────
elseif ($Action -eq "Stop") {
    $proc = Get-TrainingProcess
    if (-not $proc) {
        Write-Host "[MERLIN Training] Aucun process actif" -ForegroundColor Yellow
        Write-State "idle" 0 "manual_stop"
        if (Test-Path $PID_FILE) { Remove-Item $PID_FILE -Force }
        exit 0
    }
    Write-Host "[MERLIN Training] Arret propre demande (flag file)..." -ForegroundColor Yellow
    # Write stop flag — StopCallback in train_qwen_cpu.py will detect it and save checkpoint
    "stop" | Set-Content $STOP_FLAG -Encoding UTF8
    Write-Host "  Flag ecrit: $STOP_FLAG" -ForegroundColor Gray
    Write-Host "  Le training va terminer le step courant et sauvegarder le checkpoint." -ForegroundColor Gray

    # Wait up to 120s for graceful stop
    $waited = 0
    while ($proc -and -not $proc.HasExited -and $waited -lt 120) {
        Start-Sleep -Seconds 5
        $waited += 5
        Write-Host "  Attente arret... ${waited}s" -ForegroundColor DarkGray
        $proc = Get-TrainingProcess
    }

    if ($proc -and -not $proc.HasExited) {
        Write-Host "  Timeout — arret force..." -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $PID_FILE) { Remove-Item $PID_FILE -Force }
    if (Test-Path $STOP_FLAG) { Remove-Item $STOP_FLAG -Force }
    Write-State "stopped" 0 "manual_stop"
    Write-Host "  Training arrete." -ForegroundColor Green
}

# ── ACTION: Pause ─────────────────────────────────────────────────────────────
elseif ($Action -eq "Pause") {
    $proc = Get-TrainingProcess
    if (-not $proc) { Write-Host "[MERLIN Training] Aucun process actif" -ForegroundColor Yellow; exit 1 }
    try {
        $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
        Write-Host "[MERLIN Training] Priorite reduite a IDLE (pause simulee)" -ForegroundColor Yellow
        Write-State "paused" $proc.Id
    } catch {
        Write-Host "[ERROR] Impossible de pauser: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ── ACTION: Resume ────────────────────────────────────────────────────────────
elseif ($Action -eq "Resume") {
    $proc = Get-TrainingProcess
    if (-not $proc) { Write-Host "[MERLIN Training] Aucun process actif" -ForegroundColor Yellow; exit 1 }
    try {
        $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
        Write-Host "[MERLIN Training] Priorite restauree a BelowNormal" -ForegroundColor Green
        Write-State "running" $proc.Id
    } catch {
        Write-Host "[ERROR] Impossible de reprendre: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ── ACTION: Status ────────────────────────────────────────────────────────────
elseif ($Action -eq "Status") {
    $state   = Read-State
    $prog    = Read-Progress
    $proc    = Get-TrainingProcess

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MERLIN LoRA Training — STATUS" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan

    if ($proc) {
        Write-Host "  Process  : PID $($proc.Id) — $($proc.PriorityClass)" -ForegroundColor Green
    } else {
        Write-Host "  Process  : ARRETE" -ForegroundColor Red
    }

    if ($state) {
        $stateColor = if ($state.state -eq "running") { "Green" } elseif ($state.state -eq "stopped") { "Yellow" } else { "Gray" }
        Write-Host "  Etat     : $($state.state.ToUpper())" -ForegroundColor $stateColor
        Write-Host "  Stop-at  : $($state.stop_at)" -ForegroundColor White
    }

    if ($prog) {
        Write-Host ""
        Write-Host "  Epoch    : $($prog.epoch)/$($prog.total_epochs)" -ForegroundColor White
        Write-Host "  Step     : $($prog.step)/$($prog.total_steps)" -ForegroundColor White
        Write-Host "  Progress : $(Show-Bar $prog.pct)" -ForegroundColor White
        Write-Host "  Loss     : $($prog.loss)" -ForegroundColor White
        Write-Host "  ETA      : $(Format-Eta $prog.eta_sec)" -ForegroundColor White
        Write-Host "  Timestamp: $($prog.timestamp)" -ForegroundColor Gray
        if ($prog.reason) { Write-Host "  Raison   : $($prog.reason)" -ForegroundColor Yellow }
    }

    # Scheduler
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host ""
        Write-Host "  Scheduler: ACTIF — $($task.Triggers[0].StartBoundary) (quotidien 00h→08h)" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "  Scheduler: inactif (.\tools\lora\train_control.ps1 -Action Schedule)" -ForegroundColor Gray
    }

    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ── ACTION: Schedule ──────────────────────────────────────────────────────────
elseif ($Action -eq "Schedule") {
    # Unregister existing if any
    $existing = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
        Write-Host "  Ancienne tache supprimee." -ForegroundColor Gray
    }

    # Script to run nightly
    $trainArgs = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Action Start -StopAt $StopAt -Resume"

    $action_task = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument $trainArgs `
        -WorkingDirectory $PROJECT_ROOT

    # Trigger: daily at midnight
    $trigger = New-ScheduledTaskTrigger -Daily -At "00:00"

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 9)

    Register-ScheduledTask `
        -TaskName $TASK_NAME `
        -Action $action_task `
        -Trigger $trigger `
        -Settings $settings `
        -Description "M.E.R.L.I.N. LoRA training nightly 00h00->$StopAt" `
        -Force | Out-Null

    Write-Host ""
    Write-Host "  [OK] Scheduler installe: $TASK_NAME" -ForegroundColor Green
    Write-Host "  Declenchement: tous les jours a 00h00" -ForegroundColor White
    Write-Host "  Arret auto   : $StopAt" -ForegroundColor White
    Write-Host "  Verifie: Get-ScheduledTask -TaskName '$TASK_NAME'" -ForegroundColor Gray
    Write-Host "  Desactive: .\tools\lora\train_control.ps1 -Action Unschedule" -ForegroundColor Gray
    Write-Host ""
}

# ── ACTION: Unschedule ────────────────────────────────────────────────────────
elseif ($Action -eq "Unschedule") {
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
        Write-Host "  [OK] Scheduler $TASK_NAME supprime." -ForegroundColor Green
    } else {
        Write-Host "  Scheduler $TASK_NAME non trouve (deja supprime?)." -ForegroundColor Yellow
    }
}
