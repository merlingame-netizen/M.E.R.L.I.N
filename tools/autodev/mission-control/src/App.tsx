import { useStateSync } from './hooks/useStateSync';
import { CommandHeader } from './components/CommandHeader';
import { AgentFleet } from './components/AgentFleet';
import { StateTimeline } from './components/StateTimeline';
import { ActiveMissions } from './components/ActiveMissions';
import { AlertFeed } from './components/AlertFeed';
import { MetricsPanel } from './components/MetricsPanel';
import { FeatureQueue } from './components/FeatureQueue';
import { GamePreview } from './components/GamePreview';
import { HumanFeedback } from './components/HumanFeedback';
import { FileUpload } from './components/FileUpload';
import { DirectorInstructions } from './components/DirectorInstructions';
import { SceneSelector } from './components/SceneSelector';
import { DevCycleSummary } from './components/DevCycleSummary';
import { SpecialistRotation } from './components/SpecialistRotation';
import { StudioInsights } from './components/StudioInsights';
import './styles/scifi-theme.css';

export function App() {
  useStateSync();

  return (
    <div className="crt-screen">
      {/* CRT scanline overlay */}
      <div className="crt-scanlines" aria-hidden="true" />

      <div className="dashboard-layout">
        {/* Header */}
        <div className="dashboard-layout__full-row">
          <CommandHeader />
        </div>

        {/* Metrics — high priority on mobile */}
        <div className="dashboard-layout__full-row">
          <MetricsPanel />
        </div>

        {/* Game Preview — full width, prominent on mobile with 16:9 aspect */}
        <div className="dashboard-layout__full-row dashboard-layout__game-preview">
          <GamePreview />
        </div>

        {/* Director's Inbox — Human Feedback */}
        <div className="dashboard-layout__full-row">
          <HumanFeedback />
        </div>

        {/* Director Tools: Instructions + Asset Upload */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <DirectorInstructions />
          <FileUpload />
        </div>

        {/* Specialist Rotation */}
        <div className="dashboard-layout__full-row">
          <SpecialistRotation />
        </div>

        {/* Scene Selector + Dev Cycle Summary */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <SceneSelector />
          <DevCycleSummary />
        </div>

        {/* Studio Insights */}
        <div className="dashboard-layout__full-row">
          <StudioInsights />
        </div>

        {/* Timeline */}
        <div className="dashboard-layout__full-row">
          <StateTimeline />
        </div>

        {/* Active Missions — full width before columns */}
        <div className="dashboard-layout__full-row dashboard-layout__missions-mobile">
          <ActiveMissions />
        </div>

        {/* 3-column area: stacks on mobile, splits on tablet/desktop */}
        <div className="dashboard-layout__columns">
          {/* Left column: Feature Queue + Agent Fleet */}
          <div className="dashboard-layout__col dashboard-layout__col--left">
            <div style={{ flex: '1 1 50%', overflow: 'hidden', minHeight: '200px' }}>
              <FeatureQueue />
            </div>
            <div style={{ flex: '1 1 50%', overflow: 'hidden', minHeight: '200px' }}>
              <AgentFleet />
            </div>
          </div>

          {/* Center column: Active Missions (desktop only, hidden on mobile) + Game Preview (desktop) */}
          <div className="dashboard-layout__col dashboard-layout__col--center dashboard-layout__desktop-only">
            <div style={{ flex: 1, overflow: 'hidden', minHeight: '200px' }}>
              <ActiveMissions />
            </div>
          </div>

          {/* Right column: Alert Feed */}
          <div className="dashboard-layout__col dashboard-layout__col--right">
            <div style={{ flex: 1, overflow: 'hidden', minHeight: '200px' }}>
              <AlertFeed />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
