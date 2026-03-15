/**
 * M.E.R.L.I.N. — Standalone LLM Benchmark
 * Tests Trinity-Nano outside Godot for prompt iteration and quality measurement.
 *
 * Usage:
 *   node tools/benchmark_llm.mjs                      # Default: Q4_K_M, all tests
 *   node tools/benchmark_llm.mjs --model q5            # Test Q5_K_M
 *   node tools/benchmark_llm.mjs --model q8            # Test Q8_0
 *   node tools/benchmark_llm.mjs --test cards          # Only card generation test
 *   node tools/benchmark_llm.mjs --test sweep          # Only parameter sweep
 *   node tools/benchmark_llm.mjs --test twostage       # Two-stage generation test (Phase 30)
 *   node tools/benchmark_llm.mjs --test compare        # Compare all 3 quantizations
 *   node tools/benchmark_llm.mjs --runs 10             # 10 runs per scenario (default: 3)
 */

import { getLlama, LlamaChatSession } from "node-llama-cpp";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");
const MODELS_DIR = path.join(PROJECT_ROOT, "addons", "merlin_llm", "models");

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL PATHS
// ═══════════════════════════════════════════════════════════════════════════════

const MODEL_FILES = {
  q4: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q4_K_M.gguf"),
  q5: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q5_K_M.gguf"),
  q8: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q8_0.gguf"),
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPTS — Exact same as merlin_llm_adapter.gd + merlin_omniscient.gd
// ═══════════════════════════════════════════════════════════════════════════════

// Prompt variants for A/B testing
const PROMPTS = {
  // V1: Current production prompt (from merlin_omniscient.gd)
  v1_production: {
    system: "Merlin druide narrateur. Genere 1 carte JSON francais. 3 options avec tradeoffs. Reponds UNIQUEMENT en JSON valide.",
    userSuffix: `\nEffets: SHIFT_ASPECT aspect=Corps/Ame/Monde direction=up/down. Centre cost:1.\n{"text":"...","speaker":"merlin","options":[{"label":"...","effects":[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up"}]},{"label":"...","cost":1,"effects":[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up"}]},{"label":"...","effects":[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"down"}]}],"tags":["tag"]}`,
  },
  // V2: Concrete example (model should NOT copy "..." literally)
  v2_example: {
    system: "Tu es Merlin le druide. Genere une carte narrative au format JSON strict avec exactement 3 options.",
    userSuffix: `\nFormat attendu (exemple):\n{"text":"Le vent se leve sur la lande","speaker":"merlin","options":[{"label":"Affronter la tempete","effects":[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up"}]},{"label":"Mediter en silence","cost":1,"effects":[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up"}]},{"label":"Fuir vers la foret","effects":[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"down"}]}],"tags":["nature"]}`,
  },
  // V3: Ultra-short prompt (CLAUDE.md rules: max 10 tokens system)
  v3_minimal: {
    system: "Merlin. JSON carte. 3 options.",
    userSuffix: `\n{"text":"description scene","speaker":"merlin","options":[{"label":"choix1","effects":[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up"}]},{"label":"choix2","cost":1,"effects":[]},{"label":"choix3","effects":[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"down"}]}]}`,
  },
  // V4: Two-stage prompt — free text only, no JSON (Phase 30)
  v4_two_stage: {
    system: "Merlin le druide. Ecris un scenario court (2 phrases) pour un jeu de cartes celtique. Propose 3 choix.",
    userSuffix: " Format: scenario puis 3 choix (A/B/C).",
  },
};

// Default to production prompt
let CURRENT_PROMPT_KEY = "v1_production";
const getSystemPrompt = () => PROMPTS[CURRENT_PROMPT_KEY].system;
const getUserSuffix = () => PROMPTS[CURRENT_PROMPT_KEY].userSuffix;

const SCENARIOS = [
  {
    name: "Equilibre",
    aspects: { Corps: 0, Ame: 0, Monde: 0 },
    souffle: 3, day: 1, cards_played: 0,
    tags: [],
  },
  {
    name: "Crise Corps (bas)",
    aspects: { Corps: -1, Ame: 0, Monde: 0 },
    souffle: 2, day: 5, cards_played: 12,
    tags: ["danger"],
  },
  {
    name: "Double crise (Corps+Ame)",
    aspects: { Corps: -1, Ame: -1, Monde: 0 },
    souffle: 1, day: 8, cards_played: 20,
    tags: ["crisis", "combat"],
  },
  {
    name: "Fin de jeu (Monde haut)",
    aspects: { Corps: 0, Ame: 1, Monde: 1 },
    souffle: 5, day: 15, cards_played: 40,
    tags: ["endgame", "tyran"],
  },
  {
    name: "Sans souffle",
    aspects: { Corps: 0, Ame: 0, Monde: -1 },
    souffle: 0, day: 3, cards_played: 8,
    tags: ["nature"],
  },
];

const PARAM_SWEEP = [
  { label: "Low temp", max_tokens: 200, temperature: 0.3, top_p: 0.8, top_k: 25, repetition_penalty: 1.6 },
  { label: "Default", max_tokens: 200, temperature: 0.6, top_p: 0.85, top_k: 30, repetition_penalty: 1.5 },
  { label: "High temp", max_tokens: 200, temperature: 0.9, top_p: 0.95, top_k: 50, repetition_penalty: 1.3 },
  { label: "Short output", max_tokens: 150, temperature: 0.6, top_p: 0.85, top_k: 30, repetition_penalty: 1.5 },
  { label: "Tight (CLAUDE.md)", max_tokens: 60, temperature: 0.4, top_p: 0.75, top_k: 25, repetition_penalty: 1.6 },
];

// ═══════════════════════════════════════════════════════════════════════════════
// PROMPT BUILDER — Mirrors merlin_llm_adapter.gd _build_triade_user_prompt()
// ═══════════════════════════════════════════════════════════════════════════════

function buildUserPrompt(scenario) {
  const stateNames = { "-1": "bas", "0": "equilibre", "1": "haut" };
  let prompt = "Aspects:";
  for (const aspect of ["Corps", "Ame", "Monde"]) {
    const val = scenario.aspects[aspect] ?? 0;
    prompt += ` ${aspect}=${stateNames[String(val)] ?? "equilibre"}`;
  }
  prompt += `. Souffle:${scenario.souffle}. Jour:${scenario.day}. Carte:${scenario.cards_played}.`;

  if (scenario.tags.length > 0) {
    prompt += ` Tags:${scenario.tags.slice(0, 3).join(",")}`;
  }

  // Append prompt-variant-specific suffix
  prompt += getUserSuffix();

  return prompt;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON EXTRACTION — Same 4-stage pipeline as merlin_llm_adapter.gd
// ═══════════════════════════════════════════════════════════════════════════════

function extractJson(raw) {
  // Pre-process: strip markdown code blocks
  let cleaned = raw;
  const codeBlockMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) {
    cleaned = codeBlockMatch[1].trim();
  }

  // Strategy 1: Standard parse
  const jsonStart = cleaned.indexOf("{");
  const jsonEnd = cleaned.lastIndexOf("}");
  if (jsonStart >= 0 && jsonEnd > jsonStart) {
    try {
      return { parsed: JSON.parse(cleaned.substring(jsonStart, jsonEnd + 1)), strategy: 1 };
    } catch {}
  }

  // Strategy 2: Fix common errors
  if (jsonStart >= 0 && jsonEnd > jsonStart) {
    let fixed = cleaned.substring(jsonStart, jsonEnd + 1);
    fixed = fixed.replace(/,\s*([}\]])/g, "$1"); // trailing commas
    fixed = fixed.replace(/'/g, '"'); // single quotes
    try {
      return { parsed: JSON.parse(fixed), strategy: 2 };
    } catch {}
  }

  // Strategy 3: Aggressive repair
  if (jsonStart >= 0) {
    let text = cleaned.substring(jsonStart);
    text = text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, ""); // control chars
    text = text.replace(/,\s*([}\]])/g, "$1");
    text = text.replace(/'/g, '"');

    // Count brackets
    let opens = 0, closes = 0;
    for (const c of text) {
      if (c === "{" || c === "[") opens++;
      if (c === "}" || c === "]") closes++;
    }
    while (closes < opens) {
      text += "}";
      closes++;
    }
    try {
      return { parsed: JSON.parse(text), strategy: 3 };
    } catch {}
  }

  // Strategy 4: Regex extraction
  const textMatch = cleaned.match(/"text"\s*:\s*"([^"]+)"/);
  if (textMatch) {
    const labels = [...cleaned.matchAll(/"label"\s*:\s*"([^"]+)"/g)].map(m => m[1]);
    const card = {
      text: textMatch[1],
      speaker: "merlin",
      options: labels.slice(0, 3).map((l, i) => ({
        label: l,
        effects: [{ type: "SHIFT_ASPECT", aspect: ["Corps", "Ame", "Monde"][i % 3], direction: i % 2 === 0 ? "up" : "down" }],
        ...(i === 1 ? { cost: 1 } : {}),
      })),
      tags: ["recovered"],
    };
    if (labels.length >= 2) {
      return { parsed: card, strategy: 4 };
    }
  }

  return { parsed: null, strategy: 0 };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEMA VALIDATION — Mirrors validate_faction_card()
// ═══════════════════════════════════════════════════════════════════════════════

function validateTriadeCard(card) {
  const errors = [];
  if (!card.text || typeof card.text !== "string" || card.text.length < 5)
    errors.push("text missing or too short");
  if (!Array.isArray(card.options))
    errors.push("options not array");
  else {
    if (card.options.length < 2) errors.push("need >= 2 options");
    if (card.options.length > 3) errors.push("too many options (>3)");
    for (let i = 0; i < card.options.length; i++) {
      const opt = card.options[i];
      if (!opt.label) errors.push(`option[${i}] missing label`);
      if (!Array.isArray(opt.effects)) errors.push(`option[${i}] effects not array`);
    }
  }

  // French check (>=2 FR keywords)
  const frKeywords = ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et", "au", "se", "sa", "son", "ce"];
  const words = (card.text || "").toLowerCase().split(/\s+/);
  const frCount = words.filter(w => frKeywords.includes(w)).length;
  if (frCount < 2) errors.push("not enough French words");

  return { ok: errors.length === 0, errors };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL LOADING
// ═══════════════════════════════════════════════════════════════════════════════

async function loadModel(modelKey) {
  const modelPath = MODEL_FILES[modelKey];
  if (!modelPath || !fs.existsSync(modelPath)) {
    console.error(`Model not found: ${modelPath}`);
    process.exit(1);
  }

  const fileSizeMB = (fs.statSync(modelPath).size / (1024 * 1024)).toFixed(1);
  console.log(`\nLoading ${modelKey.toUpperCase()} (${fileSizeMB} MB)...`);

  const t0 = Date.now();
  const llama = await getLlama();
  const model = await llama.loadModel({ modelPath });
  const loadMs = Date.now() - t0;

  console.log(`Model loaded in ${loadMs}ms`);

  return { llama, model, loadMs };
}

async function generateRaw(model, systemPrompt, userPrompt, params = {}) {
  // Chat session with model's native template (auto-detected from GGUF metadata)
  const ctx = await model.createContext({ contextSize: 2048 });
  const session = new LlamaChatSession({
    contextSequence: ctx.getSequence(),
    systemPrompt: systemPrompt,
  });

  const t0 = Date.now();
  let response = "";
  try {
    response = await session.prompt(userPrompt, {
      maxTokens: params.max_tokens ?? 200,
      temperature: params.temperature ?? 0.6,
      topP: params.top_p ?? 0.85,
      topK: params.top_k ?? 30,
      repeatPenalty: {
        penalty: params.repetition_penalty ?? 1.5,
      },
    });
  } catch (e) {
    response = `[ERROR: ${e.message}]`;
  }
  const elapsedMs = Date.now() - t0;

  // Clean up
  session.dispose();
  await ctx.dispose();

  return { text: response, elapsedMs };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 1: TRIADE Card Generation (5 scenarios x N runs)
// ═══════════════════════════════════════════════════════════════════════════════

async function testCards(model, runs) {
  console.log("\n" + "=".repeat(70));
  console.log("  TRIADE CARD GENERATION BENCHMARK");
  console.log("=".repeat(70));

  const results = [];

  for (const scenario of SCENARIOS) {
    console.log(`\n--- ${scenario.name} ---`);
    const userPrompt = buildUserPrompt(scenario);
    console.log(`  Prompt: ${userPrompt.substring(0, 80)}...`);

    const scenarioResults = [];
    for (let r = 0; r < runs; r++) {
      const { text, elapsedMs } = await generateRaw(model, getSystemPrompt(), userPrompt);
      const { parsed, strategy } = extractJson(text);
      const validation = parsed ? validateTriadeCard(parsed) : { ok: false, errors: ["no JSON"] };

      const result = {
        scenario: scenario.name,
        run: r + 1,
        elapsedMs,
        rawLength: text.length,
        jsonValid: parsed !== null,
        strategy,
        schemaValid: validation.ok,
        errors: validation.errors,
        optionCount: parsed?.options?.length ?? 0,
        textPreview: (parsed?.text || text).substring(0, 80),
        raw: text,
      };
      scenarioResults.push(result);

      const status = validation.ok ? "\x1b[32mOK\x1b[0m" : parsed ? "\x1b[33mJSON ok, schema fail\x1b[0m" : "\x1b[31mFAIL\x1b[0m";
      console.log(`  [${r + 1}/${runs}] ${status} ${elapsedMs}ms | strategy:${strategy} | opts:${result.optionCount} | ${result.textPreview.substring(0, 50)}`);
      if (!validation.ok && validation.errors.length > 0) {
        console.log(`         Errors: ${validation.errors.join(", ")}`);
      }
    }
    results.push(...scenarioResults);
  }

  // Summary
  const totalRuns = results.length;
  const jsonOk = results.filter(r => r.jsonValid).length;
  const schemaOk = results.filter(r => r.schemaValid).length;
  const threeOpts = results.filter(r => r.optionCount === 3).length;
  const avgMs = Math.round(results.reduce((s, r) => s + r.elapsedMs, 0) / totalRuns);
  const strategies = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0 };
  results.forEach(r => strategies[r.strategy]++);

  console.log("\n" + "=".repeat(70));
  console.log("  RESULTATS CARTES");
  console.log("=".repeat(70));
  console.log(`  Total:         ${totalRuns} generations`);
  console.log(`  JSON valide:   ${jsonOk}/${totalRuns} (${(jsonOk / totalRuns * 100).toFixed(0)}%)`);
  console.log(`  Schema valide: ${schemaOk}/${totalRuns} (${(schemaOk / totalRuns * 100).toFixed(0)}%)`);
  console.log(`  3 options:     ${threeOpts}/${totalRuns} (${(threeOpts / totalRuns * 100).toFixed(0)}%)`);
  console.log(`  Latence moy:   ${avgMs}ms`);
  console.log(`  Strategies:    parse:${strategies[1]} fix:${strategies[2]} repair:${strategies[3]} regex:${strategies[4]} fail:${strategies[0]}`);

  return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 2: Parameter Sweep
// ═══════════════════════════════════════════════════════════════════════════════

async function testParamSweep(model) {
  console.log("\n" + "=".repeat(70));
  console.log("  PARAMETER SWEEP");
  console.log("=".repeat(70));

  const baseScenario = SCENARIOS[0]; // Equilibre
  const userPrompt = buildUserPrompt(baseScenario);
  const results = [];

  for (const params of PARAM_SWEEP) {
    console.log(`\n--- ${params.label} ---`);
    console.log(`  temp=${params.temperature} top_p=${params.top_p} top_k=${params.top_k} max_tokens=${params.max_tokens} rep=${params.repetition_penalty}`);

    const sweepParams = { ...params };
    delete sweepParams.label;

    const { text, elapsedMs } = await generateRaw(model, getSystemPrompt(), userPrompt, sweepParams);
    const { parsed, strategy } = extractJson(text);
    const validation = parsed ? validateTriadeCard(parsed) : { ok: false, errors: ["no JSON"] };

    const status = validation.ok ? "\x1b[32mVALIDE\x1b[0m" : parsed ? "\x1b[33mJSON ok\x1b[0m" : "\x1b[31mFAIL\x1b[0m";
    console.log(`  ${status} | ${elapsedMs}ms | ${text.length} chars | strategy:${strategy}`);
    console.log(`  Preview: ${(parsed?.text || text).substring(0, 80)}`);
    if (!validation.ok) console.log(`  Errors: ${validation.errors.join(", ")}`);

    results.push({
      config: params.label,
      elapsedMs,
      jsonValid: parsed !== null,
      schemaValid: validation.ok,
      strategy,
      optionCount: parsed?.options?.length ?? 0,
      raw: text,
    });
  }

  return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 3: Multi-Model Comparison
// ═══════════════════════════════════════════════════════════════════════════════

async function testCompare(runs) {
  console.log("\n" + "=".repeat(70));
  console.log("  MULTI-MODEL COMPARISON (Q4 vs Q5 vs Q8)");
  console.log("=".repeat(70));

  const modelsToTest = [];
  for (const [key, filePath] of Object.entries(MODEL_FILES)) {
    if (fs.existsSync(filePath)) modelsToTest.push(key);
  }

  if (modelsToTest.length < 2) {
    console.log("Need at least 2 models for comparison. Found:", modelsToTest);
    return [];
  }

  const allResults = {};

  for (const modelKey of modelsToTest) {
    console.log(`\n${"─".repeat(50)}`);
    console.log(`  Testing ${modelKey.toUpperCase()}`);
    console.log(`${"─".repeat(50)}`);

    const { model, loadMs } = await loadModel(modelKey);
    const modelResults = { loadMs, tests: [] };

    // Test 3 scenarios x N runs each
    const scenarios = SCENARIOS.slice(0, 3);
    for (const scenario of scenarios) {
      const userPrompt = buildUserPrompt(scenario);
      for (let r = 0; r < runs; r++) {
        const { text, elapsedMs } = await generateRaw(model, getSystemPrompt(), userPrompt);
        const { parsed, strategy } = extractJson(text);
        const validation = parsed ? validateTriadeCard(parsed) : { ok: false, errors: [] };

        modelResults.tests.push({
          scenario: scenario.name,
          elapsedMs,
          jsonValid: parsed !== null,
          schemaValid: validation.ok,
          strategy,
          optionCount: parsed?.options?.length ?? 0,
        });

        const status = validation.ok ? "\x1b[32mOK\x1b[0m" : parsed ? "\x1b[33mPARTIAL\x1b[0m" : "\x1b[31mFAIL\x1b[0m";
        console.log(`  ${scenario.name} [${r + 1}] ${status} ${elapsedMs}ms`);
      }
    }

    allResults[modelKey] = modelResults;

    // Unload model
    await model.dispose?.();
  }

  // Comparison table
  console.log("\n" + "=".repeat(70));
  console.log("  COMPARISON TABLE");
  console.log("=".repeat(70));
  console.log(`  ${"Model".padEnd(8)} | ${"Load".padEnd(8)} | ${"Avg ms".padEnd(8)} | ${"JSON %".padEnd(8)} | ${"Schema %".padEnd(10)} | 3 opts %`);
  console.log("  " + "-".repeat(65));

  for (const [key, data] of Object.entries(allResults)) {
    const tests = data.tests;
    const n = tests.length;
    const avgMs = Math.round(tests.reduce((s, t) => s + t.elapsedMs, 0) / n);
    const jsonPct = Math.round(tests.filter(t => t.jsonValid).length / n * 100);
    const schemaPct = Math.round(tests.filter(t => t.schemaValid).length / n * 100);
    const optsPct = Math.round(tests.filter(t => t.optionCount === 3).length / n * 100);

    console.log(`  ${key.toUpperCase().padEnd(8)} | ${(data.loadMs + "ms").padEnd(8)} | ${(avgMs + "ms").padEnd(8)} | ${(jsonPct + "%").padEnd(8)} | ${(schemaPct + "%").padEnd(10)} | ${optsPct}%`);
  }

  return allResults;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 4: Two-Stage Generation (Phase 30)
// ═══════════════════════════════════════════════════════════════════════════════

function extractLabelsFromText(text) {
  const labels = [];
  const rx = /^\s*(?:[A-C]\)|[1-3][.)]\s*|[-*]\s+)(.+)/gm;
  let m;
  while ((m = rx.exec(text)) !== null) {
    const label = m[1].trim();
    if (label.length > 2 && label.length < 80) labels.push(label);
  }
  return labels;
}

function wrapTextAsCard(rawText, scenario) {
  let text = rawText.trim();
  const labels = extractLabelsFromText(text);

  // Remove extracted choices from main text
  if (labels.length >= 2) {
    const rx = /^\s*(?:[A-C]\)|[1-3][.)]\s*|[-*]\s+)/m;
    const idx = text.search(rx);
    if (idx > 0) text = text.substring(0, idx).trim();
  }

  const finalLabels = labels.length >= 3 ? labels.slice(0, 3) : ["Agir avec prudence", "Mediter en silence", "Foncer tete baissee"];
  const aspects = ["Corps", "Ame", "Monde"];

  // Smart effects based on aspect states
  const lowestAspect = aspects.reduce((a, b) => (scenario.aspects[a] ?? 0) <= (scenario.aspects[b] ?? 0) ? a : b);
  const highestAspect = aspects.reduce((a, b) => (scenario.aspects[a] ?? 0) >= (scenario.aspects[b] ?? 0) ? a : b);
  const centerAspect = aspects.find(a => a !== lowestAspect && a !== highestAspect) || "Ame";

  return {
    text: text.length > 5 ? text : rawText.substring(0, 200),
    speaker: "merlin",
    options: [
      { label: finalLabels[0], effects: [{ type: "SHIFT_ASPECT", aspect: lowestAspect, direction: "up" }] },
      { label: finalLabels[1], cost: 1, effects: [{ type: "SHIFT_ASPECT", aspect: centerAspect, direction: "up" }] },
      { label: finalLabels[2], effects: [{ type: "SHIFT_ASPECT", aspect: highestAspect, direction: "down" }] },
    ],
    tags: ["two_stage", "llm_generated"],
  };
}

async function testTwoStage(model, runs) {
  console.log("\n" + "=".repeat(70));
  console.log("  TWO-STAGE GENERATION BENCHMARK (Phase 30)");
  console.log("=".repeat(70));

  const savedPrompt = CURRENT_PROMPT_KEY;
  CURRENT_PROMPT_KEY = "v4_two_stage";

  const results = [];

  for (const scenario of SCENARIOS) {
    console.log(`\n--- ${scenario.name} ---`);
    const userPrompt = buildUserPrompt(scenario);
    console.log(`  Prompt: ${userPrompt.substring(0, 80)}...`);

    for (let r = 0; r < runs; r++) {
      const { text, elapsedMs } = await generateRaw(model, getSystemPrompt(), userPrompt, {
        max_tokens: 150,
        temperature: 0.7,
        top_p: 0.85,
        top_k: 30,
        repetition_penalty: 1.5,
      });

      // Stage 2: wrap into card
      const card = wrapTextAsCard(text, scenario);
      const validation = validateTriadeCard(card);
      const labels = extractLabelsFromText(text);

      const result = {
        scenario: scenario.name,
        run: r + 1,
        elapsedMs,
        rawLength: text.length,
        labelsExtracted: labels.length,
        usedExtractedLabels: labels.length >= 3,
        schemaValid: validation.ok,
        errors: validation.errors,
        textPreview: card.text.substring(0, 80),
        raw: text,
      };
      results.push(result);

      const labelStatus = labels.length >= 3 ? "\x1b[32mLLM labels\x1b[0m" : "\x1b[33mdefault labels\x1b[0m";
      const status = validation.ok ? "\x1b[32mOK\x1b[0m" : "\x1b[31mFAIL\x1b[0m";
      console.log(`  [${r + 1}/${runs}] ${status} ${elapsedMs}ms | ${labelStatus} (${labels.length} found) | ${result.textPreview.substring(0, 50)}`);
      if (!validation.ok) console.log(`         Errors: ${validation.errors.join(", ")}`);
    }
  }

  // Summary
  const totalRuns = results.length;
  const schemaOk = results.filter(r => r.schemaValid).length;
  const labelsOk = results.filter(r => r.usedExtractedLabels).length;
  const avgMs = Math.round(results.reduce((s, r) => s + r.elapsedMs, 0) / totalRuns);

  console.log("\n" + "=".repeat(70));
  console.log("  RESULTATS TWO-STAGE");
  console.log("=".repeat(70));
  console.log(`  Total:           ${totalRuns} generations`);
  console.log(`  Schema valide:   ${schemaOk}/${totalRuns} (${(schemaOk / totalRuns * 100).toFixed(0)}%)`);
  console.log(`  Labels from LLM: ${labelsOk}/${totalRuns} (${(labelsOk / totalRuns * 100).toFixed(0)}%)`);
  console.log(`  Latence moy:     ${avgMs}ms`);
  console.log(`  NOTE: Two-stage cards always have valid JSON (effects are programmatic)`);

  CURRENT_PROMPT_KEY = savedPrompt;
  return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

async function main() {
  const args = process.argv.slice(2);
  const modelKey = args.includes("--model") ? args[args.indexOf("--model") + 1] : "q4";
  const testName = args.includes("--test") ? args[args.indexOf("--test") + 1] : "all";
  const runs = args.includes("--runs") ? parseInt(args[args.indexOf("--runs") + 1]) : 3;
  const promptKey = args.includes("--prompt") ? args[args.indexOf("--prompt") + 1] : "v2_example";
  CURRENT_PROMPT_KEY = promptKey;

  if (!PROMPTS[CURRENT_PROMPT_KEY]) {
    console.error(`Unknown prompt variant: ${promptKey}. Available: ${Object.keys(PROMPTS).join(", ")}`);
    process.exit(1);
  }

  console.log("╔══════════════════════════════════════════════════════════════════╗");
  console.log("║     M.E.R.L.I.N. — Standalone LLM Benchmark                   ║");
  console.log("╚══════════════════════════════════════════════════════════════════╝");
  console.log(`  Model: ${modelKey.toUpperCase()} | Test: ${testName} | Runs: ${runs} | Prompt: ${CURRENT_PROMPT_KEY}`);

  const allResults = { timestamp: new Date().toISOString(), model: modelKey, runs };

  if (testName === "compare") {
    allResults.compare = await testCompare(runs);
  } else {
    const { model, loadMs } = await loadModel(modelKey);
    allResults.loadMs = loadMs;

    if (testName === "all" || testName === "cards") {
      allResults.cards = await testCards(model, runs);
    }
    if (testName === "all" || testName === "sweep") {
      allResults.sweep = await testParamSweep(model);
    }
    if (testName === "all" || testName === "twostage") {
      allResults.twoStage = await testTwoStage(model, runs);
    }
  }

  // Save results
  const outPath = path.join(PROJECT_ROOT, "tools", `benchmark_results_${modelKey}_${Date.now()}.json`);
  fs.writeFileSync(outPath, JSON.stringify(allResults, null, 2));
  console.log(`\nResults saved to: ${outPath}`);

  console.log("\nDone.");
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
