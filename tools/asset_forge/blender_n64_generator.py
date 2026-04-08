"""
Blender BK Asset Generator for M.E.R.L.I.N. — v2 (Dense Forest Edition)
True Banjo-Kazooie art style: ultra-low-poly, vertex-painted, Gouraud-shaded.

Based on BK_N64_ASSET_BIBLE.md research:
- Trees: 40-60 tris (not 400)
- Rocks: 12-40 tris (not 200)
- Bushes/ferns/grass: 4-20 tris (cross-billboards + simple 3D)
- Creatures: 120-200 tris (not 600)
- Total visible scene: 3,000-5,000 tris

Run headless:
    blender --background --python blender_n64_generator.py -- --category vegetation --biome foret_broceliande --count 6
"""

import bpy
import bmesh
import math
import random
import sys
import os
import json
from mathutils import Vector, Matrix, noise


# ─── CLI ────────────────────────────────────────────────────────────────────────

def parse_args() -> dict:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    args = {
        "category": "vegetation",
        "biome": "foret_broceliande",
        "count": 3,
        "output_dir": "",
        "seed": 42,
    }

    i = 0
    while i < len(argv):
        key = argv[i]
        if key in ("--category", "--biome", "--output", "--count", "--seed", "--batch") and i + 1 < len(argv):
            val = argv[i + 1]
            if key == "--category":
                args["category"] = val
            elif key == "--biome":
                args["biome"] = val
            elif key == "--output":
                args["output_dir"] = val
            elif key in ("--count", "--batch"):
                args["count"] = int(val)
            elif key == "--seed":
                args["seed"] = int(val)
            i += 2
        else:
            i += 1

    return args


# ─── BK Forest Palette (from BK_N64_ASSET_BIBLE.md Section 4) ────────────────

BK_PALETTE = {
    # Canopy & Grass
    "canopy_bright":  (0.40, 0.62, 0.25),
    "canopy_shadow":  (0.18, 0.35, 0.12),
    "grass_sun":      (0.42, 0.58, 0.22),
    "grass_shade":    (0.22, 0.38, 0.14),
    # Wood & Earth
    "bark_light":     (0.52, 0.36, 0.22),
    "bark_dark":      (0.22, 0.15, 0.08),
    "bark_root":      (0.35, 0.24, 0.14),
    "path_center":    (0.58, 0.42, 0.26),
    "path_edge":      (0.48, 0.38, 0.22),
    # Stone
    "stone_sun":      (0.55, 0.52, 0.48),
    "stone_shade":    (0.32, 0.30, 0.28),
    "stone_moss":     (0.28, 0.40, 0.18),
    "stone_lichen":   (0.50, 0.52, 0.40),
    # Moss & Low Vegetation
    "moss_dark":      (0.15, 0.30, 0.10),
    "moss_light":     (0.30, 0.45, 0.18),
    "fern_green":     (0.25, 0.50, 0.18),
    # Atmosphere
    "sky_zenith":     (0.28, 0.52, 0.85),
    "sky_horizon":    (0.70, 0.82, 0.68),
    "fog_forest":     (0.45, 0.55, 0.35),
    "water_surface":  (0.15, 0.30, 0.42),
    # Accents
    "gold_collect":   (0.90, 0.78, 0.25),
    "magic_blue":     (0.30, 0.65, 1.00),
    "cream_highlight":(0.94, 0.91, 0.82),
    "shadow_deep":    (0.12, 0.10, 0.08),
    "mushroom_cap":   (0.72, 0.22, 0.15),
    "mushroom_stem":  (0.85, 0.82, 0.72),
    # Legacy compat
    "kazooie_red":    (0.808, 0.255, 0.153),
    "banjo_brown":    (0.616, 0.404, 0.286),
    "foliage_sage":   (0.376, 0.514, 0.427),
    "druid_purple":   (0.353, 0.188, 0.502),
}

# Biome color overrides
BIOME_TINTS = {
    "foret_broceliande":  {"crown": "canopy_bright",  "trunk": "bark_dark",    "rock": "stone_sun",   "accent": "moss_light", "ground": "grass_sun"},
    "landes_bruyere":     {"crown": "foliage_sage",   "trunk": "banjo_brown",  "rock": "stone_sun",   "accent": "druid_purple", "ground": "grass_shade"},
    "cotes_sauvages":     {"crown": "foliage_sage",   "trunk": "banjo_brown",  "rock": "stone_shade", "accent": "sky_zenith", "ground": "grass_shade"},
    "villages_celtes":    {"crown": "canopy_bright",  "trunk": "banjo_brown",  "rock": "stone_sun",   "accent": "gold_collect", "ground": "grass_sun"},
    "cercles_pierres":    {"crown": "moss_light",     "trunk": "bark_dark",    "rock": "stone_shade", "accent": "magic_blue", "ground": "moss_dark"},
    "marais_korrigans":   {"crown": "moss_dark",      "trunk": "bark_dark",    "rock": "stone_shade", "accent": "moss_light", "ground": "moss_dark"},
    "collines_dolmens":   {"crown": "foliage_sage",   "trunk": "banjo_brown",  "rock": "stone_sun",   "accent": "gold_collect", "ground": "grass_sun"},
    "iles_mystiques":     {"crown": "foliage_sage",   "trunk": "banjo_brown",  "rock": "stone_sun",   "accent": "magic_blue", "ground": "grass_sun"},
}


def biome_color(biome: str, role: str) -> tuple:
    tints = BIOME_TINTS.get(biome, BIOME_TINTS["foret_broceliande"])
    key = tints.get(role, "banjo_brown")
    return BK_PALETTE.get(key, (0.5, 0.5, 0.5))


def lerp_color(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


def jitter_color(rgb: tuple, amount: float = 0.04) -> tuple:
    return tuple(max(0.0, min(1.0, c + random.uniform(-amount, amount))) for c in rgb)


# ─── Scene Helpers ──────────────────────────────────────────────────────────────

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
        for item in block:
            if item.users == 0:
                block.remove(item)


def count_tris(obj) -> int:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    tri_count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    eval_obj.to_mesh_clear()
    return tri_count


def enforce_budget(obj, max_tris: int):
    tris = count_tris(obj)
    if tris > max_tris and tris > 0:
        ratio = max(0.1, max_tris / tris)
        mod = obj.modifiers.new(name="BudgetDecimate", type='DECIMATE')
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)


def displace_verts(obj, strength: float = 0.05, seed_offset: int = 0):
    for i, v in enumerate(obj.data.vertices):
        n = noise.noise(v.co * 3.0 + Vector((seed_offset, 0, 0)))
        v.co += v.co.normalized() * n * strength


def set_smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True


def join_into(target, *others):
    bpy.ops.object.select_all(action='DESELECT')
    for o in others:
        o.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return bpy.context.active_object


def flatten_bottom(obj, y_min: float = 0.0):
    """Flatten vertices below y_min (BK assets sit flat on ground)."""
    for v in obj.data.vertices:
        if v.co.z < y_min:
            v.co.z = y_min


# ─── BK Material (zero specular, vertex colors only) ───────────────────────────

def create_bk_material(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    bsdf.inputs['Metallic'].default_value = 0.0
    for spec_name in ('Specular IOR Level', 'Specular'):
        if spec_name in bsdf.inputs:
            bsdf.inputs[spec_name].default_value = 0.0
            break
    links.new(bsdf.outputs[0], output.inputs[0])

    vcol = nodes.new('ShaderNodeVertexColor')
    vcol.layer_name = "Col"
    links.new(vcol.outputs[0], bsdf.inputs['Base Color'])

    return mat


def apply_material(obj, mat_name: str):
    mat = create_bk_material(mat_name)
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ─── BK Vertex Painting Pipeline ─────────────────────────────────────────────

# Sun direction for baked directional lighting (upper-left, consistent across all assets)
SUN_DIR = Vector((-0.7, -0.3, 0.65)).normalized()

def bk_vertex_paint(obj, base_color: tuple, top_color: tuple = None,
                    ao_strength: float = 0.3, moss_color: tuple = None,
                    moss_threshold: float = -1.0, sun_strength: float = 0.15):
    """BK-style vertex painting: height gradient + AO + directional sun + moss + jitter."""
    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    if not verts:
        return

    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    range_z = max(max_z - min_z, 0.001)

    top_col = top_color or lerp_color(base_color, BK_PALETTE["cream_highlight"], 0.2)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = (vert.co.z - min_z) / range_z  # 0=bottom, 1=top

            # Height gradient
            r, g, b = lerp_color(base_color, top_col, t * 0.4)

            # Brightness from height (BK: darker bottom, lighter top)
            brightness = 0.72 + 0.28 * t
            r *= brightness; g *= brightness; b *= brightness

            # AO at base (quadratic falloff)
            ao = 1.0 - ao_strength * (1.0 - t) ** 2
            r *= ao; g *= ao; b *= ao

            # Directional sun (faces toward sun = brighter + warm tint)
            sun_dot = max(0.0, poly.normal.x * SUN_DIR.x + poly.normal.y * SUN_DIR.y + poly.normal.z * SUN_DIR.z)
            sun_factor = 1.0 + sun_dot * sun_strength
            warm = sun_dot * 0.03  # Warm tint in sunlit areas
            r = r * sun_factor + warm
            g = g * sun_factor + warm * 0.6
            b = b * sun_factor - warm * 0.3  # Cooler blue on shadow side

            # Up-facing shading (simulates sky ambient)
            up_dot = max(poly.normal.z, 0.0)
            shade = 0.75 + 0.25 * up_dot
            r *= shade; g *= shade; b *= shade

            # Moss on upward-facing surfaces
            if moss_color and moss_threshold > 0.0 and poly.normal.z > moss_threshold:
                moss_blend = (poly.normal.z - moss_threshold) / (1.0 - moss_threshold) * 0.6
                mr, mg, mb = moss_color
                r = r * (1.0 - moss_blend) + mr * moss_blend
                g = g * (1.0 - moss_blend) + mg * moss_blend
                b = b * (1.0 - moss_blend) + mb * moss_blend

            # Per-vertex jitter (hand-painted feel)
            r += random.uniform(-0.03, 0.03)
            g += random.uniform(-0.03, 0.03)
            b += random.uniform(-0.03, 0.03)

            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)),
                max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)),
                1.0,
            )


def paint_zones(obj, zones: list, fallback_color: tuple = None):
    """Paint vertices by spatial zones. First matching zone wins."""
    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    min_z = min(v.z for v in verts) if verts else 0
    max_z = max(v.z for v in verts) if verts else 1
    range_z = max(max_z - min_z, 0.001)

    fb = fallback_color or BK_PALETTE["banjo_brown"]

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            co = vert.co
            normal = poly.normal
            t = (co.z - min_z) / range_z

            matched = False
            for zone in zones:
                if zone["test"](co, normal):
                    r, g, b = zone["color"]
                    ao_str = zone.get("ao", 0.2)

                    brightness = 0.72 + 0.28 * t
                    r *= brightness; g *= brightness; b *= brightness
                    ao = 1.0 - ao_str * (1.0 - t) ** 2
                    r *= ao; g *= ao; b *= ao

                    sun_dot = max(0.0, normal.x * SUN_DIR.x + normal.y * SUN_DIR.y + normal.z * SUN_DIR.z)
                    r *= (1.0 + sun_dot * 0.12); g *= (1.0 + sun_dot * 0.10); b *= (1.0 + sun_dot * 0.06)

                    up_dot = max(normal.z, 0.0)
                    shade = 0.75 + 0.25 * up_dot
                    r *= shade; g *= shade; b *= shade

                    r += random.uniform(-0.03, 0.03)
                    g += random.uniform(-0.03, 0.03)
                    b += random.uniform(-0.03, 0.03)

                    color_layer.data[loop_idx].color = (
                        max(0.0, min(1.0, r)), max(0.0, min(1.0, g)),
                        max(0.0, min(1.0, b)), 1.0)
                    matched = True
                    break

            if not matched:
                r, g, b = jitter_color(fb, 0.04)
                ao = 1.0 - 0.3 * (1.0 - t) ** 2
                color_layer.data[loop_idx].color = (
                    max(0.0, min(1.0, r * ao)), max(0.0, min(1.0, g * ao)),
                    max(0.0, min(1.0, b * ao)), 1.0)


# ─── Export ─────────────────────────────────────────────────────────────────────

def apply_real_world_scale(obj, gen_name: str):
    target_factor = REAL_WORLD_SCALES.get(gen_name, 1.0)
    if target_factor == 1.0:
        return
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in bbox)
    max_z = max(v.z for v in bbox)
    current_h = max(max_z - min_z, 0.001)
    scale = target_factor / current_h
    obj.scale *= scale
    bpy.ops.object.transform_apply(scale=True)


def export_glb(obj, filepath: str, gen_name: str = ""):
    if gen_name:
        apply_real_world_scale(obj, gen_name)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_normals=True,
        export_apply=True,
    )


# ═════════════════════════════════════════════════════════════════════════════════
# GENERATORS — True BK poly budgets. Each returns a single vertex-painted object.
# ═════════════════════════════════════════════════════════════════════════════════


# ─── TREES (40-60 tris) ──────────────────────────────────────────────────────

def gen_tree_bk(biome: str, variant: int = 0):
    """BK tree: 4 sub-types. 40-60 tris total.
    v%4=0: Broad oak — wide squashed crown, thick trunk
    v%4=1: Pine — cone crown, thin trunk
    v%4=2: Willow — drooping lobes below crown center
    v%4=3: Birch — slim, oval crown
    """
    tree_type = variant % 4

    # Trunk — 6-sided cylinder (BK trees use 6-8 sides)
    if tree_type == 0:  # Oak
        trunk_h, trunk_r = random.uniform(1.4, 2.0), random.uniform(0.18, 0.26)
        crown_r = random.uniform(1.0, 1.4)
        crown_squash = random.uniform(0.45, 0.6)
    elif tree_type == 1:  # Pine
        trunk_h, trunk_r = random.uniform(1.8, 2.8), random.uniform(0.08, 0.14)
        crown_r = random.uniform(0.55, 0.85)
        crown_squash = 1.2  # Taller than wide
    elif tree_type == 2:  # Willow
        trunk_h, trunk_r = random.uniform(1.0, 1.6), random.uniform(0.10, 0.16)
        crown_r = random.uniform(0.8, 1.2)
        crown_squash = random.uniform(0.5, 0.65)
    else:  # Birch
        trunk_h, trunk_r = random.uniform(1.6, 2.4), random.uniform(0.06, 0.10)
        crown_r = random.uniform(0.5, 0.75)
        crown_squash = random.uniform(0.7, 0.9)

    # Trunk — 6-sided (minimal for BK)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, depth=trunk_h, radius=trunk_r,
        location=(0, 0, trunk_h / 2), end_fill_type='NGON')
    trunk = bpy.context.active_object
    trunk.name = f"tree_bk_{variant:03d}"

    # Flare base roots (BK characteristic)
    for v in trunk.data.vertices:
        t = v.co.z / trunk_h
        if t < 0.25:
            flare = 1.0 + (1.0 - t / 0.25) * 0.45
            v.co.x *= flare
            v.co.y *= flare

    # Bark noise
    displace_verts(trunk, strength=trunk_r * 0.06, seed_offset=variant + 100)

    # Crown — low-poly icosphere (subdiv 1 = 20 tris, subdiv 2 = 80)
    crown_z = trunk_h * random.uniform(0.82, 0.95)

    if tree_type == 1:  # Pine: cone
        bpy.ops.mesh.primitive_cone_add(
            vertices=8, radius1=crown_r, radius2=crown_r * 0.08,
            depth=crown_r * 2.0, location=(0, 0, crown_z + crown_r * 0.5))
        crown = bpy.context.active_object
    else:  # Sphere-based crowns
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=crown_r,
            location=(random.uniform(-0.06, 0.06), random.uniform(-0.06, 0.06), crown_z))
        crown = bpy.context.active_object
        crown.scale.z = crown_squash
        bpy.ops.object.transform_apply(scale=True)

    # Willow drooping lobes
    if tree_type == 2:
        for i in range(3):
            lr = crown_r * random.uniform(0.3, 0.45)
            angle = random.uniform(0, math.pi * 2)
            lx = math.cos(angle) * crown_r * 0.5
            ly = math.sin(angle) * crown_r * 0.5
            lz = crown_z - crown_r * random.uniform(0.2, 0.5)
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=lr, location=(lx, ly, lz))
            lobe = bpy.context.active_object
            lobe.scale.z = random.uniform(0.8, 1.4)
            bpy.ops.object.transform_apply(scale=True)
            displace_verts(lobe, strength=lr * 0.08, seed_offset=variant + i * 17)
            crown = join_into(crown, lobe)

    # Crown displacement for organic shape
    displace_verts(crown, strength=crown_r * 0.08, seed_offset=variant)

    # Flatten crown bottom
    for v in crown.data.vertices:
        if v.co.z < crown_z - crown_r * 0.3:
            v.co.z = crown_z - crown_r * 0.3

    obj = join_into(trunk, crown)
    set_smooth(obj)
    enforce_budget(obj, 60)

    # Vertex paint: trunk dark bark, crown green gradient
    trunk_col = BK_PALETTE["bark_dark"]
    crown_col = biome_color(biome, "crown")
    crown_bot = BK_PALETTE["canopy_shadow"]

    trunk_top_z = trunk_h * 0.7

    # Paint trunk zone
    paint_zones(obj, [{
        "test": lambda co, n, tt=trunk_top_z, tr=trunk_r: co.z < tt and (co.x**2 + co.y**2) < (tr * 2.5)**2,
        "color": trunk_col, "ao": 0.4,
    }], fallback_color=crown_col)

    # Enhance crown: gradient from shadow at bottom to bright at top
    mesh = obj.data
    color_layer = mesh.vertex_colors["Col"]
    crown_min_z = crown_z - crown_r * 0.5
    crown_max_z = crown_z + crown_r * 0.6
    crown_range = max(crown_max_z - crown_min_z, 0.001)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            co = vert.co
            if co.z >= trunk_top_z or (co.x**2 + co.y**2) > (trunk_r * 2.5)**2:
                ct = max(0.0, min(1.0, (co.z - crown_min_z) / crown_range))
                r, g, b = lerp_color(crown_bot, crown_col, ct)

                # Sun side brighter
                sun_dot = max(0.0, poly.normal.x * SUN_DIR.x + poly.normal.y * SUN_DIR.y + poly.normal.z * SUN_DIR.z)
                r *= (1.0 + sun_dot * 0.15)
                g *= (1.0 + sun_dot * 0.12)

                up_dot = max(poly.normal.z, 0.0)
                shade = 0.7 + 0.3 * up_dot
                r *= shade; g *= shade; b *= shade

                r += random.uniform(-0.03, 0.03)
                g += random.uniform(-0.03, 0.03)
                b += random.uniform(-0.03, 0.03)
                color_layer.data[loop_idx].color = (
                    max(0.0, min(1.0, r)), max(0.0, min(1.0, g)),
                    max(0.0, min(1.0, b)), 1.0)

    apply_material(obj, f"mat_tree_bk_{biome}")
    return obj


# ─── BUSHES (12-20 tris 3D, or 4 tris cross-billboard) ──────────────────────

def gen_bush_bk(biome: str, variant: int = 0):
    """BK bush: 3 sub-types. 12-20 tris.
    v%3=0: Round bush (3 squashed spheres merged)
    v%3=1: Tall shrub (2 stretched spheres)
    v%3=2: Low ground cover (single very squashed sphere)
    """
    bush_type = variant % 3

    parts = []
    if bush_type == 0:  # Round bush — 3 overlapping spheres
        for i in range(3):
            angle = i * math.pi * 2 / 3
            ox = math.cos(angle) * 0.15
            oy = math.sin(angle) * 0.15
            r = random.uniform(0.25, 0.40)
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(ox, oy, r * 0.5))
            s = bpy.context.active_object
            s.scale.z = random.uniform(0.5, 0.7)
            bpy.ops.object.transform_apply(scale=True)
            parts.append(s)
    elif bush_type == 1:  # Tall shrub
        for i in range(2):
            r = random.uniform(0.20, 0.32)
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(random.uniform(-0.1, 0.1), 0, r * (0.5 + i * 0.6)))
            s = bpy.context.active_object
            s.scale = (random.uniform(0.8, 1.1), random.uniform(0.8, 1.1), random.uniform(0.8, 1.2))
            bpy.ops.object.transform_apply(scale=True)
            parts.append(s)
    else:  # Ground cover
        r = random.uniform(0.35, 0.55)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(0, 0, r * 0.25))
        s = bpy.context.active_object
        s.scale.z = 0.35
        bpy.ops.object.transform_apply(scale=True)
        parts.append(s)

    obj = parts[0]
    obj.name = f"bush_bk_{variant:03d}"
    if len(parts) > 1:
        obj = join_into(obj, *parts[1:])

    displace_verts(obj, strength=0.06, seed_offset=variant)
    flatten_bottom(obj)
    set_smooth(obj)
    enforce_budget(obj, 24)

    crown_col = biome_color(biome, "crown")
    bk_vertex_paint(obj, base_color=BK_PALETTE["canopy_shadow"], top_color=crown_col,
                    ao_strength=0.35, moss_color=BK_PALETTE["moss_light"], moss_threshold=0.5)
    apply_material(obj, f"mat_bush_bk_{biome}")
    return obj


# ─── GROUND COVER: ferns, grass tufts, flowers (4-8 tris cross-billboards) ──

def gen_groundcover_bk(biome: str, variant: int = 0):
    """BK ground cover: cross-billboard technique (2 quads at 90°). 4-8 tris.
    v%4=0: Grass tuft
    v%4=1: Fern frond
    v%4=2: Flower
    v%4=3: Tall grass
    """
    cover_type = variant % 4

    if cover_type == 0:  # Grass tuft
        w, h = random.uniform(0.3, 0.5), random.uniform(0.25, 0.40)
        color = BK_PALETTE["grass_sun"]
        tip_color = lerp_color(color, BK_PALETTE["grass_shade"], 0.3)
    elif cover_type == 1:  # Fern
        w, h = random.uniform(0.4, 0.6), random.uniform(0.3, 0.5)
        color = BK_PALETTE["fern_green"]
        tip_color = BK_PALETTE["canopy_shadow"]
    elif cover_type == 2:  # Flower
        w, h = random.uniform(0.15, 0.25), random.uniform(0.2, 0.35)
        color = BK_PALETTE["kazooie_red"] if variant % 2 == 0 else BK_PALETTE["gold_collect"]
        tip_color = BK_PALETTE["cream_highlight"]
    else:  # Tall grass
        w, h = random.uniform(0.2, 0.3), random.uniform(0.5, 0.8)
        color = BK_PALETTE["grass_sun"]
        tip_color = lerp_color(BK_PALETTE["grass_sun"], BK_PALETTE["cream_highlight"], 0.15)

    parts = []
    for angle_deg in [0, 90]:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, h / 2))
        quad = bpy.context.active_object
        quad.scale = (w, 1.0, h)
        quad.rotation_euler.z = math.radians(angle_deg)
        quad.rotation_euler.x = math.pi / 2  # Stand upright
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        parts.append(quad)

    obj = parts[0]
    obj.name = f"groundcover_bk_{variant:03d}"
    if len(parts) > 1:
        obj = join_into(obj, *parts[1:])

    # Vertex paint: green gradient bottom→tip
    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    min_z = min(v.z for v in verts) if verts else 0
    max_z = max(v.z for v in verts) if verts else 1
    rng_z = max(max_z - min_z, 0.001)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = (vert.co.z - min_z) / rng_z
            r, g, b = lerp_color(color, tip_color, t)
            # AO at base
            ao = 0.6 + 0.4 * t
            r *= ao; g *= ao; b *= ao
            r += random.uniform(-0.03, 0.03)
            g += random.uniform(-0.03, 0.03)
            b += random.uniform(-0.03, 0.03)
            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)), max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)), 1.0)

    apply_material(obj, f"mat_groundcover_bk_{biome}")
    return obj


# ─── MUSHROOMS (12-16 tris) ─────────────────────────────────────────────────

def gen_mushroom_bk(biome: str, variant: int = 0):
    """BK mushroom: oversized, cartoon proportions. 12-16 tris.
    v%3=0: Red cap with spots (classic BK)
    v%3=1: Brown cluster (small group)
    v%3=2: Tall skinny (whimsical)
    """
    mush_type = variant % 3

    if mush_type == 0:  # Classic red toadstool
        stem_h = random.uniform(0.15, 0.25)
        stem_r = random.uniform(0.04, 0.07)
        cap_r = random.uniform(0.15, 0.25)
        cap_col = BK_PALETTE["mushroom_cap"]
    elif mush_type == 1:  # Brown cluster
        stem_h = random.uniform(0.08, 0.15)
        stem_r = random.uniform(0.03, 0.05)
        cap_r = random.uniform(0.08, 0.14)
        cap_col = BK_PALETTE["bark_light"]
    else:  # Tall whimsical
        stem_h = random.uniform(0.25, 0.40)
        stem_r = random.uniform(0.03, 0.05)
        cap_r = random.uniform(0.10, 0.18)
        cap_col = lerp_color(BK_PALETTE["mushroom_cap"], BK_PALETTE["druid_purple"], 0.5)

    # Stem — 6-sided
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=stem_r, depth=stem_h,
        location=(0, 0, stem_h / 2), end_fill_type='NGON')
    stem = bpy.context.active_object
    stem.name = f"mushroom_bk_{variant:03d}"

    # Cap — hemisphere (half icosphere)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=cap_r, location=(0, 0, stem_h))
    cap = bpy.context.active_object
    cap.scale.z = 0.5
    bpy.ops.object.transform_apply(scale=True)
    # Remove bottom half
    for v in cap.data.vertices:
        if v.co.z < stem_h - cap_r * 0.1:
            v.co.z = stem_h - cap_r * 0.1

    # For cluster type, add 1-2 smaller mushrooms
    extras = []
    if mush_type == 1:
        for i in range(random.randint(1, 2)):
            angle = random.uniform(0, math.pi * 2)
            ox = math.cos(angle) * 0.08
            oy = math.sin(angle) * 0.08
            sh = stem_h * random.uniform(0.5, 0.8)
            sr = stem_r * 0.8
            cr = cap_r * random.uniform(0.6, 0.9)
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=sr, depth=sh, location=(ox, oy, sh / 2))
            s2 = bpy.context.active_object
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=cr, location=(ox, oy, sh))
            c2 = bpy.context.active_object
            c2.scale.z = 0.5
            bpy.ops.object.transform_apply(scale=True)
            extras.extend([s2, c2])

    obj = join_into(stem, cap, *extras) if extras else join_into(stem, cap)
    flatten_bottom(obj)
    set_smooth(obj)
    enforce_budget(obj, 20)

    # Vertex paint: stem cream, cap colored
    stem_col = BK_PALETTE["mushroom_stem"]
    zones = [
        {"test": lambda co, n, sh=stem_h: co.z > sh * 0.7, "color": cap_col, "ao": 0.15},
    ]
    paint_zones(obj, zones, fallback_color=stem_col)

    apply_material(obj, f"mat_mushroom_bk_{biome}")
    return obj


# ─── STUMPS & DEAD WOOD (16-40 tris) ────────────────────────────────────────

def gen_deadwood_bk(biome: str, variant: int = 0):
    """BK dead wood: 3 sub-types. 16-40 tris.
    v%3=0: Short stump (cut tree)
    v%3=1: Tall broken stump (snapped mid-trunk)
    v%3=2: Fallen log (horizontal)
    """
    wood_type = variant % 3

    if wood_type == 0:  # Short stump
        h = random.uniform(0.2, 0.4)
        r = random.uniform(0.15, 0.30)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(0, 0, h / 2))
        obj = bpy.context.active_object
        obj.name = f"deadwood_bk_{variant:03d}"
        # Irregular top
        for v in obj.data.vertices:
            if v.co.z > h * 0.8:
                v.co.z += random.uniform(-0.04, 0.04)
        # Root flare
        for v in obj.data.vertices:
            t = v.co.z / h
            if t < 0.3:
                flare = 1.0 + (1.0 - t / 0.3) * 0.35
                v.co.x *= flare; v.co.y *= flare

    elif wood_type == 1:  # Tall broken stump
        h = random.uniform(0.5, 0.9)
        r = random.uniform(0.12, 0.22)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(0, 0, h / 2))
        obj = bpy.context.active_object
        obj.name = f"deadwood_bk_{variant:03d}"
        # Jagged break at top
        for v in obj.data.vertices:
            if v.co.z > h * 0.65:
                dist = math.sqrt(v.co.x**2 + v.co.y**2)
                angle = math.atan2(v.co.y, v.co.x)
                jagged = math.sin(angle * 3 + variant) * 0.08
                v.co.z += jagged
                if dist > r * 0.5:
                    v.co.z -= random.uniform(0, 0.06)

    else:  # Fallen log
        length = random.uniform(1.2, 2.0)
        r = random.uniform(0.10, 0.18)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=r, depth=length,
            location=(0, 0, r), rotation=(0, math.pi / 2, random.uniform(-0.15, 0.15)))
        obj = bpy.context.active_object
        obj.name = f"deadwood_bk_{variant:03d}"
        bpy.ops.object.transform_apply(rotation=True)

    displace_verts(obj, strength=0.03, seed_offset=variant)
    flatten_bottom(obj)
    set_smooth(obj)
    enforce_budget(obj, 40)

    bk_vertex_paint(obj, base_color=BK_PALETTE["bark_root"],
                    top_color=BK_PALETTE["bark_light"], ao_strength=0.35,
                    moss_color=BK_PALETTE["moss_dark"], moss_threshold=0.5)
    apply_material(obj, f"mat_deadwood_bk_{biome}")
    return obj


# ─── ROCKS (12-40 tris) ─────────────────────────────────────────────────────

def gen_rock_bk(biome: str, variant: int = 0):
    """BK rock: 3 sub-types. 12-40 tris.
    v%3=0: Small pebble (ico subdiv 1)
    v%3=1: Medium boulder (ico subdiv 2 with bumps)
    v%3=2: Rock cluster (3 small rocks merged)
    """
    rock_type = variant % 3

    if rock_type == 0:  # Small pebble
        r = random.uniform(0.2, 0.4)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(0, 0, r * 0.35))
        obj = bpy.context.active_object
        obj.scale = (random.uniform(0.8, 1.3), random.uniform(0.8, 1.2), random.uniform(0.4, 0.7))
        bpy.ops.object.transform_apply(scale=True)

    elif rock_type == 1:  # Medium boulder
        r = random.uniform(0.35, 0.55)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(0, 0, r * 0.4))
        obj = bpy.context.active_object
        obj.scale = (random.uniform(0.8, 1.3), random.uniform(0.8, 1.2), random.uniform(0.5, 0.75))
        bpy.ops.object.transform_apply(scale=True)
        # Secondary bump
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r * 0.4,
            location=(random.uniform(-r*0.3, r*0.3), random.uniform(-r*0.3, r*0.3), r * 0.2))
        bump = bpy.context.active_object
        obj = join_into(obj, bump)

    else:  # Rock cluster
        parts = []
        for i in range(3):
            ri = random.uniform(0.15, 0.30)
            angle = i * math.pi * 2 / 3 + random.uniform(-0.5, 0.5)
            ox = math.cos(angle) * 0.15
            oy = math.sin(angle) * 0.15
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=ri, location=(ox, oy, ri * 0.35))
            s = bpy.context.active_object
            s.scale.z = random.uniform(0.4, 0.7)
            bpy.ops.object.transform_apply(scale=True)
            parts.append(s)
        obj = parts[0]
        obj = join_into(obj, *parts[1:])

    obj.name = f"rock_bk_{variant:03d}"
    displace_verts(obj, strength=0.05, seed_offset=variant)
    flatten_bottom(obj)
    set_smooth(obj)
    enforce_budget(obj, 40)

    bk_vertex_paint(obj, base_color=BK_PALETTE["stone_sun"], ao_strength=0.35,
                    moss_color=BK_PALETTE["stone_moss"], moss_threshold=0.55)
    apply_material(obj, f"mat_rock_bk_{biome}")
    return obj


# ─── MEGALITHS (24-60 tris) ─────────────────────────────────────────────────

def gen_megalith_bk(biome: str, variant: int = 0):
    """BK megalith: 2 sub-types. 24-60 tris.
    v%2=0: Menhir (tall tapered stone)
    v%2=1: Dolmen (3 uprights + capstone)
    """
    mega_type = variant % 2

    if mega_type == 0:  # Menhir
        h = random.uniform(1.6, 2.8)
        r = random.uniform(0.18, 0.35)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(0, 0, h / 2))
        obj = bpy.context.active_object
        obj.name = f"megalith_bk_{variant:03d}"

        # Subdivide once for vertex paint resolution
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.subdivide(number_cuts=2)
        bpy.ops.object.mode_set(mode='OBJECT')

        # Taper top, widen base
        for v in obj.data.vertices:
            t = v.co.z / h
            dist = math.sqrt(v.co.x**2 + v.co.y**2)
            if dist > 0.01:
                taper = 1.0 - t * 0.3 + (1.0 - t) * 0.08
                v.co.x *= taper; v.co.y *= taper

            # Weathering noise
            n1 = noise.noise(v.co * 2.5 + Vector((variant * 7.3, 0, 0)))
            v.co.x += n1 * r * 0.15
            v.co.y += n1 * r * 0.15

        # Round top cap
        for v in obj.data.vertices:
            if v.co.z > h * 0.85:
                dist = math.sqrt(v.co.x**2 + v.co.y**2)
                t_cap = (v.co.z - h * 0.85) / (h * 0.15)
                v.co.z -= t_cap * 0.1 * max(dist, 0.01) / (r * 0.7)

    else:  # Dolmen
        # 3 upright stones + flat capstone
        parts = []
        cap_w = random.uniform(1.0, 1.6)
        cap_d = random.uniform(0.6, 1.0)
        stone_h = random.uniform(0.8, 1.2)

        for i, (px, py) in enumerate([(-cap_w * 0.35, -cap_d * 0.3), (cap_w * 0.35, -cap_d * 0.3), (0, cap_d * 0.3)]):
            sr = random.uniform(0.12, 0.18)
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=sr, depth=stone_h, location=(px, py, stone_h / 2))
            pillar = bpy.context.active_object
            pillar.rotation_euler = (random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), 0)
            bpy.ops.object.transform_apply(rotation=True)
            displace_verts(pillar, strength=sr * 0.12, seed_offset=variant + i)
            parts.append(pillar)

        # Capstone — flat box
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, stone_h + 0.08))
        cap = bpy.context.active_object
        cap.scale = (cap_w / 2, cap_d / 2, 0.08)
        bpy.ops.object.transform_apply(scale=True)
        displace_verts(cap, strength=0.03, seed_offset=variant + 10)
        parts.append(cap)

        obj = parts[0]
        obj.name = f"megalith_bk_{variant:03d}"
        obj = join_into(obj, *parts[1:])

    set_smooth(obj)
    enforce_budget(obj, 60)

    # Vertex paint: stone + moss gradient
    stone = BK_PALETTE["stone_sun"]
    moss = BK_PALETTE["stone_moss"]
    cream = BK_PALETTE["cream_highlight"]
    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    rng = max(max_z - min_z, 0.001)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = (vert.co.z - min_z) / rng
            if t < 0.3:
                r, g, b = lerp_color(stone, moss, t / 0.3)
            elif t < 0.7:
                r, g, b = lerp_color(moss, stone, (t - 0.3) / 0.4)
            else:
                r, g, b = lerp_color(stone, cream, (t - 0.7) / 0.3)

            ao = 1.0 - 0.35 * (1.0 - t) ** 2
            r *= ao; g *= ao; b *= ao

            sun_dot = max(0.0, poly.normal.x * SUN_DIR.x + poly.normal.y * SUN_DIR.y + poly.normal.z * SUN_DIR.z)
            r *= (1.0 + sun_dot * 0.12); g *= (1.0 + sun_dot * 0.08)

            r += random.uniform(-0.03, 0.03)
            g += random.uniform(-0.03, 0.03)
            b += random.uniform(-0.03, 0.03)

            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)), max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)), 1.0)

    apply_material(obj, f"mat_megalith_bk_{biome}")
    return obj


# ─── STRUCTURES (80-150 tris) ────────────────────────────────────────────────

def gen_structure_bk(biome: str, variant: int = 0):
    """BK structure: 3 sub-types. 80-150 tris.
    v%3=0: Round hut (Mumbo's Hut style)
    v%3=1: Long house
    v%3=2: Stone shrine/altar
    """
    struct_type = variant % 3

    if struct_type == 0:  # Round hut
        wall_h = random.uniform(0.8, 1.2)
        wall_r = random.uniform(0.6, 0.9)
        roof_h = random.uniform(0.5, 0.8)
        lean = random.uniform(-0.03, 0.03)

        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=wall_r, depth=wall_h, location=(lean, 0, wall_h / 2))
        walls = bpy.context.active_object
        walls.name = f"structure_bk_{variant:03d}"

        # Wall irregularity
        for v in walls.data.vertices:
            n = noise.noise(v.co * 4.0 + Vector((variant * 5.1, 0, 0)))
            v.co.x += n * 0.015; v.co.y += n * 0.015

        # Roof cone
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=wall_r * 1.15, radius2=0.04,
            depth=roof_h, location=(lean, 0, wall_h + roof_h / 2))
        roof = bpy.context.active_object

        # Chimney
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.05, depth=0.2,
            location=(lean + wall_r * 0.3, 0, wall_h + roof_h * 0.6))
        chimney = bpy.context.active_object

        # Door — dark rectangle placeholder (vertex painted)
        obj = join_into(walls, roof, chimney)

    elif struct_type == 1:  # Long house
        w = random.uniform(1.0, 1.4)
        d = random.uniform(0.6, 0.8)
        h = random.uniform(0.7, 1.0)
        roof_h = random.uniform(0.4, 0.6)

        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, h / 2))
        walls = bpy.context.active_object
        walls.name = f"structure_bk_{variant:03d}"
        walls.scale = (w / 2, d / 2, h / 2)
        bpy.ops.object.transform_apply(scale=True)

        # A-frame roof
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=max(w, d) * 0.6, radius2=0.02,
            depth=roof_h, location=(0, 0, h + roof_h / 2))
        roof = bpy.context.active_object
        roof.scale.y = d / w if w > 0 else 1.0
        bpy.ops.object.transform_apply(scale=True)

        obj = join_into(walls, roof)

    else:  # Stone shrine
        base_w = random.uniform(0.8, 1.2)
        base_d = random.uniform(0.6, 0.8)
        base_h = random.uniform(0.15, 0.25)

        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, base_h / 2))
        base = bpy.context.active_object
        base.name = f"structure_bk_{variant:03d}"
        base.scale = (base_w / 2, base_d / 2, base_h / 2)
        bpy.ops.object.transform_apply(scale=True)

        # Altar stone on top
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.25, location=(0, 0, base_h + 0.15))
        altar = bpy.context.active_object
        altar.scale = (1.5, 1.0, 0.5)
        bpy.ops.object.transform_apply(scale=True)

        # Side pillars
        pillars = []
        for sx in [-1, 1]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.06, depth=0.5,
                location=(sx * base_w * 0.4, 0, 0.25))
            p = bpy.context.active_object
            pillars.append(p)

        obj = join_into(base, altar, *pillars)

    displace_verts(obj, strength=0.02, seed_offset=variant)
    set_smooth(obj)
    enforce_budget(obj, 150)

    # Vertex paint
    wall_col = BK_PALETTE["banjo_brown"] if struct_type != 2 else BK_PALETTE["stone_sun"]
    roof_col = BK_PALETTE["bark_dark"]

    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    rng_z = max(max_z - min_z, 0.001)
    mid_z = min_z + rng_z * 0.6

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = (vert.co.z - min_z) / rng_z
            if vert.co.z > mid_z:
                r, g, b = roof_col
            else:
                r, g, b = wall_col

            ao = 1.0 - 0.3 * (1.0 - t) ** 2
            r *= ao; g *= ao; b *= ao

            sun_dot = max(0.0, poly.normal.x * SUN_DIR.x + poly.normal.y * SUN_DIR.y + poly.normal.z * SUN_DIR.z)
            r *= (1.0 + sun_dot * 0.12); g *= (1.0 + sun_dot * 0.10)

            r += random.uniform(-0.03, 0.03)
            g += random.uniform(-0.03, 0.03)
            b += random.uniform(-0.03, 0.03)
            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)), max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)), 1.0)

    apply_material(obj, f"mat_structure_bk_{biome}")
    return obj


# ─── COLLECTIBLES (10-30 tris) ──────────────────────────────────────────────

def gen_collectible_bk(biome: str, variant: int = 0):
    """BK collectible: 3 sub-types. 10-30 tris.
    v%3=0: Star (jiggy-like)
    v%3=1: Ring (torus)
    v%3=2: Musical note
    """
    kind = variant % 3

    if kind == 0:  # Star
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.12, location=(0, 0, 0.18))
        obj = bpy.context.active_object
        for v in obj.data.vertices:
            co = v.co - Vector((0, 0, 0.18))
            if co.length > 0.01:
                norm = co.normalized()
                max_align = max(abs(norm.x), abs(norm.y), abs(norm.z))
                if max_align > 0.7:
                    v.co = Vector((0, 0, 0.18)) + co * (1.0 + (max_align - 0.7) * 2.0)

    elif kind == 1:  # Ring
        bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.035,
            major_segments=12, minor_segments=6, location=(0, 0, 0.15))
        obj = bpy.context.active_object

    else:  # Musical note
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.07, location=(0, 0, 0.28))
        head = bpy.context.active_object
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.012, depth=0.2, location=(0.05, 0, 0.16))
        stem = bpy.context.active_object
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.05, 0, 0.28))
        flag = bpy.context.active_object
        flag.scale = (0.004, 0.04, 0.03)
        bpy.ops.object.transform_apply(scale=True)
        obj = join_into(head, stem, flag)

    obj.name = f"collectible_bk_{variant:03d}"
    set_smooth(obj)
    enforce_budget(obj, 30)

    # Bright gold vertex paint
    bk_vertex_paint(obj, base_color=BK_PALETTE["gold_collect"],
                    top_color=BK_PALETTE["cream_highlight"], ao_strength=0.1, sun_strength=0.2)
    apply_material(obj, f"mat_collectible_bk_{biome}")
    return obj


# ─── CREATURES (120-200 tris) ────────────────────────────────────────────────

def gen_creature_bk(biome: str, variant: int = 0):
    """BK creature: 3 sub-types. 120-200 tris.
    v%3=0: Korrigan (squat goblin, big head)
    v%3=1: Doe (slender, long legs)
    v%3=2: Wolf (long body, pointy ears)
    """
    creature_type = variant % 3

    if creature_type == 0:  # Korrigan
        total_h = random.uniform(0.45, 0.60)
        body_r = total_h * 0.25
        head_r = total_h * 0.22
        body_col = BK_PALETTE["moss_light"]
    elif creature_type == 1:  # Doe
        total_h = random.uniform(0.65, 0.85)
        body_r = total_h * 0.14
        head_r = total_h * 0.10
        body_col = BK_PALETTE["banjo_brown"]
    else:  # Wolf
        total_h = random.uniform(0.50, 0.65)
        body_r = total_h * 0.18
        head_r = total_h * 0.14
        body_col = lerp_color(BK_PALETTE["stone_sun"], BK_PALETTE["bark_root"], 0.4)

    belly_col = lerp_color(body_col, BK_PALETTE["cream_highlight"], 0.35)
    limb_r = body_r * 0.25
    limb_len = total_h * 0.25

    # Body — ico subdiv 2
    body_z = total_h * 0.35
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=body_r, location=(0, 0, body_z))
    body = bpy.context.active_object
    body.name = f"creature_bk_{variant:03d}"
    if creature_type == 0:
        body.scale = (1.1, 1.0, 0.85)
    elif creature_type == 1:
        body.scale = (0.8, 1.3, 1.0)
    else:
        body.scale = (0.85, 1.4, 0.75)
    bpy.ops.object.transform_apply(scale=True)

    # Head — ico subdiv 2, BK oversized
    head_z = total_h * 0.70
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=head_r, location=(0, 0, head_z))
    head = bpy.context.active_object

    # Snout
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=head_r * 0.28,
        location=(0, -head_r * 0.85, head_z - head_r * 0.1))
    snout = bpy.context.active_object

    # Ears — cones
    ear_parts = []
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=head_r * 0.18, radius2=0.01,
            depth=head_r * 0.4, location=(side * head_r * 0.55, 0, head_z + head_r * 0.6))
        ear = bpy.context.active_object
        ear.rotation_euler.y = side * 0.3
        bpy.ops.object.transform_apply(rotation=True)
        ear_parts.append(ear)

    # Eyes — BK googly eyes (ico subdiv 1)
    eye_parts = []
    eye_r = head_r * 0.35
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=eye_r,
            location=(side * head_r * 0.4, -head_r * 0.6, head_z + head_r * 0.15))
        eye = bpy.context.active_object
        eye_parts.append(eye)

    # Legs — simple cylinders
    limb_parts = []
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=limb_r * 1.2, depth=limb_len,
            location=(side * body_r * 0.5, 0, body_z - body_r - 0.02))
        leg = bpy.context.active_object
        limb_parts.append(leg)
        # Foot
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=limb_r * 1.6,
            location=(side * body_r * 0.5, -limb_r * 0.2, limb_r * 1.2))
        foot = bpy.context.active_object
        foot.scale = (1.0, 1.3, 0.45)
        bpy.ops.object.transform_apply(scale=True)
        limb_parts.append(foot)

    # Arms (smaller)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=limb_r, depth=limb_len * 0.7,
            location=(side * (body_r + limb_r), 0, body_z + body_r * 0.1),
            rotation=(0, side * 0.4, 0))
        arm = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        limb_parts.append(arm)

    # Tail
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=body_r * 0.25, radius2=0.01,
        depth=body_r * 1.0, location=(0, body_r * 0.7, body_z - body_r * 0.2),
        rotation=(math.radians(-55), 0, 0))
    tail = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)

    obj = join_into(body, head, snout, tail, *ear_parts, *eye_parts, *limb_parts)
    set_smooth(obj)
    enforce_budget(obj, 200)

    # Vertex paint by zone
    zones = [
        # Eyes white
        {"test": lambda co, n, hz=head_z, hr=head_r, er=eye_r:
            co.z > hz - hr * 0.5 and co.y < -hr * 0.3 and
            any(math.sqrt((co.x - s * hr * 0.4)**2 + (co.z - hz - hr * 0.15)**2) < er * 1.8 for s in [-1, 1]),
         "color": BK_PALETTE["cream_highlight"], "ao": 0.05},
        # Head
        {"test": lambda co, n, hz=head_z, hr=head_r:
            co.z > hz - hr * 1.0 and math.sqrt(co.x**2 + co.y**2) < hr * 1.8,
         "color": lerp_color(body_col, BK_PALETTE["cream_highlight"], 0.12), "ao": 0.2},
        # Belly
        {"test": lambda co, n, bz=body_z, br=body_r: n.z < -0.3 and co.z < bz + br,
         "color": belly_col, "ao": 0.2},
        # Feet
        {"test": lambda co, n, lr=limb_r: co.z < lr * 2.5,
         "color": lerp_color(body_col, BK_PALETTE["shadow_deep"], 0.25), "ao": 0.3},
    ]
    paint_zones(obj, zones, fallback_color=body_col)

    apply_material(obj, f"mat_creature_bk_{biome}")
    return obj


# ─── PROPS (bridges, fences, signs, torches, wells) ─────────────────────────

def gen_bridge_bk(biome: str, variant: int = 0):
    """BK bridge: planks with gaps, sagging rails. 60-80 tris."""
    length = random.uniform(2.0, 3.0)
    width = random.uniform(0.5, 0.65)
    plank_count = random.randint(8, 12)
    post_h = random.uniform(0.30, 0.45)

    parts = []
    plank_spacing = length / plank_count

    for i in range(plank_count):
        if random.random() < 0.1:
            continue
        px = -length / 2 + plank_spacing * (i + 0.5) + random.uniform(-0.015, 0.015)
        pw = plank_spacing * random.uniform(0.72, 0.88)
        ph = random.uniform(0.025, 0.045)
        sag = -0.03 * math.sin(math.pi * (i + 0.5) / plank_count)

        bpy.ops.mesh.primitive_cube_add(size=1, location=(px, 0, sag))
        plank = bpy.context.active_object
        plank.scale = (pw / 2, width / 2, ph / 2)
        bpy.ops.object.transform_apply(scale=True)
        plank.rotation_euler.z = random.uniform(-0.03, 0.03)
        bpy.ops.object.transform_apply(rotation=True)
        parts.append(plank)

    # Posts — 4 corners
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.028, depth=post_h,
                location=(sx * length / 2 * 0.88, sy * width / 2, post_h / 2))
            post = bpy.context.active_object
            post.rotation_euler.x = sy * random.uniform(0.03, 0.08)
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(post)

    # Side beams
    for sy in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.02, depth=length * 0.9,
            location=(0, sy * width / 2 * 0.9, -0.015), rotation=(0, math.pi / 2, 0))
        beam = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        parts.append(beam)

    first = parts[0]
    first.name = f"bridge_bk_{variant:03d}"
    obj = join_into(first, *parts[1:]) if len(parts) > 1 else first

    set_smooth(obj)
    enforce_budget(obj, 80)

    paint_zones(obj, [
        {"test": lambda co, n, ph=post_h: co.z > ph * 0.5 and (abs(co.x) > 0.7 or abs(co.y) > 0.2),
         "color": BK_PALETTE["bark_dark"], "ao": 0.2},
        {"test": lambda co, n: n.z < -0.5, "color": BK_PALETTE["shadow_deep"], "ao": 0.4},
    ], fallback_color=BK_PALETTE["bark_light"])

    apply_material(obj, f"mat_bridge_bk_{biome}")
    return obj


def gen_prop_bk(biome: str, variant: int = 0):
    """BK props: 4 sub-types. 8-50 tris.
    v%4=0: Fence section
    v%4=1: Signpost
    v%4=2: Torch stand
    v%4=3: Stone well
    """
    prop_type = variant % 4

    if prop_type == 0:  # Fence section
        parts = []
        fence_w = random.uniform(1.2, 1.8)
        fence_h = random.uniform(0.4, 0.6)
        post_r = 0.03

        # 3 posts
        for i in range(3):
            px = -fence_w / 2 + i * fence_w / 2
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=post_r, depth=fence_h,
                location=(px, 0, fence_h / 2))
            p = bpy.context.active_object
            p.rotation_euler = (random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), 0)
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(p)

        # 2 horizontal rails
        for rz in [fence_h * 0.35, fence_h * 0.75]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.02, depth=fence_w * 0.9,
                location=(0, 0, rz), rotation=(0, math.pi / 2, 0))
            rail = bpy.context.active_object
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(rail)

        obj = parts[0]
        obj.name = f"prop_bk_{variant:03d}"
        obj = join_into(obj, *parts[1:])

    elif prop_type == 1:  # Signpost
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.03, depth=0.7, location=(0, 0, 0.35))
        post = bpy.context.active_object
        post.name = f"prop_bk_{variant:03d}"

        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.15, 0, 0.55))
        sign = bpy.context.active_object
        sign.scale = (0.2, 0.01, 0.1)
        bpy.ops.object.transform_apply(scale=True)

        obj = join_into(post, sign)

    elif prop_type == 2:  # Torch stand
        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.025, depth=0.6, location=(0, 0, 0.3))
        post = bpy.context.active_object
        post.name = f"prop_bk_{variant:03d}"

        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.06, location=(0, 0, 0.65))
        bowl = bpy.context.active_object
        bowl.scale.z = 0.6
        bpy.ops.object.transform_apply(scale=True)

        obj = join_into(post, bowl)

    else:  # Stone well
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.35, depth=0.4, location=(0, 0, 0.2))
        ring = bpy.context.active_object
        ring.name = f"prop_bk_{variant:03d}"

        # Hollow inside (smaller cylinder to suggest depth)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.25, depth=0.15, location=(0, 0, 0.35))
        inner = bpy.context.active_object

        # Roof posts + cross beam
        for sx in [-1, 1]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.025, depth=0.5,
                location=(sx * 0.3, 0, 0.55))
            p = bpy.context.active_object
            inner = join_into(inner, p) if sx == 1 else inner
            if sx == -1:
                inner = join_into(inner, p)

        bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.02, depth=0.55,
            location=(0, 0, 0.8), rotation=(0, math.pi / 2, 0))
        crossbeam = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)

        obj = join_into(ring, inner, crossbeam)

    flatten_bottom(obj)
    set_smooth(obj)
    enforce_budget(obj, 50)

    if prop_type == 3:
        bk_vertex_paint(obj, base_color=BK_PALETTE["stone_sun"], ao_strength=0.3,
                        moss_color=BK_PALETTE["stone_moss"], moss_threshold=0.4)
    else:
        bk_vertex_paint(obj, base_color=BK_PALETTE["bark_light"],
                        top_color=BK_PALETTE["bark_root"], ao_strength=0.35)

    apply_material(obj, f"mat_prop_bk_{biome}")
    return obj


# ═════════════════════════════════════════════════════════════════════════════════
# GENERATOR REGISTRY
# ═════════════════════════════════════════════════════════════════════════════════

GENERATORS = {
    "vegetation":   {"tree_bk": gen_tree_bk},
    "bushes":       {"bush_bk": gen_bush_bk},
    "groundcover":  {"groundcover_bk": gen_groundcover_bk},
    "mushrooms":    {"mushroom_bk": gen_mushroom_bk},
    "deadwood":     {"deadwood_bk": gen_deadwood_bk},
    "rocks":        {"rock_bk": gen_rock_bk},
    "structures":   {"structure_bk": gen_structure_bk},
    "megaliths":    {"megalith_bk": gen_megalith_bk},
    "collectibles": {"collectible_bk": gen_collectible_bk},
    "characters":   {"creature_bk": gen_creature_bk},
    "props":        {"bridge_bk": gen_bridge_bk, "prop_bk": gen_prop_bk},
}

CATEGORIES = list(GENERATORS.keys())

BIOMES = [
    "foret_broceliande", "landes_bruyere", "cotes_sauvages", "villages_celtes",
    "cercles_pierres", "marais_korrigans", "collines_dolmens", "iles_mystiques",
]

# Budget reference (from BK_N64_ASSET_BIBLE.md)
TRI_BUDGETS = {
    "tree_bk":        60,
    "bush_bk":        24,
    "groundcover_bk": 8,
    "mushroom_bk":    20,
    "deadwood_bk":    40,
    "rock_bk":        40,
    "structure_bk":   150,
    "megalith_bk":    60,
    "collectible_bk": 30,
    "creature_bk":    200,
    "bridge_bk":      80,
    "prop_bk":        50,
}

# Real-world scale (1 Blender unit = 1 meter)
REAL_WORLD_SCALES = {
    "tree_bk":        5.0,
    "bush_bk":        1.2,
    "groundcover_bk": 0.5,
    "mushroom_bk":    0.4,
    "deadwood_bk":    1.0,
    "rock_bk":        1.2,
    "structure_bk":   3.2,
    "megalith_bk":    3.0,
    "collectible_bk": 0.35,
    "creature_bk":    0.7,
    "bridge_bk":      1.2,
    "prop_bk":        1.0,
}


# ═════════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════════

def main():
    args = parse_args()
    category = args["category"]
    biome = args["biome"]
    count = args["count"]
    seed = args["seed"]

    random.seed(seed)

    if args["output_dir"]:
        output_base = args["output_dir"]
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(os.path.dirname(script_dir))
        output_base = os.path.join(project_root, "Assets", "bk_assets")

    output_dir = os.path.join(output_base, category, biome)
    os.makedirs(output_dir, exist_ok=True)

    generators = GENERATORS.get(category, {})
    if not generators:
        print(f"[ERROR] Unknown category: {category}")
        print(f"Available: {CATEGORIES}")
        return

    gen_names = list(generators.keys())
    results = []

    print(f"\n{'=' * 60}")
    print(f"BK Asset Generator v2 — M.E.R.L.I.N.")
    print(f"Category: {category} | Biome: {biome} | Count: {count}")
    print(f"Output: {output_dir}")
    print(f"{'=' * 60}\n")

    for i in range(count):
        gen_name = gen_names[i % len(gen_names)]
        gen_func = generators[gen_name]
        variant = (i // len(gen_names)) + seed

        clear_scene()
        random.seed(seed + i * 137)

        try:
            obj = gen_func(biome, variant)

            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')

            tris = count_tris(obj)
            budget = TRI_BUDGETS.get(gen_name, 100)
            filename = f"{gen_name}_{biome}_{i:04d}.glb"
            filepath = os.path.join(output_dir, filename)

            export_glb(obj, filepath, gen_name=gen_name)

            file_size = os.path.getsize(filepath) if os.path.exists(filepath) else 0
            status = "OK" if tris <= budget else f"OVER ({tris}/{budget})"
            print(f"  [{i+1}/{count}] {gen_name} v{variant}: {tris} tris [{status}], {round(file_size/1024,1)}KB")

            results.append({
                "name": filename, "category": category, "biome": biome,
                "generator": gen_name, "variant": variant, "tris": tris,
                "budget": budget, "sizeKb": round(file_size / 1024, 1),
            })

        except Exception as e:
            import traceback
            print(f"  [ERROR] {gen_name} v{variant}: {e}")
            traceback.print_exc()

    manifest_path = os.path.join(output_dir, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n=== Batch: {len(results)}/{count} assets generated ===")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
