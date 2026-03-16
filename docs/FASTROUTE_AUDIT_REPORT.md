# FastRoute Card Pool — Comprehensive Audit Report (Wave 3-C)

> Generated: 2026-03-16 | Auditor: Claude Code | READ-ONLY audit (no card files modified)
> Source: `data/cards/*.json` (17 files) + `data/ai/*.json` (3 template files)
> Canonical reference: `scripts/merlin/merlin_constants.gd` (ACTION_VERBS, BIOMES, FACTIONS, TRUST_TIERS)

---

## 1. Pool Overview

**Total cards: 830** across 17 JSON files in `data/cards/`.
The 3 files in `data/ai/` contain template structures (0 playable cards each).

| File | Cards |
|------|-------|
| `faction_fallback_cards.json` | 20 |
| `fastroute_sprint6_cards.json` | 50 |
| `fastroute_sprint7_cards.json` | 50 |
| `fastroute_sprint9a_cards.json` | 50 |
| `fastroute_sprint9b_cards.json` | 50 |
| `fastroute_sprint10a_cards.json` | 50 |
| `fastroute_sprint10b_cards.json` | 50 |
| `fastroute_sprint10c_cards.json` | 50 |
| `fastroute_sprint11a_cards.json` | 50 |
| `fastroute_sprint11b_cards.json` | 50 |
| `fastroute_sprint11c_cards.json` | 30 |
| `fastroute_sprint14_cards.json` | 50 |
| `fastroute_sprint16_cards.json` | 50 |
| `fastroute_sprint19_cards.json` | 50 |
| `fastroute_sprint20_cards.json` | 50 |
| `fastroute_sprint21_danger.json` | 50 |
| `fastroute_sprint21b_danger.json` | 80 |
| `data/ai/event_cards.json` | 0 (templates) |
| `data/ai/promise_cards.json` | 0 (templates) |
| `data/ai/fastroute_cards.json` | 0 (templates) |

**Target (GDD v2.4): 500+ cards.** Current pool: **830 cards (166% of target).**

---

## 2. Trust Tier Distribution

| Tier | Count | % | GDD Reference |
|------|-------|---|---------------|
| T0 (cryptique, 0-24 confiance) | 663 | 79.9% | Default tier for most cards |
| T1 (indices, 25-49) | 68 | 8.2% | |
| T2 (avertissements, 50-74) | 55 | 6.6% | |
| T3 (secrets, 75-100) | 44 | 5.3% | |

**Assessment:** Heavy T0 skew is expected (T0 is the starting tier and most common play state). The higher tiers have enough cards for variety but T1/T2/T3 combined represent only 20.1% of the pool. This is acceptable given that players spend most time at T0.

---

## 3. Biome Distribution

| Biome | Count | % |
|-------|-------|---|
| foret_broceliande | 140 | 16.9% |
| collines_dolmens | 106 | 12.8% |
| marais_korrigans | 103 | 12.4% |
| cercles_pierres | 102 | 12.3% |
| iles_mystiques | 100 | 12.0% |
| landes_bruyere | 99 | 11.9% |
| villages_celtes | 95 | 11.4% |
| cotes_sauvages | 85 | 10.2% |

**Assessment:** `foret_broceliande` has ~40% more cards than `cotes_sauvages`. This makes sense since Broceliande is the starter biome (maturity_threshold=0) and the game's primary setting. All 8 biomes are well-represented (85-140 range). No biome is critically underserved.

**Lowest biome:** `cotes_sauvages` (85) could benefit from 15-20 more cards to match the average.

---

## 4. Faction Distribution

| Faction | Count | % |
|---------|-------|---|
| druides | 192 | 23.1% |
| niamh | 164 | 19.8% |
| ankou | 164 | 19.8% |
| anciens | 163 | 19.6% |
| korrigans | 147 | 17.7% |

**Assessment:** Druides are slightly overrepresented (+29 vs average 166), korrigans are slightly underrepresented (-19 vs average). The imbalance is modest (5.4% spread). Korrigans could use ~20 more cards to equalize.

---

## 5. Biome x Faction Cross-Tab

| Biome | druides | anciens | korrigans | niamh | ankou |
|-------|---------|---------|-----------|-------|-------|
| foret_broceliande | **81** | 9 | 19 | 18 | 13 |
| landes_bruyere | 27 | 20 | 16 | 14 | 22 |
| cotes_sauvages | 7 | 13 | 15 | **39** | 11 |
| villages_celtes | 19 | **32** | 23 | 7 | 14 |
| cercles_pierres | 25 | **44** | 6 | 7 | 20 |
| marais_korrigans | 10 | 5 | **56** | 12 | 20 |
| collines_dolmens | 14 | 30 | 7 | 7 | **48** |
| iles_mystiques | 9 | 10 | 5 | **60** | 16 |

**Assessment:** Strong thematic alignment visible:
- Druides dominate foret_broceliande (81 cards = 57.9% of biome)
- Korrigans dominate marais_korrigans (56 = 54.4%)
- Niamh dominates iles_mystiques (60 = 60.0%) and cotes_sauvages (39 = 45.9%)
- Ankou dominates collines_dolmens (48 = 45.3%)
- Anciens dominate cercles_pierres (44 = 43.1%) and villages_celtes (32 = 33.7%)

**Gaps:** Korrigans have only 5-6 cards in cercles_pierres and iles_mystiques. Niamh has only 7 cards each in villages_celtes, cercles_pierres, and collines_dolmens.

---

## 6. Tier x Faction

| Tier | druides | anciens | korrigans | niamh | ankou |
|------|---------|---------|-----------|-------|-------|
| T0 | 146 | 132 | 123 | 132 | 130 |
| T1 | 17 | 13 | 11 | 14 | 13 |
| T2 | 12 | 11 | 8 | 11 | 13 |
| T3 | **17** | 7 | **5** | 7 | 8 |

**Assessment:** Druides have disproportionately many T3 cards (17 vs average 8.8). Korrigans have the fewest T3 cards (5). Consider adding korrigan T3 content in future sprints.

---

## 7. Verb Analysis

### 7.1 All 52 Canonical Verbs (8 champs lexicaux)

| Champ | Verbs & Usage Count |
|-------|---------------------|
| **chance** | cueillir (31), chercher au hasard (13), tenter sa chance (47), deviner (29), fouiller a l'aveugle (28) |
| **bluff** | marchander (19), convaincre (44), mentir (17), negocier (50), charmer (30), amadouer (20) |
| **observation** | observer (71), scruter (72), memoriser (26), examiner (44), fixer (19), inspecter (29) |
| **logique** | dechiffrer (45), analyser (66), resoudre (45), decoder (33), interpreter (25), etudier (21) |
| **finesse** | se faufiler (56), esquiver (24), contourner (61), se cacher (23), escalader (34), traverser (41) |
| **vigueur** | resister physiquement (41), forcer (43), frapper (**0**), soulever (**0**), courir (44), nager (**0**) |
| **esprit** | calmer (36), apaiser (62), mediter (108), resister mentalement (60), se concentrer (63), endurer (68), parler (34), accepter (**386**), refuser (42), attendre (27), s'approcher (14) |
| **perception** | ecouter (59), suivre (32), pister (35), sentir (36), flairer (37), tendre l'oreille (28) |

### 7.2 Unused Canonical Verbs (3/52)

| Verb | Champ | Status |
|------|-------|--------|
| **frapper** | vigueur | Never used in any card |
| **soulever** | vigueur | Never used in any card |
| **nager** | vigueur | Never used in any card |

All 3 missing verbs belong to `vigueur`. This field has only 3 of its 6 verbs in active use, making it the most underserved champ lexical for verb variety.

### 7.3 Non-Canonical Verbs (3 verbs, 172 uses)

| Verb | Count | Note |
|------|-------|------|
| **fuir** | 79 | Not in ACTION_VERBS. Could map to finesse or esprit |
| **combattre** | 61 | Not in ACTION_VERBS. Could map to vigueur |
| **pousser** | 32 | Not in ACTION_VERBS. Could map to vigueur |

**Impact:** 172 option uses (6.9% of 2490 total) reference verbs not in the canonical 52-verb list. The LLM adapter fallback maps unknown verbs to "esprit", which means these options always trigger esprit minigames regardless of narrative intent.

**Recommendation:** Either add `fuir`, `combattre`, `pousser` to `ACTION_VERBS` in `merlin_constants.gd`, or replace them in the card files with canonical equivalents.

### 7.4 Verb Imbalance: `accepter`

The verb `accepter` appears **386 times** (15.5% of all verb uses), making it the most used verb by a factor of 3.5x over the next (mediter: 108). This creates minigame monotony in the `esprit` field.

**Recommendation:** Redistribute some `accepter` uses to other esprit verbs (calmer, apaiser, refuser, attendre, s'approcher).

---

## 8. Champ Lexical Distribution

| Champ | Cards | % |
|-------|-------|---|
| esprit | 310 | 37.3% |
| logique | 90 | 10.8% |
| perception | 88 | 10.6% |
| observation | 82 | 9.9% |
| vigueur | 81 | 9.8% |
| finesse | 68 | 8.2% |
| bluff | 63 | 7.6% |
| chance | 48 | 5.8% |

**Assessment:** `esprit` is heavily overrepresented (37.3%), nearly 4x the next field. This correlates with the `accepter` verb dominance. The other 7 fields are relatively balanced (5.8%-10.8%).

**Verb-champ alignment:** 85% of options use a verb matching the card's declared champ_lexical. The 15% cross-field usage is intentional (cards can use verbs from other fields for narrative variety).

---

## 9. Structural Quality

| Check | Result |
|-------|--------|
| All cards have 3 options | 830/830 (100%) |
| All cards have tags | 830/830 (100%) |
| No empty tag arrays | 830/830 (100%) |
| No duplicate IDs | 0 duplicates found |
| No similar text starts | 0 groups found |
| All cards have biome | 830/830 (100%) |
| All cards have faction | 830/830 (100%) |
| All cards have trust_tier | 830/830 (100%) |

**Structural integrity is excellent.** No missing fields, no duplicates, consistent 3-option format throughout.

---

## 10. Effect Type Usage

| Effect Type | Count | Notes |
|-------------|-------|-------|
| ADD_REPUTATION | 2811 | Core system, expected to dominate |
| DAMAGE_LIFE | 927 | Present in many options |
| HEAL_LIFE | 531 | |
| ADD_ANAM | 472 | Cross-run currency |
| ADD_BIOME_CURRENCY | 351 | Biome-specific currency |
| ADD_KARMA | 57 | **Not in GDD v2.4** — possibly vestigial |
| UNLOCK_OGHAM | 26 | Rare, appropriate for high-value choices |
| ADD_PROMISE | 8 | Promise system integration |

**Flag:** `ADD_KARMA` (57 uses) does not appear in the GDD v2.4 effect types or in `merlin_effect_engine.gd` constants. This may be a removed/renamed system that needs cleanup.

---

## 11. Removed Systems References

**34 cards reference removed/deprecated systems** in their narrative text or tags:

| System | Cards Referencing | Severity |
|--------|-------------------|----------|
| souffle | 27 cards | MEDIUM — narrative mentions only, no gameplay impact |
| flux | 4 cards | LOW — narrative mentions only |
| triade | 1 card | LOW |
| jauge | 1 card | LOW |

**Full list of affected cards:**

- `souffle` (27): faction_druides_002, fr_s10a_landes_001, fr_s10a_landes_004, fr_s10a_marais_002, fr_s10a_iles_004, fr_s10b_conflict_015, fr_s10c_unlock_huath_001, fr_s11a_samhain_003, fr_s11a_beltane_009, fr_s11c_revelation_009, s14_ogham_01, s14_endgame_16, s16_biome_50, s19_verb_04 (flux), s19_verb_40, s19_verb_50, s20_danger_01, s20_danger_12, s20_danger_15, s20_danger_34 (flux), FR_S21B_002, FR_S21B_007, FR_S21B_048 (flux), FR_S21B_051, FR_S21B_074 (flux), FR_S21D_015, FR_S21D_020, fr_s7_merlin_t1_003, fr_s7_event_tempete_005, fr_s7_biome_marais_002, fr_s9a_korrigans_recit_007, fr_s9a_ankou_origin_001
- `triade`: fr_s10c_ogham_lore_005
- `jauge`: faction_druides_002

**Note:** These are narrative text references (e.g., "le souffle du monde"), not gameplay mechanic invocations. The word "souffle" appears naturally in Celtic fantasy prose. Only `jauge` and `triade` are unambiguously system references that should be reviewed.

---

## 12. Summary of Findings

### Strengths
1. **Pool size exceeds target**: 830 cards vs 500+ target (166%)
2. **Perfect structural integrity**: 100% compliance on all required fields, 3 options per card, no duplicates
3. **Good biome coverage**: All 8 biomes represented (85-140 range)
4. **Good faction coverage**: All 5 factions represented (147-192 range)
5. **Strong thematic alignment**: Faction-biome pairings match lore expectations
6. **Tag quality**: Every card has meaningful tags (1055 unique tags across pool)

### Issues to Address

| Priority | Issue | Impact | Recommendation |
|----------|-------|--------|----------------|
| **HIGH** | 3 canonical verbs never used (frapper, soulever, nager) | Vigueur minigame variety reduced | Add cards using these verbs |
| **HIGH** | `accepter` used 386 times (15.5%) | Esprit minigame monotony | Redistribute to other esprit verbs |
| **MEDIUM** | 3 non-canonical verbs (fuir, combattre, pousser = 172 uses) | Always fallback to esprit minigame | Add to ACTION_VERBS or replace in cards |
| **MEDIUM** | `esprit` champ = 37.3% of cards | Minigame type imbalance | Generate more chance/bluff/finesse cards |
| **MEDIUM** | `ADD_KARMA` effect type (57 uses) | Possibly vestigial system | Verify in effect engine, remove or document |
| **LOW** | Korrigans slightly underserved (147 vs avg 166) | Minor faction imbalance | Add ~20 korrigan cards |
| **LOW** | Korrigans have only 5 T3 cards | Limits late-game variety | Add korrigan T3 content |
| **LOW** | 34 cards mention removed systems in prose | Narrative inconsistency | Review and reword where "souffle"/"flux" refer to game mechanics |
| **INFO** | cotes_sauvages has fewest cards (85) | Minor biome imbalance | Add ~15 cards if needed |
| **INFO** | `data/ai/*.json` template files contain 0 playable cards | No impact (templates for LLM generation) | Expected behavior |

---

*Audit script: `tools/audit_cards.js` | Data source: `data/cards/POOL_SUMMARY.json` cross-verified*
