extends Control
# Last modified: 2026-02-08 - Voice sliders fix

## TestLLMSceneUltimate - Scene de test ultime pour LLM
## Features:
## - Multi-backend support (MerlinLLM, NobodyWho)
## - Mode dialogue avec 4 choix interactifs
## - Animations de chargement
## - Metriques visuelles (latence, qualite)
## - Style DRU cohérent

signal test_completed(results: Dictionary)

# =============================================================================
# CONSTANTS
# =============================================================================

const DRU_COLORS := {
	"bg_dark": Color(0.07, 0.08, 0.1),
	"bg_panel": Color(0.12, 0.14, 0.18),
	"bg_input": Color(0.15, 0.17, 0.22),  # Fond sombre pour inputs
	"accent": Color(0.74, 0.66, 0.45),
	"text": Color(0.92, 0.88, 0.72),
	"text_bright": Color(1.0, 0.98, 0.9),  # Texte brillant pour inputs
	"text_dim": Color(0.6, 0.58, 0.52),
	"placeholder": Color(0.5, 0.48, 0.42),
	"success": Color(0.4, 0.75, 0.45),
	"warning": Color(0.85, 0.65, 0.25),
	"error": Color(0.85, 0.35, 0.35),
	"choice_hover": Color(0.25, 0.28, 0.35),
}

const TRINITY_MODELS := {
	"Q4_K_M": {"file": "qwen2.5-3b-instruct-q4_k_m.gguf", "size_mb": 2000, "desc": "Qwen2.5 3B (defaut)"},
}

const MODEL_DIRS := [
	"res://addons/merlin_llm/models",
	"C:/models/trinity-nano",
]

# === PROMPTS ULTRA-COURTS POUR TRINITY-NANO ===
# REGLE: ~15 tokens max, AUCUN exemple, instruction unique

const MERLIN_SYSTEM := """Merlin. Court. Francais."""

const CHOICE_SYSTEM := """Merlin repond. Puis CHOIX: avec 4 options."""

# === PARAMETRES OPTIMISES POUR VITESSE (LLM Expert Review) ===
const LLM_MAX_TOKENS := 60  # Forcer la concision (-30% latence)
const LLM_TEMPERATURE := 0.4  # Plus déterministe
const LLM_TOP_P := 0.75
const LLM_TOP_K := 25  # Réduit pour moins de variabilité
const LLM_REPETITION_PENALTY := 1.6  # Très fort pour éviter répétitions

const MAX_CHOICE_LENGTH := 60  # Limite caracteres par choix

const TEST_PROMPTS := [
	{"name": "Salutation", "text": "Salue le joueur qui arrive dans ton antre."},
	{"name": "Conseil", "text": "Donne un conseil court pour la quete."},
	{"name": "Ogham", "text": "Explique ce qu'est un Ogham en une phrase."},
	{"name": "Choix moral", "text": "Pose une question morale au joueur."},
]

const TYPEWRITER_SPEED := 45.0  # chars per second

# =============================================================================
# NODES (built dynamically)
# =============================================================================

var main_container: VBoxContainer
var header_panel: PanelContainer
var model_selector: OptionButton
var backend_selector: OptionButton
var prompt_input: TextEdit
var generate_btn: Button
var choice_mode_toggle: CheckBox
var run_all_btn: Button
var clear_btn: Button

var output_container: VBoxContainer
var response_label: RichTextLabel
var choices_container: VBoxContainer
var choice_buttons: Array[Button] = []

# Merlin portrait + voice
var merlin_portrait: TextureRect
var merlin_container: HBoxContainer
var voicebox: Node  # ACVoicebox
var _current_emotion := "SAGE"

# Merlin emotions -> portrait paths (using Assets/Sprite for better quality)
const MERLIN_PORTRAITS := {
	"SAGE": "res://Assets/Sprite/Merlin.png",
	"PENSIF": "res://Assets/Sprite/Merlin_AUTOMNE.png",
	"QUESTION": "res://Assets/Sprite/Merlin_PRINTEMPS.png",
	"COLERE": "res://Assets/Sprite/Merlin_ETE.png",
	"SURPRIS": "res://Assets/Sprite/Merlin_HIVER.png",
	"PEUR": "res://Assets/Sprite/Merlin_AUTOMNE.png",
}

# Emotion keywords for detection
const EMOTION_KEYWORDS := {
	"SAGE": ["sagesse", "ancien", "connais", "savoir", "verite", "secret"],
	"PENSIF": ["pense", "reflechis", "peut-etre", "hmm", "interessant", "curieux"],
	"QUESTION": ["pourquoi", "comment", "qui", "quoi", "demande", "?"],
	"COLERE": ["non", "jamais", "danger", "erreur", "attention", "!"],
	"SURPRIS": ["oh", "ah", "incroyable", "etonnant", "surprenant", "vraiment"],
	"PEUR": ["prudence", "menace", "sombre", "ombre", "fuis", "terrible"],
}

# Robotic voice settings (for RobotBlipVoice)
const MERLIN_VOICE := {
	"base_freq": 380.0,        # Base frequency Hz
	"freq_variation": 120.0,   # Frequency variation
	"blip_duration_ms": 40.0,  # Duration per blip
	"volume": 0.72,            # Volume 0-1
	"chirp_amount": 0.35,      # Chirp effect
}

# Voice sliders
var voice_sliders_panel: PanelContainer
var slider_base_freq: HSlider
var slider_freq_variation: HSlider
var slider_blip_duration: HSlider
var slider_chirp: HSlider
var robot_voice: Node  # RobotBlipVoice

var loading_panel: PanelContainer
var loading_spinner: ColorRect
var loading_label: Label

var metrics_panel: PanelContainer
var latency_bar: ProgressBar
var latency_label: Label
var tokens_label: Label
var quality_label: Label

var status_bar: Label
var history_container: VBoxContainer

# =============================================================================
# STATE
# =============================================================================

var _is_generating := false
var _current_model_path := ""
var _models_cache: Dictionary = {}
var _spinner_angle := 0.0
var _test_results: Array[Dictionary] = []
var _conversation_history: Array[String] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_ui()
	_apply_dru_theme()
	_scan_models()
	_connect_signals()
	# Préchauffement asynchrone du modèle
	_warmup_model.call_deferred()

func _process(delta: float) -> void:
	if loading_panel.visible:
		_spinner_angle += delta * 360.0
		if _spinner_angle > 360.0:
			_spinner_angle -= 360.0
		loading_spinner.queue_redraw()

# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = DRU_COLORS.bg_dark
	add_child(bg)

	# Main margin
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 12)
	margin.add_child(main_container)

	_build_header()
	_build_controls()
	_build_voice_sliders()
	_build_output()
	_build_loading()
	_build_metrics()
	_build_status()

func _build_header() -> void:
	header_panel = _create_panel()
	main_container.add_child(header_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	header_panel.add_child(hbox)

	var title := Label.new()
	title.text = "LLM Test Ultimate"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", DRU_COLORS.accent)
	hbox.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Backend selector
	var backend_label := Label.new()
	backend_label.text = "Backend:"
	backend_label.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	hbox.add_child(backend_label)

	backend_selector = OptionButton.new()
	backend_selector.custom_minimum_size = Vector2(140, 0)
	backend_selector.add_item("MerlinLLM")
	if ClassDB.class_exists("NobodyWho"):
		backend_selector.add_item("NobodyWho")
	hbox.add_child(backend_selector)

	# Model selector
	var model_label := Label.new()
	model_label.text = "Model:"
	model_label.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	hbox.add_child(model_label)

	model_selector = OptionButton.new()
	model_selector.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(model_selector)

func _build_controls() -> void:
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	main_container.add_child(controls)

	# Prompt input
	var prompt_panel := _create_panel()
	prompt_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(prompt_panel)

	var prompt_vbox := VBoxContainer.new()
	prompt_vbox.add_theme_constant_override("separation", 8)
	prompt_panel.add_child(prompt_vbox)

	var prompt_label := Label.new()
	prompt_label.text = "Prompt"
	prompt_label.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	prompt_vbox.add_child(prompt_label)

	prompt_input = TextEdit.new()
	prompt_input.custom_minimum_size = Vector2(0, 100)
	prompt_input.placeholder_text = "Ecris ta demande a Merlin..."
	prompt_input.add_theme_font_size_override("font_size", 18)
	prompt_input.add_theme_color_override("font_color", DRU_COLORS.text_bright)
	prompt_input.add_theme_color_override("font_placeholder_color", DRU_COLORS.placeholder)
	prompt_input.add_theme_color_override("background_color", DRU_COLORS.bg_input)
	# Style pour le fond du TextEdit
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = DRU_COLORS.bg_input
	input_style.set_border_width_all(2)
	input_style.border_color = DRU_COLORS.text_dim
	input_style.set_corner_radius_all(6)
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	input_style.content_margin_top = 10
	input_style.content_margin_bottom = 10
	prompt_input.add_theme_stylebox_override("normal", input_style)
	var input_focus := input_style.duplicate()
	input_focus.border_color = DRU_COLORS.accent
	prompt_input.add_theme_stylebox_override("focus", input_focus)
	prompt_vbox.add_child(prompt_input)

	# Mode toggle
	choice_mode_toggle = CheckBox.new()
	choice_mode_toggle.text = "Mode 4 choix"
	choice_mode_toggle.button_pressed = true
	prompt_vbox.add_child(choice_mode_toggle)

	# Buttons column
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	btn_vbox.custom_minimum_size = Vector2(140, 0)
	controls.add_child(btn_vbox)

	generate_btn = _create_button("Generer", DRU_COLORS.accent)
	btn_vbox.add_child(generate_btn)

	run_all_btn = _create_button("Run All Tests", DRU_COLORS.text_dim)
	btn_vbox.add_child(run_all_btn)

	clear_btn = _create_button("Clear", DRU_COLORS.text_dim)
	btn_vbox.add_child(clear_btn)

func _build_voice_sliders() -> void:
	voice_sliders_panel = _create_panel()
	main_container.add_child(voice_sliders_panel)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	voice_sliders_panel.add_child(main_hbox)

	# Title
	var title_label := Label.new()
	title_label.text = "Voix Merlin"
	title_label.add_theme_color_override("font_color", DRU_COLORS.accent)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.custom_minimum_size = Vector2(100, 0)
	main_hbox.add_child(title_label)

	# Sliders container
	var sliders_grid := GridContainer.new()
	sliders_grid.columns = 4
	sliders_grid.add_theme_constant_override("h_separation", 16)
	sliders_grid.add_theme_constant_override("v_separation", 8)
	sliders_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(sliders_grid)

	# Base Frequency slider
	slider_base_freq = _create_voice_slider(sliders_grid, "Frequence", 100.0, 800.0, MERLIN_VOICE.base_freq)
	slider_base_freq.value_changed.connect(_on_voice_param_changed.bind("base_freq"))

	# Frequency Variation slider
	slider_freq_variation = _create_voice_slider(sliders_grid, "Variation", 0.0, 200.0, MERLIN_VOICE.freq_variation)
	slider_freq_variation.value_changed.connect(_on_voice_param_changed.bind("freq_variation"))

	# Blip Duration slider
	slider_blip_duration = _create_voice_slider(sliders_grid, "Duree (ms)", 20.0, 100.0, MERLIN_VOICE.blip_duration_ms)
	slider_blip_duration.value_changed.connect(_on_voice_param_changed.bind("blip_duration_ms"))

	# Chirp Amount slider
	slider_chirp = _create_voice_slider(sliders_grid, "Chirp", 0.0, 1.0, MERLIN_VOICE.chirp_amount)
	slider_chirp.value_changed.connect(_on_voice_param_changed.bind("chirp_amount"))

	# Test voice button
	var test_btn := Button.new()
	test_btn.text = "Test"
	test_btn.custom_minimum_size = Vector2(60, 32)
	test_btn.pressed.connect(_on_test_voice_pressed)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = DRU_COLORS.bg_panel
	btn_style.set_border_width_all(1)
	btn_style.border_color = DRU_COLORS.accent
	btn_style.set_corner_radius_all(4)
	test_btn.add_theme_stylebox_override("normal", btn_style)
	test_btn.add_theme_color_override("font_color", DRU_COLORS.accent)
	main_hbox.add_child(test_btn)


func _create_voice_slider(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float) -> HSlider:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)

	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 0.01 if max_val <= 1.0 else 1.0
	slider.custom_minimum_size = Vector2(100, 20)
	vbox.add_child(slider)

	return slider


func _on_voice_param_changed(value: float, param: String) -> void:
	if robot_voice == null:
		return
	match param:
		"base_freq":
			robot_voice.base_freq = value
		"freq_variation":
			robot_voice.freq_variation = value
		"blip_duration_ms":
			robot_voice.blip_duration_ms = value
		"chirp_amount":
			robot_voice.chirp_amount = value


func _on_test_voice_pressed() -> void:
	if robot_voice and robot_voice.has_method("speak_text"):
		robot_voice.speak_text("Bienvenue, voyageur!", 25.0)
	elif robot_voice and robot_voice.has_method("test_voice"):
		robot_voice.test_voice()


func _build_output() -> void:
	var output_panel := _create_panel()
	output_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_panel.custom_minimum_size = Vector2(0, 300)
	main_container.add_child(output_panel)

	output_container = VBoxContainer.new()
	output_container.add_theme_constant_override("separation", 16)
	output_panel.add_child(output_container)

	var response_title := Label.new()
	response_title.text = "Reponse de Merlin"
	response_title.add_theme_color_override("font_color", DRU_COLORS.accent)
	output_container.add_child(response_title)

	# Merlin container: portrait + text side by side
	merlin_container = HBoxContainer.new()
	merlin_container.add_theme_constant_override("separation", 16)
	output_container.add_child(merlin_container)

	# Merlin portrait
	var portrait_panel := PanelContainer.new()
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.1, 0.12, 0.16)
	portrait_style.set_corner_radius_all(8)
	portrait_style.set_border_width_all(2)
	portrait_style.border_color = DRU_COLORS.accent
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	merlin_container.add_child(portrait_panel)

	merlin_portrait = TextureRect.new()
	merlin_portrait.custom_minimum_size = Vector2(120, 120)
	merlin_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	merlin_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_portrait("SAGE")
	portrait_panel.add_child(merlin_portrait)

	# Response text
	response_label = RichTextLabel.new()
	response_label.bbcode_enabled = true
	response_label.fit_content = true
	response_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	response_label.custom_minimum_size = Vector2(0, 100)
	response_label.add_theme_font_size_override("normal_font_size", 18)
	response_label.add_theme_color_override("default_color", DRU_COLORS.text)
	merlin_container.add_child(response_label)

	# ACVoicebox for voice
	_setup_voicebox()

	# Choices container
	var choices_title := Label.new()
	choices_title.text = "Tes choix:"
	choices_title.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	choices_title.visible = false
	choices_title.name = "ChoicesTitle"
	output_container.add_child(choices_title)

	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 8)
	output_container.add_child(choices_container)


func _setup_voicebox() -> void:
	# Try RobotBlipVoice first (our custom robotic voice generator)
	var robot_script = load("res://addons/robot_voice/robot_blip_voice.gd")
	if robot_script:
		robot_voice = Node.new()
		robot_voice.set_script(robot_script)
		add_child(robot_voice)

		# Apply Merlin preset
		if robot_voice.has_method("_apply_preset"):
			robot_voice.preset = "Merlin"
		# Apply custom voice settings
		robot_voice.base_freq = MERLIN_VOICE.base_freq
		robot_voice.freq_variation = MERLIN_VOICE.freq_variation
		robot_voice.blip_duration_ms = MERLIN_VOICE.blip_duration_ms
		robot_voice.volume = MERLIN_VOICE.volume
		robot_voice.chirp_amount = MERLIN_VOICE.chirp_amount
		robot_voice.chirp_enabled = true
		robot_voice.pitch_per_char = true

		_update_status("Voix robotique RobotBlipVoice activee", DRU_COLORS.success)
		return

	# Fallback: Create ACVoicebox if RobotBlipVoice not available
	if ClassDB.class_exists("ACVoicebox"):
		voicebox = ClassDB.instantiate("ACVoicebox")
	else:
		# Try loading script directly
		var vb_script = load("res://addons/acvoicebox/acvoicebox.gd")
		if vb_script:
			voicebox = AudioStreamPlayer.new()
			voicebox.set_script(vb_script)

	if voicebox:
		add_child(voicebox)
		# Apply robotic Merlin voice
		if voicebox.has_method("apply_preset"):
			voicebox.apply_preset("Merlin")
		voicebox.text_label = response_label


func _load_portrait(emotion: String) -> void:
	if not MERLIN_PORTRAITS.has(emotion):
		emotion = "SAGE"
	var path: String = MERLIN_PORTRAITS[emotion]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			merlin_portrait.texture = tex
			_current_emotion = emotion


func _detect_emotion(text: String) -> String:
	var lower_text := text.to_lower()
	var best_emotion := "SAGE"
	var best_score := 0

	for emotion in EMOTION_KEYWORDS:
		var score := 0
		for keyword in EMOTION_KEYWORDS[emotion]:
			if lower_text.find(keyword) != -1:
				score += 1
		if score > best_score:
			best_score = score
			best_emotion = emotion

	return best_emotion


func _update_merlin_emotion(text: String) -> void:
	var emotion := _detect_emotion(text)
	if emotion != _current_emotion:
		_load_portrait(emotion)
		# Animate portrait change
		var tween := create_tween()
		tween.tween_property(merlin_portrait, "modulate:a", 0.5, 0.1)
		tween.tween_callback(func(): _load_portrait(emotion))
		tween.tween_property(merlin_portrait, "modulate:a", 1.0, 0.2)

func _build_loading() -> void:
	loading_panel = PanelContainer.new()
	loading_panel.visible = false
	loading_panel.set_anchors_preset(Control.PRESET_CENTER)
	loading_panel.offset_left = -120
	loading_panel.offset_right = 120
	loading_panel.offset_top = -60
	loading_panel.offset_bottom = 60
	add_child(loading_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = DRU_COLORS.bg_panel
	style.set_border_width_all(2)
	style.border_color = DRU_COLORS.accent
	style.set_corner_radius_all(12)
	loading_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_panel.add_child(vbox)

	# Spinner
	loading_spinner = ColorRect.new()
	loading_spinner.custom_minimum_size = Vector2(40, 40)
	loading_spinner.color = Color.TRANSPARENT
	loading_spinner.draw.connect(_draw_spinner)
	vbox.add_child(loading_spinner)

	loading_label = Label.new()
	loading_label.text = "Generation en cours..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", DRU_COLORS.text)
	vbox.add_child(loading_label)

func _build_metrics() -> void:
	metrics_panel = _create_panel()
	main_container.add_child(metrics_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	metrics_panel.add_child(hbox)

	# Latency
	var latency_vbox := VBoxContainer.new()
	latency_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(latency_vbox)

	var latency_title := Label.new()
	latency_title.text = "Latence"
	latency_title.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	latency_vbox.add_child(latency_title)

	latency_bar = ProgressBar.new()
	latency_bar.custom_minimum_size = Vector2(0, 20)
	latency_bar.max_value = 10000  # 10 seconds max
	latency_bar.value = 0
	latency_vbox.add_child(latency_bar)

	latency_label = Label.new()
	latency_label.text = "-- ms"
	latency_label.add_theme_color_override("font_color", DRU_COLORS.text)
	latency_vbox.add_child(latency_label)

	# Tokens
	var tokens_vbox := VBoxContainer.new()
	hbox.add_child(tokens_vbox)

	var tokens_title := Label.new()
	tokens_title.text = "Tokens"
	tokens_title.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	tokens_vbox.add_child(tokens_title)

	tokens_label = Label.new()
	tokens_label.text = "-- tokens"
	tokens_label.add_theme_color_override("font_color", DRU_COLORS.text)
	tokens_vbox.add_child(tokens_label)

	# Quality indicator
	var quality_vbox := VBoxContainer.new()
	hbox.add_child(quality_vbox)

	var quality_title := Label.new()
	quality_title.text = "Qualite"
	quality_title.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	quality_vbox.add_child(quality_title)

	quality_label = Label.new()
	quality_label.text = "--"
	quality_label.add_theme_color_override("font_color", DRU_COLORS.text)
	quality_vbox.add_child(quality_label)

func _build_status() -> void:
	status_bar = Label.new()
	status_bar.text = "Pret. Selectionnez un modele et entrez un prompt."
	status_bar.add_theme_color_override("font_color", DRU_COLORS.text_dim)
	status_bar.add_theme_font_size_override("font_size", 14)
	main_container.add_child(status_bar)

# =============================================================================
# HELPERS
# =============================================================================

func _create_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DRU_COLORS.bg_panel
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 44)

	var style := StyleBoxFlat.new()
	style.bg_color = DRU_COLORS.bg_panel
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = DRU_COLORS.choice_hover
	hover.border_color = DRU_COLORS.accent
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = Color(0.2, 0.22, 0.28)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", color)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _create_choice_button(text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = "%d. %s" % [index + 1, text]
	btn.custom_minimum_size = Vector2(0, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var style := StyleBoxFlat.new()
	style.bg_color = DRU_COLORS.bg_panel
	style.set_border_width_all(1)
	style.border_color = DRU_COLORS.text_dim
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = DRU_COLORS.choice_hover
	hover.border_color = DRU_COLORS.accent
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", DRU_COLORS.text)
	btn.add_theme_font_size_override("font_size", 16)

	btn.pressed.connect(_on_choice_selected.bind(index, text))
	return btn

func _draw_spinner() -> void:
	var center := loading_spinner.size / 2
	var radius := 16.0
	var arc_angle := deg_to_rad(_spinner_angle)

	# Draw spinning arc
	var points: PackedVector2Array = []
	for i in range(12):
		var angle := arc_angle + deg_to_rad(i * 20)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	loading_spinner.draw_polyline(points, DRU_COLORS.accent, 3.0, true)

# =============================================================================
# THEME
# =============================================================================

func _apply_dru_theme() -> void:
	# Apply Morris Roman font if available
	var font_path := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
	if ResourceLoader.exists(font_path):
		var font := load(font_path)
		if font:
			for child in get_tree().get_nodes_in_group("dru_title"):
				if child is Label:
					child.add_theme_font_override("font", font)

# =============================================================================
# MODEL MANAGEMENT
# =============================================================================

func _scan_models() -> void:
	model_selector.clear()

	for model_key in TRINITY_MODELS:
		var model_info: Dictionary = TRINITY_MODELS[model_key]
		for dir in MODEL_DIRS:
			var path: String = dir.path_join(str(model_info.file))
			if FileAccess.file_exists(path):
				model_selector.add_item("%s (%s)" % [model_key, model_info.desc])
				model_selector.set_item_metadata(model_selector.item_count - 1, path)
				break

	if model_selector.item_count == 0:
		model_selector.add_item("(Aucun modele trouve)")
		generate_btn.disabled = true
		run_all_btn.disabled = true
	else:
		model_selector.select(0)
		_current_model_path = model_selector.get_item_metadata(0)


## Préchauffement du modèle - charge en mémoire GPU pour réponses rapides
func _warmup_model() -> void:
	if _current_model_path.is_empty():
		return

	_update_status("Prechauffement modele...", DRU_COLORS.warning)

	var llm := _get_or_load_model(_current_model_path)
	if llm == null:
		_update_status("Erreur: modele non charge", DRU_COLORS.error)
		return

	# Court prompt de warmup pour charger le modèle en mémoire
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(0.1, 0.5, 5)  # Très court

	var state := {"done": false}
	llm.generate_async("Bonjour", func(_res):
		state.done = true
	)

	while not state.done:
		llm.poll_result()
		await get_tree().process_frame

	# Restaurer les paramètres normaux
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(LLM_TEMPERATURE, LLM_TOP_P, LLM_MAX_TOKENS)

	_update_status("Pret. Modele prechauffe.", DRU_COLORS.success)

# =============================================================================
# SIGNALS
# =============================================================================

func _connect_signals() -> void:
	generate_btn.pressed.connect(_on_generate_pressed)
	run_all_btn.pressed.connect(_on_run_all_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	model_selector.item_selected.connect(_on_model_selected)

func _on_model_selected(idx: int) -> void:
	if model_selector.get_item_metadata(idx):
		_current_model_path = model_selector.get_item_metadata(idx)
		_update_status("Modele selectionne: " + _current_model_path.get_file())

func _on_generate_pressed() -> void:
	if _is_generating:
		return

	var prompt := prompt_input.text.strip_edges()
	if prompt.is_empty():
		_update_status("Erreur: Prompt vide", DRU_COLORS.error)
		return

	await _generate(prompt, choice_mode_toggle.button_pressed)

func _on_run_all_pressed() -> void:
	if _is_generating:
		return

	_test_results.clear()
	_is_generating = true
	_set_ui_enabled(false)

	for test in TEST_PROMPTS:
		_update_status("Test: %s..." % test.name)
		var result := await _generate_once(test.text, true)
		result["test_name"] = test.name
		_test_results.append(result)
		await get_tree().create_timer(0.5).timeout

	_is_generating = false
	_set_ui_enabled(true)
	_update_status("Tests termines: %d/%d reussis" % [
		_test_results.filter(func(r): return not r.has("error")).size(),
		_test_results.size()
	])
	test_completed.emit({"results": _test_results})

func _on_clear_pressed() -> void:
	response_label.text = ""
	_clear_choices()
	_reset_metrics()
	_update_status("Efface.")

func _on_choice_selected(index: int, text: String) -> void:
	# Use selected choice as next prompt
	prompt_input.text = text
	_conversation_history.append("Joueur: " + text)
	_animate_choice_selection(index)

	# Auto-generate response
	await get_tree().create_timer(0.3).timeout
	await _generate(text, true)

# =============================================================================
# GENERATION
# =============================================================================

func _generate(prompt: String, with_choices: bool) -> void:
	_is_generating = true
	_set_ui_enabled(false)
	_show_loading(true)
	_clear_choices()

	var result := await _generate_once(prompt, with_choices)

	_show_loading(false)
	_is_generating = false
	_set_ui_enabled(true)

	if result.has("error"):
		_update_status("Erreur: " + str(result.error), DRU_COLORS.error)
		return

	# Parse response and choices
	var text: String = result.get("text", "")
	var parsed := _parse_response(text)

	# Animate response
	await _typewrite_response(parsed.response)

	# Show choices if available
	if parsed.choices.size() > 0:
		await get_tree().create_timer(0.3).timeout
		_show_choices(parsed.choices)

	# Update metrics
	_update_metrics_display(result)
	_update_status("Generation terminee en %d ms" % result.get("elapsed_ms", 0))

func _generate_once(prompt: String, with_choices: bool) -> Dictionary:
	if not ClassDB.class_exists("MerlinLLM"):
		return {"error": "MerlinLLM non disponible"}

	if _current_model_path.is_empty() or not FileAccess.file_exists(_current_model_path):
		return {"error": "Modele introuvable"}

	var llm := _get_or_load_model(_current_model_path)
	if llm == null:
		return {"error": "Impossible de charger le modele"}

	var system_prompt := CHOICE_SYSTEM if with_choices else MERLIN_SYSTEM
	var formatted := _format_chatml(system_prompt, prompt)

	# Paramètres optimisés pour vitesse et qualité
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(LLM_TEMPERATURE, LLM_TOP_P, LLM_MAX_TOKENS)

	# Paramètres avancés (repetition_penalty, top_k)
	if llm.has_method("set_advanced_sampling"):
		llm.set_advanced_sampling(LLM_TOP_K, LLM_REPETITION_PENALTY)

	var start_ms := Time.get_ticks_msec()
	var state := {"done": false, "result": {}}

	llm.generate_async(formatted, func(res):
		state.result = res
		state.done = true
	)

	# Polling optimisé: pas besoin de chaque frame
	var poll_count := 0
	while not state.done:
		llm.poll_result()
		poll_count += 1
		# Poll moins agressivement après les premières itérations
		if poll_count < 10:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.05).timeout  # 50ms entre polls

	var elapsed := Time.get_ticks_msec() - start_ms
	var raw_text := _extract_text(state.result)
	var cleaned := _clean_response(raw_text)

	return {
		"text": cleaned,
		"elapsed_ms": elapsed,
		"tokens": cleaned.split(" ").size(),
	}

func _get_or_load_model(path: String) -> Object:
	if _models_cache.has(path):
		return _models_cache[path]

	var llm = ClassDB.instantiate("MerlinLLM")
	var err = llm.load_model(ProjectSettings.globalize_path(path))
	if typeof(err) == TYPE_INT and int(err) != OK:
		return null

	_models_cache[path] = llm
	return llm

func _format_chatml(system: String, user: String) -> String:
	return "<|im_start|>system\n%s<|im_end|>\n<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n" % [system, user]

func _extract_text(result) -> String:
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("text"):
			return str(result.text)
		if result.has("lines") and result.lines.size() > 0:
			return str(result.lines[0])
	return str(result)

func _clean_response(text: String) -> String:
	var cleaned := text.strip_edges()

	# 1. Supprimer TOUS les tokens spéciaux et marqueurs de rôle
	var special_tokens := ["<|im_start|>", "<|im_end|>", "<|eot_id|>", "<|endoftext|>",
		"<|assistant|>", "<|user|>", "<|system|>", "assistant:", "user:", "system:",
		"assistant\n", "user\n", "\nassistant", "\nuser", "Assistant:", "User:"]
	for token in special_tokens:
		cleaned = cleaned.replace(token, "")
	cleaned = cleaned.strip_edges()

	# 2. Supprimer les lignes qui sont des marqueurs de rôle ou fuites de prompt
	var leak_keywords := [
		"druide", "merlin", "parle", "donne", "choix", "joueur",
		"reponds", "phrases", "ecris", "options", "numerotees",
		"format", "court", "francais", "action"
	]
	# Marqueurs de rôle standalone à supprimer
	var role_markers := ["user", "assistant", "system", "utilisateur", "assistant:"]

	var lines := cleaned.split("\n")
	var clean_lines: Array[String] = []

	for line in lines:
		var lower_line: String = line.to_lower().strip_edges()
		var is_leak := false

		# Ligne trop courte ou vide
		if lower_line.length() < 3:
			continue

		# Supprimer les marqueurs de rôle standalone
		if lower_line in role_markers:
			continue

		# Supprimer les lignes qui commencent par un marqueur de rôle
		if lower_line.begins_with("user ") or lower_line.begins_with("assistant "):
			continue
		if lower_line.begins_with("je suis un utilisateur"):
			continue

		# Détection de fuite: si la ligne contient plusieurs mots-clés du prompt
		var keyword_count := 0
		for kw in leak_keywords:
			if lower_line.find(kw) != -1:
				keyword_count += 1
		if keyword_count >= 2:
			is_leak = true

		# Patterns de fuite évidents
		if lower_line.begins_with("format") or lower_line.begins_with("reponse courte"):
			is_leak = true
		if lower_line == "1. action" or lower_line == "2. action":
			is_leak = true

		if not is_leak:
			clean_lines.append(line.strip_edges())

	cleaned = "\n".join(clean_lines).strip_edges()

	# 3. Supprimer les conversations simulées (pattern: phrase + role + phrase)
	# Détecte quand le LLM génère une fausse conversation
	if cleaned.find("?") != -1:
		var parts := cleaned.split("?")
		if parts.size() >= 2:
			# Garder seulement la première partie + ?
			var first_part := parts[0].strip_edges() + "?"
			# Vérifier si ce qui suit ressemble à une conversation simulée
			var rest := parts[1].strip_edges() if parts.size() > 1 else ""
			if rest.to_lower().begins_with("je suis") or rest.to_lower().begins_with("ah") or rest.length() < 5:
				# Conversation simulée détectée, garder juste la première phrase
				cleaned = first_part

	# 4. Supprimer les méta-commentaires du LLM au début
	var meta_starts := ["Je suis Merlin", "En tant que", "Comme", "Moi,", "Bonjour, je suis"]
	for meta in meta_starts:
		if cleaned.begins_with(meta):
			var idx := cleaned.find(".")
			if idx > 0 and idx < 60:
				var after_dot := cleaned.substr(idx + 1).strip_edges()
				if after_dot.length() > 10:
					cleaned = after_dot
				else:
					# Si rien d'intéressant après, reformuler
					cleaned = "Bienvenue dans mon antre, voyageur!"

	# 5. Si la réponse est vide ou trop courte, fallback
	if cleaned.length() < 5:
		cleaned = "Bienvenue, voyageur. Que puis-je faire pour toi?"

	return cleaned.strip_edges()

func _parse_response(text: String) -> Dictionary:
	var result := {"response": "", "choices": []}

	# Chercher la section choix avec plusieurs formats possibles
	var choix_idx := -1
	var choix_markers := ["[CHOIX]", "[CHOICES]", "CHOIX:", "Choix:", "Options:"]
	for marker in choix_markers:
		choix_idx = text.find(marker)
		if choix_idx != -1:
			break

	# Aussi chercher le pattern "1." ou "1)" qui indique le début des choix
	if choix_idx == -1:
		var regex_patterns := ["\\n1\\.", "\\n1\\)"]
		for pattern in regex_patterns:
			var regex := RegEx.new()
			regex.compile(pattern)
			var match_result := regex.search(text)
			if match_result:
				choix_idx = match_result.get_start()
				break

	if choix_idx != -1:
		# Extract response before choices
		var response_part := text.substr(0, choix_idx)
		response_part = response_part.replace("[REPONSE]", "").strip_edges()
		result.response = _clean_repetitions(response_part)

		# Extract choices
		var choices_part := text.substr(choix_idx)
		var lines := choices_part.split("\n")
		var seen_choices: Array[String] = []

		for line in lines:
			var trimmed: String = line.strip_edges()
			var choice_text := ""

			# Match multiple choice patterns: "1. ", "1) ", "1: ", "- ", "* "
			if trimmed.length() > 2:
				# Pattern: "1. " "2. " etc
				if trimmed[0] in "1234" and trimmed[1] == ".":
					choice_text = trimmed.substr(2).strip_edges()
				# Pattern: "1) " "2) " etc
				elif trimmed[0] in "1234" and trimmed[1] == ")":
					choice_text = trimmed.substr(2).strip_edges()
				# Pattern: "1: " "2: " etc
				elif trimmed[0] in "1234" and trimmed[1] == ":":
					choice_text = trimmed.substr(2).strip_edges()
				# Pattern: "- " bullet
				elif trimmed.begins_with("-"):
					choice_text = trimmed.substr(1).strip_edges()
				# Pattern: "* " bullet
				elif trimmed.begins_with("*"):
					choice_text = trimmed.substr(1).strip_edges()

			if choice_text.length() > 0:
				# Clean and validate choice
				choice_text = _clean_choice_text(choice_text)
				# Supprimer les tokens spéciaux qui traînent
				choice_text = choice_text.replace("system", "").replace("<|", "").replace("|>", "")

				# Skip if too short, too long, or duplicate
				if choice_text.length() < 3:
					continue
				if choice_text.length() > MAX_CHOICE_LENGTH:
					choice_text = choice_text.substr(0, MAX_CHOICE_LENGTH - 3) + "..."
				if _is_repetitive(choice_text):
					continue
				if _is_similar_to_existing(choice_text, seen_choices):
					continue

				seen_choices.append(choice_text)
				result.choices.append(choice_text)
	else:
		result.response = _clean_repetitions(text)

	# Limit to 4 choices max
	if result.choices.size() > 4:
		result.choices = result.choices.slice(0, 4)

	# Compléter avec des fallback si moins de 4 choix
	var fallback_choices := [
		"Interroger Merlin sur les Oghams",
		"Demander conseil pour la quete",
		"Explorer les environs",
		"Saluer et partir",
		"Poser une question sur la magie",
		"Demander des nouvelles du monde",
		"S'asseoir et ecouter",
		"Remercier le druide",
	]
	var fallback_idx := 0
	while result.choices.size() < 4 and fallback_idx < fallback_choices.size():
		var fallback: String = fallback_choices[fallback_idx]
		if not _is_similar_to_existing(fallback, result.choices):
			result.choices.append(fallback)
		fallback_idx += 1

	return result


func _clean_choice_text(text: String) -> String:
	# Remove quotes and clean up
	var cleaned := text.strip_edges()
	cleaned = cleaned.trim_prefix("\"").trim_suffix("\"")
	cleaned = cleaned.trim_prefix("'").trim_suffix("'")
	return cleaned


func _clean_repetitions(text: String) -> String:
	# Detect and remove repetitive patterns
	var words := text.split(" ")
	if words.size() < 6:
		return text

	# Check for repeated words
	var word_count: Dictionary = {}
	for word in words:
		var w: String = word.to_lower()
		if w.length() > 3:
			word_count[w] = word_count.get(w, 0) + 1

	# If any word repeats more than 3 times, text is broken
	for word in word_count:
		if word_count[word] > 3:
			# Return only first occurrence
			var idx := text.find(". ")
			if idx > 10:
				return text.substr(0, idx + 1)
			return text.substr(0, min(100, text.length()))

	return text


func _is_repetitive(text: String) -> bool:
	# Check if text contains obvious repetitions
	var words := text.split(" ")
	if words.size() < 4:
		return false

	# Check for consecutive repeated words
	for i in range(words.size() - 2):
		if words[i].to_lower() == words[i + 1].to_lower() and words[i].length() > 2:
			return true

	# Check if same word appears too often
	var word_count: Dictionary = {}
	for word in words:
		var w: String = word.to_lower()
		if w.length() > 3:
			word_count[w] = word_count.get(w, 0) + 1
			if word_count[w] > 2:
				return true

	return false


func _is_similar_to_existing(new_choice: String, existing: Array) -> bool:
	var new_lower := new_choice.to_lower()
	for choice in existing:
		var existing_lower: String = choice.to_lower()
		# Check if starts the same
		if new_lower.begins_with(existing_lower.substr(0, 10)):
			return true
		if existing_lower.begins_with(new_lower.substr(0, 10)):
			return true
	return false

# =============================================================================
# ANIMATIONS
# =============================================================================

func _typewrite_response(text: String) -> void:
	response_label.text = ""
	if text.is_empty():
		return

	# Update Merlin's emotion based on text content
	_update_merlin_emotion(text)

	# Use RobotBlipVoice for robotic voice with typewriter sync
	if robot_voice and robot_voice.has_method("speak_text"):
		# Calculate chars per second based on text length
		var chars_per_sec := TYPEWRITER_SPEED
		# Start speaking - this handles blips asynchronously
		robot_voice.speak_text(text, chars_per_sec)

		# Typewriter effect synced with voice
		var delay := 1.0 / chars_per_sec
		for i in range(text.length()):
			response_label.text = text.substr(0, i + 1)
			await get_tree().create_timer(delay).timeout

		# Stop speaking when done
		if robot_voice.has_method("stop_speaking"):
			robot_voice.stop_speaking()
	# Fallback: Use ACVoicebox if available
	elif voicebox and voicebox.has_method("play_string"):
		voicebox.text_label = response_label
		voicebox.play_string(text)
		# Wait for voice to finish
		if voicebox.has_signal("finished_phrase"):
			await voicebox.finished_phrase
	else:
		# Fallback: standard typewriter without voice
		var delay := 1.0 / TYPEWRITER_SPEED
		for i in range(text.length()):
			response_label.text = text.substr(0, i + 1)
			await get_tree().create_timer(delay).timeout

func _show_choices(choices: Array) -> void:
	_clear_choices()

	var title := output_container.get_node_or_null("ChoicesTitle")
	if title:
		title.visible = true

	for i in range(choices.size()):
		var btn := _create_choice_button(choices[i], i)
		btn.modulate.a = 0.0
		choices_container.add_child(btn)
		choice_buttons.append(btn)

		# Stagger animation
		var tween := create_tween()
		tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)

func _clear_choices() -> void:
	for btn in choice_buttons:
		btn.queue_free()
	choice_buttons.clear()

	var title := output_container.get_node_or_null("ChoicesTitle")
	if title:
		title.visible = false

func _animate_choice_selection(index: int) -> void:
	if index >= choice_buttons.size():
		return

	var btn := choice_buttons[index]
	var tween := create_tween()
	tween.tween_property(btn, "modulate", DRU_COLORS.accent, 0.15)
	tween.tween_property(btn, "modulate:a", 0.0, 0.15)

func _show_loading(visible_state: bool) -> void:
	if visible_state:
		loading_panel.visible = true
		loading_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(loading_panel, "modulate:a", 1.0, 0.2)
	else:
		var tween := create_tween()
		tween.tween_property(loading_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): loading_panel.visible = false)

# =============================================================================
# METRICS
# =============================================================================

func _update_metrics_display(result: Dictionary) -> void:
	var elapsed: int = result.get("elapsed_ms", 0)
	var tokens: int = result.get("tokens", 0)

	# Latency
	latency_bar.value = min(elapsed, latency_bar.max_value)
	latency_label.text = "%d ms" % elapsed

	# Color based on performance
	if elapsed < 2000:
		latency_label.add_theme_color_override("font_color", DRU_COLORS.success)
	elif elapsed < 5000:
		latency_label.add_theme_color_override("font_color", DRU_COLORS.warning)
	else:
		latency_label.add_theme_color_override("font_color", DRU_COLORS.error)

	# Tokens
	tokens_label.text = "%d tokens" % tokens

	# Quality estimation
	var quality := "Bon" if tokens > 20 else "Court"
	quality_label.text = quality

func _reset_metrics() -> void:
	latency_bar.value = 0
	latency_label.text = "-- ms"
	tokens_label.text = "-- tokens"
	quality_label.text = "--"

# =============================================================================
# UI STATE
# =============================================================================

func _set_ui_enabled(enabled: bool) -> void:
	generate_btn.disabled = not enabled
	run_all_btn.disabled = not enabled
	prompt_input.editable = enabled

func _update_status(text: String, color: Color = DRU_COLORS.text_dim) -> void:
	if status_bar == null:
		return
	status_bar.text = text
	status_bar.add_theme_color_override("font_color", color)
