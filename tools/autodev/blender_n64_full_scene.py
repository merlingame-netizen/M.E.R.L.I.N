# N64 Menu Scene — Complete Blender scene matching reference image
# Reference: tools/autodev/captures/Image_Exemple_Menu.jpg
# Colors: pixel-perfect extraction from reference analysis
# Output: Assets/3d_models/menu_coast/n64_menu_scene.glb
#
# Usage: blender --background --python blender_n64_full_scene.py
#
import bpy, bmesh, math, random
from mathutils import Vector, noise

random.seed(42)

# ============================================================
# CLEANUP
# ============================================================
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for col in bpy.data.collections:
    if col.name != 'Collection':
        bpy.data.collections.remove(col)

# ============================================================
# REFERENCE COLORS (extracted from Image_Exemple_Menu.jpg)
# ============================================================
C = {
    "cliff_brown":   (0.314, 0.282, 0.196),   # #504832
    "cliff_dark":    (0.125, 0.122, 0.114),    # #201f1d
    "cliff_earth":   (0.235, 0.216, 0.145),    # #3c3725
    "cliff_grey":    (0.369, 0.455, 0.514),    # #5e7483
    "ocean_deep":    (0.212, 0.341, 0.376),    # #365760
    "ocean_mid":     (0.267, 0.408, 0.435),    # #44686f
    "ocean_light":   (0.310, 0.490, 0.510),    # teal highlight
    "foam_white":    (0.800, 0.830, 0.820),    # wave crests
    "sky_dark":      (0.220, 0.270, 0.340),    # dark cloud
    "sky_mid":       (0.290, 0.330, 0.390),    # mid cloud
    "sky_light":     (0.370, 0.420, 0.490),    # light cloud band
    "tower_stone":   (0.200, 0.185, 0.140),    # dark tower
    "tower_light":   (0.280, 0.260, 0.200),    # tower highlight
    "ground_brown":  (0.235, 0.216, 0.145),    # path/ground
    "ground_dark":   (0.160, 0.145, 0.100),    # dark ground
    "bush_green":    (0.180, 0.200, 0.120),    # dark vegetation
    "bush_dark":     (0.120, 0.140, 0.080),    # deep shadow bush
    "rock_grey":     (0.180, 0.170, 0.150),    # scattered rocks
    "distant_dark":  (0.100, 0.120, 0.150),    # distant cliff silhouette
}

def make_mat(name, color, roughness=0.95):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = False
    mat.diffuse_color = (*color, 1.0)
    mat.roughness = roughness
    return mat

# Pre-create materials
mats = {name: make_mat(name, color) for name, color in C.items()}

# ============================================================
# 1. CLIFF TERRAIN (main landscape)
# ============================================================
def create_cliff():
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    cliff = bpy.context.active_object
    cliff.name = "Cliff"

    # Subdivide for terrain detail
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(cliff.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=12)
    bmesh.update_edit_mesh(cliff.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Displace: cliff rises from left (ocean) to right (path), with drop-off
    for v in cliff.data.vertices:
        x, y = v.co.x, v.co.y

        # Base height: rises from left to right
        base = max(0, (x + 5) * 0.6)

        # Cliff face drop-off on left side
        if x < -3:
            base = max(-4, base - abs(x + 3) * 2.0)

        # Rocky noise
        noise_val = random.uniform(-0.4, 0.4)
        ridge = math.sin(y * 0.8 + x * 0.3) * 0.5

        v.co.z = base + noise_val + ridge

    # Assign 4 cliff materials based on face height/angle
    for name in ["cliff_brown", "cliff_dark", "cliff_earth", "cliff_grey"]:
        cliff.data.materials.append(mats[name])

    random.seed(42)
    for face in cliff.data.polygons:
        center_z = sum(cliff.data.vertices[v].co.z for v in face.vertices) / len(face.vertices)
        center_x = sum(cliff.data.vertices[v].co.x for v in face.vertices) / len(face.vertices)

        if center_z < -1:  # Ocean-facing cliff face
            face.material_index = random.choice([1, 3])  # dark / grey
        elif center_z > 4:  # High ground
            face.material_index = random.choice([0, 2])  # brown / earth
        elif center_x < -2:  # Cliff edge
            face.material_index = random.choice([1, 0, 3])
        else:
            face.material_index = random.choice([0, 1, 2, 3])

    bpy.ops.object.shade_flat()
    return cliff

# ============================================================
# 2. TOWER (cylindrical N64 stone tower)
# ============================================================
def create_tower():
    # Main body
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.7, depth=5.0, location=(-4, -3, 7.5))
    tower = bpy.context.active_object
    tower.name = "Tower"
    tower.data.materials.append(mats["tower_stone"])

    # Top battlements ring
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.85, depth=0.35, location=(-4, -3, 10.2))
    top = bpy.context.active_object
    top.name = "Tower_Top"
    top.data.materials.append(mats["tower_light"])

    # Crenellations (4 notches)
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 8
        cx = -4 + math.cos(angle) * 0.75
        cy = -3 + math.sin(angle) * 0.75
        bpy.ops.mesh.primitive_cube_add(size=0.3, location=(cx, cy, 10.5))
        notch = bpy.context.active_object
        notch.name = "Crenellation_{}".format(i)
        notch.data.materials.append(mats["tower_light"])

    # Window slit
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-3.3, -3, 8.0), scale=(0.03, 0.15, 0.06))
    win = bpy.context.active_object
    win.name = "Window"
    win.data.materials.append(mats["cliff_dark"])

    # Select all tower parts and join
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        if obj.name.startswith("Tower") or obj.name.startswith("Crenellation") or obj.name == "Window":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = tower
    bpy.ops.object.join()
    bpy.ops.object.shade_flat()
    return tower

# ============================================================
# 3. OCEAN (water plane with wave displacement)
# ============================================================
def create_ocean():
    bpy.ops.mesh.primitive_plane_add(size=80, location=(-15, 0, -3.5))
    ocean = bpy.context.active_object
    ocean.name = "Ocean"

    # Subdivide for waves
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(ocean.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=10)
    bmesh.update_edit_mesh(ocean.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Wave displacement
    for v in ocean.data.vertices:
        v.co.z += math.sin(v.co.x * 0.3 + v.co.y * 0.2) * 0.3
        v.co.z += math.sin(v.co.x * 0.7) * 0.15

    # Ocean materials: deep + mid + light bands
    ocean.data.materials.append(mats["ocean_deep"])
    ocean.data.materials.append(mats["ocean_mid"])
    ocean.data.materials.append(mats["ocean_light"])

    for face in ocean.data.polygons:
        cx = sum(ocean.data.vertices[v].co.x for v in face.vertices) / len(face.vertices)
        if cx < -10:
            face.material_index = 0  # deep
        elif cx < 0:
            face.material_index = 1  # mid
        else:
            face.material_index = 2  # light/shallow

    bpy.ops.object.shade_flat()
    return ocean

# ============================================================
# 4. FOAM LINE (white strip at cliff-ocean boundary)
# ============================================================
def create_foam():
    bpy.ops.mesh.primitive_plane_add(size=1, location=(-6, 0, -2.8))
    foam = bpy.context.active_object
    foam.name = "Foam"
    foam.scale = (12, 20, 1)
    foam.data.materials.append(mats["foam_white"])
    bpy.ops.object.shade_flat()
    return foam

# ============================================================
# 5. CLOUDS (N64 box clouds in layers)
# ============================================================
def create_clouds():
    cloud_data = [
        # (position, size, color_key)
        ((-8, -5, 18), (20, 8, 1.5), "sky_dark"),
        ((5, 0, 20), (18, 6, 1.8), "sky_mid"),
        ((-3, 5, 16), (15, 7, 1.2), "sky_light"),
        ((10, -8, 22), (22, 5, 2.0), "sky_dark"),
        ((-12, 3, 19), (16, 9, 1.4), "sky_mid"),
        ((0, -10, 17), (25, 4, 1.6), "sky_light"),
        ((8, 8, 21), (14, 6, 1.3), "sky_dark"),
        ((-6, -12, 23), (18, 7, 2.2), "sky_mid"),
    ]
    clouds = []
    for pos, size, color_key in cloud_data:
        bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
        cloud = bpy.context.active_object
        cloud.name = "Cloud_{}".format(len(clouds))
        cloud.scale = size
        cloud.data.materials.append(mats[color_key])
        bpy.ops.object.shade_flat()
        clouds.append(cloud)
    return clouds

# ============================================================
# 6. BUSHES (small N64 low-poly vegetation)
# ============================================================
def create_bushes():
    bush_positions = [
        (5, 2, 4.5, 0.5),   # (x, y, z, scale)
        (7, -1, 4.2, 0.7),
        (3, 4, 4.8, 0.4),
        (8, 3, 4.3, 0.6),
        (6, -3, 4.0, 0.5),
    ]
    bushes = []
    for bx, by, bz, bs in bush_positions:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=bs, location=(bx, by, bz))
        bush = bpy.context.active_object
        bush.name = "Bush_{}".format(len(bushes))
        bush.scale.z = 0.7  # Flatten slightly
        color_key = random.choice(["bush_green", "bush_dark"])
        bush.data.materials.append(mats[color_key])
        bpy.ops.object.shade_flat()
        bushes.append(bush)
    return bushes

# ============================================================
# 7. GROUND ROCKS (scattered N64 box rocks)
# ============================================================
def create_rocks():
    rocks = []
    for i in range(10):
        rx = random.uniform(0, 12)
        ry = random.uniform(-6, 8)
        rz = 4.0 + random.uniform(-0.2, 0.2)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(rx, ry, rz))
        rock = bpy.context.active_object
        rock.name = "Rock_{}".format(i)
        rock.scale = (
            random.uniform(0.15, 0.4),
            random.uniform(0.15, 0.35),
            random.uniform(0.1, 0.25)
        )
        rock.rotation_euler = (0, 0, random.uniform(0, math.tau))
        rock.data.materials.append(mats["rock_grey"])
        bpy.ops.object.shade_flat()
        rocks.append(rock)
    return rocks

# ============================================================
# 8. DISTANT CLIFFS (background silhouettes)
# ============================================================
def create_distant_cliffs():
    silhouettes = [
        ((-25, -20, 2), (8, 3, 6)),
        ((-30, -15, 1), (5, 4, 4)),
        ((-20, -25, 0.5), (6, 2, 3)),
    ]
    dists = []
    for pos, scale in silhouettes:
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=1, depth=1, location=pos)
        dist = bpy.context.active_object
        dist.name = "DistantCliff_{}".format(len(dists))
        dist.scale = scale
        dist.data.materials.append(mats["distant_dark"])
        bpy.ops.object.shade_flat()
        dists.append(dist)
    return dists

# ============================================================
# 9. CAMERA (matched to reference image perspective)
# ============================================================
def setup_camera():
    cam_data = bpy.data.cameras.new("MenuCamera")
    cam_data.lens = 28  # Wide angle, ~65 degree FOV
    cam_data.clip_end = 200
    cam = bpy.data.objects.new("MenuCamera", cam_data)
    bpy.context.collection.objects.link(cam)

    # Position: elevated right, looking across cliff to tower
    cam.location = (15, 10, 10)

    # Look at cliff center
    direction = Vector((-4, -3, 4)) - Vector((15, 10, 10))
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam.rotation_euler = rot_quat.to_euler()

    bpy.context.scene.camera = cam
    return cam

# ============================================================
# 10. LIGHTING (overcast N64 mood)
# ============================================================
def setup_lighting():
    # Sun — low angle, desaturated
    bpy.ops.object.light_add(type='SUN', location=(10, -10, 20))
    sun = bpy.context.active_object
    sun.name = "Sun"
    sun.data.energy = 2.0
    sun.data.color = (0.75, 0.72, 0.65)
    sun.rotation_euler = (math.radians(-40), math.radians(20), math.radians(-45))

    # Fill — cool blue from ocean side
    bpy.ops.object.light_add(type='SUN', location=(-10, 5, 15))
    fill = bpy.context.active_object
    fill.name = "Fill"
    fill.data.energy = 0.5
    fill.data.color = (0.45, 0.50, 0.60)
    fill.rotation_euler = (math.radians(-30), math.radians(-150), 0)

# ============================================================
# BUILD SCENE
# ============================================================
print("=== Building N64 Menu Scene ===")
cliff = create_cliff()
print("  Cliff terrain OK")
tower = create_tower()
print("  Tower OK")
ocean = create_ocean()
print("  Ocean OK")
foam = create_foam()
print("  Foam OK")
clouds = create_clouds()
print("  Clouds OK ({})".format(len(clouds)))
bushes = create_bushes()
print("  Bushes OK ({})".format(len(bushes)))
rocks = create_rocks()
print("  Rocks OK ({})".format(len(rocks)))
dists = create_distant_cliffs()
print("  Distant cliffs OK ({})".format(len(dists)))
cam = setup_camera()
print("  Camera OK")
setup_lighting()
print("  Lighting OK")

# ============================================================
# RENDER PREVIEW (optional — for comparison)
# ============================================================
bpy.context.scene.render.resolution_x = 1280
bpy.context.scene.render.resolution_y = 720
bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
# Bloom removed (not available in Blender 4.5)

# Set world background to match reference sky
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs[0].default_value = (0.28, 0.34, 0.42, 1.0)  # Reference sky color
    bg_node.inputs[1].default_value = 0.5

# Render preview
preview_path = "C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/blender_n64_preview.png"
bpy.context.scene.render.filepath = preview_path
bpy.ops.render.render(write_still=True)
print("  Preview rendered: {}".format(preview_path))

# ============================================================
# EXPORT GLB (for Godot)
# ============================================================
# Select all scene objects (not camera/lights)
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        obj.select_set(True)

export_path = "C:/Users/PGNK2128/Godot-MCP/Assets/3d_models/menu_coast/n64_menu_scene.glb"
bpy.ops.export_scene.gltf(
    filepath=export_path,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
)
print("  GLB exported: {}".format(export_path))
print("=== DONE ===")
