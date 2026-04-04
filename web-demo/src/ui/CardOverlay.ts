// ═══════════════════════════════════════════════════════════════════════════════
// Card Overlay — Displays narrative card with 3 options
// T067: Dark parchment card design with Celtic border, gold typography
// T068: Effect preview tooltip on hover
// ═══════════════════════════════════════════════════════════════════════════════

import type { Card, CardOption } from '../game/CardSystem';

const cardContainer = () => document.querySelector<HTMLElement>('.card-container');

// ── Faction colour map (T067) ──────────────────────────────────────────────

const FACTION_COLOURS: Record<string, string> = {
  druides:  '#6abf69',
  niamh:    '#8ab4f8',
  korrigans:'#b888e8',
  anciens:  '#e8c84c',
  ankou:    '#e05c5c',
};

function getFactionColour(faction: string): string {
  return FACTION_COLOURS[faction.toLowerCase()] ?? '#c9a84c';
}

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

// ── T047: Card flip animation ──────────────────────────────────────────────

// C126/FLIP-01: module-level timeout ID so rapid showCard() calls cancel the previous
// cleanup timeout before queuing a new one. Without this, N rapid calls queue N timeouts
// that each try to remove 'card-flip' from an already-updated/hidden container.
let flipTimeoutId = 0;

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

export function showCard(card: Card): Promise<number> {
  return new Promise((resolve) => {
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

    // Null-guard DOM elements — consistent with HUD pattern (C57)
    const overlayEl = document.getElementById('card-overlay');
    const narrativeEl = document.getElementById('card-text');
    const optContainer = document.getElementById('card-options');
    if (!overlayEl || !narrativeEl || !optContainer) { clearTimeout(safetyId); resolve(0); return; }

    // C79-03: ARIA dialog semantics — screen readers announce the card as a modal dialog
    overlayEl.setAttribute('role', 'dialog');
    overlayEl.setAttribute('aria-modal', 'true');
    overlayEl.setAttribute('aria-label', 'Choix narratif');

    // Biome badge (T067)
    const existingBadge = cardContainer()?.querySelector('.card-biome-badge');
    if (existingBadge) existingBadge.remove();
    const dividerEl = cardContainer()?.querySelector('.card-divider');
    if (dividerEl) dividerEl.remove();

    const container = cardContainer();
    if (container) {
      const badge = document.createElement('div');
      badge.className = 'card-biome-badge';
      badge.textContent = card.biome.replace(/_/g, ' ');
      container.insertBefore(badge, container.firstChild);

      const divider = document.createElement('div');
      divider.className = 'card-divider';
      // Insert divider before narrative
      const narrativeEl = container.querySelector('.card-narrative');
      if (narrativeEl) container.insertBefore(divider, narrativeEl);
    }

    // Options (T067 + T068) — optContainer already resolved above
    optContainer.innerHTML = '';

    card.options.forEach((option, index) => {
      const btn = document.createElement('div');
      btn.className = 'card-option';
      btn.setAttribute('role', 'button');
      btn.setAttribute('tabindex', '0');
      btn.setAttribute('aria-label', `${option.verb} — ${option.text}`);

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

      // Effect tooltip (T068)
      const tooltip = buildEffectTooltip(option);
      if (tooltip) btn.appendChild(tooltip);

      const activate = (): void => {
        if (activated) return;
        activated = true;
        clearTimeout(safetyId);
        document.removeEventListener('keydown', onDigitKey); // C122: cleanup digit shortcut handler
        // T073: Brief gold highlight before overlay hides (200ms feedback)
        btn.classList.add('card-option-selected');
        setTimeout(() => {
          hideCard();
          resolve(index);
        }, 200);
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

    // C122/CARD-KB-01: assign digit handler now that optContainer is confirmed non-null.
    // Fires on document so any focused element (not just options) can trigger it.
    // Self-removes on first valid keypress; also removed by activate() and the safety timeout.
    onDigitKey = (e: KeyboardEvent): void => {
      if (activated) { document.removeEventListener('keydown', onDigitKey); return; }
      const idx = ['1', '2', '3'].indexOf(e.key);
      if (idx === -1 || idx >= card.options.length) return;
      e.preventDefault();
      document.removeEventListener('keydown', onDigitKey);
      const btns = optContainer.querySelectorAll<HTMLElement>('[role="button"]');
      const targetBtn = btns[idx];
      if (!targetBtn) return;
      activated = true;
      clearTimeout(safetyId);
      targetBtn.classList.add('card-option-selected');
      setTimeout(() => { hideCard(); resolve(idx); }, 200);
    };
    document.addEventListener('keydown', onDigitKey);

    // C86/C123: Make overlay visible FIRST, then set narrative text so NVDA/JAWS
    // re-announces in context of the dialog. Setting textContent while the overlay is
    // hidden (display:none or opacity:0) causes older screen readers to skip the
    // live-region update since the element is not in the accessibility tree yet.
    overlayEl.classList.add('visible');
    narrativeEl.textContent = card.narrative;
    // Play flip animation each time a new card is shown
    triggerFlipAnimation();
    // Focus first option so keyboard users don't need to Tab from previous element
    requestAnimationFrame(() => {
      const first = optContainer.querySelector<HTMLElement>('[role="button"]');
      if (first) first.focus();
    });
  });
}

export function hideCard(): void {
  const overlayEl = document.getElementById('card-overlay');
  if (overlayEl) overlayEl.classList.remove('visible');
}
