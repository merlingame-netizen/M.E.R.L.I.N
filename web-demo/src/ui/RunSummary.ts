// ═══════════════════════════════════════════════════════════════════════════════
// RunSummary — T046: End-of-run recap overlay
// Triggered by: life <= 0 OR cardsPlayed >= 30
// Shows: cards played, factions gained, anam earned, biome reached
// ═══════════════════════════════════════════════════════════════════════════════

import { store } from '../game/Store';
import { hideCard } from './CardOverlay';
import { fadeIn } from './Transitions';

// Faction display metadata — label + color for each faction
const FACTION_META: Readonly<Record<string, { label: string; color: string }>> = {
  druides:  { label: 'Druides',  color: '#7cb87c' },
  anciens:  { label: 'Anciens',  color: '#cd853f' },
  korrigans: { label: 'Korrigans', color: '#8b7cb8' },
  niamh:    { label: 'Niamh',    color: '#7cb8b8' },
  ankou:    { label: 'Ankou',    color: '#b87c7c' },
} as const;

const BIOME_LABELS: Readonly<Record<string, string>> = {
  cotes_sauvages:    'Cotes Sauvages',
  foret_broceliande: 'Foret de Broceliande',
  marais_korrigans:  'Marais des Korrigans',
  landes_bruyere:    'Landes de Bruyere',
  cercles_pierres:   'Cercles de Pierres',
  villages_celtes:   'Villages Celtes',
  collines_dolmens:  'Collines aux Dolmens',
  iles_mystiques:    'Iles Mystiques',
} as const;

const SUMMARY_OVERLAY_ID = 'run-summary-overlay';

/**
 * Builds a faction row element.
 * Shows current reputation bar + delta annotation from this run.
 */
function buildFactionRow(factionId: string, reputation: number, delta: number): HTMLElement {
  const meta = FACTION_META[factionId] ?? { label: factionId, color: '#e8dcc8' };
  const row = document.createElement('div');
  row.style.cssText = [
    'display:flex',
    'align-items:center',
    'gap:10px',
    'margin-bottom:6px',
  ].join(';');

  const label = document.createElement('span');
  label.style.cssText = `color:${meta.color};font-size:13px;min-width:80px;`;
  label.textContent = meta.label;

  const barTrack = document.createElement('div');
  barTrack.style.cssText = [
    'flex:1',
    'height:6px',
    'background:rgba(255,255,255,0.1)',
    'border-radius:3px',
    'overflow:hidden',
  ].join(';');

  const barFill = document.createElement('div');
  const pct = Math.min(100, Math.round((reputation / 100) * 100));
  barFill.style.cssText = [
    `width:${pct}%`,
    'height:100%',
    `background:${meta.color}`,
    'border-radius:3px',
    'transition:width 0.8s ease',
  ].join(';');
  barTrack.appendChild(barFill);

  const score = document.createElement('span');
  score.style.cssText = 'font-size:13px;opacity:0.7;min-width:30px;text-align:right;';
  score.textContent = String(reputation);

  row.appendChild(label);
  row.appendChild(barTrack);
  row.appendChild(score);

  // Delta annotation (+N / -N) from this run
  if (delta !== 0) {
    const deltaEl = document.createElement('span');
    const isPositive = delta > 0;
    deltaEl.style.cssText = `font-size:11px;min-width:32px;text-align:right;color:${isPositive ? '#7cb87c' : '#b87c7c'};`;
    deltaEl.textContent = `${isPositive ? '+' : ''}${delta}`;
    row.appendChild(deltaEl);
  }

  return row;
}

/**
 * Show the end-of-run summary overlay.
 * Resolves when the player clicks "Rejouer".
 */
export async function showRunSummary(reason: 'death' | 'victory' | 'cards_limit'): Promise<void> {
  const state = store.getState();

  const biomeLabel = BIOME_LABELS[state.run.biome] ?? state.run.biome;

  const reasonMessages: Readonly<Record<string, string>> = {
    death:        'Tu as succombe aux epreuves de la lande\u2026',
    victory:      'Tu as traverse le biome avec bravoure\u202f!',
    cards_limit:  'Ton voyage touche a sa fin apr\u00e8s trente epreuves.',
  } as const;
  const message = reasonMessages[reason] ?? reasonMessages.death;

  // Fade scene to dark before showing overlay
  await fadeIn(800);

  // Build overlay
  const existing = document.getElementById(SUMMARY_OVERLAY_ID);
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = SUMMARY_OVERLAY_ID;
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-label', 'Recapitulatif de la quete');
  overlay.style.cssText = [
    'position:fixed',
    'top:0', 'left:0', 'right:0', 'bottom:0',
    'display:flex',
    'justify-content:center',
    'align-items:center',
    'background:rgba(10,10,18,0.92)',
    'z-index:70',
    'font-family:\'Segoe UI\',system-ui,sans-serif',
    'color:#e8dcc8',
  ].join(';');

  const panel = document.createElement('div');
  panel.style.cssText = [
    'max-width:480px',
    'width:90%',
    'padding:36px 40px',
    'background:linear-gradient(145deg,rgba(30,25,20,0.97),rgba(15,12,10,0.99))',
    'border:1px solid rgba(205,133,63,0.35)',
    'border-radius:20px',
    'text-align:center',
  ].join(';');

  // Header
  const header = document.createElement('div');
  header.style.cssText = 'font-size:22px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#cd853f;margin-bottom:8px;';
  header.textContent = 'Fin de Quete';
  panel.appendChild(header);

  // Reason message
  const msgEl = document.createElement('div');
  msgEl.style.cssText = 'font-size:15px;font-style:italic;opacity:0.85;margin-bottom:28px;line-height:1.5;';
  msgEl.textContent = message;
  panel.appendChild(msgEl);

  // Divider
  const div1 = document.createElement('hr');
  div1.style.cssText = 'border:none;border-top:1px solid rgba(205,133,63,0.2);margin-bottom:20px;';
  panel.appendChild(div1);

  // Stats grid
  const statsGrid = document.createElement('div');
  statsGrid.style.cssText = [
    'display:grid',
    'grid-template-columns:1fr 1fr',
    'gap:12px 20px',
    'margin-bottom:20px',
    'text-align:left',
  ].join(';');

  const addStat = (label: string, value: string | number): void => {
    const cell = document.createElement('div');
    const lbl = document.createElement('div');
    lbl.style.cssText = 'font-size:11px;text-transform:uppercase;letter-spacing:1px;opacity:0.5;margin-bottom:2px;';
    lbl.textContent = label;
    const val = document.createElement('div');
    val.style.cssText = 'font-size:18px;font-weight:600;color:#cd853f;';
    val.textContent = String(value);
    cell.appendChild(lbl);
    cell.appendChild(val);
    statsGrid.appendChild(cell);
  };

  addStat('Cartes jouees', state.run.cardsPlayed);
  addStat('Anam cette quete', state.run.anamThisRun);
  addStat('Anam total', state.meta.anam);
  addStat('Vie restante', Math.max(0, state.run.life));
  addStat('Biome atteint', biomeLabel);

  panel.appendChild(statsGrid);

  // Divider
  const div2 = document.createElement('hr');
  div2.style.cssText = 'border:none;border-top:1px solid rgba(205,133,63,0.2);margin-bottom:16px;';
  panel.appendChild(div2);

  // Faction section header
  const factionHeader = document.createElement('div');
  factionHeader.style.cssText = 'font-size:12px;text-transform:uppercase;letter-spacing:2px;opacity:0.5;margin-bottom:12px;text-align:left;';
  factionHeader.textContent = 'Reputation des factions';
  panel.appendChild(factionHeader);

  // Faction bars — show all 5 factions with delta annotation
  const factionsEl = document.createElement('div');
  factionsEl.style.cssText = 'margin-bottom:24px;';
  const factions = state.run.factions as Record<string, number>;
  const deltas = state.run.factionDeltaThisRun as Record<string, number>;
  Object.entries(factions).forEach(([id, rep]) => {
    factionsEl.appendChild(buildFactionRow(id, rep, deltas[id] ?? 0));
  });
  panel.appendChild(factionsEl);

  // Restart button
  const restartBtn = document.createElement('button');
  restartBtn.id = 'run-summary-restart';
  restartBtn.style.cssText = [
    'padding:12px 40px',
    'font-size:15px',
    'cursor:pointer',
    'background:rgba(139,69,19,0.3)',
    'color:#e8dcc8',
    'border:1px solid rgba(205,133,63,0.5)',
    'border-radius:10px',
    'font-family:inherit',
    'letter-spacing:1px',
    'transition:all 0.2s ease',
  ].join(';');
  restartBtn.textContent = 'Rejouer';
  restartBtn.addEventListener('mouseenter', () => {
    restartBtn.style.background = 'rgba(139,69,19,0.55)';
    restartBtn.style.borderColor = 'rgba(205,133,63,0.9)';
  });
  restartBtn.addEventListener('mouseleave', () => {
    restartBtn.style.background = 'rgba(139,69,19,0.3)';
    restartBtn.style.borderColor = 'rgba(205,133,63,0.5)';
  });
  panel.appendChild(restartBtn);

  overlay.appendChild(panel);
  document.body.appendChild(overlay);

  // Wait for restart click — resolve so main()'s outer while(true) loop returns to lair.
  // Do NOT call window.location.reload() — the outer loop in main.ts handles the next run
  // cleanly (new SceneManager, fresh biome, startRun). A hard reload would discard
  // in-memory GroqAdapter singletons and force re-fetching cards.json unnecessarily.
  await new Promise<void>((resolve) => {
    restartBtn.addEventListener('click', () => {
      overlay.remove();
      hideCard();
      store.getState().reset();
      resolve();
    });
  });
}
