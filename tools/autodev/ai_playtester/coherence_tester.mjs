#!/usr/bin/env node
// AI Playtester — Coherence Tester
// Plays a full run tracking narrative coherence: speaker consistency, theme drift,
// effect-text alignment, card sequencing logic, and story arc quality.
// Usage: node coherence_tester.mjs [--cycle 1] [--no-launch]

import fs from 'fs';
import path from 'path';
import * as bridge from './game_bridge.mjs';
import { generate, checkHealth } from './llm_client.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Coherence Tracking ──────────────────────────────────────────────

class CoherenceTracker {
  constructor() {
    this.cards = [];
    this.speakers = [];
    this.themes = [];
    this.effectMismatches = [];
    this.speakerTransitions = [];
    this.narrativeThread = [];
  }

  addCard(card, gameState) {
    const entry = {
      num: this.cards.length + 1,
      text: card.text || '',
      speaker: card.speaker || 'unknown',
      type: card.type || '',
      optionLabels: (card.options || []).map(o => o.label || ''),
      optionEffects: (card.options || []).map(o => o.effects || []),
      biome: gameState?.run?.biome || '?',
      life: gameState?.run?.life ?? '?',
      tension: gameState?.run?.tension ?? 0,
    };

    // Track speaker transitions
    if (this.cards.length > 0) {
      const prev = this.cards[this.cards.length - 1];
      if (prev.speaker !== entry.speaker) {
        this.speakerTransitions.push({
          from: prev.speaker,
          to: entry.speaker,
          atCard: entry.num,
        });
      }
    }

    this.speakers.push(entry.speaker);
    this.cards.push(entry);
    return entry;
  }

  /**
   * Build a summary for the LLM coherence analysis
   */
  buildSummary() {
    const speakerCounts = {};
    for (const s of this.speakers) {
      speakerCounts[s] = (speakerCounts[s] || 0) + 1;
    }

    const cardSummaries = this.cards.map(c => {
      const opts = c.optionLabels.map((l, i) => {
        const effects = c.optionEffects[i]?.join(', ') || 'aucun';
        return `  ${['A', 'B', 'C'][i]}: "${l}" (${effects})`;
      }).join('\n');
      return `Carte ${c.num} [${c.speaker}] (${c.biome}, vie=${c.life}, tension=${c.tension}):\n"${c.text.slice(0, 150)}"\n${opts}`;
    });

    return {
      totalCards: this.cards.length,
      speakerCounts,
      speakerTransitions: this.speakerTransitions.length,
      uniqueSpeakers: new Set(this.speakers).size,
      cardSummaries: cardSummaries.join('\n\n'),
    };
  }
}

// ── LLM Coherence Analysis ──────────────────────────────────────────

async function analyzeCoherence(tracker) {
  const summary = tracker.buildSummary();

  const prompt = `Tu es un directeur narratif qui analyse la cohérence d'une partie de M.E.R.L.I.N., un jeu de cartes narratif celtique.

STATISTIQUES DE LA PARTIE :
- ${summary.totalCards} cartes jouées
- ${summary.uniqueSpeakers} narrateurs uniques : ${JSON.stringify(summary.speakerCounts)}
- ${summary.speakerTransitions} changements de narrateur

CARTES (résumé) :
${summary.cardSummaries}

Analyse la cohérence narrative et réponds EXACTEMENT en JSON :
{
  "narrative_coherence": <1-10>,
  "narrative_detail": "<analyse en 2-3 phrases>",
  "speaker_consistency": <1-10>,
  "speaker_detail": "<les transitions de narrateur sont-elles logiques ?>",
  "theme_drift": <1-10>,
  "theme_detail": "<les cartes restent-elles dans le thème du biome ?>",
  "effect_text_alignment": <1-10>,
  "effect_detail": "<les effets correspondent-ils au texte des options ?>",
  "story_arc": <1-10>,
  "arc_detail": "<y a-t-il un début, un développement, une tension ?>",
  "repetition_score": <1-10>,
  "repetition_detail": "<les cartes sont-elles variées ou répétitives ?>",
  "worst_card": <numéro de la pire carte>,
  "worst_card_reason": "<pourquoi>",
  "best_card": <numéro de la meilleure carte>,
  "best_card_reason": "<pourquoi>",
  "overall_coherence": <1-10>,
  "recommendations": ["<amélioration 1>", "<amélioration 2>"]
}`;

  try {
    const response = await generate(prompt, { temperature: 0.4, maxTokens: 768 });
    const jsonMatch = response.text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[0].replace(/,\s*}/g, '}').replace(/,\s*]/g, ']'));
      } catch { /* fallback */ }
    }
    return { overall_coherence: 5, recommendations: ['Parse error'], raw: response.text.slice(0, 300) };
  } catch (e) {
    return { overall_coherence: 0, recommendations: [`LLM error: ${e.message}`] };
  }
}

// ── Main Flow ───────────────────────────────────────────────────────

async function runCoherenceTest(options = {}) {
  const startTime = Date.now();
  const tracker = new CoherenceTracker();
  const maxCards = 15; // Enough for coherence analysis without 50-card run

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  Coherence Tester — M.E.R.L.I.N.     ║');
  console.log('╚══════════════════════════════════════╝\n');

  // Launch
  if (!options.noLaunch) {
    console.log('[Coherence] Launching game...');
    const ok = await bridge.launchGame();
    if (!ok) throw new Error('Game failed to launch');
    await sleep(5000);
  } else {
    if (!bridge.isGameRunning()) throw new Error('Game not running');
  }

  // Navigate to gameplay
  console.log('[Coherence] Navigating to gameplay...');
  await sleep(3000);

  // Menu → Hub → Gameplay (fast navigation)
  for (const keyword of ['nouvelle', 'new', 'commencer', 'start', 'partir']) {
    const btn = await bridge.findButton(keyword);
    if (btn) {
      await bridge.clickButton(btn);
      await sleep(3000);
    }
  }
  // Fallback: press Enter a few times
  for (let i = 0; i < 3; i++) {
    await bridge.sendCommand('simulate_key', { key: 'enter' });
    await sleep(2000);
  }

  await sleep(5000);

  // ── PLAY CARDS ──────────────────────────────────────────────────
  console.log(`[Coherence] Playing up to ${maxCards} cards...`);
  let cardsPlayed = 0;

  for (let i = 0; i < maxCards; i++) {
    const state = bridge.readState();
    if (state?.run?.life <= 0) {
      console.log('[Coherence] Player died');
      break;
    }

    const card = await bridge.waitForCard(90_000);
    if (!card) {
      console.log('[Coherence] No card, pressing Enter');
      await bridge.sendCommand('simulate_key', { key: 'enter' });
      await sleep(3000);
      continue;
    }

    const gameState = bridge.readState();
    const entry = tracker.addCard(card, gameState);
    console.log(`[Coherence] Card #${entry.num} [${entry.speaker}]: "${card.text?.slice(0, 60)}..."`);

    // Always pick option 0 for consistency (removes player strategy as variable)
    const clickResult = await bridge.clickOption(0);
    if (!clickResult || clickResult.status !== 'ok') {
      await sleep(2000);
      await bridge.clickOption(0); // retry
    }

    cardsPlayed++;
    await sleep(3000);
    await bridge.waitForCardCleared(15_000);
    await sleep(2000);
  }

  // ── ANALYZE ─────────────────────────────────────────────────────
  console.log(`\n[Coherence] Analyzing ${cardsPlayed} cards...`);
  const analysis = await analyzeCoherence(tracker);

  // ── COMPILE REPORT ──────────────────────────────────────────────
  const report = {
    agent: 'coherence_tester',
    cycle: options.cycle || 0,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    cardsPlayed,
    analysis,
    speakerTransitions: tracker.speakerTransitions,
    cards: tracker.cards.map(c => ({
      num: c.num,
      speaker: c.speaker,
      textPreview: c.text.slice(0, 100),
      biome: c.biome,
      life: c.life,
      tension: c.tension,
      options: c.optionLabels,
    })),
  };

  writeReport(report, options.cycle || 0);
  return report;
}

function writeReport(report, cycle) {
  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });

  const filename = `coherence_test_c${cycle}_${Date.now()}.json`;
  const filePath = path.join(CONFIG.outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');

  const latestPath = path.join(CONFIG.statusDir, 'coherence_test_report.json');
  fs.writeFileSync(latestPath, JSON.stringify(report, null, 2), 'utf8');

  const a = report.analysis;
  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║    COHERENCE TEST RESULTS             ║`);
  console.log(`╠══════════════════════════════════════╣`);
  console.log(`║  Overall: ${String(a.overall_coherence ?? '?').padEnd(2)}/10                       ║`);
  console.log(`║  Narrative: ${String(a.narrative_coherence ?? '?').padEnd(2)}/10 | Arc: ${String(a.story_arc ?? '?').padEnd(2)}/10   ║`);
  console.log(`║  Speakers: ${String(a.speaker_consistency ?? '?').padEnd(2)}/10 | Theme: ${String(a.theme_drift ?? '?').padEnd(2)}/10║`);
  console.log(`║  Effects: ${String(a.effect_text_alignment ?? '?').padEnd(2)}/10 | Variety: ${String(a.repetition_score ?? '?').padEnd(2)}/10║`);
  console.log(`╚══════════════════════════════════════╝`);
  console.log(`\n[Coherence] Report: ${filePath}`);

  if (a.recommendations?.length > 0) {
    console.log('\nRecommendations:');
    for (const r of a.recommendations) console.log(`  > ${r}`);
  }
}

// ── CLI ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;
const noLaunch = args.includes('--no-launch');

(async () => {
  const healthy = await checkHealth();
  if (!healthy) { console.error('[Coherence] Ollama not running'); process.exit(1); }

  try {
    await runCoherenceTest({ cycle, noLaunch });
    process.exit(0);
  } catch (e) {
    console.error(`[Coherence] Fatal: ${e.message}`);
    process.exit(1);
  }
})();
