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
  anciens:  { label: 'Anciens',  color: '#e8c84c' },
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

// C86: module-level anchor for the pending restart Promise resolve.
// showRunSummary() can be re-entered (e.g. run ends while overlay already shown
// from a previous death) — existing.remove() at line 112 destroys the old restartBtn,
// orphaning the inline Promise resolve and causing an async deadlock for any caller
// awaiting the first invocation. Hoisting to module scope with null-guard on re-entry
// mirrors the OghamPanel resolveChoice pattern.
let resolveRestart: (() => void) | null = null;

/**
 * Builds a faction row element.
 * Shows current reputation bar + delta annotation from this run.
 */
function buildFactionRow(factionId: string, reputation: number, delta: number): HTMLElement {
  const meta = FACTION_META[factionId] ?? { label: factionId, color: 'rgba(51,255,102,0.7)' };
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
    'background:rgba(51,255,102,0.08)',
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

  // C138/RS-01: re-entry guard BEFORE fadeIn — concurrent death calls previously both
  // entered the 800ms fadeIn, then the second call resolved the first awaiter mid-fade,
  // replacing the summary screen with no player interaction.
  if (resolveRestart) {
    resolveRestart();
    resolveRestart = null;
  }

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
    'background:rgba(2,8,2,0.96)',
    'z-index:70',
    `font-family:'Courier New',monospace`,
    'color:rgba(51,255,102,0.88)',
  ].join(';');

  const panel = document.createElement('div');
  panel.style.cssText = [
    'max-width:480px',
    'width:90%',
    'padding:36px 40px',
    'background:rgba(1,8,2,0.97)',
    'border:1px solid rgba(51,255,102,0.18)',
    'border-left:3px solid #1a8833',
    'border-radius:4px',
    'text-align:center',
  ].join(';');

  // Header
  const header = document.createElement('div');
  header.style.cssText = `font-size:16px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#33ff66;margin-bottom:8px;font-family:'Courier New',monospace;text-shadow:0 0 8px rgba(51,255,102,0.35);`;
  header.textContent = '> FIN_DE_QUETE';
  panel.appendChild(header);

  // Reason message
  const msgEl = document.createElement('div');
  msgEl.style.cssText = 'font-size:15px;font-style:italic;opacity:0.85;margin-bottom:28px;line-height:1.5;';
  msgEl.textContent = message;
  panel.appendChild(msgEl);

  // Divider
  const div1 = document.createElement('hr');
  div1.style.cssText = 'border:none;border-top:1px solid rgba(51,255,102,0.12);margin-bottom:20px;';
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
    val.style.cssText = `font-size:16px;font-weight:600;color:#33ff66;font-family:'Courier New',monospace;`;
    val.textContent = String(value);
    cell.appendChild(lbl);
    cell.appendChild(val);
    statsGrid.appendChild(cell);
  };

  addStat('Cartes jouees', state.run.cardsPlayed ?? 0); // C123/RS-NULL-01: save-compat guard
  addStat('Anam cette quete', state.run.anamThisRun ?? 0); // C123/RS-NULL-01
  addStat('Anam total', state.meta.anam);
  addStat('Vie restante', Math.max(0, state.run.life));
  addStat('Biome atteint', biomeLabel);

  panel.appendChild(statsGrid);

  // Divider
  const div2 = document.createElement('hr');
  div2.style.cssText = 'border:none;border-top:1px solid rgba(51,255,102,0.12);margin-bottom:16px;';
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
  const deltas = (state.run.factionDeltaThisRun ?? {}) as Record<string, number>; // C123/RS-NULL-02: save-compat guard
  Object.entries(factions).forEach(([id, rep]) => {
    factionsEl.appendChild(buildFactionRow(id, rep, deltas[id] ?? 0));
  });
  panel.appendChild(factionsEl);

  // Promises section — show moral accountability if any promises were made this run
  const promises = state.run.promises;
  if (promises.length > 0) {
    const div3 = document.createElement('hr');
    div3.style.cssText = 'border:none;border-top:1px solid rgba(51,255,102,0.12);margin-bottom:16px;';
    panel.appendChild(div3);

    const promiseHeader = document.createElement('div');
    promiseHeader.style.cssText = 'font-size:12px;text-transform:uppercase;letter-spacing:2px;opacity:0.5;margin-bottom:12px;text-align:left;';
    promiseHeader.textContent = 'Promesses';
    panel.appendChild(promiseHeader);

    const promisesEl = document.createElement('div');
    promisesEl.style.cssText = 'margin-bottom:24px;text-align:left;';

    const STATUS_META: Readonly<Record<string, { icon: string; color: string }>> = {
      fulfilled: { icon: '✓', color: '#7cb87c' },
      broken:    { icon: '✗', color: '#b87c7c' },
      expired:   { icon: '⏱', color: 'rgba(51,255,102,0.55)' },
      active:    { icon: '…', color: '#a0a0b8' },
    } as const;

    for (const p of promises) {
      const meta = STATUS_META[p.status] ?? STATUS_META['active']!;
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:8px;align-items:center;margin-bottom:6px;font-size:13px;';
      const iconEl = document.createElement('span');
      iconEl.setAttribute('aria-hidden', 'true');
      iconEl.style.cssText = `color:${meta.color};width:14px;text-align:center;flex-shrink:0;`;
      iconEl.textContent = meta.icon;
      const nameEl = document.createElement('span');
      nameEl.style.cssText = `color:${meta.color};flex:1;`;
      nameEl.textContent = p.label;
      row.appendChild(iconEl);
      row.appendChild(nameEl);
      promisesEl.appendChild(row);
    }
    panel.appendChild(promisesEl);
  }

  // Restart button
  const restartBtn = document.createElement('button');
  restartBtn.id = 'run-summary-restart';
  restartBtn.style.cssText = [
    'padding:10px 36px',
    'font-size:13px',
    'cursor:pointer',
    'background:rgba(26,136,51,0.15)',
    'color:#33ff66',
    'border:1px solid rgba(51,255,102,0.35)',
    'border-radius:2px',
    `font-family:'Courier New',monospace`,
    'letter-spacing:0.18em',
    'text-transform:uppercase',
    'transition:all 0.2s ease',
  ].join(';');
  restartBtn.textContent = '> REJOUER';
  // C87: :focus-visible outline for keyboard users — WCAG 2.4.7 (Focus Visible).
  // Inline event listeners are used because this element is created dynamically
  // and no stylesheet is injected by this module.
  // C150/RS-LISTENER-LEAK-01: store all style-mutation handlers as named functions so the
  // click handler can removeEventListener() before overlay.remove(). Without removal,
  // 4 listeners accumulate on a detached restartBtn node per run — modern GC eventually
  // collects them but memory pressure on mobile (low-end ~512MB) can spike between runs.
  const onFocus = (): void => {
    restartBtn.style.outline = '2px solid rgba(51,255,102,0.8)';
    restartBtn.style.outlineOffset = '3px';
  };
  const onBlur = (): void => { restartBtn.style.outline = 'none'; };
  const onPointerEnter = (): void => {
    restartBtn.style.background = 'rgba(26,136,51,0.35)';
    restartBtn.style.borderColor = 'rgba(51,255,102,0.7)';
  };
  const onPointerLeave = (): void => {
    restartBtn.style.background = 'rgba(26,136,51,0.15)';
    restartBtn.style.borderColor = 'rgba(51,255,102,0.35)';
  };
  restartBtn.addEventListener('focus', onFocus);
  restartBtn.addEventListener('blur', onBlur);
  // C149/RS-HOVER-MOBILE-01: pointerenter/pointerleave fire on mouse AND touch (mobile).
  restartBtn.addEventListener('pointerenter', onPointerEnter);
  restartBtn.addEventListener('pointerleave', onPointerLeave);
  panel.appendChild(restartBtn);

  overlay.appendChild(panel);
  document.body.appendChild(overlay);
  // C87: move focus to restartBtn after DOM insertion — WCAG 2.1 SC 2.1.2 (keyboard reachable on dialog open)
  requestAnimationFrame(() => restartBtn.focus());

  // Wait for restart click — resolve so main()'s outer while(true) loop returns to lair.
  // Do NOT call window.location.reload() — the outer loop in main.ts handles the next run
  // cleanly (new SceneManager, fresh biome, startRun). A hard reload would discard
  // in-memory GroqAdapter singletons and force re-fetching cards.json unnecessarily.
  await new Promise<void>((resolve) => {
    resolveRestart = resolve;
    restartBtn.addEventListener('click', () => {
      // C150/RS-LISTENER-LEAK-01: remove style-mutation listeners before overlay removal
      restartBtn.removeEventListener('focus', onFocus);
      restartBtn.removeEventListener('blur', onBlur);
      restartBtn.removeEventListener('pointerenter', onPointerEnter);
      restartBtn.removeEventListener('pointerleave', onPointerLeave);
      overlay.remove();
      hideCard();
      resolveRestart = null;
      // C79-05: do NOT call store.reset() here — it wipes meta (anam, factionRep,
      // totalRuns) before main.ts re-hydrates via loadAnamFromStorage() /
      // loadMetaFromStorage(). startRun() in main.ts rebuilds run state cleanly
      // from buildDefaultRun() seeded with preserved meta.factionRep — no reset needed.
      resolve();
    }, { once: true }); // C79-04: { once: true } closes double-tap race on mobile
  });
}
