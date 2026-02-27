<#
.SYNOPSIS
    Launch Godot game in observable mode for Claude Code orchestration.
.DESCRIPTION
    Starts Godot with a specified scene in windowed mode (800x600).
    GameDebugServer auto-activates and writes captures to tools/autodev/captures/.
    Claude Code can then Read screenshots, state.json, perf.json for analysis.
.PARAMETER Scene
    Scene to launch (default: MerlinGame.tscn).
.PARAMETER Resolution
    Window resolution (default: 800x600).
.PARAMETER Clean
    Remove old captures before launch.
.EXAMPLE
    .\tools\launch_game.ps1
    .\tools\launch_game.ps1 -Scene "res://scenes/HubAntre.tscn"
    .\tools\launch_game.ps1 -Clean
#>

param(
    [string]$Scene = "res://scenes/BootstrapMerlinGame.tscn",
    [string]$Resolution = "800x600",
    [switch]$Clean
)

$ErrorActionPreference = "Continue"

# --- Find Godot ---
$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"
if (-not (Test-Path $GodotExe)) {
    Write-Host "[ERROR] Godot not found at: $GodotExe" -ForegroundColor Red
    exit 1
}

# --- Project root ---
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$ProjectRoot\project.godot")) {
    # Fallback: assume script is at tools/launch_game.ps1
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path "$ProjectRoot\project.godot")) {
        $ProjectRoot = "C:\Users\PGNK2128\Godot-MCP"
    }
}

# --- Captures directory ---
$CapturesDir = Join-Path $ProjectRoot "tools\autodev\captures"
if (-not (Test-Path $CapturesDir)) {
    New-Item -ItemType Directory -Path $CapturesDir -Force | Out-Null
    Write-Host "[OK] Created captures dir: $CapturesDir" -ForegroundColor Green
}

# --- Clean old captures ---
if ($Clean) {
    Get-ChildItem -Path $CapturesDir -Include "*.png","*.json" -Recurse | Remove-Item -Force
    Write-Host "[OK] Cleaned captures directory" -ForegroundColor Green
}

# --- Parse resolution ---
$resParts = $Resolution -split "x"
$width = $resParts[0]
$height = $resParts[1]

# --- Launch Godot ---
Write-Host "=== GAME OBSERVER LAUNCH ===" -ForegroundColor Cyan
Write-Host "  Godot:      $GodotExe" -ForegroundColor DarkGray
Write-Host "  Scene:      $Scene" -ForegroundColor DarkGray
Write-Host "  Resolution: ${width}x${height}" -ForegroundColor DarkGray
Write-Host "  Captures:   $CapturesDir" -ForegroundColor DarkGray
Write-Host ""

$args = @(
    "--path", $ProjectRoot,
    "--rendering-driver", "opengl3",
    "--resolution", "${width}x${height}",
    $Scene
)

Write-Host "[LAUNCH] Starting Godot..." -ForegroundColor Yellow
$process = Start-Process -FilePath $GodotExe -ArgumentList $args -PassThru
Write-Host "[OK] Godot PID: $($process.Id)" -ForegroundColor Green
Write-Host "[INFO] Screenshots will appear in: $CapturesDir\latest.png" -ForegroundColor Cyan
Write-Host "[INFO] Game state in: $CapturesDir\state.json" -ForegroundColor Cyan
Write-Host "[INFO] Send commands via: $CapturesDir\command.json" -ForegroundColor Cyan

# Output PID for Claude Code to track
$process.Id
