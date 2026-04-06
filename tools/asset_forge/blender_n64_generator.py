"""
Blender BK Asset Generator for M.E.R.L.I.N.
Banjo-Kazooie art style: smooth shading, vertex-painted AO/gradients, proper poly budgets.

Run headless:
    blender --background --python blender_n64_generator.py -- --category vegetation --biome foret_broceliande --count 3

Reference: docs/70_graphic/BK_ART_STYLE_GUIDE.md
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


# ─── BK Palette (from BK_ART_STYLE_GUIDE.md Section 4) ────────────────────────

BK_PALETTE = {
    "kazooie_red":   (0.808, 0.255, 0.153),
    "sky_cyan":      (0.349, 0.749, 0.780),
    "banjo_brown":   (0.616, 0.404, 0.286),
    "foliage_sage":  (0.376, 0.514, 0.427),
    "shadow_brown":  (0.286, 0.235, 0.184),
    "gold_accent":   (0.910, 0.784, 0.251),
    "cream_light":   (0.941, 0.910, 0.816),
    "grass_green":   (0.353, 0.541, 0.227),
    "stone_gray":    (0.478, 0.478, 0.494),
    "water_blue":    (0.251, 0.565, 0.753),
    "moss_green":    (0.227, 0.416, 0.165),
    "bark_dark":     (0.227, 0.165, 0.102),
    "magic_glow":    (0.341, 0.722, 1.000),
    "druid_purple":  (0.353, 0.188, 0.502),
}

# Biome color overrides — each biome picks dominant colors from BK_PALETTE
BIOME_TINTS = {
    "foret_broceliande":  {"crown": "grass_green",  "trunk": "bark_dark",    "rock": "stone_gray",  "accent": "moss_green"},
    "landes_bruyere":     {"crown": "foliage_sage", "trunk": "banjo_brown",  "rock": "stone_gray",  "accent": "druid_purple"},
    "cotes_sauvages":     {"crown": "foliage_sage", "trunk": "banjo_brown",  "rock": "stone_gray",  "accent": "sky_cyan"},
    "villages_celtes":    {"crown": "grass_green",  "trunk": "banjo_brown",  "rock": "stone_gray",  "accent": "gold_accent"},
    "cercles_pierres":    {"crown": "moss_green",   "trunk": "bark_dark",    "rock": "stone_gray",  "accent": "magic_glow"},
    "marais_korrigans":   {"crown": "moss_green",   "trunk": "bark_dark",    "rock": "shadow_brown","accent": "moss_green"},
    "collines_dolmens":   {"crown": "foliage_sage", "trunk": "banjo_brown",  "rock": "stone_gray",  "accent": "gold_accent"},
    "iles_mystiques":     {"crown": "foliage_sage", "trunk": "banjo_brown",  "rock": "stone_gray",  "accent": "magic_glow"},
}


def biome_color(biome: str, role: str) -> tuple:
    """Get a palette color for a biome role, with fallback."""
    tints = BIOME_TINTS.get(biome, BIOME_TINTS["foret_broceliande"])
    key = tints.get(role, "banjo_brown")
    return BK_PALETTE.get(key, (0.5, 0.5, 0.5))


def lerp_color(a: tuple, b: tuple, t: float) -> tuple:
    """Linear interpolation between two RGB tuples."""
    t = max(0.0, min(1.0, t))
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


def jitter_color(rgb: tuple, amount: float = 0.04) -> tuple:
    """Add subtle random variation to a color."""
    return tuple(max(0.0, min(1.0, c + random.uniform(-amount, amount))) for c in rgb)


# ─── Scene Helpers ──────────────────────────────────────────────────────────────

def clear_scene():
    """Remove all objects and orphan data."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in [bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights]:
        for item in block:
            if item.users == 0:
                block.remove(item)


def count_tris(obj) -> int:
    """Count triangles after modifiers are applied."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    tri_count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    eval_obj.to_mesh_clear()
    return tri_count


def enforce_budget(obj, max_tris: int):
    """Decimate if over triangle budget."""
    tris = count_tris(obj)
    if tris > max_tris and tris > 0:
        ratio = max(0.1, max_tris / tris)
        mod = obj.modifiers.new(name="BudgetDecimate", type='DECIMATE')
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)


def displace_verts(obj, strength: float = 0.05, seed_offset: int = 0):
    """Apply noise displacement to all vertices for organic variation."""
    for i, v in enumerate(obj.data.vertices):
        n = noise.noise(v.co * 3.0 + Vector((seed_offset, 0, 0)))
        v.co += v.co.normalized() * n * strength


def set_smooth(obj):
    """Apply smooth shading (BK style = rounded, not faceted)."""
    for poly in obj.data.polygons:
        poly.use_smooth = True


def join_into(target, *others):
    """Join multiple objects into target."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in others:
        o.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return bpy.context.active_object


# ─── BK Material (zero specular, vertex colors only) ───────────────────────────

def create_bk_material(name: str) -> bpy.types.Material:
    """Create a fully matte material that reads vertex colors. Zero specular/metallic."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    bsdf.inputs['Metallic'].default_value = 0.0
    # Blender 4.x uses 'Specular IOR Level', older uses 'Specular'
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
    """Create BK material and assign to object."""
    mat = create_bk_material(mat_name)
    obj.data.materials.clear()
    obj.data.materials.append(mat)


# ─── BK Vertex Painting Pipeline (CRITICAL — 80% of visual quality) ────────────

def apply_bk_vertex_paint(obj, base_color: tuple, ao_strength: float = 0.3,
                          gradient_axis: str = 'Z', top_color: tuple = None,
                          moss_color: tuple = None, moss_threshold: float = -1.0):
    """
    Apply BK-style vertex painting with:
    - Height gradient (darker at bottom, lighter at top)
    - Baked ambient occlusion at base
    - Normal-based directional shading (up = brighter)
    - Optional moss on upward-facing surfaces
    - Subtle per-vertex jitter for hand-painted feel
    """
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

    top_col = top_color if top_color else lerp_color(base_color, BK_PALETTE["cream_light"], 0.25)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]

            # Height parameter [0..1]
            t = (vert.co.z - min_z) / range_z

            # Base color with height gradient
            r, g, b = lerp_color(base_color, top_col, t * 0.5)

            # Lighten top vertices slightly
            brightness = 0.75 + 0.25 * t
            r *= brightness
            g *= brightness
            b *= brightness

            # Ambient occlusion at bottom (quadratic falloff)
            ao = 1.0 - ao_strength * (1.0 - t) ** 2
            r *= ao
            g *= ao
            b *= ao

            # Normal-based directional shading (faces pointing up = brighter)
            up_dot = max(poly.normal.z, 0.0)
            shade = 0.7 + 0.3 * up_dot
            r *= shade
            g *= shade
            b *= shade

            # Optional moss on top-facing surfaces
            if moss_color and moss_threshold > 0.0 and poly.normal.z > moss_threshold:
                moss_blend = (poly.normal.z - moss_threshold) / (1.0 - moss_threshold)
                moss_blend *= 0.7  # Don't fully replace, blend
                mr, mg, mb = moss_color
                r = r * (1.0 - moss_blend) + mr * moss_blend
                g = g * (1.0 - moss_blend) + mg * moss_blend
                b = b * (1.0 - moss_blend) + mb * moss_blend

            # Per-vertex jitter for hand-painted feel
            jit = 0.03
            r += random.uniform(-jit, jit)
            g += random.uniform(-jit, jit)
            b += random.uniform(-jit, jit)

            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)),
                max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)),
                1.0,
            )


def paint_by_zone(obj, zones: list, fallback_color: tuple = None):
    """
    Paint vertices by spatial zones. Each zone is a dict:
        {"test": callable(vert_co, poly_normal) -> bool, "color": (r,g,b), "ao": float}
    First matching zone wins. Fallback for unmatched vertices.
    """
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

            # Find matching zone
            matched = False
            for zone in zones:
                if zone["test"](co, normal):
                    r, g, b = zone["color"]
                    ao_str = zone.get("ao", 0.2)

                    # Height gradient
                    brightness = 0.75 + 0.25 * t
                    r *= brightness
                    g *= brightness
                    b *= brightness

                    # AO at bottom
                    ao = 1.0 - ao_str * (1.0 - t) ** 2
                    r *= ao
                    g *= ao
                    b *= ao

                    # Directional shading
                    up_dot = max(normal.z, 0.0)
                    shade = 0.7 + 0.3 * up_dot
                    r *= shade
                    g *= shade
                    b *= shade

                    # Jitter
                    r += random.uniform(-0.03, 0.03)
                    g += random.uniform(-0.03, 0.03)
                    b += random.uniform(-0.03, 0.03)

                    color_layer.data[loop_idx].color = (
                        max(0.0, min(1.0, r)),
                        max(0.0, min(1.0, g)),
                        max(0.0, min(1.0, b)),
                        1.0,
                    )
                    matched = True
                    break

            if not matched:
                r, g, b = jitter_color(fb, 0.04)
                ao = 1.0 - 0.3 * (1.0 - t) ** 2
                color_layer.data[loop_idx].color = (
                    max(0.0, min(1.0, r * ao)),
                    max(0.0, min(1.0, g * ao)),
                    max(0.0, min(1.0, b * ao)),
                    1.0,
                )


# ─── Export ─────────────────────────────────────────────────────────────────────

def apply_real_world_scale(obj, gen_name: str):
    """Scale object to real-world dimensions based on REAL_WORLD_SCALES.
    Measures current bounding box height and rescales uniformly to match target."""
    target_factor = REAL_WORLD_SCALES.get(gen_name, 1.0)
    if target_factor == 1.0:
        return

    # Measure current bounding box height
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in bbox)
    max_z = max(v.z for v in bbox)
    current_h = max(max_z - min_z, 0.001)

    scale = target_factor / current_h
    obj.scale *= scale
    bpy.ops.object.transform_apply(scale=True)


def export_glb(obj, filepath: str, gen_name: str = ""):
    """Export single object as GLB with vertex colors preserved.
    If gen_name is provided, applies real-world scale before export."""
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
# GENERATORS — Each returns a single Blender object, vertex-painted and shaded.
# ═════════════════════════════════════════════════════════════════════════════════

# ─── tree_bk (~150 tris) ───────────────────────────────────────────────────────

def gen_tree_bk(biome: str, variant: int = 0):
    """BK tree: thick trunk with exposed roots + multi-lobe crown. ~400 tris."""
    trunk_h = random.uniform(1.4, 2.2)
    trunk_r = random.uniform(0.14, 0.22)
    crown_r = random.uniform(0.8, 1.2)

    # Trunk — 10-sided cylinder, more segments for detail
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10, depth=trunk_h, radius=trunk_r,
        location=(0, 0, trunk_h / 2),
        end_fill_type='NGON',
    )
    trunk = bpy.context.active_object
    trunk.name = f"tree_bk_{variant:03d}"

    # Subdivide for gradient resolution + organic shape
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=3)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Widen trunk base (BK characteristic flared roots)
    for v in trunk.data.vertices:
        t = v.co.z / trunk_h
        if t < 0.3:
            flare = 1.0 + (1.0 - t / 0.3) * 0.5
            v.co.x *= flare
            v.co.y *= flare

    # Add trunk noise for bark texture feel
    displace_verts(trunk, strength=trunk_r * 0.08, seed_offset=variant + 100)

    # Exposed root bulges at base
    root_parts = []
    for i in range(random.randint(3, 5)):
        angle = i * (math.pi * 2 / 5) + random.uniform(-0.3, 0.3)
        root_r = trunk_r * random.uniform(0.4, 0.6)
        root_len = random.uniform(0.2, 0.4)
        rx = math.cos(angle) * (trunk_r + root_r * 0.5)
        ry = math.sin(angle) * (trunk_r + root_r * 0.5)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=root_r,
            location=(rx, ry, root_r * 0.3),
        )
        root = bpy.context.active_object
        root.scale = (1.0 + root_len, 1.0, 0.5)
        root.rotation_euler.z = angle
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        root_parts.append(root)

    # Main crown — icosphere subdiv 3 for rounder BK shape
    crown_z = trunk_h * random.uniform(0.85, 1.0)
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=3, radius=crown_r,
        location=(random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), crown_z),
    )
    crown = bpy.context.active_object
    crown.scale.z = random.uniform(0.55, 0.75)
    bpy.ops.object.transform_apply(scale=True)

    # Secondary crown lobes (BK trees have lumpy, multi-lobe canopies)
    lobe_parts = []
    for i in range(random.randint(2, 4)):
        lobe_r = crown_r * random.uniform(0.35, 0.55)
        angle = random.uniform(0, math.pi * 2)
        offset = crown_r * random.uniform(0.4, 0.7)
        lx = math.cos(angle) * offset
        ly = math.sin(angle) * offset
        lz = crown_z + random.uniform(-crown_r * 0.2, crown_r * 0.3)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=lobe_r,
            location=(lx, ly, lz),
        )
        lobe = bpy.context.active_object
        lobe.scale.z = random.uniform(0.6, 0.85)
        bpy.ops.object.transform_apply(scale=True)
        displace_verts(lobe, strength=lobe_r * 0.1, seed_offset=variant + i * 17)
        lobe_parts.append(lobe)

    # Organic displacement on main crown
    displace_verts(crown, strength=crown_r * 0.1, seed_offset=variant)

    # Flatten bottom of crown
    for v in crown.data.vertices:
        if v.co.z < crown_z - crown_r * 0.3:
            v.co.z = crown_z - crown_r * 0.3

    obj = join_into(trunk, crown, *root_parts, *lobe_parts)
    set_smooth(obj)
    enforce_budget(obj, 400)

    # Vertex paint: trunk vs crown with AO
    trunk_top = trunk_h * 0.7
    trunk_col = BK_PALETTE["bark_dark"]
    trunk_light = BK_PALETTE["banjo_brown"]
    crown_col = BK_PALETTE[BIOME_TINTS.get(biome, BIOME_TINTS["foret_broceliande"])["crown"]]
    crown_bottom = BK_PALETTE["foliage_sage"]
    shadow = BK_PALETTE["shadow_brown"]

    zones = [
        {
            "test": lambda co, n, tt=trunk_top, tr=trunk_r: co.z < tt and (co.x**2 + co.y**2) < (tr * 2.5) ** 2,
            "color": trunk_col,
            "ao": 0.4,
        },
    ]

    # Use paint_by_zone for trunk, then override crown manually
    paint_by_zone(obj, zones, fallback_color=crown_col)

    # Enhance crown painting: gradient from sage (bottom) to green (top)
    mesh = obj.data
    color_layer = mesh.vertex_colors["Col"]
    crown_min_z = crown_z - crown_r * 0.5
    crown_max_z = crown_z + crown_r * 0.6
    crown_range = max(crown_max_z - crown_min_z, 0.001)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            co = vert.co
            if co.z >= trunk_top or (co.x**2 + co.y**2) > (trunk_r * 2.5) ** 2:
                ct = max(0.0, min(1.0, (co.z - crown_min_z) / crown_range))
                r, g, b = lerp_color(crown_bottom, crown_col, ct)
                # AO where crown meets trunk
                if co.z < crown_z - crown_r * 0.2:
                    ao_blend = 0.6
                    r = r * (1.0 - ao_blend) + shadow[0] * ao_blend
                    g = g * (1.0 - ao_blend) + shadow[1] * ao_blend
                    b = b * (1.0 - ao_blend) + shadow[2] * ao_blend
                # Directional
                up_dot = max(poly.normal.z, 0.0)
                shade = 0.75 + 0.25 * up_dot
                r *= shade
                g *= shade
                b *= shade
                r += random.uniform(-0.03, 0.03)
                g += random.uniform(-0.03, 0.03)
                b += random.uniform(-0.03, 0.03)
                color_layer.data[loop_idx].color = (
                    max(0.0, min(1.0, r)),
                    max(0.0, min(1.0, g)),
                    max(0.0, min(1.0, b)),
                    1.0,
                )

    apply_material(obj, f"mat_tree_bk_{biome}")
    return obj


# ─── rock_bk (~60 tris) ────────────────────────────────────────────────────────

def gen_rock_bk(biome: str, variant: int = 0):
    """BK rock: displaced icosphere cluster with moss on top. ~200 tris."""
    r = random.uniform(0.35, 0.65)

    # Main body — higher subdiv for smoother BK look
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=(0, 0, r * 0.4))
    obj = bpy.context.active_object
    obj.name = f"rock_bk_{variant:03d}"

    # Squash and stretch for variety
    obj.scale = (random.uniform(0.8, 1.3), random.uniform(0.8, 1.2), random.uniform(0.5, 0.8))
    bpy.ops.object.transform_apply(scale=True)

    # Stronger noise displacement for interesting shape
    displace_verts(obj, strength=r * 0.2, seed_offset=variant)

    # Secondary rock bulges (BK rocks are lumpy, not smooth spheres)
    bulge_parts = []
    for i in range(random.randint(2, 4)):
        br = r * random.uniform(0.25, 0.4)
        angle = random.uniform(0, math.pi * 2)
        bx = math.cos(angle) * r * random.uniform(0.5, 0.8)
        by = math.sin(angle) * r * random.uniform(0.5, 0.8)
        bz = random.uniform(0, r * 0.5)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=br, location=(bx, by, bz))
        bulge = bpy.context.active_object
        bulge.scale.z = random.uniform(0.5, 0.8)
        bpy.ops.object.transform_apply(scale=True)
        displace_verts(bulge, strength=br * 0.15, seed_offset=variant + i * 13)
        bulge_parts.append(bulge)

    if bulge_parts:
        obj = join_into(obj, *bulge_parts)

    # Flatten bottom
    for v in obj.data.vertices:
        if v.co.z < 0:
            v.co.z = 0

    set_smooth(obj)
    enforce_budget(obj, 200)

    # Vertex paint: stone base with moss on top, AO at bottom
    apply_bk_vertex_paint(
        obj,
        base_color=BK_PALETTE["stone_gray"],
        ao_strength=0.35,
        moss_color=BK_PALETTE["moss_green"],
        moss_threshold=0.6,
    )

    apply_material(obj, f"mat_rock_bk_{biome}")
    return obj


# ─── structure_bk (~250 tris) ──────────────────────────────────────────────────

def gen_structure_bk(biome: str, variant: int = 0):
    """BK roundhouse: elliptical base, conical roof, chimney, BK lean. ~500 tris."""
    wall_h = random.uniform(0.9, 1.3)
    wall_rx = random.uniform(0.7, 1.1)
    wall_ry = wall_rx * random.uniform(0.85, 1.0)
    roof_h = random.uniform(0.6, 0.9)
    lean = random.uniform(-0.04, 0.04)

    # Walls — 14 sides for rounder BK shape
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=14, radius=wall_rx, depth=wall_h,
        location=(lean, 0, wall_h / 2),
    )
    walls = bpy.context.active_object
    walls.name = f"structure_bk_{variant:03d}"
    walls.scale.y = wall_ry / wall_rx
    bpy.ops.object.transform_apply(scale=True)

    # BK lean: slight outward tilt on wall tops + irregularity
    for v in walls.data.vertices:
        if v.co.z > wall_h * 0.3:
            t = (v.co.z - wall_h * 0.3) / (wall_h * 0.7)
            dist = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
            if dist > 0.01:
                expand = 1.0 + t * 0.06
                v.co.x *= expand
                v.co.y *= expand
        # Subtle wall irregularity (hand-built look)
        n = noise.noise(v.co * 4.0 + Vector((variant * 5.1, 0, 0)))
        v.co.x += n * 0.02
        v.co.y += n * 0.02

    # Roof — cone with more sides, slight droop
    bpy.ops.mesh.primitive_cone_add(
        vertices=14, radius1=wall_rx * 1.18, radius2=0.05,
        depth=roof_h, location=(lean, 0, wall_h + roof_h / 2),
    )
    roof = bpy.context.active_object
    roof.scale.y = wall_ry / wall_rx
    bpy.ops.object.transform_apply(scale=True)

    # Roof droop at edges (thatch overhang)
    for v in roof.data.vertices:
        dist = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
        if dist > wall_rx * 0.8 and v.co.z < wall_h + roof_h * 0.3:
            v.co.z -= 0.04

    # Chimney — small cylinder on roof
    chimney_angle = random.uniform(0, math.pi * 2)
    cx = lean + math.cos(chimney_angle) * wall_rx * 0.4
    cy = math.sin(chimney_angle) * wall_ry * 0.4
    chimney_h = random.uniform(0.2, 0.35)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.06, depth=chimney_h,
        location=(cx, cy, wall_h + roof_h * 0.6 + chimney_h / 2),
    )
    chimney = bpy.context.active_object

    # Door frame — extruded arch shape (flattened torus half)
    door_angle = random.uniform(0, math.pi * 2)
    dx = math.cos(door_angle) * wall_rx * 0.98
    dy = math.sin(door_angle) * wall_ry * 0.98
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=0.18, depth=0.05,
        location=(dx, dy, wall_h * 0.35),
    )
    door_frame = bpy.context.active_object
    door_frame.scale.z = 2.5
    bpy.ops.object.transform_apply(scale=True)
    # Rotate to face outward
    door_frame.rotation_euler.z = door_angle
    bpy.ops.object.transform_apply(rotation=True)

    # Window circles (small inset discs on walls)
    window_parts = []
    for i in range(random.randint(1, 3)):
        wa = door_angle + math.pi * (0.5 + i * 0.5) + random.uniform(-0.3, 0.3)
        wx = math.cos(wa) * wall_rx * 0.99
        wy = math.sin(wa) * wall_ry * 0.99
        wz = wall_h * random.uniform(0.5, 0.75)
        bpy.ops.mesh.primitive_circle_add(
            vertices=8, radius=0.08,
            location=(wx, wy, wz),
        )
        win = bpy.context.active_object
        win.rotation_euler.z = wa
        win.rotation_euler.y = math.pi / 2
        bpy.ops.object.transform_apply(rotation=True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.fill()
        bpy.ops.object.mode_set(mode='OBJECT')
        window_parts.append(win)

    # Subdivide walls and roof for vertex color resolution
    for part in [walls, roof]:
        bpy.context.view_layer.objects.active = part
        part.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.subdivide(number_cuts=2)
        bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.select_all(action='DESELECT')

    all_parts = [roof, chimney, door_frame] + window_parts
    obj = join_into(walls, *all_parts)
    set_smooth(obj)
    enforce_budget(obj, 500)

    # Vertex paint zones
    door_angle = random.uniform(0, math.pi * 2)
    door_dir_x = math.cos(door_angle)
    door_dir_y = math.sin(door_angle)

    zones = [
        # Door — dark rectangle
        {
            "test": lambda co, n, dx=door_dir_x, dy=door_dir_y, wh=wall_h, wr=wall_rx:
                co.z < wh * 0.6 and co.z > 0.05 and
                (co.x * dx + co.y * dy) > wr * 0.7 and
                abs(-co.x * dy + co.y * dx) < 0.2,
            "color": BK_PALETTE["shadow_brown"],
            "ao": 0.5,
        },
        # Roof
        {
            "test": lambda co, n, wh=wall_h: co.z > wh * 0.9,
            "color": BK_PALETTE["bark_dark"],
            "ao": 0.2,
        },
        # Walls
        {
            "test": lambda co, n: True,
            "color": BK_PALETTE["banjo_brown"],
            "ao": 0.35,
        },
    ]

    paint_by_zone(obj, zones, fallback_color=BK_PALETTE["banjo_brown"])

    apply_material(obj, f"mat_structure_bk_{biome}")
    return obj


# ─── megalith_bk (~80 tris) ────────────────────────────────────────────────────

def gen_megalith_bk(biome: str, variant: int = 0):
    """BK megalith: tall tapered stone with noise, moss cap, crevices. ~250 tris."""
    h = random.uniform(1.8, 3.2)
    r = random.uniform(0.22, 0.45)

    # 12-sided cylinder for rounder stone look
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=r, depth=h,
        location=(0, 0, h / 2),
    )
    obj = bpy.context.active_object
    obj.name = f"megalith_bk_{variant:03d}"

    # More subdivisions for detail
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=4)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Taper top, widen base, add weathering noise
    for v in obj.data.vertices:
        t = v.co.z / h
        dist = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
        if dist > 0.01:
            # Taper: narrower at top, wider at base
            taper = 1.0 - t * 0.35 + (1.0 - t) * 0.1
            v.co.x *= taper
            v.co.y *= taper

        # Multi-octave noise for weathered surface
        n1 = noise.noise(v.co * 2.0 + Vector((variant * 7.3, 0, 0)))
        n2 = noise.noise(v.co * 6.0 + Vector((variant * 3.1, 5, 0))) * 0.3
        n_total = n1 + n2
        v.co.x += n_total * r * 0.22
        v.co.y += n_total * r * 0.22
        v.co.z += n_total * 0.06

    # Vertical crevice grooves (simulate ogham-like weathering)
    for v in obj.data.vertices:
        angle = math.atan2(v.co.y, v.co.x)
        groove = math.sin(angle * random.choice([5, 7, 9])) * 0.02
        dist = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
        if dist > 0.01 and 0.2 < v.co.z / h < 0.8:
            v.co.x += v.co.x / dist * groove
            v.co.y += v.co.y / dist * groove

    # Round the top cap — smooth dome
    for v in obj.data.vertices:
        if v.co.z > h * 0.82:
            dist = math.sqrt(v.co.x ** 2 + v.co.y ** 2)
            cap_r = r * 0.65
            if dist > cap_r * 0.3:
                t_cap = (v.co.z - h * 0.82) / (h * 0.18)
                v.co.z -= t_cap * 0.15 * dist / cap_r

    set_smooth(obj)
    enforce_budget(obj, 250)

    # Vertex paint: stone base -> moss middle -> cream cap
    stone = BK_PALETTE["stone_gray"]
    moss = BK_PALETTE["moss_green"]
    cream = BK_PALETTE["cream_light"]

    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = max(0.0, min(1.0, vert.co.z / h))

            if t < 0.4:
                r_c, g_c, b_c = lerp_color(stone, moss, t / 0.4)
            elif t < 0.8:
                r_c, g_c, b_c = lerp_color(moss, stone, (t - 0.4) / 0.4)
            else:
                r_c, g_c, b_c = lerp_color(stone, cream, (t - 0.8) / 0.2)

            # AO at base
            ao = 1.0 - 0.4 * (1.0 - t) ** 2
            r_c *= ao
            g_c *= ao
            b_c *= ao

            # Directional shading
            up_dot = max(poly.normal.z, 0.0)
            shade = 0.7 + 0.3 * up_dot
            r_c *= shade
            g_c *= shade
            b_c *= shade

            # Crevice AO — vertices with inward-pointing normals in XY plane
            # (simulates dark crevices from noise displacement)
            dist = math.sqrt(vert.co.x ** 2 + vert.co.y ** 2)
            if dist > 0.01:
                radial_dot = (vert.co.x * poly.normal.x + vert.co.y * poly.normal.y) / dist
                if radial_dot < 0:  # Normal points inward = crevice
                    crevice = min(abs(radial_dot) * 0.5, 0.3)
                    r_c *= (1.0 - crevice)
                    g_c *= (1.0 - crevice)
                    b_c *= (1.0 - crevice)

            r_c += random.uniform(-0.03, 0.03)
            g_c += random.uniform(-0.03, 0.03)
            b_c += random.uniform(-0.03, 0.03)

            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r_c)),
                max(0.0, min(1.0, g_c)),
                max(0.0, min(1.0, b_c)),
                1.0,
            )

    apply_material(obj, f"mat_megalith_bk_{biome}")
    return obj


# ─── collectible_bk (~30 tris) ─────────────────────────────────────────────────

def gen_collectible_bk(biome: str, variant: int = 0):
    """BK collectible: ogham jiggy (star shape) or ring (torus). ~100 tris."""
    kind = variant % 2

    if kind == 0:
        # Jiggy-like star: icosphere with pulled-out points
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.15, location=(0, 0, 0.2))
        obj = bpy.context.active_object
        obj.name = f"collectible_bk_{variant:03d}"

        # Pull out vertices that are near axis-aligned directions to make star points
        for v in obj.data.vertices:
            co = v.co - Vector((0, 0, 0.2))
            length = co.length
            if length > 0.01:
                # Check alignment with cardinal directions
                norm = co.normalized()
                max_align = max(abs(norm.x), abs(norm.y), abs(norm.z))
                if max_align > 0.75:
                    pull = 1.0 + (max_align - 0.75) * 1.8
                    v.co = Vector((0, 0, 0.2)) + co * pull

        # Slight vertical stretch for jiggy shape
        obj.scale.z = random.uniform(1.1, 1.3)
        bpy.ops.object.transform_apply(scale=True)

        displace_verts(obj, strength=0.01, seed_offset=variant)

    else:
        # Ring collectible — thicker, more detailed torus
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.13, minor_radius=0.045,
            major_segments=16, minor_segments=8,
            location=(0, 0, 0.18),
        )
        obj = bpy.context.active_object
        obj.name = f"collectible_bk_{variant:03d}"

        # Slight wobble for character
        for v in obj.data.vertices:
            angle = math.atan2(v.co.y, v.co.x)
            v.co.z += math.sin(angle * 3) * 0.008

    set_smooth(obj)
    enforce_budget(obj, 100)

    # Bright vertex paint: gold with cream highlight on top
    gold = BK_PALETTE["gold_accent"]
    cream = BK_PALETTE["cream_light"]

    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="Col")
    color_layer = mesh.vertex_colors["Col"]

    verts = [v.co.copy() for v in mesh.vertices]
    max_z = max(v.z for v in verts) if verts else 1.0
    min_z = min(v.z for v in verts) if verts else 0.0
    range_z = max(max_z - min_z, 0.001)

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            vert = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            t = (vert.co.z - min_z) / range_z

            # Gold base with cream highlight at top
            r, g, b = lerp_color(gold, cream, t * 0.4)

            # Bright — minimal AO, just a touch
            ao = 1.0 - 0.1 * (1.0 - t) ** 2
            r *= ao
            g *= ao
            b *= ao

            # Strong upward shading for eye-catching glow
            up_dot = max(poly.normal.z, 0.0)
            shade = 0.8 + 0.2 * up_dot
            r *= shade
            g *= shade
            b *= shade

            r += random.uniform(-0.02, 0.02)
            g += random.uniform(-0.02, 0.02)
            b += random.uniform(-0.02, 0.02)

            color_layer.data[loop_idx].color = (
                max(0.0, min(1.0, r)),
                max(0.0, min(1.0, g)),
                max(0.0, min(1.0, b)),
                1.0,
            )

    apply_material(obj, f"mat_collectible_bk_{biome}")
    return obj


# ─── creature_bk (~300 tris) ───────────────────────────────────────────────────

def gen_creature_bk(biome: str, variant: int = 0):
    """BK creature: segmented body, big googly eyes, BK proportions. ~600 tris."""
    total_h = random.uniform(0.55, 0.85)
    body_r = total_h * 0.24
    head_r = total_h * 0.20  # Head = 35-40% of height (BK signature)
    limb_r = body_r * 0.28
    limb_len = total_h * 0.28

    # Body colors from biome accent
    accent_key = BIOME_TINTS.get(biome, BIOME_TINTS["foret_broceliande"])["accent"]
    body_col = BK_PALETTE.get(accent_key, BK_PALETTE["kazooie_red"])
    belly_col = lerp_color(body_col, BK_PALETTE["cream_light"], 0.4)

    # Body — icosphere subdiv 3 for smoother shape
    body_z = total_h * 0.35
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=body_r, location=(0, 0, body_z))
    body = bpy.context.active_object
    body.name = f"creature_bk_{variant:03d}"
    body.scale = (1.0, 0.9, 1.15)
    bpy.ops.object.transform_apply(scale=True)

    # Head — subdiv 3, BK oversized head
    head_z = total_h * 0.72
    gap = 0.03
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=head_r, location=(0, 0, head_z))
    head = bpy.context.active_object

    # Nose/snout bump
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2, radius=head_r * 0.3,
        location=(0, -head_r * 0.9, head_z - head_r * 0.1),
    )
    snout = bpy.context.active_object
    snout.scale = (0.8, 1.2, 0.7)
    bpy.ops.object.transform_apply(scale=True)

    # Ears/horns — small cones
    ear_parts = []
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cone_add(
            vertices=6, radius1=head_r * 0.2, radius2=0.01,
            depth=head_r * 0.5,
            location=(side * head_r * 0.6, 0, head_z + head_r * 0.7),
        )
        ear = bpy.context.active_object
        ear.rotation_euler.x = random.uniform(-0.2, 0.2)
        ear.rotation_euler.y = side * random.uniform(0.2, 0.5)
        bpy.ops.object.transform_apply(rotation=True)
        ear_parts.append(ear)

    # Eyes — bigger googly eyes (BK signature), subdiv 2
    eye_r = head_r * 0.4
    pupil_r = eye_r * 0.5
    eye_parts = []

    for side in [-1, 1]:
        ex = side * head_r * 0.5
        ey = -head_r * 0.7
        ez = head_z + head_r * 0.2

        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=eye_r, location=(ex, ey, ez))
        eye = bpy.context.active_object
        eye_parts.append(eye)

        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=pupil_r,
            location=(ex, ey - eye_r * 0.5, ez + pupil_r * 0.15),
        )
        pupil = bpy.context.active_object
        eye_parts.append(pupil)

    # Limbs — 8-sided for smoother tubes
    limb_parts = []
    # Arms
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=limb_r, depth=limb_len,
            location=(side * (body_r + gap + limb_r), 0, body_z + body_r * 0.2),
            rotation=(0, side * 0.3, 0),
        )
        arm = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        limb_parts.append(arm)

        # Hands — small spheres
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=limb_r * 1.3,
            location=(side * (body_r + gap + limb_r + limb_len * 0.4), 0, body_z),
        )
        hand = bpy.context.active_object
        limb_parts.append(hand)

    # Legs
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=limb_r * 1.3, depth=limb_len,
            location=(side * body_r * 0.5, 0, body_z - body_r - gap),
        )
        leg = bpy.context.active_object
        limb_parts.append(leg)

    # Feet — bigger, flatter (BK cartoonish)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=limb_r * 1.8,
            location=(side * body_r * 0.5, -limb_r * 0.3, limb_r * 1.3),
        )
        foot = bpy.context.active_object
        foot.scale = (1.1, 1.5, 0.5)
        bpy.ops.object.transform_apply(scale=True)
        limb_parts.append(foot)

    # Tail — small tapered cylinder
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=body_r * 0.3, radius2=0.01,
        depth=body_r * 1.2,
        location=(0, body_r * 0.8, body_z - body_r * 0.3),
        rotation=(math.radians(-60), 0, 0),
    )
    tail = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)

    obj = join_into(body, head, snout, tail, *ear_parts, *eye_parts, *limb_parts)
    set_smooth(obj)
    enforce_budget(obj, 600)

    # Vertex paint by zone
    zones = [
        # Pupils — dark
        {
            "test": lambda co, n, hz=head_z, hr=head_r, pr=pupil_r:
                co.z > hz - hr and co.z < hz + hr and co.y < -hr * 0.8 and
                math.sqrt((co.x - 0) ** 2 + (co.z - hz - hr * 0.15) ** 2) < pr * 2.5,
            "color": BK_PALETTE["shadow_brown"],
            "ao": 0.0,
        },
        # Eyes — white
        {
            "test": lambda co, n, hz=head_z, hr=head_r, er=eye_r:
                co.z > hz - hr * 0.5 and co.y < -hr * 0.4 and
                any(math.sqrt((co.x - s * hr * 0.55) ** 2 + (co.z - hz - hr * 0.15) ** 2) < er * 1.8
                    for s in [-1, 1]),
            "color": BK_PALETTE["cream_light"],
            "ao": 0.05,
        },
        # Head — body color, slightly lighter
        {
            "test": lambda co, n, hz=head_z, hr=head_r:
                co.z > hz - hr * 1.2 and co.z < hz + hr * 1.2 and
                math.sqrt(co.x ** 2 + co.y ** 2) < hr * 2.0,
            "color": lerp_color(body_col, BK_PALETTE["cream_light"], 0.15),
            "ao": 0.2,
        },
        # Belly — lighter underside
        {
            "test": lambda co, n, bz=body_z: n.z < -0.3 and co.z < bz + body_r,
            "color": belly_col,
            "ao": 0.2,
        },
        # Feet
        {
            "test": lambda co, n: co.z < limb_r * 2.5,
            "color": lerp_color(body_col, BK_PALETTE["shadow_brown"], 0.3),
            "ao": 0.3,
        },
    ]

    paint_by_zone(obj, zones, fallback_color=body_col)

    apply_material(obj, f"mat_creature_bk_{biome}")
    return obj


# ─── bridge_bk (~180 tris) ─────────────────────────────────────────────────────

def gen_bridge_bk(biome: str, variant: int = 0):
    """BK bridge: irregular planks with gaps, tilted posts, sagging rope. ~400 tris."""
    length = random.uniform(2.5, 3.5)
    width = random.uniform(0.55, 0.75)
    plank_count = random.randint(12, 18)
    post_h = random.uniform(0.35, 0.55)

    parts = []

    # Planks — subdivided cubes for vertex color detail, with gaps
    plank_spacing = length / plank_count
    for i in range(plank_count):
        # Occasional missing plank (BK style gaps)
        if random.random() < 0.12:
            continue

        px = -length / 2 + plank_spacing * (i + 0.5) + random.uniform(-0.02, 0.02)
        pw = plank_spacing * random.uniform(0.7, 0.88)
        ph = random.uniform(0.03, 0.06)
        # Slight sag in the middle of the bridge
        sag = -0.04 * math.sin(math.pi * (i + 0.5) / plank_count)

        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(px, 0, sag),
        )
        plank = bpy.context.active_object
        plank.scale = (pw / 2, width / 2, ph / 2)
        bpy.ops.object.transform_apply(scale=True)

        # Subdivide each plank for wood grain vertex color resolution
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.subdivide(number_cuts=1)
        bpy.ops.object.mode_set(mode='OBJECT')

        # Slight tilt for irregular hand-built look
        plank.rotation_euler.z = random.uniform(-0.04, 0.04)
        plank.rotation_euler.x = random.uniform(-0.02, 0.02)
        bpy.ops.object.transform_apply(rotation=True)
        parts.append(plank)

    # Side beams — thick log-like cylinders running along each edge
    for sy in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=0.035, depth=length * 0.95,
            location=(0, sy * width / 2 * 0.9, -0.02),
            rotation=(0, math.pi / 2, 0),
        )
        beam = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
        # Add sag to the beam too
        for v in beam.data.vertices:
            t = (v.co.x + length / 2) / length
            v.co.z -= 0.03 * math.sin(math.pi * t)
        parts.append(beam)

    # Posts — thicker, 8-sided, with knob tops
    post_r = 0.032
    for sx in [-1, 1]:
        for sy in [-1, 1]:
            tilt_x = random.uniform(-0.06, 0.06)
            tilt_y = sy * random.uniform(0.03, 0.1)

            bpy.ops.mesh.primitive_cylinder_add(
                vertices=8, radius=post_r, depth=post_h,
                location=(sx * length / 2 * 0.88, sy * width / 2, post_h / 2),
            )
            post = bpy.context.active_object
            post.rotation_euler.x = tilt_y
            post.rotation_euler.y = tilt_x
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(post)

            # Post cap — small sphere on top
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1, radius=post_r * 1.4,
                location=(sx * length / 2 * 0.88, sy * width / 2, post_h),
            )
            cap = bpy.context.active_object
            parts.append(cap)

    # Middle posts for longer bridges
    if length > 2.8:
        for sy in [-1, 1]:
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=8, radius=post_r * 0.8, depth=post_h * 0.8,
                location=(0, sy * width / 2, post_h * 0.4 - 0.03),
            )
            mid_post = bpy.context.active_object
            mid_post.rotation_euler.x = sy * random.uniform(0.03, 0.08)
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(mid_post)

    # Rope rails — cylinder segments with sag (not a single straight piece)
    rope_segs = 8
    for sy in [-1, 1]:
        for seg in range(rope_segs):
            t0 = seg / rope_segs
            t1 = (seg + 1) / rope_segs
            x0 = -length / 2 * 0.85 + t0 * length * 0.85
            x1 = -length / 2 * 0.85 + t1 * length * 0.85
            seg_len = x1 - x0
            mid_x = (x0 + x1) / 2
            # Sag in the middle
            sag_amount = post_h * 0.75 - 0.06 * math.sin(math.pi * (t0 + t1) / 2)

            bpy.ops.mesh.primitive_cylinder_add(
                vertices=4, radius=0.015, depth=seg_len,
                location=(mid_x, sy * width / 2, sag_amount),
                rotation=(0, math.pi / 2, 0),
            )
            rope = bpy.context.active_object
            bpy.ops.object.transform_apply(rotation=True)
            parts.append(rope)

    # Join all
    first = parts[0]
    first.name = f"bridge_bk_{variant:03d}"
    if len(parts) > 1:
        obj = join_into(first, *parts[1:])
    else:
        obj = first

    set_smooth(obj)
    enforce_budget(obj, 400)

    # Vertex paint: wood planks, dark gaps, AO underneath
    wood = BK_PALETTE["banjo_brown"]
    dark = BK_PALETTE["bark_dark"]
    shadow = BK_PALETTE["shadow_brown"]

    zones = [
        # Rope — dark
        {
            "test": lambda co, n, w=width: abs(abs(co.y) - w / 2) < 0.03 and co.z > 0.15,
            "color": dark,
            "ao": 0.1,
        },
        # Underside — shadowed
        {
            "test": lambda co, n: n.z < -0.5,
            "color": shadow,
            "ao": 0.5,
        },
        # Posts
        {
            "test": lambda co, n, l=length, w=width:
                (abs(co.x) > l / 2 * 0.7) and co.z > 0.05,
            "color": dark,
            "ao": 0.25,
        },
    ]

    paint_by_zone(obj, zones, fallback_color=wood)

    apply_material(obj, f"mat_bridge_bk_{biome}")
    return obj


# ═════════════════════════════════════════════════════════════════════════════════
# GENERATOR REGISTRY
# ═════════════════════════════════════════════════════════════════════════════════

GENERATORS = {
    "vegetation":   {"tree_bk": gen_tree_bk},
    "rocks":        {"rock_bk": gen_rock_bk},
    "structures":   {"structure_bk": gen_structure_bk},
    "megaliths":    {"megalith_bk": gen_megalith_bk},
    "collectibles": {"collectible_bk": gen_collectible_bk},
    "characters":   {"creature_bk": gen_creature_bk},
    "props":        {"bridge_bk": gen_bridge_bk},
}

CATEGORIES = list(GENERATORS.keys())

BIOMES = [
    "foret_broceliande",
    "landes_bruyere",
    "cotes_sauvages",
    "villages_celtes",
    "cercles_pierres",
    "marais_korrigans",
    "collines_dolmens",
    "iles_mystiques",
]

# Budget reference (from BK_ART_STYLE_GUIDE.md)
TRI_BUDGETS = {
    "tree_bk":        400,
    "rock_bk":        200,
    "structure_bk":   500,
    "megalith_bk":    250,
    "collectible_bk": 100,
    "creature_bk":    600,
    "bridge_bk":      400,
}

# Real-world scale factors (1 Blender unit = 1 meter in Godot).
# Each generator produces assets at a "modeling scale" — these factors
# rescale them to physically correct dimensions before export.
# Format: (target_height_meters, reference_current_height_meters)
REAL_WORLD_SCALES = {
    "tree_bk":        5.0,   # Chene breton: ~8-12m, but BK stylized = ~5m playable
    "rock_bk":        1.8,   # Rocher/boulder: ~1-2m across
    "structure_bk":   3.2,   # Hutte celtique: ~3m walls + roof = ~4.5m total
    "megalith_bk":    3.5,   # Menhir: ~3-5m typical
    "collectible_bk": 0.4,   # Ogham pickup: ~20-40cm (hand-sized, visible in scene)
    "creature_bk":    0.7,   # Korrigan: ~60-80cm (small mythical creature)
    "bridge_bk":      1.2,   # Pont de bois: already ~3m, slight scale-up to ~3.5m
}


# ═════════════════════════════════════════════════════════════════════════════════
# MAIN — Batch generation
# ═════════════════════════════════════════════════════════════════════════════════

def main():
    args = parse_args()
    category = args["category"]
    biome = args["biome"]
    count = args["count"]
    seed = args["seed"]

    random.seed(seed)

    # Output directory
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
    print(f"BK Asset Generator — M.E.R.L.I.N.")
    print(f"Category: {category} | Biome: {biome} | Count: {count}")
    print(f"Output: {output_dir}")
    print(f"{'=' * 60}\n")

    for i in range(count):
        gen_name = gen_names[i % len(gen_names)]
        gen_func = generators[gen_name]
        variant = (i // len(gen_names)) + seed

        clear_scene()

        try:
            obj = gen_func(biome, variant)

            # Set origin to geometry center
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')

            tris = count_tris(obj)
            budget = TRI_BUDGETS.get(gen_name, 300)

            filename = f"{gen_name}_{biome}_{variant:04d}.glb"
            filepath = os.path.join(output_dir, filename)

            export_glb(obj, filepath, gen_name=gen_name)

            file_size = os.path.getsize(filepath) if os.path.exists(filepath) else 0

            result = {
                "name": filename,
                "category": category,
                "biome": biome,
                "generator": gen_name,
                "variant": variant,
                "tris": tris,
                "budget": budget,
                "file_size_kb": round(file_size / 1024, 1),
            }
            results.append(result)

            status = "OK" if tris <= budget else f"OVER ({tris}/{budget})"
            print(f"  [{i + 1}/{count}] {filename} — {tris} tris [{status}], {result['file_size_kb']}KB")

        except Exception as e:
            print(f"  [ERROR] {gen_name} variant {variant}: {e}")
            import traceback
            traceback.print_exc()

    # Write manifest
    manifest_path = os.path.join(output_dir, "_manifest.json")
    manifest = {
        "generator": "blender_n64_generator.py (BK rewrite)",
        "style": "banjo-kazooie",
        "category": category,
        "biome": biome,
        "count": len(results),
        "assets": results,
    }
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    # Summary
    if results:
        tris_vals = [r["tris"] for r in results]
        sizes = [r["file_size_kb"] for r in results]
        over = [r for r in results if r["tris"] > r["budget"]]

        print(f"\n{'=' * 60}")
        print(f"BATCH COMPLETE: {len(results)}/{count} assets generated")
        print(f"Tris: min={min(tris_vals)}, max={max(tris_vals)}, avg={sum(tris_vals) // len(tris_vals)}")
        print(f"Size: min={min(sizes)}KB, max={max(sizes)}KB, total={sum(sizes):.1f}KB")
        if over:
            print(f"WARNING: {len(over)} assets over budget!")
            for r in over:
                print(f"  - {r['name']}: {r['tris']}/{r['budget']} tris")
        print(f"Manifest: {manifest_path}")
        print(f"{'=' * 60}\n")
    else:
        print("\n[WARNING] No assets generated.\n")


if __name__ == "__main__":
    main()
