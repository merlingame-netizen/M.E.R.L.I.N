# M.E.R.L.I.N. Agent Team — Multi-Agent Architecture

## Overview

This document defines the team of specialized Claude Code agents for the M.E.R.L.I.N. project.
**34 agents + 1 knowledge base** organized by domain.

## Usage with Claude Code

**STEP 0 — TOUJOURS invoquer le Task Dispatcher EN PREMIER:**

```
Task tool:
- subagent_type: "general-purpose"
- model: "haiku"
- prompt: Read .claude/agents/task_dispatcher.md and analyze this task: [DESCRIPTION]
```

Le dispatcher retourne la sequence exacte d'agents a invoquer. Suivre le plan.

**Pour invoquer un agent individuel:**

```
Task tool:
- subagent_type: "general-purpose"
- prompt: Read .claude/agents/[agent].md and follow its instructions. Task: [your task]
```

---

## Agent Roster

### Direction (NEW)

| Role | File | Specialty |
|------|------|-----------|
| **Game Director** | `game_director.md` | **Vision du createur, decisions directionnelles, coherence globale, arbitrage inter-agents, test emotionnel** |

> Le Game Director est l'incarnation de la vision du createur humain. Il repond aux autres
> agents sur la direction creative et gameplay. Decide seul sur les piliers VARIABLES (80%),
> escalade au PDG humain sur les piliers IMMUABLES (20%). Toute decision inclut un "test emotionnel".

### Orchestration

| Role | File | Specialty |
|------|------|-----------|
| **Task Dispatcher** | `task_dispatcher.md` | **Classification de tache, dispatch automatique, sequence d'agents** |

> Le dispatcher est le point d'entree OBLIGATOIRE. Il classifie la tache,
> mappe vers les agents requis, determine l'ordre d'execution, et ajoute
> les agents auto-actives (debug_qa, optimizer, git_commit).

### Core Technical Agents (6)

| Role | File | Specialty |
|------|------|-----------|
| Lead Godot | `lead_godot.md` | Architecture, conventions, code review |
| **Godot Expert** | `godot_expert.md` | **Performance, GDExtension, memory optimization** |
| **LLM Expert** | `llm_expert.md` | **Prompt engineering, RAG, guardrails, Multi-Brain, GBNF** |
| Debug/QA | `debug_qa.md` | Testing, bug reproduction, fixes, **GUT framework, lessons learned** |
| **Optimizer** | `optimizer.md` | **GDScript best practices, code scanning, optimization** |
| **Shader Specialist** | `shader_specialist.md` | **GLSL, post-processing, VFX shaders** |

### UI/UX & Animation Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| UI Implementation | `ui_impl.md` | Control layouts, themes, shaders |
| UX Research | `ux_research.md` | Usability, **WCAG 2.1, playtesting, journey mapping** |
| **Motion Designer** | `motion_designer.md` | **Tweens, particles, easing, micro-interactions** |
| **Mobile/Touch Expert** | `mobile_touch_expert.md` | **Touch gestures, haptic feedback, device quirks, battery** |

### Content & Creative Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| Game Designer | `game_designer.md` | Rules, **data-driven balancing, economy, synergies** |
| Narrative Writer | `narrative_writer.md` | Card text, **QA narrative, prompt writing, Triade templates** |
| Art Direction | `art_direction.md` | **Pixel art pipeline, shaders, procedural landscapes** |
| Audio Designer | `audio_designer.md` | **SFXManager procedural, adaptive music, accessibility** |

### Lore & World-Building Agents (3)

| Role | File | Specialty |
|------|------|-----------|
| **Merlin Guardian** | `merlin_guardian.md` | **Merlin's personality, voice, behavioral consistency** |
| **Lore Writer** | `lore_writer.md` | **Deep mythology, hidden narratives, apocalyptic truth** |
| **Historien Bretagne** | `historien_bretagne.md` | **Celtic/Breton history, mythology research, authenticity** |

### Operations & Documentation Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| Producer | `producer.md` | Priorities, **release management, risk register, retrospectives** |
| Localisation | `localisation.md` | Multi-language, translation |
| **Technical Writer** | `technical_writer.md` | **Docstrings, API docs, player docs, tutorials, onboarding** |
| **Data Analyst** | `data_analyst.md` | **RGPD, visualization, cohort analysis, predictive analytics** |

### Project Management Agents (2)

| Role | File | Specialty |
|------|------|-----------|
| **Git Commit** | `git_commit.md` | **Conventional commits, branch strategy, changelog, tags** |
| **Project Curator** | `project_curator.md` | **Inventory, cleanup, orphan detection, .gitignore** |

### Security & Quality Agents (3) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Accessibility Specialist** | `accessibility_specialist.md` | **WCAG 2.1 AA/AAA, CVD modes, keyboard nav, screen readers** |
| **Security Hardening** | `security_hardening.md` | **Save encryption, LLM sanitization, RGPD, anti-tampering** |
| **Prompt Curator** | `prompt_curator.md` | **Golden dataset, anti-hallucination Celtic, prompt versioning** |

### Progression & Economy Agents (1) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Meta-Progression Designer** | `meta_progression_designer.md` | **Talent Tree, Essences economy, Bestiole, unlock pacing, synergies** |

### CI/CD & Release Agents (1) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **CI/CD Release** | `ci_cd_release.md` | **GitHub Actions, multi-platform export, Steam, mobile stores** |

### LLM Bi-Brain Agents (3) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Bi-Brain Orchestrator** | `bi_brain_orchestrator.md` | **Pipeline sequentiel GM→Narrator, visual/audio tags, prefetch, dialogue Merlin** |
| **Narrative Arc Designer** | `narrative_arc_designer.md` | **Arcs multi-cartes, state machine SETUP→CLIMAX→RESOLUTION, callbacks, reves** |
| **Player Profiler** | `player_profiler.md` | **Profil psychologique, adaptation ton, detection danger, difficulte narrative** |

> Ces 3 agents implementent l'architecture "LLM = peau expressive, Code = cerveau logique".
> Le **Bi-Brain Orchestrator** gere le pipeline technique, l'**Arc Designer** la coherence narrative,
> le **Player Profiler** l'adaptation au joueur. Ref: `docs/VISION_LLM_BI_CERVEAUX.html`

### LoRA Fine-Tuning Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| **LoRA Gameplay Translator** | `lora_gameplay_translator.md` | **Point d'entree: traduit demande gameplay → plan d'entrainement LoRA** |
| **LoRA Data Curator** | `lora_data_curator.md` | **Extraction, curation, augmentation datasets (5 competences, ~1000 exemples)** |
| **LoRA Training Architect** | `lora_training_architect.md` | **QLoRA r=16, Qwen 2.5-1.5B, architecture adapter, pilotage training** |
| **LoRA Evaluator** | `lora_evaluator.md` | **Benchmark Celtic/format/diversity, GO/NO-GO, A/B testing in-game** |

> Pipeline de fine-tuning. Le **Gameplay Translator** est le point d'entree auto-active
> quand l'utilisateur demande une adaptation du LLM. Ref: `docs/LORA_TRAINING_SPEC.html`

### Shared Resources

| Resource | File | Purpose |
|----------|------|---------|
| **Knowledge Base** | `gdscript_knowledge_base.md` | **Corrections, best practices, lessons learned** |

---

## Summary Count

```
Total: 37 agents + 1 knowledge base

By category:
  Direction:                  1 (game_director)
  Orchestration:              1 (task_dispatcher)
  Core Technical:             6 (lead_godot, godot_expert, llm_expert, debug_qa, optimizer, shader_specialist)
  UI/UX & Animation:          4 (ui_impl, ux_research, motion_designer, mobile_touch_expert)
  Content & Creative:         4 (game_designer, narrative_writer, art_direction, audio_designer)
  Lore & World-Building:      3 (merlin_guardian, lore_writer, historien_bretagne)
  Operations & Documentation: 4 (producer, localisation, technical_writer, data_analyst)
  Project Management:         2 (git_commit, project_curator)
  Security & Quality:         3 (accessibility_specialist, security_hardening, prompt_curator)
  Progression & Economy:      1 (meta_progression_designer)
  CI/CD & Release:            1 (ci_cd_release)
  LLM Bi-Brain:               3 (bi_brain_orchestrator, narrative_arc_designer, player_profiler)
  LoRA Fine-Tuning:           4 (lora_gameplay_translator, lora_data_curator, lora_training_architect, lora_evaluator)
  Knowledge Base:             1 (gdscript_knowledge_base)
```

---

## Workflow — DISPATCH FIRST

### Flux Standard (avec Dispatcher)

```
1. DISPATCHER analyse la tache → retourne plan d'agents
2. Suivre le plan: agents de planning EN PREMIER
3. Agents d'implementation AU MILIEU
4. Agents de validation (debug_qa, optimizer) APRES
5. git_commit EN DERNIER
```

### Invocation du Dispatcher

```
Task tool:
  subagent_type: "general-purpose"
  model: "haiku"
  prompt: "Read .claude/agents/task_dispatcher.md and analyze this task: [DESCRIPTION]"
```

Le dispatcher retourne un plan structure avec:
- Types de tache identifies (multi-label)
- Agents requis avec ordre d'execution
- Hints de parallelisation
- Agents auto-actives appliques
- Fichiers impactes estimes

---

## Cross-Functional Reviews

| Change Type | Required Review |
|-------------|-----------------|
| GDScript code | Lead Godot, Debug/QA, **Optimizer** |
| Performance issues | **Godot Expert**, **Optimizer** |
| LLM integration | **LLM Expert**, Godot Expert |
| UI/UX changes | UI Impl, UX Research |
| Card content | Narrative, Game Designer, **Merlin Guardian** |
| Visual assets | Art Direction |
| Audio changes | Audio Designer |
| Doc changes | Producer, **Technical Writer** |
| **Shader/VFX code** | **Shader Specialist**, Godot Expert |
| **Animations/Tweens** | **Motion Designer**, UI Impl |
| **Touch/Mobile input** | **Mobile/Touch Expert**, UX Research |
| **Game balance data** | **Data Analyst**, Game Designer |
| **Lore/Mythology** | **Merlin Guardian**, **Lore Writer** |
| **Creative direction** | **Game Director** |
| **Correction learned** | **Debug/QA**, **Optimizer** |
| **Best practice found** | **Optimizer**, Debug/QA |
| **Phase completed** | **Git Commit** |
| **Project cleanup** | **Project Curator** |
| **Accessibility** | **Accessibility Specialist**, UX Research |
| **Security/Privacy** | **Security Hardening**, Data Analyst |
| **LLM content quality** | **Prompt Curator**, LLM Expert |
| **Meta-progression** | **Meta-Progression Designer**, Game Designer |
| **Build/Release** | **CI/CD Release**, Producer |
| **LLM adaptation/fine-tuning** | **LoRA Gameplay Translator**, LLM Expert |
| **Training data changes** | **LoRA Data Curator**, Prompt Curator |
| **LoRA training/hyperparams** | **LoRA Training Architect**, LLM Expert |
| **Model benchmark/evaluation** | **LoRA Evaluator**, LLM Expert |

---

## Agent Communication Protocol

### Handoff Format

When an agent completes work and needs handoff:

```markdown
## Agent Handoff: [Agent Role]

### Completed
- [List of completed items]

### Files Modified
- `path/to/file.gd` — Description

### For Next Agent: [Target Role]
- [Specific tasks or questions]

### Blockers
- [Any blockers or dependencies]
```

### Status Tags

- `[READY]` — Task complete, ready for review
- `[BLOCKED]` — Waiting on dependency
- `[WIP]` — Work in progress
- `[REVIEW]` — Needs review from specific agent

---

## Auto-Activation Matrix

| Agent | Declencheur | Action |
|-------|------------|--------|
| **task_dispatcher.md** | Toute tache non-triviale | Classifie et dispatch — INVOQUE EN PREMIER |
| `debug_qa.md` | Correction GDScript apprise | Documente dans gdscript_knowledge_base.md |
| `optimizer.md` | Bonne pratique decouverte ou nouveau code GDScript | Scanner et appliquer |
| `git_commit.md` | Phase complete, 3+ fichiers modifies | Commit conventionnel auto |
| `project_curator.md` | "inventaire", "nettoie", "range" | Rapport + nettoyage |
| **`game_director.md`** | **"vision du jeu", "direction creative", "le joueur doit ressentir", "coherence narrative", conflit inter-agents, ambiguite de direction** | **Evalue contre la vision du createur, decide ou escalade au PDG** |
| **`lora_gameplay_translator.md`** | **"entraine le modele", "le LLM doit", "adapte le modele", "fine-tune", adaptation gameplay LLM** | **Traduit demande → plan d'entrainement, orchestre pipeline LoRA** |
| `lora_data_curator.md` | Modification JSON contenu narratif, ajout nouveau gameplay | Re-export + augmentation dataset |
| `lora_evaluator.md` | Apres training LoRA complet | Benchmark automatique, decision GO/NO-GO |

---

## Quick Reference Commands

```bash
# NEW — Invoke Game Director for creative direction
claude "Use Task to read .claude/agents/game_director.md and evaluate: est-ce coherent avec la vision du jeu de [feature proposee]?"

# STEP 0 — DISPATCH (TOUJOURS EN PREMIER)
claude "Use Task with general-purpose agent (haiku) to read .claude/agents/task_dispatcher.md and analyze: [TASK]"

# Invoke Lead Godot for architecture review
claude "Use Task to read .claude/agents/lead_godot.md and review the merlin_store.gd architecture"

# Invoke QA for testing
claude "Use Task to read .claude/agents/debug_qa.md and test the TriadeGame scene"

# Invoke Narrative Writer for card content
claude "Use Task to read .claude/agents/narrative_writer.md and write 10 new fallback cards"

# Invoke Motion Designer for animation polish
claude "Use Task to read .claude/agents/motion_designer.md and add entry animations to the menu"

# Invoke Shader Specialist for visual effects
claude "Use Task to read .claude/agents/shader_specialist.md and create a CRT scanline effect"

# Invoke Mobile Expert for touch optimization
claude "Use Task to read .claude/agents/mobile_touch_expert.md and improve card swipe gesture"

# Invoke Data Analyst for balance review
claude "Use Task to read .claude/agents/data_analyst.md and analyze aspect ending distribution"

# Invoke Technical Writer for documentation
claude "Use Task to read .claude/agents/technical_writer.md and document the MerlinStore API"

# Invoke Optimizer for best practices scan
claude "Use Task to read .claude/agents/optimizer.md and scan scripts/merlin/ for optimization"

# Invoke Debug with knowledge base update
claude "Use Task to read .claude/agents/debug_qa.md and document the correction in gdscript_knowledge_base.md"

# NEW — Invoke Accessibility Specialist
claude "Use Task to read .claude/agents/accessibility_specialist.md and audit the TriadeGame UI"

# NEW — Invoke Security Hardening
claude "Use Task to read .claude/agents/security_hardening.md and review save system encryption"

# NEW — Invoke Prompt Curator
claude "Use Task to read .claude/agents/prompt_curator.md and evaluate golden dataset coverage"

# NEW — Invoke Meta-Progression Designer
claude "Use Task to read .claude/agents/meta_progression_designer.md and balance Talent Tree costs"

# NEW — Invoke CI/CD Release
claude "Use Task to read .claude/agents/ci_cd_release.md and setup GitHub Actions pipeline"

# NEW — LoRA Fine-Tuning Pipeline
# Point d'entree: Gameplay Translator (auto-active par "le LLM doit", "entraine le modele")
claude "Use Task to read .claude/agents/lora_gameplay_translator.md and translate this need: le modele doit etre plus poetique dans les biomes forestiers"

# LoRA Data Curator (auto-active par modification contenu JSON)
claude "Use Task to read .claude/agents/lora_data_curator.md and re-export training data after content update"

# LoRA Training Architect
claude "Use Task to read .claude/agents/lora_training_architect.md and configure training for multi-LoRA per tone"

# LoRA Evaluator (auto-active apres training)
claude "Use Task to read .claude/agents/lora_evaluator.md and benchmark the new narrator adapter"
```

---

*Created: 2026-02-06*
*Updated: 2026-02-22 — 34 agents + 1 knowledge base (new: game_director — creative vision oracle)*
*Project: M.E.R.L.I.N. — Le Jeu des Oghams*
