// extension.js — AUTODEV Monitor VS Code Extension v2.0
// Sidebar View (Activity Bar icon) + Panel (Ctrl+Alt+M)
// Polls status every 10s, updates both views

const vscode = require('vscode');
const path = require('path');
const fs = require('fs');
const { readAllStatus, readDataStatus, readCoursStatus } = require('./providers/merlin_provider');

let currentPanel = undefined;
let pollInterval = undefined;
let sidebarProvider = undefined;

// ── Sidebar WebviewView Provider ───────────────────────────────

class AutodevSidebarProvider {
  constructor(extensionUri) {
    this._extensionUri = extensionUri;
    this._view = undefined;
  }

  resolveWebviewView(webviewView) {
    this._view = webviewView;

    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [
        vscode.Uri.joinPath(this._extensionUri, 'webview'),
      ],
    };

    webviewView.webview.html = this._getHtmlContent(webviewView.webview);

    webviewView.webview.onDidReceiveMessage(message => {
      handleWebviewMessage(message);
    });

    webviewView.onDidDispose(() => {
      this._view = undefined;
    });

    // Immediately send data
    this.update();
  }

  update() {
    if (!this._view) return;

    const projectRoot = findProjectRoot();
    const data = {
      merlin: projectRoot ? readAllStatus(projectRoot) : null,
      data: readDataStatus(),
      cours: readCoursStatus(),
    };

    this._view.webview.postMessage({ type: 'update', data });
  }

  _getHtmlContent(webview) {
    const webviewDir = vscode.Uri.joinPath(this._extensionUri, 'webview');
    const styleUri = webview.asWebviewUri(vscode.Uri.joinPath(webviewDir, 'sidebar.css'));
    const scriptUri = webview.asWebviewUri(vscode.Uri.joinPath(webviewDir, 'sidebar.js'));

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src ${webview.cspSource} 'unsafe-inline'; font-src ${webview.cspSource};">
  <link rel="stylesheet" href="${styleUri}">
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

  <div class="tabs">
    <div class="tab active" data-project="merlin">MERLIN</div>
    <div class="tab" data-project="data">DATA</div>
    <div class="tab" data-project="cours">COURS</div>
  </div>

  <div id="project-merlin" class="project-view">
    <details class="section" open>
      <summary class="section-title">PIPELINE <span class="count" id="pipeline-info">C- W-</span></summary>
      <div class="pipeline-bar">
        <span id="p-cycle" class="pill">Cycle -</span>
        <span id="p-wave" class="pill wave">Wave -</span>
      </div>
    </details>

    <details class="section" open>
      <summary class="section-title">WORKERS <span class="count" id="worker-count">(0/5)</span></summary>
      <div id="workers-list"></div>
    </details>

    <details class="section">
      <summary class="section-title">AGENTS <span class="count" id="agent-count">(0)</span></summary>
      <div id="agents-list"></div>
    </details>

    <details class="section" open>
      <summary class="section-title">DIRECTOR</summary>
      <div id="director-content"></div>
    </details>

    <details class="section">
      <summary class="section-title">LOGS <span class="count" id="log-count">(0)</span></summary>
      <div class="log-container">
        <div class="log-entries" id="log-entries"></div>
      </div>
    </details>
  </div>

  <div id="project-data" class="project-view" style="display:none">
    <details class="section" open>
      <summary class="section-title">AGENTS <span class="count" id="data-agent-count">(0)</span></summary>
      <div id="data-agents-list"></div>
    </details>
    <div class="placeholder-compact">No active pipeline</div>
  </div>

  <div id="project-cours" class="project-view" style="display:none">
    <details class="section" open>
      <summary class="section-title">AGENTS <span class="count" id="cours-agent-count">(0)</span></summary>
      <div id="cours-agents-list"></div>
    </details>
    <div class="placeholder-compact">No active pipeline</div>
  </div>

  <script src="${scriptUri}"></script>
</body>
</html>`;
  }
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

    // Send initial data to panel
    pollAndSend();
  });
  context.subscriptions.push(openPanel);

  // Start global polling (shared by sidebar + panel)
  pollAndSend();
  pollInterval = setInterval(pollAndSend, 10000);
}

// ── Polling ────────────────────────────────────────────────────

function pollAndSend() {
  const projectRoot = findProjectRoot();
  const data = {
    merlin: projectRoot ? readAllStatus(projectRoot) : null,
    data: readDataStatus(),
    cours: readCoursStatus(),
  };

  // Send same data to both views (avoid double file reads)
  if (sidebarProvider && sidebarProvider._view) {
    sidebarProvider._view.webview.postMessage({ type: 'update', data });
  }

  if (currentPanel) {
    currentPanel.webview.postMessage({ type: 'update', data });
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

  // __dirname = vscode-monitor/ -> autodev/ -> tools/ -> project-root (3 levels)
  const root = path.resolve(__dirname, '..', '..', '..');
  if (fs.existsSync(path.join(root, 'tools', 'autodev', 'status'))) {
    return root;
  }

  return null;
}

// ── Message Handler ────────────────────────────────────────────

function handleWebviewMessage(message) {
  switch (message.command) {
    case 'refresh':
      pollAndSend();
      break;
    case 'openFile': {
      const filePath = message.path;
      if (filePath && fs.existsSync(filePath)) {
        vscode.workspace.openTextDocument(filePath).then(doc => {
          vscode.window.showTextDocument(doc, vscode.ViewColumn.One);
        });
      }
      break;
    }
    case 'respondEscalation': {
      const statusDir = path.join(findProjectRoot() || '', 'tools', 'autodev', 'status');
      const responsePath = path.join(statusDir, 'human_response.json');
      const response = {
        decision: message.decision || 'proceed',
        details: message.details || '',
        responded_by: 'vscode_monitor',
        timestamp: new Date().toISOString(),
      };
      try {
        fs.writeFileSync(responsePath, JSON.stringify(response, null, 2), 'utf8');
        vscode.window.showInformationMessage('AUTODEV: Response sent — ' + response.decision);
      } catch (err) {
        vscode.window.showErrorMessage('AUTODEV: Failed to write response — ' + err.message);
      }
      break;
    }
    case 'openPanel':
      vscode.commands.executeCommand('autodev-monitor.open');
      break;
  }
}

// ── Panel HTML (full 2x2 grid — existing layout) ───────────────

function getPanelHtmlContent(webview, extensionPath) {
  const webviewDir = path.join(extensionPath, 'webview');
  const styleUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'style.css')));
  const scriptUri = webview.asWebviewUri(vscode.Uri.file(path.join(webviewDir, 'dashboard.js')));

  const htmlPath = path.join(webviewDir, 'index.html');
  if (fs.existsSync(htmlPath)) {
    let html = fs.readFileSync(htmlPath, 'utf8');
    html = html.replace(/\{\{styleUri\}\}/g, styleUri.toString());
    html = html.replace(/\{\{scriptUri\}\}/g, scriptUri.toString());
    html = html.replace(/\{\{cspSource\}\}/g, webview.cspSource);
    return html;
  }

  return '<!DOCTYPE html><html><body><div>AUTODEV Monitor — Panel</div></body></html>';
}

// ── Deactivation ───────────────────────────────────────────────

function deactivate() {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = undefined;
  }
}

module.exports = { activate, deactivate };
