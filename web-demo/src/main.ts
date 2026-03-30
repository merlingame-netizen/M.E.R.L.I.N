// ═══════════════════════════════════════════════════════════════════════════════
// M.E.R.L.I.N. — Main Entry Point
// Gameplay loop: 3D walk → fade → card → choice → minigame → effects → return
// ═══════════════════════════════════════════════════════════════════════════════

import { SceneManager } from './engine/SceneManager';
import { CameraRail } from './engine/CameraRail';
import { buildCoastScene } from './scenes/CoastBiome';
import { store } from './game/Store';
import { BIOMES, getMultiplier, getMultiplierLabel } from './game/Constants';
import { generateFastRouteCard, detectMinigame } from './game/CardSystem';
import { applyEffects, applyOghamEffect, processOghamModifiers } from './game/EffectEngine';
import { showCard, hideCard } from './ui/CardOverlay';
import { initHUD, updateHUD } from './ui/HUD';
import { fadeIn, fadeOut, crossFade } from './ui/Transitions';
import { MinigameTraces } from './minigames/mg_traces';
import { MinigameRunes } from './minigames/mg_runes';
import { MinigameEquilibre } from './minigames/mg_equilibre';
import { MinigameHerboristerie } from './minigames/mg_herboristerie';
import { MinigameNegociation } from './minigames/mg_negociation';
import { MinigameCombatRituel } from './minigames/mg_combat_rituel';
import { MinigameApaisement } from './minigames/mg_apaisement';
import { MinigameSangFroid } from './minigames/mg_sang_froid';
import { MinigameCourse } from './minigames/mg_course';
import { initOghamPanel, showOghamPanel, hideOghamPanel } from './ui/OghamPanel';

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

  // Start game
  store.getState().startRun('cotes_sauvages');
  updateHUD();

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

    // 2. DRAIN life (-1 per card)
    state().drainLife();
    state().incrementCardsPlayed();
    updateHUD();

    // 3. Check death after drain
    if (state().checkDeath()) {
      state().endRun('death_drain');
      await showEndScreen('Tu as succombe a l\'epuisement...');
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

    const card = generateFastRouteCard(state().run.biome);
    await fadeOut(300);

    const chosenOption = await showCard(card);

    // 5. MINIGAME phase
    const minigameId = detectMinigame(card, chosenOption);
    const minigameContainer = document.getElementById('minigame-container')!;
    const minigameOverlay = document.getElementById('minigame-overlay')!;

    minigameOverlay.classList.add('visible');
    const minigame = createMinigame(minigameId, minigameContainer);
    const result = await minigame.play();
    minigameOverlay.classList.remove('visible');

    // 6. SCORE → multiplier
    const multiplier = getMultiplier(result.score);
    const label = getMultiplierLabel(result.score);

    // 7. APPLY EFFECTS (with ogham modifiers if active)
    const option = card.options[chosenOption];
    const activeOgham = state().run.activeOgham;
    const modifiedEffects = activeOgham
      ? processOghamModifiers(option.effects, activeOgham)
      : option.effects;
    const effectResult = applyEffects(modifiedEffects, multiplier);

    // 8. Tick ogham cooldowns + clear active ogham
    state().tickCooldowns();
    if (activeOgham) {
      state().setActiveOgham('');
    }
    updateHUD();

    // 9. Check death after effects
    if (state().checkDeath()) {
      state().endRun('death_effects');
      await showEndScreen('Les forces de Broceliande t\'ont consume...');
      break;
    }

    // 10. Check victory condition
    if (state().run.cardsPlayed >= 25 && rail.isComplete()) {
      state().endRun('victory');
      await showEndScreen('Tu as traverse le biome ! Victoire !');
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
    case 'traces':
    default:
      // Remaining minigames fall back to Traces
      return new MinigameTraces(container);
  }
}

async function showEndScreen(message: string): Promise<void> {
  const state = store.getState();
  await fadeIn(800);

  const overlay = document.getElementById('card-overlay')!;
  const textEl = document.getElementById('card-text')!;
  const optionsEl = document.getElementById('card-options')!;

  textEl.textContent = message;
  optionsEl.innerHTML = '';

  const statsDiv = document.createElement('div');
  statsDiv.style.cssText = 'text-align:center;color:#e8dcc8;font-family:system-ui;';
  statsDiv.innerHTML = `
    <div style="font-size:24px;margin-bottom:16px;color:#cd853f;">Fin de la quete</div>
    <div style="font-size:16px;margin-bottom:8px;">Cartes jouees: ${state.run.cardsPlayed}</div>
    <div style="font-size:16px;margin-bottom:8px;">Vie restante: ${state.run.life}</div>
    <div style="font-size:16px;margin-bottom:24px;">Anam gagne: ${state.meta.anam}</div>
    <button id="restart-btn" style="
      padding:12px 32px;font-size:16px;cursor:pointer;
      background:rgba(139,69,19,0.3);color:#e8dcc8;
      border:1px solid rgba(205,133,63,0.5);border-radius:8px;
      font-family:system-ui;
    ">Rejouer</button>
  `;
  optionsEl.appendChild(statsDiv);

  overlay.classList.add('visible');
  await fadeOut(800);

  // Wait for restart
  await new Promise<void>((resolve) => {
    document.getElementById('restart-btn')?.addEventListener('click', () => {
      hideCard();
      store.getState().reset();
      resolve();
    });
  });

  // Restart
  window.location.reload();
}

function waitSeconds(seconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

// --- Start ---
main().catch(console.error);
