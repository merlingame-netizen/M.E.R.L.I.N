// ═══════════════════════════════════════════════════════════════════════════════
// Card System — Card generation, FastRoute fallback, minigame selection
// ═══════════════════════════════════════════════════════════════════════════════

import { ACTION_VERBS, FIELD_MINIGAMES, MINIGAME_CATALOGUE, type FactionId } from './Constants';

// --- Card types ---

export interface CardOption {
  readonly verb: string;
  readonly text: string;
  readonly field: string;
  readonly effects: readonly string[];
}

export interface Card {
  readonly id: string;
  readonly narrative: string;
  readonly options: readonly [CardOption, CardOption, CardOption];
  readonly biome: string;
  readonly source: 'fastroute' | 'llm';
}

// --- FastRoute (hardcoded fallback cards) ---

let cardCounter = 0;

function nextCardId(): string {
  return `card_${Date.now()}_${++cardCounter}`;
}

/** Picks a random item from an array. */
function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Maps a verb to its lexical field. */
export function verbToField(verb: string): string {
  for (const [field, verbs] of Object.entries(ACTION_VERBS)) {
    if (verbs.includes(verb)) return field;
  }
  return 'esprit';
}

/** Picks a minigame appropriate for a lexical field. */
export function pickMinigame(field: string): string {
  const options = FIELD_MINIGAMES[field];
  if (!options || options.length === 0) return 'traces';
  return pick(options);
}

// --- FastRoute template loader (T043: externalized to public/data/cards.json) ---

/** Raw shape of a template as stored in cards.json. */
interface FastRouteTemplate {
  readonly narrative: string;
  readonly biome?: string; // Optional biome tag — used for biome-filtered pool selection
  readonly options: readonly [
    { readonly verb: string; readonly text: string; readonly effects: readonly string[] },
    { readonly verb: string; readonly text: string; readonly effects: readonly string[] },
    { readonly verb: string; readonly text: string; readonly effects: readonly string[] },
  ];
}

/** In-memory cache populated by loadTemplates(). */
let _templates: FastRouteTemplate[] | null = null;

/** Ring buffer tracking the last 3 templates used — prevents consecutive repeats. */
const _recentTemplates: FastRouteTemplate[] = [];
const RECENT_CARD_BUFFER = 3;

/**
 * Fetch and cache the card templates from /data/cards.json.
 * Must be awaited before generateFastRouteCard() is called.
 * Safe to call multiple times — fetches only once.
 */
export async function loadTemplates(): Promise<void> {
  if (_templates !== null) return;
  try {
    const res = await fetch('/data/cards.json');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json() as FastRouteTemplate[];
    if (!Array.isArray(data) || data.length === 0) throw new Error('Empty or invalid cards.json');
    _templates = data;
  } catch (err) {
    // Silent failure: FastRoute pool will be empty, EMERGENCY_TEMPLATE provides fallback.
    // No console.warn — production build must not leak internal paths to browser devtools.
    void err;
    _templates = [];
  }
}

// ── REMOVED: inline FASTROUTE_TEMPLATES array (186 templates, ~130KB) ──
// ── Templates are now loaded from public/data/cards.json at startup.   ──
// ── See loadTemplates() above and main.ts bootstrap sequence.           ──

/** Emergency fallback card used when template pool is empty (loadTemplates not yet called). */
const EMERGENCY_TEMPLATE: FastRouteTemplate = {
  narrative: 'Le brouillard se leve, revelant un sentier paisible devant toi.',
  options: [
    { verb: 'observer', text: 'Tu observes les alentours calmement.', effects: ['HEAL_LIFE:3'] },
    { verb: 'avancer', text: 'Tu poursuis ta route avec prudence.', effects: ['ADD_ANAM:2'] },
    { verb: 'attendre', text: 'Tu fais une pause pour reprendre tes forces.', effects: ['HEAL_LIFE:2'] },
  ],
};

/** Generate a card using FastRoute (templates loaded from /data/cards.json). */
export function generateFastRouteCard(biome: string): Card {
  const allTemplates = _templates !== null && _templates.length > 0 ? _templates : [EMERGENCY_TEMPLATE];

  // BUG-1 fix: prefer biome-tagged pool; fallback to full pool when < 3 tagged cards available
  const biomePool = allTemplates.filter(t => t.biome === biome);
  const pool = biomePool.length >= 3 ? biomePool : allTemplates;

  // BUG-2 fix: avoid the last RECENT_CARD_BUFFER templates (prevents consecutive repeats,
  // critical when biome pool narrows to ~20 cards — 78% repeat chance over 30 cards without this)
  const available = pool.filter(t => !_recentTemplates.includes(t));
  const candidates = available.length >= 1 ? available : pool; // fallback if pool is tiny
  const template = pick(candidates);

  // Update ring buffer (FIFO, max 3 entries)
  _recentTemplates.push(template);
  if (_recentTemplates.length > RECENT_CARD_BUFFER) _recentTemplates.shift();
  // C134/CS-01: runtime guard — TypeScript 3-tuple enforcement on FastRouteTemplate.options
  // only applies to static/typed data. cards.json is runtime data: a template with !=3 options
  // produces card.options[2] === undefined, crashing the UI on option render. Fall back to
  // EMERGENCY_TEMPLATE so the run continues without a crash.
  const safeTemplate = template.options.length === 3 ? template : EMERGENCY_TEMPLATE;
  const options = safeTemplate.options.map((opt) => ({
    verb: opt.verb,
    text: opt.text,
    field: verbToField(opt.verb),
    effects: opt.effects,
  })) as unknown as [CardOption, CardOption, CardOption];

  return {
    id: nextCardId(),
    narrative: safeTemplate.narrative, // C140/BUG-C140-03: use safeTemplate narrative (was template — showed malformed card's text with emergency options)
    options,
    biome,
    source: 'fastroute',
  };
}

/** Detect which minigame to play based on the chosen option's field. */
export function detectMinigame(card: Card, chosenOption: number): string {
  const option = card.options[chosenOption];
  if (!option) return 'traces';
  return pickMinigame(option.field);
}
