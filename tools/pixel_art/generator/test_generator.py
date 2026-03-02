"""Integration test — generate 3 characters via the generator pipeline."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pixel_art.generator import generate_character, animate_character, export_character
from pixel_art.generator.character_spec import (
    CharacterSpec, spec_from_json, AccentColor, ProportionSpec,
    FaceSpec, EyeSpec, EyeStyle, AnimationSpec,
    AccessorySpec, AccessorySlot, AccessorySide,
    SilhouetteShape, TemplateType,
)
from pixel_art.generator.templates import get_template, apply_overrides
from pixel_art.generator.validator import validate_spec


def test_merlin_spec():
    """Test 1: Generate M.E.R.L.I.N. via generator (regression test)."""
    print("\n=== TEST 1: M.E.R.L.I.N. via generator ===")

    spec = CharacterSpec(
        name="merlin_gen",
        template=TemplateType.HOODED_FIGURE,
        silhouette=SilhouetteShape.BELL,
        proportions=ProportionSpec(
            head_ratio=0.57,
            shoulder_width=0.92,
            body_width=0.65,
        ),
        detail_level=4,
        accent=AccentColor(bright="#FFFC68", dim="#BBA830", halo="#FFFC6838"),
        face=FaceSpec(
            width_top=0.14,
            width_bottom=0.22,
            height=0.23,
            vertical_position=0.34,
        ),
        eyes=EyeSpec(style=EyeStyle.SLIT, count=2, glow_radius=4.0, halo_radius=22.0,
                     vertical_position=0.40, spacing=0.55),
        accessories=(
            AccessorySpec(name="cable", slot=AccessorySlot.TECH_CABLE, side=AccessorySide.BOTH),
            AccessorySpec(name="glyph", slot=AccessorySlot.GLYPH, side=AccessorySide.BOTH, glow=True),
        ),
        animation=AnimationSpec(frame_count=12, fps=6),
    )

    result = validate_spec(spec)
    print(f"  Validation: valid={result.valid}, errors={result.errors}, warnings={result.warnings}")

    mesh = generate_character(spec)
    print(f"  Mesh: {len(mesh.facets)} facets, {len(mesh.glows)} glows")

    frames = animate_character(mesh, spec)
    print(f"  Animation: {len(frames)} frames, size={frames[0].size}")

    out = export_character("merlin_gen", frames, fps=6, scale_gif=4)
    print(f"  Export: {out}")


def test_bestiole_purple_fox():
    """Test 2: Generate Bestiole — a purple fox companion creature."""
    print("\n=== TEST 2: Bestiole (Purple Fox) ===")

    from pixel_art.generator.color_engine import generate_colored_ramp

    # Purple ramp for fox body — violet hue, moderate saturation
    purple_ramp = generate_colored_ramp(hue=275, saturation=0.35)

    json_spec = {
        "name": "bestiole",
        "template": "creature",
        "description": "Bestiole — purple fox companion with glowing cyan eyes",
        "silhouette": "horned",  # horned = fox ears (two peaks)
        "proportions": {
            "head_ratio": 0.52,
            "shoulder_width": 0.68,
            "body_width": 0.60,
        },
        "detail_level": 4,
        "accent": {"bright": "#1DFDFF"},  # cyan glow for eyes
        "face": {
            "width_top": 0.12,
            "width_bottom": 0.16,
            "height": 0.18,
            "vertical_position": 0.36,
            "has_chin_band": False,
        },
        "eyes": {
            "style": "round",
            "count": 2,
            "glow_radius": 5.0,
            "halo_radius": 18.0,
            "vertical_position": 0.42,
            "spacing": 0.50,
        },
        "animation": {
            "breathing_amplitude": 3.0,
            "sway_amplitude": 0.5,
        },
        "color_overrides": purple_ramp,
    }

    spec = spec_from_json(json_spec)
    result = validate_spec(spec)
    print(f"  Validation: valid={result.valid}, errors={result.errors}, warnings={result.warnings}")

    mesh = generate_character(spec)
    print(f"  Mesh: {len(mesh.facets)} facets, {len(mesh.glows)} glows")

    frames = animate_character(mesh, spec)
    print(f"  Animation: {len(frames)} frames, size={frames[0].size}")

    out = export_character("bestiole_gen", frames, fps=6, scale_gif=4)
    print(f"  Export: {out}")


def test_shadow_knight():
    """Test 3: Generate Shadow Knight — cold steel armor with red visor."""
    print("\n=== TEST 3: Shadow Knight (Cold Steel) ===")

    from pixel_art.generator.color_engine import generate_colored_ramp

    # Cold steel blue ramp — subtle blue tint on dark armor
    steel_ramp = generate_colored_ramp(hue=215, saturation=0.18)

    template = get_template(TemplateType.HOODED_FIGURE)
    spec = apply_overrides(template, {
        "name": "shadow_knight",
        "description": "Shadow Knight — cold steel armor with blood-red visor",
        "silhouette": "flat_top",  # helmet shape
        "proportions": {
            "head_ratio": 0.50,
            "shoulder_width": 0.95,
            "body_width": 0.70,
        },
        "accent": {"bright": "#FF3344"},  # blood red visor
        "eyes": {
            "style": "visor",
            "glow_radius": 4.0,
            "halo_radius": 16.0,
        },
        "face": {
            "width_top": 0.16,
            "width_bottom": 0.20,
            "height": 0.18,
            "vertical_position": 0.36,
            "has_chin_band": True,
        },
        "color_overrides": steel_ramp,
    })

    result = validate_spec(spec)
    print(f"  Validation: valid={result.valid}, errors={result.errors}, warnings={result.warnings}")

    mesh = generate_character(spec)
    print(f"  Mesh: {len(mesh.facets)} facets, {len(mesh.glows)} glows")

    frames = animate_character(mesh, spec)
    print(f"  Animation: {len(frames)} frames, size={frames[0].size}")

    out = export_character("shadow_knight_gen", frames, fps=6, scale_gif=4)
    print(f"  Export: {out}")


if __name__ == '__main__':
    test_merlin_spec()
    test_bestiole_purple_fox()
    test_shadow_knight()
    print("\n=== ALL TESTS PASSED ===")
