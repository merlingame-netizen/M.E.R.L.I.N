// panel.js — AUTODEV Monitor v3.0 Panel Logic
// 3-column layout: Tree | Detail (tabs) | Director+Health

let currentData = null;
let selectedDomain = null;
let expandedNodes = new Set();
let activeTab = 'task';
let logBuffers = {}; // domain -> string[]
let logFilter = 'all'; // all|error|warn
const MAX_LOG_LINES = 200;

// ── Message Listener ──────────────────────────────────────────

window.addEventListener('message', event => {
  const msg = event.data;
  if (msg.type === 'update') {
    currentData = msg.data;
    renderAll();
  } else if (msg.type === 'log_append' && msg.domain && msg.lines) {
    appendLogs(msg.domain, msg.lines);
  } else if (msg.type === 'selectNode' && msg.domain) {
    selectNode(msg.domain);
  }
});

// ── Render All ────────────────────────────────────────────────

function renderAll() {
  if (!currentData || !currentData.merlin) return;
  const m = currentData.merlin;

  // Header
  const ctrl = m.control || {};
  const stateEl = document.getElementById('h-state');
  const pipeEl = document.getElementById('h-pipeline');
  const clockEl = document.getElementById('h-clock');
  if (stateEl) {
    stateEl.textContent = (ctrl.state || '--').toUpperCase();
    stateEl.className = 'badge ' + (ctrl.state === 'running' ? 'badge-run' : ctrl.state === 'waiting_human' ? 'badge-escalate' : 'badge-idle');
  }
  if (pipeEl) pipeEl.textContent = 'C' + (ctrl.cycle || '-') + ' W:' + (ctrl.wave || '-').toUpperCase();
  if (clockEl) clockEl.textContent = clockTime();

  // Tree
  renderDirectorTree(m.pipeline_tree);
  renderWorkerTree(m.pipeline_tree, m.counts);
  renderReviewTree(m.pipeline_tree, m.counts);
  renderAgentTree(m.agents, m.counts);

  // Detail (re-render if a domain is selected)
  if (selectedDomain) {
    renderDetail(selectedDomain);
  }

  // Right column
  renderDirectorStatus(m.pipeline_tree, m.control);
  renderEscalation(m.questions);
  renderHealth(m.health, m.counts);
}

// ── Tree: Director ────────────────────────────────────────────

function renderDirectorTree(tree) {
  const el = document.getElementById('tree-director');
  if (!el || !tree) return;

  const d = tree.director;
  if (!d) {
    el.innerHTML = '<div class="tree-node idle"><span class="tree-connector">\u2570</span><span class="tree-glyph idle">\u25CB</span><span class="tree-label">Game Director</span><span class="tree-task-hint">no decision yet</span></div>';
    return;
  }

  const badgeCls = decisionBadgeClass(d.decision);
  el.innerHTML = `<div class="tree-director">
    <span class="badge ${badgeCls}">${escapeHtml(d.decision || '---')}</span>
    <span class="score">Q:${d.quality_score || 0}</span>
    <span class="score">C:${d.confidence_score || 0}</span>
  </div>`;
}

// ── Tree: Workers ─────────────────────────────────────────────

function renderWorkerTree(tree, counts) {
  const el = document.getElementById('tree-workers');
  const countEl = document.getElementById('worker-count');
  if (!el || !tree) return;

  const workers = tree.workers || [];
  if (countEl) countEl.textContent = `(${counts.workers_done}/${counts.workers_total})`;

  let html = '';
  workers.forEach((w, i) => {
    const isLast = i === workers.length - 1;
    const conn = isLast ? '\u2570' : '\u251C';
    const glyph = statusGlyph(w.status);
    const glyphCls = w.status === 'in_progress' ? 'active' : w.status === 'error' ? 'error' : w.status === 'done' || w.status === 'merged' ? 'done' : 'idle';
    const isSelected = w.domain === selectedDomain;
    const errorCls = w.status === 'error' ? ' error-state' : '';
    const selectedCls = isSelected ? ' selected' : '';
    const taskHint = w.current_task_title || '-';

    html += `<div class="tree-node${errorCls}${selectedCls}" data-domain="${escapeHtml(w.domain)}" onclick="selectNode('${escapeHtml(w.domain)}')">
      <span class="tree-connector">${conn}</span>
      <span class="tree-glyph ${glyphCls}">${glyph}</span>
      <span class="tree-label">${escapeHtml(w.domain)}</span>
      <span class="tree-task-hint">${escapeHtml(truncate(taskHint, 24))}</span>
      <span class="tree-status badge ${statusBadgeClass(w.status)}">${statusLabel(w.status)}</span>
    </div>`;

    // Subtask children (if expanded)
    if (expandedNodes.has(w.domain)) {
      const allTasks = [
        ...(w.tasks_completed || []).map(t => ({ ...t, done: true })),
        ...(w.tasks_remaining || []),
      ];
      allTasks.forEach((t, ti) => {
        const subIsLast = ti === allTasks.length - 1;
        const vertLine = isLast ? ' ' : '\u2502';
        const subConn = subIsLast ? '\u2570' : '\u251C';
        const subGlyph = t.done ? '\u2713' : (t.id === w.current_task ? '\u25B6' : '\u25CB');
        const subCls = t.done ? 'done' : (t.id === w.current_task ? 'active' : 'idle');

        html += `<div class="tree-subtask ${subCls}">
          <span class="tree-connector">${vertLine} ${subConn}</span>
          <span class="tree-glyph ${subCls}">${subGlyph}</span>
          <span class="tree-task-id">${escapeHtml(t.id)}</span>
          <span class="tree-task-title">${escapeHtml(truncate(t.title, 28))}</span>
        </div>`;
      });
    }
  });

  el.innerHTML = html;
}

// ── Tree: Reviews ─────────────────────────────────────────────

function renderReviewTree(tree, counts) {
  const el = document.getElementById('tree-reviews');
  const countEl = document.getElementById('review-count');
  if (!el || !tree) return;

  const reviews = tree.reviews || [];
  if (countEl) countEl.textContent = `(${counts.reviews_done}/${counts.reviews_total})`;

  let html = '';
  reviews.forEach((r, i) => {
    const isLast = i === reviews.length - 1;
    const conn = isLast ? '\u2570' : '\u251C';
    const glyph = statusGlyph(r.status);
    const glyphCls = r.status === 'in_progress' ? 'review' : r.status === 'done' ? 'done' : 'idle';

    html += `<div class="tree-node" data-domain="${escapeHtml(r.domain)}" onclick="selectNode('${escapeHtml(r.domain)}')">
      <span class="tree-connector">${conn}</span>
      <span class="tree-glyph ${glyphCls}">${glyph}</span>
      <span class="tree-label">${escapeHtml(r.domain)}</span>
      <span class="tree-task-hint">${escapeHtml(truncate(r.current_task_title, 24))}</span>
      <span class="tree-status badge ${statusBadgeClass(r.status)}">${statusLabel(r.status)}</span>
    </div>`;
  });

  el.innerHTML = html;
}

// ── Tree: Agents ──────────────────────────────────────────────

function renderAgentTree(agents, counts) {
  const el = document.getElementById('tree-agents');
  const countEl = document.getElementById('agent-count');
  if (!el || !agents) return;

  if (countEl) countEl.textContent = `(${counts.agents_active}/${counts.agents_total})`;

  // Group by category
  const groups = {};
  agents.forEach(a => {
    if (!groups[a.category]) groups[a.category] = [];
    groups[a.category].push(a);
  });

  let html = '';
  for (const [cat, items] of Object.entries(groups)) {
    html += `<div class="agent-category">${escapeHtml(cat)}</div>`;
    items.forEach(a => {
      html += `<div class="agent-item ${a.state}">
        <span class="agent-dot ${a.state}"></span>
        <span class="agent-name">${escapeHtml(a.name)}</span>
      </div>`;
    });
  }

  el.innerHTML = html;
}

// ── Node Selection ────────────────────────────────────────────

function selectNode(domain) {
  // Toggle expand if clicking same node
  if (selectedDomain === domain) {
    if (expandedNodes.has(domain)) expandedNodes.delete(domain);
    else expandedNodes.add(domain);
  } else {
    selectedDomain = domain;
    expandedNodes.add(domain);
  }

  renderAll();
  document.getElementById('detail-tabs').style.display = 'flex';
  document.getElementById('pane-placeholder').style.display = 'none';
}

// ── Detail Rendering ──────────────────────────────────────────

function renderDetail(domain) {
  const m = currentData.merlin;
  const allItems = [...(m.pipeline_tree.workers || []), ...(m.pipeline_tree.reviews || [])];
  const item = allItems.find(w => w.domain === domain);
  if (!item) return;

  document.getElementById('detail-title').textContent = item.domain;
  renderDetailTask(item);
  renderDetailLogs(item);
  renderDetailFiles(item);
  renderDetailMetrics(item);
}

function renderDetailTask(w) {
  const el = document.getElementById('pane-task');
  if (!el) return;

  let html = '';

  // Domain description
  if (w.domain_description) {
    html += `<div class="task-domain-desc">${escapeHtml(w.domain_description)}</div>`;
  }

  // Error diagnostic box (if error)
  if (w.status === 'error' && (w.blockers.length > 0 || w.blocker_diagnosis)) {
    const diag = w.blocker_diagnosis || {};
    html += `<div class="error-box">
      <div class="error-box-title">\u2717 ERREUR \u2014 ${escapeHtml(w.domain)}</div>
      <div class="error-box-message">${escapeHtml(w.blockers.join('\n'))}</div>
      ${diag.hint ? `<div class="error-box-hint">\u2139 ${escapeHtml(diag.hint)}</div>` : ''}
      ${diag.code ? `<div class="error-box-code">Code: ${escapeHtml(diag.code)} | Severite: ${escapeHtml(diag.severity || '?')}</div>` : ''}
      <div class="error-actions">
        <button class="btn btn-primary" onclick="postMessage({command:'retryWorker',domain:'${escapeHtml(w.domain)}'})">RETRY</button>
        <button class="btn" onclick="postMessage({command:'openWorktree',domain:'${escapeHtml(w.domain)}'})">OUVRIR WORKTREE</button>
      </div>
    </div>`;
  }

  // Current task
  if (w.current_task) {
    html += `<div class="task-current">
      <div class="task-current-label">Tache en cours</div>
      <div class="task-current-id">${escapeHtml(w.current_task)} <span class="${priorityClass(w.current_task_priority)}">${escapeHtml(w.current_task_priority || '').toUpperCase()}</span></div>
      <div class="task-current-title">${escapeHtml(w.current_task_title)}</div>
      ${w.current_task_description ? `<div class="task-current-desc">${escapeHtml(w.current_task_description)}</div>` : ''}
    </div>`;
  }

  // Progress bar
  const pct = progressPercent(w.tasks_completed, w.tasks_remaining);
  const done = (w.tasks_completed || []).length;
  const total = done + (w.tasks_remaining || []).length;
  html += `<div class="task-progress">
    <div class="task-progress-label">
      <span>Progression</span>
      <span>${done}/${total} (${pct}%)</span>
    </div>
    <div class="progress-bar"><div class="progress-bar-fill${w.status === 'error' ? ' error' : ''}" style="width:${pct}%"></div></div>
  </div>`;

  // Completed tasks
  if (w.tasks_completed && w.tasks_completed.length > 0) {
    html += `<div class="task-list">
      <div class="task-list-title">Taches terminees</div>
      ${w.tasks_completed.map(t => `<div class="task-item done">
        <span class="task-item-glyph" style="color:var(--status-done)">\u2713</span>
        <span class="task-item-id">${escapeHtml(t.id)}</span>
        <span class="task-item-title">${escapeHtml(t.title)}</span>
      </div>`).join('')}
    </div>`;
  }

  // Remaining tasks
  if (w.tasks_remaining && w.tasks_remaining.length > 0) {
    html += `<div class="task-list">
      <div class="task-list-title">Taches restantes</div>
      ${w.tasks_remaining.map(t => {
        const isCurrent = t.id === w.current_task;
        const cls = isCurrent ? 'active' : '';
        const glyph = isCurrent ? '\u25B6' : '\u25CB';
        const glyphColor = isCurrent ? 'var(--status-active)' : 'var(--status-idle)';
        return `<div class="task-item ${cls}">
          <span class="task-item-glyph" style="color:${glyphColor}">${glyph}</span>
          <span class="task-item-id">${escapeHtml(t.id)}</span>
          <span class="task-item-title">${escapeHtml(t.title)}</span>
          <span class="task-item-priority ${priorityClass(t.priority)}">${escapeHtml(t.priority || '').toUpperCase()}</span>
        </div>`;
      }).join('')}
    </div>`;
  }

  // Agents
  if (w.agents_config && w.agents_config.length > 0) {
    html += `<div class="agents-list">
      <div class="agents-list-title">Agents assignes</div>
      ${w.agents_config.map(a => {
        const name = a.split('/').pop().replace('.md', '');
        return `<div class="agents-list-item">\u2022 ${escapeHtml(name)}</div>`;
      }).join('')}
    </div>`;
  }

  // Action buttons
  html += `<div style="margin-top:16px;display:flex;gap:6px;flex-wrap:wrap">
    <button class="btn btn-primary" onclick="postMessage({command:'retryWorker',domain:'${escapeHtml(w.domain)}'})">RETRY WORKER</button>
    ${w.current_task ? `<button class="btn" onclick="postMessage({command:'skipTask',domain:'${escapeHtml(w.domain)}',taskId:'${escapeHtml(w.current_task)}'})">SKIP TACHE</button>` : ''}
    <button class="btn" onclick="postMessage({command:'openWorktree',domain:'${escapeHtml(w.domain)}'})">OUVRIR WORKTREE</button>
  </div>`;

  el.innerHTML = html;
}

function renderDetailLogs(w) {
  const el = document.getElementById('pane-logs');
  if (!el) return;

  if (!logBuffers[w.domain]) logBuffers[w.domain] = [];
  const lines = logBuffers[w.domain];

  const filteredLines = lines.filter(line => {
    if (logFilter === 'all') return true;
    const lower = line.toLowerCase();
    if (logFilter === 'error') return lower.includes('error') || lower.includes('erreur') || lower.includes('fail');
    if (logFilter === 'warn') return lower.includes('warn') || lower.includes('attention');
    return true;
  });

  el.innerHTML = `
    <div class="logs-toolbar">
      <button class="btn btn-primary" onclick="clearLogs('${escapeHtml(w.domain)}')" style="font-size:9px;padding:2px 6px">CLEAR</button>
      <span class="logs-filter ${logFilter === 'all' ? 'active' : ''}" onclick="setLogFilter('all')" style="cursor:pointer;padding:0 4px">ALL</span>
      <span class="logs-filter ${logFilter === 'error' ? 'active' : ''}" onclick="setLogFilter('error')" style="cursor:pointer;padding:0 4px">ERROR</span>
      <span class="logs-filter ${logFilter === 'warn' ? 'active' : ''}" onclick="setLogFilter('warn')" style="cursor:pointer;padding:0 4px">WARN</span>
      <span style="flex:1"></span>
      <span style="font-size:9px;color:var(--text-muted)">${lines.length} lignes</span>
    </div>
    <div class="log-container" id="log-scroll-${escapeHtml(w.domain)}">
      ${filteredLines.map(line => {
        const lower = line.toLowerCase();
        const cls = (lower.includes('error') || lower.includes('erreur') || lower.includes('fail')) ? ' error' :
                    (lower.includes('warn') || lower.includes('attention')) ? ' warn' : '';
        return `<div class="log-line${cls}">${escapeHtml(line)}</div>`;
      }).join('')}
    </div>`;

  // Auto-scroll to bottom
  const scrollEl = document.getElementById('log-scroll-' + w.domain);
  if (scrollEl) scrollEl.scrollTop = scrollEl.scrollHeight;
}

function renderDetailFiles(w) {
  const el = document.getElementById('pane-files');
  if (!el) return;

  let html = '';

  // Files in scope
  if (w.file_scope && w.file_scope.length > 0) {
    html += `<div class="file-section">
      <div class="file-section-title">Fichiers dans le scope</div>
      ${w.file_scope.map(f => `<div class="file-item">
        <span style="color:var(--text-dim)">\u2022</span>
        <span class="file-link" onclick="postMessage({command:'openFile',path:'${escapeHtml(f)}'});">${escapeHtml(f)}</span>
      </div>`).join('')}
    </div>`;
  }

  // Files modified
  if (w.files_modified && w.files_modified.length > 0) {
    html += `<div class="file-section">
      <div class="file-section-title">Fichiers modifies ce cycle</div>
      ${w.files_modified.map(f => `<div class="file-item">
        <span style="color:var(--status-active)">\u2022</span>
        <span class="file-link" onclick="postMessage({command:'openFile',path:'${escapeHtml(f)}'});">${escapeHtml(f)}</span>
      </div>`).join('')}
    </div>`;
  } else {
    html += `<div class="file-section">
      <div class="file-section-title">Fichiers modifies ce cycle</div>
      <div style="color:var(--text-muted);font-size:10px;padding:4px 0">(aucun)</div>
    </div>`;
  }

  // Exclusive files
  if (w.exclusive_files && w.exclusive_files.length > 0) {
    html += `<div class="file-section">
      <div class="file-section-title">Fichiers exclusifs (verrou)</div>
      ${w.exclusive_files.map(f => `<div class="file-item">
        <span style="color:var(--yellow)">\u26BF</span>
        <span class="file-link" onclick="postMessage({command:'openFile',path:'${escapeHtml(f)}'});">${escapeHtml(f)}</span>
      </div>`).join('')}
    </div>`;
  }

  el.innerHTML = html || '<div class="placeholder-msg">Aucun fichier configure</div>';
}

function renderDetailMetrics(w) {
  const el = document.getElementById('pane-metrics');
  if (!el) return;

  const done = (w.tasks_completed || []).length;
  const total = done + (w.tasks_remaining || []).length;

  let html = `
    <div class="metric-row"><span class="metric-label">Duree</span><span class="metric-value">${formatDuration(w.timestamp)}</span></div>
    <div class="metric-row"><span class="metric-label">Derniere MAJ</span><span class="metric-value">${timeAgo(w.timestamp)}</span></div>
    <div class="metric-row"><span class="metric-label">Taches</span><span class="metric-value">${done} / ${total}</span></div>
    <div class="metric-row"><span class="metric-label">Fichiers modifies</span><span class="metric-value">${(w.files_modified || []).length}</span></div>
    <div class="metric-row"><span class="metric-label">Blockers</span><span class="metric-value${w.blockers && w.blockers.length > 0 ? ' error' : ''}">${(w.blockers || []).length}</span></div>
    <div class="metric-row"><span class="metric-label">Branche</span><span class="metric-value">${escapeHtml(w.branch || '-')}</span></div>
  `;

  // Feedback from director
  if (w.feedback) {
    html += `<div class="feedback-section">
      <div class="feedback-title">Feedback du Directeur (cycle precedent)</div>`;
    if (w.feedback.priority_fixes && w.feedback.priority_fixes.length > 0) {
      html += `<div class="feedback-text"><strong>Fixes prioritaires:</strong><br>${w.feedback.priority_fixes.map(f => '\u2022 ' + escapeHtml(typeof f === 'string' ? f : f.title || f.description || JSON.stringify(f))).join('<br>')}</div>`;
    }
    if (w.feedback.balance_suggestions) {
      html += `<div class="feedback-text" style="margin-top:4px"><strong>Balance:</strong> ${escapeHtml(JSON.stringify(w.feedback.balance_suggestions).substring(0, 200))}</div>`;
    }
    html += '</div>';
  }

  el.innerHTML = html;
}

// ── Right Column ──────────────────────────────────────────────

function renderDirectorStatus(tree, control) {
  const el = document.getElementById('director-content');
  if (!el) return;

  const d = tree ? tree.director : null;
  if (!d) {
    el.innerHTML = '<div style="color:var(--text-muted);font-size:10px">Pas de decision</div>';
    return;
  }

  const qColor = d.quality_score >= 70 ? 'var(--status-done)' : d.quality_score >= 40 ? 'var(--yellow)' : 'var(--red)';
  const cColor = d.confidence_score >= 70 ? 'var(--status-done)' : d.confidence_score >= 40 ? 'var(--yellow)' : 'var(--red)';

  el.innerHTML = `
    <div class="director-decision">
      <span>Decision:</span>
      <span class="badge ${decisionBadgeClass(d.decision)}">${escapeHtml(d.decision)}</span>
      <span style="color:var(--text-muted);font-size:10px">Cycle ${d.cycle || '?'}</span>
    </div>
    <div class="director-scores">
      <div class="score-row">
        <span class="score-label">Qualite</span>
        <div class="score-bar"><div class="score-bar-fill" style="width:${d.quality_score}%;background:${qColor}"></div></div>
        <span class="score-value">${d.quality_score}</span>
      </div>
      <div class="score-row">
        <span class="score-label">Confiance</span>
        <div class="score-bar"><div class="score-bar-fill" style="width:${d.confidence_score}%;background:${cColor}"></div></div>
        <span class="score-value">${d.confidence_score}</span>
      </div>
    </div>
    ${d.critical_issues && d.critical_issues.length > 0 ? `
      <div style="margin-top:8px">
        <div style="color:var(--red);font-size:10px;font-weight:bold;margin-bottom:4px">Issues critiques (${d.critical_issues.length})</div>
        ${d.critical_issues.map(iss => `<div style="color:var(--text-dim);font-size:10px;padding:2px 0 2px 8px;border-left:2px solid var(--red)">${escapeHtml(iss.title || iss.description || JSON.stringify(iss).substring(0, 100))}</div>`).join('')}
      </div>` : ''}
    ${d.rationale ? `<div class="director-rationale">${escapeHtml(d.rationale)}</div>` : ''}
  `;
}

function renderEscalation(questions) {
  const panel = document.getElementById('escalation-panel');
  const el = document.getElementById('escalation-content');
  if (!panel || !el) return;

  if (!questions || !questions.questions || questions.questions.length === 0) {
    panel.style.display = 'none';
    return;
  }

  panel.style.display = 'block';
  let html = '';

  // Escalation level badge (ASK = yellow, BLOCK = red)
  const level = questions.escalation_level || 'ASK';
  const levelColor = level === 'BLOCK' ? 'var(--danger)' : 'var(--warning, #e6a700)';
  html += `<div style="display:flex;align-items:center;gap:6px;margin-bottom:6px">
    <span class="badge" style="background:${levelColor};color:#000;font-size:10px;font-weight:700">${escapeHtml(level)}</span>
    <span style="font-size:10px;color:var(--text-dim)">${escapeHtml(questions.escalation_reason || '')}</span>
  </div>`;

  // Estimated effort
  if (questions.estimated_human_effort_minutes) {
    html += `<div style="font-size:9px;color:var(--text-muted);margin-bottom:4px">Effort estime: ~${escapeHtml(String(questions.estimated_human_effort_minutes))} min</div>`;
  }

  // Diagnostic data summary
  if (questions.diagnostic_data) {
    const diag = questions.diagnostic_data;
    html += `<div style="font-size:9px;color:var(--text-muted);margin-bottom:6px;padding:4px;background:var(--bg-inset, rgba(0,0,0,0.15));border-radius:3px">`;
    if (diag.permanent_errors && diag.permanent_errors.length > 0) {
      html += `<div>Erreurs permanentes: ${diag.permanent_errors.map(e => escapeHtml(String(e))).join(', ')}</div>`;
    }
    if (diag.regression_delta) {
      html += `<div>Regression: ${escapeHtml(String(diag.regression_delta))} pts</div>`;
    }
    html += `</div>`;
  }

  // Questions (support both structured objects and plain strings)
  questions.questions.forEach((q, i) => {
    const isString = typeof q === 'string';
    html += `<div class="escalation-question">`;
    if (isString) {
      html += `<span class="escalation-q-id">Q${i + 1}</span>
        <div class="escalation-q-text">${escapeHtml(q)}</div>`;
    } else {
      html += `<span class="escalation-q-id">${escapeHtml(q.id || 'Q' + (i + 1))}</span>
        <span style="font-size:9px;color:var(--text-dim);margin-left:4px">${escapeHtml(q.category || '')}</span>
        <div class="escalation-q-text">${escapeHtml(q.question || '')}</div>
        <div class="escalation-q-options">
          ${(q.options || []).map(opt => `<button class="btn" style="font-size:9px" onclick="this.classList.toggle('btn-primary')">${escapeHtml(opt)}</button>`).join('')}
        </div>`;
    }
    html += `</div>`;
  });

  // Suggested options (from Director)
  if (questions.suggested_options && questions.suggested_options.length > 0) {
    html += `<div style="font-size:9px;color:var(--text-dim);margin:4px 0">Options suggerees:</div>`;
    html += `<div style="display:flex;flex-wrap:wrap;gap:3px;margin-bottom:6px">`;
    questions.suggested_options.forEach(opt => {
      html += `<button class="btn" style="font-size:9px" onclick="this.classList.toggle('btn-primary')">${escapeHtml(String(opt))}</button>`;
    });
    html += `</div>`;
  }

  html += `<div class="escalation-actions">
    <button class="btn btn-primary" onclick="respondEscalation('proceed')">PROCEED</button>
    <button class="btn btn-danger" onclick="respondEscalation('rollback')">ROLLBACK</button>
  </div>`;

  el.innerHTML = html;
}

function renderHealth(health, counts) {
  const el = document.getElementById('health-content');
  if (!el) return;

  if (!health) {
    el.innerHTML = '<div style="color:var(--text-muted);font-size:10px">Pas de donnees sante</div>';
    return;
  }

  const conflicts = health.merge_conflicts || [];
  const alerts = health.alerts || [];
  const screenshots = health.screenshots || {};
  const violations = health.scope_violations || [];

  let html = `
    <div class="health-item">
      <span class="health-label">Workers done</span>
      <span class="health-value">${counts.workers_done}/${counts.workers_total}</span>
    </div>
    <div class="health-item">
      <span class="health-label">Workers erreur</span>
      <span class="health-value${counts.workers_error > 0 ? ' error' : ''}">${counts.workers_error}</span>
    </div>
    <div class="health-item">
      <span class="health-label">Conflits merge</span>
      <span class="health-value${conflicts.length > 0 ? ' warn' : ''}">${conflicts.length}</span>
    </div>
    <div class="health-item">
      <span class="health-label">Screenshots</span>
      <span class="health-value${screenshots.failed > 0 ? ' error' : ''}">${screenshots.captured || 0}/${screenshots.total || 0}</span>
    </div>
    <div class="health-item">
      <span class="health-label">Violations scope</span>
      <span class="health-value${violations.length > 0 ? ' warn' : ''}">${violations.length}</span>
    </div>
  `;

  if (alerts.length > 0) {
    html += '<div style="margin-top:8px">';
    alerts.slice(0, 5).forEach(a => {
      html += `<div class="health-alert">${escapeHtml(typeof a === 'string' ? a : a.message || JSON.stringify(a).substring(0, 100))}</div>`;
    });
    if (alerts.length > 5) {
      html += `<div style="color:var(--text-muted);font-size:9px;margin-top:4px">+${alerts.length - 5} alertes</div>`;
    }
    html += '</div>';
  }

  el.innerHTML = html;
}

// ── Tab Switching ─────────────────────────────────────────────

function switchTab(tab) {
  activeTab = tab;
  document.querySelectorAll('.dtab').forEach(t => t.classList.toggle('active', t.dataset.tab === tab));
  document.querySelectorAll('.detail-pane').forEach(p => {
    p.style.display = 'none';
    p.classList.remove('active');
  });
  const pane = document.getElementById('pane-' + tab);
  if (pane) {
    pane.style.display = 'block';
    pane.classList.add('active');
  }
}

// ── Log Management ────────────────────────────────────────────

function appendLogs(domain, lines) {
  if (!logBuffers[domain]) logBuffers[domain] = [];
  logBuffers[domain].push(...lines);
  // Trim to max
  if (logBuffers[domain].length > MAX_LOG_LINES) {
    logBuffers[domain] = logBuffers[domain].slice(-MAX_LOG_LINES);
  }
  // Re-render if this domain's logs tab is visible
  if (selectedDomain === domain && activeTab === 'logs') {
    const m = currentData ? currentData.merlin : null;
    if (m) {
      const allItems = [...(m.pipeline_tree.workers || []), ...(m.pipeline_tree.reviews || [])];
      const item = allItems.find(w => w.domain === domain);
      if (item) renderDetailLogs(item);
    }
  }
}

function clearLogs(domain) {
  logBuffers[domain] = [];
  if (selectedDomain === domain && activeTab === 'logs') {
    const m = currentData ? currentData.merlin : null;
    if (m) {
      const allItems = [...(m.pipeline_tree.workers || []), ...(m.pipeline_tree.reviews || [])];
      const item = allItems.find(w => w.domain === domain);
      if (item) renderDetailLogs(item);
    }
  }
}

function setLogFilter(filter) {
  logFilter = filter;
  if (selectedDomain && activeTab === 'logs' && currentData && currentData.merlin) {
    const allItems = [...(currentData.merlin.pipeline_tree.workers || []), ...(currentData.merlin.pipeline_tree.reviews || [])];
    const item = allItems.find(w => w.domain === selectedDomain);
    if (item) renderDetailLogs(item);
  }
}

// ── Escalation Response ───────────────────────────────────────

function respondEscalation(decision) {
  postMessage({ command: 'respondEscalation', decision, details: '', answers: {} });
}

// ── Section Toggle ────────────────────────────────────────────

function toggleSection(sectionId) {
  const section = document.getElementById(sectionId);
  if (section) section.classList.toggle('collapsed');
}

// ── Clock Update ──────────────────────────────────────────────

setInterval(() => {
  const el = document.getElementById('h-clock');
  if (el) el.textContent = clockTime();
}, 10000);

// Signal readiness to extension (fixes race condition where data is sent before scripts load)
postMessage({ command: 'ready' });
