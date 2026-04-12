import { useMissionStore } from '../store/mission-store';

function getPriorityClass(priority: number): string {
  if (priority <= 2) return 'priority-dot--high';
  if (priority <= 5) return 'priority-dot--medium';
  return 'priority-dot--low';
}

function getTypeLabel(task: { id: string }): string | null {
  const id = task.id;
  if (id.startsWith('TEST-') || id.includes('-TEST') || id.includes('-EDGE') || id.includes('-LLM-')) return 'TEST';
  if (id.startsWith('P0-') || id.startsWith('P1-') || id.startsWith('S1-') || id.startsWith('S2-') || id.startsWith('S3-')) return 'DEV';
  return null;
}

function getSprintLabel(task: { id: string }): string | null {
  if (task.id.startsWith('S1-')) return 'S1';
  if (task.id.startsWith('S2-')) return 'S2';
  if (task.id.startsWith('S3-')) return 'S3';
  return null;
}

export function FeatureQueue() {
  const tasks = useMissionStore(s => s.featureQueue);
  const completedCount = useMissionStore(s => s.completedCount);

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
        {completedCount > 0 && (
          <div style={{
            padding: '6px 12px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--green)',
            background: 'rgba(0, 255, 136, 0.06)',
            borderBottom: '1px solid rgba(0, 255, 136, 0.1)',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
          }}>
            <span style={{ fontSize: '13px' }}>&#10003;</span>
            <span>{completedCount} tasks completed (archived)</span>
          </div>
        )}
        {sorted.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            No tasks in queue
          </div>
        )}
        {sorted.map((task) => {
          const typeLabel = getTypeLabel(task);
          const sprint = getSprintLabel(task);
          return (
            <div key={task.id} className="feature-row">
              <div className={`priority-dot ${getPriorityClass(task.priority)}`} />
              {sprint && (
                <span style={{
                  fontSize: '9px',
                  fontWeight: 700,
                  padding: '1px 3px',
                  borderRadius: '2px',
                  background: 'rgba(255,255,255,0.06)',
                  color: 'var(--text-secondary)',
                  marginRight: '2px',
                  letterSpacing: '0.5px',
                }}>
                  {sprint}
                </span>
              )}
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
