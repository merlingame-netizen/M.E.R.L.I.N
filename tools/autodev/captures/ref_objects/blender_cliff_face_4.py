# Auto-generated Blender script for object 4: cliff_face
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("cliff_face_4")
obj = bpy.data.objects.new("cliff_face_4", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((5.06, 0, 0.73))))
top_verts.append(bm.verts.new(Vector((5.06, 3.0, 0.73))))
base_verts.append(bm.verts.new(Vector((3.71, 0, 2.13))))
top_verts.append(bm.verts.new(Vector((3.71, 3.0, 2.13))))
base_verts.append(bm.verts.new(Vector((3.20, 0, -1.02))))
top_verts.append(bm.verts.new(Vector((3.20, 3.0, -1.02))))
base_verts.append(bm.verts.new(Vector((1.82, 0, -0.55))))
top_verts.append(bm.verts.new(Vector((1.82, 3.0, -0.55))))
base_verts.append(bm.verts.new(Vector((1.11, 0, -2.38))))
top_verts.append(bm.verts.new(Vector((1.11, 3.0, -2.38))))
base_verts.append(bm.verts.new(Vector((1.04, 0, 2.38))))
top_verts.append(bm.verts.new(Vector((1.04, 3.0, 2.38))))
base_verts.append(bm.verts.new(Vector((-1.41, 0, -6.28))))
top_verts.append(bm.verts.new(Vector((-1.41, 3.0, -6.28))))
base_verts.append(bm.verts.new(Vector((-0.10, 0, -7.10))))
top_verts.append(bm.verts.new(Vector((-0.10, 3.0, -7.10))))
base_verts.append(bm.verts.new(Vector((-0.41, 0, -8.64))))
top_verts.append(bm.verts.new(Vector((-0.41, 3.0, -8.64))))
base_verts.append(bm.verts.new(Vector((1.56, 0, -6.99))))
top_verts.append(bm.verts.new(Vector((1.56, 3.0, -6.99))))

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

mat = bpy.data.materials.new("cliff_face_4_mat")
mat.use_nodes = False
mat.diffuse_color = (0.094, 0.094, 0.094, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/cliff_face_4.glb", export_format="GLB", use_selection=True)
print("Exported: cliff_face_4.glb")

# Dominant colors from reference (for vertex painting):
# #101010 (72.1%) -> (0.063, 0.063, 0.063)
# #303030 (17.9%) -> (0.188, 0.188, 0.188)
# #101030 (4.0%) -> (0.063, 0.063, 0.188)