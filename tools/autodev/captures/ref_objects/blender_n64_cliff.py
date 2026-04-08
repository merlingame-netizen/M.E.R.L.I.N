# N64 Rocky Cliff — multi-face terrain from reference image colors
# Colors extracted: #504832 (brown), #201f1d (dark), #3c3725 (earth), #5e7483 (grey-blue)
import bpy, bmesh, math, random
from mathutils import Vector, noise

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Create base cliff mesh — subdivided plane displaced into cliff shape
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
cliff = bpy.context.active_object
cliff.name = "n64_cliff"

# Subdivide
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(cliff.data)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=8)
bmesh.update_edit_mesh(cliff.data)
bpy.ops.object.mode_set(mode='OBJECT')

# Displace vertices to create rocky cliff shape
random.seed(42)
for v in cliff.data.vertices:
    # Cliff rises on one side, drops on the other
    height = max(0, v.co.x * 0.8 + 2.0)  # Rising from left to right
    height += random.uniform(-0.3, 0.3)  # Rocky noise
    # Drop-off on the ocean side (negative X)
    if v.co.x < -3:
        height = max(-2, height - abs(v.co.x + 3) * 1.5)
    v.co.z = height
    # Forward-back variation
    v.co.z += math.sin(v.co.y * 0.5) * 0.4

# Stone materials — 4 colors from reference palette
colors = [
    ("stone_brown", (0.314, 0.282, 0.196)),   # #504832
    ("stone_dark", (0.125, 0.122, 0.114)),     # #201f1d
    ("stone_earth", (0.235, 0.216, 0.145)),    # #3c3725
    ("stone_grey", (0.369, 0.455, 0.514)),     # #5e7483
]
for name, color in colors:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = False
    mat.diffuse_color = (*color, 1.0)
    mat.roughness = 0.95
    cliff.data.materials.append(mat)

# Assign materials to faces randomly (N64 flat-shade variation)
random.seed(123)
for face in cliff.data.polygons:
    # Higher faces get lighter colors, lower get darker
    center_z = sum(cliff.data.vertices[v].co.z for v in face.vertices) / len(face.vertices)
    if center_z > 3:
        face.material_index = random.choice([0, 2])  # Brown/earth for top
    elif center_z > 0:
        face.material_index = random.choice([0, 1, 2, 3])  # Mixed for mid
    else:
        face.material_index = random.choice([1, 3])  # Dark/grey for ocean-facing

# Flat shade
bpy.ops.object.shade_flat()

# Export
export_path = "C:/Users/PGNK2128/Godot-MCP/Assets/3d_models/menu_coast/n64_cliff.glb"
bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True)
print(f"Exported: {export_path}")
