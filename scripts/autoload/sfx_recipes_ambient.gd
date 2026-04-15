## =============================================================================
## SFXRecipesAmbient — Procedural sound recipes: ambient, biome, dice, minigame, UX
## =============================================================================
## Split from SFXRecipes. Covers ambient/atmospheric, boot/CeltOS, quiz, dice,
## mini-game, souffle/perk, UX/scene atmospheric, and biome ambient sounds.
## =============================================================================

class_name SFXRecipesAmbient
extends RefCounted

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


# =============================================================================
# AMBIENT / ATMOSPHERIC SOUNDS
# =============================================================================

func gen_path_scratch() -> AudioStreamWAV:
	## Ink scratching on parchment — for map path drawing
	var dur := 0.06
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.6
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.12 * env
		var scratch := sin(TAU * 5000.0 * t + sin(TAU * 120.0 * t) * 3.0) * 0.06 * env
		SFXHelpers.write_sample(buf, i, noise + scratch)
	return SFXHelpers.make_stream(buf)


func gen_landmark_pop() -> AudioStreamWAV:
	## Small location marker appearing — soft pop
	var dur := 0.08
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 50.0) * sin(minf(t / 0.003, 1.0) * PI * 0.5)
		var val := sin(TAU * 1800.0 * t) * 0.12 * env
		val += sin(TAU * 900.0 * t) * 0.06 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_mist_breath() -> AudioStreamWAV:
	## Gentle breath of mist — very soft filtered noise
	var dur := 1.0
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.3
		var val := (_rng.randf() * 2.0 - 1.0) * 0.06 * env
		val += sin(TAU * 80.0 * t) * 0.02 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_aspect_shift() -> AudioStreamWAV:
	## Aspect gauge changing — tonal shift
	var dur := 0.15
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var val := sin(TAU * 440.0 * t) * 0.10 * env
		val += sin(TAU * 660.0 * t) * 0.05 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_aspect_up() -> AudioStreamWAV:
	## Aspect going up — rising pitch
	var dur := 0.18
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(400.0, 700.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_aspect_down() -> AudioStreamWAV:
	## Aspect going down — falling pitch
	var dur := 0.18
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(600.0, 300.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# BOOT / CELTOS SPECIFIC
# =============================================================================

func gen_boot_line() -> AudioStreamWAV:
	## Boot log line appearing — terminal blip
	var dur := 0.015
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 200.0)
		var val := sin(TAU * 2200.0 * t) * 0.10 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_boot_confirm() -> AudioStreamWAV:
	## Boot complete confirmation — satisfying double-beep
	var dur := 0.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var beep1 := sin(TAU * 880.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.03) * 40.0, 0.0, 1.0)
		var beep2 := sin(TAU * 1100.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.12) * 40.0, 0.0, 1.0)
		SFXHelpers.write_sample(buf, i, beep1 + beep2)
	return SFXHelpers.make_stream(buf)


func gen_convergence() -> AudioStreamWAV:
	## Blocks converging toward eyes — whooshing with building tension
	var dur := 0.80
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := t / dur  # Building up
		var freq := lerpf(100.0, 500.0, t / dur)
		var val := sin(TAU * freq * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		val += sin(TAU * freq * 3.0 * t) * 0.02 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_slit_glow() -> AudioStreamWAV:
	## Eye slit starting to glow — ethereal hum
	var dur := 1.2
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.35
		var val := sin(TAU * 220.0 * t) * 0.06 * env
		val += sin(TAU * 330.0 * t) * 0.04 * env
		val += sin(TAU * 440.0 * t) * 0.03 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# QUIZ SPECIFIC
# =============================================================================

func gen_choice_hover() -> AudioStreamWAV:
	## Hovering over a quiz choice — gentle tonal shift
	var dur := 0.05
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var val := sin(TAU * 1600.0 * t) * 0.08 * env
		val += sin(TAU * 2400.0 * t) * 0.03 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_choice_select() -> AudioStreamWAV:
	## Quiz choice confirmed — warm bell
	var dur := 0.25
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 8.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var val := sin(TAU * 880.0 * t) * 0.12 * env
		val += sin(TAU * 1320.0 * t) * 0.06 * env
		val += sin(TAU * 1760.0 * t) * 0.03 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_result_reveal() -> AudioStreamWAV:
	## Personality result reveal — dramatic chord
	var dur := 1.0
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 2.5) * sin(minf(t / 0.02, 1.0) * PI * 0.5)
		# C major chord: C4, E4, G4, C5
		var val := sin(TAU * 262.0 * t) * 0.08 * env
		val += sin(TAU * 330.0 * t) * 0.06 * env
		val += sin(TAU * 392.0 * t) * 0.06 * env
		val += sin(TAU * 524.0 * t) * 0.04 * env
		# Shimmer
		val += sin(TAU * 2000.0 * t) * 0.02 * exp(-t * 5.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_question_transition() -> AudioStreamWAV:
	## Moving to next question — soft page turn
	var dur := 0.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		var tone := sin(TAU * 300.0 * t) * 0.04 * env
		SFXHelpers.write_sample(buf, i, noise + tone)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# DICE SOUNDS (Phase 33)
# =============================================================================

func gen_dice_shake() -> AudioStreamWAV:
	## Dice rattling in hand — filtered noise + rapid ticks
	var dur := 0.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		# Filtered noise for rattle
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.12 * env
		# Rapid ticking (dice faces hitting)
		var tick_rate := 40.0
		var tick: float = sin(TAU * 3200.0 * t) * 0.06 * abs(sin(TAU * tick_rate * t)) * env
		SFXHelpers.write_sample(buf, i, noise + tick)
	return SFXHelpers.make_stream(buf)


func gen_dice_roll() -> AudioStreamWAV:
	## Dice bouncing on wood — 3-4 decaying taps
	var dur := 0.40
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		# 4 bounces at decreasing intervals and amplitude
		var val := 0.0
		var bounces := [0.0, 0.12, 0.22, 0.30]
		var amps := [0.25, 0.18, 0.12, 0.06]
		for b_idx in range(bounces.size()):
			var dt: float = t - bounces[b_idx]
			if dt >= 0.0 and dt < 0.08:
				var b_env := exp(-dt * 60.0)
				val += sin(TAU * 220.0 * dt) * amps[b_idx] * b_env
				val += (_rng.randf() * 2.0 - 1.0) * amps[b_idx] * 0.4 * exp(-dt * 100.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_dice_land() -> AudioStreamWAV:
	## Final dice landing — solid thud with wood overtone
	var dur := 0.10
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 50.0)
		var val := sin(TAU * 160.0 * t) * 0.30 * env
		val += sin(TAU * 320.0 * t) * 0.12 * exp(-t * 80.0)
		val += (_rng.randf() * 2.0 - 1.0) * 0.10 * exp(-t * 120.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_dice_crit_success() -> AudioStreamWAV:
	## Triumphant C major ascending chord — golden victory
	var dur := 0.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 3.0) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# C major arpeggio: C4 -> E4 -> G4 -> C5
		var n1 := sin(TAU * 262.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.0) * 12.0, 0.0, 1.0)
		var n2 := sin(TAU * 330.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.08) * 12.0, 0.0, 1.0)
		var n3 := sin(TAU * 392.0 * t) * 0.10 * clampf(1.0 - abs(t - 0.16) * 10.0, 0.0, 1.0)
		var n4 := sin(TAU * 524.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.24) * 8.0, 0.0, 1.0)
		# Shimmer overlay
		var shimmer := sin(TAU * 2000.0 * t) * 0.03 * env
		SFXHelpers.write_sample(buf, i, n1 + n2 + n3 + n4 + shimmer)
	return SFXHelpers.make_stream(buf)


func gen_dice_crit_fail() -> AudioStreamWAV:
	## Ominous descending drone — deep rumble
	var dur := 0.60
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.6
		var freq := lerpf(200.0, 60.0, t / dur)
		var val := sin(TAU * freq * t) * 0.15 * env
		val += sin(TAU * freq * 1.5 * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * env
		# Low rumble
		val += sin(TAU * 40.0 * t) * 0.04 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# MINI-GAME SOUNDS (Phase 33)
# =============================================================================

func gen_minigame_start() -> AudioStreamWAV:
	## Ascending chime — mini-game begins
	var dur := 0.30
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 6.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var freq := lerpf(600.0, 1200.0, t / dur)
		var val := sin(TAU * freq * t) * 0.12 * env
		val += sin(TAU * freq * 1.5 * t) * 0.05 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_minigame_success() -> AudioStreamWAV:
	## Short fanfare — two bright notes
	var dur := 0.40
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		# Note 1: G4 (short)
		var n1 := sin(TAU * 392.0 * t) * 0.10 * clampf(1.0 - abs(t - 0.05) * 15.0, 0.0, 1.0)
		# Note 2: C5 (longer, triumphant)
		var n2 := sin(TAU * 524.0 * t) * 0.14 * clampf(1.0 - abs(t - 0.18) * 6.0, 0.0, 1.0)
		var n2_h := sin(TAU * 1048.0 * t) * 0.04 * clampf(1.0 - abs(t - 0.18) * 6.0, 0.0, 1.0)
		SFXHelpers.write_sample(buf, i, n1 + n2 + n2_h)
	return SFXHelpers.make_stream(buf)


func gen_minigame_fail() -> AudioStreamWAV:
	## Dull thud — sad low tone
	var dur := 0.25
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 12.0)
		var val := sin(TAU * 150.0 * t) * 0.18 * env
		val += sin(TAU * 100.0 * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.05 * exp(-t * 30.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_minigame_tick() -> AudioStreamWAV:
	## Rapid tick for timers
	var dur := 0.03
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 200.0)
		var val := sin(TAU * 3000.0 * t) * 0.10 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_critical_alert() -> AudioStreamWAV:
	## Dramatic chord — critical choice incoming
	var dur := 0.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 3.5) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# Minor chord: A3, C4, E4 (dramatic tension)
		var val := sin(TAU * 220.0 * t) * 0.10 * env
		val += sin(TAU * 262.0 * t) * 0.08 * env
		val += sin(TAU * 330.0 * t) * 0.08 * env
		# Tremolo effect
		val *= 1.0 + sin(TAU * 6.0 * t) * 0.3
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)



# =============================================================================
# UX / SCENE ATMOSPHERIC SOUNDS
# =============================================================================

func gen_camera_focus() -> AudioStreamWAV:
	## Camera cinematic zoom — crisp shutter click + crystalline shimmer tail
	var dur := 0.35
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		# Sharp shutter click at t=0
		var click := sin(TAU * 3000.0 * t) * 0.18 * exp(-t * 80.0)
		click += (_rng.randf() * 2.0 - 1.0) * 0.08 * exp(-t * 150.0)
		# Shimmer tail (lens crystallizing into focus)
		var shimmer_env := exp(-t * 5.0) * clampf(1.0 - t * 3.0, 0.0, 1.0)
		var shimmer := sin(TAU * 4800.0 * t) * 0.05 * shimmer_env
		shimmer += sin(TAU * 6400.0 * t) * 0.02 * exp(-t * 9.0)
		SFXHelpers.write_sample(buf, i, click + shimmer)
	return SFXHelpers.make_stream(buf)


func gen_error() -> AudioStreamWAV:
	## Error / denied — soft dissonant buzz (minor 2nd interval)
	var dur := 0.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 12.0) * sin(minf(t / 0.02, 1.0) * PI * 0.5)
		# Dissonant minor 2nd: A2 + Bb2
		var val := sin(TAU * 110.0 * t) * 0.20 * env
		val += sin(TAU * 116.5 * t) * 0.15 * env
		val += sin(TAU * 220.0 * t) * 0.06 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_hub_enter() -> AudioStreamWAV:
	## Hub entry — Celtic D+A drone (bagpipe tonic+5th, detuned for warmth)
	var dur := 1.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.35
		# D3 + A3 drone, two detuned voices each (beating = warmth)
		var val := SFXHelpers.sq(147.0, t) * 0.07 * env       # D3 main drone
		val += SFXHelpers.sq(147.8, t) * 0.025 * env          # D3 +9 cents (beating)
		val += SFXHelpers.sq(220.0, t) * 0.05 * env           # A3 (5th — bagpipe)
		val += SFXHelpers.sq(220.7, t) * 0.018 * env          # A3 detuned
		# D4 triangle melody rising in second half
		val += SFXHelpers.tri(294.0, t) * 0.035 * clampf((t - 0.55) / 0.7, 0.0, 1.0) * env
		# Soft noise breath
		val += (_rng.randf() * 2.0 - 1.0) * 0.02 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_perk_confirm() -> AudioStreamWAV:
	## Perk confirmed — D pentatonic triangle chord (D4 A4 D5) + pixel shimmer
	var dur := 0.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 3.5) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# D pentatonic harp chord: D4, A4, D5 (triangle — Celtic warmth)
		var val := SFXHelpers.tri(294.0, t) * 0.09 * env   # D4 root
		val += SFXHelpers.tri(440.0, t) * 0.08 * env        # A4 (5th — Celtic)
		val += SFXHelpers.tri(587.0, t) * 0.06 * env        # D5 octave
		# Pixel square shimmer on D6
		val += SFXHelpers.sq(1174.0, t) * 0.015 * exp(-t * 9.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_biome_reveal() -> AudioStreamWAV:
	## Biome clock reveal — Celtic sweep A2->D3 (4th), soft square + breath
	var dur := 0.80
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.6
		var freq := lerpf(110.0, 147.0, t / dur)  # A2->D3 (Celtic perfect 4th)
		var val := SFXHelpers.sq(freq, t) * 0.06 * env
		val += SFXHelpers.sq(freq * 1.5, t) * 0.03 * env    # 5th above (E3/A3 area)
		val += SFXHelpers.tri(freq * 2.0, t) * 0.025 * env  # Octave, triangle for warmth
		# Low D rumble at start
		val += SFXHelpers.sq(73.4, t) * 0.025 * exp(-t * 3.5)
		val += (_rng.randf() * 2.0 - 1.0) * 0.02 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_partir_fanfare() -> AudioStreamWAV:
	## PARTIR — Celtic G Mixolydian arpeggio ascending (G4 A4 D5 G5 triangle)
	var dur := 0.65
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 2.2) * sin(minf(t / 0.02, 1.0) * PI * 0.5)
		# G Mixolydian ascending: G4(392) A4(440) D5(587) G5(784) — triangle
		var n1 := SFXHelpers.tri(392.0, t) * 0.09 * clampf(1.0 - abs(t - 0.00) * 14.0, 0.0, 1.0)
		var n2 := SFXHelpers.tri(440.0, t) * 0.09 * clampf(1.0 - abs(t - 0.09) * 12.0, 0.0, 1.0)
		var n3 := SFXHelpers.tri(587.0, t) * 0.11 * clampf(1.0 - abs(t - 0.19) * 10.0, 0.0, 1.0)
		var n4 := SFXHelpers.tri(784.0, t) * 0.12 * clampf(1.0 - abs(t - 0.30) * 8.0, 0.0, 1.0)
		# Square sparkle on final note
		var shimmer := SFXHelpers.sq(1568.0, t) * 0.012 * clampf((t - 0.25) * 10.0, 0.0, 1.0) * env
		SFXHelpers.write_sample(buf, i, (n1 + n2 + n3 + n4) * env + shimmer)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# BIOME AMBIENT SOUNDS — Procedural identity per biome (Phase 1 TransitionBiome)
# Celtic D Dorian anchoring: D4=294 E4=330 F4=349 G4=392 A4=440 B4=494 D5=587
# =============================================================================

func gen_amb_broceliande() -> AudioStreamWAV:
	## Broceliande forest — triangle D4+G4 soft 4th chord, slow breath modulation
	var dur := 1.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)                        # Full bell envelope
		var breath := 0.7 + 0.3 * sin(TAU * 0.9 * t)      # Slow forest sway 0.9Hz
		var val := SFXHelpers.tri(294.0, t) * 0.07 * env * breath    # D4 root
		val += SFXHelpers.tri(392.0, t) * 0.05 * env * breath        # G4 perfect 4th
		val += (_rng.randf() * 2.0 - 1.0) * 0.008 * env   # Very soft leaf rustle
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_amb_landes() -> AudioStreamWAV:
	## Landes wind — filtered noise with slow 0.7Hz amplitude swell
	var dur := 1.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var swell := 0.4 + 0.6 * sin(TAU * 0.7 * t)       # Wind gust 0.7Hz
		var edge_fade := sin(t / dur * PI)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.10 * swell * edge_fade
		# Low D drone under the wind (barely audible)
		noise += SFXHelpers.tri(147.0, t) * 0.015 * edge_fade
		SFXHelpers.write_sample(buf, i, noise)
	return SFXHelpers.make_stream(buf)


func gen_amb_cotes() -> AudioStreamWAV:
	## Cotes sauvages — wave rhythm: sine 55Hz with 0.4Hz amplitude LFO (ocean swell)
	var dur := 1.50
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var wave_lfo := 0.3 + 0.7 * pow(sin(TAU * 0.4 * t) * 0.5 + 0.5, 2.0)  # Cresting wave
		var edge_fade := sin(t / dur * PI)
		var val := sin(TAU * 55.0 * t) * 0.06 * wave_lfo * edge_fade  # Deep wave rumble
		val += (_rng.randf() * 2.0 - 1.0) * 0.03 * wave_lfo * edge_fade  # Foam hiss
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_amb_cercles() -> AudioStreamWAV:
	## Cercles de pierres — square D2 drone (73.4Hz), stone resonance, slow attack
	var dur := 1.20
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var attack := minf(t / 0.6, 1.0)                   # Stone slow resonance attack 0.6s
		var decay := 1.0 - maxf(0.0, (t - 0.6) / 0.6)     # Decay over last 0.6s
		var env := attack * decay
		var val := SFXHelpers.sq(73.4, t) * 0.055 * env              # D2 square stone
		val += SFXHelpers.tri(220.0, t) * 0.020 * env                # A3 overtone (Celtic 5th)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_amb_marais() -> AudioStreamWAV:
	## Marais des korrigans — F3 triangle croak burst + soft hiss ambience
	var dur := 0.80
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var croak_env := exp(-t * 5.5) * sin(minf(t / 0.025, 1.0) * PI * 0.5)  # Frog attack
		var val := SFXHelpers.tri(174.6, t) * 0.08 * croak_env       # F3 frog croak (Dorian minor 3rd)
		val += SFXHelpers.tri(220.0, t) * 0.025 * croak_env          # A3 (5th) harmonic
		val += (_rng.randf() * 2.0 - 1.0) * 0.015 * (1.0 - t / dur)  # Water hiss
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_amb_collines() -> AudioStreamWAV:
	## Collines aux dolmens — triangle G3->D4 wind glide (ascending 5th), hill breeze
	var dur := 1.00
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(196.0, 294.0, minf(t / 0.7, 1.0))  # G3->D4 over 0.7s
		var val := SFXHelpers.tri(freq, t) * 0.07 * env               # Wind pitch rise
		val += (_rng.randf() * 2.0 - 1.0) * 0.010 * env    # Grass rustle
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_amb_villages() -> AudioStreamWAV:
	## Villages celtes — narrow pulse crackle (hearth fire), 5% duty cycle
	var dur := 0.70
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.8
		# Random walk frequency for crackle texture (wood popping)
		var freq := 120.0 + _rng.randf_range(-30.0, 50.0)
		var val := SFXHelpers.pulse(freq, t, 0.05) * 0.04 * env      # Narrow pulse = sharp crackle
		val += (_rng.randf() * 2.0 - 1.0) * 0.020 * env   # Soft smoke hiss
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


# =============================================================================
# GAME FLOW SOUNDS — Card, encounter, outcome feedback
# =============================================================================

func gen_card_reveal() -> AudioStreamWAV:
	## Card flip reveal — sharp mid transient + crystal shimmer tail
	var dur := 0.30
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		# Sharp transient: narrow pulse at 2400Hz, fast exponential decay
		var click := SFXHelpers.pulse(2400.0, t, 0.15) * 0.14 * exp(-t * 80.0)
		click += (_rng.randf() * 2.0 - 1.0) * 0.05 * exp(-t * 120.0)
		# Crystal shimmer tail: high harmonics D6(1175) + A6(1760), slower decay
		var shimmer := sin(TAU * 1175.0 * t) * 0.04 * exp(-t * 12.0)
		shimmer += sin(TAU * 1760.0 * t) * 0.025 * exp(-t * 18.0)
		SFXHelpers.write_sample(buf, i, click + shimmer)
	return SFXHelpers.make_stream(buf)


func gen_confirm() -> AudioStreamWAV:
	## Positive confirmation — D4+A4 triangle chime (Celtic perfect 5th)
	var dur := 0.40
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * exp(-t * 3.0)
		var val := SFXHelpers.tri(294.0, t) * 0.09 * env   # D4 root
		val += SFXHelpers.tri(440.0, t) * 0.07 * env       # A4 perfect 5th
		val += SFXHelpers.tri(587.0, t) * 0.04 * env       # D5 octave shimmer
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_encounter() -> AudioStreamWAV:
	## Encounter tension swell — D minor chord slow attack, tremolo unease
	var dur := 0.60
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var attack := minf(t / 0.20, 1.0)
		var decay := 1.0 - maxf(0.0, (t - 0.40) / 0.20)
		var env := attack * decay
		# D minor: D3(147) + F3(174.6) + A3(220)
		var val := SFXHelpers.sq(147.0, t) * 0.07 * env
		val += SFXHelpers.tri(174.6, t) * 0.06 * env
		val += SFXHelpers.tri(220.0, t) * 0.05 * env
		# Slow tremolo at 5Hz for unease
		val *= 0.75 + 0.25 * sin(TAU * 5.0 * t)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_success() -> AudioStreamWAV:
	## Encounter success — D Dorian ascending arp: D4 G4 D5 (bright triangle)
	var dur := 0.45
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 2.5) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# Three staggered notes — D4(294) G4(392) D5(587)
		var n1 := SFXHelpers.tri(294.0, t) * 0.10 * clampf(1.0 - abs(t - 0.00) * 14.0, 0.0, 1.0)
		var n2 := SFXHelpers.tri(392.0, t) * 0.11 * clampf(1.0 - abs(t - 0.10) * 12.0, 0.0, 1.0)
		var n3 := SFXHelpers.tri(587.0, t) * 0.13 * clampf(1.0 - abs(t - 0.22) * 9.0, 0.0, 1.0)
		SFXHelpers.write_sample(buf, i, (n1 + n2 + n3) * env)
	return SFXHelpers.make_stream(buf)


func gen_fail() -> AudioStreamWAV:
	## Encounter fail — descending pitch buzz (350→100Hz) + noise burst
	var dur := 0.30
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := exp(-t * 7.0) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		var freq := lerpf(350.0, 100.0, t / dur)
		var val := SFXHelpers.sq(freq, t) * 0.12 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 40.0)
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_neutral() -> AudioStreamWAV:
	## Neutral notification — clean A5 sine beep, short bell envelope
	var dur := 0.12
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.5
		var val := sin(TAU * 880.0 * t) * 0.12 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_danger() -> AudioStreamWAV:
	## Danger alarm — low A2+Bb2 dissonant pair pulsed at 4Hz (urgency)
	var dur := 0.80
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.8
		# 4Hz pulse rhythm (alarm beat)
		var pulse_lfo := maxf(0.0, sin(TAU * 4.0 * t))
		# A2(110) + Bb2(116.5) dissonant minor 2nd
		var val := SFXHelpers.sq(110.0, t) * 0.10 * env * pulse_lfo
		val += SFXHelpers.sq(116.5, t) * 0.07 * env * pulse_lfo
		# Sub rumble
		val += sin(TAU * 55.0 * t) * 0.04 * env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)


func gen_biome_dissolve() -> AudioStreamWAV:
	## T.4 Dissolution burst — noise burst decaying + 5 random pixel plucks (D Dorian)
	var dur := 0.45
	var buf := SFXHelpers.alloc_buffer(dur)
	var count := SFXHelpers.sample_count(dur)
	var pluck_freqs: Array[float] = [294.0, 330.0, 392.0, 440.0, 587.0]  # D4 E4 G4 A4 D5
	for i in range(count):
		var t := float(i) / SFXHelpers.SAMPLE_RATE
		# Noise burst — fast decay
		var noise_env := maxf(0.0, 1.0 - t / 0.15) * 0.12
		var val := (_rng.randf() * 2.0 - 1.0) * noise_env
		# 5 pluck tones — each starts at a staggered time
		for p_idx in range(pluck_freqs.size()):
			var onset := float(p_idx) * 0.06
			var pt := t - onset
			if pt > 0.0 and pt < 0.25:
				var p_env := maxf(0.0, 1.0 - pt / 0.25)
				val += SFXHelpers.tri(pluck_freqs[p_idx], pt) * 0.06 * p_env * p_env
		SFXHelpers.write_sample(buf, i, val)
	return SFXHelpers.make_stream(buf)
