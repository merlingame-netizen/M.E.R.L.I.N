"""Template definitions — pre-configured CharacterSpec partials for common archetypes.

Each template defines the default shape, proportions, face, eyes, and animation
for a character type. Claude can reference a template and override specific fields.

Templates:
  hooded_figure — M.E.R.L.I.N.-like hooded character
  creature — quadruped/flying/blob creature
  object — item/artifact/weapon
"""

from dataclasses import replace
from typing import Dict

from .character_spec import (
    CharacterSpec, TemplateType, SilhouetteShape, ProportionSpec,
    FaceSpec, EyeSpec, EyeStyle, AnimationSpec, AccentColor,
    AccessorySpec, AccessorySlot, AccessorySide,
)


# ---------------------------------------------------------------------------
# Template definitions
# ---------------------------------------------------------------------------

HOODED_FIGURE = CharacterSpec(
    name="_template_hooded_figure",
    template=TemplateType.HOODED_FIGURE,
    description="Dark hooded figure — the M.E.R.L.I.N. archetype",
    silhouette=SilhouetteShape.BELL,
    proportions=ProportionSpec(
        head_ratio=0.57,
        shoulder_width=0.92,
        body_width=0.65,
        waist_taper=0.80,
    ),
    detail_level=4,
    grayscale_shades=10,
    grayscale_warmth=0.0,
    accent=AccentColor(bright="#FFFC68"),
    face=FaceSpec(
        width_top=0.14,
        width_bottom=0.22,
        height=0.23,
        vertical_position=0.34,
        has_chin_band=True,
        has_depth_shadows=True,
    ),
    eyes=EyeSpec(
        style=EyeStyle.SLIT,
        count=2,
        glow_radius=4.0,
        halo_radius=22.0,
        vertical_position=0.40,
        spacing=0.55,
    ),
    accessories=(
        AccessorySpec(name="cable", slot=AccessorySlot.TECH_CABLE, side=AccessorySide.BOTH),
        AccessorySpec(name="glyph", slot=AccessorySlot.GLYPH, side=AccessorySide.BOTH, glow=True),
    ),
    animation=AnimationSpec(
        breathing_amplitude=2.0,
        sway_amplitude=1.0,
        frame_count=12,
        fps=6,
    ),
)


CREATURE = CharacterSpec(
    name="_template_creature",
    template=TemplateType.CREATURE,
    description="Creature — head-dominant, rounded shape",
    silhouette=SilhouetteShape.ROUNDED,
    proportions=ProportionSpec(
        head_ratio=0.55,
        shoulder_width=0.70,
        body_width=0.80,
        waist_taper=0.60,
    ),
    detail_level=4,
    grayscale_shades=10,
    grayscale_warmth=0.0,
    accent=AccentColor(bright="#1DFDFF"),
    face=FaceSpec(
        width_top=0.16,
        width_bottom=0.16,
        height=0.18,
        vertical_position=0.34,
        has_chin_band=False,
        has_depth_shadows=True,
    ),
    eyes=EyeSpec(
        style=EyeStyle.ROUND,
        count=2,
        glow_radius=5.0,
        halo_radius=18.0,
        vertical_position=0.40,
        spacing=0.50,
    ),
    accessories=(),
    animation=AnimationSpec(
        breathing_amplitude=3.0,
        sway_amplitude=0.5,
        frame_count=12,
        fps=6,
    ),
)


OBJECT = CharacterSpec(
    name="_template_object",
    template=TemplateType.OBJECT,
    description="Object — no face, minimal animation",
    silhouette=SilhouetteShape.ANGULAR,
    proportions=ProportionSpec(
        head_ratio=0.60,
        shoulder_width=0.50,
        body_width=0.40,
        waist_taper=1.0,
    ),
    detail_level=4,
    grayscale_shades=8,
    grayscale_warmth=0.0,
    accent=AccentColor(bright="#FFFC68"),
    face=FaceSpec(
        width_top=0.0,
        width_bottom=0.0,
        height=0.0,
        vertical_position=0.35,
        has_chin_band=False,
        has_depth_shadows=False,
    ),
    eyes=EyeSpec(style=EyeStyle.NONE, count=0),
    accessories=(),
    animation=AnimationSpec(
        breathing_amplitude=1.0,
        sway_amplitude=0.3,
        frame_count=12,
        fps=6,
    ),
)


TEMPLATES: Dict[TemplateType, CharacterSpec] = {
    TemplateType.HOODED_FIGURE: HOODED_FIGURE,
    TemplateType.CREATURE: CREATURE,
    TemplateType.OBJECT: OBJECT,
}


# ---------------------------------------------------------------------------
# Template operations
# ---------------------------------------------------------------------------

def get_template(template_type: TemplateType) -> CharacterSpec:
    """Return the base template for a given type."""
    return TEMPLATES[template_type]


def apply_overrides(template: CharacterSpec, overrides: dict) -> CharacterSpec:
    """Create a new CharacterSpec by merging template defaults with overrides.

    Uses dataclasses.replace() for top-level fields. For nested frozen
    dataclasses (proportions, face, eyes, accent, animation), merges
    the override dict into the template's nested values.
    """
    from .character_spec import (
        spec_from_json, spec_to_json
    )

    # Serialize template to dict, overlay overrides, re-parse
    base = spec_to_json(template)

    for key, value in overrides.items():
        if isinstance(value, dict) and key in base and isinstance(base[key], dict):
            # Merge nested dicts
            base[key].update(value)
        else:
            base[key] = value

    return spec_from_json(base)
