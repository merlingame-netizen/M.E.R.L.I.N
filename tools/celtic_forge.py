# -*- coding: utf-8 -*-
"""Celtic forge M.E.R.L.I.N. — procedural knotwork patterns (BIBLE §20).

Generates Celtic interlace/knotwork patterns for card borders, UI dividers,
and decorative elements. Uses a lattice-based crossing algorithm inspired by
Andy Sloss's method (public domain).

Patterns are rendered in INK on transparent background (or CREAM if opaque),
directly in-palette — no sepia post-processing needed.

Usage:
    python tools/celtic_forge.py --type border --width 800 --height 60
    python tools/celtic_forge.py --type knot --grid 4x4 --output knot.png
    python tools/celtic_forge.py --type divider --width 600
    python tools/celtic_forge.py --list-types
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw

# ── Palette (merlin_visual.gd) ──────────────────────────────────────────────

INK = (0x2A, 0x20, 0x18, 255)
CREAM = (0xE8, 0xDC, 0xC0, 255)
GOLD = (0xC9, 0xA2, 0x4B, 255)
BG_PAGE = (0x1E, 0x1A, 0x14, 255)
TRANSPARENT = (0, 0, 0, 0)


# ── Pattern types ───────────────────────────────────────────────────────────

@dataclass(frozen=True)
class PatternSpec:
    name: str
    default_width: int
    default_height: int
    grid_cols: int
    grid_rows: int
    description: str


PATTERN_SPECS: dict[str, PatternSpec] = {
    "border":  PatternSpec("border",  800, 60,  12, 1, "Horizontal band for card/panel frames"),
    "divider": PatternSpec("divider", 600, 20,  10, 0, "Thin horizontal separator"),
    "knot":    PatternSpec("knot",    200, 200, 4,  4, "Square knotwork tile"),
    "corner":  PatternSpec("corner",  100, 100, 2,  2, "Corner ornament"),
}


# ── Lattice knotwork generator ──────────────────────────────────────────────

def _generate_crossings(cols: int, rows: int) -> list[list[bool]]:
    """Generate over/under crossing pattern. Alternating ensures valid interlace."""
    return [[(r + c) % 2 == 0 for c in range(cols)] for r in range(rows)]


def _bezier_point(p0: tuple[float, float], p1: tuple[float, float],
                  p2: tuple[float, float], p3: tuple[float, float],
                  t: float) -> tuple[float, float]:
    u = 1.0 - t
    return (u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1])


def _draw_strand(draw: ImageDraw.ImageDraw,
                 p0: tuple[float, float], p1: tuple[float, float],
                 p2: tuple[float, float], p3: tuple[float, float],
                 color: tuple[int, int, int, int],
                 width: int, steps: int = 20) -> None:
    points = [_bezier_point(p0, p1, p2, p3, t / steps) for t in range(steps + 1)]
    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=color, width=width)


def generate_border(width: int, height: int, cols: int,
                    color: tuple[int, int, int, int] = INK,
                    bg: tuple[int, int, int, int] = TRANSPARENT,
                    strand_width: int = 3) -> Image.Image:
    img = Image.new("RGBA", (width, height), bg)
    draw = ImageDraw.Draw(img)

    cell_w = width / max(cols, 1)
    mid_y = height / 2.0
    amp = height * 0.35
    crossings = _generate_crossings(cols, 1)

    for c in range(cols):
        x0 = c * cell_w
        x1 = (c + 0.5) * cell_w
        x2 = (c + 1) * cell_w
        over = crossings[0][c]
        y_peak = mid_y - amp if over else mid_y + amp
        y_valley = mid_y + amp if over else mid_y - amp

        _draw_strand(draw, (x0, mid_y), (x0 + cell_w * 0.15, y_peak),
                     (x1 - cell_w * 0.15, y_peak), (x1, mid_y), color, strand_width)
        _draw_strand(draw, (x1, mid_y), (x1 + cell_w * 0.15, y_valley),
                     (x2 - cell_w * 0.15, y_valley), (x2, mid_y), color, strand_width)

    for c in range(cols):
        x0 = (c + 0.5) * cell_w
        x1 = (c + 1.0) * cell_w
        x2 = (c + 1.5) * cell_w
        over = not crossings[0][c]
        y_peak = mid_y - amp * 0.8 if over else mid_y + amp * 0.8
        y_valley = mid_y + amp * 0.8 if over else mid_y - amp * 0.8

        if x2 <= width + cell_w * 0.5:
            _draw_strand(draw, (x0, mid_y), (x0 + cell_w * 0.15, y_peak),
                         (x1 - cell_w * 0.15, y_peak), (x1, mid_y), color, strand_width)
            if x2 <= width:
                _draw_strand(draw, (x1, mid_y), (x1 + cell_w * 0.15, y_valley),
                             (x2 - cell_w * 0.15, y_valley), (x2, mid_y), color, strand_width)
    return img


def generate_knot(width: int, height: int, grid_cols: int, grid_rows: int,
                  color: tuple[int, int, int, int] = INK,
                  bg: tuple[int, int, int, int] = TRANSPARENT,
                  strand_width: int = 3) -> Image.Image:
    img = Image.new("RGBA", (width, height), bg)
    draw = ImageDraw.Draw(img)

    cell_w = width / max(grid_cols, 1)
    cell_h = height / max(grid_rows, 1)
    crossings = _generate_crossings(grid_cols, grid_rows)

    for r in range(grid_rows):
        for c in range(grid_cols):
            cx = (c + 0.5) * cell_w
            cy = (r + 0.5) * cell_h
            rx, ry = cell_w * 0.35, cell_h * 0.35
            over = crossings[r][c]

            if over:
                _draw_strand(draw, (cx - rx, cy), (cx - rx * 0.3, cy - ry),
                             (cx + rx * 0.3, cy - ry), (cx + rx, cy), color, strand_width)
                _draw_strand(draw, (cx, cy - ry), (cx + rx, cy - ry * 0.3),
                             (cx + rx, cy + ry * 0.3), (cx, cy + ry), color, strand_width)
            else:
                _draw_strand(draw, (cx - rx, cy), (cx - rx * 0.3, cy + ry),
                             (cx + rx * 0.3, cy + ry), (cx + rx, cy), color, strand_width)
                _draw_strand(draw, (cx, cy - ry), (cx - rx, cy - ry * 0.3),
                             (cx - rx, cy + ry * 0.3), (cx, cy + ry), color, strand_width)

    for r in range(grid_rows):
        for c in range(grid_cols - 1):
            x = (c + 1) * cell_w
            cy = (r + 0.5) * cell_h
            draw.line([(x - 2, cy), (x + 2, cy)], fill=color, width=strand_width)
    for r in range(grid_rows - 1):
        for c in range(grid_cols):
            cx = (c + 0.5) * cell_w
            y = (r + 1) * cell_h
            draw.line([(cx, y - 2), (cx, y + 2)], fill=color, width=strand_width)

    return img


def generate_divider(width: int, height: int = 20, cols: int = 10,
                     color: tuple[int, int, int, int] = INK,
                     bg: tuple[int, int, int, int] = TRANSPARENT) -> Image.Image:
    return generate_border(width, height, cols, color, bg, strand_width=2)


def generate_corner(width: int, height: int,
                    color: tuple[int, int, int, int] = INK,
                    bg: tuple[int, int, int, int] = TRANSPARENT) -> Image.Image:
    return generate_knot(width, height, 2, 2, color, bg, strand_width=2)


# ── Public API ──────────────────────────────────────────────────────────────

def generate(pattern_type: str, width: int | None = None, height: int | None = None,
             grid: str | None = None, color_name: str = "ink",
             bg_name: str = "transparent", output: str | Path | None = None) -> dict:
    spec = PATTERN_SPECS.get(pattern_type)
    if spec is None:
        return {"error": f"Unknown type {pattern_type!r}. Available: {list(PATTERN_SPECS)}"}

    w = width or spec.default_width
    h = height or spec.default_height
    cols, rows = spec.grid_cols, spec.grid_rows

    if grid:
        parts = grid.split("x")
        if len(parts) == 2:
            try:
                cols = max(1, min(int(parts[0]), 64))
                rows = max(1, min(int(parts[1]), 64))
            except ValueError:
                return {"error": f"Invalid grid format {grid!r}. Expected NxM (e.g. 4x4)"}

    color_map = {"ink": INK, "cream": CREAM, "gold": GOLD, "bg_page": BG_PAGE}
    bg_map = {"transparent": TRANSPARENT, "cream": CREAM, "bg_page": BG_PAGE, "ink": INK}
    color = color_map.get(color_name, INK)
    bg = bg_map.get(bg_name, TRANSPARENT)

    match pattern_type:
        case "border":  img = generate_border(w, h, cols, color, bg)
        case "divider": img = generate_divider(w, h, cols, color, bg)
        case "knot":    img = generate_knot(w, h, cols, rows, color, bg)
        case "corner":  img = generate_corner(w, h, color, bg)
        case _: return {"error": f"Unimplemented: {pattern_type}"}

    w = max(1, min(w, 4096))
    h = max(1, min(h, 4096))

    result: dict = {"type": pattern_type, "width": w, "height": h, "grid": f"{cols}x{rows}"}
    if output:
        out_path = Path(output).resolve()
        _home = Path.home().resolve()
        try:
            out_path.relative_to(_home)
        except ValueError:
            return {"error": f"Output path outside allowed directory: {output}"}
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(out_path))
        result["output"] = str(out_path)
    else:
        result["output"] = None
    return result


def list_types() -> dict[str, dict]:
    return {
        name: {"default_width": s.default_width, "default_height": s.default_height,
               "grid": f"{s.grid_cols}x{s.grid_rows}", "description": s.description}
        for name, s in PATTERN_SPECS.items()
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN Celtic knotwork generator")
    parser.add_argument("--type", type=str, choices=list(PATTERN_SPECS))
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--grid", type=str, help="Grid size (e.g. 4x4)")
    parser.add_argument("--color", type=str, default="ink",
                        choices=["ink", "cream", "gold", "bg_page"])
    parser.add_argument("--bg", type=str, default="transparent",
                        choices=["transparent", "cream", "bg_page", "ink"])
    parser.add_argument("--output", type=str)
    parser.add_argument("--list-types", action="store_true")

    args = parser.parse_args(argv)

    if args.list_types:
        for name, info in list_types().items():
            print(f"  {name:10s}  {info['default_width']}x{info['default_height']}  "
                  f"grid={info['grid']}  {info['description']}")
        return 0

    if not args.type:
        print("ERROR: --type required (or --list-types)", file=sys.stderr)
        return 1

    import json
    result = generate(args.type, args.width, args.height, args.grid,
                      args.color, args.bg, args.output)
    print(json.dumps(result, indent=2))
    return 0 if "error" not in result else 1


if __name__ == "__main__":
    sys.exit(main())
