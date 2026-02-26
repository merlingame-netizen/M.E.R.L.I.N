// AUTODEV Monitor v4.1 — AUTODEV pipeline + Godot Scene Controller
// Panels: "Godot Scenes" (top) + "AUTODEV" (bottom)
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const cp = require('child_process');

// ============================================================
// SHARED UTILS
// ============================================================

function findProjectRoot() {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders) return null;
  for (const f of folders) {
    if (fs.existsSync(path.join(f.uri.fsPath, 'project.godot'))) return f.uri.fsPath;
  }
  return folders[0].uri.fsPath;
}

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
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch { return null; }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ============================================================
// GODOT PROCESS MANAGER
// ============================================================

let _godotProcess = null;

function getGodotExe() {
  const cfg = vscode.workspace.getConfiguration('godotTools');
  const fromCfg = cfg.get('editorPath.godot4');
  if (fromCfg && fs.existsSync(fromCfg)) return fromCfg;
  // Fallback: search common locations
  const candidates = [
    'C:\\Users\\PGNK2128\\Godot\\Godot_v4.5.1-stable_win64.exe',
    'C:\\Users\\PGNK2128\\Godot\\Godot_v4.5.1-stable_win64_console.exe',
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return 'godot'; // fallback to PATH
}

function isGodotRunning() {
  return _godotProcess !== null && !_godotProcess.killed;
}

function launchScene(scenePath, root, onExit) {
  killGodot();
  const exe = getGodotExe();
  const rel = path.relative(root, scenePath).replace(/\\/g, '/');
  _godotProcess = cp.spawn(exe, ['--path', root, rel], {
    detached: false,
    stdio: ['ignore', 'ignore', 'ignore'],
    windowsHide: false,
  });
  _godotProcess.on('exit', () => {
    _godotProcess = null;
    if (onExit) onExit();
  });
  _godotProcess.on('error', () => {
    _godotProcess = null;
    if (onExit) onExit();
  });
}

function launchGame(root, onExit) {
  killGodot();
  const exe = getGodotExe();
  _godotProcess = cp.spawn(exe, ['--path', root], {
    detached: false,
    stdio: ['ignore', 'ignore', 'ignore'],
    windowsHide: false,
  });
  _godotProcess.on('exit', () => {
    _godotProcess = null;
    if (onExit) onExit();
  });
  _godotProcess.on('error', () => {
    _godotProcess = null;
    if (onExit) onExit();
  });
}

function killGodot() {
  if (!_godotProcess) return;
  try {
    if (process.platform === 'win32') {
      cp.exec(`taskkill /F /PID ${_godotProcess.pid} /T`);
    } else {
      _godotProcess.kill('SIGTERM');
    }
  } catch { /* ignore */ }
  _godotProcess = null;
}

// ============================================================
// SCENE DISCOVERY
// ============================================================

function findScriptInScene(tscnPath) {
  try {
    const content = fs.readFileSync(tscnPath, 'utf8');
    const match = content.match(/\[ext_resource type="Script" path="res:\/\/([^"]+)"/);
    if (match) return match[1]; // relative to project root e.g. scripts/ui/foo.gd
  } catch { /* ignore */ }
  return null;
}

async function discoverScenes(root) {
  const scenesDir = path.join(root, 'scenes');
  if (!fs.existsSync(scenesDir)) return {};

  const uris = await vscode.workspace.findFiles('scenes/**/*.tscn', null, 200);
  const groups = {};

  for (const uri of uris) {
    const full = uri.fsPath;
    const rel = path.relative(root, full).replace(/\\/g, '/');
    const name = path.basename(full, '.tscn');
    const folder = path.relative(root, path.dirname(full)).replace(/\\/g, '/');
    const scriptRel = findScriptInScene(full);

    const entry = { name, full, rel, scriptRel };
    if (!groups[folder]) groups[folder] = [];
    groups[folder].push(entry);
  }

  // Sort scenes within each group
  for (const grp of Object.values(groups)) {
    grp.sort((a, b) => a.name.localeCompare(b.name));
  }

  return groups;
}

// ============================================================
// GODOT SCENES HTML
// ============================================================

const CRT = {
  bg: '#050a05',
  panel: '#080e08',
  green: '#00ff41',
  greenDim: '#00aa2a',
  amber: '#ffb300',
  cyan: '#00e5ff',
  red: '#ff3333',
  gray: '#555',
  text: '#b0c8b0',
  border: '#1a2a1a',
};

function buildScenesHtml(groups, running) {
  const statusColor = running ? CRT.green : CRT.gray;
  const statusIcon = running ? '●' : '○';
  const statusText = running ? 'RUNNING' : 'IDLE';

  let scenesHtml = '';
  const sortedFolders = Object.keys(groups).sort();

  if (sortedFolders.length === 0) {
    scenesHtml = `<div class="empty">No .tscn files found in scenes/</div>`;
  } else {
    for (const folder of sortedFolders) {
      const label = folder === 'scenes' ? 'scenes/' : folder + '/';
      const items = groups[folder].map(s => {
        const scriptBtn = s.scriptRel
          ? `<button class="btn-script" onclick="openScript('${escapeHtml(s.scriptRel)}')" title="Open ${s.scriptRel}">{}</button>`
          : `<button class="btn-script disabled" disabled title="No script found">{}</button>`;
        return `<div class="scene-row">
          <button class="btn-launch" onclick="launch('${escapeHtml(s.full)}')" title="Launch ${s.rel}">▶</button>
          ${scriptBtn}
          <span class="scene-name" title="${escapeHtml(s.rel)}">${escapeHtml(s.name)}</span>
        </div>`;
      }).join('');
      scenesHtml += `<div class="group">
        <div class="group-label">${escapeHtml(label)}</div>
        ${items}
      </div>`;
    }
  }

  return `<!DOCTYPE html>
<html><head><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Cascadia Code', 'Fira Code', Consolas, monospace;
    font-size: 11px;
    background: ${CRT.bg};
    color: ${CRT.text};
    padding: 8px;
    line-height: 1.5;
    user-select: none;
  }
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 6px;
    border-bottom: 1px solid ${CRT.border};
    margin-bottom: 8px;
  }
  .title { font-size: 12px; font-weight: bold; color: ${CRT.green}; letter-spacing: 1px; }
  .status { font-size: 11px; font-weight: bold; color: ${statusColor}; }
  .group { margin-bottom: 10px; }
  .group-label {
    font-size: 9px;
    color: ${CRT.gray};
    letter-spacing: 1px;
    padding: 2px 0 4px 0;
    text-transform: uppercase;
  }
  .scene-row {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 3px 4px;
    border-radius: 2px;
    cursor: default;
  }
  .scene-row:hover { background: ${CRT.panel}; }
  .scene-name { flex: 1; font-size: 11px; color: ${CRT.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: pointer; }
  .scene-name:hover { color: ${CRT.cyan}; }
  button {
    font-family: inherit;
    font-size: 10px;
    border: 1px solid ${CRT.border};
    background: ${CRT.panel};
    color: ${CRT.greenDim};
    cursor: pointer;
    padding: 1px 5px;
    border-radius: 2px;
    flex-shrink: 0;
  }
  button:hover { border-color: ${CRT.green}; color: ${CRT.green}; background: #0a1a0a; }
  button:active { background: #0d2a0d; }
  .btn-launch { color: ${CRT.green}; min-width: 22px; }
  .btn-script { color: ${CRT.amber}; min-width: 22px; font-size: 9px; }
  .btn-script.disabled { color: ${CRT.gray}; cursor: not-allowed; border-color: #111; }
  .footer {
    margin-top: 10px;
    padding-top: 8px;
    border-top: 1px solid ${CRT.border};
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  .btn-main {
    flex: 1;
    padding: 5px 8px;
    font-size: 11px;
    font-weight: bold;
    text-align: center;
    color: ${CRT.green};
    border-color: ${CRT.greenDim};
  }
  .btn-kill {
    flex: 1;
    padding: 5px 8px;
    font-size: 11px;
    font-weight: bold;
    color: ${CRT.red};
    border-color: #551111;
  }
  .btn-validate {
    flex: 1;
    padding: 5px 8px;
    font-size: 11px;
    font-weight: bold;
    color: ${CRT.cyan};
    border-color: #115555;
  }
  .empty { color: ${CRT.gray}; text-align: center; margin: 20px 0; font-size: 10px; }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: ${CRT.bg}; }
  ::-webkit-scrollbar-thumb { background: ${CRT.border}; }
</style></head><body>
  <div class="header">
    <span class="title">GODOT SCENES</span>
    <span class="status">${statusIcon} ${statusText}</span>
  </div>

  ${scenesHtml}

  <div class="footer">
    <button class="btn-main" onclick="launchGame()" title="Launch full game from main scene">▶ Game</button>
    <button class="btn-kill" onclick="kill()" title="Kill Godot process (Shift+F5)">■ Kill</button>
    <button class="btn-validate" onclick="validate()" title="Run validate.bat (parse check)">✓ Validate</button>
  </div>

  <script>
    const vscode = acquireVsCodeApi();
    function launch(p) { vscode.postMessage({ type: 'launch', scenePath: p }); }
    function launchGame() { vscode.postMessage({ type: 'launch-game' }); }
    function kill() { vscode.postMessage({ type: 'kill' }); }
    function validate() { vscode.postMessage({ type: 'validate' }); }
    function openScript(rel) { vscode.postMessage({ type: 'open-script', scriptRel: rel }); }
  </script>
</body></html>`;
}

// ============================================================
// GODOT SCENES PROVIDER
// ============================================================

class GodotScenesProvider {
  constructor(root) {
    this._root = root;
    this._view = null;
    this._groups = {};
  }

  async resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };

    webviewView.webview.onDidReceiveMessage(async (msg) => {
      switch (msg.type) {
        case 'launch':
          launchScene(msg.scenePath, this._root, () => this._update());
          this._update();
          break;
        case 'launch-game':
          launchGame(this._root, () => this._update());
          this._update();
          break;
        case 'kill':
          killGodot();
          this._update();
          break;
        case 'validate':
          this._runValidate();
          break;
        case 'open-script':
          await this._openScript(msg.scriptRel);
          break;
      }
    });

    await this._update();
  }

  async _update() {
    if (!this._view) return;
    this._groups = await discoverScenes(this._root);
    this._view.webview.html = buildScenesHtml(this._groups, isGodotRunning());
  }

  async _openScript(scriptRel) {
    const full = path.join(this._root, scriptRel);
    if (!fs.existsSync(full)) {
      vscode.window.showWarningMessage(`Script not found: ${scriptRel}`);
      return;
    }
    const doc = await vscode.workspace.openTextDocument(full);
    await vscode.window.showTextDocument(doc);
  }

  _runValidate() {
    const terminal = vscode.window.createTerminal('Validate');
    terminal.sendText(`cd "${this._root}" && .\\validate.bat`);
    terminal.show();
  }

  refresh() {
    this._update();
  }
}

// ============================================================
// AUTODEV DASHBOARD (unchanged from v4.0)
// ============================================================

function readAllStatus(statusDir) {
  const session = readJsonSafe(path.join(statusDir, 'session.json'));
  const validation = readJsonSafe(path.join(statusDir, 'validation.json'));
  const workers = [];
  try {
    for (const f of fs.readdirSync(statusDir)) {
      if (f.startsWith('worker_') && f.endsWith('.json')) {
        const data = readJsonSafe(path.join(statusDir, f));
        if (data) workers.push(data);
      }
    }
  } catch { /* ignore */ }
  workers.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
  return { session, workers, validation };
}

function timeAgo(isoString) {
  if (!isoString) return '';
  const diff = Date.now() - new Date(isoString).getTime();
  if (diff < 0) return 'now';
  const secs = Math.floor(diff / 1000);
  if (secs < 60) return secs + 's';
  const mins = Math.floor(secs / 60);
  if (mins < 60) return mins + 'm';
  return Math.floor(mins / 60) + 'h';
}

function stateColor(state) {
  const map = { running: '#00ff41', done: '#00cc33', error: '#ff3333', paused: '#ffaa00', idle: '#557755', pending: '#888888' };
  return map[state] || '#557755';
}

function stateIcon(state) {
  const map = { running: '▶', done: '✓', error: '✗', paused: '⏸', idle: '○', pending: '○' };
  return map[state] || '○';
}

function progressBar(done, total) {
  if (!total || total <= 0) return '';
  const filled = Math.round((done / total) * 10);
  return '█'.repeat(filled) + '░'.repeat(10 - filled) + ' ' + done + '/' + total;
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
  const cp2 = session.checkpoint ? `<div class="checkpoint">${escapeHtml(session.checkpoint)}</div>` : '';
  return `<div class="section header">
    <span class="title">AUTODEV</span>
    <span class="state" style="color:${stateColor(state)}">${stateIcon(state)} ${state.toUpperCase()}</span>
  </div>${obj}${cp2}`;
}

function renderWorker(w) {
  const status = w.status || 'pending';
  const done = w.progress ? (w.progress.done || 0) : 0;
  const total = w.progress ? (w.progress.total || 0) : 0;
  const bar = progressBar(done, total);
  const task = w.current_task ? `<div class="task">→ ${escapeHtml(w.current_task)}</div>` : '';
  const err = (status === 'error' && w.error) ? `<div class="error">⚠ ${escapeHtml(w.error)}</div>` : '';
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
  const icon = status === 'pass' ? '✓' : status === 'fail' ? '✗' : '▶';
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
        allLogs.push({ name: w.name, text: entry });
      }
    }
  }
  const recent = allLogs.slice(-15);
  if (recent.length === 0) return '';
  const lines = recent.map(l =>
    `<div class="log-line"><span class="log-name">${escapeHtml(l.name)}</span> ${escapeHtml(l.text)}</div>`
  ).join('');
  return `<div class="section logs">
    <div class="log-title">LOG</div>${lines}
  </div>`;
}

function buildAutodevHtml(data) {
  const { session, workers, validation } = data;
  return `<!DOCTYPE html>
<html><head><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Cascadia Code', 'Fira Code', Consolas, monospace; font-size: 11px; background: #0a0a0a; color: #c0c0c0; padding: 8px; line-height: 1.4; }
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
  .val-header { display: flex; justify-content: space-between; align-items: center; }
  .val-title { font-weight: bold; color: #00e5ff; }
  .val-summary { color: #aaa; font-size: 10px; margin: 2px 0; }
  .val-detail { color: #888; font-size: 9px; margin: 1px 0; padding-left: 8px; }
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
</body></html>`;
}

class AutodevSidebarProvider {
  constructor(statusDir) {
    this._statusDir = statusDir;
    this._view = null;
  }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: false };
    this._update();
  }

  _update() {
    if (!this._view || !this._statusDir) return;
    this._view.webview.html = buildAutodevHtml(readAllStatus(this._statusDir));
  }

  refresh() { this._update(); }
}

// ============================================================
// ACTIVATE
// ============================================================

function activate(context) {
  const root = findProjectRoot();
  const statusDir = findStatusDir();

  // --- Godot Scenes panel ---
  if (root) {
    const scenesProvider = new GodotScenesProvider(root);
    context.subscriptions.push(
      vscode.window.registerWebviewViewProvider('autodev-v4.godotView', scenesProvider)
    );

    context.subscriptions.push(
      vscode.commands.registerCommand('autodev-v4.launchGame', () => {
        launchGame(root, () => scenesProvider.refresh());
        scenesProvider.refresh();
      })
    );

    context.subscriptions.push(
      vscode.commands.registerCommand('autodev-v4.killGodot', () => {
        killGodot();
        scenesProvider.refresh();
      })
    );

    context.subscriptions.push(
      vscode.commands.registerCommand('autodev-v4.validate', () => {
        const terminal = vscode.window.createTerminal('Validate');
        terminal.sendText(`cd "${root}" && .\\validate.bat`);
        terminal.show();
      })
    );

    // Kill Godot on extension deactivate
    context.subscriptions.push({ dispose: () => killGodot() });
  }

  // --- AUTODEV Dashboard panel ---
  if (statusDir) {
    const autodevProvider = new AutodevSidebarProvider(statusDir);
    context.subscriptions.push(
      vscode.window.registerWebviewViewProvider('autodev-v4.sidebarView', autodevProvider)
    );

    context.subscriptions.push(
      vscode.commands.registerCommand('autodev-v4.refresh', () => autodevProvider.refresh())
    );

    let debounceTimer = null;
    const watcher = fs.watch(statusDir, { recursive: false }, () => {
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => autodevProvider.refresh(), 500);
    });
    context.subscriptions.push({ dispose: () => watcher.close() });

    const pollInterval = setInterval(() => autodevProvider.refresh(), 5000);
    context.subscriptions.push({ dispose: () => clearInterval(pollInterval) });
  }

  console.log('AUTODEV Monitor v4.1 activated — root: ' + root);
}

function deactivate() {
  killGodot();
}

module.exports = { activate, deactivate };
