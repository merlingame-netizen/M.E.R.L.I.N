// ═══════════════════════════════════════════════════════════════════════════════
// M.E.R.L.I.N. — Main Entry Point
// Gameplay loop: 3D walk → fade → card → choice → minigame → effects → return
// ═══════════════════════════════════════════════════════════════════════════════

import { SceneManager } from './engine/SceneManager';
import { CameraRail } from './engine/CameraRail';
// C147/BUNDLE-OVR-01: CoastBiome lazy-loaded — only needed when a run starts (line ~563).
// Static import was loading 442 lines of Three.js scene code at boot, inflating the initial
// bundle. Dynamic import defers it to first run, reducing cold-start gzip by ~5KB.
import { store } from './game/Store';
import { getMultiplier, getMultiplierLabel } from './game/Constants';
import { generateFastRouteCard, detectMinigame, verbToField } from './game/CardSystem';
import { runCeltOSIntro } from './ui/CeltOSIntro';
import { applyEffects, applyOghamEffect, processOghamModifiers } from './game/EffectEngine';
import { showCard } from './ui/CardOverlay';
import { initHUD, updateHUD, teardownHUD } from './ui/HUD';
import { fadeIn, fadeOut } from './ui/Transitions';
// Minigames are lazy-loaded on first use (dynamic import) to defer the ~21KB chunk
// until the player actually enters a run. vite.config.ts lets Rollup auto-split them.
import { initOghamPanel, showOghamPanel, hideOghamPanel } from './ui/OghamPanel';
import { getLLMAdapter, injectAPIKey, clearAPIKey } from './llm/GroqAdapter';
import { showRunSummary } from './ui/RunSummary';
import { initMainMenu } from './scenes/MainMenuScene';
import { initMerlinLair } from './scenes/MerlinLairScene';
import { runMerlinIntro } from './ui/MerlinIntro';
import { showMapGenOverlay } from './ui/MapGenOverlay';
import { cutToBlack, revealFromBlack } from './ui/SceneTransition';
import { initSFXManager, startAmbient, stopAmbient, biomeToAmbient } from './audio/SFXManager';

// --- Config ---
const WALK_SECONDS_BEFORE_CARD = 6; // Seconds of walking before showing a card
const WALK_SPEED = 0.04; // Rail progress per second

// --- Save detection ---
function hasSavedGame(): boolean {
  try {
    return (
      localStorage.getItem(ANAM_STORAGE_KEY) !== null ||
      localStorage.getItem(META_STORAGE_KEY) !== null
    );
  } catch {
    return false;
  }
}

// --- Main Menu (T061) ---
// Runs the cinematic Three.js cliff/sea scene.
// Returns { isNewGame: true } after 6s camera walk + MerlinIntro on first play,
// or { isNewGame: false } when player continues an existing save.
async function runMainMenu(): Promise<{ isNewGame: boolean }> {
  const wrapper = document.getElementById('menu-canvas-wrapper');
  const overlay = document.getElementById('main-menu-overlay');
  const startBtn = document.getElementById('menu-start-btn') as HTMLButtonElement | null;
  const continueBtn = document.getElementById('menu-continue-btn') as HTMLButtonElement | null;
  if (!wrapper || !overlay || !startBtn || !continueBtn) return { isNewGame: true };

  // Configure buttons based on save state
  const hasSave = hasSavedGame();
  if (hasSave) {
    startBtn.textContent = 'Nouvelle Partie';
    continueBtn.style.display = 'block';
  } else {
    startBtn.textContent = 'Commencer le Voyage';
    continueBtn.style.display = 'none';
  }

  wrapper.classList.add('visible');

  const menu = initMainMenu(wrapper);

  let menuAnimId = 0;
  let lastTime = performance.now();
  const tick = (): void => {
    menuAnimId = requestAnimationFrame(tick);
    const now = performance.now();
    const dt = Math.min((now - lastTime) / 1000, 0.05);
    lastTime = now;
    menu.update(dt);
  };

  // BUG-C53-03: protect RAF against WebGL context loss on mobile (initMainMenu throws)
  try {
    tick();

    // T066: Start menu ambient audio (gentle wind drone, 55Hz)
    startAmbient('menu');

    // Show menu UI immediately — camera is static until player acts
    overlay.classList.add('visible');

    // Wait for player choice
    const isNewGame = await new Promise<boolean>((resolve) => {
      startBtn.addEventListener('click', () => { playSound('click'); resolve(true); }, { once: true });
      continueBtn.addEventListener('click', () => { playSound('click'); resolve(false); }, { once: true });
    });

    // T066: Stop menu ambient
    stopAmbient();
    overlay.classList.remove('visible');

    if (isNewGame) {
      // Camera walks toward tower over 6s — play unlock tone at dolly start
      playSound('unlock');
      await new Promise<void>((resolve) => {
        menu.startDolly(resolve);
      });
    }

    cutToBlack();
    await new Promise<void>((res) => setTimeout(res, 300));

    return { isNewGame };
  } finally {
    cancelAnimationFrame(menuAnimId);
    menu.dispose();
    wrapper.classList.remove('visible');
    wrapper.style.display = 'none';
  }
}


// --- Lair Hub ---
// ── Biome picker overlay ──────────────────────────────────────────────────────
// Shows an 8-option Celtic biome selector inside the lair wrapper.
// Only cotes_sauvages currently has a 3D walk scene; the others are accepted
// by the Store and show the correct toast but share the same 3D backdrop
// until individual biome scenes are built.
function showBiomePicker(container: HTMLElement): Promise<string> {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Choisir un biome');
    overlay.style.cssText = [
      'position:absolute;inset:0;z-index:30;',
      'display:flex;flex-direction:column;align-items:center;justify-content:center;',
      'background:rgba(1,6,2,0.94);backdrop-filter:blur(3px);',
      'opacity:0;transition:opacity 0.2s ease;',
    ].join('');

    const title = document.createElement('div');
    title.textContent = '> BIOME_SELECT :: CHOIX_DESTINATION';
    title.style.cssText = [
      `color:#33ff66;font-family:'Courier New',monospace;font-size:clamp(11px,1.8vw,14px);`,
      `letter-spacing:0.12em;margin-bottom:6px;`,
      `text-shadow:0 0 8px rgba(51,255,102,0.4);`,
      `border-left:3px solid #1a8833;padding-left:10px;`,
    ].join('');
    overlay.appendChild(title);

    const subTitle = document.createElement('div');
    subTitle.textContent = '> SELECTION :: [8 BIOMES DISPONIBLES]';
    subTitle.style.cssText = [
      `color:#1a8833;font-family:'Courier New',monospace;font-size:clamp(9px,1.2vw,11px);`,
      `letter-spacing:0.08em;margin-bottom:20px;padding-left:13px;opacity:0.7;`,
    ].join('');
    overlay.appendChild(subTitle);

    const grid = document.createElement('div');
    grid.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:6px;max-width:420px;width:90%;';
    overlay.appendChild(grid);

    const BIOME_ENTRIES: Array<[string, string]> = [
      ['cotes_sauvages',    'Côtes Sauvages'],
      ['foret_broceliande', 'Forêt de Brocéliande'],
      ['marais_korrigans',  'Marais des Korrigans'],
      ['landes_bruyere',    'Landes de Bruyère'],
      ['cercles_pierres',   'Cercles de Pierres'],
      ['villages_celtes',   'Villages Celtes'],
      ['collines_dolmens',  'Collines aux Dolmens'],
      ['iles_mystiques',    'Îles Mystiques'],
    ];

    for (const [id, label] of BIOME_ENTRIES) {
      const btn = document.createElement('button');
      btn.textContent = `> ${label.toUpperCase()}`;
      btn.setAttribute('aria-label', `Biome: ${label}`);
      btn.style.cssText = [
        `background:rgba(2,10,4,0.92);border:1px solid rgba(26,136,51,0.45);`,
        `color:rgba(51,200,100,0.75);font-family:'Courier New',monospace;`,
        `font-size:clamp(9px,1.5vw,12px);`,
        `padding:10px 10px;cursor:pointer;letter-spacing:0.06em;text-align:left;`,
        `transition:background 0.12s,border-color 0.12s,color 0.12s;`,
        `border-left:2px solid transparent;`,
        'position:relative;',
      ].join('');
      // C151/MAIN-BIOMEPICKER-LEAK-01: named handlers so the click can removeEventListener
      // on the clicked button before overlay removal — 16 anonymous pointer listeners on
      // 8 detached buttons accumulated per lair visit without cleanup.
      const onBtnEnter = (): void => {
        btn.style.background = 'rgba(4,20,8,0.97)';
        btn.style.borderColor = 'rgba(51,255,102,0.75)';
        btn.style.borderLeftColor = '#33ff66';
        btn.style.color = '#33ff66';
        playSound('hover');
      };
      const onBtnLeave = (): void => {
        btn.style.background = 'rgba(2,10,4,0.92)';
        btn.style.borderColor = 'rgba(26,136,51,0.45)';
        btn.style.borderLeftColor = 'transparent';
        btn.style.color = 'rgba(51,200,100,0.75)';
      };
      btn.addEventListener('pointerenter', onBtnEnter);
      btn.addEventListener('pointerleave', onBtnLeave);
      btn.addEventListener('click', () => {
        playSound('click');
        btn.removeEventListener('pointerenter', onBtnEnter);
        btn.removeEventListener('pointerleave', onBtnLeave);
        document.removeEventListener('keydown', escapeHandler); // C138/BP-01
        overlay.style.opacity = '0';
        setTimeout(() => overlay.remove(), 220);
        resolve(id);
      });
      grid.appendChild(btn);
    }

    // C138/BP-01: Escape closes picker with default biome — prevents infinite game stall
    const defaultBiome = BIOME_ENTRIES[0]![0];
    const escapeHandler = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      document.removeEventListener('keydown', escapeHandler);
      overlay.style.opacity = '0';
      setTimeout(() => overlay.remove(), 220);
      resolve(defaultBiome);
    };
    document.addEventListener('keydown', escapeHandler);

    container.appendChild(overlay);
    requestAnimationFrame(() => requestAnimationFrame(() => { overlay.style.opacity = '1'; }));
  });
}

// C85: Journal panel — bookshelf zone shows cross-run meta stats
function showJournalPanel(): Promise<void> {
  return new Promise((resolve) => {
    const state = store.getState();
    const meta = state.meta;

    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Journal de Merlin');
    overlay.style.cssText = [
      'position:fixed;inset:0;z-index:200;',
      'display:flex;align-items:center;justify-content:center;',
      'background:rgba(0,0,0,0.65);opacity:0;transition:opacity 0.2s ease;',
    ].join('');

    const panel = document.createElement('div');
    panel.style.cssText = [
      `background:rgba(2,8,3,0.97);border:1px solid rgba(51,255,102,0.22);`,
      `padding:28px 32px;max-width:380px;width:88%;`,
      `font-family:'Courier New',monospace;color:#33ff66;`,
      `border-left:3px solid #1a8833;`,
    ].join('');

    const titleEl = document.createElement('div');
    titleEl.textContent = '> JOURNAL_MERLIN.dat';
    titleEl.style.cssText = [
      `color:#33ff66;font-size:clamp(13px,1.8vw,16px);letter-spacing:0.12em;`,
      `margin-bottom:4px;font-family:'Courier New',monospace;`,
      `text-shadow:0 0 8px rgba(51,255,102,0.35);`,
    ].join('');
    panel.appendChild(titleEl);

    const subEl = document.createElement('div');
    subEl.textContent = '> CHRONIQUES_AVENTURIER :: LECTURE';
    subEl.style.cssText = [
      `color:rgba(51,255,102,0.45);font-size:10px;letter-spacing:0.06em;margin-bottom:20px;`,
      `font-family:'Courier New',monospace;`,
    ].join('');
    panel.appendChild(subEl);

    const FACTION_DISPLAY: Record<string, string> = {
      druides: 'Druides', anciens: 'Anciens', korrigans: 'Korrigans', niamh: 'Niamh', ankou: 'Ankou',
    };
    const factionEntries = Object.entries(meta.factionRep).sort((a, b) => b[1] - a[1]);
    const topFaction = factionEntries[0];
    const rows: Array<[string, string]> = [
      ['Anam accumulé', `${Math.floor(meta.anam)}`],
      ['Aventures vécues', `${meta.totalRuns}`],
      ['Oghams maîtrisés', `${meta.oghamsUnlocked.length}`],
    ];
    if (topFaction && topFaction[1] > 0) {
      rows.push(['Alliance', `${FACTION_DISPLAY[topFaction[0]] ?? topFaction[0]} — ${topFaction[1]}`]);
    }

    const table = document.createElement('div');
    table.style.cssText = 'margin-bottom:22px;';
    for (const [label, value] of rows) {
      const row = document.createElement('div');
      row.style.cssText = [
        `display:flex;justify-content:space-between;align-items:center;padding:7px 0;`,
        `border-bottom:1px solid rgba(51,255,102,0.10);`,
      ].join('');
      const lEl = document.createElement('span');
      lEl.style.cssText = `color:rgba(51,255,102,0.55);font-size:12px;font-family:'Courier New',monospace;`;
      lEl.textContent = label;
      const vEl = document.createElement('span');
      vEl.style.cssText = `color:#33ff66;font-size:13px;font-family:'Courier New',monospace;`;
      vEl.textContent = value;
      row.appendChild(lEl);
      row.appendChild(vEl);
      table.appendChild(row);
    }
    panel.appendChild(table);

    const closeBtn = document.createElement('button');
    closeBtn.textContent = 'Fermer';
    closeBtn.setAttribute('aria-label', 'Fermer le journal');
    closeBtn.style.cssText = [
      `padding:10px 32px;font-size:12px;cursor:pointer;`,
      `background:rgba(4,16,6,0.5);color:#33ff66;`,
      `border:1px solid rgba(51,255,102,0.35);`,
      `font-family:'Courier New',monospace;transition:background 0.12s;`,
      `letter-spacing:0.08em;`,
    ].join('');
    // C151/MAIN-JOURNAL-LEAK-01: named handlers so dismiss() can removeEventListener
    // before overlay removal — 2 anonymous pointer listeners on detached closeBtn per visit.
    const onCloseBtnEnter = (): void => { closeBtn.style.background = 'rgba(8,30,12,0.85)'; closeBtn.style.borderColor = 'rgba(51,255,102,0.7)'; };
    const onCloseBtnLeave = (): void => { closeBtn.style.background = 'rgba(4,16,6,0.5)'; closeBtn.style.borderColor = 'rgba(51,255,102,0.35)'; };
    closeBtn.addEventListener('pointerenter', onCloseBtnEnter);
    closeBtn.addEventListener('pointerleave', onCloseBtnLeave);
    closeBtn.addEventListener('click', dismiss);
    panel.appendChild(closeBtn);
    overlay.appendChild(panel);
    document.body.appendChild(overlay);
    requestAnimationFrame(() => requestAnimationFrame(() => { overlay.style.opacity = '1'; }));

    function dismiss(): void {
      closeBtn.removeEventListener('pointerenter', onCloseBtnEnter);
      closeBtn.removeEventListener('pointerleave', onCloseBtnLeave);
      document.removeEventListener('keydown', escHandler);
      overlay.style.opacity = '0';
      setTimeout(() => { overlay.remove(); resolve(); }, 220);
    }
    function escHandler(e: KeyboardEvent): void { if (e.key === 'Escape') dismiss(); }
    document.addEventListener('keydown', escHandler);
  });
}

// C164: Groq API key settings modal — lets player inject key at runtime on Vercel
function showGroqSettingsModal(): Promise<void> {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Paramètres LLM');
    overlay.style.cssText = [
      'position:fixed;inset:0;z-index:500;',
      'display:flex;align-items:center;justify-content:center;',
      'background:rgba(0,0,0,0.75);opacity:0;transition:opacity 0.2s ease;',
    ].join('');

    const panel = document.createElement('div');
    panel.style.cssText = [
      'background:rgba(5,10,5,0.98);border:1px solid rgba(51,255,102,0.5);',
      'border-radius:8px;padding:24px 28px;max-width:400px;width:90%;',
      'font-family:"Courier New",Courier,monospace;color:#33ff66;',
    ].join('');

    const title = document.createElement('div');
    title.textContent = '[ CONFIG_LLM ]';
    title.style.cssText = 'font-size:16px;letter-spacing:0.15em;margin-bottom:4px;color:#33ff66;';
    panel.appendChild(title);

    const sub = document.createElement('div');
    sub.textContent = 'Clé API Groq (tab-session uniquement)';
    sub.style.cssText = 'color:rgba(51,255,102,0.5);font-size:11px;margin-bottom:18px;';
    panel.appendChild(sub);

    const hasKey = getLLMAdapter() !== null;
    const status = document.createElement('div');
    status.textContent = hasKey ? '▶ MODE: CLOUD (Groq actif)' : '▶ MODE: LOCAL (FastRoute)';
    status.style.cssText = `color:${hasKey ? '#33ff66' : '#ffaa33'};font-size:12px;margin-bottom:14px;`;
    panel.appendChild(status);

    const input = document.createElement('input');
    input.type = 'password';
    input.placeholder = 'gsk_…';
    input.setAttribute('aria-label', 'Clé API Groq');
    input.style.cssText = [
      'width:100%;box-sizing:border-box;padding:8px 10px;',
      'background:rgba(0,20,5,0.9);border:1px solid rgba(51,255,102,0.4);',
      'border-radius:4px;color:#33ff66;font-family:"Courier New",Courier,monospace;',
      'font-size:13px;outline:none;margin-bottom:14px;',
    ].join('');
    panel.appendChild(input);

    const feedback = document.createElement('div');
    feedback.style.cssText = 'font-size:11px;min-height:16px;margin-bottom:14px;';
    panel.appendChild(feedback);

    const btnRow = document.createElement('div');
    btnRow.style.cssText = 'display:flex;gap:10px;justify-content:flex-end;';

    const applyBtn = document.createElement('button');
    applyBtn.textContent = 'Appliquer';
    applyBtn.style.cssText = [
      'padding:8px 18px;font-family:"Courier New",Courier,monospace;font-size:13px;cursor:pointer;',
      'background:rgba(0,40,10,0.8);color:#33ff66;border:1px solid rgba(51,255,102,0.6);border-radius:4px;',
    ].join('');
    applyBtn.addEventListener('click', () => {
      const ok = injectAPIKey(input.value);
      if (ok) {
        feedback.style.color = '#33ff66';
        feedback.textContent = '✓ Clé acceptée — mode cloud actif';
        status.textContent = '▶ MODE: CLOUD (Groq actif)';
        status.style.color = '#33ff66';
      } else {
        feedback.style.color = '#ff4444';
        feedback.textContent = '✗ Clé invalide (min 10 caractères)';
      }
    });

    const clearBtn = document.createElement('button');
    clearBtn.textContent = 'Effacer';
    clearBtn.style.cssText = [
      'padding:8px 18px;font-family:"Courier New",Courier,monospace;font-size:13px;cursor:pointer;',
      'background:rgba(20,5,0,0.8);color:#ff8833;border:1px solid rgba(255,136,51,0.4);border-radius:4px;',
    ].join('');
    clearBtn.addEventListener('click', () => {
      clearAPIKey();
      input.value = '';
      feedback.style.color = '#ff8833';
      feedback.textContent = '— Clé supprimée — mode FastRoute';
      status.textContent = '▶ MODE: LOCAL (FastRoute)';
      status.style.color = '#ffaa33';
    });

    const closeBtn = document.createElement('button');
    closeBtn.textContent = 'Fermer';
    closeBtn.setAttribute('aria-label', 'Fermer les paramètres LLM');
    closeBtn.style.cssText = [
      'padding:8px 18px;font-family:"Courier New",Courier,monospace;font-size:13px;cursor:pointer;',
      'background:rgba(10,10,10,0.8);color:rgba(51,255,102,0.6);border:1px solid rgba(51,255,102,0.2);border-radius:4px;',
    ].join('');
    closeBtn.addEventListener('click', dismiss);

    btnRow.appendChild(clearBtn);
    btnRow.appendChild(applyBtn);
    btnRow.appendChild(closeBtn);
    panel.appendChild(btnRow);
    overlay.appendChild(panel);
    document.body.appendChild(overlay);
    requestAnimationFrame(() => requestAnimationFrame(() => { overlay.style.opacity = '1'; }));

    function dismiss(): void {
      document.removeEventListener('keydown', escHandler);
      overlay.style.opacity = '0';
      setTimeout(() => { overlay.remove(); resolve(); }, 220);
    }
    function escHandler(e: KeyboardEvent): void { if (e.key === 'Escape') dismiss(); }
    document.addEventListener('keydown', escHandler);
    // Focus input
    requestAnimationFrame(() => input.focus());
  });
}

async function runMerlinLair(app: HTMLElement): Promise<{ biomeId: string; lairOgham: string | null }> {
  // Create wrapper div dynamically (static placement in index.html preferred)
  let wrapper = document.getElementById('lair-canvas-wrapper') as HTMLDivElement | null;
  if (!wrapper) {
    wrapper = document.createElement('div');
    wrapper.id = 'lair-canvas-wrapper';
    wrapper.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;z-index:10;';
    (app.parentElement ?? document.body).appendChild(wrapper);
  }
  wrapper.style.display = 'block';
  wrapper.setAttribute('role', 'region');
  wrapper.setAttribute('aria-label', 'Antre de Merlin');

  const lair = initMerlinLair(wrapper);

  // Wire real-time clock to day/night/season — purely cosmetic
  const now = new Date();
  const seasonIndex = Math.floor(((now.getMonth() + 1) % 12) / 3);
  lair.setTime({
    hour: now.getHours() + now.getMinutes() / 60,
    season: (['winter', 'spring', 'summer', 'autumn'] as const)[seasonIndex] ?? 'spring',
  });

  let rafId = 0;
  let lastTs = performance.now();
  // C133/REVEAL-RACE-01: defer revealFromBlack until first rendered frame so the overlay
  // never fades over a blank WebGL canvas on slow mobile / cold GLB cache.
  let _firstFrame = true;
  const tick = (): void => {
    rafId = requestAnimationFrame(tick);
    const t = performance.now();
    const dt = Math.min((t - lastTs) / 1000, 0.05);
    lastTs = t;
    lair.update(dt);
    if (_firstFrame) {
      _firstFrame = false;
      revealFromBlack(800);
    }
  };
  // C104: pause/resume lair rAF when tab is hidden — saves GPU/CPU/battery on mobile
  const onLairVisibility = (): void => {
    if (document.visibilityState === 'hidden') {
      cancelAnimationFrame(rafId);
      rafId = 0;
    } else if (rafId === 0) {
      lastTs = performance.now(); // reset to prevent dt spike on resume
      tick();
    }
  };
  document.addEventListener('visibilitychange', onLairVisibility);
  tick();

  // Chosen biome — defaults to cotes_sauvages until player picks via map zone.
  let selectedBiomeId = 'cotes_sauvages';
  // C84: ogham pre-selected in lair, carried into first card of the upcoming run
  let lairSelectedOgham: string | null = null;
  // C85: cauldron zone cycles through Merlin quotes
  let cauldronQuoteIdx = -1;
  const MERLIN_QUOTES: readonly string[] = [
    'Le temps est une rivière qui coule à rebours pour les initiés…',
    'Chaque Ogham que tu maîtrises ouvre un nouveau chemin dans la forêt.',
    'Ton Anam grandit avec chaque choix courageux. Garde-le précieux.',
    'Les factions observent. Ce que tu fais dans l\'ombre forge ta légende.',
    'La mort n\'est qu\'un passage. L\'Anam, lui, demeure à jamais.',
    'Brocéliande te connaît mieux que tu ne te connais toi-même.',
  ];

  // Zone labels shown as brief toast for non-door zones
  const ZONE_LABELS: Record<string, { title: string; sub: string }> = {
    map:       { title: 'Carte des Biomes',    sub: 'Vers quelle contrée vous aventurer ?' }, // C45: Celtic register + CTA (was generic "Choisissez votre destination")
    crystal:   { title: 'Pierre des Oghams',   sub: 'Choisissez votre Ogham runique' },
    bookshelf: { title: 'Journal de Merlin',   sub: 'Les pages sont encore en gestation' },
    cauldron:  { title: 'Chaudron Druidique',  sub: 'L\'anam doit d\'abord s\'éveiller' },
    door:      { title: 'Entrer dans la forêt', sub: '→ Commencer l\'aventure' },
    skull:     { title: 'Crâne du Sage',        sub: 'Les anciens druides méditaient face à la mort' }, // C79: skull hover lore fallback (click is no-op but toast fires)
  };
  let activeToast: HTMLDivElement | null = null;
  let activeToastFadeId: ReturnType<typeof setTimeout> | null = null;
  let activeToastRemoveId: ReturnType<typeof setTimeout> | null = null;
  // C154/LAIR-03: track confirmToast timers separately — these are not part of showZoneToast
  // and were previously untracked, leaking into the next lair session on fast door-click.
  let confirmToastFadeId: ReturnType<typeof setTimeout> | null = null;
  let confirmToastRemoveId: ReturnType<typeof setTimeout> | null = null;

  const showZoneToast = (zone: string): void => {
    // Cancel any in-flight fade/remove timers before replacing the toast
    if (activeToastFadeId !== null) { clearTimeout(activeToastFadeId); activeToastFadeId = null; }
    if (activeToastRemoveId !== null) { clearTimeout(activeToastRemoveId); activeToastRemoveId = null; }
    if (activeToast) { activeToast.remove(); activeToast = null; }
    const entry = ZONE_LABELS[zone] ?? { title: zone, sub: '' };
    const toast = document.createElement('div');
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');
    toast.setAttribute('aria-atomic', 'true');
    toast.style.cssText = [
      'position:absolute;bottom:15%;left:50%;transform:translateX(-50%);',
      `background:rgba(1,6,2,0.92);border:1px solid rgba(51,255,102,0.28);`,
      `border-left:2px solid #1a8833;padding:10px 24px;pointer-events:none;z-index:20;`,
      `color:#33ff66;font-family:'Courier New',monospace;font-size:clamp(11px,2vw,13px);`,
      `letter-spacing:0.1em;text-align:left;`,
      'opacity:0;transition:opacity 0.2s ease;',
    ].join('');
    // C106: textContent — closes C104 scope (was missed in main.ts showZoneToast)
    const titleEl = document.createElement('span');
    titleEl.textContent = entry.title;
    toast.appendChild(titleEl);
    if (entry.sub) {
      toast.appendChild(document.createElement('br'));
      const subEl = document.createElement('span');
      subEl.style.cssText = 'color:rgba(180,150,90,0.6);font-size:0.8em;font-style:italic;';
      subEl.textContent = entry.sub;
      toast.appendChild(subEl);
    }
    wrapper!.appendChild(toast);
    activeToast = toast;
    requestAnimationFrame(() => requestAnimationFrame(() => { toast.style.opacity = '1'; }));
    activeToastFadeId = setTimeout(() => {
      activeToastFadeId = null;
      toast.style.opacity = '0';
      activeToastRemoveId = setTimeout(() => {
        activeToastRemoveId = null;
        toast.remove();
        if (activeToast === toast) activeToast = null;
      }, 220);
    }, 1800);
  };

  // Wait for door click (only zone that starts a run)
  await new Promise<void>((resolve) => {
    let doorTriggered = false; // C117/MAIN-01: prevent concurrent overlay fire on fast mobile double-tap during 600ms cinematic
    lair.onZoneClick(async (zone) => {
      if (zone === 'door') {
        if (doorTriggered) return;
        doorTriggered = true;
        showZoneToast('door'); // "Entrer dans la forêt" — 600ms total: 200ms fade-in + 400ms fully visible (C45: was 400ms = only 200ms readable)
        setTimeout(resolve, 600);
        return;
      }
      if (doorTriggered) return; // C117/MAIN-01: block all zone interactions after door click
      if (zone === 'crystal') {
        // C84: show ogham panel for pre-run selection — result carried into first card
        playSound('crystal');
        lairSelectedOgham = await showOghamPanel();
        if (lairSelectedOgham) {
          showZoneToast('crystal'); // "Pierre des Oghams / Choisissez votre Ogham runique"
        }
        return;
      }
      if (zone === 'bookshelf') {
        // C85: journal panel — shows cross-run meta stats (anam, runs, oghams, top faction)
        await showJournalPanel();
        return;
      }
      if (zone === 'cauldron') {
        // C85: Merlin quotes — cycle through 6 druidic whispers
        playSound('cauldron');
        cauldronQuoteIdx = (cauldronQuoteIdx + 1) % MERLIN_QUOTES.length;
        ZONE_LABELS['cauldron']!.title = 'Merlin murmure…';
        ZONE_LABELS['cauldron']!.sub = MERLIN_QUOTES[cauldronQuoteIdx]!;
        showZoneToast('cauldron');
        return;
      }
      if (zone === 'map') {
        // Biome picker — shows 8-option overlay, player selects destination
        selectedBiomeId = await showBiomePicker(wrapper!);
        const pickedLabel = BIOME_LABELS[selectedBiomeId] ?? selectedBiomeId;
        showZoneToast('map'); // brief "Carte des Biomes / Choisissez…" toast replaced
        // Show chosen biome confirmation
        const confirmToast = document.createElement('div');
        confirmToast.style.cssText = [
          'position:absolute;bottom:8%;left:50%;transform:translateX(-50%);',
          `background:rgba(1,6,2,0.92);border:1px solid rgba(51,255,102,0.28);`,
          `border-left:2px solid #33ff66;padding:8px 20px;pointer-events:none;z-index:20;`,
          `color:#33ff66;font-family:'Courier New',monospace;font-size:clamp(11px,1.8vw,13px);`,
          `letter-spacing:0.1em;text-align:left;opacity:0;transition:opacity 0.2s;`,
        ].join('');
        confirmToast.setAttribute('role', 'status');
        confirmToast.setAttribute('aria-live', 'polite');
        confirmToast.textContent = `Destination : ${pickedLabel}`;
        wrapper!.appendChild(confirmToast);
        requestAnimationFrame(() => requestAnimationFrame(() => { confirmToast.style.opacity = '1'; }));
        // C154/LAIR-03: track both timer handles so teardown can cancel them on fast door-click
        confirmToastFadeId = setTimeout(() => {
          confirmToastFadeId = null;
          confirmToast.style.opacity = '0';
          confirmToastRemoveId = setTimeout(() => { confirmToastRemoveId = null; confirmToast.remove(); }, 220);
        }, 2200);
        return;
      }
      showZoneToast(zone);
    });
  });

  cancelAnimationFrame(rafId);
  document.removeEventListener('visibilitychange', onLairVisibility); // C104: remove lair-specific listener
  // BUG-06: clear in-flight toast timers before dispose to avoid stale DOM writes
  if (activeToastFadeId !== null) { clearTimeout(activeToastFadeId); activeToastFadeId = null; }
  if (activeToastRemoveId !== null) { clearTimeout(activeToastRemoveId); activeToastRemoveId = null; }
  // C154/LAIR-03: cancel confirmToast timers — untracked before this fix, could fire against
  // the reused wrapper in the next lair session on rapid biome-pick → door-click (<2.2s).
  if (confirmToastFadeId !== null) { clearTimeout(confirmToastFadeId); confirmToastFadeId = null; }
  if (confirmToastRemoveId !== null) { clearTimeout(confirmToastRemoveId); confirmToastRemoveId = null; }
  activeToast = null; // Timers cleared above — toast element hidden with wrapper
  cutToBlack();
  await new Promise<void>((res) => setTimeout(res, 300));
  lair.dispose();
  wrapper.style.display = 'none';
  return { biomeId: selectedBiomeId, lairOgham: lairSelectedOgham };
}

// --- Bootstrap ---
async function main(): Promise<void> {
  const app = document.getElementById('app')!;
  const loading = document.getElementById('loading')!;

  // SFX: init early so first interaction resumes AudioContext
  initSFXManager();

  // C164: Groq settings gear button — persistent, bottom-right, CRT style
  const gearBtn = document.createElement('button');
  gearBtn.textContent = '⚙';
  gearBtn.setAttribute('aria-label', 'Paramètres LLM Groq');
  gearBtn.setAttribute('title', 'Configurer la clé API Groq');
  gearBtn.style.cssText = [
    'position:fixed;bottom:14px;right:14px;z-index:9990;',
    'width:36px;height:36px;border-radius:50%;',
    'background:rgba(0,20,5,0.75);border:1px solid rgba(51,255,102,0.35);',
    'color:rgba(51,255,102,0.65);font-size:18px;cursor:pointer;',
    'display:flex;align-items:center;justify-content:center;',
    'transition:background 0.15s,border-color 0.15s,color 0.15s;',
    'font-family:"Courier New",Courier,monospace;',
  ].join('');
  gearBtn.addEventListener('pointerenter', () => {
    gearBtn.style.background = 'rgba(0,40,10,0.9)';
    gearBtn.style.borderColor = 'rgba(51,255,102,0.75)';
    gearBtn.style.color = '#33ff66';
  });
  gearBtn.addEventListener('pointerleave', () => {
    gearBtn.style.background = 'rgba(0,20,5,0.75)';
    gearBtn.style.borderColor = 'rgba(51,255,102,0.35)';
    gearBtn.style.color = 'rgba(51,255,102,0.65)';
  });
  gearBtn.addEventListener('click', () => showGroqSettingsModal());
  document.body.appendChild(gearBtn);

  // BUG-01: Save cross-run data on sudden tab close or mobile backgrounding
  const emergencySave = (): void => { saveAnamToStorage(); saveMetaToStorage(); };
  window.addEventListener('beforeunload', emergencySave);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') emergencySave();
  });

  // Phase 1: CeltOS intro (terminal boot + pixel logo + real asset preload)
  // loadTemplates() is called inside runCeltOSIntro Phase 3 (loading bar = real fetch progress)
  await runCeltOSIntro();

  // C156/BUG-LOAD-01: #loading has CSS display:flex (z-index:100). Hide immediately after CeltOS
  // so the main menu and lair are never covered. Phase 3 (run init) re-shows it when needed.
  loading.style.display = 'none';

  // Phase 2: Main menu (once — never shown again between runs)
  const menuResult = await runMainMenu();

  // C84: Init ogham panel + cross-run data BEFORE first lair visit (once — panel persists across runs)
  initOghamPanel();
  loadAnamFromStorage();
  loadMetaFromStorage();

  // Phase 2b: Merlin intro dialogue — shown only on new game (walk animation already played)
  if (menuResult.isNewGame) {
    await runMerlinIntro();
  }

  // BUG-03: Outer run loop — lair → walk → run → lair → walk → run ...
  // Without this the page is a dead-end after the first run.
  while (true) {
    // Phase 2b: Lair Hub — returns chosen biome + optional pre-selected ogham
    const lairResult = await runMerlinLair(app);
    const chosenBiome = lairResult.biomeId;

    // Phase 2c: Map generation overlay — parchment + LLM scenario + progressive map painting
    // C158: showMapGenOverlay handles its own fade-in/out; it resolves when player clicks
    // "Entrer" (or auto-continues after 8s). Disguises scene init latency as narrative UX.
    await showMapGenOverlay(chosenBiome);

    // Phase 3: Reveal and enter game
    loading.style.display = 'flex';
    loading.style.opacity = '1';
    // C167: brief CRT-style loading label so player sees feedback during scene init
    loading.innerHTML = `<div style="color:#33ff66;font-family:'Courier New',Courier,monospace;font-size:13px;letter-spacing:0.1em;">INIT_BIOME: ${chosenBiome.replace(/_/g, '-').toUpperCase()}…</div>`;

    // Init scene (fresh per run)
    const sceneManager = new SceneManager(app);

    // Build biome scene — lazy dynamic imports keep initial bundle small.
    // C157: foret_broceliande gets its own dedicated forest scene; all others → coast.
    let biomeResult: import('./scenes/CoastBiome').BiomeSceneResult;
    if (chosenBiome === 'foret_broceliande') {
      const { buildForestScene } = await import('./scenes/BroceliandForest');
      biomeResult = await buildForestScene();
    } else if (chosenBiome === 'cotes_sauvages') {
      // C147/BUNDLE-OVR-01: lazy dynamic import — deferred from startup to first run start.
      const { buildCoastScene } = await import('./scenes/CoastBiome');
      biomeResult = await buildCoastScene();
    } else {
      // C161: remaining 6 biomes use parametric GenericBiome scene
      const { buildGenericBiomeScene } = await import('./scenes/GenericBiome');
      biomeResult = await buildGenericBiomeScene(chosenBiome);
    }
    sceneManager.scene.add(biomeResult.group);

    // C166: Apply biome-specific fog — read from group properties (Forest/Coast) or userData (Generic).
    // Overrides SceneManager's default dark-blue fog so each biome has correct atmospheric colour.
    {
      const g = biomeResult.group as typeof biomeResult.group & { fogColor?: number; fogDensity?: number };
      const fogColor: number  = g.fogColor ?? (g.userData['fogColor'] as number | undefined) ?? 0x1a2a3a;
      const fogDensity: number = g.fogDensity ?? (g.userData['fogDensity'] as number | undefined) ?? 0.015;
      sceneManager.updateFog(fogColor, fogDensity);
    }

    // Camera rail — biome-specific path
    const rail = chosenBiome === 'foret_broceliande'
      ? CameraRail.createForestPath()
      : chosenBiome === 'cotes_sauvages'
        ? CameraRail.createCoastalPath()
        : CameraRail.createGenericPath();
    rail.setSpeed(WALK_SPEED);

    // Footstep SFX timer — fires 'step' every 0.5s while rail is walking (2Hz bob cadence)
    let stepTimer = 0;
    sceneManager.onUpdate((dt) => {
      rail.update(sceneManager.camera, dt);
      biomeResult.update(dt);
      if (!rail.isPaused()) {
        stepTimer += dt;
        if (stepTimer >= 0.5) {
          stepTimer -= 0.5;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'step' } }));
        }
      }
    });

    // Start renderer
    sceneManager.start();

    // C118: pause 3D render when tab is hidden during gameplay (matches lair C104 pattern)
    const onGameVisibility = (): void => {
      if (document.visibilityState === 'hidden') sceneManager.stop();
      else sceneManager.start();
    };
    document.addEventListener('visibilitychange', onGameVisibility);

    // T066+C75: Start biome-matched ambient audio as game world reveals
    startAmbient(biomeToAmbient(chosenBiome));

    // Hide loading screen and reveal game (clear scene-transition black overlay)
    loading.innerHTML = ''; // C167: clear biome label before hiding
    loading.style.opacity = '0';
    loading.style.transition = 'opacity 0.5s';
    setTimeout(() => { loading.style.display = 'none'; }, 500);
    revealFromBlack(600);

    // Init HUD (ogham panel already built at startup line 523 — idempotent, BUG-C88-04 removed)
    initHUD();

    // C88-01: loadAnamFromStorage/loadMetaFromStorage removed from loop body — they are
    // called once at startup (lines 524-525). Re-loading here every run overwrites
    // in-memory meta state that accumulated since the last save, corrupting cross-run Anam.
    // saveAnamToStorage() fires at every end-of-run path (death/cards_limit/victory) so
    // the storage state is always current when the next run starts.

    // Start run with the biome the player chose at the map zone
    store.getState().startRun(chosenBiome);
    // C88-02: explicitly reset activeOgham before applying lair selection — startRun()
    // does not clear it. If the prior run exited via death_drain (step 3, before step 8
    // where setActiveOgham('') normally fires), the stale ogham persists and fires
    // silently on the next run's first card without player activation.
    store.getState().setActiveOgham('');
    // C84: apply lair-pre-selected ogham — carried into first card automatically
    if (lairResult.lairOgham) {
      store.getState().setActiveOgham(lairResult.lairOgham);
    }
    updateHUD();
    showBiomeToast(chosenBiome);

    // --- Gameplay Loop ---
    await gameLoop(sceneManager, rail, biomeResult.update);

    // BUG-C88-06: unsubscribe HUD from store — run is over, no point firing updateHUD()
    // during the lair phase for invisible HUD elements.
    teardownHUD();

    // C118: remove gameplay visibility listener before dispose
    document.removeEventListener('visibilitychange', onGameVisibility);

    // BUG-02 / C79-07: dispose() = stop rAF + removeEventListener(resize) + renderer.dispose()
    sceneManager.dispose();
    stopAmbient();
    biomeResult.dispose();

    // Fade to black before returning to lair for next run
    cutToBlack();
    await waitSeconds(0.5);
  }
}

async function gameLoop(
  sceneManager: SceneManager,
  rail: CameraRail,
  biomeUpdate: (dt: number) => void
): Promise<void> {
  const state = store.getState;

  // Resolve once before the loop — consistent with CardOverlay null-guard pattern (C61)
  const minigameContainer = document.getElementById('minigame-container');
  const minigameOverlay = document.getElementById('minigame-overlay');
  if (!minigameContainer || !minigameOverlay) return;

  let _loopSafety = 0; // C104: ceiling guard — run.active + 30-card limit are primary bounds
  // C98: idempotency guard — prevents double-save if startRun() were ever re-entered or called twice.
  // Sequential break paths already prevent double-save in practice, but this makes the contract explicit.
  let savedThisRun = false;
  const saveRunEnd = (): void => {
    if (savedThisRun) return;
    savedThisRun = true;
    saveAnamToStorage();
    saveMetaToStorage();
  };
  while (state().run.active) {
    if (++_loopSafety > 60) { // C104: hard ceiling
      state().endRun('safety');
      saveRunEnd();
      playSound('end');
      await showRunSummary('cards_limit'); // safety ceiling — closest matching summary type (unreachable in normal play)
      break;
    }
    // 1. WALK phase — camera moves along rail
    rail.resume();
    await waitSeconds(WALK_SECONDS_BEFORE_CARD);
    rail.pause();

    // Check if run still active
    if (!state().run.active) break;

    // 2. DRAIN life (T038: -1 base, -2 after card 15, -3 after card 25)
    // incrementCardsPlayed FIRST so drainLifeScaled reads the correct tier
    state().incrementCardsPlayed();
    state().drainLifeScaled();
    updateHUD();

    // 3. Check death after drain
    if (state().checkDeath()) {
      state().endRun('death_drain');
      saveRunEnd();
      playSound('end');
      await showRunSummary('death');
      break;
    }

    // 3b. OGHAM phase — let player equip/use an ogham before card
    // C84: if player pre-selected an ogham in the Lair, use it without showing panel
    const preSelected = state().run.activeOgham;
    const oghamChoice = preSelected || await showOghamPanel();
    // C135/OC-01/OC-02: capture result — narrative oghams mutate the card before display
    let oghamResult: ReturnType<typeof applyOghamEffect> | null = null;
    if (oghamChoice) {
      state().useOgham(oghamChoice);
      oghamResult = applyOghamEffect(oghamChoice);
      updateHUD();
    }
    hideOghamPanel();

    // 4. CARD phase — start LLM generation and fade simultaneously (C82-03: reduces
    // black-screen wait from up to 8.6s to max 8s by overlapping the 600ms fade)
    const llm = getLLMAdapter();
    type CardOrNull = import('./game/CardSystem').Card | null;
    let cardGenPromise: Promise<CardOrNull>;
    if (llm) {
      showLLMLoadingHint();
      // C80-01: 8s timeout prevents Groq stall from freezing indefinitely
      cardGenPromise = Promise.race<CardOrNull>([
        llm.generateCard(state().run.biome, `carte ${state().run.cardsPlayed}, vie ${state().run.life}`),
        new Promise<null>((res) => setTimeout(() => res(null), 8_000)),
      ]);
    } else {
      cardGenPromise = Promise.resolve(null);
    }
    await fadeIn(600); // runs concurrently with LLM — fade (600ms) overlaps generation

    let card: import('./game/CardSystem').Card;
    try {
      const llmCard = await cardGenPromise;
      hideLLMLoadingHint();
      card = llmCard ?? generateFastRouteCard(state().run.biome);
    } catch (err) {
      hideLLMLoadingHint();
      // FastRoute fallback: generate a minimal safe card if template fails
      console.warn('[MERLIN] Card generation failed, using emergency fallback:', err);
      card = {
        id: `card_emergency_${Date.now()}`,
        narrative: 'Le brouillard se leve, revelant un sentier paisible devant toi.',
        options: [
          { verb: 'observer', text: 'Tu observes les alentours calmement.', field: verbToField('observer'), effects: ['HEAL_LIFE:3'] as const },
          { verb: 'avancer',  text: 'Tu poursuis ta route avec prudence.',  field: verbToField('avancer'),  effects: ['ADD_ANAM:2'] as const },
          { verb: 'attendre', text: 'Tu fais une pause pour reprendre tes forces.', field: verbToField('attendre'), effects: ['HEAL_LIFE:2'] as const },
        ] as readonly [import('./game/CardSystem').CardOption, import('./game/CardSystem').CardOption, import('./game/CardSystem').CardOption],
        biome: state().run.biome,
        source: 'fastroute' as const,
      };
    }
    // C135/OC-01/OC-02: apply narrative ogham mutations to card before showing
    // C138/OC-04: guard on .applied — never mutate card if ogham was blocked (sacrifice blocked, etc.)
    if (oghamResult?.applied) {
      const et = oghamResult.effectType;
      if (et === 'full_reroll' || et === 'force_twist') {
        card = generateFastRouteCard(state().run.biome);
      } else if (et === 'regenerate_all_options') {
        const fresh = generateFastRouteCard(state().run.biome);
        card = { ...card, options: fresh.options };
      } else if (et === 'replace_worst_option') {
        const fresh = generateFastRouteCard(state().run.biome);
        // Heuristic: score each option (HEAL/ADD = +1, DAMAGE = -1), replace lowest
        const scoreOpt = (opt: { effects: readonly string[] }) =>
          opt.effects.reduce((s, e) => s + (/^(HEAL|ADD)/.test(e) ? 1 : /^DAMAGE/.test(e) ? -1 : 0), 0);
        // C142/OC-05: randomize tie-break — prevents deterministic idx=0 replacement on equal-scored options
        const optScores = ([0, 1, 2] as const).map((i) => scoreOpt(card.options[i]));
        const minScore = Math.min(...optScores);
        const tied = ([0, 1, 2] as const).filter((i) => optScores[i] === minScore);
        const worstIdx = tied[Math.floor(Math.random() * tied.length)] as 0 | 1 | 2;
        const opts = [...card.options] as [typeof card.options[0], typeof card.options[1], typeof card.options[2]];
        opts[worstIdx] = fresh.options[worstIdx];
        card = { ...card, options: opts };
      } else if (oghamResult.effectType === 'predict_next') {
        // C138/OC-03: Ailm — preview next card's field so player can prepare
        const nextPreview = generateFastRouteCard(state().run.biome);
        const predictedField = nextPreview.options[1]?.field ?? nextPreview.options[0]?.field ?? '?';
        showPredictToast(predictedField);
      }
    }

    await fadeOut(300);

    // C142/COLL: reveal_all_options — pass flag to CardOverlay so all effect tooltips become visible
    const revealEffects = oghamResult?.applied === true && oghamResult.effectType === 'reveal_all_options';
    const chosenOption = await showCard(card, { revealEffects });
    playSound('flip');

    // 5. MINIGAME phase
    const minigameId = detectMinigame(card, chosenOption);

    let result = { score: 50 }; // neutral fallback
    try {
      playSound('minigame_start'); // C82-06: audio cue signalling minigame phase start (was 'flip' — BUG-C88-03)
      sceneManager.stop(); // C118: pause 3D render during minigame — both GPU contexts concurrent = frame drops on mobile
      minigameOverlay.classList.add('visible');
      const minigame = await createMinigame(minigameId, minigameContainer);
      result = await minigame.play();
    } catch (err) {
      console.warn(`[MERLIN] Minigame '${minigameId}' failed, using neutral score 50:`, err);
    } finally {
      minigameOverlay.classList.remove('visible');
      sceneManager.start(); // C118: resume 3D render after minigame
      minigameContainer.innerHTML = ''; // C135/GL-01: dispose canvas, prevent accumulation
    }

    // 6. SCORE → multiplier
    // Align with MULTIPLIER_TABLE: reussite tier starts at 80 (BUG-C62-06)
    playSound(result.score >= 80 ? 'win' : 'lose');
    const multiplier = getMultiplier(result.score);
    const label = getMultiplierLabel(result.score);

    // 7. APPLY EFFECTS (with ogham modifiers if active)
    const option = card.options[chosenOption];
    const activeOgham = state().run.activeOgham;
    let effectResult: { applied: readonly string[]; rejected: readonly string[] } = { applied: [], rejected: [] };
    try {
      const modifiedEffects = activeOgham
        ? processOghamModifiers(option.effects, activeOgham)
        : option.effects;
      effectResult = applyEffects(modifiedEffects, multiplier);
      // C82-04: surface silently-rejected effects for balance tuning visibility
      if (effectResult.rejected.length > 0) {
        console.warn('[MERLIN] Rejected effects (not yet implemented):', effectResult.rejected);
      }
    } catch (err) {
      console.warn('[MERLIN] Effect application failed, skipping effects:', err);
    }

    // 8. Tick ogham cooldowns + clear active ogham
    state().tickCooldowns();
    if (activeOgham) {
      state().setActiveOgham('');
    }
    updateHUD();

    // 9. Check death after effects
    if (state().checkDeath()) {
      state().endRun('death_effects');
      saveRunEnd();
      playSound('end');
      await showRunSummary('death');
      break;
    }

    // 10a. Check 30-card limit (T046)
    if (state().run.cardsPlayed >= 30) {
      state().endRun('cards_limit');
      saveRunEnd();
      playSound('end');
      await showRunSummary('cards_limit');
      break;
    }

    // 10b. Check victory condition (rail complete + min cards)
    if (state().run.cardsPlayed >= 25 && rail.isComplete()) {
      state().endRun('victory');
      saveRunEnd();
      playSound('end');
      await showRunSummary('victory');
      break;
    }

    // 11. RETURN to 3D — fade back
    await fadeIn(400);
    await fadeOut(400);

    // Reset rail if complete — play audio cue so player notices world cycling
    if (rail.isComplete()) {
      playSound('unlock'); // audio cue: world is cycling before victory threshold
      rail.reset();
    }
  }
  // C152/ML-02: safety-net saveRunEnd after the while loop — covers the theoretical path
  // where run.active is flipped false externally (debug tool, future feature) causing the
  // loop to exit via the while-condition check without hitting any break. Idempotent: the
  // savedThisRun guard makes double-calling harmless for all normal break paths.
  saveRunEnd();
}

async function createMinigame(id: string, container: HTMLElement) {
  // Single dynamic import — Rollup bundles all 14 minigames into one deferred chunk
  // (see vite.config.ts manualChunks). Chunk is cached after first run entry.
  const { createMinigameById } = await import('./minigames/MinigameRegistry');
  return createMinigameById(id, container);
}


function waitSeconds(seconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

// --- LLM loading hint (shown during Groq card generation to prevent perceived freeze) ---

const LLM_HINT_ID = 'llm-loading-hint';

function showLLMLoadingHint(): void {
  if (document.getElementById(LLM_HINT_ID)) return;
  const hint = document.createElement('div');
  hint.id = LLM_HINT_ID;
  hint.setAttribute('role', 'status');
  hint.setAttribute('aria-live', 'polite');
  hint.className = 'llm-loading-hint';
  hint.textContent = 'Merlin consulte les etoiles\u2026';
  document.body.appendChild(hint);
}

function hideLLMLoadingHint(): void {
  document.getElementById(LLM_HINT_ID)?.remove();
}

// --- Biome toast (T045: 2s overlay shown on run start and biome entry) ---

const BIOME_TOAST_ID = 'biome-toast';

/** Biome display labels (French, shown in toast). */
const BIOME_LABELS: Readonly<Record<string, string>> = {
  cotes_sauvages: 'Cotes Sauvages',
  foret_broceliande: 'Foret de Broceliande',
  marais_korrigans: 'Marais des Korrigans',
  landes_bruyere: 'Landes de Bruyere',
  cercles_pierres: 'Cercles de Pierres',
  villages_celtes: 'Villages Celtes',
  collines_dolmens: 'Collines aux Dolmens',
  iles_mystiques: 'Iles Mystiques',
} as const;

/**
 * Show a 2-second biome name toast overlay.
 * Fades in over 300 ms, stays visible for 1.4 s, fades out over 300 ms.
 * Safe to call during any phase — removes itself automatically.
 */
function showBiomeToast(biomeId: string): void {
  // Remove any existing toast immediately
  document.getElementById(BIOME_TOAST_ID)?.remove();

  const label = BIOME_LABELS[biomeId] ?? biomeId;
  const toast = document.createElement('div');
  toast.id = BIOME_TOAST_ID;
  toast.setAttribute('aria-live', 'polite');
  toast.setAttribute('role', 'status');
  toast.style.cssText = [
    'position:fixed',
    'bottom:80px',
    'left:50%',
    'transform:translateX(-50%)',
    'background:rgba(1,8,2,0.92)',
    'color:rgba(51,255,102,0.90)',
    'font-family:Courier New,monospace',
    'font-size:13px',
    'font-weight:600',
    'letter-spacing:0.18em',
    'text-transform:uppercase',
    'padding:8px 24px',
    'border-radius:2px',
    'border:1px solid rgba(51,255,102,0.28)',
    'z-index:55',
    'pointer-events:none',
    'opacity:0',
    'transition:opacity 0.3s ease',
  ].join(';');
  toast.textContent = label;
  document.body.appendChild(toast);

  // Fade in
  requestAnimationFrame(() => {
    requestAnimationFrame(() => { toast.style.opacity = '1'; });
  });

  // Fade out after 1.7 s, then remove
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => { toast.remove(); }, 300);
  }, 1700);
}

// --- Anam cross-run persistence (localStorage) ---

const ANAM_STORAGE_KEY = 'merlin_anam';

function loadAnamFromStorage(): void {
  try {
    const saved = localStorage.getItem(ANAM_STORAGE_KEY);
    if (saved !== null) {
      const value = parseInt(saved, 10);
      if (!isNaN(value) && value > 0) {
        store.getState().addAnam(value);
      }
    }
  } catch {
    // localStorage unavailable (private browsing, etc.) — ignore
  }
}

function saveAnamToStorage(): void {
  try {
    const currentAnam = store.getState().meta.anam;
    localStorage.setItem(ANAM_STORAGE_KEY, currentAnam.toString());
  } catch {
    // localStorage unavailable — ignore
  }
}

// --- Meta cross-run persistence (T053) ---
// Persists oghamsUnlocked, factionRep, totalRuns alongside existing anam persistence.

const META_STORAGE_KEY = 'merlin_meta';

interface PersistedMeta {
  readonly oghamsUnlocked: string[];
  readonly factionRep: Record<string, number>;
  readonly totalRuns: number;
}

function loadMetaFromStorage(): void {
  try {
    const saved = localStorage.getItem(META_STORAGE_KEY);
    if (saved === null) return;
    const parsed: unknown = JSON.parse(saved);
    if (typeof parsed !== 'object' || parsed === null) return;
    const data = parsed as Partial<PersistedMeta>;

    const state = store.getState();

    // Restore oghamsUnlocked — merge with current (starter oghams already set)
    if (Array.isArray(data.oghamsUnlocked) && data.oghamsUnlocked.length > 0) {
      const current = state.meta.oghamsUnlocked;
      const merged = Array.from(new Set([...current, ...data.oghamsUnlocked]));
      if (merged.length > current.length) {
        store.setState((s) => ({
          meta: {
            ...s.meta,
            oghamsUnlocked: merged,
            oghamsEquipped: merged,
          },
        }));
      }
    }

    // Restore factionRep
    if (typeof data.factionRep === 'object' && data.factionRep !== null) {
      const fr = data.factionRep;
      store.setState((s) => ({
        meta: {
          ...s.meta,
          factionRep: {
            ...s.meta.factionRep,
            ...Object.fromEntries(
              Object.entries(fr).map(([k, v]) => [k, typeof v === 'number' ? Math.max(0, Math.min(100, v)) : 0])
            ),
          },
        },
      }));
    }

    // Restore totalRuns
    if (typeof data.totalRuns === 'number' && data.totalRuns > 0) {
      store.setState((s) => ({
        meta: { ...s.meta, totalRuns: data.totalRuns as number },
      }));
    }
  } catch {
    // Corrupt or unavailable — ignore, start fresh
  }
}

function saveMetaToStorage(): void {
  try {
    const meta = store.getState().meta;
    const data: PersistedMeta = {
      oghamsUnlocked: [...meta.oghamsUnlocked],
      factionRep: { ...meta.factionRep },
      totalRuns: meta.totalRuns,
    };
    localStorage.setItem(META_STORAGE_KEY, JSON.stringify(data));
  } catch {
    // localStorage unavailable — ignore
  }
}

// --- Ogham unlock toast (T049) ---
// Listens for 'ogham_unlocked' events dispatched by Store.addReputation()
// when faction rep crosses the 50 threshold for the first time.

const OGHAM_TOAST_ID = 'ogham-unlock-toast';

function showOghamUnlockToast(oghamName: string): void {
  document.getElementById(OGHAM_TOAST_ID)?.remove();

  const toast = document.createElement('div');
  toast.id = OGHAM_TOAST_ID;
  toast.setAttribute('aria-live', 'assertive');
  toast.setAttribute('role', 'status');
  toast.style.cssText = [
    'position:fixed',
    'top:80px',
    'left:50%',
    'transform:translateX(-50%)',
    'background:rgba(1,8,2,0.92)',
    'color:rgba(51,255,102,0.90)',
    'font-family:Courier New,monospace',
    'font-size:12px',
    'font-weight:600',
    'letter-spacing:0.16em',
    'padding:8px 24px',
    'border-radius:2px',
    'border:1px solid rgba(51,255,102,0.30)',
    'z-index:65',
    'pointer-events:none',
    'opacity:0',
    'transition:opacity 0.35s ease',
    'text-align:center',
  ].join(';');
  toast.textContent = `\u16AA Ogham ${oghamName} d\u00e9verrouill\u00e9`;
  document.body.appendChild(toast);

  requestAnimationFrame(() => {
    requestAnimationFrame(() => { toast.style.opacity = '1'; });
  });

  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => { toast.remove(); }, 350);
  }, 3000);
}

// C138/OC-03: Ailm predict_next — show predicted field as feedback toast
const PREDICT_TOAST_ID = 'merlin-predict-toast';
function showPredictToast(field: string): void {
  document.getElementById(PREDICT_TOAST_ID)?.remove();
  const toast = document.createElement('div');
  toast.id = PREDICT_TOAST_ID;
  toast.setAttribute('role', 'status');
  toast.setAttribute('aria-live', 'polite');
  toast.style.cssText = [
    'position:fixed',
    'top:120px',
    'left:50%',
    'transform:translateX(-50%)',
    'background:rgba(1,8,2,0.92)',
    'color:rgba(51,255,102,0.75)',
    'font-family:Courier New,monospace',
    'font-size:12px',
    'font-weight:600',
    'letter-spacing:0.14em',
    'padding:8px 22px',
    'border-radius:2px',
    'border:1px solid rgba(51,255,102,0.22)',
    'z-index:65',
    'pointer-events:none',
    'opacity:0',
    'transition:opacity 0.3s ease',
    'text-align:center',
  ].join(';');
  // C145b/NEW-MAIN-01: "entrevoit" (glimpses) instead of "prédit" (predicts) — the preview
  // is generated from a random FastRoute card, not the actual next LLM card. "Entrevoit"
  // conveys oracular approximation (Celtic mysticism) rather than a false hard prediction.
  toast.textContent = `\u168F Ailm entrevoit\u00a0: ${field}`;
  document.body.appendChild(toast);
  requestAnimationFrame(() => { requestAnimationFrame(() => { toast.style.opacity = '1'; }); });
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => { toast.remove(); }, 320);
  }, 4000);
}

window.addEventListener('ogham_unlocked', (evt: Event) => {
  const detail = (evt as CustomEvent<{ oghamId: string; oghamName: string }>).detail;
  if (detail?.oghamName) {
    showOghamUnlockToast(detail.oghamName);
    playSound('unlock');
  }
});

// --- Keyboard shortcuts (T054) ---
// Space: click first card option when card overlay is visible
// Escape: close Ogham panel (skip) or dismiss RunSummary (click Rejouer)

document.addEventListener('keydown', (evt: KeyboardEvent) => {
  // Ignore key events originating from input/textarea elements
  const target = evt.target as HTMLElement;
  if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') return;

  if (evt.code === 'Space') {
    evt.preventDefault();
    // Click the first available card option
    const cardOverlay = document.getElementById('card-overlay');
    if (cardOverlay?.classList.contains('visible')) {
      const firstOption = cardOverlay.querySelector<HTMLElement>('.card-option');
      firstOption?.click();
    }
  }

  if (evt.code === 'Escape') {
    // Close Ogham panel (simulate "Passer" / skip)
    const oghamOverlay = document.getElementById('ogham-panel-overlay');
    if (oghamOverlay && oghamOverlay.style.display !== 'none') {
      const skipBtn = oghamOverlay.querySelector<HTMLElement>('#ogham-skip-btn');
      skipBtn?.click();
      return;
    }
    // Dismiss RunSummary (click Rejouer)
    const summaryOverlay = document.getElementById('run-summary-overlay');
    if (summaryOverlay) {
      const replayBtn = summaryOverlay.querySelector<HTMLElement>('button');
      replayBtn?.click();
    }
  }
});

// --- SFX event bus (T056) ---
// Dispatches a CustomEvent on window consumed by SFXManager (initSFXManager).
// SFXManager reads e.detail.sound — key MUST match SFXEvent interface.
// Registered sounds: flip | win | lose | unlock | end

export function playSound(type: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: type } }));
}

// --- Start ---
main().catch(console.error);
