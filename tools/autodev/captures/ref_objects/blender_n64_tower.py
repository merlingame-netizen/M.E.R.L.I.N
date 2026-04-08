# N64 Cylindrical Stone Tower — from reference image pixel analysis
# Colors: dark stone grey-brown extracted from reference cliff zones
import bpy, bmesh, math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Tower body — cylinder, N64 low-poly (8 sides)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.8, depth=5.0, location=(0, 2.5, 0))
tower_body = bpy.context.active_object
tower_body.name = "n64_tower"

# Stone material — pixel-perfect from reference cliff (#3c3725 = rgb 60,55,37)
mat_stone = bpy.data.materials.new("tower_stone")
mat_stone.use_nodes = False
mat_stone.diffuse_color = (0.235, 0.216, 0.145, 1.0)
mat_stone.roughness = 0.95
tower_body.data.materials.append(mat_stone)

# Top crenellations ring — wider cylinder, short
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.95, depth=0.4, location=(0, 5.2, 0))
top_ring = bpy.context.active_object
top_ring.name = "tower_top"
mat_top = bpy.data.materials.new("tower_top_stone")
mat_top.use_nodes = False
mat_top.diffuse_color = (0.28, 0.26, 0.20, 1.0)
mat_top.roughness = 0.9
top_ring.data.materials.append(mat_top)

# Crenellation notches — 4 box cuts at top
for i in range(4):
    angle = i * math.pi / 2
    x = math.cos(angle) * 0.85
    z = math.sin(angle) * 0.85
    bpy.ops.mesh.primitive_cube_add(size=0.35, location=(x, 5.55, z))
    notch = bpy.context.active_object
    notch.name = f"crenellation_{i}"
    notch.data.materials.append(mat_top)

# Door arch — small box indentation
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.8, 0.6, 0), scale=(0.05, 0.4, 0.25))
door = bpy.context.active_object
door.name = "door"
mat_door = bpy.data.materials.new("tower_door")
mat_door.use_nodes = False
mat_door.diffuse_color = (0.12, 0.10, 0.08, 1.0)
mat_door.roughness = 1.0
door.data.materials.append(mat_door)

# Window slit
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 3.2, 0.82), scale=(0.08, 0.2, 0.02))
window = bpy.context.active_object
window.name = "window"
window.data.materials.append(mat_door)

# Select all tower parts and join
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = tower_body
bpy.ops.object.join()

# Flat shade for N64 look
bpy.ops.object.shade_flat()

# Export GLB
export_path = "C:/Users/PGNK2128/Godot-MCP/Assets/3d_models/menu_coast/n64_tower.glb"
bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True)
print(f"Exported: {export_path}")
