import { useMissionStore } from '../store/mission-store';

const STATES = ['IDLE', 'SCAN', 'PLAN', 'DISPATCH', 'COLLECT', 'VALIDATE', 'TEST', 'EVOLVE', 'REPORT'];

export function StateTimeline() {
  const { orchestratorState } = useMissionStore();

  const activeIdx = STATES.indexOf(orchestratorState);

  return (
    <div className="panel" style={{ height: 'auto' }}>
      <div className="timeline">
        {STATES.map((state, i) => {
          const isActive = i === activeIdx;
          const isCompleted = i < activeIdx;

          const dotClass = isActive
            ? 'timeline-dot timeline-dot--active'
            : isCompleted
              ? 'timeline-dot timeline-dot--completed'
              : 'timeline-dot';

          const labelClass = isActive
            ? 'timeline-label timeline-label--active'
            : isCompleted
              ? 'timeline-label timeline-label--completed'
              : 'timeline-label';

          return (
            <div key={state} style={{ display: 'flex', alignItems: 'center' }}>
              <div className="timeline-node">
                <div className={dotClass} />
                <span className={labelClass}>{state}</span>
              </div>
              {i < STATES.length - 1 && (
                <div
                  className={
                    isActive
                      ? 'timeline-connector timeline-connector--active'
                      : isCompleted
                        ? 'timeline-connector timeline-connector--completed'
                        : 'timeline-connector'
                  }
                />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
