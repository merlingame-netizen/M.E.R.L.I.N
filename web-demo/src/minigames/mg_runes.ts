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
  private totalTime = 30; // C98: scaled by difficultyTier in setup() — 30/25/20/15s
  private readonly gridCols = 4;
  private readonly gridRows = 4;
  private readonly tileSize = 80;
  private readonly tilePad = 12;
  private firstPick: number | null = null;
  private lockInput = false;
  private matchedCount = 0;
  private readonly totalPairs = 8;
  private animFrame = 0;
  private revealTimeout = 0;
  private ended = false;

  protected setup(): void {
    this.container.innerHTML = '';

    // C98: scale difficulty — tier 0: 30s, tier 1: 25s, tier 2: 20s, tier 3: 15s
    this.totalTime = 30 - this.difficultyTier * 5;

    // Title
    const title = document.createElement('div');
    title.textContent = 'RUNES -- Trouve les paires d\'oghams';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:16px;font-family:system-ui;';
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

    // pointerdown covers mouse, touch and stylus — no 'click' needed (avoids double-fire on desktop)
    this.canvas.addEventListener('pointerdown', this.onClick);

    // Timer
    this.timeLeft = this.totalTime;
    this.matchedCount = 0;
    this.firstPick = null;
    this.lockInput = false;
    this.ended = false;

    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-runes-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      const bar = document.getElementById('mg-runes-timer');
      if (bar) bar.setAttribute('aria-valuenow', String(Math.round(pct)));
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

    this.tiles = [];
    for (let row = 0; row < this.gridRows; row++) {
      for (let col = 0; col < this.gridCols; col++) {
        const idx = row * this.gridCols + col;
        const runeIndex = indices[idx];
        const rune = RUNE_SET[runeIndex];
        this.tiles.push({
          x: this.tilePad + col * (this.tileSize + this.tilePad),
          y: this.tilePad + row * (this.tileSize + this.tilePad),
          runeIndex,
          symbol: rune.symbol,
          label: rune.label,
          state: 'hidden',
        });
      }
    }
  }

  private onClick = (e: MouseEvent): void => {
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
        }, 600);
      }
    }
  };

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    clearInterval(this.timerInterval);
    clearTimeout(this.revealTimeout);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);

    // Score: base on pairs found + time bonus
    const pairScore = (this.matchedCount / this.totalPairs) * 70;
    const timeBonus = Math.max(0, this.timeLeft / this.totalTime) * 30;
    const score = pairScore + timeBonus;
    this.finish(score);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    for (const tile of this.tiles) {
      ctx.save();

      if (tile.state === 'hidden') {
        // Stone tile back
        ctx.fillStyle = 'rgba(80,75,65,0.7)';
        this.roundRect(ctx, tile.x, tile.y, this.tileSize, this.tileSize, 8);
        ctx.fill();

        // Question mark
        ctx.fillStyle = 'rgba(205,133,63,0.4)';
        ctx.font = 'bold 28px system-ui';
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
        ctx.fillStyle = '#e8dcc8';
        ctx.font = '32px serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(tile.symbol, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 - 8);

        // Label
        ctx.fillStyle = 'rgba(205,133,63,0.8)';
        ctx.font = '11px system-ui';
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
        ctx.font = '32px serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(tile.symbol, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 - 8);

        // Label
        ctx.fillStyle = 'rgba(143,188,143,0.5)';
        ctx.font = '11px system-ui';
        ctx.fillText(tile.label, tile.x + this.tileSize / 2, tile.y + this.tileSize / 2 + 18);
      }

      ctx.restore();
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
    clearInterval(this.timerInterval);
    clearTimeout(this.revealTimeout);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onClick);
    super.cleanup();
  }
}
