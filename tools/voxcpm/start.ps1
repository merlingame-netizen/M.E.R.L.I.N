<#
.SYNOPSIS
    Start the VoxCPM local TTS server from its venv.

.DESCRIPTION
    Reads tools/voxcpm/config.json (if present) to seed VOXCPM_* env vars, then
    launches server.py with the venv's Python. Env vars already set in the shell
    take precedence over config.json (so you can override per-run).
#>
param(
    [string]$Model,
    [string]$Device,
    [int]$Port
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$venv = Join-Path $here ".venv-voxcpm"
$vpy = Join-Path $venv "Scripts\python.exe"

if (-not (Test-Path $vpy)) {
    Write-Host "[VoxCPM] venv not found. Run install.bat first." -ForegroundColor Red
    exit 1
}

# Seed from config.json (only for keys not already in the environment).
$cfgPath = Join-Path $here "config.json"
if (Test-Path $cfgPath) {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    if (-not $env:VOXCPM_MODEL -and $cfg.model)               { $env:VOXCPM_MODEL = $cfg.model }
    if (-not $env:VOXCPM_DEVICE -and $cfg.device)             { $env:VOXCPM_DEVICE = $cfg.device }
    if (-not $env:VOXCPM_HOST -and $cfg.host)                 { $env:VOXCPM_HOST = $cfg.host }
    if (-not $env:VOXCPM_PORT -and $cfg.port)                 { $env:VOXCPM_PORT = "$($cfg.port)" }
    if (-not $env:VOXCPM_CFG_VALUE -and $cfg.cfg_value)       { $env:VOXCPM_CFG_VALUE = "$($cfg.cfg_value)" }
    if (-not $env:VOXCPM_TIMESTEPS -and $cfg.inference_timesteps) { $env:VOXCPM_TIMESTEPS = "$($cfg.inference_timesteps)" }
}

# Explicit param overrides win.
if ($Model)  { $env:VOXCPM_MODEL = $Model }
if ($Device) { $env:VOXCPM_DEVICE = $Device }
if ($Port)   { $env:VOXCPM_PORT = "$Port" }

Write-Host "[VoxCPM] launching server (model=$($env:VOXCPM_MODEL), device=$($env:VOXCPM_DEVICE), port=$($env:VOXCPM_PORT)) ..." -ForegroundColor Cyan
& $vpy (Join-Path $here "server.py")
