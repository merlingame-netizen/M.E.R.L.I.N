<#
.SYNOPSIS
    Install the VoxCPM local TTS server into a dedicated venv (Windows-first).

.DESCRIPTION
    Creates .venv-voxcpm next to this script, installs the right PyTorch wheel
    (CPU by default), then voxcpm + FastAPI + soundfile. Optionally pre-downloads
    the model weights so the first /synth call isn't a multi-GB surprise.

.PARAMETER Device
    cpu (default) | cuda121 | cuda118   -> chooses the torch wheel index.

.PARAMETER Model
    HuggingFace model id. Default openbmb/VoxCPM-0.5B (CPU-friendly).
    Use openbmb/VoxCPM2 if you have an NVIDIA GPU with ~8 GB VRAM.

.PARAMETER Prefetch
    If set, downloads the model weights at install time.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\voxcpm\install.ps1
    powershell -ExecutionPolicy Bypass -File tools\voxcpm\install.ps1 -Device cuda121 -Model openbmb/VoxCPM2 -Prefetch
#>
param(
    [ValidateSet("cpu", "cuda121", "cuda118")]
    [string]$Device = "cpu",
    [string]$Model = "openbmb/VoxCPM-0.5B",
    [switch]$Prefetch
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$venv = Join-Path $here ".venv-voxcpm"

Write-Host "=== VoxCPM install ===" -ForegroundColor Cyan
Write-Host "  Device : $Device"
Write-Host "  Model  : $Model"
Write-Host "  Venv   : $venv"

# 1. Locate a Python 3.10-3.12 interpreter (VoxCPM requires <3.13).
$py = $null
foreach ($cand in @("py -3.12", "py -3.11", "py -3.10", "python")) {
    try {
        $ver = & cmd /c "$cand --version" 2>$null
        if ($ver -match "3\.1[0-2]") { $py = $cand; break }
    } catch {}
}
if (-not $py) {
    Write-Host "  [WARN] No Python 3.10-3.12 found via launcher; falling back to 'python'." -ForegroundColor Yellow
    $py = "python"
}
Write-Host "  Python : $py"

# 2. Create the venv.
if (-not (Test-Path $venv)) {
    Write-Host "  Creating venv..." -ForegroundColor Green
    & cmd /c "$py -m venv `"$venv`""
}
$vpy = Join-Path $venv "Scripts\python.exe"

# 3. Upgrade pip.
& $vpy -m pip install --upgrade pip wheel setuptools

# 4. Install torch for the chosen device.
switch ($Device) {
    "cpu"     { $idx = "https://download.pytorch.org/whl/cpu" }
    "cuda121" { $idx = "https://download.pytorch.org/whl/cu121" }
    "cuda118" { $idx = "https://download.pytorch.org/whl/cu118" }
}
Write-Host "  Installing torch ($Device) from $idx ..." -ForegroundColor Green
& $vpy -m pip install torch torchaudio --index-url $idx

# 5. Install the rest.
Write-Host "  Installing voxcpm + server deps ..." -ForegroundColor Green
& $vpy -m pip install -r (Join-Path $here "requirements.txt")

# 6. Optional model prefetch.
if ($Prefetch) {
    Write-Host "  Prefetching model weights ($Model) ..." -ForegroundColor Green
    $env:VOXCPM_MODEL = $Model
    & $vpy -c "from voxcpm import VoxCPM; VoxCPM.from_pretrained('$Model'); print('model cached')"
}

Write-Host ""
Write-Host "=== Done. ===" -ForegroundColor Cyan
Write-Host "Start the server with:  tools\voxcpm\start.bat"
Write-Host "Or set a different model: `$env:VOXCPM_MODEL='$Model'; tools\voxcpm\start.bat"
Write-Host "Then check:  python tools\cli.py voxcpm status --human"
