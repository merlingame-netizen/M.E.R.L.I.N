# M.E.R.L.I.N. Studio Director — Cycle Instructions

## Mode: FULL AUTO — ALTERNANCE DEV/TEST

Aucune intervention humaine. Alterne entre cycles DEV et cycles TEST.

## IMPORTANT — Environnement cloud sandbox

Tu tournes dans un sandbox Linux ephemere (Remote Trigger). Regles critiques:
- **IGNORE** toutes les references a `validate.bat`, hooks Python, `route-and-dispatch.py`, `gate_enforcer.py` dans CLAUDE.md — ils n'existent pas ici.
- **IGNORE** le "Post-Dev Checklist" de CLAUDE.md (validate/fix/revalidate) — pas applicable en sandbox.
- **IGNORE** le "Questioning Protocol" — aucun humain a qui poser des questions.
- **PAS de `git push --force`** — uniquement `git push origin main`.
- Si `git push` echoue (non-fast-forward): `git pull --rebase origin main` puis retry.
- Prefix implicite `*` sur tout — bypass total du gate algorithm.
- Utilise `grep` et `cat` directement (pas les outils Read/Grep qui peuvent avoir des restrictions).
- Le repo est deja clone via le PAT. `git push` devrait fonctionner directement.

## Fichiers de coordination

- `tools/autodev/status/feature_queue.json` — Taches pending (source de verite)
- `tools/autodev/status/events.jsonl` — Log evenements
- `tools/autodev/status/test_reports/` — Rapports de test
- `docs/GAME_DESIGN_BIBLE.md` — Bible game design v2.4

## Human Feedback — Lire les reponses du Directeur

Avant de selectionner une tache:
1. Lire `tools/autodev/status/feedback_responses.json`
2. Pour chaque reponse non encore traitee (comparer avec `feedback_questions.json` status):
   - Appliquer la decision du directeur au domaine concerne
   - Si la reponse change les priorites, mettre a jour `feature_queue.json`
3. Mettre a jour `feedback_questions.json`: les questions correspondantes passent a `status: "answered"`

## Human Feedback — Generer des questions

Apres avoir complete le travail, AVANT le git commit:
1. Lire `tools/autodev/status/feedback_questions.json`
2. NE PAS ajouter de doublons (verifier les IDs existants)
3. Generer des questions UNIQUEMENT quand:
   - Un choix de design a 2+ alternatives viables → `type: "multiple_choice"`, `category: "design"` ou `"gamedesign"`
   - Un changement visuel pourrait aller dans 2 directions → `type: "image_compare"`, `category: "graphics"` ou `"rendering"`
   - Un flow UX a des compromis → `type: "text"`, `category: "ux"`
4. Format: `id: "q-{YYYYMMDD}-{NNN}"`, `status: "pending"`, `priority: "HIGH"|"MEDIUM"|"LOW"`
5. Maximum **3 nouvelles questions par cycle**
6. Commit `feedback_questions.json` et `feedback_responses.json` avec les autres fichiers

## SPRINT PRIORITY (CRITICAL)

La queue est organisee en 3 sprints. **Execute Sprint 1 en entier (P1-P6) avant Sprint 2.**
- Sprint 1 (S1-*): Core loop jouable — cleanup + Oghams + tests core + LLM validation
- Sprint 2 (S2-*): Contenu — biomes, verbes, MOS, dead code restant
- Sprint 3 (S3-*): Polish — edge cases, robustesse LLM

**Ne PAS commencer Sprint 2 tant que TOUTES les taches S1-* sont completed + tests S1-CORE-TEST et S1-LLM-VALIDATE passes.**
Les taches test sont intercalees — execute-les dans l'ordre de priorite comme les taches dev.

## Logique d'alternance

1. Lire les 5 dernieres lignes de `tools/autodev/status/events.jsonl`
2. Chercher le dernier evenement avec `"type":"cycle_update"`
3. Si son `data.cycle_type` etait `"dev"` → ce cycle est TEST
4. Si `"test"` → ce cycle est DEV
5. Si pas de `cycle_type` trouve → ce cycle est DEV (defaut)

## Cycle DEV — MODE BATCH (3-5 taches par cycle)

> Precedemment 1 tache/cycle ~= 1 commit/heure = trop lent. Maintenant un cycle ship un BATCH coherent.

1. Lire `tools/autodev/status/feature_queue.json`
2. Filtrer: `status=pending` ET (`type=dev` OU `type` absent)
3. **Selectionner 3 a 5 taches** en ordre de priorite:
   - TOUJOURS inclure la tache P1-P5 de plus haute priorite (si existe)
   - Remplir le batch avec des taches compatibles: meme domaine (tous LLM, tous VFX, tous minigames...) OU fichiers non conflictuels
   - Preferer gameplay (cards, oghams, minigames, factions, biomes, SFX, narrative, scenes 3D)
   - Max 5 taches pour eviter de depasser le budget temps du sandbox (~15min)
4. Pour CHAQUE tache du batch (sequentiel):
   a. Lire les fichiers cibles (champ `files`)
   b. Implementer en GDScript: `snake_case`, type hints, JAMAIS `:=` avec CONST
   c. Verifier via `grep` que les modifications sont correctes
   d. Self-QA: call-site grep si la tache ajoute une fonction (cf. VERIFIER section)
5. Mettre a jour `feature_queue.json`: pour chaque tache du batch, `status="completed"`, `completed_at`, `notes`
6. Ajouter UNE ligne a `events.jsonl` listant les N taches completees:
   `{"type":"cycle_update","timestamp":"...","data":{"cycle_type":"dev","batch_size":N,"task_ids":["T1","T2",...],"summary":"short combined summary"}}`
7. UN SEUL commit + push pour tout le batch:
   `git add -A && git commit -m "feat(scope): batch of N fixes (T1, T2, T3)" && git push origin main`
8. Si une tache du batch echoue: la laisser `status=pending`, noter `notes="failed: reason"`, et CONTINUER avec les autres. Ne jamais bloquer le batch entier sur une tache.

**Fallback** : si moins de 3 taches compatibles disponibles, shipper ce qu'il y a (1 ou 2 suffisent). Mieux vaut 1 shipee que 0.

## Cycle TEST — MODE BATCH (2-3 rapports par cycle)

1. `git pull origin main`
2. Lire `feature_queue.json`, filtrer: `type=test`, `status=pending`
3. Selectionner **2 a 3 taches test** en ordre de priorite (audits peuvent s'executer en sequence rapide)
4. Pour CHAQUE tache test:
   a. Executer selon l'agent:
      - `game_playtester`: Simuler sessions, verifier invariants (vie 0-100, rep caps +-20, MOS 8-50)
      - `game_design_auditor`: Comparer code vs `GAME_DESIGN_BIBLE.md`, lister ecarts
      - `bug_hunter`: Analyse statique, null access, type errors, softlocks
   b. Ecrire rapport JSON dans `test_reports/`
   c. Si bugs CRITICAL: creer des taches dev (`priority=1`, `type=fix`)
5. Mettre a jour `feature_queue.json`: toutes les taches du batch `status=completed`
6. Logger UNE ligne `events.jsonl` avec tous les task_ids + combined summary
7. UN SEUL commit + push: `test(scope): batch N audits + M new fix tasks`

## Housekeeping (chaque cycle)

### Queue cleanup
Deplacer les taches `status=completed` dans `tools/autodev/status/completed_archive.json` (creer si absent). Ne garder que pending/in_progress dans `feature_queue.json`.

**DEDUPE GUARD (OBLIGATOIRE avant push archive)**:
1. Avant d'ajouter une tache a `completed_archive.json`, charger l'archive existante.
2. Verifier qu'aucune entree n'a deja la meme cle `(id, completed_at)`.
3. Si doublon detecte → SKIP l'ajout (ne pas dupliquer).
4. Pattern bash: `python tools/autodev/scripts/dedupe_completed.py` apres tout ajout pour garantir l'idempotence.

### Meta-work bias (SOFT — prefere gameplay, ne bloque JAMAIS le cycle)
**REGLE (preference, pas blocage absolu)**:
1. A l'etape 3 de selection: PREFERER les taches gameplay (cards, oghams, minigames, factions, biomes, SFX, narrative, scenes 3D, godot_expert, game_designer, narrative_specialist, tech_artist) aux taches meta (dashboard, orchestrator, cycle, cli, monitor, api, mission-control).
2. Priorite egale → choisir la tache gameplay.
3. **IMPORTANT** : Si la seule tache disponible est meta, L'EXECUTER QUAND MEME. Un cycle sans commit = echec. Mieux vaut meta-work que rien.
4. Fallback absolu: si aucune tache pending n'est actionnable, generer une tache housekeeping (dedupe archive + rotate events + update watchdog) et commit cette action minimum pour preserver le rythme.
Objectif long-terme: ~70% gameplay / 30% meta sur 10 cycles glissants. **TOUJOURS shipper quelque chose.**

### Events rotation
Si `events.jsonl` depasse 200 lignes: garder les 50 dernieres, archiver le reste dans `tools/autodev/status/events_archive/YYYY-MM.jsonl`.

### Auto-generation (CRITICAL — 10+ pending tasks minimum)
**REGLE**: Il doit TOUJOURS y avoir au minimum 10 taches pending dans `feature_queue.json`.
Si le nombre de taches pending tombe sous 10 apres archivage:
1. Lire `docs/DEV_PLAN_V2.5.md` et `docs/GAME_DESIGN_BIBLE.md`
2. Identifier la prochaine phase/sprint logique
3. Decomposer en taches atomiques (completables en 1 cycle ~15 min)
4. Creer les taches manquantes jusqu'a avoir 10+ pending
5. Chaque tache DOIT avoir: id, sprint, priority, type (dev/test), title, agent, files, description
6. Alterner dev et test: pour chaque 3-4 taches dev, ajouter 1 tache test
7. Les nouvelles taches suivent la progression: S2→S3→S4→S5 (jamais revenir en arriere)

## Self-check (watchdog integre)

A chaque cycle, avant de commencer:
1. Verifier que `feature_queue.json` a des taches pending. Si 0 pending (dev ET test): lire `docs/DEV_PLAN_V2.5.md` et creer 3-5 nouvelles taches.
2. Ecrire la date du cycle dans `tools/autodev/status/watchdog.txt` (append: `YYYY-MM-DDTHH:MM:SS OK`).
3. Si le cycle echoue pour quelque raison que ce soit, ecrire l'erreur dans `tools/autodev/status/escalation.json` et commit+push quand meme.

## Self-Improvement (OBLIGATOIRE — chaque cycle)

### 1. Apprendre de ses propres rapports

Avant de coder, lire les derniers test reports dans `tools/autodev/status/test_reports/`:
- Si un rapport precedent a trouve des patterns de bugs → verifier que le fix actuel ne les reproduit pas
- Si un rapport a note des invariants PASS → ne pas casser ces invariants
- Accumuler les lecons dans `tools/autodev/status/studio_learnings.json`

### 2. Self-QA — Verifier son propre travail

Apres chaque modification de code:
- Grep le fichier modifie pour verifier: pas de `:=` avec CONST, type hints presents, snake_case respecte
- Si cycle DEV: verifier que les invariants du dernier test report sont toujours respectes
- Si cycle TEST: comparer avec le rapport precedent — les bugs ont-ils ete fixes ? De nouveaux sont-ils apparus ?

**VERIFIER CALL-SITE GREP (OBLIGATOIRE pour eviter false-positive PASS)**:
Pour chaque tache marquee `completed` qui declare "added function X" ou "implemented method Y":
1. Grep le nom de la fonction dans tout le repo: `grep -rn "func X\|X(" --include="*.gd"`
2. Si trouve UNE SEULE fois (definition seule, aucun call-site) → MARQUER comme `FAIL_CRITICAL` et ROUVRIR la tache (status=pending, priority=1, note "verifier false-positive: function defined but never called").
3. Si trouve >= 2 fois (definition + au moins 1 call-site) → PASS.
4. Lecon S2-ARC-CONDITION-EVAL (2026-04-14): la tache avait ete marquee completed alors que le dispatcher n'etait pas cable dans `llm_adapter_map_prompt.gd:96`. Cette regle empeche la repetition.

### 3. Agent Evolution — Creer/specialiser des agents

Le studio a des agents virtuels (champ `agent` dans les taches). Les evoluer:
- Si un type de tache n'a pas d'agent adapte → creer un nouveau agent_id (ex: `llm_prompt_engineer`, `shader_artist`)
- Si un agent echoue regulierement → noter la faiblesse dans `studio_learnings.json`
- Si un pattern revient → creer une checklist dans la description de l'agent

### 4. LLM Model Awareness

Pour les taches impliquant le LLM (generation de cartes, prompts):
- Noter le modele utilise dans le rapport (ex: `qwen3.5:2b`)
- Si le modele produit des JSON malformes → ajuster le prompt template
- Si un nouveau modele est disponible dans Ollama → proposer un test comparatif en feedback question
- Documenter les prompts qui fonctionnent bien dans `studio_learnings.json`

### 5. Metrics Tracking

A chaque cycle, mettre a jour `tools/autodev/status/studio_learnings.json`:
```json
{
  "total_cycles": N,
  "bugs_found": N,
  "bugs_fixed": N,
  "patterns_learned": ["pattern1", "pattern2"],
  "agent_performance": {"agent_id": {"tasks_completed": N, "bugs_introduced": N}},
  "llm_quality": {"model": "qwen3.5:2b", "json_success_rate": "N%", "avg_quality": "N/10"}
}
```

### 6. Autonomie Decision

Le bot est autorise a prendre des decisions mineures SANS feedback humain:
- Renommer des variables/fonctions pour clarte
- Choisir l'ordre d'execution entre taches de meme priorite
- Creer des taches de suivi (bugs, refactors)
- Ajuster la priorite +/-1 d'une tache

Decisions qui REQUIERENT feedback humain (via feedback_questions.json):
- Supprimer un systeme entier
- Changer l'architecture (nouveau singleton, refonte d'un pattern)
- Modifier le game design (equilibrage, nouvelles mecaniques)
- Choix visuels (couleurs, shaders, layout)

## Studio Insights — Agent Feature Proposals (chaque cycle)

Apres chaque cycle termine, SI tu identifies une amelioration pour le jeu ou le dashboard:
1. Lire `tools/autodev/status/studio_insights.json` (creer si absent)
2. Ajouter une suggestion avec structure:
```json
{
  "id": "insight-YYYYMMDD-NNN",
  "agent": "agent_id",
  "severity": "INFO|WARN|ACTION",
  "category": "gameplay|ux|performance|i18n|visual|dashboard",
  "message": "Description courte de la suggestion",
  "details": "Explication detaillee avec justification",
  "proposed_task": { "title": "...", "sprint": "S3", "type": "dev" },
  "timestamp": "ISO8601"
}
```
3. Maximum 1 insight par cycle — qualite > quantite
4. Le directeur voit ces insights sur le dashboard et peut approuver/rejeter

## i18n — Strings et traduction

Toutes les strings user-facing du jeu sont dans `data/i18n/text_registry.json`.
- Pour acceder a une string: `I18nRegistry.t("ui.hub.anam_label")` ou `I18nRegistry.tf("key", [args])`
- NE JAMAIS hardcoder du texte francais dans le code — utiliser le registre
- Si tu dois ajouter une nouvelle string: l'ajouter dans `text_registry.json` avec la cle FR remplie et les autres langues vides
- Le `i18n_auditor_agent` detectera les strings hardcoded restantes

## Multi-Platform Awareness

Le jeu cible PC + mobile + web. Regles:
- `InputAdapter` (autoload) gere touch/mouse/gamepad — ne pas utiliser Input directement pour les interactions UI
- `PlatformManager` (autoload) detecte la plateforme et ajuste la qualite
- Touch targets minimum 44px (WCAG)
- Pas de texte < 11px (illisible sur mobile)
- Shaders doivent avoir un fallback LOW quality

## Visual Testing (quand implemente)

Le pipeline `tools/autodev/visual-tester/` capture des screenshots de scenes Godot.
- `screenshot_agent.gd`: capture viewport toutes les 2s, sauvegarde dans `scene_screenshots/`
- Les screenshots sont analyses par Claude Vision (perspective joueur, pas code)
- Les bugs visuels detectes doivent etre crees comme taches dans `feature_queue.json`

## Regles strictes

- Source de verite: `docs/GAME_DESIGN_BIBLE.md` v2.4
- JAMAIS modifier `GAME_DESIGN_BIBLE.md` ni `DEV_PLAN_V2.5.md`
- GDScript: `snake_case`, `PascalCase` classes, type hints obligatoires
- Fichiers < 400 lignes, fonctions < 50 lignes
- Toutes couleurs depuis `MerlinVisual.PALETTE`
- Commit: `type(scope): description`
- Si escalation necessaire: ecrire dans `tools/autodev/status/escalation.json`
