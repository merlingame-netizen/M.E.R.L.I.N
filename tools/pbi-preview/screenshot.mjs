/**
 * PBI Preview — Screenshot capture via Python Playwright subprocess.
 *
 * Playwright is installed as a Python package, so we shell out to a temp
 * Python script that drives Chromium headless.
 *
 * Usage:
 *   import { captureScreenshot } from './screenshot.mjs';
 *   await captureScreenshot('preview.html', 'preview.png');
 *
 * CLI:
 *   node screenshot.mjs <input.html> <output.png> [width] [height]
 */

import { execSync } from 'child_process';
import { existsSync, writeFileSync, unlinkSync } from 'fs';
import { resolve, basename } from 'path';
import { tmpdir } from 'os';
import { join } from 'path';

/**
 * Capture an HTML file to PNG using Python Playwright.
 * @param {string} htmlPath  — absolute path to the HTML file
 * @param {string} outputPng — absolute path for the output PNG
 * @param {{ width?: number, height?: number }} viewport — defaults 1280x760 (720 canvas + 40 title)
 * @returns {string} outputPng path on success
 */
export async function captureScreenshot(htmlPath, outputPng, viewport = {}) {
  const width = viewport.width || 1280;
  const height = viewport.height || 760;

  const absHtml = resolve(htmlPath).replace(/\\/g, '/');
  const absPng = resolve(outputPng).replace(/\\/g, '/');

  if (!existsSync(absHtml)) {
    throw new Error(`HTML file not found: ${absHtml}`);
  }

  const pyScript = `
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(viewport={"width": ${width}, "height": ${height}})
        page = await ctx.new_page()
        await page.goto("file:///${absHtml}")
        await page.wait_for_timeout(500)
        await page.screenshot(path=r"${absPng}", full_page=False)
        await browser.close()

asyncio.run(main())
`;

  const tmpPy = join(tmpdir(), `pbi_screenshot_${Date.now()}.py`);
  try {
    writeFileSync(tmpPy, pyScript, 'utf-8');
    // Try known Windows Python path first, then PATH fallbacks
    const pythonCmds = [
      'C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe',
      'python',
      'python3',
    ];
    let lastErr = null;
    for (const py of pythonCmds) {
      try {
        execSync(`"${py}" "${tmpPy}"`, { timeout: 30_000, stdio: 'pipe' });
        lastErr = null;
        break;
      } catch (e) {
        const msg = (e.stderr?.toString?.() || e.message || '').toLowerCase();
        if (msg.includes('n\'est pas reconnu') || msg.includes('not recognized') || msg.includes('not found') || msg.includes('enoent')) {
          lastErr = e;
          continue; // python not found, try next
        }
        throw e; // real execution error
      }
    }
    if (lastErr) throw new Error('Python not found. Tried: ' + pythonCmds.join(', '));
  } finally {
    try { unlinkSync(tmpPy); } catch { /* ignore */ }
  }

  if (!existsSync(absPng)) {
    throw new Error(`Screenshot was not created: ${absPng}`);
  }
  return absPng;
}

// ── CLI entry point ──────────────────────────────────────────────────────────
const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1'));

if (isMain) {
  const [,, inputHtml, outputPng, w, h] = process.argv;
  if (!inputHtml || !outputPng) {
    console.error('Usage: node screenshot.mjs <input.html> <output.png> [width] [height]');
    process.exit(1);
  }
  const viewport = {};
  if (w) viewport.width = parseInt(w, 10);
  if (h) viewport.height = parseInt(h, 10);

  captureScreenshot(inputHtml, outputPng, viewport)
    .then(p => console.log(`Screenshot saved: ${p}`))
    .catch(err => { console.error(`Error: ${err.message}`); process.exit(1); });
}
