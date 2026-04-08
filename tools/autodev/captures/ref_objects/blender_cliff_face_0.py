# Auto-generated Blender script for object 0: cliff_face
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("cliff_face_0")
obj = bpy.data.objects.new("cliff_face_0", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((2.50, 0, 6.06))))
top_verts.append(bm.verts.new(Vector((2.50, 3.0, 6.06))))
base_verts.append(bm.verts.new(Vector((1.56, 0, 1.38))))
top_verts.append(bm.verts.new(Vector((1.56, 3.0, 1.38))))
base_verts.append(bm.verts.new(Vector((5.98, 0, -0.55))))
top_verts.append(bm.verts.new(Vector((5.98, 3.0, -0.55))))
base_verts.append(bm.verts.new(Vector((1.95, 0, -6.82))))
top_verts.append(bm.verts.new(Vector((1.95, 3.0, -6.82))))
base_verts.append(bm.verts.new(Vector((8.22, 0, -8.93))))
top_verts.append(bm.verts.new(Vector((8.22, 3.0, -8.93))))
base_verts.append(bm.verts.new(Vector((7.27, 0, -6.99))))
top_verts.append(bm.verts.new(Vector((7.27, 3.0, -6.99))))
base_verts.append(bm.verts.new(Vector((8.69, 0, -8.28))))
top_verts.append(bm.verts.new(Vector((8.69, 3.0, -8.28))))
base_verts.append(bm.verts.new(Vector((9.47, 0, -4.60))))
top_verts.append(bm.verts.new(Vector((9.47, 3.0, -4.60))))
base_verts.append(bm.verts.new(Vector((5.16, 0, 1.56))))
top_verts.append(bm.verts.new(Vector((5.16, 3.0, 1.56))))
base_verts.append(bm.verts.new(Vector((6.84, 0, 3.35))))
top_verts.append(bm.verts.new(Vector((6.84, 3.0, 3.35))))

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

mat = bpy.data.materials.new("cliff_face_0_mat")
mat.use_nodes = False
mat.diffuse_color = (0.314, 0.282, 0.196, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/cliff_face_0.glb", export_format="GLB", use_selection=True)
print("Exported: cliff_face_0.glb")

# Dominant colors from reference (for vertex painting):
# #505030 (30.2%) -> (0.314, 0.314, 0.188)
# #707050 (14.5%) -> (0.439, 0.439, 0.314)
# #303010 (8.4%) -> (0.188, 0.188, 0.063)