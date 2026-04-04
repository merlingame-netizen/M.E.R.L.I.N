// ═══════════════════════════════════════════════════════════════════════════════
// RunSummary — T046: End-of-run recap overlay
// Triggered by: life <= 0 OR cardsPlayed >= 30
// Shows: cards played, factions gained, anam earned, biome reached
// C167: cinematic polish — scanline pulse header, anam counter RAF, cause banner,
//       bloc-char faction bars, hover box-shadow + SFX on restart button
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
  monts_brumeux:     'Monts Brumeux',
  plaine_druides:    'Plaine des Druides',
  vallee_anciens:    'Vallee des Anciens',
} as const;

const SUMMARY_OVERLAY_ID = 'run-summary-overlay';
const SCANLINE_KEYFRAME_ID = 'run-summary-scanline-kf';

// C86: module-level anchor for the pending restart Promise resolve.
// showRunSummary() can be re-entered (e.g. run ends while overlay already shown
// from a previous death) — existing.remove() destroys the old restartBtn,
// orphaning the inline Promise resolve and causing an async deadlock for any caller
// awaiting the first invocation. Hoisting to module scope with null-guard on re-entry
// mirrors the OghamPanel resolveChoice pattern.
let resolveRestart: (() => void) | null = null;

// C167: active RAF handle for the anam counter — cancelled on dispose so no orphaned RAF
let anamRafHandle: number | null = null;

/**
 * Inject the scanline-pulse @keyframes once — idempotent via id guard.
 */
function ensureScanlineKeyframes(): void {
  if (document.getElementById(SCANLINE_KEYFRAME_ID)) return;
  const style = document.createElement('style');
  style.id = SCANLINE_KEYFRAME_ID;
  style.textContent = `
    @keyframes rs-scanline-pulse {
      0%   { opacity: 0.92; }
      50%  { opacity: 1; }
      100% { opacity: 0.92; }
    }
  `;
  document.head.appendChild(style);
}

/**
 * Build bloc-char faction bar — "████░░░░░░" style, 10 blocks wide.
 * Matches the Journal visual language.
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
  label.style.cssText = `color:${meta.color};font-size:13px;min-width:80px;font-family:Courier New,monospace;`;
  label.textContent = meta.label;

  // Bloc-char bar: 10 blocks, filled = █, empty = ░
  const BLOCKS = 10;
  const filled = Math.round((Math.min(100, Math.max(0, reputation)) / 100) * BLOCKS);
  const barEl = document.createElement('span');
  barEl.style.cssText = `flex:1;font-size:13px;letter-spacing:1px;color:${meta.color};opacity:0.85;font-family:Courier New,monospace;`;
  barEl.textContent = '█'.repeat(filled) + '░'.repeat(BLOCKS - filled);

  const score = document.createElement('span');
  score.style.cssText = 'font-size:13px;opacity:0.7;min-width:30px;text-align:right;font-family:Courier New,monospace;';
  score.textContent = String(reputation);

  row.appendChild(label);
  row.appendChild(barEl);
  row.appendChild(score);

  // Delta annotation (+N / -N) from this run
  if (delta !== 0) {
    const deltaEl = document.createElement('span');
    const isPositive = delta > 0;
    deltaEl.style.cssText = `font-size:11px;min-width:32px;text-align:right;color:${isPositive ? '#7cb87c' : '#b87c7c'};font-family:Courier New,monospace;`;
    deltaEl.textContent = `${isPositive ? '+' : ''}${delta}`;
    row.appendChild(deltaEl);
  }

  return row;
}

/**
 * Animate a number counter from 0 → target over durationMs using RAF.
 * Ease-out quadratic. Calls onFrame(currentValue) each tick.
 * Returns the RAF handle so the caller can cancel it on dispose.
 */
function animateCounter(
  target: number,
  durationMs: number,
  onFrame: (value: number) => void,
): number {
  const startTime = performance.now();
  let handle = 0;

  const tick = (now: number): void => {
    const elapsed = now - startTime;
    const progress = Math.min(1, elapsed / durationMs);
    // Ease-out quad: 1 - (1 - t)^2
    const eased = 1 - (1 - progress) ** 2;
    const current = Math.round(eased * target);
    onFrame(current);
    if (progress < 1) {
      handle = requestAnimationFrame(tick);
      anamRafHandle = handle;
    } else {
      anamRafHandle = null;
    }
  };

  handle = requestAnimationFrame(tick);
  anamRafHandle = handle;
  return handle;
}

/**
 * Dispatch the merlin SFX custom event for a given sound name.
 */
function playSfx(sound: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound } }));
}

/**
 * Show the end-of-run summary overlay.
 * Resolves when the player clicks "Rejouer".
 */
export async function showRunSummary(reason: 'death' | 'victory' | 'cards_limit'): Promise<void> {
  const state = store.getState();

  const biomeLabel = BIOME_LABELS[state.run.biome] ?? state.run.biome;

  // C138/RS-01: re-entry guard BEFORE fadeIn — concurrent death calls previously both
  // entered the 800ms fadeIn, then the second call resolved the first awaiter mid-fade,
  // replacing the summary screen with no player interaction.
  if (resolveRestart) {
    resolveRestart();
    resolveRestart = null;
  }

  // Cancel any orphaned anam RAF from a previous overlay
  if (anamRafHandle !== null) {
    cancelAnimationFrame(anamRafHandle);
    anamRafHandle = null;
  }

  // Fade scene to dark before showing overlay
  await fadeIn(800);

  ensureScanlineKeyframes();

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
    'font-family:Courier New,monospace',
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

  // ── C167: Header with scanline pulse animation ───────────────────────────────
  const header = document.createElement('div');
  header.style.cssText = [
    'font-size:16px',
    'font-weight:700',
    'letter-spacing:0.22em',
    'text-transform:uppercase',
    'color:#33ff66',
    'margin-bottom:4px',
    'font-family:Courier New,monospace',
    'text-shadow:0 0 8px rgba(51,255,102,0.35)',
    'animation:rs-scanline-pulse 1.2s ease-in-out infinite',
  ].join(';');
  header.textContent = '> FIN_DE_QUETE';
  panel.appendChild(header);

  // Sub-header: biome + card count
  const cardsPlayed = state.run.cardsPlayed ?? 0;
  const subHeader = document.createElement('div');
  subHeader.style.cssText = [
    'font-size:11px',
    'color:rgba(51,255,102,0.5)',
    'letter-spacing:0.14em',
    'margin-bottom:20px',
    'font-family:Courier New,monospace',
  ].join(';');
  subHeader.textContent = `${biomeLabel} — ${cardsPlayed} carte${cardsPlayed !== 1 ? 's' : ''}`;
  panel.appendChild(subHeader);

  // ── C167: Cause de fin — colored result banner ───────────────────────────────
  const isVictory = reason === 'victory' || reason === 'cards_limit';
  const causeEl = document.createElement('div');
  causeEl.style.cssText = [
    'font-size:13px',
    'font-weight:700',
    'letter-spacing:0.16em',
    'text-transform:uppercase',
    'margin-bottom:24px',
    'padding:8px 16px',
    `color:${isVictory ? '#33ff66' : 'rgba(255,80,80,0.9)'}`,
    `border:1px solid ${isVictory ? 'rgba(51,255,102,0.3)' : 'rgba(255,80,80,0.3)'}`,
    'border-radius:2px',
    `background:${isVictory ? 'rgba(51,255,102,0.06)' : 'rgba(255,80,80,0.06)'}`,
    'font-family:Courier New,monospace',
  ].join(';');
  causeEl.textContent = isVictory
    ? '[ VICTOIRE \u2014 QUETE ACCOMPLIE ]'
    : '[ DEFAITE \u2014 VIE EPUISEE ]';
  panel.appendChild(causeEl);

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

  const addStat = (label: string, value: string | number, animate?: boolean): HTMLElement => {
    const cell = document.createElement('div');
    const lbl = document.createElement('div');
    lbl.style.cssText = 'font-size:11px;text-transform:uppercase;letter-spacing:1px;opacity:0.5;margin-bottom:2px;';
    lbl.textContent = label;
    const val = document.createElement('div');
    val.style.cssText = 'font-size:16px;font-weight:600;color:#33ff66;font-family:Courier New,monospace;';
    val.textContent = animate ? '0' : String(value);
    cell.appendChild(lbl);
    cell.appendChild(val);
    statsGrid.appendChild(cell);
    return val;
  };

  addStat('Cartes jouees', cardsPlayed); // C123/RS-NULL-01: save-compat guard

  // C167: anam counter — animated from 0 → target
  const anamValue = state.run.anamThisRun ?? 0; // C123/RS-NULL-01
  const anamValEl = addStat('Anam cette quete', anamValue, true);

  addStat('Anam total', state.meta.anam);
  addStat('Vie restante', Math.max(0, state.run.life));

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

  // Faction bloc-char bars — show all 5 factions with delta annotation
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
      fulfilled: { icon: '\u2713', color: '#7cb87c' },
      broken:    { icon: '\u2717', color: '#b87c7c' },
      expired:   { icon: '\u23f1', color: 'rgba(51,255,102,0.55)' },
      active:    { icon: '\u2026', color: '#a0a0b8' },
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

  // ── C167: Restart button with box-shadow hover + SFX ────────────────────────
  const restartBtn = document.createElement('button');
  restartBtn.id = 'run-summary-restart';
  restartBtn.style.cssText = [
    'padding:10px 36px',
    'font-size:13px',
    'cursor:pointer',
    'background:rgba(26,136,51,0.15)',
    'color:#33ff66',
    'border:1px solid rgba(51,255,102,0.3)',
    'border-radius:2px',
    'font-family:Courier New,monospace',
    'letter-spacing:0.18em',
    'text-transform:uppercase',
    'transition:all 0.2s ease',
  ].join(';');
  restartBtn.textContent = '> REJOUER';

  // C87: :focus-visible outline for keyboard users — WCAG 2.4.7 (Focus Visible).
  // C150/RS-LISTENER-LEAK-01: store all style-mutation handlers as named functions so the
  // click handler can removeEventListener() before overlay.remove().
  const onFocus = (): void => {
    restartBtn.style.outline = '2px solid rgba(51,255,102,0.8)';
    restartBtn.style.outlineOffset = '3px';
  };
  const onBlur = (): void => { restartBtn.style.outline = 'none'; };
  const onPointerEnter = (): void => {
    restartBtn.style.background = 'rgba(26,136,51,0.35)';
    restartBtn.style.borderColor = 'rgba(51,255,102,0.7)';
    restartBtn.style.boxShadow = '0 0 14px rgba(51,255,102,0.2)';
  };
  const onPointerLeave = (): void => {
    restartBtn.style.background = 'rgba(26,136,51,0.15)';
    restartBtn.style.borderColor = 'rgba(51,255,102,0.3)';
    restartBtn.style.boxShadow = 'none';
  };
  restartBtn.addEventListener('focus', onFocus);
  restartBtn.addEventListener('blur', onBlur);
  // C149/RS-HOVER-MOBILE-01: pointerenter/pointerleave fire on mouse AND touch (mobile).
  restartBtn.addEventListener('pointerenter', onPointerEnter);
  restartBtn.addEventListener('pointerleave', onPointerLeave);
  panel.appendChild(restartBtn);

  overlay.appendChild(panel);
  document.body.appendChild(overlay);

  // C167: start anam counter animation after DOM insertion
  if (anamValue > 0) {
    animateCounter(anamValue, 1200, (v) => {
      anamValEl.textContent = String(v);
    });
  } else {
    anamValEl.textContent = '0';
  }

  // C87: move focus to restartBtn after DOM insertion — WCAG 2.1 SC 2.1.2 (keyboard reachable on dialog open)
  requestAnimationFrame(() => restartBtn.focus());

  // Wait for restart click — resolve so main()'s outer while(true) loop returns to lair.
  // Do NOT call window.location.reload() — the outer loop in main.ts handles the next run
  // cleanly (new SceneManager, fresh biome, startRun). A hard reload would discard
  // in-memory GroqAdapter singletons and force re-fetching cards.json unnecessarily.
  await new Promise<void>((resolve) => {
    resolveRestart = resolve;
    restartBtn.addEventListener('click', () => {
      // C167: SFX on click
      playSfx('click');

      // Cancel any still-running anam RAF before overlay removal
      if (anamRafHandle !== null) {
        cancelAnimationFrame(anamRafHandle);
        anamRafHandle = null;
      }

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
