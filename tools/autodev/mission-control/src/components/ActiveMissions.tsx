import { useState, useEffect } from 'react';
import type { ActiveSession } from '../store/mission-store';

const MOCK_SESSIONS: ActiveSession[] = [
  { sessionId: 's-001', agentId: 'architect', taskTitle: 'Design MerlinGame scene flow refactor', startedAt: new Date(Date.now() - 342000).toISOString(), status: 'running' },
  { sessionId: 's-002', agentId: 'godot-orch', taskTitle: 'Validate BroceliandeForest3D scene tree', startedAt: new Date(Date.now() - 189000).toISOString(), status: 'running' },
  { sessionId: 's-003', agentId: 'refactor', taskTitle: 'Remove deprecated yield() calls', startedAt: new Date(Date.now() - 95000).toISOString(), status: 'running' },
  { sessionId: 's-004', agentId: 'biome-bld', taskTitle: 'Generate Broceliande terrain mesh', startedAt: new Date(Date.now() - 540000).toISOString(), status: 'running' },
  { sessionId: 's-005', agentId: 'code-reviewer', taskTitle: 'Review merlin_store.gd changes', startedAt: new Date(Date.now() - 720000).toISOString(), status: 'completed' },
  { sessionId: 's-006', agentId: 'llm-adapter', taskTitle: 'Configure Qwen 3.5 multi-brain routing', startedAt: new Date(Date.now() - 900000).toISOString(), status: 'completed' },
  { sessionId: 's-007', agentId: 'save-sys', taskTitle: 'Implement cross-run profile persistence', startedAt: new Date(Date.now() - 1200000).toISOString(), status: 'completed' },
  { sessionId: 's-008', agentId: 'visual-w', taskTitle: 'Compile GBC palette shader variants', startedAt: new Date(Date.now() - 60000).toISOString(), status: 'failed' },
];

function formatElapsed(startedAt: string): string {
  const elapsed = Math.floor((Date.now() - new Date(startedAt).getTime()) / 1000);
  const m = Math.floor(elapsed / 60);
  const s = elapsed % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function ActiveMissions() {
  const [, setTick] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => setTick(t => t + 1), 1000);
    return () => clearInterval(interval);
  }, []);

  const sessions = MOCK_SESSIONS;

  return (
    <div className="panel">
      <div className="panel-header">
        Active Missions
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {sessions.filter(s => s.status === 'running').length} RUNNING
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {sessions.map((session) => (
          <div key={session.sessionId} className="mission-row">
            <span className="mission-agent">{session.agentId}</span>
            <span className="mission-task">{session.taskTitle}</span>
            <span className="mission-time">{formatElapsed(session.startedAt)}</span>
            <span className={`mission-status mission-status--${session.status}`}>
              {session.status}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
