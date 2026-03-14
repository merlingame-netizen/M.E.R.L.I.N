"""Pixel-precise visual comparison engine for PBI preview validation.

Compares two PNG screenshots and produces a diff image + similarity score.
Uses Pillow for image processing.

Usage:
    from adapters._pixel_compare import compare_images
    result = compare_images("preview.png", "reference.png", "diff.png")
    # result = {"similarity": 0.97, "diff_pixels": 1234, "total_pixels": 921600, ...}
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any


def screenshot_html(
    html_path: str,
    output_png: str,
    width: int = 1280,
    height: int = 720,
    selector: str | None = None,
) -> str:
    """Capture an HTML file to PNG using Python Playwright.

    If selector is given, screenshots that element.
    Otherwise tries ".canvas", then falls back to full viewport clip.
    """
    html_path = os.path.abspath(html_path).replace("\\", "/")
    output_png = os.path.abspath(output_png).replace("\\", "/")
    sel_code = f'"{selector}"' if selector else "None"

    script = f"""
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(viewport={{"width": {width}, "height": {height + 40}}})
        page = await ctx.new_page()
        await page.goto("file:///{html_path}")
        await page.wait_for_timeout(800)

        sel = {sel_code}
        captured = False

        # Try explicit selector first
        if sel:
            loc = page.locator(sel)
            if await loc.count() > 0:
                await loc.screenshot(path=r"{output_png}")
                captured = True

        # Try .canvas (PBI preview HTML)
        if not captured:
            canvas = page.locator(".canvas")
            if await canvas.count() > 0:
                await canvas.screenshot(path=r"{output_png}")
                captured = True

        # Fallback: clip viewport to exact dimensions
        if not captured:
            await page.screenshot(
                path=r"{output_png}",
                clip={{"x": 0, "y": 0, "width": {width}, "height": {height}}},
            )

        await browser.close()

asyncio.run(main())
"""
    py_paths = [
        "C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe",
        "python",
        "python3",
    ]

    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False, encoding="utf-8") as f:
        f.write(script)
        tmp_py = f.name

    try:
        for py in py_paths:
            try:
                subprocess.run(
                    [py, tmp_py],
                    check=True,
                    capture_output=True,
                    timeout=30,
                )
                return output_png
            except FileNotFoundError:
                continue
            except subprocess.CalledProcessError as e:
                stderr = e.stderr.decode("utf-8", errors="replace") if e.stderr else ""
                if "not recognized" in stderr.lower() or "not found" in stderr.lower():
                    continue
                raise RuntimeError(f"Screenshot failed: {stderr[:500]}")
        raise RuntimeError("Python not found for Playwright screenshot")
    finally:
        try:
            os.unlink(tmp_py)
        except OSError:
            pass


def compare_images(
    img_a_path: str,
    img_b_path: str,
    diff_output_path: str | None = None,
    tolerance: int = 12,
) -> dict[str, Any]:
    """Compare two PNG images pixel-by-pixel.

    Args:
        img_a_path: Path to image A (e.g., generated preview)
        img_b_path: Path to image B (e.g., reference screenshot)
        diff_output_path: Optional path to save the diff image
        tolerance: Per-channel tolerance (0-255). Pixels within tolerance = match.

    Returns:
        dict with similarity score, pixel counts, and region analysis.
    """
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        raise RuntimeError("Pillow is required: pip install Pillow")

    img_a = Image.open(img_a_path).convert("RGB")
    img_b = Image.open(img_b_path).convert("RGB")

    # Resize B to match A if dimensions differ
    if img_a.size != img_b.size:
        img_b = img_b.resize(img_a.size, Image.LANCZOS)

    w, h = img_a.size
    total = w * h

    px_a = img_a.load()
    px_b = img_b.load()

    diff_count = 0
    diff_img = Image.new("RGB", (w, h), (0, 0, 0))
    diff_px = diff_img.load()

    # Region analysis: divide into grid
    grid_cols, grid_rows = 16, 9  # 16:9 grid
    cell_w = w // grid_cols
    cell_h = h // grid_rows
    region_diffs: dict[str, int] = {}
    region_totals: dict[str, int] = {}

    for y in range(h):
        for x in range(w):
            ra, ga, ba = px_a[x, y]
            rb, gb, bb = px_b[x, y]

            dr = abs(ra - rb)
            dg = abs(ga - gb)
            db = abs(ba - bb)

            region_key = f"{min(x // cell_w, grid_cols - 1)},{min(y // cell_h, grid_rows - 1)}"
            region_totals[region_key] = region_totals.get(region_key, 0) + 1

            if dr > tolerance or dg > tolerance or db > tolerance:
                diff_count += 1
                # Diff image: highlight differences in red/magenta
                intensity = min(255, (dr + dg + db) * 2)
                diff_px[x, y] = (intensity, 0, intensity // 2)
                region_diffs[region_key] = region_diffs.get(region_key, 0) + 1
            else:
                # Match: show dimmed version of original
                diff_px[x, y] = (ra // 3, ga // 3, ba // 3)

    similarity = 1.0 - (diff_count / total) if total > 0 else 1.0

    # Find worst regions
    region_scores = []
    for key in region_totals:
        d = region_diffs.get(key, 0)
        t = region_totals[key]
        score = 1.0 - (d / t) if t > 0 else 1.0
        col, row = key.split(",")
        region_scores.append({
            "region": key,
            "col": int(col),
            "row": int(row),
            "x": int(col) * cell_w,
            "y": int(row) * cell_h,
            "w": cell_w,
            "h": cell_h,
            "similarity": round(score, 4),
            "diff_pixels": d,
        })

    # Sort by worst first
    region_scores.sort(key=lambda r: r["similarity"])

    if diff_output_path:
        # Add grid overlay and labels on worst regions
        draw = ImageDraw.Draw(diff_img)
        for r in region_scores[:10]:
            if r["similarity"] < 0.95:
                rx, ry = r["x"], r["y"]
                draw.rectangle([rx, ry, rx + cell_w, ry + cell_h], outline=(255, 255, 0), width=1)
                label = f"{r['similarity']:.0%}"
                draw.text((rx + 2, ry + 2), label, fill=(255, 255, 0))

        diff_img.save(diff_output_path)

    return {
        "similarity": round(similarity, 6),
        "similarity_pct": f"{similarity * 100:.2f}%",
        "diff_pixels": diff_count,
        "total_pixels": total,
        "dimensions": {"width": w, "height": h},
        "tolerance": tolerance,
        "worst_regions": region_scores[:10],
        "diff_image": diff_output_path,
    }


def run_preview_pipeline(
    project_dir: str,
    output_dir: str | None = None,
    iteration: int = 1,
) -> dict[str, Any]:
    """Run the full preview pipeline: evaluate → render HTML → screenshot PNG.

    Calls Node.js loop.mjs orchestrator.
    """
    project_dir = os.path.abspath(project_dir)
    out_dir = output_dir or project_dir

    loop_script = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "pbi-preview",
        "loop.mjs",
    )

    if not os.path.isfile(loop_script):
        raise FileNotFoundError(f"loop.mjs not found: {loop_script}")

    result = subprocess.run(
        ["node", loop_script, project_dir, str(iteration), out_dir],
        capture_output=True,
        text=True,
        timeout=60,
        cwd=os.path.dirname(loop_script),
    )

    if result.returncode != 0:
        raise RuntimeError(f"Preview pipeline failed: {result.stderr[:500]}")

    # Parse output for file paths
    measures_path = os.path.join(out_dir, f"measures_v{iteration}.json")
    html_path = os.path.join(out_dir, f"preview_v{iteration}.html")
    png_path = os.path.join(out_dir, f"preview_v{iteration}.png")

    measure_count = 0
    if os.path.isfile(measures_path):
        with open(measures_path, encoding="utf-8") as f:
            measure_count = len(json.load(f))

    return {
        "measures_path": measures_path,
        "html_path": html_path,
        "png_path": png_path,
        "measure_count": measure_count,
        "stdout": result.stdout,
    }
