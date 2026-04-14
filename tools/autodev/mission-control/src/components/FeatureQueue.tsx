import { useState } from 'react';
import { useMissionStore } from '../store/mission-store';

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

type StatusGroup = 'active' | 'planned' | 'blocked';

interface GroupConfig {
  label: string;
  color: string;
  bg: string;
  border: string;
  statuses: string[];
}

const GROUPS: Record<StatusGroup, GroupConfig> = {
  active: {
    label: 'IN PROGRESS',
    color: '#88ccff',
    bg: 'rgba(100,180,255,0.08)',
    border: 'rgba(100,180,255,0.2)',
    statuses: ['in_progress', 'dispatched'],
  },
  planned: {
    label: 'PLANNED',
    color: 'var(--amber)',
    bg: 'rgba(255,165,0,0.05)',
    border: 'rgba(255,165,0,0.15)',
    statuses: ['pending'],
  },
  blocked: {
    label: 'BLOCKED',
    color: '#ff6b6b',
    bg: 'rgba(255,60,60,0.06)',
    border: 'rgba(255,60,60,0.2)',
    statuses: ['blocked'],
  },
};

export function FeatureQueue() {
  const tasks = useMissionStore(s => s.featureQueue);
  const completedCount = useMissionStore(s => s.completedCount);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const nonCompleted = [...tasks]
    .filter(t => t.status !== 'completed')
    .sort((a, b) => a.priority - b.priority);

  const grouped: Record<StatusGroup, typeof nonCompleted> = {
    active: nonCompleted.filter(t => GROUPS.active.statuses.includes(t.status)),
    planned: nonCompleted.filter(t => GROUPS.planned.statuses.includes(t.status)),
    blocked: nonCompleted.filter(t => GROUPS.blocked.statuses.includes(t.status)),
  };

  const total = nonCompleted.length + completedCount;
  const progressPct = total > 0 ? Math.round((completedCount / total) * 100) : 0;

  return (
    <div className="panel">
      <div className="panel-header">
        Task Board
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {completedCount}/{total}
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* Progress bar */}
        {total > 0 && (
          <div style={{ padding: '8px 12px', borderBottom: '1px solid rgba(255,255,255,0.04)' }}>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: 'var(--text-secondary)',
              marginBottom: '4px',
            }}>
              <span style={{ color: 'var(--green)' }}>{completedCount} DONE</span>
              <span>{grouped.active.length} ACTIVE</span>
              <span style={{ color: 'var(--amber)' }}>{grouped.planned.length} PLANNED</span>
              <span>{progressPct}%</span>
            </div>
            <div style={{
              height: '6px',
              background: 'rgba(255,255,255,0.06)',
              borderRadius: '3px',
              overflow: 'hidden',
              display: 'flex',
            }}>
              {/* Done segment */}
              <div style={{
                width: `${progressPct}%`,
                background: 'var(--green)',
                boxShadow: '0 0 6px rgba(0,255,136,0.4)',
              }} />
              {/* Active segment */}
              {grouped.active.length > 0 && (
                <div style={{
                  width: `${(grouped.active.length / total) * 100}%`,
                  background: '#88ccff',
                  boxShadow: '0 0 4px rgba(100,180,255,0.3)',
                }} />
              )}
            </div>
          </div>
        )}

        {/* Status groups */}
        {(['active', 'blocked', 'planned'] as StatusGroup[]).map(groupKey => {
          const group = GROUPS[groupKey];
          const groupTasks = grouped[groupKey];
          if (groupTasks.length === 0) return null;

          return (
            <div key={groupKey}>
              {/* Group header */}
              <div style={{
                padding: '5px 12px',
                fontSize: '10px',
                fontFamily: 'var(--font-mono)',
                fontWeight: 700,
                color: group.color,
                background: group.bg,
                borderBottom: `1px solid ${group.border}`,
                borderTop: `1px solid ${group.border}`,
                letterSpacing: '1px',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
              }}>
                <span style={{
                  width: '6px',
                  height: '6px',
                  borderRadius: '50%',
                  background: group.color,
                  boxShadow: groupKey === 'active' ? `0 0 6px ${group.color}` : 'none',
                  display: 'inline-block',
                }} />
                {group.label}
                <span style={{ color: 'var(--text-dim)', fontWeight: 400 }}>({groupTasks.length})</span>
              </div>

              {/* Tasks */}
              {groupTasks.map((task) => {
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
                      {sprint && (
                        <span style={{
                          fontSize: '9px',
                          fontWeight: 700,
                          padding: '1px 3px',
                          borderRadius: '2px',
                          background: 'rgba(255,255,255,0.06)',
                          color: 'var(--text-secondary)',
                          letterSpacing: '0.5px',
                          flexShrink: 0,
                        }}>
                          {sprint}
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
                          letterSpacing: '0.5px',
                          flexShrink: 0,
                        }}>
                          BUG
                        </span>
                      )}
                      <span style={{
                        fontSize: '9px',
                        fontWeight: 700,
                        padding: '1px 4px',
                        borderRadius: '2px',
                        background: typeLabel === 'TEST' ? 'rgba(255,165,0,0.15)' : typeLabel === 'FIX' ? 'rgba(255,60,60,0.15)' : 'rgba(0,255,136,0.15)',
                        color: typeLabel === 'TEST' ? 'var(--amber)' : typeLabel === 'FIX' ? '#ff6b6b' : 'var(--green)',
                        letterSpacing: '0.5px',
                        flexShrink: 0,
                      }}>
                        {typeLabel}
                      </span>
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
                        fontSize: '9px',
                        color: 'var(--text-dim)',
                        transform: isExpanded ? 'rotate(180deg)' : 'rotate(0)',
                        transition: 'transform 0.15s ease',
                      }}>
                        &#9660;
                      </span>
                    </div>

                    {isExpanded && (
                      <div style={{
                        padding: '6px 12px 8px 20px',
                        fontSize: '11px',
                        fontFamily: 'var(--font-mono)',
                        color: 'var(--text-secondary)',
                        background: 'rgba(0,255,136,0.02)',
                        borderBottom: '1px solid rgba(255,255,255,0.05)',
                        lineHeight: '1.5',
                      }}>
                        <div style={{ marginBottom: '4px' }}>
                          <span style={{ color: 'var(--text-dim)' }}>ID: </span>
                          <span style={{ color: 'var(--amber)' }}>{task.id}</span>
                          <span style={{ color: 'var(--text-dim)', marginLeft: '10px' }}>P{task.priority}</span>
                        </div>
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
          );
        })}

        {nonCompleted.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px', fontFamily: 'var(--font-mono)' }}>
            All tasks completed
          </div>
        )}
      </div>
    </div>
  );
}
