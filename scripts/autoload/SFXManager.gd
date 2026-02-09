## ═══════════════════════════════════════════════════════════════════════════════
## SFXManager — Centralized Procedural Sound System for M.E.R.L.I.N.
## ═══════════════════════════════════════════════════════════════════════════════
## All sounds are procedurally generated — zero audio files required.
## Each sound is pre-generated at startup for instant playback.
## Usage: SFXManager.play("hover"), SFXManager.play("click"), etc.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const SAMPLE_RATE := 44100
const POOL_SIZE := 6  # Concurrent audio players

# Volume presets (linear 0.0-1.0, will be converted to dB)
const VOLUME := {
	"ui": 0.25,
	"ambient": 0.15,
	"impact": 0.30,
	"magic": 0.20,
	"transition": 0.22,
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _sounds: Dictionary = {}  # name -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _master_volume: float = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_rng.randomize()
	_create_player_pool()
	_generate_all_sounds()


func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Play a named sound. Optional pitch_scale for variation.
func play(sound_name: String, pitch_scale: float = 1.0) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _get_next_player()
	player.stream = _sounds[sound_name]
	player.pitch_scale = pitch_scale
	player.volume_db = linear_to_db(_get_volume_for(sound_name) * _master_volume)
	player.play()


## Play with random pitch variation (good for repeated sounds).
func play_varied(sound_name: String, variation: float = 0.1) -> void:
	var pitch := 1.0 + _rng.randf_range(-variation, variation)
	play(sound_name, pitch)


## Set master volume (0.0 to 1.0).
func set_master_volume(vol: float) -> void:
	_master_volume = clampf(vol, 0.0, 1.0)


func _get_next_player() -> AudioStreamPlayer:
	# Find a free player, or cycle through pool
	for i in range(POOL_SIZE):
		var idx := (_pool_index + i) % POOL_SIZE
		if not _pool[idx].playing:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# All busy — use round-robin (will cut oldest)
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return player


func _get_volume_for(sound_name: String) -> float:
	# Map sound names to volume categories
	if sound_name in ["hover", "click", "slider_tick", "button_appear"]:
		return VOLUME.ui
	if sound_name in ["whoosh", "card_draw", "card_swipe", "scene_transition"]:
		return VOLUME.transition
	if sound_name in ["block_land", "pixel_land", "pixel_cascade", "accum_explode",
			"dice_land", "dice_roll"]:
		return VOLUME.impact
	if sound_name in ["ogham_chime", "ogham_unlock", "bestiole_shimmer", "eye_open",
			"flash_boom", "magic_reveal", "skill_activate",
			"dice_crit_success", "dice_crit_fail", "critical_alert"]:
		return VOLUME.magic
	if sound_name in ["path_scratch", "landmark_pop", "mist_breath", "aspect_shift"]:
		return VOLUME.ambient
	if sound_name in ["dice_shake", "minigame_tick"]:
		return VOLUME.ui
	if sound_name in ["minigame_start", "minigame_success", "minigame_fail"]:
		return VOLUME.transition
	return VOLUME.ui


# ═══════════════════════════════════════════════════════════════════════════════
# SOUND GENERATION — All procedural, no files
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_all_sounds() -> void:
	# --- UI Sounds ---
	_sounds["hover"] = _gen_hover()
	_sounds["click"] = _gen_click()
	_sounds["slider_tick"] = _gen_slider_tick()
	_sounds["button_appear"] = _gen_button_appear()

	# --- Transition Sounds ---
	_sounds["whoosh"] = _gen_whoosh()
	_sounds["card_draw"] = _gen_card_draw()
	_sounds["card_swipe"] = _gen_card_swipe()
	_sounds["scene_transition"] = _gen_scene_transition()

	# --- Impact Sounds ---
	_sounds["block_land"] = _gen_block_land()
	_sounds["pixel_land"] = _gen_pixel_land()
	_sounds["pixel_cascade"] = _gen_pixel_cascade()
	_sounds["accum_explode"] = _gen_accum_explode()

	# --- Magic / Mystical Sounds ---
	_sounds["ogham_chime"] = _gen_ogham_chime()
	_sounds["ogham_unlock"] = _gen_ogham_unlock()
	_sounds["bestiole_shimmer"] = _gen_bestiole_shimmer()
	_sounds["eye_open"] = _gen_eye_open()
	_sounds["flash_boom"] = _gen_flash_boom()
	_sounds["magic_reveal"] = _gen_magic_reveal()
	_sounds["skill_activate"] = _gen_skill_activate()

	# --- Ambient / Atmospheric ---
	_sounds["path_scratch"] = _gen_path_scratch()
	_sounds["landmark_pop"] = _gen_landmark_pop()
	_sounds["mist_breath"] = _gen_mist_breath()
	_sounds["aspect_shift"] = _gen_aspect_shift()
	_sounds["aspect_up"] = _gen_aspect_up()
	_sounds["aspect_down"] = _gen_aspect_down()

	# --- Boot/CeltOS Specific ---
	_sounds["boot_line"] = _gen_boot_line()
	_sounds["boot_confirm"] = _gen_boot_confirm()
	_sounds["convergence"] = _gen_convergence()
	_sounds["slit_glow"] = _gen_slit_glow()

	# --- Quiz Specific ---
	_sounds["choice_hover"] = _gen_choice_hover()
	_sounds["choice_select"] = _gen_choice_select()
	_sounds["result_reveal"] = _gen_result_reveal()
	_sounds["question_transition"] = _gen_question_transition()

	# --- Dice Sounds (Phase 33) ---
	_sounds["dice_shake"] = _gen_dice_shake()
	_sounds["dice_roll"] = _gen_dice_roll()
	_sounds["dice_land"] = _gen_dice_land()
	_sounds["dice_crit_success"] = _gen_dice_crit_success()
	_sounds["dice_crit_fail"] = _gen_dice_crit_fail()

	# --- Mini-game Sounds (Phase 33) ---
	_sounds["minigame_start"] = _gen_minigame_start()
	_sounds["minigame_success"] = _gen_minigame_success()
	_sounds["minigame_fail"] = _gen_minigame_fail()
	_sounds["minigame_tick"] = _gen_minigame_tick()
	_sounds["critical_alert"] = _gen_critical_alert()


# ═══════════════════════════════════════════════════════════════════════════════
# STREAM BUILDER HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _alloc_buffer(duration: float) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(int(SAMPLE_RATE * duration) * 2)
	return buf


func _write_sample(buf: PackedByteArray, index: int, value: float) -> void:
	var clamped := clampf(value, -1.0, 1.0)
	var sample_val := int(clamped * 32767.0)
	var byte_idx := index * 2
	if byte_idx + 1 < buf.size():
		buf[byte_idx] = sample_val & 0xFF
		buf[byte_idx + 1] = (sample_val >> 8) & 0xFF


func _sample_count(duration: float) -> int:
	return int(SAMPLE_RATE * duration)


# ═══════════════════════════════════════════════════════════════════════════════
# UI SOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_hover() -> AudioStreamWAV:
	## Soft high-pitched tick — like a feather touching glass
	var dur := 0.035
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 180.0)
		var val := sin(TAU * 2800.0 * t) * 0.15 * env
		val += sin(TAU * 4200.0 * t) * 0.08 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_click() -> AudioStreamWAV:
	## Crisp parchment click — paper + wood character
	var dur := 0.06
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 120.0)
		var val := sin(TAU * 1200.0 * t) * 0.25 * env
		val += sin(TAU * 680.0 * t) * 0.15 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * exp(-t * 200.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_slider_tick() -> AudioStreamWAV:
	## Tiny mechanical tick for slider notches
	var dur := 0.02
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 300.0)
		var val := sin(TAU * 3500.0 * t) * 0.12 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_button_appear() -> AudioStreamWAV:
	## Soft chime for button cascade appearance
	var dur := 0.12
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / 0.12 * PI) * 0.6
		var freq := 1800.0 + t * 2000.0
		var val := sin(TAU * freq * t) * 0.10 * env
		val += sin(TAU * freq * 1.5 * t) * 0.05 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSITION SOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_whoosh() -> AudioStreamWAV:
	## Soft air whoosh for card swipe / scene transitions
	var dur := 0.30
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var noise := (_rng.randf() * 2.0 - 1.0)
		# Filtered noise: low-pass by averaging
		var freq_mod := 200.0 + sin(t * 8.0) * 100.0
		var val := noise * 0.18 * env
		val += sin(TAU * freq_mod * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_card_draw() -> AudioStreamWAV:
	## Card being drawn — paper slide sound
	var dur := 0.18
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := (1.0 - t / dur) * sin(t / dur * PI * 0.5)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.15
		var tone := sin(TAU * 400.0 * t) * 0.05
		var val := (noise + tone) * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_card_swipe() -> AudioStreamWAV:
	## Card swiped away — quick directional whoosh
	var dur := 0.22
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 8.0) * sin(minf(t / 0.05, 1.0) * PI * 0.5)
		var freq := lerpf(600.0, 200.0, t / dur)
		var val := sin(TAU * freq * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.14 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_scene_transition() -> AudioStreamWAV:
	## Longer atmospheric transition — rising then fading
	var dur := 0.50
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(120.0, 350.0, t / dur)
		var val := sin(TAU * freq * t) * 0.06 * env
		val += sin(TAU * freq * 2.01 * t) * 0.03 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# IMPACT SOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_block_land() -> AudioStreamWAV:
	## Tetris-style block landing — thud + bounce overtone
	var dur := 0.10
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 60.0)
		var val := sin(TAU * 180.0 * t) * 0.30 * env
		val += sin(TAU * 360.0 * t) * 0.10 * exp(-t * 100.0)
		val += (_rng.randf() * 2.0 - 1.0) * 0.12 * exp(-t * 150.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_pixel_land() -> AudioStreamWAV:
	## Tiny pixel settling into place — micro-tick
	var dur := 0.025
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 250.0)
		var val := sin(TAU * 4000.0 * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_pixel_cascade() -> AudioStreamWAV:
	## Batch of pixels falling — rain-like patter
	var dur := 0.08
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := 3000.0 + sin(t * 80.0) * 1500.0
		var val := sin(TAU * freq * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.05 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_accum_explode() -> AudioStreamWAV:
	## Snow/leaf pile explosion — crunchy burst
	var dur := 0.20
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 15.0)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.25 * env
		var tone := sin(TAU * 150.0 * t) * 0.10 * env
		tone += sin(TAU * 80.0 * t) * 0.08 * env
		_write_sample(buf, i, noise + tone)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# MAGIC / MYSTICAL SOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_ogham_chime() -> AudioStreamWAV:
	## Single ogham reveal — crystalline bell tone
	var dur := 0.40
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 5.0) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		var val := sin(TAU * 1320.0 * t) * 0.12 * env
		val += sin(TAU * 1980.0 * t) * 0.06 * env
		val += sin(TAU * 2640.0 * t) * 0.03 * env
		val += sin(TAU * 660.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_ogham_unlock() -> AudioStreamWAV:
	## Ogham panel appearing — ascending mystical arpeggio
	var dur := 0.60
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.8
		# Ascending notes: C5, E5, G5
		var note1 := sin(TAU * 523.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.1) * 8.0, 0.0, 1.0)
		var note2 := sin(TAU * 659.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.25) * 8.0, 0.0, 1.0)
		var note3 := sin(TAU * 784.0 * t) * 0.10 * clampf(1.0 - abs(t - 0.40) * 6.0, 0.0, 1.0)
		var shimmer := sin(TAU * 2400.0 * t) * 0.02 * env
		_write_sample(buf, i, note1 + note2 + note3 + shimmer)
	return _make_stream(buf)


func _gen_bestiole_shimmer() -> AudioStreamWAV:
	## Bestiole ethereal appearance — shimmering fairy dust
	var dur := 0.80
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.5
		# Shimmering harmonics with slight detuning
		var val := sin(TAU * 880.0 * t) * 0.06 * env
		val += sin(TAU * 1322.0 * t) * 0.04 * env  # slightly detuned 5th
		val += sin(TAU * 1762.0 * t) * 0.03 * env
		# Sparkling high noise
		val += (_rng.randf() * 2.0 - 1.0) * 0.02 * env * sin(t * 30.0) * 0.5 + 0.5
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_eye_open() -> AudioStreamWAV:
	## Eyes opening — deep rising ambient drone
	var dur := 2.0
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.4
		var freq := lerpf(60.0, 280.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		val += sin(TAU * freq * 1.5 * t) * 0.04 * env
		val += sin(TAU * freq * 2.0 * t) * 0.02 * env
		# Subtle rumble
		val += (_rng.randf() * 2.0 - 1.0) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_flash_boom() -> AudioStreamWAV:
	## Blinding flash — bright impact then quick reverb
	var dur := 0.45
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 8.0)
		var attack := clampf(1.0 - t * 50.0, 0.0, 1.0)
		var val := (_rng.randf() * 2.0 - 1.0) * 0.35 * attack
		val += sin(TAU * 200.0 * t) * 0.20 * env
		val += sin(TAU * 100.0 * t) * 0.12 * env
		# High shimmer tail
		val += sin(TAU * 3000.0 * t) * 0.04 * exp(-t * 15.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_magic_reveal() -> AudioStreamWAV:
	## Result/archetype reveal — dramatic ascending shimmer
	var dur := 0.70
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(400.0, 1200.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		val += sin(TAU * freq * 1.5 * t) * 0.05 * env
		val += sin(TAU * freq * 2.01 * t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_skill_activate() -> AudioStreamWAV:
	## Ogham skill activation — sharp magical zap
	var dur := 0.25
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 12.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var freq := lerpf(2000.0, 800.0, t / dur)
		var val := sin(TAU * freq * t) * 0.15 * env
		val += sin(TAU * freq * 0.5 * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-t * 25.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT / ATMOSPHERIC SOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_path_scratch() -> AudioStreamWAV:
	## Ink scratching on parchment — for map path drawing
	var dur := 0.06
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.6
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.12 * env
		var scratch := sin(TAU * 5000.0 * t + sin(TAU * 120.0 * t) * 3.0) * 0.06 * env
		_write_sample(buf, i, noise + scratch)
	return _make_stream(buf)


func _gen_landmark_pop() -> AudioStreamWAV:
	## Small location marker appearing — soft pop
	var dur := 0.08
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 50.0) * sin(minf(t / 0.003, 1.0) * PI * 0.5)
		var val := sin(TAU * 1800.0 * t) * 0.12 * env
		val += sin(TAU * 900.0 * t) * 0.06 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_mist_breath() -> AudioStreamWAV:
	## Gentle breath of mist — very soft filtered noise
	var dur := 1.0
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.3
		var val := (_rng.randf() * 2.0 - 1.0) * 0.06 * env
		val += sin(TAU * 80.0 * t) * 0.02 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_aspect_shift() -> AudioStreamWAV:
	## Aspect gauge changing — tonal shift
	var dur := 0.15
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var val := sin(TAU * 440.0 * t) * 0.10 * env
		val += sin(TAU * 660.0 * t) * 0.05 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_aspect_up() -> AudioStreamWAV:
	## Aspect going up — rising pitch
	var dur := 0.18
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(400.0, 700.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_aspect_down() -> AudioStreamWAV:
	## Aspect going down — falling pitch
	var dur := 0.18
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var freq := lerpf(600.0, 300.0, t / dur)
		var val := sin(TAU * freq * t) * 0.10 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# BOOT / CELTOS SPECIFIC
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_boot_line() -> AudioStreamWAV:
	## Boot log line appearing — terminal blip
	var dur := 0.015
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 200.0)
		var val := sin(TAU * 2200.0 * t) * 0.10 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_boot_confirm() -> AudioStreamWAV:
	## Boot complete confirmation — satisfying double-beep
	var dur := 0.20
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var beep1 := sin(TAU * 880.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.03) * 40.0, 0.0, 1.0)
		var beep2 := sin(TAU * 1100.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.12) * 40.0, 0.0, 1.0)
		_write_sample(buf, i, beep1 + beep2)
	return _make_stream(buf)


func _gen_convergence() -> AudioStreamWAV:
	## Blocks converging toward eyes — whooshing with building tension
	var dur := 0.80
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := t / dur  # Building up
		var freq := lerpf(100.0, 500.0, t / dur)
		var val := sin(TAU * freq * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		val += sin(TAU * freq * 3.0 * t) * 0.02 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_slit_glow() -> AudioStreamWAV:
	## Eye slit starting to glow — ethereal hum
	var dur := 1.2
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.35
		var val := sin(TAU * 220.0 * t) * 0.06 * env
		val += sin(TAU * 330.0 * t) * 0.04 * env
		val += sin(TAU * 440.0 * t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# QUIZ SPECIFIC
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_choice_hover() -> AudioStreamWAV:
	## Hovering over a quiz choice — gentle tonal shift
	var dur := 0.05
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var val := sin(TAU * 1600.0 * t) * 0.08 * env
		val += sin(TAU * 2400.0 * t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_choice_select() -> AudioStreamWAV:
	## Quiz choice confirmed — warm bell
	var dur := 0.25
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 8.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var val := sin(TAU * 880.0 * t) * 0.12 * env
		val += sin(TAU * 1320.0 * t) * 0.06 * env
		val += sin(TAU * 1760.0 * t) * 0.03 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_result_reveal() -> AudioStreamWAV:
	## Personality result reveal — dramatic chord
	var dur := 1.0
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 2.5) * sin(minf(t / 0.02, 1.0) * PI * 0.5)
		# C major chord: C4, E4, G4, C5
		var val := sin(TAU * 262.0 * t) * 0.08 * env
		val += sin(TAU * 330.0 * t) * 0.06 * env
		val += sin(TAU * 392.0 * t) * 0.06 * env
		val += sin(TAU * 524.0 * t) * 0.04 * env
		# Shimmer
		val += sin(TAU * 2000.0 * t) * 0.02 * exp(-t * 5.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_question_transition() -> AudioStreamWAV:
	## Moving to next question — soft page turn
	var dur := 0.20
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.10 * env
		var tone := sin(TAU * 300.0 * t) * 0.04 * env
		_write_sample(buf, i, noise + tone)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# DICE SOUNDS (Phase 33)
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_dice_shake() -> AudioStreamWAV:
	## Dice rattling in hand — filtered noise + rapid ticks
	var dur := 0.20
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI)
		# Filtered noise for rattle
		var noise := (_rng.randf() * 2.0 - 1.0) * 0.12 * env
		# Rapid ticking (dice faces hitting)
		var tick_rate := 40.0
		var tick := sin(TAU * 3200.0 * t) * 0.06 * abs(sin(TAU * tick_rate * t)) * env
		_write_sample(buf, i, noise + tick)
	return _make_stream(buf)


func _gen_dice_roll() -> AudioStreamWAV:
	## Dice bouncing on wood — 3-4 decaying taps
	var dur := 0.40
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
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
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_dice_land() -> AudioStreamWAV:
	## Final dice landing — solid thud with wood overtone
	var dur := 0.10
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 50.0)
		var val := sin(TAU * 160.0 * t) * 0.30 * env
		val += sin(TAU * 320.0 * t) * 0.12 * exp(-t * 80.0)
		val += (_rng.randf() * 2.0 - 1.0) * 0.10 * exp(-t * 120.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_dice_crit_success() -> AudioStreamWAV:
	## Triumphant C major ascending chord — golden victory
	var dur := 0.50
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 3.0) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# C major arpeggio: C4 -> E4 -> G4 -> C5
		var n1 := sin(TAU * 262.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.0) * 12.0, 0.0, 1.0)
		var n2 := sin(TAU * 330.0 * t) * 0.08 * clampf(1.0 - abs(t - 0.08) * 12.0, 0.0, 1.0)
		var n3 := sin(TAU * 392.0 * t) * 0.10 * clampf(1.0 - abs(t - 0.16) * 10.0, 0.0, 1.0)
		var n4 := sin(TAU * 524.0 * t) * 0.12 * clampf(1.0 - abs(t - 0.24) * 8.0, 0.0, 1.0)
		# Shimmer overlay
		var shimmer := sin(TAU * 2000.0 * t) * 0.03 * env
		_write_sample(buf, i, n1 + n2 + n3 + n4 + shimmer)
	return _make_stream(buf)


func _gen_dice_crit_fail() -> AudioStreamWAV:
	## Ominous descending drone — deep rumble
	var dur := 0.60
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := sin(t / dur * PI) * 0.6
		var freq := lerpf(200.0, 60.0, t / dur)
		var val := sin(TAU * freq * t) * 0.15 * env
		val += sin(TAU * freq * 1.5 * t) * 0.06 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.08 * env
		# Low rumble
		val += sin(TAU * 40.0 * t) * 0.04 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# MINI-GAME SOUNDS (Phase 33)
# ═══════════════════════════════════════════════════════════════════════════════

func _gen_minigame_start() -> AudioStreamWAV:
	## Ascending chime — mini-game begins
	var dur := 0.30
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 6.0) * sin(minf(t / 0.005, 1.0) * PI * 0.5)
		var freq := lerpf(600.0, 1200.0, t / dur)
		var val := sin(TAU * freq * t) * 0.12 * env
		val += sin(TAU * freq * 1.5 * t) * 0.05 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_minigame_success() -> AudioStreamWAV:
	## Short fanfare — two bright notes
	var dur := 0.40
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		# Note 1: G4 (short)
		var n1 := sin(TAU * 392.0 * t) * 0.10 * clampf(1.0 - abs(t - 0.05) * 15.0, 0.0, 1.0)
		# Note 2: C5 (longer, triumphant)
		var n2 := sin(TAU * 524.0 * t) * 0.14 * clampf(1.0 - abs(t - 0.18) * 6.0, 0.0, 1.0)
		var n2_h := sin(TAU * 1048.0 * t) * 0.04 * clampf(1.0 - abs(t - 0.18) * 6.0, 0.0, 1.0)
		_write_sample(buf, i, n1 + n2 + n2_h)
	return _make_stream(buf)


func _gen_minigame_fail() -> AudioStreamWAV:
	## Dull thud — sad low tone
	var dur := 0.25
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 12.0)
		var val := sin(TAU * 150.0 * t) * 0.18 * env
		val += sin(TAU * 100.0 * t) * 0.08 * env
		val += (_rng.randf() * 2.0 - 1.0) * 0.05 * exp(-t * 30.0)
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_minigame_tick() -> AudioStreamWAV:
	## Rapid tick for timers
	var dur := 0.03
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 200.0)
		var val := sin(TAU * 3000.0 * t) * 0.10 * env
		_write_sample(buf, i, val)
	return _make_stream(buf)


func _gen_critical_alert() -> AudioStreamWAV:
	## Dramatic chord — critical choice incoming
	var dur := 0.50
	var buf := _alloc_buffer(dur)
	var count := _sample_count(dur)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 3.5) * sin(minf(t / 0.01, 1.0) * PI * 0.5)
		# Minor chord: A3, C4, E4 (dramatic tension)
		var val := sin(TAU * 220.0 * t) * 0.10 * env
		val += sin(TAU * 262.0 * t) * 0.08 * env
		val += sin(TAU * 330.0 * t) * 0.08 * env
		# Tremolo effect
		val *= 1.0 + sin(TAU * 6.0 * t) * 0.3
		_write_sample(buf, i, val)
	return _make_stream(buf)
