export function VisualTestResults() {
  return (
    <div className="panel">
      <div className="panel-header">
        Visual Test Results
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          0 RUNS
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* Empty state */}
        <div style={{
          padding: '24px 16px',
          textAlign: 'center',
          fontFamily: 'var(--font-mono)',
        }}>
          <div style={{
            fontSize: '28px',
            marginBottom: '8px',
            opacity: 0.3,
          }}>
            &#9638;&#9638;&#9638;
          </div>
          <div style={{
            fontSize: '12px',
            color: 'var(--text-dim)',
            marginBottom: '4px',
          }}>
            No visual tests run yet
          </div>
          <div style={{
            fontSize: '10px',
            color: 'var(--text-dim)',
            opacity: 0.6,
            lineHeight: '1.5',
          }}>
            Select a scene and launch a visual test to see screenshot gallery, AI analysis, and pass/fail results here.
          </div>
        </div>

        {/* Placeholder structure for future results */}
        <div style={{
          padding: '6px 12px',
          fontSize: '10px',
          fontFamily: 'var(--font-mono)',
          color: 'var(--text-dim)',
          background: 'rgba(255, 255, 255, 0.02)',
          borderTop: '1px solid rgba(255, 255, 255, 0.05)',
          borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
          display: 'flex',
          gap: '12px',
        }}>
          <span>Screenshots: <span style={{ color: 'var(--text-secondary)' }}>--</span></span>
          <span>Passed: <span style={{ color: 'var(--green)' }}>--</span></span>
          <span>Failed: <span style={{ color: '#ff6b6b' }}>--</span></span>
        </div>

        {/* Run button */}
        <div style={{ padding: '8px 12px' }}>
          <button
            disabled
            style={{
              width: '100%',
              padding: '6px 12px',
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              letterSpacing: '1px',
              color: 'var(--text-dim)',
              background: 'rgba(255, 255, 255, 0.04)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              borderRadius: '2px',
              cursor: 'not-allowed',
              opacity: 0.5,
            }}
          >
            RUN VISUAL TEST
          </button>
        </div>
      </div>
    </div>
  );
}
