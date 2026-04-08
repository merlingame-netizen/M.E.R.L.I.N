# Auto-generated Blender script for object 1: cliff_face
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("cliff_face_1")
obj = bpy.data.objects.new("cliff_face_1", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((2.54, 0, 7.50))))
top_verts.append(bm.verts.new(Vector((2.54, 3.0, 7.50))))
base_verts.append(bm.verts.new(Vector((-1.45, 0, -5.49))))
top_verts.append(bm.verts.new(Vector((-1.45, 3.0, -5.49))))
base_verts.append(bm.verts.new(Vector((-3.73, 0, -3.88))))
top_verts.append(bm.verts.new(Vector((-3.73, 3.0, -3.88))))
base_verts.append(bm.verts.new(Vector((-3.09, 0, -6.67))))
top_verts.append(bm.verts.new(Vector((-3.09, 3.0, -6.67))))
base_verts.append(bm.verts.new(Vector((0.62, 0, -3.81))))
top_verts.append(bm.verts.new(Vector((0.62, 3.0, -3.81))))
base_verts.append(bm.verts.new(Vector((1.09, 0, -9.68))))
top_verts.append(bm.verts.new(Vector((1.09, 3.0, -9.68))))
base_verts.append(bm.verts.new(Vector((4.38, 0, -2.81))))
top_verts.append(bm.verts.new(Vector((4.38, 3.0, -2.81))))
base_verts.append(bm.verts.new(Vector((2.77, 0, 4.42))))
top_verts.append(bm.verts.new(Vector((2.77, 3.0, 4.42))))
base_verts.append(bm.verts.new(Vector((1.45, 0, 1.06))))
top_verts.append(bm.verts.new(Vector((1.45, 3.0, 1.06))))

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

mat = bpy.data.materials.new("cliff_face_1_mat")
mat.use_nodes = False
mat.diffuse_color = (0.125, 0.122, 0.114, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/cliff_face_1.glb", export_format="GLB", use_selection=True)
print("Exported: cliff_face_1.glb")

# Dominant colors from reference (for vertex painting):
# #101010 (46.5%) -> (0.063, 0.063, 0.063)
# #303030 (32.3%) -> (0.188, 0.188, 0.188)
# #303010 (9.7%) -> (0.188, 0.188, 0.063)