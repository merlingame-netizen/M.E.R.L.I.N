# control.ps1 -- AUTODEV v2 Conversation Control Bridge
# Usage:
#   .\control.ps1 -Action Start [-Wave] [-Domains "all"] [-MaxCycles 0] [-DryRun]
#   .\control.ps1 -Action Stop
#   .\control.ps1 -Action Status

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start", "Stop", "Status")]
    [string]$Action,

    [switch]$Wave,
    [string]$Domains = "",
    [int]$MaxCycles = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path $scriptDir "status"
$controlFile = Join-Path $statusDir "control_state.json"
$pidFile = Join-Path $statusDir "orchestrator.pid"
$vetoFile = Join-Path $scriptDir "VETO"

# Ensure status directory exists
if (-not (Test-Path $statusDir)) {
    New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
}

function Write-ControlState {
    param([string]$State, [hashtable]$Extra = @{})
    $obj = @{
        state       = $State
        timestamp   = (Get-Date -Format "o")
        wave_mode   = $Wave.IsPresent
        domains     = $Domains
        max_cycles  = $MaxCycles
        dry_run     = $DryRun.IsPresent
    }
    foreach ($k in $Extra.Keys) { $obj[$k] = $Extra[$k] }
    $obj | ConvertTo-Json -Depth 3 | Set-Content $controlFile -Encoding UTF8
}

switch ($Action) {
    "Start" {
        # Check if already running
        if (Test-Path $pidFile) {
            $existingPid = (Get-Content $pidFile -Raw -ErrorAction SilentlyContinue)
            if ($existingPid) { $existingPid = $existingPid.Trim() }
            $proc = if ($existingPid) { Get-Process -Id $existingPid -ErrorAction SilentlyContinue } else { $null }
            if ($proc) {
                Write-Host "[CONTROL] AUTODEV already running (PID $existingPid)" -ForegroundColor Yellow
                Write-Host "[CONTROL] Use -Action Stop first, or drop VETO file" -ForegroundColor Yellow
                exit 1
            }
            # Stale PID file, clean up
            Remove-Item $pidFile -Force
        }

        # Remove any leftover VETO file
        if (Test-Path $vetoFile) {
            Remove-Item $vetoFile -Force
            Write-Host "[CONTROL] Removed stale VETO file" -ForegroundColor Gray
        }

        # Build orchestrator arguments
        $orchScript = Join-Path $scriptDir "orchestrator.ps1"
        $orchArgs = @()
        if ($Domains) { $orchArgs += "-Domains `"$Domains`"" }
        if ($MaxCycles -gt 0) { $orchArgs += "-MaxCycles $MaxCycles" }
        if ($DryRun) { $orchArgs += "-DryRun" }
        if ($Wave) { $orchArgs += "-Wave" }

        $argString = $orchArgs -join " "
        $fullCmd = "powershell -ExecutionPolicy Bypass -File `"$orchScript`" $argString"

        Write-Host "[CONTROL] Launching AUTODEV pipeline..." -ForegroundColor Green
        Write-Host "[CONTROL] Command: $fullCmd" -ForegroundColor Gray

        # Log file for Tee-Object (both visible AND logged)
        $logFile = Join-Path (Join-Path $scriptDir "logs") "orchestrator_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Launch in VISIBLE window (dashboard) with Tee-Object for logging
        $dashboardTitle = "[AUTODEV] Dashboard - Cycle Runner"
        $dashboardCmd = @(
            "`$host.UI.RawUI.WindowTitle = '$dashboardTitle'",
            "Write-Host '' -ForegroundColor Cyan",
            "Write-Host '[==================================================]' -ForegroundColor Cyan",
            "Write-Host '|  M.E.R.L.I.N. AUTODEV v2 -- Dashboard            |' -ForegroundColor Cyan",
            "Write-Host '|  Workers will open in separate windows            |' -ForegroundColor Cyan",
            "Write-Host '|  Drop VETO file in tools/autodev/ to stop all     |' -ForegroundColor Cyan",
            "Write-Host '[==================================================]' -ForegroundColor Cyan",
            "Write-Host ''",
            "& powershell -ExecutionPolicy Bypass -File `"$orchScript`" $argString 2>&1 | Tee-Object -FilePath '$logFile'",
            "Write-Host ''",
            "Write-Host '[AUTODEV] Pipeline finished. Window closes in 120s...' -ForegroundColor Yellow",
            "Start-Sleep -Seconds 120"
        ) -join "; "

        $proc = Start-Process -FilePath "powershell" `
            -ArgumentList @("-ExecutionPolicy", "Bypass", "-NoProfile", "-Command", $dashboardCmd) `
            -PassThru

        # Save PID
        $proc.Id | Set-Content $pidFile -Encoding UTF8

        Write-ControlState -State "running" -Extra @{
            pid      = $proc.Id
            log_file = $logFile
            started  = (Get-Date -Format "o")
        }

        Write-Host "[CONTROL] AUTODEV started (PID $($proc.Id))" -ForegroundColor Green
        Write-Host "[CONTROL] Dashboard window: '$dashboardTitle'" -ForegroundColor Cyan
        Write-Host "[CONTROL] Log: $logFile" -ForegroundColor Gray
        Write-Host "[CONTROL] Stop: .\control.ps1 -Action Stop" -ForegroundColor Gray
    }

    "Stop" {
        Write-Host "[CONTROL] Stopping AUTODEV..." -ForegroundColor Yellow

        # Create VETO file (universal stop signal)
        "VETO from conversation control at $(Get-Date -Format 'o')" | Set-Content $vetoFile -Encoding UTF8

        # Wait for process to exit
        $timeout = 60
        $waited = 0
        $stopped = $false

        if (Test-Path $pidFile) {
            $procId = (Get-Content $pidFile -Raw -ErrorAction SilentlyContinue)
            if ($procId) { $procId = $procId.Trim() }
            Write-Host "[CONTROL] Waiting for PID $procId to exit (max ${timeout}s)..." -ForegroundColor Gray

            while ($waited -lt $timeout -and $procId) {
                $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if (-not $proc) {
                    $stopped = $true
                    break
                }
                Start-Sleep -Seconds 5
                $waited += 5
                Write-Host "[CONTROL]   ...waiting ($waited/${timeout}s)" -ForegroundColor Gray
            }

            if (-not $stopped -and $procId) {
                Write-Host "[CONTROL] Timeout -- force killing process tree PID $procId" -ForegroundColor Red
                # Kill entire process tree (dashboard + orchestrator + workers)
                & taskkill /T /F /PID $procId 2>$null | Out-Null
            }

            Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        }

        Write-ControlState -State "stopped"

        if ($stopped) {
            Write-Host "[CONTROL] AUTODEV stopped gracefully" -ForegroundColor Green
        } else {
            Write-Host "[CONTROL] AUTODEV force-stopped" -ForegroundColor Yellow
        }
    }

    "Status" {
        if (-not (Test-Path $controlFile)) {
            Write-Host "[CONTROL] No AUTODEV session found" -ForegroundColor Gray
            exit 0
        }

        $state = Get-Content $controlFile -Raw | ConvertFrom-Json
        $isRunning = $false

        if (Test-Path $pidFile) {
            $procId = (Get-Content $pidFile -Raw -ErrorAction SilentlyContinue)
            if ($procId) { $procId = $procId.Trim() }
            $proc = if ($procId) { Get-Process -Id $procId -ErrorAction SilentlyContinue } else { $null }
            $isRunning = ($null -ne $proc)
        }

        Write-Host "[CONTROL] ========== AUTODEV STATUS ==========" -ForegroundColor Cyan
        Write-Host "  State:      $($state.state) $(if($isRunning){'(process alive)'}else{'(process dead)'})" -ForegroundColor $(if($isRunning){"Green"}else{"Yellow"})
        Write-Host "  Wave Mode:  $($state.wave_mode)" -ForegroundColor Gray
        Write-Host "  Domains:    $($state.domains)" -ForegroundColor Gray
        Write-Host "  Max Cycles: $($state.max_cycles)" -ForegroundColor Gray
        Write-Host "  Started:    $($state.started)" -ForegroundColor Gray

        # Show health report if available
        $healthFile = Join-Path $statusDir "health_report.json"
        if (Test-Path $healthFile) {
            $health = Get-Content $healthFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($health) {
                Write-Host "`n  --- Health ---" -ForegroundColor Cyan
                Write-Host "  Workers: $($health.active_workers -join ', ')" -ForegroundColor Gray
                Write-Host "  Alerts:  $($health.alerts.Count)" -ForegroundColor $(if($health.alerts.Count -eq 0){"Green"}else{"Red"})
            }
        }

        # Show worker statuses
        Write-Host "`n  --- Workers ---" -ForegroundColor Cyan
        $statusFiles = Get-ChildItem -Path $statusDir -Filter "*.json" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "^(control_state|health_report|\.)" }
        foreach ($sf in $statusFiles) {
            $ws = Get-Content $sf.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($ws -and $ws.status) {
                $icon = switch ($ws.status) {
                    "done"        { "[OK]" }
                    "in_progress" { "[..]" }
                    "error"       { "[!!]" }
                    "merged"      { "[<<]" }
                    default       { "[??]" }
                }
                $color = switch ($ws.status) {
                    "done"        { "Green" }
                    "in_progress" { "Yellow" }
                    "error"       { "Red" }
                    "merged"      { "Cyan" }
                    default       { "Gray" }
                }
                Write-Host "  $icon $($ws.domain): $($ws.status)" -ForegroundColor $color
            }
        }
        Write-Host "[CONTROL] ====================================" -ForegroundColor Cyan

        # Output JSON for machine reading
        $state
    }
}
