"""
M.E.R.L.I.N. Menu Coast Scene — Blender Builder v4 (Pixel-Perfect)
Strategy: Blender = static geometry only (5 GLBs). Godot handles all dynamic effects.

Exports:
  1. cliff_unified.glb    — Whale-back cliff + 3 ridges + outcrops + menhirs + boulder
  2. tower_unified.glb    — Tall ruined tower + broken spire + windows + moss
  3. rocks_set.glb        — 7 sea rocks at cliff base
  4. crystal_cluster_unified.glb — 2 clusters (purple + teal)
  5. cabin_unified.glb    — Cabin on far-left plateau

NOT exported (Godot handles): ocean, sky, clouds, sun mesh, particles, vegetation,
orbiting stones, fog, day/night, UI.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector
from pathlib import Path

# =============================================================================
# CONFIG
# =============================================================================
EXPORT_DIR = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast"
BLEND_DIR = r"c:\Users\PGNK2128\Godot-MCP\assets\blender"
random.seed(42)

# --- EXACT COLOR PALETTE (from reference) ---
C_SKY = (0.45, 0.75, 0.95)
C_GREEN_SUN = (0.55, 0.70, 0.25)
C_GREEN_SHADE = (0.30, 0.50, 0.18)
C_ROCK_FACE = (0.50, 0.40, 0.28)
C_ROCK_DARK = (0.25, 0.22, 0.16)
C_OCEAN_DEEP = (0.05, 0.22, 0.40)
C_OCEAN_MID = (0.10, 0.35, 0.55)
C_OCEAN_FOAM = (0.60, 0.75, 0.80)
C_TOWER_STONE = (0.42, 0.38, 0.32)
C_CRYSTAL_PURPLE = (0.50, 0.15, 0.75)
C_CRYSTAL_TEAL = (0.15, 0.70, 0.65)
C_SUN_EMIT = (1.0, 0.95, 0.70)


# =============================================================================
# HELPERS
# =============================================================================
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def shade_flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False


def _make_solid_material(name, color, roughness=0.85):
    """Create a simple solid-color Principled BSDF material."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def create_zone_materials():
    """5 zone materials for cliff height-based assignment."""
    zones = {
        'green_bright': (0.55, 0.70, 0.25),
        'green_mid': (0.38, 0.55, 0.22),
        'green_dark': (0.30, 0.48, 0.18),
        'rock_warm': (0.50, 0.40, 0.28),
        'rock_dark': (0.28, 0.24, 0.18),
    }
    mats = {}
    for name, color in zones.items():
        mats[name] = _make_solid_material(f"Zone_{name}", color)
    return mats


def create_tower_materials():
    """Tower-specific materials."""
    specs = {
        'stone_light': (0.50, 0.48, 0.42),
        'stone_mid': (0.42, 0.38, 0.32),
        'stone_dark': (0.32, 0.28, 0.22),
        'window': (0.08, 0.06, 0.05),
        'moss': (0.28, 0.48, 0.20),
    }
    mats = {}
    for name, color in specs.items():
        mats[name] = _make_solid_material(f"Tower_{name}", color)
    return mats


def create_cabin_materials():
    """Cabin-specific materials."""
    specs = {
        'wood_warm': (0.48, 0.33, 0.18),
        'roof_dark': (0.20, 0.16, 0.13),
        'chimney': (0.40, 0.38, 0.35),
        'door': (0.12, 0.08, 0.05),
    }
    mats = {}
    for name, color in specs.items():
        mats[name] = _make_solid_material(f"Cabin_{name}", color)
    return mats


def assign_materials_by_height(obj, zone_mats, thresholds):
    """Assign materials to faces based on average vertex Z height."""
    mesh = obj.data
    mat_list = list(zone_mats.values())
    mat_names = list(zone_mats.keys())
    mesh.materials.clear()
    for mat in mat_list:
        mesh.materials.append(mat)

    for face in mesh.polygons:
        avg_z = sum(mesh.vertices[vi].co.z for vi in face.vertices) / len(face.vertices)
        if avg_z > thresholds[0]:
            face.material_index = mat_names.index(mat_names[0])
        elif avg_z > thresholds[1]:
            face.material_index = mat_names.index(mat_names[1])
        elif avg_z > thresholds[2]:
            face.material_index = mat_names.index(mat_names[2])
        elif avg_z > thresholds[3]:
            face.material_index = mat_names.index(mat_names[3])
        else:
            face.material_index = len(mat_names) - 1


def create_emission_material(name, base_color, emission_color, emission_strength):
    """Emission material for crystals and sun mesh."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.1
    bsdf.inputs["Emission Color"].default_value = (*emission_color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emission_strength

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (300, 0)

    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def assign_materials_to_faces(obj, zone_mats, classify_func):
    """Assign materials to faces using a classify function(avg_x, avg_y, avg_z) -> mat_key."""
    mesh = obj.data
    mat_names = list(zone_mats.keys())
    mesh.materials.clear()
    for mat in zone_mats.values():
        mesh.materials.append(mat)

    for face in mesh.polygons:
        verts = [mesh.vertices[vi].co for vi in face.vertices]
        n = len(verts)
        avg_x = sum(v.x for v in verts) / n
        avg_y = sum(v.y for v in verts) / n
        avg_z = sum(v.z for v in verts) / n
        key = classify_func(avg_x, avg_y, avg_z)
        face.material_index = mat_names.index(key)


def join_objects(main_obj, others):
    """Join a list of objects into main_obj."""
    bpy.ops.object.select_all(action='DESELECT')
    main_obj.select_set(True)
    for o in others:
        o.select_set(True)
    bpy.context.view_layer.objects.active = main_obj
    bpy.ops.object.join()
    return main_obj


def decimate(obj, ratio):
    """Apply decimate modifier for faceted look."""
    mod = obj.modifiers.new("Decimate", 'DECIMATE')
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Decimate")


def export_glb(obj_or_list, filename):
    """Export selected object(s) as GLB."""
    bpy.ops.object.select_all(action='DESELECT')
    if isinstance(obj_or_list, list):
        for o in obj_or_list:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obj_or_list[0]
    else:
        obj_or_list.select_set(True)
        bpy.context.view_layer.objects.active = obj_or_list

    path = os.path.join(EXPORT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB',
        use_selection=True, export_apply=True
    )
    size = os.path.getsize(path)
    print(f"[EXPORT] {filename}: {size // 1024}KB")


def _noise3(x, y, z):
    """Simple deterministic noise using mathutils."""
    from mathutils import noise as mn
    return mn.noise(Vector((x, y, z)))


# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

def build_cliff():
    """Whale-back cliff with 3 ridges stepping down left-to-right,
    steep rock face on ocean side, large protruding boulder, menhirs.
    Extends heavily to the LEFT; tower sits at rightmost edge (~x=15)."""

    all_parts = []

    # === RIDGE 1 (leftmost, highest ~80% height) — extends far left ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=40, y_subdivisions=30, size=1, location=(-18, 0, 0)
    )
    ridge1 = bpy.context.active_object
    ridge1.name = "Ridge1"
    ridge1.scale = (50, 35, 1)
    bpy.ops.object.transform_apply(scale=True)

    for v in ridge1.data.vertices:
        xn = v.co.x / 50
        yn = v.co.y / 35
        # Whale-back profile: rounded on top, steep on ocean (negative Y) side
        whale = 1.0 - (xn + 0.3) ** 2 * 1.5  # peaks left-of-center
        whale = max(whale, 0.0)
        # Y falloff: gentle on positive Y (inland), steep on negative Y (ocean)
        if yn < -0.1:
            y_drop = (yn + 0.1) ** 2 * 25.0
        else:
            y_drop = 0.0
        h = 11.0 * whale - y_drop
        h += _noise3(xn * 5, yn * 5, 0.0) * 1.2
        # Taper right edge down toward ridge 2
        if xn > 0.3:
            h -= (xn - 0.3) * 8.0
        # Taper far left gently
        if xn < -0.4:
            h -= (abs(xn) - 0.4) * 3.0
        v.co.z = max(h, -1.0)
    all_parts.append(ridge1)

    # === RIDGE 2 (middle, ~60% height) — main plateau where tower sits ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=30, y_subdivisions=25, size=1, location=(5, -3, 0)
    )
    ridge2 = bpy.context.active_object
    ridge2.name = "Ridge2"
    ridge2.scale = (35, 25, 1)
    bpy.ops.object.transform_apply(scale=True)

    for v in ridge2.data.vertices:
        xn = v.co.x / 35
        yn = v.co.y / 25
        base = 7.5
        # Peninsula shape: narrows toward right (where tower goes)
        width_at_x = max(0.5 - xn * 0.8, 0.05)
        if abs(yn) > width_at_x:
            base -= (abs(yn) - width_at_x) * 12.0
        # Noise
        base += _noise3(xn * 6, yn * 6, 2.0) * 0.8
        # Drop at edges
        if xn > 0.35:
            base -= (xn - 0.35) * 6.0
        if xn < -0.4:
            base -= (abs(xn) - 0.4) * 4.0
        v.co.z = max(base, -1.0)
    all_parts.append(ridge2)

    # === RIDGE 3 (lowest, ~30% height) — extends toward camera, has protruding rock ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=20, y_subdivisions=18, size=1, location=(0, -14, 0)
    )
    ridge3 = bpy.context.active_object
    ridge3.name = "Ridge3"
    ridge3.scale = (30, 16, 1)
    bpy.ops.object.transform_apply(scale=True)

    for v in ridge3.data.vertices:
        xn = v.co.x / 30
        yn = v.co.y / 16
        base = 3.5
        base += _noise3(xn * 7, yn * 7, 4.0) * 1.0
        # Taper edges
        edge_dist = max(abs(xn) - 0.3, 0) + max(abs(yn) - 0.3, 0)
        base -= edge_dist * 5.0
        v.co.z = max(base, -1.5)
    all_parts.append(ridge3)

    # === CLIFF FACE — vertical rock wall under plateaus (ocean side) ===
    # Main face: tall slab behind ridges
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-5, -12, 3.0))
    face1 = bpy.context.active_object
    face1.name = "CliffFace1"
    face1.scale = (55, 3.5, 11)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face1)

    # Secondary face layer (depth variation)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(3, -15, 1.5))
    face2 = bpy.context.active_object
    face2.name = "CliffFace2"
    face2.scale = (40, 2.5, 7)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face2)

    # Lower overhang face
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-10, -17, 0.0))
    face3 = bpy.context.active_object
    face3.name = "CliffFace3"
    face3.scale = (30, 2, 4)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face3)

    # === LARGE PROTRUDING BOULDER (center-bottom, over ocean) ===
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=3, radius=6.0, location=(2, -18, 1.0)
    )
    boulder = bpy.context.active_object
    boulder.name = "Boulder"
    boulder.scale = (1.4, 1.0, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    for v in boulder.data.vertices:
        v.co += v.co.normalized() * random.uniform(-0.4, 0.4)
    all_parts.append(boulder)

    # === ROCK OUTCROPS on cliff face (22 icospheres for texture) ===
    for i in range(22):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2,
            radius=random.uniform(1.5, 5.0),
            location=(
                random.uniform(-30, 20),
                random.uniform(-20, -8),
                random.uniform(-1, 7),
            ),
        )
        outcrop = bpy.context.active_object
        outcrop.scale = (
            random.uniform(0.8, 1.4),
            random.uniform(0.5, 1.0),
            random.uniform(0.3, 0.7),
        )
        bpy.ops.object.transform_apply(scale=True)
        for v in outcrop.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.3, 0.3)
        all_parts.append(outcrop)

    # === CAVE / OVERHANG recesses (dark indentations) ===
    for i in range(5):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2,
            radius=random.uniform(2.0, 4.0),
            location=(
                random.uniform(-20, 10),
                random.uniform(-16, -10),
                random.uniform(0, 4),
            ),
        )
        cave = bpy.context.active_object
        cave.scale = (1.2, 0.5, 0.6)
        bpy.ops.object.transform_apply(scale=True)
        all_parts.append(cave)

    # === MENHIRS on plateau (thin vertical standing stones) ===
    for i in range(15):
        h = random.uniform(1.2, 3.0)
        px = random.uniform(-30, 10)
        py = random.uniform(-6, 8)
        # Estimate plateau height at this location
        pz = 9.0 if px < -5 else 7.5 if px < 10 else 5.0
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(px, py, pz + h / 2),
        )
        menhir = bpy.context.active_object
        menhir.scale = (0.18, 0.14, h)
        bpy.ops.object.transform_apply(scale=True)
        menhir.rotation_euler.y = random.uniform(-0.1, 0.1)
        menhir.rotation_euler.x = random.uniform(-0.05, 0.05)
        all_parts.append(menhir)

    # === JOIN ALL ===
    main = all_parts[0]
    join_objects(main, all_parts[1:])
    main.name = "Cliff"

    # Decimate for low-poly faceted look
    decimate(main, 0.30)
    shade_flat(main)

    # Multi-material assignment by height zones
    zone_mats = create_zone_materials()
    assign_materials_by_height(main, zone_mats, [8.0, 5.5, 3.0, 1.0])

    return main


def build_tower():
    """Very tall ruined Celtic tower at the right edge of the plateau.
    Height ~25 (3x cliff height). Brown/grey stone, pointed broken top,
    windows, moss patches. Position at rightmost cliff edge."""

    # Tower center at right edge of plateau
    tower_x = 15
    tower_y = -5
    tower_base_z = 7.5  # plateau height at this location
    tower_height = 30
    tower_center_z = tower_base_z + tower_height / 2

    # Main tower body — 12-sided cylinder
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=3.0, depth=tower_height,
        location=(tower_x, tower_y, tower_center_z)
    )
    tower = bpy.context.active_object
    tower.name = "Tower"

    # Roughen tower surface for weathered stone look
    for v in tower.data.vertices:
        offset = random.uniform(-0.2, 0.2)
        v.co.x += offset
        v.co.y += offset
        # Slight taper toward top
        t = (v.co.z - (tower_center_z - tower_height / 2)) / tower_height
        taper = 1.0 - t * 0.15  # slightly narrower at top
        local_x = v.co.x - tower_x
        local_y = v.co.y - tower_y
        v.co.x = tower_x + local_x * taper
        v.co.y = tower_y + local_y * taper

    parts = []

    # === POINTED BROKEN SPIRE on top ===
    spire_base_z = tower_base_z + tower_height
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=2.5, radius2=0.3,
        depth=8, location=(tower_x, tower_y, spire_base_z + 4)
    )
    spire = bpy.context.active_object
    spire.name = "Spire"
    # Delete some vertices to make it "broken"
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(spire.data)
    bm.verts.ensure_lookup_table()
    verts_remove = [v for v in bm.verts if v.co.x > 1.0 and v.co.z > 2.0]
    if verts_remove:
        bmesh.ops.delete(bm, geom=verts_remove, context='VERTS')
    bmesh.update_edit_mesh(spire.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    parts.append(spire)

    # === WINDOWS (3 dark recesses around tower) ===
    for j in range(4):
        wz = tower_base_z + 5 + j * 5
        angle = math.radians(j * 80 + 20)
        wx = tower_x + math.cos(angle) * 3.2
        wy = tower_y + math.sin(angle) * 3.2
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, wy, wz))
        win = bpy.context.active_object
        win.name = f"Window_{j}"
        win.scale = (0.5, 0.2, 0.9)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(win)

    # === MOSS PATCHES (flattened spheres on surface) ===
    for k in range(8):
        angle = math.radians(k * 45 + 10)
        mz = random.uniform(tower_base_z + 2, tower_base_z + tower_height - 3)
        mx = tower_x + math.cos(angle) * 3.3
        my = tower_y + math.sin(angle) * 3.3
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=8, ring_count=6, radius=random.uniform(0.6, 1.2),
            location=(mx, my, mz)
        )
        moss = bpy.context.active_object
        moss.scale.z = 0.25
        bpy.ops.object.transform_apply(scale=True)
        parts.append(moss)

    # === BASE RUBBLE (stones around tower base) ===
    for i in range(6):
        angle = math.radians(i * 60 + random.uniform(-15, 15))
        dist = random.uniform(3.5, 6.0)
        rx = tower_x + math.cos(angle) * dist
        ry = tower_y + math.sin(angle) * dist
        rz = tower_base_z + random.uniform(-0.5, 0.5)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=random.uniform(0.4, 1.0),
            location=(rx, ry, rz)
        )
        rubble = bpy.context.active_object
        rubble.scale.z = random.uniform(0.4, 0.7)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(rubble)

    # Join everything
    join_objects(tower, parts)

    # Decimate
    decimate(tower, 0.45)
    shade_flat(tower)

    # Multi-material assignment by height + distance
    tower_mats = create_tower_materials()

    def classify_tower(x, y, z):
        dx = x - tower_x
        dy = y - tower_y
        dist = math.sqrt(dx * dx + dy * dy)
        # Moss patches: outside tower radius
        if dist > 3.4 and dist < 4.5 and z > tower_base_z + 1:
            return 'moss'
        # Window recesses
        if dist > 3.0 and dist < 3.8 and z > tower_base_z + 3:
            return 'window'
        # Upper tower
        if z > tower_base_z + tower_height * 0.6:
            return 'stone_light'
        # Mid tower
        if z > tower_base_z + tower_height * 0.25:
            return 'stone_mid'
        # Base
        return 'stone_dark'

    assign_materials_to_faces(tower, tower_mats, classify_tower)

    return tower


def build_rocks():
    """7 sea rocks at cliff base where ocean meets cliff.
    Positioned along the base of the cliff face (y=-16 to -22, z=-1 to 0)."""

    rock_configs = [
        # (x, y, z, radius)
        (-20, -18, -0.5, 3.5),
        (-12, -20, -1.0, 2.8),
        (-5, -19, -0.3, 4.2),
        (3, -21, -1.2, 3.0),
        (10, -18, -0.8, 2.5),
        (18, -20, -1.5, 3.2),
        (8, -22, -1.8, 2.0),
    ]

    rocks = []
    for idx, (rx, ry, rz, rad) in enumerate(rock_configs):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=rad, location=(rx, ry, rz)
        )
        rock = bpy.context.active_object
        rock.name = f"Rock_{idx}"
        # Flatten and shape
        rock.scale.z = random.uniform(0.35, 0.65)
        rock.scale.x = random.uniform(0.85, 1.35)
        rock.scale.y = random.uniform(0.8, 1.2)
        bpy.ops.object.transform_apply(scale=True)

        # Randomize vertices for natural look
        for v in rock.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.35, 0.35)

        rocks.append(rock)

    # Join all into first rock
    main_rock = rocks[0]
    join_objects(main_rock, rocks[1:])
    main_rock.name = "Rocks"

    decimate(main_rock, 0.40)
    shade_flat(main_rock)

    # Single dark rock material
    mat = _make_solid_material("RocksMat", C_ROCK_DARK, roughness=0.9)
    main_rock.data.materials.clear()
    main_rock.data.materials.append(mat)

    return main_rock


def build_crystals():
    """2 crystal clusters near tower at cliff edge:
    Cluster 1: PURPLE (x=12, y=-8) — near tower base
    Cluster 2: TEAL/CYAN (x=8, y=-10) — slightly left
    Tall pointed quartz shapes."""

    all_crystals = []

    clusters = [
        # (center_x, center_y, center_z, count, color, name_prefix)
        (12, -8, 8.0, 5, C_CRYSTAL_PURPLE, "Purple"),
        (8, -10, 7.0, 4, C_CRYSTAL_TEAL, "Teal"),
    ]

    for cx, cy, cz, count, color, prefix in clusters:
        for i in range(count):
            angle = math.radians(i * (360 / count) + random.uniform(-20, 20))
            dist = random.uniform(0.3, 2.0)
            px = cx + math.cos(angle) * dist
            py = cy + math.sin(angle) * dist
            pz = cz + random.uniform(-0.3, 0.3)

            height = random.uniform(2.0, 5.0)
            radius = random.uniform(0.25, 0.7)

            bpy.ops.mesh.primitive_cone_add(
                vertices=6, radius1=radius, radius2=0.04,
                depth=height, location=(px, py, pz + height / 2)
            )
            crystal = bpy.context.active_object
            crystal.name = f"{prefix}Crystal_{i}"

            # Tilt randomly for natural cluster
            crystal.rotation_euler = (
                math.radians(random.uniform(-25, 25)),
                math.radians(random.uniform(-25, 25)),
                math.radians(random.uniform(0, 360)),
            )
            bpy.ops.object.transform_apply(rotation=True)

            # Vertex noise for facets
            for v in crystal.data.vertices:
                v.co += Vector((
                    random.uniform(-0.06, 0.06),
                    random.uniform(-0.06, 0.06),
                    random.uniform(-0.04, 0.04),
                ))

            # Apply emission material per crystal with its cluster color
            emission_col = tuple(c * 1.3 for c in color)
            mat = create_emission_material(
                f"{prefix}CrystalMat_{i}", color, emission_col, 4.0
            )
            crystal.data.materials.clear()
            crystal.data.materials.append(mat)

            all_crystals.append(crystal)

    # Join all into first
    main_crystal = all_crystals[0]
    join_objects(main_crystal, all_crystals[1:])
    main_crystal.name = "CrystalCluster"

    shade_flat(main_crystal)

    return main_crystal


def build_cabin():
    """Small cabin on far-left plateau. Position: (x=-22, y=0, z=plateau_height).
    Plateau height at far left is ~9-10."""

    cabin_x = -22
    cabin_y = 0
    cabin_z = 9.5  # on top of ridge 1

    # Main cabin body
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cabin_x, cabin_y, cabin_z + 1.25))
    cabin = bpy.context.active_object
    cabin.name = "Cabin"
    cabin.scale = (3.5, 2.5, 2.5)
    bpy.ops.object.transform_apply(scale=True)

    parts = []

    # Roof (4-sided cone for pitched roof)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=4.5, radius2=0.2,
        depth=3.0, location=(cabin_x, cabin_y, cabin_z + 4.5)
    )
    roof = bpy.context.active_object
    roof.name = "Roof"
    roof.rotation_euler.z = math.radians(45)
    bpy.ops.object.transform_apply(rotation=True)
    parts.append(roof)

    # Chimney
    bpy.ops.mesh.primitive_cube_add(
        size=1, location=(cabin_x + 1.5, cabin_y - 0.5, cabin_z + 5.5)
    )
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney.scale = (0.5, 0.5, 1.8)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(chimney)

    # Door
    bpy.ops.mesh.primitive_cube_add(
        size=1, location=(cabin_x, cabin_y - 2.6, cabin_z + 0.8)
    )
    door = bpy.context.active_object
    door.name = "Door"
    door.scale = (0.7, 0.1, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(door)

    # Join all
    join_objects(cabin, parts)

    decimate(cabin, 0.6)
    shade_flat(cabin)

    # Multi-material by height
    cabin_mats = {
        'wood': (0.48, 0.33, 0.18),
        'roof': (0.20, 0.16, 0.13),
        'stone': (0.40, 0.38, 0.35),
        'door': (0.12, 0.08, 0.05),
    }
    cabin_zone_mats = {}
    for name, color in cabin_mats.items():
        mat = bpy.data.materials.new(f"Cabin_{name}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
        cabin_zone_mats[name] = mat

    cabin.data.materials.clear()
    for m in cabin_zone_mats.values():
        cabin.data.materials.append(m)

    mat_names = list(cabin_zone_mats.keys())
    for face in cabin.data.polygons:
        avg_z = sum(cabin.data.vertices[vi].co.z for vi in face.vertices) / len(face.vertices)
        if avg_z > cabin_z + 3.5:
            face.material_index = mat_names.index('stone')
        elif avg_z > cabin_z + 2.5:
            face.material_index = mat_names.index('roof')
        else:
            face.material_index = mat_names.index('wood')

    return cabin


def build_ocean():
    """Simple geometric ocean plane for Blender preview.
    Low subdivisions for visible triangle facets, lighter foam near cliff."""
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=12, y_subdivisions=8, size=1, location=(0, -35, -1.5)
    )
    ocean = bpy.context.active_object
    ocean.name = "OceanPreview"
    ocean.scale = (120, 70, 1)
    bpy.ops.object.transform_apply(scale=True)

    # Wave displacement — 2x amplitude for visible facets
    from mathutils import noise as mn
    for v in ocean.data.vertices:
        x_n = v.co.x / 120
        y_n = v.co.y / 70
        wave = math.sin(x_n * 12) * 1.6 + math.sin(y_n * 8 + x_n * 5) * 1.2
        wave += mn.noise(Vector((x_n * 6, y_n * 4, 0))) * 0.8
        v.co.z = wave

    shade_flat(ocean)

    # Dark teal material (deep ocean)
    mat = bpy.data.materials.new("OceanMat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.06, 0.25, 0.45, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.05

    # Lighter foam material for faces near cliff
    foam_mat = bpy.data.materials.new("OceanFoam")
    foam_mat.use_nodes = True
    foam_bsdf = foam_mat.node_tree.nodes["Principled BSDF"]
    foam_bsdf.inputs["Base Color"].default_value = (0.35, 0.55, 0.65, 1.0)
    foam_bsdf.inputs["Roughness"].default_value = 0.4
    foam_bsdf.inputs["Metallic"].default_value = 0.05

    ocean.data.materials.clear()
    ocean.data.materials.append(mat)
    ocean.data.materials.append(foam_mat)

    # Assign foam to faces near cliff (avg vertex y > -25)
    for face in ocean.data.polygons:
        avg_y = sum(ocean.data.vertices[vi].co.y for vi in face.vertices) / len(face.vertices)
        if avg_y > -25:
            face.material_index = 1  # OceanFoam
        else:
            face.material_index = 0  # OceanMat

    # DON'T export this as GLB — it's preview only
    return ocean


def build_sun_mesh():
    """Emissive sun sphere + transparent halo for preview."""
    sun_pos = (30, -20, 22)

    # Core
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=2.5, location=sun_pos)
    core = bpy.context.active_object
    core.name = "SunCore"
    core_mat = bpy.data.materials.new("SunCoreMat")
    core_mat.use_nodes = True
    bsdf = core_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (1.0, 0.95, 0.70, 1.0)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.95, 0.70, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 8.0
    core.data.materials.clear()
    core.data.materials.append(core_mat)

    # Halo (larger, transparent)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=6, location=sun_pos)
    halo = bpy.context.active_object
    halo.name = "SunHalo"
    halo_mat = bpy.data.materials.new("SunHaloMat")
    halo_mat.use_nodes = True
    bsdf_h = halo_mat.node_tree.nodes["Principled BSDF"]
    bsdf_h.inputs["Base Color"].default_value = (1.0, 0.95, 0.75, 1.0)
    bsdf_h.inputs["Emission Color"].default_value = (1.0, 0.95, 0.75, 1.0)
    bsdf_h.inputs["Emission Strength"].default_value = 2.0
    bsdf_h.inputs["Alpha"].default_value = 0.15
    try:
        halo_mat.surface_render_method = 'DITHERED'
    except (AttributeError, TypeError):
        try:
            halo_mat.blend_method = 'BLEND'
        except (AttributeError, TypeError):
            pass
    halo.data.materials.clear()
    halo.data.materials.append(halo_mat)


def build_clouds():
    """5 scattered low-poly cloud puffs in the sky."""
    cloud_mat = bpy.data.materials.new("CloudMat")
    cloud_mat.use_nodes = True
    bsdf = cloud_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.95, 0.97, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Alpha"].default_value = 0.7
    try:
        cloud_mat.surface_render_method = 'DITHERED'
    except (AttributeError, TypeError):
        try:
            cloud_mat.blend_method = 'BLEND'
        except (AttributeError, TypeError):
            pass

    cloud_positions = [
        (-25, -15, 28), (-10, -25, 32), (15, -10, 30), (35, -20, 35), (50, -15, 27)
    ]
    for i, pos in enumerate(cloud_positions):
        # Each cloud = 2-3 overlapping stretched icospheres
        for j in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=1,
                radius=random.uniform(3, 6),
                location=(
                    pos[0] + random.uniform(-2, 2),
                    pos[1] + random.uniform(-1, 1),
                    pos[2] + j * 1.5
                )
            )
            cloud = bpy.context.active_object
            cloud.name = f"Cloud_{i}_{j}"
            cloud.scale = (random.uniform(1.5, 2.5), random.uniform(0.8, 1.2), random.uniform(0.4, 0.7))
            bpy.ops.object.transform_apply(scale=True)
            for v in cloud.data.vertices:
                v.co += v.co.normalized() * random.uniform(-0.3, 0.3)
            shade_flat(cloud)
            cloud.data.materials.clear()
            cloud.data.materials.append(cloud_mat)


def build_vegetation():
    """Dense vegetation on cliff plateau — NOT exported, for preview only."""
    veg_mat = bpy.data.materials.new("VegMat")
    veg_mat.use_nodes = True
    bsdf = veg_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.35, 0.58, 0.20, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85

    # 30 bushes on plateau
    for i in range(30):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=random.uniform(0.5, 1.2),
            location=(random.uniform(-20, 12), random.uniform(-5, 8), 9.0 + random.uniform(0, 0.5))
        )
        bush = bpy.context.active_object
        bush.name = f"VegBush_{i}"
        bush.scale.z = random.uniform(0.5, 0.8)
        shade_flat(bush)
        bush.data.materials.clear()
        bush.data.materials.append(veg_mat)

    # 40 grass tufts
    for i in range(40):
        bpy.ops.mesh.primitive_cone_add(
            vertices=4, radius1=0.08, depth=0.4,
            location=(random.uniform(-22, 14), random.uniform(-6, 9), 9.2)
        )
        grass = bpy.context.active_object
        grass.name = f"Grass_{i}"
        grass.data.materials.clear()
        grass.data.materials.append(veg_mat)


def build_foam():
    """White spray where ocean meets cliff."""
    foam_mat = bpy.data.materials.new("FoamMat")
    foam_mat.use_nodes = True
    bsdf = foam_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.85, 0.90, 0.95, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0

    for i in range(25):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=0, radius=random.uniform(0.2, 0.8),
            location=(random.uniform(-20, 18), random.uniform(-18, -14), random.uniform(-1, 0.5))
        )
        foam = bpy.context.active_object
        foam.name = f"Foam_{i}"
        foam.scale.z = random.uniform(0.3, 0.6)
        shade_flat(foam)
        foam.data.materials.clear()
        foam.data.materials.append(foam_mat)


# =============================================================================
# CAMERA + LIGHTING (Blender preview only — Godot has its own)
# =============================================================================

def setup_camera():
    bpy.ops.object.camera_add(location=(32, -45, 2))  # Balance: close enough for detail, ocean visible
    cam = bpy.context.active_object
    cam.name = "PreviewCamera"
    cam.data.lens = 26  # Wide for drama + ocean foreground
    cam.data.clip_end = 250
    target = Vector((2, -5, 11))  # Slightly lower look-at to show more tower top
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam


def setup_lighting():
    """Golden warm sun, cool fill, bright cyan sky."""
    # Sun — warm golden
    bpy.ops.object.light_add(type='SUN', location=(25, -15, 35))
    sun = bpy.context.active_object
    sun.name = "Sun"
    sun.data.energy = 3.0
    sun.data.color = (1.0, 0.92, 0.70)
    sun.rotation_euler = (
        math.radians(-45), math.radians(12), math.radians(-20)
    )

    # Fill light — cool blue
    bpy.ops.object.light_add(type='SUN', location=(-15, 10, 15))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.5
    fill.data.color = (0.50, 0.60, 0.85)
    fill.rotation_euler = (
        math.radians(-30), math.radians(-150), 0
    )

    # Sky background — bright cyan-blue
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*C_SKY, 1.0)
    bg.inputs["Strength"].default_value = 1.2
    bpy.context.scene.world = world

    # Color management
    bpy.context.scene.view_settings.view_transform = 'Standard'
    bpy.context.scene.view_settings.exposure = 0.0


# =============================================================================
# MAIN
# =============================================================================

def main():
    clear_scene()
    os.makedirs(EXPORT_DIR, exist_ok=True)
    os.makedirs(BLEND_DIR, exist_ok=True)

    print("[MENU SCENE v4] Building cliff (whale-back + 3 ridges)...")
    cliff = build_cliff()
    export_glb(cliff, "cliff_unified.glb")

    bpy.ops.object.select_all(action='DESELECT')

    print("[MENU SCENE v4] Building tower (tall ruined, right edge)...")
    tower = build_tower()
    export_glb(tower, "tower_unified.glb")

    print("[MENU SCENE v4] Building rocks (7 at cliff base)...")
    rocks = build_rocks()
    export_glb(rocks, "rocks_set.glb")

    print("[MENU SCENE v4] Building crystals (purple + teal clusters)...")
    crystals = build_crystals()
    export_glb(crystals, "crystal_cluster_unified.glb")

    print("[MENU SCENE v4] Building cabin (far-left plateau)...")
    cabin = build_cabin()
    export_glb(cabin, "cabin_unified.glb")

    print("[MENU SCENE v4] Building ocean preview...")
    ocean = build_ocean()  # Preview only, not exported as GLB

    print("[MENU SCENE v4] Building sun...")
    build_sun_mesh()

    print("[MENU SCENE v4] Building clouds...")
    build_clouds()

    print("[MENU SCENE v4] Building vegetation (preview only)...")
    build_vegetation()

    print("[MENU SCENE v4] Building foam spray (preview only)...")
    build_foam()

    # Preview setup (Blender only)
    setup_camera()
    setup_lighting()

    # Save .blend
    blend_path = os.path.join(BLEND_DIR, "menu_coast_scene.blend")

    # Force camera view + Material Preview before saving
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'MATERIAL'
                    space.region_3d.view_perspective = 'CAMERA'
                    break
            break

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    # Render preview
    render_path = os.path.join(str(Path.home()), "Downloads", "menu_scene_preview.png")
    bpy.context.scene.render.filepath = render_path
    bpy.context.scene.render.resolution_x = 1920
    bpy.context.scene.render.resolution_y = 1080
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
    bpy.context.scene.eevee.taa_render_samples = 16
    bpy.ops.render.render(write_still=True)

    print(f"[MENU SCENE v4] Rendered: {render_path}")
    print(f"[MENU SCENE v4] Blend saved: {blend_path}")
    print("[MENU SCENE v4] === COMPLETE ===")
    print("[MENU SCENE v4] 5 GLBs exported for Godot integration")


main()
