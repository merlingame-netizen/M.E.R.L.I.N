# -*- coding: utf-8 -*-
"""Sepia forge M.E.R.L.I.N. — filtre d'identité gravure/sépia (BIBLE §20, R115).

Transforme toute image source en gravure monochrome sépia cohérente avec
l'identité visuelle MERLIN (parchemin sombre, encre, crème/or).

Pipeline : desaturation → sepia toning → edge enhancement → S-curve →
           grain (seeded) → vignette → clamp brightness.

Couleurs canoniques (merlin_visual.gd) :
  CREAM   #E8DCC0  (highlight)
  INK     #2A2018  (shadow)
  BG_PAGE #1E1A14  (vignette)

Usage:
    python tools/sepia_forge.py --input img.png --output sepia.png
    python tools/sepia_forge.py --input img.png --profile soft
    python tools/sepia_forge.py --batch-dir raw/ --output-dir processed/
    python tools/sepia_forge.py --list-profiles
"""
from __future__ import annotations

import argparse
import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageFilter

# Pillow 12+ deprecates getdata() — use get_flattened_data() when available
_GET_DATA = "get_flattened_data" if hasattr(Image.Image, "get_flattened_data") else "getdata"


def _pixels(img: Image.Image) -> list:
    return list(getattr(img, _GET_DATA)())


# ── Palette canonique (merlin_visual.gd — source de vérité) ─────────────────

CREAM = (0xE8, 0xDC, 0xC0)
INK = (0x2A, 0x20, 0x18)
BG_PAGE = (0x1E, 0x1A, 0x14)


# ── Profils ─────────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class SepiaProfile:
    """Paramètres du filtre sépia/gravure."""
    name: str
    edge_strength: float    # 0.0-1.0 — enhancement Sobel (0 = off)
    sepia_warmth: float     # 0.0-1.0 — intensité du toning sépia
    grain_amount: float     # 0.0-1.0 — amplitude du grain de parchemin
    vignette_radius: float  # 0.0-1.0 — assombrissement aux bords (0 = off)
    contrast_curve: float   # 0.5-2.0 — exposant S-curve midtones

PROFILES: dict[str, SepiaProfile] = {
    "gravure":  SepiaProfile("gravure",  0.8,  0.9,  0.30, 0.60, 1.4),
    "soft":     SepiaProfile("soft",     0.2,  0.7,  0.20, 0.40, 1.1),
    "card":     SepiaProfile("card",     0.5,  0.8,  0.25, 0.50, 1.2),
    "portrait": SepiaProfile("portrait", 0.3,  0.85, 0.15, 0.45, 1.3),
}

DEFAULT_PROFILE = "gravure"


# ── Pipeline ────────────────────────────────────────────────────────────────

def _desaturate(pixels: list[tuple[int, int, int]]) -> list[float]:
    """RGB → luminance (ITU-R BT.601)."""
    return [0.299 * r + 0.587 * g + 0.114 * b for r, g, b in pixels]


def _sepia_tone(luma: list[float], warmth: float) -> list[tuple[int, int, int]]:
    """Map luminance 0-255 vers gradient INK→CREAM avec warmth blend."""
    out: list[tuple[int, int, int]] = []
    for l in luma:
        t = l / 255.0
        r = int(INK[0] + t * (CREAM[0] - INK[0]))
        g = int(INK[1] + t * (CREAM[1] - INK[1]))
        b = int(INK[2] + t * (CREAM[2] - INK[2]))
        gray = int(l)
        r = int(gray + warmth * (r - gray))
        g = int(gray + warmth * (g - gray))
        b = int(gray + warmth * (b - gray))
        out.append((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))
    return out


def _s_curve(luma: list[float], exponent: float) -> list[float]:
    """S-curve contrast enhancement on normalized luminance."""
    out: list[float] = []
    for l in luma:
        t = l / 255.0
        if t < 0.5:
            v = 0.5 * (2.0 * t) ** exponent
        else:
            v = 1.0 - 0.5 * (2.0 * (1.0 - t)) ** exponent
        out.append(v * 255.0)
    return out


def _add_grain(pixels: list[tuple[int, int, int]], amount: float,
               seed: int = 42) -> list[tuple[int, int, int]]:
    """Gaussian noise grain (seeded for reproducibility)."""
    if amount <= 0:
        return pixels
    rng = random.Random(seed)
    scale = amount * 30.0
    out: list[tuple[int, int, int]] = []
    for r, g, b in pixels:
        n = rng.gauss(0, scale)
        nr = max(0, min(255, int(r + n)))
        ng = max(0, min(255, int(g + n * 0.9)))
        nb = max(0, min(255, int(b + n * 0.85)))
        out.append((nr, ng, nb))
    return out


def _add_vignette(pixels: list[tuple[int, int, int]], w: int, h: int,
                  radius: float) -> list[tuple[int, int, int]]:
    """Radial darkening toward BG_PAGE at corners."""
    if radius <= 0:
        return pixels
    cx, cy = w / 2.0, h / 2.0
    max_dist = math.sqrt(cx * cx + cy * cy)
    out: list[tuple[int, int, int]] = []
    for i, (r, g, b) in enumerate(pixels):
        x, y = i % w, i // w
        dx, dy = x - cx, y - cy
        dist = math.sqrt(dx * dx + dy * dy) / max_dist
        start = 1.0 - radius
        if dist <= start:
            factor = 1.0
        else:
            t = (dist - start) / radius
            t = min(1.0, t)
            t = t * t * (3.0 - 2.0 * t)
            factor = 1.0 - t * 0.7
        nr = int(r * factor + BG_PAGE[0] * (1.0 - factor))
        ng = int(g * factor + BG_PAGE[1] * (1.0 - factor))
        nb = int(b * factor + BG_PAGE[2] * (1.0 - factor))
        out.append((max(0, min(255, nr)), max(0, min(255, ng)), max(0, min(255, nb))))
    return out


def apply(input_path: str | Path, output_path: str | Path,
          profile_name: str = DEFAULT_PROFILE, seed: int = 42) -> Path:
    """Apply sepia/gravure filter to an image file.

    Returns:
        Path to the output file.
    """
    profile = PROFILES.get(profile_name)
    if profile is None:
        raise ValueError(f"Unknown profile {profile_name!r}. Available: {list(PROFILES)}")

    img = Image.open(input_path).convert("RGB")
    w, h = img.size

    # 1. Edge enhancement (Sobel-like via Pillow FIND_EDGES + blend)
    if profile.edge_strength > 0:
        edges = img.filter(ImageFilter.FIND_EDGES).convert("L")
        edge_pixels = _pixels(edges)
        base_pixels = _pixels(img)
        blended: list[tuple[int, int, int]] = []
        strength = profile.edge_strength * 0.5
        for (r, g, b), e in zip(base_pixels, edge_pixels):
            boost = e / 255.0 * strength
            nr = max(0, min(255, int(r * (1.0 + boost))))
            ng = max(0, min(255, int(g * (1.0 + boost))))
            nb = max(0, min(255, int(b * (1.0 + boost))))
            blended.append((nr, ng, nb))
        img.putdata(blended)

    # 2. Desaturation
    rgb_pixels: list[tuple[int, int, int]] = _pixels(img)
    luma = _desaturate(rgb_pixels)

    # 3. S-curve contrast
    luma = _s_curve(luma, profile.contrast_curve)

    # 4. Sepia toning
    sepia_pixels = _sepia_tone(luma, profile.sepia_warmth)

    # 5. Grain
    sepia_pixels = _add_grain(sepia_pixels, profile.grain_amount, seed=seed)

    # 6. Vignette
    sepia_pixels = _add_vignette(sepia_pixels, w, h, profile.vignette_radius)

    # Write output
    out_img = Image.new("RGB", (w, h))
    out_img.putdata(sepia_pixels)

    out_path = Path(output_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_img.save(str(out_path))
    return out_path


def apply_batch(input_dir: str | Path, output_dir: str | Path,
                profile_name: str = DEFAULT_PROFILE, seed: int = 42) -> list[Path]:
    """Apply sepia filter to all images in a directory."""
    in_dir = Path(input_dir)
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    results: list[Path] = []
    for ext in ("*.png", "*.jpg", "*.jpeg", "*.webp"):
        for f in sorted(in_dir.glob(ext)):
            out = out_dir / f"{f.stem}_sepia.png"
            apply(f, out, profile_name, seed)
            results.append(out)
    return results


def list_profiles() -> dict[str, dict]:
    """Return profile metadata for CLI display."""
    return {
        name: {
            "edge_strength": p.edge_strength,
            "sepia_warmth": p.sepia_warmth,
            "grain_amount": p.grain_amount,
            "vignette_radius": p.vignette_radius,
            "contrast_curve": p.contrast_curve,
        }
        for name, p in PROFILES.items()
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN sepia/gravure filter")
    parser.add_argument("--input", type=str, help="Input image path")
    parser.add_argument("--output", type=str, help="Output image path")
    parser.add_argument("--profile", type=str, default=DEFAULT_PROFILE,
                        choices=list(PROFILES), help="Filter profile")
    parser.add_argument("--seed", type=int, default=42, help="Grain RNG seed")
    parser.add_argument("--batch-dir", type=str, help="Input directory for batch mode")
    parser.add_argument("--output-dir", type=str, help="Output directory for batch mode")
    parser.add_argument("--list-profiles", action="store_true", help="List profiles")

    args = parser.parse_args(argv)

    if args.list_profiles:
        for name, params in list_profiles().items():
            print(f"  {name:12s}  edges={params['edge_strength']:.1f}  "
                  f"sepia={params['sepia_warmth']:.1f}  "
                  f"grain={params['grain_amount']:.2f}  "
                  f"vignette={params['vignette_radius']:.1f}  "
                  f"contrast={params['contrast_curve']:.1f}")
        return 0

    if args.batch_dir:
        if not args.output_dir:
            print("ERROR: --output-dir required with --batch-dir", file=sys.stderr)
            return 1
        results = apply_batch(args.batch_dir, args.output_dir, args.profile, args.seed)
        print(f"Processed {len(results)} images → {args.output_dir}")
        return 0

    if not args.input:
        print("ERROR: --input required (or use --batch-dir)", file=sys.stderr)
        return 1

    out = args.output or str(Path(args.input).with_suffix(".sepia.png"))
    result = apply(args.input, out, args.profile, args.seed)
    print(f"OK: {result} (profile={args.profile}, seed={args.seed})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
