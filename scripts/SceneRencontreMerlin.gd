## ═══════════════════════════════════════════════════════════════════════════════
## SceneRencontreMerlin — Merged Eveil + Antre in one scene
## ═══════════════════════════════════════════════════════════════════════════════
## 7-phase state machine: Eveil dialogue → Bestiole → Oghams → Mission → Biome
## Pixel Merlin portrait assembled from falling cascade. No PNG assets.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/HubAntre.tscn"
const DATA_PATH := "res://data/dialogues/scene_dialogues.json"

const TYPEWRITER_DELAY := 0.030
const TYPEWRITER_PUNCT_DELAY := 0.10
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton
# ═══════════════════════════════════════════════════════════════════════════════

const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"paper_warm": Color(0.955, 0.930, 0.890),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
	"ogham_glow": Color(0.45, 0.62, 0.32),
	"bestiole": Color(0.42, 0.60, 0.72),
}

const CARD_MAX_WIDTH := 720.0
const CARD_MAX_HEIGHT := 800.0

const STARTER_OGHAMS := [
	{"name": "Beith", "symbol": "\u1681", "meaning": "Bouleau — Nouveau depart"},
	{"name": "Luis", "symbol": "\u1682", "meaning": "Sorbier — Protection"},
	{"name": "Quert", "symbol": "\u168A", "meaning": "Pommier — Guerison"},
]

const BIOME_DATA := {
	"foret_broceliande": {"name": "Foret de Broceliande", "color": Color(0.30, 0.50, 0.28)},
	"landes_bruyere": {"name": "Landes de Bruyere", "color": Color(0.55, 0.40, 0.55)},
	"cotes_sauvages": {"name": "Cotes Sauvages", "color": Color(0.35, 0.50, 0.65)},
	"villages_celtes": {"name": "Villages Celtes", "color": Color(0.60, 0.45, 0.30)},
	"cercles_pierres": {"name": "Cercles de Pierres", "color": Color(0.50, 0.50, 0.55)},
	"marais_korrigans": {"name": "Marais des Korrigans", "color": Color(0.30, 0.42, 0.30)},
	"collines_dolmens": {"name": "Collines aux Dolmens", "color": Color(0.48, 0.55, 0.40)},
}

const CLASS_TO_BIOME := {
	"druide": "cercles_pierres",
	"guerrier": "villages_celtes",
	"barde": "cotes_sauvages",
	"eclaireur": "foret_broceliande",
}

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase {
	EVEIL_DIALOGUE,
	BESTIOLE_INTRO,
	MERLIN_COMMENTARY,
	OGHAM_REVEAL,
	MISSION_BRIEFING,
	BIOME_SELECTION,
	TRANSITIONING,
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var parchment_bg: ColorRect
var mist_layer: ColorRect
var celtic_top: Label
var celtic_bottom: Label
var card: PanelContainer
var card_vbox: VBoxContainer
var portrait_container: CenterContainer
var merlin_portrait: Control  # PixelMerlinPortrait (loaded dynamically)
var merlin_text: RichTextLabel
var skip_hint: Label
var audio_player: AudioStreamPlayer
var ogham_panel: PanelContainer
var biome_panel: PanelContainer
var biome_buttons: Dictionary = {}
var response_container: VBoxContainer
var response_buttons: Array[Button] = []

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_phase: Phase = Phase.EVEIL_DIALOGUE
var scene_finished: bool = false
var typing_active: bool = false
var typing_abort: bool = false
var _advance_requested: bool = false
var _mist_tween: Tween
var _entry_tween: Tween
var _biome_pulse_tween: Tween
var card_target_pos := Vector2.ZERO

# Dialogue data
var dialogue_data: Dictionary = {}
var eveil_lines: Array = []
var _response_chosen: int = -1
var _preloaded_responses: Dictionary = {}

# Game state
var player_class: String = "druide"
var suggested_biome: String = "foret_broceliande"
var selected_biome: String = ""
var _biome_layout: bool = false

# Fonts
var title_font: Font
var body_font: Font

# LLM
var _llm_gen: Node = null
var merlin_ai: Node = null
var _prefetched_rephrase: Dictionary = {}  # {line_index: String}
var _prefetched_responses: Dictionary = {}  # {line_index: Array}


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_fonts()
	_load_data()
	_load_game_state()
	_build_ui()
	_setup_audio()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("pensif")

	resized.connect(_on_resized)
	_start_mist_animation()

	if not is_inside_tree():
		return

	# Assemble Merlin from falling pixels
	await merlin_portrait.assemble()
	if not is_inside_tree():
		return

	_play_entry_animation()
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	# Start phase machine
	_run_phase(Phase.EVEIL_DIALOGUE)


# ═══════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _load_fonts() -> void:
	for path in ["res://resources/fonts/morris/MorrisRomanBlack.otf",
				  "res://resources/fonts/morris/MorrisRomanBlack.ttf"]:
		if title_font == null and ResourceLoader.exists(path):
			var f = load(path)
			if f is Font:
				title_font = f
	for path in ["res://resources/fonts/morris/MorrisRomanBlackAlt.otf",
				  "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"]:
		if body_font == null and ResourceLoader.exists(path):
			var f = load(path)
			if f is Font:
				body_font = f
	if body_font == null:
		body_font = title_font


func _load_data() -> void:
	var path: String = DATA_PATH
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	if locale_mgr and locale_mgr.has_method("get_data_path"):
		path = locale_mgr.get_data_path(DATA_PATH)

	if not FileAccess.file_exists(path):
		_set_fallback_data()
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_set_fallback_data()
		return
	file.close()

	var data: Dictionary = json.data
	# Load eveil lines
	eveil_lines = data.get("scene_eveil", {}).get("lines", [])
	if eveil_lines.is_empty():
		_set_fallback_data()
		return

	# Load antre data
	dialogue_data = data.get("scene_antre_merlin", {})


func _set_fallback_data() -> void:
	eveil_lines = [
		{"text": "... Tu es la.", "emotion": "soulagement_profond"},
		{"text": "J'ai attendu. Longtemps.", "emotion": "vulnerabilite_rare"},
		{"text": "La brume t'a laisse passer. C'est bon signe.", "emotion": "transition_vers_humour"},
		{"text": "Bon. Bienvenue a Broceliande.", "emotion": "accueil_jovial"},
	]


func _load_game_state() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		player_class = gm.get("player_class") if gm.get("player_class") is String else "druide"
	suggested_biome = CLASS_TO_BIOME.get(player_class, "foret_broceliande")
	merlin_ai = get_node_or_null("/root/MerlinAI")


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILD
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Parchment background
	parchment_bg = ColorRect.new()
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		parchment_bg.material = mat
	else:
		parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)

	# Mist layer
	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_layer.modulate.a = 0.0
	add_child(mist_layer)

	# Celtic ornaments
	celtic_top = _make_celtic_ornament()
	add_child(celtic_top)
	celtic_bottom = _make_celtic_ornament()
	add_child(celtic_bottom)

	# Central card
	card = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_style()
	add_child(card)

	card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 16)
	card.add_child(card_vbox)

	# Pixel Merlin portrait
	portrait_container = CenterContainer.new()
	card_vbox.add_child(portrait_container)

	var PixelMerlinClass = load("res://scripts/ui/pixel_merlin_portrait.gd")
	merlin_portrait = PixelMerlinClass.new()
	portrait_container.add_child(merlin_portrait)
	merlin_portrait.call("setup", 192.0)

	# Separator
	var sep_container := HBoxContainer.new()
	sep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_container.add_theme_constant_override("separation", 8)
	card_vbox.add_child(sep_container)
	var sep_left := ColorRect.new()
	sep_left.color = PALETTE.line
	sep_left.custom_minimum_size = Vector2(60, 1)
	sep_container.add_child(sep_left)
	var sep_diamond := Label.new()
	sep_diamond.text = "◆"
	sep_diamond.add_theme_color_override("font_color", PALETTE.accent)
	sep_diamond.add_theme_font_size_override("font_size", 10)
	sep_container.add_child(sep_diamond)
	var sep_right := ColorRect.new()
	sep_right.color = PALETTE.line
	sep_right.custom_minimum_size = Vector2(60, 1)
	sep_container.add_child(sep_right)

	# Text area
	merlin_text = RichTextLabel.new()
	merlin_text.name = "MerlinText"
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.custom_minimum_size = Vector2(440, 100)
	merlin_text.visible_characters = 0
	merlin_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		merlin_text.add_theme_font_override("normal_font", body_font)
	merlin_text.add_theme_font_size_override("normal_font_size", 24)
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)
	card_vbox.add_child(merlin_text)

	# Skip hint
	skip_hint = Label.new()
	skip_hint.text = "Appuie pour continuer"
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		skip_hint.add_theme_font_override("font", body_font)
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", PALETTE.ink_faded)
	skip_hint.visible = false
	card_vbox.add_child(skip_hint)

	# Response buttons
	_build_response_ui()
	# Ogham panel
	_build_ogham_panel()
	# Biome panel
	_build_biome_panel()

	_layout_ui()


func _apply_card_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_warm
	style.border_color = PALETTE.ink_faded
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = PALETTE.shadow
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 32
	style.content_margin_top = 28
	style.content_margin_right = 32
	style.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", style)


func _make_celtic_ornament() -> Label:
	var lbl := Label.new()
	var pattern := ["─", "•", "─", "─", "◆", "─", "─", "•", "─"]
	var line := ""
	for i in range(40):
		line += pattern[i % pattern.size()]
	lbl.text = line
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", PALETTE.ink_faded)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	return lbl


func _build_response_ui() -> void:
	response_container = VBoxContainer.new()
	response_container.add_theme_constant_override("separation", 10)
	response_container.visible = false
	response_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(response_container)

	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 44)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "..."
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = PALETTE.paper_warm
		btn_style.border_color = PALETTE.ink_faded
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = 16
		btn_style.content_margin_right = 16
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = PALETTE.paper_dark
		btn_hover.border_color = PALETTE.accent
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_color_override("font_color", PALETTE.ink)
		btn.add_theme_color_override("font_hover_color", PALETTE.accent)
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_response_chosen.bind(i))
		btn.mouse_entered.connect(func(): SFXManager.play("choice_hover"))
		response_container.add_child(btn)
		response_buttons.append(btn)


func _build_ogham_panel() -> void:
	ogham_panel = PanelContainer.new()
	ogham_panel.visible = false
	ogham_panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_dark
	style.border_color = PALETTE.ogham_glow
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	ogham_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	ogham_panel.add_child(hbox)

	for ogham in STARTER_OGHAMS:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		var symbol := Label.new()
		symbol.text = ogham.symbol
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.add_theme_font_size_override("font_size", 32)
		symbol.add_theme_color_override("font_color", PALETTE.ogham_glow)
		vbox.add_child(symbol)
		var name_lbl := Label.new()
		name_lbl.text = ogham.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if title_font:
			name_lbl.add_theme_font_override("font", title_font)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", PALETTE.ink)
		vbox.add_child(name_lbl)
		var meaning := Label.new()
		meaning.text = ogham.meaning
		meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			meaning.add_theme_font_override("font", body_font)
		meaning.add_theme_font_size_override("font_size", 11)
		meaning.add_theme_color_override("font_color", PALETTE.ink_soft)
		vbox.add_child(meaning)
		hbox.add_child(vbox)
	add_child(ogham_panel)


func _build_biome_panel() -> void:
	biome_panel = PanelContainer.new()
	biome_panel.visible = false
	biome_panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_dark
	style.border_color = PALETTE.accent_soft
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	biome_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	biome_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Les Sept Sanctuaires"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = PALETTE.line
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	for key in BIOME_DATA:
		var biome: Dictionary = BIOME_DATA[key]
		var btn := Button.new()
		btn.text = biome.name
		btn.custom_minimum_size = Vector2(280, 34)
		btn.pressed.connect(_on_biome_selected.bind(key))
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		btn.disabled = true

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = PALETTE.paper_warm
		btn_style.border_color = PALETTE.ink_faded
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(3)
		btn_style.content_margin_left = 10
		btn_style.content_margin_right = 10
		btn.add_theme_stylebox_override("normal", btn_style)
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = PALETTE.paper_dark
		btn_hover.border_color = biome.color
		btn_hover.set_border_width_all(2)
		btn.add_theme_stylebox_override("hover", btn_hover)
		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", PALETTE.ink)
		vbox.add_child(btn)
		biome_buttons[key] = btn
	add_child(biome_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# LAYOUT
# ═══════════════════════════════════════════════════════════════════════════════

func _layout_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var card_w := minf(CARD_MAX_WIDTH, vp.x * 0.85)
	var card_h: float
	if _biome_layout:
		card_h = minf(CARD_MAX_HEIGHT * 0.45, vp.y * 0.35)
	else:
		card_h = minf(CARD_MAX_HEIGHT, vp.y * 0.78)
	card.size = Vector2(card_w, card_h)
	card.position = Vector2((vp.x - card_w) * 0.5, (vp.y - card_h) * 0.5)
	if _biome_layout:
		card.position.y = vp.y * 0.05
	card.pivot_offset = card.size * 0.5
	card_target_pos = card.position

	if celtic_top:
		celtic_top.size = Vector2(vp.x, 30)
		celtic_top.position = Vector2(0, card.position.y - 35)
	if celtic_bottom:
		celtic_bottom.size = Vector2(vp.x, 30)
		celtic_bottom.position = Vector2(0, card.position.y + card_h + 5)

	# Position ogham below card
	if ogham_panel:
		var ow := minf(500, vp.x * 0.85)
		ogham_panel.size.x = ow
		ogham_panel.position = Vector2((vp.x - ow) * 0.5, card.position.y + card_h + 20)

	# Position biome panel below card
	if biome_panel and _biome_layout:
		var bw := minf(350, vp.x * 0.8)
		biome_panel.size.x = bw
		biome_panel.position = Vector2((vp.x - bw) * 0.5, card.position.y + card_h + 16)


func _on_resized() -> void:
	call_deferred("_layout_ui")


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _play_entry_animation() -> void:
	if not card:
		return
	SFXManager.play("scene_transition")
	var target_y: float = card_target_pos.y
	card.modulate.a = 0.0
	card.position.y = target_y + 40
	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = create_tween()
	_entry_tween.tween_property(celtic_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(celtic_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.tween_property(card, "position:y", target_y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase(phase: Phase) -> void:
	if scene_finished or not is_inside_tree():
		return
	current_phase = phase

	match phase:
		Phase.EVEIL_DIALOGUE:
			await _phase_eveil()
		Phase.BESTIOLE_INTRO:
			await _phase_bestiole_intro()
		Phase.MERLIN_COMMENTARY:
			await _phase_merlin_commentary()
		Phase.OGHAM_REVEAL:
			await _phase_ogham_reveal()
		Phase.MISSION_BRIEFING:
			await _phase_mission_briefing()
		Phase.BIOME_SELECTION:
			await _phase_biome_selection()
		Phase.TRANSITIONING:
			await _transition_out()


## Phase 1: Eveil — 4 dialogue lines, interactive responses after 1 and 3
func _phase_eveil() -> void:
	# Wait for LLM readiness (max 3s) to avoid fallback-only dialogue
	if merlin_ai and not merlin_ai.is_ready:
		var wait_elapsed: float = 0.0
		while merlin_ai and not merlin_ai.is_ready and wait_elapsed < 3.0:
			await get_tree().create_timer(0.5).timeout
			wait_elapsed += 0.5
			if not is_inside_tree():
				return

	# Prefetch first line rephrase
	_prefetch_rephrase(eveil_lines, 0)

	for i in range(eveil_lines.size()):
		if scene_finished or not is_inside_tree():
			return

		var line: Dictionary = eveil_lines[i]
		var emotion: String = line.get("emotion", "pensif")

		# Set mood
		_set_mood(emotion)

		# Get LLM-rephrased text (or original as fallback)
		var text: String = await _get_rephrased_line(eveil_lines, i)

		# Prefetch next line in background while displaying current
		if i + 1 < eveil_lines.size():
			_prefetch_rephrase(eveil_lines, i + 1)

		# Typewriter
		await _show_text(text)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout

		# Interactive? Show LLM-generated response buttons
		if i == 1 or i == 3:
			await _show_response_blocks(i, text)
		else:
			skip_hint.visible = true
			SFXManager.play("click")
			_advance_requested = false
			await _wait_for_advance(30.0)
			skip_hint.visible = false

		if not is_inside_tree():
			return

		# Fade between lines
		if i < eveil_lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	# Save eveil flag
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("set"):
		gm.set("eveil_seen", true)

	_run_phase(Phase.BESTIOLE_INTRO)


## Phase 2: Bestiole intro narration (LLM-rephrased)
func _phase_bestiole_intro() -> void:
	var lines: Array = dialogue_data.get("bestiole_apparition", {}).get("lines", [])
	if lines.is_empty():
		lines = [
			{"text": "Quelque chose bouge dans la brume..."},
			{"text": "Un eclat de lumiere, timide."},
			{"text": "Ta Bestiole est la. Elle t'attendait."},
		]

	_prefetched_rephrase.clear()
	_prefetch_rephrase(lines, 0)

	for i in range(lines.size()):
		if not is_inside_tree():
			return
		var text: String = await _get_rephrased_line(lines, i)
		if i + 1 < lines.size():
			_prefetch_rephrase(lines, i + 1)

		await _show_text(text)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		skip_hint.visible = true
		_advance_requested = false
		await _wait_for_advance(20.0)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	_run_phase(Phase.MERLIN_COMMENTARY)


## Phase 3: Merlin comments on Bestiole (LLM-first with JSON fallback)
func _phase_merlin_commentary() -> void:
	_set_mood("amuse")

	# Try LLM-generated commentary first
	var llm_text := await _try_llm_commentary()
	if llm_text != "":
		await _show_text(llm_text)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		skip_hint.visible = true
		_advance_requested = false
		await _wait_for_advance(20.0)
		skip_hint.visible = false
		_run_phase(Phase.OGHAM_REVEAL)
		return

	# Fallback: static JSON dialogue
	var lines: Array = dialogue_data.get("merlin_sur_bestiole", {}).get("lines", [])
	if lines.is_empty():
		lines = [
			{"text": "Ah, elle est mignonne celle-la."},
			{"text": "Prends-en soin. Elle sera ton ancre."},
		]

	for i in range(lines.size()):
		if not is_inside_tree():
			return
		var text: String = lines[i].get("text", "") if lines[i] is Dictionary else str(lines[i])
		await _show_text(text)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		skip_hint.visible = true
		_advance_requested = false
		await _wait_for_advance(20.0)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	_run_phase(Phase.OGHAM_REVEAL)


func _try_llm_commentary() -> String:
	## Attempt LLM-generated Merlin commentary with timeout. Returns "" on failure.
	if merlin_ai == null or not merlin_ai.is_ready:
		return ""

	var gm := get_node_or_null("/root/GameManager")
	var archetype: String = ""
	if gm:
		archetype = str(gm.get("archetype_title")) if gm.get("archetype_title") is String else ""

	var system_prompt := "Tu es Merlin le druide. Un voyageur vient d'arriver dans ton antre avec sa Bestiole. Commente la scene en 1-2 phrases, ton amuse et bienveillant. Reponds en francais uniquement."
	var user_input := "Le voyageur est un %s. Sa Bestiole vient d'apparaitre." % [archetype if archetype != "" else "druide"]

	# Race with timeout
	var _done := false
	var _result := {}
	var _do := func():
		_result = await merlin_ai.generate_narrative(system_prompt, user_input, {"max_tokens": 80})
		_done = true
	_do.call()

	var elapsed := 0.0
	while not _done and elapsed < 10.0:
		if not is_inside_tree():
			return ""
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25

	if not _done or _result.has("error"):
		return ""

	var text: String = str(_result.get("text", ""))
	if text.length() < 5:
		return ""

	return text


## LLM rephrase — rewrite scripted text with same meaning but LLM voice
func _llm_rephrase(scripted_text: String, emotion: String = "", _context: String = "") -> String:
	if merlin_ai == null or not merlin_ai.is_ready:
		return scripted_text

	var system := "Tu es Merlin le druide. Reformule cette phrase en gardant exactement le meme sens et la meme intention."
	if emotion != "":
		system += " Emotion: %s." % emotion
	system += " 1-2 phrases maximum. Francais uniquement. Ne dis rien d'autre que la reformulation."
	var user_input := scripted_text

	var _done := false
	var _result := {}
	var _do := func():
		_result = await merlin_ai.generate_voice(system, user_input, {"max_tokens": 80, "temperature": 0.7})
		_done = true
	_do.call()

	var elapsed := 0.0
	while not _done and elapsed < 5.0:
		if not is_inside_tree():
			return scripted_text
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2

	if not _done or _result.has("error"):
		return scripted_text

	var text: String = str(_result.get("text", "")).strip_edges()
	# Guardrails: minimum length, no empty
	if text.length() < 10:
		return scripted_text
	return text


## LLM generate 3 player responses to a Merlin line
func _llm_generate_responses(context_line: String, line_index: int) -> Array[String]:
	if merlin_ai == null or not merlin_ai.is_ready:
		return _get_fallback_responses(line_index)

	var system := "Tu es l'assistant d'un jeu narratif. Merlin vient de dire une phrase au joueur. Genere exactement 3 reponses courtes que le joueur pourrait donner. Reponds UNIQUEMENT avec un JSON array de 3 strings en francais. Exemple: [\"Reponse 1\", \"Reponse 2\", \"Reponse 3\"]"
	var user_input := "Merlin dit: \"%s\"" % context_line

	var _done := false
	var _result := {}
	var _do := func():
		_result = await merlin_ai.generate_narrative(system, user_input, {"max_tokens": 100, "temperature": 0.6})
		_done = true
	_do.call()

	var elapsed := 0.0
	while not _done and elapsed < 8.0:
		if not is_inside_tree():
			return _get_fallback_responses(line_index)
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2

	if not _done or _result.has("error"):
		return _get_fallback_responses(line_index)

	var raw_text: String = str(_result.get("text", ""))
	# Parse JSON array
	var json := JSON.new()
	if json.parse(raw_text) == OK and json.data is Array:
		var arr: Array = json.data
		if arr.size() >= 3:
			var out: Array[String] = []
			for i in range(3):
				out.append(str(arr[i]).strip_edges())
			return out

	# Try extracting JSON from mixed output (LLM may wrap in text)
	var bracket_start := raw_text.find("[")
	var bracket_end := raw_text.rfind("]")
	if bracket_start >= 0 and bracket_end > bracket_start:
		var json_slice := raw_text.substr(bracket_start, bracket_end - bracket_start + 1)
		if json.parse(json_slice) == OK and json.data is Array:
			var arr: Array = json.data
			if arr.size() >= 3:
				var out: Array[String] = []
				for i in range(3):
					out.append(str(arr[i]).strip_edges())
				return out

	return _get_fallback_responses(line_index)


## Prefetch rephrase for next line (non-blocking, stores result for later)
func _prefetch_rephrase(lines: Array, next_idx: int) -> void:
	if next_idx >= lines.size():
		return
	if _prefetched_rephrase.has(next_idx):
		return
	var line: Dictionary = lines[next_idx] if lines[next_idx] is Dictionary else {"text": str(lines[next_idx])}
	var text: String = line.get("text", "")
	var emotion: String = line.get("emotion", "")
	# Fire and forget — result stored in dict
	var rephrased := await _llm_rephrase(text, emotion)
	_prefetched_rephrase[next_idx] = rephrased


## Get rephrased text (use prefetch if available, else rephrase now)
func _get_rephrased_line(lines: Array, idx: int) -> String:
	if _prefetched_rephrase.has(idx):
		var result: String = _prefetched_rephrase[idx]
		_prefetched_rephrase.erase(idx)
		return result
	var line: Dictionary = lines[idx] if lines[idx] is Dictionary else {"text": str(lines[idx])}
	return await _llm_rephrase(line.get("text", ""), line.get("emotion", ""))


## Phase 4: Ogham reveal with panel
func _phase_ogham_reveal() -> void:
	_set_mood("sage")
	var line_data: Dictionary = dialogue_data.get("ogham_reveal", {}).get("line", {})
	var text: String = line_data.get("text", "Trois Oghams pour commencer ton chemin.")

	await _show_text(text)
	if not is_inside_tree():
		return

	# Show ogham panel with animation
	SFXManager.play("flash_boom")
	ogham_panel.visible = true
	_layout_ui()
	var tw := create_tween()
	tw.tween_property(ogham_panel, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tw.finished

	# Store oghams
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var bestiole_data: Dictionary = gm.get("bestiole") if gm.get("bestiole") is Dictionary else {}
		if not bestiole_data.has("known_oghams"):
			bestiole_data["known_oghams"] = ["beith", "luis", "quert"]
			bestiole_data["equipped_oghams"] = ["beith", "luis", "quert", ""]
			gm.set("bestiole", bestiole_data)

	if not is_inside_tree():
		return
	await get_tree().create_timer(1.0).timeout
	skip_hint.visible = true
	_advance_requested = false
	await _wait_for_advance(30.0)
	skip_hint.visible = false

	# Hide ogham panel
	var hide := create_tween()
	hide.tween_property(ogham_panel, "modulate:a", 0.0, 0.4)
	await hide.finished
	ogham_panel.visible = false

	_run_phase(Phase.MISSION_BRIEFING)


## Phase 5: Mission briefing (LLM-rephrased)
func _phase_mission_briefing() -> void:
	_set_mood("serieux")
	var lines: Array = dialogue_data.get("mission_briefing", {}).get("lines", [])
	if lines.is_empty():
		lines = [
			{"text": "Ecoute bien. Le monde est fragile."},
			{"text": "Corps, Ame, Monde — trois aspects a equilibrer."},
			{"text": "Chaque choix pese. Chaque carte compte."},
			{"text": "Mais tu n'es pas seul. Je serai la."},
		]

	_prefetched_rephrase.clear()
	_prefetch_rephrase(lines, 0)

	for i in range(lines.size()):
		if not is_inside_tree():
			return
		var text: String = await _get_rephrased_line(lines, i)
		if i + 1 < lines.size():
			_prefetch_rephrase(lines, i + 1)

		await _show_text(text)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.3).timeout
		skip_hint.visible = true
		_advance_requested = false
		await _wait_for_advance(20.0)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	_run_phase(Phase.BIOME_SELECTION)


## Phase 6: Biome selection
func _phase_biome_selection() -> void:
	_set_mood("warm")

	# Switch to compact layout
	portrait_container.visible = false
	_biome_layout = true
	_layout_ui()

	var text := "Par ou veux-tu commencer ton voyage?"
	await _show_text(text)
	if not is_inside_tree():
		return

	# Show biome panel
	biome_panel.visible = true
	_layout_ui()
	var tw := create_tween()
	tw.tween_property(biome_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished

	# Enable buttons
	for key in biome_buttons:
		biome_buttons[key].disabled = false

	# Pulse suggested biome
	if biome_buttons.has(suggested_biome):
		var sbtn: Button = biome_buttons[suggested_biome]
		if _biome_pulse_tween:
			_biome_pulse_tween.kill()
		_biome_pulse_tween = create_tween().set_loops()
		_biome_pulse_tween.tween_property(sbtn, "modulate", Color(1.15, 1.10, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
		_biome_pulse_tween.tween_property(sbtn, "modulate", Color.WHITE, 1.0).set_trans(Tween.TRANS_SINE)

	skip_hint.text = "Choisis un sanctuaire"
	skip_hint.visible = true

	# Wait for biome selection
	while selected_biome.is_empty() and not scene_finished:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	skip_hint.visible = false
	if _biome_pulse_tween:
		_biome_pulse_tween.kill()

	# Save biome
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("set"):
		gm.set("selected_biome", selected_biome)

	if not is_inside_tree():
		return
	await get_tree().create_timer(0.5).timeout
	_run_phase(Phase.TRANSITIONING)


func _on_biome_selected(key: String) -> void:
	SFXManager.play("choice_select")
	selected_biome = key
	# Visual feedback
	for k in biome_buttons:
		if k == key:
			biome_buttons[k].add_theme_color_override("font_color", PALETTE.accent)
		else:
			biome_buttons[k].modulate.a = 0.4


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func _show_text(text: String) -> void:
	text = text.replace("[long_pause]", "").replace("[pause]", "").replace("[beat]", "").strip_edges()
	typing_active = true
	typing_abort = false
	merlin_text.text = text
	merlin_text.visible_characters = 0

	for i in range(text.length()):
		if typing_abort or not is_inside_tree():
			break
		merlin_text.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		if not is_inside_tree():
			break
		await get_tree().create_timer(delay).timeout

	merlin_text.visible_characters = -1
	typing_active = false


func _skip_typewriter() -> void:
	if typing_active:
		typing_abort = true
		merlin_text.visible_characters = -1


# ═══════════════════════════════════════════════════════════════════════════════
# RESPONSE BLOCKS
# ═══════════════════════════════════════════════════════════════════════════════

func _show_response_blocks(line_index: int, context_line: String = "") -> void:
	_response_chosen = -1
	var vp := get_viewport().get_visible_rect().size
	var rc_width := minf(450.0, vp.x * 0.8)
	response_container.position = Vector2((vp.x - rc_width) * 0.5, card.position.y + card.size.y + 16)
	response_container.size.x = rc_width

	# Try LLM-generated responses, fallback to static
	var responses: Array[String] = await _llm_generate_responses(context_line, line_index)
	for i in range(response_buttons.size()):
		if i < responses.size():
			response_buttons[i].text = responses[i]
			response_buttons[i].visible = true
			response_buttons[i].modulate.a = 0.0
		else:
			response_buttons[i].visible = false

	# Position from bottom of viewport to ensure all 3 buttons are visible
	var visible_count := mini(responses.size(), 3)
	var total_h := visible_count * 44.0 + (visible_count - 1) * 10.0
	response_container.position = Vector2((vp.x - rc_width) * 0.5, vp.y - total_h - 32.0)
	response_container.size.x = rc_width

	response_container.visible = true
	for i in range(visible_count):
		var tw := create_tween()
		tw.tween_property(response_buttons[i], "modulate:a", 1.0, 0.3).set_delay(i * 0.15)

	while _response_chosen < 0 and not scene_finished:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	if _response_chosen >= 0 and is_inside_tree():
		await get_tree().create_timer(0.4).timeout

	var hide_tw := create_tween()
	hide_tw.tween_property(response_container, "modulate:a", 0.0, 0.3)
	await hide_tw.finished
	response_container.visible = false
	response_container.modulate.a = 1.0
	for btn in response_buttons:
		btn.modulate.a = 1.0


func _on_response_chosen(index: int) -> void:
	SFXManager.play("choice_select")
	_response_chosen = index
	for i in range(response_buttons.size()):
		if i == index:
			response_buttons[i].add_theme_color_override("font_color", PALETTE.accent)
		else:
			response_buttons[i].modulate.a = 0.4


func _get_fallback_responses(line_index: int) -> Array[String]:
	if line_index == 1:
		return [
			"Je suis la. Que dois-je faire ?",
			"Longtemps ? Tu comptais les siecles ?",
			"La brume m'a guide jusqu'ici.",
		]
	return [
		"Je suis pret. Montre-moi ce monde.",
		"Meme dans la brume, je te fais confiance.",
		"Le bout du monde ne me fait pas peur.",
	]


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT & WAIT
# ═══════════════════════════════════════════════════════════════════════════════

func _wait_for_advance(max_wait: float) -> void:
	var elapsed := 0.0
	while elapsed < max_wait and not _advance_requested and not scene_finished:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


func _unhandled_input(event: InputEvent) -> void:
	if scene_finished:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true

	if pressed:
		if typing_active:
			_skip_typewriter()
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# MOOD & TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func _set_mood(emotion: String) -> void:
	var mood := "sage"
	if "humour" in emotion or "jovial" in emotion or "amuse" in emotion:
		mood = "amuse"
	elif "vulnerabilite" in emotion or "soulagement" in emotion or "pensif" in emotion:
		mood = "pensif"
	elif "accueil" in emotion or "warm" in emotion:
		mood = "warm"
	elif "serieux" in emotion or "gravite" in emotion or "sage" in emotion:
		mood = "serieux"
	merlin_portrait.set_mood(mood)
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood(mood)


func _transition_out() -> void:
	SFXManager.play("scene_transition")
	scene_finished = true
	_set_mood("warm")

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(celtic_top, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(mist_layer, "modulate:a", 0.6, 0.8)
	if biome_panel and biome_panel.visible:
		tween.parallel().tween_property(biome_panel, "modulate:a", 0.0, 0.4)
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		if is_inside_tree():
			get_tree().change_scene_to_file(NEXT_SCENE)
	)
	await tween.finished


# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


func _play_blip() -> void:
	var sample_rate := 44100.0
	var duration := 0.014
	var num_samples := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var freq := randf_range(260.0, 360.0)
	for s in range(num_samples):
		var t := float(s) / sample_rate
		var envelope := exp(-t * 320.0)
		var click := sin(TAU * freq * t) * 0.35
		var noise := randf_range(-1.0, 1.0) * 0.12
		var value := (click + noise) * envelope * 0.25
		var sample_val := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[s * 2] = sample_val & 0xFF
		data[s * 2 + 1] = (sample_val >> 8) & 0xFF
	stream.data = data
	audio_player.stream = stream
	audio_player.play()
