import { useStateSync } from './hooks/useStateSync';
import { CommandHeader } from './components/CommandHeader';
import { AgentFleet } from './components/AgentFleet';
import { StateTimeline } from './components/StateTimeline';
import { ActiveMissions } from './components/ActiveMissions';
import { AlertFeed } from './components/AlertFeed';
import { MetricsPanel } from './components/MetricsPanel';
import { FeatureQueue } from './components/FeatureQueue';
import { CompletedTasks } from './components/CompletedTasks';
import { ExecutionTimeline } from './components/ExecutionTimeline';
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
        {/* 1. Header */}
        <div className="dashboard-layout__full-row">
          <CommandHeader />
        </div>

        {/* 2. Metrics — KPIs at a glance + next cycle countdown */}
        <div className="dashboard-layout__full-row">
          <MetricsPanel />
        </div>

        {/* 3. Pipeline state — where are we in the dev cycle? */}
        <div className="dashboard-layout__full-row">
          <StateTimeline />
        </div>

        {/* 4. Execution Schedule — WHEN each task will be processed */}
        <div className="dashboard-layout__full-row">
          <ExecutionTimeline />
        </div>

        {/* 5. Task Board (Kanban) — admin CRUD on tasks */}
        <div className="dashboard-layout__full-row">
          <FeatureQueue />
        </div>

        {/* 6. Completed Tasks — detailed history */}
        <div className="dashboard-layout__full-row">
          <CompletedTasks />
        </div>

        {/* 7. Velocity + Dev Cycle — throughput metrics */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <VelocityChart />
          <DevCycleSummary />
        </div>

        {/* 8. Director's Inbox — Human Feedback */}
        <div className="dashboard-layout__full-row">
          <HumanFeedback />
        </div>

        {/* 9. Director Tools: Queue Task + Asset Upload */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <DirectorInstructions />
          <FileUpload />
        </div>

        {/* 10. Specialist Rotation */}
        <div className="dashboard-layout__full-row">
          <SpecialistRotation />
        </div>

        {/* 11. Recent git commits */}
        <div className="dashboard-layout__full-row">
          <ActiveMissions />
        </div>

        {/* 12. Game Preview */}
        <div className="dashboard-layout__full-row dashboard-layout__game-preview">
          <GamePreview />
        </div>

        {/* 13. Scene Selector */}
        <div className="dashboard-layout__full-row">
          <SceneSelector />
        </div>

        {/* 14. Studio Insights */}
        <div className="dashboard-layout__full-row">
          <StudioInsights />
        </div>

        {/* 15. System details: Agents + Logs */}
        <div className="dashboard-layout__full-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
          <AgentFleet />
          <AlertFeed />
        </div>
      </div>
    </div>
  );
}
