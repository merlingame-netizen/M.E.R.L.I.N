# capture_baselines.ps1 — Capture baseline screenshots for Visual QA
# Usage: powershell -ExecutionPolicy Bypass -File tools/capture_baselines.ps1
# Requires: display (NOT headless — viewport texture needs GPU)

param(
    [string]$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe",
    [string]$OutputDir = "tools\autodev\captures\baseline",
    [int]$SettleSeconds = 3
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

$Scenes = @(
    @{ name = "MenuPrincipal";        path = "res://scenes/MenuPrincipal.tscn" },
    @{ name = "IntroCeltOS";          path = "res://scenes/IntroCeltOS.tscn" },
    @{ name = "HubAntre";             path = "res://scenes/HubAntre.tscn" },
    @{ name = "TransitionBiome";      path = "res://scenes/TransitionBiome.tscn" },
    @{ name = "SelectionSauvegarde";  path = "res://scenes/SelectionSauvegarde.tscn" },
    @{ name = "MenuOptions";          path = "res://scenes/MenuOptions.tscn" }
)

$BaselineDir = Join-Path $ProjectRoot $OutputDir
if (-not (Test-Path $BaselineDir)) {
    New-Item -ItemType Directory -Path $BaselineDir -Force | Out-Null
}

$UserData = "$env:APPDATA\Godot\app_userdata\DRU"
$ConfigPath = Join-Path $UserData "screenshot_config.json"
$ResultPath = Join-Path $UserData "screenshot_result.json"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  BASELINE CAPTURE ($($Scenes.Count) scenes)" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================`n"

$Success = 0
$Failed = 0

foreach ($scene in $Scenes) {
    $OutputFile = "user://baseline_$($scene.name).png"
    $LocalFile = Join-Path $BaselineDir "$($scene.name).png"

    # Write config for screenshot_runner.gd
    $config = @{
        scene_path = $scene.path
        output_path = $OutputFile
    } | ConvertTo-Json
    Set-Content -Path $ConfigPath -Value $config -Encoding UTF8

    # Remove previous result
    if (Test-Path $ResultPath) { Remove-Item $ResultPath -Force }

    Write-Host "  Capturing: $($scene.name)..." -NoNewline

    # Launch Godot with ScreenshotRunner scene (needs display)
    $proc = Start-Process -FilePath $GodotExe `
        -ArgumentList "--path `"$ProjectRoot`" --rendering-driver opengl3 --resolution 800x600 --quit-after 10 res://scenes/ScreenshotRunner.tscn" `
        -PassThru -WindowStyle Minimized

    # Wait for completion (max 15s)
    $proc | Wait-Process -Timeout 15 -ErrorAction SilentlyContinue
    if (-not $proc.HasExited) {
        $proc | Stop-Process -Force
        Write-Host " TIMEOUT" -ForegroundColor Red
        $Failed++
        continue
    }

    # Check result
    $UserPng = Join-Path $UserData "baseline_$($scene.name).png"
    if (Test-Path $UserPng) {
        Copy-Item $UserPng $LocalFile -Force
        $size = (Get-Item $LocalFile).Length
        Write-Host " OK ($size bytes)" -ForegroundColor Green
        $Success++
    } elseif (Test-Path $ResultPath) {
        $result = Get-Content $ResultPath -Raw | ConvertFrom-Json
        if ($result.status -eq "ok") {
            Write-Host " OK (result file)" -ForegroundColor Green
            $Success++
        } else {
            Write-Host " FAIL: $($result.error)" -ForegroundColor Red
            $Failed++
        }
    } else {
        Write-Host " FAIL (no output)" -ForegroundColor Red
        $Failed++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  BASELINE CAPTURE: $Success/$($Scenes.Count) captured ($Failed failed)" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================`n"
