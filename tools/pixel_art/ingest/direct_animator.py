"""Direct animator — animate a source image by cutting into layers.

Instead of extracting polygons (which loses anti-aliasing and gradients),
this module cuts the source image into spatial regions (anatomical groups)
and moves each region independently for animation.

This preserves the EXACT quality of the ChatGPT/AI image while adding
organic motion.

Algorithm:
  1. Paste the FULL original image as a static base layer (gap filler).
  2. Cut the source image into padded, feathered layers per group.
  3. Displace each layer per animation frame.
  4. Composite: base (static) + layers (animated) in z-order.

The result is an animated version of the ORIGINAL image at full quality
with no visible seams between layers.
"""

import os
import sys
import math
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass

from PIL import Image, ImageFilter
import numpy as np

from .layer_splitter import AnatomyType, ANATOMY_ZONES, AnatomyZone
from .anatomy_animator import (
    generate_displacements, generate_walk_displacements,
    GroupMotion, GroupTransform, IDLE_PRESETS,
)

# Padding (pixels) added around each layer to hide seams
LAYER_PADDING = 20
# Feather radius for soft edges on layer boundaries
FEATHER_RADIUS = 12


@dataclass
class ImageLayer:
    """A cropped region of the source image."""
    name: str
    image: Image.Image       # RGBA cropped region (padded + feathered)
    offset_x: int            # position in source image
    offset_y: int
    z_order: int             # drawing order


def _feather_edges(image: Image.Image, radius: int) -> Image.Image:
    """Apply soft alpha feathering to the edges of an RGBA image.

    Only fades pixels near the crop boundary — interior pixels keep
    their original alpha.
    """
    if radius <= 0:
        return image

    w, h = image.size
    arr = np.array(image)
    alpha = arr[:, :, 3].astype(np.float32)

    # Build distance-from-edge ramp (0 at edge, 1 at radius)
    ramp_y = np.minimum(
        np.arange(h, dtype=np.float32),
        np.arange(h - 1, -1, -1, dtype=np.float32),
    ).clip(0, radius) / max(radius, 1)

    ramp_x = np.minimum(
        np.arange(w, dtype=np.float32),
        np.arange(w - 1, -1, -1, dtype=np.float32),
    ).clip(0, radius) / max(radius, 1)

    # 2D ramp = min of x and y distance
    ramp = np.minimum(ramp_y[:, None], ramp_x[None, :])

    # Smooth the ramp (cubic ease)
    ramp = ramp * ramp * (3.0 - 2.0 * ramp)

    # Multiply original alpha by ramp
    arr[:, :, 3] = (alpha * ramp).astype(np.uint8)
    return Image.fromarray(arr)


def _erase_rect(
    frame: Image.Image,
    x: int, y: int, w: int, h: int,
    feather: int = 12,
) -> None:
    """Erase a rectangular region from a frame with soft edges.

    Used to remove the static base image under layers that will be
    rotated or scaled, preventing the unrotated 'ghost' from showing.
    Shrinks the erase zone by feather pixels on each side to avoid
    erasing neighboring content.
    """
    arr = np.array(frame)
    # Shrink the erase zone to avoid cutting into neighboring layers
    ex1 = max(0, x + feather)
    ey1 = max(0, y + feather)
    ex2 = min(arr.shape[1], x + w - feather)
    ey2 = min(arr.shape[0], y + h - feather)

    if ex2 <= ex1 or ey2 <= ey1:
        return

    # Fade alpha to zero in the interior (hard erase)
    arr[ey1:ey2, ex1:ex2, 3] = 0

    # Soft feather at borders (gradual fade from existing alpha to 0)
    for i in range(feather):
        fade = (feather - i) / feather  # 1.0 at edge, 0.0 at interior
        # Top border
        row = max(0, y + i)
        if 0 <= row < arr.shape[0]:
            arr[row, ex1:ex2, 3] = (arr[row, ex1:ex2, 3].astype(np.float32) * fade).astype(np.uint8)
        # Bottom border
        row = min(arr.shape[0] - 1, y + h - 1 - i)
        if 0 <= row < arr.shape[0]:
            arr[row, ex1:ex2, 3] = (arr[row, ex1:ex2, 3].astype(np.float32) * fade).astype(np.uint8)
        # Left border
        col = max(0, x + i)
        if 0 <= col < arr.shape[1]:
            arr[ey1:ey2, col, 3] = (arr[ey1:ey2, col, 3].astype(np.float32) * fade).astype(np.uint8)
        # Right border
        col = min(arr.shape[1] - 1, x + w - 1 - i)
        if 0 <= col < arr.shape[1]:
            arr[ey1:ey2, col, 3] = (arr[ey1:ey2, col, 3].astype(np.float32) * fade).astype(np.uint8)

    # Write back
    frame.paste(Image.fromarray(arr), (0, 0))


def _rotate_layer(image: Image.Image, angle_degrees: float) -> Image.Image:
    """Rotate an RGBA layer around its center, expanding canvas to fit."""
    return image.rotate(
        -angle_degrees,  # PIL rotates counter-clockwise, we want clockwise for positive
        resample=Image.BICUBIC,
        expand=True,
    )


def _scale_layer(
    image: Image.Image,
    scale_x: float,
    scale_y: float,
) -> Image.Image:
    """Scale an RGBA layer (squash/stretch), keeping center aligned."""
    new_w = max(1, int(image.width * scale_x))
    new_h = max(1, int(image.height * scale_y))
    return image.resize((new_w, new_h), Image.LANCZOS)


def cut_into_layers(
    source: Image.Image,
    anatomy: AnatomyType,
    bbox: Tuple[int, int, int, int],
    padding: int = LAYER_PADDING,
    feather: int = FEATHER_RADIUS,
) -> List[ImageLayer]:
    """Cut a source image into anatomical layers with padding and feathering.

    Args:
        source: RGBA source image.
        anatomy: Creature type for zone definitions.
        bbox: Character bounding box (left, top, right, bottom).
        padding: Extra pixels around each zone to overlap neighbors.
        feather: Soft-edge radius in pixels.

    Returns:
        List of ImageLayer, one per anatomical group.
    """
    zones = ANATOMY_ZONES.get(anatomy, ANATOMY_ZONES[AnatomyType.OBJECT])
    left, top, right, bottom = bbox
    bw = right - left
    bh = bottom - top

    layers = []

    # Process zones from bottom to top (back to front in z-order)
    for z_idx, zone in enumerate(reversed(zones)):
        # Convert zone ratios to pixel coordinates
        x1 = int(left + zone.x_min * bw) - padding
        y1 = int(top + zone.y_min * bh) - padding
        x2 = int(left + zone.x_max * bw) + padding
        y2 = int(top + zone.y_max * bh) + padding

        # Clamp to image bounds
        x1 = max(0, x1)
        y1 = max(0, y1)
        x2 = min(source.width, x2)
        y2 = min(source.height, y2)

        if x2 <= x1 or y2 <= y1:
            continue

        # Crop the region (with padding)
        cropped = source.crop((x1, y1, x2, y2)).copy()

        # Check for content
        arr = np.array(cropped)
        has_content = arr[:, :, 3] > 32
        if not np.any(has_content):
            continue

        # Apply edge feathering to hide seams
        cropped = _feather_edges(cropped, feather)

        layers.append(ImageLayer(
            name=zone.name,
            image=cropped,
            offset_x=x1,
            offset_y=y1,
            z_order=z_idx,
        ))

    return layers


def animate_layers(
    layers: List[ImageLayer],
    anatomy: AnatomyType,
    canvas_size: Tuple[int, int],
    base_image: Optional[Image.Image] = None,
    animation: str = 'idle',
    frame_count: int = 12,
    target_size: int = 128,
    modifiers: Optional[List] = None,
) -> List[Image.Image]:
    """Render animation frames by displacing image layers.

    Args:
        layers: Image layers from cut_into_layers().
        anatomy: Creature type for animation presets.
        canvas_size: (width, height) of source image.
        base_image: Static full image drawn first (gap filler).
        animation: 'idle', 'walk', 'blink', 'sleep', 'alert', 'happy',
                   'curious', 'sad', 'excited', 'scared'.
        frame_count: Number of frames.
        target_size: Output size (LANCZOS downscale).
        modifiers: List of FrameModifier to apply after compositing.

    Returns:
        List of PIL Images (RGBA, target_size x target_size).
    """
    # Get displacement maps
    if animation == 'walk':
        disp_frames = generate_walk_displacements(anatomy, frame_count)
    else:
        disp_frames = generate_displacements(anatomy, frame_count,
                                             animation=animation)

    # Scale displacements to source image size
    # (presets are calibrated for 256px, source may be larger)
    scale_factor = canvas_size[0] / 256.0

    frames = []
    for frame_idx, disp in enumerate(disp_frames):
        # Start with transparent canvas
        frame = Image.new('RGBA', canvas_size, (0, 0, 0, 0))

        # Draw static base image first (fills gaps between moving layers)
        if base_image is not None:
            frame.paste(base_image, (0, 0), base_image)

        # Draw animated layers on top in z-order (back to front)
        sorted_layers = sorted(layers, key=lambda l: l.z_order)
        _default_transform = GroupTransform()
        for layer in sorted_layers:
            transform = disp.get(layer.name, _default_transform)
            # Scale displacement
            px_dx = int(round(transform.dx * scale_factor))
            px_dy = int(round(transform.dy * scale_factor))

            has_rotation = abs(transform.rotation) > 0.1
            has_scale = (abs(transform.scale_x - 1.0) > 0.001
                         or abs(transform.scale_y - 1.0) > 0.001)

            layer_img = layer.image

            # Anti-ghosting: erase the original layer footprint from
            # the base image before drawing the transformed version.
            # Without this, the static base shows through and masks
            # rotation/scale effects.
            if (has_rotation or has_scale) and base_image is not None:
                _erase_rect(frame, layer.offset_x, layer.offset_y,
                            layer.image.width, layer.image.height,
                            feather=FEATHER_RADIUS)

            # Apply rotation around layer center
            if has_rotation:
                layer_img = _rotate_layer(layer_img, transform.rotation)

            # Apply scale (squash/stretch)
            if has_scale:
                layer_img = _scale_layer(layer_img, transform.scale_x, transform.scale_y)

            # Compute paste position (center the transformed layer)
            cx_offset = (layer_img.width - layer.image.width) // 2
            cy_offset = (layer_img.height - layer.image.height) // 2
            paste_x = layer.offset_x + px_dx - cx_offset
            paste_y = layer.offset_y + px_dy - cy_offset

            # Paste with alpha compositing
            frame.paste(layer_img, (paste_x, paste_y), layer_img)

        # Apply frame modifiers (blink, etc.) BEFORE downscale
        # Extract head displacement for position-tracking modifiers
        head_transform = disp.get('head', _default_transform)
        head_dy = head_transform.dy * scale_factor
        head_dx = head_transform.dx * scale_factor
        if modifiers:
            for mod in modifiers:
                frame = mod.apply(frame, frame_idx, frame_count,
                                  scale_factor, head_dy=head_dy,
                                  head_dx=head_dx)

        # Clean ghost pixels: zero out RGB where alpha=0
        arr = np.array(frame)
        ghost = arr[:, :, 3] == 0
        arr[ghost, :3] = 0
        frame = Image.fromarray(arr)

        # Downscale
        if target_size and target_size != canvas_size[0]:
            frame = frame.resize(
                (target_size, target_size),
                Image.LANCZOS,
            )

        frames.append(frame)

    return frames


def direct_animate(
    image_path: str,
    anatomy: str = 'creature',
    animation: str = 'idle',
    frame_count: int = 12,
    target_size: int = 128,
    verbose: bool = True,
) -> List[Image.Image]:
    """Full pipeline: source image -> cut layers -> animate -> frames.

    This is the RECOMMENDED approach for ChatGPT images as it preserves
    the exact visual quality (no polygon extraction artifacts).

    Supported animations:
        idle    — gentle breathing + sway
        walk    — leg alternation + body bob
        blink   — idle + periodic eye blink
        sleep   — slow breathing + eyes closed
        alert   — ears up, body tense, tail down
        happy   — fast tail wag, bouncy body
        curious — head tilt, raised ear, questioning pose
        sad     — head drooping, body slumped, tail low
        excited — fast bounce, squash/stretch, wild tail
        scared  — recoil, ears flat, tail tucked

    Args:
        image_path: Path to PNG.
        anatomy: Creature type.
        animation: Animation type (see above).
        frame_count: Number of frames.
        target_size: Output size.
        verbose: Print info.

    Returns:
        List of PIL Images.
    """
    anatomy_type = AnatomyType(anatomy)
    img = Image.open(image_path).convert('RGBA')
    arr = np.array(img)

    # Compute bounding box
    alpha = arr[:, :, 3]
    opaque = alpha > 128
    if not np.any(opaque):
        raise ValueError("Image has no opaque pixels")

    rows = np.any(opaque, axis=1)
    cols = np.any(opaque, axis=0)
    top = int(np.argmax(rows))
    bottom = int(len(rows) - np.argmax(rows[::-1]))
    left = int(np.argmax(cols))
    right = int(len(cols) - np.argmax(cols[::-1]))
    bbox = (left, top, right, bottom)

    if verbose:
        name = os.path.splitext(os.path.basename(image_path))[0]
        print(f"\n  DIRECT ANIMATE — {name}")
        print(f"  Size: {img.width}x{img.height}")
        print(f"  Bbox: ({left},{top}) -> ({right},{bottom})")
        print(f"  Animation: {animation}")

    # Cut into layers (padded + feathered)
    layers = cut_into_layers(img, anatomy_type, bbox)
    if verbose:
        print(f"  Layers: {', '.join(l.name for l in layers)}")
        print(f"  Padding: {LAYER_PADDING}px, Feather: {FEATHER_RADIUS}px")

    # Auto-detect eyes for blink/sleep animations
    modifiers = []
    if animation in ('blink', 'sleep'):
        from .eye_detector import detect_eyes
        from .frame_modifiers import BlinkModifier
        eyes = detect_eyes(img, bbox, anatomy_type, verbose=verbose)
        if eyes:
            schedule = 'closed' if animation == 'sleep' else 'periodic'
            modifiers.append(BlinkModifier(eyes, schedule=schedule,
                                                  desync_frames=0))
            if verbose:
                print(f"  Blink: {len(eyes)} eyes, schedule={schedule}")
        elif verbose:
            print(f"  Blink: no eyes detected, skipping blink modifier")

    # Animate with static base image as gap filler
    frames = animate_layers(
        layers, anatomy_type,
        canvas_size=(img.width, img.height),
        base_image=img,
        animation=animation,
        frame_count=frame_count,
        target_size=target_size,
        modifiers=modifiers if modifiers else None,
    )
    if verbose:
        print(f"  Frames: {len(frames)} x {target_size}x{target_size}")

    return frames
