import { useMissionStore } from '../store/mission-store';

function getShortName(name: string): string {
  return name.slice(0, 3).toUpperCase();
}

export function AgentFleet() {
  const agents = useMissionStore(s => s.agents);
  const runningCount = agents.filter(a => a.state === 'running').length;

  return (
    <div className="panel">
      <div className="panel-header">
        Agent Fleet
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {agents.length > 0 ? `${runningCount}/${agents.length} ACTIVE` : 'LIVE'}
        </span>
      </div>
      <div className="panel-body">
        {agents.length === 0 ? (
          <div style={{
            padding: '16px 12px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-dim)',
            textAlign: 'center',
          }}>
            No agents running
          </div>
        ) : (
          <div className="hex-grid">
            {agents.map((agent) => (
              <div
                key={agent.id}
                className={`hex-tile hex-tile--${agent.state}`}
                title={`${agent.name}${agent.currentTask ? ` — ${agent.currentTask}` : ''}`}
              >
                {getShortName(agent.name)}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
