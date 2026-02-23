# feedback_aggregator.ps1 -- AUTODEV v2: Collects review outputs into per-domain feedback
# Usage: .\feedback_aggregator.ps1 [-Cycle 1]
#
# Runs after REVIEW wave completes. Reads review domain outputs and generates
# feedback JSON files for each BUILD domain to consume in the next cycle.

param(
    [int]$Cycle = 0
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$statusDir = Join-Path $scriptDir "status"
$reviewsDir = Join-Path $statusDir "reviews"
$feedbackDir = Join-Path $statusDir "feedback"

# Ensure directories exist
@($feedbackDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

Write-Host "[FEEDBACK] Aggregating review outputs for cycle $Cycle..." -ForegroundColor Cyan

# ── Collect review outputs ───────────────────────────────────────────

# Testing domain outputs
$testingFixes = @()
$fixPrioritiesFile = Join-Path $reviewsDir "testing/fix_priorities.json"
if (Test-Path $fixPrioritiesFile) {
    $testingData = Get-Content $fixPrioritiesFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($testingData) {
        $testingFixes = @($testingData)
        Write-Host "[FEEDBACK]   testing: $($testingFixes.Count) fix priorities" -ForegroundColor Green
    }
} else {
    Write-Host "[FEEDBACK]   testing: no fix_priorities.json found" -ForegroundColor Yellow
}

# Game-design domain outputs
$balanceChanges = @{}
$toneNotes = @()
$proposedChangesFile = Join-Path $reviewsDir "game-design/proposed_changes.json"
$balanceReportFile = Join-Path $reviewsDir "game-design/balance_report.md"
$toneReportFile = Join-Path $reviewsDir "game-design/tone_report.md"

if (Test-Path $proposedChangesFile) {
    $proposedData = Get-Content $proposedChangesFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($proposedData) {
        $balanceChanges = $proposedData
        Write-Host "[FEEDBACK]   game-design: proposed_changes.json loaded" -ForegroundColor Green
    }
}
if (Test-Path $toneReportFile) {
    $toneNotes = @(Get-Content $toneReportFile -Raw)
    Write-Host "[FEEDBACK]   game-design: tone_report.md loaded" -ForegroundColor Green
}

# Lore domain outputs
$loreNotes = @()
$loreCoherenceFile = Join-Path $reviewsDir "lore/lore_coherence_report.md"
if (Test-Path $loreCoherenceFile) {
    $loreNotes = @(Get-Content $loreCoherenceFile -Raw)
    Write-Host "[FEEDBACK]   lore: lore_coherence_report.md loaded" -ForegroundColor Green
}

# Stats summary for reference
$statsData = $null
$statsFile = Join-Path $statusDir "stats_summary.json"
if (Test-Path $statsFile) {
    $statsData = Get-Content $statsFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}

# ── Generate per-domain feedback ─────────────────────────────────────

# Map testing fixes to domains
$domainFixes = @{}
foreach ($fix in $testingFixes) {
    # fix may have a .domain field, or we infer from .file path
    $targetDomain = ""
    if ($fix.domain) {
        $targetDomain = $fix.domain
    } elseif ($fix.file) {
        $filePath = $fix.file
        if ($filePath -match "scripts/merlin/") { $targetDomain = "gameplay" }
        elseif ($filePath -match "scripts/ui/") { $targetDomain = "ui-ux" }
        elseif ($filePath -match "addons/merlin_ai/") { $targetDomain = "llm-lora" }
        elseif ($filePath -match "scripts/(TransitionBiome|HubAntre|Collection)") { $targetDomain = "world-structure" }
        elseif ($filePath -match "shaders/|merlin_visual|merlin_backdrop") { $targetDomain = "visual-polish" }
    }
    if ($targetDomain) {
        if (-not $domainFixes[$targetDomain]) { $domainFixes[$targetDomain] = @() }
        $domainFixes[$targetDomain] += $fix
    }
}

# Build domains list
$buildDomains = @("ui-ux", "gameplay", "llm-lora", "world-structure", "visual-polish", "ui-components", "scene-scripts", "autoloads-visual")

foreach ($domain in $buildDomains) {
    $feedback = @{
        domain     = $domain
        cycle      = $Cycle
        timestamp  = (Get-Date -Format "o")
        from_reviews = @{
            testing     = @()
            game_design = @()
            lore        = @()
        }
        priority_fixes      = @()
        balance_suggestions = @{}
        lore_notes          = @()
        stats_snapshot      = @{}
    }

    # Testing fixes for this domain
    if ($domainFixes[$domain]) {
        $feedback.from_reviews.testing = @($domainFixes[$domain] | ForEach-Object {
            if ($_.description) { $_.description } else { $_.file + ": " + $_.message }
        })
        $feedback.priority_fixes = @($domainFixes[$domain] |
            Where-Object { $_.priority -eq "high" } |
            ForEach-Object { if ($_.description) { $_.description } else { $_.message } })
    }

    # Balance changes (only for gameplay domain)
    if ($domain -eq "gameplay" -and $balanceChanges) {
        $feedback.balance_suggestions = $balanceChanges
        $feedback.from_reviews.game_design += @("Apply balance adjustments from proposed_changes.json")
    }

    # Tone notes (for all creative domains)
    if ($toneNotes.Count -gt 0 -and $domain -in @("gameplay", "llm-lora", "visual-polish")) {
        $feedback.from_reviews.game_design += @("Tone review available in tone_report.md")
    }

    # Lore notes (for narrative-adjacent domains)
    if ($loreNotes.Count -gt 0 -and $domain -in @("gameplay", "llm-lora", "world-structure")) {
        $feedback.lore_notes = @("Lore coherence review available in lore_coherence_report.md")
        $feedback.from_reviews.lore += @("Review narrative consistency per lore report")
    }

    # Stats snapshot (key metrics)
    if ($statsData) {
        $feedback.stats_snapshot = @{
            balance_score = $statsData.balance_score
            fun_score     = $statsData.fun_score
            survival_rate = $statsData.survival_rate
            avg_cards     = $statsData.avg_cards_played
        }
    }

    # Write feedback file
    $feedbackPath = Join-Path $feedbackDir "$domain.json"
    $feedback | ConvertTo-Json -Depth 5 | Set-Content $feedbackPath -Encoding UTF8
    Write-Host "[FEEDBACK]   -> $domain.json written" -ForegroundColor Gray
}

Write-Host "[FEEDBACK] Aggregation complete for $($buildDomains.Count) domains" -ForegroundColor Green
