import { useState } from 'react';
import { useMissionStore } from '../../store/mission-store';
import { FeedbackCard } from '../feedback/FeedbackCard';

const CATEGORIES = ['ALL', 'DESIGN', 'GRAPHICS', 'GAMEDESIGN', 'RENDERING', 'UX', 'INFRASTRUCTURE'] as const;
const PRIORITY_ORDER: Record<string, number> = { HIGH: 0, MEDIUM: 1, LOW: 2 };

export function DirectorTab() {
  const questions = useMissionStore(s => s.feedbackQuestions);
  const submitting = useMissionStore(s => s.feedbackSubmitting);
  const submitFeedback = useMissionStore(s => s.submitFeedback);
  const [activeTab, setActiveTab] = useState<string>('ALL');
  const [showAnswered, setShowAnswered] = useState(false);

  const pending = questions
    .filter(q => q.status === 'pending')
    .filter(q => activeTab === 'ALL' || q.category.toUpperCase() === activeTab)
    .sort((a, b) => (PRIORITY_ORDER[a.priority] ?? 2) - (PRIORITY_ORDER[b.priority] ?? 2));

  const answered = questions
    .filter(q => q.status === 'answered')
    .filter(q => activeTab === 'ALL' || q.category.toUpperCase() === activeTab);

  const pendingCount = questions.filter(q => q.status === 'pending').length;

  return (
    <div className="feedback-panel">
      <div className="feedback-panel__header">
        <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '14px', color: 'var(--amber)', letterSpacing: '2px' }}>
          DIRECTOR'S INBOX
          {pendingCount > 0 && <span className="feedback-badge">{pendingCount}</span>}
        </h2>
      </div>

      <div className="feedback-tabs">
        {CATEGORIES.map(cat => (
          <button
            key={cat}
            type="button"
            className={`feedback-tab ${activeTab === cat ? 'feedback-tab--active' : ''}`}
            onClick={() => setActiveTab(cat)}
          >
            {cat}
          </button>
        ))}
      </div>

      {pending.length === 0 && (
        <div className="feedback-empty">
          No pending directives. The studio awaits your guidance.
        </div>
      )}

      <div className="feedback-list">
        {pending.map(q => (
          <FeedbackCard key={q.id} question={q} onSubmit={submitFeedback} submitting={submitting} />
        ))}
      </div>

      {answered.length > 0 && (
        <div className="feedback-answered-section">
          <button
            type="button"
            className="feedback-answered-toggle"
            onClick={() => setShowAnswered(!showAnswered)}
          >
            {showAnswered ? '▼' : '▶'} Answered ({answered.length})
          </button>
          {showAnswered && (
            <div className="feedback-list feedback-list--answered">
              {answered.map(q => (
                <FeedbackCard key={q.id} question={q} onSubmit={submitFeedback} submitting={false} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
