#!/usr/bin/env node
// AI Playtester — UX Critic
// Evaluates user experience: clarity, feedback, timing, frustration, information hierarchy.
// Measures response times, counts clicks-to-action, checks visual feedback.
// Usage: node ux_critic.mjs [--cycle 1] [--no-launch]

import fs from 'fs';
import path from 'path';
import * as bridge from './game_bridge.mjs';
import { generate, checkHealth } from './llm_client.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function runUXCritic(options = {}) {
  const startTime = Date.now();
  const measurements = [];

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║      UX Critic — M.E.R.L.I.N.        ║');
  console.log('╚══════════════════════════════════════╝\n');

  if (!options.noLaunch) {
    const ok = await bridge.launchGame();
    if (!ok) throw new Error('Game failed to launch');
    await sleep(5000);
  } else {
    if (!bridge.isGameRunning()) throw new Error('Game not running');
  }

  // ── TEST 1: Boot to first interaction ─────────────────────────
  console.log('[UX] Test: Boot → First interaction');
  const bootStart = Date.now();
  let firstButton = null;
  for (let i = 0; i < 10; i++) {
    const buttons = await bridge.listButtons();
    if (buttons.length > 0) {
      firstButton = buttons[0];
      break;
    }
    await sleep(1000);
  }
  const bootToInteract = Date.now() - bootStart;
  measurements.push({
    test: 'boot_to_first_interaction',
    valueMs: bootToInteract,
    pass: bootToInteract < 10000,
    threshold: '< 10s',
    detail: firstButton ? `First button: "${firstButton.name}"` : 'No buttons found',
  });
  console.log(`[UX]   ${bootToInteract}ms (${bootToInteract < 10000 ? 'PASS' : 'FAIL'}: threshold < 10s)`);

  // ── TEST 2: Button count per screen ───────────────────────────
  console.log('[UX] Test: Button discoverability');
  const allButtons = await bridge.listButtons();
  const visibleButtons = allButtons.filter(b => b.visible !== false);
  const disabledButtons = allButtons.filter(b => b.disabled === true);
  measurements.push({
    test: 'button_discoverability',
    total: allButtons.length,
    visible: visibleButtons.length,
    disabled: disabledButtons.length,
    pass: visibleButtons.length >= 1 && visibleButtons.length <= 10,
    threshold: '1-10 visible buttons',
    detail: visibleButtons.map(b => b.name || b.text).join(', '),
  });

  // Navigate into game
  const navBtn = await bridge.findButton('nouvelle') || await bridge.findButton('new');
  if (navBtn) await bridge.clickButton(navBtn);
  else await bridge.sendCommand('simulate_key', { key: 'enter' });
  await sleep(3000);

  // Try to get to gameplay
  for (const kw of ['commencer', 'start', 'continuer', 'ok']) {
    const btn = await bridge.findButton(kw);
    if (btn) { await bridge.clickButton(btn); await sleep(3000); }
  }
  await bridge.sendCommand('simulate_key', { key: 'enter' });
  await sleep(5000);

  // ── TEST 3: Card appearance time ──────────────────────────────
  console.log('[UX] Test: Card appearance time');
  const cardStart = Date.now();
  const card = await bridge.waitForCard(90_000);
  const cardAppearMs = Date.now() - cardStart;
  measurements.push({
    test: 'card_appearance_time',
    valueMs: cardAppearMs,
    pass: cardAppearMs < 15000,
    threshold: '< 15s',
    detail: card ? `Card: "${card.text?.slice(0, 50)}..."` : 'No card appeared',
  });
  console.log(`[UX]   ${cardAppearMs}ms (${cardAppearMs < 15000 ? 'PASS' : 'FAIL'})`);

  // ── TEST 4: Option click response time ────────────────────────
  if (card) {
    console.log('[UX] Test: Option response time');
    await bridge.screenshot('ux_card');
    const clickStart = Date.now();
    await bridge.clickOption(0);
    await bridge.waitForCardCleared(15_000);
    const clickResponseMs = Date.now() - clickStart;
    measurements.push({
      test: 'option_response_time',
      valueMs: clickResponseMs,
      pass: clickResponseMs < 5000,
      threshold: '< 5s',
    });
    console.log(`[UX]   ${clickResponseMs}ms (${clickResponseMs < 5000 ? 'PASS' : 'FAIL'})`);
    await sleep(3000);

    // ── TEST 5: Second card (measures card generation pipeline) ──
    console.log('[UX] Test: Next card pipeline');
    const nextCardStart = Date.now();
    const card2 = await bridge.waitForCard(120_000);
    const nextCardMs = Date.now() - nextCardStart;
    measurements.push({
      test: 'next_card_pipeline',
      valueMs: nextCardMs,
      pass: nextCardMs < 20000,
      threshold: '< 20s',
      detail: card2 ? 'Card appeared' : 'Timeout',
    });
    console.log(`[UX]   ${nextCardMs}ms (${nextCardMs < 20000 ? 'PASS' : 'FAIL'})`);
  }

  // ── TEST 6: FPS check ─────────────────────────────────────────
  console.log('[UX] Test: FPS stability');
  try {
    const perfPath = path.join(CONFIG.capturesDir, 'perf.json');
    if (fs.existsSync(perfPath)) {
      const perf = JSON.parse(fs.readFileSync(perfPath, 'utf8'));
      measurements.push({
        test: 'fps_stability',
        fps_avg: perf.fps_avg,
        fps_min: perf.fps_min,
        pass: (perf.fps_avg || 0) >= 30,
        threshold: 'avg >= 30 FPS',
      });
      console.log(`[UX]   avg=${perf.fps_avg} min=${perf.fps_min} (${(perf.fps_avg || 0) >= 30 ? 'PASS' : 'FAIL'})`);
    }
  } catch { /* ignore */ }

  // ── LLM UX ANALYSIS ───────────────────────────────────────────
  console.log('[UX] Generating UX analysis...');
  const uxAnalysis = await generateUXAnalysis(measurements);

  const report = {
    agent: 'ux_critic',
    cycle: options.cycle || 0,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    measurements,
    passRate: Math.round(measurements.filter(m => m.pass).length / measurements.length * 100),
    analysis: uxAnalysis,
  };

  writeReport(report, options.cycle || 0);
  return report;
}

async function generateUXAnalysis(measurements) {
  const summary = measurements.map(m =>
    `- ${m.test}: ${m.pass ? 'PASS' : 'FAIL'} (${m.valueMs ? m.valueMs + 'ms' : ''} ${m.detail || ''})`
  ).join('\n');

  const prompt = `Tu es un expert UX qui évalue un jeu vidéo (M.E.R.L.I.N., jeu de cartes narratif celtique).

RÉSULTATS DES MESURES :
${summary}

Analyse l'expérience utilisateur et réponds en JSON :
{
  "ux_score": <1-10>,
  "responsiveness": <1-10>,
  "clarity": <1-10>,
  "frustration_level": <1-10 (1=zen, 10=rage-quit)>,
  "critical_issues": ["<issue>"],
  "improvements": ["<amélioration prioritaire>"],
  "verdict": "<une phrase résumant l'UX>"
}`;

  try {
    const res = await generate(prompt, { temperature: 0.4, maxTokens: 384 });
    const m = res.text.match(/\{[\s\S]*\}/);
    if (m) return JSON.parse(m[0].replace(/,\s*}/g, '}').replace(/,\s*]/g, ']'));
  } catch { /* fallback */ }
  return { ux_score: 5, verdict: 'Analysis unavailable' };
}

function writeReport(report, cycle) {
  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const filePath = path.join(CONFIG.outputDir, `ux_critic_c${cycle}_${Date.now()}.json`);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');
  fs.writeFileSync(path.join(CONFIG.statusDir, 'ux_critic_report.json'), JSON.stringify(report, null, 2), 'utf8');

  console.log(`\n[UX] Pass rate: ${report.passRate}% | Score: ${report.analysis?.ux_score || '?'}/10`);
  console.log(`[UX] Verdict: ${report.analysis?.verdict || '?'}`);
  console.log(`[UX] Report: ${filePath}`);
}

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;
const noLaunch = args.includes('--no-launch');

(async () => {
  if (!(await checkHealth())) { console.error('[UX] Ollama not running'); process.exit(1); }
  try { await runUXCritic({ cycle, noLaunch }); process.exit(0); }
  catch (e) { console.error(`[UX] Fatal: ${e.message}`); process.exit(1); }
})();
