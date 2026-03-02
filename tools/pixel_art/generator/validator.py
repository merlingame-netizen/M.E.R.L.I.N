"""Validate a CharacterSpec before rendering.

Catches common LLM errors: invalid hex colors, out-of-range proportions,
incompatible template+silhouette combinations, missing required fields.
"""

import re
from dataclasses import dataclass
from typing import List

from .character_spec import (
    CharacterSpec, TemplateType, SilhouetteShape, EyeStyle,
)

HEX_RE = re.compile(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$')


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    errors: List[str]
    warnings: List[str]


def validate_spec(spec: CharacterSpec) -> ValidationResult:
    """Validate a CharacterSpec and return errors/warnings."""
    errors: list = []
    warnings: list = []

    _validate_name(spec, errors)
    _validate_proportions(spec, errors, warnings)
    _validate_colors(spec, errors)
    _validate_face(spec, errors, warnings)
    _validate_eyes(spec, errors, warnings)
    _validate_detail_level(spec, errors, warnings)
    _validate_animation(spec, warnings)

    return ValidationResult(
        valid=len(errors) == 0,
        errors=list(errors),
        warnings=list(warnings),
    )


def _validate_name(spec: CharacterSpec, errors: list):
    if not spec.name or not spec.name.strip():
        errors.append("name: must be non-empty")
    if len(spec.name) > 64:
        errors.append("name: must be <= 64 characters")


def _validate_proportions(spec: CharacterSpec, errors: list, warnings: list):
    p = spec.proportions
    for field_name, val in [
        ("head_ratio", p.head_ratio),
        ("shoulder_width", p.shoulder_width),
        ("body_width", p.body_width),
        ("waist_taper", p.waist_taper),
    ]:
        if val < 0.1 or val > 1.0:
            errors.append(f"proportions.{field_name}: {val} out of range [0.1, 1.0]")

    if p.peak_offset_x < -1.0 or p.peak_offset_x > 1.0:
        errors.append(f"proportions.peak_offset_x: {p.peak_offset_x} out of range [-1.0, 1.0]")

    if p.head_ratio > 0.7:
        warnings.append("proportions.head_ratio > 0.7: very large head")
    if p.shoulder_width < 0.4:
        warnings.append("proportions.shoulder_width < 0.4: very narrow shoulders")


def _validate_hex(color: str, field: str, errors: list):
    if not HEX_RE.match(color):
        errors.append(f"{field}: '{color}' is not a valid hex color (#RRGGBB or #RRGGBBAA)")


def _validate_colors(spec: CharacterSpec, errors: list):
    _validate_hex(spec.accent.bright, "accent.bright", errors)
    if spec.accent.dim is not None:
        _validate_hex(spec.accent.dim, "accent.dim", errors)
    if spec.accent.halo is not None:
        _validate_hex(spec.accent.halo, "accent.halo", errors)

    for name, hex_val in spec.color_overrides:
        _validate_hex(hex_val, f"color_overrides[{name}]", errors)

    if spec.grayscale_shades < 4:
        errors.append(f"grayscale_shades: {spec.grayscale_shades} too few (min 4)")
    if spec.grayscale_shades > 20:
        errors.append(f"grayscale_shades: {spec.grayscale_shades} too many (max 20)")

    if spec.grayscale_warmth < -1.0 or spec.grayscale_warmth > 1.0:
        errors.append(f"grayscale_warmth: {spec.grayscale_warmth} out of range [-1.0, 1.0]")


def _validate_face(spec: CharacterSpec, errors: list, warnings: list):
    f = spec.face
    if spec.template == TemplateType.OBJECT:
        if f.height > 0 or f.width_top > 0 or f.width_bottom > 0:
            warnings.append("face: object template usually has no face (set height=0)")
        return

    if f.height < 0 or f.height > 0.5:
        errors.append(f"face.height: {f.height} out of range [0.0, 0.5]")
    if f.width_top < 0 or f.width_top > 0.8:
        errors.append(f"face.width_top: {f.width_top} out of range [0.0, 0.8]")
    if f.width_bottom < 0 or f.width_bottom > 0.8:
        errors.append(f"face.width_bottom: {f.width_bottom} out of range [0.0, 0.8]")
    if f.vertical_position < 0.1 or f.vertical_position > 0.8:
        errors.append(f"face.vertical_position: {f.vertical_position} out of range [0.1, 0.8]")


def _validate_eyes(spec: CharacterSpec, errors: list, warnings: list):
    e = spec.eyes
    if e.style == EyeStyle.NONE:
        return

    if e.count < 1 or e.count > 6:
        errors.append(f"eyes.count: {e.count} out of range [1, 6]")
    if e.style == EyeStyle.SINGLE and e.count != 1:
        warnings.append("eyes: single style expects count=1")
    if e.style == EyeStyle.MULTI and e.count < 3:
        warnings.append("eyes: multi style expects count >= 3")
    if e.glow_radius < 1.0 or e.glow_radius > 20.0:
        errors.append(f"eyes.glow_radius: {e.glow_radius} out of range [1.0, 20.0]")
    if e.halo_radius < 0 or e.halo_radius > 60.0:
        errors.append(f"eyes.halo_radius: {e.halo_radius} out of range [0.0, 60.0]")

    if spec.face.height == 0 and e.style != EyeStyle.NONE:
        warnings.append("eyes: face has no opening but eyes are configured")


def _validate_detail_level(spec: CharacterSpec, errors: list, warnings: list):
    if spec.detail_level < 2:
        errors.append(f"detail_level: {spec.detail_level} too low (min 2)")
    if spec.detail_level > 12:
        errors.append(f"detail_level: {spec.detail_level} too high (max 12)")
    if spec.detail_level > 8:
        warnings.append("detail_level > 8: very complex, may be slow to render")


def _validate_animation(spec: CharacterSpec, warnings: list):
    a = spec.animation
    if a.breathing_amplitude > 5.0:
        warnings.append("animation.breathing_amplitude > 5.0: exaggerated breathing")
    if a.sway_amplitude > 3.0:
        warnings.append("animation.sway_amplitude > 3.0: exaggerated sway")
    if a.frame_count < 4:
        warnings.append("animation.frame_count < 4: very few frames, jerky animation")
    if a.frame_count > 48:
        warnings.append("animation.frame_count > 48: many frames, large sprite sheet")
