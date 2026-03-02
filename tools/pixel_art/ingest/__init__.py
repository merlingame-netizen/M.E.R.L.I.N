"""Ingest pipeline — transform AI-generated images into animated sprites.

Two modes:
  DIRECT (recommended for AI images):
    from pixel_art.ingest import ingest_direct
    result = ingest_direct("bestiole.png", anatomy="quadruped")

  POLYGON (for true flat-shaded low-poly images):
    from pixel_art.ingest import ingest_character
    result = ingest_character("bestiole.png", anatomy="quadruped")

Direct mode preserves EXACT image quality (no polygon extraction artifacts).
Polygon mode extracts flat-colored regions and reconstructs as LowPolyMesh.
"""

import os
import sys
from typing import List, Optional

from PIL import Image

# Ensure parent path for pixel_art imports
_parent = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if _parent not in sys.path:
    sys.path.insert(0, _parent)

from .image_analyzer import analyze_image, print_analysis, ImageAnalysis
from .polygon_extractor import extract_facets, ExtractedFacet
from .layer_splitter import (
    split_into_groups, flatten_groups,
    AnatomyType,
)
from .anatomy_animator import generate_displacements
from .sprite_assembler import render_animation, render_static
from .direct_animator import direct_animate

ALL_ANIMATIONS = [
    'idle', 'walk', 'blink', 'sleep', 'alert',
    'happy', 'curious', 'sad', 'excited', 'scared',
]


def ingest_all_animations(
    image_path: str,
    name: str = None,
    anatomy: str = 'quadruped',
    animations: Optional[List[str]] = None,
    frame_count: int = 12,
    target_size: int = 128,
    godot_export: bool = True,
    verbose: bool = True,
) -> dict:
    """Generate all animations for a character and optionally integrate into Godot.

    Runs direct_animate for each animation type, exports via forge,
    then calls godot_integration to copy sheets + generate .tres/.tscn.

    Args:
        image_path: Path to source PNG with transparent background.
        name: Output name (default: filename stem).
        anatomy: Creature type ('humanoid', 'quadruped', 'creature', 'bird', 'object').
        animations: List of animation types (default: all 10).
        frame_count: Frames per animation.
        target_size: Output sprite size.
        godot_export: If True, also integrate into Godot project.
        verbose: Print progress.

    Returns:
        Dict with keys: name, animations (dict of anim_type -> frames),
        and optionally godot (integration result).
    """
    if name is None:
        name = os.path.splitext(os.path.basename(image_path))[0]
        name = name.replace(' ', '_').replace(',', '').replace('.', '_')

    if animations is None:
        animations = list(ALL_ANIMATIONS)

    result = {'name': name, 'animations': {}}

    for anim_type in animations:
        if verbose:
            print(f"\n  [{anim_type}]")

        frames = direct_animate(
            image_path,
            anatomy=anatomy,
            animation=anim_type,
            frame_count=frame_count,
            target_size=target_size,
            verbose=verbose,
        )

        from pixel_art.forge_simple import forge
        forge(
            f"{name}_{anim_type}",
            frames=frames,
            fps=6,
            scale_gif=4,
            verbose=verbose,
        )

        result['animations'][anim_type] = frames

    if godot_export:
        from pixel_art.godot_integration import integrate_bestiole
        godot_result = integrate_bestiole(
            source_image=image_path,
            anatomy=anatomy,
            animations=animations,
            frame_count=frame_count,
            target_size=target_size,
            regenerate=False,
            verbose=verbose,
        )
        result['godot'] = godot_result

    return result


def ingest_character(
    image_path: str,
    anatomy: str = 'creature',
    animation: str = 'idle',
    frame_count: int = 12,
    target_size: int = 128,
    color_tolerance: int = 12,
    min_area: int = 50,
    max_vertices: int = 8,
    verbose: bool = True,
    export: bool = True,
) -> dict:
    """Full ingestion pipeline: image -> analysis -> extract -> animate -> export.

    Args:
        image_path: Path to PNG with transparent background.
        anatomy: Creature type ('humanoid', 'quadruped', 'creature', 'bird', 'object').
        animation: Animation type ('idle', 'walk').
        frame_count: Number of animation frames.
        target_size: Output sprite size (pixels).
        color_tolerance: Max RGB distance to merge similar colors (0-50).
        min_area: Minimum pixel count per facet.
        max_vertices: Maximum polygon vertices per facet.
        verbose: Print progress info.
        export: If True, export via forge (ase, png, gif, sheet).

    Returns:
        Dict with keys: analysis, facets, groups, frames, and optionally files.
    """
    # Resolve anatomy type
    anatomy_type = AnatomyType(anatomy)
    name = os.path.splitext(os.path.basename(image_path))[0]

    # 1. Analyze
    if verbose:
        print(f"\n  INGEST — {name}")
        print(f"  {'=' * 40}")

    analysis = analyze_image(image_path, color_tolerance, min_area)
    if verbose:
        print_analysis(analysis)

    # 2. Extract facets
    facets = extract_facets(
        image_path,
        color_tolerance=color_tolerance,
        min_area=min_area,
        max_vertices=max_vertices,
    )
    if verbose:
        print(f"  Extracted {len(facets)} facets")

    # 3. Split into anatomical groups
    groups = split_into_groups(facets, anatomy_type, analysis.bbox)
    grouped_facets = flatten_groups(groups)
    if verbose:
        print(f"  Groups: {', '.join(f'{k} ({len(v)})' for k, v in groups.items())}")

    # 4. Determine canvas size from source image
    canvas_size = (analysis.width, analysis.height)

    # 5. Animate
    frames = render_animation(
        grouped_facets,
        anatomy_type,
        animation=animation,
        frame_count=frame_count,
        canvas_size=canvas_size,
        target_size=target_size,
    )
    if verbose:
        print(f"  Rendered {len(frames)} frames ({target_size}x{target_size})")

    result = {
        'name': name,
        'analysis': analysis,
        'facets': facets,
        'groups': groups,
        'grouped_facets': grouped_facets,
        'frames': frames,
    }

    # 6. Export via forge
    if export:
        from pixel_art.forge_simple import forge
        forge_result = forge(
            name,
            frames=frames,
            fps=6,
            scale_gif=4,
            verbose=verbose,
        )
        result['files'] = forge_result

    return result


def ingest_direct(
    image_path: str,
    name: str = None,
    anatomy: str = 'creature',
    animation: str = 'idle',
    frame_count: int = 12,
    target_size: int = 128,
    verbose: bool = True,
    export: bool = True,
) -> dict:
    """Direct ingestion: cut source image into layers and animate.

    RECOMMENDED for ChatGPT/AI-generated images — preserves exact quality.
    No polygon extraction, no color quantization.

    Args:
        image_path: Path to PNG with transparent background.
        name: Output name (default: filename without extension).
        anatomy: Creature type ('humanoid', 'quadruped', 'creature', 'bird', 'object').
        animation: 'idle', 'walk', 'blink', 'sleep', 'alert', 'happy',
                   'curious', 'sad', 'excited', or 'scared'.
        frame_count: Number of animation frames.
        target_size: Output sprite size.
        verbose: Print progress info.
        export: If True, export via forge.

    Returns:
        Dict with keys: name, frames, and optionally files.
    """
    if name is None:
        name = os.path.splitext(os.path.basename(image_path))[0]
        # Clean filename for forge
        name = name.replace(' ', '_').replace(',', '').replace('.', '_')

    frames = direct_animate(
        image_path,
        anatomy=anatomy,
        animation=animation,
        frame_count=frame_count,
        target_size=target_size,
        verbose=verbose,
    )

    result = {
        'name': name,
        'frames': frames,
    }

    if export:
        from pixel_art.forge_simple import forge
        forge_result = forge(
            name,
            frames=frames,
            fps=6,
            scale_gif=4,
            verbose=verbose,
        )
        result['files'] = forge_result

    return result
