// sidebar.js — AUTODEV Monitor v4.0 Sidebar Logic
// Interactive controls, action buttons, log filters, progress bars

let sData = null;
let sActiveProject = 'merlin';
let sCollapsed = {};       // sectionId -> boolean
let sLogBuffer = [];       // compact log buffer (last 50 lines)
let sLogFilter = 'all';    // all | error | warn
let sLastUpdate = null;    // ISO timestamp of last data received
const S_MAX_LOGS = 50;

// ── Tab switching ─────────────────────────────────────────────

document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    sActiveProject = tab.dataset.project;
    document.querySelectorAll('.project-view').forEach(v => v.style.display = 'none');
    const view = document.getElementById('project-' + sActiveProject);
    if (view) view.style.display = 'block';
    renderSidebar();
  });
});

// ── Message Listener ──────────────────────────────────────────

window.addEventListener('message', event => {
  const msg = event.data;
  if (msg.type === 'update') {
    sData = msg.data;
    sLastUpdate = new Date().toISOString();
    renderSidebar();
    flashUpdateIndicator();
  } else if (msg.type === 'log_append' && msg.domain && msg.lines) {
    msg.lines.forEach(l => {
      sLogBuffer.push({ domain: msg.domain, text: l, time: new Date().toISOString() });
    });
    if (sLogBuffer.length > S_MAX_LOGS) sLogBuffer = sLogBuffer.slice(-S_MAX_LOGS);
    renderLogs();
  }
});

// ── Update indicator flash ────────────────────────────────────

function flashUpdateIndicator() {
  const el = document.getElementById('update-indicator');
  if (!el) return;
  el.classList.add('flash');
  setTimeout(() => el.classList.remove('flash'), 600);
}

// ── Render ────────────────────────────────────────────────────

function renderSidebar() {
  // Show diagnostic when data hasn't arrived yet
  if (!sData) {
    const el = document.getElementById('project-' + sActiveProject);
    if (el) el.innerHTML = `<div class="loading-state">
      <div class="loading-spinner"></div>
      <div class="loading-text">Waiting for data...</div>
      <div class="loading-detail">Scripts loaded. Check DevTools (F12) if stuck.</div>
    </div>`;
    return;
  }

  // Header
  const proj = sData[sActiveProject] || sData.merlin;
  if (!proj) {
    const el = document.getElementById('project-' + sActiveProject);
    if (el) el.innerHTML = '<div style="padding:16px 8px;color:#ff8800;font-size:10px;text-align:center">No data for: ' + escapeHtml(sActiveProject) + '</div>';
    return;
  }

  const ctrl = proj.control || {};
  const stateEl = document.getElementById('h-state');
  const timeEl = document.getElementById('h-time');
  if (stateEl) {
    stateEl.textContent = (ctrl.state || '--').toUpperCase();
    stateEl.className = 'state-badge badge ' + stateToBadgeClass(ctrl.state);
  }
  if (timeEl) timeEl.textContent = clockTime();

  // Update toolbar button states
  updateToolbarButtons(ctrl.state);

  try {
    if (sActiveProject === 'merlin') {
      renderMerlinSidebar(proj);
    } else {
      renderOtherSidebar(sActiveProject, proj);
    }
  } catch (err) {
    const el = document.getElementById('project-' + sActiveProject);
    if (el) el.innerHTML = '<div style="padding:16px 8px;color:#ff3333;font-size:10px;text-align:center">Render error: ' + escapeHtml(String(err.message || err)) + '</div>';
  }
}

function stateToBadgeClass(state) {
  if (state === 'running') return 'badge-run';
  if (state === 'waiting_human') return 'badge-escalate';
  if (state === 'error') return 'badge-err';
  if (state === 'stopped') return 'badge-err';
  return 'badge-idle';
}

function updateToolbarButtons(state) {
  const btnStart = document.getElementById('btn-start');
  const btnStop = document.getElementById('btn-stop');
  if (btnStart && btnStop) {
    const isRunning = state === 'running' || state === 'waiting_human';
    btnStart.disabled = isRunning;
    btnStop.disabled = !isRunning;
    btnStart.classList.toggle('disabled', isRunning);
    btnStop.classList.toggle('disabled', !isRunning);
  }
}

function renderMerlinSidebar(m) {
  const el = document.getElementById('project-merlin');
  if (!el) return;

  const ctrl = m.control || {};
  const tree = m.pipeline_tree || {};
  const counts = m.counts || {};

  let html = '';

  // ── Quick Stats Bar ───────────────────────────────────────
  const totalWorkers = counts.workers_total || 0;
  const doneWorkers = counts.workers_done || 0;
  const errorWorkers = counts.workers_error || 0;
  const activeWorkers = counts.workers_active || 0;
  const progressPct = totalWorkers > 0 ? Math.round((doneWorkers / totalWorkers) * 100) : 0;

  html += `<div class="stats-bar">
    <div class="stats-progress">
      <div class="stats-progress-fill${errorWorkers > 0 ? ' has-errors' : ''}" style="width:${progressPct}%"></div>
    </div>
    <div class="stats-row">
      <span class="stat-item stat-done" title="Completed">${doneWorkers} done</span>
      <span class="stat-item stat-active" title="Active">${activeWorkers} active</span>
      <span class="stat-item stat-error" title="Errors">${errorWorkers} err</span>
      <span class="stat-item stat-pct">${progressPct}%</span>
    </div>
  </div>`;

  // ── Pipeline info ─────────────────────────────────────────
  html += `<div class="pipeline-bar">
    <span class="pill">C${ctrl.cycle || '-'}</span>
    <span class="pill wave">W${(ctrl.wave || '-').toString().toUpperCase()}</span>
    ${ctrl.detail ? `<span class="pill-detail">${escapeHtml(truncate(ctrl.detail, 35))}</span>` : ''}
  </div>`;

  // ── V4 Workers (Claude Code subagents) ──────────────────
  const v4 = m.v4_session;
  if (v4 && v4.workers && v4.workers.length > 0) {
    html += renderV4Session(v4);
  }

  // ── Director ──────────────────────────────────────────────
  const d = tree.director;
  if (d) {
    const badgeCls = decisionBadgeClass(d.decision);
    html += `<div class="section-header" onclick="sToggle('director')">
      <span>DIRECTOR</span>
      <span class="badge ${badgeCls}" style="font-size:8px">${escapeHtml(d.decision || '---')}</span>
    </div>`;
    html += `<div class="${sCollapsed.director ? 'section-content collapsed' : 'section-content'}">`;
    html += `<div class="s-director">
      <span class="s-score">Quality: <b>${d.quality_score || 0}</b></span>
      <span class="s-score">Confidence: <b>${d.confidence_score || 0}</b></span>
    </div>`;
    if (d.critical_issues && d.critical_issues.length > 0) {
      html += `<div class="s-issues">`;
      d.critical_issues.slice(0, 3).forEach(issue => {
        html += `<div class="s-issue-item">${escapeHtml(truncate(issue, 50))}</div>`;
      });
      html += `</div>`;
    }
    html += '</div>';
  }

  // ── Workers ───────────────────────────────────────────────
  const workers = tree.workers || [];
  html += `<div class="section-header" onclick="sToggle('workers')">
    <span>WORKERS <span class="count">(${counts.workers_done}/${counts.workers_total})</span></span>
  </div>`;
  html += `<div class="${sCollapsed.workers ? 'section-content collapsed' : 'section-content'}">`;
  workers.forEach((w, i) => {
    const isLast = i === workers.length - 1;
    const conn = isLast ? '\u2570' : '\u251C';
    const glyph = statusGlyph(w.status);
    const glyphCls = w.status === 'in_progress' ? 'active' : w.status === 'error' ? 'error' : w.status === 'done' || w.status === 'merged' ? 'done' : 'idle';
    const stateCls = w.status === 'error' ? ' error-state' : w.status === 'in_progress' ? ' active-state' : '';
    const hint = w.current_task_title || '-';

    html += `<div class="s-worker-row">
      <div class="s-tree-node${stateCls}" onclick="openPanel('${escapeHtml(w.domain)}')">
        <span class="s-connector">${conn}</span>
        <span class="s-glyph ${glyphCls}">${glyph}</span>
        <span class="s-label">${escapeHtml(truncate(w.domain, 14))}</span>
        <span class="s-hint">${escapeHtml(truncate(hint, 18))}</span>
        <span class="s-badge badge ${statusBadgeClass(w.status)}">${statusLabel(w.status)}</span>
      </div>
      <div class="s-worker-actions">
        ${w.status === 'error' ? `<button class="action-btn action-retry" onclick="event.stopPropagation();postMessage({command:'retryWorker',domain:'${escapeHtml(w.domain)}'})" title="Retry">&#x21BB;</button>` : ''}
        <button class="action-btn action-log" onclick="event.stopPropagation();postMessage({command:'openLogFile',domain:'${escapeHtml(w.domain)}'})" title="View log">&#x1F4C4;</button>
        <button class="action-btn action-status" onclick="event.stopPropagation();postMessage({command:'openStatusFile',domain:'${escapeHtml(w.domain)}'})" title="View status JSON">&#x7B;&#x7D;</button>
        <button class="action-btn action-worktree" onclick="event.stopPropagation();postMessage({command:'openWorktree',domain:'${escapeHtml(w.domain)}'})" title="Open worktree">&#x1F4C2;</button>
      </div>
    </div>`;
  });
  html += '</div>';

  // ── Escalation ────────────────────────────────────────────
  if (m.questions && m.questions.questions && m.questions.questions.length > 0) {
    const qlevel = m.questions.escalation_level || 'ASK';
    const qcolor = qlevel === 'BLOCK' ? 'var(--danger, #ff3333)' : 'var(--warning, #e6a700)';
    const effort = m.questions.estimated_human_effort_minutes ? ` (~${m.questions.estimated_human_effort_minutes}min)` : '';
    html += `<div class="s-escalation">
      <div class="s-escalation-title">
        <span style="background:${qcolor};color:#000;padding:1px 4px;border-radius:2px;font-size:8px;font-weight:700">${escapeHtml(qlevel)}</span>
        ESCALATION${escapeHtml(effort)} \u2014 ${m.questions.questions.length} questions
      </div>
      ${m.questions.questions.slice(0, 3).map((q, i) => {
        const isStr = typeof q === 'string';
        const label = isStr ? 'Q' + (i + 1) : (q.id || 'Q' + (i + 1));
        const text = isStr ? q : (q.question || '');
        return `<div class="s-escalation-q">${escapeHtml(label)}: ${escapeHtml(truncate(text, 45))}</div>`;
      }).join('')}
      <div class="s-escalation-actions">
        <button class="btn btn-primary" onclick="postMessage({command:'respondEscalation',decision:'proceed'})">PROCEED</button>
        <button class="btn btn-danger" onclick="postMessage({command:'respondEscalation',decision:'rollback'})">ROLLBACK</button>
        <button class="btn" onclick="postMessage({command:'openPanel'})">DETAILS</button>
      </div>
    </div>`;
  }

  // ── Reviews ───────────────────────────────────────────────
  const reviews = tree.reviews || [];
  html += `<div class="section-header" onclick="sToggle('reviews')">
    <span>REVIEWS <span class="count">(${counts.reviews_done}/${counts.reviews_total})</span></span>
  </div>`;
  html += `<div class="${sCollapsed.reviews ? 'section-content collapsed' : 'section-content'}">`;
  reviews.forEach((r, i) => {
    const isLast = i === reviews.length - 1;
    const conn = isLast ? '\u2570' : '\u251C';
    const glyph = statusGlyph(r.status);
    const glyphCls = r.status === 'in_progress' ? 'review' : r.status === 'done' ? 'done' : 'idle';

    html += `<div class="s-tree-node" onclick="openPanel('${escapeHtml(r.domain)}')">
      <span class="s-connector">${conn}</span>
      <span class="s-glyph ${glyphCls}">${glyph}</span>
      <span class="s-label">${escapeHtml(truncate(r.domain, 14))}</span>
      <span class="s-hint">${escapeHtml(truncate(r.current_task_title, 18))}</span>
      <span class="s-badge badge ${statusBadgeClass(r.status)}">${statusLabel(r.status)}</span>
    </div>`;
  });
  html += '</div>';

  // ── Agents (collapsed by default) ─────────────────────────
  if (!('agents' in sCollapsed)) sCollapsed.agents = true;
  const agents = m.agents || [];
  html += `<div class="section-header" onclick="sToggle('agents')">
    <span>AGENTS <span class="count">(${counts.agents_active}/${counts.agents_total})</span></span>
  </div>`;
  html += `<div class="${sCollapsed.agents ? 'section-content collapsed' : 'section-content'}">`;
  const groups = {};
  agents.forEach(a => {
    if (!groups[a.category]) groups[a.category] = [];
    groups[a.category].push(a);
  });
  for (const [cat, items] of Object.entries(groups)) {
    html += `<div class="s-agent-group">${escapeHtml(cat)}</div>`;
    items.forEach(a => {
      html += `<div class="s-agent-item ${a.state}">
        <span class="s-agent-dot ${a.state}"></span>
        <span class="s-agent-name">${escapeHtml(a.name)}</span>
      </div>`;
    });
  }
  html += '</div>';

  // ── Logs with filter ──────────────────────────────────────
  html += `<div class="section-header" onclick="sToggle('logs')">
    <span>LOGS <span class="count">(${sLogBuffer.length})</span></span>
  </div>`;
  html += `<div id="s-logs-section" class="${sCollapsed.logs ? 'section-content collapsed' : 'section-content'}">`;
  html += `<div class="s-log-filter">
    <button class="log-filter-btn${sLogFilter === 'all' ? ' active' : ''}" onclick="setLogFilter('all')">ALL</button>
    <button class="log-filter-btn${sLogFilter === 'error' ? ' active' : ''}" onclick="setLogFilter('error')">ERR</button>
    <button class="log-filter-btn${sLogFilter === 'warn' ? ' active' : ''}" onclick="setLogFilter('warn')">WARN</button>
    <button class="log-filter-btn log-clear" onclick="clearLogs()" title="Clear logs">CLR</button>
  </div>`;
  html += `<div id="s-logs-body">`;
  html += renderLogsHtml();
  html += '</div></div>';

  // ── Quick Actions ─────────────────────────────────────────
  html += `<div class="section-header" onclick="sToggle('quickactions')">QUICK ACTIONS</div>`;
  html += `<div class="${sCollapsed.quickactions ? 'section-content collapsed' : 'section-content'}">`;
  html += `<div class="quick-actions">
    <button class="qa-btn" onclick="postMessage({command:'validate'})" title="Run validate.bat">Validate</button>
    <button class="qa-btn" onclick="postMessage({command:'cleanStatus'})" title="Reset stale status files">Clean</button>
    <button class="qa-btn" onclick="postMessage({command:'openPanel'})" title="Full dashboard Ctrl+Alt+M">Dashboard</button>
    <button class="qa-btn" onclick="postMessage({command:'openConfig'})" title="Edit work_units_v2.json">Config</button>
    <button class="qa-btn" onclick="postMessage({command:'openLogs'})" title="Open logs folder">Logs Dir</button>
  </div>`;
  html += '</div>';

  // ── Footer: last update ───────────────────────────────────
  html += `<div class="sidebar-footer">
    <span class="footer-label">Last update:</span>
    <span class="footer-value">${sLastUpdate ? timeAgo(sLastUpdate) : 'never'}</span>
    <span class="footer-sep">|</span>
    <span class="footer-value">v4.0</span>
  </div>`;

  el.innerHTML = html;
}

function renderOtherSidebar(project, data) {
  const el = document.getElementById('project-' + project);
  if (!el) return;

  const agents = data.agents || [];
  const groups = {};
  agents.forEach(a => {
    if (!groups[a.category]) groups[a.category] = [];
    groups[a.category].push(a);
  });

  let html = `<div class="section-header">AGENTS <span class="count">(${agents.filter(a => a.state === 'active').length}/${agents.length})</span></div>`;
  for (const [cat, items] of Object.entries(groups)) {
    html += `<div class="s-agent-group">${escapeHtml(cat)}</div>`;
    items.forEach(a => {
      html += `<div class="s-agent-item ${a.state}">
        <span class="s-agent-dot ${a.state}"></span>
        <span class="s-agent-name">${escapeHtml(a.name)}</span>
      </div>`;
    });
  }
  html += '<div class="placeholder-compact">No active pipeline</div>';

  el.innerHTML = html;
}

// ── Logs ──────────────────────────────────────────────────────

function renderLogsHtml() {
  const filtered = filterLogs(sLogBuffer);
  let html = '<div class="s-log-container">';
  if (filtered.length === 0) {
    html += '<div class="s-log-empty">No logs yet</div>';
  }
  filtered.forEach(entry => {
    const lower = entry.text.toLowerCase();
    const cls = (lower.includes('error') || lower.includes('erreur') || lower.includes('fail')) ? ' error' :
                (lower.includes('warn') || lower.includes('attention')) ? ' warn' : '';
    html += `<div class="s-log-line${cls}">
      <span class="s-log-domain">${escapeHtml(truncate(entry.domain, 8))}</span>
      <span class="s-log-text">${escapeHtml(truncate(entry.text, 55))}</span>
    </div>`;
  });
  html += '</div>';
  return html;
}

function filterLogs(logs) {
  if (sLogFilter === 'all') return logs;
  return logs.filter(entry => {
    const lower = entry.text.toLowerCase();
    if (sLogFilter === 'error') return lower.includes('error') || lower.includes('erreur') || lower.includes('fail');
    if (sLogFilter === 'warn') return lower.includes('warn') || lower.includes('attention');
    return true;
  });
}

function renderLogs() {
  const body = document.getElementById('s-logs-body');
  if (body && !sCollapsed.logs) {
    body.innerHTML = renderLogsHtml();
    // Auto-scroll to bottom
    const container = body.querySelector('.s-log-container');
    if (container) container.scrollTop = container.scrollHeight;
  }
}

function setLogFilter(filter) {
  sLogFilter = filter;
  // Re-render just the logs section
  const section = document.getElementById('s-logs-section');
  if (section) {
    renderSidebar(); // Full re-render to update active button state
  }
}

function clearLogs() {
  sLogBuffer = [];
  renderLogs();
}

// ── V4 Session Renderer ──────────────────────────────────────

function renderV4Session(v4) {
  const c = v4.counts || {};
  const pct = c.progress || 0;
  const stateLabel = (v4.state || 'idle').toUpperCase();
  const stateCls = v4.state === 'done' ? 'badge-done' : v4.state === 'running' ? 'badge-run' : 'badge-idle';

  let html = '';

  // Session header
  html += `<div class="v4-session">
    <div class="v4-header">
      <span class="v4-title">AUTODEV</span>
      <span class="badge ${stateCls}" style="font-size:8px">${escapeHtml(stateLabel)}</span>
    </div>`;

  // Objective
  if (v4.objective) {
    html += `<div class="v4-objective">${escapeHtml(truncate(v4.objective, 80))}</div>`;
  }

  // Checkpoint
  if (v4.checkpoint) {
    html += `<div class="v4-checkpoint">${escapeHtml(truncate(v4.checkpoint, 60))}</div>`;
  }

  // Global progress bar
  html += `<div class="v4-progress-row">
    <div class="v4-progress-bar">
      <div class="v4-progress-fill${c.error > 0 ? ' has-errors' : ''}" style="width:${pct}%"></div>
    </div>
    <span class="v4-progress-label">${c.done}/${c.total}</span>
  </div>`;

  // Workers list
  html += `<div class="v4-workers">`;
  (v4.workers || []).forEach(w => {
    const wPct = w.status === 'done' ? 100 : w.status === 'error' ? w.progress : w.progress || 0;
    const glyph = w.status === 'done' ? '\u2713' : w.status === 'error' ? '\u2717' : w.status === 'running' ? '\u25B6' : '\u25CB';
    const glyphCls = w.status === 'done' ? 'done' : w.status === 'error' ? 'error' : w.status === 'running' ? 'active' : 'idle';
    const dur = w.duration_ms ? formatDuration(w.duration_ms) : '';

    html += `<div class="v4-worker ${w.status}">
      <div class="v4-worker-header">
        <span class="s-glyph ${glyphCls}">${glyph}</span>
        <span class="v4-worker-name">${escapeHtml(w.name)}</span>
        ${dur ? `<span class="v4-worker-dur">${escapeHtml(dur)}</span>` : ''}
        <span class="v4-worker-badge badge ${statusBadgeClass(w.status)}">${statusLabel(w.status)}</span>
      </div>`;

    // Worker progress bar
    html += `<div class="v4-worker-progress">
      <div class="v4-worker-progress-fill ${glyphCls}" style="width:${wPct}%"></div>
    </div>`;

    // Current action
    if (w.current_action) {
      html += `<div class="v4-worker-action">${escapeHtml(truncate(w.current_action, 50))}</div>`;
    }

    // Changes summary
    if (w.changes_summary) {
      html += `<div class="v4-worker-summary">${escapeHtml(truncate(w.changes_summary, 60))}</div>`;
    }

    // Stats row (tokens + tools)
    if (w.tokens_used > 0 || w.tools_used > 0) {
      html += `<div class="v4-worker-stats">`;
      if (w.tokens_used > 0) html += `<span class="v4-stat">${(w.tokens_used / 1000).toFixed(0)}K tok</span>`;
      if (w.tools_used > 0) html += `<span class="v4-stat">${w.tools_used} tools</span>`;
      html += `</div>`;
    }

    // Files modified (collapsed, max 3 shown)
    if (w.files_modified && w.files_modified.length > 0) {
      const files = w.files_modified.slice(0, 4);
      html += `<div class="v4-worker-files">`;
      files.forEach(f => {
        const short = f.replace(/^(scripts|shaders|addons)\//, '');
        html += `<div class="v4-file">${escapeHtml(truncate(short, 40))}</div>`;
      });
      if (w.files_modified.length > 4) {
        html += `<div class="v4-file v4-file-more">+${w.files_modified.length - 4} more</div>`;
      }
      html += `</div>`;
    }

    // Scope (if no files yet)
    if ((!w.files_modified || w.files_modified.length === 0) && w.scope && w.scope.length > 0) {
      html += `<div class="v4-worker-files">`;
      w.scope.slice(0, 3).forEach(f => {
        const short = f.replace(/^(scripts|shaders|addons)\//, '');
        html += `<div class="v4-file v4-scope">${escapeHtml(truncate(short, 40))}</div>`;
      });
      html += `</div>`;
    }

    html += `</div>`; // close v4-worker
  });
  html += `</div>`; // close v4-workers
  html += `</div>`; // close v4-session

  return html;
}

// ── Helpers ───────────────────────────────────────────────────

function sToggle(id) {
  sCollapsed[id] = !sCollapsed[id];
  renderSidebar();
}

function openPanel(domain) {
  postMessage({ command: 'openPanel', domain });
}

// Clock update every 10s
setInterval(() => {
  const el = document.getElementById('h-time');
  if (el) el.textContent = clockTime();
}, 10000);

// Signal readiness to extension
postMessage({ command: 'ready' });
