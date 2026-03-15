# Visual Quality Report — M.E.R.L.I.N.

> Generated: 2026-03-15
> Tools: `visual_audit.py`, `perf_audit.py`, `visual_preview.py`

---

## 1. Visual Audit Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Overall Score** | **0 / 100** | FAIL |
| Color violations | 89 | High |
| Palette coverage | 44.6% (855/1916 refs use MerlinVisual) | Low |
| Biome completeness | 8/8 complete | OK |
| Scene depth violations | 0 (max depth = 8, threshold = 10) | OK |
| Font references in resources | 0 | OK |
| Material references | 78 (37 StandardMaterial3D, 24 ParticleProcessMaterial, 17 ShaderMaterial) | Info |

### Color Violations by File (Top 10)

| File | Violations |
|------|-----------|
| `scripts/ui/merlin_game_ui.gd` | 18 |
| `scripts/merlin/merlin_biome_system.gd` | 8 |
| `scripts/merlin/merlin_biome_tree.gd` | 8 |
| `scripts/test/pixel_art_showcase.gd` | 8 |
| `scripts/ui/card_scene_compositor.gd` | 8 |
| `scripts/minigames/minigame_base.gd` | 7 |
| `scripts/merlin/merlin_gauge_system.gd` | 5 |
| `scripts/minigames/mg_pile_ou_face.gd` | 5 |
| `scripts/ui/faction_rep_bar.gd` | 5 |
| `scripts/MenuPrincipalMerlin.gd` | 4 |

### Why Score = 0

The scoring formula penalizes 3 points per color violation (89 * 3 = 267) plus a palette coverage gap penalty. The raw penalty exceeds 100, clamping the score to 0. The palette coverage of 44.6% means more than half of all color references are hardcoded rather than using `MerlinVisual.CRT_PALETTE` or `MerlinVisual.GBC`.

**Note**: The visual_audit tool's `PALETTE_DEFINITION_FILES` and `PALETTE_EXEMPT_DIRS` already exclude files like `merlin_visual.gd`, `merlin_constants.gd`, and the `broceliande_3d/` and `sprite_factory/` directories. The 89 violations represent genuinely hardcoded colors in UI/game logic scripts.

---

## 2. Performance Audit Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Overall Score** | **67 / 100** | Grade D (PASS) |
| Node count | 337 (budget: 500 warn / 1000 crit) | OK |
| Particle budget | 244 max concurrent (budget: 500) | OK |
| Draw calls (estimated) | 307 UI controls (threshold: 300 warn) | WARNING |
| Audio pool ratio | 3.4:1 (27 SFX / 8 pool) | OK |
| Textures | 25.84 MB (302 files) | Info |
| Audio | 91.38 MB (280 files) | Info |
| Scripts | 238 total | Info |
| Fonts | 8 | Info |

### Bottlenecks Identified

1. **Draw calls**: 307 UI controls exceed the 300 warning threshold. All from UI controls (no mesh or sprite nodes in .tscn files -- 3D content is procedural).
2. **Concurrent tween risks**: 21 files tween the same property multiple times (e.g., `modulate:a` tweened 5-7 times in the same script). This can cause visual jitter if tweens overlap at runtime.
3. **Script complexity**: 21 scripts exceed 800 lines (critical threshold). 98 scripts exceed 400 lines (warning).

### Signal Hotspots (Top 4)

| File | Total Signals+Connects |
|------|----------------------|
| `scripts/ui/merlin_game_ui.gd` | 30 |
| `scripts/MenuPrincipalMerlin.gd` | 19 |
| `scripts/MenuOptions.gd` | 18 |
| `scripts/merlin/merlin_store.gd` | 16 |

### Largest Scripts (Top 5)

| File | Lines | Nesting | Complexity |
|------|-------|---------|-----------|
| `scripts/ui/merlin_game_ui.gd` | 4308 | 6 | 851 |
| `scripts/TransitionBiome.gd` | 3111 | 6 | 550 |
| `scripts/merlin/merlin_llm_adapter.gd` | 2687 | 7 | 587 |
| `scripts/ui/sprite_factory/sprite_templates.gd` | 2059 | 6 | 175 |
| `scripts/ui/merlin_game_controller.gd` | 1929 | 6 | 556 |

---

## 3. Visual Preview Completeness

| Screen | Previewed | Notes |
|--------|-----------|-------|
| Hub (L'Antre de Merlin) | Yes | Full wireframe, color map, component inventory, animations, sounds |
| Run (3D gameplay) | Yes | Card overlay, life bar, biome info, minigame layer |
| End Screen | Yes | Score summary, Anam earned, faction deltas |
| Card | Yes | 3-option layout, effects, minigame trigger |
| Biome: Broceliande | Yes | Forest theme, mist + fireflies particles |
| Biome: Landes | Yes | Heather theme, fireflies |
| Biome: Cotes Sauvages | Yes | Coastal theme, rain |
| Biome: Villages Celtes | Yes | Village theme, leaves |
| Biome: Cercles de Pierres | Yes | Stone circle theme, embers |
| Biome: Marais Korrigans | Yes | Swamp theme, mist |
| Biome: Collines Dolmens | Yes | Hill/dolmen theme, snow |
| Biome: Iles Mystiques | Yes | Island theme, rain |

**Result**: 12/12 screens previewed. All major game screens and all 8 biome environments are covered with:
- ASCII wireframe layouts
- Color maps referencing exact `MerlinVisual.CRT_PALETTE` values
- Component inventories with sizing and spacing
- Animation timelines
- Sound event maps

---

## 4. Top 10 Actionable Items

### Priority 1 — Color Consistency (Impact: Visual Score)

1. **Migrate `merlin_game_ui.gd` colors to MerlinVisual** (18 violations). This is the highest-violation file and the main gameplay UI. Replace hardcoded `Color(...)` with `MerlinVisual.CRT_PALETTE["..."]` or `MerlinVisual.GBC[...]` references.

2. **Migrate biome system colors** (`merlin_biome_system.gd` + `merlin_biome_tree.gd`, 16 violations combined). These define biome-specific colors but use raw `Color()` literals instead of referencing the palette system.

3. **Migrate minigame colors** (`minigame_base.gd` + `mg_pile_ou_face.gd`, 12 violations combined). Game-feel colors during minigames should match the CRT aesthetic.

4. **Migrate card compositor colors** (`card_scene_compositor.gd`, 8 violations). Card rendering is a core visual element.

5. **Migrate faction/gauge UI colors** (`faction_rep_bar.gd` + `merlin_gauge_system.gd`, 10 violations combined). These are player-facing status displays.

### Priority 2 — Performance (Impact: Runtime Stability)

6. **Audit concurrent tweens** in the 21 flagged files. Focus on `modulate:a` and `scale` properties that are tweened multiple times. Add `tween.kill()` guards before creating new tweens on the same property to prevent visual jitter.

7. **Refactor `merlin_game_ui.gd`** (4308 lines, complexity 851). This file is the single largest risk -- it handles UI construction, signal wiring, and rendering in one monolith. Extract sections into dedicated components (faction panel, biome grid, ogham selector, action bar).

8. **Refactor `TransitionBiome.gd`** (3111 lines) and **`merlin_llm_adapter.gd`** (2687 lines). Both exceed 2500 lines and have complexity scores above 500.

### Priority 3 — Polish

9. **Add font resource references to .tscn files**. Currently 0 font references detected in scene/resource files, meaning all fonts are set procedurally in code. Consider defining font overrides in theme resources for easier design iteration.

10. **Review draw call budget**. 307 UI controls is at the warning threshold. Consolidate UI containers where possible (reduce nesting, merge labels, use RichTextLabel instead of multiple Labels).

---

## 5. Overall Visual Readiness Assessment

| Dimension | Rating | Details |
|-----------|--------|---------|
| **Palette architecture** | Strong | MerlinVisual.CRT_PALETTE, GBC, and BIOME_CRT_PALETTES are well-designed. The palette system exists and covers all needed colors. |
| **Palette adoption** | Weak (44.6%) | More than half of color references bypass the palette. The architecture is there but not fully used. |
| **Biome visual system** | Complete | All 8 biomes have config, particles, and CRT palettes. Each biome has distinct sky/ground/fog/ambient/particle settings. |
| **Scene structure** | Good | No excessively deep scene trees (max depth 8, under threshold 10). |
| **Performance headroom** | Moderate | Node count and particles are well within budget. Draw calls and script complexity are at warning levels. |
| **Code maintainability** | Concerning | 21 scripts exceed 800 lines. The UI monolith at 4308 lines is a significant maintenance burden. |

### Verdict

The visual identity system (CRT/retro aesthetic, biome palettes, material pipeline) is **architecturally sound** but **inconsistently applied**. The project has a well-designed palette centralization mechanism in `MerlinVisual` that is only used for 44.6% of color references.

**Visual readiness**: Not production-ready. The hardcoded color violations mean visual changes require hunting through 89+ locations across 10+ files instead of updating palette constants.

**Performance readiness**: Marginal pass (67/100, grade D). The primary risks are script complexity (maintainability) and concurrent tweens (visual bugs), not raw performance budgets.

**Recommended next step**: Focus on items 1-5 (color migration) to bring palette coverage above 80%. This would raise the visual audit score from 0 to approximately 70+ and make the visual identity truly centralized.

---

## Raw Data Files

- `docs/audits/visual_audit_raw.json` — Full visual audit (89 violations, palette stats, biome details)
- `docs/audits/perf_audit_raw.json` — Full perf audit (node budget, particles, signals, tweens, complexity)
- `docs/audits/visual_preview_raw.txt` — All 12 screen previews (980 lines)
