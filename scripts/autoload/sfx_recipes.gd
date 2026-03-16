## =============================================================================
## SFXRecipes — Procedural sound generation recipes for M.E.R.L.I.N.
## =============================================================================
## Extracted from SFXManager.gd. Each function generates one AudioStreamWAV.
## Uses SFXHelpers for stream building and waveform primitives.
## =============================================================================

class_name SFXRecipes
extends RefCounted

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


# =============================================================================
# UI SOUNDS
# =============================================================================

func gen_hover() -> AudioStreamWAV:
	## Pixel hover blip — G5 square wave (Celtic 5th, retro)
	var dur := 0.038
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 160.0)
		var val := SFXHelpers.sq(784.0, t) * 0.07 * env  # G5 — Celtic 5th above D
		val += SFXHelpers.sq(392.0, t) * 0.03 * env      # G4 sub-octave body
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_click() -> AudioStreamWAV:
	## Pixel click — pulse wave snap + noise burst (chiptune parchment)
	var dur := 0.06
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 100.0)
		var val := SFXHelpers.pulse(1200.0, t, 0.25) * 0.18 * env  # Pulse D5 area
		val += SFXHelpers.sq(600.0, t) * 0.08 * env                # Sub body D4-ish
		val += (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 220.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_slider_tick() -> AudioStreamWAV:
	## Tiny mechanical tick for slider notches
	var dur := 0.02
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 300.0)
		var val := sin(TAU * 3500.0 * t) * 0.12 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_button_appear() -> AudioStreamWAV:
	## Soft chime for button cascade appearance
	var dur := 0.12
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / 0.12 * PI) * 0.6
		var freq := 1800.0 + t * 2000.0
		var val := sin(TAU * freq * t) * 0.10 * env
		val += sin(TAU * freq * 1.5 * t) * 0.05 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# TRANSITION SOUNDS
# =============================================================================

func gen_whoosh() -> AudioStreamWAV:
	## Soft air whoosh for card swipe / scene transitions
	var dur := 0.30
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var noise := (_rng.randf() * 2.0 - 1.0)
		# Filtered noise: low-pass by averaging
		var freq_mod := 200.0 + sin(t * 8.0) * 100.0
		var val := noise * 0.18 * env
		val += sin(TAU * freq_mod * t) * 0.04 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_card_draw() -> AudioStreamWAV:
	## Card being drawn — paper slide sound
	var dur := 0.18
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := (1.0 - t / dur) * sin(t / dur * PI * 0.5)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.15
		var tone := sin(TAU * 400.0 * t) * 0.05
		var val := (noise + tone) * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_card_swipe() -> AudioStreamWAV:
	## Card swiped away — quick directional whoosh
	var dur := 0.22
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 8.0) * sin(minf(t / 0.05, 1.0) * PI * 0.5)
		var freq := lerpf(600.0, 200.0, t / dur)
		var val := sin(TAU * freq * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.14 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_scene_transition() -> AudioStreamWAV:
	## Scene transition — chiptune D3->A3 glide (Celtic 5th, square wave)
	var dur := 0.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(147.0, 220.0, t / dur)  # D3->A3 (Celtic perfect 5th)
		var val := SFXHelpers.sq(freq, t) * 0.05 * env
		val += SFXHelpers.sq(freq * 2.0, t) * 0.025 * env   # Octave above
		val += SFXHelpers.tri(freq * 3.0, t) * 0.015 * env  # 5th harmonic, triangle soft
		val += (_rng.randf() * 2.0 - 1.0) * 0.05 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# IMPACT SOUNDS
# =============================================================================

func gen_block_land() -> AudioStreamWAV:
	## Tetris-style block landing — thud + bounce overtone
	var dur := 0.10
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 60.0)
		var val := sin(TAU * 180.0 * t) * 0.30 * env
		val += sin(TAU * 360.0 * t) * 0.10 * exp(-t * 100.0)
		val += (_rng.randf() * 2.0 - 1.0) * 0.12 * exp(-t * 150.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_pixel_land() -> AudioStreamWAV:
	## Tiny pixel settling into place — micro-tick
	var dur := 0.025
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 250.0)
		var val := sin(TAU * 4000.0 * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.04 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_pixel_cascade() -> AudioStreamWAV:
	## Batch of pixels falling — rain-like patter
	var dur := 0.08
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := 3000.0 + sin(t * 80.0) * 1500.0
		var val := sin(TAU * freq * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.05 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_pixel_scatter() -> AudioStreamWAV:
	## Pixels scattering upward — ascending sweep with noise burst
	var dur := 0.12
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := 1.0 - (t / dur)  # Linear decay
		env *= env  # Quadratic falloff
		var freq := 1200.0 + (t / dur) * 3000.0  # Ascending sweep
		var val := sin(TAU * freq * t) * 0.05 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.06 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_accum_explode() -> AudioStreamWAV:
	## Snow/leaf pile explosion — crunchy burst
	var dur := 0.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 15.0)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.25 * env
		var tone := sin(TAU * 150.0 * t) * 0.10 * env
		tone += sin(TAU * 80.0 * t) * 0.08 * env
		SFXHelpers.write_sample(buf, i, noise + tone)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# MAGIC / MYSTICAL SOUNDS
# =============================================================================

func gen_ogham_chime() -> AudioStreamWAV:
	## Celtic harp pluck — triangle E4 + 5th B4 (Dorian tone, pixel decay)
	var dur := 0.55
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 5.5) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		# E4 = 330Hz (D Dorian 2nd — Celtic pentatonic tone)
		var val := SFXHelpers.tri(330.0, t) * 0.11 * env
		# B4 = 494Hz (perfect 5th above E4 — Celtic harmony)
		val += SFXHelpers.tri(494.0, t) * 0.05 * exp(-t * 8.0)
		# E5 octave shimmer (pixel square)
		val += SFXHelpers.sq(659.0, t) * 0.015 * exp(-t * 14.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_ogham_unlock() -> AudioStreamWAV:
	## Ogham unlock — D Dorian arpeggio ascending (D4 F4 A4 D5 triangle wave)
	var dur := 0.70
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.75
		# D Dorian: D4(294) F4(349) A4(440) D5(587) — triangle, staggered entry
		var n1 := SFXHelpers.tri(294.0, t) * 0.09 * clampf(1.0 - abs(t - 0.08) * 9.0, 0.0, 1.0)
		var n2 := SFXHelpers.tri(349.0, t) * 0.09 * clampf(1.0 - abs(t - 0.22) * 9.0, 0.0, 1.0)
		var n3 := SFXHelpers.tri(440.0, t) * 0.10 * clampf(1.0 - abs(t - 0.36) * 8.0, 0.0, 1.0)
		var n4 := SFXHelpers.tri(587.0, t) * 0.11 * clampf(1.0 - abs(t - 0.50) * 7.0, 0.0, 1.0)
		# Square sparkle on D5 arrival
		var shimmer := SFXHelpers.sq(587.0, t) * 0.015 * clampf((t - 0.44) * 12.0, 0.0, 1.0) * exp(-(t - 0.44) * 5.0)
		SFXHelpers.write_sample(buf, i, (n1 + n2 + n3 + n4 + shimmer) * env)
	return SFXHelpers.make_stream(buf)


func gen_bestiole_shimmer() -> AudioStreamWAV:
	## Bestiole — NES-style triangle shimmer (A pentatonic: A4 E5 A5)
	var dur := 0.80
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.5
		# A4=440 pentatonic shimmer (Celtic root)
		var val := SFXHelpers.tri(440.0, t) * 0.07 * env
		val += SFXHelpers.tri(659.0, t) * 0.04 * env   # E5 (5th above A4)
		val += SFXHelpers.tri(880.0, t) * 0.025 * env  # A5 (octave)
		# Pixel pulse sparkle — short bursts
		val += SFXHelpers.pulse(1320.0, t, 0.125) * 0.015 * env * (sin(t * 22.0) * 0.5 + 0.5)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_eye_open() -> AudioStreamWAV:
	## Eyes open — Celtic drone awakening: D1->D2 octave rise (deep square)
	var dur := 2.0
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.4
		var freq := lerpf(36.7, 73.4, t / dur)  # D1->D2 (deep Celtic root)
		var val := SFXHelpers.sq(freq, t) * 0.09 * env
		val += SFXHelpers.sq(freq * 1.5, t) * 0.04 * env  # A drone (5th — bagpipe)
		# D3 triangle melody emerging in second half
		val += SFXHelpers.tri(146.8, t) * 0.025 * clampf((t - 0.9) / 0.8, 0.0, 1.0) * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.025 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_flash_boom() -> AudioStreamWAV:
	## Blinding flash — bright impact then quick reverb
	var dur := 0.45
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 8.0)
		var attack := clampf(1.0 - t * 50.0, 0.0, 1.0)
		var val := (_rng.randf() * 2.0 - 1.0) * 0.35 * attack
		val += sin(TAU * 200.0 * t) * 0.20 * env
		val += sin(TAU * 100.0 * t) * 0.12 * env
		# High shimmer tail
		val += sin(TAU * 3000.0 * t) * 0.04 * exp(-t * 15.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_magic_reveal() -> AudioStreamWAV:
	## Magic reveal — D pentatonic ascending sweep (D4->G4->A4->D5, triangle)
	var dur := 0.70
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var nt := t / dur
		# Step through D pentatonic (D4 G4 A4 D5)
		var freq: float
		if nt < 0.25:
			freq = 294.0   # D4
		elif nt < 0.50:
			freq = 392.0   # G4
		elif nt < 0.75:
			freq = 440.0   # A4
		else:
			freq = 587.0   # D5
		var val := SFXHelpers.tri(freq, t) * 0.10 * env
		val += SFXHelpers.sq(freq * 2.0, t) * 0.02 * env  # Pixel octave shimmer
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_skill_activate() -> AudioStreamWAV:
	## Skill activate — Celtic square zap: D5->G4 descent (pixel sweep)
	var dur := 0.25
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 12.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var freq := lerpf(587.0, 392.0, t / dur)  # D5->G4 (Dorian descent)
		var val := SFXHelpers.sq(freq, t) * 0.12 * env
		val += SFXHelpers.tri(freq * 0.5, t) * 0.06 * env   # Sub-octave body
		val += (_rng.randf() * 2.0 - 1.0) * 0.04 * exp(-t * 30.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)
