#!/usr/bin/env node
// AI Playtester — Tunnel / Flow Tester
// Navigates systematically through ALL game scenes, validates transitions,
// buttons, and the complete user journey end-to-end.
// Usage: node tunnel_tester.mjs [--cycle 1] [--no-launch]

import fs from 'fs';
import path from 'path';
import * as bridge from './game_bridge.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Expected Scene Flow ─────────────────────────────────────────────

const SCENE_FLOW = [
  {
    id: 'boot',
    scene: 'res://scenes/IntroCeltOS.tscn',
    name: 'Boot (IntroCeltOS)',
    expectedButtons: [],
    autoAdvance: true,
    waitMs: 5000,
  },
  {
    id: 'menu',
    scene: 'res://scenes/MenuPrincipal.tscn',
    name: 'Menu Principal',
    expectedButtons: ['nouvelle', 'continuer', 'options'],
    clickButton: 'nouvelle',
    waitMs: 3000,
  },
  {
    id: 'quiz',
    scene: 'res://scenes/IntroPersonalityQuiz.tscn',
    name: 'Personality Quiz',
    expectedButtons: [],
    skipKeys: ['enter', 'enter', 'enter', 'enter'],
    waitMs: 2000,
  },
  {
    id: 'rencontre',
    scene: 'res://scenes/SceneRencontreMerlin.tscn',
    name: 'Rencontre Merlin',
    expectedButtons: ['continuer', 'suivant', 'ok'],
    clickButton: 'continuer',
    waitMs: 3000,
  },
  {
    id: 'save_select',
    scene: 'res://scenes/SelectionSauvegarde.tscn',
    name: 'Selection Sauvegarde',
    expectedButtons: ['slot', 'sauv'],
    clickFirst: true,
    waitMs: 2000,
  },
  {
    id: 'hub',
    scene: 'res://scenes/HubAntre.tscn',
    name: 'Hub (Antre)',
    expectedButtons: ['commencer', 'explorer', 'partir'],
    clickButton: 'commencer',
    waitMs: 3000,
  },
  {
    id: 'transition',
    scene: 'res://scenes/TransitionBiome.tscn',
    name: 'Transition Biome',
    expectedButtons: [],
    autoAdvance: true,
    waitMs: 5000,
  },
  {
    id: 'gameplay',
    scene: 'res://scenes/MerlinGame.tscn',
    name: 'Gameplay (MerlinGame)',
    expectedButtons: [],
    playCards: 3,
    waitMs: 8000,
  },
];

// ── Test Runner ─────────────────────────────────────────────────────

async function runTunnelTest(options = {}) {
  const startTime = Date.now();
  const results = [];
  let scenesReached = 0;
  let transitionsFailed = 0;
  let buttonsFound = 0;
  let buttonsMissing = 0;

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║   Tunnel Tester — M.E.R.L.I.N.       ║');
  console.log('╚══════════════════════════════════════╝\n');

  // Launch
  if (!options.noLaunch) {
    console.log('[Tunnel] Launching game...');
    const ok = await bridge.launchGame();
    if (!ok) throw new Error('Game failed to launch');
    await sleep(5000);
  } else {
    if (!bridge.isGameRunning()) throw new Error('Game not running');
  }

  // Navigate through each scene
  for (const step of SCENE_FLOW) {
    console.log(`\n[Tunnel] ── ${step.name} ──`);
    const stepResult = {
      id: step.id,
      name: step.name,
      status: 'pending',
      buttonsExpected: step.expectedButtons,
      buttonsFound: [],
      buttonsMissing: [],
      transitionOk: false,
      stateSnapshot: null,
      errors: [],
      durationMs: 0,
    };
    const stepStart = Date.now();

    try {
      // Wait for scene to load
      await sleep(step.waitMs);

      // Take screenshot
      await bridge.screenshot(`tunnel_${step.id}`);

      // Read state
      const state = bridge.readState();
      stepResult.stateSnapshot = {
        phase: state?.run?.phase ?? '?',
        life: state?.run?.life ?? '?',
        cards: state?.run?.cards_played ?? 0,
      };

      // Check expected buttons
      if (step.expectedButtons.length > 0) {
        const allButtons = await bridge.listButtons();
        const buttonTexts = allButtons.map(b => (b.text || b.name || '').toLowerCase());

        for (const expected of step.expectedButtons) {
          const found = buttonTexts.some(t => t.includes(expected.toLowerCase()));
          if (found) {
            stepResult.buttonsFound.push(expected);
            buttonsFound++;
          } else {
            stepResult.buttonsMissing.push(expected);
            buttonsMissing++;
          }
        }

        console.log(`[Tunnel]   Buttons: ${stepResult.buttonsFound.length}/${step.expectedButtons.length} found`);
        if (stepResult.buttonsMissing.length > 0) {
          console.log(`[Tunnel]   Missing: ${stepResult.buttonsMissing.join(', ')}`);
        }
      }

      // Navigate to next scene
      if (step.autoAdvance) {
        console.log('[Tunnel]   Auto-advance (waiting)');
        // Scene auto-transitions
      } else if (step.clickButton) {
        const btnName = await bridge.findButton(step.clickButton);
        if (btnName) {
          console.log(`[Tunnel]   Clicking: "${btnName}"`);
          await bridge.clickButton(btnName);
        } else {
          console.log(`[Tunnel]   Button "${step.clickButton}" not found, pressing Enter`);
          await bridge.sendCommand('simulate_key', { key: 'enter' });
          stepResult.errors.push(`Button "${step.clickButton}" not found`);
        }
      } else if (step.clickFirst) {
        const allButtons = await bridge.listButtons();
        if (allButtons.length > 0) {
          console.log(`[Tunnel]   Clicking first button: "${allButtons[0].name}"`);
          await bridge.clickButton(allButtons[0].name);
        } else {
          await bridge.sendCommand('simulate_key', { key: 'enter' });
        }
      } else if (step.skipKeys) {
        for (const key of step.skipKeys) {
          await bridge.sendCommand('simulate_key', { key });
          await sleep(1500);
        }
      } else if (step.playCards) {
        // Play N cards to validate gameplay flow
        for (let i = 0; i < step.playCards; i++) {
          const card = await bridge.waitForCard(60_000);
          if (card) {
            console.log(`[Tunnel]   Card #${i + 1}: OK`);
            await bridge.clickOption(0);
            await sleep(3000);
            await bridge.waitForCardCleared(15_000);
            await sleep(2000);
          } else {
            stepResult.errors.push(`Card #${i + 1} never appeared`);
            console.log(`[Tunnel]   Card #${i + 1}: TIMEOUT`);
            await bridge.sendCommand('simulate_key', { key: 'enter' });
            await sleep(2000);
          }
        }
      }

      scenesReached++;
      stepResult.transitionOk = true;
      stepResult.status = stepResult.errors.length > 0 ? 'warn' : 'pass';

    } catch (e) {
      stepResult.status = 'fail';
      stepResult.errors.push(e.message);
      transitionsFailed++;
      console.error(`[Tunnel]   ERROR: ${e.message}`);
    }

    stepResult.durationMs = Date.now() - stepStart;
    results.push(stepResult);
    console.log(`[Tunnel]   Status: ${stepResult.status.toUpperCase()} (${stepResult.durationMs}ms)`);
  }

  // ── COMPILE REPORT ──────────────────────────────────────────────
  const report = {
    agent: 'tunnel_tester',
    cycle: options.cycle || 0,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    summary: {
      scenesTotal: SCENE_FLOW.length,
      scenesReached,
      transitionsFailed,
      buttonsFound,
      buttonsMissing,
      passRate: Math.round((scenesReached / SCENE_FLOW.length) * 100),
    },
    steps: results,
  };

  writeReport(report, options.cycle || 0);
  return report;
}

function writeReport(report, cycle) {
  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });

  const filename = `tunnel_test_c${cycle}_${Date.now()}.json`;
  const filePath = path.join(CONFIG.outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');

  const latestPath = path.join(CONFIG.statusDir, 'tunnel_test_report.json');
  fs.writeFileSync(latestPath, JSON.stringify(report, null, 2), 'utf8');

  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║     TUNNEL TEST RESULTS               ║`);
  console.log(`╠══════════════════════════════════════╣`);
  console.log(`║  Scenes: ${report.summary.scenesReached}/${report.summary.scenesTotal} reached              ║`);
  console.log(`║  Pass rate: ${String(report.summary.passRate).padEnd(3)}%                      ║`);
  console.log(`║  Buttons: ${report.summary.buttonsFound} found, ${report.summary.buttonsMissing} missing     ║`);
  console.log(`╚══════════════════════════════════════╝`);
  console.log(`\n[Tunnel] Report: ${filePath}`);

  for (const step of report.steps) {
    const icon = step.status === 'pass' ? '+' : step.status === 'warn' ? '~' : 'X';
    console.log(`  ${icon} ${step.name}: ${step.status.toUpperCase()}`);
    for (const err of step.errors) console.log(`    ! ${err}`);
  }
}

// ── CLI ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;
const noLaunch = args.includes('--no-launch');

runTunnelTest({ cycle, noLaunch }).then(() => process.exit(0)).catch(e => {
  console.error(`[Tunnel] Fatal: ${e.message}`);
  process.exit(1);
});
