"""Druid Merlin — 32x32 animated sprite, professional quality.

A hooded druid with a staff, cape flowing, and magical aura.
4-frame idle animation with real sub-pixel animation:
  - Frame 0: Neutral stance
  - Frame 1: Slight lean forward, cape billows, staff glow pulses
  - Frame 2: Return to neutral (mirrored weight shift)
  - Frame 3: Lean back slightly, cape settles, glow dims

Run: python tools/pixel_art/examples/druid_merlin.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.libresprite_bridge import forge_with_libresprite

# === PALETTE — Rich forest druid tones with magical accents ===
# Each character maps to an RGBA color
PAL = {
    # Transparency
    '_': (0, 0, 0, 0),

    # Outlines & darks
    'O': (15, 12, 8, 255),         # hard outline (near black)
    'o': (35, 28, 20, 255),        # soft outline (dark brown)
    'k': (55, 45, 32, 255),        # mid outline

    # Skin tones (weathered old druid)
    'f': (210, 175, 130, 255),     # face light
    'F': (185, 148, 105, 255),     # face mid
    'n': (160, 125, 85, 255),      # face shadow / nose
    'N': (140, 108, 70, 255),      # deep face shadow

    # Eyes
    'e': (45, 35, 25, 255),        # eye dark
    'E': (85, 145, 180, 255),      # eye iris (mystic blue)
    'w': (235, 228, 215, 255),     # eye white

    # Beard (long, grey-white)
    'b': (200, 195, 185, 255),     # beard light
    'B': (165, 158, 148, 255),     # beard mid
    'g': (130, 125, 118, 255),     # beard shadow

    # Hood & Robe (deep forest green)
    'h': (45, 75, 50, 255),        # hood light
    'H': (30, 55, 35, 255),        # hood mid
    'R': (22, 42, 28, 255),        # robe dark
    'r': (38, 65, 42, 255),        # robe mid

    # Cape (darker green, distinct from robe)
    'c': (28, 58, 38, 255),        # cape light
    'C': (18, 40, 25, 255),        # cape dark

    # Staff (gnarled wood)
    's': (120, 85, 45, 255),       # staff light
    'S': (90, 62, 30, 255),        # staff mid
    't': (65, 45, 20, 255),        # staff dark

    # Magic glow (top of staff)
    'M': (120, 220, 180, 255),     # magic bright
    'm': (80, 180, 140, 255),      # magic mid
    'j': (50, 140, 110, 255),      # magic dim
    'J': (30, 100, 80, 255),       # magic faint

    # Belt & accessories
    'L': (100, 70, 35, 255),       # leather light
    'l': (75, 50, 22, 255),        # leather dark

    # Shoes
    'x': (60, 42, 18, 255),        # boot
    'X': (40, 28, 12, 255),        # boot shadow
}

# ===================================================================
# 32x32 FRAMES — Each line is EXACTLY 32 characters
# Character placement is pixel-precise for animation coherence
# ===================================================================

# === FRAME 0: Idle — Neutral stance, staff upright ===
FRAME_0 = [
    "________________jM_____________",  # 00  staff glow
    "_______________jMmj____________",  # 01  magic aura
    "_______________mMmj____________",  # 02
    "________________sO_____________",  # 03  staff top
    "________________sO_____________",  # 04
    "_________OHHHHHOsO_____________",  # 05  hood top
    "________OHhhhhhHsO_____________",  # 06
    "_______OHhhhhhhHsO_____________",  # 07
    "_______OhhhHHhhhsO_____________",  # 08  hood sides
    "_______OhfFFFFFhsO_____________",  # 09  face starts
    "_______OfwEfnfEwfsO____________",  # 10  eyes + nose
    "_______OFFfnnfFFfsO____________",  # 11  face mid
    "_______OkfFnnFfksO_____________",  # 12  cheeks
    "________OkbBBBbksO_____________",  # 13  beard top
    "________OkbgBgbksO_____________",  # 14  beard mid
    "________OObbBbbOsO_____________",  # 15  beard bottom
    "_______OHHrbBbrHsO_____________",  # 16  robe + beard
    "______OHrrrLLrrrsO_____________",  # 17  robe + belt
    "_____OHrrrlllrrrsO_____________",  # 18  robe + belt
    "_____OCrrrrrrrrrsO_____________",  # 19  cape + robe
    "____OCCrrRRRRrrrsO_____________",  # 20  cape + robe dark
    "____OCCrRRRRRRrrsO_____________",  # 21
    "____OCCrRRRRRRrrsO_____________",  # 22
    "_____OCrRRRRRRrrsO_____________",  # 23
    "_____OOCrRRRRRrsOO_____________",  # 24
    "______OOrRRRRrrOO______________",  # 25
    "_______OOrRRRrOO_______________",  # 26
    "_______OOxxOxxOO_______________",  # 27  boots
    "________OXxOxXO________________",  # 28
    "________OOOOOOO________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]

# === FRAME 1: Inhale — Body shifts up 1px, glow pulses brighter ===
FRAME_1 = [
    "_______________jMj_____________",  # 00  glow slightly bigger
    "______________jMMmj____________",  # 01  brighter pulse
    "______________jmMmj____________",  # 02
    "_______________jmj_____________",  # 03
    "________________sO_____________",  # 04  staff
    "_________OHHHHHOsO_____________",  # 05  everything shifts up 1px
    "________OHhhhhhHsO_____________",  # 06
    "_______OHhhhhhhHsO_____________",  # 07
    "_______OhhhHHhhhsO_____________",  # 08
    "_______OhfFFFFFhsO_____________",  # 09
    "_______OfwEfnfEwfsO____________",  # 10
    "_______OFFfnnfFFfsO____________",  # 11
    "_______OkfFnnFfksO_____________",  # 12
    "________OkbBBBbksO_____________",  # 13
    "________OkbgBgbksO_____________",  # 14
    "________OObbBbbOsO_____________",  # 15
    "_______OHHrbBbrHsO_____________",  # 16
    "______OHrrrLLrrrsO_____________",  # 17
    "_____OHrrrlllrrrsO_____________",  # 18
    "_____OCrrrrrrrrrsO_____________",  # 19
    "____OCCrrRRRRrrrsO_____________",  # 20
    "____OCCrRRRRRRrrsO_____________",  # 21
    "____OCCrRRRRRRrrsO_____________",  # 22
    "_____OCrRRRRRRrrsO_____________",  # 23
    "_____OOCrRRRRRrsOO_____________",  # 24
    "______OOrRRRRrrOO______________",  # 25
    "_______OOrRRRrOO_______________",  # 26
    "_______OOxxOxxOO_______________",  # 27
    "________OXxOxXO________________",  # 28
    "________OOOOOOO________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]

# === FRAME 2: Cape billow — Cape extends, subtle sway ===
FRAME_2 = [
    "________________jM_____________",  # 00  glow back to normal
    "_______________jMmj____________",  # 01
    "_______________mMmj____________",  # 02
    "________________sO_____________",  # 03
    "________________sO_____________",  # 04
    "_________OHHHHHOsO_____________",  # 05
    "________OHhhhhhHsO_____________",  # 06
    "_______OHhhhhhhHsO_____________",  # 07
    "_______OhhhHHhhhsO_____________",  # 08
    "_______OhfFFFFFhsO_____________",  # 09
    "_______OfwEfnfEwfsO____________",  # 10
    "_______OFFfnnfFFfsO____________",  # 11
    "_______OkfFnnFfksO_____________",  # 12
    "________OkbBBBbksO_____________",  # 13
    "________OkbgBgbksO_____________",  # 14
    "________OObbBbbOsO_____________",  # 15
    "_______OHHrbBbrHsO_____________",  # 16
    "______OHrrrLLrrrsO_____________",  # 17
    "_____OHrrrlllrrrsO_____________",  # 18
    "____OCCrrrrrrrrrsO_____________",  # 19  cape extends left
    "___OCCCrrRRRRrrrsO_____________",  # 20  cape billow
    "___OCCCrRRRRRRrrsO_____________",  # 21
    "____OCCrRRRRRRrrsO_____________",  # 22
    "_____OCrRRRRRRrrsO_____________",  # 23
    "_____OOCrRRRRRrsOO_____________",  # 24
    "______OOrRRRRrrOO______________",  # 25
    "_______OOrRRRrOO_______________",  # 26
    "_______OOxxOxxOO_______________",  # 27
    "________OXxOxXO________________",  # 28
    "________OOOOOOO________________",  # 29
    "________________________________",  # 30
    "________________________________",  # 31
]

# === FRAME 3: Exhale — Body shifts down 1px, glow dims ===
FRAME_3 = [
    "________________________________",  # 00  no glow top
    "________________J______________",  # 01  glow very dim
    "_______________jmj_____________",  # 02  dimmer magic
    "_______________jmj_____________",  # 03
    "________________sO_____________",  # 04
    "________________sO_____________",  # 05
    "_________OHHHHHOsO_____________",  # 06  everything shifts down 1px
    "________OHhhhhhHsO_____________",  # 07
    "_______OHhhhhhhHsO_____________",  # 08
    "_______OhhhHHhhhsO_____________",  # 09
    "_______OhfFFFFFhsO_____________",  # 10
    "_______OfwEfnfEwfsO____________",  # 11
    "_______OFFfnnfFFfsO____________",  # 12
    "_______OkfFnnFfksO_____________",  # 13
    "________OkbBBBbksO_____________",  # 14
    "________OkbgBgbksO_____________",  # 15
    "________OObbBbbOsO_____________",  # 16
    "_______OHHrbBbrHsO_____________",  # 17
    "______OHrrrLLrrrsO_____________",  # 18
    "_____OHrrrlllrrrsO_____________",  # 19
    "_____OCrrrrrrrrrsO_____________",  # 20
    "____OCCrrRRRRrrrsO_____________",  # 21
    "____OCCrRRRRRRrrsO_____________",  # 22
    "____OCCrRRRRRRrrsO_____________",  # 23
    "_____OCrRRRRRRrrsO_____________",  # 24
    "_____OOCrRRRRRrsOO_____________",  # 25
    "______OOrRRRRrrOO______________",  # 26
    "_______OOrRRRrOO_______________",  # 27
    "_______OOxxOxxOO_______________",  # 28
    "________OXxOxXO________________",  # 29
    "________OOOOOOO________________",  # 30
    "________________________________",  # 31
]


def main():
    result = forge_with_libresprite(
        name="druid_merlin",
        grids=[FRAME_0, FRAME_1, FRAME_2, FRAME_3],
        palette=PAL,
        fps=3,  # Slow, contemplative idle
        scale_preview=8,
    )
    print(f"\nGenerated {len(result['files'])} files")
    if 'ase' in result:
        print(f"Edit in LibreSprite: libresprite.exe \"{result['ase']}\"")


if __name__ == "__main__":
    main()
