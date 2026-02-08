extends AudioStreamPlayer
class_name ACVoicebox

## ACVoicebox - Generateur de voix style Animal Crossing (Animalese)
##
## CHAQUE LETTRE est prononcee individuellement
## Comme dans Animal Crossing: chaque caractere = un son
##
## Origine: github.com/mattmarch/ACVoicebox (MIT License)

signal characters_sounded(characters: String)
signal text_updated(visible_text: String, progress: float)
signal finished_phrase()
signal voice_ready(is_ready: bool)

const PITCH_MULTIPLIER_RANGE := 0.25
const INFLECTION_SHIFT := 0.3
const SOUNDS_PATH := "res://addons/acvoicebox/sounds/"

## Mapping des caracteres vers des sons (style Animal Crossing)
## Chaque lettre a son propre son, les accents/chiffres utilisent des voyelles
const CHAR_TO_SOUND := {
	# Lettres standard (leur propre son)
	"a": "a", "b": "b", "c": "c", "d": "d", "e": "e", "f": "f", "g": "g",
	"h": "h", "i": "i", "j": "j", "k": "k", "l": "l", "m": "m", "n": "n",
	"o": "o", "p": "p", "q": "q", "r": "r", "s": "s", "t": "t", "u": "u",
	"v": "v", "w": "w", "x": "x", "y": "y", "z": "z",
	# Voyelles accentuees -> voyelle de base
	"à": "a", "â": "a", "ä": "a", "á": "a",
	"è": "e", "é": "e", "ê": "e", "ë": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i",
	"ò": "o", "ó": "o", "ô": "o", "ö": "o",
	"ù": "u", "ú": "u", "û": "u", "ü": "u",
	"ÿ": "y", "ý": "y",
	"ç": "s", "ñ": "n",
	# Chiffres -> sons voyelles varies
	"0": "o", "1": "a", "2": "u", "3": "e", "4": "a",
	"5": "i", "6": "i", "7": "e", "8": "u", "9": "a",
}

## Pitch de base (2.5 = grave, 4.5 = aigu)
@export_range(2.0, 5.0) var base_pitch := 3.5

## Variation du pitch (0 = monotone, 1 = tres varie)
@export_range(0.0, 1.0) var pitch_variation := 0.3

## Vitesse de lecture (multiplicateur)
@export_range(0.5, 2.0) var speed_scale := 1.0

## RichTextLabel pour synchronisation (optionnel)
@export var text_label: RichTextLabel

## Activer la voix
@export var voice_enabled := true

## Sons charges dynamiquement
var _sounds: Dictionary = {}
var _sounds_loaded := false

## File des sons a jouer
var _remaining_sounds: Array = []

## Texte complet et progression
var _full_text: String = ""
var _displayed_text: String = ""
var _is_speaking := false

## Presets de voix
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


func _ready() -> void:
	finished.connect(_on_finished)
	_load_sounds()
	voice_ready.emit(_sounds_loaded)


func _load_sounds() -> void:
	## Charge tous les sons disponibles
	var letters := "abcdefghijklmnopqrstuvwxyz"

	for letter in letters:
		var letter_path: String = SOUNDS_PATH + letter + ".wav"
		if ResourceLoader.exists(letter_path):
			_sounds[letter] = load(letter_path)

	# Sons speciaux
	var special := ["th", "sh", "blank", "longblank"]
	for s in special:
		var special_path: String = SOUNDS_PATH + s + ".wav"
		if ResourceLoader.exists(special_path):
			if s == "blank":
				_sounds[" "] = load(special_path)
			elif s == "longblank":
				_sounds["."] = load(special_path)
			else:
				_sounds[s] = load(special_path)

	_sounds_loaded = _sounds.size() > 0

	if not _sounds_loaded:
		push_warning("ACVoicebox: Aucun son trouve dans " + SOUNDS_PATH)
		push_warning("ACVoicebox: Executez le script d'installation des sons")


## ===== API PUBLIQUE =====

func play_string(in_string: String) -> void:
	## Joue une chaine de caracteres - CHAQUE LETTRE est prononcee
	if not _sounds_loaded:
		push_warning("ACVoicebox: Sons non charges")
		return

	_full_text = in_string
	_displayed_text = ""
	_is_speaking = true

	if text_label != null:
		text_label.text = in_string
		text_label.visible_characters = 0

	_parse_input_string(in_string)
	_play_next_sound()


func speak(text: String) -> void:
	play_string(text)


func display_text(text: String) -> void:
	play_string(text)


func stop_speaking() -> void:
	stop()
	_remaining_sounds.clear()
	_is_speaking = false

	if text_label != null:
		text_label.visible_characters = -1


func skip_to_end() -> void:
	stop()
	_remaining_sounds.clear()
	_displayed_text = _full_text

	if text_label != null:
		text_label.visible_characters = -1

	_is_speaking = false
	finished_phrase.emit()


func is_speaking() -> bool:
	return _is_speaking


func is_ready() -> bool:
	return _sounds_loaded


## ===== PRESETS =====

func apply_preset(preset_name: String) -> void:
	if not VOICE_PRESETS.has(preset_name):
		push_warning("ACVoicebox: Preset inconnu: " + preset_name)
		return

	var p: Dictionary = VOICE_PRESETS[preset_name]
	base_pitch = p.get("base_pitch", 3.5)
	pitch_variation = p.get("pitch_variation", 0.3)
	speed_scale = p.get("speed_scale", 1.0)


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


## ===== PARSING - CHAQUE CARACTERE =====

func _parse_input_string(in_string: String) -> void:
	_remaining_sounds.clear()

	var is_question := in_string.strip_edges().ends_with("?")
	var char_count := in_string.length()

	for i in range(char_count):
		var c := in_string[i]
		var lower_c := c.to_lower()

		# Inflexion montante pour les questions (derniers 20% du texte)
		var inflective := is_question and (float(i) / float(char_count) > 0.8)

		# Verifier combinaisons 2 caracteres (th, sh)
		if i < char_count - 1:
			var two_char := in_string.substr(i, 2).to_lower()
			if two_char == "th" and _sounds.has("th"):
				_add_symbol("th", c, inflective)
				continue
			elif two_char == "sh" and _sounds.has("sh"):
				_add_symbol("sh", c, inflective)
				continue

		# Determiner le son a jouer
		var sound_key := _get_sound_for_char(lower_c)
		_add_symbol(sound_key, c, inflective)


func _get_sound_for_char(c: String) -> String:
	## Retourne le son a jouer pour un caractere
	## CHAQUE caractere a un son (comme Animal Crossing)

	# Espace -> silence court
	if c == " ":
		return " "

	# Ponctuation -> pause
	if c in ".!?":
		return "."
	if c in ",;:":
		return " "

	# Mapping direct
	if CHAR_TO_SOUND.has(c):
		return CHAR_TO_SOUND[c]

	# Lettre standard
	if c >= "a" and c <= "z":
		return c

	# Caractere inconnu -> voyelle aleatoire basee sur le code unicode
	var vowels := ["a", "e", "i", "o", "u"]
	var idx := c.unicode_at(0) % vowels.size()
	return vowels[idx]


func _add_symbol(sound_key: String, character: String, inflective: bool) -> void:
	_remaining_sounds.append({
		"sound": sound_key,
		"character": character,
		"inflective": inflective
	})


## ===== PLAYBACK =====

func _play_next_sound() -> void:
	if _remaining_sounds.is_empty():
		_is_speaking = false
		if text_label != null:
			text_label.visible_characters = -1
		finished_phrase.emit()
		return

	var symbol: Dictionary = _remaining_sounds.pop_front()

	# Mettre a jour le texte affiche (1 caractere a la fois)
	_displayed_text += symbol.character
	characters_sounded.emit(symbol.character)

	# Mettre a jour le label
	if text_label != null:
		text_label.visible_characters = _displayed_text.length()

	# Emettre progression
	var progress := float(_displayed_text.length()) / float(_full_text.length()) if _full_text.length() > 0 else 1.0
	text_updated.emit(_displayed_text, progress)

	# Verifier si on a le son
	if not _sounds.has(symbol.sound):
		# Pas de son -> petit delai puis continuer
		await get_tree().create_timer(0.03 / speed_scale).timeout
		_play_next_sound()
		return

	# Configurer le pitch avec variation
	var pitch_mult := PITCH_MULTIPLIER_RANGE * pitch_variation
	var random_pitch := randf_range(-pitch_mult, pitch_mult)
	pitch_scale = base_pitch + random_pitch + (INFLECTION_SHIFT if symbol.inflective else 0.0)

	# Jouer le son de la lettre
	stream = _sounds[symbol.sound]
	play()


func _on_finished() -> void:
	## Appele quand un son de lettre est termine
	if _remaining_sounds.is_empty():
		return

	# Enchainer immediatement la lettre suivante (comme Animal Crossing)
	# Petit chevauchement pour fluidite
	await get_tree().create_timer(0.02 / speed_scale).timeout
	_play_next_sound()
