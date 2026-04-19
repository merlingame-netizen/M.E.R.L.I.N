import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

export function DirectorTab() {
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions) || [];
  const studioInsights = useMissionStore(s => s.studioInsights) || [];
  const submitFeedback = useMissionStore(s => s.submitFeedback);

  const pending = feedbackQuestions.filter(q => q.status !== 'answered');
  const answered = feedbackQuestions.filter(q => q.status === 'answered');

  const [textInputs, setTextInputs] = useState<Record<string, string>>({});
  const [expandAnswered, setExpandAnswered] = useState(false);

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
              {q.context && <div style={{ fontSize: '10px', color: 'var(--text-dim)', marginBottom: 8, lineHeight: 1.4 }}>{q.context}</div>}
              {q.type === 'multiple_choice' && Array.isArray(q.options) && q.options.map((opt, i) => (
                <button
                  key={i}
                  className="feedback-option"
                  onClick={() => submitFeedback(q.id, opt, '')}
                >
                  {opt}
                </button>
              ))}
              {q.type === 'text' && (
                <div style={{ marginTop: 6 }}>
                  <textarea
                    value={textInputs[q.id] || ''}
                    onChange={e => setTextInputs(prev => ({ ...prev, [q.id]: e.target.value }))}
                    placeholder="Your response..."
                    style={{
                      width: '100%', minHeight: 60, background: 'var(--bg-deep)', border: '1px solid var(--border)',
                      color: 'var(--text-primary)', fontFamily: 'var(--font-mono)', fontSize: 11, padding: 8,
                      resize: 'vertical',
                    }}
                  />
                  <button
                    className="feedback-option"
                    style={{ marginTop: 4, color: 'var(--amber)', borderColor: 'var(--border-amber)' }}
                    onClick={() => {
                      if (textInputs[q.id]?.trim()) {
                        submitFeedback(q.id, textInputs[q.id], '');
                        setTextInputs(prev => { const n = { ...prev }; delete n[q.id]; return n; });
                      }
                    }}
                  >
                    TRANSMIT
                  </button>
                </div>
              )}
              {q.type !== 'multiple_choice' && q.type !== 'text' && (
                <div style={{ marginTop: 6 }}>
                  <textarea
                    value={textInputs[q.id] || ''}
                    onChange={e => setTextInputs(prev => ({ ...prev, [q.id]: e.target.value }))}
                    placeholder="Your response..."
                    style={{
                      width: '100%', minHeight: 60, background: 'var(--bg-deep)', border: '1px solid var(--border)',
                      color: 'var(--text-primary)', fontFamily: 'var(--font-mono)', fontSize: 11, padding: 8,
                      resize: 'vertical',
                    }}
                  />
                  <button
                    className="feedback-option"
                    style={{ marginTop: 4, color: 'var(--amber)', borderColor: 'var(--border-amber)' }}
                    onClick={() => {
                      if (textInputs[q.id]?.trim()) {
                        submitFeedback(q.id, textInputs[q.id], '');
                        setTextInputs(prev => { const n = { ...prev }; delete n[q.id]; return n; });
                      }
                    }}
                  >
                    TRANSMIT
                  </button>
                </div>
              )}
            </div>
          ))}
        </>
      )}

      {pending.length === 0 && (
        <div style={{ padding: '20px 12px', color: 'var(--text-dim)', textAlign: 'center' }}>
          {'\u2713'} No pending decisions. All caught up.
        </div>
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
          <button
            onClick={() => setExpandAnswered(!expandAnswered)}
            style={{
              width: '100%', textAlign: 'left', background: 'none', border: 'none',
              borderBottom: '1px solid var(--border)', padding: '12px 12px 6px',
              fontFamily: 'var(--font-display)', fontSize: 11, letterSpacing: 2,
              textTransform: 'uppercase', color: 'var(--text-dim)', cursor: 'pointer',
            }}
          >
            {expandAnswered ? '\u25BC' : '\u25B6'} Answered — {answered.length}
          </button>
          {expandAnswered && answered.map(q => (
            <div key={q.id} style={{ padding: '6px 12px', fontSize: 10, color: 'var(--text-ghost)', borderBottom: '1px solid var(--border)' }}>
              {q.question.slice(0, 80)}...
            </div>
          ))}
        </>
      )}
    </div>
  );
}
