// merlin_provider.js — AUTODEV Monitor v3.0 data provider
// Reads status JSONs, enriches with task titles/descriptions from registry,
// classifies blocker errors, reads feedback, builds hierarchical data model

const fs = require('fs');
const path = require('path');
const { buildTaskRegistry, getTask, getDomain } = require('./task_registry');

const DOMAINS = [
  'ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish',
  'ui-components', 'scene-scripts', 'autoloads-visual'
];

const REVIEW_DOMAINS = ['testing', 'game-design', 'lore'];

const AGENT_ROSTER = [
  { name: 'lead_godot', category: 'Core Technical', domains: ['gameplay', 'world-structure', 'scene-scripts'] },
  { name: 'godot_expert', category: 'Core Technical', domains: ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual'] },
  { name: 'llm_expert', category: 'Core Technical', domains: ['llm-lora'] },
  { name: 'debug_qa', category: 'Core Technical', domains: ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual', 'testing'] },
  { name: 'optimizer', category: 'Core Technical', domains: ['ui-ux', 'gameplay'] },
  { name: 'shader_specialist', category: 'Core Technical', domains: ['visual-polish', 'autoloads-visual'] },
  { name: 'ui_impl', category: 'UI/UX', domains: ['ui-ux', 'visual-polish', 'ui-components'] },
  { name: 'ux_research', category: 'UI/UX', domains: ['ui-ux', 'ui-components'] },
  { name: 'motion_designer', category: 'UI/UX', domains: ['ui-ux', 'ui-components', 'autoloads-visual'] },
  { name: 'mobile_touch', category: 'UI/UX', domains: ['ui-ux'] },
  { name: 'game_designer', category: 'Content', domains: ['gameplay', 'game-design', 'world-structure', 'scene-scripts'] },
  { name: 'narrative_writer', category: 'Content', domains: ['gameplay', 'lore', 'scene-scripts'] },
  { name: 'art_direction', category: 'Content', domains: ['visual-polish', 'autoloads-visual'] },
  { name: 'audio_designer', category: 'Content', domains: [] },
  { name: 'merlin_guardian', category: 'Lore', domains: ['world-structure', 'lore'] },
  { name: 'lore_writer', category: 'Lore', domains: ['world-structure', 'lore'] },
  { name: 'historien_bretagne', category: 'Lore', domains: ['lore'] },
  { name: 'producer', category: 'Operations', domains: [] },
  { name: 'localisation', category: 'Operations', domains: [] },
  { name: 'technical_writer', category: 'Operations', domains: [] },
  { name: 'data_analyst', category: 'Operations', domains: [] },
  { name: 'git_commit', category: 'Project', domains: DOMAINS },
  { name: 'project_curator', category: 'Project', domains: [] },
  { name: 'accessibility', category: 'Security', domains: ['ui-components'] },
  { name: 'security_hardening', category: 'Security', domains: [] },
  { name: 'prompt_curator', category: 'Security', domains: ['llm-lora'] },
  { name: 'meta_progression', category: 'Economy', domains: ['gameplay'] },
  { name: 'ci_cd_release', category: 'CI/CD', domains: [] },
  { name: 'lora_gameplay_translator', category: 'LoRA', domains: ['llm-lora'] },
  { name: 'lora_data_curator', category: 'LoRA', domains: ['llm-lora'] },
  { name: 'lora_training_architect', category: 'LoRA', domains: ['llm-lora'] },
  { name: 'lora_evaluator', category: 'LoRA', domains: ['llm-lora'] },
  { name: 'game_director', category: 'Director', domains: ['game-director'] },
];

// ── Helpers ─────────────────────────────────────────────────────

function readJSON(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

// ── Blocker Classification ──────────────────────────────────────

/**
 * Classify a blocker message into a known error pattern.
 * Returns { code, hint, severity } or null if no blocker.
 */
function classifyBlocker(blockerText) {
  if (!blockerText || !blockerText.trim()) return null;
  const lower = blockerText.toLowerCase();

  if (lower.includes('fichier ouvert') || lower.includes('volume') || lower.includes('endommagé') || lower.includes('endommage')) {
    return {
      code: 'WORKTREE_LOCK',
      hint: 'Corruption worktree Windows (OneDrive sync). Fermer les editeurs pointant vers le worktree et relancer le worker.',
      severity: 'STRUCTURAL',
    };
  }
  if (lower.includes('cannot find module') || lower.includes('module not found')) {
    return {
      code: 'MISSING_DEP',
      hint: 'Dependance manquante dans le worktree. Verifier node_modules et addons.',
      severity: 'FIXABLE',
    };
  }
  if (lower.includes('permission denied') || lower.includes('access denied') || lower.includes('acces refuse')) {
    return {
      code: 'PERMISSION',
      hint: 'Erreur de permissions fichier. Verifier que le chemin du worktree est accessible en ecriture.',
      severity: 'FIXABLE',
    };
  }
  if (lower.includes('timeout') || lower.includes('timed out')) {
    return {
      code: 'TIMEOUT',
      hint: 'Le worker a depasse le delai maximum. Verifier la charge systeme et la connectivite Ollama.',
      severity: 'TRANSIENT',
    };
  }
  if (lower.includes('merge conflict') || lower.includes('conflit')) {
    return {
      code: 'MERGE_CONFLICT',
      hint: 'Conflit de merge entre branches. Resolution manuelle necessaire.',
      severity: 'STRUCTURAL',
    };
  }
  if (lower.includes('claude') && (lower.includes('crash') || lower.includes('exit'))) {
    return {
      code: 'CLAUDE_CRASH',
      hint: 'Le processus Claude CLI a plante. Verifier les logs pour le stack trace.',
      severity: 'TRANSIENT',
    };
  }

  return {
    code: 'UNKNOWN',
    hint: blockerText,
    severity: 'UNKNOWN',
  };
}

// ── Task Enrichment ──────────────────────────────────────────────

function enrichTaskList(taskIds) {
  return (taskIds || []).map(id => {
    const meta = getTask(id);
    return meta
      ? { id, title: meta.title, priority: meta.priority, description: meta.description }
      : { id, title: id, priority: '', description: '' };
  });
}

// ── Agent State Resolution ──────────────────────────────────────

function resolveAgentState(agent, domainStatuses, controlState) {
  if (!agent.domains || agent.domains.length === 0) return 'idle';
  if (!controlState) return 'idle';

  const wave = (controlState.wave || '').toLowerCase();
  let hasActive = false;
  let hasError = false;
  let hasDone = false;
  let hasReview = false;

  for (const domName of agent.domains) {
    const status = domainStatuses[domName];
    if (!status) continue;

    const st = (status.status || '').toLowerCase();
    if (st === 'error') hasError = true;
    else if (st === 'done' || st === 'merged') hasDone = true;
    else if (st === 'in_progress') {
      if (REVIEW_DOMAINS.includes(domName) && wave === 'review') hasReview = true;
      else hasActive = true;
    }
  }

  if (wave === 'review' && REVIEW_DOMAINS.some(d => agent.domains.includes(d))) hasReview = true;
  if (wave === 'director' && agent.domains.includes('game-director')) hasActive = true;

  if (hasError) return 'error';
  if (hasActive) return 'active';
  if (hasReview) return 'review';
  if (hasDone) return 'done';
  return 'idle';
}

// ── V4 Workers (Claude Code subagents) ──────────────────────────

/**
 * Read AUTODEV v4 session + individual worker status files.
 * These are written by the Claude Code orchestrator when using Task tool subagents.
 * Format: status/session.json + status/worker_{name}.json
 */
function readV4Workers(statusDir) {
  const session = readJSON(path.join(statusDir, 'session.json'));
  if (!session || !session.workers || !Array.isArray(session.workers)) return null;

  // Read individual worker detail files
  const workers = session.workers.map(w => {
    const name = w.name || w.domain || 'unknown';
    const detail = readJSON(path.join(statusDir, `worker_${name}.json`));
    return {
      name,
      status: (detail && detail.status) || w.status || 'pending',
      wave: w.wave || 1,
      objective: (detail && detail.objective) || '',
      scope: (detail && detail.scope) || [],
      current_action: (detail && detail.current_action) || '',
      progress: (detail && detail.progress) || (w.status === 'done' ? 100 : w.status === 'running' ? 50 : 0),
      files_modified: (detail && detail.files_modified) || [],
      changes_summary: (detail && detail.changes_summary) || '',
      tokens_used: (detail && detail.tokens_used) || 0,
      tools_used: (detail && detail.tools_used) || 0,
      started_at: (detail && detail.started_at) || '',
      completed_at: (detail && detail.completed_at) || '',
      duration_ms: (detail && detail.duration_ms) || 0,
      log: (detail && detail.log) || [],
      error: (detail && detail.error) || '',
    };
  });

  const done = workers.filter(w => w.status === 'done').length;
  const running = workers.filter(w => w.status === 'running').length;
  const error = workers.filter(w => w.status === 'error').length;
  const total = workers.length;
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;

  return {
    state: session.state || 'idle',
    objective: session.objective || '',
    checkpoint: session.checkpoint || '',
    started_at: session.started_at || '',
    updated_at: session.updated_at || '',
    cycle: session.cycle || 0,
    workers,
    counts: { total, done, running, error, progress },
  };
}

// ── Main Reader ─────────────────────────────────────────────────

/**
 * Read all AUTODEV status data and enrich with task registry info.
 * @param {string} projectRoot
 * @returns {object} Full enriched status object
 */
function readAllStatus(projectRoot) {
  const statusDir = path.join(projectRoot, 'tools', 'autodev', 'status');
  const logsDir = path.join(projectRoot, 'tools', 'autodev', 'logs');
  const configPath = path.join(projectRoot, 'tools', 'autodev', 'config', 'work_units_v2.json');

  // Rebuild task registry if config changed
  buildTaskRegistry(configPath);

  // Control state
  const control = readJSON(path.join(statusDir, 'control_state.json'));

  // Domain statuses (build workers)
  const domainStatuses = {};
  const workers = [];
  for (const d of DOMAINS) {
    const raw = readJSON(path.join(statusDir, `${d}.json`));
    const data = raw || { domain: d, status: 'unknown' };
    domainStatuses[d] = data;

    // Enrich with task registry
    const domainMeta = getDomain(d);
    const currentTaskMeta = data.current_task ? getTask(data.current_task) : null;

    // Classify blockers
    const blockerText = (data.blockers || []).join(' ');
    const blockerDiag = classifyBlocker(blockerText);

    // Read feedback
    const feedback = readJSON(path.join(statusDir, 'feedback', `${d}.json`));

    workers.push({
      domain: d,
      type: domainMeta ? domainMeta.type : 'build',
      status: data.status || 'unknown',
      domain_description: domainMeta ? domainMeta.description : '',
      file_scope: domainMeta ? domainMeta.file_scope : [],
      agents_config: domainMeta ? domainMeta.agents : [],
      exclusive_files: domainMeta ? domainMeta.exclusive_files : [],
      branch: domainMeta ? domainMeta.branch : '',
      current_task: data.current_task || '',
      current_task_title: currentTaskMeta ? currentTaskMeta.title : (data.current_task || '-'),
      current_task_description: currentTaskMeta ? currentTaskMeta.description : '',
      current_task_priority: currentTaskMeta ? currentTaskMeta.priority : '',
      tasks_completed: enrichTaskList(data.tasks_completed),
      tasks_remaining: enrichTaskList(data.tasks_remaining),
      files_modified: data.files_modified || [],
      blockers: data.blockers || [],
      blocker_diagnosis: blockerDiag,
      feedback: feedback || null,
      timestamp: data.timestamp || '',
    });
  }

  // Review domains
  const reviews = [];
  for (const d of REVIEW_DOMAINS) {
    const raw = readJSON(path.join(statusDir, `${d}.json`));
    const data = raw || { domain: d, status: 'unknown' };
    domainStatuses[d] = data;

    const domainMeta = getDomain(d);
    const currentTaskMeta = data.current_task ? getTask(data.current_task) : null;

    reviews.push({
      domain: d,
      type: 'review',
      status: data.status || 'unknown',
      domain_description: domainMeta ? domainMeta.description : '',
      current_task: data.current_task || '',
      current_task_title: currentTaskMeta ? currentTaskMeta.title : (data.current_task || '-'),
      tasks_completed: enrichTaskList(data.tasks_completed),
      tasks_remaining: enrichTaskList(data.tasks_remaining),
      timestamp: data.timestamp || '',
    });
  }

  // Director
  const director = readJSON(path.join(statusDir, 'director_decision.json'));
  const directives = readJSON(path.join(statusDir, 'director_directives.json'));
  const questions = readJSON(path.join(statusDir, 'director_questions.json'));

  // Health
  const health = readJSON(path.join(statusDir, 'health_report.json'));
  const testResults = readJSON(path.join(statusDir, 'test_results.json'));
  const stats = readJSON(path.join(statusDir, 'stats_report.json'));

  // Agent roster with live states
  const agents = AGENT_ROSTER.map(agent => ({
    name: agent.name,
    category: agent.category,
    domains: agent.domains,
    state: resolveAgentState(agent, domainStatuses, control),
  }));

  // Counts
  const workersDone = workers.filter(w => w.status === 'done' || w.status === 'merged').length;
  const workersError = workers.filter(w => w.status === 'error').length;
  const workersActive = workers.filter(w => w.status === 'in_progress').length;
  const reviewsDone = reviews.filter(r => r.status === 'done').length;

  return {
    project: 'M.E.R.L.I.N.',
    control: {
      state: (control && control.state) || 'stopped',
      cycle: (control && control.cycle) || 0,
      wave: (control && control.wave) || '-',
      detail: (control && control.detail) || '',
      timestamp: (control && control.timestamp) || '',
      wave_mode: !!(control && control.wave_mode),
      max_cycles: (control && control.max_cycles) || 0,
      objective: (control && control.objective) || '',
    },
    pipeline_tree: {
      director: director ? {
        status: director.decision || 'unknown',
        decision: director.decision || '',
        quality_score: director.quality_score || 0,
        confidence_score: director.confidence_score || 0,
        rationale: director.rationale || '',
        critical_issues: director.critical_issues || [],
        quality_breakdown: director.quality_breakdown || null,
        cycle: director.cycle || 0,
      } : null,
      directives: directives || null,
      workers,
      reviews,
    },
    counts: {
      workers_total: DOMAINS.length,
      workers_done: workersDone,
      workers_error: workersError,
      workers_active: workersActive,
      reviews_total: REVIEW_DOMAINS.length,
      reviews_done: reviewsDone,
      agents_total: AGENT_ROSTER.length,
      agents_active: agents.filter(a => a.state === 'active').length,
    },
    health: health ? {
      merge_conflicts: health.merge_conflicts || [],
      alerts: health.alerts || [],
      scope_violations: health.scope_violations || [],
      screenshots: health.screenshots || {},
      active_workers: health.active_workers || [],
    } : null,
    questions: questions || null,
    testResults: testResults || null,
    stats: stats || null,
    agents,
    v4_session: readV4Workers(statusDir),
    timestamp: new Date().toISOString(),
  };
}

// ── Placeholder providers ────────────────────────────────────────

function readDataStatus() {
  return {
    project: 'Data/Orange',
    control: null,
    pipeline_tree: { director: null, workers: [], reviews: [] },
    counts: { workers_total: 0, workers_done: 0, workers_error: 0, workers_active: 0, reviews_total: 0, reviews_done: 0, agents_total: 15, agents_active: 0 },
    health: null,
    questions: null,
    agents: [
      { name: 'bigquery_expert', category: 'Data', domains: [], state: 'idle' },
      { name: 'hive_edh_expert', category: 'Data', domains: [], state: 'idle' },
      { name: 'data_quality', category: 'Data', domains: [], state: 'idle' },
      { name: 'python_analyst', category: 'Data', domains: [], state: 'idle' },
      { name: 'dashboard_builder', category: 'Data', domains: [], state: 'idle' },
      { name: 'cockpit_digital', category: 'Data', domains: [], state: 'idle' },
      { name: 'powerbi_expert', category: 'Data', domains: [], state: 'idle' },
      { name: 'sql_optimizer', category: 'Data', domains: [], state: 'idle' },
      { name: 'data_viz', category: 'Viz', domains: [], state: 'idle' },
      { name: 'excel_expert', category: 'Viz', domains: [], state: 'idle' },
      { name: 'pptx_generator', category: 'Output', domains: [], state: 'idle' },
      { name: 'html_report', category: 'Output', domains: [], state: 'idle' },
      { name: 'notebook_builder', category: 'Output', domains: [], state: 'idle' },
      { name: 'security_rgpd', category: 'Security', domains: [], state: 'idle' },
      { name: 'git_ops', category: 'Ops', domains: [], state: 'idle' },
    ],
    timestamp: new Date().toISOString(),
  };
}

function readCoursStatus() {
  return {
    project: 'Cours',
    control: null,
    pipeline_tree: { director: null, workers: [], reviews: [] },
    counts: { workers_total: 0, workers_done: 0, workers_error: 0, workers_active: 0, reviews_total: 0, reviews_done: 0, agents_total: 16, agents_active: 0 },
    health: null,
    questions: null,
    agents: [
      { name: 'cours_architect', category: 'Pedagogy', domains: [], state: 'idle' },
      { name: 'slide_designer', category: 'Pedagogy', domains: [], state: 'idle' },
      { name: 'exercise_builder', category: 'Pedagogy', domains: [], state: 'idle' },
      { name: 'quiz_generator', category: 'Pedagogy', domains: [], state: 'idle' },
      { name: 'diagram_expert', category: 'Visual', domains: [], state: 'idle' },
      { name: 'pptx_generator', category: 'Visual', domains: [], state: 'idle' },
      { name: 'image_curator', category: 'Visual', domains: [], state: 'idle' },
      { name: 'brand_enforcer', category: 'Visual', domains: [], state: 'idle' },
      { name: 'markdown_writer', category: 'Content', domains: [], state: 'idle' },
      { name: 'pdf_builder', category: 'Content', domains: [], state: 'idle' },
      { name: 'notebook_builder', category: 'Content', domains: [], state: 'idle' },
      { name: 'code_example', category: 'Content', domains: [], state: 'idle' },
      { name: 'accessibility', category: 'Quality', domains: [], state: 'idle' },
      { name: 'spell_checker', category: 'Quality', domains: [], state: 'idle' },
      { name: 'orange_brand', category: 'Brand', domains: [], state: 'idle' },
      { name: 'git_ops', category: 'Ops', domains: [], state: 'idle' },
    ],
    timestamp: new Date().toISOString(),
  };
}

module.exports = {
  readAllStatus,
  readDataStatus,
  readCoursStatus,
  DOMAINS,
  REVIEW_DOMAINS,
  AGENT_ROSTER,
  classifyBlocker,
};
