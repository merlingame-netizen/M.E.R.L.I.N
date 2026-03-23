"""
M.E.R.L.I.N. Menu Coast Scene — Blender Builder
Dramatic cliff face with ruined celtic tower, low-poly faceted style.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector

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
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)

def make_mat(name, color, roughness=0.9, metallic=0.0, emission_strength=0.0, alpha=1.0):
    """Create a PBR material with proper settings."""
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

# ═══════════════════════════════════════════════════════════════════════════════
# MATERIALS (create ALL upfront)
# ═══════════════════════════════════════════════════════════════════════════════
def create_materials():
    mats = {}
    mats['cliff_green'] = make_mat("cliff_green", (0.30, 0.48, 0.22), roughness=0.85)
    mats['cliff_rock'] = make_mat("cliff_rock", (0.40, 0.35, 0.28), roughness=0.95)
    mats['cliff_dark'] = make_mat("cliff_dark", (0.25, 0.22, 0.18), roughness=1.0)
    mats['ocean'] = make_mat("ocean", (0.05, 0.20, 0.38), roughness=0.3, metallic=0.1)
    mats['ocean_foam'] = make_mat("ocean_foam", (0.50, 0.60, 0.65), roughness=0.5, alpha=0.7)
    mats['stone'] = make_mat("stone", (0.38, 0.35, 0.30), roughness=0.95)
    mats['stone_dark'] = make_mat("stone_dark", (0.22, 0.20, 0.18), roughness=1.0)
    mats['moss'] = make_mat("moss", (0.20, 0.38, 0.14), roughness=1.0)
    mats['crystal'] = make_mat("crystal", (0.55, 0.15, 0.85), roughness=0.2, metallic=0.3, emission_strength=3.0)
    mats['wood'] = make_mat("wood", (0.42, 0.34, 0.24), roughness=0.9)
    mats['roof'] = make_mat("roof", (0.30, 0.25, 0.18), roughness=0.95)
    mats['window'] = make_mat("window", (0.03, 0.02, 0.02), roughness=1.0)
    mats['bush_1'] = make_mat("bush_1", (0.22, 0.42, 0.18), roughness=0.85)
    mats['bush_2'] = make_mat("bush_2", (0.28, 0.50, 0.20), roughness=0.85)
    mats['bush_3'] = make_mat("bush_3", (0.18, 0.38, 0.15), roughness=0.85)
    mats['cloud'] = make_mat("cloud", (0.95, 0.97, 1.0), roughness=1.0, alpha=0.45)
    mats['sun_core'] = make_mat("sun_core", (1.0, 0.95, 0.80), emission_strength=8.0)
    mats['sun_halo'] = make_mat("sun_halo", (1.0, 0.95, 0.85), emission_strength=1.5, alpha=0.12)
    mats['smoke'] = make_mat("smoke", (0.6, 0.6, 0.6), alpha=0.15)
    mats['magic_green'] = make_mat("magic_green", (0.15, 0.90, 0.45), emission_strength=4.0, alpha=0.6)
    mats['magic_purple'] = make_mat("magic_purple", (0.60, 0.20, 0.90), emission_strength=3.0, alpha=0.5)
    return mats

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE ELEMENTS
# ═══════════════════════════════════════════════════════════════════════════════

def build_terrain(mats):
    """Cliff terrain: flat green top with dramatic brown rock face dropping to ocean."""
    # Main cliff body — large box for the mass
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 4))
    cliff_top = bpy.context.active_object
    cliff_top.name = "CliffTop"
    cliff_top.scale = (40, 25, 8)
    bpy.ops.object.transform_apply(scale=True)
    assign_mat(cliff_top, mats['cliff_green'])
    shade_flat(cliff_top)

    # Cliff FACE — vertical rock wall (visible from camera)
    # Multiple layered boxes for textured rock face look
    face_colors = [mats['cliff_rock'], mats['cliff_dark'], mats['cliff_rock']]
    for i in range(5):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(
            random.uniform(-3, 3),
            -12.5 - i * 0.3 + random.uniform(-0.2, 0.2),
            4 - i * 1.5 + random.uniform(-0.3, 0.3)
        ))
        layer = bpy.context.active_object
        layer.name = f"RockLayer_{i}"
        layer.scale = (38 + random.uniform(-3, 3), 1.5 + random.uniform(-0.3, 0.5), 2.0 + random.uniform(-0.3, 0.5))
        bpy.ops.object.transform_apply(scale=True)
        assign_mat(layer, face_colors[i % len(face_colors)])
        shade_flat(layer)

    # Rock outcrops on face
    for i in range(8):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(
            random.uniform(-15, 15),
            -13 + random.uniform(-1, 0),
            random.uniform(-2, 6)
        ))
        outcrop = bpy.context.active_object
        outcrop.name = f"Outcrop_{i}"
        outcrop.scale = (random.uniform(1, 3), random.uniform(0.5, 1.5), random.uniform(0.5, 2))
        outcrop.rotation_euler = (random.uniform(-0.1, 0.1), random.uniform(-0.05, 0.05), random.uniform(-0.1, 0.1))
        bpy.ops.object.transform_apply(scale=True)
        assign_mat(outcrop, mats['cliff_dark'] if random.random() > 0.5 else mats['cliff_rock'])
        shade_flat(outcrop)

    # Serrated cliff edge (uneven green line)
    for i in range(20):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(
            -18 + i * 1.9 + random.uniform(-0.3, 0.3),
            -12 + random.uniform(-0.5, 0.5),
            8 + random.uniform(-0.5, 1.0)
        ))
        edge = bpy.context.active_object
        edge.name = f"Edge_{i}"
        edge.scale = (random.uniform(0.5, 1.5), random.uniform(0.3, 0.8), random.uniform(0.3, 1.2))
        bpy.ops.object.transform_apply(scale=True)
        assign_mat(edge, mats['cliff_green'])
        shade_flat(edge)


def build_ocean(mats):
    """Geometric ocean with animated waves."""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=60, y_subdivisions=40, size=1, location=(0, -35, -1))
    ocean = bpy.context.active_object
    ocean.name = "Ocean"
    ocean.scale = (120, 60, 1)
    bpy.ops.object.transform_apply(scale=True)

    # Wave displacement
    from mathutils import noise as mn
    for v in ocean.data.vertices:
        x, y = v.co.x / 120, v.co.y / 60
        wave = math.sin(x * 15) * 0.4 + math.sin(y * 10 + x * 5) * 0.3
        wave += mn.noise(Vector((x * 8, y * 6, 0))) * 0.2
        # Quantize for faceted look
        v.co.z = round(wave * 3) / 3

    assign_mat(ocean, mats['ocean'])
    shade_flat(ocean)

    # Shape key for animation
    ocean.shape_key_add(name="Basis")
    sk = ocean.shape_key_add(name="Wave1")
    for i, v in enumerate(sk.data):
        x, y = v.co.x / 120, v.co.y / 60
        v.co.z += math.sin(x * 12 + 2.0) * 0.5 + math.cos(y * 8 + 1.5) * 0.3
    sk.value = 0.0
    sk.keyframe_insert("value", frame=1)
    sk.value = 1.0
    sk.keyframe_insert("value", frame=60)
    sk.value = 0.0
    sk.keyframe_insert("value", frame=120)


def build_tower(mats):
    """Celtic ruined tower with windows, moss, debris."""
    # Main tower
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=2.0, depth=18, location=(0, -5, 17))
    tower = bpy.context.active_object
    tower.name = "Tower"
    assign_mat(tower, mats['stone'])
    shade_flat(tower)

    # Windows
    for i in range(4):
        angle = i * math.pi / 2 + 0.3
        h = 12 + i * 3.5
        bpy.ops.mesh.primitive_cube_add(size=0.5, location=(
            math.cos(angle) * 1.9, -5 + math.sin(angle) * 1.9, h
        ))
        win = bpy.context.active_object
        win.name = f"Window_{i}"
        win.scale = (0.4, 0.15, 0.7)
        win.rotation_euler.z = angle + math.pi/2
        assign_mat(win, mats['window'])

    # Broken crenellations
    for i in range(6):
        if random.random() > 0.3:
            angle = i * math.pi / 3
            h = random.uniform(0.5, 2.5)
            bpy.ops.mesh.primitive_cube_add(size=0.5, location=(
                math.cos(angle) * 1.7, -5 + math.sin(angle) * 1.7, 26 + h * 0.5
            ))
            cren = bpy.context.active_object
            cren.name = f"Crenellation_{i}"
            cren.scale = (0.4, 0.5, h)
            cren.rotation_euler = (random.uniform(-0.15, 0.15), random.uniform(-0.15, 0.15), angle)
            assign_mat(cren, mats['stone'])

    # Moss patches
    for i in range(8):
        angle = random.uniform(0, math.tau)
        h = random.uniform(10, 22)
        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(
            math.cos(angle) * 2.05, -5 + math.sin(angle) * 2.05, h
        ))
        moss = bpy.context.active_object
        moss.name = f"Moss_{i}"
        moss.scale = (0.6, random.uniform(0.4, 1.8), random.uniform(0.3, 0.8))
        moss.rotation_euler.z = angle
        assign_mat(moss, mats['moss'])

    # Floating debris
    for i in range(12):
        angle = random.uniform(0, math.tau)
        dist = random.uniform(3, 6)
        h = random.uniform(14, 28)
        size = random.uniform(0.3, 0.8)
        bpy.ops.mesh.primitive_cube_add(size=size, location=(
            math.cos(angle) * dist, -5 + math.sin(angle) * dist, h
        ))
        debris = bpy.context.active_object
        debris.name = f"Debris_{i}"
        debris.rotation_euler = (random.uniform(0, 1), random.uniform(0, 1), random.uniform(0, 1))
        assign_mat(debris, mats['stone_dark'])


def build_crystals(mats):
    """Purple crystal cluster near tower base."""
    base = Vector((3, -10, 8.5))
    for i in range(8):
        h = random.uniform(1.5, 4.0)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.25, depth=h, location=(
            base.x + random.uniform(-2, 2),
            base.y + random.uniform(-1, 1),
            base.z + h * 0.5
        ))
        crystal = bpy.context.active_object
        crystal.name = f"Crystal_{i}"
        crystal.rotation_euler = (random.uniform(-0.25, 0.25), random.uniform(-0.2, 0.2), random.uniform(0, math.tau))
        assign_mat(crystal, mats['crystal'])
        shade_flat(crystal)


def build_menhirs(mats):
    """Standing stones scattered on cliff top."""
    positions = [
        (8, -3, 8), (-6, 2, 8), (12, -8, 8), (-10, -6, 8),
        (5, 5, 8), (-3, -9, 8), (15, 0, 8)
    ]
    for i, pos in enumerate(positions):
        h = random.uniform(3, 6)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], pos[1], pos[2] + h/2))
        stone = bpy.context.active_object
        stone.name = f"Menhir_{i}"
        stone.scale = (0.4, 0.3, h)
        bpy.ops.object.transform_apply(scale=True)
        # Taper top
        bpy.ops.object.mode_set(mode='EDIT')
        bm = bmesh.from_edit_mesh(stone.data)
        for v in bm.verts:
            if v.co.z > h * 0.5:
                factor = 1.0 - (v.co.z / h) * 0.4
                v.co.x *= factor
                v.co.y *= factor
        bmesh.update_edit_mesh(stone.data)
        bpy.ops.object.mode_set(mode='OBJECT')
        stone.rotation_euler = (random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), random.uniform(0, math.tau))
        assign_mat(stone, mats['stone_dark'])
        shade_flat(stone)


def build_cabin(mats):
    """Small cabin with chimney and smoke."""
    cx, cy = -15, 2
    # Base
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, 8.8))
    base = bpy.context.active_object
    base.name = "CabinBase"
    base.scale = (2.0, 1.5, 1.2)
    assign_mat(base, mats['wood'])
    shade_flat(base)
    # Roof
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.6, depth=1.0, location=(cx, cy, 10.0))
    roof = bpy.context.active_object
    roof.name = "CabinRoof"
    roof.scale = (1.0, 0.8, 1.0)
    roof.rotation_euler.z = math.pi / 4
    assign_mat(roof, mats['roof'])
    shade_flat(roof)
    # Chimney
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(cx + 0.7, cy, 10.5))
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney.scale = (1, 1, 2.5)
    assign_mat(chimney, mats['stone'])
    # Door
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(cx, cy - 1.5, 8.5))
    door = bpy.context.active_object
    door.name = "Door"
    door.scale = (0.5, 0.05, 0.8)
    assign_mat(door, mats['window'])


def build_vegetation(mats):
    """Bushes and small trees scattered on cliff top."""
    bush_mats = [mats['bush_1'], mats['bush_2'], mats['bush_3']]
    for i in range(40):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.4, 1.2), location=(
            random.uniform(-18, 18),
            random.uniform(-10, 10),
            8 + random.uniform(0, 0.5)
        ))
        bush = bpy.context.active_object
        bush.name = f"Bush_{i}"
        bush.scale.z = random.uniform(0.5, 0.8)
        # Randomize vertices for organic shape
        for v in bush.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.1, 0.15)
        assign_mat(bush, random.choice(bush_mats))
        shade_flat(bush)


def build_sea_rocks(mats):
    """Dark rocks in the ocean."""
    positions = [
        (20, -25, -1), (-15, -30, -1.5), (10, -40, -1), (-20, -35, -0.5), (25, -45, -1.2)
    ]
    for i, pos in enumerate(positions):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=random.uniform(1.5, 3.5), location=pos)
        rock = bpy.context.active_object
        rock.name = f"SeaRock_{i}"
        rock.scale.z = 0.6
        for v in rock.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.2, 0.2)
        assign_mat(rock, mats['stone_dark'])
        shade_flat(rock)


def build_clouds(mats):
    """Low-poly clouds scattered in sky."""
    for i in range(12):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(2, 5), location=(
            random.uniform(-40, 50),
            random.uniform(-50, -20),
            random.uniform(20, 35)
        ))
        cloud = bpy.context.active_object
        cloud.name = f"Cloud_{i}"
        cloud.scale = (random.uniform(1.5, 3), random.uniform(0.8, 1.2), random.uniform(0.4, 0.7))
        for v in cloud.data.vertices:
            v.co += v.co.normalized() * random.uniform(-0.3, 0.3)
        assign_mat(cloud, mats['cloud'])
        shade_flat(cloud)


def build_sun(mats):
    """Sun with emissive core and halo."""
    # Core
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=3, location=(40, -40, 30))
    sun_core = bpy.context.active_object
    sun_core.name = "SunCore"
    assign_mat(sun_core, mats['sun_core'])
    # Halo
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=10, location=(40, -40, 30))
    halo = bpy.context.active_object
    halo.name = "SunHalo"
    assign_mat(halo, mats['sun_halo'])


def build_magic_particles(mats):
    """Tiny emissive spheres around tower + crystals."""
    for i in range(20):
        angle = random.uniform(0, math.tau)
        dist = random.uniform(2.5, 5)
        h = random.uniform(15, 28)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.08, location=(
            math.cos(angle) * dist, -5 + math.sin(angle) * dist, h
        ))
        p = bpy.context.active_object
        p.name = f"MagicParticle_{i}"
        assign_mat(p, mats['magic_green'] if random.random() > 0.3 else mats['magic_purple'])


def setup_camera():
    """Dramatic low angle — at ocean level looking UP at cliff + tower."""
    bpy.ops.object.camera_add(location=(35, -35, 2))
    cam = bpy.context.active_object
    cam.name = "MenuCamera"
    cam.data.lens = 35  # Wider for drama
    cam.data.clip_end = 200

    # Look at tower mid-height
    target = Vector((0, -5, 12))
    direction = target - cam.location
    rot = direction.to_track_quat('-Z', 'Y')
    cam.rotation_euler = rot.to_euler()

    bpy.context.scene.camera = cam


def setup_lighting():
    """Sun + fill + world sky + volumetric fog."""
    # Main sun
    bpy.ops.object.light_add(type='SUN', location=(20, -20, 30))
    sun = bpy.context.active_object
    sun.name = "SunLight"
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.95, 0.85)
    sun.rotation_euler = (math.radians(-55), math.radians(15), math.radians(-30))

    # Fill light
    bpy.ops.object.light_add(type='SUN', location=(-10, 10, 15))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.0
    fill.data.color = (0.55, 0.65, 0.85)
    fill.rotation_euler = (math.radians(-30), math.radians(-150), 0)

    # World: blue sky + volumetric
    world = bpy.data.worlds.new("MenuWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.45, 0.72, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 1.2
    bpy.context.scene.world = world

    # EEVEE volumetric fog
    bpy.context.scene.eevee.volumetric_end = 150


def setup_render():
    """EEVEE settings for fast preview + render."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.frame_start = 1
    scene.frame_end = 120
    scene.render.fps = 30

    # EEVEE quality
    scene.eevee.taa_render_samples = 32
    # Bloom handled via compositor in EEVEE Next (Blender 4.5+)


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
def main():
    clear_scene()
    mats = create_materials()

    print("[MENU SCENE] Building terrain...")
    build_terrain(mats)
    print("[MENU SCENE] Building ocean...")
    build_ocean(mats)
    print("[MENU SCENE] Building tower...")
    build_tower(mats)
    print("[MENU SCENE] Building crystals...")
    build_crystals(mats)
    print("[MENU SCENE] Building menhirs...")
    build_menhirs(mats)
    print("[MENU SCENE] Building cabin...")
    build_cabin(mats)
    print("[MENU SCENE] Building vegetation...")
    build_vegetation(mats)
    print("[MENU SCENE] Building sea rocks...")
    build_sea_rocks(mats)
    print("[MENU SCENE] Building clouds...")
    build_clouds(mats)
    print("[MENU SCENE] Building sun...")
    build_sun(mats)
    print("[MENU SCENE] Building magic particles...")
    build_magic_particles(mats)
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
    except:
        pass
    bpy.ops.object.select_all(action='DESELECT')

    # Save .blend
    os.makedirs(SAVE_DIR, exist_ok=True)
    blend_path = os.path.join(SAVE_DIR, "menu_coast_scene.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[MENU SCENE] Saved: {blend_path}")

    # Export GLB
    os.makedirs(EXPORT_DIR, exist_ok=True)
    glb_path = os.path.join(EXPORT_DIR, "menu_scene_v2.glb")
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB', use_selection=True, export_apply=True)
    print(f"[MENU SCENE] Exported: {glb_path}")

    # RENDER PREVIEW PNG (autonomous QA)
    os.makedirs(RENDER_DIR, exist_ok=True)
    render_path = os.path.join(RENDER_DIR, "menu_scene_preview.png")
    bpy.context.scene.render.filepath = render_path
    bpy.ops.render.render(write_still=True)
    print(f"[MENU SCENE] Rendered: {render_path}")

    # Set viewport to rendered/material preview from camera
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'MATERIAL'
                    space.region_3d.view_perspective = 'CAMERA'

    print("[MENU SCENE] ═══ COMPLETE ═══")

main()
