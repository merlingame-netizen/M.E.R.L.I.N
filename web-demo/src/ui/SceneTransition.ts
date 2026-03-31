// ═══════════════════════════════════════════════════════════════════════════════
// Scene Transition Manager — T065
// Fade overlay between BOOT → MENU → LAIR → GAME states
// ═══════════════════════════════════════════════════════════════════════════════

export type SceneState = 'BOOT' | 'MENU' | 'LAIR' | 'GAME';

interface TransitionOverlay {
  el: HTMLDivElement;
}

let _overlay: TransitionOverlay | null = null;

function getOverlay(): TransitionOverlay {
  if (_overlay) return _overlay;

  const existing = document.getElementById('scene-transition-overlay');
  if (existing) {
    _overlay = { el: existing as HTMLDivElement };
    return _overlay;
  }

  const el = document.createElement('div');
  el.id = 'scene-transition-overlay';
  el.style.cssText = [
    'position:absolute',
    'top:0',
    'left:0',
    'right:0',
    'bottom:0',
    'background:#0a0a12',
    'opacity:0',
    'pointer-events:none',
    'z-index:180',
    'transition:opacity 0.6s ease',
  ].join(';');
  document.getElementById('app')?.appendChild(el);

  _overlay = { el };
  return _overlay;
}

/** Fade to black over durationMs, call midpoint(), then fade back in. */
export function transition(
  _from: SceneState,
  _to: SceneState,
  midpoint: () => void | Promise<void>,
  durationMs = 600
): Promise<void> {
  return new Promise((resolve) => {
    const { el } = getOverlay();
    el.style.pointerEvents = 'all';

    // Fade to black
    el.style.opacity = '1';

    setTimeout(async () => {
      await midpoint();

      // Fade back in (to transparent)
      el.style.opacity = '0';
      el.style.pointerEvents = 'none';

      setTimeout(resolve, durationMs);
    }, durationMs);
  });
}

/** Instantly go to black (for hard cuts). */
export function cutToBlack(): void {
  const { el } = getOverlay();
  el.style.transition = 'none';
  el.style.opacity = '1';
  el.style.pointerEvents = 'all';
  // Re-enable transition after next frame
  requestAnimationFrame(() => {
    el.style.transition = 'opacity 0.6s ease';
  });
}

/** Instantly reveal (fade out black). */
export function revealFromBlack(durationMs = 600): Promise<void> {
  return new Promise((resolve) => {
    const { el } = getOverlay();
    el.style.opacity = '0';
    el.style.pointerEvents = 'none';
    setTimeout(resolve, durationMs);
  });
}
