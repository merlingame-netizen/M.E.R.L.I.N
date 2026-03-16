"""
Visual Audit Tool — Static analysis of graphical identity and visual consistency.

Scans all .gd, .tscn, .tres files for:
  1. Hardcoded colors (Color() not from MerlinVisual)
  2. Palette consistency (MerlinVisual usage vs raw Color())
  3. Biome visual coherence (all 8 biomes have complete configs)
  4. Font references in resource files
  5. Scene tree depth in .tscn files
  6. Material audit (ShaderMaterial / StandardMaterial3D references)

Output: JSON report to stdout (or --output file).
Usage:  python tools/visual_audit.py [--output report.json] [--verbose]

No external dependencies. Python 3.10+ standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Files that ARE the palette definition — hardcoded colors are expected there
PALETTE_DEFINITION_FILES = {
    "merlin_visual.gd",
    "merlin_visual_palettes.gd",
    "sprite_palette.gd",
    "pixel_scene_data.gd",
    "biome_config.gd",
    "biome_particles.gd",
    # Pixel art asset data files — colors define procedural art, not UI
    "pixel_art_showcase.gd",
    "layered_scene_data.gd",
    "ambiance_data.gd",
    "pixel_npc_portrait.gd",
    "pixel_character_portrait.gd",
    "pixel_ogham_icons.gd",
    "pixel_matrix_bg.gd",
    # Game constants (faction colors are data, not UI styling)
    "merlin_constants.gd",
}

# Directories where hardcoded colors are expected (3D scene builders, VFX, etc.)
# These define visual assets procedurally — raw Color() is the norm.
PALETTE_EXEMPT_DIRS = {
    "broceliande_3d",
    "sprite_factory",
}

# Mapping from full biome IDs to short palette keys used in BIOME_CRT_PALETTES
BIOME_ID_TO_PALETTE_KEY = {
    "foret_broceliande": "broceliande",
    "landes_bruyere": "landes",
    "cotes_sauvages": "cotes",
    "villages_celtes": "villages",
    "cercles_pierres": "cercles",
    "marais_korrigans": "marais",
    "collines_dolmens": "collines",
    "iles_mystiques": "iles",
}

# Directories to skip entirely
SKIP_DIRS = {"archive", ".godot", ".git", "node_modules", "addons", "__pycache__"}

# The 8 canonical biomes
EXPECTED_BIOMES = [
    "foret_broceliande",
    "landes_bruyere",
    "cotes_sauvages",
    "villages_celtes",
    "cercles_pierres",
    "marais_korrigans",
    "collines_dolmens",
    "iles_mystiques",
]

# Biome config required fields (from BiomeConfig resource)
BIOME_CONFIG_FIELDS = ["sky_color", "ground_color", "fog_color", "fog_density",
                       "ambient_light_color", "ambient_light_energy", "particle_type"]

# Regex patterns
RE_COLOR_LITERAL = re.compile(
    r"""Color\(\s*"""
    r"""([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)"""
    r"""(?:\s*,\s*([\d.]+))?\s*\)""",
)
RE_COLOR_HEX = re.compile(r"""Color\(\s*["']#([0-9a-fA-F]{6,8})["']\s*\)""")
RE_MERLIN_VISUAL_REF = re.compile(r"""MerlinVisual\.""")
RE_FONT_RESOURCE = re.compile(r"""(?:font|FontFile|FontVariation)\s*=\s*.*?["']([^"']+\.(?:ttf|otf|tres|font))["']""", re.IGNORECASE)
RE_FONT_TSCN = re.compile(r"""(?:font|theme_override_fonts)\S*\s*=\s*.*?["']?(res://[^"'\s]+\.(?:ttf|otf|tres))["']?""", re.IGNORECASE)
RE_MATERIAL_REF = re.compile(r"""(ShaderMaterial|StandardMaterial3D|CanvasItemMaterial|ParticleProcessMaterial)""")
RE_TSCN_NODE = re.compile(r"""^\[node\s+name="([^"]+)"\s+.*?parent="([^"]*)".*?\]""")
RE_TSCN_NODE_ROOT = re.compile(r"""^\[node\s+name="([^"]+)"\s+type="([^"]+)"\s*\]""")

# Max acceptable scene tree depth
MAX_SCENE_DEPTH = 10

# Scoring weights
WEIGHT_COLOR_VIOLATIONS = 3.0      # per violation
WEIGHT_BIOME_INCOMPLETE = 5.0      # per missing field
WEIGHT_DEEP_SCENE = 2.0            # per scene exceeding depth
WEIGHT_PALETTE_COVERAGE = 20.0     # penalty scaled by coverage gap


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

def find_files(root: Path, extensions: set[str]) -> list[Path]:
    """Walk project tree, skip SKIP_DIRS, return files matching extensions."""
    results: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune skipped directories in-place
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fname in filenames:
            if Path(fname).suffix.lower() in extensions:
                results.append(Path(dirpath) / fname)
    return results


# ---------------------------------------------------------------------------
# 1. Hardcoded color detection
# ---------------------------------------------------------------------------

def audit_colors(gd_files: list[Path], verbose: bool = False) -> tuple[list[dict], dict]:
    """Scan .gd files for Color() literals not from MerlinVisual.

    Returns (violations, coverage_stats).
    """
    violations: list[dict] = []
    total_color_refs = 0
    palette_refs = 0
    hardcoded_refs = 0

    for fpath in gd_files:
        fname = fpath.name
        # Check if file is in an exempt directory (3D builders, sprite factories)
        fpath_parts = set(fpath.parts)
        is_exempt_dir = bool(fpath_parts & PALETTE_EXEMPT_DIRS)
        is_palette_def = fname in PALETTE_DEFINITION_FILES or is_exempt_dir
        try:
            lines = fpath.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        for line_no, line in enumerate(lines, start=1):
            stripped = line.lstrip()
            # Skip comments
            if stripped.startswith("#") or stripped.startswith("//"):
                continue

            # Count MerlinVisual references
            mv_count = len(RE_MERLIN_VISUAL_REF.findall(line))
            palette_refs += mv_count
            total_color_refs += mv_count

            # Count Color() literals
            for m in RE_COLOR_LITERAL.finditer(line):
                total_color_refs += 1
                if is_palette_def:
                    continue  # expected in palette definition files
                hardcoded_refs += 1
                r, g, b = m.group(1), m.group(2), m.group(3)
                a = m.group(4) or "1.0"
                # Check if line also has MerlinVisual reference (acceptable patterns like
                # creating Color with modified alpha from palette)
                if RE_MERLIN_VISUAL_REF.search(line):
                    # Likely a palette-derived color with alpha modification — lower severity
                    continue
                # Transparent/black/white are common utility colors, skip
                color_tuple = (float(r), float(g), float(b), float(a))
                if _is_utility_color(color_tuple):
                    continue
                rel = _rel_path(fpath)
                violations.append({
                    "file": rel,
                    "line": line_no,
                    "color_value": f"Color({r}, {g}, {b}, {a})",
                    "suggestion": f"Use MerlinVisual.CRT_PALETTE[\"...\"] instead of hardcoded Color({r}, {g}, {b})",
                })

            for m in RE_COLOR_HEX.finditer(line):
                total_color_refs += 1
                if is_palette_def:
                    continue
                hardcoded_refs += 1
                hex_val = m.group(1)
                if RE_MERLIN_VISUAL_REF.search(line):
                    continue
                rel = _rel_path(fpath)
                violations.append({
                    "file": rel,
                    "line": line_no,
                    "color_value": f'Color("#{hex_val}")',
                    "suggestion": f"Use MerlinVisual.CRT_PALETTE[\"...\"] instead of hex color #{hex_val}",
                })

    coverage_pct = (palette_refs / total_color_refs * 100.0) if total_color_refs > 0 else 100.0

    coverage = {
        "total_color_refs": total_color_refs,
        "from_palette": palette_refs,
        "hardcoded": hardcoded_refs,
        "percentage": round(coverage_pct, 1),
    }
    return violations, coverage


def _is_utility_color(rgba: tuple[float, float, float, float]) -> bool:
    """Return True for common utility colors (transparent, black, white, modulate defaults)."""
    r, g, b, a = rgba
    # Fully transparent
    if a < 0.01:
        return True
    # Pure black
    if r == 0.0 and g == 0.0 and b == 0.0:
        return True
    # Pure white
    if r >= 0.99 and g >= 0.99 and b >= 0.99:
        return True
    # Modulate identity (1,1,1,1) or close
    if abs(r - 1.0) < 0.2 and abs(g - 1.0) < 0.2 and abs(b - 1.0) < 0.2 and abs(a - 1.0) < 0.2:
        return True
    return False


# ---------------------------------------------------------------------------
# 2. Biome visual coherence
# ---------------------------------------------------------------------------

def audit_biome_completeness(gd_files: list[Path]) -> dict[str, dict]:
    """Check that all 8 biomes have complete configs and particle mappings."""
    biome_report: dict[str, dict] = {}

    # Parse biome_config.gd for preset entries
    config_file = _find_file(gd_files, "biome_config.gd")
    config_biomes: set[str] = set()
    if config_file:
        content = config_file.read_text(encoding="utf-8", errors="replace")
        # Look for presets["biome_id"] = _make(...)
        for m in re.finditer(r'presets\["(\w+)"\]\s*=\s*_make\(', content):
            config_biomes.add(m.group(1))
        # Check for fields in each preset
        # Since all are created via _make with full params, if present they're complete
        for m in re.finditer(r'_make\(\s*"(\w+)"', content):
            config_biomes.add(m.group(1))

    # Parse biome_particles.gd for particle mapping
    particles_file = _find_file(gd_files, "biome_particles.gd")
    particle_biomes: set[str] = set()
    if particles_file:
        content = particles_file.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'"(\w+)":\s*\[', content):
            particle_biomes.add(m.group(1))

    # Parse merlin_visual.gd (or merlin_visual_palettes.gd) for BIOME_CRT_PALETTES
    visual_file = _find_file(gd_files, "merlin_visual_palettes.gd") or _find_file(gd_files, "merlin_visual.gd")
    palette_biomes: set[str] = set()
    if visual_file:
        content = visual_file.read_text(encoding="utf-8", errors="replace")
        # Look for "biome_id": [ inside BIOME_CRT_PALETTES
        in_biome_palettes = False
        for line in content.splitlines():
            if "BIOME_CRT_PALETTES" in line:
                in_biome_palettes = True
            if in_biome_palettes:
                m = re.search(r'"(\w+)":\s*\[', line)
                if m:
                    palette_biomes.add(m.group(1))

    for biome_id in EXPECTED_BIOMES:
        has_config = biome_id in config_biomes
        has_particles = biome_id in particle_biomes
        # BIOME_CRT_PALETTES uses short keys (e.g. "broceliande" not "foret_broceliande")
        palette_key = BIOME_ID_TO_PALETTE_KEY.get(biome_id, biome_id)
        has_palette = palette_key in palette_biomes

        # Sky/ground/fog are part of config — if config exists, all fields present
        # (because _make() requires all params)
        biome_report[biome_id] = {
            "has_config": has_config,
            "has_particles": has_particles,
            "has_palette": has_palette,
            "has_sky": has_config,
            "has_fog": has_config,
            "complete": has_config and has_particles and has_palette,
        }

    return biome_report


# ---------------------------------------------------------------------------
# 3. Font references
# ---------------------------------------------------------------------------

def audit_fonts(resource_files: list[Path]) -> list[dict]:
    """Scan .tres and .tscn files for font references."""
    font_refs: list[dict] = []
    seen: set[tuple[str, str]] = set()

    for fpath in resource_files:
        try:
            content = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        for pattern in [RE_FONT_RESOURCE, RE_FONT_TSCN]:
            for m in pattern.finditer(content):
                font_path = m.group(1)
                rel = _rel_path(fpath)
                key = (rel, font_path)
                if key not in seen:
                    seen.add(key)
                    font_refs.append({
                        "file": rel,
                        "font_path": font_path,
                    })

    # Also scan .gd files for font loading
    gd_files = find_files(PROJECT_ROOT, {".gd"})
    for fpath in gd_files:
        try:
            content = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in re.finditer(r"""(?:load|preload)\(\s*["'](res://[^"']+\.(?:ttf|otf|tres))["']\s*\)""", content):
            font_path = m.group(1)
            rel = _rel_path(fpath)
            key = (rel, font_path)
            if key not in seen:
                seen.add(key)
                font_refs.append({
                    "file": rel,
                    "font_path": font_path,
                })

    return font_refs


# ---------------------------------------------------------------------------
# 4. Scene tree depth
# ---------------------------------------------------------------------------

def audit_scene_depth(tscn_files: list[Path]) -> list[dict]:
    """Analyze .tscn files for excessive node nesting."""
    results: list[dict] = []

    for fpath in tscn_files:
        try:
            content = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        # Build parent-child map from [node] entries
        # parent="" means root, parent="." means child of root
        nodes: dict[str, str] = {}  # node_path -> name
        max_depth = 0
        deepest_path = ""

        root_name = ""
        for line in content.splitlines():
            # Root node (no parent attribute)
            m_root = RE_TSCN_NODE_ROOT.match(line)
            m_child = RE_TSCN_NODE.match(line)

            if m_root and "parent=" not in line:
                root_name = m_root.group(1)
                nodes["."] = root_name
                continue

            if m_child:
                name = m_child.group(1)
                parent = m_child.group(2)
                if parent == ".":
                    node_path = name
                elif parent:
                    node_path = f"{parent}/{name}"
                else:
                    node_path = name
                nodes[node_path] = name
                depth = node_path.count("/") + 1
                if depth > max_depth:
                    max_depth = depth
                    deepest_path = node_path

        if max_depth > 0:
            entry: dict[str, Any] = {
                "scene": _rel_path(fpath),
                "max_depth": max_depth,
                "deepest_path": deepest_path,
            }
            if max_depth > MAX_SCENE_DEPTH:
                entry["violation"] = True
            results.append(entry)

    # Sort by depth descending
    results.sort(key=lambda x: x["max_depth"], reverse=True)
    return results


# ---------------------------------------------------------------------------
# 5. Material audit
# ---------------------------------------------------------------------------

def audit_materials(all_files: list[Path]) -> list[dict]:
    """Find all ShaderMaterial / StandardMaterial3D / etc. references."""
    material_refs: list[dict] = []
    seen: set[tuple[str, int, str]] = set()

    for fpath in all_files:
        try:
            lines = fpath.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        for line_no, line in enumerate(lines, start=1):
            for m in RE_MATERIAL_REF.finditer(line):
                rel = _rel_path(fpath)
                mat_type = m.group(1)
                key = (rel, line_no, mat_type)
                if key not in seen:
                    seen.add(key)
                    material_refs.append({
                        "file": rel,
                        "line": line_no,
                        "material_type": mat_type,
                    })

    return material_refs


# ---------------------------------------------------------------------------
# Summary & scoring
# ---------------------------------------------------------------------------

def compute_summary(
    color_violations: list[dict],
    palette_coverage: dict,
    biome_completeness: dict[str, dict],
    scene_depth: list[dict],
) -> dict:
    """Compute an overall visual consistency score (0-100)."""
    penalty = 0.0

    # Color violations
    penalty += len(color_violations) * WEIGHT_COLOR_VIOLATIONS

    # Palette coverage gap (ideal = 100%)
    coverage_gap = max(0, 100.0 - palette_coverage.get("percentage", 100))
    penalty += coverage_gap * WEIGHT_PALETTE_COVERAGE / 100.0

    # Biome incompleteness
    for biome_id, info in biome_completeness.items():
        if not info.get("complete", False):
            missing = sum(1 for k in ["has_config", "has_particles", "has_palette"] if not info.get(k, False))
            penalty += missing * WEIGHT_BIOME_INCOMPLETE

    # Deep scenes
    deep_scenes = [s for s in scene_depth if s.get("violation", False)]
    penalty += len(deep_scenes) * WEIGHT_DEEP_SCENE

    score = max(0, min(100, int(100.0 - penalty)))
    issues_count = (
        len(color_violations)
        + sum(1 for b in biome_completeness.values() if not b.get("complete", False))
        + len(deep_scenes)
    )

    return {
        "score": score,
        "issues_count": issues_count,
        "pass": score >= 70,
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _rel_path(fpath: Path) -> str:
    """Return path relative to PROJECT_ROOT, with forward slashes."""
    try:
        return str(fpath.relative_to(PROJECT_ROOT)).replace("\\", "/")
    except ValueError:
        return str(fpath).replace("\\", "/")


def _find_file(files: list[Path], name: str) -> Path | None:
    """Find first file matching name in the list."""
    for f in files:
        if f.name == name:
            return f
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run_audit(verbose: bool = False) -> dict:
    """Execute all audit checks and return the full report."""
    gd_files = find_files(PROJECT_ROOT, {".gd"})
    tscn_files = find_files(PROJECT_ROOT, {".tscn"})
    tres_files = find_files(PROJECT_ROOT, {".tres"})
    resource_files = tscn_files + tres_files

    if verbose:
        print(f"[visual_audit] Scanning {len(gd_files)} .gd files, "
              f"{len(tscn_files)} .tscn files, {len(tres_files)} .tres files",
              file=sys.stderr)

    # 1. Color violations & palette coverage
    color_violations, palette_coverage = audit_colors(gd_files, verbose)
    if verbose:
        print(f"[visual_audit] {len(color_violations)} color violations, "
              f"palette coverage: {palette_coverage['percentage']}%",
              file=sys.stderr)

    # 2. Biome completeness
    biome_completeness = audit_biome_completeness(gd_files)
    if verbose:
        complete_count = sum(1 for b in biome_completeness.values() if b["complete"])
        print(f"[visual_audit] Biomes: {complete_count}/{len(EXPECTED_BIOMES)} complete",
              file=sys.stderr)

    # 3. Font references
    font_references = audit_fonts(resource_files)
    if verbose:
        print(f"[visual_audit] {len(font_references)} font references found",
              file=sys.stderr)

    # 4. Scene depth
    scene_depth = audit_scene_depth(tscn_files)
    deep_count = sum(1 for s in scene_depth if s.get("violation", False))
    if verbose:
        print(f"[visual_audit] {deep_count} scenes exceed depth {MAX_SCENE_DEPTH}",
              file=sys.stderr)

    # 5. Material audit
    all_scannable = gd_files + resource_files
    materials = audit_materials(all_scannable)
    if verbose:
        print(f"[visual_audit] {len(materials)} material references found",
              file=sys.stderr)

    # 6. Summary
    summary = compute_summary(color_violations, palette_coverage,
                              biome_completeness, scene_depth)

    report = {
        "color_violations": color_violations,
        "palette_coverage": palette_coverage,
        "biome_completeness": biome_completeness,
        "font_references": font_references,
        "scene_depth": scene_depth,
        "materials": materials,
        "summary": summary,
    }

    return report


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Visual audit of MERLIN project graphical identity and consistency.",
    )
    parser.add_argument(
        "--output", "-o",
        help="Write JSON report to this file instead of stdout.",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print progress to stderr.",
    )
    args = parser.parse_args()

    report = run_audit(verbose=args.verbose)

    json_str = json.dumps(report, indent=2, ensure_ascii=False)

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(json_str, encoding="utf-8")
        print(f"Report written to {out_path}", file=sys.stderr)
    else:
        print(json_str)

    # Exit code: 0 if pass, 1 if fail
    if not report["summary"]["pass"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
