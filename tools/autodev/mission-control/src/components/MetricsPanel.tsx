import { useMissionStore } from '../store/mission-store';

export function MetricsPanel() {
  const featureQueue = useMissionStore(s => s.featureQueue);
  const agents = useMissionStore(s => s.agents);
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions);
  const completedCount = useMissionStore(s => s.completedCount);

  const pending = featureQueue.filter(t => t.status === 'pending').length;
  const inProgress = featureQueue.filter(t => t.status === 'in_progress' || t.status === 'dispatched').length;
  const total = featureQueue.length + completedCount;
  const activeAgents = agents.filter(a => a.state === 'running').length;
  const pendingFeedback = feedbackQuestions.filter(q => q.status === 'pending').length;
  const progressPct = total > 0 ? Math.round((completedCount / total) * 100) : 0;

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
            <div className="metric-value" style={{ color: 'var(--green)', textShadow: 'var(--glow-green)' }}>
              {completedCount}
            </div>
            <div className="metric-label">Completed</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: inProgress > 0 ? 'var(--cyan, var(--green))' : 'var(--text-dim)' }}>
              {inProgress}
            </div>
            <div className="metric-label">In Progress</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--amber)', textShadow: 'var(--glow-amber)' }}>
              {pending}
            </div>
            <div className="metric-label">Pending</div>
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

        {total > 0 && (
          <div style={{ marginTop: '10px' }}>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: 'var(--text-secondary)',
              marginBottom: '4px',
            }}>
              <span>PROGRESS</span>
              <span>{completedCount}/{total} — {progressPct}%</span>
            </div>
            <div style={{
              height: '6px',
              background: 'rgba(0, 255, 136, 0.08)',
              borderRadius: '3px',
              overflow: 'hidden',
              border: '1px solid rgba(0, 255, 136, 0.15)',
            }}>
              <div style={{
                height: '100%',
                width: `${progressPct}%`,
                background: 'var(--green)',
                boxShadow: 'var(--glow-green)',
                borderRadius: '2px',
                transition: 'width 0.5s ease',
              }} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
