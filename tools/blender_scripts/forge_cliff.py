"""Forge: Cliff Asset — High-quality low-poly cliff with vertex colors."""
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
# 1. MAIN PLATEAU — high-res for organic shape
# ══════════════════════════════════════════════════════════════
bpy.ops.mesh.primitive_grid_add(x_subdivisions=50, y_subdivisions=40, size=1, location=(0, 0, 0))
plateau = bpy.context.active_object
plateau.name = "CliffPlateau"
plateau.scale = (70, 55, 1)
bpy.ops.object.transform_apply(scale=True)

for v in plateau.data.vertices:
    xn, yn = v.co.x / 70, v.co.y / 55

    if yn > -0.12:
        # Flat plateau top with gentle undulation
        h = 10.0
        h += noise.noise(Vector((xn * 3, yn * 3, 0))) * 1.2
        h += noise.noise(Vector((xn * 8, yn * 8, 0.5))) * 0.4
        # Left side rises higher (like reference)
        if xn < -0.15:
            h += 2.5
        # Edges drop slightly
        edge = max(0, abs(xn) - 0.35) * 4.0
        h -= edge
        h = max(h, 8.0)
    elif yn > -0.28:
        # CLIFF FACE — steep drop with outcrops and caves
        t = (yn + 0.28) / 0.16
        base = t * 10.0
        # Strong noise for irregular cliff face
        base += noise.noise(Vector((xn * 5, yn * 15, 1.0))) * 4.0
        base += noise.noise(Vector((xn * 12, yn * 20, 2.0))) * 1.5
        # Cave-like recesses
        cave = noise.noise(Vector((xn * 8, yn * 8, 3.0)))
        if cave < -0.3:
            base -= 2.0
        h = max(0.0, base)
    else:
        # Ocean floor
        h = -1.0 + noise.noise(Vector((xn * 4, yn * 4, 0))) * 0.4

    v.co.z = h

parts = [plateau]

# ══════════════════════════════════════════════════════════════
# 2. TERRACE FINGERS — 3 ridges stepping down
# ══════════════════════════════════════════════════════════════
terrace_specs = [
    # (x, y, sx, sy, subdx, subdy, base_h, noise_seed)
    (10, -10, 28, 16, 22, 16, 6.5, 2.0),   # Mid terrace, center-right
    (-14, -14, 22, 12, 16, 12, 4.0, 3.0),   # Low terrace, left
    (20, -18, 18, 10, 14, 10, 2.0, 5.0),    # Lowest finger, far right
]
for i, (tx, ty, sx, sy, sdx, sdy, bh, ns) in enumerate(terrace_specs):
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=sdx, y_subdivisions=sdy, size=1, location=(tx, ty, 0))
    t = bpy.context.active_object
    t.name = f"Terrace_{i}"
    t.scale = (sx, sy, 1)
    bpy.ops.object.transform_apply(scale=True)
    for v in t.data.vertices:
        h = bh + noise.noise(Vector((v.co.x/sx*5, v.co.y/sy*5, ns))) * 1.5
        v.co.z = max(h, bh - 2.0)
    parts.append(t)

# ══════════════════════════════════════════════════════════════
# 3. CLIFF FACE WALLS — thick boxes for rock mass
# ══════════════════════════════════════════════════════════════
face_specs = [
    ((0, -14, 5.0), (65, 4, 10)),       # Main wall
    ((8, -16, 3.0), (45, 3, 6)),         # Second layer
    ((-10, -18, 1.5), (35, 2.5, 3.5)),   # Lower overhang
]
for pos, sc in face_specs:
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    f = bpy.context.active_object
    f.scale = sc
    bpy.ops.object.transform_apply(scale=True)
    parts.append(f)

# ══════════════════════════════════════════════════════════════
# 4. ROCK OUTCROPS — organic shapes on cliff face
# ══════════════════════════════════════════════════════════════
for i in range(22):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2, radius=random.uniform(1.5, 5.0),
        location=(random.uniform(-28, 28), random.uniform(-20, -8), random.uniform(-1, 9)))
    o = bpy.context.active_object
    o.scale = (random.uniform(0.7, 1.4), random.uniform(0.5, 1.0), random.uniform(0.3, 0.8))
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        v.co += v.co.normalized() * random.uniform(-0.3, 0.3)
    parts.append(o)

# ══════════════════════════════════════════════════════════════
# 5. LARGE PROTRUDING BOULDER (center-bottom, like reference)
# ══════════════════════════════════════════════════════════════
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=5.0, location=(2, -18, 3.0))
boulder = bpy.context.active_object
boulder.name = "Boulder"
boulder.scale = (1.3, 0.8, 0.6)
bpy.ops.object.transform_apply(scale=True)
for v in boulder.data.vertices:
    v.co += v.co.normalized() * random.uniform(-0.4, 0.4)
parts.append(boulder)

# ══════════════════════════════════════════════════════════════
# 6. JOIN ALL → DECIMATE → FLAT SHADE
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

# Decimate for faceted low-poly look
mod = main.modifiers.new("Dec", "DECIMATE")
mod.ratio = 0.30
bpy.ops.object.modifier_apply(modifier="Dec")

# Flat shade
for poly in main.data.polygons:
    poly.use_smooth = False

print(f"[FORGE:CLIFF] Mesh: {len(main.data.vertices)} verts, {len(main.data.polygons)} faces")

# ══════════════════════════════════════════════════════════════
# 7. MULTI-MATERIAL by height zone
# ══════════════════════════════════════════════════════════════
zone_colors = {
    "green_bright": (0.48, 0.68, 0.22),  # Sunlit plateau
    "green_mid":    (0.38, 0.55, 0.20),   # Mid terrace
    "green_shadow": (0.28, 0.45, 0.16),   # Shadow green
    "rock_warm":    (0.52, 0.42, 0.30),   # Warm brown rock
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
    avg_y = sum(main.data.vertices[vi].co.y for vi in face.vertices) / len(face.vertices)

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
