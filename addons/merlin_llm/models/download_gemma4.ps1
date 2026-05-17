# M.E.R.L.I.N. — Gemma 4 GGUF downloader (Phase B)
#
# Telecharge les .gguf Gemma 4 dans addons/merlin_llm/models/.
# Les .gguf sont gitignored (cf .gitignore *.gguf).
#
# Usage :
#   powershell -ExecutionPolicy Bypass -File addons/merlin_llm/models/download_gemma4.ps1
#   powershell ... -Tier e4b    # Specific tier only
#   powershell ... -Force       # Re-download even if file exists
#
# Tiers :
#   e2b      — ~700 MB   (mobile + worker desktop)
#   e4b      — ~2.0 GB   (default desktop SINGLE)
#   26b-a4b  — ~4.2 GB   (narrator desktop high-end)
#   31b      — ~17 GB    (offline heavy workstation)

param(
    [ValidateSet('all', 'mobile', 'desktop', 'e2b', 'e4b', '26b-a4b', '31b')]
    [string]$Tier = 'desktop',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Configurable mirror — TODO confirm final HF repo names once Gemma 4 GGUF mirrors land.
# Placeholder: huggingface.co/google/gemma-4-{tier}-it-GGUF/resolve/main/{file}
$BaseUrl = $env:GEMMA4_GGUF_MIRROR
if (-not $BaseUrl) {
    $BaseUrl = 'https://huggingface.co/google/gemma-4-{tier}-it-GGUF/resolve/main'
}

$Manifest = @(
    @{ tier='e2b';     file='gemma4-e2b-q4_k_m.gguf';     sha256='TBD'; size_mb=700 }
    @{ tier='e4b';     file='gemma4-e4b-q4_k_m.gguf';     sha256='TBD'; size_mb=2000 }
    @{ tier='26b-a4b'; file='gemma4-26b-a4b-q4_k_m.gguf'; sha256='TBD'; size_mb=4200 }
    @{ tier='31b';     file='gemma4-31b-q4_k_m.gguf';     sha256='TBD'; size_mb=17000 }
)

function Get-TargetTiers {
    switch ($Tier) {
        'all'     { return @('e2b','e4b','26b-a4b','31b') }
        'mobile'  { return @('e2b','e4b') }
        'desktop' { return @('e4b','26b-a4b') }
        default   { return @($Tier) }
    }
}

$targets = Get-TargetTiers
Write-Host "[gemma4-dl] Tiers cibles: $($targets -join ', ')" -ForegroundColor Cyan

foreach ($t in $targets) {
    $entry = $Manifest | Where-Object { $_.tier -eq $t } | Select-Object -First 1
    if (-not $entry) {
        Write-Warning "[gemma4-dl] Tier '$t' inconnu — skip."
        continue
    }
    $url = ($BaseUrl -replace '\{tier\}', $t) + "/$($entry.file)"
    $dst = Join-Path $ScriptDir $entry.file

    if ((Test-Path $dst) -and -not $Force) {
        $sizeMb = [math]::Round((Get-Item $dst).Length / 1MB, 1)
        Write-Host "[gemma4-dl] OK $($entry.file) deja present ($sizeMb MB)" -ForegroundColor Green
        continue
    }

    Write-Host "[gemma4-dl] DL $($entry.file) (~$($entry.size_mb) MB) ..." -ForegroundColor Yellow
    Write-Host "         URL: $url" -ForegroundColor DarkGray

    try {
        # PowerShell native (slow but no deps). Swap to aria2c if installed.
        $aria = Get-Command aria2c -ErrorAction SilentlyContinue
        if ($aria) {
            & aria2c -x 8 -s 8 -o $entry.file -d $ScriptDir $url
        } else {
            Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
        }
        Write-Host "[gemma4-dl] OK $($entry.file) telecharge." -ForegroundColor Green
    } catch {
        Write-Warning "[gemma4-dl] FAIL $($entry.file) — $($_.Exception.Message)"
        Write-Warning "         Placeholder: cree un fichier vide pour eviter les crashs."
        New-Item -ItemType File -Path $dst -Force | Out-Null
        Add-Content -Path $dst -Value "PLACEHOLDER — Gemma 4 GGUF non telecharge. URL=$url"
    }
}

Write-Host "`n[gemma4-dl] Termine. Modeles dans: $ScriptDir" -ForegroundColor Cyan
Write-Host "Pour rebuild Ollama:  ollama create merlin-narrator -f ../../../Modelfile" -ForegroundColor DarkGray
