# GBA-like C++ Graphics Spec (LLM Coder)

Purpose
- Provide strict rules for a C++ CLI tool that generates GBA-like 2D pixel art.
- Output PNG (RGBA) for preview and JSON metadata for engine import.
- Enforce handheld constraints: indexed pixels, stable palettes, tilemaps, and clean clusters.

Style targets
- GBA-era look: readable shapes, bold ramps, restrained noise.
- Consistent framing and proportions across assets.
- Easy to implement in C++ with deterministic steps.
- Includes UI, icons, and effects so the full presentation is stable.

0) Expected Result

The LLM must produce full, compilable C++ code that provides a CLI tool:
- Generate sprites (characters/enemies) in indexed palette format (4bpp style).
- Generate backgrounds as 8x8 tilemaps with a deduplicated tileset.
- Export:
  - PNG (RGBA) for preview
  - JSON for palettes, tileset, tilemap, frames, metadata
  - optional tileset atlas PNG

Art rules must be coded (no raw random noise):
- Readable silhouette
- Simple volume via heightmap or planes
- Shading in clusters
- Limited palette ramps
- Ordered dithering for gradients (light)
- Outline optional but consistent

Minimal automated tests:
- Palette constraints
- No isolated pixels
- Cluster size minimum
- Tile dedup effectiveness
- Reproducibility by seed

1) Console-like Constraints (GBA style)

1.1 Resolution & scaling
- Sprites: 16x24 (characters), 32x32 / 48x48 / 64x64 (enemies)
- Backgrounds: multiples of 8 px (ex: 240x160, 256x224, 320x240)
- No bilinear filtering, blur, or mipmaps
- Final PNG is RGBA, but source must be indexed (0..15 indices)

1.2 Palettes (4bpp style)
- Each sprite or tile group uses 1 palette of 16 colors max (index 0 may be transparent)
- Colors are organized in ramps (base/shadow/light/highlight)
- Hue shift is allowed, but keep ramps tight and consistent

1.3 Tiles & tilemaps
- Backgrounds must be converted to 8x8 tiles
- Tilemap = wTiles x hTiles
- Tileset dedup by hash
- Optional meta-tiles 16x16, but output must include 8x8 level

2) Data Structures (Required)

2.1 Indexed + palette representation

struct Color { uint8_t r, g, b, a; };

struct Palette16 {
  Color c[16]; // c[0] transparent optional
};

struct IndexedImage {
  int w, h;
  std::vector<uint8_t> idx; // w*h, values 0..15
  uint8_t& at(int x,int y) { return idx[y*w + x]; }
  uint8_t  at(int x,int y) const { return idx[y*w + x]; }
};

2.2 Tileset / Tilemap

struct Tile8 {
  uint8_t p[64]; // 8*8 indices
};

struct TileSet {
  std::vector<Tile8> tiles;
};

struct TileMapCell {
  uint32_t tileId;
  uint8_t  palId;
  bool flipX, flipY;
};

struct TileMap {
  int wTiles, hTiles;
  std::vector<TileMapCell> cells; // wTiles*hTiles
};

2.3 JSON export (Required)

JSON must include:
- meta: seed, size, style, timestamp
- palettes: list of 16-color palettes
- images:
  - sprites: frames, pivot, optional hitbox
  - backgrounds: tilemap, tileset, dimensions, optional layers/parallax

Example (indicative):
{
  "meta": { "seed": 123, "style": "gba_like_v1" },
  "palettes": [
    { "id": 0, "colors": ["#00000000", "#1A1E2BFF", "..."] }
  ],
  "sprite": {
    "size": [32,32],
    "palette_id": 0,
    "frames": [
      { "name": "idle_0", "png": "sprite_idle_0.png", "pivot": [16, 28] }
    ]
  },
  "background": {
    "size_px": [240,160],
    "tile_size": 8,
    "palette_id": 1,
    "tileset_png": "bg_tileset.png",
    "tilemap": {
      "w": 30, "h": 20,
      "cells": [ {"t":0,"fx":false,"fy":false}, ... ]
    }
  }
}

3) Stable Style Rules (GBA-like)

These rules must not change between runs or asset types.
They enforce consistency and are easy to implement.

3.1 Framing and scale (fixed)
- Character sprites always occupy the same base footprint:
  - 16x24 canvas
  - head band: y=2..6
  - torso band: y=7..16
  - legs band: y=17..23
- Enemy sprites use a centered canvas with 2px margin on each side.
- No rescaling per asset; only variation inside the frame.

3.2 Line weight (fixed)
- Outline thickness: 1px everywhere.
- No inner outline except for major separations (head/torso) when needed.
- Outline color always palette index 1 (darkest non-transparent).

3.3 Ramp discipline (fixed)
- Each material uses a 3-step ramp: shadow / mid / light.
- Highlights are a single pixel band, max 5 percent of filled area.
- Shadows must cover at least 20 percent of filled area.

3.4 Shading direction (fixed)
- Global light direction is always top-left.
- Use 3-4 shading levels only.
- No smooth gradients; use hard steps and optional ordered dither.

3.5 Cluster rules (fixed)
- No clusters smaller than minCluster.
- Merge clusters with a 1px close pass (dilate then erode).
- Remove 1px spikes on silhouettes.

3.6 Pixel noise ban (fixed)
- No pixel islands and no salt/pepper texture.
- Patterns only via ordered dither (Bayer 4x4) between two ramp levels.
- Dither is allowed only on backgrounds, never on character sprites.

3.7 Background tiling rules (fixed)
- Always generate in layers: sky, mid, foreground.
- Each layer has its own simple motif and limited ramps.
- Ground uses repeatable 16x16 metatiles.

3.8 Global palette families (fixed)
- Use fixed palette families across all assets:
  - Outline/dark: index 1
  - Shadow ramp: indices 2-3
  - Mid ramp: indices 4-5
  - Light/highlight: indices 6-7 (highlight only if needed)
  - Accent: index 8 (small areas only)
  - UI frame: indices 9-10
  - UI fill: indices 11-12
- Index 0 is transparent if needed. Do not change index meanings.
- Hue shifts are allowed but must stay within +/- 10 degrees for each ramp.

3.9 UI windows and HUD (fixed)
- All UI uses 8x8 tiles and a 1px border line weight.
- Window frame uses a single border style (no variations per scene).
- Corner pattern: 2x2 repeated motif, fixed.
- Inner padding: 4px on all sides.
- Text baseline: 8px grid, 1px line spacing.
- UI colors only use the UI frame/fill indices (see 3.8).

3.10 Fonts, icons, and symbols (fixed)
- Use one bitmap font size only (6x8 or 5x7, pick one and keep it).
- Icons are 8x8 or 16x16 only; do not mix sizes in the same UI.
- Icon outline uses index 1, fill uses mid ramp indices only.

3.11 VFX and overlays (fixed)
- VFX palette is limited to 3 colors max (shadow/mid/light).
- VFX can use ordered dither, but only 2x2 and only on backgrounds.
- Screen overlays must not exceed 20 percent of visible pixels.
- No glow or blur; use hard pixels and fixed ramp steps.

3.12 Camera framing and anchors (fixed)
- Character baseline is y = h-2 for all sprite sizes.
- Default pivot is (w/2, h-2) for sprites.
- Background horizon line is fixed per resolution:
  - 240x160: horizon y = 64
  - 256x224: horizon y = 92
  - 320x240: horizon y = 100
- Safe UI area margin: 8px from screen edges.

3.13 Pattern library (fixed)
- Ground pattern uses one repeatable 16x16 tile set.
- Water pattern uses one repeatable 8x8 tile set.
- Foliage uses vertical stripe motifs only (no random speckle).
- Do not mix pattern families on the same layer.

4) Art Rules (General)

4.1 Global prohibitions
- No isolated pixels: every non-transparent pixel needs at least 1 neighbor
- No tiny islands < minCluster for shadow/highlight/detail
- No raw random noise: textures must come from controlled patterns/dither

4.2 Silhouette first (Required)
Pipeline:
- Build a binary mask from primitives:
  - ellipses, rounded rectangles, lobes
  - optional horizontal symmetry for enemies
- Topology cleanup:
  - keep largest connected component
  - fill holes below threshold
  - remove 1px spikes (light erosion/dilation)
- Validate silhouette readability (filled ratio in range)

4.3 Volume: simple heightmap (Required)
- Build heightmap z(x,y) for filled pixels:
  - base: distance to border + 1-3 lobes (head/torso)
  - optional plane levels (cartoon look)
- Cheap distance approximation:
  - 2-3 expansion passes
  - or radial field from center + clamp by border

4.4 Directional shading (3-4 levels)
- light_dir (top-left)
- Approx normal via gradient:
  - nx = z(x+1) - z(x-1)
  - ny = z(y+1) - z(y-1)
- intensity I = dot(normalize(-nx, -ny, 1), light_dir3)
- map I to 3-4 ramp levels

4.5 Cluster massing
- After shading:
  - detect shadow/light regions
  - remove islands < minCluster
  - light close (dilate then erode)
- Goal: large readable blocks, zero dust

4.6 Outline (optional but consistent)
- External outline: any filled pixel with a transparent neighbor
- Outline color = palette index 1
- Selective outline allowed but must follow a single rule (do not vary)

4.7 Ordered dithering (controlled)
- Use Bayer 4x4
- Only between adjacent ramp levels
- Backgrounds only

5) Sprite Generation

5.1 API (Required)

struct SpriteSpec {
  int w, h;
  uint32_t seed;
  int paletteId;
  bool outline;
  int minCluster;
  // style params
};

struct SpriteResult {
  IndexedImage indexed;
  Palette16 palette;
  // optional: multiple frames, pivot/hitbox
};

SpriteResult GenerateSpriteGBALike(const SpriteSpec& spec);

5.2 Presets (at least 2)
- Character-like: 16x24, outline ON, minCluster=4
- Enemy-like: 48x48 or 64x64, outline ON, minCluster=6

5.3 Animation (optional)
- 2-4 idle frames by slight deformation:
  - +/-1 px height on a zone
  - 1 px appendage shift
- Palette must stay identical across frames

6) Background Generation

6.1 API (Required)

struct BackgroundSpec {
  int wPx, hPx;        // multiples of 8
  uint32_t seed;
  int paletteId;
  bool twoLayers;      // optional parallax
  int ditheringLevel;  // 0..2
};

struct BackgroundResult {
  IndexedImage indexed;
  Palette16 palette;
  TileSet tileset;
  TileMap tilemap;
  // optional: layer2 tileset/tilemap + parallax factors
};

BackgroundResult GenerateBackgroundGBALike(const BackgroundSpec& spec);

6.2 Composition (GBA-like)
- Sky: gradient + light ordered dithering
- Mountains: simple silhouettes + 2-3 shadow levels
- Forest: vertical repeating shapes, no noise
- Ground: 16x16 metatile pattern (repeatable)

6.3 Tile-ization (Required)
- Split indexed image into 8x8 tiles
- Dedup via hash of 64 indices
- Produce tilemap

Dedup approach:
- std::array<uint8_t,64> -> hash (FNV-1a)
- map hash -> tileId, verify collisions by byte compare

7) Palettes

7.1 Palette generation (Required)
- 2-4 ramps: skin, cloth, metal, global shadow, highlight
- 1 outline color (very dark)
- 1 accent color for readability

Recommended HSV method:
- Shadow: hue +/- 5-15 deg, sat slightly up, value down
- Light: slight hue shift, value up

7.2 Validation
- No duplicate colors (small tolerance)
- Alpha 0 only for index 0 if transparency is used

8) PNG Export + Indexed to RGBA

Required conversion:

std::vector<uint8_t> ToRGBA(const IndexedImage& img, const Palette16& pal);

PNG export:
- Use a small library (stb_image_write.h)
- Output:
  - sprite_rgba.png
  - bg_rgba.png
  - tileset_atlas.png

9) CLI (Required)

Commands:
- gen_sprite --seed 123 --w 48 --h 48 --style enemy --out out/
- gen_bg --seed 42 --w 240 --h 160 --style field --out out/
- gen_pack --seed 999 --count 20 --out out/ (optional)

Options:
- --outline 0/1
- --minCluster N
- --dither 0/1/2
- --palPreset name (optional)

10) Quality Tests

10.1 Sprite tests
- PaletteIndicesInRange: all indices 0..15
- NoIsolatedPixels: no filled pixel without neighbor
- ClusterMinSize: shadow/light clusters >= minCluster
- ReproducibleSeed: same seed -> same output

10.2 Background tests
- SizeMultipleOf8
- TileDedupNotExploding: tileset size <= wTiles*hTiles and ideally <<
- PaletteConstraint

11) Preset: "gba_like_v1"

Sprites
- Character: 16x24, outline ON, minCluster=4, shadingLevels=3
- Enemy: 48x48, outline ON, minCluster=6, shadingLevels=4
- light_dir = (-0.6, -0.8, 0.7)

Background
- 240x160, ditheringLevel=1, twoLayers=ON (parallax 0.5 distant layer)
- Ground: 16x16 repeatable pattern
- Sky: 3-level ramp + Bayer 4x4

12) LLM Code Rules

The LLM must:
- Provide full files (no snippets)
- Use C++17 (or C++20 if justified)
- Include:
  - main.cpp
  - sprite_gen.cpp/.h
  - bg_gen.cpp/.h
  - palette.cpp/.h
  - tile.cpp/.h
  - png_write.cpp/.h (stb)
  - json_write.cpp/.h (minimal writer)
  - tests.cpp (small runner)

Style:
- Short functions
- Clear assertions
- Comments about "why" (art rules), not "what"

13) "Convincing" Checklist

A sprite/background is convincing if:
- Palette <= 16 colors
- Silhouette readable at thumbnail size
- Shading in masses, not noise
- Outline clean when enabled
- Tile repetition controlled
- Crisp output (nearest; integer scale in engine)
- UI uses fixed window rules and font size
- VFX respects palette limits and no blur
