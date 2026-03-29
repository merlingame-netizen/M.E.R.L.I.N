# Developer Checklist — Post-QA Audit Actions

**Audit Date**: 2026-03-28
**Audited Component**: Menu3DPC refactor
**Status**: Code PASS, Deployment BLOCKED

---

## Immediate Actions (BLOCKING ISSUES)

### [ ] Issue #1: Create or Redirect HubAntre.tscn

**Affected Code**:
- `scripts/SceneRencontreMerlin.gd` line 10
- `scripts/broceliande_3d/broceliande_forest_3d.gd` line 8

**What to do** (pick one):

**Option 1A: Create HubAntre.tscn**
```
□ Create new scene: scenes/HubAntre.tscn
□ Add Control root node
□ Add biome selection UI (world map)
□ Add script: scripts/HubAntre.gd
□ Implement on_biome_selected() → transition to TransitionBiome or MerlinGame
□ Test transition path: SceneRencontreMerlin → HubAntre → MerlinGame
```

**Option 1B: Redirect HubAntre to MerlinGame (quick fix)**
```gdscript
# scripts/SceneRencontreMerlin.gd line 10
const SCENE_HUB := "res://scenes/MerlinGame.tscn"  # Changed from HubAntre

# scripts/broceliande_3d/broceliande_forest_3d.gd line 8
const HUB_SCENE: String = "res://scenes/MerlinGame.tscn"  # Changed from HubAntre
```
Time: 2 minutes | Risk: Low | Trade-off: Skips hub phase

---

### [ ] Issue #2: Create or Redirect TransitionBiome.tscn

**Affected Code**:
- `scripts/SceneRencontreMerlin.gd` line 11

**What to do** (pick one):

**Option 2A: Create TransitionBiome.tscn**
```
□ Create new scene: scenes/TransitionBiome.tscn
□ Add Node root
□ Add script: scripts/TransitionBiome.gd
□ Implement 6-phase animation:
  - Brume (mist intro)
  - Emergence (pixel landscape assembly)
  - Revelation (biome reveal)
  - Sentier (path description)
  - Voix (Merlin voice monologue)
  - Dissolution (fade out to MerlinGame)
□ Transition to MerlinGame.tscn
□ Test path: SceneRencontreMerlin → TransitionBiome → MerlinGame
```

**Option 2B: Redirect TransitionBiome to MerlinGame (quick fix)**
```gdscript
# scripts/SceneRencontreMerlin.gd line 11
const SCENE_BIOME := "res://scenes/MerlinGame.tscn"  # Changed from TransitionBiome
```
Time: 1 minute | Risk: Low | Trade-off: Skips transition scene

---

### [ ] Issue #3: Create or Redirect IntroTutorial.tscn

**Affected Code**:
- `scripts/SceneRencontreMerlin.gd` line 12

**What to do** (pick one):

**Option 3A: Create IntroTutorial.tscn**
```
□ Create new scene: scenes/IntroTutorial.tscn
□ Add Control root
□ Add script: scripts/IntroTutorial.gd
□ Implement tutorial UI:
  - Card system explanation
  - Minigame controls
  - Effect system
  - Win conditions
□ Add skip button → transition to HubAntre
□ On tutorial complete → transition to HubAntre
□ Test path: SceneRencontreMerlin → IntroTutorial → HubAntre → MerlinGame
```

**Option 3B: Disable Tutorial (quick fix)**
```gdscript
# scripts/SceneRencontreMerlin.gd around line 652
func _show_destination_choice() -> void:
    var choice: int = await _dialogue_module.show_destination_choice()
    if choice == 1:
        _next_scene = SCENE_BIOME
    else:
        # Skip tutorial path entirely
        _next_scene = SCENE_HUB  # Always go to Hub, never Tutorial
```
Time: 5 minutes | Risk: Very Low | Trade-off: Skips tutorial completely

---

## Validation After Fixes

### [ ] Test Boot Sequence
```bash
# In Godot editor:
# 1. Open scenes/Menu3DPC.tscn
# 2. Run the scene (F5)
# 3. Wait for boot sequence to complete (~5.5 seconds)
# 4. Observe menu fade in
# Expected: Menu appears with 3 buttons, no console errors
```

### [ ] Test "Nouvelle Partie" Path
```bash
# In Godot editor:
# 1. Menu3DPC is running
# 2. Click "Nouvelle Partie" button
# 3. Wait for transition (PixelTransition effect)
# 4. Observe SceneRencontreMerlin load
# 5. After Merlin dialogue, observe destination choice UI
# Expected: No console errors, smooth transitions
```

### [ ] Test Each Merlin Exit Path
```bash
# Test Hub path:
# - Merlin dialogue completes
# - Player chooses default (skip button or timer)
# - Should transition to HubAntre (or MerlinGame if redirected)
# Expected: No crash, console clean

# Test Direct Adventure path:
# - Merlin dialogue completes
# - Player chooses "I want to go directly into battle"
# - Should transition to TransitionBiome (or MerlinGame if redirected)
# Expected: No crash, console clean

# Test Tutorial path (if IntroTutorial created):
# - First-time player (tutorial_done = false)
# - After Merlin dialogue
# - Should show IntroTutorial
# Expected: Tutorial UI loads, no crash
```

### [ ] Test "Continuer" Path
```bash
# In Godot editor:
# 1. Menu3DPC is running
# 2. Click "Continuer" button
# 3. Wait for transition
# 4. Observe BroceliandeForest3D load (forest walk scene)
# Expected: No console errors, forest scene loads
```

### [ ] Test Options Button
```bash
# In Godot editor:
# 1. Menu3DPC is running
# 2. Click "Options" button
# 3. Menu should remain visible (no-op)
# Expected: Nothing happens (correct stub behavior)
```

### [ ] Console Error Check
```bash
# After running all 5 paths above, check the Output pane in editor
# Expected: 0 errors, 0 warnings
# Acceptable: Info logs from scene transitions
```

---

## Code Quality Double-Checks

### [ ] Verify All Transitions Use PixelTransition
```bash
# Search for scene transitions in modified files:
grep -n "change_scene\|PixelTransition" scripts/menu_3d_pc.gd
grep -n "change_scene\|PixelTransition" scripts/SceneRencontreMerlin.gd
# Expected: All transitions via PixelTransition.transition_to()
# If you see get_tree().change_scene_to_file(): verify it's a fallback
```

### [ ] Verify No Hardcoded Scene Paths in UI
```bash
# Search for resource paths in UI scripts:
grep -n "res://scenes" scripts/menu_3d_pc.gd
# Expected: Only found in _on_menu_button() handler (lines 905, 907)
# No other hardcoded paths in UI creation code
```

### [ ] Check Null Guards on Autoloads
```bash
# Review lines 891-901 in menu_3d_pc.gd:
# - All SFXManager calls guarded with if is_instance_valid(SFXManager)
# - All PixelTransition calls guarded with proper null checks
# Expected: No unguarded calls to autoloads that could be null
```

---

## Update Documentation

### [ ] Update METRICS.md
```
Run command:
    ./update-metrics.sh

Or manually:
    1. Change "Build Status" from "⚠ PARTIAL PASS" to "✓ PASS"
    2. Update Scene Flow Coverage table (mark all 7 scenes as ✓ YES)
    3. Update Key Findings (remove blocking issues if fixed)
    4. Update Deployment Gate (remove blocking issues)
```

### [ ] Update this Checklist
```
□ Mark completed items with [x] after each fix
□ Update "Status" at top from "BLOCKED" to "READY FOR SMOKE TESTS"
□ Date sign-off at bottom
```

---

## Pre-Deployment Checklist

Once all 3 issues are resolved:

### [ ] TypeScript Check (if applicable)
```bash
cd web-demo
npm run build
# Expected: Vite build succeeds, no errors
# Expected: output size < 800KB (gzipped < 200KB)
```

### [ ] Godot Build Check
```bash
godot --path . --check
# Expected: 0 errors, 0 warnings
# Acceptable: Info logs about exports
```

### [ ] Run Full Smoke Test
```
Scenario 1: Boot → Menu → "Nouvelle Partie" → Merlin → [path 1] → End
Scenario 2: Boot → Menu → "Nouvelle Partie" → Merlin → [path 2] → End
Scenario 3: Boot → Menu → "Nouvelle Partie" → Merlin → [path 3] → End
Scenario 4: Boot → Menu → "Continuer" → Forest → [result] → End
Scenario 5: Boot → Menu → "Options" → (no-op) → Menu (still visible)

Expected Result: All 5 complete without errors, console shows 0 errors
```

### [ ] Visual Regression Check
```
Boot sequence: ✓ (7 lines appear, fade out cleanly)
Menu animations: ✓ (buttons fade in with scale, stagger visible)
Hover effects: ✓ (border changes to amber on hover)
Click sounds: ✓ (click.ogg plays when button pressed)
Glitch effects: ✓ (rare screen distortion every 12-30s)
Transition effects: ✓ (PixelTransition effect visible between scenes)
```

---

## Sign-Off

**Developer Name**: ___________________
**Date Completed**: ___________________
**All Fixes Applied**: [ ] YES [ ] NO
**All Smoke Tests Passed**: [ ] YES [ ] NO
**Ready for Vercel Deployment**: [ ] YES [ ] NO

**If NO, list remaining issues**:
```
1. _________________________________
2. _________________________________
3. _________________________________
```

---

## Contact

**If issues arise during implementation**:
- Check `QA_AUDIT_MENU3DPC_CURRENT.md` for detailed code analysis
- Check `QA_SUMMARY_BLOCKING_ISSUES.md` for quick reference
- Review `QA_AUDIT_SCENE_FLOW.md` for complete scene flow (from previous audit)

**QA Lead**: Automated Testing System
**Report Date**: 2026-03-28
