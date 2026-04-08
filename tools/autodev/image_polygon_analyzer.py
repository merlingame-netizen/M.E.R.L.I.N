"""Polygon Analyzer — decompose N64-style images into flat-shaded polygon zones.
Outputs: color zones, edge map, polygon contours, spatial layout as JSON.
Usage: python image_polygon_analyzer.py <image.png> [--output-dir dir]
"""
import sys, json, os
import numpy as np
import cv2
from PIL import Image
from collections import Counter

def analyze_image(image_path, output_dir=None):
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    
    img = cv2.imread(image_path)
    h, w = img.shape[:2]
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # 1. Edge detection (Canny) — find polygon edges
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 30, 100)
    if output_dir:
        cv2.imwrite(os.path.join(output_dir, "edges.png"), edges)
    
    # 2. Color quantization — reduce to N64 palette (16 colors)
    pixels = rgb.reshape(-1, 3).astype(np.float32)
    k = 16
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
    _, labels, centers = cv2.kmeans(pixels, k, None, criteria, 5, cv2.KMEANS_PP_CENTERS)
    centers = centers.astype(np.uint8)
    quantized = centers[labels.flatten()].reshape(h, w, 3)
    if output_dir:
        Image.fromarray(quantized).save(os.path.join(output_dir, "quantized_16colors.png"))
    
    # 3. Color zone analysis — area + position of each color
    label_map = labels.reshape(h, w)
    zones = []
    for ci in range(k):
        mask = (label_map == ci)
        area_pct = float(mask.sum()) / (h * w) * 100
        if area_pct < 0.5:
            continue
        ys, xs = np.where(mask)
        zone = {
            "color_rgb": [int(c) for c in centers[ci]],
            "color_hex": "#{:02x}{:02x}{:02x}".format(*centers[ci]),
            "area_pct": round(area_pct, 1),
            "centroid": [int(xs.mean()), int(ys.mean())],
            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "region": _classify_region(int(xs.mean()), int(ys.mean()), w, h),
        }
        zones.append(zone)
    zones.sort(key=lambda z: z["area_pct"], reverse=True)
    
    # 4. Contour detection — find polygon shapes
    contours_data = []
    for ci in range(k):
        mask = ((label_map == ci) * 255).astype(np.uint8)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < 500:
                continue
            epsilon = 0.02 * cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, epsilon, True)
            M = cv2.moments(cnt)
            cx = int(M["m10"] / M["m00"]) if M["m00"] > 0 else 0
            cy = int(M["m01"] / M["m00"]) if M["m00"] > 0 else 0
            contours_data.append({
                "vertices": len(approx),
                "area_px": int(area),
                "centroid": [cx, cy],
                "color_hex": "#{:02x}{:02x}{:02x}".format(*centers[ci]),
                "region": _classify_region(cx, cy, w, h),
            })
    contours_data.sort(key=lambda c: c["area_px"], reverse=True)
    
    # 5. Draw contour overlay
    if output_dir:
        overlay = img.copy()
        for ci in range(k):
            mask = ((label_map == ci) * 255).astype(np.uint8)
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            color = tuple(int(c) for c in centers[ci])
            cv2.drawContours(overlay, contours, -1, (0, 255, 0), 1)
        cv2.imwrite(os.path.join(output_dir, "contours_overlay.png"), overlay)
    
    # 6. Horizontal band analysis (sky, cliff, ocean)
    bands = []
    for band_idx, (name, y0_pct, y1_pct) in enumerate([
        ("sky", 0, 30), ("upper_cliff", 30, 50), 
        ("mid_cliff", 50, 70), ("lower_ground", 70, 100)
    ]):
        y0 = int(h * y0_pct / 100)
        y1 = int(h * y1_pct / 100)
        band_pixels = rgb[y0:y1]
        avg_color = [int(x) for x in band_pixels.reshape(-1, 3).mean(axis=0)]
        bands.append({
            "name": name, "y_range": [y0_pct, y1_pct],
            "avg_color_rgb": avg_color,
            "avg_color_hex": "#{:02x}{:02x}{:02x}".format(*avg_color),
        })
    
    result = {
        "image_size": [w, h],
        "palette_16": [{"hex": "#{:02x}{:02x}{:02x}".format(*c), "rgb": [int(x) for x in c]} for c in centers],
        "color_zones": zones[:12],
        "top_polygons": contours_data[:20],
        "horizontal_bands": bands,
        "edge_density_pct": round(float(edges.sum() > 0) / (h * w) * 100 * 255, 1),
        "total_contours": len(contours_data),
    }
    return result

def _classify_region(x, y, w, h):
    rx = "left" if x < w/3 else "right" if x > 2*w/3 else "center"
    ry = "top" if y < h/3 else "bottom" if y > 2*h/3 else "mid"
    return f"{ry}_{rx}"

if __name__ == "__main__":
    path = sys.argv[1]
    out_dir = None
    if "--output-dir" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--output-dir") + 1]
    result = analyze_image(path, out_dir)
    print(json.dumps(result, indent=2))
