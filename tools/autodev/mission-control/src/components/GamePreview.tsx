export function GamePreview() {
  return (
    <div className="panel" style={{ height: '100%' }}>
      <div className="panel-header">Game Preview</div>
      <div style={{ flex: 1, position: 'relative', minHeight: 0 }}>
        <div className="holo-frame" style={{ height: '100%' }}>
          <iframe
            src="https://web-export-pi.vercel.app"
            title="M.E.R.L.I.N. Game Preview"
            style={{
              width: '100%',
              height: '100%',
              border: 'none',
              background: 'var(--bg-deep)',
              display: 'block',
            }}
            sandbox="allow-scripts allow-same-origin allow-popups"
          />
        </div>
      </div>
    </div>
  );
}
