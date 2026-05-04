#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────
// director-tick.mjs
//
// One pass of the studio-director loop. Designed to be invoked every
// 5 minutes by tools/octogent/scripts/director-watchdog.sh. Idempotent:
// safe to run as often as desired.
//
// Responsibilities (per PROJECT.md):
//   1. Verify Octogent is alive (HTTP 200 on /api/deck/tentacles).
//   2. Inspect studio_director tentacle state.
//   3. If todo.md still has [ ] items AND no swarm is currently running,
//      POST a swarm to wake the workers.
//   4. Append a structured entry to cycle_log.md.
//
// What this script does NOT do (intentionally):
//   - It does not write code itself. The smart work happens INSIDE the
//     Claude agents spawned by the swarm — they read CONTEXT.md, decide
//     the dispatch strategy, and act.
//   - It does not run quality gates. That's a separate script
//     (director-quality-gates.sh) called after each commit batch.
//   - It does not restart Octogent. That's the watchdog's job.
//
// Usage:
//   node tools/octogent/scripts/director-tick.mjs [--dry-run]
// ─────────────────────────────────────────────────────────────────────

import { existsSync, appendFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OCTOGENT_DIR = resolve(__dirname, "..");                // tools/octogent/
const TENTACLE_DIR = join(OCTOGENT_DIR, ".octogent", "tentacles", "studio_director");
const CYCLE_LOG = join(TENTACLE_DIR, "cycle_log.md");

const OCTOGENT_BASE = process.env.OCTOGENT_BASE ?? "http://localhost:8787";
const DRY_RUN = process.argv.includes("--dry-run");

const now = () => new Date().toISOString();

const log = (msg) => {
  console.log(`[director-tick ${now()}] ${msg}`);
};

const appendCycleLog = (entry) => {
  if (!existsSync(TENTACLE_DIR)) mkdirSync(TENTACLE_DIR, { recursive: true });
  appendFileSync(CYCLE_LOG, entry);
};

// ── Step 1: Octogent health ────────────────────────────────────────────
let healthOk = false;
let tentacles = [];
try {
  const res = await fetch(`${OCTOGENT_BASE}/api/deck/tentacles`, { signal: AbortSignal.timeout(5000) });
  if (res.ok) {
    tentacles = await res.json();
    healthOk = true;
    log(`Octogent OK (${tentacles.length} tentacles).`);
  } else {
    log(`Octogent HTTP ${res.status}`);
  }
} catch (e) {
  log(`Octogent unreachable: ${e.message}`);
}

if (!healthOk) {
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: **DOWN**\n- Action: skip (watchdog will restart)\n`);
  process.exit(2);
}

// ── Step 2: studio_director tentacle state ────────────────────────────
const directorEntry = tentacles.find((t) => t.tentacleId === "studio_director");
if (!directorEntry) {
  log(`studio_director tentacle missing from deck — abort.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Action: **abort** (studio_director tentacle not found in deck)\n`);
  process.exit(3);
}

const todoTotal = directorEntry.todoTotal ?? 0;
const todoDone = directorEntry.todoDone ?? 0;
const todoOpen = todoTotal - todoDone;
log(`studio_director: ${todoDone}/${todoTotal} todos done (${todoOpen} open).`);

// ── Step 3: existing swarm? ────────────────────────────────────────────
// CRITICAL FIX (post-review): use GET /api/terminal-snapshots (read-only).
// The previous code POSTed /api/terminals body {} which Octogent's
// terminalRoutes.ts treats as a CREATE, leaking a ghost terminal every
// tick. Confirmed source: terminalRoutes.ts:63-271 (POST = create).
// Correct list endpoint: terminalRoutes.ts:45-60 GET /api/terminal-snapshots.
let activeSwarm = null;
try {
  const res = await fetch(`${OCTOGENT_BASE}/api/terminal-snapshots`, {
    signal: AbortSignal.timeout(5000),
  });
  if (res.ok) {
    const data = await res.json();
    const arr = Array.isArray(data) ? data : (data.snapshots ?? data.terminals ?? []);
    activeSwarm = arr.find((t) => String(t.terminalId ?? "").startsWith("studio_director-swarm-"));
  }
} catch (e) {
  log(`Terminal list fetch failed: ${e.message} — assuming no active swarm.`);
}

if (activeSwarm) {
  log(`Active swarm detected: ${activeSwarm.terminalId} (status=${activeSwarm.status ?? "?"}). Skip spawn.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: \`${activeSwarm.terminalId}\` status=${activeSwarm.status ?? "?"}\n- Open todos: ${todoOpen}\n- Action: **skip** (swarm already running)\n`);
  process.exit(0);
}

// ── Step 4: spawn or noop ──────────────────────────────────────────────
if (todoOpen === 0) {
  log(`No open todos — nothing to dispatch. Director idle.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: 0\n- Action: **noop** (no work)\n`);
  process.exit(0);
}

if (DRY_RUN) {
  log(`[DRY RUN] Would POST swarm with ${todoOpen} open todos.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: ${todoOpen}\n- Action: **dry-run** (would spawn)\n`);
  process.exit(0);
}

log(`Spawning swarm — ${todoOpen} workers expected (capped server-side).`);
let spawnResult;
try {
  const res = await fetch(`${OCTOGENT_BASE}/api/deck/tentacles/studio_director/swarm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ agentProvider: "claude-code", workspaceMode: "worktree" }),
    signal: AbortSignal.timeout(10000),
  });
  spawnResult = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${spawnResult.error ?? "unknown"}`);
} catch (e) {
  log(`Spawn failed: ${e.message}`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: ${todoOpen}\n- Action: **spawn-failed**\n- Error: \`${e.message}\`\n`);
  process.exit(4);
}

const workerCount = Array.isArray(spawnResult.workers) ? spawnResult.workers.length : 0;
log(`Swarm spawned: parent=${spawnResult.parentTerminalId} + ${workerCount} workers.`);
appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: spawned\n- Open todos: ${todoOpen}\n- Action: **spawn**\n- Parent: \`${spawnResult.parentTerminalId}\`\n- Workers: ${workerCount}\n${(spawnResult.workers ?? []).map((w) => `  - \`${w.terminalId}\` -> ${String(w.todoText ?? "").slice(0, 100)}`).join("\n")}\n`);
process.exit(0);
