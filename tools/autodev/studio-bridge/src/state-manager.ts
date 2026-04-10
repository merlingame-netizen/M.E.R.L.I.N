import { readFile, writeFile, rename, appendFile, mkdir } from 'fs/promises';
import { join, dirname } from 'path';
import type {
  FeatureTask,
  AgentStatus,
  CloudSessionsState,
  AgentPerformance,
  EvolutionEntry,
  CycleReport,
  DashboardEvent,
} from './types.js';

export class StateManager {
  private statusDir: string;

  constructor(statusDir: string) {
    this.statusDir = statusDir;
  }

  // --- Read Methods ---

  async readFeatureQueue(): Promise<FeatureTask[]> {
    try {
      const raw = await readFile(
        join(this.statusDir, 'feature_queue.json'),
        'utf-8',
      );
      const parsed = JSON.parse(raw);
      return parsed.tasks || [];
    } catch {
      return [];
    }
  }

  async readAgentStatus(): Promise<AgentStatus> {
    try {
      const raw = await readFile(
        join(this.statusDir, 'agent_status.json'),
        'utf-8',
      );
      return JSON.parse(raw);
    } catch {
      return {
        agents: {},
        parallel_slots: { max: 3, used: 0, agents_in_parallel: [] },
        active_loops: [],
        blocked_reason: null,
      };
    }
  }

  async readCloudSessions(): Promise<CloudSessionsState> {
    try {
      const raw = await readFile(
        join(this.statusDir, 'cloud_sessions.json'),
        'utf-8',
      );
      return JSON.parse(raw);
    } catch {
      return {
        version: '1.0.0',
        active_sessions: [],
        completed_sessions: [],
        daily_stats: {
          date: new Date().toISOString().slice(0, 10),
          sessions_started: 0,
          sessions_completed: 0,
          cycles_completed: 0,
        },
      };
    }
  }

  async readAgentPerformance(): Promise<AgentPerformance> {
    try {
      const raw = await readFile(
        join(this.statusDir, 'agent_performance.json'),
        'utf-8',
      );
      return JSON.parse(raw);
    } catch {
      return {};
    }
  }

  async readEvolutionLog(): Promise<EvolutionEntry[]> {
    try {
      const raw = await readFile(
        join(this.statusDir, 'evolution_log.json'),
        'utf-8',
      );
      return JSON.parse(raw);
    } catch {
      return [];
    }
  }

  // --- Write Methods ---

  async writeFeatureQueue(tasks: FeatureTask[]): Promise<void> {
    await this.atomicWrite(join(this.statusDir, 'feature_queue.json'), {
      version: '1.0.0',
      updated_at: new Date().toISOString(),
      tasks,
    });
  }

  async writeAgentStatus(status: AgentStatus): Promise<void> {
    await this.atomicWrite(
      join(this.statusDir, 'agent_status.json'),
      status,
    );
  }

  async writeCloudSessions(sessions: CloudSessionsState): Promise<void> {
    await this.atomicWrite(
      join(this.statusDir, 'cloud_sessions.json'),
      sessions,
    );
  }

  async writeAgentPerformance(perf: AgentPerformance): Promise<void> {
    await this.atomicWrite(
      join(this.statusDir, 'agent_performance.json'),
      perf,
    );
  }

  async appendEvolutionLog(entry: EvolutionEntry): Promise<void> {
    const log = await this.readEvolutionLog();
    log.push(entry);
    await this.atomicWrite(join(this.statusDir, 'evolution_log.json'), log);
  }

  async writeCycleReport(report: CycleReport): Promise<void> {
    const logsDir = join(this.statusDir, 'cycle_logs');
    try {
      await mkdir(logsDir, { recursive: true });
    } catch {
      // directory may already exist
    }
    const filePath = join(logsDir, `${report.cycleId}.json`);
    await this.atomicWrite(filePath, report);
  }

  // --- Dashboard Events ---

  async emitEvent(event: DashboardEvent): Promise<void> {
    const eventsPath = join(this.statusDir, 'events.jsonl');
    const line = JSON.stringify(event) + '\n';
    try {
      await appendFile(eventsPath, line, 'utf-8');
    } catch {
      // If file doesn't exist yet, create it
      await writeFile(eventsPath, line, 'utf-8');
    }
  }

  // --- Atomic Write Helper ---

  private async atomicWrite(
    filePath: string,
    data: unknown,
  ): Promise<void> {
    const dir = dirname(filePath);
    try {
      await mkdir(dir, { recursive: true });
    } catch {
      // directory may already exist
    }
    const tmpPath = filePath + '.tmp';
    const content = JSON.stringify(data, null, 2);
    await writeFile(tmpPath, content, 'utf-8');
    await rename(tmpPath, filePath);
  }
}
