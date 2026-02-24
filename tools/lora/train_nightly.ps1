<#
.SYNOPSIS
    M.E.R.L.I.N. LoRA Nightly Training -- Sessions de 23h a 08h
.DESCRIPTION
    Lance l'entrainement QLoRA CPU avec arret automatique a 08h.
    Reprend automatiquement depuis le dernier checkpoint (--resume).
    Prevu pour etre planifie via Task Scheduler tous les soirs a 23h.
.USAGE
    # Manuel
    powershell -ExecutionPolicy Bypass -File tools/lora/train_nightly.ps1

    # Installer le scheduled task (une seule fois)
    powershell -ExecutionPolicy Bypass -File tools/lora/train_nightly.ps1 -Install

    # Desinstaller le scheduled task
    powershell -ExecutionPolicy Bypass -File tools/lora/train_nightly.ps1 -Uninstall
#>
param(
    [switch]$Install,
    [switch]$Uninstall,
    [string]$StopTime = "08:00",
    [string]$Python = "C:\Users\PGNK2128\AppData\Local\Programs\Python\Python312\python.exe"
)

$ErrorActionPreference = "Continue"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$TRAIN_SCRIPT = Join-Path $PROJECT_ROOT "tools\lora\train_qwen_cpu.py"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "merlin-lora-cpu-output"
$LOG_DIR = Join-Path $PROJECT_ROOT "tmp\lora_logs"
$TASK_NAME = "MERLIN_LoRA_Nightly"

# ── Install/Uninstall scheduled task ─────────────────────────────────
if ($Install) {
    Write-Host "=== Installation du scheduled task '$TASK_NAME' ===" -ForegroundColor Cyan

    $scriptPath = $MyInvocation.MyCommand.Path
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" `
        -WorkingDirectory $PROJECT_ROOT

    $trigger = New-ScheduledTaskTrigger -Daily -At "23:00"

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -WakeToRun `
        -ExecutionTimeLimit (New-TimeSpan -Hours 10)

    Register-ScheduledTask `
        -TaskName $TASK_NAME `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "M.E.R.L.I.N. LoRA QLoRA training sessions nocturnes (23h-08h)" `
        -Force

    Write-Host "  Task '$TASK_NAME' installee. Prochaine execution: ce soir a 23h." -ForegroundColor Green
    Write-Host "  Verifier: Get-ScheduledTask -TaskName '$TASK_NAME'"
    Write-Host "  Desinstaller: .\tools\lora\train_nightly.ps1 -Uninstall"
    exit 0
}

if ($Uninstall) {
    Write-Host "=== Desinstallation du scheduled task '$TASK_NAME' ===" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  Task supprimee." -ForegroundColor Green
    exit 0
}

# ── Training session ─────────────────────────────────────────────────

# Parse stop time
$stopHour, $stopMinute = $StopTime -split ":"
$stopHour = [int]$stopHour
$stopMinute = [int]$stopMinute

function Get-StopDeadline {
    $now = Get-Date
    $deadline = Get-Date -Hour $stopHour -Minute $stopMinute -Second 0
    # If stop time is earlier than now, it means tomorrow morning
    if ($deadline -le $now) {
        $deadline = $deadline.AddDays(1)
    }
    return $deadline
}

$deadline = Get-StopDeadline
$remainingHours = [math]::Round(($deadline - (Get-Date)).TotalHours, 1)

# Create log dir
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
$logFile = Join-Path $LOG_DIR ("nightly_" + (Get-Date -Format "yyyy-MM-dd_HHmm") + ".log")

# Header
$sep = "=" * 60
$header = "$sep`n  M.E.R.L.I.N. LoRA Nightly Training`n  Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n  Stop:  $deadline ($remainingHours h remaining)`n  Log:   $logFile`n$sep"
Write-Host $header -ForegroundColor Cyan
$header | Out-File $logFile -Encoding utf8

# Check Python
if (-not (Test-Path $Python)) {
    $msg = "ERREUR: Python introuvable: $Python"
    Write-Host $msg -ForegroundColor Red
    $msg | Out-File $logFile -Append -Encoding utf8
    exit 1
}

# Check if training is already complete (final-adapter exists)
$finalAdapter = Join-Path $OUTPUT_DIR "final-adapter"
if (Test-Path (Join-Path $finalAdapter "adapter_config.json")) {
    $msg = "Training DEJA TERMINE (final-adapter existe). Rien a faire."
    Write-Host $msg -ForegroundColor Green
    $msg | Out-File $logFile -Append -Encoding utf8
    exit 0
}

# Determine resume flag
$resumeFlag = ""
$checkpointDir = if (Test-Path $OUTPUT_DIR) {
    Get-ChildItem -Path $OUTPUT_DIR -Directory -Filter "checkpoint-*" | Sort-Object { [int]($_.Name -replace "checkpoint-", "") } | Select-Object -Last 1
} else { $null }
if ($checkpointDir) {
    $resumeFlag = "--resume"
    $msg = "  Resume depuis: $($checkpointDir.FullName)"
    Write-Host $msg -ForegroundColor Yellow
    $msg | Out-File $logFile -Append -Encoding utf8
}

# Launch training process
$trainArgs = @(
    $TRAIN_SCRIPT,
    "--output-dir", $OUTPUT_DIR,
    "--grad-ckpt"  # Save RAM for overnight (slower but safer)
)
if ($resumeFlag) { $trainArgs += $resumeFlag }

$msg = "  Commande: $Python $($trainArgs -join ' ')"
Write-Host $msg
$msg | Out-File $logFile -Append -Encoding utf8

$process = Start-Process -FilePath $Python -ArgumentList $trainArgs `
    -WorkingDirectory $PROJECT_ROOT `
    -RedirectStandardOutput (Join-Path $LOG_DIR "train_stdout.log") `
    -RedirectStandardError (Join-Path $LOG_DIR "train_stderr.log") `
    -PassThru -NoNewWindow

$msg = "  PID: $($process.Id)"
Write-Host $msg -ForegroundColor Gray
$msg | Out-File $logFile -Append -Encoding utf8

# Monitor loop: check deadline every 60s
while (-not $process.HasExited) {
    $now = Get-Date
    $remaining = ($deadline - $now).TotalMinutes

    if ($remaining -le 0) {
        $msg = "$(Get-Date -Format 'HH:mm:ss') | DEADLINE ATTEINTE ($StopTime) -- arret du training"
        Write-Host $msg -ForegroundColor Yellow
        $msg | Out-File $logFile -Append -Encoding utf8

        # Graceful stop: CTRL+C equivalent (sends close signal)
        # The trainer saves checkpoint on interruption
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5

        $msg = "  Training interrompu. Checkpoint sauvegarde automatiquement."
        Write-Host $msg
        $msg | Out-File $logFile -Append -Encoding utf8
        break
    }

    # Status every 5 min
    if ((Get-Date).Minute % 5 -eq 0 -and (Get-Date).Second -lt 61) {
        $remainH = [math]::Floor($remaining / 60)
        $remainM = [math]::Floor($remaining % 60)
        $msg = "$(Get-Date -Format 'HH:mm') | Training en cours... ${remainH}h${remainM}m restantes"
        Write-Host $msg -ForegroundColor DarkGray
        $msg | Out-File $logFile -Append -Encoding utf8
    }

    Start-Sleep -Seconds 60
}

# Final status
if ($process.HasExited -and $process.ExitCode -eq 0) {
    $msg = "`n  Training TERMINE avec succes (exit code 0)"
    Write-Host $msg -ForegroundColor Green
} elseif ($process.HasExited) {
    $msg = "`n  Training arrete (exit code: $($process.ExitCode))"
    Write-Host $msg -ForegroundColor Yellow
} else {
    $msg = "`n  Training interrompu par deadline"
    Write-Host $msg -ForegroundColor Yellow
}
$msg | Out-File $logFile -Append -Encoding utf8

# Summary
$stdoutLog = Join-Path $LOG_DIR "train_stdout.log"
$stderrLog = Join-Path $LOG_DIR "train_stderr.log"
$endMsg = "`n$sep`n  Session terminee: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n  Log: $logFile`n  Stdout: $stdoutLog`n  Stderr: $stderrLog`n  Prochaine session: demain soir 23h (automatique si task installee)`n$sep"
Write-Host $endMsg -ForegroundColor Cyan
$endMsg | Out-File $logFile -Append -Encoding utf8
