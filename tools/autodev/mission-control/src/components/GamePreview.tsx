import { useState, useRef, useCallback } from 'react';

// Godot web export on Vercel (deployed by godot-export.yml workflow)
const GAME_URL = 'https://web-export-pi.vercel.app';

export function GamePreview() {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [loadFailed, setLoadFailed] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen().then(() => setIsFullscreen(true)).catch(() => {});
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {});
    }
  }, []);

  return (
    <div className="panel" style={{ height: '100%' }} ref={containerRef}>
      <div className="panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span>Game Preview</span>
        <button
          onClick={toggleFullscreen}
          style={{
            background: 'var(--bg-card)',
            border: '1px solid var(--border-subtle)',
            color: 'var(--amber)',
            fontFamily: 'var(--font-mono)',
            fontSize: '10px',
            padding: '3px 10px',
            cursor: 'pointer',
            borderRadius: '2px',
            letterSpacing: '1px',
            textTransform: 'uppercase',
          }}
        >
          {isFullscreen ? 'Exit' : 'Fullscreen'}
        </button>
      </div>
      <div style={{ flex: 1, position: 'relative', minHeight: 0 }}>
        <div className="holo-frame" style={{ height: '100%' }}>
          {loadFailed ? (
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              height: '100%',
              color: 'var(--text-dim)',
              fontFamily: 'var(--font-mono)',
              fontSize: '12px',
              textAlign: 'center',
              padding: '2rem',
              background: 'var(--bg-deep)',
            }}>
              <span style={{ fontSize: '24px', marginBottom: '12px', opacity: 0.4 }}>&#9878;</span>
              <span>Godot build not available yet.</span>
              <span style={{ opacity: 0.5, marginTop: '4px' }}>Deploy to GitHub Pages to enable preview.</span>
            </div>
          ) : (
            <iframe
              src={GAME_URL}
              title="M.E.R.L.I.N. Game Preview"
              allow="fullscreen; autoplay; cross-origin-isolated"
              style={{
                width: '100%',
                height: '100%',
                border: 'none',
                background: 'var(--bg-deep)',
                display: 'block',
              }}
              sandbox="allow-scripts allow-same-origin allow-popups"
              onError={() => setLoadFailed(true)}
            />
          )}
        </div>
      </div>
    </div>
  );
}
