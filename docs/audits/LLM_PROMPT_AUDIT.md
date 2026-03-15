# LLM Prompt Audit — Bible v2.4 Alignment

**Date**: 2026-03-15
**File**: `scripts/merlin/merlin_llm_adapter.gd`
**Bible ref**: `docs/GAME_DESIGN_BIBLE.md` v2.4
**Constants ref**: `scripts/merlin/merlin_constants.gd`

---

## Issues Found and Fixed

### 1. CRITICAL — Legacy system prompt references removed systems
**Location**: `get_system_prompt()` (line ~2630)
**Problem**: Referenced "DRU", 4 jauges (Vigueur/Esprit/Faveur/Ressources), `ADD_GAUGE`/`REMOVE_GAUGE` effects, 2-option (left/right) format. All are removed systems per bible v2.4.
**Fix**: Rewrote prompt to reference 5 factions, 3 options, valid effect types (ADD_REPUTATION, HEAL_LIFE, etc.), and correct amount caps. Added deprecation warning.

### 2. CRITICAL — `ADD_BIOME_CURRENCY` missing from ALLOWED_EFFECT_TYPES
**Location**: `ALLOWED_EFFECT_TYPES` const (line ~17)
**Problem**: `ADD_BIOME_CURRENCY` is a valid effect per bible v2.4 and `EFFECT_CAPS` in constants, but was absent from the whitelist. LLM-generated effects of this type would be silently rejected.
**Fix**: Added `"ADD_BIOME_CURRENCY"` to the whitelist.

### 3. HIGH — `_validate_faction_effect` missing ADD_BIOME_CURRENCY handler
**Location**: `_validate_faction_effect()` match block
**Problem**: Even after adding to whitelist, no match arm existed to validate and sanitize ADD_BIOME_CURRENCY effects. They would fall through to the empty return.
**Fix**: Added match arm with cap from `MerlinConstants.EFFECT_CAPS` (max 10).

### 4. HIGH — `_validate_faction_effect` missing REMOVE_TAG and TRIGGER_EVENT handlers
**Location**: `_validate_faction_effect()` match block
**Problem**: Both types were in `ALLOWED_EFFECT_TYPES` but had no validation handler, causing silent rejection.
**Fix**: Added match arms for both types.

### 5. MEDIUM — `_build_narrative_system_prompt` specified "2-4 options"
**Location**: `_build_narrative_system_prompt()` (line ~1954)
**Problem**: Prompt said "2-4 options" instead of exactly 3 per bible v2.4.
**Fix**: Changed to "exactement 3 options (1 verbe chacune, 1-3 effets chacune)" and added valid effect types and rep cap.

### 6. MEDIUM — Smart effects prompt wrong amount range and missing effect types
**Location**: `calculate_smart_effects()` GM prompt (line ~1849-1852)
**Problem**: Prompt said "amount 1-15" but rep cap is +/-20. Missing ADD_BIOME_CURRENCY from effect type list.
**Fix**: Changed to "amount 1-20. Rep cap +-20." and added ADD_BIOME_CURRENCY to types list.

### 7. MEDIUM — Legacy `_effect_to_code` used ADD_GAUGE/REMOVE_GAUGE
**Location**: `_effect_to_code()` (line ~2600)
**Problem**: First two match arms used removed effect types (ADD_GAUGE, REMOVE_GAUGE).
**Fix**: Replaced with current effect types: ADD_REPUTATION, HEAL_LIFE, DAMAGE_LIFE, ADD_ANAM, ADD_BIOME_CURRENCY, UNLOCK_OGHAM.

### 8. MEDIUM — Legacy option fallback used ADD_GAUGE
**Location**: `_validate_option()` (line ~2517)
**Problem**: Empty effects fallback created `{"type": "ADD_GAUGE", "target": "Vigueur", "value": 0}` — a removed effect type.
**Fix**: Changed to `{"type": "HEAL_LIFE", "amount": 3}`.

### 9. LOW — Flux system injected into prompts (removed system)
**Location**: `_build_context_enrichment()` and `build_narrative_context()`
**Problem**: Flux axes (terre/esprit/lien) are a removed system per bible v2.4, but were still built in context and injected into LLM prompts as "Flux: terre fort, esprit faible".
**Fix**: Removed flux_desc construction and injection from both functions.

---

## No Issues Found (Verified Correct)

| Check | Status |
|-------|--------|
| No Triade/D20/Souffle/Awen references | PASS — none found |
| 5 factions correct (druides, anciens, korrigans, niamh, ankou) | PASS |
| Rep cap +/-20 in validation code | PASS — `clampf(..., -20.0, 20.0)` correct |
| MOS thresholds match constants (soft_min=8, target=20-25, soft_max=40, hard_max=50) | PASS |
| Trust tier T0-T3 system not referenced in prompts (correct — trust affects narrative tone, not prompt) | PASS |
| Lexical fields match 8 constants (chance, bluff, observation, logique, finesse, vigueur, esprit, perception) | PASS |
| Card generation always produces 3 options (pad to 3 with fallbacks) | PASS |
| Two-stage system enforces 1-3 effects per option | PASS |
| FACTION_KEYWORDS auto-tag uses FACTION_DELTA_MINOR (5) | PASS |
| Celtic themes and verb pools provide variety | PASS |

---

## Remaining Concerns

### 1. Legacy `validate_card()` still expects 2 options (left/right)
The old validation path (line ~2441) enforces exactly 2 options with left/right directions. This is only used by the legacy code path and has a deprecation warning on `validate_scene()`. Not fixed because it is explicitly marked as legacy backward compatibility — removing it could break old saved games.

### 2. Legacy `_validate_effect()` has limited effect type coverage
The old validation path only handles SET_FLAG, ADD_TAG, REMOVE_TAG, QUEUE_CARD, TRIGGER_ARC, CREATE_PROMISE. Missing current types. Same legacy concern as above.

### 3. `QUEUE_CARD` and `TRIGGER_ARC` not in ALLOWED_EFFECT_TYPES
These are used only in legacy validation and not in current card generation. They are internal engine effects, not LLM-generated. Acceptable as-is.

---

## Prompt Quality Assessment

**Overall**: GOOD — prompts are well-tuned for Qwen 3.5-4B with appropriate constraints.

**Strengths**:
- Two-stage generation (free text + programmatic wrap) avoids JSON format failures
- Balance-aware hints adapt tone to player state
- Rotating examples prevent verb repetition
- MOS convergence hints guide narrative arc pacing
- Comprehensive meta-text stripping handles LLM leakage
- Smart effects (Game Master brain) add context-aware balance

**Areas for monitoring**:
- The `ADD_KARMA` and `ADD_TENSION` effect types are in the whitelist and validated, but not mentioned in the bible v2.4 effect list. They appear to be internal systems — confirm they are intentional.
- The `ADD_NARRATIVE_DEBT` type is similarly internal. Consider documenting these internal-only types.
