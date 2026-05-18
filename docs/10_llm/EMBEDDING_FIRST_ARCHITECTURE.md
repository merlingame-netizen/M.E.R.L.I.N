# Embedding-First Architecture — Phase 10 (v7.7.30)

> **Goal**: Reduce MERLIN run-loading time **10x to 40x** by replacing per-turn
> LLM generation with pre-computed, embedding-indexed retrieval.
>
> **Target**: 1140s (current LLM-only) → **~120s** realistic / **~10s** stretch.
>
> **Origin**: Phase 10 — answers the user request *"Il faut pouvoir faire du
> embedding / vectorisation puissante pour arriver à un résultat de chargement
> 10x moins important, comment faire ? Propose une architecture bien meilleure."*

---

## 1. Why the current pipeline is slow

| Pipeline step (v7.7.29)        | LLM calls | Wall time      |
|--------------------------------|-----------|----------------|
| Titles                         | 1         | ~30s           |
| Intro (setup)                  | 1         | ~40s           |
| Skeleton (acts)                | 1         | ~100s          |
| Scenario full                  | 1         | ~90s           |
| Card x 16 (Gemma 4 E2B)        | 16        | ~480s          |
| Resolution x 16                | 16        | ~400s          |
| Outro                          | 1         | ~30s           |
| **Total**                      | **36**    | **~1140s**     |

Each LLM call pays the **token-by-token decoding cost** of Gemma 4 E2B
(~30-50 tok/s on a desktop CPU). The model writes the same archetypes over
and over — *new tokens, identical structure*. This is wasteful.

---

## 2. The insight

The reference pool `data/ai/scenarios_reference_broceliande.json` already
contains **100 scenarios x ~29 cards = ~2 900 hand-validated cards**, each
with options, branch labels, route_mask, emotion arc, pole alignment,
rarity, archetype.

> **A 2 900-card pool covers the entire combinatorial space of a Brocéliande
> run.** A 16-card run is just a *path* through this pool.

The LLM's only legitimate jobs become:
1. **Personalise** prose to the current run's choices (cheap, optional).
2. **Generate epic moments** (boss, ogham activation, first-archetype encounter).

Everything else is **retrieval, not generation**.

---

## 3. Six-layer embedding-first stack

```
+-------------------------------------------------------------+
|  L6  Hybrid runtime  (95% retrieval / 5% LLM "epic moments") |
+-------------------------------------------------------------+
|  L5  Pre-baked resolution narratives        (offline, once)  |
+-------------------------------------------------------------+
|  L4  Personalisation via embedding composition   (10 ms)     |
+-------------------------------------------------------------+
|  L3  Optional cross-encoder rerank   (top-K -> top-3, 50 ms) |
+-------------------------------------------------------------+
|  L2  HNSW kNN index over 2 900 cards   (1 ms / query)        |
+-------------------------------------------------------------+
|  L1  Pre-computed int8 embeddings   (offline, 3 MB on disk)  |
+-------------------------------------------------------------+
```

### L1 — Pre-compute embeddings offline

- Embed every card with `nomic-embed-text` (already pulled).
- Input text: `f"{archetype} . {beat.summary} . {options[0].text} . {options[1].text} . {options[2].text}"`.
- 2 900 cards x 768 dim x float32 = **8.9 MB** raw.
- **Quantise to int8** (per-vector scale): **2.2 MB** with <1 % cosine error.
- Persist as `data/ai/cards_index.npy` (mmap-able) + `data/ai/cards_meta.json`.
- One-shot script: `tools/embed_reference_cards.py` (~3 min for 2 900 cards).

### L2 — HNSW kNN index (build once, query in 1 ms)

- Library: `hnswlib` (pip, no native dep beyond what numpy needs).
- Build at boot: load `.npy` mmap -> instantiate `Index(space='cosine', dim=768)` -> `add_items(vectors, ids)`.
- Boot cost: **~1 s** for 2 900 items. **~50 ms** with `ef_construction=100`.
- Query: `index.knn_query(qvec, k=20)` -> **0.5-1 ms**.

### L3 — Optional rerank

- Pull top-K=20 by raw cosine.
- Re-score with a tiny cross-encoder (e.g. a 50 M-param distil model in ONNX)
  or with **hard filters**: pole-mismatch penalty, rarity quota, emotion-arc
  alignment to the beat plan.
- Cost: **50 ms** worst case. Skippable for first ship.

### L4 — Personalisation via embedding composition

The player has made choices `[c1, c2, c3]`. Each choice has an option-text
embedding. Build a **route embedding**:

```python
route_vec = 0.5 * beat_vec  +  0.3 * mean(last_3_choice_vecs)  +  0.2 * intro_vec
```

Then `knn_query(route_vec)` retrieves cards that are *both* relevant to the
beat *and* tonally consistent with the player's path so far. **No new LLM
call.** The route shape emerges from arithmetic on existing vectors.

### L5 — Pre-baked resolution narratives

Each option in the reference pool already carries:

```json
{
  "text": "Tu invoques le serment du jeune druide",
  "resolution_success": "Le Chene te repond par un long murmure...",
  "resolution_failure": "Le silence se referme. La foret te jauge.",
  "effects_success": ["ADD_REPUTATION:druides:8", "ADD_KARMA:4"],
  "effects_failure": ["DAMAGE_LIFE:2"]
}
```

Resolution becomes a **dict lookup** (0 ms), not a LLM call (~25 s).
For variety, store 2-3 resolution variants per option, sampled by `run_seed`.

### L6 — Hybrid: 95% retrieval / 5% LLM "epic moments"

The LLM keeps doing what it does best: writing **once-per-run signature
moments** that benefit from full creative freedom.

| Trigger                                   | Mode      | Cost   |
|-------------------------------------------|-----------|--------|
| Standard NARRATIVE card (every beat)      | Retrieval | 1 ms   |
| EVENT (random encounter)                  | Retrieval | 1 ms   |
| MERLIN_DIRECT card (Merlin speaks to you) | LLM       | 25 s   |
| Boss / Ogham activation                   | LLM       | 25 s   |
| First time a faction crosses tier         | LLM       | 25 s   |
| Intro / Outro (player keeps these)        | LLM       | 30 s   |

Budget: **2 LLM calls per run** (intro + outro) + **1-2 epic cards** = ~2 min
of LLM work spread *during* the run, masked diegetically.

---

## 4. Benchmark math

| Step               | v7.7.29 (LLM-only) | v7.7.30 (embedding-first)    | Speedup |
|--------------------|--------------------|------------------------------|---------|
| Titles             | 30 s               | 50 ms (sample + rerank)      | 600x    |
| Intro              | 40 s               | 40 s (kept as LLM)           | 1x      |
| Skeleton           | 100 s              | 50 ms (route from pool)      | 2000x   |
| Scenario full      | 90 s               | 0 s (synthesised from cards) | inf     |
| Card x 16          | 480 s              | 16 x 1 ms = 16 ms            | 30 000x |
| Resolution x 16    | 400 s              | 16 x 0 ms (dict lookup)      | inf     |
| Outro              | 30 s               | 30 s (kept as LLM)           | 1x      |
| Epic-moment LLM x 2| 0 s                | 50 s                         | -       |
| **Total**          | **~1 140 s**       | **~120 s**                   | **~10x**|

Stretch target (no LLM at all, fully retrievable): **~5 s** total.
Realistic target keeping LLM for intro/outro/epic: **~120 s**.

---

## 5. Memory & disk footprint

| Asset                              | Size       |
|------------------------------------|------------|
| `cards_index.int8.npy`             | 2.2 MB     |
| `cards_meta.json` (text + options) | 1.8 MB     |
| `hnswlib` index serialised         | 3.5 MB     |
| Resolution variants                | 0.6 MB     |
| **Total shipped with game**        | **~8 MB**  |

vs. a Gemma 4 E2B Q4_K_M weight file (1.6 GB). The pool is **200x smaller**
than the model it replaces for the retrieval portion.

---

## 6. Async loading strategy

The 120 s remaining LLM cost is spread across the run so it never blocks:

```
T=0       Boot: load embeddings + HNSW index            (~1 s)
T=1       LLM warmup (Gemma 4 E2B model load)           (~3 s parallel)
T=4       Show 3 titles (retrieved + LLM-reranked)      (~0 s perceived)
T=4       Player picks title
T=4       Start intro LLM (~40 s, async)                  <- masked by:
T=4-30    Player reads intro card 1 of pool (retrieved instantly)
T=30      Intro arrives, swap in
T=30-..   Each beat: retrieve next card (1 ms), prefetch
          resolution variant for whichever option player hovers.
T=N-30    Start outro LLM in background.
T=END     Outro ready exactly when run ends.
```

The player **never waits for the LLM**. Loading is diegetic.

---

## 7. Implementation plan

### Phase 10.1 — Card-level embeddings (1 day)
- `tools/embed_reference_cards.py` — extract every option from every scenario,
  emit `cards_meta.json` + `cards_vectors.npy` (float32 then int8 quantised).
- Expected output: 2 900 cards x 768 dim, ~2-3 min wall time.

### Phase 10.2 — HNSW index loader (0.5 day)
- `addons/merlin_ai/cards_rag.gd` (Godot side, via Python sidecar) **OR**
- `tools/cards_rag.py` (PoC side, used by `simulate_human_run.py`).

### Phase 10.3 — Retrieval-first simulate run (1 day)
- `tools/simulate_human_run_v730.py`:
  - Boot: load `.npy` + `cards_meta.json`, build HNSW index.
  - Titles, intro, outro: LLM (kept).
  - Skeleton + scenario_full: synthesised from retrieved route, **no LLM**.
  - Card x 16: kNN retrieval, no LLM (or LLM only for `MERLIN_DIRECT`).
  - Resolution x 16: dict lookup.
- HTML report `merlin_human_run_test_v7.7.30.html` with side-by-side timings.

### Phase 10.4 — In-game integration (3 days)
- Mirror the Python PoC in GDScript:
  - `CardsRAG` singleton loads `.bin` index + `.json` meta at boot.
  - `BiBrainPipeline.generate_card()` calls `CardsRAG.knn(query_vec, k=5)` first,
    falls back to LLM only if all retrieved cards fail the bible filter.
- Wire the route-embedding composition into `MerlinStore.add_choice()`.

### Phase 10.5 — Quality gate (1 day)
- Compare 10 runs (LLM-only vs embedding-first) on:
  - Narrative coherence (manual rating 1-5)
  - Schema validity (always 100 % for retrieval — pool is pre-validated)
  - Total wall time
  - Player-perceived novelty (variant sampling check)
- Ship behind a feature flag `MERLIN_FAST_LOAD=1`.

---

## 8. Failure modes & mitigations

| Risk                                          | Mitigation                                              |
|-----------------------------------------------|---------------------------------------------------------|
| Pool drift: card too repetitive across runs   | Variant pool >=3 / archetype, `run_seed`-driven shuffle |
| Player notices "I've seen this card"          | Personalisation embedding + variant prose swap          |
| Embedding miss: no card matches the beat plan | Fallback to LLM `llm_card()` with same prompt           |
| Pool gets stale (new factions, oghams)        | Re-run `embed_reference_cards.py` (idempotent, 3 min)   |
| HNSW index corruption                         | Rebuild from `.npy` at boot if checksum fails           |
| Cosine collisions on int8                     | Keep float32 fallback file, switch on demand            |

---

## 9. Comparison with current RAG

The existing `ScenariosRAG` retrieves at the **scenario** level (1 of 100).
This proposal retrieves at the **card** level (1 of ~2 900). Two orders of
magnitude finer grain -> far better narrative fit per turn.

Both systems can coexist: scenario-level RAG seeds the run skeleton,
card-level RAG fills each beat.

---

## 10. Why this is "10x better" not just "10x faster"

It's not just speed:

1. **Bible compliance is free**: every retrieved card is already validated.
2. **Cost**: shipping a 8 MB pool vs 1.6 GB model for the hot path.
3. **Determinism**: same seed -> same run, reproducible for QA.
4. **Offline mode**: works without an LLM at all (degraded but playable).
5. **Localisation**: pool is human-translatable; LLM output is not.
6. **Accessibility**: instant responses help players with cognitive load.
7. **Telemetry**: easy to A/B test pool variants vs LLM variants.

---

## 11. Open questions

- **Pool growth**: how to crowdsource new cards into the pool over time?
- **Cross-biome reuse**: can a Brocéliande card slot into Morbihan if we
  swap proper nouns via template? (Cheap, but flattens biome identity.)
- **LLM as pool curator**: nightly batch job where the LLM proposes 100 new
  cards, designer reviews 10, the rest get auto-quarantined?
- **Embedding model upgrade**: nomic-embed-text -> bge-m3 (multilingual,
  better recall) — worth the 4x larger model (574 MB)?

---

## 12. Next concrete deliverable

`tools/simulate_human_run_v730.py` running end-to-end on the existing 100-
scenario pool, generating `merlin_human_run_test_v7.7.30.html` with timings
proving the **~10x speedup** on a real run.

**Acceptance**: HTML report shows total wall time < 130 s with 16 cards,
intro + outro LLM-written, all 16 cards retrieved, all 16 resolutions
looked up.

---

*Author: Claude (Phase 10 design) - Date: 2026-05-18 - Plan version: 1.0*
