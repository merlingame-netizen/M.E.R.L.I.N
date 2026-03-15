# ARCH-1: Pipeline Resolution — D20/DC vs Minigame+Multiplier

**Date**: 2026-03-15
**Status**: DECISION REQUIRED
**Priority**: HIGH — gameplay divergence from bible v2.4

---

## Finding

Two incompatible resolution pipelines coexist in the codebase.

---

## System A — Current Code (merlin_game_controller.gd)

**Location**: `scripts/ui/merlin_game_controller.gd`, lines 786-822

**Mechanism**:
1. Compute a DC (difficulty class) per direction: `_get_dc_for_direction()`
2. 70% of the time: roll D20 dice → compare to DC
3. 30% of the time: launch minigame → `score_to_d20()` → compare to DC
4. Classify outcome: `critical_success` / `success` / `failure` / `critical_failure`
5. Modulate effects via `_modulate_effects()`: reverses heals↔damage on failure, doubles on crit

**Key signals**:
- `var minigame_chance := 0.3` (minigame is probabilistic, dice is the default)
- `score_to_d20()` converts minigame score to a 1-20 range, throwing away precision
- `_modulate_effects()` applies binary reversal logic (heal↔damage), not proportional scaling
- Headless mode: `dice_result = randi_range(1, 20)` — no minigame at all

---

## System B — Bible v2.4 (GAME_DESIGN_BIBLE.md s.2.5, s.6.5)

**Location**: `docs/GAME_DESIGN_BIBLE.md`, section 2.5 + constants in `merlin_constants.gd`

**Mechanism**:
1. Player picks option → lexical field detected → minigame assigned
2. Minigame always played (mandatory, no skip, no dice fallback)
3. Score 0-100 → MULTIPLIER_TABLE lookup → proportional factor
4. Effects scaled: `amount × factor` (e.g. score 60 → ×0.5 → "+15 rep" becomes "+7.5 rep")
5. Cap: `score_bonus_cap = 2.0`, `effects_per_option = 3`

**Multiplier table** (already in `merlin_constants.gd` MULTIPLIER_TABLE):
| Score | Label | Factor |
|-------|-------|--------|
| 0-20 | echec_critique | -1.5 |
| 21-50 | echec | -1.0 |
| 51-79 | reussite_partielle | 0.5 |
| 80-94 | reussite | 1.0 |
| 95-100 | reussite_critique | 1.5 |

---

## Dead Code Assessment

`MerlinCardSystem.resolve_card()` (`merlin_card_system.gd`, line 526) **IS called** — from `run_3d_controller.gd:177`. It uses `MerlinEffectEngine.get_multiplier(score)` and `scale_and_cap()`, which implement the bible v2.4 multiplier system correctly.

**Conclusion**: `resolve_card()` is NOT dead — it is the correct implementation of System B and is already wired in `run_3d_controller`. The dead code is the D20 path in `merlin_game_controller.gd`.

---

## Pros/Cons

| Criterion | System A (D20/DC) | System B (Minigame+Multiplier) |
|-----------|-------------------|---------------------------------|
| Bible alignment | No | Yes (v2.4) |
| Player agency | Binary (pass/fail) | Proportional (0-100 gradient) |
| Score precision | Lost (score_to_d20 collapses to 1-20) | Preserved |
| Complexity | High (DC table, karma, adaptive difficulty) | Simpler, single multiplier table |
| Current usage | merlin_game_controller (legacy UI) | run_3d_controller (active 3D run) |
| Testability | Headless dice fallback exists | Must simulate minigame score |

---

## Decision: Migrate to System B

**Rationale**: System B is already correctly implemented and actively used in `run_3d_controller.gd`. The bible v2.4 is unambiguous: minigames are mandatory, no dice, score is the direct driver. System A is a legacy from early prototyping (Phase 37 "TestBrainPool fusion").

---

## Migration Steps

1. **Keep `resolve_card()` in `merlin_card_system.gd`** — it is correct, no changes needed.

2. **Remove D20 path from `merlin_game_controller._resolve_choice()`**:
   - Delete `_run_dice_roll()`, `_classify_outcome()`, `_get_dc_for_direction()`
   - Remove `minigame_chance` var and the 70/30 split
   - Remove `score_to_d20()` call in `_run_minigame()`; pass raw score directly to `resolve_card()`

3. **Replace `_modulate_effects()` with `resolve_card()` call**:
   - `merlin_game_controller` should delegate to `_card_system.resolve_card(run_state, card, option, score)` instead of computing modulated effects itself
   - Remove `_modulate_effects()` and `_apply_chance_modifier_effects()`

4. **Remove dead constants** in `merlin_constants.gd`:
   - `DC_BASE` (variable DC ranges, line ~990+)
   - `LIFE_ESSENCE_CRIT_FAIL_DAMAGE` / `LIFE_ESSENCE_CRIT_SUCCESS_HEAL` (replace with EFFECT_CAPS)

5. **Headless mode**: replace `dice_result = randi_range(1, 20)` with a fixed score (e.g. 75) or a simulated score for test reproducibility.

6. **UI layer**: `show_dice_result()` / `show_dice_roll()` in UI → replace with `show_minigame_score()` (score + multiplier label).

---

## Risk

- `merlin_game_controller` has ~1400 lines with D20 logic entangled in karma, talents, quest history. Scope the migration per sub-function, validate after each step with `.\validate.bat`.
- `run_3d_controller` already uses System B — do not touch it during migration.
