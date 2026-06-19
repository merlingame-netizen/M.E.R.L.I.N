extends Node
## Voice input for MERLIN — mic capture -> ASR microservice (HTTP) -> voice_recognized(text)
## -> fuzzy-match to a card option. Service-first: points at tools/asr/asr_server.py (PC/VM).
## Wire-up: add as a child node, set asr_url, call start_listening()/stop_listening(), connect
## `voice_recognized`. Mapping helper `match_choice()` is static + pure (unit-testable).
##
## Style: typed vars, snake_case, await (never yield). Standalone — not auto-loaded, so it
## cannot affect game startup until explicitly instantiated.

signal voice_recognized(text: String)
signal listening_changed(active: bool)
signal transcribe_failed(reason: String)

@export var asr_url: String = "http://127.0.0.1:8770"
@export var asr_token: String = ""              ## optional x-asr-token shared secret
@export var capture_bus: String = "VoiceCapture"  ## an audio bus carrying an AudioEffectCapture

var _http: HTTPRequest
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _frames: PackedVector2Array = PackedVector2Array()
var _listening: bool = false
var _sample_rate: float = 44100.0


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)


## Begin capturing mic audio (requires a bus named `capture_bus` with an AudioEffectCapture).
func start_listening() -> bool:
	var bus_idx: int = AudioServer.get_bus_index(capture_bus)
	if bus_idx < 0:
		transcribe_failed.emit("no audio bus '" + capture_bus + "' (add one with an AudioEffectCapture)")
		return false
	_capture = null
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var eff: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if eff is AudioEffectCapture:
			_capture = eff
			break
	if _capture == null:
		transcribe_failed.emit("bus '" + capture_bus + "' has no AudioEffectCapture")
		return false
	_sample_rate = AudioServer.get_mix_rate()
	_frames = PackedVector2Array()
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = capture_bus
		add_child(_mic_player)
	_mic_player.play()
	_capture.clear_buffer()
	_listening = true
	set_process(true)
	listening_changed.emit(true)
	return true


func _process(_delta: float) -> void:
	if not _listening or _capture == null:
		return
	var available: int = _capture.get_frames_available()
	if available > 0:
		_frames.append_array(_capture.get_buffer(available))


## Stop capturing and send the recorded audio to the ASR service.
func stop_listening() -> void:
	if not _listening:
		return
	_listening = false
	set_process(false)
	if _mic_player != null:
		_mic_player.stop()
	listening_changed.emit(false)
	var wav: PackedByteArray = _frames_to_wav(_frames, int(_sample_rate))
	if wav.size() <= 44:
		transcribe_failed.emit("no audio captured")
		return
	var headers: PackedStringArray = ["Content-Type: application/octet-stream"]
	if asr_token != "":
		headers.append("x-asr-token: " + asr_token)
	var err: int = _http.request_raw(asr_url.rstrip("/") + "/transcribe", headers, HTTPClient.METHOD_POST, wav)
	if err != OK:
		transcribe_failed.emit("http request error " + str(err))


func _on_http_completed(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		transcribe_failed.emit("ASR HTTP " + str(code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("text"):
		transcribe_failed.emit("bad ASR response")
		return
	voice_recognized.emit(str(parsed["text"]))


# ── WAV encode (PCM16 mono) ──────────────────────────────────────────────────
func _frames_to_wav(frames: PackedVector2Array, rate: int) -> PackedByteArray:
	var n: int = frames.size()
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var mono: float = clampf((frames[i].x + frames[i].y) * 0.5, -1.0, 1.0)
		var s: int = int(mono * 32767.0)
		data.encode_s16(i * 2, s)
	var out: PackedByteArray = PackedByteArray()
	var byte_rate: int = rate * 2
	out.append_array("RIFF".to_utf8_buffer())
	out.append_array(_u32(36 + data.size()))
	out.append_array("WAVE".to_utf8_buffer())
	out.append_array("fmt ".to_utf8_buffer())
	out.append_array(_u32(16))
	out.append_array(_u16(1))      # PCM
	out.append_array(_u16(1))      # mono
	out.append_array(_u32(rate))
	out.append_array(_u32(byte_rate))
	out.append_array(_u16(2))      # block align
	out.append_array(_u16(16))     # bits/sample
	out.append_array("data".to_utf8_buffer())
	out.append_array(_u32(data.size()))
	out.append_array(data)
	return out


func _u32(v: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


func _u16(v: int) -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v)
	return b


# ── Fuzzy mapping: transcribed text -> option index (pure/static, unit-testable) ─────
static func _norm(s: String) -> String:
	var low: String = s.to_lower()
	var pairs: Array = [["à", "a"], ["â", "a"], ["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"],
		["î", "i"], ["ï", "i"], ["ô", "o"], ["ù", "u"], ["û", "u"], ["ç", "c"], ["'", " "], ["’", " "]]
	for p in pairs:
		low = low.replace(p[0], p[1])
	return low.strip_edges()


## options: Array of Dictionaries with "label" and/or "verb". Returns best index or -1.
## Score = share of the spoken content-words (len>=3) explained by an option, + a verb bonus.
static func match_choice(text: String, options: Array, threshold: float = 0.5) -> int:
	var t: String = _norm(text)
	if t == "":
		return -1
	var content: PackedStringArray = PackedStringArray()
	for tok in t.split(" ", false):
		if tok.length() >= 3:
			content.append(tok)
	if content.is_empty():
		return -1
	var best_i: int = -1
	var best_score: float = 0.0
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var target: String = _norm(str(opt.get("label", "")) + " " + str(opt.get("verb", "")))
		if target.strip_edges() == "":
			continue
		var matched: int = 0
		for tok in content:
			if target.contains(tok):
				matched += 1
		var score: float = float(matched) / float(content.size())
		# verb bonus (drop reflexive "s " so "approcher" matches "s'approcher")
		var verb: String = _norm(str(opt.get("verb", "")))
		if verb.begins_with("s "):
			verb = verb.substr(2)
		if verb.length() >= 3 and t.contains(verb):
			score += 0.25
		if score > best_score:
			best_score = score
			best_i = i
	return best_i if best_score >= threshold else -1
