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
  private ended = false;
  // C120/OMB-01: cached DOM refs — was getElementById every 100ms setInterval + every render frame
  private timerFillEl: HTMLElement | null = null;
  private timerBarEl: HTMLElement | null = null;
  private statusEl: HTMLElement | null = null;

  // C99: cancelTimers() contract — matches mg_combat_rituel reference pattern.
  // Centralises all handle cleanup so both endGame() and cleanup() (via super) call the same code.
  protected cancelTimers(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove); // C99: mirror add below
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  // Canvas dimensions
  private readonly canvasW = 420;
  private readonly canvasH = 380;

  // Game config — totalTime + endHalfWidth scaled by difficultyTier in setup()
  private totalTime = 16;     // C99: scaled 16/14/12/10s across tiers 0-3
  private readonly segmentCount = 40;
  private readonly startHalfWidth = 55;
  private endHalfWidth = 30;  // C99: scaled 30/26/22/18px — narrower at high tier

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

    // C106: tieredValue replaces manual arithmetic — consistent with all other minigames
    this.totalTime    = this.tieredValue([16, 14, 12, 10] as const);
    this.endHalfWidth = this.tieredValue([30, 26, 22, 18] as const);

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
    timerBar.id = 'mg-ombres-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-ombres-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#2e6b4f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Ombres — naviguez dans le couloir en evitant les zones de lumiere');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(10,10,20,0.95);border:2px solid rgba(80,60,120,0.4);cursor:none;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-ombres-status';
    statusEl.setAttribute('aria-live', 'polite'); // C114
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Progression: 0%';
    this.container.appendChild(statusEl);
    this.timerFillEl = timerFill;
    this.timerBarEl = timerBar;
    this.statusEl = statusEl;

    // Generate corridor
    this.generateCorridor();

    // Input
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    // C99: pointerdown updates cursor on first mobile tap — without this, touch users start at (30,190)
    // and progress stays 0 until finger moves. pointermove only fires after movement, not on initial contact.
    this.canvas.addEventListener('pointerdown', this.onPointerMove);
    // C135: WCAG 2.1.1 — ArrowKeys move cursor through corridor (keyboard-only players scored 0 without this)
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.cursorX = 30;
    this.cursorY = this.canvasH / 2;
    this.progress = 0;
    this.ended = false;
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
      this.checkCriticalAlert(this.timeLeft); // C101: fire critical_alert SFX once at 3s
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      if (this.timerFillEl) this.timerFillEl.style.width = `${pct}%`;
      if (this.timerBarEl) this.timerBarEl.setAttribute('aria-valuenow', String(Math.round(pct)));
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

  // C135: WCAG 2.1.1 — keyboard corridor navigation.
  // ArrowRight/Left advance/retreat along corridor (drives progress).
  // ArrowUp/Down move vertically within the corridor (avoid walls).
  private onKeyDown = (e: KeyboardEvent): void => {
    const isNav = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    if (!isNav) return;
    e.preventDefault();
    const stepX = 8;
    const stepY = 10;
    if (e.key === 'ArrowRight') this.cursorX = Math.min(this.canvasW, this.cursorX + stepX);
    else if (e.key === 'ArrowLeft') this.cursorX = Math.max(0, this.cursorX - stepX);
    else if (e.key === 'ArrowUp')   this.cursorY = Math.max(0, this.cursorY - stepY);
    else if (e.key === 'ArrowDown') this.cursorY = Math.min(this.canvasH, this.cursorY + stepY);
    this.progress = Math.max(0, Math.min(1, this.cursorX / this.canvasW));
    if (this.progress > this.maxProgress) this.maxProgress = this.progress;
  };

  private getSegmentAt(t: number): Segment {
    const idx = Math.min(this.segmentCount - 1, Math.max(0, Math.floor(t * (this.segmentCount - 1))));
    return this.segments[idx];
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.cancelTimers(); // C99: centralised via cancelTimers() — no duplicate list here

    // Score = max progress reached * (1 - collision penalty)
    // C103: multiplier raised 0.5→0.85 — wall-hugging (100% collision) now scores ~15, not 50.
    // Prevents wall-huggers from crossing the ≥50 threshold that triggers 'unlock' SFX (OMB-03).
    const collisionPenalty = Math.min(1, this.collisionTime / this.totalTime);
    const rawScore = this.maxProgress * 100 * (1 - collisionPenalty * 0.85);
    // Threshold 50: clean navigation = unlock, heavy collision = lose.
    window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: rawScore >= 50 ? 'unlock' : 'lose' } }));
    this.finish(rawScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C106: ended guard — prevents zombie rAF if endGame() fires before requestAnimationFrame at bottom of render()
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Check collision
    const seg = this.getSegmentAt(this.progress);
    const distFromCenter = Math.abs(this.cursorY - seg.centerY);
    const prevColliding = this.colliding;
    this.colliding = distFromCenter > seg.halfWidth;
    // C99: audio feedback — fire once on collision start (edge-triggered)
    if (this.colliding && !prevColliding) {
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }
    if (this.colliding) {
      this.collisionTime += dt;
    }

    // Update status — C125/OMB-FORMULA-01: show estimated score matching endGame() formula.
    // Was: maxProgress*100 (ignores collision penalty) — diverged up to 70pts from final score.
    // Fix: live penalty = collisionTime/totalTime (same as endGame), estScore mirrors the result.
    if (this.statusEl) {
      const livePenalty = this.totalTime > 0 ? Math.min(1, this.collisionTime / this.totalTime) : 0;
      const estScore = Math.round(this.maxProgress * 100 * (1 - livePenalty * 0.85));
      this.statusEl.textContent = this.colliding
        ? `COLLISION ! Score: ~${estScore}%`
        : `Score: ~${estScore}%`;
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
    // C99: super.cleanup() calls cancelTimers() (MinigameBase line 322) — no duplicate list needed here
    super.cleanup();
  }
}
