"""Geometry engine v3 — large-facet mesh matching gold standard structure.

The reference style uses FEW LARGE facets (~4 per hood side), NOT many
small triangles. Each facet covers a significant visual area and has a
distinctly different shade from its neighbors. The visual detail comes
from STRONG CONTRAST between adjacent faces, not from polygon count.

Hood structure (per side):
  - Facet 1: Upper outer — steep slope from peak to mid-bell (pentagon)
  - Facet 2: Lower outer — flatter slope from mid-bell to bottom (pentagon)
  - Facet 3: Inner — faces center/viewer, recessed (pentagon)
  - Facet 4: Lower drape — deep shadow at bottom (quad)
Plus peak details (3 facets), highlights (2-3 facets), drape extensions.

Reference: merlin_lowpoly.py gold standard v15 (~38 facets total).
"""

import math
from typing import List, Tuple

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.low_poly_mesh import LowPolyMesh
from .character_spec import (
    CharacterSpec, TemplateType, EyeStyle, AccessorySlot, AccessorySide,
)
from .silhouette import SilhouettePoints, generate_silhouette, Point
from .color_engine import ColorMap, generate_color_map

CW = 256
CH = 256


def generate_mesh(spec: CharacterSpec) -> LowPolyMesh:
    """Master function: CharacterSpec -> LowPolyMesh."""
    sil = generate_silhouette(spec.silhouette, spec.proportions, CW, CH, spec.detail_level)
    colors = generate_color_map(spec)
    mesh = LowPolyMesh(CW, CH)

    _build_body_core(mesh, spec, sil, colors)
    _build_shoulders(mesh, spec, sil, colors)
    _build_hood(mesh, spec, sil, colors)
    _build_face_void(mesh, spec, sil, colors)
    _build_face_frame(mesh, spec, sil, colors)
    _build_eyes(mesh, spec, sil, colors)
    _build_accessories(mesh, spec, sil, colors)

    return mesh


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mid(a: Point, b: Point) -> Point:
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def _lerp(a: Point, b: Point, t: float) -> Point:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# ---------------------------------------------------------------------------
# Body core (z=0-2) — exactly matching gold standard
# ---------------------------------------------------------------------------

def _build_body_core(mesh: LowPolyMesh, spec: CharacterSpec,
                     sil: SilhouettePoints, colors: ColorMap):
    gs = colors.grayscale
    cx = CW / 2
    body_w = CW * spec.proportions.body_width
    half_bw = body_w / 2

    # Body extends from below shoulders to near canvas bottom
    shldr_top_y = sil.center_bottom[1] - 16
    body_top_y = shldr_top_y
    body_bot_y = CH * 0.95

    # Full body fill (void background)
    mesh.add_facet('body_fill',
                   [(cx - half_bw - 24, body_top_y),
                    (cx + half_bw + 24, body_top_y),
                    (cx + half_bw + 20, body_bot_y),
                    (cx - half_bw - 20, body_bot_y)],
                   gs.get('void', '#000000'), 'body', 0)

    # Chest plates (centered, narrower than body)
    chest_w = half_bw * 0.50
    mesh.add_facet('chest_upper',
                   [(cx - chest_w, body_top_y),
                    (cx + chest_w, body_top_y),
                    (cx + chest_w - 4, body_top_y + 40),
                    (cx - chest_w + 4, body_top_y + 40)],
                   gs.get('deep', '#0a0a12'), 'body', 1)

    mesh.add_facet('chest_lower',
                   [(cx - chest_w + 4, body_top_y + 40),
                    (cx + chest_w - 4, body_top_y + 40),
                    (cx + chest_w - 8, body_bot_y - 8),
                    (cx - chest_w + 8, body_bot_y - 8)],
                   gs.get('dark1', '#151520'), 'body', 1)

    # Center seam
    mesh.add_facet('chest_seam',
                   [(cx - 1, body_top_y + 2), (cx + 1, body_top_y + 2),
                    (cx + 1, body_bot_y - 8), (cx - 1, body_bot_y - 8)],
                   gs.get('dark2', '#222230'), 'body', 2)


# ---------------------------------------------------------------------------
# Shoulders (z=2-5) — matching gold standard: 5 facets per side
# ---------------------------------------------------------------------------

def _build_shoulders(mesh: LowPolyMesh, spec: CharacterSpec,
                     sil: SilhouettePoints, colors: ColorMap):
    gs = colors.grayscale
    cx = CW / 2
    shldr_w = CW * spec.proportions.shoulder_width / 2
    body_w = CW * spec.proportions.body_width / 2

    shldr_top_y = sil.center_bottom[1] - 20
    shldr_bot_y = CH * 0.86
    inner_x_offset = body_w * 0.78

    for side_name, sign, shades in [
        ('l', -1, {'side': 'dark2', 'top': 'mid1', 'front': 'dark3',
                   'bevel': 'mid2', 'bottom': 'dark1'}),
        ('r', 1,  {'side': 'mid2', 'top': 'mid3', 'front': 'mid1',
                   'bevel': 'light1', 'bottom': 'dark2'}),
    ]:
        group = f'shoulder_{side_name}'
        outer = cx + sign * shldr_w
        inner = cx + sign * inner_x_offset

        # Side plate (outer edge, vertical)
        mesh.add_facet(f'shldr_{side_name}_side',
                       [(outer, shldr_top_y - 4),
                        (outer + sign * (-8), shldr_top_y + 14),
                        (outer + sign * (-12), shldr_bot_y),
                        (outer + sign * (-2), shldr_bot_y - 4)],
                       gs.get(shades['side'], '#222230'), group, 3)

        # Top plate (catches most light on right side)
        mesh.add_facet(f'shldr_{side_name}_top',
                       [(outer, shldr_top_y - 4),
                        (inner, shldr_top_y - 8),
                        (inner + sign * (-4), shldr_top_y + 8),
                        (outer + sign * (-8), shldr_top_y + 14)],
                       gs.get(shades['top'], '#3a4048'), group, 4)

        # Front plate (main visible area)
        mesh.add_facet(f'shldr_{side_name}_front',
                       [(outer + sign * (-8), shldr_top_y + 14),
                        (inner + sign * (-4), shldr_top_y + 8),
                        (inner + sign * (-6), shldr_bot_y),
                        (outer + sign * (-12), shldr_bot_y)],
                       gs.get(shades['front'], '#2a3038'), group, 3)

        # Bevel strip (subtle bright edge on top)
        mesh.add_facet(f'shldr_{side_name}_bevel',
                       [(outer + sign * (-4), shldr_top_y),
                        (inner + sign * 2, shldr_top_y - 4),
                        (inner, shldr_top_y + 4),
                        (outer + sign * (-6), shldr_top_y + 6)],
                       gs.get(shades['bevel'], '#4a5058'), group, 5)

        # Bottom plate
        mesh.add_facet(f'shldr_{side_name}_bottom',
                       [(outer + sign * (-2), shldr_bot_y - 4),
                        (outer + sign * (-12), shldr_bot_y),
                        (inner + sign * (-6), shldr_bot_y),
                        (inner + sign * (-4), shldr_bot_y + 8),
                        (outer + sign * (-4), shldr_bot_y + 8)],
                       gs.get(shades['bottom'], '#151520'), group, 2)


# ---------------------------------------------------------------------------
# Hood (z=6-9) — LARGE FACETS, 4 per side (matching gold standard)
# ---------------------------------------------------------------------------

def _build_hood(mesh: LowPolyMesh, spec: CharacterSpec,
                sil: SilhouettePoints, colors: ColorMap):
    """Build hood with LARGE facets — 4 per side like the gold standard.

    Left side (shadow): dark3 → dark2 → dark2 → dark1
    Right side (lit):   mid2  → mid1  → mid1  → dark3
    """
    gs = colors.grayscale
    pk = sil.peak
    cb = sil.center_bottom
    cx = CW / 2

    lo = sil.left_outer
    ro = sil.right_outer
    li = sil.left_interior
    ri = sil.right_interior

    n = len(lo)
    if n < 2:
        return

    # Split outer/interior points into upper and lower halves
    mid_idx = n // 2

    # --- LEFT SIDE: 4 large facets ---

    # L1: Upper outer — peak → upper_outers → mid_interior → upper_interior
    l1_points = [pk]
    for i in range(mid_idx + 1):
        l1_points.append(lo[i])
    l1_points.append(li[mid_idx])
    l1_points.append(li[0])
    mesh.add_facet('hood_l1', l1_points,
                   gs.get('dark3', '#2a3038'), 'hood', 6)

    # L2: Lower outer — mid_interior → mid_outer → bottom_outers → lower_interior
    l2_points = [li[mid_idx]]
    for i in range(mid_idx, n):
        l2_points.append(lo[i])
    l2_points.append(sil.drape_left)
    l2_points.append(li[-1] if n > mid_idx else cb)
    mesh.add_facet('hood_l2', l2_points,
                   gs.get('dark2', '#222230'), 'hood', 6)

    # L3: Inner — peak → upper_interiors → lower_interior → center_bottom
    l3_points = [pk]
    for i in range(n):
        l3_points.append(li[i])
    l3_points.append(cb)
    mesh.add_facet('hood_l3', l3_points,
                   gs.get('dark2', '#222230'), 'hood', 7)

    # L4: Lower drape — lower_interior → bottom_outer → drape → center_bottom
    mesh.add_facet('hood_l4',
                   [li[-1], lo[-1], sil.drape_left, cb],
                   gs.get('dark1', '#151520'), 'hood', 6)

    # --- RIGHT SIDE: 4 large facets ---

    # R1: Upper outer
    r1_points = [pk]
    for i in range(mid_idx + 1):
        r1_points.append(ro[i])
    r1_points.append(ri[mid_idx])
    r1_points.append(ri[0])
    mesh.add_facet('hood_r1', r1_points,
                   gs.get('mid2', '#4a5058'), 'hood', 6)

    # R2: Lower outer
    r2_points = [ri[mid_idx]]
    for i in range(mid_idx, n):
        r2_points.append(ro[i])
    r2_points.append(sil.drape_right)
    r2_points.append(ri[-1] if n > mid_idx else cb)
    mesh.add_facet('hood_r2', r2_points,
                   gs.get('mid1', '#3a4048'), 'hood', 6)

    # R3: Inner
    r3_points = [pk]
    for i in range(n):
        r3_points.append(ri[i])
    r3_points.append(cb)
    mesh.add_facet('hood_r3', r3_points,
                   gs.get('mid1', '#3a4048'), 'hood', 7)

    # R4: Lower drape
    mesh.add_facet('hood_r4',
                   [ri[-1], ro[-1], sil.drape_right, cb],
                   gs.get('dark3', '#2a3038'), 'hood', 6)

    # --- Drape extensions ---
    if n > 0:
        mesh.add_facet('hood_drape_l',
                       [lo[-1], sil.drape_left,
                        (sil.drape_left[0] + 4, sil.drape_left[1] + 10),
                        (lo[-1][0] + 6, lo[-1][1] + 8)],
                       gs.get('dark1', '#151520'), 'hood', 6)

        mesh.add_facet('hood_drape_r',
                       [ro[-1], sil.drape_right,
                        (sil.drape_right[0] - 4, sil.drape_right[1] + 10),
                        (ro[-1][0] - 6, ro[-1][1] + 8)],
                       gs.get('dark2', '#222230'), 'hood', 6)

    # --- Peak details (z=9) ---
    _build_peak_details(mesh, sil, colors)

    # --- Highlights (z=8) ---
    _build_hood_highlights(mesh, sil, colors)


def _build_peak_details(mesh: LowPolyMesh, sil: SilhouettePoints, colors: ColorMap):
    """Peak ridge with light/shadow slopes."""
    gs = colors.grayscale
    px, py = sil.peak

    if not sil.left_outer or not sil.right_outer:
        return

    lo0 = sil.left_outer[0]
    ro0 = sil.right_outer[0]

    # Right slope highlight (bright edge facing light)
    mesh.add_facet('hood_peak_hi',
                   [(px, py), (px + 12, py + 6), ro0, (ro0[0] - 8, ro0[1] - 2)],
                   gs.get('light1', '#687078'), 'hood', 9)

    # Left slope shadow
    mesh.add_facet('hood_peak_sh',
                   [(px, py), (px - 12, py + 6), lo0, (lo0[0] + 8, lo0[1] - 2)],
                   gs.get('dark1', '#151520'), 'hood', 9)

    # Ridge cap
    mesh.add_facet('hood_peak_cap',
                   [(px - 12, py + 6), (px + 12, py + 6),
                    (px + 10, py + 12), (px - 10, py + 12)],
                   gs.get('mid1', '#3a4048'), 'hood', 9)

    # Centerline ridge
    mesh.add_facet('hood_centerline',
                   [(px - 2, py + 4), (px + 2, py + 4),
                    (px + 2, py + 42), (px - 2, py + 42)],
                   gs.get('mid3', '#586068'), 'hood', 9)


def _build_hood_highlights(mesh: LowPolyMesh, sil: SilhouettePoints, colors: ColorMap):
    """Bright highlight facets on right side (where light hits)."""
    gs = colors.grayscale

    if len(sil.right_outer) < 2 or len(sil.right_interior) < 2:
        return

    ro0 = sil.right_outer[0]
    ri0 = sil.right_interior[0]
    ro1 = sil.right_outer[1]
    ri1 = sil.right_interior[1]

    # Large BRIGHT highlight (key visual feature)
    mesh.add_facet('hood_r_highlight',
                   [ri0, ro0, _mid(ro0, ro1), _mid(ri0, ri1)],
                   gs.get('bright', '#a8b0b8'), 'hood', 8)

    # Secondary highlight below
    mesh.add_facet('hood_r_accent',
                   [_mid(ri0, ri1), _mid(ro0, ro1), ro1, ri1],
                   gs.get('light2', '#8a9098'), 'hood', 8)

    # Tertiary highlight (mid-hood)
    if len(sil.right_outer) >= 3:
        ro2 = sil.right_outer[2]
        ri2 = sil.right_interior[2]
        mesh.add_facet('hood_r_accent2',
                       [ri1, ro1, _mid(ro1, ro2), _mid(ri1, ri2)],
                       gs.get('light1', '#687078'), 'hood', 8)

    # Left subtle highlight (even shadow side catches some light)
    if len(sil.left_outer) >= 2 and len(sil.left_interior) >= 2:
        lo0 = sil.left_outer[0]
        li0 = sil.left_interior[0]
        lo1 = sil.left_outer[1]
        li1 = sil.left_interior[1]
        mesh.add_facet('hood_l_highlight',
                       [li0, lo0, _mid(lo0, lo1), _mid(li0, li1)],
                       gs.get('mid1', '#3a4048'), 'hood', 8)


# ---------------------------------------------------------------------------
# Face void (z=10-11)
# ---------------------------------------------------------------------------

def _build_face_void(mesh: LowPolyMesh, spec: CharacterSpec,
                     sil: SilhouettePoints, colors: ColorMap):
    gs = colors.grayscale
    face = spec.face

    if face.height <= 0 or face.width_top <= 0:
        return

    cx = CW / 2
    face_top_y = CH * face.vertical_position
    face_bot_y = face_top_y + CH * face.height
    half_top = CW * face.width_top / 2
    half_bot = CW * face.width_bottom / 2

    # Main void trapezoid
    mesh.add_facet('face_main',
                   [(cx - half_top, face_top_y), (cx + half_top, face_top_y),
                    (cx + half_bot, face_bot_y), (cx - half_bot, face_bot_y)],
                   gs.get('void', '#000000'), 'face', 10)

    # Depth shadows on sides
    if face.has_depth_shadows:
        mesh.add_facet('face_depth_l',
                       [(cx - half_bot, face_top_y), (cx - half_top, face_top_y),
                        (cx - half_bot, face_bot_y)],
                       gs.get('deep', '#0a0a12'), 'face', 10)
        mesh.add_facet('face_depth_r',
                       [(cx + half_top, face_top_y), (cx + half_bot, face_top_y),
                        (cx + half_bot, face_bot_y)],
                       gs.get('deep', '#0a0a12'), 'face', 10)

    # Chin band
    if face.has_chin_band:
        mesh.add_facet('face_chin',
                       [(cx - half_bot, face_bot_y - 6), (cx + half_bot, face_bot_y - 6),
                        (cx + half_bot, face_bot_y), (cx - half_bot, face_bot_y)],
                       gs.get('dark1', '#151520'), 'face', 11)


# ---------------------------------------------------------------------------
# Face frame (z=13) — matching gold standard's thin precise frame
# ---------------------------------------------------------------------------

def _build_face_frame(mesh: LowPolyMesh, spec: CharacterSpec,
                      sil: SilhouettePoints, colors: ColorMap):
    gs = colors.grayscale
    face = spec.face

    if face.height <= 0 or face.width_top <= 0:
        return

    cx = CW / 2
    face_top_y = CH * face.vertical_position
    face_bot_y = face_top_y + CH * face.height
    half_top = CW * face.width_top / 2
    half_bot = CW * face.width_bottom / 2

    # Top edge — bright, angular, thin (3px like gold standard)
    mesh.add_facet('frame_top',
                   [(cx - half_top - 2, face_top_y - 3),
                    (cx + half_top + 2, face_top_y - 3),
                    (cx + half_top, face_top_y),
                    (cx - half_top, face_top_y)],
                   gs.get('light2', '#8a9098'), 'hood', 13)

    # Right edge (lit side)
    mesh.add_facet('frame_r',
                   [(cx + half_bot + 3, face_top_y - 1),
                    (cx + half_bot + 5, face_bot_y + 1),
                    (cx + half_bot, face_bot_y),
                    (cx + half_top, face_top_y)],
                   gs.get('light2', '#8a9098'), 'hood', 13)

    # Left edge (shadow)
    mesh.add_facet('frame_l',
                   [(cx - half_bot - 3, face_top_y - 1),
                    (cx - half_bot - 5, face_bot_y + 1),
                    (cx - half_bot, face_bot_y),
                    (cx - half_top, face_top_y)],
                   gs.get('mid2', '#4a5058'), 'hood', 13)


# ---------------------------------------------------------------------------
# Eyes (z=14)
# ---------------------------------------------------------------------------

def _build_eyes(mesh: LowPolyMesh, spec: CharacterSpec,
                sil: SilhouettePoints, colors: ColorMap):
    eyes = spec.eyes
    face = spec.face

    if eyes.style == EyeStyle.NONE or face.height <= 0:
        return

    cx = CW / 2
    face_top_y = CH * face.vertical_position
    face_h = CH * face.height
    face_w = CW * face.width_top

    eye_y = face_top_y + face_h * eyes.vertical_position

    acc = colors.accent_bright
    acc_halo = colors.accent_halo

    if eyes.style == EyeStyle.SLIT:
        _build_slit_eyes(mesh, cx, eye_y, face_w, eyes, acc, acc_halo)
    elif eyes.style == EyeStyle.ROUND:
        _build_round_eyes(mesh, cx, eye_y, face_w, eyes, acc, acc_halo)
    elif eyes.style == EyeStyle.SINGLE:
        _build_single_eye(mesh, cx, eye_y, eyes, acc, acc_halo)
    elif eyes.style == EyeStyle.MULTI:
        _build_multi_eyes(mesh, cx, eye_y, face_w, face_h, eyes, acc, acc_halo)
    elif eyes.style == EyeStyle.VISOR:
        _build_visor_eye(mesh, cx, eye_y, face_w, eyes, acc, acc_halo)


def _build_slit_eyes(mesh, cx, eye_y, face_w, eyes, acc, acc_halo):
    spacing = face_w * eyes.spacing / 2
    slit_w = eyes.glow_radius * 2.8
    slit_h = eyes.glow_radius * 1.5

    for idx, side_x in enumerate([cx - spacing, cx + spacing]):
        name = f'eye_{idx}'
        mesh.add_glow(f'{name}_halo', (side_x, eye_y), eyes.glow_radius,
                       acc, halo_radius=eyes.halo_radius, halo_color=acc_halo,
                       group='eyes')
        mesh.add_facet(f'{name}_slit',
                       [(side_x - slit_w, eye_y), (side_x, eye_y - slit_h),
                        (side_x + slit_w, eye_y), (side_x, eye_y + slit_h)],
                       acc, 'eyes', 14)


def _build_round_eyes(mesh, cx, eye_y, face_w, eyes, acc, acc_halo):
    spacing = face_w * eyes.spacing / 2
    for idx, side_x in enumerate([cx - spacing, cx + spacing]):
        mesh.add_glow(f'eye_{idx}_glow', (side_x, eye_y), eyes.glow_radius,
                       acc, halo_radius=eyes.halo_radius, halo_color=acc_halo,
                       group='eyes')


def _build_single_eye(mesh, cx, eye_y, eyes, acc, acc_halo):
    mesh.add_glow('eye_0_halo', (cx, eye_y), eyes.glow_radius * 1.5,
                   acc, halo_radius=eyes.halo_radius * 1.3, halo_color=acc_halo,
                   group='eyes')
    r = eyes.glow_radius * 2
    mesh.add_facet('eye_0_slit',
                   [(cx - r, eye_y), (cx, eye_y - r * 0.7),
                    (cx + r, eye_y), (cx, eye_y + r * 0.7)],
                   acc, 'eyes', 14)


def _build_multi_eyes(mesh, cx, eye_y, face_w, face_h, eyes, acc, acc_halo):
    count = min(eyes.count, 6)
    spacing = face_w * 0.7 / max(count - 1, 1)
    start_x = cx - (count - 1) * spacing / 2
    for idx in range(count):
        ex = start_x + idx * spacing
        ey = eye_y + (idx % 2) * (face_h * 0.08)
        r = eyes.glow_radius * (0.8 if idx % 2 else 1.0)
        mesh.add_glow(f'eye_{idx}_glow', (ex, ey), r,
                       acc, halo_radius=eyes.halo_radius * 0.8,
                       halo_color=acc_halo, group='eyes')


def _build_visor_eye(mesh, cx, eye_y, face_w, eyes, acc, acc_halo):
    half_w = face_w * 0.4
    bar_h = eyes.glow_radius * 1.2
    mesh.add_glow('visor_glow_l', (cx - half_w * 0.5, eye_y),
                   eyes.glow_radius, acc, halo_radius=eyes.halo_radius,
                   halo_color=acc_halo, group='eyes')
    mesh.add_glow('visor_glow_r', (cx + half_w * 0.5, eye_y),
                   eyes.glow_radius, acc, halo_radius=eyes.halo_radius,
                   halo_color=acc_halo, group='eyes')
    mesh.add_facet('visor_bar',
                   [(cx - half_w, eye_y - bar_h), (cx + half_w, eye_y - bar_h),
                    (cx + half_w, eye_y + bar_h), (cx - half_w, eye_y + bar_h)],
                   acc, 'eyes', 14)


# ---------------------------------------------------------------------------
# Accessories (z=15)
# ---------------------------------------------------------------------------

def _build_accessories(mesh: LowPolyMesh, spec: CharacterSpec,
                       sil: SilhouettePoints, colors: ColorMap):
    cx = CW / 2
    shldr_w = CW * spec.proportions.shoulder_width / 2

    for acc_spec in spec.accessories:
        if acc_spec.slot == AccessorySlot.TECH_CABLE:
            _build_cables(mesh, acc_spec, cx, shldr_w, sil, colors)
        elif acc_spec.slot == AccessorySlot.GLYPH:
            _build_glyphs(mesh, acc_spec, cx, shldr_w, sil, colors)
        elif acc_spec.slot == AccessorySlot.HORN:
            _build_horns(mesh, acc_spec, cx, sil, colors)


def _build_cables(mesh, acc_spec, cx, shldr_w, sil, colors):
    gs = colors.grayscale
    cable_y_start = sil.center_bottom[1] - 2
    cable_y_end = CH * 0.82
    cable_w = 4 * acc_spec.size

    sides = []
    if acc_spec.side in (AccessorySide.LEFT, AccessorySide.BOTH):
        sides.append(('l', -1))
    if acc_spec.side in (AccessorySide.RIGHT, AccessorySide.BOTH):
        sides.append(('r', 1))

    for side_name, sign in sides:
        group = f'shoulder_{side_name}'
        base_x = cx + sign * (shldr_w - 18)

        mesh.add_facet(f'cable_{side_name}_1',
                       [(base_x, cable_y_start), (base_x + cable_w, cable_y_start),
                        (base_x + cable_w + 2, cable_y_end), (base_x + 2, cable_y_end)],
                       gs.get('mid2', '#4a5058'), group, 15)

        mesh.add_facet(f'cable_{side_name}_2',
                       [(base_x + 12, cable_y_start + 2),
                        (base_x + 12 + cable_w, cable_y_start + 2),
                        (base_x + 12 + cable_w + 2, cable_y_end + 2),
                        (base_x + 14, cable_y_end + 2)],
                       gs.get('mid1', '#3a4048'), group, 15)


def _build_glyphs(mesh, acc_spec, cx, shldr_w, sil, colors):
    acc_dim = colors.accent_dim
    glyph_y_start = sil.center_bottom[1]
    glyph_spacing = 18

    sides = []
    if acc_spec.side in (AccessorySide.LEFT, AccessorySide.BOTH):
        sides.append(('l', -1))
    if acc_spec.side in (AccessorySide.RIGHT, AccessorySide.BOTH):
        sides.append(('r', 1))

    for side_name, sign in sides:
        base_x = cx + sign * (shldr_w - 24)
        for i in range(3):
            gy = glyph_y_start + i * glyph_spacing
            gx = base_x + (i % 2) * 6 * sign
            mesh.add_glow(f'glyph_{side_name}_{i}', (gx, gy),
                           2.5 * acc_spec.size, acc_dim, group='accent')


def _build_horns(mesh, acc_spec, cx, sil, colors):
    gs = colors.grayscale
    px, py = sil.peak
    horn_h = 30 * acc_spec.size
    horn_w = 12 * acc_spec.size

    sides = []
    if acc_spec.side in (AccessorySide.LEFT, AccessorySide.BOTH):
        sides.append(('l', -1))
    if acc_spec.side in (AccessorySide.RIGHT, AccessorySide.BOTH):
        sides.append(('r', 1))

    for side_name, sign in sides:
        base_x = px + sign * 25
        tip_x = base_x + sign * horn_w
        tip_y = py - horn_h

        mesh.add_facet(f'horn_{side_name}',
                       [(base_x - 5, py + 5), (base_x + 5, py + 5), (tip_x, tip_y)],
                       gs.get('mid2' if sign > 0 else 'dark3', '#4a5058'), 'hood', 15)
        mesh.add_facet(f'horn_{side_name}_hi',
                       [(base_x + sign * 2, py + 5), (base_x + sign * 4, py + 2),
                        (tip_x, tip_y)],
                       gs.get('light1' if sign > 0 else 'mid1', '#687078'), 'hood', 15)
