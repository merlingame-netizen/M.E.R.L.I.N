"""
Blender headless — Merlin's Cauldron v3
Style: Rustique druidique — bois brun + métal sombre, twisted, < 150 polys
Palette sobre : 3 tons max. Pas de particules (objets séparés).
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "cauldron_merlin.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette sobre : 3 couleurs max ────────────────────────────────────────────
C_METAL_DARK  = (0.10, 0.09, 0.08, 1)   # fer sombre, presque noir
C_METAL_MID   = (0.20, 0.18, 0.15, 1)   # fer éclairé, chaud et sombre
C_OAK         = (0.35, 0.20, 0.08, 1)   # bois brun rustique (jambes, cerclage)

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
        t  = (cz - h_min) / h_range   # 0 = bottom, 1 = top
        col = light if t > split else dark
        for li in poly.loop_indices:
            vc.data[li].color = col


# ── 1. Bowl — hexagone (6 côtés), profond, légèrement tordu ──────────────────
SIDES = 6
R_TOP = 1.0
R_BOT = 0.58
H_BOW = 1.05    # profond pour un vrai chaudron

bm = bmesh.new()
bot_vs, top_vs = [], []
for i in range(SIDES):
    a = 2 * math.pi * i / SIDES
    # Léger offset aléatoire déterministe pour briser la symétrie parfaite
    jitter = [0.04, -0.03, 0.05, -0.02, 0.03, -0.04][i]
    bot_vs.append(bm.verts.new(((R_BOT + jitter*0.3) * math.cos(a),
                                (R_BOT + jitter*0.3) * math.sin(a), 0.0)))
    # Twist : décaler légèrement chaque vertex du haut (10° total)
    a_twist = a + math.radians(10) * i / (SIDES - 1)
    jitter_t = [0.03, -0.05, 0.02, -0.04, 0.06, -0.02][i]
    top_vs.append(bm.verts.new(((R_TOP + jitter_t*0.2) * math.cos(a_twist),
                                (R_TOP + jitter_t*0.2) * math.sin(a_twist), H_BOW)))

# Side faces
for i in range(SIDES):
    j = (i + 1) % SIDES
    bm.faces.new([bot_vs[i], bot_vs[j], top_vs[j], top_vs[i]])
# Bottom cap
bm.faces.new(list(reversed(bot_vs)))
bm.normal_update()

bowl_mesh = bpy.data.meshes.new("Bowl")
bm.to_mesh(bowl_mesh); bm.free()
bowl_obj = bpy.data.objects.new("Bowl", bowl_mesh)
bpy.context.scene.collection.objects.link(bowl_obj)
bpy.context.view_layer.objects.active = bowl_obj
bpy.ops.object.shade_flat()
# Peindre : bas sombre, haut moins sombre (chaleur métal)
paint_faces_z(bowl_obj, C_METAL_DARK, C_METAL_MID, split=0.45)


# ── 2. Cerclage bois — anneau hexagonal à mi-hauteur (brun) ──────────────────
#    Comme un tonneau cerclé : bande de bois entourant le chaudron

bm2 = bmesh.new()
Z_BAND = H_BOW * 0.52   # mi-hauteur
BW     = 0.10            # largeur bande
# Rayon band = interpolation linéaire bol à Z_BAND + marge claire
t_band = Z_BAND / H_BOW
R_AT_BAND = R_BOT + (R_TOP - R_BOT) * t_band + 0.08   # +8% = clairement extérieur

for i in range(SIDES):
    a = 2 * math.pi * i / SIDES   # mêmes angles que le bol (pas de twist indépendant)
    bm2.verts.new((R_AT_BAND * math.cos(a), R_AT_BAND * math.sin(a), Z_BAND - BW/2))
    bm2.verts.new((R_AT_BAND * math.cos(a), R_AT_BAND * math.sin(a), Z_BAND + BW/2))

bm2.verts.ensure_lookup_table()
for i in range(SIDES):
    j = (i + 1) % SIDES
    i0,i1,j0,j1 = i*2, i*2+1, j*2, j*2+1
    bm2.faces.new([bm2.verts[i0], bm2.verts[j0], bm2.verts[j1], bm2.verts[i1]])

band_mesh = bpy.data.meshes.new("Band")
bm2.to_mesh(band_mesh); bm2.free()
band_obj = bpy.data.objects.new("Band", band_mesh)
bpy.context.scene.collection.objects.link(band_obj)
bpy.context.view_layer.objects.active = band_obj
bpy.ops.object.shade_flat()
fill(band_obj, C_OAK)


# ── 3. Rebord — anneau plat, bois brun ────────────────────────────────────────

bm3 = bmesh.new()
R_IN  = R_TOP * 0.90
R_OUT = R_TOP * 1.10
Z_RIM = H_BOW + 0.0

for i in range(SIDES):
    a = 2 * math.pi * i / SIDES + math.radians(10)  # twist cohérent
    bm3.verts.new((R_IN  * math.cos(a), R_IN  * math.sin(a), Z_RIM + 0.05))
    bm3.verts.new((R_OUT * math.cos(a), R_OUT * math.sin(a), Z_RIM))

bm3.verts.ensure_lookup_table()
for i in range(SIDES):
    j = (i + 1) % SIDES
    i0,i1,j0,j1 = i*2, i*2+1, j*2, j*2+1
    bm3.faces.new([bm3.verts[i0], bm3.verts[j0], bm3.verts[j1], bm3.verts[i1]])

rim_mesh = bpy.data.meshes.new("Rim")
bm3.to_mesh(rim_mesh); bm3.free()
rim_obj = bpy.data.objects.new("Rim", rim_mesh)
bpy.context.scene.collection.objects.link(rim_obj)
bpy.context.view_layer.objects.active = rim_obj
bpy.ops.object.shade_flat()
fill(rim_obj, C_OAK)


# ── 4. Trois jambes bois — triangulaires, épaisses, irrégulières ──────────────

leg_objects = []
for idx, angle_deg in enumerate([20, 140, 260]):
    angle = math.radians(angle_deg)

    # Ancrage sur la surface extérieure du bol à z=TOP_Z
    # Rayon du bol à cette hauteur = interpolation linéaire R_BOT → R_TOP
    TOP_Z    = 0.30                                         # hauteur d'ancrage sur le bol
    R_AT_TOP = R_BOT + (R_TOP - R_BOT) * (TOP_Z / H_BOW)  # ≈ 0.70
    R_L      = [0.12, 0.11, 0.115][idx]                    # fin → collé au bol
    # Centre de la jambe = surface bol + demi-épaisseur (contact extérieur)
    offset_r = R_AT_TOP + R_L * 0.6
    rx = math.cos(angle) * offset_r
    ry = math.sin(angle) * offset_r

    bm4 = bmesh.new()
    H_L   = 0.70
    TAP   = 0.55

    top_vs_l, bot_vs_l = [], []
    for k in range(3):
        a2 = angle + 2 * math.pi * k / 3
        top_vs_l.append(bm4.verts.new((rx + R_L * math.cos(a2),
                                       ry + R_L * math.sin(a2), TOP_Z)))
        bot_vs_l.append(bm4.verts.new((rx + R_L * TAP * math.cos(a2),
                                       ry + R_L * TAP * math.sin(a2), -H_L)))

    for k in range(3):
        l = (k + 1) % 3
        bm4.faces.new([top_vs_l[k], top_vs_l[l], bot_vs_l[l], bot_vs_l[k]])
    bm4.faces.new(top_vs_l)
    bm4.faces.new(list(reversed(bot_vs_l)))

    leg_mesh = bpy.data.meshes.new(f"Leg_{idx}")
    bm4.to_mesh(leg_mesh); bm4.free()
    leg_obj = bpy.data.objects.new(f"Leg_{idx}", leg_mesh)
    bpy.context.scene.collection.objects.link(leg_obj)
    bpy.context.view_layer.objects.active = leg_obj
    bpy.ops.object.shade_flat()
    paint_faces_z(leg_obj, (0.18, 0.10, 0.03, 1), C_OAK, split=0.5)
    leg_objects.append(leg_obj)


# ── 5. Joindre ────────────────────────────────────────────────────────────────

all_parts = [bowl_obj, band_obj, rim_obj] + leg_objects
bpy.ops.object.select_all(action='DESELECT')
for o in all_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = bowl_obj
bpy.ops.object.join()
cauldron = bpy.context.active_object
cauldron.name = "Cauldron_Merlin"

# Repositionner : jambes sous le sol, bol au-dessus
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
cauldron.location = (0, 0, 0)

bb = cauldron.bound_box
h  = max(v[2] for v in bb) - min(v[2] for v in bb)
if h > 0:
    sf = 2.0 / h
    cauldron.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True, location=True)

# ── 6. Matériau vertex color ──────────────────────────────────────────────────

mat = bpy.data.materials.new("CauldronMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 0.95
bsdf.inputs["Metallic"].default_value  = 0.0
out  = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"],  out.inputs["Surface"])
cauldron.data.materials.clear()
cauldron.data.materials.append(mat)

# ── 7. Export ─────────────────────────────────────────────────────────────────

bpy.ops.object.select_all(action='DESELECT')
cauldron.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(cauldron.data.polygons)
vert = len(cauldron.data.vertices)
print(f"\n✓ Cauldron v3 → {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
