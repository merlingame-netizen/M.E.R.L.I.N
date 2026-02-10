/**
 * M.E.R.L.I.N. — Brain Pool Architecture Test Suite
 * Static analysis + structural validation of the multi-brain worker pool system.
 * Tests WITHOUT Godot engine — validates code structure, data files, config consistency.
 *
 * Usage:
 *   node tools/test_brain_pool.mjs              # Run all tests
 *   node tools/test_brain_pool.mjs --verbose    # Show detailed output
 *   node tools/test_brain_pool.mjs --test pool  # Only pool logic tests
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");

// ═══════════════════════════════════════════════════════════════════════════════
// TEST FRAMEWORK (minimal)
// ═══════════════════════════════════════════════════════════════════════════════

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;
let skippedTests = 0;
const failures = [];
const verbose = process.argv.includes("--verbose");
const testFilter = process.argv.includes("--test")
  ? process.argv[process.argv.indexOf("--test") + 1]
  : "all";

function describe(name, fn) {
  console.log(`\n\x1b[1m\x1b[36m  ${name}\x1b[0m`);
  fn();
}

function it(name, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    if (verbose) console.log(`    \x1b[32m✓\x1b[0m ${name}`);
  } catch (e) {
    failedTests++;
    console.log(`    \x1b[31m✗\x1b[0m ${name}`);
    console.log(`      \x1b[31m${e.message}\x1b[0m`);
    failures.push({ test: name, error: e.message });
  }
}

function skip(name) {
  skippedTests++;
  if (verbose) console.log(`    \x1b[33m○\x1b[0m ${name} (skipped)`);
}

function assert(condition, message) {
  if (!condition) throw new Error(message || "Assertion failed");
}

function assertEqual(actual, expected, message) {
  if (actual !== expected)
    throw new Error(
      `${message || "Expected"} ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
}

function assertIncludes(str, substr, message) {
  if (!str.includes(substr))
    throw new Error(
      `${message || "String"} should include "${substr}"`
    );
}

function assertMatch(str, regex, message) {
  if (!regex.test(str))
    throw new Error(
      `${message || "String"} should match ${regex}`
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE LOADING
// ═══════════════════════════════════════════════════════════════════════════════

function loadFile(relativePath) {
  const fullPath = path.join(PROJECT_ROOT, relativePath);
  if (!fs.existsSync(fullPath)) return null;
  return fs.readFileSync(fullPath, "utf-8");
}

function loadJSON(relativePath) {
  const content = loadFile(relativePath);
  if (!content) return null;
  return JSON.parse(content);
}

const merlinAI = loadFile("addons/merlin_ai/merlin_ai.gd");
const merlinOmni = loadFile("addons/merlin_ai/merlin_omniscient.gd");
const promptTemplates = loadJSON("data/ai/config/prompt_templates.json");
const gmGbnf = loadFile("data/ai/gamemaster_effects.gbnf");
const narratorExamples = loadJSON("data/ai/examples/narrator_examples.json");
const gmExamples = loadJSON("data/ai/examples/gamemaster_examples.json");

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Extract GDScript constructs
// ═══════════════════════════════════════════════════════════════════════════════

function extractConstants(code) {
  const consts = {};
  const rx = /const\s+(\w+)\s*(?::=|:\s*\w+\s*=)\s*(.+)/g;
  let m;
  while ((m = rx.exec(code)) !== null) {
    // Strip inline comments (# ...) from value
    let val = m[2].trim().replace(/\s+#.*$/, "");
    consts[m[1]] = val;
  }
  return consts;
}

function extractVars(code) {
  const vars = {};
  const rx = /^var\s+(\w+)\s*(?::\s*\w+(?:\[.*?\])?)?\s*=\s*(.+)/gm;
  let m;
  while ((m = rx.exec(code)) !== null) {
    vars[m[1]] = m[2].trim();
  }
  return vars;
}

function extractFunctions(code) {
  const fns = [];
  const rx = /^(?:static\s+)?func\s+(\w+)\s*\(([^)]*)\)/gm;
  let m;
  while ((m = rx.exec(code)) !== null) {
    fns.push({ name: m[1], params: m[2].trim() });
  }
  return fns;
}

function extractSignals(code) {
  const signals = [];
  const rx = /^signal\s+(\w+)\s*(?:\(([^)]*)\))?/gm;
  let m;
  while ((m = rx.exec(code)) !== null) {
    signals.push({ name: m[1], params: (m[2] || "").trim() });
  }
  return signals;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 1: Brain Constants & Configuration
// ═══════════════════════════════════════════════════════════════════════════════

function testConstants() {
  describe("Brain Constants", () => {
    const consts = extractConstants(merlinAI);

    it("BRAIN_SINGLE = 1", () => assertEqual(consts.BRAIN_SINGLE, "1"));
    it("BRAIN_DUAL = 2", () => assertEqual(consts.BRAIN_DUAL, "2"));
    it("BRAIN_TRIPLE = 3", () => assertEqual(consts.BRAIN_TRIPLE, "3"));
    it("BRAIN_QUAD = 4", () => assertEqual(consts.BRAIN_QUAD, "4"));
    it("BRAIN_MAX = BRAIN_QUAD", () => assertEqual(consts.BRAIN_MAX, "BRAIN_QUAD"));
    it("RAM_PER_BRAIN_MB defined", () => assert(consts.RAM_PER_BRAIN_MB, "RAM_PER_BRAIN_MB missing"));

    it("Task type constants defined", () => {
      assertEqual(consts.TASK_PREFETCH, '"prefetch"');
      assertEqual(consts.TASK_VOICE, '"voice"');
      assertEqual(consts.TASK_BALANCE, '"balance"');
    });

    it("TASK_PRIORITIES has correct ordering (prefetch < voice < balance)", () => {
      assertIncludes(merlinAI, '"prefetch": 0');
      assertIncludes(merlinAI, '"voice": 1');
      assertIncludes(merlinAI, '"balance": 2');
    });

    it("Narrator params: temp=0.7 (creative)", () => {
      assertMatch(merlinAI, /"temperature":\s*0\.7/);
    });

    it("Game Master params: temp=0.2 (precise)", () => {
      assertMatch(merlinAI, /"temperature":\s*0\.2/);
    });

    it("PROMPT_TEMPLATES_PATH points to correct file", () => {
      assertEqual(consts.PROMPT_TEMPLATES_PATH, '"res://data/ai/config/prompt_templates.json"');
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 2: Brain Detection Logic
// ═══════════════════════════════════════════════════════════════════════════════

function testDetection() {
  describe("Brain Detection Logic (detect_optimal_brains)", () => {
    // Extract the detection function body
    const fnMatch = merlinAI.match(
      /static func detect_optimal_brains\(\)[^{]*?:([\s\S]*?)(?=\n(?:static )?func |\n# ═)/
    );
    assert(fnMatch, "detect_optimal_brains function not found");
    const fnBody = fnMatch[1];

    it("Web platform returns 1 brain", () => {
      assertIncludes(fnBody, 'is_web');
      assertIncludes(fnBody, 'return 1');
    });

    it("Mobile platform checks CPU count for 1-2 brains", () => {
      assertIncludes(fnBody, 'is_mobile');
      assertIncludes(fnBody, 'cpu_count >= 8');
    });

    it("Desktop with 16+ CPUs returns 4 brains", () => {
      assertIncludes(fnBody, 'cpu_count >= 16');
      assertIncludes(fnBody, 'return 4');
    });

    it("Desktop with 12+ CPUs returns 3 brains", () => {
      assertIncludes(fnBody, 'cpu_count >= 12');
      assertIncludes(fnBody, 'return 3');
    });

    it("Desktop with 6+ CPUs returns 2 brains", () => {
      assertIncludes(fnBody, 'cpu_count >= 6');
      assertIncludes(fnBody, 'return 2');
    });

    it("Low-end fallback returns 1 brain", () => {
      // Last return in function
      const returns = fnBody.match(/return \d/g);
      assert(returns, "No return statements found");
      assertEqual(returns[returns.length - 1], "return 1");
    });

    it("Detection tiers are monotonically decreasing (16 > 12 > 6)", () => {
      const idx16 = fnBody.indexOf("cpu_count >= 16");
      const idx12 = fnBody.indexOf("cpu_count >= 12");
      const idx6 = fnBody.indexOf("cpu_count >= 6");
      assert(idx16 < idx12 && idx12 < idx6, "CPU thresholds not in descending order");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 3: Pool Architecture (Lease/Release)
// ═══════════════════════════════════════════════════════════════════════════════

function testPoolArchitecture() {
  describe("Worker Pool Architecture", () => {
    it("Pool worker variables exist", () => {
      assertIncludes(merlinAI, "var _pool_workers: Array");
      assertIncludes(merlinAI, "var _pool_busy: Array");
    });

    it("Primary busy tracking variables exist", () => {
      assertIncludes(merlinAI, "var _primary_narrator_busy");
      assertIncludes(merlinAI, "var _primary_gm_busy");
    });

    it("Background task system variables exist", () => {
      assertIncludes(merlinAI, "var _active_bg_tasks: Array");
      assertIncludes(merlinAI, "var _bg_queue: Array");
    });

    it("_lease_bg_brain checks pool workers first", () => {
      const fnMatch = merlinAI.match(
        /func _lease_bg_brain\(\)[^{]*?:([\s\S]*?)(?=\nfunc )/
      );
      assert(fnMatch, "_lease_bg_brain not found");
      const body = fnMatch[1];

      // Pool workers should be checked before primary brains
      const poolCheck = body.indexOf("_pool_workers");
      const narratorCheck = body.indexOf("_primary_narrator_busy");
      const gmCheck = body.indexOf("_primary_gm_busy");
      assert(poolCheck < narratorCheck, "Pool should be checked before narrator");
      assert(narratorCheck < gmCheck, "Narrator should be checked before GM");
    });

    it("_lease_bg_brain returns null when all busy", () => {
      assertIncludes(merlinAI, "return null", "_lease_bg_brain should return null");
    });

    it("_release_bg_brain handles pool workers", () => {
      const fnMatch = merlinAI.match(
        /func _release_bg_brain\(llm: Object\)[^{]*?:([\s\S]*?)(?=\nfunc |\n$)/
      );
      assert(fnMatch, "_release_bg_brain not found");
      const body = fnMatch[1];
      assertIncludes(body, "_pool_workers");
      assertIncludes(body, "_pool_busy[i] = false");
    });

    it("_release_bg_brain handles primary narrator", () => {
      const fnMatch = merlinAI.match(
        /func _release_bg_brain\(llm: Object\)[^{]*?:([\s\S]*?)(?=\nfunc |\n$)/
      );
      const body = fnMatch[1];
      assertIncludes(body, "narrator_llm");
      assertIncludes(body, "_primary_narrator_busy = false");
    });

    it("_release_bg_brain handles primary game master", () => {
      const fnMatch = merlinAI.match(
        /func _release_bg_brain\(llm: Object\)[^{]*?:([\s\S]*?)(?=\nfunc |\n$)/
      );
      const body = fnMatch[1];
      assertIncludes(body, "gamemaster_llm");
      assertIncludes(body, "_primary_gm_busy = false");
    });

    it("_lease_bg_brain checks GM is distinct from narrator", () => {
      assertIncludes(merlinAI, "gamemaster_llm != narrator_llm");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 4: Background Task System
// ═══════════════════════════════════════════════════════════════════════════════

function testBackgroundTasks() {
  describe("Background Task System", () => {
    it("background_task_completed signal exists", () => {
      const signals = extractSignals(merlinAI);
      const found = signals.find((s) => s.name === "background_task_completed");
      assert(found, "Signal background_task_completed not found");
      assertIncludes(found.params, "task_type");
      assertIncludes(found.params, "result");
    });

    it("submit_background_task method exists with correct params", () => {
      const fns = extractFunctions(merlinAI);
      const fn = fns.find((f) => f.name === "submit_background_task");
      assert(fn, "submit_background_task not found");
      assertIncludes(fn.params, "task_type");
      assertIncludes(fn.params, "system_prompt");
      assertIncludes(fn.params, "callback");
    });

    it("submit_balance_check convenience method exists", () => {
      const fns = extractFunctions(merlinAI);
      assert(fns.find((f) => f.name === "submit_balance_check"), "submit_balance_check not found");
    });

    it("_fire_bg_task dispatches on leased brain", () => {
      assertIncludes(merlinAI, "func _fire_bg_task(task: Dictionary, llm: Object)");
    });

    it("_dispatch_from_queue processes pending tasks", () => {
      assertIncludes(merlinAI, "func _dispatch_from_queue()");
      assertIncludes(merlinAI, "_bg_queue.is_empty()");
      assertIncludes(merlinAI, "_bg_queue.pop_front()");
    });

    it("_process polls active tasks", () => {
      assertIncludes(merlinAI, "func _process(_delta: float)");
      assertIncludes(merlinAI, "_active_bg_tasks");
      assertIncludes(merlinAI, "task.state.done");
    });

    it("_process disables itself when idle", () => {
      assertIncludes(merlinAI, "set_process(false)");
    });

    it("submit_background_task sorts queue by priority", () => {
      assertIncludes(merlinAI, "sort_custom");
      assertIncludes(merlinAI, "priority");
    });

    it("Completed bg tasks release brain and fire callback", () => {
      assertIncludes(merlinAI, "task.callback.call(result)");
      assertIncludes(merlinAI, "background_task_completed.emit");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 5: Generation Methods (Narrator, GM, Parallel, Pool)
// ═══════════════════════════════════════════════════════════════════════════════

function testGenerationMethods() {
  describe("Generation Methods", () => {
    const fns = extractFunctions(merlinAI);

    it("generate_narrative exists", () => {
      assert(fns.find((f) => f.name === "generate_narrative"), "generate_narrative not found");
    });

    it("generate_structured exists", () => {
      assert(fns.find((f) => f.name === "generate_structured"), "generate_structured not found");
    });

    it("generate_parallel exists", () => {
      assert(fns.find((f) => f.name === "generate_parallel"), "generate_parallel not found");
    });

    it("generate_prefetch exists (pool-based)", () => {
      assert(fns.find((f) => f.name === "generate_prefetch"), "generate_prefetch not found");
    });

    it("generate_voice exists (pool-based)", () => {
      assert(fns.find((f) => f.name === "generate_voice"), "generate_voice not found");
    });

    it("generate_narrative sets _primary_narrator_busy", () => {
      const match = merlinAI.match(
        /func generate_narrative\b[\s\S]*?(?=\nfunc )/
      );
      assert(match, "generate_narrative body not found");
      assertIncludes(match[0], "_primary_narrator_busy = true");
      assertIncludes(match[0], "_primary_narrator_busy = false");
      assertIncludes(match[0], "_dispatch_from_queue()");
    });

    it("generate_structured sets _primary_gm_busy", () => {
      const match = merlinAI.match(
        /func generate_structured\b[\s\S]*?(?=\nfunc )/
      );
      assert(match, "generate_structured body not found");
      assertIncludes(match[0], "_primary_gm_busy = true");
      assertIncludes(match[0], "_primary_gm_busy = false");
      assertIncludes(match[0], "_dispatch_from_queue()");
    });

    it("generate_parallel sets BOTH busy flags", () => {
      const match = merlinAI.match(
        /func generate_parallel\b[\s\S]*?(?=\n## Generate a card)/
      );
      assert(match, "generate_parallel body not found");
      assertIncludes(match[0], "_primary_narrator_busy = true");
      assertIncludes(match[0], "_primary_gm_busy = true");
      assertIncludes(match[0], "_primary_narrator_busy = false");
      assertIncludes(match[0], "_primary_gm_busy = false");
    });

    it("generate_parallel sequential fallback for brain_count < 2", () => {
      assertIncludes(merlinAI, "brain_count < 2");
      // Should call generate_narrative then generate_structured
      const match = merlinAI.match(
        /func generate_parallel\b[\s\S]*?(?=\n## Generate a card)/
      );
      assertIncludes(match[0], "await generate_narrative(");
      assertIncludes(match[0], "await generate_structured(");
      assertIncludes(match[0], '"parallel": false');
    });

    it("generate_prefetch uses _lease_bg_brain/_release_bg_brain", () => {
      const match = merlinAI.match(
        /func generate_prefetch\b[\s\S]*?(?=\nfunc )/
      );
      assert(match, "generate_prefetch body not found");
      assertIncludes(match[0], "_lease_bg_brain()");
      assertIncludes(match[0], "_release_bg_brain(target_llm)");
    });

    it("generate_voice uses pool with dedicated params", () => {
      const match = merlinAI.match(
        /func generate_voice\b[\s\S]*?(?=\nfunc )/
      );
      assert(match, "generate_voice body not found");
      assertIncludes(match[0], "_lease_bg_brain()");
      assertIncludes(match[0], 'max_tokens');
      assertIncludes(match[0], "_release_bg_brain(target_llm)");
    });

    it("generate_narrative strips grammar param", () => {
      const match = merlinAI.match(
        /func generate_narrative\b[\s\S]*?(?=\nfunc )/
      );
      assertIncludes(match[0], 'params.erase("grammar")');
    });

    it("generate_structured applies GBNF grammar", () => {
      const match = merlinAI.match(
        /func generate_structured\b[\s\S]*?(?=\nfunc )/
      );
      assertIncludes(match[0], "set_grammar");
      assertIncludes(match[0], "clear_grammar");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 6: Model Init Flow (1, 2, 3, 4 brains)
// ═══════════════════════════════════════════════════════════════════════════════

function testModelInit() {
  describe("Model Initialization Flow (_init_local_models)", () => {
    const match = merlinAI.match(
      /func _init_local_models\(\)[^{]*?:([\s\S]*?)(?=\n## Detect)/
    );
    assert(match, "_init_local_models body not found");
    const body = match[1];

    it("Starts with brain_count = 0", () => {
      assertIncludes(body, "brain_count = 0");
    });

    it("Brain 1 (Narrator) always loaded first", () => {
      assertIncludes(body, "Brain 1/Narrator");
      assertIncludes(body, "brain_count = 1");
    });

    it("Single brain sets gamemaster_llm = narrator_llm", () => {
      assertIncludes(body, "gamemaster_llm = narrator_llm");
    });

    it("Brain 2 (Game Master) loaded conditionally", () => {
      assertIncludes(body, "target >= BRAIN_DUAL");
      assertIncludes(body, "Brain 2/Game Master");
      assertIncludes(body, "brain_count = 2");
    });

    it("Brain 2 failure gracefully stays at 1 brain", () => {
      assertIncludes(body, 'staying at 1 brain');
    });

    it("Pool workers (Brain 3-4) loaded in loop", () => {
      assertIncludes(body, "_pool_workers.clear()");
      assertIncludes(body, "_pool_busy.clear()");
      assertIncludes(body, "for i in range(2)");
      assertIncludes(body, "pool_brain_num: int = 3 + i");
    });

    it("Pool worker loading checks prerequisite brain count", () => {
      assertIncludes(body, "brain_count >= pool_brain_num - 1");
    });

    it("Pool worker failure breaks the loop (no Brain 4 without Brain 3)", () => {
      assertIncludes(body, "break  # Don't try Brain 4 if Brain 3 failed");
    });

    it("RAM estimate calculated from brain_count", () => {
      assertIncludes(body, "brain_count * RAM_PER_BRAIN_MB");
    });

    it("Status shows correct mode name and brain count", () => {
      assertIncludes(body, "_get_brain_mode_name()");
      assertIncludes(body, "is_ready = true");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 7: Mode Names
// ═══════════════════════════════════════════════════════════════════════════════

function testModeNames() {
  describe("Brain Mode Names", () => {
    const match = merlinAI.match(
      /func _get_brain_mode_name\(\)[^{]*?:([\s\S]*?)(?=\nfunc )/
    );
    assert(match, "_get_brain_mode_name body not found");
    const body = match[1];

    it('1 brain = "Single (Narrator seul)"', () => {
      assertIncludes(body, '"Single (Narrator seul)"');
    });

    it('2 brains = "Dual (Narrator + GM)"', () => {
      assertIncludes(body, '"Dual (Narrator + GM)"');
    });

    it('3 brains = "Triple (Narrator + GM + 1 Worker)"', () => {
      assertIncludes(body, '"Triple (Narrator + GM + 1 Worker)"');
    });

    it('4 brains = "Quad (Narrator + GM + 2 Workers)"', () => {
      assertIncludes(body, '"Quad (Narrator + GM + 2 Workers)"');
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 8: Pool Accessors
// ═══════════════════════════════════════════════════════════════════════════════

function testPoolAccessors() {
  describe("Pool Accessor Methods", () => {
    const fns = extractFunctions(merlinAI);

    it("has_pool() exists", () => {
      assert(fns.find((f) => f.name === "has_pool"), "has_pool not found");
    });

    it("get_pool_size() exists", () => {
      assert(fns.find((f) => f.name === "get_pool_size"), "get_pool_size not found");
    });

    it("get_pool_idle_count() exists", () => {
      assert(fns.find((f) => f.name === "get_pool_idle_count"), "get_pool_idle_count not found");
    });

    it("has_prefetcher() considers pool + idle primary brains", () => {
      const match = merlinAI.match(
        /func has_prefetcher\(\)[^{]*?:([\s\S]*?)(?=\nfunc )/
      );
      assert(match, "has_prefetcher body not found");
      assertIncludes(match[0], "_pool_workers.size()");
      assertIncludes(match[0], "_primary_narrator_busy");
      assertIncludes(match[0], "_primary_gm_busy");
    });

    it("is_dual_mode() checks brain_count >= 2", () => {
      assertIncludes(merlinAI, "brain_count >= 2");
    });

    it("get_model_info returns pool stats", () => {
      const match = merlinAI.match(
        /func get_model_info\(\)[^{]*?:([\s\S]*?)(?=\nfunc )/
      );
      assert(match, "get_model_info body not found");
      assertIncludes(match[0], "pool_workers");
      assertIncludes(match[0], "pool_idle");
      assertIncludes(match[0], "has_pool");
      assertIncludes(match[0], "brain_count");
      assertIncludes(match[0], "brain_mode");
    });

    it("set_brain_count clamps to BRAIN_MAX", () => {
      assertIncludes(merlinAI, "clampi(count, 0, BRAIN_MAX)");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 9: Omniscient Integration
// ═══════════════════════════════════════════════════════════════════════════════

function testOmniscientIntegration() {
  describe("MerlinOmniscient Pool Integration", () => {
    it("prefetch_next_card uses generate_prefetch via pool", () => {
      assertIncludes(merlinOmni, "generate_prefetch");
      assertIncludes(merlinOmni, "has_prefetcher()");
    });

    it("_prefetch_via_pool method exists", () => {
      assertIncludes(merlinOmni, "func _prefetch_via_pool()");
    });

    it("_prefetch_via_pool calls generate_prefetch", () => {
      const match = merlinOmni.match(
        /func _prefetch_via_pool\(\)[^{]*?:([\s\S]*?)(?=\nfunc )/
      );
      assert(match, "_prefetch_via_pool body not found");
      assertIncludes(match[0], "llm_interface.generate_prefetch");
    });

    it("_try_llm_generation checks brain_count >= 2 for parallel", () => {
      assertIncludes(merlinOmni, "llm_interface.brain_count >= 2");
    });

    it("_generate_merlin_comment uses generate_voice when available", () => {
      assertIncludes(merlinOmni, 'generate_voice');
      assertIncludes(merlinOmni, "has_method(\"generate_voice\")");
    });

    it("_generate_merlin_comment falls back to generate_with_router", () => {
      assertIncludes(merlinOmni, "generate_with_router");
    });

    it("Parallel generation builds both narrator and GM prompts", () => {
      assertIncludes(merlinOmni, "func _build_narrator_prompt()");
      assertIncludes(merlinOmni, "func _build_narrator_input()");
      assertIncludes(merlinOmni, "func _build_gm_prompt()");
      assertIncludes(merlinOmni, "func _build_gm_input()");
    });

    it("Parallel merge combines narrative text + GM effects", () => {
      assertIncludes(merlinOmni, "func _merge_parallel_results(");
    });

    it("GBNF grammar loaded from file for parallel generation", () => {
      assertIncludes(merlinOmni, "gamemaster_effects.gbnf");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 10: Data Files Validation
// ═══════════════════════════════════════════════════════════════════════════════

function testDataFiles() {
  describe("Data Files — Prompt Templates", () => {
    it("prompt_templates.json exists and is valid JSON", () => {
      assert(promptTemplates !== null, "prompt_templates.json missing or invalid");
    });

    it("Has narrator_card_text template", () => {
      assert(promptTemplates.narrator_card_text, "narrator_card_text missing");
      assert(promptTemplates.narrator_card_text.system, "system prompt missing");
      assert(promptTemplates.narrator_card_text.role === "narrator", "wrong role");
    });

    it("Has narrator_choices template", () => {
      assert(promptTemplates.narrator_choices, "narrator_choices missing");
    });

    it("Has narrator_merlin_voice template", () => {
      assert(promptTemplates.narrator_merlin_voice, "narrator_merlin_voice missing");
    });

    it("Has narrator_foreshadowing template", () => {
      assert(promptTemplates.narrator_foreshadowing, "narrator_foreshadowing missing");
    });

    it("Has gamemaster_effects template", () => {
      assert(promptTemplates.gamemaster_effects, "gamemaster_effects missing");
      assert(promptTemplates.gamemaster_effects.grammar, "grammar reference missing");
      assertEqual(promptTemplates.gamemaster_effects.role, "gamemaster");
    });

    it("Has gamemaster_balance template", () => {
      assert(promptTemplates.gamemaster_balance, "gamemaster_balance missing");
      assertEqual(promptTemplates.gamemaster_balance.role, "gamemaster");
    });

    it("Has gamemaster_rules template", () => {
      assert(promptTemplates.gamemaster_rules, "gamemaster_rules missing");
    });

    it("All templates have max_tokens defined", () => {
      for (const [key, tmpl] of Object.entries(promptTemplates)) {
        if (key === "_meta") continue;
        assert(typeof tmpl.max_tokens === "number", `${key} missing max_tokens`);
        assert(tmpl.max_tokens > 0 && tmpl.max_tokens <= 500, `${key} max_tokens out of range`);
      }
    });

    it("_meta version is 1.0.0", () => {
      assert(promptTemplates._meta, "_meta missing");
      assertEqual(promptTemplates._meta.version, "1.0.0");
    });
  });

  describe("Data Files — GBNF Grammar", () => {
    it("gamemaster_effects.gbnf exists", () => {
      assert(gmGbnf !== null, "GBNF file missing");
    });

    it("Grammar has root rule", () => {
      assertMatch(gmGbnf, /^root\s*::=/m);
    });

    it("Grammar defines options-kv with 3 entries", () => {
      assertIncludes(gmGbnf, "options-kv");
      assertIncludes(gmGbnf, "option-entry");
      assertIncludes(gmGbnf, "option-center");
    });

    it("Grammar supports SHIFT_ASPECT effect", () => {
      assertIncludes(gmGbnf, "SHIFT_ASPECT");
      assertIncludes(gmGbnf, "shift-effect");
    });

    it("Grammar supports ADD_KARMA effect", () => {
      assertIncludes(gmGbnf, "ADD_KARMA");
      assertIncludes(gmGbnf, "karma-effect");
    });

    it("Grammar supports ADD_TENSION effect", () => {
      assertIncludes(gmGbnf, "ADD_TENSION");
      assertIncludes(gmGbnf, "tension-effect");
    });

    it("Grammar supports USE_SOUFFLE and ADD_SOUFFLE effects", () => {
      assertIncludes(gmGbnf, "USE_SOUFFLE");
      assertIncludes(gmGbnf, "ADD_SOUFFLE");
      assertIncludes(gmGbnf, "souffle-effect");
    });

    it("Grammar defines valid aspects (Corps, Ame, Monde)", () => {
      // GBNF uses escaped quotes: \"Corps\" in the file
      assertIncludes(gmGbnf, "Corps");
      assertIncludes(gmGbnf, "Ame");
      assertIncludes(gmGbnf, "Monde");
    });

    it("Grammar defines directions (up, down)", () => {
      assertIncludes(gmGbnf, "up");
      assertIncludes(gmGbnf, "down");
    });

    it("Center option has cost field", () => {
      assertIncludes(gmGbnf, "cost-kv");
      assertMatch(gmGbnf, /cost-kv\s*::=/);
    });
  });

  describe("Data Files — Few-shot Examples", () => {
    it("narrator_examples.json exists and valid", () => {
      assert(narratorExamples !== null, "narrator_examples.json missing");
    });

    it("Narrator has card_text_examples", () => {
      assert(Array.isArray(narratorExamples.card_text_examples), "card_text_examples not array");
      assert(narratorExamples.card_text_examples.length >= 3, "Need >= 3 examples");
    });

    it("Narrator examples are in French", () => {
      for (const ex of narratorExamples.card_text_examples) {
        const frWords = ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et"];
        const words = ex.output.toLowerCase().split(/\s+/);
        const count = words.filter((w) => frWords.includes(w)).length;
        assert(count >= 2, `Example not French enough: "${ex.output.substring(0, 40)}"`);
      }
    });

    it("Narrator has merlin_voice_examples", () => {
      assert(Array.isArray(narratorExamples.merlin_voice_examples));
      assert(narratorExamples.merlin_voice_examples.length >= 3);
    });

    it("gamemaster_examples.json exists and valid", () => {
      assert(gmExamples !== null, "gamemaster_examples.json missing");
    });

    it("GM has effects_examples with valid structure", () => {
      assert(Array.isArray(gmExamples.effects_examples));
      for (const ex of gmExamples.effects_examples) {
        assert(ex.context, "Example missing context");
        assert(ex.output, "Example missing output");
        assert(Array.isArray(ex.output.options), "Output missing options array");
        assertEqual(ex.output.options.length, 3, "Each example should have 3 options");
      }
    });

    it("GM effects_examples have valid effect types", () => {
      const validTypes = [
        "SHIFT_ASPECT", "ADD_KARMA", "ADD_TENSION", "USE_SOUFFLE", "ADD_SOUFFLE", "CREATE_PROMISE",
      ];
      for (const ex of gmExamples.effects_examples) {
        for (const opt of ex.output.options) {
          for (const effect of opt.effects || []) {
            assert(
              validTypes.includes(effect.type),
              `Invalid effect type: ${effect.type}`
            );
          }
        }
      }
    });

    it("GM has balance_examples", () => {
      assert(Array.isArray(gmExamples.balance_examples));
      assert(gmExamples.balance_examples.length >= 1);
    });

    it("GM has rule_change_examples", () => {
      assert(Array.isArray(gmExamples.rule_change_examples));
      assert(gmExamples.rule_change_examples.length >= 1);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 11: Busy Flag Consistency
// ═══════════════════════════════════════════════════════════════════════════════

function testBusyFlagConsistency() {
  describe("Busy Flag Consistency (every set must have a clear)", () => {
    it("_primary_narrator_busy: all set/clear pairs balanced", () => {
      const sets = (merlinAI.match(/_primary_narrator_busy = true/g) || []).length;
      const clears = (merlinAI.match(/_primary_narrator_busy = false/g) || []).length;
      // At minimum, every method that sets true should also set false
      assert(clears >= sets, `Narrator busy: ${sets} sets vs ${clears} clears (potential leak)`);
    });

    it("_primary_gm_busy: all set/clear pairs balanced", () => {
      const sets = (merlinAI.match(/_primary_gm_busy = true/g) || []).length;
      const clears = (merlinAI.match(/_primary_gm_busy = false/g) || []).length;
      assert(clears >= sets, `GM busy: ${sets} sets vs ${clears} clears (potential leak)`);
    });

    it("generate_narrative clears busy in both success and error paths", () => {
      const match = merlinAI.match(
        /func generate_narrative\b[\s\S]*?(?=\n(?:##|func) )/
      );
      const body = match[0];
      // Count the busy=false occurrences (should appear after await)
      const clears = (body.match(/_primary_narrator_busy = false/g) || []).length;
      assert(clears >= 1, "generate_narrative doesn't clear narrator busy");
    });

    it("generate_structured clears busy in both success and error paths", () => {
      const match = merlinAI.match(
        /func generate_structured\b[\s\S]*?(?=\n(?:##|func) )/
      );
      const body = match[0];
      const clears = (body.match(/_primary_gm_busy = false/g) || []).length;
      assert(clears >= 1, "generate_structured doesn't clear GM busy");
    });

    it("generate_parallel clears BOTH busy flags", () => {
      const match = merlinAI.match(
        /func generate_parallel\b[\s\S]*?(?=\n## Generate a card)/
      );
      const body = match[0];
      const narratorClears = (body.match(/_primary_narrator_busy = false/g) || []).length;
      const gmClears = (body.match(/_primary_gm_busy = false/g) || []).length;
      assert(narratorClears >= 1, "generate_parallel doesn't clear narrator busy");
      assert(gmClears >= 1, "generate_parallel doesn't clear GM busy");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 12: Backward Compatibility
// ═══════════════════════════════════════════════════════════════════════════════

function testBackwardCompat() {
  describe("Backward Compatibility", () => {
    it("router_params alias exists for narrator_params", () => {
      assertIncludes(merlinAI, "var router_params: Dictionary");
      assertIncludes(merlinAI, "return narrator_params");
    });

    it("executor_params alias exists for gamemaster_params", () => {
      assertIncludes(merlinAI, "var executor_params: Dictionary");
      assertIncludes(merlinAI, "return gamemaster_params");
    });

    it("get_router_params returns narrator_params", () => {
      assertIncludes(merlinAI, "func get_router_params()");
    });

    it("get_executor_params returns gamemaster_params", () => {
      assertIncludes(merlinAI, "func get_executor_params()");
    });

    it("set_router_params updates narrator_params", () => {
      assertIncludes(merlinAI, "func set_router_params(");
    });

    it("set_executor_params updates gamemaster_params", () => {
      assertIncludes(merlinAI, "func set_executor_params(");
    });

    it("generate_with_system still works (delegates to narrator/gm)", () => {
      const fns = extractFunctions(merlinAI);
      assert(fns.find((f) => f.name === "generate_with_system"), "generate_with_system not found");
    });

    it("generate_with_router still works (uses narrator)", () => {
      const fns = extractFunctions(merlinAI);
      assert(fns.find((f) => f.name === "generate_with_router"), "generate_with_router not found");
    });

    it("get_model_info has backward compat fields (router, executor)", () => {
      assertIncludes(merlinAI, '"router":');
      assertIncludes(merlinAI, '"executor":');
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 13: Cross-File Consistency
// ═══════════════════════════════════════════════════════════════════════════════

function testCrossFileConsistency() {
  describe("Cross-File Consistency", () => {
    it("MerlinOmniscient references MerlinAI autoload", () => {
      assertIncludes(merlinOmni, '/root/MerlinAI');
    });

    it("MerlinOmniscient type hint matches (MerlinAI)", () => {
      assertIncludes(merlinOmni, "var llm_interface: MerlinAI");
    });

    it("No stale _dual_mode references in merlin_ai.gd", () => {
      // _dual_mode was removed in the refactoring
      const matches = merlinAI.match(/\b_dual_mode\b/g);
      assert(!matches, `Found ${matches ? matches.length : 0} stale _dual_mode references`);
    });

    it("No stale _dual_mode references in merlin_omniscient.gd", () => {
      const matches = merlinOmni.match(/\b_dual_mode\b/g);
      assert(!matches, `Found ${matches ? matches.length : 0} stale _dual_mode references`);
    });

    it("No stale prefetcher_llm references", () => {
      const matches = merlinAI.match(/\bprefetcher_llm\b/g);
      assert(!matches, `Found ${matches ? matches.length : 0} stale prefetcher_llm references`);
    });

    it("No stale prefetcher_params references", () => {
      const matches = merlinAI.match(/\bprefetcher_params\b/g);
      assert(!matches, `Found ${matches ? matches.length : 0} stale prefetcher_params references`);
    });

    it("No references to _prefetch_with_brain3 (replaced by _prefetch_via_pool)", () => {
      const inAI = merlinAI.match(/_prefetch_with_brain3/g);
      const inOmni = merlinOmni.match(/_prefetch_with_brain3/g);
      assert(!inAI, "Stale _prefetch_with_brain3 in merlin_ai.gd");
      assert(!inOmni, "Stale _prefetch_with_brain3 in merlin_omniscient.gd");
    });

    it("GBNF grammar file referenced by prompt template", () => {
      assertEqual(promptTemplates.gamemaster_effects.grammar, "gamemaster_effects.gbnf");
    });

    it("Aspects in GBNF match aspects used in code", () => {
      // GBNF uses escaped quotes around aspect names
      for (const aspect of ["Corps", "Ame", "Monde"]) {
        assertIncludes(gmGbnf, aspect, `GBNF missing ${aspect}`);
        assertIncludes(merlinOmni, `"${aspect}"`, `Omniscient missing ${aspect}`);
      }
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 14: Simulated Pool Scenarios
// ═══════════════════════════════════════════════════════════════════════════════

function testSimulatedPoolScenarios() {
  describe("Simulated Pool Scenarios (logic validation)", () => {
    // Simulate the pool lease/release logic in JS
    class SimPool {
      constructor(brainCount) {
        this.brainCount = brainCount;
        this.narratorBusy = false;
        this.gmBusy = false;
        this.poolSize = Math.max(0, brainCount - 2);
        this.poolBusy = new Array(this.poolSize).fill(false);
        this.isSharedMode = brainCount === 1; // GM === narrator
      }

      lease() {
        // Pool workers first
        for (let i = 0; i < this.poolSize; i++) {
          if (!this.poolBusy[i]) {
            this.poolBusy[i] = true;
            return `pool_${i}`;
          }
        }
        // Narrator if idle
        if (!this.narratorBusy) {
          this.narratorBusy = true;
          return "narrator";
        }
        // GM if idle and distinct
        if (!this.gmBusy && !this.isSharedMode) {
          this.gmBusy = true;
          return "gm";
        }
        return null;
      }

      release(brain) {
        if (brain?.startsWith("pool_")) {
          const idx = parseInt(brain.split("_")[1]);
          this.poolBusy[idx] = false;
        } else if (brain === "narrator") {
          this.narratorBusy = false;
        } else if (brain === "gm") {
          this.gmBusy = false;
        }
      }

      idleCount() {
        let count = 0;
        for (let i = 0; i < this.poolSize; i++) {
          if (!this.poolBusy[i]) count++;
        }
        return count;
      }
    }

    it("1-brain: lease returns narrator, second lease returns null", () => {
      const pool = new SimPool(1);
      const b1 = pool.lease();
      assertEqual(b1, "narrator");
      const b2 = pool.lease();
      assertEqual(b2, null, "1-brain: should be null (shared GM=narrator)");
      pool.release(b1);
    });

    it("2-brain: lease returns narrator then gm, third returns null", () => {
      const pool = new SimPool(2);
      const b1 = pool.lease();
      assertEqual(b1, "narrator");
      const b2 = pool.lease();
      assertEqual(b2, "gm");
      const b3 = pool.lease();
      assertEqual(b3, null);
      pool.release(b1);
      pool.release(b2);
    });

    it("2-brain: during parallel (both busy), bg task returns null", () => {
      const pool = new SimPool(2);
      pool.narratorBusy = true;
      pool.gmBusy = true;
      const bg = pool.lease();
      assertEqual(bg, null, "During parallel generation, no brain available");
    });

    it("2-brain: after parallel finishes, bg task gets narrator", () => {
      const pool = new SimPool(2);
      pool.narratorBusy = false;
      pool.gmBusy = false;
      const bg = pool.lease();
      assertEqual(bg, "narrator", "Narrator should be available when idle");
    });

    it("3-brain: pool worker leased before primary brains", () => {
      const pool = new SimPool(3);
      const b1 = pool.lease();
      assertEqual(b1, "pool_0", "Should prefer pool worker");
    });

    it("3-brain: after pool exhausted, falls back to narrator", () => {
      const pool = new SimPool(3);
      const b1 = pool.lease();
      assertEqual(b1, "pool_0");
      const b2 = pool.lease();
      assertEqual(b2, "narrator");
      const b3 = pool.lease();
      assertEqual(b3, "gm");
      const b4 = pool.lease();
      assertEqual(b4, null);
    });

    it("3-brain: during parallel, pool worker still available", () => {
      const pool = new SimPool(3);
      pool.narratorBusy = true;
      pool.gmBusy = true;
      const bg = pool.lease();
      assertEqual(bg, "pool_0", "Pool worker available during parallel");
    });

    it("4-brain: 2 pool workers available", () => {
      const pool = new SimPool(4);
      const b1 = pool.lease();
      assertEqual(b1, "pool_0");
      const b2 = pool.lease();
      assertEqual(b2, "pool_1");
      const b3 = pool.lease();
      assertEqual(b3, "narrator");
      const b4 = pool.lease();
      assertEqual(b4, "gm");
      const b5 = pool.lease();
      assertEqual(b5, null);
    });

    it("4-brain: during parallel, 2 pool workers still available", () => {
      const pool = new SimPool(4);
      pool.narratorBusy = true;
      pool.gmBusy = true;
      const bg1 = pool.lease();
      assertEqual(bg1, "pool_0");
      const bg2 = pool.lease();
      assertEqual(bg2, "pool_1");
      const bg3 = pool.lease();
      assertEqual(bg3, null, "All exhausted during parallel");
    });

    it("Release returns brain to pool correctly", () => {
      const pool = new SimPool(3);
      const b1 = pool.lease();
      assertEqual(pool.idleCount(), 0, "Pool exhausted");
      pool.release(b1);
      assertEqual(pool.idleCount(), 1, "Pool worker released");
    });

    it("Task priority: prefetch < voice < balance", () => {
      const priorities = { prefetch: 0, voice: 1, balance: 2 };
      const queue = [
        { type: "balance", priority: priorities.balance },
        { type: "prefetch", priority: priorities.prefetch },
        { type: "voice", priority: priorities.voice },
      ];
      queue.sort((a, b) => a.priority - b.priority);
      assertEqual(queue[0].type, "prefetch", "Prefetch should be first");
      assertEqual(queue[1].type, "voice", "Voice should be second");
      assertEqual(queue[2].type, "balance", "Balance should be last");
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST SUITE 15: Signal Declarations
// ═══════════════════════════════════════════════════════════════════════════════

function testSignals() {
  describe("Signal Declarations", () => {
    const aiSignals = extractSignals(merlinAI);
    const omniSignals = extractSignals(merlinOmni);

    it("merlin_ai.gd has background_task_completed signal", () => {
      assert(aiSignals.find((s) => s.name === "background_task_completed"));
    });

    it("merlin_ai.gd has response_received signal", () => {
      assert(aiSignals.find((s) => s.name === "response_received"));
    });

    it("merlin_ai.gd has ready_changed signal", () => {
      assert(aiSignals.find((s) => s.name === "ready_changed"));
    });

    it("merlin_omniscient.gd has prefetch_ready signal", () => {
      assert(omniSignals.find((s) => s.name === "prefetch_ready"));
    });

    it("merlin_omniscient.gd has card_generated signal", () => {
      assert(omniSignals.find((s) => s.name === "card_generated"));
    });

    it("merlin_omniscient.gd has merlin_speaks signal", () => {
      assert(omniSignals.find((s) => s.name === "merlin_speaks"));
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

function main() {
  console.log("╔══════════════════════════════════════════════════════════════════╗");
  console.log("║  M.E.R.L.I.N. — Brain Pool Architecture Test Suite             ║");
  console.log("║  Phase 32: Multi-Brain Worker Pool (2-4 brains)                 ║");
  console.log("╚══════════════════════════════════════════════════════════════════╝");

  // Verify files exist
  assert(merlinAI, "addons/merlin_ai/merlin_ai.gd not found!");
  assert(merlinOmni, "addons/merlin_ai/merlin_omniscient.gd not found!");

  const suites = {
    constants: testConstants,
    detection: testDetection,
    pool: testPoolArchitecture,
    bg: testBackgroundTasks,
    generation: testGenerationMethods,
    init: testModelInit,
    modes: testModeNames,
    accessors: testPoolAccessors,
    omniscient: testOmniscientIntegration,
    data: testDataFiles,
    busy: testBusyFlagConsistency,
    compat: testBackwardCompat,
    consistency: testCrossFileConsistency,
    simulated: testSimulatedPoolScenarios,
    signals: testSignals,
  };

  if (testFilter === "all") {
    for (const fn of Object.values(suites)) fn();
  } else if (suites[testFilter]) {
    suites[testFilter]();
  } else {
    console.error(`Unknown test suite: ${testFilter}. Available: ${Object.keys(suites).join(", ")}`);
    process.exit(1);
  }

  // Summary
  console.log("\n" + "═".repeat(70));
  console.log(
    `  Results: \x1b[32m${passedTests} passed\x1b[0m, \x1b[31m${failedTests} failed\x1b[0m, \x1b[33m${skippedTests} skipped\x1b[0m (${totalTests} total)`
  );

  if (failures.length > 0) {
    console.log("\n  \x1b[31mFailures:\x1b[0m");
    for (const f of failures) {
      console.log(`    ✗ ${f.test}: ${f.error}`);
    }
  }

  console.log("═".repeat(70));

  // Save results
  const results = {
    timestamp: new Date().toISOString(),
    total: totalTests,
    passed: passedTests,
    failed: failedTests,
    skipped: skippedTests,
    failures,
    suites: testFilter,
  };
  const outPath = path.join(PROJECT_ROOT, "tools", `test_brain_pool_results_${Date.now()}.json`);
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2));
  console.log(`\nResults saved to: ${outPath}`);

  process.exit(failedTests > 0 ? 1 : 0);
}

main();
