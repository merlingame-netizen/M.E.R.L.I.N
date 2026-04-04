"""
Blender headless — Mur en pierre (module réutilisable)
Style: rangées de pierres irrégulières, 2 tons pierre très sombre, < 150 polys
Dimensions: hauteur 12 unités, largeur 24 unités
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "mur_pierre.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette ────────────────────────────────────────────────────────────────
C_STONE_V_DARK = (0.10, 0.09, 0.08, 1)
C_STONE_DARK   = (0.16, 0.14, 0.11, 1)
C_JOINT        = (0.07, 0.06, 0.05, 1)

def vcl(obj, name="Col"):
    if name not in obj.data.vertex_colors:
        obj.data.vertex_colors.new(name=name)
    return obj.data.vertex_colors[name]

def fill(obj, col):
    vc = vcl(obj)
    for loop in obj.data.loops:
        vc.data[loop.index].color = col

all_objects = []

WALL_W = 24.0
WALL_H = 12.0
WALL_D = 0.6

def make_stone(name, x, z, w, h, d, col):
    bm = bmesh.new()
    verts = [
        bm.verts.new((x,     0,     z    )),
        bm.verts.new((x + w, 0,     z    )),
        bm.verts.new((x + w, d,     z    )),
        bm.verts.new((x,     d,     z    )),
        bm.verts.new((x,     0,     z + h)),
        bm.verts.new((x + w, 0,     z + h)),
        bm.verts.new((x + w, d,     z + h)),
        bm.verts.new((x,     d,     z + h)),
    ]
    faces = [
        [0,1,2,3],[4,7,6,5],
        [0,4,5,1],[2,6,7,3],
        [0,3,7,4],[1,5,6,2],
    ]
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_flat()
    fill(obj, col)
    return obj

# ── Plan de fond (joints) ─────────────────────────────────────────────────────
all_objects.append(make_stone("WallBg", -WALL_W/2, 0, WALL_W, WALL_H, WALL_D * 0.85, C_JOINT))

# ── Rangées de pierres (5 rangées x 4 pierres = 20 pierres x 6 faces = 120 polys + fond) ──
# 5 rangées, hauteurs variables
row_data = [
    # (z_start, z_height, [(x_start, x_width, color), ...])
    (0.06,   2.20, [(-11.9, 5.8, C_STONE_V_DARK), (-5.9, 6.2, C_STONE_DARK), (0.5, 5.6, C_STONE_V_DARK), (6.3, 5.5, C_STONE_DARK)]),
    (2.38,   2.10, [(-11.9, 6.4, C_STONE_DARK), (-5.3, 5.8, C_STONE_V_DARK), (0.7, 6.0, C_STONE_DARK), (6.9, 5.0, C_STONE_V_DARK)]),
    (4.60,   2.30, [(-11.9, 5.6, C_STONE_V_DARK), (-6.1, 6.4, C_STONE_DARK), (0.5, 5.8, C_STONE_V_DARK), (6.5, 5.3, C_STONE_DARK)]),
    (7.02,   2.15, [(-11.9, 6.0, C_STONE_DARK), (-5.7, 5.9, C_STONE_V_DARK), (0.4, 6.2, C_STONE_DARK), (6.8, 5.0, C_STONE_V_DARK)]),
    (9.29,   2.65, [(-11.9, 5.9, C_STONE_V_DARK), (-5.8, 6.1, C_STONE_DARK), (0.5, 5.7, C_STONE_V_DARK), (6.4, 5.4, C_STONE_DARK)]),
]

stone_idx = 0
for z_start, z_h, stones in row_data:
    for x_start, x_w, col in stones:
        all_objects.append(make_stone(
            f"S_{stone_idx}", x_start, z_start, x_w, z_h, WALL_D - 0.04, col
        ))
        stone_idx += 1

# ── Joindre ────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
for o in all_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objects[0]
bpy.ops.object.join()
wall = bpy.context.active_object
wall.name = "Mur_Pierre"

bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
wall.location = (0, 0, 0)
bpy.ops.object.transform_apply(scale=True, location=True)

# ── Matériau vertex color ──────────────────────────────────────────────────────
mat = bpy.data.materials.new("MurMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 1.0
bsdf.inputs["Metallic"].default_value = 0.0
out = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
wall.data.materials.clear()
wall.data.materials.append(mat)

# ── Export ─────────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
wall.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(wall.data.polygons)
vert = len(wall.data.vertices)
print(f"\n[OK] Mur Pierre -> {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
