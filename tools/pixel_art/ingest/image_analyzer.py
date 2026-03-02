"""Image analyzer — detect palette, count facets, compute bounding box.

Analyzes a low-poly character image to extract metadata useful for
the ingestion pipeline: dominant colors, estimated facet count,
character bounding box, and symmetry analysis.

Dependencies: Pillow + NumPy only.
"""

from dataclasses import dataclass
from typing import List, Tuple, Dict, Optional
import math

import numpy as np
from PIL import Image

from .polygon_extractor import quantize_colors, _flood_fill_regions, rgb_to_hex


@dataclass(frozen=True)
class ImageAnalysis:
    """Analysis results for a low-poly character image."""
    width: int
    height: int
    bbox: Tuple[int, int, int, int]     # (left, top, right, bottom)
    center: Tuple[float, float]
    palette: Dict[str, int]             # hex_color -> pixel_count
    dominant_colors: List[str]          # top 5 hex colors by area
    estimated_facets: int               # number of distinct color regions
    opaque_pixel_count: int
    fill_ratio: float                   # opaque / bbox area
    symmetry_score: float               # 0.0 (asymmetric) to 1.0 (symmetric)


def analyze_image(
    image_path: str,
    color_tolerance: int = 12,
    min_region_size: int = 50,
) -> ImageAnalysis:
    """Analyze a low-poly character image.

    Args:
        image_path: Path to PNG with transparent background.
        color_tolerance: Max RGB distance to merge similar colors.
        min_region_size: Minimum pixels for a region to count as a facet.

    Returns:
        ImageAnalysis with all extracted metadata.
    """
    img = Image.open(image_path).convert('RGBA')
    arr = np.array(img)
    h, w = arr.shape[:2]

    # Alpha mask
    alpha = arr[:, :, 3]
    opaque_mask = alpha > 128
    opaque_count = int(np.sum(opaque_mask))

    # Bounding box of opaque pixels
    if opaque_count == 0:
        return ImageAnalysis(
            width=w, height=h,
            bbox=(0, 0, w, h),
            center=(w / 2, h / 2),
            palette={},
            dominant_colors=[],
            estimated_facets=0,
            opaque_pixel_count=0,
            fill_ratio=0.0,
            symmetry_score=0.0,
        )

    rows = np.any(opaque_mask, axis=1)
    cols = np.any(opaque_mask, axis=0)
    top, bottom = int(np.argmax(rows)), int(h - np.argmax(rows[::-1]))
    left, right = int(np.argmax(cols)), int(w - np.argmax(cols[::-1]))
    bbox = (left, top, right, bottom)

    # Center of mass
    ys, xs = np.where(opaque_mask)
    center_x = float(np.mean(xs))
    center_y = float(np.mean(ys))

    # Quantize and count regions
    label_map, quant_palette = quantize_colors(img, tolerance=color_tolerance)
    regions = _flood_fill_regions(label_map)

    # Filter small regions and count facets
    significant_regions = [r for r in regions if len(r[1]) >= min_region_size]
    estimated_facets = len(significant_regions)

    # Build palette (hex -> pixel count)
    palette_counts: Dict[str, int] = {}
    for color_label, pixels in significant_regions:
        if color_label in quant_palette:
            r, g, b = quant_palette[color_label]
            hex_color = rgb_to_hex(r, g, b)
            palette_counts[hex_color] = palette_counts.get(hex_color, 0) + len(pixels)

    # Dominant colors (sorted by area)
    sorted_colors = sorted(palette_counts.items(), key=lambda x: -x[1])
    dominant = [c for c, _ in sorted_colors[:5]]

    # Fill ratio
    bbox_area = (right - left) * (bottom - top)
    fill_ratio = opaque_count / bbox_area if bbox_area > 0 else 0.0

    # Symmetry score (compare left half to mirrored right half)
    symmetry = _compute_symmetry(opaque_mask, center_x)

    return ImageAnalysis(
        width=w,
        height=h,
        bbox=bbox,
        center=(center_x, center_y),
        palette=palette_counts,
        dominant_colors=dominant,
        estimated_facets=estimated_facets,
        opaque_pixel_count=opaque_count,
        fill_ratio=fill_ratio,
        symmetry_score=symmetry,
    )


def _compute_symmetry(
    opaque_mask: np.ndarray,
    center_x: float,
) -> float:
    """Compute left-right symmetry score.

    Compares the left half to the mirrored right half.
    Returns 0.0 (completely asymmetric) to 1.0 (perfectly symmetric).
    """
    h, w = opaque_mask.shape
    cx = int(round(center_x))

    # Ensure we don't go out of bounds
    half_w = min(cx, w - cx)
    if half_w < 5:
        return 0.0

    left_half = opaque_mask[:, cx - half_w:cx]
    right_half = opaque_mask[:, cx:cx + half_w]

    # Mirror right half
    right_mirrored = np.flip(right_half, axis=1)

    # Compare
    matching = np.sum(left_half == right_mirrored)
    total = left_half.size

    return float(matching / total) if total > 0 else 0.0


def print_analysis(analysis: ImageAnalysis) -> None:
    """Pretty-print an analysis report."""
    a = analysis
    print(f"\n  IMAGE ANALYSIS")
    print(f"  {'=' * 40}")
    print(f"  Size:        {a.width}x{a.height}")
    print(f"  Bbox:        ({a.bbox[0]},{a.bbox[1]}) -> ({a.bbox[2]},{a.bbox[3]})")
    print(f"  Center:      ({a.center[0]:.1f}, {a.center[1]:.1f})")
    print(f"  Opaque px:   {a.opaque_pixel_count:,}")
    print(f"  Fill ratio:  {a.fill_ratio:.1%}")
    print(f"  Symmetry:    {a.symmetry_score:.1%}")
    print(f"  Facets:      {a.estimated_facets}")
    print(f"  Palette ({len(a.palette)} colors):")
    for color in a.dominant_colors:
        count = a.palette.get(color, 0)
        pct = count / a.opaque_pixel_count * 100 if a.opaque_pixel_count else 0
        print(f"    {color}  {count:>6} px  ({pct:.1f}%)")
    print()
