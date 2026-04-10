import { create } from 'zustand';

export interface AgentInfo {
  id: string;
  name: string;
  category: string;
  state: 'idle' | 'running' | 'blocked' | 'error' | 'completed';
  currentTask: string | null;
}

export interface ActiveSession {
  sessionId: string;
  agentId: string;
  taskTitle: string;
  startedAt: string;
  status: 'running' | 'completed' | 'failed';
}

export interface CycleInfo {
  cycleId: string;
  state: string;
  startedAt: string;
  tasksCompleted: number;
  tasksFailed: number;
  agentsUsed: string[];
}

export interface AlertEntry {
  id: string;
  timestamp: string;
  level: 'INFO' | 'WARN' | 'ERROR' | 'SUCCESS';
  message: string;
  source?: string;
}

export interface FeatureTask {
  id: string;
  title: string;
  priority: number;
  status: 'pending' | 'in_progress' | 'completed' | 'blocked' | 'dispatched';
  agent?: string;
}

interface MissionState {
  orchestratorState: string;
  cycleId: string | null;
  agents: AgentInfo[];
  activeSessions: ActiveSession[];
  featureQueue: FeatureTask[];
  cycleHistory: CycleInfo[];
  alerts: AlertEntry[];
  deployStatus: 'idle' | 'building' | 'deployed' | 'failed';
  lastDeployAt: string | null;
  connected: boolean;

  setOrchestratorState: (state: string) => void;
  setAgents: (agents: AgentInfo[]) => void;
  updateAgent: (id: string, update: Partial<AgentInfo>) => void;
  setActiveSessions: (sessions: ActiveSession[]) => void;
  setFeatureQueue: (tasks: FeatureTask[]) => void;
  addCycleToHistory: (cycle: CycleInfo) => void;
  addAlert: (alert: Omit<AlertEntry, 'id'>) => void;
  setDeployStatus: (status: MissionState['deployStatus']) => void;
  setConnected: (connected: boolean) => void;
  handleSSEEvent: (event: { type: string; data: Record<string, unknown> }) => void;
}

export const useMissionStore = create<MissionState>((set, get) => ({
  orchestratorState: 'IDLE',
  cycleId: null,
  agents: [],
  activeSessions: [],
  featureQueue: [],
  cycleHistory: [],
  alerts: [],
  deployStatus: 'idle',
  lastDeployAt: null,
  connected: false,

  setOrchestratorState: (state) => set({ orchestratorState: state }),
  setAgents: (agents) => set({ agents }),
  updateAgent: (id, update) => set(s => ({
    agents: s.agents.map(a => a.id === id ? { ...a, ...update } : a),
  })),
  setActiveSessions: (sessions) => set({ activeSessions: sessions }),
  setFeatureQueue: (tasks) => set({ featureQueue: tasks }),
  addCycleToHistory: (cycle) => set(s => ({
    cycleHistory: [cycle, ...s.cycleHistory].slice(0, 50),
  })),
  addAlert: (alert) => set(s => ({
    alerts: [{ ...alert, id: crypto.randomUUID() }, ...s.alerts].slice(0, 200),
  })),
  setDeployStatus: (deployStatus) => set({ deployStatus }),
  setConnected: (connected) => set({ connected }),
  handleSSEEvent: (event) => {
    const store = get();
    switch (event.type) {
      case 'state_change':
        store.setOrchestratorState(event.data.to as string);
        store.addAlert({
          timestamp: new Date().toISOString(),
          level: 'INFO',
          message: `State: ${event.data.from} -> ${event.data.to}`,
          source: 'orchestrator',
        });
        break;
      case 'agent_update':
        store.updateAgent(event.data.agentId as string, event.data as Partial<AgentInfo>);
        break;
      case 'cycle_update':
        store.addCycleToHistory(event.data as unknown as CycleInfo);
        break;
      case 'alert':
        store.addAlert({
          timestamp: new Date().toISOString(),
          level: (event.data.level as AlertEntry['level']) || 'INFO',
          message: event.data.message as string,
          source: event.data.source as string,
        });
        break;
      case 'deploy':
        store.setDeployStatus(event.data.status as MissionState['deployStatus']);
        break;
    }
  },
}));
