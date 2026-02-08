#!/usr/bin/env node
/**
 * Generate robotic voice WAV banks for ACVoicebox
 * Creates per-letter WAV files (a-z, th, sh, blank, longblank)
 * Each bank has a distinct robotic character
 */

const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 22050;
const BASE_DIR = path.join(__dirname, '..', 'addons', 'acvoicebox');

// Letter frequencies (Hz) - each letter maps to a distinct pitch
const LETTER_FREQS = {
  a: 220, b: 247, c: 262, d: 294, e: 330, f: 349, g: 392,
  h: 415, i: 440, j: 466, k: 494, l: 523, m: 554, n: 587,
  o: 622, p: 659, q: 698, r: 740, s: 784, t: 831, u: 880,
  v: 932, w: 988, x: 1047, y: 1109, z: 1175,
  th: 800, sh: 900,
};

function writeWav(filepath, samples, sampleRate) {
  const numSamples = samples.length;
  const byteRate = sampleRate * 2; // 16-bit mono
  const dataSize = numSamples * 2;
  const fileSize = 44 + dataSize;

  const buf = Buffer.alloc(fileSize);
  // RIFF header
  buf.write('RIFF', 0);
  buf.writeUInt32LE(fileSize - 8, 4);
  buf.write('WAVE', 8);
  // fmt chunk
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);      // chunk size
  buf.writeUInt16LE(1, 20);       // PCM
  buf.writeUInt16LE(1, 22);       // mono
  buf.writeUInt32LE(sampleRate, 24);
  buf.writeUInt32LE(byteRate, 28);
  buf.writeUInt16LE(2, 32);       // block align
  buf.writeUInt16LE(16, 34);      // bits per sample
  // data chunk
  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < numSamples; i++) {
    const val = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(val * 32767), 44 + i * 2);
  }
  fs.writeFileSync(filepath, buf);
}

// --- Bank: Robot Beep (square wave blips) ---
function generateRobotBeep(letter, freq) {
  const duration = 0.08;
  const numSamples = Math.floor(SAMPLE_RATE * duration);
  const samples = new Float64Array(numSamples);
  const fadeLen = Math.floor(numSamples * 0.15);

  for (let i = 0; i < numSamples; i++) {
    const t = i / SAMPLE_RATE;
    // Square wave
    const phase = (t * freq) % 1;
    let val = phase < 0.5 ? 0.6 : -0.6;
    // Add slight detune for thickness
    const phase2 = (t * freq * 1.01) % 1;
    val += (phase2 < 0.5 ? 0.15 : -0.15);
    // Fade in/out
    if (i < fadeLen) val *= i / fadeLen;
    if (i > numSamples - fadeLen) val *= (numSamples - i) / fadeLen;
    samples[i] = val;
  }
  return samples;
}

// --- Bank: Glitch Bot (bitcrushed noise + tone) ---
function generateGlitchBot(letter, freq) {
  const duration = 0.07;
  const numSamples = Math.floor(SAMPLE_RATE * duration);
  const samples = new Float64Array(numSamples);
  const fadeLen = Math.floor(numSamples * 0.1);
  const crushBits = 4;
  const crushStep = 1 / (1 << crushBits);

  for (let i = 0; i < numSamples; i++) {
    const t = i / SAMPLE_RATE;
    // Sine + noise
    let val = Math.sin(2 * Math.PI * freq * t) * 0.5;
    val += (Math.random() * 2 - 1) * 0.2;
    // Bitcrush
    val = Math.round(val / crushStep) * crushStep;
    // Fade
    if (i < fadeLen) val *= i / fadeLen;
    if (i > numSamples - fadeLen) val *= (numSamples - i) / fadeLen;
    samples[i] = val * 0.7;
  }
  return samples;
}

// --- Bank: Synth Whisper (filtered noise bursts) ---
function generateSynthWhisper(letter, freq) {
  const duration = 0.09;
  const numSamples = Math.floor(SAMPLE_RATE * duration);
  const samples = new Float64Array(numSamples);
  const fadeLen = Math.floor(numSamples * 0.2);

  // Simple resonant filter state
  let y1 = 0, y2 = 0;
  const f = freq / SAMPLE_RATE;
  const q = 0.7;
  const w = 2 * Math.PI * f;
  const a1 = -2 * Math.cos(w);
  const a2 = 1 - (w / q);

  for (let i = 0; i < numSamples; i++) {
    const noise = (Math.random() * 2 - 1) * 0.5;
    // 2-pole bandpass approximation
    const y = noise - a1 * y1 - a2 * y2;
    y2 = y1;
    y1 = y;
    let val = y * 0.6;
    // Fade
    if (i < fadeLen) val *= i / fadeLen;
    if (i > numSamples - fadeLen) val *= (numSamples - i) / fadeLen;
    samples[i] = Math.max(-1, Math.min(1, val));
  }
  return samples;
}

// --- Bank: Droid (FM synthesis, R2D2-like) ---
function generateDroid(letter, freq) {
  const duration = 0.1;
  const numSamples = Math.floor(SAMPLE_RATE * duration);
  const samples = new Float64Array(numSamples);
  const fadeLen = Math.floor(numSamples * 0.12);

  for (let i = 0; i < numSamples; i++) {
    const t = i / SAMPLE_RATE;
    // FM: carrier modulated by a swept modulator
    const modFreq = freq * 0.5 + (freq * 2 * t / duration);
    const modIndex = 3.0 * (1 - t / duration);
    const mod = Math.sin(2 * Math.PI * modFreq * t) * modIndex;
    let val = Math.sin(2 * Math.PI * freq * t + mod) * 0.55;
    // Fade
    if (i < fadeLen) val *= i / fadeLen;
    if (i > numSamples - fadeLen) val *= (numSamples - i) / fadeLen;
    samples[i] = val;
  }
  return samples;
}

// --- Blank/silence ---
function generateBlank(duration) {
  return new Float64Array(Math.floor(SAMPLE_RATE * duration));
}

// Bank definitions
const BANKS = {
  sounds_robot: { generator: generateRobotBeep, label: 'Robot Beep' },
  sounds_glitch: { generator: generateGlitchBot, label: 'Glitch Bot' },
  sounds_whisper: { generator: generateSynthWhisper, label: 'Synth Whisper' },
  sounds_droid: { generator: generateDroid, label: 'Droid (R2D2)' },
};

// Generate all banks
for (const [bankDir, bank] of Object.entries(BANKS)) {
  const dir = path.join(BASE_DIR, bankDir);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  console.log(`Generating ${bank.label} (${bankDir})...`);

  for (const [letter, freq] of Object.entries(LETTER_FREQS)) {
    const samples = bank.generator(letter, freq);
    writeWav(path.join(dir, `${letter}.wav`), samples, SAMPLE_RATE);
  }

  // Blanks
  writeWav(path.join(dir, 'blank.wav'), generateBlank(0.04), SAMPLE_RATE);
  writeWav(path.join(dir, 'longblank.wav'), generateBlank(0.12), SAMPLE_RATE);

  const count = Object.keys(LETTER_FREQS).length + 2;
  console.log(`  -> ${count} files in ${bankDir}/`);
}

console.log('\nDone! 4 robotic voice banks generated.');
