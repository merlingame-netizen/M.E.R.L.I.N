// =============================================================================
// HUD -- Life bar, faction bars, anam counter, biome currency, cards count
// =============================================================================

import { store } from '../game/Store';
import { LIFE_MAX, BIOMES, FACTIONS, OGHAM_SPECS, type FactionId } from '../game/Constants';

// --- Faction display config (immutable) ---
const FACTION_COLORS: Readonly<Record<FactionId, string>> = {
  druides: '#6abf69',
  anciens: '#e8c84c',
  korrigans: '#b888e8',
  niamh: '#8ab4f8',
  ankou: '#e05c5c',
} as const;

const FACTION_LABELS: Readonly<Record<FactionId, string>> = {
  druides: 'Druides',
  anciens: 'Anciens',
  korrigans: 'Korrigans',
  niamh: 'Niamh',
  ankou: 'Ankou',
} as const;

// DOM element accessors are resolved inside updateHUD() with null guards
// (consistent with faction/resource/ogham elements below — no ! assertions)

// Module-level unsubscribe handle — prevents duplicate Zustand subscriber accumulation
// when initHUD() is called on every run inside the outer while(true) loop (main.ts).
let _hudUnsubscribe: (() => void) | null = null;

/** Build the faction panel DOM and inject it into the HUD. */
function buildFactionPanel(): void {
  const hud = document.getElementById('hud');
  if (!hud || document.getElementById('faction-panel')) return;

  const panel = document.createElement('div');
  panel.id = 'faction-panel';
  panel.style.cssText = [
    'position:absolute',
    'top:60px',
    'left:16px',
    'display:flex',
    'flex-direction:column',
    'gap:4px',
    'pointer-events:none',
    'z-index:10',
  ].join(';');

  for (const faction of FACTIONS) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;align-items:center;gap:6px;';

    const label = document.createElement('span');
    label.style.cssText = 'color:rgba(232,220,200,0.6);font-size:11px;font-family:system-ui;width:60px;text-align:right;';
    label.textContent = FACTION_LABELS[faction];
    row.appendChild(label);

    const barBg = document.createElement('div');
    barBg.style.cssText = 'width:80px;height:6px;background:rgba(255,255,255,0.08);border-radius:3px;overflow:hidden;';

    const barFill = document.createElement('div');
    barFill.id = `faction-fill-${faction}`;
    barFill.style.cssText = `height:100%;width:0%;background:${FACTION_COLORS[faction]};border-radius:3px;transition:width 0.3s ease;`;
    barBg.appendChild(barFill);
    row.appendChild(barBg);

    const val = document.createElement('span');
    val.id = `faction-val-${faction}`;
    val.style.cssText = 'color:rgba(232,220,200,0.5);font-size:10px;font-family:system-ui;width:24px;';
    val.textContent = '0';
    row.appendChild(val);

    panel.appendChild(row);
  }

  hud.appendChild(panel);
}

/** Build the resource counters (anam + biome currency). */
function buildResourcePanel(): void {
  const hud = document.getElementById('hud');
  if (!hud || document.getElementById('resource-panel')) return;

  const panel = document.createElement('div');
  panel.id = 'resource-panel';
  panel.style.cssText = [
    'position:absolute',
    'top:8px',
    'right:16px',
    'display:flex',
    'flex-direction:column',
    'gap:4px',
    'pointer-events:none',
    'z-index:10',
    'text-align:right',
  ].join(';');

  // Anam counter
  const anamRow = document.createElement('div');
  anamRow.style.cssText = 'display:flex;align-items:center;gap:6px;justify-content:flex-end;';

  const anamLabel = document.createElement('span');
  anamLabel.style.cssText = 'color:rgba(205,133,63,0.7);font-size:12px;font-family:system-ui;';
  anamLabel.textContent = 'Anam';
  anamRow.appendChild(anamLabel);

  const anamVal = document.createElement('span');
  anamVal.id = 'anam-value';
  anamVal.style.cssText = 'color:#cd853f;font-size:14px;font-family:system-ui;font-weight:bold;min-width:28px;';
  anamVal.textContent = '0';
  anamRow.appendChild(anamVal);

  panel.appendChild(anamRow);

  // Biome currency counter
  const currRow = document.createElement('div');
  currRow.style.cssText = 'display:flex;align-items:center;gap:6px;justify-content:flex-end;';

  const currLabel = document.createElement('span');
  currLabel.id = 'currency-label';
  currLabel.style.cssText = 'color:rgba(143,188,143,0.7);font-size:12px;font-family:system-ui;';
  currLabel.textContent = 'Monnaie';
  currRow.appendChild(currLabel);

  const currVal = document.createElement('span');
  currVal.id = 'currency-value';
  currVal.style.cssText = 'color:#8fbc8f;font-size:14px;font-family:system-ui;font-weight:bold;min-width:28px;';
  currVal.textContent = '0';
  currRow.appendChild(currVal);

  panel.appendChild(currRow);

  hud.appendChild(panel);
}

export function updateHUD(): void {
  const state = store.getState();

  // Null-guard static elements — consistent with faction/resource/ogham pattern below
  const lifeFillEl = document.getElementById('life-fill');
  const cardsCountEl = document.getElementById('cards-count');
  const biomeNameEl = document.getElementById('biome-name');
  if (!lifeFillEl || !cardsCountEl || !biomeNameEl) return;

  const lifePercent = (state.run.life / LIFE_MAX) * 100;
  lifeFillEl.style.width = `${lifePercent}%`;

  // Color transitions for life bar
  if (lifePercent <= 25) {
    lifeFillEl.style.background = 'linear-gradient(90deg, #8b0000, #cd5c5c)';
  } else if (lifePercent <= 50) {
    lifeFillEl.style.background = 'linear-gradient(90deg, #8b4513, #cd853f)';
  } else {
    lifeFillEl.style.background = 'linear-gradient(90deg, #2e6b2e, #5a9a5a)';
  }

  cardsCountEl.textContent = `Carte ${state.run.cardsPlayed}`;

  const biome = BIOMES[state.run.biome];
  biomeNameEl.textContent = biome?.name ?? state.run.biome;

  // Update faction bars
  for (const faction of FACTIONS) {
    const rep = state.run.factions[faction] ?? 0;
    const fillEl = document.getElementById(`faction-fill-${faction}`);
    const valEl = document.getElementById(`faction-val-${faction}`);
    if (fillEl) fillEl.style.width = `${rep}%`;
    if (valEl) valEl.textContent = `${rep}`;
  }

  // Update resource counters
  const anamEl = document.getElementById('anam-value');
  if (anamEl) anamEl.textContent = `${state.meta.anam}`;

  const currEl = document.getElementById('currency-value');
  if (currEl) currEl.textContent = `${state.run.biomeCurrency}`;

  const currLabel = document.getElementById('currency-label');
  if (currLabel && biome) {
    currLabel.textContent = biome.currency_name;
  }

  updateOghamBadge();
}

/** Build the ogham active badge (top-center). Hidden by default. */
function buildOghamBadge(): void {
  const hud = document.getElementById('hud');
  if (!hud || document.getElementById('ogham-badge')) return;

  const badge = document.createElement('div');
  badge.id = 'ogham-badge';
  badge.style.cssText = [
    'position:absolute',
    'top:8px',
    'left:50%',
    'transform:translateX(-50%)',
    'display:none',
    'align-items:center',
    'gap:6px',
    'pointer-events:none',
    'z-index:15',
    'background:rgba(0,0,0,0.55)',
    'border:1px solid rgba(205,170,80,0.6)',
    'border-radius:20px',
    'padding:3px 12px',
  ].join(';');

  const runeSpan = document.createElement('span');
  runeSpan.id = 'ogham-badge-rune';
  runeSpan.style.cssText = 'color:#f0c040;font-size:18px;line-height:1;';
  badge.appendChild(runeSpan);

  const nameSpan = document.createElement('span');
  nameSpan.id = 'ogham-badge-name';
  nameSpan.style.cssText = 'color:#f0c040;font-size:11px;font-family:system-ui;font-weight:600;letter-spacing:0.04em;';
  badge.appendChild(nameSpan);

  const multSpan = document.createElement('span');
  multSpan.id = 'ogham-badge-mult';
  multSpan.style.cssText = [
    'color:#ffe680',
    'font-size:13px',
    'font-family:system-ui',
    'font-weight:bold',
    'animation:ogham-pulse 1.2s ease-in-out infinite',
  ].join(';');
  badge.appendChild(multSpan);

  // Keyframe injection (once)
  if (!document.getElementById('ogham-badge-style')) {
    const style = document.createElement('style');
    style.id = 'ogham-badge-style';
    style.textContent = '@keyframes ogham-pulse{0%,100%{opacity:1}50%{opacity:0.55}}';
    document.head.appendChild(style);
  }

  hud.appendChild(badge);
}

/** Update the ogham badge visibility and content from current store state. */
function updateOghamBadge(): void {
  const badge = document.getElementById('ogham-badge');
  if (!badge) return;

  const activeOgham = store.getState().run.activeOgham;
  if (!activeOgham) {
    badge.style.display = 'none';
    return;
  }

  const spec = OGHAM_SPECS[activeOgham];
  if (!spec) {
    badge.style.display = 'none';
    return;
  }

  const runeEl = document.getElementById('ogham-badge-rune');
  const nameEl = document.getElementById('ogham-badge-name');
  const multEl = document.getElementById('ogham-badge-mult');

  if (runeEl) runeEl.textContent = spec.unicode;
  if (nameEl) nameEl.textContent = spec.name;
  if (multEl) {
    // Show effect label: multiplier oghams show "x2", protection shows shield, etc.
    const params = spec.effect_params as Record<string, unknown>;
    if (typeof params['multiplier'] === 'number') {
      multEl.textContent = ` \u00d7${params['multiplier']}`;
    } else if (spec.category === 'protection') {
      multEl.textContent = ' prot.';
    } else {
      multEl.textContent = ' actif';
    }
  }

  badge.style.display = 'flex';
}

/** Subscribe to store changes and auto-update HUD. */
export function initHUD(): void {
  buildFactionPanel();
  buildResourcePanel();
  buildOghamBadge();
  // Unsubscribe any previous subscription before re-subscribing — initHUD() is called
  // every run inside the while(true) loop so without this each run would accumulate an
  // extra Zustand subscriber causing updateHUD() to fire N times per state change.
  _hudUnsubscribe?.();
  _hudUnsubscribe = store.subscribe(updateHUD);
  updateHUD();
}
