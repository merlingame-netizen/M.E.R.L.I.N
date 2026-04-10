import { useEffect, useRef } from 'react';
import { useMissionStore } from '../store/mission-store';

const SSE_URL = import.meta.env.VITE_SSE_URL || 'http://localhost:4201';

export function useStateSync() {
  const setConnected = useMissionStore(s => s.setConnected);
  const addAlert = useMissionStore(s => s.addAlert);
  const setFeatureQueue = useMissionStore(s => s.setFeatureQueue);
  const setAgents = useMissionStore(s => s.setAgents);
  const setActiveSessions = useMissionStore(s => s.setActiveSessions);
  const handleSSEEvent = useMissionStore(s => s.handleSSEEvent);

  const esRef = useRef<EventSource | null>(null);
  const retryRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    function connect() {
      esRef.current?.close();
      const es = new EventSource(`${SSE_URL}/events`);
      esRef.current = es;

      es.onopen = () => {
        setConnected(true);
        addAlert({ timestamp: new Date().toISOString(), level: 'SUCCESS', message: 'Connected to Studio Bridge', source: 'dashboard' });
      };

      es.onmessage = (e) => {
        try {
          const event = JSON.parse(e.data);
          if (event.type === 'full_state' || event.type === 'file_update') {
            const { file, content } = event.data;
            if (file === 'feature_queue.json') {
              setFeatureQueue(content.tasks || []);
            } else if (file === 'agent_status.json' && content.agents) {
              setAgents(Object.entries(content.agents).map(([id, info]: [string, unknown]) => {
                const agentInfo = info as { state?: string; current_task?: string | null };
                return {
                  id,
                  name: id.replace(/_/g, ' '),
                  category: 'core',
                  state: (agentInfo.state || 'idle') as 'idle' | 'running' | 'blocked' | 'error' | 'completed',
                  currentTask: agentInfo.current_task || null,
                };
              }));
            } else if (file === 'cloud_sessions.json' && content.active_sessions) {
              setActiveSessions(content.active_sessions.map((s: Record<string, unknown>) => ({
                sessionId: s.session_id as string,
                agentId: s.agent_id as string,
                taskTitle: (s.task_ids as string[])?.join(', ') || '',
                startedAt: s.started_at as string,
                status: s.status as string,
              })));
            }
          } else {
            handleSSEEvent(event);
          }
        } catch { /* ignore parse errors */ }
      };

      es.onerror = () => {
        setConnected(false);
        es.close();
        esRef.current = null;
        retryRef.current = setTimeout(connect, 5000);
      };
    }

    connect();
    return () => {
      esRef.current?.close();
      if (retryRef.current) clearTimeout(retryRef.current);
    };
  }, []);
}
