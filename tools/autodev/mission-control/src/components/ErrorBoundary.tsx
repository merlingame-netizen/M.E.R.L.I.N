import { Component, type ReactNode, type ErrorInfo } from 'react';

interface Props {
  label: string;
  children: ReactNode;
}

interface State {
  error: Error | null;
  info: ErrorInfo | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null, info: null };

  static getDerivedStateFromError(error: Error): Partial<State> {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.setState({ info });
    console.error(`[${this.props.label}] component crash:`, error, info.componentStack);
  }

  reset = () => this.setState({ error: null, info: null });

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            padding: 16,
            borderRadius: 14,
            border: '1px solid rgba(239, 68, 68, 0.4)',
            background: 'rgba(239, 68, 68, 0.08)',
            color: '#fca5a5',
            fontFamily: 'Fira Code, monospace',
            fontSize: 12,
          }}
        >
          <div style={{ fontWeight: 600, marginBottom: 8, color: '#ef4444' }}>
            [{this.props.label}] crashed
          </div>
          <div style={{ opacity: 0.85, marginBottom: 8 }}>{this.state.error.message}</div>
          {this.state.info?.componentStack && (
            <pre
              style={{
                maxHeight: 120,
                overflow: 'auto',
                fontSize: 10,
                opacity: 0.6,
                margin: 0,
                whiteSpace: 'pre-wrap',
              }}
            >
              {this.state.info.componentStack.trim().split('\n').slice(0, 8).join('\n')}
            </pre>
          )}
          <button
            type="button"
            onClick={this.reset}
            style={{
              marginTop: 10,
              padding: '4px 10px',
              border: '1px solid rgba(239, 68, 68, 0.4)',
              borderRadius: 8,
              background: 'transparent',
              color: '#fca5a5',
              fontFamily: 'inherit',
              fontSize: 11,
              cursor: 'pointer',
            }}
          >
            retry
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
