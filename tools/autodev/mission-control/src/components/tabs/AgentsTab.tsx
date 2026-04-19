import { useMissionStore } from '../../store/mission-store';

export function AgentsTab() {
  const agents = useMissionStore(s => s.agents);

  const sorted = [...agents].sort((a, b) => {
    const order: Record<string, number> = { running: 0, error: 1, blocked: 2, idle: 3, completed: 4 };
    return (order[a.state] ?? 5) - (order[b.state] ?? 5);
  });

  return (
    <div>
      <div className="section-title">{'\u2699'} Agent Fleet — {agents.length} registered</div>
      <div className="agents-grid">
        {sorted.map(a => (
          <div key={a.id} className={`agent-card agent-card--${a.state}`}>
            <span className={`agent-card__dot agent-card__dot--${a.state}`} />
            <div className="agent-card__info">
              <div className="agent-card__name">{a.name}</div>
              <div className="agent-card__task">{a.currentTask || a.state}</div>
            </div>
          </div>
        ))}
        {agents.length === 0 && (
          <div style={{ padding: '20px', color: 'var(--text-dim)', gridColumn: '1/-1' }}>
            No agents registered. Waiting for status sync...
          </div>
        )}
      </div>
    </div>
  );
}
