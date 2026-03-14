import { readFileSync } from "fs";

function parseDatatable(expression) {
  // DATATABLE format: header columns, then { \n {"row1"}, {"row2"}, ... }
  // Look for "{{ " (double brace) or "{\n{" (brace + newline + brace)
  let headerEnd = expression.indexOf("{{");
  if (headerEnd === -1) {
    // Try brace-newline-brace pattern: { \n {"...
    const braceNewline = expression.search(/\{\s*\n\s*\{/);
    if (braceNewline === -1) return [];
    headerEnd = braceNewline;
  }
  const header = expression.substring(0, headerEnd).trim();

  // Extract column definitions: pairs of ("name", TYPE)
  const cols = [];
  const colRegex = /"([^"]+)",\s*(STRING|INTEGER|DOUBLE|BOOLEAN)/g;
  let m;
  while ((m = colRegex.exec(header)) !== null) {
    cols.push({ name: m[1], type: m[2] });
  }
  if (cols.length === 0) return [];
  const dataStart = headerEnd + 1; // skip first {
  // Find the closing of the outer data block: last "}" before final ")"
  let dataEnd = expression.lastIndexOf("}}");
  if (dataEnd === -1) {
    // Try last "}" (for {\n{...}\n} pattern)
    dataEnd = expression.lastIndexOf("}");
    if (dataEnd === -1) return [];
  }
  const dataBlock = expression.substring(dataStart, dataEnd + 1);
  const rows = [];
  let depth = 0;
  let rowStart = -1;
  for (let i = 0; i < dataBlock.length; i++) {
    if (dataBlock[i] === "{") {
      if (depth === 0) rowStart = i + 1;
      depth++;
    } else if (dataBlock[i] === "}") {
      depth--;
      if (depth === 0 && rowStart !== -1) {
        rows.push(dataBlock.substring(rowStart, i));
        rowStart = -1;
      }
    }
  }

  return rows.map((rowStr) => {
    const values = tokenizeRow(rowStr);
    const record = {};
    for (let i = 0; i < cols.length && i < values.length; i++) {
      record[cols[i].name] = castValue(values[i], cols[i].type);
    }
    return record;
  });
}
function tokenizeRow(rowStr) {
  const values = [];
  let i = 0;
  const s = rowStr.trim();
  while (i < s.length) {
    if (s[i] === " " || s[i] === ",") { i++; continue; }
    if (s[i] === '"') {
      let end = i + 1;
      while (end < s.length) {
        if (s[end] === '"' && s[end + 1] !== '"') break;
        if (s[end] === '"' && s[end + 1] === '"') end++;
        end++;
      }
      values.push(s.substring(i + 1, end).replace(/""/g, '"'));
      i = end + 1;
    } else if (s.substring(i, i + 7) === "BLANK()") {
      values.push("BLANK()");
      i += 7;
    } else {
      let end = i;
      while (end < s.length && s[end] !== ",") end++;
      values.push(s.substring(i, end).trim());
      i = end;
    }
  }
  return values;
}
function castValue(raw, type) {
  if (raw === "BLANK()" || raw === "" || raw === undefined) return null;
  switch (type) {
    case "STRING": return String(raw);
    case "INTEGER": return parseInt(raw, 10);
    case "DOUBLE": return parseFloat(raw);
    case "BOOLEAN": return raw.toLowerCase() === "true";
    default: return raw;
  }
}

function buildDataStore(modelBimPath) {
  const model = JSON.parse(readFileSync(modelBimPath, "utf8"));
  const tables = new Map();
  const measures = new Map();

  for (const table of model.model.tables) {
    const calcPart = table.partitions?.find(
      (p) => p.source?.type === "calculated" && p.source.expression?.includes("DATATABLE")
    );
    if (calcPart) {
      tables.set(table.name, parseDatatable(calcPart.source.expression));
    }
    for (const m of table.measures || []) {
      measures.set(m.name, m.expression);
    }
  }

  return { tables, measures };
}

function round2(v) {
  if (v === null || v === undefined || isNaN(v)) return null;
  return Math.round(v * 100) / 100;
}

function aggregate(fn, rows, col) {
  const vals = rows.map((r) => r[col]).filter((v) => v !== null && v !== undefined);
  if (vals.length === 0) return null;
  if (fn === "AVERAGE") return round2(vals.reduce((a, b) => a + b, 0) / vals.length);
  if (fn === "SUM") return round2(vals.reduce((a, b) => a + b, 0));
  return null;
}

function evalSimpleAgg(expr, tables) {
  const m = expr.match(/^(AVERAGE|SUM)\((\w+)\[(\w+)\]\)$/);
  if (!m) return undefined;
  const [, fn, table, col] = m;
  const rows = tables.get(table);
  if (!rows) return null;
  return aggregate(fn, rows, col);
}

function filterRows(rows, filters) {
  return rows.filter((r) => filters.every((f) => r[f.col] === f.value));
}

function parseCalculateFilters(argsStr) {
  const filters = [];
  const re = /(\w+)\[(\w+)\]\s*=\s*"([^"]+)"/g;
  let m;
  while ((m = re.exec(argsStr)) !== null) {
    filters.push({ table: m[1], col: m[2], value: m[3] });
  }
  return filters;
}

function evaluateAllMeasures(store, defaultMode = "Transactionnel") {
  const { tables, measures } = store;
  const results = new Map();
  const cache = new Map();

  function evalMeasure(name, filteredTables) {
    const effective = filteredTables || tables;
    const cacheKey = name + "|" + [...effective].map(([k, v]) => `${k}:${v.length}`).join(",");
    if (cache.has(cacheKey)) return cache.get(cacheKey);

    const expr = measures.get(name);
    if (!expr) { cache.set(cacheKey, null); return null; }
    const result = evalExpression(expr, effective);
    cache.set(cacheKey, result);
    return result;
  }

  function evalExpression(expr, effective) {
    const clean = expr.replace(/\n/g, " ").replace(/\s+/g, " ").trim();

    // Pattern A: Simple aggregation
    const simpleResult = evalSimpleAgg(clean, effective);
    if (simpleResult !== undefined) return simpleResult;

    // Pattern B: SELECTEDVALUE + SWITCH
    if (clean.includes("SELECTEDVALUE") && clean.includes("SWITCH")) {
      return evalSwitchMode(clean, effective);
    }

    // Pattern D: VAR v = AGG(...) RETURN IF(v > 0, ... FORMAT ...)
    if (clean.includes("FORMAT(v,")) {
      return evalFormatArrow(clean, effective);
    }

    // Pattern C: CALCULATE([Measure], filters...)
    const calcMatch = clean.match(/^CALCULATE\(\[(\w+)\],\s*(.+)\)$/);
    if (calcMatch) {
      const [, measureRef, filtersStr] = calcMatch;
      const filters = parseCalculateFilters(filtersStr);
      const newTables = new Map(effective);
      const grouped = {};
      for (const f of filters) {
        if (!grouped[f.table]) grouped[f.table] = [];
        grouped[f.table].push(f);
      }
      for (const [tbl, tblFilters] of Object.entries(grouped)) {
        const rows = effective.get(tbl) || [];
        newTables.set(tbl, filterRows(rows, tblFilters));
      }
      return evalMeasure(measureRef, newTables);
    }

    return null;
  }

  function evalSwitchMode(clean, effective) {
    const switchMatch = clean.match(/SWITCH\(\s*SelectedMode,\s*(.+)\)/);
    if (!switchMatch) return null;
    const branches = switchMatch[1];
    const branchRe = /"([^"]+)",\s*((?:AVERAGE|SUM)\(\w+\[\w+\]\))/g;
    let m;
    while ((m = branchRe.exec(branches)) !== null) {
      if (m[1] === defaultMode) return evalSimpleAgg(m[2], effective);
    }
    const allAggs = [...branches.matchAll(/((?:AVERAGE|SUM)\(\w+\[\w+\]\))/g)];
    if (allAggs.length > 0) return evalSimpleAgg(allAggs[allAggs.length - 1][1], effective);
    return null;
  }

  function evalFormatArrow(clean, effective) {
    const varMatch = clean.match(/VAR v = ((?:AVERAGE|SUM)\(\w+\[\w+\]\))/);
    if (!varMatch) return null;
    const v = evalSimpleAgg(varMatch[1], effective);
    if (v === null) return null;
    const fmt = Math.round(v);
    if (v > 0) return `\u25B2 +${fmt} pts`;
    if (v < 0) return `\u25BC ${fmt} pts`;
    return "= 0 pts";
  }

  for (const [name] of measures) {
    results.set(name, evalMeasure(name, null));
  }
  return results;
}

export { parseDatatable, buildDataStore, evaluateAllMeasures };

const isMain = process.argv[1] && (
  process.argv[1].replace(/\\/g, "/").endsWith("dax-evaluator.mjs")
);

if (isMain) {
  const modelPath = process.argv[2];
  if (!modelPath) {
    console.error("Usage: node dax-evaluator.mjs <model.bim path>");
    process.exit(1);
  }
  const store = buildDataStore(modelPath);
  const tableInfo = [...store.tables].map(([k, v]) => `${k} (${v.length} rows)`).join(", ");
  console.log(`Loaded ${store.tables.size} tables: ${tableInfo}`);
  console.log(`Found ${store.measures.size} measures`);
  const results = evaluateAllMeasures(store);
  const output = {};
  for (const [k, v] of results) output[k] = v;
  console.log(JSON.stringify(output, null, 2));
}
