# launch_debug.ps1 — Lance Godot + watch_live_game en parallèle
# GameDebugServer s'active automatiquement (OS.is_debug_build() = true)
# Usage: powershell -File tools/autodev/launch_debug.ps1 [-Scene "scenes/MerlinGame.tscn"]
param(
    [string]$Scene = "",
    [switch]$NoWatch
)

$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64.exe"
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Vérifier que Godot existe
if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot non trouvé: $GodotExe"
    exit 1
}

Write-Host "=== MERLIN Debug Launch ===" -ForegroundColor Green
Write-Host "Project: $ProjectRoot"
Write-Host "Godot:   $GodotExe"
Write-Host ""

# Démarrer le watcher en background (sauf si -NoWatch)
if (-not $NoWatch) {
    $WatchScript = Join-Path $PSScriptRoot "watch_live_game.ps1"
    if (Test-Path $WatchScript) {
        Write-Host "Démarrage watch_live_game.ps1 en background..." -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-NoProfile -File `"$WatchScript`"" -WindowStyle Minimized
    }
}

# Créer le dossier debug user si besoin
$DebugDir = "$env:APPDATA\Godot\app_userdata\DRU\debug"
if (-not (Test-Path $DebugDir)) {
    New-Item -ItemType Directory -Path $DebugDir -Force | Out-Null
    Write-Host "Créé: $DebugDir" -ForegroundColor Gray
}

# Lancer Godot
if ($Scene -ne "") {
    Write-Host "Lancement scène: $Scene" -ForegroundColor Yellow
    & $GodotExe --path $ProjectRoot $Scene
} else {
    Write-Host "Lancement jeu complet..." -ForegroundColor Yellow
    & $GodotExe --path $ProjectRoot
}

Write-Host ""
Write-Host "=== Godot fermé ===" -ForegroundColor Gray
