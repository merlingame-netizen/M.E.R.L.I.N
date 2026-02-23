# monitor_dashboard.ps1 -- AUTODEV v2 Live Status Dashboard
# Usage: .\monitor_dashboard.ps1 [-RefreshSeconds 5]
# Opens in its own terminal window, refreshes status continuously.

param(
    [int]$RefreshSeconds = 5
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path $scriptDir "status"

$host.UI.RawUI.WindowTitle = "[AUTODEV] Live Monitor"

function Get-WaveIcon {
    param([string]$Wave)
    switch ($Wave) {
        "build"    { return "HAMMER" }
        "test"     { return "FLASK" }
        "review"   { return "LENS" }
        "fix"      { return "WRENCH" }
        "starting" { return "BOOT" }
        default    { return "----" }
    }
}

function Show-Dashboard {
    Clear-Host

    $now = Get-Date -Format "HH:mm:ss"

    # Header
    Write-Host "[================================================================]" -ForegroundColor Cyan
    Write-Host "|  M.E.R.L.I.N. AUTODEV v2 -- Live Monitor  [$now]        |" -ForegroundColor Cyan
    Write-Host "|  Refresh: ${RefreshSeconds}s | Ctrl+C to close                        |" -ForegroundColor Cyan
    Write-Host "[================================================================]" -ForegroundColor Cyan
    Write-Host ""

    # Control state
    $controlFile = Join-Path $statusDir "control_state.json"
    if (Test-Path $controlFile) {
        $ctrl = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($ctrl) {
            $waveIcon = Get-WaveIcon -Wave $ctrl.wave
            $stateColor = switch ($ctrl.state) {
                "running" { "Green" }
                "idle"    { "Yellow" }
                "stopped" { "Red" }
                default   { "Gray" }
            }
            Write-Host "  Pipeline:  $($ctrl.state)" -ForegroundColor $stateColor
            Write-Host "  Cycle:     $($ctrl.cycle) / $($ctrl.max_cycles)" -ForegroundColor White
            Write-Host "  Wave:      [$waveIcon] $($ctrl.wave)" -ForegroundColor Cyan
            Write-Host "  Detail:    $($ctrl.detail)" -ForegroundColor Gray
            Write-Host "  Updated:   $($ctrl.timestamp)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  Pipeline:  NOT STARTED" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "  --- Workers ---" -ForegroundColor Cyan

    # Worker statuses
    $statusFiles = Get-ChildItem -Path $statusDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "^(control_state|health_report|screenshots_report|stats_report|\.)" }

    $workers = @()
    foreach ($sf in $statusFiles) {
        $ws = Get-Content $sf.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($ws -and $ws.domain) {
            $workers += $ws
        }
    }

    if ($workers.Count -eq 0) {
        Write-Host "    (no workers active)" -ForegroundColor Gray
    } else {
        # Group by status
        $grouped = $workers | Group-Object -Property status

        foreach ($group in $grouped) {
            $icon = switch ($group.Name) {
                "done"        { "[OK]" }
                "in_progress" { "[..]" }
                "error"       { "[!!]" }
                "merged"      { "[<<]" }
                default       { "[??]" }
            }
            $color = switch ($group.Name) {
                "done"        { "Green" }
                "in_progress" { "Yellow" }
                "error"       { "Red" }
                "merged"      { "Cyan" }
                default       { "Gray" }
            }

            foreach ($w in $group.Group) {
                $taskInfo = ""
                if ($w.current_task) { $taskInfo = " -> $($w.current_task)" }
                if ($w.tasks_completed -ne $null -and $w.tasks_total -ne $null) {
                    $taskInfo = " ($($w.tasks_completed)/$($w.tasks_total) tasks)$taskInfo"
                }
                Write-Host "    $icon $($w.domain): $($w.status)$taskInfo" -ForegroundColor $color
            }
        }
    }

    # Health report
    $healthFile = Join-Path $statusDir "health_report.json"
    if (Test-Path $healthFile) {
        $health = Get-Content $healthFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($health) {
            Write-Host ""
            Write-Host "  --- Health ---" -ForegroundColor Cyan
            $alertColor = if ($health.alerts.Count -eq 0) { "Green" } else { "Red" }
            Write-Host "    Alerts: $($health.alerts.Count)" -ForegroundColor $alertColor
            foreach ($alert in $health.alerts) {
                Write-Host "    ! $alert" -ForegroundColor Red
            }
        }
    }

    # Screenshots report
    $ssFile = Join-Path $statusDir "screenshots_report.json"
    if (Test-Path $ssFile) {
        $ss = Get-Content $ssFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($ss) {
            Write-Host ""
            Write-Host "  --- Screenshots ---" -ForegroundColor Cyan
            Write-Host "    Captured: $($ss.captured) / $($ss.total)" -ForegroundColor $(if($ss.failed -eq 0){"Green"}else{"Yellow"})
        }
    }

    # Stats report
    $stFile = Join-Path $statusDir "stats_report.json"
    if (Test-Path $stFile) {
        $st = Get-Content $stFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($st) {
            Write-Host ""
            Write-Host "  --- Stats ---" -ForegroundColor Cyan
            Write-Host "    Runs: $($st.successful + $st.failed) ($($st.successful) OK, $($st.failed) failed)" -ForegroundColor $(if($st.failed -eq 0){"Green"}else{"Yellow"})
            if ($st.balance_score) { Write-Host "    Balance: $($st.balance_score)/100" -ForegroundColor White }
            if ($st.fun_score) { Write-Host "    Fun:     $($st.fun_score)/100" -ForegroundColor White }
        }
    }

    # Recent log entries
    $logDir = Join-Path $scriptDir "logs"
    $recentLogs = Get-ChildItem -Path $logDir -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($recentLogs) {
        Write-Host ""
        Write-Host "  --- Latest Log: $($recentLogs.Name) ---" -ForegroundColor Cyan
        $lastLines = Get-Content $recentLogs.FullName -Tail 5 -ErrorAction SilentlyContinue
        foreach ($line in $lastLines) {
            $trimmed = if ($line.Length -gt 80) { (-join $line[0..76]) + "..." } else { $line }
            Write-Host "    $trimmed" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "[================================================================]" -ForegroundColor DarkGray
    Write-Host "  VETO: New-Item tools/autodev/VETO to stop all workers" -ForegroundColor DarkGray
}

# ── Main loop ────────────────────────────────────────────────────────
while ($true) {
    Show-Dashboard
    Start-Sleep -Seconds $RefreshSeconds
}
