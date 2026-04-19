import { useMissionStore } from '../../store/mission-store';

function fmtTime(iso: string): string {
  try {
    const d = new Date(iso);
    return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  } catch { return '--:--'; }
}

export function AlertsTab() {
  const alerts = useMissionStore(s => s.alerts);
  const gitActivity = useMissionStore(s => s.gitActivity);

  const levelIcon: Record<string, string> = {
    INFO: '\u2022', WARN: '\u25B2', ERROR: '\u2717', SUCCESS: '\u2713',
  };

  return (
    <div>
      {/* Git activity */}
      {gitActivity.length > 0 && (
        <>
          <div className="section-title">{'\u2691'} Recent Commits</div>
          <div className="commit-list">
            {gitActivity.slice(0, 8).map((c, i) => (
              <div key={i} className="commit-row">
                <span className={`commit-type commit-type--${c.type}`}>{c.type}</span>
                <span className="commit-sha">{c.sha}</span>
                <span className="commit-msg">{c.message}</span>
                <span className="commit-time">{fmtTime(c.date)}</span>
              </div>
            ))}
          </div>
        </>
      )}

      {/* Alerts */}
      <div className="section-title">{'\u26A0'} System Log — {alerts.length} events</div>
      <div className="alert-list">
        {[...alerts].reverse().slice(0, 50).map((a, i) => (
          <div key={a.id || i} className="alert-row">
            <span className="alert-row__time">{fmtTime(a.timestamp)}</span>
            <span className={`alert-row__level alert-row__level--${a.level}`}>
              {levelIcon[a.level] || '\u2022'}
            </span>
            <span className="alert-row__msg">{a.message}</span>
          </div>
        ))}
        {alerts.length === 0 && (
          <div style={{ padding: '20px 12px', color: 'var(--text-dim)' }}>
            No alerts yet.
          </div>
        )}
      </div>
    </div>
  );
}
