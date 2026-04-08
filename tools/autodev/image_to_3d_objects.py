"""Image-to-3D Object Pipeline - Detour, extract, and generate Blender scripts.

1. Segment image into distinct objects (watershed + color clustering)
2. Extract each object silhouette polygon (contour -> simplified vertices)
3. Capture pixel-perfect color palette per object
4. Generate Blender Python script to create low-poly 3D mesh per object
5. Output: one .py per object + manifest.json

Usage: python image_to_3d_objects.py <reference.png> --output-dir <dir>
"""
import sys, json, os
import numpy as np
import cv2
from PIL import Image
from collections import Counter


def segment_objects(image_path, output_dir, min_area=2000):
    os.makedirs(output_dir, exist_ok=True)

    img = cv2.imread(image_path)
    h, w = img.shape[:2]
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Step 1: Color quantize to N64 palette (12 colors)
    pixels = img.reshape(-1, 3).astype(np.float32)
    k = 12
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
    _, labels, centers = cv2.kmeans(pixels, k, None, criteria, 5, cv2.KMEANS_PP_CENTERS)
    centers_uint8 = centers.astype(np.uint8)
    label_map = labels.reshape(h, w)

    # Step 2: Edge detection
    edges = cv2.Canny(gray, 40, 120)
    kernel = np.ones((3, 3), np.uint8)

    # Step 3: Extract objects per color zone
    objects = []
    obj_id = 0

    for ci in range(k):
        mask = ((label_map == ci) * 255).astype(np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < min_area:
                continue

            epsilon = 0.015 * cv2.arcLength(cnt, True)
            poly = cv2.approxPolyDP(cnt, epsilon, True)

            x, y, bw, bh = cv2.boundingRect(cnt)
            M = cv2.moments(cnt)
            cx = int(M["m10"] / M["m00"]) if M["m00"] > 0 else x + bw // 2
            cy = int(M["m01"] / M["m00"]) if M["m00"] > 0 else y + bh // 2

            # Extract object colors
            obj_mask = np.zeros((h, w), dtype=np.uint8)
            cv2.fillPoly(obj_mask, [cnt], 255)
            obj_pixels = rgb[obj_mask > 0]

            if len(obj_pixels) > 0:
                px_quant = (obj_pixels // 32) * 32 + 16
                px_tuples = [tuple(p) for p in px_quant]
                color_counts = Counter(px_tuples).most_common(5)
                dominant_colors = [
                    {"rgb": list(c), "hex": "#{:02x}{:02x}{:02x}".format(*c),
                     "pct": round(n / len(px_tuples) * 100, 1)}
                    for c, n in color_counts
                ]
                avg_color = [int(x) for x in obj_pixels.mean(axis=0)]
            else:
                dominant_colors = []
                avg_color = [int(c) for c in centers_uint8[ci]]

            obj_type = _classify_object(cx, cy, w, h, area, bw, bh, avg_color)

            vertices_px = [(int(p[0][0]), int(p[0][1])) for p in poly]
            vertices_norm = [(round(p[0][0] / w, 4), round(p[0][1] / h, 4)) for p in poly]

            # Save object mask as RGBA PNG
            obj_crop = img[y:y + bh, x:x + bw].copy()
            obj_mask_crop = obj_mask[y:y + bh, x:x + bw]
            obj_rgba = cv2.cvtColor(obj_crop, cv2.COLOR_BGR2BGRA)
            obj_rgba[:, :, 3] = obj_mask_crop
            obj_filename = "obj_{:02d}_{}.png".format(obj_id, obj_type)
            cv2.imwrite(os.path.join(output_dir, obj_filename), obj_rgba)

            objects.append({
                "id": obj_id,
                "type": obj_type,
                "bbox_px": [x, y, bw, bh],
                "bbox_norm": [round(x / w, 4), round(y / h, 4), round(bw / w, 4), round(bh / h, 4)],
                "centroid_px": [cx, cy],
                "centroid_norm": [round(cx / w, 4), round(cy / h, 4)],
                "area_px": int(area),
                "area_pct": round(area / (h * w) * 100, 2),
                "polygon_vertices": len(vertices_px),
                "vertices_px": vertices_px,
                "vertices_norm": vertices_norm,
                "avg_color_rgb": avg_color,
                "avg_color_hex": "#{:02x}{:02x}{:02x}".format(*avg_color),
                "dominant_colors": dominant_colors[:3],
                "mask_file": obj_filename,
                "region": _classify_region(cx, cy, w, h),
            })
            obj_id += 1

    objects.sort(key=lambda o: o["area_px"], reverse=True)
    for i, obj in enumerate(objects):
        obj["id"] = i

    # Generate Blender scripts for top objects
    for obj in objects[:8]:
        _generate_blender_script(obj, output_dir, w, h)

    # Draw overlay
    overlay = img.copy()
    for obj in objects:
        pts = np.array(obj["vertices_px"], dtype=np.int32)
        cv2.polylines(overlay, [pts], True, (0, 255, 0), 2)
        cv2.putText(overlay, "{}:{}".format(obj["id"], obj["type"]),
                    (obj["centroid_px"][0] - 20, obj["centroid_px"][1] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 255), 1)
    cv2.imwrite(os.path.join(output_dir, "objects_overlay.png"), overlay)

    manifest = {
        "source_image": os.path.basename(image_path),
        "image_size": [w, h],
        "total_objects": len(objects),
        "objects": objects,
    }
    class NpEncoder(json.JSONEncoder):
        def default(self, obj):
            if isinstance(obj, np.integer):
                return int(obj)
            if isinstance(obj, np.floating):
                return float(obj)
            if isinstance(obj, np.ndarray):
                return obj.tolist()
            return super().default(obj)

    with open(os.path.join(output_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2, cls=NpEncoder)

    return manifest


def _classify_object(cx, cy, w, h, area, bw, bh, avg_color):
    rel_y = cy / h
    rel_x = cx / w
    aspect = bh / max(bw, 1)
    r, g, b = avg_color

    if rel_y < 0.3 and b > r and b > g:
        return "cloud" if bw > w * 0.1 else "sky_element"
    if rel_y < 0.45 and aspect > 1.5 and 0.2 < rel_x < 0.6:
        return "tower"
    if rel_y > 0.5 and b > r and (g > r or b > 100):
        return "ocean" if area > w * h * 0.03 else "foam"
    if g > r and g > b and area < w * h * 0.02:
        return "bush"
    if area > w * h * 0.05:
        return "cliff_face"
    if r > 80 and g > 60 and b < 80:
        return "cliff_detail"
    return "rock" if area < w * h * 0.01 else "terrain"


def _classify_region(x, y, w, h):
    rx = "left" if x < w / 3 else "right" if x > 2 * w / 3 else "center"
    ry = "top" if y < h / 3 else "bottom" if y > 2 * h / 3 else "mid"
    return "{}_{}".format(ry, rx)


def _generate_blender_script(obj, output_dir, img_w, img_h):
    obj_id = obj["id"]
    obj_type = obj["type"]
    vertices = obj["vertices_norm"]
    avg_color = [c / 255.0 for c in obj["avg_color_rgb"]]
    dom_colors = obj["dominant_colors"]

    height_map = {
        "tower": 6.0, "cliff_face": 3.0, "cloud": 0.5,
        "ocean": 0.3, "bush": 1.0, "foam": 0.2,
        "rock": 1.5, "terrain": 2.0, "cliff_detail": 2.0,
        "sky_element": 0.3,
    }
    obj_height = height_map.get(obj_type, 1.0)

    lines = []
    lines.append("# Auto-generated Blender script for object {}: {}".format(obj_id, obj_type))
    lines.append("# Pixel-perfect colors extracted from reference image")
    lines.append("import bpy, bmesh")
    lines.append("from mathutils import Vector")
    lines.append("")
    lines.append("bpy.ops.object.select_all(action='SELECT')")
    lines.append("bpy.ops.object.delete()")
    lines.append("")
    lines.append('mesh = bpy.data.meshes.new("{}_{}")'.format(obj_type, obj_id))
    lines.append('obj = bpy.data.objects.new("{}_{}", mesh)'.format(obj_type, obj_id))
    lines.append("bpy.context.collection.objects.link(obj)")
    lines.append("")
    lines.append("bm = bmesh.new()")
    lines.append("base_verts = []")
    lines.append("top_verts = []")

    for vx, vy in vertices:
        x3d = (vx - 0.5) * 20
        z3d = (0.5 - vy) * 20
        lines.append("base_verts.append(bm.verts.new(Vector(({:.2f}, 0, {:.2f}))))".format(x3d, z3d))
        lines.append("top_verts.append(bm.verts.new(Vector(({:.2f}, {:.1f}, {:.2f}))))".format(x3d, obj_height, z3d))

    lines.append("")
    lines.append("bm.verts.ensure_lookup_table()")
    lines.append("n = len(base_verts)")
    lines.append("if n >= 3:")
    lines.append("    try: bm.faces.new(base_verts)")
    lines.append("    except: pass")
    lines.append("    try: bm.faces.new(list(reversed(top_verts)))")
    lines.append("    except: pass")
    lines.append("for i in range(n):")
    lines.append("    j = (i + 1) % n")
    lines.append("    try: bm.faces.new([base_verts[i], base_verts[j], top_verts[j], top_verts[i]])")
    lines.append("    except: pass")
    lines.append("")
    lines.append("bm.to_mesh(mesh)")
    lines.append("bm.free()")
    lines.append("")
    lines.append('mat = bpy.data.materials.new("{}_{}_mat")'.format(obj_type, obj_id))
    lines.append("mat.use_nodes = False")
    lines.append("mat.diffuse_color = ({:.3f}, {:.3f}, {:.3f}, 1.0)".format(*avg_color))
    lines.append("mat.roughness = 0.9")
    lines.append("obj.data.materials.append(mat)")
    lines.append("")

    export_path = os.path.join(output_dir, "{}_{}.glb".format(obj_type, obj_id)).replace("\\", "/")
    lines.append("bpy.context.view_layer.objects.active = obj")
    lines.append("obj.select_set(True)")
    lines.append('bpy.ops.export_scene.gltf(filepath=r"{}", export_format="GLB", use_selection=True)'.format(export_path))
    lines.append('print("Exported: {}_{}.glb")'.format(obj_type, obj_id))

    if dom_colors:
        lines.append("")
        lines.append("# Dominant colors from reference (for vertex painting):")
        for dc in dom_colors:
            r, g, b = [c / 255.0 for c in dc["rgb"]]
            lines.append("# {} ({}%) -> ({:.3f}, {:.3f}, {:.3f})".format(dc["hex"], dc["pct"], r, g, b))

    script_path = os.path.join(output_dir, "blender_{}_{}.py".format(obj_type, obj_id))
    with open(script_path, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python image_to_3d_objects.py <image.png> --output-dir <dir>")
        sys.exit(1)

    image_path = sys.argv[1]
    output_dir = "."
    if "--output-dir" in sys.argv:
        output_dir = sys.argv[sys.argv.index("--output-dir") + 1]

    manifest = segment_objects(image_path, output_dir)
    print("Detected {} objects".format(manifest["total_objects"]))
    for obj in manifest["objects"][:10]:
        print("  [{}] {:15s} area={:5.1f}% color={} region={} verts={}".format(
            obj["id"], obj["type"], obj["area_pct"],
            obj["avg_color_hex"], obj["region"], obj["polygon_vertices"]))
