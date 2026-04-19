import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

type Filter = 'all' | 'pending' | 'in_progress' | 'completed';

export function TasksTab() {
  const featureQueue = useMissionStore(s => s.featureQueue);
  const [filter, setFilter] = useState<Filter>('all');

  const filtered = filter === 'all'
    ? featureQueue
    : featureQueue.filter(t => t.status === filter);

  const counts = {
    all: featureQueue.length,
    pending: featureQueue.filter(t => t.status === 'pending').length,
    in_progress: featureQueue.filter(t => t.status === 'in_progress').length,
    completed: featureQueue.filter(t => t.status === 'completed').length,
  };

  return (
    <div>
      {/* Filter bar */}
      <div style={{
        display: 'flex', gap: '4px', padding: '8px 12px',
        borderBottom: '1px solid var(--border)', overflowX: 'auto',
      }}>
        {(['all', 'pending', 'in_progress', 'completed'] as Filter[]).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            style={{
              background: filter === f ? 'var(--bg-active)' : 'transparent',
              border: `1px solid ${filter === f ? 'var(--border-active)' : 'var(--border)'}`,
              color: filter === f ? 'var(--phosphor)' : 'var(--text-dim)',
              fontFamily: 'var(--font-mono)',
              fontSize: '9px',
              padding: '4px 10px',
              cursor: 'pointer',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              whiteSpace: 'nowrap',
              minHeight: '28px',
            }}
          >
            {f.replace('_', ' ')} ({counts[f]})
          </button>
        ))}
      </div>

      {/* Task list */}
      <div className="task-list">
        {filtered.map(t => (
          <div key={t.id} className="task-row">
            <span className={`task-dot task-dot--${t.status}`} />
            <div className="task-info">
              <div className="task-title">{t.title}</div>
              <div className="task-meta">
                <span>{t.id}</span>
                {t.agent && <span>{'\u2699'} {t.agent}</span>}
              </div>
            </div>
            {t.type && (
              <span className={`task-badge task-badge--${t.type === 'test' ? 'test' : t.id?.startsWith('BUGFIX') ? 'fix' : 'feat'}`}>
                {t.type || 'task'}
              </span>
            )}
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{ padding: '20px 12px', color: 'var(--text-dim)' }}>
            No tasks match this filter.
          </div>
        )}
      </div>
    </div>
  );
}
