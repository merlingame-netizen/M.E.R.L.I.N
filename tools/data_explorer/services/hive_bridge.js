#!/usr/bin/env node
/**
 * hive_bridge.js — Node.js bridge for EDH Hive queries via hive-driver (Knox HTTPS).
 *
 * Usage: node hive_bridge.js "SELECT * FROM schema.table LIMIT 100"
 * Output: JSON on stdout: {columns: [...], rows: [{...}, ...], row_count: N, duration_ms: N}
 * Errors: JSON on stdout: {error: "message", duration_ms: N}
 */

// Force UTF-8 output
if (process.stdout.setDefaultEncoding) process.stdout.setDefaultEncoding('utf-8');

const { createRequire } = require('module');

// Resolve hive-driver from dbeaver-mcp-server's node_modules
const DBEAVER_MCP = 'C:/Users/PGNK2128/AppData/Roaming/npm/node_modules/dbeaver-mcp-server';
const req = createRequire(require.resolve(DBEAVER_MCP + '/dist/index.js'));
const { DBeaverConfigParser } = require(DBEAVER_MCP + '/dist/config-parser.js');

const CONNECTION_ID = 'EDH_PRODv2';
const MAX_POLL_ATTEMPTS = 180; // 6 min max (180 * 2s)
const POLL_INTERVAL_MS = 2000;

async function hiveQuery(connection, sql) {
  const hive = req('hive-driver');
  const { TCLIService, TCLIService_types } = hive.thrift;
  const client = new hive.HiveClient(TCLIService, TCLIService_types);
  const utils = new hive.HiveUtils(TCLIService_types);

  const url = connection.url || '';
  const host = url.match(/hive2:\/\/([^:\/]+)/)?.[1] || 'localhost';
  const port = parseInt(url.match(/hive2:\/\/[^:]+:(\d+)/)?.[1] || '443');
  const httpPath = '/' + (url.match(/httpPath=([^;]+)/)?.[1] || '');
  const user = connection.user || '';
  const password = connection.properties?.password || '';

  const t0 = Date.now();

  try {
    await client.connect(
      { host, port, options: { path: httpPath, https: true } },
      new hive.connections.HttpConnection(),
      new hive.auth.PlainHttpAuthentication({ username: user, password })
    );

    const session = await client.openSession({
      client_protocol: TCLIService_types.TProtocolVersion.HIVE_CLI_SERVICE_PROTOCOL_V8,
      username: user, password
    });

    const operation = await session.executeStatement(sql, { runAsync: true });

    // Poll until done
    let ready = false;
    let attempts = 0;
    while (!ready && attempts < MAX_POLL_ATTEMPTS) {
      const status = await operation.status();
      if (status.operationState === TCLIService_types.TOperationState.FINISHED_STATE) {
        ready = true;
      } else if (status.operationState === TCLIService_types.TOperationState.ERROR_STATE) {
        const errMsg = status.errorMessage || 'Unknown Hive error';
        await operation.close(); await session.close(); await client.close();
        return { error: errMsg.substring(0, 500), duration_ms: Date.now() - t0 };
      } else {
        attempts++;
        await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
      }
    }

    if (!ready) {
      await operation.close(); await session.close(); await client.close();
      return { error: `Timeout after ${MAX_POLL_ATTEMPTS * POLL_INTERVAL_MS / 1000}s`, duration_ms: Date.now() - t0 };
    }

    // Fetch results
    await utils.fetchAll(operation);
    const resultObj = await utils.getResult(operation);
    const rawRows = resultObj.getValue ? resultObj.getValue() : [];

    // Convert to {columns, rows} format
    const columns = rawRows.length > 0 ? Object.keys(rawRows[0]) : [];
    const rows = rawRows.map(r => {
      const row = {};
      for (const col of columns) {
        const v = r[col];
        row[col] = (v === null || v === undefined) ? null : String(v);
      }
      return row;
    });

    await operation.close();
    await session.close();
    await client.close();

    return {
      columns,
      rows,
      row_count: rows.length,
      duration_ms: Date.now() - t0,
    };
  } catch (e) {
    try { await client.close(); } catch (_) {}
    return { error: (e.message || String(e)).substring(0, 500), duration_ms: Date.now() - t0 };
  }
}

async function main() {
  const sql = process.argv[2];
  if (!sql) {
    console.log(JSON.stringify({ error: 'Usage: node hive_bridge.js "SQL QUERY"' }));
    process.exit(1);
  }

  const parser = new DBeaverConfigParser();
  const conn = await parser.getConnection(CONNECTION_ID);
  if (!conn) {
    console.log(JSON.stringify({ error: `DBeaver connection '${CONNECTION_ID}' not found` }));
    process.exit(1);
  }

  const result = await hiveQuery(conn, sql);
  console.log(JSON.stringify(result));
}

main().catch(e => {
  console.log(JSON.stringify({ error: `Fatal: ${(e.message || e).substring(0, 300)}` }));
  process.exit(1);
});
