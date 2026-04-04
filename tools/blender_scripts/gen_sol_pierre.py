"""
Blender headless — Sol en dalles hexagonales
Style: dalles hex irrégulières, 2 tons gris-brun, joints sombres, < 150 polys
Dimensions: 20x20 unités Three.js
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "sol_pierre.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette ────────────────────────────────────────────────────────────────
C_STONE_DARK  = (0.14, 0.12, 0.10, 1)
C_STONE_MID   = (0.22, 0.19, 0.15, 1)
C_JOINT       = (0.09, 0.08, 0.07, 1)

def vcl(obj, name="Col"):
    if name not in obj.data.vertex_colors:
        obj.data.vertex_colors.new(name=name)
    return obj.data.vertex_colors[name]

def fill(obj, col):
    vc = vcl(obj)
    for loop in obj.data.loops:
        vc.data[loop.index].color = col

all_objects = []

def make_hex_tile(name, cx, cy, r, z_off, col):
    """Dalle hexagonale plate avec léger jitter de sommet."""
    bm = bmesh.new()
    verts = []
    jitters = [0.04, -0.03, 0.05, -0.04, 0.03, -0.05]
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        rj = r + jitters[i % 6] * r
        verts.append(bm.verts.new((cx + rj * math.cos(a), cy + rj * math.sin(a), z_off)))
    center = bm.verts.new((cx, cy, z_off + 0.02))
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new([verts[i], verts[j], center])
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_flat()
    fill(obj, col)
    return obj

# Grille hexagonale — taille terrain ~20x20 Three.js units
# On normalise à Blender units, échelle appliquée post-export
TILE_R = 2.6   # rayon dalle (plus grands pour couvrir avec moins de tuiles)
GAP    = 0.12  # joint

# Disposition hex: colonnes décalées — 4x4 = 16 tuiles x 6 tris = 96 polys
COLS = 4
ROWS = 4
dx = TILE_R * 2 * math.cos(math.pi / 6) + GAP
dy = TILE_R * 1.5 + GAP * 0.5

# Alternance couleurs basée sur (row+col) % 2
colors = [C_STONE_DARK, C_STONE_MID]

tile_idx = 0
for row in range(ROWS):
    for col in range(COLS):
        cx = col * dx + (0.5 * dx if row % 2 == 1 else 0) - (COLS * dx) / 2
        cy = row * dy - (ROWS * dy) / 2
        col_choice = colors[(row + col) % 2]
        # Légère variation de hauteur pour irrégularité
        z_var = [(0.0, 0.01, -0.01, 0.02, 0.0, -0.02, 0.01)[tile_idx % 7]][0]
        all_objects.append(make_hex_tile(f"Tile_{tile_idx}", cx, cy, TILE_R, z_var, col_choice))
        tile_idx += 1

# Plan de base joint (rectangle plat légèrement sous les dalles)
bm_base = bmesh.new()
hw = COLS * dx / 2 + TILE_R
hd = ROWS * dy / 2 + TILE_R
bv = [
    bm_base.verts.new((-hw, -hd, -0.05)),
    bm_base.verts.new(( hw, -hd, -0.05)),
    bm_base.verts.new(( hw,  hd, -0.05)),
    bm_base.verts.new((-hw,  hd, -0.05)),
]
bm_base.faces.new(bv)
bm_base.normal_update()
base_mesh = bpy.data.meshes.new("FloorBase")
bm_base.to_mesh(base_mesh); bm_base.free()
base_obj = bpy.data.objects.new("FloorBase", base_mesh)
bpy.context.scene.collection.objects.link(base_obj)
bpy.context.view_layer.objects.active = base_obj
bpy.ops.object.shade_flat()
fill(base_obj, C_JOINT)
all_objects.append(base_obj)

# ── Joindre ───────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
for o in all_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objects[0]
bpy.ops.object.join()
floor = bpy.context.active_object
floor.name = "Sol_Pierre"

bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
floor.location = (0, 0, 0)
# Normaliser à 20x20 Blender units
bb = floor.bound_box
wx = max(v[0] for v in bb) - min(v[0] for v in bb)
if wx > 0:
    sf = 20.0 / wx
    floor.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True, location=True)

# ── Matériau vertex color ──────────────────────────────────────────────────────
mat = bpy.data.materials.new("SolMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 1.0
bsdf.inputs["Metallic"].default_value = 0.0
out = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
floor.data.materials.clear()
floor.data.materials.append(mat)

# ── Export ─────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
floor.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(floor.data.polygons)
vert = len(floor.data.vertices)
print(f"\n[OK] Sol Pierre -> {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
