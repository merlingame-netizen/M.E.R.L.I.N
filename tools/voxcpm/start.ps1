<#
.SYNOPSIS
    Start the local TTS server from its venv.

.DESCRIPTION
    Seeds VOXCPM_*/PIPER_* env from config.json (if present); shell env vars and
    explicit params take precedence.
#>
param(
    [ValidateSet("piper", "voxcpm")]
    [string]$Engine,
    [string]$Model,
    [int]$Port,
    [switch]$NoRobot
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$vpy = Join-Path $here ".venv-voxcpm\Scripts\python.exe"

if (-not (Test-Path $vpy)) {
    Write-Host "[TTS] venv not found. Run install.bat first." -ForegroundColor Red
    exit 1
}

$cfgPath = Join-Path $here "config.json"
if (Test-Path $cfgPath) {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    if (-not $env:VOXCPM_ENGINE -and $cfg.engine)            { $env:VOXCPM_ENGINE = $cfg.engine }
    if (-not $env:VOXCPM_HOST -and $cfg.host)                { $env:VOXCPM_HOST = $cfg.host }
    if (-not $env:VOXCPM_PORT -and $cfg.port)                { $env:VOXCPM_PORT = "$($cfg.port)" }
    if (-not $env:PIPER_MODEL -and $cfg.piper_model)         { $env:PIPER_MODEL = $cfg.piper_model }
    if (-not $env:VOXCPM_MODEL -and $cfg.voxcpm_model)       { $env:VOXCPM_MODEL = $cfg.voxcpm_model }
    if (-not $env:VOXCPM_DEVICE -and $cfg.voxcpm_device)     { $env:VOXCPM_DEVICE = $cfg.voxcpm_device }
    if (-not $env:VOXCPM_ROBOT -and ($cfg.PSObject.Properties.Name -contains "robot")) {
        $env:VOXCPM_ROBOT = if ($cfg.robot) { "1" } else { "0" }
    }
    if (-not $env:VOXCPM_ROBOT_INTENSITY -and $cfg.robot_intensity) { $env:VOXCPM_ROBOT_INTENSITY = "$($cfg.robot_intensity)" }
    if (-not $env:VOXCPM_ROBOT_CARRIER -and $cfg.robot_carrier_hz)  { $env:VOXCPM_ROBOT_CARRIER = "$($cfg.robot_carrier_hz)" }
    if (-not $env:VOXCPM_ROBOT_BITS -and $cfg.robot_bits)           { $env:VOXCPM_ROBOT_BITS = "$($cfg.robot_bits)" }
}

if ($Engine)  { $env:VOXCPM_ENGINE = $Engine }
if ($Model)   { if ($env:VOXCPM_ENGINE -eq "voxcpm") { $env:VOXCPM_MODEL = $Model } else { $env:PIPER_MODEL = $Model } }
if ($Port)    { $env:VOXCPM_PORT = "$Port" }
if ($NoRobot) { $env:VOXCPM_ROBOT = "0" }

Write-Host "[TTS] launching (engine=$($env:VOXCPM_ENGINE), robot=$($env:VOXCPM_ROBOT), port=$($env:VOXCPM_PORT)) ..." -ForegroundColor Cyan
& $vpy (Join-Path $here "server.py")
