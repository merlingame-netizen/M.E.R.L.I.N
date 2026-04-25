# Visual Design Specification: Transition Scenes (LEGACY)
## M.E.R.L.I.N. — Le Jeu des Oghams

> **LEGACY DOC** : Ce document reference les scenes `SceneEveil` et `SceneAntreMerlin` qui ont ete remplacees par `SceneRencontreMerlin` et `HubAntre`. Les specs visuelles (palettes, animations) restent valides mais les noms de scenes sont obsoletes. Source de verite : `docs/30_scenes/CANONICAL_ONBOARDING_FLOW.md`.

**Author:** Art Direction Agent
**Version:** 1.1 (updated 2026-02-22 — legacy banner)
**Date:** 2026-02-08

---

> *"Chaque transition est un seuil. Le joueur ne change pas de scene — il traverse une membrane."*

---

## TABLE OF CONTENTS

1. [Global Design Principles](#1-global-design-principles)
2. [Palette Reference (GBC + Parchment)](#2-palette-reference)
3. [Scene 1: SceneEveil — The Awakening](#3-scene-1-sceneeveil)
4. [Scene 2: SceneAntreMerlin — Merlin's Lair](#4-scene-2-sceneantreMerlin)
5. [Scene 3: TransitionBiome — The Journey](#5-scene-3-transitionbiome)
6. [Biome Color Mapping](#6-biome-color-mapping)
7. [Asset Needs Summary](#7-asset-needs-summary)
8. [Implementation Notes](#8-implementation-notes)

---

## 1. GLOBAL DESIGN PRINCIPLES

### Visual DNA

All three scenes share a unified visual language:

- **GBC aesthetic**: Limited palette, flat shading, pixel-informed but not pixel-art
- **Celtic mysticism**: Parchment textures, Celtic ornaments, Morris Roman typography
- **Merlin's emotional membrane**: Screen distortion reflects Merlin's connection state
- **The Exhaustion**: Beauty that subtly communicates decay — things are gorgeous but slightly wrong

### Motion Language

| Motion Type | Easing | Duration | Usage |
|------------|--------|----------|-------|
| Fade in | TRANS_SINE, EASE_OUT | 0.5-1.5s | Element appearance |
| Breathing | TRANS_SINE (looped) | 4-8s cycle | Ambient elements (mist, glow) |
| Typewriter | Linear, per-char | 25ms/char, 80ms/punct | Text reveal |
| Path drawing | TRANS_CUBIC, EASE_IN_OUT | 2-3s | Map transitions |
| Mood shift | TRANS_SINE, EASE_IN_OUT | 0.6s | ScreenEffects mood change |

### Typography Rules (All Scenes)

| Role | Font | Size | Color |
|------|------|------|-------|
| Scene title | MorrisRomanBlack | 48-56px | Parchment ink `Color(0.22, 0.18, 0.14)` |
| Merlin speech | MorrisRomanBlackAlt | 20-22px | Ink soft `Color(0.38, 0.32, 0.26)` |
| Merlin whisper | MorrisRomanBlackAlt | 16-18px | Ink faded `Color(0.50, 0.44, 0.38, 0.7)` |
| Labels/captions | MorrisRomanBlackAlt | 14px | Varies per biome |
| Celtic ornament | celtic-bit | 12-14px | Accent bronze `Color(0.58, 0.44, 0.26)` |

---

## 2. PALETTE REFERENCE

### GBC Palette Constants (from game_manager.gd PALETTE)

```gdscript
# Referenced as GameManager.PALETTE["key"]

# === BASE ===
"black":       Color("#181810")   # True black with warm undertone
"dark_gray":   Color("#484840")   # Deep shadow
"gray":        Color("#787870")   # Mid tone
"light_gray":  Color("#b8b0a0")   # Muted light
"cream":       Color("#f8f0d8")   # Warm cream
"white":       Color("#e8e8e8")   # Soft white

# === NATURE (Biome: Foret de Broceliande) ===
"grass_light": Color("#88d850")   # Bright canopy
"grass":       Color("#48a028")   # Core forest green
"grass_dark":  Color("#306018")   # Deep undergrowth

# === WATER (Biome: Cotes Sauvages) ===
"water_light": Color("#78c8f0")   # Surface shimmer
"water":       Color("#3888c8")   # Deep sea blue
"water_dark":  Color("#205898")   # Abyssal blue

# === FIRE (Ember, Forge, Candles) ===
"fire_light":  Color("#f8a850")   # Warm glow
"fire":        Color("#e07028")   # Flame orange
"fire_dark":   Color("#a04818")   # Burning coal

# === EARTH (Biome: Villages Celtes, Collines) ===
"earth_light": Color("#d0b080")   # Sandstone
"earth":       Color("#a08058")   # Warm earth
"earth_dark":  Color("#685030")   # Deep soil

# === MYSTIC/ARCANE (Crystals, Magic) ===
"mystic_light": Color("#c0a0e0")  # Crystal glow
"mystic":       Color("#8868b0")  # Arcane purple
"mystic_dark":  Color("#504078")  # Deep mystic

# === ICE (Biome accent: Winter) ===
"ice_light":   Color("#d0f0f8")   # Frost shimmer
"ice":         Color("#90d0e8")   # Clear ice
"ice_dark":    Color("#5898b8")   # Deep cold

# === SHADOW (Biome: Marais des Korrigans) ===
"shadow_light": Color("#686078")  # Twilight
"shadow":       Color("#403848")  # Deep shadow
"shadow_dark":  Color("#201820")  # Near void

# === LIGHT (Biome: Cercles de Pierres, Sacred) ===
"light_light": Color("#f8f8c0")   # Holy glow
"light":       Color("#f0e890")   # Sacred gold
"light_dark":  Color("#c8b858")   # Ancient gold

# === THUNDER ===
"thunder_light": Color("#f8f080") # Lightning flash
"thunder":       Color("#e8c830") # Electric gold
"thunder_dark":  Color("#a89020") # Storm amber
```

### Parchment Palette Constants (from MerlinVisual.PALETTE)

```gdscript
# Referenced as PALETTE["key"] in parchment-style scenes

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
"mist":         Color(0.94, 0.92, 0.88, 0.35)     # Brume bretonne
"celtic_gold":  Color(0.68, 0.55, 0.32)            # Or celtique
"celtic_brown": Color(0.45, 0.36, 0.28)            # Brun enluminure
```

---

## 3. SCENE 1: SceneEveil — "The Awakening"

### Concept

The very first thing the player sees when starting a new game. Pure darkness. A single ember awakens. Merlin's voice emerges from the void, letter by letter. Light gradually fills the screen as his connection establishes. This scene is the moment where an AI from the future reaches across time and touches the player for the first time.

**Duration:** 30-45 seconds
**ScreenEffects Mood Progression:** `mystique` -> `warm`
**Player Interaction:** None (cinematic). Tap to skip after 10 seconds.

### Color Palette

| Phase | Duration | Colors Used | Rationale |
|-------|----------|-------------|-----------|
| Phase 0: Void | 0-2s | `Color("#181810")` (black) only | Pure emptiness. Not RGB black -- warm black. |
| Phase 1: Ember | 2-8s | black + `Color("#e07028")` (fire) + `Color("#a04818")` (fire_dark) | A single point of orange warmth in the dark. |
| Phase 2: Glow | 8-20s | Add `Color("#f8a850")` (fire_light) + `Color("#685030")` (earth_dark) | The ember expands, shadows become visible. |
| Phase 3: Dawn | 20-35s | Transition to `Color("#f8f0d8")` (cream) + `Color("#d0b080")` (earth_light) | Full warmth. Parchment world fading in. |
| Phase 4: Arrival | 35-45s | Full parchment palette established | Scene transitions to SceneAntreMerlin. |

### Background Composition

```
+----------------------------------------------------------+
|                                                          |
|                    PURE BLACK                            |
|                                                          |
|                                                          |
|                   [EMBER]                                |
|              center-bottom third                         |
|              position: (0.5, 0.62)                       |
|              starts as 4px point                         |
|              grows to 64px radius glow                   |
|                                                          |
|                                                          |
|         [TYPEWRITER TEXT]                                |
|         center of screen                                 |
|         appears at Phase 2                               |
|         horizontal_alignment: CENTER                     |
|                                                          |
|                                                          |
|  [VIGNETTE: extreme, 0.45 intensity]                    |
|  Closes down to ember, opens as light grows             |
+----------------------------------------------------------+
```

### Lighting / Mood

**ScreenEffects Configuration:**

```gdscript
# Phase 1-2: Mystique mood (Merlin reaching across time)
ScreenEffects.set_merlin_mood("mystique")
# Mystique profile:
#   chromatic_intensity: 0.003
#   scanline_wobble_intensity: 0.0006
#   glitch_probability: 0.005
#   vignette_intensity: 0.14

# Phase 3-4: Warm mood (connection established)
ScreenEffects.set_merlin_mood("warm")
# Warm profile:
#   chromatic_intensity: 0.0004
#   scanline_wobble_intensity: 0.0002
#   glitch_probability: 0.002
#   vignette_intensity: 0.06
```

**Custom Vignette Override:**

The default vignette is not strong enough for this scene. Override the shader parameter directly:

```gdscript
# Start with extreme vignette (only ember visible)
ScreenEffects.set_parameter("vignette_intensity", 0.45)
ScreenEffects.set_parameter("vignette_softness", 0.25)

# Gradually open up over 30 seconds
var tween := create_tween()
tween.tween_method(
    func(val: float): ScreenEffects.set_parameter("vignette_intensity", val),
    0.45, 0.06, 30.0
).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
tween.parallel().tween_method(
    func(val: float): ScreenEffects.set_parameter("vignette_softness", val),
    0.25, 0.6, 30.0
).set_trans(Tween.TRANS_SINE)
```

### Particle Effects

#### EmberParticle (GPUParticles2D)

| Property | Value | Notes |
|----------|-------|-------|
| amount | 8 | Very sparse |
| lifetime | 3.0s | Slow drift |
| emission_shape | SPHERE, radius 4px -> 32px | Grows with ember |
| direction | Vector2(0, -1) | Upward drift |
| spread | 35 degrees | Slight scatter |
| initial_velocity | 8-15 px/s | Very slow |
| gravity | Vector2(0, -5) | Float upward |
| color | Gradient: `fire` -> `fire_light` -> transparent | Orange fading out |
| scale_min / scale_max | 1.0 / 3.0 | Tiny sparks |
| modulate | Start `Color(1,1,1,0)`, fade to `Color(1,1,1,1)` over 2s | |

#### DustMotes (GPUParticles2D) -- Phase 3+

| Property | Value | Notes |
|----------|-------|-------|
| amount | 12 | |
| lifetime | 5.0s | |
| emission_shape | RECT, full screen | |
| initial_velocity | 2-4 px/s | Barely moving |
| scale_min / scale_max | 0.5 / 1.5 | |
| color | `Color("#f8f0d8")` at 10% alpha | Cream dust |

### Animation Keyframes

```
TIMELINE (seconds)
|=====|=====|=====|=====|=====|=====|=====|=====|=====|
0     5     10    15    20    25    30    35    40    45

[BACKGROUND]
0.0s:  Pure black Color("#181810")
2.0s:  Begin radial gradient from ember center (fire_dark -> black)
8.0s:  Gradient radius = 15% of screen
15.0s: Gradient radius = 40% of screen
25.0s: Gradient transitions to full cream (paper shader begins)
35.0s: merlin_paper.gdshader fully active with parchment tint

[EMBER (ColorRect + shader or Sprite2D)]
0.0s:  Invisible
1.5s:  Fade in, 4px radius, Color("#a04818"), alpha 0.0 -> 0.6 (0.8s)
3.0s:  Pulse begins: scale 1.0 <-> 1.15, period 2.5s
5.0s:  Radius grows to 16px, color shifts to Color("#e07028")
10.0s: Radius grows to 32px, glow halo appears (fire_light, 50% alpha)
20.0s: Ember dissolves into general warm light
25.0s: Ember fully dissolved

[EMBER PARTICLES]
2.0s:  Start emitting (amount: 2)
5.0s:  amount increases to 4
10.0s: amount increases to 8
20.0s: Particles transition to dust motes
25.0s: Ember particles stop, dust motes continue

[TYPEWRITER TEXT — Merlin's first words]
4.0s:  First line begins: "..."
5.5s:  Second line: "Tu m'entends?"
8.0s:  Pause (1.5s)
9.5s:  "C'est... etrange."
12.0s: "Apres tout ce temps..."
15.0s: Pause (2.0s)
17.0s: "Je suis Merlin."
20.0s: "Et le monde a besoin de toi."
24.0s: Pause (1.5s)
25.5s: "Viens. Il y a tant a voir."
28.0s: "Avant qu'il ne soit trop tard."
32.0s: Text fades out (1.5s)

[TYPEWRITER PARAMETERS]
char_delay:  0.025s (TYPEWRITER_DELAY from IntroMerlinDialogue)
punct_delay: 0.08s  (TYPEWRITER_PUNCT_DELAY)
blip_freq:   880.0  (BLIP_FREQ)
blip_volume: 0.04   (BLIP_VOLUME)
font:        MorrisRomanBlackAlt, 20px
color:       Start Color("#f8a850") (fire_light), transition to Color(0.38, 0.32, 0.26) (ink_soft) at Phase 3

[SCREENEFFECTS MOOD]
0.0s:  ScreenEffects.set_merlin_mood("mystique")
17.0s: ScreenEffects.set_merlin_mood("warm")  # After "Je suis Merlin"

[NARRATIVE SHOCK — At "Je suis Merlin"]
17.0s: ScreenEffects.narrative_shock(0.3)  # Brief distortion spike

[VIGNETTE OVERRIDE]
0.0s:  vignette_intensity = 0.45, vignette_softness = 0.25
0.0s-30.0s: Tween to vignette_intensity = 0.06, softness = 0.6 (EXPO ease)

[SKIP INDICATOR]
10.0s: Small text appears bottom-center: "Toucher pour passer"
       Font: MorrisRomanBlackAlt, 12px
       Color: Color(0.50, 0.44, 0.38, 0.25)  (ink_faded, more transparent)
       Fade in over 1.0s
```

### Scene Transition Out

When SceneEveil ends (at ~35-40s or on tap after 10s):

```gdscript
# Fade to warm white/cream, then load SceneAntreMerlin
var exit_tween := create_tween()
exit_tween.tween_property(fade_overlay, "color:a", 1.0, 1.5)
exit_tween.set_trans(Tween.TRANS_SINE)
# fade_overlay.color = Color("#f8f0d8")  # Cream, not white
await exit_tween.finished
get_tree().change_scene_to_file("res://scenes/SceneAntreMerlin.tscn")
```

---

## 4. SCENE 2: SceneAntreMerlin — "Merlin's Lair"

### Concept

Merlin's personal sanctuary. A cave/grotto illuminated by crystals and candles. This is the hub scene the player returns to between runs. It must feel cozy yet ancient, lived-in yet eternal. Merlin's portrait dominates one side. Bestiole floats nearby as a luminous creature. A parchment map of the 7 biomes occupies the central space.

**ScreenEffects Mood:** `sage` (default, calm) with shifts to `pensif` or `amuse` based on dialogue
**Player Interaction:** Tap on map biomes, interact with Merlin, pet Bestiole

### Color Palette

The Lair uses a restricted subset to create a warm, enclosed feel:

| Element | Primary Color | Secondary | Accent |
|---------|--------------|-----------|--------|
| Cave walls | `Color("#484840")` (dark_gray) | `Color("#685030")` (earth_dark) | -- |
| Cave floor | `Color("#685030")` (earth_dark) | `Color("#a08058")` (earth) | -- |
| Candle light | `Color("#f8a850")` (fire_light) | `Color("#e07028")` (fire) | -- |
| Crystal glow | `Color("#c0a0e0")` (mystic_light) | `Color("#8868b0")` (mystic) | `Color("#504078")` (mystic_dark) |
| Parchment map | `Color(0.965, 0.945, 0.905)` (paper) | `Color(0.935, 0.905, 0.855)` (paper_dark) | -- |
| Map ink | `Color(0.22, 0.18, 0.14)` (ink) | `Color(0.38, 0.32, 0.26)` (ink_soft) | -- |
| Merlin portrait bg | `Color("#a08058")` (earth) | `Color("#d0b080")` (earth_light) | `Color(0.58, 0.44, 0.26)` (accent/bronze) |
| Bestiole glow | `Color("#88d850")` (grass_light) | `Color("#f0e890")` (light) | `Color("#f8f8c0")` (light_light) |
| Scrolls/runes | `Color(0.68, 0.55, 0.32)` (celtic_gold) | `Color(0.45, 0.36, 0.28)` (celtic_brown) | -- |
| Ambient shadow | `Color("#201820")` (shadow_dark) | `Color("#403848")` (shadow) | -- |

### Background Composition

```
+----------------------------------------------------------+
|  [CAVE CEILING]  dark_gray with stalactite silhouettes   |
|   scattered crystal points (mystic_light, 30% alpha)     |
|_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _|
|                                                          |
|  [MERLIN PORTRAIT]    |    [PARCHMENT MAP]               |
|  Left 25% of screen   |    Center 50%                    |
|  Position: (0.12, 0.3)|    Position: (0.3, 0.15)         |
|  Size: ~200x280px     |    Size: ~480x400px              |
|  Seasonal variant     |    Hand-drawn 7 biomes           |
|  Ornate bronze frame  |    Celtic border                 |
|  Asset: Merlin_*.png  |    Scrolled parchment feel       |
|                       |                                   |
|  [CANDLE]  [CANDLE]   |    [BIOME DOTS with color]       |
|  (flickering light)   |    (see biome map section)        |
|                       |                                   |
|  [SCROLLS/RUNES]      |                                   |
|  Desk area below      |              [BESTIOLE]           |
|  portrait             |              Floating right        |
|                       |              Position: (0.82, 0.4) |
|_ _ _ _ _ _ _ _ _ _ _ _|_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _|
|  [DESK SURFACE]  earth_dark with scattered items         |
|  Celtic ornament line at bottom                          |
+----------------------------------------------------------+
```

### Element Specifications

#### 4.1 Cave Background (ColorRect + Shader)

```gdscript
# Use merlin_paper.gdshader with dark cave tinting
var cave_shader := load("res://shaders/merlin_paper.gdshader")
var cave_mat := ShaderMaterial.new()
cave_mat.shader = cave_shader
cave_mat.set_shader_parameter("paper_tint", Color("#484840"))     # dark_gray
cave_mat.set_shader_parameter("grain_strength", 0.04)             # More visible grain
cave_mat.set_shader_parameter("vignette_strength", 0.20)          # Stronger vignette = cave feel
cave_mat.set_shader_parameter("vignette_softness", 0.40)          # Tighter vignette
cave_mat.set_shader_parameter("grain_scale", 600.0)               # Coarser grain = rock texture
cave_mat.set_shader_parameter("grain_speed", 0.03)                # Nearly static
cave_mat.set_shader_parameter("warp_strength", 0.0005)            # Barely moving
```

#### 4.2 Merlin Portrait

| Property | Value |
|----------|-------|
| Texture | `res://Assets/Sprite/Merlin_[SEASON].png` (seasonal) |
| Size | 192x256px display size |
| Position | Left side, vertically centered (x: 12%, y: 30%) |
| Frame | 2px border, `Color(0.58, 0.44, 0.26)` (bronze accent) |
| Frame corners | 4px radius |
| Shadow | 12px blur, `Color(0.25, 0.20, 0.16, 0.3)` |
| Animation | Subtle breathing: scale 1.0 <-> 1.005, period 4s, TRANS_SINE |
| Candle flicker effect | Modulate oscillates: Color(1.0, 0.98, 0.92) <-> Color(1.0, 0.95, 0.85), period 2.5s irregular |

#### 4.3 Parchment Map (Central Element)

The map is the most complex visual element. It shows 7 biomes connected by paths.

```
MAP LAYOUT (within parchment panel):

         [Collines aux Dolmens]
              (7)
             /    \
    [Cercles de    \
     Pierres (5)]   \
        |            \
    [Foret de    [Landes de
     Broceliande   Bruyere (2)]
        (1)]         |
        |        [Marais des
    [Villages     Korrigans (6)]
     Celtes (4)]     |
         \          /
      [Cotes Sauvages (3)]
```

**Map Container:**

| Property | Value |
|----------|-------|
| Type | PanelContainer |
| Size | 480 x 400 px |
| Background | `Color(0.955, 0.930, 0.890)` (paper_warm) with reigns_paper shader |
| Border | 1px `Color(0.50, 0.44, 0.38, 0.35)` (ink_faded) |
| Corner radius | 6px |
| Shadow | 16px, `Color(0.25, 0.20, 0.16, 0.18)` |
| Title text | "Les Sept Sanctuaires", MorrisRomanBlack, 18px, `Color(0.22, 0.18, 0.14)` |
| Celtic border | Unicode ornament line (same pattern as MenuPrincipalReigns) |

**Biome Nodes on Map:**

Each biome is represented by a circular dot with its unique color, connected by drawn path lines.

| Biome | Map Position (normalized within map) | Dot Color (GBC Palette) | Dot Size | Label |
|-------|--------------------------------------|------------------------|----------|-------|
| 1. Foret de Broceliande | (0.30, 0.45) | `Color("#48a028")` (grass) | 16px diameter | "Broceliande" |
| 2. Landes de Bruyere | (0.70, 0.35) | `Color("#8868b0")` (mystic) | 14px | "Landes" |
| 3. Cotes Sauvages | (0.50, 0.85) | `Color("#3888c8")` (water) | 14px | "Cotes" |
| 4. Villages Celtes | (0.25, 0.70) | `Color("#a08058")` (earth) | 14px | "Villages" |
| 5. Cercles de Pierres | (0.20, 0.25) | `Color("#f0e890")` (light) | 14px | "Cercles" |
| 6. Marais des Korrigans | (0.75, 0.60) | `Color("#403848")` (shadow) | 14px | "Marais" |
| 7. Collines aux Dolmens | (0.48, 0.10) | `Color("#685030")` (earth_dark) | 14px | "Collines" |

**Biome Dot Styling:**

```gdscript
# Each dot is a colored circle with a soft outer glow
# Active biome: full opacity, pulsing glow
# Locked biome: 40% opacity, no glow, "?" label
# Current biome: ring highlight (celtic_gold)

func _create_biome_dot(biome_color: Color, is_active: bool, is_current: bool) -> Control:
    # Outer glow: biome_color at 20% alpha, 24px diameter
    # Inner dot: biome_color at 100%, 14px diameter
    # If is_current: add ring Color(0.68, 0.55, 0.32) (celtic_gold), 2px, 20px diameter
    # If not is_active: modulate.a = 0.4, no glow
    pass
```

**Path Lines Between Biomes:**

```gdscript
# Paths drawn as Line2D with dashed/dotted style
# Color: Color(0.50, 0.44, 0.38, 0.25) (ink_faded, very subtle)
# Width: 1.5px
# Style: Dashed (segments of 6px visible, 4px gap)
# Active paths: Color(0.45, 0.36, 0.28) (celtic_brown), 2px
```

#### 4.4 Bestiole (Floating Companion)

| Property | Value |
|----------|-------|
| Position | Right side (x: 82%, y: 40%) |
| Base size | 48x48 px |
| Core color | `Color("#88d850")` (grass_light) |
| Glow color | `Color("#f8f8c0")` (light_light) at 30% alpha |
| Animation | Float: Y oscillation +/- 6px, period 3.5s, TRANS_SINE |
| | Breathe: scale 1.0 <-> 1.08, period 2.8s, TRANS_SINE |
| | Rotate: subtle +/- 3 degrees, period 5s |
| Interaction | On tap: squish shader (bestiole_squish.gdshader), emit heart particles |

**Bestiole Particle Aura (GPUParticles2D):**

| Property | Value |
|----------|-------|
| amount | 6 |
| lifetime | 2.5s |
| emission_shape | SPHERE, radius 24px |
| direction | Vector2(0, -0.5) |
| spread | 180 degrees |
| initial_velocity | 3-8 px/s |
| gravity | Vector2(0, -2) |
| color | Gradient: `grass_light` 40% -> `light_light` 20% -> transparent |
| scale_min / scale_max | 0.5 / 2.0 |
| Draw order | Behind Bestiole sprite |

#### 4.5 Candle Lights (x2-3)

| Property | Value |
|----------|-------|
| Positions | Near Merlin portrait and on desk |
| Flame color | `Color("#f8a850")` (fire_light) core, `Color("#e07028")` (fire) halo |
| Flame size | 8x12px core |
| Halo | Radial gradient, 64px radius, 15% opacity |
| Animation | Flicker: random scale 0.85 <-> 1.1, randomized timing 0.2-0.5s intervals |
| | Halo: modulate.a oscillates 0.10 <-> 0.18, period 1.5-3s (random per candle) |
| Light2D | PointLight2D, `Color("#f8a850")`, energy 0.15, texture_scale 2.0 |

#### 4.6 Crystal Points (ceiling, x4-6)

| Property | Value |
|----------|-------|
| Colors | Alternate between `Color("#c0a0e0")` (mystic_light) and `Color("#90d0e8")` (ice) |
| Size | 4-8px |
| Glow | Radial, 16px radius, 20% alpha |
| Animation | Twinkle: alpha oscillates 0.15 <-> 0.35, staggered timing, period 4-7s each |

#### 4.7 Desk / Scrolls / Runes (Bottom Area)

| Element | Visual |
|---------|--------|
| Desk surface | Horizontal band, `Color("#685030")` (earth_dark), bottom 20% of screen |
| Scrolls | 2-3 small scroll sprites (parchment color), slightly rotated, scattered |
| Rune circles | Small Celtic ornaments in `Color(0.68, 0.55, 0.32)` (celtic_gold), 10px |
| Candle base | Small rectangle, `Color("#a08058")` (earth) |

### Lighting / Mood

**ScreenEffects Configuration:**

```gdscript
# Default state: Sage (calm, clear connection)
ScreenEffects.set_merlin_mood("sage")
# sage profile:
#   chromatic_intensity: 0.0005
#   scanline_wobble_intensity: 0.0002
#   glitch_probability: 0.003
#   vignette_intensity: 0.08

# During Merlin dialogue: shift based on ToneController
# Example:
# "WARM" dialogue -> ScreenEffects.set_mood_from_tone("WARM")
# "MYSTERIOUS" dialogue -> ScreenEffects.set_mood_from_tone("MYSTERIOUS")
```

### Animation Keyframes (Entry)

```
TIMELINE (seconds) — Scene entry after SceneEveil or returning from biome

[CAVE BACKGROUND]
0.0s:  Visible immediately (already faded in from previous scene)

[CANDLES]
0.0s:  Start flickering (immediate, looped)

[CRYSTALS]
0.5s:  Fade in staggered, 0.3s per crystal, left to right

[MERLIN PORTRAIT]
0.8s:  Slide in from left (-20px offset), fade in over 0.6s, EASE_OUT

[MAP]
1.2s:  Fade in from center, slight scale 0.95 -> 1.0, over 0.8s

[BIOME DOTS]
1.6s:  Pop in one by one, 0.15s intervals, scale 0 -> 1.0 with bounce

[BESTIOLE]
2.0s:  Float in from right edge, settle into hover position over 1.0s
2.5s:  Particle aura begins

[DESK ITEMS]
1.0s:  Fade in simultaneously, 0.5s duration

[CELTIC ORNAMENT BORDERS]
2.5s:  Draw in from center outward (top and bottom), 0.6s
```

---

## 5. SCENE 3: TransitionBiome — "The Journey"

### Concept

Plays when the player selects a biome from the map in SceneAntreMerlin. The camera zooms into the selected biome dot on the map, the parchment map fills the screen, and a path draws itself from the current position to the destination. Mist swirls between biomes. The color palette gradually transitions to match the destination.

**Duration:** 4-6 seconds
**ScreenEffects Mood:** Starts with current mood, transitions to `mystique` during travel, then to biome-appropriate mood on arrival
**Player Interaction:** None (cinematic)

### Color Palette

The TransitionBiome scene is unique because its palette CHANGES based on origin and destination biomes.

**Constants (always present):**

| Element | Color |
|---------|-------|
| Map parchment | `Color(0.955, 0.930, 0.890)` (paper_warm) |
| Path ink (traveled) | `Color(0.22, 0.18, 0.14)` (ink) |
| Path ink (drawing) | `Color(0.58, 0.44, 0.26)` (bronze accent) |
| Mist/fog | `Color(0.94, 0.92, 0.88, 0.5)` (mist, more opaque) |
| Celtic border | `Color(0.45, 0.36, 0.28)` (celtic_brown) |

**Dynamic palette per destination** — see Section 6 (Biome Color Mapping) for full table.

### Background Composition

```
PHASE 1: Zoom In (0-1.5s)
+----------------------------------------------------------+
|                                                          |
|         Map zooms from scene overview                    |
|         to fill the entire screen                        |
|         Center on the PATH between                       |
|         origin biome and destination                     |
|                                                          |
|         Camera zoom: 1.0 -> 2.5x over 1.5s              |
|         Camera pan to path midpoint                      |
|                                                          |
+----------------------------------------------------------+

PHASE 2: Path Drawing (1.5-3.5s)
+----------------------------------------------------------+
|                                                          |
|    [ORIGIN DOT]                                          |
|    (current biome color)                                 |
|         \                                                |
|          \ --- path draws itself ---                     |
|           \       with ink trail                         |
|            \     and bronze glow                         |
|             \                                            |
|              \   [MIST PATCHES]                          |
|               \  swirling between                        |
|                \                                         |
|                 \                                        |
|           [DESTINATION DOT]                              |
|           (pulsing, destination color)                   |
|                                                          |
+----------------------------------------------------------+

PHASE 3: Arrival (3.5-5.5s)
+----------------------------------------------------------+
|                                                          |
|    Full screen fades to destination biome colors         |
|    Mist clears from center outward                       |
|    Destination dot expands to fill screen                |
|    Color palette transitions complete                    |
|                                                          |
+----------------------------------------------------------+
```

### Path Drawing Animation

```gdscript
# Path is a Line2D that draws progressively
# Points are pre-calculated between origin and destination biome positions
# The line uses a custom draw method that reveals points over time

# Path visual properties:
var path_line := Line2D.new()
path_line.width = 3.0
path_line.default_color = Color(0.22, 0.18, 0.14)          # ink
path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
path_line.antialiased = true

# Glow trail behind the drawing point:
var trail_glow := Line2D.new()
trail_glow.width = 8.0
trail_glow.default_color = Color(0.58, 0.44, 0.26, 0.3)  # bronze accent, transparent
# Trail fades behind the leading edge
```

### Particle Effects

#### MistParticles (GPUParticles2D)

| Property | Value | Notes |
|----------|-------|-------|
| amount | 24 | Dense fog |
| lifetime | 4.0s | |
| emission_shape | RECT, covers path area | |
| direction | Vector2(1, 0.3) | Drifting east-ish |
| spread | 45 degrees | |
| initial_velocity | 10-25 px/s | Slow drift |
| gravity | Vector2(0, 0) | No gravity |
| scale_min / scale_max | 4.0 / 12.0 | Large, soft blobs |
| color | `Color(0.94, 0.92, 0.88, 0.3)` -> transparent | Mist color |
| Animation | Clears during Phase 3 (modulate.a -> 0 over 1.5s) | |

#### PathSparkles (GPUParticles2D) — follows drawing point

| Property | Value |
|----------|-------|
| amount | 4 |
| lifetime | 0.8s |
| emission_shape | POINT (follows path head) |
| spread | 360 degrees |
| initial_velocity | 15-30 px/s |
| scale_min / scale_max | 0.5 / 2.0 |
| color | Destination biome color at 60% -> transparent |

### Animation Keyframes

```
TIMELINE (seconds) — After player taps a biome on the map

[PHASE 1: ZOOM IN]
0.0s:  Camera begins zooming: scale 1.0 -> 2.5, duration 1.5s, EASE_IN_OUT
0.0s:  Camera pans to midpoint of origin-destination path
0.0s:  ScreenEffects.set_merlin_mood("mystique")
0.3s:  Non-involved biome dots fade to 15% alpha (0.5s duration)
0.5s:  Mist particles begin emitting
0.8s:  Origin dot pulses once (scale 1.0 -> 1.3 -> 1.0, 0.4s)

[PHASE 2: PATH DRAWING]
1.5s:  Path line begins drawing from origin dot
       Speed: ~120px/s (adjust for distance)
       Duration: 2.0s for any path
1.5s:  PathSparkles particle follows line head
1.5s:  Bronze glow trail follows 0.3s behind line head
2.0s:  Background parchment tint starts shifting:
       paper_warm -> lerp toward destination biome light color (20% mix)
2.5s:  Mist density peaks (amount modulator: 1.0 -> 1.5)

[PHASE 3: ARRIVAL]
3.5s:  Path completes, destination dot reached
3.5s:  Destination dot pulses large (scale 1.0 -> 2.0, 0.3s)
3.5s:  ScreenEffects.narrative_shock(0.2)  # Brief distortion on arrival
3.7s:  Mist begins clearing (modulate.a -> 0, 1.5s, from center out)
3.7s:  Color palette transition accelerates:
       Background -> destination biome dominant color (full)
4.0s:  Destination dot expands as circle wipe (fills screen)
4.5s:  ScreenEffects.set_merlin_mood([destination_mood])
5.5s:  Scene change to destination biome scene

[PALETTE TRANSITION]
# The background color lerps from parchment to destination biome:
var dest_color: Color = BIOME_COLORS[destination]["dominant"]
var tween := create_tween()
tween.tween_method(
    _set_bg_tint,
    Color(0.955, 0.930, 0.890),   # paper_warm
    dest_color,
    3.0
).set_trans(Tween.TRANS_SINE)
```

### ScreenEffects Mood per Destination

| Destination Biome | ScreenEffects Mood | Rationale |
|-------------------|-------------------|-----------|
| Foret de Broceliande | `sage` | Calm, stable, the heart |
| Landes de Bruyere | `pensif` | Melancholy, vast, wind |
| Cotes Sauvages | `warm` | Open, generous, sea |
| Villages Celtes | `warm` | Human warmth |
| Cercles de Pierres | `mystique` | Sacred, arcane |
| Marais des Korrigans | `cryptic` | Dangerous, hidden |
| Collines aux Dolmens | `pensif` | Ancient, nostalgic |

---

## 6. BIOME COLOR MAPPING

### Complete Biome-to-Palette Table

Each biome maps to a set of GBC palette colors used for its map dot, transitions, and in-game scenes.

```gdscript
const BIOME_COLORS := {
    "broceliande": {
        # La Foret — Le Coeur Qui Bat Encore
        "dominant":    Color("#48a028"),    # grass
        "light":       Color("#88d850"),    # grass_light
        "dark":        Color("#306018"),    # grass_dark
        "accent":      Color("#685030"),    # earth_dark (tree trunks)
        "atmosphere":  Color("#f8f0d8"),    # cream (filtered sunlight)
        "mist":        Color("#88d850", 0.15),  # green-tinted mist
        "map_dot":     Color("#48a028"),    # grass
        "mood":        "sage",
        "ogham":       "duir",
        "season_peak": "AUTOMNE",
    },
    "landes": {
        # Les Landes de Bruyere — Le Souffle Qui S'Essouffle
        "dominant":    Color("#8868b0"),    # mystic (heather purple)
        "light":       Color("#c0a0e0"),    # mystic_light
        "dark":        Color("#504078"),    # mystic_dark
        "accent":      Color("#a08058"),    # earth (granite)
        "atmosphere":  Color("#b8b0a0"),    # light_gray (overcast sky)
        "mist":        Color("#c0a0e0", 0.12),  # purple-tinted mist
        "map_dot":     Color("#8868b0"),    # mystic
        "mood":        "pensif",
        "ogham":       "onn",
        "season_peak": "HIVER",
    },
    "cotes": {
        # Les Cotes Sauvages — La Mer Qui Se Retire
        "dominant":    Color("#3888c8"),    # water
        "light":       Color("#78c8f0"),    # water_light
        "dark":        Color("#205898"),    # water_dark
        "accent":      Color("#484840"),    # dark_gray (granite cliffs)
        "atmosphere":  Color("#d0f0f8"),    # ice_light (sea spray)
        "mist":        Color("#78c8f0", 0.18),  # blue-tinted mist
        "map_dot":     Color("#3888c8"),    # water
        "mood":        "warm",
        "ogham":       "nuin",
        "season_peak": "ETE",
    },
    "villages": {
        # Les Villages Celtes — La Derniere Chaleur
        "dominant":    Color("#a08058"),    # earth
        "light":       Color("#d0b080"),    # earth_light
        "dark":        Color("#685030"),    # earth_dark
        "accent":      Color("#e07028"),    # fire (hearth fire)
        "atmosphere":  Color("#f8f0d8"),    # cream (warm indoor light)
        "mist":        Color("#d0b080", 0.10),  # warm earth-tinted mist
        "map_dot":     Color("#a08058"),    # earth
        "mood":        "warm",
        "ogham":       "gort",
        "season_peak": "PRINTEMPS",
    },
    "cercles": {
        # Les Cercles de Pierres — Le Temps Qui Hesite
        "dominant":    Color("#f0e890"),    # light (sacred glow)
        "light":       Color("#f8f8c0"),    # light_light
        "dark":        Color("#c8b858"),    # light_dark
        "accent":      Color("#787870"),    # gray (granite stones)
        "atmosphere":  Color("#e8e8e8"),    # white (vast sky)
        "mist":        Color("#f0e890", 0.10),  # gold-tinted mist
        "map_dot":     Color("#f0e890"),    # light
        "mood":        "mystique",
        "ogham":       "huath",
        "season_peak": "SAMHAIN",
    },
    "marais": {
        # Les Marais des Korrigans — Ce Qui Attend en Dessous
        "dominant":    Color("#403848"),    # shadow
        "light":       Color("#686078"),    # shadow_light
        "dark":        Color("#201820"),    # shadow_dark
        "accent":      Color("#88d850"),    # grass_light (will-o-wisps)
        "atmosphere":  Color("#484840"),    # dark_gray (perpetual twilight)
        "mist":        Color("#403848", 0.25),  # dark mist, thicker
        "map_dot":     Color("#403848"),    # shadow
        "mood":        "cryptic",
        "ogham":       "muin",
        "season_peak": "LUGHNASADH",
    },
    "collines": {
        # Les Collines aux Dolmens — La Memoire Qui S'Effrite
        "dominant":    Color("#685030"),    # earth_dark
        "light":       Color("#a08058"),    # earth
        "dark":        Color("#484840"),    # dark_gray
        "accent":      Color("#c8b858"),    # light_dark (ancient gold)
        "atmosphere":  Color("#b8b0a0"),    # light_gray (vast open sky)
        "mist":        Color("#685030", 0.12),  # brown-tinted mist
        "map_dot":     Color("#685030"),    # earth_dark
        "mood":        "pensif",
        "ogham":       "ioho",
        "season_peak": "YULE",
    },
}
```

### Biome Map Visual Reference

```
Biome Map Color Key (for dot and path coloring):

    [7] COLLINES        earth_dark    ████  #685030
         |
    [5] CERCLES         light         ████  #f0e890
    [2] LANDES          mystic        ████  #8868b0
         |               |
    [1] BROCELIANDE     grass         ████  #48a028
    [6] MARAIS          shadow        ████  #403848
         |               |
    [4] VILLAGES        earth         ████  #a08058
         |
    [3] COTES           water         ████  #3888c8
```

### Path Colors Between Biomes

When a path connects two biomes, the path line uses a gradient from origin color to destination color:

```gdscript
# Path gradient calculation
func _get_path_gradient(origin: String, destination: String) -> Gradient:
    var grad := Gradient.new()
    grad.set_color(0, BIOME_COLORS[origin]["dominant"])
    grad.set_color(1, BIOME_COLORS[destination]["dominant"])
    return grad
```

---

## 7. ASSET NEEDS SUMMARY

### New Assets Required

| Asset | Type | Size | Priority | Notes |
|-------|------|------|----------|-------|
| `ember_glow.png` | Sprite | 64x64 | HIGH | Radial gradient, orange-to-transparent, for SceneEveil ember |
| `crystal_point.png` | Sprite | 16x16 | MEDIUM | Small crystal shape, semi-transparent, for cave ceiling |
| `candle_flame.png` | Sprite sheet | 32x48 (4 frames) | MEDIUM | Simple animated flame, 4-frame loop |
| `candle_base.png` | Sprite | 16x32 | LOW | Simple candle holder |
| `scroll_small.png` | Sprite | 48x24 | LOW | Rolled scroll, parchment color |
| `rune_circle.png` | Sprite | 24x24 | LOW | Celtic knot pattern, gold |
| `biome_map_bg.png` | Texture | 480x400 | HIGH | Hand-drawn parchment map background with coastline hints |
| `mist_blob.png` | Particle texture | 64x64 | HIGH | Soft white blob for mist particles |
| `spark_dot.png` | Particle texture | 8x8 | MEDIUM | Small bright dot for ember/path sparkles |
| `path_dash.png` | Texture | 16x4 | MEDIUM | Dashed line segment for map paths |

### Existing Assets Used

| Asset | Path | Usage |
|-------|------|-------|
| Merlin Portrait | `res://Assets/Sprite/Merlin.png` | Default portrait in lair |
| Merlin Seasonal | `res://Assets/Sprite/Merlin_HIVER.png` etc. | Seasonal variants |
| Paper Shader | `res://shaders/merlin_paper.gdshader` | Parchment backgrounds |
| Screen Distortion | `res://shaders/screen_distortion.gdshader` | ScreenEffects mood system |
| Bestiole Squish | `res://shaders/bestiole_squish.gdshader` | Bestiole tap interaction |
| Morris Roman | `res://resources/fonts/morris/MorrisRomanBlack.otf` | Title text |
| Morris Roman Alt | `res://resources/fonts/morris/MorrisRomanBlackAlt.otf` | Body/dialogue text |
| Celtic Bit | `res://resources/fonts/celtic_bit/celtic-bit.ttf` | Ornamental characters |

### Shaders to Create

| Shader | Purpose | Priority |
|--------|---------|----------|
| `ember_glow.gdshader` | Pulsing radial glow for the awakening ember | HIGH |
| `path_draw.gdshader` | Progressive line reveal with glow trail | MEDIUM |
| `circle_wipe.gdshader` | Expanding circle transition (biome dot -> fullscreen) | MEDIUM |

---

## 8. IMPLEMENTATION NOTES

### Scene Node Tree Recommendations

#### SceneEveil.tscn
```
Control (SceneEveil.gd)
  +-- ColorRect (background, black)
  +-- ColorRect (radial_gradient, for light spread)
  +-- Sprite2D (ember_sprite)
  +-- GPUParticles2D (ember_particles)
  +-- GPUParticles2D (dust_motes)
  +-- Label (typewriter_text)
  +-- Label (skip_hint)
  +-- ColorRect (fade_overlay)
```

#### SceneAntreMerlin.tscn
```
Control (SceneAntreMerlin.gd)
  +-- ColorRect (cave_background, with shader)
  +-- Node2D (crystal_layer)
  |     +-- Sprite2D x4-6 (crystal points)
  +-- TextureRect (merlin_portrait)
  +-- Node2D (candle_layer)
  |     +-- Node2D (candle_1)
  |     |     +-- Sprite2D (flame)
  |     |     +-- PointLight2D (light)
  |     +-- Node2D (candle_2)
  |           +-- Sprite2D (flame)
  |           +-- PointLight2D (light)
  +-- PanelContainer (map_panel)
  |     +-- Control (map_content)
  |           +-- Label (map_title)
  |           +-- Node2D (biome_dots_layer)
  |           |     +-- Control x7 (biome_dot_N)
  |           +-- Node2D (paths_layer)
  |                 +-- Line2D x7 (path_N)
  +-- Node2D (bestiole)
  |     +-- Sprite2D (bestiole_sprite)
  |     +-- GPUParticles2D (bestiole_aura)
  +-- Node2D (desk_layer)
  |     +-- ColorRect (desk_surface)
  |     +-- Sprite2D x3 (scrolls)
  |     +-- Sprite2D x2 (rune_circles)
  +-- Label (celtic_ornament_top)
  +-- Label (celtic_ornament_bottom)
```

#### TransitionBiome.tscn
```
Control (TransitionBiome.gd)
  +-- ColorRect (map_background, with paper shader)
  +-- Node2D (map_zoomed)
  |     +-- Node2D (biome_dots_layer)
  |     +-- Line2D (path_traveled)
  |     +-- Line2D (path_drawing)
  |     +-- GPUParticles2D (path_sparkles)
  +-- GPUParticles2D (mist_particles)
  +-- ColorRect (circle_wipe_overlay)
  +-- ColorRect (color_transition_overlay)
```

### Performance Considerations

- **Particle count:** Keep total particles under 50 per scene (mobile target)
- **Shader complexity:** merlin_paper.gdshader is already optimized; reuse it for cave bg
- **Tween management:** Always kill previous tweens before creating new ones (pattern from MenuPrincipalReigns)
- **Texture sizes:** All new textures should be power-of-2 and under 256x256
- **ScreenEffects:** Mood transitions use MOOD_TRANSITION_DURATION (0.6s) -- do not fight this timing

### Audio Integration Points

| Moment | Sound | Source |
|--------|-------|--------|
| SceneEveil: ember appears | Soft crackle | New SFX needed |
| SceneEveil: typewriter | Letter blip (880Hz) | Existing: BLIP_FREQ from IntroMerlinDialogue |
| SceneEveil: "Je suis Merlin" | Brief resonant tone | New SFX needed |
| AntreMerlin: ambient | Cave ambience loop | New SFX needed |
| AntreMerlin: candle | Soft crackle (very low) | New SFX needed |
| AntreMerlin: biome tap | UI click | Existing: `res://audio/sfx/ui/ui_click.ogg` |
| AntreMerlin: Bestiole tap | Soft chirp | New SFX needed |
| TransitionBiome: path draw | Ink scratching / quill | New SFX needed |
| TransitionBiome: arrival | Whoosh + biome ambient fade-in | Existing whoosh: `res://audio/sfx/ui/card_swipe.ogg` |

---

## STYLE CHECK

- [x] Color palette compliance (all colors from GBC PALETTE or Parchment PALETTE)
- [x] Typography correct (MorrisRomanBlack, MorrisRomanBlackAlt, celtic-bit)
- [x] Consistent with existing assets (parchment style from MenuPrincipalReigns)
- [x] ScreenEffects mood profiles used correctly
- [x] Celtic ornament language maintained
- [x] GBC aesthetic respected (limited palette, flat shading)
- [x] Merlin's emotional membrane concept maintained through mood system
- [x] Biome lore reflected in color choices (matched to 08_LES_BIOMES.md)

---

*Art Direction Agent — M.E.R.L.I.N. Project*
*Document generated: 2026-02-08*
