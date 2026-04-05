// ═══════════════════════════════════════════════════════════════════════════════
// Scene Transition Manager — T065
// Fade overlay between BOOT → MENU → LAIR → GAME states
// ═══════════════════════════════════════════════════════════════════════════════

export type SceneState = 'BOOT' | 'MENU' | 'LAIR' | 'GAME';

const TRANSITION_RUNES = ['ᚁ','ᚂ','ᚃ','ᚄ','ᚅ','ᚆ','ᚇ','ᚈ','ᚉ','ᚋ','ᚌ','ᚍ','ᚎ'];

interface BiomeTransitionData {
  runes: string[];
  color: string;
  label: string;
}

const BIOME_TRANSITION_DATA: Record<string, BiomeTransitionData> = {
  'cotes_sauvages':    { runes: ['ᚉ','ᚊ','ᚋ'], color: 'rgba(51,200,180,0.85)',  label: 'CÔTES SAUVAGES' },
  'foret_broceliande': { runes: ['ᚁ','ᚂ','ᚃ'], color: 'rgba(51,255,102,0.85)',  label: 'FORÊT DE BROCÉLIANDE' },
  'plaine_druides':    { runes: ['ᚄ','ᚅ','ᚆ'], color: 'rgba(80,255,120,0.85)',  label: 'PLAINE DES DRUIDES' },
  'landes_bruyere':    { runes: ['ᚇ','ᚈ','ᚉ'], color: 'rgba(40,180,90,0.85)',   label: 'LANDES DE BRUYÈRE' },
  'cercles_pierres':   { runes: ['ᚊ','ᚋ','ᚌ'], color: 'rgba(100,255,150,0.85)', label: 'CERCLES DE PIERRES' },
  'marais_korrigans':  { runes: ['ᚍ','ᚎ','ᚏ'], color: 'rgba(30,140,80,0.85)',   label: 'MARAIS DES KORRIGANS' },
  'monts_brumeux':     { runes: ['ᚐ','ᚑ','ᚒ'], color: 'rgba(60,180,160,0.85)',  label: 'MONTS BRUMEUX' },
  'vallee_anciens':    { runes: ['ᚁ','ᚌ','ᚒ'], color: 'rgba(70,220,130,0.85)',  label: 'VALLÉE DES ANCIENS' },
};

interface TransitionOverlay {
  el: HTMLDivElement;
}

function sfx(sound: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound } }));
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
 *
 * @param biomeKey  Optional biome identifier. When provided and recognized,
 *                  uses biome-specific rune, color, and label.
 */
export function cutToBlack(biomeKey?: string): void {
  sfx('beep'); // C185: CRT cut feedback
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

    // Resolve biome data (or fall back to defaults)
    const biomeData = biomeKey != null ? BIOME_TRANSITION_DATA[biomeKey] : undefined;
    const runePool = biomeData ? biomeData.runes : TRANSITION_RUNES;
    const runeColor = biomeData ? biomeData.color : 'rgba(51,255,102,0.6)';
    const shadowColor = biomeData ? biomeData.color : 'rgba(51,255,102,0.8)';
    const rune = runePool[Math.floor(Math.random() * runePool.length)];

    // Show rune briefly on the black screen (fire-and-forget)
    const runeEl = document.createElement('div');
    runeEl.textContent = rune;
    runeEl.style.cssText = [
      'position:absolute',
      'inset:0',
      'display:flex',
      'flex-direction:column',
      'align-items:center',
      'justify-content:center',
      'gap:16px',
      'font-family:Courier New,monospace',
      'font-size:72px',
      `color:${runeColor}`,
      `text-shadow:0 0 30px ${shadowColor}`,
      'pointer-events:none',
      'opacity:0',
      'transition:opacity 0.3s ease',
    ].join(';');
    el.appendChild(runeEl);

    // Biome label element (only when biome is recognized)
    let labelEl: HTMLSpanElement | null = null;
    if (biomeData) {
      labelEl = document.createElement('span');
      labelEl.textContent = `— ${biomeData.label} —`;
      labelEl.style.cssText = [
        'font:9px Courier New,monospace',
        'letter-spacing:3px',
        `color:${biomeData.color}`,
        'opacity:0',
        'transition:opacity 0.3s ease',
        'font-size:9px',
      ].join(';');
      runeEl.appendChild(labelEl);
    }

    requestAnimationFrame(() => {
      runeEl.style.opacity = '1';
      // Fade-in label with 0.15s delay
      if (labelEl) {
        setTimeout(() => {
          if (labelEl) labelEl.style.opacity = '1';
        }, 150);
      }
      setTimeout(() => {
        runeEl.style.opacity = '0';
        if (labelEl) labelEl.style.opacity = '0';
        setTimeout(() => runeEl.remove(), 300);
      }, 600);
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
  sfx('magic_reveal'); // C185: cinematic reveal
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
  sfx('mapZoom'); // C185: wipe transition SFX
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
