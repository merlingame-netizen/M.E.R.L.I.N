// =============================================================================
// Minigame: Negociation -- Persuade a spirit with the right words
// Words scroll upward. Player clicks words that match the target faction's
// keywords to build a persuasion sequence. Timer 12s. Score = combo bonus
// (matching faction keywords) + time bonus + sequence length bonus.
// =============================================================================

import { MinigameBase } from './MinigameBase';

/** Immutable word descriptor. */
interface Word {
  readonly text: string;
  readonly isFactionWord: boolean;
  readonly field: string;
}

/** Mutable word position on canvas (mutated only locally in render loop). */
interface ScrollingWord {
  readonly word: Word;
  x: number;
  y: number;
  picked: boolean;
  fadeAlpha: number;
}

/** Faction keyword pools -- words that resonate with each faction. */
const FACTION_KEYWORDS: Record<string, readonly string[]> = {
  druides: ['sagesse', 'nature', 'equilibre', 'harmonie', 'racines', 'gui', 'rituel', 'ancien', 'cycle', 'chene'],
  anciens: ['memoire', 'serment', 'honneur', 'tradition', 'cairn', 'lignee', 'pierre', 'ancestral', 'devoir', 'loi'],
  korrigans: ['ruse', 'marche', 'tresor', 'malice', 'enigme', 'prix', 'astuce', 'fete', 'echange', 'farce'],
  niamh: ['beaute', 'brume', 'reve', 'lac', 'argent', 'grace', 'voile', 'lune', 'chant', 'mystere'],
  ankou: ['ombre', 'mort', 'passage', 'silence', 'os', 'nuit', 'froid', 'seuil', 'crepuscule', 'neant'],
};

/** Neutral filler words (no bonus). */
const NEUTRAL_WORDS: readonly string[] = [
  'peut-etre', 'certainement', 'jamais', 'toujours', 'ici', 'ailleurs',
  'bientot', 'lentement', 'vite', 'encore', 'simplement', 'vraiment',
  'parole', 'chemin', 'vent', 'pluie', 'terre', 'feu', 'eau', 'ciel',
];

/** Pick a random element from an array. */
function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

export class MinigameNegociation extends MinigameBase {
  private canvas: HTMLCanvasElement | null = null;
  private ctx: CanvasRenderingContext2D | null = null;
  private animFrame = 0;
  private timerInterval = 0;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 400;

  // Game config
  private readonly totalTime = 12;
  private readonly maxWords = 30; // words on screen at once
  private readonly scrollSpeed = 40; // pixels per second
  private readonly spawnInterval = 0.6; // seconds between spawns
  private readonly wordHeight = 28;

  // Game state
  private targetFaction = '';
  private factionKeywords: readonly string[] = [];
  private scrollingWords: ScrollingWord[] = [];
  private pickedSequence: Word[] = [];
  private timeLeft = 12;
  private elapsedTime = 0;
  private spawnTimer = 0;
  private comboCount = 0;
  private maxCombo = 0;
  private score = 0;

  // Visual
  private pulsePhase = 0;

  protected setup(): void {
    this.container.innerHTML = '';

    // Pick random target faction
    const factionKeys = Object.keys(FACTION_KEYWORDS);
    this.targetFaction = pick(factionKeys);
    this.factionKeywords = FACTION_KEYWORDS[this.targetFaction];

    // Title
    const title = document.createElement('div');
    title.textContent = 'NEGOCIATION -- Persuade l\'esprit';
    title.style.cssText = 'color:#e8dcc8;font-size:20px;text-align:center;margin-bottom:4px;font-family:system-ui;';
    this.container.appendChild(title);

    // Target faction indicator
    const factionLabel = document.createElement('div');
    factionLabel.textContent = `Cible: ${this.targetFaction}`;
    factionLabel.style.cssText = 'color:#cd853f;font-size:14px;text-align:center;margin-bottom:8px;font-family:system-ui;';
    this.container.appendChild(factionLabel);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-nego-timer';
    timerBar.style.cssText = `width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-nego-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#8b6914;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,15,25,0.9);border:1px solid rgba(205,133,63,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Sequence display
    const seqLabel = document.createElement('div');
    seqLabel.id = 'mg-nego-sequence';
    seqLabel.style.cssText = `width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(232,220,200,0.6);font-size:12px;text-align:center;font-family:system-ui;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;`;
    seqLabel.textContent = 'Sequence: ...';
    this.container.appendChild(seqLabel);

    // Input
    this.canvas.addEventListener('pointerdown', this.onPointerDown);

    // Reset state
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.spawnTimer = 0;
    this.scrollingWords = [];
    this.pickedSequence = [];
    this.comboCount = 0;
    this.maxCombo = 0;
    this.score = 0;
    this.pulsePhase = 0;

    // Pre-seed some words
    for (let i = 0; i < 8; i++) {
      this.spawnWord(Math.random() * this.canvasH * 0.8);
    }

    // Timer
    this.timerInterval = window.setInterval(() => {
      this.timeLeft -= 0.1;
      const pct = Math.max(0, (this.timeLeft / this.totalTime) * 100);
      const fill = document.getElementById('mg-nego-timer-fill');
      if (fill) fill.style.width = `${pct}%`;
      if (this.timeLeft <= 0) {
        this.endGame();
      }
    }, 100);
  }

  private spawnWord(startY?: number): void {
    if (this.scrollingWords.length >= this.maxWords) return;

    // 40% chance faction word, 60% neutral
    const isFaction = Math.random() < 0.4;
    let text: string;
    let field: string;

    if (isFaction) {
      text = pick(this.factionKeywords);
      field = this.targetFaction;
    } else {
      text = pick(NEUTRAL_WORDS);
      field = 'neutral';
    }

    const x = 20 + Math.random() * (this.canvasW - 100);
    const y = startY !== undefined ? startY : this.canvasH + 10;

    this.scrollingWords = [
      ...this.scrollingWords,
      {
        word: { text, isFactionWord: isFaction, field },
        x,
        y,
        picked: false,
        fadeAlpha: 1,
      },
    ];
  }

  private getWordAt(px: number, py: number): number | null {
    // Check from top to bottom (last drawn = on top)
    for (let i = this.scrollingWords.length - 1; i >= 0; i--) {
      const sw = this.scrollingWords[i];
      if (sw.picked) continue;
      const textWidth = Math.max(60, sw.word.text.length * 9);
      if (
        px >= sw.x - 4 &&
        px <= sw.x + textWidth + 8 &&
        py >= sw.y - this.wordHeight / 2 - 4 &&
        py <= sw.y + this.wordHeight / 2 + 4
      ) {
        return i;
      }
    }
    return null;
  }

  private onPointerDown = (e: PointerEvent): void => {
    if (!this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const y = (e.clientY - rect.top) * (this.canvas.height / rect.height);

    const idx = this.getWordAt(x, y);
    if (idx === null) return;

    const sw = this.scrollingWords[idx];
    sw.picked = true;
    sw.fadeAlpha = 1;

    // Add to sequence
    this.pickedSequence = [...this.pickedSequence, sw.word];

    // Combo tracking
    if (sw.word.isFactionWord) {
      this.comboCount++;
      this.maxCombo = Math.max(this.maxCombo, this.comboCount);
    } else {
      // Neutral word breaks combo
      this.comboCount = 0;
    }

    // Update sequence display
    const seqEl = document.getElementById('mg-nego-sequence');
    if (seqEl) {
      const words = this.pickedSequence.map((w) =>
        w.isFactionWord ? `[${w.text}]` : w.text
      );
      seqEl.textContent = `Sequence: ${words.join(' ')}`;
    }
  };

  private endGame(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);

    // Score calculation:
    // - Faction words picked: each worth 8 points (up to 80)
    // - Combo bonus: maxCombo * 5 (up to 25)
    // - Penalty: neutral words picked * 3
    // - Time bonus: up to +15 if finished early or picked enough
    const factionPicked = this.pickedSequence.filter((w) => w.isFactionWord).length;
    const neutralPicked = this.pickedSequence.filter((w) => !w.isFactionWord).length;

    const factionScore = Math.min(80, factionPicked * 8);
    const comboBonus = Math.min(25, this.maxCombo * 5);
    const penalty = neutralPicked * 3;
    const timeBonus = this.timeLeft > 0 ? (this.timeLeft / this.totalTime) * 15 : 0;

    const finalScore = Math.max(0, factionScore + comboBonus - penalty + timeBonus);
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas) return;
    const ctx = this.ctx;
    const dt = 1 / 60;
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Spawn new words
    this.spawnTimer += dt;
    if (this.spawnTimer >= this.spawnInterval) {
      this.spawnTimer = 0;
      this.spawnWord();
    }

    // Update scrolling positions
    for (const sw of this.scrollingWords) {
      sw.y -= this.scrollSpeed * dt;
      if (sw.picked) {
        sw.fadeAlpha -= dt * 3;
      }
    }

    // Remove off-screen or fully faded words
    this.scrollingWords = this.scrollingWords.filter(
      (sw) => sw.y > -20 && sw.fadeAlpha > 0
    );

    // Clear
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // Background gradient
    const bgGrad = ctx.createLinearGradient(0, 0, 0, this.canvasH);
    bgGrad.addColorStop(0, 'rgba(10,10,20,0.95)');
    bgGrad.addColorStop(0.5, 'rgba(15,12,25,0.9)');
    bgGrad.addColorStop(1, 'rgba(10,10,20,0.95)');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, this.canvasW, this.canvasH);

    // Faction indicator at top
    ctx.fillStyle = 'rgba(205,133,63,0.5)';
    ctx.font = 'bold 13px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(
      `Mots de pouvoir: ${this.targetFaction}`,
      this.canvasW / 2,
      16
    );

    // Combo display
    if (this.comboCount > 1) {
      const comboPulse = 0.7 + Math.sin(this.pulsePhase * 6) * 0.3;
      ctx.fillStyle = `rgba(255,200,60,${comboPulse})`;
      ctx.font = 'bold 16px system-ui';
      ctx.textAlign = 'right';
      ctx.fillText(`Combo x${this.comboCount}`, this.canvasW - 12, 16);
    }

    // Score display
    const factionPicked = this.pickedSequence.filter((w) => w.isFactionWord).length;
    ctx.fillStyle = 'rgba(232,220,200,0.5)';
    ctx.font = '12px system-ui';
    ctx.textAlign = 'left';
    ctx.fillText(`Mots: ${factionPicked}`, 10, 16);

    // Draw scrolling words
    for (const sw of this.scrollingWords) {
      const alpha = sw.picked ? sw.fadeAlpha * 0.4 : 0.9;
      if (alpha <= 0) continue;

      const textWidth = Math.max(60, sw.word.text.length * 8.5);

      // Word background pill
      if (sw.word.isFactionWord) {
        ctx.fillStyle = `rgba(139,105,20,${alpha * 0.25})`;
      } else {
        ctx.fillStyle = `rgba(60,60,80,${alpha * 0.2})`;
      }
      const pillX = sw.x - 6;
      const pillY = sw.y - this.wordHeight / 2 - 2;
      const pillW = textWidth + 12;
      const pillH = this.wordHeight + 4;
      ctx.beginPath();
      ctx.roundRect(pillX, pillY, pillW, pillH, 6);
      ctx.fill();

      // Word border
      if (sw.word.isFactionWord) {
        ctx.strokeStyle = `rgba(205,133,63,${alpha * 0.5})`;
      } else {
        ctx.strokeStyle = `rgba(100,100,120,${alpha * 0.2})`;
      }
      ctx.lineWidth = 1;
      ctx.stroke();

      // Word text
      ctx.font = sw.word.isFactionWord ? 'bold 15px system-ui' : '14px system-ui';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';

      if (sw.picked) {
        ctx.fillStyle = sw.word.isFactionWord
          ? `rgba(200,180,60,${alpha})`
          : `rgba(150,100,100,${alpha})`;
      } else {
        ctx.fillStyle = sw.word.isFactionWord
          ? `rgba(232,220,200,${alpha})`
          : `rgba(160,160,180,${alpha * 0.7})`;
      }
      ctx.fillText(sw.word.text, sw.x, sw.y);

      // Picked checkmark
      if (sw.picked && sw.word.isFactionWord) {
        ctx.fillStyle = `rgba(90,200,90,${sw.fadeAlpha})`;
        ctx.font = 'bold 18px system-ui';
        ctx.fillText('\u2713', sw.x + textWidth - 4, sw.y);
      }
    }

    // Bottom fade gradient (words disappear at top)
    const topFade = ctx.createLinearGradient(0, 0, 0, 40);
    topFade.addColorStop(0, 'rgba(10,10,20,1)');
    topFade.addColorStop(1, 'rgba(10,10,20,0)');
    ctx.fillStyle = topFade;
    ctx.fillRect(0, 0, this.canvasW, 40);

    this.animFrame = requestAnimationFrame(() => this.render());
  }

  protected cleanup(): void {
    clearInterval(this.timerInterval);
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    super.cleanup();
  }
}
