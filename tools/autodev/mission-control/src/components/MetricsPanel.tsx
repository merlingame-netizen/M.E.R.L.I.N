import { useMissionStore } from '../store/mission-store';

export function MetricsPanel() {
  const featureQueue = useMissionStore(s => s.featureQueue);
  const agents = useMissionStore(s => s.agents);
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions);

  const pending = featureQueue.filter(t => t.status === 'pending').length;
  const completed = featureQueue.filter(t => t.status === 'completed').length;
  const total = featureQueue.length;
  const activeAgents = agents.filter(a => a.state === 'running').length;
  const pendingFeedback = feedbackQuestions.filter(q => q.status === 'pending').length;

  return (
    <div className="panel" style={{ height: 'auto' }}>
      <div className="panel-header">Telemetry</div>
      <div className="panel-body">
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))',
          gap: '8px',
        }}>
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--amber)', textShadow: 'var(--glow-amber)' }}>
              {pending}
            </div>
            <div className="metric-label">Pending Tasks</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--green)', textShadow: 'var(--glow-green)' }}>
              {completed}
            </div>
            <div className="metric-label">Completed</div>
          </div>
          <div className="metric-card">
            <div className="metric-value">{total}</div>
            <div className="metric-label">Total Queue</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: activeAgents > 0 ? 'var(--green)' : 'var(--text-dim)', textShadow: activeAgents > 0 ? 'var(--glow-green)' : 'none' }}>
              {activeAgents}
            </div>
            <div className="metric-label">Agents Active</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: pendingFeedback > 0 ? 'var(--amber)' : 'var(--text-dim)', textShadow: pendingFeedback > 0 ? 'var(--glow-amber)' : 'none' }}>
              {pendingFeedback}
            </div>
            <div className="metric-label">Awaiting Director</div>
          </div>
        </div>
      </div>
    </div>
  );
}
