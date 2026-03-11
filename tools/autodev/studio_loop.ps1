# studio_loop.ps1 — M.E.R.L.I.N. Studio Loop v1.0
# Cycle autonome 30 min : Build -> Validate -> Metrics -> Report -> Questions
# Usage : Invoqué par /loop 30m via Claude Code, ou directement : .\studio_loop.ps1
#
# Chaque cycle :
#   1. Lit l'état et les métriques précédentes
#   2. Prend 1-2 tâches dans feature_queue.json
#   3. Implémente via claude -p (agent autonome)
#   4. Valide avec validate.bat
#   5. Collecte métriques (metrics_collector.ps1)
#   6. Écrit rapport de cycle
#   7. Génère 3 questions d'orientation pour l'utilisateur

param(
    [switch]$DryRun,
    [string]$FocusTask = ""   # Forcer une tâche spécifique si besoin
)

$ErrorActionPreference = "Continue"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$statusDir   = Join-Path $scriptDir "status"
$logsDir     = Join-Path $scriptDir "logs"

# Chemins config
$configPath       = Join-Path $scriptDir "config/work_units_v2.json"
$queuePath        = Join-Path $statusDir "feature_queue.json"
$sessionPath      = Join-Path $statusDir "session.json"
$metricsLatest    = Join-Path $statusDir "metrics_latest.json"
$questionsPath    = Join-Path $statusDir "questions_pending.json"
$config = $null
try {
    $config = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "[STUDIO] FATAL: Impossible de lire $configPath : $_" -ForegroundColor Red
    @{ state = "error"; objective = "config load failed"; cycle = 0; updated_at = (Get-Date -Format "o"); checkpoint = ""; workers = @() } |
        ConvertTo-Json | Set-Content (Join-Path $scriptDir "status/session.json") -Encoding UTF8 -ErrorAction SilentlyContinue
    exit 1
}
$claudeExe   = $config.claude_exe
$claudeModel = $config.claude_model
$permMode    = $config.claude_permission_mode

# Timestamp pour ce cycle
$ts       = Get-Date -Format "yyyyMMdd_HHmm"
$reportPath = Join-Path $statusDir "cycle_report_$ts.md"

# Numéro de cycle
$cycleNum = 1
if (Test-Path $sessionPath) {
    $sess = Get-Content $sessionPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($sess -and $sess.cycle) { $cycleNum = $sess.cycle + 1 }
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  M.E.R.L.I.N. Studio Loop — Cycle #$cycleNum" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Helper: Mise à jour session.json ────────────────────────────────────

function Update-Session {
    param([string]$Objective, [string]$State = "running")
    $s = @{
        state      = $State
        objective  = $Objective
        cycle      = $cycleNum
        updated_at = (Get-Date -Format "o")
        checkpoint = "studio_loop"
        workers    = @(@{ name = "studio_loop"; wave = 1; status = $State })
    }
    # Écriture atomique (temp + rename) pour éviter les lectures partielles
    $tmp = "$sessionPath.tmp"
    $s | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $sessionPath -Force
}

# ── Helper: Invocation claude agent ────────────────────────────────────

function Invoke-ClaudeAgent {
    param(
        [string]$AgentName,
        [string]$Prompt,
        [string]$Tools = "Edit,Write,Bash,Read,Glob,Grep,TodoWrite"
    )
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would invoke agent '$AgentName'" -ForegroundColor Yellow
        return $true
    }

    Write-Host "[AGENT] $AgentName — démarrage..." -ForegroundColor Yellow
    # Créer le dossier logs si absent
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    $logFile = Join-Path $logsDir "agent_${AgentName}_$ts.log"

    $promptFile = Join-Path $env:TEMP "merlin_prompt_$AgentName.txt"
    $Prompt | Set-Content $promptFile -Encoding UTF8

    # $claudeArgs (pas $args — variable réservée PowerShell)
    $claudeArgs = @(
        "-p", (Get-Content $promptFile -Raw),
        "--model", $claudeModel,
        "--permission-mode", $permMode,
        "--allowed-tools", $Tools,
        "--output-format", "text"
    )

    & $claudeExe @claudeArgs 2>&1 | Tee-Object -FilePath $logFile
    $success = ($LASTEXITCODE -eq 0)
    Write-Host "[AGENT] $AgentName — $(if($success){'OK'}else{'FAILED'})" -ForegroundColor $(if($success){'Green'}else{'Red'})
    Remove-Item $promptFile -ErrorAction SilentlyContinue
    return $success
}

# ── ÉTAPE 1 : Charger la queue de features ──────────────────────────────

Write-Host "[1/7] Chargement de la feature queue..." -ForegroundColor Magenta

$queue = $null
if (Test-Path $queuePath) {
    $queue = Get-Content $queuePath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}
if (-not $queue) {
    Write-Host "  feature_queue.json introuvable — initialisation depuis le plan" -ForegroundColor Yellow
    # Créer une queue par défaut basée sur Phase 1 (Triade removal)
    $defaultQueue = @{
        version = "1.0"
        updated  = (Get-Date -Format "o")
        tasks    = @(
            @{ id = "TRIADE-CORE-1"; phase = 1; priority = 1; status = "pending";
               title = "Supprimer Triade de merlin_constants.gd";
               agent = "godot_expert";
               files = @("scripts/merlin/merlin_constants.gd");
               description = "Supprimer AspectState enum, TRIADE_ASPECTS, TRIADE_ASPECT_INFO, SOUFFLE_MAX/START. Garder les 18 Oghams et les 5 factions." },
            @{ id = "TRIADE-CORE-2"; phase = 1; priority = 2; status = "pending";
               title = "Nettoyer merlin_store.gd (état Triade)";
               agent = "godot_expert";
               files = @("scripts/merlin/merlin_store.gd");
               description = "Supprimer build_default_state avec 3 aspects. Reconstruire état minimal : tour, ogham_actif, factions (dictionnaire 5 clés), cartes." },
            @{ id = "TRIADE-CORE-3"; phase = 1; priority = 3; status = "pending";
               title = "Nettoyer merlin_effect_engine.gd (SHIFT_ASPECT/SOUFFLE)";
               agent = "godot_expert";
               files = @("scripts/merlin/merlin_effect_engine.gd");
               description = "Supprimer SHIFT_ASPECT, ADD_ASPECT_ALIGNMENT, USE_SOUFFLE, ADD_SOUFFLE. Garder ADD_REPUTATION et les effets narratifs." },
            @{ id = "TRIADE-UI-1"; phase = 1; priority = 4; status = "pending";
               title = "Supprimer hub_triade_hud.gd et hub_souffle_bar.gd";
               agent = "godot_expert";
               files = @("scripts/ui/hub_triade_hud.gd", "scripts/ui/hub_souffle_bar.gd");
               description = "Supprimer ces fichiers UI. Créer reputation_hud.gd minimal (5 factions, affichage texte simple pour l'instant)." },
            @{ id = "MECANIQUE-DESIGN"; phase = 2; priority = 5; status = "pending";
               title = "Mettre à jour NEW_MECHANICS_DESIGN.md avec décisions session";
               agent = "game_designer";
               files = @("docs/NEW_MECHANICS_DESIGN.md");
               description = "Documenter les décisions de game design de la session courante. Poser 3 questions de game design pour la prochaine session." }
        )
    }
    $defaultQueue | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8
    $queue = $defaultQueue
}

# Prendre 1-2 tâches pending par priorité
$pendingTasks = @($queue.tasks | Where-Object { $_.status -eq "pending" } | Sort-Object priority)

if ($FocusTask) {
    $pendingTasks = @($pendingTasks | Where-Object { $_.id -eq $FocusTask })
}

$tasksToRun = $pendingTasks | Select-Object -First 2

if ($tasksToRun.Count -eq 0) {
    Write-Host "  Aucune tâche pending dans la queue — queue terminée ?" -ForegroundColor Green
    Write-Host "  Passage en mode REVIEW uniquement" -ForegroundColor Cyan
}

# ── ÉTAPE 2 : Implémenter les tâches ────────────────────────────────────

Write-Host "[2/7] Implémentation ($($tasksToRun.Count) tâche(s))..." -ForegroundColor Magenta
$taskIds = ($tasksToRun | ForEach-Object { $_.id }) -join ", "
Update-Session -Objective "Cycle $cycleNum — BUILD ($taskIds)"

$buildResults = @{}

foreach ($task in $tasksToRun) {
    Write-Host ""
    Write-Host "  → Tâche : [$($task.id)] $($task.title)" -ForegroundColor Yellow

    # Marquer en cours dans la queue
    $task.status = "in_progress"
    $queue | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8

    $filesContext = ($task.files | ForEach-Object { "  - c:\Users\PGNK2128\Godot-MCP\$_" }) -join "`n"
    $prompt = @"
Tu es un agent de développement autonome pour le jeu M.E.R.L.I.N. (Godot 4.x, GDScript).

## Tâche : $($task.id) — $($task.title)

$($task.description)

## Fichiers concernés :
$filesContext

## Règles ABSOLUES :
- GDScript : snake_case vars/funcs, PascalCase classes, type hints obligatoires
- JAMAIS := avec CONST[index] (type explicite : var c: Color = ...)
- JAMAIS yield(), utiliser await
- JAMAIS supprimer un fichier sans recréer un équivalent fonctionnel
- Après chaque modification : .\validate.bat (tu peux le faire via Bash)
- Si validate.bat montre des erreurs : corriger avant de terminer
- Marquer la tâche completed dans tools/autodev/status/feature_queue.json

## Contexte système :
- Triade (Corps/Âme/Monde) est SUPPRIMÉE entièrement — ne jamais recréer ces concepts
- Les mécaniques conservées : Réputation (5 factions : Druides/Anciens/Korrigans/Niamh/Ankou), 18 Oghams, Calendrier celtique
- Nouvelles mécaniques : à co-designer avec l'utilisateur (voir docs/NEW_MECHANICS_DESIGN.md)
- Jeu Godot 4.5 — toujours utiliser la syntaxe Godot 4.x

Commence par lire les fichiers concernés, puis implémente les modifications.
"@

    $success = Invoke-ClaudeAgent -AgentName $task.id -Prompt $prompt
    $buildResults[$task.id] = $success

    # Mettre à jour statut dans la queue
    $taskInQueue = $queue.tasks | Where-Object { $_.id -eq $task.id }
    if ($taskInQueue) {
        $taskInQueue.status = if ($success) { "completed" } else { "failed" }
        $taskInQueue.completed_at = (Get-Date -Format "o")
    }
    $queue | ConvertTo-Json -Depth 10 | Set-Content $queuePath -Encoding UTF8
}

# ── ÉTAPE 3 : Validation ────────────────────────────────────────────────

Write-Host ""
Write-Host "[3/7] Validation (validate.bat)..." -ForegroundColor Magenta
Update-Session -Objective "Cycle $cycleNum — VALIDATE"

$validateLog = Join-Path $logsDir "validate_$ts.log"
$validateResult = "SKIP"
$validateErrors = 0

if (-not $DryRun) {
    Push-Location $projectRoot
    $validateOutput = & cmd /c ".\validate.bat" 2>&1
    $validateExit   = $LASTEXITCODE
    Pop-Location

    $validateOutput | Set-Content $validateLog -Encoding UTF8
    $validateErrors = ($validateOutput | Select-String "ERROR:" | Measure-Object).Count
    $validateResult = if ($validateExit -eq 0 -and $validateErrors -eq 0) { "PASS" } else { "FAIL ($validateErrors errors)" }

    Write-Host "  validate.bat : $validateResult" -ForegroundColor $(if($validateErrors -eq 0){'Green'}else{'Red'})

    # Auto-correction si erreurs
    if ($validateErrors -gt 0) {
        Write-Host "  → Lancement agent de correction..." -ForegroundColor Yellow
        $fixPrompt = @"
validate.bat a retourné $validateErrors erreur(s) après les modifications du cycle $cycleNum.

Voici le log de validation :
$(Get-Content $validateLog | Select-Object -First 100 | Out-String)

Corrige toutes les erreurs GDScript dans les fichiers du projet M.E.R.L.I.N. (c:\Users\PGNK2128\Godot-MCP).
Règles : snake_case, type hints, await (pas yield), pas := avec CONST.
Relance .\validate.bat après correction pour confirmer 0 erreur.
"@
        Invoke-ClaudeAgent -AgentName "auto-fixer" -Prompt $fixPrompt | Out-Null
    }
} else {
    Write-Host "  [DRY-RUN] validate.bat skipped" -ForegroundColor Yellow
}

# ── ÉTAPE 4 : Métriques ────────────────────────────────────────────────

Write-Host ""
Write-Host "[4/7] Collecte métriques..." -ForegroundColor Magenta
Update-Session -Objective "Cycle $cycleNum — METRICS"

$metricsScript = Join-Path $scriptDir "metrics_collector.ps1"
$metrics = $null
if (Test-Path $metricsScript -and -not $DryRun) {
    & $metricsScript -CycleNum $cycleNum
    if (Test-Path $metricsLatest) {
        $metrics = Get-Content $metricsLatest -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "  metrics_collector.ps1 introuvable ou DryRun — skip" -ForegroundColor Gray
    $metrics = @{ note = "metrics not collected" }
}

# ── ÉTAPE 5 : Review code ──────────────────────────────────────────────

Write-Host ""
Write-Host "[5/7] Code Review (agent)..." -ForegroundColor Magenta
Update-Session -Objective "Cycle $cycleNum — REVIEW"

if ($tasksToRun.Count -gt 0 -and -not $DryRun) {
    $modifiedFiles = ($tasksToRun | ForEach-Object { $_.files } | ForEach-Object { "c:\Users\PGNK2128\Godot-MCP\$_" }) -join ", "
    $reviewPrompt = @"
Fais une code review des fichiers GDScript modifiés dans ce cycle M.E.R.L.I.N. :
$modifiedFiles

Vérifie :
1. Aucune référence à Triade/Corps/Âme/Monde/SHIFT_ASPECT/SOUFFLE
2. Types hints corrects (pas := avec CONST)
3. Pas de yield(), utilise await
4. Signaux correctement connectés
5. Variables privées avec _underscore

Écris le résultat dans tools/autodev/status/review_cycle_$ts.md (CRITICAL/HIGH uniquement).
"@
    Invoke-ClaudeAgent -AgentName "code-reviewer" -Prompt $reviewPrompt -Tools "Read,Glob,Grep,Write" | Out-Null
}

# ── ÉTAPE 6 : Rapport de cycle ────────────────────────────────────────

Write-Host ""
Write-Host "[6/7] Génération rapport cycle #$cycleNum..." -ForegroundColor Magenta

$tasksCompleted = ($buildResults.Values | Where-Object { $_ -eq $true }).Count
$tasksFailed    = ($buildResults.Values | Where-Object { $_ -eq $false }).Count
$pendingRemain  = @($queue.tasks | Where-Object { $_.status -eq "pending" }).Count

$reportContent = @"
# Rapport Cycle #$cycleNum — $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Résumé
| Indicateur | Valeur |
|---|---|
| Tâches traitées | $($tasksToRun.Count) |
| Succès | $tasksCompleted |
| Échecs | $tasksFailed |
| Queue restante | $pendingRemain tâches |
| Validation | $validateResult |

## Tâches exécutées
$(
    $tasksToRun | ForEach-Object {
        $status = if ($buildResults[$_.id]) { "DONE" } else { "FAIL" }
        "- **[$status]** ``$($_.id)`` — $($_.title)"
    }
)

## Métriques
$(
    if ($metrics) {
        $metrics | ConvertTo-Json -Depth 3
    } else {
        "Non collectées ce cycle"
    }
)

## Prochaines tâches en queue
$(
    @($queue.tasks | Where-Object { $_.status -eq "pending" } | Select-Object -First 5) | ForEach-Object {
        "- ``$($_.id)`` (P$($_.priority)) — $($_.title)"
    }
)

---
*Studio Loop v1.0 — $(Get-Date -Format 'o')*
"@

$reportContent | Set-Content $reportPath -Encoding UTF8
Write-Host "  Rapport : $reportPath" -ForegroundColor Green

# ── ÉTAPE 7 : Générer 3 questions d'orientation ──────────────────────

Write-Host ""
Write-Host "[7/7] Génération des questions d'orientation..." -ForegroundColor Magenta
Update-Session -Objective "Cycle $cycleNum — QUESTIONS"

# Questions générées par contexte de la queue
$questions = @()

# Q1 : Game design (toujours posée)
$q1Context = "Phase 1 (Triade removal) : $($tasksCompleted) tâches complétées ce cycle, $pendingRemain restantes."
$questions += @{
    id       = 1
    agent    = "game_designer"
    priority = "HIGH"
    question = "Les 3 options par carte (Gauche/Centre/Droite) sont-elles conservées dans le nouveau design ? Ou veux-tu repenser la structure de choix ?"
    context  = $q1Context
}

# Q2 : Feature suivante
$nextTask = $queue.tasks | Where-Object { $_.status -eq "pending" } | Sort-Object priority | Select-Object -First 1
$q2Question = if ($nextTask) {
    "Prochaine tâche prévue : '$($nextTask.title)'. On continue avec ça, ou il y a une priorité plus urgente ?"
} else {
    "La queue Phase 1 est vide. Quelle est la prochaine phase à attaquer ? (Jour/Nuit, Réputation, ou autre ?)"
}
$questions += @{
    id       = 2
    agent    = "game_director"
    priority = "MEDIUM"
    question = $q2Question
    context  = "Queue restante : $pendingRemain tâches"
}

# Q3 : Validation visuelle / mécanique
$q3Options = @(
    "Lancer une partie de test dans Godot pour vérifier que le jeu tourne sans la Triade",
    "Commencer à esquisser le nouveau HUD (sans Triade) — quelle info afficher ?",
    "Documenter les conditions de victoire/défaite dans NEW_MECHANICS_DESIGN.md"
)
$questions += @{
    id       = 3
    agent    = "ux_director"
    priority = "LOW"
    question = "Parmi ces 3 orientations, laquelle veux-tu prioriser pour le prochain cycle ?"
    context  = ($q3Options | ForEach-Object { "  - $_" }) -join "`n"
}

$questionsPayload = @{
    cycle     = $cycleNum
    generated = (Get-Date -Format "o")
    answered  = $false
    questions = $questions
}
$questionsPayload | ConvertTo-Json -Depth 10 | Set-Content $questionsPath -Encoding UTF8

Write-Host "  3 questions écrites dans questions_pending.json" -ForegroundColor Green

# ── Fin du cycle ────────────────────────────────────────────────────────

Update-Session -Objective "Cycle $cycleNum terminé — en attente réponses" -State "idle"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Cycle #$cycleNum terminé ✓" -ForegroundColor Green
Write-Host "║  Tasks: $tasksCompleted OK / $tasksFailed FAIL | Queue: $pendingRemain restantes" -ForegroundColor Green
Write-Host "║  Validation: $validateResult" -ForegroundColor $(if($validateErrors -eq 0){'Green'}else{'Yellow'})
Write-Host "║  Rapport: cycle_report_$ts.md" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "3 questions d'orientation en attente — réponds dans Claude Code." -ForegroundColor Cyan
Write-Host ""

# Afficher les questions directement pour Claude Code
Write-Host "═══ QUESTIONS CYCLE #$cycleNum ═══" -ForegroundColor Yellow
foreach ($q in $questions) {
    Write-Host ""
    Write-Host "Q$($q.id) [$($q.priority)] ($($q.agent)) :" -ForegroundColor White
    Write-Host "  $($q.question)" -ForegroundColor Cyan
    if ($q.context) {
        Write-Host "  Contexte: $($q.context)" -ForegroundColor Gray
    }
}
Write-Host ""
