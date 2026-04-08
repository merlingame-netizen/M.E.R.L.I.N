# Auto-generated Blender script for object 2: ocean
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("ocean_2")
obj = bpy.data.objects.new("ocean_2", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((-8.95, 0, -9.96))))
top_verts.append(bm.verts.new(Vector((-8.95, 0.3, -9.96))))
base_verts.append(bm.verts.new(Vector((-1.68, 0, -1.06))))
top_verts.append(bm.verts.new(Vector((-1.68, 0.3, -1.06))))
base_verts.append(bm.verts.new(Vector((-10.00, 0, 0.23))))
top_verts.append(bm.verts.new(Vector((-10.00, 0.3, 0.23))))
base_verts.append(bm.verts.new(Vector((-10.00, 0, -4.74))))
top_verts.append(bm.verts.new(Vector((-10.00, 0.3, -4.74))))
base_verts.append(bm.verts.new(Vector((-9.02, 0, -4.53))))
top_verts.append(bm.verts.new(Vector((-9.02, 0.3, -4.53))))
base_verts.append(bm.verts.new(Vector((-10.00, 0, -5.85))))
top_verts.append(bm.verts.new(Vector((-10.00, 0.3, -5.85))))
base_verts.append(bm.verts.new(Vector((-6.86, 0, -6.14))))
top_verts.append(bm.verts.new(Vector((-6.86, 0.3, -6.14))))

bm.verts.ensure_lookup_table()
n = len(base_verts)
if n >= 3:
    try: bm.faces.new(base_verts)
    except: pass
    try: bm.faces.new(list(reversed(top_verts)))
    except: pass
for i in range(n):
    j = (i + 1) % n
    try: bm.faces.new([base_verts[i], base_verts[j], top_verts[j], top_verts[i]])
    except: pass

bm.to_mesh(mesh)
bm.free()

mat = bpy.data.materials.new("ocean_2_mat")
mat.use_nodes = False
mat.diffuse_color = (0.212, 0.341, 0.376, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/ocean_2.glb", export_format="GLB", use_selection=True)
print("Exported: ocean_2.glb")

# Dominant colors from reference (for vertex painting):
# #305050 (45.5%) -> (0.188, 0.314, 0.314)
# #305070 (26.0%) -> (0.188, 0.314, 0.439)
# #507070 (13.2%) -> (0.314, 0.439, 0.439)