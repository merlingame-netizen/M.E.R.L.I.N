#!/usr/bin/env node
// AI Playtester — Visual QA Agent
// Navigates scenes, takes burst screenshots at key moments, produces visual quality report.
// Usage: node visual_qa.mjs [--cycle 1] [--no-launch]

import fs from 'fs';
import path from 'path';
import * as bridge from './game_bridge.mjs';
import { generate, checkHealth } from './llm_client.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Scene Checkpoints ───────────────────────────────────────────────
// Each checkpoint: navigate to scene, take screenshots, run visual checks

const CHECKPOINTS = [
  {
    id: 'menu',
    name: 'Menu Principal',
    buttons: ['nouvelle', 'new', 'jouer'],
    checks: ['background_render', 'button_visibility', 'text_legibility', 'crt_effect'],
  },
  {
    id: 'hub',
    name: 'Hub Antre',
    buttons: ['commencer', 'explorer', 'partir'],
    checks: ['biome_selector', 'ogham_display', 'ui_layout', 'color_palette'],
  },
  {
    id: 'gameplay',
    name: 'Gameplay (3 cartes)',
    buttons: [],
    checks: ['card_render', 'biome_backdrop', 'parallax_layers', 'scanlines', 'option_buttons', 'sfx_indicators'],
  },
];

// ── Visual Analysis Prompts ─────────────────────────────────────────

function buildVisualAnalysisPrompt(checkpoint, stateData, perfData) {
  const fps = perfData?.fps ?? '?';
  const phase = stateData?.run?.phase ?? '?';
  const biome = stateData?.run?.biome ?? '?';

  return `Tu es un QA testeur visuel pour un jeu vidéo rétro-celtique (M.E.R.L.I.N.).
Le jeu utilise une esthétique CRT pixel art (160x90 upscalé) avec des effets scanlines.

CONTEXTE ACTUEL :
- Scène : ${checkpoint.name} (${checkpoint.id})
- Phase : ${phase} | Biome : ${biome}
- FPS : ${fps}

CHECKLIST VISUELLE pour cette scène (${checkpoint.checks.join(', ')}) :

Analyse chaque point et réponds en JSON :
{
  "scene": "${checkpoint.id}",
  "fps": ${fps},
  "checks": {
    ${checkpoint.checks.map(c => `"${c}": {"status": "pass|warn|fail", "detail": "<une phrase>"}`).join(',\n    ')}
  },
  "artifacts_detected": ["<description artefact visuel>"],
  "overall_quality": <1-10>,
  "recommendations": ["<amélioration suggérée>"]
}`;
}

// ── Main Flow ───────────────────────────────────────────────────────

async function runVisualQA(options = {}) {
  const startTime = Date.now();
  const results = [];

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║     Visual QA Agent — M.E.R.L.I.N.   ║');
  console.log('╚══════════════════════════════════════╝\n');

  // Launch game if needed
  if (!options.noLaunch) {
    console.log('[VisualQA] Launching game...');
    const ok = await bridge.launchGame();
    if (!ok) throw new Error('Game failed to launch');
    await sleep(5000);
  } else {
    if (!bridge.isGameRunning()) throw new Error('Game not running');
  }

  // ── CHECKPOINT: MENU ────────────────────────────────────────────
  console.log('[VisualQA] Checkpoint: Menu');
  await sleep(3000);
  await bridge.screenshot('vqa_menu');
  await bridge.sendCommand('burst_screenshot', { count: 5, interval: 0.5 });
  await sleep(4000);

  let state = bridge.readState();
  let perf = null;
  try {
    const perfPath = path.join(CONFIG.capturesDir, 'perf.json');
    if (fs.existsSync(perfPath)) perf = JSON.parse(fs.readFileSync(perfPath, 'utf8'));
  } catch { /* ignore */ }

  const menuAnalysis = await analyzeCheckpoint(CHECKPOINTS[0], state, perf);
  results.push(menuAnalysis);

  // Navigate to hub
  const menuBtn = await bridge.findButton('nouvelle') || await bridge.findButton('new');
  if (menuBtn) {
    await bridge.clickButton(menuBtn);
  } else {
    await bridge.sendCommand('simulate_key', { key: 'enter' });
  }
  await sleep(4000);

  // ── CHECKPOINT: HUB ─────────────────────────────────────────────
  console.log('[VisualQA] Checkpoint: Hub');
  await bridge.screenshot('vqa_hub');
  await bridge.sendCommand('burst_screenshot', { count: 5, interval: 0.5 });
  await sleep(4000);

  state = bridge.readState();
  const hubAnalysis = await analyzeCheckpoint(CHECKPOINTS[1], state, perf);
  results.push(hubAnalysis);

  // Navigate to gameplay
  const hubBtn = await bridge.findButton('commencer') || await bridge.findButton('start');
  if (hubBtn) {
    await bridge.clickButton(hubBtn);
  } else {
    await bridge.sendCommand('simulate_key', { key: 'enter' });
  }
  await sleep(8000);

  // ── CHECKPOINT: GAMEPLAY (3 cartes) ─────────────────────────────
  console.log('[VisualQA] Checkpoint: Gameplay');

  for (let i = 0; i < 3; i++) {
    const card = await bridge.waitForCard(60_000);
    if (!card) {
      console.log(`[VisualQA] No card #${i + 1}, pressing Enter`);
      await bridge.sendCommand('simulate_key', { key: 'enter' });
      await sleep(3000);
      continue;
    }

    console.log(`[VisualQA] Card #${i + 1}: "${card.text?.slice(0, 50)}..."`);
    await bridge.screenshot(`vqa_card_${i + 1}`);
    await bridge.sendCommand('burst_screenshot', { count: 3, interval: 0.3 });
    await sleep(2000);

    // Pick option 0 (we don't care about strategy, just visuals)
    await bridge.clickOption(0);
    await sleep(4000);
    await bridge.waitForCardCleared(15_000);
    await sleep(2000);
  }

  state = bridge.readState();
  try {
    const perfPath = path.join(CONFIG.capturesDir, 'perf.json');
    if (fs.existsSync(perfPath)) perf = JSON.parse(fs.readFileSync(perfPath, 'utf8'));
  } catch { /* ignore */ }

  const gameAnalysis = await analyzeCheckpoint(CHECKPOINTS[2], state, perf);
  results.push(gameAnalysis);

  // ── COMPILE REPORT ──────────────────────────────────────────────
  const report = compileReport(results, startTime, options.cycle || 0);
  writeReport(report, options.cycle || 0);

  return report;
}

async function analyzeCheckpoint(checkpoint, state, perf) {
  const prompt = buildVisualAnalysisPrompt(checkpoint, state, perf);
  try {
    const response = await generate(prompt, { temperature: 0.4, maxTokens: 512 });
    const jsonMatch = response.text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[0].replace(/,\s*}/g, '}').replace(/,\s*]/g, ']'));
      } catch { /* fallback below */ }
    }
    return {
      scene: checkpoint.id,
      checks: {},
      overall_quality: 5,
      artifacts_detected: [],
      recommendations: ['LLM response parse error'],
      raw_response: response.text.slice(0, 300),
    };
  } catch (e) {
    return {
      scene: checkpoint.id,
      checks: {},
      overall_quality: 0,
      artifacts_detected: [],
      recommendations: [`LLM error: ${e.message}`],
    };
  }
}

function compileReport(results, startTime, cycle) {
  const avgQuality = results.length > 0
    ? Math.round(results.reduce((sum, r) => sum + (r.overall_quality || 0), 0) / results.length * 10) / 10
    : 0;

  const allArtifacts = results.flatMap(r => r.artifacts_detected || []);
  const allRecs = results.flatMap(r => r.recommendations || []);

  return {
    agent: 'visual_qa',
    cycle,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    averageQuality: avgQuality,
    checkpoints: results,
    allArtifacts,
    allRecommendations: [...new Set(allRecs)],
  };
}

function writeReport(report, cycle) {
  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });

  const filename = `visual_qa_c${cycle}_${Date.now()}.json`;
  const filePath = path.join(CONFIG.outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');

  const latestPath = path.join(CONFIG.statusDir, 'visual_qa_report.json');
  fs.writeFileSync(latestPath, JSON.stringify(report, null, 2), 'utf8');

  console.log(`\n[VisualQA] Report: ${filePath}`);
  console.log(`[VisualQA] Quality: ${report.averageQuality}/10`);
  if (report.allArtifacts.length > 0) {
    console.log('[VisualQA] Artifacts:');
    for (const a of report.allArtifacts) console.log(`  ! ${a}`);
  }
}

// ── CLI ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;
const noLaunch = args.includes('--no-launch');

(async () => {
  const healthy = await checkHealth();
  if (!healthy) { console.error('[VisualQA] Ollama not running'); process.exit(1); }

  try {
    await runVisualQA({ cycle, noLaunch });
    process.exit(0);
  } catch (e) {
    console.error(`[VisualQA] Fatal: ${e.message}`);
    process.exit(1);
  }
})();
