# Auto-generated Blender script for object 5: cliff_face
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("cliff_face_5")
obj = bpy.data.objects.new("cliff_face_5", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((-10.00, 0, 1.45))))
top_verts.append(bm.verts.new(Vector((-10.00, 3.0, 1.45))))
base_verts.append(bm.verts.new(Vector((-2.15, 0, 0.84))))
top_verts.append(bm.verts.new(Vector((-2.15, 3.0, 0.84))))
base_verts.append(bm.verts.new(Vector((-0.16, 0, 3.38))))
top_verts.append(bm.verts.new(Vector((-0.16, 3.0, 3.38))))
base_verts.append(bm.verts.new(Vector((-9.36, 0, 3.42))))
top_verts.append(bm.verts.new(Vector((-9.36, 3.0, 3.42))))
base_verts.append(bm.verts.new(Vector((1.48, 0, 4.78))))
top_verts.append(bm.verts.new(Vector((1.48, 3.0, 4.78))))
base_verts.append(bm.verts.new(Vector((-5.76, 0, 6.46))))
top_verts.append(bm.verts.new(Vector((-5.76, 3.0, 6.46))))
base_verts.append(bm.verts.new(Vector((-3.81, 0, 4.92))))
top_verts.append(bm.verts.new(Vector((-3.81, 3.0, 4.92))))
base_verts.append(bm.verts.new(Vector((-10.00, 0, 4.88))))
top_verts.append(bm.verts.new(Vector((-10.00, 3.0, 4.88))))

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

mat = bpy.data.materials.new("cliff_face_5_mat")
mat.use_nodes = False
mat.diffuse_color = (0.447, 0.537, 0.643, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/cliff_face_5.glb", export_format="GLB", use_selection=True)
print("Exported: cliff_face_5.glb")

# Dominant colors from reference (for vertex painting):
# #7090b0 (67.8%) -> (0.439, 0.565, 0.690)
# #709090 (17.2%) -> (0.439, 0.565, 0.565)
# #707090 (8.6%) -> (0.439, 0.439, 0.565)