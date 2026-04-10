import { useStateSync } from './hooks/useStateSync';
import { CommandHeader } from './components/CommandHeader';
import { AgentFleet } from './components/AgentFleet';
import { StateTimeline } from './components/StateTimeline';
import { ActiveMissions } from './components/ActiveMissions';
import { AlertFeed } from './components/AlertFeed';
import { MetricsPanel } from './components/MetricsPanel';
import { FeatureQueue } from './components/FeatureQueue';
import { GamePreview } from './components/GamePreview';
import './styles/scifi-theme.css';

export function App() {
  useStateSync();

  return (
    <div style={{
      display: 'grid',
      gridTemplateRows: 'auto auto 1fr',
      gridTemplateColumns: '280px 1fr 320px',
      height: '100vh',
      gap: '4px',
      padding: '4px',
    }}>
      {/* Header row - full width */}
      <div style={{ gridColumn: '1 / -1' }}>
        <CommandHeader />
      </div>

      {/* Timeline row - full width */}
      <div style={{ gridColumn: '1 / -1' }}>
        <StateTimeline />
      </div>

      {/* Left column: Agent Fleet + Feature Queue */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', overflow: 'hidden' }}>
        <div style={{ flex: '1 1 60%', overflow: 'hidden' }}>
          <AgentFleet />
        </div>
        <div style={{ flex: '1 1 40%', overflow: 'hidden' }}>
          <FeatureQueue />
        </div>
      </div>

      {/* Center column: Game Preview + Active Missions */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', overflow: 'hidden' }}>
        <div style={{ flex: '0 0 280px' }}>
          <GamePreview />
        </div>
        <div style={{ flex: 1, overflow: 'hidden' }}>
          <ActiveMissions />
        </div>
      </div>

      {/* Right column: Metrics + Alert Feed */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', overflow: 'hidden' }}>
        <div style={{ flex: '0 0 auto' }}>
          <MetricsPanel />
        </div>
        <div style={{ flex: 1, overflow: 'hidden' }}>
          <AlertFeed />
        </div>
      </div>
    </div>
  );
}
