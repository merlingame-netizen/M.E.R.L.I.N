"""Palette swap — automatic color variant generation for sprites.

Extracts the dominant palette from a sprite and generates recolored variants
by shifting hue, remapping colors, or applying named form palettes.

Usage:
    from pixel_art.ingest.palette_swap import generate_variants, BESTIOLE_FORMS
    variants = generate_variants(image, n=5)
    ember_img = apply_form(image, BESTIOLE_FORMS['emberform'])
"""

import math
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image


# Named bestiole form palettes: hue_offset in degrees from the original purple
BESTIOLE_FORMS: Dict[str, Dict] = {
    'default':    {'hue_offset': 0,   'sat_mult': 1.0, 'val_mult': 1.0},
    'veilform':   {'hue_offset': 200, 'sat_mult': 0.6, 'val_mult': 1.1},  # ghostly blue
    'stoneform':  {'hue_offset': 30,  'sat_mult': 0.3, 'val_mult': 0.85}, # desaturated grey-brown
    'emberform':  {'hue_offset': -60, 'sat_mult': 1.2, 'val_mult': 1.0},  # warm red-orange
    'riverform':  {'hue_offset': 140, 'sat_mult': 1.0, 'val_mult': 1.05}, # teal-cyan
    'thornform':  {'hue_offset': 80,  'sat_mult': 1.1, 'val_mult': 0.9},  # forest green
    'galeform':   {'hue_offset': 180, 'sat_mult': 0.8, 'val_mult': 1.15}, # pale sky blue
    'rootform':   {'hue_offset': 40,  'sat_mult': 0.9, 'val_mult': 0.8},  # earthy brown
    'tideform':   {'hue_offset': 160, 'sat_mult': 1.0, 'val_mult': 1.0},  # deep ocean blue
    'emberglass': {'hue_offset': -40, 'sat_mult': 1.3, 'val_mult': 1.1},  # golden amber
    'mossform':   {'hue_offset': 100, 'sat_mult': 0.7, 'val_mult': 0.95}, # muted olive
}


def _rgb_to_hsv_array(arr: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Convert RGB array (H,W,3) float 0-1 to separate H,S,V arrays."""
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    diff = mx - mn

    h = np.zeros_like(diff)
    mask_diff = diff > 0
    mask_r = (mx == r) & mask_diff
    mask_g = (mx == g) & mask_diff
    mask_b = (mx == b) & mask_diff

    h[mask_r] = (((g[mask_r] - b[mask_r]) / diff[mask_r]) % 6) / 6.0
    h[mask_g] = ((b[mask_g] - r[mask_g]) / diff[mask_g] + 2) / 6.0
    h[mask_b] = ((r[mask_b] - g[mask_b]) / diff[mask_b] + 4) / 6.0

    safe_mx = np.where(mx > 0, mx, 1.0)
    s = np.where(mx > 0, diff / safe_mx, 0.0)
    v = mx
    return h, s, v


def _hsv_to_rgb_array(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Convert H,S,V arrays to RGB array (H,W,3) float 0-1."""
    c = v * s
    x = c * (1.0 - np.abs((h * 6.0) % 2.0 - 1.0))
    m = v - c

    h6 = (h * 6.0).astype(int) % 6
    r = np.zeros_like(h)
    g = np.zeros_like(h)
    b = np.zeros_like(h)

    for sector, rv, gv, bv in [(0, c, x, 0), (1, x, c, 0), (2, 0, c, x),
                                 (3, 0, x, c), (4, x, 0, c), (5, c, 0, x)]:
        mask = h6 == sector
        r[mask] = rv[mask] if not isinstance(rv, (int, float)) else rv
        g[mask] = gv[mask] if not isinstance(gv, (int, float)) else gv
        b[mask] = bv[mask] if not isinstance(bv, (int, float)) else bv

    result = np.stack([r + m, g + m, b + m], axis=-1)
    return np.clip(result, 0.0, 1.0)


def shift_hue(image: Image.Image, hue_offset: float,
              sat_mult: float = 1.0, val_mult: float = 1.0) -> Image.Image:
    """Shift hue of all opaque pixels in an RGBA image.

    Args:
        image: PIL Image (RGBA).
        hue_offset: Hue rotation in degrees (0-360).
        sat_mult: Saturation multiplier (1.0 = unchanged).
        val_mult: Value/brightness multiplier (1.0 = unchanged).

    Returns:
        New recolored PIL Image (RGBA).
    """
    arr = np.array(image).astype(np.float32)
    alpha = arr[:, :, 3]
    opaque = alpha > 32

    rgb = arr[:, :, :3] / 255.0
    h, s, v = _rgb_to_hsv_array(rgb)

    h[opaque] = (h[opaque] + hue_offset / 360.0) % 1.0
    s[opaque] = np.clip(s[opaque] * sat_mult, 0.0, 1.0)
    v[opaque] = np.clip(v[opaque] * val_mult, 0.0, 1.0)

    new_rgb = _hsv_to_rgb_array(h, s, v)

    result = arr.copy()
    result[:, :, :3] = np.where(opaque[:, :, np.newaxis], new_rgb * 255.0, arr[:, :, :3])
    return Image.fromarray(np.clip(result, 0, 255).astype(np.uint8))


def apply_form(image: Image.Image, form_params: Dict) -> Image.Image:
    """Apply a named bestiole form palette to an image.

    Args:
        image: Source RGBA image.
        form_params: Dict with hue_offset, sat_mult, val_mult.

    Returns:
        Recolored PIL Image.
    """
    return shift_hue(
        image,
        hue_offset=form_params.get('hue_offset', 0),
        sat_mult=form_params.get('sat_mult', 1.0),
        val_mult=form_params.get('val_mult', 1.0),
    )


def generate_variants(image: Image.Image, n: int = 5) -> List[Image.Image]:
    """Generate N color variants with equidistant hue shifts.

    Args:
        image: Source RGBA image.
        n: Number of variants to generate.

    Returns:
        List of N recolored PIL Images.
    """
    variants = []
    for i in range(n):
        offset = (360.0 / n) * i
        variants.append(shift_hue(image, hue_offset=offset))
    return variants


def extract_dominant_palette(image: Image.Image, n_colors: int = 6) -> List[Tuple[int, int, int]]:
    """Extract the N most dominant colors from an image.

    Uses quantized color binning (faster than k-means for sprite art).

    Args:
        image: PIL Image (RGBA).
        n_colors: Number of colors to extract.

    Returns:
        List of (R, G, B) tuples sorted by frequency.
    """
    arr = np.array(image.convert('RGBA'))
    opaque = arr[:, :, 3] > 32
    pixels = arr[opaque][:, :3]

    if len(pixels) == 0:
        return [(0, 0, 0)]

    # Quantize to 32-level bins per channel for grouping
    quantized = (pixels // 8) * 8
    # Count unique colors
    colors, counts = np.unique(quantized, axis=0, return_counts=True)
    sorted_idx = np.argsort(-counts)

    result = []
    for idx in sorted_idx[:n_colors]:
        r, g, b = colors[idx]
        result.append((int(r), int(g), int(b)))

    return result
