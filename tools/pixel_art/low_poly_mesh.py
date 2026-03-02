"""LowPolyMesh — Isometric low-poly flat-shaded sprite renderer.

Style: Dark hooded figure with faceted 3D look.
  - Flat-shaded polygons (each face = single color, NO outlines)
  - Shapes defined by color contrast between adjacent facets
  - Dark grayscale palette + one bright accent color (eyes/glyphs)
  - GaussianBlur halo on glow elements
  - 256x256 canvas, downscale to 128x128 for Godot

Usage:
    from pixel_art.low_poly_mesh import LowPolyMesh

    m = LowPolyMesh()
    m.add_facet('hood_l', [(128,20),(80,80),(128,75)], '#2a3038', group='hood')
    m.add_glow('eye_l', (110, 90), 5, '#FFFC68', halo_radius=14, halo_color='#FFFC6840')
    img = m.render_scaled(128)
"""

from dataclasses import dataclass, field
from typing import List, Tuple, Optional

from PIL import Image, ImageDraw, ImageFilter


@dataclass
class Facet:
    """A single polygon face of the low-poly mesh."""
    name: str
    points: List[Tuple[float, float]]
    color: str
    group: str = 'body'
    z_order: int = 0


@dataclass
class GlowDot:
    """A glowing point (eyes, tech glyphs)."""
    name: str
    center: Tuple[float, float]
    radius: float
    color: str
    halo_radius: float = 0
    halo_color: Optional[str] = None
    group: str = 'accent'


class LowPolyMesh:
    """Mesh of flat-shaded polygons for isometric low-poly rendering."""

    def __init__(self, width=256, height=256):
        self.width = width
        self.height = height
        self.facets: List[Facet] = []
        self.glows: List[GlowDot] = []

    def add_facet(self, name, points, color, group='body', z_order=0):
        """Add a polygon facet to the mesh. Returns self for chaining."""
        self.facets.append(Facet(name, list(points), color, group, z_order))
        return self

    def add_glow(self, name, center, radius, color,
                 halo_radius=0, halo_color=None, group='accent'):
        """Add a glow dot (eye, tech glyph). Returns self for chaining."""
        self.glows.append(GlowDot(
            name, tuple(center), radius, color,
            halo_radius, halo_color, group,
        ))
        return self

    def render(self, displacements=None):
        """Render the mesh to a PIL RGBA Image.

        Args:
            displacements: Dict mapping group names to (dx, dy) offsets
                           for animation. Example: {'hood': (0, -1.5)}
        """
        displacements = displacements or {}
        img = Image.new('RGBA', (self.width, self.height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Draw facets sorted by z_order (lower = further back)
        for facet in sorted(self.facets, key=lambda f: f.z_order):
            dx, dy = displacements.get(facet.group, (0, 0))
            pts = [(x + dx, y + dy) for x, y in facet.points]
            draw.polygon(pts, fill=facet.color)

        # Draw glow elements (halos first, then bright centers)
        for glow in self.glows:
            dx, dy = displacements.get(glow.group, (0, 0))
            cx = glow.center[0] + dx
            cy = glow.center[1] + dy

            if glow.halo_radius > 0 and glow.halo_color:
                halo = Image.new('RGBA', (self.width, self.height), (0, 0, 0, 0))
                halo_draw = ImageDraw.Draw(halo)
                r = glow.halo_radius
                halo_draw.ellipse(
                    (cx - r, cy - r, cx + r, cy + r),
                    fill=glow.halo_color,
                )
                blur_r = max(2, int(r // 2))
                halo = halo.filter(ImageFilter.GaussianBlur(radius=blur_r))
                img = Image.alpha_composite(img, halo)
                draw = ImageDraw.Draw(img)

            r = glow.radius
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=glow.color)

        return img

    def render_scaled(self, target=128, displacements=None):
        """Render and downscale with LANCZOS for smooth result."""
        full = self.render(displacements)
        if isinstance(target, int):
            target = (target, target)
        return full.resize(target, Image.LANCZOS)
