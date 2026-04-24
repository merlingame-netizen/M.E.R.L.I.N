import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';
import type { AgentInfo } from '../../store/mission-store';

const CATEGORY_LABELS: Record<string, string> = {
  direction: 'Direction',
  engineering: 'Engineering',
  gamedesign: 'Game Design',
  content: 'Content',
  visual: 'Visual',
  blender: 'Blender/3D',
  audio: 'Audio',
  ux: 'UX',
  qa: 'QA',
  perf: 'Performance',
  ai: 'AI/LLM',
  meta: 'Meta',
  devops: 'DevOps',
  core: 'Core',
  quality: 'Quality',
  ops: 'Operations',
  test: 'Test',
  docs: 'Docs',
  game: 'Game',
  ui: 'UI',
};

function getShortName(name: string): string {
  return name.slice(0, 3).toUpperCase();
}

export function AgentsTab() {
  const agents = useMissionStore(s => s.agents) || [];
  const [expandedCats, setExpandedCats] = useState<Set<string>>(new Set());

  const runningCount = agents.filter(a => a.state === 'running').length;

  const grouped = agents.reduce<Record<string, AgentInfo[]>>((acc, a) => {
    const cat = a.category || 'meta';
    (acc[cat] ??= []).push(a);
    return acc;
  }, {});

  const categories = Object.keys(grouped).sort();

  function toggle(cat: string) {
    setExpandedCats(prev => {
      const next = new Set(prev);
      if (next.has(cat)) next.delete(cat); else next.add(cat);
      return next;
    });
  }

  return (
    <div style={{ padding: '12px' }}>
      <div className="panel-header" style={{ marginBottom: '12px' }}>
        Agent Fleet
        <span style={{ marginLeft: 'auto', fontSize: '10px', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
          {runningCount}/{agents.length} ACTIVE
        </span>
      </div>

      {agents.length === 0 && (
        <div style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-dim)' }}>
          Loading agent fleet...
        </div>
      )}

      {categories.map(cat => {
        const catAgents = grouped[cat] || [];
        const expanded = expandedCats.has(cat);
        const catRunning = catAgents.filter(a => a.state === 'running').length;

        return (
          <div key={cat} style={{ marginBottom: '8px' }}>
            <button
              onClick={() => toggle(cat)}
              style={{
                width: '100%', background: 'var(--bg-card)', border: '1px solid var(--border-subtle)',
                color: 'var(--amber)', fontFamily: 'var(--font-mono)', fontSize: '11px',
                padding: '8px 12px', cursor: 'pointer', display: 'flex', justifyContent: 'space-between',
                textAlign: 'left', letterSpacing: '1px', textTransform: 'uppercase',
              }}
            >
              <span>{expanded ? '▼' : '▶'} {CATEGORY_LABELS[cat] || cat} ({catAgents.length})</span>
              {catRunning > 0 && <span style={{ color: 'var(--cyan)' }}>{catRunning} active</span>}
            </button>
            {expanded && (
              <div className="hex-grid" style={{ background: 'var(--bg-panel)', border: '1px solid var(--border-subtle)', borderTop: 'none', padding: '8px' }}>
                {catAgents.map(agent => (
                  <div
                    key={agent.id}
                    className={`hex-tile hex-tile--${agent.state}`}
                    title={`${agent.name}${agent.role ? ` (${agent.role})` : ''}${agent.currentTask ? ` — ${agent.currentTask}` : ''}`}
                  >
                    {getShortName(agent.name)}
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
