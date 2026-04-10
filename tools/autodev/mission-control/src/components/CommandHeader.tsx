import { useState, useEffect } from 'react';
import { useMissionStore } from '../store/mission-store';

const STATE_CLASSES: Record<string, string> = {
  IDLE: 'state-badge--idle',
  SCAN: 'state-badge--scan',
  PLAN: 'state-badge--plan',
  DISPATCH: 'state-badge--dispatch',
  COLLECT: 'state-badge--collect',
  VALIDATE: 'state-badge--validate',
  TEST: 'state-badge--test',
  EVOLVE: 'state-badge--evolve',
  REPORT: 'state-badge--report',
  ERROR: 'state-badge--error',
};

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function CommandHeader() {
  const { orchestratorState, cycleId, connected } = useMissionStore();
  const [uptime, setUptime] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => setUptime(u => u + 1), 1000);
    return () => clearInterval(interval);
  }, []);

  const stateClass = STATE_CLASSES[orchestratorState] ?? 'state-badge--idle';

  return (
    <div style={{
      background: 'var(--bg-panel)',
      border: '1px solid var(--border-subtle)',
      borderRadius: '4px',
      padding: '10px 20px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Top glow line */}
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: '1px',
        background: 'linear-gradient(90deg, transparent, var(--cyan), var(--blue), var(--cyan), transparent)',
        opacity: 0.7,
      }} />

      {/* Left: Title */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        <div style={{
          fontFamily: 'var(--font-display)',
          fontSize: '16px',
          fontWeight: 900,
          letterSpacing: '3px',
          color: 'var(--cyan)',
          textShadow: '0 0 20px rgba(0, 240, 255, 0.3)',
        }}>
          M.E.R.L.I.N. MISSION CONTROL
        </div>
        <div style={{
          fontFamily: 'var(--font-mono)',
          fontSize: '10px',
          color: 'var(--text-dim)',
          letterSpacing: '1px',
        }}>
          v1.0.0
        </div>
      </div>

      {/* Center: State + Cycle */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        <span className={`state-badge ${stateClass}`}>
          {orchestratorState}
        </span>
        {cycleId && (
          <span style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '11px',
            color: 'var(--text-secondary)',
          }}>
            CYCLE {cycleId}
          </span>
        )}
      </div>

      {/* Right: Connection + Uptime */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span className={`connection-dot ${connected ? 'connection-dot--online' : 'connection-dot--offline'}`} />
          <span style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '10px',
            color: connected ? 'var(--green)' : 'var(--red)',
            letterSpacing: '1px',
            textTransform: 'uppercase',
          }}>
            {connected ? 'LINKED' : 'OFFLINE'}
          </span>
        </div>
        <div style={{
          fontFamily: 'var(--font-mono)',
          fontSize: '12px',
          color: 'var(--text-dim)',
          letterSpacing: '2px',
        }}>
          {formatUptime(uptime)}
        </div>
      </div>
    </div>
  );
}
