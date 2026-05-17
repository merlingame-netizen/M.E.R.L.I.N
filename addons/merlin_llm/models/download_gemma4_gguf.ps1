# M.E.R.L.I.N. — Gemma 4 GGUF downloader (Windows PowerShell)
#
# Downloads Gemma 4 GGUF files for the merlin_llm GDExtension (llama.cpp).
# These files are NOT committed (see ../../.gitignore: *.gguf, models/*.gguf).
#
# Usage:
#   pwsh -File addons/merlin_llm/models/download_gemma4_gguf.ps1
#   pwsh -File addons/merlin_llm/models/download_gemma4_gguf.ps1 -Variant e2b
#   pwsh -File addons/merlin_llm/models/download_gemma4_gguf.ps1 -Variant all
#
# Sources (HuggingFace, Apache 2.0):
#   E2B  - Mobile/Judge/Worker target  (~1.6 GB, Q4_K_M)
#   E4B  - Desktop Game Master default (~3.0 GB, Q4_K_M)
#   26B-A4B - Narrator MoE             (~14 GB, Q4_K_M)
#   31B  - Dev heavy dense (offline)   (~18 GB, Q4_K_M)
#
# Update the BASE_URL block below if the HuggingFace repos move. The exact
# repo paths for Gemma 4 GGUF Q4_K_M will appear on https://huggingface.co/google
# once published — the placeholder URLs assume google/gemma-4-{variant}-gguf.

[CmdletBinding()]
param(
    [ValidateSet('e2b','e4b','26b','31b','all','default')]
    [string]$Variant = 'default'
)

$ErrorActionPreference = 'Stop'
$ModelsDir = Split-Path -Parent $PSCommandPath

# ── Source matrix ────────────────────────────────────────────────────────────
# NOTE: replace BaseUrl / Filename pairs with the real HuggingFace paths once
# Google publishes the Gemma 4 GGUF repos. Until then the script reports the
# expected destination and prints the manual download instructions.
$Models = @{
    'e2b' = @{
        Filename = 'gemma4-e2b-q4_k_m.gguf'
        SizeGB   = 1.6
        Url      = 'https://huggingface.co/google/gemma-4-e2b-gguf/resolve/main/gemma4-e2b-q4_k_m.gguf'
    }
    'e4b' = @{
        Filename = 'gemma4-e4b-q4_k_m.gguf'
        SizeGB   = 3.0
        Url      = 'https://huggingface.co/google/gemma-4-e4b-gguf/resolve/main/gemma4-e4b-q4_k_m.gguf'
    }
    '26b' = @{
        Filename = 'gemma4-26b-q4_k_m.gguf'
        SizeGB   = 14.0
        Url      = 'https://huggingface.co/google/gemma-4-26b-a4b-gguf/resolve/main/gemma4-26b-q4_k_m.gguf'
    }
    '31b' = @{
        Filename = 'gemma4-31b-q4_k_m.gguf'
        SizeGB   = 18.0
        Url      = 'https://huggingface.co/google/gemma-4-31b-gguf/resolve/main/gemma4-31b-q4_k_m.gguf'
    }
}

function Download-Variant {
    param([string]$Key)
    $info = $Models[$Key]
    if (-not $info) { Write-Error "Unknown variant: $Key"; return }
    $dest = Join-Path $ModelsDir $info.Filename
    if (Test-Path $dest) {
        $sizeGB = [math]::Round((Get-Item $dest).Length / 1GB, 2)
        Write-Host "[skip] $($info.Filename) already exists ($sizeGB GB)" -ForegroundColor Yellow
        return
    }
    Write-Host "[download] $($info.Filename) (~$($info.SizeGB) GB)" -ForegroundColor Cyan
    Write-Host "           from $($info.Url)" -ForegroundColor DarkGray
    try {
        # Prefer huggingface-cli when available (resumable, faster for large files).
        $hf = Get-Command huggingface-cli -ErrorAction SilentlyContinue
        if ($hf) {
            # huggingface-cli expects repo + filename split; we keep the curl path
            # as the canonical recipe to avoid CLI version coupling.
            Invoke-WebRequest -Uri $info.Url -OutFile $dest -UseBasicParsing
        } else {
            Invoke-WebRequest -Uri $info.Url -OutFile $dest -UseBasicParsing
        }
        Write-Host "[ok]   $($info.Filename) downloaded" -ForegroundColor Green
    } catch {
        Write-Host "[fail] download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download instructions:" -ForegroundColor Yellow
        Write-Host "  1. Browse to https://huggingface.co/google and locate the gemma-4-$Key GGUF repo."
        Write-Host "  2. Download $($info.Filename) (Q4_K_M quantization, ~$($info.SizeGB) GB)."
        Write-Host "  3. Place it at: $dest"
    }
}

switch ($Variant) {
    'default' {
        # Desktop default: E4B (GM, ~3 GB). Add 26B-A4B manually if you have the RAM.
        Download-Variant 'e4b'
    }
    'all' {
        foreach ($k in 'e2b','e4b','26b','31b') { Download-Variant $k }
    }
    default {
        Download-Variant $Variant
    }
}

Write-Host ""
Write-Host "Done. Verify with: Get-ChildItem '$ModelsDir' -Filter *.gguf" -ForegroundColor Green
