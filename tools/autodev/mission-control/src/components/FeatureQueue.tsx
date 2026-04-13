import { useState } from 'react';
import { useMissionStore } from '../store/mission-store';

function getPriorityClass(priority: number): string {
  if (priority <= 2) return 'priority-dot--high';
  if (priority <= 5) return 'priority-dot--medium';
  return 'priority-dot--low';
}

function getTypeLabel(task: { id: string; type?: string }): string {
  if (task.type) return task.type.toUpperCase();
  if (task.id.startsWith('TEST-') || task.id.includes('-TEST') || task.id.includes('-EDGE') || task.id.includes('-LLM-')) return 'TEST';
  return 'DEV';
}

function getSprintLabel(task: { id: string; sprint?: string }): string | null {
  if (task.sprint) return task.sprint.toUpperCase();
  if (task.id.startsWith('S1-')) return 'S1';
  if (task.id.startsWith('S2-')) return 'S2';
  if (task.id.startsWith('S3-')) return 'S3';
  if (task.id.startsWith('S4-')) return 'S4';
  return null;
}

export function FeatureQueue() {
  const tasks = useMissionStore(s => s.featureQueue);
  const completedCount = useMissionStore(s => s.completedCount);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const sorted = [...tasks]
    .filter(t => t.status !== 'completed')
    .sort((a, b) => a.priority - b.priority);

  const pendingCount = sorted.filter(t => t.status === 'pending' || t.status === 'in_progress' || t.status === 'dispatched').length;

  // Group by sprint for summary
  const sprintCounts: Record<string, number> = {};
  for (const t of sorted) {
    const s = getSprintLabel(t) || '??';
    sprintCounts[s] = (sprintCounts[s] || 0) + 1;
  }

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
        {/* Archive banner */}
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

        {/* Sprint summary bar */}
        {Object.keys(sprintCounts).length > 0 && (
          <div style={{
            padding: '4px 12px',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-secondary)',
            background: 'rgba(255,255,255,0.02)',
            borderBottom: '1px solid rgba(255,255,255,0.05)',
            display: 'flex',
            gap: '10px',
          }}>
            {Object.entries(sprintCounts).map(([sprint, count]) => (
              <span key={sprint}>
                <span style={{ color: 'var(--amber)', fontWeight: 700 }}>{sprint}</span>
                <span style={{ marginLeft: '3px' }}>{count}</span>
              </span>
            ))}
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
          const isExpanded = expandedId === task.id;
          const isBug = task.id.startsWith('BUG-');

          return (
            <div key={task.id}>
              <div
                className="feature-row"
                style={{ cursor: 'pointer' }}
                onClick={() => setExpandedId(isExpanded ? null : task.id)}
              >
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
                    flexShrink: 0,
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
                    flexShrink: 0,
                  }}>
                    {typeLabel}
                  </span>
                )}
                {isBug && (
                  <span style={{
                    fontSize: '9px',
                    fontWeight: 700,
                    padding: '1px 4px',
                    borderRadius: '2px',
                    background: 'rgba(255,60,60,0.15)',
                    color: '#ff6b6b',
                    marginRight: '4px',
                    letterSpacing: '0.5px',
                    flexShrink: 0,
                  }}>
                    BUG
                  </span>
                )}
                <span className="feature-title" style={{
                  whiteSpace: isExpanded ? 'normal' : 'nowrap',
                  overflow: isExpanded ? 'visible' : 'hidden',
                  textOverflow: isExpanded ? 'unset' : 'ellipsis',
                }}>
                  {task.title}
                </span>
                <span style={{
                  marginLeft: 'auto',
                  flexShrink: 0,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                }}>
                  <span className={`feature-status feature-status--${task.status}`}>
                    {task.status.replace('_', ' ')}
                  </span>
                  <span style={{
                    fontSize: '9px',
                    color: 'var(--text-dim)',
                    transform: isExpanded ? 'rotate(180deg)' : 'rotate(0)',
                    transition: 'transform 0.15s ease',
                  }}>
                    &#9660;
                  </span>
                </span>
              </div>

              {/* Expanded detail panel */}
              {isExpanded && (
                <div style={{
                  padding: '6px 12px 8px 28px',
                  fontSize: '11px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-secondary)',
                  background: 'rgba(0,255,136,0.02)',
                  borderBottom: '1px solid rgba(255,255,255,0.05)',
                  lineHeight: '1.5',
                }}>
                  {/* Task ID */}
                  <div style={{ marginBottom: '4px' }}>
                    <span style={{ color: 'var(--text-dim)' }}>ID: </span>
                    <span style={{ color: 'var(--amber)' }}>{task.id}</span>
                    <span style={{ color: 'var(--text-dim)', marginLeft: '10px' }}>P{task.priority}</span>
                  </div>

                  {/* Description */}
                  {task.description && (
                    <div style={{
                      marginBottom: '4px',
                      color: 'var(--text-primary, #ccc)',
                      fontSize: '10px',
                      lineHeight: '1.6',
                    }}>
                      {task.description}
                    </div>
                  )}

                  {/* Files */}
                  {task.files && task.files.length > 0 && (
                    <div style={{ marginBottom: '2px' }}>
                      <span style={{ color: 'var(--text-dim)' }}>Files: </span>
                      {task.files.map((f, i) => (
                        <span key={f}>
                          <span style={{ color: 'var(--cyan, #88ddff)' }}>{f.split('/').pop()}</span>
                          {i < task.files!.length - 1 && <span style={{ color: 'var(--text-dim)' }}>, </span>}
                        </span>
                      ))}
                    </div>
                  )}

                  {/* Agent */}
                  {task.agent && (
                    <div>
                      <span style={{ color: 'var(--text-dim)' }}>Agent: </span>
                      <span style={{ color: 'var(--green)' }}>{task.agent}</span>
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
