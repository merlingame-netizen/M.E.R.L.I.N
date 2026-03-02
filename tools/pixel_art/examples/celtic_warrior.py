"""Example: Celtic Warrior — 32x32 sprite with idle animation.

Demonstrates the full Merlin Pixel Forge pipeline:
- Character sprite defined as ASCII grid + palette
- 4 idle animation frames (breathing effect)
- Export: PNG, upscaled preview, sprite sheet, GIF, Godot .tres

Run: python tools/pixel_art/examples/celtic_warrior.py
"""

import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.merlin_pixel_forge import GridSprite, upscale
from pixel_art.effects import outline, shadow
from pixel_art.animation import SpriteSheet, export_gif, export_godot_tres_file
from pixel_art.palettes import get_palette

# === PALETTE ===
PALETTE = {
    '_': (0, 0, 0, 0),            # transparent
    'o': (20, 20, 15, 255),       # outline/dark
    'h': (139, 90, 43, 255),      # hair (auburn)
    'H': (100, 60, 25, 255),      # hair shadow
    's': (222, 184, 135, 255),    # skin
    'S': (180, 140, 100, 255),    # skin shadow
    'e': (40, 40, 35, 255),       # eyes
    'c': (0, 100, 60, 255),       # cape (forest green)
    'C': (0, 70, 40, 255),        # cape shadow
    'a': (90, 90, 100, 255),      # armor (chainmail)
    'A': (65, 65, 75, 255),       # armor shadow
    'b': (101, 67, 33, 255),      # boots/belt (leather)
    'B': (70, 45, 20, 255),       # boots shadow
    'w': (192, 192, 200, 255),    # weapon (sword blade)
    'W': (150, 150, 160, 255),    # weapon shadow
    'g': (180, 140, 50, 255),     # gold (belt buckle)
    'p': (160, 130, 90, 255),     # pants (linen)
    'P': (130, 100, 65, 255),     # pants shadow
}

# === FRAME 0: Idle (neutral) ===
# Exactly 32 chars per row, 32 rows
FRAME_0 = [
    "________________________________",  # 00
    "________________________________",  # 01
    "____________ohhho_______________",  # 02
    "___________ohhhhho______________",  # 03
    "___________ohHhhHho_____________",  # 04
    "___________oshssho______________",  # 05
    "__________ooseSeso______________",  # 06
    "___________osssso_______________",  # 07
    "___________oosSoo_______________",  # 08
    "____________osso________________",  # 09
    "_________ooccaaccoo____________",  # 10
    "________oCCcaaaaacCCo__________",  # 11
    "________oCCcaAaAacCCo__________",  # 12
    "________oCCcaggaacCCo__________",  # 13
    "________oC_caaaaac_Co_w________",  # 14
    "_________o_caaAAac_o_ow________",  # 15
    "____________oaaaao___owo_______",  # 16
    "___________oopppoo___oWo_______",  # 17
    "___________opPppPpo__owo_______",  # 18
    "___________oppppppo__oWo_______",  # 19
    "___________opPppPpo__owo_______",  # 20
    "___________oppppppo__oo________",  # 21
    "___________opp__ppo____________",  # 22
    "___________obb__bbo____________",  # 23
    "___________oBb__bBo____________",  # 24
    "___________obboobboo___________",  # 25
    "____________oo__oo_____________",  # 26
    "________________________________",  # 27
    "________________________________",  # 28
    "________________________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]

# === FRAME 1: Idle (inhale — body shifts up 1px) ===
FRAME_1 = [
    "________________________________",  # 00
    "____________ohhho_______________",  # 01
    "___________ohhhhho______________",  # 02
    "___________ohHhhHho_____________",  # 03
    "___________oshssho______________",  # 04
    "__________ooseSeso______________",  # 05
    "___________osssso_______________",  # 06
    "___________oosSoo_______________",  # 07
    "____________osso________________",  # 08
    "_________ooccaaccoo____________",  # 09
    "________oCCcaaaaacCCo__________",  # 10
    "________oCCcaAaAacCCo__________",  # 11
    "________oCCcaggaacCCo__________",  # 12
    "________oC_caaaaac_Co_w________",  # 13
    "_________o_caaAAac_o_ow________",  # 14
    "____________oaaaao___owo_______",  # 15
    "___________oopppoo___oWo_______",  # 16
    "___________opPppPpo__owo_______",  # 17
    "___________oppppppo__oWo_______",  # 18
    "___________opPppPpo__owo_______",  # 19
    "___________oppppppo__oo________",  # 20
    "___________opp__ppo____________",  # 21
    "___________obb__bbo____________",  # 22
    "___________oBb__bBo____________",  # 23
    "___________obboobboo___________",  # 24
    "____________oo__oo_____________",  # 25
    "________________________________",  # 26
    "________________________________",  # 27
    "________________________________",  # 28
    "________________________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]

# === FRAME 2: Idle (exhale — body shifts down 1px) ===
FRAME_2 = [
    "________________________________",  # 00
    "________________________________",  # 01
    "________________________________",  # 02
    "____________ohhho_______________",  # 03
    "___________ohhhhho______________",  # 04
    "___________ohHhhHho_____________",  # 05
    "___________oshssho______________",  # 06
    "__________ooseSeso______________",  # 07
    "___________osssso_______________",  # 08
    "___________oosSoo_______________",  # 09
    "____________osso________________",  # 10
    "_________ooccaaccoo____________",  # 11
    "________oCCcaaaaacCCo__________",  # 12
    "________oCCcaAaAacCCo__________",  # 13
    "________oCCcaggaacCCo__________",  # 14
    "________oC_caaaaac_Co_w________",  # 15
    "_________o_caaAAac_o_ow________",  # 16
    "____________oaaaao___owo_______",  # 17
    "___________oopppoo___oWo_______",  # 18
    "___________opPppPpo__owo_______",  # 19
    "___________oppppppo__oWo_______",  # 20
    "___________opPppPpo__owo_______",  # 21
    "___________oppppppo__oo________",  # 22
    "___________opp__ppo____________",  # 23
    "___________obb__bbo____________",  # 24
    "___________oBb__bBo____________",  # 25
    "___________obboobboo___________",  # 26
    "____________oo__oo_____________",  # 27
    "________________________________",  # 28
    "________________________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]


def main():
    output_dir = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'output', 'pixel_art')
    os.makedirs(output_dir, exist_ok=True)

    # GridSprite auto-pads rows to max width
    frames_data = [FRAME_0, FRAME_1, FRAME_0, FRAME_2]
    sprites = [GridSprite(f, PALETTE, "celtic_warrior") for f in frames_data]
    rendered_frames = [s.render() for s in sprites]

    # 1. Single frame PNG (native 32x32)
    path_native = os.path.join(output_dir, "celtic_warrior_32x32.png")
    sprites[0].export_png(path_native)
    print(f"[OK] Native PNG: {path_native}")

    # 2. Upscaled preview (4x = 128x128)
    path_preview = os.path.join(output_dir, "celtic_warrior_128x128.png")
    sprites[0].export_preview(path_preview, scale=4, background=(40, 40, 50))
    print(f"[OK] Preview 4x: {path_preview}")

    # 3. Upscaled preview (8x = 256x256)
    path_big = os.path.join(output_dir, "celtic_warrior_256x256.png")
    sprites[0].export_preview(path_big, scale=8, background=(40, 40, 50))
    print(f"[OK] Preview 8x: {path_big}")

    # 4. Outlined version
    outlined = outline(rendered_frames[0], color=(0, 0, 0, 255))
    outlined_up = upscale(outlined, 4)
    path_outlined = os.path.join(output_dir, "celtic_warrior_outlined.png")
    outlined_up.save(path_outlined, 'PNG')
    print(f"[OK] Outlined: {path_outlined}")

    # 5. Shadow version
    shadowed = shadow(rendered_frames[0], direction="se", color=(0, 0, 0, 100), offset=2)
    shadowed_up = upscale(shadowed, 4)
    path_shadow = os.path.join(output_dir, "celtic_warrior_shadow.png")
    shadowed_up.save(path_shadow, 'PNG')
    print(f"[OK] Shadow: {path_shadow}")

    # 6. Sprite sheet (4 frames in 1 row)
    sheet = SpriteSheet(rendered_frames, columns=4)
    path_sheet = os.path.join(output_dir, "celtic_warrior_sheet.png")
    sheet.export(path_sheet)
    print(f"[OK] Sprite sheet: {path_sheet}")

    # 7. Upscaled sprite sheet (4x)
    path_sheet_4x = os.path.join(output_dir, "celtic_warrior_sheet_4x.png")
    sheet.export(path_sheet_4x, scale=4)
    print(f"[OK] Sprite sheet 4x: {path_sheet_4x}")

    # 8. Animated GIF
    path_gif = os.path.join(output_dir, "celtic_warrior.gif")
    export_gif(rendered_frames, path_gif, fps=4, scale=8)
    print(f"[OK] Animated GIF: {path_gif}")

    # 9. Godot .tres
    path_tres = os.path.join(output_dir, "celtic_warrior_frames.tres")
    export_godot_tres_file(
        path_tres,
        sheet_path="sprites/celtic_warrior_sheet.png",
        frame_count=4,
        fps=4,
        columns=4,
        frame_width=32,
        frame_height=32,
        animation_name="idle",
    )
    print(f"[OK] Godot .tres: {path_tres}")

    # 10. Palette variants (color shift)
    from pixel_art.effects import color_shift
    for angle, name in [(30, "warm"), (180, "ice"), (270, "shadow_variant")]:
        shifted = color_shift(rendered_frames[0], angle)
        shifted_up = upscale(shifted, 4)
        path_var = os.path.join(output_dir, f"celtic_warrior_{name}.png")
        shifted_up.save(path_var, 'PNG')
        print(f"[OK] Variant {name}: {path_var}")

    # 11. Dithered version (Game Boy palette)
    from pixel_art.effects import floyd_steinberg, bayer_dither
    gb_palette = get_palette('gameboy')
    dithered_fs = floyd_steinberg(rendered_frames[0], gb_palette)
    dithered_fs_up = upscale(dithered_fs, 8)
    path_dither = os.path.join(output_dir, "celtic_warrior_gameboy_fs.png")
    dithered_fs_up.save(path_dither, 'PNG')
    print(f"[OK] Floyd-Steinberg (Game Boy): {path_dither}")

    dithered_bayer = bayer_dither(rendered_frames[0], gb_palette)
    dithered_bayer_up = upscale(dithered_bayer, 8)
    path_bayer = os.path.join(output_dir, "celtic_warrior_gameboy_bayer.png")
    dithered_bayer_up.save(path_bayer, 'PNG')
    print(f"[OK] Bayer dither (Game Boy): {path_bayer}")

    print(f"\nAll outputs in: {os.path.abspath(output_dir)}")
    print(f"Total: {len(os.listdir(output_dir))} files")


if __name__ == "__main__":
    main()
