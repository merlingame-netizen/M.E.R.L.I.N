"""Forge: Ocean Rocks — 7 flattened icosphere rocks, merged, dark material."""
import bpy, bmesh, math, random, os, json
from mathutils import Vector

random.seed(77)
OUT = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast\rocks_set.glb"

# Clear
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)

print("[FORGE:ROCKS] Starting...")

# ══════════════════════════════════════════════════════════════
# 1. BUILD 7 ROCKS at ocean positions
# ══════════════════════════════════════════════════════════════
rock_specs = [
    # (x, y, z, radius, sx, sy, sz)
    (-18, -25, -0.5, 3.5, 1.3, 1.0, 0.45),
    (-10, -28, -0.8, 2.8, 1.1, 0.9, 0.40),
    ( -3, -26, -0.3, 4.0, 1.4, 1.1, 0.50),
    (  8, -30, -0.6, 3.2, 1.0, 1.2, 0.38),
    ( 16, -27, -0.4, 2.5, 1.2, 0.8, 0.42),
    ( 22, -32, -0.7, 3.8, 1.1, 1.0, 0.35),
    (  0, -34, -0.9, 2.0, 1.0, 1.0, 0.50),
]

parts = []
for i, (x, y, z, rad, sx, sy, sz) in enumerate(rock_specs):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=rad, location=(x, y, z))
    rock = bpy.context.active_object
    rock.name = f"Rock_{i}"
    rock.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    # Roughen vertices
    for v in rock.data.vertices:
        offset = v.co.normalized() * random.uniform(-0.4, 0.4)
        v.co += offset
    parts.append(rock)

# ══════════════════════════════════════════════════════════════
# 2. JOIN ALL
# ══════════════════════════════════════════════════════════════
print(f"[FORGE:ROCKS] Joining {len(parts)} objects...")
bpy.ops.object.select_all(action='DESELECT')
main = parts[0]
main.select_set(True)
for o in parts[1:]:
    o.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.object.join()
main.name = "RocksSet"

# ══════════════════════════════════════════════════════════════
# 3. DECIMATE + FLAT SHADE
# ══════════════════════════════════════════════════════════════
mod = main.modifiers.new("Dec", "DECIMATE")
mod.ratio = 0.4
bpy.ops.object.modifier_apply(modifier="Dec")

for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:ROCKS] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══════════════════════════════════════════════════════════════
# 4. SINGLE DARK MATERIAL
# ══════════════════════════════════════════════════════════════
mat = bpy.data.materials.new("Rock_Dark")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.30, 0.26, 0.20, 1.0)
bsdf.inputs["Roughness"].default_value = 0.92

main.data.materials.clear()
main.data.materials.append(mat)

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
    "materials": 1,
}
print(json.dumps(result))
print("[FORGE:ROCKS] === DONE ===")
