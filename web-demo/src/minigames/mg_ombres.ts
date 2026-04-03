// =============================================================================
// Minigame: Ombres -- Stealth corridor navigation
// Player cursor must move through a twisting corridor without touching shadow
// walls. Corridor narrows over 10s. Score = % distance covered without collision.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable corridor segment. */
interface Segment {
  readonly centerY: number;
  readonly halfWidth: number;
}

export class MinigameOmbres extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;

  // Canvas dimensions
  private readonly canvasW = 420;
  private readonly canvasH = 380;

  // Game config
  private readonly totalTime = 10;
  private readonly segmentCount = 40;
  private readonly startHalfWidth = 55;
  private readonly endHalfWidth = 18;

  // Game state
  private segments: Segment[] = [];
  private cursorX = 0;
  private cursorY = 190;
  private progress = 0;       // 0 to 1 (how far along corridor)
  private timeLeft = 10;
  private elapsedTime = 0;
  private colliding = false;
  private collisionTime = 0;  // cumulative collision time
  private maxProgress = 0;
  private pulsePhase = 0;
  private scrollOffset = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'OMBRES -- Traverse le corridor';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Guide ton curseur sans toucher les murs d\'ombre';
    instr.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.style.cssText = `width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-ombres-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#2e6b4f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', '');
    this.canvas.setAttribute('role', 'application');
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(10,10,20,0.95);border:2px solid rgba(80,60,120,0.4);cursor:none;display:block;margin:0 auto;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-ombres-status';
    statusEl.style.cssText = `width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Progression: 0%';
    this.container.appendChild(statusEl);

    // Generate corridor
    this.generateCorridor();

    // Input
    this.canvas.addEventListener('pointermove', this.onPointerMove);

    // Reset state
    this.cursorX = 30;
    this.cursorY = this.canvasH / 2;
    this.progress = 0;
    this.maxProgress = 0;
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.colliding = false;
    this.collisionTime = 0;
    this.pulsePhase = 0;
    this.scrollOffset = 0;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-ombres-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private generateCorridor(): void {
    const segs: Segment[] = [];
    let cy = this.canvasH / 2;
    for (let i = 0; i < this.segmentCount; i++) {
      const t = i / (this.segmentCount - 1);
      const hw = this.startHalfWidth + (this.endHalfWidth - this.startHalfWidth) * t;
      // Sinusoidal winding with increasing frequency
      const wave = Math.sin(t * Math.PI * 3.5) * 60 * t;
      const secondWave = Math.sin(t * Math.PI * 7) * 20 * t * t;
      cy = this.canvasH / 2 + wave + secondWave;
      // Clamp to keep corridor visible
      cy = Math.max(hw + 10, Math.min(this.canvasH - hw - 10, cy));
      segs.push({ centerY: cy, halfWidth: hw });
    }
    this.segments = segs;
  }

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    this.cursorX = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    this.cursorY = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Progress is tied to horizontal cursor position
    this.progress = Math.max(0, Math.min(1, this.cursorX / this.canvasW));
    if (this.progress > this.maxProgress) {
      this.maxProgress = this.progress;
    }
  };

  private getSegmentAt(t: number): Segment {
    const idx = Math.min(this.segmentCount - 1, Math.max(0, Math.floor(t * (this.segmentCount - 1))));
    return this.segments[idx];
  }

  private endGame(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);

    // Score = max progress reached * (1 - collision penalty)
    const collisionPenalty = Math.min(1, this.collisionTime / this.totalTime);
    const rawScore = this.maxProgress * 100 * (1 - collisionPenalty * 0.5);
    this.finish(rawScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = 1 / 60;
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Check collision
    const seg = this.getSegmentAt(this.progress);
    const distFromCenter = Math.abs(this.cursorY - seg.centerY);
    this.colliding = distFromCenter > seg.halfWidth;
    if (this.colliding) {
      this.collisionTime += dt;
    }

    // Update status
    const statusEl = document.getElementById('mg-ombres-status');
    if (statusEl) {
      const pctProg = Math.round(this.maxProgress * 100);
      statusEl.textContent = this.colliding
        ? `COLLISION ! Progression: ${pctProg}%`
        : `Progression: ${pctProg}%`;
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Draw shadow walls (the corridor is the safe path)
    // Top wall
    ctx.fillStyle = 'rgba(30,20,50,0.85)';
    ctx.beginPath();
    ctx.moveTo(0, 0);
    for (let i = 0; i < this.segmentCount; i++) {
      const x = (i / (this.segmentCount - 1)) * this.canvasW;
      const s = this.segments[i];
      ctx.lineTo(x, s.centerY - s.halfWidth);
    }
    ctx.lineTo(this.canvasW, 0);
    ctx.closePath();
    ctx.fill();

    // Bottom wall
    ctx.beginPath();
    ctx.moveTo(0, this.canvasH);
    for (let i = 0; i < this.segmentCount; i++) {
      const x = (i / (this.segmentCount - 1)) * this.canvasW;
      const s = this.segments[i];
      ctx.lineTo(x, s.centerY + s.halfWidth);
    }
    ctx.lineTo(this.canvasW, this.canvasH);
    ctx.closePath();
    ctx.fill();

    // Corridor edges glow
    ctx.strokeStyle = 'rgba(120,80,180,0.4)';
    ctx.lineWidth = 2;
    // Top edge
    ctx.beginPath();
    for (let i = 0; i < this.segmentCount; i++) {
      const x = (i / (this.segmentCount - 1)) * this.canvasW;
      const s = this.segments[i];
      if (i === 0) ctx.moveTo(x, s.centerY - s.halfWidth);
      else ctx.lineTo(x, s.centerY - s.halfWidth);
    }
    ctx.stroke();
    // Bottom edge
    ctx.beginPath();
    for (let i = 0; i < this.segmentCount; i++) {
      const x = (i / (this.segmentCount - 1)) * this.canvasW;
      const s = this.segments[i];
      if (i === 0) ctx.moveTo(x, s.centerY + s.halfWidth);
      else ctx.lineTo(x, s.centerY + s.halfWidth);
    }
    ctx.stroke();

    // Center line (faint guide)
    ctx.strokeStyle = 'rgba(120,80,180,0.08)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 8]);
    ctx.beginPath();
    for (let i = 0; i < this.segmentCount; i++) {
      const x = (i / (this.segmentCount - 1)) * this.canvasW;
      const s = this.segments[i];
      if (i === 0) ctx.moveTo(x, s.centerY);
      else ctx.lineTo(x, s.centerY);
    }
    ctx.stroke();
    ctx.setLineDash([]);

    // Progress marker (vertical line at max progress)
    if (this.maxProgress > 0.02) {
      const mpx = this.maxProgress * this.canvasW;
      ctx.strokeStyle = 'rgba(80,200,120,0.3)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(mpx, 0);
      ctx.lineTo(mpx, this.canvasH);
      ctx.stroke();
    }

    // Cursor
    const cx = this.cursorX;
    const cy = this.cursorY;

    // Cursor glow
    const cursorGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 16);
    if (this.colliding) {
      const flash = Math.sin(this.pulsePhase * 10) * 0.3 + 0.5;
      cursorGrad.addColorStop(0, `rgba(200,60,60,${flash})`);
    } else {
      cursorGrad.addColorStop(0, 'rgba(180,160,220,0.6)');
    }
    cursorGrad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = cursorGrad;
    ctx.beginPath();
    ctx.arc(cx, cy, 16, 0, Math.PI * 2);
    ctx.fill();

    // Cursor dot
    ctx.beginPath();
    ctx.arc(cx, cy, 4, 0, Math.PI * 2);
    ctx.fillStyle = this.colliding ? '#e04040' : '#c0b0e0';
    ctx.fill();
    ctx.strokeStyle = this.colliding ? '#a02020' : '#8070b0';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Collision flash on whole canvas
    if (this.colliding) {
      const flash = Math.sin(this.pulsePhase * 8) * 0.5 + 0.5;
      ctx.fillStyle = `rgba(160,30,30,${flash * 0.06})`;
      ctx.fillRect(0, 0, this.canvasW, this.canvasH);
    }

    // End zone indicator
    ctx.fillStyle = 'rgba(80,200,120,0.15)';
    ctx.fillRect(this.canvasW - 15, 0, 15, this.canvasH);

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    super.cleanup();
  }
}
