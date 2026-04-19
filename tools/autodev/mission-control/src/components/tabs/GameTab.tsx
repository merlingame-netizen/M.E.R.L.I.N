import { useState, useRef, useCallback, useEffect } from 'react';
import { useMissionStore } from '../../store/mission-store';
// v2 — with VERCEL_DASHBOARD_PROJECT_ID

const GAME_URL = 'https://project-4o9qm.vercel.app';
const DEPLOY_API = '/api/deploy-status';

interface DeployInfo {
  run_number: number;
  status: string;
  conclusion?: string;
  head_sha: string;
  head_message: string;
  created_at: string;
  updated_at?: string;
  duration_s?: number;
  elapsed_s?: number;
}

function fmt(s: number): string {
  return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`;
}

export function GameTab() {
  const completedCount = useMissionStore(s => s.completedCount);
  const agents = useMissionStore(s => s.agents);
  const featureQueue = useMissionStore(s => s.featureQueue);

  const [latest, setLatest] = useState<DeployInfo | null>(null);
  const [deploying, setDeploying] = useState<DeployInfo | null>(null);
  const [elapsed, setElapsed] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  const runningAgents = agents.filter(a => a.state === 'running').length;
  const pendingTasks = featureQueue.filter(t => t.status === 'pending').length;
  const inProgress = featureQueue.filter(t => t.status === 'in_progress').length;

  useEffect(() => {
    async function poll() {
      try {
        const res = await fetch(DEPLOY_API);
        if (!res.ok) return;
        const json = await res.json();
        if (json.latest) setLatest(json.latest);
        setDeploying(json.deploying || null);
      } catch { /* silent */ }
    }
    poll();
    const id = setInterval(poll, 15000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    if (!deploying) { setElapsed(0); return; }
    setElapsed(deploying.elapsed_s || 0);
    const id = setInterval(() => setElapsed(p => p + 1), 1000);
    return () => clearInterval(id);
  }, [deploying]);

  const toggleFs = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  }, []);

  return (
    <div className="game-view">
      <div className="game-frame" ref={containerRef}>
        <button className="game-frame__fullscreen" onClick={toggleFs}>&#x26F6;</button>
        <iframe
          src={GAME_URL}
          title="M.E.R.L.I.N. Godot"
          allow="fullscreen; autoplay; cross-origin-isolated"
          sandbox="allow-scripts allow-same-origin allow-popups"
        />
      </div>

      {/* Deploy status */}
      <div className="deploy-bar">
        {deploying ? (
          <>
            <span className="deploy-bar__icon deploy-bar__icon--building">{'\u25B6'}</span>
            <span className="deploy-bar__label">DEPLOYING</span>
            <span className="deploy-bar__sha">#{deploying.run_number}</span>
            <span className="deploy-bar__time">{fmt(elapsed)}</span>
            <span className="deploy-bar__msg">{deploying.head_message.slice(0, 40)}</span>
          </>
        ) : latest ? (
          <>
            <span className={`deploy-bar__icon ${latest.conclusion === 'success' ? 'deploy-bar__icon--ok' : 'deploy-bar__icon--fail'}`}>
              {latest.conclusion === 'success' ? '\u2713' : '\u2717'}
            </span>
            <span className="deploy-bar__label">BUILD #{latest.run_number}</span>
            <span className="deploy-bar__time">{fmt(latest.duration_s || 0)}</span>
            <span className="deploy-bar__sha">{latest.head_sha}</span>
            <span className="deploy-bar__msg">{latest.head_message.slice(0, 40)}</span>
          </>
        ) : (
          <span className="deploy-bar__label">Awaiting deploy data...</span>
        )}
      </div>

      {/* KPI strip */}
      <div className="kpi-strip">
        <div className="kpi">
          <span className="kpi__value">{completedCount}</span>
          <span className="kpi__label">Done</span>
        </div>
        <div className="kpi">
          <span className="kpi__value">{inProgress}</span>
          <span className="kpi__label">Active</span>
        </div>
        <div className="kpi">
          <span className="kpi__value">{runningAgents}/{agents.length}</span>
          <span className="kpi__label">Agents</span>
        </div>
        <div className="kpi">
          <span className="kpi__value">{pendingTasks}</span>
          <span className="kpi__label">Queue</span>
        </div>
      </div>
    </div>
  );
}
