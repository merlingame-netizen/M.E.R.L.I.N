# orchestrator.ps1 -- AUTODEV Orchestrator: autonomous parallel development pipeline
# Usage: .\orchestrator.ps1 [-Domains "ui-ux,gameplay"] [-MaxCycles 1] [-DryRun] [-NoContinue]
#
# Creates branches, launches workers, monitors health, merges results.
# Drop a VETO file in tools/autodev/ to stop everything.

param(
    [string]$Domains = "",          # Comma-separated list, or empty for all
    [int]$MaxCycles = 1,            # Max cycles before stopping (0 = infinite)
    [switch]$DryRun,                # Simulate without executing
    [switch]$NoContinue,            # Don't auto-continue to next cycle
    [switch]$Wave                   # v2 wave mode: BUILD -> TEST -> REVIEW -> FIX cycles
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
# Support both v1 and v2 config
$configV2Path = Join-Path $scriptDir "config/work_units_v2.json"
$configV1Path = Join-Path $scriptDir "config/work_units.json"
$configPath = if (Test-Path $configV2Path) { $configV2Path } else { $configV1Path }
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# ── v2 Wave mode delegation ───────────────────────────────────────────
if ($Wave) {
    Write-Host "[ORCH] Wave mode enabled -- delegating to cycle_runner.ps1" -ForegroundColor Cyan

    # Write control_state for the conversation bridge
    $controlState = @{
        state      = "running"
        wave_mode  = $true
        max_cycles = $MaxCycles
        dry_run    = $DryRun.IsPresent
        timestamp  = (Get-Date -Format "o")
        pid        = $PID
    }
    $controlState | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "control_state.json") -Encoding UTF8

    $cycleArgs = @("-MaxCycles", $MaxCycles)
    if ($DryRun) { $cycleArgs += "-DryRun" }

    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "cycle_runner.ps1") @cycleArgs

    # Update control_state when done
    $controlState.state = "idle"
    $controlState.timestamp = (Get-Date -Format "o")
    $controlState | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "control_state.json") -Encoding UTF8

    exit $LASTEXITCODE
}

# ── v1 Legacy mode (no -Wave) ─────────────────────────────────────────

# Ensure directories exist
@($statusDir, $logDir, (Join-Path $statusDir "patches")) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# Load config
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# ── Banner ───────────────────────────────────────────────────────────
function Show-Banner {
    param([int]$CycleNum)
    Write-Host ""
    Write-Host "[==============================================================]" -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host "|   M.E.R.L.I.N. AUTODEV --Autonomous Development Pipeline    |" -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host "|   Cycle: $CycleNum                                                     |" -ForegroundColor Cyan
    Write-Host "|   Veto:  Drop 'VETO' file in tools/autodev/ to stop         |" -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host "[==============================================================]" -ForegroundColor Cyan
    Write-Host ""
}

# ── Domain selection ─────────────────────────────────────────────────
function Get-ActiveDomains {
    if ($Domains) {
        $selected = $Domains -split ","
        return $config.domains | Where-Object { $selected -contains $_.name }
    }
    return $config.domains
}

# ── Check veto ───────────────────────────────────────────────────────
function Test-Veto {
    param([string]$DomainName = "")
    if (Test-Path (Join-Path $scriptDir "VETO")) { return $true }
    if ($DomainName -and (Test-Path (Join-Path $scriptDir "VETO_$DomainName"))) { return $true }
    return $false
}

# ── Pre-flight checks ───────────────────────────────────────────────
function Test-Prerequisites {
    Write-Host "[ORCH] Pre-flight checks..." -ForegroundColor Yellow

    # Check claude CLI exists
    if (-not (Test-Path $config.claude_exe)) {
        Write-Host "[ORCH] ERROR: Claude CLI not found at $($config.claude_exe)" -ForegroundColor Red
        return $false
    }

    # Check git is clean (no uncommitted changes)
    Push-Location $projectRoot
    $dirtyFiles = @(git status --porcelain 2>$null)
    Pop-Location

    if ($dirtyFiles.Count -gt 0) {
        Write-Host "[ORCH] WARNING: $($dirtyFiles.Count) uncommitted files in working tree" -ForegroundColor Yellow
        Write-Host "[ORCH] Workers will branch from current HEAD including staged changes" -ForegroundColor Yellow
        Write-Host "[ORCH] Recommend: commit pending changes first (git add -A && git commit)" -ForegroundColor Yellow

        # Don't block, just warn --user may have intentionally uncommitted changes
    }

    # Check worktree base directory is writable
    $worktreeBase = $config.worktree_base
    $parentDir = Split-Path $worktreeBase -Parent
    if (-not (Test-Path $parentDir)) {
        Write-Host "[ORCH] Creating worktree base: $worktreeBase" -ForegroundColor Gray
        New-Item -ItemType Directory -Path $worktreeBase -Force | Out-Null
    }

    Write-Host "[ORCH] Pre-flight OK" -ForegroundColor Green
    return $true
}

# ── Launch workers ───────────────────────────────────────────────────
function Start-Workers {
    param([array]$DomainsToRun)

    $jobs = @{}
    foreach ($d in $DomainsToRun) {
        if (Test-Veto -DomainName $d.name) {
            Write-Host "[ORCH] VETO for $($d.name), skipping" -ForegroundColor Red
            continue
        }

        Write-Host "[ORCH] Launching worker: $($d.name) ($($d.tasks.Count) tasks)" -ForegroundColor Green

        $workerScript = Join-Path $scriptDir "worker.ps1"
        $workerArgs = @{
            Domain = $d.name
        }
        if ($DryRun) { $workerArgs["DryRun"] = $true }

        $job = Start-Job -ScriptBlock {
            param($script, $domain, $isDryRun)
            if ($isDryRun) {
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain -DryRun
            } else {
                & powershell -ExecutionPolicy Bypass -File $script -Domain $domain
            }
        } -ArgumentList $workerScript, $d.name, $DryRun.IsPresent

        $jobs[$d.name] = $job
        Write-Host "[ORCH]   -> Job ID: $($job.Id)" -ForegroundColor Gray
    }

    return $jobs
}

# ── Monitor loop ─────────────────────────────────────────────────────
function Watch-Workers {
    param([hashtable]$Jobs)

    $tickSeconds = $config.cycle_tick_seconds
    $allDone = $false

    # Start health monitor in background
    $healthJob = $null
    if (-not $DryRun) {
        $healthScript = Join-Path $scriptDir "health_monitor.ps1"
        $healthJob = Start-Job -ScriptBlock {
            param($script)
            & powershell -File $script -IntervalSeconds 120
        } -ArgumentList $healthScript
        Write-Host "[ORCH] Health monitor started (Job $($healthJob.Id))" -ForegroundColor Gray
    }

    while (-not $allDone) {
        # Check for global VETO
        if (Test-Veto) {
            Write-Host "`n[ORCH] !! VETO DETECTED --Stopping all workers !!" -ForegroundColor Red

            foreach ($name in $Jobs.Keys) {
                if ($Jobs[$name].State -eq "Running") {
                    Stop-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
                    Write-Host "[ORCH]   Stopped: $name" -ForegroundColor Red
                }
            }

            & powershell -File (Join-Path $scriptDir "notify.ps1") `
                -Event "veto" -Message "Tous les workers stoppes"

            # Save interrupted state
            $state = @{
                timestamp = (Get-Date -Format "o")
                reason = "veto"
                workers = @{}
            }
            foreach ($name in $Jobs.Keys) {
                $state.workers[$name] = $Jobs[$name].State
            }
            $state | ConvertTo-Json -Depth 3 |
                Set-Content (Join-Path $statusDir "interrupted_state.json") -Encoding UTF8

            break
        }

        # Check worker statuses
        $statusSummary = @{}
        $runningCount = 0
        $doneCount = 0

        foreach ($name in $Jobs.Keys) {
            $job = $Jobs[$name]
            $jobState = $job.State

            # Also check status file for more detail
            $statusFile = Join-Path $statusDir "$name.json"
            $fileStatus = "unknown"
            if (Test-Path $statusFile) {
                $s = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($s) { $fileStatus = $s.status }
            }

            $statusSummary[$name] = @{ job_state = $jobState; file_status = $fileStatus }

            switch ($jobState) {
                "Running" { $runningCount++ }
                "Completed" { $doneCount++ }
                "Failed" {
                    $doneCount++
                    $errorOutput = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    Write-Host "[ORCH] Worker $name FAILED: $errorOutput" -ForegroundColor Red
                }
            }

            # Check for per-domain veto
            if ($jobState -eq "Running" -and (Test-Veto -DomainName $name)) {
                Write-Host "[ORCH] VETO for $name --stopping" -ForegroundColor Red
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
        }

        # Display status
        Write-Host "[ORCH] $(Get-Date -Format 'HH:mm:ss') --Running: $runningCount, Done: $doneCount/$($Jobs.Count)" -ForegroundColor Cyan
        foreach ($name in $statusSummary.Keys) {
            $s = $statusSummary[$name]
            $icon = switch ($s.job_state) {
                "Running"   { "[..]" }
                "Completed" { "[OK]" }
                "Failed"    { "[!!]" }
                default     { "[??]" }
            }
            $color = switch ($s.job_state) {
                "Running"   { "Yellow" }
                "Completed" { "Green" }
                "Failed"    { "Red" }
                default     { "Gray" }
            }
            Write-Host "  $icon $name (file: $($s.file_status))" -ForegroundColor $color
        }

        # All done?
        if ($runningCount -eq 0) {
            $allDone = $true
        } else {
            Start-Sleep -Seconds $tickSeconds
        }
    }

    # Stop health monitor
    if ($healthJob) {
        Stop-Job -Job $healthJob -ErrorAction SilentlyContinue
        Remove-Job -Job $healthJob -ErrorAction SilentlyContinue
    }

    # Cleanup all jobs
    foreach ($name in $Jobs.Keys) {
        $null = Receive-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
        Remove-Job -Job $Jobs[$name] -ErrorAction SilentlyContinue
    }

    return $statusSummary
}

# ── Merge completed branches ─────────────────────────────────────────
function Invoke-MergePhase {
    Write-Host "`n[ORCH] === MERGE PHASE ===" -ForegroundColor Magenta

    $mergeScript = Join-Path $scriptDir "merge_coordinator.ps1"
    if ($DryRun) {
        & powershell -File $mergeScript -All -DryRun
    } else {
        & powershell -File $mergeScript -All
    }
}

# ── Generate cycle report ────────────────────────────────────────────
function New-CycleReport {
    param([int]$CycleNum, [hashtable]$StatusSummary)

    $report = @{
        cycle     = $CycleNum
        timestamp = (Get-Date -Format "o")
        workers   = $StatusSummary
        domains_done = @()
        domains_failed = @()
    }

    foreach ($name in $StatusSummary.Keys) {
        $s = $StatusSummary[$name]
        if ($s.job_state -eq "Completed" -and $s.file_status -eq "done") {
            $report.domains_done += $name
        } else {
            $report.domains_failed += $name
        }
    }

    $reportJson = $report | ConvertTo-Json -Depth 5
    $reportPath = Join-Path $logDir "cycle_${CycleNum}_report.json"
    $reportJson | Set-Content $reportPath -Encoding UTF8

    Write-Host "`n[ORCH] ======================================" -ForegroundColor Cyan
    Write-Host "[ORCH] Cycle $CycleNum Report:" -ForegroundColor Cyan
    Write-Host "  Done:   $($report.domains_done -join ', ')" -ForegroundColor Green
    Write-Host "  Failed: $($report.domains_failed -join ', ')" -ForegroundColor $(if($report.domains_failed.Count -gt 0){"Red"}else{"Green"})

    return $report
}

# =====================================================================
# MAIN
# =====================================================================

# Pre-flight
if (-not (Test-Prerequisites)) {
    Write-Host "[ORCH] Pre-flight failed. Aborting." -ForegroundColor Red
    exit 1
}

$activeDomains = Get-ActiveDomains
Write-Host "[ORCH] Active domains: $($activeDomains | ForEach-Object { $_.name })" -ForegroundColor Cyan

$cycle = 1
$continueLoop = $true

while ($continueLoop) {
    Show-Banner -CycleNum $cycle

    # Check veto before starting
    if (Test-Veto) {
        Write-Host "[ORCH] VETO file detected. Not starting cycle $cycle." -ForegroundColor Red
        break
    }

    # Notify cycle start
    & powershell -File (Join-Path $scriptDir "notify.ps1") `
        -Event "cycle_start" `
        -Message "Cycle ${cycle} - $($activeDomains.Count) workers ($($activeDomains | ForEach-Object { $_.name }))"

    # Launch workers
    $jobs = Start-Workers -DomainsToRun $activeDomains

    if ($jobs.Count -eq 0) {
        Write-Host "[ORCH] No workers launched. Exiting." -ForegroundColor Yellow
        break
    }

    # Monitor
    $statusSummary = Watch-Workers -Jobs $jobs

    # Merge phase (skip if veto)
    if (-not (Test-Veto)) {
        Invoke-MergePhase
    }

    # Report
    $report = New-CycleReport -CycleNum $cycle -StatusSummary $statusSummary

    # Notify cycle complete
    $doneList = ($report.domains_done -join ", ")
    $failList = ($report.domains_failed -join ", ")
    & powershell -File (Join-Path $scriptDir "notify.ps1") `
        -Event "cycle_complete" `
        -Message "Cycle $cycle termine: $($report.domains_done.Count) OK, $($report.domains_failed.Count) echecs" `
        -Details "OK: $doneList`nFail: $failList"

    # Check if we should continue
    $cycle++
    if ($MaxCycles -gt 0 -and $cycle -gt $MaxCycles) {
        Write-Host "[ORCH] Max cycles ($MaxCycles) reached." -ForegroundColor Yellow
        $continueLoop = $false
    } elseif ($NoContinue) {
        Write-Host "[ORCH] NoContinue flag set. Stopping." -ForegroundColor Yellow
        $continueLoop = $false
    } elseif (Test-Veto) {
        Write-Host "[ORCH] VETO detected. Stopping." -ForegroundColor Red
        $continueLoop = $false
    } else {
        # Veto delay: wait before starting next cycle
        $vetoDelay = $config.veto_delay_seconds
        Write-Host "[ORCH] Next cycle in ${vetoDelay}s (drop VETO file to cancel)..." -ForegroundColor Yellow
        $waited = 0
        while ($waited -lt $vetoDelay) {
            if (Test-Veto) {
                Write-Host "[ORCH] VETO during delay. Stopping." -ForegroundColor Red
                $continueLoop = $false
                break
            }
            Start-Sleep -Seconds 10
            $waited += 10
        }
    }
}

Write-Host "`n[ORCH] AUTODEV Pipeline complete." -ForegroundColor Green
