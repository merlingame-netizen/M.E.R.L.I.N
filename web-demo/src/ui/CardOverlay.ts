// ═══════════════════════════════════════════════════════════════════════════════
// Card Overlay — Displays narrative card with 3 options
// T067: Dark parchment card design with Celtic border, gold typography
// T068: Effect preview tooltip on hover
// ═══════════════════════════════════════════════════════════════════════════════

import type { Card, CardOption } from '../game/CardSystem';

const cardContainer = () => document.querySelector<HTMLElement>('.card-container');

// ── SFX helper ─────────────────────────────────────────────────────────────

function sfx(sound: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound } }));
}

// ── Ogham glyph map (Unicode Ogham block U+1680–U+169F) ──────────────────

const OGHAM_GLYPHS: Record<string, string> = {
  Beith:  'ᚁ', Luis:   'ᚂ', Nion:   'ᚃ', Fearn:  'ᚄ', Sail:   'ᚅ',
  Huath:  'ᚆ', Dair:   'ᚇ', Tinne:  'ᚈ', Coll:   'ᚉ', Quert:  'ᚊ',
  Muin:   'ᚋ', Gort:   'ᚌ', Ngetal: 'ᚍ', Straif: 'ᚎ', Ruis:   'ᚏ',
  Ailm:   'ᚐ', Onn:    'ᚑ', Ur:     'ᚒ', Edad:   'ᚓ', Idad:   'ᚔ',
};

/**
 * Scan an option's effects for ACTIVATE_OGHAM:Name and return the Unicode glyph,
 * or null if none found.
 */
function extractOghamGlyph(option: CardOption): string | null {
  for (const eff of option.effects) {
    const s = eff as string;
    if (!s.startsWith('ACTIVATE_OGHAM:')) continue;
    const name = s.split(':')[1] ?? '';
    const glyph = OGHAM_GLYPHS[name];
    if (glyph) return glyph;
  }
  return null;
}

// ── Card overlay entrance animation styles injection (idempotent) ────────

function ensureCardOverlayEnterStyles(): void {
  if (document.getElementById('card-overlay-enter-style')) return;
  const s = document.createElement('style');
  s.id = 'card-overlay-enter-style';
  s.textContent = `
    @keyframes card-overlay-enter {
      from { transform: translateY(-30px) scale(0.94); opacity: 0; }
      to   { transform: translateY(0) scale(1); opacity: 1; }
    }
    .card-overlay-enter {
      animation: card-overlay-enter 280ms ease-out forwards;
    }
  `;
  document.head.appendChild(s);
}

// ── Spawn green sparks that sweep outward from overlay center (C315) ──────

function spawnCardSparks(overlayEl: HTMLElement): void {
  const rect = overlayEl.getBoundingClientRect();
  const cx = rect.left + rect.width / 2;
  const cy = rect.top + rect.height / 2;

  for (let i = 0; i < 6; i++) {
    const spark = document.createElement('div');
    const angle = (i / 6) * 2 * Math.PI + (Math.random() * 0.5 - 0.25);
    const dist = 80 + Math.random() * 60; // 80–140 px
    const dx = Math.cos(angle) * dist;
    const dy = Math.sin(angle) * dist;

    spark.style.cssText = [
      'position:fixed',
      `left:${cx - 2}px`,
      `top:${cy - 2}px`,
      'width:4px',
      'height:4px',
      'border-radius:50%',
      'background:rgba(51,255,102,0.8)',
      'pointer-events:none',
      'z-index:9999',
      'transition:transform 400ms ease-out, opacity 400ms ease-out',
      'transform:translate(0,0)',
      'opacity:1',
    ].join(';');

    document.body.appendChild(spark);

    // Trigger transition on next frame
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        spark.style.transform = `translate(${dx}px,${dy}px)`;
        spark.style.opacity = '0';
      });
    });

    setTimeout(() => { spark.remove(); }, 400);
  }
}

// ── Card flip-reveal animation styles injection (idempotent) ─────────────

function ensureCardFlipStyles(): void {
  if (document.getElementById('card-flip-style')) return;
  const s = document.createElement('style');
  s.id = 'card-flip-style';
  s.textContent = `
    @keyframes card-flip-in {
      0%   { transform: perspective(600px) rotateY(-90deg); opacity: 0; }
      40%  { opacity: 1; }
      100% { transform: perspective(600px) rotateY(0deg); opacity: 1; }
    }
    .card-flip-reveal {
      animation: card-flip-in 0.45s cubic-bezier(0.34,1.2,0.64,1) forwards;
      transform-origin: center center;
    }
  `;
  document.head.appendChild(s);
}

// ── Option slide-in animation styles injection (idempotent) ──────────────

function ensureCardOptAnimStyles(): void {
  if (document.getElementById('card-opt-anim-style')) return;
  const s = document.createElement('style');
  s.id = 'card-opt-anim-style';
  s.textContent = `
    @keyframes card-opt-slide-in {
      from { opacity: 0; transform: translateY(18px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .card-opt-animate {
      opacity: 0;
      animation: card-opt-slide-in 0.32s ease-out forwards;
    }
  `;
  document.head.appendChild(s);
}

// ── Option badge + ogham styles injection (idempotent) ────────────────────

function ensureCardOptBadgeStyles(): void {
  if (document.getElementById('card-opt-badge-styles')) return;
  const s = document.createElement('style');
  s.id = 'card-opt-badge-styles';
  s.textContent = `
    .card-opt-num {
      position: absolute;
      top: 6px;
      left: 8px;
      font: bold 0.65rem 'Courier New', monospace;
      color: rgba(51,255,102,0.4);
      background: rgba(1,8,2,0.7);
      border: 1px solid rgba(51,255,102,0.2);
      padding: 1px 5px;
      border-radius: 2px;
      pointer-events: none;
      line-height: 1.4;
      user-select: none;
    }
    .card-opt-ogham {
      position: absolute;
      top: 6px;
      right: 8px;
      font: bold 1rem 'Courier New', monospace;
      color: rgba(51,255,102,0.55);
      background: rgba(1,8,2,0.7);
      border: 1px solid rgba(51,255,102,0.25);
      padding: 0px 5px;
      border-radius: 2px;
      pointer-events: none;
      line-height: 1.4;
      user-select: none;
    }
  `;
  document.head.appendChild(s);
}

// ── Badge + flavor styles injection (idempotent) ──────────────────────────

function ensureCardBadgeStyles(): void {
  if (document.getElementById('card-badge-styles')) return;
  const s = document.createElement('style');
  s.id = 'card-badge-styles';
  s.textContent = `
    .card-faction-badge {
      display: inline-block;
      font: bold 0.65rem 'Courier New', monospace;
      padding: 2px 6px;
      border-radius: 2px;
      vertical-align: middle;
      margin-left: 8px;
      letter-spacing: 0.05em;
      background: rgba(0,0,0,0.6);
    }
    .card-flavor {
      font: italic 0.72rem 'Courier New', monospace;
      color: rgba(51,255,102,0.55);
      border-top: 1px solid rgba(51,255,102,0.15);
      padding-top: 6px;
      margin-top: 8px;
      line-height: 1.5;
    }
  `;
  document.head.appendChild(s);
}

// ── Verb-select animation style injection (idempotent) ─────────────────────

function ensureCardSelectStyle(): void {
  if (document.getElementById('card-select-anim')) return;
  const s = document.createElement('style');
  s.id = 'card-select-anim';
  s.textContent = `
    @keyframes verb-select {
      0%   { transform: scale(1);    color: inherit; }
      40%  { transform: scale(1.18); color: #33ff66; text-shadow: 0 0 12px rgba(51,255,102,0.8); }
      100% { transform: scale(1);    color: inherit; }
    }
    .card-option.selected .verb {
      animation: verb-select 0.22s ease-out forwards;
    }
  `;
  document.head.appendChild(s);
}

// ── Faction colour map (T067) ──────────────────────────────────────────────

const FACTION_COLOURS: Record<string, string> = {
  druides:  '#6abf69',
  niamh:    '#8ab4f8',
  korrigans:'#b888e8',
  anciens:  '#e8c84c',
  ankou:    '#e05c5c',
};

function getFactionColour(faction: string): string {
  return FACTION_COLOURS[faction.toLowerCase()] ?? 'rgba(51,255,102,0.70)';
}

// ── Faction glow map (C244) — card panel border glow per faction ───────────

const FACTION_GLOW: Record<string, string> = {
  druides:   'rgba(51,255,102,0.35)',   // forest green
  anciens:   'rgba(100,180,255,0.30)',  // time-blue
  korrigans: 'rgba(180,80,255,0.30)',   // chaos-purple
  niamh:     'rgba(255,180,220,0.28)', // healing-rose
  ankou:     'rgba(140,160,180,0.30)', // death-silver
  central:   'rgba(51,255,102,0.20)',  // neutral green
};

// ── Faction SVG background pattern map (C300) ─────────────────────────────
// Each value is a ready-to-use CSS background-image data URL.
// All patterns use rgba(51,255,102,...) green family — CeltOS charter compliant.

function buildSvgDataUrl(svgBody: string, w = 20, h = 20): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${svgBody}</svg>`;
  // Minimal URL encoding: encode only characters that break data URLs in CSS
  const encoded = svg
    .replace(/%/g, '%25')
    .replace(/#/g, '%23')
    .replace(/\n/g, '')
    .replace(/"/g, "'");
  return `url("data:image/svg+xml,${encoded}")`;
}

const FACTION_PATTERN: Record<string, string> = {
  // Interlocking circles — Celtic triquetra style
  druides: buildSvgDataUrl(
    `<circle cx='10' cy='5' r='6' fill='none' stroke='rgba(51,255,102,0.12)' stroke-width='1'/>` +
    `<circle cx='5' cy='14' r='6' fill='none' stroke='rgba(51,255,102,0.12)' stroke-width='1'/>` +
    `<circle cx='15' cy='14' r='6' fill='none' stroke='rgba(51,255,102,0.12)' stroke-width='1'/>`,
  ),
  // Diamond grid
  anciens: buildSvgDataUrl(
    `<path d='M10,0 L20,10 L10,20 L0,10 Z' fill='none' stroke='rgba(51,255,102,0.10)' stroke-width='1'/>`,
  ),
  // Chaotic zig-zag lines
  korrigans: buildSvgDataUrl(
    `<polyline points='0,5 4,1 8,9 12,3 16,11 20,5' fill='none' stroke='rgba(51,255,102,0.09)' stroke-width='1'/>` +
    `<polyline points='0,15 4,11 8,19 12,13 16,18 20,15' fill='none' stroke='rgba(51,255,102,0.09)' stroke-width='1'/>`,
  ),
  // Flowing wave curves
  niamh: buildSvgDataUrl(
    `<path d='M0,10 Q5,0 10,10 Q15,20 20,10' fill='none' stroke='rgba(51,255,102,0.11)' stroke-width='1'/>` +
    `<path d='M0,20 Q5,10 10,20' fill='none' stroke='rgba(51,255,102,0.11)' stroke-width='1'/>`,
  ),
  // Skull-like X crosses
  ankou: buildSvgDataUrl(
    `<line x1='2' y1='2' x2='8' y2='8' stroke='rgba(51,255,102,0.08)' stroke-width='1'/>` +
    `<line x1='8' y1='2' x2='2' y2='8' stroke='rgba(51,255,102,0.08)' stroke-width='1'/>` +
    `<line x1='12' y1='12' x2='18' y2='18' stroke='rgba(51,255,102,0.08)' stroke-width='1'/>` +
    `<line x1='18' y1='12' x2='12' y2='18' stroke='rgba(51,255,102,0.08)' stroke-width='1'/>`,
  ),
};

// Neutral / default: simple dot grid
const FACTION_PATTERN_DEFAULT: string = buildSvgDataUrl(
  `<circle cx='10' cy='10' r='1' fill='rgba(51,255,102,0.07)'/>`,
);

function getFactionPattern(factionKey: string): string {
  return FACTION_PATTERN[factionKey] ?? FACTION_PATTERN_DEFAULT;
}

// ── Title colour by faction (C244) ─────────────────────────────────────────

const FACTION_TITLE_COLOUR: Record<string, string> = {
  druides:   '#33ff66',
  anciens:   '#64b4ff',
  korrigans: '#b450ff',
  niamh:     '#ffb4dc',
  ankou:     '#8ca0b4',
  central:   '#33ff66',
};

// ── Effect parsing for tooltip (T068) ─────────────────────────────────────

interface ParsedEffect {
  label: string;
  positive: boolean | null; // null = neutral
}

/**
 * Parse an effect string like "HEAL_LIFE:5", "ADD_REPUTATION:druides:12",
 * "DAMAGE_LIFE:3", "PROMISE:xxx" into a human-readable label.
 */
function parseEffect(effectStr: string): ParsedEffect {
  const parts = effectStr.split(':');
  const type = parts[0] ?? '';
  switch (type) {
    case 'HEAL_LIFE': {
      const amt = parts[1] ?? '?';
      return { label: `+${amt} Vie`, positive: true };
    }
    case 'DAMAGE_LIFE': {
      const amt = parts[1] ?? '?';
      return { label: `-${amt} Vie`, positive: false };
    }
    case 'ADD_REPUTATION': {
      const faction = parts[1] ?? '?';
      const amt = Number(parts[2] ?? 0);
      const sign = amt >= 0 ? '+' : '';
      return { label: `${sign}${amt} ${faction}`, positive: amt >= 0 };
    }
    case 'PROMISE': {
      return { label: 'Promesse', positive: null };
    }
    default:
      return { label: effectStr, positive: null };
  }
}

/**
 * Build the effect tooltip DOM node for a card option (T068).
 * Returns null if the option has no effects.
 */
function buildEffectTooltip(option: CardOption): HTMLElement | null {
  const effects = option.effects;
  if (!effects || effects.length === 0) return null;

  const tooltip = document.createElement('div');
  tooltip.className = 'effect-tooltip';

  for (const eff of effects) {
    const parsed = parseEffect(eff as string);
    const line = document.createElement('div');
    line.className = 'effect-line';

    const cls = parsed.positive === true
      ? 'effect-pos'
      : parsed.positive === false
        ? 'effect-neg'
        : 'effect-neu';

    const icon = parsed.positive === true ? '▲' : parsed.positive === false ? '▼' : '◆';

    // C107: textContent — parsed.label comes from LLM JSON (faction names, raw effect strings)
    // innerHTML here is a real XSS vector if LLM guardrails fail (default case uses raw effectStr)
    const spanEl = document.createElement('span');
    spanEl.className = cls;
    const iconEl = document.createElement('span');
    iconEl.setAttribute('aria-hidden', 'true');
    iconEl.textContent = icon;
    spanEl.appendChild(iconEl);
    spanEl.appendChild(document.createTextNode(` ${parsed.label}`));
    line.appendChild(spanEl);
    tooltip.appendChild(line);
  }

  return tooltip;
}

/**
 * Build faction dots for an option — one per ADD_REPUTATION effect (T067).
 * Shows all faction impacts (positive and negative) so the player sees full trade-offs.
 * Returns a container span with 1-N dots, or null if no reputation effects.
 */
function buildFactionDot(option: CardOption): HTMLElement | null {
  const dots: HTMLElement[] = [];
  for (const eff of option.effects) {
    const parts = (eff as string).split(':');
    if (parts[0] === 'ADD_REPUTATION' && parts[1]) {
      const delta = Number(parts[2] ?? 0);
      const dot = document.createElement('span');
      dot.className = 'faction-dot';
      dot.setAttribute('role', 'img');
      dot.style.backgroundColor = getFactionColour(parts[1]);
      // Negative delta: dimmed + dashed border so the player notices the cost
      if (delta < 0) {
        dot.style.opacity = '0.55';
        dot.style.outline = '1px dashed rgba(255,80,80,0.7)';
      }
      const dotLabel = `${parts[1]}${delta !== 0 ? ` (${delta > 0 ? '+' : ''}${delta})` : ''}`;
      dot.title = dotLabel;
      dot.setAttribute('aria-label', dotLabel);
      dots.push(dot);
    }
  }
  if (dots.length === 0) return null;
  if (dots.length === 1) return dots[0] ?? null;
  // Multiple factions: wrap in a labelled group for screen readers (WCAG 1.3.1)
  const container = document.createElement('span');
  container.setAttribute('role', 'group');
  container.setAttribute('aria-label', 'Impacts de faction');
  container.style.cssText = 'display:inline-flex;gap:2px;align-items:center;';
  dots.forEach((d) => container.appendChild(d));
  return container;
}

// ── Typewriter animation ───────────────────────────────────────────────────

interface TypewriterHandle {
  skip: () => void;
}

/**
 * Animate `text` into `el` one character at a time at `msPerChar` ms/char.
 * Returns a handle whose `skip()` jumps immediately to the full text.
 * `onComplete` is called once — either when the animation finishes naturally
 * or when skip() is called.
 */
function typewriterText(
  el: HTMLElement,
  text: string,
  msPerChar: number,
  onComplete?: () => void,
): TypewriterHandle {
  let i = 0;
  el.textContent = '';
  const interval = setInterval(() => {
    i++;
    el.textContent = text.slice(0, i);
    if (i >= text.length) {
      clearInterval(interval);
      onComplete?.();
    }
  }, msPerChar);
  return {
    skip: () => {
      clearInterval(interval);
      el.textContent = text;
      onComplete?.();
    },
  };
}

// C224/TW-01: module-level typewriter handle so hideCard() can cancel an
// in-progress animation when the overlay is dismissed externally (scene
// transition, safety timeout). Without this, the setInterval keeps firing on
// a detached narrativeEl, retaining the Card closure until the interval ends.
let _activeTypewriter: TypewriterHandle | null = null;

// ── C360: Holographic rune watermark ─────────────────────────────────────────
// Module-level map: card element → RAF id for the pulse/rotation loop.
// Keyed by element reference so teardown can cancel without a separate id field.
const _runeRafMap = new WeakMap<HTMLElement, number>();
// Counter for unique watermark element ids
let _runeCounter = 0;

/** Inject the .rune-watermark style block once into <head>. */
function ensureRuneWatermarkStyle(): void {
  if (document.getElementById('rune-watermark-style')) return;
  const style = document.createElement('style');
  style.id = 'rune-watermark-style';
  style.textContent = `
    .rune-watermark { transition: opacity 0.8s ease; }
  `;
  document.head.appendChild(style);
}

/**
 * Create and inject a rotating/pulsing SVG triquetra watermark inside `cardEl`.
 * @param cardEl   The card container element (must have position:relative or similar).
 * @param oghamId  Optional ogham name — its Unicode glyph is rendered in the SVG center.
 */
function injectRuneWatermark(cardEl: HTMLElement, oghamId?: string): void {
  ensureRuneWatermarkStyle();

  // Remove any stale watermark first (idempotent)
  teardownRuneWatermark(cardEl);

  const id = `rune-watermark-${_runeCounter++}`;

  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.id = id;
  svg.classList.add('rune-watermark');
  svg.setAttribute('viewBox', '0 0 80 80');
  svg.setAttribute('xmlns', ns);
  svg.setAttribute('aria-hidden', 'true');
  svg.style.cssText = [
    'position:absolute',
    'top:50%',
    'left:50%',
    'transform:translate(-50%,-50%)',
    'width:80px',
    'height:80px',
    'pointer-events:none',
    'z-index:0',
    'opacity:0.06',
  ].join(';');

  // Triquetra approximation — three-lobed Celtic knot using cubic bezier arcs
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('d', [
    'M 40,20 C 55,5 75,15 70,30 C 65,45 50,45 40,40 C 30,45 15,45 10,30 C 5,15 25,5 40,20 Z',
    'M 40,20 C 40,35 55,55 65,58 C 75,61 80,48 70,38 C 60,28 48,32 40,40',
    'M 40,20 C 40,35 25,55 15,58 C 5,61 0,48 10,38 C 20,28 32,32 40,40',
  ].join(' '));
  path.setAttribute('stroke', '#33ff66');
  path.setAttribute('stroke-width', '1.5');
  path.setAttribute('fill', 'none');
  svg.appendChild(path);

  // Ogham letter in center — only when a known glyph is available
  if (oghamId) {
    const glyph = OGHAM_GLYPHS[oghamId];
    if (glyph) {
      const text = document.createElementNS(ns, 'text');
      text.setAttribute('x', '40');
      text.setAttribute('y', '44');
      text.setAttribute('text-anchor', 'middle');
      text.setAttribute('dominant-baseline', 'middle');
      text.setAttribute('font-size', '10');
      text.setAttribute('fill', '#33ff66');
      text.setAttribute('opacity', '0.5');
      text.textContent = glyph;
      svg.appendChild(text);
    }
  }

  cardEl.appendChild(svg);

  // Animation state — captured in RAF closure
  let angle = 0;
  let startTime: number | null = null;

  function animFrame(now: number): void {
    if (startTime === null) startTime = now;
    const elapsed = (now - startTime) / 1000; // seconds

    // Rotation: full 360° every 15 seconds
    angle = ((elapsed / 15) * 360) % 360;
    // Opacity pulse: 0.04 → 0.10 → 0.04 (period ~15.7s)
    const opacity = 0.06 + Math.sin(elapsed * 0.4) * 0.03;

    svg.style.transform = `translate(-50%,-50%) rotate(${angle}deg)`;
    svg.style.opacity = String(Math.max(0.04, Math.min(0.10, opacity)));

    const rafId = requestAnimationFrame(animFrame);
    _runeRafMap.set(cardEl, rafId);
  }

  const initialRafId = requestAnimationFrame(animFrame);
  _runeRafMap.set(cardEl, initialRafId);
}

/**
 * Flash the rune watermark to 0.25 opacity, then fade back over 800ms.
 * Uses the CSS transition already set on .rune-watermark.
 */
function flashRuneWatermark(cardEl: HTMLElement): void {
  const svg = cardEl.querySelector<SVGElement>('.rune-watermark');
  if (!svg) return;
  svg.style.opacity = '0.25';
  // After one frame, let the CSS transition take it back to the animated baseline.
  // We restore to the mid-range idle opacity (0.07); the RAF loop will resume smoothly.
  setTimeout(() => {
    svg.style.opacity = '0.07';
  }, 800);
}

/** Cancel the RAF loop and remove the SVG element from `cardEl`. */
function teardownRuneWatermark(cardEl: HTMLElement): void {
  const rafId = _runeRafMap.get(cardEl);
  if (rafId !== undefined) {
    cancelAnimationFrame(rafId);
    _runeRafMap.delete(cardEl);
  }
  const existing = cardEl.querySelector('.rune-watermark');
  if (existing) existing.remove();
}

// ── T047: Card flip animation ──────────────────────────────────────────────

// C126/FLIP-01: module-level timeout ID so rapid showCard() calls cancel the previous
// cleanup timeout before queuing a new one. Without this, N rapid calls queue N timeouts
// that each try to remove 'card-flip' from an already-updated/hidden container.
let flipTimeoutId = 0;

// C152/CO-01: module-level refs so hideCard() can clean up regardless of call path.
// Without these, any external hideCard() call (scene transition, future skip-card control)
// leaves onDigitKey + per-button keydown handlers live on detached nodes indefinitely.
// The safety timeout at 60s would clean them up, but that is not a substitute.
let _activeDigitKeyHandler: ((e: KeyboardEvent) => void) | null = null;
let _activeKeyDownHandlers: Array<{ btn: HTMLElement; handler: (e: KeyboardEvent) => void }> = [];
let _activeCardSafetyId: ReturnType<typeof setTimeout> | number = 0;

/** T047: Trigger card-flip CSS animation on the card container (0.4s rotateY). */
function triggerFlipAnimation(): void {
  const container = cardContainer();
  if (!container) return;
  // Remove class first in case it is already present from a previous card
  container.classList.remove('card-flip');
  // Force reflow so the browser registers the removal before re-adding
  void container.offsetWidth;
  container.classList.add('card-flip');
  // C126/FLIP-01: cancel any pending cleanup from previous flip before scheduling new one
  clearTimeout(flipTimeoutId);
  flipTimeoutId = window.setTimeout(() => { container.classList.remove('card-flip'); }, 420);
}

// ── Public API ─────────────────────────────────────────────────────────────

// C142/COLL: optional reveal flag — coll ogham (reveal_all_options) makes effects persistently visible
export function showCard(card: Card, opts?: { revealEffects?: boolean }): Promise<number> {
  ensureCardOverlayEnterStyles();
  ensureCardFlipStyles();
  ensureCardSelectStyle();
  ensureCardBadgeStyles();
  ensureCardOptBadgeStyles();
  ensureCardOptAnimStyles();
  return new Promise((resolve) => {
    // C165/CO-01: purge any stale handlers from a previous showCard() that was interrupted
    // (e.g. scene teardown, rapid card transitions). Without this cleanup, the old
    // onDigitKey handler stays registered on document and fires on the new card's input.
    if (_activeCardSafetyId) { clearTimeout(_activeCardSafetyId as number); _activeCardSafetyId = 0; }
    if (_activeDigitKeyHandler !== null) {
      document.removeEventListener('keydown', _activeDigitKeyHandler);
      _activeDigitKeyHandler = null;
    }
    for (const { btn, handler } of _activeKeyDownHandlers) btn.removeEventListener('keydown', handler);
    _activeKeyDownHandlers = [];

    // One-shot guard: prevents a second option click during the 200ms gold-highlight
    // animation from calling hideCard()+resolve() a second time (resolve is a no-op
    // after first call, but hideCard() and classList mutations would still fire).
    let activated = false;

    // C79-02: runtime guard against empty options array — a Groq response can parse
    // as valid JSON with options:[] (bypassing the emergency-catch in main.ts) despite
    // the tuple type. Cast to readonly array to suppress the TS tuple-length overlap error.
    if (!(card.options as readonly CardOption[]).length) { hideCard(); resolve(0); return; }

    // C122/CARD-KB-01: document-level 1/2/3 digit shortcuts — direct option selection
    // without Tab navigation. Declared here (let + definite-assignment !) so the safety
    // timeout callback can reference it for cleanup before the assignment runs below.
    // eslint-disable-next-line prefer-const
    let onDigitKey!: (e: KeyboardEvent) => void;

    // C123/CARD-LEAK-01: per-button keydown handler refs — needed so safety timeout can
    // remove them from detached DOM nodes (innerHTML='' discards nodes but not their listeners
    // until GC; on mobile/low-memory these closures retain the whole Card object for 60s).
    const keyDownHandlers: Array<{ btn: HTMLElement; handler: (e: KeyboardEvent) => void }> = [];

    // 60s safety timeout — last-resort escape if all button paths somehow become
    // unreachable (e.g. DOM mutation by an extension, tab hidden on mobile).
    const safetyId = setTimeout(() => {
      if (!activated) {
        activated = true;
        document.removeEventListener('keydown', onDigitKey);
        // C123/CARD-LEAK-01: remove per-button keydown handlers before discarding nodes
        for (const { btn, handler } of keyDownHandlers) btn.removeEventListener('keydown', handler);
        hideCard();
        resolve(0);
      }
    }, 60_000);
    // C152/CO-01: track safety timer at module level so external hideCard() can cancel it
    _activeCardSafetyId = safetyId;

    // Null-guard DOM elements — consistent with HUD pattern (C57)
    const overlayEl = document.getElementById('card-overlay');
    const narrativeEl = document.getElementById('card-text');
    const optContainer = document.getElementById('card-options');
    if (!overlayEl || !narrativeEl || !optContainer) { clearTimeout(safetyId); resolve(0); return; }

    // C79-03: ARIA dialog semantics — screen readers announce the card as a modal dialog
    overlayEl.setAttribute('role', 'dialog');
    overlayEl.setAttribute('aria-modal', 'true');
    overlayEl.setAttribute('aria-label', 'Choix narratif');

    // C153/CO-03: capture cardContainer() once — was called 3× as live DOM queries here.
    // Three separate querySelector('.card-container') traversals per showCard() is wasteful
    // on the hot path (called every card). Capture once; null-guard on the outer block suffices.
    const container = cardContainer();

    // Biome badge + faction badge (T067)
    const existingBadge = container?.querySelector('.card-biome-badge');
    if (existingBadge) existingBadge.remove();
    const existingFactionBadge = container?.querySelector('.card-faction-badge');
    if (existingFactionBadge) existingFactionBadge.remove();
    const dividerEl = container?.querySelector('.card-divider');
    if (dividerEl) dividerEl.remove();
    // Remove stale flavor text from previous card
    const existingFlavor = container?.querySelector('.card-flavor');
    if (existingFlavor) existingFlavor.remove();

    // C300: faction key resolved here so both the container block and the
    // options loop below can share it without redundant DOM access.
    const faction: string | undefined = ((card as unknown) as Record<string, unknown>).faction as string | undefined;
    const factionKey = (faction ?? 'central').toLowerCase();

    if (container) {
      const badge = document.createElement('div');
      badge.className = 'card-biome-badge';
      // LLM source indicator: ✦ prefix for Groq-generated cards
      const sourceGlyph = card.source === 'llm' ? '✦ ' : '';
      badge.textContent = sourceGlyph + card.biome.replace(/_/g, ' ');
      if (card.source === 'llm') badge.title = 'Carte générée par Merlin (Groq)';
      container.insertBefore(badge, container.firstChild);

      // Faction badge — defensive access (faction not in Card interface)
      if (faction) {
        const factionColour = getFactionColour(faction);
        const fBadge = document.createElement('span');
        fBadge.className = 'card-faction-badge';
        fBadge.textContent = faction.charAt(0).toUpperCase();
        fBadge.title = faction;
        fBadge.setAttribute('aria-label', `Faction: ${faction}`);
        fBadge.style.borderColor = factionColour;
        fBadge.style.color = factionColour;
        badge.appendChild(fBadge);
      }

      // C244: faction-tinted glow on the main card panel
      const factionGlow = FACTION_GLOW[factionKey] ?? FACTION_GLOW['central'] as string;
      container.style.boxShadow = `0 0 18px ${factionGlow}, inset 0 0 6px ${factionGlow}`;

      // C244: faction title-colour tint on the biome badge (card header)
      badge.style.color = FACTION_TITLE_COLOUR[factionKey] ?? FACTION_TITLE_COLOUR['central'] as string;

      const divider = document.createElement('div');
      divider.className = 'card-divider';
      // Insert divider before narrative
      const narrativeEl = container.querySelector('.card-narrative');
      if (narrativeEl) container.insertBefore(divider, narrativeEl);

      // Flavor text — defensive access (flavor/lore not in Card interface)
      const cardAny = card as unknown as Record<string, unknown>;
      const flavor: string | undefined =
        (cardAny.flavor as string | undefined) ??
        (cardAny.lore as string | undefined);
      if (flavor) {
        const flavorEl = document.createElement('p');
        flavorEl.className = 'card-flavor';
        flavorEl.textContent = flavor;
        // Insert after narrative element (or append to container as fallback)
        const narrativeNode = container.querySelector('.card-narrative');
        if (narrativeNode && narrativeNode.nextSibling) {
          container.insertBefore(flavorEl, narrativeNode.nextSibling);
        } else if (narrativeNode) {
          container.appendChild(flavorEl);
        }
      }
    }

    // C360: inject holographic rune watermark on the card panel
    if (container) {
      // Pick ogham id from the first option that has an ACTIVATE_OGHAM effect, if any
      let cardOghamId: string | undefined;
      for (const opt of card.options) {
        for (const eff of opt.effects) {
          const s = eff as string;
          if (s.startsWith('ACTIVATE_OGHAM:')) {
            cardOghamId = s.split(':')[1];
            break;
          }
        }
        if (cardOghamId) break;
      }
      injectRuneWatermark(container, cardOghamId);
    }

    // Options (T067 + T068) — optContainer already resolved above
    optContainer.innerHTML = '';

    // C232: single flip sfx when the overlay opens (not per-option)
    sfx('flip');

    card.options.forEach((option, index) => {
      const btn = document.createElement('div');
      btn.className = 'card-option card-opt-animate';
      const delays = ['0ms', '80ms', '160ms'] as const;
      btn.style.animationDelay = delays[index] ?? '160ms';
      btn.setAttribute('role', 'button');
      btn.setAttribute('tabindex', '0');
      btn.setAttribute('aria-label', `${option.verb} — ${option.text}`);
      // Required so absolutely-positioned .card-opt-num and .card-opt-ogham are anchored here
      btn.style.position = 'relative';

      // C300: faction SVG background pattern — subtle decorative tile on card back
      btn.style.backgroundImage = getFactionPattern(factionKey);
      btn.style.backgroundSize = '20px 20px';
      btn.style.backgroundRepeat = 'repeat';

      // Number badge (top-left corner)
      const numBadge = document.createElement('span');
      numBadge.className = 'card-opt-num';
      numBadge.setAttribute('aria-hidden', 'true');
      numBadge.textContent = String(index + 1);
      btn.appendChild(numBadge);

      // Ogham glyph badge (top-right corner) — shown only when ACTIVATE_OGHAM effect present
      const oghamGlyph = extractOghamGlyph(option);
      if (oghamGlyph !== null) {
        const oghamBadge = document.createElement('span');
        oghamBadge.className = 'card-opt-ogham';
        oghamBadge.setAttribute('aria-hidden', 'true');
        oghamBadge.textContent = oghamGlyph;
        btn.appendChild(oghamBadge);
      }

      // Faction dot (T067)
      const dot = buildFactionDot(option);
      const verbEl = document.createElement('div');
      verbEl.className = 'verb';
      if (dot) verbEl.appendChild(dot);
      verbEl.appendChild(document.createTextNode(option.verb));

      const descEl = document.createElement('div');
      descEl.className = 'desc';
      descEl.textContent = option.text;

      btn.appendChild(verbEl);
      btn.appendChild(descEl);

      // Effect tooltip (T068) — C142/COLL: add effects-revealed class when coll ogham active
      const tooltip = buildEffectTooltip(option);
      if (tooltip) {
        if (opts?.revealEffects) btn.classList.add('effects-revealed');
        btn.appendChild(tooltip);
      }

      btn.addEventListener('pointerenter', () => sfx('hover'));

      const activate = async (): Promise<void> => {
        sfx('click');
        if (activated) return;
        activated = true;
        clearTimeout(safetyId);
        document.removeEventListener('keydown', onDigitKey); // C122: cleanup digit shortcut handler
        // T073: Brief gold highlight before overlay hides (200ms feedback)
        btn.classList.add('card-option-selected');
        // C179: verb-select flash animation before hiding
        btn.classList.add('selected');
        // C360: flash the rune watermark on selection
        if (container) flashRuneWatermark(container);
        await new Promise<void>(r => setTimeout(r, 120)); // brief flash
        hideCard();
        resolve(index);
      };

      btn.addEventListener('click', activate, { once: true });
      // Keyboard activation: Enter and Space — WCAG 2.1.1
      // C85: named handler so it can self-remove on activation, preventing a closure
      // leak when hideCard() is called externally (safety timeout) without clearing
      // optContainer. The click handler uses { once: true }; keydown needs manual removal.
      const onKeyDown = (e: KeyboardEvent): void => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          btn.removeEventListener('keydown', onKeyDown);
          activate();
        }
      };
      btn.addEventListener('keydown', onKeyDown);
      // C123/CARD-LEAK-01: store handler ref so safety timeout can remove it from detached node
      keyDownHandlers.push({ btn, handler: onKeyDown });

      optContainer.appendChild(btn);
    });

    // Keyboard shortcut hint below options
    const kbHint = document.createElement('div');
    kbHint.style.cssText = [
      'text-align:center;margin-top:8px;',
      'color:rgba(51,255,102,0.28);font-size:10px;letter-spacing:0.12em;',
      'pointer-events:none;font-family:Courier New,monospace;',
    ].join('');
    kbHint.setAttribute('aria-hidden', 'true');
    kbHint.textContent = '[ 1 ]  [ 2 ]  [ 3 ]';
    optContainer.appendChild(kbHint);

    // C122/CARD-KB-01: assign digit handler now that optContainer is confirmed non-null.
    // Fires on document so any focused element (not just options) can trigger it.
    // Self-removes on first valid keypress; also removed by activate() and the safety timeout.
    onDigitKey = (e: KeyboardEvent): void => {
      if (activated) { document.removeEventListener('keydown', onDigitKey); return; }
      const idx = ['1', '2', '3'].indexOf(e.key);
      if (idx === -1 || idx >= card.options.length) return;
      e.preventDefault();
      // C224/TW: if typewriter is running, skip it first so the user sees the
      // full text and the options become visible before the option activates.
      if (_activeTypewriter !== null) {
        _activeTypewriter.skip();
        _activeTypewriter = null;
        // The skip() call triggers onComplete → revealOptions(). Give one frame
        // for the DOM to update (opacity transition) before activating.
        requestAnimationFrame(() => {
          document.removeEventListener('keydown', onDigitKey);
          const btns = optContainer.querySelectorAll<HTMLElement>('[role="button"]');
          const targetBtn = btns[idx];
          if (!targetBtn || activated) return;
          sfx('click');
          activated = true;
          clearTimeout(safetyId);
          targetBtn.classList.add('card-option-selected');
          targetBtn.classList.add('selected');
          setTimeout(() => { hideCard(); resolve(idx); }, 200);
        });
        return;
      }
      document.removeEventListener('keydown', onDigitKey);
      const btns = optContainer.querySelectorAll<HTMLElement>('[role="button"]');
      const targetBtn = btns[idx];
      if (!targetBtn) return;
      sfx('click');
      activated = true;
      clearTimeout(safetyId);
      targetBtn.classList.add('card-option-selected');
      targetBtn.classList.add('selected');
      setTimeout(() => { hideCard(); resolve(idx); }, 200);
    };
    // C152/CO-01: expose to module scope so hideCard() can remove regardless of call path
    _activeDigitKeyHandler = onDigitKey;
    _activeKeyDownHandlers = keyDownHandlers;
    document.addEventListener('keydown', onDigitKey);

    // C86/C123: Make overlay visible FIRST, then set narrative text so NVDA/JAWS
    // re-announces in context of the dialog. Setting textContent while the overlay is
    // hidden (display:none or opacity:0) causes older screen readers to skip the
    // live-region update since the element is not in the accessibility tree yet.
    overlayEl.classList.add('visible');

    // C315: draw whoosh entrance — overlay slides in from top with scale
    overlayEl.classList.remove('card-overlay-enter');
    void overlayEl.offsetWidth; // force reflow to restart animation
    overlayEl.classList.add('card-overlay-enter');
    sfx('whoosh');
    spawnCardSparks(overlayEl);

    // Play flip animation each time a new card is shown
    triggerFlipAnimation();
    // C261: 3D perspective flip-reveal on the main card panel
    if (container) {
      container.classList.remove('card-flip-reveal');
      void container.offsetWidth; // force reflow to restart animation
      container.classList.add('card-flip-reveal');
    }

    // C224/TW: cancel any previous typewriter from a rapid showCard() call
    if (_activeTypewriter !== null) {
      _activeTypewriter.skip();
      _activeTypewriter = null;
    }

    // C224/TW: Hide options until typewriter completes (or skip).
    // Opacity+pointer-events keeps options in the DOM (so keyboard shortcuts
    // don't error on missing nodes) while preventing premature interaction.
    optContainer.style.opacity = '0';
    optContainer.style.pointerEvents = 'none';

    /** Reveal options and transfer focus to the first button. */
    const revealOptions = (): void => {
      optContainer.style.transition = 'opacity 0.3s';
      optContainer.style.opacity = '1';
      optContainer.style.pointerEvents = '';
      requestAnimationFrame(() => {
        const first = optContainer.querySelector<HTMLElement>('[role="button"]');
        if (first) first.focus();
      });
    };

    // C224/TW: Click/tap anywhere on the card container skips the typewriter.
    // The listener is { once: true } so it self-removes after first interaction.
    const skipHandler = (): void => {
      if (_activeTypewriter !== null) {
        _activeTypewriter.skip();
        _activeTypewriter = null;
      }
    };
    if (container) {
      container.addEventListener('click', skipHandler, { once: true });
    }

    // C224/TW: Start typewriter — 18ms/char ≈ 2-3s for a 120-char narrative.
    // onComplete removes the skip click-listener (it already fired or is no
    // longer needed) and reveals options.
    _activeTypewriter = typewriterText(
      narrativeEl,
      card.narrative,
      18,
      () => {
        _activeTypewriter = null;
        if (container) container.removeEventListener('click', skipHandler);
        revealOptions();
      },
    );
  });
}

export function hideCard(): void {
  // C152/CO-01: clean up active card event listeners regardless of call path.
  // removeEventListener is idempotent — safe even if already cleaned by activate() or safetyId.
  if (_activeDigitKeyHandler !== null) {
    document.removeEventListener('keydown', _activeDigitKeyHandler);
    _activeDigitKeyHandler = null;
  }
  for (const { btn, handler } of _activeKeyDownHandlers) btn.removeEventListener('keydown', handler);
  _activeKeyDownHandlers = [];
  clearTimeout(_activeCardSafetyId);
  // C224/TW-01: cancel in-progress typewriter so its setInterval doesn't keep
  // firing on a detached element after the overlay is hidden.
  if (_activeTypewriter !== null) {
    _activeTypewriter.skip();
    _activeTypewriter = null;
  }
  // C224/TW: reset option container visibility for the next card show
  const optContainer = document.getElementById('card-options');
  if (optContainer) {
    optContainer.style.opacity = '';
    optContainer.style.pointerEvents = '';
    optContainer.style.transition = '';
  }
  // C360: teardown rune watermark RAF and SVG element
  const containerEl = cardContainer();
  if (containerEl) teardownRuneWatermark(containerEl);

  const overlayEl = document.getElementById('card-overlay');
  if (overlayEl) overlayEl.classList.remove('visible');
}

// ── C331: Decision timer arc ───────────────────────────────────────────────
// A canvas-based countdown arc drawn clockwise from the top of the card overlay.
// Colors: normal  rgba(51,255,102,0.6) | urgent (>80% depleted) rgba(255,60,60,0.7)
// The background ring stays at rgba(51,255,102,0.1) throughout.

const TIMER_CANVAS_ID = 'card-timer-arc';
const TIMER_CANVAS_SIZE = 360;
const TIMER_RADIUS = 170;
const TIMER_CENTER = TIMER_CANVAS_SIZE / 2; // 180

// Module-level RAF handle so stopDecisionTimer() can cancel inflight animation.
let _timerRafId: number = 0;

/**
 * Start a circular countdown arc around the card overlay.
 * Idempotent: if a canvas already exists the call is a no-op.
 *
 * @param durationMs  Total countdown duration in milliseconds.
 * @param onExpire    Optional callback invoked when the timer completes.
 */
export function startDecisionTimer(durationMs: number, onExpire?: () => void): void {
  // Idempotent guard
  if (document.getElementById(TIMER_CANVAS_ID)) return;

  const overlay = document.getElementById('card-overlay');
  if (!overlay) return;

  const canvas = document.createElement('canvas');
  canvas.id = TIMER_CANVAS_ID;
  canvas.width = TIMER_CANVAS_SIZE;
  canvas.height = TIMER_CANVAS_SIZE;
  canvas.style.cssText = [
    'position:absolute',
    `width:${TIMER_CANVAS_SIZE}px`,
    `height:${TIMER_CANVAS_SIZE}px`,
    `top:50%`,
    `left:50%`,
    `transform:translate(-50%,-50%)`,
    'pointer-events:none',
    'z-index:100',
  ].join(';');

  // The overlay needs to be a positioning parent
  const prevPosition = overlay.style.position;
  if (!prevPosition || prevPosition === 'static') {
    overlay.style.position = 'relative';
  }
  overlay.appendChild(canvas);

  const ctx = canvas.getContext('2d');
  if (!ctx) { canvas.remove(); return; }

  const startTime = performance.now();

  function drawFrame(now: number): void {
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / durationMs, 1); // 0 → 1

    ctx!.clearRect(0, 0, TIMER_CANVAS_SIZE, TIMER_CANVAS_SIZE);

    // Background ring — always visible, dim full circle
    ctx!.beginPath();
    ctx!.arc(TIMER_CENTER, TIMER_CENTER, TIMER_RADIUS, 0, 2 * Math.PI);
    ctx!.strokeStyle = 'rgba(51,255,102,0.1)';
    ctx!.lineWidth = 3;
    ctx!.lineCap = 'round';
    ctx!.stroke();

    // Remaining arc: from -π/2 to -π/2 + (1 - progress) * 2π (clockwise depletion)
    const remaining = 1 - progress;
    const startAngle = -Math.PI / 2;
    const endAngle = startAngle + remaining * 2 * Math.PI;

    if (remaining > 0) {
      // Urgent when more than 80% depleted (remaining < 0.2)
      const urgent = remaining < 0.2;
      ctx!.beginPath();
      ctx!.arc(TIMER_CENTER, TIMER_CENTER, TIMER_RADIUS, startAngle, endAngle);
      ctx!.strokeStyle = urgent ? 'rgba(255,60,60,0.7)' : 'rgba(51,255,102,0.6)';
      ctx!.lineWidth = 3;
      ctx!.lineCap = 'round';
      ctx!.stroke();

      // Shake offset in urgent phase: canvas drifts by ±2px along X using sin
      if (urgent) {
        const shakeX = Math.sin(now * 0.03) * 2; // ~sin(t*30) in seconds
        canvas.style.transform = `translate(calc(-50% + ${shakeX}px), -50%)`;
      } else {
        canvas.style.transform = 'translate(-50%, -50%)';
      }
    }

    if (progress >= 1) {
      // Timer complete
      canvas.remove();
      _timerRafId = 0;
      onExpire?.();
      return;
    }

    _timerRafId = requestAnimationFrame(drawFrame);
  }

  _timerRafId = requestAnimationFrame(drawFrame);
}

/**
 * Cancel the decision timer and remove its canvas immediately.
 * Safe to call even if no timer is running.
 */
export function stopDecisionTimer(): void {
  if (_timerRafId !== 0) {
    cancelAnimationFrame(_timerRafId);
    _timerRafId = 0;
  }
  const canvas = document.getElementById(TIMER_CANVAS_ID);
  if (canvas) canvas.remove();
}
