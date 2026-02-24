# Task Plan: M.E.R.L.I.N. — Le Jeu des Oghams

## Goal
Developper un JDR Parlant roguelite avec LLM local (Qwen 2.5-3B-Instruct Multi-Brain), systeme Triade (3 aspects x 3 etats), et narration procedurale.

## Current Phase
Phase P1 — Intelligence sans LoRA (Plan Bi-Cerveaux)

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
- [ ] P1.9.1 | visual_tags -> shaders/particles | merlin_game_ui.gd, merlin_visual.gd
- [ ] P1.9.2 | audio_tags -> SFXManager | SFXManager.gd

### WAVE 10: RAG v2.1 (after W6+W7+W8)
- [ ] P1.10.1 | RAG profil+arc+danger | rag_manager.gd
- [ ] P1.10.2 | Cross-run memory | rag_manager.gd

### WAVE 11: Integration P1
- [ ] P1.11.1 | Wire tous systemes MOS
- [ ] P1.11.2 | Validation P1

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
| B.1 | Souffle d'Ogham → Perk personnalisable | A FAIRE |
| B.2 | UI Arbre de Vie (page 4 Hub) | A FAIRE |
| B.3 | Archetype → bonus DC + contexte RAG | A FAIRE |
| B.4 | Aspects → impact narratif + bonus/malus | A FAIRE |
| B.5 | Premiere run direct (skip Hub) | A FAIRE |

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
