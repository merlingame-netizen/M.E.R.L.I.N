#!/usr/bin/env node
// AI Playtester — Entry Point
// Usage: node playtester.mjs --persona explorer [--cycle 1] [--no-launch] [--model qwen2.5:7b]

import { checkHealth } from './llm_client.mjs';
import { getPersona, listPersonaIds } from './personas.mjs';
import { runPlaytest } from './state_machine.mjs';
import { generateReport } from './report_generator.mjs';
import { CONFIG } from './config.mjs';

// ── CLI Argument Parsing ─────────────────��──────────────────────────

function parseArgs(argv) {
  const args = {
    persona: null,
    cycle: 0,
    noLaunch: false,
    model: null,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case '--persona':
        args.persona = argv[++i];
        break;
      case '--cycle':
        args.cycle = parseInt(argv[++i]) || 0;
        break;
      case '--no-launch':
        args.noLaunch = true;
        break;
      case '--model':
        args.model = argv[++i];
        break;
      case '--help':
        printHelp();
        process.exit(0);
    }
  }

  return args;
}

function printHelp() {
  const ids = listPersonaIds().join(', ');
  console.log(`
AI Playtester for M.E.R.L.I.N.

Usage:
  node playtester.mjs --persona <id> [options]

Personas: ${ids}

Options:
  --persona <id>   Player persona (required)
  --cycle <n>      Cycle number for report naming (default: 0)
  --no-launch      Skip game launch (game already running)
  --model <name>   Override Ollama model (default: ${CONFIG.ollamaModel})
  --help           Show this help
`);
}

// ── Main ─────────────────────────────────────────��──────────────────

async function main() {
  const args = parseArgs(process.argv);

  if (!args.persona) {
    console.error('Error: --persona is required');
    printHelp();
    process.exit(1);
  }

  const persona = getPersona(args.persona);
  if (persona.id !== args.persona) {
    console.warn(`Warning: persona "${args.persona}" not found, using "${persona.id}"`);
  }

  // Override model if specified
  if (args.model) {
    CONFIG.ollamaModel = args.model;
  }

  // Health check
  console.log(`[Playtester] Checking Ollama (${CONFIG.ollamaUrl})...`);
  const healthy = await checkHealth();
  if (!healthy) {
    console.error('[Playtester] Ollama is not running. Start it with: ollama serve');
    process.exit(1);
  }
  console.log(`[Playtester] Ollama OK (model: ${CONFIG.ollamaModel})`);

  // Run playtest
  const t0 = Date.now();
  let result;
  try {
    result = await runPlaytest(persona, { noLaunch: args.noLaunch });
  } catch (e) {
    console.error(`[Playtester] Fatal: ${e.message}`);
    process.exit(1);
  }

  // Generate report
  const { report, filePath } = await generateReport(
    result.decisions,
    result.finalState,
    persona,
    result.startTime,
    result.endTime,
    args.cycle,
  );

  const totalSec = Math.round((Date.now() - t0) / 1000);
  console.log(`\n[Playtester] Done in ${totalSec}s — Report: ${filePath}`);

  // Exit code based on fun rating
  const funRating = report.subjective?.fun_rating ?? 5;
  if (funRating <= 3) {
    console.log(`[Playtester] ⚠ Low fun rating (${funRating}/10) — flagging for review`);
    process.exit(2);
  }

  process.exit(0);
}

main().catch(e => {
  console.error(`[Playtester] Unhandled: ${e.message}`);
  process.exit(1);
});
