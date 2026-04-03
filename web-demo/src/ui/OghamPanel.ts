// =============================================================================
// Ogham Panel -- Equip/activate ogham before card choice
// Shows equipped oghams as clickable slots. Player picks one (or skips).
// Returns the selected ogham id or null if skipped.
// =============================================================================

import { store } from '../game/Store';
import { OGHAM_SPECS, type OghamSpec } from '../game/Constants';

// --- Panel state ---
let panelEl: HTMLElement | null = null;
let resolveChoice: ((oghamId: string | null) => void) | null = null;
let escapeHandler: ((e: KeyboardEvent) => void) | null = null;

/** Build the ogham panel DOM (called once at init). */
export function initOghamPanel(): void {
  const app = document.getElementById('app');
  if (!app || document.getElementById('ogham-panel-overlay')) return;

  const overlay = document.createElement('div');
  overlay.id = 'ogham-panel-overlay';
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-label', 'Sélection d\'Ogham — activer un pouvoir runique');
  overlay.style.cssText = [
    'position:fixed',
    'inset:0',
    'background:rgba(0,0,0,0.6)',
    'display:none',
    'align-items:center',
    'justify-content:center',
    'z-index:200',
    'font-family:system-ui',
  ].join(';');

  const panel = document.createElement('div');
  panel.id = 'ogham-panel';
  panel.style.cssText = [
    'background:rgba(20,20,30,0.95)',
    'border:1px solid rgba(205,133,63,0.4)',
    'border-radius:16px',
    'padding:24px',
    'max-width:480px',
    'width:90%',
    'text-align:center',
  ].join(';');

  overlay.appendChild(panel);
  app.appendChild(overlay);
  panelEl = panel;
}

/** Show the ogham panel and wait for player choice. */
export function showOghamPanel(): Promise<string | null> {
  return new Promise((resolve) => {
    const state = store.getState();

    const overlay = document.getElementById('ogham-panel-overlay');
    if (!overlay || !panelEl) {
      resolve(null);
      return;
    }

    resolveChoice = resolve;

    // Escape key handler — remove previous before adding (guard against double-show)
    if (escapeHandler) document.removeEventListener('keydown', escapeHandler);
    escapeHandler = (e: KeyboardEvent) => { if (e.key === 'Escape') selectOgham(null); };
    document.addEventListener('keydown', escapeHandler);

    // Build panel content
    panelEl.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'Activer un Ogham ?';
    title.style.cssText = 'color:#cd853f;font-size:20px;margin-bottom:6px;';
    panelEl.appendChild(title);

    // Subtitle
    const sub = document.createElement('div');
    sub.textContent = 'Choisis un ogham avant de voir la carte, ou passe.';
    sub.style.cssText = 'color:rgba(232,220,200,0.5);font-size:13px;margin-bottom:20px;';
    panelEl.appendChild(sub);

    // Ogham slots grid — T052: show ALL oghams, grey out locked ones
    // Faction names for locked tooltip (ogham branch -> faction display label)
    const BRANCH_LABEL: Readonly<Record<string, string>> = {
      central:   'Starter',
      druides:   'Druides',
      anciens:   'Anciens',
      korrigans: 'Korrigans',
      niamh:     'Niamh',
      ankou:     'Ankou',
    } as const;

    const grid = document.createElement('div');
    grid.style.cssText = 'display:flex;flex-wrap:wrap;gap:12px;justify-content:center;margin-bottom:20px;';

    for (const oghamId of Object.keys(OGHAM_SPECS)) {
      const spec = OGHAM_SPECS[oghamId];
      if (!spec) continue;

      const isUnlocked = state.meta.oghamsUnlocked.includes(oghamId);
      const cooldown = isUnlocked ? (state.run.oghamCooldowns[oghamId] ?? 0) : 0;
      const isAvailable = isUnlocked && cooldown <= 0;

      const slot = document.createElement('button');
      slot.setAttribute('aria-label', `${spec.name} — ${spec.description}`);
      slot.setAttribute('aria-disabled', String(!isAvailable));
      slot.style.cssText = [
        'width:100px',
        'padding:12px 8px',
        'border-radius:10px',
        'border:1px solid',
        `border-color:${isAvailable ? 'rgba(205,133,63,0.5)' : 'rgba(100,100,100,0.3)'}`,
        `background:${isAvailable ? 'rgba(139,69,19,0.2)' : 'rgba(40,40,50,0.4)'}`,
        'cursor:' + (isAvailable ? 'pointer' : 'not-allowed'),
        `opacity:${isUnlocked ? (isAvailable ? '1' : '0.5') : '0.35'}`,
        'display:flex',
        'flex-direction:column',
        'align-items:center',
        'gap:4px',
        'transition:background 0.2s, border-color 0.2s',
      ].join(';');

      // Ogham unicode symbol
      const symbolEl = document.createElement('div');
      symbolEl.textContent = spec.unicode;
      symbolEl.style.cssText = `font-size:28px;color:${isUnlocked ? '#e8dcc8' : 'rgba(180,180,180,0.4)'};line-height:1;`;
      slot.appendChild(symbolEl);

      // Ogham name
      const nameEl = document.createElement('div');
      nameEl.textContent = spec.name;
      nameEl.style.cssText = `font-size:11px;color:${isAvailable ? '#cd853f' : 'rgba(150,150,150,0.6)'};`;
      slot.appendChild(nameEl);

      // Status row: lock icon, cooldown, or category
      const infoEl = document.createElement('div');
      if (!isUnlocked) {
        const branchLabel = BRANCH_LABEL[spec.branch] ?? spec.branch;
        infoEl.textContent = '\uD83D\uDD12 rep 50';
        infoEl.style.cssText = 'font-size:10px;color:rgba(180,140,100,0.6);';
        slot.title = `D\u00e9bloquez ${branchLabel} \u2014 r\u00e9putation 50 requise`;
      } else if (cooldown > 0) {
        infoEl.textContent = `CD: ${cooldown}`;
        infoEl.style.cssText = 'font-size:10px;color:rgba(200,100,100,0.7);';
        slot.title = `${spec.description} (recharge dans ${cooldown} cartes)`;
      } else {
        infoEl.textContent = spec.category;
        infoEl.style.cssText = 'font-size:10px;color:rgba(232,220,200,0.4);';
        slot.title = `${spec.description} (CD: ${spec.cooldown} cartes)`;
      }
      slot.appendChild(infoEl);

      if (isAvailable) {
        slot.addEventListener('click', () => selectOgham(oghamId));
        slot.addEventListener('mouseenter', () => {
          slot.style.background = 'rgba(139,69,19,0.4)';
          slot.style.borderColor = 'rgba(205,133,63,0.8)';
        });
        slot.addEventListener('mouseleave', () => {
          slot.style.background = 'rgba(139,69,19,0.2)';
          slot.style.borderColor = 'rgba(205,133,63,0.5)';
        });
      }

      grid.appendChild(slot);
    }

    panelEl.appendChild(grid);

    // Skip button
    const skipBtn = document.createElement('button');
    skipBtn.id = 'ogham-skip-btn';
    skipBtn.textContent = 'Passer';
    skipBtn.style.cssText = [
      'padding:10px 32px',
      'font-size:14px',
      'cursor:pointer',
      'background:rgba(80,80,90,0.3)',
      'color:rgba(232,220,200,0.7)',
      'border:1px solid rgba(150,150,150,0.3)',
      'border-radius:8px',
      'font-family:system-ui',
      'transition:background 0.2s',
    ].join(';');
    skipBtn.addEventListener('click', () => selectOgham(null));
    skipBtn.addEventListener('mouseenter', () => {
      skipBtn.style.background = 'rgba(80,80,90,0.5)';
    });
    skipBtn.addEventListener('mouseleave', () => {
      skipBtn.style.background = 'rgba(80,80,90,0.3)';
    });
    panelEl.appendChild(skipBtn);

    // Show overlay
    overlay.style.display = 'flex';
  });
}

function selectOgham(oghamId: string | null): void {
  // Remove escape handler immediately to prevent double-fire
  if (escapeHandler) {
    document.removeEventListener('keydown', escapeHandler);
    escapeHandler = null;
  }

  const overlay = document.getElementById('ogham-panel-overlay');
  if (overlay) overlay.style.display = 'none';

  if (resolveChoice) {
    resolveChoice(oghamId);
    resolveChoice = null;
  }
}

/** Hide the ogham panel (cleanup). Call resolves any pending Promise to avoid async deadlock. */
export function hideOghamPanel(): void {
  if (escapeHandler) {
    document.removeEventListener('keydown', escapeHandler);
    escapeHandler = null;
  }
  const overlay = document.getElementById('ogham-panel-overlay');
  if (overlay) overlay.style.display = 'none';
  // Resolve pending promise to prevent async deadlock on scene transitions (BUG-C58-03)
  if (resolveChoice) {
    resolveChoice(null);
    resolveChoice = null;
  }
}
