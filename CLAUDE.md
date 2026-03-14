# CLAUDE.md — M.E.R.L.I.N.: Le Jeu des Oghams

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

```powershell
.\validate.bat   # Step 0: Editor Parse Check (le plus fiable)
```

**Ordre**: Editer → validate.bat → corriger → re-valider → tester dans Godot

### 3. Post-Dev Checklist — FIN DE SESSION (OBLIGATOIRE)

```
1. VALIDATE  — .\validate.bat (Step 0 minimum)
2. FIX       — Corriger TOUTES erreurs + warnings
3. REVALIDATE — Confirmer 0 errors, 0 warnings
4. COMMIT    — git add + git commit (conventional commits)
5. PUSH      — git push origin main (ou rappeler si auth requise)
6. AGENTS    — Verifier que tous les agents/skills mandates ont ete invoques
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

---

## Commits

Format: `type(scope): description` — Conventional Commits
Types: feat, fix, refactor, docs, test, chore, perf
Ce projet est personnel — PAS de tag `[AI-assisted]`.

---

## Project Overview

Narrative card game built with Godot 4.x.
- **Core Loop**: Choix narratif → minigame (champ lexical) → effets proportionnels
- **Game System**: 5 Factions, 18 Oghams, 1 barre de vie, 8 champs lexicaux, MOS
- **LLM**: Multi-Brain heterogene (Qwen 3.5) via Ollama — voir `docs/LLM_ARCHITECTURE.md`
- **Audio**: SFXManager (30+ sons proceduraux)
- **Design Ref**: `docs/GAME_DESIGN_BIBLE.md` v2.1 (source de verite unique)

---

## Quick Commands

```bash
.\validate.bat                          # Validation complete
godot --path .                          # Run project
godot --path . scenes/MerlinGame.tscn   # Run scene
cd server && npm run build              # Build MCP server
/loop 5m <prompt>                       # Tache recurrente
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

# Outlook
python tools/cli.py outlook inbox --limit 10
python tools/cli.py outlook search --query "rapport"
python tools/cli.py outlook read --index 0
python tools/cli.py outlook send --to "x@y.com" --subject "S" --body "B"
python tools/cli.py outlook reply --index 0 --body "Merci"
python tools/cli.py outlook forward --index 0 --to "x@y.com" --body "FYI"

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

# Office (PowerPoint / OneNote / Teams)
python tools/cli.py office ppt-open --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office ppt-info --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office ppt-export-pdf --pbix "C:/path/to/rapport.pptx"
python tools/cli.py office onenote-notebooks
python tools/cli.py office onenote-sections --query "Mon Notebook"
python tools/cli.py office teams-status
python tools/cli.py office teams-chat --to "colleague@orange.com"

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

### Core Systems (scripts/merlin/)
```
merlin_store.gd              <- Central state (Redux-like), Factions
merlin_card_system.gd        <- Card engine, fallback pool, LLM generation
merlin_effect_engine.gd      <- ADD_REPUTATION, HEAL_LIFE, DAMAGE_LIFE, PROMISE
merlin_llm_adapter.gd        <- LLM contract, Faction-based, JSON repair
merlin_constants.gd          <- 18 Oghams, biomes, minigames, factions
merlin_reputation_system.gd  <- 5 factions, 0-100, thresholds 50/80
merlin_save_system.gd        <- 3 slots JSON
```

### UI Layer (scripts/ui/)
```
merlin_game_controller.gd   <- Store-UI bridge, run flow, LLM wiring
```

### Visual System
```
merlin_visual.gd            <- Centralized visual constants (PALETTE, GBC, fonts)
```
- **RULE**: ALL colors from `MerlinVisual.PALETTE` / `MerlinVisual.GBC`
- **RULE**: `var c: Color = MerlinVisual.PALETTE["x"]` (explicit type, NEVER `:=`)

### AI Layer (addons/merlin_ai/) — Details: `docs/LLM_ARCHITECTURE.md`
```
ollama_backend.gd        <- Ollama HTTP API
merlin_ai.gd             <- Multi-Brain (Qwen 3.5), time-sharing, routing
brain_swarm_config.gd    <- Hardware profiles NANO/SINGLE/DUAL/QUAD
merlin_omniscient.gd     <- Orchestrateur IA, guardrails
rag_manager.gd           <- RAG v3.0, per-brain context budget
```

### Key Documents
- `docs/GAME_DESIGN_BIBLE.md` — **Source de verite unique** pour le game design v2.1
- `docs/LLM_ARCHITECTURE.md` — Multi-cerveaux, LoRA, prompts
- `docs/70_graphic/UI_UX_BIBLE.md` — Visual system specification
- `docs/20_card_system/DOC_15_Faction_Alignment_System.md` — Detail factions
- `.claude/agents/AGENTS.md` — Agent roster

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

## Game Design (Quick Ref) — v2.3

> **Source de verite** : `docs/GAME_DESIGN_BIBLE.md` v2.3

### Core Loop
```
Hub 2D → Biome → Ogham → 3D rail (marche) → [5-15s collecte] → [fondu] → Carte 2D (3 options) → Minigame overlay → Effets (multiplicateur direct) → [fondu] → 3D → [repeter] → Fin → Hub
```

### Systemes actifs
- **Vie** : 1 barre unique (0-100), drain -1/carte
- **5 Factions** : Druides/Anciens/Korrigans/Niamh/Ankou (0-100, cross-run, PAS de decay)
- **18 Oghams** : 1 equipe + 1-2 trouves en run (temporaires + discount arbre). Switch possible, seul l'actif se recharge
- **3 options fixes** par carte. Minigames obligatoires (sauf Merlin Direct)
- **8 Champs lexicaux** : chance, bluff, observation, logique, finesse, vigueur, esprit, perception
- **Anam** : cross-run, progression lente (~10 runs/noeud). Mort = gains proportionnels aux cartes
- **8 Biomes** : deblocage organique (MOS score de maturite + carte-cle)
- **MOS** : orchestrateur LLM + directeur + guardrails + confiance T0-T3
- **Save** : Profil unique, auto-continue (Hades-style)
- **Fins** : ~10-15 cataloguees + LLM personnalise le texte
- **Run 3D** : on-rails permanent, cartes via fondu enchaine, minigames overlay 2D

### Systemes SUPPRIMES
~~Triade (Corps/Ame/Monde)~~, ~~Souffle d'Ogham~~, ~~4 Jauges~~, ~~Bestiole~~, ~~Awen~~, ~~D20~~, ~~Flux System~~, ~~Run Typologies~~

### Scene Flow
```
IntroCeltOS -> Menu -> Quiz -> Rencontre -> Hub 2D -> [Choix biome + Ogham] -> Run 3D (rail permanent: marche ↔ cartes ↔ minigames) -> [Fin] -> Hub 2D
```

---

## AUTODEV (mot-cle `autodev:`)

Workers = subagents Claude Code (Task tool) en parallele.
Sidebar VS Code: `tools/autodev/vscode-monitor-v4/`
Status protocol: `status/session.json`, `status/worker_{name}.json`

---

*Updated: 2026-03-14 — CLAUDE.md v3.2 (game design v2.3: run 3D on-rails, economie Anam, oghams mix, MOS organique)*
