# QA AUDIT SUMMARY — Menu3DPC Refactor

**Status**: BLOCKED — 3 Critical Missing Scenes
**Date**: 2026-03-28
**Auditor**: QA Lead

---

## TL;DR

The Menu3DPC refactor is **code-complete and boots perfectly**. Boot sequence, button wiring, audio, and animations all work. **BUT** the game cannot proceed past Merlin's dialogue because **3 critical scenes have not been created**:

1. `HubAntre.tscn` — needed when player chooses Hub or completes tutorial
2. `TransitionBiome.tscn` — needed when player chooses "Direct Adventure"
3. `IntroTutorial.tscn` — needed for first-time players

Trying to proceed will crash with "Scene not found" errors.

---

## What Works ✓

**Menu3DPC Initialization**:
- Boot sequence (7 lines of green terminal text, 5.5s total) ✓
- 3D world (low-poly cliff, animated ocean, floating stones) ✓
- UI buttons fade in with smooth tweens ✓
- Hover/click sounds play correctly ✓
- Glitch effects render (rare screen distortion) ✓

**Button Transitions**:
- "Nouvelle Partie" → SceneRencontreMerlin ✓ (scene exists)
- "Continuer" → BroceliandeForest3D ✓ (scene exists)
- "Options" → no-op (acceptable stub) ✓

**Code Quality**:
- 914 lines of well-organized GDScript ✓
- Proper type hints throughout ✓
- Tweens and autoload guards correctly implemented ✓
- No parse errors or warnings ✓

---

## What's Broken ✗

**SceneRencontreMerlin Exit Paths**:
After Merlin's 3-part intro (greeting + ogham reveal + mission briefing), the scene tries to transition to one of 3 places based on player choice:

1. **Destination = "Hub"** → tries to load `res://scenes/HubAntre.tscn`
   - File does NOT exist → **CRASH**

2. **Destination = "Direct Adventure"** → tries to load `res://scenes/TransitionBiome.tscn`
   - File does NOT exist → **CRASH**

3. **Destination = "Tutorial"** (first-time players) → tries to load `res://scenes/IntroTutorial.tscn`
   - File does NOT exist → **CRASH**

**Forest Walk Return Path**:
If player uses "Continuer" button → BroceliandeForest3D, and the forest walk returns to Hub → tries to load `HubAntre.tscn`
- File does NOT exist → **CRASH**

---

## Scene Inventory

**Scenes that exist** (8 files):
```
✓ Menu3DPC.tscn (181B) — main menu
✓ SceneRencontreMerlin.tscn (2.7K) — Merlin intro dialogue
✓ BroceliandeForest3D.tscn (3.2K) — forest walk
✓ MerlinGame.tscn (401B) — gameplay loop
✓ LLMWarmupOverlay.tscn (1.1K) — loading overlay
✓ MerlinGameUI.tscn (8.7K) — game UI
✓ MenuReturnButton.tscn (284B) — UI component
✓ TestCardLayers.tscn (300B) — test scene
```

**Scenes that are MISSING but REFERENCED** (3 files):
```
✗ HubAntre.tscn — referenced in 2 scripts
✗ TransitionBiome.tscn — referenced in 1 script
✗ IntroTutorial.tscn — referenced in 1 script
```

---

## How to Fix (Choose One Approach)

### Option A: Create the Missing Scenes (RECOMMENDED)

1. Create `scenes/HubAntre.tscn`
   - Implement hub menu (biome selection, collections, stats)
   - Transition to TransitionBiome or MerlinGame

2. Create `scenes/TransitionBiome.tscn`
   - Implement 6-phase transition animation (brume → emergence → revelation)
   - Transition to MerlinGame

3. Create `scenes/IntroTutorial.tscn`
   - Implement tutorial (controls, card system, minigames)
   - Transition to HubAntre or MerlinGame

**Timeline**: Depends on complexity (1-3 full implementation cycles)

### Option B: Redirect to Existing Scenes (QUICK FIX)

Modify `SceneRencontreMerlin.gd` lines 10-14:

**Current**:
```gdscript
const SCENE_HUB := "res://scenes/HubAntre.tscn"
const SCENE_BIOME := "res://scenes/TransitionBiome.tscn"
const SCENE_TUTORIAL := "res://scenes/IntroTutorial.tscn"
var _next_scene: String = SCENE_HUB
```

**Fixed** (redirect all to MerlinGame):
```gdscript
const SCENE_HUB := "res://scenes/MerlinGame.tscn"
const SCENE_BIOME := "res://scenes/MerlinGame.tscn"
const SCENE_TUTORIAL := "res://scenes/MerlinGame.tscn"
var _next_scene: String = SCENE_HUB
```

Do the same in `broceliande_forest_3d.gd` line 8:

**Current**:
```gdscript
const HUB_SCENE: String = "res://scenes/HubAntre.tscn"
```

**Fixed**:
```gdscript
const HUB_SCENE: String = "res://scenes/MerlinGame.tscn"
```

**Timeline**: 5 minutes (quick bypass, skips intermediate scenes)
**Trade-off**: No hub, no transition scene, no tutorial — jumps straight to gameplay

### Option C: Conditional Fallback (HYBRID)

Add safe fallback logic in both scripts:

```gdscript
func _safe_transition(target: String) -> void:
    # Check if target scene exists, fallback to MerlinGame if not
    var fallback: String = "res://scenes/MerlinGame.tscn"
    var target_path: String = target if ResourceLoader.exists(target) else fallback
    PixelTransition.transition_to(target_path)
```

Then call: `_safe_transition(_next_scene)`

**Timeline**: 10 minutes
**Trade-off**: Doesn't prevent skipping intermediate scenes, but prevents crashes

---

## Recommendation

**DO NOT DEPLOY** until this is resolved.

**Suggested Action**:
1. If missing scenes are critical design features → **Choose Option A** (create them)
2. If missing scenes are nice-to-have → **Choose Option B** (quick bypass to MerlinGame)
3. If you want safety nets → **Choose Option C** (fallback logic)

---

## Audit Files

**Detailed audit**: `/c:/Users/PGNK2128/Godot-MCP/web-demo/QA_AUDIT_MENU3DPC_CURRENT.md`
- Complete code review
- Smoke test results
- Blocking issue analysis
- Scene-by-scene breakdown

**Updated metrics**: `/c:/Users/PGNK2128/Godot-MCP/web-demo/METRICS.md`
- Build validation status
- Scene flow coverage
- Deployment gate status

---

**QA Lead Verdict**: Menu3DPC is high-quality code. The missing scenes are a scope/design issue, not a code issue. Once the 3 scenes (or redirects) are in place, the game will proceed to full gameplay loop validation.
