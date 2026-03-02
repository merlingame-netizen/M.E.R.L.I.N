"""ShapeSprite — Reigns-style sprite renderer using geometric primitives.

Style reference: Reigns (Nerial, 2016, artist Mieko Murakami)
  - Flat solid fills, zero gradients
  - Geometric primitives: polygons, ellipses, rectangles
  - Thick outlines (3px), near-black warm (#14101e)
  - 4-6 colors per character
  - Diamond/egg base shapes, smooth curves
  - 128x128 canvas (large enough for smooth curves)

Usage:
    from pixel_art.shape_sprite import ShapeSprite

    s = ShapeSprite()
    s.polygon([(64,8),(38,55),(90,55)], fill='#3c2d50')
    s.ellipse((42,40,86,72), fill='#d7bea0')
    img = s.render()
"""

from PIL import Image, ImageDraw

# Default outline color — warm near-black
OUTLINE_COLOR = '#14101e'
OUTLINE_WIDTH = 3


class ShapeSprite:
    """Sprite built from geometric shapes on a transparent canvas."""

    def __init__(self, width=128, height=128):
        self.width = width
        self.height = height
        self.img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)

    def polygon(self, points, fill, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH):
        """Draw a filled polygon with outline.

        Args:
            points: List of (x, y) tuples.
            fill: Fill color (hex string or RGB/RGBA tuple).
            outline: Outline color.
            width: Outline width in pixels.
        """
        self.draw.polygon(points, fill=fill, outline=outline, width=width)

    def ellipse(self, bbox, fill, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH):
        """Draw a filled ellipse with outline.

        Args:
            bbox: Bounding box as (x0, y0, x1, y1).
            fill: Fill color.
            outline: Outline color.
            width: Outline width.
        """
        self.draw.ellipse(bbox, fill=fill, outline=outline, width=width)

    def rect(self, bbox, fill, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH):
        """Draw a filled rectangle with outline.

        Args:
            bbox: Bounding box as (x0, y0, x1, y1).
            fill: Fill color.
            outline: Outline color.
            width: Outline width.
        """
        self.draw.rectangle(bbox, fill=fill, outline=outline, width=width)

    def line(self, points, fill, width=OUTLINE_WIDTH):
        """Draw a line (no fill, just stroke).

        Args:
            points: List of (x, y) tuples.
            fill: Line color.
            width: Line width.
        """
        self.draw.line(points, fill=fill, width=width)

    def circle(self, center, radius, fill, outline=OUTLINE_COLOR, width=OUTLINE_WIDTH):
        """Draw a filled circle (convenience wrapper around ellipse).

        Args:
            center: (cx, cy) tuple.
            radius: Circle radius in pixels.
            fill: Fill color.
            outline: Outline color.
            width: Outline width.
        """
        cx, cy = center
        self.draw.ellipse(
            (cx - radius, cy - radius, cx + radius, cy + radius),
            fill=fill, outline=outline, width=width,
        )

    def render(self):
        """Return the final PIL Image."""
        return self.img.copy()

    def render_scaled(self, target_size):
        """Return the image downscaled to target_size (e.g. 64x64 for Godot).

        Uses LANCZOS for smooth downscale.
        """
        if isinstance(target_size, int):
            target_size = (target_size, target_size)
        return self.img.resize(target_size, Image.LANCZOS)
