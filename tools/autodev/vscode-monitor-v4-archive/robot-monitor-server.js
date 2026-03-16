#!/usr/bin/env node
// robot-monitor-server.js — Tiny Node.js server for standalone Robot Monitor (v2: themes + taskPanel)
// Usage: node robot-monitor-server.js [--port 3847] [--status-dir ./tools/autodev/status] [--project merlin|data|cours]
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

// Parse CLI args
const args = process.argv.slice(2);
let port = 3847;
let statusDir = path.join(process.cwd(), 'tools', 'autodev', 'status');
let project = 'merlin';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port' && args[i + 1]) { port = parseInt(args[i + 1], 10); i++; }
  if (args[i] === '--status-dir' && args[i + 1]) { statusDir = args[i + 1]; i++; }
  if (args[i] === '--project' && args[i + 1]) { project = args[i + 1]; i++; }
}

// Auto-detect project from CWD if not explicitly set
if (!args.includes('--project')) {
  const cwd = process.cwd();
  if (fs.existsSync(path.join(cwd, 'project.godot'))) {
    project = 'merlin';
  } else if (/partage.voc|data|orange/i.test(cwd)) {
    project = 'data';
  } else if (/cours|teaching|ecole/i.test(cwd)) {
    project = 'cours';
  }
}

function readJson(filePath) {
  try {
    if (!fs.existsSync(filePath)) return {};
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch { return {}; }
}

function buildNormalized() {
  const controlState = readJson(path.join(statusDir, 'control_state.json'));
  const session = readJson(path.join(statusDir, 'session.json'));
  const healthReport = readJson(path.join(statusDir, 'health_report.json'));

  const state = controlState.state || session.state || 'idle';
  const objective = controlState.objective || session.objective || '';
  const checkpoint = session.checkpoint || '';

  const workers = [];
  const seen = new Set();

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

  const domainFiles = ['gameplay', 'ui-ux', 'llm-lora', 'world-structure', 'visual-polish', 'game-director',
    'ui-components', 'scene-scripts', 'autoloads-visual'];
  for (const d of domainFiles) {
    if (seen.has(d)) continue;
    const fp = path.join(statusDir, `${d}.json`);
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
      tool: 'claude',
    });
  }

  // Swarm integration: read .swarm/tasks.json for mixed Claude+Codex workers
  const swarmTasksPath = path.join(statusDir, '..', '..', '.swarm', 'tasks.json');
  if (fs.existsSync(swarmTasksPath)) {
    const swarmTasks = readJson(swarmTasksPath);
    if (swarmTasks.tasks && Array.isArray(swarmTasks.tasks)) {
      for (const t of swarmTasks.tasks) {
        const swarmDomain = `swarm:${t.id}`;
        if (seen.has(swarmDomain)) continue;
        seen.add(swarmDomain);
        workers.push({
          domain: swarmDomain,
          status: t.status || 'pending',
          current_task: t.title || '',
          progress: t.status === 'done' ? 100 : t.status === 'running' ? 50 : 0,
          files_modified: t.file_scope || [],
          error: '',
          blockers: [],
          tool: t.assigned_to || 'auto',
        });
      }
    }
  }

  // A2A lifecycle mapping: normalize status strings
  const A2A_STATUS_MAP = {
    'starting': 'accepted',
    'in_progress': 'working',
    'done': 'completed',
    'error': 'failed',
    'retrying': 'working',
    'dry_run': 'accepted',
    'pending': 'submitted',
  };

  for (const w of workers) {
    w.a2a_status = w.a2a_status || A2A_STATUS_MAP[w.status] || w.status;
    if (typeof w.progress_pct === 'undefined') {
      w.progress_pct = w.a2a_status === 'completed' ? 100 : w.a2a_status === 'working' ? 50 : 0;
    }
  }

  return { state, objective, checkpoint, workers };
}

// SSE clients
const sseClients = new Set();

// Watch for changes
let debounceTimer = null;
function onStatusChange() {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    const data = buildNormalized();
    const payload = `data: ${JSON.stringify(data)}\n\n`;
    for (const res of sseClients) {
      try { res.write(payload); } catch { sseClients.delete(res); }
    }
  }, 500);
}

if (fs.existsSync(statusDir)) {
  try { fs.watch(statusDir, { persistent: false }, onStatusChange); } catch {}
}
setInterval(onStatusChange, 2000);

// ── ROSTER: scan all agents + skills across projects ──
const HOME = process.env.USERPROFILE || process.env.HOME || '';

function scanAgents(dir, projectId) {
  const agents = [];
  if (!fs.existsSync(dir)) return agents;
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.md') && f !== 'AGENTS.md' && !f.startsWith('_'));
  for (const f of files) {
    const name = f.replace('.md', '');
    let category = 'general';
    try {
      const content = fs.readFileSync(path.join(dir, f), 'utf8');
      const headerMatch = content.match(/^#\s+(.+)/m);
      const catMatch = content.match(/categor(?:y|ie)\s*[:=]\s*(.+)/i)
        || content.match(/##\s+(\d+\.\s+)?Role/i);
      if (headerMatch) {
        const h = headerMatch[1].toLowerCase();
        if (/ui|ux|interface/.test(h)) category = 'ui-ux';
        else if (/llm|lora|brain|prompt/.test(h)) category = 'llm';
        else if (/debug|qa|test|quality/.test(h)) category = 'quality';
        else if (/game|design|balance|progress/.test(h)) category = 'design';
        else if (/narrat|lore|merlin|histor|writer/.test(h)) category = 'narrative';
        else if (/audio|shader|visual|art|motion|sprite/.test(h)) category = 'creative';
        else if (/git|ci|release|curator|producer|doc/.test(h)) category = 'ops';
        else if (/security|access|hardening/.test(h)) category = 'security';
        else if (/dispatch|orchestrat|studio|director/.test(h)) category = 'orchestration';
        else if (/sql|bigquery|hive|data|etl|powerbi|qlik|dataiku|notebook/.test(h)) category = 'data';
        else if (/cours|pedagog|slide|quiz|exercise|evaluat|school/.test(h)) category = 'education';
        else if (/outlook|mail|cockpit|msurvey/.test(h)) category = 'tools';
        else if (/godot|gdscript|optim|perf/.test(h)) category = 'core';
      }
    } catch {}
    agents.push({ name, category, project: projectId });
  }
  return agents;
}

function scanSkills(dir) {
  const skills = [];
  if (!fs.existsSync(dir)) return skills;
  const dirs = fs.readdirSync(dir).filter(d => {
    return d !== '_archived' && fs.statSync(path.join(dir, d)).isDirectory();
  });
  for (const d of dirs) {
    skills.push({ name: d, score: 5 });
  }
  return skills;
}

// Known project agent paths
const PROJECT_AGENT_PATHS = {
  merlin: path.join(process.cwd(), '.claude', 'agents'),
  data: path.join(HOME, 'OneDrive - orange.com', 'Bureau', 'Agents', 'Data', '.claude', 'agents'),
  cours: path.join(HOME, 'OneDrive - orange.com', 'Bureau', 'Agents', 'Cours', '.claude', 'agents'),
};
const COMMON_AGENTS_PATH = path.join(HOME, '.claude', 'agents', 'common');
const SKILLS_PATH = path.join(HOME, '.claude', 'skills');

let cachedRoster = null;
const METRICS_FILE = path.join(HOME, '.claude', 'metrics', 'agent_invocations.jsonl');

function buildMetrics() {
  if (!fs.existsSync(METRICS_FILE)) return { entries: [], topAgents: [], topSkills: [], byProject: {}, byDay: [] };
  const lines = fs.readFileSync(METRICS_FILE, 'utf8').trim().split('\n').filter(Boolean);
  const entries = [];
  for (const line of lines) {
    try { entries.push(JSON.parse(line)); } catch {}
  }

  // Top agents (by invocation count)
  const agentCounts = {};
  const skillCounts = {};
  const projectCounts = {};
  const dayCounts = {};

  for (const e of entries) {
    const proj = e.project || 'unknown';
    projectCounts[proj] = (projectCounts[proj] || 0) + 1;

    const day = (e.ts || '').substring(0, 10);
    if (day) dayCounts[day] = (dayCounts[day] || 0) + 1;

    // New format (R4+): has type field
    if (e.type === 'agent' || e.type === 'agent_read') {
      const name = e.agent || 'unknown';
      agentCounts[name] = (agentCounts[name] || 0) + 1;
    } else if (e.type === 'skill') {
      const name = e.skill || 'unknown';
      skillCounts[name] = (skillCounts[name] || 0) + 1;
    } else if (!e.type && e.agent) {
      // Legacy format (pre-R4): no type field, but has agent
      agentCounts[e.agent] = (agentCounts[e.agent] || 0) + 1;
    }
  }

  const topAgents = Object.entries(agentCounts).sort((a, b) => b[1] - a[1]).slice(0, 15)
    .map(([name, count]) => ({ name, count }));
  const topSkills = Object.entries(skillCounts).sort((a, b) => b[1] - a[1]).slice(0, 10)
    .map(([name, count]) => ({ name, count }));
  const byDay = Object.entries(dayCounts).sort((a, b) => a[0].localeCompare(b[0])).slice(-14)
    .map(([day, count]) => ({ day, count }));

  return { total: entries.length, topAgents, topSkills, byProject: projectCounts, byDay };
}

function buildRoster() {
  if (cachedRoster) return cachedRoster;

  const projects = {};
  for (const [pid, agentDir] of Object.entries(PROJECT_AGENT_PATHS)) {
    projects[pid] = scanAgents(agentDir, pid);
  }
  const commonAgents = scanAgents(COMMON_AGENTS_PATH, 'common');
  const skills = scanSkills(SKILLS_PATH);

  // Try to read skill scores from skill-activation-matrix
  const matrixPath = path.join(HOME, '.claude', 'rules', 'common', 'skill-activation-matrix.md');
  if (fs.existsSync(matrixPath)) {
    try {
      const matrix = fs.readFileSync(matrixPath, 'utf8');
      for (const s of skills) {
        // Match score patterns like "| **8-9** |" or "Score | 10 |"
        const scoreMatch = matrix.match(new RegExp(s.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '.*?\\|\\s*(\\d+)', 'i'));
        if (scoreMatch) s.score = parseInt(scoreMatch[1], 10);
        // Match project patterns
        const projMatch = matrix.match(new RegExp(s.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '.*?\\|\\s*(ALL|MERLIN|Data|Cours[^|]*)', 'i'));
        if (projMatch) s.projects = projMatch[1].trim();
      }
    } catch {}
  }

  // Sort skills by score descending
  skills.sort((a, b) => (b.score || 0) - (a.score || 0));

  cachedRoster = {
    projects,
    commonAgents,
    skills,
    totals: {
      merlin: (projects.merlin || []).length,
      data: (projects.data || []).length,
      cours: (projects.cours || []).length,
      common: commonAgents.length,
      skills: skills.length,
    }
  };
  return cachedRoster;
}

// Read JS files
const coreJs = fs.readFileSync(path.join(__dirname, 'robot-monitor-core.js'), 'utf8');

// Theme palette for body background
const THEME_BG = { merlin: '#050a05', data: '#0a0500', cours: '#050508' };
const bodyBg = THEME_BG[project] || '#050a05';

const HTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Robot Monitor</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: ${bodyBg}; overflow: hidden; font-family: 'Cascadia Code', 'Fira Code', Consolas, monospace; }
#robotContainer { width: 100vw; height: 100vh; display: flex; }
#robotCanvas { display: block; flex: 0 0 70%; image-rendering: pixelated; image-rendering: crisp-edges; }
#taskPanel { flex: 0 0 30%; overflow-y: auto; padding: 0; }
#modeTabs { display: flex; gap: 0; border-bottom: 1px solid #1a2a1a; }
#modeTabs button { flex: 1; padding: 4px 8px; border: none; cursor: pointer; font-family: inherit; font-size: 9px; font-weight: 700; letter-spacing: 1px; background: transparent; color: #6d7b6d; }
#modeTabs button.active { color: #00ff41; border-bottom: 2px solid #00ff41; }
@media (max-width: 500px) {
  #robotContainer { flex-direction: column; }
  #robotCanvas { flex: 0 0 65%; width: 100%; }
  #taskPanel { flex: 0 0 35%; width: 100%; }
}
</style>
</head>
<body>
<div id="robotContainer">
  <canvas id="robotCanvas"></canvas>
  <div style="flex: 0 0 30%; display: flex; flex-direction: column; overflow: hidden;">
    <div id="modeTabs">
      <button id="tabLive" class="active">LIVE</button>
      <button id="tabRoster">ROSTER</button>
      <button id="tabMetrics">METRICS</button>
      <button id="tabA2A">A2A</button>
    </div>
    <div id="taskPanel" style="flex: 1; overflow-y: auto;"></div>
  </div>
</div>
<script>window.__ROBOT_PROJECT = '${project}';</script>
<script>${coreJs}</script>
<script>
(function() {
  'use strict';
  var projectId = window.__ROBOT_PROJECT || 'merlin';
  if (window.RobotMonitor.setTheme) {
    window.RobotMonitor.setTheme(projectId);
  }

  var canvas = document.getElementById('robotCanvas');
  var taskPanelEl = document.getElementById('taskPanel');
  var scene = new window.RobotMonitor.Scene(canvas, taskPanelEl);

  function resize() {
    var container = document.getElementById('robotContainer');
    var canvasEl = document.getElementById('robotCanvas');
    scene.resize(canvasEl.clientWidth || container.clientWidth * 0.7, container.clientHeight || window.innerHeight);
  }
  window.addEventListener('resize', resize);
  resize();
  scene.start();

  // Initial fetch
  fetch('/api/status')
    .then(function(r) { return r.json(); })
    .then(function(data) { scene.setData(data); })
    .catch(function() {});

  // SSE for live updates
  var evtSource = new EventSource('/events');
  evtSource.onmessage = function(e) {
    try {
      var data = JSON.parse(e.data);
      scene.setData(data);
    } catch(err) {}
  };
  evtSource.onerror = function() {};

  // Fetch roster for Roster tab
  fetch('/api/roster')
    .then(function(r) { return r.json(); })
    .then(function(roster) {
      if (scene.setRoster) scene.setRoster(roster);
    })
    .catch(function() {});

  // Fetch metrics
  fetch('/api/metrics')
    .then(function(r) { return r.json(); })
    .then(function(metrics) {
      if (scene.setMetrics) scene.setMetrics(metrics);
    })
    .catch(function() {});

  // Fetch A2A agent cards
  fetch('/api/agent-cards')
    .then(function(r) { return r.json(); })
    .then(function(cards) {
      if (scene.setAgentCards) scene.setAgentCards(cards);
    })
    .catch(function() {});

  // Fetch A2A messages
  fetch('/api/messages')
    .then(function(r) { return r.json(); })
    .then(function(messages) {
      if (scene.setMessages) scene.setMessages(messages);
    })
    .catch(function() {});

  // Tab switching
  var tabLive = document.getElementById('tabLive');
  var tabRoster = document.getElementById('tabRoster');
  var tabMetrics = document.getElementById('tabMetrics');
  var tabA2A = document.getElementById('tabA2A');
  var allTabs = [tabLive, tabRoster, tabMetrics, tabA2A];
  function activateTab(active, mode) {
    allTabs.forEach(function(t) { t.className = ''; });
    active.className = 'active';
    scene.setMode(mode);
  }
  tabLive.addEventListener('click', function() { activateTab(tabLive, 'live'); });
  tabRoster.addEventListener('click', function() { activateTab(tabRoster, 'roster'); });
  tabMetrics.addEventListener('click', function() { activateTab(tabMetrics, 'metrics'); });
  tabA2A.addEventListener('click', function() { activateTab(tabA2A, 'a2a'); });
})();
</script>
</body>
</html>`;

// HTTP Server
const server = http.createServer(function (req, res) {
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(HTML);
    return;
  }

  if (req.url === '/api/status') {
    const data = buildNormalized();
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(data));
    return;
  }

  if (req.url === '/api/roster') {
    const roster = buildRoster();
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(roster));
    return;
  }

  if (req.url === '/api/metrics') {
    const metrics = buildMetrics();
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(metrics));
    return;
  }

  // A2A: Agent capability cards registry
  if (req.url === '/api/agent-cards') {
    const registryPath = path.join(statusDir, '..', 'agent_cards', '_registry.json');
    const registry = readJson(registryPath);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(registry));
    return;
  }

  // A2A: Message queue inspection
  if (req.url === '/api/messages') {
    const messagesDir = path.join(statusDir, 'messages');
    const messages = {};
    if (fs.existsSync(messagesDir)) {
      const files = fs.readdirSync(messagesDir).filter(f => f.startsWith('inbox_') && f.endsWith('.jsonl'));
      for (const f of files) {
        const agent = f.replace('inbox_', '').replace('.jsonl', '');
        const lines = fs.readFileSync(path.join(messagesDir, f), 'utf8').trim().split('\n').filter(Boolean);
        messages[agent] = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
      }
    }
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(messages));
    return;
  }

  if (req.url === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('\n');
    sseClients.add(res);
    req.on('close', function () { sseClients.delete(res); });

    // Send initial data
    const data = buildNormalized();
    res.write('data: ' + JSON.stringify(data) + '\n\n');
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

server.listen(port, function () {
  console.log('[Robot Monitor] http://localhost:' + port);
  console.log('[Robot Monitor] Status dir: ' + statusDir);
  console.log('[Robot Monitor] Project: ' + project);
});
