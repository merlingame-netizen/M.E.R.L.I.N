import { useMissionStore } from '../store/mission-store';

function getSprintLabel(task: { id: string; sprint?: string }): string | null {
  if (task.sprint) return task.sprint.toUpperCase();
  if (task.id.startsWith('S1-')) return 'S1';
  if (task.id.startsWith('S2-')) return 'S2';
  if (task.id.startsWith('S3-')) return 'S3';
  if (task.id.startsWith('S4-')) return 'S4';
  return null;
}

function formatTime(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

const TASKS_PER_CYCLE = 2;

export function ExecutionTimeline() {
  const featureQueue = useMissionStore(s => s.featureQueue);
  const nextCycleAt = useMissionStore(s => s.nextCycleAt);

  const pending = [...featureQueue]
    .filter(t => t.status === 'pending')
    .sort((a, b) => a.priority - b.priority);

  const active = featureQueue.filter(t => t.status === 'in_progress' || t.status === 'dispatched');

  if (pending.length === 0 && active.length === 0) return null;

  // Calculate cycle slots
  const nextCycle = nextCycleAt ? new Date(nextCycleAt) : null;
  const slots: Array<{
    cycleLabel: string;
    cycleTime: string;
    tasks: typeof pending;
    isCurrent: boolean;
  }> = [];

  // Current cycle (active tasks)
  if (active.length > 0) {
    slots.push({
      cycleLabel: 'NOW',
      cycleTime: 'In progress',
      tasks: active,
      isCurrent: true,
    });
  }

  // Future cycles
  let taskIdx = 0;
  let cycleOffset = 0;
  while (taskIdx < pending.length && cycleOffset < 12) {
    const cycleTasks = pending.slice(taskIdx, taskIdx + TASKS_PER_CYCLE);
    const cycleTime = nextCycle
      ? new Date(nextCycle.getTime() + cycleOffset * 3600_000)
      : null;

    slots.push({
      cycleLabel: cycleOffset === 0 ? 'NEXT' : `+${cycleOffset + 1}h`,
      cycleTime: cycleTime ? formatTime(cycleTime) : '—',
      tasks: cycleTasks,
      isCurrent: false,
    });

    taskIdx += TASKS_PER_CYCLE;
    cycleOffset++;
  }

  const remaining = pending.length - taskIdx;

  return (
    <div className="panel">
      <div className="panel-header">
        Execution Schedule
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {pending.length} QUEUED
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {slots.map((slot, slotIdx) => (
          <div key={slotIdx} style={{
            borderBottom: '1px solid rgba(255,255,255,0.04)',
          }}>
            {/* Cycle header */}
            <div style={{
              padding: '4px 12px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              background: slot.isCurrent
                ? 'rgba(100,180,255,0.08)'
                : slotIdx === (active.length > 0 ? 1 : 0)
                ? 'rgba(255,0,255,0.06)'
                : 'transparent',
            }}>
              {/* Timeline dot */}
              <span style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: slot.isCurrent
                  ? '#88ccff'
                  : slotIdx === (active.length > 0 ? 1 : 0)
                  ? '#ff00ff'
                  : 'rgba(255,255,255,0.15)',
                boxShadow: slot.isCurrent
                  ? '0 0 6px rgba(100,180,255,0.5)'
                  : slotIdx === (active.length > 0 ? 1 : 0)
                  ? '0 0 6px rgba(255,0,255,0.4)'
                  : 'none',
                flexShrink: 0,
              }} />
              <span style={{
                fontWeight: 700,
                color: slot.isCurrent
                  ? '#88ccff'
                  : slotIdx === (active.length > 0 ? 1 : 0)
                  ? '#ff00ff'
                  : 'var(--text-dim)',
                minWidth: '36px',
              }}>
                {slot.cycleLabel}
              </span>
              <span style={{
                color: 'var(--text-dim)',
                fontSize: '9px',
              }}>
                {slot.cycleTime}
              </span>
            </div>

            {/* Tasks in this cycle */}
            {slot.tasks.map(task => {
              const sprint = getSprintLabel(task);
              const typeLabel = task.type?.toUpperCase() || 'DEV';
              return (
                <div key={task.id} style={{
                  padding: '3px 12px 3px 32px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                }}>
                  {sprint && (
                    <span style={{
                      fontSize: '8px',
                      fontWeight: 700,
                      padding: '0 3px',
                      borderRadius: '2px',
                      background: 'rgba(255,255,255,0.06)',
                      color: 'var(--text-secondary)',
                      flexShrink: 0,
                    }}>
                      {sprint}
                    </span>
                  )}
                  <span style={{
                    fontSize: '8px',
                    fontWeight: 700,
                    padding: '0 3px',
                    borderRadius: '2px',
                    background: typeLabel === 'TEST' ? 'rgba(255,165,0,0.12)' : typeLabel === 'FIX' ? 'rgba(255,60,60,0.12)' : 'rgba(0,255,136,0.12)',
                    color: typeLabel === 'TEST' ? 'var(--amber)' : typeLabel === 'FIX' ? '#ff6b6b' : 'var(--green)',
                    flexShrink: 0,
                  }}>
                    {typeLabel}
                  </span>
                  <span style={{
                    color: slot.isCurrent ? '#88ccff' : 'var(--text-secondary)',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                    flex: 1,
                  }}>
                    {task.title}
                  </span>
                  <span style={{
                    fontSize: '8px',
                    color: 'var(--text-dim)',
                    flexShrink: 0,
                  }}>
                    P{task.priority}
                  </span>
                </div>
              );
            })}
          </div>
        ))}

        {remaining > 0 && (
          <div style={{
            padding: '6px 12px',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-dim)',
            textAlign: 'center',
          }}>
            +{remaining} more tasks in backlog
          </div>
        )}
      </div>
    </div>
  );
}
