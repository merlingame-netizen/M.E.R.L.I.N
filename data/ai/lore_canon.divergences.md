# Lore Canon — Code ↔ Lore Divergences

> Companion to `data/ai/lore_canon.json`. Generated 2026-06-19 from a consolidation of
> `docs/50_lore/*`, `docs/GAME_DESIGN_BIBLE.md` (v3.8), and `scripts/merlin/merlin_constants.gd`.
> When docs disagree, the **GAME_DESIGN_BIBLE v3.8** is the source of truth.

---

## 1. Rune-Circuits (9) vs Oghams (18)

- **Code says:** `merlin_constants.gd` `OGHAM_FULL_SPECS` defines **18 Oghams** (beith, luis, quert, coll, ailm, gort, eadhadh, duir, tinne, onn, nuin, huath, straif, muin, ioho, ur, ruis, saille). `OGHAM_STARTER_SKILLS = ["beith","luis","quert"]`.
- **Bible says:** `GAME_DESIGN_BIBLE.md` v3.8 §3.1 / §3.3: **9 Rune-Circuits** organised into 3 Poles (Neutre / Ordre / Chaos / Liminal). Line 15: *"Rune-Circuits | 9 (bible) | 9 confirmees (refacto Godot 18→9 a faire)"*.
- **Reconciliation:** Adopt the bible's **9 Rune-Circuits** as canon (recorded in `lore_canon.json.rune_circuits`). Refactor the 18 Oghams down to 9, keeping the 3 starters (beith/luis/quert) and folding the rest into the Ordre/Chaos/Liminal poles. Until done, code remains at 18 (legacy).

## 2. Life Drain −1/card vs "No Auto-Drain"

- **Code says:** `LIFE_ESSENCE_DRAIN_PER_CARD = 1`; `EFFECT_CAPS.drain_per_card = 1`; `EFFECT_PIPELINE[0] = "DRAIN_VIE"` (−1 PV at card start). A comment dates this to a QA v1 (2026-05-14) reversal of a prior director call.
- **Bible says:** v3.1/v3.8 §5.1 — **NO DRAIN** (Hand of Fate 2 philosophy): tension comes from limited safe choices, not time pressure. Drain de base = **0**, balance via card effects only. Bible line 1803 explicitly: *"No drain auto | LIFE_ESSENCE_DRAIN_PER_CARD = 1 | refacto a faire (constant = 0)"*.
- **Reconciliation:** Set `LIFE_ESSENCE_DRAIN_PER_CARD = 0` and `EFFECT_CAPS.drain_per_card = 0`. This is an explicitly acknowledged, pending code refactor.

## 3. Effect Pipeline — 12 steps vs 11 steps

- **Code says:** `EFFECT_PIPELINE` = **12 steps**, starting with `DRAIN_VIE`.
- **Bible says:** v3.1 §13.3 — **11 steps** (step 1 `DRAIN -1` dropped; card starts directly at display + optional Merlin comment).
- **Reconciliation:** Drop `DRAIN_VIE` from the pipeline (consequence of divergence #2). Pipeline becomes 11 steps.

## 4. Fifth Faction — `niamh` (code) vs `Humains` (lore)

- **Code says:** `FACTIONS = ["druides","anciens","korrigans","niamh","ankou"]`; `FACTION_INFO.niamh = {"name":"Niamh et Tir na nOg","symbol":"lac"}`.
- **Lore says:** `03_LES_FACTIONS.md` canonical list = **Druides, Korrigans, Humains, Anciens, Ankou** (with "humains" = mechanical labels villageois/guerriers/marchands). Bible v3.5 changelog, however, **confirms** `druides/anciens/korrigans/niamh/ankou`.
- **Reconciliation:** Bible v3.5 supersedes lore 03 — keep **`niamh`** as the 5th faction id. BUT this orphans the Humans content (Enora, Riwal, Yves, Morwenna) which has no mechanical faction. Either (a) re-skin `niamh` to absorb the human social/diplomacy theme, or (b) re-tag those NPCs under `niamh`. Currently they carry a non-code `"faction":"humains"` tag in the canon and need a design decision.

## 5. "Niamh" name collision (faction vs Ancienne vs dissolved druid)

- **Sources disagree:** `niamh` is simultaneously (1) a code **faction**, (2) **Niamh the Ancienne** (Sidhe PNJ, guardian of Tir na nOg), and (3) a **druid dissolved in the Nuin Ogham** (per `00_LORE_BIBLE_INDEX` disambiguation table).
- **Reconciliation:** Treat as three distinct entities sharing a name (cultural continuity), per the index's own ruling. The canon keeps the faction `niamh` and the NPC `niamh` (Ancienne) separate; the dissolved druid is out of NPC scope.

## 6. "Bran" — druid (lore) vs `anciens` (code biome PNJ)

- **Code says:** `BIOME_PNJ_INFO.bran = {faction:"anciens", biome:"cotes_sauvages"}` (Bran le Passeur, marchand maritime).
- **Lore says:** `03/11`: **Bran** is a **druide** guarding the coasts (ile de Sein), specialty marées/navigation.
- **Reconciliation:** Most likely **two characters** named Bran (the living druid vs. the biome merchant-ferryman). Canon keeps both: `bran_druide` (druides) + the merchant implied by the biome PNJ. Rename one to avoid confusion, or confirm they are one entity and pick a single faction.

## 7. Biome count — 8 (code) vs "Sept Biomes" (lore)

- **Code says:** `BIOME_KEYS` = **8 biomes** (adds `iles_mystiques`, maturity threshold 75).
- **Lore says:** `08_LES_BIOMES.md` titled **"LES SEPT BIOMES"** and documents 7 in depth.
- **Reconciliation:** Keep 8 biomes (code/progression-driven). Write deep lore for `iles_mystiques` to match the other seven (see Gaps).

## 8. Bible version reference — v2.4 (code/CLAUDE.md) vs v3.8 (actual)

- **Code says:** `merlin_constants.gd` comments cite "bible v2.4"; `CLAUDE.md` Project Overview/Quick Ref cite v2.4.
- **Bible says:** `docs/GAME_DESIGN_BIBLE.md` header = **v3.8** (v3.5 changelog 2026-05-16).
- **Reconciliation:** Source of truth is **v3.8**. Many constants (caps, pipeline, 18 Oghams) are v2.4-era and trail the bible; update comments/CLAUDE.md and reconcile values as the v3.x refactors land.

## 9. Trust Tier scale — score 0-100 (code) vs run-count (lore)

- **Code says:** `TRUST_TIERS` keyed by a **0-100 score** (T0 0-24, T1 25-49, T2 50-74, T3 75-100).
- **Lore says:** `04_MERLIN.md` describes T0 = runs 1-5, T1 = 6-20, T2 = 21-50, T3 = 51+ (by **run count**).
- **Reconciliation:** Canon uses the **score 0-100** thresholds for mechanics; the run-count table is a narrative pacing guide, not a separate gate. Document that both exist but only score drives interference slots.

## 10. Game-over conditions — vie=0 (code) vs vie=0 / MOS hard-max / player choice (bible)

- **Code says:** Run ends at `vie = 0`; victory needs `MIN_CARDS_FOR_VICTORY = 25`.
- **Bible says:** v3.5 — game over on **vie=0 OR MOS hard_max (50 cards) OR player choice**.
- **Reconciliation:** Add MOS hard-max and explicit player-quit as terminal conditions in code.

---

## Content GAPS

| Gap | Detail | Suggested fix |
|-----|--------|---------------|
| **iles_mystiques lore** | Only briefly named; no deep section in `08_LES_BIOMES.md` (which covers 7). | Author a full biome section (sub-locations, creatures, secrets, card seeds). |
| **Non-Broceliande NPC/event depth** | Named NPCs and the detailed bestiary (`14_BESTIAIRE_BROCELIANDE`) are overwhelmingly Broceliande-centric; the other 7 biomes usually have only 1 recurring PNJ. | Add 1-2 named NPCs + a small bestiary per biome (landes, côtes, villages, cercles, marais, collines, îles). |
| **biome-specific events** | `event_cards.json` has `seasonal`/`universal`/`whispers` populated but the `biome_specific` bucket is empty/minimal. | Write per-biome event sets keyed to each biome's pole and dominant faction. |
| **Humains faction orphaned** | Faction exists in lore 03 but not in code `FACTIONS`; its NPCs have no mechanical faction (see Divergence #4). | Design decision: merge into `niamh` or add a 6th faction (the bible says 5, so prefer merge). |
| **9 Rune-Circuits not implemented** | Bible v3.8 defines 9; code still ships 18 Oghams (Divergence #1). | Execute the 18→9 refactor in `merlin_constants.gd` and dependent systems. |
| **Endings mechanical wiring** | The 16 endings (Système 3 Aspects: Corps/Ame/Monde) exist in `09_LES_FINS.md` but the trigger mapping is not encoded in `merlin_constants.gd`. | Add an endings table mapping aspect states → ending id. |
| **Biome thematic poles** | The per-biome `pole` (Awen aspect) is synthesised from lore, not a structured constant. | Add a `pole` field to `BIOMES` if the 3-Pole system is adopted in code. |

---

*Counts (from `lore_canon.json`): factions 5 · npcs 27 · biomes 8 · rune_circuits 9 · endings 16 · events 30 · themes 10 · divergences 10 · gaps 8.*
