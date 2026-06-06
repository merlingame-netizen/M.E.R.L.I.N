## ═══════════════════════════════════════════════════════════════════════════════
## MerlinTTS — In-game neural voice for Merlin (VoxCPM bridge)
## ═══════════════════════════════════════════════════════════════════════════════
## Speaks text through the local VoxCPM server (tools/voxcpm/server.py) and plays
## the returned WAV. Designed to be SAFE: if the server is offline, every call is
## a graceful no-op — the game runs exactly as before, just silent.
##
## Usage (from anywhere, e.g. the Merlin speech-bar):
##     MerlinTTS.speak("Bonjour, jeune druide. La forêt t'attend.")
##     MerlinTTS.speak("Approche...", "merlin")        # clone the 'merlin' voice
##     MerlinTTS.stop()
##
## On CPU the first synthesis is slow (model load + RTF >> 1), so results are
## cached to user://voxcpm_cache/ — repeated lines replay instantly.
##
## Config: set MERLIN_TTS_URL env (or edit DEFAULT_URL) to point elsewhere.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ── Signals ─────────────────────────────────────────────────────────────────
signal speech_started(text: String)
signal speech_finished()
signal speech_failed(reason: String)
signal availability_changed(available: bool)

# ── Configuration ───────────────────────────────────────────────────────────
const DEFAULT_URL := "http://127.0.0.1:8808"
const CACHE_DIR := "user://voxcpm_cache"
const HEALTH_TIMEOUT := 3.0
const SYNTH_TIMEOUT := 120.0   # CPU first-call can be slow

# ── State ───────────────────────────────────────────────────────────────────
var base_url: String = DEFAULT_URL
var available: bool = false
var enabled: bool = true        # master switch (e.g. an options toggle)
var default_voice: String = ""  # set to "merlin" once a reference voice exists

var _http: HTTPRequest
var _player: AudioStreamPlayer
var _busy: bool = false
var _queue: Array = []          # of { text, voice }
var _current_text: String = ""
var _current_cache_path: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	var env_url := OS.get_environment("MERLIN_TTS_URL")
	if env_url != "":
		base_url = env_url

	DirAccess.make_dir_recursive_absolute(CACHE_DIR)

	_http = HTTPRequest.new()
	_http.timeout = SYNTH_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_player_finished)

	# Probe availability without blocking the boot.
	_check_availability()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Speak a line. Safe no-op if disabled or the server is unreachable.
func speak(text: String, voice: String = "") -> void:
	if not enabled:
		return
	var line := text.strip_edges()
	if line.is_empty():
		return
	var v := voice if voice != "" else default_voice

	# Cache hit → play immediately, no network round-trip.
	var cache_path := _cache_path_for(line, v)
	if FileAccess.file_exists(cache_path):
		_play_file(cache_path, line)
		return

	if not available:
		# Don't queue forever against a dead server; re-probe once and drop.
		_check_availability()
		return

	_queue.append({"text": line, "voice": v, "cache": cache_path})
	_pump_queue()


## Stop current playback and clear the pending queue.
func stop() -> void:
	_queue.clear()
	if _player and _player.playing:
		_player.stop()


## Manually toggle the whole subsystem (e.g. from an options menu).
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop()


## Returns true if the server answered /health.
func is_available() -> bool:
	return available


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — availability probe
# ═══════════════════════════════════════════════════════════════════════════════

func _check_availability() -> void:
	# Use a short-lived second HTTPRequest so we never collide with synthesis.
	var probe := HTTPRequest.new()
	probe.timeout = HEALTH_TIMEOUT
	add_child(probe)
	probe.request_completed.connect(
		func(_r, code, _h, _b):
			var was := available
			available = (code == 200)
			if was != available:
				availability_changed.emit(available)
			probe.queue_free()
	)
	var err := probe.request(base_url + "/health", PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		available = false
		probe.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — synthesis queue
# ═══════════════════════════════════════════════════════════════════════════════

func _pump_queue() -> void:
	if _busy or _queue.is_empty():
		return
	var job: Dictionary = _queue.pop_front()
	_busy = true
	_current_text = job["text"]
	_current_cache_path = job["cache"]

	var body := JSON.stringify({"text": job["text"], "voice": job["voice"]})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(base_url + "/synth", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		speech_failed.emit("request error %d" % err)
		_pump_queue()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		available = false
		availability_changed.emit(false)
		speech_failed.emit("http result=%d code=%d" % [result, code])
		_pump_queue()
		return

	# Persist to cache, then play from disk (single decode path).
	var f := FileAccess.open(_current_cache_path, FileAccess.WRITE)
	if f:
		f.store_buffer(body)
		f.close()

	_play_buffer(body, _current_text)
	_pump_queue()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — playback
# ═══════════════════════════════════════════════════════════════════════════════

func _play_buffer(buffer: PackedByteArray, text: String) -> void:
	var stream := AudioStreamWAV.load_from_buffer(buffer)
	if stream == null:
		speech_failed.emit("WAV decode failed")
		return
	_player.stream = stream
	_player.play()
	speech_started.emit(text)


func _play_file(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var buffer := f.get_buffer(f.get_length())
	f.close()
	_play_buffer(buffer, text)


func _on_player_finished() -> void:
	speech_finished.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — cache key
# ═══════════════════════════════════════════════════════════════════════════════

func _cache_path_for(text: String, voice: String) -> String:
	var key := (voice + "|" + text).sha256_text()
	return "%s/%s.wav" % [CACHE_DIR, key]
