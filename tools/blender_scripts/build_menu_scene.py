"""
M.E.R.L.I.N. Menu Coast Scene — Blender Builder
Dramatic cliff face with ruined celtic tower, low-poly faceted style.
"""

import bpy
import bmesh
import math
import random
import os
from mathutils import Vector, noise

random.seed(42)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BLEND_PATH = "c:/Users/PGNK2128/Godot-MCP/assets/blender/menu_coast_scene.blend"
GLB_PATH = "c:/Users/PGNK2128/Godot-MCP/assets/3d_models/menu_coast/menu_scene_complete.glb"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def create_material(name, color, roughness=0.9, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1.0:
        mat.blend_method = 'BLEND'
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def set_flat_shading(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False


def add_to_collection(obj, col_name):
    if col_name not in bpy.data.collections:
        col = bpy.data.collections.new(col_name)
        bpy.context.scene.collection.children.link(col)
    col = bpy.data.collections[col_name]
    # Unlink from scene collection if present
    if obj.name in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.unlink(obj)
    col.objects.link(obj)


# ---------------------------------------------------------------------------
# Materials dict
# ---------------------------------------------------------------------------
MATS = {}

def create_all_materials():
    global MATS
    MATS = {
        'cliff_top':    create_material('cliff_top',    (0.35, 0.45, 0.25), 0.9),
        'cliff_face':   create_material('cliff_face',   (0.38, 0.32, 0.24), 0.95),
        'cliff_base':   create_material('cliff_base',   (0.25, 0.22, 0.18), 0.95),
        'stone':        create_material('stone',        (0.35, 0.33, 0.28), 0.95),
        'moss':         create_material('moss',         (0.18, 0.35, 0.12), 1.0),
        'ocean':        create_material('ocean',        (0.05, 0.18, 0.35), 0.3, alpha=0.85),
        'crystal':      create_material('crystal',      (0.55, 0.15, 0.85), 0.4, emission=2.0),
        'wood':         create_material('wood',         (0.40, 0.32, 0.22), 0.9),
        'window_dark':  create_material('window_dark',  (0.05, 0.04, 0.03), 1.0),
        'cloud':        create_material('cloud',        (0.95, 0.97, 1.0),  0.8, alpha=0.4),
        'sun_glow':     create_material('sun_glow',     (1.0, 0.95, 0.7),   0.5, emission=5.0),
        'sun_halo':     create_material('sun_halo',     (1.0, 0.92, 0.65),  0.5, emission=1.5, alpha=0.15),
        'vegetation_1': create_material('vegetation_1', (0.28, 0.42, 0.18), 0.95),
        'vegetation_2': create_material('vegetation_2', (0.22, 0.38, 0.15), 0.95),
        'vegetation_3': create_material('vegetation_3', (0.32, 0.50, 0.22), 0.95),
        'rock_dark':    create_material('rock_dark',    (0.22, 0.20, 0.18), 0.95),
        'roof':         create_material('roof',         (0.30, 0.25, 0.20), 0.95),
        'door':         create_material('door',         (0.12, 0.10, 0.08), 1.0),
        'chimney_smoke': create_material('chimney_smoke', (0.6, 0.6, 0.62), 0.8, alpha=0.25),
        'particle':     create_material('particle',     (0.8, 0.9, 1.0), 0.5, emission=1.0, alpha=0.5),
    }


# ---------------------------------------------------------------------------
# 1. TERRAIN
# ---------------------------------------------------------------------------
def build_terrain():
    verts = []
    faces = []
    sx, sy = 80, 60
    nx, ny = 40, 30

    for iy in range(ny + 1):
        for ix in range(nx + 1):
            x = (ix / nx - 0.5) * sx
            y = (iy / ny - 0.5) * sy
            # Normalized coords
            ny_norm = iy / ny  # 0=front(ocean), 1=back

            # Height logic
            cliff_threshold = 0.45
            if ny_norm > cliff_threshold + 0.05:
                # Cliff top — high plateau
                h = 9.0
                n = noise.noise(Vector((x * 0.08, y * 0.08, 0))) * 1.2
                h += n
            elif ny_norm > cliff_threshold - 0.05:
                # Cliff edge — steep transition
                t = (ny_norm - (cliff_threshold - 0.05)) / 0.1
                h = t * 9.0
                n = noise.noise(Vector((x * 0.15, y * 0.15, 1.0))) * 1.5
                h += n * (1.0 - t)
            else:
                # Ocean floor
                h = -0.5
                n = noise.noise(Vector((x * 0.05, y * 0.05, 2.0))) * 0.3
                h += n

            verts.append((x, y, h))

    for iy in range(ny):
        for ix in range(nx):
            i = iy * (nx + 1) + ix
            faces.append((i, i + 1, i + nx + 2, i + nx + 1))

    mesh = bpy.data.meshes.new("Terrain")
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    obj = bpy.data.objects.new("Terrain", mesh)
    bpy.context.scene.collection.objects.link(obj)

    # Vertex colors for material zones
    # Use two materials: cliff_top for top, cliff_face for face
    obj.data.materials.append(MATS['cliff_top'])
    obj.data.materials.append(MATS['cliff_face'])
    obj.data.materials.append(MATS['cliff_base'])

    for poly in obj.data.polygons:
        center_z = sum(verts[vi][2] for vi in poly.vertices) / len(poly.vertices)
        if center_z > 6.0:
            poly.material_index = 0  # green top
        elif center_z > 1.0:
            poly.material_index = 1  # brown cliff
        else:
            poly.material_index = 2  # dark base

    set_flat_shading(obj)
    add_to_collection(obj, "Terrain")
    return obj


# ---------------------------------------------------------------------------
# 2. OCEAN
# ---------------------------------------------------------------------------
def build_ocean():
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=60, y_subdivisions=40,
        size=1, location=(0, -5, -1)
    )
    obj = bpy.context.active_object
    obj.name = "Ocean"
    obj.scale = (60, 40, 1)
    bpy.ops.object.transform_apply(scale=True)

    # Base wave displacement
    mesh = obj.data
    basis_key = obj.shape_key_add(name="Basis")

    for sk_idx in range(3):
        sk = obj.shape_key_add(name=f"Wave_{sk_idx}")
        freq = 0.12 + sk_idx * 0.06
        amp = 0.3 + sk_idx * 0.15
        phase = sk_idx * 1.5
        for i, v in enumerate(sk.data):
            orig = basis_key.data[i].co
            wave = math.sin(orig.x * freq + phase) * math.cos(orig.y * freq * 0.7 + phase * 0.5)
            n = noise.noise(Vector((orig.x * 0.05 + phase, orig.y * 0.05, sk_idx))) * 0.5
            v.co = orig.copy()
            v.co.z = orig.z + (wave + n) * amp

    # Animate shape keys
    for sk_idx in range(3):
        sk = obj.data.shape_keys.key_blocks[sk_idx + 1]
        sk.value = 0.0
        sk.keyframe_insert("value", frame=1)
        sk.value = 1.0
        sk.keyframe_insert("value", frame=30 + sk_idx * 20)
        sk.value = 0.0
        sk.keyframe_insert("value", frame=60 + sk_idx * 20)

    # Loop animation
    if obj.data.shape_keys.animation_data and obj.data.shape_keys.animation_data.action:
        for fc in obj.data.shape_keys.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'SINUSOIDAL' if hasattr(kp, 'SINUSOIDAL') else 'BEZIER'
            fc.modifiers.new(type='CYCLES')

    obj.data.materials.append(MATS['ocean'])
    set_flat_shading(obj)
    add_to_collection(obj, "Ocean")
    return obj


# ---------------------------------------------------------------------------
# 3. CELTIC TOWER
# ---------------------------------------------------------------------------
def build_tower():
    tower_x, tower_y = 0, 8
    tower_base_z = 9.0
    objects = []

    # Main cylinder
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=2, depth=15,
        location=(tower_x, tower_y, tower_base_z + 7.5)
    )
    tower = bpy.context.active_object
    tower.name = "Tower_Main"
    tower.data.materials.append(MATS['stone'])
    set_flat_shading(tower)
    objects.append(tower)

    # Broken crenellations
    for i in range(6):
        angle = i * math.pi * 2 / 6
        cx = tower_x + math.cos(angle) * 1.8
        cy = tower_y + math.sin(angle) * 1.8
        h = random.uniform(0.8, 2.0)
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(cx, cy, tower_base_z + 15 + h / 2)
        )
        cren = bpy.context.active_object
        cren.name = f"Crenellation_{i}"
        cren.scale = (0.6, 0.6, h)
        bpy.ops.object.transform_apply(scale=True)
        cren.data.materials.append(MATS['stone'])
        set_flat_shading(cren)
        objects.append(cren)

    # Window recesses
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 4
        wx = tower_x + math.cos(angle) * 2.05
        wy = tower_y + math.sin(angle) * 2.05
        wz = tower_base_z + 10 + i * 1.5
        bpy.ops.mesh.primitive_cube_add(size=1, location=(wx, wy, wz))
        win = bpy.context.active_object
        win.name = f"Window_{i}"
        win.scale = (0.3, 0.3, 0.5)
        bpy.ops.object.transform_apply(scale=True)
        win.data.materials.append(MATS['window_dark'])
        set_flat_shading(win)
        objects.append(win)

    # Moss patches
    for i in range(6):
        angle = random.uniform(0, math.pi * 2)
        mz = tower_base_z + random.uniform(3, 12)
        mx = tower_x + math.cos(angle) * 2.05
        my = tower_y + math.sin(angle) * 2.05
        bpy.ops.mesh.primitive_cube_add(size=1, location=(mx, my, mz))
        mp = bpy.context.active_object
        mp.name = f"Moss_{i}"
        mp.scale = (0.4, 0.4, 0.15)
        bpy.ops.object.transform_apply(scale=True)
        mp.data.materials.append(MATS['moss'])
        set_flat_shading(mp)
        objects.append(mp)

    # Floating stone debris
    for i in range(8):
        angle = random.uniform(0, math.pi * 2)
        dist = random.uniform(3.5, 6.0)
        dz = tower_base_z + random.uniform(8, 18)
        dx = tower_x + math.cos(angle) * dist
        dy = tower_y + math.sin(angle) * dist
        sz = random.uniform(0.2, 0.6)
        bpy.ops.mesh.primitive_cube_add(size=sz, location=(dx, dy, dz))
        debris = bpy.context.active_object
        debris.name = f"Debris_{i}"
        debris.rotation_euler = (
            random.uniform(0, math.pi),
            random.uniform(0, math.pi),
            random.uniform(0, math.pi),
        )
        debris.data.materials.append(MATS['stone'])
        set_flat_shading(debris)
        objects.append(debris)

        # Animate orbit
        debris.keyframe_insert("location", frame=1)
        debris.location = (
            tower_x + math.cos(angle + math.pi * 0.3) * dist,
            tower_y + math.sin(angle + math.pi * 0.3) * dist,
            dz + random.uniform(-0.5, 0.5),
        )
        debris.keyframe_insert("location", frame=120)
        if debris.animation_data and debris.animation_data.action:
            for fc in debris.animation_data.action.fcurves:
                fc.modifiers.new(type='CYCLES')

    for o in objects:
        add_to_collection(o, "Tower")


# ---------------------------------------------------------------------------
# 4. CABIN
# ---------------------------------------------------------------------------
def build_cabin():
    cx, cy, cz = -15, 10, 9.0
    objects = []

    # Base
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz + 0.4))
    base = bpy.context.active_object
    base.name = "Cabin_Base"
    base.scale = (1.5, 1.0, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    base.data.materials.append(MATS['wood'])
    set_flat_shading(base)
    objects.append(base)

    # Roof
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.3, depth=0.8,
                                     location=(cx, cy, cz + 1.2))
    roof = bpy.context.active_object
    roof.name = "Cabin_Roof"
    roof.scale.y = 0.7
    bpy.ops.object.transform_apply(scale=True)
    roof.data.materials.append(MATS['roof'])
    set_flat_shading(roof)
    objects.append(roof)

    # Chimney
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx + 0.5, cy, cz + 1.6))
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney.scale = (0.2, 0.2, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    chimney.data.materials.append(MATS['stone'])
    set_flat_shading(chimney)
    objects.append(chimney)

    # Smoke puffs
    for i in range(4):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=0.25 + i * 0.1,
            location=(cx + 0.5 + random.uniform(-0.2, 0.2),
                      cy + random.uniform(-0.1, 0.1),
                      cz + 2.0 + i * 0.5)
        )
        smoke = bpy.context.active_object
        smoke.name = f"Smoke_{i}"
        smoke.data.materials.append(MATS['chimney_smoke'])
        set_flat_shading(smoke)
        objects.append(smoke)

    # Door
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy - 0.51, cz + 0.25))
    door = bpy.context.active_object
    door.name = "Cabin_Door"
    door.scale = (0.3, 0.05, 0.45)
    bpy.ops.object.transform_apply(scale=True)
    door.data.materials.append(MATS['door'])
    set_flat_shading(door)
    objects.append(door)

    for o in objects:
        add_to_collection(o, "Cabin")


# ---------------------------------------------------------------------------
# 5. STANDING STONES
# ---------------------------------------------------------------------------
def build_menhirs():
    positions = [
        (5, 12, 9.0), (-5, 11, 9.0), (8, 14, 9.2),
        (-8, 13, 9.0), (3, 15, 9.1), (-3, 9, 9.0), (10, 10, 9.0),
    ]
    for i, (mx, my, mz) in enumerate(positions):
        h = random.uniform(3, 5)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(mx, my, mz + h / 2))
        stone = bpy.context.active_object
        stone.name = f"Menhir_{i}"
        stone.scale = (0.5, 0.3, h)
        # Taper top
        bpy.ops.object.transform_apply(scale=True)
        bm = bmesh.new()
        bm.from_mesh(stone.data)
        bm.verts.ensure_lookup_table()
        for v in bm.verts:
            if v.co.z > h * 0.6:
                factor = 1.0 - (v.co.z - h * 0.6) / (h * 0.5)
                factor = max(factor, 0.3)
                v.co.x *= factor
                v.co.y *= factor
        bm.to_mesh(stone.data)
        bm.free()

        stone.rotation_euler.x = random.uniform(-0.08, 0.08)
        stone.rotation_euler.y = random.uniform(-0.08, 0.08)
        stone.data.materials.append(MATS['stone'])
        set_flat_shading(stone)
        add_to_collection(stone, "Menhirs")


# ---------------------------------------------------------------------------
# 6. CRYSTALS
# ---------------------------------------------------------------------------
def build_crystals():
    cluster_x, cluster_y, cluster_z = 3, 6, 9.0
    for i in range(6):
        h = random.uniform(1.0, 3.0)
        r = random.uniform(0.15, 0.35)
        ox = random.uniform(-1.0, 1.0)
        oy = random.uniform(-1.0, 1.0)
        bpy.ops.mesh.primitive_cone_add(
            vertices=6, radius1=r, depth=h,
            location=(cluster_x + ox, cluster_y + oy, cluster_z + h / 2)
        )
        crystal = bpy.context.active_object
        crystal.name = f"Crystal_{i}"
        crystal.rotation_euler = (
            random.uniform(-0.3, 0.3),
            random.uniform(-0.3, 0.3),
            random.uniform(0, math.pi),
        )
        crystal.data.materials.append(MATS['crystal'])
        set_flat_shading(crystal)
        add_to_collection(crystal, "Crystals")


# ---------------------------------------------------------------------------
# 7. VEGETATION
# ---------------------------------------------------------------------------
def build_vegetation():
    veg_mats = [MATS['vegetation_1'], MATS['vegetation_2'], MATS['vegetation_3']]
    for i in range(35):
        x = random.uniform(-30, 30)
        y = random.uniform(7, 25)
        z = 9.0 + random.uniform(-0.3, 0.5)
        r = random.uniform(0.3, 1.0)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=r,
            location=(x, y, z)
        )
        bush = bpy.context.active_object
        bush.name = f"Vegetation_{i}"
        bush.scale.z = random.uniform(0.4, 1.0)
        bpy.ops.object.transform_apply(scale=True)
        bush.data.materials.append(random.choice(veg_mats))
        set_flat_shading(bush)
        add_to_collection(bush, "Vegetation")


# ---------------------------------------------------------------------------
# 8. SEA ROCKS
# ---------------------------------------------------------------------------
def build_sea_rocks():
    positions = [
        (15, -18, -0.5), (-12, -20, -0.3), (25, -15, -0.7),
        (-20, -22, -0.4), (5, -25, -0.6),
    ]
    for i, (rx, ry, rz) in enumerate(positions):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=random.uniform(1.0, 2.5),
            location=(rx, ry, rz)
        )
        rock = bpy.context.active_object
        rock.name = f"SeaRock_{i}"
        # Randomize vertices for rocky look
        bm = bmesh.new()
        bm.from_mesh(rock.data)
        for v in bm.verts:
            v.co += Vector((
                random.uniform(-0.3, 0.3),
                random.uniform(-0.3, 0.3),
                random.uniform(-0.2, 0.2),
            ))
        bm.to_mesh(rock.data)
        bm.free()
        rock.data.materials.append(MATS['rock_dark'])
        set_flat_shading(rock)
        add_to_collection(rock, "SeaRocks")


# ---------------------------------------------------------------------------
# 9. CLOUDS
# ---------------------------------------------------------------------------
def build_clouds():
    for i in range(10):
        x = random.uniform(-40, 40)
        y = random.uniform(10, 40)
        z = random.uniform(18, 28)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=1, radius=random.uniform(2.0, 5.0),
            location=(x, y, z)
        )
        cloud = bpy.context.active_object
        cloud.name = f"Cloud_{i}"
        cloud.scale = (
            random.uniform(1.5, 3.0),
            random.uniform(0.8, 1.5),
            random.uniform(0.4, 0.8),
        )
        bpy.ops.object.transform_apply(scale=True)
        # Randomize verts
        bm = bmesh.new()
        bm.from_mesh(cloud.data)
        for v in bm.verts:
            v.co += Vector((
                random.uniform(-0.8, 0.8),
                random.uniform(-0.5, 0.5),
                random.uniform(-0.3, 0.3),
            ))
        bm.to_mesh(cloud.data)
        bm.free()
        cloud.data.materials.append(MATS['cloud'])
        set_flat_shading(cloud)
        add_to_collection(cloud, "Clouds")


# ---------------------------------------------------------------------------
# 10. SUN
# ---------------------------------------------------------------------------
def build_sun():
    sun_x, sun_y, sun_z = 20, 30, 25

    # Bright core
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=1.5,
        location=(sun_x, sun_y, sun_z)
    )
    sun_core = bpy.context.active_object
    sun_core.name = "Sun_Core"
    sun_core.data.materials.append(MATS['sun_glow'])
    set_flat_shading(sun_core)
    add_to_collection(sun_core, "Sun")

    # Glow halo
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16, ring_count=10, radius=5.0,
        location=(sun_x, sun_y, sun_z)
    )
    halo = bpy.context.active_object
    halo.name = "Sun_Halo"
    halo.data.materials.append(MATS['sun_halo'])
    add_to_collection(halo, "Sun")


# ---------------------------------------------------------------------------
# 11. MAGIC PARTICLES
# ---------------------------------------------------------------------------
def build_particles():
    for i in range(20):
        x = random.uniform(-5, 5)
        y = random.uniform(5, 15)
        z = random.uniform(10, 20)
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=0, radius=0.08,
            location=(x, y, z)
        )
        p = bpy.context.active_object
        p.name = f"Particle_{i}"
        p.data.materials.append(MATS['particle'])
        add_to_collection(p, "Particles")


# ---------------------------------------------------------------------------
# 12. CAMERA
# ---------------------------------------------------------------------------
def setup_camera():
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 50
    cam_data.clip_end = 500
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    cam_obj.location = (35, -30, 3)

    # Point at tower top
    target_pos = Vector((0, 8, 12))
    direction = target_pos - cam_obj.location
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam_obj.rotation_euler = rot_quat.to_euler()


# ---------------------------------------------------------------------------
# 13. LIGHTING
# ---------------------------------------------------------------------------
def setup_lighting():
    # Sun lamp
    sun_data = bpy.data.lights.new("SunLight", type='SUN')
    sun_data.energy = 3.0
    sun_data.color = (1.0, 0.95, 0.88)
    sun_obj = bpy.data.objects.new("SunLight", sun_data)
    bpy.context.scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(-55), math.radians(15), math.radians(30))

    # Fill light
    fill_data = bpy.data.lights.new("FillLight", type='SUN')
    fill_data.energy = 0.5
    fill_data.color = (0.7, 0.8, 1.0)
    fill_obj = bpy.data.objects.new("FillLight", fill_data)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(-30), math.radians(-20), math.radians(-60))

    # World
    world = bpy.data.worlds.new("MenuWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.45, 0.72, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 0.8

    # EEVEE settings
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
    bpy.context.scene.render.resolution_x = 1920
    bpy.context.scene.render.resolution_y = 1080
    bpy.context.scene.frame_end = 120


# ---------------------------------------------------------------------------
# SAVE & EXPORT
# ---------------------------------------------------------------------------
def save_and_export():
    # Save .blend
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print(f"Saved: {BLEND_PATH}")

    # Export GLB
    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format='GLB',
        export_apply=True,
        export_animations=True,
    )
    print(f"Exported: {GLB_PATH}")


# ---------------------------------------------------------------------------
# VIEWPORT
# ---------------------------------------------------------------------------
def set_viewport_camera():
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.region_3d.view_perspective = 'CAMERA'
                    space.shading.type = 'MATERIAL'
            break


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
def main():
    print("=== M.E.R.L.I.N. Menu Coast Scene Builder ===")
    clear_scene()
    create_all_materials()

    print("Building terrain...")
    build_terrain()
    print("Building ocean...")
    build_ocean()
    print("Building tower...")
    build_tower()
    print("Building cabin...")
    build_cabin()
    print("Building menhirs...")
    build_menhirs()
    print("Building crystals...")
    build_crystals()
    print("Building vegetation...")
    build_vegetation()
    print("Building sea rocks...")
    build_sea_rocks()
    print("Building clouds...")
    build_clouds()
    print("Building sun...")
    build_sun()
    print("Building particles...")
    build_particles()
    print("Setting up camera...")
    setup_camera()
    print("Setting up lighting...")
    setup_lighting()

    print("Saving and exporting...")
    save_and_export()

    print("Setting viewport...")
    set_viewport_camera()

    print("=== DONE — Scene ready for iteration ===")


main()
