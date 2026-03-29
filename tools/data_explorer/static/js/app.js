/**
 * Data Explorer — Main application JS
 * Handles: API calls, state management, UI wiring, toasts
 */

// ============================================================================
// HTML ESCAPE (XSS prevention)
// ============================================================================

function escapeHtml(s) {
  return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ============================================================================
// STATE
// ============================================================================

const AppState = {
  source: 'edh',           // 'edh' | 'bigquery'
  connections: { edh: false, bigquery: false },
  tables: [],
  currentTable: null,
  schema: [],              // [{name, type, mode}]
  sampleData: null,        // {columns: [], rows: [[]]}
  queryResult: null,       // same shape
  savedQueries: [],
  queryHistory: [],
};

// ============================================================================
// API WRAPPER
// ============================================================================

async function api(method, path, body = null) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
  };
  if (body) opts.body = JSON.stringify(body);

  try {
    const resp = await fetch(path, opts);
    const json = await resp.json();
    if (json.status === 'error') {
      showToast(json.error || 'Erreur inconnue', 'danger');
      return null;
    }
    return json.data;
  } catch (err) {
    showToast(`Erreur reseau : ${err.message}`, 'danger');
    return null;
  }
}

// ============================================================================
// TOAST NOTIFICATIONS
// ============================================================================

function showToast(message, type = 'info', duration = 6000) {
  const container = document.getElementById('toast-container');
  const id = `toast-${Date.now()}`;
  const bgClass = {
    info: 'text-bg-info',
    success: 'text-bg-success',
    warning: 'text-bg-warning',
    danger: 'text-bg-danger',
  }[type] || 'text-bg-info';

  const html = `
    <div id="${id}" class="toast ${bgClass}" role="alert" data-bs-autohide="true" data-bs-delay="${duration}">
      <div class="d-flex">
        <div class="toast-body">${message}</div>
        <button type="button" class="btn-close me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>`;
  container.insertAdjacentHTML('beforeend', html);
  const el = document.getElementById(id);
  const toast = new boosted.Toast(el);
  toast.show();
  el.addEventListener('hidden.bs.toast', () => el.remove());
}

// ============================================================================
// CONNECTION STATUS
// ============================================================================

async function refreshStatus() {
  const data = await api('GET', '/api/status');
  if (!data) return;

  AppState.connections.edh = data.edh?.connected || false;
  AppState.connections.bigquery = data.bigquery?.connected || false;

  updateConnectionBadges();
  updateButtonStates();
}

function updateConnectionBadges() {
  const edh = AppState.connections.edh;
  const bq = AppState.connections.bigquery;

  // Navbar quick-connect buttons
  for (const [btnId, textId, connected, labelOff, labelOn] of [
    ['btn-quick-edh', 'edh-conn-text', edh, 'ODBC', ''],
    ['btn-quick-gcp', 'gcp-conn-text', bq, 'ADC', ''],
  ]) {
    const btn = document.getElementById(btnId);
    const txt = document.getElementById(textId);
    if (btn) {
      btn.classList.toggle('is-connected', connected);
      btn.classList.remove('is-connecting');
    }
    if (txt) txt.textContent = connected ? labelOn : labelOff;
  }

  // Settings tab badges
  for (const [id, connected] of [
    ['settings-badge-edh', edh], ['settings-badge-bq', bq],
  ]) {
    const el = document.getElementById(id);
    if (!el) continue;
    el.classList.toggle('connected', connected);
    el.classList.toggle('disconnected', !connected);
    el.textContent = connected ? 'Connecte' : 'Deconnecte';
  }
}

function updateButtonStates() {
  const connected = AppState.connections[AppState.source];
  const hasTable = !!AppState.currentTable;
  const hasData = !!AppState.sampleData;

  const setDisabled = (id, disabled) => {
    const el = document.getElementById(id);
    if (el) el.disabled = disabled;
  };

  setDisabled('btn-describe', !connected || !hasTable);
  setDisabled('btn-sample', !connected || !hasTable);
  setDisabled('btn-export-csv', !hasData);
  setDisabled('btn-chart', !hasData);
  setDisabled('btn-run-query', !AppState.connections.edh && !AppState.connections.bigquery);
  setDisabled('btn-disconnect-edh', !AppState.connections.edh);
  setDisabled('btn-disconnect-bq', !AppState.connections.bigquery);
}

// ============================================================================
// CONNECTION ACTIONS
// ============================================================================

async function connectEDH() {
  // Grab form fields if filled (Settings tab), otherwise send empty (auto DSN/stored creds)
  const userEl = document.getElementById('edh-user');
  const passEl = document.getElementById('edh-pass');
  const user = userEl ? userEl.value.trim() : '';
  const pass = passEl ? passEl.value : '';
  const msgEl = document.getElementById('edh-status-msg');
  if (msgEl) msgEl.innerHTML = '<small class="text-warning">Connexion ODBC en cours (30-90s)...</small>';

  _setQuickSpinner('edh', true);
  showToast('EDH : connexion ODBC en cours...', 'info', 10000);
  const data = await api('POST', '/api/connect/edh', { user, password: pass });
  _setQuickSpinner('edh', false);

  if (data) {
    if (msgEl) msgEl.innerHTML = '<small class="text-success">Connecte</small>';
    showToast('EDH connecte', 'success');
    await refreshStatus();
    if (AppState.source === 'edh') await loadTables();
  } else {
    if (msgEl) msgEl.innerHTML = '<small class="text-danger">Echec — verifier DSN ODBC ou saisir credentials dans Parametres</small>';
    showToast('EDH : echec connexion. Verifier DSN ou renseigner login dans Parametres.', 'danger', 8000);
  }
}

async function connectBQ() {
  const msgEl = document.getElementById('bq-status-msg');
  if (msgEl) msgEl.innerHTML = '<small class="text-warning">Connexion ADC en cours...</small>';

  _setQuickSpinner('gcp', true);
  showToast('GCP : connexion ADC en cours...', 'info', 8000);
  const data = await api('POST', '/api/connect/bigquery');
  _setQuickSpinner('gcp', false);

  if (data) {
    if (msgEl) msgEl.innerHTML = '<small class="text-success">Connecte</small>';
    showToast('GCP connecte', 'success');
    await refreshStatus();
    if (AppState.source === 'bigquery') await loadTables();
  } else {
    if (msgEl) msgEl.innerHTML = '<small class="text-danger">Echec — lancer: gcloud auth login --update-adc</small>';
    showToast('GCP : echec. Lancer gcloud auth login --update-adc', 'danger', 8000);
  }
}

async function disconnectSource(source) {
  await api('POST', `/api/disconnect/${source}`);
  showToast(`${source.toUpperCase()} deconnecte`, 'info');
  await refreshStatus();
}

// --- Quick-connect from navbar (parallel-safe) ---

function _setQuickSpinner(source, show) {
  const isEdh = source === 'edh';
  const spinnerId = isEdh ? 'spinner-edh' : 'spinner-gcp';
  const btnId = isEdh ? 'btn-quick-edh' : 'btn-quick-gcp';
  const spinner = document.getElementById(spinnerId);
  const btn = document.getElementById(btnId);
  if (spinner) spinner.classList.toggle('d-none', !show);
  if (btn) {
    btn.disabled = show;
    btn.classList.toggle('is-connecting', show);
  }
}

async function quickConnect(source) {
  const isEdh = source === 'edh';
  const isConnected = isEdh ? AppState.connections.edh : AppState.connections.bigquery;

  if (isConnected) {
    await disconnectSource(isEdh ? 'edh' : 'bigquery');
  } else if (isEdh) {
    await connectEDH();
  } else {
    await connectBQ();
  }
}

// ============================================================================
// TABLE BROWSER
// ============================================================================

async function loadTables() {
  const source = AppState.source;
  if (!AppState.connections[source]) return;

  const data = await api('GET', `/api/tables?source=${source}`);
  if (!data) return;

  AppState.tables = data.tables || data || [];
  renderTableList();
}

function renderTableList(filter = '') {
  const list = document.getElementById('table-list');
  const tables = AppState.tables.filter(t => {
    const name = typeof t === 'string' ? t : t.name;
    return name.toLowerCase().includes(filter.toLowerCase());
  });

  if (tables.length === 0) {
    list.innerHTML = '<div class="text-center text-body-secondary py-3"><small>Aucune table</small></div>';
    return;
  }

  list.innerHTML = tables.map(t => {
    const name = typeof t === 'string' ? t : t.name;
    const active = name === AppState.currentTable ? 'active' : '';
    return `<a href="#" class="list-group-item list-group-item-action ${active}" data-table="${name}">${name}</a>`;
  }).join('');

  list.querySelectorAll('.list-group-item').forEach(el => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      selectTable(el.dataset.table);
    });
  });
}

function selectTable(tableName) {
  AppState.currentTable = tableName;
  AppState.sampleData = null;
  document.getElementById('table-info').textContent = tableName;
  renderTableList(document.getElementById('table-filter').value);
  updateButtonStates();
  clearDataTable();
  resetKPIs();
}

// ============================================================================
// DESCRIBE + SAMPLE
// ============================================================================

async function describeTable() {
  if (!AppState.currentTable) return;
  const data = await api('GET', `/api/describe/${AppState.currentTable}?source=${AppState.source}`);
  if (!data) return;

  AppState.schema = data.columns || [];
  renderDataTable(
    (data.columns || []).map(c => c.name || c.col),
    (data.columns || []).map(c => [c.name || c.col, c.type, c.mode || ''])
  );
  updateProfileColumnSelector(AppState.schema.map(c => c.name || c.col));
  document.getElementById('table-info').textContent =
    `${AppState.currentTable} — ${AppState.schema.length} colonnes`;
}

async function sampleTable() {
  if (!AppState.currentTable) return;
  const data = await api('GET', `/api/sample/${AppState.currentTable}?source=${AppState.source}&limit=100`);
  if (!data) return;

  AppState.sampleData = data;
  renderDataTable(data.columns, data.rows);
  updateKPIs(data);
  updateChartControls(data.columns);
  updateProfileColumnSelector(data.columns);
  updateButtonStates();
  document.getElementById('table-info').textContent =
    `${AppState.currentTable} — ${data.rows.length} lignes x ${data.columns.length} cols (${data.duration_ms || 0}ms)`;
}

// ============================================================================
// DATA TABLE RENDERING
// ============================================================================

function renderDataTable(columns, rows) {
  const thead = document.getElementById('data-thead');
  const tbody = document.getElementById('data-tbody');

  thead.innerHTML = '<tr>' + columns.map(c => `<th>${escapeHtml(c)}</th>`).join('') + '</tr>';
  tbody.innerHTML = rows.slice(0, 200).map(row =>
    '<tr>' + (Array.isArray(row) ? row : columns.map(c => row[c] ?? '')).map(v =>
      `<td title="${escapeHtml(v)}">${escapeHtml(v)}</td>`
    ).join('') + '</tr>'
  ).join('');
}

function clearDataTable() {
  document.getElementById('data-thead').innerHTML = '';
  document.getElementById('data-tbody').innerHTML = '';
}

// ============================================================================
// KPI CARDS
// ============================================================================

function resetKPIs() {
  ['kpi-rows', 'kpi-cols', 'kpi-nulls', 'kpi-uniques'].forEach(id => {
    document.getElementById(id).textContent = '--';
  });
}

function updateKPIs(data) {
  if (!data || !data.rows) return;
  const rows = data.rows;
  const cols = data.columns;

  document.getElementById('kpi-rows').textContent = rows.length.toLocaleString();
  document.getElementById('kpi-cols').textContent = cols.length;

  // Null percentage (across all cells)
  let totalCells = 0, nullCells = 0;
  rows.forEach(row => {
    const values = Array.isArray(row) ? row : cols.map(c => row[c]);
    values.forEach(v => {
      totalCells++;
      if (v === null || v === undefined || v === '' || v === 'null') nullCells++;
    });
  });
  const nullPct = totalCells > 0 ? ((nullCells / totalCells) * 100).toFixed(1) : '0';
  document.getElementById('kpi-nulls').textContent = `${nullPct}%`;

  // Unique values in first column
  if (cols.length > 0) {
    const firstCol = cols[0];
    const values = rows.map(r => Array.isArray(r) ? r[0] : r[firstCol]);
    const uniques = new Set(values.filter(v => v != null && v !== '' && v !== 'null'));
    document.getElementById('kpi-uniques').textContent = uniques.size.toLocaleString();
  }
}

// ============================================================================
// COLUMN PROFILING (Count / Distinct)
// ============================================================================

function updateProfileColumnSelector(columns) {
  const sel = document.getElementById('profile-col');
  if (!sel) return;
  const prev = sel.value;
  sel.innerHTML = '<option value="">-- Champ --</option>' +
    columns.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('');
  if (columns.includes(prev)) sel.value = prev;
  sel.disabled = columns.length === 0;
  document.getElementById('btn-count-col').disabled = columns.length === 0;
  document.getElementById('btn-distinct-col').disabled = columns.length === 0;
}

async function profileColumn(mode) {
  const column = document.getElementById('profile-col').value;
  if (!column) { showToast('Choisir un champ dans le selecteur', 'warning'); return; }
  if (!AppState.currentTable) { showToast('Choisir une table', 'warning'); return; }

  const spinner = document.getElementById('spinner-profile');
  const panel = document.getElementById('profile-results');
  const title = document.getElementById('profile-title');
  const body = document.getElementById('profile-body');

  spinner.classList.remove('d-none');
  title.textContent = `${mode === 'count' ? 'Comptage' : 'Distinct'} : ${column}...`;
  panel.classList.remove('d-none');
  body.innerHTML = '<div class="text-center py-2"><span class="spinner-border spinner-border-sm"></span> Extraction en cours (hive-driver)...</div>';

  const data = await api('GET',
    `/api/profile-column/${AppState.currentTable}?source=${AppState.source}&column=${encodeURIComponent(column)}&mode=${mode}`
  );

  spinner.classList.add('d-none');

  if (!data) {
    body.innerHTML = '<div class="text-danger">Erreur profiling</div>';
    return;
  }

  // Update KPI cards with real values
  document.getElementById('kpi-rows').textContent = data.total.toLocaleString() + (data.capped ? '+' : '');
  document.getElementById('kpi-nulls').textContent = data.null_pct + '%';
  document.getElementById('kpi-uniques').textContent = data.distinct_count.toLocaleString();

  if (mode === 'count') {
    title.textContent = `Comptage : ${escapeHtml(column)}`;
    body.innerHTML = `
      <div class="row g-2 text-center">
        <div class="col-4">
          <div class="fw-bold text-primary">${data.total.toLocaleString()}${data.capped ? '<small class="text-warning"> (cap)</small>' : ''}</div>
          <small class="text-body-secondary">Total lignes</small>
        </div>
        <div class="col-4">
          <div class="fw-bold text-success">${data.distinct_count.toLocaleString()}</div>
          <small class="text-body-secondary">Valeurs distinctes</small>
        </div>
        <div class="col-4">
          <div class="fw-bold text-warning">${data.nulls.toLocaleString()} <small>(${data.null_pct}%)</small></div>
          <small class="text-body-secondary">Nulls</small>
        </div>
      </div>
      <div class="text-body-secondary mt-1"><small>${data.duration_ms}ms via hive-driver</small></div>
    `;
  } else {
    // Distinct mode — show values table
    title.textContent = `Distinct : ${escapeHtml(column)} (${data.distinct_count} valeurs)`;
    let valuesHtml = '';
    if (data.values && data.values.length > 0) {
      valuesHtml = `
        <div class="table-scroll mt-2" style="max-height: 260px;">
          <table class="table table-sm table-hover mb-0">
            <thead><tr><th>Valeur</th><th class="text-end">Nb</th><th class="text-end">%</th></tr></thead>
            <tbody>
              ${data.values.map(v => `<tr>
                <td>${escapeHtml(v.value)}</td>
                <td class="text-end">${v.count.toLocaleString()}</td>
                <td class="text-end">${v.pct}%</td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
        ${data.values_truncated ? '<small class="text-warning">Top 50 affichees sur ' + data.distinct_count + ' valeurs</small>' : ''}
      `;
    } else {
      valuesHtml = `<div class="text-body-secondary mt-2"><small>${data.distinct_count} valeurs distinctes (trop nombreuses pour affichage)</small></div>`;
    }
    body.innerHTML = `
      <div class="row g-2 text-center mb-2">
        <div class="col-4">
          <div class="fw-bold text-primary">${data.total.toLocaleString()}${data.capped ? '<small class="text-warning"> (cap)</small>' : ''}</div>
          <small class="text-body-secondary">Total</small>
        </div>
        <div class="col-4">
          <div class="fw-bold text-success">${data.distinct_count.toLocaleString()}</div>
          <small class="text-body-secondary">Distincts</small>
        </div>
        <div class="col-4">
          <div class="fw-bold text-warning">${data.nulls.toLocaleString()} <small>(${data.null_pct}%)</small></div>
          <small class="text-body-secondary">Nulls</small>
        </div>
      </div>
      ${valuesHtml}
      <div class="text-body-secondary mt-1"><small>${data.duration_ms}ms via hive-driver</small></div>
    `;
  }
}

// ============================================================================
// CHART CONTROLS
// ============================================================================

function updateChartControls(columns) {
  const options = '<option value="">--</option>' +
    columns.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('');
  ['chart-x', 'chart-y', 'chart-color'].forEach(id => {
    const el = document.getElementById(id);
    const prev = el.value;
    el.innerHTML = options;
    if (columns.includes(prev)) el.value = prev;
  });
  // Auto-set X to first column
  if (columns.length > 0 && !document.getElementById('chart-x').value) {
    document.getElementById('chart-x').value = columns[0];
  }
  if (columns.length > 1 && !document.getElementById('chart-y').value) {
    document.getElementById('chart-y').value = columns[1];
  }
}

// ============================================================================
// CHART GENERATION
// ============================================================================

async function generateChart() {
  if (!AppState.sampleData) {
    showToast('Chargez un echantillon dans Explorer d\'abord', 'warning');
    return;
  }

  const body = {
    chart_type: document.getElementById('chart-type').value,
    x: document.getElementById('chart-x').value,
    y: document.getElementById('chart-y').value,
    color: document.getElementById('chart-color').value || null,
    top_n: parseInt(document.getElementById('chart-topn').value),
    columns: AppState.sampleData.columns,
    rows: AppState.sampleData.rows,
  };

  const container = document.getElementById('chart-container');
  container.innerHTML = '<div class="spinner-overlay"><div class="spinner-border text-primary"></div></div>';

  const data = await api('POST', '/api/chart', body);
  if (!data) {
    container.innerHTML = '<div class="text-center text-danger py-5">Erreur generation graphe</div>';
    return;
  }

  // data is a Plotly figure JSON
  container.innerHTML = '';
  try {
    const fig = typeof data === 'string' ? JSON.parse(data) : data;
    Plotly.react(container, fig.data || [], fig.layout || {}, { responsive: true });
  } catch (err) {
    container.innerHTML = `<div class="text-center text-danger py-5">Erreur Plotly: ${err.message}</div>`;
  }
}

// ============================================================================
// QUERY EXECUTION
// ============================================================================

async function executeQuery() {
  const sql = document.getElementById('sql-textarea').value.trim();
  if (!sql) { showToast('Entrez une requete SQL', 'warning'); return; }

  const source = document.getElementById('query-source').value;
  document.getElementById('query-result-info').textContent = 'Execution en cours...';

  const data = await api('POST', '/api/query', { source, sql });
  if (!data) {
    document.getElementById('query-result-info').textContent = 'Erreur';
    return;
  }

  AppState.queryResult = data;
  document.getElementById('query-result-info').textContent =
    `${data.rows.length} lignes x ${data.columns.length} cols (${data.duration_ms || 0}ms)`;

  renderQueryResults(data);
  enableExportButtons(true);
  loadQueryHistory();
}

function renderQueryResults(data) {
  const thead = document.getElementById('query-result-thead');
  const tbody = document.getElementById('query-result-tbody');
  thead.innerHTML = '<tr>' + data.columns.map(c => `<th>${escapeHtml(c)}</th>`).join('') + '</tr>';
  tbody.innerHTML = data.rows.slice(0, 500).map(row =>
    '<tr>' + (Array.isArray(row) ? row : data.columns.map(c => row[c] ?? '')).map(v =>
      `<td title="${escapeHtml(v)}">${escapeHtml(v)}</td>`
    ).join('') + '</tr>'
  ).join('');
}

function enableExportButtons(enabled) {
  ['btn-export-query-csv', 'btn-export-query-xlsx', 'btn-export-query-json'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.disabled = !enabled;
  });
}

// ============================================================================
// EXPORT
// ============================================================================

async function exportData(format) {
  const data = AppState.queryResult || AppState.sampleData;
  if (!data) { showToast('Aucune donnee a exporter', 'warning'); return; }

  const resp = await fetch('/api/export', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ columns: data.columns, rows: data.rows, format }),
  });

  if (!resp.ok) { showToast('Erreur export', 'danger'); return; }

  const blob = await resp.blob();
  const ext = { csv: 'csv', xlsx: 'xlsx', json: 'json' }[format] || 'csv';
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `data_export.${ext}`;
  a.click();
  URL.revokeObjectURL(url);
  showToast(`Export ${format.toUpperCase()} telecharge`, 'success');
}

// ============================================================================
// SAVED QUERIES
// ============================================================================

async function loadSavedQueries() {
  const data = await api('GET', '/api/saved-queries');
  if (!data) return;
  AppState.savedQueries = data;
  renderSavedQueries();
}

function renderSavedQueries() {
  const list = document.getElementById('saved-queries-list');
  if (AppState.savedQueries.length === 0) {
    list.innerHTML = '<div class="text-center text-body-secondary py-2"><small>Aucune requete sauvegardee</small></div>';
    return;
  }

  list.innerHTML = AppState.savedQueries.map(q => `
    <div class="list-group-item list-group-item-action d-flex justify-content-between align-items-start" data-id="${escapeHtml(q.id)}">
      <div class="me-auto" style="cursor:pointer;" data-action="load" data-qid="${escapeHtml(q.id)}">
        <div class="fw-bold small">${escapeHtml(q.name)}</div>
        <small class="text-body-secondary query-history-item">${escapeHtml(q.sql.substring(0, 80))}</small>
      </div>
      <button class="btn btn-outline-danger btn-sm" data-action="delete" data-qid="${escapeHtml(q.id)}">X</button>
    </div>
  `).join('');

  // Bind events via delegation instead of inline onclick
  list.querySelectorAll('[data-action="load"]').forEach(el => {
    el.addEventListener('click', () => loadSavedQuery(el.dataset.qid));
  });
  list.querySelectorAll('[data-action="delete"]').forEach(el => {
    el.addEventListener('click', () => deleteSavedQuery(el.dataset.qid));
  });
}

async function saveQuery() {
  const name = document.getElementById('save-query-name').value.trim();
  if (!name) { showToast('Entrez un nom pour la requete', 'warning'); return; }

  const sql = document.getElementById('sql-textarea').value.trim();
  const source = document.getElementById('query-source').value;

  const data = await api('POST', '/api/saved-queries', { name, sql, source });
  if (data) {
    showToast('Requete sauvegardee', 'success');
    boosted.Modal.getInstance(document.getElementById('saveQueryModal'))?.hide();
    await loadSavedQueries();
  }
}

async function loadSavedQuery(id) {
  const q = AppState.savedQueries.find(q => q.id === id);
  if (!q) return;
  document.getElementById('sql-textarea').value = q.sql;
  document.getElementById('query-source').value = q.source || 'edh';
  // Switch to queries tab
  const tab = document.getElementById('tab-queries');
  if (tab) boosted.Tab.getOrCreateInstance(tab).show();
}

async function deleteSavedQuery(id) {
  await api('DELETE', `/api/saved-queries/${id}`);
  showToast('Requete supprimee', 'info');
  await loadSavedQueries();
}

// ============================================================================
// QUERY HISTORY
// ============================================================================

async function loadQueryHistory() {
  const data = await api('GET', '/api/query-history');
  if (!data) return;
  AppState.queryHistory = data;
  renderQueryHistory();
}

function renderQueryHistory() {
  const list = document.getElementById('query-history-list');
  if (AppState.queryHistory.length === 0) {
    list.innerHTML = '<div class="text-center text-body-secondary py-2"><small>Aucun historique</small></div>';
    return;
  }

  list.innerHTML = AppState.queryHistory.map(h => `
    <div class="query-history-item py-1 border-bottom" data-sql="${encodeURIComponent(h.sql)}" data-source="${escapeHtml(h.source || 'edh')}">
      <small class="text-body-secondary">${escapeHtml(h.source || 'edh')}</small> ${escapeHtml(h.sql.substring(0, 60))}
      <small class="text-body-secondary ms-1">(${h.row_count || 0}r, ${h.duration_ms || 0}ms)</small>
    </div>
  `).join('');

  list.querySelectorAll('.query-history-item').forEach(el => {
    el.addEventListener('click', () => loadHistoryQuery(el));
  });
}

function loadHistoryQuery(el) {
  document.getElementById('sql-textarea').value = decodeURIComponent(el.dataset.sql);
  document.getElementById('query-source').value = el.dataset.source || 'edh';
}

// ============================================================================
// EVENT WIRING
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
  // Source toggle
  document.querySelectorAll('input[name="source"]').forEach(radio => {
    radio.addEventListener('change', () => {
      AppState.source = radio.value;
      AppState.currentTable = null;
      AppState.sampleData = null;
      clearDataTable();
      resetKPIs();
      updateButtonStates();
      loadTables();
    });
  });

  // Table filter
  document.getElementById('table-filter').addEventListener('input', (e) => {
    renderTableList(e.target.value);
  });

  // Buttons
  document.getElementById('btn-describe').addEventListener('click', describeTable);
  document.getElementById('btn-sample').addEventListener('click', sampleTable);
  document.getElementById('btn-count-col').addEventListener('click', () => profileColumn('count'));
  document.getElementById('btn-distinct-col').addEventListener('click', () => profileColumn('distinct'));
  document.getElementById('btn-close-profile').addEventListener('click', () => {
    document.getElementById('profile-results').classList.add('d-none');
  });
  document.getElementById('btn-chart').addEventListener('click', generateChart);
  document.getElementById('btn-run-query').addEventListener('click', executeQuery);
  document.getElementById('btn-connect-edh').addEventListener('click', connectEDH);
  document.getElementById('btn-connect-bq').addEventListener('click', connectBQ);
  document.getElementById('btn-quick-edh').addEventListener('click', () => quickConnect('edh'));
  document.getElementById('btn-quick-gcp').addEventListener('click', () => quickConnect('gcp'));
  document.getElementById('btn-disconnect-edh').addEventListener('click', () => disconnectSource('edh'));
  document.getElementById('btn-disconnect-bq').addEventListener('click', () => disconnectSource('bigquery'));

  // Export buttons
  document.getElementById('btn-export-csv').addEventListener('click', () => exportData('csv'));
  document.getElementById('btn-export-query-csv').addEventListener('click', () => exportData('csv'));
  document.getElementById('btn-export-query-xlsx').addEventListener('click', () => exportData('xlsx'));
  document.getElementById('btn-export-query-json').addEventListener('click', () => exportData('json'));

  // Save query
  document.getElementById('btn-save-query').addEventListener('click', () => {
    const sql = document.getElementById('sql-textarea').value.trim();
    if (!sql) { showToast('Ecrivez une requete d\'abord', 'warning'); return; }
    document.getElementById('save-query-name').value = '';
    new boosted.Modal(document.getElementById('saveQueryModal')).show();
  });
  document.getElementById('btn-confirm-save-query').addEventListener('click', saveQuery);

  // Top N slider
  document.getElementById('chart-topn').addEventListener('input', (e) => {
    document.getElementById('topn-val').textContent = e.target.value;
  });

  // Init — refresh status then auto-load tables if already connected
  refreshStatus().then(() => {
    if (AppState.connections[AppState.source]) loadTables();
  });
  loadSavedQueries();
  loadQueryHistory();
});
