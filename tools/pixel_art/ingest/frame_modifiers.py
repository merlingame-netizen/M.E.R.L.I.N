"""Frame modifiers — post-composite pixel modifications per animation frame.

The existing animation system only displaces layers (movement). Modifiers
add pixel-level effects AFTER compositing: blink (eyelid paint), glow,
trail afterimages, color shift, etc.

Usage:
    modifiers = [BlinkModifier(eyes, schedule='periodic')]
    modifiers = [GlowModifier(color=(100, 180, 255), radius=8, pulse=True)]
    modifiers = [TrailModifier(trail_count=3)]
    modifiers = [ColorShiftModifier(hue_start=0, hue_end=60)]
    frames = animate_layers(layers, ..., modifiers=modifiers)
"""

import math
from abc import ABC, abstractmethod
from collections import deque
from typing import List, Tuple, Dict, Optional

from PIL import Image, ImageFilter
import numpy as np

from .eye_detector import EyeRegion


# Blink schedules: maps frame_ratio (0.0-1.0) to eyelid closure (0.0-1.0)
# 0.0 = fully open, 1.0 = fully closed
BLINK_SCHEDULES = {
    'periodic': [
        # Frames 0-7: open, 8: closing, 9: closed, 10: opening, 11: open
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 1.0, 0.5, 0.0,
    ],
    'double': [
        # Two quick blinks
        0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    ],
    'slow': [
        # Slow blink (more frames closed)
        0.0, 0.0, 0.0, 0.2, 0.6, 1.0, 1.0, 1.0, 0.6, 0.2, 0.0, 0.0,
    ],
    'closed': [
        # Always closed (sleep)
        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
    ],
}


class FrameModifier(ABC):
    """Base class for post-composite frame modifications."""

    @abstractmethod
    def apply(
        self,
        frame: Image.Image,
        frame_idx: int,
        frame_count: int,
        scale: float,
        head_dy: float = 0.0,
        head_dx: float = 0.0,
    ) -> Image.Image:
        """Apply modification to a composited frame.

        Args:
            frame: RGBA frame at SOURCE resolution (before downscale).
            frame_idx: Current frame index (0-based).
            frame_count: Total number of frames.
            scale: Scale factor (source_size / 256.0).
            head_dy: Head vertical displacement in pixels (negative = up).
            head_dx: Head horizontal displacement in pixels (negative = left).

        Returns:
            Modified RGBA frame (same size).
        """


class BlinkModifier(FrameModifier):
    """Closes eyes by replacing distinct eye pixels with fur-colored lid pixels.

    Instead of painting lid rectangles (which cause artifacts on colored
    bodies), this modifier finds the actual eye pixels in each composited
    frame and replaces them pixel-by-pixel with the surrounding fur color.

    Detection uses color distance from lid_color, which works for:
      - Warm eyes (orange/yellow on purple body) — bestiole
      - Cold eyes (cyan/white on dark body) — Merlin
      - Any eye type as long as eyes differ from surrounding fur

    Artifact-free because:
      - Only actual eye pixels are modified (no rectangles)
      - Per-frame detection adapts to layer displacement automatically
      - No bbox expansion, no union, no clip — just pixel replacement
    """

    def __init__(
        self,
        eyes: List[EyeRegion],
        schedule: str = 'periodic',
        search_margin: int = 12,
        desync_frames: int = 1,
        head_coupling: float = 0.04,
    ):
        """
        Args:
            eyes: Detected eye regions from eye_detector.
            schedule: Blink timing ('periodic', 'double', 'slow', 'closed').
            search_margin: Pixels around eye bbox to search for displaced eyes.
            desync_frames: Integer frame offset between first and last eye.
            head_coupling: How much head_dy shifts closure (small additive).
        """
        self.eyes = eyes
        self.schedule_name = schedule
        self.schedule = BLINK_SCHEDULES.get(schedule, BLINK_SCHEDULES['periodic'])
        self.search_margin = search_margin
        self.desync_frames = desync_frames
        self.head_coupling = head_coupling

        # Pre-compute per-eye params sorted left-to-right
        sorted_eyes = sorted(eyes, key=lambda e: e.center[0])
        n = len(sorted_eyes)
        self._eye_params: Dict[int, Dict] = {}
        for rank, eye in enumerate(sorted_eyes):
            eid = id(eye)
            frame_offset = 0 if n <= 1 else int(
                desync_frames * (1.0 - rank / (n - 1))
            )
            # Detection: find pixels close to eye_color (targeted matching)
            # Radius = 35% of eye-to-lid color distance: tight enough to
            # exclude warm fur (bestiole) and hood pixels (Merlin),
            # wide enough to cover antialiased eye pixels.
            er, eg, eb = eye.color
            lr, lg, lb = eye.lid_color
            eye_lid_dist = math.sqrt(
                (er - lr) ** 2 + (eg - lg) ** 2 + (eb - lb) ** 2
            )
            self._eye_params[eid] = {
                'frame_offset': frame_offset,
                'eye_color_f': (float(er), float(eg), float(eb)),
                'eye_match_radius': max(int(eye_lid_dist * 0.35), 40),
            }

    def _get_eye_closure(
        self, eye: EyeRegion, frame_idx: int, frame_count: int, head_dy: float
    ) -> float:
        """Compute closure for a specific eye using integer frame offset."""
        params = self._eye_params.get(id(eye))
        if params is None:
            return 0.0

        shifted = (frame_idx + params['frame_offset']) % frame_count
        schedule_len = len(self.schedule)
        pos = shifted / frame_count * schedule_len
        idx = int(pos) % schedule_len
        frac = pos - int(pos)
        v1 = self.schedule[idx]
        v2 = self.schedule[(idx + 1) % schedule_len]
        closure = v1 + (v2 - v1) * frac
        closure += head_dy * self.head_coupling

        if closure < 0.05:
            return 0.0
        return min(1.0, closure)

    def apply(
        self,
        frame: Image.Image,
        frame_idx: int,
        frame_count: int,
        scale: float,
        head_dy: float = 0.0,
        head_dx: float = 0.0,
    ) -> Image.Image:
        any_closing = False
        closures = {}
        for eye in self.eyes:
            c = self._get_eye_closure(eye, frame_idx, frame_count, head_dy)
            closures[id(eye)] = c
            if c > 0.01:
                any_closing = True

        if not any_closing:
            return frame

        arr = np.array(frame)

        for eye in self.eyes:
            closure = closures.get(id(eye), 0.0)
            if closure <= 0.01:
                continue

            x1, y1, x2, y2 = eye.bbox
            m = self.search_margin
            params = self._eye_params[id(eye)]

            # Search region: eye bbox + margin (covers layer displacement)
            sy1 = max(0, y1 - m)
            sy2 = min(arr.shape[0], y2 + m)
            sx1 = max(0, x1 - m)
            sx2 = min(arr.shape[1], x2 + m)

            region = arr[sy1:sy2, sx1:sx2]
            if region.size == 0:
                continue

            # Find eye pixels by proximity to known eye_color
            # Only matches pixels that LOOK like the detected eye color
            r_ch = region[:, :, 0].astype(np.float32)
            g_ch = region[:, :, 1].astype(np.float32)
            b_ch = region[:, :, 2].astype(np.float32)
            alpha = region[:, :, 3]

            er, eg, eb = params['eye_color_f']
            dist_to_eye = np.sqrt(
                (r_ch - er) ** 2 + (g_ch - eg) ** 2 + (b_ch - eb) ** 2
            )
            eye_mask = (dist_to_eye < params['eye_match_radius']) & (alpha > 128)

            if not np.any(eye_mask):
                continue

            # Extended eye mask: includes the antialiased transition ring
            # around the eye. Without this, Merlin's teal halo pixels
            # remain visible when the eye closes (not fully black).
            # Safety: if extended captures >5× the eye pixels, the halo
            # is matching body/face (warm eyes on warm body like bestiole).
            # In that case, fall back to the original tight eye_mask.
            halo_radius = params['eye_match_radius'] * 2.0
            extended_mask = (dist_to_eye < halo_radius) & (alpha > 128)
            if extended_mask.sum() > eye_mask.sum() * 5:
                extended_mask = eye_mask

            # Eyelid geometry from ORIGINAL eye_mask (not extended)
            # to avoid expanding the lid area into face/body pixels.
            eye_rows = np.where(eye_mask.any(axis=1))[0]
            if len(eye_rows) == 0:
                continue

            eye_y_min = int(eye_rows[0])
            eye_y_max = int(eye_rows[-1])
            eye_height = eye_y_max - eye_y_min + 1
            lid_y_limit = eye_y_min + int(eye_height * closure)

            # --- Column-wise top-down lid replacement ---
            row_indices = np.arange(region.shape[0])[:, None]

            # Surrounding mask: only pixels beyond the halo ring
            surrounding_mask = (alpha > 128) & ~extended_mask
            if surrounding_mask.sum() < 4:
                surrounding_mask = (alpha > 128) & ~eye_mask

            # Solid replacement uses extended_mask (eye + transition ring)
            if closure >= 0.95:
                solid_mask = extended_mask & (row_indices <= lid_y_limit)
            else:
                solid_mask = extended_mask & (row_indices < lid_y_limit)

            # Border mask for 1px AA (partial close only)
            border_mask = (
                extended_mask & (row_indices == lid_y_limit)
                if closure < 0.95 else None
            )

            # Per-column scan: find lid color from ABOVE each eye pixel
            for c in range(region.shape[1]):
                col_solid = solid_mask[:, c]
                col_border = (
                    border_mask[:, c] if border_mask is not None else None
                )
                has_solid = np.any(col_solid)
                has_border = (
                    col_border is not None and np.any(col_border)
                )
                if not has_solid and not has_border:
                    continue

                # Search upward for the first qualifying pixel
                top_row = int(np.where(col_solid)[0][0]) if has_solid else (
                    int(np.where(col_border)[0][0])
                )
                lid_col = None
                for r in range(top_row - 1, -1, -1):
                    if surrounding_mask[r, c]:
                        lid_col = region[r, c, :3].copy()
                        break

                # Fallback: search downward
                if lid_col is None:
                    bot = int(np.where(
                        col_solid | (col_border if has_border else col_solid)
                    )[0][-1])
                    for r in range(bot + 1, region.shape[0]):
                        if surrounding_mask[r, c]:
                            lid_col = region[r, c, :3].copy()
                            break

                # Last resort: eye.lid_color
                if lid_col is None:
                    lid_col = np.array(eye.lid_color[:3], dtype=np.uint8)

                # Apply solid replacement
                if has_solid:
                    region[col_solid, c, 0] = lid_col[0]
                    region[col_solid, c, 1] = lid_col[1]
                    region[col_solid, c, 2] = lid_col[2]

                # Apply 1px AA border (50% blend)
                if has_border:
                    region[col_border, c, 0] = (
                        (r_ch[col_border, c] + float(lid_col[0])) * 0.5
                    ).astype(np.uint8)
                    region[col_border, c, 1] = (
                        (g_ch[col_border, c] + float(lid_col[1])) * 0.5
                    ).astype(np.uint8)
                    region[col_border, c, 2] = (
                        (b_ch[col_border, c] + float(lid_col[2])) * 0.5
                    ).astype(np.uint8)

        return Image.fromarray(arr)


class GlowModifier(FrameModifier):
    """Adds a colored glow halo around the sprite silhouette.

    The glow is a dilated + blurred version of the alpha mask,
    composited UNDER the sprite. Optionally pulses over the animation cycle.
    """

    def __init__(
        self,
        color: Tuple[int, int, int] = (100, 180, 255),
        radius: int = 8,
        alpha: int = 120,
        pulse: bool = False,
        pulse_min: float = 0.4,
    ):
        self.color = color
        self.base_radius = radius
        self.alpha = alpha
        self.pulse = pulse
        self.pulse_min = pulse_min

    def apply(
        self,
        frame: Image.Image,
        frame_idx: int,
        frame_count: int,
        scale: float,
        head_dy: float = 0.0,
        head_dx: float = 0.0,
    ) -> Image.Image:
        arr = np.array(frame)
        h, w = arr.shape[:2]

        # Extract alpha mask (binary: opaque pixels)
        mask = (arr[:, :, 3] > 32).astype(np.uint8)

        # Compute effective radius (pulse modulation)
        radius = int(self.base_radius * scale)
        if self.pulse and frame_count > 1:
            t = frame_idx / frame_count * 2.0 * math.pi
            pulse_factor = self.pulse_min + (1.0 - self.pulse_min) * (0.5 + 0.5 * math.sin(t))
            radius = max(1, int(radius * pulse_factor))

        if radius < 1:
            return frame

        # Dilate mask to create glow region
        from PIL import ImageFilter as _IF
        mask_img = Image.fromarray(mask * 255, mode='L')
        dilated = mask_img.filter(_IF.MaxFilter(size=radius * 2 + 1))

        # Subtract original mask -> ring
        dilated_arr = np.array(dilated).astype(np.float32)
        original_arr = np.array(mask_img).astype(np.float32)
        ring_arr = np.clip(dilated_arr - original_arr, 0, 255)

        # Blur the ring for soft glow
        ring_img = Image.fromarray(ring_arr.astype(np.uint8), mode='L')
        ring_blurred = ring_img.filter(_IF.GaussianBlur(radius=max(1, radius // 2)))

        # Create colored glow layer
        glow_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        glow_arr = np.array(glow_layer)
        ring_final = np.array(ring_blurred)
        glow_alpha = (ring_final.astype(np.float32) / 255.0 * self.alpha).astype(np.uint8)

        glow_arr[:, :, 0] = self.color[0]
        glow_arr[:, :, 1] = self.color[1]
        glow_arr[:, :, 2] = self.color[2]
        glow_arr[:, :, 3] = glow_alpha

        # Composite: glow UNDER sprite
        glow_img = Image.fromarray(glow_arr)
        result = glow_img.copy()
        result.paste(frame, (0, 0), frame)
        return result


class TrailModifier(FrameModifier):
    """Adds motion trail afterimages behind the sprite.

    Stores previous frames and composites them at decreasing opacity
    behind the current frame, creating a motion blur effect.
    """

    def __init__(
        self,
        trail_count: int = 3,
        base_alpha: float = 0.35,
    ):
        self.trail_count = trail_count
        self.base_alpha = base_alpha
        self._buffer: deque = deque(maxlen=trail_count)

    def apply(
        self,
        frame: Image.Image,
        frame_idx: int,
        frame_count: int,
        scale: float,
        head_dy: float = 0.0,
        head_dx: float = 0.0,
    ) -> Image.Image:
        if frame_idx == 0:
            self._buffer.clear()

        result = Image.new('RGBA', frame.size, (0, 0, 0, 0))

        # Draw afterimages from oldest to newest
        n = len(self._buffer)
        for i, old_frame in enumerate(self._buffer):
            # Alpha decreases for older frames
            age_ratio = (i + 1) / (n + 1)
            alpha_mult = self.base_alpha * (1.0 - age_ratio)
            if alpha_mult < 0.02:
                continue

            ghost = old_frame.copy()
            ghost_arr = np.array(ghost)
            ghost_arr[:, :, 3] = (ghost_arr[:, :, 3].astype(np.float32) * alpha_mult).astype(np.uint8)
            ghost = Image.fromarray(ghost_arr)
            result.paste(ghost, (0, 0), ghost)

        # Draw current frame on top
        result.paste(frame, (0, 0), frame)

        # Store current frame for next iteration
        self._buffer.append(frame.copy())

        return result


class ColorShiftModifier(FrameModifier):
    """Shifts the hue of opaque pixels across the animation cycle.

    Interpolates between hue_start and hue_end over the frame sequence,
    creating a smooth color transition effect.
    """

    def __init__(
        self,
        hue_start: float = 0.0,
        hue_end: float = 60.0,
    ):
        self.hue_start = hue_start
        self.hue_end = hue_end

    def apply(
        self,
        frame: Image.Image,
        frame_idx: int,
        frame_count: int,
        scale: float,
        head_dy: float = 0.0,
        head_dx: float = 0.0,
    ) -> Image.Image:
        if frame_count <= 1:
            t = 0.0
        else:
            t = frame_idx / (frame_count - 1)

        hue_offset = self.hue_start + (self.hue_end - self.hue_start) * t

        if abs(hue_offset) < 0.5:
            return frame

        # Vectorized HSV shift using numpy
        arr = np.array(frame).astype(np.float32)
        alpha = arr[:, :, 3]
        opaque = alpha > 32

        r = arr[:, :, 0] / 255.0
        g = arr[:, :, 1] / 255.0
        b = arr[:, :, 2] / 255.0

        mx = np.maximum(np.maximum(r, g), b)
        mn = np.minimum(np.minimum(r, g), b)
        diff = mx - mn

        # Hue computation
        h = np.zeros_like(diff)
        mask_r = (mx == r) & (diff > 0)
        mask_g = (mx == g) & (diff > 0)
        mask_b = (mx == b) & (diff > 0)
        h[mask_r] = (((g[mask_r] - b[mask_r]) / diff[mask_r]) % 6) / 6.0
        h[mask_g] = ((b[mask_g] - r[mask_g]) / diff[mask_g] + 2) / 6.0
        h[mask_b] = ((r[mask_b] - g[mask_b]) / diff[mask_b] + 4) / 6.0

        safe_mx = np.where(mx > 0, mx, 1.0)
        s = np.where(mx > 0, diff / safe_mx, 0.0)
        v = mx

        # Shift hue on opaque pixels only
        h[opaque] = (h[opaque] + hue_offset / 360.0) % 1.0

        # HSV -> RGB
        c = v * s
        x = c * (1 - np.abs((h * 6) % 2 - 1))
        m = v - c

        h6 = (h * 6).astype(int) % 6
        nr = np.zeros_like(h)
        ng = np.zeros_like(h)
        nb = np.zeros_like(h)

        for sector, rv, gv, bv in [(0, c, x, 0), (1, x, c, 0), (2, 0, c, x),
                                     (3, 0, x, c), (4, x, 0, c), (5, c, 0, x)]:
            mask = h6 == sector
            if isinstance(rv, (int, float)):
                nr[mask] = rv
            else:
                nr[mask] = rv[mask]
            if isinstance(gv, (int, float)):
                ng[mask] = gv
            else:
                ng[mask] = gv[mask]
            if isinstance(bv, (int, float)):
                nb[mask] = bv
            else:
                nb[mask] = bv[mask]

        result_arr = arr.copy()
        result_arr[:, :, 0] = np.where(opaque, (nr + m) * 255, arr[:, :, 0])
        result_arr[:, :, 1] = np.where(opaque, (ng + m) * 255, arr[:, :, 1])
        result_arr[:, :, 2] = np.where(opaque, (nb + m) * 255, arr[:, :, 2])

        return Image.fromarray(np.clip(result_arr, 0, 255).astype(np.uint8))
