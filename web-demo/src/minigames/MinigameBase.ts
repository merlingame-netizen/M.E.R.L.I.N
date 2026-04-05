// ═══════════════════════════════════════════════════════════════════════════════
// Minigame Base — Abstract class for all minigames (score 0-100)
// 4-level outcome system: désastre (0-25) / échec (26-50) / réussite (51-85) / maîtrise (86-100)
// Narrative feedback: animated overlay + WebAudio tone, shown 2.2s before resolve.
// ═══════════════════════════════════════════════════════════════════════════════

// C195: SFX helper — dispatches to SFXManager via CustomEvent (same pattern as all UI files)
function sfx(sound: string): void {
  window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound } }));
}

export type OutcomeLevel = 'desastre' | 'echec' | 'reussite' | 'maitrise';

export interface MinigameResult {
  readonly score: number;         // 0-100
  readonly timeSpent: number;     // seconds
  readonly completed: boolean;
  readonly outcomeLevel: OutcomeLevel;
}

// ── Outcome helpers ───────────────────────────────────────────────────────────

/**
 * Normalise a raw score to the 0-100 integer range.
 * Non-finite values (NaN, ±Infinity) map to 0 rather than silently becoming
 * 'maitrise' (all NaN comparisons are false, so scoreToOutcome would fall
 * through to the final return). Call this before any outcome decision.
 */
export function validateScore(score: number): number {
  const safe = Number.isFinite(score) ? score : 0;
  return Math.max(0, Math.min(100, Math.round(safe)));
}

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
    color: '#ff6644',
    bg: 'rgba(60, 12, 4, 0.92)',
    border: '#8b2010',
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

// C105: module-level lazy singleton — avoids browser AudioContext cap
// (Chrome: 6, Safari: 1) on rapid completions. Stays open between calls;
// recreated only if ctx.state === 'closed'.
let _sharedAudioCtx: AudioContext | null = null;
function getSharedAudioCtx(): AudioContext {
  if (!_sharedAudioCtx || _sharedAudioCtx.state === 'closed') {
    _sharedAudioCtx = new AudioContext();
  }
  return _sharedAudioCtx;
}

function playOutcomeTone(level: OutcomeLevel): void {
  try {
    const ctx = getSharedAudioCtx();
    const gain = ctx.createGain();
    gain.connect(ctx.destination);

    const tones: Record<OutcomeLevel, number[]> = {
      desastre: [110, 100, 90],
      echec: [220, 196],
      reussite: [330, 392, 440],
      maitrise: [440, 554, 659, 880],
    };

    const freqs = tones[level];
    const dur = level === 'maitrise' ? 0.22 : 0.18;

    // BUG-03 fix: resume context first — iOS/Android suspend AudioContext on creation
    ctx.resume().catch(() => { /* autoplay blocked, silent */ }).finally(() => {
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
      // C105: singleton — do NOT call ctx.close() here; context reused across calls
    });
  } catch {
    // WebAudio unavailable — silent fallback
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
      `letter-spacing:0.12em;font-family:'Courier New',monospace;`,
      'text-shadow:0 0 16px currentColor;margin-bottom:8px;',
    ].join('');

    // Score
    const scoreEl = document.createElement('div');
    scoreEl.textContent = `${score} / 100`;
    scoreEl.style.cssText = [
      'color:rgba(51,255,102,0.85);font-size:clamp(14px,3vw,18px);',
      `font-family:'Courier New',monospace;margin-bottom:16px;`,
    ].join('');

    // Flavor text
    const flavor = document.createElement('div');
    flavor.textContent = cfg.flavor;
    flavor.style.cssText = [
      'color:rgba(51,255,102,0.7);font-size:clamp(11px,2.5vw,14px);',
      'font-style:italic;text-align:center;padding:0 24px;',
      `font-family:'Courier New',monospace;max-width:320px;line-height:1.5;`,
    ].join('');

    overlay.appendChild(badge);
    overlay.appendChild(scoreEl);
    overlay.appendChild(flavor);

    // BUG-04 fix: don't rely on 'static' string (jsdom returns ''); force unconditionally
    if (!['relative', 'absolute', 'fixed', 'sticky'].includes(getComputedStyle(container).position)) {
      container.style.position = 'relative';
    }
    container.appendChild(overlay);

    // Fade in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => { overlay.style.opacity = '1'; });
    });

    // C195: outcome SFX
    if (level === 'desastre' || level === 'echec') {
      sfx('lose');
    } else if (level === 'maitrise') {
      sfx('magic_reveal'); // special fanfare for mastery
      setTimeout(() => sfx('win'), 180); // double sound for emphasis
    } else {
      sfx('win'); // reussite
    }

    // Auto-dismiss after 2.2s
    // BUG-02 fix: check overlay.isConnected before resolving (guard against external cleanup())
    setTimeout(() => {
      overlay.style.opacity = '0';
      setTimeout(() => {
        overlay.remove();
        resolve(); // safe even if overlay was already removed — Promise resolves once only
      }, 260);
    }, 2200);
  });
}

// ── GO! flash overlay ─────────────────────────────────────────────────────────

function showGoFlash(container: HTMLElement): Promise<void> {
  return new Promise(resolve => {
    const flash = document.createElement('div');
    flash.textContent = 'GO!';
    flash.style.cssText = [
      'position:absolute', 'inset:0',
      'display:flex', 'align-items:center', 'justify-content:center',
      'font-family:Courier New,monospace',
      'font-size:64px', 'font-weight:bold',
      'color:#33ff66',
      'text-shadow:0 0 20px rgba(51,255,102,0.8)',
      'pointer-events:none',
      'z-index:50',
      'animation:go-flash-anim 0.7s ease-out forwards',
    ].join(';');

    // Inject keyframes once
    if (!document.getElementById('go-flash-style')) {
      const s = document.createElement('style');
      s.id = 'go-flash-style';
      s.textContent = `@keyframes go-flash-anim {
        0%   { opacity:0; transform:scale(0.5); }
        30%  { opacity:1; transform:scale(1.1); }
        60%  { opacity:1; transform:scale(1.0); }
        100% { opacity:0; transform:scale(1.3); }
      }`;
      document.head.appendChild(s);
    }

    if (!['relative', 'absolute', 'fixed', 'sticky'].includes(getComputedStyle(container).position)) {
      container.style.position = 'relative';
    }
    container.appendChild(flash);
    setTimeout(() => {
      flash.remove();
      resolve();
    }, 700);
  });
}

// ── Combo flash overlay ───────────────────────────────────────────────────────

/**
 * Show a ×N COMBO flash at the top-center of the container.
 * Only meaningful for comboCount >= 2.
 * - combo ≥ 3: green glow text-shadow
 * - combo ≥ 5: second line "INCROYABLE!" at 16px
 * Fires 'select' SFX once.
 */
export function showComboFlash(container: HTMLElement, comboCount: number): void {
  if (comboCount < 2) return;

  // Inject keyframes + base style once (idempotent)
  if (!document.getElementById('minigame-combo-style')) {
    const s = document.createElement('style');
    s.id = 'minigame-combo-style';
    s.textContent = `@keyframes combo-pop {
      0%   { transform: translateX(-50%) scale(0.6); opacity:0; }
      60%  { transform: translateX(-50%) scale(1.15); opacity:1; }
      100% { transform: translateX(-50%) scale(1.0); opacity:1; }
    }`;
    document.head.appendChild(s);
  }

  if (!['relative', 'absolute', 'fixed', 'sticky'].includes(getComputedStyle(container).position)) {
    container.style.position = 'relative';
  }

  const el = document.createElement('div');

  const glow = comboCount >= 3 ? '0 0 20px rgba(51,255,102,0.8)' : 'none';

  el.style.cssText = [
    'position:absolute',
    'top:18%',
    'left:50%',
    'transform:translateX(-50%)',
    'z-index:60',
    'pointer-events:none',
    'text-align:center',
    'animation:combo-pop 0.25s ease-out forwards',
    `text-shadow:${glow}`,
  ].join(';');

  // Main combo label
  const label = document.createElement('div');
  label.textContent = `\u00D7${comboCount} COMBO`;
  label.style.cssText = [
    'font-family:\'Courier New\',monospace',
    'font-size:28px',
    'font-weight:bold',
    'color:rgba(51,255,102,0.95)',
    'white-space:nowrap',
    'line-height:1.2',
  ].join(';');
  el.appendChild(label);

  // Extra line for high combos
  if (comboCount >= 5) {
    const extra = document.createElement('div');
    extra.textContent = 'INCROYABLE!';
    extra.style.cssText = [
      'font-family:\'Courier New\',monospace',
      'font-size:16px',
      'font-weight:bold',
      'color:rgba(51,255,102,0.85)',
      'white-space:nowrap',
      'margin-top:4px',
    ].join(';');
    el.appendChild(extra);
  }

  container.appendChild(el);

  sfx('select');

  // Visible 1.2s total (0.25s pop already included), then fade out 0.3s
  const visibleMs = 1200 - 250; // remaining after pop animation
  setTimeout(() => {
    el.style.transition = 'opacity 0.3s ease';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 300);
  }, visibleMs);
}

// ── Streak break visual ───────────────────────────────────────────────────────

/**
 * Brief dim red flash over the container — signals that a streak was reset.
 * No text, no SFX. 200ms fade-out.
 */
export function showStreakBreak(container: HTMLElement): void {
  if (!['relative', 'absolute', 'fixed', 'sticky'].includes(getComputedStyle(container).position)) {
    container.style.position = 'relative';
  }

  const overlay = document.createElement('div');
  overlay.style.cssText = [
    'position:absolute',
    'inset:0',
    'background:rgba(255,60,60,0.12)',
    'pointer-events:none',
    'z-index:55',
    'border-radius:inherit',
    'opacity:1',
    'transition:opacity 0.2s ease',
  ].join(';');

  container.appendChild(overlay);

  // Start fade-out on next frame
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      overlay.style.opacity = '0';
      setTimeout(() => overlay.remove(), 200);
    });
  });
}

// ── Abstract base ─────────────────────────────────────────────────────────────

export abstract class MinigameBase {
  protected container: HTMLElement;
  protected startTime = 0;
  protected resolve: ((result: MinigameResult) => void) | null = null;
  // BUG-05 fix: guard against double-finish (timer expiry + external call race)
  private finished = false;
  // Real-delta tracking — reset to 0 each play() so first frame returns 1/60 as safe default.
  private lastRenderMs = 0;
  // C94: cross-run difficulty tier (0-3) derived from cumulative play count in localStorage.
  // Tier 0: 0-2 plays, Tier 1: 3-6, Tier 2: 7-11, Tier 3: 12+.
  protected difficultyTier = 0;
  // C101: edge-trigger for critical_alert SFX — fires once when timeLeft crosses 3s threshold.
  protected criticalAlerted = false;

  /**
   * Per-subclass localStorage key fragment — prevents cross-minigame difficulty pollution.
   * C104: default is the concrete class name (preserved by Vite's esbuild; overridable with
   * a stable literal if minification ever strips class names). Used as suffix in:
   *   `merlin_mg_plays_${this.storageKey}`
   */
  protected get storageKey(): string { return this.constructor.name; }

  constructor(container: HTMLElement) {
    this.container = container;
  }

  /**
   * Return the per-tier value for this play session.
   * C100: eliminates `[v0,v1,v2,v3][this.difficultyTier] ?? v3` boilerplate in subclasses.
   * Example: `this.totalTime = this.tieredValue([30, 25, 20, 15]);`
   */
  protected tieredValue<T>(values: readonly [T, T, T, T]): T {
    return values[Math.min(this.difficultyTier, 3) as 0 | 1 | 2 | 3];
  }

  /**
   * Real delta time (seconds) since the previous render() call.
   * First call of a play session returns 1/60 (safe default).
   * Capped at 100ms to suppress post-tab-switch / DevTools spikes.
   * Subclasses replace `const dt = 1/60` with `const dt = this.getDeltaTime()`.
   */
  protected getDeltaTime(): number {
    const now = performance.now();
    const dt = this.lastRenderMs === 0 ? 1 / 60 : Math.min((now - this.lastRenderMs) / 1000, 0.1);
    this.lastRenderMs = now;
    return dt;
  }

  /**
   * Dispatch critical_alert SFX once when timeLeft crosses 3s from above.
   * Call from any subclass timer setInterval after decrementing timeLeft.
   */
  protected checkCriticalAlert(timeLeft: number): void {
    if (!this.criticalAlerted && timeLeft <= 3.0) {
      this.criticalAlerted = true;
      window.dispatchEvent(new CustomEvent('merlin_sfx', { detail: { sound: 'critical_alert' } }));
    }
  }

  /** Start the minigame and return a promise that resolves with the result. */
  play(): Promise<MinigameResult> {
    this.finished = false;
    this.criticalAlerted = false; // C101: reset for each new play session
    this.lastRenderMs = 0; // reset so getDeltaTime() returns 1/60 on first frame
    // C94: compute difficulty tier from cumulative play count
    try {
      const plays = parseInt(localStorage.getItem(`merlin_mg_plays_${this.storageKey}`) ?? '0', 10) || 0;
      this.difficultyTier = plays < 3 ? 0 : plays < 7 ? 1 : plays < 12 ? 2 : 3;
    } catch { this.difficultyTier = 0; }
    return new Promise((resolve) => {
      this.resolve = resolve;
      this.startTime = performance.now();
      this.setup();
      // C248: GO! flash overlay — fire-and-forget, does not delay minigame start
      sfx('minigame_start');
      showGoFlash(this.container); // intentionally not awaited
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
   * Safe to call multiple times — only first call takes effect.
   */
  protected finish(score: number): void {
    if (this.finished) return;  // BUG-05: idempotent guard
    this.finished = true;

    // C94: increment cumulative play count for difficulty ramp
    try {
      const plays = parseInt(localStorage.getItem(`merlin_mg_plays_${this.storageKey}`) ?? '0', 10) || 0;
      localStorage.setItem(`merlin_mg_plays_${this.storageKey}`, String(plays + 1));
    } catch { /* localStorage unavailable — difficulty stays static */ }

    const clamped = validateScore(score);
    const level = scoreToOutcome(clamped);
    const timeSpent = (performance.now() - this.startTime) / 1000;

    playOutcomeTone(level);

    // BUG-01 fix: dim ALL canvases in container, not just first
    this.container.querySelectorAll<HTMLCanvasElement>('canvas').forEach((c) => {
      c.style.opacity = '0.25';
    });

    showOutcomeOverlay(this.container, clamped, level).then(() => {
      this.cleanup();
      this.resolve?.({ score: clamped, timeSpent, completed: true, outcomeLevel: level });
    });
  }

  /**
   * Cancel all pending timers (setInterval / rAF handles) for this minigame.
   * BUG-C88-08: called by cleanup() so handles are always cleared even if cleanup()
   * fires before endGame() (e.g. overlay resolves early, external teardown).
   * Subclasses that own timers MUST override this method.
   */
  protected cancelTimers(): void {
    // Default no-op — subclasses with timers override this.
  }

  /** Clean up the minigame UI. */
  protected cleanup(): void {
    this.cancelTimers(); // BUG-C88-08: ensure handles cleared before DOM teardown
    this.container.innerHTML = '';
  }
}
