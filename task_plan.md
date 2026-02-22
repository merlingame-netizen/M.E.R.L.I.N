# Task Plan: M.E.R.L.I.N. — Le Jeu des Oghams

## Goal
Developper un JDR Parlant roguelite avec LLM local (Qwen 2.5-3B-Instruct Multi-Brain), systeme Triade (3 aspects x 3 etats), et narration procedurale.

## Current Phase
Phase 43 — Refonte Gameplay (Plan consolide Phase 42 walkthrough)

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
