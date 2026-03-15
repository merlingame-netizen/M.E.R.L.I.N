## ═══════════════════════════════════════════════════════════════════════════════
## SFXManager — Phase 9 Enum-Based Procedural Sound System
## ═══════════════════════════════════════════════════════════════════════════════
## Typed enum API over an AudioStreamPlayer pool with procedural generation.
## Designed as autoload singleton. All sounds generated at startup — zero files.
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
		var val: float = 0.0

		match wave_type:
			WaveType.SINE:
				val = sin(TAU * freq * t)
			WaveType.SQUARE:
				val = clampf(sin(TAU * freq * t) * 8.0, -1.0, 1.0)
			WaveType.TRIANGLE:
				val = 2.0 / PI * asin(clampf(sin(TAU * freq * t), -1.0, 1.0))
			WaveType.SAWTOOTH:
				val = 2.0 * fposmod(freq * t, 1.0) - 1.0
			WaveType.NOISE:
				val = _rng.randf() * 2.0 - 1.0

		_write_sample(buf, i, val * env * 0.3)

	return _make_stream(buf)


## Square wave helper (chiptune aesthetic)
func _sq(freq: float, t: float) -> float:
	return clampf(sin(TAU * freq * t) * 8.0, -1.0, 1.0)


## Triangle wave helper (NES-style smooth)
func _tri(freq: float, t: float) -> float:
	return 2.0 / PI * asin(clampf(sin(TAU * freq * t), -1.0, 1.0))


## Pulse wave helper (duty cycle character)
func _pulse(freq: float, t: float, duty: float = 0.25) -> float:
	return 1.0 if fposmod(freq * t, 1.0) < duty else -1.0


# Celtic scale reference (D Dorian = D E F G A B C D):
# D3=147  E3=165  F3=175  G3=196  A3=220  B3=247  C4=262
# D4=294  E4=330  F4=349  G4=392  A4=440  B4=494  C5=523  D5=587  G5=784


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
# INDIVIDUAL SOUND GENERATORS — Celtic chiptune procedural sounds
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_card_draw() -> AudioStreamWAV:
	## Paper slide — filtered noise + soft tone sweep
	var dur: float = 0.18
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / dur) * sin(t / dur * PI * 0.5)
		var noise: float = (_rng.randf() * 2.0 - 1.0) * 0.15
		var tone: float = sin(TAU * 400.0 * t) * 0.05
		_write_sample(buf, i, (noise + tone) * env)
	return _make_stream(buf)


func _gen_card_flip() -> AudioStreamWAV:
	## Card flip — quick snap with pitch rise
	var dur: float = 0.12
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 40.0)
		var freq: float = lerpf(300.0, 800.0, t / dur)
		var val: float = _pulse(freq, t, 0.3) * 0.12 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * exp(-t * 60.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_option_select() -> AudioStreamWAV:
	## Confirm click — D4 square with harmonic
	var dur: float = 0.08
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 80.0)
		var val: float = _sq(294.0, t) * 0.15 * env
		val += _sq(588.0, t) * 0.06 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_minigame_start() -> AudioStreamWAV:
	## Rising arpeggio — D E G A (Celtic scale, chiptune)
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var notes: Array[float] = [294.0, 330.0, 392.0, 440.0]
	var note_dur: float = dur / float(notes.size())
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = mini(int(t / note_dur), notes.size() - 1)
		var local_t: float = fposmod(t, note_dur)
		var env: float = exp(-local_t * 12.0)
		var val: float = _tri(notes[note_idx], t) * 0.18 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_minigame_end() -> AudioStreamWAV:
	## Resolution chord — D+A power chord fade
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 6.0)
		var val: float = _tri(294.0, t) * 0.14 * env
		val += _tri(440.0, t) * 0.10 * env
		val += _sq(588.0, t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_score_reveal() -> AudioStreamWAV:
	## Ascending shimmer — G4 to D5 glide
	var dur: float = 0.30
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var freq: float = lerpf(392.0, 587.0, t / dur)
		var val: float = _tri(freq, t) * 0.16 * env
		val += sin(TAU * freq * 2.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_effect_positive() -> AudioStreamWAV:
	## Bright chime — A4 + E5 sparkle
	var dur: float = 0.25
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 8.0)
		var val: float = sin(TAU * 440.0 * t) * 0.14 * env
		val += sin(TAU * 660.0 * t) * 0.08 * env
		val += _tri(880.0, t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_effect_negative() -> AudioStreamWAV:
	## Dark buzz — low D3 with dissonant overtone
	var dur: float = 0.28
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 6.0)
		var val: float = _sq(147.0, t) * 0.16 * env
		val += _sq(155.0, t) * 0.10 * env  # Dissonant beating
		val += (_rng.randf() * 2.0 - 1.0) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_ogham_activate() -> AudioStreamWAV:
	## Mystical activation — harmonic series shimmer
	var dur: float = 0.45
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI) * exp(-t * 2.0)
		var base_freq: float = 220.0
		var val: float = sin(TAU * base_freq * t) * 0.10 * env
		val += sin(TAU * base_freq * 2.0 * t) * 0.08 * env
		val += sin(TAU * base_freq * 3.0 * t) * 0.05 * env
		val += sin(TAU * base_freq * 5.0 * t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_ogham_cooldown() -> AudioStreamWAV:
	## Descending tone — cooldown indicator
	var dur: float = 0.20
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 1.0 - t / dur
		var freq: float = lerpf(440.0, 220.0, t / dur)
		var val: float = _tri(freq, t) * 0.12 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_life_drain() -> AudioStreamWAV:
	## Hollow thud — low pulse with noise
	var dur: float = 0.15
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 30.0)
		var val: float = _pulse(110.0, t, 0.4) * 0.20 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.06 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_life_heal() -> AudioStreamWAV:
	## Warm rising tone — E4 to A4 sine glide
	var dur: float = 0.30
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var freq: float = lerpf(330.0, 440.0, t / dur)
		var val: float = sin(TAU * freq * t) * 0.14 * env
		val += sin(TAU * freq * 2.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_death() -> AudioStreamWAV:
	## Dramatic descending — D4 crashing down to D2 with distortion
	var dur: float = 0.80
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 2.5)
		var freq: float = lerpf(294.0, 73.0, t / dur)
		var val: float = _sq(freq, t) * 0.20 * env
		val += _sq(freq * 1.01, t) * 0.10 * env  # Detuned dissonance
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * env * (t / dur)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_victory() -> AudioStreamWAV:
	## Fanfare — D G A D arpeggio (Celtic triumph)
	var dur: float = 0.60
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	var notes: Array[float] = [294.0, 392.0, 440.0, 587.0]
	var note_dur: float = dur / float(notes.size())
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = mini(int(t / note_dur), notes.size() - 1)
		var local_t: float = fposmod(t, note_dur)
		var env: float = exp(-local_t * 6.0)
		var val: float = _tri(notes[note_idx], t) * 0.16 * env
		val += _sq(notes[note_idx] * 2.0, t) * 0.05 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_rep_up() -> AudioStreamWAV:
	## Short ascending chime — G4 to B4
	var dur: float = 0.15
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 15.0)
		var freq: float = lerpf(392.0, 494.0, t / dur)
		var val: float = _tri(freq, t) * 0.14 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_rep_down() -> AudioStreamWAV:
	## Short descending tone — B4 to G4
	var dur: float = 0.15
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 15.0)
		var freq: float = lerpf(494.0, 392.0, t / dur)
		var val: float = _tri(freq, t) * 0.14 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_anam_gain() -> AudioStreamWAV:
	## Ethereal shimmer — high harmonics with slow decay
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI) * exp(-t * 3.0)
		var val: float = sin(TAU * 523.0 * t) * 0.08 * env
		val += sin(TAU * 784.0 * t) * 0.06 * env
		val += sin(TAU * 1047.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_walk_step() -> AudioStreamWAV:
	## Soft footstep — noise burst with low thump
	var dur: float = 0.08
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 60.0)
		var val: float = (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		val += sin(TAU * 80.0 * t) * 0.08 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_biome_transition() -> AudioStreamWAV:
	## Sweeping transition — D3 to A3 glide with harmonics
	var dur: float = 0.50
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var freq: float = lerpf(147.0, 220.0, t / dur)
		var val: float = _sq(freq, t) * 0.10 * env
		val += sin(TAU * freq * 2.0 * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_menu_click() -> AudioStreamWAV:
	## Pixel click — pulse wave snap
	var dur: float = 0.05
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 120.0)
		var val: float = _pulse(1200.0, t, 0.25) * 0.15 * env
		val += _sq(600.0, t) * 0.06 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_menu_hover() -> AudioStreamWAV:
	## Pixel hover blip — G5 square wave
	var dur: float = 0.035
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 160.0)
		var val: float = _sq(784.0, t) * 0.07 * env
		val += _sq(392.0, t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_promise_create() -> AudioStreamWAV:
	## Mystical commitment — rising harmonic series
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var base: float = lerpf(220.0, 330.0, t / dur)
		var val: float = sin(TAU * base * t) * 0.10 * env
		val += sin(TAU * base * 1.5 * t) * 0.06 * env
		val += sin(TAU * base * 2.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_promise_fulfill() -> AudioStreamWAV:
	## Triumphant resolution — D major chord bloom
	var dur: float = 0.35
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI) * exp(-t * 3.0)
		var val: float = _tri(294.0, t) * 0.12 * env  # D4
		val += _tri(370.0, t) * 0.08 * env  # F#4
		val += _tri(440.0, t) * 0.06 * env  # A4
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_promise_break() -> AudioStreamWAV:
	## Breaking glass — noise burst with descending dissonance
	var dur: float = 0.30
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 8.0)
		var freq: float = lerpf(600.0, 150.0, t / dur)
		var val: float = _sq(freq, t) * 0.12 * env
		val += _sq(freq * 1.06, t) * 0.08 * env  # Dissonant
		val += (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_karma_shift() -> AudioStreamWAV:
	## Deep resonance shift — sub-bass with overtone wobble
	var dur: float = 0.40
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var wobble: float = sin(TAU * 4.0 * t) * 20.0
		var val: float = sin(TAU * (110.0 + wobble) * t) * 0.12 * env
		val += _tri(220.0 + wobble, t) * 0.06 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_hub_ambient() -> AudioStreamWAV:
	## Gentle drone — layered sine tones, long sustain
	var dur: float = 1.0
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI)
		var val: float = sin(TAU * 147.0 * t) * 0.06 * env
		val += sin(TAU * 220.0 * t) * 0.04 * env
		val += sin(TAU * 294.0 * t) * 0.03 * env
		val += sin(TAU * 2.0 * t) * 0.02 * env  # Slow LFO modulation
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_run_ambient() -> AudioStreamWAV:
	## Wind-like ambient — filtered noise with slow movement
	var dur: float = 1.0
	var buf: PackedByteArray = _alloc_buffer(dur)
	var count: int = _sample_count(dur)
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = sin(t / dur * PI) * 0.8
		var val: float = (_rng.randf() * 2.0 - 1.0) * 0.06 * env
		val += sin(TAU * (100.0 + sin(TAU * 0.5 * t) * 30.0) * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)
