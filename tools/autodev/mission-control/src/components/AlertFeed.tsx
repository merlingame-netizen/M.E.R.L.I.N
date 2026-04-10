import { useEffect, useRef } from 'react';
import type { AlertEntry } from '../store/mission-store';
import { useMissionStore } from '../store/mission-store';

const MOCK_ALERTS: AlertEntry[] = [
  { id: 'a1', timestamp: new Date(Date.now() - 600000).toISOString(), level: 'INFO', message: 'Orchestrator initialized — IDLE state', source: 'system' },
  { id: 'a2', timestamp: new Date(Date.now() - 550000).toISOString(), level: 'SUCCESS', message: 'Connected to Ollama backend (qwen3.5:2b)', source: 'llm' },
  { id: 'a3', timestamp: new Date(Date.now() - 500000).toISOString(), level: 'INFO', message: 'Loaded 18 Oghams, 5 Factions, 8 Biomes', source: 'game-data' },
  { id: 'a4', timestamp: new Date(Date.now() - 450000).toISOString(), level: 'INFO', message: 'State: IDLE -> SCAN', source: 'orchestrator' },
  { id: 'a5', timestamp: new Date(Date.now() - 400000).toISOString(), level: 'INFO', message: 'Scanning feature queue... 12 tasks found', source: 'scanner' },
  { id: 'a6', timestamp: new Date(Date.now() - 380000).toISOString(), level: 'INFO', message: 'State: SCAN -> PLAN', source: 'orchestrator' },
  { id: 'a7', timestamp: new Date(Date.now() - 350000).toISOString(), level: 'INFO', message: 'Planning phase: 4 agents selected for dispatch', source: 'planner' },
  { id: 'a8', timestamp: new Date(Date.now() - 340000).toISOString(), level: 'INFO', message: 'State: PLAN -> DISPATCH', source: 'orchestrator' },
  { id: 'a9', timestamp: new Date(Date.now() - 330000).toISOString(), level: 'SUCCESS', message: 'Dispatched architect -> scene flow refactor', source: 'dispatcher' },
  { id: 'a10', timestamp: new Date(Date.now() - 320000).toISOString(), level: 'SUCCESS', message: 'Dispatched godot-orch -> scene validation', source: 'dispatcher' },
  { id: 'a11', timestamp: new Date(Date.now() - 310000).toISOString(), level: 'SUCCESS', message: 'Dispatched refactor -> yield cleanup', source: 'dispatcher' },
  { id: 'a12', timestamp: new Date(Date.now() - 250000).toISOString(), level: 'WARN', message: 'card-generator blocked — waiting for LLM response', source: 'card-gen' },
  { id: 'a13', timestamp: new Date(Date.now() - 200000).toISOString(), level: 'SUCCESS', message: 'code-reviewer completed — merlin_store.gd PASS', source: 'review' },
  { id: 'a14', timestamp: new Date(Date.now() - 150000).toISOString(), level: 'SUCCESS', message: 'llm-adapter completed — Qwen 3.5 routing configured', source: 'llm' },
  { id: 'a15', timestamp: new Date(Date.now() - 100000).toISOString(), level: 'ERROR', message: 'visual-worker FAILED — shader compile error in GBC palette', source: 'visual' },
  { id: 'a16', timestamp: new Date(Date.now() - 80000).toISOString(), level: 'WARN', message: 'RAM usage at 87% — consider closing unused processes', source: 'monitor' },
  { id: 'a17', timestamp: new Date(Date.now() - 50000).toISOString(), level: 'INFO', message: 'biome-builder progress: 62% terrain mesh generated', source: 'biome' },
  { id: 'a18', timestamp: new Date(Date.now() - 20000).toISOString(), level: 'SUCCESS', message: 'save-system completed — profile persistence verified', source: 'save' },
  { id: 'a19', timestamp: new Date(Date.now() - 5000).toISOString(), level: 'INFO', message: 'Waiting for 4 active agents to complete...', source: 'orchestrator' },
];

function formatTime(isoStr: string): string {
  const d = new Date(isoStr);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
}

export function AlertFeed() {
  const storeAlerts = useMissionStore(s => s.alerts);
  const feedRef = useRef<HTMLDivElement>(null);

  // Combine mock + live alerts, sorted newest first
  const allAlerts = storeAlerts.length > 0
    ? [...storeAlerts, ...MOCK_ALERTS]
    : MOCK_ALERTS;

  useEffect(() => {
    if (feedRef.current) {
      feedRef.current.scrollTop = 0;
    }
  }, [allAlerts.length]);

  return (
    <div className="panel">
      <div className="panel-header">
        System Log
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {allAlerts.length} ENTRIES
        </span>
      </div>
      <div className="alert-feed" ref={feedRef} style={{ flex: 1 }}>
        {allAlerts.map((alert) => (
          <div key={alert.id} className="alert-entry">
            <span className="alert-time">{formatTime(alert.timestamp)}</span>
            <span className={`alert-level alert-level--${alert.level.toLowerCase()}`}>
              {alert.level}
            </span>
            <span className="alert-message">{alert.message}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
