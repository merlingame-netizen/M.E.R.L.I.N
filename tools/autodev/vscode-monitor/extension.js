// extension.js — AUTODEV Monitor VS Code Extension v4.0
// File-watch driven reactivity + hierarchical tree + action handlers + interactive controls
// Sidebar View (Activity Bar) + Panel (Ctrl+Alt+M)

const vscode = require('vscode');
const path = require('path');
const fs = require('fs');
const { readAllStatus, readDataStatus, readCoursStatus } = require('./providers/merlin_provider');
const { buildTaskRegistry, invalidate: invalidateRegistry } = require('./providers/task_registry');
const { LogTracker } = require('./providers/log_watcher');

let currentPanel = undefined;
let sidebarProvider = undefined;
let fileWatchers = [];
let fallbackInterval = undefined;
let debounceTimer = undefined;
let logDebounceTimer = undefined;
const logTracker = new LogTracker();

const DOMAINS = ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual'];
const DEBOUNCE_MS = 250;
const FALLBACK_POLL_MS = 10000;

/** Sanitize a domain or task ID to prevent path traversal (alphanumeric, hyphens, underscores, dots only). */
function sanitizeName(name) {
  if (!name || typeof name !== 'string') return '';
  return name.replace(/[^a-zA-Z0-9_\-\.]/g, '').substring(0, 100);
}

// ── Sidebar WebviewView Provider ───────────────────────────────

class AutodevSidebarProvider {
  constructor(extensionUri) {
    this._extensionUri = extensionUri;
    this._view = undefined;
    this._ready = false;
    this._pendingUpdates = [];
  }

  resolveWebviewView(webviewView) {
    this._view = webviewView;
    this._ready = false;

    webviewView.webview.options = {
      enableScripts: true,
    };

    webviewView.webview.html = this._getHtmlContent(webviewView.webview);

    webviewView.webview.onDidReceiveMessage(message => {
      if (message.command === 'ready') {
        this._ready = true;
        // Flush any pending updates
        sendFullUpdate();
        return;
      }
      handleWebviewMessage(message);
    });

    webviewView.onDidDispose(() => {
      this._view = undefined;
      this._ready = false;
    });

    // Progressive retries: 300ms, 1s, 3s, 6s — covers slow loads
    setTimeout(() => this._trySend(), 300);
    setTimeout(() => this._trySend(), 1000);
    setTimeout(() => this._trySend(), 3000);
    setTimeout(() => this._trySend(), 6000);
  }

  _trySend() {
    if (!this._view) return;
    sendFullUpdate();
  }

  update(data) {
    if (!this._view) return;
    this._view.webview.postMessage({ type: 'update', data });
  }

  _getHtmlContent(_webview) {
    // Inline all CSS and JS to eliminate external file loading issues
    const extDir = this._extensionUri.fsPath;
    const webviewDir = path.join(extDir, 'webview');

    let themeCSS = '', sidebarCSS = '', utilsJS = '', sidebarJS = '';
    try { themeCSS = fs.readFileSync(path.join(webviewDir, 'shared', 'theme.css'), 'utf8'); } catch { themeCSS = '/* theme.css not found */'; }
    try { sidebarCSS = fs.readFileSync(path.join(webviewDir, 'sidebar', 'sidebar.css'), 'utf8'); } catch { sidebarCSS = '/* sidebar.css not found */'; }
    try { utilsJS = fs.readFileSync(path.join(webviewDir, 'shared', 'utils.js'), 'utf8'); } catch { utilsJS = '/* utils.js not found */'; }
    try { sidebarJS = fs.readFileSync(path.join(webviewDir, 'sidebar', 'sidebar.js'), 'utf8'); } catch { sidebarJS = '/* sidebar.js not found */'; }

    // Log file loading status for debugging
    const loadStatus = [
      themeCSS.startsWith('/*') ? 'theme:FAIL' : 'theme:OK',
      sidebarCSS.startsWith('/*') ? 'css:FAIL' : 'css:OK',
      utilsJS.startsWith('/*') ? 'utils:FAIL' : 'utils:OK',
      sidebarJS.startsWith('/*') ? 'sidebar:FAIL' : 'sidebar:OK',
    ].join(' ');

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
  <style>${themeCSS}\n${sidebarCSS}</style>
  <title>AUTODEV</title>
</head>
<body>
  <div class="sidebar-header">
    <span class="header-title">&gt;_ AUTODEV</span>
    <span class="header-status">
      <span id="h-state" class="state-badge">--</span>
      <span id="h-time" class="clock">--:--</span>
    </span>
  </div>

  <div class="toolbar">
    <button class="toolbar-btn" onclick="postMessage({command:'refresh'})" title="Refresh data">&#x21BB;</button>
    <button class="toolbar-btn" onclick="postMessage({command:'openPanel'})" title="Open full dashboard (Ctrl+Alt+M)">&#x2398;</button>
    <button class="toolbar-btn toolbar-btn-start" id="btn-start" onclick="postMessage({command:'startPipeline'})" title="Start pipeline">&#x25B6;</button>
    <button class="toolbar-btn toolbar-btn-stop" id="btn-stop" onclick="postMessage({command:'stopPipeline'})" title="Stop pipeline">&#x25A0;</button>
    <button class="toolbar-btn" onclick="postMessage({command:'openLogs'})" title="Open logs folder">&#x1F4C4;</button>
    <button class="toolbar-btn" onclick="postMessage({command:'openConfig'})" title="Open config">&#x2699;</button>
  </div>

  <div class="tabs">
    <div class="tab active" data-project="merlin">MERLIN</div>
    <div class="tab" data-project="data">DATA</div>
    <div class="tab" data-project="cours">COURS</div>
  </div>

  <div id="project-merlin" class="project-view">
    <div class="loading-state">
      <div class="loading-spinner"></div>
      <div class="loading-text">Connecting...</div>
      <div class="loading-detail">${escapeHtmlInline(loadStatus)}</div>
    </div>
  </div>
  <div id="project-data" class="project-view" style="display:none"></div>
  <div id="project-cours" class="project-view" style="display:none"></div>

  <div id="update-indicator" class="update-indicator"></div>

  <script>${utilsJS}</script>
  <script>${sidebarJS}</script>
</body>
</html>`;
  }
}

/** Simple HTML escaper for use in template literals (Node.js side). */
function escapeHtmlInline(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// ── Activation ─────────────────────────────────────────────────

function activate(context) {
  // Register Sidebar View Provider
  sidebarProvider = new AutodevSidebarProvider(context.extensionUri);
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(
      'autodev-monitor.sidebarView',
      sidebarProvider,
      { webviewOptions: { retainContextWhenHidden: true } }
    )
  );

  // Register Panel command (Ctrl+Alt+M)
  const openPanel = vscode.commands.registerCommand('autodev-monitor.open', () => {
    if (currentPanel) {
      currentPanel.reveal(vscode.ViewColumn.Two);
      return;
    }

    currentPanel = vscode.window.createWebviewPanel(
      'autodevMonitor',
      'AUTODEV Monitor',
      vscode.ViewColumn.Two,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [
          vscode.Uri.file(path.join(context.extensionPath, 'webview')),
        ],
      }
    );

    currentPanel.webview.html = getPanelHtmlContent(currentPanel.webview, context.extensionPath);

    currentPanel.webview.onDidReceiveMessage(
      message => handleWebviewMessage(message),
      undefined,
      context.subscriptions
    );

    currentPanel.onDidDispose(() => {
      currentPanel = undefined;
    });

    sendFullUpdate();
  });
  context.subscriptions.push(openPanel);

  // Register Refresh command (Ctrl+Alt+R)
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-monitor.refresh', () => {
      sendFullUpdate();
      vscode.window.showInformationMessage('AUTODEV: Dashboard refreshed');
    })
  );

  // Register Start Pipeline command
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-monitor.startPipeline', () => {
      startPipeline();
    })
  );

  // Register Stop Pipeline command
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-monitor.stopPipeline', () => {
      stopPipeline();
    })
  );

  // Register Open Logs command
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-monitor.openLogs', () => {
      const projectRoot = findProjectRoot();
      if (projectRoot) {
        const logsDir = path.join(projectRoot, 'tools', 'autodev', 'logs');
        if (fs.existsSync(logsDir)) {
          vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(logsDir));
        } else {
          vscode.window.showWarningMessage('AUTODEV: Logs directory not found');
        }
      }
    })
  );

  // Register Open Config command
  context.subscriptions.push(
    vscode.commands.registerCommand('autodev-monitor.openConfig', () => {
      const projectRoot = findProjectRoot();
      if (projectRoot) {
        const configPath = path.join(projectRoot, 'tools', 'autodev', 'config', 'work_units_v2.json');
        if (fs.existsSync(configPath)) {
          vscode.workspace.openTextDocument(configPath).then(doc => {
            vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
          });
        }
      }
    })
  );

  // Initialize task registry
  const projectRoot = findProjectRoot();
  if (projectRoot) {
    const configPath = path.join(projectRoot, 'tools', 'autodev', 'config', 'work_units_v2.json');
    buildTaskRegistry(configPath);
  }

  // Start file watchers
  startFileWatchers();

  // Fallback poll (catches missed fs.watch events on Windows)
  fallbackInterval = setInterval(sendFullUpdate, FALLBACK_POLL_MS);

  // Initial data push
  sendFullUpdate();
}

// ── Pipeline Control ─────────────────────────────────────────

function startPipeline() {
  const projectRoot = findProjectRoot();
  if (!projectRoot) {
    vscode.window.showErrorMessage('AUTODEV: Project root not found');
    return;
  }

  const controlScript = path.join(projectRoot, 'tools', 'autodev', 'control.ps1');
  if (!fs.existsSync(controlScript)) {
    vscode.window.showErrorMessage('AUTODEV: control.ps1 not found');
    return;
  }

  const terminal = vscode.window.createTerminal({
    name: 'AUTODEV Pipeline',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(`.\\tools\\autodev\\control.ps1 -Action Start -Wave`);

  vscode.window.showInformationMessage('AUTODEV: Pipeline starting...');
  setTimeout(sendFullUpdate, 2000);
}

function stopPipeline() {
  const projectRoot = findProjectRoot();
  if (!projectRoot) return;

  const controlScript = path.join(projectRoot, 'tools', 'autodev', 'control.ps1');
  if (!fs.existsSync(controlScript)) {
    vscode.window.showErrorMessage('AUTODEV: control.ps1 not found');
    return;
  }

  const terminal = vscode.window.createTerminal({
    name: 'AUTODEV Stop',
    cwd: projectRoot,
  });
  terminal.show();
  terminal.sendText(`.\\tools\\autodev\\control.ps1 -Action Stop`);

  vscode.window.showInformationMessage('AUTODEV: Pipeline stopping...');
  setTimeout(sendFullUpdate, 2000);
}

// ── File Watchers ─────────────────────────────────────────────

function startFileWatchers() {
  stopFileWatchers();

  const projectRoot = findProjectRoot();
  if (!projectRoot) return;

  const statusDir = path.join(projectRoot, 'tools', 'autodev', 'status');
  const logsDir = path.join(projectRoot, 'tools', 'autodev', 'logs');
  const configPath = path.join(projectRoot, 'tools', 'autodev', 'config', 'work_units_v2.json');

  // Watch status/ directory for JSON changes
  try {
    if (fs.existsSync(statusDir)) {
      const watcher = fs.watch(statusDir, { recursive: false }, (event, filename) => {
        try {
          if (filename && filename.endsWith('.json')) {
            scheduleStatusUpdate();
          }
        } catch (err) { console.error('[AUTODEV Monitor] status watcher callback error:', err.message); }
      });
      watcher.on('error', (err) => {
        console.error('[AUTODEV Monitor] status watcher died:', err.message);
        setTimeout(startFileWatchers, 5000);
      });
      fileWatchers.push(watcher);
    }
  } catch { /* directory may not exist */ }

  // Watch status/feedback/ subdirectory
  const feedbackDir = path.join(statusDir, 'feedback');
  try {
    if (fs.existsSync(feedbackDir)) {
      const watcher = fs.watch(feedbackDir, { recursive: false }, (event, filename) => {
        if (filename && filename.endsWith('.json')) {
          scheduleStatusUpdate();
        }
      });
      fileWatchers.push(watcher);
    }
  } catch { /* */ }

  // Watch status/patches/ subdirectory
  const patchesDir = path.join(statusDir, 'patches');
  try {
    if (fs.existsSync(patchesDir)) {
      const watcher = fs.watch(patchesDir, { recursive: false }, (event, filename) => {
        if (filename && filename.endsWith('.json')) {
          scheduleStatusUpdate();
        }
      });
      fileWatchers.push(watcher);
    }
  } catch { /* */ }

  // Watch logs/ directory for log updates
  try {
    if (fs.existsSync(logsDir)) {
      const watcher = fs.watch(logsDir, { recursive: false }, (event, filename) => {
        if (filename && filename.endsWith('.log')) {
          scheduleLogUpdate(logsDir, filename);
        }
      });
      fileWatchers.push(watcher);
    }
  } catch { /* */ }

  // Watch config file for registry rebuild
  try {
    if (fs.existsSync(configPath)) {
      const watcher = fs.watch(configPath, () => {
        invalidateRegistry();
        scheduleStatusUpdate();
      });
      fileWatchers.push(watcher);
    }
  } catch { /* */ }
}

function stopFileWatchers() {
  for (const w of fileWatchers) {
    try { w.close(); } catch { /* */ }
  }
  fileWatchers = [];
}

function scheduleStatusUpdate() {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(sendFullUpdate, DEBOUNCE_MS);
}

function scheduleLogUpdate(logsDir, filename) {
  clearTimeout(logDebounceTimer);
  logDebounceTimer = setTimeout(() => {
    const matchedDomain = DOMAINS.find(d => filename.startsWith(d));
    if (!matchedDomain) return;

    const result = logTracker.getNewLinesForDomain(logsDir, matchedDomain);
    if (result.lines.length > 0) {
      sendLogAppend(matchedDomain, result.lines);
    }
  }, DEBOUNCE_MS);
}

// ── Data Sending ──────────────────────────────────────────────

function sendFullUpdate() {
  try {
    const projectRoot = findProjectRoot();
    console.log('[AUTODEV Monitor] sendFullUpdate: root=' + (projectRoot || 'NULL'));

    const data = {
      merlin: projectRoot ? readAllStatus(projectRoot) : null,
      data: readDataStatus(),
      cours: readCoursStatus(),
      _meta: {
        timestamp: new Date().toISOString(),
        projectRoot: projectRoot || null,
        watchersActive: fileWatchers.length,
      },
    };

    const ctrl = data.merlin && data.merlin.control;
    console.log('[AUTODEV Monitor] sendFullUpdate: state=' +
      (ctrl ? ctrl.state : 'no-ctrl') +
      ' wave=' + (ctrl ? ctrl.wave : '-') +
      ' cycle=' + (ctrl ? ctrl.cycle : '-') +
      ' workers=' + (data.merlin ? data.merlin.counts.workers_total : 0));

    const hasSidebar = !!(sidebarProvider && sidebarProvider._view);
    const hasPanel = !!currentPanel;
    console.log('[AUTODEV Monitor] sendFullUpdate: sidebar=' + hasSidebar + ' panel=' + hasPanel);

    if (hasSidebar) {
      sidebarProvider._view.webview.postMessage({ type: 'update', data });
    }
    if (hasPanel) {
      currentPanel.webview.postMessage({ type: 'update', data });
    }
  } catch (err) {
    console.error('[AUTODEV Monitor] sendFullUpdate error:', err.message, err.stack);
    const fallbackData = {
      merlin: { project: 'M.E.R.L.I.N.', control: { state: 'error', cycle: 0, wave: '-', detail: 'Data read error: ' + (err.message || '').substring(0, 80) }, pipeline_tree: { director: null, workers: [], reviews: [] }, counts: { workers_total: 8, workers_done: 0, workers_error: 0, workers_active: 0, reviews_total: 3, reviews_done: 0, agents_total: 33, agents_active: 0 }, health: null, questions: null, agents: [], timestamp: new Date().toISOString() },
      data: null,
      cours: null,
      _meta: { timestamp: new Date().toISOString(), error: err.message },
    };
    try {
      if (sidebarProvider && sidebarProvider._view) {
        sidebarProvider._view.webview.postMessage({ type: 'update', data: fallbackData });
      }
      if (currentPanel) {
        currentPanel.webview.postMessage({ type: 'update', data: fallbackData });
      }
    } catch { /* last resort — ignore */ }
  }
}

function sendLogAppend(domain, lines) {
  const msg = { type: 'log_append', domain, lines };
  if (sidebarProvider && sidebarProvider._view) {
    sidebarProvider._view.webview.postMessage(msg);
  }
  if (currentPanel) {
    currentPanel.webview.postMessage(msg);
  }
}

// ── Project Root Discovery ─────────────────────────────────────

function findProjectRoot() {
  if (vscode.workspace.workspaceFolders) {
    for (const folder of vscode.workspace.workspaceFolders) {
      const candidate = folder.uri.fsPath;
      if (fs.existsSync(path.join(candidate, 'tools', 'autodev', 'status'))) {
        return candidate;
      }
    }
  }

  const root = path.resolve(__dirname, '..', '..', '..');
  if (fs.existsSync(path.join(root, 'tools', 'autodev', 'status'))) {
    return root;
  }

  return null;
}

// ── Message Handler ────────────────────────────────────────────

function handleWebviewMessage(message) {
  const projectRoot = findProjectRoot();
  const statusDir = projectRoot ? path.join(projectRoot, 'tools', 'autodev', 'status') : '';

  switch (message.command) {
    case 'ready':
      sendFullUpdate();
      break;

    case 'refresh':
      sendFullUpdate();
      break;

    case 'startPipeline':
      startPipeline();
      break;

    case 'stopPipeline':
      stopPipeline();
      break;

    case 'openLogs':
      vscode.commands.executeCommand('autodev-monitor.openLogs');
      break;

    case 'openConfig':
      vscode.commands.executeCommand('autodev-monitor.openConfig');
      break;

    case 'openLogFile': {
      if (!projectRoot || !message.domain) break;
      const domain = sanitizeName(message.domain);
      const logsDir = path.join(projectRoot, 'tools', 'autodev', 'logs');
      // Find latest log file for domain
      try {
        if (fs.existsSync(logsDir)) {
          const files = fs.readdirSync(logsDir)
            .filter(f => f.startsWith(domain) && f.endsWith('.log'))
            .sort()
            .reverse();
          if (files.length > 0) {
            const logPath = path.join(logsDir, files[0]);
            vscode.workspace.openTextDocument(logPath).then(doc => {
              vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
            });
          } else {
            vscode.window.showWarningMessage(`AUTODEV: No log files found for ${domain}`);
          }
        }
      } catch { /* */ }
      break;
    }

    case 'openStatusFile': {
      if (!projectRoot || !message.domain) break;
      const domain = sanitizeName(message.domain);
      const feedbackPath = path.join(statusDir, 'feedback', domain + '.json');
      const statusPath = path.join(statusDir, domain + '.json');
      const filePath = fs.existsSync(feedbackPath) ? feedbackPath : fs.existsSync(statusPath) ? statusPath : null;
      if (filePath) {
        vscode.workspace.openTextDocument(filePath).then(doc => {
          vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
        });
      }
      break;
    }

    case 'openFile': {
      if (!projectRoot || !message.path) break;
      const normalizedFile = path.resolve(message.path);
      if (!normalizedFile.startsWith(path.resolve(projectRoot))) break;
      if (fs.existsSync(normalizedFile)) {
        vscode.workspace.openTextDocument(normalizedFile).then(doc => {
          vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
        });
      }
      break;
    }

    case 'openPanel':
      vscode.commands.executeCommand('autodev-monitor.open');
      if (message.domain) {
        setTimeout(() => {
          if (currentPanel) {
            currentPanel.webview.postMessage({ type: 'selectNode', domain: message.domain });
          }
        }, 300);
      }
      break;

    case 'respondEscalation': {
      if (!statusDir) break;
      const VALID_DECISIONS = ['proceed', 'rollback', 'override', 'custom'];
      const rawDecision = String(message.decision || 'proceed');
      const decision = VALID_DECISIONS.includes(rawDecision) ? rawDecision : 'proceed';
      const details = String(message.details || '').substring(0, 2000);
      const rawAnswers = (message.answers && typeof message.answers === 'object') ? message.answers : {};
      const answers = {};
      for (const [k, v] of Object.entries(rawAnswers)) {
        if (typeof k === 'string' && k.length < 100 && typeof v === 'string' && v.length < 1000) {
          answers[k] = v;
        }
      }
      const responsePath = path.join(statusDir, 'human_response.json');
      const response = {
        decision,
        details,
        responded_by: 'vscode_monitor_v4',
        timestamp: new Date().toISOString(),
        answers,
      };
      try {
        fs.writeFileSync(responsePath, JSON.stringify(response, null, 2), 'utf8');
        vscode.window.showInformationMessage('AUTODEV: Response sent — ' + decision);
      } catch (err) {
        vscode.window.showErrorMessage('AUTODEV: Failed to write response — ' + err.message);
      }
      break;
    }

    case 'retryWorker': {
      if (!statusDir) break;
      const retryDomain = sanitizeName(message.domain);
      if (!retryDomain) break;
      const actionsDir = path.join(statusDir, 'actions');
      try {
        if (!fs.existsSync(actionsDir)) fs.mkdirSync(actionsDir, { recursive: true });
        const actionPath = path.join(actionsDir, `${retryDomain}_retry.json`);
        fs.writeFileSync(actionPath, JSON.stringify({
          action: 'retry',
          domain: retryDomain,
          timestamp: new Date().toISOString(),
          source: 'vscode_monitor_v4',
        }, null, 2), 'utf8');
        vscode.window.showInformationMessage(`AUTODEV: Retry requested for ${retryDomain}`);
      } catch (err) {
        vscode.window.showErrorMessage('AUTODEV: Failed to request retry — ' + err.message);
      }
      break;
    }

    case 'skipTask': {
      if (!statusDir) break;
      const skipDomain = sanitizeName(message.domain);
      const skipTaskId = sanitizeName(message.taskId);
      if (!skipDomain || !skipTaskId) break;
      const actionsDir2 = path.join(statusDir, 'actions');
      try {
        if (!fs.existsSync(actionsDir2)) fs.mkdirSync(actionsDir2, { recursive: true });
        const actionPath = path.join(actionsDir2, `${skipDomain}_skip.json`);
        fs.writeFileSync(actionPath, JSON.stringify({
          action: 'skip_task',
          domain: skipDomain,
          task_id: skipTaskId,
          timestamp: new Date().toISOString(),
          source: 'vscode_monitor_v4',
        }, null, 2), 'utf8');
        vscode.window.showInformationMessage(`AUTODEV: Skip requested for ${skipTaskId} in ${skipDomain}`);
      } catch (err) {
        vscode.window.showErrorMessage('AUTODEV: Failed to request skip — ' + err.message);
      }
      break;
    }

    case 'openWorktree': {
      if (!projectRoot) break;
      const wtDomain = sanitizeName(message.domain);
      if (!wtDomain) break;
      const worktreeBase = path.join(path.dirname(projectRoot), 'Godot-MCP-worktrees', wtDomain);
      if (fs.existsSync(worktreeBase)) {
        const uri = vscode.Uri.file(worktreeBase);
        vscode.commands.executeCommand('vscode.openFolder', uri, true);
      } else {
        vscode.window.showWarningMessage(`AUTODEV: Worktree not found at ${worktreeBase}`);
      }
      break;
    }

    case 'validate': {
      if (!projectRoot) break;
      const terminal = vscode.window.createTerminal({
        name: 'AUTODEV Validate',
        cwd: projectRoot,
      });
      terminal.show();
      terminal.sendText('.\\validate.bat');
      break;
    }

    case 'cleanStatus': {
      if (!statusDir) break;
      try {
        const cleanDomains = ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual'];
        for (const d of cleanDomains) {
          const p = path.join(statusDir, d + '.json');
          if (fs.existsSync(p)) {
            fs.writeFileSync(p, JSON.stringify({ domain: d, status: 'idle', timestamp: new Date().toISOString() }, null, 2), 'utf8');
          }
        }
        // Remove stale director/escalation files
        for (const f of ['director_decision.json', 'director_questions.json', 'human_response.json', 'director_directives.json']) {
          const p = path.join(statusDir, f);
          if (fs.existsSync(p)) {
            try { fs.unlinkSync(p); } catch { /* */ }
          }
        }
        // Clean feedback files
        const feedbackDir = path.join(statusDir, 'feedback');
        if (fs.existsSync(feedbackDir)) {
          for (const d of cleanDomains) {
            const p = path.join(feedbackDir, d + '.json');
            if (fs.existsSync(p)) {
              try { fs.unlinkSync(p); } catch { /* */ }
            }
          }
        }
        vscode.window.showInformationMessage('AUTODEV: Status files cleaned');
        console.log('[AUTODEV Monitor] cleanStatus: reset all domain + director files');
        sendFullUpdate();
      } catch (err) {
        vscode.window.showErrorMessage('AUTODEV: Failed to clean status — ' + err.message);
      }
      break;
    }
  }
}

// ── Panel HTML ────────────────────────────────────────────────

function getPanelHtmlContent(webview, extensionPath) {
  const webviewDir = path.join(extensionPath, 'webview');
  const themeUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'shared', 'theme.css')));
  const styleUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'panel', 'panel.css')));
  const utilsUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'shared', 'utils.js')));
  const scriptUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'panel', 'panel.js')));

  const htmlPath = path.join(webviewDir, 'panel', 'index.html');
  if (fs.existsSync(htmlPath)) {
    let html = fs.readFileSync(htmlPath, 'utf8');
    html = html.replace(/\{\{themeUri\}\}/g, themeUri.toString());
    html = html.replace(/\{\{styleUri\}\}/g, styleUri.toString());
    html = html.replace(/\{\{utilsUri\}\}/g, utilsUri.toString());
    html = html.replace(/\{\{scriptUri\}\}/g, scriptUri.toString());
    html = html.replace(/\{\{cspSource\}\}/g, webview.cspSource);
    return html;
  }

  return `<!DOCTYPE html><html><body><div style="color:#00ff41;font-family:monospace;padding:20px">AUTODEV Monitor v4.0 — Panel HTML not found</div></body></html>`;
}

// ── Deactivation ───────────────────────────────────────────────

function deactivate() {
  stopFileWatchers();
  logTracker.resetAll();
  if (fallbackInterval) {
    clearInterval(fallbackInterval);
    fallbackInterval = undefined;
  }
  clearTimeout(debounceTimer);
  clearTimeout(logDebounceTimer);
}

module.exports = { activate, deactivate };
