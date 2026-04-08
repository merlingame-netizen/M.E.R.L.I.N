# Auto-generated Blender script for object 7: terrain
# Pixel-perfect colors extracted from reference image
import bpy, bmesh
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

mesh = bpy.data.meshes.new("terrain_7")
obj = bpy.data.objects.new("terrain_7", mesh)
bpy.context.collection.objects.link(obj)

bm = bmesh.new()
base_verts = []
top_verts = []
base_verts.append(bm.verts.new(Vector((4.61, 0, 1.02))))
top_verts.append(bm.verts.new(Vector((4.61, 2.0, 1.02))))
base_verts.append(bm.verts.new(Vector((2.64, 0, -5.74))))
top_verts.append(bm.verts.new(Vector((2.64, 2.0, -5.74))))
base_verts.append(bm.verts.new(Vector((-1.91, 0, -9.32))))
top_verts.append(bm.verts.new(Vector((-1.91, 2.0, -9.32))))
base_verts.append(bm.verts.new(Vector((2.34, 0, -9.96))))
top_verts.append(bm.verts.new(Vector((2.34, 2.0, -9.96))))
base_verts.append(bm.verts.new(Vector((2.09, 0, -7.75))))
top_verts.append(bm.verts.new(Vector((2.09, 2.0, -7.75))))
base_verts.append(bm.verts.new(Vector((4.84, 0, -9.50))))
top_verts.append(bm.verts.new(Vector((4.84, 2.0, -9.50))))
base_verts.append(bm.verts.new(Vector((3.61, 0, -8.14))))
top_verts.append(bm.verts.new(Vector((3.61, 2.0, -8.14))))
base_verts.append(bm.verts.new(Vector((4.22, 0, -6.31))))
top_verts.append(bm.verts.new(Vector((4.22, 2.0, -6.31))))
base_verts.append(bm.verts.new(Vector((2.99, 0, -7.21))))
top_verts.append(bm.verts.new(Vector((2.99, 2.0, -7.21))))
base_verts.append(bm.verts.new(Vector((6.04, 0, -3.99))))
top_verts.append(bm.verts.new(Vector((6.04, 2.0, -3.99))))
base_verts.append(bm.verts.new(Vector((4.51, 0, -3.85))))
top_verts.append(bm.verts.new(Vector((4.51, 2.0, -3.85))))
base_verts.append(bm.verts.new(Vector((5.33, 0, -1.99))))
top_verts.append(bm.verts.new(Vector((5.33, 2.0, -1.99))))

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

mat = bpy.data.materials.new("terrain_7_mat")
mat.use_nodes = False
mat.diffuse_color = (0.235, 0.216, 0.137, 1.0)
mat.roughness = 0.9
obj.data.materials.append(mat)

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=r"C:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/ref_objects/terrain_7.glb", export_format="GLB", use_selection=True)
print("Exported: terrain_7.glb")

# Dominant colors from reference (for vertex painting):
# #505030 (26.2%) -> (0.314, 0.314, 0.188)
# #303010 (22.3%) -> (0.188, 0.188, 0.063)
# #303030 (14.5%) -> (0.188, 0.188, 0.188)