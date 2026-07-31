/**
 * MERLIN Studio — extension VS Code.
 *
 * Pilote à distance le studio de dev hébergé sur la VM Oracle (tools/merlin_studio),
 * exposé en HTTPS par le tunnel Cloudflare et protégé par Basic-auth.
 *
 * Aucune dépendance npm : http/https natifs (pas de fetch global — VS Code 1.80
 * embarque encore Node 16 chez certains). Le token est rangé dans le SecretStorage
 * de VS Code, jamais dans les settings ni dans le dépôt.
 */
const vscode = require("vscode");
const http = require("http");
const https = require("https");
const { URL } = require("url");

const SECRET_KEY = "merlinStudio.token";
let out; // OutputChannel
let statusBar;
let ctxRef;
let timer;
const providers = {};

// ── HTTP ─────────────────────────────────────────────────────────────────────
function cfg() {
  return vscode.workspace.getConfiguration("merlinStudio");
}

async function token() {
  return (await ctxRef.secrets.get(SECRET_KEY)) || "";
}

async function request(path, { method = "GET", body = null, raw = false, timeout = 30000 } = {}) {
  const base = (cfg().get("url") || "").replace(/\/+$/, "");
  if (!base) {
    const e = new Error("URL du studio non configurée — lance « MERLIN: Configurer la connexion »");
    e.notConfigured = true;
    throw e;
  }
  const u = new URL(base + path);
  const lib = u.protocol === "https:" ? https : http;
  const tok = await token();
  const headers = { Accept: raw ? "text/plain" : "application/json" };
  if (tok) {
    const user = cfg().get("user") || "merlin";
    headers.Authorization = "Basic " + Buffer.from(`${user}:${tok}`).toString("base64");
  }
  let payload = null;
  if (body) {
    payload = JSON.stringify(body);
    headers["Content-Type"] = "application/json";
    headers["Content-Length"] = Buffer.byteLength(payload);
  }
  return new Promise((resolve, reject) => {
    const req = lib.request(
      { hostname: u.hostname, port: u.port || (u.protocol === "https:" ? 443 : 80), path: u.pathname + u.search, method, headers, timeout },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          if (res.statusCode === 401) return reject(new Error("401 — token invalide ou manquant (MERLIN: Configurer la connexion)"));
          if (raw) return resolve(data);
          try {
            resolve(JSON.parse(data || "{}"));
          } catch {
            reject(new Error(`Réponse illisible (HTTP ${res.statusCode})`));
          }
        });
      }
    );
    req.on("timeout", () => req.destroy(new Error("timeout — la VM ou le tunnel ne répond pas")));
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function fail(e) {
  if (e && e.notConfigured) {
    vscode.window.showWarningMessage(e.message, "Configurer").then((c) => {
      if (c) vscode.commands.executeCommand("merlinStudio.configure");
    });
  } else {
    vscode.window.showErrorMessage("MERLIN Studio : " + (e && e.message ? e.message : String(e)));
  }
}

// ── Lancement d'action + suivi du log ────────────────────────────────────────
async function launch(kind, params = {}, label) {
  try {
    const rec = await request("/api/launch", { method: "POST", body: { kind, params } });
    if (rec.error) {
      vscode.window.showWarningMessage("MERLIN : " + rec.error);
      return null;
    }
    const name = label || rec.label || kind;
    out.appendLine(`\n▶ ${name}  (job ${rec.id})`);
    if (cfg().get("autoOpenLog")) out.show(true);
    followJob(rec.id, name);
    refreshAll();
    return rec;
  } catch (e) {
    fail(e);
    return null;
  }
}

/** Poll le job jusqu'à la fin et déverse l'incrément de log dans la sortie. */
async function followJob(id, name) {
  let seen = 0;
  const started = Date.now();
  const tick = async () => {
    try {
      const text = await request(`/api/job/${id}`, { raw: true });
      if (text && text.length > seen) {
        out.append(text.slice(seen));
        seen = text.length;
      }
      const { jobs = [] } = await request("/api/jobs");
      const j = jobs.find((x) => x.id === id);
      if (j && j.status !== "running") {
        const secs = Math.round((Date.now() - started) / 1000);
        const ok = j.status === "done";
        out.appendLine(`\n${ok ? "✅" : "❌"} ${name} — ${j.status}${j.exit_code != null ? ` (exit ${j.exit_code})` : ""} en ${secs}s`);
        (ok ? vscode.window.showInformationMessage : vscode.window.showWarningMessage)(
          `MERLIN : ${name} — ${j.status}`
        );
        refreshAll();
        return;
      }
      if (Date.now() - started < 30 * 60 * 1000) setTimeout(tick, 2000);
    } catch {
      /* réseau instable : on retente au prochain tick */
      if (Date.now() - started < 30 * 60 * 1000) setTimeout(tick, 5000);
    }
  };
  setTimeout(tick, 1200);
}

// ── Arbres ───────────────────────────────────────────────────────────────────
class Tree {
  constructor(loader) {
    this.loader = loader;
    this._e = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._e.event;
    this.items = [];
  }
  refresh() {
    this.loader()
      .then((items) => {
        this.items = items;
        this._e.fire();
      })
      .catch(() => {
        this.items = [node("⚠ studio injoignable", "Configure l'URL/token ou vérifie le tunnel")];
        this._e.fire();
      });
  }
  getTreeItem(x) {
    return x;
  }
  getChildren(x) {
    return x ? x.children || [] : this.items;
  }
}

function node(label, description, opts = {}) {
  const it = new vscode.TreeItem(
    label,
    opts.children ? vscode.TreeItemCollapsibleState.Expanded : vscode.TreeItemCollapsibleState.None
  );
  it.description = description;
  if (opts.icon) it.iconPath = new vscode.ThemeIcon(opts.icon, opts.color ? new vscode.ThemeColor(opts.color) : undefined);
  if (opts.command) it.command = opts.command;
  if (opts.tooltip) it.tooltip = opts.tooltip;
  if (opts.context) it.contextValue = opts.context;
  if (opts.children) it.children = opts.children;
  return it;
}

async function loadScenes() {
  const d = await request("/api/godot");
  const g = d.godot || {}, runs = d.runs || {};
  const head = [];
  head.push(
    node(`Godot ${g.version || "?"}`, g.warning || (g.available ? "prêt" : "indisponible"), {
      icon: g.available ? (g.warning ? "warning" : "check") : "error",
      color: g.available ? (g.warning ? "charts.yellow" : "charts.green") : "charts.red",
      tooltip: g.warning || "",
    })
  );
  for (const s of g.scenes || []) {
    const r = runs["smoke:" + s];
    const ok = r && r.status === "done" && !r.script_errors;
    head.push(
      node(s.replace(".tscn", ""), r ? `${r.status}${r.script_errors ? ` · ${r.script_errors} erreurs` : ""}` : "jamais testée", {
        icon: r ? (ok ? "pass" : "error") : "circle-outline",
        color: r ? (ok ? "charts.green" : "charts.red") : undefined,
        tooltip: r ? (r.tail || "").slice(-400) : "Clic = lancer un smoke",
        command: { command: "merlinStudio.smokeScene", title: "Smoke", arguments: [s] },
      })
    );
  }
  return head;
}

async function loadJobs() {
  const d = await request("/api/jobs");
  return (d.jobs || []).slice(0, 25).map((j) =>
    node(j.label || j.kind, `${j.status}${j.exit_code != null ? ` · exit ${j.exit_code}` : ""}`, {
      icon: j.status === "running" ? "sync~spin" : j.status === "done" ? "pass" : "error",
      color: j.status === "done" ? "charts.green" : j.status === "running" ? "charts.blue" : "charts.red",
      tooltip: (j.log_tail || "").slice(-500),
      context: "merlinJob",
      command: { command: "merlinStudio.showLog", title: "Log", arguments: [j.id] },
    })
  );
}

async function loadVm() {
  const [h, l, r] = await Promise.all([request("/api/host"), request("/api/llm"), request("/api/repo")]);
  const mem = h.mem || {};
  const o = l.ollama || {};
  const models = (o.models || []).map((m) => node(m.name, `${m.gb} Go ${m.param || ""}`, { icon: "database" }));
  const svc = Object.entries(h.services || {}).map(([k, v]) =>
    node(k, v, { icon: v === "active" ? "pass" : "circle-outline", color: v === "active" ? "charts.green" : undefined })
  );
  return [
    node(`${h.cpus || "?"} cœurs · ${mem.available_gb ?? "?"}/${mem.total_gb ?? "?"} Go`, h.uptime || "", { icon: "server" }),
    node(`Modèles (${models.length})`, o.available ? o.version : "Ollama injoignable", {
      icon: "beaker",
      color: o.available ? "charts.green" : "charts.red",
      children: models,
    }),
    node(`Dépôt : ${r.branch || "?"}`, `↑${r.ahead || 0} ↓${r.behind || 0} · ${r.dirty_count || 0} modifiés`, { icon: "git-branch" }),
    node("Services", "", { icon: "gear", children: svc }),
  ];
}

function refreshAll() {
  Object.values(providers).forEach((p) => p.refresh());
  updateStatus();
}

async function updateStatus() {
  try {
    const [o, j] = await Promise.all([request("/api/overview"), request("/api/jobs")]);
    const running = Object.values(j.running || {}).reduce((a, b) => a + b, 0);
    const m = o.mem || {};
    statusBar.text = `$(server) MERLIN ${o.cpus || "?"}c · ${m.available_gb ?? "?"}Go${running ? ` · $(sync~spin) ${running}` : ""}`;
    statusBar.tooltip = `Studio VM — branche ${o.branch || "?"} · ${o.models || 0} modèles\nClic : ouvrir le tableau de bord`;
    statusBar.backgroundColor = undefined;
  } catch (e) {
    statusBar.text = "$(server) MERLIN —";
    statusBar.tooltip = "Studio injoignable : " + (e.message || "");
    statusBar.backgroundColor = new vscode.ThemeColor("statusBarItem.warningBackground");
  }
  statusBar.show();
}

// ── Activation ───────────────────────────────────────────────────────────────
function activate(context) {
  ctxRef = context;
  out = vscode.window.createOutputChannel("MERLIN Studio");
  statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  statusBar.command = "merlinStudio.openDashboard";
  context.subscriptions.push(out, statusBar);

  providers.scenes = new Tree(loadScenes);
  providers.jobs = new Tree(loadJobs);
  providers.vm = new Tree(loadVm);
  context.subscriptions.push(
    vscode.window.registerTreeDataProvider("merlinStudio.scenes", providers.scenes),
    vscode.window.registerTreeDataProvider("merlinStudio.jobs", providers.jobs),
    vscode.window.registerTreeDataProvider("merlinStudio.vm", providers.vm)
  );

  const reg = (id, fn) => context.subscriptions.push(vscode.commands.registerCommand(id, fn));

  reg("merlinStudio.configure", async () => {
    const url = await vscode.window.showInputBox({
      prompt: "URL du studio sur la VM",
      value: cfg().get("url") || "",
      placeHolder: "https://xxxx.trycloudflare.com",
      ignoreFocusOut: true,
    });
    if (url === undefined) return;
    await cfg().update("url", url.trim().replace(/\/+$/, ""), vscode.ConfigurationTarget.Global);
    const tok = await vscode.window.showInputBox({
      prompt: "Token (celui affiché par deploy-studio.sh) — stocké dans le coffre de VS Code",
      password: true,
      ignoreFocusOut: true,
    });
    if (tok !== undefined) await context.secrets.store(SECRET_KEY, tok.trim());
    try {
      const h = await request("/healthz");
      vscode.window.showInformationMessage(h.ok ? "MERLIN Studio : connexion OK ✅" : "Réponse inattendue du studio");
    } catch (e) {
      fail(e);
    }
    refreshAll();
  });

  reg("merlinStudio.refresh", refreshAll);

  reg("merlinStudio.openDashboard", async () => {
    const base = cfg().get("url");
    if (!base) return vscode.commands.executeCommand("merlinStudio.configure");
    const panel = vscode.window.createWebviewPanel("merlinStudioDash", "MERLIN Studio", vscode.ViewColumn.One, {
      enableScripts: true,
    });
    // Le studio est protégé par Basic-auth : on ne peut pas l'iframer sans creds,
    // donc on propose l'ouverture externe + un résumé natif.
    panel.webview.html = `<!doctype html><meta charset="utf-8">
      <style>body{font-family:system-ui;padding:24px;line-height:1.6}code{background:#8883;padding:2px 6px;border-radius:4px}
      a{color:#58a6ff}button{padding:10px 16px;font:inherit;border:0;border-radius:8px;background:#58a6ff;color:#000;cursor:pointer}</style>
      <h2>🜨 MERLIN Studio — VM perso</h2>
      <p>Le tableau de bord complet est servi par la VM :</p>
      <p><code>${base}</code></p>
      <p><button onclick="vscode.postMessage({open:1})">Ouvrir dans le navigateur</button></p>
      <p style="opacity:.75">Le studio est protégé par Basic-auth (utilisateur <code>${cfg().get("user")}</code>) :
      le navigateur demandera le token une fois, puis le mémorisera.
      Les arbres et commandes de la barre latérale VS Code fonctionnent, eux, sans navigateur.</p>
      <script>const vscode=acquireVsCodeApi();</script>`;
    panel.webview.onDidReceiveMessage(() => vscode.env.openExternal(vscode.Uri.parse(base)));
  });

  reg("merlinStudio.smokeScene", async (scene) => {
    try {
      if (!scene) {
        const d = await request("/api/godot");
        const pick = await vscode.window.showQuickPick((d.godot?.scenes || []).map((s) => ({ label: s })), {
          placeHolder: "Quelle scène tester ?",
        });
        if (!pick) return;
        scene = pick.label;
      }
      launch("godot-smoke", { scene, duration: 8 }, `Smoke ${scene}`);
    } catch (e) {
      fail(e);
    }
  });

  reg("merlinStudio.smokeAll", () => launch("godot-smoke-all", { duration: 6 }, "Smoke toutes les scènes"));
  reg("merlinStudio.runTests", () => launch("godot-test", {}, "Suite de tests"));
  reg("merlinStudio.bootCheck", () => launch("godot-boot", {}, "Boot check"));
  reg("merlinStudio.validateContent", () => launch("content-validate", {}, "Validation du contenu"));
  reg("merlinStudio.gitPull", () => launch("git-pull", {}, "Git pull (ff-only)"));

  reg("merlinStudio.generateContent", async () => {
    const n = await vscode.window.showQuickPick(["6", "12", "24", "48"], { placeHolder: "Combien de cartes ?" });
    if (!n) return;
    const b = await vscode.window.showQuickPick(
      [
        { label: "template", description: "hors-ligne, toujours dispo" },
        { label: "ollama", description: "modèle local de la VM (Gemma 4)" },
      ],
      { placeHolder: "Backend de génération" }
    );
    if (!b) return;
    launch("content-gen", { count: parseInt(n, 10), backend: b.label }, `Génération ${n} cartes`);
  });

  reg("merlinStudio.askModel", async () => {
    try {
      const l = await request("/api/llm");
      const models = (l.ollama?.models || []).map((m) => ({ label: m.name, description: `${m.gb} Go` }));
      const m = models.length
        ? await vscode.window.showQuickPick(models, { placeHolder: "Quel modèle ?" })
        : { label: "gemma4:e4b-it-qat" };
      if (!m) return;
      const prompt = await vscode.window.showInputBox({
        prompt: `Prompt pour ${m.label}`,
        value: "Décris Brocéliande en une phrase, à la manière de Merlin.",
        ignoreFocusOut: true,
      });
      if (!prompt) return;
      launch("ollama-generate", { model: m.label, prompt }, `Génération ${m.label}`);
    } catch (e) {
      fail(e);
    }
  });

  reg("merlinStudio.pullModel", async () => {
    const model = await vscode.window.showInputBox({
      prompt: "Modèle Ollama à télécharger sur la VM",
      value: "gemma4:e4b-it-qat",
      ignoreFocusOut: true,
    });
    if (!model) return;
    launch("ollama-pull", { model }, `Téléchargement ${model}`);
  });

  reg("merlinStudio.startVoice", async () => {
    const which = await vscode.window.showQuickPick(
      [
        { label: "TTS", description: "voix du conteur" },
        { label: "ASR", description: "voix du joueur" },
        { label: "Les deux", description: "" },
      ],
      { placeHolder: "Quel service démarrer ?" }
    );
    if (!which) return;
    if (which.label !== "ASR") launch("tts-start", {}, "Service TTS");
    if (which.label !== "TTS") launch("asr-start", {}, "Service ASR");
  });

  reg("merlinStudio.showLog", async (id) => {
    try {
      if (!id) {
        const d = await request("/api/jobs");
        const pick = await vscode.window.showQuickPick(
          (d.jobs || []).map((j) => ({ label: j.label || j.kind, description: `${j.status} · ${j.id}`, id: j.id })),
          { placeHolder: "Quel job ?" }
        );
        if (!pick) return;
        id = pick.id;
      }
      const text = await request(`/api/job/${id}`, { raw: true });
      out.appendLine(`\n──── log ${id} ────`);
      out.append(text || "(vide)");
      out.show(true);
    } catch (e) {
      fail(e);
    }
  });

  reg("merlinStudio.stopJob", async () => {
    try {
      const d = await request("/api/jobs");
      const running = (d.jobs || []).filter((j) => j.status === "running");
      if (!running.length) return vscode.window.showInformationMessage("MERLIN : aucun job en cours.");
      const pick = await vscode.window.showQuickPick(
        running.map((j) => ({ label: j.label || j.kind, description: j.id, id: j.id })),
        { placeHolder: "Arrêter quel job ?" }
      );
      if (!pick) return;
      const r = await request(`/api/job/${pick.id}/stop`, { method: "POST" });
      vscode.window.showInformationMessage(r.ok ? "Job arrêté." : "MERLIN : " + (r.error || "échec"));
      refreshAll();
    } catch (e) {
      fail(e);
    }
  });

  reg("merlinStudio.runAny", async () => {
    try {
      const c = await request("/api/launchers");
      const pick = await vscode.window.showQuickPick(
        (c.launchers || []).map((l) => ({
          label: l.label,
          description: l.available ? l.group : `indisponible — ${l.reason || ""}`,
          kind: l.kind,
          params: l.params || [],
          available: l.available,
        })),
        { placeHolder: "Quelle action lancer sur la VM ?" }
      );
      if (!pick) return;
      if (!pick.available) return vscode.window.showWarningMessage("Action indisponible : " + (pick.description || ""));
      const params = {};
      for (const p of pick.params) {
        const v = p.options
          ? await vscode.window.showQuickPick(p.options.map(String), { placeHolder: p.name })
          : await vscode.window.showInputBox({ prompt: p.name, value: String(p.default ?? ""), ignoreFocusOut: true });
        if (v === undefined) return;
        if (v !== "") params[p.name] = v;
      }
      launch(pick.kind, params, pick.label);
    } catch (e) {
      fail(e);
    }
  });

  // premier chargement + rafraîchissement périodique
  refreshAll();
  const every = () => {
    if (timer) clearInterval(timer);
    const s = Number(cfg().get("refreshSeconds") || 0);
    if (s >= 5) timer = setInterval(refreshAll, s * 1000);
  };
  every();
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration("merlinStudio")) {
        every();
        refreshAll();
      }
    }),
    { dispose: () => timer && clearInterval(timer) }
  );
}

function deactivate() {
  if (timer) clearInterval(timer);
}

module.exports = { activate, deactivate };
