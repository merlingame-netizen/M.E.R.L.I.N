import { useMissionStore } from '../store/mission-store';

function getPriorityClass(priority: number): string {
  if (priority <= 2) return 'priority-dot--high';
  if (priority <= 5) return 'priority-dot--medium';
  return 'priority-dot--low';
}

function getTypeLabel(task: { id: string; type?: string }): string | null {
  if (task.id.startsWith('TEST-')) return 'TEST';
  if (task.id.startsWith('P0-') || task.id.startsWith('P1-')) return 'DEV';
  return null;
}

export function FeatureQueue() {
  const tasks = useMissionStore(s => s.featureQueue);

  const sorted = [...tasks]
    .filter(t => t.status !== 'completed')
    .sort((a, b) => a.priority - b.priority);

  const pendingCount = sorted.filter(t => t.status === 'pending' || t.status === 'in_progress' || t.status === 'dispatched').length;

  return (
    <div className="panel">
      <div className="panel-header">
        Feature Queue
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {pendingCount} PENDING
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {sorted.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            No tasks in queue
          </div>
        )}
        {sorted.map((task) => {
          const typeLabel = getTypeLabel(task);
          return (
            <div key={task.id} className="feature-row">
              <div className={`priority-dot ${getPriorityClass(task.priority)}`} />
              {typeLabel && (
                <span style={{
                  fontSize: '9px',
                  fontWeight: 700,
                  padding: '1px 4px',
                  borderRadius: '2px',
                  background: typeLabel === 'TEST' ? 'rgba(255,165,0,0.15)' : 'rgba(0,255,136,0.15)',
                  color: typeLabel === 'TEST' ? 'var(--amber)' : 'var(--green)',
                  marginRight: '4px',
                  letterSpacing: '0.5px',
                }}>
                  {typeLabel}
                </span>
              )}
              <span className="feature-title">{task.title}</span>
              <span className={`feature-status feature-status--${task.status}`}>
                {task.status.replace('_', ' ')}
              </span>
              {task.agent && (
                <span className="feature-agent">{task.agent}</span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
