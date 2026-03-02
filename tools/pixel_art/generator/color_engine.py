"""Color engine — generates grayscale ramps, accent derivations, and
automatic facet-to-color mapping based on lighting angle.

The 10-shade grayscale from STYLE_LOWPOLY.md is the reference.
This module can generate custom ramps with different warmth/coolness.

Light source: UPPER-RIGHT (per style guide).
"""

from dataclasses import dataclass
from typing import Dict, Tuple, Optional
import math

from .character_spec import CharacterSpec


# ---------------------------------------------------------------------------
# Reference palette from STYLE_LOWPOLY.md / merlin_lowpoly.py
# ---------------------------------------------------------------------------

REFERENCE_GRAYSCALE = {
    'void':   '#000000',
    'deep':   '#0a0a12',
    'dark1':  '#151520',
    'dark2':  '#222230',
    'dark3':  '#2a3038',
    'mid1':   '#3a4048',
    'mid2':   '#4a5058',
    'mid3':   '#586068',
    'light1': '#687078',
    'light2': '#8a9098',
    'bright': '#a8b0b8',
}

# Shade names in order from darkest to brightest
SHADE_NAMES = [
    'void', 'deep', 'dark1', 'dark2', 'dark3',
    'mid1', 'mid2', 'mid3',
    'light1', 'light2', 'bright',
]


@dataclass(frozen=True)
class ColorMap:
    """Complete color assignment for a character."""
    grayscale: Dict[str, str]
    accent_bright: str
    accent_dim: str
    accent_halo: str


# ---------------------------------------------------------------------------
# Hex <-> RGB utilities
# ---------------------------------------------------------------------------

def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    """Parse #RRGGBB or #RRGGBBAA to (R, G, B)."""
    h = hex_color.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert (R, G, B) to #RRGGBB."""
    return f'#{max(0,min(255,r)):02x}{max(0,min(255,g)):02x}{max(0,min(255,b)):02x}'


def hex_to_hsl(hex_color: str) -> Tuple[float, float, float]:
    """Convert hex to (H, S, L) with H in [0,360], S,L in [0,1]."""
    r, g, b = hex_to_rgb(hex_color)
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    mx, mn = max(rf, gf, bf), min(rf, gf, bf)
    l = (mx + mn) / 2.0

    if mx == mn:
        h = s = 0.0
    else:
        d = mx - mn
        s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
        if mx == rf:
            h = (gf - bf) / d + (6.0 if gf < bf else 0.0)
        elif mx == gf:
            h = (bf - rf) / d + 2.0
        else:
            h = (rf - gf) / d + 4.0
        h *= 60.0

    return (h, s, l)


def hsl_to_hex(h: float, s: float, l: float) -> str:
    """Convert (H, S, L) to hex."""
    if s == 0:
        v = int(round(l * 255))
        return rgb_to_hex(v, v, v)

    def hue2rgb(p, q, t):
        if t < 0: t += 1
        if t > 1: t -= 1
        if t < 1/6: return p + (q - p) * 6 * t
        if t < 1/2: return q
        if t < 2/3: return p + (q - p) * (2/3 - t) * 6
        return p

    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    hn = h / 360.0

    r = int(round(hue2rgb(p, q, hn + 1/3) * 255))
    g = int(round(hue2rgb(p, q, hn) * 255))
    b = int(round(hue2rgb(p, q, hn - 1/3) * 255))
    return rgb_to_hex(r, g, b)


def lerp_color(hex_a: str, hex_b: str, t: float) -> str:
    """Linear interpolation between two hex colors."""
    ra, ga, ba = hex_to_rgb(hex_a)
    rb, gb, bb = hex_to_rgb(hex_b)
    r = int(round(ra + (rb - ra) * t))
    g = int(round(ga + (gb - ga) * t))
    b = int(round(ba + (bb - ba) * t))
    return rgb_to_hex(r, g, b)


# ---------------------------------------------------------------------------
# Grayscale ramp generation
# ---------------------------------------------------------------------------

def generate_grayscale_ramp(shades: int = 10, warmth: float = 0.0) -> Dict[str, str]:
    """Generate an N-shade grayscale ramp.

    warmth: -1.0 (cool blue tint) to 1.0 (warm brown tint).
    warmth == 0.0 returns the EXACT reference palette extracted from the
    ChatGPT images (not computed — hand-tuned values).

    Returns dict with named keys matching SHADE_NAMES.
    """
    # When warmth is 0 (or very close) and shades match, use the EXACT
    # reference palette — this guarantees pixel-perfect M.E.R.L.I.N. output.
    if abs(warmth) < 0.01 and shades >= 10:
        return dict(REFERENCE_GRAYSCALE)

    # For non-standard palettes: tint the reference colors
    result = {}
    for i, name in enumerate(SHADE_NAMES):
        ref_hex = REFERENCE_GRAYSCALE[name]
        if abs(warmth) < 0.01:
            result[name] = ref_hex
            continue

        r, g, b = hex_to_rgb(ref_hex)
        lum = (r + g + b) / (3 * 255)
        tint = lum * 0.18 * abs(warmth) * 255

        if warmth < 0:
            # Cool: blue push
            r = max(0, int(r - tint * 0.5))
            g = max(0, int(g - tint * 0.2))
            b = min(255, int(b + tint * 0.3))
        else:
            # Warm: brown/amber push
            r = min(255, int(r + tint * 0.3))
            g = max(0, int(g - tint * 0.1))
            b = max(0, int(b + tint * 0.4))

        result[name] = rgb_to_hex(r, g, b)

    # Ensure void is always pure black
    result['void'] = '#000000'

    return result


# ---------------------------------------------------------------------------
# Colored ramp generation (for non-grayscale characters)
# ---------------------------------------------------------------------------

def generate_colored_ramp(hue: float, saturation: float = 0.30) -> Dict[str, str]:
    """Generate a colored ramp with the same luminance structure as the reference.

    Takes the reference grayscale luminance values and shifts them to a given
    hue. The result maintains the same dark-to-bright progression but in color.

    Args:
        hue: Hue in degrees (0-360). Common values:
             270=purple, 210=steel blue, 30=amber, 120=forest green, 0=red.
        saturation: Color intensity (0.0=grayscale, 1.0=fully saturated).
                   Recommended: 0.20-0.45 for the low-poly style.

    Returns:
        Dict mapping shade names to hex colors, suitable for color_overrides.

    Usage:
        purple = generate_colored_ramp(hue=270, saturation=0.35)
        spec = CharacterSpec(..., color_overrides=tuple(purple.items()))
    """
    result = {}
    for name in SHADE_NAMES:
        ref_hex = REFERENCE_GRAYSCALE[name]
        r, g, b = hex_to_rgb(ref_hex)
        # Compute luminance of the reference shade
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

        # For void/deep, keep saturation very low (near-black stays near-black)
        effective_sat = saturation * min(1.0, lum * 4.0)

        result[name] = hsl_to_hex(hue, effective_sat, lum)

    # Void is always black
    result['void'] = '#000000'

    return result


# ---------------------------------------------------------------------------
# Accent color derivation
# ---------------------------------------------------------------------------

def derive_dim(bright_hex: str) -> str:
    """Derive the dim variant (~60% brightness, same hue)."""
    h, s, l = hex_to_hsl(bright_hex)
    return hsl_to_hex(h, s, l * 0.6)


def derive_halo(bright_hex: str) -> str:
    """Derive the halo variant (same color + '38' alpha suffix)."""
    h = bright_hex.lstrip('#')[:6]
    return f'#{h}38'


# ---------------------------------------------------------------------------
# Main color map generation
# ---------------------------------------------------------------------------

def generate_color_map(spec: CharacterSpec) -> ColorMap:
    """Generate the full color map from a CharacterSpec."""
    grayscale = generate_grayscale_ramp(
        shades=spec.grayscale_shades,
        warmth=spec.grayscale_warmth,
    )

    accent_bright = spec.accent.bright
    accent_dim = spec.accent.dim or derive_dim(accent_bright)
    accent_halo = spec.accent.halo or derive_halo(accent_bright)

    # Apply color overrides
    for name, hex_val in spec.color_overrides:
        if name in grayscale:
            grayscale[name] = hex_val

    return ColorMap(
        grayscale=grayscale,
        accent_bright=accent_bright,
        accent_dim=accent_dim,
        accent_halo=accent_halo,
    )


# ---------------------------------------------------------------------------
# Lighting-based color assignment
# ---------------------------------------------------------------------------

def assign_color_for_angle(
    angle_deg: float,
    side: str,
    colors: ColorMap,
) -> str:
    """Given a facet's facing angle and side, return the appropriate hex color.

    angle_deg: 0=right, 90=up, 180=left, 270=down
    side: "left" or "right"
    Light source: upper-right (~315 degrees)

    Matches STYLE_LOWPOLY.md lighting model:
    - Facing right/up (toward light): mid2 - bright
    - Facing viewer (flat): mid1 - mid3
    - Facing left (away from light): dark2 - dark3
    - Facing down (deep shadow): dark1 - void
    """
    gs = colors.grayscale

    # Normalize angle to [0, 360)
    angle = angle_deg % 360

    # Right side (toward light) gets brighter colors overall
    brightness_offset = 1 if side == "right" else 0

    if angle < 45 or angle >= 315:
        # Facing right/upper-right (toward light)
        options = ['mid2', 'mid3', 'light1', 'light2', 'bright']
    elif 45 <= angle < 135:
        # Facing up or viewer
        options = ['mid1', 'mid2', 'mid3']
    elif 135 <= angle < 225:
        # Facing left (away from light)
        options = ['dark2', 'dark3', 'mid1']
    else:
        # Facing down (deep shadow)
        options = ['dark1', 'deep', 'void']

    # Apply brightness offset for right-side facets
    idx = min(brightness_offset, len(options) - 1)
    shade_name = options[idx]
    return gs.get(shade_name, gs.get('mid1', '#3a4048'))


def shade_for_layer(layer_name: str, side: str, colors: ColorMap) -> str:
    """Quick shade assignment for named structural layers.

    Used by geometry.py for body/shoulder layers where face angle
    calculation isn't needed.
    """
    gs = colors.grayscale
    shade_map = {
        ('body_fill', 'center'): 'void',
        ('chest_upper', 'center'): 'deep',
        ('chest_lower', 'center'): 'dark1',
        ('chest_seam', 'center'): 'dark2',
        ('shoulder_side', 'left'): 'dark2',
        ('shoulder_top', 'left'): 'mid1',
        ('shoulder_front', 'left'): 'dark3',
        ('shoulder_bevel', 'left'): 'mid2',
        ('shoulder_bottom', 'left'): 'dark1',
        ('shoulder_side', 'right'): 'mid2',
        ('shoulder_top', 'right'): 'mid3',
        ('shoulder_front', 'right'): 'mid1',
        ('shoulder_bevel', 'right'): 'light1',
        ('shoulder_bottom', 'right'): 'dark2',
        ('frame_top', 'center'): 'light2',
        ('frame_right', 'right'): 'light2',
        ('frame_left', 'left'): 'mid2',
        ('face_void', 'center'): 'void',
        ('face_depth', 'left'): 'deep',
        ('face_depth', 'right'): 'deep',
        ('face_chin', 'center'): 'dark1',
        ('drape', 'left'): 'dark1',
        ('drape', 'right'): 'dark2',
    }
    shade_name = shade_map.get((layer_name, side), 'mid1')
    return gs.get(shade_name, '#3a4048')
