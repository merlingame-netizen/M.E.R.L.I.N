// M.E.R.L.I.N. Orchestrator v6.0 — Autonomous Game Studio (48 agents, 5 modes)
// Panels: Game Control | Live View | Commands | Diagnostics | Overnight | Studio
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const cp = require('child_process');

// ============================================================
// CRT PALETTE
// ============================================================
const CRT = {
  bg: '#050a05', panel: '#080e08', green: '#00ff41', greenDim: '#00aa2a',
  amber: '#ffb300', cyan: '#00e5ff', red: '#ff3333', gray: '#555',
  text: '#b0c8b0', border: '#1a2a1a', magenta: '#cc66ff',
};

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

function capturesDir(root) {
  return path.join(root, 'tools', 'autodev', 'captures');
}

function readJsonSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch { return null; }
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function timeAgo(isoOrMs) {
  if (!isoOrMs) return '';
  const ms = typeof isoOrMs === 'number' ? isoOrMs : new Date(isoOrMs).getTime();
  const diff = Date.now() - ms;
  if (diff < 0) return 'now';
  const secs = Math.floor(diff / 1000);
  if (secs < 60) return secs + 's ago';
  const mins = Math.floor(secs / 60);
  if (mins < 60) return mins + 'min ago';
  return Math.floor(mins / 60) + 'h ago';
}

function progressBar(pct, width = 15) {
  const filled = Math.min(width, Math.round(pct * width / 100));
  return '\u2588'.repeat(filled) + '\u2591'.repeat(width - filled);
}

function fileAge(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return Date.now() - stat.mtimeMs;
  } catch { return Infinity; }
}

const CSS_BASE = `
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Cascadia Code','Fira Code',Consolas,monospace; font-size:11px;
         background:${CRT.bg}; color:${CRT.text}; padding:8px; line-height:1.5; user-select:none; }
  .header { display:flex; justify-content:space-between; align-items:center;
            padding-bottom:6px; border-bottom:1px solid ${CRT.border}; margin-bottom:8px; }
  .title { font-size:12px; font-weight:bold; color:${CRT.green}; letter-spacing:1px; }
  .status { font-size:11px; font-weight:bold; }
  .section { margin-bottom:10px; }
  .section-label { font-size:9px; color:${CRT.gray}; letter-spacing:1px; text-transform:uppercase; padding:4px 0 2px; }
  .empty { color:${CRT.gray}; font-size:10px; font-style:italic; padding:4px 0; }
  .sep { border-top:1px solid ${CRT.border}; margin:8px 0; }
  button { font-family:inherit; font-size:10px; border:1px solid ${CRT.border}; background:${CRT.panel};
           color:${CRT.greenDim}; cursor:pointer; padding:3px 7px; border-radius:2px; }
  button:hover { border-color:${CRT.green}; color:${CRT.green}; background:#0a1a0a; }
  button:active { background:#0d2a0d; }
  button:disabled { opacity:0.3; cursor:not-allowed; }
  .btn-row { display:flex; gap:4px; flex-wrap:wrap; margin:4px 0; }
  .btn-danger { color:${CRT.red}; border-color:#551111; }
  .btn-amber { color:${CRT.amber}; border-color:#553300; }
  .btn-cyan { color:${CRT.cyan}; border-color:#115555; }
  .btn-magenta { color:${CRT.magenta}; border-color:#441155; }
  table { width:100%; border-collapse:collapse; }
  td { padding:1px 4px; font-size:10px; }
  .k { color:${CRT.gray}; width:70px; }
  .v { color:${CRT.text}; }
  .v-good { color:${CRT.green}; }
  .v-warn { color:${CRT.amber}; }
  .v-bad { color:${CRT.red}; }
  ::-webkit-scrollbar { width:4px; }
  ::-webkit-scrollbar-thumb { background:${CRT.border}; }
`;

// ============================================================
// GODOT PROCESS MANAGER
// ============================================================

let _godotProcess = null;

function getGodotExe() {
  const candidates = [
    'C:\\Users\\PGNK2128\\Godot\\Godot_v4.5.1-stable_win64_console.exe',
    'C:\\Users\\PGNK2128\\Godot\\Godot_v4.5.1-stable_win64.exe',
  ];
  for (const c of candidates) { if (fs.existsSync(c)) return c; }
  return 'godot';
}

function isGodotRunning() { return _godotProcess !== null && !_godotProcess.killed; }

function launchGameBootstrap(root, onExit) {
  killGodot();
  const exe = getGodotExe();
  _godotProcess = cp.spawn(exe, [
    '--path', root,
    'scenes/BootstrapMerlinGame.tscn',
    '--rendering-driver', 'opengl3',
    '--resolution', '800x600',
  ], { detached: false, stdio: ['ignore', 'ignore', 'ignore'], windowsHide: false });
  _godotProcess.on('exit', () => { _godotProcess = null; if (onExit) onExit(); });
  _godotProcess.on('error', () => { _godotProcess = null; if (onExit) onExit(); });
}

function launchScene(scenePath, root, onExit) {
  killGodot();
  const exe = getGodotExe();
  const rel = path.relative(root, scenePath).replace(/\\/g, '/');
  _godotProcess = cp.spawn(exe, ['--path', root, rel, '--rendering-driver', 'opengl3'], {
    detached: false, stdio: ['ignore', 'ignore', 'ignore'], windowsHide: false });
  _godotProcess.on('exit', () => { _godotProcess = null; if (onExit) onExit(); });
  _godotProcess.on('error', () => { _godotProcess = null; if (onExit) onExit(); });
}

function killGodot() {
  if (!_godotProcess) return;
  try {
    if (process.platform === 'win32') {
      cp.exec(`taskkill /F /PID ${_godotProcess.pid} /T`);
    } else { _godotProcess.kill('SIGTERM'); }
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
    return match ? match[1] : null;
  } catch { return null; }
}

async function discoverScenes(root) {
  const uris = await vscode.workspace.findFiles('scenes/**/*.tscn', null, 200);
  const groups = {};
  for (const uri of uris) {
    const full = uri.fsPath;
    const rel = path.relative(root, full).replace(/\\/g, '/');
    const name = path.basename(full, '.tscn');
    const folder = path.relative(root, path.dirname(full)).replace(/\\/g, '/');
    const scriptRel = findScriptInScene(full);
    if (!groups[folder]) groups[folder] = [];
    groups[folder].push({ name, full, rel, scriptRel });
  }
  for (const grp of Object.values(groups)) grp.sort((a, b) => a.name.localeCompare(b.name));
  return groups;
}

// ============================================================
// COMMAND SENDER
// ============================================================

function sendGameCommand(root, action, params = {}) {
  const dir = capturesDir(root);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const cmd = { action, params, id: 'vsc_' + Date.now() };
  fs.writeFileSync(path.join(dir, 'command.json'), JSON.stringify(cmd, null, 2), 'utf8');
  return cmd.id;
}

function readCommandResult(root) {
  return readJsonSafe(path.join(capturesDir(root), 'command_result.json'));
}

// ============================================================
// PANEL 1 — GAME CONTROL
// ============================================================

class GameControlProvider {
  constructor(root) { this._root = root; this._view = null; this._groups = {}; }

  async resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.onDidReceiveMessage(async (msg) => {
      switch (msg.type) {
        case 'launch-bootstrap':
          launchGameBootstrap(this._root, () => this._update());
          setTimeout(() => this._update(), 1000);
          break;
        case 'launch-scene':
          launchScene(msg.scenePath, this._root, () => this._update());
          setTimeout(() => this._update(), 1000);
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
    const running = isGodotRunning();
    const statusColor = running ? CRT.green : CRT.gray;
    const statusIcon = running ? '\u25CF' : '\u25CB';

    let scenesHtml = '';
    const sorted = Object.keys(this._groups).sort();
    for (const folder of sorted) {
      const label = folder === 'scenes' ? 'scenes/' : folder + '/';
      const items = this._groups[folder].map(s => {
        const scriptBtn = s.scriptRel
          ? `<button class="btn-amber" style="min-width:22px;font-size:9px;padding:1px 5px" onclick="openScript('${escapeHtml(s.scriptRel)}')" title="${escapeHtml(s.scriptRel)}">{}</button>`
          : '';
        return `<div style="display:flex;align-items:center;gap:4px;padding:2px 4px;border-radius:2px" onmouseover="this.style.background='${CRT.panel}'" onmouseout="this.style.background='none'">
          <button style="min-width:22px;padding:1px 5px;color:${CRT.green}" onclick="launchScene('${escapeHtml(s.full)}')">\u25B6</button>
          ${scriptBtn}
          <span style="flex:1;font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:pointer" title="${escapeHtml(s.rel)}">${escapeHtml(s.name)}</span>
        </div>`;
      }).join('');
      scenesHtml += `<div class="section-label">${escapeHtml(label)}</div>${items}`;
    }

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}</style></head><body>
      <div class="header">
        <span class="title">GAME CONTROL</span>
        <span class="status" style="color:${statusColor}">${statusIcon} ${running ? 'RUNNING' : 'IDLE'}</span>
      </div>
      <div class="btn-row">
        <button style="flex:1;padding:5px 8px;font-size:11px;font-weight:bold;color:${CRT.green};border-color:${CRT.greenDim}" onclick="launchBootstrap()">\u25B6 Bootstrap</button>
        <button class="btn-danger" style="flex:1;padding:5px 8px;font-size:11px;font-weight:bold" onclick="kill()">\u25A0 Kill</button>
        <button class="btn-cyan" style="flex:1;padding:5px 8px;font-size:11px;font-weight:bold" onclick="validate()">\u2713 Validate</button>
      </div>
      <div class="sep"></div>
      ${scenesHtml || '<div class="empty">No scenes found</div>'}
      <script>
        const vscode = acquireVsCodeApi();
        function launchBootstrap() { vscode.postMessage({type:'launch-bootstrap'}); }
        function launchScene(p) { vscode.postMessage({type:'launch-scene', scenePath:p}); }
        function kill() { vscode.postMessage({type:'kill'}); }
        function validate() { vscode.postMessage({type:'validate'}); }
        function openScript(r) { vscode.postMessage({type:'open-script', scriptRel:r}); }
      </script>
    </body></html>`;
  }

  async _openScript(scriptRel) {
    const full = path.join(this._root, scriptRel);
    if (fs.existsSync(full)) {
      const doc = await vscode.workspace.openTextDocument(full);
      await vscode.window.showTextDocument(doc);
    }
  }

  _runValidate() {
    const terminal = vscode.window.createTerminal('Validate');
    terminal.sendText(`cd "${this._root}" && .\\validate.bat`);
    terminal.show();
  }

  refresh() { this._update(); }
}

// ============================================================
// PANEL 2 — LIVE VIEW
// ============================================================

class LiveViewProvider {
  constructor(root) { this._root = root; this._view = null; this._interval = null; }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.onDidReceiveMessage((msg) => {
      if (msg.type === 'screenshot') sendGameCommand(this._root, 'screenshot');
      if (msg.type === 'refresh') this._update();
    });
    this._interval = setInterval(() => this._update(), 3000);
    this._update();
  }

  _update() {
    if (!this._view) return;
    const dir = capturesDir(this._root);
    const screenshotPath = path.join(dir, 'latest.png');
    const state = readJsonSafe(path.join(dir, 'state.json'));
    const perf = readJsonSafe(path.join(dir, 'perf.json'));
    const log = readJsonSafe(path.join(dir, 'log.json')) || [];

    // Screenshot base64
    let screenshotSrc = '';
    const age = fileAge(screenshotPath);
    if (age < 300000) { // 5 min max
      try {
        const buf = fs.readFileSync(screenshotPath);
        screenshotSrc = 'data:image/png;base64,' + buf.toString('base64');
      } catch { /* ignore */ }
    }

    const running = isGodotRunning();
    const stateAge = state ? timeAgo(state.datetime || state.timestamp * 1000) : '';

    // State table
    const run = state ? state.run : null;
    let stateRows = '';
    if (run) {
      const lifeColor = (run.life || 0) < 30 ? CRT.red : (run.life || 0) < 60 ? CRT.amber : CRT.green;
      const aspects = run.aspects || {};
      const aspStr = `C:${aspects.Corps || 0} A:${aspects.Ame || 0} M:${aspects.Monde || 0}`;
      stateRows = [
        ['Phase', run.phase || '-', ''],
        ['Biome', (run.biome || '-').replace('foret_', ''), ''],
        ['Life', `${run.life || 0}/100`, lifeColor],
        ['Souffle', `${run.souffle || 0}/7`, ''],
        ['Aspects', aspStr, ''],
        ['Card #', String(run.cards_played || 0), ''],
        ['Mission', run.mission_type ? `${run.mission_progress}/${run.mission_total}` : '-', ''],
      ].map(([k, v, c]) => `<tr><td class="k">${k}</td><td class="${c ? '' : 'v'}" style="${c ? 'color:' + c : ''}">${escapeHtml(v)}</td></tr>`).join('');
    }

    // Perf row
    let perfHtml = '';
    if (perf) {
      const fpsColor = (perf.fps_avg || 0) < 30 ? CRT.red : (perf.fps_avg || 0) < 50 ? CRT.amber : CRT.green;
      const genMs = perf.card_gen_p50_ms || 0;
      const genColor = genMs > 15000 ? CRT.red : genMs > 10000 ? CRT.amber : CRT.green;
      perfHtml = `<div class="section-label">Performance</div><table>
        <tr><td class="k">FPS</td><td style="color:${fpsColor}">${(perf.fps_avg || 0).toFixed(0)}</td></tr>
        <tr><td class="k">Card gen p50</td><td style="color:${genColor}">${genMs > 0 ? (genMs / 1000).toFixed(1) + 's' : '-'}</td></tr>
        <tr><td class="k">Cards gen</td><td class="v">${perf.cards_generated || 0}</td></tr>
        <tr><td class="k">Fallback</td><td class="v">${((perf.fallback_rate || 0) * 100).toFixed(0)}%</td></tr>
      </table>`;
    }

    // Log tail
    const logLines = (Array.isArray(log) ? log : []).slice(-8);
    const logHtml = logLines.length > 0
      ? logLines.map(l => {
          let colored = escapeHtml(String(l));
          colored = colored.replace(/\[GameObserver\]/g, `<span style="color:${CRT.cyan}">[GameObserver]</span>`);
          colored = colored.replace(/\[TRIADE\]/g, `<span style="color:${CRT.amber}">[TRIADE]</span>`);
          colored = colored.replace(/\[MerlinStore\]/g, `<span style="color:${CRT.green}">[MerlinStore]</span>`);
          return `<div style="font-size:9px;color:${CRT.gray};white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin:1px 0">${colored}</div>`;
        }).join('')
      : '<div class="empty">No logs yet</div>';

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}
      .screenshot { width:100%; border:1px solid ${CRT.border}; display:block; margin-bottom:8px; image-rendering:pixelated; }
      .no-screenshot { background:${CRT.panel}; border:1px dashed ${CRT.border}; color:${CRT.gray};
                       text-align:center; padding:20px 8px; font-size:10px; margin-bottom:8px; }
    </style></head><body>
      <div class="header">
        <span class="title">LIVE VIEW</span>
        <span class="status" style="color:${running ? CRT.green : CRT.gray}">${running ? '\u25CF LIVE' : '\u25CB IDLE'}</span>
      </div>
      ${screenshotSrc
        ? `<img class="screenshot" src="${screenshotSrc}" title="Game screenshot">`
        : `<div class="no-screenshot">No screenshot available</div>`}
      ${stateAge ? `<div style="font-size:9px;color:${CRT.gray};margin-bottom:4px">State: ${stateAge}</div>` : ''}
      ${stateRows ? `<div class="section-label">Run State</div><table>${stateRows}</table>` : ''}
      ${perfHtml}
      <div class="sep"></div>
      <div class="section-label">Log</div>
      ${logHtml}
      <div class="btn-row" style="margin-top:6px">
        <button class="btn-amber" onclick="capture()">Capture</button>
        <button onclick="refresh()">Refresh</button>
      </div>
      <script>
        const vscode = acquireVsCodeApi();
        function capture() { vscode.postMessage({type:'screenshot'}); }
        function refresh() { vscode.postMessage({type:'refresh'}); }
      </script>
    </body></html>`;
  }

  dispose() { if (this._interval) { clearInterval(this._interval); this._interval = null; } }
}

// ============================================================
// PANEL 3 — COMMANDS
// ============================================================

class CommandsProvider {
  constructor(root) { this._root = root; this._view = null; this._interval = null; }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.onDidReceiveMessage((msg) => {
      if (msg.type === 'cmd') {
        sendGameCommand(this._root, msg.action, msg.params || {});
        vscode.window.setStatusBarMessage(`Sent: ${msg.action}`, 2000);
      }
    });
    this._interval = setInterval(() => this._update(), 5000);
    this._update();
  }

  _update() {
    if (!this._view) return;
    const result = readCommandResult(this._root);
    const resultHtml = result
      ? `<div style="font-size:9px;color:${result.status === 'ok' ? CRT.green : CRT.red};margin-top:4px">
           Last: ${escapeHtml(result.id)} = ${result.status}</div>`
      : '';

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}
      .cmd-grid { display:grid; grid-template-columns:1fr 1fr; gap:4px; }
      .cmd-btn { padding:6px 4px; font-size:10px; text-align:center; width:100%; }
    </style></head><body>
      <div class="header">
        <span class="title">COMMANDS</span>
        <span class="status" style="color:${CRT.cyan}">GameObserver</span>
      </div>

      <div class="section-label">Capture</div>
      <div class="cmd-grid">
        <button class="cmd-btn btn-amber" onclick="cmd('screenshot')">Screenshot</button>
        <button class="cmd-btn btn-magenta" onclick="cmd('burst_screenshot',{count:15,interval:0.12})">Burst x15</button>
      </div>

      <div class="section-label" style="margin-top:8px">Play</div>
      <div class="cmd-grid">
        <button class="cmd-btn" onclick="cmd('click_option',{option:1})">Option 1 (L)</button>
        <button class="cmd-btn" onclick="cmd('click_option',{option:2})">Option 2 (C)</button>
        <button class="cmd-btn" onclick="cmd('click_option',{option:3})">Option 3 (R)</button>
        <button class="cmd-btn btn-cyan" onclick="cmd('simulate_click',{x:400,y:300})">Click Center</button>
      </div>

      <div class="section-label" style="margin-top:8px">Keys</div>
      <div class="cmd-grid">
        <button class="cmd-btn" onclick="cmd('simulate_key',{key:'enter'})">Enter</button>
        <button class="cmd-btn" onclick="cmd('simulate_key',{key:'escape'})">Escape</button>
        <button class="cmd-btn" onclick="cmd('simulate_key',{key:'space'})">Space</button>
        <button class="cmd-btn" onclick="cmd('simulate_click',{x:400,y:500})">Click Bottom</button>
      </div>

      <div class="section-label" style="margin-top:8px">Inspect</div>
      <div class="cmd-grid">
        <button class="cmd-btn btn-cyan" onclick="cmd('list_buttons')">List Buttons</button>
        <button class="cmd-btn btn-cyan" onclick="cmd('get_tree_snapshot')">Scene Tree</button>
        <button class="cmd-btn" onclick="cmd('get_state')">Force State</button>
        <button class="cmd-btn" onclick="cmd('mark_card_gen_start')">Mark Gen Start</button>
      </div>

      ${resultHtml}
      <script>
        const vscode = acquireVsCodeApi();
        function cmd(action, params) { vscode.postMessage({type:'cmd', action, params: params||{}}); }
      </script>
    </body></html>`;
  }

  dispose() { if (this._interval) { clearInterval(this._interval); this._interval = null; } }
}

// ============================================================
// PANEL 4 — DIAGNOSTICS
// ============================================================

class DiagnosticsProvider {
  constructor(root) { this._root = root; this._view = null; this._interval = null; }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: false };
    this._interval = setInterval(() => this._update(), 5000);
    this._update();
  }

  _update() {
    if (!this._view) return;
    const dir = capturesDir(this._root);
    const state = readJsonSafe(path.join(dir, 'state.json'));
    const perf = readJsonSafe(path.join(dir, 'perf.json'));
    const screenshotExists = fs.existsSync(path.join(dir, 'latest.png')) && fileAge(path.join(dir, 'latest.png')) < 60000;

    const run = state ? state.run : null;

    // Build checklist evaluations from live data
    const checks = [];

    // Visual (auto-evaluate what we can)
    checks.push({ cat: 'VISUAL', name: 'Screenshot recent', pass: screenshotExists });
    checks.push({ cat: 'VISUAL', name: 'Game running', pass: isGodotRunning() });

    // Gameplay
    if (run) {
      checks.push({ cat: 'GAMEPLAY', name: 'Aspects changing', pass: run.aspects && (run.aspects.Corps !== 0 || run.aspects.Ame !== 0 || run.aspects.Monde !== 0) });
      checks.push({ cat: 'GAMEPLAY', name: 'Life < 100', pass: (run.life || 100) < 100 || (run.cards_played || 0) === 0 });
      checks.push({ cat: 'GAMEPLAY', name: 'Cards played > 0', pass: (run.cards_played || 0) > 0 });
      checks.push({ cat: 'GAMEPLAY', name: 'Souffle tracking', pass: run.souffle !== undefined });
      checks.push({ cat: 'GAMEPLAY', name: 'Phase valid', pass: ['card', 'minigame', 'narrator', 'hub', 'transition', 'intro'].includes(run.phase) });
    }

    // Performance
    if (perf) {
      checks.push({ cat: 'PERF', name: 'FPS > 30', pass: (perf.fps_avg || 0) > 30 });
      const p50 = perf.card_gen_p50_ms || 0;
      checks.push({ cat: 'PERF', name: 'Card gen p50 < 10s', pass: p50 === 0 || p50 < 10000 });
      checks.push({ cat: 'PERF', name: 'Fallback < 10%', pass: (perf.fallback_rate || 0) < 0.1 });
    }

    // Group by category
    const cats = {};
    for (const c of checks) {
      if (!cats[c.cat]) cats[c.cat] = [];
      cats[c.cat].push(c);
    }

    let checksHtml = '';
    for (const [cat, items] of Object.entries(cats)) {
      const passed = items.filter(i => i.pass).length;
      const total = items.length;
      const pct = Math.round(passed / total * 100);
      const color = pct === 100 ? CRT.green : pct >= 60 ? CRT.amber : CRT.red;
      checksHtml += `<div class="section-label">${cat} <span style="color:${color}">${passed}/${total}</span></div>`;
      for (const item of items) {
        const icon = item.pass ? `<span style="color:${CRT.green}">\u2713</span>` : `<span style="color:${CRT.red}">\u2717</span>`;
        checksHtml += `<div style="font-size:10px;margin:2px 0;display:flex;gap:6px">${icon} <span>${escapeHtml(item.name)}</span></div>`;
      }
    }

    // Known issues
    const issues = [];
    if (run && run.cards_played > 2 && run.aspects && run.aspects.Corps === 0 && run.aspects.Ame === 0 && run.aspects.Monde === 0) {
      issues.push({ sev: 'HIGH', text: 'Aspects stuck at 0/0/0 after ' + run.cards_played + ' cards' });
    }
    if (perf && perf.card_gen_p50_ms > 15000) {
      issues.push({ sev: 'HIGH', text: 'Card gen > 15s (p50: ' + (perf.card_gen_p50_ms / 1000).toFixed(1) + 's)' });
    }
    if (perf && perf.fps_avg && perf.fps_avg < 20) {
      issues.push({ sev: 'MEDIUM', text: 'Low FPS: ' + perf.fps_avg.toFixed(0) });
    }

    const issuesHtml = issues.length > 0
      ? issues.map(i => {
          const sevColor = i.sev === 'CRITICAL' ? CRT.red : i.sev === 'HIGH' ? CRT.amber : CRT.cyan;
          return `<div style="font-size:10px;margin:2px 0"><span style="color:${sevColor};font-weight:bold">[${i.sev}]</span> ${escapeHtml(i.text)}</div>`;
        }).join('')
      : '<div class="empty">No active issues</div>';

    // Overall score
    const totalPassed = checks.filter(c => c.pass).length;
    const totalChecks = checks.length;
    const overallPct = totalChecks > 0 ? Math.round(totalPassed / totalChecks * 100) : 0;
    const overallColor = overallPct === 100 ? CRT.green : overallPct >= 70 ? CRT.amber : CRT.red;

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}</style></head><body>
      <div class="header">
        <span class="title">DIAGNOSTICS</span>
        <span class="status" style="color:${overallColor}">${overallPct}%</span>
      </div>
      <div style="margin-bottom:8px;color:${overallColor};font-size:10px;letter-spacing:-0.5px">${progressBar(overallPct, 20)} ${totalPassed}/${totalChecks}</div>
      ${checksHtml}
      <div class="sep"></div>
      <div class="section-label">Active Issues</div>
      ${issuesHtml}
    </body></html>`;
  }

  dispose() { if (this._interval) { clearInterval(this._interval); this._interval = null; } }
}

// ============================================================
// PANEL 5 — OVERNIGHT
// ============================================================

class OvernightProvider {
  constructor(root) { this._root = root; this._view = null; this._interval = null; }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    webviewView.webview.options = { enableScripts: true };
    webviewView.webview.onDidReceiveMessage((msg) => {
      if (msg.type === 'open-report') this._openReport();
    });
    this._interval = setInterval(() => this._update(), 10000);
    this._update();
  }

  _update() {
    if (!this._view) return;
    const dir = capturesDir(this._root);
    const reportPath = path.join(dir, 'overnight_report.json');
    const report = readJsonSafe(reportPath);

    if (!report || !report.cycles || report.cycles.length === 0) {
      this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}</style></head><body>
        <div class="header">
          <span class="title">OVERNIGHT</span>
          <span class="status" style="color:${CRT.gray}">\u25CB STANDBY</span>
        </div>
        <div class="empty" style="margin-top:20px">No overnight session active.<br><br>
          Trigger overnight mode in Claude Code:<br>
          <span style="color:${CRT.cyan}">"overnight"</span> or <span style="color:${CRT.cyan}">"mode nuit"</span>
        </div>
        <div style="margin-top:12px;font-size:9px;color:${CRT.gray}">
          Parameters: 12 cycles, 8 cards/cycle, ~7h max<br>
          Report: overnight_report.json
        </div>
      </body></html>`;
      return;
    }

    const cycles = report.cycles;
    const latest = cycles[cycles.length - 1];
    const totalCards = cycles.reduce((s, c) => s + (c.cards_played || 0), 0);
    const totalIssues = cycles.reduce((s, c) => {
      const f = c.issues_found || {};
      return s + (f.critical || 0) + (f.high || 0) + (f.medium || 0) + (f.low || 0);
    }, 0);
    const totalFixed = cycles.reduce((s, c) => s + (c.issues_fixed || []).length, 0);

    const isActive = latest && !['time_limit', 'all_pass', 'crash_unrecoverable', 'context_limit'].includes(report.exit_reason);
    const statusColor = isActive ? CRT.green : CRT.amber;
    const statusText = isActive ? 'RUNNING' : (report.exit_reason || 'DONE');

    // Cycle progress
    const cyclePct = Math.round(cycles.length / (report.cycle_target || 12) * 100);

    // Checklist progression table
    let progressTable = '';
    if (cycles.length > 0) {
      progressTable = '<div class="section-label" style="margin-top:8px">Checklist Progression</div>';
      progressTable += '<table><tr><td class="k">Cycle</td><td class="k">Visual</td><td class="k">UX</td><td class="k">Game</td><td class="k">Perf</td></tr>';
      for (const c of cycles.slice(-6)) {
        const sc = c.checklist_scores || {};
        progressTable += `<tr>
          <td class="v">#${c.cycle || '?'}</td>
          <td class="v">${sc.visual || '-'}</td>
          <td class="v">${sc.ux || '-'}</td>
          <td class="v">${sc.gameplay || '-'}</td>
          <td class="v">${sc.perf || '-'}</td>
        </tr>`;
      }
      progressTable += '</table>';
    }

    // Recent fixes
    let fixesHtml = '';
    const allFixes = cycles.flatMap(c => (c.issues_fixed || []).map(f => ({ ...f, cycle: c.cycle })));
    if (allFixes.length > 0) {
      fixesHtml = '<div class="section-label" style="margin-top:8px">Fixes Applied</div>';
      for (const f of allFixes.slice(-5)) {
        const color = f.status === 'VERIFIED' ? CRT.green : CRT.amber;
        fixesHtml += `<div style="font-size:9px;margin:2px 0">
          <span style="color:${color}">\u2713</span> #${f.cycle} ${escapeHtml(f.description || f.file || '?')}
        </div>`;
      }
    }

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}</style></head><body>
      <div class="header">
        <span class="title">OVERNIGHT</span>
        <span class="status" style="color:${statusColor}">${statusText}</span>
      </div>

      <div style="margin-bottom:6px;color:${CRT.green};font-size:10px;letter-spacing:-0.5px">${progressBar(cyclePct, 20)} Cycle ${cycles.length}/${report.cycle_target || 12}</div>

      <table>
        <tr><td class="k">Cards played</td><td class="v">${totalCards}</td></tr>
        <tr><td class="k">Issues found</td><td class="v">${totalIssues}</td></tr>
        <tr><td class="k">Issues fixed</td><td style="color:${CRT.green}">${totalFixed}</td></tr>
        <tr><td class="k">Duration</td><td class="v">${report.duration || '-'}</td></tr>
      </table>

      ${progressTable}
      ${fixesHtml}

      <div class="sep"></div>
      <button onclick="openReport()" style="width:100%;padding:5px;font-size:10px">Open Full Report</button>
      <script>
        const vscode = acquireVsCodeApi();
        function openReport() { vscode.postMessage({type:'open-report'}); }
      </script>
    </body></html>`;
  }

  async _openReport() {
    const mdPath = path.join(capturesDir(this._root), 'overnight_report.md');
    const jsonPath = path.join(capturesDir(this._root), 'overnight_report.json');
    const target = fs.existsSync(mdPath) ? mdPath : jsonPath;
    if (fs.existsSync(target)) {
      const doc = await vscode.workspace.openTextDocument(target);
      await vscode.window.showTextDocument(doc);
    } else {
      vscode.window.showWarningMessage('No overnight report found');
    }
  }

  dispose() { if (this._interval) { clearInterval(this._interval); this._interval = null; } }
}

// ============================================================
// PANEL 6: STUDIO (Autonomous Game Studio dashboard)
// ============================================================

class StudioProvider {
  constructor(root) { this._root = root; this._view = null; this._interval = null; }
  resolveWebviewView(view) {
    this._view = view;
    view.webview.options = { enableScripts: true };
    view.webview.onDidReceiveMessage(msg => {
      if (msg.type === 'open-report' && msg.file) {
        const fp = path.join(capturesDir(this._root), msg.file);
        if (fs.existsSync(fp)) {
          vscode.workspace.openTextDocument(fp).then(d => vscode.window.showTextDocument(d));
        }
      }
    });
    this._update();
    this._interval = setInterval(() => this._update(), 10000);
    view.onDidDispose(() => { if (this._interval) clearInterval(this._interval); });
  }

  _update() {
    if (!this._view) return;
    const dir = capturesDir(this._root);

    // Read all studio agent reports
    const reports = [
      { key: 'playtest', file: 'playtest_log.json', label: 'Playtest Log', icon: '\u{1F3AE}' },
      { key: 'balance', file: 'balance_report.json', label: 'Balance Report', icon: '\u2696' },
      { key: 'stress', file: 'stress_test_report.json', label: 'Stress Test', icon: '\u26A1' },
      { key: 'visual_qa', file: 'visual_qa_report.json', label: 'Visual QA', icon: '\u{1F441}' },
      { key: 'regression', file: 'regression_log.json', label: 'Regression Log', icon: '\u{1F4C9}' },
      { key: 'release', file: 'release_quality_report.json', label: 'Release Quality', icon: '\u2705' },
    ];

    let cardsHtml = '';
    let activeCount = 0;

    for (const r of reports) {
      const fp = path.join(dir, r.file);
      let status = 'NO DATA';
      let statusColor = CRT.gray;
      let detail = '';
      let age = '';

      if (fs.existsSync(fp)) {
        try {
          const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
          age = fileAge(fp);
          activeCount++;

          if (r.key === 'playtest') {
            const runs = data.runs || [];
            status = `${runs.length} runs`;
            statusColor = runs.length >= 5 ? CRT.green : CRT.amber;
            const lastRun = runs[runs.length - 1];
            if (lastRun) detail = `Last: ${lastRun.archetype || '?'} (${lastRun.cards_played || '?'} cards)`;
          } else if (r.key === 'balance') {
            const anomalies = (data.anomalies || []).filter(a => a.severity === 'HIGH').length;
            status = anomalies > 0 ? `${anomalies} HIGH` : 'BALANCED';
            statusColor = anomalies > 0 ? CRT.red : CRT.green;
          } else if (r.key === 'stress') {
            const scenarios = data.scenarios || {};
            const fails = Object.values(scenarios).filter(s => s.status === 'FAIL').length;
            status = fails > 0 ? `${fails} FAIL` : 'ALL PASS';
            statusColor = fails > 0 ? CRT.red : CRT.green;
          } else if (r.key === 'visual_qa') {
            const summary = data.summary || {};
            const regressions = (summary.regression || 0) + (summary.breaking || 0);
            status = regressions > 0 ? `${regressions} REGRESS` : 'CLEAN';
            statusColor = regressions > 0 ? CRT.red : CRT.green;
            detail = `${summary.pass || 0} pass, ${summary.minor || 0} minor`;
          } else if (r.key === 'regression') {
            const entries = data.entries || [];
            const lastAlert = entries.filter(e => (e.regressions || []).length > 0);
            status = lastAlert.length > 0 ? `${lastAlert.length} alerts` : 'STABLE';
            statusColor = lastAlert.length > 0 ? CRT.amber : CRT.green;
          } else if (r.key === 'release') {
            status = data.verdict || 'UNKNOWN';
            statusColor = status === 'GO' ? CRT.green : status === 'NO-GO' ? CRT.red : CRT.amber;
            const score = data.score || {};
            detail = `${score.pass || 0}/${score.total || 62} pass`;
          }
        } catch (e) {
          status = 'PARSE ERROR';
          statusColor = CRT.red;
        }
      }

      cardsHtml += `<div style="background:${CRT.panel};border:1px solid ${CRT.border};padding:4px 6px;margin:3px 0;border-radius:2px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span style="font-size:10px">${r.icon} ${r.label}</span>
          <span style="font-size:9px;color:${statusColor};font-weight:bold">${status}</span>
        </div>
        ${detail ? `<div style="font-size:8px;color:${CRT.greenDim};margin-top:1px">${escapeHtml(detail)}</div>` : ''}
        ${age ? `<div style="font-size:8px;color:${CRT.gray};margin-top:1px">${age}</div>` : ''}
        ${fs.existsSync(path.join(dir, r.file)) ? `<div style="text-align:right"><a href="#" onclick="openFile('${r.file}')" style="font-size:8px;color:${CRT.cyan};text-decoration:none">[open]</a></div>` : ''}
      </div>`;
    }

    // Baseline status
    const baselineDir = path.join(dir, 'baseline');
    let baselineCount = 0;
    if (fs.existsSync(baselineDir)) {
      try { baselineCount = fs.readdirSync(baselineDir).filter(f => f.endsWith('.png')).length; } catch (e) {}
    }

    this._view.webview.html = `<!DOCTYPE html><html><head><style>${CSS_BASE}</style></head><body>
      <div class="header">
        <span class="title">STUDIO</span>
        <span class="status" style="color:${activeCount >= 4 ? CRT.green : activeCount > 0 ? CRT.amber : CRT.gray}">${activeCount}/${reports.length} active</span>
      </div>

      <div style="font-size:9px;color:${CRT.greenDim};margin-bottom:6px">48 agents | 10 studio agents | 5 modes</div>

      ${cardsHtml}

      <div class="sep"></div>
      <table>
        <tr><td class="k">Baseline screenshots</td><td class="v">${baselineCount}</td></tr>
      </table>

      <script>
        const vscode = acquireVsCodeApi();
        function openFile(f) { vscode.postMessage({type:'open-report', file: f}); }
      </script>
    </body></html>`;
  }

  refresh() { this._update(); }
  dispose() { if (this._interval) { clearInterval(this._interval); this._interval = null; } }
}

// ============================================================
// EXTENSION LIFECYCLE
// ============================================================

function activate(context) {
  const root = findProjectRoot();
  if (!root) {
    vscode.window.showWarningMessage('M.E.R.L.I.N. Orchestrator: No project.godot found');
    return;
  }

  // Ensure captures dir exists
  const dir = capturesDir(root);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  // Register all 6 providers
  const gameControl = new GameControlProvider(root);
  const liveView = new LiveViewProvider(root);
  const commands = new CommandsProvider(root);
  const diagnostics = new DiagnosticsProvider(root);
  const overnight = new OvernightProvider(root);
  const studio = new StudioProvider(root);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('autodev-v4.gameControl', gameControl),
    vscode.window.registerWebviewViewProvider('autodev-v4.liveView', liveView),
    vscode.window.registerWebviewViewProvider('autodev-v4.commands', commands),
    vscode.window.registerWebviewViewProvider('autodev-v4.diagnostics', diagnostics),
    vscode.window.registerWebviewViewProvider('autodev-v4.overnight', overnight),
    vscode.window.registerWebviewViewProvider('autodev-v4.studio', studio),
  );

  // Commands
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-v4.refresh', () => {
      gameControl.refresh();
      liveView._update();
      commands._update();
      diagnostics._update();
      overnight._update();
      studio._update();
    }),
    vscode.commands.registerCommand('autodev-v4.launchGame', () => {
      launchGameBootstrap(root, () => gameControl.refresh());
      setTimeout(() => gameControl.refresh(), 1000);
    }),
    vscode.commands.registerCommand('autodev-v4.killGodot', () => {
      killGodot();
      gameControl.refresh();
    }),
    vscode.commands.registerCommand('autodev-v4.validate', () => {
      const terminal = vscode.window.createTerminal('Validate');
      terminal.sendText(`cd "${root}" && .\\validate.bat`);
      terminal.show();
    }),
    vscode.commands.registerCommand('autodev-v4.sendCommand', async () => {
      const action = await vscode.window.showQuickPick(
        ['screenshot', 'burst_screenshot', 'click_option', 'list_buttons', 'get_tree_snapshot', 'get_state', 'simulate_click', 'simulate_key'],
        { placeHolder: 'Select command to send to game' }
      );
      if (action) {
        sendGameCommand(root, action);
        vscode.window.setStatusBarMessage(`Sent: ${action}`, 2000);
      }
    }),
  );

  // File watcher for captures dir
  const watcher = vscode.workspace.createFileSystemWatcher(
    new vscode.RelativePattern(dir, '*.{json,png}')
  );
  watcher.onDidChange(() => {
    liveView._update();
    diagnostics._update();
  });
  watcher.onDidCreate(() => {
    liveView._update();
    diagnostics._update();
  });
  context.subscriptions.push(watcher);

  console.log('M.E.R.L.I.N. Orchestrator v6.0 activated');
}

function deactivate() {
  // Cleanup handled by VS Code disposing subscriptions
}

module.exports = { activate, deactivate };
