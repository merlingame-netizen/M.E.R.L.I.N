#!/usr/bin/env node
// AI Playtester — Blind Navigator
// Explores the game with ZERO knowledge: clicks random buttons, presses random keys,
// discovers deadlocks, broken buttons, crashes, unreachable states.
// Usage: node blind_navigator.mjs [--cycle 1] [--no-launch] [--duration 120]

import fs from 'fs';
import path from 'path';
import * as bridge from './game_bridge.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

const KEYS = ['enter', 'space', 'escape', 'up', 'down', 'left', 'right', 'tab', '1', '2', '3'];

async function runBlindNavigation(options = {}) {
  const startTime = Date.now();
  const durationMs = (options.duration || 120) * 1000;
  const deadline = startTime + durationMs;
  const events = [];
  let actionCount = 0;
  let crashCount = 0;
  let deadlockCount = 0;
  let lastPhase = '';
  let stuckCounter = 0;
  const scenesVisited = new Set();
  const buttonsClicked = new Set();
  const errorsFound = [];

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  Blind Navigator — Chaos Testing     ║');
  console.log(`║  Duration: ${options.duration || 120}s                        ║`);
  console.log('╚══════════════════════════════════════╝\n');

  if (!options.noLaunch) {
    const ok = await bridge.launchGame();
    if (!ok) throw new Error('Game failed to launch');
    await sleep(5000);
  } else {
    if (!bridge.isGameRunning()) throw new Error('Game not running');
  }

  while (Date.now() < deadline) {
    actionCount++;
    const state = bridge.readState();
    const phase = state?.run?.phase || 'unknown';

    // Track scene changes
    if (phase !== lastPhase) {
      scenesVisited.add(phase);
      events.push({ action: 'phase_change', from: lastPhase, to: phase, at: actionCount });
      console.log(`[Blind] Phase: ${lastPhase} → ${phase}`);
      lastPhase = phase;
      stuckCounter = 0;
    } else {
      stuckCounter++;
    }

    // Detect deadlock (stuck on same phase for 15+ actions)
    if (stuckCounter >= 15) {
      deadlockCount++;
      events.push({ action: 'deadlock_detected', phase, at: actionCount, stuckFor: stuckCounter });
      console.log(`[Blind] DEADLOCK detected in phase "${phase}" (stuck ${stuckCounter} actions)`);
      stuckCounter = 0;
      // Try to escape: mash escape + enter
      await bridge.sendCommand('simulate_key', { key: 'escape' });
      await sleep(1000);
      await bridge.sendCommand('simulate_key', { key: 'enter' });
      await sleep(1000);
    }

    // Random action selection (weighted)
    const roll = Math.random();

    if (roll < 0.35) {
      // Click a random visible button
      const buttons = await bridge.listButtons();
      if (buttons.length > 0) {
        const btn = buttons[Math.floor(Math.random() * buttons.length)];
        const name = btn.name || 'unknown';
        buttonsClicked.add(name);
        const result = await bridge.clickButton(name);
        const status = result?.status || 'timeout';
        events.push({ action: 'click_button', button: name, status, at: actionCount });
        if (status === 'error') {
          errorsFound.push({ type: 'button_error', button: name, error: result?.error, at: actionCount });
        }
      }
    } else if (roll < 0.55) {
      // Press random key
      const key = KEYS[Math.floor(Math.random() * KEYS.length)];
      await bridge.sendCommand('simulate_key', { key });
      events.push({ action: 'key_press', key, at: actionCount });
    } else if (roll < 0.70) {
      // Click random screen position
      const x = Math.floor(Math.random() * 800);
      const y = Math.floor(Math.random() * 600);
      await bridge.sendCommand('simulate_click', { x, y });
      events.push({ action: 'random_click', x, y, at: actionCount });
    } else if (roll < 0.80) {
      // Try card option if available
      const card = await bridge.getCardData();
      if (card && card.text) {
        const opt = Math.floor(Math.random() * (card.options?.length || 3));
        await bridge.clickOption(opt);
        events.push({ action: 'card_option', option: opt, at: actionCount });
      }
    } else if (roll < 0.90) {
      // Take screenshot for analysis
      await bridge.screenshot(`blind_${actionCount}`);
      events.push({ action: 'screenshot', at: actionCount });
    } else {
      // Check game health (is it still responding?)
      const preState = bridge.readState();
      await sleep(3000);
      const postState = bridge.readState();
      if (preState && postState && preState.timestamp === postState.timestamp) {
        // State hasn't updated in 3s — game might be frozen
        crashCount++;
        events.push({ action: 'possible_freeze', at: actionCount });
        errorsFound.push({ type: 'freeze', phase, at: actionCount });
        console.log(`[Blind] POSSIBLE FREEZE at action ${actionCount} (state unchanged)`);
      }
    }

    // Check log for errors
    if (state?.log_tail) {
      for (const log of state.log_tail) {
        const logStr = typeof log === 'string' ? log : JSON.stringify(log);
        if (logStr.includes('ERROR') || logStr.includes('SCRIPT ERROR')) {
          errorsFound.push({ type: 'log_error', message: logStr.slice(0, 200), at: actionCount });
        }
      }
    }

    await sleep(1500 + Math.random() * 1500); // 1.5-3s between actions (human-like)
  }

  // Final screenshot
  await bridge.screenshot('blind_final');

  const report = {
    agent: 'blind_navigator',
    cycle: options.cycle || 0,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    summary: {
      totalActions: actionCount,
      scenesVisited: [...scenesVisited],
      scenesCount: scenesVisited.size,
      buttonsDiscovered: buttonsClicked.size,
      deadlocksDetected: deadlockCount,
      possibleCrashes: crashCount,
      errorsFound: errorsFound.length,
    },
    errors: errorsFound,
    events: events.slice(-100), // Last 100 events
  };

  writeReport(report, options.cycle || 0);
  return report;
}

function writeReport(report, cycle) {
  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const filename = `blind_nav_c${cycle}_${Date.now()}.json`;
  const filePath = path.join(CONFIG.outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');
  fs.writeFileSync(path.join(CONFIG.statusDir, 'blind_nav_report.json'), JSON.stringify(report, null, 2), 'utf8');

  const s = report.summary;
  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║    BLIND NAVIGATOR RESULTS            ║`);
  console.log(`╠══════════════════════════════════════╣`);
  console.log(`║  Actions: ${String(s.totalActions).padEnd(6)} Scenes: ${String(s.scenesCount).padEnd(8)}║`);
  console.log(`║  Buttons: ${String(s.buttonsDiscovered).padEnd(6)} Deadlocks: ${String(s.deadlocksDetected).padEnd(5)}║`);
  console.log(`║  Crashes: ${String(s.possibleCrashes).padEnd(6)} Errors: ${String(s.errorsFound).padEnd(8)}║`);
  console.log(`╚══════════════════════════════════════╝`);
  console.log(`Report: ${filePath}`);
  for (const e of report.errors.slice(0, 5)) console.log(`  ! [${e.type}] ${e.message || e.button || e.phase || ''}`);
}

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;
const duration = parseInt(args[args.indexOf('--duration') + 1]) || 120;
const noLaunch = args.includes('--no-launch');

runBlindNavigation({ cycle, noLaunch, duration }).then(() => process.exit(0)).catch(e => {
  console.error(`[Blind] Fatal: ${e.message}`);
  process.exit(1);
});
