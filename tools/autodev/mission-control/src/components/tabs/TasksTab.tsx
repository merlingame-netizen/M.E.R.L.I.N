import { useMissionStore } from '../../store/mission-store';

function getPriorityClass(priority: number): string {
  if (priority <= 1) return 'priority-dot--high';
  if (priority <= 2) return 'priority-dot--medium';
  return 'priority-dot--low';
}

export function TasksTab() {
  const featureQueue = useMissionStore(s => s.featureQueue) || [];

  const pending = featureQueue.filter(t => t.status !== 'completed');
  const completed = featureQueue.filter(t => t.status === 'completed');

  return (
    <div style={{ padding: '12px' }}>
      <div className="panel-header" style={{ marginBottom: '12px' }}>
        Feature Queue
        <span style={{ marginLeft: 'auto', fontSize: '10px', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
          {pending.length} PENDING
        </span>
      </div>

      {featureQueue.length === 0 && (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-dim)' }}>
          Loading feature queue...
        </div>
      )}

      {pending.map(task => (
        <div key={task.id} className="feature-row">
          <div className={`priority-dot ${getPriorityClass(task.priority)}`} />
          <span className="feature-title">{task.title}</span>
          <span className={`feature-status feature-status--${task.status}`}>
            {task.status.replace('_', ' ')}
          </span>
          {task.agent && <span className="feature-agent">{task.agent}</span>}
        </div>
      ))}

      {completed.length > 0 && (
        <>
          <div style={{ margin: '16px 0 8px', fontSize: '10px', color: 'var(--text-dim)', textTransform: 'uppercase', letterSpacing: '1px' }}>
            Completed ({completed.length})
          </div>
          {completed.map(task => (
            <div key={task.id} className="feature-row" style={{ opacity: 0.5 }}>
              <div className={`priority-dot ${getPriorityClass(task.priority)}`} />
              <span className="feature-title">{task.title}</span>
              <span className="feature-status feature-status--completed">done</span>
              {task.agent && <span className="feature-agent">{task.agent}</span>}
            </div>
          ))}
        </>
      )}
    </div>
  );
}
