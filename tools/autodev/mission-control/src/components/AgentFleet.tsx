import type { AgentInfo } from '../store/mission-store';

const MOCK_AGENTS: AgentInfo[] = [
  { id: 'planner', name: 'planner', category: 'core', state: 'idle', currentTask: null },
  { id: 'architect', name: 'architect', category: 'core', state: 'running', currentTask: 'Design scene flow' },
  { id: 'tdd-guide', name: 'tdd-guide', category: 'core', state: 'idle', currentTask: null },
  { id: 'code-reviewer', name: 'code-reviewer', category: 'quality', state: 'completed', currentTask: null },
  { id: 'security', name: 'security-reviewer', category: 'quality', state: 'idle', currentTask: null },
  { id: 'build-err', name: 'build-error-resolver', category: 'ops', state: 'idle', currentTask: null },
  { id: 'e2e-runner', name: 'e2e-runner', category: 'test', state: 'idle', currentTask: null },
  { id: 'refactor', name: 'refactor-cleaner', category: 'quality', state: 'running', currentTask: 'Clean dead code' },
  { id: 'doc-update', name: 'doc-updater', category: 'docs', state: 'idle', currentTask: null },
  { id: 'godot-orch', name: 'godot-orchestrator', category: 'game', state: 'running', currentTask: 'Scene validation' },
  { id: 'llm-adapter', name: 'llm-adapter', category: 'ai', state: 'completed', currentTask: null },
  { id: 'rag-mgr', name: 'rag-manager', category: 'ai', state: 'idle', currentTask: null },
  { id: 'sfx-worker', name: 'sfx-worker', category: 'audio', state: 'idle', currentTask: null },
  { id: 'card-gen', name: 'card-generator', category: 'game', state: 'blocked', currentTask: 'Waiting for LLM' },
  { id: 'effect-eng', name: 'effect-engine', category: 'game', state: 'idle', currentTask: null },
  { id: 'save-sys', name: 'save-system', category: 'game', state: 'completed', currentTask: null },
  { id: 'rep-sys', name: 'reputation-sys', category: 'game', state: 'idle', currentTask: null },
  { id: 'visual-w', name: 'visual-worker', category: 'ui', state: 'error', currentTask: 'Shader compile fail' },
  { id: 'deploy-w', name: 'deploy-worker', category: 'ops', state: 'idle', currentTask: null },
  { id: 'biome-bld', name: 'biome-builder', category: 'game', state: 'running', currentTask: 'Broceliande gen' },
];

function getShortName(name: string): string {
  return name.slice(0, 3).toUpperCase();
}

export function AgentFleet() {
  const agents = MOCK_AGENTS;
  const runningCount = agents.filter(a => a.state === 'running').length;

  return (
    <div className="panel">
      <div className="panel-header">
        Agent Fleet
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {runningCount}/{agents.length} ACTIVE
        </span>
      </div>
      <div className="panel-body">
        <div className="hex-grid">
          {agents.map((agent) => (
            <div
              key={agent.id}
              className={`hex-tile hex-tile--${agent.state}`}
              title={`${agent.name}${agent.currentTask ? ` — ${agent.currentTask}` : ''}`}
            >
              {getShortName(agent.name)}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
