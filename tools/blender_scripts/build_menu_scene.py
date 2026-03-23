"""
M.E.R.L.I.N. Menu Coast Scene — Blender Builder v3
Strategy: Blender = static geometry only (5 GLBs). Godot handles all dynamic effects.

Exports:
  1. cliff_unified.glb    — Merged cliff + outcrops, vertex colored
  2. tower_unified.glb    — Tower + windows + moss + crenellations merged
  3. rocks_set.glb        — 5 sea rocks merged
  4. crystal_cluster_unified.glb — 8 crystals merged (emission material)
  5. cabin_unified.glb    — Cabin + roof + chimney + door merged

NOT exported (Godot handles): ocean, sky, clouds, sun, particles, vegetation,
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


def create_vertex_color_material(name):
    """Single material that reads vertex colors — used for ALL meshes."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    attr.location = (-300, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (300, 0)

    links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def create_crystal_material(name):
    """Emission material for crystals — purple glow, no vertex colors needed."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    bsdf.inputs["Base Color"].default_value = (0.45, 0.15, 0.70, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.1
    bsdf.inputs["Emission Color"].default_value = (0.55, 0.20, 0.85, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 3.0

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (300, 0)

    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def paint_vertex_colors(obj, color_func):
    """Paint vertex colors on mesh using a function(vertex) -> (r, g, b, a)."""
    mesh = obj.data
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    color_attr = mesh.color_attributes["Color"]

    for loop_idx, loop in enumerate(mesh.loops):
        vert = mesh.vertices[loop.vertex_index]
        color = color_func(vert)
        color_attr.data[loop_idx].color = color


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


# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

def build_cliff():
    """Multi-layered cliff: main plateau + 3 terraces + cliff faces +
    overhangs + outcrops + menhirs. Vertex painted by height zone."""
    from mathutils import noise as mn

    all_parts = []

    # === MAIN PLATEAU (highest, flat green top) ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=35, y_subdivisions=25, size=1, location=(0, 2, 0)
    )
    plateau = bpy.context.active_object
    plateau.name = "Plateau"
    plateau.scale = (65, 40, 1)
    bpy.ops.object.transform_apply(scale=True)

    for v in plateau.data.vertices:
        x_n = v.co.x / 65
        y_n = v.co.y / 40
        h = 9.0 + mn.noise(Vector((x_n * 4, y_n * 4, 0))) * 1.0
        # Taper edges down
        edge_drop = min(abs(x_n) - 0.4, 0) * 5.0
        h += edge_drop
        v.co.z = max(h, 7.5)
    all_parts.append(plateau)

    # === TERRACE 1 (mid-height, extends forward) ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=20, y_subdivisions=15, size=1, location=(8, -8, 0)
    )
    t1 = bpy.context.active_object
    t1.name = "Terrace1"
    t1.scale = (30, 18, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in t1.data.vertices:
        x_n = v.co.x / 30
        y_n = v.co.y / 18
        h = 6.0 + mn.noise(Vector((x_n * 5, y_n * 5, 2.0))) * 1.5
        v.co.z = max(h, 4.0)
    all_parts.append(t1)

    # === TERRACE 2 (lower, left side) ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=15, y_subdivisions=12, size=1, location=(-12, -12, 0)
    )
    t2 = bpy.context.active_object
    t2.name = "Terrace2"
    t2.scale = (25, 15, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in t2.data.vertices:
        x_n = v.co.x / 25
        y_n = v.co.y / 15
        h = 3.5 + mn.noise(Vector((x_n * 6, y_n * 6, 3.0))) * 1.2
        v.co.z = max(h, 1.5)
    all_parts.append(t2)

    # === TERRACE 3 (lowest, right side finger) ===
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=12, y_subdivisions=10, size=1, location=(18, -16, 0)
    )
    t3 = bpy.context.active_object
    t3.name = "Terrace3"
    t3.scale = (20, 12, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in t3.data.vertices:
        x_n = v.co.x / 20
        y_n = v.co.y / 12
        h = 1.8 + mn.noise(Vector((x_n * 7, y_n * 7, 5.0))) * 0.8
        v.co.z = max(h, 0.5)
    all_parts.append(t3)

    # === CLIFF FACE (vertical rock wall under plateau) ===
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -12, 4.5))
    face1 = bpy.context.active_object
    face1.name = "CliffFace1"
    face1.scale = (60, 3, 9)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face1)

    # Second cliff face layer (offset for depth)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(5, -14, 3))
    face2 = bpy.context.active_object
    face2.name = "CliffFace2"
    face2.scale = (45, 2.5, 6)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face2)

    # Third cliff face (lower overhang)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-8, -16, 1.5))
    face3 = bpy.context.active_object
    face3.name = "CliffFace3"
    face3.scale = (35, 2, 3.5)
    bpy.ops.object.transform_apply(scale=True)
    all_parts.append(face3)

    # === ROCK OUTCROPS on cliff face (18 icospheres) ===
    for i in range(18):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2,
            radius=random.uniform(1.5, 4.5),
            location=(
                random.uniform(-25, 25),
                random.uniform(-18, -8),
                random.uniform(0, 8),
            ),
        )
        outcrop = bpy.context.active_object
        outcrop.scale = (
            random.uniform(0.8, 1.3),
            random.uniform(0.6, 1.0),
            random.uniform(0.4, 0.8),
        )
        bpy.ops.object.transform_apply(scale=True)
        for v in outcrop.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.25, 0.25)
        all_parts.append(outcrop)

    # === MENHIRS on plateau (thin vertical standing stones) ===
    for i in range(12):
        h = random.uniform(1.5, 3.5)
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            location=(
                random.uniform(-20, 20),
                random.uniform(-5, 8),
                9.0 + h / 2,
            ),
        )
        menhir = bpy.context.active_object
        menhir.scale = (0.2, 0.15, h)
        bpy.ops.object.transform_apply(scale=True)
        menhir.rotation_euler.y = random.uniform(-0.08, 0.08)
        all_parts.append(menhir)

    # === JOIN ALL ===
    main = all_parts[0]
    join_objects(main, all_parts[1:])
    main.name = "Cliff"

    # Decimate for faceted look
    decimate(main, 0.35)
    shade_flat(main)

    # Vertex color paint — zone by height
    def cliff_color(vert):
        z = vert.co.z
        n = random.uniform(-0.02, 0.02)

        if z > 8.0:
            # Bright green plateau top
            return (0.42 + n, 0.62 + n, 0.22 + n, 1.0)
        elif z > 5.5:
            # Mid-green terrace
            return (0.35 + n, 0.52 + n, 0.20 + n, 1.0)
        elif z > 3.0:
            # Yellow-green lower terrace
            return (0.45 + n, 0.50 + n, 0.22 + n, 1.0)
        elif z > 1.0:
            # Warm brown rock face
            return (0.48 + n, 0.38 + n, 0.26 + n, 1.0)
        else:
            # Dark rock base
            return (0.25 + n, 0.22 + n, 0.18 + n, 1.0)

    paint_vertex_colors(main, cliff_color)

    mat = create_vertex_color_material("CliffMat")
    main.data.materials.clear()
    main.data.materials.append(mat)

    return main


def build_tower():
    """Celtic ruined tower: cylinder body + window holes + moss patches +
    crenellations on top. All joined into 1 mesh, vertex painted."""

    # Main tower body
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=3.5, depth=18, location=(5, -8, 18)
    )
    tower = bpy.context.active_object
    tower.name = "Tower"

    # Roughen tower surface for weathered look
    for v in tower.data.vertices:
        offset = random.uniform(-0.15, 0.15)
        v.co.x += offset
        v.co.y += offset

    parts = []

    # Crenellations on top (8 small cubes around rim)
    for i in range(8):
        angle = math.radians(i * 45)
        cx = 5 + math.cos(angle) * 3.2
        cy = -8 + math.sin(angle) * 3.2
        bpy.ops.mesh.primitive_cube_add(size=1.5, location=(cx, cy, 27.5))
        cren = bpy.context.active_object
        cren.scale = (0.7, 0.7, 1.2)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(cren)

    # Window recesses (small cubes subtracted visually — here just placed as
    # inset geometry that will get dark vertex color)
    for j in range(3):
        wz = 14 + j * 5
        angle = math.radians(j * 90 + 30)
        wx = 5 + math.cos(angle) * 3.6
        wy = -8 + math.sin(angle) * 3.6
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, wy, wz))
        win = bpy.context.active_object
        win.scale = (0.4, 0.15, 0.7)
        bpy.ops.object.transform_apply(scale=True)
        parts.append(win)

    # Moss patches (flattened spheres on the surface)
    for k in range(6):
        angle = math.radians(k * 60 + 15)
        mz = random.uniform(10, 24)
        mx = 5 + math.cos(angle) * 3.7
        my = -8 + math.sin(angle) * 3.7
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=8, ring_count=6, radius=random.uniform(0.8, 1.5),
            location=(mx, my, mz)
        )
        moss = bpy.context.active_object
        moss.scale.z = 0.3
        bpy.ops.object.transform_apply(scale=True)
        parts.append(moss)

    # Join everything
    join_objects(tower, parts)

    # Decimate
    decimate(tower, 0.5)
    shade_flat(tower)

    # Vertex color: grey stone, dark windows (inset cubes), green moss
    def tower_color(vert):
        z = vert.co.z
        # Distance from tower center axis
        dx = vert.co.x - 5
        dy = vert.co.y + 8
        dist = math.sqrt(dx * dx + dy * dy)

        # Moss patches: on the outer surface, small Z scale means
        # they are close to the cylinder radius
        if dist > 3.5 and z > 6:
            # Could be moss — check if vertex is from a flattened sphere
            # Simple heuristic: slightly outside tower radius
            if dist > 4.0:
                return (0.30, 0.50, 0.22, 1.0)  # Green moss
            else:
                return (0.12, 0.10, 0.08, 1.0)  # Dark window recess

        # Crenellations at top
        if z > 26.0:
            return (0.50, 0.48, 0.42, 1.0)  # Light stone

        # Main tower body — vary by height
        noise_val = random.uniform(-0.03, 0.03)
        if z > 19:
            return (0.48 + noise_val, 0.45 + noise_val, 0.40 + noise_val, 1.0)
        elif z > 12:
            return (0.42 + noise_val, 0.40 + noise_val, 0.35 + noise_val, 1.0)
        else:
            return (0.35 + noise_val, 0.33 + noise_val, 0.28 + noise_val, 1.0)

    paint_vertex_colors(tower, tower_color)

    mat = create_vertex_color_material("TowerMat")
    tower.data.materials.clear()
    tower.data.materials.append(mat)

    return tower


def build_rocks():
    """5 sea rocks merged into 1 mesh, vertex painted dark grey."""

    rock_positions = [
        (-25, -28, -1.5),
        (-18, -32, -2.0),
        (-10, -30, -1.0),
        (15, -35, -2.5),
        (22, -30, -1.8),
    ]
    rock_radii = [3.5, 2.8, 4.0, 3.0, 2.5]

    rocks = []
    for idx, (pos, rad) in enumerate(zip(rock_positions, rock_radii)):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=rad, location=pos
        )
        rock = bpy.context.active_object
        rock.name = f"Rock_{idx}"
        # Flatten and roughen
        rock.scale.z = random.uniform(0.4, 0.7)
        rock.scale.x = random.uniform(0.8, 1.3)
        bpy.ops.object.transform_apply(scale=True)

        # Randomize vertices for natural look
        for v in rock.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.3, 0.3)

        rocks.append(rock)

    # Join all into first rock
    main_rock = rocks[0]
    join_objects(main_rock, rocks[1:])
    main_rock.name = "Rocks"

    # Decimate
    decimate(main_rock, 0.45)
    shade_flat(main_rock)

    # Vertex color: dark grey with slight variation
    def rock_color(vert):
        z = vert.co.z
        base = 0.22 + random.uniform(-0.04, 0.04)
        if z > 0:
            # Top exposed: slightly lighter
            return (base + 0.05, base + 0.04, base + 0.03, 1.0)
        else:
            # Submerged: darker, greenish tint
            return (base - 0.02, base + 0.01, base, 1.0)

    paint_vertex_colors(main_rock, rock_color)

    mat = create_vertex_color_material("RocksMat")
    main_rock.data.materials.clear()
    main_rock.data.materials.append(mat)

    return main_rock


def build_crystals():
    """8 crystals merged into a cluster. Uses emission material (not vertex colors)."""

    crystals = []
    center = Vector((-12, -5, 9.5))

    for i in range(8):
        angle = math.radians(i * 45 + random.uniform(-15, 15))
        dist = random.uniform(0.5, 2.5)
        cx = center.x + math.cos(angle) * dist
        cy = center.y + math.sin(angle) * dist
        cz = center.z + random.uniform(-0.5, 0.5)

        height = random.uniform(1.5, 4.0)
        radius = random.uniform(0.3, 0.8)

        bpy.ops.mesh.primitive_cone_add(
            vertices=6, radius1=radius, radius2=0.05,
            depth=height, location=(cx, cy, cz + height / 2)
        )
        crystal = bpy.context.active_object
        crystal.name = f"Crystal_{i}"

        # Tilt randomly
        crystal.rotation_euler = (
            math.radians(random.uniform(-20, 20)),
            math.radians(random.uniform(-20, 20)),
            math.radians(random.uniform(0, 360)),
        )
        bpy.ops.object.transform_apply(rotation=True)

        # Slight vertex noise for organic facets
        for v in crystal.data.vertices:
            v.co += Vector((
                random.uniform(-0.05, 0.05),
                random.uniform(-0.05, 0.05),
                random.uniform(-0.03, 0.03),
            ))

        crystals.append(crystal)

    # Join all into first
    main_crystal = crystals[0]
    join_objects(main_crystal, crystals[1:])
    main_crystal.name = "CrystalCluster"

    shade_flat(main_crystal)

    # Crystal emission material (no vertex colors)
    mat = create_crystal_material("CrystalMat")
    main_crystal.data.materials.clear()
    main_crystal.data.materials.append(mat)

    return main_crystal


def build_cabin():
    """Cabin with roof, chimney, and door. All merged, vertex painted."""

    # Main cabin body
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-20, -3, 9.5))
    cabin = bpy.context.active_object
    cabin.name = "Cabin"
    cabin.scale = (4, 3, 2.5)
    bpy.ops.object.transform_apply(scale=True)

    parts = []

    # Roof (cone / flattened)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=5.5, radius2=0.3,
        depth=3.5, location=(-20, -3, 13.0)
    )
    roof = bpy.context.active_object
    roof.name = "Roof"
    roof.rotation_euler.z = math.radians(45)
    bpy.ops.object.transform_apply(rotation=True)
    parts.append(roof)

    # Chimney
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-18, -2, 14.5))
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney.scale = (0.6, 0.6, 2.0)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(chimney)

    # Door
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-20, -5.1, 8.5))
    door = bpy.context.active_object
    door.name = "Door"
    door.scale = (0.8, 0.1, 1.5)
    bpy.ops.object.transform_apply(scale=True)
    parts.append(door)

    # Join all
    join_objects(cabin, parts)

    # Decimate slightly
    decimate(cabin, 0.6)
    shade_flat(cabin)

    # Vertex color: brown wood walls, dark roof, dark door, grey chimney
    def cabin_color(vert):
        z = vert.co.z
        x = vert.co.x
        y = vert.co.y

        # Door area: dark brown
        if abs(x - (-20)) < 1.0 and y < -4.5 and z < 10.0:
            return (0.15, 0.10, 0.06, 1.0)

        # Chimney: grey stone
        if abs(x - (-18)) < 1.0 and abs(y - (-2)) < 1.0 and z > 13.0:
            return (0.40, 0.38, 0.35, 1.0)

        # Roof: dark slate
        if z > 11.5:
            return (0.22, 0.18, 0.15, 1.0)

        # Walls: warm brown wood
        noise_val = random.uniform(-0.03, 0.03)
        return (0.50 + noise_val, 0.35 + noise_val, 0.20 + noise_val, 1.0)

    paint_vertex_colors(cabin, cabin_color)

    mat = create_vertex_color_material("CabinMat")
    cabin.data.materials.clear()
    cabin.data.materials.append(mat)

    return cabin


# =============================================================================
# CAMERA + LIGHTING (Blender preview only — Godot has its own)
# =============================================================================

def setup_camera():
    bpy.ops.object.camera_add(location=(45, -55, 5))
    cam = bpy.context.active_object
    cam.name = "PreviewCamera"
    cam.data.lens = 35
    cam.data.clip_end = 200
    target = Vector((-5, -5, 12))
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam


def setup_lighting():
    # Sun — warm golden
    bpy.ops.object.light_add(type='SUN', location=(20, -20, 30))
    sun = bpy.context.active_object
    sun.name = "Sun"
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.92, 0.75)
    sun.rotation_euler = (
        math.radians(-50), math.radians(15), math.radians(-25)
    )

    # Fill light — cool blue
    bpy.ops.object.light_add(type='SUN', location=(-10, 10, 15))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.2
    fill.data.color = (0.55, 0.65, 0.85)
    fill.rotation_euler = (
        math.radians(-30), math.radians(-150), 0
    )

    # Sky background
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.35, 0.65, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 1.5
    bpy.context.scene.world = world

    # Color management
    bpy.context.scene.view_settings.view_transform = 'Standard'
    bpy.context.scene.view_settings.exposure = 0.3


# =============================================================================
# MAIN
# =============================================================================

def main():
    clear_scene()
    os.makedirs(EXPORT_DIR, exist_ok=True)
    os.makedirs(BLEND_DIR, exist_ok=True)

    print("[MENU SCENE] Building cliff...")
    cliff = build_cliff()
    export_glb(cliff, "cliff_unified.glb")

    # Clear and rebuild for each to avoid name conflicts
    bpy.ops.object.select_all(action='DESELECT')

    print("[MENU SCENE] Building tower...")
    tower = build_tower()
    export_glb(tower, "tower_unified.glb")

    print("[MENU SCENE] Building rocks...")
    rocks = build_rocks()
    export_glb(rocks, "rocks_set.glb")

    print("[MENU SCENE] Building crystals...")
    crystals = build_crystals()
    export_glb(crystals, "crystal_cluster_unified.glb")

    print("[MENU SCENE] Building cabin...")
    cabin = build_cabin()
    export_glb(cabin, "cabin_unified.glb")

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

    print(f"[MENU SCENE] Rendered: {render_path}")
    print(f"[MENU SCENE] Blend saved: {blend_path}")
    print("[MENU SCENE] === COMPLETE ===")
    print("[MENU SCENE] 5 GLBs exported for Godot integration")


main()
