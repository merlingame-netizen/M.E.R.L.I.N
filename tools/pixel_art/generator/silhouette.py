"""Silhouette generator — converts shape type + proportions into key points.

Each silhouette function returns a SilhouettePoints dataclass containing
the outer edge, interior shared vertices, and drape points needed by
the geometry engine to create tiled facets.

Reference: M.E.R.L.I.N. bell curve on 256x256 canvas:
  Peak:     (128, 44)
  Flank:    (76, 62)
  Mid-bell: (42, 104)
  Shoulder: (30, 152)
  Bottom:   (40, 190)
  Interior: (98,70), (76,118), (82,158)
  Drape:    (98, 170)
  Center:   (128, 158)
"""

from dataclasses import dataclass
from typing import List, Tuple
import math

from .character_spec import SilhouetteShape, ProportionSpec

Point = Tuple[float, float]


@dataclass(frozen=True)
class SilhouettePoints:
    """Complete silhouette definition for one character."""
    peak: Point
    left_outer: List[Point]
    right_outer: List[Point]
    left_interior: List[Point]
    right_interior: List[Point]
    drape_left: Point
    drape_right: Point
    center_bottom: Point


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mirror_x(point: Point, center_x: float) -> Point:
    """Mirror a point horizontally around center_x."""
    return (2 * center_x - point[0], point[1])


def _lerp(a: Point, b: Point, t: float) -> Point:
    """Linear interpolation between two points."""
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _quadratic_bezier(p0: Point, p1: Point, p2: Point, t: float) -> Point:
    """Quadratic bezier interpolation."""
    u = 1 - t
    x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
    y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
    return (x, y)


def _subdivide_curve(points: List[Point], detail: int, smooth: bool = True) -> List[Point]:
    """Subdivide a polyline into more points using bezier or linear interpolation.

    If smooth=True, uses quadratic bezier between every 3 consecutive points.
    If smooth=False, uses linear interpolation (angular look).
    Returns a list with approximately detail * (len(points)-1) segments.
    """
    if len(points) < 2:
        return list(points)

    if not smooth:
        # Linear: just interpolate between each pair
        result = [points[0]]
        for i in range(len(points) - 1):
            for j in range(1, detail + 1):
                t = j / detail
                result.append(_lerp(points[i], points[i + 1], t))
        return result

    # Smooth: quadratic bezier through triplets
    if len(points) == 2:
        result = [points[0]]
        for j in range(1, detail + 1):
            t = j / detail
            result.append(_lerp(points[0], points[1], t))
        return result

    result = [points[0]]
    for i in range(len(points) - 2):
        p0 = points[i]
        p1 = points[i + 1]
        p2 = points[i + 2]
        # Use the middle point as a control point
        mid_start = _lerp(p0, p1, 0.5) if i > 0 else p0
        mid_end = _lerp(p1, p2, 0.5)

        steps = max(2, detail)
        for j in range(1, steps + 1):
            t = j / steps
            pt = _quadratic_bezier(mid_start, p1, mid_end, t)
            result.append(pt)

    # Ensure last point is included
    if result[-1] != points[-1]:
        result.append(points[-1])

    return result


def _compute_interior(outer: List[Point], center_x: float, center_y: float,
                      inset_ratio: float = 0.35) -> List[Point]:
    """Compute interior vertices by moving outer points toward center line.

    inset_ratio: how far toward center (0.0 = at outer, 1.0 = at center).
    Returns one interior point per outer point (excluding first=peak).
    """
    interior = []
    for ox, oy in outer:
        ix = ox + (center_x - ox) * inset_ratio
        iy = oy + (center_y - oy) * 0.15  # Slight vertical shift
        interior.append((ix, iy))
    return interior


# ---------------------------------------------------------------------------
# Master dispatcher
# ---------------------------------------------------------------------------

def generate_silhouette(
    shape: SilhouetteShape,
    proportions: ProportionSpec,
    canvas_w: int = 256,
    canvas_h: int = 256,
    detail: int = 4,
) -> SilhouettePoints:
    """Generate silhouette points for the given shape and proportions."""
    dispatch = {
        SilhouetteShape.BELL: _bell_silhouette,
        SilhouetteShape.ANGULAR: _angular_silhouette,
        SilhouetteShape.ROUNDED: _rounded_silhouette,
        SilhouetteShape.HORNED: _horned_silhouette,
        SilhouetteShape.SPIKY: _spiky_silhouette,
        SilhouetteShape.FLAT_TOP: _flat_top_silhouette,
        SilhouetteShape.TAPERED: _tapered_silhouette,
    }
    fn = dispatch.get(shape, _bell_silhouette)
    return fn(proportions, canvas_w, canvas_h, detail)


# ---------------------------------------------------------------------------
# Bell (M.E.R.L.I.N.-style hood)
# ---------------------------------------------------------------------------

def _bell_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Bell curve silhouette — the reference M.E.R.L.I.N. shape.

    Generates a bell/dome outline from 5 control points per side,
    then derives interior vertices for facet tiling.
    """
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio  # Height of head section

    # Peak
    peak_y = ch * 0.17
    peak = (cx, peak_y)

    # Left-side control points (top to bottom)
    # These ratios reproduce M.E.R.L.I.N.'s bell when proportions are default
    half_w = cw * props.shoulder_width * 0.45  # Hood is ~90% of shoulder width

    flank_y = peak_y + head_h * 0.12
    flank_x = cx - half_w * 0.55

    mid_y = peak_y + head_h * 0.41
    mid_x = cx - half_w * 0.91

    shoulder_y = peak_y + head_h * 0.74
    shoulder_x = cx - half_w * 1.04

    bottom_y = peak_y + head_h * 1.0
    bottom_x = cx - half_w * 0.93

    left_controls = [
        (flank_x, flank_y),
        (mid_x, mid_y),
        (shoulder_x, shoulder_y),
        (bottom_x, bottom_y),
    ]

    # Generate outer points based on detail level
    if detail <= 4:
        left_outer = list(left_controls)
    else:
        left_outer = _subdivide_curve(left_controls, max(1, detail // 4), smooth=True)

    # Mirror for right side
    right_outer = [_mirror_x(p, cx) for p in left_outer]

    # Interior vertices (shared edges between outer and inner facets)
    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.40)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.40)

    # Drape points (where hood fabric curves back in at bottom)
    drape_y = peak_y + head_h * 0.86
    drape_left = (cx - half_w * 0.62, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak,
        left_outer=left_outer,
        right_outer=right_outer,
        left_interior=left_interior,
        right_interior=right_interior,
        drape_left=drape_left,
        drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Angular (crystal/pyramid)
# ---------------------------------------------------------------------------

def _angular_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Sharp geometric silhouette — straight lines, crystal/pyramid look."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.14
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45

    left_controls = [
        (cx - half_w * 0.30, peak_y + head_h * 0.15),
        (cx - half_w * 0.85, peak_y + head_h * 0.35),
        (cx - half_w * 1.05, peak_y + head_h * 0.65),
        (cx - half_w * 0.95, peak_y + head_h * 1.0),
    ]

    if detail > 4:
        left_outer = _subdivide_curve(left_controls, max(1, detail // 4), smooth=False)
    else:
        left_outer = list(left_controls)

    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.35)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.35)

    drape_y = peak_y + head_h * 0.88
    drape_left = (cx - half_w * 0.55, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Rounded (dome/blob)
# ---------------------------------------------------------------------------

def _rounded_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Soft dome/egg silhouette — elliptical arc, good for creatures."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.15
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45

    # Use circular arc control points for a smooth dome
    steps = max(4, detail)
    left_controls = []
    for i in range(1, steps + 1):
        t = i / steps
        angle = t * math.pi / 2  # 0 to 90 degrees
        x = cx - half_w * math.sin(angle)
        y = peak_y + head_h * (1 - math.cos(angle)) * 0.9
        left_controls.append((x, y))

    # Add bottom point
    left_controls.append((cx - half_w * 0.85, peak_y + head_h * 1.0))

    left_outer = left_controls
    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.80
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.40)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.40)

    drape_y = peak_y + head_h * 0.90
    drape_left = (cx - half_w * 0.55, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Horned (two-peak)
# ---------------------------------------------------------------------------

def _horned_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Two-peak silhouette — horns or ears extending from a dome base."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.20  # Slightly lower peak (horns go above)
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45
    horn_height = head_h * 0.25

    left_controls = [
        # Horn tip (extends above peak)
        (cx - half_w * 0.35, peak_y - horn_height),
        # Horn base
        (cx - half_w * 0.40, peak_y + head_h * 0.08),
        # Bell below horn
        (cx - half_w * 0.85, peak_y + head_h * 0.40),
        (cx - half_w * 1.0, peak_y + head_h * 0.70),
        (cx - half_w * 0.90, peak_y + head_h * 1.0),
    ]

    if detail > 4:
        left_outer = _subdivide_curve(left_controls, max(1, detail // 4), smooth=True)
    else:
        left_outer = list(left_controls)

    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.38)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.38)

    drape_y = peak_y + head_h * 0.88
    drape_left = (cx - half_w * 0.55, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Spiky (irregular multi-peak)
# ---------------------------------------------------------------------------

def _spiky_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Multiple irregular peaks — eldritch, crystal, hedgehog."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.12
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45
    spike_depth = head_h * 0.08

    left_controls = [
        # Spike 1 (top)
        (cx - half_w * 0.20, peak_y + head_h * 0.05),
        # Valley
        (cx - half_w * 0.35, peak_y + head_h * 0.15 + spike_depth),
        # Spike 2 (mid)
        (cx - half_w * 0.55, peak_y + head_h * 0.20),
        # Valley
        (cx - half_w * 0.75, peak_y + head_h * 0.35 + spike_depth),
        # Spike 3 (lower)
        (cx - half_w * 0.95, peak_y + head_h * 0.45),
        # Body
        (cx - half_w * 1.0, peak_y + head_h * 0.70),
        (cx - half_w * 0.90, peak_y + head_h * 1.0),
    ]

    left_outer = list(left_controls)
    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.35)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.35)

    drape_y = peak_y + head_h * 0.88
    drape_left = (cx - half_w * 0.55, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Flat top (helm/crown)
# ---------------------------------------------------------------------------

def _flat_top_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Flat/truncated top — helmet, crown, rectangular head."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.16
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45
    top_w = half_w * 0.55  # Flat top width

    left_controls = [
        # Flat top corner
        (cx - top_w, peak_y),
        # Vertical side, then expand
        (cx - top_w * 1.1, peak_y + head_h * 0.20),
        (cx - half_w * 0.95, peak_y + head_h * 0.45),
        (cx - half_w * 1.0, peak_y + head_h * 0.70),
        (cx - half_w * 0.90, peak_y + head_h * 1.0),
    ]

    if detail > 4:
        left_outer = _subdivide_curve(left_controls, max(1, detail // 4), smooth=False)
    else:
        left_outer = list(left_controls)

    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.38)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.38)

    drape_y = peak_y + head_h * 0.88
    drape_left = (cx - half_w * 0.55, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )


# ---------------------------------------------------------------------------
# Tapered (narrow top, wide base — cone/ghost)
# ---------------------------------------------------------------------------

def _tapered_silhouette(props: ProportionSpec, cw: int, ch: int, detail: int) -> SilhouettePoints:
    """Narrow top, wide base — cone, ghost, robed figure."""
    cx = cw / 2 + props.peak_offset_x * cw * 0.1
    head_h = ch * props.head_ratio
    peak_y = ch * 0.10  # Tall peak
    peak = (cx, peak_y)

    half_w = cw * props.shoulder_width * 0.45

    left_controls = [
        (cx - half_w * 0.15, peak_y + head_h * 0.15),
        (cx - half_w * 0.40, peak_y + head_h * 0.35),
        (cx - half_w * 0.70, peak_y + head_h * 0.55),
        (cx - half_w * 1.0, peak_y + head_h * 0.80),
        (cx - half_w * 1.10, peak_y + head_h * 1.0),
    ]

    if detail > 4:
        left_outer = _subdivide_curve(left_controls, max(1, detail // 4), smooth=True)
    else:
        left_outer = list(left_controls)

    right_outer = [_mirror_x(p, cx) for p in left_outer]

    center_bottom_y = peak_y + head_h * 0.78
    center_bottom = (cx, center_bottom_y)

    left_interior = _compute_interior(left_outer, cx, center_bottom_y, inset_ratio=0.35)
    right_interior = _compute_interior(right_outer, cx, center_bottom_y, inset_ratio=0.35)

    drape_y = peak_y + head_h * 0.90
    drape_left = (cx - half_w * 0.65, drape_y)
    drape_right = _mirror_x(drape_left, cx)

    return SilhouettePoints(
        peak=peak, left_outer=left_outer, right_outer=right_outer,
        left_interior=left_interior, right_interior=right_interior,
        drape_left=drape_left, drape_right=drape_right,
        center_bottom=center_bottom,
    )
