import { useEffect, useRef } from 'react';
import { useMissionStore } from '../store/mission-store';

// Cloud-native: poll the Vercel serverless API or fallback to local SSE
const API_URL = import.meta.env.VITE_API_URL || '/api/status';
const POLL_INTERVAL = 30_000; // 30s

interface StatusResponse {
  ok: boolean;
  timestamp: string;
  data: {
    feature_queue?: { tasks?: Array<{ id: string; title: string; priority: number; status: string; agent?: string }> };
    agent_status?: { agents?: Record<string, { state?: string; current_task?: string | null }> };
    events?: Array<{ type: string; timestamp?: string; data?: Record<string, unknown> }>;
    escalation?: { type?: string; message?: string; timestamp?: string } | null;
    watchdog?: string | null;
    feedback_questions?: { questions?: Array<{ id: string; category: string; priority: string; status: string; question: string; context?: string; type: string; options?: string[] | null; screenshot_urls?: string[] | null; created_at: string }> };
    feedback_responses?: { responses?: Array<{ question_id: string; answer: string; additional_notes?: string }> };
    completed_archive?: { tasks?: Array<{ id: string }> };
  };
}

export function useStateSync() {
  const setConnected = useMissionStore(s => s.setConnected);
  const addAlert = useMissionStore(s => s.addAlert);
  const setFeatureQueue = useMissionStore(s => s.setFeatureQueue);
  const setAgents = useMissionStore(s => s.setAgents);
  const setOrchestratorState = useMissionStore(s => s.setOrchestratorState);
  const addCycleToHistory = useMissionStore(s => s.addCycleToHistory);
  const setFeedbackQuestions = useMissionStore(s => s.setFeedbackQuestions);
  const setLastHeartbeat = useMissionStore(s => s.setLastHeartbeat);
  const setCompletedCount = useMissionStore(s => s.setCompletedCount);

  const intervalRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined);
  const lastTimestampRef = useRef<string>('');

  useEffect(() => {
    async function poll() {
      try {
        const res = await fetch(API_URL);
        if (!res.ok) {
          setConnected(false);
          return;
        }

        const json: StatusResponse = await res.json();
        setConnected(true);

        // Only process if data changed
        if (json.timestamp === lastTimestampRef.current) return;
        lastTimestampRef.current = json.timestamp;

        const { data } = json;

        // Feature queue
        if (data.feature_queue?.tasks) {
          setFeatureQueue(data.feature_queue.tasks.map(t => ({
            id: t.id,
            title: t.title,
            priority: t.priority,
            status: t.status as 'pending' | 'in_progress' | 'completed' | 'blocked' | 'dispatched',
            agent: t.agent,
          })));
        }

        // Agents
        if (data.agent_status?.agents) {
          setAgents(Object.entries(data.agent_status.agents).map(([id, info]) => ({
            id,
            name: id.replace(/_/g, ' '),
            category: 'core',
            state: (info.state || 'idle') as 'idle' | 'running' | 'blocked' | 'error' | 'completed',
            currentTask: info.current_task || null,
          })));
        }

        // Completed archive count
        const archivedCount = data.completed_archive?.tasks?.length || 0;
        setCompletedCount(archivedCount);

        // Events — process last 20 for state changes, cycle updates, and alerts
        if (data.events && Array.isArray(data.events)) {
          const recent = data.events.slice(-20);
          for (const event of recent) {
            if (event.type === 'state_change' && event.data) {
              setOrchestratorState(event.data.to as string);
              addAlert({
                timestamp: (event.timestamp as string) || new Date().toISOString(),
                level: 'INFO',
                message: `State: ${event.data.from} → ${event.data.to}`,
                source: 'orchestrator',
              });
            }
            if (event.type === 'cycle_update' && event.data) {
              addCycleToHistory({
                cycleId: (event.data.cycleId as string) || '',
                state: 'completed',
                startedAt: (event.timestamp as string) || '',
                tasksCompleted: (event.data.tasksCompleted as number) || 0,
                tasksFailed: (event.data.tasksFailed as number) || 0,
                agentsUsed: (event.data.agentsUsed as string[]) || [],
              });
              const tasks = (event.data.tasksCompleted as number) || 0;
              const cycleType = (event.data.cycle_type as string) || 'unknown';
              addAlert({
                timestamp: (event.timestamp as string) || new Date().toISOString(),
                level: tasks > 0 ? 'SUCCESS' : 'INFO',
                message: `Cycle ${event.data.cycleId} complete [${cycleType.toUpperCase()}] — ${tasks} tasks done`,
                source: 'orchestrator',
              });
            }
          }
        }

        // Watchdog heartbeat
        if (data.watchdog && typeof data.watchdog === 'string') {
          const lines = (data.watchdog as string).trim().split('\n');
          const lastLine = lines[lines.length - 1] || '';
          const tsMatch = lastLine.match(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/);
          setLastHeartbeat(tsMatch ? tsMatch[0] : lastLine.slice(0, 25));
        }

        // Feedback questions — merge with server responses + local optimistic state
        if (data.feedback_questions?.questions) {
          // Server-side responses (survives reload)
          const serverResponseIds = new Set(
            (data.feedback_responses?.responses || []).map(r => r.question_id)
          );
          // Local optimistic state (survives within session)
          const localResponses = useMissionStore.getState().feedbackResponses;
          const localAnsweredIds = new Set(localResponses.map(r => r.question_id));
          const localQuestionAnswered = new Set(
            useMissionStore.getState().feedbackQuestions.filter(q => q.status === 'answered').map(q => q.id)
          );

          const merged = data.feedback_questions.questions.map(q => ({
            ...q,
            status: (serverResponseIds.has(q.id) || localAnsweredIds.has(q.id) || localQuestionAnswered.has(q.id))
              ? 'answered' as const
              : q.status,
          }));
          setFeedbackQuestions(merged as any);
        }

        // Escalation alert
        if (data.escalation && typeof data.escalation === 'object' && data.escalation.message) {
          addAlert({
            timestamp: data.escalation.timestamp || new Date().toISOString(),
            level: 'ERROR',
            message: data.escalation.message,
            source: 'escalation',
          });
        }

      } catch {
        setConnected(false);
      }
    }

    // Initial poll
    poll();

    // Poll every 30s
    intervalRef.current = setInterval(poll, POLL_INTERVAL);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);
}
