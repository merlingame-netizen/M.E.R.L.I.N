import { useState } from 'react';
import type { FeedbackQuestion } from '../../store/mission-store';
import { ImageCompare } from './ImageCompare';

interface FeedbackCardProps {
  question: FeedbackQuestion;
  onSubmit: (questionId: string, answer: string, notes?: string) => void;
  submitting: boolean;
}

const CATEGORY_COLORS: Record<string, string> = {
  design: '#e6a817',
  graphics: '#17e6a8',
  gamedesign: '#e67817',
  rendering: '#a817e6',
  ux: '#17a8e6',
  infrastructure: '#8888aa',
};

export function FeedbackCard({ question, onSubmit, submitting }: FeedbackCardProps) {
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [textAnswer, setTextAnswer] = useState('');
  const [notes, setNotes] = useState('');
  const isAnswered = question.status === 'answered';

  const canSubmit = question.type === 'text'
    ? textAnswer.trim().length > 0
    : selectedOption !== null;

  function handleSubmit() {
    const answer = question.type === 'text' ? textAnswer.trim() : selectedOption!;
    onSubmit(question.id, answer, notes.trim() || undefined);
  }

  const borderColor = CATEGORY_COLORS[question.category] || '#888';

  return (
    <div
      className={`feedback-card ${isAnswered ? 'feedback-card--answered' : ''}`}
      style={{ borderLeftColor: borderColor }}
    >
      <div className="feedback-card__header">
        <span className={`feedback-priority feedback-priority--${question.priority}`}>
          {question.priority}
        </span>
        <span className="feedback-category" style={{ color: borderColor }}>
          {question.category.toUpperCase()}
        </span>
      </div>

      <p className="feedback-card__question">{question.question}</p>
      {question.context && (
        <p className="feedback-card__context">{question.context}</p>
      )}

      {!isAnswered && (
        <div className="feedback-card__body">
          {question.type === 'multiple_choice' && question.options && (
            <div className="feedback-options">
              {question.options.map(opt => (
                <button
                  key={opt}
                  type="button"
                  className={`feedback-option ${selectedOption === opt ? 'feedback-option--selected' : ''}`}
                  onClick={() => setSelectedOption(opt)}
                >
                  {opt}
                </button>
              ))}
            </div>
          )}

          {question.type === 'image_compare' && question.screenshot_urls && question.options && (
            <ImageCompare
              urls={question.screenshot_urls as [string, string]}
              labels={question.options as [string, string]}
              selected={selectedOption}
              onSelect={setSelectedOption}
            />
          )}

          {question.type === 'text' && (
            <textarea
              className="feedback-textarea"
              placeholder="Enter your directive, Director..."
              value={textAnswer}
              onChange={e => setTextAnswer(e.target.value)}
              rows={4}
            />
          )}

          <textarea
            className="feedback-textarea feedback-textarea--notes"
            placeholder="Additional notes (optional)..."
            value={notes}
            onChange={e => setNotes(e.target.value)}
            rows={2}
          />

          <button
            type="button"
            className="feedback-submit"
            disabled={!canSubmit || submitting}
            onClick={handleSubmit}
          >
            {submitting ? 'TRANSMITTING...' : 'TRANSMIT'}
          </button>
        </div>
      )}

      {isAnswered && (
        <div className="feedback-card__answered-badge">DIRECTIVE TRANSMITTED</div>
      )}
    </div>
  );
}
