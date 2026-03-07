const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
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

    const proc = cp.spawn(runtime.cmd, fullArgs, { cwd: root, shell: false });
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

async function directChat(prompt, cfg) {
  const endpoint = normalizeChatEndpoint(cfg.testEndpoint);
  if (endpoint) {
    const apiKey = resolveApiKey(endpoint, cfg.testApiKey);
    const headers = apiKey ? { Authorization: `Bearer ${apiKey}` } : {};
    const payload = {
      model: cfg.testModel,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.7,
      max_tokens: 350,
    };
    const data = await postJson(endpoint, payload, headers);
    const reply = data?.choices?.[0]?.message?.content;
    return String(reply || '').trim() || '(reponse vide)';
  }

  const payload = {
    model: cfg.testModel,
    messages: [{ role: 'user', content: prompt }],
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
        case 'chat':
          await this.chatSend(String(msg.prompt || '').trim());
          break;
      }
    });
    this.update();
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
    this.update();
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
    this.chat.push({ role: 'user', content: prompt });
    this.isBusy = true;
    this.update();

    this.output.show(true);
    try {
      let reply = '';
      if (root) {
        const args = ['chat', '--workspace', root, '--prompt', prompt, '--model', cfg.testModel];
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
        reply = await directChat(prompt, cfg);
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
      return `<div style="display:flex;justify-content:space-between;align-items:center;padding:3px 6px;cursor:pointer;background:${bg};border:${border};border-radius:3px;margin-bottom:2px" onclick="selectBrain('${b}')">
        <span><span style="color:${statusColor}">${icon}</span> ${escapeHtml(label)}</span>
        <span style="color:${CRT.gray};font-size:9px">${escapeHtml(status)}${time ? ' ' + time : ''}</span>
      </div>`;
    }).join('');
  }

  update() {
    if (!this.view) return;
    const root = this.resolveRoot();
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

    // Count trained brains
    const brainsState = (state && state.brains) || {};
    const trainedCount = BRAIN_LIST.filter((b) => (brainsState[b] || {}).status === 'complete').length;
    const brainSummary = `${trainedCount}/${BRAIN_LIST.length} trained`;

    // Selected brain info
    const selBrainState = brainsState[this.selectedBrain] || {};
    const selJob = selBrainState.job || '';

    this.view.webview.html = `<!DOCTYPE html><html><head><style>${CSS}
      .brainBoard { border:1px solid ${CRT.border}; border-radius:3px; padding:4px; margin:6px 0; background:#061006; }
    </style></head><body>
      <div class="header">
        <span class="title">MERLIN MULTI-BRAIN</span>
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
          <button ${trainDisabled} onclick="sendBrain('doctor')">Doctor</button>
          <button ${trainDisabled} onclick="sendBrain('setup')">Setup</button>
          <button ${trainDisabled} onclick="sendBrain('submit')">Submit</button>
          <button ${trainDisabled} onclick="sendBrain('status')">Status</button>
          <button ${trainDisabled} onclick="sendBrain('download')">Download</button>
        </div>
        <div class="btnRow">
          <button class="btnAmber" ${openDisabled} onclick="send('openKaggle')">Open Kaggle</button>
        </div>
        <div class="hint">Click a brain above to select it, then use actions.</div>
      </div>

      <div class="block">
        <div class="blockTitle">Chat Merlin</div>
        <table>
          <tr><td class="k">Model</td><td class="v">${escapeHtml(cfg.testModel)}</td></tr>
          <tr><td class="k">Endpoint</td><td class="v">${escapeHtml(endpointLabel)}</td></tr>
        </table>
        <div class="btnRow">
          <button ${chatDisabled} onclick="send('presetTogether')">Preset Together</button>
          <button ${chatDisabled} onclick="send('presetGroq')">Preset Groq</button>
          <button ${chatDisabled} onclick="send('presetRunpod')">Preset RunPod</button>
        </div>
        <div class="chatWrap">
          <div class="chatLog">${this.chatHtml()}</div>
          <textarea id="prompt" placeholder="Parle a Merlin ici..."></textarea>
          <div class="btnRow">
            <button class="btnCyan" ${chatDisabled} onclick="chat()">Send</button>
            <button ${chatDisabled} onclick="quickHello()">Bonjour</button>
            <button ${chatDisabled} onclick="clearBox()">Clear</button>
          </div>
        </div>
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

// ── STATUS READER ──
// Reads tools/autodev/status/*.json and normalizes to a unified data model
class StatusReader {
  constructor(statusDir) {
    this.statusDir = statusDir;
    this.listeners = [];
    this.watcher = null;
    this.pollInterval = null;
    this.debounceTimer = null;
    this.lastData = null;
  }

  start() {
    if (!fs.existsSync(this.statusDir)) {
      // Poll until directory appears
      this.pollInterval = setInterval(() => {
        if (fs.existsSync(this.statusDir)) {
          clearInterval(this.pollInterval);
          this._startWatching();
        }
      }, 3000);
      return;
    }
    this._startWatching();
  }

  _startWatching() {
    // fs.watch
    try {
      this.watcher = fs.watch(this.statusDir, { persistent: false }, () => {
        this._debouncedRead();
      });
    } catch {
      // fs.watch can fail on some setups
    }
    // Polling fallback (2s)
    this.pollInterval = setInterval(() => this._readAll(), 2000);
    // Initial read
    this._readAll();
  }

  _debouncedRead() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => this._readAll(), 500);
  }

  _readAll() {
    const data = this._buildNormalized();
    const json = JSON.stringify(data);
    if (json !== JSON.stringify(this.lastData)) {
      this.lastData = data;
      for (const fn of this.listeners) fn(data);
    }
  }

  _buildNormalized() {
    const controlState = readJson(path.join(this.statusDir, 'control_state.json'));
    const session = readJson(path.join(this.statusDir, 'session.json'));
    const healthReport = readJson(path.join(this.statusDir, 'health_report.json'));

    // Determine global state
    const state = controlState.state || session.state || 'idle';
    const objective = controlState.objective || session.objective || '';
    const checkpoint = session.checkpoint || '';

    // Collect workers from multiple sources
    const workers = [];
    const seen = new Set();

    // From session.json workers array
    if (Array.isArray(session.workers)) {
      for (const w of session.workers) {
        const domain = w.name || w.domain || 'unknown';
        if (seen.has(domain)) continue;
        seen.add(domain);
        workers.push({
          domain,
          status: w.status || 'pending',
          current_task: w.current_task || '',
          progress: w.progress || 0,
          files_modified: w.files_modified || [],
          error: w.error || '',
          blockers: w.blockers || [],
        });
      }
    }

    // From health_report.json worker_statuses
    if (healthReport.worker_statuses) {
      for (const [domain, ws] of Object.entries(healthReport.worker_statuses)) {
        if (seen.has(domain)) continue;
        seen.add(domain);
        workers.push({
          domain,
          status: ws.status || 'pending',
          current_task: ws.current_task || '',
          progress: ws.progress || 0,
          files_modified: ws.files_modified || [],
          error: ws.error || '',
          blockers: ws.blockers || [],
        });
      }
    }

    // From individual domain JSON files
    const domainFiles = ['gameplay', 'ui-ux', 'llm-lora', 'world-structure', 'visual-polish', 'game-director'];
    for (const d of domainFiles) {
      if (seen.has(d)) continue;
      const fp = path.join(this.statusDir, `${d}.json`);
      if (!fs.existsSync(fp)) continue;
      const ws = readJson(fp);
      if (!ws.domain) continue;
      seen.add(d);
      workers.push({
        domain: ws.domain,
        status: ws.status || 'pending',
        current_task: ws.current_task || '',
        progress: ws.progress || 0,
        files_modified: ws.files_modified || [],
        error: ws.error || '',
        blockers: ws.blockers || [],
      });
    }

    return { state, objective, checkpoint, workers };
  }

  onUpdate(fn) {
    this.listeners.push(fn);
  }

  stop() {
    if (this.watcher) { try { this.watcher.close(); } catch {} }
    if (this.pollInterval) clearInterval(this.pollInterval);
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
  }
}

// ── PROJECT DETECTION ──
function detectProject() {
  // 1. Explicit config override
  const cfgProject = vscode.workspace.getConfiguration('autodev-v4.robotMonitor').get('project', 'auto');
  if (cfgProject && cfgProject !== 'auto') return cfgProject;

  // 2. Heuristic from workspace
  const folders = vscode.workspace.workspaceFolders;
  if (folders) {
    for (const f of folders) {
      const root = f.uri.fsPath;
      if (fs.existsSync(path.join(root, 'project.godot'))) return 'merlin';
      if (/partage.voc|data|orange/i.test(root)) return 'data';
      if (/cours|teaching|ecole/i.test(root)) return 'cours';
    }
  }

  // 3. Default
  return 'merlin';
}

const THEME_BG = { merlin: '#050a05', data: '#0a0500', cours: '#050508' };

// ── ROBOT MONITOR PROVIDER ──
class RobotMonitorProvider {
  constructor(statusDir, extensionUri) {
    this.statusDir = statusDir;
    this.extensionUri = extensionUri;
    this.view = null;
    this.statusReader = new StatusReader(statusDir);
    this.statusReader.onUpdate((data) => this._sendUpdate(data));
    this.statusReader.start();
  }

  resolveWebviewView(view) {
    this.view = view;
    view.webview.options = { enableScripts: true };

    const projectId = detectProject();
    const bodyBg = THEME_BG[projectId] || '#050a05';

    // Read core and webview scripts
    const extPath = this.extensionUri.fsPath || path.dirname(__filename);
    const coreJs = fs.readFileSync(path.join(extPath, 'robot-monitor-core.js'), 'utf8');
    const webviewJs = fs.readFileSync(path.join(extPath, 'robot-monitor-webview.js'), 'utf8');

    view.webview.html = `<!DOCTYPE html>
<html>
<head>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: ${bodyBg}; overflow: hidden; font-family: 'Cascadia Code', 'Fira Code', Consolas, monospace; }
#robotContainer { width: 100%; height: 100vh; display: flex; flex-direction: column; }
#robotCanvas { display: block; flex: 1 1 auto; image-rendering: pixelated; image-rendering: crisp-edges; }
#taskPanel { flex: 0 0 auto; max-height: 35%; overflow-y: auto; }
</style>
</head>
<body>
<div id="robotContainer">
  <canvas id="robotCanvas"></canvas>
  <div id="taskPanel"></div>
</div>
<script>window.__ROBOT_PROJECT = '${projectId}';</script>
<script>${coreJs}</script>
<script>${webviewJs}</script>
</body>
</html>`;

    // Send initial data if available
    if (this.statusReader.lastData) {
      this._sendUpdate(this.statusReader.lastData);
    }

    view.onDidDispose(() => { this.view = null; });
  }

  _sendUpdate(data) {
    if (this.view && this.view.webview) {
      this.view.webview.postMessage({ type: 'statusUpdate', data });
    }
  }

  dispose() {
    this.statusReader.stop();
  }
}

function activate(context) {
  const root = findProjectRoot();
  const provider = new RemoteTrainProvider(root);

  // Robot Monitor
  const statusDir = root
    ? path.join(root, 'tools', 'autodev', 'status')
    : path.join(process.cwd(), 'tools', 'autodev', 'status');
  const robotProvider = new RobotMonitorProvider(statusDir, context.extensionUri);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('autodev-v4.remoteTrain', provider),
    vscode.window.registerWebviewViewProvider('autodev-v4.robotMonitor', robotProvider),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.open', async () => provider.openPanel()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.refresh', () => provider.refresh()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.configure', async () => provider.configure()),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.doctor', async () => provider.runRemote('doctor')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.setup', async () => provider.runRemote('setup')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.submit', async () => provider.runRemote('submit')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.status', async () => provider.runRemote('status')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.download', async () => provider.runRemote('download')),
    vscode.commands.registerCommand('autodev-v4.remoteTrain.openKaggle', () => provider.openKaggle()),
    vscode.commands.registerCommand('autodev-v4.robotMonitor.openStandalone', () => {
      const serverScript = path.join(context.extensionUri.fsPath, 'robot-monitor-server.js');
      const projectId = detectProject();
      const proc = cp.spawn('node', [serverScript, '--status-dir', statusDir, '--port', '3847', '--project', projectId], {
        detached: true, stdio: 'ignore',
      });
      proc.unref();
      setTimeout(() => {
        vscode.env.openExternal(vscode.Uri.parse('http://localhost:3847'));
      }, 800);
    })
  );

  context.subscriptions.push({ dispose: () => robotProvider.dispose() });
}

function deactivate() {}

module.exports = { activate, deactivate };

