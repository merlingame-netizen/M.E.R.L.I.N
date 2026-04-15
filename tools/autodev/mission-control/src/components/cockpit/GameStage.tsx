import { useResizable } from '../../hooks/useResizable';
import { GamePreview } from '../GamePreview';

export function GameStage() {
  const { size, isDragging, startDrag } = useResizable({
    storageKey: 'merlin.cockpit.gameStageWidth',
    initial: 65,
    min: 40,
    max: 80,
    axis: 'x',
  });

  return (
    <div
      className="game-stage"
      style={{ width: `${size}%` }}
      data-dragging={isDragging || undefined}
    >
      <div className="game-stage__inner">
        <GamePreview />
      </div>
      <div
        className="game-stage__handle"
        role="separator"
        aria-orientation="vertical"
        aria-label="Resize game preview"
        onPointerDown={startDrag}
      >
        <span className="game-stage__handle-grip" aria-hidden="true" />
      </div>
    </div>
  );
}
