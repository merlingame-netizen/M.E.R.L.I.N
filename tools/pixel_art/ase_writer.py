"""ASE File Writer — Generate native Aseprite/LibreSprite .ase files.

Writes the ASE binary format directly from Python, enabling:
- Multi-frame animated sprites
- RGBA color mode
- Named layers
- Palette embedding

Format spec: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

Usage:
    from pixel_art.ase_writer import write_ase
    write_ase("output.ase", frames=[pil_image1, pil_image2], fps=4)
"""

import struct
import zlib
from io import BytesIO


# ASE magic number
ASE_MAGIC = 0xA5E0
FRAME_MAGIC = 0xF1FA

# Chunk types
CHUNK_OLD_PALETTE = 0x0004
CHUNK_LAYER = 0x2004
CHUNK_CEL = 0x2005
CHUNK_COLOR_PROFILE = 0x2007
CHUNK_PALETTE = 0x2019

# Color depth
COLOR_RGBA = 32
COLOR_INDEXED = 8

# Layer types
LAYER_NORMAL = 0

# Cel types
CEL_RAW = 0
CEL_COMPRESSED = 2


def _write_word(buf, val):
    """Write 16-bit unsigned LE."""
    buf.write(struct.pack('<H', val & 0xFFFF))


def _write_short(buf, val):
    """Write 16-bit signed LE."""
    buf.write(struct.pack('<h', val))


def _write_dword(buf, val):
    """Write 32-bit unsigned LE."""
    buf.write(struct.pack('<I', val & 0xFFFFFFFF))


def _write_long(buf, val):
    """Write 32-bit signed LE."""
    buf.write(struct.pack('<i', val))


def _write_byte(buf, val):
    """Write 8-bit unsigned."""
    buf.write(struct.pack('B', val))


def _write_string(buf, text):
    """Write ASE string (WORD length + UTF-8 bytes)."""
    encoded = text.encode('utf-8')
    _write_word(buf, len(encoded))
    buf.write(encoded)


def _write_fixed(buf, val):
    """Write 32-bit fixed point (16.16)."""
    int_part = int(val)
    frac_part = int((val - int_part) * 65536)
    _write_word(buf, frac_part)
    _write_word(buf, int_part)


def _build_color_profile_chunk():
    """Build sRGB color profile chunk."""
    chunk = BytesIO()
    _write_word(chunk, 1)       # Type: sRGB
    _write_word(chunk, 0)       # Flags
    _write_fixed(chunk, 2.2)    # Gamma (fixed 16.16)
    # No ICC data for sRGB
    return _wrap_chunk(CHUNK_COLOR_PROFILE, chunk.getvalue())


def _build_palette_chunk(colors):
    """Build palette chunk from list of (R,G,B,A) tuples.

    Args:
        colors: List of (R, G, B, A) color tuples (max 256).

    Returns:
        Chunk bytes.
    """
    n = min(len(colors), 256)
    chunk = BytesIO()
    _write_dword(chunk, n)     # Palette size
    _write_dword(chunk, 0)     # First color index to change
    _write_dword(chunk, n - 1) # Last color index to change

    # 8 reserved bytes
    chunk.write(b'\x00' * 8)

    for i in range(n):
        r, g, b = colors[i][0], colors[i][1], colors[i][2]
        a = colors[i][3] if len(colors[i]) > 3 else 255
        has_name = 0
        _write_word(chunk, has_name)  # Entry flags
        _write_byte(chunk, r)
        _write_byte(chunk, g)
        _write_byte(chunk, b)
        _write_byte(chunk, a)

    return _wrap_chunk(CHUNK_PALETTE, chunk.getvalue())


def _build_layer_chunk(name="Layer 1", opacity=255, visible=True):
    """Build layer chunk.

    Args:
        name: Layer name.
        opacity: Layer opacity (0-255).
        visible: Whether the layer is visible.

    Returns:
        Chunk bytes.
    """
    chunk = BytesIO()
    flags = 0x01 if visible else 0x00  # Bit 0 = visible
    flags |= 0x08  # Bit 3 = editable (prefer to keep)
    _write_word(chunk, flags)         # Flags
    _write_word(chunk, LAYER_NORMAL)  # Layer type
    _write_word(chunk, 0)             # Child level
    _write_word(chunk, 0)             # Default layer width (ignored)
    _write_word(chunk, 0)             # Default layer height (ignored)
    _write_word(chunk, 0)             # Blend mode (normal)
    _write_byte(chunk, opacity)       # Opacity
    chunk.write(b'\x00' * 3)          # Reserved
    _write_string(chunk, name)        # Layer name

    return _wrap_chunk(CHUNK_LAYER, chunk.getvalue())


def _build_cel_chunk(layer_index, x, y, width, height, rgba_data,
                     opacity=255, compress=True):
    """Build cel (frame image data) chunk.

    Args:
        layer_index: Layer index (0-based).
        x: X position of the cel.
        y: Y position of the cel.
        width: Image width.
        height: Image height.
        rgba_data: Raw RGBA pixel data (bytes, 4 bytes per pixel).
        opacity: Cel opacity (0-255).
        compress: Whether to zlib-compress the pixel data.

    Returns:
        Chunk bytes.
    """
    chunk = BytesIO()
    _write_word(chunk, layer_index)  # Layer index
    _write_short(chunk, x)           # X position
    _write_short(chunk, y)           # Y position
    _write_byte(chunk, opacity)      # Opacity
    _write_word(chunk, CEL_COMPRESSED if compress else CEL_RAW)  # Cel type
    _write_short(chunk, 0)           # Z-index (0 = default, since ASE 1.3)

    # 5 reserved bytes (padding to align)
    chunk.write(b'\x00' * 5)

    # Image dimensions (for compressed/raw cels)
    _write_word(chunk, width)
    _write_word(chunk, height)

    # Pixel data
    if compress:
        compressed = zlib.compress(rgba_data, 6)
        chunk.write(compressed)
    else:
        chunk.write(rgba_data)

    return _wrap_chunk(CHUNK_CEL, chunk.getvalue())


def _wrap_chunk(chunk_type, data):
    """Wrap chunk data with header (size + type).

    Args:
        chunk_type: Chunk type ID.
        data: Raw chunk data bytes.

    Returns:
        Complete chunk bytes with header.
    """
    buf = BytesIO()
    total_size = 6 + len(data)  # 4 (size) + 2 (type) + data
    _write_dword(buf, total_size)
    _write_word(buf, chunk_type)
    buf.write(data)
    return buf.getvalue()


def _build_frame(chunks, duration_ms=100):
    """Build a complete frame from chunks.

    Args:
        chunks: List of chunk byte arrays.
        duration_ms: Frame duration in milliseconds.

    Returns:
        Complete frame bytes.
    """
    # Concatenate all chunks
    chunks_data = b''.join(chunks)

    buf = BytesIO()
    frame_size = 16 + len(chunks_data)  # Frame header = 16 bytes

    _write_dword(buf, frame_size)      # Frame size
    _write_word(buf, FRAME_MAGIC)      # Magic number
    _write_word(buf, len(chunks))      # Number of chunks (old field)
    _write_word(buf, duration_ms)      # Frame duration (ms)
    buf.write(b'\x00' * 2)            # Reserved
    _write_dword(buf, len(chunks))    # Number of chunks (new field)

    buf.write(chunks_data)
    return buf.getvalue()


def _pil_to_rgba_bytes(image):
    """Convert a PIL Image to raw RGBA bytes.

    Args:
        image: PIL Image (any mode, will be converted to RGBA).

    Returns:
        Bytes of RGBA pixel data.
    """
    rgba = image.convert('RGBA')
    return rgba.tobytes()


def _extract_palette_colors(images):
    """Extract unique colors from a list of PIL Images.

    Args:
        images: List of PIL Images.

    Returns:
        List of (R, G, B, A) tuples (max 256).
    """
    colors_set = set()
    for img in images:
        rgba = img.convert('RGBA')
        for pixel in rgba.getdata():
            colors_set.add(pixel)

    # Sort: transparent first, then by luminance
    colors = sorted(colors_set, key=lambda c: (c[3] == 0, c[0] + c[1] + c[2]))

    # Ensure transparent is at index 0
    transparent = (0, 0, 0, 0)
    if transparent in colors:
        colors.remove(transparent)
    colors.insert(0, transparent)

    return colors[:256]


def write_ase(output_path, frames, fps=4, layer_name="Layer 1",
              palette_colors=None):
    """Write a multi-frame .ase file.

    Args:
        output_path: Output .ase file path.
        frames: List of PIL Image objects (one per frame, same dimensions).
        fps: Animation frames per second.
        layer_name: Name for the default layer.
        palette_colors: Optional list of (R,G,B,A) colors for palette.
                        If None, extracted from frame images.

    Returns:
        Path to the written .ase file.
    """
    if not frames:
        raise ValueError("At least one frame is required")

    # Ensure consistent dimensions
    width = frames[0].width
    height = frames[0].height
    for i, f in enumerate(frames):
        if f.width != width or f.height != height:
            raise ValueError(
                f"Frame {i} dimensions ({f.width}x{f.height}) "
                f"don't match frame 0 ({width}x{height})"
            )

    frame_count = len(frames)
    duration_ms = max(1, int(1000 / fps))

    # Extract or use provided palette
    if palette_colors is None:
        palette_colors = _extract_palette_colors(frames)

    # Build all frame data
    frame_bytes_list = []

    for i, frame_img in enumerate(frames):
        chunks = []

        # First frame gets layer definition + palette + color profile
        if i == 0:
            chunks.append(_build_color_profile_chunk())
            chunks.append(_build_palette_chunk(palette_colors))
            chunks.append(_build_layer_chunk(name=layer_name))

        # Cel (image data) for every frame
        rgba_bytes = _pil_to_rgba_bytes(frame_img)
        chunks.append(_build_cel_chunk(
            layer_index=0,
            x=0, y=0,
            width=width, height=height,
            rgba_data=rgba_bytes,
            compress=True
        ))

        frame_bytes_list.append(_build_frame(chunks, duration_ms))

    # Build header
    all_frames = b''.join(frame_bytes_list)
    file_size = 128 + len(all_frames)  # Header = 128 bytes

    header = BytesIO()
    _write_dword(header, file_size)      # File size
    _write_word(header, ASE_MAGIC)       # Magic number
    _write_word(header, frame_count)     # Number of frames
    _write_word(header, width)           # Width in pixels
    _write_word(header, height)          # Height in pixels
    _write_word(header, COLOR_RGBA)      # Color depth (32 = RGBA)
    _write_dword(header, 0x00000001)     # Flags (layer opacity valid)
    _write_word(header, 100)             # Speed (deprecated, ms per frame)
    _write_dword(header, 0)              # Reserved
    _write_dword(header, 0)              # Reserved
    _write_byte(header, 0)               # Transparent color index
    header.write(b'\x00' * 3)            # Reserved
    _write_word(header, 0)               # Number of colors (0 = 256 for 8bpp)
    _write_byte(header, 0)               # Pixel width (ratio, 0 = square)
    _write_byte(header, 0)               # Pixel height (ratio, 0 = square)
    _write_short(header, 0)              # X position of the grid
    _write_short(header, 0)              # Y position of the grid
    _write_word(header, 16)              # Grid width
    _write_word(header, 16)              # Grid height
    header.write(b'\x00' * 84)           # Reserved (pad to 128 bytes)

    # Write file
    with open(output_path, 'wb') as f:
        f.write(header.getvalue())
        f.write(all_frames)

    return output_path


def write_ase_from_grids(output_path, grids, palette, fps=4,
                         layer_name="Layer 1"):
    """Write .ase from grid definitions (convenience wrapper).

    Args:
        output_path: Output .ase file path.
        grids: List of grid strings (one per frame).
        palette: Dict of {char: (R,G,B,A)}.
        fps: Animation FPS.
        layer_name: Layer name.

    Returns:
        Path to the written .ase file.
    """
    from pixel_art.merlin_pixel_forge import GridSprite

    sprites = [GridSprite(g, palette, "temp") for g in grids]
    frames = [s.render() for s in sprites]

    # Extract palette colors from the palette dict
    pal_colors = []
    for char, color in palette.items():
        if len(color) == 3:
            color = (*color, 255)
        if color not in pal_colors:
            pal_colors.append(color)

    return write_ase(output_path, frames, fps=fps,
                     layer_name=layer_name,
                     palette_colors=pal_colors)
