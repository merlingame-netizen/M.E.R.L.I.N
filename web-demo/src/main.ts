// ═══════════════════════════════════════════════════════════════════════════════
// M.E.R.L.I.N. — Main Entry Point
// Gameplay loop: 3D walk → fade → card → choice → minigame → effects → return
// ═══════════════════════════════════════════════════════════════════════════════

import { SceneManager } from './engine/SceneManager';
import { CameraRail } from './engine/CameraRail';
import { buildCoastScene } from './scenes/CoastBiome';
import { store } from './game/Store';
import { getMultiplier, getMultiplierLabel } from './game/Constants';
import { generateFastRouteCard, detectMinigame, loadTemplates } from './game/CardSystem';
import { applyEffects, applyOghamEffect, processOghamModifiers } from './game/EffectEngine';
import { showCard } from './ui/CardOverlay';
import { initHUD, updateHUD } from './ui/HUD';
import { fadeIn, fadeOut } from './ui/Transitions';
import { MinigameTraces } from './minigames/mg_traces';
import { MinigameRunes } from './minigames/mg_runes';
import { MinigameEquilibre } from './minigames/mg_equilibre';
import { MinigameHerboristerie } from './minigames/mg_herboristerie';
import { MinigameNegociation } from './minigames/mg_negociation';
import { MinigameCombatRituel } from './minigames/mg_combat_rituel';
import { MinigameApaisement } from './minigames/mg_apaisement';
import { MinigameSangFroid } from './minigames/mg_sang_froid';
import { MinigameCourse } from './minigames/mg_course';
import { MinigameFouille } from './minigames/mg_fouille';
import { MinigameOmbres } from './minigames/mg_ombres';
import { MinigameVolonte } from './minigames/mg_volonte';
import { MinigameRegard } from './minigames/mg_regard';
import { MinigameEcho } from './minigames/mg_echo';
import { initOghamPanel, showOghamPanel, hideOghamPanel } from './ui/OghamPanel';
import { getLLMAdapter } from './llm/GroqAdapter';
import { showRunSummary } from './ui/RunSummary';

// --- Config ---
const WALK_SECONDS_BEFORE_CARD = 6; // Seconds of walking before showing a card
const WALK_SPEED = 0.04; // Rail progress per second

// --- Bootstrap ---
async function main(): Promise<void> {
  const app = document.getElementById('app')!;
  const loading = document.getElementById('loading')!;

  // Init scene
  const sceneManager = new SceneManager(app);

  // Build biome
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

  // Hide loading screen
  loading.style.opacity = '0';
  loading.style.transition = 'opacity 0.5s';
  setTimeout(() => { loading.style.display = 'none'; }, 500);

  // Init HUD + Ogham panel
  initHUD();
  initOghamPanel();

  // T043: Load FastRoute card templates from /data/cards.json before game starts
  await loadTemplates();

  // Load cross-run Anam + meta from localStorage (T053)
  loadAnamFromStorage();
  loadMetaFromStorage();

  // Start game
  store.getState().startRun('cotes_sauvages');
  updateHUD();
  showBiomeToast('cotes_sauvages');

  // --- Gameplay Loop ---
  await gameLoop(sceneManager, rail, biomeResult.update);
}

async function gameLoop(
  sceneManager: SceneManager,
  rail: CameraRail,
  biomeUpdate: (dt: number) => void
): Promise<void> {
  const state = store.getState;

  while (state().run.active) {
    // 1. WALK phase — camera moves along rail
    rail.resume();
    await waitSeconds(WALK_SECONDS_BEFORE_CARD);
    rail.pause();

    // Check if run still active
    if (!state().run.active) break;

    // 2. DRAIN life (T038: -1 base, -2 after card 15, -3 after card 25)
    state().drainLifeScaled();
    state().incrementCardsPlayed();
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
    const oghamChoice = await showOghamPanel();
    if (oghamChoice) {
      state().useOgham(oghamChoice);
      // Apply immediate ogham effects (heal, currency, sacrifice, etc.)
      applyOghamEffect(oghamChoice);
      updateHUD();
    }
    hideOghamPanel();

    // 4. CARD phase — fade to card overlay
    await fadeIn(600);

    let card;
    try {
      // Try LLM first (Groq cloud), fall back to FastRoute.
      // Show a brief loading indicator during generation to avoid perceived freeze.
      const llm = getLLMAdapter();
      let llmCard = null;
      if (llm) {
        showLLMLoadingHint();
        llmCard = await llm.generateCard(state().run.biome, `carte ${state().run.cardsPlayed}, vie ${state().run.life}`);
        hideLLMLoadingHint();
      }
      card = llmCard ?? generateFastRouteCard(state().run.biome);
    } catch (err) {
      hideLLMLoadingHint();
      // FastRoute fallback: generate a minimal safe card if template fails
      console.warn('[MERLIN] Card generation failed, using emergency fallback:', err);
      card = {
        id: `card_emergency_${Date.now()}`,
        narrative: 'Le brouillard se leve, revelant un sentier paisible devant toi.',
        options: [
          { verb: 'observer', text: 'Tu observes les alentours calmement.', field: 'observation', effects: ['HEAL_LIFE:3'] },
          { verb: 'avancer', text: 'Tu poursuis ta route avec prudence.', field: 'esprit', effects: ['ADD_ANAM:2'] },
          { verb: 'attendre', text: 'Tu fais une pause pour reprendre tes forces.', field: 'esprit', effects: ['HEAL_LIFE:2'] },
        ] as const,
        biome: state().run.biome,
        source: 'fastroute' as const,
      };
    }
    await fadeOut(300);

    const chosenOption = await showCard(card);
    playSound('flip');

    // 5. MINIGAME phase
    const minigameId = detectMinigame(card, chosenOption);
    const minigameContainer = document.getElementById('minigame-container')!;
    const minigameOverlay = document.getElementById('minigame-overlay')!;

    let result = { score: 50 }; // neutral fallback
    try {
      minigameOverlay.classList.add('visible');
      const minigame = createMinigame(minigameId, minigameContainer);
      result = await minigame.play();
    } catch (err) {
      console.warn(`[MERLIN] Minigame '${minigameId}' failed, using neutral score 50:`, err);
    } finally {
      minigameOverlay.classList.remove('visible');
    }

    // 6. SCORE → multiplier
    playSound(result.score > 65 ? 'win' : 'lose');
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

    // Reset rail if complete
    if (rail.isComplete()) {
      rail.reset();
    }
  }
}

function createMinigame(id: string, container: HTMLElement) {
  switch (id) {
    case 'runes':
      return new MinigameRunes(container);
    case 'equilibre':
      return new MinigameEquilibre(container);
    case 'herboristerie':
      return new MinigameHerboristerie(container);
    case 'negociation':
      return new MinigameNegociation(container);
    case 'combat_rituel':
      return new MinigameCombatRituel(container);
    case 'apaisement':
      return new MinigameApaisement(container);
    case 'sang_froid':
      return new MinigameSangFroid(container);
    case 'course':
      return new MinigameCourse(container);
    case 'fouille':
      return new MinigameFouille(container);
    case 'ombres':
      return new MinigameOmbres(container);
    case 'volonte':
      return new MinigameVolonte(container);
    case 'regard':
      return new MinigameRegard(container);
    case 'echo':
      return new MinigameEcho(container);
    case 'traces':
    default:
      // Remaining minigames fall back to Traces
      return new MinigameTraces(container);
  }
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
  hint.style.cssText = [
    'position:fixed',
    'bottom:24px',
    'left:50%',
    'transform:translateX(-50%)',
    'background:rgba(10,10,18,0.85)',
    'color:rgba(205,133,63,0.8)',
    'font-family:system-ui',
    'font-size:13px',
    'padding:8px 20px',
    'border-radius:20px',
    'border:1px solid rgba(205,133,63,0.3)',
    'z-index:60',
    'pointer-events:none',
    'letter-spacing:1px',
  ].join(';');
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
// Dispatches a CustomEvent on window so any future audio layer can listen
// without coupling to the game loop. No actual audio is produced here.
// Usage: window.addEventListener('merlin_sfx', (e) => { /* e.detail.type */ });

export function playSound(type: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { type } }));
}

// --- Start ---
main().catch(console.error);
