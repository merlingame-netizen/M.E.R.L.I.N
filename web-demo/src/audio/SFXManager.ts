// ═══════════════════════════════════════════════════════════════════════════════
// SFX Manager — Web Audio API procedural tones (T058)
// T066: Ambient audio — startAmbient(type) / stopAmbient()
// Listens to window 'merlin_sfx' CustomEvent dispatched by CardSystem/EffectEngine
// No external assets — pure procedural synthesis
// ═══════════════════════════════════════════════════════════════════════════════

type SFXName = 'flip' | 'win' | 'lose' | 'unlock' | 'end';
type AmbientType = 'menu' | 'forest' | 'wind' | 'rain';

interface SFXEvent {
  sound: SFXName;
}

// ── Shared AudioContext (module-level, created lazily on first interaction) ──

let sharedCtx: AudioContext | null = null;

function getOrCreateContext(): AudioContext | null {
  try {
    if (!sharedCtx) {
      sharedCtx = new AudioContext();
    }
    return sharedCtx;
  } catch {
    return null;
  }
}

function ensureContext(): AudioContext | null {
  const ctx = getOrCreateContext();
  if (ctx && ctx.state === 'suspended') {
    ctx.resume().catch(() => undefined);
  }
  return ctx;
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

// ── Ambient audio (T066) ────────────────────────────────────────────────────

/** Nodes kept alive for the current ambient session so we can stop them. */
interface AmbientSession {
  masterGain: GainNode;
  oscillators: OscillatorNode[];
  noiseSource: AudioBufferSourceNode | null;
  birdTimer: ReturnType<typeof setTimeout> | null;
}

let ambientSession: AmbientSession | null = null;

/**
 * Create a long (30s looping) noise buffer filtered to simulate wind.
 * Lower cutoff = deeper wind rumble.
 */
function createWindNoise(ctx: AudioContext, master: GainNode, cutoffHz: number): AudioBufferSourceNode {
  const duration = 30;
  const bufSize = ctx.sampleRate * duration;
  const buffer = ctx.createBuffer(1, bufSize, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  // Pink-ish noise: simple running average to tilt spectrum
  let lastVal = 0;
  for (let i = 0; i < bufSize; i++) {
    const white = Math.random() * 2 - 1;
    lastVal = (lastVal + 0.08 * white) / 1.08;
    data[i] = lastVal * 8; // compensate gain loss from filtering
  }

  const source = ctx.createBufferSource();
  source.buffer = buffer;
  source.loop = true;

  const lpf = ctx.createBiquadFilter();
  lpf.type = 'lowpass';
  lpf.frequency.setValueAtTime(cutoffHz, ctx.currentTime);
  lpf.Q.value = 0.7;

  // Gentle gain flutter to simulate gusting
  const flutter = ctx.createGain();
  flutter.gain.setValueAtTime(1.0, ctx.currentTime);

  source.connect(lpf);
  lpf.connect(flutter);
  flutter.connect(master);
  source.start(ctx.currentTime);
  return source;
}

/**
 * Schedule a single bird chirp: a short rising sine sweep 800→1200Hz, 120ms.
 */
function playBirdChirp(ctx: AudioContext, master: GainNode): void {
  const t = ctx.currentTime;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(800, t);
  osc.frequency.exponentialRampToValueAtTime(1200, t + 0.12);
  gain.gain.setValueAtTime(0, t);
  gain.gain.linearRampToValueAtTime(0.06, t + 0.02);
  gain.gain.setValueAtTime(0.06, t + 0.09);
  gain.gain.linearRampToValueAtTime(0, t + 0.14);
  osc.connect(gain);
  gain.connect(master);
  osc.start(t);
  osc.stop(t + 0.15);
}

/**
 * Single rain drop: a short white-noise burst band-passed to 800-2000Hz, 80ms.
 */
function playRainDrop(ctx: AudioContext, master: GainNode): void {
  const t = ctx.currentTime;
  const bufSize = Math.floor(ctx.sampleRate * 0.08);
  const buf = ctx.createBuffer(1, bufSize, ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
  const src = ctx.createBufferSource();
  src.buffer = buf;
  const bpf = ctx.createBiquadFilter();
  bpf.type = 'bandpass';
  bpf.frequency.setValueAtTime(1200, t);
  bpf.Q.value = 0.8;
  const dropGain = ctx.createGain();
  dropGain.gain.setValueAtTime(0, t);
  dropGain.gain.linearRampToValueAtTime(0.04, t + 0.005);
  dropGain.gain.linearRampToValueAtTime(0, t + 0.08);
  src.connect(bpf);
  bpf.connect(dropGain);
  dropGain.connect(master);
  src.start(t);
  src.stop(t + 0.09);
}

/** Schedule rain drops at random 0.3-1.4s intervals (dense rain texture). */
function scheduleRainDrops(
  ctx: AudioContext,
  master: GainNode,
  session: AmbientSession
): void {
  const scheduleNext = (): void => {
    const delayMs = (0.3 + Math.random() * 1.1) * 1000;
    session.birdTimer = setTimeout(() => {
      if (!ambientSession) return;
      try { playRainDrop(ctx, master); } catch { /* silent fail */ }
      scheduleNext();
    }, delayMs);
  };
  scheduleNext();
}

/**
 * Start looping bird chirps at random 4-12s intervals.
 * Returns the handle so we can cancel it.
 */
function scheduleBirds(
  ctx: AudioContext,
  master: GainNode,
  session: AmbientSession
): void {
  const scheduleNext = (): void => {
    const delayMs = (4 + Math.random() * 8) * 1000;
    session.birdTimer = setTimeout(() => {
      if (!ambientSession) return; // stopped
      try { playBirdChirp(ctx, master); } catch { /* silent fail */ }
      scheduleNext();
    }, delayMs);
  };
  scheduleNext();
}

/**
 * T066 — Start procedural ambient audio.
 * 'menu':   55Hz drone + lowpass wind (400Hz). Gain 0.05.
 * 'forest': 65Hz drone + lowpass wind (350Hz) + bird chirps. Gain 0.05.
 * 'wind':   42Hz drone + lowpass wind (700Hz, airy coastal feel). Gain 0.05. No birds.
 * 'rain':   50Hz drone + lowpass wind (500Hz) + dense rain drop bursts. Gain 0.05.
 * Silent-fails if AudioContext unavailable (browser policy, no interaction yet).
 */
export function startAmbient(type: AmbientType): void {
  stopAmbient(); // stop any previous session first

  const ctx = ensureContext();
  if (!ctx) return;

  // If context is still suspended (no user interaction yet), queue and defer.
  // T072: resumeOnInteraction will call startAmbient(pendingAmbientType) after resume.
  if (ctx.state === 'suspended') {
    pendingAmbientType = type;
    return;
  }

  try {
    const master = ctx.createGain();
    const targetGain = 0.05;
    master.gain.setValueAtTime(0, ctx.currentTime);
    master.gain.linearRampToValueAtTime(targetGain, ctx.currentTime + 2.0); // 2s fade-in
    master.connect(ctx.destination);

    const droneFreq =
      type === 'menu' ? 55 :
      type === 'wind' ? 42 :
      type === 'rain' ? 50 : 65;
    const windCutoff =
      type === 'menu' ? 400 :
      type === 'wind' ? 700 :
      type === 'rain' ? 500 : 350;
    const droneGainVal =
      type === 'wind' ? 0.2 : 0.3; // coastal wind feels less grounded

    // Low drone oscillator (sine, very quiet)
    const drone = ctx.createOscillator();
    drone.type = 'sine';
    drone.frequency.setValueAtTime(droneFreq, ctx.currentTime);
    const droneGain = ctx.createGain();
    droneGain.gain.setValueAtTime(droneGainVal, ctx.currentTime);
    drone.connect(droneGain);
    droneGain.connect(master);
    drone.start(ctx.currentTime);

    // Second harmonic at 2× freq, even quieter
    const harmonic = ctx.createOscillator();
    harmonic.type = 'sine';
    harmonic.frequency.setValueAtTime(droneFreq * 2, ctx.currentTime);
    const harmonicGain = ctx.createGain();
    harmonicGain.gain.setValueAtTime(0.08, ctx.currentTime);
    harmonic.connect(harmonicGain);
    harmonicGain.connect(master);
    harmonic.start(ctx.currentTime);

    // Wind / rain noise layer
    const noiseSource = createWindNoise(ctx, master, windCutoff);

    const session: AmbientSession = {
      masterGain: master,
      oscillators: [drone, harmonic],
      noiseSource,
      birdTimer: null,
    };

    ambientSession = session;

    if (type === 'forest') {
      scheduleBirds(ctx, master, session);
    } else if (type === 'rain') {
      scheduleRainDrops(ctx, master, session);
    }
    // 'wind' and 'menu': no stochastic events — pure noise + drone
  } catch {
    // Silent-fail — audio is non-critical
  }
}

/**
 * Map a biome ID to the nearest available AmbientType.
 * Exported so main.ts can call startAmbient(biomeToAmbient(chosenBiome)).
 */
export function biomeToAmbient(biomeId: string): AmbientType {
  const map: Readonly<Record<string, AmbientType>> = {
    cotes_sauvages:    'wind',    // coastal cliffs — sea wind
    foret_broceliande: 'forest',  // deep forest — birds + drone
    marais_korrigans:  'rain',    // swamp — rain drops + mist
    landes_bruyere:    'wind',    // moorland — exposed wind
    cercles_pierres:   'wind',    // open stone circles — wind
    villages_celtes:   'forest',  // sheltered village — ambient forest
    collines_dolmens:  'wind',    // hilltop dolmens — wind
    iles_mystiques:    'wind',    // islands — sea wind
  };
  return map[biomeId] ?? 'forest';
}

/**
 * T066 — Stop ambient audio with a short fade-out.
 */
export function stopAmbient(): void {
  if (!ambientSession) return;

  const session = ambientSession;
  ambientSession = null;

  // Cancel bird timer
  if (session.birdTimer !== null) {
    clearTimeout(session.birdTimer);
    session.birdTimer = null;
  }

  const ctx = sharedCtx;
  if (!ctx) return;

  try {
    const now = ctx.currentTime;
    const fadeEnd = now + 1.5;

    // Fade master gain to 0
    session.masterGain.gain.cancelScheduledValues(now);
    session.masterGain.gain.setValueAtTime(session.masterGain.gain.value, now);
    session.masterGain.gain.linearRampToValueAtTime(0, fadeEnd);

    // Stop oscillators and noise after fade
    setTimeout(() => {
      try {
        for (const osc of session.oscillators) {
          osc.stop();
        }
        if (session.noiseSource) {
          session.noiseSource.stop();
        }
        session.masterGain.disconnect();
      } catch {
        // Already stopped — ignore
      }
    }, 1600);
  } catch {
    // Silent fail
  }
}

// ── SFX Manager init ─────────────────────────────────────────────────────────

/** T072: Queue ambient type when AudioContext is suspended at call time. */
let pendingAmbientType: AmbientType | null = null;

export function initSFXManager(): void {
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

  // T072: Resume context on first user interaction, then retry any pending ambient
  const resumeOnInteraction = (): void => {
    if (sharedCtx && sharedCtx.state === 'suspended') {
      sharedCtx.resume().then(() => {
        // Retry queued ambient now that context is running
        if (pendingAmbientType !== null && ambientSession === null) {
          const type = pendingAmbientType;
          pendingAmbientType = null;
          startAmbient(type);
        }
      }).catch(() => undefined);
    }
  };

  window.addEventListener('merlin_sfx', handleSFX);
  document.addEventListener('click', resumeOnInteraction, { once: true });
  document.addEventListener('keydown', resumeOnInteraction, { once: true });
}
