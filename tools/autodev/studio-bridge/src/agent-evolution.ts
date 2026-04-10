import type {
  AgentPerformance,
  EvolutionEntry,
  AgentDefinition,
  AgentCard,
  AgentCapability,
} from './types.js';
import { StateManager } from './state-manager.js';
import { AgentCatalog } from './agent-catalog.js';

interface GapRecord {
  domain: string;
  taskDescription: string;
  keywords: string[];
  timestamp: string;
}

interface EvolutionConfig {
  gapThreshold: number;        // min gaps before auto-create (default 3)
  passRateFloor: number;       // below this → trigger improvement (default 0.7)
  overrideRateCeiling: number; // above this → add constraints (default 0.2)
  minTasksForEval: number;     // min tasks before evaluating (default 10)
}

const DEFAULT_CONFIG: EvolutionConfig = {
  gapThreshold: 3,
  passRateFloor: 0.7,
  overrideRateCeiling: 0.2,
  minTasksForEval: 10,
};

export class AgentEvolution {
  private stateManager: StateManager;
  private catalog: AgentCatalog;
  private gaps: GapRecord[] = [];
  private config: EvolutionConfig;

  constructor(
    stateManager: StateManager,
    catalog: AgentCatalog,
    config: Partial<EvolutionConfig> = {},
  ) {
    this.stateManager = stateManager;
    this.catalog = catalog;
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  // --- Gap Detection ---

  recordGap(domain: string, taskDescription: string, keywords: string[]): void {
    this.gaps.push({
      domain,
      taskDescription,
      keywords,
      timestamp: new Date().toISOString(),
    });
  }

  getGapsByDomain(): Map<string, GapRecord[]> {
    const byDomain = new Map<string, GapRecord[]>();
    for (const gap of this.gaps) {
      const existing = byDomain.get(gap.domain) || [];
      existing.push(gap);
      byDomain.set(gap.domain, existing);
    }
    return byDomain;
  }

  getDomainsNeedingAgents(): string[] {
    const byDomain = this.getGapsByDomain();
    const result: string[] = [];
    for (const [domain, gaps] of byDomain) {
      if (gaps.length >= this.config.gapThreshold) {
        result.push(domain);
      }
    }
    return result;
  }

  // --- Agent Creation ---

  async generateAgentSpec(domain: string): Promise<{
    agentId: string;
    mdContent: string;
    cardJson: AgentCard;
  }> {
    const gaps = this.getGapsByDomain().get(domain) || [];
    const allKeywords = [...new Set(gaps.flatMap((g) => g.keywords))];
    const taskExamples = gaps.map((g) => g.taskDescription).slice(0, 5);

    const agentId = `auto_${domain.toLowerCase().replace(/\s+/g, '_')}`;
    const agentName = `Auto-Generated ${this.titleCase(domain)} Specialist`;

    // Generate .md content following existing agent template
    const mdContent = this.generateAgentMd(agentId, agentName, domain, allKeywords, taskExamples);

    // Generate agent card JSON
    const cardJson = this.generateAgentCard(agentId, agentName, domain, allKeywords);

    return { agentId, mdContent, cardJson };
  }

  private generateAgentMd(
    id: string,
    name: string,
    domain: string,
    keywords: string[],
    taskExamples: string[],
  ): string {
    return [
      `# ${name}`,
      '',
      `> Auto-generated agent for ${domain} domain.`,
      `> Created by Agent Evolution system on ${new Date().toISOString().slice(0, 10)}.`,
      '',
      '## Role',
      `Specialist agent for ${domain}-related tasks in the M.E.R.L.I.N. game project.`,
      '',
      '## AUTO-ACTIVATION RULE',
      `Activate when the task involves: ${keywords.join(', ')}.`,
      '',
      '## Expertise',
      `- ${domain} implementation and optimization`,
      '- M.E.R.L.I.N. game architecture (Godot 4.x)',
      '- GDScript coding conventions (snake_case, type hints)',
      '',
      '## Example Tasks',
      ...taskExamples.map((t) => `- ${t}`),
      '',
      '## Workflow',
      '1. Read the task description and relevant files',
      '2. Understand the existing code patterns in the project',
      '3. Implement changes following GDScript/TypeScript conventions',
      '4. Validate with validate.bat',
      '5. Report results with summary of changes',
      '',
      '## Constraints',
      '- Follow GAME_DESIGN_BIBLE.md v2.4 as source of truth',
      '- Never break existing functionality',
      '- Keep files under 400 lines, functions under 50 lines',
      '- Use explicit type hints (never := with CONST)',
      '- All colors from MerlinVisual.PALETTE',
    ].join('\n');
  }

  private generateAgentCard(
    id: string,
    name: string,
    domain: string,
    keywords: string[],
  ): AgentCard {
    const capability: AgentCapability = {
      task_type: domain,
      keywords,
      confidence: 0.6,
      mode: 'build',
    };

    return {
      id,
      name,
      version: '1.0.0',
      description: `Auto-generated specialist for ${domain} tasks`,
      agent_file: `.claude/agents/${id}.md`,
      category: this.inferCardCategory(domain),
      capabilities: [capability],
      inputs: [
        { name: 'task_description', type: 'text', required: true },
        { name: 'relevant_files', type: 'file', required: false },
      ],
      outputs: [
        { name: 'code_changes', type: 'artifact' },
        { name: 'summary', type: 'text' },
      ],
      cost_profile: 'sonnet',
    };
  }

  // --- Agent Improvement ---

  async evaluateAgents(): Promise<{
    needsImprovement: string[];
    needsConstraints: string[];
    healthy: string[];
  }> {
    const performance = await this.stateManager.readAgentPerformance();
    const needsImprovement: string[] = [];
    const needsConstraints: string[] = [];
    const healthy: string[] = [];

    for (const [agentId, metrics] of Object.entries(performance)) {
      const totalTasks = metrics.tasks_completed + metrics.tasks_failed;
      if (totalTasks < this.config.minTasksForEval) {
        continue; // Not enough data
      }

      if (metrics.validation_pass_rate < this.config.passRateFloor) {
        needsImprovement.push(agentId);
      } else if (metrics.human_override_rate > this.config.overrideRateCeiling) {
        needsConstraints.push(agentId);
      } else {
        healthy.push(agentId);
      }
    }

    return { needsImprovement, needsConstraints, healthy };
  }

  generateImprovementPrompt(agentId: string, metrics: AgentPerformance[string]): string {
    const agent = this.catalog.getAgent(agentId);
    if (!agent) {
      return `Agent ${agentId} not found in catalog.`;
    }

    return [
      `# Agent Improvement Task`,
      '',
      `## Agent: ${agent.name} (${agentId})`,
      '',
      '## Current Performance',
      `- Tasks completed: ${metrics.tasks_completed}`,
      `- Tasks failed: ${metrics.tasks_failed}`,
      `- Validation pass rate: ${(metrics.validation_pass_rate * 100).toFixed(1)}%`,
      `- Human override rate: ${(metrics.human_override_rate * 100).toFixed(1)}%`,
      `- Trend: ${metrics.trend}`,
      '',
      '## Current Instructions',
      '```',
      agent.instructions,
      '```',
      '',
      '## Task',
      'Rewrite the agent instructions to improve its performance.',
      'Focus on:',
      metrics.validation_pass_rate < this.config.passRateFloor
        ? '- Adding more specific validation steps and error checks'
        : '- Adding constraints to reduce human override decisions',
      '- Being more specific about GDScript/Godot conventions',
      '- Adding concrete examples of correct output',
      '',
      '## Output',
      'Return ONLY the new .md content for the agent file.',
      'Follow the same structure: Role, AUTO-ACTIVATION RULE, Expertise, Workflow, Constraints.',
    ].join('\n');
  }

  // --- Performance Tracking ---

  async updatePerformance(
    agentId: string,
    passed: boolean,
    durationMs: number,
    humanOverride: boolean,
  ): Promise<void> {
    const perf = await this.stateManager.readAgentPerformance();

    const existing = perf[agentId] || {
      tasks_completed: 0,
      tasks_failed: 0,
      validation_pass_rate: 1.0,
      human_override_rate: 0,
      avg_duration_ms: 0,
      last_task_at: '',
      trend: 'stable' as const,
    };

    if (passed) {
      existing.tasks_completed++;
    } else {
      existing.tasks_failed++;
    }

    const total = existing.tasks_completed + existing.tasks_failed;
    existing.validation_pass_rate = existing.tasks_completed / total;

    // Exponential moving average for override rate
    const alpha = 0.1;
    existing.human_override_rate =
      alpha * (humanOverride ? 1 : 0) + (1 - alpha) * existing.human_override_rate;

    // Running average for duration
    existing.avg_duration_ms =
      (existing.avg_duration_ms * (total - 1) + durationMs) / total;

    existing.last_task_at = new Date().toISOString();

    // Determine trend based on recent pass rate vs historical
    const recentWeight = Math.min(total, 10);
    if (existing.validation_pass_rate > 0.85 && recentWeight >= 5) {
      existing.trend = 'improving';
    } else if (existing.validation_pass_rate < 0.6 && recentWeight >= 5) {
      existing.trend = 'degrading';
    } else {
      existing.trend = 'stable';
    }

    perf[agentId] = existing;
    await this.stateManager.writeAgentPerformance(perf);
  }

  // --- Evolution Log ---

  async logEvolution(
    type: EvolutionEntry['type'],
    agentId: string,
    reason: string,
    details: string,
  ): Promise<void> {
    await this.stateManager.appendEvolutionLog({
      timestamp: new Date().toISOString(),
      type,
      agentId,
      reason,
      details,
    });
  }

  // --- Full Evolution Cycle ---

  async runEvolutionCheck(): Promise<{
    created: string[];
    improved: string[];
    constrained: string[];
  }> {
    const created: string[] = [];
    const improved: string[] = [];
    const constrained: string[] = [];

    // 1. Check for domains needing new agents
    const domainsNeedingAgents = this.getDomainsNeedingAgents();
    for (const domain of domainsNeedingAgents) {
      const spec = await this.generateAgentSpec(domain);
      created.push(spec.agentId);
      await this.logEvolution(
        'created',
        spec.agentId,
        `${this.gaps.length} gaps detected in ${domain} domain`,
        `Keywords: ${spec.cardJson.capabilities[0].keywords.join(', ')}`,
      );
      console.log(`[EVOLVE] Created agent spec: ${spec.agentId} for ${domain}`);
    }

    // 2. Evaluate existing agents
    const evaluation = await this.evaluateAgents();

    const perf = await this.stateManager.readAgentPerformance();

    for (const agentId of evaluation.needsImprovement) {
      improved.push(agentId);
      const rate = perf[agentId]?.validation_pass_rate ?? 0;
      await this.logEvolution(
        'improved',
        agentId,
        'Validation pass rate below threshold',
        `Rate: ${(rate * 100).toFixed(1)}%`,
      );
      console.log(`[EVOLVE] Agent ${agentId} flagged for improvement`);
    }

    for (const agentId of evaluation.needsConstraints) {
      constrained.push(agentId);
      const rate = perf[agentId]?.human_override_rate ?? 0;
      await this.logEvolution(
        'improved',
        agentId,
        'Human override rate above threshold',
        `Override rate: ${(rate * 100).toFixed(1)}%`,
      );
      console.log(`[EVOLVE] Agent ${agentId} flagged for additional constraints`);
    }

    return { created, improved, constrained };
  }

  // --- Helpers ---

  private titleCase(str: string): string {
    return str.replace(/\b\w/g, (c) => c.toUpperCase());
  }

  private inferCardCategory(domain: string): AgentCard['category'] {
    const lower = domain.toLowerCase();
    const mapping: Record<string, AgentCard['category']> = {
      gameplay: 'core',
      mechanic: 'core',
      engine: 'core',
      visual: 'creative',
      shader: 'creative',
      animation: 'creative',
      ui: 'ui-ux',
      ux: 'ui-ux',
      narrative: 'narrative',
      story: 'narrative',
      test: 'quality',
      qa: 'quality',
      deploy: 'ops',
      build: 'ops',
      llm: 'llm',
      ai: 'llm',
    };

    for (const [keyword, category] of Object.entries(mapping)) {
      if (lower.includes(keyword)) {
        return category;
      }
    }
    return 'core';
  }
}
