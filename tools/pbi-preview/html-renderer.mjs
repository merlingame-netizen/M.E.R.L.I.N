/**
 * html-renderer.mjs — Generate HTML preview of a Power BI dashboard
 * Reads report.json (pbi-tools extracted) and renders visuals to static HTML.
 *
 * Export: parseVisualContainer, renderToHtml
 * CLI:    node html-renderer.mjs <report.json> <measures.json> <output.html>
 */

import { readFileSync, writeFileSync } from 'fs';
import { basename } from 'path';

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Strip PBI literal quotes: "'#FF7900'" → "#FF7900" */
function stripQuotes(val) {
  if (typeof val !== 'string') return val;
  return val.replace(/^'+|'+$/g, '');
}

/** Strip D suffix from PBI numeric literals: "40D" → 40, "0D" → 0 */
function stripD(val) {
  if (typeof val !== 'string') return Number(val) || 0;
  return Number(val.replace(/D$/i, '')) || 0;
}

/** Safely drill into nested object by dot-separated path */
function dig(obj, path) {
  const parts = path.split('.');
  let cur = obj;
  for (const p of parts) {
    if (cur == null) return undefined;
    cur = cur[p];
  }
  return cur;
}

/** Get a PBI literal value from an object property chain */
function pbiLiteral(obj) {
  return dig(obj, 'expr.Literal.Value');
}

/** Format a numeric value for display */
function formatValue(val) {
  if (val == null || val === '') return null;
  const n = Number(val);
  if (Number.isNaN(n)) return String(val);
  if (Number.isInteger(n)) return n.toLocaleString('fr-FR');
  return n.toLocaleString('fr-FR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
}

/** Escape HTML entities */
function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Parse Visual Container ───────────────────────────────────────────────────

/**
 * @param {object} vc — raw visual container from report.json
 * @returns {object} VisualDescriptor
 */
export function parseVisualContainer(vc) {
  const cfg = typeof vc.config === 'string' ? JSON.parse(vc.config) : vc.config;
  const sv = cfg.singleVisual || {};
  const type = sv.visualType || 'unknown';
  const objects = sv.objects || {};

  const base = {
    x: vc.x, y: vc.y,
    width: vc.width, height: vc.height,
    tabOrder: vc.tabOrder || 0,
    type,
  };

  if (type === 'shape') {
    const fillProps = objects.fill?.[0]?.properties || {};
    const lineProps = objects.line?.[0]?.properties || {};
    return {
      ...base,
      fillColor: stripQuotes(pbiLiteral(fillProps.fillColor?.solid?.color) || ''),
      fillTransparency: stripD(pbiLiteral(fillProps.transparency)),
      lineColor: stripQuotes(pbiLiteral(lineProps.lineColor?.solid?.color) || ''),
      lineWeight: stripD(pbiLiteral(lineProps.weight)),
      roundEdge: stripD(pbiLiteral(lineProps.roundEdge)),
    };
  }

  if (type === 'textbox') {
    const paraRaw = pbiLiteral(objects.general?.[0]?.properties?.paragraphs) || '[]';
    let paragraphs = [];
    try { paragraphs = JSON.parse(paraRaw); } catch { /* empty */ }
    return { ...base, paragraphs };
  }

  if (type === 'card') {
    const sel = sv.prototypeQuery?.Select?.[0] || {};
    const measureName = sel.Measure?.Property || sel.Column?.Property || '';
    const labelProps = objects.labels?.[0]?.properties || {};
    const labelColor = stripQuotes(pbiLiteral(labelProps.color?.solid?.color) || '#000000');
    const labelFontSize = stripD(pbiLiteral(labelProps.fontSize));
    const labelFontFamily = stripQuotes(pbiLiteral(labelProps.fontFamily) || 'Segoe UI');
    const bgTransparency = stripD(
      pbiLiteral(objects.background?.[0]?.properties?.transparency)
    );
    return {
      ...base,
      measureName,
      labelColor, labelFontSize, labelFontFamily,
      bgTransparency,
    };
  }

  if (type === 'slicer') {
    const sel = sv.prototypeQuery?.Select?.[0] || {};
    const fieldName = sel.Column?.Property || sel.Measure?.Property || '';
    const titleText = stripQuotes(
      pbiLiteral(objects.title?.[0]?.properties?.text) || fieldName
    );
    const headerColor = stripQuotes(
      pbiLiteral(objects.header?.[0]?.properties?.fontColor?.solid?.color) || '#FF7900'
    );
    return { ...base, fieldName, titleText, headerColor };
  }

  return base;
}

// ── Render Functions ─────────────────────────────────────────────────────────

function renderShape(v) {
  const opacity = 1 - (v.fillTransparency / 100);
  const border = v.lineWeight > 0
    ? `border: ${v.lineWeight}px solid ${v.lineColor};`
    : 'border: none;';
  const radius = v.roundEdge > 0 ? `border-radius: ${v.roundEdge}px;` : '';
  return `<div class="vc" style="left:${v.x}px;top:${v.y}px;width:${v.width}px;height:${v.height}px;`
    + `z-index:${v.tabOrder};background-color:${v.fillColor};opacity:${opacity};${border}${radius}"></div>`;
}

function renderTextbox(v) {
  const spans = (v.paragraphs || []).flatMap(para =>
    (para.textRuns || []).map(run => {
      const s = run.textStyle || {};
      const styles = [
        s.fontFamily ? `font-family:${s.fontFamily}` : '',
        s.fontSize ? `font-size:${s.fontSize}` : '',
        s.color ? `color:${s.color}` : '',
        s.fontWeight ? `font-weight:${s.fontWeight}` : '',
      ].filter(Boolean).join(';');
      return `<span style="${styles}">${esc(run.value || '')}</span>`;
    })
  );
  return `<div class="vc tb" style="left:${v.x}px;top:${v.y}px;width:${v.width}px;height:${v.height}px;`
    + `z-index:${v.tabOrder}">${spans.join('')}</div>`;
}

function renderCard(v, measureValues) {
  const raw = measureValues?.get(v.measureName);
  const display = raw != null ? formatValue(raw) : '(Vide)';
  const color = raw != null ? v.labelColor : '#999';
  const fontSize = v.labelFontSize || 14;
  return `<div class="vc card-vc" style="left:${v.x}px;top:${v.y}px;width:${v.width}px;height:${v.height}px;`
    + `z-index:${v.tabOrder};display:flex;align-items:center;justify-content:center;`
    + `background:transparent;" title="${esc(v.measureName)}">`
    + `<span style="font-size:${fontSize}px;color:${color};font-family:${v.labelFontFamily};font-weight:600">`
    + `${esc(display)}</span></div>`;
}

function renderSlicer(v) {
  return `<div class="vc slicer" style="left:${v.x}px;top:${v.y}px;width:${v.width}px;height:${v.height}px;`
    + `z-index:${v.tabOrder};background:#FFF;border:1px solid #CCC;border-radius:4px;overflow:hidden">`
    + `<div style="background:${v.headerColor};color:#FFF;padding:3px 8px;font-size:11px;font-weight:600">`
    + `${esc(v.titleText)}</div>`
    + `<div style="padding:4px 8px;font-size:12px;color:#666">&#9662; ${esc(v.fieldName)}</div></div>`;
}

function renderVisual(v, measureValues) {
  switch (v.type) {
    case 'shape': return renderShape(v);
    case 'textbox': return renderTextbox(v);
    case 'card': return renderCard(v, measureValues);
    case 'slicer': return renderSlicer(v);
    default: return `<div class="vc" style="left:${v.x}px;top:${v.y}px;width:${v.width}px;`
      + `height:${v.height}px;z-index:${v.tabOrder};border:1px dashed #CCC" `
      + `title="unknown: ${esc(v.type)}"></div>`;
  }
}

// ── Main Render ──────────────────────────────────────────────────────────────

/**
 * @param {string} reportJsonPath — path to report.json
 * @param {Map<string, number|string>} measureValues — measure name → value
 * @returns {string} complete HTML document
 */
export function renderToHtml(reportJsonPath, measureValues) {
  const report = JSON.parse(readFileSync(reportJsonPath, 'utf8'));
  const page = report.sections[0];
  const pageName = page.displayName || page.name || 'Untitled';
  const W = page.width || 1280;
  const H = page.height || 720;

  const vcs = (page.visualContainers || []).map(parseVisualContainer);
  vcs.sort((a, b) => a.tabOrder - b.tabOrder);

  const visuals = vcs.map(v => renderVisual(v, measureValues)).join('\n    ');

  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PBI Preview — ${esc(pageName)}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #1a1a1a; color: #fff;
           display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
    .title-bar { width: ${W}px; padding: 10px 16px; background: #141414;
                 border-bottom: 3px solid #FF7900; font-size: 13px; color: #ccc; }
    .title-bar strong { color: #FF7900; }
    .canvas { position: relative; width: ${W}px; height: ${H}px;
              background: #F0F0F0; overflow: hidden; margin: 0 auto; box-shadow: 0 4px 24px rgba(0,0,0,.4); }
    .vc { position: absolute; }
    .tb { display: flex; align-items: center; padding: 0 6px; overflow: hidden; white-space: nowrap; }
    .card-vc { pointer-events: auto; }
    .card-vc:hover { outline: 2px solid #FF7900; outline-offset: -1px; }
    .slicer:hover { border-color: #FF7900 !important; }
    .footer { width: ${W}px; padding: 6px 16px; font-size: 11px; color: #666; text-align: right; }
  </style>
</head>
<body>
  <div class="title-bar">
    <strong>PBI Preview</strong> — ${esc(pageName)} — v1
  </div>
  <div class="canvas">
    ${visuals}
  </div>
  <div class="footer">${vcs.length} visuals rendered</div>
</body>
</html>`;
}

// ── CLI ──────────────────────────────────────────────────────────────────────

const isMain = process.argv[1] && basename(process.argv[1]) === 'html-renderer.mjs';

if (isMain) {
  const [,, reportPath, measuresPath, outputPath] = process.argv;

  if (!reportPath || !measuresPath || !outputPath) {
    console.error('Usage: node html-renderer.mjs <report.json> <measures.json> <output.html>');
    process.exit(1);
  }

  const measureValues = new Map();
  try {
    const raw = JSON.parse(readFileSync(measuresPath, 'utf8'));
    if (Array.isArray(raw)) {
      for (const entry of raw) {
        if (entry.name && entry.value !== undefined) measureValues.set(entry.name, entry.value);
      }
    } else if (typeof raw === 'object') {
      for (const [k, v] of Object.entries(raw)) measureValues.set(k, v);
    }
  } catch (err) {
    console.error(`Warning: could not parse measures file: ${err.message}`);
  }

  const html = renderToHtml(reportPath, measureValues);
  writeFileSync(outputPath, html, 'utf8');

  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  const count = report.sections[0].visualContainers?.length || 0;
  console.log(`Generated: ${outputPath} (${count} visuals)`);
}
