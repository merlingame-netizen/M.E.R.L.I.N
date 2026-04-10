import { readFile, readdir } from 'fs/promises';
import { join, basename } from 'path';
import type { AgentDefinition, AgentCard, WorkOrder } from './types.js';

export class AgentCatalog {
  private agents: Map<string, AgentDefinition> = new Map();
  private cards: Map<string, AgentCard> = new Map();

  constructor(
    private agentsDir: string,
    private agentCardsDir: string,
  ) {}

  async load(): Promise<void> {
    // 1. Read all .md agent files
    await this.loadAgentDefinitions();

    // 2. Read all .json agent cards
    await this.loadAgentCards();
  }

  private async loadAgentDefinitions(): Promise<void> {
    let files: string[];
    try {
      files = await readdir(this.agentsDir);
    } catch {
      console.warn(`[CATALOG] Could not read agents dir: ${this.agentsDir}`);
      return;
    }

    const mdFiles = files.filter((f) => f.endsWith('.md'));

    for (const file of mdFiles) {
      const filePath = join(this.agentsDir, file);
      try {
        const content = await readFile(filePath, 'utf-8');
        const id = basename(file, '.md');
        const name = this.parseAgentName(content, id);
        const category = this.inferCategory(id, content);
        const autoActivation = this.parseAutoActivation(content);

        this.agents.set(id, {
          id,
          name,
          filePath,
          category,
          instructions: content,
          autoActivation,
        });
      } catch {
        console.warn(`[CATALOG] Failed to read agent file: ${file}`);
      }
    }
  }

  private async loadAgentCards(): Promise<void> {
    let files: string[];
    try {
      files = await readdir(this.agentCardsDir);
    } catch {
      console.warn(
        `[CATALOG] Could not read agent cards dir: ${this.agentCardsDir}`,
      );
      return;
    }

    const jsonFiles = files.filter(
      (f) =>
        f.endsWith('.json') &&
        f !== '_schema.json' &&
        f !== '_registry.json',
    );

    for (const file of jsonFiles) {
      const filePath = join(this.agentCardsDir, file);
      try {
        const raw = await readFile(filePath, 'utf-8');
        const card: AgentCard = JSON.parse(raw);
        if (card.id) {
          this.cards.set(card.id, card);
        }
      } catch {
        console.warn(`[CATALOG] Failed to parse agent card: ${file}`);
      }
    }
  }

  private parseAgentName(content: string, fallbackId: string): string {
    const headerMatch = content.match(/^#\s+(.+)$/m);
    if (headerMatch) {
      return headerMatch[1].trim();
    }
    // Fallback: convert id to title case
    return fallbackId
      .replace(/[-_]/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }

  private inferCategory(id: string, content: string): string {
    const lower = `${id} ${content.slice(0, 500)}`.toLowerCase();

    const categoryKeywords: Record<string, string[]> = {
      core: ['gameplay', 'mechanic', 'engine', 'system', 'gdscript', 'godot'],
      'ui-ux': ['ui', 'ux', 'interface', 'visual', 'layout', 'theme'],
      creative: ['art', 'shader', 'animation', 'particle', '3d', 'model'],
      narrative: ['narrative', 'story', 'dialogue', 'lore', 'writing'],
      quality: [
        'test',
        'qa',
        'review',
        'lint',
        'validate',
        'security',
        'audit',
      ],
      ops: [
        'deploy',
        'ci',
        'build',
        'export',
        'pipeline',
        'git',
        'devops',
      ],
      llm: ['llm', 'ai', 'ollama', 'brain', 'prompt', 'rag'],
      orchestration: [
        'orchestrat',
        'dispatch',
        'autodev',
        'studio',
        'bridge',
      ],
      knowledge: ['knowledge', 'doc', 'bible', 'reference', 'memory'],
    };

    for (const [category, keywords] of Object.entries(categoryKeywords)) {
      if (keywords.some((kw) => lower.includes(kw))) {
        return category;
      }
    }
    return 'general';
  }

  private parseAutoActivation(content: string): string[] {
    // Look for auto-activation keywords in the .md content
    const match = content.match(
      /auto[_-]?activat(?:ion|e)[:\s]*(.+)/i,
    );
    if (match) {
      return match[1]
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean);
    }
    return [];
  }

  // --- Query Methods ---

  getAgent(id: string): AgentDefinition | undefined {
    return this.agents.get(id);
  }

  getCard(id: string): AgentCard | undefined {
    return this.cards.get(id);
  }

  getAllAgents(): AgentDefinition[] {
    return Array.from(this.agents.values());
  }

  getAgentsByCategory(category: string): AgentDefinition[] {
    return this.getAllAgents().filter((a) => a.category === category);
  }

  getAgentsWithCards(): Array<{ agent: AgentDefinition; card: AgentCard }> {
    const results: Array<{ agent: AgentDefinition; card: AgentCard }> = [];
    for (const [id, agent] of this.agents) {
      const card = this.cards.get(id);
      if (card) {
        results.push({ agent, card });
      }
    }
    return results;
  }

  getAgentsWithoutCards(): AgentDefinition[] {
    return this.getAllAgents().filter((a) => !this.cards.has(a.id));
  }

  // --- Prompt Builder ---

  buildAgentPrompt(agentId: string, workOrder: WorkOrder): string {
    const agent = this.agents.get(agentId);
    if (!agent) {
      throw new Error(`Agent not found: ${agentId}`);
    }

    return [
      `# Agent Instructions: ${agent.name}`,
      '',
      agent.instructions,
      '',
      '---',
      '',
      '# Work Order',
      `- ID: ${workOrder.id}`,
      `- Priority: ${workOrder.priority}`,
      `- Tasks: ${workOrder.taskIds.join(', ')}`,
      '',
      '## Assignment',
      workOrder.prompt,
      '',
      '## Expected Outputs',
      ...workOrder.expectedOutputs.map((o) => `- ${o}`),
      '',
      '## Project Root',
      'c:/Users/PGNK2128/Godot-MCP',
      '',
      '## Constraints',
      '- Run validate.bat after code changes',
      '- Follow GDScript conventions: snake_case, type hints, no := with CONST',
      '- Commit changes with conventional commit format',
    ].join('\n');
  }
}
