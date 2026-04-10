import { createServer, IncomingMessage, ServerResponse } from 'http';
import { readFile, watch } from 'fs';
import { join } from 'path';

const STATUS_DIR = 'c:/Users/PGNK2128/Godot-MCP/tools/autodev/status';
const EVENTS_FILE = join(STATUS_DIR, 'dashboard_events.jsonl');
const PORT = 4201;
const clients: Set<ServerResponse> = new Set();

function broadcast(event: { type: string; data: Record<string, unknown> }): void {
  const payload = `data: ${JSON.stringify(event)}\n\n`;
  for (const client of clients) {
    try { client.write(payload); } catch { clients.delete(client); }
  }
}

function sendFullState(res: ServerResponse): void {
  const files = ['feature_queue.json', 'agent_status.json', 'cloud_sessions.json', 'agent_performance.json'];
  for (const file of files) {
    readFile(join(STATUS_DIR, file), 'utf-8', (err, data) => {
      if (err) return;
      try { res.write(`data: ${JSON.stringify({ type: 'full_state', data: { file, content: JSON.parse(data) } })}\n\n`); } catch { /* ignore */ }
    });
  }
}

function watchStatusDir(): void {
  try {
    watch(STATUS_DIR, { recursive: false }, (_ev, filename) => {
      if (!filename || !filename.endsWith('.json')) return;
      readFile(join(STATUS_DIR, filename), 'utf-8', (err, data) => {
        if (err) return;
        try { broadcast({ type: 'file_update', data: { file: filename, content: JSON.parse(data) } }); } catch { /* ignore */ }
      });
    });
    console.log(`[SSE] Watching ${STATUS_DIR}`);
  } catch (err) { console.error('[SSE] Watch failed:', err); }
}

function watchEventsFile(): void {
  let lastSize = 0;
  try {
    watch(EVENTS_FILE, (eventType) => {
      if (eventType !== 'change') return;
      readFile(EVENTS_FILE, 'utf-8', (err, data) => {
        if (err) return;
        const lines = data.trim().split('\n');
        const newLines = lines.slice(lastSize);
        lastSize = lines.length;
        for (const line of newLines) { try { broadcast(JSON.parse(line)); } catch { /* ignore */ } }
      });
    });
  } catch { /* events file not yet created */ }
}

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  if (req.url === '/events') {
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' });
    sendFullState(res);
    clients.add(res);
    console.log(`[SSE] +client (${clients.size})`);
    const hb = setInterval(() => { try { res.write(': hb\n\n'); } catch { clearInterval(hb); clients.delete(res); } }, 30000);
    req.on('close', () => { clearInterval(hb); clients.delete(res); console.log(`[SSE] -client (${clients.size})`); });
    return;
  }
  if (req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', clients: clients.size, uptime: process.uptime() }));
    return;
  }
  if (req.url === '/api/state') {
    const state: Record<string, unknown> = {};
    const files = ['feature_queue.json', 'agent_status.json', 'cloud_sessions.json', 'agent_performance.json'];
    let n = 0;
    for (const f of files) {
      readFile(join(STATUS_DIR, f), 'utf-8', (err, data) => {
        n++;
        if (!err) { try { state[f] = JSON.parse(data); } catch { /* ignore */ } }
        if (n === files.length) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(state)); }
      });
    }
    return;
  }
  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`[MERLIN SSE] http://localhost:${PORT}`);
  watchStatusDir();
  watchEventsFile();
});
