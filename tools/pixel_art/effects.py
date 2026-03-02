"""Dithering algorithms and pixel art effects.

Provides Floyd-Steinberg, Bayer, and ordered dithering,
plus sprite effects like outline and shadow.
"""

from PIL import Image
import math


# Bayer 4x4 matrix (normalized 0-15)
BAYER_4X4 = [
    [0,  8,  2, 10],
    [12, 4, 14,  6],
    [3, 11,  1,  9],
    [15, 7, 13,  5],
]

# Bayer 2x2 matrix
BAYER_2X2 = [
    [0, 2],
    [3, 1],
]


def _color_distance(c1, c2):
    """Squared Euclidean distance between two RGB tuples."""
    return sum((a - b) ** 2 for a, b in zip(c1[:3], c2[:3]))


def _find_nearest(rgb, colors):
    """Find the nearest color in a list of (R,G,B,A) tuples."""
    best = colors[0]
    best_dist = _color_distance(rgb, best)
    for c in colors[1:]:
        d = _color_distance(rgb, c)
        if d < best_dist:
            best_dist = d
            best = c
    return best


def floyd_steinberg(image, palette):
    """Apply Floyd-Steinberg error-diffusion dithering.

    Args:
        image: PIL Image (RGBA).
        palette: Dict of {char: (R,G,B,A)}. Only opaque colors are used.

    Returns:
        New PIL Image with dithered colors from the palette.
    """
    colors = [c for k, c in palette.items() if k != '_' and (len(c) < 4 or c[3] > 0)]
    if not colors:
        return image.copy()

    img = image.copy().convert('RGBA')
    pixels = list(img.getdata())
    w, h = img.size
    # Work with float arrays for error diffusion
    buf = [[list(pixels[y * w + x][:3]) for x in range(w)] for y in range(h)]
    alpha = [[pixels[y * w + x][3] if len(pixels[y * w + x]) == 4 else 255
              for x in range(w)] for y in range(h)]

    result = Image.new('RGBA', (w, h), (0, 0, 0, 0))

    for y in range(h):
        for x in range(w):
            if alpha[y][x] < 128:
                continue

            old = buf[y][x]
            nearest = _find_nearest(old, colors)
            result.putpixel((x, y), tuple(nearest))

            # Error
            er = [old[i] - nearest[i] for i in range(3)]

            # Distribute error to neighbors
            for dx, dy, weight in [(1, 0, 7/16), (-1, 1, 3/16), (0, 1, 5/16), (1, 1, 1/16)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and alpha[ny][nx] >= 128:
                    for i in range(3):
                        buf[ny][nx][i] = max(0, min(255, buf[ny][nx][i] + er[i] * weight))

    return result


def bayer_dither(image, palette, matrix_size=4):
    """Apply ordered Bayer matrix dithering.

    Args:
        image: PIL Image (RGBA).
        palette: Dict of {char: (R,G,B,A)}.
        matrix_size: 2 or 4 (Bayer matrix dimension).

    Returns:
        New PIL Image with Bayer-dithered colors.
    """
    colors = [c for k, c in palette.items() if k != '_' and (len(c) < 4 or c[3] > 0)]
    if not colors:
        return image.copy()

    matrix = BAYER_4X4 if matrix_size == 4 else BAYER_2X2
    n = len(matrix)
    scale = 255.0 / (n * n)

    img = image.copy().convert('RGBA')
    result = Image.new('RGBA', img.size, (0, 0, 0, 0))

    for y in range(img.height):
        for x in range(img.width):
            pixel = img.getpixel((x, y))
            if len(pixel) == 4 and pixel[3] < 128:
                continue

            threshold = (matrix[y % n][x % n] + 0.5) * scale - 128
            adjusted = tuple(
                max(0, min(255, int(pixel[i] + threshold))) for i in range(3)
            )
            nearest = _find_nearest(adjusted, colors)
            result.putpixel((x, y), tuple(nearest))

    return result


def ordered_dither(image, palette):
    """Apply ordered dithering (alias for bayer_dither with 4x4 matrix)."""
    return bayer_dither(image, palette, matrix_size=4)


def outline(sprite_image, color=(0, 0, 0, 255), thickness=1):
    """Add a pixel outline around non-transparent pixels.

    Args:
        sprite_image: PIL Image (RGBA).
        color: Outline color as (R, G, B, A).
        thickness: Outline thickness in pixels (default 1).

    Returns:
        New PIL Image with outline added (size increases by 2*thickness).
    """
    w, h = sprite_image.size
    pad = thickness
    result = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))

    # Check each pixel in the expanded canvas
    for y in range(result.height):
        for x in range(result.width):
            sx, sy = x - pad, y - pad

            # If this position has a sprite pixel, keep it
            if 0 <= sx < w and 0 <= sy < h:
                pixel = sprite_image.getpixel((sx, sy))
                if len(pixel) == 4 and pixel[3] > 0:
                    result.putpixel((x, y), pixel)
                    continue

            # Check if any neighbor within thickness has a sprite pixel
            has_neighbor = False
            for dy in range(-pad, pad + 1):
                for dx in range(-pad, pad + 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = sx + dx, sy + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        p = sprite_image.getpixel((nx, ny))
                        if len(p) == 4 and p[3] > 0:
                            has_neighbor = True
                            break
                if has_neighbor:
                    break

            if has_neighbor:
                result.putpixel((x, y), color)

    return result


def shadow(sprite_image, direction="se", color=(0, 0, 0, 128), offset=1):
    """Add a drop shadow to a sprite.

    Args:
        sprite_image: PIL Image (RGBA).
        direction: Shadow direction ("n", "s", "e", "w", "ne", "nw", "se", "sw").
        color: Shadow color (R, G, B, A).
        offset: Shadow offset in pixels.

    Returns:
        New PIL Image with shadow (same size, shadow may clip).
    """
    offsets = {
        'n':  (0, -1), 's':  (0, 1),  'e':  (1, 0),  'w':  (-1, 0),
        'ne': (1, -1), 'nw': (-1, -1), 'se': (1, 1),  'sw': (-1, 1),
    }
    dx, dy = offsets.get(direction, (1, 1))
    dx *= offset
    dy *= offset

    w, h = sprite_image.size
    result = Image.new('RGBA', (w, h), (0, 0, 0, 0))

    # Draw shadow first
    for y in range(h):
        for x in range(w):
            pixel = sprite_image.getpixel((x, y))
            if len(pixel) == 4 and pixel[3] > 0:
                sx, sy = x + dx, y + dy
                if 0 <= sx < w and 0 <= sy < h:
                    result.putpixel((sx, sy), color)

    # Draw sprite on top
    result.paste(sprite_image, mask=sprite_image)
    return result


def color_shift(sprite_image, hue_offset):
    """Shift the hue of all opaque pixels.

    Args:
        sprite_image: PIL Image (RGBA).
        hue_offset: Hue rotation in degrees (0-360).

    Returns:
        New PIL Image with shifted hue.
    """
    result = sprite_image.copy().convert('RGBA')

    for y in range(result.height):
        for x in range(result.width):
            pixel = result.getpixel((x, y))
            if len(pixel) == 4 and pixel[3] < 128:
                continue

            r, g, b = pixel[:3]
            h, s, v = _rgb_to_hsv(r, g, b)
            h = (h + hue_offset / 360.0) % 1.0
            nr, ng, nb = _hsv_to_rgb(h, s, v)
            result.putpixel((x, y), (nr, ng, nb, pixel[3]))

    return result


def _rgb_to_hsv(r, g, b):
    """Convert RGB (0-255) to HSV (0-1, 0-1, 0-1)."""
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    mx = max(r, g, b)
    mn = min(r, g, b)
    diff = mx - mn

    if diff == 0:
        h = 0
    elif mx == r:
        h = ((g - b) / diff) % 6
    elif mx == g:
        h = (b - r) / diff + 2
    else:
        h = (r - g) / diff + 4
    h /= 6.0

    s = 0 if mx == 0 else diff / mx
    v = mx
    return h, s, v


def _hsv_to_rgb(h, s, v):
    """Convert HSV (0-1) to RGB (0-255)."""
    c = v * s
    x = c * (1 - abs((h * 6) % 2 - 1))
    m = v - c

    if h < 1/6:
        r, g, b = c, x, 0
    elif h < 2/6:
        r, g, b = x, c, 0
    elif h < 3/6:
        r, g, b = 0, c, x
    elif h < 4/6:
        r, g, b = 0, x, c
    elif h < 5/6:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x

    return int((r + m) * 255), int((g + m) * 255), int((b + m) * 255)
