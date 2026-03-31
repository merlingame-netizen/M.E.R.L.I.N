// ═══════════════════════════════════════════════════════════════════════════════
// SFX Manager — Web Audio API procedural tones (T058)
// Listens to window 'merlin_sfx' CustomEvent dispatched by CardSystem/EffectEngine
// No external assets — pure procedural synthesis
// ═══════════════════════════════════════════════════════════════════════════════

type SFXName = 'flip' | 'win' | 'lose' | 'unlock' | 'end';

interface SFXEvent {
  sound: SFXName;
}

function getOrCreateContext(): AudioContext | null {
  try {
    return new AudioContext();
  } catch {
    return null;
  }
}

// ── Synthesis helpers ────────────────────────────────────────────────────────

function playTone(
  ctx: AudioContext,
  freq: number,
  startTime: number,
  duration: number,
  gainPeak: number,
  type: OscillatorType = 'sine',
  fadeOutStart?: number
): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  osc.type = type;
  osc.frequency.setValueAtTime(freq, startTime);

  gain.gain.setValueAtTime(0, startTime);
  gain.gain.linearRampToValueAtTime(gainPeak, startTime + 0.01);
  const fadeStart = fadeOutStart ?? startTime + duration - 0.02;
  gain.gain.setValueAtTime(gainPeak, fadeStart);
  gain.gain.linearRampToValueAtTime(0, startTime + duration);

  osc.connect(gain);
  gain.connect(ctx.destination);

  osc.start(startTime);
  osc.stop(startTime + duration + 0.01);
}

function playNoise(
  ctx: AudioContext,
  startTime: number,
  duration: number,
  gainPeak: number,
  filterFreq: number
): void {
  const bufferSize = ctx.sampleRate * duration;
  const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) {
    data[i] = (Math.random() * 2 - 1) * 0.3;
  }

  const source = ctx.createBufferSource();
  source.buffer = buffer;

  const filter = ctx.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.setValueAtTime(filterFreq, startTime);
  filter.Q.value = 1.5;

  const gain = ctx.createGain();
  gain.gain.setValueAtTime(gainPeak, startTime);
  gain.gain.linearRampToValueAtTime(0, startTime + duration);

  source.connect(filter);
  filter.connect(gain);
  gain.connect(ctx.destination);

  source.start(startTime);
  source.stop(startTime + duration);
}

// ── Sound definitions ────────────────────────────────────────────────────────

// flip: short ping 440Hz, 80ms
function playFlip(ctx: AudioContext): void {
  const t = ctx.currentTime;
  playTone(ctx, 440, t, 0.08, 0.18, 'sine');
  playTone(ctx, 880, t, 0.04, 0.06, 'sine');
}

// win: ascending major arpeggio C4-E4-G4-C5, each 80ms
function playWin(ctx: AudioContext): void {
  const t = ctx.currentTime;
  const notes = [261.63, 329.63, 392.0, 523.25];
  notes.forEach((freq, i) => {
    playTone(ctx, freq, t + i * 0.09, 0.18, 0.22, 'sine');
  });
  // Soft pad underneath
  playTone(ctx, 130.81, t, 0.45, 0.08, 'sine');
}

// lose: descending tone, 220Hz→110Hz glide, 400ms
function playLose(ctx: AudioContext): void {
  const t = ctx.currentTime;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(220, t);
  osc.frequency.exponentialRampToValueAtTime(100, t + 0.4);
  gain.gain.setValueAtTime(0.2, t);
  gain.gain.linearRampToValueAtTime(0, t + 0.45);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t);
  osc.stop(t + 0.46);

  // Low thud
  playNoise(ctx, t, 0.12, 0.15, 180);
}

// unlock: bell-like 880Hz with short reverb simulation (delay + decay)
function playUnlock(ctx: AudioContext): void {
  const t = ctx.currentTime;
  // Bell fundamental
  playTone(ctx, 880, t, 0.6, 0.25, 'sine', t + 0.05);
  // Bell partial harmonics
  playTone(ctx, 1318, t, 0.4, 0.10, 'sine', t + 0.05);
  playTone(ctx, 1760, t, 0.25, 0.06, 'sine', t + 0.05);
  // Simulated reverb: delayed echoes
  playTone(ctx, 880, t + 0.08, 0.5, 0.07, 'sine', t + 0.13);
  playTone(ctx, 880, t + 0.18, 0.4, 0.04, 'sine', t + 0.23);
  // Shimmer
  playTone(ctx, 2637, t, 0.15, 0.04, 'sine');
}

// end: sustained fade-out chord, 3s
function playEnd(ctx: AudioContext): void {
  const t = ctx.currentTime;
  const chordFreqs = [130.81, 164.81, 196.0, 261.63]; // C3 E3 G3 C4
  for (const freq of chordFreqs) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, t);
    gain.gain.setValueAtTime(0.12, t);
    gain.gain.setValueAtTime(0.12, t + 1.5);
    gain.gain.linearRampToValueAtTime(0, t + 3.0);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 3.1);
  }
}

// ── SFX Manager init ─────────────────────────────────────────────────────────

export function initSFXManager(): void {
  let ctx: AudioContext | null = null;

  const ensureContext = (): AudioContext | null => {
    if (!ctx) {
      ctx = getOrCreateContext();
    }
    if (ctx && ctx.state === 'suspended') {
      ctx.resume().catch(() => undefined);
    }
    return ctx;
  };

  const dispatch: Record<SFXName, (c: AudioContext) => void> = {
    flip: playFlip,
    win: playWin,
    lose: playLose,
    unlock: playUnlock,
    end: playEnd,
  };

  const handleSFX = (e: Event): void => {
    const detail = (e as CustomEvent<SFXEvent>).detail;
    if (!detail?.sound) return;
    const audioCtx = ensureContext();
    if (!audioCtx) return;
    const fn = dispatch[detail.sound];
    if (fn) {
      try {
        fn(audioCtx);
      } catch {
        // Silent fail — audio is non-critical
      }
    }
  };

  // Resume context on first user interaction (browser autoplay policy)
  const resumeOnInteraction = (): void => {
    if (ctx && ctx.state === 'suspended') {
      ctx.resume().catch(() => undefined);
    }
  };

  window.addEventListener('merlin_sfx', handleSFX);
  document.addEventListener('click', resumeOnInteraction, { once: true });
  document.addEventListener('keydown', resumeOnInteraction, { once: true });
}
