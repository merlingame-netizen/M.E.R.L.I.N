# auto_diagnosis.ps1 -- AUTODEV v4: Pre-Director error analysis and auto-resolution
# Runs BETWEEN Review wave and Director wave
# Classifies all domain errors, identifies transient vs permanent, provides structured context
# Usage: .\auto_diagnosis.ps1 -Cycle 1

param(
    [int]$Cycle = 1
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"
$configPath = Join-Path $scriptDir "config/work_units_v2.json"

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$buildDomains = @($config.domains | Where-Object { $_.type -eq "build" })

Write-Host "[DIAG] Auto-diagnosis for Cycle $Cycle ($($buildDomains.Count) domains)" -ForegroundColor Cyan

# ── Known error patterns ─────────────────────────────────────────────

$transientPatterns = @(
    @{ name = "onedrive_corruption"; pattern = "n'est plus valide car le volume"; hint = "OneDrive sync corrupted a file. Auto-retry with config repair." }
    @{ name = "onedrive_corruption_v2"; pattern = "fichier ouvert n'est plus valide"; hint = "OneDrive sync corruption variant." }
    @{ name = "claude_config_missing"; pattern = "ENOENT.*\.claude"; hint = ".claude.json missing or corrupted. Backup restore attempted." }
    @{ name = "network_timeout"; pattern = "ETIMEDOUT|ECONNRESET|ECONNREFUSED"; hint = "Network connectivity issue. Transient." }
    @{ name = "rate_limit"; pattern = "rate limit|Too Many Requests|429"; hint = "API rate limit hit. Backoff and retry." }
    @{ name = "service_unavailable"; pattern = "503 Service|502 Bad Gateway"; hint = "Backend service temporarily down." }
    @{ name = "socket_error"; pattern = "socket hang up|getaddrinfo ENOTFOUND"; hint = "DNS/socket transient failure." }
)

$permanentPatterns = @(
    @{ name = "validation_parse_error"; pattern = "Could not find type|SCRIPT ERROR|Parse Error"; hint = "GDScript compilation error. Code fix needed." }
    @{ name = "type_inference"; pattern = "Integer division|:= on Variant"; hint = "GDScript type inference issue. Use explicit types." }
    @{ name = "missing_dependency"; pattern = "Cannot find module|ModuleNotFoundError|addon not found"; hint = "Missing dependency. Install required." }
    @{ name = "permission_denied"; pattern = "Permission denied|Access is denied|EPERM"; hint = "File permission issue. May need manual fix." }
    @{ name = "merge_conflict"; pattern = "CONFLICT|merge conflict|Merge conflict"; hint = "Git merge conflict. Manual resolution needed." }
    @{ name = "worktree_error"; pattern = "fatal.*worktree|already checked out"; hint = "Git worktree setup failure. Cleanup needed." }
    @{ name = "uid_missing"; pattern = "\.uid.*not found|missing.*\.uid"; hint = "Godot .uid file missing. Run Editor Parse Check to regenerate." }
)

$infrastructurePatterns = @(
    @{ name = "gut_missing"; pattern = "GutTest|addons/gut|gut_cmdln"; hint = "GUT testing framework not installed yet (INFRA.3 dependency)." }
    @{ name = "stats_missing"; pattern = "stats_summary\.json|batch_autoplay"; hint = "Stats aggregator not yet created (INFRA.6/INFRA.9 dependency)." }
    @{ name = "validate_script_missing"; pattern = "generate_test_results\.ps1.*not found"; hint = "Validation script not yet created (INFRA.1 dependency)." }
)

# ── Analysis ─────────────────────────────────────────────────────────

$domainResults = @{}
$totalErrors = 0
$transientResolved = 0
$permanentCount = 0
$infraCount = 0

foreach ($d in $buildDomains) {
    $name = $d.name
    $statusFile = Join-Path $statusDir "$name.json"

    if (-not (Test-Path $statusFile)) {
        $domainResults[$name] = @{
            status = "missing"
            classification = "UNKNOWN"
            pattern = "no_status_file"
            recommendation = "Worker may not have started"
        }
        continue
    }

    $status = Get-Content $statusFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $status) {
        $domainResults[$name] = @{
            status = "unreadable"
            classification = "UNKNOWN"
            pattern = "json_parse_error"
            recommendation = "Status file corrupted"
        }
        continue
    }

    if ($status.status -eq "done") {
        $domainResults[$name] = @{
            status = "done"
            classification = "OK"
            tasks_completed = $status.tasks_completed
        }
        continue
    }

    if ($status.status -ne "error") {
        $domainResults[$name] = @{
            status = $status.status
            classification = "IN_PROGRESS"
        }
        continue
    }

    # Domain is in error — classify
    $totalErrors++
    $blockerText = ($status.blockers -join " ") + " "
    $errorCtx = ""
    if ($status.error_context) {
        $errorCtx = ($status.error_context | ConvertTo-Json -Depth 2 -Compress)
    }
    $fullText = "$blockerText $errorCtx"

    # Also check the latest log for more context
    $latestLog = Get-ChildItem -Path $logDir -Filter "$name*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $logTail = ""
    if ($latestLog) {
        $logTail = (Get-Content $latestLog.FullName -Tail 30 -ErrorAction SilentlyContinue) -join " "
        $fullText += " $logTail"
    }

    $classified = $false

    # Check transient patterns first
    foreach ($tp in $transientPatterns) {
        if ($fullText -match $tp.pattern) {
            # Check if retry already succeeded (status has error_context.attempts > 1 or retrying status)
            $wasRetried = $false
            if ($status.error_context -and $status.error_context.attempts) {
                $wasRetried = $status.error_context.attempts -gt 1
            }

            $domainResults[$name] = @{
                status = "error"
                classification = "TRANSIENT"
                pattern = $tp.name
                hint = $tp.hint
                auto_resolved = $wasRetried
                attempts = if ($status.error_context.attempts) { $status.error_context.attempts } else { 1 }
                recommendation = if ($wasRetried) { "RETRY_EXHAUSTED" } else { "SHOULD_RETRY" }
                blocker_summary = ($status.blockers | Select-Object -First 2) -join " | "
            }
            if ($wasRetried) { $transientResolved++ }
            $classified = $true
            break
        }
    }

    if (-not $classified) {
        # Check infrastructure patterns
        foreach ($ip in $infrastructurePatterns) {
            if ($fullText -match $ip.pattern) {
                $domainResults[$name] = @{
                    status = "error"
                    classification = "INFRASTRUCTURE"
                    pattern = $ip.name
                    hint = $ip.hint
                    recommendation = "DEPENDENCY_MISSING"
                    blocker_summary = ($status.blockers | Select-Object -First 2) -join " | "
                }
                $infraCount++
                $classified = $true
                break
            }
        }
    }

    if (-not $classified) {
        # Check permanent patterns
        foreach ($pp in $permanentPatterns) {
            if ($fullText -match $pp.pattern) {
                $domainResults[$name] = @{
                    status = "error"
                    classification = "PERMANENT"
                    pattern = $pp.name
                    hint = $pp.hint
                    recommendation = "FIX_REQUIRED"
                    blocker_summary = ($status.blockers | Select-Object -First 2) -join " | "
                }
                $permanentCount++
                $classified = $true
                break
            }
        }
    }

    if (-not $classified) {
        $domainResults[$name] = @{
            status = "error"
            classification = "UNKNOWN"
            pattern = "unrecognized"
            recommendation = "NEEDS_INVESTIGATION"
            blocker_summary = ($status.blockers | Select-Object -First 2) -join " | "
            log_tail = ($logTail | Select-Object -First 200)
        }
        $permanentCount++
    }
}

# ── Decision: does this need human? ──────────────────────────────────

$needsHuman = $false
$reason = "all_auto_resolvable"

# Needs human if: >50% domains have PERMANENT errors, or UNKNOWN errors exist
$unknownCount = @($domainResults.Values | Where-Object { $_.classification -eq "UNKNOWN" }).Count
if ($permanentCount -gt ($buildDomains.Count / 2)) {
    $needsHuman = $true
    $reason = "majority_permanent_errors"
}
if ($unknownCount -gt 0) {
    $needsHuman = $true
    $reason = "unknown_errors_need_investigation"
}

# ── Write report ─────────────────────────────────────────────────────

$report = @{
    cycle = $Cycle
    timestamp = (Get-Date -Format "o")
    domains = $domainResults
    summary = @{
        total_domains = $buildDomains.Count
        total_errors = $totalErrors
        transient = @($domainResults.Values | Where-Object { $_.classification -eq "TRANSIENT" }).Count
        transient_resolved = $transientResolved
        permanent = $permanentCount
        infrastructure = $infraCount
        unknown = $unknownCount
        ok = @($domainResults.Values | Where-Object { $_.classification -eq "OK" }).Count
        needs_human = $needsHuman
        reason = $reason
    }
}

# Atomic write
$targetFile = Join-Path $statusDir "auto_diagnosis.json"
$tmpFile = "$targetFile.tmp"
$report | ConvertTo-Json -Depth 5 | Set-Content $tmpFile -Encoding UTF8
Move-Item -Path $tmpFile -Destination $targetFile -Force

# ── Console summary ──────────────────────────────────────────────────

Write-Host "" -ForegroundColor Cyan
Write-Host "[DIAG] ========== AUTO-DIAGNOSIS REPORT ==========" -ForegroundColor Cyan
Write-Host "[DIAG] Cycle: $Cycle" -ForegroundColor Cyan
Write-Host "[DIAG] Total errors: $totalErrors / $($buildDomains.Count) domains" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Yellow" })
Write-Host "[DIAG]   TRANSIENT: $(@($domainResults.Values | Where-Object { $_.classification -eq 'TRANSIENT' }).Count) (resolved: $transientResolved)" -ForegroundColor $(if ($transientResolved -gt 0) { "Green" } else { "Gray" })
Write-Host "[DIAG]   PERMANENT: $permanentCount" -ForegroundColor $(if ($permanentCount -gt 0) { "Red" } else { "Gray" })
Write-Host "[DIAG]   INFRA:     $infraCount" -ForegroundColor $(if ($infraCount -gt 0) { "Yellow" } else { "Gray" })
Write-Host "[DIAG]   UNKNOWN:   $unknownCount" -ForegroundColor $(if ($unknownCount -gt 0) { "Red" } else { "Gray" })
Write-Host "[DIAG]   OK:        $(@($domainResults.Values | Where-Object { $_.classification -eq 'OK' }).Count)" -ForegroundColor Green
Write-Host "[DIAG] Needs human: $needsHuman ($reason)" -ForegroundColor $(if ($needsHuman) { "Yellow" } else { "Green" })
Write-Host "[DIAG] ============================================" -ForegroundColor Cyan

foreach ($name in $domainResults.Keys) {
    $dr = $domainResults[$name]
    $icon = switch ($dr.classification) {
        "OK"             { "[OK]" }
        "TRANSIENT"      { "[~~]" }
        "PERMANENT"      { "[!!]" }
        "INFRASTRUCTURE" { "[??]" }
        default          { "[--]" }
    }
    $color = switch ($dr.classification) {
        "OK"             { "Green" }
        "TRANSIENT"      { "Yellow" }
        "PERMANENT"      { "Red" }
        "INFRASTRUCTURE" { "Magenta" }
        default          { "Gray" }
    }
    $detail = if ($dr.pattern) { "($($dr.pattern))" } else { "" }
    Write-Host "  $icon $name : $($dr.classification) $detail" -ForegroundColor $color
}

Write-Host "[DIAG] Report written to: $targetFile" -ForegroundColor Gray
