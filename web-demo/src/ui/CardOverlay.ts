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

    if (container) {
      const badge = document.createElement('div');
      badge.className = 'card-biome-badge';
      // LLM source indicator: ✦ prefix for Groq-generated cards
      const sourceGlyph = card.source === 'llm' ? '✦ ' : '';
      badge.textContent = sourceGlyph + card.biome.replace(/_/g, ' ');
      if (card.source === 'llm') badge.title = 'Carte générée par Merlin (Groq)';
      container.insertBefore(badge, container.firstChild);

      // Faction badge — defensive access (faction not in Card interface)
      const faction: string | undefined = ((card as unknown) as Record<string, unknown>).faction as string | undefined;
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
      const factionKey = (faction ?? 'central').toLowerCase();
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
  const overlayEl = document.getElementById('card-overlay');
  if (overlayEl) overlayEl.classList.remove('visible');
}
