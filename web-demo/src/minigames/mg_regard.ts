// =============================================================================
// Minigame: Regard -- Memory sequence (memorize ogham symbols, reproduce order)
// Show 4-6 symbols for 3s, hide them, player clicks in order from shuffled grid.
// 3 rounds with increasing length (4, 5, 6). Score = correct / total * 100.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable symbol cell in the grid. */
interface GridCell {
  readonly symbol: string;
  readonly gridX: number;
  readonly gridY: number;
  readonly isTarget: boolean;
  readonly targetIndex: number; // -1 if not a target
}

/** All ogham symbols used. */
const SYMBOLS: readonly string[] = [
  '\u1681', '\u1682', '\u1683', '\u1684', '\u1685',
  '\u1686', '\u1687', '\u1688', '\u1689', '\u168A',
  '\u168B', '\u168C', '\u168D', '\u168E', '\u168F',
];

function shuffle<T>(arr: readonly T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export class MinigameRegard extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private ended = false;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 360;

  // Game config
  private roundLengths: readonly number[] = [4, 5, 6]; // C126: mutable — set via tieredValue in setup()
  private showTime = 3.0;    // C100: [3.0,2.5,2.0,1.5]s to memorize
  private readonly gridCols = 5;
  private readonly gridRows = 3;
  private readonly cellSize = 60;

  // Game state
  private currentRound = 0;
  private correctTotal = 0;
  private attemptsTotal = 0;
  private phase: 'show' | 'recall' | 'feedback' | 'done' = 'show';
  private showTimer = 0;
  private feedbackTimer = 0;
  private feedbackCorrect = false;
  private sequence: readonly string[] = [];
  private grid: readonly GridCell[] = [];
  private clickedIndex = 0; // next expected index in sequence
  private clickedCells: Set<number> = new Set(); // grid indices already clicked
  private pulsePhase = 0;
  private kbFocusIdx = -1; // C136: keyboard-focused cell index (-1 = none)
  private recallTimeout = 0; // C105: per-round recall deadline — prevents softlock if player never clicks (RGD-01)
  // C120/RGD-02: cached DOM refs — was getElementById in render() (~60fps), prepareRound, onClick, onKeyDown
  private instrElRef: HTMLElement | null = null;
  private statusElRef: HTMLElement | null = null;
  private roundElRef: HTMLElement | null = null;

  protected setup(): void {
    this.container.innerHTML = '';

    // C100: difficulty scaling — less time to memorize at high tiers
    this.showTime = this.tieredValue([3.0, 2.5, 2.0, 1.5] as const);
    // C126: scale sequence length per round — more symbols to memorize at high tiers
    this.roundLengths = this.tieredValue([
      [3, 4, 5],
      [4, 5, 6],
      [4, 5, 6],
      [5, 6, 7],
    ] as const);

    // Title
    const title = document.createElement('div');
    title.textContent = 'REGARD -- Memorise la sequence';
    title.style.cssText = 'color:rgba(51,255,102,0.88);font-size:14px;text-align:center;margin-bottom:4px;font-family:Courier New,monospace;';
    this.container.appendChild(title);

    // Instruction
    const instr = document.createElement('div');
    instr.id = 'mg-regard-instr';
    instr.textContent = 'Observe les symboles dans l\'ordre, puis reproduis la sequence !';
    instr.style.cssText = 'color:rgba(51,255,102,0.50);font-size:11px;text-align:center;margin-bottom:8px;font-family:Courier New,monospace;';
    this.container.appendChild(instr);

    // Round indicator
    const roundEl = document.createElement('div');
    roundEl.id = 'mg-regard-round';
    roundEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:24px;margin:0 auto 8px;color:rgba(51,255,102,0.60);font-size:12px;text-align:center;font-family:Courier New,monospace;line-height:24px;`;
    roundEl.textContent = `Manche 1 / ${this.roundLengths.length}`;
    this.container.appendChild(roundEl);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Regard — memorisez la sequence de symboles et reproduisez-la');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,15,25,0.9);border:2px solid rgba(51,200,100,0.4);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Status
    const statusEl = document.createElement('div');
    statusEl.id = 'mg-regard-status';
    statusEl.setAttribute('aria-live', 'polite'); // C114
    statusEl.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(51,255,102,0.45);font-size:12px;text-align:center;font-family:Courier New,monospace;`;
    statusEl.textContent = 'Memorise...';
    this.container.appendChild(statusEl);
    this.instrElRef = instr;
    this.statusElRef = statusEl;
    this.roundElRef = roundEl;

    // Input
    this.canvas.addEventListener('pointerdown', this.onClick);
    // C136: WCAG 2.1.1 — ArrowKey cell focus + Enter/Space confirm for keyboard-only players
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Reset state
    this.currentRound = 0;
    this.ended = false;
    this.correctTotal = 0;
    this.attemptsTotal = 0;
    this.pulsePhase = 0;
    this.kbFocusIdx = -1;
    // C146b/RGD-BUG-01: reset feedback state — stale feedbackTimer>0 from a previous play()
    // causes the feedback phase to instant-advance on the very first rAF frame of a replay.
    this.feedbackTimer = 0;
    this.feedbackCorrect = false;

    this.prepareRound();
  }

  private prepareRound(): void {
    if (this.currentRound >= this.roundLengths.length) {
      this.endGame();
      return;
    }

    // C85: ?? fallback — TypeScript types arr[N] as number|undefined even with the
    // currentRound < roundLengths.length guard above; slice(0, undefined) returns the
    // full SYMBOLS array (15 symbols), making the round unexpectedly long if reached.
    const seqLen = this.roundLengths[this.currentRound] ?? 4;
    // Pick unique symbols for the sequence
    const shuffled = shuffle(SYMBOLS);
    this.sequence = shuffled.slice(0, seqLen);

    // Build grid: sequence symbols + fillers, shuffled into grid positions
    const totalCells = this.gridCols * this.gridRows;
    const fillerCount = totalCells - seqLen;
    const fillerSymbols: string[] = [];
    const usedSymbols = new Set(this.sequence);
    for (let i = 0; i < fillerCount; i++) {
      let s = pick(SYMBOLS);
      // Allow duplicates in fillers but try to avoid sequence symbols
      let attempts = 0;
      while (usedSymbols.has(s) && attempts < 20) {
        s = pick(SYMBOLS);
        attempts++;
      }
      fillerSymbols.push(s);
    }

    // Create cells: targets first, then fillers
    const allCells: { symbol: string; isTarget: boolean; targetIndex: number }[] = [];
    for (let i = 0; i < seqLen; i++) {
      allCells.push({ symbol: this.sequence[i], isTarget: true, targetIndex: i });
    }
    for (const fs of fillerSymbols) {
      allCells.push({ symbol: fs, isTarget: false, targetIndex: -1 });
    }

    // Shuffle positions
    const shuffledCells = shuffle(allCells);
    const gridOffsetX = (this.canvasW - this.gridCols * this.cellSize) / 2;
    const gridOffsetY = 80;

    this.grid = shuffledCells.map((cell, i) => ({
      symbol: cell.symbol,
      gridX: gridOffsetX + (i % this.gridCols) * this.cellSize + this.cellSize / 2,
      gridY: gridOffsetY + Math.floor(i / this.gridCols) * this.cellSize + this.cellSize / 2,
      isTarget: cell.isTarget,
      targetIndex: cell.targetIndex,
    }));

    this.clickedIndex = 0;
    this.clickedCells = new Set();
    this.phase = 'show';
    this.showTimer = this.showTime;

    if (this.instrElRef) this.instrElRef.textContent = `Memorise l'ordre des ${seqLen} symboles illumines !`;
    if (this.statusElRef) this.statusElRef.textContent = 'Memorise...';
  }

  private onClick = (e: PointerEvent): void => {
    if (!this.canvas || this.phase !== 'recall') return;
    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Find clicked cell
    const clickRadius = this.cellSize / 2 - 4;
    for (let i = 0; i < this.grid.length; i++) {
      if (this.clickedCells.has(i)) continue;
      const cell = this.grid[i];
      const dx = mx - cell.gridX;
      const dy = my - cell.gridY;
      if (Math.sqrt(dx * dx + dy * dy) <= clickRadius) {
        this.clickedCells.add(i);
        this.attemptsTotal++;

        if (cell.isTarget && cell.targetIndex === this.clickedIndex) {
          // Correct
          this.correctTotal++;
          this.clickedIndex++;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));

          if (this.clickedIndex >= this.sequence.length) {
            // Round complete
            clearTimeout(this.recallTimeout); // C105: cancel recall deadline (RGD-01)
            this.phase = 'feedback';
            this.feedbackCorrect = true;
            this.feedbackTimer = 0.8;
          }
        } else {
          // Wrong -- end round
          clearTimeout(this.recallTimeout); // C105: cancel recall deadline (RGD-01)
          this.phase = 'feedback';
          this.feedbackCorrect = false;
          this.feedbackTimer = 0.8;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
        }

        if (this.statusElRef) {
          this.statusElRef.textContent = `Correct: ${this.correctTotal} / ${this.attemptsTotal}`;
        }
        break;
      }
    }
  };

  // C136: WCAG 2.1.1 — keyboard cell navigation during recall phase.
  // ArrowKeys move kbFocusIdx through 5×3 grid. Enter/Space confirms the focused cell.
  private onKeyDown = (e: KeyboardEvent): void => {
    if (this.phase !== 'recall') return;
    const isArrow = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    const isConfirm = e.key === 'Enter' || e.key === ' ';
    if (!isArrow && !isConfirm) return;
    e.preventDefault();
    const total = this.gridCols * this.gridRows;
    if (isArrow) {
      const cur = this.kbFocusIdx < 0 ? 0 : this.kbFocusIdx;
      if (e.key === 'ArrowRight')     this.kbFocusIdx = Math.min(total - 1, cur + 1);
      else if (e.key === 'ArrowLeft') this.kbFocusIdx = Math.max(0, cur - 1);
      else if (e.key === 'ArrowDown') this.kbFocusIdx = Math.min(total - 1, cur + this.gridCols);
      else if (e.key === 'ArrowUp')   this.kbFocusIdx = Math.max(0, cur - this.gridCols);
    } else if (isConfirm && this.kbFocusIdx >= 0) {
      // Simulate click on the focused cell using its grid coordinates
      const cell = this.grid[this.kbFocusIdx];
      if (!cell || this.clickedCells.has(this.kbFocusIdx)) return;
      // Reuse the exact same hit-detection path as onClick (direct cell index lookup)
      this.clickedCells.add(this.kbFocusIdx);
      this.attemptsTotal++;
      if (cell.isTarget && cell.targetIndex === this.clickedIndex) {
        this.correctTotal++;
        this.clickedIndex++;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
        if (this.clickedIndex >= this.sequence.length) {
          clearTimeout(this.recallTimeout); // C105: cancel recall deadline (RGD-01)
          this.phase = 'feedback'; this.feedbackCorrect = true; this.feedbackTimer = 0.8;
        }
      } else {
        clearTimeout(this.recallTimeout); // C105: cancel recall deadline (RGD-01)
        this.phase = 'feedback'; this.feedbackCorrect = false; this.feedbackTimer = 0.8;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
      }
      if (this.statusElRef) this.statusElRef.textContent = `Correct: ${this.correctTotal} / ${this.attemptsTotal}`;
    }
  };

  protected cancelTimers(): void {
    clearTimeout(this.recallTimeout); // C105: cancel any in-flight recall deadline (RGD-01)
    cancelAnimationFrame(this.animFrame); // C102: centralised teardown
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.phase = 'done';
    this.cancelTimers(); // C102: centralised teardown

    // Score: accuracy model — correct / attempted clicks.
    // C101: previous denominator was sum-of-all-roundLengths (15), which silently included
    // symbols the player never had a chance to click after an early wrong answer in a round.
    // Example: 1 correct + fail per round → 3/15=20% (wrong) vs 3/6=50% (correct accuracy).
    const finalScore = this.attemptsTotal > 0
      ? (this.correctTotal / this.attemptsTotal) * 100
      : 0;
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C129/BUG-L-REGARD-GUARD-01: align with C106 contract (was this.phase==='done' — silent deviation from all 13 other minigames)
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.pulsePhase += dt;

    // Phase transitions
    if (this.phase === 'show') {
      this.showTimer -= dt;
      if (this.showTimer <= 0) {
        this.phase = 'recall';
        // C105: 10s recall deadline — treat expiry as wrong answer to prevent softlock (RGD-01)
        this.recallTimeout = window.setTimeout(() => {
          if (this.phase !== 'recall') return; // guard: already transitioned
          this.phase = 'feedback';
          this.feedbackCorrect = false;
          this.feedbackTimer = 0.8;
          window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
        }, 10000);
        if (this.instrElRef) this.instrElRef.textContent = 'Clique les symboles dans le bon ordre !';
        if (this.statusElRef) this.statusElRef.textContent = `Correct: ${this.correctTotal} / ${this.attemptsTotal}`;
      }
    }

    if (this.phase === 'feedback') {
      this.feedbackTimer -= dt;
      if (this.feedbackTimer <= 0) {
        this.currentRound++;
        if (this.roundElRef) {
          this.roundElRef.textContent = this.currentRound < this.roundLengths.length
            ? `Manche ${this.currentRound + 1} / ${this.roundLengths.length}`
            : 'Termine !';
        }
        if (this.currentRound >= this.roundLengths.length) {
          this.endGame();
          return;
        }
        this.prepareRound();
      }
    }

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background circles
    ctx.strokeStyle = 'rgba(51,200,100,0.06)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 5; i++) {
      ctx.beginPath();
      ctx.arc(this.canvasW / 2, this.canvasH / 2 + 20, 50 + i * 35, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Show phase: display sequence with numbered order
    if (this.phase === 'show') {
      // Show sequence order at top
      ctx.fillStyle = 'rgba(51,255,102,0.85)';
      ctx.font = '14px Courier New';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText('Sequence:', this.canvasW / 2, 8);

      const seqSpacing = 40;
      const seqStartX = (this.canvasW - (this.sequence.length - 1) * seqSpacing) / 2;
      for (let i = 0; i < this.sequence.length; i++) {
        const sx = seqStartX + i * seqSpacing;
        ctx.font = '24px Courier New';
        ctx.fillStyle = 'rgba(51,255,102,0.80)';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(this.sequence[i], sx, 46);

        // Number below
        ctx.font = '11px Courier New';
        ctx.fillStyle = 'rgba(51,255,102,0.5)';
        ctx.fillText(`${i + 1}`, sx, 64);
      }

      // Timer bar
      const timePct = this.showTimer / this.showTime;
      const barW = this.canvasW - 40;
      ctx.fillStyle = 'rgba(255,255,255,0.1)';
      ctx.fillRect(20, 72, barW, 3);
      ctx.fillStyle = 'rgba(51,255,102,0.6)';
      ctx.fillRect(20, 72, barW * timePct, 3);
    }

    // Draw grid
    for (let i = 0; i < this.grid.length; i++) {
      const cell = this.grid[i];
      const isClicked = this.clickedCells.has(i);

      // Cell background
      let bgColor = 'rgba(40,35,50,0.6)';
      if (this.phase === 'show' && cell.isTarget) {
        // Highlight targets during show phase
        const pulse = 0.4 + Math.sin(this.pulsePhase * 3 + cell.targetIndex * 0.5) * 0.2;
        bgColor = `rgba(51,200,100,${pulse})`;
      } else if (isClicked) {
        bgColor = cell.isTarget && cell.targetIndex < this.clickedIndex
          ? 'rgba(60,140,60,0.4)'
          : 'rgba(140,50,50,0.4)';
      }

      ctx.fillStyle = bgColor;
      ctx.beginPath();
      ctx.arc(cell.gridX, cell.gridY, this.cellSize / 2 - 6, 0, Math.PI * 2);
      ctx.fill();

      // Cell border — C136: amber ring on keyboard-focused cell for WCAG 2.4.7 Focus Visible
      const isKbFocus = i === this.kbFocusIdx && this.phase === 'recall';
      ctx.strokeStyle = isKbFocus
        ? 'rgba(51,255,102,0.9)'
        : this.phase === 'show' && cell.isTarget
          ? 'rgba(51,255,102,0.5)'
          : 'rgba(51,200,100,0.2)';
      ctx.lineWidth = isKbFocus ? 2.5 : 1.5;
      ctx.stroke();

      // Symbol (always visible -- player must remember ORDER not position)
      const symAlpha = isClicked ? 0.3 : 0.8;
      ctx.font = '22px Courier New';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = `rgba(51,255,102,${symAlpha})`;
      ctx.fillText(cell.symbol, cell.gridX, cell.gridY);

      // Show order number during show phase
      if (this.phase === 'show' && cell.isTarget) {
        ctx.font = '12px Courier New';
        ctx.fillStyle = 'rgba(51,255,102,0.80)';
        ctx.fillText(`${cell.targetIndex + 1}`, cell.gridX, cell.gridY + 18);
      }
    }

    // Feedback overlay
    if (this.phase === 'feedback') {
      const fbAlpha = this.feedbackTimer / 0.8;
      ctx.fillStyle = this.feedbackCorrect
        ? `rgba(60,160,60,${fbAlpha * 0.15})`
        : `rgba(180,50,50,${fbAlpha * 0.15})`;
      ctx.fillRect(0, 0, this.canvasW, this.canvasH);

      ctx.font = '28px Courier New';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = this.feedbackCorrect
        ? `rgba(80,220,80,${fbAlpha})`
        : `rgba(220,80,80,${fbAlpha})`;
      ctx.fillText(
        this.feedbackCorrect ? 'Sequence correcte !' : 'Erreur de sequence',
        this.canvasW / 2, this.canvasH / 2
      );
    }

    // Round progress dots
    const dotY = this.canvasH - 16;
    const dotSpacing = 40;
    const dotStartX = (this.canvasW - (this.roundLengths.length - 1) * dotSpacing) / 2;
    for (let i = 0; i < this.roundLengths.length; i++) {
      const dx = dotStartX + i * dotSpacing;
      ctx.beginPath();
      ctx.arc(dx, dotY, 6, 0, Math.PI * 2);
      if (i < this.currentRound) {
        ctx.fillStyle = 'rgba(140,130,120,0.5)';
      } else if (i === this.currentRound) {
        const cp = 0.5 + Math.sin(this.pulsePhase * 4) * 0.3;
        ctx.fillStyle = `rgba(51,255,102,${cp * 0.8})`;
      } else {
        ctx.fillStyle = 'rgba(80,70,60,0.3)';
      }
      ctx.fill();
      ctx.strokeStyle = 'rgba(51,255,102,0.18)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    super.cleanup(); // calls cancelTimers() — C102
  }
}
