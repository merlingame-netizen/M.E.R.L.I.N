extends Node
class_name MerlinVoice

## MerlinVoice - Voix "Yaourt" style Animal Crossing
##
## 3 modes: AC Voice (Animalese WAV), Digital Voice (synthese), Off
## AC Voice supporte 5 banques de sons differentes

signal text_started(full_text: String)
signal text_updated(visible_text: String, progress: float)
signal text_finished()
signal character_displayed(char: String, index: int)
signal voice_ready(is_ready: bool)

## Modes de voix
enum VoiceMode { AC_VOICE, DIGITAL_VOICE, OFF }

const VOICE_MODE_LABELS := {
	VoiceMode.AC_VOICE: "Voix AC (Animalese)",
	VoiceMode.DIGITAL_VOICE: "Voix Numerique",
	VoiceMode.OFF: "Desactivee",
}

## Presets de voix (compatibles ACVoicebox)
const VOICE_PRESETS := {
	"Normal": {"base_pitch": 3.5, "pitch_variation": 0.3, "speed_scale": 1.0},
	"Aigu": {"base_pitch": 4.2, "pitch_variation": 0.35, "speed_scale": 1.1},
	"Grave": {"base_pitch": 2.8, "pitch_variation": 0.25, "speed_scale": 0.9},
	"Enfant": {"base_pitch": 4.5, "pitch_variation": 0.4, "speed_scale": 1.2},
	"Sage": {"base_pitch": 3.0, "pitch_variation": 0.2, "speed_scale": 0.85},
	"Joyeux": {"base_pitch": 3.8, "pitch_variation": 0.45, "speed_scale": 1.15},
	"Mysterieux": {"base_pitch": 2.6, "pitch_variation": 0.15, "speed_scale": 0.75},
	"Merlin": {"base_pitch": 3.2, "pitch_variation": 0.28, "speed_scale": 0.95},
}

## References externes
@export var text_label: RichTextLabel

## Configuration
@export_group("Voix")
@export var voice_mode: VoiceMode = VoiceMode.AC_VOICE
@export var current_preset: String = "Merlin"
@export var voice_enabled: bool = true
@export var sound_bank: String = "default"

@export_group("Parametres")
@export_range(2.0, 5.0) var base_pitch: float = 3.2
@export_range(0.0, 1.0) var pitch_variation: float = 0.28
@export_range(0.5, 2.0) var speed_scale: float = 0.95

@export_group("LLM")
@export var auto_speak_responses: bool = true
@export var strip_markdown: bool = true

## ACVoicebox (si disponible)
var _acvoicebox: Node = null
var _using_acvoicebox := false

## Fallback synthese douce
var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: int = 44100

## Etat
var _current_text: String = ""
var _visible_chars: int = 0
var _is_displaying: bool = false
var _char_timer: float = 0.0
var _is_ready: bool = false
var _connected_ai: Node = null
var _last_pitch: float = 294.0


func _ready() -> void:
	_try_load_acvoicebox()
	_setup_fallback_audio()

	apply_preset(current_preset)
	_is_ready = true
	voice_ready.emit(true)


func _try_load_acvoicebox() -> void:
	## Essayer de charger ACVoicebox si disponible
	var acvoicebox_path := "res://addons/acvoicebox/acvoicebox.tscn"

	if ResourceLoader.exists(acvoicebox_path):
		var scene = load(acvoicebox_path)
		if scene:
			_acvoicebox = scene.instantiate()
			_acvoicebox.name = "ACVoicebox"
			add_child(_acvoicebox)

			# Appliquer la banque de sons
			if _acvoicebox.has_method("set_sound_bank"):
				_acvoicebox.set_sound_bank(sound_bank)

			# Connecter les signaux
			if _acvoicebox.has_signal("characters_sounded"):
				_acvoicebox.characters_sounded.connect(_on_ac_character)
			if _acvoicebox.has_signal("text_updated"):
				_acvoicebox.text_updated.connect(_on_ac_text_updated)
			if _acvoicebox.has_signal("finished_phrase"):
				_acvoicebox.finished_phrase.connect(_on_ac_finished)

			# Verifier si les sons sont charges
			if _acvoicebox.has_method("is_ready") and _acvoicebox.is_ready():
				_using_acvoicebox = true
				print("MerlinVoice: ACVoicebox charge (banque: %s)" % sound_bank)
			else:
				_using_acvoicebox = false
				_acvoicebox.queue_free()
				_acvoicebox = null
				print("MerlinVoice: ACVoicebox sans sons, synthese disponible")


func _setup_fallback_audio() -> void:
	## Synthese douce en fallback
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = _sample_rate
	_generator.buffer_length = 0.15

	_player = AudioStreamPlayer.new()
	_player.stream = _generator
	_player.bus = "Master"
	_player.volume_db = -3.0
	_player.name = "SoftVoicePlayer"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _process(delta: float) -> void:
	if voice_mode == VoiceMode.AC_VOICE and _using_acvoicebox:
		return  # ACVoicebox gere tout

	if not _is_displaying:
		return

	_char_timer += delta
	var char_delay := 0.04 / speed_scale

	while _char_timer >= char_delay and _visible_chars < _current_text.length():
		_char_timer -= char_delay
		_advance_one_char()


func _advance_one_char() -> void:
	if _visible_chars >= _current_text.length():
		_finish_display()
		return

	var c := _current_text[_visible_chars]
	_visible_chars += 1

	if text_label != null:
		text_label.visible_characters = _visible_chars

	if voice_enabled and voice_mode == VoiceMode.DIGITAL_VOICE:
		_play_soft_sound(c)

	character_displayed.emit(c, _visible_chars - 1)
	text_updated.emit(_current_text.substr(0, _visible_chars), float(_visible_chars) / float(_current_text.length()))


func _finish_display() -> void:
	_is_displaying = false
	if text_label != null:
		text_label.visible_characters = -1
	text_finished.emit()


## ===== ACVoicebox callbacks =====

func _on_ac_character(chars: String) -> void:
	character_displayed.emit(chars, _visible_chars)
	_visible_chars += chars.length()


func _on_ac_text_updated(visible_text: String, progress: float) -> void:
	text_updated.emit(visible_text, progress)


func _on_ac_finished() -> void:
	_is_displaying = false
	text_finished.emit()


## ===== API PUBLIQUE =====

func display_text(text: String) -> void:
	if strip_markdown:
		text = _strip_markdown(text)

	_current_text = text
	_visible_chars = 0
	_char_timer = 0.0
	_is_displaying = true

	if text_label != null:
		text_label.text = text
		text_label.visible_characters = 0

	text_started.emit(text)

	match voice_mode:
		VoiceMode.AC_VOICE:
			if _using_acvoicebox and _acvoicebox != null:
				_acvoicebox.text_label = text_label
				_acvoicebox.play_string(text)
		VoiceMode.DIGITAL_VOICE:
			pass  # Handled in _process via _advance_one_char
		VoiceMode.OFF:
			pass  # Handled in _process (text display only, no sound)


func speak(text: String) -> void:
	display_text(text)


func stop() -> void:
	_is_displaying = false
	if voice_mode == VoiceMode.AC_VOICE and _using_acvoicebox and _acvoicebox != null:
		_acvoicebox.stop_speaking()


func skip_to_end() -> void:
	if _using_acvoicebox and _acvoicebox != null:
		_acvoicebox.skip_to_end()
	elif text_label != null:
		_visible_chars = _current_text.length()
		text_label.visible_characters = -1
	_finish_display()


func is_displaying() -> bool:
	return _is_displaying


func is_speaking() -> bool:
	if _using_acvoicebox and _acvoicebox != null:
		return _acvoicebox.is_speaking()
	return _is_displaying


func is_ready() -> bool:
	return _is_ready


func uses_acvoicebox() -> bool:
	return _using_acvoicebox


## ===== PRESETS =====

func apply_preset(preset_name: String) -> void:
	if not VOICE_PRESETS.has(preset_name):
		push_warning("MerlinVoice: Preset inconnu: " + preset_name)
		return

	current_preset = preset_name
	var p: Dictionary = VOICE_PRESETS[preset_name]

	base_pitch = p.get("base_pitch", 3.2)
	pitch_variation = p.get("pitch_variation", 0.28)
	speed_scale = p.get("speed_scale", 0.95)

	if _using_acvoicebox and _acvoicebox != null:
		_acvoicebox.base_pitch = base_pitch
		_acvoicebox.pitch_variation = pitch_variation
		_acvoicebox.speed_scale = speed_scale


func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for key in VOICE_PRESETS.keys():
		names.append(key)
	return names


func get_current_preset_params() -> Dictionary:
	return {
		"base_pitch": base_pitch,
		"pitch_variation": pitch_variation,
		"speed_scale": speed_scale
	}


## ===== MODE DE VOIX =====

func set_voice_mode(mode: VoiceMode) -> void:
	voice_mode = mode
	voice_enabled = (mode != VoiceMode.OFF)


func get_voice_mode() -> VoiceMode:
	return voice_mode


func get_voice_mode_label(mode: VoiceMode) -> String:
	return VOICE_MODE_LABELS.get(mode, "Inconnu")


## ===== BANQUES DE SONS =====

func set_sound_bank(bank_name: String) -> void:
	sound_bank = bank_name
	if _using_acvoicebox and _acvoicebox != null:
		if _acvoicebox.has_method("set_sound_bank"):
			_acvoicebox.set_sound_bank(bank_name)


func get_sound_bank() -> String:
	return sound_bank


func get_sound_bank_names() -> Array[String]:
	if _acvoicebox != null and _acvoicebox.has_method("get_sound_bank_names"):
		return _acvoicebox.get_sound_bank_names()
	var names: Array[String] = ["default", "high", "low", "lowest", "med"]
	return names


func get_sound_bank_label(bank_name: String) -> String:
	if _acvoicebox != null and _acvoicebox.has_method("get_sound_bank_label"):
		return _acvoicebox.get_sound_bank_label(bank_name)
	var labels := {
		"default": "Classique", "high": "Aigu (Peppy)",
		"low": "Grave (Cranky)", "lowest": "Tres grave", "med": "Medium"
	}
	return labels.get(bank_name, bank_name)


## ===== CONNEXION LLM =====

func connect_to_ai(ai_node: Node) -> void:
	if _connected_ai != null:
		_disconnect_from_ai()
	_connected_ai = ai_node
	if ai_node.has_signal("response_received"):
		ai_node.response_received.connect(_on_ai_response)
	if ai_node.has_signal("response_chunk"):
		ai_node.response_chunk.connect(_on_ai_chunk)


func disconnect_from_ai() -> void:
	_disconnect_from_ai()


func _disconnect_from_ai() -> void:
	if _connected_ai != null:
		if _connected_ai.has_signal("response_received"):
			if _connected_ai.response_received.is_connected(_on_ai_response):
				_connected_ai.response_received.disconnect(_on_ai_response)
		if _connected_ai.has_signal("response_chunk"):
			if _connected_ai.response_chunk.is_connected(_on_ai_chunk):
				_connected_ai.response_chunk.disconnect(_on_ai_chunk)
	_connected_ai = null


func _on_ai_response(response) -> void:
	if not auto_speak_responses:
		return
	var text: String = ""
	if response is Dictionary:
		text = str(response.get("response", ""))
	elif response is String:
		text = response
	if text.strip_edges() != "":
		display_text(text)


func _on_ai_chunk(chunk: String) -> void:
	if auto_speak_responses:
		_current_text += chunk
		if text_label != null:
			text_label.text = _current_text
		if not _is_displaying:
			_is_displaying = true
			text_started.emit(_current_text)


## ===== SYNTHESE DOUCE (FALLBACK) =====

func _play_soft_sound(c: String) -> void:
	if _playback == null or not voice_enabled:
		return

	var lower_c := c.to_lower()

	# Ignorer espaces et ponctuation
	if c == " " or c in ".,!?;:-":
		return

	# Convertir pitch ACVoicebox (2-5) en frequence Hz (150-500)
	var freq := 150.0 + (base_pitch - 2.0) * 116.0  # 2->150Hz, 5->500Hz

	# Variation
	var variation := randf_range(-pitch_variation, pitch_variation) * 0.3
	freq *= (1.0 + variation)

	# Note basee sur le caractere
	if lower_c >= "a" and lower_c <= "z":
		var idx: int = lower_c.unicode_at(0) - "a".unicode_at(0)
		var pentatonic: Array[int] = [0, 2, 4, 7, 9]
		var note: int = pentatonic[idx % pentatonic.size()]
		freq *= pow(2.0, float(note) / 12.0)

	var samples := _generate_soft_tone(freq)

	for sample in samples:
		_playback.push_frame(Vector2(sample, sample))

	_last_pitch = freq


func _generate_soft_tone(freq: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var duration_sec := 0.06 / speed_scale
	var num_samples := int(duration_sec * _sample_rate)

	samples.resize(num_samples)

	var phase := 0.0

	for i in range(num_samples):
		var t := float(i) / float(num_samples)

		# Envelope douce
		var envelope := sin(t * PI) * 0.7

		# Sinusoide pure
		var sample := sin(phase * TAU) * envelope

		samples[i] = clampf(sample, -1.0, 1.0)

		phase += freq / _sample_rate

	# Petit silence
	var gap := int(0.01 * _sample_rate)
	for j in range(gap):
		samples.append(0.0)

	return samples


## ===== UTILITAIRES =====

func _strip_markdown(text: String) -> String:
	var result := text
	var patterns := [["**", ""], ["__", ""], ["*", ""], ["_", ""], ["`", ""], ["~~", ""]]
	for pattern in patterns:
		result = result.replace(pattern[0], pattern[1])
	var lines := result.split("\n")
	var clean_lines := PackedStringArray()
	for line in lines:
		var trimmed := line.strip_edges()
		while trimmed.begins_with("#"):
			trimmed = trimmed.substr(1).strip_edges()
		clean_lines.append(trimmed)
	return "\n".join(clean_lines)


func test_voice(custom_text: String = "") -> void:
	var text := custom_text if custom_text != "" else "Bonjour! Je suis Merlin, votre guide magique!"
	display_text(text)
