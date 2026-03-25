// ═══════════════════════════════════════════════════════════════════════════════
// HUD — Life bar, cards count, biome name
// ═══════════════════════════════════════════════════════════════════════════════

import { store } from '../game/Store';
import { LIFE_MAX, BIOMES } from '../game/Constants';

const lifeFill = () => document.getElementById('life-fill')!;
const cardsCount = () => document.getElementById('cards-count')!;
const biomeName = () => document.getElementById('biome-name')!;

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
}

/** Subscribe to store changes and auto-update HUD. */
export function initHUD(): void {
  store.subscribe(updateHUD);
  updateHUD();
}
