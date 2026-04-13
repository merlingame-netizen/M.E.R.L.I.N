import { useMissionStore } from '../store/mission-store';

function formatTimeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function DevCycleSummary() {
  const cycleHistory = useMissionStore(s => s.cycleHistory);
  const alerts = useMissionStore(s => s.alerts);
  const gitActivity = useMissionStore(s => s.gitActivity);

  // Find last meaningful cycle
  const lastCycle = cycleHistory.length > 0 ? cycleHistory[0] : null;

  // Find last cycle-related alerts (up to 5)
  const cycleAlerts = alerts
    .filter(a => a.source === 'orchestrator' && a.level !== 'INFO')
    .slice(0, 5);

  // Count dev commits in last 24h
  const oneDayAgo = Date.now() - 86400_000;
  const recentCommits = gitActivity.filter(c => new Date(c.date).getTime() > oneDayAgo);
  const devCommits = recentCommits.filter(c => c.type === 'feat' || c.type === 'fix');

  const hasData = lastCycle || cycleAlerts.length > 0 || recentCommits.length > 0;

  return (
    <div className="panel">
      <div className="panel-header">
        Dev Cycle Summary
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          LIVE
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* 24h stats banner */}
        <div style={{
          padding: '8px 12px',
          fontSize: '11px',
          fontFamily: 'var(--font-mono)',
          background: 'rgba(0, 255, 136, 0.04)',
          borderBottom: '1px solid rgba(0, 255, 136, 0.1)',
          display: 'flex',
          gap: '16px',
          alignItems: 'center',
        }}>
          <div>
            <span style={{ color: 'var(--green)', fontWeight: 700, fontSize: '16px' }}>
              {recentCommits.length}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>
              commits/24h
            </span>
          </div>
          <div>
            <span style={{
              color: devCommits.length > 0 ? 'var(--green)' : 'var(--amber)',
              fontWeight: 700,
              fontSize: '16px',
            }}>
              {devCommits.length}
            </span>
            <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>
              feat+fix
            </span>
          </div>
          {lastCycle && (
            <div>
              <span style={{ color: 'var(--amber)', fontWeight: 700, fontSize: '16px' }}>
                {lastCycle.tasksCompleted}
              </span>
              <span style={{ color: 'var(--text-dim)', fontSize: '10px', marginLeft: '4px' }}>
                tasks last cycle
              </span>
            </div>
          )}
        </div>

        {!hasData ? (
          <div style={{
            padding: '16px 12px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-dim)',
            textAlign: 'center',
          }}>
            No cycle data yet — run a dev cycle to see results here
          </div>
        ) : (
          <>
            {/* Last cycle detail */}
            {lastCycle && (
              <div style={{
                padding: '8px 12px',
                borderBottom: '1px solid rgba(255,255,255,0.04)',
              }}>
                <div style={{
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-secondary)',
                  marginBottom: '4px',
                }}>
                  LAST CYCLE
                </div>
                <div style={{
                  fontSize: '11px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-primary)',
                  display: 'flex',
                  gap: '8px',
                  alignItems: 'center',
                }}>
                  <span style={{ color: 'var(--amber)' }}>{lastCycle.cycleId || '—'}</span>
                  <span style={{ color: 'var(--text-dim)' }}>|</span>
                  <span style={{ color: 'var(--green)' }}>
                    {lastCycle.tasksCompleted} done
                  </span>
                  {lastCycle.tasksFailed > 0 && (
                    <span style={{ color: '#ff6b6b' }}>
                      {lastCycle.tasksFailed} failed
                    </span>
                  )}
                  {lastCycle.startedAt && (
                    <span style={{ color: 'var(--text-dim)', marginLeft: 'auto', fontSize: '10px' }}>
                      {formatTimeAgo(lastCycle.startedAt)}
                    </span>
                  )}
                </div>
                {lastCycle.agentsUsed.length > 0 && (
                  <div style={{
                    marginTop: '4px',
                    fontSize: '10px',
                    fontFamily: 'var(--font-mono)',
                    color: 'var(--text-dim)',
                  }}>
                    Agents: {lastCycle.agentsUsed.join(', ')}
                  </div>
                )}
              </div>
            )}

            {/* Recent cycle events */}
            {cycleAlerts.length > 0 && (
              <div style={{ padding: '6px 12px' }}>
                <div style={{
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-secondary)',
                  marginBottom: '4px',
                }}>
                  RECENT EVENTS
                </div>
                {cycleAlerts.map((alert) => (
                  <div key={alert.id} style={{
                    fontSize: '10px',
                    fontFamily: 'var(--font-mono)',
                    color: alert.level === 'SUCCESS' ? 'var(--green)'
                      : alert.level === 'ERROR' ? '#ff6b6b'
                      : alert.level === 'WARN' ? 'var(--amber)'
                      : 'var(--text-secondary)',
                    padding: '2px 0',
                    borderBottom: '1px solid rgba(255,255,255,0.03)',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}>
                    {alert.message}
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
