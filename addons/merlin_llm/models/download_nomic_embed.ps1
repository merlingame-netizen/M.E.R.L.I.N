# M.E.R.L.I.N. — nomic-embed-text GGUF downloader (Windows PowerShell)
#
# Phase 13 (Sprint 12.4 follow-up). Downloads the embedding GGUF that backs
# the native MerlinEmbed class (replaces the Ollama HTTP path used by
# addons/merlin_ai/cards_rag.gd). This file is NOT committed (gitignored
# via *.gguf in addons/merlin_llm/.gitignore).
#
# Usage:
#   pwsh -File addons/merlin_llm/models/download_nomic_embed.ps1
#
# Source : nomic-ai/nomic-embed-text-v1.5-GGUF on HuggingFace (Apache 2.0).
# Vector dim 768. The same model is used by Ollama's nomic-embed-text tag
# so the produced vectors are bit-compatible with data/ai/cards_index_broceliande.json
# (which was offline-embedded via Ollama at Phase 10 commit time).

[CmdletBinding()]
param(
    [ValidateSet('Q4_K_M','Q5_K_M','Q8_0','f16','default')]
    [string]$Quant = 'default'
)

$ErrorActionPreference = 'Stop'
$ModelsDir = Split-Path -Parent $PSCommandPath

# ── Source matrix ────────────────────────────────────────────────────────────
$Models = @{
    'Q4_K_M' = @{
        Filename = 'nomic-embed-text-Q4_K_M.gguf'
        SizeMB   = 137
        Url      = 'https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q4_K_M.gguf'
    }
    'Q5_K_M' = @{
        Filename = 'nomic-embed-text-Q5_K_M.gguf'
        SizeMB   = 167
        Url      = 'https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q5_K_M.gguf'
    }
    'Q8_0' = @{
        Filename = 'nomic-embed-text-Q8_0.gguf'
        SizeMB   = 247
        Url      = 'https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf'
    }
    'f16' = @{
        Filename = 'nomic-embed-text-f16.gguf'
        SizeMB   = 274
        Url      = 'https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf'
    }
}

function Download-Variant {
    param([string]$Key)
    $info = $Models[$Key]
    if (-not $info) { Write-Error "Unknown quant: $Key"; return }
    $dest = Join-Path $ModelsDir $info.Filename
    if (Test-Path $dest) {
        $sizeMB = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        Write-Host "[skip] $($info.Filename) already exists ($sizeMB MB)" -ForegroundColor Yellow
        return $dest
    }
    Write-Host "[download] $($info.Filename) (~$($info.SizeMB) MB)" -ForegroundColor Cyan
    Write-Host "           from $($info.Url)" -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $info.Url -OutFile $dest -UseBasicParsing
        Write-Host "[ok]   $($info.Filename) downloaded" -ForegroundColor Green
        return $dest
    } catch {
        Write-Host "[fail] download failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download instructions:" -ForegroundColor Yellow
        Write-Host "  1. Browse to https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF"
        Write-Host "  2. Download nomic-embed-text-v1.5.$Key.gguf"
        Write-Host "  3. Save to $dest"
        return $null
    }
}

switch ($Quant) {
    'default' {
        # Desktop default : Q4_K_M (~137 MB) - matches Ollama nomic-embed-text tag
        Download-Variant 'Q4_K_M'
    }
    default {
        Download-Variant $Quant
    }
}

Write-Host ""
Write-Host "Done. Verify with: Get-ChildItem '$ModelsDir' -Filter nomic-embed-text*" -ForegroundColor Green
Write-Host ""
Write-Host "Next step :" -ForegroundColor Cyan
Write-Host "  1. (Re)build merlin_llm.dll (see docs/10_llm/PHASE_13_NATIVE_EMBED.md section 13.3)"
Write-Host "  2. Verify ClassDB.class_exists('MerlinEmbed') == true in a Godot smoke"
