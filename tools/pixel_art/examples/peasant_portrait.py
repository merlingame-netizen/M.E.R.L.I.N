"""Peasant Portrait — 32x32 bust (shoulders + head), low-poly pixel art.

Run: python tools/pixel_art/examples/peasant_portrait.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.merlin_pixel_forge import GridSprite, upscale
from pixel_art.effects import outline
from pixel_art.palettes import get_palette

# === PALETTE — Earthy peasant tones ===
PAL = {
    '_': (0, 0, 0, 0),            # transparent
    'o': (30, 25, 18, 255),       # outline
    'k': (50, 40, 28, 255),       # dark outline (soft)
    'h': (120, 75, 35, 255),      # hair (chestnut)
    'H': (85, 50, 22, 255),       # hair shadow
    'f': (222, 184, 135, 255),    # face/skin
    'F': (195, 155, 110, 255),    # face shadow
    'n': (180, 140, 100, 255),    # nose/cheek tint
    'e': (55, 40, 30, 255),       # eyes
    'E': (255, 248, 240, 255),    # eye whites
    'm': (175, 120, 100, 255),    # mouth
    'b': (85, 65, 40, 255),       # beard stubble
    'L': (170, 145, 100, 255),    # linen shirt (light)
    'l': (140, 115, 75, 255),     # linen shirt
    'D': (110, 88, 55, 255),      # linen shadow
    'v': (100, 75, 45, 255),      # vest/leather
    'V': (70, 50, 30, 255),       # vest shadow
    'r': (130, 55, 35, 255),      # rope/cord accent
    's': (160, 140, 110, 255),    # skin (neck)
    'S': (140, 118, 85, 255),     # neck shadow
    'c': (95, 80, 55, 255),       # collar
    'p': (175, 155, 125, 255),    # patch/stitch
}

# === 32x32 Peasant portrait — bust from shoulders up ===
GRID = [
    "________________________________",
    "________________________________",
    "___________oHHHHHo______________",
    "__________oHhhhhhHo_____________",
    "_________oHhhhhhhHHo____________",
    "_________ohhhhhhhhhho___________",
    "_________ohhhhhhhhhho___________",
    "_________ohhHhhhHhho____________",
    "_________kffFFFFffk_____________",
    "________kfffFFFFfffk____________",
    "________kffeEfeEffk_____________",
    "________kfffnffnfffk____________",
    "_________kfffnffffk_____________",
    "_________kffFmmFffk_____________",
    "__________kfbbbbfk______________",
    "__________kkfFFfkk______________",
    "___________ksSSsk_______________",
    "___________ksSSSk_______________",
    "__________kcccccck______________",
    "________oVvvLLLLvvVo____________",
    "_______oVvlLLLLLLlvVo___________",
    "______oVvlLLpLLpLLlvVo__________",
    "_____oVvlLLLLLLLLLLlvVo_________",
    "_____oVvlLDLLLLLLDLlvVo_________",
    "____oVvlLDLLLLLLLLDLlvVo________",
    "____oVvlLDLLLLLLLLDLlvVo________",
    "____oVvlDLLLLrrLLLLDlvVo________",
    "____oVvlDLLLLrrLLLLDlvVo________",
    "____oVvDLLLLLLLLLLLLDvVo________",
    "____oVVDDLLLLLLLLLLDDVVo________",
    "____oooooooooooooooooooo________",
    "________________________________",
]


def main():
    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'output', 'pixel_art')
    os.makedirs(output_dir, exist_ok=True)

    sprite = GridSprite(GRID, PAL, "peasant_portrait")

    # Native 32x32
    path_32 = os.path.join(output_dir, "peasant_portrait_32x32.png")
    sprite.export_png(path_32)
    print(f"[OK] Native: {path_32}")

    # Preview 4x (128x128)
    path_4x = os.path.join(output_dir, "peasant_portrait_128x128.png")
    sprite.export_preview(path_4x, scale=4, background=(45, 40, 35))
    print(f"[OK] Preview 4x: {path_4x}")

    # Preview 8x (256x256)
    path_8x = os.path.join(output_dir, "peasant_portrait_256x256.png")
    sprite.export_preview(path_8x, scale=8, background=(45, 40, 35))
    print(f"[OK] Preview 8x: {path_8x}")

    # Outlined version
    rendered = sprite.render()
    outlined = outline(rendered, color=(30, 25, 18, 255))
    outlined_up = upscale(outlined, 6)
    path_out = os.path.join(output_dir, "peasant_portrait_outlined.png")
    outlined_up.save(path_out, 'PNG')
    print(f"[OK] Outlined: {path_out}")

    # Game Boy version
    from pixel_art.effects import floyd_steinberg
    gb = get_palette('gameboy')
    dithered = floyd_steinberg(rendered, gb)
    dithered_up = upscale(dithered, 8)
    path_gb = os.path.join(output_dir, "peasant_portrait_gameboy.png")
    dithered_up.save(path_gb, 'PNG')
    print(f"[OK] Game Boy: {path_gb}")

    print(f"\nDone — {os.path.abspath(output_dir)}")


if __name__ == "__main__":
    main()
