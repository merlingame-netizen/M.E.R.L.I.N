// =============================================================================
// HUD -- Life bar, faction bars, anam counter, biome currency, cards count
// =============================================================================

import { store } from '../game/Store';
import { LIFE_MAX, BIOMES, FACTIONS, type FactionId } from '../game/Constants';

// --- Faction display config (immutable) ---
const FACTION_COLORS: Readonly<Record<FactionId, string>> = {
  druides: '#5a9a5a',
  anciens: '#8b8b6a',
  korrigans: '#9a6a5a',
  niamh: '#6a8a9a',
  ankou: '#7a5a7a',
} as const;

const FACTION_LABELS: Readonly<Record<FactionId, string>> = {
  druides: 'Druides',
  anciens: 'Anciens',
  korrigans: 'Korrigans',
  niamh: 'Niamh',
  ankou: 'Ankou',
} as const;

// --- DOM element accessors ---
const lifeFill = () => document.getElementById('life-fill')!;
const cardsCount = () => document.getElementById('cards-count')!;
const biomeName = () => document.getElementById('biome-name')!;

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
  const lifePercent = (state.run.life / LIFE_MAX) * 100;
  lifeFill().style.width = `${lifePercent}%`;

  // Color transitions for life bar
  const fill = lifeFill();
  if (lifePercent <= 25) {
    fill.style.background = 'linear-gradient(90deg, #8b0000, #cd5c5c)';
  } else if (lifePercent <= 50) {
    fill.style.background = 'linear-gradient(90deg, #8b4513, #cd853f)';
  } else {
    fill.style.background = 'linear-gradient(90deg, #2e6b2e, #5a9a5a)';
  }

  cardsCount().textContent = `Carte ${state.run.cardsPlayed}`;

  const biome = BIOMES[state.run.biome];
  biomeName().textContent = biome?.name ?? state.run.biome;

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
}

/** Subscribe to store changes and auto-update HUD. */
export function initHUD(): void {
  buildFactionPanel();
  buildResourcePanel();
  store.subscribe(updateHUD);
  updateHUD();
}
