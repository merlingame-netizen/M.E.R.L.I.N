import { useStateSync } from './hooks/useStateSync';
import { TopBar } from './components/cockpit/TopBar';
import { GameStage } from './components/cockpit/GameStage';
import { Timeline } from './components/cockpit/Timeline';
import { Drawer } from './components/cockpit/Drawer';
import { ToastViewport } from './components/Toast';
import './styles/modern-theme.css';
import './styles/cockpit.css';

export function App() {
  useStateSync();

  return (
    <div className="cockpit">
      <TopBar />
      <main className="cockpit__main">
        <GameStage />
        <Timeline />
      </main>
      <Drawer />
      <ToastViewport />
    </div>
  );
}
