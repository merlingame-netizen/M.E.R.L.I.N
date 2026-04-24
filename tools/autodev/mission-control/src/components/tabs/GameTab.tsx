import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

const GODOT_CMD = 'godot --path .';

export function GameTab() {
  const completedCount = useMissionStore(s => s.completedCount);
  const agents = useMissionStore(s => s.agents) || [];
  const featureQueue = useMissionStore(s => s.featureQueue) || [];
  const orchestratorState = useMissionStore(s => s.orchestratorState);
  const lastHeartbeat = useMissionStore(s => s.lastHeartbeat);

  const [copied, setCopied] = useState(false);

  const runningAgents = agents.filter(a => a.state === 'running').length;
  const pendingTasks = featureQueue.filter(t => t.status === 'pending').length;
  const inProgress = featureQueue.filter(t => t.status === 'in_progress').length;

  function copyCommand() {
    navigator.clipboard.writeText(GODOT_CMD).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }).catch(() => {});
  }

  return (
    <div className="game-view">
      <div className="game-launch">
        <div className="game-launch__logo">M.E.R.L.I.N.</div>
        <div className="game-launch__subtitle">Le Jeu des Oghams</div>

        <button className="game-launch__btn" onClick={copyCommand}>
          {copied ? '✓ COPIED' : '▶ LANCER GODOT'}
        </button>

        <div className="game-launch__cmd">
          <code>{GODOT_CMD}</code>
        </div>

        <div className="game-launch__hint">
          Copy the command above or use <code>./launch.sh</code> to start everything.
        </div>

        <div className="game-launch__status">
          <div className="game-launch__status-row">
            <span className="game-launch__status-label">Engine</span>
            <span className="game-launch__status-value">Godot 4.5 (Local)</span>
          </div>
          <div className="game-launch__status-row">
            <span className="game-launch__status-label">Orchestrator</span>
            <span className="game-launch__status-value">{orchestratorState || 'IDLE'}</span>
          </div>
          {lastHeartbeat && (
            <div className="game-launch__status-row">
              <span className="game-launch__status-label">Last heartbeat</span>
              <span className="game-launch__status-value">{lastHeartbeat}</span>
            </div>
          )}
        </div>
      </div>

      <div className="kpi-strip">
        <div className="kpi">
          <span className="kpi__value">{completedCount || 0}</span>
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
