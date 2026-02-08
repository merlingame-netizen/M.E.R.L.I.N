# Art Direction Audit Report
## M.E.R.L.I.N. — Le Jeu des Oghams

**Author:** Art Direction Agent
**Date:** 2026-02-08
**Scope:** Full visual consistency audit across all scenes, shaders, palettes, typography, animations

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Palette Audit — Scene-by-Scene](#2-palette-audit)
3. [Typography Audit](#3-typography-audit)
4. [Shader Audit](#4-shader-audit)
5. [Animation Timing Audit](#5-animation-timing-audit)
6. [Celtic Ornament Consistency](#6-celtic-ornament-consistency)
7. [Game UI Scenes (Triade / Reigns)](#7-game-ui-scenes)
8. [IntroCeltOS Boot Scene](#8-introceltos-boot-scene)
9. [TestLLMSceneUltimate](#9-testllmsceneultimate)
10. [Asset Inventory](#10-asset-inventory)
11. [Biome Color Discrepancies](#11-biome-color-discrepancies)
12. [Critical Inconsistencies Summary](#12-critical-inconsistencies)
13. [Recommended Corrections](#13-recommended-corrections)
14. [Future UI: Bestiole Panel Guidelines](#14-future-bestiole-ui)

---

## 1. EXECUTIVE SUMMARY

### Overall Assessment: GOOD with significant gaps in game UI scenes

**Scenes with EXCELLENT visual coherence (Parchemin Mystique Breton style):**
- `MenuPrincipalReigns.gd` — **REFERENCE implementation** (canonical palette, full style)
- `SceneEveil.gd` — Matches reference palette exactly
- `SceneAntreMerlin.gd` — Matches reference, with appropriate extensions (ogham_glow, bestiole)
- `Calendar.gd` — Matches reference palette, adds season colors correctly
- `IntroMerlinDialogue.gd` — Matches reference palette (inline values, not const dict)

**Scenes with CRITICAL visual divergence:**
- `TriadeGameUI.gd` — **No parchment style at all**, uses default Godot theme, hard-coded generic colors
- `ReignsGameUI.gd` — **No parchment style at all**, depends entirely on .tscn scene styling
- `TestLLMSceneUltimate.gd` — **Completely different dark palette** ("DRU_COLORS"), does not match any project style

**Scenes with INTENTIONAL divergence (acceptable):**
- `IntroCeltOS.gd` — Dark terminal/boot aesthetic, transitions TO parchment world

### Key Finding
The project has **two visual worlds** that are not bridged:
1. **Parchment World** (menu, narrative scenes) — Fully coherent, well-documented
2. **Gameplay World** (Triade UI, Reigns UI) — Unstyled or uses a different vocabulary

---

## 2. PALETTE AUDIT — Scene-by-Scene

### 2.1 Canonical Palette: "Parchemin Mystique Breton"

Source of truth: `MenuPrincipalReigns.gd` PALETTE constant.

```
"paper":        Color(0.965, 0.945, 0.905)        # Ivoire ancien
"paper_dark":   Color(0.935, 0.905, 0.855)        # Parchemin use
"paper_warm":   Color(0.955, 0.930, 0.890)        # Parchemin tiede
"ink":          Color(0.22, 0.18, 0.14)            # Encre brune profonde
"ink_soft":     Color(0.38, 0.32, 0.26)            # Encre diluee
"ink_faded":    Color(0.50, 0.44, 0.38, 0.35)     # Encre tres pale
"accent":       Color(0.58, 0.44, 0.26)            # Bronze ancien
"accent_soft":  Color(0.65, 0.52, 0.34)            # Or terni
"accent_glow":  Color(0.72, 0.58, 0.38, 0.25)     # Lueur doree subtile
"shadow":       Color(0.25, 0.20, 0.16, 0.18)     # Ombre chaude legere
"line":         Color(0.40, 0.34, 0.28, 0.12)     # Lignes subtiles
"mist":         Color(0.94, 0.92, 0.88, 0.35)     # Brume bretonne
"celtic_gold":  Color(0.68, 0.55, 0.32)           # Or celtique
"celtic_brown": Color(0.45, 0.36, 0.28)           # Brun enluminure
```

### 2.2 Palette Per Scene

| Scene | Has PALETTE const? | Matches Canonical? | Extra Colors | Missing Colors |
|-------|-------------------|-------------------|--------------|----------------|
| MenuPrincipalReigns.gd | YES (14 entries) | **CANONICAL** | celtic_gold, celtic_brown | -- |
| SceneEveil.gd | YES (12 entries) | EXACT match | -- | celtic_gold, celtic_brown |
| SceneAntreMerlin.gd | YES (14 entries) | Match + extensions | ogham_glow, bestiole | celtic_gold, celtic_brown |
| Calendar.gd | YES (14 entries) | Match + extensions | spring/summer/autumn/winter, event_* | celtic_gold, celtic_brown |
| IntroMerlinDialogue.gd | NO (inline vars) | MATCH (same values) | error Color(0.72, 0.38, 0.30) | -- |
| TriadeGameUI.gd | NO | **NO MATCH** | ASPECT_COLORS, generic colors | All parchment colors |
| ReignsGameUI.gd | NO | **NO MATCH** | gauge colors (red/green) | All parchment colors |
| TestLLMSceneUltimate.gd | YES (DRU_COLORS) | **COMPLETELY DIFFERENT** | Dark UI palette | All parchment colors |
| IntroCeltOS.gd | YES (PALETTE) | **INTENTIONALLY DIFFERENT** | Terminal green, eye blue | -- |

### 2.3 Specific Inconsistencies Found

**ISSUE #1: SceneEveil.gd missing `celtic_gold` and `celtic_brown`**
- Severity: LOW
- The scene does not use Celtic ornaments with gold, so the absence is harmless.
- Recommendation: Add for consistency but not blocking.

**ISSUE #2: SceneAntreMerlin.gd custom biome colors differ from VISUAL_SPEC doc**
- Severity: MEDIUM
- In `SceneAntreMerlin.gd`, `BIOME_DATA` uses approximate RGB colors:
  ```
  "foret_broceliande": Color(0.30, 0.50, 0.28)
  "cercles_pierres": Color(0.50, 0.50, 0.55)
  "marais_korrigans": Color(0.30, 0.42, 0.30)
  ```
- The VISUAL_SPEC document specifies GBC palette hex colors:
  ```
  Broceliande: Color("#48a028") = Color(0.282, 0.627, 0.157)
  Cercles: Color("#f0e890") = Color(0.941, 0.910, 0.565)
  Marais: Color("#403848") = Color(0.251, 0.220, 0.282)
  ```
- **These are significantly different.** SceneAntreMerlin uses muted/desaturated approximations rather than the vivid GBC palette colors.
- Recommendation: Update BIOME_DATA in SceneAntreMerlin.gd to use the canonical BIOME_COLORS from the VISUAL_SPEC doc.

**ISSUE #3: TriadeGameUI.gd uses entirely unstyled colors**
- Severity: HIGH
- `ASPECT_COLORS`:
  ```
  "Corps": Color(0.8, 0.4, 0.2)   # Generic orange
  "Ame": Color(0.5, 0.3, 0.7)     # Generic purple
  "Monde": Color(0.3, 0.6, 0.4)   # Generic green
  ```
- Option button colors: `Color(0.4, 0.6, 0.8)`, `Color(0.8, 0.7, 0.3)`, `Color(0.8, 0.4, 0.4)`
- Card speaker color: `Color(0.9, 0.7, 0.3)` — generic gold
- End screen overlay: `Color(0, 0, 0, 0.85)` — pure black
- Victory/defeat: `Color(0.4, 0.9, 0.4)` / `Color(0.9, 0.4, 0.4)` — pure green/red
- **None of these match the parchment palette.**
- Recommendation: Full restyle of TriadeGameUI to adopt parchment style (see Section 13).

**ISSUE #4: ReignsGameUI.gd has no styling code**
- Severity: HIGH
- All styling depends on the .tscn scene file, which references `reigns_theme.tres`.
- Gauge bar styling uses hardcoded `Color(0.9, 0.2, 0.2)` and `Color(0.3, 0.7, 0.3)`.
- The end screen uses `Color(0, 0, 0, 0.8)` — generic.
- Recommendation: Align with parchment palette or create a dedicated game theme.

**ISSUE #5: TestLLMSceneUltimate.gd dark palette**
- Severity: LOW (test scene)
- Uses DRU_COLORS dark palette: dark background, amber accent.
- Acceptable as a dev/debug scene, but should ideally also adopt parchment style for visual consistency.
- Recommendation: Low priority, restyle if time permits.

**ISSUE #6: IntroMerlinDialogue.gd uses inline colors instead of PALETTE dict**
- Severity: LOW (values match, but code is less maintainable)
- Colors are defined as local variables in `_apply_theme()`:
  ```gdscript
  var paper := Color(0.965, 0.945, 0.905)
  var ink := Color(0.22, 0.18, 0.14)
  ```
- Values are CORRECT but duplicated from MenuPrincipalReigns.
- Recommendation: Extract to a shared const or autoload.

---

## 3. TYPOGRAPHY AUDIT

### 3.1 Font Inventory

Available fonts:
| Font | Path | Usage |
|------|------|-------|
| MorrisRomanBlack | `res://resources/fonts/morris/MorrisRomanBlack.otf` + `.ttf` | Titles, display text |
| MorrisRomanBlackAlt | `res://resources/fonts/morris/MorrisRomanBlackAlt.otf` + `.ttf` | Body, dialogue, buttons |
| celtic-bit | `res://resources/fonts/celtic_bit/celtic-bit.ttf` | Ornamental characters |
| celtic-bit-thin | `res://resources/fonts/celtic_bit/celtic-bit-thin.ttf` | Not currently used |
| celtic-bitty | `res://resources/fonts/celtic_bit/celtic-bitty.ttf` | Not currently used |

### 3.2 Font Usage Per Scene

| Scene | Title Font | Body Font | Celtic Font | Fallback Chain |
|-------|-----------|-----------|-------------|----------------|
| MenuPrincipalReigns | MorrisRomanBlack | MorrisRomanBlackAlt | celtic-bit | .otf -> .ttf -> fallback |
| SceneEveil | MorrisRomanBlack | MorrisRomanBlackAlt | -- | .otf -> .ttf -> title |
| SceneAntreMerlin | MorrisRomanBlack | MorrisRomanBlackAlt | -- | .otf -> .ttf -> title |
| IntroMerlinDialogue | MorrisRomanBlack | MorrisRomanBlackAlt | -- | .ttf -> .otf -> celtic-bit-thin |
| Calendar | MorrisRomanBlack | MorrisRomanBlackAlt | -- | direct path |
| **TriadeGameUI** | **NONE** | **NONE** | **NONE** | **Default Godot font** |
| **ReignsGameUI** | **NONE** | **NONE** | **NONE** | **Depends on theme** |

### 3.3 Font Size Consistency

| Role | MenuPrincipal | SceneEveil | SceneAntreMerlin | IntroMerlinDialogue | VISUAL_SPEC |
|------|--------------|------------|------------------|---------------------|-------------|
| Title | 52px | -- | -- | -- | 48-56px |
| Subtitle | 16px | -- | -- | -- | 24px |
| Body/Dialogue | 22px (buttons) | 22px | 22px | 22px | 20-22px |
| Caption/Hint | -- | 14px | 14px | 12px-16px | 14px |
| Ornament | 14px | 14px | 14px | -- | 12-14px |
| Progress | -- | -- | -- | 16px (accent) | -- |

**ISSUE #7: Subtitle font size inconsistency**
- MenuPrincipal uses 16px for subtitle
- VISUAL_SPEC recommends 24px for subtitles
- Recommendation: Consider increasing subtitle to 20-24px for better readability.

**ISSUE #8: IntroMerlinDialogue hint label at 12px**
- Slightly below the 14px minimum recommended.
- Recommendation: Increase to 14px.

**ISSUE #9: IntroMerlinDialogue fallback chain differs**
- Uses `.ttf` first, then `.otf`, whereas other scenes use `.otf` first.
- Also falls back to `celtic-bit-thin.ttf` instead of body or system font.
- Recommendation: Standardize fallback order: `.otf` -> `.ttf` -> system.

---

## 4. SHADER AUDIT

### 4.1 Shader Inventory

| Shader | File | Used By | Status |
|--------|------|---------|--------|
| reigns_paper | `shaders/reigns_paper.gdshader` | MenuPrincipal, SceneEveil, SceneAntreMerlin, Calendar | ACTIVE, core |
| screen_distortion | `shaders/screen_distortion.gdshader` | ScreenEffects autoload (global) | ACTIVE, global |
| seasonal_snow | `shaders/seasonal_snow.gdshader` | SceneEveil, SceneAntreMerlin (winter only) | ACTIVE, seasonal |
| bestiole_squish | `shaders/bestiole_squish.gdshader` | Referenced in VISUAL_SPEC, not yet in scene code | DESIGNED, not implemented |
| pixelate | `shaders/pixelate.gdshader` | Unknown | LEGACY? |
| ps1_material | `shaders/ps1_material.gdshader` | Unknown | LEGACY? |
| crt_static | `shaders/crt_static.gdshader` | Unknown | LEGACY? |

### 4.2 reigns_paper.gdshader Parameter Consistency

| Parameter | Default | MenuPrincipal | SceneEveil | SceneAntreMerlin | VISUAL_SPEC Cave |
|-----------|---------|--------------|------------|------------------|------------------|
| paper_tint | 0.96,0.92,0.84 | PALETTE.paper | PALETTE.paper | PALETTE.paper | #484840 (dark) |
| grain_strength | 0.035 | 0.025 | 0.025 | 0.025 | 0.04 |
| vignette_strength | 0.12 | 0.08 | 0.08 | 0.08 | 0.20 |
| vignette_softness | 0.55 | 0.65 | 0.65 | 0.65 | 0.40 |
| grain_scale | 900.0 | 1200.0 | 1200.0 | 1200.0 | 600.0 |
| grain_speed | 0.15 | 0.08 | 0.08 | 0.08 | 0.03 |
| warp_strength | 0.002 | 0.001 | 0.001 | 0.001 | 0.0005 |

**Finding:** MenuPrincipal, SceneEveil, and SceneAntreMerlin all use IDENTICAL paper shader parameters. This is correct for the parchment world.

**ISSUE #10: SceneAntreMerlin does NOT use the cave variant described in VISUAL_SPEC**
- The VISUAL_SPEC doc specifies that SceneAntreMerlin should use `dark_gray (#484840)` paper_tint with coarser grain and stronger vignette for a "cave feel."
- The current implementation uses the same warm parchment as the menu.
- This means the Antre (Merlin's Lair) looks identical to the menu -- no cave atmosphere.
- Recommendation: Implement the cave-tinted variant for SceneAntreMerlin as specified in VISUAL_SPEC Section 4.1.

### 4.3 screen_distortion.gdshader / ScreenEffects Mood Profiles

The 7 mood profiles are well-defined and consistent:
- `sage`, `amuse`, `mystique`, `serieux`, `pensif`, `warm`, `cryptic`

Each mood is correctly applied via `ScreenEffects.set_merlin_mood()` in:
- SceneEveil: "pensif" on entry, emotion-driven per line, "warm" on exit
- SceneAntreMerlin: "warm" on entry, emotion-driven per dialogue phase, "amuse" on biome select
- IntroMerlinDialogue: emotion-keyword based detection

**No inconsistencies found in mood system usage.**

### 4.4 seasonal_snow.gdshader

Used identically in SceneEveil and SceneAntreMerlin:
- `speed: 0.25`, `density: 0.22`
- Applied only during winter months (Dec-Feb)
- Positioned to overlay the card area only

**No inconsistencies found.**

---

## 5. ANIMATION TIMING AUDIT

### 5.1 Entry Animations

| Scene | Ornament Fade | Card Slide Duration | Card Fade | Easing | Button Cascade |
|-------|--------------|---------------------|-----------|--------|----------------|
| MenuPrincipal | 0.8s SINE | 0.7s SINE EASE_OUT | 0.5s SINE | Consistent | 0.05s stagger |
| SceneEveil | 0.8s SINE | 0.7s SINE EASE_OUT | 0.5s SINE | Matches Menu | -- |
| SceneAntreMerlin | 0.8s SINE | 0.7s SINE EASE_OUT | 0.5s SINE | Matches Menu | -- |
| IntroMerlinDialogue | -- | 0.35s QUAD EASE_OUT | 0.25s | **DIFFERENT** | -- |

**ISSUE #11: IntroMerlinDialogue uses TRANS_QUAD instead of TRANS_SINE**
- All other scenes use `TRANS_SINE / EASE_OUT` for card entry.
- IntroMerlinDialogue uses `TRANS_QUAD / EASE_OUT` with faster timing (0.35s vs 0.7s).
- This creates a snappier, less organic feel compared to the rest.
- Recommendation: Align to TRANS_SINE / 0.7s for consistency.

### 5.2 Mist Breathing Animation

| Scene | Cycle Up | Cycle Down | Total Cycle | Alpha Range | Easing |
|-------|----------|-----------|-------------|-------------|--------|
| MenuPrincipal | 8.0s | 8.0s | 16.0s | 0.08 - 0.25 | SINE |
| SceneEveil | 8.0s | 8.0s | 16.0s | 0.08 - 0.25 | SINE |
| SceneAntreMerlin | 8.0s | 8.0s | 16.0s | 0.06 - 0.20 | SINE |

**ISSUE #12: SceneAntreMerlin mist range slightly different**
- Menu and Eveil: 0.08 to 0.25
- AntreMerlin: 0.06 to 0.20
- Minor, but creates slightly thinner mist in the lair.
- Recommendation: Intentional? If so, document. If not, align to 0.08-0.25.

### 5.3 Typewriter Parameters

| Scene | Char Delay | Punct Delay | Blip Freq | Blip Duration | Blip Volume |
|-------|-----------|-------------|-----------|---------------|-------------|
| SceneEveil | 0.030s | 0.10s | 880Hz | 0.018s | 0.04 |
| SceneAntreMerlin | 0.030s | 0.10s | 880Hz | 0.018s | 0.04 |
| IntroMerlinDialogue | 0.025s | 0.08s | 880Hz | 0.018s | 0.04 |
| VISUAL_SPEC | 0.025s | 0.08s | 880Hz | -- | 0.04 |

**ISSUE #13: Typewriter speed inconsistency**
- SceneEveil and SceneAntreMerlin use 0.030s/0.10s (slower)
- IntroMerlinDialogue uses 0.025s/0.08s (faster, matches VISUAL_SPEC)
- Recommendation: Standardize to 0.025s/0.08s as per VISUAL_SPEC, or 0.030s/0.10s if the slower pace is preferred for post-questionnaire scenes. Document the choice.

### 5.4 Transition Out Animations

| Scene | Card Fade | Ornament Fade | Mist Rise | Interval | Total |
|-------|-----------|---------------|-----------|----------|-------|
| SceneEveil | 0.6s SINE IN_OUT | 0.4s | 0.8s to 0.6 | 0.3s | ~1.4s |
| SceneAntreMerlin | 0.6s SINE IN_OUT | 0.4s | 0.8s to 0.6 | 0.3s | ~1.4s |
| MenuPrincipal | 0.25s (swipe) | -- | -- | 0.25s | ~0.5s |
| IntroMerlinDialogue | 0.8s (modulate fade) | -- | -- | callback | ~0.8s |

**ISSUE #14: Menu exit is much faster than narrative exits**
- Menu: 0.25s swipe with rotation
- Narrative scenes: ~1.4s gentle fade
- This is arguably intentional (menu = snappy, narrative = contemplative), but could feel jarring when transitioning FROM menu TO a scene and then BACK.
- Recommendation: Acceptable as intentional. No change needed.

### 5.5 Card Entry Y-Offset

| Scene | Entry Offset | Exit Animation |
|-------|-------------|----------------|
| MenuPrincipal | +40px down, slide up | Swipe + rotate |
| SceneEveil | +40px down, slide up | Fade out |
| SceneAntreMerlin | +40px down, slide up | Fade out |
| IntroMerlinDialogue | +60px down, slide up | Verb-specific (force/logique/finesse) |

**ISSUE #15: IntroMerlinDialogue uses +60px offset**
- Other scenes use +40px.
- Minor inconsistency but noticeable in sequential flow.
- Recommendation: Align to +40px.

---

## 6. CELTIC ORNAMENT CONSISTENCY

### 6.1 Pattern Used

All scenes use the SAME pattern:
```gdscript
["─", "•", "─", "─", "◆", "─", "─", "•", "─"]
```
Repeated 40 times (360 characters).

### 6.2 Ornament Styling

| Property | MenuPrincipal | SceneEveil | SceneAntreMerlin |
|----------|--------------|------------|------------------|
| Font color | ink_faded | ink_faded | ink_faded |
| Font size | 14px | 14px | 14px |
| Initial alpha | 0.0 | 0.0 | 0.0 |
| Fade in | 0.8s SINE | 0.8s SINE | 0.8s SINE |

**No inconsistencies found.** Celtic ornaments are perfectly consistent.

---

## 7. GAME UI SCENES (Triade / Reigns)

### 7.1 TriadeGameUI.gd — CRITICAL STYLE GAP

**Current state:** TriadeGameUI builds its entire UI programmatically using default Godot styles. It has:
- No background (no paper shader)
- No Celtic ornaments
- No Morris Roman fonts
- No card styling matching parchment aesthetic
- Colors that don't belong to any palette

**Specific issues:**
1. ASPECT_COLORS `(0.8, 0.4, 0.2)`, `(0.5, 0.3, 0.7)`, `(0.3, 0.6, 0.4)` are generic and not from GBC palette
2. Card panel uses default Godot Panel style (no parchment, no shadow, no border radius)
3. Card speaker label uses `Color(0.9, 0.7, 0.3)` -- not matching `accent` or `celtic_gold`
4. Option button colors `(0.4, 0.6, 0.8)`, `(0.8, 0.7, 0.3)`, `(0.8, 0.4, 0.4)` are fully arbitrary
5. End screen uses pure black overlay `Color(0, 0, 0, 0.85)` -- should use `ink` with parchment tint
6. Souffle icon uses emoji `SOUFFLE_ICON := "..."` -- fine for Unicode, but no consistent styling
7. State indicator uses `Color(0.5, 0.5, 0.5)` for inactive and `Color(0.7, 0.7, 0.7)` for labels -- gray, not warm

**Required restyle:**
- Apply parchment paper shader as background
- Add Celtic ornaments top/bottom
- Style card panel with paper_warm bg, ink_faded border, shadow, corner_radius 4
- Use Morris Roman fonts throughout
- Replace ASPECT_COLORS with GBC palette equivalents:
  ```
  "Corps": Color("#a08058")  (earth)
  "Ame": Color("#8868b0")    (mystic)
  "Monde": Color("#48a028")  (grass)
  ```
- Replace option colors with palette colors
- Style end screen with parchment overlay instead of black

### 7.2 ReignsGameUI.gd — DEPENDS ON THEME FILE

ReignsGameUI uses @onready references to .tscn nodes and `reigns_theme.tres`. It has minimal in-code styling:
- Gauge critical colors: `Color(0.9, 0.2, 0.2)` and `Color(0.3, 0.7, 0.3)` -- generic red/green
- End screen: `Color(0, 0, 0, 0.8)` -- pure black

**ISSUE #16: Gauge critical colors should use GBC palette**
- Red critical: use `Color("#8B0000")` (art_direction.md Warning) or `Color("#a04818")` (fire_dark)
- Green normal: use `Color("#48a028")` (grass) or `Color("#4A5D23")` (nature from art_direction.md)

---

## 8. INTROCELTOS BOOT SCENE

IntroCeltOS uses an intentionally different visual language (terminal/boot aesthetic):

```gdscript
const PALETTE := {
    "bg": Color(0.015, 0.015, 0.025),       # Near-black
    "text": Color(0.6, 0.7, 0.65),           # Terminal green-gray
    "accent": Color(0.4, 0.85, 0.55),        # Bright green
    "block": Color(0.25, 0.75, 0.45),        # Block green
    "eye_deep": Color(0.15, 0.45, 0.85),     # Merlin eye blue
    ...
}
```

This is **intentionally different** -- it represents the "boot sequence" before M.E.R.L.I.N. establishes his connection. The visual transition from IntroCeltOS -> IntroMerlinDialogue/SceneEveil should feel like "entering the parchment world."

**No inconsistencies.** This is correct by design.

---

## 9. TESTLLMSCENEULTIMATE

Uses a dark debug palette:
```gdscript
const DRU_COLORS := {
    "bg_dark": Color(0.07, 0.08, 0.1),
    "accent": Color(0.74, 0.66, 0.45),
    "text": Color(0.92, 0.88, 0.72),
    ...
}
```

**ISSUE #17: TestLLMScene should ideally match parchment style**
- Severity: LOW (dev/test scene, not player-facing)
- The "DRU_COLORS" name references the old project name.
- Recommendation: Low priority. Restyle if this scene becomes player-accessible.

---

## 10. ASSET INVENTORY

### 10.1 Fonts Available vs Used

| Font | Available | Used |
|------|-----------|------|
| MorrisRomanBlack.otf | YES | YES (titles) |
| MorrisRomanBlack.ttf | YES | YES (fallback) |
| MorrisRomanBlackAlt.otf | YES | YES (body) |
| MorrisRomanBlackAlt.ttf | YES | YES (fallback) |
| celtic-bit.ttf | YES | YES (MenuPrincipal ornaments) |
| celtic-bit-thin.ttf | YES | Partial (IntroMerlinDialogue fallback only) |
| celtic-bitty.ttf | YES | **NOT USED** |

### 10.2 Portrait Assets

| Asset | Path | Used By |
|-------|------|---------|
| Merlin.png | Assets/Sprite/Merlin.png | Default portrait |
| Merlin_PRINTEMPS.png | Assets/Sprite/Merlin_PRINTEMPS.png | Mar-May |
| Merlin_ETE.png | Assets/Sprite/Merlin_ETE.png | Jun-Aug |
| Merlin_AUTOMNE.png | Assets/Sprite/Merlin_AUTOMNE.png | Sep-Nov |
| Merlin_HIVER.png | Assets/Sprite/Merlin_HIVER.png | Dec-Feb |

All scenes use the same seasonal portrait logic. Consistent.

### 10.3 Audio Assets Referenced

| Sound | Path | Used By |
|-------|------|---------|
| ui_click | audio/sfx/ui/ui_click.ogg | MenuPrincipal, SceneEveil |
| ui_hover | audio/sfx/ui/ui_hover.ogg | MenuPrincipal |
| card_swipe | audio/sfx/ui/card_swipe.ogg | MenuPrincipal |

**ISSUE #18: SceneAntreMerlin does not reference UI sounds**
- No click/hover sounds for biome buttons.
- Recommendation: Add ui_click for biome button press, consistent with MenuPrincipal.

### 10.4 Shader Assets Status

| Shader | Status | Notes |
|--------|--------|-------|
| reigns_paper.gdshader | ACTIVE | Core visual |
| screen_distortion.gdshader | ACTIVE | Global post-process |
| seasonal_snow.gdshader | ACTIVE | Winter only |
| bestiole_squish.gdshader | CREATED | Not yet used in any scene code |
| pixelate.gdshader | LEGACY | Not referenced by any current scene |
| ps1_material.gdshader | LEGACY | Not referenced by any current scene |
| crt_static.gdshader | LEGACY | Not referenced by any current scene |

---

## 11. BIOME COLOR DISCREPANCIES

### 11.1 SceneAntreMerlin vs VISUAL_SPEC BIOME_COLORS

| Biome | SceneAntreMerlin.gd | VISUAL_SPEC (canonical) | Match? |
|-------|--------------------|-----------------------|--------|
| Broceliande | Color(0.30, 0.50, 0.28) | Color("#48a028") = (0.28, 0.63, 0.16) | **NO** (too dark, too blue) |
| Landes | Color(0.55, 0.40, 0.55) | Color("#8868b0") = (0.53, 0.41, 0.69) | Approximate, blue too low |
| Cotes | Color(0.35, 0.50, 0.65) | Color("#3888c8") = (0.22, 0.53, 0.78) | Approximate, red too high |
| Villages | Color(0.60, 0.45, 0.30) | Color("#a08058") = (0.63, 0.50, 0.35) | Close enough |
| Cercles | Color(0.50, 0.50, 0.55) | Color("#f0e890") = (0.94, 0.91, 0.56) | **COMPLETELY WRONG** (gray vs gold) |
| Marais | Color(0.30, 0.42, 0.30) | Color("#403848") = (0.25, 0.22, 0.28) | **WRONG** (green vs purple-dark) |
| Collines | Color(0.48, 0.55, 0.40) | Color("#685030") = (0.41, 0.31, 0.19) | **WRONG** (green vs brown) |

**ISSUE #19: 4 out of 7 biome colors are significantly wrong in SceneAntreMerlin.gd**
- Severity: HIGH
- The biome selection screen will display incorrect colors that don't match the game's biome visual identity.
- Recommendation: Replace `BIOME_DATA` colors with the exact hex values from VISUAL_SPEC.

---

## 12. CRITICAL INCONSISTENCIES SUMMARY

### Priority 1 (Must Fix)

| # | Issue | File | Description |
|---|-------|------|-------------|
| 3 | Unstyled TriadeGameUI | triade_game_ui.gd | No parchment style, arbitrary colors, no fonts |
| 4 | Unstyled ReignsGameUI | reigns_game_ui.gd | No parchment style in code, depends on external theme |
| 10 | No cave shader variant | SceneAntreMerlin.gd | Lair looks identical to menu, no cave atmosphere |
| 19 | Wrong biome colors | SceneAntreMerlin.gd | 4/7 biome colors significantly wrong |

### Priority 2 (Should Fix)

| # | Issue | File | Description |
|---|-------|------|-------------|
| 6 | Inline palette | IntroMerlinDialogue.gd | Colors duplicated instead of shared const |
| 11 | Different easing | IntroMerlinDialogue.gd | TRANS_QUAD vs TRANS_SINE |
| 13 | Typewriter speed differs | SceneEveil.gd, SceneAntreMerlin.gd | 0.030s vs 0.025s spec |
| 15 | Card offset differs | IntroMerlinDialogue.gd | +60px vs +40px |
| 16 | Generic gauge colors | reigns_game_ui.gd | Red/green not from GBC palette |
| 18 | Missing UI sounds | SceneAntreMerlin.gd | No click sounds for biome buttons |

### Priority 3 (Nice to Have)

| # | Issue | File | Description |
|---|-------|------|-------------|
| 1 | Missing celtic_gold/brown | SceneEveil.gd | Unused but inconsistent dict |
| 7 | Subtitle font size | MenuPrincipalReigns.gd | 16px vs 24px spec |
| 8 | Small hint text | IntroMerlinDialogue.gd | 12px vs 14px min |
| 9 | Font fallback chain | IntroMerlinDialogue.gd | .ttf first vs .otf first |
| 12 | Mist range differs | SceneAntreMerlin.gd | 0.06-0.20 vs 0.08-0.25 |
| 17 | TestLLM dark palette | TestLLMSceneUltimate.gd | Legacy DRU_COLORS style |

---

## 13. RECOMMENDED CORRECTIONS

### 13.1 Shared Palette Autoload (Recommended Architecture)

Create a shared palette resource to eliminate duplication:

```gdscript
# scripts/autoload/VisualStyle.gd (or scripts/merlin/merlin_visual.gd)
extends RefCounted
class_name MerlinVisual

const PARCHMENT := {
    "paper": Color(0.965, 0.945, 0.905),
    "paper_dark": Color(0.935, 0.905, 0.855),
    "paper_warm": Color(0.955, 0.930, 0.890),
    "ink": Color(0.22, 0.18, 0.14),
    "ink_soft": Color(0.38, 0.32, 0.26),
    "ink_faded": Color(0.50, 0.44, 0.38, 0.35),
    "accent": Color(0.58, 0.44, 0.26),
    "accent_soft": Color(0.65, 0.52, 0.34),
    "accent_glow": Color(0.72, 0.58, 0.38, 0.25),
    "shadow": Color(0.25, 0.20, 0.16, 0.18),
    "line": Color(0.40, 0.34, 0.28, 0.12),
    "mist": Color(0.94, 0.92, 0.88, 0.35),
    "celtic_gold": Color(0.68, 0.55, 0.32),
    "celtic_brown": Color(0.45, 0.36, 0.28),
}

const BIOME_COLORS := { ... }  # From VISUAL_SPEC

const FONTS := {
    "title": "res://resources/fonts/morris/MorrisRomanBlack.otf",
    "body": "res://resources/fonts/morris/MorrisRomanBlackAlt.otf",
    "celtic": "res://resources/fonts/celtic_bit/celtic-bit.ttf",
}
```

### 13.2 TriadeGameUI Restyle Plan

1. Add parchment background with `reigns_paper.gdshader`
2. Add Celtic ornaments top/bottom
3. Use MorrisRomanBlack for aspect names, MorrisRomanBlackAlt for body
4. Replace ASPECT_COLORS with GBC palette:
   - Corps: `Color("#a08058")` (earth)
   - Ame: `Color("#8868b0")` (mystic)
   - Monde: `Color("#48a028")` (grass)
5. Style card panel: paper_warm bg, ink_faded border 1px, corner_radius 4, shadow 16px
6. Style option buttons: paper bg, ink_faded border, accent hover
7. Replace end screen: paper_warm overlay with ink text instead of black
8. Replace score color: `accent` instead of `Color(0.9, 0.8, 0.3)`

### 13.3 SceneAntreMerlin Cave Variant

Update the shader parameters for cave atmosphere:
```gdscript
mat.set_shader_parameter("paper_tint", Color("#484840"))  # dark_gray
mat.set_shader_parameter("grain_strength", 0.04)
mat.set_shader_parameter("vignette_strength", 0.20)
mat.set_shader_parameter("vignette_softness", 0.40)
mat.set_shader_parameter("grain_scale", 600.0)
mat.set_shader_parameter("grain_speed", 0.03)
mat.set_shader_parameter("warp_strength", 0.0005)
```

### 13.4 Fix Biome Colors in SceneAntreMerlin

Replace BIOME_DATA with canonical GBC palette colors:
```gdscript
const BIOME_DATA := {
    "foret_broceliande": {"name": "Foret de Broceliande", "color": Color("#48a028")},
    "landes_bruyere": {"name": "Landes de Bruyere", "color": Color("#8868b0")},
    "cotes_sauvages": {"name": "Cotes Sauvages", "color": Color("#3888c8")},
    "villages_celtes": {"name": "Villages Celtes", "color": Color("#a08058")},
    "cercles_pierres": {"name": "Cercles de Pierres", "color": Color("#f0e890")},
    "marais_korrigans": {"name": "Marais des Korrigans", "color": Color("#403848")},
    "collines_dolmens": {"name": "Collines aux Dolmens", "color": Color("#685030")},
}
```

---

## 14. FUTURE UI: BESTIOLE PANEL GUIDELINES

When implementing the Bestiole companion UI, follow these rules:

### Palette
- Core color: `Color("#88d850")` (grass_light) from GBC palette
- Glow: `Color("#f8f8c0")` (light_light) at 30% alpha
- Panel background: `PARCHMENT.paper_dark`
- Panel border: `Color(0.45, 0.62, 0.32)` (ogham_glow from SceneAntreMerlin)

### Typography
- Bestiole name: MorrisRomanBlack, 18px, ink color
- Stats/bond: MorrisRomanBlackAlt, 14px, ink_soft
- Ogham symbols: celtic-bit or Unicode Ogham block (U+1680-U+169F), 24-32px

### Animation
- Float: Y oscillation +/- 6px, period 3.5s, TRANS_SINE
- Breathe: scale 1.0 <-> 1.08, period 2.8s, TRANS_SINE
- Tap reaction: bestiole_squish.gdshader activation + brief scale bounce

### Card Style
- Same as main card: paper_warm bg, ink_faded border 1px, corner_radius 4, shadow 16px
- Ogham skill cards: paper_dark bg, ogham_glow border, corner_radius 6

---

## STYLE CHECK

- [x] All scenes audited for palette compliance
- [x] Typography consistency documented
- [x] Shader usage mapped
- [x] Animation timings compared
- [x] Celtic ornament patterns verified
- [x] Biome color accuracy checked
- [x] Asset inventory completed
- [ ] TriadeGameUI restyle (PENDING implementation)
- [ ] ReignsGameUI restyle (PENDING implementation)
- [ ] SceneAntreMerlin cave variant (PENDING implementation)
- [ ] Biome color fix (PENDING implementation)
- [ ] Shared palette autoload (PENDING implementation)

---

*Art Direction Agent — M.E.R.L.I.N. Project*
*Full Visual Audit — 2026-02-08*
