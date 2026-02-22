# Game-Design Review — Cycle 1

**Domain**: Game-Design
**Reviewer**: Game Balance & Tone Specialist
**Date**: 2026-02-22
**Status**: ✅ COMPLETED (theoretical analysis)

---

## Deliverables

### 1. Balance Analysis (`balance_analysis.json`)
- **Task**: GD.1 — Balance analysis from auto-play stats
- **Status**: ⚠️ Theoretical (no autoplay stats found)
- **Findings**:
  - **CRITICAL**: `LIFE_ESSENCE_DRAIN_PER_CARD = 1` is too low → propose `= 2`
  - **HIGH**: `AWEN_REGEN_INTERVAL = 5` allows too many special Oghams → propose `= 6`
  - **MEDIUM**: Power milestone timing suboptimal (heal at card 5 overcaps)
  - **OK**: DC ranges well-balanced (75%/60%/40% success rates)

### 2. Tone Evaluation (`tone_analysis.json`)
- **Task**: GD.2 — Fun factor and tone evaluation
- **Status**: ✅ Completed
- **Findings**:
  - **Quirky**: 9/10 (Merlin's glitches, meta-humor excellent)
  - **Mysterious**: 10/10 (layered secrets, double meanings, lore reveals)
  - **Humour décalé**: 6/10 (present in Merlin, missing in scenarios)
  - **Narration double fond**: 10/10 (scenario twists, hidden meanings)
- **Recommendation**: Add 2-3 comedic/absurd scenarios

### 3. Proposed Changes (`proposed_changes.json`)
- **Task**: GD.3 — Propose balance adjustments
- **Status**: ✅ Completed
- **Changes**:
  1. `LIFE_ESSENCE_DRAIN_PER_CARD := 2` (CRITICAL)
  2. `AWEN_REGEN_INTERVAL := 6` (HIGH)
  3. Swap `POWER_MILESTONES` entries 5 and 8 (MEDIUM)

---

## Critical Warning

**NO AUTOPLAY STATS AVAILABLE** — All balance predictions are THEORETICAL based on static code analysis of `merlin_constants.gd`.

**Required Next Step**: Implement autoplay testing infrastructure and run 100+ automated runs to validate predictions.

---

## Action Items for Gameplay Domain

1. ✅ Review `proposed_changes.json`
2. ⬜ Apply changes to `scripts/merlin/merlin_constants.gd`
3. ⬜ Implement autoplay testing (CRITICAL)
4. ⬜ Run 100+ autoplay tests
5. ⬜ Validate balance predictions with `stats_summary.json`
6. ⬜ Add 2-3 comedic scenarios to `data/ai/scenarios/scenario_catalogue.json`

---

## Metrics to Track (Future Autoplay Tests)

- `run_length_distribution` (target: 25-35 cards)
- `ending_distribution` (target: no ending > 15%)
- `life_curve` (HP per card)
- `souffle_usage_rate` (target: 60-80% of runs)
- `awen_usage_per_ogham_category`
- `dc_success_rate_per_option`
- `milestone_heal_overcap_rate`
- `rest_node_visit_frequency`
- `critical_failure_death_rate`

---

**Reviewer Sign-Off**: Game-Design Review Worker
**Confidence**: HIGH (balance), MEDIUM (tone — needs LLM card samples)
**Next Cycle**: Validate with real autoplay data
