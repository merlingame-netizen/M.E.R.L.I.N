// ═══════════════════════════════════════════════════════════════════════════════
// Minigame Base — Abstract class for all minigames (score 0-100)
// 4-level outcome system: désastre (0-25) / échec (26-50) / réussite (51-85) / maîtrise (86-100)
// Narrative feedback: animated overlay + WebAudio tone, shown 2.2s before resolve.
// ═══════════════════════════════════════════════════════════════════════════════

export type OutcomeLevel = 'desastre' | 'echec' | 'reussite' | 'maitrise';

export interface MinigameResult {
  readonly score: number;         // 0-100
  readonly timeSpent: number;     // seconds
  readonly completed: boolean;
  readonly outcomeLevel: OutcomeLevel;
}

// ── Outcome helpers ───────────────────────────────────────────────────────────

export function scoreToOutcome(score: number): OutcomeLevel {
  if (score <= 25) return 'desastre';
  if (score <= 50) return 'echec';
  if (score <= 85) return 'reussite';
  return 'maitrise';
}

const OUTCOME_CONFIG: Record<OutcomeLevel, {
  label: string;
  color: string;
  bg: string;
  flavor: string;
  border: string;
}> = {
  desastre: {
    label: 'DÉSASTRE',
    color: '#ff3322',
    bg: 'rgba(80, 8, 4, 0.92)',
    border: '#8b1010',
    flavor: 'Les esprits de la forêt se détournent de toi.',
  },
  echec: {
    label: 'ÉCHEC',
    color: '#ff9933',
    bg: 'rgba(60, 28, 4, 0.92)',
    border: '#6b4010',
    flavor: 'Le druide observe. La voie reste incertaine.',
  },
  reussite: {
    label: 'RÉUSSITE',
    color: '#44dd77',
    bg: 'rgba(4, 40, 16, 0.92)',
    border: '#1a6b38',
    flavor: 'Merlin hoche la tête — l\'équilibre est maintenu.',
  },
  maitrise: {
    label: 'MAÎTRISE',
    color: '#ffd700',
    bg: 'rgba(30, 24, 4, 0.92)',
    border: '#8b7000',
    flavor: 'Ogham vivant — la forêt chante à ton passage.',
  },
};

// ── WebAudio outcome tones ────────────────────────────────────────────────────

function playOutcomeTone(level: OutcomeLevel): void {
  try {
    const ctx = new AudioContext();
    const gain = ctx.createGain();
    gain.connect(ctx.destination);

    const tones: Record<OutcomeLevel, number[]> = {
      desastre: [110, 100, 90],      // descending minor, dark
      echec: [220, 196],             // minor 3rd fall
      reussite: [330, 392, 440],     // major arpeggio rise
      maitrise: [440, 554, 659, 880],// full major chord cascade
    };

    const freqs = tones[level];
    const dur = level === 'maitrise' ? 0.22 : 0.18;

    freqs.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      osc.type = level === 'desastre' ? 'sawtooth' : 'sine';
      osc.frequency.value = freq;
      osc.connect(gain);
      const start = ctx.currentTime + i * (dur * 0.6);
      gain.gain.setValueAtTime(0.15, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + dur);
      osc.start(start);
      osc.stop(start + dur);
    });

    // Auto-close AudioContext after tones finish
    setTimeout(() => ctx.close(), (freqs.length * dur * 0.6 + dur + 0.2) * 1000);
  } catch {
    // WebAudio unavailable (e.g. unit tests) — silent fallback
  }
}

// ── Outcome overlay ───────────────────────────────────────────────────────────

function showOutcomeOverlay(container: HTMLElement, score: number, level: OutcomeLevel): Promise<void> {
  return new Promise((resolve) => {
    const cfg = OUTCOME_CONFIG[level];

    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'status');
    overlay.setAttribute('aria-live', 'assertive');
    overlay.style.cssText = [
      'position:absolute;inset:0;display:flex;flex-direction:column;',
      'align-items:center;justify-content:center;z-index:100;',
      `background:${cfg.bg};`,
      `border:2px solid ${cfg.border};border-radius:12px;`,
      'opacity:0;transition:opacity 0.25s ease;',
      'pointer-events:none;',
    ].join('');

    // Level badge
    const badge = document.createElement('div');
    badge.textContent = cfg.label;
    badge.style.cssText = [
      `color:${cfg.color};font-size:clamp(22px,5vw,32px);font-weight:700;`,
      'letter-spacing:0.12em;font-family:Georgia,serif;',
      'text-shadow:0 0 16px currentColor;margin-bottom:8px;',
    ].join('');

    // Score
    const scoreEl = document.createElement('div');
    scoreEl.textContent = `${score} / 100`;
    scoreEl.style.cssText = [
      'color:rgba(255,255,255,0.7);font-size:clamp(14px,3vw,18px);',
      'font-family:monospace;margin-bottom:16px;',
    ].join('');

    // Flavor text
    const flavor = document.createElement('div');
    flavor.textContent = cfg.flavor;
    flavor.style.cssText = [
      'color:rgba(200,180,140,0.85);font-size:clamp(11px,2.5vw,14px);',
      'font-style:italic;text-align:center;padding:0 24px;',
      'font-family:Georgia,serif;max-width:320px;line-height:1.5;',
    ].join('');

    overlay.appendChild(badge);
    overlay.appendChild(scoreEl);
    overlay.appendChild(flavor);

    // Ensure container is position:relative for absolute child
    if (getComputedStyle(container).position === 'static') {
      container.style.position = 'relative';
    }
    container.appendChild(overlay);

    // Fade in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => { overlay.style.opacity = '1'; });
    });

    // Auto-dismiss after 2.2s
    setTimeout(() => {
      overlay.style.opacity = '0';
      setTimeout(() => {
        overlay.remove();
        resolve();
      }, 260);
    }, 2200);
  });
}

// ── Abstract base ─────────────────────────────────────────────────────────────

export abstract class MinigameBase {
  protected container: HTMLElement;
  protected startTime = 0;
  protected resolve: ((result: MinigameResult) => void) | null = null;

  constructor(container: HTMLElement) {
    this.container = container;
  }

  /** Start the minigame and return a promise that resolves with the result. */
  play(): Promise<MinigameResult> {
    return new Promise((resolve) => {
      this.resolve = resolve;
      this.startTime = performance.now();
      this.setup();
      this.render();
    });
  }

  /** Called once to set up the minigame UI. */
  protected abstract setup(): void;

  /** Called to render/update the minigame. */
  protected abstract render(): void;

  /**
   * Call this to end the minigame with a score (0-100).
   * Shows the 4-level outcome overlay + plays a tone, then resolves.
   */
  protected finish(score: number): void {
    const clamped = Math.max(0, Math.min(100, Math.round(score)));
    const level = scoreToOutcome(clamped);
    const timeSpent = (performance.now() - this.startTime) / 1000;

    playOutcomeTone(level);

    // Hide game content (keep container for overlay)
    const canvas = this.container.querySelector('canvas');
    if (canvas) canvas.style.opacity = '0.25';

    showOutcomeOverlay(this.container, clamped, level).then(() => {
      this.cleanup();
      this.resolve?.({ score: clamped, timeSpent, completed: true, outcomeLevel: level });
    });
  }

  /** Clean up the minigame UI. */
  protected cleanup(): void {
    this.container.innerHTML = '';
  }
}
