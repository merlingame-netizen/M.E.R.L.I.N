import { useMissionStore } from '../../store/mission-store';

export function DirectorTab() {
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions);
  const studioInsights = useMissionStore(s => s.studioInsights);
  const submitFeedback = useMissionStore(s => s.submitFeedback);

  const pending = feedbackQuestions.filter(q => q.status !== 'answered');
  const answered = feedbackQuestions.filter(q => q.status === 'answered');

  const severityIcon: Record<string, string> = {
    ACTION: '\u26A1', WARN: '\u25B2', INFO: '\u2022',
  };

  return (
    <div>
      {/* Pending questions */}
      {pending.length > 0 && (
        <>
          <div className="section-title">{'\u2691'} Pending Decisions — {pending.length}</div>
          {pending.map(q => (
            <div key={q.id} className="feedback-card">
              <div className="feedback-card__cat">{q.category} — {q.priority}</div>
              <div className="feedback-card__q">{q.question}</div>
              {q.type === 'multiple_choice' && q.options?.map((opt, i) => (
                <button
                  key={i}
                  className="feedback-option"
                  onClick={() => submitFeedback(q.id, opt, '')}
                >
                  {opt}
                </button>
              ))}
            </div>
          ))}
        </>
      )}

      {/* Studio insights */}
      {studioInsights.length > 0 && (
        <>
          <div className="section-title">{'\u26A1'} Studio Insights — {studioInsights.length}</div>
          {studioInsights.slice(0, 15).map((ins, i) => (
            <div key={i} className="task-row">
              <span style={{
                color: ins.severity === 'ACTION' ? 'var(--amber)' : ins.severity === 'WARN' ? 'var(--danger)' : 'var(--text-dim)',
                flexShrink: 0,
                width: '16px',
                textAlign: 'center',
              }}>
                {severityIcon[ins.severity] || '\u2022'}
              </span>
              <div className="task-info">
                <div className="task-title">{ins.message}</div>
                <div className="task-meta">
                  <span>{ins.agent}</span>
                  <span>{ins.category}</span>
                </div>
              </div>
            </div>
          ))}
        </>
      )}

      {/* Answered */}
      {answered.length > 0 && (
        <>
          <div className="section-title" style={{ color: 'var(--text-dim)' }}>
            {'\u2713'} Answered — {answered.length}
          </div>
          <div style={{ padding: '8px 12px', color: 'var(--text-ghost)', fontSize: '10px' }}>
            {answered.length} decisions submitted.
          </div>
        </>
      )}

      {pending.length === 0 && studioInsights.length === 0 && (
        <div style={{ padding: '20px 12px', color: 'var(--text-dim)' }}>
          No pending decisions or insights.
        </div>
      )}
    </div>
  );
}
