import { useEffect, useRef, useState } from 'react';
import { useMissionStore } from '../store/mission-store';

function formatTime(isoStr: string): string {
  const d = new Date(isoStr);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
}

type FilterLevel = 'all' | 'important';

export function AlertFeed() {
  const alerts = useMissionStore(s => s.alerts);
  const feedRef = useRef<HTMLDivElement>(null);
  const [filter, setFilter] = useState<FilterLevel>('important');

  useEffect(() => {
    if (feedRef.current) {
      feedRef.current.scrollTop = 0;
    }
  }, [alerts.length]);

  const filtered = filter === 'important'
    ? alerts.filter(a => a.level !== 'INFO')
    : alerts;

  const importantCount = alerts.filter(a => a.level !== 'INFO').length;

  return (
    <div className="panel">
      <div className="panel-header">
        System Log
        <span style={{
          marginLeft: 'auto',
          display: 'flex',
          gap: '4px',
          alignItems: 'center',
        }}>
          <button
            onClick={() => setFilter('important')}
            style={{
              fontSize: '9px',
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              padding: '1px 6px',
              borderRadius: '2px',
              border: 'none',
              cursor: 'pointer',
              background: filter === 'important' ? 'rgba(0,255,136,0.15)' : 'transparent',
              color: filter === 'important' ? 'var(--green)' : 'var(--text-dim)',
            }}
          >
            KEY ({importantCount})
          </button>
          <button
            onClick={() => setFilter('all')}
            style={{
              fontSize: '9px',
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              padding: '1px 6px',
              borderRadius: '2px',
              border: 'none',
              cursor: 'pointer',
              background: filter === 'all' ? 'rgba(0,255,136,0.15)' : 'transparent',
              color: filter === 'all' ? 'var(--green)' : 'var(--text-dim)',
            }}
          >
            ALL ({alerts.length})
          </button>
        </span>
      </div>
      <div className="alert-feed" ref={feedRef} style={{ flex: 1 }}>
        {filtered.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            {filter === 'important'
              ? 'No warnings or errors — system nominal'
              : 'No events yet — waiting for orchestrator cycle...'}
          </div>
        )}
        {filtered.map((alert) => (
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
