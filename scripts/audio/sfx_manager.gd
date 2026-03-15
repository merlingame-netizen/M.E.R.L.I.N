## ═══════════════════════════════════════════════════════════════════════════════
## SFXManager — Phase 9 Enum-Based Procedural Sound System (Enhanced)
## ═══════════════════════════════════════════════════════════════════════════════
## Typed enum API over an AudioStreamPlayer pool with procedural generation.
## Designed as autoload singleton. All sounds generated at startup — zero files.
## Enhanced with multi-layered synthesis: ADSR envelopes, filtered noise bursts,
## layer mixing, arpeggios, and richer per-sound generators.
##
## Usage:
##   SFXEngine.play(SFXEngine.SFX.CARD_DRAW)
##   SFXEngine.play(SFXEngine.SFX.OGHAM_ACTIVATE, -3.0, 1.2)
##   SFXEngine.set_sfx_enabled(false)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name SFXEngine

# ═══════════════════════════════════════════════════════════════════════════════
# SFX ENUM — All game sound effects
# ═══════════════════════════════════════════════════════════════════════════════

enum SFX {
	CARD_DRAW,
	CARD_FLIP,
	OPTION_SELECT,
	MINIGAME_START,
	MINIGAME_END,
	SCORE_REVEAL,
	EFFECT_POSITIVE,
	EFFECT_NEGATIVE,
	OGHAM_ACTIVATE,
	OGHAM_COOLDOWN,
	LIFE_DRAIN,
	LIFE_HEAL,
	DEATH,
	VICTORY,
	REP_UP,
	REP_DOWN,
	ANAM_GAIN,
	WALK_STEP,
	BIOME_TRANSITION,
	MENU_CLICK,
	MENU_HOVER,
	PROMISE_CREATE,
	PROMISE_FULFILL,
	PROMISE_BREAK,
	KARMA_SHIFT,
	HUB_AMBIENT,
	RUN_AMBIENT,
}

# ═══════════════════════════════════════════════════════════════════════════════
# WAVE TYPE — For procedural tone generation
# ═══════════════════════════════════════════════════════════════════════════════

enum WaveType {
	SINE,
	SQUARE,
	TRIANGLE,
	SAWTOOTH,
	NOISE,
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const SAMPLE_RATE: int = 44100
const POOL_SIZE: int = 8
const VOLUME_DB_MIN: float = -80.0
const VOLUME_DB_MAX: float = 6.0

## Volume category presets (linear 0.0-1.0)
const VOLUME_CATEGORIES: Dictionary = {
	"ui": 0.25,
	"gameplay": 0.30,
	"ambient": 0.15,
	"magic": 0.20,
	"transition": 0.22,
	"impact": 0.35,
}

## Maps each SFX to a volume category
const SFX_VOLUME_MAP: Dictionary = {
	SFX.CARD_DRAW: "transition",
	SFX.CARD_FLIP: "transition",
	SFX.OPTION_SELECT: "ui",
	SFX.MINIGAME_START: "gameplay",
	SFX.MINIGAME_END: "gameplay",
	SFX.SCORE_REVEAL: "gameplay",
	SFX.EFFECT_POSITIVE: "magic",
	SFX.EFFECT_NEGATIVE: "impact",
	SFX.OGHAM_ACTIVATE: "magic",
	SFX.OGHAM_COOLDOWN: "magic",
	SFX.LIFE_DRAIN: "impact",
	SFX.LIFE_HEAL: "magic",
	SFX.DEATH: "impact",
	SFX.VICTORY: "gameplay",
	SFX.REP_UP: "gameplay",
	SFX.REP_DOWN: "gameplay",
	SFX.ANAM_GAIN: "magic",
	SFX.WALK_STEP: "ambient",
	SFX.BIOME_TRANSITION: "transition",
	SFX.MENU_CLICK: "ui",
	SFX.MENU_HOVER: "ui",
	SFX.PROMISE_CREATE: "magic",
	SFX.PROMISE_FULFILL: "gameplay",
	SFX.PROMISE_BREAK: "impact",
	SFX.KARMA_SHIFT: "magic",
	SFX.HUB_AMBIENT: "ambient",
	SFX.RUN_AMBIENT: "ambient",
}

# Celtic scale reference (D Dorian = D E F G A B C D):
# D3=147  E3=165  F3=175  G3=196  A3=220  B3=247  C4=262
# D4=294  E4=330  F4=349  G4=392  A4=440  B4=494  C5=523  D5=587  G5=784

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _sounds: Dictionary = {}  # SFX enum value -> AudioStreamWAV
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _master_volume_db: float = 0.0
var _sfx_enabled: bool = true


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_rng.randomize()
	_create_player_pool()
	_generate_all_sounds()


func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Play a sound effect by enum. volume_db offsets from the category default.
func play(sfx: SFX, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_enabled:
		return
	if not _sounds.has(sfx):
		push_warning("[SFXManager] No sound generated for SFX %d" % sfx)
		return

	var player: AudioStreamPlayer = _get_next_player()
	player.stream = _sounds[sfx]
	player.pitch_scale = clampf(pitch_scale, 0.1, 4.0)

	var category_vol: float = _get_category_volume(sfx)
	var final_db: float = linear_to_db(category_vol) + _master_volume_db + volume_db
	player.volume_db = clampf(final_db, VOLUME_DB_MIN, VOLUME_DB_MAX)
	player.play()


## Play a sound at a 3D position (requires AudioStreamPlayer3D in pool — stub).
## Currently falls back to 2D play. Will be wired to 3D pool in Phase 9B.
func play_positional(sfx: SFX, position: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	# Phase 9B: use AudioStreamPlayer3D pool with position
	# For now, delegate to 2D play
	var _unused: Vector3 = position  # Suppress unused warning
	play(sfx, volume_db, pitch_scale)


## Play with random pitch variation (good for repeated sounds like walk steps).
func play_varied(sfx: SFX, variation: float = 0.1, volume_db: float = 0.0) -> void:
	var pitch: float = 1.0 + _rng.randf_range(-variation, variation)
	play(sfx, volume_db, pitch)


## Set master volume in dB. Clamped to [VOLUME_DB_MIN, VOLUME_DB_MAX].
func set_master_volume(volume_db: float) -> void:
	_master_volume_db = clampf(volume_db, VOLUME_DB_MIN, VOLUME_DB_MAX)


## Get master volume in dB.
func get_master_volume() -> float:
	return _master_volume_db


## Enable or disable all SFX playback.
func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	if not enabled:
		stop_all()


## Returns whether SFX playback is enabled.
func is_sfx_enabled() -> bool:
	return _sfx_enabled


## Stop all currently playing sounds.
func stop_all() -> void:
	for player in _pool:
		if player.playing:
			player.stop()


## Returns number of currently active (playing) pool slots.
func get_active_count() -> int:
	var count: int = 0
	for player in _pool:
		if player.playing:
			count += 1
	return count


## Returns the total pool size.
func get_pool_size() -> int:
	return POOL_SIZE


## Returns true if the given SFX has a generated sound.
func has_sound(sfx: SFX) -> bool:
	return _sounds.has(sfx)


# ═══════════════════════════════════════════════════════════════════════════════
# POOL MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func _get_next_player() -> AudioStreamPlayer:
	# Prefer a free (non-playing) player
	for i in range(POOL_SIZE):
		var idx: int = (_pool_index + i) % POOL_SIZE
		if not _pool[idx].playing:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# All busy — round-robin steal (cuts oldest)
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return player


func _get_category_volume(sfx: SFX) -> float:
	var category: String = str(SFX_VOLUME_MAP.get(sfx, "ui"))
	return float(VOLUME_CATEGORIES.get(category, 0.25))


# ═══════════════════════════════════════════════════════════════════════════════
# STREAM BUILDER HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _alloc_buffer(duration: float) -> PackedByteArray:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(int(SAMPLE_RATE * duration) * 2)
	return buf


func _write_sample(buf: PackedByteArray, index: int, value: float) -> void:
	var clamped: float = clampf(value, -1.0, 1.0)
	var sample_val: int = int(clamped * 32767.0)
	var byte_idx: int = index * 2
	if byte_idx + 1 < buf.size():
		buf[byte_idx] = sample_val & 0xFF
		buf[byte_idx + 1] = (sample_val >> 8) & 0xFF


func _read_sample(buf: PackedByteArray, index: int) -> float:
	var byte_idx: int = index * 2
	if byte_idx + 1 >= buf.size():
		return 0.0
	var lo: int = buf[byte_idx]
	var hi: int = buf[byte_idx + 1]
	var raw: int = lo | (hi << 8)
	# Sign-extend 16-bit
	if raw >= 32768:
		raw -= 65536
	return float(raw) / 32767.0


func _sample_count(duration: float) -> int:
	return int(SAMPLE_RATE * duration)


# ═══════════════════════════════════════════════════════════════════════════════
# WAVEFORM GENERATORS — Procedural tone building blocks
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a procedural tone. Returns an AudioStreamWAV.
## freq: frequency in Hz, duration: seconds, wave_type: WaveType enum.
func _generate_tone(freq: float, duration: float, wave_type: WaveType) -> AudioStreamWAV:
	var buf: PackedByteArray = _alloc_buffer(duration)
	var count: int = _sample_count(duration)

	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 1.0 - (t / duration)  # Linear decay envelope
		var val: float = _wave_sample(wave_type, freq, t)
		_write_sample(buf, i, val * env * 0.3)

	return _make_stream(buf)


## Sample a waveform at time t for given frequency and type.
func _wave_sample(wave_type: WaveType, freq: float, t: float) -> float:
	match wave_type:
		WaveType.SINE:
			return sin(TAU * freq * t)
		WaveType.SQUARE:
			return clampf(sin(TAU * freq * t) * 8.0, -1.0, 1.0)
		WaveType.TRIANGLE:
			return 2.0 / PI * asin(clampf(sin(TAU * freq * t), -1.0, 1.0))
		WaveType.SAWTOOTH:
			return 2.0 * fposmod(freq * t, 1.0) - 1.0
		WaveType.NOISE:
			return _rng.randf() * 2.0 - 1.0
	return 0.0


## Square wave helper (chiptune aesthetic)
func _sq(freq: float, t: float) -> float:
	return clampf(sin(TAU * freq * t) * 8.0, -1.0, 1.0)


## Triangle wave helper (NES-style smooth)
func _tri(freq: float, t: float) -> float:
	return 2.0 / PI * asin(clampf(sin(TAU * freq * t), -1.0, 1.0))


## Pulse wave helper (duty cycle character)
func _pulse(freq: float, t: float, duty: float = 0.25) -> float:
	return 1.0 if fposmod(freq * t, 1.0) < duty else -1.0


# ═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS HELPERS — ADSR, filtered noise, layer mixing, arpeggios
# ═══════════════════════════════════════════════════════════════════════════════

## Generate an ADSR envelope curve for a given number of samples.
## attack/decay/release in seconds, sustain as level 0.0-1.0.
## Returns a PackedFloat32Array of per-sample amplitude multipliers.
func _generate_envelope(
	samples: int,
	attack: float,
	decay: float,
	sustain: float,
	release: float
) -> PackedFloat32Array:
	var env: PackedFloat32Array = PackedFloat32Array()
	env.resize(samples)

	var attack_samples: int = int(attack * SAMPLE_RATE)
	var decay_samples: int = int(decay * SAMPLE_RATE)
	var release_samples: int = int(release * SAMPLE_RATE)
	var sustain_samples: int = maxi(0, samples - attack_samples - decay_samples - release_samples)

	var idx: int = 0

	# Attack: 0 -> 1
	for i in range(mini(attack_samples, samples)):
		if idx >= samples:
			break
		var frac: float = float(i) / maxf(float(attack_samples), 1.0)
		env[idx] = frac
		idx += 1

	# Decay: 1 -> sustain
	for i in range(mini(decay_samples, samples)):
		if idx >= samples:
			break
		var frac: float = float(i) / maxf(float(decay_samples), 1.0)
		env[idx] = lerpf(1.0, sustain, frac)
		idx += 1

	# Sustain: hold at sustain level
	for i in range(sustain_samples):
		if idx >= samples:
			break
		env[idx] = sustain
		idx += 1

	# Release: sustain -> 0
	for i in range(release_samples):
		if idx >= samples:
			break
		var frac: float = float(i) / maxf(float(release_samples), 1.0)
		env[idx] = lerpf(sustain, 0.0, frac)
		idx += 1

	# Fill any remaining with 0
	while idx < samples:
		env[idx] = 0.0
		idx += 1

	return env


## Generate a filtered noise burst. Returns an AudioStreamWAV.
## filter_freq controls a simple one-pole low-pass filter cutoff (Hz).
func _generate_noise_burst(duration: float, filter_freq: float) -> AudioStreamWAV:
	var buf: PackedByteArray = _alloc_buffer(duration)
	var count: int = _sample_count(duration)

	# One-pole low-pass coefficient
	var rc: float = 1.0 / (TAU * filter_freq)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var alpha: float = clampf(dt / (rc + dt), 0.0, 1.0)

	var prev: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var noise: float = _rng.randf() * 2.0 - 1.0
		prev = prev + alpha * (noise - prev)  # Low-pass filter
		var env: float = 1.0 - (t / duration)
		_write_sample(buf, i, prev * env * 0.3)

	return _make_stream(buf)


## Mix two AudioStreamWAV layers together. balance: 0.0 = all A, 1.0 = all B.
## Returned stream length matches the longer of the two inputs.
func _mix_layers(
	layer_a: AudioStreamWAV,
	layer_b: AudioStreamWAV,
	balance: float
) -> AudioStreamWAV:
	var data_a: PackedByteArray = layer_a.data
	var data_b: PackedByteArray = layer_b.data
	var samples_a: int = data_a.size() / 2
	var samples_b: int = data_b.size() / 2
	var max_samples: int = maxi(samples_a, samples_b)

	var buf: PackedByteArray = PackedByteArray()
	buf.resize(max_samples * 2)

	var gain_a: float = clampf(1.0 - balance, 0.0, 1.0)
	var gain_b: float = clampf(balance, 0.0, 1.0)

	for i in range(max_samples):
		var val_a: float = 0.0
		var val_b: float = 0.0
		if i < samples_a:
			val_a = _read_sample(data_a, i)
		if i < samples_b:
			val_b = _read_sample(data_b, i)
		var mixed: float = val_a * gain_a + val_b * gain_b
		_write_sample(buf, i, mixed)

	return _make_stream(buf)


## Generate a multi-note arpeggio sequence. Returns an AudioStreamWAV.
## notes: array of frequencies (Hz). note_duration: seconds per note.
func _generate_arpeggio(
	notes: Array,
	note_duration: float,
	wave_type: WaveType
) -> AudioStreamWAV:
	var total_dur: float = note_duration * float(notes.size())
	var buf: PackedByteArray = _alloc_buffer(total_dur)
	var count: int = _sample_count(total_dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var note_idx: int = mini(int(t / note_duration), notes.size() - 1)
		var local_t: float = t - float(note_idx) * note_duration
		# Per-note ADSR: quick attack, short decay, moderate sustain
		var note_env: float = 0.0
		var note_frac: float = local_t / note_duration
		if note_frac < 0.05:
			note_env = note_frac / 0.05  # Attack
		elif note_frac < 0.15:
			note_env = lerpf(1.0, 0.7, (note_frac - 0.05) / 0.1)  # Decay
		elif note_frac < 0.8:
			note_env = 0.7  # Sustain
		else:
			note_env = lerpf(0.7, 0.0, (note_frac - 0.8) / 0.2)  # Release

		var freq: float = float(notes[note_idx])
		var val: float = _wave_sample(wave_type, freq, t) * note_env * 0.25
		# Add subtle octave harmonic
		val += _wave_sample(WaveType.SINE, freq * 2.0, t) * note_env * 0.06
		_write_sample(buf, i, val)

	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# SOUND GENERATION — Procedural sounds for each SFX enum value
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_all_sounds() -> void:
	_sounds[SFX.CARD_DRAW] = _gen_card_draw()
	_sounds[SFX.CARD_FLIP] = _gen_card_flip()
	_sounds[SFX.OPTION_SELECT] = _gen_option_select()
	_sounds[SFX.MINIGAME_START] = _gen_minigame_start()
	_sounds[SFX.MINIGAME_END] = _gen_minigame_end()
	_sounds[SFX.SCORE_REVEAL] = _gen_score_reveal()
	_sounds[SFX.EFFECT_POSITIVE] = _gen_effect_positive()
	_sounds[SFX.EFFECT_NEGATIVE] = _gen_effect_negative()
	_sounds[SFX.OGHAM_ACTIVATE] = _gen_ogham_activate()
	_sounds[SFX.OGHAM_COOLDOWN] = _gen_ogham_cooldown()
	_sounds[SFX.LIFE_DRAIN] = _gen_life_drain()
	_sounds[SFX.LIFE_HEAL] = _gen_life_heal()
	_sounds[SFX.DEATH] = _gen_death()
	_sounds[SFX.VICTORY] = _gen_victory()
	_sounds[SFX.REP_UP] = _gen_rep_up()
	_sounds[SFX.REP_DOWN] = _gen_rep_down()
	_sounds[SFX.ANAM_GAIN] = _gen_anam_gain()
	_sounds[SFX.WALK_STEP] = _gen_walk_step()
	_sounds[SFX.BIOME_TRANSITION] = _gen_biome_transition()
	_sounds[SFX.MENU_CLICK] = _gen_menu_click()
	_sounds[SFX.MENU_HOVER] = _gen_menu_hover()
	_sounds[SFX.PROMISE_CREATE] = _gen_promise_create()
	_sounds[SFX.PROMISE_FULFILL] = _gen_promise_fulfill()
	_sounds[SFX.PROMISE_BREAK] = _gen_promise_break()
	_sounds[SFX.KARMA_SHIFT] = _gen_karma_shift()
	_sounds[SFX.HUB_AMBIENT] = _gen_hub_ambient()
	_sounds[SFX.RUN_AMBIENT] = _gen_run_ambient()


# ═══════════════════════════════════════════════════════════════════════════════
# INDIVIDUAL SOUND GENERATORS — Multi-layered procedural Celtic sounds
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_card_draw() -> AudioStreamWAV:
	## Paper shuffle — noise burst + filtered sweep + subtle tonal layer
	var dur: float = 0.22
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.005, 0.04, 0.3, 0.12)

	# One-pole filter state for noise
	var rc: float = 1.0 / (TAU * 2500.0)
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var alpha: float = clampf(dt / (rc + dt), 0.0, 1.0)
	var filtered: float = 0.0

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: filtered noise (paper texture)
		var noise: float = _rng.randf() * 2.0 - 1.0
		filtered = filtered + alpha * (noise - filtered)
		var paper: float = filtered * 0.18 * e
		# Layer 2: sweep tone (slide feel)
		var sweep_freq: float = lerpf(350.0, 600.0, t / dur)
		var tone: float = sin(TAU * sweep_freq * t) * 0.06 * e
		# Layer 3: micro-click at onset
		var click: float = sin(TAU * 1800.0 * t) * 0.08 * exp(-t * 200.0)
		_write_sample(buf, i, paper + tone + click)
	return _make_stream(buf)


func _gen_card_flip() -> AudioStreamWAV:
	## Snap — short click impulse + resonant body + high transient
	var dur: float = 0.14
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Layer 1: sharp click transient
		var click: float = _pulse(1400.0, t, 0.15) * 0.14 * exp(-t * 180.0)
		# Layer 2: resonant body (pitch-swept pulse)
		var body_freq: float = lerpf(400.0, 900.0, t / dur)
		var body: float = _pulse(body_freq, t, 0.3) * 0.10 * exp(-t * 40.0)
		# Layer 3: noise transient (mechanical snap)
		var snap: float = (_rng.randf() * 2.0 - 1.0) * 0.09 * exp(-t * 120.0)
		# Layer 4: subtle sine resonance
		var res: float = sin(TAU * 650.0 * t) * 0.04 * exp(-t * 25.0)
		_write_sample(buf, i, click + body + snap + res)
	return _make_stream(buf)


func _gen_option_select() -> AudioStreamWAV:
	## Soft chime — sine fundamental + harmonic shimmer
	var dur: float = 0.18
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.002, 0.03, 0.5, 0.10)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: fundamental sine (D4 = 294 Hz)
		var fundamental: float = sin(TAU * 294.0 * t) * 0.14 * e
		# Layer 2: 2nd harmonic (octave)
		var h2: float = sin(TAU * 588.0 * t) * 0.07 * e
		# Layer 3: 3rd harmonic (fifth above octave)
		var h3: float = sin(TAU * 882.0 * t) * 0.03 * e
		# Layer 4: soft shimmer (high triangle)
		var shimmer: float = _tri(1176.0, t) * 0.02 * e * sin(t / dur * PI)
		_write_sample(buf, i, fundamental + h2 + h3 + shimmer)
	return _make_stream(buf)


func _gen_minigame_start() -> AudioStreamWAV:
	## Ascending arpeggio — D E G (Celtic D Dorian, triangle wave + harmonics)
	var notes: Array = [294.0, 330.0, 392.0]  # D4, E4, G4
	return _generate_arpeggio(notes, 0.13, WaveType.TRIANGLE)


func _gen_minigame_end() -> AudioStreamWAV:
	## Descending resolution — A G D power chord + decay shimmer
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var notes: Array[float] = [440.0, 392.0, 294.0]  # A4, G4, D4
	var note_dur: float = dur / 3.0

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var note_idx: int = mini(int(t / note_dur), 2)
		var local_t: float = t - float(note_idx) * note_dur
		var note_env: float = exp(-local_t * 8.0)
		var freq: float = notes[note_idx]
		# Layer 1: triangle fundamental
		var fundamental: float = _tri(freq, t) * 0.16 * note_env
		# Layer 2: octave harmonic
		var h2: float = _tri(freq * 2.0, t) * 0.05 * note_env
		# Layer 3: soft fifth for richness on last note
		var fifth: float = 0.0
		if note_idx == 2:
			fifth = sin(TAU * freq * 1.5 * t) * 0.04 * note_env
		# Layer 4: shimmer tail on final note
		var shimmer: float = 0.0
		if note_idx == 2 and local_t > note_dur * 0.3:
			shimmer = sin(TAU * freq * 4.0 * t) * 0.02 * exp(-local_t * 5.0)
		_write_sample(buf, i, fundamental + h2 + fifth + shimmer)
	return _make_stream(buf)


func _gen_score_reveal() -> AudioStreamWAV:
	## Dramatic reveal — timpani-like low hit + shimmer sweep
	var dur: float = 0.45
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.003, 0.08, 0.4, 0.25)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: timpani-like low hit (sub-bass sine with fast pitch drop)
		var timpani_freq: float = lerpf(180.0, 90.0, minf(t / 0.08, 1.0))
		var timpani: float = sin(TAU * timpani_freq * t) * 0.18 * exp(-t * 6.0)
		# Layer 2: shimmer sweep (ascending filtered harmonics)
		var sweep_freq: float = lerpf(400.0, 800.0, t / dur)
		var shimmer: float = sin(TAU * sweep_freq * t) * 0.08 * e
		shimmer += sin(TAU * sweep_freq * 2.0 * t) * 0.04 * e
		# Layer 3: noise splash on attack
		var splash: float = (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 40.0)
		# Layer 4: high bell overtone
		var bell: float = sin(TAU * 1200.0 * t) * 0.03 * exp(-t * 12.0)
		_write_sample(buf, i, timpani + shimmer + splash + bell)
	return _make_stream(buf)


func _gen_effect_positive() -> AudioStreamWAV:
	## Warm major chord — 3 sine tones (D major: D4 F#4 A4) + sparkle
	var dur: float = 0.30
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.01, 0.05, 0.6, 0.15)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: D4 root
		var root: float = sin(TAU * 294.0 * t) * 0.12 * e
		# Layer 2: F#4 major third
		var third: float = sin(TAU * 370.0 * t) * 0.09 * e
		# Layer 3: A4 fifth
		var fifth: float = sin(TAU * 440.0 * t) * 0.08 * e
		# Layer 4: sparkle (high octave with tremolo)
		var sparkle: float = sin(TAU * 880.0 * t) * 0.03 * e * (0.5 + 0.5 * sin(TAU * 8.0 * t))
		_write_sample(buf, i, root + third + fifth + sparkle)
	return _make_stream(buf)


func _gen_effect_negative() -> AudioStreamWAV:
	## Minor dissonance — detuned sines (D3 + Eb3 beating) + rumble noise
	var dur: float = 0.32
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.005, 0.06, 0.5, 0.18)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: D3 square (dark fundamental)
		var d3: float = _sq(147.0, t) * 0.14 * e
		# Layer 2: Eb3 detuned (beating dissonance)
		var eb3: float = _sq(155.6, t) * 0.10 * e
		# Layer 3: minor third (F3)
		var f3: float = sin(TAU * 175.0 * t) * 0.06 * e
		# Layer 4: rumble noise (filtered low)
		var rumble: float = (_rng.randf() * 2.0 - 1.0) * 0.05 * e * exp(-t * 4.0)
		_write_sample(buf, i, d3 + eb3 + f3 + rumble)
	return _make_stream(buf)


func _gen_ogham_activate() -> AudioStreamWAV:
	## Mystical whoosh — filtered noise sweep up + harmonic shimmer
	var dur: float = 0.50
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.08, 0.10, 0.6, 0.20)

	var filtered: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var progress: float = t / dur
		# Layer 1: noise with sweeping filter (low -> high)
		var filter_freq: float = lerpf(200.0, 4000.0, progress)
		var rc: float = 1.0 / (TAU * filter_freq)
		var dt_val: float = 1.0 / float(SAMPLE_RATE)
		var alpha: float = clampf(dt_val / (rc + dt_val), 0.0, 1.0)
		var noise: float = _rng.randf() * 2.0 - 1.0
		filtered = filtered + alpha * (noise - filtered)
		var whoosh: float = filtered * 0.16 * e
		# Layer 2: harmonic series shimmer (A3 base)
		var base: float = 220.0
		var h1: float = sin(TAU * base * t) * 0.08 * e * progress
		var h2: float = sin(TAU * base * 2.0 * t) * 0.06 * e * progress
		var h3: float = sin(TAU * base * 3.0 * t) * 0.04 * e * progress
		var h5: float = sin(TAU * base * 5.0 * t) * 0.02 * e * progress
		_write_sample(buf, i, whoosh + h1 + h2 + h3 + h5)
	return _make_stream(buf)


func _gen_ogham_cooldown() -> AudioStreamWAV:
	## Descending tone — A4 down to D4 with fading harmonics
	var dur: float = 0.25
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.005, 0.04, 0.5, 0.12)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var freq: float = lerpf(440.0, 294.0, t / dur)
		# Layer 1: triangle fundamental
		var fundamental: float = _tri(freq, t) * 0.12 * e
		# Layer 2: octave above fading out
		var h2: float = sin(TAU * freq * 2.0 * t) * 0.04 * e * (1.0 - t / dur)
		# Layer 3: subtle sub-bass
		var sub: float = sin(TAU * freq * 0.5 * t) * 0.03 * e
		_write_sample(buf, i, fundamental + h2 + sub)
	return _make_stream(buf)


func _gen_life_drain() -> AudioStreamWAV:
	## Heartbeat pulse — dual low sine hits with envelope shaping
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Two heartbeat thuds at t=0 and t=0.15
		var beat1_env: float = exp(-t * 20.0) * 0.9
		var beat2_t: float = maxf(0.0, t - 0.15)
		var beat2_env: float = exp(-beat2_t * 25.0) * 0.7 if t >= 0.15 else 0.0
		# Layer 1: low pulse (heartbeat thud)
		var thud1: float = sin(TAU * 55.0 * t) * 0.20 * beat1_env
		var thud2: float = sin(TAU * 50.0 * t) * 0.16 * beat2_env
		# Layer 2: body resonance
		var body1: float = sin(TAU * 110.0 * t) * 0.08 * beat1_env
		var body2: float = sin(TAU * 105.0 * t) * 0.06 * beat2_env
		# Layer 3: noise texture
		var noise_env: float = (beat1_env + beat2_env) * 0.3
		var tex: float = (_rng.randf() * 2.0 - 1.0) * 0.04 * noise_env
		_write_sample(buf, i, thud1 + thud2 + body1 + body2 + tex)
	return _make_stream(buf)


func _gen_life_heal() -> AudioStreamWAV:
	## Gentle rising tone — E4 to A4 sine glide + warm harmonics
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.03, 0.05, 0.6, 0.15)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var freq: float = lerpf(330.0, 440.0, t / dur)
		# Layer 1: sine fundamental (warm glide)
		var fundamental: float = sin(TAU * freq * t) * 0.14 * e
		# Layer 2: octave harmonic
		var h2: float = sin(TAU * freq * 2.0 * t) * 0.05 * e
		# Layer 3: fifth above (gentle)
		var fifth: float = sin(TAU * freq * 1.5 * t) * 0.04 * e
		# Layer 4: soft chorus (slightly detuned)
		var chorus: float = sin(TAU * (freq * 1.003) * t) * 0.03 * e
		_write_sample(buf, i, fundamental + h2 + fifth + chorus)
	return _make_stream(buf)


func _gen_death() -> AudioStreamWAV:
	## Deep bell toll — low sine with long decay + dissonant overtones + noise
	var dur: float = 1.0
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Layer 1: deep bell fundamental (D2 = 73 Hz)
		var bell_env: float = exp(-t * 2.0)
		var bell: float = sin(TAU * 73.0 * t) * 0.20 * bell_env
		# Layer 2: bell partials (non-harmonic, like a real bell)
		var partial2: float = sin(TAU * 73.0 * 2.76 * t) * 0.08 * exp(-t * 3.0)
		var partial3: float = sin(TAU * 73.0 * 5.40 * t) * 0.04 * exp(-t * 5.0)
		# Layer 3: descending pitch sweep (doom feel)
		var sweep_freq: float = lerpf(294.0, 73.0, minf(t / 0.3, 1.0))
		var sweep: float = _sq(sweep_freq, t) * 0.10 * exp(-t * 4.0)
		# Layer 4: detuned dissonance
		var detune: float = _sq(sweep_freq * 1.015, t) * 0.05 * exp(-t * 4.5)
		# Layer 5: noise wash
		var noise_wash: float = (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 3.0) * (t / 0.3 if t < 0.3 else 1.0)
		_write_sample(buf, i, bell + partial2 + partial3 + sweep + detune + noise_wash)
	return _make_stream(buf)


func _gen_victory() -> AudioStreamWAV:
	## Triumphant fanfare — ascending major arpeggio D G A D' (Celtic triumph)
	var notes: Array = [294.0, 392.0, 440.0, 587.0]  # D4, G4, A4, D5
	var base: AudioStreamWAV = _generate_arpeggio(notes, 0.15, WaveType.TRIANGLE)

	# Add a sustain chord tail
	var tail_dur: float = 0.30
	var tail_buf: PackedByteArray = _alloc_buffer(tail_dur)
	var tail_count: int = _sample_count(tail_dur)
	for i in range(tail_count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = exp(-t * 4.0)
		# D major chord sustained
		var d: float = _tri(587.0, t) * 0.10 * e
		var a: float = sin(TAU * 440.0 * t) * 0.06 * e
		var g: float = sin(TAU * 392.0 * t) * 0.04 * e
		_write_sample(tail_buf, i, d + a + g)
	var tail: AudioStreamWAV = _make_stream(tail_buf)

	return _mix_layers(base, tail, 0.35)


func _gen_rep_up() -> AudioStreamWAV:
	## Coin-like ding — metallic high sine + bell partials
	var dur: float = 0.18
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env_fast: float = exp(-t * 20.0)
		var env_slow: float = exp(-t * 8.0)
		# Layer 1: high sine (coin ping)
		var ping: float = sin(TAU * 1200.0 * t) * 0.10 * env_fast
		# Layer 2: body tone (G4)
		var body: float = sin(TAU * 392.0 * t) * 0.10 * env_slow
		# Layer 3: ascending sweep
		var sweep_freq: float = lerpf(392.0, 600.0, t / dur)
		var sweep: float = _tri(sweep_freq, t) * 0.06 * env_slow
		# Layer 4: bell partial
		var bell: float = sin(TAU * 392.0 * 2.76 * t) * 0.03 * env_fast
		_write_sample(buf, i, ping + body + sweep + bell)
	return _make_stream(buf)


func _gen_rep_down() -> AudioStreamWAV:
	## Dull thud — low muffled impact + descending tone
	var dur: float = 0.18
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 18.0)
		# Layer 1: low thud
		var thud: float = sin(TAU * 120.0 * t) * 0.16 * exp(-t * 30.0)
		# Layer 2: descending tone (B4 -> G4)
		var freq: float = lerpf(494.0, 350.0, t / dur)
		var desc: float = _tri(freq, t) * 0.10 * env
		# Layer 3: muffled noise
		var muffled: float = (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 40.0)
		_write_sample(buf, i, thud + desc + muffled)
	return _make_stream(buf)


func _gen_anam_gain() -> AudioStreamWAV:
	## Ethereal shimmer — high harmonics with chorus and slow decay
	var dur: float = 0.45
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.05, 0.08, 0.5, 0.20)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: C5 fundamental
		var c5: float = sin(TAU * 523.0 * t) * 0.08 * e
		# Layer 2: G5 fifth
		var g5: float = sin(TAU * 784.0 * t) * 0.06 * e
		# Layer 3: C6 octave
		var c6: float = sin(TAU * 1047.0 * t) * 0.04 * e
		# Layer 4: chorus (slightly detuned)
		var chorus: float = sin(TAU * 525.0 * t) * 0.03 * e
		chorus += sin(TAU * 786.0 * t) * 0.02 * e
		# Layer 5: shimmer LFO modulation
		var lfo: float = 0.5 + 0.5 * sin(TAU * 6.0 * t)
		var shimmer: float = sin(TAU * 1570.0 * t) * 0.02 * e * lfo
		_write_sample(buf, i, c5 + g5 + c6 + chorus + shimmer)
	return _make_stream(buf)


func _gen_walk_step() -> AudioStreamWAV:
	## Soft crunch — short filtered noise + low thump
	var dur: float = 0.08
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	# Filter state for crunch texture
	var filtered: float = 0.0
	var rc: float = 1.0 / (TAU * 1800.0)
	var dt_val: float = 1.0 / float(SAMPLE_RATE)
	var alpha: float = clampf(dt_val / (rc + dt_val), 0.0, 1.0)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 60.0)
		# Layer 1: filtered noise (crunch)
		var noise: float = _rng.randf() * 2.0 - 1.0
		filtered = filtered + alpha * (noise - filtered)
		var crunch: float = filtered * 0.12 * env
		# Layer 2: low thump
		var thump: float = sin(TAU * 80.0 * t) * 0.08 * exp(-t * 80.0)
		# Layer 3: subtle mid-click
		var mid: float = sin(TAU * 400.0 * t) * 0.03 * exp(-t * 100.0)
		_write_sample(buf, i, crunch + thump + mid)
	return _make_stream(buf)


func _gen_biome_transition() -> AudioStreamWAV:
	## Sweeping transition — D3 to A3 glide with layered harmonics + noise wash
	var dur: float = 0.55
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.05, 0.08, 0.6, 0.20)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var freq: float = lerpf(147.0, 220.0, t / dur)
		# Layer 1: square wave sweep
		var sweep: float = _sq(freq, t) * 0.10 * e
		# Layer 2: octave harmonic
		var h2: float = sin(TAU * freq * 2.0 * t) * 0.06 * e
		# Layer 3: fifth above
		var fifth: float = sin(TAU * freq * 1.5 * t) * 0.03 * e
		# Layer 4: noise wash
		var wash: float = (_rng.randf() * 2.0 - 1.0) * 0.03 * e * sin(t / dur * PI)
		_write_sample(buf, i, sweep + h2 + fifth + wash)
	return _make_stream(buf)


func _gen_menu_click() -> AudioStreamWAV:
	## Pixel click — sharp pulse snap + harmonic accent
	var dur: float = 0.05
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 120.0)
		# Layer 1: high pulse (click)
		var click: float = _pulse(1200.0, t, 0.25) * 0.14 * env
		# Layer 2: square harmonic accent
		var accent: float = _sq(600.0, t) * 0.06 * env
		# Layer 3: micro sine body
		var body: float = sin(TAU * 900.0 * t) * 0.04 * exp(-t * 200.0)
		_write_sample(buf, i, click + accent + body)
	return _make_stream(buf)


func _gen_menu_hover() -> AudioStreamWAV:
	## Pixel hover blip — G5 square + subtle octave
	var dur: float = 0.04
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 160.0)
		# Layer 1: G5 square
		var g5: float = _sq(784.0, t) * 0.07 * env
		# Layer 2: G4 sub-octave
		var g4: float = _sq(392.0, t) * 0.03 * env
		# Layer 3: tiny sine sparkle
		var sparkle: float = sin(TAU * 1568.0 * t) * 0.02 * exp(-t * 200.0)
		_write_sample(buf, i, g5 + g4 + sparkle)
	return _make_stream(buf)


func _gen_promise_create() -> AudioStreamWAV:
	## Mystical commitment — rising harmonic series + whoosh
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.03, 0.06, 0.5, 0.18)

	var filtered: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var base: float = lerpf(220.0, 330.0, t / dur)
		# Layer 1: rising fundamental
		var fundamental: float = sin(TAU * base * t) * 0.10 * e
		# Layer 2: perfect fifth
		var fifth: float = sin(TAU * base * 1.5 * t) * 0.06 * e
		# Layer 3: octave
		var h2: float = sin(TAU * base * 2.0 * t) * 0.04 * e
		# Layer 4: noise whoosh (filtered, building)
		var noise: float = _rng.randf() * 2.0 - 1.0
		var progress: float = t / dur
		var lp_freq: float = lerpf(300.0, 2000.0, progress)
		var rc: float = 1.0 / (TAU * lp_freq)
		var dt_val: float = 1.0 / float(SAMPLE_RATE)
		var alpha: float = clampf(dt_val / (rc + dt_val), 0.0, 1.0)
		filtered = filtered + alpha * (noise - filtered)
		var whoosh: float = filtered * 0.05 * e * progress
		_write_sample(buf, i, fundamental + fifth + h2 + whoosh)
	return _make_stream(buf)


func _gen_promise_fulfill() -> AudioStreamWAV:
	## Triumphant resolution — D major chord bloom + sparkle tail
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.01, 0.06, 0.6, 0.18)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		# Layer 1: D4 root (triangle)
		var d4: float = _tri(294.0, t) * 0.12 * e
		# Layer 2: F#4 major third
		var fsharp4: float = _tri(370.0, t) * 0.08 * e
		# Layer 3: A4 fifth
		var a4: float = _tri(440.0, t) * 0.06 * e
		# Layer 4: sparkle tail (high sine, fading in then out)
		var sparkle_env: float = sin(t / dur * PI) * 0.5
		var sparkle: float = sin(TAU * 880.0 * t) * 0.04 * sparkle_env
		sparkle += sin(TAU * 1176.0 * t) * 0.02 * sparkle_env
		_write_sample(buf, i, d4 + fsharp4 + a4 + sparkle)
	return _make_stream(buf)


func _gen_promise_break() -> AudioStreamWAV:
	## Breaking glass — noise burst + descending dissonance + crackle
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 7.0)
		var freq: float = lerpf(700.0, 150.0, t / dur)
		# Layer 1: descending square
		var desc: float = _sq(freq, t) * 0.10 * env
		# Layer 2: dissonant minor second above
		var dissonant: float = _sq(freq * 1.06, t) * 0.07 * env
		# Layer 3: noise burst (glass shatter)
		var noise: float = (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		# Layer 4: crackle (random clicks, fading)
		var crackle: float = 0.0
		if _rng.randf() < 0.15 * env:
			crackle = (_rng.randf() * 2.0 - 1.0) * 0.08
		_write_sample(buf, i, desc + dissonant + noise + crackle)
	return _make_stream(buf)


func _gen_karma_shift() -> AudioStreamWAV:
	## Deep resonance shift — sub-bass wobble + overtone modulation
	var dur: float = 0.45
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var env: PackedFloat32Array = _generate_envelope(count, 0.04, 0.06, 0.5, 0.20)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var e: float = env[i]
		var wobble: float = sin(TAU * 4.0 * t) * 20.0
		# Layer 1: sub-bass with wobble
		var sub: float = sin(TAU * (110.0 + wobble) * t) * 0.12 * e
		# Layer 2: overtone triangle
		var overtone: float = _tri(220.0 + wobble, t) * 0.06 * e
		# Layer 3: higher partial with phase modulation
		var phase_mod: float = sin(TAU * 3.0 * t) * 0.5
		var partial: float = sin(TAU * 330.0 * t + phase_mod) * 0.04 * e
		# Layer 4: subtle noise texture
		var tex: float = (_rng.randf() * 2.0 - 1.0) * 0.02 * e
		_write_sample(buf, i, sub + overtone + partial + tex)
	return _make_stream(buf)


func _gen_hub_ambient() -> AudioStreamWAV:
	## Looping pad — layered low sines with LFO + filtered noise bed
	var dur: float = 2.0
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	var filtered: float = 0.0
	var rc: float = 1.0 / (TAU * 300.0)
	var dt_val: float = 1.0 / float(SAMPLE_RATE)
	var alpha: float = clampf(dt_val / (rc + dt_val), 0.0, 1.0)

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(t / dur * PI)
		# Layer 1: D3 drone
		var d3: float = sin(TAU * 147.0 * t) * 0.06 * env
		# Layer 2: A3 fifth
		var a3: float = sin(TAU * 220.0 * t) * 0.04 * env
		# Layer 3: D4 octave
		var d4: float = sin(TAU * 294.0 * t) * 0.03 * env
		# Layer 4: slow LFO modulation on amplitude
		var lfo: float = 0.8 + 0.2 * sin(TAU * 0.5 * t)
		# Layer 5: filtered noise bed (warm hiss)
		var noise: float = _rng.randf() * 2.0 - 1.0
		filtered = filtered + alpha * (noise - filtered)
		var noise_bed: float = filtered * 0.03 * env
		_write_sample(buf, i, (d3 + a3 + d4) * lfo + noise_bed)
	return _make_stream(buf)


func _gen_run_ambient() -> AudioStreamWAV:
	## Wind-like ambient — filtered noise with slow modulation + drone
	var dur: float = 2.0
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)

	var filtered: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(t / dur * PI) * 0.8
		# Layer 1: modulated filtered noise (wind)
		var mod_freq: float = 100.0 + sin(TAU * 0.3 * t) * 40.0 + sin(TAU * 0.7 * t) * 20.0
		var rc: float = 1.0 / (TAU * mod_freq)
		var dt_val: float = 1.0 / float(SAMPLE_RATE)
		var a: float = clampf(dt_val / (rc + dt_val), 0.0, 1.0)
		var noise: float = _rng.randf() * 2.0 - 1.0
		filtered = filtered + a * (noise - filtered)
		var wind: float = filtered * 0.07 * env
		# Layer 2: sub-drone
		var drone: float = sin(TAU * (80.0 + sin(TAU * 0.2 * t) * 10.0) * t) * 0.03 * env
		# Layer 3: high whistle (very faint)
		var whistle: float = sin(TAU * 1200.0 * t) * 0.008 * env * (0.5 + 0.5 * sin(TAU * 0.4 * t))
		_write_sample(buf, i, wind + drone + whistle)
	return _make_stream(buf)
