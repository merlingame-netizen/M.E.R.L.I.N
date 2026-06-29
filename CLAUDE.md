# CLAUDE.md — M.E.R.L.I.N.

> Comportements OBLIGATOIRES pour Claude Code sur ce projet.

---

## REGLES D'AUTO-ACTIVATION (MANDATORY)

### 1. Planning Files — TOUJOURS si > 2 etapes

```
1. LIRE progress.md et task_plan.md (si existants)
2. CREER/METTRE A JOUR task_plan.md avec les phases
3. METTRE A JOUR progress.md apres chaque phase completee
4. DOCUMENTER les erreurs dans findings.md
```

### 2. Validation — AVANT CHAQUE TEST

```bash
python tools/cli.py godot validate_step0   # Parse check headless (le plus fiable)
```

**Ordre**: Editer → validate_step0 → corriger → re-valider → tester dans Godot

**ATTENTION** : les `.bat` sont **bloqués par stratégie de groupe** sur ce poste — toujours
passer par `python tools/cli.py godot ...` (ou `powershell -File tools/<script>.ps1`).
Le parse check **ne detecte PAS** les erreurs runtime (`SCRIPT ERROR`, `Identifier "x" not
declared`, push_error en _ready, etc.). Un script qui parse OK peut crasher au demarrage
de scene. Pour ces cas, voir 2bis ci-dessous.

### 2bis. Smoke + Soak Runtime — AVANT COMMIT runtime (OBLIGATOIRE)

Les **6 scènes canon** : MerlinMenu, MerlinSelection, MerlinGame, MerlinEnd, MerlinOptions,
GemmaConsole. Tout commit qui touche un script ou une scene du flow DOIT passer un smoke
runtime sur **chaque scene affectee**:

```bash
python tools/cli.py godot smoke --scene "res://scenes/MerlinMenu.tscn" --duration 6
python tools/cli.py godot smoke --scene "res://scenes/MerlinGame.tscn" --duration 8
```

Critere de pass : `passed=true` ET `script_errors=[]` ET `exit_code=0`.
Si KO → corriger avant commit. Ne **JAMAIS** committer un bug runtime detectable par smoke.

**R109 (BIBLE §18)** : tout changement du **flow de run** exige en plus le harnais de preuve :

```bash
python tools/cli.py godot soak --runs 200 --autoplay true --loops 3
```

Gate de référence : soak 200/200 + autoplay 3/3, 0 SCRIPT ERROR.

### 3. Post-Dev Checklist — FIN DE SESSION (OBLIGATOIRE)

```
1. VALIDATE       — python tools/cli.py godot validate_step0
2. SMOKE RUNTIME  — python tools/cli.py godot smoke --scene <chaque scene touchee>
3. SOAK (si flow) — python tools/cli.py godot soak --runs 200 --autoplay true (R109)
4. FIX            — Corriger TOUTES erreurs + warnings + script_errors smoke
5. REVALIDATE     — 0 errors validate_step0 ET tous smoke passed=true
6. COMMIT         — git add <fichiers touchés> + git commit (conventional commits)
7. PUSH           — git push origin <branche courante>
8. AGENTS         — Verifier que tous les agents/skills mandates ont ete invoques
```

**JAMAIS** repondre "termine" sans les 6 etapes.

### 4. Smart Workflow — ADAPTATIF

| Complexite | Critere | Action |
|------------|---------|--------|
| **TRIVIAL** | 1 fichier, <10 lignes | Faire directement |
| **SIMPLE** | 1-2 fichiers | Faire directement. MAJ progress.md |
| **MODEREE** | 3+ fichiers OU logique complexe | Planning files + dispatcher + agents OBLIGATOIRES |
| **COMPLEXE** | Multi-systeme, architecture | Dispatcher + planning files + agents review + GSD |

**Hook**: `route-and-dispatch.py` v4.1 (auto: projet, complexite, skills, decomposition, gate state).
**Bypass**: `*` prefix | **Source de verite**: `~/.claude/project_registry.json`

### 5. Agent & Skill Gate (MANDATORY)

**REGLE**: Executer TOUTES les lignes `ACTION N:` du header `[AUTO-ROUTE]` AVANT toute edition de code.
- Exceptions: TRIVIAL, prefixes `*` `/` `!`
- Le hook `gate_enforcer` emettra un `[GATE VIOLATION]` WARNING si vous editez du code avant d'avoir complete les actions.
- Post-implementation: `code-reviewer` sur code modifie, `security-reviewer` avant commit.
- **Ne JAMAIS traiter une demande "a la main" quand un agent ou skill existe.**

Algorithme detaille: `~/.claude/rules/common/gate-algorithm.md`

### 6. Plan Mode Gate (MANDATORY)

En Plan Mode, `gate_enforcer` ne bloque pas (pas d'Edit/Write de code). La discipline est **manuelle** :

```
Phase 1 (Explore)  : Lire progress.md + task_plan.md + memory files
Phase 2 (Design)   : Executer TOUTES les ACTION N: du [AUTO-ROUTE] AVANT d'ecrire le plan file
                     → "Invoke Skill X"  → utiliser Skill tool avec ce skill
                     → "Invoke Agent Y"  → lancer Agent tool avec ce type
Phase 3 (Review)   : Verifier alignement plan vs ACTIONs executees
Phase 4 (Plan)     : Ecrire le plan file (declenche plan_mode dans Neural Monitor)
```

**Neural Monitor** (sidebar VS Code) affiche en direct :
- Badge `PLAN MODE` ou `INTERACTIVE`
- Objectif courant + derniers skills/agents invoques
- Gate compliance : `N/M actions completes (X%)`

### 7. Apprentissage Continu (OBLIGATOIRE)

**REGLE** : En fin de session MODERATE+, invoquer `everything-claude-code:learn-eval` pour extraire les patterns.
**REGLE** : Si une erreur est corrigee par l'utilisateur → documenter dans le KB (`gdscript_knowledge_base.md`).
**REGLE** : Si aucun agent ne couvre le type de tache → en creer un via `create_agent.py`.
**AUTO** : Le hook `session_learner.py` (Stop) execute `optimize_agents.py` automatiquement.

### 8. Memory Capture — Maxime (OBLIGATOIRE)

**Convention fichiers**: `projet__categorie.md` dans `memory/` (merlin/data/cours/_shared/_ref)
**Categories**: `context`, `lessons`, `business_rules`, `decisions`

Quand l'utilisateur corrige une erreur factuelle, precise une regle metier, ou prend une decision:
1. Identifier le projet (merlin/data/cours/_shared)
2. Identifier la categorie (context/lessons/business_rules/decisions)
3. Ecrire immediatement dans le fichier `projet__categorie.md` correspondant
4. Format decisions: `## YYYY-MM-DD: [titre court]\n- [quoi]\n- [pourquoi]`
5. Format lessons: ajouter une ligne au tableau `| Date | Erreur | Correction | Source |`
6. NE PAS attendre la fin de session — capturer en temps reel

En debut de session MODERATE+:
1. Lire `~/.claude/metrics/pending_consolidation.md` si existant
2. Integrer les apprentissages dans les fichiers memoire
3. Supprimer le fichier pending

**Skill**: `/maxime:status` — affiche l'etat complet de la memoire

### 10. MERLIN Systematic Policy — Bible-First + AskUserQuestion (NON-NÉGOCIABLE)

**Décrété 2026-05-16.** Sur projet MERLIN, **toute** session déclenche un protocole strict.

#### 10.1 Bible-first ritual au début de chaque session MERLIN

L'agent **DOIT** lire `docs/BIBLE.md` (**canon unique v2.0** — Quickstart + §18-§24 minimum,
journal R1-R113 au besoin) **AVANT** toute action de code/design. Vérifier cohérence contexte ↔
bible. Divergence détectée → flag + AskUserQuestion réconciliation.
⚠️ `docs/archive/GAME_DESIGN_BIBLE_legacy_v3.8.md` est **ARCHIVÉE, non-autoritaire**.

**Exception** : prefixes `*` `/` `!` bypass. Pure debug sans design decision peut skip si bypass explicite.

#### 10.2 AskUserQuestion cadence longue (étend §questioning-protocol global)

| Complexité | Comportement MERLIN |
|------------|---------------------|
| TRIVIAL | Action directe |
| **SIMPLE+** | **4 questions obligatoires** avant action |
| **MODERATE** | **8-12 questions multi-round** obligatoires (4 rounds × 4 questions) |
| **COMPLEX** | **16+ questions multi-round** (4-6 rounds × 4 questions) |

Pattern multi-round : R1 (divergences fondamentales) → R2 (implications) → R3 (décisions pending) → R4 (politique). Bypass via `*`.

#### 10.3 Bible update cadence per-feature complete

À chaque feature complète (groupe de commits formant une unité), update les sections bible
impactées : nouvelle règle R-numérotée dans la section concernée (ou §18+ versionnée).
Trigger : tout mécanisme listé §1-§24 de `docs/BIBLE.md`.

#### 10.4 Référence canonique v2.0 (2026-06-12, R114)

- **Deck-building narratif celtique** — Citizen Sleeper / Cultist Simulator feel, ton merveilleux-inquiétant
- **Gemma 4 E2B natif** (MerlinLLM GDExtension, GBNF, 100% local, ZÉRO Ollama)
- **2 jauges** : Intégrité 0-10 + Corruption (seuils /5, paliers glitch R75)
- **Geste** : 1 carte principale + 1-2 modificateurs ; résolution hybride tags requis + code ; Gemma narre
- **Run** : 3 titres+pitch générés → squelette 5 beats → lookahead → climax → fins multiples
- **4 factions** (Druides / Créatures & Êtres / Chevalerie déchue / Corrompus) + 4 piliers PNJ
- **6 scènes** : MerlinMenu → MerlinSelection → MerlinGame → MerlinEnd (+ MerlinOptions, GemmaConsole)
- **Brocéliande seul** au MVP ; méta cross-run = fragments du Graal
- **R109** : fiabilité MESURÉE (soak 200/200 + autoplay) après tout changement du flow
- **§19** : roadmap montée en gamme v10.13.1 → v10.19 (juice → contenu → artworks → audio)

### 9. Game Design & Playthrough — Cascade Obligatoire (NON-NÉGOCIABLE)

**Décrété 2026-05-14 part 16.** Toute activité touchant au game design DOIT
déclencher une cascade d'agents spécialisés AVANT toute implémentation.

**Déclencheurs (auto-détection)** :
- Mots-clés : `playthrough`, `jouer`, `playtest`, `game design`, `UX`, `parcours joueur`,
  `mécanique`, `balance`, `équilibrage`, `flow`, `écran`, `transition`, `carte`, `minigame`,
  `choix`, `effet`, `HUD`, `tutoriel`, `onboarding`
- Toute "réflexion sur le jeu" (l'utilisateur réfléchit au gameplay à voix haute)
- Tout playthrough simulé via smoke + capture screenshots

**Cascade obligatoire** (voir `docs/BIBLE.md` §24) :
```
Wave 1 (parallèle):
  - game_designer.md       → cohérence BIBLE.md §1-§24 (canon v2.0)
  - ux_flow.md             → flow + navigation
  - game_playtester.md     → simulation 5 archétypes joueur (optimal/greedy/chaotic/corrompu/tag-ignorant)

Wave 2 (séquentiel):
  - game_design_auditor.md → audit final contre les 4 piliers UX (BIBLE.md §23)
```

**Les 4 piliers UX** (à vérifier par TOUT agent UI/UX/game design — BIBLE.md §23) :
1. **FACILE** — action en ≤2 gestes
2. **ÉVIDENT** — intention lisible <2s sans tuto
3. **MINIMAL** — aucun élément UI sans rôle actif ; l'info ne vit qu'à UN endroit
4. **TACTILE + DESKTOP** — cibles ≥44×44 px, no hover-only, retour visuel ≤100ms

**Référence** : `docs/BIBLE.md` §23 (R118 — source de vérité unique).

---

## Commits

Format: `type(scope): description` — Conventional Commits
Types: feat, fix, refactor, docs, test, chore, perf
Ce projet est personnel — PAS de tag `[AI-assisted]`.

---

## Project Overview

**M.E.R.L.I.N.** — deck-building narratif celtique (Godot 4.5, Windows desktop).
- **Core Loop**: situation (LLM) → main ~5 cartes → 1 principale + 1-2 modificateurs →
  résolution hybride (tags requis → degré ; le code applique les jauges ; Gemma 4 narre) →
  Intégrité/Corruption → situation suivante (lookahead)
- **LLM**: **Gemma 4 E2B natif** (`addons/merlin_llm/` GDExtension, GBNF, 100% local, zéro Ollama)
- **Jauges**: Intégrité 0-10 + Corruption (seuils /5 → événements + glitch R75)
- **Audio**: thème menu MusicGen ; SFX/stingers = roadmap v10.16 (BIBLE §22)
- **Design Ref**: `docs/BIBLE.md` **v2.0 (canon UNIQUE)** — R1-R119 + roadmap §19

---

## TOOL PRIORITY HIERARCHY (OBLIGATOIRE — preference utilisateur)

**Pour toute interaction avec un projet Godot ouvert dans l'editeur, l'ordre est :**

1. **Native MCP godot-mcp** (`mcp__godot-mcp__*`) — TOUJOURS en premier choix
   - Lecture/inspection live : `get_project_info`, `get_current_scene`, `list_nodes`,
     `get_node_properties`, `get_script`
   - Mutations sur la scene ouverte : `create_node`, `delete_node`, `update_node_property`,
     `create_scene`, `open_scene`, `save_scene`
   - Mutations sur le code source : `create_script`, `edit_script`
   - One-shot scripting dans l'editeur live : `execute_editor_script`
2. **CLI native** (`python tools/cli.py godot ...`) — pour le headless / hors-editeur
   - smoke, validate_step0, test, export, telemetry — tout ce qui ne necessite PAS l'editeur ouvert
3. **Edit/Write fichier source** — pour les changements code persistants quand MCP inadapte
   (gros refactor, multi-fichier, regex globale)
4. **Bash Python ad-hoc** — dernier recours, jamais quand MCP/CLI couvrent le besoin

**Anti-patterns** :
- Ecrire un script GDScript jetable pour faire ce qu'`update_node_property` fait en 1 appel
- Lancer `python tools/cli.py godot smoke` quand `mcp__godot-mcp__get_node_properties` suffit
- Editer un fichier `.tscn` avec Edit quand `create_node` + `update_node_property` ferait le job

**Notes connues sur le MCP server** :
- `execute_editor_script` rejette `print(str(x))` (parens imbriquees) — fixe en C38
  (`addons/godot_mcp/commands/editor_script_commands.gd`). Apres ce fix, redemarrer
  l'editeur Godot pour que l'addon recharge.
- MCP query la scene EDITEUR (`/root/<SceneName>` echoue souvent). Utiliser
  `EditorInterface.get_edited_scene_root()` via `execute_editor_script` pour le tree live.

---

## Quick Commands

```bash
python tools/cli.py godot validate_step0       # Parse check (les .bat sont bloqués par GPO)
python tools/cli.py godot smoke --scene res://scenes/MerlinGame.tscn --duration 8
python tools/cli.py godot soak --runs 200 --autoplay true   # Harnais de preuve R109
godot --path .                                 # Run project
/loop 5m <prompt>                              # Tache recurrente
```

### CLI-Anything (agent-native, CLI-first)

```bash
# Godot
python tools/cli.py godot validate              # validate.bat (toutes etapes)
python tools/cli.py godot validate_step0        # Parse check headless uniquement
python tools/cli.py godot test                  # GDScript test runner headless
python tools/cli.py godot smoke --scene res://scenes/MerlinGame.tscn
python tools/cli.py godot export web            # Export preset "web"
python tools/cli.py godot list_presets          # Lister les presets disponibles
python tools/cli.py godot telemetry             # Aggreger les stats gameplay JSON

# PowerBI — Local XMLA (PBI Desktop — pythonnet/ADOMD.NET/TOM)
python tools/cli.py powerbi connect-local                     # Detect PBI Desktop port
python tools/cli.py powerbi validate-model                    # Full model validation
python tools/cli.py powerbi list-tables-local                 # Tables + row counts
python tools/cli.py powerbi row-count --table "MyTable"       # Single table row count
python tools/cli.py powerbi query-local --dax "EVALUATE {1}"  # Execute DAX locally
python tools/cli.py powerbi refresh-local --table "MyTable"   # Refresh table (or all)
python tools/cli.py powerbi export-table --table T --format csv --out ~/Downloads/t.csv
python tools/cli.py powerbi model-info                        # Model metadata
python tools/cli.py powerbi create-table --name T --columns '[{"name":"id","type":"int64"}]'
python tools/cli.py powerbi delete-table --table "OldTable"   # rename-table, list-columns
python tools/cli.py powerbi add-column --table T --name Col --expr "DAX" --type String
python tools/cli.py powerbi remove-column --table T --column Col
python tools/cli.py powerbi list-measures                     # set-measure, delete-measure
python tools/cli.py powerbi list-relationships                # create-relationship, delete-relationship
python tools/cli.py powerbi list-partitions --table T         # create-partition, delete-partition
python tools/cli.py powerbi get-m-expression --table T        # set-m-expression
python tools/cli.py powerbi list-hierarchies                  # list-roles, create-role
python tools/cli.py powerbi list-data-sources                 # list-expressions, set-property, list-kpis
# PowerBI — REST API (Power BI Service)
python tools/cli.py powerbi workspaces                        # list-workspaces
python tools/cli.py powerbi list-reports --workspace <id>     # list-datasets
python tools/cli.py powerbi refresh --dataset <id>            # refresh-status
python tools/cli.py powerbi query --dax "EVALUATE {1}" --dataset <id>
python tools/cli.py powerbi export --report <id> --format PDF
python tools/cli.py powerbi list-dashboards --workspace <id>  # list-tiles, list-pages
python tools/cli.py powerbi clone-report --report <id> --name "Clone"
python tools/cli.py powerbi rebind-report --report <id> --dataset <target_id>
python tools/cli.py powerbi take-ownership --dataset <id>     # list-datasources, list-gateways
python tools/cli.py powerbi dataset-params --dataset <id>     # update-params
python tools/cli.py powerbi list-capacities                   # list-apps, get-dataset-info
# PowerBI — Offline (pbi-tools)
python tools/cli.py powerbi open --pbix <path>                # Inspecter .pbix offline
python tools/cli.py powerbi extract --pbix <p>                # Extraire TMDL (pbi-tools)

# Outlook (win32com COM — Outlook desktop must be running)
python tools/cli.py outlook inbox --limit 10
python tools/cli.py outlook sent --limit 10
python tools/cli.py outlook search --query "rapport" --from_addr "x@orange.com" --since "2026-03-01"
python tools/cli.py outlook read --index 0
python tools/cli.py outlook send --to "x@y.com" --subject "S" --body "B"
python tools/cli.py outlook reply --index 0 --body "Merci"
python tools/cli.py outlook forward --index 0 --to "x@y.com" --body "FYI"
python tools/cli.py outlook calendar-today
python tools/cli.py outlook calendar-week
python tools/cli.py outlook calendar-search --query "comite"
python tools/cli.py outlook contacts-search --query "dupont"
python tools/cli.py outlook folders

# Teams (Power Automate exports + LevelDB cache fallback)
python tools/cli.py teams status                          # Data sources status
python tools/cli.py teams recent-chats --limit 10
python tools/cli.py teams search-chats --query "dataset"
python tools/cli.py teams recent-channels --limit 10
python tools/cli.py teams cache-scan --limit 20           # Best-effort LevelDB scan

# CR Reunion (VTT Teams → CR Orange — Gemma 4 local)
python tools/cli.py cr status                              # Check Ollama/Gemma availability
python tools/cli.py cr generate --input ~/Downloads/t.vtt  # Full pipeline: MD + PPT + Outlook
python tools/cli.py cr parse --input ~/Downloads/t.vtt     # Parse VTT only (no LLM)
python tools/cli.py cr json --input ~/Downloads/t.vtt      # CR as JSON
python tools/cli.py cr watch                               # Auto-trigger on .vtt in Downloads

# DBeaver / EDH Hive
python tools/cli.py dbeaver list-connections
python tools/cli.py dbeaver list-tables --connection EDH_PRODv2 --database prod_app_bcv_vm_v
python tools/cli.py dbeaver describe --connection EDH_PRODv2 --table schema.table_name
python tools/cli.py dbeaver query --connection EDH_PRODv2 --sql "SELECT col FROM schema.t LIMIT 10"
python tools/cli.py dbeaver profile --connection EDH_PRODv2 --table schema.table_name

# BigQuery
python tools/cli.py bigquery list-datasets --project ofr-ppx-propme-1-prd
python tools/cli.py bigquery list-tables --project ofr-ppx-propme-1-prd --dataset my_dataset
python tools/cli.py bigquery describe --project ofr-ppx-propme-1-prd --dataset ds --table t
python tools/cli.py bigquery query --sql "SELECT * FROM \`proj.ds.table\` LIMIT 10"
python tools/cli.py bigquery dry-run --sql "SELECT * FROM \`proj.ds.table\`"

# Ollama / LLM local
python tools/cli.py ollama list                 # Modeles installes (qwen3.5:2b, merlin-narrator, ...)
python tools/cli.py ollama ps                   # Modeles en cours d'execution
python tools/cli.py ollama generate --model qwen2.5:7b --prompt "Hello"
python tools/cli.py ollama chat --model qwen2.5:7b --prompt "Bonjour !"
python tools/cli.py ollama pull --model qwen2.5:7b
python tools/cli.py ollama show --model merlin-narrator-lora:latest

# Git / GitHub
python tools/cli.py git status
python tools/cli.py git diff
python tools/cli.py git log
python tools/cli.py git commit --message "feat: ..." --files tools/cli.py
python tools/cli.py git push
python tools/cli.py git pr-list
python tools/cli.py git pr-create --title "Mon PR" --body "Description"

# Office (PowerPoint / Teams)
python tools/cli.py office ppt-open --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office ppt-info --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office ppt-export-pdf --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office teams-status
python tools/cli.py office teams-chat --to "colleague@orange.com"

# OneNote (dedicated CLI — full COM headless)
python tools/cli.py onenote notebooks                                          # List open notebooks
python tools/cli.py onenote sections --notebook "My Notebook"                  # List sections
python tools/cli.py onenote section-groups --notebook "My Notebook"            # List section groups
python tools/cli.py onenote pages --section "Project Notes"                    # List pages in section
python tools/cli.py onenote tree --notebook "My Notebook" --depth 3            # Full hierarchy tree
python tools/cli.py onenote read --title "Meeting Notes"                       # Read page as text
python tools/cli.py onenote read-xml --page_id "{...guid...}"                  # Read raw XML
python tools/cli.py onenote create --section "Notes" --title "New" --body_html "<p>Hello</p>"
python tools/cli.py onenote append --title "Meeting Notes" --body_html "<p>Action item</p>"
python tools/cli.py onenote update --page_id "{...}" --page_xml "<one:Page>..."
python tools/cli.py onenote delete --title "Old Page"                          # Delete page
python tools/cli.py onenote create-section --notebook "My NB" --name "New Sec" # Create section
python tools/cli.py onenote delete-section --section "Old Section"             # Delete section
python tools/cli.py onenote rename-section --section "Old" --new_name "New"    # Rename section
python tools/cli.py onenote search --query "action items" --notebook "Work"    # Full-text search
python tools/cli.py onenote recent --limit 10                                  # Recent pages
python tools/cli.py onenote export --id "{...}" --format pdf --output ~/Downloads/p.pdf
python tools/cli.py onenote navigate --title "Meeting Notes"                   # Open in OneNote UI
python tools/cli.py onenote get-link --title "Meeting Notes"                   # Get onenote:// link
python tools/cli.py onenote sync --notebook "My Notebook"                      # Force sync
python tools/cli.py onenote special-locations                                  # Backup/unfiled/default paths
python tools/cli.py onenote open-notebook --path "C:/path/to/notebook.one"     # Open notebook
python tools/cli.py onenote close-notebook --notebook "Old Notebook"           # Close notebook
python tools/cli.py onenote page-info --title "Meeting Notes"                  # Page metadata
# Move & Copy
python tools/cli.py onenote move-page --title "Old Note" --target_section "Archive"
python tools/cli.py onenote copy-page --title "Template" --target_section "Projects"
python tools/cli.py onenote move-section --section "Done" --target_notebook "Archive NB"
python tools/cli.py onenote merge-sections --source "Draft" --target "Final"
python tools/cli.py onenote set-page-level --title "Sub Page" --level 2          # Indent 1-3
python tools/cli.py onenote reorder-pages --title "Important" --position 0       # Move to top
# Extraction
python tools/cli.py onenote extract-tags --section "BACKLOG" --tag_type pending  # all/completed/pending
python tools/cli.py onenote extract-tables --title "Meeting Notes"               # Tables as JSON
python tools/cli.py onenote extract-links --title "Resources"                    # All hyperlinks
python tools/cli.py onenote extract-text --section "COURS" --output ~/Downloads/cours.txt
# Bulk Operations
python tools/cli.py onenote bulk-move --query "draft" --target_section "Archive"
python tools/cli.py onenote bulk-delete --query "temp" --dry_run true            # Preview first
python tools/cli.py onenote bulk-export --section "COURS" --format pdf --output_dir ~/Downloads/export
# Stats & Analysis
python tools/cli.py onenote section-stats --section "ORANGE"                     # Words, chars, dates
python tools/cli.py onenote notebook-stats                                       # All notebooks overview
python tools/cli.py onenote duplicate-finder                                     # Find duplicate titles
# OneNote Auto-Sync (skill /onenote-sync)
# /onenote-sync              — Synchronise notes avec etat reel des travaux
# /onenote-sync review       — Audit sante notebook (pages vides, doublons, perimees)
# Mode auto: Claude ajoute des entrees dans PROJETS ACTIFS en fin de session MODERATE+

# Browser (Playwright / Edge)
python tools/cli.py browser status              # Verifier Playwright installe
python tools/cli.py browser search --query "Claude Code documentation"
python tools/cli.py browser open --query "https://example.com"
python tools/cli.py browser screenshot --query "https://example.com" --out "screen.png"
python tools/cli.py browser scrape --query "https://example.com"
python tools/cli.py browser pdf --query "https://example.com" --out "page.pdf"

# N8N (workflow automation)
python tools/cli.py n8n list-workflows
python tools/cli.py n8n get-workflow --id 123
python tools/cli.py n8n execute-workflow --id 123
python tools/cli.py n8n list-executions --workflow_id 123 --limit 10

# Mermaid (diagrammes — mono-engine v3.0)
python tools/cli.py mermaid render-themed --input "flowchart LR; A-->B" --open
python tools/cli.py mermaid render --input "..." --theme orange --output ~/Downloads/d.png --open
python tools/cli.py mermaid from-file --input ~/Downloads/schema.mmd --open
python tools/cli.py mermaid validate --input "flowchart LR; A-->B"
python tools/cli.py mermaid list-themes
python tools/cli.py mermaid create-theme --name custom --primary_color "#336699"
python tools/cli.py mermaid open --path ~/Downloads/diagram.png

# Context7 (documentation)
python tools/cli.py context7 resolve-library --query lodash
python tools/cli.py context7 query-docs --library_id ID --query "debounce"

# Nano-Banana (image generation via Gemini)
python tools/cli.py nano-banana generate-image --prompt "description"
python tools/cli.py nano-banana edit-image --image path --prompt "edit"

# PageIndex (documents PDF)
python tools/cli.py pageindex recent-documents
python tools/cli.py pageindex find-relevant --query "search terms"
python tools/cli.py pageindex get-page-content --document_id ID --page_range "1-5"

# Magic (21st.dev components)
python tools/cli.py magic component-builder --query "description"
python tools/cli.py magic logo-search --query "react"

# Figma (design handoff)
python tools/cli.py figma me                                    # Validate token
python tools/cli.py figma get-file --file_key KEY               # File structure
python tools/cli.py figma get-images --file_key K --node_ids N  # Export PNG/SVG
python tools/cli.py figma export-tokens --file_key KEY          # Design tokens

# DataGouv (donnees ouvertes France)
python tools/cli.py datagouv search-datasets --query "population"
python tools/cli.py datagouv get-dataset --dataset_id ID
python tools/cli.py datagouv download --resource_id ID --output ~/Downloads/data.csv

# Stitch / Trellis (MCP bridges)
python tools/cli.py stitch list-tools
python tools/cli.py trellis list-tools

# Help
python tools/cli.py <tool>                      # Liste actions (godot/powerbi/outlook/dbeaver/...)
```

---

## Architecture

### Game Layer (scripts/game/)
```
merlin_game.gd        <- Scène de jeu : UI plateau, boucle beats, combo, résolution (~1150 l)
merlin_run.gd         <- État de run : deck, main, jauges, save/resume (R108)
merlin_menu.gd        <- Menu principal animé (wordmark, thème MusicGen)
merlin_fx.gd          <- Cinématique de fusion 4 phases + sustain skippable + helpers juice
merlin_wait_stage.gd  <- Attente animée générique (caption + glow + skip + cap)
merlin_visual.gd      <- SOURCE DE VÉRITÉ visuelle : palette canonique + FS_* + factories
merlin_card_view.gd   <- Vue de carte (rareté=bordure, archétype=bande, glyphe par tag)
merlin_beat_map.gd    <- Panneau CHEMIN (fil des beats, déviations de draft)
merlin_scene_art.gd   <- Décor vivant (silhouettes, brume, lune)
merlin_transition.gd  <- Fondus inter-scènes
```

### LLM Layer (scripts/llm/ + addons/merlin_llm/)
```
merlin_scenario.gd       <- Squelette + lookahead + priorité moteur (R110), single-flight
merlin_prose.gd          <- Prompts statiques purs (octet-identiques)
merlin_prompt_builder.gd <- Construction des prompts (zéro lecture d'autoload)
addons/merlin_llm/       <- GDExtension native Gemma 4 E2B (GGUF, GBNF, streaming)
```
(`addons/merlin_ai/` = couche héritée multi-backend — non utilisée par le flow canon.)

### Visual System
- **RULE**: TOUTES les couleurs viennent de `MerlinVisual` (alias `const COL_X: Color = MerlinVisual.X`)
- **RULE**: ZÉRO hex en dur hors `merlin_visual.gd` (BIBLE §20) — rebranding = 1 édition
- **RULE**: `var c: Color = MerlinVisual.GOLD` (type explicite, JAMAIS `:=` avec CONST[index])

### Harnais de preuve (R109)
```
tools/probe_soak.gd    <- Monte Carlo N runs logiques (5 archétypes, invariants, save/resume)
tools/autoplay_run.gd  <- Runs UI complets LLM ON (intro → beats → draft → MerlinEnd)
```

### Key Documents
- `docs/BIBLE.md` — **CANON UNIQUE v2.0** (R1-R119 ; §19 roadmap ; §20-§24 DA/Juice/Audio/Lisibilité/Pipeline)
- `docs/archive/` — bibles et plans legacy (NON-AUTORITAIRES)
- `.claude/agents/AGENTS.md` — Agent roster (⚠ beaucoup d'agents décrivent encore l'ancien jeu —
  vérifier contre BIBLE.md ; `python tools/create_agent.py --validate` liste les agents périmés)
- `.claude/skills/merlin-juice|merlin-audio|merlin-artwork/` — outillage studio (BIBLE §24)

---

## Code Style

### GDScript
- `snake_case` vars/funcs, `PascalCase` classes, `_` prefix private
- Type hints: `var x: int = 0`
- **JAMAIS** `:=` avec `CONST[index]` (type explicite)
- **JAMAIS** `yield()` (utiliser `await`)
- **JAMAIS** `//` pour division entiere (utiliser `int(x/y)`)

### TypeScript (Server)
- `camelCase` vars/funcs, `PascalCase` classes/interfaces, strong typing

---

## Game Design (Quick Ref) — BIBLE v2.0

> **Source de verite** : `docs/BIBLE.md` v2.0 (lire en début de session — règle 10.1)

### Core Loop
```
Menu → 3 titres+pitch générés → « Merlin écrit » (squelette) → beats : situation (LLM) →
main ~5 → combo (1 principale + 1-2 mods) → Résoudre → fusion animée → degré (sceau R112) →
deltas jauges → beat suivant (lookahead) → climax → fin (multiple) → MerlinEnd
```

### Systemes actifs (canon)
- **Intégrité** : 0-10 ; échec -2/-3, partiel -1, éclatante +0/+1 ; mort narrative jugée par Gemma (R65)
- **Corruption** : coût 0-3 par carte risquée ; seuil /5 → événement + carte corrompue ;
  plafond ~15-20 = fin corrompu ; **glitch visuel par palier** (R75 : sain/trouble/emprise/dissolution)
- **Résolution** : ternaire+ (échec/partiel/réussite/éclatante) — tags requis couverts = degré,
  le code applique, Gemma colore (R20/R105) ; combos bénis nommés, paires antagonistes (R41/R79)
- **Deck** : 12 cartes canon au départ (4 approches : Perception/Corps/Parole/Intuition, R21/R33) ;
  main 5, défausse-repioche ; invariant main jouable ≥2 (R113)
- **Quêtes** : v10.14+ run = chaîne 2-3 quêtes de 2-5 beats, dé PRÉ-TIRÉ par rareté, ramification
- **Méta cross-run** : fragments du Graal (~20-30), codex, PNJ à mémoire, réputation 3 états (post-MVP)
- **4 piliers PNJ** : Chœur des Druides · L'Être Indéfinissable · Le Compagnon Perdu · L'Enfant (R36-R40)
- **Save** : reprise TOUJOURS au début de beat (R108) ; transients jamais persistés

### Scene Flow (6 scènes)
```
MerlinMenu -> MerlinSelection (3 parchemins) -> MerlinGame (boucle beats) -> MerlinEnd
           (+ MerlinOptions ; GemmaConsole = REPL debug LLM)
```

---

## AUTODEV (mot-cle `autodev:`)

Workers = subagents Claude Code (Task tool) en parallele.
Sidebar VS Code: `tools/autodev/vscode-monitor-v4/`
Status protocol: `status/session.json`, `status/worker_{name}.json`

---

*Updated: 2026-06-12 — CLAUDE.md v4.0 (R114 : canon unique BIBLE.md v2.0, 6 scènes, Gemma 4 natif, soak R109, 4 skills studio, legacy archivé)*
