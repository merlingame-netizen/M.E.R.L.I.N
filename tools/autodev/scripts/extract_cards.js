// Script: extract FASTROUTE_TEMPLATES from CardSystem.ts to public/data/cards.json
// Run: node tools/autodev/scripts/extract_cards.js

const fs = require('fs');
const path = require('path');

const ROOT = 'C:/Users/PGNK2128/Godot-MCP';
const INPUT = path.join(ROOT, 'web-demo/src/game/CardSystem.ts');
const OUTPUT_DIR = path.join(ROOT, 'web-demo/public/data');
const OUTPUT = path.join(OUTPUT_DIR, 'cards.json');

const content = fs.readFileSync(INPUT, 'utf8');

// Find the array literal after const FASTROUTE_TEMPLATES: = [
const declStart = content.indexOf('const FASTROUTE_TEMPLATES:');
const eqSign = content.indexOf('= [', declStart);
const arrayStart = eqSign + 2; // points to '['

let depth = 0;
let arrayEnd = -1;
for (let i = arrayStart; i < content.length; i++) {
  if (content[i] === '[') depth++;
  else if (content[i] === ']') {
    depth--;
    if (depth === 0) { arrayEnd = i; break; }
  }
}

if (arrayEnd === -1) {
  console.error('Could not find end of FASTROUTE_TEMPLATES array');
  process.exit(1);
}

let tsArray = content.slice(arrayStart, arrayEnd + 1);

// Step 1: Remove single-line comments
tsArray = tsArray.replace(/\/\/[^\n]*/g, '');

// Step 2: Convert TS object literal single-quote strings to JSON double-quote strings
// We use a state machine to handle this reliably
function tsLiteralToJson(src) {
  let result = '';
  let i = 0;
  while (i < src.length) {
    const ch = src[i];
    if (ch === "'") {
      // Start of single-quoted string: collect until closing unescaped '
      let str = '';
      i++;
      while (i < src.length) {
        if (src[i] === '\\' && src[i + 1] === "'") {
          // Escaped single quote in TS -> literal '
          str += "'";
          i += 2;
        } else if (src[i] === "\\") {
          // Other escape: keep as-is
          str += src[i] + src[i + 1];
          i += 2;
        } else if (src[i] === "'") {
          // End of string
          i++;
          break;
        } else {
          str += src[i];
          i++;
        }
      }
      // Escape double quotes inside the string for JSON
      str = str.replace(/"/g, '\\"');
      result += '"' + str + '"';
    } else {
      result += ch;
      i++;
    }
  }
  return result;
}

tsArray = tsLiteralToJson(tsArray);

// Step 3: Quote unquoted object keys (word chars followed by colon, not inside strings)
// This is safe after Step 2 since all strings are now double-quoted
tsArray = tsArray.replace(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*:)/g, '$1"$2"$3');

// Step 4: Remove trailing commas before } or ]
tsArray = tsArray.replace(/,(\s*[}\]])/g, '$1');

// Step 5: Parse and validate
let parsed;
try {
  parsed = JSON.parse(tsArray);
} catch (e) {
  console.error('JSON parse error:', e.message.slice(0, 300));
  // Write debug output for inspection
  fs.writeFileSync(path.join(ROOT, 'tools/autodev/scripts/debug_cards.txt'), tsArray.slice(0, 2000));
  process.exit(1);
}

console.log('Parsed OK:', parsed.length, 'templates');

// Validate structure
let issues = 0;
for (let idx = 0; idx < parsed.length; idx++) {
  const t = parsed[idx];
  if (!t.narrative || typeof t.narrative !== 'string') {
    console.warn('  Template', idx, 'missing narrative');
    issues++;
  }
  if (!Array.isArray(t.options) || t.options.length !== 3) {
    console.warn('  Template', idx, 'bad options count:', t.options?.length);
    issues++;
  }
}
if (issues === 0) {
  console.log('Validation OK: all templates have narrative + 3 options');
} else {
  console.warn('Validation found', issues, 'issues');
}

// Write output
fs.mkdirSync(OUTPUT_DIR, { recursive: true });
fs.writeFileSync(OUTPUT, JSON.stringify(parsed, null, 2), 'utf8');
const stat = fs.statSync(OUTPUT);
console.log('Written:', OUTPUT);
console.log('Size:', Math.round(stat.size / 1024), 'KB (', stat.size, 'bytes)');
