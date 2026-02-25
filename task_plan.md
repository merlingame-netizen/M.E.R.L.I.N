# Task Plan: M.E.R.L.I.N. — Le Jeu des Oghams

## Goal
Developper un JDR Parlant roguelite avec LLM local (Qwen 2.5-3B-Instruct Multi-Brain), systeme Triade (3 aspects x 3 etats), et narration procedurale.

## Current Phase
Phase P2 — LoRA Training (Plan Bi-Cerveaux)

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
- [ ] P1.11.2 | Validation P1

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
- [ ] P2.14.1 | QLoRA CPU ~8-12h (3 epochs, 724 samples)
- [ ] P2.14.2 | Convert GGUF
- [ ] P2.14.3 | Deploy Ollama

### WAVE 15: GO/NO-GO
- [ ] P2.15.1 | Benchmark 5 competences
- [ ] P2.15.2 | Decision GO/NO-GO (Format >95%, Coherence 4+/5, Latency <+15%, French >90%)
- [ ] P2.15.3 | Wire adapter si GO

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
| B.4 | Aspects → impact narratif + bonus/malus | A FAIRE |
| B.5 | Premiere run direct (skip Hub) | FAIT (2026-02-25) |

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

*Updated: 2026-02-17 — Migration Scene-Based COMPLETE, Phase 43A+Migration done*
