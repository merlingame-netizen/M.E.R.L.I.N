"""Sprite assembler — build LowPolyMesh from extracted facets + animate.

This is the glue module that connects:
  polygon_extractor (facets) + layer_splitter (groups) +
  anatomy_animator (displacements) -> LowPolyMesh -> PIL frames -> forge()

The output is a list of PIL Images ready for forge_simple.forge().
"""

import os
import sys
from typing import List, Dict, Tuple, Optional

from PIL import Image

# Add parent to path for pixel_art imports
_parent = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if _parent not in sys.path:
    sys.path.insert(0, _parent)

from pixel_art.low_poly_mesh import LowPolyMesh
from .polygon_extractor import ExtractedFacet
from .layer_splitter import AnatomyType
from .anatomy_animator import generate_displacements, generate_walk_displacements


def build_mesh(
    facets: List[ExtractedFacet],
    canvas_size: Tuple[int, int] = (256, 256),
) -> LowPolyMesh:
    """Build a LowPolyMesh from extracted facets.

    Args:
        facets: List of ExtractedFacet (with group names assigned).
        canvas_size: (width, height) of the rendering canvas.

    Returns:
        LowPolyMesh ready for rendering.
    """
    mesh = LowPolyMesh(canvas_size[0], canvas_size[1])

    for facet in facets:
        mesh.add_facet(
            name=facet.name,
            points=list(facet.points),
            color=facet.color,
            group=facet.group,
            z_order=facet.z_order,
        )

    return mesh


def render_animation(
    facets: List[ExtractedFacet],
    anatomy: AnatomyType,
    animation: str = 'idle',
    frame_count: int = 12,
    canvas_size: Tuple[int, int] = (256, 256),
    target_size: int = 128,
) -> List[Image.Image]:
    """Render a full animation sequence from extracted facets.

    Args:
        facets: Facets with group names assigned by layer_splitter.
        anatomy: Creature type for animation presets.
        animation: 'idle' or 'walk'.
        frame_count: Number of frames to generate.
        canvas_size: Internal rendering canvas.
        target_size: Output frame size (LANCZOS downscale).

    Returns:
        List of PIL Images (RGBA, target_size x target_size).
    """
    mesh = build_mesh(facets, canvas_size)

    # Generate displacement maps
    if animation == 'walk':
        disp_frames = generate_walk_displacements(anatomy, frame_count)
    else:
        disp_frames = generate_displacements(anatomy, frame_count)

    # Render each frame
    frames = []
    for disp in disp_frames:
        frame = mesh.render_scaled(target_size, displacements=disp)
        frames.append(frame)

    return frames


def render_static(
    facets: List[ExtractedFacet],
    canvas_size: Tuple[int, int] = (256, 256),
    target_size: int = 128,
) -> Image.Image:
    """Render a single static frame (no animation).

    Args:
        facets: Extracted facets.
        canvas_size: Internal canvas.
        target_size: Output size.

    Returns:
        Single PIL Image (RGBA).
    """
    mesh = build_mesh(facets, canvas_size)
    return mesh.render_scaled(target_size)
