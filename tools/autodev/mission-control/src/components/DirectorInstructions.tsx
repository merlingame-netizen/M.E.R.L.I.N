import { useState } from 'react';

const TYPES = ['dev', 'test', 'fix'];

type SendState = 'idle' | 'sending' | 'success' | 'error';

export function DirectorInstructions() {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [type, setType] = useState('dev');
  const [state, setState] = useState<SendState>('idle');
  const [message, setMessage] = useState('');

  async function handleSubmit() {
    if (title.trim().length < 5) {
      setState('error');
      setMessage('Title must be at least 5 characters');
      return;
    }

    setState('sending');
    setMessage('');

    try {
      const API_URL = import.meta.env.VITE_API_URL
        ? import.meta.env.VITE_API_URL.replace('/status', '/instructions')
        : '/api/instructions';

      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: title.trim(),
          description: description.trim() || undefined,
          type,
        }),
      });

      const json = await res.json();
      if (json.ok) {
        setState('success');
        setMessage(`Queued: ${json.task.id}`);
        setTitle('');
        setDescription('');
      } else {
        setState('error');
        setMessage(json.error || 'Failed to add task');
      }
    } catch (err: unknown) {
      setState('error');
      setMessage(err instanceof Error ? err.message : 'Network error');
    }
  }

  const inputStyle = {
    width: '100%',
    background: 'rgba(0,0,0,0.4)',
    color: 'var(--text-primary)',
    border: '1px solid rgba(0,255,136,0.2)',
    borderRadius: '3px',
    padding: '5px 8px',
    fontSize: '11px',
    fontFamily: 'var(--font-mono)',
    outline: 'none',
    boxSizing: 'border-box' as const,
  };

  const labelStyle = {
    fontSize: '10px',
    fontFamily: 'var(--font-mono)',
    color: 'var(--text-secondary)',
    display: 'block' as const,
    marginBottom: '3px',
  };

  return (
    <div className="panel">
      <div className="panel-header">
        Queue Task
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
        }}>
          AUTO-DISPATCH
        </span>
      </div>
      <div className="panel-body" style={{ padding: '10px 12px' }}>
        {/* Title */}
        <div style={{ marginBottom: '6px' }}>
          <label style={labelStyle}>TASK *</label>
          <input
            type="text"
            value={title}
            onChange={e => { setTitle(e.target.value); setState('idle'); }}
            placeholder="Fix biome intervals, Add SFX for card draw..."
            style={inputStyle}
          />
        </div>

        {/* Description */}
        <div style={{ marginBottom: '6px' }}>
          <label style={labelStyle}>DETAILS</label>
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="Optional context for the bot..."
            rows={2}
            style={{
              ...inputStyle,
              resize: 'vertical',
              minHeight: '36px',
            }}
          />
        </div>

        {/* Type selector */}
        <div style={{ marginBottom: '8px' }}>
          <label style={labelStyle}>TYPE</label>
          <div style={{ display: 'flex', gap: '4px' }}>
            {TYPES.map(t => (
              <button
                key={t}
                onClick={() => setType(t)}
                style={{
                  flex: 1,
                  padding: '4px 8px',
                  fontSize: '10px',
                  fontFamily: 'var(--font-mono)',
                  fontWeight: 700,
                  letterSpacing: '1px',
                  background: type === t
                    ? t === 'fix' ? 'rgba(255,60,60,0.2)' : t === 'test' ? 'rgba(255,165,0,0.2)' : 'rgba(0,255,136,0.15)'
                    : 'rgba(255,255,255,0.04)',
                  color: type === t
                    ? t === 'fix' ? '#ff6b6b' : t === 'test' ? 'var(--amber)' : 'var(--green)'
                    : 'var(--text-dim)',
                  border: `1px solid ${type === t
                    ? t === 'fix' ? 'rgba(255,60,60,0.3)' : t === 'test' ? 'rgba(255,165,0,0.3)' : 'rgba(0,255,136,0.3)'
                    : 'rgba(255,255,255,0.1)'}`,
                  borderRadius: '2px',
                  cursor: 'pointer',
                }}
              >
                {t.toUpperCase()}
              </button>
            ))}
          </div>
        </div>

        {/* Submit */}
        <button
          onClick={handleSubmit}
          disabled={state === 'sending' || title.trim().length < 5}
          style={{
            width: '100%',
            padding: '6px',
            background: state === 'sending'
              ? 'rgba(255,165,0,0.2)'
              : 'rgba(0,255,136,0.15)',
            color: state === 'sending' ? 'var(--amber)' : 'var(--green)',
            border: `1px solid ${state === 'sending' ? 'rgba(255,165,0,0.3)' : 'rgba(0,255,136,0.3)'}`,
            borderRadius: '3px',
            fontSize: '11px',
            fontFamily: 'var(--font-mono)',
            fontWeight: 700,
            cursor: state === 'sending' || title.trim().length < 5 ? 'not-allowed' : 'pointer',
            letterSpacing: '1px',
            opacity: title.trim().length < 5 ? 0.4 : 1,
          }}
        >
          {state === 'sending' ? 'QUEUING...' : 'QUEUE TASK'}
        </button>

        {/* Status */}
        {message && (
          <div style={{
            marginTop: '6px',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
            color: state === 'success' ? 'var(--green)' : '#ff6b6b',
            padding: '4px 6px',
            background: state === 'success' ? 'rgba(0,255,136,0.06)' : 'rgba(255,60,60,0.06)',
            borderRadius: '2px',
          }}>
            {message}
          </div>
        )}
      </div>
    </div>
  );
}
