# visual_diff.ps1 — M.E.R.L.I.N. Visual QA v1.0
# Compare captures/latest.png vs captures/baseline/*.png
# Utilise PowerShell + .NET System.Drawing pour comparaison pixel.
# Écrit captures/visual_diff_report.json avec delta%.

param(
    [string]$LatestDir   = "",   # override du dossier latest
    [string]$BaselineDir = "",   # override du dossier baseline
    [double]$Threshold   = 5.0   # % de différence acceptable
)

$ErrorActionPreference = "Continue"
$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot  = Split-Path -Parent (Split-Path -Parent $scriptDir)
$capturesDir  = Join-Path $projectRoot "captures"

if (-not $LatestDir)   { $LatestDir   = $capturesDir }
if (-not $BaselineDir) { $BaselineDir = Join-Path $capturesDir "baseline" }

if (-not (Test-Path $BaselineDir)) {
    Write-Host "[VISUAL] Pas de baseline — premier cycle, on crée la baseline." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BaselineDir -Force | Out-Null

    # Copier toutes les captures actuelles comme baseline
    $pngs = Get-ChildItem $LatestDir -Filter "*.png" -ErrorAction SilentlyContinue
    foreach ($png in $pngs) {
        Copy-Item $png.FullName (Join-Path $BaselineDir $png.Name)
    }
    Write-Host "[VISUAL] Baseline créée ($($pngs.Count) images) dans $BaselineDir" -ForegroundColor Green
    Write-Host "delta=0%"
    exit 0
}

# Charger System.Drawing pour comparaison pixel
Add-Type -AssemblyName System.Drawing

function Compare-Images {
    param([string]$Path1, [string]$Path2)

    try {
        $img1 = [System.Drawing.Bitmap]::new($Path1)
        $img2 = [System.Drawing.Bitmap]::new($Path2)

        # Si tailles différentes — diff maximale
        if ($img1.Width -ne $img2.Width -or $img1.Height -ne $img2.Height) {
            $img1.Dispose(); $img2.Dispose()
            return 100.0
        }

        $diffPixels = 0
        $total      = $img1.Width * $img1.Height

        # Échantillonnage (1 pixel sur 4 pour performance)
        for ($y = 0; $y -lt $img1.Height; $y += 2) {
            for ($x = 0; $x -lt $img1.Width; $x += 2) {
                $p1 = $img1.GetPixel($x, $y)
                $p2 = $img2.GetPixel($x, $y)
                $rDiff = [Math]::Abs($p1.R - $p2.R)
                $gDiff = [Math]::Abs($p1.G - $p2.G)
                $bDiff = [Math]::Abs($p1.B - $p2.B)
                # Seuil de tolérance : diff > 10 sur l'un des canaux = pixel différent
                if (($rDiff + $gDiff + $bDiff) -gt 30) { $diffPixels++ }
            }
        }

        # Sauvegarder dimensions avant Dispose (évite use-after-dispose)
        $w = $img1.Width
        $h = $img1.Height
        $img1.Dispose(); $img2.Dispose()

        # Ratio sur pixels échantillonnés
        $sampledPixels = [math]::Ceiling($w / 2) * [math]::Ceiling($h / 2)
        return [math]::Round($diffPixels * 100.0 / $sampledPixels, 2)
    } catch {
        return -1
    }
}

# ── Comparaison toutes les paires baseline/latest ────────────────────

$baselineImages = Get-ChildItem $BaselineDir -Filter "*.png" -ErrorAction SilentlyContinue
$results        = @()
$totalDelta     = 0.0
$compareCount   = 0

Write-Host "[VISUAL] Comparaison baseline vs latest..." -ForegroundColor Cyan

foreach ($baseImg in $baselineImages) {
    $latestImg = Join-Path $LatestDir $baseImg.Name
    if (-not (Test-Path $latestImg)) {
        Write-Host "  MISSING : $($baseImg.Name) (pas de capture récente)" -ForegroundColor Red
        $results += @{ file = $baseImg.Name; delta = 100.0; status = "MISSING" }
        $totalDelta += 100.0
        $compareCount++
        continue
    }

    $delta = Compare-Images -Path1 $baseImg.FullName -Path2 $latestImg
    $status = if ($delta -lt 0) { "ERROR" } elseif ($delta -lt $Threshold) { "OK" } else { "DIFF" }
    $color  = switch ($status) { "OK" { "Green" } "DIFF" { "Yellow" } default { "Red" } }

    Write-Host "  $($baseImg.Name) : delta=${delta}% [$status]" -ForegroundColor $color
    $results += @{ file = $baseImg.Name; delta = $delta; status = $status }

    if ($delta -ge 0) { $totalDelta += $delta; $compareCount++ }
}

$avgDelta = if ($compareCount -gt 0) { [math]::Round($totalDelta / $compareCount, 2) } else { 0 }
$overallStatus = if ($avgDelta -lt $Threshold) { "OK" } else { "REGRESSION" }

# ── Rapport ──────────────────────────────────────────────────────────

$report = @{
    timestamp      = (Get-Date -Format "o")
    baseline_dir   = $BaselineDir
    latest_dir     = $LatestDir
    threshold_pct  = $Threshold
    avg_delta_pct  = $avgDelta
    status         = $overallStatus
    images_checked = $compareCount
    results        = $results
}

$reportPath = Join-Path $capturesDir "visual_diff_report.json"
$report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8

Write-Host ""
Write-Host "[VISUAL] delta=$($avgDelta)% (seuil: $Threshold%) — $overallStatus" -ForegroundColor $(if($overallStatus -eq 'OK'){'Green'}else{'Red'})
Write-Host "[VISUAL] Rapport : $reportPath"

# Mettre à jour la baseline si tout est OK (auto-update au fil du temps)
if ($overallStatus -eq "OK" -and $compareCount -gt 0) {
    $latestPngs = Get-ChildItem $LatestDir -Filter "*.png" -ErrorAction SilentlyContinue
    foreach ($png in $latestPngs) {
        Copy-Item $png.FullName (Join-Path $BaselineDir $png.Name) -Force
    }
    Write-Host "[VISUAL] Baseline mise à jour automatiquement" -ForegroundColor Gray
}
