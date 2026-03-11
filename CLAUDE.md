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

---

## Commits

Format: `type(scope): description` — Conventional Commits
Types: feat, fix, refactor, docs, test, chore, perf
Ce projet est personnel — PAS de tag `[AI-assisted]`.

---

## Project Overview

Narrative card game built with Godot 4.x.
- **Core Loop**: 3 options/carte, balance 3 Aspects (Corps/Ame/Monde), survive
- **Game System**: Triade — 3 Aspects x 3 etats discrets, Souffle d'Ogham
- **LLM**: Multi-Brain heterogene (Qwen 3.5) via Ollama — voir `docs/LLM_ARCHITECTURE.md`
- **Audio**: SFXManager (30+ sons proceduraux)

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

# PowerBI
python tools/cli.py powerbi workspaces          # Lister workspaces
python tools/cli.py powerbi list-reports        # Lister rapports
python tools/cli.py powerbi list-datasets       # Lister datasets
python tools/cli.py powerbi refresh <id>        # Refresh dataset (poll status)
python tools/cli.py powerbi query --dax "EVALUATE {1}" --dataset <id>
python tools/cli.py powerbi export <report_id> --format PDF
python tools/cli.py powerbi open --pbix <path>  # Inspecter .pbix offline
python tools/cli.py powerbi extract --pbix <p>  # Extraire TMDL (pbi-tools)

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

# Help
python tools/cli.py <tool>                      # Liste actions (godot/powerbi/outlook/dbeaver/...)
```

---

## Architecture

### Core Systems (scripts/merlin/)
```
merlin_store.gd          <- Central state (Redux-like), Triade
merlin_card_system.gd    <- Card engine, fallback pool, TRIADE generation
merlin_effect_engine.gd  <- SHIFT_ASPECT, SOUFFLE, KARMA, PROMISE
merlin_llm_adapter.gd    <- LLM contract, format TRIADE, JSON repair
merlin_constants.gd      <- 18 Oghams, 12 endings, 3 victoires
merlin_save_system.gd    <- 3 slots JSON
```

### UI Layer (scripts/ui/)
```
triade_game_ui.gd           <- 3 aspects, 3 options, souffle, typewriter
triade_game_controller.gd   <- Store-UI bridge, run flow, LLM wiring
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
- `docs/MASTER_DOCUMENT.md` — Project overview
- `docs/LLM_ARCHITECTURE.md` — Multi-cerveaux, LoRA, prompts
- `docs/70_graphic/UI_UX_BIBLE.md` — Visual system specification
- `docs/20_card_system/DOC_12_Triade_Gameplay_System.md` — Triade system
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

## Game Design (Quick Ref)

### Triade — 3 Aspects x 3 etats
| Aspect | Animal | Bas | Equilibre | Haut |
|--------|--------|-----|-----------|------|
| Corps | Sanglier | Epuise | Robuste | Surmene |
| Ame | Corbeau | Perdue | Centree | Possedee |
| Monde | Cerf | Exile | Integre | Tyran |

- **Choix**: 3 options/carte (G/C/D), Centre payant (Souffle)
- **Souffle d'Ogham**: Max 7, depart 3, +1 si 3 equilibres
- **Fins**: 12 chutes + 3 victoires + 1 secrete
- **Cards**: Narrative 80%, Event 10%, Promise 5%, Merlin Direct 5%
- **Ref**: `docs/20_card_system/DOC_12_Triade_Gameplay_System.md`

### Scene Flow
```
IntroCeltOS -> Menu -> Quiz -> Rencontre -> Hub -> Transition -> MerlinGame -> [Fin] -> Hub
```

---

## AUTODEV (mot-cle `autodev:`)

Workers = subagents Claude Code (Task tool) en parallele.
Sidebar VS Code: `tools/autodev/vscode-monitor-v4/`
Status protocol: `status/session.json`, `status/worker_{name}.json`

---

*Updated: 2026-03-08 — CLAUDE.md v3.0 (lean core, LLM externalized to docs/LLM_ARCHITECTURE.md)*
