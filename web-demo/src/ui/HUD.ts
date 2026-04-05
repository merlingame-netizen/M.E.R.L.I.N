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

// Cards limit — mirrors the 30-card ceiling in main.ts (T046)
const CARDS_LIMIT = 30;

// Module-level element caches — populated in initHUD() / build* functions, cleared in teardownHUD().
// Eliminates 22 getElementById calls per updateHUD() invocation (C121/HUD-01).
let _lifeFillEl: HTMLElement | null = null;
let _cardsCountEl: HTMLElement | null = null;
let _progressFillEl: HTMLElement | null = null;
let _biomeNameEl: HTMLElement | null = null;
let _lifeBarContainerEl: HTMLElement | null = null;
let _lifeStatusEl: HTMLElement | null = null;
let _anamEl: HTMLElement | null = null;
let _currEl: HTMLElement | null = null;
let _currLabelEl: HTMLElement | null = null;
const _factionFillEls: Partial<Record<FactionId, HTMLElement>> = {};
const _factionValEls: Partial<Record<FactionId, HTMLElement>> = {};
let _oghamBadgeEl: HTMLElement | null = null;
let _oghamRuneEl: HTMLElement | null = null;
let _oghamNameEl: HTMLElement | null = null;
let _oghamMultEl: HTMLElement | null = null;

// Module-level unsubscribe handle — prevents duplicate Zustand subscriber accumulation
// when initHUD() is called on every run inside the outer while(true) loop (main.ts).
let _hudUnsubscribe: (() => void) | null = null;

// C240: tracks whether the critical_alert SFX has fired for the current run (reset in teardownHUD).
let _criticalAlerted: boolean = false;

// C271: previous life value used to detect changes and spawn floating delta indicators.
// -1 means "not yet initialized" (set on first updateHUD call in a run).
let _prevLife: number = -1;

// Cached #hud root element — used by setHUDWalkMode() for opacity transition. C163/HUD-WALK-01.
let _hudRootEl: HTMLElement | null = null;

/**
 * Toggle HUD opacity for walk vs card/minigame phases. C163/HUD-WALK-01.
 * During walk: opacity 1 (fully visible, player sees life/biome/cards).
 * During card/minigame overlay: opacity 0.2 (recede — card takes focus).
 */
export function setHUDWalkMode(walk: boolean): void {
  if (!_hudRootEl) _hudRootEl = document.getElementById('hud');
  if (!_hudRootEl) return;
  _hudRootEl.style.transition = 'opacity 0.4s ease';
  _hudRootEl.style.opacity = walk ? '1' : '0.2';
}

// =============================================================================
// C240 — Critical health pulse warning (≤20 HP)
// =============================================================================

/**
 * Inject the hud-critical-pulse CSS keyframes once into document.head.
 * Idempotent — safe to call multiple times.
 */
function ensureHudCriticalStyles(): void {
  if (document.getElementById('hud-critical-style')) return;
  const s = document.createElement('style');
  s.id = 'hud-critical-style';
  s.textContent = `
    @keyframes hud-critical-pulse {
      0%, 100% { box-shadow: 0 0 0px rgba(200,30,30,0); border-color: rgba(200,30,30,0.3); }
      50%       { box-shadow: 0 0 16px rgba(200,30,30,0.6); border-color: rgba(200,30,30,0.8); }
    }
    .hud-critical {
      animation: hud-critical-pulse 1.2s ease-in-out infinite;
    }
  `;
  document.head.appendChild(s);
}

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

    // C171: CeltOS charter — Courier New, phosphor green dim labels
    const label = document.createElement('span');
    label.style.cssText = 'color:rgba(51,255,102,0.42);font-size:10px;font-family:"Courier New",Courier,monospace;width:60px;text-align:right;letter-spacing:1px;text-transform:uppercase;';
    label.textContent = FACTION_LABELS[faction];
    row.appendChild(label);

    const barBg = document.createElement('div');
    barBg.style.cssText = 'width:80px;height:5px;background:rgba(51,255,102,0.06);border:1px solid rgba(51,255,102,0.15);border-radius:0;overflow:hidden;';

    const barFill = document.createElement('div');
    barFill.id = `faction-fill-${faction}`;
    barFill.style.cssText = `height:100%;width:0%;background:${FACTION_COLORS[faction]};border-radius:0;transition:width 0.3s ease;`;
    barBg.appendChild(barFill);
    row.appendChild(barBg);
    _factionFillEls[faction] = barFill; // C121/HUD-01: cache for zero-getElementById updateHUD

    const val = document.createElement('span');
    val.id = `faction-val-${faction}`;
    val.style.cssText = 'color:rgba(51,255,102,0.55);font-size:10px;font-family:"Courier New",Courier,monospace;width:24px;';
    val.textContent = '0';
    row.appendChild(val);
    _factionValEls[faction] = val; // C121/HUD-01

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

  // C171: CeltOS charter
  const anamLabel = document.createElement('span');
  anamLabel.style.cssText = 'color:rgba(51,255,102,0.45);font-size:10px;font-family:"Courier New",Courier,monospace;letter-spacing:2px;text-transform:uppercase;';
  anamLabel.textContent = 'ANAM';
  anamRow.appendChild(anamLabel);

  const anamVal = document.createElement('span');
  anamVal.id = 'anam-value';
  anamVal.style.cssText = 'color:#33ff66;font-size:13px;font-family:"Courier New",Courier,monospace;font-weight:bold;min-width:28px;text-shadow:0 0 6px rgba(51,255,102,0.4);';
  anamVal.textContent = '0';
  anamRow.appendChild(anamVal);
  _anamEl = anamVal; // C121/HUD-01

  panel.appendChild(anamRow);

  // Biome currency counter
  const currRow = document.createElement('div');
  currRow.style.cssText = 'display:flex;align-items:center;gap:6px;justify-content:flex-end;';

  // C171: CeltOS charter
  const currLabel = document.createElement('span');
  currLabel.id = 'currency-label';
  currLabel.style.cssText = 'color:rgba(51,255,102,0.40);font-size:10px;font-family:"Courier New",Courier,monospace;letter-spacing:2px;text-transform:uppercase;';
  currLabel.textContent = 'MONNAIE';
  currRow.appendChild(currLabel);
  _currLabelEl = currLabel; // C121/HUD-01

  const currVal = document.createElement('span');
  currVal.id = 'currency-value';
  currVal.style.cssText = 'color:rgba(51,255,102,0.75);font-size:13px;font-family:"Courier New",Courier,monospace;font-weight:bold;min-width:28px;';
  currVal.textContent = '0';
  currRow.appendChild(currVal);
  _currEl = currVal; // C121/HUD-01

  panel.appendChild(currRow);

  hud.appendChild(panel);
}

export function updateHUD(): void {
  const state = store.getState();

  // Use module-level cached refs (C121/HUD-01 — zero getElementById at runtime)
  if (!_lifeFillEl || !_cardsCountEl || !_biomeNameEl) return;

  const lifePercent = (state.run.life / LIFE_MAX) * 100;
  _lifeFillEl.style.width = `${lifePercent}%`;

  // ARIA progressbar value — BUG-C88-07
  if (_lifeBarContainerEl) _lifeBarContainerEl.setAttribute('aria-valuenow', String(Math.round(lifePercent)));

  // C171: CRT life bar — danger=red glitch, warning=amber, normal=phosphor green
  if (lifePercent <= 25) {
    _lifeFillEl.style.background = 'linear-gradient(90deg, #cc1515, #ff3535)';
    _lifeFillEl.style.boxShadow = '0 0 8px rgba(255,50,50,0.6)';
  } else if (lifePercent <= 50) {
    _lifeFillEl.style.background = 'linear-gradient(90deg, #7b0000, #cc2200)';
    _lifeFillEl.style.boxShadow = '0 0 6px rgba(200,40,0,0.5)';
  } else {
    _lifeFillEl.style.background = 'linear-gradient(90deg, #1a8833, #33ff66)';
    _lifeFillEl.style.boxShadow = '0 0 6px rgba(51,255,102,0.4)';
  }

  // ARIA live region — announce critical health once on entry (BUG-C88-07)
  if (_lifeStatusEl) {
    const prevAnnounced = _lifeStatusEl.dataset['criticalAnnounced'] === 'true';
    if (lifePercent <= 25 && !prevAnnounced) {
      _lifeStatusEl.textContent = `Vie critique — ${Math.round(lifePercent)} % restant`;
      _lifeStatusEl.dataset['criticalAnnounced'] = 'true';
    } else if (lifePercent > 25 && prevAnnounced) {
      _lifeStatusEl.textContent = '';
      _lifeStatusEl.dataset['criticalAnnounced'] = 'false';
    }
  }

  // C240: critical health pulse on life-bar-container at ≤20 HP
  if (_lifeBarContainerEl) {
    if (state.run.life <= 20) {
      ensureHudCriticalStyles();
      _lifeBarContainerEl.classList.add('hud-critical');
      if (!_criticalAlerted) {
        _criticalAlerted = true;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'critical_alert' } }));
      }
    } else {
      _lifeBarContainerEl.classList.remove('hud-critical');
    }
  }

  // C271: floating life delta indicator — fire when life changes between frames
  const currentLife = state.run.life;
  if (_prevLife !== -1 && currentLife !== _prevLife) {
    spawnLifeDelta(currentLife - _prevLife);
  }
  _prevLife = currentLife;

  _cardsCountEl.textContent = `CARTE_${state.run.cardsPlayed}`;

  // Run progress bar update
  if (_progressFillEl) {
    const progress = Math.min(state.run.cardsPlayed / CARDS_LIMIT, 1);
    _progressFillEl.style.width = `${progress * 100}%`;
    if (progress > 0.8) {
      _progressFillEl.style.boxShadow = '0 0 4px rgba(51,255,102,0.5)';
    } else {
      _progressFillEl.style.boxShadow = '';
    }
  }

  const biome = BIOMES[state.run.biome];
  _biomeNameEl.textContent = (biome?.name ?? state.run.biome).toUpperCase();

  // Update faction bars
  for (const faction of FACTIONS) {
    const rep = state.run.factions[faction] ?? 0;
    const fillEl = _factionFillEls[faction];
    const valEl = _factionValEls[faction];
    if (fillEl) fillEl.style.width = `${rep}%`;
    if (valEl) valEl.textContent = `${rep}`;
  }

  // Update resource counters
  if (_anamEl) _anamEl.textContent = `${state.meta.anam}`;
  if (_currEl) _currEl.textContent = `${state.run.biomeCurrency}`;
  if (_currLabelEl && biome) _currLabelEl.textContent = biome.currency_name;

  updateOghamBadge();
}

// =============================================================================
// C271 — Life change floating delta indicator (+N / -N)
// =============================================================================

/**
 * Inject the hud-life-delta CSS keyframes and class once into document.head.
 * Idempotent — safe to call multiple times.
 */
function ensureLifeDeltaStyle(): void {
  if (document.getElementById('hud-life-delta-style')) return;
  const s = document.createElement('style');
  s.id = 'hud-life-delta-style';
  s.textContent = `
    @keyframes life-delta-float {
      0%   { opacity: 1; transform: translateY(0); }
      100% { opacity: 0; transform: translateY(-28px); }
    }
    .hud-life-delta {
      position: fixed;
      font-family: 'Courier New', monospace;
      font-size: 13px;
      font-weight: bold;
      pointer-events: none;
      z-index: 101;
      animation: life-delta-float 1.2s ease-out forwards;
    }
  `;
  document.head.appendChild(s);
}

/**
 * Spawn a floating +N / -N indicator near the life bar fill element.
 * @param delta - Signed life change value (positive = heal, negative = damage).
 */
function spawnLifeDelta(delta: number): void {
  ensureLifeDeltaStyle();
  const el = document.createElement('div');
  el.className = 'hud-life-delta';
  el.textContent = delta > 0 ? `+${delta}` : `${delta}`;
  el.style.color = delta > 0 ? '#33ff66' : 'rgba(220,50,50,0.9)';

  // Position near the life fill bar — right edge of bar + small offset
  const lifeEl = _lifeFillEl ?? document.getElementById('life-fill');
  if (lifeEl) {
    const rect = lifeEl.getBoundingClientRect();
    el.style.left = (rect.right + 4) + 'px';
    el.style.top = rect.top + 'px';
  } else {
    el.style.right = '80px';
    el.style.top = '20px';
  }

  document.body.appendChild(el);
  window.setTimeout(() => el.remove(), 1200);
}

/** Build and inject the run progress bar beneath the cards counter element. */
function buildProgressBar(): void {
  // Progress style — guard against duplicate injection
  if (!document.getElementById('hud-progress-style')) {
    const style = document.createElement('style');
    style.id = 'hud-progress-style';
    style.textContent = [
      '#hud-progress-bar{width:100%;height:3px;background:rgba(51,255,102,0.12);border-radius:2px;overflow:hidden;margin-top:2px;}',
      '#hud-progress-fill{height:100%;background:linear-gradient(90deg,#1a8833,#33ff66);border-radius:2px;transition:width 0.5s ease;}',
    ].join('');
    document.head.appendChild(style);
  }

  // Create bar only if cards-count element exists and bar not already present
  const cardsEl = document.getElementById('cards-count');
  if (!cardsEl || document.getElementById('hud-progress-bar')) return;

  const bar = document.createElement('div');
  bar.id = 'hud-progress-bar';

  const fill = document.createElement('div');
  fill.id = 'hud-progress-fill';
  fill.style.width = '0%';
  bar.appendChild(fill);

  // Insert bar immediately after cards-count element in its parent
  cardsEl.parentNode?.insertBefore(bar, cardsEl.nextSibling);
  _progressFillEl = fill;
}

/** Build the ogham active badge (top-center). Hidden by default. */
function buildOghamBadge(): void {
  const hud = document.getElementById('hud');
  if (!hud || document.getElementById('ogham-badge')) return;

  const badge = document.createElement('div');
  badge.id = 'ogham-badge';
  // C171: CRT ogham badge — gold accent retained (magical emphasis) with CRT border
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
    'background:rgba(3,5,3,0.85)',
    'border:1px solid rgba(205,170,80,0.55)',
    'border-left:2px solid rgba(205,170,80,0.9)',
    'border-radius:0 2px 2px 0',
    'padding:4px 14px',
    'font-family:"Courier New",Courier,monospace',
  ].join(';');
  _oghamBadgeEl = badge; // C121/HUD-01

  const runeSpan = document.createElement('span');
  runeSpan.id = 'ogham-badge-rune';
  runeSpan.style.cssText = 'color:#f0c040;font-size:18px;line-height:1;';
  badge.appendChild(runeSpan);
  _oghamRuneEl = runeSpan; // C121/HUD-01

  const nameSpan = document.createElement('span');
  nameSpan.id = 'ogham-badge-name';
  nameSpan.style.cssText = 'color:#f0c040;font-size:11px;font-family:"Courier New",Courier,monospace;font-weight:600;letter-spacing:2px;text-transform:uppercase;';
  badge.appendChild(nameSpan);
  _oghamNameEl = nameSpan; // C121/HUD-01

  const multSpan = document.createElement('span');
  multSpan.id = 'ogham-badge-mult';
  multSpan.style.cssText = [
    'color:#ffe680',
    'font-size:13px',
    'font-family:"Courier New",Courier,monospace',
    'font-weight:bold',
    'animation:ogham-pulse 1.2s ease-in-out infinite',
  ].join(';');
  badge.appendChild(multSpan);
  _oghamMultEl = multSpan; // C121/HUD-01

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
  // Use module-level cached refs (C121/HUD-01)
  if (!_oghamBadgeEl) return;

  const activeOgham = store.getState().run.activeOgham;
  if (!activeOgham) {
    _oghamBadgeEl.style.display = 'none';
    return;
  }

  const spec = OGHAM_SPECS[activeOgham];
  if (!spec) {
    _oghamBadgeEl.style.display = 'none';
    return;
  }

  if (_oghamRuneEl) _oghamRuneEl.textContent = spec.unicode;
  if (_oghamNameEl) _oghamNameEl.textContent = spec.name;
  if (_oghamMultEl) {
    // Show effect label: multiplier oghams show "x2", protection shows shield, etc.
    const params = spec.effect_params as Record<string, unknown>;
    if (typeof params['multiplier'] === 'number') {
      _oghamMultEl.textContent = ` \u00d7${params['multiplier']}`;
    } else if (spec.category === 'protection') {
      _oghamMultEl.textContent = ' prot.';
    } else {
      _oghamMultEl.textContent = ' actif';
    }
  }

  _oghamBadgeEl.style.display = 'flex';
}

/** Subscribe to store changes and auto-update HUD. */
export function initHUD(): void {
  buildFactionPanel();
  buildResourcePanel();
  buildOghamBadge();
  buildProgressBar();
  // Cache static HTML elements (created in index.html, not by build functions). C121/HUD-01.
  _lifeFillEl = document.getElementById('life-fill');
  _cardsCountEl = document.getElementById('cards-count');
  _progressFillEl = document.getElementById('hud-progress-fill');
  _biomeNameEl = document.getElementById('biome-name');
  _lifeBarContainerEl = document.getElementById('life-bar-container');
  _lifeStatusEl = document.getElementById('life-status');
  // Cache #hud root for setHUDWalkMode(). C163/HUD-WALK-01.
  _hudRootEl = document.getElementById('hud');
  // Walk starts immediately — HUD fully visible on run begin.
  if (_hudRootEl) { _hudRootEl.style.transition = 'opacity 0.4s ease'; _hudRootEl.style.opacity = '1'; }
  // Unsubscribe any previous subscription before re-subscribing — initHUD() is called
  // every run inside the while(true) loop so without this each run would accumulate an
  // extra Zustand subscriber causing updateHUD() to fire N times per state change.
  _hudUnsubscribe?.();
  _hudUnsubscribe = store.subscribe(updateHUD);
  updateHUD();
}

// =============================================================================
// C180 — HUD animation helpers: life damage flash + faction gain pulse
// =============================================================================

/**
 * Inject HUD animation keyframes once into document.head.
 * Idempotent — safe to call multiple times.
 */
function ensureHUDAnimStyles(): void {
  if (document.getElementById('hud-anim-styles')) return;
  const s = document.createElement('style');
  s.id = 'hud-anim-styles';
  s.textContent = `
    @keyframes hud-life-flash {
      0%   { color: #ff3333; text-shadow: 0 0 16px rgba(255,51,51,0.9); transform: scale(1.25); }
      60%  { color: #ff6666; text-shadow: 0 0 8px rgba(255,51,51,0.5); transform: scale(1.1); }
      100% { color: inherit; text-shadow: none; transform: scale(1); }
    }
    .life-damage-flash { animation: hud-life-flash 0.38s ease-out forwards !important; }
    @keyframes hud-faction-gain {
      0%   { opacity: 1; transform: translateY(0); }
      50%  { opacity: 0.7; transform: translateY(-4px); }
      100% { opacity: 1; transform: translateY(0); }
    }
    .faction-gain-pulse { animation: hud-faction-gain 0.3s ease-out forwards !important; }
  `;
  document.head.appendChild(s);
}

/**
 * Flash the life fill bar red briefly to signal damage taken.
 * Uses the cached `_lifeFillEl` reference (populated by initHUD).
 * No-op if element is not found.
 */
export function flashLifeDamage(): void {
  ensureHUDAnimStyles();
  const el = _lifeFillEl;
  if (!el) return;
  el.classList.remove('life-damage-flash');
  // Force reflow so re-adding the class always re-triggers the animation.
  void el.offsetWidth;
  el.classList.add('life-damage-flash');
  window.setTimeout(() => {
    el.classList.remove('life-damage-flash');
  }, 400);
}

/**
 * Pulse the faction bar fill upward briefly to signal a reputation gain.
 * @param factionName - A FactionId string (e.g. 'druides', 'ankou', …).
 * No-op if the element is not found.
 */
export function flashFactionGain(factionName: string): void {
  ensureHUDAnimStyles();
  const el = _factionFillEls[factionName as FactionId] ?? null;
  if (!el) return;
  el.classList.remove('faction-gain-pulse');
  void el.offsetWidth;
  el.classList.add('faction-gain-pulse');
  window.setTimeout(() => {
    el.classList.remove('faction-gain-pulse');
  }, 320);
}

// =============================================================================
// C259 — Ogham activation toast (top-right flash notification)
// =============================================================================

/**
 * Inject the hud-ogham-slide CSS keyframes once into document.head.
 * Idempotent — safe to call multiple times.
 */
function ensureOghamToastStyle(): void {
  if (document.getElementById('hud-ogham-toast-style')) return;
  const s = document.createElement('style');
  s.id = 'hud-ogham-toast-style';
  s.textContent = `
    @keyframes hud-ogham-slide {
      0%   { opacity:0; transform:translateX(20px); }
      15%  { opacity:1; transform:translateX(0); }
      75%  { opacity:1; transform:translateX(0); }
      100% { opacity:0; transform:translateX(10px); }
    }
  `;
  document.head.appendChild(s);
}

/**
 * Show a brief CeltOS-styled toast when an ogham is activated.
 * Reads OGHAM_SPECS[oghamId] for name + unicode glyph.
 * Creates #hud-ogham-toast at top-right; auto-removes after 2.5 s.
 * No-op if oghamId is not found in OGHAM_SPECS.
 */
export function showOghamActivated(oghamId: string): void {
  const spec = OGHAM_SPECS[oghamId];
  if (!spec) return;

  ensureOghamToastStyle();

  // Remove previous toast if still alive
  document.getElementById('hud-ogham-toast')?.remove();

  const toast = document.createElement('div');
  toast.id = 'hud-ogham-toast';
  toast.style.cssText = [
    'position:fixed',
    'top:80px',
    'right:16px',
    'background:rgba(1,8,2,0.92)',
    'border:1px solid rgba(51,255,102,0.4)',
    'border-left:3px solid #33ff66',
    'padding:6px 12px',
    'font-family:\'Courier New\',monospace',
    'font-size:11px',
    'color:#33ff66',
    'z-index:100',
    'pointer-events:none',
    'letter-spacing:0.15em',
    'animation:hud-ogham-slide 2.5s ease forwards',
  ].join(';');

  toast.textContent = `${spec.unicode} ${spec.name.toUpperCase()}`;
  document.body.appendChild(toast);

  window.setTimeout(() => {
    document.getElementById('hud-ogham-toast')?.remove();
  }, 2500);
}

// =============================================================================
// C296 — Faction reputation flash animation on rep change
// =============================================================================

/**
 * Inject the hud-faction-flash CSS transition classes once into document.head.
 * Idempotent — safe to call multiple times.
 */
function ensureHudFactionStyles(): void {
  if (document.getElementById('hud-faction-flash-style')) return;
  const s = document.createElement('style');
  s.id = 'hud-faction-flash-style';
  s.textContent = `.hud-fac-flash-up { transition: box-shadow 0.6s ease-out; }
.hud-fac-flash-down { transition: box-shadow 0.6s ease-out; }`;
  document.head.appendChild(s);
}

/** Module-level previous faction rep values — -1 means "not yet initialized". */
const _prevFactions: Record<string, number> = {};

/**
 * Update faction display and flash the faction row on changes ≥ 3 points.
 * - Green glow for reputation increase, red glow for decrease.
 * - Fires `reputation_up` or `reputation_down` SFX once per changed faction.
 * @param factions - Map of faction key → current reputation value (0-100).
 */
export function updateFactionDisplay(factions: Record<string, number>): void {
  ensureHudFactionStyles();

  for (const faction of Object.keys(factions)) {
    const newVal: number = factions[faction] ?? 0;
    const prevVal: number = _prevFactions[faction] ?? -1;

    if (prevVal !== -1) {
      const delta: number = newVal - prevVal;
      if (Math.abs(delta) >= 3) {
        const rowEl = document.getElementById(`hud-fac-${faction}`);
        if (rowEl) {
          if (delta > 0) {
            rowEl.style.transition = 'box-shadow 0.1s ease-in, box-shadow 0.5s ease-out 0.1s';
            rowEl.style.boxShadow = '0 0 12px rgba(51,255,102,0.8)';
            rowEl.classList.add('hud-fac-flash-up');
            rowEl.classList.remove('hud-fac-flash-down');
          } else {
            rowEl.style.transition = 'box-shadow 0.1s ease-in, box-shadow 0.5s ease-out 0.1s';
            rowEl.style.boxShadow = '0 0 12px rgba(255,60,60,0.6)';
            rowEl.classList.add('hud-fac-flash-down');
            rowEl.classList.remove('hud-fac-flash-up');
          }
          window.setTimeout(() => {
            rowEl.style.boxShadow = '';
            rowEl.classList.remove('hud-fac-flash-up', 'hud-fac-flash-down');
          }, 600);
        }

        const sfxSound: string = delta > 0 ? 'reputation_up' : 'reputation_down';
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: sfxSound } }));
      }
    }

    _prevFactions[faction] = newVal;
  }
}

/** Unsubscribe HUD from store — call when entering lair/menu to stop unnecessary renders. BUG-C88-06. */
export function teardownHUD(): void {
  _hudUnsubscribe?.();
  _hudUnsubscribe = null;
  // Clear element caches to avoid stale refs across runs. C121/HUD-01.
  _lifeFillEl = null;
  _cardsCountEl = null;
  _biomeNameEl = null;
  _lifeBarContainerEl = null;
  _lifeStatusEl = null;
  _anamEl = null;
  _currEl = null;
  _currLabelEl = null;
  for (const faction of FACTIONS) {
    delete _factionFillEls[faction];
    delete _factionValEls[faction];
  }
  _oghamBadgeEl = null;
  _oghamRuneEl = null;
  _oghamNameEl = null;
  _oghamMultEl = null;
  _progressFillEl = null;
  // C146/HUD-REINIT-01: remove dynamic panels from DOM so buildFactionPanel/buildResourcePanel/
  // buildOghamBadge fully reconstruct them on the next initHUD() call. Without removal, the
  // document.getElementById() guards inside each builder return early, leaving all module-level
  // refs null → faction bars, anam, currency and ogham badge freeze after the first run.
  document.getElementById('faction-panel')?.remove();
  document.getElementById('resource-panel')?.remove();
  document.getElementById('ogham-badge')?.remove();
  // C140/BUG-C140-01: predict toast lives on document.body — remove on run end to avoid z-index:65 overlap on RunSummary
  document.getElementById('merlin-predict-toast')?.remove();
  // C145b/NEW-HUD-01: ogham-badge-style <style> injected into document.head in buildOghamBadge().
  // Remove on teardown so it is cleanly re-injected on next initHUD(). Prevents stale <style> accumulation.
  document.getElementById('ogham-badge-style')?.remove();
  // C180: hud-anim-styles <style> injected by ensureHUDAnimStyles(). Remove on teardown.
  document.getElementById('hud-anim-styles')?.remove();
  // C225: progress bar — remove bar element and style from DOM on teardown.
  document.getElementById('hud-progress-bar')?.remove();
  document.getElementById('hud-progress-style')?.remove();
  // C240: reset critical alert flag and remove pulse style.
  _criticalAlerted = false;
  document.getElementById('hud-critical-style')?.remove();
  // C271: reset prev life tracker and remove delta style.
  _prevLife = -1;
  document.getElementById('hud-life-delta-style')?.remove();
  // C296: reset prev faction tracker and remove faction flash style.
  for (const key of Object.keys(_prevFactions)) {
    delete _prevFactions[key];
  }
  document.getElementById('hud-faction-flash-style')?.remove();
  // C259: remove ogham toast and its style on teardown.
  document.getElementById('hud-ogham-toast')?.remove();
  document.getElementById('hud-ogham-toast-style')?.remove();
  // C163/HUD-WALK-01: restore full opacity on teardown (lair/menu phases).
  if (_hudRootEl) { _hudRootEl.style.opacity = '1'; }
  _hudRootEl = null;
}
