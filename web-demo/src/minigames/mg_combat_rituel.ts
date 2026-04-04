// =============================================================================
// Minigame: Combat Rituel -- Dodge obstacles in a sacred circle
// Circular dodge arena: player cursor avoids rotating obstacles. 10s timer.
// Score = survival time percentage + center bonus (staying near center is risky
// but awards bonus). Canvas-based.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable obstacle descriptor. */
interface Obstacle {
  readonly angle: number;      // radians, position on the circle
  readonly speed: number;      // radians per second
  readonly width: number;      // angular width in radians
  readonly radius: number;     // distance from center
  readonly thickness: number;  // radial thickness
}

/** Pick a random number between min and max. */
function randRange(min: number, max: number): number {
  return min + Math.random() * (max - min);
}

export class MinigameCombatRituel extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;
  private ended = false;
  // C119/COMBAT-01: cached DOM refs — was getElementById every frame / every 100ms setInterval
  private timerFillEl: HTMLElement | null = null;
  private timerBarEl: HTMLElement | null = null;
  private statusEl: HTMLElement | null = null;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 380;
  private readonly centerX = 190;
  private readonly centerY = 190;
  private readonly arenaRadius = 150;

  // Game config — totalTime + obstacleCount scaled by difficultyTier in setup()
  private totalTime = 16;      // C99: scaled 16/14/12/10s across tiers 0-3
  private obstacleCount = 3;   // C99: scaled 3/4/5/6 — more obstacles at high tier
  private readonly centerBonusRadius = 40; // px from center for bonus zone

  // Game state
  private playerX = 190;
  private playerY = 190;
  private obstacles: Obstacle[] = [];
  private timeLeft = 10;
  private elapsedTime = 0;
  private survivalTime = 0;
  private centerTime = 0;  // time spent near center
  private hit = false;
  private hitFlash = 0;
  private pulsePhase = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // C103: tieredValue replaces manual arithmetic — consistent with all other minigames
    this.totalTime     = this.tieredValue([16, 14, 12, 10] as const);
    this.obstacleCount = this.tieredValue([3, 4, 5, 6] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'COMBAT RITUEL -- Esquive dans le cercle sacre';
    title.style.cssText = 'color:rgba(51,255,102,0.88);font-size:14px;text-align:center;margin-bottom:4px;font-family:Courier New,monospace;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Deplace ton curseur pour esquiver. Le centre donne un bonus.';
    instr.style.cssText = 'color:rgba(51,255,102,0.50);font-size:11px;text-align:center;margin-bottom:8px;font-family:Courier New,monospace;';
    this.container.appendChild(instr);

    // Timer bar — responsive width (min of canvas width and 100%)
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-combat-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-combat-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#8b2020;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Arène de combat rituel — déplacez le curseur pour esquiver les obstacles');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:50%;background:rgba(15,15,25,0.9);border:2px solid rgba(139,32,32,0.4);cursor:none;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status display
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-combat-status';
    statusEl.setAttribute('aria-live', 'polite'); // C114
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(51,255,102,0.45);font-size:12px;text-align:center;font-family:Courier New,monospace;`;
    statusEl.textContent = 'Survie: 0.0s';
    this.container.appendChild(statusEl);
    // C119/COMBAT-01: cache refs so render() and setInterval don't call getElementById each tick
    this.timerFillEl = timerFill;
    this.timerBarEl = timerBar;
    this.statusEl = statusEl;

    // Input -- pointer move
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    this.canvas.addEventListener('pointerdown', this.onPointerMove);
    // C128: arrow key cursor — WCAG 2.1.1 keyboard accessibility
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.playerX = this.centerX;
    this.playerY = this.centerY;
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.survivalTime = 0;
    this.centerTime = 0;
    this.hit = false;
    this.hitFlash = 0;
    this.pulsePhase = 0;
    this.ended = false;

    // Generate obstacles -- rotating arcs at various radii
    this.obstacles = [];
    for (let i = 0; i < this.obstacleCount; i++) {
      this.obstacles = [
        ...this.obstacles,
        {
          angle: randRange(0, Math.PI * 2),
          speed: randRange(0.8, 2.5) * (Math.random() > 0.5 ? 1 : -1),
          width: randRange(0.4, 1.0),   // angular width
          radius: randRange(50, 130),     // distance from center
          thickness: randRange(12, 24),   // radial thickness
        },
      ];
    }

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

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    this.playerX = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    this.playerY = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Clamp player to arena circle
    const dx = this.playerX - this.centerX;
    const dy = this.playerY - this.centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > this.arenaRadius - 8) {
      const scale = (this.arenaRadius - 8) / dist;
      this.playerX = this.centerX + dx * scale;
      this.playerY = this.centerY + dy * scale;
    }
  };

  // C128: arrow key cursor — WCAG 2.1.1 (mirrors mg_sang_froid C96 pattern)
  // Moves playerX/Y by 10px per press; clamps to arena boundary matching onPointerMove.
  private onKeyDown = (e: KeyboardEvent): void => {
    const isArrow = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    if (!isArrow) return;
    e.preventDefault();
    const step = 10;
    if (e.key === 'ArrowLeft')       this.playerX -= step;
    else if (e.key === 'ArrowRight') this.playerX += step;
    else if (e.key === 'ArrowUp')    this.playerY -= step;
    else if (e.key === 'ArrowDown')  this.playerY += step;
    // Clamp to arena boundary (same constraint as onPointerMove)
    const dx = this.playerX - this.centerX;
    const dy = this.playerY - this.centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > this.arenaRadius - 8) {
      const scale = (this.arenaRadius - 8) / dist;
      this.playerX = this.centerX + dx * scale;
      this.playerY = this.centerY + dy * scale;
    }
  };

  private checkCollision(): boolean {
    const px = this.playerX - this.centerX;
    const py = this.playerY - this.centerY;
    const playerDist = Math.sqrt(px * px + py * py);
    const playerAngle = Math.atan2(py, px);

    for (const obs of this.obstacles) {
      // Check radial overlap (player is a ~8px circle)
      const rMin = obs.radius - obs.thickness / 2;
      const rMax = obs.radius + obs.thickness / 2;
      if (playerDist + 6 < rMin || playerDist - 6 > rMax) continue;

      // Check angular overlap
      const halfWidth = obs.width / 2;
      let angleDiff = playerAngle - obs.angle;
      // Normalize to [-PI, PI]
      while (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
      while (angleDiff < -Math.PI) angleDiff += Math.PI * 2;

      if (Math.abs(angleDiff) < halfWidth + 0.08) {
        return true;
      }
    }
    return false;
  }

  // C102: extract handle teardown into cancelTimers() — called by both endGame() and
  // MinigameBase.cleanup() (via super). Eliminates the maintenance-trap duplication.
  protected cancelTimers(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onPointerMove);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.cancelTimers();

    // Score = survival time percentage (0-80) + center bonus (0-20)
    const survivalPct = (this.survivalTime / this.totalTime) * 80;
    const centerPct = this.totalTime > 0
      ? (this.centerTime / this.totalTime) * 20
      : 0;

    const finalScore = Math.min(100, survivalPct + centerPct);
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C106: ended guard — prevents zombie rAF if endGame() fires before requestAnimationFrame at bottom of render()
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Progressive difficulty: obstacles accelerate exponentially from 1.0x to 2.5x over 10s
    // Easing: cubic — gentle start, steep end (satisfying escalation without early frustration)
    const timeRatio = Math.min(1, this.elapsedTime / this.totalTime);
    const speedMult = 1.0 + (timeRatio * timeRatio * timeRatio) * 1.5;

    // Update obstacle angles with progressive speed multiplier
    this.obstacles = this.obstacles.map((obs) => ({
      ...obs,
      angle: obs.angle + obs.speed * speedMult * dt,
    }));

    // Check collision
    if (this.checkCollision()) {
      if (!this.hit) {
        this.hit = true;
        this.hitFlash = 0.5;
        // C99: audio feedback — first frame of each new collision (edge-triggered)
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
      }
    } else {
      // C83: edge-triggered dodge-recovery — first frame clear after collision (reward the dodge)
      if (this.hit) window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
      this.hit = false;
      this.survivalTime += dt;
    }

    // C140/COMB-01: center bonus is positional — accumulate independently of hit state
    // (player at center while absorbing a hit still deserves precision credit)
    const dx = this.playerX - this.centerX;
    const dy = this.playerY - this.centerY;
    if (Math.sqrt(dx * dx + dy * dy) < this.centerBonusRadius) {
      this.centerTime += dt;
    }

    // Hit flash decay
    if (this.hitFlash > 0) this.hitFlash -= dt * 2;

    // Update status — C127/COMB-FORMULA-01: show estimated score matching endGame formula.
    // Was: raw seconds (e.g. "Survie: 10.0s") — implied 100% but score is weighted %, gap >20pts.
    // endGame: survivalPct = (survivalTime/totalTime)*80 + centerPct = (centerTime/totalTime)*20.
    if (this.statusEl) {
      const estSurv = Math.round((this.survivalTime / this.totalTime) * 80);
      const estCtr = this.totalTime > 0 ? Math.round((this.centerTime / this.totalTime) * 20) : 0;
      this.statusEl.textContent = `Score: ~${estSurv + estCtr}% (survie ${estSurv}/80, centre ${estCtr}/20)`;
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Arena circle
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.arenaRadius, 0, Math.PI * 2);
    const arenaGrad = ctx.createRadialGradient(
      this.centerX, this.centerY, 0,
      this.centerX, this.centerY, this.arenaRadius
    );
    arenaGrad.addColorStop(0, 'rgba(30,15,15,0.95)');
    arenaGrad.addColorStop(0.7, 'rgba(20,10,10,0.9)');
    arenaGrad.addColorStop(1, 'rgba(10,5,5,0.85)');
    ctx.fillStyle = arenaGrad;
    ctx.fill();

    // Hit flash overlay
    if (this.hitFlash > 0) {
      ctx.beginPath();
      ctx.arc(this.centerX, this.centerY, this.arenaRadius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(200,40,40,${this.hitFlash * 0.3})`;
      ctx.fill();
    }

    // Center bonus zone
    const centerPulse = 0.15 + Math.sin(this.pulsePhase * 3) * 0.08;
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.centerBonusRadius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(200,170,60,${centerPulse})`;
    ctx.fill();
    ctx.strokeStyle = `rgba(200,170,60,${centerPulse + 0.1})`;
    ctx.lineWidth = 1;
    ctx.stroke();

    // Sacred circle border marks (8 runes)
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2 + this.pulsePhase * 0.2;
      const rx = this.centerX + Math.cos(a) * (this.arenaRadius - 4);
      const ry = this.centerY + Math.sin(a) * (this.arenaRadius - 4);
      ctx.fillStyle = 'rgba(139,32,32,0.5)';
      ctx.font = '12px Courier New';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('\u1680', rx, ry); // ogham space mark as decoration
    }

    // Draw obstacles (rotating arcs)
    for (const obs of this.obstacles) {
      const startAngle = obs.angle - obs.width / 2;
      const endAngle = obs.angle + obs.width / 2;
      const rInner = obs.radius - obs.thickness / 2;
      const rOuter = obs.radius + obs.thickness / 2;

      ctx.beginPath();
      ctx.arc(this.centerX, this.centerY, rOuter, startAngle, endAngle);
      ctx.arc(this.centerX, this.centerY, rInner, endAngle, startAngle, true);
      ctx.closePath();

      const obsPulse = 0.6 + Math.sin(this.pulsePhase * 4 + obs.angle) * 0.2;
      ctx.fillStyle = `rgba(180,50,50,${obsPulse})`;
      ctx.fill();
      ctx.strokeStyle = `rgba(220,80,80,${obsPulse * 0.7})`;
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Draw player cursor
    const px = this.playerX;
    const py = this.playerY;

    // Player glow
    const playerGrad = ctx.createRadialGradient(px, py, 0, px, py, 16);
    playerGrad.addColorStop(0, this.hit ? 'rgba(200,60,60,0.6)' : 'rgba(200,180,100,0.4)');
    playerGrad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = playerGrad;
    ctx.beginPath();
    ctx.arc(px, py, 16, 0, Math.PI * 2);
    ctx.fill();

    // Player dot
    ctx.beginPath();
    ctx.arc(px, py, 6, 0, Math.PI * 2);
    ctx.fillStyle = this.hit ? '#c84040' : 'rgba(51,255,102,0.85)';
    ctx.fill();
    ctx.strokeStyle = this.hit ? '#ff6060' : 'rgba(51,255,102,0.60)';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Arena border ring
    ctx.beginPath();
    ctx.arc(this.centerX, this.centerY, this.arenaRadius, 0, Math.PI * 2);
    ctx.strokeStyle = `rgba(139,32,32,${0.4 + Math.sin(this.pulsePhase * 2) * 0.1})`;
    ctx.lineWidth = 2;
    ctx.stroke();

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    // cancelTimers() is called by super.cleanup() via MinigameBase.cleanup() (BUG-C88-08)
    super.cleanup();
  }
}
