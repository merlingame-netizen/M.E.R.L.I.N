# ADR: ARCH-1 — Scoring Pipeline (D20/DC vs Minigame+Multiplier)

> **Status**: Accepted — Keep current implementation
> **Date**: 2026-03-16
> **Scope**: `merlin_minigame_system.gd`, `merlin_effect_engine.gd`, `merlin_card_system.gd`, `merlin_constants.gd`

---

## 1. Context

The codebase contains two scoring models:

1. **D20/DC model** (legacy) — A tabletop-RPG-style system where a D20 roll is compared against a Difficulty Class (DC). This was the original design.
2. **Minigame+Multiplier model** (current) — The player plays a skill-based minigame that produces a score 0-100, which maps to a multiplier that scales card effects.

The Game Design Bible v2.4 explicitly lists D20 as a **suppressed system** (section "Systemes SUPPRIMES"):

> `| D20 / dice roll | Remplace par minigames systematiques | 2026-03-12 |`

The bible also documents the current pipeline as the **reference absolue** (section 13.3).

This document formalizes the gap analysis and confirms the decision.

---

## 2. What the Bible Describes (Design Intent)

### 2.1 Pipeline (bible section 13.3, 12 steps)

```
1. DRAIN -1 PV at card start
2. CARD displayed (narrative + 3 options)
3. OGHAM? activation (before choice, optional)
4. CHOICE by player (1 of 3 options)
5. MINIGAME: player plays the minigame (skip only for Merlin Direct)
6. SCORE: 0-100, multiplier calculated
7. APPLICATION EFFETS: option effects x multiplier
8. OGHAM PROTECTION: filter negative effects (luis/gort/eadhadh)
9. VIE=0? death check AFTER all effects
10. PROMESSES: check/expire promises
11. COOLDOWN: decrement ogham cooldowns
12. RETOUR 3D: return to 3D walk
```

### 2.2 Multiplier Table (bible section 6.5)

| Score     | Label               | Multiplier |
|-----------|---------------------|------------|
| 0-20      | echec critique      | neg x1.5   |
| 21-50     | echec               | neg x1.0   |
| 51-79     | reussite partielle  | pos x0.5   |
| 80-100    | reussite            | pos x1.0   |
| 95-100    | reussite critique   | pos x1.5   |

### 2.3 Minigame Selection

Detection is verb-based: 45 verbs in a closed list map to 8 lexical fields, each field maps to 1-2 minigame types.

### 2.4 Merlin Direct Exception

Cards of type `merlin_direct` have no minigame. Effects apply at x1.0 (100%).

### 2.5 Score Bonuses

Additive bonuses from biome affinity, talent tree, 3D buffs, ogham `ur` (x1.3). Global cap: x2.0.

---

## 3. What the Code Actually Implements

### 3.1 Core Scoring Pipeline (ALIGNED)

**`merlin_card_system.gd:resolve_card()`**: Receives `score: int` (0-100) from minigame, looks up multiplier via `MerlinEffectEngine.get_multiplier(score)`, scales each effect via `scale_and_cap`, returns applied effects.

### 3.2 Multiplier Table (ALIGNED)

**`merlin_constants.gd:MULTIPLIER_TABLE`**: Exact match with bible — 5 tiers with factors -1.5, -1.0, 0.5, 1.0, 1.5.

### 3.3 Minigame System (ALIGNED)

**`merlin_minigame_system.gd`**: 8 field-specific algorithms. Difficulty 1-10, success threshold 80.

### 3.4 Effect Capping (ALIGNED)

**`merlin_constants.gd:EFFECT_CAPS`**: rep +/-20, heal 18, damage 15, biome currency 10, score bonus cap x2.0.

### 3.5 Ogham Protection Step 8 (ALIGNED)

**`merlin_effect_engine.gd:apply_ogham_protection()`**: luis/gort/eadhadh. Immutable.

---

## 4. D20/DC Legacy — Gap Analysis

### 4.1 Remaining D20 References

| File | Nature | Risk |
|------|--------|------|
| `minigame_base.gd:score_to_d20()` | Cosmetic conversion (score -> D20 visual) | Low — KEEP |
| `ui_overlay_dice.gd` | UI dice animation | Low — KEEP |
| `auto_play_runner.gd:257-277` | Reads `d20`/`dc` from history | Medium — CLEAN UP |
| `test_llm_full_run.gd:229-253` | Simulates D20 roll | Medium — CLEAN UP |
| `SFXManager.gd` | Dice sound effects | None — KEEP |

### 4.2 Architectural Verdict

The D20/DC system has been **correctly superseded** at the mechanical level. No game logic depends on D20 rolls. The remaining references are cosmetic (dice animation) or stale test code.

---

## 5. Decision

**Keep the current Minigame+Multiplier implementation. No migration needed.**

```
Verb Detection -> Lexical Field -> Minigame Type -> Score 0-100
  -> Multiplier Table -> scale_and_cap -> Applied Effects
  -> Ogham Protection -> Final State
```

### 5.1 Recommended Cleanup (Low Priority)

| Action | Files | Priority |
|--------|-------|----------|
| Remove `d20`/`dc` reads from auto_play_runner | `auto_play_runner.gd` | LOW |
| Remove D20 simulation from test_llm_full_run | `test_llm_full_run.gd` | LOW |
| Keep `score_to_d20()` and dice overlay | `minigame_base.gd`, `ui_overlay_dice.gd` | KEEP |
| Keep dice sound effects | `SFXManager.gd` | KEEP |

---

## 6. Summary

| Aspect | Bible | Code | Status |
|--------|-------|------|--------|
| Minigame produces score 0-100 | Yes | Yes | ALIGNED |
| 5-tier multiplier table | Yes | Yes | ALIGNED |
| `scale_and_cap` pipeline | Yes | Yes | ALIGNED |
| Merlin Direct = x1.0 | Yes | Yes | ALIGNED |
| Ogham protection filter (step 8) | Yes | Yes | ALIGNED |
| D20/DC mechanical system | SUPPRESSED | Not used mechanically | ALIGNED |
| D20 visual display (cosmetic) | Not mentioned | Present | ACCEPTABLE |
| Verb -> Field -> Minigame | Yes | Yes | ALIGNED |
| Effect caps | Yes | Yes | ALIGNED |
| Score bonus cap x2.0 | Yes | Yes | ALIGNED |

**Conclusion**: Zero gaps between bible and code for the scoring pipeline.

---

*Generated: 2026-03-16 — Studio Sprint #2, Wave 3-D*
