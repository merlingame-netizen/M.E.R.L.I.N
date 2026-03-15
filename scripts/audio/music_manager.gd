## ═══════════════════════════════════════════════════════════════════════════════
## MusicManager — Phase 9 Crossfade Music Controller
## ═══════════════════════════════════════════════════════════════════════════════
## Manages background music with crossfade transitions between biomes, hub, menu.
## Works alongside StemsMusicManager for tension-based stem mixing.
## Designed as autoload singleton.
##
## Usage:
##   MusicManager.set_biome_music("broceliande")
##   MusicManager.set_hub_music()
##   MusicManager.fade_out(2.0)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MusicManagerV2

signal track_changed(track_id: String)
signal fade_completed

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const DEFAULT_VOLUME_DB: float = -6.0
const CROSSFADE_DURATION: float = 2.0
const FADE_IN_DURATION: float = 1.5
const VOLUME_DB_MIN: float = -80.0

## Track ID constants
const TRACK_HUB: String = "hub"
const TRACK_MENU: String = "menu"

## Biome to music file mapping (loop required, intro optional).
## Paths are stubs — replace with actual audio files when available.
const BIOME_MUSIC: Dictionary = {
	"broceliande": {
		"loop": "res://audio/music/broceliande/loop.ogg",
		"intro": "res://audio/music/broceliande/intro.ogg",
	},
	"landes": {
		"loop": "res://audio/music/landes/loop.ogg",
	},
	"cotes": {
		"loop": "res://audio/music/cotes/loop.ogg",
	},
	"cercles": {
		"loop": "res://audio/music/cercles/loop.ogg",
	},
	"marais": {
		"loop": "res://audio/music/marais/loop.ogg",
	},
	"collines": {
		"loop": "res://audio/music/collines/loop.ogg",
	},
	"villages": {
		"loop": "res://audio/music/villages/loop.ogg",
	},
	"dolmens": {
		"loop": "res://audio/music/dolmens/loop.ogg",
	},
}

const HUB_MUSIC: Dictionary = {
	"loop": "res://audio/music/hub/loop.ogg",
}

const MENU_MUSIC: Dictionary = {
	"loop": "res://audio/music/menu/loop.ogg",
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null  # Currently audible
var _fade_tween: Tween = null
var _current_track_id: String = ""
var _is_playing: bool = false
var _master_volume_db: float = DEFAULT_VOLUME_DB
var _music_enabled: bool = true


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Music"
	_player_a.volume_db = VOLUME_DB_MIN
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Music"
	_player_b.volume_db = VOLUME_DB_MIN
	add_child(_player_b)

	_player_a.finished.connect(_on_player_finished.bind(_player_a))
	_player_b.finished.connect(_on_player_finished.bind(_player_b))

	_active_player = _player_a


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Set music for a specific biome. Crossfades from current track.
## Does nothing if biome has no music entry or is already playing.
func set_biome_music(biome_id: String) -> void:
	if not _music_enabled:
		return

	var track_id: String = "biome_%s" % biome_id
	if track_id == _current_track_id and _is_playing:
		return

	if not BIOME_MUSIC.has(biome_id):
		push_warning("[MusicManagerV2] No music mapping for biome: %s" % biome_id)
		return

	var music_data: Dictionary = BIOME_MUSIC[biome_id]
	var loop_path: String = str(music_data.get("loop", ""))
	var intro_path: String = str(music_data.get("intro", ""))

	_crossfade_to(track_id, loop_path, intro_path)


## Set hub music. Crossfades from current track.
func set_hub_music() -> void:
	if not _music_enabled:
		return
	if _current_track_id == TRACK_HUB and _is_playing:
		return

	var loop_path: String = str(HUB_MUSIC.get("loop", ""))
	var intro_path: String = str(HUB_MUSIC.get("intro", ""))
	_crossfade_to(TRACK_HUB, loop_path, intro_path)


## Set menu music. Crossfades from current track.
func set_menu_music() -> void:
	if not _music_enabled:
		return
	if _current_track_id == TRACK_MENU and _is_playing:
		return

	var loop_path: String = str(MENU_MUSIC.get("loop", ""))
	var intro_path: String = str(MENU_MUSIC.get("intro", ""))
	_crossfade_to(TRACK_MENU, loop_path, intro_path)


## Fade out the current music over the given duration.
func fade_out(duration: float = 1.0) -> void:
	if not _is_playing:
		return

	_kill_tween()
	_fade_tween = create_tween()

	if _player_a.playing:
		_fade_tween.parallel().tween_property(_player_a, "volume_db", VOLUME_DB_MIN, duration)
	if _player_b.playing:
		_fade_tween.parallel().tween_property(_player_b, "volume_db", VOLUME_DB_MIN, duration)

	_fade_tween.chain().tween_callback(_on_fade_out_complete)


## Immediately stop all music.
func stop() -> void:
	_kill_tween()
	_player_a.stop()
	_player_b.stop()
	_is_playing = false
	_current_track_id = ""


## Set master volume for music (in dB).
func set_volume(volume_db: float) -> void:
	_master_volume_db = clampf(volume_db, VOLUME_DB_MIN, 6.0)
	if _active_player and _active_player.playing:
		_active_player.volume_db = _master_volume_db


## Enable or disable music playback.
func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if not enabled:
		stop()


## Returns true if music is currently playing.
func is_playing() -> bool:
	return _is_playing


## Returns the current track ID (e.g., "biome_broceliande", "hub", "menu").
func get_current_track() -> String:
	return _current_track_id


# ═══════════════════════════════════════════════════════════════════════════════
# CROSSFADE ENGINE
# ═══════════════════════════════════════════════════════════════════════════════

func _crossfade_to(track_id: String, loop_path: String, intro_path: String) -> void:
	if loop_path.is_empty():
		push_warning("[MusicManagerV2] No loop path for track: %s" % track_id)
		return

	# Determine which player is inactive (for crossfade target)
	var outgoing: AudioStreamPlayer = _active_player
	var incoming: AudioStreamPlayer = _player_b if _active_player == _player_a else _player_a

	# Load the loop stream
	var loop_stream: AudioStream = null
	if ResourceLoader.exists(loop_path):
		loop_stream = load(loop_path) as AudioStream

	if loop_stream == null:
		# No file yet (stub paths) — update state but don't play
		_current_track_id = track_id
		track_changed.emit(track_id)
		return

	# Load optional intro
	var intro_stream: AudioStream = null
	if not intro_path.is_empty() and ResourceLoader.exists(intro_path):
		intro_stream = load(intro_path) as AudioStream

	# Setup incoming player
	if intro_stream:
		incoming.stream = intro_stream
	else:
		incoming.stream = loop_stream
		_enable_looping(loop_stream)

	incoming.volume_db = VOLUME_DB_MIN
	incoming.play()

	# Crossfade
	_kill_tween()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	# Fade in incoming
	_fade_tween.tween_property(incoming, "volume_db", _master_volume_db, CROSSFADE_DURATION)

	# Fade out outgoing (if playing)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", VOLUME_DB_MIN, CROSSFADE_DURATION)

	_fade_tween.chain().tween_callback(func() -> void:
		outgoing.stop()
		outgoing.volume_db = VOLUME_DB_MIN
	)

	# Store loop stream for after intro finishes
	if intro_stream:
		incoming.set_meta("_pending_loop", loop_stream)

	_active_player = incoming
	_current_track_id = track_id
	_is_playing = true
	track_changed.emit(track_id)


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _on_player_finished(player: AudioStreamPlayer) -> void:
	if not _is_playing:
		return

	# Check if there's a pending loop after intro
	if player.has_meta("_pending_loop"):
		var loop_stream: AudioStream = player.get_meta("_pending_loop") as AudioStream
		player.remove_meta("_pending_loop")
		if loop_stream:
			_enable_looping(loop_stream)
			player.stream = loop_stream
			player.volume_db = _master_volume_db
			player.play()
			return

	# If this was the active looping player, restart it
	if player == _active_player and player.stream:
		player.play()


func _on_fade_out_complete() -> void:
	_player_a.stop()
	_player_b.stop()
	_player_a.volume_db = VOLUME_DB_MIN
	_player_b.volume_db = VOLUME_DB_MIN
	_is_playing = false
	_current_track_id = ""
	fade_completed.emit()


func _enable_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.loop_end <= 0 and wav.mix_rate > 0:
			var total_frames: int = int(wav.get_length() * float(wav.mix_rate))
			if total_frames > 0:
				wav.loop_end = total_frames


func _kill_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
