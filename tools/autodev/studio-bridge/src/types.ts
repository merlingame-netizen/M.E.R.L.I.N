// === M.E.R.L.I.N. Studio Bridge — Type Definitions ===

// State machine states
export type OrchestratorState =
  | 'IDLE'
  | 'SCAN'
  | 'PLAN'
  | 'DISPATCH'
  | 'COLLECT'
  | 'VALIDATE'
  | 'TEST'
  | 'EVOLVE'
  | 'REPORT';

// Agent from .md file
export interface AgentDefinition {
  id: string;                    // filename without .md
  name: string;                  // parsed from .md header
  filePath: string;              // absolute path to .md
  category: string;              // core, ui-ux, creative, etc.
  instructions: string;          // full .md content
  autoActivation?: string[];     // keywords that trigger this agent
}

// Agent card from JSON (A2A protocol)
export interface AgentCard {
  id: string;
  name: string;
  version: string;
  description: string;
  agent_file: string;
  category:
    | 'core'
    | 'ui-ux'
    | 'creative'
    | 'narrative'
    | 'quality'
    | 'ops'
    | 'llm'
    | 'orchestration'
    | 'knowledge';
  capabilities: AgentCapability[];
  inputs: AgentIO[];
  outputs: AgentIO[];
  file_scope?: string[];
  dependencies?: string[];
  cost_profile?: 'haiku' | 'sonnet' | 'opus';
  max_concurrent?: number;
}

export interface AgentCapability {
  task_type: string;
  keywords: string[];
  confidence: number;
  mode:
    | 'analyze'
    | 'build'
    | 'review'
    | 'generate'
    | 'validate'
    | 'orchestrate'
    | 'reference';
}

export interface AgentIO {
  name: string;
  type: 'text' | 'json' | 'file' | 'artifact';
  required?: boolean;
  description?: string;
}

// Work order dispatched to a subagent
export interface WorkOrder {
  id: string;                    // WO-YYYY-MM-DD-NNN
  cycleId: string;               // parent cycle reference
  taskIds: string[];             // references into feature_queue
  agentId: string;               // target agent
  priority: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  prompt: string;                // full prompt sent to Agent tool
  model?: 'haiku' | 'sonnet' | 'opus';
  isolation?: 'worktree';        // git worktree isolation
  expectedOutputs: string[];     // what to collect
  status: 'pending' | 'dispatched' | 'completed' | 'failed' | 'timeout';
  result?: WorkOrderResult;
  createdAt: string;
  completedAt?: string;
}

export interface WorkOrderResult {
  artifacts: Artifact[];
  summary: string;
  filesModified: string[];
  errors: string[];
  durationMs: number;
}

export interface Artifact {
  type: 'code' | 'report' | 'config' | 'card' | 'test';
  path?: string;                 // file path if applicable
  content: string;               // artifact content
  language?: string;             // for code artifacts
}

// Feature queue task (matches existing feature_queue.json schema)
export interface FeatureTask {
  id: string;
  phase: number;
  priority: number;
  status: 'pending' | 'in_progress' | 'completed' | 'blocked' | 'dispatched';
  title: string;
  agent?: string;
  files?: string[];
  description: string;
  completed_at?: string;
  notes?: string;
}

// Agent status (matches existing agent_status.json schema)
export interface AgentStatus {
  agents: Record<
    string,
    {
      state: 'idle' | 'running' | 'blocked' | 'error' | 'completed';
      current_task: string | null;
      cycle: number;
      session_id?: string;
      work_order_id?: string;
    }
  >;
  parallel_slots: {
    max: number;
    used: number;
    agents_in_parallel: string[];
  };
  active_loops: string[];
  blocked_reason: string | null;
}

// Cloud sessions tracking
export interface CloudSessionsState {
  version: string;
  active_sessions: CloudSession[];
  completed_sessions: CloudSession[];
  daily_stats: {
    date: string;
    sessions_started: number;
    sessions_completed: number;
    cycles_completed: number;
  };
}

export interface CloudSession {
  session_id: string;
  agent_id: string;
  work_order_id: string;
  task_ids: string[];
  started_at: string;
  completed_at?: string;
  last_polled?: string;
  status: 'running' | 'completed' | 'failed' | 'timeout';
}

// Orchestrator cycle
export interface CycleState {
  cycleId: string;               // CYCLE-YYYY-MM-DD-NNN
  state: OrchestratorState;
  startedAt: string;
  phases: CyclePhase[];
  workOrders: WorkOrder[];
  scanResults?: ScanResult;
  validationResult?: ValidationResult;
  report?: CycleReport;
}

export interface CyclePhase {
  name: OrchestratorState;
  startedAt: string;
  completedAt?: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  notes?: string;
}

export interface ScanResult {
  domains: DomainScore[];
  pendingTasks: number;
  blockedTasks: number;
  recommendedFocus: string;
}

export interface DomainScore {
  domain: string;               // gameplay, visual, audio, narrative, qa, performance, content
  score: number;                // 0-100 priority score
  reasons: string[];
}

export interface ValidationResult {
  passed: boolean;
  errors: number;
  warnings: number;
  details: string;
}

export interface CycleReport {
  cycleId: string;
  duration_seconds: number;
  tasksCompleted: number;
  tasksFailed: number;
  agentsUsed: string[];
  filesModified: string[];
  validationPassed: boolean;
  summary: string;
}

// Agent performance tracking
export interface AgentPerformance {
  [agentId: string]: {
    tasks_completed: number;
    tasks_failed: number;
    validation_pass_rate: number;
    human_override_rate: number;
    avg_duration_ms: number;
    last_task_at: string;
    trend: 'improving' | 'stable' | 'degrading';
  };
}

// Agent evolution
export interface EvolutionEntry {
  timestamp: string;
  type: 'created' | 'improved' | 'disabled' | 'promoted';
  agentId: string;
  reason: string;
  details: string;
}

// Dashboard SSE event
export interface DashboardEvent {
  type:
    | 'state_change'
    | 'agent_update'
    | 'task_update'
    | 'cycle_update'
    | 'alert'
    | 'deploy';
  timestamp: string;
  data: Record<string, unknown>;
}

// Config
export interface BridgeConfig {
  projectRoot: string;
  statusDir: string;             // tools/autodev/status/
  agentsDir: string;             // .claude/agents/
  agentCardsDir: string;         // tools/autodev/agent_cards/
  maxParallelAgents: number;     // default 3
  cycleTimeout_minutes: number;  // default 120
  dryRun: boolean;
  autoEvolve: boolean;
  vercelProjectUrl: string;
}
