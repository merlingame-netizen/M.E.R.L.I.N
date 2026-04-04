// =============================================================================
// Minigame: Runes -- Decipher ogham symbols by matching pairs
// The player sees ogham runes on stone tiles and must click matching pairs
// before time runs out. Score based on pairs found + time remaining.
// =============================================================================

import { MinigameBase } from './MinigameBase';

interface RuneTile {
  readonly x: number;
  readonly y: number;
  readonly runeIndex: number;
  readonly symbol: string;
  readonly label: string;
  state: 'hidden' | 'revealed' | 'matched';
}

// Ogham rune set (unicode + tree name)
const RUNE_SET: readonly { symbol: string; label: string }[] = [
  { symbol: '\u1681', label: 'Beith' },
  { symbol: '\u1682', label: 'Luis' },
  { symbol: '\u1683', label: 'Fearn' },
  { symbol: '\u1684', label: 'Nuin' },
  { symbol: '\u1685', label: 'Coll' },
  { symbol: '\u1686', label: 'Huath' },
  { symbol: '\u1687', label: 'Duir' },
  { symbol: '\u1688', label: 'Tinne' },
];

export class MinigameRunes extends MinigameBase {
  private tiles: RuneTile[] = [];
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private timerInterval = 0;
  private timeLeft = 30;
  private totalTime = 30;    // C103: tieredValue [30,25,20,15]s in setup()
  private flipBackDelay = 600; // C103: tieredValue [600,550,500,450]ms in setup()
  private readonly gridCols = 4;
  private gridRows = 4;          // C116: mutable — set from tieredValue([3,4,4,4]) in setup()
  private readonly tileSize = 80;
  private readonly tilePad = 12;
  private firstPick: number | null = null;
  private lockInput = false;
  private matchedCount = 0;
  private totalPairs = 8;        // C116: mutable — tieredValue([6,7,8,8]); RUNE_SET has exactly 8
  private animFrame = 0;
  private revealTimeout = 0;
  private ended = false;
  private kbFocusIdx = 0; // C137: keyboard-focused tile index (ArrowKey grid nav)
  // C120/RUN-01: cached DOM refs — was getElementById every 100ms setInterval
  private timerFillEl: HTMLElement | null = null;
  private timerBarEl: HTMLElement | null = null;

  protected setup(): void {
    clearTimeout(this.revealTimeout); // C102: cancel any in-flight flip-back timer on re-play
    this.container.innerHTML = '';

    // C103: tieredValue replaces manual arithmetic — consistent with all other minigames
    this.totalTime     = this.tieredValue([30, 25, 20, 15] as const);
    this.flipBackDelay = this.tieredValue([600, 550, 500, 450] as const);
    // C116: pair count scales with tier. C120/RUN-02: tier 1 was 7 pairs → 14 tiles in 16-slot grid
    // → 2 empty cells in last row + ArrowDown focus drift (RUN-KB-02). Fixed: 6→8→8→8.
    // RUNE_SET has exactly 8 entries — pairCount must stay ≤ 8.
    this.totalPairs = this.tieredValue([6, 8, 8, 8] as const);
    this.gridRows   = Math.ceil((this.totalPairs * 2) / this.gridCols); // 3 rows for 6 pairs, 4 for 7-8

    // Title
    const title = document.createElement('div');
    title.textContent = 'RUNES -- Trouve les paires d\'oghams';
    title.style.cssText = 'color:rgba(51,255,102,0.88);font-size:14px;text-align:center;margin-bottom:16px;font-family:Courier New,monospace;';
    this.container.appendChild(title);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-runes-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = 'width:min(380px,100%);height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 16px;overflow:hidden;';
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-runes-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#cd853f;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    const canvasWidth = this.gridCols * (this.tileSize + this.tilePad) + this.tilePad;
    const canvasHeight = this.gridRows * (this.tileSize + this.tilePad) + this.tilePad;

    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Runes Oghams — cliquez les paires de runes identiques avant la fin du temps');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = canvasWidth;
    this.canvas.height = canvasHeight;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(20,20,30,0.8);border:1px solid rgba(205,133,63,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Generate tiles: 8 pairs = 16 tiles in a 4x4 grid
    this.generateTiles();

    this.timerFillEl = timerFill;
    this.timerBarEl = timerBar;

    // pointerdown covers mouse, touch and stylus — no 'click' needed (avoids double-fire on desktop)
    this.canvas.addEventListener('pointerdown', this.onClick);
    // C137: WCAG 2.1.1 — ArrowKey grid navigation + Enter/Space to flip tile
    this.canvas.addEventListener('keydown', this.onKeyDown);

    // Timer
    this.timeLeft = this.totalTime;
    this.matchedCount = 0;
    this.firstPick = null;
    this.lockInput = false;
    this.ended = false;
    this.kbFocusIdx = -1; // C105: -1 = no initial focus ring (was 0 — showed amber ring on tile 0 before any keypress, RUN-03)

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

  private generateTiles(): void {
    // Create pairs: pick 8 runes, duplicate each
    const indices: number[] = [];
    for (let i = 0; i < this.totalPairs; i++) {
      indices.push(i, i);
    }
    // Shuffle (Fisher-Yates)
    for (let i = indices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = indices[i];
      indices[i] = indices[j];
      indices[j] = tmp;
    }

    // C116: only place totalPairs*2 tiles — when pairCount < 8, last row may have empty slots
    this.tiles = [];
    let placed = 0;
    const totalTiles = this.totalPairs * 2;
    outer: for (let row = 0; row < this.gridRows; row++) {
      for (let col = 0; col < this.gridCols; col++) {
        if (placed >= totalTiles) break outer;
        const runeIndex = indices[placed]!;
        const rune = RUNE_SET[runeIndex]!;
        this.tiles.push({
          x: this.tilePad + col * (this.tileSize + this.tilePad),
          y: this.tilePad + row * (this.tileSize + this.tilePad),
          runeIndex,
          symbol: rune.symbol,
          label: rune.label,
          state: 'hidden',
        });
        placed++;
      }
    }
  }

  private onClick = (e: PointerEvent): void => { // C106: PointerEvent — matches pointerdown listener
    if (this.lockInput || !this.canvas) return;

    const rect = this.canvas.getBoundingClientRect();
    const mx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const my = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    // Find which tile was clicked
    const clickedIndex = this.tiles.findIndex(
      (t) => t.state === 'hidden' && mx >= t.x && mx <= t.x + this.tileSize && my >= t.y && my <= t.y + this.tileSize
    );

    if (clickedIndex === -1) return;

    const tile = this.tiles[clickedIndex];
    // Mutate state (tiles are mutable game state, not shared data)
    (tile as { state: string }).state = 'revealed';

    if (this.firstPick === null) {
      // First pick
      this.firstPick = clickedIndex;
    } else {
      // Second pick -- check match
      const firstTile = this.tiles[this.firstPick];
      this.lockInput = true;

      if (firstTile.runeIndex === tile.runeIndex) {
        // Match found
        (firstTile as { state: string }).state = 'matched';
        (tile as { state: string }).state = 'matched';
        this.matchedCount++;
        this.firstPick = null;
        this.lockInput = false;
        // C98: audio feedback — pair matched
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));

        if (this.matchedCount >= this.totalPairs) {
          this.endGame();
        }
      } else {
        // No match -- flip back after delay
        // C98: audio feedback — mismatch
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
        const fp = this.firstPick;
        this.revealTimeout = window.setTimeout(() => {
          (this.tiles[fp] as { state: string }).state = 'hidden';
          (tile as { state: string }).state = 'hidden';
          this.firstPick = null;
          this.lockInput = false;
        }, this.flipBackDelay); // C103: tier-scaled [600,550,500,450]ms
      }
    }
  };

  // C137: WCAG 2.1.1 — ArrowKey 4-column grid navigation + Enter/Space to flip tile
  private onKeyDown = (e: KeyboardEvent): void => {
    const isArrow = e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown';
    const isConfirm = e.key === 'Enter' || e.key === ' ';
    if (!isArrow && !isConfirm) return;
    e.preventDefault();

    if (isArrow) {
      const maxIdx = this.tiles.length - 1;
      if (e.key === 'ArrowRight')     this.kbFocusIdx = Math.min(maxIdx, this.kbFocusIdx + 1);
      else if (e.key === 'ArrowLeft') this.kbFocusIdx = Math.max(0, this.kbFocusIdx - 1);
      else if (e.key === 'ArrowDown') this.kbFocusIdx = Math.min(maxIdx, this.kbFocusIdx + this.gridCols);
      else if (e.key === 'ArrowUp')   this.kbFocusIdx = Math.max(0, this.kbFocusIdx - this.gridCols);
      return;
    }

    // Confirm (Enter / Space) — same logic as onClick
    if (this.lockInput) return;
    const tile = this.tiles[this.kbFocusIdx];
    if (!tile || tile.state !== 'hidden') return;
    (tile as { state: string }).state = 'revealed';

    if (this.firstPick === null) {
      this.firstPick = this.kbFocusIdx;
    } else {
      const firstTile = this.tiles[this.firstPick];
      this.lockInput = true;

      if (firstTile.runeIndex === tile.runeIndex) {
        (firstTile as { state: string }).state = 'matched';
        (tile as { state: string }).state = 'matched';
        this.matchedCount++;
        this.firstPick = null;
        this.lockInput = false;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
        if (this.matchedCount >= this.totalPairs) {
          this.endGame();
        }
      } else {
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
        const fp = this.firstPick;
        this.revealTimeout = window.setTimeout(() => {
          (this.tiles[fp] as { state: string }).state = 'hidden';
          (tile as { state: string }).state = 'hidden';
          this.firstPick = null;
          this.lockInput = false;
        }, this.flipBackDelay);
      }
    }
  };

  protected cancelTimers(): void {
    clearInterval(this.timerInterval); // C102: centralised teardown
    clearTimeout(this.revealTimeout);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.kbFocusIdx = -1; // C51: clear focus ring before final rAF may fire
    this.cancelTimers(); // C102: centralised teardown

    // Score: base on pairs found + time bonus
    const pairScore = (this.matchedCount / this.totalPairs) * 70;
    const timeBonus = Math.max(0, this.timeLeft / this.totalTime) * 30;
    const score = pairScore + timeBonus;
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C105: ended guard prevents zombie rAF after cancelAnimationFrame (RUN-01)
    const ctx = this.ctx;

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    for (let i = 0; i < this.tiles.length; i++) {
      const tile = this.tiles[i]!;
      ctx.save();

      if (tile.state === 'hidden') {
        // Stone tile back
        ctx.fillStyle = 'rgba(80,75,65,0.7)';
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.fill();

        // Question mark
        ctx.fillStyle = 'rgba(205,133,63,0.4)';
        ctx.font = 'bold 28px Courier New';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('?', tile.x + this.tileSize / 2, tile.y + this.tileSize / 2);

      } else if (tile.state === 'revealed') {
        // Revealed -- show rune on lighter stone
        ctx.fillStyle = 'rgba(100,90,75,0.9)';
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.fill();
        ctx.strokeStyle = 'rgba(205,133,63,0.6)';
        ctx.lineWidth = 2;
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.stroke();

        // Ogham symbol
        ctx.fillStyle = 'rgba(51,255,102,0.85)';
        ctx.font = '32px Courier New';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(tile.symbol, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 - 8);

        // Label
        ctx.fillStyle = 'rgba(205,133,63,0.8)';
        ctx.font = '11px Courier New';
        ctx.fillText(tile.label, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 + 18);

      } else {
        // Matched -- green glow
        ctx.fillStyle = 'rgba(46,107,46,0.5)';
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.fill();
        ctx.strokeStyle = 'rgba(100,200,100,0.4)';
        ctx.lineWidth = 2;
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.stroke();

        // Ogham symbol (dimmed)
        ctx.fillStyle = 'rgba(143,188,143,0.7)';
        ctx.font = '32px Courier New';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(tile.symbol, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 - 8);

        // Label
        ctx.fillStyle = 'rgba(143,188,143,0.5)';
        ctx.font = '11px Courier New';
        ctx.fillText(tile.label, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 + 18);
      }

      ctx.restore();

      // C137: keyboard focus ring — amber border on focused tile. C51: guard kbFocusIdx>=0 (reset in endGame)
      if (this.kbFocusIdx >= 0 && i === this.kbFocusIdx) {
        ctx.save();
        ctx.strokeStyle = 'rgba(205,133,63,0.9)';
        ctx.lineWidth = 2.5;
        this.roundRect(ctx, tile.x - 2, tile.y - 2, this.tileSize + 4, this.tileSize + 4, 10);
        ctx.stroke();
        ctx.restore();
      }
    }

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  private roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }

  protected cleanup(): void {
    super.cleanup(); // calls cancelTimers() — C102
  }
}
