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

/** Transient canvas burst effect — green for faction, red for neutral. */
interface FlashEffect {
  x: number;
  y: number;
  radius: number;
  alpha: number;
  readonly isFaction: boolean;
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
  private ended = false;
  private timerInterval = 0;

  // Canvas dimensions
  private readonly canvasW = 380;
  private readonly canvasH = 400;

  // Game config — C100: scaled by difficultyTier in setup()
  private totalTime = 12;            // C100: [12,10,8,7]s
  private readonly maxWords = 30;    // words on screen at once
  private scrollSpeed = 40;          // C100: [40,50,60,70]px/s
  private spawnInterval = 0.6;       // C100: [0.6,0.5,0.4,0.35]s
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
  // C258: transient burst effects on word pick
  private flashEffects: FlashEffect[] = [];
  // C258: sequence bar flash timer (>0 = flashing)
  private seqFlashTimer = 0;
  private seqFlashFaction = true;

  // Keyboard support (WCAG 2.1.1 C137)
  private kbFocusIdx = 0;
  // C120/NEG-01: cached DOM refs — was getElementById every 100ms setInterval + every word pick
  private timerFillEl: HTMLElement | null = null;
  private timerBarEl: HTMLElement | null = null;
  private seqEl: HTMLElement | null = null;

  private onKeyDown = (e: KeyboardEvent): void => {
    if (this.ended) return;

    const visible = this.scrollingWords
      .map((sw, i) => ({ sw, i }))
      .filter(({ sw }) => !sw.picked && sw.fadeAlpha > 0 && sw.y > 0 && sw.y < this.canvasH);

    if (visible.length === 0) return;

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      this.kbFocusIdx = (this.kbFocusIdx + 1) % visible.length;
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      this.kbFocusIdx = (this.kbFocusIdx - 1 + visible.length) % visible.length;
    } else if (e.key === ' ' || e.key === 'Enter') {
      e.preventDefault();
      const clampedIdx = Math.min(this.kbFocusIdx, visible.length - 1);
      const target = visible[clampedIdx];
      if (!target) return;
      const sw = target.sw;
      // C142/NEG-01: immutable update via index — matches onPointerDown pattern
      this.scrollingWords = this.scrollingWords.map((w, i) => i === target.i ? { ...w, picked: true, fadeAlpha: 1 } : w);
      this.pickedSequence = [...this.pickedSequence, sw.word];
      if (sw.word.isFactionWord) {
        this.comboCount++;
        this.maxCombo = Math.max(this.maxCombo, this.comboCount);
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
      } else {
        this.comboCount = 0;
        window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
      }
      // C258: canvas burst + sequence bar flash (keyboard path mirrors pointer path)
      this.flashEffects = [
        ...this.flashEffects,
        { x: sw.x + Math.max(60, sw.word.text.length * 8.5) / 2, y: sw.y, radius: 4, alpha: 0.85, isFaction: sw.word.isFactionWord },
      ];
      this.seqFlashFaction = sw.word.isFactionWord;
      this.seqFlashTimer = 0.55;
      if (this.seqEl) {
        this.seqEl.classList.remove('nego-seq-flash-green', 'nego-seq-flash-red');
        void (this.seqEl as HTMLElement).offsetWidth;
        this.seqEl.classList.add(sw.word.isFactionWord ? 'nego-seq-flash-green' : 'nego-seq-flash-red');
      }
      if (this.seqEl) {
        const words = this.pickedSequence.map((w) =>
          w.isFactionWord ? `[${w.text}]` : w.text
        );
        this.seqEl.textContent = `Sequence: ${words.join(' ')}`;
      }
      // Advance focus to next visible word
      this.kbFocusIdx = Math.min(this.kbFocusIdx, Math.max(0, visible.length - 2));
    }
  };

  // C258: inject CeltOS visual enhancement CSS once (idempotent)
  private static injectStyles(): void {
    if (document.getElementById('mg-nego-styles-c258')) return;
    const style = document.createElement('style');
    style.id = 'mg-nego-styles-c258';
    style.textContent = `
      @keyframes negoWordPop {
        0%   { transform: scale(0.5); opacity: 0; }
        60%  { transform: scale(1.15); opacity: 1; }
        100% { transform: scale(1);   opacity: 1; }
      }
      @keyframes negoSeqFlashGreen {
        0%   { background: rgba(51,255,102,0.35); color: rgba(51,255,102,1); }
        60%  { background: rgba(51,255,102,0.18); color: rgba(51,255,102,0.9); }
        100% { background: transparent;           color: rgba(51,255,102,0.45); }
      }
      @keyframes negoSeqFlashRed {
        0%   { background: rgba(255,60,60,0.30); color: rgba(255,90,90,1); }
        60%  { background: rgba(255,60,60,0.12); color: rgba(255,90,90,0.85); }
        100% { background: transparent;          color: rgba(51,255,102,0.45); }
      }
      .nego-seq-flash-green {
        animation: negoSeqFlashGreen 0.55s ease-out forwards;
        border-radius: 4px;
      }
      .nego-seq-flash-red {
        animation: negoSeqFlashRed 0.55s ease-out forwards;
        border-radius: 4px;
      }
    `;
    document.head.appendChild(style);
  }

  protected setup(): void {
    this.container.innerHTML = '';
    MinigameNegociation.injectStyles(); // C258

    // C100: difficulty scaling
    this.totalTime     = this.tieredValue([12, 10, 8, 7] as const);
    this.scrollSpeed   = this.tieredValue([40, 50, 60, 70] as const);
    this.spawnInterval = this.tieredValue([0.6, 0.5, 0.4, 0.35] as const);

    // Pick random target faction
    const factionKeys = Object.keys(FACTION_KEYWORDS);
    this.targetFaction = pick(factionKeys);
    this.factionKeywords = FACTION_KEYWORDS[this.targetFaction];

    // Title
    const title = document.createElement('div');
    title.textContent = 'NEGOCIATION -- Persuade l\'esprit';
    title.style.cssText = 'color:rgba(51,255,102,0.88);font-size:14px;text-align:center;margin-bottom:4px;font-family:Courier New,monospace;';
    this.container.appendChild(title);

    // Target faction indicator
    const factionLabel = document.createElement('div');
    factionLabel.textContent = `Cible: ${this.targetFaction}`;
    factionLabel.style.cssText = 'color:rgba(51,255,102,0.50);font-size:12px;text-align:center;margin-bottom:8px;font-family:Courier New,monospace;';
    this.container.appendChild(factionLabel);

    // Timer bar
    const timerBar = document.createElement('div');
    timerBar.id = 'mg-nego-timer';
    timerBar.setAttribute('role', 'progressbar');
    timerBar.setAttribute('aria-label', 'Temps restant');
    timerBar.setAttribute('aria-valuemin', '0');
    timerBar.setAttribute('aria-valuemax', '100');
    timerBar.setAttribute('aria-valuenow', '100');
    timerBar.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;height:8px;background:rgba(255,255,255,0.1);border-radius:4px;margin:0 auto 8px;overflow:hidden;`;
    const timerFill = document.createElement('div');
    timerFill.id = 'mg-nego-timer-fill';
    timerFill.style.cssText = 'height:100%;width:100%;background:#8b6914;border-radius:4px;transition:width 0.1s linear;';
    timerBar.appendChild(timerFill);
    this.container.appendChild(timerBar);

    // Canvas
    this.canvas = document.createElement('canvas');
    this.canvas.setAttribute('aria-label', 'Minigame Negociation — choisissez les bons mots pour persuader');
    this.canvas.setAttribute('role', 'application');
    this.canvas.tabIndex = 0; // required for keyboard events to fire on canvas
    this.canvas.width = this.canvasW;
    this.canvas.height = this.canvasH;
    this.canvas.style.cssText = 'border-radius:12px;background:rgba(15,15,25,0.9);border:1px solid rgba(51,255,102,0.3);cursor:pointer;display:block;margin:0 auto;touch-action:none;max-width:100%;';
    this.container.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');

    // Sequence display
    const seqLabel = document.createElement('div');
    seqLabel.id = 'mg-nego-sequence';
    seqLabel.setAttribute('aria-live', 'polite'); // C114
    seqLabel.style.cssText = `width:min(${this.canvasW}px,100%);max-width:${this.canvasW}px;min-height:24px;margin:8px auto 0;color:rgba(51,255,102,0.45);font-size:11px;text-align:center;font-family:Courier New,monospace;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;`;
    seqLabel.textContent = 'Sequence: ...';
    this.container.appendChild(seqLabel);
    this.timerFillEl = timerFill;
    this.timerBarEl = timerBar;
    this.seqEl = seqLabel;

    // Input
    this.canvas.addEventListener('pointerdown', this.onPointerDown);
    this.canvas.addEventListener('keydown', this.onKeyDown);
    this.canvas.focus();

    // Reset state
    this.timeLeft = this.totalTime;
    this.elapsedTime = 0;
    this.spawnTimer = 0;
    this.scrollingWords = [];
    this.pickedSequence = [];
    this.comboCount = 0;
    this.maxCombo = 0;
    this.score = 0;
    this.ended = false;
    this.pulsePhase = 0;
    this.kbFocusIdx = 0;
    this.flashEffects = []; // C258
    this.seqFlashTimer = 0; // C258

    // Pre-seed some words — C100: clamp lower bound to wordHeight to avoid top-fade removal on first frame
    for (let i = 0; i < 8; i++) {
      this.spawnWord(this.wordHeight + Math.random() * (this.canvasH * 0.8 - this.wordHeight));
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

  private spawnWord(startY?: number): void {
    // C142/NEG-02: count only active (non-picked) words — fading picked words clogged the cap at tier 3,
    // blocking new faction word spawns for 0.5-1s and reducing achievable score by 30-40%
    if (this.scrollingWords.filter((w) => !w.picked).length >= this.maxWords) return;

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

    // C142/NEG-01: immutable update — render loop uses map(), direct mutation breaks reference equality
    const sw = this.scrollingWords[idx]!;
    this.scrollingWords = this.scrollingWords.map((w, i) => i === idx ? { ...w, picked: true, fadeAlpha: 1 } : w);

    // Add to sequence
    this.pickedSequence = [...this.pickedSequence, sw.word];

    // Combo tracking
    if (sw.word.isFactionWord) {
      this.comboCount++;
      this.maxCombo = Math.max(this.maxCombo, this.comboCount);
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'unlock' } }));
    } else {
      // Neutral word breaks combo
      this.comboCount = 0;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'lose' } }));
    }

    // C258: canvas burst flash at picked word position
    this.flashEffects = [
      ...this.flashEffects,
      { x: sw.x + Math.max(60, sw.word.text.length * 8.5) / 2, y: sw.y, radius: 4, alpha: 0.85, isFaction: sw.word.isFactionWord },
    ];

    // C258: sequence bar DOM flash (green=faction, red=neutral)
    this.seqFlashFaction = sw.word.isFactionWord;
    this.seqFlashTimer = 0.55;
    if (this.seqEl) {
      this.seqEl.classList.remove('nego-seq-flash-green', 'nego-seq-flash-red');
      // Force reflow so animation restarts
      void (this.seqEl as HTMLElement).offsetWidth;
      this.seqEl.classList.add(sw.word.isFactionWord ? 'nego-seq-flash-green' : 'nego-seq-flash-red');
    }

    // Update sequence display
    if (this.seqEl) {
      const words = this.pickedSequence.map((w) =>
        w.isFactionWord ? `[${w.text}]` : w.text
      );
      this.seqEl.textContent = `Sequence: ${words.join(' ')}`;
    }
  };

  protected cancelTimers(): void {
    clearInterval(this.timerInterval); // C102: centralised teardown
    cancelAnimationFrame(this.animFrame);
    this.canvas?.removeEventListener('pointerdown', this.onPointerDown);
    this.canvas?.removeEventListener('keydown', this.onKeyDown);
    this.flashEffects = []; // C258: clear burst effects on teardown
  }

  private endGame(): void {
    if (this.ended) return;
    this.ended = true;
    this.cancelTimers(); // C102: centralised teardown

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

    const finalScore = Math.min(100, Math.max(0, factionScore + comboBonus - penalty + timeBonus));
    this.finish(finalScore);
  }

  protected render(): void {
    if (!this.ctx || !this.canvas || this.ended) return; // C106: ended guard — prevents zombie rAF if endGame() fires before requestAnimationFrame at bottom of render()
    const ctx = this.ctx;
    const dt = this.getDeltaTime();
    this.elapsedTime += dt;
    this.pulsePhase += dt;

    // Spawn new words
    this.spawnTimer += dt;
    if (this.spawnTimer >= this.spawnInterval) {
      this.spawnTimer = 0;
      this.spawnWord();
    }

    // Update scrolling positions — C100: immutable map (no direct mutation)
    this.scrollingWords = this.scrollingWords.map((sw) => ({
      ...sw,
      y: sw.y - this.scrollSpeed * dt,
      fadeAlpha: sw.picked ? sw.fadeAlpha - dt * 3 : sw.fadeAlpha,
    }));

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
    ctx.fillStyle = 'rgba(51,255,102,0.5)';
    ctx.font = 'bold 13px Courier New';
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
      ctx.fillStyle = `rgba(51,255,102,${comboPulse})`;
      ctx.font = 'bold 16px Courier New';
      ctx.textAlign = 'right';
      ctx.fillText(`Combo x${this.comboCount}`, this.canvasW - 12, 16);
    }

    // C145/NEG-03: maxCombo cap indicator — comboBonus = min(25, maxCombo*5), cap reached at 5 combos.
    // Without this, player cannot tell when the 25pt bonus is already maxed and further combos add nothing.
    if (this.maxCombo > 0) {
      const capReached = this.maxCombo >= 5;
      ctx.fillStyle = capReached ? 'rgba(51,255,102,0.9)' : 'rgba(51,200,100,0.45)';
      ctx.font = '11px Courier New';
      ctx.textAlign = 'right';
      ctx.fillText(capReached ? 'BONUS MAX \u2713' : `Meilleur: ${this.maxCombo}/5`, this.canvasW - 12, 30);
    }

    // Score display
    const factionPicked = this.pickedSequence.filter((w) => w.isFactionWord).length;
    ctx.fillStyle = 'rgba(51,255,102,0.5)';
    ctx.font = '12px Courier New';
    ctx.textAlign = 'left';
    ctx.fillText(`Mots: ${factionPicked}`, 10, 16);

    // Build visible word list for keyboard focus tracking
    const visibleForKb = this.scrollingWords
      .map((sw, i) => ({ sw, i }))
      .filter(({ sw }) => !sw.picked && sw.fadeAlpha > 0 && sw.y > 0 && sw.y < this.canvasH);
    const kbClampedIdx = visibleForKb.length > 0
      ? Math.min(this.kbFocusIdx, visibleForKb.length - 1)
      : -1;
    const kbFocusedRawIdx = kbClampedIdx >= 0 ? visibleForKb[kbClampedIdx].i : -1;

    // C52: WCAG 2.4.7 — keyboard focus visible during empty window (first ~0.6s before words appear)
    if (visibleForKb.length === 0 && document.activeElement === this.canvas) {
      ctx.save();
      ctx.fillStyle = 'rgba(51,255,102,0.55)';
      ctx.font = '11px Courier New';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'alphabetic';
      ctx.fillText('⌨ Prêt…', this.canvas.width / 2, this.canvas.height - 16);
      ctx.restore();
    }

    // Draw scrolling words
    for (const [rawIdx, sw] of this.scrollingWords.entries()) {
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
        ctx.strokeStyle = `rgba(51,255,102,${alpha * 0.5})`;
      } else {
        ctx.strokeStyle = `rgba(100,100,120,${alpha * 0.2})`;
      }
      ctx.lineWidth = 1;
      ctx.stroke();

      // Keyboard focus ring (amber, WCAG C137)
      if (rawIdx === kbFocusedRawIdx && document.activeElement === this.canvas) {
        ctx.beginPath();
        ctx.roundRect(pillX - 2, pillY - 2, pillW + 4, pillH + 4, 8);
        ctx.strokeStyle = 'rgba(51,255,102,0.9)';
        ctx.lineWidth = 2.5;
        ctx.stroke();
      }

      // Word text
      ctx.font = sw.word.isFactionWord ? 'bold 15px Courier New' : '14px Courier New';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';

      if (sw.picked) {
        ctx.fillStyle = sw.word.isFactionWord
          ? `rgba(51,200,100,${alpha})`
          : `rgba(51,200,100,${alpha})`;
      } else {
        ctx.fillStyle = sw.word.isFactionWord
          ? `rgba(51,255,102,${alpha})`
          : `rgba(160,160,180,${alpha * 0.7})`;
      }
      ctx.fillText(sw.word.text, sw.x, sw.y);

      // Picked checkmark
      if (sw.picked && sw.word.isFactionWord) {
        ctx.fillStyle = `rgba(90,200,90,${sw.fadeAlpha})`;
        ctx.font = 'bold 18px Courier New';
        ctx.fillText('\u2713', sw.x + textWidth - 4, sw.y);
      }
    }

    // C258: draw and age canvas burst flash effects
    this.flashEffects = this.flashEffects
      .map((fx): FlashEffect => ({
        ...fx,
        radius: fx.radius + dt * 80,
        alpha: fx.alpha - dt * 2.8,
      }))
      .filter((fx) => fx.alpha > 0);

    for (const fx of this.flashEffects) {
      const grad = ctx.createRadialGradient(fx.x, fx.y, 0, fx.x, fx.y, fx.radius);
      if (fx.isFaction) {
        grad.addColorStop(0, `rgba(51,255,102,${fx.alpha})`);
        grad.addColorStop(0.5, `rgba(51,255,102,${fx.alpha * 0.4})`);
        grad.addColorStop(1, `rgba(51,255,102,0)`);
      } else {
        grad.addColorStop(0, `rgba(255,80,60,${fx.alpha})`);
        grad.addColorStop(0.5, `rgba(255,80,60,${fx.alpha * 0.35})`);
        grad.addColorStop(1, `rgba(255,80,60,0)`);
      }
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(fx.x, fx.y, fx.radius, 0, Math.PI * 2);
      ctx.fill();
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
    super.cleanup(); // calls cancelTimers() — C102
  }
}
