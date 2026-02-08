# Findings & Decisions - DRU: Le Jeu des Oghams

## Session: 2026-02-05

---

## PIVOT DECISION (2026-02-05)

### Nouvelle Direction
Le jeu pivote vers un **Reigns-like** avec LLM dynamique:
- **PAS de combat traditionnel** - Uniquement des choix narratifs
- **Bestiole = support passif** - Bonus passifs, outils, skills (pas de combat direct)
- **Scenarios dynamiques via LLM** - Style Reigns avec cartes/choix
- **Focus**: Narration + choix a consequences

### Ce qui change
| Avant | Apres |
|-------|-------|
| Combat FORCE/LOGIQUE/FINESSE | Choix narratifs type Reigns |
| Bestiole combat actions | Bestiole = bonus passifs + outils |
| Turn-based combat | Swipe/choix binaires ou multiples |
| Oghams = attaques | Oghams = declencheurs narratifs? |

### Architecture Decision
- **Fusionner vers DruStore** (modulaire, pret LLM)
- Abandonner le combat GameManager v7.0
- Garder l'UI style GBC/Reigns

---

## Project Overview

### Identity (UPDATED)
- **Game**: DRU: Le Jeu des Oghams (Merlin)
- **Genre**: Reigns-like narrative roguelite avec LLM
- **Core duo**: Merlin (LLM narrator) + Bestiole (support passif)
- **World**: Bretagne mystique, controlled by supercomputer "Merlin"
- **Philosophy**: Simple choices, complex consequences

### Gameplay Loop (NEW)
1. LLM genere un scenario/carte
2. Joueur fait un choix (style Reigns: swipe ou boutons)
3. Consequences s'appliquent aux ressources/stats
4. Bestiole donne des bonus passifs selon son etat
5. Boucle continue jusqu'a fin de run

---

## Architecture Findings

### Dual System Architecture
Le projet contient **deux systemes paralleles**:

#### 1. DruStore System (scripts/dru/*) - A GARDER
```
dru_store.gd          -> Central state management (Redux-like)
dru_event_system.gd   -> Event handling (KEEP - pour scenarios)
dru_effect_engine.gd  -> Effect application (whitelist)
dru_action_resolver.gd -> Resolution (A ADAPTER pour Reigns)
dru_llm_adapter.gd    -> LLM integration contract (CORE)
dru_save_system.gd    -> Save/load
dru_rng.gd            -> Deterministic RNG
dru_constants.gd      -> Constants
```

#### Files a deprecier/refactorer
```
dru_combat_system.gd  -> DEPRECIER (plus de combat)
dru_minigame_system.gd -> PEUT-ETRE garder pour tests narratifs?
```

#### 2. GameManager System - A MIGRER
```
game_manager.gd       -> Migrer vers DruStore
main_game.gd          -> Refactorer UI vers Reigns-style
```

---

## Reigns-Style Design Requirements

### Card/Choice Structure
```gdscript
var choice = {
    "id": "string",
    "text": "Description narrative...",
    "speaker": "MERLIN",  # ou vide pour narration
    "options": [
        {"label": "Gauche/Non", "effects": [...]},
        {"label": "Droite/Oui", "effects": [...]}
    ],
    "bestiole_bonus": "optional_modifier",
    "conditions": {},  # prerequisites
}
```

### Resources (Reigns-style bars)
Typiquement 4 resources a equilibrer:
- **Vigueur** (sante/energie physique)
- **Esprit** (sante mentale/magie)
- **Faveur** (reputation/relations)
- **Ressources** (materiel/or)

Si une barre atteint 0 ou max = fin de run

### Bestiole Role (NEW)
- **Bonus passifs** bases sur:
  - Needs (Hunger, Energy, Mood)
  - Bond level
  - Form active
- **Outils/Skills** que bestiole peut utiliser:
  - Reveal info sur choix
  - Modifier les effets
  - Debloquer options speciales
- **Pas de combat direct**

---

## LLM Integration (CORE)

### Merlin Contract (dru_llm_adapter.gd)
```gdscript
# Input context
{
    "resources": {...},
    "bestiole_state": {...},
    "story_log": [...],
    "current_arc": "string",
    "promises": [...],
    "hour_slice": int,
}

# Output (scenario card)
{
    "text": "narrative...",
    "speaker": "MERLIN",
    "options": [...],
    "effects_left": [...],  # whitelist only
    "effects_right": [...],
    "tags": ["tension", "choice", ...]
}
```

### Whitelist Effects (CRITICAL)
LLM ne peut proposer que des effets valides:
- ADD_RESOURCE / REMOVE_RESOURCE
- SET_FLAG / CHECK_FLAG
- TRIGGER_EVENT
- MODIFY_BESTIOLE
- UNLOCK_ITEM
- etc.

---

## UI Design (Reigns-Style)

### Main Screen Layout
```
+---------------------------+
|     [Resource Bars]       |
|  Vigueur | Esprit | etc.  |
+---------------------------+
|                           |
|    [Card/Scenario]        |
|    Image + Text           |
|                           |
+---------------------------+
|  [Bestiole Status Mini]   |
+---------------------------+
|  [Left]     [Right]       |
|  Choice     Choice        |
+---------------------------+
```

### Interactions
- Swipe left/right (mobile)
- Click buttons (desktop)
- Keyboard arrows

---

## Implementation Roadmap

### Phase 1: Core Reigns Engine
1. Refactorer DruStore pour Reigns-style
2. Creer CardSystem (remplace CombatSystem)
3. Implementer resource bars (4 jauges)
4. UI card display + swipe

### Phase 2: LLM Integration
1. Adapter dru_llm_adapter.gd
2. Definir whitelist effects
3. Context packaging
4. Response validation

### Phase 3: Bestiole as Support
1. Refactorer bestiole vers bonus passifs
2. Implementer outils/skills
3. Bond -> modifiers mapping

### Phase 4: Content & Polish
1. Scenarios de base (fallback sans LLM)
2. Merlin voice integration
3. Polish UI

---

## Files to Update

### Scripts (High Priority)
- [ ] `dru_store.gd` - Adapter pour Reigns
- [ ] `dru_event_system.gd` -> `dru_card_system.gd`
- [ ] `dru_llm_adapter.gd` - Contract Reigns
- [ ] `main_game.gd` - UI Reigns

### Documentation (High Priority)
- [ ] `MASTER_DOCUMENT.md` - Refleter pivot
- [ ] `GAMEPLAY_LOOP_ROGUELITE.md` - Reigns-style
- [ ] `DOC_05_Combat_System_v2.md` - DEPRECIER ou transformer
- [ ] `BESTIOLE_SYSTEM.md` - Role support passif
- [ ] NEW: `DOC_REIGNS_CARD_SYSTEM.md`

---

## Open Questions

1. **Nombre de resources?** 4 classique ou adapter aux 5 existantes?
2. **Oghams?** Gardent un role? Declencheurs narratifs?
3. **Mini-jeux?** Garder pour tests narratifs optionnels?
4. **Biomes?** Toujours pertinents comme themes visuels/narratifs?

---

## Session: 2026-02-07 - LLM Optimization Review

### Agent Reviews Summary

Four specialized agents reviewed the LLM integration code:

#### 1. LLM Expert Review
**Status**: OPTIMAL after corrections

| Metric | Before | After |
|--------|--------|-------|
| System Prompt | ~35 tokens | ~10 tokens |
| max_tokens | 256 → 80 | 60 |
| temperature | 0.6 | 0.4 |
| repetition_penalty | none → 1.5 | 1.6 |
| Expected Latency | 6-8s | 2-4s |

**Key Optimizations Applied**:
- Ultra-short prompts: `Merlin. Court. Francais.`
- Removed all examples from prompts (model was repeating them)
- Aggressive keyword-based leak detection
- Stronger repetition penalty (1.6)

#### 2. Godot Expert Review
**Status**: OPTIMAL after corrections

**Optimizations Applied**:
- Adaptive polling in warmup (fast→slow pattern)
- Model caching to avoid reloading
- Timeout protection (30s max)

**Polling Pattern**:
```gdscript
if poll_count < 5:
    await get_tree().process_frame     # ~16ms
elif poll_count < 20:
    await get_tree().create_timer(0.03).timeout  # 30ms
else:
    await get_tree().create_timer(0.1).timeout   # 100ms
```

#### 3. Lead Godot Review
**Status**: APPROVED

**Corrections Applied**:
- Added `_exit_tree()` for signal cleanup
- Added `unload_model()` call on cleanup
- Warmup timeout to prevent infinite loops
- Proper memory management

#### 4. Debug/QA Review
**Status**: TEST PLAN CREATED

- 117 test cases defined
- Covers: warmup, generation, UI, model switching, edge cases
- Pending user validation

### Files Modified (2026-02-07)

| File | Changes |
|------|---------|
| `scripts/TestLLMSceneUltimate.gd` | Ultra-short prompts, optimized params, aggressive cleaning |
| `scripts/llm_status_bar.gd` | Timeout, adaptive polling, _exit_tree() cleanup |
| `scripts/MenuPrincipalReigns.gd` | Added "Test LLM" menu item |
| `project.godot` | Added LLMStatusBar autoload |
| `.claude/agents/godot_expert.md` | NEW - Performance/GDExtension expert |
| `.claude/agents/llm_expert.md` | NEW - Prompt engineering expert |
| `.claude/agents/AGENTS.md` | Updated with new agents |

### LLM Parameters (Final)

```gdscript
const LLM_MAX_TOKENS := 60
const LLM_TEMPERATURE := 0.4
const LLM_TOP_P := 0.75
const LLM_TOP_K := 25
const LLM_REPETITION_PENALTY := 1.6
```

### Prompt Templates (Final)

```gdscript
# Simple response (~10 tokens)
const MERLIN_SYSTEM := """Merlin. Court. Francais."""

# With choices (~15 tokens)
const CHOICE_SYSTEM := """Merlin repond. Puis CHOIX: avec 4 options."""
```

### Known Issues Resolved

1. **Prompt Leakage**: Fixed with keyword detection + aggressive cleaning
2. **Slow Latency (17-22s)**: Reduced to estimated 2-4s
3. **Memory Leaks**: Fixed with proper _exit_tree() cleanup
4. **Warmup Hangs**: Fixed with 30s timeout

### Pending Validation

- [ ] User test in Godot to confirm latency improvements
- [ ] Verify LLM stays in Merlin character
- [ ] Verify 4 choices generated consistently

---

*Last updated: 2026-02-07 - POST AGENT REVIEW*
