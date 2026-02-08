extends Control

## Scene de test - Voix Animal Crossing avec ACVoicebox
## Utilise des samples audio reels pour un son authentique

const MerlinVoiceClass = preload("res://addons/merlin_ai/merlin_voice.gd")
const PROFILES_PATH := "user://voice_profiles.json"

const TEST_PHRASES := {
	"Salutations": [
		"Salut Voyageur! Bienvenue dans mon antre magique.",
		"Ah, te voila enfin! Je t'attendais.",
		"Bonjour jeune aventurier!",
		"Bienvenue, bienvenue! Entre donc.",
	],
	"Joie": [
		"Magnifique! Tu as reussi!",
		"Ha ha! Excellente nouvelle!",
		"Formidable! Je savais que tu y arriverais!",
		"Quelle joie! Bravo!",
	],
	"Tristesse": [
		"Helas... les temps sont sombres.",
		"Je suis desole...",
		"Malheureusement, nous avons echoue...",
		"Quel dommage...",
	],
	"Mystere": [
		"Hmm... interessant...",
		"Les etoiles murmurent des secrets...",
		"Laisse-moi consulter mes grimoires...",
		"Les forces cosmiques sont en mouvement...",
	],
	"Questions": [
		"Comment puis-je t'aider?",
		"Qu'est-ce qui t'amene ici?",
		"As-tu trouve ce que tu cherchais?",
		"Veux-tu en savoir plus?",
	],
}

@onready var text_display: RichTextLabel = $Main/ContentArea/LeftPanel/TextDisplay
@onready var status_label: Label = $Main/TopBar/StatusLabel
@onready var back_button: Button = $Main/TopBar/BackButton

# Phrases
@onready var emotion_option: OptionButton = $Main/ContentArea/LeftPanel/PhraseSection/EmotionRow/EmotionOption
@onready var phrase_option: OptionButton = $Main/ContentArea/LeftPanel/PhraseSection/PhraseRow/PhraseOption
@onready var speak_button: Button = $Main/ContentArea/LeftPanel/PhraseSection/ButtonRow/SpeakButton
@onready var stop_button: Button = $Main/ContentArea/LeftPanel/PhraseSection/ButtonRow/StopButton
@onready var random_button: Button = $Main/ContentArea/LeftPanel/PhraseSection/ButtonRow/RandomButton

# Parametres voix
@onready var pitch_slider: HSlider = $Main/ContentArea/RightPanel/ParamsSection/PitchRow/PitchSlider
@onready var pitch_value: Label = $Main/ContentArea/RightPanel/ParamsSection/PitchRow/PitchValue
@onready var variation_slider: HSlider = $Main/ContentArea/RightPanel/ParamsSection/VariationRow/VariationSlider
@onready var variation_value: Label = $Main/ContentArea/RightPanel/ParamsSection/VariationRow/VariationValue
@onready var speed_slider: HSlider = $Main/ContentArea/RightPanel/ParamsSection/SpeedRow/SpeedSlider
@onready var speed_value: Label = $Main/ContentArea/RightPanel/ParamsSection/SpeedRow/SpeedValue

# Profils
@onready var preset_option: OptionButton = $Main/ContentArea/RightPanel/ProfileSection/PresetRow/PresetOption
@onready var profile_name_edit: LineEdit = $Main/ContentArea/RightPanel/ProfileSection/SaveRow/ProfileNameEdit
@onready var save_button: Button = $Main/ContentArea/RightPanel/ProfileSection/SaveRow/SaveButton
@onready var saved_profiles_option: OptionButton = $Main/ContentArea/RightPanel/ProfileSection/LoadRow/SavedProfilesOption
@onready var load_button: Button = $Main/ContentArea/RightPanel/ProfileSection/LoadRow/LoadButton
@onready var delete_button: Button = $Main/ContentArea/RightPanel/ProfileSection/LoadRow/DeleteButton

var merlin_voice: Node = null
var saved_profiles: Dictionary = {}


func _ready() -> void:
	_init_voice()
	_setup_ui()
	_bind_signals()
	_load_saved_profiles()

	# Afficher le mode utilise
	if merlin_voice.uses_acvoicebox():
		_update_status("ACVoicebox actif (sons reels)")
	else:
		_update_status("Mode synthese (installez les sons)")


func _init_voice() -> void:
	merlin_voice = MerlinVoiceClass.new()
	merlin_voice.name = "MerlinVoice"
	merlin_voice.text_label = text_display
	merlin_voice.auto_speak_responses = false
	add_child(merlin_voice)
	merlin_voice.text_started.connect(_on_text_started)
	merlin_voice.text_finished.connect(_on_text_finished)


func _setup_ui() -> void:
	emotion_option.clear()
	for emotion in TEST_PHRASES.keys():
		emotion_option.add_item(emotion)
	emotion_option.select(0)
	_update_phrases_for_emotion(0)

	preset_option.clear()
	for preset_name in MerlinVoiceClass.VOICE_PRESETS.keys():
		preset_option.add_item(preset_name)

	for i in range(preset_option.item_count):
		if preset_option.get_item_text(i) == "Merlin":
			preset_option.select(i)
			_apply_preset_to_ui("Merlin")
			break


func _bind_signals() -> void:
	back_button.pressed.connect(_on_back_pressed)
	emotion_option.item_selected.connect(_update_phrases_for_emotion)
	speak_button.pressed.connect(_on_speak_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	random_button.pressed.connect(_on_random_pressed)

	pitch_slider.value_changed.connect(_on_pitch_changed)
	variation_slider.value_changed.connect(_on_variation_changed)
	speed_slider.value_changed.connect(_on_speed_changed)

	preset_option.item_selected.connect(_on_preset_selected)
	save_button.pressed.connect(_on_save_profile)
	load_button.pressed.connect(_on_load_profile)
	delete_button.pressed.connect(_on_delete_profile)


func _update_phrases_for_emotion(index: int) -> void:
	var emotion = emotion_option.get_item_text(index)
	phrase_option.clear()
	if TEST_PHRASES.has(emotion):
		for phrase in TEST_PHRASES[emotion]:
			var short = phrase.substr(0, 35) + ("..." if phrase.length() > 35 else "")
			phrase_option.add_item(short)
	if phrase_option.item_count > 0:
		phrase_option.select(0)


func _on_speak_pressed() -> void:
	var emotion = emotion_option.get_item_text(emotion_option.selected)
	var phrase_idx = phrase_option.selected
	if TEST_PHRASES.has(emotion) and phrase_idx < TEST_PHRASES[emotion].size():
		merlin_voice.display_text(TEST_PHRASES[emotion][phrase_idx])


func _on_stop_pressed() -> void:
	merlin_voice.stop()
	merlin_voice.skip_to_end()
	_update_status("Arrete")


func _on_random_pressed() -> void:
	var emotions = TEST_PHRASES.keys()
	var emotion = emotions[randi() % emotions.size()]
	var phrases = TEST_PHRASES[emotion]
	merlin_voice.display_text(phrases[randi() % phrases.size()])


func _on_text_started(_text: String) -> void:
	_update_status("Parle...")
	speak_button.disabled = true


func _on_text_finished() -> void:
	if merlin_voice.uses_acvoicebox():
		_update_status("ACVoicebox actif")
	else:
		_update_status("Mode synthese")
	speak_button.disabled = false


## ===== PARAMETRES =====

func _on_pitch_changed(value: float) -> void:
	pitch_value.text = str(snapped(value, 0.1))
	merlin_voice.base_pitch = value
	if merlin_voice._acvoicebox:
		merlin_voice._acvoicebox.base_pitch = value


func _on_variation_changed(value: float) -> void:
	variation_value.text = str(int(value * 100)) + "%"
	merlin_voice.pitch_variation = value
	if merlin_voice._acvoicebox:
		merlin_voice._acvoicebox.pitch_variation = value


func _on_speed_changed(value: float) -> void:
	speed_value.text = "x" + str(snapped(value, 0.1))
	merlin_voice.speed_scale = value
	if merlin_voice._acvoicebox:
		merlin_voice._acvoicebox.speed_scale = value


## ===== PRESETS & PROFILS =====

func _on_preset_selected(index: int) -> void:
	var preset_name = preset_option.get_item_text(index)
	merlin_voice.apply_preset(preset_name)
	_apply_preset_to_ui(preset_name)


func _apply_preset_to_ui(preset_name: String) -> void:
	if not MerlinVoiceClass.VOICE_PRESETS.has(preset_name):
		return
	var p: Dictionary = MerlinVoiceClass.VOICE_PRESETS[preset_name]
	pitch_slider.value = p.get("base_pitch", 3.2)
	variation_slider.value = p.get("pitch_variation", 0.28)
	speed_slider.value = p.get("speed_scale", 0.95)


func _on_save_profile() -> void:
	var pname = profile_name_edit.text.strip_edges()
	if pname == "":
		_update_status("Entrez un nom")
		return
	saved_profiles[pname] = {
		"base_pitch": pitch_slider.value,
		"pitch_variation": variation_slider.value,
		"speed_scale": speed_slider.value
	}
	_save_profiles_to_file()
	_refresh_saved_profiles_list()
	_update_status("'" + pname + "' sauvegarde!")
	profile_name_edit.text = ""


func _on_load_profile() -> void:
	if saved_profiles_option.selected < 0:
		return
	var pname = saved_profiles_option.get_item_text(saved_profiles_option.selected)
	if not saved_profiles.has(pname):
		return
	var p: Dictionary = saved_profiles[pname]
	pitch_slider.value = p.get("base_pitch", 3.2)
	variation_slider.value = p.get("pitch_variation", 0.28)
	speed_slider.value = p.get("speed_scale", 0.95)
	# Appliquer
	merlin_voice.base_pitch = pitch_slider.value
	merlin_voice.pitch_variation = variation_slider.value
	merlin_voice.speed_scale = speed_slider.value
	_update_status("'" + pname + "' charge!")


func _on_delete_profile() -> void:
	if saved_profiles_option.selected < 0:
		return
	var pname = saved_profiles_option.get_item_text(saved_profiles_option.selected)
	if saved_profiles.has(pname):
		saved_profiles.erase(pname)
		_save_profiles_to_file()
		_refresh_saved_profiles_list()
		_update_status("'" + pname + "' supprime!")


func _save_profiles_to_file() -> void:
	var file = FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_profiles, "\t"))
		file.close()


func _load_saved_profiles() -> void:
	if FileAccess.file_exists(PROFILES_PATH):
		var file = FileAccess.open(PROFILES_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary:
				saved_profiles = data
	_refresh_saved_profiles_list()


func _refresh_saved_profiles_list() -> void:
	saved_profiles_option.clear()
	for pname in saved_profiles.keys():
		saved_profiles_option.add_item(pname)


func _update_status(text: String) -> void:
	status_label.text = text


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
