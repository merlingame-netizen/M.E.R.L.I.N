"""
M.E.R.L.I.N. Menu Coast Scene — Blender Builder v2
Dramatic organic cliff, geometric ocean, ruined celtic tower, low-poly faceted style.
Reference: vibrant pixel-art cliff coast with massive sun, lush vegetation, visible cloud layer.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector, noise

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════
SAVE_DIR = r"c:\Users\PGNK2128\Godot-MCP\assets\blender"
EXPORT_DIR = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast"
RENDER_DIR = r"c:\Users\PGNK2128\Downloads"
random.seed(42)

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def make_mat(name, color, roughness=0.9, metallic=0.0, emission_strength=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_strength > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        mat.blend_method = 'BLEND'
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def assign_mat(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def shade_flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False


def deselect_all():
    bpy.ops.object.select_all(action='DESELECT')


# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALS
# ═══════════════════════════════════════════════════════════════════════════════
def create_materials():
    m = {}
    # Cliff zones
    m['cliff_green'] = make_mat("cliff_green", (0.40, 0.60, 0.28), roughness=0.85)
    m['cliff_green_dark'] = make_mat("cliff_green_dark", (0.18, 0.40, 0.12), roughness=0.9)
    m['cliff_rock'] = make_mat("cliff_rock", (0.45, 0.38, 0.28), roughness=0.95)
    m['cliff_rock_light'] = make_mat("cliff_rock_light", (0.52, 0.45, 0.35), roughness=0.9)
    m['cliff_dark'] = make_mat("cliff_dark", (0.22, 0.20, 0.16), roughness=1.0)
    m['cliff_base'] = make_mat("cliff_base", (0.15, 0.13, 0.10), roughness=1.0)
    # Ocean
    m['ocean'] = make_mat("ocean", (0.10, 0.35, 0.55), roughness=0.4, metallic=0.2)
    m['ocean_deep'] = make_mat("ocean_deep", (0.01, 0.08, 0.20), roughness=0.3, metallic=0.1)
    m['ocean_crest'] = make_mat("ocean_crest", (0.25, 0.50, 0.65), roughness=0.35, metallic=0.15)
    m['foam'] = make_mat("foam", (0.85, 0.90, 0.95), roughness=1.0, emission_strength=0.3)
    # Stone
    m['stone'] = make_mat("stone", (0.35, 0.30, 0.25), roughness=0.95)
    m['stone_dark'] = make_mat("stone_dark", (0.20, 0.18, 0.15), roughness=1.0)
    m['moss'] = make_mat("moss", (0.18, 0.40, 0.12), roughness=1.0)
    # Crystal
    m['crystal_purple'] = make_mat("crystal_purple", (0.55, 0.12, 0.85), roughness=0.15, metallic=0.35, emission_strength=4.0)
    m['crystal_teal'] = make_mat("crystal_teal", (0.10, 0.65, 0.70), roughness=0.15, metallic=0.3, emission_strength=3.5)
    # Vegetation
    m['bush_1'] = make_mat("bush_1", (0.20, 0.45, 0.15), roughness=0.85)
    m['bush_2'] = make_mat("bush_2", (0.28, 0.55, 0.18), roughness=0.85)
    m['bush_3'] = make_mat("bush_3", (0.15, 0.38, 0.12), roughness=0.9)
    m['bush_4'] = make_mat("bush_4", (0.12, 0.32, 0.08), roughness=0.9)
    m['bush_5'] = make_mat("bush_5", (0.35, 0.60, 0.22), roughness=0.85)
    m['grass'] = make_mat("grass", (0.30, 0.58, 0.20), roughness=0.9)
    m['tree_trunk'] = make_mat("tree_trunk", (0.38, 0.28, 0.18), roughness=0.95)
    m['tree_canopy'] = make_mat("tree_canopy", (0.22, 0.48, 0.16), roughness=0.85)
    # Sky objects
    m['cloud'] = make_mat("cloud", (0.95, 0.97, 1.0), roughness=1.0, alpha=0.65)
    m['sun_core'] = make_mat("sun_core", (1.0, 0.90, 0.60), emission_strength=25.0)
    m['sun_halo'] = make_mat("sun_halo", (1.0, 0.92, 0.65), emission_strength=4.0, alpha=0.20)
    m['sun_ring'] = make_mat("sun_ring", (1.0, 0.92, 0.70), emission_strength=2.0, alpha=0.10)
    # Magic
    m['magic_orb'] = make_mat("magic_orb", (0.10, 0.05, 0.15), roughness=0.2, metallic=0.5, emission_strength=1.5)
    m['magic_green'] = make_mat("magic_green", (0.12, 0.90, 0.40), emission_strength=5.0, alpha=0.6)
    # Cabin
    m['wood'] = make_mat("wood", (0.42, 0.34, 0.24), roughness=0.9)
    m['roof'] = make_mat("roof", (0.30, 0.25, 0.18), roughness=0.95)
    m['window'] = make_mat("window", (0.03, 0.02, 0.02), roughness=1.0)
    return m


# ═══════════════════════════════════════════════════════════════════════════════
# TERRAIN — Organic displaced mesh
# ═══════════════════════════════════════════════════════════════════════════════
def build_terrain(mats):
    """Organic cliff using displaced grid — NOT boxes. Plateau top, irregular cliff face, ocean floor."""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=60, y_subdivisions=50, size=1, location=(0, 0, 0))
    terrain = bpy.context.active_object
    terrain.name = "Terrain"
    terrain.scale = (70, 55, 1)
    bpy.ops.object.transform_apply(scale=True)

    # Displace vertices for organic cliff profile
    for v in terrain.data.vertices:
        x_norm = v.co.x / 70.0
        y_norm = v.co.y / 55.0

        # Zone: plateau (y > -0.05), cliff face (-0.05 to -0.30), ocean floor (< -0.30)
        if y_norm > -0.05:
            # Green plateau — high with gentle rolling
            base_h = 8.5
            base_h += noise.noise(Vector((x_norm * 3, y_norm * 3, 0))) * 1.2
            base_h += noise.noise(Vector((x_norm * 7, y_norm * 7, 0.5))) * 0.4
            # Slight slope toward cliff edge
            edge_dist = max(0, (-0.05 - y_norm + 0.15)) / 0.20
            base_h += edge_dist * 0.5

        elif y_norm > -0.30:
            # CLIFF FACE — steep with irregular outcrops, caves, overhangs
            t = (y_norm + 0.30) / 0.25  # 0 at bottom, 1 at top
            base_h = t * 8.5

            # Large-scale irregularity (major outcrops)
            base_h += noise.noise(Vector((x_norm * 5, y_norm * 10, 1.0))) * 3.5
            # Medium detail (rock layers)
            base_h += noise.noise(Vector((x_norm * 12, y_norm * 15, 2.0))) * 1.5
            # Fine detail (cracks and texture)
            base_h += noise.noise(Vector((x_norm * 25, y_norm * 25, 3.0))) * 0.5

            # Cave-like indentations at specific x positions
            cave_factor = math.sin(x_norm * 8) * math.sin(y_norm * 20)
            if cave_factor > 0.6:
                base_h -= 1.5

            base_h = max(-0.3, base_h)

        else:
            # Ocean floor — slightly below zero
            base_h = -0.5 + noise.noise(Vector((x_norm * 4, y_norm * 4, 0))) * 0.3

        v.co.z = base_h

    # Vertex colors for zone-based coloring
    mesh = terrain.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="ZoneColor")

    # Apply multi-material based on height/zone using face materials
    # We'll use 4 materials: green top, rock light, rock dark, base
    mesh.materials.append(mats['cliff_green'])      # 0
    mesh.materials.append(mats['cliff_rock'])        # 1
    mesh.materials.append(mats['cliff_dark'])        # 2
    mesh.materials.append(mats['cliff_base'])        # 3
    mesh.materials.append(mats['cliff_rock_light'])  # 4
    mesh.materials.append(mats['cliff_green_dark'])  # 5

    for poly in mesh.polygons:
        center_z = sum(mesh.vertices[vi].co.z for vi in poly.vertices) / len(poly.vertices)
        center_y = sum(mesh.vertices[vi].co.y for vi in poly.vertices) / len(poly.vertices)
        y_norm = center_y / 55.0

        if center_z > 7.5 and y_norm > -0.10:
            # Plateau top — green with variation
            n_val = noise.noise(Vector((center_y * 0.1, center_z * 0.1, 5.0)))
            poly.material_index = 0 if n_val > -0.2 else 5
        elif center_z > 5.0:
            # Upper cliff — lighter rock with green patches
            n_val = noise.noise(Vector((center_y * 0.15, center_z * 0.15, 6.0)))
            poly.material_index = 4 if n_val > 0.1 else 1
        elif center_z > 2.0:
            # Mid cliff — dark rock
            poly.material_index = 1 if random.random() > 0.3 else 2
        elif center_z > 0:
            # Lower cliff — very dark
            poly.material_index = 2 if random.random() > 0.2 else 3
        else:
            # Base/ocean floor
            poly.material_index = 3

    shade_flat(terrain)

    # Decimate for more faceted look
    mod = terrain.modifiers.new("Decimate", 'DECIMATE')
    mod.ratio = 0.55
    bpy.context.view_layer.objects.active = terrain
    bpy.ops.object.modifier_apply(modifier="Decimate")
    shade_flat(terrain)

    # Additional rock outcrops glued to cliff face for more 3D depth
    for i in range(20):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2,
            radius=random.uniform(1.5, 4.0),
            location=(
                random.uniform(-25, 25),
                random.uniform(-16, -14),
                random.uniform(1, 7)
            )
        )
        outcrop = bpy.context.active_object
        outcrop.name = f"Outcrop_{i}"
        outcrop.scale = (
            random.uniform(0.8, 2.0),
            random.uniform(0.4, 1.0),
            random.uniform(0.5, 1.5)
        )
        # Deform for organic look
        for v in outcrop.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.15, 0.25)
        assign_mat(outcrop, random.choice([mats['cliff_rock'], mats['cliff_dark'], mats['cliff_rock_light']]))
        shade_flat(outcrop)


# ═══════════════════════════════════════════════════════════════════════════════
# OCEAN — Geometric with visible triangle facets
# ═══════════════════════════════════════════════════════════════════════════════
def build_ocean(mats):
    """Low-subdivision ocean for visible triangle facets. Bright teal with crest highlights."""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=15, y_subdivisions=10, size=1, location=(0, -40, -4))
    ocean = bpy.context.active_object
    ocean.name = "Ocean"
    ocean.scale = (140, 80, 1)
    bpy.ops.object.transform_apply(scale=True)

    # Large wave displacement for visible geometric facets
    for v in ocean.data.vertices:
        x_n = v.co.x / 140.0
        y_n = v.co.y / 70.0

        wave = math.sin(x_n * 12) * 2.5
        wave += math.sin(y_n * 8 + x_n * 4) * 2.0
        wave += noise.noise(Vector((x_n * 6, y_n * 5, 0))) * 1.5

        v.co.z = wave

    # Compute average z for crest threshold
    mesh = ocean.data
    avg_z = sum(v.co.z for v in mesh.vertices) / len(mesh.vertices)

    # Three-tone ocean: deep, base, crest
    mesh.materials.append(mats['ocean'])        # 0 — base teal
    mesh.materials.append(mats['ocean_deep'])   # 1 — deep dark
    mesh.materials.append(mats['ocean_crest'])  # 2 — bright crest

    for poly in mesh.polygons:
        center_z = sum(mesh.vertices[vi].co.z for vi in poly.vertices) / len(poly.vertices)
        if center_z > avg_z:
            poly.material_index = 2  # crest
        elif center_z > avg_z - 1.0:
            poly.material_index = 0  # base
        else:
            poly.material_index = 1  # deep

    shade_flat(ocean)

    # Shape key for wave animation
    ocean.shape_key_add(name="Basis")
    sk = ocean.shape_key_add(name="Wave1")
    for i, v in enumerate(sk.data):
        x_n = v.co.x / 140.0
        y_n = v.co.y / 70.0
        v.co.z += math.sin(x_n * 10 + 2.0) * 0.7 + math.cos(y_n * 7 + 1.5) * 0.4
    sk.value = 0.0
    sk.keyframe_insert("value", frame=1)
    sk.value = 1.0
    sk.keyframe_insert("value", frame=60)
    sk.value = 0.0
    sk.keyframe_insert("value", frame=120)


def build_foam(mats):
    """White foam meshes where cliff meets ocean — 30 small icospheres at cliff base."""
    for i in range(30):
        x_pos = random.uniform(-28, 28)
        y_pos = random.uniform(-15, -13)
        z_pos = random.uniform(-1, 1)
        size = random.uniform(0.2, 0.6)

        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=0, radius=size, location=(x_pos, y_pos, z_pos))
        foam = bpy.context.active_object
        foam.name = f"Foam_{i}"
        foam.scale.z = random.uniform(0.3, 0.6)
        assign_mat(foam, mats['foam'])
        shade_flat(foam)


# ═══════════════════════════════════════════════════════════════════════════════
# TOWER — Very tall ruined celtic tower
# ═══════════════════════════════════════════════════════════════════════════════
def build_tower(mats):
    """Celtic ruined tower, ~3x cliff height. Broken pointed top. Orbiting debris and dark orbs."""
    tower_base_z = 8.5  # On top of cliff plateau
    tower_height = 28.0
    tower_center = Vector((0, -5, tower_base_z + tower_height / 2))

    # Main tower body
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=2.2, depth=tower_height, location=tower_center)
    tower = bpy.context.active_object
    tower.name = "Tower"

    # Taper the tower — narrower at top
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(tower.data)
    for v in bm.verts:
        height_ratio = (v.co.z + tower_height / 2) / tower_height  # 0 at bottom, 1 at top
        taper = 1.0 - height_ratio * 0.25
        v.co.x *= taper
        v.co.y *= taper
        # Add noise to stone surface
        offset = noise.noise(Vector((v.co.x * 2, v.co.y * 2, v.co.z * 0.5))) * 0.15
        v.co.x += offset
        v.co.y += offset
    bmesh.update_edit_mesh(tower.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    assign_mat(tower, mats['stone_dark'])
    shade_flat(tower)

    # Broken/pointed top — irregular crenellations
    top_z = tower_base_z + tower_height
    for i in range(10):
        angle = i * math.tau / 10 + random.uniform(-0.1, 0.1)
        r = 1.6 + random.uniform(-0.3, 0.3)
        h = random.uniform(1.0, 4.5)
        bpy.ops.mesh.primitive_cube_add(size=0.5, location=(
            math.cos(angle) * r,
            -5 + math.sin(angle) * r,
            top_z + h * 0.5
        ))
        cren = bpy.context.active_object
        cren.name = f"Crenellation_{i}"
        cren.scale = (0.35, 0.45, h)
        cren.rotation_euler = (
            random.uniform(-0.2, 0.2),
            random.uniform(-0.2, 0.2),
            angle
        )
        assign_mat(cren, mats['stone_dark'] if random.random() > 0.4 else mats['stone'])
        shade_flat(cren)

    # Broken pointed spire at very top
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.5, depth=5, location=(0, -5, top_z + 2.5))
    spire = bpy.context.active_object
    spire.name = "TowerSpire"
    # Break it by removing top half vertices
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(spire.data)
    verts_to_remove = [v for v in bm.verts if v.co.z > 2.0]
    bmesh.ops.delete(bm, geom=verts_to_remove, context='VERTS')
    bmesh.update_edit_mesh(spire.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    assign_mat(spire, mats['stone'])
    shade_flat(spire)

    # Windows (dark slits)
    for i in range(6):
        angle = i * math.pi / 3 + 0.2
        h = tower_base_z + 6 + i * 3.5
        bpy.ops.mesh.primitive_cube_add(size=0.3, location=(
            math.cos(angle) * 2.15, -5 + math.sin(angle) * 2.15, h
        ))
        win = bpy.context.active_object
        win.name = f"Window_{i}"
        win.scale = (0.3, 0.1, 0.8)
        win.rotation_euler.z = angle + math.pi / 2
        assign_mat(win, mats['window'])

    # Moss patches on tower
    for i in range(12):
        angle = random.uniform(0, math.tau)
        h = random.uniform(tower_base_z + 2, tower_base_z + tower_height - 2)
        bpy.ops.mesh.primitive_cube_add(size=0.15, location=(
            math.cos(angle) * 2.25, -5 + math.sin(angle) * 2.25, h
        ))
        mp = bpy.context.active_object
        mp.name = f"TowerMoss_{i}"
        mp.scale = (0.5, random.uniform(0.5, 2.0), random.uniform(0.3, 1.0))
        mp.rotation_euler.z = angle
        assign_mat(mp, mats['moss'])

    # Orbiting stone debris
    for i in range(16):
        angle = random.uniform(0, math.tau)
        dist = random.uniform(3.5, 7)
        h = random.uniform(tower_base_z + 8, tower_base_z + tower_height + 5)
        size = random.uniform(0.25, 0.9)
        bpy.ops.mesh.primitive_cube_add(size=size, location=(
            math.cos(angle) * dist, -5 + math.sin(angle) * dist, h
        ))
        debris = bpy.context.active_object
        debris.name = f"Debris_{i}"
        debris.rotation_euler = (random.uniform(0, 1), random.uniform(0, 1), random.uniform(0, 1))
        assign_mat(debris, mats['stone'])
        shade_flat(debris)

    # Dark magical orbs
    for i in range(8):
        angle = random.uniform(0, math.tau)
        dist = random.uniform(3, 6)
        h = random.uniform(tower_base_z + 12, tower_base_z + tower_height + 3)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=random.uniform(0.3, 0.6),
                                              location=(math.cos(angle) * dist, -5 + math.sin(angle) * dist, h))
        orb = bpy.context.active_object
        orb.name = f"MagicOrb_{i}"
        assign_mat(orb, mats['magic_orb'])


# ═══════════════════════════════════════════════════════════════════════════════
# CRYSTALS — Purple and teal growing from cliff edge
# ═══════════════════════════════════════════════════════════════════════════════
def build_crystals(mats):
    """Clusters of purple/teal crystals on cliff edge."""
    clusters = [
        (5, -9, 8.5, 6),
        (-8, -10, 8.5, 4),
        (12, -8, 8.5, 3),
        (3, -11, 7.0, 5),
    ]
    for ci, (cx, cy, cz, count) in enumerate(clusters):
        crystal_mats = [mats['crystal_purple'], mats['crystal_teal']]
        for i in range(count):
            h = random.uniform(1.5, 5.0)
            bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=random.uniform(0.2, 0.4), depth=h, location=(
                cx + random.uniform(-2, 2),
                cy + random.uniform(-1.5, 1.5),
                cz + h * 0.5
            ))
            crystal = bpy.context.active_object
            crystal.name = f"Crystal_{ci}_{i}"
            crystal.rotation_euler = (
                random.uniform(-0.3, 0.3),
                random.uniform(-0.25, 0.25),
                random.uniform(0, math.tau)
            )
            assign_mat(crystal, random.choice(crystal_mats))
            shade_flat(crystal)


# ═══════════════════════════════════════════════════════════════════════════════
# MENHIRS — Standing stones on cliff top
# ═══════════════════════════════════════════════════════════════════════════════
def build_menhirs(mats):
    positions = [
        (8, -3, 8.5), (-6, 2, 8.5), (14, -7, 8.5), (-12, -5, 8.5),
        (5, 6, 8.5), (-3, -8, 8.5), (18, 1, 8.5), (-16, 3, 8.5),
        (10, 4, 8.5), (-9, -2, 8.5)
    ]
    for i, (px, py, pz) in enumerate(positions):
        h = random.uniform(2.5, 6.5)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(px, py, pz + h / 2))
        stone = bpy.context.active_object
        stone.name = f"Menhir_{i}"
        stone.scale = (random.uniform(0.3, 0.5), random.uniform(0.25, 0.4), h)
        bpy.ops.object.transform_apply(scale=True)

        # Taper top
        bpy.ops.object.mode_set(mode='EDIT')
        bm = bmesh.from_edit_mesh(stone.data)
        for v in bm.verts:
            if v.co.z > h * 0.4:
                factor = 1.0 - (v.co.z / h) * 0.45
                v.co.x *= factor
                v.co.y *= factor
        bmesh.update_edit_mesh(stone.data)
        bpy.ops.object.mode_set(mode='OBJECT')

        stone.rotation_euler = (
            random.uniform(-0.1, 0.1),
            random.uniform(-0.1, 0.1),
            random.uniform(0, math.tau)
        )
        assign_mat(stone, mats['stone_dark'])
        shade_flat(stone)


# ═══════════════════════════════════════════════════════════════════════════════
# VEGETATION — Dense bushes, grass tufts, trees
# ═══════════════════════════════════════════════════════════════════════════════
def build_vegetation(mats):
    """Lush dense vegetation: 120 bushes, grass tufts, 20 trees — plateau only (z>7, y>-10)."""
    bush_mats = [mats['bush_1'], mats['bush_2'], mats['bush_3'], mats['bush_4'], mats['bush_5']]

    # Bushes — 120 scattered on plateau
    for i in range(120):
        r = random.uniform(0.39, 1.82)
        px = random.uniform(-22, 22)
        py = random.uniform(-9, 12)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(px, py, 8.5 + r * 0.3))
        bush = bpy.context.active_object
        bush.name = f"Bush_{i}"
        bush.scale.z = random.uniform(0.4, 0.75)
        for v in bush.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.12, 0.18)
        assign_mat(bush, random.choice(bush_mats))
        shade_flat(bush)

    # Grass tufts — thin cones pointing up along cliff edge
    for i in range(80):
        px = random.uniform(-22, 22)
        py = random.uniform(-9, -6)
        h = random.uniform(0.5, 1.8)
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.12, depth=h, location=(px, py, 8.5 + h * 0.5))
        grass = bpy.context.active_object
        grass.name = f"Grass_{i}"
        grass.rotation_euler = (random.uniform(-0.15, 0.15), random.uniform(-0.15, 0.15), random.uniform(0, math.tau))
        assign_mat(grass, mats['grass'])
        shade_flat(grass)

    # Trees — 20 small trees (thin cylinder trunk + icosphere canopy) on plateau
    for i in range(20):
        tx = random.uniform(-22, 22)
        ty = random.uniform(-8, 12)
        tz = 8.5
        trunk_h = random.uniform(2.0, 4.0)
        # Trunk
        bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.15, depth=trunk_h,
                                             location=(tx, ty, tz + trunk_h / 2))
        trunk = bpy.context.active_object
        trunk.name = f"TreeTrunk_{i}"
        assign_mat(trunk, mats['tree_trunk'])
        shade_flat(trunk)
        # Canopy
        canopy_r = random.uniform(1.0, 2.2)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=canopy_r,
                                               location=(tx, ty, tz + trunk_h + canopy_r * 0.5))
        canopy = bpy.context.active_object
        canopy.name = f"TreeCanopy_{i}"
        canopy.scale.z = random.uniform(0.6, 0.9)
        for v in canopy.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.15, 0.2)
        assign_mat(canopy, mats['tree_canopy'])
        shade_flat(canopy)


# ═══════════════════════════════════════════════════════════════════════════════
# SEA ROCKS
# ═══════════════════════════════════════════════════════════════════════════════
def build_sea_rocks(mats):
    positions = [
        (22, -22, -1), (-18, -28, -1.5), (12, -35, -1), (-22, -32, -0.5),
        (28, -40, -1.2), (-10, -20, -0.8), (30, -30, -0.3), (-25, -25, -1.0)
    ]
    for i, pos in enumerate(positions):
        r = random.uniform(1.5, 4.0)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=pos)
        rock = bpy.context.active_object
        rock.name = f"SeaRock_{i}"
        rock.scale.z = random.uniform(0.4, 0.7)
        for v in rock.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.25, 0.25)
        assign_mat(rock, mats['stone_dark'])
        shade_flat(rock)


# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDS — Visible scattered shapes against blue sky
# ═══════════════════════════════════════════════════════════════════════════════
def build_clouds(mats):
    """Larger clouds positioned where camera can see them."""
    cloud_specs = [
        # (x, y, z, radius, x_scale)
        (-15, -25, 22, 7, 2.5),
        (5, -35, 28, 8, 3.0),
        (25, -45, 24, 6, 2.0),
        (40, -30, 30, 10, 2.8),
        (-10, -20, 26, 7, 2.2),
        (30, -50, 25, 9, 3.5),
        (-5, -40, 32, 8, 2.5),
        (15, -25, 29, 6, 2.0),
        (35, -28, 27, 7, 2.3),
        (-18, -38, 30, 8, 2.8),
        (10, -55, 20, 9, 3.0),
        (38, -22, 24, 6, 2.0),
        (-12, -48, 28, 7, 2.5),
        (20, -33, 31, 8, 2.8),
    ]
    for i, (cx, cy, cz, r, xs) in enumerate(cloud_specs):
        # Each cloud = 2-3 overlapping icospheres
        for j in range(random.randint(2, 3)):
            offset_x = random.uniform(-r * 0.5, r * 0.5)
            offset_z = random.uniform(-r * 0.15, r * 0.15)
            sub_r = r * random.uniform(0.5, 0.9)
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=sub_r,
                                                   location=(cx + offset_x, cy, cz + offset_z))
            cloud = bpy.context.active_object
            cloud.name = f"Cloud_{i}_{j}"
            cloud.scale = (xs * random.uniform(0.8, 1.2), random.uniform(0.7, 1.0), random.uniform(0.35, 0.55))
            for v in cloud.data.vertices:
                v.co += v.co.normalized() * random.uniform(-0.2, 0.3)
            assign_mat(cloud, mats['cloud'])
            shade_flat(cloud)


# ═══════════════════════════════════════════════════════════════════════════════
# SUN — Massive and bright, dominates right side
# ═══════════════════════════════════════════════════════════════════════════════
def build_sun(mats):
    """Massive sun with intense core, halo, and outer ring."""
    # Camera at (30,-50,3) looking at (-2,-10,12)
    # Screen-right = positive X direction from camera perspective
    # Sun visible upper-right: between camera and target but offset right+up
    # Upper-right of frame: partially visible, bright glow
    sun_pos = (32, 5, 28)

    # Core — bright emissive sphere
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=6, location=sun_pos)
    core = bpy.context.active_object
    core.name = "SunCore"
    assign_mat(core, mats['sun_core'])

    # Inner halo
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=14, location=sun_pos)
    halo1 = bpy.context.active_object
    halo1.name = "SunHalo1"
    assign_mat(halo1, mats['sun_halo'])

    # Outer halo ring
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=22, location=sun_pos)
    halo2 = bpy.context.active_object
    halo2.name = "SunHalo2"
    assign_mat(halo2, mats['sun_ring'])


# ═══════════════════════════════════════════════════════════════════════════════
# CABIN — Small, on cliff top
# ═══════════════════════════════════════════════════════════════════════════════
def build_cabin(mats):
    cx, cy, cz = -15, 2, 8.5
    # Base
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz + 0.8))
    base = bpy.context.active_object
    base.name = "CabinBase"
    base.scale = (2.0, 1.5, 1.2)
    assign_mat(base, mats['wood'])
    shade_flat(base)
    # Roof
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.6, depth=1.0, location=(cx, cy, cz + 2.0))
    roof = bpy.context.active_object
    roof.name = "CabinRoof"
    roof.scale = (1.0, 0.8, 1.0)
    roof.rotation_euler.z = math.pi / 4
    assign_mat(roof, mats['roof'])
    shade_flat(roof)
    # Chimney
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(cx + 0.7, cy, cz + 2.5))
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney.scale = (1, 1, 2.5)
    assign_mat(chimney, mats['stone'])
    # Door
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(cx, cy - 1.5, cz + 0.5))
    door = bpy.context.active_object
    door.name = "Door"
    door.scale = (0.5, 0.05, 0.8)
    assign_mat(door, mats['window'])


# ═══════════════════════════════════════════════════════════════════════════════
# CAMERA — Low, wide, dramatic angle
# ═══════════════════════════════════════════════════════════════════════════════
def setup_camera():
    # More to the side to see cliff face prominently
    bpy.ops.object.camera_add(location=(30, -45, 5))
    cam = bpy.context.active_object
    cam.name = "MenuCamera"
    cam.data.lens = 28  # Wider angle to capture more scene
    cam.data.clip_end = 400

    # Look at cliff face mid-height for prominent visibility
    target = Vector((-2, -8, 10))
    direction = target - cam.location
    rot = direction.to_track_quat('-Z', 'Y')
    cam.rotation_euler = rot.to_euler()

    bpy.context.scene.camera = cam


# ═══════════════════════════════════════════════════════════════════════════════
# LIGHTING — Vivid blue sky, warm sun
# ═══════════════════════════════════════════════════════════════════════════════
def setup_lighting():
    # Main sun light
    bpy.ops.object.light_add(type='SUN', location=(20, -20, 30))
    sun = bpy.context.active_object
    sun.name = "SunLight"
    sun.data.energy = 3.0
    sun.data.color = (1.0, 0.95, 0.82)
    sun.rotation_euler = (math.radians(-50), math.radians(15), math.radians(-25))

    # Fill light — blue tint
    bpy.ops.object.light_add(type='SUN', location=(-10, 10, 15))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.2
    fill.data.color = (0.50, 0.60, 0.85)
    fill.rotation_euler = (math.radians(-30), math.radians(-150), 0)

    # Rim light from sun side
    bpy.ops.object.light_add(type='SUN', location=(40, -30, 35))
    rim = bpy.context.active_object
    rim.name = "RimLight"
    rim.data.energy = 2.0
    rim.data.color = (1.0, 0.90, 0.70)
    rim.rotation_euler = (math.radians(-40), math.radians(30), math.radians(-20))

    # World: VIVID CYAN-BLUE sky
    world = bpy.data.worlds.new("MenuWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.18, 0.45, 0.85, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    bpy.context.scene.world = world

    # Color management — Standard for saturated pixel-art look
    bpy.context.scene.view_settings.view_transform = 'Standard'
    bpy.context.scene.view_settings.look = 'None'
    bpy.context.scene.view_settings.exposure = -0.5
    bpy.context.scene.view_settings.gamma = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# RENDER SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════
def setup_render():
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.frame_start = 1
    scene.frame_end = 120
    scene.render.fps = 30
    scene.eevee.taa_render_samples = 64


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    clear_scene()
    mats = create_materials()

    steps = [
        ("terrain", lambda: build_terrain(mats)),
        ("ocean", lambda: build_ocean(mats)),
        ("foam", lambda: build_foam(mats)),
        ("tower", lambda: build_tower(mats)),
        ("crystals", lambda: build_crystals(mats)),
        ("menhirs", lambda: build_menhirs(mats)),
        ("cabin", lambda: build_cabin(mats)),
        ("vegetation", lambda: build_vegetation(mats)),
        ("sea rocks", lambda: build_sea_rocks(mats)),
        ("clouds", lambda: build_clouds(mats)),
        ("sun", lambda: build_sun(mats)),
    ]

    for name, fn in steps:
        print(f"[MENU SCENE] Building {name}...")
        fn()

    print("[MENU SCENE] Setting up camera...")
    setup_camera()
    print("[MENU SCENE] Setting up lighting...")
    setup_lighting()
    print("[MENU SCENE] Setting up render...")
    setup_render()

    # Shade ALL objects flat
    bpy.ops.object.select_all(action='SELECT')
    try:
        bpy.ops.object.shade_flat()
    except Exception:
        pass
    bpy.ops.object.select_all(action='DESELECT')

    # Save .blend
    os.makedirs(SAVE_DIR, exist_ok=True)
    blend_path = os.path.join(SAVE_DIR, "menu_coast_scene.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[MENU SCENE] Saved: {blend_path}")

    # Export GLB
    os.makedirs(EXPORT_DIR, exist_ok=True)
    glb_path = os.path.join(EXPORT_DIR, "menu_scene_v3.glb")
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True)
    print(f"[MENU SCENE] Exported: {glb_path}")

    # RENDER PREVIEW PNG
    os.makedirs(RENDER_DIR, exist_ok=True)
    render_path = os.path.join(RENDER_DIR, "menu_scene_preview.png")
    bpy.context.scene.render.filepath = render_path
    bpy.ops.render.render(write_still=True)
    print(f"[MENU SCENE] Rendered: {render_path}")

    # Force camera view + material preview in viewport
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'MATERIAL'
                    space.region_3d.view_perspective = 'CAMERA'
                    break

    print("[MENU SCENE] === COMPLETE ===")

main()
