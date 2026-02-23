// merlin_provider.js — Read AUTODEV status JSONs + build agent roster
// Called by extension.js every 10s poll tick

const fs = require('fs');
const path = require('path');

const DOMAINS = ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual'];

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
  { name: 'git_commit', category: 'Project', domains: ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish', 'ui-components', 'scene-scripts', 'autoloads-visual'] },
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

/**
 * Safely read and parse a JSON file. Returns null on any error.
 */
function readJSON(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    const raw = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

/**
 * Read last N lines from a file. Returns array of strings.
 */
function tailFile(filePath, maxLines) {
  try {
    if (!fs.existsSync(filePath)) return [];
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').filter(l => l.trim());
    return lines.slice(-maxLines);
  } catch {
    return [];
  }
}

/**
 * Determine agent state from domain statuses and current wave.
 */
function resolveAgentState(agent, domainStatuses, controlState) {
  if (!agent.domains || agent.domains.length === 0) return 'idle';
  if (!controlState) return 'idle';

  const wave = (controlState.wave || '').toLowerCase();
  const buildDomains = ['ui-ux', 'gameplay', 'llm-lora', 'world-structure', 'visual-polish'];
  const reviewDomains = ['testing', 'game-design', 'lore'];

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
      if (buildDomains.includes(domName) && (wave === 'build' || wave === 'fix')) hasActive = true;
      else if (reviewDomains.includes(domName) && wave === 'review') hasReview = true;
      else hasActive = true;
    }
  }

  if (wave === 'review' && reviewDomains.some(d => agent.domains.includes(d))) hasReview = true;
  if (wave === 'director' && agent.domains.includes('game-director')) hasActive = true;

  if (hasError) return 'error';
  if (hasActive) return 'active';
  if (hasReview) return 'review';
  if (hasDone) return 'done';
  return 'idle';
}

/**
 * Read all AUTODEV status data from the status directory.
 * Returns a structured object for the webview.
 */
function readAllStatus(projectRoot) {
  const statusDir = path.join(projectRoot, 'tools', 'autodev', 'status');
  const logsDir = path.join(projectRoot, 'tools', 'autodev', 'logs');

  const control = readJSON(path.join(statusDir, 'control_state.json'));

  const domainStatuses = {};
  const domainList = [];
  for (const d of DOMAINS) {
    const data = readJSON(path.join(statusDir, `${d}.json`));
    domainStatuses[d] = data || { domain: d, status: 'unknown' };
    domainList.push(domainStatuses[d]);
  }

  const director = readJSON(path.join(statusDir, 'director_decision.json'));
  const questions = readJSON(path.join(statusDir, 'director_questions.json'));
  const health = readJSON(path.join(statusDir, 'health_report.json'));
  const testResults = readJSON(path.join(statusDir, 'test_results.json'));
  const stats = readJSON(path.join(statusDir, 'stats_report.json'));

  // Build agent roster with live states
  const agents = AGENT_ROSTER.map(agent => ({
    name: agent.name,
    category: agent.category,
    domains: agent.domains,
    state: resolveAgentState(agent, domainStatuses, control),
  }));

  // Tail logs (last 50 lines per domain)
  const logs = {};
  for (const d of DOMAINS) {
    logs[d] = tailFile(path.join(logsDir, `${d}.log`), 50);
  }

  return {
    project: 'M.E.R.L.I.N.',
    control: control || { state: 'stopped', cycle: 0, wave: '-', detail: '' },
    domains: domainList,
    director: director || null,
    questions: questions || null,
    health: health || null,
    testResults: testResults || null,
    stats: stats || null,
    agents,
    logs,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Placeholder provider for Data/Orange project.
 */
function readDataStatus() {
  return {
    project: 'Data/Orange',
    control: null,
    domains: [],
    director: null,
    questions: null,
    health: null,
    testResults: null,
    stats: null,
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
    logs: {},
    timestamp: new Date().toISOString(),
  };
}

/**
 * Placeholder provider for Cours project.
 */
function readCoursStatus() {
  return {
    project: 'Cours',
    control: null,
    domains: [],
    director: null,
    questions: null,
    health: null,
    testResults: null,
    stats: null,
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
    logs: {},
    timestamp: new Date().toISOString(),
  };
}

module.exports = {
  readAllStatus,
  readDataStatus,
  readCoursStatus,
  DOMAINS,
  AGENT_ROSTER,
};
