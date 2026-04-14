import { useMissionStore } from '../store/mission-store';

const SPECIALISTS = [
  { id: 0, name: 'Scene Flow', icon: '🔀', color: '#00ff88' },
  { id: 1, name: 'Visual', icon: '🎨', color: '#ff88ff' },
  { id: 2, name: 'Game Design', icon: '📐', color: '#ffaa00' },
  { id: 3, name: 'SFX/Audio', icon: '🔊', color: '#88ccff' },
  { id: 4, name: 'Animation', icon: '🎬', color: '#ff6688' },
  { id: 5, name: 'Shader/VFX', icon: '✨', color: '#aa88ff' },
  { id: 6, name: 'UX/Access.', icon: '👆', color: '#66ffcc' },
  { id: 7, name: 'Narrative', icon: '📜', color: '#ffcc66' },
  { id: 8, name: 'LLM Pipe', icon: '🧠', color: '#ff8844' },
  { id: 9, name: 'Save/Load', icon: '💾', color: '#88ff88' },
  { id: 10, name: 'Perf/Code', icon: '⚡', color: '#ffff66' },
  { id: 11, name: 'Factions', icon: '⚔️', color: '#ff4444' },
  { id: 12, name: 'Minigames', icon: '🎮', color: '#44ffaa' },
  { id: 13, name: '3D Assets', icon: '🏗️', color: '#cc88ff' },
  { id: 14, name: 'E2E Integ.', icon: '🔗', color: '#88ffff' },
  { id: 15, name: 'Meta-Evo', icon: '🧬', color: '#ff00ff' },
];

function formatTimeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function SpecialistRotation() {
  const alerts = useMissionStore(s => s.alerts);
  const gitActivity = useMissionStore(s => s.gitActivity);

  // Count cycle_update events to determine current specialist
  const cycleEvents = alerts.filter(a =>
    a.source === 'orchestrator' || a.message.includes('SPECIALIST')
  );
  const eventCount = cycleEvents.length;
  const currentSpecialist = eventCount % 16;
  const nextSpecialist = (eventCount + 1) % 16;
  const current = SPECIALISTS[currentSpecialist] ?? SPECIALISTS[0]!;
  const next = SPECIALISTS[nextSpecialist] ?? SPECIALISTS[1]!;

  // Find last specialist-related commit
  const lastSpecialistCommit = gitActivity.find(c =>
    c.message.toLowerCase().includes('specialist') ||
    c.message.toLowerCase().includes('audit')
  );

  // Count how many specialists have run (from commits)
  const specialistCommits = gitActivity.filter(c =>
    c.message.toLowerCase().includes('specialist') ||
    c.message.toLowerCase().includes('audit')
  );

  return (
    <div className="panel">
      <div className="panel-header">
        Specialist Rotation
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: current.color,
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          #{current.id} ACTIVE
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* Current specialist banner */}
        <div style={{
          padding: '10px 12px',
          background: `${current.color}11`,
          borderBottom: `1px solid ${current.color}33`,
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
        }}>
          <span style={{ fontSize: '24px' }}>{current.icon}</span>
          <div>
            <div style={{
              fontSize: '13px',
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              color: current.color,
            }}>
              {current.name}
            </div>
            <div style={{
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: 'var(--text-dim)',
            }}>
              Current auditor — cycle #{eventCount}
            </div>
          </div>
          <div style={{ marginLeft: 'auto', textAlign: 'right' }}>
            <div style={{
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: 'var(--text-dim)',
            }}>
              NEXT
            </div>
            <div style={{
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
              color: next.color,
            }}>
              {next.icon} {next.name}
            </div>
          </div>
        </div>

        {/* Last audit info */}
        {lastSpecialistCommit && (
          <div style={{
            padding: '6px 12px',
            borderBottom: '1px solid rgba(255,255,255,0.04)',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-secondary)',
          }}>
            Last audit: {lastSpecialistCommit.message.substring(0, 60)}
            <span style={{ color: 'var(--text-dim)', marginLeft: '8px' }}>
              {formatTimeAgo(lastSpecialistCommit.date)}
            </span>
          </div>
        )}

        {/* Specialist grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(8, 1fr)',
          gap: '2px',
          padding: '8px',
        }}>
          {SPECIALISTS.map(spec => {
            const isActive = spec.id === currentSpecialist;
            const isNext = spec.id === nextSpecialist;
            const hasRun = specialistCommits.some(c =>
              c.message.includes(`#${spec.id}`) || c.message.toLowerCase().includes(spec.name.toLowerCase())
            );
            return (
              <div
                key={spec.id}
                title={`#${spec.id}: ${spec.name}`}
                style={{
                  width: '100%',
                  aspectRatio: '1',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  borderRadius: '4px',
                  border: isActive
                    ? `2px solid ${spec.color}`
                    : isNext
                    ? `1px dashed ${spec.color}66`
                    : '1px solid rgba(255,255,255,0.06)',
                  background: isActive
                    ? `${spec.color}22`
                    : hasRun
                    ? 'rgba(0,255,136,0.05)'
                    : 'rgba(255,255,255,0.02)',
                  cursor: 'default',
                  position: 'relative',
                }}
              >
                <span style={{ fontSize: '14px' }}>{spec.icon}</span>
                <span style={{
                  fontSize: '7px',
                  fontFamily: 'var(--font-mono)',
                  color: isActive ? spec.color : 'var(--text-dim)',
                  marginTop: '2px',
                  textAlign: 'center',
                  lineHeight: '1.1',
                }}>
                  {spec.name}
                </span>
                {isActive && (
                  <div style={{
                    position: 'absolute',
                    top: '-1px',
                    right: '-1px',
                    width: '6px',
                    height: '6px',
                    borderRadius: '50%',
                    background: spec.color,
                    boxShadow: `0 0 6px ${spec.color}`,
                  }} />
                )}
              </div>
            );
          })}
        </div>

        {/* Stats footer */}
        <div style={{
          padding: '6px 12px',
          borderTop: '1px solid rgba(255,255,255,0.04)',
          display: 'flex',
          gap: '16px',
          fontSize: '10px',
          fontFamily: 'var(--font-mono)',
          color: 'var(--text-dim)',
        }}>
          <span>{specialistCommits.length} audits run</span>
          <span>16 specialists</span>
          <span>cycle every 1h</span>
        </div>
      </div>
    </div>
  );
}
