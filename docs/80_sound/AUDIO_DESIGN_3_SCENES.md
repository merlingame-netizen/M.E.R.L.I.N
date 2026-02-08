# Audio Design Document -- 3 New Scenes

> M.E.R.L.I.N. -- Le Jeu des Oghams
> Audio Designer Agent Output
> Date: 2026-02-08

---

## Table of Contents

1. [Audio Bus Architecture](#1-audio-bus-architecture)
2. [Shared Procedural Utilities](#2-shared-procedural-utilities)
3. [Scene 1 -- SceneEveil (Awakening)](#3-scene-1----sceneeveil-awakening)
4. [Scene 2 -- SceneAntreMerlin (Merlin's Lair)](#4-scene-2----sceneantre-merlin-merlins-lair)
5. [Scene 3 -- TransitionBiome (Journey)](#5-scene-3----transitionbiome-journey)
6. [Implementation Priority](#6-implementation-priority)
7. [Testing Checklist](#7-testing-checklist)

---

## 1. Audio Bus Architecture

### Current State (default_bus_layout.tres)

```
Master
  Music
  SFX
```

### Required Additions

The existing layout is missing the **Ambience**, **Voice**, and **UI** buses required by
the agent spec and mix guide (`docs/80_sound/30_music/MERLIN_MUSIC_MIX_GUIDE.md`).

**Target layout:**

```
Master (0 dB)
  Music      (-6 dB baseline, ducked -3 dB during speech)
  Ambience   (-8 dB baseline, separate from SFX for independent control)
  SFX        (-6 dB baseline)
  Voice      (-3 dB baseline, highest priority)
  UI         (-10 dB baseline)
```

**Bus assignments per scene:**

| Sound Category             | Bus       |
|----------------------------|-----------|
| Drones, cave wind, fire    | Ambience  |
| Heartbeat, water drips     | Ambience  |
| Crystal hum, singing bowl  | SFX       |
| Parchment, chime           | SFX       |
| Wind transition, mist      | Ambience  |
| Merlin blip voice          | Voice     |
| Bestiole tinkle            | SFX       |
| Biome preview tones        | Music     |

---

## 2. Shared Procedural Utilities

All three scenes use procedural audio via `AudioStreamGenerator`. The following
utility patterns are based on the existing codebase (`IntroBoot.gd`, `IntroMerlinDialogue.gd`,
`RobotBlipVoice`).

### 2.1 Base Generator Setup

```gdscript
## Standard procedural audio setup -- reuse across all scenes
const SAMPLE_RATE := 44100

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

func _setup_generator(bus: String = "Ambience", buffer_length: float = 2.0) -> void:
    _player = AudioStreamPlayer.new()
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = buffer_length
    _player.stream = stream
    _player.bus = bus
    add_child(_player)
    _player.play()
    _playback = _player.get_stream_playback()
```

### 2.2 Wave Generation Primitives

```gdscript
## Sine wave sample at given phase
func _sine(phase: float) -> float:
    return sin(phase * TAU)

## Square wave (band-limited by coefficient softening)
func _square(phase: float) -> float:
    return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

## Triangle wave
func _triangle(phase: float) -> float:
    var p := fmod(phase, 1.0)
    return 4.0 * abs(p - 0.5) - 1.0

## White noise sample
func _noise() -> float:
    return randf() * 2.0 - 1.0

## Filtered noise (low-pass approximation via exponential smoothing)
var _lp_state: float = 0.0
func _filtered_noise(cutoff_normalized: float) -> float:
    var raw := _noise()
    _lp_state += cutoff_normalized * (raw - _lp_state)
    return _lp_state
```

### 2.3 Envelope Helpers

```gdscript
## Linear fade in/out envelope
## t: normalized time 0.0-1.0
## attack: fraction of duration for fade-in
## release: fraction of duration for fade-out
func _envelope(t: float, attack: float = 0.05, release: float = 0.1) -> float:
    var env := 1.0
    if t < attack:
        env = t / attack
    elif t > 1.0 - release:
        env = (1.0 - t) / release
    return clampf(env, 0.0, 1.0)

## Smooth exponential decay
func _exp_decay(t: float, rate: float = 3.0) -> float:
    return exp(-rate * t)
```

---

## 3. Scene 1 -- SceneEveil (Awakening)

### Narrative Context

The player awakens in total darkness. A deep, primal drone fills the silence.
Merlin's voice breaks through. A heartbeat-like pulse grows from nothing.
Eventually, light arrives with a warm tonal shift.

### 3.1 SOUND: Cave Drone (Ambient)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Layered sine waves + filtered noise |
| **Loop**          | Yes (continuous fill via `_process`) |
| **Volume**        | 0.06 (player volume_db: -12) |
| **Fade behavior** | Fade in over 4 seconds on scene enter |

**Frequency spec:**

```
Layer 1 (fundamental): 40 Hz sine -- deep sub-bass
Layer 2 (harmonic):    80 Hz sine, amplitude 0.4x -- octave body
Layer 3 (breath):      Filtered noise, cutoff 0.02 (very low), amplitude 0.3x
Layer 4 (drift):       Slow LFO modulating Layer 1 pitch +/- 2 Hz, rate 0.08 Hz
```

**GDScript implementation spec:**

```gdscript
## Cave drone -- continuous ambient
## Call in _process() to fill buffer

var drone_phase_1: float = 0.0
var drone_phase_2: float = 0.0
var drone_lfo_phase: float = 0.0
var drone_volume: float = 0.0          ## Animated 0->1 over 4s
var drone_target_volume: float = 1.0

const DRONE_BASE_FREQ := 40.0          ## Hz -- deep sub-bass
const DRONE_HARMONIC_FREQ := 80.0      ## Hz -- octave
const DRONE_LFO_RATE := 0.08           ## Hz -- very slow wobble
const DRONE_LFO_DEPTH := 2.0           ## Hz deviation
const DRONE_NOISE_CUTOFF := 0.02       ## Low-pass coefficient
const DRONE_AMPLITUDE := 0.06          ## Master volume

func _feed_cave_drone() -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    if frames <= 0:
        return

    ## Smooth volume ramp (4 second fade)
    drone_volume = lerpf(drone_volume, drone_target_volume, 0.0001)

    for i in range(mini(frames, 2048)):
        ## LFO modulation
        drone_lfo_phase += DRONE_LFO_RATE / float(SAMPLE_RATE)
        var freq_mod := sin(drone_lfo_phase * TAU) * DRONE_LFO_DEPTH

        ## Layer 1: fundamental
        drone_phase_1 += (DRONE_BASE_FREQ + freq_mod) / float(SAMPLE_RATE)
        var s1 := _sine(drone_phase_1) * 1.0

        ## Layer 2: harmonic
        drone_phase_2 += DRONE_HARMONIC_FREQ / float(SAMPLE_RATE)
        var s2 := _sine(drone_phase_2) * 0.4

        ## Layer 3: filtered wind noise
        var s3 := _filtered_noise(DRONE_NOISE_CUTOFF) * 0.3

        var sample := (s1 + s2 + s3) * DRONE_AMPLITUDE * drone_volume
        _playback.push_frame(Vector2(sample, sample))
```

---

### 3.2 SOUND: Heartbeat Pulse (Growing)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Low sine burst with sharp attack, exponential decay |
| **Loop**          | Timer-driven, interval decreasing over time |
| **Volume**        | Starts 0.02, grows to 0.08 |
| **Playback**      | One-shot per beat, triggered by Timer |

**Frequency spec:**

```
Lub:  55 Hz sine, duration 0.12s, sharp attack (0.01), exp decay rate 8.0
Dub:  45 Hz sine, duration 0.08s, softer, 0.15s after lub, amplitude 0.7x
Initial interval: 1.2 seconds (resting heartbeat)
Final interval:   0.6 seconds (anxious)
Growth rate:      Linear over 30 seconds of scene time
```

**GDScript implementation spec:**

```gdscript
## Heartbeat -- triggered periodically with decreasing interval

var heartbeat_intensity: float = 0.0  ## 0.0 -> 1.0 over scene duration
var heartbeat_interval: float = 1.2   ## Current interval in seconds

const HB_LUB_FREQ := 55.0
const HB_DUB_FREQ := 45.0
const HB_LUB_DURATION := 0.12
const HB_DUB_DURATION := 0.08
const HB_DUB_DELAY := 0.15
const HB_MIN_AMPLITUDE := 0.02
const HB_MAX_AMPLITUDE := 0.08
const HB_MIN_INTERVAL := 0.6
const HB_MAX_INTERVAL := 1.2

func _generate_heartbeat() -> void:
    ## "Lub" beat
    var amplitude := lerpf(HB_MIN_AMPLITUDE, HB_MAX_AMPLITUDE, heartbeat_intensity)
    _generate_beat_pulse(HB_LUB_FREQ, HB_LUB_DURATION, amplitude)

    ## Silence gap before "dub"
    _generate_silence(HB_DUB_DELAY)

    ## "Dub" beat (softer)
    _generate_beat_pulse(HB_DUB_FREQ, HB_DUB_DURATION, amplitude * 0.7)

func _generate_beat_pulse(freq: float, duration: float, amplitude: float) -> void:
    var samples := int(duration * float(SAMPLE_RATE))
    var phase := 0.0
    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _exp_decay(t, 8.0)
        if t < 0.01:
            env = t / 0.01  ## Sharp attack
        phase += freq / float(SAMPLE_RATE)
        var sample := _sine(phase) * env * amplitude
        _playback.push_frame(Vector2(sample, sample))

func _generate_silence(duration: float) -> void:
    var samples := int(duration * float(SAMPLE_RATE))
    for i in range(samples):
        _playback.push_frame(Vector2.ZERO)

## Call from Timer timeout, update interval:
func _on_heartbeat_timer_timeout() -> void:
    _generate_heartbeat()
    heartbeat_interval = lerpf(HB_MAX_INTERVAL, HB_MIN_INTERVAL, heartbeat_intensity)
    $HeartbeatTimer.wait_time = heartbeat_interval
```

---

### 3.3 SOUND: Warm Tonal Shift (Light Arrival)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Music |
| **Generation**    | Rising chord: 3 sines sweeping upward with harmonics |
| **Loop**          | No -- one-shot, 3.0 seconds |
| **Volume**        | 0.05 peak |
| **Fade behavior** | Slow attack (1.5s), sustain (0.5s), slow release (1.0s) |

**Frequency spec:**

```
Voice 1: 130.8 Hz -> 261.6 Hz (C3 -> C4) -- fundamental rising octave
Voice 2: 164.8 Hz -> 329.6 Hz (E3 -> E4) -- major third
Voice 3: 196.0 Hz -> 392.0 Hz (G3 -> G4) -- perfect fifth
Sweep: Exponential ease over 3.0 seconds
Envelope: attack 0.5 (1.5s), release 0.33 (1.0s)
```

**GDScript implementation spec:**

```gdscript
## Warm tonal shift -- one-shot when light arrives

const LIGHT_CHORD := [
    {"start": 130.8, "end": 261.6},  ## C3 -> C4
    {"start": 164.8, "end": 329.6},  ## E3 -> E4
    {"start": 196.0, "end": 392.0},  ## G3 -> G4
]
const LIGHT_DURATION := 3.0
const LIGHT_AMPLITUDE := 0.05

func _play_light_arrival() -> void:
    var samples := int(LIGHT_DURATION * float(SAMPLE_RATE))
    var phases := [0.0, 0.0, 0.0]

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _envelope(t, 0.5, 0.33)
        var sample := 0.0

        for v in range(3):
            ## Exponential frequency sweep (ease-in)
            var freq := lerpf(
                LIGHT_CHORD[v]["start"],
                LIGHT_CHORD[v]["end"],
                t * t  ## Ease-in quadratic
            )
            phases[v] += freq / float(SAMPLE_RATE)
            sample += _sine(phases[v]) * (1.0 / 3.0)

        sample *= env * LIGHT_AMPLITUDE
        _playback.push_frame(Vector2(sample, sample))
```

---

### 3.4 SOUND: Merlin Voice Breaks Silence

| Property          | Value |
|-------------------|-------|
| **Type**          | EXISTING SYSTEM (RobotBlipVoice / ACVoicebox) |
| **Bus**           | Voice |
| **Preset**        | "Merlin" (base_freq 380, variation 120, chirp 0.35) |
| **Special**       | First blips should be preceded by 0.5s silence after drone establishes |
| **Ducking**       | Drone volume reduced by 30% during speech |

**Integration note:**

```gdscript
## Before Merlin speaks in SceneEveil, duck the drone
func _merlin_speaks(text: String) -> void:
    drone_target_volume = 0.7  ## Duck drone 30%
    await get_tree().create_timer(0.3).timeout
    $RobotBlipVoice.speak_text(text)
    await $RobotBlipVoice.speech_finished
    drone_target_volume = 1.0  ## Restore
```

---

### SceneEveil -- Timeline Summary

```
Time (s)  Sound
0.0       [Silence -- true black]
0.5       Cave drone fades in (4s ramp)
4.0       Drone established
5.0       Heartbeat starts (slow, quiet)
8.0       Merlin's first words (drone ducks)
12.0      Heartbeat accelerating
20.0      Heartbeat near peak intensity
25.0      Light arrival chord begins
28.0      Warm tonal shift completes, drone pitch shifts up +5 Hz
30.0      Transition to next scene
```

---

## 4. Scene 2 -- SceneAntreMerlin (Merlin's Lair)

### Narrative Context

The player enters Merlin's lair -- a cave-workshop with crackling fire,
distant water, crystal formations, and ancient artifacts. This is the hub
scene with multiple interactive elements.

### 4.1 SOUND: Crackling Fire (Ambient Loop)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Filtered noise bursts with random timing |
| **Loop**          | Yes (continuous via `_process`) |
| **Volume**        | 0.04 |

**Spec:**

```
Base: Filtered noise, cutoff 0.08 (warm crackle, not hissy)
Pops: Random bursts every 0.3-1.5s
  - Duration: 0.005-0.015s
  - Volume spike: 2x-4x base
  - Frequency: Higher cutoff (0.15) for sharpness
Crackle envelope: Exponential decay, rate 15.0
Overall warmth: Add subtle 120 Hz sine undertone at 0.2x amplitude
```

**GDScript implementation spec:**

```gdscript
## Crackling fire -- continuous with random pops

var fire_pop_timer: float = 0.0
var fire_pop_interval: float = 0.8
var fire_pop_remaining: int = 0
const FIRE_BASE_CUTOFF := 0.08
const FIRE_POP_CUTOFF := 0.15
const FIRE_AMPLITUDE := 0.04
const FIRE_UNDERTONE_FREQ := 120.0
var fire_undertone_phase: float = 0.0
var _fire_lp_state: float = 0.0

func _feed_fire_crackle(delta: float) -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    if frames <= 0:
        return

    fire_pop_timer -= delta
    if fire_pop_timer <= 0.0:
        fire_pop_remaining = int(randf_range(0.005, 0.015) * SAMPLE_RATE)
        fire_pop_timer = randf_range(0.3, 1.5)

    for i in range(mini(frames, 2048)):
        var raw := _noise()
        var cutoff := FIRE_BASE_CUTOFF
        var amp_mult := 1.0

        if fire_pop_remaining > 0:
            cutoff = FIRE_POP_CUTOFF
            amp_mult = randf_range(2.0, 4.0) * _exp_decay(
                1.0 - float(fire_pop_remaining) / (0.01 * SAMPLE_RATE), 15.0
            )
            fire_pop_remaining -= 1

        _fire_lp_state += cutoff * (raw - _fire_lp_state)
        var sample := _fire_lp_state * FIRE_AMPLITUDE * amp_mult

        ## Warm undertone
        fire_undertone_phase += FIRE_UNDERTONE_FREQ / float(SAMPLE_RATE)
        sample += _sine(fire_undertone_phase) * FIRE_AMPLITUDE * 0.2

        _playback.push_frame(Vector2(sample, sample))
```

---

### 4.2 SOUND: Water Drips (Ambient)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | High-frequency sine pings with rapid decay |
| **Loop**          | Timer-driven, random intervals 2.0-6.0s |
| **Volume**        | 0.02 |
| **Stereo**        | Vary L/R per drip (pan -0.3 to +0.3) |

**Frequency spec:**

```
Each drip:
  Frequency: Random 1800-3200 Hz (high, crystalline)
  Duration:  0.04-0.08s
  Attack:    Instant (< 1ms)
  Decay:     Exponential, rate 20.0 (very fast)
  Second harmonic: freq * 2.6 at 0.15x amplitude (splash overtone)
  Stereo pan: Random per drip for spatial depth
```

**GDScript implementation spec:**

```gdscript
## Water drip -- triggered by timer

const DRIP_FREQ_MIN := 1800.0
const DRIP_FREQ_MAX := 3200.0
const DRIP_DURATION_MIN := 0.04
const DRIP_DURATION_MAX := 0.08
const DRIP_AMPLITUDE := 0.02
const DRIP_INTERVAL_MIN := 2.0
const DRIP_INTERVAL_MAX := 6.0

func _generate_water_drip() -> void:
    var freq := randf_range(DRIP_FREQ_MIN, DRIP_FREQ_MAX)
    var duration := randf_range(DRIP_DURATION_MIN, DRIP_DURATION_MAX)
    var samples := int(duration * float(SAMPLE_RATE))
    var phase := 0.0
    var phase_h := 0.0  ## Harmonic
    var pan := randf_range(-0.3, 0.3)

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _exp_decay(t, 20.0)

        phase += freq / float(SAMPLE_RATE)
        phase_h += (freq * 2.6) / float(SAMPLE_RATE)

        var sample := _sine(phase) * env * DRIP_AMPLITUDE
        sample += _sine(phase_h) * env * DRIP_AMPLITUDE * 0.15

        ## Simple stereo pan
        var left := sample * (1.0 - max(pan, 0.0))
        var right := sample * (1.0 + min(pan, 0.0))
        _playback.push_frame(Vector2(left, right))

func _on_drip_timer_timeout() -> void:
    _generate_water_drip()
    $DripTimer.wait_time = randf_range(DRIP_INTERVAL_MIN, DRIP_INTERVAL_MAX)
    $DripTimer.start()
```

---

### 4.3 SOUND: Crystal Hum (Ambient)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Layered high sines with slow beating |
| **Loop**          | Yes (continuous) |
| **Volume**        | 0.025 |

**Frequency spec:**

```
Layer 1: 528 Hz sine (C5, "crystal" frequency)
Layer 2: 530 Hz sine (2 Hz beating with Layer 1 -- creates ethereal shimmer)
Layer 3: 792 Hz sine (perfect fifth above, 0.3x amplitude)
LFO: 0.15 Hz modulating overall amplitude (gentle breathing)
```

**GDScript implementation spec:**

```gdscript
## Crystal hum -- continuous ethereal shimmer

var crystal_phase_1: float = 0.0
var crystal_phase_2: float = 0.0
var crystal_phase_3: float = 0.0
var crystal_lfo_phase: float = 0.0

const CRYSTAL_FREQ_1 := 528.0
const CRYSTAL_FREQ_2 := 530.0    ## 2 Hz beat frequency with F1
const CRYSTAL_FREQ_3 := 792.0    ## Perfect fifth
const CRYSTAL_LFO_RATE := 0.15   ## Breathing rate
const CRYSTAL_AMPLITUDE := 0.025

func _feed_crystal_hum() -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    if frames <= 0:
        return

    for i in range(mini(frames, 2048)):
        crystal_lfo_phase += CRYSTAL_LFO_RATE / float(SAMPLE_RATE)
        var lfo := 0.7 + 0.3 * _sine(crystal_lfo_phase)

        crystal_phase_1 += CRYSTAL_FREQ_1 / float(SAMPLE_RATE)
        crystal_phase_2 += CRYSTAL_FREQ_2 / float(SAMPLE_RATE)
        crystal_phase_3 += CRYSTAL_FREQ_3 / float(SAMPLE_RATE)

        var sample := _sine(crystal_phase_1) * 0.4
        sample += _sine(crystal_phase_2) * 0.4
        sample += _sine(crystal_phase_3) * 0.2

        sample *= lfo * CRYSTAL_AMPLITUDE
        _playback.push_frame(Vector2(sample, sample))
```

---

### 4.4 SOUND: Bestiole Tinkle/Chime

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | SFX |
| **Generation**    | Bright sine cluster with rapid shimmer |
| **Loop**          | No -- one-shot on Bestiole movement |
| **Volume**        | 0.03 |
| **Trigger**       | Bestiole position change, hover, or interaction |

**Frequency spec:**

```
Main tone:   880 Hz (A5) -- bright, clear
Shimmer 1:   1174 Hz (D6) -- major interval above
Shimmer 2:   1318 Hz (E6) -- adds sparkle
Duration:    0.15s
Attack:      0.02 (sharp)
Decay:       Exponential, rate 6.0
Random pitch variation: +/- 5% per trigger (keeps it alive)
```

**GDScript implementation spec:**

```gdscript
## Bestiole tinkle -- one-shot on movement

const TINKLE_BASE := 880.0
const TINKLE_SHIMMER_1 := 1174.0
const TINKLE_SHIMMER_2 := 1318.0
const TINKLE_DURATION := 0.15
const TINKLE_AMPLITUDE := 0.03

func _play_bestiole_tinkle() -> void:
    var pitch_var := randf_range(0.95, 1.05)
    var f1 := TINKLE_BASE * pitch_var
    var f2 := TINKLE_SHIMMER_1 * pitch_var
    var f3 := TINKLE_SHIMMER_2 * pitch_var

    var samples := int(TINKLE_DURATION * float(SAMPLE_RATE))
    var p1 := 0.0
    var p2 := 0.0
    var p3 := 0.0

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _exp_decay(t, 6.0)
        if t < 0.02 / TINKLE_DURATION:
            env *= t / (0.02 / TINKLE_DURATION)

        p1 += f1 / float(SAMPLE_RATE)
        p2 += f2 / float(SAMPLE_RATE)
        p3 += f3 / float(SAMPLE_RATE)

        var sample := _sine(p1) * 0.5
        sample += _sine(p2) * 0.3
        sample += _sine(p3) * 0.2

        sample *= env * TINKLE_AMPLITUDE
        _playback.push_frame(Vector2(sample, sample))
```

---

### 4.5 SOUND: Map Unfold (Parchment Rustling)

| Property          | Value |
|-------------------|-------|
| **Type**          | **FILE RECOMMENDED** (difficult to synthesize convincingly) |
| **Bus**           | SFX |
| **File path**     | `audio/sfx/ui/map_unfold.ogg` |
| **Duration**      | 0.8-1.2s |
| **Volume**        | player volume_db: -8 |
| **Playback**      | One-shot |

**If file unavailable -- procedural fallback:**

```
Filtered noise with rising cutoff (paper texture simulation)
Cutoff sweep: 0.03 -> 0.12 over 0.8s (sounds like unfolding)
Amplitude envelope: attack 0.1, sustain 0.5, release 0.3
Volume: 0.04
Layer subtle crinkle: Noise bursts (0.002s) at random intervals
```

**Procedural fallback GDScript:**

```gdscript
## Parchment unfold -- procedural fallback

const PARCH_DURATION := 0.8
const PARCH_AMPLITUDE := 0.04

func _play_parchment_unfold() -> void:
    var samples := int(PARCH_DURATION * float(SAMPLE_RATE))
    var lp := 0.0

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _envelope(t, 0.1, 0.3)
        var cutoff := lerpf(0.03, 0.12, t)  ## Rising cutoff = unfolding

        var raw := _noise()
        lp += cutoff * (raw - lp)
        var sample := lp * PARCH_AMPLITUDE * env

        ## Random crinkle bursts
        if randf() < 0.005:
            sample += _noise() * PARCH_AMPLITUDE * 2.0 * env

        _playback.push_frame(Vector2(sample, sample))
```

**Sourcing recommendation for file:**
Foley recording of paper/parchment being unfolded on a wooden surface.
Alternatives: freesound.org keywords "parchment unfold", "paper scroll", "map open".
Format: OGG Vorbis, mono, 44100 Hz, normalized -3 dB.

---

### 4.6 SOUND: Ogham Unlock (Singing Bowl Resonance)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | SFX |
| **Generation**    | Multi-harmonic resonance with slow decay |
| **Loop**          | No -- one-shot, 2.5s duration |
| **Volume**        | 0.06 (prominent -- this is a reward sound) |
| **Trigger**       | Ogham skill unlocked |

**Frequency spec:**

```
This emulates a singing bowl / bell strike:

Fundamental:  262 Hz (C4 -- grounded, druidic)
Partial 2:    524 Hz (octave, 0.6x amplitude)
Partial 3:    786 Hz (fifth above octave, 0.3x amplitude)
Partial 4:    1048 Hz (double octave, 0.15x amplitude)
Metallic:     1572 Hz (non-harmonic, 0.08x -- adds metallic color)

Attack:       Very fast (0.005s)
Decay:        Slow exponential, rate 1.2 (sustains for ~2.5s)
Beating:      Add 263 Hz tone at 0.2x for 1 Hz beat (mystical wobble)

Duration:     2.5s
```

**GDScript implementation spec:**

```gdscript
## Ogham unlock -- singing bowl resonance

const BOWL_PARTIALS := [
    {"freq": 262.0, "amp": 1.0},
    {"freq": 263.0, "amp": 0.2},    ## 1 Hz beating with fundamental
    {"freq": 524.0, "amp": 0.6},
    {"freq": 786.0, "amp": 0.3},
    {"freq": 1048.0, "amp": 0.15},
    {"freq": 1572.0, "amp": 0.08},  ## Metallic partial
]
const BOWL_DURATION := 2.5
const BOWL_AMPLITUDE := 0.06
const BOWL_DECAY_RATE := 1.2

func _play_ogham_unlock() -> void:
    var samples := int(BOWL_DURATION * float(SAMPLE_RATE))
    var phases := PackedFloat32Array()
    phases.resize(BOWL_PARTIALS.size())
    phases.fill(0.0)

    for i in range(samples):
        var t := float(i) / float(samples)

        ## Sharp attack, long decay
        var env := _exp_decay(t, BOWL_DECAY_RATE)
        if t < 0.002:
            env *= t / 0.002

        var sample := 0.0
        for p in range(BOWL_PARTIALS.size()):
            phases[p] += BOWL_PARTIALS[p]["freq"] / float(SAMPLE_RATE)
            sample += _sine(phases[p]) * BOWL_PARTIALS[p]["amp"]

        ## Normalize by sum of amplitudes
        sample /= 2.33  ## Sum of amps: 1.0+0.2+0.6+0.3+0.15+0.08
        sample *= env * BOWL_AMPLITUDE
        _playback.push_frame(Vector2(sample, sample))
```

---

### 4.7 SOUND: Biome Selection Tones

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Music |
| **Generation**    | Unique tone per biome (pentatonic scale, Celtic intervals) |
| **Loop**          | No -- one-shot on hover/select, 0.6s |
| **Volume**        | 0.04 (hover), 0.06 (select) |

**Biome frequency mapping (Celtic pentatonic -- D minor pentatonic):**

| Biome         | Hover Tone (Hz) | Note  | Character |
|---------------|-----------------|-------|-----------|
| Broceliande   | 293.7           | D4    | Earthy, grounded |
| Landes        | 349.2           | F4    | Open, windswept |
| Cotes         | 392.0           | G4    | Flowing, tidal |
| Villages      | 440.0           | A4    | Warm, human |
| Cercles       | 523.3           | C5    | Mystical, high |
| Marais        | 261.6           | C4    | Dark, murky |
| Collines      | 330.0           | E4    | Rolling, pastoral |

**GDScript implementation spec:**

```gdscript
## Biome tones -- one-shot on hover/select

const BIOME_TONES := {
    "broceliande": 293.7,
    "landes": 349.2,
    "cotes": 392.0,
    "villages": 440.0,
    "cercles": 523.3,
    "marais": 261.6,
    "collines": 330.0,
}

const BIOME_TONE_DURATION := 0.6
const BIOME_HOVER_AMP := 0.04
const BIOME_SELECT_AMP := 0.06

func _play_biome_tone(biome_name: String, is_select: bool = false) -> void:
    if not BIOME_TONES.has(biome_name):
        return

    var freq: float = BIOME_TONES[biome_name]
    var amp: float = BIOME_SELECT_AMP if is_select else BIOME_HOVER_AMP
    var samples := int(BIOME_TONE_DURATION * float(SAMPLE_RATE))
    var phase := 0.0
    var phase_fifth := 0.0  ## Perfect fifth for richness

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _envelope(t, 0.08, 0.4)

        phase += freq / float(SAMPLE_RATE)
        phase_fifth += (freq * 1.5) / float(SAMPLE_RATE)

        var sample := _sine(phase) * 0.7
        sample += _sine(phase_fifth) * 0.3  ## Gentle fifth
        sample *= env * amp

        _playback.push_frame(Vector2(sample, sample))
```

---

## 5. Scene 3 -- TransitionBiome (Journey)

### Narrative Context

The player leaves the lair and travels through mist. Wind builds, peaks,
then fades as the destination biome's ambient preview takes over.

### 5.1 SOUND: Wind Sweep (Travel)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Filtered noise with dynamic cutoff modulation |
| **Loop**          | Yes (continuous, 5-8s scene duration) |
| **Volume**        | 0.0 -> 0.08 -> 0.0 (bell curve over scene) |

**Frequency spec:**

```
Base: White noise through low-pass filter
Cutoff modulation: Slow random walk between 0.04 and 0.15
  - Simulates gusts: cutoff spikes to 0.2 for 0.3s, 2-4 times during travel
Wind body: Additional 60 Hz sine at 0.1x (gives wind its "weight")
Volume curve: Sine envelope over entire scene duration (rise, peak, fall)
```

**GDScript implementation spec:**

```gdscript
## Wind sweep -- continuous, volume follows scene progress

var wind_cutoff: float = 0.06
var wind_target_cutoff: float = 0.06
var wind_gust_timer: float = 2.0
var wind_progress: float = 0.0  ## 0.0 -> 1.0 over scene
var _wind_lp_state: float = 0.0
var wind_body_phase: float = 0.0

const WIND_MAX_AMPLITUDE := 0.08
const WIND_BODY_FREQ := 60.0

func _feed_wind(delta: float) -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    if frames <= 0:
        return

    ## Gust timing
    wind_gust_timer -= delta
    if wind_gust_timer <= 0.0:
        wind_target_cutoff = 0.2  ## Gust spike
        wind_gust_timer = randf_range(1.5, 3.0)
    else:
        wind_target_cutoff = randf_range(0.04, 0.15)
    wind_cutoff = lerpf(wind_cutoff, wind_target_cutoff, 0.001)

    ## Volume follows scene arc (bell curve)
    var volume := sin(wind_progress * PI) * WIND_MAX_AMPLITUDE

    for i in range(mini(frames, 2048)):
        var raw := _noise()
        _wind_lp_state += wind_cutoff * (raw - _wind_lp_state)
        var sample := _wind_lp_state * volume

        ## Wind body rumble
        wind_body_phase += WIND_BODY_FREQ / float(SAMPLE_RATE)
        sample += _sine(wind_body_phase) * volume * 0.1

        _playback.push_frame(Vector2(sample, sample))
```

---

### 5.2 SOUND: Mist Layer (Soft White Noise)

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Ambience |
| **Generation**    | Very soft, heavily filtered white noise |
| **Loop**          | Yes (continuous, layered with wind) |
| **Volume**        | 0.02 (constant, under the wind) |

**Frequency spec:**

```
Very low cutoff: 0.015 (extremely soft, almost sub-audible texture)
No gusts -- perfectly smooth
Slight stereo decorrelation: L and R use independent noise sources
Purpose: Fills the sonic "floor" beneath wind, feels like moisture in air
```

**GDScript implementation spec:**

```gdscript
## Mist layer -- very soft filtered noise, stereo decorrelation

var _mist_lp_l: float = 0.0
var _mist_lp_r: float = 0.0
const MIST_CUTOFF := 0.015
const MIST_AMPLITUDE := 0.02

func _feed_mist() -> void:
    if _playback == null:
        return
    var frames := _playback.get_frames_available()
    if frames <= 0:
        return

    for i in range(mini(frames, 2048)):
        ## Independent L/R noise for stereo width
        _mist_lp_l += MIST_CUTOFF * (_noise() - _mist_lp_l)
        _mist_lp_r += MIST_CUTOFF * (_noise() - _mist_lp_r)

        var left := _mist_lp_l * MIST_AMPLITUDE
        var right := _mist_lp_r * MIST_AMPLITUDE
        _playback.push_frame(Vector2(left, right))
```

---

### 5.3 SOUND: Biome Arrival Preview

| Property          | Value |
|-------------------|-------|
| **Type**          | PROCEDURAL (AudioStreamGenerator) |
| **Bus**           | Music |
| **Generation**    | Reuses biome tone from Section 4.7, extended to 2.0s |
| **Loop**          | No -- one-shot at scene end, crossfades with wind |
| **Volume**        | 0.0 -> 0.05 (fade in as wind fades out) |

**Spec:**

Each biome gets its characteristic tone (from Section 4.7) played as a sustained
preview. The tone is extended to 2.0s with a longer release, and a second voice
at the octave below is added for depth.

```gdscript
## Biome arrival preview -- extended version of biome tone

const ARRIVAL_DURATION := 2.0
const ARRIVAL_AMPLITUDE := 0.05

func _play_biome_arrival(biome_name: String) -> void:
    if not BIOME_TONES.has(biome_name):
        return

    var freq: float = BIOME_TONES[biome_name]
    var samples := int(ARRIVAL_DURATION * float(SAMPLE_RATE))
    var phase := 0.0
    var phase_low := 0.0   ## Octave below
    var phase_fifth := 0.0 ## Perfect fifth

    for i in range(samples):
        var t := float(i) / float(samples)
        var env := _envelope(t, 0.3, 0.4)  ## Slow fade in, slow fade out

        phase += freq / float(SAMPLE_RATE)
        phase_low += (freq * 0.5) / float(SAMPLE_RATE)
        phase_fifth += (freq * 1.5) / float(SAMPLE_RATE)

        var sample := _sine(phase) * 0.5
        sample += _sine(phase_low) * 0.3    ## Depth
        sample += _sine(phase_fifth) * 0.2  ## Brightness

        sample *= env * ARRIVAL_AMPLITUDE
        _playback.push_frame(Vector2(sample, sample))
```

---

### TransitionBiome -- Timeline Summary

```
Time (s)  Sound
0.0       Wind begins rising from silence
0.5       Mist layer fades in (stays constant)
1.0       Wind building
2.5       Wind peak, possible gust
3.0       Wind peak sustained
4.0       Wind beginning to fade
5.0       Biome arrival tone fades in (overlaps with fading wind)
6.0       Wind nearly gone, biome tone sustaining
7.0       Biome tone fading, mist disappearing
7.5       [Scene transition to biome]
```

---

## 6. Implementation Priority

### Phase 1: Core Infrastructure (Day 1)

| Task | Effort |
|------|--------|
| Update `default_bus_layout.tres` with Ambience + Voice + UI buses | 10 min |
| Create `scripts/audio/procedural_audio_base.gd` with shared utilities | 30 min |
| Test generator setup on one AudioStreamPlayer | 15 min |

### Phase 2: SceneEveil (Day 1-2)

| Task | Effort |
|------|--------|
| Cave drone (continuous) | 1 hr |
| Heartbeat pulse (timer-driven) | 45 min |
| Light arrival chord (one-shot) | 30 min |
| Merlin voice ducking integration | 15 min |
| Timeline sequencing | 30 min |

### Phase 3: SceneAntreMerlin (Day 2-3)

| Task | Effort |
|------|--------|
| Fire crackle (continuous + pops) | 1 hr |
| Water drips (timer-driven) | 30 min |
| Crystal hum (continuous) | 30 min |
| Bestiole tinkle (event-driven) | 30 min |
| Parchment unfold (procedural fallback or file) | 30 min |
| Ogham singing bowl (one-shot) | 45 min |
| Biome selection tones (7 tones) | 30 min |

### Phase 4: TransitionBiome (Day 3)

| Task | Effort |
|------|--------|
| Wind sweep (continuous + gusts) | 45 min |
| Mist layer (continuous) | 15 min |
| Biome arrival preview | 20 min |
| Timeline sequencing | 20 min |

### Phase 5: Mixing and Polish (Day 4)

| Task | Effort |
|------|--------|
| Bus volume balancing across all scenes | 1 hr |
| Cross-scene transition testing | 30 min |
| Voice ducking verification | 15 min |
| Final playtest | 30 min |

**Total estimated effort: ~4 days**

---

## 7. Testing Checklist

### Per-Sound Tests

- [ ] Sound plays without clipping (peak < 1.0)
- [ ] Sound routes to correct AudioBus
- [ ] Volume is appropriate relative to other sounds
- [ ] Looping sounds have no audible seam/click
- [ ] One-shot sounds have clean attack and release (no pop)
- [ ] Procedural generation does not spike CPU (measure with profiler)

### Per-Scene Tests

- [ ] **SceneEveil**: Drone fades in smoothly, heartbeat grows, light chord resolves
- [ ] **SceneEveil**: Merlin voice ducks drone correctly
- [ ] **SceneAntreMerlin**: All ambient layers coexist without muddiness
- [ ] **SceneAntreMerlin**: Bestiole tinkle is audible above ambience
- [ ] **SceneAntreMerlin**: Ogham unlock is prominent and satisfying
- [ ] **SceneAntreMerlin**: Biome tones are distinguishable
- [ ] **TransitionBiome**: Wind bell curve is natural
- [ ] **TransitionBiome**: Mist adds depth without being noticeable
- [ ] **TransitionBiome**: Biome preview crossfades cleanly with wind

### Cross-Scene Tests

- [ ] SceneEveil -> SceneAntreMerlin transition (no audio pop)
- [ ] SceneAntreMerlin -> TransitionBiome transition (fire fades, wind rises)
- [ ] No two generators writing to same playback simultaneously (use separate players)
- [ ] Voice bus audible in all scenes

### Performance Tests

- [ ] CPU usage per generator < 2% in profiler
- [ ] No buffer underrun warnings in console
- [ ] Stable 60 FPS with all audio active
- [ ] Memory: No accumulation (generators reuse buffers)

### Mix Tests (Loudness Targets from Mix Guide)

| Bus      | Target    | Measured |
|----------|-----------|----------|
| Voice    | -12 LUFS  | ________ |
| Music    | -16 LUFS  | ________ |
| SFX      | -18 LUFS  | ________ |
| Ambience | -18 LUFS  | ________ |
| UI       | -20 LUFS  | ________ |

---

## Audio Report

### Area: Scene Audio Design (SceneEveil, SceneAntreMerlin, TransitionBiome)

### Sounds Designed

| Sound | Type | Duration | Bus | Notes |
|-------|------|----------|-----|-------|
| Cave drone | Procedural | Loop | Ambience | 40+80 Hz sines + filtered noise |
| Heartbeat | Procedural | 0.35s/beat | Ambience | 55+45 Hz lub-dub, accelerating |
| Light chord | Procedural | 3.0s | Music | C-E-G rising octave sweep |
| Fire crackle | Procedural | Loop | Ambience | Filtered noise + random pops |
| Water drips | Procedural | 0.04-0.08s | Ambience | 1800-3200 Hz pings, stereo |
| Crystal hum | Procedural | Loop | Ambience | 528/530 Hz beating + 792 Hz |
| Bestiole tinkle | Procedural | 0.15s | SFX | 880/1174/1318 Hz cluster |
| Parchment unfold | File (pref) / Procedural fallback | 0.8s | SFX | Noise with rising cutoff |
| Ogham singing bowl | Procedural | 2.5s | SFX | 6 partials, slow decay |
| Biome tones (x7) | Procedural | 0.6s | Music | D minor pentatonic |
| Wind sweep | Procedural | Loop | Ambience | Noise + gusts + 60 Hz body |
| Mist layer | Procedural | Loop | Ambience | Ultra-soft decorrelated noise |
| Biome arrival | Procedural | 2.0s | Music | Extended biome tone + octave |

### Implementation

- All procedural sounds use `AudioStreamGenerator` pattern from existing codebase
- Consistent with `IntroBoot.gd` and `RobotBlipVoice` approach
- 12 of 13 sounds are fully procedural (parchment has file alternative)

### Mixing Notes

- Bus layout needs 3 additions: Ambience, Voice, UI
- Voice ducking: -3 dB on Music and Ambience during Merlin speech
- Ambience bus: -8 dB baseline to sit beneath everything

### Dependencies

- AudioBus layout update (Ambience, Voice, UI buses)
- No external audio files required (all procedural except optional parchment)
- Bestiole movement signal for tinkle triggers
- Ogham unlock signal for singing bowl triggers
- Scene timeline/sequencer for SceneEveil and TransitionBiome

### Testing

- See full checklist in Section 7

---

*Generated by Audio Designer Agent for M.E.R.L.I.N. project*
