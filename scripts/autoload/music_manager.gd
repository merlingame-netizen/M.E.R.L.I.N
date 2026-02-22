## ═══════════════════════════════════════════════════════════════════════════════
## MusicManager — Persistent background music with cross-scene continuity
## ═══════════════════════════════════════════════════════════════════════════════
## Autoload singleton. Music persists across scene changes.
## Usage:
##   MusicManager.play_intro_music()   — start from IntroCeltOS
##   MusicManager.fade_out(3.0)        — fade out over 3 seconds
##   MusicManager.stop()               — immediate stop
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const INTRO_MUSIC_PATH := "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-loop.wav"
const INTRO_MUSIC_INTRO_PATH := "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-intro.wav"
const DEFAULT_VOLUME_DB := -6.0
const FADE_IN_DURATION := 1.5
const CROSSFADE_DURATION := 2.0

## Biome → music mapping. Each entry has "intro" (optional) and "loop" (required).
const BIOME_MUSIC: Dictionary = {
	"foret_broceliande": {
		"intro": "res://music/loop/CHAS DONZ PART1 (Cover).mp3-intro.wav",
		"loop": "res://music/loop/CHAS DONZ PART1 (Cover).mp3-loop.wav",
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _player_intro: AudioStreamPlayer
var _player_loop: AudioStreamPlayer
var _fade_tween: Tween
var _is_playing := false
var _current_track := ""


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_player_intro = AudioStreamPlayer.new()
	_player_intro.bus = "Master"
	_player_intro.volume_db = DEFAULT_VOLUME_DB
	add_child(_player_intro)

	_player_loop = AudioStreamPlayer.new()
	_player_loop.bus = "Master"
	_player_loop.volume_db = DEFAULT_VOLUME_DB
	add_child(_player_loop)

	_player_intro.finished.connect(_on_intro_finished)
	_player_loop.finished.connect(_on_loop_finished)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Start the intro music (plays intro section, then loops the loop section).
## Safe to call multiple times — won't restart if already playing same track.
func play_intro_music() -> void:
	if _is_playing and _current_track == "intro":
		return

	_kill_fade_tween()
	_current_track = "intro"
	_is_playing = true

	# Load intro section
	var intro_stream := load(INTRO_MUSIC_INTRO_PATH) as AudioStream
	var loop_stream := load(INTRO_MUSIC_PATH) as AudioStream

	if intro_stream:
		_player_intro.stream = intro_stream
		_player_intro.volume_db = -80.0
		_player_intro.play()

		# Fade in
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player_intro, "volume_db", DEFAULT_VOLUME_DB, FADE_IN_DURATION)
	elif loop_stream:
		# No intro file — go straight to loop
		_start_loop_playback()

	# Pre-load the loop stream and enable looping
	if loop_stream:
		_player_loop.stream = loop_stream
		_enable_wav_looping(loop_stream)


## Play biome-specific music (crossfade from current track).
## Falls back to no music if biome has no entry in BIOME_MUSIC.
func play_biome_music(biome_key: String) -> void:
	if not BIOME_MUSIC.has(biome_key):
		return

	var track_id: String = "biome_%s" % biome_key
	if _is_playing and _current_track == track_id:
		return

	var music_data: Dictionary = BIOME_MUSIC[biome_key]
	var intro_path: String = str(music_data.get("intro", ""))
	var loop_path: String = str(music_data.get("loop", ""))

	if loop_path.is_empty():
		return

	# Crossfade out current music before starting biome track
	if _is_playing:
		_kill_fade_tween()
		_fade_tween = create_tween()
		_fade_tween.set_parallel(true)
		if _player_intro.playing:
			_fade_tween.tween_property(_player_intro, "volume_db", -80.0, CROSSFADE_DURATION)
		if _player_loop.playing:
			_fade_tween.tween_property(_player_loop, "volume_db", -80.0, CROSSFADE_DURATION)
		_fade_tween.chain().tween_callback(func():
			_player_intro.stop()
			_player_loop.stop()
			_play_biome_track(track_id, intro_path, loop_path)
		)
	else:
		_play_biome_track(track_id, intro_path, loop_path)


## Fade out the music over the given duration (seconds).
func fade_out(duration: float = 3.0) -> void:
	if not _is_playing:
		return

	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	if _player_intro.playing:
		_fade_tween.tween_property(_player_intro, "volume_db", -80.0, duration)
	if _player_loop.playing:
		_fade_tween.tween_property(_player_loop, "volume_db", -80.0, duration)

	_fade_tween.chain().tween_callback(_on_fade_complete)


## Immediately stop all music.
func stop() -> void:
	_kill_fade_tween()
	_player_intro.stop()
	_player_loop.stop()
	_is_playing = false
	_current_track = ""


## Returns true if music is currently playing (including during fade out).
func is_playing() -> bool:
	return _is_playing


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _on_intro_finished() -> void:
	if _is_playing and (_current_track == "intro" or _current_track.begins_with("biome_")):
		_start_loop_playback()


func _on_loop_finished() -> void:
	if _is_playing and _player_loop.stream:
		print("[MusicManager] _on_loop_finished — restarting loop")
		_player_loop.play()


func _play_biome_track(track_id: String, intro_path: String, loop_path: String) -> void:
	_current_track = track_id
	_is_playing = true

	var loop_stream: AudioStream = load(loop_path) as AudioStream
	if loop_stream:
		_player_loop.stream = loop_stream
		_enable_wav_looping(loop_stream)

	var intro_stream: AudioStream = null
	if not intro_path.is_empty():
		intro_stream = load(intro_path) as AudioStream

	if intro_stream:
		_player_intro.stream = intro_stream
		_player_intro.volume_db = -80.0
		_player_intro.play()
		_kill_fade_tween()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player_intro, "volume_db", DEFAULT_VOLUME_DB, FADE_IN_DURATION)
	elif loop_stream:
		_start_loop_playback()


func _start_loop_playback() -> void:
	if _player_loop.stream:
		_enable_wav_looping(_player_loop.stream)
		_player_loop.volume_db = DEFAULT_VOLUME_DB
		_player_loop.play()


## Enable looping on an AudioStreamWAV resource.
## Sets loop_mode and computes loop_end from stream length if import default is invalid.
func _enable_wav_looping(stream: AudioStream) -> void:
	if not stream is AudioStreamWAV:
		return
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	# Import default loop_end is -1 which prevents internal looping.
	# Compute total sample frames from stream length and mix_rate.
	if wav.loop_end <= 0 and wav.mix_rate > 0:
		var total_frames: int = int(wav.get_length() * float(wav.mix_rate))
		if total_frames > 0:
			wav.loop_end = total_frames
			print("[MusicManager] Set loop_end=%d for stream (%.1fs)" % [total_frames, wav.get_length()])


func _on_fade_complete() -> void:
	_player_intro.stop()
	_player_loop.stop()
	_is_playing = false
	_current_track = ""
	# Reset volumes for next play
	_player_intro.volume_db = DEFAULT_VOLUME_DB
	_player_loop.volume_db = DEFAULT_VOLUME_DB


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
