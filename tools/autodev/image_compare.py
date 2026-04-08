"""Pixel-perfect image comparison for Studio Loop.
Usage: python image_compare.py <current.png> <reference.png> [--diff diff_output.png]

Outputs:
- SSIM score (0-100%)
- MSE (Mean Squared Error)
- Per-region scores (9 grid zones)
- Dominant color comparison
- Optional diff heatmap image
"""
import sys, json
from pathlib import Path
import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim

def load_and_resize(path, target_size):
    img = Image.open(path).convert("RGB")
    img = img.resize(target_size, Image.LANCZOS)
    return np.array(img)

def compare_images(current_path, reference_path, diff_path=None):
    ref_img = Image.open(reference_path).convert("RGB")
    target_size = ref_img.size  # Match reference resolution
    
    ref = np.array(ref_img)
    cur = load_and_resize(current_path, target_size)
    
    # Global SSIM
    ssim_score = ssim(ref, cur, channel_axis=2, data_range=255)
    
    # MSE
    mse = float(np.mean((ref.astype(float) - cur.astype(float)) ** 2))
    
    # Per-region analysis (3x3 grid)
    h, w = ref.shape[:2]
    regions = {}
    for ry in range(3):
        for rx in range(3):
            y0, y1 = ry * h // 3, (ry + 1) * h // 3
            x0, x1 = rx * w // 3, (rx + 1) * w // 3
            r_ref = ref[y0:y1, x0:x1]
            r_cur = cur[y0:y1, x0:x1]
            r_ssim = ssim(r_ref, r_cur, channel_axis=2, data_range=255)
            # Region name
            ry_name = ["top", "mid", "bot"][ry]
            rx_name = ["left", "center", "right"][rx]
            regions[f"{ry_name}_{rx_name}"] = round(r_ssim * 100, 1)
    
    # Dominant colors (average per quadrant)
    def avg_color(arr):
        return [int(x) for x in np.mean(arr.reshape(-1, 3), axis=0)]
    
    color_ref = {
        "top_half": avg_color(ref[:h//2]),
        "bot_half": avg_color(ref[h//2:]),
        "overall": avg_color(ref),
    }
    color_cur = {
        "top_half": avg_color(cur[:h//2]),
        "bot_half": avg_color(cur[h//2:]),
        "overall": avg_color(cur),
    }
    
    # Color distance (Euclidean in RGB)
    def color_dist(c1, c2):
        return round(np.sqrt(sum((a-b)**2 for a,b in zip(c1,c2))), 1)
    
    color_distances = {
        "top_half": color_dist(color_ref["top_half"], color_cur["top_half"]),
        "bot_half": color_dist(color_ref["bot_half"], color_cur["bot_half"]),
        "overall": color_dist(color_ref["overall"], color_cur["overall"]),
    }
    
    # Worst regions (lowest SSIM)
    sorted_regions = sorted(regions.items(), key=lambda x: x[1])
    worst = sorted_regions[:3]
    best = sorted_regions[-3:]
    
    # Generate diff heatmap
    if diff_path:
        diff = np.abs(ref.astype(float) - cur.astype(float))
        diff_normalized = (diff / diff.max() * 255).astype(np.uint8) if diff.max() > 0 else diff.astype(np.uint8)
        # Red channel = difference intensity
        heatmap = np.zeros_like(ref)
        heatmap[:,:,0] = np.mean(diff_normalized, axis=2).astype(np.uint8)  # Red = diff
        heatmap[:,:,1] = (cur[:,:,1] * 0.3).astype(np.uint8)  # Dim green from current
        blend = (cur * 0.4 + heatmap * 0.6).astype(np.uint8)
        Image.fromarray(blend).save(diff_path)
    
    result = {
        "ssim_percent": round(ssim_score * 100, 1),
        "mse": round(mse, 1),
        "regions": regions,
        "worst_regions": [{"name": n, "ssim": s} for n,s in worst],
        "best_regions": [{"name": n, "ssim": s} for n,s in best],
        "color_ref": color_ref,
        "color_cur": color_cur,
        "color_distances": color_distances,
        "verdict": "CLOSE" if ssim_score > 0.7 else "FAR" if ssim_score < 0.4 else "MODERATE",
    }
    return result

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python image_compare.py <current.png> <reference.png> [--diff diff.png]")
        sys.exit(1)
    
    current = sys.argv[1]
    reference = sys.argv[2]
    diff = None
    if "--diff" in sys.argv:
        diff_idx = sys.argv.index("--diff")
        if diff_idx + 1 < len(sys.argv):
            diff = sys.argv[diff_idx + 1]
    
    result = compare_images(current, reference, diff)
    print(json.dumps(result, indent=2))
