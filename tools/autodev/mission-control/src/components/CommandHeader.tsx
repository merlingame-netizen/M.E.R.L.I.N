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
    <div className="command-header" role="banner">
      {/* Top glow line — phosphor green to amber gradient */}
      <div className="command-header__glow-line" aria-hidden="true" />

      {/* Title row: Celtic title + version */}
      <div className="command-header__title-row">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span className="command-header__celtic-border" aria-hidden="true">
            &#x2726;&#x2727;&#x2726;
          </span>
          <span className="command-header__title">
            M.E.R.L.I.N.
          </span>
          <span className="command-header__celtic-border" aria-hidden="true">
            &#x2726;&#x2727;&#x2726;
          </span>
          <span className="command-header__version">v1.0.0</span>
        </div>
      </div>

      {/* Status row: state badge, cycle, connection, uptime */}
      <div className="command-header__status-row">
        <span className={`state-badge ${stateClass}`}>
          {orchestratorState}
        </span>

        {cycleId && (
          <span className="command-header__cycle">
            CYCLE {cycleId}
          </span>
        )}

        <div className="command-header__connection">
          <span
            className={`connection-dot ${connected ? 'connection-dot--online' : 'connection-dot--offline'}`}
            role="status"
            aria-label={connected ? 'Connected' : 'Disconnected'}
          />
          <span
            className="command-header__connection-label"
            style={{ color: connected ? 'var(--green)' : 'var(--red)' }}
          >
            {connected ? 'LINKED' : 'OFFLINE'}
          </span>
        </div>

        <span className="command-header__uptime" aria-label={`Uptime: ${formatUptime(uptime)}`}>
          {formatUptime(uptime)}
        </span>
      </div>
    </div>
  );
}
