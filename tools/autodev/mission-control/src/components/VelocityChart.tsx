import { useMissionStore } from '../store/mission-store';

export function VelocityChart() {
  const gitActivity = useMissionStore(s => s.gitActivity);
  const featureQueue = useMissionStore(s => s.featureQueue);
  const completedCount = useMissionStore(s => s.completedCount);

  // Build daily commit counts for last 7 days
  const now = Date.now();
  const days: { label: string; feat: number; fix: number; other: number }[] = [];

  for (let i = 6; i >= 0; i--) {
    const dayStart = now - i * 86400_000;
    const dayEnd = dayStart + 86400_000;
    const dayCommits = gitActivity.filter(c => {
      const t = new Date(c.date).getTime();
      return t >= dayStart && t < dayEnd;
    });

    const d = new Date(dayStart);
    days.push({
      label: `${d.getMonth() + 1}/${d.getDate()}`,
      feat: dayCommits.filter(c => c.type === 'feat').length,
      fix: dayCommits.filter(c => c.type === 'fix').length,
      other: dayCommits.filter(c => c.type !== 'feat' && c.type !== 'fix').length,
    });
  }

  const maxCommits = Math.max(1, ...days.map(d => d.feat + d.fix + d.other));
  const barHeight = 60;

  // Queue stats
  const pending = featureQueue.filter(t => t.status === 'pending').length;
  const inProgress = featureQueue.filter(t => t.status === 'in_progress' || t.status === 'dispatched').length;

  return (
    <div className="panel">
      <div className="panel-header">
        Velocity
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          7 DAYS
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* Stats row */}
        <div style={{
          padding: '8px 12px',
          display: 'flex',
          gap: '16px',
          fontSize: '11px',
          fontFamily: 'var(--font-mono)',
          borderBottom: '1px solid rgba(255,255,255,0.04)',
        }}>
          <div>
            <span style={{ color: 'var(--green)', fontWeight: 700, fontSize: '16px' }}>
              {completedCount}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>done</span>
          </div>
          <div>
            <span style={{ color: 'var(--amber)', fontWeight: 700, fontSize: '16px' }}>
              {pending}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>pending</span>
          </div>
          <div>
            <span style={{ color: '#88ccff', fontWeight: 700, fontSize: '16px' }}>
              {inProgress}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>active</span>
          </div>
          <div>
            <span style={{ color: 'var(--text-primary)', fontWeight: 700, fontSize: '16px' }}>
              {gitActivity.length}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>commits</span>
          </div>
        </div>

        {/* Bar chart */}
        <div style={{
          padding: '8px 12px 4px',
          display: 'flex',
          gap: '4px',
          alignItems: 'flex-end',
          height: `${barHeight + 20}px`,
        }}>
          {days.map((day, i) => {
            const total = day.feat + day.fix + day.other;
            const featH = (day.feat / maxCommits) * barHeight;
            const fixH = (day.fix / maxCommits) * barHeight;
            const otherH = (day.other / maxCommits) * barHeight;
            const isToday = i === days.length - 1;
            return (
              <div key={day.label} style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '0',
              }}>
                {/* Count label */}
                {total > 0 && (
                  <span style={{
                    fontSize: '8px',
                    fontFamily: 'var(--font-mono)',
                    color: 'var(--text-dim)',
                    marginBottom: '2px',
                  }}>
                    {total}
                  </span>
                )}
                {/* Stacked bars */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', width: '100%' }}>
                  {day.other > 0 && (
                    <div style={{
                      height: `${otherH}px`,
                      background: 'rgba(255,255,255,0.15)',
                      borderRadius: '2px 2px 0 0',
                    }} />
                  )}
                  {day.fix > 0 && (
                    <div style={{
                      height: `${fixH}px`,
                      background: '#ff6b6b',
                      borderRadius: day.other > 0 ? '0' : '2px 2px 0 0',
                    }} />
                  )}
                  {day.feat > 0 && (
                    <div style={{
                      height: `${featH}px`,
                      background: 'var(--green)',
                      borderRadius: '0 0 2px 2px',
                    }} />
                  )}
                  {total === 0 && (
                    <div style={{
                      height: '2px',
                      background: 'rgba(255,255,255,0.06)',
                      borderRadius: '1px',
                    }} />
                  )}
                </div>
                {/* Day label */}
                <span style={{
                  fontSize: '8px',
                  fontFamily: 'var(--font-mono)',
                  color: isToday ? 'var(--green)' : 'var(--text-dim)',
                  marginTop: '4px',
                }}>
                  {day.label}
                </span>
              </div>
            );
          })}
        </div>

        {/* Legend */}
        <div style={{
          padding: '4px 12px 6px',
          display: 'flex',
          gap: '12px',
          fontSize: '8px',
          fontFamily: 'var(--font-mono)',
          color: 'var(--text-dim)',
        }}>
          <span><span style={{ color: 'var(--green)' }}>///</span> feat</span>
          <span><span style={{ color: '#ff6b6b' }}>///</span> fix</span>
          <span><span style={{ color: 'rgba(255,255,255,0.4)' }}>///</span> other</span>
        </div>
      </div>
    </div>
  );
}
