"""Palette presets for pixel art generation.

Each palette maps single-character keys to RGBA tuples.
The '_' key is always transparent (0,0,0,0).
"""

# NES-inspired palette (condensed to 16 usable colors)
NES = {
    '0': (0, 0, 0, 255),          # black
    '1': (252, 252, 252, 255),    # white
    '2': (188, 188, 188, 255),    # light gray
    '3': (124, 124, 124, 255),    # dark gray
    '4': (164, 0, 0, 255),        # dark red
    '5': (228, 0, 40, 255),       # red
    '6': (248, 120, 88, 255),     # salmon
    '7': (0, 120, 0, 255),        # dark green
    '8': (0, 184, 0, 255),        # green
    '9': (88, 216, 84, 255),      # light green
    'a': (0, 0, 168, 255),        # dark blue
    'b': (0, 120, 248, 255),      # blue
    'c': (104, 168, 252, 255),    # light blue
    'd': (248, 184, 0, 255),      # yellow/gold
    'e': (172, 124, 0, 255),      # brown
    'f': (248, 164, 108, 255),    # skin
    '_': (0, 0, 0, 0),            # transparent
}

# Game Boy (4 shades of green)
GAMEBOY = {
    '0': (15, 56, 15, 255),       # darkest
    '1': (48, 98, 48, 255),       # dark
    '2': (139, 172, 15, 255),     # light
    '3': (155, 188, 15, 255),     # lightest
    '_': (0, 0, 0, 0),            # transparent
}

# PICO-8 (16 colors)
PICO8 = {
    '0': (0, 0, 0, 255),          # black
    '1': (29, 43, 83, 255),       # dark blue
    '2': (126, 37, 83, 255),      # dark purple
    '3': (0, 135, 81, 255),       # dark green
    '4': (171, 82, 54, 255),      # brown
    '5': (95, 87, 79, 255),       # dark gray
    '6': (194, 195, 199, 255),    # light gray
    '7': (255, 241, 232, 255),    # white
    '8': (255, 0, 77, 255),       # red
    '9': (255, 163, 0, 255),      # orange
    'a': (255, 236, 39, 255),     # yellow
    'b': (0, 228, 54, 255),       # green
    'c': (41, 173, 255, 255),     # blue
    'd': (131, 118, 156, 255),    # lavender
    'e': (255, 119, 168, 255),    # pink
    'f': (255, 204, 170, 255),    # peach
    '_': (0, 0, 0, 0),            # transparent
}

# Celtic / M.E.R.L.I.N. custom palette (16 colors)
CELTIC = {
    '0': (20, 20, 15, 255),       # near-black (ombre)
    '1': (60, 50, 35, 255),       # dark brown (bois vieux)
    '2': (101, 67, 33, 255),      # brown (bois, cuir)
    '3': (139, 90, 43, 255),      # warm brown (cheveux)
    '4': (222, 184, 135, 255),    # skin tone
    '5': (245, 235, 220, 255),    # cream/parchment
    '6': (0, 80, 50, 255),        # deep forest green
    '7': (34, 139, 34, 255),      # celtic green
    '8': (120, 180, 80, 255),     # moss/lichen
    '9': (90, 90, 100, 255),      # stone gray
    'a': (150, 150, 160, 255),    # light stone
    'b': (192, 192, 200, 255),    # silver/metal
    'c': (180, 140, 50, 255),     # gold (torques)
    'd': (120, 40, 30, 255),      # dark red (sang)
    'e': (70, 70, 120, 255),      # twilight blue
    'f': (140, 100, 180, 255),    # mystic purple
    '_': (0, 0, 0, 0),            # transparent
}

# Earthy / Nature palette
EARTHY = {
    '0': (30, 20, 10, 255),       # deep earth
    '1': (70, 50, 30, 255),       # dark soil
    '2': (120, 80, 40, 255),      # earth
    '3': (170, 120, 60, 255),     # sand
    '4': (210, 180, 130, 255),    # light sand
    '5': (20, 60, 20, 255),       # dark forest
    '6': (40, 100, 40, 255),      # forest
    '7': (80, 150, 60, 255),      # grass
    '8': (140, 190, 80, 255),     # light grass
    '9': (60, 80, 100, 255),      # slate blue
    'a': (100, 130, 160, 255),    # sky
    'b': (160, 200, 220, 255),    # light sky
    'c': (80, 60, 60, 255),       # dark stone
    'd': (130, 120, 110, 255),    # stone
    'e': (190, 180, 170, 255),    # light stone
    'f': (240, 230, 210, 255),    # cream
    '_': (0, 0, 0, 0),            # transparent
}

# Fantasy / Heroic palette
FANTASY = {
    '0': (10, 10, 20, 255),       # void black
    '1': (40, 20, 60, 255),       # deep purple
    '2': (100, 40, 120, 255),     # royal purple
    '3': (180, 60, 40, 255),      # dragon red
    '4': (240, 160, 40, 255),     # gold
    '5': (255, 220, 100, 255),    # bright gold
    '6': (20, 80, 140, 255),      # deep blue
    '7': (60, 140, 200, 255),     # magic blue
    '8': (120, 220, 255, 255),    # ice blue
    '9': (20, 100, 50, 255),      # deep green
    'a': (60, 180, 80, 255),      # emerald
    'b': (200, 200, 210, 255),    # silver armor
    'c': (140, 100, 60, 255),     # leather
    'd': (200, 160, 120, 255),    # skin
    'e': (100, 80, 70, 255),      # dark metal
    'f': (250, 245, 240, 255),    # white
    '_': (0, 0, 0, 0),            # transparent
}


# Registry of all palettes
PALETTES = {
    'nes': NES,
    'gameboy': GAMEBOY,
    'gb': GAMEBOY,
    'pico8': PICO8,
    'pico-8': PICO8,
    'celtic': CELTIC,
    'merlin': CELTIC,
    'earthy': EARTHY,
    'nature': EARTHY,
    'fantasy': FANTASY,
}


def get_palette(name):
    """Get a palette by name. Returns None if not found."""
    return PALETTES.get(name.lower())


def list_palettes():
    """Return list of unique palette names."""
    seen = set()
    names = []
    for name, pal in PALETTES.items():
        pal_id = id(pal)
        if pal_id not in seen:
            seen.add(pal_id)
            names.append(name)
    return names


def nearest_color(rgb, palette):
    """Find the nearest color in a palette to the given RGB tuple.

    Args:
        rgb: (R, G, B) tuple (0-255)
        palette: dict of {char: (R, G, B, A)} or list of (R, G, B, A) tuples

    Returns:
        The palette key (char) of the nearest color.
    """
    colors = palette.items() if isinstance(palette, dict) else enumerate(palette)
    best_key = '_'
    best_dist = float('inf')
    for key, color in colors:
        if key == '_' or (len(color) == 4 and color[3] == 0):
            continue
        dr = rgb[0] - color[0]
        dg = rgb[1] - color[1]
        db = rgb[2] - color[2]
        dist = dr * dr + dg * dg + db * db
        if dist < best_dist:
            best_dist = dist
            best_key = key
    return best_key


def quantize_image(image, palette):
    """Reduce an image to the given palette colors.

    Args:
        image: PIL Image (RGBA)
        palette: dict of {char: (R, G, B, A)}

    Returns:
        New PIL Image with colors quantized to palette.
    """
    from PIL import Image as PILImage

    result = PILImage.new('RGBA', image.size, (0, 0, 0, 0))
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if len(pixel) == 4 and pixel[3] < 128:
                continue
            key = nearest_color(pixel[:3], palette)
            result.putpixel((x, y), palette[key])
    return result
