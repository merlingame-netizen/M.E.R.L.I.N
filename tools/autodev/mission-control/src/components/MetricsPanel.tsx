import { useState, useEffect } from 'react';
import { useMissionStore } from '../store/mission-store';

export function MetricsPanel() {
  const featureQueue = useMissionStore(s => s.featureQueue);
  const agents = useMissionStore(s => s.agents);
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions);
  const completedCount = useMissionStore(s => s.completedCount);
  const gitActivity = useMissionStore(s => s.gitActivity);
  const nextCycleAt = useMissionStore(s => s.nextCycleAt);

  const pending = featureQueue.filter(t => t.status === 'pending');
  const inProgress = featureQueue.filter(t => t.status === 'in_progress' || t.status === 'dispatched');
  const blocked = featureQueue.filter(t => t.status === 'blocked');
  const activeAgents = agents.filter(a => a.state === 'running').length;
  const pendingFeedback = feedbackQuestions.filter(q => q.status === 'pending').length;

  // Last commit time
  const lastCommit = gitActivity.length > 0 ? gitActivity[0] : null;
  const lastCommitAgo = lastCommit
    ? formatTimeAgo(lastCommit.date)
    : null;

  // Next cycle countdown
  const [countdown, setCountdown] = useState('');
  useEffect(() => {
    if (!nextCycleAt) return;
    function tick() {
      const diff = Math.max(0, Math.floor((new Date(nextCycleAt!).getTime() - Date.now()) / 1000));
      const m = Math.floor(diff / 60);
      const s = diff % 60;
      setCountdown(`${m}:${String(s).padStart(2, '0')}`);
    }
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [nextCycleAt]);

  return (
    <div className="panel" style={{ height: 'auto' }}>
      <div className="panel-header">
        Telemetry
        {lastCommitAgo && (
          <span style={{
            marginLeft: 'auto',
            fontSize: '10px',
            color: 'var(--text-dim)',
            fontFamily: 'var(--font-mono)',
            letterSpacing: '0',
          }}>
            LAST COMMIT {lastCommitAgo}
          </span>
        )}
      </div>
      <div className="panel-body">
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))',
          gap: '8px',
        }}>
          {/* Completed */}
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--green)', textShadow: 'var(--glow-green)' }}>
              {completedCount}
            </div>
            <div className="metric-label">Done</div>
          </div>

          {/* In Progress — with task names */}
          <div className="metric-card" title={inProgress.map(t => t.title).join('\n')}>
            <div className="metric-value" style={{ color: inProgress.length > 0 ? '#88ccff' : 'var(--text-dim)' }}>
              {inProgress.length}
            </div>
            <div className="metric-label">Active</div>
            {inProgress.length > 0 && (
              <div style={{
                fontSize: '8px',
                fontFamily: 'var(--font-mono)',
                color: '#88ccff',
                marginTop: '3px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                maxWidth: '100%',
              }}>
                {inProgress[0]?.title.slice(0, 25)}
                {inProgress.length > 1 && ` +${inProgress.length - 1}`}
              </div>
            )}
          </div>

          {/* Planned */}
          <div className="metric-card">
            <div className="metric-value" style={{ color: 'var(--amber)', textShadow: 'var(--glow-amber)' }}>
              {pending.length}
            </div>
            <div className="metric-label">Planned</div>
          </div>

          {/* Blocked */}
          {blocked.length > 0 && (
            <div className="metric-card" title={blocked.map(t => t.title).join('\n')}>
              <div className="metric-value" style={{ color: '#ff6b6b' }}>
                {blocked.length}
              </div>
              <div className="metric-label">Blocked</div>
              <div style={{
                fontSize: '8px',
                fontFamily: 'var(--font-mono)',
                color: '#ff6b6b',
                marginTop: '3px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}>
                {blocked[0]?.title.slice(0, 25)}
              </div>
            </div>
          )}

          {/* Agents */}
          <div className="metric-card">
            <div className="metric-value" style={{
              color: activeAgents > 0 ? 'var(--green)' : 'var(--text-dim)',
              textShadow: activeAgents > 0 ? 'var(--glow-green)' : 'none',
            }}>
              {activeAgents > 0 ? activeAgents : agents.length > 0 ? `0/${agents.length}` : '—'}
            </div>
            <div className="metric-label">Agents</div>
          </div>

          {/* Next cycle countdown */}
          {countdown && (
            <div className="metric-card">
              <div className="metric-value" style={{ color: '#ff00ff', textShadow: '0 0 8px rgba(255,0,255,0.4)' }}>
                {countdown}
              </div>
              <div className="metric-label">Next Cycle</div>
            </div>
          )}

          {/* Director feedback */}
          {pendingFeedback > 0 && (
            <div className="metric-card">
              <div className="metric-value" style={{ color: 'var(--amber)', textShadow: 'var(--glow-amber)' }}>
                {pendingFeedback}
              </div>
              <div className="metric-label">Needs You</div>
            </div>
          )}
        </div>

        {/* Next up banner — shows what the bot will work on next */}
        {pending.length > 0 && (
          <div style={{
            marginTop: '8px',
            padding: '6px 10px',
            background: 'rgba(255,0,255,0.06)',
            border: '1px solid rgba(255,0,255,0.15)',
            borderRadius: '3px',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
          }}>
            <span style={{
              color: '#ff00ff',
              fontWeight: 700,
              letterSpacing: '1px',
              flexShrink: 0,
            }}>
              NEXT UP
            </span>
            <span style={{ color: 'var(--text-dim)' }}>|</span>
            <span style={{
              color: 'var(--text-primary)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}>
              {pending[0]?.title}
            </span>
            <span style={{
              marginLeft: 'auto',
              color: 'var(--text-dim)',
              flexShrink: 0,
              fontSize: '9px',
            }}>
              P{pending[0]?.priority}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

function formatTimeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}
