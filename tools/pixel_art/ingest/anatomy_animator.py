"""Anatomy animator — generate animation frames from grouped facets.

Each anatomical group (head, body, tail, etc.) gets independent motion
parameters.  Animation types:

  idle:    Gentle breathing + sway (sin/cos per group with phase offsets)
  walk:    Leg alternation + body bob
  blink:   Idle + eye blink (displacement only, blink handled by BlinkModifier)
  sleep:   Slow breathing, reduced amplitude (eyes handled by BlinkModifier)
  alert:   Ears up, body tense, tail down
  happy:   Tail wag fast, bouncy body
  curious: Head tilt, raised ear, questioning pose
  sad:     Head drooping, body slumped, tail low
  excited: Fast bounce, squash/stretch, wild tail
  scared:  Recoil, ears flat, tail tucked

The output is a list of transform dicts per frame.
"""

from dataclasses import dataclass
from typing import Dict, List, Tuple
import math

from .layer_splitter import AnatomyType


@dataclass(frozen=True)
class GroupTransform:
    """Per-frame transform for a single anatomical group."""
    dx: float = 0.0
    dy: float = 0.0
    rotation: float = 0.0      # degrees
    scale_x: float = 1.0
    scale_y: float = 1.0


@dataclass(frozen=True)
class GroupMotion:
    """Motion parameters for a single anatomical group."""
    dx_amplitude: float = 0.0       # horizontal sway amplitude (pixels)
    dy_amplitude: float = 0.0       # vertical breathing amplitude (pixels)
    phase_offset: float = 0.0       # phase offset in radians
    frequency: float = 1.0          # cycles per animation loop
    rotation_amplitude: float = 0.0 # rotation oscillation amplitude (degrees)
    scale_x_amplitude: float = 0.0  # horizontal squash/stretch (0.0 = none)
    scale_y_amplitude: float = 0.0  # vertical squash/stretch (0.0 = none)
    pivot_x: float = 0.5           # pivot x normalized in layer (0=left, 1=right)
    pivot_y: float = 1.0           # pivot y normalized in layer (0=top, 1=bottom)


# ---------------------------------------------------------------------------
# Animation presets per anatomy type
# ---------------------------------------------------------------------------

IDLE_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.5, phase_offset=0.0),
        'torso':      GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.0, phase_offset=0.1),
        'arm_left':   GroupMotion(dx_amplitude=0.8, dy_amplitude=-0.5, phase_offset=0.3),
        'arm_right':  GroupMotion(dx_amplitude=-0.8, dy_amplitude=-0.5, phase_offset=0.3),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0, phase_offset=0.0),
    },
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.2, phase_offset=0.0),
        'ears':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-2.0, phase_offset=-0.2),
        'body':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-0.8, phase_offset=0.15),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.3, phase_offset=0.4),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.2, phase_offset=0.5),
        'tail':        GroupMotion(dx_amplitude=1.5, dy_amplitude=-0.5, phase_offset=-0.4,
                                  frequency=1.3),
    },
    AnatomyType.CREATURE: {
        'head':        GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.5, phase_offset=0.0),
        'body':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.0, phase_offset=0.15),
        'appendages':  GroupMotion(dx_amplitude=0.8, dy_amplitude=-0.3, phase_offset=0.3),
    },
    AnatomyType.BIRD: {
        'head':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.0, phase_offset=0.0),
        'body':        GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.8, phase_offset=0.1),
        'wing_left':   GroupMotion(dx_amplitude=-1.0, dy_amplitude=-1.5, phase_offset=0.0),
        'wing_right':  GroupMotion(dx_amplitude=1.0, dy_amplitude=-1.5, phase_offset=0.0),
        'tail':        GroupMotion(dx_amplitude=0.5, dy_amplitude=0.3, phase_offset=0.4),
        'legs':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0, phase_offset=0.0),
    },
    AnatomyType.OBJECT: {
        'body':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-0.8, phase_offset=0.0),
    },
}


# Sleep: like idle but 50% amplitude, 50% frequency (slow breathing)
SLEEP_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.5, phase_offset=0.0,
                                  frequency=0.5),
        'ears':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'body':        GroupMotion(dx_amplitude=0.1, dy_amplitude=-0.4, phase_offset=0.15,
                                  frequency=0.5),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-0.1, phase_offset=-0.4,
                                  frequency=0.5),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.6, phase_offset=0.0,
                                 frequency=0.5),
        'torso':      GroupMotion(dx_amplitude=0.1, dy_amplitude=-0.4, phase_offset=0.1,
                                 frequency=0.5),
        'arm_left':   GroupMotion(dx_amplitude=0.3, dy_amplitude=-0.2, phase_offset=0.3,
                                 frequency=0.5),
        'arm_right':  GroupMotion(dx_amplitude=-0.3, dy_amplitude=-0.2, phase_offset=0.3,
                                 frequency=0.5),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
    AnatomyType.CREATURE: {
        'head':        GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.6, phase_offset=0.0,
                                  frequency=0.5),
        'body':        GroupMotion(dx_amplitude=0.1, dy_amplitude=-0.4, phase_offset=0.15,
                                  frequency=0.5),
        'appendages':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
    AnatomyType.BIRD: {
        'head':        GroupMotion(dx_amplitude=0.1, dy_amplitude=-0.4, phase_offset=0.0,
                                  frequency=0.5),
        'body':        GroupMotion(dx_amplitude=0.1, dy_amplitude=-0.3, phase_offset=0.1,
                                  frequency=0.5),
        'wing_left':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'wing_right':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'legs':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}

# Alert: ears up (negative dy), body slightly raised, tail low
ALERT_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=0.0, dy_amplitude=-0.5, phase_offset=0.0,
                                  frequency=0.3),
        'ears':        GroupMotion(dx_amplitude=0.0, dy_amplitude=-3.0, phase_offset=0.0,
                                  frequency=0.2),
        'body':        GroupMotion(dx_amplitude=0.0, dy_amplitude=-0.3, phase_offset=0.0,
                                  frequency=0.3),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=0.5, dy_amplitude=1.0, phase_offset=0.0,
                                  frequency=0.4),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.0, dy_amplitude=-0.8, phase_offset=0.0,
                                 frequency=0.3),
        'torso':      GroupMotion(dx_amplitude=0.0, dy_amplitude=-0.3, phase_offset=0.0,
                                 frequency=0.3),
        'arm_left':   GroupMotion(dx_amplitude=-0.5, dy_amplitude=-0.3, phase_offset=0.0,
                                 frequency=0.3),
        'arm_right':  GroupMotion(dx_amplitude=0.5, dy_amplitude=-0.3, phase_offset=0.0,
                                 frequency=0.3),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}

# Happy: fast tail wag, bouncy body, perky ears
HAPPY_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=0.8, dy_amplitude=-1.5, phase_offset=0.0,
                                  frequency=1.5),
        'ears':        GroupMotion(dx_amplitude=0.5, dy_amplitude=-2.5, phase_offset=-0.3,
                                  frequency=1.5),
        'body':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.2, phase_offset=0.1,
                                  frequency=1.5),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.5, phase_offset=0.3,
                                  frequency=1.5),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.4, phase_offset=0.5,
                                  frequency=1.5),
        'tail':        GroupMotion(dx_amplitude=3.0, dy_amplitude=-0.5, phase_offset=-0.2,
                                  frequency=3.0),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.8, phase_offset=0.0,
                                 frequency=1.5),
        'torso':      GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.2, phase_offset=0.1,
                                 frequency=1.5),
        'arm_left':   GroupMotion(dx_amplitude=1.2, dy_amplitude=-0.8, phase_offset=0.3,
                                 frequency=1.5),
        'arm_right':  GroupMotion(dx_amplitude=-1.2, dy_amplitude=-0.8, phase_offset=0.3,
                                 frequency=1.5),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.3, phase_offset=0.4,
                                 frequency=1.5),
    },
    AnatomyType.BIRD: {
        'head':        GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.5, phase_offset=0.0,
                                  frequency=2.0),
        'body':        GroupMotion(dx_amplitude=0.3, dy_amplitude=-1.0, phase_offset=0.1,
                                  frequency=1.5),
        'wing_left':   GroupMotion(dx_amplitude=-2.0, dy_amplitude=-2.5, phase_offset=0.0,
                                  frequency=2.0),
        'wing_right':  GroupMotion(dx_amplitude=2.0, dy_amplitude=-2.5, phase_offset=0.0,
                                  frequency=2.0),
        'tail':        GroupMotion(dx_amplitude=1.0, dy_amplitude=0.5, phase_offset=0.4,
                                  frequency=2.0),
        'legs':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}

# Curious: head tilt, raised ear, inquisitive posture
CURIOUS_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=1.5, dy_amplitude=-0.8, phase_offset=0.0,
                                  frequency=0.6, rotation_amplitude=15.0,
                                  pivot_x=0.5, pivot_y=0.8),
        'ears':        GroupMotion(dx_amplitude=0.8, dy_amplitude=-2.5, phase_offset=-0.3,
                                  frequency=0.8, rotation_amplitude=12.0),
        'body':        GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.5, phase_offset=0.1,
                                  frequency=0.6),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=0.8, dy_amplitude=-0.3, phase_offset=-0.4,
                                  frequency=0.8),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.8, dy_amplitude=-0.5, phase_offset=0.0,
                                 frequency=0.6, rotation_amplitude=6.0),
        'torso':      GroupMotion(dx_amplitude=0.2, dy_amplitude=-0.3, phase_offset=0.1,
                                 frequency=0.6),
        'arm_left':   GroupMotion(dx_amplitude=0.5, dy_amplitude=-0.3, phase_offset=0.2,
                                 frequency=0.6),
        'arm_right':  GroupMotion(dx_amplitude=-0.3, dy_amplitude=0.5, phase_offset=0.3,
                                 frequency=0.6, rotation_amplitude=10.0),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}

# Sad: head drooping, body slumped, tail low and slow
SAD_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=0.0, dy_amplitude=2.0, phase_offset=0.0,
                                  frequency=0.4, rotation_amplitude=-8.0,
                                  pivot_x=0.5, pivot_y=0.2),
        'ears':        GroupMotion(dx_amplitude=0.0, dy_amplitude=1.0, phase_offset=0.1,
                                  frequency=0.4),
        'body':        GroupMotion(dx_amplitude=0.0, dy_amplitude=0.5, phase_offset=0.15,
                                  frequency=0.4, scale_y_amplitude=-0.02),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=0.3, dy_amplitude=1.5, phase_offset=-0.4,
                                  frequency=0.3),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.0, dy_amplitude=1.0, phase_offset=0.0,
                                 frequency=0.4, rotation_amplitude=-4.0),
        'torso':      GroupMotion(dx_amplitude=0.0, dy_amplitude=0.5, phase_offset=0.1,
                                 frequency=0.4, scale_y_amplitude=-0.02),
        'arm_left':   GroupMotion(dx_amplitude=0.3, dy_amplitude=0.5, phase_offset=0.2,
                                 frequency=0.4),
        'arm_right':  GroupMotion(dx_amplitude=-0.3, dy_amplitude=0.5, phase_offset=0.2,
                                 frequency=0.4),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}

# Excited: fast bounce, wild tail, squash/stretch on body
EXCITED_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=1.0, dy_amplitude=-2.5, phase_offset=0.0,
                                  frequency=2.0),
        'ears':        GroupMotion(dx_amplitude=0.8, dy_amplitude=-3.0, phase_offset=-0.3,
                                  frequency=2.0, rotation_amplitude=18.0),
        'body':        GroupMotion(dx_amplitude=0.5, dy_amplitude=-2.0, phase_offset=0.1,
                                  frequency=2.0, scale_y_amplitude=0.05),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=1.0, phase_offset=0.3,
                                  frequency=2.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.8, phase_offset=0.5,
                                  frequency=2.0),
        'tail':        GroupMotion(dx_amplitude=4.0, dy_amplitude=-1.0, phase_offset=-0.2,
                                  frequency=4.0),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=0.8, dy_amplitude=-2.0, phase_offset=0.0,
                                 frequency=2.0),
        'torso':      GroupMotion(dx_amplitude=0.5, dy_amplitude=-1.5, phase_offset=0.1,
                                 frequency=2.0, scale_y_amplitude=0.03),
        'arm_left':   GroupMotion(dx_amplitude=1.5, dy_amplitude=-1.0, phase_offset=0.2,
                                 frequency=2.0, rotation_amplitude=8.0),
        'arm_right':  GroupMotion(dx_amplitude=-1.5, dy_amplitude=-1.0, phase_offset=0.2,
                                 frequency=2.0, rotation_amplitude=-8.0),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.5, phase_offset=0.4,
                                 frequency=2.0),
    },
}

# Scared: recoil, ears flat, tail tucked, body compressed
SCARED_PRESETS: Dict[AnatomyType, Dict[str, GroupMotion]] = {
    AnatomyType.QUADRUPED: {
        'head':        GroupMotion(dx_amplitude=-1.5, dy_amplitude=0.8, phase_offset=0.0,
                                  frequency=0.5, rotation_amplitude=-12.0,
                                  pivot_x=0.5, pivot_y=0.5),
        'ears':        GroupMotion(dx_amplitude=-0.5, dy_amplitude=1.5, phase_offset=0.1,
                                  frequency=0.5),
        'body':        GroupMotion(dx_amplitude=-0.5, dy_amplitude=0.3, phase_offset=0.0,
                                  frequency=0.5, scale_x_amplitude=-0.02),
        'front_legs':  GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'back_legs':   GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
        'tail':        GroupMotion(dx_amplitude=-1.0, dy_amplitude=1.5, phase_offset=0.0,
                                  frequency=0.5),
    },
    AnatomyType.HUMANOID: {
        'head':       GroupMotion(dx_amplitude=-0.5, dy_amplitude=0.5, phase_offset=0.0,
                                 frequency=0.5, rotation_amplitude=-4.0),
        'torso':      GroupMotion(dx_amplitude=-0.3, dy_amplitude=0.3, phase_offset=0.0,
                                 frequency=0.5, scale_y_amplitude=-0.02),
        'arm_left':   GroupMotion(dx_amplitude=-0.8, dy_amplitude=0.5, phase_offset=0.1,
                                 frequency=0.5),
        'arm_right':  GroupMotion(dx_amplitude=0.8, dy_amplitude=0.5, phase_offset=0.1,
                                 frequency=0.5),
        'legs':       GroupMotion(dx_amplitude=0.0, dy_amplitude=0.0),
    },
}


# Map animation name -> preset dict
ANIMATION_PRESETS = {
    'idle':    IDLE_PRESETS,
    'blink':   IDLE_PRESETS,   # same movement as idle, blink handled by modifier
    'sleep':   SLEEP_PRESETS,
    'alert':   ALERT_PRESETS,
    'happy':   HAPPY_PRESETS,
    'curious': CURIOUS_PRESETS,
    'sad':     SAD_PRESETS,
    'excited': EXCITED_PRESETS,
    'scared':  SCARED_PRESETS,
}


# ---------------------------------------------------------------------------
# Frame generation
# ---------------------------------------------------------------------------

def generate_displacements(
    anatomy: AnatomyType,
    frame_count: int = 12,
    animation: str = 'idle',
    custom_presets: Dict[str, GroupMotion] = None,
) -> List[Dict[str, GroupTransform]]:
    """Generate per-frame transform maps for each anatomical group.

    Args:
        anatomy: Creature type.
        frame_count: Number of animation frames.
        animation: Animation type ('idle', 'walk', 'blink', 'sleep', 'alert',
                   'happy', 'curious', 'sad', 'excited', 'scared').
        custom_presets: Override default presets.

    Returns:
        List of frame_count dicts, each mapping group_name -> GroupTransform.
    """
    if custom_presets:
        presets = custom_presets
    else:
        preset_dict = ANIMATION_PRESETS.get(animation, IDLE_PRESETS)
        presets = preset_dict.get(anatomy, IDLE_PRESETS.get(
            anatomy, IDLE_PRESETS[AnatomyType.OBJECT]
        ))

    frames = []
    for i in range(frame_count):
        t = (i / frame_count) * 2.0 * math.pi  # 0 -> 2pi over full cycle

        frame_disp: Dict[str, GroupTransform] = {}
        for group_name, motion in presets.items():
            phase = t * motion.frequency + motion.phase_offset
            dx = motion.dx_amplitude * math.sin(phase)
            dy = motion.dy_amplitude * math.sin(phase)
            rotation = motion.rotation_amplitude * math.sin(phase)
            scale_x = 1.0 + motion.scale_x_amplitude * math.sin(phase)
            scale_y = 1.0 + motion.scale_y_amplitude * math.sin(phase)
            frame_disp[group_name] = GroupTransform(
                dx=dx, dy=dy, rotation=rotation,
                scale_x=scale_x, scale_y=scale_y,
            )

        frames.append(frame_disp)

    return frames


def generate_walk_displacements(
    anatomy: AnatomyType,
    frame_count: int = 8,
) -> List[Dict[str, Tuple[float, float]]]:
    """Generate walk cycle displacements.

    Walk cycle: alternating leg movement with body bob.
    """
    presets = dict(IDLE_PRESETS.get(anatomy, IDLE_PRESETS[AnatomyType.OBJECT]))

    if anatomy == AnatomyType.QUADRUPED:
        presets['front_legs'] = GroupMotion(
            dx_amplitude=0.0, dy_amplitude=1.5,
            phase_offset=0.0, frequency=2.0,
        )
        presets['back_legs'] = GroupMotion(
            dx_amplitude=0.0, dy_amplitude=1.5,
            phase_offset=math.pi, frequency=2.0,
        )
        presets['body'] = GroupMotion(
            dx_amplitude=0.5, dy_amplitude=-1.0,
            phase_offset=0.0, frequency=2.0,
        )
    elif anatomy == AnatomyType.HUMANOID:
        presets['legs'] = GroupMotion(
            dx_amplitude=0.0, dy_amplitude=1.0,
            phase_offset=0.0, frequency=2.0,
        )
        presets['torso'] = GroupMotion(
            dx_amplitude=0.5, dy_amplitude=-0.5,
            phase_offset=0.0, frequency=2.0,
        )

    return generate_displacements(
        anatomy, frame_count, animation='walk',
        custom_presets=presets,
    )
