# Run Flow 3D — Gap Analysis

> **Phase**: 6 (Run Flow 3D) — DEV_PLAN_V2.5
> **Date**: 2026-03-15
> **Source of truth**: `docs/GAME_DESIGN_BIBLE.md` v2.4, `docs/DEV_PLAN_V2.5.md`

---

## 1. Bible Spec Summary

### Core Loop (Bible s.1.3)

The run is **permanently in 3D**: the character auto-walks on a rail through the biome. Cards interrupt via crossfade.

```
Hub 2D -> Biome choice -> Ogham choice
   |
SCENE 3D: character advances on rail (on-rails)
   |
[5-15s] Collect biome currency, observe scenery, events
   |
[FADE] -> Card 2D displayed (text + 3 options)
   |
Player chooses ACTION VERB (always 3 options)
   |
MINIGAME overlay 2D on frozen 3D
   |
Score 0-100 -> Direct multiplier -> Effects applied
   |
[FADE] -> Return to 3D (character resumes walking)
   |
[Repeat] until narrative end or life = 0
   |
End -> Narrative fade -> Journey map -> Rewards screen -> Hub
```

### Effect Pipeline (Bible s.13.3 — 12 steps)

```
1. DRAIN -1 PV (at card start, before choice)
2. CARD DISPLAY
3. OGHAM activation (before choice, optional)
4. PLAYER CHOICE (option index)
5. MINIGAME (unless merlin_direct)
6. SCORE 0-100
7. APPLY EFFECTS (multiplied by score)
8. OGHAM PROTECTION (luis/gort/eadhadh filter negatives AFTER)
9. CHECK LIFE = 0 (after ALL effects)
10. CHECK PROMISES (countdown -1, expired -> resolution card)
11. COOLDOWN -1 on active ogham
12. RETURN TO 3D (fade, walk resumes)
```

### Run End Conditions (Bible s.5)

- **Life = 0**: after full effect application (step 9)
- **MOS convergence**: soft min 8, target 20-25, soft max 40, hard max 50
- **Faction end**: if faction rep >= 80 at end of run

### End-of-Run Flow (Bible s.5.3)

1. **Narrative fade** — screen dims, LLM-generated ending text
2. **Journey map** — stylized biome map with pins at key moments
3. **Rewards screen** — Anam earned, faction rep changes, run stats

### Ogham Timing (Bible s.2.2)

- Activation: only during card display (before choice)
- Switch: during 3D walk OR during card display (before choice)
- Cooldown: decrements by 1 per card played (only active ogham)

---

## 2. Current Implementation

### 2.1 Run3DController (`scripts/run/run_3d_controller.gd`)

**Status: EXISTS — 303 lines, structurally complete**

| Feature | Lines | Status |
|---------|-------|--------|
| `start_run(biome, ogham)` | 71-88 | Initializes run_state, starts spawner, emits initial signals |
| `stop_run(reason)` | 95-108 | Stops spawner, emits run_ended with data |
| `process_tick(delta)` | 115-132 | Walk timer, period updates, card trigger check |
| `_trigger_card()` | 135-167 | Drain -1, check run end, check promises, fade, generate card |
| `on_card_choice(option_index, score)` | 170-204 | Resolve card, apply effects, update promises, resume |
| `pause_for_card()` / `resume_after_card()` | 207-218 | Fade transitions, input lock |
| `_apply_effects(effects)` | 231-260 | HEAL_LIFE, DAMAGE_LIFE, ADD_REPUTATION, ADD_BIOME_CURRENCY |
| `on_collectible_picked(type, amount)` | 272-286 | currency, anam_rare, heal pickups |
| Signals contract (Phase 6->7) | 16-24 | All 8 signals defined |
| Card interval (8-14s) | 48-49 | Matches bible 5-15s range (close enough) |

### 2.2 TransitionManager (`scripts/run/transition_manager.gd`)

**Status: EXISTS — 133 lines, complete**

| Feature | Lines | Status |
|---------|-------|--------|
| `fade_to_card(duration)` | 52-53 | Implemented (fade out/in with tween) |
| `fade_to_3d(duration)` | 56-57 | Implemented |
| `fade_to_minigame(duration)` | 60-61 | Implemented |
| `disable_inputs()` / `enable_inputs()` | 64-79 | Implemented (mouse filter + signals) |
| ColorRect overlay | 37-45 | z_index 100, full rect, cubic ease |

### 2.3 CollectibleSpawner (`scripts/run/collectible_spawner.gd`)

**Status: EXISTS — 168 lines, complete**

| Feature | Lines | Status |
|---------|-------|--------|
| Currency spawn (3-5s interval) | 18-22 | 1-2 amount, 1.5s pickup window |
| Event types | 25-32 | plant, trap, rune, spirit, anam_rare |
| `try_pickup(player_position)` | 134-145 | Radius-based pickup |
| Expiry system | 148-155 | Lifetime countdown |

### 2.4 HudController (`scripts/ui/hud_controller.gd`)

**Status: EXISTS — 239 lines, Phase 7 but tied to Phase 6**

| Feature | Lines | Status |
|---------|-------|--------|
| `bind_to_run_controller()` | 44-52 | Connects all 8 Run3DController signals |
| `update_life/currency/ogham/promises/period` | 81-145 | All handlers implemented |
| Card overlay show/hide | 157-201 | Shows text + 3 option buttons |
| Ogham button (during card) | 192-194 | Visible during card, emits ogham_activated |
| Option button press | 209-216 | Disables buttons to prevent double-click |

### 2.5 BroceliandeForest3D (`scripts/broceliande_3d/broceliande_forest_3d.gd`)

**Status: EXISTS — extensive 3D scene system**

Sub-modules (all exist in `scripts/broceliande_3d/`):
- `broc_autowalk.gd` — auto-walk on rail
- `broc_chunk_manager.gd` — procedural terrain (MultiMesh chunks)
- `broc_atmosphere.gd` — volumetric fog
- `broc_day_night.gd` — day/night cycle
- `broc_season.gd` — seasonal tints
- `broc_creature_spawner.gd` — pixel-art creatures (4 types)
- `broc_events.gd` — 8 atmospheric event types
- `walk_event_controller.gd` — LLM-driven narrative walk events
- `broc_narrative_director.gd` — scene directives from LLM
- `broc_event_vfx.gd` — VFX keywords
- `broc_screen_vfx.gd` — fullscreen VFX (fade, blur)
- `biome_walk_config.gd` — biome resource config

Scene: `scenes/BroceliandeForest3D.tscn` exists.

### 2.6 MerlinCardSystem (`scripts/merlin/merlin_card_system.gd`)

**Status: EXISTS — 893 lines, Phase 5 complete**

Provides: `generate_card()`, `resolve_card()`, `detect_lexical_field()`, `select_minigame()`, `check_run_end()`, promise system, FastRoute fallback, Ogham narrative effects (nuin/huath/ioho).

### 2.7 MerlinStore (`scripts/merlin/merlin_store.gd`)

**Status: EXISTS — run actions defined**

| Action | Line | Status |
|--------|------|--------|
| `START_RUN` | 301-325 | Init run, set biome, notify MOS |
| `GET_CARD` | 327-351 | LLM via MOS or direct |
| `RESOLVE_CHOICE` | 353-373 | Resolve, check run end, notify MOS |
| `END_RUN` | 384-400 | Abandon handling, notify MOS |
| `USE_OGHAM` | 380-382 | Delegates to `_use_ogham()` |

### 2.8 MerlinMiniGameSystem (`scripts/merlin/merlin_minigame_system.gd`)

**Status: EXISTS** — minigame registry and system available.

### 2.9 Scene Flow (Bible s.5.1)

| Scene | File | Status |
|-------|------|--------|
| IntroCeltOS | `scenes/IntroCeltOS.tscn` | EXISTS |
| MenuPrincipal | `scenes/MenuPrincipal.tscn` | EXISTS |
| IntroPersonalityQuiz | `scenes/IntroPersonalityQuiz.tscn` | EXISTS |
| SceneRencontreMerlin | `scenes/SceneRencontreMerlin.tscn` | EXISTS |
| HubAntre | `scenes/HubAntre.tscn` | EXISTS |
| BroceliandeForest3D | `scenes/BroceliandeForest3D.tscn` | EXISTS |
| TransitionBiome | `scenes/TransitionBiome.tscn` | EXISTS |
| ArbreDeVie (talent tree) | `scenes/ArbreDeVie.tscn` | EXISTS |

---

## 3. Gap Matrix

### 3.1 Run Flow Core

| # | Feature | Bible Ref | Status | Notes |
|---|---------|-----------|--------|-------|
| 1 | 3D rail walking segment | s.1.3 | DONE | `BrocAutowalk` + `BroceliandeForest3D` with 7 zones, chunks, atmosphere, creatures |
| 2 | Walk->Card transition (5-15s collect + fade) | s.1.3 | DONE | `Run3DController._trigger_card()` (8-14s interval) + `TransitionManager.fade_to_card()` |
| 3 | Card presentation (3 options) | s.1.3 | DONE | `MerlinCardSystem.generate_card()` + `_ensure_3_options()` + `HudController._show_card_overlay()` |
| 4 | Minigame overlay on frozen 3D | s.1.3 | PARTIAL | `TransitionManager.fade_to_minigame()` exists but **no wiring** in `Run3DController.on_card_choice()` — it goes directly to `resolve_card()` without launching a minigame. The `MerlinMiniGameSystem` exists but is **not integrated** into the Run3D pipeline. |
| 5 | Score->Effect pipeline (resolve_card) | s.13.3 | DONE | `MerlinCardSystem.resolve_card()` applies multiplier, scales effects, caps. `Run3DController._apply_effects()` handles HEAL/DAMAGE/REP/CURRENCY. |
| 6 | Card->Walk transition (fade back) | s.1.3 | DONE | `Run3DController.resume_after_card()` calls `_transition.fade_to_3d()` then unpauses. |
| 7 | Run end conditions (life=0, all cards) | s.2.1, s.6.2 | DONE | `check_run_end()` covers death (life<=0), hard_max (50), and tension zones. `_apply_effects()` also checks life<=0 after DAMAGE_LIFE. |
| 8 | Run state management (START/END/PAUSE) | s.5 | DONE | `start_run()`, `stop_run()`, `_is_running`/`_is_paused` flags. `MerlinStore` has START_RUN/END_RUN/GET_CARD/RESOLVE_CHOICE. |
| 9 | Biome visual switching | s.4.1 | PARTIAL | `BiomeWalkConfig` resource exists but `BroceliandeForest3D` hardcodes Broceliande assets (TREE_MODELS, BUSH_MODELS, etc. at lines 34-100). No dynamic biome loading via config resource. Only 1 biome scene exists. |
| 10 | Ogham activation before choice | s.2.2 | PARTIAL | `HudController` shows ogham button during card (line 192-194) and emits `ogham_activated`. But `Run3DController` **does not handle** this signal — there is no wiring to apply ogham effects before the choice is made. The card system has `apply_ogham_narrative()` but it is **not called** from the run flow. |

### 3.2 Effect Pipeline Steps (Bible s.13.3)

| Step | Description | Status | Notes |
|------|-------------|--------|-------|
| 1 | DRAIN -1 PV | DONE | `Run3DController._trigger_card()` line 140 |
| 2 | CARD DISPLAY | DONE | `card_started.emit()` line 167 -> `HudController._on_card_started()` |
| 3 | OGHAM activation | MISSING | Ogham button emits signal but no handler in Run3DController. Protection/boost/reveal/narrative oghams not integrated in the run pipeline. |
| 4 | PLAYER CHOICE | DONE | `HudController.option_selected` -> `Run3DController.on_card_choice()` (wiring exists in HudController but **external scene must connect** HudController.option_selected to Run3DController.on_card_choice) |
| 5 | MINIGAME | MISSING | `on_card_choice()` receives a `score` parameter but **no minigame is actually launched**. The minigame overlay transition exists but is never called from the run flow. |
| 6 | SCORE | PARTIAL | Score is a parameter to `on_card_choice()` — works if externally provided, but no minigame generates it. |
| 7 | APPLY EFFECTS | DONE | `_apply_effects()` handles 4 effect types. |
| 8 | OGHAM PROTECTION | MISSING | luis/gort/eadhadh protection filtering is not implemented in `Run3DController._apply_effects()`. The effect engine has static methods but they are not called. |
| 9 | CHECK LIFE = 0 | DONE | Checked in `_apply_effects()` after DAMAGE_LIFE and in `_trigger_card()` before card. |
| 10 | PROMISE VERIFICATION | DONE | `_trigger_card()` calls `_card_system.check_promises()`, applies trust deltas. |
| 11 | COOLDOWN -1 | MISSING | No ogham cooldown decrement occurs after card resolution. The `ogham_updated` signal exists but is only emitted at `start_run()`. |
| 12 | RETURN TO 3D | DONE | `resume_after_card()` fades back and unpauses. |

### 3.3 End-of-Run Screens (Bible s.5.3)

| Screen | Status | Notes |
|--------|--------|-------|
| Narrative fade (LLM ending text) | MISSING | `run_ended` signal emits reason+data but no end screen displays narrative text. |
| Journey map (pins at key moments) | MISSING | No scene, no script, no data structure for journey map. |
| Rewards screen (Anam, factions, stats) | MISSING | No end-run rewards screen. `MerlinStore._handle_run_end()` exists but no UI. |

### 3.4 Collectibles & Walk Events

| Feature | Status | Notes |
|---------|--------|-------|
| Currency pickup during walk | DONE | `CollectibleSpawner` spawns currency 3-5s interval |
| Rare event pickups | DONE | plant/trap/rune/spirit/anam_rare |
| Walk events (LLM narrative) | DONE | `WalkEventController` with prefetch buffer, fallback chain |
| Atmospheric events | DONE | `BrocEvents` with 8 event types |
| Creature encounters | DONE | `BrocCreatureSpawner` with 4 types, zone-based |

### 3.5 Wiring & Integration

| Integration Point | Status | Notes |
|-------------------|--------|-------|
| BroceliandeForest3D -> Run3DController | UNKNOWN | DOC_3D_WALK describes the wiring (line 514: `_run_3d_controller.process_tick(delta)`), but need to verify actual scene wiring in `.tscn`. |
| HudController -> Run3DController | PARTIAL | `bind_to_run_controller()` connects signals READ direction. But WRITE direction (option_selected -> on_card_choice) requires external connection. |
| MiniGameSystem -> Run3DController | MISSING | No integration. Minigame is never launched during a run. |
| Ogham system -> Run3DController | MISSING | No integration. HudController emits ogham_activated but nothing handles it. |
| Run3DController -> MerlinStore | UNCLEAR | Run3DController uses its own _run_state dict and MerlinCardSystem directly. It does NOT dispatch through MerlinStore actions (START_RUN/GET_CARD/etc.). Two parallel paths exist. |

---

## 4. Priority Recommendations

### P0 — Critical (blocks playable loop)

1. **Minigame integration** — Wire `MerlinMiniGameSystem` into `Run3DController.on_card_choice()`. After player selects an option, launch the minigame (based on `option.minigame`), await score, then resolve. Currently the score parameter is unused/external.
   - Files: `scripts/run/run_3d_controller.gd`, `scripts/merlin/merlin_minigame_system.gd`

2. **Option selection wiring** — Ensure `HudController.option_selected` is connected to `Run3DController.on_card_choice()` in the scene tree. Currently `bind_to_run_controller()` only connects Run3D->HUD signals (read), not HUD->Run3D (write).
   - Files: `scripts/ui/hud_controller.gd`, scene that hosts both

### P1 — High (core mechanics incomplete)

3. **Ogham activation in run flow** — Handle `HudController.ogham_activated` signal in `Run3DController`. Apply reveal/boost/narrative/recovery/special effects before choice. Apply protection effects after effect resolution (step 8).
   - Files: `scripts/run/run_3d_controller.gd`

4. **Ogham cooldown decrement** — After each card resolution, decrement active ogham cooldown by 1. Emit `ogham_updated` signal.
   - Files: `scripts/run/run_3d_controller.gd` (add to `on_card_choice()`)

5. **End-of-run screens** — Create the 3-screen end flow: narrative fade, journey map, rewards.
   - New files needed: `scripts/ui/end_run_screen.gd`, scene `.tscn`
   - Data: journey map pins from `run_state.story_log`

### P2 — Medium (multi-biome support)

6. **Dynamic biome loading** — Refactor `BroceliandeForest3D` to load assets from `BiomeWalkConfig` resource instead of hardcoded constants. Enable 8 biomes.
   - Files: `scripts/broceliande_3d/broceliande_forest_3d.gd`, `scripts/broceliande_3d/biome_walk_config.gd`
   - Need: 7 additional `.tres` biome configs + GLB asset sets

7. **Dual run path reconciliation** — `Run3DController` manages its own `_run_state` while `MerlinStore` has START_RUN/GET_CARD/RESOLVE_CHOICE actions. These are two parallel paths. Decide: either Run3DController dispatches through MerlinStore, or Run3DController is the authority and MerlinStore is updated at run boundaries only.
   - Files: `scripts/run/run_3d_controller.gd`, `scripts/merlin/merlin_store.gd`

### P3 — Low (polish)

8. **Card interval tuning** — Current 8-14s; bible says 5-15s. Minor mismatch, adjust if needed.

9. **Ogham switch during walk** — Bible allows switching active ogham during 3D walk. No UI for this exists yet.

10. **Biome affinity bonus** — When active ogham is in biome's `oghams_affinity`: +10% minigame score, -1 cooldown. Not implemented in run flow.

---

## 5. Completion Assessment

| Category | Done | Total | % |
|----------|------|-------|---|
| Run flow core (matrix 3.1) | 7 | 10 | 70% |
| Effect pipeline steps (matrix 3.2) | 7 | 12 | 58% |
| End-of-run screens (matrix 3.3) | 0 | 3 | 0% |
| Collectibles & walk (matrix 3.4) | 5 | 5 | 100% |
| Wiring & integration (matrix 3.5) | 1 | 5 | 20% |

**Overall Phase 6 estimate: ~50%** — The structural code exists (controller, transitions, spawner, 3D scene) but the critical integration points (minigame launch, ogham activation, end screens, signal wiring) are missing.

---

*Generated: 2026-03-15*
