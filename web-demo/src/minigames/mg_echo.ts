// =============================================================================
// Minigame: Echo -- Sound direction (visual-only variant)
// A Celtic symbol appears briefly in one of 4 quadrants, then vanishes.
// Player clicks which quadrant it appeared in. 6 rounds, 1.2s window.
// Score = hits / rounds * 100. Canvas-based.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Quadrant layout. */
interface Quadrant {
  readonly label: string;
  readonly cx: number;
  readonly cy: number;
  readonly symbol: string; // cardinal direction symbol
}

/** Ogham symbols used as flash targets. */
const FLASH_SYMBOLS: readonly string[] = [
  '\u1681', '\u1682', '\u1683', '\u1684', '\u1685',
  '\u1686', '\u1687', '\u1688', '\u1689', '\u168A',
  '\u168B', '\u168C', '\u168D', '\u168E', '\u168F',
];

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export class MinigameEcho extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private ended = false;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 340;

  // Game config
  private readonly totalRounds = 6;
  private flashDuration = 0.5;   // C100: [0.5,0.4,0.35,0.3]s
  private windowDuration = 1.2;  // C100: [1.2,1.0,0.8,0.7]s
  private readonly pauseBetween = 0.6;    // pause between rounds

  // Quadrant positions (relative to canvas center)
  private readonly quadrants: readonly Quadrant[] = [
    { label: 'Nord', cx: 0, cy: -80, symbol: '\u2191' },
    { label: 'Est', cx: 100, cy: 0, symbol: '\u2192' },
    { label: 'Sud', cx: 0, cy: 80, symbol: '\u2193' },
    { label: 'Ouest', cx: -100, cy: 0, symbol: '\u2190' },
  ];

  // Game state
  private currentRound = 0;
  private hits = 0;
  private phase: 'flash' | 'answer' | 'feedback' | 'pause' | 'done' = 'pause';
  private phaseTimer = 0;
  private targetQuadrant = 0;     // index into quadrants
  private flashSymbol = '';
  private feedback: 'none' | 'hit' | 'miss' = 'none';
  private feedbackTimer = 0;
  private answered = false;
  private pulsePhase = 0;
  // Ripple effect state
  private rippleActive = false;
  private rippleX = 0;
  private rippleY = 0;
  private rippleTimer = 0;

  private get centerX(): number { return this.canvasW / 2; }
  private get centerY(): number { return this.canvasH / 2; }

  protected setup(): void {
    this.container.innerHTML = '';

    // C100: difficulty scaling — shorter flash and answer window at high tiers
    this.flashDuration  = this.tieredValue([0.5, 0.4, 0.35, 0.3] as const);
    this.windowDuration = this.tieredValue([1.2, 1.0, 0.8, 0.7] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'ECHO -- D\'ou vient l\'appel ?';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.textContent = 'Un symbole apparait brievement. Clique sur le quadrant d\'ou il venait !';
    instr.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(instr);

    // Round indicator
    const roundEl = document.createElement('div');
    roundEl.id = 'mg-echo-round';
    roundEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:24px;margin:0 auto 8px;color:rgba(232,220,200,0.7);font-size:14px;text-align:center;font-family:system-ui;line-height:24px;`;
    roundEl.textContent = `Manche 1 / ${this.totalRounds}`;
    this.container.appendChild(roundEl);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Echo — memorisez la direction du son et cliquez sur le bon quadrant');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,15,25,0.9);border:2px solid rgba(100,80,140,0.4);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-echo-status';
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Ecoute...';
    this.container.appendChild(statusEl);

    // Input — pointer + keyboard (C111: ArrowKeys map to Nord/Est/Sud/Ouest quadrants, WCAG 2.1.1)
    this.canvas.addEventListener('pointerdown', this.onClick);
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.currentRound = 0;
    this.hits = 0;
    this.ended = false;
    this.pulsePhase = 0;
    this.rippleActive = false;

    // Start first round after brief pause
    this.phase = 'pause';
    this.phaseTimer = this.pauseBetween;
    this.prepareRound();
  }

  private prepareRound(): void {
    // Pick random quadrant and symbol
    this.targetQuadrant = Math.floor(Math.random() * this.quadrants.length);
    this.flashSymbol = pick(FLASH_SYMBOLS);
    this.answered = false;
    this.feedback = 'none';
  }

  private onClick = (e: PointerEvent): void => {
    if (!this.canvas || this.phase !== 'answer' || this.answered) return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Determine which quadrant was clicked
    const clickedQuadrant = this.getClickedQuadrant(mx, my);
    if (clickedQuadrant < 0) return;

    this.answered = true;

    if (clickedQuadrant === this.targetQuadrant) {
      this.hits++;
      this.feedback = 'hit';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else {
      this.feedback = 'miss';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }

    this.phase = 'feedback';
    this.feedbackTimer = 0.5;

    // Start ripple from click position
    this.rippleActive = true;
    this.rippleX = mx;
    this.rippleY = my;
    this.rippleTimer = 0;

    const statusEl = document.getElementById('mg-echo-status');
    if (statusEl) {
      statusEl.textContent = `Echos captes: ${this.hits} / ${this.currentRound + 1}`;
    }
  };

  // C111: keyboard handler — ArrowUp=Nord, ArrowRight=Est, ArrowDown=Sud, ArrowLeft=Ouest (WCAG 2.1.1)
  private onKeyDown = (e: KeyboardEvent): void => {
    if (!this.canvas || this.phase !== 'answer' || this.answered) return;
    const keyMap: Record<string, number> = {
      ArrowUp: 0, ArrowRight: 1, ArrowDown: 2, ArrowLeft: 3,
    };
    const quadrant = keyMap[e.key];
    if (quadrant === undefined) return;
    e.preventDefault();

    this.answered = true;
    if (quadrant === this.targetQuadrant) {
      this.hits++;
      this.feedback = 'hit';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else {
      this.feedback = 'miss';
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }
    this.phase = 'feedback';
    this.feedbackTimer = 0.5;
    // Ripple at quadrant centre so keyboard players get visual feedback
    const q = this.quadrants[quadrant];
    if (q) {
      this.rippleActive = true;
      this.rippleX = this.centerX + q.cx;
      this.rippleY = this.centerY + q.cy;
      this.rippleTimer = 0;
    }
    const statusEl = document.getElementById('mg-echo-status');
    if (statusEl) statusEl.textContent = `Echos captes: ${this.hits} / ${this.currentRound + 1}`;
  };

  private getClickedQuadrant(mx: number, my: number): number {
    // Simple: determine quadrant by position relative to center
    const dx = mx - this.centerX;
    const dy = my - this.centerY;

    // Must be outside a central dead zone
    if (Math.abs(dx) < 30 && Math.abs(dy) < 30) return -1;

    // Determine primary direction
    if (Math.abs(dy) > Math.abs(dx)) {
      return dy < 0 ? 0 : 2; // North or South
    } else {
      return dx > 0 ? 1 : 3; // East or West
    }
  }

  private advanceRound(): void {
    this.currentRound++;
    const roundEl = document.getElementById('mg-echo-round');
    if (roundEl) {
      roundEl.textContent = this.currentRound < this.totalRounds
        ? `Manche ${this.currentRound + 1} / ${this.totalRounds}`
        : 'Termine !';
    }

    if (this.currentRound >= this.totalRounds) {
      this.endGame();
      return;
    }

    this.prepareRound();
    this.phase = 'pause';
    this.phaseTimer = this.pauseBetween;
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.phase = 'done';
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);

    const finalScore = (this.hits / this.totalRounds) * 100;
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.phase === 'done') return;
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.pulsePhase += dt;

    // Phase transitions
    if (this.phase === 'pause') {
      this.phaseTimer -= dt;
      if (this.phaseTimer <= 0) {
        this.phase = 'flash';
        this.phaseTimer = this.flashDuration;
      }
    }

    if (this.phase === 'flash') {
      this.phaseTimer -= dt;
      if (this.phaseTimer <= 0) {
        this.phase = 'answer';
        this.phaseTimer = this.windowDuration;
      }
    }

    if (this.phase === 'answer') {
      this.phaseTimer -= dt;
      if (this.phaseTimer <= 0 && !this.answered) {
        // Timed out -- miss
        this.feedback = 'miss';
        this.phase = 'feedback';
        this.feedbackTimer = 0.5;
        this.answered = true;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));

        const statusEl = document.getElementById('mg-echo-status');
        if (statusEl) {
          statusEl.textContent = `Echos captes: ${this.hits} / ${this.currentRound + 1}`;
        }
      }
    }

    if (this.phase === 'feedback') {
      this.feedbackTimer -= dt;
      if (this.feedbackTimer <= 0) {
        this.advanceRound();
      }
    }

    // Ripple timer
    if (this.rippleActive) {
      this.rippleTimer += dt;
      if (this.rippleTimer > 0.6) {
        this.rippleActive = false;
      }
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background -- subtle concentric sound waves from center
    ctx.strokeStyle = 'rgba(100,80,140,0.05)';
    ctx.lineWidth = 1;
    const waveOffset = (this.pulsePhase * 30) % 40;
    for (let i = 0; i < 8; i++) {
      const r = waveOffset + i * 40;
      if (r < 200) {
        ctx.beginPath();
        ctx.arc(this.centerX, this.centerY, r, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // Draw quadrant zones
    for (let qi = 0; qi < this.quadrants.length; qi++) {
      const q = this.quadrants[qi];
      const qx = this.centerX + q.cx;
      const qy = this.centerY + q.cy;

      // Zone circle
      let zoneAlpha = 0.15;
      let zoneColor = '100,80,140';

      if (this.phase === 'answer' && !this.answered) {
        // Highlight on hover-like pulse
        zoneAlpha = 0.2 + Math.sin(this.pulsePhase * 3 + qi) * 0.05;
      }

      if (this.phase === 'feedback' && qi === this.targetQuadrant) {
        // Show correct quadrant
        zoneColor = '80,180,80';
        zoneAlpha = 0.4;
      }

      ctx.beginPath();
      ctx.arc(qx, qy, 45, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${zoneColor},${zoneAlpha})`;
      ctx.fill();
      ctx.strokeStyle = `rgba(${zoneColor},${zoneAlpha + 0.15})`;
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Direction label
      ctx.font = '12px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = `rgba(232,220,200,0.4)`;
      ctx.fillText(q.label, qx, qy + 30);

      // Direction arrow
      ctx.font = '20px system-ui';
      ctx.fillStyle = `rgba(232,220,200,0.5)`;
      ctx.fillText(q.symbol, qx, qy);
    }

    // Flash symbol in target quadrant
    if (this.phase === 'flash') {
      const q = this.quadrants[this.targetQuadrant];
      const qx = this.centerX + q.cx;
      const qy = this.centerY + q.cy;

      // Flash alpha fades
      const flashProgress = 1 - (this.phaseTimer / this.flashDuration);
      const flashAlpha = flashProgress < 0.3
        ? flashProgress / 0.3
        : flashProgress > 0.7
          ? (1 - flashProgress) / 0.3
          : 1.0;

      // Glow
      const glow = ctx.createRadialGradient(qx, qy, 0, qx, qy, 50);
      glow.addColorStop(0, `rgba(205,133,63,${flashAlpha * 0.3})`);
      glow.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(qx, qy, 50, 0, Math.PI * 2);
      ctx.fill();

      // Symbol
      ctx.font = '36px serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = `rgba(255,220,150,${flashAlpha})`;
      ctx.fillText(this.flashSymbol, qx, qy - 5);
    }

    // Answer phase -- timer bar
    if (this.phase === 'answer' && !this.answered) {
      const timePct = this.phaseTimer / this.windowDuration;
      const barW = this.canvasW - 40;
      const barH = 4;
      const barY = this.canvasH - 20;

      ctx.fillStyle = 'rgba(255,255,255,0.1)';
      ctx.fillRect(20, barY, barW, barH);

      const urgency = timePct < 0.3 ? '200,60,60' : '100,80,140';
      ctx.fillStyle = `rgba(${urgency},0.7)`;
      ctx.fillRect(20, barY, barW * timePct, barH);

      // Prompt
      ctx.font = '16px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = 'rgba(232,220,200,0.7)';
      ctx.fillText('D\'ou venait l\'echo ?', this.centerX, 20);
    }

    // Click ripple effect
    if (this.rippleActive) {
      const rippleRadius = this.rippleTimer * 150;
      const rippleAlpha = Math.max(0, 0.3 - this.rippleTimer * 0.5);
      ctx.beginPath();
      ctx.arc(this.rippleX, this.rippleY, rippleRadius, 0, Math.PI * 2);
      ctx.strokeStyle = this.feedback === 'hit'
        ? `rgba(80,200,80,${rippleAlpha})`
        : `rgba(200,80,80,${rippleAlpha})`;
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // Feedback text overlay
    if (this.phase === 'feedback') {
      const fbAlpha = this.feedbackTimer / 0.5;
      ctx.font = '28px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = this.feedback === 'hit'
        ? `rgba(80,220,80,${fbAlpha})`
        : `rgba(220,80,80,${fbAlpha})`;
      ctx.fillText(
        this.feedback === 'hit' ? 'Bien entendu !' : 'Mauvaise direction',
        this.centerX, this.centerY
      );
    }

    // Score dots (bottom)
    const dotY = this.canvasH - 35;
    const dotSpacing = 28;
    const dotStartX = (this.canvasW - (this.totalRounds - 1) * dotSpacing) / 2;
    for (let i = 0; i < this.totalRounds; i++) {
      const dx = dotStartX + i * dotSpacing;
      ctx.beginPath();
      ctx.arc(dx, dotY, 6, 0, Math.PI * 2);
      if (i < this.currentRound) {
        ctx.fillStyle = 'rgba(140,130,120,0.5)';
      } else if (i === this.currentRound) {
        const cp = 0.5 + Math.sin(this.pulsePhase * 4) * 0.3;
        ctx.fillStyle = `rgba(200,170,100,${cp})`;
      } else {
        ctx.fillStyle = 'rgba(80,70,60,0.3)';
      }
      ctx.fill();
      ctx.strokeStyle = 'rgba(200,170,100,0.2)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
    super.cleanup();
  }
}
