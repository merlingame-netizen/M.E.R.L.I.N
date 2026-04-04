// =============================================================================
// Minigame: Herboristerie -- Identify the right plant among toxic ones
// The player sees a grid of plant icons. One target plant is shown at the top.
// They must click all instances of the target plant while avoiding toxic ones.
// Score based on correct picks vs total picks and time remaining.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable plant descriptor. */
interface Plant {
  readonly emoji: string;
  readonly name: string;
  readonly isTarget: boolean;
  readonly isToxic: boolean;
}

/** Immutable grid cell state. */
interface CellState {
  readonly plant: Plant;
  readonly picked: boolean;
  readonly correct: boolean | null; // null = not yet picked
}

// Plant pool (curated for celtic herboristerie feel)
// C92-P1: append U+FE0E (VS-15) to force text-presentation on glyphs that may
// render as color emoji on Android canvas (☘ U+2618, ☠ U+2620, ⚙ U+2699).
// U+2740 ❀ U+2741 ✁ U+2736 ✶ U+273F ✿ U+2698 ⚘ are Misc Symbols — text-only by default.
const VS15 = '\uFE0E';
const PLANT_SETS: readonly {
  readonly target: { emoji: string; name: string };
  readonly safe: readonly { emoji: string; name: string }[];
  readonly toxic: readonly { emoji: string; name: string }[];
}[] = [
  {
    target: { emoji: '\u2618' + VS15, name: 'Trefle' },   // ☘︎ shamrock (force text)
    safe: [
      { emoji: '\u2740', name: 'Fleur blanche' },
      { emoji: '\u2741', name: 'Petale' },
    ],
    toxic: [
      { emoji: '\u2620' + VS15, name: 'Morelle noire' },  // ☠︎ skull (force text)
      { emoji: '\u2736', name: 'Epine toxique' },
    ],
  },
  {
    target: { emoji: '\u273F', name: 'Gui sacre' },
    safe: [
      { emoji: '\u2740', name: 'Mousse' },
      { emoji: '\u2698', name: 'Alchimille' },
    ],
    toxic: [
      { emoji: '\u2620' + VS15, name: 'Aconit' },         // ☠︎ skull (force text)
      { emoji: '\u2736', name: 'Belladone' },
    ],
  },
  {
    target: { emoji: '\u2699' + VS15, name: 'Verveine' }, // ⚙︎ gear (force text)
    safe: [
      { emoji: '\u2741', name: 'Sauge' },
      { emoji: '\u2618' + VS15, name: 'Trefle' },          // ☘︎ shamrock (force text)
    ],
    toxic: [
      { emoji: '\u2620' + VS15, name: 'Cigue' },           // ☠︎ skull (force text)
      { emoji: '\u2736', name: 'Digitale' },
    ],
  },
  // C98: two additional sets for variety (prevents memorisation after 3 runs)
  {
    target: { emoji: '\u2698', name: 'Millepertuis' },    // ⚘ flower — text by default
    safe: [
      { emoji: '\u2740', name: 'Bruyere' },
      { emoji: '\u273F', name: 'Lavande' },
    ],
    toxic: [
      { emoji: '\u2620' + VS15, name: 'Datura' },          // ☠︎
      { emoji: '\u2736', name: 'Jusquiame' },
    ],
  },
  {
    target: { emoji: '\u2741', name: 'Menthe sauvage' },  // ✁ — text by default
    safe: [
      { emoji: '\u2698', name: 'Achillee' },
      { emoji: '\u273F', name: 'Valerian' },
    ],
    toxic: [
      { emoji: '\u2620' + VS15, name: 'Colchique' },       // ☠︎
      { emoji: '\u2736', name: 'Elleborine' },
    ],
  },
];

export class MinigameHerboristerie extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private ended = false;
  private timerInterval = 0;
  private endTimeout = 0; // C114: stored so cleanup() can cancel if player exits within 300ms delay

  // Grid config
  private readonly gridCols = 5;
  private readonly gridRows = 4;
  private readonly cellSize = 64;
  private readonly canvasW = 5 * 64 + 40; // 360
  private readonly canvasH = 4 * 64 + 100; // 356

  // Game state
  private cells: CellState[] = [];
  private targetPlant: { emoji: string; name: string } = { emoji: '', name: '' };
  private timeLeft = 15;
  private totalTime = 15;    // C94: scaled by difficultyTier in setup()
  private wrongPenalty = 5; // C115: pts deducted per wrong pick — tieredValue-scaled in setup()
  private correctPicks = 0;
  private wrongPicks = 0;
  private totalTargets = 0;
  private elapsedTime = 0;

  // Visual feedback
  private flashCells: Map<number, { color: string; alpha: number }> = new Map();
  private shakeAmount = 0;
  // C92-P2: floating penalty text — shows "−8 pts" near wrong pick for 0.8s
  private penaltyToasts: Array<{ x: number; y: number; life: number }> = [];
  // C96: keyboard navigation — tracks selected cell (keyCol=-1 means inactive)
  private keyCol = -1;
  private keyRow = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // C106: tieredValue replaces manual arithmetic — consistent with all other minigames
    this.totalTime    = this.tieredValue([15, 13, 11, 9] as const);
    // C115: penalty scales with tier — easier tiers use 5pts to avoid discouraging beginners
    this.wrongPenalty = this.tieredValue([5, 6, 7, 8] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'HERBORISTERIE -- Trouve les bonnes plantes';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // C97: instruction — target name set after buildGrid() populates targetPlant
    const instrEl = document.createElement('div');
    instrEl.id = 'mg-herb-instr';
    instrEl.style.cssText = 'color:#cd853f;font-size:13px;text-align:center;margin-bottom:6px;font-family:system-ui;';
    instrEl.textContent = `Cherche la bonne plante — Évite les toxiques (−${this.wrongPenalty} pts)`; // C135: use tieredValue not hardcoded 8
    this.container.appendChild(instrEl);

    // Timer bar — responsive
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-herb-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-herb-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#5a9a5a;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    // aria-label set after buildGrid() below — targetPlant.name is populated there.
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(20,25,15,0.85);border:1px solid rgba(90,154,90,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Build grid — populates this.targetPlant before aria-label is set
    this.buildGrid();
    this.canvas.setAttribute('aria-label', `Herboristerie — cliquez sur les plantes ${this.targetPlant.name || ''} et évitez les plantes toxiques`);
    // C97: update instruction with actual target name
    instrEl.textContent = `Cible : ${this.targetPlant.name} — Évite les toxiques (−${this.wrongPenalty} pts)`; // C135

    // Input
    this.canvas.addEventListener('pointerdown', this.onPointerDown);
    // C96: keyboard cell navigation — arrow keys move selection, Enter/Space picks
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.timeLeft = this.totalTime;
    this.correctPicks = 0;
    this.ended = false;
    this.wrongPicks = 0;
    this.elapsedTime = 0;
    this.flashCells = new Map();
    this.shakeAmount = 0;
    this.penaltyToasts = [];
    this.keyCol = -1;
    this.keyRow = 0;

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      this.checkCriticalAlert(this.timeLeft); // C101: fire critical_alert SFX once at 3s
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-herb-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-herb-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private buildGrid(): void {
    // Pick a random plant set
    const setIndex = Math.floor(Math.random() * PLANT_SETS.length);
    const plantSet = PLANT_SETS[setIndex];
    this.targetPlant = plantSet.target;

    const totalCells = this.gridCols * this.gridRows;

    // Distribute: ~30% target, ~40% safe, ~30% toxic
    const targetCount = Math.max(4, Math.floor(totalCells * 0.3));
    const toxicCount = Math.max(3, Math.floor(totalCells * 0.25));
    const safeCount = totalCells - targetCount - toxicCount;

    this.totalTargets = targetCount;

    const plants: Plant[] = [];

    // Add targets
    for (let i = 0; i < targetCount; i++) {
      plants.push({
        emoji: plantSet.target.emoji,
        name: plantSet.target.name,
        isTarget: true,
        isToxic: false,
      });
    }

    // Add safe (non-target)
    for (let i = 0; i < safeCount; i++) {
      const safe = plantSet.safe[i % plantSet.safe.length];
      plants.push({
        emoji: safe.emoji,
        name: safe.name,
        isTarget: false,
        isToxic: false,
      });
    }

    // Add toxic
    for (let i = 0; i < toxicCount; i++) {
      const toxic = plantSet.toxic[i % plantSet.toxic.length];
      plants.push({
        emoji: toxic.emoji,
        name: toxic.name,
        isTarget: false,
        isToxic: true,
      });
    }

    // Shuffle (Fisher-Yates)
    for (let i = plants.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = plants[i];
      plants[i] = plants[j];
      plants[j] = temp;
    }

    this.cells = plants.map((plant) => ({
      plant,
      picked: false,
      correct: null,
    }));
  }

  private getCellAt(px: number, py: number): number | null {
    const offsetX = 20;
    const offsetY = 60; // space for target indicator at top
    const col = Math.floor((px - offsetX) / this.cellSize);
    const row = Math.floor((py - offsetY) / this.cellSize);
    if (col < 0 || col >= this.gridCols || row < 0 || row >= this.gridRows) return null;
    return row * this.gridCols + col;
  }

  private pickCellByIdx(idx: number): void {
    if (idx < 0 || idx >= this.cells.length) return;
    const cell = this.cells[idx];
    if (!cell || cell.picked) return;

    const isCorrect = cell.plant.isTarget;
    this.cells = this.cells.map((c, i) =>
      i === idx ? { ...c, picked: true, correct: isCorrect } : c
    );

    if (isCorrect) {
      this.correctPicks++;
      this.flashCells.set(idx, { color: 'rgba(90,180,90,0.6)', alpha: 1 });
      // C97: audio feedback — correct pick
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else {
      this.wrongPicks++;
      this.flashCells.set(idx, { color: 'rgba(200,60,60,0.6)', alpha: 1 });
      // C97: audio feedback — wrong pick
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
      this.shakeAmount = 6;
      const col = idx % this.gridCols;
      const row = Math.floor(idx / this.gridCols);
      this.penaltyToasts.push({ x: 20 + col * this.cellSize + this.cellSize / 2, y: 60 + row * this.cellSize + this.cellSize / 2, life: 0.8 });
    }

    if (this.correctPicks >= this.totalTargets) {
      this.endTimeout = window.setTimeout(() => this.endGame(), 300); // C114: store handle for cleanup()
    }
  }

  private onPointerDown = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const y = (e.clientY - rect.top) * (this.canvas.height / rect.height);
    const idx = this.getCellAt(x, y);
    if (idx !== null) this.pickCellByIdx(idx);
  };

  // C96: keyboard navigation — arrow keys move selection, Enter/Space picks selected cell
  private onKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'ArrowLeft')  { e.preventDefault(); this.keyCol = this.keyCol < 0 ? 0 : Math.max(0, this.keyCol - 1); }
    else if (e.key === 'ArrowRight') { e.preventDefault(); this.keyCol = Math.min(this.gridCols - 1, Math.max(0, this.keyCol) + 1); }
    else if (e.key === 'ArrowUp')    { e.preventDefault(); this.keyRow = this.keyRow < 0 ? 0 : Math.max(0, this.keyRow - 1); if (this.keyCol < 0) this.keyCol = 0; }
    else if (e.key === 'ArrowDown')  { e.preventDefault(); this.keyRow = Math.min(this.gridRows - 1, Math.max(0, this.keyRow) + 1); if (this.keyCol < 0) this.keyCol = 0; }
    else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      if (this.keyCol >= 0) this.pickCellByIdx(this.keyRow * this.gridCols + this.keyCol);
    }
  };

  protected cancelTimers(): void {
    clearTimeout(this.endTimeout); // C102: C114 cancel pending 300ms delay
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.cancelTimers(); // C102: centralised teardown

    // Score formula:
    // - Base: (correctPicks / totalTargets) * 80
    // - Penalty: wrongPicks * 8 (each wrong pick costs 8 points)
    // - Time bonus: up to +20 if finished quickly
    const pickRatio = this.totalTargets > 0 ? this.correctPicks / this.totalTargets : 0;
    const baseScore = pickRatio * 80;
    const penalty = this.wrongPicks * this.wrongPenalty; // C115: tieredValue-scaled
    const timeBonus = this.timeLeft > 0 ? (this.timeLeft / this.totalTime) * 20 : 0;
    const score = Math.max(0, baseScore - penalty + timeBonus);

    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C106: ended guard — prevents zombie rAF if endGame() fires before requestAnimationFrame at bottom of render()
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;

    // Decay shake
    this.shakeAmount *= 0.85;
    if (this.shakeAmount < 0.5) this.shakeAmount = 0;

    // Decay flash cells
    for (const [idx, flash] of this.flashCells.entries()) {
      const newAlpha = flash.alpha - dt * 2;
      if (newAlpha <= 0) {
        this.flashCells.delete(idx);
      } else {
        this.flashCells.set(idx, { ...flash, alpha: newAlpha });
      }
    }

    ctx.save();

    // Apply shake
    if (this.shakeAmount > 0) {
      const sx = (Math.random() - 0.5) * this.shakeAmount;
      const sy = (Math.random() - 0.5) * this.shakeAmount;
      ctx.translate(sx, sy);
    }

    // Clear
    ctx.clearRect(-10, -10, this.canvasW + 20, this.canvasH + 20);

    // Background
    const bgGrad = ctx.createLinearGradient(0, 0, 0, this.canvasH);
    bgGrad.addColorStop(0, 'rgba(15,25,10,0.95)');
    bgGrad.addColorStop(1, 'rgba(20,30,15,0.9)');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, this.canvasW, this.canvasH);

    // Target indicator at top
    ctx.fillStyle = 'rgba(232,220,200,0.7)';
    ctx.font = '14px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Cherche:', this.canvasW / 2 - 40, 25);

    ctx.font = '28px system-ui';
    ctx.fillText(this.targetPlant.emoji, this.canvasW / 2 + 10, 25);

    ctx.font = '13px system-ui';
    ctx.fillStyle = 'rgba(205,133,63,0.6)';
    ctx.fillText(this.targetPlant.name, this.canvasW / 2 + 50, 25);

    // Score display
    ctx.fillStyle = 'rgba(232,220,200,0.6)';
    ctx.font = '12px system-ui';
    ctx.textAlign = 'right';
    ctx.fillText(`${this.correctPicks}/${this.totalTargets}`, this.canvasW - 12, 20);

    // Draw grid
    const offsetX = 20;
    const offsetY = 60;

    for (let i = 0; i < this.cells.length; i++) {
      const cell = this.cells[i];
      const col = i % this.gridCols;
      const row = Math.floor(i / this.gridCols);
      const x = offsetX + col * this.cellSize;
      const y = offsetY + row * this.cellSize;

      // Cell background
      if (cell.picked) {
        if (cell.correct) {
          ctx.fillStyle = 'rgba(46,107,46,0.3)';
        } else {
          ctx.fillStyle = 'rgba(139,50,50,0.3)';
        }
      } else {
        // Subtle hover hint with breathing animation
        const breath = 0.03 + Math.sin(this.elapsedTime * 2 + i * 0.5) * 0.02;
        ctx.fillStyle = `rgba(90,130,70,${breath})`;
      }
      ctx.fillRect(x + 2, y + 2, this.cellSize - 4, this.cellSize - 4);

      // Cell border (C96: keyboard selected cell gets bright outline)
      const isKeySelected = (col === this.keyCol && row === this.keyRow);
      ctx.strokeStyle = isKeySelected
        ? `rgba(255,220,120,${0.7 + Math.sin(this.elapsedTime * 6) * 0.3})`
        : cell.picked
          ? (cell.correct ? 'rgba(90,180,90,0.4)' : 'rgba(200,80,80,0.4)')
          : 'rgba(90,130,70,0.15)';
      ctx.lineWidth = isKeySelected ? 2 : 1;
      ctx.strokeRect(x + 2, y + 2, this.cellSize - 4, this.cellSize - 4);

      // Flash overlay
      const flash = this.flashCells.get(i);
      if (flash) {
        ctx.fillStyle = flash.color.replace('0.6', `${flash.alpha * 0.6}`);
        ctx.fillRect(x + 2, y + 2, this.cellSize - 4, this.cellSize - 4);
      }

      // Plant emoji
      if (!cell.picked || cell.correct) {
        ctx.font = '28px system-ui';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = cell.picked ? 'rgba(232,220,200,0.4)' : 'rgba(232,220,200,0.9)';
        ctx.fillText(cell.plant.emoji, x + this.cellSize / 2, y + this.cellSize / 2);
      } else {
        // Wrong pick: show X
        ctx.font = 'bold 24px system-ui';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = 'rgba(200,80,80,0.6)';
        ctx.fillText('\u2717', x + this.cellSize / 2, y + this.cellSize / 2);
      }
    }

    // C92-P2: render floating penalty toasts (C119/HRB-01: immutable decay — was mutating t.life in-place)
    // Decay + filter first (immutable map→filter), then render survivors
    this.penaltyToasts = this.penaltyToasts
      .map((t) => ({ ...t, life: t.life - dt }))
      .filter((t) => t.life > 0);
    for (const t of this.penaltyToasts) {
      const alpha = Math.min(1, t.life / 0.4);
      const rise = (0.8 - t.life) * 30; // float up 30px over lifetime
      ctx.fillStyle = `rgba(220,80,80,${alpha})`;
      ctx.font = 'bold 14px system-ui';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`\u2212${this.wrongPenalty} pts`, t.x, t.y - rise); // C136: tieredValue not hardcoded 8
    }

    ctx.restore();

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    super.cleanup(); // calls cancelTimers() — C102
  }
}
