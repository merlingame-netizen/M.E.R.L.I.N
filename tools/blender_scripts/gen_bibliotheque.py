"""
Blender headless — Bibliotheque druidique
Style: caisse bois sombre, 3 etageres, livres blocs colorés, < 150 polys
Palette: C_OAK, C_OAK_DARK, + accents livres (rouge sombre, noir)
"""
import bpy, bmesh, math, os

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "3d_models", "decor", "bibliotheque.glb"
))
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)

# ── Palette ────────────────────────────────────────────────────────────────
C_OAK        = (0.35, 0.20, 0.08, 1)
C_OAK_DARK   = (0.18, 0.10, 0.03, 1)
C_BOOK_RED   = (0.30, 0.05, 0.04, 1)
C_BOOK_BLK   = (0.08, 0.07, 0.06, 1)
C_BOOK_BRUN  = (0.28, 0.16, 0.07, 1)

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

def make_box(name, x, y, z, w, d, h, col_dark, col_light, split=0.5):
    bm = bmesh.new()
    verts = [
        bm.verts.new((x,     y,     z    )),
        bm.verts.new((x + w, y,     z    )),
        bm.verts.new((x + w, y + d, z    )),
        bm.verts.new((x,     y + d, z    )),
        bm.verts.new((x,     y,     z + h)),
        bm.verts.new((x + w, y,     z + h)),
        bm.verts.new((x + w, y + d, z + h)),
        bm.verts.new((x,     y + d, z + h)),
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
    if col_dark == col_light:
        fill(obj, col_dark)
    else:
        paint_faces_z(obj, col_dark, col_light, split)
    return obj

all_objects = []

# ── 1. Caisse principale ──────────────────────────────────────────────────────
# Panneau arrière
all_objects.append(make_box("Back",   -1.0, -0.10, 0.0,  2.0, 0.08, 3.2, C_OAK_DARK, C_OAK, 0.5))
# Panneau gauche
all_objects.append(make_box("Left",   -1.0, -0.10, 0.0,  0.08, 0.65, 3.2, C_OAK_DARK, C_OAK, 0.5))
# Panneau droit
all_objects.append(make_box("Right",   0.92, -0.10, 0.0, 0.08, 0.65, 3.2, C_OAK_DARK, C_OAK, 0.5))
# Fond du bas
all_objects.append(make_box("Base",  -1.0, -0.10, 0.0,   2.0, 0.65, 0.08, C_OAK_DARK, C_OAK, 0.5))
# Toit
all_objects.append(make_box("Roof",  -1.0, -0.10, 3.12,  2.0, 0.65, 0.08, C_OAK_DARK, C_OAK, 0.5))

# ── 2. Trois étagères ─────────────────────────────────────────────────────────
for shelf_z in [1.0, 1.9, 2.8]:
    all_objects.append(make_box(f"Shelf_{shelf_z}",
                                -0.92, -0.05, shelf_z - 0.04, 1.84, 0.55, 0.06,
                                C_OAK_DARK, C_OAK, 0.5))

# ── 3. Livres (blocs rectangulaires sur chaque étagère) ──────────────────────
# Données: (shelf_z, x_start, largeur, hauteur, couleur)
books = [
    # Etagère 1 — 4 livres (blocs larges, moins de faces)
    (1.06, -0.88, 0.44, 0.55, C_BOOK_RED),
    (1.06, -0.40, 0.38, 0.60, C_BOOK_BLK),
    (1.06,  0.02, 0.42, 0.50, C_OAK),
    (1.06,  0.48, 0.38, 0.56, C_OAK_DARK),
    # Etagère 2 — 4 livres
    (1.96, -0.88, 0.42, 0.52, C_BOOK_BLK),
    (1.96, -0.42, 0.40, 0.60, C_BOOK_RED),
    (1.96,  0.02, 0.44, 0.54, C_OAK),
    (1.96,  0.50, 0.36, 0.50, C_BOOK_BLK),
    # Etagère 3 — 4 livres
    (2.86, -0.88, 0.40, 0.50, C_BOOK_RED),
    (2.86, -0.44, 0.42, 0.58, C_BOOK_BLK),
    (2.86,  0.02, 0.40, 0.52, C_OAK),
    (2.86,  0.46, 0.38, 0.56, C_OAK_DARK),
]
for sz, bx, bw, bh, bcol in books:
    all_objects.append(make_box(
        f"Book_{len(all_objects)}", bx, 0.0, sz, bw, 0.45, bh, bcol, bcol
    ))

# ── 4. Joindre ────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
for o in all_objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = all_objects[0]
bpy.ops.object.join()
lib = bpy.context.active_object
lib.name = "Bibliotheque"

bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
lib.location = (0, 0, 0)
bb = lib.bound_box
h = max(v[2] for v in bb) - min(v[2] for v in bb)
if h > 0:
    sf = 3.0 / h
    lib.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True, location=True)

# ── 5. Matériau vertex color ──────────────────────────────────────────────────
mat = bpy.data.materials.new("BiblioMat")
mat.use_nodes = True
ns = mat.node_tree.nodes; ns.clear()
vc_n = ns.new("ShaderNodeVertexColor"); vc_n.layer_name = "Col"
bsdf = ns.new("ShaderNodeBsdfPrincipled")
bsdf.inputs["Roughness"].default_value = 0.97
bsdf.inputs["Metallic"].default_value = 0.0
out = ns.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(vc_n.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
lib.data.materials.clear()
lib.data.materials.append(mat)

# ── 6. Export ─────────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='DESELECT')
lib.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT, use_selection=True,
    export_format='GLB', export_attributes=True,
    export_normals=True, export_apply=True, export_yup=True,
)
poly = len(lib.data.polygons)
vert = len(lib.data.vertices)
print(f"\n[OK] Bibliotheque -> {OUT}")
print(f"  Polygons : {poly}  Vertices : {vert}")
