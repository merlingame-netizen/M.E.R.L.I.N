import { useEffect, useRef } from 'react';
import { useMissionStore } from '../store/mission-store';

function formatTime(isoStr: string): string {
  const d = new Date(isoStr);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
}

export function AlertFeed() {
  const alerts = useMissionStore(s => s.alerts);
  const feedRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (feedRef.current) {
      feedRef.current.scrollTop = 0;
    }
  }, [alerts.length]);

  return (
    <div className="panel">
      <div className="panel-header">
        System Log
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {alerts.length} ENTRIES
        </span>
      </div>
      <div className="alert-feed" ref={feedRef} style={{ flex: 1 }}>
        {alerts.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            No events yet — waiting for orchestrator cycle...
          </div>
        )}
        {alerts.map((alert) => (
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
