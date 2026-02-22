# screenshot_capture.ps1 -- AUTODEV v2: Capture screenshots of all game scenes
# Usage: .\screenshot_capture.ps1 [-Scenes "IntroCeltOS,MenuPrincipal"] [-Cycle 1] [-OutputDir path]
#
# Launches Godot with --rendering-driver opengl3 (non-headless) to capture viewport.
# Each scene is loaded via ScreenshotRunner.tscn which reads a config JSON.

param(
    [string]$Scenes = "all",
    [int]$Cycle = 0,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$configPath = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir = Join-Path $scriptDir "status"

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$godotExe = $config.godot_exe
$resolution = $config.screenshot_resolution

if (-not $OutputDir) {
    $OutputDir = Join-Path $scriptDir "screenshots"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Determine which scenes to capture
$sceneList = @()
if ($Scenes -eq "all") {
    $sceneList = @($config.screenshot_scenes)
} else {
    foreach ($s in ($Scenes -split ",")) {
        $s = $s.Trim()
        # Accept both "IntroCeltOS" and "res://scenes/IntroCeltOS.tscn"
        if (-not $s.StartsWith("res://")) {
            $s = "res://scenes/$s.tscn"
        }
        $sceneList += $s
    }
}

Write-Host "[SCREENSHOT] Capturing $($sceneList.Count) scenes (cycle $Cycle)" -ForegroundColor Cyan
Write-Host "[SCREENSHOT] Output: $OutputDir" -ForegroundColor Gray
Write-Host "[SCREENSHOT] Resolution: $resolution" -ForegroundColor Gray

# Validation mutex (Godot single instance)
$mutexFile = Join-Path $statusDir ".validate_mutex"

function Acquire-Mutex {
    $waited = 0
    while ((Test-Path $mutexFile) -and $waited -lt 300) {
        Write-Host "[SCREENSHOT] Waiting for Godot mutex..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $waited += 10
    }
    if (Test-Path $mutexFile) {
        Write-Host "[SCREENSHOT] WARN: Stale mutex, removing" -ForegroundColor Yellow
        Remove-Item $mutexFile -Force
    }
    @{ domain = "screenshot_capture"; timestamp = (Get-Date -Format "o") } |
        ConvertTo-Json | Set-Content $mutexFile -Encoding UTF8
}

function Release-Mutex {
    if (Test-Path $mutexFile) { Remove-Item $mutexFile -Force }
}

# Godot user data path (for screenshot_config.json and results)
$godotUserDir = Join-Path $env:APPDATA "Godot/app_userdata/DRU"
if (-not (Test-Path $godotUserDir)) {
    # Try project name from project.godot
    $godotUserDir = Join-Path $env:APPDATA "Godot/app_userdata/M.E.R.L.I.N."
}

$report = @{
    cycle     = $Cycle
    timestamp = (Get-Date -Format "o")
    scenes    = @()
    total     = $sceneList.Count
    captured  = 0
    failed    = 0
}

Acquire-Mutex

try {
    foreach ($scenePath in $sceneList) {
        # Extract scene name from path
        $sceneName = [System.IO.Path]::GetFileNameWithoutExtension($scenePath)
        $timestamp = Get-Date -Format "HHmmss"
        $outputFile = Join-Path $OutputDir "${sceneName}_c${Cycle}_${timestamp}.png"

        Write-Host "[SCREENSHOT] Capturing: $sceneName" -ForegroundColor Green -NoNewline

        # Write config for screenshot_runner.gd
        $screenshotConfig = @{
            scene_path  = $scenePath
            output_path = "user://${sceneName}_screenshot.png"
        } | ConvertTo-Json
        $configFile = Join-Path $godotUserDir "screenshot_config.json"

        # Ensure user data dir exists
        $configDir = Split-Path $configFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $screenshotConfig | Set-Content $configFile -Encoding UTF8

        # Launch Godot with rendering (non-headless)
        $startTime = Get-Date
        $godotArgs = @(
            "--path", $projectRoot,
            "--rendering-driver", "opengl3",
            "--resolution", $resolution,
            "--quit-after", "10",
            "res://scenes/ScreenshotRunner.tscn"
        )

        $proc = Start-Process -FilePath $godotExe -ArgumentList $godotArgs `
            -WindowStyle Hidden -PassThru -Wait -ErrorAction SilentlyContinue

        $elapsed = ((Get-Date) - $startTime).TotalSeconds

        # Check for result
        $resultFile = Join-Path $godotUserDir "screenshot_result.json"
        $sceneResult = @{
            name     = $sceneName
            path     = $scenePath
            status   = "failed"
            error    = ""
            output   = ""
            seconds  = [math]::Round($elapsed, 1)
        }

        if (Test-Path $resultFile) {
            $result = Get-Content $resultFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($result -and $result.status -eq "ok") {
                # Copy the screenshot from user data to output dir
                $userScreenshot = Join-Path $godotUserDir "${sceneName}_screenshot.png"
                if (Test-Path $userScreenshot) {
                    Copy-Item $userScreenshot $outputFile -Force
                    $sceneResult.status = "captured"
                    $sceneResult.output = $outputFile
                    $sceneResult.size_bytes = (Get-Item $outputFile).Length
                    $report.captured++
                    Write-Host " -> OK (${elapsed}s, $($sceneResult.size_bytes) bytes)" -ForegroundColor Green
                } else {
                    $sceneResult.error = "Screenshot file not found after capture"
                    $report.failed++
                    Write-Host " -> FAIL (file not found)" -ForegroundColor Red
                }
            } else {
                $sceneResult.error = if ($result) { $result.error } else { "No result JSON" }
                $report.failed++
                Write-Host " -> FAIL ($($sceneResult.error))" -ForegroundColor Red
            }
            Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
        } else {
            $sceneResult.error = "Godot exited without producing result"
            $report.failed++
            Write-Host " -> FAIL (no result)" -ForegroundColor Red
        }

        $report.scenes += $sceneResult

        # Brief pause between scenes
        Start-Sleep -Seconds 1
    }
} finally {
    Release-Mutex
}

# Write report
$reportPath = Join-Path $statusDir "screenshots_report.json"
$report | ConvertTo-Json -Depth 5 | Set-Content $reportPath -Encoding UTF8

Write-Host "`n[SCREENSHOT] Done: $($report.captured)/$($report.total) captured, $($report.failed) failed" -ForegroundColor Cyan

# Notify
& powershell -File (Join-Path $scriptDir "notify.ps1") `
    -Event "screenshot_done" `
    -Message "$($report.captured)/$($report.total) scenes capturees (cycle $Cycle)"
