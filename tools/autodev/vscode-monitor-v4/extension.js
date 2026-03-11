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
  }

  resolveRoot() {
    this.root = findProjectRoot();
    return this.root;
  }

  resolveWebviewView(view) {
    this.view = view;
    view.webview.options = { enableScripts: true };
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
        case 'chat':
          await this.chatSend(String(msg.prompt || '').trim());
          break;
      }
    });
    this.resolveRoot();
    this._loadSessionState();
    this.update();

    // Poll session.json every 3s for live Claude Code activity display
    if (this._sessionPoll) clearInterval(this._sessionPoll);
    this._sessionPoll = setInterval(() => {
      this.resolveRoot();
      this._loadSessionState();
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
      ? s.recent_skills.map(sk =>
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

  update() {
    if (!this.view) return;
    const root = this.resolveRoot();
    if (root && !this.roadmap) this.loadRoadmap(root);
    if (root) BRAIN_LIST.forEach((b) => { if (!this.metrics[b]) this.loadMetrics(root, b); });
    const cfg = getConfig();
    const state = root ? readJson(remoteState(root)) : {};
    const rawStatus = String(root ? (state.last_status || 'idle') : 'chat_only');
    const color = this.isBusy
      ? CRT.cyan
      : /success|ready|submitted|running|complete|checked/i.test(rawStatus)
      ? CRT.green
      : /fail|error/i.test(rawStatus)
      ? CRT.red
      : root
      ? CRT.amber
      : CRT.cyan;
    const statusLabel = this.isBusy ? 'BUSY' : (root ? rawStatus.toUpperCase() : 'CHAT ONLY');
    const trainDisabled = (this.isBusy || !root) ? 'disabled' : '';
    const openDisabled = this.isBusy ? 'disabled' : '';
    const chatDisabled = this.isBusy ? 'disabled' : '';
    const endpointLabel = cfg.testEndpoint ? cfg.testEndpoint : 'local Ollama';

    const brainsState = (state && state.brains) || {};
    const trainedCount = BRAIN_LIST.filter((b) => (brainsState[b] || {}).status === 'complete').length;
    const brainSummary = `${trainedCount}/${BRAIN_LIST.length} trained`;

    const selBrainState = brainsState[this.selectedBrain] || {};
    const selJob = selBrainState.job || '';

    this.view.webview.html = `<!DOCTYPE html><html><head><style>${CSS}
      .brainBoard { border:1px solid ${CRT.border}; border-radius:3px; padding:4px; margin:6px 0; background:#061006; }
    </style></head><body>
      <div class="header">
        <span class="title">M.E.R.L.I.N. REMOTE</span>
        <span class="status" style="color:${color}">${escapeHtml(statusLabel)}</span>
      </div>

      <div class="block">
        <div class="blockTitle">Brain Status Board &mdash; ${escapeHtml(brainSummary)}</div>
        <div class="brainBoard">${this.brainStatusHtml(state)}</div>
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
          <button ${trainDisabled} title="${escapeHtml(ACTION_DESCRIPTIONS.doctor)}" onclick="sendBrain('doctor')">Doctor</button>
          <button ${trainDisabled} title="${escapeHtml(ACTION_DESCRIPTIONS.setup)}" onclick="sendBrain('setup')">Setup</button>
          <button ${trainDisabled} title="${escapeHtml(ACTION_DESCRIPTIONS.submit)}" onclick="sendBrain('submit')">Submit</button>
          <button ${trainDisabled} title="${escapeHtml(ACTION_DESCRIPTIONS.status)}" onclick="sendBrain('status')">Status</button>
          <button ${trainDisabled} title="${escapeHtml(ACTION_DESCRIPTIONS.download)}" onclick="sendBrain('download')">Download</button>
        </div>
        <div class="btnRow">
          <button class="btnAmber" ${openDisabled} onclick="send('openKaggle')">Open Kaggle</button>
        </div>
        <div class="hint">Survolez un bouton pour voir sa description. Cliquez un brain pour le s\u00e9lectionner.</div>
      </div>

      <div class="block">
        <div class="blockTitle">M\u00e9triques Training</div>
        ${this.metricsHtml()}
        <div class="hint" style="margin-top:4px">Mis \u00e0 jour apr\u00e8s chaque Download.</div>
        ${this.claudeActivityHtml()}
      </div>

      <div class="block">
        <div class="blockTitle">Chat Merlin</div>
        <table>
          <tr><td class="k">Model</td><td class="v">${escapeHtml(cfg.testModel)}</td></tr>
          <tr><td class="k">Endpoint</td><td class="v">${escapeHtml(endpointLabel)}</td></tr>
        </table>
        <div class="modeToggle">
          <div class="modeBtn ${this.chatMode === 'merlin' ? 'active-merlin' : ''}" onclick="send('toggleChatMode')" title="Merlin — persona myst\u00e9rieux, celtique">&#9670; Merlin</div>
          <div class="modeBtn ${this.chatMode === 'dev' ? 'active-dev' : ''}" onclick="send('toggleChatMode')" title="Dev — assistant technique du projet">&#9654; Dev</div>
        </div>
        <div class="btnRow">
          <button ${chatDisabled} onclick="send('presetTogether')">Preset Together</button>
          <button ${chatDisabled} onclick="send('presetGroq')">Preset Groq</button>
          <button ${chatDisabled} onclick="send('presetRunpod')">Preset RunPod</button>
        </div>
        <div class="chatWrap">
          <div class="chatLog">${this.chatHtml()}</div>
          <textarea id="prompt" placeholder="${this.chatMode === 'merlin' ? 'Parle \u00e0 Merlin...' : 'Question technique sur le projet...'}"></textarea>
          <div class="btnRow">
            <button class="btnCyan" ${chatDisabled} onclick="chat()">Send</button>
            <button ${chatDisabled} onclick="quickHello()">Bonjour</button>
            <button ${chatDisabled} onclick="clearBox()">Clear</button>
          </div>
        </div>
      </div>

      <div class="block">
        <div class="blockTitle">Prochaines Sessions d\u2019Entra\u00eenement</div>
        ${this.nextSessionsHtml()}
        <div class="hint" style="margin-top:4px">Fichier\u00a0: .merlin_remote/training_roadmap.json</div>
      </div>

      <script>
        const vscode = acquireVsCodeApi();
        function send(type) { vscode.postMessage({ type }); }
        function selectBrain(brain) { vscode.postMessage({ type: 'selectBrain', brain }); }
        function sendBrain(action) { vscode.postMessage({ type: action, brain: '${this.selectedBrain}' }); }
        function clearBox() { document.getElementById('prompt').value = ''; }
        function chat() {
          const el = document.getElementById('prompt');
          const prompt = (el.value || '').trim();
          if (!prompt) return;
          vscode.postMessage({ type: 'chat', prompt });
          el.value = '';
        }
        function quickHello() { vscode.postMessage({ type: 'chat', prompt: 'Bonjour Merlin' }); }
      </script>
    </body></html>`;
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
