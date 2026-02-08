extends Node
class_name RobotBlipVoice
## Generateur de voix robotique par "blips" synthetiques
## Style Undertale/Animal Crossing - parfait pour synchronisation texte progressif

signal blip_played(character: String)
signal speech_started()
signal speech_finished()

## Presets de voix robotique
const VOICE_PRESETS := {
	"Mignon": {
		"base_freq": 440.0,
		"freq_variation": 80.0,
		"blip_duration_ms": 45.0,
		"volume": 0.7,
		"wave_type": "sine",
		"chirp_enabled": true,
		"chirp_amount": 0.3
	},
	"Doux": {
		"base_freq": 330.0,
		"freq_variation": 50.0,
		"blip_duration_ms": 60.0,
		"volume": 0.6,
		"wave_type": "sine",
		"chirp_enabled": false,
		"chirp_amount": 0.0
	},
	"Clair": {
		"base_freq": 520.0,
		"freq_variation": 100.0,
		"blip_duration_ms": 35.0,
		"volume": 0.75,
		"wave_type": "square",
		"chirp_enabled": true,
		"chirp_amount": 0.2
	},
	"Gazouillis": {
		"base_freq": 600.0,
		"freq_variation": 150.0,
		"blip_duration_ms": 30.0,
		"volume": 0.65,
		"wave_type": "sine",
		"chirp_enabled": true,
		"chirp_amount": 0.5
	},
	"Robot": {
		"base_freq": 200.0,
		"freq_variation": 40.0,
		"blip_duration_ms": 50.0,
		"volume": 0.8,
		"wave_type": "square",
		"chirp_enabled": false,
		"chirp_amount": 0.0
	},
	"Merlin": {
		"base_freq": 380.0,
		"freq_variation": 120.0,
		"blip_duration_ms": 40.0,
		"volume": 0.72,
		"wave_type": "sine",
		"chirp_enabled": true,
		"chirp_amount": 0.35
	}
}

## Configuration
@export var preset: String = "Merlin":
	set(value):
		preset = value
		if VOICE_PRESETS.has(value):
			_apply_preset(VOICE_PRESETS[value])

@export_group("Frequence")
@export var base_freq: float = 380.0
@export var freq_variation: float = 120.0

@export_group("Timing")
@export var blip_duration_ms: float = 40.0
@export var silence_between_ms: float = 20.0
@export var chars_per_blip: int = 1  ## 1 = chaque caractere, 2+ = groupes

@export_group("Son")
@export_range(0.0, 1.0) var volume: float = 0.72
@export var wave_type: String = "sine"  ## sine, square, triangle, saw
@export var chirp_enabled: bool = true
@export var chirp_amount: float = 0.35  ## Glissement de frequence

@export_group("Variation")
@export var pitch_per_char: bool = true  ## Varier le pitch selon le caractere
@export var random_variation: float = 0.1  ## Variation aleatoire supplementaire

## Internes
var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: int = 22050
var _is_speaking: bool = false
var _current_phase: float = 0.0

## Caracteres qui declenchent un blip (ignorer espaces, ponctuation silencieuse)
var _blip_chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var _pause_chars := ".,!?;:-"  ## Caracteres qui ajoutent une pause


func _ready() -> void:
	_setup_audio()
	_apply_preset(VOICE_PRESETS.get(preset, VOICE_PRESETS["Merlin"]))


func _setup_audio() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = _sample_rate
	_generator.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = _generator
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _apply_preset(p: Dictionary) -> void:
	base_freq = p.get("base_freq", 380.0)
	freq_variation = p.get("freq_variation", 120.0)
	blip_duration_ms = p.get("blip_duration_ms", 40.0)
	volume = p.get("volume", 0.72)
	wave_type = p.get("wave_type", "sine")
	chirp_enabled = p.get("chirp_enabled", true)
	chirp_amount = p.get("chirp_amount", 0.35)


## Joue un blip pour un caractere donne
func play_blip(character: String = "a") -> void:
	if _playback == null:
		return

	var freq := _calculate_frequency(character)
	var samples := _generate_blip(freq)

	for sample in samples:
		_playback.push_frame(Vector2(sample, sample))

	blip_played.emit(character)


## Joue les blips pour une chaine complete (asynchrone via Timer)
func speak_text(text: String, chars_per_second: float = 30.0) -> void:
	if _is_speaking:
		stop_speaking()

	_is_speaking = true
	speech_started.emit()

	var char_delay := 1.0 / chars_per_second
	var char_count := 0

	for i in range(text.length()):
		if not _is_speaking:
			break

		var c := text[i]

		if c in _blip_chars:
			char_count += 1
			if char_count >= chars_per_blip:
				play_blip(c)
				char_count = 0
		elif c in _pause_chars:
			# Pause supplementaire pour la ponctuation
			await get_tree().create_timer(char_delay * 3).timeout
			continue
		elif c == " ":
			# Petit silence pour les espaces
			await get_tree().create_timer(char_delay * 0.5).timeout
			continue

		await get_tree().create_timer(char_delay).timeout

	_is_speaking = false
	speech_finished.emit()


## Arrete la parole en cours
func stop_speaking() -> void:
	_is_speaking = false


## Calcule la frequence pour un caractere
func _calculate_frequency(character: String) -> float:
	var freq := base_freq

	if pitch_per_char and character.length() > 0:
		# Utiliser le code ASCII pour varier le pitch
		var code := character.unicode_at(0)
		var normalized := fmod(float(code), 26.0) / 26.0  # 0.0 - 1.0
		freq += (normalized - 0.5) * freq_variation * 2.0

	# Ajouter variation aleatoire
	if random_variation > 0.0:
		freq += randf_range(-random_variation, random_variation) * freq_variation

	return clampf(freq, 100.0, 2000.0)


## Genere les samples audio pour un blip
func _generate_blip(freq: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var duration_sec := blip_duration_ms / 1000.0
	var num_samples := int(duration_sec * _sample_rate)

	samples.resize(num_samples)

	var phase := _current_phase
	var phase_inc := freq / _sample_rate

	for i in range(num_samples):
		var t := float(i) / float(num_samples)  # 0.0 - 1.0

		# Envelope ADSR simple (attack-decay)
		var envelope := 1.0
		var attack := 0.1
		var decay_start := 0.3
		if t < attack:
			envelope = t / attack
		elif t > decay_start:
			envelope = 1.0 - ((t - decay_start) / (1.0 - decay_start))
		envelope = clampf(envelope, 0.0, 1.0)

		# Chirp (glissement de frequence)
		var current_freq := freq
		if chirp_enabled:
			current_freq = freq * (1.0 + chirp_amount * (1.0 - t))

		phase_inc = current_freq / _sample_rate

		# Generation de la forme d'onde
		var sample := 0.0
		match wave_type:
			"sine":
				sample = sin(phase * TAU)
			"square":
				sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				sample *= 0.5  # Reduire le volume des carrees
			"triangle":
				var p := fmod(phase, 1.0)
				sample = 4.0 * abs(p - 0.5) - 1.0
			"saw":
				sample = 2.0 * fmod(phase, 1.0) - 1.0
				sample *= 0.5
			_:
				sample = sin(phase * TAU)

		sample *= envelope * volume
		samples[i] = clampf(sample, -1.0, 1.0)

		phase += phase_inc

	_current_phase = fmod(phase, 1.0)

	# Ajouter silence entre les blips
	var silence_samples := int((silence_between_ms / 1000.0) * _sample_rate)
	for i in range(silence_samples):
		samples.append(0.0)

	return samples


## Test rapide
func test_voice() -> void:
	speak_text("Bonjour, je suis Merlin!")


## Joue un blip de test
func test_blip() -> void:
	play_blip("a")
