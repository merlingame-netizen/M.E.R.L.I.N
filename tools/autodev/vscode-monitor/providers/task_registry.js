// task_registry.js — Loads work_units_v2.json and builds lookup tables
// for human-readable task titles and domain metadata

const fs = require('fs');
const path = require('path');

let _taskMap = new Map();   // taskId -> { id, title, description, domain, priority }
let _domainMap = new Map(); // domainName -> { description, file_scope, agents, review_agents, type, tasks, exclusive_files }
let _mergeOrder = [];
let _reviewOrder = [];
let _lastConfigMtime = 0;

/**
 * Build the task registry from work_units_v2.json.
 * Rebuilds only if the file has changed (mtime check).
 * @param {string} configPath - Absolute path to work_units_v2.json
 * @returns {boolean} true if registry was rebuilt
 */
function buildTaskRegistry(configPath) {
  try {
    if (!fs.existsSync(configPath)) return false;

    const stat = fs.statSync(configPath);
    if (stat.mtimeMs === _lastConfigMtime) return false;

    const raw = fs.readFileSync(configPath, 'utf8').replace(/^\uFEFF/, '');
    const config = JSON.parse(raw);

    const newTaskMap = new Map();
    const newDomainMap = new Map();

    for (const domain of (config.domains || [])) {
      newDomainMap.set(domain.name, {
        name: domain.name,
        description: domain.description || '',
        file_scope: domain.file_scope || [],
        agents: domain.agents || [],
        review_agents: domain.review_agents || [],
        type: domain.type || 'build',
        exclusive_files: domain.exclusive_files || [],
        branch: domain.branch || '',
        tasks: (domain.tasks || []).map(t => t.id),
      });

      for (const task of (domain.tasks || [])) {
        newTaskMap.set(task.id, {
          id: task.id,
          title: task.title || task.id,
          description: task.description || '',
          domain: domain.name,
          priority: task.priority || 'medium',
        });
      }
    }

    _taskMap = newTaskMap;
    _domainMap = newDomainMap;
    _mergeOrder = config.merge_order || [];
    _reviewOrder = config.review_order || [];
    _lastConfigMtime = stat.mtimeMs;

    return true;
  } catch {
    return false;
  }
}

/**
 * Get task metadata by ID.
 * @param {string} taskId - e.g. "INFRA.3"
 * @returns {{ id: string, title: string, description: string, domain: string, priority: string } | null}
 */
function getTask(taskId) {
  return _taskMap.get(taskId) || null;
}

/**
 * Get domain metadata by name.
 * @param {string} domainName - e.g. "gameplay"
 * @returns {object | null}
 */
function getDomain(domainName) {
  return _domainMap.get(domainName) || null;
}

/** @returns {string[]} */
function getMergeOrder() { return _mergeOrder; }

/** @returns {string[]} */
function getReviewOrder() { return _reviewOrder; }

/** @returns {number} total tasks across all domains */
function getTotalTasks() { return _taskMap.size; }

/** Force rebuild on next call */
function invalidate() { _lastConfigMtime = 0; }

module.exports = {
  buildTaskRegistry,
  getTask,
  getDomain,
  getMergeOrder,
  getReviewOrder,
  getTotalTasks,
  invalidate,
};
