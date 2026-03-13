const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const http = require('http');
const https = require('https');

const CRT = {
  bg: '#050a05',
  panel: '#080e08',
  green: '#00ff41',
  greenDim: '#00aa2a',
  amber: '#ffb300',
  cyan: '#00e5ff',
  red: '#ff3333',
  gray: '#6d7b6d',
  text: '#b0c8b0',
  border: '#1a2a1a',
};

const INFERENCE_PRESETS = {
  together: {
    label: 'Together',
    endpoint: 'https://api.together.xyz/v1/chat/completions',
    model: 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
  },
  groq: {
    label: 'Groq',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    model: 'llama-3.1-8b-instant',
  },
};

const CSS = `
* { box-sizing:border-box; }
body { margin:0; padding:10px; background:${CRT.bg}; color:${CRT.text}; font-family:'Cascadia Code','Fira Code',Consolas,monospace; font-size:11px; }
.header { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; padding-bottom:6px; border-bottom:1px solid ${CRT.border}; }
.title { color:${CRT.green}; font-weight:700; letter-spacing:.8px; font-size:12px; }
.status { font-size:10px; font-weight:700; }
.block { border:1px solid ${CRT.border}; border-radius:4px; background:${CRT.panel}; padding:8px; margin-bottom:8px; }
.blockTitle { color:${CRT.greenDim}; text-transform:uppercase; font-size:9px; letter-spacing:.9px; margin-bottom:6px; }
table { width:100%; border-collapse:collapse; }
td { padding:2px 0; vertical-align:top; }
.k { color:${CRT.gray}; width:95px; }
.v { color:${CRT.text}; word-break:break-word; }
.btnRow { display:flex; gap:6px; flex-wrap:wrap; margin-top:6px; }
button { border:1px solid ${CRT.border}; background:#0a140a; color:${CRT.green}; padding:4px 7px; border-radius:3px; font:inherit; font-size:10px; cursor:pointer; }
button:hover { border-color:${CRT.green}; }
button:disabled { opacity:.45; cursor:not-allowed; }
.btnAmber { color:${CRT.amber}; border-color:#554000; }
.btnCyan { color:${CRT.cyan}; border-color:#114955; }
.chatWrap { display:flex; flex-direction:column; gap:6px; }
.chatLog { border:1px solid ${CRT.border}; border-radius:3px; min-height:220px; max-height:320px; overflow:auto; padding:6px; background:#071007; }
.msg { margin-bottom:6px; padding:5px 6px; border-radius:3px; white-space:pre-wrap; word-break:break-word; }
.msgUser { border:1px solid #1d3a1d; background:#0c1e0c; }
.msgAssistant { border:1px solid #133f4a; background:#071a1f; }
.msgHead { font-size:9px; margin-bottom:3px; text-transform:uppercase; letter-spacing:.8px; }
.msgHead.user { color:${CRT.amber}; }
.msgHead.assistant { color:${CRT.cyan}; }
textarea { width:100%; min-height:64px; resize:vertical; background:#051105; color:${CRT.text}; border:1px solid ${CRT.border}; border-radius:3px; padding:6px; font:inherit; font-size:11px; }
.hint { color:${CRT.gray}; font-size:9px; margin-top:3px; }
.brainDesc { color:${CRT.gray}; font-size:9px; padding:2px 6px 4px; font-style:italic; }
.modeToggle { display:flex; gap:4px; margin-bottom:6px; }
.modeBtn { flex:1; padding:4px; border-radius:3px; font-size:10px; cursor:pointer; text-align:center; border:1px solid ${CRT.border}; background:#0a140a; color:${CRT.gray}; }
.modeBtn.active-merlin { color:${CRT.green}; border-color:${CRT.greenDim}; background:#0c1e0c; }
.modeBtn.active-dev { color:${CRT.cyan}; border-color:#114955; background:#071a1f; }
.metricRow { display:flex; justify-content:space-between; padding:2px 0; border-bottom:1px solid ${CRT.border}; }
.metricLabel { color:${CRT.gray}; font-size:9px; }
.metricVal { color:${CRT.text}; font-size:9px; }
.metricDiff.up { color:${CRT.green}; }
.metricDiff.down { color:${CRT.red}; }
.sessionRow { padding:3px 0; border-bottom:1px solid ${CRT.border}; }
.sessionFocus { color:${CRT.text}; font-size:10px; }
.sessionWhy { color:${CRT.gray}; font-size:9px; margin-top:1px; }
.badge { display:inline-block; padding:1px 4px; border-radius:2px; font-size:8px; font-weight:700; margin-right:4px; }
.badge-HIGH { background:#332200; color:${CRT.amber}; border:1px solid #554000; }
.badge-MEDIUM { background:#071a1f; color:${CRT.cyan}; border:1px solid #114955; }
.badge-DONE { background:#0a0a0a; color:${CRT.gray}; border:1px solid ${CRT.border}; }
.claudeActivity { border-top:1px solid ${CRT.border}; padding:6px 0; margin-top:2px; }
.claudeActivity .blockTitle { margin-bottom:4px; }
.badge-plan { display:inline-block;padding:1px 5px;border-radius:2px;font-size:9px;font-weight:700;background:#0d1f33;color:${CRT.cyan};border:1px solid #114955; }
.badge-interactive { display:inline-block;padding:1px 5px;border-radius:2px;font-size:9px;font-weight:700;background:#0c1e0c;color:${CRT.green};border:1px solid ${CRT.greenDim}; }
.caObjective { color:${CRT.text};font-size:10px;margin:3px 0; }
.caCompliance { color:${CRT.amber};font-size:9px;margin-bottom:3px; }
.caSkillRow { font-size:9px;padding:1px 0;color:#8aaa8a;display:flex;justify-content:space-between; }
.caSkillRow .caTs { color:#444; }
.caDim { color:#444;font-size:9px; }
.agentsList { margin-top:4px; }
.agentRow { display:flex;align-items:baseline;gap:4px;padding:2px 0;border-bottom:1px solid ${CRT.border};font-size:9px; }
.agentRow.running { border-left:2px solid ${CRT.cyan};padding-left:4px; }
.agentRow.done { border-left:2px solid ${CRT.border};padding-left:4px;opacity:.65; }
.agentPrj { display:inline-block;padding:0 3px;border-radius:2px;font-size:8px;font-weight:700;flex-shrink:0; }
.agentPrj-merlin { background:#1a1a0d;color:${CRT.amber};border:1px solid #554000; }
.agentPrj-data   { background:#0d1a2e;color:${CRT.cyan};border:1px solid #114955; }
.agentPrj-cours  { background:#1a0d1a;color:#cc88ff;border:1px solid #442244; }
.agentPrj-unknown{ background:#111;color:${CRT.gray};border:1px solid ${CRT.border}; }
.agentName { color:${CRT.text};font-weight:600;flex-shrink:0; }
.agentTask { color:${CRT.gray};flex:1;overflow:hidden;white-space:nowrap;text-overflow:ellipsis; }
.agentDur  { color:#444;flex-shrink:0;margin-left:4px; }
.busMsg { padding:3px 0; border-bottom:1px solid ${CRT.border}; font-size:10px; }
.busMsg:last-child { border-bottom:none; }
.busTs { color:${CRT.gray}; font-size:9px; margin-right:4px; }
.busRoute { color:${CRT.greenDim}; }
.busRoute.high { color:${CRT.amber}; }
.busRoute.critical { color:${CRT.red}; }
.busBody { color:${CRT.text}; font-size:9px; padding-left:4px; }
.agentGrid { display:grid; grid-template-columns:1fr 1fr; gap:3px; }
.agentBadge { display:flex; align-items:center; gap:4px; font-size:9px; padding:2px 3px; }
.agentBadgeDot { font-size:10px; flex-shrink:0; }
.agentBadgeName { color:${CRT.text}; font-weight:600; flex-shrink:0; white-space:nowrap; }
.agentBadgeState { color:${CRT.gray}; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }
.debugBar { font-family:inherit; font-size:9px; color:${CRT.green}; letter-spacing:0; }
.debugInfo { color:${CRT.text}; font-size:9px; margin-top:2px; }
.stateIndicator { display:flex; align-items:center; gap:8px; padding:4px 0; }
.stateName { font-size:13px; font-weight:700; letter-spacing:1px; }
.stateCycle { color:${CRT.gray}; font-size:10px; }
.rosterToggle { cursor:pointer;color:${CRT.greenDim};font-size:9px;text-transform:uppercase;letter-spacing:.8px;user-select:none; }
.rosterToggle:hover { color:${CRT.green}; }
.rosterList { margin-top:4px; }
.rosterItem { display:flex;justify-content:space-between;align-items:center;padding:1px 0;font-size:9px;border-bottom:1px solid ${CRT.border}; }
.rosterName { color:${CRT.text}; }
.rosterName.active { color:${CRT.green};font-weight:600; }
.rosterMeta { color:${CRT.gray};font-size:8px; }
.rosterCount { color:${CRT.amber};font-size:8px;margin-left:4px; }
.rosterSection { margin-top:4px; }
.rosterSectionTitle { color:${CRT.greenDim};font-size:8px;text-transform:uppercase;letter-spacing:.6px;margin-bottom:2px; }
.sessionCard { display:flex;justify-content:space-between;align-items:center;padding:3px 0;border-bottom:1px solid ${CRT.border};font-size:9px; }
.sessionCard.current { border-left:2px solid ${CRT.cyan};padding-left:4px; }
.badge-active { display:inline-block;padding:1px 4px;border-radius:2px;font-size:7px;font-weight:700;background:#0c1e0c;color:${CRT.green};border:1px solid ${CRT.greenDim}; }
.badge-stale { display:inline-block;padding:1px 4px;border-radius:2px;font-size:7px;font-weight:700;background:#1a1200;color:${CRT.amber};border:1px solid #554000; }
.badge-offline { display:inline-block;padding:1px 4px;border-radius:2px;font-size:7px;font-weight:700;background:#1a0a0a;color:${CRT.red};border:1px solid #440000; }
.pidRow { display:flex;align-items:center;gap:6px;padding:2px 0;font-size:9px;border-bottom:1px solid ${CRT.border}; }
.pidLabel { color:${CRT.cyan};font-weight:600; }
.pidMem { color:${CRT.gray}; }
`;


function escapeHtml(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function findProjectRoot() {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) return null;

  const hasRemoteScript = (root) =>
    fs.existsSync(path.join(root, 'tools', 'lora', 'remote_kaggle_train.py'));

  for (const f of folders) {
    const root = f.uri.fsPath;
    if (fs.existsSync(path.join(root, 'project.godot')) && hasRemoteScript(root)) return root;
  }
  for (const f of folders) {
    const root = f.uri.fsPath;
    if (hasRemoteScript(root)) return root;
  }
  return null;
}

function getConfig() {
  const c = vscode.workspace.getConfiguration('autodev-v4.remoteTrain');
  const py = vscode.workspace.getConfiguration('python');
  return {
    pythonPath: c.get('pythonPath', ''),
    pythonDefaultInterpreterPath: py.get('defaultInterpreterPath', ''),
    kaggleUsername: c.get('kaggleUsername', ''),
    kernelSlug: c.get('kernelSlug', 'merlin-remote-train'),
    kernelTitle: c.get('kernelTitle', 'MERLIN Remote LoRA Training'),
    testModel: c.get('testModel', 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo'),
    testEndpoint: c.get('testEndpoint', 'https://api.together.xyz/v1/chat/completions'),
    testApiKey: c.get('testApiKey', ''),
  };
}

function pushCandidate(candidates, cmd, args = []) {
  if (!cmd) return;
  const key = `${cmd}:::${args.join(' ')}`;
  if (candidates.some((c) => c.key === key)) return;
  candidates.push({ key, cmd, args });
}

function resolvePythonRuntime(root, output) {
  const cfg = getConfig();
  const candidates = [];

  pushCandidate(candidates, cfg.pythonPath || '');
  pushCandidate(candidates, cfg.pythonDefaultInterpreterPath || '');
  pushCandidate(candidates, process.env.PYTHON || '');

  if (process.platform === 'win32') {
    const localApp = process.env.LOCALAPPDATA || '';
    if (localApp) {
      pushCandidate(candidates, path.join(localApp, 'Programs', 'Python', 'Python312', 'python.exe'));
      pushCandidate(candidates, path.join(localApp, 'Programs', 'Python', 'Python311', 'python.exe'));
      pushCandidate(candidates, path.join(localApp, 'Programs', 'Python', 'Python310', 'python.exe'));
    }
    pushCandidate(candidates, 'py', ['-3']);
    pushCandidate(candidates, 'py');
  } else {
    pushCandidate(candidates, 'python3');
  }
  pushCandidate(candidates, 'python');

  for (const candidate of candidates) {
    try {
      const probe = cp.spawnSync(candidate.cmd, [...candidate.args, '--version'], {
        cwd: root,
        shell: false,
        encoding: 'utf8',
      });
      if (probe && probe.status === 0) return candidate;
    } catch {
      // Probe next candidate.
    }
  }

  const tried = candidates.map((c) => `${c.cmd} ${c.args.join(' ')}`.trim()).join(', ');
  const hint = process.platform === 'win32'
    ? 'Set autodev-v4.remoteTrain.pythonPath to a valid python.exe path.'
    : 'Set autodev-v4.remoteTrain.pythonPath to a valid Python executable.';
  throw new Error(`Python runtime not found. Tried: ${tried}. ${hint}`);
}

function readJson(filePath) {
  try {
    if (!fs.existsSync(filePath)) return {};
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
}

function remoteScript(root) {
  return path.join(root, 'tools', 'lora', 'remote_kaggle_train.py');
}

function remoteState(root) {
  return path.join(root, '.merlin_remote', 'kaggle', 'state.json');
}

function runPython(root, args, output) {
  return new Promise((resolve, reject) => {
    const runtime = resolvePythonRuntime(root, output);
    const script = remoteScript(root);
    if (!fs.existsSync(script)) {
      reject(new Error(`Missing script: ${script}`));
      return;
    }
    const fullArgs = [...runtime.args, script, ...args];
    output.appendLine(`$ ${runtime.cmd} ${fullArgs.join(' ')}`);

    const proc = cp.spawn(runtime.cmd, fullArgs, {
      cwd: root,
      shell: false,
      env: { ...process.env, PYTHONIOENCODING: 'utf-8', PYTHONUTF8: '1' },
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => {
      const text = d.toString();
      stdout += text;
      output.append(text);
    });
    proc.stderr.on('data', (d) => {
      const text = d.toString();
      stderr += text;
      output.append(text);
    });
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code === 0) resolve({ stdout, stderr, code });
      else reject(new Error(`Command failed (${code})`));
    });
  });
}

function normalizeChatEndpoint(endpoint) {
  const clean = String(endpoint || '').trim().replace(/\/+$/, '');
  if (!clean) return '';
  if (clean.endsWith('/chat/completions')) return clean;
  if (clean.endsWith('/v1') || clean.endsWith('/openai/v1')) return `${clean}/chat/completions`;
  return clean;
}

function resolveApiKey(endpoint, explicitKey) {
  if (explicitKey) return explicitKey;
  const lowered = String(endpoint || '').toLowerCase();
  if (lowered.includes('together.xyz')) return process.env.TOGETHER_API_KEY || '';
  if (lowered.includes('groq.com')) return process.env.GROQ_API_KEY || '';
  if (lowered.includes('runpod.ai')) return process.env.RUNPOD_API_KEY || '';
  return process.env.OPENAI_API_KEY || '';
}

function postJson(url, payload, headers = {}) {
  return new Promise((resolve, reject) => {
    let parsed;
    try {
      parsed = new URL(url);
    } catch (err) {
      reject(new Error(`Invalid endpoint URL: ${url}`));
      return;
    }
    const data = JSON.stringify(payload);
    const options = {
      method: 'POST',
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: `${parsed.pathname}${parsed.search}`,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...headers,
      },
      timeout: 180000,
    };
    const client = parsed.protocol === 'https:' ? https : http;
    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 300)}`));
          return;
        }
        try {
          resolve(JSON.parse(body));
        } catch (err) {
          reject(new Error(`Invalid JSON response: ${body.slice(0, 300)}`));
        }
      });
    });
    req.on('timeout', () => req.destroy(new Error('Request timeout')));
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function directChat(prompt, cfg, systemPrompt = '') {
  const endpoint = normalizeChatEndpoint(cfg.testEndpoint);
  const messages = [];
  if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
  messages.push({ role: 'user', content: prompt });

  if (endpoint) {
    const apiKey = resolveApiKey(endpoint, cfg.testApiKey);
    const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : {};
    const payload = { model: cfg.testModel, messages, temperature: 0.7, max_tokens: 350 };
    const data = await postJson(endpoint, payload, headers);
    const reply = data?.choices?.[0]?.message?.content;
    return String(reply || '').trim() || '(reponse vide)';
  }

  const payload = {
    model: cfg.testModel,
    messages,
    stream: false,
    options: { temperature: 0.7, num_predict: 350 },
  };
  const data = await postJson('http://127.0.0.1:11434/api/chat', payload);
  const reply = data?.message?.content;
  return String(reply || '').trim() || '(reponse vide)';
}

const BRAIN_LIST = ['narrator', 'gamemaster', 'worker'];
const BRAIN_LABELS = { narrator: 'Narrator (4B)', gamemaster: 'Game Master (2B)', worker: 'Worker (0.8B)' };
const BRAIN_ICONS = { running: '\u25CF', complete: '\u2713', failed: '\u2717', ready: '\u25CB', pending: '\u25CB' };

const BRAIN_DESCRIPTIONS = {
  narrator: 'Voix de Merlin \u2014 narration des cartes, descriptions po\u00e9tiques, dialogue celtique. Qwen 3B.',
  gamemaster: 'Cerveau du jeu \u2014 gestion des \u00e9v\u00e9nements Triade, transitions d\u2019\u00e9tats, fins narratives. Qwen 1.5B.',
  worker: 'Utilitaire \u2014 classification d\u2019intentions, routing des actions, t\u00e2ches r\u00e9p\u00e9titives. Qwen 0.5B.',
};

const ACTION_DESCRIPTIONS = {
  doctor: 'V\u00e9rifie l\u2019environnement\u00a0: Python, Kaggle CLI, credentials, dataset pr\u00e9sent',
  setup: 'G\u00e9n\u00e8re le script d\u2019entra\u00eenement Kaggle et encode le dataset en base64',
  submit: 'Envoie le kernel sur Kaggle GPU \u2014 d\u00e9marre l\u2019entra\u00eenement LoRA (\u223c20\u00a0min)',
  status: 'Interroge l\u2019API Kaggle pour voir l\u2019\u00e9tat du job (running / complete / error)',
  download: 'T\u00e9l\u00e9charge les artefacts LoRA depuis Kaggle vers output/remote_kaggle/{brain}/',
};

const SYSTEM_PROMPTS = {
  merlin: `Tu es Merlin, le vieux sage enchanteur de la for\u00eat de Brocéliande.\nTu guides le joueur dans M.E.R.L.I.N. \u2014 Le Jeu des Oghams, un jeu de cartes narratif celtique.\nTu parles avec myst\u00e8re et sagesse, en \u00e9voquant les Oghams, les 3 Aspects (Corps/\u00c2me/Monde),\nle Souffle, et les 18 runes. Tu NE dis JAMAIS que tu es un mod\u00e8le de langage ou une IA.\nSi on te demande qui tu es\u00a0: tu es Merlin, gardien des Oghams.\nR\u00e9ponds en fran\u00e7ais, avec po\u00e9sie et concision.`,
  dev: `Tu es l\u2019assistant de d\u00e9veloppement du projet M.E.R.L.I.N. \u2014 Le Jeu des Oghams.\nTu aides \u00e0 analyser les datasets d\u2019entra\u00eenement LoRA, les m\u00e9triques, les performances des brains.\nTu connais l\u2019architecture\u00a0: narrator (Qwen 3B), gamemaster (1.5B), worker (0.5B).\nR\u00e9ponds de fa\u00e7on technique et pr\u00e9cise en fran\u00e7ais.`,
};

class RemoteTrainProvider {
  constructor(root) {
    this.root = root;
    this.view = null;
    this.output = vscode.window.createOutputChannel('MERLIN Remote Trainer');
    this.chat = [
      {
        role: 'assistant',
        content: 'Panel pret. Clique Bonjour ou ecris ton message pour chatter avec Merlin.',
      },
    ];
    this.isBusy = false;
    this.selectedBrain = 'narrator';
    this.chatMode = 'merlin';
    this.metrics = {};
    this.roadmap = null;
    this._sessionState = null;
    this._sessionPoll = null;
    this._activeAgents = null;
    this._agentMessages = null;
    this._agentStatus = null;
    this._fullRoster = null;
    this._claudeSessions = null;
    this._pollTick = 0;
    this._rosterExpanded = false;
    this._sessionsExpanded = true;
  }

  resolveRoot() {
    this.root = findProjectRoot();
    return this.root;
  }

  _generateNonce() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let nonce = '';
    for (let i = 0; i < 32; i++) nonce += chars.charAt(Math.floor(Math.random() * chars.length));
    return nonce;
  }

  _getInitialHtml(webview) {
    const extUri = vscode.Uri.file(path.join(__dirname));
    const dataBridgeUri = webview.asWebviewUri(vscode.Uri.joinPath(extUri, 'sidebar-data-bridge.js'));
    const neuralUri = webview.asWebviewUri(vscode.Uri.joinPath(extUri, 'neural-renderer.js'));
    const bridgeUri = webview.asWebviewUri(vscode.Uri.joinPath(extUri, 'sidebar-bridge.js'));
    const nonce = this._generateNonce();

    return `<!DOCTYPE html><html><head>
      <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';">
      <style>${CSS}
        #galaxyContainer { height: 70vh; position: relative; overflow: hidden; border-bottom: 1px solid ${CRT.border}; }
        #neuralCanvas { width: 100%; height: 100%; display: block; }
        #textSection { height: 30vh; overflow-y: auto; padding: 4px 0; }
        .textBlock { padding: 4px 8px; }
        .moreToggle { cursor:pointer;color:${CRT.greenDim};font-size:9px;text-transform:uppercase;letter-spacing:.8px;user-select:none;padding:4px 8px; }
        .moreToggle:hover { color:${CRT.green}; }
        .moreContent { display:none; }
        .moreContent.expanded { display:block; }
      </style>
    </head><body>
      <div id="galaxyContainer">
        <canvas id="neuralCanvas"></canvas>
      </div>
      <div id="textSection">
        <div id="section-activity" class="textBlock"></div>
        <div id="section-agents" class="textBlock"></div>
        <div id="section-sessions" class="textBlock"></div>
        <div class="moreToggle" onclick="toggleMore()">&#9654; More (Brain, Chat, Roster)</div>
        <div id="section-more" class="moreContent"></div>
      </div>
      <script nonce="${nonce}" src="${dataBridgeUri}"></script>
      <script nonce="${nonce}" src="${neuralUri}"></script>
      <script nonce="${nonce}" src="${bridgeUri}"></script>
      <script nonce="${nonce}">
        function send(type, payload) { window._sidebarSend(type, payload); }
        function selectBrain(brain) { window._sidebarSend('selectBrain', { brain: brain }); }
        function sendBrain(action) { window._sidebarSend(action, { brain: '${this.selectedBrain}' }); }
        function clearBox() { var el = document.getElementById('prompt'); if (el) el.value = ''; }
        function chat() {
          var el = document.getElementById('prompt');
          var prompt = (el && el.value || '').trim();
          if (!prompt) return;
          window._sidebarSend('chat', { prompt: prompt });
          el.value = '';
        }
        function quickHello() { window._sidebarSend('chat', { prompt: 'Bonjour Merlin' }); }
        var _moreExpanded = false;
        function toggleMore() {
          _moreExpanded = !_moreExpanded;
          var el = document.getElementById('section-more');
          if (el) el.className = _moreExpanded ? 'moreContent expanded' : 'moreContent';
        }
      </script>
    </body></html>`;
  }

  resolveWebviewView(view) {
    this.view = view;
    const extUri = vscode.Uri.file(path.join(__dirname));
    view.webview.options = {
      enableScripts: true,
      localResourceRoots: [extUri]
    };
    view.webview.onDidReceiveMessage(async (msg) => {
      if (!msg || !msg.type) return;
      switch (msg.type) {
        case 'refresh':
          this.update();
          break;
        case 'configure':
          await this.configure();
          break;
        case 'presetTogether':
          await this.applyInferencePreset('together');
          break;
        case 'presetGroq':
          await this.applyInferencePreset('groq');
          break;
        case 'presetRunpod':
          await this.configureRunpodPreset();
          break;
        case 'selectBrain':
          this.selectedBrain = msg.brain || 'narrator';
          this.update();
          break;
        case 'setup':
        case 'submit':
        case 'status':
        case 'download':
        case 'doctor':
          await this.runRemote(msg.type, msg.brain || this.selectedBrain);
          break;
        case 'trainAll':
          await this.trainAll();
          break;
        case 'openKaggle':
          this.openKaggle();
          break;
        case 'toggleChatMode':
          this.chatMode = this.chatMode === 'merlin' ? 'dev' : 'merlin';
          this.update();
          break;
        case 'toggleRoster':
          this._rosterExpanded = !this._rosterExpanded;
          this.update();
          break;
        case 'toggleSessions':
          this._sessionsExpanded = !this._sessionsExpanded;
          this.update();
          break;
        case 'chat':
          await this.chatSend(String(msg.prompt || '').trim());
          break;
      }
    });
    this.resolveRoot();

    // Set HTML once (canvas + scripts + text placeholders)
    view.webview.html = this._getInitialHtml(view.webview);

    this._loadSessionState();
    this._loadActiveAgents();
    this._loadAgentMessages();
    this._loadAgentStatus();
    this._loadFullRoster();
    this._loadClaudeSessions();
    this._refreshRecentInvocationsAsync();
    this._refreshSessionContextAsync();
    this._refreshParentMapAsync();

    // Initial data push (delayed to let webview scripts load)
    setTimeout(() => this.update(), 500);

    // Multi-frequency polling: 3s base, 10s processes, 5s roster
    if (this._sessionPoll) clearInterval(this._sessionPoll);
    this._pollTick = 0;
    this._sessionPoll = setInterval(() => {
      this._pollTick++;
      this.resolveRoot();
      this._loadSessionState();
      this._loadActiveAgents();
      this._loadAgentMessages();
      this._loadAgentStatus();
      // Every 3s: refresh recent invocations + session context (lightweight, drives bubbles)
      this._refreshRecentInvocationsAsync();
      this._refreshSessionContextAsync();
      // Every 10s (tick 3,6,9...): refresh Claude processes + parent map
      if (this._pollTick % 3 === 0) {
        this._loadClaudeSessions();
        this._refreshParentMapAsync();
      }
      // Every 5s (tick 2,4,6,...): refresh roster from registry
      if (this._pollTick % 2 === 0) {
        this._loadFullRoster();
      }
      if (this.view) this.update();
    }, 3000);

    // CRITICAL: clear interval when panel is disposed (prevents post-deactivation I/O)
    view.onDidDispose(() => {
      if (this._sessionPoll) {
        clearInterval(this._sessionPoll);
        this._sessionPoll = null;
      }
    });
  }

  async configure() {
    const cfg = getConfig();
    const pythonPath = await vscode.window.showInputBox({
      prompt: 'Python executable (optional if auto-detect works)',
      value: cfg.pythonPath || cfg.pythonDefaultInterpreterPath || '',
      ignoreFocusOut: true,
    });
    if (pythonPath === undefined) return;
    const username = await vscode.window.showInputBox({
      prompt: 'Kaggle username',
      value: cfg.kaggleUsername || '',
      ignoreFocusOut: true,
    });
    if (username === undefined) return;
    const slug = await vscode.window.showInputBox({
      prompt: 'Kernel slug',
      value: cfg.kernelSlug || 'merlin-remote-train',
      ignoreFocusOut: true,
    });
    if (slug === undefined) return;
    const title = await vscode.window.showInputBox({
      prompt: 'Kernel title',
      value: cfg.kernelTitle || 'MERLIN Remote LoRA Training',
      ignoreFocusOut: true,
    });
    if (title === undefined) return;
    const model = await vscode.window.showInputBox({
      prompt: 'Test model',
      value: cfg.testModel || 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
      ignoreFocusOut: true,
    });
    if (model === undefined) return;
    const endpoint = await vscode.window.showInputBox({
      prompt: 'Optional test endpoint URL (OpenAI-compatible). Leave empty for local Ollama.',
      value: cfg.testEndpoint || 'https://api.together.xyz/v1/chat/completions',
      ignoreFocusOut: true,
    });
    if (endpoint === undefined) return;
    const apiKey = await vscode.window.showInputBox({
      prompt: 'Optional endpoint API key (leave empty to keep current)',
      value: cfg.testApiKey || '',
      password: true,
      ignoreFocusOut: true,
    });
    if (apiKey === undefined) return;

    const usernameValue = username.trim();
    const slugValue = slug.trim() || 'merlin-remote-train';
    const titleValue = title.trim() || 'MERLIN Remote LoRA Training';
    const modelValue = model.trim() || 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo';

    const ws = vscode.workspace.getConfiguration('autodev-v4.remoteTrain');
    await ws.update('pythonPath', pythonPath.trim(), vscode.ConfigurationTarget.Workspace);
    await ws.update('kaggleUsername', usernameValue, vscode.ConfigurationTarget.Workspace);
    await ws.update('kernelSlug', slugValue, vscode.ConfigurationTarget.Workspace);
    await ws.update('kernelTitle', titleValue, vscode.ConfigurationTarget.Workspace);
    await ws.update('testModel', modelValue, vscode.ConfigurationTarget.Workspace);
    await ws.update('testEndpoint', endpoint.trim(), vscode.ConfigurationTarget.Workspace);
    await ws.update('testApiKey', apiKey.trim(), vscode.ConfigurationTarget.Workspace);
    vscode.window.showInformationMessage('MERLIN Remote Trainer config updated');
    this.update();
  }

  async applyInferencePreset(name) {
    const preset = INFERENCE_PRESETS[name];
    if (!preset) return;
    const ws = vscode.workspace.getConfiguration('autodev-v4.remoteTrain');
    await ws.update('testEndpoint', preset.endpoint, vscode.ConfigurationTarget.Workspace);
    await ws.update('testModel', preset.model, vscode.ConfigurationTarget.Workspace);
    const key = await vscode.window.showInputBox({
      prompt: `${preset.label} API key (optional now, required for remote chat)`,
      value: '',
      password: true,
      ignoreFocusOut: true,
    });
    if (key !== undefined && key.trim()) {
      await ws.update('testApiKey', key.trim(), vscode.ConfigurationTarget.Workspace);
    }
    vscode.window.showInformationMessage(`Preset ${preset.label} applique`);
    this.update();
  }

  async configureRunpodPreset() {
    const endpointOrId = await vscode.window.showInputBox({
      prompt: 'RunPod endpoint URL ou endpoint ID',
      value: '',
      ignoreFocusOut: true,
    });
    if (endpointOrId === undefined || !endpointOrId.trim()) return;
    const normalized = endpointOrId.trim().startsWith('http')
      ? endpointOrId.trim()
      : `https://api.runpod.ai/v2/${endpointOrId.trim()}/openai/v1/chat/completions`;
    const model = await vscode.window.showInputBox({
      prompt: 'RunPod model name',
      value: 'meta-llama/Meta-Llama-3.1-8B-Instruct',
      ignoreFocusOut: true,
    });
    if (model === undefined || !model.trim()) return;
    const key = await vscode.window.showInputBox({
      prompt: 'RunPod API key (optional now, required for remote chat)',
      value: '',
      password: true,
      ignoreFocusOut: true,
    });
    if (key === undefined) return;

    const ws = vscode.workspace.getConfiguration('autodev-v4.remoteTrain');
    await ws.update('testEndpoint', normalized, vscode.ConfigurationTarget.Workspace);
    await ws.update('testModel', model.trim(), vscode.ConfigurationTarget.Workspace);
    await ws.update('testApiKey', key.trim(), vscode.ConfigurationTarget.Workspace);
    vscode.window.showInformationMessage('Preset RunPod applique');
    this.update();
  }

  async runRemote(action, brain) {
    if (this.isBusy) return;
    const root = this.resolveRoot();
    if (!root) {
      vscode.window.showWarningMessage('Ouvre le workspace du projet (tools/lora/remote_kaggle_train.py) pour les actions Kaggle.');
      this.update();
      return;
    }
    const cfg = getConfig();
    const effectiveBrain = brain || this.selectedBrain || '';
    const args = [action, '--workspace', root];
    if (effectiveBrain) args.push('--brain', effectiveBrain);
    if (cfg.kaggleUsername) args.push('--username', cfg.kaggleUsername);
    if (cfg.kernelSlug && !effectiveBrain) args.push('--slug', cfg.kernelSlug);
    if (action === 'setup' && cfg.kernelTitle && !effectiveBrain) args.push('--title', cfg.kernelTitle);
    if (action === 'download') args.push('--output', path.join(root, 'output', 'remote_kaggle'));

    const label = effectiveBrain ? `${action} [${effectiveBrain}]` : action;
    this.isBusy = true;
    this.update();
    this.output.show(true);
    await vscode.window.withProgress(
      { location: vscode.ProgressLocation.Notification, title: `MERLIN Remote: ${label}` },
      async () => {
        await runPython(root, args, this.output);
      }
    ).then(
      () => vscode.window.showInformationMessage(`Action '${label}' terminee`),
      (err) => vscode.window.showErrorMessage(`Action '${label}' en erreur: ${err.message}`)
    );
    this.isBusy = false;
    if (action === 'download') {
      this.loadMetrics(root, brain || this.selectedBrain);
      this.loadRoadmap(root);
      this.update();
      await this.autoTestAfterDownload(brain || this.selectedBrain);
    } else {
      this.update();
    }
  }

  async trainAll() {
    if (this.isBusy) return;
    const root = this.resolveRoot();
    if (!root) return;

    this.isBusy = true;
    this.update();
    this.output.show(true);

    for (const brain of BRAIN_LIST) {
      try {
        this.output.appendLine(`\n=== Setup + Submit: ${brain} ===`);
        await runPython(root, ['setup', '--workspace', root, '--brain', brain], this.output);
        await runPython(root, ['submit', '--workspace', root, '--brain', brain], this.output);
        this.update();
      } catch (err) {
        this.output.appendLine(`[ERROR] ${brain}: ${err.message}`);
        vscode.window.showErrorMessage(`Train All: ${brain} failed — ${err.message}`);
      }
    }

    this.isBusy = false;
    this.update();
    vscode.window.showInformationMessage('Train All: all brains submitted');
  }

  async openPanel() {
    await vscode.commands.executeCommand('workbench.view.extension.autodev-v4-sidebar');
    try {
      await vscode.commands.executeCommand('autodev-v4.remoteTrain.focus');
    } catch {
      // Focus command can be unavailable on some VS Code builds.
    }
    this.update();
  }

  openKaggle() {
    const root = this.resolveRoot();
    const state = root ? readJson(remoteState(root)) : {};
    const stateUrl = typeof state.url === 'string' ? state.url.trim() : '';
    if (stateUrl) {
      vscode.env.openExternal(vscode.Uri.parse(stateUrl));
      return;
    }

    const cfg = getConfig();
    let username = String(cfg.kaggleUsername || '').trim();
    let slug = String(cfg.kernelSlug || '').trim();

    const stateJob = String(state.job || '').trim();
    const slashIndex = stateJob.indexOf('/');
    if (slashIndex > 0) {
      if (!username) username = stateJob.slice(0, slashIndex).trim();
      if (!slug) slug = stateJob.slice(slashIndex + 1).trim();
    }

    if (!username || !slug) {
      vscode.window.showWarningMessage('Impossible de construire le lien Kaggle. Renseigne username/slug ou lance setup.');
      return;
    }

    const url = `https://www.kaggle.com/code/${username}/${slug}`;
    vscode.env.openExternal(vscode.Uri.parse(url));
  }

  async chatSend(prompt) {
    if (!prompt || this.isBusy) return;
    const root = this.resolveRoot();
    const cfg = getConfig();
    const systemPrompt = SYSTEM_PROMPTS[this.chatMode] || SYSTEM_PROMPTS.merlin;
    this.chat.push({ role: 'user', content: prompt });
    this.isBusy = true;
    this.update();

    this.output.show(true);
    try {
      let reply = '';
      if (root) {
        const args = ['chat', '--workspace', root, '--prompt', prompt, '--model', cfg.testModel,
          '--system-prompt', systemPrompt];
        if (cfg.testEndpoint) args.push('--endpoint', cfg.testEndpoint);
        if (cfg.testApiKey) args.push('--api-key', cfg.testApiKey);
        const result = await runPython(root, args, this.output);
        reply = result.stdout.trim();
        const lastLine = reply.split(/\r?\n/).filter(Boolean).slice(-1)[0] || '';
        try {
          const parsed = JSON.parse(lastLine);
          if (parsed && parsed.reply) reply = String(parsed.reply);
        } catch {
          // Keep raw output if parser fails.
        }
      } else {
        this.output.appendLine('[MERLIN] Chat en mode direct (sans script Python du projet)');
        reply = await directChat(prompt, cfg, systemPrompt);
      }
      if (!reply) reply = '(reponse vide)';
      this.chat.push({ role: 'assistant', content: reply });
    } catch (err) {
      this.chat.push({ role: 'assistant', content: `Erreur chat: ${err.message}` });
    }

    this.isBusy = false;
    this.update();
  }
  chatHtml() {
    const lines = this.chat
      .slice(-30)
      .map((m) => {
        const user = m.role === 'user';
        return `<div class="msg ${user ? 'msgUser' : 'msgAssistant'}">
          <div class="msgHead ${user ? 'user' : 'assistant'}">${user ? 'toi' : 'merlin'}</div>
          ${escapeHtml(m.content)}
        </div>`;
      })
      .join('');
    return lines || `<div class="hint">Pas encore de message.</div>`;
  }

  loadMetrics(root, brain) {
    if (!root || !brain) return;
    const manifestPath = path.join(root, 'output', 'remote_kaggle', brain, 'merlin_artifacts', 'manifest.json');
    const manifest = readJson(manifestPath);
    if (manifest && manifest.brain) {
      const prev = (this.metrics[brain] || {}).samples;
      this.metrics[brain] = { ...manifest, _prevSamples: prev };
    }
  }

  loadRoadmap(root) {
    if (!root) return;
    const p = path.join(root, '.merlin_remote', 'training_roadmap.json');
    const data = readJson(p);
    if (data && Array.isArray(data.sessions)) this.roadmap = data;
  }

  metricsHtml() {
    const rows = BRAIN_LIST.map((b) => {
      const m = this.metrics[b];
      const label = BRAIN_LABELS[b];
      if (!m || !m.brain) {
        return `<div class="metricRow"><span class="metricLabel">${escapeHtml(label)}</span><span class="metricVal" style="color:${CRT.gray}">(download requis)</span></div>`;
      }
      const diffHtml = (m._prevSamples && m.samples !== m._prevSamples)
        ? `<span class="metricDiff ${m.samples > m._prevSamples ? 'up' : 'down'}"> (${m.samples > m._prevSamples ? '+' : ''}${m.samples - m._prevSamples})</span>`
        : '';
      return `<div class="metricRow">
        <span class="metricLabel">${escapeHtml(label)}</span>
        <span class="metricVal">${m.samples || '?'} samples${diffHtml} &bull; ${m.max_steps || '?'} steps &bull; lr=${m.learning_rate || '?'} &bull; r=${m.lora_r || '?'}</span>
      </div>`;
    }).join('');
    return rows;
  }

  nextSessionsHtml() {
    if (!this.roadmap || !Array.isArray(this.roadmap.sessions) || this.roadmap.sessions.length === 0) {
      return `<div class="hint">Fichier .merlin_remote/training_roadmap.json non charg\u00e9. Cliquez Download pour l\u2019initialiser.</div>`;
    }
    return this.roadmap.sessions.map((s) => {
      const priority = String(s.priority || 'MEDIUM').toUpperCase();
      const badgeClass = s.status === 'done' ? 'badge-DONE' : `badge-${priority}`;
      const priorityLabel = s.status === 'done' ? 'DONE' : priority;
      const samples = s.target_samples ? ` &bull; +${s.target_samples} samples` : '';
      return `<div class="sessionRow">
        <div class="sessionFocus"><span class="badge ${badgeClass}">${escapeHtml(priorityLabel)}</span>${escapeHtml(s.brain || '')} &mdash; ${escapeHtml(s.focus || '')}${samples}</div>
        ${s.why ? `<div class="sessionWhy">${escapeHtml(s.why)}</div>` : ''}
      </div>`;
    }).join('');
  }

  async autoTestAfterDownload(brain) {
    if (!brain) return;
    const root = this.resolveRoot();
    const cfg = getConfig();
    const testPrompts = {
      narrator: 'Qui es-tu\u00a0?',
      gamemaster: 'Donne l\u2019\u00e9tat actuel de la Triade.',
      worker: 'Classe cette action\u00a0: le joueur choisit l\u2019option du centre.',
    };
    const prompt = testPrompts[brain] || 'Bonjour\u00a0!';
    this.chat.push({ role: 'assistant', content: `\u2014 Test auto post-download [${brain}]\u00a0: \u00ab\u00a0${prompt}\u00a0\u00bb` });
    this.update();
    try {
      const systemPrompt = SYSTEM_PROMPTS[brain === 'narrator' ? 'merlin' : 'dev'];
      let reply;
      if (root) {
        const args = ['chat', '--workspace', root, '--prompt', prompt, '--model', cfg.testModel,
          '--system-prompt', systemPrompt];
        if (cfg.testEndpoint) args.push('--endpoint', cfg.testEndpoint);
        if (cfg.testApiKey) args.push('--api-key', cfg.testApiKey);
        const result = await runPython(root, args, this.output);
        const lastLine = result.stdout.trim().split(/\r?\n/).filter(Boolean).slice(-1)[0] || '';
        try { const parsed = JSON.parse(lastLine); if (parsed && parsed.reply) reply = String(parsed.reply); } catch { reply = result.stdout.trim(); }
      } else {
        reply = await directChat(prompt, cfg, systemPrompt);
      }
      this.chat.push({ role: 'assistant', content: reply || '(reponse vide)' });
    } catch (err) {
      this.chat.push({ role: 'assistant', content: `Test auto \u00e9chou\u00e9\u00a0: ${err.message}` });
    }
    this.update();
  }

  _loadActiveAgents() {
    const agentsPath = path.join(os.homedir(), '.claude', 'metrics', 'active_agents.json');
    fs.readFile(agentsPath, 'utf8', (err, data) => {
      if (err) {
        // ENOENT = file doesn't exist yet → clear state
        // Other errors (transient I/O) → keep previous value to avoid flicker
        if (err.code === 'ENOENT') this._activeAgents = null;
        return;
      }
      try { this._activeAgents = JSON.parse(data); }
      catch { this._activeAgents = null; }
    });
  }

  activeAgentsHtml() {
    const data = this._activeAgents;
    const agents = data && Array.isArray(data.agents) ? data.agents : [];

    const running = agents.filter(a => a.status === 'in_progress');
    const done = agents.filter(a => a.status !== 'in_progress')
      .sort((a, b) => (b.end_ts || '').localeCompare(a.end_ts || '')).slice(0, 5);
    const displayed = [...running, ...done];

    if (displayed.length === 0) {
      return `<div class="agentsList"><span class="caDim">Aucun agent actif</span></div>`;
    }

    const now = Date.now();
    const rows = displayed.map(a => {
      const isRunning = a.status === 'in_progress';
      const icon = isRunning ? `<span style="color:${CRT.cyan}">&#9679;</span>` : `<span style="color:${CRT.greenDim}">&#10003;</span>`;
      const prjClass = `agentPrj-${(a.project || 'unknown').toLowerCase()}`;
      let dur = '';
      try {
        // Truncate Python microseconds (6 digits) to ms (3 digits) before parsing
        const parseTs = (ts) => ts ? new Date(String(ts).replace(/(\.\d{3})\d+/, '$1')).getTime() : NaN;
        const start = parseTs(a.start_ts);
        const end = isRunning ? now : parseTs(a.end_ts);
        const secs = Math.round((end - start) / 1000);
        if (!isNaN(secs) && secs >= 0) dur = secs < 60 ? `${secs}s` : `${Math.round(secs / 60)}m`;
      } catch { /* ignore */ }
      return `<div class="agentRow ${isRunning ? 'running' : 'done'}">
        ${icon}
        <span class="agentPrj ${prjClass}">${escapeHtml(a.project || '?')}</span>
        <span class="agentName">${escapeHtml(a.name || '?')}</span>
        <span class="agentTask">${escapeHtml(a.task || '')}</span>
        <span class="agentDur">${dur}</span>
      </div>`;
    }).join('');

    const runningCount = running.length;
    const header = runningCount > 0
      ? `<span style="color:${CRT.cyan}">&#9679; ${runningCount} actif${runningCount > 1 ? 's' : ''}</span>`
      : `<span class="caDim">aucun actif</span>`;

    return `<div class="agentsList">${header}${rows}</div>`;
  }

  _loadSessionState() {
    const root = this.root;
    if (!root) { this._sessionState = null; return; }
    const sessionPath = path.join(root, 'tools', 'autodev', 'status', 'session.json');
    // Non-blocking read — update state and re-render when done
    fs.readFile(sessionPath, 'utf8', (err, data) => {
      if (err) { this._sessionState = null; }
      else {
        try { this._sessionState = JSON.parse(data); }
        catch { this._sessionState = null; }
      }
    });
  }

  _loadAgentMessages() {
    const root = this.root;
    if (!root) { this._agentMessages = null; return; }
    const p = path.join(root, 'tools', 'autodev', 'status', 'agent_messages.json');
    fs.readFile(p, 'utf8', (err, data) => {
      if (err) { if (err.code === 'ENOENT') this._agentMessages = null; return; }
      try { this._agentMessages = JSON.parse(data); } catch { this._agentMessages = null; }
    });
  }

  _loadAgentStatus() {
    const root = this.root;
    if (!root) { this._agentStatus = null; return; }
    const p = path.join(root, 'tools', 'autodev', 'status', 'agent_status.json');
    fs.readFile(p, 'utf8', (err, data) => {
      if (err) { if (err.code === 'ENOENT') this._agentStatus = null; return; }
      try { this._agentStatus = JSON.parse(data); } catch { this._agentStatus = null; }
    });
  }

  agentBusHtml() {
    const data = this._agentMessages;
    const messages = (data && Array.isArray(data.messages)) ? data.messages : [];
    // Show last 5 messages (pending or recent)
    const recent = messages.slice(-5);
    if (recent.length === 0) {
      return `<span class="caDim">Aucun message</span>`;
    }
    return recent.map(m => {
      const ts = m.timestamp ? String(m.timestamp).slice(11, 16) : '??:??';
      const from = escapeHtml(m.from || '?');
      const to = escapeHtml(m.to || '?');
      const priority = String(m.priority || 'NORMAL').toUpperCase();
      const priorityCls = priority === 'CRITICAL' ? 'critical' : priority === 'HIGH' ? 'high' : '';
      const type = escapeHtml(m.type || '');
      const payload = m.payload ? escapeHtml(JSON.stringify(m.payload).slice(0, 60)) : '';
      return `<div class="busMsg">
        <span class="busTs">[${ts}]</span><span class="busRoute ${priorityCls}">${from} &#8594; ${to}</span>${priority !== 'NORMAL' ? ` <span class="badge badge-${priority}">${priority}</span>` : ''}
        <div class="busBody">${type}${payload ? ': ' + payload : ''}</div>
      </div>`;
    }).join('');
  }

  agentStatusBadgesHtml() {
    const data = this._agentStatus;
    const agents = (data && data.agents) ? data.agents : {};
    const entries = Object.entries(agents);
    if (entries.length === 0) {
      return `<span class="caDim">agent_status.json non disponible</span>`;
    }
    const rows = entries.map(([name, info]) => {
      const state = String(info.state || 'idle').toLowerCase();
      let dotColor = CRT.gray;
      let dotChar = '&#9675;'; // hollow circle = idle
      if (state === 'running' || state === 'done') { dotColor = CRT.green; dotChar = '&#9679;'; }
      else if (state === 'waiting' || state === 'build') { dotColor = CRT.amber; dotChar = '&#9679;'; }
      else if (state === 'error' || state === 'blocked') { dotColor = CRT.red; dotChar = '&#9679;'; }
      return `<div class="agentBadge">
        <span class="agentBadgeDot" style="color:${dotColor}">${dotChar}</span>
        <span class="agentBadgeName">${escapeHtml(name.replace('_', ' '))}</span>
        <span class="agentBadgeState">${escapeHtml(state)}</span>
      </div>`;
    });
    return `<div class="agentGrid">${rows.join('')}</div>`;
  }

  debugLoopHtml() {
    const data = this._agentStatus;
    const debugger_ = (data && data.agents && data.agents.debugger) ? data.agents.debugger : null;
    if (!debugger_ || debugger_.state !== 'running') return '';
    const iter = debugger_.iteration || 0;
    const maxIter = debugger_.max_iterations || 10;
    const pct = Math.min(100, Math.round((iter / maxIter) * 100));
    const filledBars = Math.round(pct / 5); // 20 chars total
    const bar = '\u2588'.repeat(filledBars) + '\u2591'.repeat(20 - filledBars);
    const issue = debugger_.issue_signature ? escapeHtml(debugger_.issue_signature) : '';
    return `<div class="block">
      <div class="blockTitle">&#128030; DEBUG LOOP</div>
      <div class="debugBar">Iteration: ${iter}/${maxIter}  ${bar}  ${pct}%</div>
      ${issue ? `<div class="debugInfo">Issue: ${issue}</div>` : ''}
    </div>`;
  }

  stateMachineHtml() {
    const agentData = this._agentStatus;
    const sessionData = this._sessionState;
    // Try orchestrator state first, fall back to session state
    const orch = (agentData && agentData.agents && agentData.agents.orchestrator) ? agentData.agents.orchestrator : null;
    const state = orch ? String(orch.state || 'idle').toUpperCase()
      : sessionData ? String(sessionData.state || 'idle').toUpperCase()
      : 'IDLE';
    const cycle = orch ? (orch.cycle || 0) : (sessionData ? (sessionData.cycle || 0) : 0);
    const stateColor = state === 'RUNNING' || state === 'BUILD' ? CRT.cyan
      : state === 'WAITING' ? CRT.amber
      : state === 'ERROR' || state === 'BLOCKED' ? CRT.red
      : CRT.green;
    return `<div class="stateIndicator">
      <span class="stateName" style="color:${stateColor}">${escapeHtml(state)}</span>
      <span class="stateCycle">cycle: ${cycle}</span>
    </div>`;
  }

  // ── ROSTER: scan agents + skills + invocation counts ──
  _loadFullRoster() {
    const homeDir = os.homedir();
    const roster = { agents: [], skills: [] };
    const registryPath = path.join(homeDir, '.claude', 'project_registry.json');
    const seenAgents = new Set();
    const seenSkills = new Set();

    // 1. PRIMARY SOURCE: project_registry.json (source of truth)
    try {
      const regData = fs.readFileSync(registryPath, 'utf8');
      const registry = JSON.parse(regData);

      // Extract agents from project agent dirs
      if (registry.projects) {
        for (const [pName, pCfg] of Object.entries(registry.projects)) {
          // Scan agents_dir if available
          if (pCfg.agents_dir) {
            try {
              const files = fs.readdirSync(pCfg.agents_dir).filter(f => f.endsWith('.md') && f !== 'AGENTS.md' && f !== 'AGENT_TEMPLATE.md');
              for (const f of files) {
                const name = f.replace(/\.md$/, '');
                if (!seenAgents.has(name)) {
                  seenAgents.add(name);
                  roster.agents.push({ name, source: pCfg.agents_dir, project: pName });
                }
              }
            } catch { /* dir not found */ }
          }
        }
      }

      // Extract skills from skill_triggers keys
      if (registry.skill_triggers) {
        for (const [trigger, skillNames] of Object.entries(registry.skill_triggers)) {
          const names = Array.isArray(skillNames) ? skillNames : [skillNames];
          for (const name of names) {
            if (name && !seenSkills.has(name)) {
              seenSkills.add(name);
              roster.skills.push({ name });
            }
          }
        }
      }
    } catch { /* registry not available */ }

    // 2. FALLBACK: scan global agents dir + skills dir (for items not in registry)
    const globalAgentsDir = path.join(homeDir, '.claude', 'agents');
    try {
      const files = fs.readdirSync(globalAgentsDir).filter(f => f.endsWith('.md') && f !== 'AGENTS.md' && f !== 'AGENT_TEMPLATE.md');
      for (const f of files) {
        const name = f.replace(/\.md$/, '');
        if (!seenAgents.has(name)) {
          seenAgents.add(name);
          roster.agents.push({ name, source: globalAgentsDir });
        }
      }
    } catch { /* dir not found */ }

    const skillsDir = path.join(homeDir, '.claude', 'skills');
    try {
      const entries = fs.readdirSync(skillsDir, { withFileTypes: true });
      for (const e of entries) {
        if (e.isDirectory() && !seenSkills.has(e.name)) {
          seenSkills.add(e.name);
          roster.skills.push({ name: e.name });
        }
      }
    } catch { /* skills dir not found */ }

    // 3. Cross-reference with invocation log for counts + last usage
    const invocPath = path.join(homeDir, '.claude', 'metrics', 'agent_invocations.jsonl');
    const invocCounts = {};
    const invocLast = {};
    try {
      const lines = fs.readFileSync(invocPath, 'utf8').trim().split('\n');
      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          const n = entry.name || entry.agent || entry.skill || '';
          if (!n) continue;
          invocCounts[n] = (invocCounts[n] || 0) + 1;
          if (entry.ts && (!invocLast[n] || entry.ts > invocLast[n])) {
            invocLast[n] = entry.ts;
          }
        } catch { /* skip malformed line */ }
      }
    } catch { /* no invocations file */ }

    // Enrich agents and skills with counts
    for (const a of roster.agents) {
      a.count = invocCounts[a.name] || 0;
      a.lastUsed = invocLast[a.name] || null;
    }
    for (const s of roster.skills) {
      s.count = invocCounts[s.name] || 0;
      s.lastUsed = invocLast[s.name] || null;
    }

    // Sort by last used (desc), then by name
    const sortByUsage = (a, b) => {
      if (a.lastUsed && b.lastUsed) return b.lastUsed.localeCompare(a.lastUsed);
      if (a.lastUsed) return -1;
      if (b.lastUsed) return 1;
      return a.name.localeCompare(b.name);
    };
    roster.agents.sort(sortByUsage);
    roster.skills.sort(sortByUsage);

    this._fullRoster = roster;
  }

  fullRosterHtml() {
    const r = this._fullRoster;
    if (!r) return `<span class="caDim">Roster non charge</span>`;

    const arrow = this._rosterExpanded ? '&#9660;' : '&#9654;';
    const agentCount = r.agents.length;
    const skillCount = r.skills.length;
    const header = `<div class="rosterToggle" onclick="send('toggleRoster')">${arrow} ${agentCount} agents, ${skillCount} skills</div>`;

    if (!this._rosterExpanded) return header;

    // Active agent names from current session
    const activeNames = new Set();
    const s = this._sessionState;
    if (s && Array.isArray(s.recent_skills)) {
      s.recent_skills.forEach(sk => activeNames.add(sk.name));
    }

    const renderItems = (items, limit) => {
      const shown = items.slice(0, limit);
      return shown.map(it => {
        const isActive = activeNames.has(it.name);
        const nameCls = isActive ? 'rosterName active' : 'rosterName';
        const last = it.lastUsed ? escapeHtml(it.lastUsed.slice(0, 10)) : '';
        const countBadge = it.count > 0 ? `<span class="rosterCount">x${it.count}</span>` : '';
        return `<div class="rosterItem"><span class="${nameCls}">${escapeHtml(it.name)}</span><span><span class="rosterMeta">${last}</span>${countBadge}</span></div>`;
      }).join('');
    };

    const agentsHtml = r.agents.length > 0
      ? `<div class="rosterSection"><div class="rosterSectionTitle">Agents (${agentCount})</div><div class="rosterList">${renderItems(r.agents, 30)}</div></div>`
      : '';
    const skillsHtml = r.skills.length > 0
      ? `<div class="rosterSection"><div class="rosterSectionTitle">Skills (${skillCount})</div><div class="rosterList">${renderItems(r.skills, 50)}</div></div>`
      : '';

    return `${header}${agentsHtml}${skillsHtml}`;
  }

  // ── SESSIONS: OS processes + multi-project session.json ──
  _loadClaudeSessions() {
    const sessions = { processes: [], projects: [] };

    // 1. Detect claude OS processes (Windows)
    try {
      const result = cp.execSync(
        'powershell -NoProfile -Command "Get-Process claude -ErrorAction SilentlyContinue | Select-Object Id,WorkingSet64,StartTime | ConvertTo-Json"',
        { timeout: 5000, encoding: 'utf8', windowsHide: true }
      );
      if (result && result.trim()) {
        let parsed = JSON.parse(result.trim());
        if (!Array.isArray(parsed)) parsed = [parsed];
        for (const p of parsed) {
          sessions.processes.push({
            pid: p.Id,
            memMB: p.WorkingSet64 ? Math.round(p.WorkingSet64 / 1024 / 1024) : 0,
            startTime: p.StartTime ? String(p.StartTime) : '',
          });
        }
      }
    } catch { /* no claude processes or powershell error */ }

    // 2. Multi-project session.json scan
    const homeDir = os.homedir();
    try {
      const registryPath = path.join(homeDir, '.claude', 'project_registry.json');
      const regData = fs.readFileSync(registryPath, 'utf8');
      const registry = JSON.parse(regData);
      if (registry.projects) {
        for (const [pName, pCfg] of Object.entries(registry.projects)) {
          // Derive project root from agents_dir (go up from .claude/agents)
          let projectRoot = null;
          if (pCfg.agents_dir) {
            projectRoot = path.resolve(pCfg.agents_dir, '..', '..');
          }
          if (!projectRoot) continue;

          const sessionPath = path.join(projectRoot, 'tools', 'autodev', 'status', 'session.json');
          try {
            const data = JSON.parse(fs.readFileSync(sessionPath, 'utf8'));
            const updatedAt = data.updated_at || '';
            const ageMs = updatedAt ? Date.now() - new Date(updatedAt).getTime() : Infinity;
            const ageSec = Math.round(ageMs / 1000);
            let status = 'offline';
            if (ageSec < 60) status = 'active';
            else if (ageSec < 300) status = 'stale';

            sessions.projects.push({
              name: pCfg.display_name || pName,
              key: pName,
              objective: data.objective || '',
              state: data.state || 'idle',
              updatedAt,
              ageSec,
              status,
              isCurrent: projectRoot === this.root,
            });
          } catch { /* session.json not found for this project */ }
        }
      }
    } catch { /* registry not available */ }

    this._claudeSessions = sessions;
  }

  claudeSessionsHtml() {
    const data = this._claudeSessions;
    if (!data) return `<span class="caDim">Sessions non chargees</span>`;

    const arrow = this._sessionsExpanded ? '&#9660;' : '&#9654;';
    const procCount = data.processes.length;
    const projCount = data.projects.length;
    const header = `<div class="rosterToggle" onclick="send('toggleSessions')">${arrow} ${procCount} process, ${projCount} projets</div>`;

    if (!this._sessionsExpanded) return header;

    // PID section
    let pidHtml = '';
    if (data.processes.length > 0) {
      pidHtml = data.processes.map(p => {
        const startShort = p.startTime ? String(p.startTime).slice(0, 19) : '';
        return `<div class="pidRow"><span class="pidLabel">PID ${escapeHtml(String(p.pid))}</span><span class="pidMem">${escapeHtml(String(p.memMB))} MB</span><span class="rosterMeta">${escapeHtml(startShort)}</span></div>`;
      }).join('');
    } else {
      pidHtml = `<span class="caDim">Aucun process claude detecte</span>`;
    }

    // Projects section
    let projHtml = '';
    if (data.projects.length > 0) {
      projHtml = data.projects.map(p => {
        const currentCls = p.isCurrent ? 'sessionCard current' : 'sessionCard';
        const badgeCls = p.status === 'active' ? 'badge-active' : p.status === 'stale' ? 'badge-stale' : 'badge-offline';
        const badgeLabel = p.status.toUpperCase();
        const ageLabel = p.ageSec < 60 ? `${p.ageSec}s` : p.ageSec < 3600 ? `${Math.round(p.ageSec / 60)}m` : `${Math.round(p.ageSec / 3600)}h`;
        const obj = p.objective ? escapeHtml(p.objective.slice(0, 50)) : '';
        const safeKey = p.key.replace(/[^a-zA-Z0-9_-]/g, '_');
        const prjCls = `agentPrj agentPrj-${safeKey}`;
        return `<div class="${currentCls}">
          <span><span class="${prjCls}">${escapeHtml(p.name)}</span> <span class="${badgeCls}">${badgeLabel}</span> <span class="rosterMeta">${ageLabel} ago</span></span>
          ${obj ? `<div style="color:${CRT.gray};font-size:8px;margin-top:1px">${obj}</div>` : ''}
        </div>`;
      }).join('');
    } else {
      projHtml = `<span class="caDim">Aucun projet avec session.json</span>`;
    }

    return `${header}
      <div class="rosterSection"><div class="rosterSectionTitle">Processus OS</div>${pidHtml}</div>
      <div class="rosterSection"><div class="rosterSectionTitle">Projets</div>${projHtml}</div>`;
  }

  claudeActivityHtml() {
    const s = this._sessionState;
    if (!s) return `<div class="claudeActivity"><div class="blockTitle">&#9889; CLAUDE CODE</div><span class="caDim">session.json non disponible</span></div>`;

    const modeBadge = s.plan_mode
      ? `<span class="badge-plan">&#128208; PLAN MODE</span>`
      : `<span class="badge-interactive">&#9889; INTERACTIVE</span>`;

    const compliance = s.gate_compliance
      ? `<div class="caCompliance">Gate: ${s.gate_compliance.completed}/${s.gate_compliance.total} actions (${s.gate_compliance.pct}%)</div>`
      : '';

    const objective = s.objective
      ? `<div class="caObjective">${escapeHtml(s.objective)}</div>`
      : '';

    const skills = Array.isArray(s.recent_skills) && s.recent_skills.length > 0
      ? s.recent_skills.slice(0, 15).map(sk =>
          `<div class="caSkillRow"><span>&#10003; ${escapeHtml(sk.name)}</span><span class="caTs">${escapeHtml(sk.ts)}</span></div>`
        ).join('')
      : `<span class="caDim">Aucune action recente</span>`;

    return `<div class="claudeActivity">
      <div class="blockTitle">&#9889; CLAUDE CODE</div>
      ${modeBadge}
      ${objective}
      ${compliance}
      <div style="margin-top:3px">${skills}</div>
    </div>`;
  }

  brainStatusHtml(state) {
    const brainsState = (state && state.brains) || {};
    return BRAIN_LIST.map((b) => {
      const bs = brainsState[b] || {};
      const status = bs.status || 'pending';
      const icon = BRAIN_ICONS[status] || BRAIN_ICONS.pending;
      const label = BRAIN_LABELS[b];
      const selected = b === this.selectedBrain;
      const statusColor = status === 'running' ? CRT.cyan
        : status === 'complete' || status === 'ready' ? CRT.green
        : status === 'failed' ? CRT.red
        : CRT.gray;
      const bg = selected ? '#0c1e0c' : 'transparent';
      const border = selected ? `1px solid ${CRT.greenDim}` : '1px solid transparent';
      const time = bs.updated_at ? bs.updated_at.slice(11, 16) : '';
      return `<div style="cursor:pointer;background:${bg};border:${border};border-radius:3px;margin-bottom:2px" onclick="selectBrain('${b}')">
        <div style="display:flex;justify-content:space-between;align-items:center;padding:3px 6px;">
          <span><span style="color:${statusColor}">${icon}</span> ${escapeHtml(label)}</span>
          <span style="color:${CRT.gray};font-size:9px">${escapeHtml(status)}${time ? ' ' + time : ''}</span>
        </div>
        ${selected ? `<div class="brainDesc">${escapeHtml(BRAIN_DESCRIPTIONS[b] || '')}</div>` : ''}
      </div>`;
    }).join('');
  }

  _detectProjectId() {
    const root = this.root || '';
    if (/Godot-MCP/i.test(root)) return 'merlin';
    if (/Cours/i.test(root)) return 'cours';
    if (/Data|Partage VOC/i.test(root)) return 'data';
    return 'merlin';
  }

  _buildRosterForCanvas() {
    const r = this._fullRoster;
    if (!r) return null;

    // Build DataBridge-compatible format: { projects, commonAgents, skills }
    const projectId = this._detectProjectId();
    const rosterData = {
      projects: {},
      commonAgents: [],
      skills: []
    };

    // Group agents by guessed category
    for (const a of r.agents) {
      const cat = this._guessAgentCategory(a.name);
      rosterData.commonAgents.push({
        name: a.name,
        category: cat,
        description: ''
      });
    }

    // Skills
    for (const s of r.skills) {
      rosterData.skills.push({
        name: s.name,
        score: s.count || 0
      });
    }

    return rosterData;
  }

  _guessAgentCategory(name) {
    const n = String(name).toLowerCase();
    if (/game|godot|gdscript|scene|sprite|biome/.test(n)) return 'gameplay';
    if (/ui|ux|visual|css|html|frontend/.test(n)) return 'ui-ux';
    if (/llm|lora|ai|brain|swarm|ollama/.test(n)) return 'llm-lora';
    if (/data|query|sql|bigquery|hive|qlik|powerbi|dbeaver/.test(n)) return 'data';
    if (/test|review|security|build|tdd/.test(n)) return 'review';
    if (/doc|plan|architect/.test(n)) return 'planning';
    return 'general';
  }

  _buildInvocationMetrics() {
    const r = this._fullRoster;
    if (!r) return null;
    const topAgents = r.agents.filter(a => a.count > 0).map(a => ({ name: a.name, count: a.count }));
    const topSkills = r.skills.filter(s => s.count > 0).map(s => ({ name: s.name, count: s.count }));
    return { topAgents, topSkills };
  }

  _buildLiveAgents() {
    const live = [];
    const seen = new Set();

    // Source 1: active_agents.json (Task-based agents still in_progress)
    const data = this._activeAgents;
    if (data && Array.isArray(data.agents)) {
      for (const a of data.agents) {
        if (a.status === 'in_progress' && a.name) {
          const key = a.name.toLowerCase();
          if (!seen.has(key)) {
            seen.add(key);
            live.push({ name: a.name, project: a.project || 'unknown', description: a.task || '' });
          }
        }
      }
    }

    // Source 2: recent JSONL invocations (< 90s ago = likely still running)
    const recentInvocs = this._cachedRecentInvocations || [];
    const now = Date.now();
    for (const inv of recentInvocs) {
      const age = now - inv.tsMs;
      if (age < 90000) { // 90s window
        const name = inv.agent || inv.skill || '';
        const key = name.toLowerCase();
        if (name && !seen.has(key)) {
          seen.add(key);
          live.push({ name, project: inv.project || 'unknown', description: inv.description || '' });
        }
      }
    }

    // Source 3: session_context.json (last active agent, < 60s)
    const ctx = this._cachedSessionContext;
    if (ctx && ctx.last_agent) {
      const ctxAge = ctx.last_agent_ts ? (now - new Date(ctx.last_agent_ts).getTime()) : Infinity;
      if (ctxAge < 60000) {
        const key = ctx.last_agent.toLowerCase();
        if (!seen.has(key)) {
          seen.add(key);
          live.push({ name: ctx.last_agent, project: ctx.project || 'unknown', description: 'active (context)' });
        }
      }
    }

    return live.length > 0 ? live : null;
  }

  _buildParentMap() {
    // Return cached parent map (refreshed async every 10s)
    return this._cachedParentMap || {};
  }

  _refreshRecentInvocationsAsync() {
    const invocPath = path.join(os.homedir(), '.claude', 'metrics', 'agent_invocations.jsonl');
    fs.readFile(invocPath, 'utf8', (err, content) => {
      if (err || !content) { this._cachedRecentInvocations = []; return; }
      const lines = content.trim().split('\n');
      const recent = lines.slice(-20); // last 20 entries
      const entries = [];
      for (const line of recent) {
        try {
          const entry = JSON.parse(line);
          entry.tsMs = new Date(entry.ts).getTime();
          entries.push(entry);
        } catch { /* skip */ }
      }
      this._cachedRecentInvocations = entries;
    });
  }

  _refreshSessionContextAsync() {
    const ctxPath = path.join(os.homedir(), '.claude', 'metrics', '.session_context.json');
    fs.readFile(ctxPath, 'utf8', (err, data) => {
      if (err || !data) { this._cachedSessionContext = null; return; }
      try { this._cachedSessionContext = JSON.parse(data); }
      catch { this._cachedSessionContext = null; }
    });
  }

  _refreshParentMapAsync() {
    const invocPath = path.join(os.homedir(), '.claude', 'metrics', 'agent_invocations.jsonl');
    fs.readFile(invocPath, 'utf8', (err, content) => {
      if (err || !content) { this._cachedParentMap = {}; return; }
      const parentMap = {};
      const lines = content.trim().split('\n');
      const recent = lines.slice(-50);
      for (const line of recent) {
        try {
          const entry = JSON.parse(line);
          const name = entry.agent || entry.skill || '';
          const parent = entry.parent_agent || '';
          if (name && parent) parentMap[name] = parent;
        } catch { /* skip */ }
      }
      this._cachedParentMap = parentMap;
    });
  }

  update() {
    if (!this.view) return;
    const root = this.resolveRoot();
    if (root && !this.roadmap) this.loadRoadmap(root);
    if (root) BRAIN_LIST.forEach((b) => { if (!this.metrics[b]) this.loadMetrics(root, b); });
    const cfg = getConfig();
    const state = root ? readJson(remoteState(root)) : {};
    const rawStatus = String(root ? (state.last_status || 'idle') : 'chat_only');
    const trainDisabled = (this.isBusy || !root) ? 'disabled' : '';
    const chatDisabled = this.isBusy ? 'disabled' : '';
    const endpointLabel = cfg.testEndpoint ? cfg.testEndpoint : 'local Ollama';
    const brainsState = (state && state.brains) || {};
    const trainedCount = BRAIN_LIST.filter((b) => (brainsState[b] || {}).status === 'complete').length;
    const brainSummary = `${trainedCount}/${BRAIN_LIST.length} trained`;
    const selBrainState = brainsState[this.selectedBrain] || {};
    const selJob = selBrainState.job || '';

    const webview = this.view.webview;

    // 1. Send roster data to canvas (for NeuralRenderer)
    const rosterData = this._buildRosterForCanvas();
    if (rosterData) {
      webview.postMessage({
        type: 'rosterData',
        data: rosterData,
        projectId: this._detectProjectId()
      });
    }

    // 2. Send session status data (for DataBridge.applyStatus)
    const sessionData = this._sessionState || {};
    webview.postMessage({
      type: 'statusData',
      data: sessionData
    });

    // 3. Send live agents (for DataBridge.applyLiveActivity)
    const liveAgents = this._buildLiveAgents();
    if (liveAgents && liveAgents.length > 0) {
      webview.postMessage({
        type: 'liveAgents',
        agents: liveAgents
      });
    }

    // 4. Send metrics (for DataBridge.applyMetrics)
    const metrics = this._buildInvocationMetrics();
    if (metrics) {
      webview.postMessage({ type: 'metricsData', data: metrics });
    }

    // 5. Send parent map (for delegation traces)
    const parentMap = this._buildParentMap();
    if (Object.keys(parentMap).length > 0) {
      webview.postMessage({ type: 'parentData', map: parentMap });
    }

    // 6. Send text section HTML updates (incremental, no DOM rebuild)
    webview.postMessage({
      type: 'htmlUpdate',
      sections: {
        activity: this.claudeActivityHtml(),
        agents: `<div class="block"><div class="blockTitle">&#9889; Agents Actifs</div>${this.activeAgentsHtml()}</div>`,
        sessions: `<div class="block"><div class="blockTitle">&#128268; SESSIONS</div>${this.claudeSessionsHtml()}</div>`,
        more: this._moreHtml(state, cfg, trainDisabled, chatDisabled, endpointLabel, brainSummary, selBrainState, selJob)
      }
    });
  }

  _moreHtml(state, cfg, trainDisabled, chatDisabled, endpointLabel, brainSummary, selBrainState, selJob) {
    return `
      <div class="block">
        <div class="blockTitle">&#9889; STATE &mdash; ORCHESTRATOR</div>
        ${this.stateMachineHtml()}
        <div class="blockTitle" style="margin-top:6px">AGENTS</div>
        ${this.agentStatusBadgesHtml()}
      </div>
      <div class="block">
        <div class="blockTitle">&#128241; AGENT BUS</div>
        ${this.agentBusHtml()}
      </div>
      ${this.debugLoopHtml()}
      <div class="block">
        <div class="blockTitle">&#128218; ROSTER</div>
        ${this.fullRosterHtml()}
      </div>
      <div class="block">
        <div class="blockTitle">Brain Status Board &mdash; ${escapeHtml(brainSummary)}</div>
        <div style="border:1px solid ${CRT.border};border-radius:3px;padding:4px;margin:6px 0;background:#061006">${this.brainStatusHtml(state)}</div>
        <div class="btnRow">
          <button class="btnAmber" ${trainDisabled} onclick="send('trainAll')">Train All</button>
          <button class="btnCyan" ${trainDisabled} onclick="send('configure')">Configure</button>
          <button onclick="send('refresh')">Refresh</button>
        </div>
      </div>
      <div class="block">
        <div class="blockTitle">Actions &mdash; ${escapeHtml(BRAIN_LABELS[this.selectedBrain] || this.selectedBrain)}</div>
        <table>
          <tr><td class="k">Brain</td><td class="v">${escapeHtml(this.selectedBrain)}</td></tr>
          <tr><td class="k">Kernel</td><td class="v">${escapeHtml(selJob || 'non configure')}</td></tr>
          <tr><td class="k">Status</td><td class="v">${escapeHtml(selBrainState.status || 'pending')}</td></tr>
        </table>
        <div class="btnRow">
          <button ${trainDisabled} onclick="sendBrain('doctor')">Doctor</button>
          <button ${trainDisabled} onclick="sendBrain('setup')">Setup</button>
          <button ${trainDisabled} onclick="sendBrain('submit')">Submit</button>
          <button ${trainDisabled} onclick="sendBrain('status')">Status</button>
          <button ${trainDisabled} onclick="sendBrain('download')">Download</button>
        </div>
      </div>
      <div class="block">
        <div class="blockTitle">M\u00e9triques Training</div>
        ${this.metricsHtml()}
      </div>
      <div class="block">
        <div class="blockTitle">Chat Merlin</div>
        <table>
          <tr><td class="k">Model</td><td class="v">${escapeHtml(cfg.testModel)}</td></tr>
          <tr><td class="k">Endpoint</td><td class="v">${escapeHtml(endpointLabel)}</td></tr>
        </table>
        <div class="modeToggle">
          <div class="modeBtn ${this.chatMode === 'merlin' ? 'active-merlin' : ''}" onclick="send('toggleChatMode')">&#9670; Merlin</div>
          <div class="modeBtn ${this.chatMode === 'dev' ? 'active-dev' : ''}" onclick="send('toggleChatMode')">&#9654; Dev</div>
        </div>
        <div class="chatWrap">
          <div class="chatLog">${this.chatHtml()}</div>
          <textarea id="prompt" placeholder="${this.chatMode === 'merlin' ? 'Parle \u00e0 Merlin...' : 'Question technique...'}"></textarea>
          <div class="btnRow">
            <button class="btnCyan" ${chatDisabled} onclick="chat()">Send</button>
            <button ${chatDisabled} onclick="quickHello()">Bonjour</button>
            <button ${chatDisabled} onclick="clearBox()">Clear</button>
          </div>
        </div>
      </div>
      <div class="block">
        <div class="blockTitle">Prochaines Sessions</div>
        ${this.nextSessionsHtml()}
      </div>`;
  }
  refresh() {
    this.update();
  }
}

// ── ACTIVATE ──
function activate(context) {
  const root = findProjectRoot();
  const provider = new RemoteTrainProvider(root);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('autodev-v4.remoteTrain', provider),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.open', async () => provider.openPanel()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.refresh', () => provider.refresh()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.configure', async () => provider.configure()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.doctor', async () => provider.runRemote('doctor')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.setup', async () => provider.runRemote('setup')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.submit', async () => provider.runRemote('submit')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.status', async () => provider.runRemote('status')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.download', async () => provider.runRemote('download')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.openKaggle', () => provider.openKaggle())
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
