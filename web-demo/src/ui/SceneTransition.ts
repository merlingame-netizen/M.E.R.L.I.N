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
 * CRT power-off cut to black:
 *  1. Brief phosphor-green flash (40ms) — CRT capacitor discharge
 *  2. Hard cut to black
 * Total ~80ms then black is held until revealFromBlack().
 */
export function cutToBlack(): void {
  const { el } = getOverlay();

  // Phase 1 — CRT green flash
  el.style.transition = 'none';
  el.style.background = 'rgba(10,40,15,0.55)';
  el.style.opacity = '1';
  el.style.pointerEvents = 'all';

  // Phase 2 — hard black after flash
  setTimeout(() => {
    el.style.background = '#060d06';
    // Re-enable smooth transition for future revealFromBlack
    requestAnimationFrame(() => {
      el.style.transition = 'opacity 0.55s ease';
    });
  }, 60);
}

/**
 * CRT power-on reveal:
 *  1. Start black
 *  2. Brief scanline flicker flash (white at very low opacity) — monitor tube igniting
 *  3. Smooth fade to transparent over durationMs
 */
export function revealFromBlack(durationMs = 600): Promise<void> {
  return new Promise((resolve) => {
    const { el } = getOverlay();

    // Phase 1 — CRT ignition flash (scanline shimmer)
    el.style.transition = 'none';
    el.style.background = 'rgba(51,255,102,0.06)';
    el.style.opacity = '1';

    setTimeout(() => {
      // Phase 2 — back to black then fade out
      el.style.background = '#060d06';
      requestAnimationFrame(() => {
        el.style.transition = `opacity ${durationMs}ms ease`;
        el.style.opacity = '0';
        el.style.pointerEvents = 'none';
      });
      setTimeout(resolve, durationMs);
    }, 80);
  });
}
