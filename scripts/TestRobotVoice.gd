extends Control

const PRESETS := {
	"Mignon": {"pitch": 1.45, "volume": 0.85, "chirp_strength": 0.06, "chirp_hz": 1400.0, "chirp_ms": 12.0},
	"Doux": {"pitch": 1.25, "volume": 0.78, "chirp_strength": 0.03, "chirp_hz": 1100.0, "chirp_ms": 10.0},
	"Clair": {"pitch": 1.10, "volume": 0.9, "chirp_strength": 0.02, "chirp_hz": 900.0, "chirp_ms": 8.0},
	"Gazouillis": {"pitch": 1.6, "volume": 0.82, "chirp_strength": 0.08, "chirp_hz": 1700.0, "chirp_ms": 14.0},
}

@onready var status_label: Label = $Center/Panel/VBox/StatusLabel
@onready var preset_option: OptionButton = $Center/Panel/VBox/PresetRow/PresetOption
@onready var text_input: LineEdit = $Center/Panel/VBox/TextRow/TextInput
@onready var pitch_slider: HSlider = $Center/Panel/VBox/PitchRow/PitchSlider
@onready var pitch_value: Label = $Center/Panel/VBox/PitchRow/PitchValue
@onready var volume_slider: HSlider = $Center/Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Center/Panel/VBox/VolumeRow/VolumeValue
@onready var chirp_strength_slider: HSlider = $Center/Panel/VBox/ChirpStrengthRow/ChirpStrengthSlider
@onready var chirp_strength_value: Label = $Center/Panel/VBox/ChirpStrengthRow/ChirpStrengthValue
@onready var chirp_hz_slider: HSlider = $Center/Panel/VBox/ChirpHzRow/ChirpHzSlider
@onready var chirp_hz_value: Label = $Center/Panel/VBox/ChirpHzRow/ChirpHzValue
@onready var chirp_ms_slider: HSlider = $Center/Panel/VBox/ChirpMsRow/ChirpMsSlider
@onready var chirp_ms_value: Label = $Center/Panel/VBox/ChirpMsRow/ChirpMsValue
@onready var speak_button: Button = $Center/Panel/VBox/ButtonRow/SpeakButton
@onready var stop_button: Button = $Center/Panel/VBox/ButtonRow/StopButton
@onready var back_button: Button = $Center/Panel/VBox/ButtonRow/BackButton
@onready var player: RobotVoicePlayer = $RobotVoicePlayer

var voice: Object = null

func _ready() -> void:
	_setup_presets()
	_bind_ui()
	_init_voice()
	_apply_preset("Mignon")

func _setup_presets() -> void:
	preset_option.clear()
	for key in PRESETS.keys():
		preset_option.add_item(key)
	preset_option.select(0)

func _bind_ui() -> void:
	preset_option.item_selected.connect(_on_preset_selected)
	pitch_slider.value_changed.connect(_on_pitch_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	chirp_strength_slider.value_changed.connect(_on_chirp_strength_changed)
	chirp_hz_slider.value_changed.connect(_on_chirp_hz_changed)
	chirp_ms_slider.value_changed.connect(_on_chirp_ms_changed)
	speak_button.pressed.connect(_on_speak_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _init_voice() -> void:
	if ClassDB.class_exists("RobotVoice"):
		voice = ClassDB.instantiate("RobotVoice")
		status_label.text = "Voix Merlin: OK"
	else:
		status_label.text = "Voix Merlin: extension absente (compiler avec Colab)"

func _apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	var p = PRESETS[name]
	pitch_slider.value = p["pitch"]
	volume_slider.value = p["volume"]
	chirp_strength_slider.value = p["chirp_strength"]
	chirp_hz_slider.value = p["chirp_hz"]
	chirp_ms_slider.value = p["chirp_ms"]
	_apply_to_voice()
	_update_labels()

func _apply_to_voice() -> void:
	if voice == null:
		return
	voice.set_pitch(pitch_slider.value)
	voice.set_volume(volume_slider.value)
	voice.set_chirp_strength(chirp_strength_slider.value)
	voice.set_chirp_hz(chirp_hz_slider.value)
	voice.set_chirp_ms(chirp_ms_slider.value)

func _update_labels() -> void:
	pitch_value.text = _fmt(pitch_slider.value)
	volume_value.text = _fmt(volume_slider.value)
	chirp_strength_value.text = _fmt(chirp_strength_slider.value)
	chirp_hz_value.text = str(int(chirp_hz_slider.value))
	chirp_ms_value.text = _fmt(chirp_ms_slider.value)

func _fmt(value: float) -> String:
	return String.num(value, 2)

func _on_preset_selected(index: int) -> void:
	var name = preset_option.get_item_text(index)
	_apply_preset(name)

func _on_pitch_changed(_v: float) -> void:
	_apply_to_voice()
	_update_labels()

func _on_volume_changed(_v: float) -> void:
	_apply_to_voice()
	_update_labels()

func _on_chirp_strength_changed(_v: float) -> void:
	_apply_to_voice()
	_update_labels()

func _on_chirp_hz_changed(_v: float) -> void:
	_apply_to_voice()
	_update_labels()

func _on_chirp_ms_changed(_v: float) -> void:
	_apply_to_voice()
	_update_labels()

func _on_speak_pressed() -> void:
	if voice == null:
		status_label.text = "Voix Merlin: extension absente"
		return
	var text = text_input.text.strip_edges()
	if text == "":
		text = "Salut, je suis Merlin"
	var samples: PackedFloat32Array = voice.speak(text)
	if samples.is_empty():
		status_label.text = "Aucun echantillon genere"
		return
	player.push_mono(samples)
	status_label.text = "Merlin: " + text

func _on_stop_pressed() -> void:
	player.reset()
	status_label.text = "Lecture stoppee"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
