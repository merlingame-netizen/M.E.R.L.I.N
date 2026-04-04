// =============================================================================
// Minigame: Apaisement -- Breathing rhythm synchronization
// A pulsing circle expands and contracts rhythmically. Player clicks/taps
// when the circle reaches its target size (peak expand or peak contract).
// 12s timer. Score = sync accuracy percentage.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable record of a single breath tap. */
interface BreathTap {
  readonly time: number;      // elapsed time of tap
  readonly accuracy: number;  // 0-1 how close to peak
  readonly phase: string;     // 'expand' or 'contract'
}

export class MinigameApaisement extends MinigameBase {
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

  // Breathing config — C100: scaled by difficultyTier in setup()
  private totalTime = 12;             // C100: [12,10,8,6]s
  private breathCycleDuration = 3.0;  // C100: [3.0,2.5,2.0,1.7]s
  private readonly minRadius = 30;
  private readonly maxRadius = 120;
  private targetWindow = 0.15;        // C100: [0.15,0.13,0.10,0.08]
  private goodWindow = 0.30;          // C100: [0.30,0.25,0.20,0.16]

  // Game state
  private timeLeft = 12;
  private elapsedTime = 0;
  private breathPhase = 0;          // 0-1 within breath cycle
  private currentRadius = 30;
  private taps: readonly BreathTap[] = [];
  private lastTapFeedback = '';
  private feedbackAlpha = 0;
  private feedbackColor = '';
  private totalAccuracy = 0;
  private ringPulse = 0;
  private showGuide = true;

  protected setup(): void {
    this.container.innerHTML = '';

    // C100: difficulty scaling
    this.totalTime           = this.tieredValue([12, 10, 8, 6] as const);
    this.breathCycleDuration = this.tieredValue([3.0, 2.5, 2.0, 1.7] as const);
    this.targetWindow        = this.tieredValue([0.15, 0.13, 0.10, 0.08] as const);
    this.goodWindow          = this.tieredValue([0.30, 0.25, 0.20, 0.16] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'APAISEMENT -- Respire avec le cercle';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Clique quand le cercle atteint son maximum ou minimum.';
    instr.style.cssText = 'color:#5a8a5a;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-apaise-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-apaise-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#3a6b3a;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Apaisement — synchronisez votre respiration avec le cercle de lumiere');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(10,18,10,0.9);border:1px solid rgba(90,138,90,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Score display
    const scoreEl = document.createElement('div');
    scoreEl.id = 'mg-apaise-score';
    scoreEl.setAttribute('aria-live', 'polite'); // C114
    scoreEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    scoreEl.textContent = 'Synchronisation: --';
    this.container.appendChild(scoreEl);

    // Input
    this.canvas.addEventListener('pointerdown', this.onPointerDown);
    // C136: WCAG 2.1.1 — Space/Enter trigger breath tap for keyboard-only players
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.breathPhase = 0;
    this.ended = false;
    this.currentRadius = this.minRadius;
    this.taps = [];
    this.lastTapFeedback = '';
    this.feedbackAlpha = 0;
    this.feedbackColor = '';
    this.totalAccuracy = 0;
    this.ringPulse = 0;
    this.showGuide = true;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      this.checkCriticalAlert(this.timeLeft); // C101: fire critical_alert SFX once at 3s
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-apaise-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-apaise-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  /**
   * Calculate how close the current breath phase is to a peak (expand or contract).
   * Returns accuracy 0-1 where 1 = perfect timing.
   * breathPhase goes 0->0.5 (expanding) then 0.5->1.0 (contracting).
   * Peaks at 0.5 (max expand) and 0.0/1.0 (max contract).
   */
  private getAccuracy(): { accuracy: number; phase: string } {
    // Distance to nearest peak (0.0 or 0.5)
    const distToExpand = Math.abs(this.breathPhase - 0.5);
    const distToContract = Math.min(this.breathPhase, 1.0 - this.breathPhase);
    const minDist = Math.min(distToExpand, distToContract);
    const phase = distToExpand < distToContract ? 'expand' : 'contract';

    // Convert distance to accuracy (0 at peak = 1.0 accuracy)
    if (minDist <= this.targetWindow / 2) {
      return { accuracy: 1.0, phase };
    }
    if (minDist <= this.goodWindow / 2) {
      // Linear falloff from 1.0 to 0.5 in the good window
      const t = (minDist - this.targetWindow / 2) / (this.goodWindow / 2 - this.targetWindow / 2);
      return { accuracy: 1.0 - t * 0.5, phase };
    }
    // Outside good window -- poor timing
    const t = Math.min(1, (minDist - this.goodWindow / 2) / 0.25);
    return { accuracy: Math.max(0, 0.5 - t * 0.5), phase };
  }

  // C136: WCAG 2.1.1 — keyboard tap (Space/Enter = same effect as pointer tap)
  private onKeyDown = (e: KeyboardEvent): void => {
    if (e.key !== ' ' && e.key !== 'Enter') return;
    e.preventDefault();
    this.registerTap();
  };

  private onPointerDown = (_e: PointerEvent): void => {
    if (this.timeLeft <= 0) return;
    this.registerTap();
  };

  // C136: shared tap logic extracted to avoid duplication between pointer and keyboard paths
  private registerTap(): void {
    if (this.timeLeft <= 0) return;
    this.showGuide = false;

    const { accuracy, phase } = this.getAccuracy();

    const tap: BreathTap = {
      time: this.elapsedTime,
      accuracy,
      phase,
    };
    this.taps = [...this.taps, tap];
    this.totalAccuracy += accuracy;

    // Visual feedback
    this.ringPulse = 1.0;
    if (accuracy >= 0.9) {
      this.lastTapFeedback = 'Parfait !';
      this.feedbackColor = '#60c060';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else if (accuracy >= 0.5) {
      this.lastTapFeedback = 'Bien';
      this.feedbackColor = '#a0b060';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else {
      this.lastTapFeedback = 'Decale...';
      this.feedbackColor = '#b06040';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }
    this.feedbackAlpha = 1.0;

    // Update score display
    const scoreEl = document.getElementById('mg-apaise-score');
    if (scoreEl && this.taps.length > 0) {
      const avgAcc = this.totalAccuracy / this.taps.length;
      scoreEl.textContent = `Synchronisation: ${Math.round(avgAcc * 100)}% (${this.taps.length} respirations)`;
    }
  }

  protected cancelTimers(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.cancelTimers(); // C101: centralised teardown

    // Score = average accuracy * 100, with a minimum tap count bonus
    // At least 4 taps needed for full score potential
    const tapCount = this.taps.length;
    if (tapCount === 0) {
      this.finish(0);
      return;
    }

    const avgAccuracy = this.totalAccuracy / tapCount;
    const tapBonus = Math.min(1.0, tapCount / 4); // penalize if fewer than 4 taps
    const finalScore = avgAccuracy * tapBonus * 100;

    // Floor of 10 for any engaged player (≥1 tap) — distinguishes participation from idle
    this.finish(Math.max(10, finalScore));
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;

    // Update breath phase (0 -> 1 over breathCycleDuration)
    this.breathPhase = (this.breathPhase + dt / this.breathCycleDuration) % 1.0;

    // Sinusoidal radius: min at phase 0/1, max at phase 0.5
    const t = Math.sin(this.breathPhase * Math.PI);
    this.currentRadius = this.minRadius + (this.maxRadius - this.minRadius) * t;

    // Feedback decay
    if (this.feedbackAlpha > 0) this.feedbackAlpha -= dt * 1.5;
    if (this.ringPulse > 0) this.ringPulse -= dt * 3;

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background
    const bgGrad = ctx.createRadialGradient(
      this.centerX, this.centerY, 0,
      this.centerX, this.centerY, this.canvasW / 2
    );
    bgGrad.addColorStop(0, 'rgba(15,25,15,0.95)');
    bgGrad.addColorStop(1, 'rgba(8,12,8,0.98)');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, this.canvasW, this.canvasH);

    // Target rings (show where peaks are)
    // Max ring
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.maxRadius, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(90,138,90,0.15)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 8]);
    ctx.stroke();
    ctx.setLineDash([]);

    // Min ring
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.minRadius, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(90,138,90,0.15)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 8]);
    ctx.stroke();
    ctx.setLineDash([]);

    // Guide text (first few seconds)
    if (this.showGuide && this.elapsedTime < 5) {
      const guideAlpha = Math.max(0, 1 - this.elapsedTime / 5);
      ctx.fillStyle = `rgba(90,138,90,${guideAlpha * 0.6})`;
      ctx.font = '14px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('Clique aux extremes', this.centerX, this.centerY + this.maxRadius + 30);
    }

    // Breathing circle -- main visual
    const breathGrad = ctx.createRadialGradient(
      this.centerX, this.centerY, 0,
      this.centerX, this.centerY, this.currentRadius
    );

    // Color shifts with breath phase
    const expanding = this.breathPhase < 0.5;
    if (expanding) {
      breathGrad.addColorStop(0, 'rgba(60,120,60,0.3)');
      breathGrad.addColorStop(0.7, 'rgba(40,100,40,0.2)');
      breathGrad.addColorStop(1, 'rgba(30,80,30,0.1)');
    } else {
      breathGrad.addColorStop(0, 'rgba(40,100,80,0.3)');
      breathGrad.addColorStop(0.7, 'rgba(30,80,60,0.2)');
      breathGrad.addColorStop(1, 'rgba(20,60,40,0.1)');
    }

    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.currentRadius, 0, Math.PI * 2);
    ctx.fillStyle = breathGrad;
    ctx.fill();

    // Circle border
    const borderAlpha = 0.4 + (this.ringPulse > 0 ? this.ringPulse * 0.4 : 0);
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.currentRadius, 0, Math.PI * 2);
    ctx.strokeStyle = this.ringPulse > 0
      ? `rgba(100,200,100,${borderAlpha})`
      : `rgba(90,138,90,${borderAlpha})`;
    ctx.lineWidth = this.ringPulse > 0 ? 3 : 2;
    ctx.stroke();

    // Ring pulse effect (on tap)
    if (this.ringPulse > 0) {
      ctx.beginPath();
      ctx.arc(
        this.centerX, this.centerY,
        this.currentRadius + (1 - this.ringPulse) * 30,
        0, Math.PI * 2
      );
      ctx.strokeStyle = `rgba(100,200,100,${this.ringPulse * 0.3})`;
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // Center dot (breath indicator)
    const dotSize = 4 + t * 3;
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, dotSize, 0, Math.PI * 2);
    ctx.fillStyle = expanding ? '#5a8a5a' : '#4a7a6a';
    ctx.fill();

    // Phase label
    ctx.fillStyle = 'rgba(232,220,200,0.3)';
    ctx.font = '12px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(
      expanding ? 'Inspire...' : 'Expire...',
      this.centerX, this.centerY - this.maxRadius - 16
    );

    // Tap feedback text
    if (this.feedbackAlpha > 0 && this.lastTapFeedback) {
      ctx.save();
      ctx.globalAlpha = this.feedbackAlpha;
      ctx.fillStyle = this.feedbackColor;
      ctx.font = 'bold 22px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(this.lastTapFeedback, this.centerX, this.centerY + this.maxRadius + 24);
      ctx.restore();
    }

    // Tap history dots (last 8 taps shown around the circle)
    const recentTaps = this.taps.slice(-8);
    for (let i = 0; i < recentTaps.length; i++) {
      const tap = recentTaps[i];
      const tapAngle = -Math.PI / 2 + (i / 8) * Math.PI * 2;
      const tapX = this.centerX + Math.cos(tapAngle) * (this.maxRadius + 20);
      const tapY = this.centerY + Math.sin(tapAngle) * (this.maxRadius + 20);

      ctx.beginPath();
      ctx.arc(tapX, tapY, 4, 0, Math.PI * 2);
      if (tap.accuracy >= 0.9) {
        ctx.fillStyle = '#60c060';
      } else if (tap.accuracy >= 0.5) {
        ctx.fillStyle = '#a0b060';
      } else {
        ctx.fillStyle = '#b06040';
      }
      ctx.fill();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    super.cleanup(); // calls cancelTimers() — C101
  }
}
