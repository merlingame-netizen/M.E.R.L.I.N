<#
.SYNOPSIS
    Unified post-edit inspection for Godot scripts and scenes.
.DESCRIPTION
    Runs the full validation chain after edits:
    1) GDScript validation (targeted or full scripts folder)
    2) Editor parse check (headless editor compile)
    3) Affected scene runtime validation
    4) Godot log + static/runtime summary check
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/post_edit_inspect.ps1
    powershell -ExecutionPolicy Bypass -File tools/post_edit_inspect.ps1 -Scripts "scripts/MenuPrincipal3DWeather.gd"
#>

param(
    [string]$Scripts = "",
    [int]$Timeout = 18,
    [switch]$StrictEditor
)

$ErrorActionPreference = "Continue"

function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red }

$toolDir = $PSScriptRoot
$projectDir = Split-Path $toolDir -Parent
$failed = 0

Push-Location $projectDir
try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  POST-EDIT INSPECTION" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 1) GDScript validation
    if ($Scripts -ne "") {
        $targets = $Scripts -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        foreach ($target in $targets) {
            Write-Info "[1/4] validate_gdscript: $target"
            & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_gdscript.ps1") -Path $target
            if ($LASTEXITCODE -ne 0) { $failed++ }
        }
    } else {
        Write-Info "[1/4] validate_gdscript: scripts/"
        & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_gdscript.ps1") -Path "scripts"
        if ($LASTEXITCODE -ne 0) { $failed++ }
    }

    # 2) Editor parse check
    Write-Info "[2/4] validate_editor_parse"
    if ($StrictEditor) {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_editor_parse.ps1") -strict
    } else {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_editor_parse.ps1")
    }
    if ($LASTEXITCODE -ne 0) { $failed++ }

    # 3) Affected scenes
    Write-Info "[3/4] validate_affected_scenes"
    if ($Scripts -ne "") {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_affected_scenes.ps1") -Scripts $Scripts -Timeout $Timeout
    } else {
        & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_affected_scenes.ps1") -Timeout $Timeout
    }
    if ($LASTEXITCODE -ne 0) { $failed++ }

    # 4) Runtime log + static/runtime quick scan
    Write-Info "[4/4] validate_godot_errors"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "validate_godot_errors.ps1") -Path "scripts"
    if ($LASTEXITCODE -ne 0) { $failed++ }

    Write-Host ""
    if ($failed -eq 0) {
        Write-Host "========================================" -ForegroundColor Green
        Write-OK "  POST-EDIT INSPECTION: PASSED"
        Write-Host "========================================" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "========================================" -ForegroundColor Red
        Write-Err "  POST-EDIT INSPECTION: FAILED ($failed step(s))"
        Write-Host "========================================" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}
