// AI Playtester — Decision Engine
// Builds LLM prompts from card + game state + persona, parses decisions

import { generate } from './llm_client.mjs';

/**
 * Format effects array for display
 * @param {Array} effects
 * @returns {string}
 */
function formatEffects(effects) {
  if (!Array.isArray(effects) || effects.length === 0) return '(aucun)';
  return effects.map(e => {
    if (typeof e === 'string') return e;
    if (typeof e === 'object') return JSON.stringify(e);
    return String(e);
  }).join(', ');
}

/**
 * Format recent history for context
 * @param {Array} history — last N decision entries
 * @returns {string}
 */
function formatHistory(history) {
  if (!history || history.length === 0) return '(première carte)';
  return history.map((h, i) => {
    const optLabel = h.optionLabel || `Option ${h.choice}`;
    return `- Carte ${h.cardNum}: "${optLabel}" → ${h.emotion || '?'}`;
  }).join('\n');
}

/**
 * Build the decision prompt for a card
 * @param {object} card — { text, speaker, type, options: [{label, effects}] }
 * @param {object} gameState — { run: { life, cards_played, biome, factions, tension } }
 * @param {object} persona — from personas.mjs
 * @param {Array} history — recent decisions
 * @returns {string}
 */
function buildDecisionPrompt(card, gameState, persona, history) {
  const run = gameState.run || {};
  const options = card.options || [];

  const optionLines = options.map((opt, i) => {
    const letter = ['A', 'B', 'C'][i] || String(i);
    return `OPTION ${letter} : "${opt.label || '???'}" → Effets : ${formatEffects(opt.effects)}`;
  }).join('\n');

  return `Tu joues à M.E.R.L.I.N., un jeu de cartes narratif dans la mythologie celtique.

TON PERSONNAGE : ${persona.systemPrompt}

ÉTAT DU JEU :
- Vie : ${run.life ?? '?'}/100 | Cartes jouées : ${run.cards_played ?? 0}
- Biome : ${run.biome || '?'} | Tension : ${run.tension ?? 0}
- Factions : ${JSON.stringify(run.factions || {})}

CARTE ACTUELLE :
Narrateur : ${card.speaker || '?'}
"${card.text || '(pas de texte)'}"

${optionLines}

HISTORIQUE (${history.length} derniers choix) :
${formatHistory(history)}

Réponds EXACTEMENT dans ce format (3 lignes, rien d'autre) :
CHOIX: A ou B ou C
RAISON: une phrase courte
EMOTION: un seul mot`;
}

/**
 * Parse LLM response into a structured decision
 * @param {string} text — raw LLM output
 * @returns {{ option: number, reasoning: string, emotion: string }}
 */
function parseDecision(text, optionCount = 3) {
  const lines = text.trim().split('\n');

  // Parse CHOIX
  let option = -1;
  const choiceMap = { 'A': 0, 'B': 1, 'C': 2 };
  for (const line of lines) {
    const m = line.match(/CHOIX\s*:\s*([ABC])/i);
    if (m) {
      option = choiceMap[m[1].toUpperCase()] ?? -1;
      break;
    }
  }
  // Fallback: look for standalone A/B/C in first line
  if (option === -1) {
    const firstMatch = lines[0]?.match(/\b([ABC])\b/i);
    if (firstMatch) {
      option = choiceMap[firstMatch[1].toUpperCase()] ?? -1;
    }
  }
  // Last resort: random (bounded by actual option count)
  if (option === -1) {
    option = Math.floor(Math.random() * optionCount);
    console.warn(`[Decision] Failed to parse choice, random fallback: ${option}`);
  }

  // Parse RAISON
  let reasoning = '';
  for (const line of lines) {
    const m = line.match(/RAISON\s*:\s*(.+)/i);
    if (m) {
      reasoning = m[1].trim();
      break;
    }
  }

  // Parse EMOTION
  let emotion = '';
  for (const line of lines) {
    const m = line.match(/EMOTION\s*:\s*(\S+)/i);
    if (m) {
      emotion = m[1].trim();
      break;
    }
  }

  return { option, reasoning, emotion };
}

/**
 * Decide which option to pick for a card
 * @param {object} card — card data from GameObserver
 * @param {object} gameState — current state.json
 * @param {object} persona — persona definition
 * @param {Array} history — recent decisions
 * @returns {Promise<{chosenOption: number, reasoning: string, emotion: string, llmDurationMs: number, rawResponse: string}>}
 */
export async function decideCard(card, gameState, persona, history) {
  const prompt = buildDecisionPrompt(card, gameState, persona, history);

  try {
    const response = await generate(prompt, {
      temperature: persona.temperature,
      maxTokens: 128,
    });

    const optCount = card?.options?.length || 3;
    const decision = parseDecision(response.text, optCount);

    return {
      chosenOption: decision.option,
      reasoning: decision.reasoning,
      emotion: decision.emotion,
      llmDurationMs: response.durationMs,
      rawResponse: response.text,
    };
  } catch (e) {
    console.error(`[Decision] LLM error: ${e.message}`);
    // Fallback: random choice (bounded by actual options)
    const fallbackCount = card?.options?.length || 3;
    return {
      chosenOption: Math.floor(Math.random() * fallbackCount),
      reasoning: 'LLM error — random fallback',
      emotion: 'confused',
      llmDurationMs: 0,
      rawResponse: '',
    };
  }
}
