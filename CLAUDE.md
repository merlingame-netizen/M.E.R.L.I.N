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
