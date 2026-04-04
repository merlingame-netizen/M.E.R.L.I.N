"""
Blender headless — Druidic Table
Style: plateau hexagonal brun, 4 pieds angulaires tordus, < 150 polys
Palette: C_OAK (brun bois), C_OAK_DARK (grain sombre), C_METAL_DARK (métal)
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "table_druidique.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette sobre : 3 couleurs max ──────────────────────────────────────────
C_OAK        = (0.35, 0.20, 0.08, 1)
C_OAK_DARK   = (0.18, 0.10, 0.03, 1)
C_METAL_DARK = (0.10, 0.09, 0.08, 1)

def vcl(obj, name="Col"):
    if name not in obj.data.vertex_colors:
        obj.data.vertex_colors.new(name=name)
    return obj.data.vertex_colors[name]

def fill(obj, col):
    vc = vcl(obj)
    for loop in obj.data.loops:
        vc.data[loop.index].color = col

def paint_faces_z(obj, dark, light, split=0.5):
    vc = vcl(obj)
    mesh = obj.data
    h_min = min(v.co.z for v in mesh.vertices)
    h_max = max(v.co.z for v in mesh.vertices)
    h_range = max(h_max - h_min, 0.001)
    for poly in mesh.polygons:
        cz = sum(mesh.vertices[v].co.z for v in poly.vertices) / len(poly.vertices)
        t = (cz - h_min) / h_range
        col = light if t > split else dark
        for li in poly.loop_indices:
            vc.data[li].color = col

all_objects = []

# ── 1. Plateau hexagonal légèrement penché ───────────────────────────────────
SIDES = 6
R_TOP = 1.8
H_TOP = 0.12   # épaisseur plateau
Z_TOP = 1.5    # hauteur du plateau au-dessus du sol

bm = bmesh.new()
# Plateau légèrement penché : z varie selon l'angle (tilt ~4°)
TILT = 0.12
for i in range(SIDES):
    a = 2 * math.pi * i / SIDES
    jitter = [0.06, -0.05, 0.04, -0.06, 0.03, -0.04][i]
    r = R_TOP + jitter
    tz = Z_TOP + TILT * math.cos(a)   # inclinaison
    bz = tz - H_TOP
    bm.verts.new((r * math.cos(a), r * math.sin(a), tz))
    bm.verts.new((r * math.cos(a), r * math.sin(a), bz))

bm.verts.ensure_lookup_table()
# Face du dessus
top_vs = [bm.verts[i * 2] for i in range(SIDES)]
bot_vs = [bm.verts[i * 2 + 1] for i in range(SIDES)]
bm.faces.new(top_vs)
bm.faces.new(list(reversed(bot_vs)))
for i in range(SIDES):
    j = (i + 1) % SIDES
    bm.faces.new([top_vs[i], top_vs[j], bot_vs[j], bot_vs[i]])

bm.normal_update()
top_mesh = bpy.data.meshes.new("TableTop")
bm.to_mesh(top_mesh); bm.free()
top_obj = bpy.data.objects.new("TableTop", top_mesh)
bpy.context.scene.collection.objects.link(top_obj)
bpy.context.view_layer.objects.active = top_obj
bpy.ops.object.shade_flat()
paint_faces_z(top_obj, C_OAK_DARK, C_OAK, split=0.7)
all_objects.append(top_obj)

# ── 2. Quatre pieds angulaires légèrement tordus ─────────────────────────────
LEG_ANGLES = [45, 135, 225, 315]
LEG_W = 0.13
H_LEG = 1.5

for idx, ang_deg in enumerate(LEG_ANGLES):
    ang = math.radians(ang_deg)
    # Position pied = sous le plateau, légèrement décalé vers l'extérieur
    offset = R_TOP * 0.62
    cx = math.cos(ang) * offset
    cy = math.sin(ang) * offset
    # Torsion légère : le pied s'incline légèrement vers l'extérieur
    lean = 0.08
    dx = math.cos(ang) * lean
    dy = math.sin(ang) * lean

    bm2 = bmesh.new()
    # Section carrée en haut, légèrement pivotée en bas
    pivot = math.radians(8) * (1 if idx % 2 == 0 else -1)
    for k in range(4):
        a_top = ang + math.pi / 4 + k * math.pi / 2
        a_bot = ang + math.pi / 4 + k * math.pi / 2 + pivot
        bm2.verts.new((cx + LEG_W * math.cos(a_top),
                       cy + LEG_W * math.sin(a_top), Z_TOP - H_TOP * 0.5))
        bm2.verts.new((cx + dx + LEG_W * 0.7 * math.cos(a_bot),
                       cy + dy + LEG_W * 0.7 * math.sin(a_bot), 0.0))

    bm2.verts.ensure_lookup_table()
    top_l = [bm2.verts[k * 2] for k in range(4)]
    bot_l = [bm2.verts[k * 2 + 1] for k in range(4)]
    bm2.faces.new(top_l)
    bm2.faces.new(list(reversed(bot_l)))
    for k in range(4):
        l = (k + 1) % 4
        bm2.faces.new([top_l[k], top_l[l], bot_l[l], bot_l[k]])

    leg_mesh = bpy.data.meshes.new(f"Leg_{idx}")
    bm2.to_mesh(leg_mesh); bm2.free()
    leg_obj = bpy.data.objects.new(f"Leg_{idx}", leg_mesh)
    bpy.context.scene.collection.objects.link(leg_obj)
    bpy.context.view_layer.objects.active = leg_obj
    bpy.ops.object.shade_flat()
    paint_faces_z(leg_obj, C_OAK_DARK, C_OAK, split=0.55)
    all_objects.append(leg_obj)

# ── 3. Joindre ───────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
for o in all_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objects[0]
bpy.ops.object.join()
table = bpy.context.active_object
table.name = "Table_Druidique"

bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
table.location = (0, 0, 0)
bb = table.bound_box
h = max(v[2] for v in bb) - min(v[2] for v in bb)
if h > 0:
    sf = 2.0 / h
    table.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True, location=True)

# ── 4. Matériau vertex color ──────────────────────────────────────────────────
mat = bpy.data.materials.new("TableMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 0.98
bsdf.inputs["Metallic"].default_value = 0.0
out = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
table.data.materials.clear()
table.data.materials.append(mat)

# ── 5. Export ─────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
table.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(table.data.polygons)
vert = len(table.data.vertices)
print(f"\n[OK] Table Druidique -> {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
