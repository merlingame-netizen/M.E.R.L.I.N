// dashboard.js — AUTODEV Monitor Webview
// Handles DOM updates, animations, log tail, agent roster rendering

(function () {
  // @ts-ignore
  const vscode = acquireVsCodeApi();

  let currentProject = 'merlin';
  let lastData = null;
  let logEntryCount = 0;
  const MAX_LOG_ENTRIES = 150;
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

    const merlin = data.merlin;
    const dataProject = data.data;
    const cours = data.cours;

    // Update header from active project
    if (merlin && merlin.control) {
      updateHeader(merlin.control);
    }

    // Render active tab
    if (currentProject === 'merlin' && merlin) {
      updateWorkers(merlin.domains);
      updateAgentRoster(merlin.agents, 'agents-list', 'agent-count');
      updateDirector(merlin.director, merlin.questions, merlin.control);
      updateLogs(merlin.logs);
    } else if (currentProject === 'data' && dataProject) {
      updateAgentRoster(dataProject.agents, 'data-agents-list', 'data-agent-count');
    } else if (currentProject === 'cours' && cours) {
      updateAgentRoster(cours.agents, 'cours-agents-list', 'cours-agent-count');
    }

    // Update clock
    const timeEl = document.getElementById('h-time');
    if (timeEl) {
      const now = new Date();
      timeEl.textContent = pad2(now.getHours()) + ':' + pad2(now.getMinutes()) + ':' + pad2(now.getSeconds());
    }
  }

  // ── Header ─────────────────────────────────────────────────

  function updateHeader(control) {
    setText('h-cycle', control.cycle || '-');
    setText('h-wave', (control.wave || '-').toUpperCase());
    const stateEl = document.getElementById('h-state');
    if (stateEl) {
      const state = (control.state || 'unknown').toUpperCase();
      stateEl.textContent = state;
      stateEl.style.color = stateColor(control.state);
    }
  }

  // ── Workers Panel ──────────────────────────────────────────

  function updateWorkers(domains) {
    const container = document.getElementById('workers-list');
    if (!container) return;

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
      const progressBar = renderProgressBar(tasksCompleted.length, totalTasks);

      const currentTask = d.current_task || '-';
      const blockers = Array.isArray(d.blockers) && d.blockers.length > 0
        ? '<div style="color:var(--red);font-size:9px">BLOCKER: ' + escapeHtml(d.blockers[0]) + '</div>'
        : '';

      const timeAgo = d.timestamp ? formatTimeAgo(d.timestamp) : '';

      html += '<div class="worker-card ' + cardClass + '">'
        + '<div class="worker-header">'
        + '<span class="worker-name">' + escapeHtml(d.domain || '?') + '</span>'
        + '<span class="worker-status ' + cardClass + '">' + statusLabel(status) + '</span>'
        + '</div>'
        + '<div class="progress-bar">' + progressBar + ' ' + progressPct + '%</div>'
        + '<div class="worker-detail">Task: ' + escapeHtml(currentTask) + '</div>'
        + (tasksCompleted.length > 0 ? '<div class="worker-detail">Done: ' + escapeHtml(tasksCompleted.join(', ')) + '</div>' : '')
        + blockers
        + (timeAgo ? '<div class="worker-time">' + timeAgo + '</div>' : '')
        + '</div>';
    }

    container.innerHTML = html;
    setText('worker-count', '(' + doneCount + '/' + domains.length + ')');
  }

  // ── Agent Roster ───────────────────────────────────────────

  function updateAgentRoster(agents, containerId, countId) {
    const container = document.getElementById(containerId);
    if (!container || !agents) return;

    // Group by category
    const groups = {};
    for (const agent of agents) {
      const cat = agent.category || 'Other';
      if (!groups[cat]) groups[cat] = [];
      groups[cat].push(agent);
    }

    let html = '';
    let activeCount = 0;

    for (const [category, catAgents] of Object.entries(groups)) {
      html += '<div class="agent-category">' + escapeHtml(category) + '</div>';
      for (const agent of catAgents) {
        const state = agent.state || 'idle';
        if (state === 'active' || state === 'review') activeCount++;

        html += '<div class="agent-row">'
          + '<div class="agent-dot ' + state + '"></div>'
          + '<span class="agent-name">' + escapeHtml(agent.name) + '</span>'
          + '<span class="agent-state ' + state + '">' + state.toUpperCase() + '</span>'
          + '</div>';
      }
    }

    container.innerHTML = html;
    const countEl = document.getElementById(countId);
    if (countEl) countEl.textContent = '(' + activeCount + '/' + agents.length + ' active)';
  }

  // ── Director Panel ─────────────────────────────────────────

  function updateDirector(director, questions, control) {
    const container = document.getElementById('director-content');
    if (!container) return;

    if (!director) {
      container.innerHTML = '<div style="color:var(--text-dim);padding:20px;text-align:center">No director decision yet</div>';
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

    // Decision
    html += '<div class="director-metric">'
      + '<span class="director-label">Decision</span>'
      + '<span class="director-value ' + decisionClass + '">' + decision + '</span>'
      + '</div>';

    // Quality bar
    html += '<div class="director-metric">'
      + '<span class="director-label">Quality</span>'
      + '<div class="bar-track"><div class="bar-fill ' + qualityBarClass + '" style="width:' + quality + '%"></div></div>'
      + '<span style="min-width:40px;text-align:right;font-size:11px">' + quality + '/100</span>'
      + '</div>';

    // Confidence bar
    html += '<div class="director-metric">'
      + '<span class="director-label">Confidence</span>'
      + '<div class="bar-track"><div class="bar-fill ' + confBarClass + '" style="width:' + confidence + '%"></div></div>'
      + '<span style="min-width:40px;text-align:right;font-size:11px">' + confidence + '/100</span>'
      + '</div>';

    // Cycle
    if (director.cycle) {
      html += '<div class="director-metric">'
        + '<span class="director-label">Cycle</span>'
        + '<span style="font-size:11px">' + director.cycle + '</span>'
        + '</div>';
    }

    // Rationale
    if (director.rationale) {
      let rationale = director.rationale;
      if (rationale.length > 300) rationale = rationale.substring(0, 297) + '...';
      html += '<div class="director-rationale">' + escapeHtml(rationale) + '</div>';
    }

    // Escalation section
    if (questions && questions.questions && control && control.state === 'waiting_human') {
      html += '<div class="escalation-box">';
      html += '<div class="escalation-title">ESCALATION -- AWAITING HUMAN RESPONSE</div>';

      if (questions.escalation_reason) {
        html += '<div style="font-size:10px;color:var(--amber);margin-bottom:6px">'
          + escapeHtml(questions.escalation_reason) + '</div>';
      }

      for (const q of questions.questions) {
        html += '<div class="escalation-question">'
          + '<strong>' + escapeHtml(q.id || '') + '</strong>: '
          + escapeHtml(q.question || '') + '</div>';
      }

      // Quick response buttons
      html += '<div style="margin-top:8px;display:flex;gap:6px">'
        + '<button onclick="respondEscalation(\'proceed\')" style="background:var(--green-dim);color:#000;border:none;padding:4px 12px;cursor:pointer;font-family:var(--font-mono);font-size:10px">PROCEED</button>'
        + '<button onclick="respondEscalation(\'rollback\')" style="background:var(--red);color:#000;border:none;padding:4px 12px;cursor:pointer;font-family:var(--font-mono);font-size:10px">ROLLBACK</button>'
        + '</div>';

      html += '</div>';
    }

    container.innerHTML = html;
  }

  // ── Logs Panel ─────────────────────────────────────────────

  function updateLogs(logs) {
    const container = document.getElementById('log-entries');
    if (!container || !logs) return;

    let newEntries = [];

    for (const [domain, lines] of Object.entries(logs)) {
      for (const line of lines) {
        const key = domain + ':' + line;
        if (!seenLogLines.has(key)) {
          seenLogLines.add(key);
          newEntries.push({ domain, line });
        }
      }
    }

    // Sort by apparent time if available, otherwise keep order
    for (const entry of newEntries) {
      const logClass = classifyLogLine(entry.line);
      const el = document.createElement('div');
      el.className = 'log-entry ' + logClass;

      const time = extractTime(entry.line);
      el.innerHTML = '<span class="log-time">' + (time || nowTime()) + '</span>'
        + '<span class="log-domain">' + escapeHtml(entry.domain) + ':</span> '
        + escapeHtml(entry.line);

      container.appendChild(el);
      logEntryCount++;
    }

    // Trim old entries
    while (container.children.length > MAX_LOG_ENTRIES) {
      container.removeChild(container.firstChild);
    }

    // Auto-scroll
    if (newEntries.length > 0) {
      container.scrollTop = container.scrollHeight;
    }

    setText('log-count', '(' + container.children.length + ')');
  }

  // ── Utility Functions ──────────────────────────────────────

  function renderProgressBar(done, total) {
    if (total === 0) return '[----------]';
    const filled = Math.round((done / total) * 10);
    const empty = 10 - filled;
    return '[' + '\u25A0'.repeat(filled) + '\u25A1'.repeat(empty) + ']';
  }

  function statusLabel(status) {
    const map = {
      'in_progress': 'ACTIVE',
      'done': 'DONE',
      'error': 'ERROR',
      'merged': 'MERGED',
      'unknown': '---',
    };
    return map[status] || status.toUpperCase();
  }

  function stateColor(state) {
    const s = (state || '').toLowerCase();
    if (s === 'running') return 'var(--green)';
    if (s === 'waiting_human') return 'var(--amber)';
    if (s === 'stopped' || s === 'error') return 'var(--red)';
    return 'var(--text-dim)';
  }

  function classifyLogLine(line) {
    const lower = line.toLowerCase();
    if (lower.includes('error') || lower.includes('fatal') || lower.includes('fail')) return 'error';
    if (lower.includes('warn') || lower.includes('attention')) return 'warn';
    if (lower.includes('director') || lower.includes('escalat')) return 'director';
    return 'info';
  }

  function extractTime(line) {
    const match = line.match(/\[(\d{2}:\d{2}(?::\d{2})?)\]/);
    return match ? match[1] : null;
  }

  function nowTime() {
    const d = new Date();
    return pad2(d.getHours()) + ':' + pad2(d.getMinutes());
  }

  function pad2(n) {
    return n < 10 ? '0' + n : '' + n;
  }

  function formatTimeAgo(timestamp) {
    try {
      const then = new Date(timestamp);
      const now = new Date();
      const diffSec = Math.round((now.getTime() - then.getTime()) / 1000);
      if (diffSec < 10) return 'just now';
      if (diffSec < 60) return diffSec + 's ago';
      const diffMin = Math.round(diffSec / 60);
      if (diffMin < 60) return diffMin + 'min ago';
      const diffHr = Math.round(diffMin / 60);
      return diffHr + 'h ago';
    } catch {
      return '';
    }
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = String(text);
  }

  // ── Global Functions (called from inline onclick) ──────────

  window.respondEscalation = function (decision) {
    vscode.postMessage({ command: 'respondEscalation', decision: decision, details: '' });
  };

  window.requestRefresh = function () {
    vscode.postMessage({ command: 'refresh' });
  };
})();
