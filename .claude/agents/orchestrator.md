# Agent Orchestrator — M.E.R.L.I.N. Multi-Agent System

> **NOTE**: Ce fichier est le complement de `task_dispatcher.md`.
> Le dispatcher classifie et retourne le plan d'agents.
> L'orchestrateur decrit les workflows et la coordination entre agents.

---

## Quick Start

### Etape 1: Dispatcher (OBLIGATOIRE)

```
Task tool:
  subagent_type: "general-purpose"
  model: "haiku"
  prompt: "Read .claude/agents/task_dispatcher.md and analyze this task: [DESCRIPTION]"
```

### Etape 2: Suivre le Plan

Le dispatcher retourne un plan structure. Invoquer chaque agent dans l'ordre:

```
Task tool:
  subagent_type: "general-purpose"
  prompt: "Read .claude/agents/[agent].md and follow its role. Task: [DESCRIPTION]"
```

---

## Workflow Patterns

### Pattern 1: Feature Development

```
0. [Dispatcher] → Classifie, retourne plan d'agents
1. [Producer] Define task and priority
2. [Game Designer] Validate design intent
3. [Lead Godot] Plan architecture
4. [Implementation Agent(s)] Implement (parallel if independent)
5. [Debug/QA] Test implementation
6. [Optimizer] Scan best practices [AUTO]
7. [Lead Godot] Final review
8. [Git Commit] Commit [AUTO]
```

### Pattern 2: Content Creation

```
0. [Dispatcher] → Classifie, retourne plan d'agents
1. [Game Designer] Define card requirements + Triade balance
2. [Merlin Guardian] Review voice guidelines
3. [Narrative Writer] Write card text (parallel with Lore Writer if mythology)
4. [Game Designer] Validate card balance
5. [Debug/QA] Test cards in-game [AUTO]
6. [Git Commit] Commit [AUTO]
```

### Pattern 3: Bug Fix

```
0. [Dispatcher] → Classifie, retourne plan d'agents
1. [Debug/QA] Reproduce bug, document
2. [Lead Godot / Domain Agent] Identify root cause
3. [Appropriate Agent] Fix
4. [Debug/QA] Verify fix, update knowledge base [AUTO]
5. [Optimizer] Scan for related patterns [AUTO]
6. [Git Commit] Commit [AUTO]
```

### Pattern 4: UX Improvement

```
0. [Dispatcher] → Classifie, retourne plan d'agents
1. [UX Research] Identify issue, propose solution
2. [Game Designer] Validate design solution
3. [UI Impl] Implement (parallel with Motion Designer if animation)
4. [UX Research] Verify improvement
5. [Debug/QA] Regression test [AUTO]
6. [Git Commit] Commit [AUTO]
```

### Pattern 5: LLM Integration

```
0. [Dispatcher] → Classifie, retourne plan d'agents
1. [LLM Expert] Analyze prompt/parsing issue
2. [Lead Godot] Review architecture impact
3. [Godot Expert] Performance considerations
4. [Debug/QA] Test LLM integration [AUTO]
5. [Optimizer] Scan adapter code [AUTO]
6. [Technical Writer] Document prompt changes
7. [Git Commit] Commit [AUTO]
```

---

## Parallel Agent Execution

Quand les agents sont independants, les invoquer en parallele:

```
# Exemple: Design + Review en parallele
Task 1 (Game Designer): Define card requirements
Task 2 (Merlin Guardian): Review voice guidelines
→ Les deux peuvent tourner simultanement

# Exemple: Implementation parallele
Task 1 (UI Impl): Implement layout
Task 2 (Motion Designer): Implement animations
→ Independants, parallelisables
```

**ATTENTION**: Ne PAS paralleliser des agents dependants:
- Debug/QA APRES implementation (pas en parallele)
- Optimizer APRES code ecrit (pas en parallele)
- Git Commit TOUJOURS en dernier

---

## Handoff Protocol

Quand un agent termine et passe au suivant:

```markdown
## Handoff: [From Agent] -> [To Agent]

### Completed Work
- Description of what was done

### Files Changed
- `path/file.gd` — Changes made

### For [To Agent]
- Specific request or question

### Context
- Relevant state or decisions
```

---

## Project Context Summary

### Current State (2026-02)
- **Game System**: Triade — 3 Aspects x 3 etats discrets
- **LLM**: Qwen2.5-3B-Instruct Q4_K_M, Multi-Brain (1-4 cerveaux)
- **Core Loop**: 3 options par carte, equilibrer Corps/Ame/Monde
- **Companion**: Bestiole (18 Oghams)
- **Audio**: SFXManager (30+ sons proceduraux)

### Key Files
```
scripts/merlin/merlin_store.gd      <- Central state (Redux-like), Triade
scripts/merlin/merlin_card_system.gd <- Card engine, fallback pool
scripts/ui/triade_game_ui.gd        <- 3 aspects, 3 options, typewriter
scripts/ui/triade_game_controller.gd <- Store-UI bridge, LLM wiring
addons/merlin_ai/merlin_ai.gd       <- Multi-Brain, worker pool
addons/merlin_ai/merlin_omniscient.gd <- Orchestrateur IA, guardrails
docs/MASTER_DOCUMENT.md              <- Project overview (v4.0)
```

### Tech Stack
- Engine: Godot 4.x
- Language: GDScript
- State: Redux-like (MerlinStore)
- LLM: Qwen2.5-3B via llama.cpp (GDExtension)
- Agents: 24 + 1 knowledge base

---

## Best Practices

1. **Dispatcher first** — Toujours invoquer task_dispatcher.md avant d'agir
2. **One agent per role** — Ne pas melanger les responsabilites
3. **Clear handoffs** — Specifier le prochain agent
4. **Read role first** — L'agent lit son .md avant d'agir
5. **Test after changes** — Toujours impliquer debug_qa
6. **Auto-activate** — debug_qa, optimizer, git_commit se declenchent auto
7. **Knowledge base** — Documenter les corrections pour eviter les regressions

---

*Orchestrator version: 2.0*
*Updated: 2026-02-09 — Modernized for M.E.R.L.I.N. + Task Dispatcher integration*
