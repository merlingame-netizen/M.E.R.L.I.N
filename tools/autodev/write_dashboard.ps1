# write_dashboard.ps1 -- Generates live_dashboard.md from AUTODEV status files
# Called by cycle_runner.ps1 at each poll tick
# Output: tools/autodev/status/live_dashboard.md (auto-refreshes in VS Code)

param(
    [int]$CycleNum = 0,
    [string]$Wave = "",
    [string]$Detail = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path $scriptDir "status"
$outFile = Join-Path $statusDir "live_dashboard.md"

# ── Collect data ──────────────────────────────────────────────────────

$controlFile = Join-Path $statusDir "control_state.json"
$control = $null
if (Test-Path $controlFile) {
    $control = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}

$directorFile = Join-Path $statusDir "director_decision.json"
$director = $null
if (Test-Path $directorFile) {
    $director = Get-Content $directorFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}

$directivesFile = Join-Path $statusDir "director_directives.json"
$directives = $null
if (Test-Path $directivesFile) {
    $directives = Get-Content $directivesFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}

# Override with params if provided
$cycleDisplay = if ($CycleNum -gt 0) { $CycleNum } elseif ($control -and $control.cycle) { $control.cycle } else { "?" }
$waveDisplay = if ($Wave) { $Wave } elseif ($control -and $control.wave) { $control.wave } else { "?" }
$stateDisplay = if ($control -and $control.state) { $control.state } else { "unknown" }
$detailDisplay = if ($Detail) { $Detail } elseif ($control -and $control.detail) { $control.detail } else { "" }

# ── Build domain table ────────────────────────────────────────────────

$domains = @("ui-ux", "gameplay", "llm-lora", "world-structure", "visual-polish", "ui-components", "scene-scripts", "autoloads-visual")
$domainRows = @()
$doneCount = 0
$errorCount = 0
$progressCount = 0

foreach ($d in $domains) {
    $sf = Join-Path $statusDir "$d.json"
    $status = "---"
    $detail = ""
    if (Test-Path $sf) {
        $s = Get-Content $sf -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($s) {
            $status = $s.status
            if ($s.detail) { $detail = $s.detail }
            if ($s.tasks_completed) { $detail = "$($s.tasks_completed) tasks" }
        }
    }
    $icon = switch ($status) {
        "done"        { "v" }
        "in_progress" { "~" }
        "error"       { "x" }
        "merged"      { "<" }
        default       { "-" }
    }
    if ($status -eq "done") { $doneCount++ }
    elseif ($status -eq "error") { $errorCount++ }
    elseif ($status -eq "in_progress") { $progressCount++ }

    $domainRows += "| $icon | $d | $status | $detail |"
}

# ── Build director section ────────────────────────────────────────────

$directorSection = ""
if ($director) {
    $dec = $director.decision
    $q = if ($director.quality_score) { $director.quality_score } else { "?" }
    $c = if ($director.confidence_score) { $director.confidence_score } else { if ($director.confidence) { $director.confidence } else { "?" } }
    $directorSection = @"

## Director (Cycle $($director.cycle))

| Metric | Value |
|--------|-------|
| Decision | **$dec** |
| Quality | $q / 100 |
| Confidence | $c / 100 |

"@
    if ($director.rationale) {
        $shortRationale = "$($director.rationale)"
        if ($shortRationale.Length -gt 200) {
            $shortRationale = (-join $shortRationale[0..196]) + "..."
        }
        $directorSection += "> $shortRationale`n"
    }
}

# ── Build escalation section ──────────────────────────────────────────

$escalationSection = ""
if ($stateDisplay -eq "waiting_human") {
    $qFile = Join-Path $statusDir "director_questions.json"
    if (Test-Path $qFile) {
        $qs = Get-Content $qFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($qs -and $qs.questions) {
            $escalationSection = "`n## ESCALATION -- En attente de reponse`n`n"
            $escalationSection += "**Raison**: $($qs.escalation_reason)`n`n"
            foreach ($q in $qs.questions) {
                $qid = $q.id
                $qtext = $q.question
                $escalationSection += "- **$qid**: $qtext`n"
            }
            $escalationSection += "`n> Reponds dans Claude Code. Le pipeline reprend automatiquement.`n"
        }
    }
}

# ── Build directives section ──────────────────────────────────────────

$directivesSection = ""
if ($directives -and $directives.directives) {
    $directivesSection = "`n## Directives actives`n`n"
    foreach ($dir in $directives.directives) {
        $p = $dir.priority
        $d = $dir.directive
        $directivesSection += "- [$p] $d`n"
    }
}

# ── Assemble dashboard ────────────────────────────────────────────────

$now = Get-Date -Format "HH:mm:ss"
$total = $domains.Count

$content = @"
# AUTODEV v3 -- Live Dashboard

> Cycle **$cycleDisplay** | Wave **$waveDisplay** | Etat **$stateDisplay** | $now

---

## Workers ($doneCount/$total done, $progressCount en cours, $errorCount erreurs)

| | Domaine | Statut | Detail |
|---|---------|--------|--------|
$($domainRows -join "`n")
$directorSection
$escalationSection
$directivesSection

---

*Auto-refresh: ce fichier est mis a jour toutes les 30s par le pipeline.*
"@

$content | Set-Content $outFile -Encoding UTF8 -NoNewline
