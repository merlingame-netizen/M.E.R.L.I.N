# Low-Poly Isometric Style Guide — M.E.R.L.I.N.

## Style Definition

**Type**: Low-poly isometric flat-shading (faceted 3D illusion)
**Canvas**: 256x256 render, downscale to 128x128 (LANCZOS) for Godot
**Outlines**: NONE — shapes defined by color contrast between adjacent facets
**Animation**: 12 frames, 6 fps, per-group displacement (sin/cos breathing + sway)

## Palette Rules

Every character uses a **10-shade grayscale** + **1 accent color**.

### Base Grayscale (shared across all characters)

| Name | Hex | Usage |
|------|-----|-------|
| `void` | `#000000` | Face void, deepest shadows |
| `deep` | `#0a0a12` | Near-black bluish, depth edges |
| `dark1` | `#151520` | Very dark, chin shadows, drape |
| `dark2` | `#222230` | Dark charcoal, inner hood |
| `dark3` | `#2a3038` | Charcoal, shadow-side hood |
| `mid1` | `#3a4048` | Medium-dark, ambient-lit surfaces |
| `mid2` | `#4a5058` | Medium, lit armor/hood |
| `mid3` | `#586068` | Medium-light, secondary highlights |
| `light1` | `#687078` | Gray, reflections, cable detail |
| `light2` | `#8a9098` | Light gray, visor edge, face frame |
| `bright` | `#a8b0b8` | Brightest, highlight facets, edges |

### Accent Colors (per character)

| Character | Accent | Dim | Halo |
|-----------|--------|-----|------|
| M.E.R.L.I.N. (amber) | `#FFFC68` | `#BBA830` | `#FFFC6838` |
| M.E.R.L.I.N. (cyan) | `#1DFDFF` | `#0EA0A8` | `#1DFDFF38` |

For new characters, choose ONE bright accent color and derive dim + halo variants:
- **Accent**: Full brightness, saturated
- **Dim**: ~60% brightness, same hue
- **Halo**: Same as accent + `38` alpha suffix (semi-transparent)

## Construction Rules

### 1. Layered Z-Order Stack

Build characters in layers (back to front):

| Z-Range | Layer | Description |
|---------|-------|-------------|
| 0-2 | Body core | Mostly hidden, fills gaps |
| 3-5 | Armor/clothing | Blocky angular shapes |
| 6-8 | Hood/head shell | DEFINING shape, covers body |
| 9 | Peak details | Highlight/shadow strips |
| 10-11 | Face void | Black recess punching through head |
| 13 | Face frame | Visor edge highlights |
| 14 | Eyes | Glow dots + polygon slits |
| 15 | Tech details | Cables, accents, accessories |

### 2. Hood/Head Construction

The head piece is the CHARACTER-DEFINING shape. Rules:

- Build as **TILED ANGULAR FACETS** (like a 3D mesh)
- Each facet = single flat color, NO gradients
- Adjacent facets must have VISIBLE color difference (creates edges)
- Use **4 facets per side** minimum (upper outer, lower outer, inner, drape)
- Share vertices exactly between adjacent facets (no gaps)
- Bottom edge curves UP in center (hanging fabric)

### 3. Lighting Model

Light source: **UPPER RIGHT**

| Face Angle | Color Range |
|------------|-------------|
| Facing right/up (toward light) | `mid2` — `bright` |
| Facing viewer (flat) | `mid1` — `mid3` |
| Facing left (away from light) | `dark2` — `dark3` |
| Facing down (deep shadow) | `dark1` — `void` |
| Direct light hit | `light2` — `bright` |

**Key highlight**: Always add a BRIGHT facet on the upper-right of the head shape.
**Centerline ridge**: Thin subtle strip where left/right halves meet.

### 4. Face Opening

- Shape: TRAPEZOID (narrower at forehead, wider at chin)
- Filled with `void` (#000000) at z=10
- Depth shadows: triangular `deep` facets at edges
- Chin band: `dark1` at bottom
- Visor edge: thin highlights (bright top, light2 right, mid2 left)
- NO heavy rectangular frame — keep it geometric

### 5. Eyes

- **Glow dots**: GlowDot with `halo_radius=22`, accent halo color
- **Slit shapes**: Diamond polygon facets (wider than tall)
- Eyes in upper third of face opening
- Always 2 eyes, centered horizontally

### 6. Animation Groups

| Group | Displacement | Purpose |
|-------|-------------|---------|
| `hood` (or head) | `(sway * 1.0, breath * 0.5)` | Head sway |
| `face` | `(sway * 0.8, breath * 0.6)` | Follows head |
| `eyes` | `(sway * 0.8, breath * 0.6)` | Follows face |
| `shoulder_l` | `(-0.3, breath * 0.3)` | Opposite sway |
| `shoulder_r` | `(0.3, breath * 0.3)` | Opposite sway |
| `body` | `(0, breath * 0.2)` | Minimal bob |
| `accent` | `(0, breath * 0.3)` | Follows body |

**Curves**: `breath = sin(t * 2pi) * 2.0`, `sway = cos(t * 2pi) * 1.0`

## Template: Creating a New Character

```python
from pixel_art.low_poly_mesh import LowPolyMesh

def build_character():
    m = LowPolyMesh(256, 256)

    # 1. BODY (z=0-2) — wide background fill
    # 2. ARMOR/CLOTHING (z=3-5) — blocky plates
    # 3. HEAD/HOOD (z=6-9) — bell curve, angular facets
    #    - 4+ facets per side, tiled (not overlapping)
    #    - Bright highlight on upper-right
    #    - Centerline ridge
    # 4. FACE VOID (z=10) — trapezoid punch-through
    # 5. FACE FRAME (z=13) — visor edge
    # 6. EYES (z=14) — glow + slit facets
    # 7. DETAILS (z=15) — cables, accents

    return m
```

## File Structure

```
tools/pixel_art/
  low_poly_mesh.py        # LowPolyMesh, Facet, GlowDot
  characters/
    __init__.py
    merlin_lowpoly.py     # M.E.R.L.I.N. definition
    # Future: bestiole_lowpoly.py, enemy_lowpoly.py, etc.
  STYLE_LOWPOLY.md        # This file
```

## Output Pipeline

```bash
python tools/pixel_art/characters/merlin_lowpoly.py
# Generates: output/pixel_art/merlin.{png,gif,ase,_sheet.png}
```

Uses `forge_simple.forge()` which outputs:
1. `.ase` — Aseprite/LibreSprite editable file (12 frames)
2. `.png` — Single frame preview (128x128)
3. `.gif` — Animated preview (4x upscaled = 512x512)
4. `_sheet.png` — Sprite sheet (1536x128, 12 frames in row)
