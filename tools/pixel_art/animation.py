"""Sprite sheet and animation export for Godot integration.

Supports:
- Multi-frame sprite sheet generation (grid layout)
- Animated GIF export
- Godot .tres SpriteFrames metadata generation
"""

from PIL import Image
import json
import os


class SpriteSheet:
    """Assembles multiple frames into a sprite sheet.

    Args:
        frames: List of PIL Images (same size, RGBA).
        columns: Number of columns in the sheet grid.
    """

    def __init__(self, frames, columns=None):
        if not frames:
            raise ValueError("At least one frame is required")
        self.frames = frames
        self.frame_width = frames[0].width
        self.frame_height = frames[0].height
        self.columns = columns or len(frames)
        self.rows = (len(frames) + self.columns - 1) // self.columns

    def render(self):
        """Render all frames into a single sprite sheet image.

        Returns:
            PIL.Image.Image (RGBA) with all frames in a grid.
        """
        sheet_w = self.frame_width * self.columns
        sheet_h = self.frame_height * self.rows
        sheet = Image.new('RGBA', (sheet_w, sheet_h), (0, 0, 0, 0))

        for i, frame in enumerate(self.frames):
            col = i % self.columns
            row = i // self.columns
            x = col * self.frame_width
            y = row * self.frame_height
            sheet.paste(frame, (x, y))

        return sheet

    def export(self, path, scale=1):
        """Export the sprite sheet as PNG.

        Args:
            path: Output file path.
            scale: Upscale factor (nearest-neighbor).
        """
        sheet = self.render()
        if scale > 1:
            new_size = (sheet.width * scale, sheet.height * scale)
            sheet = sheet.resize(new_size, Image.NEAREST)
        sheet.save(path, 'PNG')
        return path


def export_spritesheet(frames, path, columns=None, scale=1):
    """Convenience function: frames → PNG sprite sheet.

    Args:
        frames: List of PIL Images.
        path: Output PNG path.
        columns: Grid columns (default: all in one row).
        scale: Upscale factor.

    Returns:
        Output path.
    """
    sheet = SpriteSheet(frames, columns)
    return sheet.export(path, scale)


def export_gif(frames, path, fps=4, scale=1, loop=0):
    """Export frames as an animated GIF.

    Args:
        frames: List of PIL Images (RGBA).
        path: Output GIF path.
        fps: Frames per second.
        scale: Upscale factor.
        loop: Number of loops (0 = infinite).

    Returns:
        Output path.
    """
    duration = int(1000 / fps)
    processed = []

    for frame in frames:
        if scale > 1:
            new_size = (frame.width * scale, frame.height * scale)
            frame = frame.resize(new_size, Image.NEAREST)
        # GIF needs palette mode — convert via intermediate
        rgba = frame.convert('RGBA')
        # Create a white background for GIF (no true transparency in GIF)
        bg = Image.new('RGBA', rgba.size, (0, 0, 0, 0))
        bg.paste(rgba, mask=rgba)
        processed.append(bg)

    # Save with transparency
    processed[0].save(
        path,
        save_all=True,
        append_images=processed[1:],
        duration=duration,
        loop=loop,
        disposal=2,  # restore to background between frames
        transparency=0,
    )
    return path


def export_godot_tres(sheet_path, frame_count, fps=8, columns=None,
                       frame_width=32, frame_height=32, animation_name="default"):
    """Generate a Godot .tres file for SpriteFrames resource.

    Creates a .tres file that can be loaded by AnimatedSprite2D.

    Args:
        sheet_path: Path to the sprite sheet PNG (relative to Godot project).
        frame_count: Total number of frames.
        fps: Animation speed (frames per second).
        columns: Columns in the sheet (default: frame_count).
        frame_width: Width of each frame in pixels.
        frame_height: Height of each frame in pixels.
        animation_name: Name of the animation (default: "default").

    Returns:
        Content of the .tres file as a string.
    """
    columns = columns or frame_count

    # Normalize path for Godot (res://)
    godot_path = sheet_path.replace('\\', '/')
    if not godot_path.startswith('res://'):
        godot_path = 'res://' + godot_path

    # Build .tres content
    lines = [
        '[gd_resource type="SpriteFrames" format=3]',
        '',
        f'[ext_resource type="Texture2D" path="{godot_path}" id="1"]',
        '',
        '[resource]',
        'animations = [{',
        f'"name": &"{animation_name}",',
        f'"speed": {float(fps)},',
        '"loop": true,',
        '"frames": [',
    ]

    for i in range(frame_count):
        col = i % columns
        row = i // columns
        x = col * frame_width
        y = row * frame_height
        lines.append('{')
        lines.append('"texture": SubResource("AtlasTexture_%d"),' % i)
        lines.append('"duration": 1.0,')
        lines.append('},')

    lines.append(']')
    lines.append('}]')

    # Add AtlasTexture sub-resources
    atlas_lines = []
    for i in range(frame_count):
        col = i % columns
        row = i // columns
        x = col * frame_width
        y = row * frame_height
        atlas_lines.extend([
            '',
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]',
            'atlas = ExtResource("1")',
            f'region = Rect2({x}, {y}, {frame_width}, {frame_height})',
        ])

    # Insert atlas sub-resources before [resource]
    resource_idx = lines.index('[resource]')
    for j, line in enumerate(atlas_lines):
        lines.insert(resource_idx + j, line)

    return '\n'.join(lines)


def export_godot_tres_file(tres_path, sheet_path, frame_count, fps=8,
                            columns=None, frame_width=32, frame_height=32,
                            animation_name="default"):
    """Write a .tres file to disk.

    Args:
        tres_path: Output .tres file path.
        sheet_path: Sprite sheet path (relative to Godot project root).
        frame_count: Number of frames.
        fps: Animation speed.
        columns: Sheet columns.
        frame_width: Frame width.
        frame_height: Frame height.
        animation_name: Animation name.

    Returns:
        Output path.
    """
    content = export_godot_tres(
        sheet_path, frame_count, fps, columns,
        frame_width, frame_height, animation_name
    )
    with open(tres_path, 'w', encoding='utf-8') as f:
        f.write(content)
    return tres_path
