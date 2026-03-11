"""DBeaver/EDH Hive adapter — CLI wrapper for Knox HTTPS queries via hive-driver (Node.js ESM).

Key constraints (from production experience on EDH/BCV):
  - COUNT / GROUP BY / DISTINCT in HiveQL FAIL with Tez (return code 1) — never used here.
  - All aggregation is done client-side in Python after raw row extraction.
  - LIMIT is always injected if absent (default 100, configurable).
  - Connection via Knox HTTPS takes 47-90 s — subprocess timeout is 120 s.
  - The hive-driver is a Node.js ESM module; the adapter writes a temp .mjs script,
    runs it with node, parses JSON from stdout, then deletes the temp file.
  - list-connections / list-tables use offline DBeaverConfigParser (no network call).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

# ── Constants ─────────────────────────────────────────────────────────────────

_DBEAVER_MCP_DIR = Path(
    "C:/Users/PGNK2128/AppData/Roaming/npm/node_modules/dbeaver-mcp-server"
)
_CONFIG_PARSER_ESM = _DBEAVER_MCP_DIR / "dist" / "config-parser.js"
_INDEX_ESM = _DBEAVER_MCP_DIR / "dist" / "index.js"

_DEFAULT_CONNECTION = "EDH_PRODv2"
_DEFAULT_LIMIT = 100
_PROFILE_LIMIT = 500
_NODE_TIMEOUT = 120  # seconds — EDH Knox is slow

# Forbidden HiveQL aggregation patterns that cause Tez crashes
_TEZ_FORBIDDEN = re.compile(
    r"\b(COUNT\s*\(|GROUP\s+BY\b|DISTINCT\b)",
    re.IGNORECASE,
)

# ── Node.js script templates ──────────────────────────────────────────────────

# Offline config reader — no network calls, parses DBeaver workspace XML.
_TMPL_LIST_CONNECTIONS = """\
import {{ DBeaverConfigParser }} from 'file:///{config_parser}';

async function main() {{
  const parser = new DBeaverConfigParser();
  const connections = await parser.getConnections();
  if (!connections) {{
    console.log(JSON.stringify({{ error: 'No connections found' }}));
    process.exit(1);
  }}
  // connections is a Map or object — normalise to array
  const out = [];
  for (const [id, cfg] of Object.entries(connections)) {{
    out.push({{ id, name: cfg.name || id, driver: cfg.driver || 'unknown', url: cfg.url || '' }});
  }}
  console.log(JSON.stringify({{ connections: out }}));
}}
main().catch(e => {{ console.error(e.message || e); process.exit(1); }});
"""

# Offline config reader for a single connection details.
_TMPL_LIST_TABLES = """\
import {{ DBeaverConfigParser }} from 'file:///{config_parser}';
import {{ createRequire }} from 'module';

const require = createRequire('file:///{index_esm}');

const CONNECTION_ID = '{connection}';
const DATABASE = '{database}';

async function main() {{
  const parser = new DBeaverConfigParser();
  const conn = await parser.getConnection(CONNECTION_ID);
  if (!conn) {{
    console.log(JSON.stringify({{ error: 'Connection not found: ' + CONNECTION_ID }}));
    process.exit(1);
  }}

  const hive = require('hive-driver');
  const {{ TCLIService, TCLIService_types }} = hive.thrift;
  const client = new hive.HiveClient(TCLIService, TCLIService_types);
  const utils = new hive.HiveUtils(TCLIService_types);

  const url = conn.url || '';
  const hostMatch = url.match(/hive2:\\/\\/([^:\\/]+):?(\\d+)?/);
  const host = hostMatch ? hostMatch[1] : 'localhost';
  const port = hostMatch ? parseInt(hostMatch[2] || '443') : 443;
  const httpPathMatch = url.match(/httpPath=([^;]+)/);
  const httpPath = httpPathMatch ? '/' + httpPathMatch[1] : '/';
  const user = conn.user || '';
  const password = conn.properties?.password || '';

  try {{
    await client.connect(
      {{ host, port, options: {{ path: httpPath, https: true }} }},
      new hive.connections.HttpConnection(),
      new hive.auth.PlainHttpAuthentication({{ username: user, password }})
    );
    const session = await client.openSession({{
      client_protocol: TCLIService_types.TProtocolVersion.HIVE_CLI_SERVICE_PROTOCOL_V8,
      username: user, password
    }});
    const op = await session.executeStatement(
      'SHOW TABLES IN ' + DATABASE,
      {{ runAsync: true }}
    );
    let ready = false, attempts = 0;
    while (!ready && attempts < 90) {{
      const status = await op.status();
      if (status.operationState === TCLIService_types.TOperationState.FINISHED_STATE) {{
        ready = true;
      }} else if (status.operationState === TCLIService_types.TOperationState.ERROR_STATE) {{
        console.log(JSON.stringify({{ error: status.errorMessage || 'Hive error' }}));
        await op.close(); await session.close(); await client.close();
        process.exit(1);
      }} else {{
        attempts++;
        await new Promise(r => setTimeout(r, 2000));
      }}
    }}
    await utils.fetchAll(op);
    const result = await utils.getResult(op);
    const rows = result.getValue ? result.getValue() : [];
    await op.close(); await session.close(); await client.close();
    const tables = rows.map(r => Object.values(r)[0]);
    console.log(JSON.stringify({{ tables, count: tables.length, database: DATABASE }}));
  }} catch (e) {{
    try {{ await client.close(); }} catch {{}}
    console.log(JSON.stringify({{ error: (e.message || String(e)).substring(0, 300) }}));
    process.exit(1);
  }}
}}
main().catch(e => {{ console.error(e.message || e); process.exit(1); }});
"""

_TMPL_DESCRIBE = """\
import {{ DBeaverConfigParser }} from 'file:///{config_parser}';
import {{ createRequire }} from 'module';

const require = createRequire('file:///{index_esm}');

const CONNECTION_ID = '{connection}';
const TABLE = '{table}';

async function main() {{
  const parser = new DBeaverConfigParser();
  const conn = await parser.getConnection(CONNECTION_ID);
  if (!conn) {{
    console.log(JSON.stringify({{ error: 'Connection not found: ' + CONNECTION_ID }}));
    process.exit(1);
  }}

  const hive = require('hive-driver');
  const {{ TCLIService, TCLIService_types }} = hive.thrift;
  const client = new hive.HiveClient(TCLIService, TCLIService_types);
  const utils = new hive.HiveUtils(TCLIService_types);

  const url = conn.url || '';
  const hostMatch = url.match(/hive2:\\/\\/([^:\\/]+):?(\\d+)?/);
  const host = hostMatch ? hostMatch[1] : 'localhost';
  const port = hostMatch ? parseInt(hostMatch[2] || '443') : 443;
  const httpPathMatch = url.match(/httpPath=([^;]+)/);
  const httpPath = httpPathMatch ? '/' + httpPathMatch[1] : '/';
  const user = conn.user || '';
  const password = conn.properties?.password || '';

  try {{
    await client.connect(
      {{ host, port, options: {{ path: httpPath, https: true }} }},
      new hive.connections.HttpConnection(),
      new hive.auth.PlainHttpAuthentication({{ username: user, password }})
    );
    const session = await client.openSession({{
      client_protocol: TCLIService_types.TProtocolVersion.HIVE_CLI_SERVICE_PROTOCOL_V8,
      username: user, password
    }});
    const op = await session.executeStatement(
      'DESCRIBE ' + TABLE,
      {{ runAsync: true }}
    );
    let ready = false, attempts = 0;
    while (!ready && attempts < 90) {{
      const status = await op.status();
      if (status.operationState === TCLIService_types.TOperationState.FINISHED_STATE) {{
        ready = true;
      }} else if (status.operationState === TCLIService_types.TOperationState.ERROR_STATE) {{
        console.log(JSON.stringify({{ error: status.errorMessage || 'Hive error' }}));
        await op.close(); await session.close(); await client.close();
        process.exit(1);
      }} else {{
        attempts++;
        await new Promise(r => setTimeout(r, 2000));
      }}
    }}
    await utils.fetchAll(op);
    const result = await utils.getResult(op);
    const rows = result.getValue ? result.getValue() : [];
    await op.close(); await session.close(); await client.close();
    // rows: [{{ col_name, data_type, comment }}, ...]
    const columns = rows.map(r => {{
      const vals = Object.values(r);
      return {{ name: vals[0], type: vals[1], comment: vals[2] || '' }};
    }}).filter(c => c.name && !c.name.startsWith('#'));
    console.log(JSON.stringify({{ table: TABLE, columns, column_count: columns.length }}));
  }} catch (e) {{
    try {{ await client.close(); }} catch {{}}
    console.log(JSON.stringify({{ error: (e.message || String(e)).substring(0, 300) }}));
    process.exit(1);
  }}
}}
main().catch(e => {{ console.error(e.message || e); process.exit(1); }});
"""

_TMPL_QUERY = """\
import {{ DBeaverConfigParser }} from 'file:///{config_parser}';
import {{ createRequire }} from 'module';

const require = createRequire('file:///{index_esm}');

const CONNECTION_ID = '{connection}';
const QUERY = {sql_json};

async function main() {{
  const parser = new DBeaverConfigParser();
  const conn = await parser.getConnection(CONNECTION_ID);
  if (!conn) {{
    console.log(JSON.stringify({{ error: 'Connection not found: ' + CONNECTION_ID }}));
    process.exit(1);
  }}

  const hive = require('hive-driver');
  const {{ TCLIService, TCLIService_types }} = hive.thrift;
  const client = new hive.HiveClient(TCLIService, TCLIService_types);
  const utils = new hive.HiveUtils(TCLIService_types);

  const url = conn.url || '';
  const hostMatch = url.match(/hive2:\\/\\/([^:\\/]+):?(\\d+)?/);
  const host = hostMatch ? hostMatch[1] : 'localhost';
  const port = hostMatch ? parseInt(hostMatch[2] || '443') : 443;
  const httpPathMatch = url.match(/httpPath=([^;]+)/);
  const httpPath = httpPathMatch ? '/' + httpPathMatch[1] : '/';
  const user = conn.user || '';
  const password = conn.properties?.password || '';

  const t0 = Date.now();
  try {{
    await client.connect(
      {{ host, port, options: {{ path: httpPath, https: true }} }},
      new hive.connections.HttpConnection(),
      new hive.auth.PlainHttpAuthentication({{ username: user, password }})
    );
    const session = await client.openSession({{
      client_protocol: TCLIService_types.TProtocolVersion.HIVE_CLI_SERVICE_PROTOCOL_V8,
      username: user, password
    }});
    const op = await session.executeStatement(QUERY, {{ runAsync: true }});
    let ready = false, attempts = 0;
    while (!ready && attempts < 180) {{
      const status = await op.status();
      if (status.operationState === TCLIService_types.TOperationState.FINISHED_STATE) {{
        ready = true;
      }} else if (status.operationState === TCLIService_types.TOperationState.ERROR_STATE) {{
        const errMsg = status.errorMessage || 'Unknown error';
        console.log(JSON.stringify({{ error: errMsg.substring(0, 300) }}));
        await op.close(); await session.close(); await client.close();
        process.exit(1);
      }} else {{
        attempts++;
        await new Promise(r => setTimeout(r, 2000));
      }}
    }}
    if (!ready) {{
      await op.close(); await session.close(); await client.close();
      console.log(JSON.stringify({{ error: 'Query timed out (360 s)' }}));
      process.exit(1);
    }}
    await utils.fetchAll(op);
    const result = await utils.getResult(op);
    const rows = result.getValue ? result.getValue() : [];
    await op.close(); await session.close(); await client.close();
    const duration_s = Math.round((Date.now() - t0) / 1000);
    console.log(JSON.stringify({{ rows, count: rows.length, duration_s }}));
  }} catch (e) {{
    try {{ await client.close(); }} catch {{}}
    console.log(JSON.stringify({{ error: (e.message || String(e)).substring(0, 300) }}));
    process.exit(1);
  }}
}}
main().catch(e => {{ console.error(e.message || e); process.exit(1); }});
"""


# ── Adapter ───────────────────────────────────────────────────────────────────


class DBeaverAdapter(BaseAdapter):
    """
    CLI adapter for DBeaver / EDH Hive queries.

    Execution model:
      1. A temporary .mjs script is written to the system temp directory.
      2. The script is executed via node with a 120-second timeout.
      3. JSON output is parsed from stdout; the temp file is always deleted.

    Aggregation rules (Tez constraint):
      - COUNT / GROUP BY / DISTINCT are forbidden in HiveQL.
      - The `profile` action retrieves raw rows and computes stats in Python.
    """

    def __init__(self) -> None:
        super().__init__("dbeaver")

    # ── Public interface ──────────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "list-connections": "List configured DBeaver connections (offline, no network)",
            "list-tables": "List tables in a database (kwargs: connection=EDH_PRODv2, database=prod_app_bcv_vm_v)",
            "describe": "Describe table schema (kwargs: connection, table=schema.table)",
            "query": "Execute SELECT query with LIMIT (kwargs: connection, sql=..., limit=100)",
            "profile": "Profile table: sample rows + client-side column stats (kwargs: connection, table, limit=500)",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "list-connections": self._list_connections,
            "list-tables": self._list_tables,
            "describe": self._describe,
            "query": self._query,
            "profile": self._profile,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError
        return handler(kwargs)

    # ── Actions ───────────────────────────────────────────────────────────────

    def _list_connections(self, kwargs: dict) -> dict:
        """Parse DBeaver config offline — no Hive network call."""
        if not self._check_dbeaver_mcp():
            return self.error(
                f"dbeaver-mcp-server not found at: {_DBEAVER_MCP_DIR}\n"
                "Install it with: npm install -g dbeaver-mcp-server"
            )
        script = _TMPL_LIST_CONNECTIONS.format(
            config_parser=_fwd(_CONFIG_PARSER_ESM),
        )
        result = self._run_node_script(script, label="list-connections")
        if "error" in result:
            return self.error(result["error"])
        return self.ok(result)

    def _list_tables(self, kwargs: dict) -> dict:
        if not self._check_dbeaver_mcp():
            return self._dbeaver_missing_error()
        connection = kwargs.get("connection", _DEFAULT_CONNECTION)
        database = kwargs.get("database")
        if not database:
            return self.error("Missing required argument: database (e.g. database=prod_app_bcv_vm_v)")
        self.log(f"Listing tables in {database} via {connection} (Knox ~47-90s connect)…")
        script = _TMPL_LIST_TABLES.format(
            config_parser=_fwd(_CONFIG_PARSER_ESM),
            index_esm=_fwd(_INDEX_ESM),
            connection=connection,
            database=database,
        )
        result = self._run_node_script(script, label="list-tables")
        if "error" in result:
            return self.error(result["error"])
        return self.ok(result)

    def _describe(self, kwargs: dict) -> dict:
        if not self._check_dbeaver_mcp():
            return self._dbeaver_missing_error()
        connection = kwargs.get("connection", _DEFAULT_CONNECTION)
        table = kwargs.get("table")
        if not table:
            return self.error("Missing required argument: table (e.g. table=schema.table_name)")
        self.log(f"Describing {table} via {connection}…")
        script = _TMPL_DESCRIBE.format(
            config_parser=_fwd(_CONFIG_PARSER_ESM),
            index_esm=_fwd(_INDEX_ESM),
            connection=connection,
            table=table,
        )
        result = self._run_node_script(script, label="describe")
        if "error" in result:
            return self.error(result["error"])
        return self.ok(result)

    def _query(self, kwargs: dict) -> dict:
        if not self._check_dbeaver_mcp():
            return self._dbeaver_missing_error()
        connection = kwargs.get("connection", _DEFAULT_CONNECTION)
        sql = kwargs.get("sql")
        if not sql:
            return self.error("Missing required argument: sql")

        # Guard: reject aggregation that breaks Tez
        forbidden_match = _TEZ_FORBIDDEN.search(sql)
        if forbidden_match:
            return self.error(
                f"Forbidden HiveQL pattern detected: '{forbidden_match.group()}'. "
                "COUNT / GROUP BY / DISTINCT cause Tez crashes on EDH. "
                "Use action=profile for aggregation (computed client-side in Python), "
                "or remove the aggregation and set a LIMIT."
            )

        # Auto-inject LIMIT if absent
        limit = int(kwargs.get("limit", _DEFAULT_LIMIT))
        sql = _ensure_limit(sql, limit)

        self.log(f"Executing query via {connection} (Knox ~47-90s connect)…")
        self.log(f"SQL: {sql[:200]}")

        script = _TMPL_QUERY.format(
            config_parser=_fwd(_CONFIG_PARSER_ESM),
            index_esm=_fwd(_INDEX_ESM),
            connection=connection,
            sql_json=json.dumps(sql),  # safe JS string literal
        )
        result = self._run_node_script(script, label="query")
        if "error" in result:
            return self.error(result["error"])
        return self.ok(result)

    def _profile(self, kwargs: dict) -> dict:
        """
        Profile a table:
          1. Fetch up to `limit` rows via a raw SELECT *.
          2. Compute column-level stats in Python (no HiveQL aggregation).

        Stats per column: null_count, unique_count, top_5_values, min, max.
        """
        if not self._check_dbeaver_mcp():
            return self._dbeaver_missing_error()
        connection = kwargs.get("connection", _DEFAULT_CONNECTION)
        table = kwargs.get("table")
        if not table:
            return self.error("Missing required argument: table")
        limit = int(kwargs.get("limit", _PROFILE_LIMIT))

        self.log(f"Profiling {table}: fetching up to {limit} rows…")

        # Step 1: fetch raw rows
        sql = f"SELECT * FROM {table} LIMIT {limit}"
        script = _TMPL_QUERY.format(
            config_parser=_fwd(_CONFIG_PARSER_ESM),
            index_esm=_fwd(_INDEX_ESM),
            connection=connection,
            sql_json=json.dumps(sql),
        )
        result = self._run_node_script(script, label="profile-fetch")
        if "error" in result:
            return self.error(f"Row fetch failed: {result['error']}")

        rows: list[dict] = result.get("rows", [])
        row_count = len(rows)
        self.log(f"Fetched {row_count} rows. Computing stats client-side…")

        if not rows:
            return self.ok({"table": table, "row_count": 0, "columns": [], "warning": "No rows returned."})

        # Step 2: client-side stats (no HiveQL)
        column_names: list[str] = list(rows[0].keys())
        column_stats: list[dict] = []

        for col in column_names:
            values = [row.get(col) for row in rows]
            null_count = sum(1 for v in values if v is None or v == "" or str(v).lower() == "null")
            non_null = [v for v in values if v is not None and v != "" and str(v).lower() != "null"]
            unique_count = len(set(str(v) for v in non_null))

            # top 5 most frequent values (client-side, no GROUP BY)
            counter = Counter(str(v) for v in non_null)
            top_5 = [{"value": v, "count": c} for v, c in counter.most_common(5)]

            # min / max only for comparable scalars
            min_val: Any = None
            max_val: Any = None
            if non_null:
                try:
                    numeric = [float(v) for v in non_null]
                    min_val = min(numeric)
                    max_val = max(numeric)
                except (ValueError, TypeError):
                    try:
                        sorted_vals = sorted(str(v) for v in non_null)
                        min_val = sorted_vals[0]
                        max_val = sorted_vals[-1]
                    except Exception:
                        pass

            column_stats.append({
                "column": col,
                "null_count": null_count,
                "null_pct": round(null_count * 100 / row_count, 1),
                "unique_count": unique_count,
                "top_5": top_5,
                "min": min_val,
                "max": max_val,
            })

        return self.ok({
            "table": table,
            "row_count": row_count,
            "column_count": len(column_names),
            "sampled_limit": limit,
            "columns": column_stats,
            "note": (
                "Stats computed client-side on a sample. "
                "Aggregation in HiveQL is disabled (Tez constraint)."
            ),
        })

    # ── Node.js execution ─────────────────────────────────────────────────────

    def _run_node_script(self, script_content: str, label: str) -> dict:
        """
        Write script_content to a temp .mjs file, execute with node,
        parse JSON from stdout, delete the temp file.

        Returns the parsed dict on success, or {"error": "..."} on failure.
        """
        node_exe = _find_node()
        if not node_exe:
            return {"error": "node executable not found. Install Node.js and ensure it is on PATH."}

        tmp_path: Path | None = None
        try:
            # Temp file with .mjs extension (ESM required)
            fd, tmp_str = tempfile.mkstemp(suffix=".mjs", prefix="dbeaver_adapter_")
            os.close(fd)
            tmp_path = Path(tmp_str)
            tmp_path.write_text(script_content, encoding="utf-8")

            self.log(f"[{label}] Running node script: {tmp_path.name}")
            completed = subprocess.run(
                [node_exe, str(tmp_path)],
                capture_output=True,
                text=True,
                timeout=_NODE_TIMEOUT,
            )

            stdout = completed.stdout.strip()
            stderr = completed.stderr.strip()

            if stderr:
                self.log(f"[{label}] node stderr: {stderr[:300]}")

            if not stdout:
                return {"error": f"Node script produced no output (exit {completed.returncode}). stderr: {stderr[:200]}"}

            # Parse the last JSON line (node may emit progress lines to stdout)
            json_line = _last_json_line(stdout)
            if json_line is None:
                return {"error": f"No valid JSON in node output: {stdout[:300]}"}

            parsed = json.loads(json_line)
            return parsed

        except subprocess.TimeoutExpired:
            return {"error": f"Node script timed out after {_NODE_TIMEOUT} s (EDH Knox is slow — retry or check VPN)"}
        except json.JSONDecodeError as exc:
            return {"error": f"JSON parse error: {exc}. Raw stdout: {stdout[:200]}"}
        except Exception as exc:  # noqa: BLE001
            return {"error": f"Script execution error: {exc}"}
        finally:
            if tmp_path and tmp_path.exists():
                try:
                    tmp_path.unlink()
                except OSError:
                    pass

    # ── Guards ────────────────────────────────────────────────────────────────

    def _check_dbeaver_mcp(self) -> bool:
        return _DBEAVER_MCP_DIR.exists() and _CONFIG_PARSER_ESM.exists() and _INDEX_ESM.exists()

    def _dbeaver_missing_error(self) -> dict:
        return self.error(
            f"dbeaver-mcp-server not found at: {_DBEAVER_MCP_DIR}\n"
            "Install it with: npm install -g dbeaver-mcp-server\n"
            "If already installed, verify the dist/ folder contains config-parser.js and index.js."
        )


# ── Utilities ─────────────────────────────────────────────────────────────────


def _fwd(path: Path) -> str:
    """Convert Windows path to forward-slash string for ESM file:/// URLs."""
    return str(path).replace("\\", "/")


def _find_node() -> str | None:
    """Return path to node executable, or None if not found."""
    # Try known Windows location first
    candidates = [
        "C:/Program Files/nodejs/node.exe",
        "C:/Program Files (x86)/nodejs/node.exe",
    ]
    for c in candidates:
        if Path(c).exists():
            return c
    # Fall back to PATH
    return shutil.which("node")


def _ensure_limit(sql: str, limit: int) -> str:
    """
    Add LIMIT N to the query if no LIMIT clause is present.
    Case-insensitive; strips trailing semicolons before appending.
    """
    cleaned = sql.rstrip().rstrip(";").rstrip()
    if re.search(r"\bLIMIT\s+\d+", cleaned, re.IGNORECASE):
        return cleaned
    return f"{cleaned}\nLIMIT {limit}"


def _last_json_line(text: str) -> str | None:
    """
    Return the last line in text that is valid JSON, or None.
    Node scripts may print progress lines before the final JSON payload.
    """
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line.startswith(("{", "[")):
            try:
                json.loads(line)
                return line
            except json.JSONDecodeError:
                continue
    return None
