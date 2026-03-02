"""Forge Simple — Minimal output sprite pipeline.

Generates ONLY the essential files:
  - name.ase     (editable in LibreSprite/Aseprite)
  - name.png     (frame 0, native size)
  - name.gif     (animated, upscaled — if multi-frame)
  - name_sheet.png (sprite sheet for Godot — if multi-frame)

No more _outlined, _256x256, _preview.html, _gameboy, _warm, etc.

Usage:
    from pixel_art.forge_simple import forge
    forge("merlin", grids=[F0, F1, F2, F3], palette=PAL, fps=4)
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from pixel_art.merlin_pixel_forge import GridSprite, upscale
from pixel_art.animation import SpriteSheet, export_gif
from pixel_art.ase_writer import write_ase

GODOT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUTPUT_DIR = os.path.join(GODOT_ROOT, 'output', 'pixel_art')


def forge(name, grids=None, palette=None, frames=None, fps=4, scale_gif=8, verbose=True):
    """Generate a sprite with minimal output files.

    Accepts EITHER grid-based input (grids + palette) OR pre-rendered Pillow Images (frames).

    Args:
        name: Sprite name (used for filenames).
        grids: List of grid strings (each row is a string, each char is a pixel).
               Mutually exclusive with frames.
        palette: Dict mapping characters to (R, G, B) or (R, G, B, A) tuples.
                 Required when using grids. Use '.' or ' ' for transparent pixels.
        frames: List of PIL Image objects (pre-rendered). Used by ShapeSprite.
                Mutually exclusive with grids.
        fps: Animation speed.
        scale_gif: GIF upscale factor for preview.
        verbose: Print progress.

    Returns:
        Dict with generated file paths.
    """
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    result = {'name': name, 'files': []}

    # Render frames — from grids or pre-rendered images
    if frames is not None:
        pass  # Already PIL Images
    elif grids is not None and palette is not None:
        sprites = [GridSprite(g, palette, name) for g in grids]
        frames = [s.render() for s in sprites]
    else:
        raise ValueError("Provide either (grids + palette) or frames.")
    w, h = frames[0].size
    fc = len(frames)

    if verbose:
        print(f"\n  PIXEL FORGE — {name}  ({w}x{h}, {fc} frames, {fps} fps)")
        print(f"  {'—' * 40}")

    # 1. ASE (always)
    ase_path = os.path.join(OUTPUT_DIR, f'{name}.ase')
    write_ase(ase_path, frames, fps=fps, layer_name=name)
    result['files'].append(ase_path)
    result['ase'] = ase_path
    if verbose:
        print(f"  [1] {name}.ase")

    # 2. PNG frame 0 (always)
    png_path = os.path.join(OUTPUT_DIR, f'{name}.png')
    frames[0].save(png_path, 'PNG')
    result['files'].append(png_path)
    result['png'] = png_path
    if verbose:
        print(f"  [2] {name}.png")

    # 3. GIF animated (if multi-frame)
    if fc > 1:
        gif_path = os.path.join(OUTPUT_DIR, f'{name}.gif')
        export_gif(frames, gif_path, fps=fps, scale=scale_gif)
        result['files'].append(gif_path)
        result['gif'] = gif_path
        if verbose:
            print(f"  [3] {name}.gif  ({scale_gif}x upscaled)")

        # 4. Sprite sheet (if multi-frame)
        sheet_path = os.path.join(OUTPUT_DIR, f'{name}_sheet.png')
        sheet = SpriteSheet(frames, columns=fc)
        sheet.export(sheet_path)
        result['files'].append(sheet_path)
        result['sheet'] = sheet_path
        if verbose:
            print(f"  [4] {name}_sheet.png  ({w * fc}x{h})")

    if verbose:
        print(f"\n  Done — {len(result['files'])} files in output/pixel_art/")
        print(f"  Edit: libresprite.exe \"{ase_path}\"\n")

    return result
