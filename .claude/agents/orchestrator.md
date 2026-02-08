# Agent Orchestrator — DRU Multi-Agent System

## Overview

This orchestrator coordinates the team of specialized Claude Code agents for the DRU project.
Use this file to understand how to invoke and coordinate agents.

---

## Quick Start

### Invoke a Single Agent

```
Use the Task tool with:
- subagent_type: "general-purpose"
- prompt: "Read c:/Users/PGNK2128/Godot-MCP/.claude/agents/[agent].md and follow its role. Task: [your task]"
```

### Example Invocations

```
# Lead Godot reviews architecture
Task: Read .claude/agents/lead_godot.md. Review the dru_store.gd architecture and provide feedback.

# QA tests the Reigns scene
Task: Read .claude/agents/debug_qa.md. Test the ReignsGame.tscn scene for bugs.

# Narrative Writer creates cards
Task: Read .claude/agents/narrative_writer.md. Write 5 new fallback cards for the forest theme.

# Producer plans sprint
Task: Read .claude/agents/producer.md. Create a sprint plan for the next milestone.
```

---

## Agent Roster

| Agent | File | Primary Tasks |
|-------|------|---------------|
| Lead Godot | `lead_godot.md` | Architecture, code review, integration |
| Debug/QA | `debug_qa.md` | Testing, bug reports, fixes |
| UI Impl | `ui_impl.md` | Controls, themes, animations |
| UX Research | `ux_research.md` | Usability, readability, flow |
| Game Designer | `game_designer.md` | Rules, balance, progression |
| Narrative | `narrative_writer.md` | Card text, story, tone |
| Art Direction | `art_direction.md` | Visual style, assets |
| Audio | `audio_designer.md` | SFX, music, voice |
| Producer | `producer.md` | Planning, coordination |
| Localisation | `localisation.md` | Translation, i18n |

---

## Workflow Patterns

### Pattern 1: Feature Development

```
1. [Producer] Define task and assign
2. [Game Designer] Validate design
3. [Lead Godot] Plan implementation
4. [UI Impl / Lead Godot] Implement
5. [Debug/QA] Test
6. [Lead Godot] Review and approve
```

### Pattern 2: Content Creation

```
1. [Game Designer] Define card requirements
2. [Narrative] Write card text
3. [Art Direction] Specify visuals (if any)
4. [Audio] Specify sounds (if any)
5. [Debug/QA] Test cards in-game
```

### Pattern 3: Bug Fix

```
1. [Debug/QA] Report bug with reproduction
2. [Lead Godot] Triage and assign
3. [Appropriate Agent] Fix
4. [Debug/QA] Verify fix
5. [Lead Godot] Approve
```

### Pattern 4: UX Improvement

```
1. [UX Research] Identify issue
2. [Game Designer] Validate design solution
3. [UI Impl] Implement
4. [UX Research] Verify improvement
5. [Debug/QA] Regression test
```

---

## Parallel Agent Execution

When tasks are independent, invoke multiple agents in parallel:

```
# Example: Parallel documentation and testing
Use Task tool twice in same message:

1. Task (Lead Godot): Review architecture
2. Task (Debug/QA): Run test suite
```

---

## Handoff Protocol

When one agent completes work for another:

```markdown
## Handoff: [From Agent] -> [To Agent]

### Completed Work
- Description of what was done

### Files Changed
- `path/file.gd` - Changes made

### For [To Agent]
- Specific request or question

### Context
- Relevant state or decisions
```

---

## Common Multi-Agent Scenarios

### Scenario: New Feature

```
Prompt:
"Coordinate agents to implement [feature]:
1. First, have Game Designer define requirements
2. Then, Lead Godot plan implementation
3. Finally, appropriate agents implement and test"
```

### Scenario: Bug Triage

```
Prompt:
"Coordinate agents to fix [bug]:
1. Debug/QA reproduces and documents
2. Lead Godot identifies root cause
3. Appropriate agent fixes
4. Debug/QA verifies"
```

### Scenario: Content Sprint

```
Prompt:
"Coordinate content creation:
1. Game Designer defines 10 card themes
2. Narrative Writer creates text
3. Debug/QA tests cards
4. Producer tracks progress"
```

---

## Agent Communication Channels

### Status Updates
Agents report status with tags:
- `[READY]` - Work complete
- `[WIP]` - Work in progress
- `[BLOCKED]` - Needs input
- `[REVIEW]` - Needs review

### Escalation Path
```
Any Agent -> Lead Godot (technical)
Any Agent -> Producer (process)
Any Agent -> Game Designer (design)
```

---

## Project Context Summary

### Current State (2026-02)
- Pivoted to Reigns-style gameplay
- Core card system implemented
- UI implemented, needs polish
- LLM integration pending
- 20 fallback cards, need 80 more

### Key Files
```
scripts/dru/dru_store.gd        <- Central state
scripts/dru/dru_card_system.gd  <- Card engine
scripts/ui/reigns_game_ui.gd    <- Game UI
scenes/ReignsGame.tscn          <- Main scene
docs/MASTER_DOCUMENT.md         <- Project overview
```

### Tech Stack
- Engine: Godot 4.x
- Language: GDScript
- State: Redux-like (DruStore)
- LLM: Anthropic Claude (via adapter)

---

## Best Practices

1. **One agent per task** - Don't mix responsibilities
2. **Clear handoffs** - Always specify next agent
3. **Read role first** - Agent reads its .md before acting
4. **Document decisions** - Update docs after changes
5. **Test after changes** - Always involve QA

---

*Orchestrator version: 1.0*
*Last updated: 2026-02-06*
