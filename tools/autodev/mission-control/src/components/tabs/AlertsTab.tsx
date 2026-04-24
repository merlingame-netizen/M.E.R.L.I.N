import { useEffect, useRef } from 'react';
import { useMissionStore } from '../../store/mission-store';

function formatTime(isoStr: string): string {
  const d = new Date(isoStr);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
}

export function AlertsTab() {
  const alerts = useMissionStore(s => s.alerts) || [];
  const feedRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (feedRef.current) feedRef.current.scrollTop = 0;
  }, [alerts.length]);

  return (
    <div style={{ padding: '12px' }}>
      <div className="panel-header" style={{ marginBottom: '12px' }}>
        System Log
        <span style={{ marginLeft: 'auto', fontSize: '10px', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
          {alerts.length} ENTRIES
        </span>
      </div>

      {alerts.length === 0 && (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-dim)' }}>
          No alerts yet. System nominal.
        </div>
      )}

      <div className="alert-feed" ref={feedRef}>
        {alerts.map(alert => (
          <div key={alert.id} className="alert-entry">
            <span className="alert-time">{formatTime(alert.timestamp)}</span>
            <span className={`alert-level alert-level--${alert.level.toLowerCase()}`}>
              {alert.level}
            </span>
            <span className="alert-message">{alert.message}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
