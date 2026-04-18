import { useState, useRef, useCallback, useEffect } from 'react';

const GAME_URL = 'https://project-4o9qm.vercel.app';
const DEPLOY_API = '/api/deploy-status';
const POLL_INTERVAL = 15_000;

interface DeployInfo {
  run_number: number;
  status: string;
  conclusion?: string;
  head_sha: string;
  head_message: string;
  created_at: string;
  updated_at?: string;
  duration_s?: number;
  elapsed_s?: number;
}

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function DeployStatusBar({ latest, deploying }: { latest: DeployInfo | null; deploying: DeployInfo | null }) {
  const [elapsed, setElapsed] = useState(deploying?.elapsed_s || 0);

  useEffect(() => {
    if (!deploying) { setElapsed(0); return; }
    setElapsed(deploying.elapsed_s || 0);
    const interval = setInterval(() => setElapsed(prev => prev + 1), 1000);
    return () => clearInterval(interval);
  }, [deploying]);

  const barStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '6px 10px',
    fontFamily: 'var(--font-mono)',
    fontSize: '10px',
    letterSpacing: '0.5px',
    borderTop: '1px solid var(--border-subtle)',
    background: 'var(--bg-deep)',
    minHeight: '28px',
  };

  if (deploying) {
    return (
      <div style={barStyle}>
        <span style={{ color: 'var(--amber)', animation: 'crt-cursor-blink 1s steps(2) infinite' }}>&#9654;</span>
        <span style={{ color: 'var(--amber)' }}>DEPLOYING</span>
        <span style={{ color: 'var(--text-dim)' }}>#{deploying.run_number}</span>
        <span style={{ color: 'var(--phosphor)', fontFamily: 'var(--font-mono)' }}>{formatTime(elapsed)}</span>
        <span style={{ color: 'var(--text-dim)', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {deploying.head_sha} {deploying.head_message.slice(0, 50)}
        </span>
      </div>
    );
  }

  if (latest) {
    const ok = latest.conclusion === 'success';
    const color = ok ? 'var(--phosphor)' : 'var(--danger, #ff4444)';
    const icon = ok ? '\u2713' : '\u2717';
    const ago = Math.round((Date.now() - new Date(latest.updated_at || latest.created_at).getTime()) / 60000);
    const agoStr = ago < 1 ? 'just now' : ago < 60 ? `${ago}m ago` : `${Math.round(ago / 60)}h ago`;

    return (
      <div style={barStyle}>
        <span style={{ color }}>{icon}</span>
        <span style={{ color }}>BUILD #{latest.run_number}</span>
        <span style={{ color: 'var(--text-dim)' }}>{latest.head_sha}</span>
        <span style={{ color: 'var(--text-dim)' }}>{formatTime(latest.duration_s || 0)}</span>
        <span style={{ color: 'var(--text-dim)' }}>{agoStr}</span>
        <span style={{ color: 'var(--text-dim)', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {latest.head_message.slice(0, 50)}
        </span>
      </div>
    );
  }

  return (
    <div style={barStyle}>
      <span style={{ color: 'var(--text-dim)' }}>No deploy info available</span>
    </div>
  );
}

export function GamePreview() {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [latest, setLatest] = useState<DeployInfo | null>(null);
  const [deploying, setDeploying] = useState<DeployInfo | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen().then(() => setIsFullscreen(true)).catch(() => {});
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {});
    }
  }, []);

  useEffect(() => {
    async function poll() {
      try {
        const res = await fetch(DEPLOY_API);
        if (!res.ok) return;
        const json = await res.json();
        if (json.latest) setLatest(json.latest);
        setDeploying(json.deploying || null);
      } catch { /* silent */ }
    }
    poll();
    const interval = setInterval(poll, POLL_INTERVAL);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="panel" style={{ height: '100%', display: 'flex', flexDirection: 'column' }} ref={containerRef}>
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
            src={GAME_URL}
            title="M.E.R.L.I.N. Godot WebAssembly"
            allow="fullscreen; autoplay; cross-origin-isolated"
            style={{
              width: '100%',
              height: '100%',
              border: 'none',
              background: '#020507',
              display: 'block',
            }}
            sandbox="allow-scripts allow-same-origin allow-popups"
          />
        </div>
      </div>
      <DeployStatusBar latest={latest} deploying={deploying} />
    </div>
  );
}
