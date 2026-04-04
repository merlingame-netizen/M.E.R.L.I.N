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
// C155/BUG-LAIR-04: module-level AbortController so innerHTML='' (which discards DOM nodes
// but NOT their listeners) is preceded by abort(). Each showOghamPanel() creates a fresh
// controller and passes its signal to every slot + skipBtn listener. On the next show(),
// the old controller is aborted before nodes are replaced — zero orphaned closures.
let _slotsAbortController: AbortController | null = null;

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
    'font-family:Courier New,monospace',
  ].join(';');

  const panel = document.createElement('div');
  panel.id = 'ogham-panel';
  panel.style.cssText = [
    'background:rgba(1,8,2,0.97)',
    'border:1px solid rgba(51,255,102,0.18)',
    'border-left:3px solid #1a8833',
    'border-radius:4px',
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

    // C155/BUG-LAIR-04: abort previous slot listeners before discarding nodes via innerHTML=''.
    // Without this, each showOghamPanel() call leaks up to 42 listeners (14 slots × 3 events
    // + skipBtn × 3) that are retained by the old DOM nodes until GC — on mobile/low-memory
    // devices these closures keep spec objects and state snapshots alive across card cycles.
    if (_slotsAbortController) {
      _slotsAbortController.abort();
      _slotsAbortController = null;
    }
    _slotsAbortController = new AbortController();
    const slotSignal = _slotsAbortController.signal;

    // Build panel content
    panelEl.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'Activer un Ogham ?';
    title.style.cssText = `color:#33ff66;font-size:14px;letter-spacing:0.18em;font-family:'Courier New',monospace;margin-bottom:6px;text-shadow:0 0 6px rgba(51,255,102,0.3);`;
    panelEl.appendChild(title);

    // Subtitle
    const sub = document.createElement('div');
    sub.textContent = 'Choisis un ogham avant de voir la carte, ou passe.';
    sub.style.cssText = `color:rgba(51,255,102,0.45);font-size:11px;font-family:'Courier New',monospace;margin-bottom:20px;`;
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
      // C128/C122-16: locked oghams announce lock status in aria-label — screen readers
      // cannot reach slot.title (tooltip) without hover; aria-label is the only announced text.
      // C132/BUG-C131-02: 3-way label — cooldown slots must announce cooldown, not just description.
      // A disabled button with only its description gives no hint about *why* it is unavailable
      // (WCAG 4.1.2 — name, role, value). Cooldown state is now surfaced as accessible text.
      slot.setAttribute(
        'aria-label',
        !isUnlocked
          ? `${spec.name} — Verrouillé, réputation 50 requise`
          : cooldown > 0
            ? `${spec.name} — En recharge, ${cooldown} carte${cooldown > 1 ? 's' : ''} restante${cooldown > 1 ? 's' : ''}`
            : `${spec.name} — ${spec.description}`,
      );
      // C86: use native `disabled` attribute instead of aria-disabled for unavailable slots.
      // aria-disabled='true' leaves the button in the tab order and still receives keyboard
      // Enter/Space events via browser default. `disabled` removes the button from tab order
      // and prevents all synthetic click/keyboard activation — correct WCAG 2.1.1 behavior.
      if (!isAvailable) slot.disabled = true;
      slot.style.cssText = [
        'width:100px',
        'padding:12px 8px',
        'border-radius:10px',
        'border:1px solid',
        `border-color:${isAvailable ? 'rgba(51,255,102,0.5)' : 'rgba(100,100,100,0.3)'}`,
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
      symbolEl.style.cssText = `font-size:28px;color:${isUnlocked ? 'rgba(51,255,102,0.90)' : 'rgba(51,255,102,0.22)'};line-height:1;`;
      slot.appendChild(symbolEl);

      // Ogham name
      const nameEl = document.createElement('div');
      nameEl.textContent = spec.name;
      nameEl.style.cssText = `font-size:11px;color:${isAvailable ? '#33ff66' : 'rgba(51,255,102,0.30)'};font-family:'Courier New',monospace;`;
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
        infoEl.style.cssText = 'font-size:10px;color:rgba(51,255,102,0.4);';
        slot.title = `${spec.description} (CD: ${spec.cooldown} cartes)`;
      }
      slot.appendChild(infoEl);

      if (isAvailable) {
        slot.addEventListener('click', () => selectOgham(oghamId), { signal: slotSignal });
        // C162/BUG-C131-03: touchend — on mobile pointerenter stays "stuck" after tap (no
        // pointerleave fires). Adding touchend fires selectOgham and prevents ghost click
        // via preventDefault(), which also stops the subsequent click event from firing twice.
        slot.addEventListener('touchend', (e) => {
          e.preventDefault();
          selectOgham(oghamId);
        }, { signal: slotSignal });
        // C148/OGHAM-HOVER-MOBILE-01: pointerenter/pointerleave fire on mouse AND touch (mobile).
        // mouseenter/mouseleave only fire for mouse → no hover feedback on touch screens.
        slot.addEventListener('pointerenter', () => {
          slot.style.background = 'rgba(139,69,19,0.4)';
          slot.style.borderColor = 'rgba(51,255,102,0.8)';
        }, { signal: slotSignal });
        slot.addEventListener('pointerleave', () => {
          slot.style.background = 'rgba(139,69,19,0.2)';
          slot.style.borderColor = 'rgba(51,255,102,0.5)';
        }, { signal: slotSignal });
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
      'background:rgba(26,136,51,0.10)',
      'color:rgba(51,255,102,0.55)',
      'border:1px solid rgba(51,255,102,0.20)',
      'border-radius:2px',
      'font-family:Courier New,monospace',
      'transition:background 0.2s',
    ].join(';');
    skipBtn.addEventListener('click', () => selectOgham(null), { signal: slotSignal });
    // C162/BUG-C131-03: touchend on skipBtn — mirrors same fix applied to slot buttons above.
    skipBtn.addEventListener('touchend', (e) => {
      e.preventDefault();
      selectOgham(null);
    }, { signal: slotSignal });
    // C148/OGHAM-HOVER-MOBILE-01: pointerenter/pointerleave — consistent with ogham slots above
    skipBtn.addEventListener('pointerenter', () => {
      skipBtn.style.background = 'rgba(80,80,90,0.5)';
    }, { signal: slotSignal });
    skipBtn.addEventListener('pointerleave', () => {
      skipBtn.style.background = 'rgba(80,80,90,0.3)';
    }, { signal: slotSignal });
    panelEl.appendChild(skipBtn);

    // Show overlay
    overlay.style.display = 'flex';
    // C86: move focus into dialog on open — WCAG 2.1 SC 2.1.2 (No Keyboard Trap requires
    // focus to be reachable inside the dialog when it opens). Focus the first available
    // slot, falling back to skipBtn if all oghams are locked/on cooldown.
    requestAnimationFrame(() => {
      // panelEl non-null: guarded by the null check at function entry (resolve(null) path)
      const firstAvailable = panelEl!.querySelector<HTMLButtonElement>('button:not([disabled])');
      (firstAvailable ?? skipBtn).focus();
    });
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
  // C155/BUG-LAIR-04: also abort slot listeners on external hide (scene transition, endRun)
  if (_slotsAbortController) {
    _slotsAbortController.abort();
    _slotsAbortController = null;
  }
  const overlay = document.getElementById('ogham-panel-overlay');
  if (overlay) overlay.style.display = 'none';
  // Resolve pending promise to prevent async deadlock on scene transitions (BUG-C58-03)
  if (resolveChoice) {
    resolveChoice(null);
    resolveChoice = null;
  }
}
