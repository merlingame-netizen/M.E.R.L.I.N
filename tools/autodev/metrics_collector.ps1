# metrics_collector.ps1 — M.E.R.L.I.N. Metrics Collector v1.0
# Collecte les métriques du jeu à chaque cycle studio_loop.
# Écrit dans tools/autodev/status/metrics_latest.json + metrics_history.jsonl

param(
    [int]$CycleNum = 0
)

$ErrorActionPreference = "Continue"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$statusDir   = Join-Path $scriptDir "status"
$capturesDir = Join-Path $projectRoot "captures"
$baselineDir = Join-Path $capturesDir "baseline"

$metrics = @{
    cycle       = $CycleNum
    timestamp   = (Get-Date -Format "o")
    parse       = @{}
    codebase    = @{}
    lore        = @{}
    visual      = @{}
    perf        = @{}
    llm         = @{}
    systems     = @{}
}

Write-Host "[METRICS] Collecte cycle #$CycleNum..." -ForegroundColor Cyan

# ── 1. Parse errors (depuis validate.bat log le plus récent) ───────────

$validateLogs = Get-ChildItem (Join-Path $scriptDir "logs") -Filter "validate_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($validateLogs) {
    $logContent     = Get-Content $validateLogs.FullName -Raw -ErrorAction SilentlyContinue
    $errorCount     = ($logContent | Select-String "ERROR:" | Measure-Object).Count
    $warningCount   = ($logContent | Select-String "WARNING:" | Measure-Object).Count

    # Chercher références Triade résiduelles
    $triadeRefs = ($logContent | Select-String "Triade|SHIFT_ASPECT|SOUFFLE|Corps.*Ame.*Monde|AspectState" | Measure-Object).Count

    $metrics.parse = @{
        errors        = $errorCount
        warnings      = $warningCount
        triade_refs   = $triadeRefs
        status        = if ($errorCount -eq 0) { "PASS" } else { "FAIL" }
        log_file      = $validateLogs.Name
    }
} else {
    $metrics.parse = @{ status = "NO_LOG"; errors = -1; warnings = -1; triade_refs = -1 }
}

Write-Host "  Parse errors: $($metrics.parse.errors) | Warnings: $($metrics.parse.warnings) | Triade refs: $($metrics.parse.triade_refs)"

# ── 2. Codebase scan ────────────────────────────────────────────────────

# Compter les références Triade encore présentes dans le code GDScript
$gdFiles    = Get-ChildItem $projectRoot -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue
$gdCount    = $gdFiles.Count
$triadeInCode = 0
$corpsAme   = 0

foreach ($f in $gdFiles) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if ($content -match "Triade|SHIFT_ASPECT|SOUFFLE_MAX|AspectState|TRIADE_ASPECTS") {
            $triadeInCode++
        }
        if ($content -match "Corps.*Ame|Ame.*Monde|Corps.*Monde|aspect_state") {
            $corpsAme++
        }
    }
}

# Compter les Oghams définis dans merlin_constants
$constantsPath = Join-Path $projectRoot "scripts/merlin/merlin_constants.gd"
$oghamCount = 0
if (Test-Path $constantsPath) {
    $constContent = Get-Content $constantsPath -Raw
    $oghamCount = ([regex]::Matches($constContent, "OGHAM_[A-Z]+")).Count
}

# Vérifier si merlin_reputation_system.gd existe
$reputationExists = Test-Path (Join-Path $projectRoot "scripts/merlin/merlin_reputation_system.gd")

# Vérifier si game_time_manager.gd existe
$timeManagerExists = Test-Path (Join-Path $projectRoot "scripts/autoload/game_time_manager.gd")

$metrics.codebase = @{
    gd_files_total          = $gdCount
    triade_files_remaining  = $triadeInCode
    corps_ame_remaining     = $corpsAme
    triade_clean            = ($triadeInCode -eq 0)
    oghams_defined          = $oghamCount
    reputation_system_exists = $reputationExists
    time_manager_exists     = $timeManagerExists
}

Write-Host "  GDScript files: $gdCount | Triade still present: $triadeInCode files | Oghams: $oghamCount"

# ── 3. Documentation scan ────────────────────────────────────────────────

$docsDir    = Join-Path $projectRoot "docs"
$mdFiles    = Get-ChildItem $docsDir -Recurse -Filter "*.md" -ErrorAction SilentlyContinue
$mdCount    = $mdFiles.Count
$triadeInDocs = 0
$newMechDocExists = Test-Path (Join-Path $projectRoot "docs/NEW_MECHANICS_DESIGN.md")

foreach ($f in $mdFiles) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and ($content -match "Triade|SHIFT_ASPECT|SOUFFLE|Corps.*Ame.*Monde|AspectState")) {
        $triadeInDocs++
    }
}

$metrics.lore = @{
    md_files_total         = $mdCount
    triade_docs_remaining  = $triadeInDocs
    new_mechanics_doc      = $newMechDocExists
    docs_clean             = ($triadeInDocs -eq 0)
}

Write-Host "  MD files: $mdCount | Triade in docs: $triadeInDocs"

# ── 4. Métriques perf (depuis captures/perf.json si existant) ──────────

$perfPath = Join-Path $capturesDir "perf.json"
if (Test-Path $perfPath) {
    $perf = Get-Content $perfPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    $metrics.perf = @{
        fps_avg    = if ($perf.fps_avg) { $perf.fps_avg } else { -1 }
        draw_calls = if ($perf.draw_calls) { $perf.draw_calls } else { -1 }
        memory_mb  = if ($perf.memory_mb) { $perf.memory_mb } else { -1 }
        status     = if ($perf.fps_avg -gt 55) { "OK" } else { "WARN" }
    }
} else {
    $metrics.perf = @{ status = "NO_CAPTURE"; fps_avg = -1; draw_calls = -1; memory_mb = -1 }
}

# ── 5. Qualité LLM (depuis logs Ollama si disponibles) ─────────────────

$ollamaLogDir = Join-Path $projectRoot "logs"
$llmLogs = Get-ChildItem $ollamaLogDir -Filter "*.log" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 3

$jsonValidCount = 0
$jsonTotalCount = 0

foreach ($log in $llmLogs) {
    $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $attempts = ([regex]::Matches($content, "JSON_ATTEMPT|json_attempt|generate_card")).Count
        $valid    = ([regex]::Matches($content, "JSON_VALID|json_valid|card_generated")).Count
        $jsonTotalCount += $attempts
        $jsonValidCount += $valid
    }
}

$llmQuality = if ($jsonTotalCount -gt 0) {
    [math]::Round($jsonValidCount * 100.0 / $jsonTotalCount, 1)
} else { -1 }

$metrics.llm = @{
    json_valid_rate  = $llmQuality
    json_total       = $jsonTotalCount
    json_valid       = $jsonValidCount
    status           = if ($llmQuality -gt 90 -or $llmQuality -eq -1) { "OK" } else { "WARN" }
}

Write-Host "  LLM JSON quality: $llmQuality% ($jsonValidCount/$jsonTotalCount)"

# ── 6. Visual diff (screenshots baseline) ────────────────────────────────

$visualScript = Join-Path $scriptDir "visual_diff.ps1"
if (Test-Path $visualScript) {
    $visualResult = & $visualScript 2>&1
    $delta = ($visualResult | Select-String "delta=(\d+\.?\d*)%" | ForEach-Object {
        $_.Matches[0].Groups[1].Value
    }) | Select-Object -First 1
    $metrics.visual = @{
        delta_pct = if ($delta) { [double]$delta } else { -1 }
        status    = if ($delta -and [double]$delta -lt 5) { "OK" } else { "UNCHECKED" }
    }
} else {
    $metrics.visual = @{ status = "NO_SCRIPT"; delta_pct = -1 }
}

# ── 7. Systèmes présents ────────────────────────────────────────────────

$metrics.systems = @{
    reputation_impl     = $reputationExists
    day_night_extended  = $timeManagerExists
    reputation_hud      = (Test-Path (Join-Path $projectRoot "scripts/ui/reputation_hud.gd"))
    new_mechanics_doc   = $newMechDocExists
    calendar_active     = (Test-Path (Join-Path $projectRoot "scripts/Calendar.gd"))
}

# ── Dashboard live ───────────────────────────────────────────────────────

$dashboardPath = Join-Path $statusDir "live_dashboard.md"
$triadeStatus  = if ($metrics.codebase.triade_clean) { "CLEAN" } else { "$($metrics.codebase.triade_files_remaining) fichiers" }
$docsStatus    = if ($metrics.lore.docs_clean) { "CLEAN" } else { "$($metrics.lore.triade_docs_remaining) docs" }

$dashboard = @"
# M.E.R.L.I.N. Live Dashboard — Cycle #$CycleNum
> Mis à jour : $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Status Global

| Métrique | Valeur | Status |
|---|---|---|
| Parse errors | $($metrics.parse.errors) | $(if($metrics.parse.errors -eq 0){'✅'}else{'❌'}) |
| Triade dans le code | $triadeStatus | $(if($metrics.codebase.triade_clean){'✅'}else{'⚠️'}) |
| Triade dans les docs | $docsStatus | $(if($metrics.lore.docs_clean){'✅'}else{'⚠️'}) |
| Oghams définis | $($metrics.codebase.oghams_defined)/18 | $(if($metrics.codebase.oghams_defined -ge 18){'✅'}else{'⚠️'}) |
| FPS moyen | $($metrics.perf.fps_avg) | $(if($metrics.perf.fps_avg -gt 55){'✅'}elseif($metrics.perf.fps_avg -eq -1){'—'}else{'❌'}) |
| LLM JSON quality | $($metrics.llm.json_valid_rate)% | $(if($metrics.llm.json_valid_rate -gt 90 -or $metrics.llm.json_valid_rate -eq -1){'✅'}else{'⚠️'}) |

## Systèmes

| Système | Présent |
|---|---|
| Réputation (code) | $(if($metrics.systems.reputation_impl){'✅'}else{'❌'}) |
| Réputation HUD | $(if($metrics.systems.reputation_hud){'✅'}else{'❌'}) |
| Cycle Jour/Nuit (global) | $(if($metrics.systems.day_night_extended){'✅'}else{'❌'}) |
| NEW_MECHANICS_DESIGN.md | $(if($metrics.systems.new_mechanics_doc){'✅'}else{'❌'}) |
| Calendrier celtique | $(if($metrics.systems.calendar_active){'✅'}else{'❌'}) |

## Feature Queue
$(
    $queuePath = Join-Path $statusDir "feature_queue.json"
    if (Test-Path $queuePath) {
        $q = Get-Content $queuePath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($q) {
            $pending = @($q.tasks | Where-Object { $_.status -eq "pending" })
            $done    = @($q.tasks | Where-Object { $_.status -eq "completed" })
            "Completed: $($done.Count) / $(($q.tasks | Measure-Object).Count) | Pending: $($pending.Count)"
        }
    }
)
"@

$dashboard | Set-Content $dashboardPath -Encoding UTF8

# ── Écrire metrics_latest.json ────────────────────────────────────────

$metrics | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $statusDir "metrics_latest.json") -Encoding UTF8

# Historique (append)
$historyPath = Join-Path $statusDir "metrics_history.jsonl"
($metrics | ConvertTo-Json -Compress) | Add-Content $historyPath -Encoding UTF8

Write-Host "[METRICS] Dashboard mis à jour : $dashboardPath" -ForegroundColor Green
