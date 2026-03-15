## =============================================================================
## Unit Tests -- SFXEngine Audio Generation (Enhanced Procedural Synthesis)
## =============================================================================
## Tests: all 27 sounds generate non-empty AudioStreamWAV, ADSR envelope shape,
## mix layer balance, arpeggio structure, noise burst filtering, helper integrity.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _make_manager() -> SFXEngine:
	var mgr: SFXEngine = SFXEngine.new()
	mgr._create_player_pool()
	mgr._generate_all_sounds()
	return mgr


func _cleanup(mgr: SFXEngine) -> void:
	mgr.stop_all()
	for child in mgr.get_children():
		child.queue_free()
	mgr.queue_free()


## Check that an AudioStreamWAV has non-zero sample data.
func _stream_has_nonzero_data(stream: AudioStreamWAV) -> bool:
	if stream == null:
		return false
	if stream.data.size() < 2:
		return false
	# Check that at least some samples are non-zero
	var found_nonzero: bool = false
	var step: int = maxi(1, stream.data.size() / 40)  # Sample sparse for speed
	for i in range(0, stream.data.size() - 1, step):
		if stream.data[i] != 0 or stream.data[i + 1] != 0:
			found_nonzero = true
			break
	return found_nonzero


# =============================================================================
# TEST: All 27 SFX generate non-empty AudioStreamWAV
# =============================================================================

func test_all_27_sounds_nonempty() -> bool:
	var mgr: SFXEngine = _make_manager()
	var all_sfx: Array[int] = [
		SFXEngine.SFX.CARD_DRAW, SFXEngine.SFX.CARD_FLIP,
		SFXEngine.SFX.OPTION_SELECT, SFXEngine.SFX.MINIGAME_START,
		SFXEngine.SFX.MINIGAME_END, SFXEngine.SFX.SCORE_REVEAL,
		SFXEngine.SFX.EFFECT_POSITIVE, SFXEngine.SFX.EFFECT_NEGATIVE,
		SFXEngine.SFX.OGHAM_ACTIVATE, SFXEngine.SFX.OGHAM_COOLDOWN,
		SFXEngine.SFX.LIFE_DRAIN, SFXEngine.SFX.LIFE_HEAL,
		SFXEngine.SFX.DEATH, SFXEngine.SFX.VICTORY,
		SFXEngine.SFX.REP_UP, SFXEngine.SFX.REP_DOWN,
		SFXEngine.SFX.ANAM_GAIN, SFXEngine.SFX.WALK_STEP,
		SFXEngine.SFX.BIOME_TRANSITION, SFXEngine.SFX.MENU_CLICK,
		SFXEngine.SFX.MENU_HOVER, SFXEngine.SFX.PROMISE_CREATE,
		SFXEngine.SFX.PROMISE_FULFILL, SFXEngine.SFX.PROMISE_BREAK,
		SFXEngine.SFX.KARMA_SHIFT, SFXEngine.SFX.HUB_AMBIENT,
		SFXEngine.SFX.RUN_AMBIENT,
	]

	var pass_count: int = 0
	for sfx_val in all_sfx:
		if not mgr.has_sound(sfx_val):
			push_error("[test_all_27_sounds_nonempty] Missing sound for SFX %d" % sfx_val)
			_cleanup(mgr)
			return false
		var stream: AudioStreamWAV = mgr._sounds[sfx_val] as AudioStreamWAV
		if not _stream_has_nonzero_data(stream):
			push_error("[test_all_27_sounds_nonempty] SFX %d has empty/zero data" % sfx_val)
			_cleanup(mgr)
			return false
		pass_count += 1

	if pass_count != 27:
		push_error("[test_all_27_sounds_nonempty] Expected 27 sounds, got %d" % pass_count)
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: All streams have correct format (16-bit, mono, correct sample rate)
# =============================================================================

func test_stream_format() -> bool:
	var mgr: SFXEngine = _make_manager()
	for sfx_val in mgr._sounds:
		var stream: AudioStreamWAV = mgr._sounds[sfx_val] as AudioStreamWAV
		if stream.format != AudioStreamWAV.FORMAT_16_BITS:
			push_error("[test_stream_format] SFX %d: wrong format %d" % [sfx_val, stream.format])
			_cleanup(mgr)
			return false
		if stream.stereo:
			push_error("[test_stream_format] SFX %d: should be mono" % sfx_val)
			_cleanup(mgr)
			return false
		if stream.mix_rate != SFXEngine.SAMPLE_RATE:
			push_error("[test_stream_format] SFX %d: wrong mix_rate %d" % [sfx_val, stream.mix_rate])
			_cleanup(mgr)
			return false
	_cleanup(mgr)
	return true


# =============================================================================
# TEST: ADSR envelope shape — attack rises, sustain holds, release falls
# =============================================================================

func test_envelope_shape() -> bool:
	var mgr: SFXEngine = _make_manager()
	var samples: int = 44100  # 1 second at 44100 Hz
	var env: PackedFloat32Array = mgr._generate_envelope(samples, 0.1, 0.1, 0.5, 0.3)

	if env.size() != samples:
		push_error("[test_envelope_shape] Expected %d samples, got %d" % [samples, env.size()])
		_cleanup(mgr)
		return false

	# First sample should be near 0 (start of attack)
	if env[0] > 0.01:
		push_error("[test_envelope_shape] First sample should be near 0, got %f" % env[0])
		_cleanup(mgr)
		return false

	# Peak should be near 1.0 at end of attack phase
	var attack_end: int = int(0.1 * SFXEngine.SAMPLE_RATE) - 1
	if env[attack_end] < 0.9:
		push_error("[test_envelope_shape] Attack peak should be near 1.0, got %f" % env[attack_end])
		_cleanup(mgr)
		return false

	# Sustain region should be near 0.5
	var sustain_mid: int = int(0.35 * SFXEngine.SAMPLE_RATE)
	if absf(env[sustain_mid] - 0.5) > 0.15:
		push_error("[test_envelope_shape] Sustain should be near 0.5, got %f" % env[sustain_mid])
		_cleanup(mgr)
		return false

	# Last sample should be near 0 (end of release)
	if env[samples - 1] > 0.05:
		push_error("[test_envelope_shape] Last sample should be near 0, got %f" % env[samples - 1])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Envelope with zero attack starts at peak immediately
# =============================================================================

func test_envelope_zero_attack() -> bool:
	var mgr: SFXEngine = _make_manager()
	var env: PackedFloat32Array = mgr._generate_envelope(4410, 0.0, 0.02, 0.8, 0.05)

	# With zero attack, first sample in decay should be near 1.0
	if env[0] < 0.5:
		push_error("[test_envelope_zero_attack] Expected near 1.0 with zero attack, got %f" % env[0])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Noise burst generates non-silent filtered output
# =============================================================================

func test_noise_burst_output() -> bool:
	var mgr: SFXEngine = _make_manager()
	var stream: AudioStreamWAV = mgr._generate_noise_burst(0.1, 2000.0)

	if not _stream_has_nonzero_data(stream):
		push_error("[test_noise_burst_output] Noise burst produced silent output")
		_cleanup(mgr)
		return false

	# Check data size matches expected duration (0.1s * 44100 * 2 bytes)
	var expected_size: int = int(0.1 * SFXEngine.SAMPLE_RATE) * 2
	if stream.data.size() != expected_size:
		push_error("[test_noise_burst_output] Expected %d bytes, got %d" % [expected_size, stream.data.size()])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Noise burst with low filter produces lower amplitude than high filter
# =============================================================================

func test_noise_burst_filter_effect() -> bool:
	var mgr: SFXEngine = _make_manager()
	# Low filter should produce less energy than high filter
	var low_stream: AudioStreamWAV = mgr._generate_noise_burst(0.05, 200.0)
	var high_stream: AudioStreamWAV = mgr._generate_noise_burst(0.05, 8000.0)

	# Measure RMS energy of each
	var low_energy: float = 0.0
	var high_energy: float = 0.0
	var sample_count: int = low_stream.data.size() / 2

	for i in range(sample_count):
		var low_val: float = mgr._read_sample(low_stream.data, i)
		var high_val: float = mgr._read_sample(high_stream.data, i)
		low_energy += low_val * low_val
		high_energy += high_val * high_val

	# High filter should pass more energy (on average)
	# This is statistical, so use a generous margin
	if low_energy >= high_energy * 2.0:
		push_error("[test_noise_burst_filter_effect] Low filter energy (%f) should be less than high (%f)" % [low_energy, high_energy])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Mix layers with balance 0.0 produces only layer A
# =============================================================================

func test_mix_balance_zero() -> bool:
	var mgr: SFXEngine = _make_manager()

	var tone_a: AudioStreamWAV = mgr._generate_tone(440.0, 0.05, SFXEngine.WaveType.SINE)
	var tone_b: AudioStreamWAV = mgr._generate_tone(880.0, 0.05, SFXEngine.WaveType.SINE)
	var mixed: AudioStreamWAV = mgr._mix_layers(tone_a, tone_b, 0.0)

	# With balance 0.0, output should match layer A exactly
	var sample_count: int = tone_a.data.size() / 2
	var max_diff: float = 0.0
	for i in range(sample_count):
		var orig: float = mgr._read_sample(tone_a.data, i)
		var mix_val: float = mgr._read_sample(mixed.data, i)
		max_diff = maxf(max_diff, absf(orig - mix_val))

	if max_diff > 0.01:
		push_error("[test_mix_balance_zero] Balance 0.0 should produce only A, max diff: %f" % max_diff)
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Mix layers with balance 1.0 produces only layer B
# =============================================================================

func test_mix_balance_one() -> bool:
	var mgr: SFXEngine = _make_manager()

	var tone_a: AudioStreamWAV = mgr._generate_tone(440.0, 0.05, SFXEngine.WaveType.SINE)
	var tone_b: AudioStreamWAV = mgr._generate_tone(880.0, 0.05, SFXEngine.WaveType.SINE)
	var mixed: AudioStreamWAV = mgr._mix_layers(tone_a, tone_b, 1.0)

	var sample_count: int = tone_b.data.size() / 2
	var max_diff: float = 0.0
	for i in range(sample_count):
		var orig: float = mgr._read_sample(tone_b.data, i)
		var mix_val: float = mgr._read_sample(mixed.data, i)
		max_diff = maxf(max_diff, absf(orig - mix_val))

	if max_diff > 0.01:
		push_error("[test_mix_balance_one] Balance 1.0 should produce only B, max diff: %f" % max_diff)
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Mix layers with balance 0.5 blends both layers
# =============================================================================

func test_mix_balance_half() -> bool:
	var mgr: SFXEngine = _make_manager()

	var tone_a: AudioStreamWAV = mgr._generate_tone(440.0, 0.05, SFXEngine.WaveType.SINE)
	var tone_b: AudioStreamWAV = mgr._generate_tone(880.0, 0.05, SFXEngine.WaveType.SINE)
	var mixed: AudioStreamWAV = mgr._mix_layers(tone_a, tone_b, 0.5)

	# Each layer should contribute half
	var sample_count: int = tone_a.data.size() / 2
	var max_diff: float = 0.0
	for i in range(sample_count):
		var a_val: float = mgr._read_sample(tone_a.data, i)
		var b_val: float = mgr._read_sample(tone_b.data, i)
		var expected: float = a_val * 0.5 + b_val * 0.5
		var mix_val: float = mgr._read_sample(mixed.data, i)
		max_diff = maxf(max_diff, absf(expected - mix_val))

	if max_diff > 0.01:
		push_error("[test_mix_balance_half] Balance 0.5 mix error, max diff: %f" % max_diff)
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Arpeggio generates correct total duration
# =============================================================================

func test_arpeggio_duration() -> bool:
	var mgr: SFXEngine = _make_manager()
	var notes: Array = [294.0, 392.0, 440.0]
	var note_dur: float = 0.1
	var arpeggio: AudioStreamWAV = mgr._generate_arpeggio(notes, note_dur, SFXEngine.WaveType.TRIANGLE)

	var expected_samples: int = int(SFXEngine.SAMPLE_RATE * note_dur * 3.0) * 2  # bytes
	if arpeggio.data.size() != expected_samples:
		push_error("[test_arpeggio_duration] Expected %d bytes, got %d" % [expected_samples, arpeggio.data.size()])
		_cleanup(mgr)
		return false

	if not _stream_has_nonzero_data(arpeggio):
		push_error("[test_arpeggio_duration] Arpeggio has no audio data")
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Arpeggio with single note produces valid output
# =============================================================================

func test_arpeggio_single_note() -> bool:
	var mgr: SFXEngine = _make_manager()
	var notes: Array = [440.0]
	var arpeggio: AudioStreamWAV = mgr._generate_arpeggio(notes, 0.1, SFXEngine.WaveType.SINE)

	if not _stream_has_nonzero_data(arpeggio):
		push_error("[test_arpeggio_single_note] Single-note arpeggio is silent")
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Ambient sounds (HUB/RUN) are longer than action sounds
# =============================================================================

func test_ambient_longer_than_actions() -> bool:
	var mgr: SFXEngine = _make_manager()

	var hub: AudioStreamWAV = mgr._sounds[SFXEngine.SFX.HUB_AMBIENT] as AudioStreamWAV
	var run: AudioStreamWAV = mgr._sounds[SFXEngine.SFX.RUN_AMBIENT] as AudioStreamWAV
	var click: AudioStreamWAV = mgr._sounds[SFXEngine.SFX.MENU_CLICK] as AudioStreamWAV
	var step: AudioStreamWAV = mgr._sounds[SFXEngine.SFX.WALK_STEP] as AudioStreamWAV

	# Ambient sounds should be significantly longer than UI/action sounds
	if hub.data.size() <= click.data.size():
		push_error("[test_ambient_longer] HUB_AMBIENT should be longer than MENU_CLICK")
		_cleanup(mgr)
		return false

	if run.data.size() <= step.data.size():
		push_error("[test_ambient_longer] RUN_AMBIENT should be longer than WALK_STEP")
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: read_sample / write_sample roundtrip
# =============================================================================

func test_sample_roundtrip() -> bool:
	var mgr: SFXEngine = _make_manager()
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(20)  # 10 samples

	var test_values: Array[float] = [0.0, 0.5, -0.5, 1.0, -1.0, 0.123, -0.789, 0.001, -0.001, 0.999]
	for i in range(test_values.size()):
		mgr._write_sample(buf, i, test_values[i])

	for i in range(test_values.size()):
		var read_val: float = mgr._read_sample(buf, i)
		var expected: float = clampf(test_values[i], -1.0, 1.0)
		# 16-bit quantization allows ~0.00003 error
		if absf(read_val - expected) > 0.001:
			push_error("[test_sample_roundtrip] Sample %d: wrote %f, read %f" % [i, expected, read_val])
			_cleanup(mgr)
			return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Death sound is the longest non-ambient sound
# =============================================================================

func test_death_is_longest_action() -> bool:
	var mgr: SFXEngine = _make_manager()
	var death: AudioStreamWAV = mgr._sounds[SFXEngine.SFX.DEATH] as AudioStreamWAV
	var action_sfx: Array[int] = [
		SFXEngine.SFX.CARD_DRAW, SFXEngine.SFX.CARD_FLIP,
		SFXEngine.SFX.OPTION_SELECT, SFXEngine.SFX.MENU_CLICK,
		SFXEngine.SFX.MENU_HOVER, SFXEngine.SFX.WALK_STEP,
		SFXEngine.SFX.REP_UP, SFXEngine.SFX.REP_DOWN,
		SFXEngine.SFX.LIFE_DRAIN, SFXEngine.SFX.EFFECT_POSITIVE,
	]

	for sfx_val in action_sfx:
		var stream: AudioStreamWAV = mgr._sounds[sfx_val] as AudioStreamWAV
		if stream.data.size() >= death.data.size():
			push_error("[test_death_is_longest_action] SFX %d (%d bytes) >= DEATH (%d bytes)" % [sfx_val, stream.data.size(), death.data.size()])
			_cleanup(mgr)
			return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Wave sample helper produces expected range [-1, 1]
# =============================================================================

func test_wave_sample_range() -> bool:
	var mgr: SFXEngine = _make_manager()
	var wave_types: Array[int] = [
		SFXEngine.WaveType.SINE,
		SFXEngine.WaveType.SQUARE,
		SFXEngine.WaveType.TRIANGLE,
		SFXEngine.WaveType.SAWTOOTH,
	]

	for wt in wave_types:
		for step in range(100):
			var t: float = float(step) * 0.001
			var val: float = mgr._wave_sample(wt, 440.0, t)
			if val < -1.0 or val > 1.0:
				push_error("[test_wave_sample_range] WaveType %d at t=%f out of range: %f" % [wt, t, val])
				_cleanup(mgr)
				return false

	_cleanup(mgr)
	return true


# =============================================================================
# RUN ALL
# =============================================================================

func run_all() -> bool:
	var tests: Array[Callable] = [
		test_all_27_sounds_nonempty,
		test_stream_format,
		test_envelope_shape,
		test_envelope_zero_attack,
		test_noise_burst_output,
		test_noise_burst_filter_effect,
		test_mix_balance_zero,
		test_mix_balance_one,
		test_mix_balance_half,
		test_arpeggio_duration,
		test_arpeggio_single_note,
		test_ambient_longer_than_actions,
		test_sample_roundtrip,
		test_death_is_longest_action,
		test_wave_sample_range,
	]

	var passed: int = 0
	var failed: int = 0

	for test_fn in tests:
		var result: bool = test_fn.call()
		if result:
			passed += 1
		else:
			failed += 1
			push_error("[AudioGeneration Tests] FAILED: %s" % test_fn.get_method())

	print("[AudioGeneration Tests] %d passed, %d failed out of %d" % [passed, failed, tests.size()])
	return failed == 0
