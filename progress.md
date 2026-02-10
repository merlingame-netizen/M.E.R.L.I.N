# Progress Log - M.E.R.L.I.N.: Le Jeu des Oghams

> **Note**: Sessions anterieures archivees dans `archive/progress_archive_2026-02-05_to_2026-02-08.md`

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

