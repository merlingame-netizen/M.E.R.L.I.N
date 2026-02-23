// sidebar.js — AUTODEV Monitor Sidebar Webview
// Compact vertical layout for Activity Bar sidebar (~300px wide)

(function () {
  // @ts-ignore
  const vscode = acquireVsCodeApi();

  let currentProject = 'merlin';
  let lastData = null;
  let logEntryCount = 0;
  const MAX_LOG_ENTRIES = 30;
  const MAX_SEEN_LOG_KEYS = 2000;
  const seenLogLines = new Set();

  // ── Tab Switching ──────────────────────────────────────────

  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      const project = tab.getAttribute('data-project');
      document.querySelectorAll('.project-view').forEach(v => {
        v.style.display = 'none';
      });
      const view = document.getElementById('project-' + project);
      if (view) view.style.display = '';
      currentProject = project;

      if (lastData) renderAll(lastData);
    });
  });

  // ── Message Handler ────────────────────────────────────────

  window.addEventListener('message', event => {
    const msg = event.data;
    if (msg.type === 'update') {
      lastData = msg.data;
      renderAll(msg.data);
    }
  });

  // ── Main Render ────────────────────────────────────────────

  function renderAll(data) {
    if (!data) return;

    if (data.merlin && data.merlin.control) {
      updateHeader(data.merlin.control);
    }

    if (currentProject === 'merlin' && data.merlin) {
      updatePipeline(data.merlin.control);
      updateWorkers(data.merlin.domains);
      updateAgentRoster(data.merlin.agents, 'agents-list', 'agent-count');
      updateDirector(data.merlin.director, data.merlin.questions, data.merlin.control);
      updateLogs(data.merlin.logs);
    } else if (currentProject === 'data' && data.data) {
      updateAgentRoster(data.data.agents, 'data-agents-list', 'data-agent-count');
    } else if (currentProject === 'cours' && data.cours) {
      updateAgentRoster(data.cours.agents, 'cours-agents-list', 'cours-agent-count');
    }

    const timeEl = document.getElementById('h-time');
    if (timeEl) {
      const now = new Date();
      timeEl.textContent = pad2(now.getHours()) + ':' + pad2(now.getMinutes());
    }
  }

  // ── Header ─────────────────────────────────────────────────

  function updateHeader(control) {
    const stateEl = document.getElementById('h-state');
    if (stateEl) {
      const state = (control.state || 'idle').toLowerCase();
      stateEl.textContent = state.toUpperCase();
      stateEl.className = 'state-badge ' + state;
    }
  }

  // ── Pipeline ───────────────────────────────────────────────

  function updatePipeline(control) {
    if (!control) return;
    const wave = (control.wave || '-').toUpperCase();
    setText('p-cycle', 'Cycle ' + (control.cycle || '-'));
    setText('p-wave', 'Wave ' + wave);
    setText('pipeline-info', 'C' + (control.cycle || '-') + ' W' + wave.substring(0, 3));
  }

  // ── Workers ────────────────────────────────────────────────

  function updateWorkers(domains) {
    const container = document.getElementById('workers-list');
    if (!container || !Array.isArray(domains)) return;

    let doneCount = 0;
    let html = '';

    for (const d of domains) {
      const status = (d.status || 'unknown').toLowerCase();
      const cardClass = status === 'in_progress' ? 'active' :
                        status === 'error' ? 'error' :
                        (status === 'done' || status === 'merged') ? 'done' : '';

      if (status === 'done' || status === 'merged') doneCount++;

      const tasksCompleted = Array.isArray(d.tasks_completed) ? d.tasks_completed : [];
      const tasksRemaining = Array.isArray(d.tasks_remaining) ? d.tasks_remaining : [];
      const totalTasks = tasksCompleted.length + tasksRemaining.length;
      const progressPct = totalTasks > 0 ? Math.round((tasksCompleted.length / totalTasks) * 100) : 0;

      const currentTask = d.current_task || '-';
      const blockerHtml = Array.isArray(d.blockers) && d.blockers.length > 0 && d.blockers[0]
        ? '<div class="worker-blocker">BLOCK: ' + escapeHtml(truncate(d.blockers[0], 40)) + '</div>'
        : '';

      html += '<div class="worker-card ' + cardClass + '">'
        + '<div class="worker-header">'
        + '<span class="worker-name">' + escapeHtml(d.domain || '?') + '</span>'
        + '<span class="worker-status ' + cardClass + '">' + statusLabel(status) + '</span>'
        + '</div>'
        + '<div class="progress-bar">' + miniBar(tasksCompleted.length, totalTasks) + ' ' + progressPct + '%</div>'
        + '<div class="worker-detail">' + escapeHtml(truncate(currentTask, 50)) + '</div>'
        + blockerHtml
        + '</div>';
    }

    container.innerHTML = html;
    setText('worker-count', '(' + doneCount + '/' + domains.length + ')');
  }

  // ── Agents ─────────────────────────────────────────────────

  function updateAgentRoster(agents, containerId, countId) {
    const container = document.getElementById(containerId);
    if (!container || !agents) return;

    const groups = {};
    let activeCount = 0;

    for (const agent of agents) {
      const cat = agent.category || 'Other';
      if (!groups[cat]) groups[cat] = [];
      groups[cat].push(agent);
      if (agent.state === 'active' || agent.state === 'review') activeCount++;
    }

    let html = '';
    for (const [category, catAgents] of Object.entries(groups)) {
      html += '<div class="agent-category">' + escapeHtml(category) + '</div>';
      for (const agent of catAgents) {
        const state = agent.state || 'idle';
        html += '<div class="agent-row">'
          + '<div class="agent-dot ' + state + '"></div>'
          + '<span class="agent-name">' + escapeHtml(agent.name) + '</span>'
          + '<span class="agent-state ' + state + '">' + state.toUpperCase() + '</span>'
          + '</div>';
      }
    }

    container.innerHTML = html;
    const countEl = document.getElementById(countId);
    if (countEl) countEl.textContent = '(' + activeCount + '/' + agents.length + ')';
  }

  // ── Director ───────────────────────────────────────────────

  function updateDirector(director, questions, control) {
    const container = document.getElementById('director-content');
    if (!container) return;

    if (!director) {
      container.innerHTML = '<div style="color:var(--text-dim);padding:10px;text-align:center;font-size:10px">No decision yet</div>';
      return;
    }

    const decision = (director.decision || '?').toUpperCase();
    const decisionClass = decision === 'PROCEED' ? 'proceed' :
                          decision === 'ESCALATE' ? 'escalate' :
                          decision === 'ROLLBACK' ? 'rollback' : '';

    const quality = director.quality_score || director.quality || 0;
    const confidence = director.confidence_score || director.confidence || 0;
    const qualityBarClass = quality >= 70 ? 'quality' : quality >= 40 ? 'medium' : 'low';
    const confBarClass = confidence >= 70 ? 'confidence' : confidence >= 40 ? 'medium' : 'low';

    let html = '';

    html += '<div class="director-metric">'
      + '<span class="director-label">Decision</span>'
      + '<span class="director-value ' + decisionClass + '">' + decision + '</span>'
      + '</div>';

    html += '<div class="director-metric">'
      + '<span class="director-label">Quality</span>'
      + '<div class="bar-track"><div class="bar-fill ' + qualityBarClass + '" style="width:' + quality + '%"></div></div>'
      + '<span style="font-size:10px">' + quality + '</span>'
      + '</div>';

    html += '<div class="director-metric">'
      + '<span class="director-label">Confidence</span>'
      + '<div class="bar-track"><div class="bar-fill ' + confBarClass + '" style="width:' + confidence + '%"></div></div>'
      + '<span style="font-size:10px">' + confidence + '</span>'
      + '</div>';

    if (director.rationale) {
      html += '<div class="director-rationale">' + escapeHtml(truncate(director.rationale, 150)) + '</div>';
    }

    if (questions && questions.questions && control && control.state === 'waiting_human') {
      html += '<div class="escalation-box">';
      html += '<div class="escalation-title">ESCALATION</div>';
      for (const q of questions.questions) {
        html += '<div class="escalation-question">'
          + '<strong>' + escapeHtml(q.id || '') + '</strong> '
          + escapeHtml(truncate(q.question || '', 60)) + '</div>';
      }
      html += '<div class="escalation-actions">'
        + '<button class="btn-proceed" onclick="respond(\'proceed\')">PROCEED</button>'
        + '<button class="btn-rollback" onclick="respond(\'rollback\')">ROLLBACK</button>'
        + '</div></div>';
    }

    container.innerHTML = html;
  }

  // ── Logs ───────────────────────────────────────────────────

  function updateLogs(logs) {
    const container = document.getElementById('log-entries');
    if (!container || !logs || typeof logs !== 'object') return;

    let newEntries = [];
    for (const [domain, lines] of Object.entries(logs)) {
      if (!Array.isArray(lines)) continue;
      for (const line of lines) {
        const key = domain + ':' + line;
        if (!seenLogLines.has(key)) {
          // Cap set size to prevent memory leak over long sessions
          if (seenLogLines.size >= MAX_SEEN_LOG_KEYS) {
            seenLogLines.delete(seenLogLines.values().next().value);
          }
          seenLogLines.add(key);
          newEntries.push({ domain, line });
        }
      }
    }

    for (const entry of newEntries) {
      const logClass = classifyLog(entry.line);
      const el = document.createElement('div');
      el.className = 'log-entry ' + logClass;
      el.innerHTML = '<span class="log-domain">' + escapeHtml(entry.domain) + '</span>'
        + escapeHtml(truncate(entry.line, 60));
      container.appendChild(el);
      logEntryCount++;
    }

    while (container.children.length > MAX_LOG_ENTRIES) {
      container.removeChild(container.firstChild);
    }

    if (newEntries.length > 0) {
      container.scrollTop = container.scrollHeight;
    }

    setText('log-count', '(' + container.children.length + ')');
  }

  // ── Utilities ──────────────────────────────────────────────

  function miniBar(done, total) {
    if (total === 0) return '[-----]';
    const filled = Math.round((done / total) * 5);
    return '[' + '\u25A0'.repeat(filled) + '\u25A1'.repeat(5 - filled) + ']';
  }

  function statusLabel(status) {
    const map = { 'in_progress': 'RUN', 'done': 'OK', 'error': 'ERR', 'merged': 'MRG', 'unknown': '---' };
    return map[status] || status.toUpperCase().substring(0, 3);
  }

  function classifyLog(line) {
    const lower = line.toLowerCase();
    if (lower.includes('error') || lower.includes('fatal')) return 'error';
    if (lower.includes('warn')) return 'warn';
    if (lower.includes('director') || lower.includes('escalat')) return 'director';
    return 'info';
  }

  function truncate(str, max) {
    if (!str || str.length <= max) return str || '';
    return str.substring(0, max - 3) + '...';
  }

  function pad2(n) { return n < 10 ? '0' + n : '' + n; }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = String(text);
  }

  // ── Global ─────────────────────────────────────────────────

  window.respond = function (decision) {
    vscode.postMessage({ command: 'respondEscalation', decision: decision, details: '' });
  };

  window.openFullDashboard = function () {
    vscode.postMessage({ command: 'openPanel' });
  };
})();
