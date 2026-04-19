import { useState, useCallback, Component, ReactNode } from 'react';
import { useStateSync } from './hooks/useStateSync';
import { useMissionStore } from './store/mission-store';
import { GameTab } from './components/tabs/GameTab';
import { AgentsTab } from './components/tabs/AgentsTab';
import { TasksTab } from './components/tabs/TasksTab';
import { AlertsTab } from './components/tabs/AlertsTab';
import { DirectorTab } from './components/tabs/DirectorTab';
import './styles/terminal.css';

type TabId = 'game' | 'agents' | 'tasks' | 'alerts' | 'director';

const TABS: { id: TabId; icon: string; label: string }[] = [
  { id: 'game', icon: '\u25B6', label: 'Game' },
  { id: 'agents', icon: '\u2699', label: 'Agents' },
  { id: 'tasks', icon: '\u2630', label: 'Tasks' },
  { id: 'alerts', icon: '\u26A0', label: 'Alerts' },
  { id: 'director', icon: '\u2691', label: 'Director' },
];

class SafePanel extends Component<{ children: ReactNode }, { error: string | null }> {
  state = { error: null as string | null };
  static getDerivedStateFromError(e: Error) { return { error: e.message }; }
  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 20, color: '#ff3326', fontFamily: 'monospace', fontSize: 11 }}>
          <p>Panel error: {this.state.error}</p>
          <button onClick={() => this.setState({ error: null })} style={{ color: '#ffbf33', background: 'none', border: '1px solid #ffbf33', padding: '4px 12px', marginTop: 8, cursor: 'pointer', fontFamily: 'monospace' }}>
            Retry
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

export function App() {
  useStateSync();
  const connected = useMissionStore(s => s.connected);
  const alerts = useMissionStore(s => s.alerts);
  const featureQueue = useMissionStore(s => s.featureQueue);

  const [tab, setTab] = useState<TabId>(() => {
    const saved = localStorage.getItem('mc.tab') as TabId;
    return saved && TABS.some(t => t.id === saved) ? saved : 'game';
  });

  const switchTab = useCallback((id: TabId) => {
    setTab(id);
    localStorage.setItem('mc.tab', id);
  }, []);

  const pendingTasks = featureQueue?.filter(t => t.status === 'pending' || t.status === 'in_progress').length || 0;
  const errorAlerts = alerts?.filter(a => a.level === 'ERROR').length || 0;

  return (
    <div className="app">
      <header className="app__header">
        <span className="app__logo">MERLIN</span>
        <div className="app__status">
          <span className={`app__dot ${connected ? '' : 'app__dot--offline'}`} />
          <span>{connected ? 'LINKED' : 'OFFLINE'}</span>
        </div>
      </header>

      <div className="app__content">
        <div className={`tab-panel ${tab === 'game' ? 'tab-panel--active' : ''}`}><SafePanel><GameTab /></SafePanel></div>
        <div className={`tab-panel ${tab === 'agents' ? 'tab-panel--active' : ''}`}><SafePanel><AgentsTab /></SafePanel></div>
        <div className={`tab-panel ${tab === 'tasks' ? 'tab-panel--active' : ''}`}><SafePanel><TasksTab /></SafePanel></div>
        <div className={`tab-panel ${tab === 'alerts' ? 'tab-panel--active' : ''}`}><SafePanel><AlertsTab /></SafePanel></div>
        <div className={`tab-panel ${tab === 'director' ? 'tab-panel--active' : ''}`}><SafePanel><DirectorTab /></SafePanel></div>
      </div>

      <nav className="app__nav">
        {TABS.map(t => (
          <button
            key={t.id}
            className={`nav-tab ${tab === t.id ? 'nav-tab--active' : ''}`}
            onClick={() => switchTab(t.id)}
          >
            <span className="nav-tab__icon">{t.icon}</span>
            <span>{t.label}</span>
            {t.id === 'tasks' && pendingTasks > 0 && <span className="nav-tab__badge">{pendingTasks}</span>}
            {t.id === 'alerts' && errorAlerts > 0 && <span className="nav-tab__badge">{errorAlerts}</span>}
          </button>
        ))}
      </nav>
    </div>
  );
}
