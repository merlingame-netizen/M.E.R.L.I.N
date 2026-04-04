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

/**
 * CRT power-off fade to black:
 *  1. Brief phosphor-green flash (40ms) — CRT capacitor discharge
 *  2. Smooth 0.3s fade to full black
 * Black is held until revealFromBlack().
 */
export function cutToBlack(): void {
  const { el } = getOverlay();

  // Phase 1 — CRT green flash (no transition, instant)
  el.style.transition = 'none';
  el.style.background = 'rgba(10,40,15,0.55)';
  el.style.opacity = '1';
  el.style.pointerEvents = 'all';

  // Phase 2 — smooth 0.3s fade to full black
  setTimeout(() => {
    el.style.background = '#060d06';
    requestAnimationFrame(() => {
      el.style.transition = 'opacity 0.3s ease';
      el.style.opacity = '1';
      // Restore smooth transition for future revealFromBlack
      setTimeout(() => {
        el.style.transition = 'opacity 0.55s ease';
      }, 320);
    });
  }, 40);
}

/**
 * CRT power-on reveal:
 *  1. Start black
 *  2. 50ms initial delay (prevents white flash on scene swap)
 *  3. Brief scanline flicker flash — monitor tube igniting
 *  4. Smooth 0.5s fade to transparent
 */
export function revealFromBlack(durationMs = 500): Promise<void> {
  return new Promise((resolve) => {
    const { el } = getOverlay();

    // Ensure we start fully opaque/black
    el.style.transition = 'none';
    el.style.background = '#060d06';
    el.style.opacity = '1';

    // Phase 1 — 50ms initial hold (no flash on fast scene swaps)
    setTimeout(() => {
      // Phase 2 — CRT ignition shimmer
      el.style.background = 'rgba(51,255,102,0.06)';

      setTimeout(() => {
        // Phase 3 — back to black then smooth fade out
        el.style.background = '#060d06';
        requestAnimationFrame(() => {
          el.style.transition = `opacity ${durationMs}ms ease`;
          el.style.opacity = '0';
          el.style.pointerEvents = 'none';
        });
        setTimeout(resolve, durationMs);
      }, 60);
    }, 50);
  });
}

/**
 * CRT-style wipe transition: a black rectangle sweeps in the given direction
 * over `durationMs` ms, occluding the scene.
 * Call midpoint() when the wipe is 50% complete (scene can swap then).
 */
export function wipeToBlack(
  direction: 'left' | 'right' | 'down',
  durationMs = 400
): Promise<void> {
  return new Promise((resolve) => {
    const { el } = getOverlay();

    el.style.transition = 'none';
    el.style.opacity = '1';
    el.style.background = '#060d06';
    el.style.pointerEvents = 'all';

    // Initial clip: panel fully outside, revealing nothing
    const clipStart = _wipeClipStart(direction);
    const clipEnd   = 'inset(0 0 0 0)'; // fully covers

    el.style.clipPath = clipStart;

    requestAnimationFrame(() => {
      el.style.transition = `clip-path ${durationMs}ms linear`;
      el.style.clipPath = clipEnd;
      setTimeout(() => {
        el.style.transition = 'none';
        el.style.clipPath = '';
        resolve();
      }, durationMs);
    });
  });
}

function _wipeClipStart(direction: 'left' | 'right' | 'down'): string {
  switch (direction) {
    case 'left':  return 'inset(0 100% 0 0)'; // slides in from right
    case 'right': return 'inset(0 0 0 100%)'; // slides in from left
    case 'down':  return 'inset(0 0 100% 0)'; // slides down from top
  }
}
