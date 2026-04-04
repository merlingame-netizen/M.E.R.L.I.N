// =============================================================================
// Minigame: Sang Froid -- Hold cursor inside a shrinking safe zone
// Player must keep their cursor within a progressively shrinking circle for 10s.
// Score = percentage of time spent inside the safe zone. Canvas-based.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable drift descriptor for the safe zone center. */
interface Drift {
  readonly vx: number; // pixels per second
  readonly vy: number;
}

export class MinigameSangFroid extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;
  private ended = false;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 380;
  private readonly centerX = 190;
  private readonly centerY = 190;

  // Game config (endRadius + driftSpeed scaled by difficultyTier in setup())
  private totalTime = 10; // C103: tieredValue [10,9,8,7]s in setup()
  private readonly startRadius = 120;  // initial safe zone radius
  private endRadius = 28;              // final safe zone radius — scaled by tier
  private driftSpeed = 18;             // max drift speed px/s — scaled by tier

  // Game state
  // Cursor starts at (0,0) — outside the initial zone radius of 120px centred at (190,190).
  // Distance (0,0)→(190,190) ≈ 269px >> 120px, so an idle player immediately starts outside.
  private cursorX = 0;
  private cursorY = 0;
  private zoneX = 190;
  private zoneY = 190;
  private zoneDrift: Drift = { vx: 0, vy: 0 };
  private timeLeft = 10;
  private elapsedTime = 0;
  private timeInside = 0;
  private currentRadius = 120;
  private pulsePhase = 0;
  private isInside = false;  // re-evaluated each frame; init false prevents 1-frame free credit
  private nextDriftChange = 2;

  protected setup(): void {
    this.container.innerHTML = '';

    // C103/C110: all 3 difficulty params via tieredValue — same values as before but consistent
    // with the convention established for all 14 minigames (eliminates difficultyTier arithmetic).
    this.totalTime  = this.tieredValue([10, 9, 8, 7]    as const);
    this.endRadius  = this.tieredValue([28, 24, 20, 16]  as const);
    this.driftSpeed = this.tieredValue([18, 22, 26, 30]  as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'SANG-FROID -- Reste dans la zone';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction — C96: mention drift + keyboard controls for accessibility
    const instr = document.createElement('div');
    instr.textContent = 'Garde ton curseur dans le cercle qui rétrécit et dérive. Flèches = déplacer.';
    instr.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Timer bar — responsive
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-sf-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-sf-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#2e6b4f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Zone de sang-froid — gardez votre curseur dans le cercle qui rétrécit');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,20,15,0.9);border:2px solid rgba(46,107,79,0.4);cursor:crosshair;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-sf-status';
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Concentration: 100%';
    this.container.appendChild(statusEl);

    // Input
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    this.canvas.addEventListener('pointerdown', this.onPointerMove);
    // C96: keyboard cursor — arrow keys move virtual cursor 10px per press (full keyboard accessibility)
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state — pointer cursor starts at (0,0) so idle player starts OUTSIDE the zone
    // (dist (0,0)→(190,190) ≈ 269px >> radius 120px — no free time credit).
    // Keyboard-only players get auto-centered on first ArrowKey press (see onKeyDown).
    this.cursorX = 0;
    this.cursorY = 0;
    this.zoneX = this.centerX;
    this.zoneY = this.centerY;
    this.zoneDrift = { vx: this.randomDrift(), vy: this.randomDrift() };
    this.timeLeft = this.totalTime;
    this.ended = false;
    this.elapsedTime = 0;
    this.timeInside = 0;
    this.currentRadius = this.startRadius;
    this.pulsePhase = 0;
    this.isInside = false;
    this.nextDriftChange = 2;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      this.checkCriticalAlert(this.timeLeft); // C101: fire critical_alert SFX once at 3s
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-sf-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-sf-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private randomDrift(): number {
    return (Math.random() - 0.5) * 2 * this.driftSpeed;
  }

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    this.cursorX = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    this.cursorY = (e.clientY - rect.top) * (this.canvas.height / rect.height);
  };

  // C96: arrow key cursor movement — full keyboard accessibility without pointer device
  // C98: on first arrow key interaction, cursor jumps from (0,0) to canvas center so
  // keyboard-only players don't need 26+ presses just to enter the starting zone.
  // Pointer users always have cursorX/Y updated by pointermove before any keydown fires.
  private onKeyDown = (e: KeyboardEvent): void => {
    const isArrow = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    if (!isArrow) return;
    e.preventDefault();
    // Teleport to center on first keyboard interaction (pointer cursor stays at dist≈269 from start)
    if (this.cursorX === 0 && this.cursorY === 0) {
      this.cursorX = this.centerX;
      this.cursorY = this.centerY;
    }
    const step = 10;
    if (e.key === 'ArrowLeft')       this.cursorX = Math.max(0, this.cursorX - step);
    else if (e.key === 'ArrowRight') this.cursorX = Math.min(this.canvasW, this.cursorX + step);
    else if (e.key === 'ArrowUp')    this.cursorY = Math.max(0, this.cursorY - step);
    else if (e.key === 'ArrowDown')  this.cursorY = Math.min(this.canvasH, this.cursorY + step);
  };

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);

    const finalScore = this.totalTime > 0
      ? (this.timeInside / this.totalTime) * 100
      : 0;
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Shrink zone linearly
    const progress = Math.min(this.elapsedTime / this.totalTime, 1);
    this.currentRadius = this.startRadius + (this.endRadius - this.startRadius) * progress;

    // Drift the safe zone center
    this.zoneX += this.zoneDrift.vx * dt;
    this.zoneY += this.zoneDrift.vy * dt;

    // Bounce zone off canvas edges (keep zone fully visible)
    const margin = this.currentRadius + 10;
    if (this.zoneX < margin || this.zoneX > this.canvasW - margin) {
      this.zoneDrift = { ...this.zoneDrift, vx: -this.zoneDrift.vx };
      this.zoneX = Math.max(margin, Math.min(this.canvasW - margin, this.zoneX));
    }
    if (this.zoneY < margin || this.zoneY > this.canvasH - margin) {
      this.zoneDrift = { ...this.zoneDrift, vy: -this.zoneDrift.vy };
      this.zoneY = Math.max(margin, Math.min(this.canvasH - margin, this.zoneY));
    }

    // Change drift direction periodically
    this.nextDriftChange -= dt;
    if (this.nextDriftChange <= 0) {
      this.zoneDrift = { vx: this.randomDrift(), vy: this.randomDrift() };
      this.nextDriftChange = 1.5 + Math.random() * 2;
    }

    // Check if cursor is inside zone
    const dx = this.cursorX - this.zoneX;
    const dy = this.cursorY - this.zoneY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const wasInside = this.isInside;
    this.isInside = dist <= this.currentRadius;

    // C97: audio feedback on zone enter/exit transitions (not every frame)
    if (this.isInside && !wasInside) {
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else if (!this.isInside && wasInside) {
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }

    if (this.isInside) {
      this.timeInside += dt;
    }

    // Update status
    const pctInside = this.elapsedTime > 0
      ? Math.round((this.timeInside / this.elapsedTime) * 100)
      : 100;
    const statusEl = document.getElementById('mg-sf-status');
    if (statusEl) {
      statusEl.textContent = `Concentration: ${pctInside}% | Zone: ${Math.round(this.currentRadius)}px`;
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background grid (subtle)
    ctx.strokeStyle = 'rgba(46,107,79,0.08)';
    ctx.lineWidth = 1;
    for (let x = 0; x < this.canvasW; x += 30) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, this.canvasH);
      ctx.stroke();
    }
    for (let y = 0; y < this.canvasH; y += 30) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(this.canvasW, y);
      ctx.stroke();
    }

    // Safe zone
    const zonePulse = 0.3 + Math.sin(this.pulsePhase * 2) * 0.1;
    const zoneColor = this.isInside ? '46,107,79' : '180,80,40';

    // Zone glow
    const glow = ctx.createRadialGradient(
      this.zoneX, this.zoneY, this.currentRadius * 0.5,
      this.zoneX, this.zoneY, this.currentRadius * 1.3
    );
    glow.addColorStop(0, `rgba(${zoneColor},${zonePulse * 0.3})`);
    glow.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(this.zoneX, this.zoneY, this.currentRadius * 1.3, 0, Math.PI * 2);
    ctx.fill();

    // Zone circle
    ctx.beginPath();
    ctx.arc(this.zoneX, this.zoneY, this.currentRadius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${zoneColor},${zonePulse * 0.15})`;
    ctx.fill();
    // C96: pivot telegraph — border flashes white in the 0.3s before a drift direction change
    const pivotWarning = this.nextDriftChange < 0.3 && this.nextDriftChange > 0;
    ctx.strokeStyle = pivotWarning
      ? `rgba(255,220,120,${0.6 + Math.sin(this.pulsePhase * 20) * 0.4})`
      : `rgba(${zoneColor},${zonePulse + 0.3})`;
    ctx.lineWidth = pivotWarning ? 3 : 2;
    ctx.stroke();

    // Zone center mark
    ctx.beginPath();
    ctx.arc(this.zoneX, this.zoneY, 3, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${zoneColor},0.5)`;
    ctx.fill();

    // Shrink indicator rings (concentric fading rings)
    for (let r = 1; r <= 3; r++) {
      const ringR = this.currentRadius + r * 15;
      if (ringR > this.startRadius + 20) break;
      ctx.beginPath();
      ctx.arc(this.zoneX, this.zoneY, ringR, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(${zoneColor},${0.05 / r})`;
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    // Cursor
    const cx = this.cursorX;
    const cy = this.cursorY;

    // Cursor glow
    const cursorGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 14);
    cursorGrad.addColorStop(0, this.isInside ? 'rgba(200,220,180,0.5)' : 'rgba(200,100,60,0.5)');
    cursorGrad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = cursorGrad;
    ctx.beginPath();
    ctx.arc(cx, cy, 14, 0, Math.PI * 2);
    ctx.fill();

    // Cursor dot
    ctx.beginPath();
    ctx.arc(cx, cy, 5, 0, Math.PI * 2);
    ctx.fillStyle = this.isInside ? '#c8e0b0' : '#c86030';
    ctx.fill();
    ctx.strokeStyle = this.isInside ? '#6a9a50' : '#a04020';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Line from cursor to zone center (visual guide)
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(this.zoneX, this.zoneY);
    ctx.strokeStyle = `rgba(${zoneColor},0.15)`;
    ctx.lineWidth = 1;
    ctx.stroke();

    // HUD: score % in canvas top-left — immediate readable feedback
    const pct = this.elapsedTime > 0 ? Math.round((this.timeInside / this.elapsedTime) * 100) : 100;
    ctx.font = 'bold 16px system-ui';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillStyle = this.isInside ? 'rgba(140,200,120,0.85)' : 'rgba(200,90,50,0.85)';
    ctx.fillText(`${pct}%`, 10, 10);
    // C106: debug radius display removed (was player-visible in production)

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
    super.cleanup();
  }
}
