import { useState } from 'react';

const SPRINTS = ['S2', 'S3', 'S4'];
const TYPES = ['dev', 'test'];
const AGENTS = ['godot_expert', 'bug_hunter', 'game_playtester', 'game_design_auditor', 'narrative_designer'];

type SendState = 'idle' | 'sending' | 'success' | 'error';

export function DirectorInstructions() {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [sprint, setSprint] = useState('S2');
  const [type, setType] = useState('dev');
  const [agent, setAgent] = useState('godot_expert');
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
          sprint,
          type,
          agent,
        }),
      });

      const json = await res.json();
      if (json.ok) {
        setState('success');
        setMessage(`Task ${json.task.id} added to queue`);
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
        Director Instructions
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
        }}>
          ADD TASK
        </span>
      </div>
      <div className="panel-body" style={{ padding: '10px 12px' }}>
        {/* Title */}
        <div style={{ marginBottom: '6px' }}>
          <label style={labelStyle}>TASK TITLE *</label>
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
          <label style={labelStyle}>DESCRIPTION</label>
          <textarea
            value={description}
            onChange={e => setDescription(e.target.value)}
            placeholder="Detailed instructions for the bot..."
            rows={3}
            style={{
              ...inputStyle,
              resize: 'vertical',
              minHeight: '48px',
            }}
          />
        </div>

        {/* Sprint + Type + Agent row */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr 1fr',
          gap: '6px',
          marginBottom: '8px',
        }}>
          <div>
            <label style={labelStyle}>SPRINT</label>
            <select value={sprint} onChange={e => setSprint(e.target.value)} style={inputStyle}>
              {SPRINTS.map(s => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          <div>
            <label style={labelStyle}>TYPE</label>
            <select value={type} onChange={e => setType(e.target.value)} style={inputStyle}>
              {TYPES.map(t => <option key={t} value={t}>{t.toUpperCase()}</option>)}
            </select>
          </div>
          <div>
            <label style={labelStyle}>AGENT</label>
            <select value={agent} onChange={e => setAgent(e.target.value)} style={inputStyle}>
              {AGENTS.map(a => <option key={a} value={a}>{a}</option>)}
            </select>
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
          {state === 'sending' ? 'SENDING...' : 'ADD TO PENDING QUEUE'}
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
