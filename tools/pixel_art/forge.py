"""Merlin Pixel Forge — Unified pipeline.

One-command sprite generation: grid → render → preview → Godot integration.

Usage (from project root):
    python tools/pixel_art/forge.py --example peasant

Or imported:
    from pixel_art.forge import forge_sprite
    forge_sprite(name, grids, palette, fps=4)
"""

import sys
import os

# Ensure pixel_art package is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from pixel_art.merlin_pixel_forge import GridSprite, upscale
from pixel_art.previewer import generate_preview
from pixel_art.godot_integration import integrate_sprite
from pixel_art.animation import SpriteSheet, export_gif
from pixel_art.effects import outline


# Godot project root (this repo)
GODOT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUTPUT_DIR = os.path.join(GODOT_ROOT, 'output', 'pixel_art')


def forge_sprite(name, grids, palette, fps=4, scale_preview=8,
                 godot_integrate=True, open_preview=True):
    """Full pipeline: grids → PNG + preview + Godot integration.

    Args:
        name: Sprite name.
        grids: List of grid strings (one per frame). Single grid = static sprite.
        palette: Dict of {char: (R,G,B,A)}.
        fps: Animation FPS.
        scale_preview: Upscale factor for preview exports.
        godot_integrate: If True, copy to Godot project sprites/ dir.
        open_preview: If True, print the preview path for VS Code.

    Returns:
        Dict with all generated file paths.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    result = {'name': name, 'files': []}

    # Render all frames
    sprites = [GridSprite(g, palette, name) for g in grids]
    frames = [s.render() for s in sprites]
    fw, fh = frames[0].width, frames[0].height

    print(f"\n{'='*50}")
    print(f"  MERLIN PIXEL FORGE — {name}")
    print(f"  {fw}x{fh} | {len(frames)} frame(s) | {fps} FPS")
    print(f"{'='*50}\n")

    # 1. Native PNG
    path = os.path.join(OUTPUT_DIR, f"{name}.png")
    sprites[0].export_png(path)
    result['files'].append(path)
    print(f"  [PNG] {path}")

    # 2. Upscaled preview
    path = os.path.join(OUTPUT_DIR, f"{name}_{fw*scale_preview}x{fh*scale_preview}.png")
    sprites[0].export_preview(path, scale=scale_preview, background=(40, 40, 45))
    result['files'].append(path)
    print(f"  [PNG] {path}")

    # 3. Outlined
    out_img = outline(frames[0], color=(20, 18, 15, 255))
    out_up = upscale(out_img, scale_preview)
    path = os.path.join(OUTPUT_DIR, f"{name}_outlined.png")
    out_up.save(path, 'PNG')
    result['files'].append(path)
    print(f"  [PNG] {path}")

    # 4. Sprite sheet (if animated)
    if len(frames) > 1:
        sheet = SpriteSheet(frames, columns=len(frames))
        path = os.path.join(OUTPUT_DIR, f"{name}_sheet.png")
        sheet.export(path)
        result['files'].append(path)
        print(f"  [SHEET] {path}")

        # GIF
        path = os.path.join(OUTPUT_DIR, f"{name}.gif")
        export_gif(frames, path, fps=fps, scale=scale_preview)
        result['files'].append(path)
        print(f"  [GIF] {path}")

    # 5. HTML Preview (for VS Code)
    path = generate_preview(frames, palette, name, OUTPUT_DIR, fw, fh, fps)
    result['preview'] = path
    result['files'].append(path)
    print(f"  [HTML] {path}")

    # 6. Godot integration
    if godot_integrate:
        godot_result = integrate_sprite(
            frames, name, GODOT_ROOT,
            sprites_dir="sprites/pixel_art",
            fps=fps,
        )
        result['godot'] = godot_result
        for key, val in godot_result.items():
            print(f"  [GODOT:{key.upper()}] {val}")

    print(f"\n  Total: {len(result['files'])} output files")

    if open_preview:
        print(f"\n  Preview: {result['preview']}")
        print(f"  (Ouvrir dans VS Code: Ctrl+Shift+P > 'Simple Browser')")

    return result


if __name__ == "__main__":
    # Quick demo with celtic warrior
    from pixel_art.examples.celtic_warrior import FRAME_0, FRAME_1, FRAME_2, PALETTE
    forge_sprite(
        name="celtic_warrior",
        grids=[FRAME_0, FRAME_1, FRAME_0, FRAME_2],
        palette=PALETTE,
        fps=4,
    )
