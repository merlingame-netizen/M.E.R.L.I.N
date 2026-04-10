import { StateManager } from './state-manager.js';
import { AgentCatalog } from './agent-catalog.js';
import { AgentEvolution } from './agent-evolution.js';
import type {
  BridgeConfig,
  CycleState,
  OrchestratorState,
  CyclePhase,
  ScanResult,
  DomainScore,
  FeatureTask,
  WorkOrder,
  CycleReport,
  ValidationResult,
} from './types.js';

export class Orchestrator {
  private stateManager: StateManager;
  private catalog: AgentCatalog;
  private evolution: AgentEvolution;
  private currentCycle: CycleState | null = null;

  constructor(private config: BridgeConfig) {
    this.stateManager = new StateManager(config.statusDir);
    this.catalog = new AgentCatalog(config.agentsDir, config.agentCardsDir);
    this.evolution = new AgentEvolution(this.stateManager, this.catalog);
  }

  async initialize(): Promise<void> {
    await this.catalog.load();
    console.log(`[INIT] Loaded ${this.catalog.getAllAgents().length} agents`);
    const withCards = this.catalog.getAgentsWithCards().length;
    const withoutCards = this.catalog.getAgentsWithoutCards().length;
    console.log(
      `[INIT] Agent cards: ${withCards} with, ${withoutCards} without`,
    );
  }

  async runCycle(): Promise<void> {
    const cycleId = this.generateCycleId();
    this.currentCycle = this.createCycleState(cycleId);
    console.log(`\n[CYCLE ${cycleId}] Starting autonomous cycle`);

    try {
      await this.transition('SCAN');
      await this.executeScan();

      await this.transition('PLAN');
      await this.executePlan();

      await this.transition('DISPATCH');
      await this.executeDispatch();

      await this.transition('COLLECT');
      await this.executeCollect();

      await this.transition('VALIDATE');
      await this.executeValidate();

      await this.transition('TEST');
      await this.executeTest();

      if (this.config.autoEvolve) {
        await this.transition('EVOLVE');
        await this.executeEvolve();
      }

      await this.transition('REPORT');
      await this.executeReport();

      console.log(`[CYCLE ${cycleId}] Completed successfully`);
    } catch (err) {
      console.error(`[CYCLE ${cycleId}] Failed:`, err);
      await this.stateManager.emitEvent({
        type: 'alert',
        timestamp: new Date().toISOString(),
        data: {
          level: 'ERROR',
          message: `Cycle ${cycleId} failed: ${err}`,
        },
      });
    }
  }

  // --- State Machine ---

  private getCycle(): CycleState {
    if (!this.currentCycle) throw new Error('No active cycle — call runCycle() first');
    return this.currentCycle;
  }

  private async transition(newState: OrchestratorState): Promise<void> {
    const cycle = this.getCycle();
    const prev = cycle.state;
    cycle.state = newState;

    // Complete previous phase
    const prevPhase = cycle.phases.find(
      (p) => p.name === prev && p.status === 'running',
    );
    if (prevPhase) {
      prevPhase.status = 'completed';
      prevPhase.completedAt = new Date().toISOString();
    }

    // Start new phase
    cycle.phases.push({
      name: newState,
      startedAt: new Date().toISOString(),
      status: 'running',
    });

    console.log(`[STATE] ${prev} -> ${newState}`);
    await this.stateManager.emitEvent({
      type: 'state_change',
      timestamp: new Date().toISOString(),
      data: {
        from: prev,
        to: newState,
        cycleId: cycle.cycleId,
      },
    });
  }

  // --- Phase Implementations ---

  private async executeScan(): Promise<void> {
    console.log('[SCAN] Analyzing project state...');
    const tasks = await this.stateManager.readFeatureQueue();
    const pending = tasks.filter((t) => t.status === 'pending');
    const blocked = tasks.filter((t) => t.status === 'blocked');

    // Score domains based on pending tasks
    const domainScores = this.scoreDomains(pending);

    this.getCycle().scanResults = {
      domains: domainScores,
      pendingTasks: pending.length,
      blockedTasks: blocked.length,
      recommendedFocus: domainScores[0]?.domain || 'none',
    };

    console.log(
      `[SCAN] Found ${pending.length} pending, ${blocked.length} blocked tasks`,
    );
    console.log(
      `[SCAN] Recommended focus: ${this.getCycle().scanResults?.recommendedFocus ?? 'none'}`,
    );
  }

  private async executePlan(): Promise<void> {
    console.log('[PLAN] Creating work orders...');
    const tasks = await this.stateManager.readFeatureQueue();
    const pending = tasks
      .filter((t) => t.status === 'pending')
      .slice(0, this.config.maxParallelAgents);

    for (const task of pending) {
      const workOrder = this.createWorkOrder(task);
      this.getCycle().workOrders.push(workOrder);
      console.log(
        `[PLAN] Work order ${workOrder.id} -> ${workOrder.agentId} for "${task.title}"`,
      );
    }

    if (this.getCycle().workOrders.length === 0) {
      console.log('[PLAN] No pending tasks. Cycle will be short.');
    }
  }

  private async executeDispatch(): Promise<void> {
    if (this.config.dryRun) {
      console.log('[DISPATCH] DRY RUN — skipping agent dispatch');
      for (const wo of this.getCycle().workOrders) {
        wo.status = 'completed';
        wo.result = {
          artifacts: [],
          summary: 'Dry run — no execution',
          filesModified: [],
          errors: [],
          durationMs: 0,
        };
      }
      return;
    }
    // TODO: Implement real dispatch via Claude Code Agent tool
    console.log(
      `[DISPATCH] Would dispatch ${this.getCycle().workOrders.length} work orders`,
    );
  }

  private async executeCollect(): Promise<void> {
    // TODO: Poll and collect results from dispatched agents
    console.log('[COLLECT] Collecting results...');
  }

  private async executeValidate(): Promise<void> {
    if (this.config.dryRun) {
      console.log('[VALIDATE] DRY RUN — skipping validation');
      this.getCycle().validationResult = {
        passed: true,
        errors: 0,
        warnings: 0,
        details: 'Dry run',
      };
      return;
    }
    // TODO: Run validate.bat and parse results
    console.log('[VALIDATE] Running validation...');
  }

  private async executeTest(): Promise<void> {
    // TODO: Run tests if available
    console.log('[TEST] Running tests...');
  }

  private async executeEvolve(): Promise<void> {
    console.log('[EVOLVE] Checking agent evolution...');
    const result = await this.evolution.runEvolutionCheck();

    if (result.created.length > 0) {
      console.log(`[EVOLVE] New agents proposed: ${result.created.join(', ')}`);
    }
    if (result.improved.length > 0) {
      console.log(`[EVOLVE] Agents flagged for improvement: ${result.improved.join(', ')}`);
    }
    if (result.constrained.length > 0) {
      console.log(`[EVOLVE] Agents needing constraints: ${result.constrained.join(', ')}`);
    }
    if (result.created.length === 0 && result.improved.length === 0 && result.constrained.length === 0) {
      console.log('[EVOLVE] All agents performing within thresholds');
    }
  }

  private async executeReport(): Promise<void> {
    const cycle = this.getCycle();
    const report: CycleReport = {
      cycleId: cycle.cycleId,
      duration_seconds: Math.round(
        (Date.now() - new Date(cycle.startedAt).getTime()) / 1000,
      ),
      tasksCompleted: cycle.workOrders.filter(
        (wo) => wo.status === 'completed',
      ).length,
      tasksFailed: cycle.workOrders.filter((wo) => wo.status === 'failed')
        .length,
      agentsUsed: [
        ...new Set(cycle.workOrders.map((wo) => wo.agentId)),
      ],
      filesModified: cycle.workOrders.flatMap(
        (wo) => wo.result?.filesModified || [],
      ),
      validationPassed: cycle.validationResult?.passed ?? false,
      summary: `Cycle ${cycle.cycleId}: ${cycle.workOrders.length} work orders processed`,
    };

    await this.stateManager.writeCycleReport(report);
    await this.stateManager.emitEvent({
      type: 'cycle_update',
      timestamp: new Date().toISOString(),
      data: report as unknown as Record<string, unknown>,
    });

    console.log(`[REPORT] Cycle completed in ${report.duration_seconds}s`);
    console.log(
      `[REPORT] Tasks: ${report.tasksCompleted} completed, ${report.tasksFailed} failed`,
    );
    console.log(`[REPORT] Agents used: ${report.agentsUsed.join(', ')}`);
  }

  // --- Helpers ---

  private scoreDomains(tasks: FeatureTask[]): DomainScore[] {
    const domainMap: Record<string, { score: number; reasons: string[] }> =
      {};
    const domainKeywords: Record<string, string[]> = {
      gameplay: [
        'game',
        'mechanic',
        'rule',
        'ogham',
        'faction',
        'card',
        'effect',
        'reputation',
      ],
      visual: [
        'shader',
        'animation',
        'particle',
        'visual',
        'ui',
        'scene',
        'render',
      ],
      audio: ['audio', 'sound', 'music', 'sfx', 'ambiance'],
      narrative: [
        'narrative',
        'story',
        'dialogue',
        'lore',
        'card text',
        'merlin',
      ],
      qa: ['test', 'bug', 'fix', 'regression', 'smoke', 'qa'],
      performance: ['perf', 'optimize', 'memory', 'fps', 'loading'],
      content: ['content', 'asset', 'biome', 'creature', 'world'],
    };

    for (const task of tasks) {
      const text = `${task.title} ${task.description}`.toLowerCase();
      for (const [domain, keywords] of Object.entries(domainKeywords)) {
        const matches = keywords.filter((k) => text.includes(k));
        if (matches.length > 0) {
          if (!domainMap[domain]) {
            domainMap[domain] = { score: 0, reasons: [] };
          }
          domainMap[domain].score += matches.length * task.priority;
          domainMap[domain].reasons.push(task.title);
        }
      }
    }

    return Object.entries(domainMap)
      .map(([domain, data]) => ({ domain, ...data }))
      .sort((a, b) => b.score - a.score);
  }

  private createWorkOrder(task: FeatureTask): WorkOrder {
    const agentId = task.agent || 'godot_expert';
    return {
      id: `WO-${new Date().toISOString().slice(0, 10)}-${crypto.randomUUID().slice(0, 8)}`,
      cycleId: this.getCycle().cycleId,
      taskIds: [task.id],
      agentId,
      priority:
        task.priority <= 1
          ? 'CRITICAL'
          : task.priority <= 3
            ? 'HIGH'
            : task.priority <= 5
              ? 'MEDIUM'
              : 'LOW',
      prompt: `Task: ${task.title}\n\nDescription: ${task.description}\n\nFiles: ${(task.files || []).join(', ')}`,
      model: 'sonnet',
      isolation: 'worktree',
      expectedOutputs: ['code changes', 'summary report'],
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
  }

  private generateCycleId(): string {
    const date = new Date().toISOString().slice(0, 10);
    const seq = crypto.randomUUID().slice(0, 8);
    return `CYCLE-${date}-${seq}`;
  }

  private createCycleState(cycleId: string): CycleState {
    return {
      cycleId,
      state: 'IDLE',
      startedAt: new Date().toISOString(),
      phases: [
        {
          name: 'IDLE',
          startedAt: new Date().toISOString(),
          status: 'running',
        },
      ],
      workOrders: [],
    };
  }

  async printStatus(): Promise<void> {
    const tasks = await this.stateManager.readFeatureQueue();
    const status = await this.stateManager.readAgentStatus();
    const sessions = await this.stateManager.readCloudSessions();

    console.log('\n=== MERLIN Studio Bridge Status ===');
    console.log(`Agents loaded: ${this.catalog.getAllAgents().length}`);
    console.log(
      `Pending tasks: ${tasks.filter((t) => t.status === 'pending').length}`,
    );
    console.log(`Active sessions: ${sessions.active_sessions.length}`);
    console.log(
      `Parallel slots: ${status.parallel_slots.used}/${status.parallel_slots.max}`,
    );
    console.log(
      `Today: ${sessions.daily_stats.sessions_completed} sessions completed`,
    );
  }

  async printHistory(): Promise<void> {
    // TODO: Read cycle reports from cycle_logs/
    console.log('[HISTORY] Not yet implemented');
  }
}
