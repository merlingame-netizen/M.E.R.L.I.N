// AI Playtester — State Machine
// FSM navigating: LAUNCH → MENU → HUB → RUN loop → END → REPORT → DONE

import * as bridge from './game_bridge.mjs';
import { decideCard } from './decision_engine.mjs';
import { CONFIG } from './config.mjs';

/**
 * @typedef {object} RunLog
 * @property {number} cardNum
 * @property {object} card
 * @property {number} chosenOption
 * @property {string} optionLabel
 * @property {string} reasoning
 * @property {string} emotion
 * @property {number} llmDurationMs
 * @property {number} lifeBefore
 * @property {number} lifeAfter
 */

/**
 * Run the full playtest state machine
 * @param {object} persona — persona definition
 * @param {object} options — { noLaunch: bool }
 * @returns {Promise<{decisions: RunLog[], finalState: object, startTime: number, endTime: number}>}
 */
export async function runPlaytest(persona, options = {}) {
  const decisions = [];
  const history = [];
  let state = null;
  let cardNum = 0;
  const startTime = Date.now();

  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║  AI Playtester — ${persona.name.padEnd(18)}║`);
  console.log(`╚══════════════════════════════════════╝\n`);

  // ── LAUNCH ──────────────────────────────────────────────────────
  if (!options.noLaunch) {
    console.log('[FSM] State: LAUNCH');
    const ok = await bridge.launchGame();
    if (!ok) {
      throw new Error('Game failed to launch');
    }
    // Wait extra for scene to settle
    await sleep(5000);
  } else {
    console.log('[FSM] State: LAUNCH (skipped — game already running)');
    if (!bridge.isGameRunning()) {
      throw new Error('Game not running (no state.json)');
    }
  }

  // ── MENU ────────────────────────────────────────────────────────
  console.log('[FSM] State: MENU');
  await sleep(3000);

  // Try to find and click "Nouvelle Partie" or similar
  const menuAttempts = ['nouvelle', 'new', 'commencer', 'jouer', 'start'];
  let menuClicked = false;
  for (const attempt of menuAttempts) {
    const btnName = await bridge.findButton(attempt);
    if (btnName) {
      console.log(`[FSM] Found menu button: "${btnName}"`);
      await bridge.clickButton(btnName);
      menuClicked = true;
      break;
    }
  }

  if (!menuClicked) {
    // Fallback: simulate Enter key
    console.log('[FSM] No menu button found, pressing Enter');
    await bridge.sendCommand('simulate_key', { key: 'enter' });
  }

  await sleep(3000);

  // ── HUB ─────────────────────────────────────────────────────────
  console.log('[FSM] State: HUB');

  // Try to find biome selection and start
  const hubAttempts = ['commencer', 'start', 'partir', 'explorer'];
  let hubClicked = false;
  for (let retry = 0; retry < 3; retry++) {
    await sleep(2000);
    for (const attempt of hubAttempts) {
      const btnName = await bridge.findButton(attempt);
      if (btnName) {
        console.log(`[FSM] Found hub button: "${btnName}"`);
        await bridge.clickButton(btnName);
        hubClicked = true;
        break;
      }
    }
    if (hubClicked) break;
  }

  if (!hubClicked) {
    console.log('[FSM] No hub button found, pressing Enter');
    await bridge.sendCommand('simulate_key', { key: 'enter' });
  }

  await sleep(5000);

  // ── RUN LOOP ────────────────────────────────────────────────────
  console.log('[FSM] State: RUN');
  let runActive = true;

  while (runActive && cardNum < CONFIG.maxCards) {
    // Check game state
    state = bridge.readState();
    if (state && state.run) {
      const life = state.run.life ?? 100;
      if (life <= 0) {
        console.log(`[FSM] Player died (life=${life})`);
        break;
      }
    }

    // Wait for card
    console.log(`[FSM] Waiting for card #${cardNum + 1}...`);
    const card = await bridge.waitForCard(CONFIG.cardWaitTimeoutMs);

    if (!card) {
      console.log('[FSM] No card appeared, checking if run ended');
      state = bridge.readState();
      // If cards_played hasn't changed and no card, run may be over
      if (state && state.run && (state.run.life <= 0 || state.run.cards_played >= CONFIG.maxCards)) {
        break;
      }
      // Try pressing Enter to advance past screens
      await bridge.sendCommand('simulate_key', { key: 'enter' });
      await sleep(3000);
      continue;
    }

    cardNum++;
    const lifeBefore = state?.run?.life ?? 100;

    // ── DECIDE ──────────────────────────────────────────────────
    console.log(`[FSM] Card #${cardNum}: "${card.text?.slice(0, 60)}..."`);
    const decision = await decideCard(card, state || {}, persona, history.slice(-CONFIG.historySize));

    const optLabel = card.options?.[decision.chosenOption]?.label || '?';
    const choiceLetter = ['A', 'B', 'C'][decision.chosenOption];
    console.log(`[FSM] → Choice ${choiceLetter} "${optLabel}" (${decision.emotion}) [${decision.llmDurationMs}ms]`);
    console.log(`[FSM]   Reason: ${decision.reasoning}`);

    // ── RESOLVE ─────────────────────────────────────────────────
    const clickResult = await bridge.clickOption(decision.chosenOption);
    if (!clickResult || clickResult.status !== 'ok') {
      console.warn(`[FSM] click_option failed: ${clickResult?.error || 'timeout'}, retrying...`);
      await sleep(2000);
      const retry = await bridge.clickOption(decision.chosenOption);
      if (!retry || retry.status !== 'ok') {
        console.error(`[FSM] click_option failed twice, skipping card`);
        await bridge.sendCommand('simulate_key', { key: 'enter' });
        await sleep(3000);
        continue;
      }
    }

    // Wait for resolution (card cleared or new state)
    await sleep(3000);
    await bridge.waitForCardCleared(15_000);
    await sleep(2000);

    // Read post-resolution state
    const postState = bridge.readState();
    const lifeAfter = postState?.run?.life ?? lifeBefore;

    // Log decision
    const entry = {
      cardNum,
      card: { text: card.text, speaker: card.speaker, type: card.type },
      chosenOption: decision.chosenOption,
      optionLabel: optLabel,
      reasoning: decision.reasoning,
      emotion: decision.emotion,
      llmDurationMs: decision.llmDurationMs,
      lifeBefore,
      lifeAfter,
      lifeDelta: lifeAfter - lifeBefore,
    };
    decisions.push(entry);
    history.push(entry);

    // Check if run ended
    if (lifeAfter <= 0) {
      console.log(`[FSM] Death at card #${cardNum} (life: ${lifeBefore} → ${lifeAfter})`);
      break;
    }

    // Check cards_played from state
    if (postState?.run?.cards_played >= CONFIG.maxCards) {
      console.log(`[FSM] Max cards reached`);
      break;
    }
  }

  // ── RUN END ─────────────────────────────────────────────────────
  console.log('[FSM] State: RUN_END');
  await bridge.screenshot('playtest_end');
  await sleep(2000);

  // Try to click through end screen
  const endAttempts = ['continuer', 'retour', 'hub', 'ok', 'terminer'];
  for (const attempt of endAttempts) {
    const btnName = await bridge.findButton(attempt);
    if (btnName) {
      await bridge.clickButton(btnName);
      break;
    }
  }

  const finalState = bridge.readState();
  const endTime = Date.now();

  console.log(`\n[FSM] Playtest complete: ${cardNum} cards, ${Math.round((endTime - startTime) / 1000)}s`);

  return { decisions, finalState, startTime, endTime };
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
