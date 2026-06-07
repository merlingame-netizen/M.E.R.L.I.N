<#
.SYNOPSIS
    Install the local TTS server into a dedicated venv (Windows-first).

.DESCRIPTION
    Default engine = Piper: fast on CPU, French voices, NO torch. Downloads the
    Merlin voice (fr_FR-tom-medium). This is the recommended CPU-only setup.

    Use -Engine voxcpm for the optional neural voice-cloning engine (installs
    torch + voxcpm; GPU strongly recommended — very slow on CPU).

.PARAMETER Engine
    piper (default) | voxcpm

.PARAMETER PiperVoice
    Piper voice to download (default fr_FR-tom-medium = male French, fits Merlin).

.PARAMETER Device
    For -Engine voxcpm: cpu (default) | cuda121 | cuda118  -> torch wheel index.

.PARAMETER Model
    For -Engine voxcpm: HF model id (default openbmb/VoxCPM-0.5B).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\voxcpm\install.ps1
    powershell -ExecutionPolicy Bypass -File tools\voxcpm\install.ps1 -Engine voxcpm -Device cuda121 -Model openbmb/VoxCPM2
#>
param(
    [ValidateSet("piper", "voxcpm")]
    [string]$Engine = "piper",
    [string]$PiperVoice = "fr_FR-tom-medium",
    [ValidateSet("cpu", "cuda121", "cuda118")]
    [string]$Device = "cpu",
    [string]$Model = "openbmb/VoxCPM-0.5B"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$venv = Join-Path $here ".venv-voxcpm"

Write-Host "=== Local TTS install ===" -ForegroundColor Cyan
Write-Host "  Engine : $Engine"
Write-Host "  Venv   : $venv"

# 1. Python (3.10-3.12 preferred for both engines).
$py = $null
foreach ($cand in @("py -3.12", "py -3.11", "py -3.10", "python")) {
    try {
        $ver = & cmd /c "$cand --version" 2>$null
        if ($ver -match "3\.1[0-2]") { $py = $cand; break }
    } catch {}
}
if (-not $py) { Write-Host "  [WARN] No Python 3.10-3.12 found; using 'python'." -ForegroundColor Yellow; $py = "python" }
Write-Host "  Python : $py"

# 2. venv + pip.
if (-not (Test-Path $venv)) { & cmd /c "$py -m venv `"$venv`"" }
$vpy = Join-Path $venv "Scripts\python.exe"
& $vpy -m pip install --upgrade pip wheel setuptools

# 3. Engine deps.
& $vpy -m pip install -r (Join-Path $here "requirements.txt")

if ($Engine -eq "voxcpm") {
    switch ($Device) {
        "cpu"     { $idx = "https://download.pytorch.org/whl/cpu" }
        "cuda121" { $idx = "https://download.pytorch.org/whl/cu121" }
        "cuda118" { $idx = "https://download.pytorch.org/whl/cu118" }
    }
    Write-Host "  Installing torch ($Device) + voxcpm ..." -ForegroundColor Green
    & $vpy -m pip install torch torchaudio --index-url $idx
    & $vpy -m pip install -r (Join-Path $here "requirements-voxcpm.txt")
}

# 4. Download the Piper voice (always useful as the fast default).
$voicesDir = Join-Path $here "piper_voices"
New-Item -ItemType Directory -Path $voicesDir -Force | Out-Null
$onnx = Join-Path $voicesDir "$PiperVoice.onnx"
if (-not (Test-Path $onnx)) {
    # fr_FR-tom-medium -> fr/fr_FR/tom/medium/fr_FR-tom-medium
    $parts = $PiperVoice -split "-"          # [fr_FR, tom, medium]
    $lang = $parts[0]; $name = $parts[1]; $quality = $parts[2]
    $base = "https://huggingface.co/rhasspy/piper-voices/resolve/main/$($lang.Substring(0,2))/$lang/$name/$quality/$PiperVoice"
    Write-Host "  Downloading Piper voice $PiperVoice ..." -ForegroundColor Green
    Invoke-WebRequest "$base.onnx"      -OutFile $onnx
    Invoke-WebRequest "$base.onnx.json" -OutFile "$onnx.json"
} else {
    Write-Host "  Piper voice $PiperVoice already present." -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Done. ===" -ForegroundColor Cyan
Write-Host "Start:   tools\voxcpm\start.bat"
Write-Host "Test:    open http://127.0.0.1:8808/  (or: python tools\cli.py voxcpm speak --text 'Bonjour')"
