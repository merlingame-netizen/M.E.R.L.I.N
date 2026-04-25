# Task Plan: M.E.R.L.I.N. — Le Jeu des Oghams

## Goal
Developper un JDR Parlant roguelite avec LLM local (Qwen 3.5 Multi-Brain heterogene), systeme Triade (3 aspects x 3 etats), et narration procedurale.

---

## Phase Active: 2026-04-25 (suite) — LLM Mobile Architecture (Cycle 1 Polish Pass)

### Context
User direction explicite :
- **Plateforme** : Android + iOS ensemble (cross-platform mobile dès le départ)
- **Stratégie LLM** : llama.cpp embedded recompilé (option B llm_expert) avec MODÈLES NOUVEAUX et architecture tier-aware adressant les limites hardware
- **Pas d'Ollama mobile** : tout-on-device via GDExtension recompilée ARM
- **Multi-instance** : Desktop seulement, mobile = SINGLE strict (batterie/RAM/thermal)

### Findings critiques (audits Wave 1)
- `generate_parallel()` jamais appelé en gameplay (potentiel mort)
- LoRA `merlin-narrator-lora-q4` jamais référencé dans PROFILES
- `qwen3.5:0.8b` référencé mais non installé (fallback silencieux)
- `merlin_llm.gdextension` Windows-only (ARM à compiler)
- `native/llama.cpp/CMakeLists.txt` supporte déjà iOS/Android/Metal/Vulkan/OpenCL
- Pattern multi-instance validé : `WorkerThreadPool` + signals + isolated `MerlinLLM` instances

### Phases Cycle 1
- **Phase 1.1 (10 min)** : Refactor `BrainSwarmConfig` — ajout `Profile.MOBILE_LOW/MID/HIGH` avec modèles ARM-friendly
- **Phase 1.2 (TDD)** : Test `test_brain_swarm_config_mobile.gd` — vérifie profiles mobile + detect_profile mobile-aware
- **Phase 1.3 (30 min)** : `MultiBrainOrchestrator` GDScript desktop autonome (squelette llm_expert)
- **Phase 1.4 (1-2 jours)** : Cross-compilation `merlin_llm.gdextension` Android arm64 + iOS arm64 (NDK + Xcode)
- **Phase 1.5 (validation)** : Test runtime export Android local
- **Phase 1.6 (audio P2)** : Brancher `generate_parallel` dans MOS pour overlap narrator(N+1) ‖ GM(N)

### TDD pour Phase 1.1
RED : `test_brain_swarm_config_mobile.gd` vérifie :
- `Profile.MOBILE_LOW`, `MOBILE_MID`, `MOBILE_HIGH` existent
- Profile MOBILE_LOW : 1 brain, RAM ~700MB, n_ctx 1024, model tag arm64-friendly
- Profile MOBILE_MID : 1 brain, RAM ~1400MB, n_ctx 2048
- Profile MOBILE_HIGH : 1 brain, RAM ~2500MB, n_ctx 2048
- `detect_profile_mobile(ram, threads)` choisit entre LOW/MID/HIGH

GREEN : ajouter au `PROFILES` dict + nouvelle fonction `detect_profile_mobile()`.

---

## Phase Active: 2026-04-25 — Rail On-Rails Forest Walker (v3 visual)

### Context
Pivot du free-roam BKForestTestRoom (WASD + mouse look) vers un **rail on-rails** conforme bible v2.4 et vision graphique v3.
- Le user a rejete les BoxMesh primitifs (use real .glb assets BK already generated, 230+ files in Assets/)
- Le user precise: chemin predetermine, walker auto, head bob actif, evenements cartes spawn auto

### Architecture cible (native-first)
- **Path3D** : courbure douce dessinee, 4-6 points de control, sentier zigzag through la foret
- **PathFollow3D** : auto-walker driven by AnimationPlayer (no per-frame movement code)
- **Camera3D** (POV, FOV 60°, eye_height 1.5m) child of PathFollow3D
- **AnimationPlayer** : tween progress_ratio 0→1 sur ~90s (auto-walk)
- **rail_walker.gd** : MINIMAL script (head bob via _process + Tween, card-trigger callbacks)
- **Area3D triggers** : 5-10 places fixes le long du chemin pour spawn cards
- **Forest** : 12 categories d'assets BK (trees, bushes, ground, mushrooms, deadwood, rocks, megaliths, structures, collectibles, ...) places autour du chemin via bk_forest_test_room.gd recycled

### Etat
- [x] Vision v3 cristallisee + memoire mise a jour
- [x] Polices telechargees (Uncial Antiqua + VT323 + PressStart2P)
- [x] 8 cartes LLM commitees (d9be7351)
- [x] BKForestTestRoom.tscn restaure (git checkout, BoxMesh primitifs supprimes)
- [x] rail_walker.gd cree (~50 lignes, head bob + triggers)
- [ ] BKForestRail.tscn cree (Path3D + PathFollow3D + Camera + AnimationPlayer + Forest)
- [ ] AnimationPlayer "auto_walk" (progress_ratio 0→1, 90s)
- [ ] 5 Area3D triggers le long du Path3D
- [ ] Forest assembly (assets BK trees + mushrooms + megaliths + ...)
- [ ] Code review rail_walker.gd (agent code-reviewer)
- [ ] Test runtime + screenshot validation
- [ ] Commit + push

### Blockers
- MCP server godot-mcp down (port 9080 ferme apres runtime exit) — necessite reconnect manuel ou redemarrage editeur
- Volumetric fog ignore en Compatibility renderer — fog standard plus dense en compensation

### Findings critiques playtester (cycle 1)
- P0: drain de vie LIFE_ESSENCE_DRAIN_PER_CARD=0 → INTENTIONNEL (run = scenario LLM 15-25 cartes)
- P1: 3 bugs minigames web-demo (mg_regard score plafonne 20/100, mg_fouille setTimeout orphelin, mg_equilibre listeners doc leakent)
- P2: faction imbalance druides 27.6% vs niamh 13%, difficultyTier non consomme, audio in-play absent 12/14 minigames

### Findings card-generator
- merlin-narrator-lora-q4 utilise (~11.7s/narration) — qwen3.5:4b/2b TIMEOUT >120s sur CPU
- LoRA UTF-8 casse sur JSON structure → agent finalise les JSON manuellement
- 8/8 cartes valides, 8 biomes couverts, validation rigoureuse

---

## Current Phase
Phase N64 — Asset Generation Pipeline (2000+ low-poly .glb via Blender headless)

---

## Phase V1 — Adaptation Web Demo → Godot (DA N64 Sombre)

> Reference: `~/Downloads/Imgae_Exemple_Menu.jpg`
> Source: `web-demo/src/scenes/` (Three.js) → `scripts/menu_3d_pc.gd` (Godot)

### V1.1: Palette & Environment (Menu3DPC) ✅
- [x] Camera fixe 3/4 (plus d'orbite) — angle reference image
- [x] Environnement sombre: ciel couvert gris, brume epaisse
- [x] Sun/lighting: baisser energie, supprimer soleil visible (overcast)
- [x] Fog: plus dense, couleur sombre

### V1.2: Ocean & Terrain ✅
- [x] Ocean: darker teal, garder foam mais griser
- [x] Cliff: repositionner pour montrer le chemin
- [x] Ajouter chemin de terre/pierre le long de la falaise (7 segments + 20 pierres bord)

### V1.3: Nuages N64 & Vegetation ✅
- [x] Nuages: BoxMesh opaques gris fonce (20 blocs, 4 couleurs)
- [x] Vegetation: assombrir tous les verts (grass, bushes, tufts, edge)
- [x] Pierres/menhirs: tons plus sombres

### V1.4: Cables Neon Celtiques ✅
- [x] Cables lumineux vert phosphore connectant 6 menhirs (5 cables, 12 segments chacun)
- [x] Spheres emissives aux noeuds de connexion + point lights
- [x] Style fibre optique catenary droop
- [ ] Pulsation animee (a ajouter dans _process — phase suivante)

### V1.5: Polish & Coherence ✅
- [x] Reduire pierres flottantes (15→6)
- [x] Rune ring: plus subtil (alpha 0.35, couleur atenuee)
- [x] Particules: ajuster couleurs au mood sombre (magic, crystal, smoke)
- [x] Iles distantes: silhouettes plus sombres
- [ ] Camera transition "Nouvelle Partie": a adapter (phase suivante)

---

## Previous Phase
Phase P3 — Architecture Multi-Cerveaux Qwen 3.5 (heterogene)

---

## Phase P3 — Qwen 3.5 Multi-Brain Architecture

### P3.1 Foundation (Code refactor) — COMPLETE
- [x] P3.1.1 | Refactor `ollama_backend.gd`: model per instance, thinking mode, `<think>` stripping
- [x] P3.1.2 | Rewrite `brain_swarm_config.gd`: NANO/SINGLE/SINGLE+/DUAL/TRIPLE/QUAD profiles, heterogeneous RAM
- [x] P3.1.3 | Refactor `merlin_ai.gd`: model registry, heterogeneous init, SINGLE+ time-sharing, `_swap_model_for_role()`
- [x] P3.1.4 | Update `prompt_templates.json`: add `model` and `thinking` fields per template (v3.0)
- [x] P3.1.5 | Update `rag_manager.gd`: per-brain context budget (narrator=800, gm=400, judge/worker=200)
- [x] P3.1.6 | Validation: `validate.bat` Step 0 passed (0 errors, 0 warnings)
- [x] P3.1.7 | Pull Qwen 3.5 2B (Q8_0, 2.7 GB). 4B/0.8B deferred to P3.2 (need LoRA first)
- [x] P3.1.8 | Smoke test: Qwen 3.5 2B via Ollama API — works. Findings:
  - Qwen 3.5 emits `<think></think>` by default (even without thinking_mode) — fixed stripping to always run
  - Cold start: ~57s (model load from disk). Warm: 5-7s for 30-40 tokens (~5.5 tok/s CPU)
  - CRITICAL: Ollama defaults to 262K context (8.3 GB RAM!) — must always send explicit `num_ctx`
  - Poetic French quality decent from base 2B — LoRA will improve further

### P3.2 LoRA Per-Brain — PLANNED
- [ ] P3.2.1 | Update `train_narrator_lora.py` for Qwen 3.5-4B base
- [ ] P3.2.2 | Create GM training dataset (effects JSON)
- [ ] P3.2.3 | New `train_gm_lora.py` for Qwen 3.5-2B
- [ ] P3.2.4 | Create Ollama Modelfiles with embedded adapters
- [ ] P3.2.5 | Benchmark: with/without LoRA quality metrics

### P3.3 Thinking + Judge — PLANNED
- [ ] P3.3.1 | Test thinking mode with GM effects
- [ ] P3.3.2 | Implement LLM Quality Judge (0.8B brain, QUAD+ tier)
- [ ] P3.3.3 | Train Judge LoRA
- [ ] P3.3.4 | A/B test: heuristic vs LLM judge

### P3.4 Advanced — PLANNED
- [ ] P3.4.1 | Tool calling natif pour GM (Qwen 3.5 function schemas)
- [ ] P3.4.2 | Multimodal support (Vision Worker, experimental)

## Phase P0 — Fix Gameplay — COMPLETE (commit `0bd08f6`, 2026-02-24)
- [x] P0.0.1 Audit async flow timestamps
- [x] P0.1.1-P0.1.3 Fix timing (async, show_thinking, await start_run)
- [x] P0.2.1-P0.2.3 Fix labels (blocklist, validate_verb, regex)
- [x] P0.3.1-P0.3.3 Tune quality (seuils, poids, guardrails)
- [x] P0.4.1 E2E validation (3 cartes LLM native, 0% fallback)

---

## Phase P1 — Intelligence sans LoRA (~22h)

### WAVE 5: Sequential Pipeline
- [x] P1.5.1 | Contrat pipeline + templates | prompt_templates.json (sequential_card_full, gm_effects, consequences)
- [x] P1.5.2 | generate_sequential() | merlin_ai.gd
- [x] P1.5.3 | Strategy SEQ dans MOS | merlin_omniscient.gd

### WAVE 6: Player Profiling (parallele avec 7+8)
- [x] P1.6.1 | Calcul profil 6 axes + seed_from_quiz | player_profile_registry.gd
- [x] P1.6.2 | Wire dans choix | merlin_game_controller.gd
- [x] P1.6.3 | Injecter dans prompts (summary compact) | context_builder.gd

### WAVE 7: Narrative Arc (parallele avec 6+8)
- [x] P1.7.1 | FSM ArcPhase enum + run_phase auto-progress | narrative_registry.gd
- [x] P1.7.2 | Wire arc dans prompts + RAG fix | merlin_omniscient.gd, rag_manager.gd
- [x] P1.7.3 | Temperature + events par phase | merlin_omniscient.gd

### WAVE 8: Danger Detection (parallele avec 6+7)
- [x] P1.8.1 | 5 regles danger pre-LLM + life in prompt | merlin_omniscient.gd
- [x] P1.8.2 | Templates danger | scenario_prompts.json

### WAVE 9: Tags (after W5)
- [x] P1.9.1 | visual_tags -> card ambient FX (tints, pulse) | merlin_game_ui.gd
- [x] P1.9.2 | audio_tags -> SFXManager (tag-to-sound mapping) | merlin_game_ui.gd

### WAVE 10: RAG v2.1 (after W6+W7+W8)
- [x] P1.10.1 | RAG profil+arc+danger (3 new context sections) | rag_manager.gd, merlin_omniscient.gd
- [x] P1.10.2 | Cross-run memory (enhanced archive + reset_for_new_run) | rag_manager.gd, merlin_omniscient.gd

### WAVE 11: Integration P1
- [x] P1.11.1 | Wire tous systemes MOS (run_start/end, sync, tags)
- [x] P1.11.2 | Validation P1 (5/6 systemes wired, visual/audio tags design-only)

---

## Phase P2 — LoRA Training (~15h)

### WAVE 12: Data Prep
- [x] P2.12.1 | Export game logs + Tier 5 generators (sequential, danger, arcs, gm_effects) | generate_full_dataset_v7.py
- [x] P2.12.2 | 200+ gold x 5 competences → v8 dataset (724 samples, 455 gold) | merlin_full_v8.jsonl
- [x] P2.12.3 | Augmentation x3 (6 strategies, built-in pipeline) | generate_full_dataset_v7.py

### WAVE 13: Config
- [x] P2.13.1 | QLoRA config (v8 dataset auto-detect, r=16 alpha=32) | train_qwen_cpu.py
- [x] P2.13.2 | Benchmark script (5 P1 competences: sequential, danger, arcs, GM JSON, celtic) | benchmark_lora.py

### WAVE 14: Training
- [x] P2.14.1a | QLoRA CPU v1 — 21.5h, 3 epochs, 724 samples, checkpoint-225 | **FAILED: 95% truncated**
- [x] P2.14.1b | Root cause: max_seq_len=384 truncates 95% of samples (sys=353 tokens)
- [x] P2.14.1c | Dataset v9: 752 samples, shorter sys prompts, 0% truncated at 512
- [ ] P2.14.1d | QLoRA CPU v2 — 1 epoch, 85 steps, max_seq=512, 4 LoRA targets | **IN PROGRESS**
- [ ] P2.14.2 | Merge LoRA → GGUF | post_training_v2.ps1
- [ ] P2.14.3 | Deploy Ollama (merlin-narrator) | post_training_v2.ps1

### WAVE 15: GO/NO-GO
- [x] P2.15.0 | Eval v1: Format 0%, French 83%, Celtic 0.3, GM JSON 0% | **NO-GO → v2 needed**
- [ ] P2.15.1 | Benchmark v2 (merlin-narrator vs qwen2.5:1.5b base)
- [ ] P2.15.2 | Decision GO/NO-GO (Format >70%, French >90%, Tu >60%)
- [ ] P2.15.3 | Wire adapter in merlin_omniscient.gd si GO

---

## Phase P3 — Features Avancees (~25h) — COMPLETE (2026-02-24)

### WAVE 16: Dialogue Merlin
- [x] P3.16.1 | UI dialogue 3 presets + libre + journal | merlin_game_ui.gd
- [x] P3.16.2 | Generation reponse LLM | merlin_omniscient.gd
- [x] P3.16.3 | Impact game state + is_processing guard | merlin_game_controller.gd

### WAVE 17: Titres + What-If
- [x] P3.17.1 | Titres poetiques GM brain | merlin_omniscient.gd
- [x] P3.17.2 | Affichage titre UI (CAPTION_LARGE) | merlin_game_ui.gd
- [x] P3.17.3 | What-if choix non-pris generation | merlin_omniscient.gd
- [x] P3.17.4 | UI reveal post-choix staggered fade | merlin_game_ui.gd

### WAVE 18: Reves
- [x] P3.18.1 | Generation reves 80 tok T=0.9 | merlin_omniscient.gd
- [x] P3.18.2 | Dream overlay (CRT_PALETTE colors) | merlin_game_ui.gd
- [x] P3.18.3 | Trigger inter-biome | merlin_game_controller.gd

### WAVE 19: Tutoriel Narratif
- [x] P3.19.1 | Triggers 7 mecaniques | merlin_game_controller.gd
- [x] P3.19.2 | Textes tutoriel | tutorial_narratives.json
- [x] P3.19.3 | Integration diegetique via MerlinBubble | merlin_game_controller.gd

### WAVE 20: Cross-Run Memory
- [x] P3.20.1 | Summariser runs (past lives for prompt) | rag_manager.gd
- [x] P3.20.2 | Merlin reference vies dans narrator prompt | merlin_omniscient.gd
- [x] P3.20.3 | Journal visuel popup | merlin_game_ui.gd

### WAVE 21: Integration P3
- [x] P3.21.1 | E2E code review + 4 HIGH fixes (null safety, tree guard, journal wire, is_processing)
- [x] P3.21.2 | UI/UX Bible conformity (5 colors, font sizes, button themes, touch targets)
- [x] P3.21.3 | Validation + commit | `24cd876`

---

## Phase 43: Refonte Gameplay — Phase A (Fondations)

### Plan consolide: `.claude/plans/playful-yawning-tarjan.md`

### A.1: Supprimer game over par aspects + 12 chutes + Legacy/Reigns — FAIT
- [x] merlin_constants.gd: Supprimer Legacy (L1-46) + Reigns (L47-69) + TRIADE_ENDINGS
- [x] merlin_constants.gd: Supprimer SOUFFLE_CENTER_COST, SOUFFLE_EMPTY_RISK
- [x] merlin_constants.gd: Centre gratuit dans TRIADE_OPTION_INFO (cost=0)
- [x] merlin_store.gd: Retirer game over 2 extremes dans _check_triade_run_end() → vie=0
- [x] merlin_store.gd: Supprimer bestiole.needs (Tamagotchi) dans build_default_state()
- [x] merlin_store.gd: Supprimer _handle_bestiole_care() → _damage_life()/_heal_life()
- [x] merlin_store.gd: Supprimer legacy resources + actions REIGNS/LEGACY
- [x] merlin_store.gd: Supprimer _get_triade_ending() + _handle_run_end()
- [x] triade_game_controller.gd: Centre gratuit dans _modulate_effects()
- [x] Collection.gd: Retirer references TRIADE_ENDINGS
- [x] merlin_effect_engine.gd: Inline Reigns gauge defaults
- [x] merlin_llm_adapter.gd: Inline Reigns gauge thresholds

### A.2: Systeme essences de vie (jauge HP) — FAIT
- [x] merlin_constants.gd: LIFE_ESSENCE_MAX/START/damages/heals/threshold
- [x] merlin_store.gd: life_essence dans run state + _init_triade_run()
- [x] merlin_store.gd: _check_triade_run_end() — vie=0 = "Essences Epuisees"
- [x] merlin_store.gd: _damage_life(), _heal_life(), get_life_essence()
- [x] merlin_store.gd: Actions TRIADE_DAMAGE_LIFE, TRIADE_HEAL_LIFE
- [x] merlin_effect_engine.gd: DAMAGE_LIFE, HEAL_LIFE dans VALID_CODES + _apply_life_delta()
- [x] triade_game_controller.gd: Degats vie crit_failure, heal crit_success
- [x] triade_game_controller.gd: Connect life_changed signal + _on_life_changed()
- [x] triade_game_ui.gd: update_life_essence() + life_panel/counter/bar variables

### A.3: Centre gratuit + DC variable hybride — FAIT
- [x] triade_game_controller.gd: DC variable (DC_BASE ranges + ASPECT_DC_MODIFIER)
- [x] merlin_constants.gd: DC_BASE, ASPECT_DC_MODIFIER, DC_DIFFICULTY_LABELS
- [x] triade_game_controller.gd: Suppression DC_LEFT/DC_CENTER/DC_RIGHT fixes

### A.4: Missions hybrides (template + LLM) — FAIT
- [x] merlin_constants.gd: MISSION_TEMPLATES (4 types: survive/equilibre/explore/artefact)
- [x] merlin_store.gd: _generate_mission() weighted random
- [x] triade_game_controller.gd: _auto_progress_mission() par type de mission

### A.5: Ecran de resultats de run — FAIT
- [x] triade_game_ui.gd: Enrichi show_end_screen() avec life_depleted indicator
- [x] triade_game_ui.gd: update_life_essence() avec couleurs/animation low-life

---

## Migration Scene-Based Design — COMPLETE (2026-02-17)

Plan: `.claude/plans/majestic-sprouting-pond.md`

| Phase | Cible | Lignes | Status |
|-------|-------|--------|--------|
| 1 | Theme System (fondation) | ~-100 | FAIT |
| 2 | TriadeGameUI extraction | -408 | FAIT |
| 3 | HubAntre extraction | ~-300 | FAIT |
| 4 | MenuPrincipalMerlin extraction | -94 | FAIT |
| 5 | Scenes secondaires (4 scenes) | -432 | FAIT |

**Total: ~1334 lignes supprimees, ratio scene/script 5% → 60%**

### Bug pre-existant: gui_embed_subviewports — CORRIGE
- `pixel_content_animator.gd:386` utilisait `svp.gui_embed_subviewports = false` (propriete Window, pas SubViewport)
- Fix: remplace par `svp.gui_disable_input = true` (propriete Viewport valide)
- **18/18 scenes PASS en headless** apres correction

---

## Backlog

### Phase B — Progression
| # | Item | Statut |
|---|------|--------|
| B.1 | Souffle d'Ogham → Perk personnalisable | FAIT (2026-02-25) |
| B.2 | UI Arbre de Vie (page 4 Hub) | FAIT (HubAntre hotspot + scene deja impl.) |
| B.3 | Archetype → bonus DC + contexte RAG | FAIT (2026-02-25) |
| B.4 | Aspects → impact narratif + bonus/malus | FAIT (2026-02-25) |
| B.5 | Premiere run direct (skip Hub) | FAIT (2026-02-25) |

### Phase E — SFX + UX TransitionBiome
| # | Item | Statut |
|---|------|--------|
| E.1 | SFX Rework v1 — 9 sons manquants + UX contextuel Hub/Transition | FAIT (2026-02-25, commit `4415047`) |
| E.2 | SFX Rework v2 — Waveforms pixel/celtique, D Dorian, 12 generators | FAIT (2026-02-25, commit `4592ebc`) |
| T.1 | TransitionBiome Phase 1 — Scout pixels biome-colorés | FAIT (deja impl.) |
| T.2 | TransitionBiome Phase 1 — Sons ambiants par biome (7 generators) | FAIT (deja impl.) |
| T.3 | TransitionBiome Phase 3 — Titre biome-teinté (pulse scale) | FAIT (2026-02-27, `e82b9d7`) |
| T.4 | TransitionBiome Phase 6 — Dissolution SFX burst (biome_dissolve) | FAIT (2026-02-27, `e82b9d7`) |

### Phase C — Bestiole & Structure
| # | Item | Statut |
|---|------|--------|
| C.1 | Refonte Bestiole (option remplacement, runes, sauveur) | A FAIRE |
| C.2 | Structure semi-lineaire (carte noeuds) | A FAIRE |
| C.3 | Consequences long terme inter-runs | A FAIRE |
| C.4 | Refonte calendrier UI | A FAIRE |

### Phase D — Polish
| # | Item | Statut |
|---|------|--------|
| D.1 | Effets saisonniers menu | A FAIRE |
| D.2 | Art Kingdom Two Crowns (portraits) | A FAIRE |
| D.3 | Nettoyage code legacy restant | A FAIRE |
| D.4 | Equilibrage global | A FAIRE |
| D.5 | ~~Fix gui_embed_subviewports~~ | FAIT |

*Updated: 2026-02-27 — P1.11.2 VALIDE, T.1-T.4 FAIT, Perks wired, trust_merlin live, 10 studio agents*

---

## Phase MC-V3 — Mission Control Cockpit + Pipeline Reset (2026-04-15)

> Source plan: `~/.claude/plans/elegant-yawning-tarjan.md`
> Out-of-game tooling. No `.gd`/`.tscn` impacted.

### MC-V3.1: Cockpit shell — DONE
- [x] `useResizable.ts` hook (drag + localStorage persist)
- [x] `cockpit/TopBar.tsx` (KPI 1-liner)
- [x] `cockpit/GameStage.tsx` (resizable iframe wrapper)
- [x] `cockpit/Timeline.tsx` (NEXT/RUNNING/DONE feed)
- [x] `cockpit/Drawer.tsx` (bottom sheet, 4 mini-tabs)
- [x] `App.tsx` rewrite (no tabs, cockpit shell)
- [x] `cockpit.css` styles
- [x] Delete `views/`, `TabNavigation.tsx`, `views.css`
- [x] Build green (451 modules, 5.82s)

### MC-V3.2: Pipeline reset — IN PROGRESS
- [x] Create `tools/autodev/scripts/dedupe_completed.py`
- [ ] Run dedupe → log removed count
- [ ] Add dedupe guard in `studio-bridge/src/orchestrator.ts` (push to archive)
- [ ] Reopen `S2-ARC-CONDITION-EVAL` in `feature_queue.json` with verifier note
- [ ] Reinforce task-verifier (require call-site grep, not just definition)
- [ ] Purge `SPLIT-*` / `REDUCE-MEGAFUNC-*` priority >= 30 from queue
- [ ] Generate 5-10 gameplay tasks (oghams, minigames, FastRoute, factions, SFX)
- [ ] Add 10% meta-task cap to `studio-bridge/prompts/cycle_instructions.md`

### MC-V3.3: Deploy
- [ ] `npm run build` + `npx vercel --prod --yes`
- [ ] Acceptance criteria from approved plan (4.5)

### MC-V3.4: Stitch handoff — BLOCKED
- Waits on user `project_id` + `screen_id` from https://stitch.withgoogle.com
