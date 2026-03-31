// ═══════════════════════════════════════════════════════════════════════════════
// Card Overlay — Displays narrative card with 3 options
// T067: Dark parchment card design with Celtic border, gold typography
// T068: Effect preview tooltip on hover
// ═══════════════════════════════════════════════════════════════════════════════

import type { Card, CardOption } from '../game/CardSystem';

const overlay = () => document.getElementById('card-overlay')!;
const textEl = () => document.getElementById('card-text')!;
const optionsEl = () => document.getElementById('card-options')!;
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
 * Build the primary faction dot for an option based on its first
 * ADD_REPUTATION effect (T067).
 */
function buildFactionDot(option: CardOption): HTMLElement | null {
  for (const eff of option.effects) {
    const parts = (eff as string).split(':');
    if (parts[0] === 'ADD_REPUTATION' && parts[1]) {
      const dot = document.createElement('span');
      dot.className = 'faction-dot';
      dot.style.backgroundColor = getFactionColour(parts[1]);
      dot.title = parts[1];
      return dot;
    }
  }
  return null;
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
    // Narrative text (T067: keep existing element, styled via CSS)
    textEl().textContent = card.narrative;

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

    // Options (T067 + T068)
    const optContainer = optionsEl();
    optContainer.innerHTML = '';

    card.options.forEach((option, index) => {
      const btn = document.createElement('div');
      btn.className = 'card-option';

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

      btn.addEventListener('click', () => {
        hideCard();
        resolve(index);
      });

      optContainer.appendChild(btn);
    });

    overlay().classList.add('visible');
    // Play flip animation each time a new card is shown
    triggerFlipAnimation();
  });
}

export function hideCard(): void {
  overlay().classList.remove('visible');
}
