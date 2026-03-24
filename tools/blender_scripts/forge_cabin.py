"""Forge: Cabin — Cube body + cone roof + chimney + door slab, 4 materials."""
import bpy, math, random, os, json

random.seed(33)
OUT = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast\cabin_unified.glb"

# Clear
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)

print("[FORGE:CABIN] Starting...")

# ══════════════════════════════════════════════════════════════
# 1. BUILD GEOMETRY
# ══════════════════════════════════════════════════════════════
parts = []

# Body — cube
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1.5))
body = bpy.context.active_object
body.name = "CabinBody"
body.scale = (3.0, 2.5, 3.0)
bpy.ops.object.transform_apply(scale=True)
parts.append(body)

# Roof — 4-sided cone
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=2.8, radius2=0.0, depth=2.5, location=(0, 0, 4.25))
roof = bpy.context.active_object
roof.name = "CabinRoof"
roof.scale = (1.15, 1.0, 1.0)
roof.rotation_euler = (0, 0, math.radians(45))
bpy.ops.object.transform_apply(scale=True, rotation=True)
parts.append(roof)

# Chimney — small cube on right side
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.2, 0.0, 4.8))
chimney = bpy.context.active_object
chimney.name = "Chimney"
chimney.scale = (0.5, 0.5, 1.5)
bpy.ops.object.transform_apply(scale=True)
parts.append(chimney)

# Door — thin slab on front face
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -1.26, 0.9))
door = bpy.context.active_object
door.name = "Door"
door.scale = (0.7, 0.08, 1.4)
bpy.ops.object.transform_apply(scale=True)
parts.append(door)

# ══════════════════════════════════════════════════════════════
# 2. JOIN ALL
# ══════════════════════════════════════════════════════════════
print(f"[FORGE:CABIN] Joining {len(parts)} objects...")
bpy.ops.object.select_all(action='DESELECT')
main = parts[0]
main.select_set(True)
for o in parts[1:]:
    o.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.object.join()
main.name = "Cabin"

# ══════════════════════════════════════════════════════════════
# 3. DECIMATE + FLAT SHADE
# ══════════════════════════════════════════════════════════════
mod = main.modifiers.new("Dec", "DECIMATE")
mod.ratio = 0.55
bpy.ops.object.modifier_apply(modifier="Dec")

for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:CABIN] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══════════════════════════════════════════════════════════════
# 4. MULTI-MATERIAL by height zone
# ══════════════════════════════════════════════════════════════
zone_colors = {
    "wood":    (0.45, 0.30, 0.15),   # Warm brown wood walls
    "roof":    (0.30, 0.18, 0.10),   # Dark brown roof
    "chimney": (0.40, 0.38, 0.35),   # Grey stone chimney
    "door":    (0.22, 0.12, 0.06),   # Dark oak door
}

mats = {}
for name, color in zone_colors.items():
    mat = bpy.data.materials.new(f"Cabin_{name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    mats[name] = mat

main.data.materials.clear()
mat_names = list(mats.keys())
for m in mats.values():
    main.data.materials.append(m)

for face in main.data.polygons:
    avg_z = sum(main.data.vertices[vi].co.z for vi in face.vertices) / len(face.vertices)
    avg_y = sum(main.data.vertices[vi].co.y for vi in face.vertices) / len(face.vertices)
    avg_x = sum(main.data.vertices[vi].co.x for vi in face.vertices) / len(face.vertices)

    # Chimney: high + right side
    if avg_z > 4.0 and avg_x > 0.8:
        face.material_index = mat_names.index("chimney")
    # Roof: above body
    elif avg_z > 3.0:
        face.material_index = mat_names.index("roof")
    # Door: low + front face
    elif avg_z < 1.8 and avg_y < -1.0:
        face.material_index = mat_names.index("door")
    # Wood walls
    else:
        face.material_index = mat_names.index("wood")

# ══════════════════════════════════════════════════════════════
# 5. EXPORT GLB
# ══════════════════════════════════════════════════════════════
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
main.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True)

size = os.path.getsize(OUT)
result = {
    "status": "ok",
    "file": OUT,
    "size_kb": size // 1024,
    "vertices": len(main.data.vertices),
    "faces": len(main.data.polygons),
    "materials": len(zone_colors),
}
print(json.dumps(result))
print("[FORGE:CABIN] === DONE ===")
