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

    line.innerHTML = `<span class="${cls}">${icon} ${parsed.label}</span>`;
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
      dot.style.backgroundColor = getFactionColour(parts[1]);
      // Negative delta: dimmed + dashed border so the player notices the cost
      if (delta < 0) {
        dot.style.opacity = '0.55';
        dot.style.outline = '1px dashed rgba(255,80,80,0.7)';
      }
      dot.title = `${parts[1]}${delta !== 0 ? ` (${delta > 0 ? '+' : ''}${delta})` : ''}`;
      dots.push(dot);
    }
  }
  if (dots.length === 0) return null;
  if (dots.length === 1) return dots[0]!;
  // Multiple factions: wrap in a flex row
  const container = document.createElement('span');
  container.style.cssText = 'display:inline-flex;gap:2px;align-items:center;';
  dots.forEach((d) => container.appendChild(d));
  return container;
}

// ── T047: Card flip animation ──────────────────────────────────────────────

/** T047: Trigger card-flip CSS animation on the card container (0.4s rotateY). */
function triggerFlipAnimation(): void {
  const container = cardContainer();
  if (!container) return;
  // Remove class first in case it is already present from a previous card
  container.classList.remove('card-flip');
  // Force reflow so the browser registers the removal before re-adding
  void container.offsetWidth;
  container.classList.add('card-flip');
  // Clean up class after animation completes so hover/transitions are unaffected
  setTimeout(() => { container.classList.remove('card-flip'); }, 420);
}

// ── Public API ─────────────────────────────────────────────────────────────

export function showCard(card: Card): Promise<number> {
  return new Promise((resolve) => {
    // Null-guard DOM elements — consistent with HUD pattern (C57)
    const overlayEl = document.getElementById('card-overlay');
    const narrativeEl = document.getElementById('card-text');
    const optContainer = document.getElementById('card-options');
    if (!overlayEl || !narrativeEl || !optContainer) { resolve(0); return; }

    // Narrative text (T067: keep existing element, styled via CSS)
    narrativeEl.textContent = card.narrative;

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
        // T073: Brief gold highlight before overlay hides (200ms feedback)
        btn.classList.add('card-option-selected');
        setTimeout(() => {
          hideCard();
          resolve(index);
        }, 200);
      };

      btn.addEventListener('click', activate);
      // Keyboard activation: Enter and Space — WCAG 2.1.1
      btn.addEventListener('keydown', (e: KeyboardEvent) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          activate();
        }
      });

      optContainer.appendChild(btn);
    });

    overlayEl.classList.add('visible');
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
