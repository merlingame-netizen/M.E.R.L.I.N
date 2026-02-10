/**
 * M.E.R.L.I.N. — Raw LLM Test (Latence + Comprehension)
 * Test epure des modeles Trinity-Nano en dehors de Godot.
 *
 * Usage:
 *   node tools/test_llm_raw.mjs                   # Q5 par defaut, tous les tests
 *   node tools/test_llm_raw.mjs --model q4        # Test Q4_K_M
 *   node tools/test_llm_raw.mjs --model q8        # Test Q8_0
 *   node tools/test_llm_raw.mjs --model all       # Compare les 3 modeles
 *   node tools/test_llm_raw.mjs --test latency    # Seulement test latence
 *   node tools/test_llm_raw.mjs --test comprehension  # Seulement comprehension
 */

import { getLlama, LlamaChatSession } from "node-llama-cpp";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");
const MODELS_DIR = path.join(PROJECT_ROOT, "addons", "merlin_llm", "models");

const MODEL_FILES = {
  q4: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q4_K_M.gguf"),
  q5: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q5_K_M.gguf"),
  q8: path.join(MODELS_DIR, "Trinity-Nano-Preview-Q8_0.gguf"),
  // Modeles alternatifs pour comparaison
  phi3: "C:\\Users\\PGNK2128\\DRU\\addons\\merlin_llm\\models\\phi3-mini-q4.gguf",
  qwen3b: path.join(MODELS_DIR, "qwen2.5-3b-instruct-q4_k_m.gguf"),
};

// Parse CLI args
const args = process.argv.slice(2);
const getArg = (flag, def) => {
  const idx = args.indexOf(flag);
  return idx >= 0 && args[idx + 1] ? args[idx + 1] : def;
};
const modelArg = getArg("--model", "q5");
const testArg = getArg("--test", "all");
// Support --path for arbitrary GGUF file
const customPath = getArg("--path", "");
if (customPath) MODEL_FILES["custom"] = customPath;

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATION HELPER — Le plus epure possible
// ═══════════════════════════════════════════════════════════════════════════════

async function generate(model, system, user, params = {}) {
  const ctx = await model.createContext({ contextSize: 2048 });
  const session = new LlamaChatSession({
    contextSequence: ctx.getSequence(),
    systemPrompt: system,
  });

  const t0 = Date.now();
  let response = "";
  try {
    response = await session.prompt(user, {
      maxTokens: params.maxTokens ?? 80,
      temperature: params.temperature ?? 0.4,
      topP: params.topP ?? 0.8,
      topK: params.topK ?? 30,
      repeatPenalty: { penalty: params.repeatPenalty ?? 1.5 },
    });
  } catch (e) {
    response = `[ERROR: ${e.message}]`;
  }
  const ms = Date.now() - t0;

  session.dispose();
  await ctx.dispose();

  return { text: response.trim(), ms };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 1: LATENCE BRUTE — Configuration la plus epuree
// ═══════════════════════════════════════════════════════════════════════════════

const LATENCY_TESTS = [
  // Ultra-court: 1 mot
  {
    name: "1 mot (max 5 tokens)",
    system: "Reponds en 1 seul mot.",
    user: "Quelle saison est la plus froide?",
    params: { maxTokens: 5, temperature: 0.1 },
  },
  // Court: 1 phrase
  {
    name: "1 phrase (max 20 tokens)",
    system: "Reponds en une seule phrase courte.",
    user: "Decris la foret en automne.",
    params: { maxTokens: 20, temperature: 0.3 },
  },
  // Moyen: texte narratif
  {
    name: "Narratif court (max 40 tokens)",
    system: "Tu es un druide celte. Raconte un evenement.",
    user: "Un voyageur arrive a la clairiere sacree.",
    params: { maxTokens: 40, temperature: 0.4 },
  },
  // Production: carte TRIADE (max 60 tokens, comme CLAUDE.md)
  {
    name: "Carte JSON (max 60 tokens, prod config)",
    system: "Merlin druide. JSON carte. 3 options.",
    user: `Aspects: Corps=equilibre Ame=bas Monde=equilibre. Souffle:3. Jour:1.\n{"text":"description","speaker":"merlin","options":[{"label":"choix1","effects":[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up"}]},{"label":"choix2","cost":1,"effects":[]},{"label":"choix3","effects":[]}]}`,
    params: { maxTokens: 60, temperature: 0.4, topP: 0.75, topK: 25, repeatPenalty: 1.6 },
  },
  // Long: generation etendue
  {
    name: "Texte long (max 150 tokens)",
    system: "Tu es Merlin. Raconte une histoire celtique.",
    user: "Raconte la legende du Chaudron de Dagda.",
    params: { maxTokens: 150, temperature: 0.6 },
  },
];

async function testLatency(model, modelName) {
  console.log("\n" + "=".repeat(70));
  console.log(`  LATENCE BRUTE — ${modelName}`);
  console.log("=".repeat(70));

  const results = [];
  for (const test of LATENCY_TESTS) {
    // Warmup: 1 generation jetee
    await generate(model, test.system, test.user, test.params);

    // 3 runs chronometres
    const runs = [];
    for (let i = 0; i < 3; i++) {
      const { text, ms } = await generate(model, test.system, test.user, test.params);
      runs.push({ text, ms });
    }

    const avgMs = Math.round(runs.reduce((s, r) => s + r.ms, 0) / runs.length);
    const minMs = Math.min(...runs.map(r => r.ms));
    const maxMs = Math.max(...runs.map(r => r.ms));
    const avgTokens = Math.round(runs.reduce((s, r) => s + r.text.split(/\s+/).length, 0) / runs.length);
    const tokPerSec = avgTokens > 0 ? (avgTokens / (avgMs / 1000)).toFixed(1) : "?";

    console.log(`\n  ${test.name}`);
    console.log(`    Temps: ${avgMs}ms moy (${minMs}-${maxMs}ms)`);
    console.log(`    ~${avgTokens} mots, ~${tokPerSec} mots/sec`);
    console.log(`    Sortie: "${runs[0].text.substring(0, 100)}${runs[0].text.length > 100 ? "..." : ""}"`);

    results.push({
      test: test.name,
      avgMs, minMs, maxMs,
      avgWords: avgTokens,
      wordsPerSec: parseFloat(tokPerSec),
      sample: runs[0].text.substring(0, 120),
    });
  }

  return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST 2: COMPREHENSION — Le modele comprend-il les instructions?
// ═══════════════════════════════════════════════════════════════════════════════

const COMPREHENSION_TESTS = [
  // --- A. Suivi d'instructions simples ---
  {
    name: "Instruction: oui/non",
    system: "Reponds UNIQUEMENT par oui ou non.",
    user: "L'eau gele-t-elle a 0 degres?",
    validate: (text) => {
      const lower = text.toLowerCase().trim();
      return lower.includes("oui") && !lower.includes("non");
    },
    expected: "oui",
    category: "instruction",
  },
  {
    name: "Instruction: compter",
    system: "Reponds uniquement par un chiffre.",
    user: "Combien de pattes a un chat?",
    validate: (text) => text.includes("4") || text.includes("quatre"),
    expected: "4",
    category: "instruction",
  },
  {
    name: "Instruction: liste 3 elements",
    system: "Donne exactement 3 elements, separes par des virgules.",
    user: "Cite 3 arbres.",
    validate: (text) => {
      const parts = text.split(/[,;\n]+/).filter(p => p.trim().length > 1);
      return parts.length >= 3;
    },
    expected: "3 elements separes",
    category: "instruction",
  },
  {
    name: "Instruction: langue francaise",
    system: "Reponds en francais uniquement.",
    user: "What is the color of the sky?",
    validate: (text) => {
      const frWords = ["le", "la", "de", "un", "une", "du", "les", "des", "est", "ciel", "bleu", "couleur"];
      const words = text.toLowerCase().split(/\s+/);
      return words.some(w => frWords.includes(w));
    },
    expected: "reponse en francais",
    category: "instruction",
  },

  // --- B. Comprehension / logique ---
  {
    name: "Logique: contraire",
    system: "Reponds en un mot.",
    user: "Quel est le contraire de 'chaud'?",
    validate: (text) => text.toLowerCase().includes("froid"),
    expected: "froid",
    category: "logique",
  },
  {
    name: "Logique: categorisation",
    system: "Reponds en un mot: animal, plante ou mineral.",
    user: "Un chene est un(e)?",
    validate: (text) => {
      const lower = text.toLowerCase();
      return lower.includes("plante") || lower.includes("arbre") || lower.includes("vegetal");
    },
    expected: "plante/arbre",
    category: "logique",
  },
  {
    name: "Logique: sequence",
    system: "Complete la sequence avec le nombre suivant.",
    user: "2, 4, 6, 8, ?",
    validate: (text) => text.includes("10") || text.includes("dix"),
    expected: "10",
    category: "logique",
  },

  // --- C. Jeu de role (Merlin) ---
  {
    name: "Role: rester Merlin",
    system: "Tu es Merlin le druide. Reponds toujours en tant que Merlin.",
    user: "Qui es-tu?",
    validate: (text) => {
      const lower = text.toLowerCase();
      return lower.includes("merlin") || lower.includes("druide") || lower.includes("mage");
    },
    expected: "se presenter comme Merlin",
    category: "role",
  },
  {
    name: "Role: ton medieval",
    system: "Tu es un druide celte ancien. Parle avec un ton medieval.",
    user: "Que penses-tu de cette foret?",
    validate: (text) => {
      // Verifie que c'est au moins 5 mots et pas du charabia
      const words = text.split(/\s+/).filter(w => w.length > 1);
      return words.length >= 5 && text.length > 20;
    },
    expected: "reponse coherente > 5 mots",
    category: "role",
  },
  {
    name: "Role: generer des choix",
    system: "Propose 3 choix pour un jeu de cartes. Format: A) ... B) ... C) ...",
    user: "Un loup affame te barre la route.",
    validate: (text) => {
      const hasA = /[aA][).\]:]/.test(text) || text.includes("1)") || text.includes("1.");
      const hasMultiple = (text.match(/[A-Ca-c][).\]:]/g) || []).length >= 2 ||
                          (text.match(/[1-3][).]/g) || []).length >= 2;
      return hasMultiple || text.split("\n").filter(l => l.trim().length > 5).length >= 3;
    },
    expected: "3 choix distincts A/B/C",
    category: "role",
  },

  // --- D. JSON basique ---
  {
    name: "JSON: objet simple",
    system: "Reponds uniquement en JSON valide.",
    user: 'Genere: {"nom":"Merlin","age":500}',
    validate: (text) => {
      try {
        const start = text.indexOf("{");
        const end = text.lastIndexOf("}");
        if (start < 0 || end <= start) return false;
        const obj = JSON.parse(text.substring(start, end + 1));
        return obj.nom !== undefined || obj.name !== undefined;
      } catch { return false; }
    },
    expected: "JSON valide avec nom",
    category: "json",
  },
  {
    name: "JSON: tableau",
    system: "Reponds en JSON: un tableau de 3 strings.",
    user: 'Genere un tableau de 3 animaux celtiques en JSON.',
    validate: (text) => {
      try {
        const start = text.indexOf("[");
        const end = text.lastIndexOf("]");
        if (start < 0 || end <= start) return false;
        const arr = JSON.parse(text.substring(start, end + 1));
        return Array.isArray(arr) && arr.length >= 2;
      } catch { return false; }
    },
    expected: "JSON tableau >= 2 elements",
    category: "json",
  },
];

async function testComprehension(model, modelName) {
  console.log("\n" + "=".repeat(70));
  console.log(`  COMPREHENSION — ${modelName}`);
  console.log("=".repeat(70));

  const results = [];
  const scores = { instruction: [], logique: [], role: [], json: [] };

  for (const test of COMPREHENSION_TESTS) {
    const { text, ms } = await generate(model, test.system, test.user, {
      maxTokens: 80, temperature: 0.3, topP: 0.8,
    });

    const pass = test.validate(text);
    scores[test.category].push(pass);

    const icon = pass ? "\x1b[32mPASS\x1b[0m" : "\x1b[31mFAIL\x1b[0m";
    console.log(`\n  [${icon}] ${test.name} (${ms}ms)`);
    console.log(`    Attendu: ${test.expected}`);
    console.log(`    Recu: "${text.substring(0, 120)}${text.length > 120 ? "..." : ""}"`);

    results.push({
      test: test.name,
      category: test.category,
      pass,
      ms,
      expected: test.expected,
      received: text.substring(0, 150),
    });
  }

  // Score par categorie
  console.log("\n" + "-".repeat(50));
  console.log("  SCORES PAR CATEGORIE:");
  for (const [cat, vals] of Object.entries(scores)) {
    const passed = vals.filter(v => v).length;
    const total = vals.length;
    const pct = Math.round((passed / total) * 100);
    const bar = pct >= 70 ? "\x1b[32m" : pct >= 40 ? "\x1b[33m" : "\x1b[31m";
    console.log(`    ${cat.padEnd(15)} ${bar}${passed}/${total} (${pct}%)\x1b[0m`);
  }

  const totalPass = results.filter(r => r.pass).length;
  const totalPct = Math.round((totalPass / results.length) * 100);
  console.log(`\n  TOTAL: ${totalPass}/${results.length} (${totalPct}%)`);

  return { results, scores, totalPass, totalPct };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

async function runForModel(modelKey) {
  const modelPath = MODEL_FILES[modelKey];
  if (!modelPath || !fs.existsSync(modelPath)) {
    console.error(`Modele introuvable: ${modelPath}`);
    return null;
  }

  const sizeMB = (fs.statSync(modelPath).size / (1024 * 1024)).toFixed(0);
  console.log(`\n${"#".repeat(70)}`);
  console.log(`  MODELE: ${modelKey.toUpperCase()} (${sizeMB} MB)`);
  console.log(`${"#".repeat(70)}`);

  const t0 = Date.now();
  const llama = await getLlama();
  const model = await llama.loadModel({ modelPath });
  const loadMs = Date.now() - t0;
  console.log(`  Charge en ${loadMs}ms`);

  let latencyResults = null;
  let comprehensionResults = null;

  if (testArg === "all" || testArg === "latency") {
    latencyResults = await testLatency(model, modelKey.toUpperCase());
  }
  if (testArg === "all" || testArg === "comprehension") {
    comprehensionResults = await testComprehension(model, modelKey.toUpperCase());
  }

  await model.dispose();
  await llama.dispose();

  return { modelKey, sizeMB, loadMs, latencyResults, comprehensionResults };
}

async function main() {
  console.log("M.E.R.L.I.N. — Test LLM Raw (Latence + Comprehension)");
  console.log(`Date: ${new Date().toISOString()}`);
  console.log(`Test: ${testArg} | Modele(s): ${modelArg}`);

  const modelsToTest = modelArg === "all" ? ["q4", "q5", "q8"] : [modelArg];
  const allResults = [];

  for (const mk of modelsToTest) {
    const result = await runForModel(mk);
    if (result) allResults.push(result);
  }

  // Tableau comparatif final
  if (allResults.length > 1) {
    console.log("\n" + "=".repeat(70));
    console.log("  COMPARAISON FINALE");
    console.log("=".repeat(70));

    console.log("\n  Latence moyenne (ms):");
    console.log("  " + "Test".padEnd(35) + allResults.map(r => r.modelKey.toUpperCase().padStart(10)).join(""));
    if (allResults[0].latencyResults) {
      for (let i = 0; i < LATENCY_TESTS.length; i++) {
        const label = LATENCY_TESTS[i].name.substring(0, 33).padEnd(35);
        const vals = allResults.map(r => r.latencyResults?.[i]?.avgMs?.toString().padStart(10) ?? "N/A".padStart(10)).join("");
        console.log(`  ${label}${vals}`);
      }
    }

    if (allResults[0].comprehensionResults) {
      console.log("\n  Comprehension (%):");
      for (const r of allResults) {
        console.log(`    ${r.modelKey.toUpperCase()}: ${r.comprehensionResults.totalPct}% (${r.comprehensionResults.totalPass}/${r.comprehensionResults.results.length})`);
      }
    }
  }

  // Save results
  const outPath = path.join(__dirname, `raw_test_${modelArg}_${Date.now()}.json`);
  fs.writeFileSync(outPath, JSON.stringify(allResults, null, 2));
  console.log(`\nResultats sauvegardes: ${outPath}`);
}

main().catch(console.error);
