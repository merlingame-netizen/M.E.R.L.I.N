# -*- coding: utf-8 -*-
"""Sprite-anim forge M.E.R.L.I.N. — generative animated sprite sequences (BIBLE §20/§24).

Procedural-first (PIL only, zero heavy deps) generator of style-coherent ANIMATION
sequences, packed as a horizontal sprite-sheet PNG + a Godot 4.5 SpriteFrames .tres
directly consumable by AnimatedSprite2D. Mirrors the sd_forge.py structure: frozen
dataclass templates, sha1 cache + manifest, status()/list_templates()/generate() API.

Procedural frames are drawn ONLY in the canonical palette (mirror of merlin_visual.gd —
the agreed Python-side mirror, same as sepia_forge/sd_forge) on a transparent ground, so
they are in-palette by construction and need NO sepia post-process (which would flatten
alpha). The SD img2img path of the design was intentionally dropped (flickery, no MVP
consumer — YAGNI); add later behind a backend flag if a real need appears.

Usage:
    python tools/sprite_anim_forge.py --template shimmer --seed 42
    python tools/sprite_anim_forge.py --template ember_drift --frames 16 --size 128x128
    python tools/sprite_anim_forge.py --list-templates
    python tools/sprite_anim_forge.py --status
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import random
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence

# ── Canonical palette (mirror of merlin_visual.gd — DA flat sépia/gravure, R115) ────────
# RGB tuples, identical to the values asset_validator.py / sepia_forge.py mirror.

INK = (0x2A, 0x20, 0x18)
CREAM = (0xE8, 0xDC, 0xC0)
GOLD = (0xC9, 0xA2, 0x4B)
BG_DEEP = (0x14, 0x10, 0x0C)

_TAU = math.tau

# Largeur totale max d'une feuille (n × cell_w). Borne SOUS la limite d'import Godot (32768px) ET
# garde une taille de fichier raisonnable. Si dépassement → on réduit le nombre de frames (jamais
# une feuille non-importable). 8192 = 64 frames @128px ou 85 @96px : largement suffisant.
MAX_SHEET_W: int = 8192


# ── Animation templates ─────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class AnimTemplate:
    name: str
    renderer: str          # key into _RENDERERS
    frames: int
    cell_w: int
    cell_h: int
    fps: int
    loop: bool
    description: str


TEMPLATES: dict[str, AnimTemplate] = {
    "shimmer": AnimTemplate(
        "shimmer", "shimmer", frames=12, cell_w=96, cell_h=96, fps=12, loop=True,
        description="Halo doré qui respire (accent carte rare / wordmark) — boucle douce",
    ),
    "ember_drift": AnimTemplate(
        "ember_drift", "ember_drift", frames=16, cell_w=128, cell_h=128, fps=14, loop=True,
        description="Braises dérivant vers le haut (overlay ambiant Brocéliande) — boucle continue",
    ),
}


# ── Procedural renderers (PIL only — deterministic, flicker-free, seamless loop) ──────

def _scale_alpha(img, factor: float):
    """Return a copy of an RGBA image with its alpha channel multiplied by `factor`."""
    r, g, b, a = img.split()
    a = a.point(lambda v: max(0, min(255, int(v * factor))))
    from PIL import Image
    return Image.merge("RGBA", (r, g, b, a))


def _render_shimmer(n: int, w: int, h: int, seed: int) -> list:
    """Radial gold halo whose alpha breathes over the loop. Frame 0 == frame n (seamless)."""
    from PIL import Image, ImageDraw

    cx, cy = w / 2.0, h / 2.0
    max_r = min(w, h) * 0.5
    # Base radial gradient: draw outer→inner, inner brighter, so it paints a soft glow.
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    rings = 28
    for k in range(rings):
        t = k / float(rings - 1)            # 0 outer .. 1 inner
        r = max_r * (1.0 - t)
        a = int(150.0 * (t ** 1.6))         # inner brightest, edge transparent
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(GOLD[0], GOLD[1], GOLD[2], a))

    frames: list = []
    for i in range(n):
        phase = (i / float(n)) * _TAU
        breath = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(phase))   # 0.55 .. 1.0
        frames.append(_scale_alpha(base, breath))
    return frames


def _render_ember_drift(n: int, w: int, h: int, seed: int) -> list:
    """A handful of embers drifting upward, wrapping seamlessly over the loop."""
    from PIL import Image, ImageDraw

    rng = random.Random(seed)
    count = 7
    embers = [
        (rng.uniform(0.1, 0.9) * w,   # x
         rng.uniform(0.0, 1.0),       # y phase offset (0..1)
         rng.uniform(2.0, 4.2),       # radius
         rng.uniform(0.30, 0.90))     # base alpha factor
        for _ in range(count)
    ]
    frames: list = []
    for i in range(n):
        ph = i / float(n)
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for (ex, y0, rad, base_a) in embers:
            y = ((y0 - ph) % 1.0) * h                          # drift up, wrap
            flick = 0.6 + 0.4 * math.sin((ph + y0) * _TAU * 2.0)
            a = int(190.0 * base_a * flick)
            col = CREAM if rad > 3.2 else GOLD
            d.ellipse([ex - rad, y - rad, ex + rad, y + rad],
                      fill=(col[0], col[1], col[2], max(0, min(255, a))))
        frames.append(img)
    return frames


_RENDERERS: dict[str, Callable[[int, int, int, int], list]] = {
    "shimmer": _render_shimmer,
    "ember_drift": _render_ember_drift,
}


# ── Sheet packing + .tres writer ──────────────────────────────────────────────────────

def pack_sheet(frames: list) -> tuple:
    """Pack frames into a single horizontal strip. Returns (sheet_image, [region tuples])."""
    from PIL import Image

    if not frames:
        raise ValueError("no frames to pack")
    cw, ch = frames[0].size
    sheet = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    regions: list[tuple[int, int, int, int]] = []
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * cw, 0))
        regions.append((i * cw, 0, cw, ch))
    return sheet, regions


def write_sprite_frames_tres(tres_path: Path, sheet_res_path: str,
                             regions: list[tuple[int, int, int, int]],
                             anim_name: str, fps: int, loop: bool) -> Path:
    """Write a Godot 4.5 SpriteFrames .tres referencing a sheet via AtlasTexture regions.

    Mirrors the exact structure of sprites/pixel_art/*/*_blink_frames.tres (format=3).
    `sheet_res_path` MUST be a res:// path so Godot resolves the ExtResource.
    """
    lines: list[str] = ['[gd_resource type="SpriteFrames" format=3]', ""]
    lines.append('[ext_resource type="Texture2D" path="%s" id="1"]' % sheet_res_path)
    lines.append("")
    for i, (x, y, w, h) in enumerate(regions):
        lines.append('[sub_resource type="AtlasTexture" id="AtlasTexture_%d"]' % i)
        lines.append('atlas = ExtResource("1")')
        lines.append("region = Rect2(%d, %d, %d, %d)" % (x, y, w, h))
        lines.append("")
    lines.append("[resource]")
    lines.append("animations = [{")
    lines.append('"name": &"%s",' % anim_name)
    lines.append('"speed": %.1f,' % float(fps))
    lines.append('"loop": %s,' % ("true" if loop else "false"))
    lines.append('"frames": [')
    for i in range(len(regions)):
        comma = "" if i == len(regions) - 1 else ","
        lines.append("{")
        lines.append('"texture": SubResource("AtlasTexture_%d"),' % i)
        lines.append('"duration": 1.0,')
        lines.append("}%s" % comma)
    lines.append("]")
    lines.append("}]")
    tres_path.parent.mkdir(parents=True, exist_ok=True)
    tres_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return tres_path


# ── Cache convention (BIBLE §24, mirror sd_forge) ────────────────────────────────────

_REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = _REPO_ROOT / "assets" / "sprites" / "cache"
MANIFEST_PATH = CACHE_DIR / "manifest.json"


def _res_path(p: Path) -> str:
    """Map a filesystem path under the repo to a res:// path (forward slashes)."""
    return "res://" + p.resolve().relative_to(_REPO_ROOT).as_posix()


def _rel_path(p: Path) -> str:
    """Repo-relative POSIX path, for storage in the manifest.

    The manifest must never hold machine-absolute paths (``C:/Users/...``):
    it is committed alongside the repo and read on other checkouts.
    """
    return p.resolve().relative_to(_REPO_ROOT).as_posix()


def _from_manifest(stored: str) -> Path:
    """Resolve a manifest path entry. Tolerates legacy absolute entries."""
    p = Path(stored)
    return p if p.is_absolute() else (_REPO_ROOT / p)


def _git_sha() -> str:
    """Short SHA of HEAD, so an asset can be traced back to the code that made it."""
    try:
        out = subprocess.run(
            ["git", "-C", str(_REPO_ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=10, check=False,
        )
        return out.stdout.strip() or "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def _measure(sheet_path: Path) -> dict:
    """Run the canonical QC checks and return their MEASURED values.

    Mirrors the audio ledger (``audio/sfx/manifest.json``), which stores the
    achieved LUFS/true-peak next to the generation params. Here the measured
    quantities are palette conformity (delta-E vs the canon palette),
    dimensions, file size and alpha. Never raises: QC must not break a build.
    """
    tools_dir = str(Path(__file__).resolve().parent)
    if tools_dir not in sys.path:
        sys.path.insert(0, tools_dir)
    try:
        import asset_validator as av
    except ImportError:
        return {"error": "asset_validator unavailable"}
    try:
        report = av.validate_file(sheet_path, "sprite_sheet")
    except Exception as exc:  # noqa: BLE001 - QC is advisory, never fatal
        return {"error": f"{type(exc).__name__}: {exc}"}
    measured: dict = {"passed": report.get("passed"), "critical": report.get("critical")}
    for chk in report.get("checks", []):
        measured[chk["check"]] = chk.get("value")
    try:
        measured["file_size_kb"] = round(sheet_path.stat().st_size / 1024, 1)
    except OSError:
        pass
    return measured


def _cache_key(template: str, frames: int, w: int, h: int, fps: int, loop: bool, seed: int) -> str:
    raw = "%s|%d|%dx%d|%d|%d|%d" % (template, frames, w, h, fps, int(loop), seed)
    return hashlib.sha1(raw.encode()).hexdigest()[:12]


def _load_manifest() -> dict:
    empty: dict = {"version": 1, "entries": {}}
    if not MANIFEST_PATH.exists():
        return empty
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return empty
    if not isinstance(data, dict) or not isinstance(data.get("entries"), dict):
        return empty
    return data


def _save_manifest(manifest: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False),
                             encoding="utf-8")


# ── Public API ────────────────────────────────────────────────────────────────────────

def _has_pillow() -> bool:
    try:
        import PIL  # noqa: F401
        return True
    except ImportError:
        return False


def status() -> dict:
    manifest = _load_manifest()
    return {
        "pillow_available": _has_pillow(),
        "templates": sorted(TEMPLATES),
        "cache_entries": len(manifest.get("entries", {})),
        "cache_dir": str(CACHE_DIR),
        "backend": "procedural",
    }


def list_templates() -> dict[str, dict]:
    return {
        name: {"renderer": t.renderer, "frames": t.frames, "cell": f"{t.cell_w}x{t.cell_h}",
               "fps": t.fps, "loop": t.loop, "description": t.description}
        for name, t in TEMPLATES.items()
    }


def generate(template: str, seed: int = 42, frames: int | None = None,
             width: int | None = None, height: int | None = None,
             fps: int | None = None, loop: bool | None = None) -> dict:
    """Generate an animated sprite-sheet PNG + SpriteFrames .tres for a template.

    Returns dict with: output_sheet, output_tres, frame_count, fps, loop, cached, regions.
    """
    if not _has_pillow():
        return {"output_sheet": None, "error": "Pillow not available — pip install Pillow"}
    if template not in TEMPLATES:
        return {"output_sheet": None,
                "error": f"Unknown template {template!r}. Available: {sorted(TEMPLATES)}"}

    tpl = TEMPLATES[template]
    n = max(2, min(int(frames if frames is not None else tpl.frames), 120))
    w = max(16, min(int(width if width is not None else tpl.cell_w), 1024))
    h = max(16, min(int(height if height is not None else tpl.cell_h), 1024))
    f = max(1, min(int(fps if fps is not None else tpl.fps), 60))
    lp = tpl.loop if loop is None else bool(loop)

    # Garde Godot : la largeur totale (n × w) ne doit pas dépasser MAX_SHEET_W → on réduit n au besoin.
    if n * w > MAX_SHEET_W:
        n = max(2, MAX_SHEET_W // w)

    key = _cache_key(template, n, w, h, f, lp, seed)
    manifest = _load_manifest()
    entry = manifest.get("entries", {}).get(key)
    if entry:
        sheet_p = _from_manifest(entry["sheet"]).resolve()
        tres_p = _from_manifest(entry["tres"]).resolve()
        if (sheet_p.is_relative_to(CACHE_DIR.resolve()) and sheet_p.exists() and tres_p.exists()):
            return {"output_sheet": str(sheet_p), "output_tres": str(tres_p),
                    "frame_count": n, "fps": f, "loop": lp, "cached": True,
                    "regions": entry.get("regions", []), "template": template}

    render = _RENDERERS[tpl.renderer]
    frame_imgs = render(n, w, h, seed)
    sheet, regions = pack_sheet(frame_imgs)

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    sheet_path = CACHE_DIR / f"{template}_{key}_sheet.png"
    tres_path = CACHE_DIR / f"{template}_{key}_frames.tres"
    sheet.save(str(sheet_path), optimize=True)
    write_sprite_frames_tres(tres_path, _res_path(sheet_path), regions, template, f, lp)

    # Ledger entry: repo-relative paths + provenance + MEASURED QC, mirroring
    # audio/sfx/manifest.json. Params alone are not traceability: the measured
    # block is what makes the entry a gate rather than a claim.
    manifest.setdefault("entries", {})[key] = {
        "sheet": _rel_path(sheet_path), "tres": _rel_path(tres_path), "template": template,
        "frames": n, "size": f"{w}x{h}", "fps": f, "loop": lp, "seed": seed,
        "regions": regions,
        "provenance": {
            "tool": "sprite_anim_forge.py",
            "renderer": tpl.renderer,
            "git_sha": _git_sha(),
            "generated_utc": datetime.datetime.now(datetime.timezone.utc)
                             .replace(microsecond=0).isoformat(),
        },
        "measured": _measure(sheet_path),
    }
    _save_manifest(manifest)

    return {"output_sheet": str(sheet_path), "output_tres": str(tres_path),
            "frame_count": n, "fps": f, "loop": lp, "cached": False,
            "regions": regions, "template": template}


def cache_list() -> dict:
    return _load_manifest()


def remeasure() -> dict:
    """Normalise every manifest entry: repo-relative paths + fresh measurements.

    Needed because the cache short-circuits before measuring, so entries written
    by an older forge (absolute paths, no QC block) would otherwise never be
    upgraded. Also the way to refresh the ledger after asset_validator changes.
    Entries whose sheet has vanished are reported, never silently dropped.
    """
    manifest = _load_manifest()
    entries = manifest.get("entries", {})
    updated, missing = [], []
    for key, entry in entries.items():
        sheet_p = _from_manifest(entry.get("sheet", ""))
        tres_p = _from_manifest(entry.get("tres", ""))
        if not sheet_p.exists():
            missing.append(key)
            continue
        entry["sheet"] = _rel_path(sheet_p)
        if tres_p.exists():
            entry["tres"] = _rel_path(tres_p)
        entry.setdefault("provenance", {}).update({
            "tool": "sprite_anim_forge.py",
            "renderer": TEMPLATES[entry["template"]].renderer
                        if entry.get("template") in TEMPLATES else "unknown",
        })
        entry["provenance"].setdefault("git_sha", "pre-ledger")
        entry["measured"] = _measure(sheet_p)
        updated.append(key)
    _save_manifest(manifest)
    return {"updated": updated, "missing": missing, "total": len(entries)}


# ── CLI ─────────────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN sprite-anim forge (procedural)")
    parser.add_argument("--template", type=str, choices=list(TEMPLATES),
                        help="Animation template to render")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--frames", type=int, default=None, help="Override frame count (2..120)")
    parser.add_argument("--size", type=str, default=None, help="Override cell size WxH (16..1024)")
    parser.add_argument("--fps", type=int, default=None, help="Override playback fps (1..60)")
    parser.add_argument("--no-loop", action="store_true", help="Disable looping")
    parser.add_argument("--list-templates", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--cache-list", action="store_true")
    parser.add_argument("--remeasure", action="store_true",
                        help="Normalise manifest paths + refresh measured QC on every entry")

    args = parser.parse_args(argv)

    if args.remeasure:
        print(json.dumps(remeasure(), indent=2))
        return 0

    if args.status:
        print(json.dumps(status(), indent=2))
        return 0
    if args.list_templates:
        for name, info in list_templates().items():
            print(f"  {name:14s}  {info['frames']:2d}f {info['cell']:9s} {info['fps']}fps  {info['description']}")
        return 0
    if args.cache_list:
        print(json.dumps(cache_list(), indent=2))
        return 0

    if not args.template:
        print("ERROR: --template required (or --list-templates / --status)", file=sys.stderr)
        return 1

    w = h = None
    if args.size:
        try:
            parts = args.size.lower().split("x")
            w, h = int(parts[0]), int(parts[1])
        except (ValueError, IndexError):
            print("ERROR: --size must be WxH (e.g. 128x128)", file=sys.stderr)
            return 1

    result = generate(args.template, seed=args.seed, frames=args.frames,
                      width=w, height=h, fps=args.fps,
                      loop=(False if args.no_loop else None))
    print(json.dumps(result, indent=2))
    return 0 if result.get("output_sheet") else 1


if __name__ == "__main__":
    sys.exit(main())
