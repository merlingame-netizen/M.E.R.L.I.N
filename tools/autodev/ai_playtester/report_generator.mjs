// AI Playtester — Report Generator
// Compiles mechanical metrics + LLM-generated subjective experience report

import fs from 'fs';
import path from 'path';
import { generate } from './llm_client.mjs';
import { CONFIG } from './config.mjs';

/**
 * Compute mechanical metrics from decision log
 * @param {Array} decisions
 * @param {object} finalState
 * @param {number} startTime
 * @param {number} endTime
 * @returns {object}
 */
function computeMetrics(decisions, finalState, startTime, endTime) {
  const run = finalState?.run || {};
  const optionCounts = { A: 0, B: 0, C: 0 };
  let totalLlmMs = 0;
  let totalLifeDelta = 0;
  const speakers = new Set();
  const emotions = {};

  for (const d of decisions) {
    const letter = ['A', 'B', 'C'][d.chosenOption] || '?';
    optionCounts[letter] = (optionCounts[letter] || 0) + 1;
    totalLlmMs += d.llmDurationMs || 0;
    totalLifeDelta += d.lifeDelta || 0;
    if (d.card?.speaker) speakers.add(d.card.speaker);
    const emo = d.emotion || 'unknown';
    emotions[emo] = (emotions[emo] || 0) + 1;
  }

  const avgDecisionMs = decisions.length > 0
    ? Math.round(totalLlmMs / decisions.length)
    : 0;

  return {
    cardsPlayed: decisions.length,
    finalLife: run.life ?? 0,
    totalLifeLost: totalLifeDelta,
    optionDistribution: optionCounts,
    avgDecisionMs,
    uniqueSpeakers: speakers.size,
    emotionDistribution: emotions,
    runDurationMs: endTime - startTime,
    factions: run.factions || {},
  };
}

/**
 * Build summary of decisions for the report prompt
 * @param {Array} decisions
 * @returns {string}
 */
function buildDecisionSummary(decisions) {
  return decisions.map(d => {
    const letter = ['A', 'B', 'C'][d.chosenOption];
    return `Carte ${d.cardNum}: "${d.card?.text?.slice(0, 80) || '?'}..." → ${letter} "${d.optionLabel}" (${d.emotion}) | Vie: ${d.lifeBefore}→${d.lifeAfter}`;
  }).join('\n');
}

/**
 * Generate subjective experience report via LLM
 * @param {Array} decisions
 * @param {object} metrics
 * @param {object} persona
 * @returns {Promise<object>}
 */
async function generateSubjectiveReport(decisions, metrics, persona) {
  const summary = buildDecisionSummary(decisions);

  const prompt = `Tu es un testeur de jeu vidéo avec la personnalité suivante : ${persona.systemPrompt}

Tu viens de jouer une partie de M.E.R.L.I.N., un jeu de cartes narratif celtique.
Voici le résumé de ta partie :

STATISTIQUES :
- Cartes jouées : ${metrics.cardsPlayed}
- Vie finale : ${metrics.finalLife}/100 (total perdu : ${metrics.totalLifeLost})
- Répartition choix : A=${metrics.optionDistribution.A}, B=${metrics.optionDistribution.B}, C=${metrics.optionDistribution.C}
- Narrateurs uniques : ${metrics.uniqueSpeakers}
- Durée : ${Math.round(metrics.runDurationMs / 1000)}s

CHOIX DÉTAILLÉS :
${summary}

Donne ton avis de joueur en répondant EXACTEMENT dans ce format JSON :
{
  "fun_rating": <1-10>,
  "fun_reasoning": "<une phrase>",
  "pacing": "<too_slow|good|too_fast>",
  "pacing_detail": "<une phrase>",
  "narrative_coherence": <1-10>,
  "narrative_detail": "<une phrase>",
  "frustration_points": ["<point 1>", "<point 2>"],
  "highlight_moments": ["<moment 1>", "<moment 2>"],
  "balance_assessment": "<une phrase>",
  "ux_issues": ["<issue 1>"]
}`;

  try {
    const response = await generate(prompt, {
      temperature: 0.6,
      maxTokens: 512,
    });

    // Extract JSON from response
    const jsonMatch = response.text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[0]);
      } catch {
        // Try to fix common JSON issues
        const fixed = jsonMatch[0]
          .replace(/,\s*}/g, '}')
          .replace(/,\s*]/g, ']');
        try {
          return JSON.parse(fixed);
        } catch {
          console.warn('[Report] Failed to parse subjective JSON, using raw text');
        }
      }
    }

    return {
      fun_rating: 5,
      fun_reasoning: response.text.slice(0, 200),
      pacing: 'good',
      pacing_detail: 'Unable to parse structured response',
      narrative_coherence: 5,
      narrative_detail: '',
      frustration_points: [],
      highlight_moments: [],
      balance_assessment: '',
      ux_issues: ['Report generation parse error'],
    };
  } catch (e) {
    console.error(`[Report] LLM error: ${e.message}`);
    return {
      fun_rating: 0,
      fun_reasoning: `LLM error: ${e.message}`,
      pacing: 'good',
      pacing_detail: '',
      narrative_coherence: 0,
      narrative_detail: '',
      frustration_points: [],
      highlight_moments: [],
      balance_assessment: '',
      ux_issues: [],
    };
  }
}

/**
 * Generate full playtest report and write to disk
 * @param {Array} decisions
 * @param {object} finalState
 * @param {object} persona
 * @param {number} startTime
 * @param {number} endTime
 * @param {number} cycle — optional cycle number
 * @returns {Promise<{report: object, filePath: string}>}
 */
export async function generateReport(decisions, finalState, persona, startTime, endTime, cycle = 0) {
  console.log('\n[Report] Generating experience report...');

  const metrics = computeMetrics(decisions, finalState, startTime, endTime);
  const subjective = await generateSubjectiveReport(decisions, metrics, persona);

  const report = {
    persona: persona.id,
    personaName: persona.name,
    cycle,
    timestamp: new Date().toISOString(),
    metrics,
    subjective,
    decisions: decisions.map(d => ({
      cardNum: d.cardNum,
      speaker: d.card?.speaker || '',
      textPreview: d.card?.text?.slice(0, 100) || '',
      choice: ['A', 'B', 'C'][d.chosenOption],
      optionLabel: d.optionLabel,
      reasoning: d.reasoning,
      emotion: d.emotion,
      llmDurationMs: d.llmDurationMs,
      lifeBefore: d.lifeBefore,
      lifeAfter: d.lifeAfter,
    })),
  };

  // Write report
  if (!fs.existsSync(CONFIG.outputDir)) {
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  }

  const filename = `playtest_${persona.id}_c${cycle}_${Date.now()}.json`;
  const filePath = path.join(CONFIG.outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');
  console.log(`[Report] Written to: ${filePath}`);

  // Also copy as latest for studio integration
  const latestPath = path.join(CONFIG.statusDir, 'playtest_report.json');
  fs.writeFileSync(latestPath, JSON.stringify(report, null, 2), 'utf8');
  console.log(`[Report] Latest copy: ${latestPath}`);

  // Print summary
  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║  PLAYTEST REPORT — ${persona.name.padEnd(17)}║`);
  console.log(`╠══════════════════════════════════��═══╣`);
  console.log(`║  Cards: ${String(metrics.cardsPlayed).padEnd(4)} | Life: ${String(metrics.finalLife).padEnd(4)}     ║`);
  console.log(`║  Fun: ${String(subjective.fun_rating || '?').padEnd(2)}/10 | Narr: ${String(subjective.narrative_coherence || '?').padEnd(2)}/10   ║`);
  console.log(`║  Pacing: ${String(subjective.pacing || '?').padEnd(24)}║`);
  console.log(`╚═════════════════════════════════��════╝`);

  if (subjective.frustration_points?.length > 0) {
    console.log('\nFrustrations:');
    for (const f of subjective.frustration_points) console.log(`  - ${f}`);
  }
  if (subjective.highlight_moments?.length > 0) {
    console.log('\nHighlights:');
    for (const h of subjective.highlight_moments) console.log(`  + ${h}`);
  }
  if (subjective.ux_issues?.length > 0) {
    console.log('\nUX Issues:');
    for (const u of subjective.ux_issues) console.log(`  ! ${u}`);
  }

  return { report, filePath };
}
