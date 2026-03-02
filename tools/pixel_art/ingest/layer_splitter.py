"""Layer splitter — decompose character image into anatomical groups.

Takes extracted facets and assigns them to anatomical groups (head, body,
limbs, tail, etc.) based on spatial position relative to the character's
bounding box.

Two modes:
  1. AUTO: Heuristic spatial assignment (head = top, body = center, etc.)
  2. MANUAL: User provides a group map (facet_name -> group)

The groups are used by the anatomy animator to apply different motion
to different body parts (head bobs differently than tail, etc.).
"""

from dataclasses import dataclass
from typing import List, Dict, Tuple, Optional
from enum import Enum

from .polygon_extractor import ExtractedFacet


class AnatomyType(str, Enum):
    """Supported creature anatomies."""
    HUMANOID = "humanoid"
    QUADRUPED = "quadruped"
    CREATURE = "creature"       # generic blob/creature
    BIRD = "bird"
    OBJECT = "object"           # no anatomy, single group


@dataclass(frozen=True)
class AnatomyZone:
    """A named zone of the character's bounding box."""
    name: str
    y_min: float    # ratio 0.0 (top) to 1.0 (bottom)
    y_max: float
    x_min: float    # ratio 0.0 (left) to 1.0 (right)
    x_max: float


# ---------------------------------------------------------------------------
# Anatomy zone definitions
# ---------------------------------------------------------------------------

ANATOMY_ZONES: Dict[AnatomyType, List[AnatomyZone]] = {
    AnatomyType.HUMANOID: [
        AnatomyZone('head',       0.00, 0.25, 0.20, 0.80),
        AnatomyZone('torso',      0.25, 0.55, 0.15, 0.85),
        AnatomyZone('arm_left',   0.25, 0.60, 0.00, 0.25),
        AnatomyZone('arm_right',  0.25, 0.60, 0.75, 1.00),
        AnatomyZone('legs',       0.55, 1.00, 0.15, 0.85),
    ],
    AnatomyType.QUADRUPED: [
        AnatomyZone('head',         0.00, 0.35, 0.00, 0.50),
        AnatomyZone('ears',         0.00, 0.20, 0.00, 0.60),
        AnatomyZone('body',         0.20, 0.70, 0.15, 0.85),
        AnatomyZone('front_legs',   0.55, 1.00, 0.10, 0.50),
        AnatomyZone('back_legs',    0.55, 1.00, 0.50, 0.90),
        AnatomyZone('tail',         0.15, 0.65, 0.65, 1.00),
    ],
    AnatomyType.CREATURE: [
        AnatomyZone('head',         0.00, 0.40, 0.15, 0.85),
        AnatomyZone('body',         0.30, 0.80, 0.10, 0.90),
        AnatomyZone('appendages',   0.60, 1.00, 0.00, 1.00),
    ],
    AnatomyType.BIRD: [
        AnatomyZone('head',         0.00, 0.30, 0.30, 0.70),
        AnatomyZone('body',         0.25, 0.65, 0.20, 0.80),
        AnatomyZone('wing_left',    0.15, 0.55, 0.00, 0.30),
        AnatomyZone('wing_right',   0.15, 0.55, 0.70, 1.00),
        AnatomyZone('tail',         0.50, 0.80, 0.30, 0.70),
        AnatomyZone('legs',         0.65, 1.00, 0.30, 0.70),
    ],
    AnatomyType.OBJECT: [
        AnatomyZone('body',         0.00, 1.00, 0.00, 1.00),
    ],
}


# ---------------------------------------------------------------------------
# Auto-assignment
# ---------------------------------------------------------------------------

def _point_in_zone(
    cx: float, cy: float,
    zone: AnatomyZone,
    bbox: Tuple[int, int, int, int],
) -> bool:
    """Check if a centroid falls within an anatomy zone.

    Coordinates are normalized to [0,1] within the bounding box.
    """
    left, top, right, bottom = bbox
    bw = right - left
    bh = bottom - top
    if bw <= 0 or bh <= 0:
        return False

    nx = (cx - left) / bw
    ny = (cy - top) / bh

    return (zone.x_min <= nx <= zone.x_max and
            zone.y_min <= ny <= zone.y_max)


def _assign_best_zone(
    cx: float, cy: float,
    zones: List[AnatomyZone],
    bbox: Tuple[int, int, int, int],
) -> str:
    """Find the best matching zone for a centroid.

    If the point falls in multiple overlapping zones, pick the
    one whose center is closest. Falls back to 'body' if no match.
    """
    left, top, right, bottom = bbox
    bw = right - left
    bh = bottom - top
    if bw <= 0 or bh <= 0:
        return 'body'

    nx = (cx - left) / bw
    ny = (cy - top) / bh

    best_zone = 'body'
    best_dist = float('inf')

    for zone in zones:
        if _point_in_zone(cx, cy, zone, bbox):
            # Distance to zone center
            zcx = (zone.x_min + zone.x_max) / 2
            zcy = (zone.y_min + zone.y_max) / 2
            dist = (nx - zcx) ** 2 + (ny - zcy) ** 2
            if dist < best_dist:
                best_dist = dist
                best_zone = zone.name

    return best_zone


def split_into_groups(
    facets: List[ExtractedFacet],
    anatomy: AnatomyType,
    bbox: Tuple[int, int, int, int],
    manual_overrides: Optional[Dict[str, str]] = None,
) -> Dict[str, List[ExtractedFacet]]:
    """Assign facets to anatomical groups.

    Args:
        facets: Extracted facets from polygon_extractor.
        anatomy: Creature type for zone definitions.
        bbox: Character bounding box (left, top, right, bottom).
        manual_overrides: Optional dict facet_name -> group_name.

    Returns:
        Dict mapping group name to list of facets in that group.
    """
    zones = ANATOMY_ZONES.get(anatomy, ANATOMY_ZONES[AnatomyType.OBJECT])
    overrides = manual_overrides or {}

    groups: Dict[str, List[ExtractedFacet]] = {}

    for facet in facets:
        # Manual override takes priority
        if facet.name in overrides:
            group = overrides[facet.name]
        else:
            group = _assign_best_zone(
                facet.centroid[0], facet.centroid[1],
                zones, bbox,
            )

        # Create new facet with updated group
        updated = ExtractedFacet(
            name=facet.name,
            points=facet.points,
            color=facet.color,
            area=facet.area,
            centroid=facet.centroid,
            group=group,
            z_order=facet.z_order,
        )

        if group not in groups:
            groups[group] = []
        groups[group].append(updated)

    return groups


def flatten_groups(
    groups: Dict[str, List[ExtractedFacet]],
) -> List[ExtractedFacet]:
    """Flatten grouped facets back to a single list (with group names set)."""
    result = []
    for facets in groups.values():
        result.extend(facets)
    result.sort(key=lambda f: f.z_order)
    return result
