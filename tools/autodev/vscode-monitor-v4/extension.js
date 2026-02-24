// AUTODEV Monitor v4 — Simple sidebar dashboard for subagent pipeline
// Reads: session.json, worker_*.json, validation.json from tools/autodev/status/
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

// --- Data Layer ---

function findStatusDir() {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders) return null;
  for (const f of folders) {
    const candidate = path.join(f.uri.fsPath, 'tools', 'autodev', 'status');
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function readJsonSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(raw);
  } catch { return null; }
}

function readAllStatus(statusDir) {
  const session = readJsonSafe(path.join(statusDir, 'session.json'));
  const validation = readJsonSafe(path.join(statusDir, 'validation.json'));

  const workers = [];
  try {
    const files = fs.readdirSync(statusDir);
    for (const f of files) {
      if (f.startsWith('worker_') && f.endsWith('.json')) {
        const data = readJsonSafe(path.join(statusDir, f));
        if (data) workers.push(data);
      }
    }
  } catch { /* ignore */ }

  workers.sort((a, b) => (a.name || '').localeCompare(b.name || ''));

  return { session, workers, validation };
}

// --- HTML Rendering ---

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function timeAgo(isoString) {
  if (!isoString) return '';
  const diff = Date.now() - new Date(isoString).getTime();
  if (diff < 0) return 'now';
  const secs = Math.floor(diff / 1000);
  if (secs < 60) return secs + 's';
  const mins = Math.floor(secs / 60);
  if (mins < 60) return mins + 'm';
  const hrs = Math.floor(mins / 60);
  return hrs + 'h';
}

function stateColor(state) {
  const map = { running: '#00ff41', done: '#00cc33', error: '#ff3333', paused: '#ffaa00', idle: '#557755', pending: '#888888' };
  return map[state] || '#557755';
}

function stateIcon(state) {
  const map = { running: '\u25B6', done: '\u2713', error: '\u2717', paused: '\u275A\u275A', idle: '\u25CB', pending: '\u25CB' };
  return map[state] || '\u25CB';
}

function progressBar(done, total) {
  if (!total || total <= 0) return '';
  const filled = Math.round((done / total) * 10);
  return '\u2588'.repeat(filled) + '\u2591'.repeat(10 - filled) + ' ' + done + '/' + total;
}

function renderSession(session) {
  if (!session) {
    return `<div class="section header">
      <span class="title">AUTODEV</span>
      <span class="state" style="color:${stateColor('idle')}">${stateIcon('idle')} IDLE</span>
    </div>`;
  }
  const state = session.state || 'idle';
  const obj = session.objective ? `<div class="objective">"${escapeHtml(session.objective)}"</div>` : '';
  const cp = session.checkpoint ? `<div class="checkpoint">${escapeHtml(session.checkpoint)}</div>` : '';
  return `<div class="section header">
    <span class="title">AUTODEV</span>
    <span class="state" style="color:${stateColor(state)}">${stateIcon(state)} ${state.toUpperCase()}</span>
  </div>
  ${obj}${cp}`;
}

function renderWorker(w) {
  const status = w.status || 'pending';
  const done = w.progress ? (w.progress.done || 0) : 0;
  const total = w.progress ? (w.progress.total || 0) : 0;
  const bar = progressBar(done, total);
  const task = w.current_task ? `<div class="task">\u2192 ${escapeHtml(w.current_task)}</div>` : '';
  const err = (status === 'error' && w.error) ? `<div class="error">\u26A0 ${escapeHtml(w.error)}</div>` : '';
  const ago = w.updated_at ? `<span class="ago">${timeAgo(w.updated_at)}</span>` : '';

  return `<div class="worker">
    <div class="worker-header">
      <span class="worker-name" style="color:${stateColor(status)}">${stateIcon(status)} ${escapeHtml(w.name || '?')}</span>
      ${ago}
    </div>
    ${bar ? `<div class="progress">${bar}</div>` : ''}
    ${task}${err}
  </div>`;
}

function renderValidation(v) {
  if (!v) return '';
  const status = v.status || 'unknown';
  const color = status === 'pass' ? '#00cc33' : status === 'fail' ? '#ff3333' : '#ffaa00';
  const icon = status === 'pass' ? '\u2713' : status === 'fail' ? '\u2717' : '\u25B6';
  const details = (v.details && v.details.length > 0)
    ? v.details.slice(0, 5).map(d => `<div class="val-detail">${escapeHtml(d)}</div>`).join('')
    : '';
  return `<div class="section validation">
    <div class="val-header">
      <span class="val-title">VALIDATION</span>
      <span style="color:${color}">${icon} ${status.toUpperCase()}</span>
    </div>
    <div class="val-summary">${v.errors || 0} errors, ${v.warnings || 0} warnings</div>
    ${details}
  </div>`;
}

function renderLogs(workers) {
  const allLogs = [];
  for (const w of workers) {
    if (w.log && Array.isArray(w.log)) {
      for (const entry of w.log.slice(-10)) {
        allLogs.push({ name: w.name, text: entry, time: w.updated_at });
      }
    }
  }
  const recent = allLogs.slice(-15);
  if (recent.length === 0) return '';

  const lines = recent.map(l =>
    `<div class="log-line"><span class="log-name">${escapeHtml(l.name)}</span> ${escapeHtml(l.text)}</div>`
  ).join('');
  return `<div class="section logs">
    <div class="log-title">LOG</div>
    ${lines}
  </div>`;
}

function buildHtml(data) {
  const { session, workers, validation } = data;
  return `<!DOCTYPE html>
<html><head><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    font-size: 11px;
    background: #0a0a0a;
    color: #c0c0c0;
    padding: 8px;
    line-height: 1.4;
  }
  .section { margin-bottom: 10px; padding-bottom: 8px; border-bottom: 1px solid #1a2a1a; }
  .header { display: flex; justify-content: space-between; align-items: center; }
  .title { font-size: 13px; font-weight: bold; color: #00ff41; }
  .state { font-size: 11px; font-weight: bold; }
  .objective { color: #888; font-style: italic; margin: 4px 0; font-size: 10px; }
  .checkpoint { color: #00e5ff; margin: 2px 0; font-size: 10px; }
  .worker { margin: 6px 0; padding: 6px; background: #0d0d0d; border: 1px solid #1a2a1a; border-radius: 3px; }
  .worker-header { display: flex; justify-content: space-between; align-items: center; }
  .worker-name { font-weight: bold; font-size: 11px; }
  .ago { color: #555; font-size: 9px; }
  .progress { color: #00ff41; font-size: 10px; margin: 2px 0; letter-spacing: -1px; }
  .task { color: #aaa; font-size: 10px; margin: 2px 0; }
  .error { color: #ff3333; font-size: 10px; margin: 2px 0; }
  .validation { }
  .val-header { display: flex; justify-content: space-between; align-items: center; }
  .val-title { font-weight: bold; color: #00e5ff; }
  .val-summary { color: #aaa; font-size: 10px; margin: 2px 0; }
  .val-detail { color: #888; font-size: 9px; margin: 1px 0; padding-left: 8px; }
  .logs { }
  .log-title { font-weight: bold; color: #555; margin-bottom: 4px; }
  .log-line { font-size: 9px; color: #666; margin: 1px 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .log-name { color: #00ff41; font-weight: bold; }
  .empty { color: #333; text-align: center; margin: 20px 0; font-size: 10px; }
</style></head><body>
  ${renderSession(session)}
  ${workers.length > 0
    ? `<div class="section">${workers.map(renderWorker).join('')}</div>`
    : '<div class="empty">No workers active</div>'}
  ${renderValidation(validation)}
  ${renderLogs(workers)}
  <script>
    window.addEventListener('message', e => {
      if (e.data && e.data.type === 'refresh') location.reload();
    });
  </script>
</body></html>`;
}

// --- VS Code Extension ---

class AutodevSidebarProvider {
  constructor(statusDir) {
    this._statusDir = statusDir;
    this._view = null;
  }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    this._update();
  }

  _update() {
    if (!this._view || !this._statusDir) return;
    const data = readAllStatus(this._statusDir);
    this._view.webview.html = buildHtml(data);
  }

  refresh() {
    this._update();
  }
}

function activate(context) {
  const statusDir = findStatusDir();
  if (!statusDir) {
    console.log('AUTODEV v4: No status directory found');
    return;
  }

  const provider = new AutodevSidebarProvider(statusDir);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('autodev-v4.sidebarView', provider)
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-v4.refresh', () => provider.refresh())
  );

  // File watcher with debounce
  let debounceTimer = null;
  const watcher = fs.watch(statusDir, { recursive: false }, () => {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => provider.refresh(), 500);
  });
  context.subscriptions.push({ dispose: () => watcher.close() });

  // Fallback poll every 5s (Windows fs.watch can miss events)
  const pollInterval = setInterval(() => provider.refresh(), 5000);
  context.subscriptions.push({ dispose: () => clearInterval(pollInterval) });

  console.log('AUTODEV Monitor v4 activated — watching ' + statusDir);
}

function deactivate() {}

module.exports = { activate, deactivate };
