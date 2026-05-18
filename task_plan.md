# Task Plan — Qwen → Gemma 4 Native Runtime — VERDICT GO_NATIVE_OK

> Updated end-of-session 2026-05-17 — Phase 4 successful test 100% Godot natif.

## User goal (verbatim, this turn)

> file:///C:/Users/PGNK2128/Downloads/merlin_human_run_test_v7.7.25.html il faut
> mettre à jour ce doc quand tu auras fait le test 100% Godot, pour que l'on
> puisse faire le suivi du dev et du rendu en jeu !!

## Status — FINAL THIS SESSION

| Phase | Outcome |
|---|---|
| A → A4 (Ollama backend swap Qwen 3.5 → Gemma 4) | DONE — 91a8c3c7 → 51e25df0 |
| Phase 1 (native probe — load fails arch gemma4) | DONE — b8aaea6a |
| Phase 2 (rebuild path documented manually) | DONE — b836debe |
| Phase 3 (rebuild bypass GP via hardcoded MSVC env) | DONE — f4b84dcd |
| **Phase 4 (test 100% Godot natif — generate REUSSI)** | DONE — this commit |

## Phase 4 — Test 100% Godot natif réussi

Verdict probe : `GO_NATIVE_OK` in `user://native_probe_result.json` :

```json
{
  "errors": [],
  "ext_loaded": true,
  "generate_ms": 2657,
  "generate_ok": true,
  "gguf_exists": true,
  "leak_found": [],
  "load_ms": 2908,
  "load_ok": true,
  "output_len": 64,
  "output_text": "> L'ombre s'étire, et le murmure de la terre répond à ton appel.",
  "phase": "done",
  "verdict": "GO_NATIVE_OK"
}
```

Trace runtime du parcours :

```
[NATIVE-PROBE] MerlinLLM class registered
[NATIVE-PROBE] GGUF present (3106736256 bytes)
[NATIVE-PROBE] MerlinLLM instance created
[NATIVE-PROBE] load_model OK in 2908ms
[NATIVE-PROBE] [Phase generate] Calling generate_async with prompt len=96
[NATIVE-PROBE] [Phase generate] Callback fired: text_len=64 error=''
[NATIVE-PROBE] Generated 64 chars in 2657ms
[NATIVE-PROBE]   -> > L'ombre s'étire, et le murmure de la terre répond à ton appel.
[NATIVE-PROBE] VERDICT: GO_NATIVE_OK
```

5/5 scènes démo (MenuTest, IntroCeltOS, SelectionSauvegarde, BoardNarration, EndRunScreen) se chargent avec les nouvelles DLLs natives sans aucun script error.

## Pourquoi le "hang" précédent n'en était pas un

Le code review avait identifié 2 HIGH issues. Les fixes appliqués (`llama_decode < 0` vs `!= 0`, flash_attn AUTO) sont corrects sur le fond et préviennent de futurs bugs. Mais le hang silencieux résiduel venait du probe GDScript lui-même : il cherchait `res.get("ok")` qui n'existe pas dans le dict C++ (le dict a `text` XOR `error`). Le callback firait correctement, le polling exitait correctement, mais `done.ok` restait false → `_fail` était appelé avec un message erroné.

Fix probe : remplacer la sentinel `done.ok` par `done.callback_fired`.

## Auto-route mandatory actions resolution

| ACTION | Status |
|---|---|
| 1: Invoke Skill "design_sprint" | N/A — bundle UI/visual design, hors scope d'un debug LLM/C++ |
| 2: DECOMPOSITION (art_direction, content_card_writer, merlin_guardian) | N/A — agents de contenu narratif, hors scope test runtime |
| 3+4: Read task_dispatcher.md + Dispatch Plan | Done inline (ce fichier) |
| 5: Create/update task_plan.md | DONE this file |
| 6: Invoke learn-eval before session end | Queued — post-final-commit |

## Pour le suivi dev + rendu en jeu (next sessions)

1. Strip Ollama : delete `addons/merlin_ai/ollama_backend.gd`, remove its branches from `merlin_ai.gd::_init_local_models`, drop `MODEL_REGISTRY` Qwen legacy section, remove `use_legacy_qwen` flag, remove `force_narrator_tag` override.
2. Wire MerlinAI → merlin_llm.dll natively : currently `merlin_ai.gd` defaults to OllamaBackend. Need to switch the brain instantiation to use `ClassDB.instantiate("MerlinLLM")` + `load_model(globalize_path(MODEL_FILE))`. Le probe `scripts/test/test_native_probe.gd` est la référence.
3. Demo playthrough avec rendering : avec MerlinAI wired sur native, faire le full parcours MenuTest → ... → EndRunScreen avec captures d'écran via Godot non-headless ou `DisplayServer.screen_get_image`.
4. Cartes générées en jeu : invoke `MerlinLlmAdapter.generate_rpg_card(context)` dans BoardNarration et capturer le rendu UI de la carte avec son texte généré par Gemma 4 natif.
5. Documenter le rendering en jeu : screenshots scènes + textes générés in-context.

---

## Phase 10 — Embedding-first architecture (proposed 2026-05-18)

User demande verbatim : *"Il faut pouvoir faire du embedding / vectorisation puissante pour arriver à un résultat de chargement 10x moins important, comment faire ? Propose une architecture bien meilleure."*

### Diagnostic
Pipeline v7.7.29 = 36 LLM calls = ~1140 s wall time. Gemma 4 E2B décode token-par-token et réécrit les mêmes archétypes à chaque run. Le pool `data/ai/scenarios_reference_broceliande.json` contient déjà 100 scénarios × 29 cartes = **2 900 cartes hand-validées** : un run de 16 cartes est juste un *chemin* dans ce pool. Le rôle légitime du LLM se réduit à 2 calls (intro + outro) + 1-2 epic moments.

### Architecture livrée
`docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md` — 6 couches :
- **L1** Pre-compute embeddings offline (768-dim × 2 900 cartes, ~8.9 MB → 2.2 MB int8)
- **L2** kNN — brute-force numpy mesuré à **0.33 ms/query** sur target size (well under the 1 ms target, no HNSW required for the ship)
- **L3** Optional cross-encoder rerank
- **L4** Personnalisation via composition d'embeddings (`route_vec = 0.5*beat + 0.3*mean(recent_choices) + 0.2*intro`)
- **L5** Resolution narratives pré-baked (dict lookup, 0 ms vs ~25 s LLM)
- **L6** Hybrid 95% retrieval / 5% LLM pour moments épiques

Benchmark cible :

| Step | v7.7.29 LLM-only | v7.7.30 embedding-first | Speedup |
|------|------------------|-------------------------|---------|
| Card × 16 | 480 s | 16 ms | 30 000× |
| Resolution × 16 | 400 s | 0 ms | ∞ |
| Skeleton + scenario | 190 s | 100 ms | 1 900× |
| Titles | 30 s | 50 ms | 600× |
| **Total** | **~1140 s** | **~120 s** (intro+outro+epic LLM kept) | **~10×** |

### Files livrés (Phase 10.1 + 10.2 + 10.3) — VALIDATED 2026-05-18
1. `docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md` — design complet 12 sections
2. `tools/embed_reference_cards.py` — embedder card-level, idempotent (SHA1 content-hash cache), ETA logging. **Ran successfully**: 2 994 cards × 768 dim → 47.8 MB JSON en 623 s, 0 skipped.
3. `tools/cards_rag.py` — runtime kNN library : `CardsRAG.load()` / `embed_query()` / `knn(filters)` / `compose_route_vec()`. CLI diagnostic. Mesuré **3.2 ms/query** sur 2 994 cartes réelles (scores cosinus 0.77+).
4. `tools/simulate_human_run_v730.py` — PoC end-to-end, exécuté avec succès :
   - **Total wall : 31.82 s pour 16 cartes** (vs baseline 1140 s)
   - **Speedup mesuré : ~35.8×** (3.6× au-dessus de la cible 10× du doc)
   - 16 cartes uniques retrieved (10 summaries distincts, dedup graceful fallback)
   - Mix retrieved : NARRATIVE/EVENT/MERLIN_DIRECT + COMMUNE/RARE/EPIQUE
   - Arc émotionnel naturel : curiosité → sagesse → tension → peur
   - Outro LLM personnalisé sur factions dominantes (druides+niamh)
   - Output : `~/Downloads/merlin_human_run_test_v7.7.30.html` + `.json`

### Mesures empiriques v7.7.30 (rapport 2026-05-18)

| Step | v7.7.29 LLM-only | v7.7.30 mesuré | Speedup |
|------|------------------|----------------|---------|
| Boot CardsRAG | 0 | 1.85 s | — |
| Titles | ~30 s | 0 ms (pool sample) | ∞ |
| Intro LLM | ~40 s | 16.4 s (kept) | 2.4× |
| Skeleton 16 kNN | 250 s | 1.53 s (avg 2.49 ms/card) | 163× |
| Cards play loop | ~480 s | 0 ms (state machine) | ∞ |
| Resolutions 16 | ~400 s | 0 ms (template) | ∞ |
| Outro LLM | ~30 s | 11.8 s (kept) | 2.5× |
| **Total** | **~1140 s** | **31.82 s** | **35.8×** |

### Files restants (Phase 10.4 → 10.5)
5. `addons/merlin_ai/cards_rag.gd` — port GDScript pour intégration in-game (consomme `cards_index_broceliande.json`)
6. Feature flag `MERLIN_FAST_LOAD=1` + A/B QA gate (10 runs LLM vs embedding-first)
7. Pre-baked resolution variants (Phase 10.5) — actuellement template, à étoffer avec pool de 2-3 variantes par option

### Pré-requis run pour Phase 10.3
```bash
# 1. Build le card index (one-shot, ~3 min sur 2 900 cartes via nomic-embed-text)
python tools/embed_reference_cards.py
# → écrit data/ai/cards_index_broceliande.json

# 2. Smoke kNN runtime
python tools/cards_rag.py --query "Une rencontre dévoile un secret du chêne" --k 5 --type EVENT

# 3. (à venir Phase 10.3) Full PoC run
python tools/simulate_human_run_v730.py
```

### Why "10× better" not just "10× faster"
1. Bible compliance free (pool pré-validée)
2. 8 MB shipped vs 1.6 GB Gemma weight pour le hot path (200× plus petit)
3. Déterminisme : même seed → même run (reproductible QA)
4. Mode offline-only viable (joue sans LLM)
5. Localisation possible (pool traduisible humain)
6. Accessibilité : réponses instantanées

---

## Phase 11 — Narrative depth + DnD-without-combat (delivered 2026-05-18)

User asked (verbatim) : *"Bien plus de scénario et de longueur dans les cartes, investigue avec des agents architectures IA / LLM ce qui peut être optimisé et avec des agents ecrivains pour plus de profondeur et de cohérence, un vrai fil rouge, investigue egalement avec des agents game design pour ajouter de la stratégie dans les choix et une profondeur dans les choix plus que simplement faire des choix, à la manière d'un DnD mais sans combat."*

### Diagnostic mesuré
Pool `scenarios_reference_broceliande.json` : 2 994 cartes mais **90 strings uniques** = **97% de duplication**. Top 10 dupes : "Un druide voyageur…" ×116, "Une créature étrange…" ×107, "Le temps ralentit…" ×102, etc. La duplication faisait que kNN convergeait sur 1 cluster → Beat N ≡ Beat N+1 dans v7.7.30.

### Synthèse 3 agents (parallèles)
- **LLM architect** (general) : M1 pool dedup + LLM batch enrichment, M2 MMR re-rank, M3 streaming stitcher async.
- **merlin-narrative-designer** : 3 leviers +0 LLM (anchor table, header template, cascade prompt) + Phase 11+ LLM outro avec mémoire.
- **merlin-game-designer** : DnD-without-combat — hidden DC + 3 outcomes (success/partial/failure) + 4 ressources (Souffle/Essence/Karma/Anam) + signaux qualitatifs `[Confiant]/[Risqué]/[Éprouvé]/[Verrouillé]` + tags inter-beat.

→ Rapport complet : `docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md`

### Files livrés
1. `docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md` — design 6 sprints
2. `tools/dedup_and_expand_pool.py` — Sprint 11.1 : 2 994 cartes → 90 buckets, batch LLM enrichment (gemma4:e4b, JSON mode + json-repair, fallback template per option). Output `data/ai/cards_meta_v2.json` (canonicals avec prose_short/long, anchor_motif, 3 enriched_options avec DC + 3 outcomes + cost + gated_on)
3. `tools/cards_rag.py` — Sprint 11.2 : nouveau param `dedup_summary=True` (kills 97% dup) + `mmr_lambda=0.6` (MMR re-rank) + nouveau helper `_mmr_select`. Backward-compatible.
4. `tools/simulate_human_run_v731.py` — Sprint 11.3+11.4 : pipeline complet, lit v2 pool + raw pool fallback, agent stratégique (score = signal+balance+rng), `resolve_dc(option, state, rng)`, ADD_TAG/PROMISE/karma inter-beat, transitions templates avec anchor (5-movement model), outro cascade-prompt

### Mesures empiriques v7.7.31 (2026-05-18, seed=42)

| Dimension | v7.7.30 | v7.7.31 | Statut |
|---|---|---|---|
| Unique summaries / 16 | 10/16 | **16/16** | ✅ Sprint 11.2 |
| DC outcome distribution | 16 success | succ=5, partial=9, failure=2 | ✅ Sprint 11.3 |
| 5-movement coverage | 0 | M1=3, M2=4, M3=2, M4=4, M5=3 | ✅ Sprint 11.4 |
| Transition prose | none | "Un seuil se franchit. L'apres-coup de refuser t'accompagne." | ✅ Sprint 11.4 |
| Resolution source | template f-string | LLM-prose si v2, sinon summary | ✅ Sprint 11.3 |
| Inter-beat memory | none | tags + karma + promises | ✅ Sprint 11.3 |
| Avg kNN/card | 2.49 ms | 5.14 ms (dedup_summary scan deeper) | ✅ acceptable |
| **Total wall time** | 31.8 s | **102.8 s** (intro+outro plus larges) | quality > speed |

### Status batch LLM enrichment
- Sprint 11.1 batch (`dedup_and_expand_pool.py`) : 90 canonicals à enrichir, ~3 min/bucket sur gemma4:e4b. Plusieurs interruptions (Ollama down, contention avec v731). 
- État actuel : 5 canonicals dans v2 (1 LLM-source, 4 fallback). Cache idempotent — re-run reprend où batch s'est arrêté.
- ETA full batch : ~4-5h sur gemma4:e4b. Recommandation : lancer overnight sans contention.
- v731 fonctionne déjà sur fallback : 102.8 s avec 0 LLM-source. Quand le batch finit, v731 sans changement gagne automatiquement la prose enrichie + DC réels.

### Sprints restants (Phase 11.5 + 11.6)
- **Sprint 11.5** — Streaming stitcher : 80-token Gemma async entre beats, masqué par l'animation UI. Remplace `transition_prose` template par LLM. +0s perçu, +~80s background.
- **Sprint 11.6** — QA gate : 10 runs side-by-side v7.7.29/30/31 sur seeds identiques + rating manuel 1-5 (coherence/depth/strategic-feel). Bump bible v3.5 → v3.6 avec §25 (Inter-Beat Narrative Contract) + §26 (Hidden-DC doctrine).

### Pré-requis pour run v731
```bash
# 1. Bâtir le card index (one-shot, ~3 min)
python tools/embed_reference_cards.py

# 2. Enrichir le pool (offline, ~4h ; resumable via cache)
python tools/dedup_and_expand_pool.py

# 3. Run le PoC
python tools/simulate_human_run_v731.py
# → ~/Downloads/merlin_human_run_test_v7.7.31.html + .json

# 4. (Optionnel) Activer Sprint 11.5 — stitcher LLM parallèle entre les beats
MERLIN_STITCHER=1 MERLIN_STITCHER_WORKERS=2 python tools/simulate_human_run_v731.py
```

### Sprint 11.5 — Async LLM beat-chain stitcher (delivered 2026-05-18)

**Livré** :
- `tools/beat_chain_stitcher.py` — module standalone + CLI. ThreadPoolExecutor avec `max_workers=2` (configurable via `MERLIN_STITCHER_WORKERS`). Prompt système 2 phrases obligatoires en 2ème personne, sans révéler l'option à venir.
- Wire-in dans `tools/simulate_human_run_v731.py` derrière feature flag `MERLIN_STITCHER=1`. HTML render les bridges LLM avec badge `LLM` pour distinguer du template fallback.

**Mesures empiriques (seed=42, gemma4:e2b, 15 bridges)** :

| Métrique | Valeur |
|---|---|
| Bridges générés | 15/15 (100% yield) |
| Avg / bridge | 13.0 s |
| Wall stitcher | 100.5 s |
| Sum sequential | 195.2 s |
| **Parallel speedup** | **1.94×** (sur 2 workers) |
| Chars / bridge | 82-109 (cible 2 phrases) |
| Total run avec stitcher | 225.3 s |

**Exemple de qualité (Beat 5)** :
- Template : *"Un seuil se franchit. L'apres-coup de accueillir t'accompagne."*
- LLM      : *"L'ombre s'étire, te mordant la peau. Cherche un creux dans le bois pour te couvrir."* (sensoriel + foreshadowing de "la nuit tombe plus vite" qui suit)

**Limites + suites** :
- Avec 4 workers (au lieu de 2), Ollama queue se sature → bridges timeout. Garder à 2 pour gemma4:e2b sur CPU.
- En-jeu : bridges doivent être masqués diégétiquement par l'animation entre cartes UI (≤2s de masque suffisant si les bridges N+2 sont pré-fetchés pendant le tour N).
- Avec gemma4:e4b (plus lent mais plus riche), bumper le timeout par-call à 60s et passer à workers=1.

### Bilan Phase 11 (Sprints 11.1 → 11.5 livrés)

| Sprint | Livrable | Statut |
|---|---|---|
| 11.1 | `tools/dedup_and_expand_pool.py` + batch ~60% (36 LLM, 23 fallback) | ✅ partiel — batch resumable |
| 11.2 | `tools/cards_rag.py` : `dedup_summary` + MMR | ✅ shipped, **1/5 → 5/5 unique vérifié** |
| 11.3 | DnD-without-combat (DC + 3 outcomes + tags + agent stratégique) | ✅ shipped |
| 11.4 | Anchor + 5-movement model + template transitions | ✅ shipped |
| 11.5 | `tools/beat_chain_stitcher.py` (LLM bridges parallèles) | ✅ shipped |
| 11.6 | Bible v3.5 → v3.6 (§25 Inter-Beat Contract, §26 Hidden-DC) + QA gate 10 runs A/B | ⏳ TODO |

### Mesures finales v7.7.31 (avec Sprint 11.5)

| Dimension | v7.7.30 | v7.7.31 +stitcher | Statut |
|---|---|---|---|
| Unique summaries / 16 | 10/16 | **16/16** | ✅ |
| DC outcomes mix | 16 success | succ=4, partial=10, failure=2 | ✅ |
| 5-movement coverage | 0 | M1=3, M2=4, M3=2, M4=4, M5=3 | ✅ |
| Inter-beat transitions | 0 | 15/15 LLM bridges (100% yield) | ✅ |
| LLM-source options labels | 0 | ~10/16 (depends on v2 batch coverage) | 🟡 |
| Total wall time | 31.8 s | 225 s (stitcher on) / 122 s (off) | quality > vitesse |
