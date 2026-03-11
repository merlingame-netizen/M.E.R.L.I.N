# playtest_simulator.ps1 — M.E.R.L.I.N. Playtest Headless v1.0
# Simule N parties en mode headless, parse les logs, produit des métriques.
# Godot exporte les résultats de partie dans captures/playtest_result.json via print().

param(
    [int]$Runs     = 3,
    [int]$Timeout  = 60,     # secondes max par run
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot  = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configPath   = Join-Path $scriptDir "config/work_units_v2.json"
$capturesDir  = Join-Path $projectRoot "captures"
$statusDir    = Join-Path $scriptDir "status"

$config = $null
try {
    $config = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "[PLAYTEST] FATAL: Impossible de lire $configPath : $_" -ForegroundColor Red
    exit 1
}
$godotExe = $config.godot_exe

if (-not (Test-Path $godotExe)) {
    Write-Host "[PLAYTEST] Godot introuvable : $godotExe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $capturesDir)) { New-Item -ItemType Directory -Path $capturesDir -Force | Out-Null }

Write-Host "[PLAYTEST] Lancement de $Runs parties headless..." -ForegroundColor Cyan

$allResults = @()

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host "  Run $i/$Runs..." -ForegroundColor Yellow

    $resultFile = Join-Path $capturesDir "playtest_run_$i.json"
    Remove-Item $resultFile -ErrorAction SilentlyContinue

    # Lancer Godot en headless avec la scène de jeu
    # Le jeu doit écrire le résultat dans captures/playtest_run_N.json puis quitter
    # Note : --quit-after N = nombre de frames. À 60fps : 18000 frames ≈ 5 minutes max par run.
    # Le $Timeout (secondes) reste le vrai garde-fou via WaitForExit.
    $godotArgs = @(
        "--path", $projectRoot,
        "--headless",
        "--quit-after", "18000",
        "scenes/MerlinGame.tscn",
        "--",
        "autoplay=true",
        "output=$resultFile"
    )

    $proc = Start-Process -FilePath $godotExe -ArgumentList $godotArgs `
        -RedirectStandardOutput (Join-Path $capturesDir "playtest_stdout_$i.txt") `
        -RedirectStandardError  (Join-Path $capturesDir "playtest_stderr_$i.txt") `
        -PassThru -NoNewWindow

    # Attendre avec timeout
    $waited = 0
    while (-not $proc.HasExited -and $waited -lt $Timeout) {
        Start-Sleep -Seconds 2
        $waited += 2
    }

    if (-not $proc.HasExited) {
        Write-Host "    Timeout atteint — kill du process" -ForegroundColor Red
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        $allResults += @{ run = $i; status = "TIMEOUT"; outcome = "unknown"; turns = -1 }
        continue
    }

    # Lire résultat si le fichier existe
    if (Test-Path $resultFile) {
        $result = Get-Content $resultFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($result) {
            $allResults += @{
                run     = $i
                status  = "COMPLETED"
                outcome = if ($result.outcome) { $result.outcome } else { "unknown" }
                turns   = if ($result.turns)   { $result.turns }   else { -1 }
                ending  = if ($result.ending)  { $result.ending }  else { "none" }
            }
            Write-Host "    Résultat : $($result.outcome) en $($result.turns) tours (ending: $($result.ending))" -ForegroundColor Green
        } else {
            $allResults += @{ run = $i; status = "PARSE_ERROR"; outcome = "unknown"; turns = -1 }
        }
    } else {
        # Fallback : analyser stdout pour des patterns de victoire/défaite
        $stdout = Get-Content (Join-Path $capturesDir "playtest_stdout_$i.txt") -Raw -ErrorAction SilentlyContinue
        $outcome = "unknown"
        if ($stdout -match "GAME_OVER|game_over") { $outcome = "defeat" }
        if ($stdout -match "VICTORY|victory")     { $outcome = "victory" }
        if ($stdout -match "CRASH|ERROR:")        { $outcome = "crash" }

        $allResults += @{ run = $i; status = "NO_FILE"; outcome = $outcome; turns = -1 }
        Write-Host "    Résultat (stdout parse) : $outcome" -ForegroundColor $(if($outcome -eq "crash"){'Red'}else{'Yellow'})
    }
}

# ── Résumé statistique ────────────────────────────────────────────────

$victories = @($allResults | Where-Object { $_.outcome -eq "victory" }).Count
$defeats   = @($allResults | Where-Object { $_.outcome -eq "defeat" }).Count
$crashes   = @($allResults | Where-Object { $_.outcome -eq "crash" }).Count
$timeouts  = @($allResults | Where-Object { $_.status -eq "TIMEOUT" }).Count
$unknown   = @($allResults | Where-Object { $_.outcome -eq "unknown" -and $_.status -ne "TIMEOUT" }).Count

$avgTurns  = ($allResults | Where-Object { $_.turns -gt 0 } |
    Measure-Object -Property turns -Average).Average

$summary = @{
    timestamp   = (Get-Date -Format "o")
    runs_total  = $Runs
    victories   = $victories
    defeats     = $defeats
    crashes     = $crashes
    timeouts    = $timeouts
    unknown     = $unknown
    avg_turns   = if ($avgTurns) { [math]::Round($avgTurns, 1) } else { -1 }
    win_rate    = if ($Runs -gt 0) { [math]::Round($victories * 100.0 / $Runs, 1) } else { 0 }
    crash_rate  = if ($Runs -gt 0) { [math]::Round($crashes  * 100.0 / $Runs, 1) } else { 0 }
    results     = $allResults
}

$summaryPath = Join-Path $capturesDir "playtest_summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content $summaryPath -Encoding UTF8

Write-Host ""
Write-Host "[PLAYTEST] Résumé :" -ForegroundColor Cyan
Write-Host "  Victoires   : $victories/$Runs ($($summary.win_rate)%)"
Write-Host "  Défaites    : $defeats/$Runs"
Write-Host "  Crashes     : $crashes/$Runs ($($summary.crash_rate)%)"
Write-Host "  Tours moyens: $($summary.avg_turns)"
Write-Host "  Rapport     : $summaryPath"

# Écrire dans metrics_latest.json (section playtest)
$metricsPath = Join-Path $statusDir "metrics_latest.json"
if (Test-Path $metricsPath) {
    $m = Get-Content $metricsPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($m) {
        $m | Add-Member -NotePropertyName "playtest" -NotePropertyValue $summary -Force
        $m | ConvertTo-Json -Depth 10 | Set-Content $metricsPath -Encoding UTF8
    }
}
