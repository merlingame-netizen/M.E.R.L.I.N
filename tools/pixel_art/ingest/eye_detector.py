"""Auto-detect eye positions in a character image.

Eyes are typically the WARMEST (highest R-B difference) and most distinct
pixels in the head zone. This works well for low-poly game characters where
eyes are small bright spots against a cooler body color.

Algorithm:
  1. Crop the head zone from the character bounding box.
  2. Compute warmth metric (R - B) for each opaque pixel.
  3. Threshold at 99th percentile to find the hottest pixels.
  4. Cluster by proximity (grid-based) to separate left/right eyes.
  5. Compute bbox, center, eye color, and surrounding fur color per cluster.
"""

from typing import List, Tuple, Optional
from dataclasses import dataclass
from collections import defaultdict

from PIL import Image
import numpy as np

from .layer_splitter import AnatomyType, ANATOMY_ZONES


@dataclass(frozen=True)
class EyeRegion:
    """Detected eye location in source image coordinates."""
    bbox: Tuple[int, int, int, int]   # (x1, y1, x2, y2) absolute in source
    center: Tuple[int, int]           # (cx, cy) absolute in source
    color: Tuple[int, int, int]       # average RGB of eye pixels
    lid_color: Tuple[int, int, int]   # average RGB of fur above eye (eyelid)
    pixel_count: int


def detect_eyes(
    source: Image.Image,
    char_bbox: Tuple[int, int, int, int],
    anatomy: AnatomyType = AnatomyType.QUADRUPED,
    warmth_percentile: float = 99.0,
    min_eye_pixels: int = 10,
    verbose: bool = False,
) -> List[EyeRegion]:
    """Detect eye positions in a character image.

    Args:
        source: RGBA source image.
        char_bbox: Character bounding box (left, top, right, bottom).
        anatomy: Creature type to determine head zone.
        warmth_percentile: Percentile threshold for warm pixel detection.
        min_eye_pixels: Minimum pixel count to consider a cluster an eye.
        verbose: Print detection info.

    Returns:
        List of EyeRegion (0-2 eyes), sorted left-to-right.
    """
    left, top, right, bottom = char_bbox
    bw, bh = right - left, bottom - top

    # Determine head zone from anatomy
    zones = ANATOMY_ZONES.get(anatomy, ANATOMY_ZONES[AnatomyType.OBJECT])
    head_zone = next((z for z in zones if z.name == 'head'), None)
    if head_zone is None:
        return []

    # Expand head zone for eye search — eyes are often at the lower
    # boundary of the head zone, so extend downward by 20% of char height
    # and widen by 10% on each side
    expand_y = 0.20
    expand_x = 0.10
    hx1 = max(0, int(left + (head_zone.x_min - expand_x) * bw))
    hy1 = max(0, int(top + head_zone.y_min * bh))
    hx2 = min(source.width, int(left + (head_zone.x_max + expand_x) * bw))
    hy2 = min(source.height, int(top + (head_zone.y_max + expand_y) * bh))

    if hx2 <= hx1 or hy2 <= hy1:
        return []

    # Crop expanded head zone
    head_arr = np.array(source.crop((hx1, hy1, hx2, hy2)))
    h_alpha = head_arr[:, :, 3]
    opmask = h_alpha > 128

    if np.sum(opmask) < 50:
        return []

    # Compute chroma (saturation) and brightness for each pixel.
    # Chroma = max(R,G,B) - min(R,G,B): high for saturated colors (any hue),
    # low for grays/neutrals. Works for warm eyes (orange) AND cool eyes (cyan).
    r = head_arr[:, :, 0].astype(np.float32)
    g = head_arr[:, :, 1].astype(np.float32)
    b = head_arr[:, :, 2].astype(np.float32)

    mx = np.maximum(r, np.maximum(g, b))
    mn = np.minimum(r, np.minimum(g, b))
    chroma = mx - mn  # 0 for pure grays, 255 for fully saturated

    brightness = (r + g + b) / 3.0

    # Eye score = chroma * brightness (eyes are saturated AND visible)
    # This finds: orange eyes on purple body, cyan eyes on dark hood,
    # any colored eye on any body — as long as eyes are more saturated.
    chroma_vals = chroma[opmask]
    bright_vals = brightness[opmask]

    chroma_min, chroma_max = chroma_vals.min(), chroma_vals.max()
    bright_min, bright_max = bright_vals.min(), bright_vals.max()

    if chroma_max - chroma_min < 15 or bright_max - bright_min < 20:
        if verbose:
            print(f"  Eyes: insufficient color contrast for detection")
        return []

    # Normalize both to 0-1 and combine
    chroma_norm = np.clip((chroma - chroma_min) / max(chroma_max - chroma_min, 1), 0, 1)
    bright_norm = np.clip((brightness - bright_min) / max(bright_max - bright_min, 1), 0, 1)
    eye_score = chroma_norm * bright_norm

    # Threshold at top percentile of eye_score
    score_vals = eye_score[opmask]
    threshold = np.percentile(score_vals, warmth_percentile)

    if threshold < 0.3:
        if verbose:
            print(f"  Eyes: eye score threshold too low ({threshold:.2f}), no clear eyes")
        return []

    hot_mask = opmask & (eye_score > threshold)
    hot_count = int(np.sum(hot_mask))

    if hot_count < min_eye_pixels:
        if verbose:
            print(f"  Eyes: only {hot_count} saturated pixels, below minimum {min_eye_pixels}")
        return []

    # Cluster by proximity using grid-based grouping
    ys, xs = np.where(hot_mask)
    grid_size = max(15, min(hx2 - hx1, hy2 - hy1) // 10)
    grid = defaultdict(list)
    for y, x in zip(ys.tolist(), xs.tolist()):
        grid[(y // grid_size, x // grid_size)].append((y, x))

    # Merge adjacent grid cells into clusters
    clusters = _merge_grid_clusters(grid, grid_size)

    # Filter: keep clusters with enough pixels
    clusters = [c for c in clusters if len(c) >= min_eye_pixels]

    # Split wide clusters: if a single cluster's width > 1.5x its height,
    # it likely contains two merged eyes (3/4 view) — split at the X median
    split_clusters = []
    for c in clusters:
        pts = np.array(c)
        x_min, x_max = int(pts[:, 1].min()), int(pts[:, 1].max())
        y_min, y_max = int(pts[:, 0].min()), int(pts[:, 0].max())
        c_width = x_max - x_min + 1
        c_height = max(1, y_max - y_min + 1)
        if c_width > c_height * 1.5 and len(c) >= max(6, min_eye_pixels):
            # Split at the X median
            x_median = float(np.median(pts[:, 1]))
            left_pts = [(y, x) for y, x in c if x <= x_median]
            right_pts = [(y, x) for y, x in c if x > x_median]
            split_min = max(3, min_eye_pixels // 3)
            if len(left_pts) >= split_min and len(right_pts) >= split_min:
                split_clusters.append(left_pts)
                split_clusters.append(right_pts)
                continue
        split_clusters.append(c)
    clusters = split_clusters

    # Sort by x-center (left to right)
    clusters.sort(key=lambda c: np.mean([p[1] for p in c]))
    # Keep at most 2 (left eye, right eye)
    clusters = clusters[:2]

    if verbose:
        print(f"  Eyes: {hot_count} warm pixels, {len(clusters)} clusters")

    # Build EyeRegion for each cluster
    eyes = []
    for cluster in clusters:
        pts = np.array(cluster)
        cy, cx = int(pts[:, 0].mean()), int(pts[:, 1].mean())
        y1, x1 = int(pts[:, 0].min()), int(pts[:, 1].min())
        y2, x2 = int(pts[:, 0].max()) + 1, int(pts[:, 1].max()) + 1

        # Tighten bbox: if much wider than tall, clamp to a reasonable
        # aspect ratio around the center (prevents artifacts between eyes)
        raw_w = x2 - x1
        raw_h = max(1, y2 - y1)
        max_w = max(raw_h * 3, int(len(cluster) ** 0.5) * 2 + 2)
        if raw_w > max_w:
            trim = (raw_w - max_w) // 2
            x1 += trim
            x2 -= trim

        # Eye color (average of cluster pixels)
        eye_pixels = np.array([head_arr[p[0], p[1], :3] for p in cluster])
        eye_color = tuple(eye_pixels.mean(axis=0).astype(int).tolist())

        # Lid color: sample fur pixels 5-20px above the eye
        lid_y_start = max(0, y1 - 20)
        lid_y_end = max(0, y1 - 3)
        lid_x_start = max(0, x1 - 5)
        lid_x_end = min(head_arr.shape[1], x2 + 5)

        lid_strip = head_arr[lid_y_start:lid_y_end, lid_x_start:lid_x_end]
        lid_alpha = lid_strip[:, :, 3] if lid_strip.size > 0 else np.array([])
        lid_opaque = lid_strip[:, :, :3][lid_alpha > 128] if lid_alpha.size > 0 else np.array([])

        if len(lid_opaque) > 0:
            lid_color = tuple(lid_opaque.mean(axis=0).astype(int).tolist())
        else:
            # Fallback: use pixels just beside the eye
            lid_color = _sample_surrounding(head_arr, y1, y2, x1, x2)

        # Convert to source image coordinates
        abs_bbox = (hx1 + x1, hy1 + y1, hx1 + x2, hy1 + y2)
        abs_center = (hx1 + cx, hy1 + cy)

        eyes.append(EyeRegion(
            bbox=abs_bbox,
            center=abs_center,
            color=eye_color,
            lid_color=lid_color,
            pixel_count=len(cluster),
        ))

        if verbose:
            print(f"    Eye at ({abs_center[0]},{abs_center[1]}): "
                  f"{len(cluster)}px, color=RGB{eye_color}, lid=RGB{lid_color}")

    return eyes


def _merge_grid_clusters(
    grid: dict,
    grid_size: int,
) -> List[List[Tuple[int, int]]]:
    """Merge adjacent grid cells into connected clusters."""
    visited = set()
    clusters = []

    for key in grid:
        if key in visited:
            continue
        # BFS to find connected cells
        cluster_points = []
        queue = [key]
        while queue:
            cell = queue.pop(0)
            if cell in visited:
                continue
            visited.add(cell)
            if cell in grid:
                cluster_points.extend(grid[cell])
                # Check 8-connected neighbors
                gy, gx = cell
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        neighbor = (gy + dy, gx + dx)
                        if neighbor not in visited and neighbor in grid:
                            queue.append(neighbor)
        if cluster_points:
            clusters.append(cluster_points)

    return clusters


def _sample_surrounding(
    arr: np.ndarray,
    y1: int, y2: int, x1: int, x2: int,
) -> Tuple[int, int, int]:
    """Sample the average color around a region (fallback for lid color)."""
    h, w = arr.shape[:2]
    pad = 10
    sy1, sy2 = max(0, y1 - pad), min(h, y2 + pad)
    sx1, sx2 = max(0, x1 - pad), min(w, x2 + pad)

    surround = arr[sy1:sy2, sx1:sx2]
    mask = surround[:, :, 3] > 128

    # Exclude the eye region itself
    inner_y1 = y1 - sy1
    inner_y2 = y2 - sy1
    inner_x1 = x1 - sx1
    inner_x2 = x2 - sx1
    mask[inner_y1:inner_y2, inner_x1:inner_x2] = False

    pixels = surround[:, :, :3][mask]
    if len(pixels) > 0:
        return tuple(pixels.mean(axis=0).astype(int).tolist())
    return (100, 80, 100)  # fallback gray-purple
