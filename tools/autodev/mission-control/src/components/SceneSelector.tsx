import { useState, useEffect } from 'react';

interface SceneFile {
  name: string;
  path: string;
  size: number;
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const kb = bytes / 1024;
  if (kb < 1024) return `${kb.toFixed(1)} KB`;
  return `${(kb / 1024).toFixed(1)} MB`;
}

export function SceneSelector() {
  const [scenes, setScenes] = useState<SceneFile[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [launching, setLaunching] = useState(false);
  const [launchResult, setLaunchResult] = useState<string | null>(null);

  useEffect(() => {
    const API_URL = import.meta.env.VITE_API_URL
      ? `${import.meta.env.VITE_API_URL.replace('/status', '/scenes')}`
      : '/api/scenes';

    fetch(API_URL)
      .then(res => res.json())
      .then(data => {
        if (data.ok) {
          setScenes(data.scenes);
          if (data.scenes.length > 0) {
            setSelected(data.scenes[0].path);
          }
        } else {
          setError(data.error || 'Failed to load scenes');
        }
      })
      .catch(() => setError('Network error fetching scenes'))
      .finally(() => setLoading(false));
  }, []);

  const selectedScene = scenes.find(s => s.path === selected);

  const handleLaunchTest = async () => {
    if (!selected) return;
    setLaunching(true);
    setLaunchResult(null);
    try {
      const API_URL = import.meta.env.VITE_API_URL
        ? `${import.meta.env.VITE_API_URL.replace('/status', '/visual-test')}`
        : '/api/visual-test';
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scene: selected, duration: 30 }),
      });
      const data = await res.json();
      if (data.ok) {
        setLaunchResult('REQUEST QUEUED');
      } else {
        setLaunchResult(data.error || 'Failed');
      }
    } catch {
      setLaunchResult('Network error');
    } finally {
      setLaunching(false);
    }
  };

  return (
    <div className="panel">
      <div className="panel-header">
        Scene Selector
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0',
        }}>
          {scenes.length} SCENES
        </span>
      </div>
      <div className="panel-body" style={{ padding: '0' }}>
        {/* Selected scene banner */}
        {selectedScene && (
          <div style={{
            padding: '8px 12px',
            fontSize: '12px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--green)',
            background: 'rgba(0, 255, 136, 0.06)',
            borderBottom: '1px solid rgba(0, 255, 136, 0.1)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}>
            <span style={{ fontSize: '14px' }}>&#9654;</span>
            <span style={{ fontWeight: 700 }}>{selectedScene.name}</span>
            <span style={{ fontSize: '10px', color: 'var(--text-dim)', marginLeft: 'auto' }}>
              {formatSize(selectedScene.size)}
            </span>
          </div>
        )}

        {loading && (
          <div style={{ padding: '12px 16px', fontSize: '12px', color: 'var(--text-dim)' }}>
            Loading scenes...
          </div>
        )}

        {error && (
          <div style={{ padding: '12px 16px', fontSize: '12px', color: 'var(--amber)' }}>
            {error}
          </div>
        )}

        {!loading && !error && scenes.length === 0 && (
          <div style={{ padding: '12px 16px', opacity: 0.5, fontSize: '12px' }}>
            No .tscn scenes found
          </div>
        )}

        {scenes.map(scene => (
          <div
            key={scene.path}
            onClick={() => setSelected(scene.path)}
            style={{
              padding: '6px 12px',
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
              color: selected === scene.path ? 'var(--green)' : 'var(--text-primary)',
              background: selected === scene.path ? 'rgba(0, 255, 136, 0.04)' : 'transparent',
              borderBottom: '1px solid rgba(255, 255, 255, 0.04)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              transition: 'background 0.15s ease',
            }}
          >
            <span style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              border: `2px solid ${selected === scene.path ? 'var(--green)' : 'var(--text-dim)'}`,
              background: selected === scene.path ? 'var(--green)' : 'transparent',
              flexShrink: 0,
              boxShadow: selected === scene.path ? 'var(--glow-green)' : 'none',
            }} />
            <span style={{ flex: 1 }}>{scene.name}</span>
            <span style={{ fontSize: '10px', color: 'var(--text-dim)' }}>
              {formatSize(scene.size)}
            </span>
          </div>
        ))}

        {/* Launch button */}
        <div style={{ padding: '8px 12px' }}>
          <button
            disabled={!selected || launching}
            onClick={handleLaunchTest}
            style={{
              width: '100%',
              padding: '6px 12px',
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
              fontWeight: 700,
              letterSpacing: '1px',
              color: !selected || launching ? 'var(--text-dim)' : 'var(--green)',
              background: !selected || launching
                ? 'rgba(255, 255, 255, 0.04)'
                : 'rgba(0, 255, 136, 0.1)',
              border: `1px solid ${!selected || launching ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 255, 136, 0.2)'}`,
              borderRadius: '2px',
              cursor: !selected || launching ? 'not-allowed' : 'pointer',
              opacity: !selected || launching ? 0.5 : 1,
            }}
          >
            {launching ? 'REQUESTING...' : 'LAUNCH VISUAL TEST'}
          </button>
          {launchResult && (
            <div style={{
              marginTop: '4px',
              fontSize: '10px',
              fontFamily: 'var(--font-mono)',
              color: launchResult === 'REQUEST QUEUED' ? 'var(--green)' : 'var(--amber)',
              textAlign: 'center',
            }}>
              {launchResult}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
