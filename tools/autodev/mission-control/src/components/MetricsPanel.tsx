export function MetricsPanel() {
  return (
    <div className="panel" style={{ height: 'auto' }}>
      <div className="panel-header">Telemetry</div>
      <div className="panel-body">
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr 1fr',
          gap: '8px',
        }}>
          <div className="metric-card">
            <div className="metric-value">37</div>
            <div className="metric-label">Tasks Today</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--green)', textShadow: 'var(--glow-green)' }}>
              94%
            </div>
            <div className="metric-label">Pass Rate</div>
          </div>
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--amber)', textShadow: 'var(--glow-amber)' }}>
              4
            </div>
            <div className="metric-label">Agents Active</div>
          </div>
        </div>
      </div>
    </div>
  );
}
