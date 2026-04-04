// ═══════════════════════════════════════════════════════════════════════════════
// M.E.R.L.I.N. — Main Entry Point
// Gameplay loop: 3D walk → fade → card → choice → minigame → effects → return
// ═══════════════════════════════════════════════════════════════════════════════

import { SceneManager } from './engine/SceneManager';
import { CameraRail } from './engine/CameraRail';
import { buildCoastScene } from './scenes/CoastBiome';
import { store } from './game/Store';
import { getMultiplier, getMultiplierLabel } from './game/Constants';
import { generateFastRouteCard, detectMinigame, loadTemplates, verbToField } from './game/CardSystem';
import { applyEffects, applyOghamEffect, processOghamModifiers } from './game/EffectEngine';
import { showCard } from './ui/CardOverlay';
import { initHUD, updateHUD, teardownHUD } from './ui/HUD';
import { fadeIn, fadeOut } from './ui/Transitions';
// Minigames are lazy-loaded on first use (dynamic import) to defer the ~21KB chunk
// until the player actually enters a run. vite.config.ts lets Rollup auto-split them.
import { initOghamPanel, showOghamPanel, hideOghamPanel } from './ui/OghamPanel';
import { getLLMAdapter } from './llm/GroqAdapter';
import { showRunSummary } from './ui/RunSummary';
import { initMainMenu } from './scenes/MainMenuScene';
import { initMerlinLair } from './scenes/MerlinLairScene';
import { cutToBlack, revealFromBlack } from './ui/SceneTransition';
import { initSFXManager, startAmbient, stopAmbient, biomeToAmbient } from './audio/SFXManager';

// --- Config ---
const WALK_SECONDS_BEFORE_CARD = 6; // Seconds of walking before showing a card
const WALK_SPEED = 0.04; // Rail progress per second

// --- Boot Screen (T060 + T069) ---
// Shows Celtic logo + progress bar for 2.5s, then transitions to main menu.
// T069: Any click or keypress during boot skips the remaining wait immediately.
async function runBootScreen(): Promise<void> {
  const bootScreen = document.getElementById('boot-screen');
  if (!bootScreen) return;

  const statusEl = document.getElementById('boot-status-text');
  const statusMessages = [
    'Initialisation...',
    'Chargement des Oghams...',
    'Eveil du monde celtique...',
    'Merlin vous attend...',
  ];
  let msgIndex = 0;
  const msgInterval = setInterval(() => {
    msgIndex = (msgIndex + 1) % statusMessages.length;
    if (statusEl) statusEl.textContent = statusMessages[msgIndex] ?? '';
  }, 650);

  // T069: resolve immediately on click or keypress (listeners cleaned up on resolve)
  await new Promise<void>((resolve) => {
    let resolved = false;
    const skip = (): void => {
      if (resolved) return;
      resolved = true;
      document.removeEventListener('click', skip);
      document.removeEventListener('keydown', skip);
      // T075: Snap progress bar to 100% on early skip
      const fill = document.querySelector<HTMLElement>('.boot-progress-fill');
      if (fill) {
        fill.style.animation = 'none';
        fill.style.width = '100%';
      }
      resolve();
    };
    document.addEventListener('click', skip, { once: true });
    document.addEventListener('keydown', skip, { once: true });
    // Auto-resolve after 2.6s (normal duration)
    waitSeconds(2.6).then(skip);
  });

  clearInterval(msgInterval);

  // Fade out boot screen — race transitionend vs timeout (handles prefers-reduced-motion)
  bootScreen.classList.add('hidden');
  await Promise.race([
    new Promise<void>(res => bootScreen.addEventListener('transitionend', () => res(), { once: true })),
    new Promise<void>(res => setTimeout(res, 1000)), // 0.8s transition + 200ms margin
  ]);
  bootScreen.style.display = 'none';
}

// --- Main Menu (T061) ---
// Runs the cinematic Three.js cliff/sea scene. Resolves when player clicks Start.
async function runMainMenu(): Promise<void> {
  const wrapper = document.getElementById('menu-canvas-wrapper');
  const overlay = document.getElementById('main-menu-overlay');
  const startBtn = document.getElementById('menu-start-btn');
  if (!wrapper || !overlay || !startBtn) return;

  wrapper.classList.add('visible');

  const menu = initMainMenu(wrapper);

  // Animation loop for the menu scene
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
  // try/finally guarantees cancelAnimationFrame is always called even on failure.
  try {
    tick();

    // T066: Start menu ambient audio (gentle wind drone, 55Hz)
    startAmbient('menu');

    // Show menu UI immediately — camera is static, no dolly to wait for
    overlay.classList.add('visible');

    // Wait for player to click Start
    await new Promise<void>((resolve) => {
      startBtn.addEventListener('click', () => resolve(), { once: true });
    });

    // T066: Stop menu ambient, transition to forest ambient
    stopAmbient();

    // Transition: fade to black then go to game
    overlay.classList.remove('visible');
    cutToBlack();

    // startDolly is now a no-op that calls onComplete immediately
    await new Promise<void>((resolve) => {
      menu.startDolly(resolve);
    });
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
      'background:rgba(5,4,2,0.88);backdrop-filter:blur(2px);',
      'opacity:0;transition:opacity 0.2s ease;',
    ].join('');

    const title = document.createElement('div');
    title.textContent = 'Choisir un Biome';
    title.style.cssText = [
      'color:#c8a050;font-family:Georgia,serif;font-size:clamp(14px,3vw,20px);',
      'letter-spacing:0.15em;margin-bottom:16px;text-shadow:0 0 10px rgba(200,160,80,0.5);',
    ].join('');
    overlay.appendChild(title);

    const grid = document.createElement('div');
    grid.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:8px;max-width:380px;width:90%;';
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
      btn.textContent = label;
      btn.setAttribute('aria-label', `Biome: ${label}`);
      btn.style.cssText = [
        'background:rgba(30,22,10,0.9);border:1px solid rgba(160,110,50,0.45);border-radius:6px;',
        'color:rgba(200,170,100,0.85);font-family:Georgia,serif;font-size:clamp(10px,2vw,13px);',
        'padding:10px 8px;cursor:pointer;letter-spacing:0.05em;text-align:center;',
        'transition:background 0.15s,border-color 0.15s,color 0.15s;',
      ].join('');
      btn.addEventListener('pointerenter', () => {
        btn.style.background = 'rgba(60,42,15,0.95)';
        btn.style.borderColor = 'rgba(200,150,60,0.8)';
        btn.style.color = '#e8c870';
      });
      btn.addEventListener('pointerleave', () => {
        btn.style.background = 'rgba(30,22,10,0.9)';
        btn.style.borderColor = 'rgba(160,110,50,0.45)';
        btn.style.color = 'rgba(200,170,100,0.85)';
      });
      btn.addEventListener('click', () => {
        overlay.style.opacity = '0';
        setTimeout(() => overlay.remove(), 220);
        resolve(id);
      });
      grid.appendChild(btn);
    }

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
      'background:rgba(18,13,7,0.97);border:1px solid rgba(200,150,60,0.5);',
      'border-radius:12px;padding:28px 32px;max-width:360px;width:88%;',
      'font-family:Georgia,serif;color:#e8dcc8;text-align:center;',
    ].join('');

    const titleEl = document.createElement('div');
    titleEl.textContent = 'Journal de Merlin';
    titleEl.style.cssText = 'color:#c8a050;font-size:20px;letter-spacing:0.12em;margin-bottom:6px;';
    panel.appendChild(titleEl);

    const subEl = document.createElement('div');
    subEl.textContent = 'Chroniques de l\'aventurier';
    subEl.style.cssText = 'color:rgba(200,170,100,0.45);font-size:12px;font-style:italic;margin-bottom:20px;';
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
      row.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:7px 0;border-bottom:1px solid rgba(200,150,60,0.12);';
      const lEl = document.createElement('span');
      lEl.style.cssText = 'color:rgba(232,220,200,0.6);font-size:13px;';
      lEl.textContent = label;
      const vEl = document.createElement('span');
      vEl.style.cssText = 'color:#c8a050;font-size:14px;';
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
      'padding:10px 32px;font-size:14px;cursor:pointer;',
      'background:rgba(80,60,20,0.4);color:rgba(232,220,200,0.8);',
      'border:1px solid rgba(200,150,60,0.4);border-radius:8px;',
      'font-family:Georgia,serif;transition:background 0.15s;',
    ].join('');
    closeBtn.addEventListener('pointerenter', () => { closeBtn.style.background = 'rgba(100,75,25,0.6)'; });
    closeBtn.addEventListener('pointerleave', () => { closeBtn.style.background = 'rgba(80,60,20,0.4)'; });
    closeBtn.addEventListener('click', dismiss);
    panel.appendChild(closeBtn);
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

  revealFromBlack(800);

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
  const tick = (): void => {
    rafId = requestAnimationFrame(tick);
    const t = performance.now();
    const dt = Math.min((t - lastTs) / 1000, 0.05);
    lastTs = t;
    lair.update(dt);
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
      'background:rgba(10,8,4,0.88);border:1px solid rgba(160,110,50,0.6);',
      'border-radius:6px;padding:10px 24px;pointer-events:none;z-index:20;',
      'color:#c8a050;font-family:Georgia,serif;font-size:clamp(13px,2.5vw,16px);',
      'letter-spacing:0.08em;text-align:center;',
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
    lair.onZoneClick(async (zone) => {
      if (zone === 'door') {
        showZoneToast('door'); // "Entrer dans la forêt" — 600ms total: 200ms fade-in + 400ms fully visible (C45: was 400ms = only 200ms readable)
        setTimeout(resolve, 600);
        return;
      }
      if (zone === 'crystal') {
        // C84: show ogham panel for pre-run selection — result carried into first card
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
          'background:rgba(10,8,4,0.9);border:1px solid rgba(200,150,60,0.6);',
          'border-radius:6px;padding:8px 20px;pointer-events:none;z-index:20;',
          'color:#e8c870;font-family:Georgia,serif;font-size:clamp(12px,2.2vw,15px);',
          'letter-spacing:0.07em;text-align:center;opacity:0;transition:opacity 0.2s;',
        ].join('');
        confirmToast.setAttribute('role', 'status');
        confirmToast.setAttribute('aria-live', 'polite');
        confirmToast.textContent = `Destination : ${pickedLabel}`;
        wrapper!.appendChild(confirmToast);
        requestAnimationFrame(() => requestAnimationFrame(() => { confirmToast.style.opacity = '1'; }));
        setTimeout(() => {
          confirmToast.style.opacity = '0';
          setTimeout(() => confirmToast.remove(), 220);
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

  // BUG-01: Save cross-run data on sudden tab close or mobile backgrounding
  const emergencySave = (): void => { saveAnamToStorage(); saveMetaToStorage(); };
  window.addEventListener('beforeunload', emergencySave);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') emergencySave();
  });

  // Phase 1: Boot screen (T060)
  await runBootScreen();

  // Phase 2: Main menu (once — never shown again between runs)
  await runMainMenu();

  // T043: Load FastRoute card templates once (shared across all runs)
  await loadTemplates();

  // C84: Init ogham panel + cross-run data BEFORE first lair visit
  // (initOghamPanel is idempotent; safe to call again each loop iteration)
  initOghamPanel();
  loadAnamFromStorage();
  loadMetaFromStorage();

  // BUG-03: Outer run loop — lair → walk → run → lair → walk → run ...
  // Without this the page is a dead-end after the first run.
  while (true) {
    // Phase 2b: Lair Hub — returns chosen biome + optional pre-selected ogham
    const lairResult = await runMerlinLair(app);
    const chosenBiome = lairResult.biomeId;

    // Phase 3: Reveal and enter game
    loading.style.display = 'flex';
    loading.style.opacity = '1';

    // Init scene (fresh per run)
    const sceneManager = new SceneManager(app);

    // Build biome — only cotes_sauvages has a 3D walk scene for now;
    // all other biomes share this backdrop until their scenes are implemented.
    const biomeResult = await buildCoastScene();
    sceneManager.scene.add(biomeResult.group);

    // Camera rail
    const rail = CameraRail.createCoastalPath();
    rail.setSpeed(WALK_SPEED);

    sceneManager.onUpdate((dt) => {
      rail.update(sceneManager.camera, dt);
      biomeResult.update(dt);
    });

    // Start renderer
    sceneManager.start();

    // T066+C75: Start biome-matched ambient audio as game world reveals
    startAmbient(biomeToAmbient(chosenBiome));

    // Hide loading screen and reveal game (clear scene-transition black overlay)
    loading.style.opacity = '0';
    loading.style.transition = 'opacity 0.5s';
    setTimeout(() => { loading.style.display = 'none'; }, 500);
    revealFromBlack(600);

    // Init HUD + Ogham panel
    initHUD();
    initOghamPanel();

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

  while (state().run.active) {
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
      saveAnamToStorage();
      saveMetaToStorage();
      playSound('end');
      await showRunSummary('death');
      break;
    }

    // 3b. OGHAM phase — let player equip/use an ogham before card
    // C84: if player pre-selected an ogham in the Lair, use it without showing panel
    const preSelected = state().run.activeOgham;
    const oghamChoice = preSelected || await showOghamPanel();
    if (oghamChoice) {
      state().useOgham(oghamChoice);
      // Apply immediate ogham effects (heal, currency, sacrifice, etc.)
      applyOghamEffect(oghamChoice);
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

    let card;
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
    await fadeOut(300);

    const chosenOption = await showCard(card);
    playSound('flip');

    // 5. MINIGAME phase
    const minigameId = detectMinigame(card, chosenOption);

    let result = { score: 50 }; // neutral fallback
    try {
      playSound('minigame_start'); // C82-06: audio cue signalling minigame phase start (was 'flip' — BUG-C88-03)
      minigameOverlay.classList.add('visible');
      const minigame = await createMinigame(minigameId, minigameContainer);
      result = await minigame.play();
    } catch (err) {
      console.warn(`[MERLIN] Minigame '${minigameId}' failed, using neutral score 50:`, err);
    } finally {
      minigameOverlay.classList.remove('visible');
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
      saveAnamToStorage();
      saveMetaToStorage();
      playSound('end');
      await showRunSummary('death');
      break;
    }

    // 10a. Check 30-card limit (T046)
    if (state().run.cardsPlayed >= 30) {
      state().endRun('cards_limit');
      saveAnamToStorage();
      saveMetaToStorage();
      playSound('end');
      await showRunSummary('cards_limit');
      break;
    }

    // 10b. Check victory condition (rail complete + min cards)
    if (state().run.cardsPlayed >= 25 && rail.isComplete()) {
      state().endRun('victory');
      saveAnamToStorage();
      saveMetaToStorage();
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
    'background:rgba(10,10,18,0.88)',
    'color:rgba(205,133,63,0.95)',
    'font-family:system-ui',
    'font-size:15px',
    'font-weight:600',
    'letter-spacing:2px',
    'text-transform:uppercase',
    'padding:10px 28px',
    'border-radius:24px',
    'border:1px solid rgba(205,133,63,0.4)',
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
    'background:rgba(10,10,18,0.92)',
    'color:rgba(205,133,63,0.98)',
    'font-family:system-ui',
    'font-size:14px',
    'font-weight:600',
    'letter-spacing:1.5px',
    'padding:10px 28px',
    'border-radius:24px',
    'border:1px solid rgba(205,133,63,0.55)',
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
