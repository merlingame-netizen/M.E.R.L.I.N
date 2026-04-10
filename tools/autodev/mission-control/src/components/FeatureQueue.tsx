import type { FeatureTask } from '../store/mission-store';

const MOCK_TASKS: FeatureTask[] = [
  { id: 'f1', title: 'Implement Ogham activation UI overlay', priority: 1, status: 'in_progress', agent: 'architect' },
  { id: 'f2', title: 'Wire minigame scoring to effect engine', priority: 1, status: 'dispatched', agent: 'godot-orch' },
  { id: 'f3', title: 'Add SFX for faction reputation changes', priority: 2, status: 'pending' },
  { id: 'f4', title: 'Fix card drain -1 at start of pipeline', priority: 1, status: 'completed', agent: 'tdd-guide' },
  { id: 'f5', title: 'Implement MOS convergence soft caps', priority: 2, status: 'blocked', agent: 'card-gen' },
  { id: 'f6', title: 'Add Anam cross-run persistence', priority: 3, status: 'pending' },
  { id: 'f7', title: 'Build biome maturity scoring system', priority: 2, status: 'dispatched', agent: 'biome-bld' },
  { id: 'f8', title: 'Create Confiance Merlin tier transitions', priority: 3, status: 'pending' },
  { id: 'f9', title: 'Implement FastRoute 500+ card variants', priority: 2, status: 'pending' },
  { id: 'f10', title: 'Add multiplicateur cap global x2.0', priority: 3, status: 'completed', agent: 'code-reviewer' },
];

function getPriorityClass(priority: number): string {
  if (priority <= 1) return 'priority-dot--high';
  if (priority <= 2) return 'priority-dot--medium';
  return 'priority-dot--low';
}

export function FeatureQueue() {
  const tasks = MOCK_TASKS;
  const pendingCount = tasks.filter(t => t.status === 'pending' || t.status === 'in_progress' || t.status === 'dispatched').length;

  return (
    <div className="panel">
      <div className="panel-header">
        Feature Queue
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {pendingCount} PENDING
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {tasks.map((task) => (
          <div key={task.id} className="feature-row">
            <div className={`priority-dot ${getPriorityClass(task.priority)}`} />
            <span className="feature-title">{task.title}</span>
            <span className={`feature-status feature-status--${task.status}`}>
              {task.status.replace('_', ' ')}
            </span>
            {task.agent && (
              <span className="feature-agent">{task.agent}</span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
