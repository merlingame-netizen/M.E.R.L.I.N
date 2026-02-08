# DRU Agent Team — Multi-Agent Architecture

## Overview

This document defines the team of specialized Claude Code agents for the DRU project.
Each agent has a specific role, expertise, and responsibilities.

## Usage with Claude Code

To invoke a specialized agent, use the Task tool with the agent's prompt:

```
Task tool:
- subagent_type: "general-purpose"
- prompt: Read .claude/agents/[agent].md and follow its instructions. Task: [your task]
```

---

## Agent Roster

### Core Technical Agents

| Role | File | Specialty |
|------|------|-----------|
| Lead Godot | `lead_godot.md` | Architecture, conventions, code review |
| **Godot Expert** | `godot_expert.md` | **Performance, GDExtension, memory optimization** |
| **LLM Expert** | `llm_expert.md` | **Prompt engineering, latency, output parsing** |
| Debug/QA | `debug_qa.md` | Testing, bug reproduction, fixes, **lessons learned** |
| **Optimizer** | `optimizer.md` | **GDScript best practices, code scanning, optimization** |
| **Shader Specialist** | `shader_specialist.md` | **GLSL, post-processing, VFX shaders** |

### UI/UX & Animation Agents

| Role | File | Specialty |
|------|------|-----------|
| UI Implementation | `ui_impl.md` | Control layouts, themes, shaders |
| UX Research | `ux_research.md` | Usability, playtesting, iterations |
| **Motion Designer** | `motion_designer.md` | **Tweens, particles, easing, micro-interactions** |
| **Mobile/Touch Expert** | `mobile_touch_expert.md` | **Touch gestures, responsive UI, mobile perf** |

### Content & Creative Agents

| Role | File | Specialty |
|------|------|-----------|
| Game Designer | `game_designer.md` | Rules, balancing, progression |
| Narrative Writer | `narrative_writer.md` | Card text, tone, story coherence |
| Art Direction | `art_direction.md` | Visual style, assets, consistency |
| Audio Designer | `audio_designer.md` | SFX, music, ambiance |

### Lore & World-Building Agents

| Role | File | Specialty |
|------|------|-----------|
| **Merlin Guardian** | `merlin_guardian.md` | **Merlin's personality, voice, behavioral consistency** |
| **Lore Writer** | `lore_writer.md` | **Deep mythology, hidden narratives, apocalyptic truth** |
| **Historien Bretagne** | `historien_bretagne.md` | **Celtic/Breton history, mythology research, authenticity** |

### Operations & Documentation Agents

| Role | File | Specialty |
|------|------|-----------|
| Producer | `producer.md` | Priorities, milestones, coordination |
| Localisation | `localisation.md` | Multi-language, translation |
| **Technical Writer** | `technical_writer.md` | **Docstrings, API docs, tutorials** |
| **Data Analyst** | `data_analyst.md` | **Game analytics, A/B testing, balance metrics** |

### Project Management Agents

| Role | File | Specialty |
|------|------|-----------|
| **Git Commit** | `git_commit.md` | **Auto-commit, message formatting, change grouping** |
| **Project Curator** | `project_curator.md` | **Inventory, cleanup, orphan detection, .gitignore** |

### Shared Resources

| Resource | File | Purpose |
|----------|------|---------|
| **Knowledge Base** | `gdscript_knowledge_base.md` | **Corrections, best practices, lessons learned** |

---

## Workflow

### Standard Task Flow

```
1. Producer assigns task with priority
2. Game Designer validates design intent
3. Relevant implementation agent executes
4. Debug/QA tests the result
5. Lead Godot reviews and approves
```

### Cross-Functional Reviews

| Change Type | Required Review |
|-------------|-----------------|
| GDScript code | Lead Godot, Debug/QA, **Optimizer** |
| Performance issues | **Godot Expert**, **Optimizer** |
| LLM integration | **LLM Expert**, Godot Expert |
| UI/UX changes | UI Impl, UX Research |
| Card content | Narrative, Game Designer |
| Visual assets | Art Direction |
| Audio changes | Audio Designer |
| Doc changes | Producer, **Technical Writer** |
| **Shader/VFX code** | **Shader Specialist**, Godot Expert |
| **Animations/Tweens** | **Motion Designer**, UI Impl |
| **Touch/Mobile input** | **Mobile/Touch Expert**, UX Research |
| **Game balance data** | **Data Analyst**, Game Designer |
| **Correction learned** | **Debug/QA**, **Optimizer** |
| **Best practice found** | **Optimizer**, Debug/QA |
| **Phase completed** | **Git Commit** |
| **Project cleanup** | **Project Curator** |
| **Orphan files** | **Project Curator**, Lead Godot |

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

## Quick Reference Commands

```bash
# Invoke Lead Godot for architecture review
claude "Use Task with general-purpose agent to read .claude/agents/lead_godot.md and review the dru_store.gd architecture"

# Invoke QA for testing
claude "Use Task with general-purpose agent to read .claude/agents/debug_qa.md and test the ReignsGame scene"

# Invoke Narrative Writer for card content
claude "Use Task with general-purpose agent to read .claude/agents/narrative_writer.md and write 10 new fallback cards"

# Invoke Motion Designer for animation polish
claude "Use Task with general-purpose agent to read .claude/agents/motion_designer.md and add entry animations to the menu"

# Invoke Shader Specialist for visual effects
claude "Use Task with general-purpose agent to read .claude/agents/shader_specialist.md and create a CRT scanline effect"

# Invoke Mobile Expert for touch optimization
claude "Use Task with general-purpose agent to read .claude/agents/mobile_touch_expert.md and improve card swipe gesture"

# Invoke Data Analyst for balance review
claude "Use Task with general-purpose agent to read .claude/agents/data_analyst.md and analyze gauge ending distribution"

# Invoke Technical Writer for documentation
claude "Use Task with general-purpose agent to read .claude/agents/technical_writer.md and document the DruStore API"

# Invoke Optimizer for best practices scan
claude "Use Task with general-purpose agent to read .claude/agents/optimizer.md and scan scripts/dru/ for optimization opportunities"

# Invoke Debug with knowledge base update
claude "Use Task with general-purpose agent to read .claude/agents/debug_qa.md and document the correction in gdscript_knowledge_base.md"
```

---

*Created: 2026-02-06*
*Updated: 2026-02-08 — Added Optimizer agent + Knowledge Base (total: 23 agents + 1 shared resource)*
*Project: DRU - Le Jeu des Oghams*
