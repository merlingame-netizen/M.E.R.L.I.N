#!/usr/bin/env node
// a2a_capability_router.js — A2A Capability-Based Agent Router
// Routes tasks to agents based on capability matching from _registry.json
// Usage: node a2a_capability_router.js "task description" [--top N] [--threshold 0.5]
//   or:  require('./a2a_capability_router.js').route("task description")

'use strict';

const fs = require('fs');
const path = require('path');

const REGISTRY_PATH = path.join(__dirname, 'agent_cards', '_registry.json');

function loadRegistry() {
  try {
    return JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
  } catch {
    return null;
  }
}

/**
 * Route a task description to the best matching agents.
 * @param {string} taskDescription - Natural language task description
 * @param {object} options - { top: number, threshold: number, excludeAgents: string[] }
 * @returns {object[]} Ranked list of { agent_id, score, task_types, capabilities }
 */
function route(taskDescription, options) {
  const opts = Object.assign({ top: 5, threshold: 0.3, excludeAgents: [] }, options || {});
  const registry = loadRegistry();
  if (!registry) return [];

  const words = taskDescription.toLowerCase().split(/\s+/);
  const keywordIndex = registry.keyword_index || {};
  const agents = registry.agents || {};

  // Score each agent by keyword matches * confidence
  const scores = {};
  const taskTypeMatches = {};

  for (const word of words) {
    if (!keywordIndex[word]) continue;
    for (const entry of keywordIndex[word]) {
      const aid = entry.agent_id;
      if (opts.excludeAgents.includes(aid)) continue;

      if (!scores[aid]) {
        scores[aid] = 0;
        taskTypeMatches[aid] = new Set();
      }
      scores[aid] += entry.confidence;
      taskTypeMatches[aid].add(entry.task_type);
    }
  }

  // Also check capability_index for task_type exact matches
  const capabilityIndex = registry.capability_index || {};
  for (const word of words) {
    if (capabilityIndex[word]) {
      for (const entry of capabilityIndex[word]) {
        const aid = entry.agent_id;
        if (opts.excludeAgents.includes(aid)) continue;
        if (!scores[aid]) {
          scores[aid] = 0;
          taskTypeMatches[aid] = new Set();
        }
        scores[aid] += entry.confidence * 1.5; // Boost for direct task_type match
        taskTypeMatches[aid].add(word);
      }
    }
  }

  // Normalize scores (0-1 range)
  const maxScore = Math.max(...Object.values(scores), 1);

  // Build result
  const results = Object.entries(scores)
    .map(([agentId, rawScore]) => {
      const normalizedScore = rawScore / maxScore;
      const card = agents[agentId] || {};
      return {
        agent_id: agentId,
        name: card.name || agentId,
        score: Math.round(normalizedScore * 100) / 100,
        raw_score: Math.round(rawScore * 100) / 100,
        category: card.category || 'unknown',
        cost_profile: card.cost_profile || 'sonnet',
        task_types: Array.from(taskTypeMatches[agentId] || []),
        capabilities: (card.capabilities || []).map(c => c.task_type),
        dependencies: card.dependencies || [],
        file_scope: card.file_scope || [],
      };
    })
    .filter(r => r.score >= opts.threshold)
    .sort((a, b) => b.score - a.score)
    .slice(0, opts.top);

  return results;
}

/**
 * Find agents that can collaborate on a multi-aspect task.
 * Returns groups of agents organized by category.
 * @param {string} taskDescription
 * @returns {object} { primary: agent, reviewers: agent[], support: agent[] }
 */
function routeWithCollaboration(taskDescription, options) {
  const allMatches = route(taskDescription, Object.assign({}, options, { top: 10, threshold: 0.2 }));

  if (allMatches.length === 0) return { primary: null, reviewers: [], support: [] };

  const primary = allMatches[0];

  // Find reviewers: agents with "review" or "validate" mode capabilities
  const reviewers = allMatches.slice(1).filter(a => {
    const card = loadRegistry()?.agents?.[a.agent_id];
    if (!card) return false;
    return card.capabilities.some(c => c.mode === 'review' || c.mode === 'validate');
  }).slice(0, 2);

  // Find support: remaining agents that aren't the primary or reviewers
  const reviewerIds = new Set(reviewers.map(r => r.agent_id));
  const support = allMatches.slice(1)
    .filter(a => !reviewerIds.has(a.agent_id))
    .slice(0, 2);

  return { primary, reviewers, support };
}

/**
 * Generate a dispatch plan for a complex task.
 * @param {string} taskDescription
 * @returns {object} { waves: [{ agents: [], mode: 'parallel'|'sequential' }] }
 */
function generateDispatchPlan(taskDescription) {
  const collab = routeWithCollaboration(taskDescription);
  if (!collab.primary) return { waves: [] };

  const waves = [];

  // Wave 1: Primary agent + support (parallel)
  const wave1Agents = [collab.primary];
  if (collab.support.length > 0) {
    wave1Agents.push(...collab.support);
  }
  waves.push({
    wave: 1,
    label: 'BUILD',
    mode: wave1Agents.length > 1 ? 'parallel' : 'sequential',
    agents: wave1Agents.map(a => ({
      agent_id: a.agent_id,
      name: a.name,
      score: a.score,
      task_types: a.task_types,
    })),
  });

  // Wave 2: Reviewers (parallel)
  if (collab.reviewers.length > 0) {
    waves.push({
      wave: 2,
      label: 'REVIEW',
      mode: collab.reviewers.length > 1 ? 'parallel' : 'sequential',
      agents: collab.reviewers.map(a => ({
        agent_id: a.agent_id,
        name: a.name,
        score: a.score,
        task_types: a.task_types,
      })),
    });
  }

  return {
    task: taskDescription.substring(0, 100),
    generated_at: new Date().toISOString(),
    total_agents: waves.reduce((sum, w) => sum + w.agents.length, 0),
    waves,
  };
}

// Export for require()
module.exports = { route, routeWithCollaboration, generateDispatchPlan, loadRegistry };

// CLI mode
if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.log('Usage: node a2a_capability_router.js "task description" [--top N] [--plan]');
    process.exit(0);
  }

  const taskDesc = args.filter(a => !a.startsWith('--')).join(' ');
  const topN = args.includes('--top') ? parseInt(args[args.indexOf('--top') + 1]) : 5;
  const planMode = args.includes('--plan');

  if (planMode) {
    const plan = generateDispatchPlan(taskDesc);
    console.log(JSON.stringify(plan, null, 2));
  } else {
    const results = route(taskDesc, { top: topN });
    console.log(JSON.stringify(results, null, 2));
  }
}
