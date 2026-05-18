# Phase 11 - Narrative Depth + DnD-without-Combat Strategy Plan

> Investigation synthesis: 3 parallel agents (LLM architect / Narrative writer / Game designer)
>
> **Trigger** (user verbatim): *"Bien plus de scénario et de longueur dans les cartes, investigue
> avec des agents architectures IA / LLM ce qui peut être optimisé et avec des agents ecrivains
> pour plus de profondeur et de cohérence, un vrai fil rouge, investigue egalement avec des
> agents game design pour ajouter de la stratégie dans les choix et une profondeur dans les
> choix plus que simplement faire des choix, à la manière d'un DnD mais sans combat."*
>
> **Date**: 2026-05-18  -  **Baseline**: v7.7.30 PoC (31.8 s for 16 cards, 35.8x speedup, flat narrative)

---

## 1. The root cause (measured this session, not inferred)

The pool `data/ai/scenarios_reference_broceliande.json` holds **2 994 cards but only
90 unique summary strings** = **97 % string duplication**. Top 10 summaries each appear
92-116 times across the 100 scenarios:

| Repeats | Summary preview                                                          |
|--------:|--------------------------------------------------------------------------|
| 116x    | "Un druide voyageur te demande de témoigner pour lui devant un cercle." |
| 107x    | "Une créature étrange te défie en silence. Tu peux fuir, lutter..."     |
| 102x    | "Le temps ralentit sans raison. Tu peux profiter, fuir..."              |
| 100x    | "Des pierres alignées attendent qu'on les complète..."                  |
|  99x    | "Un vieux sage te propose une leçon..."                                 |

**Consequence**: even with the v730 graceful-dedup fallback chain, kNN converges back
to the same 90-string cluster, producing the "Beat 1 == Beat 2" pattern visible in the
v7.7.30 HTML report.

**Architecture doc §L5 (lines 106-118) was aspirational**: it advertises
`resolution_success` / `resolution_failure` / `effects_success` fields **that do not
exist in the actual pool**. The runtime falls back to the mechanical template at
`tools/simulate_human_run_v730.py:220-230`. The §L5 section needs an honest rewrite.

---

## 2. Three agent findings, converged

### 2.1 LLM architecture (general-purpose architect)

Six upgrade mechanisms ranked by ROI. **Top 3 to ship**:

| # | Mechanism | Layer | Wall cost | Quality delta | Effort |
|---|-----------|-------|-----------|---------------|--------|
| **M1** | **Pool dedup + offline LLM variant batch**: collapse 2 994 -> 90 canonical types, then LLM-write 5 prose variants x 2 lengths per (emotion, pole, archetype) tuple. Persist `cards_meta_v2.json`. Runtime = dict lookup. | L1+L5 | **+0 s runtime** (one-shot ~30 min offline) | Kills duplication, shallowness, template-resolution **simultaneously**. Pool diversity 90 -> 900 strings. | 1.5 d |
| **M2** | **MMR re-ranking in `cards_rag.knn`**: top-K=32 -> rerank `lambda * sim(q,c) - (1 - lambda) * max sim(c, picked)`, lambda~=0.6. Pure numpy. Replaces broken dedup fallback. | L2/L3 | +0.05 s/run | Deterministically kills Beat N == Beat N+1 even if M1 slips. | 0.5 d |
| **M3** | **Streaming beat-chain stitcher LLM**: between beat N and N+1, fire `gemma4:e2b` with an 80-token prompt: *"Lien narratif 2 phrases entre {prev_summary}+{prev_verb} et {next_summary}"*. Async, masked by UI animation. | L6 | **+0 s perceived** (~70 s background spread over 16 beats) | Kills no-transition gap + injects fil rouge via prev-3 history. | 2 d |

**Deferred**: M5 trajectory retrieval via `leads_to_card_id` graph (waits on M1, graph
currently collapses to identical twists). M6 hybrid epic-moment LLM (waits on M1 -
else epic beats float in flat sea). M4 memory-injection into intro/outro prompts
(0.5 d free win, fold into M3 sprint).

### 2.2 Narrative depth (merlin-narrative-designer)

Three **+0 LLM-cost** levers for the fil rouge:

- **A) Anchor table at boot**: pick the first retrieved card's character/symbol
  (e.g. "druide voyageur") and *force* a callback at beat 8 and 16. Pure state, 0 ms.
- **B) Header / transition prose template**: interpolated, not LLM. Pattern:
  *"{transition_connector_pool[mvt]} - {prev_anchor_callback}"*. Played before each
  resolution.
- **C) Cascade prompt enrichment**: pass `last_verb` + `current_mouvement` + `anchor_char`
  in the system prompt of `llm_intro` / `llm_outro`. Extra tokens, not extra calls.

Phase 11+ lever (budget +60 s): real LLM outro that reads the 16 resolutions and
synthesises 3-5 coherent sentences (vs current interpolation from `faction_rep`).

**Narrative skeleton** (5-movement model for any 16-beat run):

| Mvt | Beats | Narrative role | Emotional seuil | Required anchor callback |
|-----|-------|----------------|-----------------|--------------------------|
| 1   | 1-3   | Setup + first anchor | curiosité | Name the anchor (char/symbol) |
| 2   | 4-7   | First descent | tension | Echo the anchor (sensory) |
| 3   | 8     | MERLIN_DIRECT pivot | révélation | Anchor recontextualised |
| 4   | 9-13  | Deepening | peur / fascination | Twin shadow of anchor |
| 5   | 14-16 | Pay-off | sagesse | Anchor returns transformed |

Recommend adding **bible §25 - Inter-Beat Narrative Contract** to formalise this.

### 2.3 Game design (merlin-game-designer)

v7.7.30 currently exploits **~20 % of bible v3.5 mechanics**. Key gaps + fixes:

| Gap | Bible ref | Proposed fix |
|-----|-----------|--------------|
| No DC / skill check | §5.3 step SCORE | Hidden DC system with qualitative signals `[Confiant]`/`[Risqué]`/`[Éprouvé]` (no d20 surfaced) |
| No challenges | §4.1 | Add Rune Gambit / Minigame / Oracle / Merlin Judges hooks - challenge score multiplies effects |
| Merlin interference unused | §2.3 | Swap / Hide / Amplify / Bait based on Trust tier T0-T3 |
| Anam not used | §5.2 | Cross-run currency for unlocking Rune-Circuits T1-T2 |
| Cross-pole stakes absent | §3.2 | ~10 % of options have `+rep ordre, -rep chaos` style trade-offs |
| Promesses dormant | §5.5 | PROMISE cards with 3-beat countdown, +10/-15 Merlin trust |
| No inter-beat memory | §6.4 | `tags[]` registry checked by `gated_on` on subsequent options |

**Proposed enriched option JSON** (offline regen, runtime cost +0.2 ms/card):

```json
{
  "label": "Soigner",
  "verb": "apaiser",
  "primary_faction": "niamh",
  "dc_against": { "pole": "Liminal", "threshold": 30 },
  "cost": { "souffle": 1 },
  "gated_on": { "required_tags": ["animal_soigne"], "min_karma": 5 },
  "gate_hint": "Cette créature te reconnait...",
  "success_effects":  ["ADD_REPUTATION:Liminal:12", "HEAL_LIFE:5",
                       "ADD_TAG:sanglier_soigne", "PROMISE:cercle:3"],
  "partial_effects":  ["ADD_REPUTATION:Liminal:6", "ADD_TAG:sanglier_soigne"],
  "failure_effects":  ["DAMAGE_LIFE:4", "ADD_TAG:sanglier_fui"],
  "success_prose": "La bête flaire ta main. La marque du cercle pulse...",
  "failure_prose": "Tu t'approches trop vite. Le sanglier part en trombe..."
}
```

**4 strategic resources** (Souffle, Essence, Karma, Anam) creating arbitrages:

| Resource | Range | Gain | Spend | Arbitrage |
|----------|-------|------|-------|-----------|
| Souffle  | 0-5 per run | +1 on Liminal observation / rest | -1 to unlock starter Rune-Circuit; -2 to force re-roll on grey option | Save for late DC vs spend now on circuit |
| Essence  | 0-20 per run (§5.2) | Challenge score >=80, EVENT bonus | Boost challenge score +20, buy "pay passage" (avoid DAMAGE_LIFE) | Boost critical challenge vs save for late merchant |
| Karma    | int cumul (visible "Mémoire Druidique") | +3-5 altruistic | -5 selfish / broken promise | High karma reduces all DCs (-2 per 10 karma) - rewards consistency |
| Anam     | int cross-run (§5.2) | Successful challenges, Rune-Circuit usage | Unlock T1-T2 Rune-Circuits (80-140 Anam, §8.2) | Spend on circuit-in-run for +1 Anam, but risk cooldown miss |

**Information asymmetry** (DnD-without-combat core):

- Visible: `primary_faction`, `cost`
- Hidden: `dc_against.threshold`, `failure_effects`
- Revealed later: `ADD_TAG` payoff when tested as gate (2 beats later)
- Rumour / scouting: Rune-Circuit `beith` (§3.3) reveals 1 option's hidden DC.
  Merlin at T2+ glides narrative hints.
- Bluff: 1/3 of options may carry `true_faction != primary_faction` (Merlin Bait
  interference, §2.3). Rune-Circuit `saille` reveals it.

---

## 3. Unified prioritised roadmap

**Sprint 11.1 - Pool surgery (1.5 d, blocker for all else)**
- Build `tools/dedup_and_expand_pool.py`:
  1. Group cards by canonical summary (90 buckets).
  2. For each bucket, batch LLM-write 5 prose variants x 2 lengths (~30 min offline run).
  3. Inject enriched option schema (Q 2.3) using bible defaults per archetype/emotion.
  4. Write `data/ai/cards_meta_v2.json` (~10 MB with prose + DCs + tags).
- Re-run `tools/embed_reference_cards.py` against the rewritten pool to refresh embeddings.

**Sprint 11.2 - kNN MMR + bug fix (0.5 d)**
- Add `mmr_lambda` parameter to `cards_rag.CardsRAG.knn` (default 0.6).
- Replace the v730 fallback chain at `simulate_human_run_v730.py:165-176` with MMR.
- Remove the `with_dedup=False` silent fallback - MMR makes it unnecessary.

**Sprint 11.3 - Inter-beat memory + DnD checks (1 d)**
- Extend `agent_pick_option(card, state)` to read `gated_on` from the pool, filter
  greyed options, calculate DC vs state, return `dc_result: "success"|"partial"|"failure"`.
- Branch `derive_effects` on the dc_result.
- Replace `synthesise_resolution` with picks from `success_prose` / `partial_prose` /
  `failure_prose` (no template).
- Add `tags[]` accumulator on `state`. Render `[Confiant]/[Risqué]/[Éprouvé]` signals
  on options that have a DC.

**Sprint 11.4 - Fil rouge injection (1 d)**
- Anchor table at boot: pick the first retrieved card's `character_voice` (added in
  Sprint 11.1) and force callback at beats 8 and 16.
- Cascade prompt enrichment in `llm_intro` and `llm_outro`: inject `anchor_char`,
  `last_3_verbs`, `dominant_mouvement`. No extra LLM calls.

**Sprint 11.5 - Streaming stitcher (2 d, async-masked, ships last)**
- New `tools/beat_chain_stitcher.py`: 80-token Ollama prompt per beat-transition,
  fires *during* the UI animation between cards. Falls back to pre-baked connector
  pool if LLM is slow.

**Sprint 11.6 - QA gate + bible update (1 d)**
- 10 runs side-by-side (LLM-only / v7.7.30 / v7.7.31) on identical seeds.
- Manual rating 1-5 on coherence, depth, strategic feel.
- Update `docs/GAME_DESIGN_BIBLE.md` v3.5 -> v3.6:
  - **New §25** - Inter-Beat Narrative Contract (anchor + 5-movement model)
  - **Extend §5.3** - Pipeline SCORE step uses dc_result, not flat
  - **New §26** - Hidden-DC / DnD-without-combat doctrine + qualitative signal vocabulary

**Total**: ~7 dev days + ~1 h offline LLM batch + ~1 d QA. **Net wall-time impact**:
v7.7.31 target = ~50 s for 16 cards (vs 31.8 s today) = still ~23x baseline speedup,
with vastly deeper narrative + strategic stakes.

---

## 4. Concrete benchmark targets for v7.7.31

| Dimension                    | v7.7.30 (today) | v7.7.31 target | Mechanism |
|------------------------------|-----------------|----------------|-----------|
| Wall time / run              | 31.8 s          | 45-55 s        | M3 stitcher async + M1 lookup |
| Unique summaries in 1 run    | 10 / 16         | 16 / 16        | M1 pool dedup + M2 MMR |
| Outcomes per option          | 1 (success)     | 3 (succ/part/fail) | DC system |
| Greyed options w/ hint       | 0               | 1-2 per run    | gated_on + tags |
| Inter-beat callbacks         | 0               | >=3 per run    | anchor table + tags |
| Cross-pole stakes triggered  | 0               | ~10 %          | enriched option JSON |
| LLM intro/outro coherence    | poor            | strong         | M4 memory-injection |
| Transition prose             | none            | yes            | M3 stitcher |

---

## 5. Out of scope this turn

- Voice acting / TTS integration on the new prose variants
- Music / SFX layering tied to anchor callbacks
- Visual UI rework for qualitative DC signals (`[Confiant]` chip etc.) - Sprint 11.7
- Cross-biome reuse of the enriched pool (Morbihan, etc.)
- Localisation pipeline for new prose variants
- A/B telemetry instrumentation in-game

These remain Phase 12+ backlog.

---

## 6. Why this matters

The user's diagnosis is correct: v7.7.30 proves the **speed**, but a narrative card
game's value lives in the **narrative + stakes**. Architecture is sound; pool was
insufficient. **All three agents converge on the same answer**: spend 30 minutes of
offline LLM time once (Sprint 11.1) and the runtime depth changes qualitatively,
without losing the embedding-first speedup.

DnD's secret isn't combat - it's the **DC + table memory + consequence cascade**.
Sprint 11.3 ports that to MERLIN: every choice becomes a *test* against your run
state, not a verb pick. Every tag becomes a future gate. Every promise becomes a
3-beat countdown. The pool stays the source of truth; the runtime becomes a
state-machine that reads structured cards rather than freestyle LLM prose.

---

*Author: synthesis of 3 parallel agent investigations - 2026-05-18*
*Files referenced: GAME_DESIGN_BIBLE.md v3.5, scenarios_reference_broceliande.json,
tools/simulate_human_run_v730.py, EMBEDDING_FIRST_ARCHITECTURE.md*
