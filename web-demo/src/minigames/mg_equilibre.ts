// =============================================================================
// Minigame: Equilibre -- Balance on an unstable path
// The player must keep a balance cursor centered by pressing left/right arrows
// (or tapping left/right sides of the canvas). Wind gusts push the cursor off
// balance. Score based on time spent in the safe zone.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable wind gust descriptor. */
interface WindGust {
  readonly startTime: number;
  readonly duration: number;
  readonly force: number; // negative = left, positive = right
}

export class MinigameEquilibre extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;
  private ended = false;

  // Game state
  private cursorX = 0; // -1 (left edge) to +1 (right edge), 0 = center
  private velocity = 0;
  private timeLeft = 12;
  private totalTime = 12;        // C101: mutable for tieredValue() scaling in setup()
  private timeInZone = 0; // seconds spent inside safe zone
  private safeZoneHalf = 0.25; // C100: [0.25,0.20,0.15,0.10] — narrower at high tier
  private wasInZone = false;   // C100: SFX edge-trigger

  // Wind system
  private gusts: WindGust[] = [];
  private nextGustTime = 2;
  private elapsedTime = 0;

  // Input
  private keysDown: Set<string> = new Set();
  private touchSide: 'left' | 'right' | null = null;

  // Visual
  private readonly canvasW = 400;
  private readonly canvasH = 200;
  private readonly pathY = 140;
  private readonly cursorRadius = 12;
  private windArrowAlpha = 0;
  private windArrowDir = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // C100/C101: difficulty scaling
    this.totalTime    = this.tieredValue([12, 10, 8, 7] as const);
    this.safeZoneHalf = this.tieredValue([0.25, 0.20, 0.15, 0.10] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'EQUILIBRE -- Reste au centre du chemin';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:16px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instructions
    const instr = document.createElement('div');
    instr.textContent = 'Fleches gauche/droite ou touche le canvas';
    instr.style.cssText = 'color:rgba(205,133,63,0.6);font-size:13px;text-align:center;margin-bottom:12px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-eq-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = 'width:min(400px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 12px;overflow:hidden;';
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-eq-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#cd853f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Equilibre — maintenez votre equilibre sur le chemin etroit');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(20,20,30,0.8);border:1px solid rgba(205,133,63,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Reset state
    this.cursorX = 0;
    this.velocity = 0;
    this.timeLeft = this.totalTime;
    this.timeInZone = 0;
    this.gusts = [];
    this.nextGustTime = 1.5 + Math.random();
    this.elapsedTime = 0;
    this.keysDown = new Set();
    this.ended = false;
    this.wasInZone = false;
    this.touchSide = null;

    // Input handlers
    document.addEventListener('keydown', this.onKeyDown);
    document.addEventListener('keyup', this.onKeyUp);
    this.canvas.addEventListener('pointerdown', this.onPointerDown);
    this.canvas.addEventListener('pointerup', this.onPointerUp);
    this.canvas.addEventListener('pointerleave', this.onPointerUp);

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      this.checkCriticalAlert(this.timeLeft); // C101: fire critical_alert SFX once at 3s
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-eq-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-eq-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private onKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      e.preventDefault();
      this.keysDown.add(e.key);
    }
  };

  private onKeyUp = (e: KeyboardEvent): void => {
    this.keysDown.delete(e.key);
  };

  private onPointerDown = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    this.touchSide = x < rect.width / 2 ? 'left' : 'right';
  };

  private onPointerUp = (): void => {
    this.touchSide = null;
  };

  private spawnGust(): void {
    const direction = Math.random() < 0.5 ? -1 : 1;
    const intensity = 0.3 + Math.random() * 0.5;
    // Gusts get stronger over time
    const timeFactor = 1 + (this.elapsedTime / this.totalTime) * 0.8;
    this.gusts.push({
      startTime: this.elapsedTime,
      duration: 0.8 + Math.random() * 1.2,
      force: direction * intensity * timeFactor,
    });
    this.windArrowAlpha = 1;
    this.windArrowDir = direction;
    // Next gust comes sooner as time progresses
    const baseInterval = 2.5 - (this.elapsedTime / this.totalTime) * 1.5;
    this.nextGustTime = this.elapsedTime + Math.max(0.8, baseInterval + Math.random() * 0.5);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    document.removeEventListener('keydown', this.onKeyDown);
    document.removeEventListener('keyup', this.onKeyUp);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas?.removeEventListener('pointerup', this.onPointerUp);
    this.canvas?.removeEventListener('pointerleave', this.onPointerUp);

    // Score: percentage of time spent in safe zone
    const totalElapsed = Math.min(this.totalTime, this.totalTime - this.timeLeft + 0.001);
    const zoneRatio = this.timeInZone / totalElapsed;
    const score = zoneRatio * 100;
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = this.getDeltaTime(); // approximate frame time
    this.elapsedTime += dt;

    // --- Physics ---
    const friction = 0.92;
    const inputForce = 0.06;
    const gustMultiplier = 0.04;

    // Player input
    if (this.keysDown.has('ArrowLeft') || this.touchSide === 'left') {
      this.velocity -= inputForce;
    }
    if (this.keysDown.has('ArrowRight') || this.touchSide === 'right') {
      this.velocity += inputForce;
    }

    // Wind gusts
    const activeGusts = this.gusts.filter(
      (g) => this.elapsedTime >= g.startTime && this.elapsedTime < g.startTime + g.duration
    );
    for (const gust of activeGusts) {
      this.velocity += gust.force * gustMultiplier;
    }

    // Spawn new gusts
    if (this.elapsedTime >= this.nextGustTime) {
      this.spawnGust();
    }

    // Apply physics
    this.velocity *= friction;
    this.cursorX += this.velocity;

    // Clamp to edges
    if (this.cursorX < -1) { this.cursorX = -1; this.velocity = 0; }
    if (this.cursorX > 1) { this.cursorX = 1; this.velocity = 0; }

    // Track time in safe zone — C100: edge-triggered SFX on zone enter/leave
    const nowInZone = Math.abs(this.cursorX) <= this.safeZoneHalf;
    if (nowInZone && !this.wasInZone) window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    if (!nowInZone && this.wasInZone) window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    this.wasInZone = nowInZone;
    if (nowInZone) {
      this.timeInZone += dt;
    }

    // Fade wind arrow
    this.windArrowAlpha = Math.max(0, this.windArrowAlpha - dt * 1.5);

    // --- Drawing ---
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background gradient (canyon feel)
    const bgGrad = ctx.createLinearGradient(0, 0, 0, this.canvasH);
    bgGrad.addColorStop(0, 'rgba(30,25,40,0.9)');
    bgGrad.addColorStop(1, 'rgba(20,15,25,0.95)');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, this.canvasW, this.canvasH);

    const centerX = this.canvasW / 2;
    const pathWidth = this.canvasW * 0.85;
    const safePixels = pathWidth * this.safeZoneHalf;

    // Draw path (full width)
    ctx.fillStyle = 'rgba(80,70,55,0.5)';
    ctx.fillRect(centerX - pathWidth / 2, this.pathY - 4, pathWidth, 8);

    // Draw safe zone (highlighted)
    const isInZone = Math.abs(this.cursorX) <= this.safeZoneHalf;
    ctx.fillStyle = isInZone ? 'rgba(46,107,46,0.6)' : 'rgba(139,115,85,0.4)';
    ctx.fillRect(centerX - safePixels, this.pathY - 6, safePixels * 2, 12);

    // Safe zone border marks
    ctx.strokeStyle = 'rgba(205,133,63,0.5)';
    ctx.lineWidth = 2;
    for (const side of [-1, 1]) {
      const x = centerX + side * safePixels;
      ctx.beginPath();
      ctx.moveTo(x, this.pathY - 15);
      ctx.lineTo(x, this.pathY + 15);
      ctx.stroke();
    }

    // Draw cursor
    const cursorPixelX = centerX + (this.cursorX * pathWidth) / 2;
    const cursorGlow = isInZone ? 'rgba(100,200,100,0.3)' : 'rgba(200,100,100,0.3)';

    // Glow
    ctx.beginPath();
    ctx.arc(cursorPixelX, this.pathY, this.cursorRadius + 6, 0, Math.PI * 2);
    ctx.fillStyle = cursorGlow;
    ctx.fill();

    // Cursor body
    ctx.beginPath();
    ctx.arc(cursorPixelX, this.pathY, this.cursorRadius, 0, Math.PI * 2);
    ctx.fillStyle = isInZone ? '#5a9a5a' : '#cd5c5c';
    ctx.fill();
    ctx.strokeStyle = isInZone ? '#8fbc8f' : '#e8a0a0';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Center dot
    ctx.beginPath();
    ctx.arc(cursorPixelX, this.pathY, 3, 0, Math.PI * 2);
    ctx.fillStyle = '#e8dcc8';
    ctx.fill();

    // Wind indicator arrow
    if (this.windArrowAlpha > 0.01) {
      ctx.save();
      ctx.globalAlpha = this.windArrowAlpha;
      ctx.fillStyle = '#cd853f';
      ctx.font = 'bold 28px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const arrowChar = this.windArrowDir < 0 ? '\u2190' : '\u2192';
      ctx.fillText(arrowChar, centerX, 40);
      ctx.font = '14px system-ui';
      ctx.fillText('Vent !', centerX, 65);
      ctx.restore();
    }

    // Score display (real-time feedback)
    const currentScore = this.elapsedTime > 0
      ? Math.round((this.timeInZone / this.elapsedTime) * 100)
      : 100;
    ctx.fillStyle = 'rgba(232,220,200,0.7)';
    ctx.font = '14px system-ui';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'top';
    ctx.fillText(`Equilibre: ${currentScore}%`, this.canvasW - 12, 12);

    // Falling particles (atmospheric)
    const particleCount = 5;
    for (let i = 0; i < particleCount; i++) {
      const px = ((this.elapsedTime * 30 + i * 80) % this.canvasW);
      const py = ((this.elapsedTime * 15 + i * 40) % (this.pathY - 20));
      ctx.beginPath();
      ctx.arc(px, py, 1.5, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(205,133,63,${0.1 + Math.sin(this.elapsedTime + i) * 0.1})`;
      ctx.fill();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    document.removeEventListener('keydown', this.onKeyDown);
    document.removeEventListener('keyup', this.onKeyUp);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas?.removeEventListener('pointerup', this.onPointerUp);
    this.canvas?.removeEventListener('pointerleave', this.onPointerUp);
    super.cleanup();
  }
}
