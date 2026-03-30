// =============================================================================
// Minigame: Fouille -- Find the hidden target object among decoys
// Player must find and click the TARGET object among 15 decoys within 12s.
// Objects shuffle position every 2s. Score = early bonus if found, 0 if not.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable object descriptor placed on the canvas. */
interface PlacedObject {
  readonly label: string;
  readonly x: number;
  readonly y: number;
  readonly isTarget: boolean;
  readonly angle: number;
  readonly scale: number;
}

// Object pools for generation
const TARGET_OBJECTS = [
  'Cle Ogham', 'Bague Sacree', 'Fiole Lune', 'Sceau Druidique',
  'Plume Merlin', 'Pierre Rune', 'Collier Anam', 'Broche Cerf',
];

const DECOY_OBJECTS = [
  'Branche', 'Feuille', 'Mousse', 'Champignon', 'Caillou', 'Ecorce',
  'Racine', 'Lichen', 'Baie', 'Gland', 'Pomme Pin', 'Noix',
  'Brindille', 'Petal', 'Chardon', 'Fougere', 'Lierre', 'Noisette',
  'Houx', 'Gui', 'Ortie', 'Ajonc', 'Geneve', 'Sureau',
];

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffle<T>(arr: readonly T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export class MinigameFouille extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;

  // Canvas dimensions
  private readonly canvasW = 420;
  private readonly canvasH = 380;

  // Game config
  private readonly totalTime = 12;
  private readonly decoyCount = 15;
  private readonly shuffleInterval = 2; // seconds between shuffles

  // Game state
  private objects: PlacedObject[] = [];
  private targetLabel = '';
  private timeLeft = 12;
  private elapsedTime = 0;
  private found = false;
  private clickedWrong = false;
  private wrongClickTimer = 0;
  private nextShuffle = 2;
  private pulsePhase = 0;
  private hoverIndex = -1;
  private cursorX = 0;
  private cursorY = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // Pick target
    this.targetLabel = pick(TARGET_OBJECTS);

    // Title
    const title = document.createElement('div');
    title.textContent = 'FOUILLE -- Trouve l\'objet cache';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Instruction with target name
    const instr = document.createElement('div');
    instr.id = 'mg-fouille-instr';
    instr.textContent = `Cherche : ${this.targetLabel}`;
    instr.style.cssText = 'color:#cd853f;font-size:15px;text-align:center;margin-bottom:8px;font-family:system-ui;font-weight:bold;';
    this.container.appendChild(instr);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-fouille-timer';
    timerBar.style.cssText = `width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-fouille-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#2e6b4f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,20,15,0.9);border:2px solid rgba(46,107,79,0.4);cursor:pointer;display:block;margin:0 auto;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-fouille-status';
    statusEl.style.cssText = `width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:13px;text-align:center;font-family:system-ui;`;
    statusEl.textContent = 'Clique sur l\'objet cible...';
    this.container.appendChild(statusEl);

    // Generate objects
    this.generateObjects();

    // Input
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    this.canvas.addEventListener('pointerdown', this.onClick);

    // Reset state
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.found = false;
    this.clickedWrong = false;
    this.wrongClickTimer = 0;
    this.nextShuffle = this.shuffleInterval;
    this.pulsePhase = 0;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-fouille-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private generateObjects(): void {
    const objects: PlacedObject[] = [];
    const usedDecoys = shuffle(DECOY_OBJECTS).slice(0, this.decoyCount);

    // Place all labels (target + decoys)
    const allLabels = shuffle([this.targetLabel, ...usedDecoys]);
    const cols = 4;
    const rows = Math.ceil(allLabels.length / cols);
    const cellW = this.canvasW / cols;
    const cellH = this.canvasH / rows;

    for (let i = 0; i < allLabels.length; i++) {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const jitterX = (Math.random() - 0.5) * cellW * 0.5;
      const jitterY = (Math.random() - 0.5) * cellH * 0.4;
      objects.push({
        label: allLabels[i],
        x: cellW * (col + 0.5) + jitterX,
        y: cellH * (row + 0.5) + jitterY,
        isTarget: allLabels[i] === this.targetLabel,
        angle: (Math.random() - 0.5) * 0.3,
        scale: 0.85 + Math.random() * 0.3,
      });
    }

    this.objects = objects;
  }

  private onPointerMove = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    this.cursorX = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    this.cursorY = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Hit test
    this.hoverIndex = this.hitTest(this.cursorX, this.cursorY);
  };

  private onClick = (e: PointerEvent): void => {
    if (this.found) return;
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    const idx = this.hitTest(mx, my);
    if (idx < 0) return;

    const obj = this.objects[idx];
    if (obj.isTarget) {
      this.found = true;
      const statusEl = document.getElementById('mg-fouille-status');
      if (statusEl) statusEl.textContent = 'Trouve !';
      // Short delay before ending to show the found state
      setTimeout(() => this.endGame(), 400);
    } else {
      this.clickedWrong = true;
      this.wrongClickTimer = 0.5;
    }
  };

  private hitTest(mx: number, my: number): number {
    // Check each object bounding box (text-based, approximate)
    for (let i = 0; i < this.objects.length; i++) {
      const obj = this.objects[i];
      const textW = obj.label.length * 7 * obj.scale;
      const textH = 14 * obj.scale;
      if (mx >= obj.x - textW / 2 - 6 && mx <= obj.x + textW / 2 + 6 &&
          my >= obj.y - textH / 2 - 4 && my <= obj.y + textH / 2 + 4) {
        return i;
      }
    }
    return -1;
  }

  private endGame(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onClick);

    let score = 0;
    if (this.found) {
      // Bonus for finding early: 100 at t=0, 50 at t=totalTime
      const timePct = Math.max(0, this.timeLeft / this.totalTime);
      score = 50 + timePct * 50;
    }
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = 1 / 60;
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Wrong click feedback countdown
    if (this.wrongClickTimer > 0) {
      this.wrongClickTimer -= dt;
      if (this.wrongClickTimer <= 0) {
        this.clickedWrong = false;
      }
    }

    // Shuffle timer
    if (!this.found) {
      this.nextShuffle -= dt;
      if (this.nextShuffle <= 0) {
        this.generateObjects();
        this.nextShuffle = this.shuffleInterval;
      }
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background texture (scattered dots like forest floor)
    ctx.fillStyle = 'rgba(46,107,79,0.03)';
    for (let i = 0; i < 60; i++) {
      const bx = ((i * 73 + 17) % this.canvasW);
      const by = ((i * 47 + 31) % this.canvasH);
      ctx.beginPath();
      ctx.arc(bx, by, 2, 0, Math.PI * 2);
      ctx.fill();
    }

    // Draw objects
    for (let i = 0; i < this.objects.length; i++) {
      const obj = this.objects[i];
      const isHover = i === this.hoverIndex;

      ctx.save();
      ctx.translate(obj.x, obj.y);
      ctx.rotate(obj.angle);
      ctx.scale(obj.scale, obj.scale);

      // Background pill
      const tw = obj.label.length * 7 + 12;
      const th = 20;
      ctx.fillStyle = this.found && obj.isTarget
        ? 'rgba(80,180,80,0.4)'
        : isHover
          ? 'rgba(205,133,63,0.25)'
          : 'rgba(255,255,255,0.06)';
      ctx.beginPath();
      ctx.roundRect(-tw / 2, -th / 2, tw, th, 4);
      ctx.fill();

      if (isHover) {
        ctx.strokeStyle = 'rgba(205,133,63,0.5)';
        ctx.lineWidth = 1;
        ctx.stroke();
      }

      // Text
      ctx.font = '12px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      if (this.found && obj.isTarget) {
        ctx.fillStyle = '#80e080';
        const glow = 0.5 + Math.sin(this.pulsePhase * 6) * 0.3;
        ctx.shadowColor = `rgba(80,220,80,${glow})`;
        ctx.shadowBlur = 8;
      } else if (obj.isTarget) {
        // Target blends with decoys (same color as decoys)
        ctx.fillStyle = isHover ? '#e8dcc8' : 'rgba(232,220,200,0.65)';
      } else {
        ctx.fillStyle = isHover ? '#e8dcc8' : 'rgba(232,220,200,0.55)';
      }

      ctx.fillText(obj.label, 0, 1);
      ctx.shadowBlur = 0;
      ctx.restore();
    }

    // Wrong click flash
    if (this.clickedWrong) {
      ctx.fillStyle = `rgba(180,40,40,${0.15 * (this.wrongClickTimer / 0.5)})`;
      ctx.fillRect(0, 0, this.canvasW, this.canvasH);
    }

    // Shuffle warning (flash when about to shuffle)
    if (this.nextShuffle < 0.5 && !this.found) {
      const flash = Math.sin(this.pulsePhase * 12) * 0.5 + 0.5;
      ctx.fillStyle = `rgba(205,133,63,${flash * 0.08})`;
      ctx.fillRect(0, 0, this.canvasW, this.canvasH);
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointermove', this.onPointerMove);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    super.cleanup();
  }
}
