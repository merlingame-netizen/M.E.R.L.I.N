# Visual Auditor Agent

## Purpose

Static analysis of graphical identity and visual consistency across the MERLIN codebase.
Detects hardcoded colors, palette drift, biome config gaps, font inconsistencies,
excessive scene nesting, and material usage — all without running the game.

## AUTO-ACTIVATION

Trigger this agent automatically when:
- Any file in `scripts/ui/` is modified
- Any file in `scripts/autoload/merlin_visual.gd` is modified
- Any file in `scripts/run/biome_config.gd` or `scripts/run/biome_particles.gd` is modified
- Any `.tscn` scene file is modified
- Any file containing `Color(` or `MerlinVisual` is edited

## Tool

```bash
python tools/visual_audit.py --verbose
```

Options:
- `--output report.json` — write JSON report to file
- `--verbose` — progress output to stderr

Exit code: 0 = pass (score >= 70), 1 = fail.

## Report Sections

| Section | What it checks |
|---------|---------------|
| `color_violations` | `Color()` literals in non-palette files that should use `MerlinVisual.CRT_PALETTE` |
| `palette_coverage` | Ratio of palette refs vs hardcoded colors across all .gd files |
| `biome_completeness` | All 8 biomes have config, particles, and CRT palette entries |
| `font_references` | Font files referenced in .tscn/.tres/.gd — flags non-standard fonts |
| `scene_depth` | .tscn node nesting depth — flags scenes exceeding 10 levels |
| `materials` | ShaderMaterial / StandardMaterial3D / ParticleProcessMaterial usage map |
| `summary` | Score (0-100), issues count, pass/fail |

## Rules Enforced

1. **All UI colors MUST come from `MerlinVisual.CRT_PALETTE`** — no raw `Color()` in UI scripts
2. **Palette definition files are exempt** — `merlin_visual.gd`, `sprite_palette.gd`, `pixel_scene_data.gd`, `biome_config.gd`, `biome_particles.gd`
3. **Utility colors exempt** — transparent, black, white, modulate identity
4. **All 8 biomes must have** — BiomeConfig preset, BiomeParticles mapping, BIOME_CRT_PALETTES entry
5. **Scene depth <= 10** — deeper nesting is flagged as a warning

## Integration

Run as part of the post-dev checklist (CLAUDE.md section 3):
```
1. VALIDATE  — .\validate.bat
2. VISUAL    — python tools/visual_audit.py --verbose
3. FIX       — address color violations and biome gaps
4. COMMIT    — git add + git commit
```

## Scoring

- Each color violation: -3 points
- Each incomplete biome (missing config/particles/palette): -5 points per missing element
- Each scene exceeding depth limit: -2 points
- Palette coverage gap: up to -20 points
- **Pass threshold: 70/100**
