# Progress Log - M.E.R.L.I.N.: Le Jeu des Oghams

> **Note**: Sessions anterieures archivees dans `archive/progress_archive_2026-02-05_to_2026-02-08.md`

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

