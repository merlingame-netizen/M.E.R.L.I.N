"""Forge: Crystal Clusters — 6 purple + 4 teal emission cones in 2 clusters."""
import bpy, math, random, os, json
from mathutils import Vector

random.seed(55)
OUT = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast\crystal_cluster_unified.glb"

# Clear
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)

print("[FORGE:CRYSTALS] Starting...")

# ══════════════════════════════════════════════════════════════
# 1. MATERIALS — purple emission + teal emission
# ══════════════════════════════════════════════════════════════
mat_purple = bpy.data.materials.new("Crystal_Purple")
mat_purple.use_nodes = True
bsdf_p = mat_purple.node_tree.nodes["Principled BSDF"]
bsdf_p.inputs["Base Color"].default_value = (0.55, 0.15, 0.85, 1.0)
bsdf_p.inputs["Roughness"].default_value = 0.25
bsdf_p.inputs["Emission Color"].default_value = (0.55, 0.15, 0.85, 1.0)
bsdf_p.inputs["Emission Strength"].default_value = 2.0

mat_teal = bpy.data.materials.new("Crystal_Teal")
mat_teal.use_nodes = True
bsdf_t = mat_teal.node_tree.nodes["Principled BSDF"]
bsdf_t.inputs["Base Color"].default_value = (0.10, 0.75, 0.65, 1.0)
bsdf_t.inputs["Roughness"].default_value = 0.25
bsdf_t.inputs["Emission Color"].default_value = (0.10, 0.75, 0.65, 1.0)
bsdf_t.inputs["Emission Strength"].default_value = 1.5

# ══════════════════════════════════════════════════════════════
# 2. BUILD CRYSTALS — 6 purple (cluster 1) + 4 teal (cluster 2)
# ══════════════════════════════════════════════════════════════
purple_specs = [
    # (x, y, z, radius, depth, tilt_x, tilt_y)
    ( 0.0,  0.0, 0.0, 0.4, 3.0,  5,  0),
    ( 0.8,  0.3, 0.0, 0.3, 2.4, -8, 10),
    (-0.6,  0.5, 0.0, 0.35, 2.8, 10, -5),
    ( 0.3, -0.7, 0.0, 0.25, 2.0,  0, 12),
    (-0.9, -0.3, 0.0, 0.3, 1.8, -6, -8),
    ( 1.1, -0.2, 0.0, 0.2, 1.5, 12,  5),
]

teal_specs = [
    ( 5.0,  0.0, 0.0, 0.35, 2.5,  -5,  3),
    ( 5.6,  0.5, 0.0, 0.28, 2.0,   8, -7),
    ( 4.5, -0.4, 0.0, 0.32, 2.2,  -3, 10),
    ( 5.3, -0.6, 0.0, 0.22, 1.6,  10,  5),
]

parts = []

for i, (x, y, z, rad, depth, tx, ty) in enumerate(purple_specs):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=rad, radius2=0.02, depth=depth, location=(x, y, z + depth / 2))
    c = bpy.context.active_object
    c.name = f"Purple_{i}"
    c.rotation_euler = (math.radians(tx), math.radians(ty), 0)
    bpy.ops.object.transform_apply(rotation=True)
    c.data.materials.append(mat_purple)
    parts.append(c)

for i, (x, y, z, rad, depth, tx, ty) in enumerate(teal_specs):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=rad, radius2=0.02, depth=depth, location=(x, y, z + depth / 2))
    c = bpy.context.active_object
    c.name = f"Teal_{i}"
    c.rotation_euler = (math.radians(tx), math.radians(ty), 0)
    bpy.ops.object.transform_apply(rotation=True)
    c.data.materials.append(mat_teal)
    parts.append(c)

# ══════════════════════════════════════════════════════════════
# 3. JOIN ALL + FLAT SHADE (no decimate)
# ══════════════════════════════════════════════════════════════
print(f"[FORGE:CRYSTALS] Joining {len(parts)} objects...")
bpy.ops.object.select_all(action='DESELECT')
main = parts[0]
main.select_set(True)
for o in parts[1:]:
    o.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.object.join()
main.name = "CrystalCluster"

for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:CRYSTALS] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══════════════════════════════════════════════════════════════
# 4. EXPORT GLB
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
    "materials": 2,
}
print(json.dumps(result))
print("[FORGE:CRYSTALS] === DONE ===")
