# start_bitnet_brains.ps1 — Lance N instances llama-server.exe pour le swarm BitNet
# Usage:
#   .\tools\start_bitnet_brains.ps1              # Defaut: 2 brains (Narrator + GM)
#   .\tools\start_bitnet_brains.ps1 -Brains 4    # 4 brains (Narrator + GM + 2 Workers)
#   .\tools\start_bitnet_brains.ps1 -Stop        # Arrete tous les llama-server.exe

param(
    [int]$Brains = 2,
    [switch]$Stop
)

$ErrorActionPreference = "Stop"

# ── Paths ─────────────────────────────────────────────────────────────────────
$LLAMA_SERVER = "C:\Users\PGNK2128\BitNet\build\bin\llama-server.exe"
$MODEL_FALCON = "C:\Users\PGNK2128\BitNet\models\Falcon3-7B-Instruct-1.58bit\ggml-model-i2_s.gguf"
$MODEL_BITNET = "C:\Users\PGNK2128\BitNet\models\BitNet-b1.58-2B-4T\ggml-model-i2_s.gguf"
$BASE_PORT = 8081

# ── Brain Configurations ──────────────────────────────────────────────────────
# Each brain: [role, model_path, threads, n_ctx, port_offset]
$BRAIN_CONFIGS = @(
    @{ Role="Narrator";     Model=$MODEL_FALCON; Threads=3; NCtx=1024 }
    @{ Role="GameMaster";   Model=$MODEL_BITNET;  Threads=2; NCtx=512  }
    @{ Role="Worker1";      Model=$MODEL_BITNET;  Threads=2; NCtx=512  }
    @{ Role="Worker2";      Model=$MODEL_BITNET;  Threads=1; NCtx=256  }
)

# ── Stop Mode ─────────────────────────────────────────────────────────────────
if ($Stop) {
    Write-Host "[BitNet] Stopping all llama-server.exe processes..." -ForegroundColor Yellow
    $procs = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force
        Write-Host "[BitNet] Stopped $($procs.Count) process(es)" -ForegroundColor Green
    } else {
        Write-Host "[BitNet] No llama-server processes found" -ForegroundColor Gray
    }
    exit 0
}

# ── Validate ──────────────────────────────────────────────────────────────────
if (-not (Test-Path $LLAMA_SERVER)) {
    Write-Host "[ERROR] llama-server.exe not found: $LLAMA_SERVER" -ForegroundColor Red
    exit 1
}

$Brains = [Math]::Clamp($Brains, 1, 4)

# Kill existing instances first
$existing = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[BitNet] Killing $($existing.Count) existing llama-server process(es)..." -ForegroundColor Yellow
    $existing | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# ── Launch Brains ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BitNet Brain Swarm — $Brains brain(s)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$pids = @()
$totalRAM = 0

for ($i = 0; $i -lt $Brains; $i++) {
    $cfg = $BRAIN_CONFIGS[$i]
    $port = $BASE_PORT + $i

    if (-not (Test-Path $cfg.Model)) {
        Write-Host "[Brain $($i+1)] SKIP — model not found: $($cfg.Model)" -ForegroundColor Red
        continue
    }

    $modelName = Split-Path $cfg.Model -Leaf
    $ramEstimate = if ($cfg.Model -eq $MODEL_FALCON) { "~3.3 GB" } else { "~1.9 GB" }

    Write-Host "[Brain $($i+1)] $($cfg.Role) — port $port — $modelName ($ramEstimate)" -ForegroundColor White

    $args = @(
        "-m", $cfg.Model,
        "--port", $port,
        "--host", "127.0.0.1",
        "-t", $cfg.Threads,
        "-c", $cfg.NCtx,
        "--log-disable"
    )

    $proc = Start-Process -FilePath $LLAMA_SERVER -ArgumentList $args -PassThru -WindowStyle Minimized
    $pids += $proc.Id
    $totalRAM += if ($cfg.Model -eq $MODEL_FALCON) { 3300 } else { 1900 }

    Write-Host "         PID $($proc.Id) — threads=$($cfg.Threads), n_ctx=$($cfg.NCtx)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Total estimated RAM: ~$([Math]::Round($totalRAM / 1024, 1)) GB" -ForegroundColor Cyan
Write-Host ""

# ── Health Check (wait for servers to load models) ────────────────────────────
Write-Host "[BitNet] Waiting for health checks..." -ForegroundColor Yellow
$maxWait = 60  # seconds
$startTime = Get-Date

for ($i = 0; $i -lt $Brains; $i++) {
    $port = $BASE_PORT + $i
    $role = $BRAIN_CONFIGS[$i].Role
    $healthy = $false

    while (-not $healthy) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        if ($elapsed -gt $maxWait) {
            Write-Host "[Brain $($i+1)] TIMEOUT after ${maxWait}s — port $port" -ForegroundColor Red
            break
        }

        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2 -ErrorAction Stop
            if ($resp.status -eq "ok") {
                $healthy = $true
                Write-Host "[Brain $($i+1)] $role — HEALTHY (port $port)" -ForegroundColor Green
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Swarm ready — launch Godot now" -ForegroundColor Green
Write-Host "  Stop: .\tools\start_bitnet_brains.ps1 -Stop" -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PIDs: $($pids -join ', ')" -ForegroundColor DarkGray
