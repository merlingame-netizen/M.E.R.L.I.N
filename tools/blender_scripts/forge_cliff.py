"""Forge: Cliff Asset — Whale-back cliff with terraces, caves, and outcrops."""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, noise

random.seed(42)
OUT = r"c:\Users\PGNK2128\Godot-MCP\assets\3d_models\menu_coast\cliff_unified.glb"

# Clear
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)

print("[FORGE:CLIFF] Starting...")

# ══════════════════════════════════════════════════════════════
# 1. MAIN PLATEAU — 60x50 grid for organic whale-back shape
# ══════════════════════════════════════════════════════════════
bpy.ops.mesh.primitive_grid_add(x_subdivisions=60, y_subdivisions=50, size=1, location=(0, 0, 0))
plateau = bpy.context.active_object
plateau.name = "CliffPlateau"
plateau.scale = (70, 55, 1)
bpy.ops.object.transform_apply(scale=True)

for v in plateau.data.vertices:
    xn, yn = v.co.x / 70, v.co.y / 55

    if yn > -0.12:
        # Whale-back plateau top — smoothly rounded, left side higher
        h = 10.0
        # Large-scale undulation
        h += noise.noise(Vector((xn * 3, yn * 3, 0))) * 1.5
        h += noise.noise(Vector((xn * 7, yn * 7, 0.5))) * 0.6
        # Small detail bumps
        h += noise.noise(Vector((xn * 15, yn * 15, 1.5))) * 0.25
        # Left side rises 3 units higher (whale profile)
        left_rise = max(0, -xn - 0.1) * 6.0
        h += min(left_rise, 3.0)
        # Whale-back rounded profile from front to back
        front_roll = max(0, yn - 0.2) * 2.0
        h -= front_roll
        # Edges drop smoothly
        edge = max(0, abs(xn) - 0.32) * 5.0
        h -= edge
        h = max(h, 7.5)
    elif yn > -0.30:
        # CLIFF FACE — steep drop with caves and overhangs
        t = (yn + 0.30) / 0.18
        base = t * 10.0
        # Strong noise for irregular cliff face (amplitude 4.0)
        base += noise.noise(Vector((xn * 5, yn * 15, 1.0))) * 4.0
        base += noise.noise(Vector((xn * 12, yn * 20, 2.0))) * 2.0
        # Medium detail
        base += noise.noise(Vector((xn * 20, yn * 25, 4.0))) * 0.8
        # Deep caves — threshold -0.25, subtract 3.0
        cave = noise.noise(Vector((xn * 8, yn * 8, 3.0)))
        if cave < -0.25:
            base -= 3.0
        # Secondary cave layer
        cave2 = noise.noise(Vector((xn * 6, yn * 12, 6.0)))
        if cave2 < -0.3:
            base -= 1.5
        # Left side stays higher on cliff face too
        if xn < -0.15:
            base += 1.5
        h = max(-0.5, base)
    else:
        # Ocean floor
        h = -1.5 + noise.noise(Vector((xn * 4, yn * 4, 0))) * 0.5

    v.co.z = h

parts = [plateau]

# ══════════════════════════════════════════════════════════════
# 2. TERRACE FINGERS — 3 wider ridges stepping down left to right
# ══════════════════════════════════════════════════════════════
terrace_specs = [
    # (x, y, sx, sy, subdx, subdy, base_h, noise_seed)
    (8, -10, 35, 18, 28, 18, 7.0, 2.0),    # High terrace, center
    (-12, -14, 28, 14, 22, 14, 4.5, 3.0),   # Mid terrace, left
    (22, -18, 22, 12, 18, 12, 2.5, 5.0),    # Low terrace, right
]
for i, (tx, ty, sx, sy, sdx, sdy, bh, ns) in enumerate(terrace_specs):
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=sdx, y_subdivisions=sdy, size=1, location=(tx, ty, 0))
    t = bpy.context.active_object
    t.name = f"Terrace_{i}"
    t.scale = (sx, sy, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in t.data.vertices:
        h = bh + noise.noise(Vector((v.co.x / sx * 5, v.co.y / sy * 5, ns))) * 1.8
        h += noise.noise(Vector((v.co.x / sx * 12, v.co.y / sy * 12, ns + 1))) * 0.5
        v.co.z = max(h, bh - 2.5)
    parts.append(t)

# ══════════════════════════════════════════════════════════════
# 3. CLIFF FACE WALLS — thick boxes for rock mass depth
# ══════════════════════════════════════════════════════════════
face_specs = [
    ((0, -15, 5.0), (68, 5, 11)),        # Main wall (wider, thicker)
    ((10, -17, 3.5), (48, 4, 7)),         # Second layer
    ((-8, -19, 1.5), (38, 3, 4)),         # Lower overhang
]
for pos, sc in face_specs:
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    f = bpy.context.active_object
    f.scale = sc
    bpy.ops.object.transform_apply(scale=True)
    parts.append(f)

# ══════════════════════════════════════════════════════════════
# 4. ROCK OUTCROPS — 25 organic shapes on cliff face
# ══════════════════════════════════════════════════════════════
for i in range(25):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2, radius=random.uniform(2.0, 6.0),
        location=(random.uniform(-30, 30), random.uniform(-22, -6), random.uniform(-1, 10)))
    o = bpy.context.active_object
    o.scale = (random.uniform(0.7, 1.5), random.uniform(0.5, 1.1), random.uniform(0.3, 0.9))
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        v.co += v.co.normalized() * random.uniform(-0.4, 0.4)
    parts.append(o)

# ══════════════════════════════════════════════════════════════
# 5. LARGE PROTRUDING BOULDER (center-bottom, r=7, further out)
# ══════════════════════════════════════════════════════════════
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=7.0, location=(2, -20, 3.0))
boulder = bpy.context.active_object
boulder.name = "Boulder"
boulder.scale = (1.4, 0.9, 0.65)
bpy.ops.object.transform_apply(scale=True)
for v in boulder.data.vertices:
    v.co += v.co.normalized() * random.uniform(-0.5, 0.5)
parts.append(boulder)

# ══════════════════════════════════════════════════════════════
# 6. JOIN ALL → DECIMATE 0.25 → FLAT SHADE
# ══════════════════════════════════════════════════════════════
print(f"[FORGE:CLIFF] Joining {len(parts)} objects...")
bpy.ops.object.select_all(action='DESELECT')
main = parts[0]
main.select_set(True)
for o in parts[1:]:
    o.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.object.join()
main.name = "Cliff"

# Decimate for faceted low-poly look (0.25 = more faceted)
mod = main.modifiers.new("Dec", "DECIMATE")
mod.ratio = 0.25
bpy.ops.object.modifier_apply(modifier="Dec")

# Flat shade
for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:CLIFF] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══════════════════════════════════════════════════════════════
# 7. MULTI-MATERIAL by height zone (6 zones, reference colors)
# ══════════════════════════════════════════════════════════════
zone_colors = {
    "green_bright": (0.48, 0.68, 0.22),  # Sunlit plateau top
    "green_mid":    (0.38, 0.55, 0.20),   # Mid terrace green
    "green_shadow": (0.30, 0.48, 0.16),   # Shadow green (adjusted)
    "rock_warm":    (0.52, 0.42, 0.30),   # Warm brown rock face
    "rock_mid":     (0.42, 0.35, 0.25),   # Mid brown
    "rock_dark":    (0.25, 0.22, 0.16),   # Dark base
}

mats = {}
for name, color in zone_colors.items():
    mat = bpy.data.materials.new(f"Cliff_{name}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.88
    mats[name] = mat

main.data.materials.clear()
mat_names = list(mats.keys())
for m in mats.values():
    main.data.materials.append(m)

for face in main.data.polygons:
    avg_z = sum(main.data.vertices[vi].co.z for vi in face.vertices) / len(face.vertices)

    if avg_z > 9.0:
        face.material_index = mat_names.index("green_bright")
    elif avg_z > 6.5:
        face.material_index = mat_names.index("green_mid")
    elif avg_z > 4.0:
        face.material_index = mat_names.index("green_shadow")
    elif avg_z > 2.0:
        face.material_index = mat_names.index("rock_warm")
    elif avg_z > 0.5:
        face.material_index = mat_names.index("rock_mid")
    else:
        face.material_index = mat_names.index("rock_dark")

# ══════════════════════════════════════════════════════════════
# 8. EXPORT GLB
# ══════════════════════════════════════════════════════════════
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
main.select_set(True)
bpy.context.view_layer.objects.active = main
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True)

size = os.path.getsize(OUT)
result = {
    "status": "ok",
    "file": OUT,
    "size_kb": size // 1024,
    "vertices": len(main.data.vertices),
    "faces": len(main.data.polygons),
    "materials": len(zone_colors),
}
print(json.dumps(result))
print("[FORGE:CLIFF] === DONE ===")
