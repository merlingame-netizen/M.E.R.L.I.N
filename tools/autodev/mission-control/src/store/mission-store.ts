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
  sprint?: string;
  type?: string;
  description?: string;
  files?: string[];
}

export interface StudioInsight {
  id: string;
  agent: string;
  severity: 'ACTION' | 'WARN' | 'INFO';
  category: string;
  message: string;
  details?: string;
  proposed_task?: { title: string; sprint: string; type: string };
  timestamp: string;
}

export interface GitCommit {
  sha: string;
  message: string;
  author: string;
  date: string;
  type: string;
  scope: string | null;
}

export interface FeedbackQuestion {
  id: string;
  category: 'design' | 'graphics' | 'gamedesign' | 'rendering' | 'ux' | 'infrastructure';
  priority: 'HIGH' | 'MEDIUM' | 'LOW';
  status: 'pending' | 'answered';
  question: string;
  context?: string;
  type: 'multiple_choice' | 'text' | 'image_compare';
  options?: string[] | null;
  screenshot_urls?: string[] | null;
  created_at: string;
}

export interface FeedbackResponse {
  question_id: string;
  answer: string;
  additional_notes?: string;
  timestamp: string;
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
  feedbackQuestions: FeedbackQuestion[];
  feedbackResponses: FeedbackResponse[];
  feedbackSubmitting: boolean;
  lastHeartbeat: string | null;
  completedCount: number;
  studioInsights: StudioInsight[];
  gitActivity: GitCommit[];

  setOrchestratorState: (state: string) => void;
  setGitActivity: (commits: GitCommit[]) => void;
  setAgents: (agents: AgentInfo[]) => void;
  setStudioInsights: (insights: StudioInsight[]) => void;
  updateAgent: (id: string, update: Partial<AgentInfo>) => void;
  setActiveSessions: (sessions: ActiveSession[]) => void;
  setFeatureQueue: (tasks: FeatureTask[]) => void;
  addCycleToHistory: (cycle: CycleInfo) => void;
  addAlert: (alert: Omit<AlertEntry, 'id'>) => void;
  setDeployStatus: (status: MissionState['deployStatus']) => void;
  setConnected: (connected: boolean) => void;
  setLastHeartbeat: (heartbeat: string | null) => void;
  setCompletedCount: (count: number) => void;
  setFeedbackQuestions: (questions: FeedbackQuestion[]) => void;
  submitFeedback: (questionId: string, answer: string, notes?: string) => Promise<void>;
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
  feedbackQuestions: [],
  feedbackResponses: [],
  feedbackSubmitting: false,
  lastHeartbeat: null,
  completedCount: 0,
  studioInsights: [],
  gitActivity: [],

  setOrchestratorState: (state) => set({ orchestratorState: state }),
  setGitActivity: (gitActivity) => set({ gitActivity }),
  setStudioInsights: (studioInsights) => set({ studioInsights }),
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
  setLastHeartbeat: (lastHeartbeat) => set({ lastHeartbeat }),
  setCompletedCount: (completedCount) => set({ completedCount }),
  setFeedbackQuestions: (questions) => set({ feedbackQuestions: questions }),
  submitFeedback: async (questionId, answer, notes) => {
    set({ feedbackSubmitting: true });
    try {
      const API_URL = import.meta.env.VITE_API_URL
        ? `${import.meta.env.VITE_API_URL.replace('/status', '/feedback')}`
        : '/api/feedback';
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question_id: questionId, answer, additional_notes: notes }),
      });
      if (res.ok) {
        set(s => ({
          feedbackQuestions: s.feedbackQuestions.map(q =>
            q.id === questionId ? { ...q, status: 'answered' as const } : q
          ),
          feedbackResponses: [...s.feedbackResponses, {
            question_id: questionId,
            answer,
            additional_notes: notes,
            timestamp: new Date().toISOString(),
          }],
        }));
      }
    } finally {
      set({ feedbackSubmitting: false });
    }
  },
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
