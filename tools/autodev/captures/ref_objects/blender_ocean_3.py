# Auto-generated Blender script for object 3: ocean
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("ocean_3")
obj = bpy.data.objects.new("ocean_3", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((-10.00, 0, -2.56))))
top_verts.append(bm.verts.new(Vector((-10.00, 0.3, -2.56))))
base_verts.append(bm.verts.new(Vector((-3.75, 0, -1.56))))
top_verts.append(bm.verts.new(Vector((-3.75, 0.3, -1.56))))
base_verts.append(bm.verts.new(Vector((-6.74, 0, -7.39))))
top_verts.append(bm.verts.new(Vector((-6.74, 0.3, -7.39))))
base_verts.append(bm.verts.new(Vector((-3.24, 0, -9.00))))
top_verts.append(bm.verts.new(Vector((-3.24, 0.3, -9.00))))
base_verts.append(bm.verts.new(Vector((-4.92, 0, -4.81))))
top_verts.append(bm.verts.new(Vector((-4.92, 0.3, -4.81))))
base_verts.append(bm.verts.new(Vector((-0.23, 0, 0.30))))
top_verts.append(bm.verts.new(Vector((-0.23, 0.3, 0.30))))
base_verts.append(bm.verts.new(Vector((-10.00, 0, 1.02))))
top_verts.append(bm.verts.new(Vector((-10.00, 0.3, 1.02))))

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

mat = bpy.data.materials.new("ocean_3_mat")
mat.use_nodes = False
mat.diffuse_color = (0.267, 0.408, 0.435, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/ocean_3.glb", export_format="GLB", use_selection=True)
print("Exported: ocean_3.glb")

# Dominant colors from reference (for vertex painting):
# #507070 (50.9%) -> (0.314, 0.439, 0.439)
# #305070 (18.3%) -> (0.188, 0.314, 0.439)
# #307070 (11.5%) -> (0.188, 0.439, 0.439)