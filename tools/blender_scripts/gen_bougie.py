"""
Blender headless — Bougie/chandelier
Style: cylindre beige fin, flamme hexagonale jaune chaud, base métal sombre, < 30 polys
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "bougie.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette ─────────────────────────────────────────────────────────────────
C_WAX        = (0.82, 0.76, 0.55, 1)   # cire beige
C_FLAME      = (0.95, 0.55, 0.10, 1)   # flamme orange-jaune
C_METAL_DARK = (0.10, 0.09, 0.08, 1)
C_METAL_MID  = (0.20, 0.18, 0.15, 1)

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

# ── 1. Base en métal (hex plate) ──────────────────────────────────────────────
SIDES = 6
R_BASE = 0.28
H_BASE = 0.08

bm = bmesh.new()
bot_vs, top_vs = [], []
for i in range(SIDES):
    a = math.pi / 6 + i * math.pi / 3
    bot_vs.append(bm.verts.new((R_BASE * math.cos(a), R_BASE * math.sin(a), 0.0)))
    top_vs.append(bm.verts.new((R_BASE * 0.85 * math.cos(a), R_BASE * 0.85 * math.sin(a), H_BASE)))
bm.faces.new(list(reversed(bot_vs)))
bm.faces.new(top_vs)
for i in range(SIDES):
    j = (i + 1) % SIDES
    bm.faces.new([bot_vs[i], bot_vs[j], top_vs[j], top_vs[i]])
bm.normal_update()
base_mesh = bpy.data.meshes.new("Base")
bm.to_mesh(base_mesh); bm.free()
base_obj = bpy.data.objects.new("Base", base_mesh)
bpy.context.scene.collection.objects.link(base_obj)
bpy.context.view_layer.objects.active = base_obj
bpy.ops.object.shade_flat()
paint_faces_z(base_obj, C_METAL_DARK, C_METAL_MID, split=0.4)
all_objects.append(base_obj)

# ── 2. Corps de la bougie (cylindre hexagonal fin) ────────────────────────────
R_WAX = 0.12
H_WAX = 1.2
Z_WAX = H_BASE

bm2 = bmesh.new()
bot_w, top_w = [], []
for i in range(SIDES):
    a = math.pi / 6 + i * math.pi / 3
    # Légère irrégularité pour look fait main
    jitter = [0.01, -0.01, 0.02, -0.01, 0.01, -0.02][i]
    bot_w.append(bm2.verts.new(((R_WAX + jitter) * math.cos(a), (R_WAX + jitter) * math.sin(a), Z_WAX)))
    # Légèrement plus étroit en haut (fondu)
    top_w.append(bm2.verts.new(((R_WAX * 0.90 + jitter) * math.cos(a), (R_WAX * 0.90 + jitter) * math.sin(a), Z_WAX + H_WAX)))
bm2.faces.new(list(reversed(bot_w)))
bm2.faces.new(top_w)
for i in range(SIDES):
    j = (i + 1) % SIDES
    bm2.faces.new([bot_w[i], bot_w[j], top_w[j], top_w[i]])
bm2.normal_update()
wax_mesh = bpy.data.meshes.new("Wax")
bm2.to_mesh(wax_mesh); bm2.free()
wax_obj = bpy.data.objects.new("Wax", wax_mesh)
bpy.context.scene.collection.objects.link(wax_obj)
bpy.context.view_layer.objects.active = wax_obj
bpy.ops.object.shade_flat()
fill(wax_obj, C_WAX)
all_objects.append(wax_obj)

# ── 3. Flamme hexagonale (pyramide torsadée) ──────────────────────────────────
R_FLAME_BOT = 0.08
R_FLAME_TOP = 0.0   # pointe
H_FLAME = 0.30
Z_FLAME = Z_WAX + H_WAX

bm3 = bmesh.new()
flame_base = []
for i in range(SIDES):
    a = math.pi / 6 + i * math.pi / 3 + math.radians(15)  # légère rotation
    flame_base.append(bm3.verts.new((R_FLAME_BOT * math.cos(a), R_FLAME_BOT * math.sin(a), Z_FLAME)))
tip = bm3.verts.new((0.0, 0.0, Z_FLAME + H_FLAME))
bm3.faces.new(list(reversed(flame_base)))
for i in range(SIDES):
    j = (i + 1) % SIDES
    bm3.faces.new([flame_base[i], flame_base[j], tip])
bm3.normal_update()
flame_mesh = bpy.data.meshes.new("Flame")
bm3.to_mesh(flame_mesh); bm3.free()
flame_obj = bpy.data.objects.new("Flame", flame_mesh)
bpy.context.scene.collection.objects.link(flame_obj)
bpy.context.view_layer.objects.active = flame_obj
bpy.ops.object.shade_flat()
fill(flame_obj, C_FLAME)
all_objects.append(flame_obj)

# ── 4. Joindre ────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
for o in all_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objects[0]
bpy.ops.object.join()
candle = bpy.context.active_object
candle.name = "Bougie"

bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
candle.location = (0, 0, 0)
bb = candle.bound_box
h = max(v[2] for v in bb) - min(v[2] for v in bb)
if h > 0:
    sf = 1.5 / h
    candle.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True, location=True)

# ── 5. Matériau vertex color ──────────────────────────────────────────────────
mat = bpy.data.materials.new("BougieMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 0.90
bsdf.inputs["Metallic"].default_value = 0.0
out = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
candle.data.materials.clear()
candle.data.materials.append(mat)

# ── 6. Export ─────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
candle.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(candle.data.polygons)
vert = len(candle.data.vertices)
print(f"\n[OK] Bougie -> {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
