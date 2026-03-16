#!/usr/bin/env python3
"""
perf_audit.py — Static performance analysis for the M.E.R.L.I.N. Godot 4.x project.

CLI tool: python tools/perf_audit.py
No external deps. Python 3.12+, Windows compatible.

Analyses (all static, no Godot runtime):
  1. Node count estimation from .tscn files
  2. Particle budget from biome_particles.gd constants
  3. Signal density per script
  4. Draw call estimation (MeshInstance3D, Sprite2D/3D, Controls)
  5. Memory estimation (textures, audio, fonts from .import/ and .tscn)
  6. Tween count / concurrent tween risk
  7. Audio pool size vs max concurrent sounds
  8. Script complexity (lines, nesting, cyclomatic complexity)

Output: JSON report to stdout (or --output file).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any


# ============================================================================
# Constants
# ============================================================================

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Thresholds
NODE_BUDGET_WARNING = 500
NODE_BUDGET_CRITICAL = 1000
PARTICLE_RECOMMENDED_MAX = 500
SIGNAL_HOTSPOT_THRESHOLD = 20
DRAW_CALL_WARNING = 350
DRAW_CALL_CRITICAL = 600
COMPLEXITY_WARNING = 40
NESTING_WARNING = 6
LINES_WARNING = 500
LINES_CRITICAL = 800
POOL_SIZE_DEFAULT = 8
SFX_ENUM_COUNT_DEFAULT = 27

# Known particle amounts from biome_particles.gd
PARTICLE_AMOUNTS: dict[str, int] = {
    "rain": 200,
    "fireflies": 30,
    "mist": 40,
    "snow": 100,
    "leaves": 25,
    "embers": 50,
    "spores": 20,
}

BIOME_PARTICLE_MAP: dict[str, list[str]] = {
    "foret_broceliande": ["mist", "fireflies"],
    "landes_bruyere": ["fireflies"],
    "cotes_sauvages": ["rain"],
    "marais_korrigans": ["mist"],
    "collines_dolmens": ["leaves"],
    "iles_mystiques": ["rain", "mist"],
    "cercles_pierres": ["embers"],
    "villages_celtes": ["leaves"],
}

# File extensions for memory estimation
TEXTURE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".tga"}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3"}
FONT_EXTENSIONS = {".ttf", ".otf", ".woff", ".woff2"}

# Directories to skip
SKIP_DIRS = {"archive", ".git", "node_modules", ".godot", "__pycache__", ".import"}


# ============================================================================
# Helpers
# ============================================================================

def _find_files(root: Path, extension: str, skip_archive: bool = True) -> list[Path]:
    """Find all files with a given extension under root, skipping archive dirs."""
    results: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune skipped directories in-place
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if skip_archive and "archive" in Path(dirpath).parts:
            continue
        for f in filenames:
            if f.lower().endswith(extension):
                results.append(Path(dirpath) / f)
    return results


def _relative(path: Path) -> str:
    """Return path relative to project root, using forward slashes."""
    try:
        return str(path.relative_to(PROJECT_ROOT)).replace("\\", "/")
    except ValueError:
        return str(path).replace("\\", "/")


# ============================================================================
# 1. Node Count Estimation
# ============================================================================

def analyze_node_counts(project_root: Path) -> dict[str, Any]:
    """Parse .tscn files and count [node ...] entries per scene."""
    tscn_files = _find_files(project_root / "scenes", ".tscn")
    per_scene: dict[str, int] = {}
    total = 0
    node_pattern = re.compile(r'^\[node\s+', re.MULTILINE)

    for tscn in tscn_files:
        try:
            content = tscn.read_text(encoding="utf-8", errors="replace")
            count = len(node_pattern.findall(content))
            rel = _relative(tscn)
            per_scene[rel] = count
            total += count
        except OSError:
            continue

    status = "ok"
    if total > NODE_BUDGET_CRITICAL:
        status = "critical"
    elif total > NODE_BUDGET_WARNING:
        status = "warning"

    return {
        "per_scene": per_scene,
        "total": total,
        "budget_warning": NODE_BUDGET_WARNING,
        "budget_critical": NODE_BUDGET_CRITICAL,
        "budget_status": status,
    }


# ============================================================================
# 2. Particle Budget
# ============================================================================

def analyze_particle_budget(project_root: Path) -> dict[str, Any]:
    """Sum max particles across all biomes (worst case: all biomes active)."""
    # Max concurrent = worst-case biome (largest particle sum)
    per_biome: dict[str, int] = {}
    worst_biome = ""
    worst_count = 0

    for biome_id, types in BIOME_PARTICLE_MAP.items():
        count = sum(PARTICLE_AMOUNTS.get(t, 0) for t in types)
        per_biome[biome_id] = count
        if count > worst_count:
            worst_count = count
            worst_biome = biome_id

    # Also scan for additional GPUParticles3D in scripts (broceliande_forest_3d etc.)
    extra_particles = _scan_extra_gpu_particles(project_root)

    max_concurrent = worst_count + extra_particles
    status = "ok"
    if max_concurrent > PARTICLE_RECOMMENDED_MAX:
        status = "warning" if max_concurrent < PARTICLE_RECOMMENDED_MAX * 2 else "critical"

    return {
        "per_biome": per_biome,
        "worst_biome": worst_biome,
        "worst_biome_particles": worst_count,
        "extra_gpu_particles_in_scripts": extra_particles,
        "max_concurrent": max_concurrent,
        "recommended_max": PARTICLE_RECOMMENDED_MAX,
        "particle_types": PARTICLE_AMOUNTS,
        "status": status,
    }


def _scan_extra_gpu_particles(project_root: Path) -> int:
    """Count GPUParticles3D.new() calls outside biome_particles.gd."""
    count = 0
    pattern = re.compile(r'GPUParticles3D\.new\(\)')
    scripts_dir = project_root / "scripts"
    biome_particles_path = scripts_dir / "run" / "biome_particles.gd"

    for gd_file in _find_files(scripts_dir, ".gd"):
        if gd_file.resolve() == biome_particles_path.resolve():
            continue
        try:
            content = gd_file.read_text(encoding="utf-8", errors="replace")
            count += len(pattern.findall(content))
        except OSError:
            continue
    return count


# ============================================================================
# 3. Signal Density
# ============================================================================

def analyze_signal_density(project_root: Path) -> dict[str, Any]:
    """Count signal declarations and .connect() calls per script."""
    signal_decl_re = re.compile(r'^signal\s+\w+', re.MULTILINE)
    connect_re = re.compile(r'\.connect\(')

    per_file: dict[str, dict[str, int]] = {}
    hotspots: list[dict[str, Any]] = []

    for gd_file in _find_files(project_root / "scripts", ".gd"):
        try:
            content = gd_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        declarations = len(signal_decl_re.findall(content))
        connections = len(connect_re.findall(content))
        total = declarations + connections
        rel = _relative(gd_file)

        per_file[rel] = {"declarations": declarations, "connections": connections, "total": total}

        if total >= SIGNAL_HOTSPOT_THRESHOLD:
            hotspots.append({"file": rel, "total": total, "declarations": declarations, "connections": connections})

    hotspots.sort(key=lambda x: x["total"], reverse=True)

    return {
        "per_file": per_file,
        "hotspots": hotspots,
        "hotspot_threshold": SIGNAL_HOTSPOT_THRESHOLD,
    }


# ============================================================================
# 4. Draw Call Estimation
# ============================================================================

def analyze_draw_calls(project_root: Path) -> dict[str, Any]:
    """Count MeshInstance3D, Sprite2D/3D, and UI Control nodes in .tscn files."""
    mesh_re = re.compile(r'type="MeshInstance3D"')
    sprite_re = re.compile(r'type="(?:Sprite2D|Sprite3D)"')
    ui_control_types = [
        "Control", "Panel", "PanelContainer", "Label", "RichTextLabel",
        "Button", "TextureButton", "TextureRect", "ColorRect",
        "HBoxContainer", "VBoxContainer", "MarginContainer", "CenterContainer",
        "GridContainer", "ScrollContainer", "TabContainer",
        "ProgressBar", "HSlider", "VSlider", "SpinBox",
        "LineEdit", "TextEdit", "OptionButton", "CheckBox", "CheckButton",
    ]
    ui_pattern = r'type="(?:' + "|".join(ui_control_types) + r')"'
    ui_re = re.compile(ui_pattern)

    meshes = 0
    sprites = 0
    ui_controls = 0

    for tscn in _find_files(project_root / "scenes", ".tscn"):
        try:
            content = tscn.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        meshes += len(mesh_re.findall(content))
        sprites += len(sprite_re.findall(content))
        ui_controls += len(ui_re.findall(content))

    total = meshes + sprites + ui_controls
    status = "ok"
    if total > DRAW_CALL_CRITICAL:
        status = "critical"
    elif total > DRAW_CALL_WARNING:
        status = "warning"

    return {
        "meshes": meshes,
        "sprites": sprites,
        "ui_controls": ui_controls,
        "total": total,
        "warning_threshold": DRAW_CALL_WARNING,
        "critical_threshold": DRAW_CALL_CRITICAL,
        "status": status,
    }


# ============================================================================
# 5. Memory Estimation
# ============================================================================

def analyze_memory(project_root: Path) -> dict[str, Any]:
    """Estimate memory from imported resources and scripts."""
    textures_bytes = 0
    textures_count = 0
    audio_bytes = 0
    audio_count = 0
    fonts_count = 0
    scripts_count = 0

    # Scan project for resource files (not in .import, archive, .git)
    for dirpath, dirnames, filenames in os.walk(project_root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            ext = os.path.splitext(f)[1].lower()
            full = Path(dirpath) / f
            try:
                size = full.stat().st_size
            except OSError:
                size = 0

            if ext in TEXTURE_EXTENSIONS:
                textures_bytes += size
                textures_count += 1
            elif ext in AUDIO_EXTENSIONS:
                audio_bytes += size
                audio_count += 1
            elif ext in FONT_EXTENSIONS:
                fonts_count += 1
            elif ext == ".gd":
                scripts_count += 1

    return {
        "textures_mb": round(textures_bytes / (1024 * 1024), 2),
        "textures_count": textures_count,
        "audio_mb": round(audio_bytes / (1024 * 1024), 2),
        "audio_count": audio_count,
        "fonts_count": fonts_count,
        "scripts_count": scripts_count,
    }


# ============================================================================
# 6. Tween Count
# ============================================================================

def analyze_tweens(project_root: Path) -> dict[str, Any]:
    """Find tween usage patterns and concurrent tween risks."""
    tween_var_re = re.compile(r'var\s+\w*tween\w*\s*:\s*Tween', re.IGNORECASE)
    create_tween_re = re.compile(r'create_tween\(\)')
    tween_property_re = re.compile(r'tween_property\(([^,]+),\s*"([^"]+)"')

    per_file: dict[str, dict[str, Any]] = {}
    concurrent_risks: list[dict[str, Any]] = []

    for gd_file in _find_files(project_root / "scripts", ".gd"):
        try:
            content = gd_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        tween_vars = len(tween_var_re.findall(content))
        creates = len(create_tween_re.findall(content))
        properties = tween_property_re.findall(content)

        if creates == 0 and tween_vars == 0:
            continue

        rel = _relative(gd_file)

        # Detect same property tweened multiple times (concurrent risk)
        prop_targets: dict[str, int] = {}
        for _target, prop in properties:
            key = prop.strip()
            prop_targets[key] = prop_targets.get(key, 0) + 1

        dupes = {k: v for k, v in prop_targets.items() if v > 1}

        per_file[rel] = {
            "tween_vars": tween_vars,
            "create_calls": creates,
            "property_tweens": len(properties),
            "duplicate_properties": dupes,
        }

        if dupes:
            concurrent_risks.append({
                "file": rel,
                "properties": dupes,
            })

    return {
        "per_file": per_file,
        "files_with_tweens": len(per_file),
        "concurrent_risks": concurrent_risks,
    }


# ============================================================================
# 7. Audio Pool
# ============================================================================

def analyze_audio_pool(project_root: Path) -> dict[str, Any]:
    """Verify pool size vs max concurrent sounds from sfx_manager.gd."""
    sfx_path = project_root / "scripts" / "audio" / "sfx_manager.gd"

    pool_size = POOL_SIZE_DEFAULT
    sfx_count = SFX_ENUM_COUNT_DEFAULT

    if sfx_path.exists():
        try:
            content = sfx_path.read_text(encoding="utf-8", errors="replace")

            # Extract POOL_SIZE
            pool_match = re.search(r'POOL_SIZE\s*[:=]\s*(?:int\s*=\s*)?(\d+)', content)
            if pool_match:
                pool_size = int(pool_match.group(1))

            # Count SFX enum members
            enum_match = re.search(r'enum\s+SFX\s*\{([^}]+)\}', content, re.DOTALL)
            if enum_match:
                enum_body = enum_match.group(1)
                members = [m.strip() for m in enum_body.split(",") if m.strip() and not m.strip().startswith("#")]
                sfx_count = len(members)
        except OSError:
            pass

    ratio = sfx_count / pool_size if pool_size > 0 else float("inf")
    status = "ok"
    if ratio > 5:
        status = "warning"
    if ratio > 10:
        status = "critical"

    return {
        "pool_size": pool_size,
        "sfx_count": sfx_count,
        "ratio_sfx_to_pool": round(ratio, 1),
        "status": status,
        "note": "Pool reuses players; ratio > 5 may cause sound drops under heavy usage",
    }


# ============================================================================
# 8. Script Complexity
# ============================================================================

def analyze_script_complexity(project_root: Path) -> list[dict[str, Any]]:
    """Analyze lines, nesting depth, and cyclomatic complexity estimate per script."""
    results: list[dict[str, Any]] = []

    # Data-only files: primarily const/static definitions, not runtime logic.
    # merlin_constants.gd excluded: contains infer_reward_type() with match/for.
    DATA_FILE_NAMES = {
        "sprite_templates.gd", "pixel_scene_data.gd",
        "merlin_visual.gd",
    }

    for gd_file in _find_files(project_root / "scripts", ".gd"):
        # Skip test files — they don't affect runtime performance
        if "test" in gd_file.parts or gd_file.name.startswith("test_"):
            continue
        # Skip data-heavy files — constants/templates don't affect runtime complexity
        if gd_file.name in DATA_FILE_NAMES:
            continue
        try:
            content = gd_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        lines = content.splitlines()
        line_count = len(lines)
        max_nesting = _compute_max_nesting(lines)
        complexity = _estimate_cyclomatic_complexity(content)

        status = "ok"
        issues: list[str] = []
        if line_count > LINES_CRITICAL:
            status = "critical"
            issues.append(f">{LINES_CRITICAL} lines")
        elif line_count > LINES_WARNING:
            status = "warning"
            issues.append(f">{LINES_WARNING} lines")
        if max_nesting > NESTING_WARNING:
            status = "warning" if status == "ok" else status
            issues.append(f"nesting={max_nesting}")
        if complexity > COMPLEXITY_WARNING:
            status = "warning" if status == "ok" else status
            issues.append(f"complexity={complexity}")

        rel = _relative(gd_file)
        results.append({
            "file": rel,
            "lines": line_count,
            "max_nesting": max_nesting,
            "complexity": complexity,
            "status": status,
            "issues": issues,
        })

    results.sort(key=lambda x: x["lines"], reverse=True)
    return results


def _compute_max_nesting(lines: list[str]) -> int:
    """Estimate max indentation nesting depth (tab-based, 1 tab = 1 level)."""
    max_depth = 0
    for line in lines:
        stripped = line.rstrip()
        if not stripped or stripped.startswith("#"):
            continue
        # Count leading tabs
        tabs = len(line) - len(line.lstrip("\t"))
        if tabs > max_depth:
            max_depth = tabs
    return max_depth


def _estimate_cyclomatic_complexity(content: str) -> int:
    """Rough cyclomatic complexity: count decision points."""
    # Each if/elif/for/while/match/and/or adds 1 to complexity
    decision_keywords = [
        r'\bif\b', r'\belif\b', r'\bfor\b', r'\bwhile\b',
        r'\bmatch\b', r'\band\b', r'\bor\b',
    ]
    complexity = 1  # base
    for pattern in decision_keywords:
        complexity += len(re.findall(pattern, content))
    return complexity


# ============================================================================
# Summary Scoring
# ============================================================================

def compute_summary(
    node_budget: dict[str, Any],
    particle_budget: dict[str, Any],
    signal_density: dict[str, Any],
    draw_calls: dict[str, Any],
    memory_estimate: dict[str, Any],
    tweens: dict[str, Any],
    audio_pool: dict[str, Any],
    script_complexity: list[dict[str, Any]],
) -> dict[str, Any]:
    """Compute overall score 0-100 and list bottlenecks."""
    score = 100
    bottlenecks: list[str] = []

    # Node budget
    if node_budget["budget_status"] == "critical":
        score -= 20
        bottlenecks.append(f"Node count {node_budget['total']} exceeds critical threshold {NODE_BUDGET_CRITICAL}")
    elif node_budget["budget_status"] == "warning":
        score -= 10
        bottlenecks.append(f"Node count {node_budget['total']} exceeds warning threshold {NODE_BUDGET_WARNING}")

    # Particles
    if particle_budget["status"] == "critical":
        score -= 20
        bottlenecks.append(f"Particle budget {particle_budget['max_concurrent']} is very high")
    elif particle_budget["status"] == "warning":
        score -= 10
        bottlenecks.append(f"Particle budget {particle_budget['max_concurrent']} exceeds {PARTICLE_RECOMMENDED_MAX}")

    # Signals
    hotspot_count = len(signal_density["hotspots"])
    if hotspot_count > 5:
        score -= 10
        bottlenecks.append(f"{hotspot_count} signal hotspot files (>{SIGNAL_HOTSPOT_THRESHOLD} signals+connects)")
    elif hotspot_count > 0:
        score -= 5

    # Draw calls
    if draw_calls["status"] == "critical":
        score -= 15
        bottlenecks.append(f"Estimated draw calls {draw_calls['total']} exceeds critical threshold")
    elif draw_calls["status"] == "warning":
        score -= 8
        bottlenecks.append(f"Estimated draw calls {draw_calls['total']} exceeds warning threshold")

    # Concurrent tween risks (note: static analysis may flag false positives
    # when different nodes share the same property name like "modulate:a")
    risk_count = len(tweens["concurrent_risks"])
    if risk_count > 40:
        score -= 5
        bottlenecks.append(f"{risk_count} files with potential concurrent tween risks (review recommended)")
    elif risk_count > 15:
        score -= 3

    # Audio pool
    if audio_pool["status"] == "critical":
        score -= 10
        bottlenecks.append(f"Audio pool ratio {audio_pool['ratio_sfx_to_pool']}:1 — sound drops likely")
    elif audio_pool["status"] == "warning":
        score -= 5
        bottlenecks.append(f"Audio pool ratio {audio_pool['ratio_sfx_to_pool']}:1 — may drop sounds")

    # Script complexity — count critical/warning files
    critical_scripts = [s for s in script_complexity if s["status"] == "critical"]
    warning_scripts = [s for s in script_complexity if s["status"] == "warning"]
    if len(critical_scripts) > 10:
        score -= 10
        bottlenecks.append(f"{len(critical_scripts)} scripts exceed {LINES_CRITICAL} lines (refactoring recommended)")
    elif len(critical_scripts) > 3:
        score -= 5
        bottlenecks.append(f"{len(critical_scripts)} scripts exceed {LINES_CRITICAL} lines")
    # Flag when >30% of scripts are in warning state (proportional to project size)
    if len(warning_scripts) > 30:
        score -= 5

    score = max(0, min(100, score))

    return {
        "score": score,
        "bottlenecks": bottlenecks,
        "pass": score >= 60,
        "grade": _score_grade(score),
    }


def _score_grade(score: int) -> str:
    if score >= 90:
        return "A"
    if score >= 80:
        return "B"
    if score >= 70:
        return "C"
    if score >= 60:
        return "D"
    return "F"


# ============================================================================
# Main
# ============================================================================

def run_audit(project_root: Path) -> dict[str, Any]:
    """Run all analyses and return the full report."""
    node_budget = analyze_node_counts(project_root)
    particle_budget = analyze_particle_budget(project_root)
    signal_density = analyze_signal_density(project_root)
    draw_calls = analyze_draw_calls(project_root)
    memory_estimate = analyze_memory(project_root)
    tweens = analyze_tweens(project_root)
    audio_pool = analyze_audio_pool(project_root)
    script_complexity = analyze_script_complexity(project_root)

    summary = compute_summary(
        node_budget, particle_budget, signal_density, draw_calls,
        memory_estimate, tweens, audio_pool, script_complexity,
    )

    return {
        "node_budget": node_budget,
        "particle_budget": particle_budget,
        "signal_density": signal_density,
        "draw_calls_estimate": draw_calls,
        "memory_estimate": memory_estimate,
        "tween_analysis": tweens,
        "audio_pool": audio_pool,
        "script_complexity": script_complexity,
        "summary": summary,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="M.E.R.L.I.N. Performance Audit — Static code analysis for Godot 4.x"
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--root",
        type=str,
        default=str(PROJECT_ROOT),
        help="Project root directory (default: auto-detected)",
    )
    parser.add_argument(
        "--compact",
        action="store_true",
        help="Compact JSON output (no indentation)",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Only output the summary section",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not (root / "project.godot").exists():
        print(f"ERROR: {root} does not appear to be a Godot project (no project.godot)", file=sys.stderr)
        sys.exit(1)

    report = run_audit(root)

    if args.summary_only:
        output_data = report["summary"]
    else:
        output_data = report

    indent = None if args.compact else 2
    json_str = json.dumps(output_data, indent=indent, ensure_ascii=False)

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json_str, encoding="utf-8")
        print(f"Report written to {out_path}", file=sys.stderr)
    else:
        print(json_str)

    # Exit code based on pass/fail
    if not report["summary"]["pass"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
