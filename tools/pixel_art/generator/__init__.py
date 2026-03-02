"""Low-Poly Isometric Character Generator.

Usage:
    from pixel_art.generator import generate_character, animate_character, export_character
    from pixel_art.generator.character_spec import CharacterSpec, spec_from_json

    # From JSON (Claude-generated spec):
    spec = spec_from_json({
        "name": "forest_guardian",
        "template": "hooded_figure",
        "silhouette": "horned",
        "accent": {"bright": "#22FF88"},
    })
    mesh = generate_character(spec)
    frames = animate_character(mesh, spec)
    result = export_character("forest_guardian", frames)

    # From template with overrides:
    from pixel_art.generator.templates import get_template, apply_overrides
    from pixel_art.generator.character_spec import TemplateType

    template = get_template(TemplateType.CREATURE)
    spec = apply_overrides(template, {"name": "bestiole", "accent": {"bright": "#FF8844"}})
    mesh = generate_character(spec)
    frames = animate_character(mesh, spec)
    export_character("bestiole", frames)
"""

import math
import os
import sys

# Ensure parent packages are importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.low_poly_mesh import LowPolyMesh

from .character_spec import CharacterSpec, spec_from_json, spec_to_json
from .validator import validate_spec, ValidationResult
from .geometry import generate_mesh
from .color_engine import generate_color_map, ColorMap
from .templates import get_template, apply_overrides, TEMPLATES


def generate_character(spec: CharacterSpec) -> LowPolyMesh:
    """Validate spec and generate a LowPolyMesh.

    Raises ValueError if spec validation fails.
    """
    result = validate_spec(spec)
    if not result.valid:
        raise ValueError(f"Invalid CharacterSpec: {'; '.join(result.errors)}")
    if result.warnings:
        for w in result.warnings:
            print(f"  [warn] {w}")
    return generate_mesh(spec)


def animate_character(mesh: LowPolyMesh, spec: CharacterSpec) -> list:
    """Generate animation frames from mesh + spec animation params.

    Returns list of PIL.Image (128x128 RGBA).
    """
    anim = spec.animation
    frames = []

    for i in range(anim.frame_count):
        t = i / anim.frame_count
        angle = t * 2 * math.pi

        breath_dy = math.sin(angle) * anim.breathing_amplitude
        sway_dx = math.cos(angle) * anim.sway_amplitude

        displacements = {
            'hood':       (sway_dx,       breath_dy * 0.5),
            'face':       (sway_dx * 0.8, breath_dy * 0.6),
            'eyes':       (sway_dx * 0.8, breath_dy * 0.6),
            'shoulder_l': (-0.3,          breath_dy * 0.3),
            'shoulder_r': (0.3,           breath_dy * 0.3),
            'body':       (0,             breath_dy * 0.2),
            'accent':     (0,             breath_dy * 0.3),
        }

        frames.append(mesh.render_scaled(128, displacements))

    return frames


def export_character(name: str, frames: list, fps: int = 6, scale_gif: int = 4) -> dict:
    """Export character via forge_simple.forge().

    Returns dict with file paths: {name, ase, png, gif, sheet}.
    """
    from pixel_art.forge_simple import forge
    return forge(name=name, frames=frames, fps=fps, scale_gif=scale_gif)
