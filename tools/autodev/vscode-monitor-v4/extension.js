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
// LIVE VIEW — Godot debug dir reader
// ============================================================

const GODOT_USER = path.join(process.env.APPDATA || '', 'Godot', 'app_userdata', 'DRU');
const GODOT_DEBUG_DIR = path.join(GODOT_USER, 'debug');
const LIVE_SCREENSHOT = path.join(GODOT_DEBUG_DIR, 'latest_screenshot.png');
const LIVE_STATE = path.join(GODOT_DEBUG_DIR, 'latest_state.json');
const LIVE_LOG = path.join(GODOT_DEBUG_DIR, 'log_buffer.json');

function readScreenshotBase64() {
  try {
    if (!fs.existsSync(LIVE_SCREENSHOT)) return null;
    const stat = fs.statSync(LIVE_SCREENSHOT);
    // Ignorer si vieux de plus de 5 minutes
    if (Date.now() - stat.mtimeMs > 5 * 60 * 1000) return null;
    const buf = fs.readFileSync(LIVE_SCREENSHOT);
    return 'data:image/png;base64,' + buf.toString('base64');
  } catch { return null; }
}

function buildLiveViewHtml(screenshot, state, logLines) {
  const running = isGodotRunning();
  const hasDebug = fs.existsSync(GODOT_DEBUG_DIR);
  const statusColor = running ? CRT.green : CRT.gray;
  const statusIcon = running ? '●' : '○';

  // State table
  let stateHtml = '';
  const run = state ? state.run : null;
  if (run) {
    const rows = [
      ['Phase', escapeHtml(run.phase || '—')],
      ['Vie', `${run.life ?? '—'}/100`],
      ['Souffle', String(run.souffle ?? '—')],
      ['Essences', String(run.essences ?? '—')],
      ['Carte #', String(run.cards_played ?? '—')],
      ['Biome', escapeHtml((run.biome || '—').replace('foret_', ''))],
      ['Typology', escapeHtml(run.typology || '—')],
      ['Karma', String(run.karma ?? '—')],
      ['Mission', run.mission_type ? `${run.mission_progress}/${run.mission_total} ${escapeHtml(run.mission_type)}` : '—'],
    ];
    stateHtml = `<table class="state-table">
      ${rows.map(([k, v]) => `<tr><td class="key">${k}</td><td class="val">${v}</td></tr>`).join('')}
    </table>`;
    if (state.datetime) {
      stateHtml += `<div class="ts">Snapshot: ${escapeHtml(state.datetime)}</div>`;
    }
  } else {
    stateHtml = `<div class="empty">Aucun état — lance le jeu depuis [Godot Scenes]</div>`;
  }

  // Log
  const logHtml = logLines.length > 0
    ? logLines.map(l => {
        const colored = String(l)
          .replace(/\[GameDebug[^\]]*\]/g, m => `<span style="color:${CRT.cyan}">${escapeHtml(m)}</span>`)
          .replace(/\[TRIADE\]/g, `<span style="color:${CRT.amber}">[TRIADE]</span>`)
          .replace(/\[MerlinStore\]/g, `<span style="color:${CRT.green}">[MerlinStore]</span>`)
          .replace(/\[MerlinUI\]/g, `<span style="color:${CRT.greenDim}">[MerlinUI]</span>`);
        return `<div class="log-line">${colored}</div>`;
      }).join('')
    : `<div class="empty">Aucun log — GameDebugServer actif si is_debug_build()</div>`;

  return `<!DOCTYPE html>
<html><head><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Cascadia Code', Consolas, monospace; font-size: 11px; background: ${CRT.bg}; color: ${CRT.text}; padding: 8px; line-height: 1.5; }
  .header { display: flex; justify-content: space-between; align-items: center; padding-bottom: 6px; border-bottom: 1px solid ${CRT.border}; margin-bottom: 8px; }
  .title { font-size: 12px; font-weight: bold; color: ${CRT.green}; letter-spacing: 1px; }
  .status { font-size: 11px; font-weight: bold; color: ${statusColor}; }
  .screenshot { width: 100%; border: 1px solid ${CRT.border}; display: block; margin-bottom: 8px; image-rendering: pixelated; }
  .no-screenshot { background: ${CRT.panel}; border: 1px dashed ${CRT.border}; color: ${CRT.gray}; text-align: center; padding: 24px 8px; font-size: 10px; margin-bottom: 8px; }
  .section-label { font-size: 9px; color: ${CRT.gray}; letter-spacing: 1px; text-transform: uppercase; padding: 4px 0 2px 0; }
  .state-table { width: 100%; border-collapse: collapse; margin-bottom: 6px; }
  .state-table td { padding: 1px 4px; font-size: 10px; }
  .key { color: ${CRT.gray}; width: 52px; }
  .val { color: ${CRT.text}; }
  .ts { font-size: 9px; color: ${CRT.gray}; margin-bottom: 8px; }
  .log-section { border-top: 1px solid ${CRT.border}; margin-top: 6px; padding-top: 6px; }
  .log-line { font-size: 9px; color: ${CRT.gray}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin: 1px 0; }
  .empty { color: ${CRT.gray}; font-size: 10px; font-style: italic; padding: 4px 0; }
  .footer { margin-top: 8px; padding-top: 6px; border-top: 1px solid ${CRT.border}; display: flex; gap: 6px; }
  button { font-family: inherit; font-size: 10px; border: 1px solid ${CRT.border}; background: ${CRT.panel}; color: ${CRT.greenDim}; cursor: pointer; padding: 3px 7px; border-radius: 2px; flex: 1; }
  button:hover { border-color: ${CRT.green}; color: ${CRT.green}; }
  .btn-capture { color: ${CRT.amber}; border-color: #553300; }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-thumb { background: ${CRT.border}; }
</style></head><body>
  <div class="header">
    <span class="title">LIVE VIEW</span>
    <span class="status">${statusIcon} ${running ? 'RUNNING' : 'IDLE'}</span>
  </div>

  ${screenshot
    ? `<img class="screenshot" src="${screenshot}" title="Dernier screenshot Godot (F11 = manuel)">`
    : `<div class="no-screenshot">📷 Aucun screenshot<br>Lance le jeu → F11 ou attends 30s</div>`}

  <div class="section-label">État Run</div>
  ${stateHtml}

  <div class="log-section">
    <div class="section-label">Log GameDebugServer</div>
    ${logHtml}
  </div>

  <div class="footer">
    <button class="btn-capture" onclick="capture()" title="Envoie F11 à Godot (capture manuelle)">📷 F11</button>
    <button onclick="refresh()" title="Refresh immédiat">⟳ Refresh</button>
  </div>

  <script>
    const vscode = acquireVsCodeApi();
    function capture() { vscode.postMessage({ type: 'capture' }); }
    function refresh() { vscode.postMessage({ type: 'refresh' }); }
  </script>
</body></html>`;
}

class LiveViewProvider {
  constructor() {
    this._view = null;
    this._interval = null;
  }

  async resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };

    webviewView.webview.onDidReceiveMessage(async (msg) => {
      if (msg.type === 'capture') this._sendF11ToGodot();
      if (msg.type === 'refresh') await this._update();
    });

    // Auto-refresh every 3s
    this._interval = setInterval(() => this._update(), 3000);
    await this._update();
  }

  async _update() {
    if (!this._view) return;
    const screenshot = readScreenshotBase64();
    const state = readJsonSafe(LIVE_STATE);
    const logLines = readJsonSafe(LIVE_LOG) || [];
    this._view.webview.html = buildLiveViewHtml(screenshot, state, logLines.slice(-10));
  }

  _sendF11ToGodot() {
    // Envoie F11 à la fenêtre Godot via PowerShell SendKeys
    cp.exec(
      'powershell -Command "Add-Type -AN System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'{F11}\')"',
      () => {}
    );
  }

  dispose() {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  }
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
// TRAINING CONTROL PANEL
// ============================================================

function buildTrainingHtml(trainingState, progress, root) {
  const state   = (trainingState && trainingState.state) || 'idle';
  const stopAt  = (trainingState && trainingState.stop_at) || '08:00';
  const pid     = (trainingState && trainingState.pid) || 0;

  // Progress metrics (from progress.json written by train_qwen_cpu.py)
  const epoch    = (progress && progress.epoch)       || 0;
  const totEp    = (progress && progress.total_epochs)|| 3;
  const step     = (progress && progress.step)        || 0;
  const totStep  = (progress && progress.total_steps) || 1;
  const loss     = (progress && progress.loss)        || '--';
  const pct      = (progress && progress.pct)         || 0;
  const etaSec   = (progress && progress.eta_sec)     || 0;
  const ts       = (progress && progress.timestamp)   || '';
  const reason   = (progress && progress.reason)      || '';

  const stateColors = { running: '#00ff41', paused: '#ffb300', stopped: '#ff3333',
                        error: '#ff3333', starting: '#00e5ff', idle: '#557755' };
  const stateIcons  = { running: '▶', paused: '⏸', stopped: '■', error: '✗', starting: '…', idle: '○' };
  const color = stateColors[state] || '#557755';
  const icon  = stateIcons[state]  || '○';

  // Progress bar (20 chars)
  const filled = Math.min(20, Math.round(pct / 5));
  const bar    = '█'.repeat(filled) + '░'.repeat(20 - filled);

  // ETA formatter
  function fmtEta(s) {
    if (!s || s <= 0) return '--';
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h}h${String(m).padStart(2,'0')}min` : `${m}min`;
  }

  // Disable buttons based on state
  const isRunning = (state === 'running' || state === 'starting');
  const startDis  = isRunning  ? 'disabled' : '';
  const stopDis   = !isRunning ? 'disabled' : '';
  const pauseDis  = !isRunning ? 'disabled' : '';
  const resumeDis = state !== 'paused' ? 'disabled' : '';

  function psCmd(action) {
    if (!root) return '';
    const script = path.join(root, 'tools', 'lora', 'train_control.ps1').replace(/\\/g, '\\\\');
    return `powershell -ExecutionPolicy Bypass -File "${script}" -Action ${action} -StopAt ${stopAt}`;
  }

  return `<!DOCTYPE html><html><head><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Cascadia Code','Fira Code',Consolas,monospace; font-size:11px;
         background:#050a05; color:#c0c0c0; padding:8px; line-height:1.5; }
  .header { display:flex; justify-content:space-between; align-items:center;
            border-bottom:1px solid #1a2a1a; padding-bottom:6px; margin-bottom:8px; }
  .title  { font-size:13px; font-weight:bold; color:#00ff41; }
  .state  { font-size:11px; font-weight:bold; color:${color}; }
  .metric { display:flex; justify-content:space-between; margin:2px 0; }
  .label  { color:#557755; }
  .value  { color:#c0c0c0; }
  .bar    { color:#00ff41; letter-spacing:-0.5px; margin:4px 0; font-size:10px; }
  .pct    { color:#00e5ff; }
  .btns   { display:flex; gap:4px; margin-top:10px; flex-wrap:wrap; }
  button  { background:#0d150d; border:1px solid #1a3a1a; color:#00ff41;
            font-family:inherit; font-size:10px; padding:4px 8px; cursor:pointer;
            border-radius:2px; }
  button:hover:not(:disabled) { background:#1a3a1a; border-color:#00ff41; }
  button:disabled { opacity:0.3; cursor:not-allowed; }
  .stop-btn { color:#ff5555; border-color:#3a1a1a; }
  .stop-btn:hover:not(:disabled) { background:#3a1a1a; border-color:#ff5555; }
  .stop-at { margin-top:8px; display:flex; align-items:center; gap:6px; }
  .stop-at label { color:#557755; font-size:10px; }
  .stop-at input { background:#0d0d0d; border:1px solid #1a3a1a; color:#c0c0c0;
                   font-family:inherit; font-size:11px; padding:2px 4px; width:60px; }
  .hint { color:#333; font-size:9px; margin-top:6px; }
  .sched { margin-top:8px; font-size:9px; color:#557755; border-top:1px solid #1a2a1a; padding-top:6px;}
  .reason { color:#ffb300; font-size:9px; margin-top:4px; }
</style></head><body>
<div class="header">
  <span class="title">TRAINING</span>
  <span class="state">${icon} ${state.toUpperCase()}${pid ? ' [' + pid + ']' : ''}</span>
</div>
<div class="metric"><span class="label">Epoch</span><span class="value">${epoch}/${totEp}</span></div>
<div class="metric"><span class="label">Step</span><span class="value">${step}/${totStep}</span></div>
<div class="bar">${bar} <span class="pct">${pct.toFixed(1)}%</span></div>
<div class="metric"><span class="label">Loss</span><span class="value">${loss}</span></div>
<div class="metric"><span class="label">ETA</span><span class="value">${fmtEta(etaSec)}</span></div>
${ts ? `<div class="metric"><span class="label">Updated</span><span class="value" style="color:#444">${ts.slice(11)}</span></div>` : ''}
${reason ? `<div class="reason">↳ ${escapeHtml(reason)}</div>` : ''}

<div class="btns">
  <button id="btnStart" ${startDis} onclick="send('start')">▶ Start</button>
  <button id="btnPause" ${pauseDis} onclick="send('pause')">⏸ Pause</button>
  <button id="btnResume" ${resumeDis} onclick="send('resume')">▶ Resume</button>
  <button class="stop-btn" id="btnStop" ${stopDis} onclick="send('stop')">■ Stop</button>
</div>
<div class="stop-at">
  <label>Stop-at:</label>
  <input id="stopAt" type="text" value="${escapeHtml(stopAt)}" placeholder="08:00"
         onchange="send('set_stop_at', this.value)" />
  <button onclick="send('schedule')" title="Installer scheduler 00h00 nightly">📅</button>
  <button onclick="send('status')" title="Voir status complet">ℹ</button>
</div>
<div class="hint">Creer training_stop.flag pour arreter proprement</div>
<div class="sched">📅 Scheduler: <span id="schedState">Verif...</span></div>

<script>
  const vscode = acquireVsCodeApi();
  function send(action, value) { vscode.postMessage({ type: action, value: value || '' }); }
  // Check scheduler periodically via message reply
  vscode.postMessage({ type: 'check_scheduler' });
  window.addEventListener('message', e => {
    const msg = e.data;
    if (msg.type === 'scheduler_state') {
      document.getElementById('schedState').textContent = msg.active ? 'ACTIF (00h00 daily)' : 'inactif';
      document.getElementById('schedState').style.color = msg.active ? '#00ff41' : '#555';
    }
  });
</script>
</body></html>`;
}

class TrainingWebviewProvider {
  constructor(root) {
    this._root       = root;
    this._view       = null;
    this._stopAt     = '08:00';
    this._schedTimer = null;
  }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };

    webviewView.webview.onDidReceiveMessage((msg) => {
      switch (msg.type) {
        case 'start':
          this._runPS1(`-Action Start -StopAt ${this._stopAt} -Resume`);
          setTimeout(() => this._update(), 3000);
          break;
        case 'stop':
          this._runPS1('-Action Stop');
          setTimeout(() => this._update(), 2000);
          break;
        case 'pause':
          this._runPS1('-Action Pause');
          setTimeout(() => this._update(), 1000);
          break;
        case 'resume':
          this._runPS1('-Action Resume');
          setTimeout(() => this._update(), 1000);
          break;
        case 'schedule':
          this._runPS1(`-Action Schedule -StopAt ${this._stopAt}`);
          vscode.window.showInformationMessage('MERLIN Training: scheduler 00h00 installe!');
          break;
        case 'status':
          const terminal = vscode.window.createTerminal('Training Status');
          terminal.sendText(`cd "${this._root}" && powershell -ExecutionPolicy Bypass -File tools\\lora\\train_control.ps1 -Action Status`);
          terminal.show();
          break;
        case 'set_stop_at':
          if (msg.value && /^\d{2}:\d{2}$/.test(msg.value)) {
            this._stopAt = msg.value;
          }
          break;
        case 'check_scheduler':
          this._checkScheduler();
          break;
      }
    });

    this._update();
  }

  _runPS1(args) {
    if (!this._root) return;
    const script = path.join(this._root, 'tools', 'lora', 'train_control.ps1');
    const cmd = `powershell -ExecutionPolicy Bypass -File "${script}" ${args}`;
    cp.exec(cmd, { cwd: this._root }, (err) => {
      if (err && err.code !== 0) {
        vscode.window.showErrorMessage(`Training control error: ${err.message.slice(0, 100)}`);
      }
    });
  }

  _checkScheduler() {
    cp.exec('powershell -Command "if (Get-ScheduledTask -TaskName MERLIN_Training_Nightly -EA SilentlyContinue) { exit 0 } else { exit 1 }"',
      (err) => {
        if (this._view) {
          this._view.webview.postMessage({ type: 'scheduler_state', active: !err || err.code === 0 });
        }
      }
    );
  }

  _update() {
    if (!this._view || !this._root) return;
    const stateFile    = path.join(this._root, 'tools', 'lora', 'status', 'training_state.json');
    const progressFile = path.join(this._root, 'merlin-lora-cpu-output', 'progress.json');
    const ts = readJsonSafe(stateFile);
    const pr = readJsonSafe(progressFile);
    this._view.webview.html = buildTrainingHtml(ts, pr, this._root);
    this._checkScheduler();
  }

  refresh() { this._update(); }
}

// ============================================================
// ACTIVATE
// ============================================================

function activate(context) {
  const root = findProjectRoot();
  const statusDir = findStatusDir();

  // --- Live View panel ---
  const liveProvider = new LiveViewProvider();
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('autodev-v4.liveView', liveProvider)
  );
  context.subscriptions.push({ dispose: () => liveProvider.dispose() });

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
