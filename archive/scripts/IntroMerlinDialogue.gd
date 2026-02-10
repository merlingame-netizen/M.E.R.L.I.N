extends Control

signal intro_completed(result: Dictionary)

const DATA_PATH := "res://data/intro_dialogue.json"
const NEXT_SCENE := "res://scenes/SceneRencontreMerlin.tscn"
const MENU_SCENE := "res://scenes/MenuPrincipal.tscn"
const PORTRAIT_DEFAULT := "res://Assets/Sprite/Merlin.png"
const PORTRAIT_PRINTEMPS := "res://Assets/Sprite/Merlin_PRINTEMPS.png"
const PORTRAIT_ETE := "res://Assets/Sprite/Merlin_ETE.png"
const PORTRAIT_AUTOMNE := "res://Assets/Sprite/Merlin_AUTOMNE.png"
const PORTRAIT_HIVER := "res://Assets/Sprite/Merlin_HIVER.png"

const VERBS := ["FORCE", "LOGIQUE", "FINESSE"]
const CLASSES := ["druide", "guerrier", "barde", "eclaireur"]
const CARD_SIZE := Vector2(640, 760)

const TYPEWRITER_DELAY := 0.025
const TYPEWRITER_PUNCT_DELAY := 0.08
const NAME_MAX_LEN := 16
const TOTAL_QUESTIONS := 15

const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

const CLASS_NAMES := {
	"druide": "Druide",
	"guerrier": "Guerrier",
	"barde": "Barde",
	"eclaireur": "Eclaireur"
}

const CLASS_DESCRIPTIONS := {
	"druide": "Tu parles aux pierres et aux arbres. La lande te connait.",
	"guerrier": "Tu frappes d'abord, la brume s'ecarte devant toi.",
	"barde": "Les mots sont tes armes, les histoires ton bouclier.",
	"eclaireur": "Tu lis les traces, tu vois ce que d'autres ignorent."
}

const HOOK_MEMORY := {
	"hates_vague": "Le Voyageur refuse le flou.",
	"wants_control": "Le Voyageur veut tenir la brume.",
	"seeks_explanations": "Le Voyageur cherche un sens.",
	"tests_intentions": "Le Voyageur pese les intentions.",
	"avoids_conflict": "Le Voyageur evite le choc.",
	"seeks_shortcuts": "Le Voyageur cherche un passage court.",
	"acts_fast": "Le Voyageur agit sans tarder.",
	"prefers_preparation": "Le Voyageur prepare le pas.",
	"keeps_secrets": "Le Voyageur garde ses ombres.",
	"protects_weak": "Le Voyageur protege les faibles.",
	"confronts_threats": "Le Voyageur chasse les menaces.",
	"tracks_patterns": "Le Voyageur suit les traces.",
	"needs_structure": "Le Voyageur cherche un repere.",
	"avoids_noise": "Le Voyageur parle bas.",
	"guides_subtly": "Le Voyageur guide d un signe.",
	"plants_seed": "Le Voyageur plante ce qu'il trouve.",
	"destroys_growth": "Le Voyageur ecrase sans hesiter.",
	"studies_nature": "Le Voyageur etudie la nature.",
	"collects_samples": "Le Voyageur collecte pour plus tard.",
	"trusts_nature": "Le Voyageur fait confiance au vent.",
	"sings_to_life": "Le Voyageur chante pour la vie.",
	"chooses_dark": "Le Voyageur choisit l'ombre.",
	"marks_path": "Le Voyageur marque son chemin.",
	"seeks_clues": "Le Voyageur cherche des indices.",
	"reads_wind": "Le Voyageur lit le vent.",
	"follows_shadow": "Le Voyageur suit l'ombre douce.",
	"moves_silent": "Le Voyageur avance sans bruit.",
	"refuses_oath": "Le Voyageur refuse le serment.",
	"demands_proof": "Le Voyageur demande une preuve.",
	"asks_questions": "Le Voyageur pose des questions.",
	"offers_trade": "Le Voyageur propose un echange.",
	"buys_time": "Le Voyageur gagne du temps.",
	"observes_calm": "Le Voyageur observe sans bruit.",
	"pushes_through": "Le Voyageur passe malgre le vent.",
	"seeks_shelter": "Le Voyageur cherche un abri.",
	"reads_sky": "Le Voyageur lit le ciel.",
	"waits_calm": "Le Voyageur attend l'accalmie.",
	"slips_trees": "Le Voyageur glisse sous les arbres.",
	"hides_tracks": "Le Voyageur couvre ses traces.",
	"smothers_fire": "Le Voyageur etouffe la flamme.",
	"feeds_flame": "Le Voyageur nourrit le feu.",
	"reads_camp": "Le Voyageur lit les traces du camp.",
	"studies_fire": "Le Voyageur etudie le feu.",
	"enjoys_warmth": "Le Voyageur profite de la chaleur.",
	"weaves_story": "Le Voyageur tisse une histoire.",
	"jumps_gap": "Le Voyageur saute le vide.",
	"reinforces_bridge": "Le Voyageur renforce le pont.",
	"finds_detour": "Le Voyageur trouve un detour.",
	"tests_bank": "Le Voyageur teste la rive.",
	"steps_stones": "Le Voyageur marche sur les pierres.",
	"uses_rope": "Le Voyageur tend une corde.",
	"answers_loud": "Le Voyageur repond fort.",
	"silences_wood": "Le Voyageur fait taire le bois.",
	"listens_pattern": "Le Voyageur ecoute le rythme.",
	"seeks_source": "Le Voyageur cherche la source.",
	"approaches_soft": "Le Voyageur s'approche doucement.",
	"whispers_back": "Le Voyageur murmure en retour.",
	"takes_gift": "Le Voyageur prend le present.",
	"chases_crow": "Le Voyageur chasse le corbeau.",
	"asks_origin": "Le Voyageur demande l'origine.",
	"trades_thread": "Le Voyageur echange un fil.",
	"returns_gift": "Le Voyageur rend le present.",
	"follows_bird": "Le Voyageur suit l'oiseau.",
	"breaks_wood": "Le Voyageur brise le bois.",
	"climbs_over": "Le Voyageur grimpe par-dessus.",
	"studies_roots": "Le Voyageur etudie les racines.",
	"finds_gap": "Le Voyageur trouve une breche.",
	"honors_dead": "Le Voyageur honore les morts.",
	"writes_verse": "Le Voyageur compose un vers.",
	"turns_back": "Le Voyageur se retourne.",
	"faces_shadow": "Le Voyageur affronte l'ombre.",
	"counts_steps": "Le Voyageur compte les pas.",
	"sets_trap": "Le Voyageur tend un piege.",
	"changes_pace": "Le Voyageur change d'allure.",
	"vanishes_rocks": "Le Voyageur disparait entre les rocs.",
	"pulls_book": "Le Voyageur arrache le livre.",
	"leaves_book": "Le Voyageur laisse le livre.",
	"opens_carefully": "Le Voyageur ouvre avec soin.",
	"reads_page": "Le Voyageur lit une page.",
	"dries_book": "Le Voyageur seche le livre.",
	"hides_book": "Le Voyageur cache le livre.",
	"clears_thorns": "Le Voyageur ecarte les epines.",
	"cuts_thorns": "Le Voyageur coupe les epines.",
	"seeks_origin": "Le Voyageur cherche l'origine.",
	"finds_weak": "Le Voyageur trouve un angle faible.",
	"slips_thorns": "Le Voyageur passe entre les pointes.",
	"asks_passage": "Le Voyageur demande un passage."
}

enum InputMode { NONE, CHOICES, NAME, CLASS_REVEAL }

@onready var card_root: Control = $CardRoot
@onready var card_panel: Panel = $CardRoot/CardPanel
@onready var portrait: TextureRect = $CardRoot/CardPanel/CardMargin/CardVBox/PortraitFrame/Portrait
@onready var merlin_text: RichTextLabel = $CardRoot/CardPanel/CardMargin/CardVBox/MerlinText
@onready var progress_label: Label = $CardRoot/ProgressLabel

@onready var choices_bar: Control = $ChoicesBar
@onready var verb_buttons := {
	"FORCE": $ChoicesBar/VerbRow/ForceButton,
	"LOGIQUE": $ChoicesBar/VerbRow/LogiqueButton,
	"FINESSE": $ChoicesBar/VerbRow/FinesseButton
}
@onready var sub_panel: Panel = $ChoicesBar/SubChoicePanel
@onready var sub_buttons: Array[Button] = [
	$ChoicesBar/SubChoicePanel/SubChoiceVBox/SubChoice1,
	$ChoicesBar/SubChoicePanel/SubChoiceVBox/SubChoice2
]

@onready var name_overlay: Control = $NameOverlay
@onready var name_edit: LineEdit = $NameOverlay/NamePanel/NameVBox/NameEdit
@onready var name_error: Label = $NameOverlay/NamePanel/NameVBox/NameError
@onready var name_confirm: Button = $NameOverlay/NamePanel/NameVBox/NameButtons/ConfirmButton

@onready var sfx_card_in: AudioStreamPlayer = $Audio/SfxCardIn
@onready var sfx_card_out: AudioStreamPlayer = $Audio/SfxCardOut
@onready var sfx_select: AudioStreamPlayer = $Audio/SfxSelect
@onready var sfx_ink: AudioStreamPlayer = $Audio/SfxInk

var node_map: Dictionary = {}
var node_order: Array[String] = []
var current_node_id := ""
var current_node: Dictionary = {}
var current_choices: Dictionary = {}
var current_verb := "FORCE"
var current_sub_index := 0
var input_mode := InputMode.NONE
var typing_active := false
var typing_abort := false
var card_home_pos := Vector2.ZERO
var card_base_scale := Vector2.ONE

var game_manager: Node = null
var run_state: Dictionary = {}
var traveler_profile: Dictionary = {}
var chronicle_name := ""
var current_season := ""

var voicebox: Node = null
var voice_ready := false
var blip_player: AudioStreamPlayer = null
var blip_playback: AudioStreamGeneratorPlayback = null
var blip_phase := 0.0
var blip_mix_rate := 44100

var class_overlay: Control = null
var class_label: Label = null
var class_desc_label: Label = null
var class_continue_button: Button = null

# Emotion detection for portrait effects
enum Emotion { SAGE, MYSTIQUE, SERIEUX, AMUSE, PENSIF }
var current_emotion: Emotion = Emotion.SAGE

const EMOTION_KEYWORDS := {
	Emotion.MYSTIQUE: ["magie", "ogham", "pouvoir", "secret", "ancien", "rune", "mystere", "esprit", "vision", "arcane", "elements", "lumiere"],
	Emotion.SERIEUX: ["danger", "ombre", "prudent", "attention", "mort", "tenebres", "mal", "menace", "garde", "peril", "sombre", "piege"],
	Emotion.AMUSE: ["bien", "bravo", "courage", "sourire", "petit", "jeune", "drole", "amusant", "ha", "excellent", "voyageur", "bienvenue"],
	Emotion.PENSIF: ["destin", "temps", "memoire", "jadis", "autrefois", "souvenir", "passe", "tristesse", "melancolie", "songeur", "loin"]
}

const EMOTION_MODULATES := {
	Emotion.SAGE: Color(1.0, 1.0, 1.0, 1.0),
	Emotion.MYSTIQUE: Color(0.85, 0.75, 1.0, 1.0),
	Emotion.SERIEUX: Color(1.0, 0.8, 0.8, 1.0),
	Emotion.AMUSE: Color(1.0, 1.0, 0.9, 1.0),
	Emotion.PENSIF: Color(0.85, 0.9, 1.0, 1.0)
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	choices_bar.visible = false
	sub_panel.visible = false
	name_overlay.visible = false
	progress_label.visible = false
	_apply_theme()
	_bind_ui()
	_setup_audio()
	_setup_class_overlay()
	_load_dialogue()
	_ensure_run_state()
	if portrait and portrait.texture == null and ResourceLoader.exists(PORTRAIT_DEFAULT):
		portrait.texture = load(PORTRAIT_DEFAULT)
	_update_card_layout()
	get_viewport().size_changed.connect(_on_viewport_resize)
	call_deferred("_start_dialogue")


func _on_viewport_resize() -> void:
	_update_card_layout()
	_update_subchoice_panel()


func _setup_class_overlay() -> void:
	class_overlay = Control.new()
	class_overlay.name = "ClassOverlay"
	class_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	class_overlay.visible = false
	add_child(class_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.965, 0.945, 0.905, 0.85)
	class_overlay.add_child(dim)

	var panel := Panel.new()
	panel.name = "ClassPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -200
	panel.offset_bottom = 200
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.955, 0.930, 0.890)
	panel_style.border_color = Color(0.50, 0.44, 0.38, 0.35)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color(0.25, 0.20, 0.16, 0.18)
	panel_style.shadow_size = 20
	panel_style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", panel_style)
	class_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_right = -24
	vbox.offset_top = 24
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Ta voie se revele"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.58, 0.44, 0.26))
	vbox.add_child(title)

	class_label = Label.new()
	class_label.name = "ClassLabel"
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 36)
	class_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))
	vbox.add_child(class_label)

	class_desc_label = Label.new()
	class_desc_label.name = "ClassDescLabel"
	class_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_desc_label.add_theme_font_size_override("font_size", 18)
	class_desc_label.add_theme_color_override("font_color", Color(0.38, 0.32, 0.26))
	vbox.add_child(class_desc_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	class_continue_button = Button.new()
	class_continue_button.name = "ContinueButton"
	class_continue_button.text = "Commencer l'aventure"
	class_continue_button.custom_minimum_size = Vector2(0, 50)
	class_continue_button.pressed.connect(_on_class_continue)
	vbox.add_child(class_continue_button)

	var cls_body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if cls_body_font == null:
		cls_body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	var cls_title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	if cls_title_font == null:
		cls_title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if cls_title_font:
		title.add_theme_font_override("font", cls_title_font)
		class_label.add_theme_font_override("font", cls_title_font)
	if cls_body_font:
		class_desc_label.add_theme_font_override("font", cls_body_font)
		class_continue_button.add_theme_font_override("font", cls_body_font)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.965, 0.945, 0.905)
	btn_normal.border_color = Color(0.50, 0.44, 0.38, 0.35)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(3)
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.935, 0.905, 0.855)
	btn_hover.border_color = Color(0.58, 0.44, 0.26)
	class_continue_button.add_theme_stylebox_override("normal", btn_normal)
	class_continue_button.add_theme_stylebox_override("hover", btn_hover)
	class_continue_button.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))


func _apply_theme() -> void:
	# — Parchemin Mystique Breton Palette —
	var paper := Color(0.965, 0.945, 0.905)
	var paper_warm := Color(0.955, 0.930, 0.890)
	var paper_dark := Color(0.935, 0.905, 0.855)
	var ink := Color(0.22, 0.18, 0.14)
	var ink_soft := Color(0.38, 0.32, 0.26)
	var ink_faded := Color(0.50, 0.44, 0.38, 0.35)
	var accent := Color(0.58, 0.44, 0.26)
	var accent_soft := Color(0.65, 0.52, 0.34)
	var shadow := Color(0.25, 0.20, 0.16, 0.18)

	var body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _load_font("res://resources/fonts/celtic_bit/celtic-bit-thin.ttf")
	var title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	if title_font == null:
		title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = paper_warm
	card_style.border_color = ink_faded
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.shadow_color = shadow
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 4)
	card_panel.add_theme_stylebox_override("panel", card_style)

	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = paper_dark
	portrait_style.border_color = ink_faded
	portrait_style.set_border_width_all(1)
	portrait_style.set_corner_radius_all(4)
	$CardRoot/CardPanel/CardMargin/CardVBox/PortraitFrame.add_theme_stylebox_override("panel", portrait_style)

	var sub_style := StyleBoxFlat.new()
	sub_style.bg_color = paper_dark
	sub_style.border_color = accent_soft
	sub_style.set_border_width_all(1)
	sub_style.set_corner_radius_all(6)
	sub_style.content_margin_left = 8
	sub_style.content_margin_right = 8
	sub_style.content_margin_top = 6
	sub_style.content_margin_bottom = 6
	sub_panel.add_theme_stylebox_override("panel", sub_style)

	var name_style := StyleBoxFlat.new()
	name_style.bg_color = paper_warm
	name_style.border_color = ink_faded
	name_style.set_border_width_all(1)
	name_style.set_corner_radius_all(6)
	name_style.shadow_color = shadow
	name_style.shadow_size = 12
	$NameOverlay/NamePanel.add_theme_stylebox_override("panel", name_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = paper
	btn_normal.border_color = ink_faded
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(3)
	btn_normal.content_margin_left = 10
	btn_normal.content_margin_right = 10

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = paper_dark
	btn_hover.border_color = accent

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = accent_soft.lightened(0.6)
	btn_pressed.border_color = accent

	for verb in VERBS:
		var btn: Button = verb_buttons[verb]
		_style_button(btn, btn_normal, btn_hover, btn_pressed, body_font)
		btn.toggle_mode = true

	for btn in sub_buttons:
		_style_button(btn, btn_normal, btn_hover, btn_pressed, body_font)
		btn.toggle_mode = true

	_style_button(name_confirm, btn_normal, btn_hover, btn_pressed, body_font)

	if merlin_text:
		if body_font:
			merlin_text.add_theme_font_override("font", body_font)
		merlin_text.add_theme_font_size_override("font_size", 22)
		merlin_text.add_theme_color_override("font_color", ink)

	if progress_label:
		if title_font:
			progress_label.add_theme_font_override("font", title_font)
		progress_label.add_theme_font_size_override("font_size", 16)
		progress_label.add_theme_color_override("font_color", accent)

	var title_label: Label = $NameOverlay/NamePanel/NameVBox/TitleLabel
	var hint_label: Label = $NameOverlay/NamePanel/NameVBox/HintLabel
	var error_label: Label = $NameOverlay/NamePanel/NameVBox/NameError
	if title_label:
		if title_font:
			title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", 20)
		title_label.add_theme_color_override("font_color", accent)
	if hint_label:
		if body_font:
			hint_label.add_theme_font_override("font", body_font)
		hint_label.add_theme_font_size_override("font_size", 12)
		hint_label.add_theme_color_override("font_color", ink_soft)
	if error_label:
		if body_font:
			error_label.add_theme_font_override("font", body_font)
		error_label.add_theme_font_size_override("font_size", 12)
		error_label.add_theme_color_override("font_color", Color(0.72, 0.38, 0.30))

	if name_edit:
		if body_font:
			name_edit.add_theme_font_override("font", body_font)
		name_edit.add_theme_font_size_override("font_size", 16)
		name_edit.add_theme_color_override("font_color", ink)


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return ThemeDB.fallback_font


func _style_button(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, font: Font) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))
	btn.add_theme_color_override("font_hover_color", Color(0.58, 0.44, 0.26))
	btn.add_theme_color_override("font_pressed_color", Color(0.58, 0.44, 0.26))
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 16)


func _bind_ui() -> void:
	for verb in VERBS:
		var btn: Button = verb_buttons[verb]
		btn.pressed.connect(_on_verb_pressed.bind(verb))
		btn.mouse_entered.connect(_on_verb_hover.bind(verb))
	for i in range(sub_buttons.size()):
		sub_buttons[i].pressed.connect(_on_subchoice_pressed.bind(i))
	name_confirm.pressed.connect(_on_name_confirm)
	name_edit.text_submitted.connect(_on_name_submitted)


func _setup_audio() -> void:
	var blip_stream := AudioStreamGenerator.new()
	blip_stream.mix_rate = blip_mix_rate
	blip_stream.buffer_length = 0.2
	blip_player = AudioStreamPlayer.new()
	blip_player.stream = blip_stream
	blip_player.volume_db = -12.0
	$Audio.add_child(blip_player)
	blip_player.play()
	blip_playback = blip_player.get_stream_playback()

	if ResourceLoader.exists("res://addons/acvoicebox/acvoicebox.tscn"):
		voicebox = preload("res://addons/acvoicebox/acvoicebox.tscn").instantiate()
		$Audio.add_child(voicebox)
		if voicebox.has_method("apply_preset"):
			voicebox.apply_preset("Merlin")
		# Override with robotic + soft voice
		voicebox.set("base_pitch", 2.5)
		voicebox.set("pitch_variation", 0.06)
		voicebox.set("speed_scale", 0.70)
		if voicebox.has_signal("voice_ready"):
			voicebox.voice_ready.connect(_on_voice_ready)
		if voicebox.has_method("is_ready"):
			voice_ready = voicebox.is_ready()


func _on_voice_ready(is_ready: bool) -> void:
	voice_ready = is_ready


func _play_blip() -> void:
	if blip_playback == null:
		return
	var frames := int(BLIP_DURATION * float(blip_mix_rate))
	if blip_playback.get_frames_available() < frames:
		return
	for i in range(frames):
		var sample := sin(blip_phase) * BLIP_VOLUME
		blip_phase += TAU * BLIP_FREQ / float(blip_mix_rate)
		blip_playback.push_frame(Vector2(sample, sample))


func _load_dialogue() -> void:
	node_map.clear()
	node_order.clear()
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var path: String = DATA_PATH
	if locale_mgr:
		path = locale_mgr.get_data_path(DATA_PATH)
	if not FileAccess.file_exists(path):
		push_warning("IntroMerlinDialogue: data file missing")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_ARRAY:
		return
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("id"):
			continue
		var id = str(entry.id)
		node_map[id] = entry
		node_order.append(id)


func _ensure_run_state() -> void:
	game_manager = get_node_or_null("/root/GameManager")
	if game_manager and "run" in game_manager:
		run_state = game_manager.run
	else:
		run_state = {}
	if not run_state.has("chronicle_name"):
		run_state["chronicle_name"] = ""
	if not run_state.has("traveler_profile") or typeof(run_state["traveler_profile"]) != TYPE_DICTIONARY:
		run_state["traveler_profile"] = _default_profile()
	if not run_state.has("merlin_memory"):
		run_state["merlin_memory"] = []
	traveler_profile = run_state["traveler_profile"]
	chronicle_name = str(run_state.get("chronicle_name", ""))


func _default_profile() -> Dictionary:
	return {
		"verb_affinity": {"FORCE": 0, "LOGIQUE": 0, "FINESSE": 0},
		"traits": {
			"courage": 0,
			"curiosite": 0,
			"compassion": 0,
			"orgueil": 0,
			"verite": 0,
			"controle": 0
		},
		"class_scores": {
			"druide": 0,
			"guerrier": 0,
			"barde": 0,
			"eclaireur": 0
		},
		"hooks": [],
		"answers": []
	}


func _update_card_layout() -> void:
	card_root.size = CARD_SIZE
	card_root.pivot_offset = card_root.size * 0.5
	card_root.position = Vector2(-CARD_SIZE.x * 0.5, -CARD_SIZE.y * 0.5)
	var viewport_size := get_viewport_rect().size
	var scale_x := (viewport_size.x * 0.9) / card_root.size.x
	var scale_y := (viewport_size.y * 0.8) / card_root.size.y
	var s := minf(1.0, minf(scale_x, scale_y))
	card_root.scale = Vector2(s, s)
	card_base_scale = card_root.scale
	card_home_pos = card_root.position


func _start_dialogue() -> void:
	if node_map.is_empty():
		return
	var start_id := "welcome"
	if not node_map.has(start_id) and node_order.size() > 0:
		start_id = node_order[0]
	await _enter_node(start_id)


func _enter_node(node_id: String) -> void:
	if not node_map.has(node_id):
		_end_demo()
		return
	current_node_id = node_id
	current_node = node_map[node_id]
	_update_progress_for_node(node_id)
	current_choices = {}
	input_mode = InputMode.NONE
	choices_bar.visible = false
	sub_panel.visible = false

	_update_portrait_for_node(current_node)

	await _animate_card_in()
	var line := _ascii_only(str(current_node.get("merlin", "")))
	if line != "":
		await _show_merlin_text(line)

	if current_node.has("ui"):
		var ui_type = str(current_node.ui)
		if ui_type == "name_input":
			_open_name_input()
			return
		elif ui_type == "show_class":
			_show_class_reveal()
			return

	if current_node.has("choices"):
		current_choices = current_node.choices
		_show_choices()
		return

	var next_id := str(current_node.get("next", ""))
	if next_id != "":
		await get_tree().create_timer(0.3).timeout
		await _enter_node(next_id)
		return

	_end_demo()


func _update_portrait_for_node(node: Dictionary) -> void:
	if not portrait:
		return

	var portrait_path := PORTRAIT_DEFAULT

	if node.has("portrait"):
		portrait_path = str(node.portrait)
	elif node.has("season"):
		var season = str(node.season).to_upper()
		match season:
			"PRINTEMPS":
				portrait_path = PORTRAIT_PRINTEMPS
			"ETE":
				portrait_path = PORTRAIT_ETE
			"AUTOMNE":
				portrait_path = PORTRAIT_AUTOMNE
			"HIVER":
				portrait_path = PORTRAIT_HIVER
		current_season = season

	if ResourceLoader.exists(portrait_path):
		var new_tex = load(portrait_path)
		if new_tex:
			var tween := create_tween()
			tween.tween_property(portrait, "modulate:a", 0.0, 0.15)
			await tween.finished
			portrait.texture = new_tex
			var tween2 := create_tween()
			tween2.tween_property(portrait, "modulate:a", 1.0, 0.15)


func _detect_emotion_from_text(text: String) -> Emotion:
	var text_lower := text.to_lower()
	var best_emotion: Emotion = Emotion.SAGE
	var best_score := 0

	for emotion in EMOTION_KEYWORDS:
		var score := 0
		var keywords: Array = EMOTION_KEYWORDS[emotion]
		for keyword in keywords:
			if keyword in text_lower:
				score += 1
		if score > best_score:
			best_score = score
			best_emotion = emotion

	return best_emotion


func _apply_portrait_emotion(emotion: Emotion) -> void:
	if portrait == null:
		return
	if emotion == current_emotion:
		return

	current_emotion = emotion
	var target_color: Color = EMOTION_MODULATES.get(emotion, EMOTION_MODULATES[Emotion.SAGE])

	var tween := create_tween()
	tween.tween_property(portrait, "modulate", target_color, 0.25)

	# Sync screen distortion to Merlin's emotional state
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		var mood_map := {
			Emotion.SAGE: "sage",
			Emotion.MYSTIQUE: "mystique",
			Emotion.SERIEUX: "serieux",
			Emotion.AMUSE: "amuse",
			Emotion.PENSIF: "pensif",
		}
		screen_fx.set_merlin_mood(mood_map.get(emotion, "sage"))

	# Visual effect based on emotion
	match emotion:
		Emotion.MYSTIQUE:
			# Subtle pulse for mystical
			var pulse := create_tween()
			pulse.tween_property(portrait, "scale", Vector2(1.02, 1.02), 0.2)
			pulse.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.2)
		Emotion.SERIEUX:
			# Slight shake for serious
			var orig_pos := portrait.position
			var shake := create_tween()
			shake.tween_property(portrait, "position", orig_pos + Vector2(3, 0), 0.05)
			shake.tween_property(portrait, "position", orig_pos - Vector2(3, 0), 0.05)
			shake.tween_property(portrait, "position", orig_pos, 0.05)
		Emotion.AMUSE:
			# Bounce for amusement
			var bounce := create_tween()
			bounce.tween_property(portrait, "scale", Vector2(1.03, 0.97), 0.1)
			bounce.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.1)


func _show_merlin_text(text: String) -> void:
	typing_active = true
	typing_abort = false

	# Detect and apply emotion based on text content
	var detected_emotion := _detect_emotion_from_text(text)
	_apply_portrait_emotion(detected_emotion)

	if voice_ready and voicebox:
		if voicebox.has_method("stop_speaking"):
			voicebox.stop_speaking()
		voicebox.text_label = merlin_text
		voicebox.play_string(text)
		await voicebox.finished_phrase
		typing_active = false
		return

	merlin_text.text = text
	merlin_text.visible_characters = 0
	for i in range(text.length()):
		if typing_abort:
			break
		var next_char := i + 1
		merlin_text.visible_characters = next_char
		var delay := TYPEWRITER_DELAY
		var ch := text[i]
		if ch != " ":
			_play_blip()
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		await get_tree().create_timer(delay).timeout
	merlin_text.visible_characters = -1
	typing_active = false


func _update_progress_for_node(node_id: String) -> void:
	if progress_label == null:
		return
	if not progress_label.visible:
		return
	if node_id.begins_with("q"):
		var tail := node_id.substr(1)
		if tail.is_valid_int():
			var idx := int(tail)
			progress_label.text = "%d/%d" % [idx, TOTAL_QUESTIONS]
			return


func _show_choices() -> void:
	choices_bar.visible = true
	input_mode = InputMode.CHOICES
	current_verb = _pick_default_verb()
	current_sub_index = 0
	_update_verb_buttons()
	_update_subchoice_panel()


func _pick_default_verb() -> String:
	for verb in VERBS:
		if _choices_for_verb(verb).size() > 0:
			return verb
	return "FORCE"


func _choices_for_verb(verb: String) -> Array:
	if not current_choices.has(verb):
		return []
	var arr = current_choices[verb]
	if typeof(arr) != TYPE_ARRAY:
		return []
	return arr


func _update_verb_buttons() -> void:
	for verb in VERBS:
		var btn: Button = verb_buttons[verb]
		btn.button_pressed = verb == current_verb


func _update_subchoice_panel() -> void:
	if input_mode != InputMode.CHOICES:
		sub_panel.visible = false
		return
	var choices := _choices_for_verb(current_verb)
	if choices.is_empty():
		sub_panel.visible = false
		return
	sub_panel.visible = true
	if sub_panel.size == Vector2.ZERO:
		sub_panel.size = sub_panel.custom_minimum_size
	current_sub_index = clampi(current_sub_index, 0, choices.size() - 1)
	for i in range(sub_buttons.size()):
		if i < choices.size():
			var entry = choices[i]
			sub_buttons[i].visible = true
			sub_buttons[i].text = str(entry.get("text", "..."))
			sub_buttons[i].button_pressed = i == current_sub_index
		else:
			sub_buttons[i].visible = false
	_position_sub_panel()


func _position_sub_panel() -> void:
	if not sub_panel.visible:
		return
	var btn: Button = verb_buttons[current_verb]
	var btn_center := btn.get_global_rect().get_center()
	var panel_size := sub_panel.size
	var pos := btn_center - Vector2(panel_size.x * 0.5, panel_size.y + 18)
	var viewport_size := get_viewport_rect().size
	pos.x = clampf(pos.x, 16.0, viewport_size.x - panel_size.x - 16.0)
	pos.y = clampf(pos.y, 16.0, viewport_size.y - panel_size.y - 16.0)
	sub_panel.global_position = pos


func _on_verb_pressed(verb: String) -> void:
	if input_mode != InputMode.CHOICES:
		return
	_set_current_verb(verb)


func _on_verb_hover(verb: String) -> void:
	if input_mode != InputMode.CHOICES:
		return
	_set_current_verb(verb)


func _set_current_verb(verb: String) -> void:
	if verb == current_verb:
		return
	current_verb = verb
	current_sub_index = 0
	_update_verb_buttons()
	_update_subchoice_panel()


func _on_subchoice_pressed(index: int) -> void:
	if input_mode != InputMode.CHOICES:
		return
	current_sub_index = index
	_confirm_subchoice()


func _confirm_subchoice() -> void:
	if input_mode != InputMode.CHOICES:
		return
	var choices := _choices_for_verb(current_verb)
	if choices.is_empty():
		return
	current_sub_index = clampi(current_sub_index, 0, choices.size() - 1)
	var choice: Dictionary = choices[current_sub_index]
	_apply_choice(current_verb, choice)


func _apply_choice(verb: String, choice: Dictionary) -> void:
	input_mode = InputMode.NONE
	choices_bar.visible = false
	sub_panel.visible = false
	_apply_deltas(choice.get("deltas", {}))
	_append_answer(choice, verb)
	_append_memory_line(choice)
	var next_id := str(choice.get("next", ""))
	await _animate_card_out(verb)
	if next_id == "":
		_end_demo()
		return
	await _enter_node(next_id)


func _apply_deltas(deltas: Dictionary) -> void:
	if not traveler_profile.has("traits"):
		traveler_profile["traits"] = {}
	if not traveler_profile.has("verb_affinity"):
		traveler_profile["verb_affinity"] = {}
	if not traveler_profile.has("class_scores"):
		traveler_profile["class_scores"] = {"druide": 0, "guerrier": 0, "barde": 0, "eclaireur": 0}

	if deltas.has("traits"):
		for key in deltas.traits:
			traveler_profile.traits[key] = int(traveler_profile.traits.get(key, 0)) + int(deltas.traits[key])
	if deltas.has("verbs"):
		for key in deltas.verbs:
			traveler_profile.verb_affinity[key] = int(traveler_profile.verb_affinity.get(key, 0)) + int(deltas.verbs[key])
	if deltas.has("classes"):
		for key in deltas.classes:
			traveler_profile.class_scores[key] = int(traveler_profile.class_scores.get(key, 0)) + int(deltas.classes[key])

	run_state["traveler_profile"] = traveler_profile


func _append_answer(choice: Dictionary, verb: String) -> void:
	var answers: Array = traveler_profile.get("answers", [])
	var entry := {
		"id": current_node_id,
		"choice_id": str(choice.get("id", "")),
		"verb": verb,
		"tags": choice.get("hooks", []),
		"deltas": choice.get("deltas", {})
	}
	answers.append(entry)
	traveler_profile["answers"] = answers
	var hooks: Array = traveler_profile.get("hooks", [])
	for h in choice.get("hooks", []):
		if not hooks.has(h):
			hooks.append(h)
	traveler_profile["hooks"] = hooks
	run_state["traveler_profile"] = traveler_profile


func _append_memory_line(choice: Dictionary) -> void:
	var line := _build_memory_line(choice)
	if line == "":
		return
	var memory: Array = run_state.get("merlin_memory", [])
	memory.append(line)
	if memory.size() > 8:
		memory = memory.slice(memory.size() - 8, memory.size())
	run_state["merlin_memory"] = memory


func _build_memory_line(choice: Dictionary) -> String:
	var hooks: Array = choice.get("hooks", [])
	for h in hooks:
		if HOOK_MEMORY.has(h):
			return HOOK_MEMORY[h]
	return "La brume note un pas du Voyageur."


func _open_name_input() -> void:
	input_mode = InputMode.NAME
	name_overlay.visible = true
	name_error.text = ""
	name_edit.text = chronicle_name
	name_edit.max_length = NAME_MAX_LEN
	name_edit.grab_focus()


func _on_name_submitted(_text: String) -> void:
	_on_name_confirm()


func _on_name_confirm() -> void:
	if input_mode != InputMode.NAME:
		return
	var cleaned := _sanitize_name(name_edit.text)
	if cleaned == "":
		name_error.text = "Nom trop court."
		return
	chronicle_name = cleaned
	run_state["chronicle_name"] = chronicle_name
	name_overlay.visible = false
	input_mode = InputMode.NONE
	progress_label.visible = true
	progress_label.text = "1/%d" % TOTAL_QUESTIONS
	var next_id := str(current_node.get("next", ""))
	if next_id != "":
		await _enter_node(next_id)


func _sanitize_name(raw: String) -> String:
	var trimmed := raw.strip_edges()
	var out := ""
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_'"
	for i in range(trimmed.length()):
		var ch := trimmed[i]
		if ch in allowed:
			out += ch
	out = out.strip_edges()
	while out.find("  ") != -1:
		out = out.replace("  ", " ")
	if out.length() > NAME_MAX_LEN:
		out = out.substr(0, NAME_MAX_LEN)
	return out


func _show_class_reveal() -> void:
	input_mode = InputMode.CLASS_REVEAL
	choices_bar.visible = false
	sub_panel.visible = false
	card_root.visible = false

	var determined_class := _determine_class()
	traveler_profile["class"] = determined_class
	run_state["traveler_profile"] = traveler_profile

	class_label.text = CLASS_NAMES.get(determined_class, "Inconnu")
	class_desc_label.text = CLASS_DESCRIPTIONS.get(determined_class, "")

	class_overlay.visible = true
	class_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(class_overlay, "modulate:a", 1.0, 0.4)

	class_continue_button.grab_focus()


func _determine_class() -> String:
	var class_scores: Dictionary = traveler_profile.get("class_scores", {})
	var best_class := "eclaireur"
	var best_score := -1

	for cls in CLASSES:
		var score: int = class_scores.get(cls, 0)
		if score > best_score:
			best_score = score
			best_class = cls

	if best_score <= 0:
		var verb_affinity: Dictionary = traveler_profile.get("verb_affinity", {})
		var traits: Dictionary = traveler_profile.get("traits", {})

		var force_score: int = verb_affinity.get("FORCE", 0)
		var logique_score: int = verb_affinity.get("LOGIQUE", 0)
		var finesse_score: int = verb_affinity.get("FINESSE", 0)

		var compassion: int = traits.get("compassion", 0)
		var courage: int = traits.get("courage", 0)
		var curiosite: int = traits.get("curiosite", 0)

		if force_score >= logique_score and force_score >= finesse_score:
			if compassion > courage:
				best_class = "druide"
			else:
				best_class = "guerrier"
		elif logique_score >= finesse_score:
			best_class = "eclaireur"
		else:
			if compassion > curiosite:
				best_class = "barde"
			else:
				best_class = "eclaireur"

	return best_class


func _on_class_continue() -> void:
	_end_demo()


func _animate_card_in() -> void:
	card_root.visible = true
	card_root.modulate = Color(1, 1, 1, 0)
	card_root.rotation = deg_to_rad(-2.0)
	card_root.position = card_home_pos + Vector2(0, 60)
	card_root.scale = card_base_scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_root, "position", card_home_pos, 0.35)
	tween.parallel().tween_property(card_root, "rotation", 0.0, 0.35)
	tween.parallel().tween_property(card_root, "modulate:a", 1.0, 0.25)
	await tween.finished


func _animate_card_out(verb: String) -> void:
	var tween := create_tween()
	match verb:
		"FORCE":
			tween.tween_property(card_root, "position", card_home_pos + Vector2(6, -18), 0.05)
			tween.tween_property(card_root, "position", card_home_pos + Vector2(-6, -22), 0.05)
			tween.parallel().tween_property(card_root, "scale", card_base_scale * 1.03, 0.1)
			tween.tween_property(card_root, "position", card_home_pos + Vector2(0, -150), 0.22)
			tween.parallel().tween_property(card_root, "rotation", deg_to_rad(-5.0), 0.2)
			tween.parallel().tween_property(card_root, "modulate:a", 0.0, 0.2)
		"LOGIQUE":
			tween.tween_property(card_root, "scale", Vector2(card_base_scale.x * 0.05, card_base_scale.y), 0.18)
			tween.parallel().tween_property(card_root, "modulate:a", 0.0, 0.2)
			tween.parallel().tween_property(card_root, "position", card_home_pos + Vector2(0, 40), 0.2)
		"FINESSE":
			tween.tween_property(card_root, "position", card_home_pos + Vector2(220, 0), 0.26)
			tween.parallel().tween_property(card_root, "modulate:a", 0.0, 0.22)
		_:
			tween.tween_property(card_root, "modulate:a", 0.0, 0.2)
	await tween.finished


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if typing_active:
			_skip_typewriter()
			return
	if event is InputEventKey and event.pressed:
		if typing_active:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_skip_typewriter()
				return
		if input_mode == InputMode.NAME:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_on_name_confirm()
			elif event.keycode == KEY_ESCAPE:
				_on_name_confirm()
			return
		if input_mode == InputMode.CLASS_REVEAL:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_on_class_continue()
			return
		if input_mode == InputMode.CHOICES:
			match event.keycode:
				KEY_LEFT:
					_move_verb(-1)
				KEY_RIGHT:
					_move_verb(1)
				KEY_UP:
					_move_sub(-1)
				KEY_DOWN:
					_move_sub(1)
				KEY_ENTER, KEY_KP_ENTER:
					_confirm_subchoice()
				KEY_ESCAPE:
					sub_panel.visible = false


func _move_verb(delta: int) -> void:
	var available: Array[String] = []
	for verb in VERBS:
		if _choices_for_verb(verb).size() > 0:
			available.append(verb)
	if available.is_empty():
		return
	var idx := available.find(current_verb)
	if idx == -1:
		idx = 0
	idx = wrapi(idx + delta, 0, available.size())
	_set_current_verb(available[idx])


func _move_sub(delta: int) -> void:
	var choices := _choices_for_verb(current_verb)
	if choices.is_empty():
		return
	if not sub_panel.visible:
		sub_panel.visible = true
	var count := choices.size()
	current_sub_index = wrapi(current_sub_index + delta, 0, count)
	_update_subchoice_panel()


func _skip_typewriter() -> void:
	if not typing_active:
		return
	typing_abort = true
	if voice_ready and voicebox and voicebox.has_method("skip_to_end"):
		voicebox.skip_to_end()
	else:
		merlin_text.visible_characters = -1


func _end_demo() -> void:
	input_mode = InputMode.NONE
	choices_bar.visible = false
	sub_panel.visible = false
	class_overlay.visible = false
	intro_completed.emit({
		"chronicle_name": chronicle_name,
		"traveler_profile": traveler_profile,
		"merlin_memory": run_state.get("merlin_memory", [])
	})

	# Save profile to GameManager before transitioning
	if game_manager:
		game_manager.set("run", run_state)

	# Fade out and go to game
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


func _ascii_only(text: String) -> String:
	var out := ""
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code >= 32 and code <= 126:
			out += text[i]
	return out
