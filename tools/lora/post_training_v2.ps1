<#
.SYNOPSIS
    Post-training pipeline: merge + convert + deploy + benchmark
.DESCRIPTION
    Lancez ce script apres que le training v2 est termine.
    Il merge le LoRA adapter, le deploie sur Ollama, et lance un benchmark.
.USAGE
    powershell -ExecutionPolicy Bypass -File tools/lora/post_training_v2.ps1
#>
$ErrorActionPreference = "Continue"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$PYTHON = "C:\Users\PGNK2128\AppData\Local\Programs\Python\Python312\python.exe"
$SCRIPT = Join-Path $PROJECT_ROOT "tools\lora\overnight_v2.py"

Write-Host "=== M.E.R.L.I.N. Post-Training Pipeline ===" -ForegroundColor Cyan
Write-Host ""

# Check training status
$progressFile = Join-Path $PROJECT_ROOT "merlin-lora-cpu-output-v2\progress.json"
if (Test-Path $progressFile) {
    $progress = Get-Content $progressFile | ConvertFrom-Json
    Write-Host "  Training status: $($progress.status)" -ForegroundColor Yellow
    Write-Host "  Steps: $($progress.step) / $($progress.total_steps)"
    Write-Host "  Elapsed: $([math]::Round($progress.elapsed_sec / 3600, 1))h"
} else {
    Write-Host "  WARNING: No progress.json found. Training may still be running." -ForegroundColor Red
}

# Check for final adapter
$adapterDir = Join-Path $PROJECT_ROOT "merlin-lora-cpu-output-v2\final-adapter"
if (-not (Test-Path (Join-Path $adapterDir "adapter_config.json"))) {
    # Try latest checkpoint
    $checkpoints = Get-ChildItem -Path (Join-Path $PROJECT_ROOT "merlin-lora-cpu-output-v2") -Directory -Filter "checkpoint-*" -ErrorAction SilentlyContinue
    if ($checkpoints) {
        $latest = $checkpoints | Sort-Object { [int]($_.Name -replace "checkpoint-", "") } | Select-Object -Last 1
        $adapterDir = $latest.FullName
        Write-Host "  Using latest checkpoint: $adapterDir" -ForegroundColor Yellow
    } else {
        Write-Host "  ERROR: No adapter or checkpoint found!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Phase 4: Merge + Convert + Deploy ===" -ForegroundColor Cyan

# Run Phase 4: Convert
& $PYTHON $SCRIPT --phase convert 2>&1 | Tee-Object -FilePath (Join-Path $PROJECT_ROOT "tmp\lora_logs\post_training_convert.log")

Write-Host ""
Write-Host "=== Phase 5: Benchmark ===" -ForegroundColor Cyan

# Run Phase 5: Benchmark
& $PYTHON $SCRIPT --phase benchmark 2>&1 | Tee-Object -FilePath (Join-Path $PROJECT_ROOT "tmp\lora_logs\post_training_benchmark.log")

Write-Host ""
Write-Host "=== Pipeline Complete ===" -ForegroundColor Green
Write-Host "  Reports: $PROJECT_ROOT\output\lora_reports\"
Write-Host "  To test: ollama run merlin-narrator"
