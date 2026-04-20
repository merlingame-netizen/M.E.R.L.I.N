import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

interface AgentExt {
  id: string;
  name: string;
  state: string;
  currentTask: string | null;
  category?: string;
  role?: string;
}

const CATEGORIES: { id: string; label: string; icon: string; color: string }[] = [
  { id: 'direction', label: 'Direction & Orchestration', icon: '\u2691', color: 'var(--amber)' },
  { id: 'engineering', label: 'Core Engineering', icon: '\u2699', color: 'var(--phosphor)' },
  { id: 'gamedesign', label: 'Game Design', icon: '\u25B2', color: 'var(--cyan)' },
  { id: 'content', label: 'Content & Narrative', icon: '\u270E', color: 'var(--amber)' },
  { id: 'visual', label: 'Visual & Art', icon: '\u25C6', color: 'var(--cyan)' },
  { id: 'blender', label: 'Blender 3D', icon: '\u25A0', color: 'var(--phosphor)' },
  { id: 'audio', label: 'Audio', icon: '\u266A', color: 'var(--amber)' },
  { id: 'ux', label: 'UX & Accessibility', icon: '\u25CB', color: 'var(--cyan)' },
  { id: 'qa', label: 'QA & Testing', icon: '\u2713', color: 'var(--phosphor)' },
  { id: 'perf', label: 'Performance', icon: '\u26A1', color: 'var(--amber)' },
  { id: 'ai', label: 'AI / LLM', icon: '\u25EF', color: 'var(--cyan)' },
  { id: 'meta', label: 'Meta & Governance', icon: '\u2023', color: 'var(--text-secondary)' },
  { id: 'devops', label: 'DevOps', icon: '\u21BB', color: 'var(--phosphor-dim)' },
];

export function AgentsTab() {
  const agents = (useMissionStore(s => s.agents) || []) as AgentExt[];
  const [expanded, setExpanded] = useState<Set<string>>(new Set(['direction', 'engineering']));

  const toggle = (cat: string) => {
    setExpanded(prev => {
      const n = new Set(prev);
      if (n.has(cat)) n.delete(cat); else n.add(cat);
      return n;
    });
  };

  const byCat: Record<string, AgentExt[]> = {};
  for (const a of agents) {
    const cat = a.category || 'meta';
    if (!byCat[cat]) byCat[cat] = [];
    byCat[cat].push(a);
  }

  const running = agents.filter(a => a.state === 'running').length;
  const completed = agents.filter(a => a.state === 'completed').length;

  return (
    <div>
      <div className="section-title" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span>{'\u2699'} Agent Fleet — {agents.length} total</span>
        <span style={{ fontSize: 9, color: 'var(--text-dim)' }}>
          <span style={{ color: 'var(--phosphor)' }}>{running} running</span>
          {' \u2022 '}
          <span style={{ color: 'var(--phosphor-dim)' }}>{completed} done</span>
        </span>
      </div>

      {CATEGORIES.map(cat => {
        const list = byCat[cat.id] || [];
        if (list.length === 0) return null;
        const isOpen = expanded.has(cat.id);
        const catRunning = list.filter(a => a.state === 'running').length;

        return (
          <div key={cat.id}>
            <button
              onClick={() => toggle(cat.id)}
              style={{
                width: '100%', display: 'flex', alignItems: 'center', gap: 8,
                padding: '10px 12px', background: 'var(--bg-panel)',
                border: 'none', borderBottom: '1px solid var(--border)',
                color: cat.color, fontFamily: 'var(--font-mono)',
                fontSize: 11, letterSpacing: 1, textTransform: 'uppercase',
                cursor: 'pointer', textAlign: 'left', minHeight: 40,
              }}
            >
              <span style={{ color: cat.color, fontSize: 14 }}>{cat.icon}</span>
              <span style={{ flex: 1 }}>{cat.label}</span>
              <span style={{ fontSize: 9, color: 'var(--text-dim)' }}>
                {catRunning > 0 && <span style={{ color: 'var(--phosphor)' }}>{catRunning} \u25B6 </span>}
                {list.length}
              </span>
              <span style={{ color: 'var(--text-dim)', fontSize: 10 }}>{isOpen ? '\u25BC' : '\u25B6'}</span>
            </button>

            {isOpen && (
              <div className="agents-grid" style={{ padding: '8px 12px' }}>
                {list.map(a => (
                  <div key={a.id} className={`agent-card agent-card--${a.state}`}>
                    <span className={`agent-card__dot agent-card__dot--${a.state}`} />
                    <div className="agent-card__info">
                      <div className="agent-card__name">{a.role || a.name}</div>
                      <div className="agent-card__task">
                        {a.currentTask || (a.state === 'completed' ? '\u2713 done' : a.state)}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}

      {agents.length === 0 && (
        <div style={{ padding: 20, color: 'var(--text-dim)', textAlign: 'center' }}>
          No agents registered. Waiting for status sync...
        </div>
      )}
    </div>
  );
}
