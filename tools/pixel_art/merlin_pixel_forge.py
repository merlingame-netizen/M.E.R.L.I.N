"""Merlin Pixel Forge — Core engine for pixel art generation.

Converts ASCII grids + color palettes into pixel art images.
Designed to be driven by Claude from natural language descriptions.

Usage:
    from merlin_pixel_forge import GridSprite

    sprite = GridSprite(grid=["__oo__", "_oxxo_", ...], palette={'o': (0,0,0,255), ...})
    sprite.export_png("output.png")
    sprite.export_png("output_4x.png", scale=4)
"""

from PIL import Image


class GridSprite:
    """A pixel art sprite defined by a character grid and color palette.

    Args:
        grid: List of strings, each string is one row of pixels.
              Each character maps to a color in the palette.
        palette: Dict mapping single characters to (R, G, B, A) tuples.
                 '_' is always transparent.
        name: Optional name for the sprite (used in export filenames).
    """

    def __init__(self, grid, palette, name="sprite"):
        self.grid = grid
        self.palette = dict(palette)
        if '_' not in self.palette:
            self.palette['_'] = (0, 0, 0, 0)
        self.name = name
        self._validate()

    def _validate(self):
        """Validate and normalize grid: pad all rows to max width with '_'."""
        if not self.grid:
            raise ValueError("Grid cannot be empty")
        max_width = max(len(row) for row in self.grid)
        # Auto-pad short rows with transparent pixels
        self.grid = [row.ljust(max_width, '_') for row in self.grid]

    @property
    def width(self):
        return len(self.grid[0]) if self.grid else 0

    @property
    def height(self):
        return len(self.grid)

    def render(self):
        """Render the grid into a PIL Image (RGBA).

        Returns:
            PIL.Image.Image in RGBA mode.
        """
        img = Image.new('RGBA', (self.width, self.height), (0, 0, 0, 0))
        for y, row in enumerate(self.grid):
            for x, char in enumerate(row):
                color = self.palette.get(char, (255, 0, 255, 255))  # magenta = missing
                if len(color) == 3:
                    color = (*color, 255)
                img.putpixel((x, y), color)
        return img

    def mirror_h(self):
        """Return a new GridSprite mirrored horizontally (left half → full).

        The grid is assumed to be the LEFT half. The result is
        left + reversed(left), doubling the width.
        """
        mirrored_grid = [row + row[::-1] for row in self.grid]
        return GridSprite(mirrored_grid, self.palette, self.name)

    def mirror_v(self):
        """Return a new GridSprite mirrored vertically (top half → full)."""
        mirrored_grid = list(self.grid) + list(reversed(self.grid))
        return GridSprite(mirrored_grid, self.palette, self.name)

    def flip_h(self):
        """Return a new GridSprite flipped horizontally."""
        flipped_grid = [row[::-1] for row in self.grid]
        return GridSprite(flipped_grid, self.palette, self.name)

    def export_png(self, path, scale=1):
        """Export the sprite as a PNG file.

        Args:
            path: Output file path.
            scale: Upscale factor (nearest-neighbor). 1 = native size.
        """
        img = self.render()
        if scale > 1:
            img = upscale(img, scale)
        img.save(path, 'PNG')
        return path

    def export_preview(self, path, scale=4, background=None):
        """Export an upscaled preview with optional background color.

        Args:
            path: Output file path.
            scale: Upscale factor (default 4x for visibility).
            background: Optional (R, G, B) background color. None = transparent.
        """
        img = self.render()
        if background is not None:
            bg = Image.new('RGBA', img.size, (*background, 255))
            bg.paste(img, mask=img)
            img = bg
        if scale > 1:
            img = upscale(img, scale)
        img.save(path, 'PNG')
        return path

    def __repr__(self):
        return f"GridSprite('{self.name}', {self.width}x{self.height})"


def render_grid(grid, palette):
    """Render a character grid with a palette into a PIL Image.

    Args:
        grid: List of strings (rows of character pixels).
        palette: Dict mapping chars to (R, G, B, A) tuples.

    Returns:
        PIL.Image.Image in RGBA mode.
    """
    sprite = GridSprite(grid, palette)
    return sprite.render()


def upscale(image, factor):
    """Upscale an image using nearest-neighbor interpolation.

    Args:
        image: PIL Image.
        factor: Integer scale factor (2 = double, 4 = quadruple, etc.)

    Returns:
        New PIL Image at the scaled size.
    """
    new_size = (image.width * factor, image.height * factor)
    return image.resize(new_size, Image.NEAREST)


def export_png(grid, palette, path, scale=1):
    """Convenience function: grid + palette → PNG file.

    Args:
        grid: List of strings.
        palette: Dict of {char: (R, G, B, A)}.
        path: Output PNG path.
        scale: Upscale factor.
    """
    sprite = GridSprite(grid, palette)
    return sprite.export_png(path, scale)
