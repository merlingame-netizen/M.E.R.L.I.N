// AI Playtester — Ollama LLM Client
// Zero dependencies — uses Node.js 18+ native fetch

import { CONFIG } from './config.mjs';

/**
 * Check Ollama health
 * @returns {Promise<boolean>}
 */
export async function checkHealth() {
  try {
    const res = await fetch(`${CONFIG.ollamaUrl}/api/tags`, { signal: AbortSignal.timeout(5000) });
    return res.ok;
  } catch {
    return false;
  }
}

/**
 * Generate text from Ollama
 * @param {string} prompt
 * @param {object} options
 * @returns {Promise<{text: string, durationMs: number}>}
 */
export async function generate(prompt, options = {}) {
  const model = options.model || CONFIG.ollamaModel;
  const temperature = options.temperature ?? 0.7;
  const maxTokens = options.maxTokens ?? 256;

  const t0 = Date.now();
  const res = await fetch(`${CONFIG.ollamaUrl}/api/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      prompt,
      stream: false,
      options: {
        temperature,
        num_predict: maxTokens,
      },
    }),
    signal: AbortSignal.timeout(120_000),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Ollama ${res.status}: ${body.slice(0, 200)}`);
  }

  const data = await res.json();
  return {
    text: data.response || '',
    durationMs: Date.now() - t0,
  };
}
