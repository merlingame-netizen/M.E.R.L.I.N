import { useState, useRef } from 'react';

const UPLOAD_TARGETS: Record<string, string[]> = {
  'Assets/audio/music': ['.ogg', '.wav', '.mp3'],
  'Assets/audio/sfx': ['.ogg', '.wav', '.mp3'],
  'Assets/models': ['.glb', '.gltf', '.obj', '.fbx', '.blend'],
  'Assets/textures': ['.png', '.jpg', '.jpeg', '.webp', '.svg'],
  'Assets/fonts': ['.ttf', '.otf', '.woff', '.woff2'],
};

type UploadState = 'idle' | 'uploading' | 'success' | 'error';

export function FileUpload() {
  const [directory, setDirectory] = useState('Assets/audio/music');
  const [state, setState] = useState<UploadState>('idle');
  const [message, setMessage] = useState('');
  const [fileName, setFileName] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const acceptExts = UPLOAD_TARGETS[directory]?.join(',') || '';

  async function handleUpload() {
    const file = fileRef.current?.files?.[0];
    if (!file) {
      setMessage('Select a file first');
      setState('error');
      return;
    }

    setState('uploading');
    setMessage('');

    try {
      const buffer = await file.arrayBuffer();
      const base64 = btoa(
        new Uint8Array(buffer).reduce((data, byte) => data + String.fromCharCode(byte), '')
      );

      const API_URL = import.meta.env.VITE_API_URL
        ? import.meta.env.VITE_API_URL.replace('/status', '/upload')
        : '/api/upload';

      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          filename: file.name,
          directory,
          content_base64: base64,
        }),
      });

      const json = await res.json();
      if (json.ok) {
        setState('success');
        setMessage(`Uploaded: ${json.path}${json.replaced ? ' (replaced)' : ''}`);
        setFileName('');
        if (fileRef.current) fileRef.current.value = '';
      } else {
        setState('error');
        setMessage(json.error || 'Upload failed');
      }
    } catch (err: unknown) {
      setState('error');
      setMessage(err instanceof Error ? err.message : 'Network error');
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        Asset Upload
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
        }}>
          REPO DIRECT
        </span>
      </div>
      <div className="panel-body" style={{ padding: '10px 12px' }}>
        {/* Directory selector */}
        <div style={{ marginBottom: '8px' }}>
          <label style={{
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-secondary)',
            display: 'block',
            marginBottom: '4px',
          }}>
            TARGET DIRECTORY
          </label>
          <select
            value={directory}
            onChange={e => setDirectory(e.target.value)}
            style={{
              width: '100%',
              background: 'rgba(0,0,0,0.4)',
              color: 'var(--green)',
              border: '1px solid rgba(0,255,136,0.2)',
              borderRadius: '3px',
              padding: '5px 8px',
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
              outline: 'none',
            }}
          >
            {Object.entries(UPLOAD_TARGETS).map(([dir, exts]) => (
              <option key={dir} value={dir}>
                {dir} ({exts.join(', ')})
              </option>
            ))}
          </select>
        </div>

        {/* File input */}
        <div style={{ marginBottom: '8px' }}>
          <label style={{
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: 'var(--text-secondary)',
            display: 'block',
            marginBottom: '4px',
          }}>
            FILE
          </label>
          <input
            ref={fileRef}
            type="file"
            accept={acceptExts}
            onChange={e => setFileName(e.target.files?.[0]?.name || '')}
            style={{
              width: '100%',
              background: 'rgba(0,0,0,0.4)',
              color: 'var(--text-primary)',
              border: '1px solid rgba(0,255,136,0.2)',
              borderRadius: '3px',
              padding: '4px 8px',
              fontSize: '11px',
              fontFamily: 'var(--font-mono)',
            }}
          />
        </div>

        {/* Upload button */}
        <button
          onClick={handleUpload}
          disabled={state === 'uploading' || !fileName}
          style={{
            width: '100%',
            padding: '6px',
            background: state === 'uploading'
              ? 'rgba(255,165,0,0.2)'
              : 'rgba(0,255,136,0.15)',
            color: state === 'uploading' ? 'var(--amber)' : 'var(--green)',
            border: `1px solid ${state === 'uploading' ? 'rgba(255,165,0,0.3)' : 'rgba(0,255,136,0.3)'}`,
            borderRadius: '3px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            fontWeight: 700,
            cursor: state === 'uploading' || !fileName ? 'not-allowed' : 'pointer',
            letterSpacing: '1px',
            opacity: !fileName ? 0.4 : 1,
          }}
        >
          {state === 'uploading' ? 'UPLOADING...' : 'UPLOAD TO REPO'}
        </button>

        {/* Status message */}
        {message && (
          <div style={{
            marginTop: '6px',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: state === 'success' ? 'var(--green)' : state === 'error' ? '#ff6b6b' : 'var(--text-secondary)',
            padding: '4px 6px',
            background: state === 'success'
              ? 'rgba(0,255,136,0.06)'
              : state === 'error'
                ? 'rgba(255,60,60,0.06)'
                : 'transparent',
            borderRadius: '2px',
          }}>
            {message}
          </div>
        )}
      </div>
    </div>
  );
}
