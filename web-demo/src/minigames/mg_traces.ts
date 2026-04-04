// ═══════════════════════════════════════════════════════════════════════════════
// Minigame: Traces — Follow a sequence of footprints along a path
// Click/tap each footprint in order before time runs out
// ═══════════════════════════════════════════════════════════════════════════════

import { MinigameBase } from './MinigameBase';

interface Footprint {
  x: number;
  y: number;
  index: number;
  hit: boolean;
}

export class MinigameTraces extends MinigameBase {
  private footprints: Footprint[] = [];
  private currentIndex = 0;
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private timerInterval = 0;
  private timeLeft = 8; // seconds
  private readonly totalTime = 8;
  private readonly footprintCount = 7;
  private animFrame = 0;
  private ended = false;

  protected setup(): void {
    this.container.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'TRACES — Suis les empreintes dans l\'ordre';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:16px;font-family:system-ui;';
    this.container.appendChild(title);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = 'width:min(400px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 16px;overflow:hidden;';
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#cd853f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Traces — suivez le chemin trace avec precision');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = 400;
    this.canvas.height = 400;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(20,30,20,0.8);border:1px solid rgba(205,133,63,0.3);cursor:pointer;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Generate footprint positions along a winding path
    this.footprints = [];
    this.currentIndex = 0;
    this.ended = false;
    for (let i = 0; i < this.footprintCount; i++) {
      const t = (i + 1) / (this.footprintCount + 1);
      const x = 50 + 300 * t + Math.sin(t * Math.PI * 2) * 40;
      const y = 350 - 300 * t + Math.cos(t * Math.PI * 3) * 30;
      this.footprints.push({ x, y, index: i, hit: false });
    }

    // pointerdown covers mouse, touch and stylus — no 'click' needed (avoids double-fire on desktop)
    this.canvas.addEventListener('pointerdown', this.onClick);

    // Timer
    this.timeLeft = this.totalTime;
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private onClick = (e: MouseEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    const target = this.footprints[this.currentIndex];
    if (!target) return;

    const dist = Math.sqrt((mx - target.x) ** 2 + (my - target.y) ** 2);
    if (dist < 30) {
      target.hit = true;
      this.currentIndex++;
      if (this.currentIndex >= this.footprintCount) {
        this.endGame();
      }
    }
  };

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);

    const hitCount = this.footprints.filter((f) => f.hit).length;
    const timeBonus = Math.max(0, this.timeLeft / this.totalTime) * 20;
    const score = (hitCount / this.footprintCount) * 80 + timeBonus;
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    // Draw path (dotted line between footprints)
    ctx.strokeStyle = 'rgba(205,133,63,0.15)';
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 8]);
    ctx.beginPath();
    for (let i = 0; i < this.footprints.length; i++) {
      const fp = this.footprints[i];
      if (i === 0) ctx.moveTo(fp.x, fp.y);
      else ctx.lineTo(fp.x, fp.y);
    }
    ctx.stroke();
    ctx.setLineDash([]);

    // Draw footprints
    for (const fp of this.footprints) {
      ctx.save();
      ctx.translate(fp.x, fp.y);

      if (fp.hit) {
        // Hit — green glow
        ctx.fillStyle = 'rgba(100,200,100,0.6)';
        ctx.beginPath();
        ctx.arc(0, 0, 16, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#8fbc8f';
      } else if (fp.index === this.currentIndex) {
        // Current target — pulsing gold
        const pulse = 1 + Math.sin(performance.now() / 200) * 0.15;
        ctx.fillStyle = 'rgba(205,133,63,0.4)';
        ctx.beginPath();
        ctx.arc(0, 0, 22 * pulse, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#cd853f';
      } else {
        // Future — dim
        ctx.fillStyle = 'rgba(200,200,200,0.2)';
      }

      // Footprint shape (simple oval)
      ctx.beginPath();
      ctx.ellipse(0, 0, 8, 12, 0, 0, Math.PI * 2);
      ctx.fill();

      // Index number
      ctx.fillStyle = fp.hit ? '#2d5a2d' : 'rgba(255,255,255,0.5)';
      ctx.font = '10px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`${fp.index + 1}`, 0, 0);

      ctx.restore();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    super.cleanup();
  }
}
