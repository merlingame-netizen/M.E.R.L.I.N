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
import { VelocityChart } from './components/VelocityChart';
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

        {/* Metrics — high-level status at a glance */}
        <div className="dashboard-layout__full-row">
          <MetricsPanel />
        </div>

        {/* Pipeline state — where are we in the dev cycle? */}
        <div className="dashboard-layout__full-row">
          <StateTimeline />
        </div>

        {/* === STATUS ZONE: What's planned / active / done === */}

        {/* Task Board (Kanban) — THE answer to "what's happening" */}
        <div className="dashboard-layout__full-row">
          <FeatureQueue />
        </div>

        {/* Velocity + Dev Cycle — recent throughput */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <VelocityChart />
          <DevCycleSummary />
        </div>

        {/* Recent commits — what was shipped */}
        <div className="dashboard-layout__full-row">
          <ActiveMissions />
        </div>

        {/* === DIRECTOR ZONE: Your inbox + controls === */}

        {/* Director's Inbox — Human Feedback */}
        <div className="dashboard-layout__full-row">
          <HumanFeedback />
        </div>

        {/* Director Tools: Instructions + Asset Upload */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <DirectorInstructions />
          <FileUpload />
        </div>

        {/* === SYSTEM ZONE: Specialists, agents, logs === */}

        {/* Specialist Rotation */}
        <div className="dashboard-layout__full-row">
          <SpecialistRotation />
        </div>

        {/* Game Preview — full width, 16:9 aspect */}
        <div className="dashboard-layout__full-row dashboard-layout__game-preview">
          <GamePreview />
        </div>

        {/* Scene Selector */}
        <div className="dashboard-layout__full-row">
          <SceneSelector />
        </div>

        {/* Studio Insights */}
        <div className="dashboard-layout__full-row">
          <StudioInsights />
        </div>

        {/* 3-column area: stacks on mobile, splits on tablet/desktop */}
        <div className="dashboard-layout__columns">
          {/* Left column: Agent Fleet */}
          <div className="dashboard-layout__col dashboard-layout__col--left">
            <div style={{ flex: 1, overflow: 'hidden', minHeight: '200px' }}>
              <AgentFleet />
            </div>
          </div>

          {/* Center column: System Log */}
          <div className="dashboard-layout__col dashboard-layout__col--center">
            <div style={{ flex: 1, overflow: 'hidden', minHeight: '200px' }}>
              <AlertFeed />
            </div>
          </div>

          {/* Right column: empty for balance — or future panel */}
          <div className="dashboard-layout__col dashboard-layout__col--right" />
        </div>
      </div>
    </div>
  );
}
