"""Polygon extractor — detect flat-colored regions in low-poly images.

Takes a PNG image of a low-poly character (transparent background) and
extracts each flat-colored region as a polygon (Facet).  The output is
directly compatible with LowPolyMesh.

Algorithm:
  1. Quantize colors (merge near-identical shades).
  2. Flood-fill connected regions of same quantized color.
  3. Extract convex hull of each region = polygon vertices.
  4. Assign z-order by vertical position (higher = further back).
  5. Return list of Facet-compatible dicts.

Dependencies: Pillow + NumPy only (no OpenCV).
"""

from dataclasses import dataclass, field
from typing import List, Tuple, Dict, Optional
import math

import numpy as np
from PIL import Image


@dataclass(frozen=True)
class ExtractedFacet:
    """A polygon region extracted from a low-poly image."""
    name: str
    points: Tuple[Tuple[float, float], ...]
    color: str          # '#RRGGBB'
    area: int           # pixel count
    centroid: Tuple[float, float]
    group: str = 'body'
    z_order: int = 0


# ---------------------------------------------------------------------------
# Color quantization
# ---------------------------------------------------------------------------

def _color_distance(c1: Tuple[int, ...], c2: Tuple[int, ...]) -> float:
    """Euclidean distance in RGB space."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1[:3], c2[:3])))


def quantize_colors(
    img: Image.Image,
    tolerance: int = 12,
) -> Tuple[np.ndarray, Dict[int, Tuple[int, int, int]]]:
    """Reduce image colors by merging shades within tolerance.

    Returns:
        label_map: 2D array where each pixel has a color label (int).
        palette: Dict mapping label -> (R, G, B).
    """
    arr = np.array(img.convert('RGBA'))
    h, w = arr.shape[:2]

    # Build alpha mask (transparent = background)
    alpha = arr[:, :, 3]
    opaque_mask = alpha > 128

    # Collect unique opaque colors
    rgb = arr[:, :, :3]
    flat_rgb = rgb[opaque_mask]

    if len(flat_rgb) == 0:
        return np.full((h, w), -1, dtype=np.int32), {}

    # K-means-like greedy merging: iterate unique colors, merge nearby
    unique_colors = np.unique(flat_rgb.reshape(-1, 3), axis=0)

    clusters: List[Tuple[int, int, int]] = []
    color_to_label: Dict[Tuple[int, int, int], int] = {}

    for uc in unique_colors:
        uc_tuple = tuple(int(v) for v in uc)
        matched = False
        for label, center in enumerate(clusters):
            if _color_distance(uc_tuple, center) <= tolerance:
                color_to_label[uc_tuple] = label
                matched = True
                break
        if not matched:
            label = len(clusters)
            clusters.append(uc_tuple)
            color_to_label[uc_tuple] = label

    # Build label map
    label_map = np.full((h, w), -1, dtype=np.int32)
    for y in range(h):
        for x in range(w):
            if opaque_mask[y, x]:
                px = tuple(int(v) for v in rgb[y, x])
                label_map[y, x] = color_to_label.get(px, -1)

    palette = {i: c for i, c in enumerate(clusters)}
    return label_map, palette


# ---------------------------------------------------------------------------
# Region extraction (flood-fill)
# ---------------------------------------------------------------------------

def _flood_fill_regions(
    label_map: np.ndarray,
) -> List[Tuple[int, List[Tuple[int, int]]]]:
    """Find connected components of same color label.

    Returns list of (color_label, pixel_coords) for each region.
    """
    h, w = label_map.shape
    visited = np.zeros((h, w), dtype=bool)
    regions = []

    for y in range(h):
        for x in range(w):
            if visited[y, x] or label_map[y, x] < 0:
                continue

            # BFS flood fill
            color_label = label_map[y, x]
            queue = [(y, x)]
            visited[y, x] = True
            pixels = []

            while queue:
                cy, cx = queue.pop()
                pixels.append((cx, cy))  # (x, y) format

                for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    ny, nx = cy + dy, cx + dx
                    if (0 <= ny < h and 0 <= nx < w
                            and not visited[ny, nx]
                            and label_map[ny, nx] == color_label):
                        visited[ny, nx] = True
                        queue.append((ny, nx))

            regions.append((color_label, pixels))

    return regions


# ---------------------------------------------------------------------------
# Convex hull (Graham scan — no scipy dependency)
# ---------------------------------------------------------------------------

def _cross(o, a, b):
    """Cross product of vectors OA and OB."""
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _convex_hull(points: List[Tuple[int, int]]) -> List[Tuple[float, float]]:
    """Compute convex hull of a set of 2D points (Andrew's monotone chain).

    Returns vertices in counter-clockwise order.
    """
    pts = sorted(set(points))
    if len(pts) <= 1:
        return [(float(p[0]), float(p[1])) for p in pts]
    if len(pts) == 2:
        return [(float(p[0]), float(p[1])) for p in pts]

    # Build lower hull
    lower = []
    for p in pts:
        while len(lower) >= 2 and _cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)

    # Build upper hull
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and _cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)

    hull = lower[:-1] + upper[:-1]
    return [(float(x), float(y)) for x, y in hull]


def _simplify_polygon(
    hull: List[Tuple[float, float]],
    max_vertices: int = 8,
) -> List[Tuple[float, float]]:
    """Reduce polygon vertex count while preserving shape.

    Uses iterative removal of the vertex that changes area the least.
    """
    if len(hull) <= max_vertices:
        return hull

    pts = list(hull)
    while len(pts) > max_vertices:
        # Find vertex whose removal causes smallest area change
        min_area = float('inf')
        min_idx = 0
        n = len(pts)
        for i in range(n):
            prev_pt = pts[(i - 1) % n]
            curr = pts[i]
            next_pt = pts[(i + 1) % n]
            # Triangle area formed by removing this vertex
            area = abs(_cross(prev_pt, curr, next_pt)) / 2.0
            if area < min_area:
                min_area = area
                min_idx = i
        pts.pop(min_idx)

    return pts


# ---------------------------------------------------------------------------
# Boundary tracing (concave hull approximation)
# ---------------------------------------------------------------------------

def _trace_boundary(
    pixels: List[Tuple[int, int]],
    max_vertices: int = 8,
) -> List[Tuple[float, float]]:
    """Extract boundary of a pixel region and simplify to polygon.

    For low-poly images, the convex hull is usually sufficient since
    each facet IS a convex polygon.  For non-convex regions, we use
    the convex hull with simplification.
    """
    hull = _convex_hull(pixels)
    return _simplify_polygon(hull, max_vertices)


# ---------------------------------------------------------------------------
# Main extraction
# ---------------------------------------------------------------------------

def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert RGB tuple to hex string."""
    return f'#{r:02x}{g:02x}{b:02x}'


def extract_facets(
    image_path: str,
    color_tolerance: int = 12,
    min_area: int = 50,
    max_vertices: int = 8,
) -> List[ExtractedFacet]:
    """Extract low-poly facets from a PNG image.

    Args:
        image_path: Path to PNG with transparent background.
        color_tolerance: Max RGB distance to merge similar colors.
        min_area: Minimum pixel count for a region to be kept.
        max_vertices: Maximum vertices per polygon.

    Returns:
        List of ExtractedFacet, sorted by z_order (top-to-bottom).
    """
    img = Image.open(image_path).convert('RGBA')

    # 1. Quantize colors
    label_map, palette = quantize_colors(img, tolerance=color_tolerance)

    if not palette:
        return []

    # 2. Flood-fill connected regions
    regions = _flood_fill_regions(label_map)

    # 3. Extract polygons
    facets = []
    for region_idx, (color_label, pixels) in enumerate(regions):
        if len(pixels) < min_area:
            continue

        # Compute centroid
        cx = sum(p[0] for p in pixels) / len(pixels)
        cy = sum(p[1] for p in pixels) / len(pixels)

        # Get polygon vertices
        boundary = _trace_boundary(pixels, max_vertices)
        if len(boundary) < 3:
            continue

        # Color
        r, g, b = palette[color_label]
        hex_color = rgb_to_hex(r, g, b)

        # Z-order: higher centroid y = further forward (higher z)
        # Normalize to 0-20 range based on image height
        img_h = img.height
        z = int((cy / img_h) * 20)

        facets.append(ExtractedFacet(
            name=f'facet_{region_idx}',
            points=tuple(boundary),
            color=hex_color,
            area=len(pixels),
            centroid=(cx, cy),
            group='body',
            z_order=z,
        ))

    # Sort by z_order (back to front)
    facets.sort(key=lambda f: f.z_order)

    return facets


def facets_to_mesh_data(
    facets: List[ExtractedFacet],
) -> List[dict]:
    """Convert extracted facets to LowPolyMesh-compatible dicts.

    Each dict has keys: name, points, color, group, z_order.
    Ready to pass to LowPolyMesh.add_facet().
    """
    return [
        {
            'name': f.name,
            'points': list(f.points),
            'color': f.color,
            'group': f.group,
            'z_order': f.z_order,
        }
        for f in facets
    ]
