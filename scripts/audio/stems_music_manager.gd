## ═══════════════════════════════════════════════════════════════════════════════
## Stems Music Manager — 4 stems × 8 biomes, crossfade by tension
## ═══════════════════════════════════════════════════════════════════════════════
## Phase 9 (DEV_PLAN_V2.5). Each biome has 4 music stems:
## - base: always playing (ambient drone)
## - rhythm: fades in at tension > 0.2
## - melody: fades in at tension > 0.4
## - climax: fades in at tension > 0.6
## Crossfade duration: 2-3s. All stems synced to same BPM.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name StemsMusicManager

signal biome_music_changed(biome: String)
signal tension_level_changed(level: int)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const STEM_NAMES: Array[String] = ["base", "rhythm", "melody", "climax"]
const CROSSFADE_DURATION: float = 2.5
const STEM_PATH_TEMPLATE := "res://audio/music/%s/%s.ogg"

# Tension thresholds for each stem layer
const STEM_THRESHOLDS: Dictionary = {
	"base": 0.0,
	"rhythm": 0.2,
	"melody": 0.4,
	"climax": 0.6,
}

const VOLUME_DB_MAX: float = 0.0
const VOLUME_DB_MIN: float = -80.0

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _current_biome: String = ""
var _current_tension: float = 0.0
var _players: Dictionary = {}  # stem_name -> AudioStreamPlayer
var _target_volumes: Dictionary = {}  # stem_name -> float (0.0-1.0)
var _active: bool = false
var _master_volume: float = 0.7


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup() -> void:
	for stem_name in STEM_NAMES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = VOLUME_DB_MIN
		add_child(player)
		_players[stem_name] = player
		_target_volumes[stem_name] = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME CHANGE — Load stems for new biome
# ═══════════════════════════════════════════════════════════════════════════════

func set_biome(biome: String) -> void:
	if biome == _current_biome:
		return

	# Fade out current stems
	_fade_all_out()
	_current_biome = biome

	# Load new stems
	for stem_name in STEM_NAMES:
		var path: String = STEM_PATH_TEMPLATE % [biome, stem_name]
		var player: AudioStreamPlayer = _players[stem_name]

		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			player.stream = stream
			player.volume_db = VOLUME_DB_MIN
		else:
			# No audio file — generate placeholder silence
			player.stream = null

	_active = true
	_update_stem_volumes(_current_tension)
	_start_all_stems()
	biome_music_changed.emit(biome)


func stop() -> void:
	_active = false
	_fade_all_out()
	for player in _players.values():
		if player is AudioStreamPlayer:
			player.stop()


# ═══════════════════════════════════════════════════════════════════════════════
# TENSION UPDATE — Crossfade stems based on tension
# ═══════════════════════════════════════════════════════════════════════════════

func set_tension(tension: float) -> void:
	tension = clampf(tension, 0.0, 0.8)
	if absf(tension - _current_tension) < 0.05:
		return
	_current_tension = tension
	_update_stem_volumes(tension)

	# Emit level change
	var level: int = 0
	if tension >= 0.6:
		level = 3
	elif tension >= 0.4:
		level = 2
	elif tension >= 0.2:
		level = 1
	tension_level_changed.emit(level)


func _update_stem_volumes(tension: float) -> void:
	for stem_name in STEM_NAMES:
		var threshold: float = float(STEM_THRESHOLDS.get(stem_name, 0.0))
		if tension >= threshold:
			# Fade volume based on how far above threshold
			var intensity: float = clampf((tension - threshold) / 0.2, 0.0, 1.0)
			# Base always at full volume
			if stem_name == "base":
				intensity = 1.0
			_target_volumes[stem_name] = intensity * _master_volume
		else:
			_target_volumes[stem_name] = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS — Smooth volume transitions
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _active:
		return

	var fade_speed: float = delta / CROSSFADE_DURATION

	for stem_name in STEM_NAMES:
		var player: AudioStreamPlayer = _players.get(stem_name)
		if player == null or player.stream == null:
			continue

		var target: float = float(_target_volumes.get(stem_name, 0.0))
		var current_linear: float = db_to_linear(player.volume_db)
		var new_linear: float = move_toward(current_linear, target, fade_speed)

		if new_linear < 0.01:
			player.volume_db = VOLUME_DB_MIN
		else:
			player.volume_db = linear_to_db(new_linear)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _start_all_stems() -> void:
	for player in _players.values():
		if player is AudioStreamPlayer and player.stream != null:
			if not player.playing:
				player.play()


func _fade_all_out() -> void:
	for stem_name in STEM_NAMES:
		_target_volumes[stem_name] = 0.0


func set_master_volume(volume: float) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	if _active:
		_update_stem_volumes(_current_tension)


func get_current_biome() -> String:
	return _current_biome


func get_current_tension() -> float:
	return _current_tension
