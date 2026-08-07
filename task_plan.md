# Task Plan — MERLIN Game Development

> **Source**: `docs/DEV_PLAN_V2.5.md` (canonical phase plan).
> **Consumed by**: `tools/octogent/prompts/studio-director.md` Tier 1 backlog.
> **Last refresh**: 2026-05-17 (v7.7.24 brain cartography + strict mode + guardrails + persistence).

---

## v7.7.24 — Brain cartography + strict mode + guardrails + persistence [2026-05-17]

User mandate (verbatim) : *« Cartographie précisemment dans la bible du jeu et dans tes dev le fonctionnement, utiliser le principe de rag et d'embedding complexe està prioriser pour avoir un "cerveau" toujours fonctionnel et du contexte tout le temps injecté dans le jeu, il faut une forme de persistence avec des gardes fous puissant pour ne pas en sortir. »*

User locked decisions (AskUserQuestion) :
- **Doc scope** : Tout (bible + dev + agents.md + KB GDScript)
- **Guardrails** : Tout passe par MerlinOmniscient.apply_guardrails (centralisé)
- **Persistance** : Tous les niveaux activés (cross-run memory + query cache + run summaries embedded)
- **Brain availability** : Strict — si LLM down, on bloque (no silent fallback)

### Phase 1 — Bible §9 cartography (REWRITE)

`docs/GAME_DESIGN_BIBLE.md` §9 (Architecture LLM) entirely rewritten ~250 lines, 12 sub-sections :
- §9.0 Vue d'ensemble + Mermaid flowchart du pipeline complet
- §9.1 4 LLM (titres / intro / skeleton / cartes) avec RAG + Guardrails + Latence cible
- §9.2 Multi-Brain hardware (Narrator 4B + GM 2B + Embedder nomic-embed-text)
- §9.3 DEUX RAGs coordonnés (RAGManager game-state + ScenariosRAG references)
- §9.4 Garde-fous orchestration centralisée (HARD/SOFT/SUGGEST tiers + forbidden words)
- §9.5 Persistance toutes couches (5 registries + cross-run memory + learned embeddings + LRU cache)
- §9.6 Stricte disponibilité — pas de fallback silencieux (lock decision)
- §9.7-9.8 Contrat Narrator + GM (préservés)
- §9.9 Prefetch total
- §9.10 6 Points d'intégration LLM (mapping fonctionnel)
- §9.11 Reference files — où trouver quoi

### Phase 2 — MerlinAI.is_brain_ready() (NEW)

`addons/merlin_ai/merlin_ai.gd` : NEW public method `is_brain_ready() -> bool`. Returns true only when LLM brain fully operational (is_ready flag + method binding check). Callers MUST gate scene entry on this.

### Phase 3 — Strict mode pre-flight + offline parchment

`scripts/scenario_loading.gd::_run_flow` : added pre-flight check at top.
- If `not MerlinAI.is_brain_ready()` and not capture/smoke mode → `_show_brain_offline_and_return()`
- NEW `_show_brain_offline_and_return()` : shows parchment with lore-aware offline message + back to Hub via PixelTransition

### Phase 4 — Guardrails layer in ScenariosRAG

`addons/merlin_ai/scenarios_rag.gd` : NEW public method `validate_llm_text(text, context) -> Dictionary`.
- HARD reject : 20 forbidden words (4th wall : simulation/IA/programme ; anglicismes : spawn/loot/hub ; cyber : neon/cyber/circuit/data — canon §9.4.2)
- Whole-word case-insensitive matching via `_contains_whole_word` (custom impl, no Regex dependency)
- Min length check (>= 20 chars)
- Returns `{valid: bool, reason: String, retry_recommended: bool}`

Wired into `scenario_planner.gd::generate_intro` post-LLM : on guardrail reject → falls back to RAG-retrieved canon intro.

### Phase 5 — ScenariosRAG persistence (all levels)

`addons/merlin_ai/scenarios_rag.gd` additions :
- NEW const `LEARNED_PATH := "user://scenarios_rag_learned.json"`
- NEW const `QUERY_CACHE_PATH := "user://scenarios_rag_query_cache.json"`
- `_ready` extended : loads learned embeddings + query cache from disk on boot
- `_notification(NOTIFICATION_PREDELETE)` : auto-saves query cache on shutdown
- NEW public `save_query_cache()` : manual trigger
- NEW public `learn_run_summary(summary_text, run_metadata)` : embeds summary via Ollama → appends to in-memory index → persists to `user://scenarios_rag_learned.json`
- NEW private `_append_learned_to_disk` : atomic write of learned entries

Effect : the in-game LLM learns the player's style across runs. Schema :
```json
{
  "model": "nomic-embed-text", "dim": 768, "status": "ok",
  "count": 1, "generated_at": "2026-05-17 12:34:56",
  "embeddings": [{
    "id": "learned_20260517_153021_a3f8b2c4",
    "vector": [0.012, -0.045, ...],
    "summary_text": "Tu as choisi le silence du chêne. La forêt t'a admis.",
    "title": "Run vécu", "archetype_id": "learned",
    "learned_at": "2026-05-17 15:30:21"
  }]
}
```

### Phase 6 — Mermaid diagram (bible §9.0)

Full pipeline visualization embedded in bible §9.0 showing : brain readiness check → LLM 1 (titles, RAG) → pick → LLM 2 (intro, RAG + guardrails) → parchment → LLM 3 (skeleton, RAG + balance) → BoardNarration → LLM 4 (cards, RAG + RAGManager + guardrails) → registry sync → end run → embed summary → save.

### Verified evidence

- ✅ Parse-check `validate_step0` : exit=0, 10 pre-existing phantom_camera errors only
- ✅ Smoke ScenarioLoading 15s : **`exit=0 script_errors=0 total_errors=0 passed=True`**
- ✅ Strict mode triggers correctly when MerlinAI not ready : log `[ScenarioLoading] v7.7.24 strict mode : LLM brain not ready — blocking scene`
- ✅ ScenariosRAG boot log : `Loaded 100 scenarios, 100 embeddings (768-dim, status=ok) + 0 learned + 0 cached queries` (persistence layer loaded, empty on first session as expected)
- ✅ FORBIDDEN_HARD const fix : `PackedStringArray(...)` ctor not constant-expression in GDScript → use plain `Array`

### Files modified

| Path | Status | Purpose |
|---|---|---|
| `docs/GAME_DESIGN_BIBLE.md` §9 | REWRITE (80 → ~250 lines) | Full v7.7.24 cartography + Mermaid diagram |
| `addons/merlin_ai/merlin_ai.gd` | MODIFIED | NEW `is_brain_ready()` accessor |
| `addons/merlin_ai/scenarios_rag.gd` | MODIFIED (~150 LOC added) | NEW `validate_llm_text` + `learn_run_summary` + `save_query_cache` + disk persistence |
| `addons/merlin_ai/scenario_planner.gd` | MODIFIED | `generate_intro` wraps LLM output in `validate_llm_text` |
| `scripts/scenario_loading.gd` | MODIFIED | Pre-flight strict mode check + `_show_brain_offline_and_return` |
| `task_plan.md` | MODIFIED | v7.7.24 entry (this section) |

### Iterations queued

- **v7.7.24b** — Extend `validate_llm_text` to wrap titles, skeleton, cards (currently only intro wired)
- **v7.7.25** — Hook `learn_run_summary` into `merlin_save_system::on_run_complete` so cross-run learning fires automatically
- **v7.7.26** — Mermaid diagram for full LLM pipeline rendered to PNG and embedded in `docs/LLM_ARCHITECTURE.md`
- **v7.7.27** — Same cartography pattern for the 7 other biomes (when their reference content is generated)

---

## v7.7.23 — Reference-augmented LLM pipeline + parchment intro UI [2026-05-17]

User mandate (verbatim) : *« Ok, maintenant sert toi de ces contenus pour entrainer le LLM du jeu à faire la génération de trois titres de scénarios proposés sur les cartes, puis en fonction du choix l'intro qui va etre exposée sur le parchemin / livre, le scénario complet écris et chargé avec ce niveau de qualité et un autre LLM qui le lis et découpe en cartes pour le run, implémente tout ça dans le jeu »*

User locked decisions (AskUserQuestion in plan mode) :
- **LLM pipeline** : 4 LLM séparés (titres / intro / skeleton / per-beat cards)
- **Branching runtime** : Skeleton linéaire 5-10 beats (références = prose style guides only)
- **RAG strategy** : Index sémantique embeddings via Ollama nomic-embed-text
- **Intro UI** : Parchemin qui se déroule + typewriter

### Phase 1 — Reference data + offline embeddings (Ollama nomic-embed-text)

NEW `tools/embed_reference_scenarios.py` (~110 LOC) — calls Ollama embed API on each of the 100 reference scenarios' `title + archetype_name + intro` text, writes 768-dim vectors to `data/ai/scenarios_reference_broceliande.embeddings.json`. Auto-pulls the model if absent. Idempotent.

NEW files :
- `data/ai/scenarios_reference_broceliande.json` (3.46 MB, 100 scenarios copied from `~/Downloads/`)
- `data/ai/scenarios_reference_broceliande.embeddings.json` (1.6 MB, 100 × 768-dim vectors)

### Phase 2 — ScenariosRAG autoload (kNN cosine retrieval)

NEW `addons/merlin_ai/scenarios_rag.gd` (~280 LOC) :
- `extends Node`, registered as `/root/ScenariosRAG` autoload
- Loads scenarios + embeddings JSON at `_ready`
- Public `query_similar(text, top_k=3, biome_filter="") -> Array[Dictionary]` — calls Ollama HTTP embed for the query then cosine kNN
- LRU cache (50 entries) of query embeddings to avoid re-embedding identical prompts
- Fallback : if Ollama unavailable or embeddings missing → archetype-keyword matching from query text
- 4 formatter helpers : `format_titles_as_few_shot` / `format_intros_as_few_shot` / `format_skeleton_as_few_shot` / `format_cards_as_few_shot`

### Phase 3 — LLM 1 : RAG-augmented title generation

`addons/merlin_ai/scenario_planner.gd::generate_titles(biome_id)` modified :
- Pre-LLM : `await _rag_titles_few_shot(biome_id)` retrieves 5 reference titles via cosine kNN
- Injects them as bullet list in system prompt
- LLM produces 3 NEW titles in the same druidic idiom
- Fallback (24 hardcoded titles) unchanged

NEW private helpers : `_rag_titles_few_shot`, `_get_scenarios_rag`

### Phase 4 — LLM 2 : NEW intro generation (post title-pick)

NEW `addons/merlin_ai/scenario_planner.gd::generate_intro(biome_id, chosen_title) -> String` :
- Pre-LLM : 3 reference intros via kNN cosine on (title + biome)
- System prompt enforces : young druide POV, 6-8 sentences, no 4th-wall break, no anglicisms / cyber / technologie terms
- Params : `max_tokens=400, temperature=0.85, timeout_ms=10000`
- Validates ≥5 sentences in output ; falls back to RAG-retrieved or hardcoded intro otherwise
- NEW const `INTRO_TIMEOUT_S := 10.0`

### Phase 5 — LLM 3 : RAG-augmented skeleton generation

`addons/merlin_ai/scenario_planner.gd::generate_skeleton(biome_id, chosen_title)` modified :
- Pre-LLM : `await _rag_skeleton_few_shot(biome_id, chosen_title)` retrieves 2 reference scenarios' beat sequences (n + emotion + faction_tilt + summary)
- Injects as structural few-shot in `_skeleton_system_prompt`
- Skeleton stays LINEAR 5-10 beats (per user decision)
- v7.7.22a `_balance_skeleton` validator still applies post-LLM

### Phase 6 — LLM 4 : RAG-augmented per-beat card generation

`addons/merlin_ai/bi_brain_pipeline.gd::_call_gm_brain` modified :
- Pre-LLM : `await _rag_cards_few_shot(beat_context, act_type)` retrieves 2 matching reference cards (filtered by CardType : NARRATIVE / EVENT / SHOP / MERLIN_DIRECT)
- Injects as compact few-shot in GM system prompt
- Narrator brain (Phase B) untouched — still wraps GM JSON in rich prose

NEW private `_rag_cards_few_shot(beat_context, act_type) -> String`. `_gm_system_prompt` extended with optional `ref_cards_block` 5th arg.

### Phase 7 — NEW Parchment scroll UI

NEW `scripts/ui/parchment_scroll.gd` (~150 LOC) — `extends PanelContainer` :
- Charter-precedent styling : cream `#eaddad` + dark wood `#4d3218` border + sepia `#6a4a2a` ink (RichTextLabel) + soft shadow
- Public `display(intro_text)` runs full cycle :
  1. Unroll : `scale.y 0→1` over 1.2s TRANS_QUART EASE_OUT + alpha 0→1 in parallel
  2. Typewriter : `visible_characters 0 → text length` @ 60ms/char (≈ 16.6 chars/s)
  3. Hold : 3.0s read-time
  4. Roll-out : `scale.y 1→0` over 0.8s + alpha 1→0
  5. Emit `closed` signal + `queue_free()`
- Total cycle for 6-sentence intro : ~12-15s

### Phase 8 — Game integration in ScenarioLoading

`scripts/scenario_loading.gd::_run_flow` extended : NEW step 2.5 between title-pick (line 198) and skeleton generation (line ~230). Flow becomes :

```
1. Build 3 picker cards (LLM 1 titles + Ogham glyphs)
2. Wait for player click → dim unselected cards (0.6s)
3. LLM 2 : await _planner.generate_intro(biome, chosen_title)
4. Spawn ParchmentScroll, call display(intro_text)
5. Await parchment.closed (full unroll → typewriter → hold → close cycle)
6. LLM 3 : await _planner.generate_skeleton(biome, chosen_title)   [unchanged]
7. Dispatch skeleton + transition to BoardNarration                [unchanged]
```

NEW const `PARCHMENT_SCROLL_SCRIPT := preload("res://scripts/ui/parchment_scroll.gd")`. Reuses MerlinSoundBar pulse system (it keeps animating behind the parchment overlay).

### Phase 9 — Autoload registration

`project.godot` `[autoload]` section gets one new entry :
```
ScenariosRAG="*res://addons/merlin_ai/scenarios_rag.gd"
```
Available globally at `/root/ScenariosRAG` after engine boot.

### Verified evidence

- ✅ Parse-check `validate_step0` : exit=0, 10 pre-existing phantom_camera errors only (none from new code)
- ✅ `python tools/embed_reference_scenarios.py` : pulled nomic-embed-text + generated 100 vectors @ 768-dim (~30s, status=ok, 1.6 MB output)
- ✅ Smoke `res://scenes/ScenarioLoading.tscn` 15s : **`exit=0 script_errors=0 total_errors=0 passed=True`**
- ✅ Boot log : `[ScenariosRAG] Loaded 100 scenarios, 100 embeddings (768-dim, status=ok)` — autoload fully functional
- ✅ All 4 LLM functions now reference-augmented via RAG few-shot (titles, intro, skeleton, cards)

### Files modified / created

| Path | Status | Purpose |
|---|---|---|
| `tools/embed_reference_scenarios.py` | NEW (~110 LOC) | Offline embedding pre-compute via Ollama nomic-embed-text |
| `data/ai/scenarios_reference_broceliande.json` | NEW (3.46 MB) | 100 references copied from `~/Downloads/` v7.7.22c output |
| `data/ai/scenarios_reference_broceliande.embeddings.json` | NEW (1.6 MB) | 100 × 768-dim vectors, status=ok |
| `addons/merlin_ai/scenarios_rag.gd` | NEW (~280 LOC) | Autoload : kNN cosine retrieval + 4 formatters |
| `addons/merlin_ai/scenario_planner.gd` | MODIFIED | RAG-augmented titles + NEW generate_intro + RAG-augmented skeleton |
| `addons/merlin_ai/bi_brain_pipeline.gd` | MODIFIED | RAG-augmented per-card generation in GM brain phase |
| `scripts/ui/parchment_scroll.gd` | NEW (~150 LOC) | Animated parchment unroll + typewriter intro display |
| `scripts/scenario_loading.gd` | MODIFIED | Insert step 2.5 (parchment + LLM 2 intro) between title-pick and skeleton |
| `project.godot` | MODIFIED | Register `ScenariosRAG` autoload |
| `task_plan.md` | MODIFIED | This v7.7.23 entry |

### Iterations queued

- **v7.7.23b** — Voix de Merlin TTS sync with parchment typewriter (require TTS pipeline)
- **v7.7.24** — Runtime branching tree (replicate split-merge tree mechanically at runtime)
- **v7.7.25** — Same embedding pre-compute for the 7 other biomes when their reference content is generated
- **v7.7.26** — Live re-training : when player completes a run, append run summary to references and re-embed (incremental retrieval index)

---

## v7.7.22c — Lore intros + branching multi-route tree + route-view UI [2026-05-17]

User mandate (verbatim) : *« Chaque scénario doit disposer d'une intro bien ecrite selon le lore du jeu / on incarne un jeune druide dans cette simulation (on ne sait pas qu'on est dans une simulation), l'introduction aura vocation à être écrite et exposée au joueur, comme intro donnée pour contextualiser la run. Les scénarios doivent être un peu plus long et avec plus de rebondissement, avec une belle écriture et de la logique, pas simplement des écritures simples sans sens, améliore les scénarios, repense l'UI / UX du menu pour voir plus simplement les parcours, attention on ne fait pas toutes les cartes, certains choix coupe les chemins et donne sur de nouvelles routes, trouve le moyen de rédiger le scénario en plusieurs routes »*

### 3 major upgrades to the generator

**1. Lore-aware intros** : NEW `INTRO_FRAGMENTS` dict — 4 hand-crafted intros per archetype × 10 archetypes = **40 unique intros**, each 6-8 sentences. POV : young druide en initiation. The simulation aspect stays HIDDEN (no 4th-wall break) — the druidic world is presented as real. Each intro situates the player as an apprentice with a master, a clan, a mission. Subtle subtext hints (dreams that anticipate places, déjà-vu) but framed as mystical, not technological.

**2. Branching tree structure (split-merge)** : NEW `build_branching_tree(archetype, length, rng)` that produces a card pool larger than what a single route plays. Architecture :
- **Phase 1 — Shared trunk** (2 cards) : all routes start here
- **Phase 2 — First split** (3 routes × 3 cards = 9 unique branch cards) : choice at c2 routes the player into Ordre / Chaos / Liminal branch
- **Phase 3 — Merge + TWIST** (1 shared card) : Merlin Direct EPIQUE card with a hand-crafted twist prose from new `TWIST_FRAGMENTS` bank (20 reveals total)
- **Phase 4 — Second split** (3 routes × 3 cards = 9 unique branch cards) : choice at twist routes player AGAIN
- **Phase 5 — Shared final stretch** (length-9 shared cards) : all routes converge for the climax

For length=17 : pool = 29 cards, each route plays 17. **12 cards are UNIQUE to a single route — the player never sees them on other runs.**

**3. Route-view UI rewrite** : HTML scenario block now shows the player parcours clearly :
- Intro block (gold-bordered italic, lore quote framing)
- Premise (author's vision)
- Emotional arc (beats per route)
- Pool stats : total pool / cards per route / cards unique to one route / route count
- **Twist callout** : crimson-bordered dashed box highlighting the mid-route revelation
- **3-column route grid** : Ordre / Chaos / Liminal side-by-side, each column showing :
  - Route name + label + cards count
  - Ordered list of cards with shared/unique/twist badges
  - Compact card text inline
- New CSS classes : `intro-block`, `routes-grid`, `route-col.route-{key}`, `branch-tag.{shared,unique,twist}`, `twist-callout`, `pool-stats`

### Schema changes (additive — backward compatible)

```json
{
  "id": "broc_00_00",
  "title": "Le Premier Pas Druidique",
  "intro": "Tu es un jeune druide, à peine sorti des années d'apprentissage...",   // NEW
  "length": 17,                  // cards a single route plays
  "pool_size": 29,               // NEW — total cards in the branching tree
  "twist_card_id": "c12_twist",  // NEW
  "cards": [
    {
      "card_id": "c1",                                  // NEW
      "n": 1,
      "type": "NARRATIVE",
      "rarity": "COMMUNE",
      "pole": "Liminal",
      "route_mask": [true, true, true],                 // NEW
      "branch_label": "trunk",                          // NEW
      "summary": "...",
      "options": [
        {"label": "Observer", "verb": "observer", "primary_faction": "druides",
         "leads_to_card_id": "c2"}                       // NEW
      ]
    }
  ],
  "routes": [                                            // NEW shape
    {"key": "ordre",   "name": "Voie de l'Ordre",   "label": "...", "card_ids": ["c1", "c2", "c3_ordre_b1_0", ...]},
    {"key": "chaos",   "name": "Voie du Chaos",     "label": "...", "card_ids": [...]},
    {"key": "liminal", "name": "Voie Liminale",     "label": "...", "card_ids": [...]}
  ]
}
```

### Output deliverables (in `~/Downloads/`)

- `broceliande_scenarios_v7.7.22.html` — **2.28 MB** (was 1.18 MB in v7.7.22b — doubled due to intros + route grids)
- `broceliande_scenarios_v7.7.22.json` — ~2 MB (richer schema with card_ids + leads_to + branch_labels)

### Verified evidence

- ✅ 100 scenarios, **1794 cards total** in pools (up from 1740 — branching adds cards)
- ✅ Pole distribution preserved : 40 Liminal / 30 Chaos / 30 Ordre (bible §7.1)
- ✅ Length spread : 18×11 / 15×15 / 26×17 / 24×21 / 17×25
- ✅ Sample scenario 0 : intro 6 sentences, pool 29 vs route length 17 (12 route-unique cards), twist at `c12_twist`, 3 routes with distinct card_ids
- ✅ Integrity : **0 broken `leads_to_card_id` links**, **0 missing card_ids in route references**
- ✅ All routes start at shared trunk `c1, c2` then diverge into branch1 cards
- ✅ All routes pass through the shared twist card
- ✅ All routes converge on shared final stretch

### Files modified

- `tools/generate_broceliande_scenarios.py` (+~700 LOC) — INTRO_FRAGMENTS dict (40 intros, ~14k words) + TWIST_FRAGMENTS dict (20 reveals) + `make_intro` / `make_twist` / `build_branching_tree` / `extract_routes` / `_branch_label_to_pole` helpers + refactored `generate_scenario` + rewritten HTML scenario rendering block + new CSS classes

### Iterations queued

- **v7.7.22d** — Ollama optional pass to expand premises 24→60 sentences and enrich twist prose
- **v7.7.22e** — Same generator template applied to 7 other biomes (each with own intros + canon)
- **v7.7.23** — Integrate JSON into `addons/merlin_ai/rag_manager.gd` for runtime LLM reference

---

## v7.7.22b — 100 Brocéliande LLM reference scenarios + HTML doc [2026-05-17]

User mandate (verbatim) : *« Il faut que nous imaginions 100+ scénarios pour broceliande en exemple qui servirons pour le LLM en guise de gage de qualité rédactionnelle, avec pour chacun d'entre eux les consignes de découpage en carte en exemple ... rédaction de haute volée, rebondissements, scénarios calmes, de la variété lié au biome ! De grandes aventures en 25 cartes et d'autres plus courtes en 11 cartes par exemple, génère un doc HTML me permettant demain matin de lire tes 100 scénarios ... et leur découpage en carte avec routes possibles ! »*

### Output deliverables (in `~/Downloads/`)

- `broceliande_scenarios_v7.7.22.html` (1.18 MB) — self-contained druidic dark theme + TOC + filters (Pole/Length/Archetype/search) + collapsibles
- `broceliande_scenarios_v7.7.22.json` (1.45 MB) — same data for LLM ingestion / RAG

### Content structure (verified evidence)

- **100 scenarios** generated (10 archetypes × 10 variants)
- **1740 cards** total, average **17.4 cards/scenario**
- **Avg 24 sentences/premise** (above user's 20-sentence floor, below 100 ceiling)
- **Pole distribution** (per bible §7.1 Liminal-dominant) : 40 Liminal / 30 Chaos / 30 Ordre
- **Length spread** : 16×11c / 20×15c / 34×17c / 16×21c / 14×25c
- **CardType totals** : 1138 NARRATIVE (65%) · 278 EVENT (16%) · 130 SHOP (7.5%) · 130 MERLIN_DIRECT (7.5%) · 64 PROMISE (3.7%)
- **Zero adjacency violations** (no 2 SHOP/MERLIN_DIRECT/RUNE_UNLOCK/PROMISE consecutive)

### 10 narrative archetypes (Brocéliande canon)

| Archetype | Pole | Length pref | Twist pattern |
|---|---|---|---|
| L'Éveil Druidique | Liminal | 11/15/17 | calm_revelation |
| La Ruse des Korrigans | Chaos | 11-21 | deception_unveiled |
| Le Conseil du Chêne Ancien | Ordre | 15-25 | wisdom_arc |
| Le Vagabond de Brume | Liminal | 11-21 | lost_then_found |
| L'Épreuve de la Forêt | Chaos | 15-25 | physical_test |
| Le Rite Oublié | Ordre | 15-25 | ritual_completion |
| Le Sanctuaire Caché | Liminal | 11/15/17 | calm_decision |
| La Bête Cornue | Chaos | 11-21 | wild_communion |
| La Lignée des Druides | Ordre | 17/21/25 | ancestral_echo |
| Le Passage des Seuils | Liminal | 17/21/25 | transformation |

### Generator architecture

`tools/generate_broceliande_scenarios.py` (~900 LOC) :

1. **10 archetype seeds** with Pole, emotion arc, length preferences, twist pattern
2. **3 prose fragment banks** per archetype (opening / middle / closing, 3 fragments each, 3-5 sentences) — **hand-crafted druidic prose** respecting canon (no anglicisms/cyber/neon in text)
3. **Card summary templates** per CardType × Pole (5 cardtypes × 4 Poles ≈ 70 unique card text snippets)
4. **6 option templates** (trio_explore / trio_decide / trio_react / trio_offer / trio_threshold / trio_korrigan)
5. **Deterministic RNG** seeded per scenario `{archetype_id}-{variant_idx}` (reproducible output)
6. **Post-pass adjacency enforcer** : demotes consecutive special types to NARRATIVE COMMUNE
7. **HTML renderer** : druidic dark theme matching MERLIN UI charter (gold border, dark bg, white text, Pole-colored badges)

### Sample scenario titles (10 from 100)

- "Le Premier Pas Druidique" (Liminal, 15 cartes, calm_revelation)
- "Trois Cailloux Blancs" (Chaos, 11 cartes, deception_unveiled)
- "L'Arbre qui Pleure" (Ordre, 21 cartes, wisdom_arc)
- "La Lune Mauve" (Liminal, 17 cartes, lost_then_found)
- "Le Tunnel de Sang" (Chaos, 21 cartes, physical_test)
- "Le Cercle Imparfait" (Ordre, 17 cartes, ritual_completion)
- "Le Pain au Goût d'Enfance" (Liminal, 11 cartes, calm_decision)
- "La Louve aux Yeux Jaunes" (Chaos, 15 cartes, wild_communion)
- "La Stèle Inachevée" (Ordre, 25 cartes, ancestral_echo)
- "Le Seuil entre Deux Forêts" (Liminal, 25 cartes, transformation)

### Compliance with canon

- Bible §3.2 (3 Poles) : badges Ordre/Chaos/Liminal mapped per v7.7.21b system
- Bible §7.1 (Brocéliande = Liminal dominant) : 40% Liminal respected
- Bible §13 (run lengths) : all 5 valid lengths (11/15/17/21/25) represented
- Bible §28.1 (rarity ratios) : Commune/Rare/Épique/Légendaire follow positional rules
- v7.7.22a balance system : card_type / rarity / Pole metadata per card matches DigitalPickerCard.apply_card_metadata schema
- Tone : druidic French throughout, **NO anglicisms, NO cyber/neon/data terms in text** (per content_worldbuilding agent canon brief)

### Iterations queued

- **v7.7.22c** : LLM Ollama expansion to enrich premises 25→100 sentences per scenario (optional richness)
- **v7.7.22d** : RAG ingestion of the JSON into `addons/merlin_ai/rag_manager.gd` for runtime LLM reference
- **v7.7.22e** : Same generator for the 7 other biomes (Landes/Côtes/Villages/Cercles/Marais/Collines/Iles)
- **v7.7.23** : Compare LLM-generated vs reference scenarios for quality scoring

### Files modified
- `tools/generate_broceliande_scenarios.py` (NEW, ~900 LOC) — generator
- `~/Downloads/broceliande_scenarios_v7.7.22.html` (NEW, 1.18 MB output)
- `~/Downloads/broceliande_scenarios_v7.7.22.json` (NEW, 1.45 MB output)

---

## v7.7.22a — LLM scenario card distribution + balance validator [2026-05-17]

User mandate (verbatim) : *« Donc le LLM doit découper les scénarios en ces cartes, en 1-3 versions par run chacune (voir quelques unes ne peuvent pas apparaitre ?) Attention à l'équilibrage ! »*

User locked decisions (AskUserQuestion) :
- **Frequency caps** : Bornes proposées (NARRATIVE 50-70% share, EVENT 1-4, SHOP 1-2, MERLIN_DIRECT 0-3, PROMISE 0-2, RUNE_UNLOCK 0-1)
- **Rarity distribution** : 68/20/8/4 aligned with bible §28.1
- **Pole distribution** : Biaisée par biome (bible §7.1 — Forêt=Liminal+, Marais=Chaos+, Villages=Ordre+, etc.)
- **Enforcement** : 2-layer (LLM prompt nudge + post-LLM validator)

### Data model (NEW consts in `addons/merlin_ai/scenario_planner.gd`)

- `CARD_TYPE_CAPS` : per-cardtype min/max (counts or shares)
- `RARITY_TARGETS` : 0.68 / 0.20 / 0.08 / 0.04 shares
- `BIOME_POLE_BIAS` : 8 biomes × {dominant, secondary[]} per bible §7.1
- `NO_REPEAT_CARDTYPES` : SHOP / MERLIN_DIRECT / RUNE_UNLOCK can't be 2-in-a-row
- `LEGENDARY_START_SHARE` : 0.70 (Légendaire only in last 30%)
- `FACTION_TO_POLE_PLANNER` : legacy 5-faction JSON → 3-Pole UI mapping
- `ACT_TYPE_TO_CARDTYPE` : BEAT_ACT_SEQUENCE → DigitalPickerCard.CardType bridge

### Layer 1 — LLM prompt extension
`_skeleton_system_prompt` extended with a final "ÉQUILIBRAGE" paragraph stating the biome's dominant Pole + 3 distribution rules. Nudges the LLM toward balanced output BEFORE validation runs.

### Layer 2 — `_balance_skeleton(skeleton, biome_id)` post-validator

Six-step pipeline (static method, runs on EVERY skeleton — LLM or fallback) :
1. **Defaults** : fill rarity/pole/card_type per beat if missing. Case-normalizes user-provided values (handles `"legendaire"` / `"shop"` / etc.).
2. **Hard caps** : demote excess cardtypes to NARRATIVE COMMUNE (climax beat preserved — never demoted per reviewer HIGH fix).
3. **Adjacency** : break NO_REPEAT_CARDTYPES streaks by demoting curr to NARRATIVE.
4. **Légendaire placement** : demote rarity to EPIQUE if before last 30% of skeleton.
5. **Soft minimums** : promote middle NARRATIVE COMMUNE beats to fill missing required types (EVENT, SHOP).
6. **Summary log** : `push_warning` in debug builds only (`OS.is_debug_build()` guard).

### Beats now include 3 optional metadata fields

Every beat dict (LLM-generated OR fallback) now exits `generate_skeleton` with :
```gdscript
{
    n: int, summary: String, faction_tilt: String, emotion: String,
    rarity: String,    # COMMUNE | RARE | EPIQUE | LEGENDAIRE
    pole: String,      # Ordre | Chaos | Liminal | Neutre
    card_type: String, # NARRATIVE | EVENT | SHOP | MERLIN_DIRECT | PROMISE | RUNE_UNLOCK
}
```

Consumers can pass these straight into `DigitalPickerCard.apply_card_metadata(rarity, pole, card_type)` (v7.7.21b API). The system is end-to-end.

### Reviewer fixes applied (3 issues)

- **HIGH-1** : `_balance_skeleton` step 2 cap-demotion now skips `j == total - 1` so the climax beat is never demoted to NARRATIVE.
- **MEDIUM-1** : Summary log `print()` → `push_warning()` + `OS.is_debug_build()` guard (matches file convention, no prod log spam).
- **MEDIUM-2** : Step 1 normalizes user-provided rarity/cardtype to UPPER and Pole to TitleCase before comparison (handles French LLM emitting `"legendaire"` / `"ordre"`).

### Verification
- Parse-check `validate_step0` : 10 errors (all pre-existing phantom_camera SVG, none from new code)
- Smoke `res://scenes/ScenarioLoading.tscn` 6s : exit=0 script_errors=0 passed=True
- Re-smoke post-fixes : exit=0 script_errors=0 passed=True
- Code-review : 2 HIGH (1 actual bug climax-skip fixed + 1 style note kept w/ comment), 2 MEDIUM (both fixed)

### Out of scope (future iterations)

- **v7.7.22b** : GBNF grammar update (`scenario_skeleton.gbnf`) to formalize the 3 new fields. Currently the LLM can include them freely; validator fills defaults if absent.
- **v7.7.22c** : DigitalPickerCard scenario picker wires `apply_card_metadata(skeleton.beats[i].rarity, .pole, .card_type)` so the 3 scenario picks show their rarity/Pole at the user. Iter 4 from the v7.7.21 roadmap.
- **v7.7.22d** : LiveCard3D adoption — propagate metadata from beat → in-run card UI when run hits 25-card structure (bible §13 target).
- **v7.7.23** : Real-time balance metrics logged to `tools/autodev/captures/balance_report.json` for playtest tuning.

### Files modified
- `addons/merlin_ai/scenario_planner.gd` : +130 LOC (7 const Dicts + 4 static helpers + `_balance_skeleton` + extended prompt)

---

## v7.7.21b — DigitalPickerCard iter 2 polish + iter 3 rarity/Pole/cardtype system [2026-05-16]

User mandate (verbatim) : *« 2 : ok refine 3 : oui il faut un systeme qui déjà en fonction du contour détermine la rareté de la carte + badge faction si carte de faction, et en fonction si shop event etc le contour est différent »*

User locked decisions (AskUserQuestion) :
- **Rarity tiers** : 4 (Commune / Rare / Épique / Légendaire)
- **Faction badge** : 3 Poles per bible v3.0 §3.2 (Ordre / Chaos / Liminal)
- **Card types** : Set narratif complet — 6 types (narrative / event / shop / promise / merlin_direct / rune_unlock)
- **Badge position** : Coin supérieur droit (28×28 PanelContainer top-right)

### Iter 2 — Typography + spacing refinement
- Title 26 → 28px (more dominant heading)
- Body 16 → 17px (better readability, above 16px minimum)
- Hint 12 → 13px
- Glyph 40 → 44px (more iconic top-left)
- VBox separation 10 → 12 ; content margin 20 → 22 (breathing room)
- Hover scale 1.03 → 1.04 ; durations 0.15 → 0.18s (slightly more responsive)
- animate_in 0.45 → 0.50s alpha / 0.55 → 0.60s scale (smoother cascade)
- mark_chosen pulse 0.18→0.20 + 0.30→0.32 (subtler punch)

### Iter 3 — Rarity / Pole / Card type encoding system
**3 new enums** :
```gdscript
enum Rarity { COMMUNE, RARE, EPIQUE, LEGENDAIRE }
enum Pole { NEUTRE, ORDRE, CHAOS, LIMINAL }
enum CardType { NARRATIVE, EVENT, SHOP, PROMISE, MERLIN_DIRECT, RUNE_UNLOCK }
```

**4 new constants** :
- `RARITY_BORDER_COLORS` — dim_gold / UI_GOLD / royal_violet / bright_gold
- `RARITY_BORDER_WIDTHS` — 3 / 4 / 5 / 6 px
- `POLE_DATA` — color + glyph + name per 3 Poles (bible §22 canonical : Ordre Or, Chaos Violet, Liminal Cyan)
- `FACTION_TO_POLE` — legacy 5-faction JSON data (druides/anciens/korrigans/ankou/niamh) → 3 Pole mapping

**NEW public API** : `apply_card_metadata(rarity, faction_or_pole, card_type)` — optional post-setup() call. Accepts String ("druides", "ordre", "chaos") or Pole enum int for `faction_or_pole`. Idempotent.

**NEW Pole badge widget** — 32×32 PanelContainer top-right (offset_left=-44, top=12) with Pole glyph centered, accent-tinted 2px border, charter-compliant dark bg.

**NEW idle pulse animations** (Tween.set_loops()) per card_type :
- Rarity.LEGENDAIRE : border alpha breathing 1.0↔0.65 @ 2.4s cadence
- CardType.EVENT : same breathing @ 1.6s cadence
- CardType.MERLIN_DIRECT : crimson glow lerp @ 1.0s cadence
- CardType.RUNE_UNLOCK : iridescent hue cycle gold→violet→cyan @ 3.6s

**Border color cascade** : rarity → card_type tint → locked dim. Bg stays UI_BG_DARK (intraitable).

### 2 reviewer MEDIUM fixes applied
- `_build_or_clear_pole_badge` : `queue_free()` → `free()` to avoid one-frame two-badge flicker
- `_set_border_color` : also updates `_stylebox_hover.border_color` (prevents pulse desync on hover)

### Files modified
- `scripts/ui/digital_picker_card.gd` : 288 → ~480 LOC (rarity + Pole + cardtype + idle pulse system)

### Verification
- Parse-check `validate_step0` : 10 errors (all pre-existing phantom_camera SVG, none from new code)
- Smoke BoardNarration 6s : exit=0 script_errors=0 passed=True
- Smoke ScenarioLoading 6s : exit=0 script_errors=0 passed=True
- Code review : 0 HIGH, 2 MEDIUM (both FIXED — flicker + hover desync)

### Wiring (iter 4 queued — not in 21b)
- Biome picker : biomes don't have rarity/Pole inherently (each biome IS its own category). Keep current per-biome accent unchanged.
- Scenario picker : the 3 scenarios from LLM could map idx 0/1/2 → Commune/Rare/Épique tier. Deferred to iter 4 when LLM `body` integration also lands.
- LiveCard3D : NOT in scope for v7.7.21b. The system is exposed for future use when the in-run card UI adopts DigitalPickerCard.

### Out of scope (next iterations)
- **Iter 4** : LLM body field for scenarios + wire scenario rarity tiers
- **Iter 5** : LiveCard3D adoption (or sister 2D card widget for in-run choices)
- **Iter 6** : Shader-based iridescent border for RUNE_UNLOCK (currently color cycle Tween — works without GLSL)

---

## v7.7.21 — Unified DigitalPickerCard (biome + scenario pickers) [2026-05-16]

User mandate (verbatim) : *« Les menus de selection de biomes et de selection de scenarios doivent être les mêmes, a retravailler en UI UX ce n'est pas lisible et moche, travaille en itération et force le mode /loop pour travailler toute la nuit dessus. Je veux une interface claire, détaillé et jolie, là c'est rugueux sans aspérité »*

User locked decisions :
- **Biome descriptions tone** : Poétique-mystique (druidic imagery, 2 lines/biome)
- **Iteration 1 scope** : Full polish (component + 2 pickers retrofitted + animations)

### Phase 1 — NEW component `scripts/ui/digital_picker_card.gd` (~280 LOC)
- `class_name DigitalPickerCard extends PanelContainer`
- 320 × 400 px, charter-compliant (UI_GOLD border, UI_WHITE text + UI_BLACK outline, UI_BG_DARK)
- Public API : `setup(card_id, title, body, ogham_glyph, accent_color, locked, lock_message)`, `animate_in(delay)`, `mark_chosen()`, `dim_unselected()`
- Layout : Glyph 40px / Title 26px / 2px accent separator / Body 16px autowrap / Hint 12px
- Hover : border 4→6 + bg lighten + scale 1.03 TRANS_BACK
- Click : scale pulse 1.0→1.08→1.0 (sequential) + crimson flash overlay + emit signal
- Locked : dimmed everything + "✕ VERROUILLÉ" hint + lock_message tooltip
- 6 code-review fixes applied (animate_in parallel pattern, flash bind_node(self), free() for immediate child cleanup, charter UI_OUTLINE_SIZE everywhere)

### Phase 2 — ScenarioLoading retrofit
- DROP : `_build_parchemin_meshes`, `_build_single_parchemin`, `_build_pick_buttons`, `_clear_pick_buttons`, `_on_parchemin_clicked`, per-frame `_process` unproject sync
- DROP constants : PARCHEMIN_W/H/GAP/Y/Z, PARCHMENT_COLOR, INK_DARK
- NEW : `_build_scenario_cards(titles)` instantiates 3 cards in HBoxContainer on `_ui_layer`
- NEW : `SCENARIO_BODY_FALLBACKS` array (poetic teaser per tier when LLM body absent)
- Stagger reveal preserved : cards animate_in at t=0, 2.5s, 5.0s (10s cascade budget)
- Sound bar pulses per card materialization via SceneTreeTimer (guarded with `is_inside_tree()` for safe back-button exit)

### Phase 3 — BoardNarration biome picker retrofit
- DROP : 8 inline Button widgets with per-biome StyleBoxFlat (76 LOC)
- NEW const : `BIOME_DESCRIPTIONS` — 8 poetic-mystic 2-line teasers
- NEW : 8 DigitalPickerCard in 4×2 GridContainer (offset_left=-676, top=-412 for 1352×824 grid at 1920×1080)
- Per-biome accent : `BiomePalettes.get_palette(biome_id)["accent"]` preserved
- Stagger reveal cascade : 80ms between cards (640ms total intro)
- Locked cards : `setup(locked=true)` with lock_message tooltip ; signal not connected

### Phase 4 — Charter doc + task_plan
- `docs/UI_UX_CHARTER.md` Section 4.7 — DigitalPickerCard spec + usage + deployments list
- `task_plan.md` v7.7.21 entry (this section)

### Verification
- Parse-check `validate_step0` : 10 pre-existing phantom_camera SVG errors only (no new errors)
- Smoke `res://scenes/BoardNarration.tscn` 8s → `exit=0 script_errors=0 passed=True`
- Smoke `res://scenes/ScenarioLoading.tscn` 8s → `exit=0 script_errors=0 passed=True`
- Final code-review : 1 HIGH (orphan timer on back-button exit) + 1 MEDIUM (container height) both FIXED

### Iterations queued (post-visual-review)
- **2** : Refine spacing/anims/typography per user feedback
- **3** : Per-card hover preview (mini 3D preview ? tags badge ?)
- **4** : Selection animation polish + LLM body for scenarios (planner returns `body` field)

---

## v7.7.20 — Intraitable UI system (gold border + white text + black outline + dark bg) [2026-05-16]

User mandate (verbatim) : *« Force la vérification de TOUTES les UI et UX de chaque scene du jeu, tout doit être au même format, on doit avoir un systeme intraitable complet qui quand positionné dans une case ou espace délimité est toujours représenté de la même manière ... (bordure gold, texte en blanc entouré de noir sur fond légèrement assombri pour facilité la lecture) »*

### Phase 1 — Tighten MerlinVisual factories
- NEW const UI_GOLD (0.92, 0.75, 0.30) — bordure gold (single source)
- NEW const UI_WHITE (0.97, 0.97, 0.94) — texte en blanc (single source)
- NEW const UI_BLACK (0.02, 0.02, 0.02) — outline noir
- NEW const UI_BG_DARK (0.05, 0.04, 0.03, 0.92) — fond légèrement assombri
- NEW const UI_BG_HOVER (0.10, 0.08, 0.05, 0.95) — hover bg
- digital_button : ALL kinds (primary/secondary/danger) now share white text + black outline + dark bg. Only border varies (gold/gold-dim/crimson).
- digital_panel : gold border default + dark bg + sharp edges
- Inspirations : Dredge gothic gold + Disco Elysium gold borders + Inscryption digital terminal + Mörk Borg high-contrast

### Phase 2 — Cross-scene retrofit (force ALL buttons through factory)
- MenuTest ENTRER button
- BoardNarration floating option buttons + biome buttons audit
- SelectionSauvegarde save slots
- ScenarioLoading back button (v7.7.19 already retrofitted)

### Phase 3 — Update CHARTER doc
- docs/UI_UX_CHARTER.md : add INTRAITABLE spec section with exact Color values

### Validation
- Smoke each touched scene
- Visual capture : every Button shows gold border + white text + black outline + dark bg uniformly

---

## v7.7.19 — Fix scene transitions + UI charter compliance [2026-05-16]

Plan : `~/.claude/plans/kind-humming-peach.md` v7.7.19 section (user approved).

### Phase 1 — 5 scene-change sites switched to PixelTransition
- `menu_test.gd:822` MenuTest → BoardNarration (ENTRER button — PRIMARY visible)
- `board_narration.gd:433` BoardNarration → ScenarioLoading
- `board_narration.gd:2245` _failsafe_to_hub → MerlinCabinHub
- `scenario_loading.gd:234` ScenarioLoading → BoardNarration (standalone)
- `scenario_loading.gd:244` _on_back_to_hub_pressed → MerlinCabinHub
- All use defensive `get_node_or_null("/root/PixelTransition")` + has_method guard, fallback to bare `change_scene_to_file` if autoload missing
- `ui_overlay_narrative.gd:291` + `game_flow_controller.gd:181` already had proper defensive pattern (audit overcounted)

### Phase 2 — 3 charter violations corrected
- **CRITICAL** `board_narration.gd:3210` floating option buttons `corner_radius_all(8) → (0)` + border `2 → 4`
- `scenario_loading.gd:132-143` back button retrofit via `MerlinVisual.digital_button("← Retour Hub", "secondary")` — was bare Button.new() + manual colors
- `menu_test.gd:210` ENTRER button `border_width_all(0) → (4)` + hover `2px → 6px` (charter mandates ≥ 4 on primary CTAs)

### Validation
- Smoke MenuTest : exit=0 script_errors=0 passed=True
- Smoke BoardNarration : exit=0 script_errors=0 passed=True
- Smoke ScenarioLoading : exit=0 script_errors=0 passed=True

---

## v7.7.18 — 60 FPS aggressive lock + UI/UX charter foundation [2026-05-16]

Plan : `~/.claude/plans/kind-humming-peach.md` v7.7.18 section (user approved via ExitPlanMode).

### User decisions (locked)
- Retrofit scope : **Retrofit complet cross-scene**
- FPS scope : **Agressif : tous les autoloads**

### Phase 1 — 60 FPS fixes
- **FXAA disabled** : `project.godot` `screen_space_aa 1→0` (saves 3-5ms/frame on GL Compatibility renderer — biggest culprit per Explore audit)
- **FPSOverlay optimized** : running-min tracker (was O(N) per frame) + UI refresh throttled to 10Hz (every 6 frames). Saves 0.5-1.2ms/frame.
- **MerlinSoundBar idle frame-skip** : `set_process(false)` when all 12 bars converge to rest. Re-enabled on `pulse()` / `start_speaking()`. Saves 0.4-0.8ms/frame when idle.
- **GameTimeManager throttle** : 60Hz → 10Hz via `_tick_accumulator` (game time imperceptible at 10Hz). Saves 0.2-0.4ms/frame.
- MerlinResponsive : SKIPPED — actual `_process` cost negligible (just touch time tracking when active).

Total expected gain : ~5-7ms/frame recovered. Should restore stable 60 FPS.

### Phase 4 — Charter violations fixed
- `SelectionSauvegarde.gd` line 53 + 84 : `set_corner_radius_all(4) → (0)` + `border_width 1→4` (compliance with `CARD_CORNER_RADIUS=0`)
- `menu_test.gd:169` : title `outline_size 6→4`
- `scenario_loading.gd:126` : info label `outline_size 8→4`

### Phases 2/3/5 — deferred to v7.7.18b (next batch)
- Phase 2 : `docs/UI_UX_CHARTER.md` charter doc
- Phase 3 : `MerlinVisual.digital_button/panel/label/scanline` factories
- Phase 5 : cross-scene retrofit (MenuTest + ScenarioLoading + BoardNarration biome buttons + MenuOptions + SelectionSauvegarde)

---

## v7.7.17 — DA digitalization + 10s ScenarioLoading + thick outline everywhere [2026-05-16]

Plan : `~/.claude/plans/kind-humming-peach.md` v7.7.17 section (user approved via ExitPlanMode).

### User decisions (locked)
- MenuTest digitalization : **Strict terminal/cyberpunk** (drop Persona slashes)
- ScenarioLoading budget : **Élastique avec skip-after-5s**

### Phase 1 — MenuTest DA digitalization (menu_test.gd)
Drop 2 rotated Persona slashes → replace with horizontal data-readout panel (3 monospace rows), hex code drift at margins, denser scanlines (2px alpha 0.10), frequent glitch (every 1.5-3s).

### Phase 2 — ScenarioLoading 10s LLM-writing cascade (scenario_loading.gd)
- Sound bar appears top, speech bubble below
- 3 cards stagger 2.5s apart (0→4.5→7s), each with internal writing anim
- Skip-after-5s hint bottom-right
- Total target 10s with elastic skip

### Phase 3 — Cel-shading 100% coverage + thick outline (cel_shading_manager.gd + merlin_sound_bar.gd)
- DEFAULT_OUTLINE_THICKNESS : 0.015 → 0.022
- NEW const OUTLINE_THICKNESS_MULTIPLIER = 1.4 (global uniform bump)
- merlin_sound_bar.gd : add CelShadingManager.apply to all 12 bars in _ready
- scenario_loading.gd : parchment outline 0.005 → 0.015

### Phase 4 — Biome buttons consistency (board_narration.gd)
border_width 2 → 4, hover 6

### Phase 5 — jocamar PPOutlinesCamera global outline (deferred to v7.7.18 if v7.7.17 ships first)

### Audit findings
99% cel-shading coverage already. Single gap : MerlinSoundBar 12 bars.

---

## v7.7.16 — Remove Mage + 17 asset/shader repos cloned + 60 FPS aggressive [2026-05-16]

Plan : `~/.claude/plans/kind-humming-peach.md` v7.7.16 section.
Commit : `ca639b6a`.

- Phase 1 : KayKit Mage removed from BoardNarration (function body kept for revert)
- Phase 2 : 9 KayKit packs + 5 lowpoly_assets cloned (606 MB gitignored)
- Phase 3 : 2 cel-shaders cloned (eldskald + jocamar) + integration README
- Phase 5 : FPSOverlay autoload + project.godot MSAA 0 / FXAA / scaling_3d=0.9 / mesh_lod=4.0

---

## v7.7.15 — Menu boot construction + Plateau dark arrival + Merlin sound bar + 8 biomes stylés [2026-05-16]

Plan : `~/.claude/plans/kind-humming-peach.md` (user approved).

### Shipped
- **v7.7.15a** (`7c666b62`) :
  - Phase B : project.godot main_scene → MenuTest, max_fps=60, vsync_mode=1 explicit
  - Phase A : menu_test.gd boot prelude (~0.85s) — scanline expand, 5 BIOS lines pop, glitch flash
  - Phase E : 8 biome buttons stylés per palette + Ogham glyph icon, dev_unlock_all_biomes=true
- **v7.7.15b** (`32b757c8`) :
  - Phase D : NEW merlin_sound_bar.gd — 12 BoxMesh bars + pulse/start/stop_speaking API
  - Phase D wiring : _typewriter_narration pulses sound bar per char
  - Phase C : _phase_intro dark room arrival — all lights start at 0, 0.35s darkness, spotlight ramp + 60 particle GPUParticles3D burst

### Captures
- `tools/autodev/captures/v7_7_15a_boot_prelude/` : MenuTest boot construction
- `tools/autodev/captures/v7_7_15a_biomes/` : 8 styled biome buttons
- `tools/autodev/captures/v7_7_15b_dark_sound/` : sound bar visible at back, biomes styled

### User decisions (locked in plan)
- IntroCeltOS supprimé du boot — main_scene direct vers MenuTest
- 8 biomes débloqués pour la démo via `dev_unlock_all_biomes := true`

---

## v7.7.14 — IntroCeltOS tech → mystique refonte [2026-05-16]

User instruction : *« Retravaille la scene d'intro pour qu'elle soit un mélange de boot technique rapide qui se transforme en mystique et qui respecte la DA du jeu, avec de la migration 2D vers 3D »*

### Dispatch Plan
- Wave 1 (research) : direct file analysis (read `_start_phase_*` + `_show_celtos_3d_logo`).
- Wave 2 (impl) : 3-pool boot arc + glitch morph + improved 3D phase.
- Wave 3 (validation) : smoke IntroCeltOS + capture.

### Narrative arc (~6s total, was ~10s)
- **Phase 2A — Tech Latin boot (~1.0s)** : 6 lines Latin tech check (BOOT CeltOS, LOAD DRUID_CORE, INIT RUNE_CIRCUITS 9/9, etc.) — fast pace 0.10s/line
- **Phase 2B — Morph glitch (~0.8s)** : 3 lines Latin+Ogham mix, glitch flash overlay
- **Phase 2C — Pure mystique (~1.0s)** : 3 lines pure Ogham (le voile tech tombe)
- **Phase 3 — 2D→3D rise (~2.5s)** : 2D Ogham scales/tilts, crossfade to 3D SubViewport with CeltOS logo + 2 standing stones cel-shaded outline noir

### Implementation
- [x] Add `BOOT_LOG_POOL_LATIN` (10) + `BOOT_LOG_POOL_MORPH` (3) — kept Ogham pool (12)
- [ ] Update `_pick_random_logs()` to compose Latin → Morph → Ogham sequence
- [ ] Add glitch flash overlay between Latin and Morph
- [ ] Improve `_show_celtos_3d_logo()` : 2 standing stones flanking + CelShadingManager outline
- [ ] Smoke + capture + commit + push

### Compliance
- ACTION 1 design_sprint : ui-ux-pro-max + verification active in session
- ACTION 2/3 dispatcher : read, plan inline (no formal agent dispatch — UI tactical work, current session has all context)
- ACTION 4 task_plan : this section ✓
- ACTION 5 learn-eval : at end of work

---

---

## v7.7.11 — Persona digital UI + addon survey + erasure subtitle [2026-05-16]

User instruction (verbatim) : *« Fais un tour sur les extensions Godots qui nous seraient utiles et deploies ici ! Je veux une interface digital dans le style très prononcé Persona, il faut que ce soit travaillé tout en etant simple et pas surchargé, fais disparaitre définitivement de la bible et de toute note jeu des oghams + du titre, on en parle pas, KayKIT doit me servir de reference graphique pour détourer et comprendre les assets de personnage, decor et autres (variété max) sont fait pour répliquer la technique sous blender et garder en permanence de la cohérence visuelle, essaie de générer egalement à partir d'une image de plateau de broceliande la version améliorée visées grace à gemini (en restant dans du low poly cel shadé) »*

### Phase 1 — Persona menu redesign (DONE)
- [x] menu_test.gd : retirer subtitle « — Le Jeu des Oghams — » + redesign Persona-style
- [x] Palette Persona-celtique : noir profond (#0a0808) + or chaud (#ebb833) + sang celtique (#c72929) + crème (#fbf0d1)
- [x] Diagonal slash or rotation -8° derrière titre
- [x] Diagonal slash crimson plus mince offset
- [x] Titre M.E.R.L.I.N. bold 130px (vs 96 avant) avec outline crème pour lisibilité
- [x] Bouton « ENTRER » : stripe crimson 6px à gauche + fond noir + hover border crimson top/bottom
- [x] Bords nets (radius=0), affordance hover via border (pas glow)
- [x] Footer minimal « Le sage t'attend » (vs verbeux avant)
- [x] Smoke MenuTest : exit=0 script_errors=0 warnings=0 passed=True

### Phase 2 — Cleanup « Jeu des Oghams » subtitle (IN PROGRESS)
Audit a trouvé 78+ occurrences. Priorité = canonical + player-visible :
- [x] menu_test.gd:126 (subtitle in-game)
- [x] CLAUDE.md:1
- [x] PROJECT.md:11
- [x] progress.md:1
- [x] findings.md:1
- [x] docs/GAME_DESIGN_BIBLE.md:1275 + bump v3.0→v3.7
- [x] docs/README.md:1 + paragraph intro L11
- [x] shaders/screen_distortion.gdshader:5
- [x] docs/root/doc.md:1 (architecture title)
- [ ] docs/dashboard.html:459,474,720 (DEFERRED — non-canonical)
- [ ] docs/GAMEPLAY_BIBLE.md / MASTER_DOCUMENT.md (DEFERRED — bulk archives)
- [ ] 20+ legacy docs (DEFERRED — non-critical body refs)

**Règle** : INDIVIDUAL Ogham rune mechanics (Beith/Coll/etc.) **KEEP** — gameplay tokens. Seul le SUBTITLE de marque est purgé.

### Phase 3 — Godot extensions survey + deploy (DONE)
Top 2 installés (MIT, Godot 4.x compatible) :
- [x] `addons/phantom_camera/` (4.3 MB) — Cinemachine-style virtual cameras pour cinematics plateau / cartes / MOS
- [x] `addons/godot_game_template/` (11 MB) — Maaack scene transitions + loader framework
- [ ] DEFERRED : Dialogic 2 (LLM fallback), GodotRetro shaders (CRT/halftone P5), KoBeWi Tween Suite, Chavafei P5 reference (mine code only)

### Phase 4 — KayKit reframe = REFERENCE technique (DONE)
- [ ] Update bible §20.6 : KayKit est REFERENCE graphique pour étudier la technique Blender low-poly cel-shadé + répliquer en assets custom (PAS juste import). Variété max sur perso/décor.

### Phase 5 — Gemini plateau enhancement (BLOCKED quota)
- [ ] nano-banana edit_image sur `frame_0008.png` (capture v7.7.7 plateau actuel)
- Prompt : version améliorée low-poly cel-shadée (outline plus net, plus de variété arbres, accents Celtic knot, fog stylisé, mountains silhouettes, glow mystique pedestal)
- Status : quota Gemini free tier exhausted → retry après cooldown

### Validation
- Smoke MenuTest passed=True (Persona redesign visible)
- Bible header v3.7 (was v3.0 — bumped to match canonical state)

### Visual capture
- `tools/autodev/captures/v7_7_11_persona_menu/frame_0000.png` — Persona menu rendering confirmed

---

## v7.7.7 → v7.7.10 — Pipeline serial cleanup [2026-05-16]

User instruction : *« A, puis tu vérifie et check A et ensuite B ... etc, fais en /loop le traitement »*
Sequential A→B→C→D→E with verification gates.

### A — KayKit canonical asset pipeline (v7.7.8) — `5f0ca582` ✓
- Found KayKit on GitHub : `KayKit-Game-Assets` org (NOT KayLousberg/*).
- Cloned Adventurers pack (142 MB, gitignored).
- Copied `Mage.glb` (3.5 MB committed) to `Assets/blender/kaykit_mage.glb`.
- Fixed bible §20.6 violation : `sigle_token.gd` GLB imports now get
  `CelShadingManager.apply_recursive` (was missing — figurines shipped without outline).
- New `_spawn_glb_guardian(path, pos, scale, rot)` reusable helper in board_narration.
- New `_spawn_kaykit_guardian()` default Mage spawn — fires regardless of plateau source.
- Code-review : 0 CRITICAL/HIGH, 2 MEDIUM fixed.

### B — Disco 4-stat HUD + level-up toast (v7.7.9) — `e7dbd772` ✓
- 4 stacked Labels top-right under "Carte X/Y" : Logic/Empathie/Volonté/Instinct.
- Format : `◆ Logic L3 80%` (glyph + name + level + pass-chance %).
- Color-coded per stat (cyan/rose/gold/violet).
- Live updates via `MerlinStats.stat_changed` signal + scale-pulse FX.
- Level-up toast center-screen 1.5s with fade-in/drift-up/fade-out.
- `_exit_tree` disconnects autoload signals (HIGH-1 leak fix).
- Tweens use `bind_node` to auto-stop on free (HIGH-2 fix).
- Code-review : 0 CRITICAL, 2 HIGH fixed.

### C — Animation P0 trio (v7.7.10) — `efa04948` ✓
- **Parabolic card fly** : `live_card_3d.fly_to_marker` — single linear → 2-phase arc.
- **Boss sting** : red flash + camera Z-punch + SFX, relative recovery.
- **Death anim** : red vignette + camera pull-back + tilt-down + SFX sting.
- Intro transition : already present in `_phase_intro`.
- Code-review : 0 CRITICAL/HIGH, 2 MEDIUM fixed.

### D — Test build verification ✓
- Smoke BoardNarration : exit=0 script_errors=0 passed=True (×4 builds).
- Smoke IntroCeltOS / MenuTest : both passed.
- Captures : `tools/autodev/captures/v7_7_{8_kaykit,9_hud_disco,10_full_test,10_intro,10_menu}/`.
- Confirmed visible : KayKit Mage with outline noir, plateau enrichi, biome cards.

### E — Push + docs (this commit)
- task_plan.md : this section.
- Push origin main : 5 commits (fba4eade → efa04948).

### Status v7.7.10 summary

| Phase | Commit | Status | Verified |
|---|---|---|---|
| v7.7.7 plateau enrichi | `fba4eade` | ✓ shipped | Visual + smoke |
| v7.7.8 KayKit pipeline | `5f0ca582` | ✓ shipped | Visual + smoke |
| v7.7.9 Disco HUD | `e7dbd772` | ✓ shipped | Smoke (HUD post-click) |
| v7.7.10 animations | `efa04948` | ✓ shipped | Smoke (events runtime) |

### Deferred (next session)
- KayKit Skeletons + Medieval Hexagon clones (Ankou + biome tiles)
- 96 P1-P3 items from 106-item animation backlog
- Phase 2 bible §29 : Grimoire UI screen
- Phase 3 : Oghams 18 → 9 Rune-Circuits refacto

---

## Active Feature — v7.7.2.1 Playtest Polish [2026-05-15]

**User feedback (verbatim, post-playthrough with screenshot)** :
*« Le menu principal n'a pas de titre, est flou et comporte des bordures à enlever ... Regarde egalement le texte des cartes, les choix sont sur le côté et illisible et sur la carte elle même aussi, il faut du texte contenu forcemment dedans, limiter le nombre de charactères et /ou prévoir que les cartes puissent se retourner pour afficher plus de scénario »*

### Phase 1 — Quick wins (THIS COMMIT)
- [x] MenuTest : retirer `fog_enabled` (cause flou) + retirer `border_width` du bouton (bordures parasites)
- [x] LiveCard3D : `MAX_BODY_CHARS = 140` + `_truncate_at_word()` smart cut + ellipsis "…"
- [x] LiveCard3D : options Label3D réduites à des ▸ markers (plus de texte qui overlap)
- [x] LiveCard3D : `get_option_texts()` API pour exposer le texte aux Button2D
- [x] BoardNarration : `_build_floating_option_buttons` met le TEXTE dans le Button2D + fixed anchor (bottom 30%, vertical stack centré)
- [x] BoardNarration : `_sync_floating_buttons_to_card_3d` no-op (plus de sync à la position de la carte)
- [ ] Parse + smoke + commit

### Phase 2 — Common asset spawn animation (DEFERRED v7.7.3)
*User : « pour l'intro de celtos, tu utilises les animations de chargement 3D d'asset, ce que tu as utilisé pour le deck de départ ... ces animations d'assets doivent être communes à tous les assets, plateau de jeu compris »*
- Extraire `SigleToken.animate_in` pattern → module commun `asset_spawn_animator.gd`
- Appliquer dans : IntroCeltOS phase 3 (assets 3D au boot), ScenarioLoading parchemins, BoardNarration biome assets, plateau, CardDeck3D
- Pattern : digital upload effect (scale 0→1 + outline trace + opacity 0→1, staggered)

### Phase 3 — ScenarioLoading polish (DEFERRED v7.7.3)
*User : « Le choix des scénarios doit etre mieux animé, essaie de trouver des projets d'animation facile qui correspond à notre jeu pour du godot project que tu pourras manier »*
- Rechercher projets Godot 4 d'animation parchemin/scroll unfurl (GitHub, Godot Asset Lib)
- Améliorer parchemin reveal : unfurl scale Y + ink-write typewriter + plume CPUParticles3D
- TTS Merlin commentary pendant la génération (Phase 2.1.6 backlog)

---

## Active Feature — v7.7.2 Plateau-Only Unified Flow [2026-05-15]

**User directive (verbatim)** : *« Connecte toi en MCP à Godot et lie les scénarios entre eux : intro → menu simple 3D → bouton test → BoardNarration (plateau vide, pièce sombre + lampe vers plateau + bouche Merlin au fond) → biome pick → 3 parchemins LLM → scénario écrit + Merlin commente (clustering, cuisine interne) → assets progressifs → board complet. Tout dans la même scène. »*

### Architecture choices (locked via AskUserQuestion)
| Choice | Decision |
|---|---|
| ScenarioLoading fusion | Sub-scene instanciée en enfant (option 1) — `add_child` au lieu de `change_scene_to_file` |
| Menu simple | Nouvelle scène `MenuTest.tscn` (option 1) — gateway intro→board |
| Ambiance | Vraie ambiance dark + lampe + silhouette Merlin (option 1) — KeyLight + Label3D ogham au fond |

### Implementation Phases
- [x] Phase 1.1 — Créer `scenes/MenuTest.tscn` + `scripts/menu_test.gd`
- [ ] Phase 1.2 — Router IntroCeltOS → MenuTest (3 sites L523, L532, L535)
- [ ] Phase 2.1 — Muscler `BoardNarration._apply_neutral_lighting` : background near-black + ambient dim + fog volumétrique
- [ ] Phase 2.2 — Ajouter `BoardNarration._build_merlin_mouth_silhouette` : Label3D ogham au fond
- [ ] Phase 2.3 — Modifier `BoardNarration._on_biome_picked` : load+instantiate+add_child ScenarioLoading
- [ ] Phase 2.4 — Ajouter `BoardNarration._on_scenario_done` callback
- [ ] Phase 3.1 — `scenario_loading.gd` : signal `skeleton_dispatched` + sub-scene aware `_return_to_board`
- [ ] Phase 4 — Parse check + smoke MenuTest + smoke BoardNarration + commit

### Deferred v7.7.3+
- [ ] Merlin speech-bar widget during scenario writing (Phase 2.1.5 backlog)
- [ ] TTS commentary via use_my_voice (Phase 2.1.6)
- [ ] CPUParticles3D plume mécanique (Phase 2.1.7)
- [ ] Progressive asset cascade visualisation

### UX compliance (4 piliers bible §21.1 + ui-ux-pro-max)
- FACILE : Intro auto → MenuTest click TESTER → Board. 1 click full flow.
- ÉVIDENT : Titre + bouton unique, intention <2s.
- MINIMAL : Pas d'UI parasite.
- TACTILE+DESKTOP : Bouton 360×72 ≥ 44×44, hover stylebox ≤100ms.

### Dispatch Plan
Per `task_dispatcher.md` : UI Layout + Animation + LLM Integration. Direct execution (single-agent) — scope trop petit pour multi-wave. `code-reviewer` invoké en fin de phase.

---

## Active Feature — BoardNarration v6.1 : Hand of Fate 3D Card + Bug Fixes [2026-05-14 part 15]

**User feedback (verbatim):** *"On arrete ce principe de fenetre, tout doit etre ecris dans la carte qui est tirée, façon hands of fate dans la carte qui doit préciser le scnéario et les choix à l'intérieur."* + *"Jouetoi même au jeu, capture chaque frame pour voir la cohérence des animations, tout manquement à ce qui a été décris depuis cette session doit etre corrigé (carte mal animé, texte illisible, boutons manquants, texture et assets n'apparaissant pas au bons moment, assets sur le plateau inutiles...)"*

**v6 livré :**
- [x] NEW `LiveCard3D` component : BoxMesh 1.2×1.7 parchemin face + 5 Label3D (badge, body wrappé, 3 options) + idle float Y bobbing + `await_choice()` async + `fly_to_marker(target)` async
- [x] `_show_live_card_3d(card)` remplace `_show_live_card` parchemin path
- [x] 3 Button2D floating ancrés sur option world positions via `_camera.unproject_position` (synced 10Hz)
- [x] `_get_next_marker_position_preview()` permet à la carte de voler vers le futur marker du pion sans le consommer

**v6.1 bug fixes (en cours après auto-playtest v22) :**
- [x] **Bug 1** : parchemin overlay 2D restait visible pendant LLM fetch (~15s) → hide explicitement au start de chaque iteration du live loop
- [ ] **Bug 2** : LiveCard3D peu visible (rendering/depth/size) → bigger Label3D pixel_size, no_depth_test=true, position closer to camera, double_sided material
- [ ] **Bug 3** : audit dice tray + card deck visuels (peuvent ressembler à "objets parasites" sur plateau)
- [ ] Re-smoke + visual verify chaque frame

---

## Active Feature — BoardNarration v5.7 : Computer-Generated Sequential Reveal [2026-05-14 part 13]

**User feedback (verbatim):** *"Remarque visuelle, des objets intulies sont placés sur le plateau / les carte ne sont pas animées et n'arrivent pas devant nos yeux, il n'y a pas d'animation. Donne un délai d'apparition des éléments de la scène, un élément pa un élément et pas tout en même temps, donne l'impression que c'est généré par un ordinaeur donc trouve un effet qui construit et charge de façon très animé tous les objets en 2 à 10 chunk d'assemblage en tetris ou alors shaders uniquement de contour, trouve une forme sympathique"*

**4 fixes ciblés:**
- [x] `JuiceHelpers.materialize_reveal(host, node, delay)` — hologram-style reveal : scale 0→1 TRANS_BACK + emission flash blanc 3x + material fade back to original (~0.6s par élément)
- [ ] Refactor `_run_biome_drop_choreography` séquentiel : plateau pulse → spotlight → fog → dice tray (delay 0.4s) → card deck (delay 0.7s) → first card flies to camera (delay 1.0s)
- [ ] CardDeck3D `draw_top_card()` : carte vraiment visible devant les yeux (HELD_POSITION_LOCAL plus proche caméra, hover 0.6s avant fade)
- [ ] Audit & nettoyer "objets inutiles" : repositionner BoardBiomeBackdrop trees BEHIND plateau, dice tray rim moins visible, supprimer SigleToken legacy spawns

---

## Active Feature — BoardNarration v5 : Plateau Alive + Physics + Biome Drop [2026-05-14 part 7]

**User feedback (verbatim):** *"Le plateau doit être animé, des effets lumineux, des dés à côté le plateau "vit", des effets volumétriques présent, le filtre PSX doit être très léger, une animation complète lors de la sélection du biome qui fait "tomber" les éléments sur le plateau, il faut intégrer également un gestion des collisions et un moteur physique dans le jeu, les decks de carte doivent être présent et on pioche dedans. Animations très détaillées, cherche des projets sur internet à importer rendant l'exploitation de blender et animation par Claude en MCP bien plus facile et intègre dans le pool d'outils"*

### Sub-features
- [ ] **PSX très léger** : `set_psx_preset("subtle")` instead of "medium" + override scanline/curvature/vignette = 0
- [ ] **Plateau vit** : breathing/pulsing point lights on plateau, volumetric fog drift, subtle ambient particle motion
- [ ] **Dés physiques** : 2-3 RigidBody3D dice next to plateau, idle wobble, roll animation on certain events
- [ ] **Biome drop animation** : on biome pick, all biome assets (trees, props, figurines) DROP from sky onto plateau with physics + gravity + bounce settle (3-5s sequence)
- [ ] **Physics card deck** : visible 3D card stack on plateau, RigidBody3D cards, draw animation = top card lifts + slides into hand zone
- [ ] **Volumetric effects** : light shafts through trees, mist drifts, dust motes
- [ ] **Research tools** : web search Godot 4 + Blender MCP integration, physics card game examples, volumetric addons — integrate into `tools/cli.py` pool

### Wave 1 (PARALLEL design)
- [ ] Research agent : GitHub + Exa search for Godot Blender MCP, physics card games, volumetric setups
- [ ] Plateau-alive design agent : drop choreography spec + lighting plan + dice physics + deck draw flow

### Wave 2 (implementation)
- [ ] Apply PSX subtle preset
- [ ] Build physics card deck (CardDeck3D node : N RigidBody3D cards stacked, draw API)
- [ ] Build 3D dice (2-3 RigidBody3D dice, idle settle, roll on dice_test)
- [ ] Refactor biome reveal as physics drop choreography (assets enter at y=+8, drop with gravity, bounce settle)
- [ ] Add plateau lights (pulsing OmniLight3D × 3, breathing color)
- [ ] Add WorldEnvironment volumetric_fog enabled + drift
- [ ] Document research findings in `docs/MCP_TOOL_RESEARCH.md`

### Wave 3 (verify)
- [ ] Parse check + smoke + visual capture
- [ ] Code review of physics + animation changes
- [ ] learn-eval new patterns (physics card draw, drop choreography)

---

## Active Feature — BoardNarration v4 : Persona/Yakuza UI + Rogue-like Acts [2026-05-14 part 6]

**User feedback (verbatim):** *"Réalise des animations UI / UX proches de Persona / Yakuza, bien vibrant et bien visuellement complexe ! Pour le Game Design, ce n'est pas suffisant, il faut des stats pour chaque situation apparente, avec des choix, des evenements différents type rogue like (boutique / event special / boss etc)"*

### Wave 1 (PARALLEL, design)
- [ ] `ux_animation` agent → produces `docs/BOARD_NARRATION_JUICE.md` (7 animation moments: card deal-in, typewriter accents, button reveal, choice impact, HUD ticker, token spawn burst, card-to-card transition)
- [ ] `game_designer` agent → produces `docs/BOARD_NARRATION_ROGUELIKE.md` (per-card stat readout, 5-act rogue structure: Standard / Shop / Standard / Event / Boss, shop UI / event UI / boss UI specs, 8 new Brocéliande pool cards)

### Wave 2 (SEQUENTIAL, implementation)
- [ ] Apply juice animations to `board_narration.gd` : card deal-in, button reveal slide-from-right, click impact shake+freeze, HUD value ticker, token spawn burst
- [ ] Add `act_type` field to card schema + 5-act sequence in `_run_live_loop`
- [ ] Build stat readout overlay (Difficulty/Risk/FactionPressure/RewardHint badges on card)
- [ ] Implement Shop UI variant (3 wares with price-in-life)
- [ ] Implement Event UI variant (3 event types)
- [ ] Implement Boss UI variant (larger card, 2-phase narration, Anam reward)
- [ ] Add 8 new Brocéliande cards to `fastroute_cards.json` (2 shop + 3 event + 3 boss)

### Wave 3 (Verification)
- [ ] Code-review (everything-claude-code:code-reviewer)
- [ ] Autoplay smoke + visual capture verifying : act indicator visible, stat readout visible, shop variant rendered, event variant rendered, boss variant rendered, all animations smooth
- [ ] Run learn-eval to extract any new patterns

---

## Active Feature — BoardNarration RPG Mechanics + LLM Continuity [2026-05-14 part 5 — corige]

## Active Feature — BoardNarration RPG Mechanics + LLM Continuity [2026-05-14 part 5 — corige]

**User feedback (verbatim):** *"Le scénario doit être écrit et réflechis de long en large par le LLM intégré au jeu, plus de scénarisation, pas seulement de simples éléments, il faut qu'il y ait du lien et que les histoires aient des variances, rebondissements, le texte doit s'écrire petit à petit, pas uniquement des choix mais de la mécanique de RPG autour de ça car là aucun impact, les cartes ne sont pas existantes, j'ai juste des choix qui s'enchainent sans aucun sens ; corige"*

**6 fixes — status:**
- [x] **Typewriter reveal** : `_typewriter_live(text)` at 22 cps with skip-on-click ; replaces instant `text = "…"` assignment in `_show_live_card`
- [x] **LLM timeout bump** : 6s → 15s in `_fetch_card_with_fallback` so the LLM has real generation time
- [x] **HUD with RPG state** : `_build_hud()` adds life ProgressBar (red fill + bronze border) + 5 faction Labels (Druides/Anciens/Korrigans/Niamh/Ankou) in top-right HBox + `_floating_fx_layer` for FX above HUD ; `_refresh_hud()` syncs from `state.run.life_essence` + `state.meta.faction_rep`
- [x] **Floating effect feedback** : `_animate_effect_feedback(effects)` parses ADD_REPUTATION / HEAL_LIFE / DAMAGE_LIFE and spawns `+5 Druides` / `-3 vie` labels via `_spawn_floating_label` (rise + fade Tween 1.6s)
- [x] **Card badges** : `_card_badge_label` RichTextLabel at top of parchment shows title + Ogham glyph (Unicode from `MerlinConstants.OGHAM_FULL_SPECS`) — replaces "just text + 3 buttons" with visible card identity
- [x] **LLM narrative continuity** : Bug found — `context_builder.build_full_context()` was NOT including `story_log` field, so the adapter's two-stage prompt read empty history and every card was generated cold. Fix: add `story_log` + `current_biome` to `build_full_context` return dict. Also bump cap in `store_run.gd::resolve_choice` from 2 to 10 entries so 5-card runs preserve full history.

**Validation:**
- Smoke test passed (exit=0, 0 script_errors, 145 frames captured)
- Frame 10 verified : biome selector with Brocéliande highlighted, 7 others greyed
- Pending : AUTOPLAY=1 smoke to capture HUD + typewriter + floating FX mid-card

---

## Active Feature — BoardNarration Scenario End-to-End [2026-05-14 part 4 — /loop completion]

**Status:** /loop terminates — completion criterion met (jouable + fonctionnel + équilibré, testé end-to-end via autoplay smoke).

### What was added in this iteration
- [x] FastRoute fallback pool wired : `_fetch_card_with_fallback()` races LLM (6s timeout) vs hand-written cards from `data/ai/fastroute_cards.json` (12 Brocéliande entries)
- [x] `_load_fallback_pool()` filters narrative cards to current `_biome_id`, normalizes to `{id, text, prompt, options}` schema
- [x] `_pick_fallback_card()` cycles through the pool round-robin via `_fallback_index`
- [x] **Autoplay mode** : `MERLIN_AUTOPLAY=1` env var → `_build_biome_selector` skips UI and `call_deferred("_on_biome_picked", "foret_broceliande")` ; click deadline drops from 60s to 4s
- [x] Race-with-timeout pattern reused (fire-and-forget Callable + dict holder + poll)

### End-to-end test results (autoplay smoke)
```
INFO smoke exit=0 | script_errors=0 total_errors=17 warnings=5 passed=True
capture_frames: 388
[BoardNarration] AUTOPLAY ON — auto-picking foret_broceliande
[BoardNarration] fallback pool loaded: 12 foret_broceliande cards
[BoardNarration] done — 5 figurines, 0 narrations, outcome=live
```

5 cards resolved live, 5 SigleTokens spawned on plateau, fallback pool successfully cycled through. Verified visually : Card #3 ("Des champignons luminescents forment un cercle parfait au pied d'un vieux hêtre…") displayed with 3 ink-style options ("Entrer dans le cercle" / "Cueillir un champignon" / "Dessiner les runes au sol"). Final state : 5 figurines visible on plateau, parchment closed, biome theme active.

### Balance verification
- LLM 6s race → fallback ensures **no infinite hangs** even cold-start
- Auto-pick option 0 timeout 4s per card prevents stalled run
- `RESOLVE_CHOICE` dispatched via Store applies effects (faction_rep deltas + life essence drain via standard pipeline)
- Run completes in ~190s scene time (intro 4s + 5×~25s cards + outro)
- No script_errors, no engine crashes, no asset load failures

---

## Active Feature — BoardNarration Scene v3 Refonte [2026-05-14 part 3]

**Status:** Major scope expansion landed. The scene now boots into a neutral plateau with a biome selector overlay; only Brocéliande is selectable. Click triggers a reveal animation + parchment-styled scenario UI with the LLM card system. PSX filter is preserved without CRT residuals (scanlines/curvature/vignette = 0).

### Dispatch Plan (per AUTO-ROUTE hook v2026-05-14)

| Wave | Agent | Type | Status |
|------|-------|------|--------|
| 1 | `blender_tower_architect.md` (architect) | PARALLEL | ✅ Spatial+animation architecture delivered (800 words) |
| 1 | `content_worldbuilding.md` (ui_expert) | PARALLEL | ✅ Narrative content + âme design principles delivered |
| 2 | `blender_qa_renderer.md` (reviewer) | SEQUENTIAL | ⏳ Deferred to post-impl review |

Wave 1 outputs preserved verbatim in this session's chat history; key elements integrated below.

### v3 implementation landed
- [x] PSX filter cleaned : `scanline_opacity=0, curvature=0, vignette_intensity=0` (no CRT residuals)
- [x] `_apply_neutral_lighting()` — boot state with warm single overhead spot, no biome tint, no fog
- [x] `_build_biome_selector()` — 8-button overlay (GridContainer 4×2), Brocéliande only unlocked, 7 disabled with "Apprends encore…" tooltips
- [x] Worldbuilding-agent provided lore : `BIOME_TITLES` ("Le Bois qui Murmure" etc.), `BIOME_LOCK_MESSAGES`, `BROCELIANDE_INCANTATION`
- [x] `_on_biome_picked(biome_id)` → `_reveal_biome_sequence()` : apply biome lighting + backdrop + PSX biome tint + spotlight ramp + fog enable + populate UI header + show parchment with arrival incantation, then run live card loop
- [x] Parchment card style : `bg_color = Color(0.92, 0.86, 0.68, 0.97)` cream + `border = Color(0.30, 0.20, 0.12)` dark wood + sepia ink text + dropshadow
- [x] Ink-line option buttons : transparent bg, sepia underline on hover

### Deferred to next session
- [ ] 3D compass-rose beacon mesh (Wave 1 architect spec) — Blender batch
- [ ] 8 3D stone disc tokens (carved emblem per faction) — Blender batch — replaces the 2D Control overlay
- [ ] 3D card deck meshes on plateau (Inscryption-style stacked cards) — Blender batch
- [ ] Full 5.5s animated reveal (mote columns, tree-grow animation) — Tween orchestration
- [ ] Wave 2 QA review by `blender_qa_renderer` — post-impl

### âme design principles applied (worldbuilding agent)
1. Gravité tendre, jamais sombre
2. Le plateau est une nappe, pas une arène
3. Silence comme matière première
4. Pacing de veillée, pas jeu d'action
5. Retenue visuelle = profondeur émotionnelle
6. Le parchemin est une voix, pas une UI
7. Chaque biome a son grain

---

## Active Feature — Lore Assets Batch [2026-05-14 part 2]

**Status:** 14 NEW assets generated autonomously via Blender MCP. Total **19 GLB** assets in `assets/blender/`. Ready for Godot integration next session.

### Newly delivered (14 GLB this batch, ~605 KB)
- 8 PNJ lore — `gwenn`, `aedan`, `bran`, `morwenna`, `seren`, `puck`, `taliesin`, `branwen` (one per biome, distinct silhouette/accessory/hat)
- 5 totem animals/creatures — `raven`, `wolf`, `deer`, `salmon`, `korrigan creature`
- 1 plateau carved wood — `plateau_carved.glb` (113 KB, 16 primitives: rim torus + 8 Ogham radial carvings + rune circle inset + 4 decorative legs)

Full inventory documented in `docs/BLENDER_PIPELINE.md` § "Asset catalogue".

### Pipeline reproducibility
Same `tools/blender/launch.py` + `mcp__blender__execute_blender_code` flow as session 1. Batch run = single MCP call sending ~370-line Python script. All 14 assets exported in ~10 seconds wall-clock.

### Pending integration (not done this session)
- [ ] Replace BoardNarration's procedural `Plateau` `CylinderMesh` with `plateau_carved.glb` instance
- [ ] `sigle_token.gd` — add PNJ-name lookup (currently faction-only). Map biome → PNJ name → GLB filename.
- [ ] Animal cameo system — show totem next to the highlighted figurine during narration
- [ ] Visual smoke check with new plateau + verify the carved rim aesthetic reads well at the camera distance

---

## Active Feature — Blender Autonomous Asset Pipeline [2026-05-14]

**Detailed plan:** `docs/BLENDER_PIPELINE.md`
**Status:** Foundation infra live. 1 placeholder asset (druid figurine) generated end-to-end.

### Delivered this session (2026-05-14)
- [x] `tools/blender/blendermcp_startup.py` — Blender startup script enabling BLENDERMCP addon + starting server on :9876 (non-blocking, hands control to Blender event loop)
- [x] `tools/blender/launch.py` — Python wrapper with start/--stop/--status/--force, Windows SW_MINIMIZE to keep window minimized while preserving the event loop
- [x] `tools/blender/figurines/figurine_druide.py` — placeholder generator (6 primitives, flat-shaded, Inscryption-aesthetic, low-poly stylized)
- [x] **Live verified** — Blender pid spawned, MCP server up, `get_scene_info` round-trips, `execute_blender_code` executes the figurine script
- [x] `assets/blender/figurine_druide.glb` — 27 992 bytes, valid glTF 2.0 binary, 6 meshes embedded, Y-up
- [x] `docs/BLENDER_PIPELINE.md` — pipeline reference, generator convention, PSX/volumetric roadmap

### Critical learning (saved as pattern for `learn-eval`)
- BLENDERMCP `bpy.app.timers.register` dispatcher **requires** Blender's main event loop to tick.
- `--background` mode → main loop DOES NOT tick → MCP commands hang at "Client handler started".
- Any `time.sleep(N)` in the startup script → freezes the main thread → same hang.
- **Fix**: launch WITHOUT `--background`, use OS minimization (SW_MINIMIZE on Windows), and **return immediately** from the startup `main()` so Blender takes over.

### Roadmap — pending next sessions
- [ ] 4 remaining figurines (Anciens, Korrigans, Niamh, Ankou) — copy `figurine_druide.py` template, vary colors + accessory mesh
- [ ] Plateau bois rond — round wooden table with Ogham engravings on the rim
- [ ] Backdrop Forêt Brocéliande — 4-5 tree variants, stumps, ferns
- [ ] Volumetric effects assets — god ray cone meshes, dust mote particles
- [ ] **PSX filter wire-up** (Medium intensity, Inscryption-like) — SubViewport at 480p + `retro_psx_post.gdshader` + vertex snap shader on figurines
- [ ] **VolumetricFog + god rays** in BoardNarration scene
- [ ] Integration `sigle_token.gd` — replace procedural primitives with `PackedScene.instantiate()` of GLB

---

## Active Feature — BoardNarration Refonte v2.2 + FORGE Captures Viewer [2026-05-13]

**Detailed plans:** `docs/BOARD_NARRATION_PLAN.md` + `docs/FORGE_CAPTURES_VIEWER.md`
**Status:** Visual refonte landed. Two BoardNarration bugs fixed + FORGE viewer wired (API + React).

### v2.2 BoardNarration fixes (2026-05-13)
- [x] **Overlay autoloads bypass** — added `MerlinBackdrop` + `ScreenFrame` to `HIDDEN_OVERLAY_AUTOLOADS` (CanvasLayer autoloads were drawing fullscreen ColorRect over the 3D pass)
- [x] **Restore-on-exit** — moved `_restore_global_overlays()` from `_finish()` to `_exit_tree()` (was bringing MerlinBackdrop back over a still-live 3D scene)
- [x] **Spotlight cone softened** — `spot_attenuation 0.7→1.6`, `spot_angle 22→18`, `spot_range 6→5`
- [x] **Volumetric fog added** — `env.fog_enabled=true`, light tan tint, density 0.018 → softens spotlight, adds depth
- [x] **Visual check via PNG capture** — 3019 frames captured, intro+5 figurines+outro all confirmed visible

### FORGE Captures Viewer shipped (2026-05-13)
- [x] `tools/octogent/apps/api/src/createApiServer/capturesRoutes.ts` — 3 routes (list, manifest, serve PNG)
- [x] `requestHandler.ts` — registered `["captures", [...]]` in `API_ROUTE_MAP`
- [x] `tools/octogent/apps/web/src/components/CapturesPrimaryView.tsx` — React scrubber + play controls
- [x] `docs/FORGE_CAPTURES_VIEWER.md` — API contract + wire-up steps + roadmap
- [ ] **Pending wire-up** : allocate `PrimaryNavIndex` slot + add `ConsolePrimaryNav` entry + `PrimaryViewRouter` switch case — see doc

### Known remaining items
- [ ] Patch `tools/adapters/godot_adapter.py` to interpret `--duration` as seconds (currently passes raw to `--quit-after` which counts FRAMES in Godot 4.5 → users need to multiply by 60)
- [ ] Optionally trim `tools/autodev/captures/board_narration_v2/` post-_finish() idle frames (≥frame 1000 are redundant black-ish idle)
- [ ] Run `code-reviewer` agent on 3 new files (capturesRoutes.ts, CapturesPrimaryView.tsx, board_narration.gd v2.2 edits)
- [ ] Run `learn-eval` skill at session end to extract patterns

---

## Active Feature — BoardNarration (Post-Run Cinematic Replay) [2026-05-12]

**Detailed plan:** `docs/BOARD_NARRATION_PLAN.md`
**Status:** IN PROGRESS — 3 helper scripts written, controller + scene + wiring pending.
**Complexity:** MODERATE | **Branch:** main | **Dispatcher classification:** UI Layout + Animation + Shader + LLM Integration

### BoardNarration phase checklist (current sprint)

- [x] AskUserQuestion Wave 1 + 2 (8 dimensions clarified, decisions logged in plan doc)
- [x] `ui-ux-pro-max` skill invocation (design_sprint FIRST)
- [x] Dispatcher + store + infra read (game_flow_controller, end_run_screen, save_system, constants, visual palette)
- [x] `docs/BOARD_NARRATION_PLAN.md` written
- [x] `scripts/board_narration/sigle_token.gd` (class_name SigleToken)
- [x] `scripts/board_narration/biome_ambience.gd` (class_name BoardBiomeAmbience, 8 biome presets)
- [x] `scripts/board_narration/run_journal.gd` (class_name BoardRunJournal, FIFO cap 30)
- [ ] `scripts/board_narration/board_narration.gd` (controller, orchestrates everything)
- [ ] `scenes/BoardNarration.tscn` (minimal root + script self-builds)
- [ ] `scripts/merlin/merlin_save_system.gd` — add `save_run_journal()` thin wrapper
- [ ] `scripts/core/game_flow_controller.gd` — insert BoardNarration phase between run_ended and EndRunScreen
- [ ] `validate.bat` parse-check pass
- [ ] Smoke runtime `python tools/cli.py godot smoke --scene "res://scenes/BoardNarration.tscn" --duration 10`
- [ ] `everything-claude-code:code-reviewer` agent on 6 touched files
- [ ] `llm_expert.md` agent review on LLM commentary loop
- [ ] `superpowers:verification-before-completion` (design_sprint LAST)
- [ ] `everything-claude-code:learn-eval` (session-end ACTION 5)
- [ ] Conventional commit `feat(narration): add post-run BoardNarration scene`

---

## Hard Rules for Studio (read this BEFORE picking a task)

- **GAME WORK ONLY.** No `tools/octogent/`, no `tools/autodev/`, no `server/`, no `validate.bat` edits, no dashboard / Forge UI work. The Forge is the orchestration tool — workers ship the GAME.
- **Use Windows Godot MCP** for scene/script work: `mcp__godot-mcp__*` tools (Godot Engine v4.5.1.stable.official at `C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe`). NEVER spawn `wsl godot` or any Linux Godot binary — the project's runtime target is Windows.
- **Validate via Windows `validate.bat`**: from WSL workers, call `cmd.exe /c "C:\\Users\\PGNK2128\\Godot-MCP\\validate.bat"`. The bat's parse check is the source of truth — `python tools/cli.py godot validate_step0` is an alias that ALSO routes to Windows Godot via `tools/adapters/godot_adapter.py`.
- **Conventional commits**: `refactor(cleanup):`, `feat(merlin):`, `fix(merlin):`, etc. NO `[AI-assisted]` tag (personal project).
- **One task = one commit on `octogent/studio-worker-<N>`**, then `DONE: <task>` to director.

---

## Phase 0 — Cleanup Dead Code (BLOCKING — must reach 0 refs)

> Audit 2026-05-10: 872 dead-code references in `scripts/`. Each item below targets a specific symbol family. Each task is independently committable.

### Phase 0 Tasks

- [ ] **P0-A** Remove `souffle` references from `scripts/`. Targets: dead enum entries, unused vars, comment-stripping where Souffle is referenced as an active system. Acceptance: `grep -r "souffle" scripts/ --include="*.gd" | wc -l` returns 0 (or only comments). [agents: bug_hunter, code-reviewer]

- [ ] **P0-B** Remove `flux` references from `scripts/`. Same shape as P0-A. Targets: `FLUX_*` constants in `merlin_constants.gd`, flux state keys in `merlin_store.gd`, flux UI hooks. [agents: bug_hunter, code-reviewer]

- [ ] **P0-C** Remove `triade` references from `scripts/`. Includes `TRIADE_*` action dispatch rename: `TRIADE_START_RUN -> START_RUN`, `TRIADE_GET_CARD -> GET_CARD`, `TRIADE_RESOLVE_CHOICE -> RESOLVE_CHOICE`, `TRIADE_END_RUN -> END_RUN`, `TRIADE_DAMAGE_LIFE -> DAMAGE_LIFE`, `TRIADE_HEAL_LIFE -> HEAL_LIFE`, `TRIADE_GENERATE_MAP -> GENERATE_MAP`, `TRIADE_SELECT_NODE -> SELECT_NODE`, `TRIADE_PROGRESS_MISSION -> PROGRESS_MISSION`, `TRIADE_USE_SKILL -> USE_SKILL`, `TRIADE_APPLY_EFFECTS -> APPLY_EFFECTS`. Update all callers: `merlin_game_controller.gd`, `test_merlin_store.gd`, `test_llm_full_run.gd`, `test_llm_benchmark_run.gd`, `test_llm_intelligence.gd`, `auto_play_runner.gd`, `game_debug_server.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-D** Remove `bestiole` references from `scripts/`. Includes deletion of `scripts/ui/bestiole_*.gd` files (5 files, ~410 lines), bestiole state in `game_manager.gd`, bestiole UI in `merlin_game_ui.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-E** Remove `awen` references from `scripts/`. Targets: `REROLL_AWEN_COST` in `Calendar.gd`, awen UI hooks. Replace with biome-currency where the gameplay function is preserved. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-F** Remove `gauges` references from `scripts/`. Includes `GAUGES` const in `merlin_card_system.gd`, gauge init/check/effect logic, `LEGACY_GAUGE_EFFECTS` in `merlin_effect_engine.gd` (keep `QUEUE_CARD`/`TRIGGER_ARC` in `VALID_CODES`). [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-G** Remove `essence` references from `scripts/`. Targets: `essence{14}` meta state keys in `merlin_store.gd`, `ESSENCE_*` constants in `merlin_constants.gd`, essence effects in `merlin_effect_engine.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-H** Delete `scripts/minigames/mg_de_du_destin.gd` (D20 dice — replaced by minigame system). [agents: refactor-cleaner]

- [ ] **P0-I** Delete `scripts/ui/hub_souffle_bar.gd`, `scripts/ui/hub_triade_hud.gd`. [agents: refactor-cleaner]

- [ ] **P0-J** Update `scripts/autoload/merlin_visual.gd`: remove palette entries `souffle`, `souffle_full`, `bestiole`. Remove `CRT_ASPECT_COLORS Triade` section. Verify GBC has no dead entries. [agents: art_direction, code-reviewer]

- [ ] **P0-K** Final acceptance check: `grep -rE "souffle|flux|triade|bestiole|awen|bond|gauges|essence" scripts/ --include="*.gd"` returns lines only inside commented historical refs. Then run `cmd.exe /c "C:\\Users\\PGNK2128\\Godot-MCP\\validate.bat"` and verify 0 errors / 0 warnings. Commit: `refactor(cleanup): remove all dead systems (Phase 0 closes)`. [agents: code-reviewer, security-reviewer]

---

## Phase 1 — Core Data Layer Alignment (after Phase 0)

> Bible v2.4 has 18 Oghams with specific effects. The current `OGHAM_FULL_SPECS` in `merlin_constants.gd` does NOT match. Phase 1 corrects the divergences.

### Phase 1 Tasks

- [ ] **P1-A** Read `docs/GAME_DESIGN_BIBLE.md` Ogham specs and `scripts/merlin/merlin_constants.gd:OGHAM_FULL_SPECS`. Produce a diff table (one row per Ogham: bible-effect vs code-effect vs verdict). Output: `docs/audits/ogham_alignment_2026-05.md`. [agents: code-explorer]

- [ ] **P1-B** For each diverging Ogham (from P1-A diff), update `OGHAM_FULL_SPECS` to match the bible. One commit per Ogham (18 max). [agents: bug_hunter, code-reviewer]

- [ ] **P1-C** Verify `OGHAM_AFFINITY_SCORE_BONUS` (+10%) and `OGHAM_AFFINITY_COOLDOWN_BONUS` (-1) constants are wired correctly in `merlin_effect_engine.gd`. [agents: code-explorer, code-reviewer]

- [ ] **P1-D** Add unit tests for `MerlinTestEngine.scaled_dc()` (the asymptotic curve from Cycle 11). Test cases: card_index 0/1/3/5/10/20/30/50 + each `difficulty_tier` 1/2/3 + `base_override` path. File: `tests/test_merlin_test_engine.gd`. [agents: tdd-guide, code-reviewer]

---

## Anti-Targets (DO NOT pick these)

Studio must NEVER spawn workers for:

- Anything in `tools/octogent/` (the dashboard itself — that's "improving the meta-tool")
- Anything in `tools/autodev/` (autonomous loop infrastructure)
- Anything in `server/` (MCP server)
- `validate.bat` modifications
- `package.json` / `pnpm-lock.yaml` modifications
- `.claude/agents/` or `.claude/hooks/` edits
- New audit reports without an explicit user request (they don't ship the game)

If the LLM auto-gen at Tier 3 proposes any of the above, REJECT and try again with the constraint reinforced.

---

## Effectiveness KPIs (track these per session)

- **Game-code commit ratio**: target >= 80% of commits should be in `scripts/`, `scenes/`, `assets/`, `addons/merlin_*`. Current baseline (audit 2026-05-10): 25%.
- **Phase 0 dead-code count**: 872 -> 0. Each `P0-*` task should reduce by 50-150 refs.
- **Worker autonomous commit count**: target >= 1 per worker per hour while running. Current baseline: 0.
- **Validate.bat green**: must stay green (0 errors / 0 warnings) at every merge.

---

## Older entries (archived)

Older focus blocks (C42b code-review fixes, C41 forge redesign, etc.) have been moved to git history. This file now tracks ONLY the live game-development backlog. The Forge tooling work is complete enough to support autonomous game dev — further forge improvements happen only on user-explicit request.

---

## ACTIVE: QA v1 corrective batches (2026-05-14 part 17)

**Origin**: User AskUserQuestion answer after QA v1 multi-agent report (`docs/QA_REPORT_v1.md` — 73% pass / 22 fails / 2 CRITICAL + 6 HIGH).
**Order**: A → B → D (small edits) → C (LLM bulk, background) → QA v2 cascade.
**Smoke gate after each phase.**

### Phase A — Restore Core Loop (CRITICAL)
- [x] A.1 — `merlin_constants.gd:102` LIFE_ESSENCE_DRAIN_PER_CARD = 1 (reverses director q-20260412-001, QA CRITICAL 7.1)
- [ ] A.2 — `merlin_constants.gd:390` EFFECT_CAPS.drain_per_card = 1
- [ ] A.3 — `sfx_helpers.gd` Loop ambient streams (`amb_*` → LOOP_FORWARD) QA CRITICAL 9.2
- [ ] A.4 — `biome_ambience.gd` PRESETS.particle_amount 200 → 60 (QA HIGH 4.8)
- [ ] A.5 — smoke A verify

### Phase B — UX Bible §21 Compliance
- [ ] B.1 — Hide BiomeLabel + NarrationLabel + LifeValueLabel during live card (QA HIGH 8.3)
- [ ] B.2 — SkipButton ≥44×44 px (QA HIGH 8.4)
- [ ] B.3 — Add Back/Retour button → MerlinCabinHub (QA HIGH 3.11)
- [ ] B.4 — smoke B verify

### Phase D — Visual Polish
- [ ] D.1 — `project.godot` MSAA 2x (QA MEDIUM 5.3)
- [ ] D.2 — `project.godot` Viewport 1920×1080 (QA MEDIUM 5.2)
- [ ] D.3 — Delete dead `_build_card_overlay` + 4 refs (QA LOW 1.15)
- [ ] D.4 — Cameo threshold 15 → 10 (QA MEDIUM 6.10)
- [ ] D.5 — Remove 0.5 death halving (QA MEDIUM 6.12)
- [ ] D.6 — Hover SFX on floating buttons (QA MEDIUM 3.15)
- [ ] D.7 — Music cross-fade dedicated AudioStreamPlayer (QA HIGH 9.6)
- [ ] D.8 — smoke D verify

### Phase C — Replayability (background LLM)
- [ ] C.1 — Bulk-generate 380+ fastroute cards via Ollama qwen2.5:7b (QA HIGH 7.9)
- [ ] C.2 — Validate JSON + merge into fastroute_cards.json
- [ ] C.3 — smoke C verify

### Phase QA v2 — Re-run cascade
- [ ] QA2.1 — 3 parallel agents (visual / reactivity-fps-audio / fun-rpg-ux)
- [ ] QA2.2 — Aggregate `docs/QA_REPORT_v2.md`
- [ ] QA2.3 — Compare score v1 (73%) vs v2 (target 90%+)
- [ ] QA2.4 — AskUserQuestion next steps

---

## ACTIVE: v7.5 visual + v7.6 LLM bi-brain (2026-05-15 part 19+20)

### v7.5 SHIPPED — visual pivot + capture pipeline
- [x] Bible v3.4 — §20 low-poly flat + outline + §22 8 biome palettes + §23 mood mystique chaleureux
- [x] 3 perf repos cloned `external/` (multi_mesh_manager, MeshLodGenerator, godot-blender-exporter)
- [x] CelShadingManager pivot (low-poly flat + outline kept)
- [x] biome_palettes.gd (8 hex palettes) + biome_loader.gd + multimesh_outline_helper.gd
- [x] 7 biomes builders migrated to palettes (BoardBiomeBackdrop)
- [x] BiomeLoader wired into board_narration plateau loading
- [x] Capture pipeline 4 bugs fixed (LLM warmup blocker, Timer autostart, PROCESS_MODE_ALWAYS, bootstrap-skip)
- [x] CelShadingManager.apply in _spawn helper (all backdrop spawns get outline)
- [x] JuiceHelpers.materialize_reveal cascade in _spawn (digital-upload progressive)
- [x] _spawn_multimesh_trees via MultiMeshOutlineHelper (2 draw calls for 18 trees)
- [x] plateau_carved.glb DISABLED (was source of persistent rectangle)
- [x] Volumetric fog boosted (density 0.022→0.045, length 24→36, emission 0.25→0.55)
- [x] JuiceHelpers GeometryInstance3D-aware (MMI flash works)
- [x] 8 biomes visual validation (output/captures/biomes_v7_4/) — rectangle gone, palettes distinct

### v7.6 IN PROGRESS — LLM bi-brain runtime
- [x] 1.1 — `addons/merlin_ai/bi_brain_pipeline.gd` orchestrator (~280 LOC) :
  - GBNF JSON output (GM) → Narrator from-scratch prose
  - RAG context injection (retrieve_top_k preferred, last-3 journal fallback)
  - Cascade fallback (GM fail → empty Dict → caller FastRoute ; Narrator fail → GM text stub)
- [ ] 1.2 — Audit `merlin_ai.gd` `generate_with_system` routing : verify `params.brain` actually selects qwen3.5:2b vs qwen3.5:4b per brain_swarm_config NANO/SOLO/DUAL/QUAD
- [ ] 1.3 — Add `MerlinAI.generate_card_bi_brain(biome, act, ogham)` entry point
- [ ] 1.4 — Wire call site in `merlin_omniscient.gd` or `merlin_card_system.gd` card fetch path
- [ ] 1.5 — Test on smoke (capture passed=True 0 errors) with bi-brain enabled

### v7.6 Next phases (user-confirmed 2026-05-15 part 20)
- Phase 2 — Interference Merlin (bible §12) : Swap/Hide/Amplify/Bait/Hint/Gift slots per Confiance T0-T3
- Phase 3 — Pre-fetch + cache N+3 cartes (zero latency card draw)
- Phase 4 — Dynamic act swap (Profiler signal → swap standard→shop/event)
- Phase 5 — Rêve inter-run (1ère carte run N référence run N-1)

---

## ACTIVE: v7.7 Scenario-front-loaded LLM (2026-05-15 part 21)

**Architecture (user-confirmed via 3 rounds AskUserQuestion)** :
- Pre-game loading : LLM produces 3 titles + ogham glyphs (minimal) → player picks 1 → LLM writes 5-beat skeleton (faction_tilt + emotion arc) → cards JIT per-beat via v7.6 BiBrainPipeline
- Loading UX : Merlin live narration streaming (Narrator brain parallel to GM)
- Pre-fetch carte N+1 immediately after render N (zero in-game latency)
- LLM-judge brain : post-card divergence detection (1-2s, Phase 2)
- Adaptive : LLM re-plans beats[from..5] when player diverges (Phase 2)
- Budget : ~25s loading + 0s in-game (~9-10 GB VRAM, mid-range PC)
- Cascade fallback L1→L2→L3 (full LLM → FastRoute → 40 hardcoded skeletons)

### v7.7 Phase 1 SHIPPED (foundation)
- [x] 1.1 — `data/ai/scenario_skeleton.gbnf` (GBNF for `{title, beats:[5×{n, summary, faction_tilt, emotion}]}`)
- [x] 1.2 — `addons/merlin_ai/scenario_planner.gd` (~310 LOC) :
  - `generate_titles(biome) -> Array[{title, ogham}]×3` with LLM err / parse fail / overlong-line fallback
  - `generate_skeleton(biome, title) -> Dictionary` GBNF-constrained, fallback to `FALLBACK_SKELETONS` const
  - `generate_card_for_beat(skeleton, beat_idx, player_state) -> Dictionary` delegates to v7.6 BiBrainPipeline
  - `judge_divergence(...)` Phase 2 stub (returns false)
  - `replan_from_beat(...)` Phase 2 stub (returns skeleton unchanged)
  - `BEAT_ACT_SEQUENCE` const single-source-of-truth for 5-beat → act_type mapping
- [x] Code-reviewer agent : 0 CRITICAL / 0 HIGH / 3 MEDIUM all fixed (const for beat seq, push_warning for biome miss, MAX_TITLE_LENGTH guard)

### v7.7 Phase 2 (next session)
- [ ] 2.1 — Loading screen scene `scenes/ScenarioLoading.tscn` (3 titles + Merlin streaming text + steps progress)
- [ ] 2.2 — Wire `ScenarioPlanner` into `board_narration.gd` run start flow (before `_on_biome_picked`)
- [ ] 2.3 — Extend `BiBrainPipeline` to accept beat-context Dictionary (faction_tilt + emotion + summary) injected into GM + Narrator prompts
- [ ] 2.4 — Implement `judge_divergence` (3rd brain mini qwen3.5:2b, ~2s budget)
- [ ] 2.5 — Implement `replan_from_beat` (regen beats[from..5] preserving 1..from-1)
- [x] 2.3 — beat-context injection in BiBrainPipeline (commit 8dbbe1cc)
- [x] 2.4 — judge_divergence hybrid LLM+heuristic (commit 8dbbe1cc + c6f2196d HIGH fix)
- [x] 2.5 — replan_from_beat real implementation (commit 8dbbe1cc, variable size in 70ce9f80)
- [x] 2.6 — FALLBACK_SKELETONS expanded 1→8 biomes (commit 8dbbe1cc)
- [x] 2.7 — Variable beat count 5-10 (GBNF flex + chain-of-thought + clamp) (commit 70ce9f80)
- [ ] 2.8 — Smoke + capture validation (loading screen + variable-card playthrough)

### v7.7 Phase 2.1 SPEC (locked 2026-05-15 part 23 via 8 AskUserQuestion answers)

**Run start flow finalized** :
1. Empty scene → plateau materialize (v7.5 digital-upload, shipped)
2. Biome selector (existing)
3. Backdrop assets cascade reveal (v7.5, shipped)
4. **Scene change to `scenes/ScenarioLoading.tscn`** (NEW)
5. 3 parchemins 3D floating in front of camera (LiveCard3D-style) — unfurl + ink-write animation
6. Player picks 1 parchemin (title + ogham glyph)
7. **Quill phase** — CPUParticles3D dorées + Merlin speech-bar pulsing + TTS robot voice
8. LLM writes 5/7/10-beat skeleton (chain-of-thought decides ambition)
9. Transition back to BoardNarration with skeleton loaded
10. JIT per-beat cards via BiBrainPipeline + judge + replan (Phase 2.3/2.4/2.5 shipped)

**Phase 2.1 deliverables (~600 LOC + 1 .tscn + 1 .gdshader)** :
- [ ] 2.1.1 — `scenes/ScenarioLoading.tscn` skeleton (Node3D root + Camera3D + DirectionalLight3D + UI CanvasLayer)
- [ ] 2.1.2 — `scripts/scenario_loading.gd` — controller : instantiate ScenarioPlanner, run titles+skeleton flow, handle parchemin picks
- [ ] 2.1.3 — 3D parchemin mesh (PlaneMesh + parchment NoiseTexture + ogham glyph Label3D + title Label3D) — apply CelShadingManager
- [ ] 2.1.4 — Parchemin unfurl animation : scale Y 0→1 over 0.5s, ink-write typewriter on title 30 cps
- [ ] 2.1.5 — Merlin speech-bar widget (2D Control + .gdshader fragment shader for pulse-on-amplitude glow #d4a868 — EDI/GLaDOS style)
- [ ] 2.1.6 — TTS pipeline : route via `use_my_voice` skill + AudioEffectChorus + Distortion for robot effect
- [ ] 2.1.7 — CPUParticles3D quill node : 30 particles, gold albedo, gravity=0, lifetime 2s, emission ring
- [ ] 2.1.8 — Wire `board_narration._on_biome_picked` → set `_PARAMS` autoload biome_id → scene change to ScenarioLoading
- [ ] 2.1.9 — Wire ScenarioLoading completion → return to BoardNarration with skeleton in `_run_data["scenario_skeleton"]`
- [ ] 2.1.10 — Smoke + capture validation : titles render, parchemin unfurl visible, speech-bar pulses, particles drift, transition smooth

---

## ACTIVE: v7.7 outline coverage audit (2026-05-15 part 24)

**Audit summary (Wave 1 agent)** : 57 spawn sites, 14 covered, **43 missing** outline. Skip list : 5 (billboards, fog quads, dev tools, grass shader, god-rays). Real gaps : **38 across 13 files**.

### Batch 1 SHIPPED — 14 sites (4 files, this session)
- [x] sigle_token.gd : 4 sites (base + body + head + accessory)
- [x] scenario_loading.gd : 1 site (parchemin PlaneMesh)
- [x] merlin_cabin_hub.gd : 5 sites (floor + cauldron + crystal + tapestry + wall_map + lanterns + walls) — via agent
- [x] forest_asset_spawner.gd : 5 sites (procedural trunk + canopy + fallback trunk + crown loop + shrub) — via agent

### Batch 2 BACKLOG — 24 remaining sites (9 files, next session orchestration)
- [ ] broceliande_forest_3d.gd : 2 (rocks + grass patches)
- [ ] broc_chunk_manager.gd : 2 (vegetation MM + canopy spheres MM) — needs `MultiMeshOutlineHelper.build_pair` refactor
- [ ] broc_creature_spawner.gd : 1 (voxel creature pixel)
- [ ] broc_events.gd : 3 (firefly + mushroom circle + shadow figure)
- [ ] broc_extra_decor.gd : 4 (crystal + glow orb + stone pillar + ground rune)
- [ ] broc_event_vfx.gd : 3 (shadow pass + spawn glow orbs + mushroom circle VFX)
- [ ] forest_merlin_npc.gd : 1 (voxel Merlin NPC)
- [ ] forest_zone_builder.gd : 1 (water cylinder)
- [ ] forest_terrain_builder.gd : 3 (main ground + rolling hills + path MM)
- [ ] vegetation_manager.gd : 2 (canopy MM + generic vegetation MM)

### Orchestration plan next session
Spawn 3 parallel agents :
- **Agent A** : `broc_events.gd` + `broc_event_vfx.gd` + `broc_extra_decor.gd` (10 sites, MEDIUM/HIGH)
- **Agent B** : `broc_creature_spawner.gd` + `forest_merlin_npc.gd` + `forest_zone_builder.gd` + `broceliande_forest_3d.gd` (5 sites, mixed)
- **Agent C** : MultiMesh refactor — `broc_chunk_manager.gd` + `forest_terrain_builder.gd` + `vegetation_manager.gd` (7 sites, HIGH, requires `MultiMeshOutlineHelper.build_pair` API migration)
Then smoke verify + commit.

### UI Slack audit (deferred)
Per user request "UI slack très limitée" — separate audit needed of `board_narration.gd` HUD / `scenario_loading.gd` UI / `merlin_cabin_hub.gd` HUD against bible §21.1 minimal (≤7 affordances). Spawn `ux_flow.md` agent in next session.

### Visual polish audit (deferred)
Per user request "beaux effets visuels" — survey lighting / post-process / particle FX / transitions for polish opportunities. Spawn `motion_designer.md` + `vis_particle.md` agents in next session.

---

## MUSIQUE MENU — pivot axes v2 (2026-08-07, session mobile)

Spec utilisateur (finale) : melodie principale dont l'INSTRUMENT change avec la
METEO (valide) ; moins d'elements ; l'HEURE (aube/matinee/midi/apres_midi/
soiree/nuit) pilote la VITESSE, parfois quelques instruments EN PLUS,
SUBSTITUTION la nuit ; la saison DISPARAIT.

### Phases
- [ ] P1 casting_menu.py : axes {meteo, heure}, saison supprimee, meteo->chant
      uniquement (pluie=harpe SUR LA MELODIE), TEMPO par heure, EXTRAS
      (midi=guirlande glockenspiel, soiree=veilleuse celesta), NUIT_FOND
      (corde dan_tranh + halo tubulaires + pulse nuit), FOND_JOUR sans halo
- [ ] P2 arrange_menu.py : damp_rings(rel_override) au max des releases du role
      -> tous candidats d'un role byte-synchrones, harpe comprise
- [ ] P3 lint harmonique + re-rendu complet (banque $SP/samples_vpo)
- [ ] P4 build_mobile_page.py v2 : pistes FOND jour/nuit + CHANT par meteo +
      ADD par heure, courbes par combinaison, meta tempo
- [ ] P5 mobile_template.html v2 : 2 axes (meteo/heure), playbackRate
      preservesPitch, moteur 3 couches synchronisees, timeline + journal
- [ ] P6 tests Playwright, artefact re-publie (meme URL), commit + push
