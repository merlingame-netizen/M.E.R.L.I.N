import { useMissionStore } from '../store/mission-store';

const TYPE_COLORS: Record<string, { bg: string; color: string }> = {
  feat: { bg: 'rgba(0,255,136,0.15)', color: 'var(--green)' },
  fix: { bg: 'rgba(255,60,60,0.15)', color: '#ff6b6b' },
  test: { bg: 'rgba(255,165,0,0.15)', color: 'var(--amber)' },
  refactor: { bg: 'rgba(100,180,255,0.15)', color: '#88bbff' },
  docs: { bg: 'rgba(180,140,255,0.15)', color: '#b08cff' },
  chore: { bg: 'rgba(255,255,255,0.06)', color: 'var(--text-dim)' },
  perf: { bg: 'rgba(0,255,200,0.15)', color: '#00ffc8' },
  ci: { bg: 'rgba(255,255,255,0.06)', color: 'var(--text-dim)' },
};

function formatTimeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function ActiveMissions() {
  const commits = useMissionStore(s => s.gitActivity);

  const gameDevCount = commits.filter(c =>
    c.type === 'feat' || c.type === 'fix' || c.type === 'test'
  ).length;

  return (
    <div className="panel">
      <div className="panel-header">
        Recent Dev Activity
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {commits.length > 0 ? `${gameDevCount}/${commits.length} DEV` : 'LIVE'}
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {commits.length === 0 ? (
          <div style={{
            padding: '16px 12px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-dim)',
            textAlign: 'center',
          }}>
            Loading git activity...
          </div>
        ) : (
          commits.map((commit) => {
            const style = TYPE_COLORS[commit.type] ?? { bg: 'rgba(255,255,255,0.06)', color: 'var(--text-dim)' };
            // Strip type prefix from message for display
            const displayMsg = commit.message.replace(/^\w+(\([^)]+\))?:\s*/, '');

            return (
              <div key={commit.sha} className="mission-row">
                <span style={{
                  fontSize: '9px',
                  fontWeight: 700,
                  padding: '1px 4px',
                  borderRadius: '2px',
                  background: style.bg,
                  color: style.color,
                  letterSpacing: '0.5px',
                  flexShrink: 0,
                  minWidth: '36px',
                  textAlign: 'center',
                }}>
                  {commit.type.toUpperCase()}
                </span>
                {commit.scope && (
                  <span style={{
                    fontSize: '9px',
                    padding: '1px 3px',
                    borderRadius: '2px',
                    background: 'rgba(255,255,255,0.06)',
                    color: 'var(--text-secondary)',
                    flexShrink: 0,
                  }}>
                    {commit.scope}
                  </span>
                )}
                <span className="mission-task" title={commit.message}>
                  {displayMsg}
                </span>
                <span className="mission-time">
                  {formatTimeAgo(commit.date)}
                </span>
                <span style={{
                  fontSize: '9px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-dim)',
                  flexShrink: 0,
                }}>
                  {commit.sha}
                </span>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
