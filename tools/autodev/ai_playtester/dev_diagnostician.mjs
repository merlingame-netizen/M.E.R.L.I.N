#!/usr/bin/env node
// AI Playtester — Dev Diagnostician
// Reads ALL other agent reports, Godot logs, and game state to:
// 1. Identify bugs and issues across all agents
// 2. Prioritize by severity
// 3. Generate fix suggestions with file paths
// 4. Update task_plan.md and progress.md with findings
// This is the "brain" that turns test results into actionable dev work.
// Usage: node dev_diagnostician.mjs [--cycle 1]

import fs from 'fs';
import path from 'path';
import { generate, checkHealth } from './llm_client.mjs';
import { CONFIG } from './config.mjs';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Collect All Reports ─────────────────────────────────────────────

function collectReports() {
  const reports = {};
  const reportFiles = {
    playtest: 'playtest_report.json',
    visual_qa: 'visual_qa_report.json',
    tunnel: 'tunnel_test_report.json',
    coherence: 'coherence_test_report.json',
    blind_nav: 'blind_nav_report.json',
    ux_critic: 'ux_critic_report.json',
    suite: 'playtest_suite_report.json',
  };

  for (const [key, filename] of Object.entries(reportFiles)) {
    const filePath = path.join(CONFIG.statusDir, filename);
    if (fs.existsSync(filePath)) {
      try {
        reports[key] = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      } catch { /* skip corrupt files */ }
    }
  }

  return reports;
}

// ── Collect Godot Logs ──────────────────────────────────────────────

function collectLogs() {
  const logs = { errors: [], warnings: [], state: null, perf: null };

  // Game log
  const logPath = path.join(CONFIG.capturesDir, 'log.json');
  if (fs.existsSync(logPath)) {
    try {
      const logData = JSON.parse(fs.readFileSync(logPath, 'utf8'));
      const entries = Array.isArray(logData) ? logData : logData.entries || [];
      for (const entry of entries) {
        const str = typeof entry === 'string' ? entry : JSON.stringify(entry);
        if (str.includes('ERROR') || str.includes('SCRIPT ERROR')) {
          logs.errors.push(str.slice(0, 300));
        } else if (str.includes('WARNING') || str.includes('WARN')) {
          logs.warnings.push(str.slice(0, 300));
        }
      }
    } catch { /* ignore */ }
  }

  // State
  const statePath = path.join(CONFIG.capturesDir, 'state.json');
  if (fs.existsSync(statePath)) {
    try { logs.state = JSON.parse(fs.readFileSync(statePath, 'utf8')); } catch { /* ignore */ }
  }

  // Perf
  const perfPath = path.join(CONFIG.capturesDir, 'perf.json');
  if (fs.existsSync(perfPath)) {
    try { logs.perf = JSON.parse(fs.readFileSync(perfPath, 'utf8')); } catch { /* ignore */ }
  }

  return logs;
}

// ── Build Diagnosis Prompt ──────────────────────────────────────────

function buildDiagnosisPrompt(reports, logs) {
  const sections = [];

  // Tunnel test results
  if (reports.tunnel) {
    const t = reports.tunnel;
    const failures = (t.steps || []).filter(s => s.status !== 'pass');
    if (failures.length > 0) {
      sections.push(`TUNNEL TEST FAILURES:\n${failures.map(f =>
        `- ${f.name}: ${f.status} — ${(f.errors || []).join(', ')}`
      ).join('\n')}`);
    }
  }

  // Blind navigator issues
  if (reports.blind_nav) {
    const b = reports.blind_nav;
    if (b.summary?.deadlocksDetected > 0 || b.summary?.possibleCrashes > 0) {
      sections.push(`BLIND NAVIGATOR ISSUES:\n- Deadlocks: ${b.summary.deadlocksDetected}\n- Possible crashes: ${b.summary.possibleCrashes}\n- Errors: ${(b.errors || []).slice(0, 5).map(e => `  ${e.type}: ${e.message || e.button || ''}`).join('\n')}`);
    }
  }

  // Visual QA issues
  if (reports.visual_qa) {
    const v = reports.visual_qa;
    if (v.averageQuality < 7 || (v.allArtifacts || []).length > 0) {
      sections.push(`VISUAL QA (score: ${v.averageQuality}/10):\n- Artifacts: ${(v.allArtifacts || []).join(', ') || 'none'}\n- Recommendations: ${(v.allRecommendations || []).join(', ')}`);
    }
  }

  // UX issues
  if (reports.ux_critic) {
    const u = reports.ux_critic;
    const failures = (u.measurements || []).filter(m => !m.pass);
    if (failures.length > 0) {
      sections.push(`UX FAILURES:\n${failures.map(f => `- ${f.test}: ${f.valueMs ? f.valueMs + 'ms' : ''} (threshold: ${f.threshold})`).join('\n')}`);
    }
  }

  // Coherence issues
  if (reports.coherence) {
    const c = reports.coherence?.analysis;
    if (c && (c.overall_coherence || 10) < 6) {
      sections.push(`COHERENCE ISSUES (score: ${c.overall_coherence}/10):\n- ${c.narrative_detail || ''}\n- ${c.arc_detail || ''}`);
    }
  }

  // Playtest fun
  if (reports.playtest) {
    const p = reports.playtest?.subjective;
    if (p && (p.fun_rating || 10) < 5) {
      sections.push(`LOW FUN RATING (${p.fun_rating}/10):\n- ${p.fun_reasoning || ''}\n- Frustrations: ${(p.frustration_points || []).join(', ')}`);
    }
  }

  // Godot logs
  if (logs.errors.length > 0) {
    sections.push(`GODOT ERRORS (${logs.errors.length}):\n${logs.errors.slice(0, 10).map(e => `- ${e}`).join('\n')}`);
  }

  // Perf issues
  if (logs.perf) {
    const p = logs.perf;
    if ((p.fps_avg || 60) < 30 || (p.fallback_rate || 0) > 0.3) {
      sections.push(`PERFORMANCE:\n- FPS: avg=${p.fps_avg} min=${p.fps_min}\n- Fallback rate: ${p.fallback_rate}\n- Card gen avg: ${p.card_gen_avg_ms}ms`);
    }
  }

  if (sections.length === 0) {
    return null; // No issues found
  }

  return `Tu es un développeur senior qui diagnostique des bugs dans un jeu Godot 4.x (M.E.R.L.I.N.).
Voici les rapports de tous les agents de test :

${sections.join('\n\n')}

Analyse tous les problèmes et produis un diagnostic structuré en JSON :
{
  "issues": [
    {
      "severity": "critical|high|medium|low",
      "category": "crash|deadlock|visual|ux|perf|narrative|gameplay",
      "title": "<titre court>",
      "description": "<description détaillée>",
      "likely_cause": "<cause probable>",
      "suggested_fix": "<correction suggérée>",
      "files_to_check": ["<chemin relatif>"],
      "effort": "trivial|small|medium|large"
    }
  ],
  "plan_updates": [
    "<tâche à ajouter au plan>"
  ],
  "overall_health": <1-10>,
  "verdict": "<état général du jeu en une phrase>"
}`;
}

// ── Update Plan Files ───────────────────────────────────────────────

function updatePlanFiles(diagnosis, cycle) {
  const projectRoot = CONFIG.projectRoot;

  // Update task_plan.md if it exists
  const taskPlanPath = path.join(projectRoot, 'task_plan.md');
  const planUpdates = diagnosis.plan_updates || [];
  const issues = diagnosis.issues || [];

  if (planUpdates.length > 0 || issues.length > 0) {
    let planContent = '';
    if (fs.existsSync(taskPlanPath)) {
      planContent = fs.readFileSync(taskPlanPath, 'utf8');
    }

    const diagSection = `\n\n## AI Diagnostician — Cycle ${cycle} (${new Date().toISOString().split('T')[0]})\n\n`;
    const issueLines = issues
      .filter(i => i.severity === 'critical' || i.severity === 'high')
      .map(i => `- [ ] **[${i.severity.toUpperCase()}]** ${i.title}: ${i.suggested_fix} (${i.files_to_check?.join(', ') || '?'})`)
      .join('\n');
    const planLines = planUpdates.map(p => `- [ ] ${p}`).join('\n');

    const newSection = diagSection +
      (issueLines ? `### Bugs à corriger\n${issueLines}\n\n` : '') +
      (planLines ? `### Tâches ajoutées\n${planLines}\n` : '');

    fs.writeFileSync(taskPlanPath, planContent + newSection, 'utf8');
    console.log(`[Diag] Updated: ${taskPlanPath}`);
  }

  // Update progress.md
  const progressPath = path.join(projectRoot, 'progress.md');
  let progressContent = '';
  if (fs.existsSync(progressPath)) {
    progressContent = fs.readFileSync(progressPath, 'utf8');
  }

  const criticalCount = issues.filter(i => i.severity === 'critical').length;
  const highCount = issues.filter(i => i.severity === 'high').length;
  const progressEntry = `\n- **Cycle ${cycle} AI Diagnosis**: ${issues.length} issues (${criticalCount} critical, ${highCount} high) — Health: ${diagnosis.overall_health}/10\n`;
  fs.writeFileSync(progressPath, progressContent + progressEntry, 'utf8');
  console.log(`[Diag] Updated: ${progressPath}`);
}

// ── Main ────────────────────────────────────────────────────────────

async function runDiagnostician(options = {}) {
  const startTime = Date.now();

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║   Dev Diagnostician — M.E.R.L.I.N.   ║');
  console.log('╚══════════════════════════════════════╝\n');

  // Collect all data
  console.log('[Diag] Collecting agent reports...');
  const reports = collectReports();
  const reportCount = Object.keys(reports).length;
  console.log(`[Diag] Found ${reportCount} reports`);

  console.log('[Diag] Collecting Godot logs...');
  const logs = collectLogs();
  console.log(`[Diag] Errors: ${logs.errors.length}, Warnings: ${logs.warnings.length}`);

  // Build and run diagnosis
  const prompt = buildDiagnosisPrompt(reports, logs);

  let diagnosis;
  if (!prompt) {
    console.log('[Diag] No issues found across all agents — game is healthy!');
    diagnosis = { issues: [], plan_updates: [], overall_health: 10, verdict: 'No issues detected' };
  } else {
    console.log('[Diag] Analyzing issues...');
    try {
      const response = await generate(prompt, { temperature: 0.3, maxTokens: 1024 });
      const jsonMatch = response.text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        diagnosis = JSON.parse(jsonMatch[0].replace(/,\s*}/g, '}').replace(/,\s*]/g, ']'));
      } else {
        diagnosis = { issues: [], plan_updates: [], overall_health: 5, verdict: response.text.slice(0, 200) };
      }
    } catch (e) {
      diagnosis = { issues: [], plan_updates: [], overall_health: 0, verdict: `LLM error: ${e.message}` };
    }
  }

  // Update plan files
  console.log('[Diag] Updating plan files...');
  updatePlanFiles(diagnosis, options.cycle || 0);

  // Write report
  const report = {
    agent: 'dev_diagnostician',
    cycle: options.cycle || 0,
    timestamp: new Date().toISOString(),
    durationMs: Date.now() - startTime,
    reportsAnalyzed: reportCount,
    godotErrors: logs.errors.length,
    diagnosis,
  };

  if (!fs.existsSync(CONFIG.outputDir)) fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const filePath = path.join(CONFIG.outputDir, `diagnosis_c${options.cycle || 0}_${Date.now()}.json`);
  fs.writeFileSync(filePath, JSON.stringify(report, null, 2), 'utf8');
  fs.writeFileSync(path.join(CONFIG.statusDir, 'diagnosis_report.json'), JSON.stringify(report, null, 2), 'utf8');

  // Print summary
  const issues = diagnosis.issues || [];
  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║   DIAGNOSIS RESULTS                   ║`);
  console.log(`╠══════════════════════════════════════╣`);
  console.log(`║  Health: ${String(diagnosis.overall_health || '?').padEnd(2)}/10                        ║`);
  console.log(`║  Issues: ${String(issues.length).padEnd(3)} (${issues.filter(i => i.severity === 'critical').length} crit, ${issues.filter(i => i.severity === 'high').length} high)       ║`);
  console.log(`╚══════════════════════════════════════╝`);
  console.log(`\nVerdict: ${diagnosis.verdict || '?'}`);

  for (const issue of issues) {
    const icon = issue.severity === 'critical' ? 'X' : issue.severity === 'high' ? '!' : '-';
    console.log(`  ${icon} [${issue.severity}] ${issue.title}: ${issue.suggested_fix?.slice(0, 80) || ''}`);
  }

  console.log(`\nReport: ${filePath}`);
  return report;
}

const args = process.argv.slice(2);
const cycle = parseInt(args[args.indexOf('--cycle') + 1]) || 0;

(async () => {
  if (!(await checkHealth())) { console.error('[Diag] Ollama not running'); process.exit(1); }
  try { await runDiagnostician({ cycle }); process.exit(0); }
  catch (e) { console.error(`[Diag] Fatal: ${e.message}`); process.exit(1); }
})();
