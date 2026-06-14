# -*- coding: utf-8 -*-
"""Calligraphy forge M.E.R.L.I.N. — handwriting stroke synthesis (BIBLE §20).

Generates organic handwriting stroke sequences for the "Merlin écrit…" animation.
Outputs JSON stroke data (x, y, pen_up) for Godot Line2D replay, or rasterized
PNG via Pillow.

Procedural approach: each glyph is decomposed into stroke primitives (arcs,
lines, loops) with jitter for organic feel. No ML dependency — works immediately.

Usage:
    python tools/calligraphy_forge.py --text "Merlin" --output strokes.json
    python tools/calligraphy_forge.py --text "Brocéliande" --format png --output title.png
    python tools/calligraphy_forge.py --text "Test" --format svg --output test.svg
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

# ── Palette (merlin_visual.gd) ──────────────────────────────────────────────

INK_RGB = (0x2A, 0x20, 0x18)
CREAM_RGB = (0xE8, 0xDC, 0xC0)


# ── Stroke primitives ──────────────────────────────────────────────────────

@dataclass(frozen=True)
class StrokePoint:
    x: float
    y: float
    pen_up: bool = False

    def to_dict(self) -> dict:
        return {"x": round(self.x, 2), "y": round(self.y, 2), "pen_up": self.pen_up}


def _arc(cx: float, cy: float, rx: float, ry: float,
         start_angle: float, end_angle: float, steps: int = 12,
         rng: random.Random | None = None) -> list[StrokePoint]:
    jitter = 0.8 if rng else 0.0
    points: list[StrokePoint] = []
    for i in range(steps + 1):
        t = i / steps
        angle = start_angle + t * (end_angle - start_angle)
        jx = rng.gauss(0, jitter) if rng else 0.0
        jy = rng.gauss(0, jitter) if rng else 0.0
        points.append(StrokePoint(cx + rx * math.cos(angle) + jx,
                                  cy + ry * math.sin(angle) + jy))
    return points


def _line(x0: float, y0: float, x1: float, y1: float,
          steps: int = 6, rng: random.Random | None = None) -> list[StrokePoint]:
    jitter = 0.6 if rng else 0.0
    points: list[StrokePoint] = []
    for i in range(steps + 1):
        t = i / steps
        jx = rng.gauss(0, jitter) if rng else 0.0
        jy = rng.gauss(0, jitter) if rng else 0.0
        points.append(StrokePoint(x0 + t * (x1 - x0) + jx,
                                  y0 + t * (y1 - y0) + jy))
    return points


# ── Glyph builder ───────────────────────────────────────────────────────────

def _glyph_generic(char: str, x: float, rng: random.Random) -> tuple[list[list[StrokePoint]], float]:
    strokes = [_line(x + 5, 0, x + 5, -18, rng=rng)]
    return strokes, 12.0


def _build_glyph(char: str, x: float, rng: random.Random) -> tuple[list[list[StrokePoint]], float]:
    c = char.lower()

    if c == 'm':
        s1 = _line(x, 0, x, -18, rng=rng)
        s2 = _line(x, -18, x + 6, -4, rng=rng) + _line(x + 6, -4, x + 12, -18, rng=rng)
        s3 = _line(x + 12, -18, x + 12, 0, rng=rng)
        return [s1, s2, s3], 16.0

    if c == 'e':
        s1 = _arc(x + 6, -9, 6, 9, -0.3, math.pi * 1.6, rng=rng)
        return [s1], 14.0

    if c == 'r':
        s1 = _line(x + 2, 0, x + 2, -18, rng=rng)
        s2 = _arc(x + 2, -14, 6, 4, -math.pi / 2, math.pi / 4, rng=rng)
        return [s1, s2], 12.0

    if c == 'l':
        s1 = _line(x + 3, -20, x + 3, 0, rng=rng)
        return [s1], 8.0

    if c == 'i':
        s1 = _line(x + 3, -14, x + 3, 0, rng=rng)
        s2 = [StrokePoint(x + 3, -18)]
        return [s1, s2], 8.0

    if c == 'n':
        s1 = _line(x + 2, 0, x + 2, -14, rng=rng)
        s2 = _arc(x + 7, -14, 5, 6, math.pi, 0, rng=rng) + _line(x + 12, -8, x + 12, 0, rng=rng)
        return [s1, s2], 16.0

    if c == 'a':
        s1 = _arc(x + 7, -7, 6, 7, 0.3, math.pi * 2.0, rng=rng)
        s2 = _line(x + 13, -14, x + 13, 0, rng=rng)
        return [s1, s2], 16.0

    if c == 'o':
        s1 = _arc(x + 7, -7, 6, 7, 0, math.pi * 2, rng=rng)
        return [s1], 16.0

    if c == 'b':
        s1 = _line(x + 2, -20, x + 2, 0, rng=rng)
        s2 = _arc(x + 7, -7, 5, 7, -math.pi / 2, math.pi * 1.5, rng=rng)
        return [s1, s2], 14.0

    if c == 'c':
        s1 = _arc(x + 8, -7, 6, 7, 0.5, math.pi * 1.8, rng=rng)
        return [s1], 14.0

    if c == 'd':
        s1 = _arc(x + 7, -7, 5, 7, math.pi * 1.5, math.pi * 3.5, rng=rng)
        s2 = _line(x + 12, -20, x + 12, 0, rng=rng)
        return [s1, s2], 16.0

    if c in ('é', 'è', 'ê'):
        s1 = _arc(x + 6, -9, 6, 9, -0.3, math.pi * 1.6, rng=rng)
        s2 = _line(x + 5, -20, x + 8, -18, rng=rng)
        return [s1, s2], 14.0

    if c == 't':
        s1 = _line(x + 5, -20, x + 5, 0, rng=rng)
        s2 = _line(x + 1, -13, x + 9, -13, rng=rng)
        return [s1, s2], 12.0

    if c == 's':
        s1 = _arc(x + 6, -11, 5, 4, -0.3, math.pi, rng=rng)
        s2 = _arc(x + 6, -4, 5, 4, math.pi, math.pi * 2.3, rng=rng)
        return [s1, s2], 14.0

    if c == 'u':
        s1 = _line(x + 2, -14, x + 2, -4, rng=rng)
        s1 += _arc(x + 7, -4, 5, 4, math.pi, 0, rng=rng)
        s1 += _line(x + 12, -4, x + 12, 0, rng=rng)
        return [s1], 16.0

    if c == 'p':
        s1 = _line(x + 2, -14, x + 2, 6, rng=rng)
        s2 = _arc(x + 7, -7, 5, 7, -math.pi / 2, math.pi * 1.5, rng=rng)
        return [s1, s2], 14.0

    if c == 'g':
        s1 = _arc(x + 7, -7, 6, 7, 0, math.pi * 2, rng=rng)
        s2 = _line(x + 13, -7, x + 13, 6, rng=rng) + _arc(x + 8, 6, 5, 4, 0, math.pi, rng=rng)
        return [s1, s2], 16.0

    if c == 'h':
        s1 = _line(x + 2, -20, x + 2, 0, rng=rng)
        s2 = _arc(x + 7, -14, 5, 6, math.pi, 0, rng=rng) + _line(x + 12, -8, x + 12, 0, rng=rng)
        return [s1, s2], 16.0

    if c == 'f':
        s1 = _arc(x + 8, -18, 4, 3, math.pi / 2, math.pi, rng=rng) + _line(x + 4, -15, x + 4, 0, rng=rng)
        s2 = _line(x + 1, -10, x + 9, -10, rng=rng)
        return [s1, s2], 12.0

    if c == 'v':
        s1 = _line(x + 1, -14, x + 7, 0, rng=rng)
        s2 = _line(x + 7, 0, x + 13, -14, rng=rng)
        return [s1, s2], 16.0

    if c == 'w':
        s1 = _line(x, -14, x + 4, 0, rng=rng) + _line(x + 4, 0, x + 8, -10, rng=rng)
        s2 = _line(x + 8, -10, x + 12, 0, rng=rng) + _line(x + 12, 0, x + 16, -14, rng=rng)
        return [s1, s2], 20.0

    if c == 'x':
        s1 = _line(x + 2, -14, x + 12, 0, rng=rng)
        s2 = _line(x + 12, -14, x + 2, 0, rng=rng)
        return [s1, s2], 16.0

    if c == 'y':
        s1 = _line(x + 2, -14, x + 7, -4, rng=rng)
        s2 = _line(x + 12, -14, x + 5, 6, rng=rng)
        return [s1, s2], 16.0

    if c == 'z':
        s1 = _line(x + 2, -14, x + 12, -14, rng=rng) + _line(x + 12, -14, x + 2, 0, rng=rng) + _line(x + 2, 0, x + 12, 0, rng=rng)
        return [s1], 16.0

    if c == 'j':
        s1 = _line(x + 6, -14, x + 6, 2, rng=rng) + _arc(x + 3, 2, 3, 4, 0, math.pi / 2, rng=rng)
        s2 = [StrokePoint(x + 6, -18)]
        return [s1, s2], 10.0

    if c == 'k':
        s1 = _line(x + 2, -20, x + 2, 0, rng=rng)
        s2 = _line(x + 10, -14, x + 2, -7, rng=rng) + _line(x + 2, -7, x + 10, 0, rng=rng)
        return [s1, s2], 14.0

    if c == 'q':
        s1 = _arc(x + 7, -7, 6, 7, 0, math.pi * 2, rng=rng)
        s2 = _line(x + 13, -7, x + 13, 6, rng=rng)
        return [s1, s2], 16.0

    if c == ' ':
        return [], 10.0

    if c == '.':
        return [[StrokePoint(x + 3, -1)]], 8.0

    if c == ',':
        return [_line(x + 3, -1, x + 2, 3, steps=3, rng=rng)], 8.0

    if c in ('…', '—'):
        return [_line(x, -4, x + 16, -4, rng=rng)], 20.0

    if c == "'":
        return [_line(x + 3, -18, x + 2, -14, steps=3, rng=rng)], 6.0

    if c == '!':
        s1 = _line(x + 3, -18, x + 3, -4, rng=rng)
        s2 = [StrokePoint(x + 3, -1)]
        return [s1, s2], 8.0

    if c == '?':
        s1 = _arc(x + 6, -14, 5, 4, math.pi, 0, rng=rng) + _line(x + 6, -10, x + 6, -5, steps=4, rng=rng)
        s2 = [StrokePoint(x + 6, -1)]
        return [s1, s2], 14.0

    return _glyph_generic(char, x, rng)


# ── Public API ──────────────────────────────────────────────────────────────

MAX_TEXT_LENGTH = 512


def synthesize(text: str, seed: int = 42, scale: float = 1.0,
               baseline_y: float = 30.0) -> list[list[dict]]:
    """Generate stroke data for text.

    Returns list of strokes, each stroke is a list of {x, y, pen_up} dicts.
    """
    if not text or not text.strip():
        return []
    if len(text) > MAX_TEXT_LENGTH:
        raise ValueError(f"text too long ({len(text)} chars, max {MAX_TEXT_LENGTH})")

    rng = random.Random(seed)
    all_strokes: list[list[dict]] = []
    cursor_x = 10.0

    for char in text:
        glyph_strokes, advance = _build_glyph(char, cursor_x, rng)
        for stroke in glyph_strokes:
            points = []
            for i, sp in enumerate(stroke):
                points.append({
                    "x": round(sp.x * scale, 2),
                    "y": round((baseline_y + sp.y) * scale, 2),
                    "pen_up": True if i == 0 else sp.pen_up,
                })
            if points:
                all_strokes.append(points)
        cursor_x += advance + rng.gauss(0, 0.8)

    return all_strokes


def render_png(text: str, seed: int = 42, scale: float = 2.0,
               width: int | None = None, height: int = 80) -> "Image.Image":
    from PIL import Image, ImageDraw

    strokes = synthesize(text, seed, scale, baseline_y=height * 0.6 / scale)

    if width is None:
        max_x = max((p["x"] for s in strokes for p in s), default=100)
        width = int(max_x + 20)

    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    for stroke in strokes:
        for i in range(len(stroke) - 1):
            if not stroke[i + 1]["pen_up"]:
                draw.line(
                    [(stroke[i]["x"], stroke[i]["y"]),
                     (stroke[i + 1]["x"], stroke[i + 1]["y"])],
                    fill=INK_RGB + (255,), width=2,
                )

    return img


def render_svg(text: str, seed: int = 42, scale: float = 2.0,
               height: int = 80) -> str:
    strokes = synthesize(text, seed, scale, baseline_y=height * 0.6 / scale)
    max_x = max((p["x"] for s in strokes for p in s), default=100)
    width = int(max_x + 20)

    ink_hex = f"#{INK_RGB[0]:02x}{INK_RGB[1]:02x}{INK_RGB[2]:02x}"
    paths: list[str] = []

    for stroke in strokes:
        if len(stroke) < 2:
            continue
        d = f"M {stroke[0]['x']:.1f} {stroke[0]['y']:.1f}"
        for p in stroke[1:]:
            if p["pen_up"]:
                d += f" M {p['x']:.1f} {p['y']:.1f}"
            else:
                d += f" L {p['x']:.1f} {p['y']:.1f}"
        paths.append(f'  <path d="{d}" fill="none" stroke="{ink_hex}" '
                     f'stroke-width="2" stroke-linecap="round"/>')

    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}">\n'
           + "\n".join(paths)
           + "\n</svg>")
    return svg


def list_glyphs() -> dict:
    """List supported glyphs with metadata."""
    supported = list("abcdefghijklmnopqrstuvwxyz") + ["é", "è", "ê"]
    punctuation = list(" .,!?'…—")
    return {
        "letters": sorted(supported),
        "punctuation": punctuation,
        "total": len(supported) + len(punctuation),
        "fallback": "vertical stroke for unknown characters",
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN calligraphy stroke generator")
    parser.add_argument("--text", type=str, help="Text to render")
    parser.add_argument("--format", type=str, default="json",
                        choices=["json", "png", "svg"])
    parser.add_argument("--output", type=str, help="Output file path")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--scale", type=float, default=2.0)
    parser.add_argument("--height", type=int, default=80)
    parser.add_argument("--list-glyphs", action="store_true")

    args = parser.parse_args(argv)

    if args.list_glyphs:
        print(json.dumps(list_glyphs(), indent=2, ensure_ascii=False))
        return 0

    if not args.text:
        print("ERROR: --text required (or --list-glyphs)", file=sys.stderr)
        return 1

    out_path = None
    if args.output:
        _resolved = Path(args.output).expanduser().resolve()
        try:
            _resolved.relative_to(Path.home().resolve())
            out_path = _resolved
        except ValueError:
            print(f"ERROR: output path outside home directory: {args.output}",
                  file=sys.stderr)
            return 1

    if args.format == "json":
        strokes = synthesize(args.text, args.seed, args.scale)
        data = {"text": args.text, "seed": args.seed, "stroke_count": len(strokes),
                "strokes": strokes}
        content = json.dumps(data, indent=2, ensure_ascii=False)
        if out_path:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(content, encoding="utf-8")
            print(f"OK: {len(strokes)} strokes -> {out_path}")
        else:
            print(content)

    elif args.format == "png":
        img = render_png(args.text, args.seed, args.scale, height=args.height)
        if out_path:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            img.save(str(out_path))
            print(f"OK: {img.size[0]}x{img.size[1]} -> {out_path}")
        else:
            print("ERROR: --output required for PNG format", file=sys.stderr)
            return 1

    elif args.format == "svg":
        svg = render_svg(args.text, args.seed, args.scale, args.height)
        if out_path:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(svg, encoding="utf-8")
            print(f"OK: SVG -> {out_path}")
        else:
            print(svg)

    return 0


if __name__ == "__main__":
    sys.exit(main())
