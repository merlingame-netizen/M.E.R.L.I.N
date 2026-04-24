import { useEffect, useRef } from 'react';
import { useMissionStore } from '../store/mission-store';

const POLL_INTERVAL = 5_000;

async function fetchJson(path: string) {
  const res = await fetch(`/status/${path}`);
  if (!res.ok) return null;
  return res.json();
}

async function fetchLines(path: string): Promise<Array<Record<string, unknown>>> {
  const res = await fetch(`/status/${path}`);
  if (!res.ok) return [];
  const text = await res.text();
  return text.trim().split('\n').filter(Boolean).map(line => {
    try { return JSON.parse(line); } catch { return null; }
  }).filter(Boolean) as Array<Record<string, unknown>>;
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
  const setStudioInsights = useMissionStore(s => s.setStudioInsights);
  const setCompletedTasks = useMissionStore(s => s.setCompletedTasks);

  const intervalRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined);
  const lastSessionRef = useRef<string>('');

  useEffect(() => {
    async function poll() {
      try {
        const [session, featureQueue, agentStatus, events, feedbackQuestions, feedbackResponses, completedArchive, studioInsights, watchdog] = await Promise.all([
          fetchJson('session.json'),
          fetchJson('feature_queue.json'),
          fetchJson('agent_status.json'),
          fetchLines('events.jsonl'),
          fetchJson('feedback_questions.json'),
          fetchJson('feedback_responses.json'),
          fetchJson('completed_archive.json'),
          fetchJson('studio_insights.json'),
          fetch('/status/watchdog.txt').then(r => r.ok ? r.text() : null).catch(() => null),
        ]);

        setConnected(true);

        const sessionKey = JSON.stringify(session?.updated_at || session?.cycle);
        if (sessionKey === lastSessionRef.current && sessionKey !== 'null') return;
        lastSessionRef.current = sessionKey;

        if (session) {
          setOrchestratorState(session.state || 'idle');
        }

        const rawTasks = featureQueue?.tasks || [];
        if (rawTasks.length > 0) {
          setFeatureQueue(rawTasks.map((t: Record<string, unknown>) => ({
            id: t.id,
            title: t.title,
            priority: t.priority,
            status: t.status as string,
            agent: t.agent,
            sprint: t.sprint,
            type: t.type,
            description: t.description,
            files: t.files,
          })));
        }

        if (agentStatus?.agents) {
          setAgents(Object.entries(agentStatus.agents).map(([id, info]: [string, any]) => ({
            id,
            name: id.replace(/_/g, ' '),
            category: info.category || 'meta',
            role: info.role,
            state: (info.state || 'idle') as 'idle' | 'running' | 'blocked' | 'error' | 'completed',
            currentTask: info.current_task || null,
          })));
        }

        let archivedCount = 0;
        if (Array.isArray(completedArchive)) {
          archivedCount = completedArchive.length;
        } else if (completedArchive && typeof completedArchive === 'object') {
          const list = completedArchive.archived_tasks || completedArchive.archived || completedArchive.tasks;
          if (Array.isArray(list)) archivedCount = list.length;
        }
        const fqCompleted = rawTasks.filter((t: { status?: string }) => t.status === 'completed').length;
        const newCount = Math.max(archivedCount, fqCompleted);
        if (newCount > 0 || rawTasks.length > 0) {
          setCompletedCount(newCount);
        }

        const archivedTasks = Array.isArray(completedArchive)
          ? completedArchive
          : completedArchive?.archived_tasks;
        if (archivedTasks) {
          setCompletedTasks(archivedTasks.map((t: any) => ({
            id: t.id,
            sprint: t.sprint,
            title: t.title,
            completed_at: t.completed_at,
          })));
        }

        if (events.length > 0) {
          const existingAlertKeys = new Set(
            useMissionStore.getState().alerts.map(a => `${a.timestamp}|${a.message}`)
          );
          const recent = events.slice(-20);
          const lastStateChange = [...recent].reverse().find(e => e.type === 'state_change');
          if (lastStateChange?.data) {
            setOrchestratorState((lastStateChange.data as Record<string, unknown>).to as string);
          }

          for (const event of recent) {
            if (event.type === 'cycle_update' && event.data) {
              const d = event.data as Record<string, unknown>;
              const tasks = (d.tasksCompleted as number) || 0;
              const cycleType = (d.cycle_type as string) || 'unknown';
              const taskId = (d.task_id as string) || '';
              const summary = (d.summary as string) || '';
              const cycleId = (d.cycleId as string) || '';

              addCycleToHistory({
                cycleId,
                state: 'completed',
                startedAt: (event.timestamp as string) || '',
                tasksCompleted: tasks,
                tasksFailed: (d.tasksFailed as number) || 0,
                agentsUsed: (d.agentsUsed as string[]) || [],
              });

              const displayMsg = taskId
                ? `[${cycleType.toUpperCase()}] ${taskId}: ${(summary as string).slice(0, 120)}`
                : `Cycle ${cycleId} [${cycleType.toUpperCase()}] — ${tasks} tasks`;

              const alertKey = `${event.timestamp}|${displayMsg}`;
              if (!existingAlertKeys.has(alertKey)) {
                addAlert({
                  timestamp: (event.timestamp as string) || new Date().toISOString(),
                  level: tasks > 0 ? 'SUCCESS' : 'INFO',
                  message: displayMsg,
                  source: 'orchestrator',
                });
              }
            }
          }
        }

        if (watchdog && typeof watchdog === 'string') {
          const lines = watchdog.trim().split('\n');
          const lastLine = lines[lines.length - 1] || '';
          const tsMatch = lastLine.match(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/);
          setLastHeartbeat(tsMatch ? tsMatch[0] : lastLine.slice(0, 25));
        }

        if (feedbackQuestions?.questions) {
          const serverResponseIds = new Set(
            (feedbackResponses?.responses || []).map((r: { question_id: string }) => r.question_id)
          );
          let localAnsweredIds: Set<string>;
          try {
            localAnsweredIds = new Set(JSON.parse(localStorage.getItem('mc.answered') || '[]'));
          } catch { localAnsweredIds = new Set(); }

          const merged = feedbackQuestions.questions.map((q: { id: string; status: string }) => ({
            ...q,
            status: (serverResponseIds.has(q.id) || localAnsweredIds.has(q.id))
              ? 'answered' as const
              : q.status,
          }));
          setFeedbackQuestions(merged as any);
        }

        if (studioInsights?.insights) {
          setStudioInsights(studioInsights.insights.map((i: any) => ({
            ...i,
            severity: i.severity as 'ACTION' | 'WARN' | 'INFO',
          })));
        }

      } catch {
        setConnected(false);
      }
    }

    poll();
    intervalRef.current = setInterval(poll, POLL_INTERVAL);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);
}
