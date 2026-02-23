# git_rollback.ps1 -- AUTODEV v3: Git tagging and rollback management
# Usage:
#   .\git_rollback.ps1 -Action Tag -Cycle 1              # Tag after successful TEST wave
#   .\git_rollback.ps1 -Action RollbackDomain -Domain "ui-ux" -Cycle 1  # Partial rollback
#   .\git_rollback.ps1 -Action RollbackFull -Cycle 1      # Full rollback to last_good
#   .\git_rollback.ps1 -Action Status                     # Show tags and rollback history

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Tag", "RollbackDomain", "RollbackFull", "Status")]
    [string]$Action,

    [int]$Cycle = 0,
    [string]$Domain = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# Tag naming convention
$TAG_PREFIX = "autodev"
$TAG_GOOD_CYCLE = "$TAG_PREFIX/good_cycle"        # autodev/good_cycle_1
$TAG_LAST_GOOD = "$TAG_PREFIX/last_good"           # autodev/last_good (moves)
$TAG_PRE_ROLLBACK = "$TAG_PREFIX/pre_rollback"     # autodev/pre_rollback_1 (safety)

# Ensure directories
@($statusDir, $logDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ── Helpers ────────────────────────────────────────────────────────────

function Write-RollbackLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$ts] [$Level] $Message"
    $logFile = Join-Path $logDir "rollback.log"
    Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    $color = switch ($Level) {
        "INFO"    { "Gray" }
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "ACTION"  { "Cyan" }
        default   { "White" }
    }
    Write-Host "[ROLLBACK] $Message" -ForegroundColor $color
}

function Get-CurrentCommit {
    Push-Location $projectRoot
    $commit = git rev-parse --short HEAD 2>$null
    Pop-Location
    return $commit
}

function Test-CleanWorkingTree {
    Push-Location $projectRoot
    $status = git status --porcelain 2>$null
    Pop-Location
    return ([string]::IsNullOrWhiteSpace($status))
}

# ── ACTION: Tag ────────────────────────────────────────────────────────
# Called after successful TEST wave (merge + validate OK)
# Creates: autodev/good_cycle_N and updates autodev/last_good

function Invoke-TagAction {
    param([int]$CycleNum)

    if ($CycleNum -le 0) {
        Write-RollbackLog "Tag requires -Cycle > 0" "ERROR"
        return $false
    }

    $cycleTag = "${TAG_GOOD_CYCLE}_${CycleNum}"

    Push-Location $projectRoot
    try {
        $currentCommit = git rev-parse --short HEAD 2>$null

        if ($DryRun) {
            Write-RollbackLog "[DRY RUN] Would tag $cycleTag at $currentCommit" "ACTION"
            Write-RollbackLog "[DRY RUN] Would update $TAG_LAST_GOOD to $currentCommit" "ACTION"
            Pop-Location
            return $true
        }

        # Create cycle-specific tag
        $null = git tag -f $cycleTag HEAD 2>&1
        Write-RollbackLog "Tagged $cycleTag at $currentCommit" "OK"

        # Update last_good (moving tag)
        $null = git tag -f $TAG_LAST_GOOD HEAD 2>&1
        Write-RollbackLog "Updated $TAG_LAST_GOOD to $currentCommit" "OK"

        # Write tag info to status
        $tagInfo = @{
            cycle       = $CycleNum
            tag         = $cycleTag
            last_good   = $TAG_LAST_GOOD
            commit      = $currentCommit
            timestamp   = (Get-Date -Format "o")
        }
        $tagInfo | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "last_tag.json") -Encoding UTF8

        Pop-Location
        return $true
    } catch {
        Write-RollbackLog "Tag failed: $($_.Exception.Message)" "ERROR"
        Pop-Location
        return $false
    }
}

# ── ACTION: RollbackDomain ─────────────────────────────────────────────
# Partial rollback: revert a specific domain's merge commit

function Invoke-DomainRollback {
    param([string]$DomainName, [int]$CycleNum)

    if (-not $DomainName) {
        Write-RollbackLog "RollbackDomain requires -Domain" "ERROR"
        return $false
    }

    Push-Location $projectRoot
    try {
        # Find the merge commit for this domain
        $mergePattern = "merge(autodev): integrate $DomainName"
        $mergeCommit = git log --oneline --grep="$mergePattern" -1 --format="%H" 2>$null

        if (-not $mergeCommit) {
            Write-RollbackLog "No merge commit found for domain '$DomainName'" "WARN"
            Pop-Location
            return $false
        }

        $shortCommit = -join $mergeCommit[0..6]
        Write-RollbackLog "Found merge commit for $DomainName : $shortCommit" "INFO"

        if ($DryRun) {
            Write-RollbackLog "[DRY RUN] Would revert $shortCommit ($DomainName)" "ACTION"
            Pop-Location
            return $true
        }

        # Safety: tag before rollback
        $safetyTag = "${TAG_PRE_ROLLBACK}_${CycleNum}_${DomainName}"
        $null = git tag $safetyTag HEAD 2>&1
        Write-RollbackLog "Safety tag: $safetyTag" "ACTION"

        # Revert the merge commit
        $revertOutput = git revert --no-edit $mergeCommit 2>&1
        $revertExitCode = $LASTEXITCODE

        if ($revertExitCode -ne 0) {
            Write-RollbackLog "Revert failed! Output: $revertOutput" "ERROR"
            $null = git revert --abort 2>&1
            Pop-Location
            return $false
        }

        Write-RollbackLog "Successfully reverted $DomainName (commit $shortCommit)" "OK"

        # Update domain status
        $statusFile = Join-Path $statusDir "$DomainName.json"
        if (Test-Path $statusFile) {
            $status = Get-Content $statusFile -Raw | ConvertFrom-Json
            $status.status = "rolled_back"
            $status.timestamp = (Get-Date -Format "o")
            $status | ConvertTo-Json -Depth 3 | Set-Content $statusFile -Encoding UTF8
        }

        # Log rollback event
        $rollbackRecord = @{
            type        = "partial"
            domain      = $DomainName
            cycle       = $CycleNum
            reverted    = $shortCommit
            safety_tag  = $safetyTag
            new_head    = (git rev-parse --short HEAD 2>$null)
            timestamp   = (Get-Date -Format "o")
        }
        $rollbackFile = Join-Path $statusDir "rollback_history.json"
        $history = @()
        if (Test-Path $rollbackFile) {
            $history = @(Get-Content $rollbackFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue)
        }
        $history += $rollbackRecord
        $history | ConvertTo-Json -Depth 5 | Set-Content $rollbackFile -Encoding UTF8

        Pop-Location
        return $true
    } catch {
        Write-RollbackLog "Domain rollback failed: $($_.Exception.Message)" "ERROR"
        $null = git revert --abort 2>&1
        Pop-Location
        return $false
    }
}

# ── ACTION: RollbackFull ───────────────────────────────────────────────
# Full rollback: reset to autodev/last_good tag

function Invoke-FullRollback {
    param([int]$CycleNum)

    Push-Location $projectRoot
    try {
        # Check that last_good tag exists
        $tagExists = git tag -l $TAG_LAST_GOOD 2>$null
        if (-not $tagExists) {
            Write-RollbackLog "Tag $TAG_LAST_GOOD not found! Cannot rollback." "ERROR"
            Pop-Location
            return $false
        }

        $targetCommit = git rev-parse --short $TAG_LAST_GOOD 2>$null
        $currentCommit = git rev-parse --short HEAD 2>$null

        if ($targetCommit -eq $currentCommit) {
            Write-RollbackLog "Already at $TAG_LAST_GOOD ($currentCommit), nothing to rollback" "WARN"
            Pop-Location
            return $true
        }

        Write-RollbackLog "Full rollback: $currentCommit -> $targetCommit ($TAG_LAST_GOOD)" "ACTION"

        if ($DryRun) {
            Write-RollbackLog "[DRY RUN] Would reset --hard to $TAG_LAST_GOOD ($targetCommit)" "ACTION"
            Pop-Location
            return $true
        }

        # Safety: tag current state before rollback
        $safetyTag = "${TAG_PRE_ROLLBACK}_${CycleNum}"
        $null = git tag $safetyTag HEAD 2>&1
        Write-RollbackLog "Safety tag: $safetyTag at $currentCommit" "ACTION"

        # Full reset
        $null = git reset --hard $TAG_LAST_GOOD 2>&1
        $newHead = git rev-parse --short HEAD 2>$null

        Write-RollbackLog "Full rollback complete. HEAD now at $newHead" "OK"

        # Update all domain statuses to rolled_back
        $configPath = Join-Path $scriptDir "config/work_units_v2.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            foreach ($d in $config.domains) {
                if ($d.type -eq "build") {
                    $statusFile = Join-Path $statusDir "$($d.name).json"
                    if (Test-Path $statusFile) {
                        $s = Get-Content $statusFile -Raw | ConvertFrom-Json
                        $s.status = "rolled_back"
                        $s.timestamp = (Get-Date -Format "o")
                        $s | ConvertTo-Json -Depth 3 | Set-Content $statusFile -Encoding UTF8
                    }
                }
            }
        }

        # Log rollback event
        $rollbackRecord = @{
            type        = "full"
            cycle       = $CycleNum
            from        = $currentCommit
            to          = $newHead
            safety_tag  = $safetyTag
            target_tag  = $TAG_LAST_GOOD
            timestamp   = (Get-Date -Format "o")
        }
        $rollbackFile = Join-Path $statusDir "rollback_history.json"
        $history = @()
        if (Test-Path $rollbackFile) {
            $history = @(Get-Content $rollbackFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue)
        }
        $history += $rollbackRecord
        $history | ConvertTo-Json -Depth 5 | Set-Content $rollbackFile -Encoding UTF8

        # Notify
        & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") `
            -Event "rollback" -Message "Full rollback: $currentCommit -> $newHead" `
            -Details "Safety tag: $safetyTag"

        Pop-Location
        return $true
    } catch {
        Write-RollbackLog "Full rollback failed: $($_.Exception.Message)" "ERROR"
        Pop-Location
        return $false
    }
}

# ── ACTION: Status ─────────────────────────────────────────────────────

function Show-RollbackStatus {
    Push-Location $projectRoot

    Write-Host "`n[ROLLBACK] ========== Git Tags ==========" -ForegroundColor Cyan

    # Show all autodev tags
    $tags = git tag -l "${TAG_PREFIX}/*" --sort=-creatordate 2>$null
    if ($tags) {
        foreach ($tag in $tags) {
            $commit = git rev-parse --short $tag 2>$null
            $date = git log -1 --format="%ci" $tag 2>$null
            Write-Host "  $tag -> $commit ($date)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No autodev tags found" -ForegroundColor Yellow
    }

    # Show rollback history
    $rollbackFile = Join-Path $statusDir "rollback_history.json"
    if (Test-Path $rollbackFile) {
        $history = Get-Content $rollbackFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($history) {
            Write-Host "`n[ROLLBACK] ========== History ==========" -ForegroundColor Cyan
            foreach ($entry in $history) {
                $icon = if ($entry.type -eq "full") { "[FULL]" } else { "[PART]" }
                Write-Host "  $icon Cycle $($entry.cycle): $($entry.type) rollback at $($entry.timestamp)" -ForegroundColor Yellow
            }
        }
    }

    Pop-Location
}

# ── Main ───────────────────────────────────────────────────────────────

Write-Host "[ROLLBACK] ========================================" -ForegroundColor Magenta
Write-Host "  AUTODEV v3 Git Rollback Manager" -ForegroundColor Magenta
Write-Host "  Action: $Action | Cycle: $Cycle | Domain: $Domain" -ForegroundColor Magenta
Write-Host "[ROLLBACK] ========================================" -ForegroundColor Magenta

switch ($Action) {
    "Tag" {
        $success = Invoke-TagAction -CycleNum $Cycle
        if ($success) {
            Write-RollbackLog "Tag action completed successfully" "OK"
        } else {
            Write-RollbackLog "Tag action failed" "ERROR"
            exit 1
        }
    }
    "RollbackDomain" {
        $success = Invoke-DomainRollback -DomainName $Domain -CycleNum $Cycle
        if ($success) {
            Write-RollbackLog "Domain rollback completed" "OK"
        } else {
            Write-RollbackLog "Domain rollback failed" "ERROR"
            exit 1
        }
    }
    "RollbackFull" {
        $success = Invoke-FullRollback -CycleNum $Cycle
        if ($success) {
            Write-RollbackLog "Full rollback completed" "OK"
        } else {
            Write-RollbackLog "Full rollback failed" "ERROR"
            exit 1
        }
    }
    "Status" {
        Show-RollbackStatus
    }
}
