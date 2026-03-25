// ═══════════════════════════════════════════════════════════════════════════════
// Minigame Base — Abstract class for all minigames (score 0-100)
// ═══════════════════════════════════════════════════════════════════════════════

export interface MinigameResult {
  readonly score: number;      // 0-100
  readonly timeSpent: number;  // seconds
  readonly completed: boolean;
}

export abstract class MinigameBase {
  protected container: HTMLElement;
  protected startTime = 0;
  protected resolve: ((result: MinigameResult) => void) | null = null;

  constructor(container: HTMLElement) {
    this.container = container;
  }

  /** Start the minigame and return a promise that resolves with the result. */
  play(): Promise<MinigameResult> {
    return new Promise((resolve) => {
      this.resolve = resolve;
      this.startTime = performance.now();
      this.setup();
      this.render();
    });
  }

  /** Called once to set up the minigame UI. */
  protected abstract setup(): void;

  /** Called to render/update the minigame. */
  protected abstract render(): void;

  /** Call this to end the minigame with a score. */
  protected finish(score: number): void {
    const timeSpent = (performance.now() - this.startTime) / 1000;
    this.cleanup();
    this.resolve?.({
      score: Math.max(0, Math.min(100, Math.round(score))),
      timeSpent,
      completed: true,
    });
  }

  /** Clean up the minigame UI. */
  protected cleanup(): void {
    this.container.innerHTML = '';
  }
}
