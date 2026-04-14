import { useState } from 'react';
import { useMissionStore } from '../store/mission-store';

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffH = Math.floor(diffMs / 3600_000);
  if (diffH < 1) return `${Math.floor(diffMs / 60_000)}m ago`;
  if (diffH < 24) return `${diffH}h ago`;
  const diffD = Math.floor(diffH / 24);
  if (diffD < 7) return `${diffD}d ago`;
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

const VERDICT_STYLE: Record<string, { color: string; bg: string }> = {
  PASS: { color: 'var(--green)', bg: 'rgba(0,255,136,0.12)' },
  PARTIAL_PASS: { color: 'var(--amber)', bg: 'rgba(255,165,0,0.12)' },
  FAIL: { color: '#ff6b6b', bg: 'rgba(255,60,60,0.12)' },
};

export function CompletedTasks() {
  const completedTasks = useMissionStore(s => s.completedTasks);
  const [expanded, setExpanded] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  if (completedTasks.length === 0) return null;

  // Sort by completion date (newest first)
  const sorted = [...completedTasks].sort((a, b) => {
    const da = a.completed_at ? new Date(a.completed_at).getTime() : 0;
    const db = b.completed_at ? new Date(b.completed_at).getTime() : 0;
    return db - da;
  });

  const shown = expanded ? sorted : sorted.slice(0, 5);

  return (
    <div className="panel">
      <div className="panel-header">
        Completed Tasks
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--green)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {completedTasks.length} DONE
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {shown.map(task => {
          const verdict = (task as Record<string, unknown>).verdict as string | undefined;
          const notes = (task as Record<string, unknown>).notes as string | undefined;
          const lookup = verdict ? VERDICT_STYLE[verdict] : undefined;
          const vsColor = lookup?.color ?? 'var(--green)';
          const vsBg = lookup?.bg ?? 'rgba(0,255,136,0.12)';
          const isExpanded = expandedId === task.id;

          return (
            <div key={task.id}>
              <div
                style={{
                  padding: '6px 12px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  borderBottom: '1px solid rgba(255,255,255,0.03)',
                  cursor: notes ? 'pointer' : 'default',
                  fontSize: '11px',
                  fontFamily: 'var(--font-mono)',
                }}
                onClick={() => notes && setExpandedId(isExpanded ? null : task.id)}
              >
                {/* Verdict badge */}
                {verdict && (
                  <span style={{
                    fontSize: '8px',
                    fontWeight: 700,
                    padding: '1px 4px',
                    borderRadius: '2px',
                    background: vsBg,
                    color: vsColor,
                    letterSpacing: '0.5px',
                    flexShrink: 0,
                  }}>
                    {verdict}
                  </span>
                )}

                {/* Sprint */}
                {task.sprint && (
                  <span style={{
                    fontSize: '9px',
                    fontWeight: 700,
                    padding: '1px 3px',
                    borderRadius: '2px',
                    background: 'rgba(255,255,255,0.06)',
                    color: 'var(--text-secondary)',
                    flexShrink: 0,
                  }}>
                    {task.sprint}
                  </span>
                )}

                {/* Title */}
                <span style={{
                  color: 'var(--text-secondary)',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: isExpanded ? 'normal' : 'nowrap',
                  flex: 1,
                }}>
                  {task.title}
                </span>

                {/* Time */}
                {task.completed_at && (
                  <span style={{
                    fontSize: '9px',
                    color: 'var(--text-dim)',
                    flexShrink: 0,
                  }}>
                    {formatDate(task.completed_at)}
                  </span>
                )}
              </div>

              {/* Expanded notes */}
              {isExpanded && notes && (
                <div style={{
                  padding: '6px 12px 8px 24px',
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-dim)',
                  background: 'rgba(0,255,136,0.02)',
                  borderBottom: '1px solid rgba(255,255,255,0.05)',
                  lineHeight: '1.6',
                  whiteSpace: 'pre-wrap',
                  wordBreak: 'break-word',
                }}>
                  {notes}
                </div>
              )}
            </div>
          );
        })}

        {/* Show more/less */}
        {sorted.length > 5 && (
          <div
            style={{
              padding: '6px 12px',
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: 'var(--green)',
              cursor: 'pointer',
              textAlign: 'center',
              borderTop: '1px solid rgba(255,255,255,0.04)',
            }}
            onClick={() => setExpanded(!expanded)}
          >
            {expanded ? 'SHOW LESS' : `SHOW ALL ${sorted.length}`}
          </div>
        )}
      </div>
    </div>
  );
}
