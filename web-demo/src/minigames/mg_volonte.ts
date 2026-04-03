// =============================================================================
// Minigame: Volonte -- Resist distractions, hold focus on center target
// Flashing colored squares try to lure cursor away from the pulsing center
// circle. Player holds cursor on center for 10s. Score = % time on target.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable distractor descriptor. */
interface Distractor {
  readonly x: number;
  readonly y: number;
  readonly size: number;
  readonly color: string;
  readonly spawnTime: number;
  readonly lifetime: number;
  readonly pulseSpeed: number;
}

const DISTRACTOR_COLORS = [
  '#e04040', '#40a0e0', '#e0a040', '#40e080', '#c040e0',
  '#e06080', '#80e040', '#e0e040', '#4080e0', '#e04080',
];

export class MinigameVolonte extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 380;
  private readonly centerX = 190;
  private readonly centerY = 190;

  // Game config
  private readonly totalTime = 10;
  private readonly targetRadius = 30;
  private readonly spawnInterval = 0.6;  // new distractor every 0.6s
  private readonly maxDistractors = 12;

  // Game state
  // Cursor starts at (0,0) — outside the target radius of 30px at (190,190).
  // Distance (0,0)→(190,190) ≈ 269px >> 30px, so idle player starts outside target.
  private cursorX = 0;
  private cursorY = 0;
  private timeLeft = 10;
  private elapsedTime = 0;
  private timeOnTarget = 0;
  private isOnTarget = false;  // re-evaluated each frame; init false prevents free credit
  private pulsePhase = 0;
  private distractors: Distractor[] = [];
  private nextSpawn = 0.5;
  private targetPulse = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'VOLONTE -- Garde le focus';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Maintiens ton curseur sur le cercle central malgre les distractions';
    instr.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-volonte-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-volonte-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#2e6b4f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Volonte — resistez aux distractions et maintenez votre concentration');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(12,12,18,0.95);border:2px solid rgba(100,80,160,0.4);cursor:crosshair;display:block;margin:0 auto;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-volonte-status';
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Focus: 100%';
    this.container.appendChild(statusEl);

    // Input
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    this.canvas.addEventListener('pointerdown', this.onPointerMove);

    // Reset state — cursor at (0,0) so idle player starts OUTSIDE the target (dist≈269 > radius 30).
    this.cursorX = 0;
    this.cursorY = 0;
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.timeOnTarget = 0;
    this.isOnTarget = false;
    this.pulsePhase = 0;
    this.distractors = [];
    this.nextSpawn = 0.5;
    this.targetPulse = 0;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-volonte-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-volonte-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    this.cursorX = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    this.cursorY = (e.clientY - rect.top) * (this.canvas.height / rect.height);
  };

  private spawnDistractor(): void {
    // Spawn at random position away from center
    const angle = Math.random() * Math.PI * 2;
    const dist = 80 + Math.random() * 100;
    const x = this.centerX + Math.cos(angle) * dist;
    const y = this.centerY + Math.sin(angle) * dist;
    const clampedX = Math.max(20, Math.min(this.canvasW - 20, x));
    const clampedY = Math.max(20, Math.min(this.canvasH - 20, y));

    const color = DISTRACTOR_COLORS[Math.floor(Math.random() * DISTRACTOR_COLORS.length)];
    const size = 15 + Math.random() * 25;
    const lifetime = 1.5 + Math.random() * 2;

    this.distractors = [
      ...this.distractors.filter(d => this.elapsedTime - d.spawnTime < d.lifetime),
      {
        x: clampedX,
        y: clampedY,
        size,
        color,
        spawnTime: this.elapsedTime,
        lifetime,
        pulseSpeed: 3 + Math.random() * 6,
      },
    ].slice(-this.maxDistractors);
  }

  private endGame(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove);

    const score = this.totalTime > 0
      ? (this.timeOnTarget / this.totalTime) * 100
      : 0;
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;
    this.pulsePhase += dt;
    this.targetPulse += dt;

    // Check if cursor is on target
    const dx = this.cursorX - this.centerX;
    const dy = this.cursorY - this.centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    this.isOnTarget = dist <= this.targetRadius;

    if (this.isOnTarget) {
      this.timeOnTarget += dt;
    }

    // Spawn distractors
    this.nextSpawn -= dt;
    if (this.nextSpawn <= 0) {
      this.spawnDistractor();
      // Spawn faster as time progresses
      const speedup = 1 - (this.elapsedTime / this.totalTime) * 0.5;
      this.nextSpawn = this.spawnInterval * speedup;
    }

    // Update status
    const focusPct = this.elapsedTime > 0
      ? Math.round((this.timeOnTarget / this.elapsedTime) * 100)
      : 100;
    const statusEl = document.getElementById('mg-volonte-status');
    if (statusEl) {
      statusEl.textContent = `Focus: ${focusPct}%`;
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Subtle background pattern
    ctx.strokeStyle = 'rgba(100,80,160,0.04)';
    ctx.lineWidth = 1;
    for (let r = 40; r < 240; r += 40) {
      ctx.beginPath();
      ctx.arc(this.centerX, this.centerY, r, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Draw distractors
    const activeDistractors = this.distractors.filter(
      d => this.elapsedTime - d.spawnTime < d.lifetime
    );
    for (const d of activeDistractors) {
      const age = this.elapsedTime - d.spawnTime;
      const fadeIn = Math.min(1, age / 0.2);
      const fadeOut = Math.max(0, 1 - (age - d.lifetime + 0.3) / 0.3);
      const alpha = Math.min(fadeIn, fadeOut);
      const pulse = Math.sin(age * d.pulseSpeed) * 0.5 + 0.5;
      const currentSize = d.size * (0.8 + pulse * 0.4);

      // Glow — convert hex color (#rrggbb) to rgba for alpha support
      const r = parseInt(d.color.slice(1, 3), 16);
      const g = parseInt(d.color.slice(3, 5), 16);
      const b = parseInt(d.color.slice(5, 7), 16);
      const glow = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, currentSize * 1.5);
      glow.addColorStop(0, `rgba(${r},${g},${b},${alpha * 0.3})`);
      glow.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(d.x, d.y, currentSize * 1.5, 0, Math.PI * 2);
      ctx.fill();

      // Square
      ctx.save();
      ctx.translate(d.x, d.y);
      ctx.rotate(age * 2);
      ctx.globalAlpha = alpha * (0.6 + pulse * 0.4);
      ctx.fillStyle = d.color;
      ctx.fillRect(-currentSize / 2, -currentSize / 2, currentSize, currentSize);
      ctx.globalAlpha = 1;
      ctx.restore();
    }

    // Center target circle (pulsing)
    const targetPulse = Math.sin(this.targetPulse * 2.5) * 0.15 + 0.85;
    const drawRadius = this.targetRadius * targetPulse;
    const targetColor = this.isOnTarget ? '80,180,120' : '180,120,80';

    // Target glow
    const tGlow = ctx.createRadialGradient(
      this.centerX, this.centerY, drawRadius * 0.3,
      this.centerX, this.centerY, drawRadius * 1.8
    );
    tGlow.addColorStop(0, `rgba(${targetColor},0.2)`);
    tGlow.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = tGlow;
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, drawRadius * 1.8, 0, Math.PI * 2);
    ctx.fill();

    // Target ring
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, drawRadius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${targetColor},0.12)`;
    ctx.fill();
    ctx.strokeStyle = `rgba(${targetColor},0.7)`;
    ctx.lineWidth = 2.5;
    ctx.stroke();

    // Target center dot
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, 4, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${targetColor},0.6)`;
    ctx.fill();

    // "FOCUS" label on target
    ctx.font = '10px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = `rgba(${targetColor},0.4)`;
    ctx.fillText('FOCUS', this.centerX, this.centerY + drawRadius + 14);

    // Cursor
    const cx = this.cursorX;
    const cy = this.cursorY;
    const cursorGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 12);
    cursorGrad.addColorStop(0, this.isOnTarget ? 'rgba(180,220,180,0.6)' : 'rgba(220,180,120,0.6)');
    cursorGrad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = cursorGrad;
    ctx.beginPath();
    ctx.arc(cx, cy, 12, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    ctx.arc(cx, cy, 4, 0, Math.PI * 2);
    ctx.fillStyle = this.isOnTarget ? '#b0e0b0' : '#e0c080';
    ctx.fill();
    ctx.strokeStyle = this.isOnTarget ? '#609060' : '#a08050';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Line from cursor to center (visual tether)
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(this.centerX, this.centerY);
    ctx.strokeStyle = `rgba(${targetColor},0.1)`;
    ctx.lineWidth = 1;
    ctx.stroke();

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove);
    super.cleanup();
  }
}
