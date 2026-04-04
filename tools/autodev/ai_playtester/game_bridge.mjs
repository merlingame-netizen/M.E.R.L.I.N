// AI Playtester — Game Bridge
// File-based I/O with Godot GameObserver: read state, write commands, poll results

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { CONFIG } from './config.mjs';

const STATE_FILE = path.join(CONFIG.capturesDir, 'state.json');
const COMMAND_FILE = path.join(CONFIG.capturesDir, 'command.json');
const RESULT_FILE = path.join(CONFIG.capturesDir, 'command_result.json');

let _cmdCounter = 0;
let _lastCommandMs = 0;
const MIN_COMMAND_GAP_MS = 1500; // Godot polls command.json every 1s

// ── Helpers ─────────────────────────────────────────────────────────

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Safe JSON read — retries on partial write from Godot (sync version)
 */
function safeReadJson(filePath, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(raw);
    } catch {
      if (i < retries - 1) {
        // Brief sync pause — acceptable for readState() which must be sync
        const end = Date.now() + 100;
        while (Date.now() < end) { /* spin */ }
      }
    }
  }
  return null;
}

/**
 * Async-safe JSON read — retries with non-blocking sleep
 */
async function safeReadJsonAsync(filePath, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(raw);
    } catch {
      if (i < retries - 1) {
        await sleep(200);
      }
    }
  }
  return null;
}

// ── State Reading ───────────────────────────────────────────────────

/**
 * Read current game state from captures/state.json
 * @returns {object|null}
 */
export function readState() {
  return safeReadJson(STATE_FILE);
}

/**
 * Check if state.json exists (game is running)
 */
export function isGameRunning() {
  return fs.existsSync(STATE_FILE);
}

// ── Command System ──────────────────────────────────────────────────

/**
 * Send a command to GameObserver and wait for result
 * @param {string} action
 * @param {object} params
 * @returns {Promise<object|null>} result or null on timeout
 */
export async function sendCommand(action, params = {}) {
  // Enforce minimum gap between commands (Godot polls every 1s)
  const elapsed = Date.now() - _lastCommandMs;
  if (elapsed < MIN_COMMAND_GAP_MS) {
    await sleep(MIN_COMMAND_GAP_MS - elapsed);
  }

  _cmdCounter++;
  const cmdId = `pt_${Date.now()}_${_cmdCounter}`;

  const command = {
    action,
    params,
    id: cmdId,
    timestamp: new Date().toISOString(),
  };

  // Atomic write: temp file + rename
  const tmpPath = COMMAND_FILE + '.tmp';
  fs.writeFileSync(tmpPath, JSON.stringify(command, null, '\t'), 'utf8');
  fs.renameSync(tmpPath, COMMAND_FILE);
  _lastCommandMs = Date.now();

  // Poll for matching result
  const deadline = Date.now() + CONFIG.commandTimeoutMs;
  while (Date.now() < deadline) {
    await sleep(500);
    if (fs.existsSync(RESULT_FILE)) {
      const result = safeReadJson(RESULT_FILE);
      if (result && result.command_id === cmdId) {
        return result;
      }
    }
  }

  console.warn(`[Bridge] Command timeout: ${action} (${cmdId})`);
  return null;
}

// ── Shorthand Commands ──────────────────────────────────────────────

export async function clickOption(index) {
  return sendCommand('click_option', { option: index });
}

export async function clickButton(name) {
  return sendCommand('click_button', { name });
}

export async function listButtons() {
  const result = await sendCommand('list_buttons');
  if (result && result.status === 'ok') {
    return result.buttons || [];
  }
  return [];
}

export async function getCardData() {
  const result = await sendCommand('get_card_data');
  if (result && result.status === 'ok' && result.card) {
    return result.card;
  }
  return null;
}

export async function screenshot(label) {
  return sendCommand('screenshot', { label });
}

export async function getState() {
  return sendCommand('get_state');
}

// ── Polling / Waiting ───────────────────────────────────────────────

/**
 * Wait until a card with non-empty text appears
 * @param {number} timeoutMs
 * @returns {Promise<object|null>}
 */
export async function waitForCard(timeoutMs = CONFIG.cardWaitTimeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    // First try state.json card field (faster, no command overhead)
    const state = await safeReadJsonAsync(STATE_FILE);
    if (state && state.card && state.card.text) {
      return state.card;
    }
    // Fallback: explicit get_card_data command
    const card = await getCardData();
    if (card && card.text) {
      return card;
    }
    await sleep(CONFIG.statePollMs);
  }
  console.warn('[Bridge] waitForCard timeout');
  return null;
}

/**
 * Wait until card is cleared (between cards)
 * @param {number} timeoutMs
 * @returns {Promise<boolean>}
 */
export async function waitForCardCleared(timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const state = await safeReadJsonAsync(STATE_FILE);
    if (state && (!state.card || !state.card.text)) {
      return true;
    }
    await sleep(1000);
  }
  return false;
}

/**
 * Wait until state.json phase matches target
 * @param {string} targetPhase
 * @param {number} timeoutMs
 * @returns {Promise<object|null>}
 */
export async function waitForPhase(targetPhase, timeoutMs = CONFIG.phaseWaitTimeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const state = await safeReadJsonAsync(STATE_FILE);
    if (state && state.run && state.run.phase === targetPhase) {
      return state;
    }
    await sleep(CONFIG.statePollMs);
  }
  console.warn(`[Bridge] waitForPhase timeout: ${targetPhase}`);
  return null;
}

/**
 * Wait for state.json to appear (game launched)
 * @param {number} timeoutMs
 * @returns {Promise<boolean>}
 */
export async function waitForGameReady(timeoutMs = CONFIG.launchWaitMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (isGameRunning()) {
      const state = readState();
      if (state && state.timestamp) {
        return true;
      }
    }
    await sleep(2000);
  }
  return false;
}

// ── Game Launch ─────────────────────────────────────────────────────

/**
 * Launch the game via PowerShell script
 * @returns {Promise<boolean>} true if game started
 */
export async function launchGame() {
  console.log('[Bridge] Launching game...');

  // Clean old captures
  for (const f of [STATE_FILE, COMMAND_FILE, RESULT_FILE]) {
    if (fs.existsSync(f)) fs.unlinkSync(f);
  }

  try {
    execSync(
      `powershell -ExecutionPolicy Bypass -File "${CONFIG.launchScript}" -Scene "${CONFIG.godotScene}" -Clean`,
      { stdio: 'pipe', timeout: 15_000 }
    );
  } catch (e) {
    // launch_game.ps1 returns immediately (game is async), so errors here are unexpected
    console.warn(`[Bridge] Launch warning: ${(e.message || '').slice(0, 200)}`);
  }

  console.log('[Bridge] Waiting for game to initialize...');
  const ready = await waitForGameReady();
  if (ready) {
    console.log('[Bridge] Game is ready');
  } else {
    console.error('[Bridge] Game failed to start (no state.json after timeout)');
  }
  return ready;
}

/**
 * Find a button by partial text match
 * @param {string} textFragment — substring to search in button text
 * @returns {Promise<string|null>} button name or null
 */
export async function findButton(textFragment) {
  const buttons = await listButtons();
  const lower = textFragment.toLowerCase();
  for (const btn of buttons) {
    const text = (btn.text || btn.name || '').toLowerCase();
    if (text.includes(lower)) {
      return btn.name;
    }
  }
  return null;
}
