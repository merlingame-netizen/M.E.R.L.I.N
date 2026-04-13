import { useState } from 'react';

type Severity = 'INFO' | 'WARN' | 'ACTION';

interface Insight {
  id: string;
  severity: Severity;
  agent: string;
  message: string;
  timestamp: string;
}

const STATIC_INSIGHTS: Insight[] = [
  {
    id: 'ins-001',
    severity: 'ACTION',
    agent: 'Visual QA',
    message: 'No screenshot tests configured yet — recommend enabling visual_test_runner',
    timestamp: '2026-04-13T08:00:00Z',
  },
  {
    id: 'ins-002',
    severity: 'WARN',
    agent: 'i18n Auditor',
    message: '192 hardcoded French strings detected — text_registry.json needed',
    timestamp: '2026-04-13T07:45:00Z',
  },
  {
    id: 'ins-003',
    severity: 'INFO',
    agent: 'UX Reviewer',
    message: 'Card overlay text may be too small on mobile (< 11px)',
    timestamp: '2026-04-13T07:30:00Z',
  },
];

function getSeverityStyle(severity: Severity): { bg: string; color: string } {
  switch (severity) {
    case 'ACTION':
      return { bg: 'rgba(255, 60, 60, 0.15)', color: '#ff6b6b' };
    case 'WARN':
      return { bg: 'rgba(255, 165, 0, 0.15)', color: 'var(--amber)' };
    case 'INFO':
      return { bg: 'rgba(0, 255, 136, 0.15)', color: 'var(--green)' };
  }
}

function formatTime(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  } catch {
    return '--:--';
  }
}

export function StudioInsights() {
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());
  const [approved, setApproved] = useState<Set<string>>(new Set());

  const visible = STATIC_INSIGHTS.filter(i => !dismissed.has(i.id));

  const handleDismiss = (id: string) => {
    setDismissed(prev => new Set([...prev, id]));
  };

  const handleApprove = (id: string) => {
    setApproved(prev => new Set([...prev, id]));
  };

  return (
    <div className="panel">
      <div className="panel-header">
        Studio Insights
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {visible.length} ACTIVE
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {visible.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            All insights reviewed
          </div>
        )}

        {visible.map(insight => {
          const sev = getSeverityStyle(insight.severity);
          const isApproved = approved.has(insight.id);

          return (
            <div key={insight.id} style={{
              padding: '8px 12px',
              borderBottom: '1px solid rgba(255, 255, 255, 0.04)',
              background: isApproved ? 'rgba(0, 255, 136, 0.03)' : 'transparent',
            }}>
              {/* Top row: severity + agent + timestamp */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                marginBottom: '4px',
              }}>
                <span style={{
                  fontSize: '9px',
                  fontWeight: 700,
                  padding: '1px 4px',
                  borderRadius: '2px',
                  background: sev.bg,
                  color: sev.color,
                  letterSpacing: '0.5px',
                  flexShrink: 0,
                }}>
                  {insight.severity}
                </span>
                <span style={{
                  fontSize: '11px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--amber)',
                  fontWeight: 700,
                }}>
                  {insight.agent}
                </span>
                <span style={{
                  marginLeft: 'auto',
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-dim)',
                }}>
                  {formatTime(insight.timestamp)}
                </span>
              </div>

              {/* Message */}
              <div style={{
                fontSize: '11px',
                fontFamily: 'var(--font-mono)',
                color: 'var(--text-primary)',
                lineHeight: '1.5',
                marginBottom: '6px',
              }}>
                {insight.message}
              </div>

              {/* Action buttons */}
              <div style={{ display: 'flex', gap: '6px' }}>
                <button
                  onClick={() => handleApprove(insight.id)}
                  disabled={isApproved}
                  style={{
                    padding: '3px 8px',
                    fontSize: '10px',
                    fontFamily: 'var(--font-mono)',
                    fontWeight: 700,
                    color: isApproved ? 'var(--text-dim)' : 'var(--green)',
                    background: isApproved
                      ? 'rgba(255, 255, 255, 0.04)'
                      : 'rgba(0, 255, 136, 0.1)',
                    border: `1px solid ${isApproved ? 'rgba(255,255,255,0.1)' : 'rgba(0, 255, 136, 0.2)'}`,
                    borderRadius: '2px',
                    cursor: isApproved ? 'default' : 'pointer',
                    letterSpacing: '0.5px',
                  }}
                >
                  {isApproved ? 'APPROVED' : 'APPROVE'}
                </button>
                <button
                  onClick={() => handleDismiss(insight.id)}
                  style={{
                    padding: '3px 8px',
                    fontSize: '10px',
                    fontFamily: 'var(--font-mono)',
                    fontWeight: 700,
                    color: 'var(--text-dim)',
                    background: 'rgba(255, 255, 255, 0.04)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    borderRadius: '2px',
                    cursor: 'pointer',
                    letterSpacing: '0.5px',
                  }}
                >
                  DISMISS
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
