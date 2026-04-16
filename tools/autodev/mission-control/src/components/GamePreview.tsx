import { useState, useRef, useCallback } from 'react';

// Game build URLs — GitHub Pages (free, auto-deploy) with Vercel fallback
const GAME_URLS = [
  'https://merlingame-netizen.github.io/M.E.R.L.I.N/',
  'https://web-export-pi.vercel.app',
];

export function GamePreview() {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [urlIndex, setUrlIndex] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen().then(() => setIsFullscreen(true)).catch(() => {});
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {});
    }
  }, []);

  const handleIframeError = useCallback(() => {
    if (urlIndex < GAME_URLS.length - 1) {
      setUrlIndex(urlIndex + 1);
    }
  }, [urlIndex]);

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
          <iframe
            src={GAME_URLS[urlIndex]}
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
            onError={handleIframeError}
          />
        </div>
      </div>
    </div>
  );
}
