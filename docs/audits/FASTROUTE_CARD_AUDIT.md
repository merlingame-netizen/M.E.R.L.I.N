# FastRoute Card Pool Audit

> Generated: 2026-03-15 | Auditor: Claude Code | READ-ONLY (no files modified)

---

## 1. Summary

| Pool | File | Card Count |
|------|------|------------|
| FastRoute Narrative | `data/ai/fastroute_cards.json` → `narrative` | 14 |
| FastRoute Merlin Direct | `data/ai/fastroute_cards.json` → `merlin_direct` | 4 |
| Event (Seasonal) | `data/ai/event_cards.json` → `seasonal` | 8 |
| Event (Biome-specific) | `data/ai/event_cards.json` → `biome_specific` | 10 |
| Event (Universal) | `data/ai/event_cards.json` → `universal` | 5 |
| Promise | `data/ai/promise_cards.json` → `promises` | 7 |
| **TOTAL** | | **48** |

The Game Design Bible targets 500+ cards for FastRoute. The current pool has **14 narrative + 4 merlin_direct = 18 FastRoute cards**, which is **3.6% of target**.

---

## 2. FastRoute Narrative Cards — Per Biome

| Biome | Card Count | Card IDs |
|-------|------------|----------|
| `foret_broceliande` | 2 | fr_broceliande_001, fr_broceliande_002 |
| `landes_bruyere` | 1 | fr_landes_001 |
| `cotes_sauvages` | 1 | fr_cotes_001 |
| `villages_celtes` | 1 | fr_villages_001 |
| `cercles_pierres` | 1 | fr_cercles_001 |
| `marais_korrigans` | 1 | fr_marais_001 |
| `collines_dolmens` | 1 | fr_collines_001 |
| `iles_mystiques` | 1 | fr_iles_001 |
| Generic (no biome) | 5 | fr_generic_001 to fr_generic_005 |

**Issue**: All 8 biomes have only 1 card each (foret_broceliande has 2). With MOS target of 20-25 cards per run, the pool will exhaust within 1-2 runs per biome, causing heavy reliance on generic fallback and pool reset.

---

## 3. FastRoute Merlin Direct Cards — Per Trust Tier

| Trust Tier Min | Card Count | Card IDs |
|----------------|------------|----------|
| T0 | 2 | md_conseil_001, md_warning_001 |
| T1 | 1 | md_secret_001 |
| T2 | 1 | md_gift_001 |
| T3 | 0 | (none) |

**Issue**: No T3-exclusive cards. Players at max trust have no unique Merlin Direct content.

---

## 4. Faction Coverage — FastRoute Narrative Pool

Factions referenced in effects across all 14 narrative cards:

| Faction | Cards with at least 1 effect | Total effects referencing |
|---------|------------------------------|--------------------------|
| `druides` | 6 | 7 |
| `anciens` | 8 | 9 |
| `korrigans` | 4 | 4 |
| `ankou` | 3 | 3 |
| `niamh` | 2 | 2 |

**Issue**: `niamh` faction is underrepresented (only 2 cards: fr_broceliande_002 and fr_iles_001). `ankou` is also sparse (3 cards). `anciens` dominates.

---

## 5. Faction Coverage — Merlin Direct Pool

| Faction | Effects referencing |
|---------|---------------------|
| `druides` | 3 |
| `anciens` | 2 |
| `korrigans` | 1 |
| `ankou` | 2 |
| `niamh` | 0 |

**Issue**: `niamh` has zero representation in Merlin Direct cards.

---

## 6. Faction Coverage — Event Cards (All Sub-pools)

| Faction | Seasonal | Biome-specific | Universal | Total |
|---------|----------|----------------|-----------|-------|
| `druides` | 7 | 4 | 3 | 14 |
| `anciens` | 5 | 5 | 3 | 13 |
| `korrigans` | 1 | 4 | 1 | 6 |
| `ankou` | 1 | 1 | 3 | 5 |
| `niamh` | 1 | 3 | 1 | 5 |

---

## 7. Faction Coverage — Promise Cards

| Faction | Card Count | Promise IDs |
|---------|------------|-------------|
| `druides` | 2 | survive_8_cards, gain_rep_druides |
| `anciens` | 2 | win_3_minigames, no_safe_choices |
| `korrigans` | 1 | korrigan_bargain |
| `ankou` | 1 | walk_with_death |
| `niamh` | 1 | heal_the_land |

All 5 factions have at least 1 promise. Balanced.

---

## 8. Structural Validation

### 8.1 Required Fields Check

**FastRoute Narrative cards** — Required: `id`, `text`, `biome`, `options`, `tags`

| Card ID | id | text | biome | options | tags | PASS |
|---------|----|----|-------|---------|------|------|
| fr_broceliande_001 | OK | OK | OK | 3 | OK | YES |
| fr_broceliande_002 | OK | OK | OK | 3 | OK | YES |
| fr_landes_001 | OK | OK | OK | 3 | OK | YES |
| fr_cotes_001 | OK | OK | OK | 3 | OK | YES |
| fr_villages_001 | OK | OK | OK | 3 | OK | YES |
| fr_cercles_001 | OK | OK | OK | 3 | OK | YES |
| fr_marais_001 | OK | OK | OK | 3 | OK | YES |
| fr_collines_001 | OK | OK | OK | 3 | OK | YES |
| fr_iles_001 | OK | OK | OK | 3 | OK | YES |
| fr_generic_001 | OK | OK | "" | 3 | OK | YES |
| fr_generic_002 | OK | OK | "" | 3 | OK | YES |
| fr_generic_003 | OK | OK | "" | 3 | OK | YES |
| fr_generic_004 | OK | OK | "" | 3 | OK | YES |
| fr_generic_005 | OK | OK | "" | 3 | OK | YES |

All 14 cards pass structural validation.

**FastRoute Merlin Direct cards** — Required: `id`, `text`, `trust_tier_min`, `options`, `tags`

| Card ID | id | text | trust_tier_min | options | tags | PASS |
|---------|----|----|----------------|---------|------|------|
| md_conseil_001 | OK | OK | T0 | 3 | OK | YES |
| md_secret_001 | OK | OK | T1 | 3 | OK | YES |
| md_warning_001 | OK | OK | T0 | 3 | OK | YES |
| md_gift_001 | OK | OK | T2 | 3 | OK | YES |

All 4 cards pass.

### 8.2 Option Count (must be exactly 3 per Bible v2.4)

All 48 cards across all pools have exactly 3 options. **PASS**.

### 8.3 Effects Per Option (max 3 per Bible v2.4)

| Pool | Max effects on any single option | PASS |
|------|----------------------------------|------|
| FastRoute Narrative | 2 | YES |
| FastRoute Merlin Direct | 2 | YES |
| Event Seasonal | 2 | YES |
| Event Biome-specific | 2 | YES |
| Event Universal | 2 | YES |
| Promise | 2 | YES |

No option exceeds 3 effects. **PASS**.

### 8.4 Duplicate Card IDs

No duplicate IDs found across any pool. **PASS**.

All IDs are unique within and across files.

---

## 9. Effect Type Validation

Valid effect types per `merlin_effect_engine.gd`:
`DAMAGE_LIFE`, `HEAL_LIFE`, `CREATE_PROMISE`, `ADD_REPUTATION`, `ADD_ANAM`, `ADD_BIOME_CURRENCY`, `UNLOCK_OGHAM`, `TRIGGER_EVENT`, `PLAY_SFX`, `SHOW_DIALOG`

### Effect types used in card data:

| Effect Type | FastRoute | Events | Promises | Valid? |
|-------------|-----------|--------|----------|--------|
| `ADD_REPUTATION` | 26 uses | 48 uses | 6 uses | YES |
| `HEAL_LIFE` | 16 uses | 19 uses | 2 uses | YES |
| `DAMAGE_LIFE` | 5 uses | 8 uses | 0 uses | YES |
| `CREATE_PROMISE` | 0 uses | 0 uses | 12 uses | YES |
| `TRIGGER_EVENT` | 0 uses | 6 uses | 0 uses | YES |

No invalid effect types found. **PASS**.

Note: `ADD_ANAM`, `ADD_BIOME_CURRENCY`, `UNLOCK_OGHAM`, `PLAY_SFX`, `SHOW_DIALOG` are valid but unused in any card data file.

---

## 10. Value Range Validation

Per `EFFECT_CAPS` in `merlin_constants.gd`:
- `ADD_REPUTATION`: min -20, max +20
- `HEAL_LIFE`: max 18
- `DAMAGE_LIFE`: max 15

### Out-of-range values found:

**NONE** — All values are within caps.

| Metric | Min found | Max found | Cap | PASS |
|--------|-----------|-----------|-----|------|
| ADD_REPUTATION amount | -10 | +12 | [-20, +20] | YES |
| HEAL_LIFE amount | +3 | +10 | [0, 18] | YES |
| DAMAGE_LIFE amount | +3 | +5 | [0, 15] | YES |

---

## 11. Faction ID Validation

Valid factions: `druides`, `anciens`, `korrigans`, `ankou`, `niamh`

All `faction` values in `ADD_REPUTATION` effects use valid faction IDs. **PASS**.

---

## 12. Verb Validation (FastRoute Narrative)

Valid verbs per `ACTION_VERBS` in `merlin_constants.gd` (45 verbs across 8 fields):

| Verb used in card | In ACTION_VERBS? | Mapped field |
|-------------------|-------------------|--------------|
| observer | YES | observation |
| ecouter | YES | perception |
| tenter sa chance | YES | chance |
| s'approcher | YES | esprit |
| suivre | YES | perception |
| attendre | YES | esprit |
| examiner | YES | observation |
| se cacher | YES | finesse |
| resister physiquement | YES | vigueur |
| fouiller a l'aveugle | YES | chance |
| escalader | YES | finesse |
| parler | YES | esprit |
| avancer | NO (fallback to esprit) | esprit |
| dechiffrer | YES | logique |
| mediter | YES | esprit |
| negocier | YES | bluff |
| contourner | YES | finesse |
| accepter | YES | esprit |
| analyser | YES | logique |
| refuser | YES | esprit |
| decoder | YES | logique |
| cueillir | YES | chance |
| se faufiler | YES | finesse |
| apaiser | YES | esprit |
| tendre l'oreille | YES | perception |

**Minor issue**: `avancer` (used in fr_villages_001 option 3 and fr_generic_005 option 3) is not in ACTION_VERBS. It falls back to `esprit` via `ACTION_VERB_FALLBACK_FIELD`. This is acceptable behavior but could be intentionally mapped.

---

## 13. Coverage Gaps

### 13.1 Critical: Pool Size vs Target

| Metric | Current | Target (Bible) | Gap |
|--------|---------|----------------|-----|
| FastRoute narrative cards | 14 | 500+ | 486 cards missing (97%) |
| Cards per biome (avg) | 1.1 | ~60 per biome | Severely insufficient |
| Generic fallback cards | 5 | ~100 | 95 cards missing |
| Merlin Direct cards | 4 | ~50 (estimated) | 46 cards missing |

### 13.2 Biome Balance

Biomes with only 1 card each (minimum viable = ~10 for non-repetitive runs):
- landes_bruyere (1)
- cotes_sauvages (1)
- villages_celtes (1)
- cercles_pierres (1)
- marais_korrigans (1)
- collines_dolmens (1)
- iles_mystiques (1)

### 13.3 Trust Tier Coverage (Merlin Direct)

- T3 has 0 dedicated cards (players with high trust see only T0-T2 content)

### 13.4 Lexical Field Coverage in FastRoute

| Field | Verbs used | Cards with verb in this field |
|-------|------------|-------------------------------|
| chance | 3 | 4 options |
| bluff | 1 | 1 option |
| observation | 3 | 4 options |
| logique | 3 | 3 options |
| finesse | 3 | 4 options |
| vigueur | 1 | 1 option |
| esprit | 6 | 10 options |
| perception | 3 | 4 options |

**Issue**: `vigueur` and `bluff` fields have only 1 option each. `esprit` dominates with 10 options (due to being the fallback field for many calm/neutral verbs).

---

## 14. Event Card — Biome Coverage

| Biome | Biome-specific events | FastRoute + Event total |
|-------|----------------------|-------------------------|
| foret_broceliande | 1 | 3 |
| landes_bruyere | 1 | 2 |
| cotes_sauvages | 1 | 2 |
| villages_celtes | 1 | 2 |
| cercles_pierres | 1 | 2 |
| marais_korrigans | 1 | 2 |
| collines_dolmens | 1 | 2 |
| iles_mystiques | 2 | 3 |

Iles_mystiques is the only biome with 2 biome-specific events.

---

## 15. Issues Summary

| # | Severity | Issue | Affected |
|---|----------|-------|----------|
| 1 | **CRITICAL** | Pool size 18 vs 500+ target (3.6% complete) | All FastRoute |
| 2 | **HIGH** | 1 card per biome (except foret=2). Runs exhaust pool immediately | FastRoute Narrative |
| 3 | **HIGH** | `niamh` faction underrepresented: 2 narrative, 0 merlin_direct | FastRoute |
| 4 | **MEDIUM** | No T3 Merlin Direct cards | Merlin Direct |
| 5 | **MEDIUM** | `vigueur` and `bluff` lexical fields have minimal coverage (1 option each) | FastRoute Narrative |
| 6 | **LOW** | Verb `avancer` not in ACTION_VERBS (falls back to esprit) | fr_villages_001, fr_generic_005 |
| 7 | **LOW** | Effect types ADD_ANAM, ADD_BIOME_CURRENCY, UNLOCK_OGHAM unused in any card | All pools |
| 8 | **INFO** | All structural checks pass (fields, option count, effect caps, faction IDs, no duplicates) | All pools |

---

## 16. Recommendations

1. **Scale the pool to 500+ cards** (Bible target). Priority order:
   - 10+ narrative cards per biome (80 total biome-specific)
   - 30+ generic narrative cards
   - 10+ Merlin Direct cards (covering all trust tiers)

2. **Rebalance faction representation**:
   - Add `niamh`-focused cards to narrative and merlin_direct pools
   - Reduce `anciens` dominance (currently in 8/14 narrative cards)

3. **Add T3 Merlin Direct cards** for players who reach max trust.

4. **Diversify lexical fields**: Add cards with `vigueur` and `bluff` verbs to exercise combat_rituel/course and negociation minigames more frequently.

5. **Use more effect types**: `ADD_ANAM`, `ADD_BIOME_CURRENCY`, and `UNLOCK_OGHAM` are valid but never appear in card data. These add gameplay variety.

6. **Add `avancer` to ACTION_VERBS** or replace with an existing verb in the 2 cards that use it.

7. **Consider trust tier variants**: The Bible mentions "variantes par tier confiance" for FastRoute. Currently no card has tier-based variant logic in the narrative pool.

---

*End of audit.*
