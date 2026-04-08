# Auto-generated Blender script for object 6: terrain
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("terrain_6")
obj = bpy.data.objects.new("terrain_6", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((9.98, 0, 5.74))))
top_verts.append(bm.verts.new(Vector((9.98, 2.0, 5.74))))
base_verts.append(bm.verts.new(Vector((3.98, 0, 3.81))))
top_verts.append(bm.verts.new(Vector((3.98, 2.0, 3.81))))
base_verts.append(bm.verts.new(Vector((2.11, 0, -0.41))))
top_verts.append(bm.verts.new(Vector((2.11, 2.0, -0.41))))
base_verts.append(bm.verts.new(Vector((3.34, 0, -0.45))))
top_verts.append(bm.verts.new(Vector((3.34, 2.0, -0.45))))
base_verts.append(bm.verts.new(Vector((4.24, 0, 3.02))))
top_verts.append(bm.verts.new(Vector((4.24, 2.0, 3.02))))
base_verts.append(bm.verts.new(Vector((8.69, 0, -1.45))))
top_verts.append(bm.verts.new(Vector((8.69, 2.0, -1.45))))
base_verts.append(bm.verts.new(Vector((7.62, 0, 2.16))))
top_verts.append(bm.verts.new(Vector((7.62, 2.0, 2.16))))
base_verts.append(bm.verts.new(Vector((9.98, 0, 1.38))))
top_verts.append(bm.verts.new(Vector((9.98, 2.0, 1.38))))
base_verts.append(bm.verts.new(Vector((9.98, 0, 4.13))))
top_verts.append(bm.verts.new(Vector((9.98, 2.0, 4.13))))
base_verts.append(bm.verts.new(Vector((7.73, 0, 3.95))))
top_verts.append(bm.verts.new(Vector((7.73, 2.0, 3.95))))

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

mat = bpy.data.materials.new("terrain_6_mat")
mat.use_nodes = False
mat.diffuse_color = (0.235, 0.216, 0.145, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/terrain_6.glb", export_format="GLB", use_selection=True)
print("Exported: terrain_6.glb")

# Dominant colors from reference (for vertex painting):
# #505030 (24.5%) -> (0.314, 0.314, 0.188)
# #303010 (20.8%) -> (0.188, 0.188, 0.063)
# #303030 (19.4%) -> (0.188, 0.188, 0.188)