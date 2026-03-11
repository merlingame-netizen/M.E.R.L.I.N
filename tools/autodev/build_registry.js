#!/usr/bin/env node
// build_registry.js — A2A Agent Card Registry Builder
// Scans agent_cards/*.json, builds _registry.json with capability + keyword indexes
// Usage: node tools/autodev/build_registry.js

'use strict';

const fs = require('fs');
const path = require('path');

const CARDS_DIR = path.join(__dirname, 'agent_cards');
const REGISTRY_PATH = path.join(CARDS_DIR, '_registry.json');
const SCHEMA_FILE = '_schema.json';

function loadAgentCards() {
  const files = fs.readdirSync(CARDS_DIR)
    .filter(f => f.endsWith('.json') && !f.startsWith('_'));

  const cards = {};
  const errors = [];

  for (const file of files) {
    try {
      const raw = fs.readFileSync(path.join(CARDS_DIR, file), 'utf8');
      const card = JSON.parse(raw);

      if (!card.id || !card.capabilities) {
        errors.push(`${file}: missing required fields (id, capabilities)`);
        continue;
      }

      cards[card.id] = card;
    } catch (e) {
      errors.push(`${file}: ${e.message}`);
    }
  }

  return { cards, errors };
}

function buildCapabilityIndex(cards) {
  const index = {};

  for (const [agentId, card] of Object.entries(cards)) {
    for (const cap of card.capabilities) {
      if (!index[cap.task_type]) {
        index[cap.task_type] = [];
      }
      index[cap.task_type].push({
        agent_id: agentId,
        confidence: cap.confidence,
        mode: cap.mode
      });
    }
  }

  // Sort each task_type by confidence descending
  for (const taskType of Object.keys(index)) {
    index[taskType].sort((a, b) => b.confidence - a.confidence);
  }

  return index;
}

function buildKeywordIndex(cards) {
  const index = {};

  for (const [agentId, card] of Object.entries(cards)) {
    for (const cap of card.capabilities) {
      for (const keyword of cap.keywords) {
        const key = keyword.toLowerCase();
        if (!index[key]) {
          index[key] = [];
        }
        // Avoid duplicates
        if (!index[key].some(e => e.agent_id === agentId && e.task_type === cap.task_type)) {
          index[key].push({
            agent_id: agentId,
            task_type: cap.task_type,
            confidence: cap.confidence
          });
        }
      }
    }
  }

  // Sort each keyword by confidence descending
  for (const keyword of Object.keys(index)) {
    index[keyword].sort((a, b) => b.confidence - a.confidence);
  }

  return index;
}

function buildCategoryIndex(cards) {
  const index = {};

  for (const [agentId, card] of Object.entries(cards)) {
    if (!index[card.category]) {
      index[card.category] = [];
    }
    index[card.category].push(agentId);
  }

  return index;
}

function buildDependencyGraph(cards) {
  const graph = {};

  for (const [agentId, card] of Object.entries(cards)) {
    graph[agentId] = card.dependencies || [];
  }

  return graph;
}

function main() {
  console.log('[A2A Registry Builder] Scanning agent cards...');

  const { cards, errors } = loadAgentCards();

  if (errors.length > 0) {
    console.error('[ERRORS]');
    errors.forEach(e => console.error(`  - ${e}`));
  }

  const agentCount = Object.keys(cards).length;
  console.log(`[OK] Found ${agentCount} agent cards`);

  const capabilityIndex = buildCapabilityIndex(cards);
  const keywordIndex = buildKeywordIndex(cards);
  const categoryIndex = buildCategoryIndex(cards);
  const dependencyGraph = buildDependencyGraph(cards);

  const registry = {
    version: "1.0.0",
    protocol: "a2a-file-based",
    generated_at: new Date().toISOString(),
    agent_count: agentCount,
    agents: cards,
    capability_index: capabilityIndex,
    keyword_index: keywordIndex,
    category_index: categoryIndex,
    dependency_graph: dependencyGraph
  };

  fs.writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2));
  console.log(`[OK] Registry written to ${REGISTRY_PATH}`);
  console.log(`     - ${Object.keys(capabilityIndex).length} task types indexed`);
  console.log(`     - ${Object.keys(keywordIndex).length} keywords indexed`);
  console.log(`     - ${Object.keys(categoryIndex).length} categories`);
}

main();
