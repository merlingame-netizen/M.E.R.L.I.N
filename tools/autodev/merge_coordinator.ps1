# merge_coordinator.ps1 --AUTODEV Merge Coordinator: integrates completed branches into main
# Usage: .\merge_coordinator.ps1 [-Domain "ui-ux"] [-All] [-DryRun]

param(
    [string]$Domain = "",
    [switch]$All,
    [switch]$DryRun,
    [switch]$PostMergeScreenshots,  # v2: capture screenshots after successful merge
    [int]$Cycle = 0,                # v2: current cycle number (for screenshot naming)
    [switch]$TagOnSuccess           # v3: tag autodev/good_cycle_N + autodev/last_good after all merges OK
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
# Support both v1 and v2 config
$configV2Path = Join-Path $scriptDir "config/work_units_v2.json"
$configV1Path = Join-Path $scriptDir "config/work_units.json"
$configPath = if (Test-Path $configV2Path) { $configV2Path } else { $configV1Path }
$statusDir = Join-Path $scriptDir "status"

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$worktreeBase = $config.worktree_base
$validateCmd = $config.validate_command

Write-Host "[======================================================]" -ForegroundColor Magenta
Write-Host "|  AUTODEV Merge Coordinator" -ForegroundColor Magenta
Write-Host "[======================================================]" -ForegroundColor Magenta

# ── Topological sort based on merge_dependencies ─────────────────────
function Get-TopologicalOrder {
    param([array]$DomainNames)

    # Build adjacency map from config
    $deps = @{}
    foreach ($d in $config.domains) {
        if ($d.type -eq "build") {
            $deps[$d.name] = @()
            if ($d.merge_dependencies) {
                $deps[$d.name] = @($d.merge_dependencies)
            }
        }
    }

    # Kahn's algorithm: topological sort
    $inDegree = @{}
    $nameSet = @{}
    foreach ($name in $DomainNames) {
        $nameSet[$name] = $true
        $inDegree[$name] = 0
    }

    # Count in-degrees (only within the set of domains to merge)
    foreach ($name in $DomainNames) {
        if ($deps[$name]) {
            foreach ($dep in $deps[$name]) {
                if ($nameSet.ContainsKey($dep)) {
                    $inDegree[$name] = $inDegree[$name] + 1
                }
            }
        }
    }

    # Start with zero in-degree nodes
    $queue = [System.Collections.ArrayList]@()
    foreach ($name in $DomainNames) {
        if ($inDegree[$name] -eq 0) {
            $null = $queue.Add($name)
        }
    }

    $sorted = @()
    while ($queue.Count -gt 0) {
        # Pick first from queue (stable order: config.merge_order priority)
        $current = $queue[0]
        $queue.RemoveAt(0)
        $sorted += $current

        # Reduce in-degree of dependents
        foreach ($name in $DomainNames) {
            if ($deps[$name] -and $deps[$name] -contains $current) {
                $inDegree[$name] = $inDegree[$name] - 1
                if ($inDegree[$name] -eq 0) {
                    $null = $queue.Add($name)
                }
            }
        }
    }

    # If sorted.Count < input, there's a cycle (should not happen)
    if ($sorted.Count -lt $DomainNames.Count) {
        $missing = @($DomainNames | Where-Object { $_ -notin $sorted })
        Write-Host "[MERGE] WARNING: Dependency cycle detected for: $($missing -join ', '). Appending at end." -ForegroundColor Red
        $sorted += $missing
    }

    return $sorted
}

# ── Check if a domain's dependencies are all merged ──────────────────
function Test-DependenciesMerged {
    param([string]$DomainName, [hashtable]$MergedSoFar)

    $domainConfig = $config.domains | Where-Object { $_.name -eq $DomainName }
    if (-not $domainConfig -or -not $domainConfig.merge_dependencies) {
        return @{ ok = $true; missing = @() }
    }

    $missing = @()
    foreach ($dep in $domainConfig.merge_dependencies) {
        if (-not $MergedSoFar.ContainsKey($dep) -or $MergedSoFar[$dep] -ne $true) {
            $missing += $dep
        }
    }

    return @{ ok = ($missing.Count -eq 0); missing = $missing }
}

# ── Determine which domains to merge ─────────────────────────────────
function Get-DomainsToMerge {
    $domainsToMerge = @()

    if ($Domain) {
        # Single domain specified
        $domainsToMerge = @($Domain)
    } elseif ($All) {
        # All domains that are DONE, in merge order
        foreach ($name in $config.merge_order) {
            $statusFile = Join-Path $statusDir "$name.json"
            if (Test-Path $statusFile) {
                $status = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($status -and $status.status -eq "done") {
                    $domainsToMerge += $name
                }
            }
        }
    }

    # Apply topological sort based on merge_dependencies
    if ($domainsToMerge.Count -gt 1) {
        $domainsToMerge = Get-TopologicalOrder -DomainNames $domainsToMerge
    }

    return $domainsToMerge
}

# ── Validation mutex (Godot can only run one instance) ───────────────
function Acquire-ValidationMutex {
    param([string]$DomainName)
    $mutexFile = Join-Path $statusDir ".validate_mutex"

    # Wait for existing mutex to clear (max 5 min)
    $waited = 0
    while ((Test-Path $mutexFile) -and $waited -lt 300) {
        Write-Host "[MERGE] Waiting for validation mutex..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $waited += 10
    }

    if (Test-Path $mutexFile) {
        Write-Host "[MERGE] WARN: Stale mutex, removing" -ForegroundColor Yellow
        Remove-Item $mutexFile -Force
    }

    @{ domain = $DomainName; timestamp = (Get-Date -Format "o") } |
        ConvertTo-Json | Set-Content $mutexFile -Encoding UTF8
}

function Release-ValidationMutex {
    $mutexFile = Join-Path $statusDir ".validate_mutex"
    if (Test-Path $mutexFile) { Remove-Item $mutexFile -Force }
}

# ── Merge a single domain ───────────────────────────────────────────
function Merge-Domain {
    param([string]$DomainName)

    $domainConfig = $config.domains | Where-Object { $_.name -eq $DomainName }
    if (-not $domainConfig) {
        Write-Host "[MERGE] Domain '$DomainName' not found" -ForegroundColor Red
        return $false
    }

    $branch = $domainConfig.branch
    $worktreePath = Join-Path $worktreeBase $DomainName

    Write-Host "`n[MERGE] === Merging $DomainName ($branch) ===" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "[DRY RUN] Would merge $branch into main" -ForegroundColor Magenta
        return $true
    }

    Push-Location $projectRoot

    try {
        # 1. Ensure we're on main
        Write-Host "[MERGE] Switching to main..." -ForegroundColor Gray
        $null = git checkout main 2>&1
        # Pull is optional (may fail if no remote or auth)
        $null = git pull origin main 2>&1

        # Reset LASTEXITCODE before merge
        $null = git status 2>$null

        # 2. Attempt merge
        Write-Host "[MERGE] Merging $branch..." -ForegroundColor Gray
        $mergeOutput = git merge --no-ff $branch -m "merge(autodev): integrate $DomainName" 2>&1
        $mergeExitCode = $LASTEXITCODE

        if ($mergeExitCode -ne 0) {
            # Merge conflict
            Write-Host "[MERGE] CONFLICT in $DomainName!" -ForegroundColor Red
            $conflictFiles = @(git diff --name-only --diff-filter=U 2>$null)
            Write-Host "[MERGE] Conflicting files: $($conflictFiles -join ', ')" -ForegroundColor Red

            # Abort the merge
            git merge --abort 2>$null

            & powershell -File (Join-Path $scriptDir "notify.ps1") `
                -Event "merge_conflict" -Domain $DomainName `
                -Message "Conflit merge: $($conflictFiles.Count) fichiers" `
                -Details ($conflictFiles -join "`n")

            Pop-Location
            return $false
        }

        Write-Host "[MERGE] Merge successful, validating..." -ForegroundColor Green

        # 3. Validate (with mutex)
        Acquire-ValidationMutex -DomainName $DomainName

        try {
            # Run Editor Parse Check (Step 0 --most reliable)
            $godotExe = $config.godot_exe
            Write-Host "[MERGE] Running Editor Parse Check..." -ForegroundColor Gray
            $validateOutput = & $godotExe --editor --headless --quit 2>&1
            $hasErrors = $validateOutput | Select-String -Pattern "ERROR|SCRIPT ERROR|Could not find type" -Quiet

            if ($hasErrors) {
                Write-Host "[MERGE] VALIDATION FAILED after merge!" -ForegroundColor Red
                Write-Host ($validateOutput | Select-String "ERROR|SCRIPT ERROR" | Select-Object -First 10) -ForegroundColor Red

                # Abort: reset to before merge
                git reset --hard HEAD~1 2>$null

                & powershell -File (Join-Path $scriptDir "notify.ps1") `
                    -Event "merge_conflict" -Domain $DomainName `
                    -Message "Validation echouee apres merge" `
                    -Details ($validateOutput | Select-String "ERROR" | Select-Object -First 5) -join "`n"

                Pop-Location
                return $false
            }

            Write-Host "[MERGE] Validation OK!" -ForegroundColor Green
        } finally {
            Release-ValidationMutex
        }

        # 4. Cleanup worktree and branch
        Write-Host "[MERGE] Cleaning up worktree and branch..." -ForegroundColor Gray
        if (Test-Path $worktreePath) {
            git worktree remove $worktreePath --force 2>$null
        }
        git branch -d $branch 2>$null

        # 5. Update status
        $statusFile = Join-Path $statusDir "$DomainName.json"
        if (Test-Path $statusFile) {
            $status = Get-Content $statusFile -Raw | ConvertFrom-Json
            $status.status = "merged"
            $status.timestamp = (Get-Date -Format "o")
            $status | ConvertTo-Json -Depth 3 | Set-Content $statusFile -Encoding UTF8
        }

        & powershell -File (Join-Path $scriptDir "notify.ps1") `
            -Event "merge_ok" -Domain $DomainName `
            -Message "Merge et validation OK"

        Pop-Location
        return $true

    } catch {
        Write-Host "[MERGE] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $null = git merge --abort 2>&1
        Release-ValidationMutex
        Pop-Location
        return $false
    }
}

# ── Main ─────────────────────────────────────────────────────────────
$domainsToMerge = Get-DomainsToMerge

if ($domainsToMerge.Count -eq 0) {
    Write-Host "[MERGE] No domains ready to merge." -ForegroundColor Yellow
    exit 0
}

Write-Host "[MERGE] Domains to merge (in order): $($domainsToMerge -join ' -> ')" -ForegroundColor Cyan

$results = @{}
$mergedOk = @{}
$skipped = @{}

foreach ($d in $domainsToMerge) {
    # Check dependencies before merging
    $depCheck = Test-DependenciesMerged -DomainName $d -MergedSoFar $mergedOk
    if (-not $depCheck.ok) {
        Write-Host "[MERGE] SKIPPING $d : unmet dependencies: $($depCheck.missing -join ', ')" -ForegroundColor Yellow
        $results[$d] = $false
        $skipped[$d] = $depCheck.missing
        continue
    }

    $success = Merge-Domain -DomainName $d
    $results[$d] = $success
    if ($success) { $mergedOk[$d] = $true }

    if (-not $success -and -not $All) {
        Write-Host "[MERGE] Stopping due to failure on $d" -ForegroundColor Red
        break
    }
}

# ── Write merge report ────────────────────────────────────────────────
$domainDetails = @{}
foreach ($d in $domainsToMerge) {
    $detail = @{
        merged = if ($results[$d]) { $true } else { $false }
    }
    if ($skipped.ContainsKey($d)) {
        $detail["status"] = "skipped_deps"
        $detail["unmet_dependencies"] = $skipped[$d]
    } elseif ($results[$d]) {
        $detail["status"] = "merged"
    } else {
        $detail["status"] = "failed"
    }
    $domainDetails[$d] = $detail
}

$mergeReport = @{
    cycle          = $Cycle
    timestamp      = (Get-Date -Format "o")
    total          = $domainsToMerge.Count
    merged_ok      = @($results.Values | Where-Object { $_ -eq $true }).Count
    failed         = @($results.Values | Where-Object { $_ -eq $false }).Count
    skipped_deps   = $skipped.Count
    merge_order    = $domainsToMerge
    domains        = $domainDetails
}

# Atomic write
$reportTarget = Join-Path $statusDir "merge_report.json"
$reportTmp = "$reportTarget.tmp"
$mergeReport | ConvertTo-Json -Depth 5 | Set-Content $reportTmp -Encoding UTF8
Move-Item -Path $reportTmp -Destination $reportTarget -Force
Write-Host "[MERGE] Report written: $reportTarget" -ForegroundColor Gray

# Summary
Write-Host "`n[MERGE] ==========================================" -ForegroundColor Cyan
Write-Host "[MERGE] Results:" -ForegroundColor Cyan
$anySuccess = $false
foreach ($d in $domainsToMerge) {
    if (-not $results.ContainsKey($d)) { continue }
    $icon = if ($results[$d]) { "OK" } elseif ($skipped.ContainsKey($d)) { "SKIP" } else { "FAIL" }
    $color = if ($results[$d]) { "Green" } elseif ($skipped.ContainsKey($d)) { "Yellow" } else { "Red" }
    $depNote = if ($skipped.ContainsKey($d)) { " (deps: $($skipped[$d] -join ', '))" } else { "" }
    Write-Host "  [$icon] $d$depNote" -ForegroundColor $color
    if ($results[$d]) { $anySuccess = $true }
}

# v2: Post-merge screenshots
if ($PostMergeScreenshots -and $anySuccess -and -not $DryRun) {
    Write-Host "`n[MERGE] Capturing post-merge screenshots..." -ForegroundColor Cyan
    $screenshotScript = Join-Path $scriptDir "screenshot_capture.ps1"
    if (Test-Path $screenshotScript) {
        $screenshotArgs = @("-Cycle", $Cycle)
        & powershell -File $screenshotScript @screenshotArgs
    } else {
        Write-Host "[MERGE] screenshot_capture.ps1 not found, skipping" -ForegroundColor Yellow
    }
} elseif ($PostMergeScreenshots -and $DryRun) {
    Write-Host "`n[DRY RUN] Would capture post-merge screenshots" -ForegroundColor Magenta
}

# v3: Tag after successful merge (all domains OK)
$allMergesOk = ($results.Values | Where-Object { $_ -eq $false }).Count -eq 0
if ($TagOnSuccess -and $allMergesOk -and $anySuccess) {
    Write-Host "`n[MERGE] Tagging successful merge state..." -ForegroundColor Cyan
    $rollbackScript = Join-Path $scriptDir "git_rollback.ps1"
    if (Test-Path $rollbackScript) {
        $tagArgs = @("-Action", "Tag", "-Cycle", $Cycle)
        if ($DryRun) { $tagArgs += "-DryRun" }
        & powershell -NoProfile -File $rollbackScript @tagArgs
    } else {
        Write-Host "[MERGE] git_rollback.ps1 not found, skipping tagging" -ForegroundColor Yellow
    }
} elseif ($TagOnSuccess -and -not $allMergesOk) {
    Write-Host "`n[MERGE] Some merges failed --skipping tagging" -ForegroundColor Yellow
} elseif ($TagOnSuccess -and $DryRun) {
    Write-Host "`n[DRY RUN] Would tag after merge (if all OK)" -ForegroundColor Magenta
}
