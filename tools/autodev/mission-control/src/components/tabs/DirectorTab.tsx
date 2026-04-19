import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';

function safeStr(val: unknown): string {
  if (val === null || val === undefined) return '';
  if (typeof val === 'string') return val;
  if (typeof val === 'number' || typeof val === 'boolean') return String(val);
  return JSON.stringify(val);
}

export function DirectorTab() {
  const feedbackQuestions = useMissionStore(s => s.feedbackQuestions) || [];
  const studioInsights = useMissionStore(s => s.studioInsights) || [];
  const submitFeedback = useMissionStore(s => s.submitFeedback);

  const pending = feedbackQuestions.filter(q => q.status !== 'answered');
  const answered = feedbackQuestions.filter(q => q.status === 'answered');

  const [textInputs, setTextInputs] = useState<Record<string, string>>({});
  const [expandAnswered, setExpandAnswered] = useState(false);

  return (
    <div>
      {pending.length > 0 ? (
        <>
          <div className="section-title">{'\u2691'} Pending Decisions — {pending.length}</div>
          {pending.map(q => {
            const opts = Array.isArray(q.options) ? q.options : [];
            const qType = safeStr(q.type);
            return (
              <div key={q.id} className="feedback-card">
                <div className="feedback-card__cat">{safeStr(q.category)} — {safeStr(q.priority)}</div>
                <div className="feedback-card__q">{safeStr(q.question)}</div>
                {q.context && <div style={{ fontSize: 10, color: 'var(--text-dim)', marginBottom: 8, lineHeight: 1.4 }}>{safeStr(q.context)}</div>}
                {qType === 'multiple_choice' && opts.map((opt, i) => (
                  <button key={i} className="feedback-option" onClick={() => submitFeedback(q.id, safeStr(opt), '')}>
                    {safeStr(opt)}
                  </button>
                ))}
                {qType !== 'multiple_choice' && (
                  <div style={{ marginTop: 6 }}>
                    <textarea
                      value={textInputs[q.id] || ''}
                      onChange={e => setTextInputs(prev => ({ ...prev, [q.id]: e.target.value }))}
                      placeholder="Your response..."
                      style={{ width: '100%', minHeight: 60, background: 'var(--bg-deep)', border: '1px solid var(--border)', color: 'var(--text-primary)', fontFamily: 'var(--font-mono)', fontSize: 11, padding: 8, resize: 'vertical' }}
                    />
                    <button className="feedback-option" style={{ marginTop: 4, color: 'var(--amber)' }}
                      onClick={() => { if (textInputs[q.id]?.trim()) { submitFeedback(q.id, textInputs[q.id] || '', ''); setTextInputs(prev => { const n = { ...prev }; delete n[q.id]; return n; }); } }}>
                      TRANSMIT
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </>
      ) : (
        <div style={{ padding: 20, color: 'var(--text-dim)', textAlign: 'center' }}>{'\u2713'} No pending decisions.</div>
      )}

      {studioInsights.length > 0 && (
        <>
          <div className="section-title">{'\u26A1'} Insights — {studioInsights.length}</div>
          {studioInsights.slice(0, 15).map((ins, i) => (
            <div key={i} className="task-row">
              <span style={{ color: ins.severity === 'ACTION' ? 'var(--amber)' : ins.severity === 'WARN' ? 'var(--danger)' : 'var(--text-dim)', flexShrink: 0, width: 16, textAlign: 'center' }}>
                {ins.severity === 'ACTION' ? '\u26A1' : ins.severity === 'WARN' ? '\u25B2' : '\u2022'}
              </span>
              <div className="task-info">
                <div className="task-title">{safeStr(ins.message)}</div>
                <div className="task-meta"><span>{safeStr(ins.agent)}</span><span>{safeStr(ins.category)}</span></div>
              </div>
            </div>
          ))}
        </>
      )}

      {answered.length > 0 && (
        <button onClick={() => setExpandAnswered(!expandAnswered)} style={{ width: '100%', textAlign: 'left', background: 'none', border: 'none', borderBottom: '1px solid var(--border)', padding: '12px 12px 6px', fontFamily: 'var(--font-display)', fontSize: 11, letterSpacing: 2, textTransform: 'uppercase', color: 'var(--text-dim)', cursor: 'pointer' }}>
          {expandAnswered ? '\u25BC' : '\u25B6'} Answered — {answered.length}
        </button>
      )}
      {expandAnswered && answered.map(q => (
        <div key={q.id} style={{ padding: '6px 12px', fontSize: 10, color: 'var(--text-ghost)', borderBottom: '1px solid var(--border)' }}>
          {safeStr(q.question).slice(0, 80)}
        </div>
      ))}
    </div>
  );
}
