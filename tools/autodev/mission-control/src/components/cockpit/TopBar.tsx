import { useEffect, useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

function nextCycleLabel(nextCycleAt: string | null): string {
  if (!nextCycleAt) return '—';
  const t = Date.parse(nextCycleAt);
  if (!Number.isFinite(t)) return '—';
  const diffMs = t - Date.now();
  if (diffMs <= 0) return 'now';
  const minutes = Math.round(diffMs / 60_000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return rem === 0 ? `${hours}h` : `${hours}h${String(rem).padStart(2, '0')}`;
}

export function TopBar() {
  const completedCount = useMissionStore((s) => s.completedCount);
  const featureQueue = useMissionStore((s) => s.featureQueue);
  const agents = useMissionStore((s) => s.agents);
  const connected = useMissionStore((s) => s.connected);
  const nextCycleAt = useMissionStore((s) => s.nextCycleAt);

  const [, setTick] = useState(0);
  useEffect(() => {
    const id = window.setInterval(() => setTick((t) => t + 1), 30_000);
    return () => window.clearInterval(id);
  }, []);

  const running = featureQueue.filter(
    (t) => t.status === 'in_progress' || t.status === 'dispatched',
  ).length;
  const pending = featureQueue.filter((t) => t.status === 'pending').length;
  const activeAgents = agents.filter((a) => a.state === 'running').length;

  return (
    <header className="topbar" role="banner">
      <div className="topbar__brand">
        <span
          className={`topbar__dot ${connected ? 'topbar__dot--online' : 'topbar__dot--offline'}`}
          aria-label={connected ? 'connected' : 'disconnected'}
        />
        <span className="topbar__logo">MERLIN</span>
        <span className="topbar__tag">cockpit</span>
      </div>
      <div className="topbar__kpi" role="status" aria-live="polite">
        <span className="topbar__kpi-item topbar__kpi-item--done">
          <span className="topbar__kpi-glyph">✓</span>
          <span className="topbar__kpi-num">{completedCount}</span>
          <span className="topbar__kpi-label">done</span>
        </span>
        <span className="topbar__kpi-sep" aria-hidden="true">·</span>
        <span className="topbar__kpi-item topbar__kpi-item--running">
          <span className="topbar__kpi-glyph">▶</span>
          <span className="topbar__kpi-num">{running}</span>
          <span className="topbar__kpi-label">running</span>
        </span>
        <span className="topbar__kpi-sep" aria-hidden="true">·</span>
        <span className="topbar__kpi-item">
          <span className="topbar__kpi-glyph">⏱</span>
          <span className="topbar__kpi-num">{nextCycleLabel(nextCycleAt)}</span>
          <span className="topbar__kpi-label">next</span>
        </span>
        <span className="topbar__kpi-sep" aria-hidden="true">·</span>
        <span className="topbar__kpi-item">
          <span className="topbar__kpi-glyph">⚡</span>
          <span className="topbar__kpi-num">{activeAgents}/{agents.length}</span>
          <span className="topbar__kpi-label">agents</span>
        </span>
        <span className="topbar__kpi-sep" aria-hidden="true">·</span>
        <span className="topbar__kpi-item">
          <span className="topbar__kpi-glyph">⌖</span>
          <span className="topbar__kpi-num">{pending}</span>
          <span className="topbar__kpi-label">queued</span>
        </span>
      </div>
      <div className="topbar__actions">
        <a
          href="https://github.com/maxbab38/Godot-MCP"
          target="_blank"
          rel="noreferrer"
          className="topbar__btn"
          aria-label="Open repository"
          title="Repository"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22" />
          </svg>
        </a>
        <button type="button" className="topbar__btn" aria-label="Settings" title="Settings">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
        </button>
      </div>
    </header>
  );
}
