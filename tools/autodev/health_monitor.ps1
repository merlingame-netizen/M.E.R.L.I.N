# health_monitor.ps1 --AUTODEV Health Monitor: continuous project health checks
# Usage: .\health_monitor.ps1 [-IntervalSeconds 120] [-Once]

param(
    [int]$IntervalSeconds = 120,
    [switch]$Once
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
# Support both v1 and v2 config
$configV2Path = Join-Path $scriptDir "config/work_units_v2.json"
$configV1Path = Join-Path $scriptDir "config/work_units.json"
$configPath = if (Test-Path $configV2Path) { $configV2Path } else { $configV1Path }
$statusDir = Join-Path $scriptDir "status"

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$worktreeBase = $config.worktree_base
$isV2 = (Test-Path $configV2Path)

Write-Host "[HEALTH] Monitor started (interval: ${IntervalSeconds}s)" -ForegroundColor Cyan

function Check-ScopeCompliance {
    param([object]$DomainConfig)

    $domain = $DomainConfig.name
    $worktreePath = Join-Path $worktreeBase $domain

    if (-not (Test-Path $worktreePath)) { return @() }

    Push-Location $worktreePath
    $modifiedFiles = @(git diff --name-only 2>$null) + @(git diff --cached --name-only 2>$null)
    Pop-Location

    $allowedPaths = $DomainConfig.file_scope
    $violations = @()

    foreach ($file in $modifiedFiles) {
        $isAllowed = $false
        foreach ($scope in $allowedPaths) {
            # Check if scope is a directory (ends with /)
            if ($scope -like "*/" -and $file -like "$scope*") {
                $isAllowed = $true
                break
            }
            # Check exact match
            if ($file -eq $scope) {
                $isAllowed = $true
                break
            }
            # Check if file is under a directory scope
            $scopeDir = Split-Path $scope -Parent
            if ($scopeDir -and $file -like "$scopeDir/*") {
                # More permissive: allow files in the same directory
                $isAllowed = $true
                break
            }
        }
        # Always allow status/log files
        if ($file -like "tools/autodev/*") { $isAllowed = $true }

        if (-not $isAllowed) {
            $violations += @{ domain = $domain; file = $file; scope = ($allowedPaths -join ", ") }
        }
    }
    return $violations
}

function Check-MergeConflicts {
    $activeBranches = @()
    foreach ($d in $config.domains) {
        $worktreePath = Join-Path $worktreeBase $d.name
        if (Test-Path $worktreePath) {
            $activeBranches += $d.branch
        }
    }

    $conflicts = @()
    # Check each branch against main for potential conflicts
    Push-Location $projectRoot
    foreach ($branch in $activeBranches) {
        try {
            $mergeBase = git merge-base main $branch 2>$null
            if ($mergeBase) {
                $diffFiles = @(git diff --name-only $mergeBase $branch 2>$null)
                $mainDiffFiles = @(git diff --name-only $mergeBase main 2>$null)
                $overlap = $diffFiles | Where-Object { $mainDiffFiles -contains $_ }
                if ($overlap) {
                    $conflicts += @{ branch = $branch; files = $overlap }
                }
            }
        } catch {}
    }
    Pop-Location
    return $conflicts
}

function Check-ValidationMutex {
    $mutexFile = Join-Path $scriptDir "status/.validate_mutex"
    if (Test-Path $mutexFile) {
        $mutexContent = Get-Content $mutexFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($mutexContent) {
            $age = (Get-Date) - [datetime]$mutexContent.timestamp
            if ($age.TotalMinutes -gt 10) {
                # Stale mutex (> 10 min), remove it
                Remove-Item $mutexFile -Force
                return @{ stale = $true; domain = $mutexContent.domain }
            }
            return @{ active = $true; domain = $mutexContent.domain; age_minutes = [int]($age.TotalMinutes * 10) / 10 }
        }
    }
    return @{ active = $false }
}

function Run-HealthCheck {
    $report = @{
        timestamp       = (Get-Date -Format "o")
        scope_violations = @()
        merge_conflicts  = @()
        validation_mutex = @{}
        active_workers   = @()
        alerts           = @()
    }

    # 1. Check scope compliance for each active worktree
    foreach ($d in $config.domains) {
        $worktreePath = Join-Path $worktreeBase $d.name
        if (Test-Path $worktreePath) {
            $report.active_workers += $d.name

            $violations = Check-ScopeCompliance -DomainConfig $d
            if ($violations.Count -gt 0) {
                $report.scope_violations += $violations
                $fileList = ($violations | ForEach-Object { $_.file }) -join ", "
                $report.alerts += "SCOPE VIOLATION: $($d.name) modified out-of-scope files: $fileList"

                & powershell -File (Join-Path $scriptDir "notify.ps1") `
                    -Event "health_alert" -Domain $d.name `
                    -Message "Scope violation: $($violations.Count) fichiers hors scope" `
                    -Details $fileList
            }
        }
    }

    # 2. Check merge conflicts
    $conflicts = Check-MergeConflicts
    if ($conflicts.Count -gt 0) {
        $report.merge_conflicts = $conflicts
        foreach ($c in $conflicts) {
            $fileList = ($c.files -join ", ")
            $report.alerts += "MERGE CONFLICT RISK: $($c.branch) --$fileList"

            & powershell -File (Join-Path $scriptDir "notify.ps1") `
                -Event "health_alert" -Domain ($c.branch -replace "autodev/", "") `
                -Message "Risque de conflit merge" -Details $fileList
        }
    }

    # 3. Check validation mutex
    $report.validation_mutex = Check-ValidationMutex

    # 4. Collect worker statuses
    $workerStatuses = @{}
    foreach ($d in $config.domains) {
        $statusFile = Join-Path $statusDir "$($d.name).json"
        if (Test-Path $statusFile) {
            $workerStatuses[$d.name] = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
    }
    $report.worker_statuses = $workerStatuses

    # 5. v2: Wave/cycle state monitoring
    if ($isV2) {
        $controlFile = Join-Path $statusDir "control_state.json"
        if (Test-Path $controlFile) {
            $controlState = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($controlState) {
                $report.wave_state = @{
                    state = $controlState.state
                    cycle = $controlState.cycle
                    wave  = $controlState.wave
                }
            }
        }

        # Check screenshots report
        $screenshotsReport = Join-Path $statusDir "screenshots_report.json"
        if (Test-Path $screenshotsReport) {
            $ssData = Get-Content $screenshotsReport -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($ssData) {
                $report.screenshots = @{
                    captured = $ssData.captured
                    failed   = $ssData.failed
                    total    = $ssData.total
                }
                if ($ssData.failed -gt 0) {
                    $report.alerts += "SCREENSHOTS: $($ssData.failed)/$($ssData.total) captures failed"
                }
            }
        }

        # Check stats report
        $statsReport = Join-Path $statusDir "stats_report.json"
        if (Test-Path $statsReport) {
            $stData = Get-Content $statsReport -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($stData) {
                $report.stats = @{
                    successful = $stData.successful
                    failed     = $stData.failed
                    total      = $stData.total_runs
                }
                if ($stData.failed -gt 0) {
                    $report.alerts += "STATS: $($stData.failed)/$($stData.total_runs) auto-play runs failed"
                }
            }
        }

        # Check review outputs
        $reviewsDir = Join-Path $statusDir "reviews"
        if (Test-Path $reviewsDir) {
            $reviewDomains = @(Get-ChildItem $reviewsDir -Directory -ErrorAction SilentlyContinue)
            $report.review_domains = @($reviewDomains | ForEach-Object { $_.Name })
        }
    }

    # Write health report
    $reportPath = Join-Path $statusDir "health_report.json"
    $report | ConvertTo-Json -Depth 5 | Set-Content $reportPath -Encoding UTF8

    # Console output
    $alertCount = $report.alerts.Count
    $color = if ($alertCount -eq 0) { "Green" } else { "Red" }
    Write-Host "[HEALTH] $(Get-Date -Format 'HH:mm:ss') --$($report.active_workers.Count) workers, $alertCount alerts" -ForegroundColor $color
    foreach ($alert in $report.alerts) {
        Write-Host "  ! $alert" -ForegroundColor Red
    }

    return $report
}

# ── Main loop ────────────────────────────────────────────────────────
do {
    # Check for VETO
    if (Test-Path (Join-Path $scriptDir "VETO")) {
        Write-Host "[HEALTH] VETO detected --stopping monitor" -ForegroundColor Red
        break
    }

    Run-HealthCheck | Out-Null

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while (-not $Once)

Write-Host "[HEALTH] Monitor stopped." -ForegroundColor Yellow
