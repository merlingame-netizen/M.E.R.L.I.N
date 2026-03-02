"""CharacterSpec — The constraint schema that Claude fills out to describe a character.

Claude generates a JSON object matching this schema. The system translates it
into LowPolyMesh facets, colors, and animations.

All dataclasses are frozen (immutable) per project coding style.
All numeric proportions are ratios (0.0-1.0), not pixel values.
"""

from dataclasses import dataclass, field
from typing import List, Tuple, Optional, Dict
from enum import Enum
import json


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class TemplateType(str, Enum):
    HOODED_FIGURE = "hooded_figure"
    CREATURE = "creature"
    OBJECT = "object"


class SilhouetteShape(str, Enum):
    BELL = "bell"
    ANGULAR = "angular"
    ROUNDED = "rounded"
    HORNED = "horned"
    SPIKY = "spiky"
    FLAT_TOP = "flat_top"
    TAPERED = "tapered"


class EyeStyle(str, Enum):
    SLIT = "slit"
    ROUND = "round"
    SINGLE = "single"
    MULTI = "multi"
    NONE = "none"
    VISOR = "visor"


class AccessorySlot(str, Enum):
    TECH_CABLE = "tech_cable"
    GLYPH = "glyph"
    HORN = "horn"
    SHOULDER_PAD = "shoulder_pad"
    CROWN = "crown"
    WEAPON = "weapon"
    WING = "wing"
    TAIL = "tail"


class AccessorySide(str, Enum):
    LEFT = "left"
    RIGHT = "right"
    BOTH = "both"
    CENTER = "center"


# ---------------------------------------------------------------------------
# Sub-specs (frozen dataclasses)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class AccentColor:
    """Accent color specification. Claude provides the bright color;
    dim and halo are auto-derived if not specified."""
    bright: str
    dim: Optional[str] = None
    halo: Optional[str] = None


@dataclass(frozen=True)
class ProportionSpec:
    """Body proportions as ratios of total canvas dimensions.

    Defaults calibrated from gold standard merlin_lowpoly.py v15:
      head_ratio=0.57  → hood spans 146px on 256 canvas (y=44→190)
      shoulder_width=0.92 → shoulders at x=10/246 (118px from center)
    """
    head_ratio: float = 0.57
    shoulder_width: float = 0.92
    body_width: float = 0.65
    waist_taper: float = 0.80
    peak_offset_x: float = 0.0


@dataclass(frozen=True)
class FaceSpec:
    """Face opening configuration (trapezoid).

    Defaults calibrated from gold standard:
      Face void: (110,88)→(146,88) top, (100,148)→(156,148) bottom
      width_top=0.14, width_bottom=0.22, height=0.23, vertical_position=0.34
    """
    width_top: float = 0.14
    width_bottom: float = 0.22
    height: float = 0.23
    vertical_position: float = 0.34
    has_chin_band: bool = True
    has_depth_shadows: bool = True


@dataclass(frozen=True)
class EyeSpec:
    """Eye configuration.

    Defaults calibrated from gold standard:
      Eyes at y=112, x=118/138 (±10px from center within 36px face)
    """
    style: EyeStyle = EyeStyle.SLIT
    count: int = 2
    glow_radius: float = 4.0
    halo_radius: float = 22.0
    vertical_position: float = 0.40
    spacing: float = 0.55


@dataclass(frozen=True)
class AccessorySpec:
    """Optional accessories (cables, glyphs, horns, etc.)."""
    name: str
    slot: AccessorySlot = AccessorySlot.GLYPH
    side: AccessorySide = AccessorySide.BOTH
    size: float = 1.0
    glow: bool = False


@dataclass(frozen=True)
class AnimationSpec:
    """Animation parameters."""
    breathing_amplitude: float = 2.0
    sway_amplitude: float = 1.0
    frame_count: int = 12
    fps: int = 6


# ---------------------------------------------------------------------------
# Main spec
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class CharacterSpec:
    """Complete character specification. This is what Claude fills out."""
    name: str
    template: TemplateType = TemplateType.HOODED_FIGURE
    description: str = ""

    silhouette: SilhouetteShape = SilhouetteShape.BELL
    proportions: ProportionSpec = ProportionSpec()
    detail_level: int = 4

    grayscale_shades: int = 10
    grayscale_warmth: float = 0.0
    accent: AccentColor = AccentColor(bright="#FFFC68")

    face: FaceSpec = FaceSpec()
    eyes: EyeSpec = EyeSpec()

    accessories: Tuple[AccessorySpec, ...] = ()

    animation: AnimationSpec = AnimationSpec()

    color_overrides: Tuple[Tuple[str, str], ...] = ()


# ---------------------------------------------------------------------------
# JSON serialization
# ---------------------------------------------------------------------------

def _enum_val(v):
    """Extract .value from enums, pass through others."""
    return v.value if isinstance(v, Enum) else v


def spec_to_json(spec: CharacterSpec) -> dict:
    """Serialize a CharacterSpec to a JSON-safe dict."""
    return {
        "name": spec.name,
        "template": _enum_val(spec.template),
        "description": spec.description,
        "silhouette": _enum_val(spec.silhouette),
        "proportions": {
            "head_ratio": spec.proportions.head_ratio,
            "shoulder_width": spec.proportions.shoulder_width,
            "body_width": spec.proportions.body_width,
            "waist_taper": spec.proportions.waist_taper,
            "peak_offset_x": spec.proportions.peak_offset_x,
        },
        "detail_level": spec.detail_level,
        "grayscale_shades": spec.grayscale_shades,
        "grayscale_warmth": spec.grayscale_warmth,
        "accent": {
            "bright": spec.accent.bright,
            "dim": spec.accent.dim,
            "halo": spec.accent.halo,
        },
        "face": {
            "width_top": spec.face.width_top,
            "width_bottom": spec.face.width_bottom,
            "height": spec.face.height,
            "vertical_position": spec.face.vertical_position,
            "has_chin_band": spec.face.has_chin_band,
            "has_depth_shadows": spec.face.has_depth_shadows,
        },
        "eyes": {
            "style": _enum_val(spec.eyes.style),
            "count": spec.eyes.count,
            "glow_radius": spec.eyes.glow_radius,
            "halo_radius": spec.eyes.halo_radius,
            "vertical_position": spec.eyes.vertical_position,
            "spacing": spec.eyes.spacing,
        },
        "accessories": [
            {
                "name": a.name,
                "slot": _enum_val(a.slot),
                "side": _enum_val(a.side),
                "size": a.size,
                "glow": a.glow,
            }
            for a in spec.accessories
        ],
        "animation": {
            "breathing_amplitude": spec.animation.breathing_amplitude,
            "sway_amplitude": spec.animation.sway_amplitude,
            "frame_count": spec.animation.frame_count,
            "fps": spec.animation.fps,
        },
        "color_overrides": dict(spec.color_overrides),
    }


def _parse_enum(enum_cls, value, default):
    """Safely parse a string into an enum, returning default on failure."""
    if value is None:
        return default
    if isinstance(value, enum_cls):
        return value
    try:
        return enum_cls(value)
    except (ValueError, KeyError):
        return default


def spec_from_json(data: dict) -> CharacterSpec:
    """Parse a JSON dict (from Claude) into a CharacterSpec.

    Tolerant to missing fields — uses template defaults for anything absent.
    """
    if not isinstance(data, dict):
        raise TypeError(f"Expected dict, got {type(data).__name__}")

    name = data.get("name", "unnamed")

    template = _parse_enum(TemplateType, data.get("template"), TemplateType.HOODED_FIGURE)
    silhouette = _parse_enum(SilhouetteShape, data.get("silhouette"), SilhouetteShape.BELL)

    # Proportions
    p = data.get("proportions", {})
    if not isinstance(p, dict):
        p = {}
    proportions = ProportionSpec(
        head_ratio=float(p.get("head_ratio", 0.57)),
        shoulder_width=float(p.get("shoulder_width", 0.92)),
        body_width=float(p.get("body_width", 0.65)),
        waist_taper=float(p.get("waist_taper", 0.80)),
        peak_offset_x=float(p.get("peak_offset_x", 0.0)),
    )

    # Accent
    a = data.get("accent", {})
    if isinstance(a, str):
        a = {"bright": a}
    elif not isinstance(a, dict):
        a = {}
    accent = AccentColor(
        bright=a.get("bright", "#FFFC68"),
        dim=a.get("dim"),
        halo=a.get("halo"),
    )

    # Face
    f = data.get("face", {})
    if not isinstance(f, dict):
        f = {}
    face = FaceSpec(
        width_top=float(f.get("width_top", 0.14)),
        width_bottom=float(f.get("width_bottom", 0.22)),
        height=float(f.get("height", 0.23)),
        vertical_position=float(f.get("vertical_position", 0.34)),
        has_chin_band=bool(f.get("has_chin_band", True)),
        has_depth_shadows=bool(f.get("has_depth_shadows", True)),
    )

    # Eyes
    e = data.get("eyes", {})
    if not isinstance(e, dict):
        e = {}
    eyes = EyeSpec(
        style=_parse_enum(EyeStyle, e.get("style"), EyeStyle.SLIT),
        count=int(e.get("count", 2)),
        glow_radius=float(e.get("glow_radius", 4.0)),
        halo_radius=float(e.get("halo_radius", 22.0)),
        vertical_position=float(e.get("vertical_position", 0.40)),
        spacing=float(e.get("spacing", 0.55)),
    )

    # Accessories
    raw_acc = data.get("accessories", [])
    if not isinstance(raw_acc, list):
        raw_acc = []
    accessories = []
    for item in raw_acc:
        if not isinstance(item, dict):
            continue
        accessories.append(AccessorySpec(
            name=item.get("name", "accessory"),
            slot=_parse_enum(AccessorySlot, item.get("slot"), AccessorySlot.GLYPH),
            side=_parse_enum(AccessorySide, item.get("side"), AccessorySide.BOTH),
            size=float(item.get("size", 1.0)),
            glow=bool(item.get("glow", False)),
        ))

    # Animation
    an = data.get("animation", {})
    if not isinstance(an, dict):
        an = {}
    animation = AnimationSpec(
        breathing_amplitude=float(an.get("breathing_amplitude", 2.0)),
        sway_amplitude=float(an.get("sway_amplitude", 1.0)),
        frame_count=int(an.get("frame_count", 12)),
        fps=int(an.get("fps", 6)),
    )

    # Color overrides
    co = data.get("color_overrides", {})
    if not isinstance(co, dict):
        co = {}
    color_overrides = tuple((k, v) for k, v in co.items() if isinstance(k, str) and isinstance(v, str))

    return CharacterSpec(
        name=name,
        template=template,
        description=str(data.get("description", "")),
        silhouette=silhouette,
        proportions=proportions,
        detail_level=int(data.get("detail_level", 4)),
        grayscale_shades=int(data.get("grayscale_shades", 10)),
        grayscale_warmth=float(data.get("grayscale_warmth", 0.0)),
        accent=accent,
        face=face,
        eyes=eyes,
        accessories=tuple(accessories),
        animation=animation,
        color_overrides=color_overrides,
    )
