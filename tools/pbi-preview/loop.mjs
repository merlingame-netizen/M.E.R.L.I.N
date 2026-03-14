/**
 * PBI Preview — Loop orchestrator.
 *
 * Chains: evaluate measures -> render HTML -> screenshot -> (optional) export PBIX.
 *
 * Usage:
 *   import { runIteration, exportPbix } from './loop.mjs';
 *   await runIteration('C:/path/to/Cockpit_SAT_ProPME', 1);
 *
 * CLI:
 *   node loop.mjs <reportProjectDir> [iteration] [outputDir]
 */

import { captureScreenshot } from './screenshot.mjs';
import { writeFileSync, existsSync, readdirSync } from 'fs';
import { resolve, join, basename } from 'path';

// ── Project structure discovery ─────────────────────────────────────────────

/**
 * Auto-discover .Report and .SemanticModel subfolders in a PBIP project dir.
 * @param {string} projectDir — e.g. C:/Users/.../Cockpit_SAT_ProPME
 * @returns {{ reportDir: string, modelDir: string, modelBimPath: string, reportJsonPath: string }}
 */
function discoverProject(projectDir) {
  const absDir = resolve(projectDir);
  if (!existsSync(absDir)) {
    throw new Error(`Project directory not found: ${absDir}`);
  }

  const entries = readdirSync(absDir);

  const reportFolder = entries.find(e => e.endsWith('.Report'));
  const modelFolder = entries.find(e => e.endsWith('.SemanticModel'));

  if (!reportFolder) {
    throw new Error(`No .Report folder found in: ${absDir}`);
  }
  if (!modelFolder) {
    throw new Error(`No .SemanticModel folder found in: ${absDir}`);
  }

  const reportDir = join(absDir, reportFolder);
  const modelDir = join(absDir, modelFolder);
  const modelBimPath = join(modelDir, 'model.bim');
  const reportJsonPath = join(reportDir, 'report.json');

  return { reportDir, modelDir, modelBimPath, reportJsonPath };
}

// ── Main iteration ──────────────────────────────────────────────────────────

/**
 * Run one preview iteration: evaluate -> render HTML -> screenshot.
 * @param {string} projectDir — PBIP project root
 * @param {number} iteration  — iteration number (for versioned filenames)
 * @param {string} [outputDir] — output directory (defaults to projectDir)
 * @returns {Promise<{ measuresPath: string, htmlPath: string, pngPath: string, measureCount: number }>}
 */
export async function runIteration(projectDir, iteration = 1, outputDir = null) {
  const outDir = outputDir ? resolve(outputDir) : resolve(projectDir);
  const { modelBimPath, reportJsonPath } = discoverProject(projectDir);

  console.log(`\n=== PBI Preview — Iteration ${iteration} ===\n`);

  // Step 1: Evaluate measures
  let measures = new Map();
  try {
    const { buildDataStore, evaluateAllMeasures } = await import('./dax-evaluator.mjs');
    const store = buildDataStore(modelBimPath);
    measures = evaluateAllMeasures(store);
  } catch (err) {
    console.warn(`  Measures: skipped (${err.message})`);
  }

  const measuresObj = Object.fromEntries(measures);
  const measuresPath = join(outDir, `measures_v${iteration}.json`);
  writeFileSync(measuresPath, JSON.stringify(measuresObj, null, 2), 'utf-8');
  console.log(`  Measures: ${measures.size} evaluated -> ${measuresPath}`);

  // Step 2: Render HTML
  let htmlPath = join(outDir, `preview_v${iteration}.html`);
  try {
    const { renderToHtml } = await import('./html-renderer.mjs');
    const html = renderToHtml(reportJsonPath, measures);
    writeFileSync(htmlPath, html, 'utf-8');
  } catch (err) {
    // Fallback: generate a minimal placeholder HTML
    const fallbackHtml = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>PBI Preview v${iteration}</title></head>
<body style="font-family:Segoe UI,sans-serif;padding:40px;background:#1a1a2e;color:#fff">
<h1>PBI Preview — Iteration ${iteration}</h1>
<p>Measures evaluated: ${measures.size}</p>
<pre>${JSON.stringify(measuresObj, null, 2).slice(0, 2000)}</pre>
<p style="color:#888">HTML renderer not available: ${err.message}</p>
</body></html>`;
    writeFileSync(htmlPath, fallbackHtml, 'utf-8');
    console.warn(`  HTML: fallback generated (${err.message})`);
  }
  console.log(`  HTML: ${htmlPath}`);

  // Step 3: Screenshot
  const pngPath = join(outDir, `preview_v${iteration}.png`);
  try {
    await captureScreenshot(htmlPath, pngPath);
    console.log(`  PNG: ${pngPath}`);
  } catch (err) {
    console.warn(`  PNG: skipped (${err.message})`);
  }

  return { measuresPath, htmlPath, pngPath, measureCount: measures.size };
}

// ── PBIX export ─────────────────────────────────────────────────────────────

/**
 * Generate a .pbix file from the PBIP project.
 * @param {string} projectDir — PBIP project root
 * @param {string} outputPath — path for the .pbix output
 * @returns {Promise<object>}
 */
export async function exportPbix(projectDir, outputPath) {
  const { reportDir } = discoverProject(projectDir);
  try {
    const genModule = await import(
      'file:///C:/Users/PGNK2128/OneDrive%20-%20orange.com/Bureau/Agents/Data/powerbi-dashboard-mcp/dist/tools/generate-pbix.js'
    );
    const result = genModule.generatePbix({ reportDir, outputPath: resolve(outputPath) });
    console.log(`  PBIX exported: ${outputPath}`);
    return result;
  } catch (err) {
    throw new Error(`PBIX export failed: ${err.message}`);
  }
}

// ── CLI entry point ─────────────────────────────────────────────────────────
const selfPath = new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1');
const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(selfPath);

if (isMain) {
  const [,, projectDir, iterationStr, outputDir] = process.argv;
  if (!projectDir) {
    console.error('Usage: node loop.mjs <reportProjectDir> [iteration] [outputDir]');
    process.exit(1);
  }
  const iteration = parseInt(iterationStr || '1', 10);

  runIteration(projectDir, iteration, outputDir || null)
    .then(result => {
      console.log('\n=== Done ===');
      console.log(JSON.stringify(result, null, 2));
    })
    .catch(err => {
      console.error(`Error: ${err.message}`);
      process.exit(1);
    });
}
