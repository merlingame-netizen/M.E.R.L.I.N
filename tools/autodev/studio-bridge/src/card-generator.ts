import { readFile, writeFile, readdir, mkdir } from 'fs/promises';
import { join, basename } from 'path';
import type { AgentCard, AgentCapability } from './types.js';

interface GenerationResult {
  generated: number;
  skipped: number;
  errors: string[];
}

export class CardGenerator {
  constructor(
    private agentsDir: string,
    private cardsDir: string,
  ) {}

  async generateAll(): Promise<GenerationResult> {
    const result: GenerationResult = { generated: 0, skipped: 0, errors: [] };

    // Read existing cards
    const existingCards = new Set<string>();
    try {
      const cardFiles = await readdir(this.cardsDir);
      for (const f of cardFiles) {
        if (f.endsWith('.json') && !f.startsWith('_')) {
          existingCards.add(basename(f, '.json'));
        }
      }
    } catch {
      await mkdir(this.cardsDir, { recursive: true });
    }

    // Read all agent .md files
    let mdFiles: string[];
    try {
      const files = await readdir(this.agentsDir);
      mdFiles = files.filter((f) => f.endsWith('.md') && f !== 'AGENTS.md');
    } catch {
      result.errors.push(`Cannot read agents dir: ${this.agentsDir}`);
      return result;
    }

    for (const file of mdFiles) {
      const id = basename(file, '.md');

      if (existingCards.has(id)) {
        result.skipped++;
        continue;
      }

      try {
        const content = await readFile(join(this.agentsDir, file), 'utf-8');
        const card = this.parseAgentToCard(id, content);
        const cardPath = join(this.cardsDir, `${id}.json`);
        await writeFile(cardPath, JSON.stringify(card, null, 2), 'utf-8');
        result.generated++;
      } catch (err) {
        result.errors.push(`${id}: ${err}`);
      }
    }

    return result;
  }

  async rebuildRegistry(): Promise<number> {
    const cards: AgentCard[] = [];

    let files: string[];
    try {
      files = await readdir(this.cardsDir);
    } catch {
      return 0;
    }

    for (const file of files) {
      if (!file.endsWith('.json') || file.startsWith('_')) continue;
      try {
        const raw = await readFile(join(this.cardsDir, file), 'utf-8');
        cards.push(JSON.parse(raw));
      } catch {
        // skip invalid
      }
    }

    // Sort by category then name
    cards.sort((a, b) => a.category.localeCompare(b.category) || a.name.localeCompare(b.name));

    const registry = {
      version: '2.0.0',
      generated_at: new Date().toISOString(),
      total_agents: cards.length,
      by_category: this.groupByCategory(cards),
      agents: cards.map((c) => ({
        id: c.id,
        name: c.name,
        category: c.category,
        capabilities: c.capabilities.map((cap) => cap.task_type),
        cost_profile: c.cost_profile || 'sonnet',
      })),
    };

    await writeFile(
      join(this.cardsDir, '_registry.json'),
      JSON.stringify(registry, null, 2),
      'utf-8',
    );

    return cards.length;
  }

  private parseAgentToCard(id: string, content: string): AgentCard {
    const name = this.extractName(content, id);
    const category = this.inferCategory(id, content);
    const keywords = this.extractKeywords(content);
    const capabilities = this.buildCapabilities(id, content, keywords);
    const fileScope = this.extractFileScope(content);
    const costProfile = this.inferCostProfile(content);

    return {
      id,
      name,
      version: '1.0.0',
      description: this.extractDescription(content, name),
      agent_file: `.claude/agents/${id}.md`,
      category,
      capabilities,
      inputs: [
        { name: 'task_description', type: 'text', required: true },
        { name: 'relevant_files', type: 'file', required: false },
      ],
      outputs: [
        { name: 'code_changes', type: 'artifact' },
        { name: 'summary', type: 'text' },
      ],
      file_scope: fileScope.length > 0 ? fileScope : undefined,
      cost_profile: costProfile,
    };
  }

  private extractName(content: string, fallbackId: string): string {
    const match = content.match(/^#\s+(.+)$/m);
    return match ? match[1].trim() : this.titleCase(fallbackId);
  }

  private extractDescription(content: string, name: string): string {
    // Look for a line after the first header that isn't another header
    const lines = content.split('\n');
    let foundHeader = false;
    for (const line of lines) {
      if (line.startsWith('# ')) {
        foundHeader = true;
        continue;
      }
      if (foundHeader && line.trim() && !line.startsWith('#') && !line.startsWith('>')) {
        return line.trim().slice(0, 200);
      }
      if (foundHeader && line.startsWith('>')) {
        return line.replace(/^>\s*/, '').trim().slice(0, 200);
      }
    }
    return `Agent: ${name}`;
  }

  private inferCategory(id: string, content: string): AgentCard['category'] {
    const lower = `${id} ${content.slice(0, 800)}`.toLowerCase();

    const rules: Array<{ category: AgentCard['category']; patterns: string[] }> = [
      { category: 'orchestration', patterns: ['orchestrat', 'dispatch', 'studio', 'bridge', 'autodev'] },
      { category: 'quality', patterns: ['qa_', 'test', 'review', 'lint', 'validate', 'security', 'audit', 'debug'] },
      { category: 'narrative', patterns: ['narrative', 'story', 'dialogue', 'lore', 'writing', 'card_'] },
      { category: 'creative', patterns: ['art', 'shader', 'animation', 'particle', '3d', 'model', 'visual', 'vis_'] },
      { category: 'ui-ux', patterns: ['ui_', 'ux_', 'interface', 'layout', 'theme', 'hud'] },
      { category: 'llm', patterns: ['llm', 'ai_', 'ollama', 'brain', 'prompt', 'rag'] },
      { category: 'ops', patterns: ['deploy', 'ci_', 'build', 'export', 'pipeline', 'devops', 'perf_'] },
      { category: 'knowledge', patterns: ['knowledge', 'doc_', 'bible', 'reference', 'memory'] },
      { category: 'core', patterns: ['gameplay', 'mechanic', 'engine', 'system', 'godot', 'gdscript'] },
    ];

    for (const rule of rules) {
      if (rule.patterns.some((p) => lower.includes(p))) {
        return rule.category;
      }
    }
    return 'core';
  }

  private extractKeywords(content: string): string[] {
    const keywords: string[] = [];

    // From AUTO-ACTIVATION section
    const activationMatch = content.match(/auto[_-]?activat(?:ion|e)[^:]*:\s*(.+)/i);
    if (activationMatch) {
      keywords.push(
        ...activationMatch[1]
          .split(/[,;|]/)
          .map((s) => s.trim().toLowerCase())
          .filter((s) => s.length > 2),
      );
    }

    // From ## Expertise or ## Role sections
    const expertiseMatch = content.match(/##\s*(?:Expertise|Role|Sp[eé]cialit[eé])\s*\n([\s\S]*?)(?=\n##|\n$)/i);
    if (expertiseMatch) {
      const words = expertiseMatch[1]
        .replace(/[-*]/g, '')
        .split(/[\s,;.()]+/)
        .map((w) => w.toLowerCase().trim())
        .filter((w) => w.length > 3 && !STOP_WORDS.has(w));
      keywords.push(...words.slice(0, 10));
    }

    return [...new Set(keywords)].slice(0, 15);
  }

  private buildCapabilities(id: string, content: string, keywords: string[]): AgentCapability[] {
    const mode = this.inferMode(id, content);
    const taskType = this.inferTaskType(id, content);

    const capabilities: AgentCapability[] = [
      {
        task_type: taskType,
        keywords: keywords.length > 0 ? keywords : [id.replace(/_/g, ' ')],
        confidence: keywords.length > 3 ? 0.7 : 0.5,
        mode,
      },
    ];

    return capabilities;
  }

  private inferMode(id: string, content: string): AgentCapability['mode'] {
    const lower = `${id} ${content.slice(0, 500)}`.toLowerCase();
    if (lower.includes('review') || lower.includes('audit') || lower.includes('check')) return 'review';
    if (lower.includes('generat') || lower.includes('creat') || lower.includes('write')) return 'generate';
    if (lower.includes('analyz') || lower.includes('scan') || lower.includes('detect')) return 'analyze';
    if (lower.includes('valid') || lower.includes('test') || lower.includes('verif')) return 'validate';
    if (lower.includes('orchestrat') || lower.includes('dispatch') || lower.includes('coordinat')) return 'orchestrate';
    if (lower.includes('doc') || lower.includes('reference') || lower.includes('knowledge')) return 'reference';
    return 'build';
  }

  private inferTaskType(id: string, content: string): string {
    const lower = id.toLowerCase();
    // Extract primary domain from agent id
    const prefixes = ['qa_', 'perf_', 'ux_', 'vis_', 'ui_', 'ai_', 'doc_', 'ci_'];
    for (const prefix of prefixes) {
      if (lower.startsWith(prefix)) {
        return lower.slice(prefix.length).replace(/_/g, ' ');
      }
    }
    return lower.replace(/_/g, ' ').replace(/[-]/g, ' ');
  }

  private extractFileScope(content: string): string[] {
    const scopes: string[] = [];
    // Look for file path patterns in the content
    const pathMatches = content.matchAll(/`((?:scripts|addons|scenes|tools|docs)\/[^`]+)`/g);
    for (const match of pathMatches) {
      scopes.push(match[1]);
    }
    return [...new Set(scopes)].slice(0, 10);
  }

  private inferCostProfile(content: string): 'haiku' | 'sonnet' | 'opus' {
    const lower = content.toLowerCase();
    if (lower.includes('opus') || lower.includes('complex reasoning') || lower.includes('architect')) {
      return 'opus';
    }
    if (lower.includes('haiku') || lower.includes('lightweight') || lower.includes('simple')) {
      return 'haiku';
    }
    return 'sonnet';
  }

  private groupByCategory(cards: AgentCard[]): Record<string, number> {
    const counts: Record<string, number> = {};
    for (const card of cards) {
      counts[card.category] = (counts[card.category] || 0) + 1;
    }
    return counts;
  }

  private titleCase(str: string): string {
    return str
      .replace(/[-_]/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }
}

const STOP_WORDS = new Set([
  'the', 'and', 'for', 'that', 'this', 'with', 'from', 'will', 'have', 'been',
  'when', 'which', 'their', 'each', 'should', 'could', 'would', 'about', 'into',
  'more', 'other', 'than', 'then', 'these', 'those', 'also', 'must', 'does',
  'using', 'used', 'make', 'like', 'just', 'over', 'such', 'take', 'only',
  'very', 'after', 'before', 'between', 'through', 'during', 'without',
]);
