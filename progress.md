# Progress Log - M.E.R.L.I.N.: Le Jeu des Oghams

> **Note**: Sessions anterieures archivees dans `archive/progress_archive_2026-02-05_to_2026-02-08.md`

## Session: 2026-02-28 (night cont.7) — Overnight QA: FIX 49-50 (Arc Prefix + Screenplay Strip)

### Context
Continuation of overnight QA. Previous session committed FIX 46-48.
This session runs MC30-32 (15 cards) and implements FIX 49-50.

### Fixes Applied
- **FIX 49**: Arc prefix regex `\d+` now `\d*` (optional) to catch "Scene :" without number; added "séance" to prefix keywords; "saison spring/summer/autumn/winter" + "séance:" meta_words
- **FIX 50**: Strip screenplay format headers (`INT./EXT. LOCATION - TIME`); added "cette scène", "the scene is" meta_words

### Results (MC30-32, 15 cards)
| Metric | MC30 (FIX 48) | MC31 (FIX 49) | MC32 (FIX 49) |
|--------|--------------|---------------|---------------|
| 2nd person "tu" | 4/5 (80%) | **5/5 (100%)** | 3/5 (60%) |
| Action verb labels | **15/15 (100%)** | 14/15 (93%) | 14/15 (93%) |
| No meta-text leaks | 4/5 (80%) | **5/5 (100%)** | 3/5 (60%) |

### Key Findings
- **MC30 Card 2**: "Scene : Le Jardin de Brocéliande - Saison Spring Séance: 1" — arc prefix regex required `\d+` → FIX 49 makes `\d*` optional
- **MC31**: PERFECT CYCLE — 0 meta leaks, 100% 2nd person, 93% valid labels. FIX 47-49 combination highly effective
- **MC32 Cards 2-3**: NEW issue — **Screenplay format** "INT. FORET BROCELIANDE - LE MATIN" + **full English text**. LLM fell into screenplay/English mode → FIX 50 strips INT./EXT. headers
- **English text**: Cannot fix by post-processing (would need translation). This is a prompt-level/LoRA issue
- **Invented words persistent**: "Reniser", "Rendesteur", "s'enchevient", "heliophoniques" — model-level
- FPS 41-58, lower on MC32 (LLM CPU load)

### Cumulative Quality Trend (MC19-MC32, 70 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 | MC25 | MC26 | MC27 | MC28 | MC29 | MC30 | MC31 | MC32 |
|--------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% | 60% | 80% | 80% | 80% | 80% | 80% | **100%** | 60% |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% | 80% | 47% | 87% | **100%** | 87% | **100%** | 93% | 93% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% | 80% | 80% | 80% | **40%** | 80% | 80% | **100%** | 60% |

### Commits
- `21280fb` — fix(cards): FIX 49 — arc prefix regex handles "Scene :" without number
- `2fc9a91` — fix(cards): FIX 50 — strip screenplay headers (INT./EXT.)

---

## Session: 2026-02-28 (night cont.6) — Overnight QA: FIX 46-48 (Sentence-Strip + Meta Patterns)

### Context
Continuation of overnight QA. Previous session committed FIX 43-45.
This session runs MC27-29 (15 cards) and implements FIX 46-48.

### Fixes Applied
- **FIX 46**: Add "la complication est", "causée par" meta patterns; strip backslash-prefixed lines
- **FIX 47** (MAJOR): **Sentence-level fallback stripping** — root cause of persistent meta leaks found: when meta text + narrative on ONE line (no \n), line-stripper removes everything, result < 10 chars, guard falls back to original text. Now falls back to sentence-level strip. Also adds "voici la suggestion", "→ choix:" arrow template strip
- **FIX 48**: Add "phrase finale", "a/", "b/", "c/" meta patterns; expand noun blocklist (facette, amour, silence, ombre, sentier)

### Results (MC27-29, 15 cards)
| Metric | MC27 (FIX 45) | MC28 (FIX 46) | MC29 (FIX 47) |
|--------|--------------|---------------|---------------|
| 2nd person "tu" | 4/5 (80%) | 4/5 (80%) | 4/5 (80%) |
| Action verb labels | 13/15 (87%) | 15/15 (**100%**) | 13/15 (87%) |
| No meta-text leaks | 4/5 (80%) | 2/5 (**40%**) | 4/5 (80%) |

### Key Findings
- **MC27 Card 5**: "\ La complication est causée par" — backslash + narrative structure leak → FIX 46
- **MC28 Cards 2,3,5**: 3 meta leaks including "Voici la suggestion du scenario" and "Voici ta carte ambiante pour le jour 1" — FIX 44 patterns matched but line-strip removed ALL text (single-line), guard fell back to original → **ROOT CAUSE found** → FIX 47 sentence-strip
- **MC28 Card 5**: "→ choix: DECHIFFRER" template arrow leaked → FIX 47 regex strip
- **MC29 Card 2**: "Phrase finale: A/" option labeling leaked → FIX 48
- **MC29 Cards 3,5**: Noun labels "Facette" and "L'amour" → FIX 48 blocklist expansion
- FPS stable 46-58 throughout

### Cumulative Quality Trend (MC19-MC29, 55 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 | MC25 | MC26 | MC27 | MC28 | MC29 |
|--------|------|------|------|------|------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% | 60% | 80% | 80% | 80% | 80% |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% | 80% | 47% | 87% | **100%** | 87% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% | 80% | 80% | 80% | **40%** | 80% |

### Commits
- `c00cfa7` — fix(cards): FIX 46 — narrative structure leak + backslash strip
- `c84b9ef` — fix(cards): FIX 47 — sentence-level fallback strip + new meta patterns
- `34184a5` — fix(cards): FIX 48 — "phrase finale" meta + noun blocklist expansion

---

## Session: 2026-02-28 (night cont.4) — Overnight QA: FIX 43 (Identity Leak + Truncated Labels)

### Context
Continuation of overnight QA. Previous session committed FIX 40-42 (commit 58ff95c).
This session runs MEGA-CYCLE 24 (5 cards) and implements FIX 43.

### Fixes Applied
- **FIX 43**: Identity leak "tu es merlin" added to meta_words (both files); reject labels ending with dash ("Vise-")

### Results (MC24, 5 cards — FIX 41-42 active)
| Metric | MC24 |
|--------|------|
| 2nd person "tu" | 4/5 (80%) |
| Action verb labels | 14/15 (93%) — "Vise-" truncated |
| No meta-text leaks | 4/5 (80%) — identity leak Card 2 |
| Opening variety | 5/5 (100%) |
| FPS avg | 45-57 |

### MC24 Card-by-Card
| Card | Title | Person | Labels | Issues |
|------|-------|--------|--------|--------|
| 1 | Le Désespoir au Rêve-Dieu Crissant | 2nd | Répondre/Grimper/Renifler | Clean |
| 2 | Voyage nocturne dans la Forêt du Ciel | 2nd | Secourir/Marchander/Forcer | Identity leak "Tu es Merlin", "tu traversons" |
| 3 | Clairveine: L'Ombres Échappent à la Merveilleinte | 3rd | Enraciner/Déchiffrer/Frapper | Hallucinated words |
| 4 | Le Serpent Pierré: Source de Passeurs Celts | 2nd | Plonger/**Vise-**/Secourir | Truncated label |
| 5 | Tombée du char des voix lointaines | 2nd | Frapper/Pardonner/Aider | Clean, FIX 40 confirmed |

### Key Findings
- **FIX 40 re-confirmed**: Card 5 "Tu as entendu" (correct conversion)
- **FIX 41-42 working**: No VERBE/FORCE leaks, no "n'ai" errors
- **New identity leak**: "Tu es Merlin l'Enchanteur" — LLM assigns Merlin identity to player → FIX 43
- **Truncated label "Vise-"**: Dash-ending label not caught → FIX 43
- **Aspects moving**: Ame 0→1→0, Monde 0→1 (effects engine working)
- **Remaining model-level issues**: "tu traversons" conjugation, hallucinated words, 3rd person (20%)

### Cumulative Quality Trend (MC19-MC24, 30 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 |
|--------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% |

### Commits
- `b627918` — fix(cards): FIX 43 — identity leak + truncated label

---

## Session: 2026-02-28 (night cont.3) — Overnight QA: FIX 40-42 (Conjugation + Meta-text)

### Context
Continuation of overnight QA. Previous session committed FIX 34-39 (commit 314d540).
This session implements FIX 40-42 and runs MEGA-CYCLES 22-23 (10 cards total).

### Fixes Applied
- **FIX 40**: j'ai→tu as conversion (prevents broken "t'ai" artifact). Also j'avais/j'étais/j'aurai
- **FIX 41**: Strip "VERBE:", "B/C)", "FORCE" prompt structure leaks; block "verbe","force","option" labels
- **FIX 42**: Fix avoir conjugation after je→tu: "tu n'ai" → "tu n'as"

### Results (MC22-23, 10 cards)
| Metric | MC22 (FIX 38-39) | MC23 (FIX 40) |
|--------|-----------------|---------------|
| 2nd person "tu" | 4/5 (80%) | 3/5 (60%) |
| Action verb labels | **15/15 (100%)** | 13/15 (87%) |
| No meta-text leaks | **5/5 (100%)** | 3/5 (60%) |
| Opening variety | 5/5 (100%) | 5/5 (100%) |

### Key Findings
- **FIX 40 confirmed**: MC23 Card 1 "Tu as entendu" (was broken "t'ai entendu" in MC22)
- **Labels near-perfect**: MC22 achieved 100% valid verb labels
- **New meta-text patterns**: "VERBE : DÉGAINER", "B/C)", "FORCE" — fixed by FIX 41
- **Conjugation gap**: "je n'ai" → "tu n'ai" (not "tu n'as") — fixed by FIX 42
- **Remaining model-level issues**: 3rd person (40%), invented words, grammar errors

### Commits
- `50afd57` — fix(cards): FIX 40 — j'ai→tu as
- `58ff95c` — fix(cards): FIX 41-42 — VERBE: meta-text + n'ai→n'as

---

## Session: 2026-02-28 (night cont.2) — Overnight QA: FIX 34-39 (Labels + Meta-text + Hooks)

### Context
Continuation of overnight QA. Previous session committed FIX 28-33 (commit 0d9951e).
This session implements FIX 34-39 and runs MEGA-CYCLES 20-21 (10 cards total).

### Fixes Applied
- **FIX 34**: Label dedup — seen dictionary + fallback verb pool (14 verbs)
- **FIX 35**: Opening hook rotation — 10 hooks ("Tu decouvres/entends/sens/...") indexed by cards_played
- **FIX 36**: Arc prefix strip — "Complication:", "Climax:", "Resolution:", etc. structural markers
- **FIX 37**: Label sanitization — reject nouns, too-short, punctuation artifacts, common nouns blocklist
- **FIX 38**: Meta-text patterns — "sert de catalyseur", "complication suivante", narrative structure leaks
- **FIX 39**: Pronoun-suffixed labels — reject "-tu", "-moi", "-toi", "-nous", "-vous" suffixes

### Results (MC19-21, 15 cards)
| Metric | MC19 (FIX 33) | MC20 (FIX 34-36) | MC21 (FIX 37) |
|--------|--------------|-----------------|---------------|
| 2nd person "tu" | 5/5 (100%) | 3/5 (60%) | 2/5 (40%) |
| Action verb labels | 5/5 (100%) | 12/15 (80%) | 14/15 (93%) |
| No meta-text leaks | 5/5 (100%) | 4/5 (80%) | 3/5 (60%) |
| Opening variety | 2/5 (40%) | 5/5 (100%) | 5/5 (100%) |

### Key Findings
- **FIX 35 confirmed**: Opening variety went from 40% to 100% — no more "Tu marches" repetition
- **FIX 37 confirmed**: Label quality improved — MC21 had 14/15 valid verbs vs MC20's 12/15
- **3rd person issue**: 40-60% of cards still use 3rd person impersonal (model-level, needs LoRA)
- **New meta-text pattern**: "sert de catalyseur a la complication suivante" — fixed by FIX 38
- **Pronoun labels**: "Apaiset-tu" corruption — fixed by FIX 39

### Commits
- `b9011fb` — fix(cards): FIX 34-36 — label dedup, opening hooks, arc prefix strip
- `314d540` — fix(cards): FIX 37-39 — label sanitization, meta-text patterns, pronoun labels

---

## Session: 2026-02-28 (night cont.) — Overnight QA: FIX 28-33 (TransitionBiome + Controller)

### Context
Continuation of overnight QA mode. Previous session committed FIX 15-27 (commit 4168188).
This session implements FIX 28-33 and runs MEGA-CYCLES 16-19 (18 cards total).

### Fixes Applied
- **FIX 28**: Label suffix validation (ANT/IQUE/TION/MENT/ENCE/ISTE), merged apostrophe detection
- **FIX 29**: Sensory prompt rewrite ("Decris ce que tu SENS: odeurs, sons, toucher, lumiere") — BIGGEST breakthrough
- **FIX 30**: 1st→2nd person conversion (je→tu, mes→tes, mon→ton, m'→t', moi→toi)
- **FIX 31**: vous→tu conversion (vous avez→tu as, votre→ton, vos→tes), meta "Voici une description"
- **FIX 32**: Strip "Etape N:", "Scene N -", "Bienvenue dans", "ce voyageur" patterns
- **FIX 33**: Live card post-processing in merlin_game_controller.gd — mirrors TransitionBiome pipeline, ALL 6 display paths

### Results (MC16-19, 18 cards)
| Metric | Before (MC12) | MC16-18 (prerun) | MC19 (live, FIX 33) |
|--------|-------------|-----------------|---------------------|
| 2nd person "tu" | 0/5 (0%) | 8/13 (62%) | **5/5 (100%)** |
| Action verb labels | 3/5 (60%) | 13/13 (100%) | 5/5 (100%) |
| No "je suis Merlin" | 1/5 (20%) | 13/13 (100%) | 5/5 (100%) |
| Sensory content | 0/5 (0%) | 10/13 (77%) | 4/5 (80%) |
| Meta-text leaks | 3/5 (60%) | 2/13 (15%) | **0/5 (0%)** |

### Key Insight (RESOLVED)
TransitionBiome post-processing only applied to PRERUN cards. FIX 33 adds
_post_process_card_text() to merlin_game_controller.gd with the same pipeline
(meta strip + person convert), applied before ALL 6 ui.display_card() call sites.
MC19 confirmed 100% "tu" form and 0% meta leaks on live-generated cards.

### Remaining Issues (LoRA-level)
- LLM repetition: 3/5 MC19 cards use near-identical template ("Tu marches dans la foret...")
- Invented words: "soleilier", "Celtaux", "Gelelcir" (Qwen 2.5-1.5B limitations)
- Gender mismatch: "ton mission" instead of "ta mission" (regex can't detect gender)
- Duplicate labels: Card 2 MC19 had "Secourir/Secourir/Marchander"

### Commits
- `77d2a46` — fix(prerun): FIX 28-31
- `56c7ba2` — fix(prerun): FIX 32
- `0d9951e` — fix(controller): FIX 33 — live card post-processing

---

## Session: 2026-02-28 — Cible IPSOS: PowerBI model.bim Alignment (10 fixes)

### Context
Comparison of `model.bim` M expressions vs `run_full_pipeline.py` (aligned with notebook reference). 10 critical divergences identified and corrected in model.bim.

### Fixes Applied to model.bim

**HIGH PRIORITY (affect row count):**
1. **Q8 VAGUE threshold**: `> 202003` → `> 202203` (match notebook Cell 149)
2. **T3→T4 BDD ordering**: Moved BDD exclusion from T3 (before ciblage) to T4 (after ciblage, match notebook)
3. **T2 role filter**: Added `Decid=1 OR Admin=1 OR repprod=1 OR repsav=1` (match notebook Cell 65)
4. **T2 phone filter**: Added `Telephone <> null OR Mobile <> null` (match notebook Cell 79)
5. **T4 Direction filter**: Changed `<> null` to `Contains("Dir") OR AE CARAIBES/REUNION` (match notebook Cell 118)
6. **T4 sort removed**: Removed `Table.Sort(Date_maj_contact DESC)` — notebook uses plain drop_duplicates

**MEDIUM PRIORITY (affect column values):**
7. **T7 Code Marche**: Replaced `StartsWith("HdM")/Contains("HDM")` with MdM list lookup (SPES → HAUT now correct)
8. **T8 Perimetre**: `"DEF"` → `"DEF PRO PME"` (PP Car/Reu, match notebook + Volume PP KPI)
9. **T8 Code Marche**: `"MILIEU DE MARCHE"` → `"BAS DE MARCHE"` (match notebook)
10. **T6 Segment**: `"MdM Marchand"` → `PROPME CARAIBES/REUNION` by direction (match notebook)

### Verification
- JSON validation: OK (23 tables, valid structure)
- All 12 automated checks: PASS
- model.bim now aligned with run_full_pipeline.py and notebook reference

### Files Modified
- `Cible_IPSOS_V1_Files.SemanticModel/definition/model.bim` — 10 M expression corrections

---

## Session: 2026-02-27 — Cible IPSOS T4 2025: BDD Quarterly Blacklist Fix

### Context
Pipeline `run_full_pipeline.py` produced +2,149 rows vs reference (52,348 vs 50,205). Root cause identified and fixed in Q8 BDD blacklist loading.

### Root Cause Identified
The notebook's `Prepa_cible.ipynb` (Cell 142-155) loads TWO BDD sources:
1. **BDD_Full.xlsx** filtered to Definitive + VAGUE > 202203 → 6,326 unique contacts
2. **Quarterly consolidated BDD** (`BDD_FIN_TERRAIN_T2_2025.xlsx` at root) → ALL Definitive, no VAGUE filter → 9,061 entries
3. Combined: 29,873 rows (exclu) → unique Contact IDs used for exclusion

The pipeline was only loading BDD_Full.xlsx (6,326 contacts). The quarterly consolidated file at root level had 308k rows spanning all historical vagues — it's no longer at root level (reorganized into subdirectories).

### Fix Applied
Modified Q8 to load quarterly BDD files from subdirectories (up to T3 2025) + BDD_Full. T3 2025 file serves as proxy for old-vague contacts from the gone consolidated file.

### Results
| Config | DEF gap | Total gap |
|--------|---------|-----------|
| BDD_Full only (before) | +2,143 | +2,149 |
| + All 36 quarterly files | -1,122 | -1,122 |
| + Quarterly up to T3 2025 | **-351** | **-351** |

- PP segments: 19,300 = 19,300 (exact match)
- ID overlap: 91.7% (ENT only, PP fully matched)
- Remaining -351 gap (0.7%) due to T3 2025 proxy not exactly matching old-vague contacts

### Files Modified
- `App_Cible_IPSOS_v2/scripts/run_full_pipeline.py` — Q8 rewritten with Q8a (BDD_Full) + Q8b (quarterly files), diagnostic pre-dedup save removed

## Session: 2026-02-28 (Night) — Overnight QA: TransitionBiome Prerun Pipeline (FIX 15-27)

### Context
Continued overnight QA focusing on TransitionBiome → MerlinGame prerun card pipeline.
5 MEGA-CYCLES (MC10-14), 25+ cards played through TransitionBiome flow.

### Fixes Applied

**FIX 15** — Prerun cards now include SHIFT_ASPECT effects rotating across Corps/Ame/Monde.
Added title, biome, season, visual_tags, audio_tags to card structure.

**FIX 16** — TransitionBiome cards generated via `_generate_prerun_card()` → `_try_llm_prerun_card()`.
Arc-based prompts (intro/exploration/complication/climax/twist).

**FIX 17** — Incremental save to `user://temp_run_cards.json` after each card (not all 5 at end).
Controller loads cards progressively. Added debug logging.

**FIX 18** — Markdown bold `**...**` stripping in narrative text.

**FIX 19** — Wait timeout for card buffer increased. Simplified LLM prompt.

**FIX 20** — 5 rotating fallback label triplets to avoid repetition across cards.

**FIX 21** — Prompt rewritten: 2e personne (tu), no "Je suis Merlin" self-introduction.

**FIX 22** — Label extraction regex: captures A)/B)/C), A-/B-/C-, 1//2//3/, §, Action A).
Inline option stripping from narrative. Label safety net: reject articles, pronouns, meta-text.

**FIX 23** — Always use arc titles ("L'Eveil du Sentier", "Echos dans la Brume", etc.).
Expanded meta_words list (30+ patterns: "je suis merlin", "trois options", etc.).

**FIX 24** — Added "voici une introduction", "voici ta reponse", "je suis pret" to meta_words.

**FIX 25** — Extended option stripping regex from [1-3] to [1-9]. Added dash-dialogue stripping.

**FIX 26** — Added "tu as choisi", "avec une voix", "ensemble nous formons" to meta_words.
Paragraph-inline option stripping (not just line-start). Apostrophe handling in label safety.
Prompt hardened with explicit "INTERDIT: je suis, meta-commentaire".

**FIX 27** — Changed system prompt example to different biome (prevents LLM copying it verbatim).
Added § marker stripping, (tu) fragment removal. Label regex extended to A-D, 1-4.

### Verified Results (MEGA-CYCLES 10-14, 25+ cards)
- **"Je suis Merlin"**: ELIMINATED — 0/5 in MC13, 0/3 in MC14 (was 3/5 in MC10)
- **Arc titles**: 5/5 consistent across all cycles
- **SHIFT_ASPECT**: Working — Ame/Corps shift confirmed every cycle
- **PROGRESS_MISSION**: Working — increments each card
- **Inline options in text**: Mostly stripped (line-start 100%, paragraph-inline ~80%)
- **Prompt example copying**: ELIMINATED (FIX 27 — different biome example)
- **Meta-text stripping**: 30+ patterns caught, ~80% effective
- **FPS**: 52-58 stable during gameplay
- **Prerun pipeline**: 5 cards generated in ~60-70s during TransitionBiome

### Remaining Issues (model-level, need LoRA)
- **Content quality**: LLM produces encyclopedic/meta descriptions instead of immersive fantasy narration
- **Geography errors**: "Nord-Ouest d'Angleterre", "Pays-Bas" (wrong — Brocéliande is in Brittany)
- **Mixed register**: tu/vous inconsistency in same card
- **Label quality**: LLM sometimes outputs non-verb labels ("Prise", "Voyageant", "Lhisterique")
- **Self-help text**: Card 3 sometimes produces therapeutic advice instead of fantasy

### Files Modified
- `scripts/TransitionBiome.gd` — FIX 15-27 (prerun pipeline, prompt, stripping, labels)
- `scripts/ui/merlin_game_controller.gd` — FIX 17 (prerun loading debug logs)

---

## Session: 2026-02-27 (Night) — Overnight LLM QA: SHIFT_ASPECT + Minigame + Repair

### Fixes Applied (commits `5ef39e4`, `78a4cba`)

**FIX 6c** — `_validate_triade_effect` converted SHIFT_ASPECT to HEAL_LIFE. Added SHIFT_ASPECT/SET_ASPECT to TRIADE_EFFECT_TYPES whitelist. Fixed validation to pass through.

**FIX 6d** — GM brain effects (HEAL_LIFE/ADD_KARMA/ADD_SOUFFLE) completely overwrote SHIFT_ASPECT at line 506. Changed to MERGE: keep SHIFT_ASPECT from contextual effects, add GM balance effects alongside. Added SHIFT_ASPECT to GM prompt vocabulary and parser.

**FIX 7** — Minigame triggered on EVERY card (30s timeout). Two bugs: (1) `_detect_minigame` threshold too low (1 keyword hit), raised to 2; (2) `str(Dict)` check always non-empty, fixed type check for Dict vs String.

**FIX 8** — Verb repair prompt produced meta-text ("Bien sur! Voici..."). Changed to pure completion format with 2 few-shot examples. T 0.3→0.2, max_tokens 30→20.

### Verified Results (MEGA-CYCLES 5-7, 13 cards played)
- **SHIFT_ASPECT**: Working end-to-end. Aspects shift 0/0/0 → 1/1/1 → rebalancing confirmed
- **Balance-aware direction**: Corps=1 → "down", Corps=0 → "up" (adaptive)
- **GM merge**: SHIFT_ASPECT + GM effects coexist on each option
- **No minigame timeouts**: Card resolution 35s → 2s
- **Card gen time**: ~50s standalone (no buffer)

### Remaining Issues (for next session)
- **Repair call** still produces meta-text ~50% of time (Qwen 2.5-1.5B limitation)
- **Fallback verbs** (21 triplets) used when repair fails — acceptable quality
- **Card gen latency** ~50s standalone — acceptable (3-5s with TransitionBiome prerun)
- **Titles**: sometimes over-creative ("Forest Poem: Evasion Au Coeur D'un Vieux Larsen") — cosmetic
- **Text truncation**: occasional mid-sentence cut ("pour ce que cette") — length cap issue

## Session: 2026-02-27 (Night cont.) — GM JSON + Dedup + Label Safety

### Fixes Applied (commit `52fe5e8`)

**FIX 9** — Removed 3 leftover debug prints ([LLM-Adapter] prefix) from merlin_llm_adapter.gd

**FIX 10** — GM brain JSON parse failures (was ~30%):
- max_tokens 80→150 (valid 3-effect JSON needs ~120 chars, was truncating)
- JSON repair: single quotes → double quotes, trailing commas, truncated JSON recovery
- Example-driven system prompt (Qwen 2.5-1.5B responds better to examples than instructions)

**FIX 12** — New meta-text strip patterns: "décrochez le choix", "tendres choix", "(a/b/c)"

**FIX 13** — Verb pool and narrative fallback dedup: avoid consecutive repeats across cards. Track `_last_verb_pool_idx` and `_last_narrative_fallback_idx`.

**FIX 14** — Label safety net at option builder level: reject verbs <3 chars, articles ("La"), possessives ("Votre") that slip through extraction — fallback to verb pool.

### Verified Results (MEGA-CYCLES 7-8, 8 cards played)
- **GM JSON parse**: 0 errors across 8 cards (was ~30% failure rate)
- **SHIFT_ASPECT**: Still working — Ame 0→1, Monde 0→1 confirmed
- **Verb variety**: No consecutive repeats (Préciser/Escalader/Déchiffrer, then Chercher/Lire/Désarmer)
- **No minigame timeouts**: All cards resolve in <5s
- **FPS**: 44-57 range (stable)
- **Balance-aware GM**: HEAL_LIFE when player low, DAMAGE_LIFE when stable

---

## Session: 2026-02-27 — 7h Polish + Integration + P1 Validation

### MC1: Housekeeping (commits `1753be6`, `abf3222`)
- 10 studio agents committed (playtester_ai, balance_analyst, visual_qa, etc.)
- VS Code extension v6.0 (6 sidebar panels)
- LoRA training pipeline + game control scripts

### MC2: Quick Wins (commit `1db1b61`)
- **trust_merlin wired**: RelationshipRegistry.trust_points injecte dans context LLM (etait hardcode a 0)
- **reveal_one/reveal_all skills**: affiche effets des options en overlay (etait `pass`)
- **pause menu**: overlay CRT-styled avec Resume/Quitter (process_mode ALWAYS)

### MC3: TransitionBiome T.3-T.4 (commit `e82b9d7`)
- T.1 (scouts biome-colores) et T.2 (SFX ambiant) deja implementes
- **T.3**: scale pulse titre biome (1.0-1.05-1.0 via Tween)
- **T.4**: biome_dissolve SFX burst (noise + D Dorian plucks)

### MC4: Souffle Perks (commit `719e06c`)
- **bouclier**: absorbe premier SHIFT_ASPECT negatif (flag souffle_shield_active consomme)
- **vision**: auto-reveal effets options sur la prochaine carte (flag souffle_vision_active consomme)
- **surge/canalisation**: deja fonctionnels (DC bonus seul / activation ogham)
- Script capture_baselines.ps1 pour Visual QA

### MC5: P1.11.2 Validation E2E
- 5/6 systemes P1 valides (pipeline, profiling, arcs, danger, RAG v2.1)
- Visual/Audio tags: design only — future Phase C/D
- Flow order: 8/8 scenes PASS
- Smoke test: 20/20 scenes PASS
- Editor Parse Check: 0 errors, 0 warnings

### MC6: Data Bootstrap
- `playtest_log.json` (1 session baseline EXPLORER)
- `balance_report.json` (initial metrics, INSUFFICIENT_DATA)
- `regression_log.json` (snapshot post-MC5: FPS 46.2, 0 errors, 20/20 scenes)

### MC7: Final Validation
- validate.bat Step 0: PASS (0 errors, 0 warnings)
- 4 commits this session (1753be6, abf3222, 1db1b61, e82b9d7, 719e06c)
- Git clean: all tracked changes committed

---

## Session: 2026-02-25 — SFX Rework + UX Enrichissement Hub/Transition

### SFX System — 9 sons + méthode ajoutés (commit `4415047`)

**SFXManager.gd** — 9 nouveaux sons procéduraux + méthode `play_ui_click()`:
- `play_ui_click()` — alias typewriter blip (fix MerlinBubble silent fail — `has_method` ne trouvait pas)
- `camera_focus` — clic obturateur + shimmer cristallin (Phase 3 TransitionBiome)
- `souffle_regen` / `souffle_full` — sons Souffle (fix merlin_game_ui calls silencieux)
- `error` — buzz dissonant doux (fix merlin_game_ui calls silencieux)
- `hub_enter` — souffle atmosphérique chaud (entrée Hub Antre)
- `perk_confirm` — accord pentatonique ogham (confirmation perk B.1)
- `biome_reveal` — révélation atmosphérique profonde (Phase 4 horloge solaire)
- `partir_fanfare` — arpège majeur ascendant (bouton PARTIR)

**HubAntre.gd** — UX contextuelle:
- Entrée: `hub_enter` + `scene_transition` superposés
- Hotspot souffle: `ogham_chime` (au lieu de `whoosh` générique)
- Bouton PARTIR: `partir_fanfare`
- Biome sélectionné: `choice_select` + `ogham_chime` (confirmation rituelle)
- Perk confirmé: `perk_confirm`

**TransitionBiome.gd** — Phase 4 Sentier: `biome_reveal` distinct (au lieu de `magic_reveal` dupliqué)

### SFX Rework v2 — Waveforms Pixel Celtic (commit `4592ebc`)

**Objectif** : Remplacer les sines génériques par des waveforms pixel/chiptune + échelle D Dorian celtique.

**SFXManager.gd** — 3 helpers de waveform + 12 générateurs retravaillés :
- `_sq(freq, t)` — onde carrée adoucie (sin * 8.0 clampé -1..1), style Game Boy
- `_tri(freq, t)` — triangle NES (`2/PI * asin(sin(...))`)
- `_pulse(freq, t, duty)` — duty cycle variable (25% par défaut), style SID chip
- **Échelle D Dorian (référence)** : D4=294Hz E4=330Hz F4=349Hz G4=392Hz A4=440Hz B4=494Hz C5=523Hz D5=587Hz

12 générateurs reworked vers pixel/celtique :
- `hover` → G5 square blip (5ème celtique au-dessus de D)
- `click` → pulse 25% + noise burst
- `ogham_chime` → triangle E4+B4 (harpe plucked)
- `ogham_unlock` → arpège Dorian D4-F4-A4-D5 triangle
- `bestiole_shimmer` → NES triangle A4-E5-A5 + pulse sparkle
- `magic_reveal` → balayage pentatonique D→G→A→D triangle
- `skill_activate` → square zap D5→G4 descente Dorian
- `scene_transition` → square glide D3→A3 (5ème celtique grave)
- `eye_open` → square profond D1→D2 + drone A (cornemuse awakening)
- `hub_enter` → drone D+A désaccordé (2 voix 147.0+147.8 Hz → beating naturel, chaleur pipe)
- `souffle_regen` → glide triangle D4→A4 + sparkle square
- `souffle_full` → arpège pentatonique D4-G4-A4-D5 triangle

---

## Session: 2026-02-25 (Phase B COMPLETE — B.1 + B.2 + B.3 + B.4 + B.5)

### Backlog B — Progression (3 items livrés)

**B.2 — Arbre de Vie (déjà implémenté, confirmé)**
- Constat: HubAntre.gd avait déjà le hotspot "arbre" + navigation vers ArbreDeVie.tscn
- ArbreDeVie.tscn + arbre_de_vie_ui.gd (494 L) entièrement implémentés avec bouton Retour
- Marqué FAIT (aucune modification nécessaire)

**B.5 — Première Run Directe** (`scripts/SceneRencontreMerlin.gd`)
- Après la Rencontre Merlin, propose 2 boutons: "Explorer le Refuge" / "Commencer l'Aventure"
- "Commencer l'Aventure" → TransitionBiome directement (skip Hub), pre-set biome = suggested_biome
- "Explorer le Refuge" → HubAntre (comportement normal)
- Architecture: `var _next_scene` + `_show_destination_choice()`, routing dynamique en `_transition_out()`

**B.3 — Archétype → Bonus DC + Contexte RAG**
- `merlin_constants.gd`: `ARCHETYPE_DC_BONUS` dict (8 archétypes, valeurs -1/0/+1)
- `merlin_game_controller.gd`: applique `archetype_modifier` dans `_get_dc_for_direction()`
- `player_profile_registry.gd`: `get_archetype_id()`, `get_archetype_title()`, archetype_title dans save + get_summary_for_prompt()
- `merlin_omniscient.gd`: sync `archetype_id` + `archetype_title` dans registry_data → RAG world_state
- `rag_manager.gd`: `_get_archetype_context()` (MEDIUM priority, ~40 tokens)

**Commits**: `3e37e54` (chore: triage Step 0), `941eccc` (feat: B.2/B.3/B.5)

---

## Session: 2026-02-25 (Phase B Suite — B.1 COMPLETE)

### B.1 — Souffle Perk UI (sélection Hub + activation en jeu)

**`scripts/HubAntre.gd`**
- 5e hotspot "Souffle" (icon=COMPASS, ratio=0.06,0.80) — bottom-left
- `_show_perk_overlay()`: overlay modal 2×2 avec 4 cartes perk (Bouclier/Surge/Vision/Canalisation)
- `_on_perk_card_selected()`: mise à jour visuelle des cartes (selected/unselected)
- `_on_perk_confirmed()` → `store.dispatch({SELECT_PERK, perk_id})`
- `_on_perk_cancelled()`: ferme sans sauvegarder

**`scripts/merlin/merlin_store.gd`**
- `state.run.perks`: `{selected_perk: "", perk_used: false}`
- `_init_triade_run()`: preserve selected_perk, reset perk_used uniquement
- `SELECT_PERK` dispatch: valide perk_id vs SOUFFLE_PERK_TYPES, met à jour run.perks

**`scripts/ui/merlin_game_controller.gd`**
- `_get_souffle_perk_dc_bonus()`: bouclier=+2, surge=+6, vision=+2, canalisation=+4 (fallback=+4)
- `_apply_souffle_perk_side_effect()`: shield_active (bouclier), vision_active (vision), auto-ogham (canalisation)
- Headless path + normal dice roll path câblés sur les nouveaux helpers
- `_on_state_changed()` → `ui.update_selected_perk(perk_id)` pour sync badge

**`scripts/ui/merlin_game_ui.gd`**
- `_perk_badge: Label` créé au-dessus du bouton Souffle
- `update_selected_perk(perk_id)`: affiche `[NomPerk]` ou masque le badge
- Positionné à `(vp_size.x - 76, vp_size.y - 84)`, 72×14px

**Validation**: 0 errors, 0 warnings (validate_editor_parse.ps1)
**Commit**: `7d795e4` (feat(progression): B.1 Souffle Perk UI)

---

**B.4 — Aspects → DC modifiers + contexte RAG** (commit `e4682dd`)
- `merlin_constants.gd`: ASPECT_DC_PENALTY_BAS=+2, PENALTY_HAUT=+1, BONUS_FULL_EQUILIBRE=-1
- Labels narratifs ASPECT_STATE_NARRATIVE (6 descriptions, 1 par état extrême par aspect)
- `merlin_game_controller.gd`: aspect_modifier cumulatif dans `_get_dc_for_direction()`
- `rag_manager.gd`: `_get_aspects_state_context()` (Priority HIGH) — injecte états extrêmes
  sous forme "ETAT: Corps Épuisé | Âme Possédée" pour guider le LLM

**Phase B COMPLETE** — B.1 + B.2 + B.3 + B.4 + B.5 tous livrés.

---

## Session: 2026-02-24 (Phase P3 — Features Avancees, Waves 16-21 COMPLETE)

### Phase P3 — Features Avancees (COMPLETE)

**Wave 16-17: Merlin Dialogue + Titles + What-If** (commit `66cbb3d`)
- Dialogue UI: 3 presets + free text + journal action (4th preset)
- LLM response generation via MOS with tone-aware prompts
- Card title: GM brain, 20 tokens, FALLBACK_TITLES (10 celtic)
- What-if: generate 3 alternatives, staggered fade-in reveal on unchosen options

**Wave 18: Dreams** (commit `c41fc13`)
- Dream overlay: fullscreen bg_deep, typewriter text, gentle pulse
- LLM dream generation: 80 tokens, T=0.9, 6 FALLBACK_DREAMS
- Trigger: biome change detection in `_resolve_choice()`

**Wave 19: Tutorial Narratif** (commit `c41fc13`)
- 7 diegetic mechanic hints in `tutorial_narratives.json`
- Triggers: first_card, dice_roll, souffle, ogham, biome, aspect, extreme
- Displayed via MerlinBubble, each shown once per run

**Wave 20: Cross-Run Memory** (commit `c41fc13`)
- RAG: `get_past_lives_for_prompt()` — last 3 runs
- Narrator prompt injection for continuity
- Journal popup: scrollable past lives with BBCode

**Wave 21: Integration P3** (commit `24cd876`)
- LLM null safety: Variant intermediate pattern (5 MOS sites)
- Dream overlay `is_inside_tree()` guard
- Journal popup wiring (signal + controller handler)
- Dialogue `is_processing` guard
- UI/UX Bible: 5 hardcoded colors → CRT_PALETTE, named font sizes, button themes, 48px touch targets

**Commits**: `66cbb3d` (W16-17), `c41fc13` (W18-20), `24cd876` (W21)

---

## Session: 2026-02-24 (Phase P2 — LoRA Data Prep, Waves 12-13)

### Phase P2 — LoRA Training (Waves 12-13 COMPLETE)

**Wave 12: Data Prep**
- Added TIER5_GENERATORS (4 P1-specific generators) to `generate_full_dataset_v7.py`:
  - `gen_sequential_pipeline()` — 6 gold samples (narrator+labels format)
  - `gen_danger_scenarios()` — 4 gold samples (survie + agonie)
  - `gen_narrative_arcs()` — 4 gold samples (1 per arc phase)
  - `gen_gm_effects()` — 4 gold samples (GM effects JSON)
- Generated v8 dataset: **724 total samples** (455 gold, 269 augmented)
- Identity primer injected into 95.3% of samples
- P1 features density: 2.9% (21/724)

**Wave 13: Config**
- `train_qwen_cpu.py`: Added v8 dataset auto-detection (priority over v7)
- `benchmark_lora.py`: Added 4 P1 competence metrics:
  - `sequential_format_rate` (target 85%) — A/B/C label extraction
  - `danger_awareness_rate` (target 80%) — life-aware language
  - `gm_effects_validity` (target 90%) — JSON format compliance
  - `arc_phase_count` — narrative phase variety

**Commits**: `1ca8a06` (P1.5 sequential), `9525df1` (P1 waves 9-11)

---

## Session: 2026-02-24 (Phase P0 Complete + Good Practices + P1 Start)

### Phase P0 — Fix Gameplay (COMPLETE, commit `0bd08f6`)

**Waves executees:**
- P0.0.1: Audit async flow timestamps
- P0.1.1-P0.1.3: Fix timing (refactor _request_next_card, show_thinking, await start_run)
- P0.2.1-P0.2.3: Fix labels (blocklist 102→20, relacher _validate_single_verb, regex fallback)
- P0.3.1-P0.3.3: Tune quality (seuils MIN/JACCARD, poids REPETITION/STRUCTURE, guardrails MOS)
- P0.4.1: E2E Validation — autoplay 3 cartes LLM native, 0% fallback

**Fixes headless mode (auto_play_runner.gd + merlin_game_controller.gd):**
- Skip narrator intro, dice roll animation, result transitions, travel animation en headless
- Race condition fix: `headless_mode = true` AVANT `add_child()` (_ready triggers during add_child)
- SIGPIPE fix: redirect `> /dev/null 2>&1` au lieu de pipe `| head`

**Good Practices**: Section 8 ajoutee dans `gdscript_knowledge_base.md` (9 sous-sections)

**Metriques E2E:**
| Metrique | Resultat |
|----------|----------|
| Cards generated | 3/3 LLM native |
| Fallback rate | 0% |
| Headless intro | 232ms (was 95s) |
| Resolve time | 0ms (UI skipped) |
| Gen time/card | 75-87s (CPU normal) |

### Problemes connus (non bloquants)
- Label extraction ~50% fallback generiques
- GM effects fail sur certaines cartes → heuristic fallback
- Hang apres 3-4 cartes (suspicion memoire/Ollama)

---

## Session: 2026-02-22 (Architecture LLM — LoRA v2 + Pipeline Enrichi)

### Objectif
Repondre a la question strategique: "Un seul modele peut-il tout faire?" et preparer LoRA v2.

### Resultats

**AXE A: LoRA v2 Dataset + Notebook**
- Gold dataset v5: 20 examples extraits du doc reference (20 cartes avec VERBE — description)
- Augmentation v5: 1734 samples (9 strategies: biome, aspect, theme, celtic, verb swap, system prompt, card num, combined, v1 merge)
- Format compliance: 100%
- Notebook Colab mis a jour: QLoRA r=16, 7 modules (q/k/v/o_proj + gate/up/down_proj), MAX_SEQ_LENGTH=2048
- Export dual GGUF: Q4_K_M + F16

**AXE B: Pipeline Programmatique (CODE Godot)**
- Prompt format: VERBE seul → "VERBE — description concrete en 1 phrase" (2 locations dans merlin_llm_adapter.gd)
- MINIGAME_CATALOGUE: 6 → 14 types (Apaisement, Sang-froid, Course, Fouille, Ombres, Volonte, Regard, Echo)
- UI desc_labels: risk level → action_desc (merlin_game_ui.gd)
- Editor parse check: 0 erreurs, 0 warnings

**AXE C: Rapport Word**
- generate_test_report.mjs: mis a jour v5 (14 mini-jeux, 1734 LoRA samples)

**Background: LoRA v1 Training**
- Step 203/310 (epoch 3.2), loss=0.81, accuracy=82.4%
- ~6.5h restantes sur CPU

### Fichiers modifies
- `scripts/merlin/merlin_llm_adapter.gd` — prompt format VERBE — description
- `scripts/merlin/merlin_constants.gd` — MINIGAME_CATALOGUE 14 entries
- `scripts/ui/merlin_game_ui.gd` — desc_labels action_desc
- `data/ai/training/gold_verbs_v5.jsonl` — 20 gold examples
- `data/ai/training/merlin_verbs_v5_augmented.jsonl` — 1734 augmented samples
- `tools/lora/augment_dataset_v5.py` — 9-strategy augmentation script
- `tools/lora/train_qwen_colab.ipynb` — QLoRA v2 notebook
- `C:/Users/PGNK2128/Downloads/generate_test_report.mjs` — rapport Word v5

## Session: 2026-02-21b (Bugfix Round 2 — 4 Remaining Issues Post-Test)

### Objectif
Corriger 4 bugs restants apres test utilisateur: intro absente, LLM incoherent (dialogue au lieu de narration 2e personne), hover souris KO, musique ne boucle pas.

### Root Causes Identifies

| Bug | Root Cause |
|-----|------------|
| Intro absente | Gated behind `result.get("ok", false)` — si store dispatch echoue, intro skip |
| LLM incoherent | Template path (L1112) manquait persona + "PAS de dialogue" — seul fallback l'avait |
| Hover souris KO | `_bottom_zone` (VBoxContainer) a `mouse_filter=STOP` par defaut → bloque les signaux `mouse_entered` des boutons enfants. `_merlin_overlay` (z_index=20) reste PASS apres fade |
| Musique ne boucle pas | `.import` file a `edit/loop_end=-1` → Godot ignore `loop_mode=FORWARD` si `loop_end <= 0`. Le fix precedent settait `loop_mode` mais pas `loop_end` |

### Fixes appliques (4/4)

**Fix 1: LLM coherence** — `merlin_llm_adapter.gd`
- Template path: ajoute "Narre a la 2e personne (tu). Decris sensations. PAS de dialogue."
- Fallback path: ajoute "PAS de dialogue." a la persona
- Format choix: "VERBE — description courte" (les deux paths)

**Fix 2: Mouse hover** — `triade_game_ui.gd`
- `_bottom_zone.mouse_filter = MOUSE_FILTER_PASS` (explicite au setup)
- `options_container.mouse_filter = MOUSE_FILTER_PASS`
- `btn.mouse_filter = MOUSE_FILTER_STOP` (explicite sur chaque bouton)
- `_merlin_overlay.mouse_filter = IGNORE` quand cache (callback tween)
- `_merlin_overlay.mouse_filter = PASS` quand visible

**Fix 3: Music loop** — `music_manager.gd`
- Nouveau helper `_enable_wav_looping(stream)`: set `loop_mode=FORWARD`, `loop_begin=0`
- Calcule `loop_end = get_length() * mix_rate` quand `.import` a `loop_end=-1`
- Remplace tous les settings inline par appels a `_enable_wav_looping()`
- Debug print dans `_on_loop_finished` + check `_player_loop.stream` non null

**Fix 4: Intro visibility** — `triade_game_controller.gd`
- Deplace `show_opening_sequence()` + `show_narrator_intro()` HORS du gate `result.get("ok")`
- Seul `_sync_ui_with_state()` reste dans le ok-check
- L'intro s'affiche toujours, meme si store dispatch echoue

### Validation
- Editor Parse Check: **0 errors, 0 warnings**
- Fichiers modifies: 4 (merlin_llm_adapter.gd, triade_game_ui.gd, music_manager.gd, triade_game_controller.gd)

---

## Session: 2026-02-21 (Bugfix MerlinGame — 10 Bugs + Keyboard Accessibility)

### Objectif
Corriger 10 bugs MerlinGame: fuite prompt LLM, positions boutons, texte resultat, bordure carte, hover souris, Souffle, musique loop, renommages, accessibilite clavier minijeux.

### Phases completees (8/8)

**Phase 1: Fix LLM Prompt Leakage** — `merlin_llm_adapter.gd`
- Simplifie system prompt (retire STYLE OBLIGATOIRE, FORMAT, EXEMPLE)
- Pipeline reordonne: cleanup meta AVANT extraction labels
- 15+ patterns ajoutes (choix a/b/c, format:, style:, complement, infinitif...)
- Regex elargie: `[...]{2+ chars}` capture tout contenu entre crochets

**Phase 2: Fix bouton selectionne en hauteur** — `triade_game_ui.gd`
- Reset scale + queue_sort() parent Container avant chaque nouvelle carte

**Phase 3: Fix texte resultat apres D20** — `triade_game_ui.gd`
- Cache dice overlay avant affichage du texte resultat

**Phase 4: Fix bordure carte** — `merlin_visual.gd`
- Border PALETTE.accent → PALETTE.ink (meilleur contraste)
- Border width 2 → 3px

**Phase 5: Hover + Souffle + Renommages** — `triade_game_ui.gd`, `TriadeGameUI.tscn`
- Souffle btn position ajustee (-68px au lieu de -72px)
- "Pioche" → "Restant", "Cimetiere" → "Passe"
- Tailles augmentees: PiocheColumn 120→140, CimetiereColumn 120→140
- DeckRoot 100x140→110x150, DiscardRoot 86x114→100x130

**Phase 6: Fix musique loop** — `music_manager.gd`
- Connecte `_player_loop.finished` → `_on_loop_finished()` (replay)
- Set `loop_mode = LOOP_FORWARD` au chargement du stream (pas seulement au play)

**Phase 7: Clavier minijeux** — 12 minigames + `minigame_base.gd`
- Base class: `_unhandled_input()` → `_on_key_pressed(keycode)` virtual
- ESPACE/ENTREE: de_du_destin, roue_fortune, tir_a_larc
- Q/E: pile_ou_face, pas_renard
- Q/W/E: pierre_feuille_racine
- A/S/D: joute_verbale
- W/S ou UP/DOWN: bluff_druide
- 1-4: lame_druide
- 1-3: noeud_celtique, enigme_ogham
- 1-9: rune_cachee, oeil_corbeau
- LEFT/RIGHT + ENTREE: negociation

**Phase 9: Documentation** — `docs/10_llm/RUN_REFERENCE.md`, `progress.md`
- Anti-leakage v2: pipeline reordonne, prompt simplification rules
- Audio looping requirements
- Tableau complet accessibilite clavier par minijeu

### Validation
- Editor Parse Check: **0 errors, 0 warnings**
- Fichiers modifies: 18

---

## Session: 2026-02-21 (Quality Upgrade — Verbes Contextuels + LoRA + Rapport v4)

### Objectif
Matcher la qualite du doc de reference: verbes contextuels (VERBE — description), mini-jeux, rapport enrichi, pipeline LoRA.

### Phases completees (5/5)

**Phase 1: Prompt Refonte** — `merlin_llm_adapter.gd`
- Format prompt: "UN SEUL VERBE" → "VERBE — Description d'action en 1 phrase"
- Extraction regex: `^[A-D][):.]\s*([A-ZA-U]+)\s*[—–\-:]+\s*(.+)` (verb + desc)
- story_log window: 3 → 10 entrees, 120 → 200 chars
- Fallback: VERB_POOL avec action_desc="" (pas d'invention)

**Phase 2: Mini-Jeux** — `merlin_constants.gd` + `merlin_llm_adapter.gd`
- Catalogue 6 mini-jeux (traces, runes, equilibre, herboristerie, negociation, combat_rituel)
- Detection programmatique `_detect_minigame()` par regex sur trigger words
- Champ `card["minigame"]` propage dans la pipeline

**Phase 3: UI** — `triade_game_ui.gd`
- Labels enrichis: verb en majuscules + sous-label description
- Badge mini-jeu (celtic_gold) sous le texte narratif
- Texte de resolution (SUCCESS/FAILURE) apres choix

**Phase 4: LoRA Pipeline**
- `data/ai/training/gold_verbs_v4.jsonl` — 20 exemples gold
- `tools/lora/augment_verbs_dataset.py` — 7 strategies, 550 samples, 166 verbes uniques
- `tools/lora/train_qwen_colab.ipynb` — QLoRA r=16, 3 epochs, Colab T4
- `tools/lora/benchmark_lora.py` — metriques verb extraction, format compliance, Jaccard

**Phase 5: Rapport Word v4** — `Downloads/generate_test_report.mjs`
- Options: VERBE gras + description italique + verb source tags
- Badge mini-jeu + texte de resolution
- Section 10: "Qualite des Verbes & Mini-Jeux"
- Output: `MERLIN_LLM_Pipeline_Test_Report_v4.docx`

### Bug fix
- `_validate_triade_option()` strippait `action_desc` et `verb_source` → ajoutes a la liste de preservation
- `pixel_scene_data.gd`: 6 `const` → `static var` (Godot 4.5 ne supporte pas PackedStringArray/Color dans const)

### Validation
- Editor parse: PASSED (0 errors, 0 warnings)
- Suite 1 (TestLLMIntelligence): **24/24 PASS**
- Suite 2 (TestLLMFullRun): **4/4 PASS** — 20 cards, 10 essences, p50=52.8s
- verb_source: `(llm)` et `(fallback)` correctement propagees
- Minigames: "Traces" + "Combat Rituel" detectes

### Observations base model (sans LoRA)
- Qwen 1.5B ne produit pas nativement le format VERBE — description (~90% fallback)
- Le LoRA (Phase 4) est concu pour corriger ca → notebook Colab pret a lancer

---

## Session: 2026-02-15d (Fix LLM Pipeline — 0% to 100% LLM)

### Objectif
Corriger le pipeline LLM pour que 100% des cartes soient generees par le LLM (core feature du jeu).
Run 5 E2E avait montre 0% LLM — toutes les cartes venaient de emergency_fallback.

### Causes racines identifiees (chaine de defaillance)
1. Controller LLM_TIMEOUT_SEC=25s trop court pour CPU inference (~60s)
2. Retry "_retry_llm_generation" echouait car "Already generating" (thread C++ actif)
3. Adapter GENERATION_TIMEOUT_MS=8s rejetait tout resultat >8s (double-kill)
4. `_run_llm()` sans timeout → attend indefiniment si callback ne fire pas
5. JSON primary generation TOUJOURS malformee avec Qwen 3B CPU → 120s gaspillees

### Corrections appliquees (5 fichiers)

**1. merlin_ai.gd** — Core LLM interface
- Ajout `cancel_current_generation()` et `is_llm_busy()` (methodes C++ existantes)
- Ajout `_warmup_generate()` — prime le cache CPU apres chargement modele (7.8s)
- Timeouts: LLM_POLL_TIMEOUT_FIRST_MS=300s, LLM_POLL_TIMEOUT_MS=120s
- Backoff polling 50ms (vs 10ms)

**2. merlin_omniscient.gd** — MOS orchestrateur
- `generate_card()` attend `_generation_in_progress` et `_prefetch_in_progress` (vs return empty)
- Prefetch: pool path desactive → toujours pipeline complet (Strategy B)
- LLM_TIMEOUT_MS: 5000 → 300000

**3. merlin_llm_adapter.gd** — Adaptateur TRIADE
- Skip JSON primary generation → two-stage direct (free text + wrap programmatique)
- Suppression du post-hoc timeout de 8s

**4. triade_game_controller.gd** — Controller
- LLM_TIMEOUT_SEC: 25 → 360
- Guard retry si LLM busy
- max_tokens: 380 → 250

**5. auto_play_runner.gd** — Runner E2E
- Detection resolution par `current_card.is_empty()` (vs `is_processing`)
- POLL_TIMEOUT_SEC: 90 → 420, resolution timeout: 60 → 300
- Classification source amelioree (detecte `_strategy` field)

### Runs E2E (9 → 13)
| Run | Cartes | LLM% | Resultat | Cause echec |
|-----|--------|------|----------|-------------|
| 9 | 0 | 0% | Timeout | Cold start 120s + runner 180s timeout |
| 10 | 1 | 100% | Timeout | Resolution timeout 60s trop court |
| 11 | 1 | 100% | Bloque | cancel_generation() bloque C++ 80s |
| 12 | 1 | 0% | Bloque | _generation_in_progress stuck true |
| 12b | 5 | 0% | Fallback | Pool path JSON toujours malformed |
| **13** | **31** | **100%** | **VICTOIRE** | **Mission survive 30/30 completee** |

### Run 13 — Resultats detailles
- **31 cartes jouees, 100% LLM, VICTOIRE ("Le Prix Paye")**
- Card 1: 113s (cold start), Cards 2-31: **~2.9s** (prefetch)
- Total run: 448s (7.5 min)
- Life: 86 final, Karma: -3, Souffle: 1
- Outcomes: 2 crit_success, 14 success, 14 failure, 1 crit_fail
- Flux: terre=91, esprit=100, lien=64

### Issue identifiee: Textes repetitifs
- Les 31 cartes ont le MEME texte (prefetch genere avant update du game state)
- Options generiques ("Agir avec prudence", "Mediter en silence", "Foncer tete baissee")

---

## Session: 2026-02-15e (Text Variety + Guardrail Fix — 100% LLM unique)

### Objectif
Corriger la repetition textuelle (31 cartes identiques dans Run 13) et les faux positifs guardrails.

### Causes racines (5 bugs)
1. **story_log jamais peuple** — le store l'initialisait a `[]` mais ne le remplissait jamais
2. **Prompt two-stage sans variance** — memes inputs = memes outputs
3. **Context hash trop simple** — ne detectait pas le changement de cards_played/life
4. **Fallback labels toujours identiques** — meme triplet "Agir/Mediter/Foncer"
5. **Prefetch avant resolution** — utilisait l'ancien game state (stale data)

### Bug supplementaire (Run 14b): Guardrails faux positifs
- `_contains_forbidden_words()` utilisait `.contains()` (substring match)
- Le mot interdit "ia" matchait "conf**ia**nce", "all**ia**nce", etc.
- 2/5 cartes LLM valides (670 et 590 chars) rejetees par guardrails

### Corrections (4 fichiers)

**1. merlin_llm_adapter.gd** — Enrichissement prompt + rotation labels
- 32 themes celtiques (CELTIC_THEMES) injectes aleatoirement dans le prompt
- 8 sets de fallback labels (FALLBACK_LABEL_SETS) rotatifs par cards_played
- Prompt enrichi: cards_played, life, karma, story_log, theme word

**2. merlin_store.gd** — Population story_log
- `_resolve_triade_choice()` enregistre card text + chosen label (5 derniers)

**3. merlin_omniscient.gd** — Context hash + guardrails
- Hash enrichi: + cards_played + life_essence
- GUARDRAIL_MAX_TEXT_LEN: 500 → 1200
- `_contains_forbidden_words()` → `_find_forbidden_word()` (whole-word matching)
- Forbidden words: soft warning pour LLM (vs hard reject avant)
- Diagnostic logging (pre/post guardrails, post-validate)

**4. triade_game_controller.gd** — Prefetch timing
- Prefetch deplace APRES resolution (state a jour, pas stale)
- Labels retry rotatifs

### Runs E2E (14 → 15)
| Run | Cartes | LLM% | Fallback | Guardrail rejets | Texte unique |
|-----|--------|------|----------|-----------------|-------------|
| 14 | 2 | 50% | 1 | 1 (max_len 500) | Oui |
| 14b | 5 | 60% | 2 | 2 (forbidden "ia") | Oui |
| **15** | **7** | **100%** | **0** | **0** | **Oui** |

### Run 15 — Resultats
- **7 cartes jouees, 100% LLM, 0 fallback, mission equilibre 7/8**
- Timeout 600s avant 8e carte (CPU inference ~70s/carte)
- Themes varies: saumon/riviere, feu/saule, lande sauvage, tonnerre
- Guardrails: 0 rejections, 0 soft warnings
- NPC encounter (Marchand des Ombres) detecte et traite correctement

---

## Session: 2026-02-15c (Audit Complet Projet — Coherence + Headless)

### Audit par 3 agents paralleles (structure, logs, lore)
- 75+ scripts, 19 scenes actives, 43 scenes total inspectees
- Coherence lore/data: 7 biomes, 7 druides, 18 Oghams, Triade — TOUT OK
- 6 fichiers JSON data/ai/config/ valides et coherents

### Bugs corriges
1. **CRITIQUE** — MerlinStore pas enregistre comme singleton (14+ scripts le cherchent via `/root/MerlinStore`)
   - class_name + autoload meme nom = interdit en Godot 4
   - Fix: GameManager._ready() cree MerlinStore et l'ajoute a root
   - Supprime le fallback local dans triade_game_controller.gd
2. **Calendar.gd:180** — `Dictionary == "floating"` crash runtime (19 erreurs)
   - Fix: `if date_val is String and date_val == "floating"`
3. **SceneAntreMerlin.gd + SceneEveil.gd** — 10 constantes vers sprites supprimes
   - Fix: pointer vers M.E.R.L.I.N.png
4. **HubAntre.gd:1956,1965** — Control anchor/size warnings
   - Fix: `set_deferred("size", vp)`

### Validation
- Editor Parse Check: PASSED (0 errors, 0 warnings)
- Smoke Test: **19/19 scenes PASS** (toutes en headless)
- KB mise a jour: 7 nouvelles entrees + 2 patterns

---

## Session: 2026-02-15b (Bestiaire de Broceliande — Catalogue des Rencontres)

### Document cree: `docs/50_lore/14_BESTIAIRE_BROCELIANDE.md` (~700 lignes, 32K chars)
- Catalogue complet de toutes les entites rencontrables dans le monde de DRU
- 12 sections: 7 Druides, 3 Humains, 5 Anciens du Sidhe, Korrigans, Creatures folkloriques, L'Ankou, Bestiole, 18 Druides dissous + 7 perdus, Merlin, Matrice de rencontres, Evolution multi-run, Relations
- Matrice de rencontres croisee (36 entites x 7 biomes x conditions)
- Cross-references vers tous les docs source (11_PNJ, 03_FACTIONS, 08_BIOMES, 07_OGHAMS, 06_BESTIOLE, 04_MERLIN)

### MAJ Index: `docs/50_lore/00_LORE_BIBLE_INDEX.md`
- Entree #14 ajoutee dans la table des documents
- Cross-reference ajoutee dans la section verification
- Total corpus: ~12,700+ lignes

---

## Session: 2026-02-15 (Revert Ministral -> Qwen 2.5-3B definitive)

### Benchmark comparatif hors-Godot (Ollama API, 20 prompts)
- **Qwen 2.5-3B**: 95% persona, 3 violations, 8.99s latence — coherent, francais correct
- **Ministral 3B**: 62% persona, 16 violations, 40.19s latence — incohérent, texte casse
- **Verdict**: Qwen gagne sur tous les fronts

### Migration complete: suppression totale de Ministral
- **GGUF supprime**: `ministral-3b-instruct.gguf` (3.3 GB)
- **Ollama purge**: `ollama rm ministral-3b-instruct:latest`
- **MODEL_FILE**: `qwen2.5-3b-instruct-q4_k_m.gguf` dans merlin_ai.gd
- **RAM_PER_BRAIN_MB**: 3800 -> 2200
- **Fichiers GDScript (9)**: merlin_ai, merlin_omniscient, rag_manager, merlin_llm_adapter, triade_game_controller, IntroCeltOS, TestLLMScene, llm_source_badge, llm_status_bar
- **Config**: PLACE_MODEL_HERE.txt
- **Outils Python (2)**: test_merlin_chat.py (reecrit Ollama API), compare_models.py (Qwen-only)
- **Docs (10+)**: CLAUDE.md, GAMEPLAY_BIBLE, MASTER_DOCUMENT, TRINITY_ARCHITECTURE, STATE_Claude_MerlinLLM, MOS_ARCHITECTURE, GUIDE_SCENARIOS_LLM, ci_cd_release.md
- **Grep zero Ministral**: confirme dans *.gd, *.json, *.txt (residus historiques OK dans docs)

---

## Session: 2026-02-14a (Fix Warnings + Migration Qwen -> Ministral 3B — REVERTED)

### GDScript Warnings Fixed
- **Integer divisions (7 total)**: relationship_registry, session_registry (x2), IntroCeltOS, mg_lame_druide, mg_roue_fortune, triade_game_controller — pattern `int(x / N.0)`
- **Unused class variables (3)**: Removed `_preloaded_responses`, `_llm_gen`, `_prefetched_responses` from SceneRencontreMerlin.gd
- **Lambda capture bug (2)**: `_llm_rephrase()` et `_llm_generate_responses()` — GDScript 4 lambdas capture by value, refactored to Dictionary (reference type) as shared state

### Migration LLM: Qwen2.5-3B -> Ministral 3B Instruct (REVERTED 2026-02-15)
- **REVERT**: Benchmark a demontre que Ministral est inutilisable (62% persona, texte incohérent)
- Migration annulee et remplacee par Qwen definitif (session 2026-02-15)

---

## Session: 2026-02-11i (Phase 43B — Fix UI + LLM + TransitionBiome)

### Etape 1: UI TriadeGame — Options visibles
- Removed spacer2 (EXPAND_FILL) → fixed 4px gap between card and options
- Reduced card_panel: 460x360 → 460x280
- Reduced portrait height: 96 → 72, encounter tile: 72 → 0 (auto)
- Removed obsolete Centre cost indicator "(1 🜁)" (Centre is free since 43A)
- Reduced buttons: 120x46 → 110x40

### Etape 2: LLM Timeout + Fallback
- `LLM_TIMEOUT_SEC`: 8.0 → 20.0 (Qwen2.5-3B needs 15-25s for GBNF JSON on CPU)
- Added card validation: checks `options` is Array of size >= 3, else fallback

### Etape 3: LLM Prompts enrichis
- `build_triade_context()`: Added `biome` and `life_essence` fields
- `_build_triade_system_prompt()`: Enriched with Celtic vocabulary, immersive tone
- `_build_triade_user_prompt()`: Added biome, life essence, story_log context; removed `cost:1`
- `_generate_card_two_stage()`: Enriched system/user prompts with biome
- `_build_narrator_input()` (merlin_omniscient): Added biome from context

### Etape 4: TransitionBiome subtile + progressive
- Removed opaque mist_layer ColorRect (main culprit for full-screen opacity)
- Repositioned GPU particles on landscape center (not screen center)
- Reduced particle opacity: back 0.40→0.25, mid 0.30→0.18, front 0.20→0.12
- Reduced volumetric fog: density 0.3→0.15, color alpha 0.2→0.12
- Path drawing slowed: 0.022s→0.06s per step (~2.1s total)
- End diamond pulses while waiting for LLM prefetch (up to 8s)

---

## Session: 2026-02-11h (Hotfix — Pipeline Warnings + PixelEncounterTile)

### Pipeline Enhancements
- **validate_editor_parse.ps1**: Added warning detection (Integer division, unused vars, etc.)
  - Warnings reported in YELLOW, non-fatal by default
  - `--strict` flag makes warnings fatal (exit 1)
  - Warning patterns: Integer division, unused vars/params, unused signals, narrowing conversion
- **Editor Parse Check**: Now detects both errors AND warnings from Godot recompilation

### Warning Fixes (6 integer division + 2 unused)
- `merlin_action_resolver.gd:68` — `int(momentum / 20)` → `int(momentum / 20.0)`
- `merlin_action_resolver.gd:134` — `int(score / 10)` → `int(score / 10.0)`
- `merlin_map_system.gd:60` — `int(total / 2)` → `int(total / 2.0)`
- `merlin_store.gd:1220` — `int(... / 100)` → `int(... / 100.0)`
- `merlin_store.gd:1491` — `int(awen_spent / 3)` → `int(awen_spent / 3.0)`
- `merlin_store.gd:1498` — `int(score / 50)` → `int(score / 50.0)`
- `merlin_card_system.gd:583` — Removed unused `story_log` variable
- `merlin_card_system.gd:638` — Prefixed unused `biome_key` → `_biome_key`

### KB Updates
- `gdscript_knowledge_base.md` section 1.3: Corrected integer division docs
- `MEMORY.md`: Updated pipeline step 0 description with warning detection

---

## Session: 2026-02-11g (Phase 43A — Refonte Gameplay Fondations)

### Phase 43A: Fondations Gameplay (Hand of Fate 2 inspiration)
- **Status:** COMPLETE (validate.bat passed)
- **Plan consolide:** `.claude/plans/playful-yawning-tarjan.md`

#### A.1: Suppression game over par aspects + 12 chutes
- Supprime Legacy section (VERBS, RUN_RESOURCES, NEEDS, etc.) + Reigns section + TRIADE_ENDINGS
- Supprime SOUFFLE_CENTER_COST, SOUFFLE_EMPTY_RISK
- Centre gratuit (cost=0 dans TRIADE_OPTION_INFO)
- _check_triade_run_end(): vie=0 remplace 2 extremes
- Supprime _handle_bestiole_care(), _get_triade_ending(), _handle_run_end()
- Supprime actions REIGNS_* et LEGACY (START_RUN, END_RUN, APPLY_EFFECTS, RUN_EVENT)
- Supprime bestiole.needs (Tamagotchi) de build_default_state()
- Fix references: Collection.gd, merlin_effect_engine.gd, merlin_llm_adapter.gd

#### A.2: Systeme essences de vie (jauge HP)
- LIFE_ESSENCE_MAX=10, START=7, CRIT_FAIL_DAMAGE=2, CRIT_SUCCESS_HEAL=1
- _damage_life(), _heal_life(), get_life_essence() dans store
- Actions TRIADE_DAMAGE_LIFE/HEAL_LIFE + signal life_changed
- DAMAGE_LIFE/HEAL_LIFE dans effect engine (VALID_CODES + _apply_life_delta)
- Controller: degats crit_failure, heal crit_success, _on_life_changed
- UI: update_life_essence() avec couleurs et animation low-life

#### A.3: DC variable hybride
- Supprime DC_LEFT=6/DC_CENTER=10/DC_RIGHT=14 fixes
- DC_BASE ranges: left 4-8, center 7-12, right 10-16
- ASPECT_DC_MODIFIER: balanced=-1, 1 extreme=0, 2=+1, 3=+2
- DC_DIFFICULTY_LABELS: Facile/Normal/Difficile avec couleurs

#### A.4: Missions hybrides
- MISSION_TEMPLATES: 4 types (survive/equilibre/explore/artefact) avec poids
- _generate_mission() weighted random dans store
- _auto_progress_mission() par type dans controller

#### A.5: Ecran resultats enrichi
- show_end_screen() enrichi avec indicateur "Essences Epuisees"
- update_life_essence() avec seuils couleur et animation

**Fichiers modifies (8):**
- merlin_constants.gd, merlin_store.gd, merlin_effect_engine.gd
- triade_game_controller.gd, triade_game_ui.gd
- Collection.gd, merlin_llm_adapter.gd, task_plan.md

---

## Session: 2026-02-11f (Phase 41 — Responsiveness + Qualite LLM)

### Phase 41: Optimisation Responsiveness + Qualite Narrative
- **Status:** COMPLETE

#### Phase A: Responsiveness Critique
- Remplace polling 250ms par `process_frame` dans triade_game_controller.gd (latence 250ms → ~16ms)
- Skip typewriter deja implemente (click/tap/touche)
- Fix polling backoff merlin_ai.gd: instant exit on done + 10ms backoff (2 sites: single + parallel)

#### Phase B: Prefetch Intelligent
- Relaxe prefetch validation: tolerance aspects ±1 step + biome exact (vs hash exact)
- Ajoute `try_consume_prefetch()` public dans merlin_omniscient.gd
- Deplace `_trigger_prefetch()` AVANT `display_card()` (prefetch pendant lecture)
- Fast-path prefetch dans controller: bypass store dispatch si prefetch dispo

#### Phase C: Qualite Narrative
- RAG budget 300→600 tokens (8192 ctx, ~11% utilise)
- Nouvelles sections RAG: karma/tension, promesses actives, arcs detailles
- Historique etendu: 3→10 derniers choix
- Sampling: Narrator T=0.75/top_p=0.92/rep=1.35, GM T=0.15/max=130/top_k=15

#### Phase D: Robustesse
- Brain busy timeout 60s (previent deadlock si brain crash)
- LLM timeout 15→8s (Qwen finit en 2-5s, 15s masquait les bugs)
- Emergency fallback contextuel (texte par biome, recovery aspect faible)

**Fichiers modifies (Phase 41):**
- `scripts/ui/triade_game_controller.gd` — Polling, prefetch, timeout, fallback
- `addons/merlin_ai/merlin_ai.gd` — Polling backoff, busy timeout, sampling params
- `addons/merlin_ai/merlin_omniscient.gd` — Prefetch tolerance, try_consume_prefetch
- `addons/merlin_ai/rag_manager.gd` — Budget 600, karma/tension/promesses/arcs

**Validation:** PASSED (0 erreurs, 1 warning pre-existant)

---

## Session: 2026-02-11e (Phase 40 — Optimisation LLM + LoRA Pipeline + Agents Fine-Tuning)

### Phase 40A: Optimisation Prompts + RAG (Palier 1)
- **Status:** COMPLETE
- Enrichi 3 templates narrator dans `prompt_templates.json` (vocab celtique, registres, few-shot)
- Injecte `tone_prompt_guidance()` dans `_build_narrator_prompt()` et `_build_system_prompt()`
- Augmente CONTEXT_BUDGET 180→300 tokens dans `rag_manager.gd`
- Ajoute `_get_tone_context()` au systeme de priorite RAG (Priority.HIGH)
- Sync ton ToneController → RAG world_state dans `_sync_mos_to_rag()`

### Phase 40B: Pipeline LoRA Complet (Palier 3)
- **Status:** COMPLETE
- Cree `tools/lora/export_training_data.py` v2.0 — 480 samples game-wide (0 ref scenes)
- Cree `tools/lora/augment_dataset.py` — 2001 samples augmentes (4 strategies)
- Cree `tools/lora/train_narrator_lora.py` — Unsloth/PEFT, QLoRA 4-bit
- Cree `tools/lora/convert_to_gguf.sh` — Conversion HF → GGUF
- Cree `tools/lora/benchmark_lora.py` — 6 metriques (ton, vocab, BLEU, francais, longueur, latence)
- Cree `tools/lora/README.md` — Documentation pipeline
- Cree `data/ai/training/tone_mapping.json` — 17 moods → 7 tons
- Modifie `merlin_ai.gd` — Chargement LoRA auto + Multi-LoRA par ton
- Modifie `merlin_omniscient.gd` — Switch ton LoRA avant generation

### Phase 40C: Agents Fine-Tuning (4 agents)
- **Status:** COMPLETE
- Cree `lora_gameplay_translator.md` — Point d'entree auto-active, traduit gameplay → spec
- Cree `lora_data_curator.md` — Extraction, curation, augmentation datasets
- Cree `lora_training_architect.md` — Hyperparametres, architecture, pilotage training
- Cree `lora_evaluator.md` — Benchmark, metriques GO/NO-GO, A/B testing
- MAJ `AGENTS.md` — 29→33 agents, nouvelle categorie LoRA Fine-Tuning
- MAJ `task_dispatcher.md` v1.2 — Types LoRA, patterns fichiers, review croise, exemples dispatch
- MAJ `CLAUDE.md` — Auto-activation LoRA, section 33 agents, pipeline reference

**Fichiers modifies (Phase 40):**
- `data/ai/config/prompt_templates.json`
- `addons/merlin_ai/merlin_omniscient.gd`
- `addons/merlin_ai/rag_manager.gd`
- `addons/merlin_ai/merlin_ai.gd`
- `tools/lora/` (6 fichiers crees)
- `data/ai/training/` (3 fichiers crees)
- `.claude/agents/` (4 agents crees + 2 MAJ)
- `CLAUDE.md`

---

## Session: 2026-02-11d (Phase 39B — Refonte Multi-Scenes)

### Phase 39B: Refonte Multi-Scenes (5 phases)
- **Status:** COMPLETE

#### Phase 1: Fix 3 choix TriadeGame (CRITIQUE)
- Cause racine: toutes les cartes fallback n'avaient que 2 options (LEFT+RIGHT)
- Ajout CENTER a toutes les 13 cartes fallback + emergency cards
- `_pad_options_to_three()` dans merlin_omniscient.gd — auto-insere CENTER contextuel
- triade_game_ui.gd: affiche toujours 3 boutons, grise les manquants

#### Phase 2: Accelerer SceneRencontreMerlin
- Timings: typewriter 30ms→15ms, animations 50% plus rapides, fades 0.3→0.15
- LLM: max_tokens 200→80 (RAG), 80→40 (rephrase), 100→60 (responses)
- Fallback lines raccourcies a 2 lignes max
- Phase BIOME_SELECTION supprimee (auto-set Broceliande)
- Oghams enrichis avec effets gameplay visibles
- Animation d'attente LLM ("..." pulsant)

#### Phase 3: Refonte HubAntre
- Removed numbered steps 1/2/3 → labels propres (Destination/Outil/Conditions)
- LLM Passif: Merlin commente async via generate_voice (30 tokens, auto-fade 4s)
- Auto-selection Broceliande si aucun biome choisi
- Bouton aventure repositionne en haut

#### Phase 4: TriadeGame UI
- Compteur Souffle numerique "3/7" avec code couleur
- PixelEncounterTile (NOUVEAU): tuile pixel art 24x24, 6 types de rencontre
- Integration dans display_card() avec detection auto par tags

#### Phase 5: PNJ via LLM + Mini-jeux logiques
- 5 cartes NPC fallback (Druide, Villageoise, Barde, Guerrier, Marchand)
- generate_npc_card() dans merlin_omniscient.gd (LLM first, fallback pool)
- 15% chance NPC apres carte 5 dans triade_game_controller.gd
- Mini-jeux contextuels: TAG_FIELD_MAP dans minigame_registry.gd (tags > keywords)

#### Fichiers modifies
- `addons/merlin_ai/merlin_omniscient.gd` — pad_options, generate_npc_card
- `addons/merlin_ai/generators/fallback_pool.gd` — CENTER sur 13 cartes, 5 NPC cards
- `scripts/ui/triade_game_ui.gd` — 3 boutons toujours, souffle counter, encounter tile
- `scripts/ui/triade_game_controller.gd` — NPC trigger, direct LLM 3 options, tag-based minigames
- `scripts/SceneRencontreMerlin.gd` — timings, textes courts, biome removed, oghams enrichis
- `scripts/HubAntre.gd` — adventure flow, LLM passif, auto-broceliande
- `scripts/ui/pixel_encounter_tile.gd` (NOUVEAU) — pixel art encounter tiles
- `scripts/minigames/minigame_registry.gd` — TAG_FIELD_MAP, tags parameter

#### Validation: PASSED (0 errors, 1 pre-existing warning)

---

## Session: 2026-02-11c (Phase 42 — Gameplay Bible & Audit de Coherence)

### Phase 42: GAMEPLAY_BIBLE.md — Vision Complete du Jeu
- **Status:** complete

#### Livrable
- **`docs/GAMEPLAY_BIBLE.md`** (~1500 lignes) — Reference absolue pour tout developpement futur

#### Contenu de l'audit
1. Boucle de gameplay principale (diagramme complet)
2. Systeme TRIADE (3 aspects x 3 etats, Souffle, Awen, Flux, Karma)
3. Systeme de cartes (4 types, pipeline LLM, fallbacks)
4. Systeme D20 + 15 mini-jeux
5. Flux de scenes complet (8 scenes, transitions, donnees requises)
6. Meta-progression (Arbre de Vie 28 talents, 18 Oghams, Evolution Bestiole)
7. Architecture IA/LLM (Multi-Brain, RAG v2.0, Guardrails)
8. Relations inter-systemes (signaux, actions, flux de donnees)
9. Audit de coherence complet

#### Problemes identifies
- **5 game-breaking (P0):** Mission stub, Arbre sans UI, Buffer absent, Twists absents, Fin secrete absente
- **6 equilibrage (P1):** Souffle restrictif, Karma volatile, DC Droite dur, Awen lent, Saut aspect, Save scumming
- **10 systemes caches non-implantes** (DOC_13 complet en attente)
- **6 incoherences design/code** (DOC_11 obsolete, D20 non-documente, Legacy code, etc.)

#### Recommandations priorisees
- **Phase A (P0):** Mission, Buffer cartes, Validation saut, Twists
- **Phase B (P1):** UI Arbre, Resonances, Profil joueur, Reequilibrage
- **Phase C (P2):** Fin secrete, Synergies, Evolution Bestiole, Quetes
- **Phase D (P3):** Nettoyage Legacy, MAJ docs

---

## Session: 2026-02-11b (Phase 41 — Phase 2A: Textes Dynamiques + Architecture LLM)

### Phase 41: LLM Early Warmup + Textes Dynamiques + Prefetch Parallele
- **Status:** complete (7/7 sub-phases)

#### Etape 1A+1B: LLM Early Warmup + Force 2 cerveaux
- `MenuPrincipalReigns._ready()` appelle `start_warmup()` en arriere-plan (call_deferred)
- `_start_llm_warmup()` ne montre l'overlay QUE si LLM pas encore pret
- `detect_optimal_brains()` force minimum 2 cerveaux sur desktop (maxi(2, detected))

#### Etape 1C: Indicateur IA discret dans le menu
- Label "IA: ..." en bas a droite, discret (ink_faded)
- Se connecte a MerlinAI.status_changed / ready_changed
- Passe a "IA: 2 cerveaux" (accent_soft) quand pret

#### Etape 2A+2B: JSON enrichi (140 variantes + atmosphere)
- 7 biomes x 4 categories (balanced, corps_extreme, ame_extreme, monde_extreme) x 5 variantes = 140 textes
- Champ `atmosphere` par biome: sounds, smell, light, mood (metadonnees sensorielles)
- Retro-compatible: arrival_text + merlin_comment toujours presents

#### Etape 3A+3B: Context builders LLM
- `_build_llm_biome_context()`: prompt systeme riche (biome, gardien, ogham, saison, atmosphere, aspects, jour, outil, condition)
- `_build_merlin_comment_context()`: prompt pour Merlin (ton amuse/cynique)

#### Etape 3C: Fallback intelligent
- `_detect_aspect_category()`: detecte si Corps/Ame/Monde est extreme
- `_get_fallback_text()`: selection par categorie + unseen tracking (pas de repetition)
- `_pick_unseen_variant()`: cycle a travers les 5 variantes sans doublon

#### Etape 3D: Prefetch parallele
- LLM lance des Phase 1 (Brume), tourne pendant les 6-8s d'animation
- `_start_llm_prefetch()`: fire-and-forget, arrival + merlin en parallele
- `_consume_prefetch()`: attend max 3s supplementaires, puis fallback JSON

#### Etape 3E: Validation LLM (guardrails)
- Rejet si < 10 chars ou > 300 chars
- Rejet si mots anglais detectes (the, and, you, are...)
- Rejet si similarite Jaccard > 0.7 avec le dernier texte
- Fallback JSON automatique en cas de rejet

---

## Session: 2026-02-11 (Phase 40 — Refonte HubAntre + TransitionBiome + TriadeGame)

### Phase 40: UI Overhaul (Expedition System + Fog + Card Flip + Resources)
- **Status:** complete (9/10 sub-phases, Phase 2A deferred)

#### Phase 1A: Standardiser icones bottom bar HubAntre
- ICON_STANDARDS constant (size=24, line_thickness=1.5, detail_thickness=1.0)
- All 9 celtic icon types unified, bottom bar reduced from 4 to 2 tabs (Antre + Compagnons)

#### Phase 1B+1C: Systeme d'expedition complet
- 3-step expedition prep: Destination + Outil + Conditions de depart
- EXPEDITION_TOOLS (4 tools with bonus_field/dc_bonus) in merlin_constants.gd
- DEPARTURE_CONDITIONS (4 options with initial_effects) in merlin_constants.gd
- Merlin reactive comments per selection (EXPEDITION_MERLIN_REACTIONS)
- Partir button greyed until all 3 steps complete
- Tool/condition data passed to GameManager.run

#### Phase 2B: Zoom camera TransitionBiome
- pixel_container.scale tween 1.0 → 1.4 after revelation phase (1.5s CUBIC)
- Reset to 1.0 before dissolution

#### Phase 2C: Brouillard volumetrique
- 3 particle layers (Back/Mid/Front) with per-biome tint from FOG_CONFIG
- Radial GradientTexture2D (64px) for soft particles
- Shader-based volumetric fog (ColorRect, Perlin noise + vertical gradient)
- 7 biome configs with direction/speed/tint

#### Phase 3A: Card display agrandi + flip animation
- Card panel 380x280 → 460x360, portrait 68 → 96px
- Flip entrance: rotation 90→0 (ELASTIC), scale 0.8→1.0 (BACK), fade-in

#### Phase 3B: Hover preview effets options
- Tooltip panel showing DC + aspect shift previews on option hover
- Dynamic state preview: "Corps ↑ (Robuste → Surmene)" with danger coloring
- Supports SHIFT_ASPECT, ADD_KARMA, ADD_SOUFFLE, PROGRESS_MISSION effects

#### Phase 3C: Top bar enrichie
- Animal icons 40x36 → 56x48
- Shift arrows (↑ red / ↓ blue) after each aspect change
- Resource bar: equipped tool + day counter + mission progress
- Souffle dots 20 → 28px

#### Phase 3D: Souffle VFX
- Regen: scale bounce 0.3→1.2→1.0 per gained dot
- Consumption: shrink 0.5 then restore
- Full (7/7): golden glow + SFX
- Empty (0/7): blink 3x red

#### Phase 3E: Mini-jeux integres + bonus outil
- Minigame intro overlay (field icon + name + tool bonus display)
- Tool bonus DC modifier in _run_minigame (matches bonus_field to detected field)
- Score→D20 feedback display before dice confirmation
- Resource bar sync in _sync_ui_with_state

#### Validation
- Static analysis: PASSED (0 errors, 1 unrelated warning)
- Affected scene validation: 6/6 PASSED (HubAntre, MapMonde, MenuPrincipal, SceneRencontreMerlin, TransitionBiome, TriadeGame)

#### Remaining: Phase 2A (Textes dynamiques + JSON enrichi)
- Deferred: requires ~140 text variants in post_intro_dialogues.json + LLM context builder

---

## Session: 2026-02-10b (Phase 39 — Runtime Error Fixing + Affected Scene Validation Tool)

### Phase 39: Runtime Error Fixing + Validation Pipeline Enhancement
- **Status:** complete

#### Fix TransitionBiome.gd — 17 unsafe get_tree() calls
- Root cause: `await` yields while node exits scene tree, `get_tree()` returns null
- Added `_safe_wait(seconds)` and `_safe_frame()` helper methods with `is_inside_tree()` guards
- Replaced ALL 15 `get_tree().create_timer()` + 2 `get_tree().process_frame` calls
- Added guard on `get_tree().change_scene_to_file()` in dissolution callback
- **Result:** 0 unprotected get_tree() calls remaining

#### MCP Godot Capabilities Assessment
- Project info, scripts, scene structure: OK
- `execute_editor_script`: KO (parse error 43)
- Debugger/runtime logs: NOT accessible via MCP
- **Alternative found:** Read Godot logs from `AppData\Roaming\Godot\app_userdata\DRU\logs\`

#### New Tool: validate_affected_scenes.ps1
- Auto-detects modified .gd via `git diff` (staged + unstaged + untracked)
- Dynamically maps scripts to scenes by scanning .tscn files
- Detects autoload/addon scripts and adds representative scenes
- Launches each scene in Godot headless mode with timeout
- Captures stdout/stderr, reports errors/warnings/crashes
- PS 5.1 compatible (no .NET method calls)
- Integrated into `validate.bat` as Step 4 (automatic)
- **Test result:** 6/6 scenes PASS (HubAntre, MapMonde, MenuPrincipal, SceneRencontreMerlin, TransitionBiome, TriadeGame)

#### validate.bat Pipeline (updated)
1. Runtime logs analysis
2. GDScript static analysis (63 files)
3. GDExtension check
4. **NEW: Affected scene validation** (headless Godot, git-diff targeted)
5. Optional: `--smoke` full scene sweep

---

## Session: 2026-02-10 (Phase 37 — Stabilisation + Fusion Triade/BrainPool + LLM Rencontre + Nettoyage)

### Phase 37: Stabilisation + Fusion Triade/BrainPool + LLM Rencontre + Nettoyage
- **Status:** complete
- **Plan:** `.claude/plans/swift-dancing-crane.md`
- **Agents:** Plan (architecture), Explore (codebase audit)

#### T1: Fix HubAntre parse error (line 2056)
- `:=` avec `instantiate()` remplace par type explicite `var map_instance: Control`

#### T2: Fix Triade crash complet
- Root cause: chaine async non-protegee `_async_card_dispatch()` → `store.dispatch(TRIADE_GET_CARD)` → `merlin.generate_card()`
- **triade_game_controller.gd**: null guards complets, trace logging, emergency fallback card
- **triade_game_ui.gd**: `is_instance_valid()` sur show_thinking/hide_thinking/display_card/show_narrator_intro
- **merlin_store.gd**: null checks TRIADE_GET_CARD handler (merlin, llm, card result)
- **merlin_omniscient.gd**: `_emergency_card()`, `_safe_fallback()`, null checks generate_card

#### T6: Warnings cleanup
- `merlin_map_system.gd`: `config` → `_config` (unused param)
- `merlin_effect_engine.gd`: `var story_log = ...` → `var story_log: Array = ...`

#### T3a-T3l: Fusion Triade ← TestBrainPool (MAJEUR)
- **triade_game_controller.gd** — v0.4.0 → v1.0.0 (~350 lignes ajoutees):
  - D20 Dice system: DC 6/10/14, 4 outcomes (crit success/success/failure/crit failure)
  - 15 minijeux branches via MiniGameRegistry (70% chance, 100% critique)
  - Critical choice system (karma extreme, 2+ extreme aspects, 15% random)
  - Flux system branche: `TRIADE_UPDATE_FLUX` dispatch apres chaque choix
  - Talents branches: shields Corps/Monde, free center, -30% negatifs, equilibre bonus
  - Biome passives branches: trigger every N cards
  - Karma (-1 left, +1 right, ±2 crits) + Blessings (absorbe game over)
  - Adaptive difficulty: pity (3 echecs → DC-4), challenge (3 succes → DC+2)
  - Run rewards: essences, fragments, liens, gloire en fin de run
  - 16 templates reactions narratives (4 outcomes × 4 messages)
  - Travel fog animation entre cartes
  - RAG context file (5 derniers choix+resultats)
  - SFX choreographie complète
- **triade_game_ui.gd** — ~250 lignes ajoutees:
  - `show_dice_roll()` — animation D20 2.2s deceleration + bounce elastique
  - `show_dice_instant()` — affichage apres minijeu
  - `show_dice_result()` — texte + couleur outcome
  - `show_travel_animation()` — full-screen fog overlay
  - `show_reaction_text()` — reaction narrative
  - `show_critical_badge()` — bordure doree pulsante
  - `show_biome_passive()` — notification biome
  - `animate_card_outcome()` — shake/pulse par outcome

#### Store gaps fixes
- **merlin_store.gd**: Ajout action `TRIADE_UPDATE_FLUX` (delta dict → clampi flux axes)
- **merlin_store.gd**: `_resolve_triade_choice()` accepte `modulated_effects` optionnel — evite double application effets/souffle
- **triade_game_controller.gd**: `are_all_aspects_balanced()` → `is_all_aspects_balanced()` (nom correct du store)

#### T3m + T5: Archive scenes inutiles
- Deplace vers `archive/`: TestBrainPool, TestLLMSceneUltimate, TestLLMBenchmark, GameMain (.tscn + .gd + .uid)
- SceneSelector.gd: retire 4 entrees (GameMain, TestLLMSceneUltimate, LLM Benchmark, TestBrainPool)
- MenuPrincipalReigns.gd: retire "Test Brain Pool" du menu

#### T4: SceneRencontreMerlin — LLM dynamique
- `_llm_rephrase(text, emotion)` — reformulation par `generate_voice()`, timeout 5s, fallback original
- `_llm_generate_responses(context, index)` — 3 reponses joueur par `generate_narrative()`, parse JSON, timeout 8s
- Phase 1 (Eveil): chaque ligne rephrased + reponses LLM aux moments interactifs
- Phase 2 (Bestiole): chaque ligne rephrased
- Phase 5 (Mission): chaque ligne rephrased
- Prefetch: `_prefetch_rephrase()` lance la ligne suivante pendant l'affichage courante

#### Validation finale: 63 fichiers GDScript, 0 erreur statique, GDExtension OK

#### Fichiers modifies (8)
| Fichier | Taches |
|---------|--------|
| `scripts/HubAntre.gd` | T1 |
| `scripts/ui/triade_game_controller.gd` | T2, T3a-l, store gaps |
| `scripts/ui/triade_game_ui.gd` | T2, T3a-l |
| `scripts/merlin/merlin_store.gd` | T2, TRIADE_UPDATE_FLUX, modulated_effects |
| `addons/merlin_ai/merlin_omniscient.gd` | T2 |
| `scripts/merlin/merlin_map_system.gd` | T6 |
| `scripts/merlin/merlin_effect_engine.gd` | T6 |
| `scripts/SceneRencontreMerlin.gd` | T4 |
| `scripts/autoload/SceneSelector.gd` | T5 |
| `scripts/MenuPrincipalReigns.gd` | T5 |

#### Boucle gameplay attendue
`HubAntre → TransitionBiome → TriadeGame → [D20/Minijeux/Flux/Talents/Rewards] → HubAntre`

---

## Session: 2026-02-09 (Phase 36 — Meta-Progression + Arbre de Vie + Flux)

### Phase 36: Meta-Progression + Arbre de Vie + Balance des Flux
- **Status:** complete
- **Agents:** Plan (x3 parallel), Explore (codebase audit)
- **Files modified:** merlin_constants.gd, merlin_store.gd, TestBrainPool.gd, HubAntre.gd, prompt_templates.json

#### Sous-Phase 1: Backend (Donnees + Constantes)
- Ajout constantes Flux (FLUX_START, FLUX_CHOICE_DELTA, FLUX_ASPECT_OFFSET, FLUX_TIERS, FLUX_HINTS) dans merlin_constants.gd
- Ajout 28 TALENT_NODES (Racines/Ramures/Feuillage/Tronc) avec couts en 14 essences + fragments
- Ajout constantes evolution Bestiole (3 stades, 3 sous-chemins)
- Ajout TALENT_BRANCH_COLORS, TALENT_TIER_NAMES
- Ajout meta.talent_tree + meta.bestiole_evolution dans merlin_store.gd
- Fonctions: is_talent_active(), can_unlock_talent(), unlock_talent(), get_affordable_talents()
- Fonctions: calculate_run_rewards(), apply_run_rewards(), check_bestiole_evolution(), evolve_bestiole()

#### Sous-Phase 2: Systeme de Flux (in-run, cache)
- 3 axes caches: Terre (environnement), Esprit (recit), Lien (difficulte) — 0 a 100
- Mise a jour apres chaque choix (gauche/centre/droite) + influence passive des Aspects
- DC modifie par Flux Lien (calme: -2, brutal: +3)
- Contexte Flux envoye au LLM Narrateur via prompt_templates.json
- Feedback subtil via texte Merlin (pas de chiffres visibles au joueur)
- Monitor debug: affichage Flux et tiers

#### Sous-Phase 3: Recompenses de fin de run
- 14 types d'essences gagnees selon conditions (victoire, chute, flux, equilibre, bond, mini-jeux, oghams)
- Fragments d'Ogham: 1 + floor(awen_spent/3)
- Liens: 2 + mini-jeux + score bonus
- Gloire: floor(score/50)
- Affichage detaille sur ecran de fin de run

#### Sous-Phase 4: Arbre de Vie — UI Hub (4eme onglet)
- Nouvel onglet "Arbre" dans HubAntre.gd (page 4)
- 28 noeuds organises par tier (Germe → Pousse → Branche → Cime)
- Noeuds: gris (verrouille), or (achetable), colore (debloque)
- Hover: nom + cout + description + lore
- Click: debloquer si affordable (essences + fragments)
- Affichage essences collectees + devises (fragments, liens, gloire)
- Legende des branches (Sanglier/Tronc/Corbeau/Cerf)

#### Sous-Phase 5: Talents actifs + Evolution Bestiole
- _apply_talent_bonuses() appele au debut de chaque run
- Talents de depart: racines_1 (+1 Souffle), racines_3 (+1 Benediction), racines_6 (+2 Souffle max), feuillage_2 (centre gratuit), tronc_1 (Flux 50/50/50)
- Boucliers: racines_2 (Corps 1er shift BAS annule), feuillage_1 (Monde 1er shift HAUT annule)
- DC: feuillage_4 (critique DC +2 au lieu de +4)
- Equilibre: racines_5 (+2 Souffle au lieu de +1 quand 3 aspects a 0)
- Reduction: feuillage_7 (effets negatifs -30%)
- SOUFFLE_MAX dynamique via _souffle_max
- Evolution Bestiole: verification en fin de run, 3 stades (Enfant → Compagnon → Gardien)
- Affichage stade dans onglet Bestiole du Hub

---

## Session: 2026-02-09 (Phase 35 — Project-Wide Resource Cleanup)

### Phase 35: Nettoyage Complet des Ressources Projet
- **Status:** complete
- **Agents:** Project Curator, Explore (audit)

#### Objectif
Audit complet du projet et suppression de ~751 MB de fichiers morts/obsoletes.

#### Changements
1. **8 fichiers junk racine** — Supprimes (nul, chemins corrompus, anciens scripts PPT, AGENTS.md doublon)
2. **19 scripts morts** — Supprimes (3D/FPS, Reigns UI, anciens managers, shaders experimentaux)
3. **archive/artifacts/** — Supprime (390 MB artefacts Colab LLM)
4. **Godot/** — Archive vers archive/3d_models/ (86 fichiers .glb, 11 MB)
5. **orange_brand_assets/** — Deplace vers Bureau/Agents/Data/ (350 MB)
6. **tools/** — 15 fichiers JSON benchmark supprimes, 3 scripts one-time archives
7. **.gitignore** — Mis a jour (benchmark results, node_modules, artifacts)

#### Scripts supprimes (Phase 2):
- 3D/FPS: player_fps, sea_animation, seagull_flock, lighthouse_beacon, day_night_cycle, exterior_window, flickering_light, ground_mist, volumetric_fog_ps1, merlin_house_animations
- Shaders: ps1_shader_controller, retro_viewport, pixel_shader_controller
- Remplaces: reigns_game_controller, reigns_game_ui, LLMManager, main_game, MerlinPortraitManager, test_merlin

#### Scripts preserves (travail futur):
- minigames/ (16 fichiers — P1.1), bestiole_wheel_system, merlin_event/map/minigame_system, merlin_action_resolver
- pixel_character_portrait, custom_cursor, pixel_merlin_portrait (recents)

#### Validation: 65 fichiers GDScript 0 erreur statique, GDExtension OK

---

## Session: 2026-02-09 (Phase 34 — Mini-Jeux + Dual-Brain + Dice VFX + Resource Overhaul)

### Phase 34: Refonte Gameplay Majeure
- **Status:** complete
- **Phases:** A (Ressources), B (Dual-Brain), C (Dice VFX), D (15 Mini-Jeux), E+F (Choix Critique), G (Animations)

#### Phase A: Fix Ressources + Equilibrage
- Aspects etendus de [-2,+2] a [-3,+3], game over a abs>=3
- Fix bug critique: `_apply_crit_success()` ne provoque plus de game over
- Nouveau: Karma visible [-10,+10], Benedictions (bouclier, max 2)
- Souffle max 5, regen: +1 succes, +2 crit, +1 equilibre parfait
- Difficulte adaptative (pity mode apres 3 echecs, DC+2 apres 3 succes)

#### Phase B: Integration Dual-Brain
- `generate_parallel()` — Narrateur + Maitre du Jeu en simultane
- Nouveau GBNF: `gamemaster_choices.gbnf` (labels + minigame + effets)
- Nouveau template: `gamemaster_choices` dans prompt_templates.json
- Fallback 3 niveaux: GM complet → labels GM + effets heuristiques → tout heuristique

#### Phase C: Dice VFX + Audio
- De avec deceleration organique + bounce a l'atterrissage + rotation wobble
- CPUParticles2D par outcome (40 dorees crit, 15 vertes succes, 20 rouges echec, 30 fumee crit fail)
- 5 nouveaux SFX dice: shake, roll, land, crit_success, crit_fail
- Choregraphie complete: shake → roll → deceleration → land → particles → outcome

#### Phase D: 15 Mini-Jeux par Champs Lexicaux
- Architecture: MiniGameBase + MiniGameRegistry + 15 jeux
- 5 champs: chance, bluff, observation, logique, finesse (3 jeux chacun)
- Selection par keywords narratifs ou hint du GM
- Conversion score 0-100 → D20
- 5 SFX mini-jeux: start, success, fail, tick, critical_alert
- Modificateurs Ogham (+10% score par affinite)

#### Phase E+F: Choix Critique + Adaptation Quete
- Declenchement: 15% base apres carte 3, force si karma>=5 ou 2+ aspects danger
- DC +4, mini-jeu diff +3, bordure doree pulsante + SFX critical_alert
- Historique quest_history pour difficulte adaptative
- Travel text adapte aux outcomes recents et aspects en danger
- Benediction sur fin de sous-quete

#### Phase G: Animations Globales
- Boutons: hover scale 1.05 + SFX hover, press scale 0.95 + SFX click
- Carte: entree "depercheminement" (scaleY 0→1 + fade)
- Jauges aspects: tween 0.3s, couleur orange zone danger
- Travel: SFX mist_breath, texte adapte
- Carte draw: SFX card_draw

#### Fichiers crees (18 nouveaux)
- `scripts/minigames/minigame_base.gd` — Classe de base
- `scripts/minigames/minigame_registry.gd` — Registre par champs lexicaux
- `scripts/minigames/mg_*.gd` — 15 mini-jeux
- `data/ai/gamemaster_choices.gbnf` — Grammaire GM choix

#### Fichiers modifies (2)
- `scripts/TestBrainPool.gd` — Refonte complete (ressources, dual-brain, mini-jeux, VFX, choix critique, animations)
- `scripts/autoload/SFXManager.gd` — 10 nouveaux sons proceduraux (5 dice + 5 mini-jeux)
- `data/ai/config/prompt_templates.json` — Nouveau template gamemaster_choices

---

## Session: 2026-02-09 (Phase 33 — Documentation Cleanup v4.0)

### Phase 33: Menage Extensif Documentation
- **Status:** complete
- **Agents:** Technical Writer, Project Curator

#### Objectif
Mise a jour complete de toute la documentation du projet apres 32+ phases d'evolution.

#### Changements
1. **MASTER_DOCUMENT.md** — Reecrit v4.0 (Triade + Multi-Brain + architecture complete)
2. **CLAUDE.md** — Mis a jour (params LLM Narrator/GM, architecture, scene flow)
3. **docs/README.md** — Reecrit v4.0 (129 fichiers indexes, statuts corrects)
4. **progress.md** — Archive 3920 lignes anciennes, garde phases 25-32 recentes
5. **task_plan.md** — Nettoye (phases obsoletes supprimees, backlog mis a jour)
6. **Dashboard Frontend** — Cree (`docs/dashboard.html`, dark theme, stats projet)
7. **Legacy docs** — 4 fichiers deplaces vers `docs/old/` (DOC_02, ALTERNATIVES, merlin_rag_cadrage, SPEC_Optimisation)
8. **MOS_ARCHITECTURE.md** — Corrige "DRU STORE" -> "MERLIN STORE"
9. **STATE_Claude_MerlinLLM.md** — Corrige Trinity-Nano -> Qwen2.5-3B-Instruct

---

## Session: 2026-02-09 (Phase 32 — Multi-Brain LLM Architecture)

### Phase 32: Multi-Brain + Worker Pool — Architecture 2-4 Cerveaux Qwen2.5-3B
- **Status:** complete
- **Agents:** LLM Expert, Lead Godot

#### Objectif
Architecture LLM adaptative 2-4 cerveaux avec worker pool:
- **Brain 1 — Narrator** (toujours present): texte creatif, scenarios, dialogues
- **Brain 2 — Game Master** (desktop+): effets JSON, equilibrage, regles (GBNF)
- **Brain 3-4 — Worker Pool**: taches de fond (prefetch, voice, balance)
- **Avec 2 cerveaux**: les primaires font aussi les taches de fond quand idle (transparent)

#### Architecture
```
MerlinOmniscient
    ├── generate_parallel() ─┬── Brain 1 Narrator → texte + labels
    │                        └── Brain 2 Game Master (GBNF) → effets JSON
    │                                     ↓ merge → carte TRIADE
    └── Pool tasks ──────────┬── Pool Worker (3+) si disponible
                             └── Idle Primary (2 brains) si pas de worker
                                  ↓
                             prefetch, voice, balance (en fond)
```

#### Configuration par plateforme (auto-detection):
| Plateforme            | Cerveaux | RAM      | Detection              |
|-----------------------|----------|----------|------------------------|
| Web (WASM)            | 1        | ~2.5 GB  | `OS.has_feature("web")`|
| Mobile entry/mid      | 1        | ~2.5 GB  | CPU < 8 cores          |
| Mobile flagship 2024+ | 2        | ~4.5 GB  | CPU >= 8 cores         |
| Desktop mid           | 2        | ~4.5 GB  | CPU >= 6 threads       |
| Desktop high-end      | 3        | ~6.5 GB  | CPU >= 12 threads      |
| Desktop ultra         | 4        | ~8.8 GB  | CPU >= 16 threads      |

#### Changements (Phase 32.A-F — dual-instance initiale):
1. **merlin_ai.gd** — narrator_llm + gamemaster_llm, generate_parallel()
2. **merlin_omniscient.gd** — _try_parallel_generation(), _merge_parallel_results()
3. **merlin_llm_adapter.gd** — evaluate_balance(), suggest_rule_change()
4. **Fichiers data**: prompt_templates.json, gamemaster_effects.gbnf, few-shot examples

#### Changements (Phase 32.J — Worker Pool 2-4 cerveaux):
5. **merlin_ai.gd** — Worker Pool complet:
   - `BRAIN_QUAD := 4`, `BRAIN_MAX`, `_pool_workers[]`, `_pool_busy[]`
   - Busy tracking: `_primary_narrator_busy`, `_primary_gm_busy`
   - `_lease_bg_brain()` / `_release_bg_brain()` — pool worker > idle primary
   - `_process()` — polling fire-and-forget + dispatch queue
   - `submit_background_task()`, `_fire_bg_task()`, `_dispatch_from_queue()`
   - `generate_prefetch()` — lease/release via pool (await)
   - `generate_voice()` — commentaires Merlin via pool (await)
   - `submit_balance_check()` — equilibre fire-and-forget
   - generate_narrative/structured/parallel: busy tracking

6. **merlin_omniscient.gd** — Pool integration:
   - `_prefetch_via_pool()` — remplace `_prefetch_with_brain3()`
   - `_generate_merlin_comment()` → `generate_voice()` via pool

#### Changements (Phase 32.O — Test Suite + QA Review):
7. **tools/test_brain_pool.mjs** — External test suite (148/148 tests):
   - 15 suites: constants, detection, pool arch, bg tasks, generation,
     model init, mode names, accessors, omniscient integration, data files,
     busy flag consistency, backward compat, cross-file, simulated pool, signals
   - Simulated pool scenarios: 1/2/3/4 brains, lease/release, priority queue

8. **scripts/TestBrainPool.gd + scenes/TestBrainPool.tscn** — In-game test scene:
   - 6 test categories: current mode, all modes (2→3→4), pool logic,
     background tasks, parallel generation, prefetch+voice
   - Full suite runner with sequential execution

9. **merlin_ai.gd — QA fixes** (from debug_qa agent review):
   - `BG_QUEUE_MAX_SIZE := 100` — prevents unbounded queue growth
   - `BG_TASK_TIMEOUT_MS := 30000` — detects stuck background tasks
   - `start_time` added to active bg tasks for timeout tracking
   - `is_instance_valid()` checks in `_lease_bg_brain()`
   - `reload_models()` cancels active bg tasks before reinit
   - `_process()` handles invalid brain instances + timeout detection

10. **gdscript_knowledge_base.md** — 7 new corrections logged

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32bis: TestBrainPool Interactive Quest Showcase + Bug Fixes
- **Status:** complete
- **Agents:** Lead Godot

#### Bug fixes (Godot debugger errors):
1. **merlin_llm_adapter.gd:347** — `var score: int =` (was `:=`, `max()` returns Variant)
2. **merlin_card_system.gd:281** — Added `await` on `_llm.generate_card(context)` (coroutine)
3. **merlin_store.gd:386** — Added `await` on `cards.get_next_card(state)` (cascade)

#### Scene selector + Menu integration:
4. **SceneSelector.gd** — Added TestBrainPool to SCENES array
5. **MenuPrincipalReigns.gd** — Replaced "Benchmark TRIADE" with "Test Brain Pool"

#### TestBrainPool.gd — Complete rewrite as Interactive Quest Showcase (~1230 lines):
- Phase state machine: IDLE → GENERATING → CARD_SHOWN → EFFECTS_SHOWN → MINIGAME → QUEST_END
- 3 quest templates with sub-quests (Brume, Chant, Sanglier)
- Card generation via `generate_parallel()` with brain attribution (Narrator + GM timing)
- Mini-games between cards: D20 dice rolls + lore riddles (8 questions)
- Prefetch system: generates next card during mini-game
- Brain activity monitor: real-time bars (load%, RAM) + activity log with timestamps
- Aspect gauges (Corps/Ame/Monde) + Souffle tracking
- 7 fallback cards when LLM unavailable
- Quest end: victory (5 survived) or chute (extreme aspect / souffle=0)

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32ter: RPG Mechanics + Travel Animations + RAG Context
- **Status:** complete
- **Agents:** Lead Godot

#### Changements majeurs (TestBrainPool.gd — rewrite complet ~1307 lignes):
1. **Effets caches** — Les boutons de choix n'affichent que les labels (Prudence/Sagesse/Audace), pas les effets. Le joueur ne sait pas ce qui va se passer.
2. **Systeme de de D20** — Apres chaque choix, jet de de avec Difficulty Class:
   - Gauche (prudent): DC 6 — facile
   - Centre (equilibre): DC 10 — moyen, coute du Souffle
   - Droite (audacieux): DC 14 — difficile, gros risque/recompense
   - Nat 20: Coup Critique (double positif, pas de cout)
   - >= DC: Reussite (effets normaux)
   - < DC: Echec (effets inverses)
   - Nat 1: Echec Critique (effets negatifs amplifies + -1 Souffle)
3. **Animations de voyage** — Brume/fog overlay entre chaque carte avec textes immersifs celtiques
4. **Contexte RAG** — Fichier `user://brain_pool_context.txt` stocke les 5 derniers evenements, injecte dans le prompt au lieu de faire grandir le contexte
5. **Narrator-only** — Plus de Game Master call (crash GBNF + latence inutile). Effets generes par heuristique equilibree basee sur l'etat du jeu
6. **Effets equilibres** — `_generate_balanced_effects()` analyse aspects faibles/forts pour proposer des choix strategiques
7. **Animation de chargement** — Symboles celtiques animes (◎◉●◐◑◒◓) pendant la generation LLM
8. **Prefetch pendant lecture** — Le prefetch demarre des que la carte est affichee (pendant que le joueur lit), pas entre les cartes
9. **Nettoyage** — Suppression de ~50 print() debug, suppression du code riddle/minigame separee, code plus propre

#### Orchestration cerveaux (revue):
- Narrateur seul genere les cartes (~14s) — pas de GM sequentiel qui doublait la latence
- GM en standby (disponible pour prefetch ou voice si besoin)
- Effets par logique de jeu, pas par LLM (plus rapide + plus equilibre)

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32quater: Systeme de Buffer Continu (Pre-generation)
- **Status:** complete
- **Agents:** Lead Godot

#### Changements (TestBrainPool.gd):
1. **Buffer continu** — `BUFFER_SIZE=3` cartes pre-generees en permanence. Remplace le prefetch simple (1 carte).
2. **_continuous_refill()** — Boucle async qui remplit le buffer tant que `_quest_active`. Se relance automatiquement quand on pop une carte.
3. **_pop_card_from_buffer()** — Pop FIFO du buffer + relance refill si besoin.
4. **Chargement initial** — Au lancement de quete, genere 1 carte (affichee immediatement), puis demarre le refill en arriere-plan.
5. **Loading flavor texts** — 8 textes immersifs celtiques qui tournent pendant le chargement (ex: "Les runes s'assemblent dans la brume...").
6. **Moniteur buffer** — Affiche `Buffer: X/3` en couleur (vert=plein, jaune=partiel, rouge=vide) + indicateur "(refill...)".
7. **_show_travel** utilise le buffer (pop) au lieu du prefetch. Si buffer vide, fallback sur generation on-demand.
8. **_show_quest_end** arrete le buffer (`_quest_active=false`, `_card_buffer.clear()`).

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

---

## Session: 2026-02-09 (Phase 31 — Switch to Qwen2.5-3B-Instruct)

### Phase 31: Model Switch — Trinity-Nano → Qwen2.5-3B-Instruct
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA

#### Objectif
Remplacer Trinity-Nano (bon conteur, 0% logique) par un modele capable de narratif ET logique.

#### Benchmark comparatif (CPU Ryzen 5 PRO, 12 tests):
| Modele | Taille | Comprehension | Logique | Role-play | JSON | Latence 1 mot |
|--------|--------|:------------:|:-------:|:---------:|:----:|:-------------:|
| Trinity Q4 | 3.6 GB | 58% | 0% | 100% | 50% | 940ms |
| Trinity Q5 | 4.1 GB | 50% | 0% | 100% | 50% | 989ms |
| Trinity Q8 | 6.2 GB | 50% | 33% | 100% | 50% | 847ms |
| Phi-3 Mini | 2.3 GB | 42% | 67% | 33% | 0% | 1627ms |
| **Qwen2.5-3B** | **2.0 GB** | **83%** | **100%** | **100%** | **100%** | **726ms** |

#### Changements:
1. **Modeles supprimes:** Trinity-Nano Q4/Q5/Q8 (~14 GB liberes)
2. **Modele ajoute:** qwen2.5-3b-instruct-q4_k_m.gguf (2.0 GB)
3. **Fichiers GDScript modifies (10):**
   - merlin_ai.gd: ROUTER/EXECUTOR → qwen2.5, params ajustes
   - merlin_llm_adapter.gd: commentaire modele
   - merlin_omniscient.gd: commentaire system prompt
   - LLMManager.gd: MODEL_PATH → qwen2.5
   - llm_status_bar.gd: dictionnaire modeles
   - TestLLMScene.gd, TestLLMSceneUltimate.gd: modeles
   - TestLLMBenchmark.gd: titre benchmark
   - test_merlin.gd: model_path
   - IntroCeltOS.gd: affichage "LLM: Qwen2.5-3B"
   - rag_manager.gd: commentaire header
4. **Doc mise a jour:** CLAUDE.md, PLACE_MODEL_HERE.txt, README.txt
5. **Outil de test cree:** tools/test_llm_raw.mjs (latence + comprehension)

#### Validation: 66 fichiers GDScript 0 erreur, GDExtension OK

---

## Session: 2026-02-09 (Phase 30 — GBNF Grammar + Two-Stage + Q5 Default)

### Phase 30: Constrained Decoding + Two-Stage Fallback + Model Switch
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA
- **Output:** 5 fichiers modifies + 1 fichier cree, validation 66 fichiers 0 erreur

#### Objectif
Ameliorer la fiabilite de la generation JSON par le nano-modele (benchmark: 20-60% validite).

#### Changements:

1. **native/src/merlin_llm.h + merlin_llm.cpp** — GBNF Grammar support dans GDExtension:
   - `set_grammar(grammar_str, root)`: configure une grammaire GBNF pour le decodage contraint
   - `clear_grammar()`: desactive la grammaire pour les appels suivants
   - Grammar sampler insere dans la chaine llama.cpp (apres top_p, avant greedy)
   - Utilise `llama_sampler_init_grammar()` de llama.cpp natif
   - **Necessite recompilation du GDExtension pour activation**

2. **data/ai/triade_card.gbnf** — Grammaire GBNF pour cartes TRIADE:
   - Force JSON valide avec schema exact (text, speaker, 3 options, effects)
   - Contraint aspects: "Corps" | "Ame" | "Monde"
   - Contraint direction: "up" | "down"
   - Force speaker: "merlin"
   - Option centre avec cost obligatoire
   - String flexible pour texte narratif et labels

3. **addons/merlin_ai/merlin_ai.gd** — Propagation grammar:
   - `generate_with_system()` supporte `params.grammar` et `params.grammar_root`
   - Set grammar avant generation, clear apres
   - Log "Grammar constrained decoding active" quand utilise
   - **Default model change: Q4_K_M → Q5_K_M** (+40pp qualite, +600MB RAM)

4. **scripts/merlin/merlin_llm_adapter.gd** — Pipeline de generation ameliore:
   - Chargement automatique de la grammaire GBNF au demarrage
   - Grammar passee dans les params LLM si disponible
   - **Two-stage generation fallback** (nouveau):
     - Stage 1: LLM genere du texte narratif libre (pas de JSON)
     - Stage 2: Extraction labels + wrapping JSON programmatique
     - Effets intelligents bases sur l'etat des aspects (boost le plus bas, etc.)
   - Flux revu: grammar → JSON parse → two-stage → erreur
   - Marquage `two_stage` dans les tags de carte

#### Architecture generation (Phase 30):
```
generate_card(context)
  │
  ├─[1] Grammar-constrained generation (si GDExtension recompile)
  │     GBNF force JSON valide → parse + validate
  │     Expected: ~95% validite
  │
  ├─[2] Post-processing 4-stage repair (existant)
  │     parse → fix → repair → regex
  │     Current: 20-60% validite
  │
  └─[3] Two-stage fallback (NOUVEAU)
        Stage 1: texte libre → Stage 2: JSON wrapper
        Expected: ~80% validite (texte OK, effets programmatiques)
```

#### Benchmark Two-Stage (Q5_K_M, 10 runs CPU):
| Approche | JSON Valid | Schema OK | Note |
|----------|-----------|-----------|------|
| Q4 JSON direct | 20% | 20% | Baseline (Phase 29) |
| Q5 JSON direct | 60% | 40% | Meilleur quant |
| **Q5 Two-Stage** | **100%** | **80%** | JSON garanti, texte variable |

Labels extraits du LLM: 20% (80% utilisent labels par defaut).
Echecs: check francais ("not enough French words") sur texte trop court.

#### GDExtension Build (Session continuation):
- **Status:** SUCCESS
- **Erreurs corrigees:**
  - `llama_n_vocab(model)` → `llama_n_vocab(vocab)` (API changee dans llama.cpp recent)
  - `llama_sampler_init_penalties()` simplifie: 9 args → 4 args (n_vocab, eos, nl, penalize_nl, ignore_eos retires)
  - RuntimeLibrary mismatch: llama.cpp rebuild avec `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` (MT statique)
- **Build 3 stages:**
  - Stage 1: godot-cpp (scons) — OK
  - Stage 2: llama.cpp (cmake/ninja, 211/211) — OK (rebuild MT)
  - Stage 3: merlin_llm.dll (cmake/ninja, 3/3) — OK
- **DLL:** `addons/merlin_llm/bin/merlin_llm.windows.release.x86_64.dll` (353 KB)
- **Validation:** 66 fichiers GDScript 0 erreur, GDExtension OK

#### Prochaine etape:
- Tester GBNF grammar-constrained generation dans Godot (GPU)
- Benchmark grammar vs two-stage vs baseline in-game
- Fine-tuning LoRA si budget qualite insuffisant

---

## Session: 2026-02-09 (Standalone LLM Benchmark)

### Benchmark: Trinity-Nano Standalone Testing
- **Status:** complete
- **Tool:** `tools/benchmark_llm.mjs` (Node.js + node-llama-cpp)
- **Output:** 3 quantizations testees, fichiers JSON resultats

#### Resultats cles
| Modele | JSON valide | Schema OK | Latence CPU |
|--------|-------------|-----------|-------------|
| Q4_K_M | 20% | 20% | 21.5s |
| Q5_K_M | **60%** | **40%** | 19.0s |
| Q8_0 | 40% | 0% | 16.6s |

#### Problemes identifies
1. Modele copie les exemples du prompt au lieu de generer du contenu
2. JSON systematiquement malformed (virgules au lieu de `:`, types incorrects)
3. Switch FR/EN aleatoire
4. Latence CPU 7-33s (GPU sera 5-10x plus rapide)

#### Recommandations
- P0: GBNF Grammar (JSON contraint au niveau token) → ~95% validite
- P1: Fallback pool etendu (50-100 cartes)
- P2: Generation deux-etapes (texte libre → JSON template)
- P3: Q5_K_M comme defaut (+40pp qualite, +600MB RAM)
- P4: Fine-tuning LoRA (200-500 exemples)
- P5: Hybrid local/API pour mobile

---

## Session: 2026-02-09 (Async Pipeline + UX Masking + JSON Repair)

### Phase 29: Async Pre-Generation + UX Animation Masking + Advanced JSON Repair + Anti-Hallucination
- **Status:** complete
- **Agents:** LLM Expert, UI Impl, Debug/QA
- **Output:** 4 fichiers modifies, validation 66 fichiers 0 erreur

#### Objectif
Masquer la latence LLM (1-3s) derriere des animations et du pre-fetching. Ameliorer la robustesse JSON. Reduire les hallucinations du nano-modele.

#### Changements:
1. **merlin_omniscient.gd** — Async pre-generation pipeline:
   - `prefetch_next_card(game_state)`: pre-genere carte N+1 pendant que joueur lit carte N
   - `_try_use_prefetch()`: utilise la carte pre-generee si le contexte n'a pas change
   - `_compute_context_hash()`: hash aspects+souffle pour valider pertinence du prefetch
   - `invalidate_prefetch()`: annule le prefetch si etat change significativement
   - Stats: `prefetch_hits`, `prefetch_misses` pour monitoring
   - Context tightening: system prompt reduit a ~50 tokens, JSON template deplace dans user prompt
   - Instruction anti-hallucination: "Reponds UNIQUEMENT en JSON valide"

2. **triade_game_ui.gd** — Animation "Merlin reflechit":
   - `show_thinking()`: spirale celtique (triskelion) + dots animes sur la carte
   - `hide_thinking()`: restaure l'UI et les options
   - `_draw_thinking_spiral()`: dessine un triple spiral celtique avec rotation
   - Timer anime les dots "Merlin reflechit..." toutes les 400ms
   - Options dimmed (alpha 0.3) pendant la generation

3. **triade_game_controller.gd** — Wiring animation + prefetch:
   - `_request_next_card()`: show_thinking → generation → hide_thinking → display
   - `_trigger_prefetch()`: lance la pre-generation apres affichage carte
   - Delai transition reduit de 0.3s a 0.15s (card flip feel)

4. **merlin_llm_adapter.gd** — Advanced JSON repair (4 strategies):
   - Strategy 1: Parse standard `{...}` (existant)
   - Strategy 2: Fix erreurs courantes (trailing commas, single quotes, unquoted keys)
   - Strategy 3: `_aggressive_json_repair()` — fix troncature, nesting, caracteres speciaux
   - Strategy 4: `_regex_extract_card_fields()` — extraction regex text/labels/speaker/effects
   - System prompt compact + JSON template dans user prompt (anti-hallucination)

---

## Session: 2026-02-09 (RAG v2.0 + MOS Integration + Guardrails)

### Phase 28: RAG v2.0 + MOS-RAG Bridge + Output Guardrails
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA, Optimizer
- **Output:** 3 fichiers modifies majeurs, validation 66 fichiers 0 erreur

#### Audit LLM Pipeline — 6 problemes critiques:
1. Double model loading: router + executor = 2x MerlinLLM (~7.2 GB) → FIX: instance unique quand même modele
2. RAG primitif: keyword search 105 lignes → FIX: v2.0 450 lignes, token budget, priority enum
3. System prompt 500+ tokens: depasse contexte nano → FIX: ~80 tokens base + RAG dynamique 180 tokens max
4. MOS deconnecte du RAG → FIX: _sync_mos_to_rag() a chaque generation
5. Aucun guardrail → FIX: French language, Jaccard repetition, length bounds
6. Aucun journal → FIX: structured journal (card/choice/aspect/ogham/event) + cross-run memory

#### Changements:
1. **merlin_ai.gd** — Single model instance sharing (router == executor → 1 instance, saves ~3.6 GB)
2. **rag_manager.gd** — Rewrite complet v2.0:
   - Token budget management (CHARS_PER_TOKEN=4, CONTEXT_BUDGET=180)
   - Priority enum: CRITICAL(4), HIGH(3), MEDIUM(2), LOW(1), OPTIONAL(0)
   - Structured journal: card_played, choice_made, aspect_shifted, ogham_used, run_event
   - Cross-run memory: summarize_and_archive_run() avec run summaries compresses
   - World state sync from MOS registries
   - Journal search + persistence JSON
3. **merlin_omniscient.gd** — MOS-RAG bridge + guardrails:
   - _sync_mos_to_rag(): sync patterns, arcs, trust, session → RAG world state
   - _build_system_prompt(): compact ~80 tokens + rag.get_prioritized_context()
   - _build_user_prompt(): compact pour nano (aspects/souffle/jour/ton/themes)
   - _apply_guardrails(): French language check, Jaccard repetition detection, length bounds
   - record_choice(): log choice + aspect shifts dans RAG journal
   - on_run_end(): archive run dans cross-run memory
   - generate_card(): log card dans RAG journal
   - save_all(): sauvegarde journal + world state RAG
   - get_debug_info(): infos RAG (journal size, cross-runs, last ending)

---

## Session: 2026-02-09 (Trinity-Nano Migration)

### Phase 27: Migration Qwen → Trinity-Nano + Architecture LLM
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA, Optimizer, Project Curator
- **Output:** 10 fichiers modifies, 1 fichier cree, 1 fichier supprime, validation 66 fichiers 0 erreur

#### Changements:
1. **Suppression modele Qwen** — `qwen2.5-3b-instruct-q4_k_m.gguf` supprime (~2 GB liberes)
2. **merlin_ai.gd** — ROUTER_FILE + EXECUTOR_FILE recables vers Trinity-Nano Q4_K_M, candidates fallback Q4→Q5→Q8
3. **LLMManager.gd** — MODEL_PATH recable vers Trinity-Nano
4. **merlin_llm_adapter.gd** — Commentaires mis a jour (Qwen → Trinity)
5. **TestLLMBenchmark.gd** — Titre mis a jour
6. **test_merlin.gd** — model_path recable
7. **start_llm_server.sh** — Chemin modele recable
8. **PLACE_MODEL_HERE.txt** — Guide mis a jour avec 3 quantizations Trinity
9. **data/ai/models/README.txt** — Liste modeles mise a jour
10. **STATE_Claude_MerlinLLM.md** — Etat des lieux mis a jour
11. **TRINITY_ARCHITECTURE.md** — NOUVEAU: doc architecture complete (9 sections)

#### Architecture LLM apres cette session:
```
Modele: Trinity-Nano (modele unique, 3 quantizations)
  Q4_K_M (3.6 GB) — DEFAULT production
  Q5_K_M (4.1 GB) — Fallback equilibre
  Q8_0   (6.1 GB) — Fallback qualite

Pipeline: MerlinStore.TRIADE_GET_CARD
  ├── MerlinOmniscient (cache + registres)
  ├── MerlinLlmAdapter (Trinity-Nano + validation TRIADE)
  └── MerlinCardSystem (fallback pool)
```

---

## Session: 2026-02-09 (LLM TRIADE Pipeline)

### Phase 26: Brancher le LLM sur TRIADE + Benchmark
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA
- **Output:** 4 fichiers modifies, 2 fichiers crees, validation 66 fichiers 0 erreur

#### Changements:
1. **merlin_llm_adapter.gd** — Rewrite majeur v3.0.0: generate_card() branche sur MerlinAI autoload, format TRIADE 3 options, extraction JSON robuste, validation SHIFT_ASPECT, build_triade_context()
2. **merlin_store.gd** — Wiring MerlinAI dans _ready() + TRIADE_GET_CARD dispatch avec fallback 3 tiers (MOS → Adapter LLM → CardSystem)
3. **merlin_omniscient.gd** — Fix double instance MerlinAI (economie ~2GB RAM), prompts TRIADE, _try_llm_generation() delegue a l'adapter, _parse_llm_response() utilise validation TRIADE
4. **merlin_card_system.gd** — Ajout get_next_triade_card(), _select_triade_fallback_card(), _get_emergency_triade_card()
5. **TestTriadeLLMBenchmark.gd + .tscn** — Nouvelle scene benchmark: 5 scenarios, param sweep, mini-run E2E, streaming

#### Architecture LLM apres cette session:
```
Gameplay → MerlinStore.TRIADE_GET_CARD
             ├── MerlinOmniscient (MOS + 5 registres) → carte contextualisee
             ├── MerlinLlmAdapter.generate_card() → carte LLM brute validee
             └── MerlinCardSystem.get_next_triade_card() → fallback pool
```

---

## Session: 2026-02-17 (Phase 5 — Scene-Based Migration: Secondary Scenes)

### Migration Plan Reference
- **Plan**: `.claude/plans/majestic-sprouting-pond.md`
- **Phase**: 5/5 — Secondary scenes (TransitionBiome, SceneRencontreMerlin, Calendar, Collection)
- **Status**: COMPLETE

### Approach
Pattern identique aux Phases 2-4: extraire les noeuds crees programmatiquement par `_build_ui()` vers le .tscn, remplacer par `@onready var`, renommer `_build_ui()` en `_configure_ui()` (applique styles dynamiques MerlinVisual + shaders).

**Classification static vs dynamic:**
- **Scene (.tscn)**: Containers, Labels avec texte fixe, ColorRect, PanelContainer, Button, RichTextLabel, AudioStreamPlayer
- **Code (dynamique)**: LLMSourceBadge.create(), PixelMerlinPortrait, StyleBoxFlat factories (MerlinVisual.PALETTE), shader materials, boutons data-driven (STARTER_OGHAMS, BIOME_DATA)

### 1. TransitionBiome (1797 → 1726 lignes, -71)

**Fichiers modifies:**
- `scenes/TransitionBiome.tscn` — reecrit: 15 noeuds declares (Bg, CelticTop/Bottom, PixelContainer, WeatherOverlay, BlueSun, ClockPanel/ClockLabel, BiomeTitle, BiomeSubtitle, ArrivalText, MerlinComment, AudioPlayer)
- `scripts/TransitionBiome.gd` — 11 `@onready var`, 2 vars dynamiques (_arrival_badge, _merlin_badge = LLMSourceBadge)

**Refactoring:**
| Avant (methode) | Apres | Notes |
|-----------------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader bg, celtic text/color, positions viewport-dependantes, LLMSourceBadge |
| `_make_celtic_ornament()` | `_configure_celtic_ornament(lbl, pos, sz)` | Texte + couleur sur Label existant |
| `_create_mist_particles()` | `_configure_weather_system()` | StyleBoxFlat sur BlueSun/ClockPanel, couleur WeatherOverlay |
| `_setup_audio()` | `_configure_audio()` | Pass (AudioPlayer en scene avec bus=Master) |

### 2. SceneRencontreMerlin (1472 → 1409 lignes, -63)

**Fichiers modifies:**
- `scenes/SceneRencontreMerlin.tscn` — reecrit: 17 noeuds (ParchmentBg, MistLayer alpha=0, CelticTop/Bottom alpha=0, Card/CardVBox/PortraitContainer/SeparatorContainer/MerlinText/SkipHint, ResponseContainer, AudioPlayer)
- `scripts/SceneRencontreMerlin.gd` — 11 `@onready var`, 7 vars dynamiques (merlin_portrait, ogham_panel, biome_panel, etc.)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader parchment, MerlinVisual styles, PixelMerlinPortrait dynamique |
| `_make_celtic_ornament()` | `_configure_celtic_ornament(lbl)` | Texte + couleur sur Label existant |
| `_build_response_ui()` | `_build_response_buttons()` | Renomme, garde dynamique (styling + signaux) |
| `_setup_audio()` | `_configure_audio()` | Set volume_db uniquement |

### 3. Calendar (1211 → 1128 lignes, -83)

**Fichiers modifies:**
- `scenes/Calendar.tscn` — **reecrit integralement** (ancien 211 lignes stale ignore par le script): 25 noeuds (ParchmentBg, MistLayer, CelticOrnamentTop/Bottom, MainCard/CardVBox/TitleLabel/SubtitleLabel/SeparatorContainer/WheelContainer/EventPanel/TabsContainer/ContentScroll/ContentVBox/EventsSection/StatsSection/BrumesSection, BackButton)
- `scripts/Calendar.gd` — 13 `@onready var` + 3 vars dynamiques (tab buttons)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader, mist, positions viewport-dependantes |
| `_build_celtic_ornaments()` | `_configure_celtic_ornaments()` | Texte + couleur sur Labels existants |
| `_build_main_card()` | `_configure_main_card()` | StyleBoxFlat card + separateurs couleur |
| `_build_next_event_panel()` | `_configure_event_panel()` | StyleBoxFlat event panel |
| `_build_tabs()` | `_configure_tabs()` | Cree 3 boutons dynamiques (styling + signaux) |
| `_build_back_button()` | `_configure_back_button()` | Styling + signal retour |
| `_create_separator()` | SUPPRIME | Separateur maintenant en scene |

### 4. Collection (956 → 741 lignes, -215, plus grosse reduction)

**Fichiers modifies:**
- `scenes/Collection.tscn` — **reecrit integralement** (ancien 163 lignes stale, script faisait `queue_free()` sur tous les enfants): 35 noeuds (ParchmentBg, MistLayer, OrnamentTop/Bottom, MainContainer/Layout/Header/TitleLabel/StatsVBox/GloryLabel/RankLabel, SepTop, PassPanel/PassVBox, ViewTabs/3 Buttons, ContentPanel/ContentScroll/ContentStack/ProgressSection/RecentSection/CollectionSection/sub-labels/lists/grids, SepBottom, BottomBar/BackButton)
- `scripts/Collection.gd` — 35 `@onready var` (plus gros nombre d'extractions)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `for child in get_children(): child.queue_free()` | SUPPRIME | Plus de destruction de scene |
| `_build_ui()` (260 lignes) | `_configure_ui()` (~40 lignes) | Shader, mist, ornements, separateurs, signaux |

### 5. IntroBoot — PASSE (non migre)
- Seulement 3 noeuds (background, static_rect, logo)
- Animation CRT procedurale = correct en code
- Gain negligeable, risque inutile

### Validation
- **Editor Parse Check**: 0 erreurs, 0 warnings
- **Headless scene validation** (19 scenes):
  - 17 PASS (dont TransitionBiome, SceneRencontreMerlin, Collection, MenuPrincipal)
  - 2 FAIL initiaux: Calendar + HubAntre (`gui_embed_subviewports` SubViewport error — **pre-existant**)
    - **CORRIGE**: `pixel_content_animator.gd:386` — `gui_embed_subviewports` (Window) → `gui_disable_input` (Viewport)
    - **Re-test: 18/18 PASS, 0 FAIL**
  - 1 WARN: MerlinGame (CanvasItem RID leak — pre-existant, non bloquant)

### Bilan Migration Complette (Phases 1-5)

| Phase | Cible | Lignes supprimees | Status |
|-------|-------|-------------------|--------|
| 1 | Theme System | ~100 (factorisation styles) | COMPLETE |
| 2 | TriadeGameUI | -408 | COMPLETE |
| 3 | HubAntre | ~-300 | COMPLETE |
| 4 | MenuPrincipalMerlin | -94 | COMPLETE |
| 5 | Scenes secondaires | -432 (71+63+83+215) | COMPLETE |
| **Total** | | **~-1334 lignes** | **DONE** |

**Ratio scene/script**: ~5% → ~55-60% des noeuds declares en scene.

---

## Session: 2026-02-09 (Transition Biome Revamp)

### Phase 25: Paysage Pixel Emergent — TransitionBiome Rewrite
- **Status:** complete
- **Agents:** Motion Designer, Art Direction
- **Output:** 1 fichier reecrit (906 lignes), validation 65 fichiers 0 erreur

#### Changements:
1. **Remplacement complet** de TransitionBiome.gd — nouveau flow "Paysage Pixel Emergent"
2. **6 phases d'animation**: Brume → Emergence → Revelation → Sentier → Voix → Dissolution
3. **7 paysages pixel-art proceduraux** (32x16 grids) — un par biome:
   - Broceliande: foret dense, 4 coniferes, troncs, champignons
   - Landes: menhir solitaire, collines ondulees, bruyere
   - Cotes: falaise a gauche, vagues, plage
   - Villages: 2 huttes celtiques, fumee, sentier
   - Cercles: 5 menhirs en arc, etoiles, lune
   - Marais: arbres tordus, eau sombre, phosphorescence
   - Collines: dolmen trilithon, collines, crepuscule
4. **Primitives de dessin procedural**: triangle, rectangle, hill (ellipse), dots
5. **Pixel size dynamique**: s'adapte a la taille du viewport (~48% largeur)
6. **Phase Brume**: pixels eclaireurs qui tombent et disparaissent (anticipation)
7. **Phase Dissolution**: pixels tombent avec gravite + derive horizontale (inverse de l'emergence)
8. **BIOME_COLORS etendu**: 7 palettes (3 couleurs chacune) vs 4 anciennes
9. **SFX integres**: mist_breath, pixel_land, pixel_cascade, magic_reveal, path_scratch, landmark_pop, scene_transition

#### Avant/Apres:
- Avant: chemin bezier generique + icone 8x8 (~40 pixels)
- Apres: paysage 32x16 (~200-300 pixels) unique par biome + dissolution gravitaire

---

