// =============================================================================
// Minigame: Course -- QTE chase with flashing symbols
// Letters/symbols flash briefly, player clicks the matching one before it fades.
// 8 rounds, 1.5s window each. Score = (hits / rounds) * 100. Canvas-based.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable symbol target for each round. */
interface RoundTarget {
  readonly symbol: string;
  readonly x: number;
  readonly y: number;
}

/** Immutable decoy for distraction. */
interface Decoy {
  readonly symbol: string;
  readonly x: number;
  readonly y: number;
}

/** All celtic/ogham-themed symbols used in the game. */
const SYMBOLS: readonly string[] = [
  '\u1681', '\u1682', '\u1683', '\u1684', '\u1685', // Ogham letters B L F S N
  '\u1686', '\u1687', '\u1688', '\u1689', '\u168A', // Ogham letters H D T C Q
  '\u168B', '\u168C', '\u168D', '\u168E', '\u168F', // Ogham letters M G NG Z R
];

function randRange(min: number, max: number): number {
  return min + Math.random() * (max - min);
}

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export class MinigameCourse extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 340;

  // Game config
  private readonly totalRounds = 8;
  private readonly roundTime = 1.5;   // seconds per round
  private readonly decoyCount = 4;    // number of distractors per round
  private readonly hitRadius = 32;    // click detection radius

  // Game state
  private currentRound = 0;
  private hits = 0;
  private roundElapsed = 0;
  private roundActive = false;
  private target: RoundTarget | null = null;
  private decoys: readonly Decoy[] = [];
  private feedback: 'none' | 'hit' | 'miss' = 'none';
  private feedbackTimer = 0;
  private pulsePhase = 0;
  private roundTransition = false;
  private transitionTimer = 0;
  private gameOver = false;

  // Prompt display
  private promptSymbol = '';

  protected setup(): void {
    this.container.innerHTML = '';

    // Title
    const title = document.createElement('div');
    title.textContent = 'COURSE -- Attrape les symboles';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Clique sur le symbole demande avant qu\'il disparaisse !';
    instr.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Round indicator
    const roundEl = document.createElement('div');
    roundEl.id = 'mg-course-round';
    roundEl.style.cssText = `width:${this.canvasW}px;height:24px;margin:0 auto 8px;color:rgba(232,220,200,0.7);font-size:14px;text-align:center;font-family:system-ui;line-height:24px;`;
    roundEl.textContent = `Manche 1 / ${this.totalRounds}`;
    this.container.appendChild(roundEl);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,15,25,0.9);border:2px solid rgba(100,80,140,0.4);cursor:pointer;display:block;margin:0 auto;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-course-status';
    statusEl.style.cssText = `width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Touches: 0 / 0';
    this.container.appendChild(statusEl);

    // Input
    this.canvas.addEventListener('pointerdown', this.onClick);

    // Reset state
    this.currentRound = 0;
    this.hits = 0;
    this.roundElapsed = 0;
    this.roundActive = false;
    this.target = null;
    this.decoys = [];
    this.feedback = 'none';
    this.feedbackTimer = 0;
    this.pulsePhase = 0;
    this.roundTransition = true;
    this.transitionTimer = 0.6;
    this.gameOver = false;
    this.promptSymbol = '';

    this.prepareRound();
  }

  private prepareRound(): void {
    if (this.currentRound >= this.totalRounds) {
      this.endGame();
      return;
    }

    // Pick target symbol
    const sym = pick(SYMBOLS);
    this.promptSymbol = sym;

    // Place target at random position (with margin)
    const margin = 50;
    this.target = {
      symbol: sym,
      x: randRange(margin, this.canvasW - margin),
      y: randRange(margin, this.canvasH - margin),
    };

    // Generate decoys (different symbols at different positions)
    const newDecoys: Decoy[] = [];
    for (let i = 0; i < this.decoyCount; i++) {
      let decoySym = pick(SYMBOLS);
      // Ensure decoy is not the target symbol
      while (decoySym === sym) {
        decoySym = pick(SYMBOLS);
      }
      newDecoys.push({
        symbol: decoySym,
        x: randRange(margin, this.canvasW - margin),
        y: randRange(margin, this.canvasH - margin),
      });
    }
    this.decoys = newDecoys;

    this.roundElapsed = 0;
    this.roundActive = false;
    this.roundTransition = true;
    this.transitionTimer = 0.6; // brief pause between rounds
  }

  private onClick = (e: PointerEvent): void => {
    if (!this.canvas || !this.roundActive || this.gameOver) return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    if (!this.target) return;

    // Check if clicked on target
    const dx = mx - this.target.x;
    const dy = my - this.target.y;
    const dist = Math.sqrt(dx * dx + dy * dy);

    if (dist <= this.hitRadius) {
      this.hits++;
      this.feedback = 'hit';
      this.feedbackTimer = 0.4;
      this.roundActive = false;
      this.advanceRound();
    } else {
      // Check if clicked on a decoy (miss penalty)
      const clickedDecoy = this.decoys.some((d) => {
        const ddx = mx - d.x;
        const ddy = my - d.y;
        return Math.sqrt(ddx * ddx + ddy * ddy) <= this.hitRadius;
      });
      if (clickedDecoy) {
        this.feedback = 'miss';
        this.feedbackTimer = 0.4;
        this.roundActive = false;
        this.advanceRound();
      }
    }
  };

  private advanceRound(): void {
    this.currentRound++;
    const roundEl = document.getElementById('mg-course-round');
    if (roundEl) {
      roundEl.textContent = this.currentRound < this.totalRounds
        ? `Manche ${this.currentRound + 1} / ${this.totalRounds}`
        : `Termine !`;
    }

    // Update status
    const statusEl = document.getElementById('mg-course-status');
    if (statusEl) {
      statusEl.textContent = `Touches: ${this.hits} / ${this.currentRound}`;
    }

    if (this.currentRound >= this.totalRounds) {
      // Small delay before ending
      setTimeout(() => this.endGame(), 500);
    } else {
      this.prepareRound();
    }
  }

  private endGame(): void {
    this.gameOver = true;
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);

    const finalScore = (this.hits / this.totalRounds) * 100;
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.gameOver) return;
    const ctx = this.ctx;
    const dt = 1 / 60;
    this.pulsePhase += dt;

    // Handle transition
    if (this.roundTransition) {
      this.transitionTimer -= dt;
      if (this.transitionTimer <= 0) {
        this.roundTransition = false;
        this.roundActive = true;
        this.roundElapsed = 0;
      }
    }

    // Handle round timer
    if (this.roundActive) {
      this.roundElapsed += dt;
      if (this.roundElapsed >= this.roundTime) {
        // Time expired -- miss
        this.feedback = 'miss';
        this.feedbackTimer = 0.3;
        this.roundActive = false;
        this.advanceRound();
      }
    }

    // Feedback decay
    if (this.feedbackTimer > 0) {
      this.feedbackTimer -= dt;
      if (this.feedbackTimer <= 0) {
        this.feedback = 'none';
      }
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background pattern (subtle celtic knot-like)
    ctx.strokeStyle = 'rgba(100,80,140,0.06)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 6; i++) {
      const r = 40 + i * 30;
      ctx.beginPath();
      ctx.arc(this.canvasW / 2, this.canvasH / 2, r, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Prompt -- show which symbol to find (top center)
    ctx.fillStyle = '#e8dcc8';
    ctx.font = '14px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText('Trouve:', this.canvasW / 2, 8);

    ctx.font = '36px serif';
    ctx.fillStyle = '#cd853f';
    ctx.fillText(this.promptSymbol, this.canvasW / 2, 26);

    // Time bar for current round
    if (this.roundActive) {
      const timePct = 1 - (this.roundElapsed / this.roundTime);
      const barW = this.canvasW - 40;
      const barH = 4;
      const barY = this.canvasH - 16;

      ctx.fillStyle = 'rgba(255,255,255,0.1)';
      ctx.fillRect(20, barY, barW, barH);

      const urgency = timePct < 0.3 ? '200,60,60' : '100,80,140';
      ctx.fillStyle = `rgba(${urgency},0.7)`;
      ctx.fillRect(20, barY, barW * timePct, barH);
    }

    // Draw decoys
    if (this.roundActive || this.roundTransition) {
      const alpha = this.roundTransition
        ? Math.max(0, 1 - this.transitionTimer / 0.6)
        : Math.max(0, 1 - this.roundElapsed / this.roundTime);

      // Decoys
      for (const d of this.decoys) {
        ctx.font = '28px serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = `rgba(120,100,100,${alpha * 0.6})`;
        ctx.fillText(d.symbol, d.x, d.y);

        // Subtle ring
        ctx.beginPath();
        ctx.arc(d.x, d.y, this.hitRadius, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(120,100,100,${alpha * 0.1})`;
        ctx.lineWidth = 1;
        ctx.stroke();
      }

      // Target (slightly brighter)
      if (this.target) {
        const targetPulse = 0.7 + Math.sin(this.pulsePhase * 5) * 0.3;
        ctx.font = '28px serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = `rgba(220,200,160,${alpha * targetPulse})`;
        ctx.fillText(this.target.symbol, this.target.x, this.target.y);

        // Target glow
        const glow = ctx.createRadialGradient(
          this.target.x, this.target.y, 0,
          this.target.x, this.target.y, this.hitRadius
        );
        glow.addColorStop(0, `rgba(200,170,100,${alpha * 0.15})`);
        glow.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(this.target.x, this.target.y, this.hitRadius, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Feedback flash
    if (this.feedback !== 'none' && this.feedbackTimer > 0) {
      const fbAlpha = this.feedbackTimer / 0.4;
      if (this.feedback === 'hit') {
        ctx.fillStyle = `rgba(80,180,80,${fbAlpha * 0.2})`;
      } else {
        ctx.fillStyle = `rgba(200,60,60,${fbAlpha * 0.2})`;
      }
      ctx.fillRect(0, 0, this.canvasW, this.canvasH);

      ctx.font = '32px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = this.feedback === 'hit'
        ? `rgba(80,220,80,${fbAlpha})`
        : `rgba(220,80,80,${fbAlpha})`;
      ctx.fillText(
        this.feedback === 'hit' ? 'Touche !' : 'Rate !',
        this.canvasW / 2, this.canvasH / 2
      );
    }

    // Score dots (bottom)
    const dotY = this.canvasH - 30;
    const dotSpacing = 28;
    const dotStartX = (this.canvasW - (this.totalRounds - 1) * dotSpacing) / 2;
    for (let i = 0; i < this.totalRounds; i++) {
      const dx = dotStartX + i * dotSpacing;
      ctx.beginPath();
      ctx.arc(dx, dotY, 6, 0, Math.PI * 2);
      if (i < this.currentRound) {
        // Completed round
        ctx.fillStyle = i < this.hits + (this.currentRound - this.hits - (i >= this.hits ? 0 : 0))
          ? 'rgba(80,180,80,0.7)' : 'rgba(200,60,60,0.5)';
        // Simpler: track hits order... just color based on result
        ctx.fillStyle = 'rgba(140,130,120,0.5)';
        ctx.fill();
      } else if (i === this.currentRound) {
        // Current round
        const cp = 0.5 + Math.sin(this.pulsePhase * 4) * 0.3;
        ctx.fillStyle = `rgba(200,170,100,${cp})`;
        ctx.fill();
      } else {
        // Future round
        ctx.fillStyle = 'rgba(80,70,60,0.3)';
        ctx.fill();
      }
      ctx.strokeStyle = 'rgba(200,170,100,0.2)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    super.cleanup();
  }
}
