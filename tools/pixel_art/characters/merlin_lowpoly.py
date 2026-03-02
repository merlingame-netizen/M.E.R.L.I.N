"""M.E.R.L.I.N. — Low-poly isometric flat-shaded character.

Reference: Two ChatGPT-generated images (1024x1024) showing a dark hooded
figure with faceted 3D geometry, near-monochrome dark palette, and amber
glowing eyes + tech glyphs.

Canvas: 256x256 (downscaled to 128x128 for Godot).
Facets: ~38 polygons + 6 glow dots.
Animation: 12 frames — breathing (sin) + sway (cos) + glow pulse.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.low_poly_mesh import LowPolyMesh
from pixel_art.forge_simple import forge


# ============================================================
# PALETTE — extracted from reference images
# ============================================================
P = {
    'void':       '#000000',   # face void, deep shadows
    'deep':       '#0a0a12',   # near-black bluish
    'dark1':      '#151520',   # very dark gray
    'dark2':      '#222230',   # dark charcoal
    'dark3':      '#2a3038',   # charcoal — hood shadow side
    'mid1':       '#3a4048',   # medium-dark — armor
    'mid2':       '#4a5058',   # medium — lit armor faces
    'mid3':       '#586068',   # medium-light
    'light1':     '#687078',   # gray — hood reflections
    'light2':     '#8a9098',   # light gray — highlights
    'bright':     '#a8b0b8',   # bright edge highlights
    'amber':      '#FFFC68',   # eye + glyph accent
    'amber_dim':  '#BBA830',   # dimmed accent
    'amber_halo': '#FFFC6838', # semi-transparent halo
}


def build_merlin(accent='amber'):
    """Build the M.E.R.L.I.N. low-poly mesh — v11 angular faceted hood.

    KEY: Hood built as TILED ANGULAR FACETS (like a 3D mesh), not smooth
    overlapping strips. Each facet = distinct flat color = visible edges.
    This recreates the reference's flat-shaded faceted 3D look.

    Facet layout per hood half:
      - Upper outer: steep slope from peak to mid-bell
      - Lower outer: flatter slope from mid-bell to bottom
      - Inner: faces toward center/viewer
      - Drape: bottom fabric fold

    Args:
        accent: 'amber' for yellow eyes or 'cyan' for teal eyes.
    """
    m = LowPolyMesh(256, 256)

    acc = P['amber']
    acc_dim = P['amber_dim']
    acc_halo = P['amber_halo']
    if accent == 'cyan':
        acc = '#1DFDFF'
        acc_dim = '#0EA0A8'
        acc_halo = '#1DFDFF38'

    # =============================================================
    # LAYER 0-2: BODY CORE (group='body')
    # =============================================================

    m.add_facet('body_fill',
                [(16, 140), (240, 140), (236, 244), (20, 244)],
                P['void'], 'body', 0)
    m.add_facet('chest_upper',
                [(82, 140), (174, 140), (170, 180), (86, 180)],
                P['deep'], 'body', 1)
    m.add_facet('chest_lower',
                [(86, 180), (170, 180), (164, 236), (92, 236)],
                P['dark1'], 'body', 1)
    m.add_facet('chest_seam',
                [(127, 142), (129, 142), (129, 236), (127, 236)],
                P['dark2'], 'body', 2)

    # =============================================================
    # LAYER 3-5: SHOULDERS (group='shoulder_l/r')
    # =============================================================

    # Left (shadow)
    m.add_facet('shldr_l_side',
                [(10, 136), (18, 150), (24, 220), (12, 216)],
                P['dark2'], 'shoulder_l', 3)
    m.add_facet('shldr_l_top',
                [(10, 136), (98, 128), (102, 144), (18, 150)],
                P['mid1'], 'shoulder_l', 4)
    m.add_facet('shldr_l_front',
                [(18, 150), (102, 144), (106, 220), (24, 220)],
                P['dark3'], 'shoulder_l', 3)
    m.add_facet('shldr_l_bevel',
                [(18, 140), (94, 132), (98, 142), (22, 146)],
                P['mid2'], 'shoulder_l', 5)
    m.add_facet('shldr_l_bottom',
                [(12, 216), (24, 220), (106, 220), (102, 228), (16, 228)],
                P['dark1'], 'shoulder_l', 2)

    # Right (lit)
    m.add_facet('shldr_r_side',
                [(246, 136), (238, 150), (232, 220), (244, 216)],
                P['mid2'], 'shoulder_r', 3)
    m.add_facet('shldr_r_top',
                [(246, 136), (158, 128), (154, 144), (238, 150)],
                P['mid3'], 'shoulder_r', 4)
    m.add_facet('shldr_r_front',
                [(238, 150), (154, 144), (150, 220), (232, 220)],
                P['mid1'], 'shoulder_r', 3)
    m.add_facet('shldr_r_bevel',
                [(238, 140), (162, 132), (158, 142), (234, 146)],
                P['light1'], 'shoulder_r', 5)
    m.add_facet('shldr_r_bottom',
                [(244, 216), (232, 220), (150, 220), (154, 228), (240, 228)],
                P['dark2'], 'shoulder_r', 2)

    # =============================================================
    # LAYER 6-8: HOOD — TILED ANGULAR FACETS (group='hood')
    #
    # Silhouette bell curve (left outer edge):
    #   Peak:     (128, 44)
    #   Flank:    (76, 62)
    #   Mid-bell: (42, 104)
    #   Shoulder: (30, 152)
    #   Bottom:   (40, 190)
    #   Drape-in: (98, 170)
    #   Center:   (128, 158)
    #
    # Interior shared vertices (edges between facets):
    #   Upper-L: (98, 70)    Upper-R: (158, 70)
    #   Mid-L:   (76, 118)   Mid-R:   (180, 118)
    #   Lower-L: (82, 158)   Lower-R: (174, 158)
    #
    # Each facet = unique color based on face angle vs light
    # Light source: upper-right
    # =============================================================

    # --- LEFT SIDE: 4 tiled facets ---

    # L1: upper outer — steep slope facing LEFT (away from light)
    m.add_facet('hood_l1',
                [(128, 44), (76, 62), (42, 104), (76, 118), (98, 70)],
                P['dark3'], 'hood', 6)

    # L2: lower outer — flatter slope facing DOWN-LEFT
    m.add_facet('hood_l2',
                [(76, 118), (42, 104), (30, 152), (40, 190), (82, 158)],
                P['dark2'], 'hood', 6)

    # L3: inner — faces CENTER/VIEWER, recessed (darker than outer)
    m.add_facet('hood_l3',
                [(128, 44), (98, 70), (76, 118), (82, 158), (128, 158)],
                P['dark2'], 'hood', 7)

    # L4: lower inner/drape — deep shadow at bottom
    m.add_facet('hood_l4',
                [(82, 158), (40, 190), (98, 170), (128, 158)],
                P['dark1'], 'hood', 6)

    # --- RIGHT SIDE: 4 tiled facets ---

    # R1: upper outer — steep slope facing RIGHT (towards light)
    m.add_facet('hood_r1',
                [(128, 44), (180, 62), (214, 104), (180, 118), (158, 70)],
                P['mid2'], 'hood', 6)

    # R2: lower outer — flatter, still catches light
    m.add_facet('hood_r2',
                [(180, 118), (214, 104), (226, 152), (216, 190), (174, 158)],
                P['mid1'], 'hood', 6)

    # R3: inner — faces center, slightly lit (not as bright as outer)
    m.add_facet('hood_r3',
                [(128, 44), (158, 70), (180, 118), (174, 158), (128, 158)],
                P['mid1'], 'hood', 7)

    # R4: lower inner/drape
    m.add_facet('hood_r4',
                [(174, 158), (216, 190), (158, 170), (128, 158)],
                P['dark3'], 'hood', 6)

    # --- Peak details (z=9) ---

    # Right slope highlight — bright edge facing light
    m.add_facet('hood_peak_hi',
                [(128, 44), (140, 50), (180, 62), (172, 60)],
                P['light1'], 'hood', 9)
    # Left slope shadow — dark edge away from light
    m.add_facet('hood_peak_sh',
                [(128, 44), (116, 50), (76, 62), (84, 60)],
                P['dark1'], 'hood', 9)
    # Center ridge — subtle cap matching hood surface
    m.add_facet('hood_peak_cap',
                [(116, 50), (140, 50), (138, 58), (118, 58)],
                P['mid1'], 'hood', 9)

    # Centerline ridge — subtle strip from peak toward face
    m.add_facet('hood_centerline',
                [(126, 48), (130, 48), (130, 86), (126, 86)],
                P['mid3'], 'hood', 9)

    # Right upper highlight — BRIGHT facet where light hits directly
    m.add_facet('hood_r_highlight',
                [(158, 70), (180, 62), (192, 88), (170, 92)],
                P['bright'], 'hood', 8)
    # Secondary accent below highlight
    m.add_facet('hood_r_accent',
                [(170, 92), (192, 88), (202, 110), (184, 112)],
                P['light2'], 'hood', 8)

    # Left subtle highlight — even shadow side catches some light
    m.add_facet('hood_l_highlight',
                [(98, 70), (76, 62), (64, 88), (86, 92)],
                P['mid1'], 'hood', 8)

    # --- Hood drape extensions ---
    m.add_facet('hood_drape_l',
                [(40, 190), (98, 170), (102, 200), (46, 198)],
                P['dark1'], 'hood', 6)
    m.add_facet('hood_drape_r',
                [(216, 190), (158, 170), (154, 200), (210, 198)],
                P['dark2'], 'hood', 6)

    # =============================================================
    # LAYER 10-11: FACE VOID (group='face')
    # =============================================================

    m.add_facet('face_main',
                [(110, 88), (146, 88), (156, 148), (100, 148)],
                P['void'], 'face', 10)
    m.add_facet('face_depth_l',
                [(100, 88), (110, 88), (100, 148)],
                P['deep'], 'face', 10)
    m.add_facet('face_depth_r',
                [(146, 88), (156, 88), (156, 148)],
                P['deep'], 'face', 10)
    m.add_facet('face_chin',
                [(100, 142), (156, 142), (156, 148), (100, 148)],
                P['dark1'], 'face', 11)

    # =============================================================
    # LAYER 13: FACE FRAME — subtle rim highlights
    # Left rim catches light, right rim barely visible.
    # =============================================================

    # Visor edge — angled frame like the reference
    # Top edge: bright but thin (2px)
    m.add_facet('frame_top',
                [(108, 86), (148, 86), (146, 89), (110, 89)],
                P['light2'], 'hood', 13)
    # Right edge: catches light
    m.add_facet('frame_r',
                [(156, 86), (158, 150), (155, 148), (153, 88)],
                P['light2'], 'hood', 13)
    # Left edge: in shadow, muted
    m.add_facet('frame_l',
                [(98, 86), (100, 150), (103, 148), (101, 88)],
                P['mid2'], 'hood', 13)

    # =============================================================
    # LAYER 14: GLOWING EYES
    # =============================================================

    m.add_glow('eye_halo_l', (118, 112), 4, acc,
               halo_radius=22, halo_color=acc_halo, group='eyes')
    m.add_glow('eye_halo_r', (138, 112), 4, acc,
               halo_radius=22, halo_color=acc_halo, group='eyes')

    m.add_facet('eye_slit_l',
                [(106, 112), (118, 106), (128, 112), (118, 118)],
                acc, 'eyes', 14)
    m.add_facet('eye_slit_r',
                [(128, 112), (138, 106), (150, 112), (138, 118)],
                acc, 'eyes', 14)

    # =============================================================
    # LAYER 15: TECH DETAILS
    # =============================================================

    m.add_facet('cable_l1',
                [(26, 158), (30, 158), (32, 208), (28, 208)],
                P['mid2'], 'shoulder_l', 15)
    m.add_facet('cable_l2',
                [(38, 160), (42, 160), (44, 210), (40, 210)],
                P['mid1'], 'shoulder_l', 15)
    m.add_facet('cable_r1',
                [(226, 158), (230, 158), (228, 208), (224, 208)],
                P['mid3'], 'shoulder_r', 15)
    m.add_facet('cable_r2',
                [(214, 160), (218, 160), (216, 210), (212, 210)],
                P['mid2'], 'shoulder_r', 15)

    m.add_glow('glyph_l1', (46, 156), 2, acc_dim, group='accent')
    m.add_glow('glyph_l2', (52, 178), 2, acc_dim, group='accent')
    m.add_glow('glyph_l3', (40, 196), 2, acc_dim, group='accent')
    m.add_glow('glyph_r1', (210, 156), 2, acc_dim, group='accent')
    m.add_glow('glyph_r2', (204, 178), 2, acc_dim, group='accent')
    m.add_glow('glyph_r3', (216, 196), 2, acc_dim, group='accent')

    return m


def animate_merlin(mesh, frame_count=12):
    """Generate 12 animation frames with breathing + sway + glow pulse.

    Curves:
      - breath: sin wave, 2px amplitude (vertical bob)
      - sway: cos wave, 1px amplitude (horizontal head tilt)
      - glow: not yet vertex-based (TODO: modulate glow radius per frame)
    """
    frames = []
    for i in range(frame_count):
        t = i / frame_count
        angle = t * 2 * math.pi

        breath_dy = math.sin(angle) * 2.0
        sway_dx = math.cos(angle) * 1.0

        displacements = {
            'hood':       (sway_dx,       breath_dy * 0.5),
            'face':       (sway_dx * 0.8, breath_dy * 0.6),
            'eyes':       (sway_dx * 0.8, breath_dy * 0.6),
            'shoulder_l': (-0.3,          breath_dy * 0.3),
            'shoulder_r': (0.3,           breath_dy * 0.3),
            'body':       (0,             breath_dy * 0.2),
            'accent':     (0,             breath_dy * 0.3),
        }

        frames.append(mesh.render_scaled(128, displacements))

    return frames


if __name__ == '__main__':
    # Generate amber variant (default)
    mesh = build_merlin(accent='amber')
    frames = animate_merlin(mesh, frame_count=12)
    forge(name="merlin", frames=frames, fps=6, scale_gif=4)

    # Generate cyan variant
    mesh_cyan = build_merlin(accent='cyan')
    frames_cyan = animate_merlin(mesh_cyan, frame_count=12)
    forge(name="merlin_cyan", frames=frames_cyan, fps=6, scale_gif=4)
