"""Forge: Celtic Ruined Tower — Tall, broken spire, windows, moss, debris."""
import bpy, bmesh, math, random, os, json
from mathutils import Vector

random.seed(42)
OUT = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast\tower_unified.glb"

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)

print("[FORGE:TOWER] Starting...")

parts = []

# ══ MAIN BODY — 12-sided cylinder, weathered ══
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=3.0, depth=22, location=(0, 0, 11))
tower = bpy.context.active_object
tower.name = "TowerBody"
# Weathered surface — randomize vertices
for v in tower.data.vertices:
    v.co.x += random.uniform(-0.2, 0.2)
    v.co.y += random.uniform(-0.2, 0.2)
    # Taper slightly toward top
    height_factor = (v.co.z - 0) / 22
    if height_factor > 0.5:
        taper = 1.0 - (height_factor - 0.5) * 0.15
        v.co.x *= taper
        v.co.y *= taper
parts.append(tower)

# ══ BROKEN SPIRE — cone with vertices deleted ══
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=2.8, radius2=0.2, depth=10, location=(0, 0, 27))
spire = bpy.context.active_object
spire.name = "Spire"
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(spire.data)
# Delete random upper vertices for broken look
to_remove = [v for v in bm.verts if v.co.x > 0.8 and v.co.z > 3.0]
if to_remove:
    bmesh.ops.delete(bm, geom=to_remove, context='VERTS')
bmesh.update_edit_mesh(spire.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(spire)

# ══ CRENELLATIONS — 8 broken battlements ══
for i in range(8):
    if random.random() > 0.25:
        angle = math.radians(i * 45 + random.uniform(-10, 10))
        h = random.uniform(1.0, 2.5)
        cx = math.cos(angle) * 2.8
        cy = math.sin(angle) * 2.8
        bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, 22 + h/2))
        c = bpy.context.active_object
        c.scale = (0.6, 0.5, h)
        c.rotation_euler = (random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), angle)
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        parts.append(c)

# ══ WINDOWS — 4 dark recesses ══
for i in range(4):
    angle = math.radians(i * 90 + 20)
    wz = 6 + i * 4.5
    wx = math.cos(angle) * 3.1
    wy = math.sin(angle) * 3.1
    bpy.ops.mesh.primitive_cube_add(size=1, location=(wx, wy, wz))
    w = bpy.context.active_object
    w.scale = (0.5, 0.12, 0.8)
    w.rotation_euler.z = angle + math.pi/2
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    parts.append(w)

# ══ MOSS PATCHES — 8 flattened spheres ══
for i in range(8):
    angle = random.uniform(0, math.tau)
    mz = random.uniform(3, 18)
    mx = math.cos(angle) * 3.2
    my = math.sin(angle) * 3.2
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=random.uniform(0.5, 1.2), location=(mx, my, mz))
    m = bpy.context.active_object
    m.scale.z = 0.25
    bpy.ops.object.transform_apply(scale=True)
    parts.append(m)

# ══ BASE RUBBLE — 6 scattered rocks at tower base ══
for i in range(6):
    angle = random.uniform(0, math.tau)
    dist = random.uniform(3.5, 5.0)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(0.4, 1.0),
        location=(math.cos(angle)*dist, math.sin(angle)*dist, random.uniform(0, 1.5)))
    r = bpy.context.active_object
    r.scale.z = random.uniform(0.4, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    for v in r.data.vertices:
        v.co += v.co.normalized() * random.uniform(-0.1, 0.1)
    parts.append(r)

# ══ JOIN ALL ══
print(f"[FORGE:TOWER] Joining {len(parts)} objects...")
bpy.ops.object.select_all(action='DESELECT')
main = parts[0]
main.select_set(True)
for o in parts[1:]:
    o.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.object.join()
main.name = "Tower"

# Decimate
mod = main.modifiers.new("Dec", "DECIMATE")
mod.ratio = 0.45
bpy.ops.object.modifier_apply(modifier="Dec")

for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:TOWER] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══ MULTI-MATERIAL ══
tower_colors = {
    "stone_light":  (0.52, 0.48, 0.40),
    "stone_mid":    (0.45, 0.40, 0.33),
    "stone_dark":   (0.32, 0.28, 0.22),
    "window_dark":  (0.06, 0.04, 0.03),
    "moss_green":   (0.28, 0.48, 0.18),
    "rubble":       (0.38, 0.34, 0.28),
}
mats = {}
for name, color in tower_colors.items():
    mat = bpy.data.materials.new(f"Tower_{name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.92
    mats[name] = mat

main.data.materials.clear()
mat_names = list(mats.keys())
for m in mats.values():
    main.data.materials.append(m)

for face in main.data.polygons:
    avg_z = sum(main.data.vertices[vi].co.z for vi in face.vertices) / len(face.vertices)
    avg_dist = sum(math.sqrt(main.data.vertices[vi].co.x**2 + main.data.vertices[vi].co.y**2) for vi in face.vertices) / len(face.vertices)

    # Rubble at base
    if avg_z < 1.5 and avg_dist > 3.0:
        face.material_index = mat_names.index("rubble")
    # Windows (very close to outer surface, small z bands)
    elif avg_dist > 3.0 and avg_z > 5:
        face.material_index = mat_names.index("window_dark")
    # Moss (outer surface)
    elif avg_dist > 3.1:
        face.material_index = mat_names.index("moss_green")
    # Upper tower
    elif avg_z > 18:
        face.material_index = mat_names.index("stone_light")
    elif avg_z > 10:
        face.material_index = mat_names.index("stone_mid")
    else:
        face.material_index = mat_names.index("stone_dark")

# ══ EXPORT ══
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
main.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True)

size = os.path.getsize(OUT)
print(json.dumps({"status":"ok","file":OUT,"size_kb":size//1024,"vertices":len(main.data.vertices),"faces":len(main.data.polygons)}))
print("[FORGE:TOWER] === DONE ===")
