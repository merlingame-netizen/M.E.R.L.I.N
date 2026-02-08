## ═══════════════════════════════════════════════════════════════════════════════
## Scene Antre Merlin — Merlin's Lair (Parchemin Mystique Breton)
## ═══════════════════════════════════════════════════════════════════════════════
## Meet Bestiole → Oghams unlock → Mission briefing → Biome selection
## Style: Parchment card, Celtic ornaments, Merlin portrait, typewriter
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const NEXT_SCENE := "res://scenes/HubAntre.tscn"
const DATA_PATH := "res://data/dialogues/scene_dialogues.json"

const TYPEWRITER_DELAY := 0.030
const TYPEWRITER_PUNCT_DELAY := 0.10
const BLIP_FREQ := 880.0
const BLIP_DURATION := 0.018
const BLIP_VOLUME := 0.04

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton (shared with MenuPrincipal & SceneEveil)
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
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
	"ogham_glow": Color(0.45, 0.62, 0.32),
	"bestiole": Color(0.42, 0.60, 0.72),
}

const CARD_MAX_WIDTH := 720.0
const CARD_MAX_HEIGHT := 800.0
const PORTRAIT_SIZE := Vector2(280, 340)

const PORTRAIT_DEFAULT := "res://Assets/Sprite/Merlin.png"
const PORTRAIT_PRINTEMPS := "res://Assets/Sprite/Merlin_PRINTEMPS.png"
const PORTRAIT_ETE := "res://Assets/Sprite/Merlin_ETE.png"
const PORTRAIT_AUTOMNE := "res://Assets/Sprite/Merlin_AUTOMNE.png"
const PORTRAIT_HIVER := "res://Assets/Sprite/Merlin_HIVER.png"

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const CLASS_TO_BIOME := {
	"druide": "cercles_pierres",
	"guerrier": "villages_celtes",
	"barde": "cotes_sauvages",
	"eclaireur": "foret_broceliande",
}

const BIOME_DATA := {
	"foret_broceliande": {"name": "Foret de Broceliande", "color": Color(0.30, 0.50, 0.28)},
	"landes_bruyere": {"name": "Landes de Bruyere", "color": Color(0.55, 0.40, 0.55)},
	"cotes_sauvages": {"name": "Cotes Sauvages", "color": Color(0.35, 0.50, 0.65)},
	"villages_celtes": {"name": "Villages Celtes", "color": Color(0.60, 0.45, 0.30)},
	"cercles_pierres": {"name": "Cercles de Pierres", "color": Color(0.50, 0.50, 0.55)},
	"marais_korrigans": {"name": "Marais des Korrigans", "color": Color(0.30, 0.42, 0.30)},
	"collines_dolmens": {"name": "Collines aux Dolmens", "color": Color(0.48, 0.55, 0.40)},
}

const STARTER_OGHAMS := [
	{"name": "Beith", "symbol": "\u1681", "meaning": "Bouleau — Nouveau depart"},
	{"name": "Luis", "symbol": "\u1682", "meaning": "Sorbier — Protection"},
	{"name": "Quert", "symbol": "\u168A", "meaning": "Pommier — Guerison"},
]

# ═══════════════════════════════════════════════════════════════════════════════
# NODES
# ═══════════════════════════════════════════════════════════════════════════════

var parchment_bg: ColorRect
var mist_layer: ColorRect
var celtic_top: Label
var celtic_bottom: Label
var card: PanelContainer
var card_vbox: VBoxContainer
var portrait_rect: TextureRect
var merlin_text: RichTextLabel
var skip_hint: Label
var ogham_panel: PanelContainer
var biome_panel: PanelContainer
var biome_buttons: Dictionary = {}
var bestiole_label: Label
var audio_player: AudioStreamPlayer
var portrait_container: CenterContainer
var seasonal_overlay: ColorRect
var _biome_layout := false

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase { BESTIOLE_INTRO, MERLIN_ON_BESTIOLE, OGHAM_REVEAL, MISSION_BRIEFING, BIOME_SELECTION, TRANSITIONING }

var current_phase: int = Phase.BESTIOLE_INTRO
var typing_active: bool = false
var typing_abort: bool = false
var scene_finished: bool = false
var _advance_requested: bool = false
var _mist_tween: Tween
var _biome_pulse_tween: Tween

var dialogue_data: Dictionary = {}
var selected_biome: String = ""
var suggested_biome: String = ""
var player_class: String = "eclaireur"
var chronicle_name: String = "Voyageur"

# Fonts
var title_font: Font
var body_font: Font

# Voicebox
var voicebox: Node = null
var voice_ready: bool = false

# LLM dialogue generator
var _llm_gen: LLMDialogueGenerator = null
var _llm_lang: String = "fr"


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_load_data()
	_load_player_data()
	_init_llm_generator()
	_build_ui()
	_setup_audio()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	resized.connect(_on_resized)
	_start_mist_animation()
	_play_entry_animation.call_deferred()

	await _setup_voicebox()

	await get_tree().create_timer(1.5).timeout
	_run_phase_bestiole()


func _load_fonts() -> void:
	title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _load_data() -> void:
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	var path: String = DATA_PATH
	if locale_mgr:
		path = locale_mgr.get_data_path(DATA_PATH)

	if not FileAccess.file_exists(path):
		push_warning("[SceneAntreMerlin] Data file not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[SceneAntreMerlin] JSON parse error: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	dialogue_data = data.get("scene_antre_merlin", {})


func _init_llm_generator() -> void:
	var gen_script = load("res://scripts/llm_dialogue_generator.gd")
	if gen_script == null:
		return
	_llm_gen = gen_script.new()
	_llm_gen.setup(get_tree())
	var locale_mgr = get_node_or_null("/root/LocaleManager")
	if locale_mgr:
		_llm_lang = locale_mgr.get_language()


func _llm_rephrase(text: String, emotion: String = "neutre") -> String:
	if _llm_gen == null or not _llm_gen.is_llm_available():
		return text
	# Use a unique index based on text hash to avoid collisions
	var idx: int = text.hash() & 0x7FFFFFFF
	_llm_gen.generate_line_async(idx, text, emotion, _llm_lang)
	# Wait a frame for generation to start, then poll results
	await get_tree().process_frame
	# The generator runs async internally; wait for result
	var attempts := 0
	while _llm_gen.get_result(idx, "") == "" and attempts < 300:
		await get_tree().process_frame
		attempts += 1
	return _llm_gen.get_result(idx, text)


func _load_player_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var profile: Dictionary = run_data.get("traveler_profile", {})
		player_class = profile.get("class", "eclaireur")
		chronicle_name = run_data.get("chronicle_name", "Voyageur")
	suggested_biome = CLASS_TO_BIOME.get(player_class, "foret_broceliande")


# ═══════════════════════════════════════════════════════════════════════════════
# UI BUILD — Parchemin Mystique Breton
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
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.08)
		mat.set_shader_parameter("warp_strength", 0.001)
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

	# Portrait Merlin
	portrait_container = CenterContainer.new()
	card_vbox.add_child(portrait_container)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = PORTRAIT_SIZE
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_seasonal_portrait()
	portrait_container.add_child(portrait_rect)

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
	sep_diamond.text = "\u25C6"
	sep_diamond.add_theme_color_override("font_color", PALETTE.accent)
	sep_diamond.add_theme_font_size_override("font_size", 10)
	sep_container.add_child(sep_diamond)
	var sep_right := ColorRect.new()
	sep_right.color = PALETTE.line
	sep_right.custom_minimum_size = Vector2(60, 1)
	sep_container.add_child(sep_right)

	# Merlin text area
	merlin_text = RichTextLabel.new()
	merlin_text.name = "MerlinText"
	merlin_text.bbcode_enabled = true
	merlin_text.fit_content = true
	merlin_text.scroll_active = false
	merlin_text.custom_minimum_size = Vector2(440, 130)
	merlin_text.visible_characters = 0
	merlin_text.text = ""
	merlin_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		merlin_text.add_theme_font_override("normal_font", body_font)
	merlin_text.add_theme_font_size_override("normal_font_size", 26)
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)
	card_vbox.add_child(merlin_text)

	# Bestiole label (hidden, used in Phase A)
	bestiole_label = Label.new()
	bestiole_label.text = "\u2022"
	bestiole_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bestiole_label.add_theme_color_override("font_color", PALETTE.bestiole)
	bestiole_label.add_theme_font_size_override("font_size", 28)
	bestiole_label.visible = false
	bestiole_label.modulate.a = 0.0
	card_vbox.add_child(bestiole_label)

	# Ogham panel (hidden, used in Phase C)
	_build_ogham_panel()

	# Biome panel (hidden, used in Phase D)
	_build_biome_panel()

	# Skip hint — inside card, below text
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

	# Seasonal overlay (snow/petals on card)
	_build_seasonal_overlay()

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


func _load_seasonal_portrait() -> void:
	var month: int = Time.get_date_dict_from_system().month
	var path := PORTRAIT_DEFAULT
	if month >= 3 and month <= 5:
		path = PORTRAIT_PRINTEMPS
	elif month >= 6 and month <= 8:
		path = PORTRAIT_ETE
	elif month >= 9 and month <= 11:
		path = PORTRAIT_AUTOMNE
	else:
		path = PORTRAIT_HIVER
	if ResourceLoader.exists(path):
		portrait_rect.texture = load(path)
	elif ResourceLoader.exists(PORTRAIT_DEFAULT):
		portrait_rect.texture = load(PORTRAIT_DEFAULT)


func _make_celtic_ornament() -> Label:
	var lbl := Label.new()
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25C6", "\u2500", "\u2500", "\u2022", "\u2500"]
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


func _build_ogham_panel() -> void:
	ogham_panel = PanelContainer.new()
	ogham_panel.visible = false
	ogham_panel.modulate.a = 0.0

	var ogham_style := StyleBoxFlat.new()
	ogham_style.bg_color = PALETTE.paper_dark
	ogham_style.border_color = PALETTE.ogham_glow
	ogham_style.set_border_width_all(1)
	ogham_style.set_corner_radius_all(6)
	ogham_style.content_margin_left = 20
	ogham_style.content_margin_right = 20
	ogham_style.content_margin_top = 16
	ogham_style.content_margin_bottom = 16
	ogham_panel.add_theme_stylebox_override("panel", ogham_style)

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

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PALETTE.paper_dark
	panel_style.border_color = PALETTE.accent_soft
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	biome_panel.add_theme_stylebox_override("panel", panel_style)

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

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = biome.color.lightened(0.7)
		btn_pressed.border_color = biome.color
		btn_pressed.set_border_width_all(2)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		if body_font:
			btn.add_theme_font_override("font", body_font)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", PALETTE.ink)

		vbox.add_child(btn)
		biome_buttons[key] = btn

	add_child(biome_panel)


func _build_seasonal_overlay() -> void:
	var month: int = Time.get_date_dict_from_system().month
	var is_winter := month >= 12 or month <= 2
	if not is_winter:
		return
	var snow_shader = load("res://shaders/seasonal_snow.gdshader")
	if snow_shader == null:
		return
	seasonal_overlay = ColorRect.new()
	seasonal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = snow_shader
	mat.set_shader_parameter("speed", 0.25)
	mat.set_shader_parameter("density", 0.22)
	seasonal_overlay.material = mat
	add_child(seasonal_overlay)


func _layout_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	var card_w := minf(CARD_MAX_WIDTH, vp.x * 0.88)
	var card_h: float
	if _biome_layout:
		card_h = minf(320, vp.y * 0.38)
	else:
		card_h = minf(CARD_MAX_HEIGHT, vp.y * 0.72)
	card.size = Vector2(card_w, card_h)

	if _biome_layout:
		card.position = Vector2((vp.x - card_w) * 0.5, vp.y * 0.04)
	else:
		card.position = (vp - card.size) * 0.5
	card.pivot_offset = card.size * 0.5

	if celtic_top:
		celtic_top.size = Vector2(vp.x, 30)
		celtic_top.position = Vector2(0, card.position.y - 35)
	if celtic_bottom:
		celtic_bottom.size = Vector2(vp.x, 30)
		celtic_bottom.position = Vector2(0, card.position.y + card_h + 5)

	# Ogham panel: centered below card
	if ogham_panel:
		ogham_panel.position = Vector2((vp.x - 360) * 0.5, card.position.y + card_h + 16)

	# Biome panel: centered below card (fits because card is smaller in biome mode)
	if biome_panel:
		var bw := minf(340, vp.x * 0.8)
		biome_panel.position = Vector2((vp.x - bw) * 0.5, card.position.y + card_h + 16)

	# Seasonal overlay matches card position
	if seasonal_overlay:
		seasonal_overlay.position = card.position
		seasonal_overlay.size = card.size


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _play_entry_animation() -> void:
	if not card:
		return
	card.modulate.a = 0.0
	card.position.y += 40

	var tween := create_tween()
	tween.tween_property(celtic_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	var target_y := card.position.y - 40
	tween.tween_property(card, "position:y", target_y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _start_mist_animation() -> void:
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.20, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.06, 8.0).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE A: BESTIOLE APPARITION
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase_bestiole() -> void:
	current_phase = Phase.BESTIOLE_INTRO

	var lines_data: Dictionary = dialogue_data.get("bestiole_apparition", {})
	var lines: Array = lines_data.get("lines", [])

	# Fallback
	if lines.is_empty():
		lines = [
			{"text": "Quelque chose bouge dans l'ombre.", "speaker": "NARRATION"},
			{"text": "La lueur s'approche. Deux yeux immenses.", "speaker": "NARRATION"},
			{"text": "Un son doux qui dit : je suis la.", "speaker": "NARRATION"},
		]

	for i in range(lines.size()):
		if scene_finished:
			return
		var line: Dictionary = lines[i]
		var text: String = line.get("text", "")
		var speaker: String = line.get("speaker", "NARRATION")
		# LLM rephrase (narration too)
		text = await _llm_rephrase(text, line.get("emotion", "neutre"))

		# Narration style: italic/soft
		if speaker == "NARRATION":
			merlin_text.add_theme_color_override("default_color", PALETTE.ink_soft)
		else:
			merlin_text.add_theme_color_override("default_color", PALETTE.ink)

		# Show bestiole glow on first line
		if i == 0:
			bestiole_label.visible = true
			var glow := create_tween()
			glow.tween_property(bestiole_label, "modulate:a", 0.7, 1.5).set_trans(Tween.TRANS_SINE)

		await _show_text(text)
		skip_hint.visible = true
		await _wait_for_advance(5.0)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	# Hide bestiole glow
	var hide_glow := create_tween()
	hide_glow.tween_property(bestiole_label, "modulate:a", 0.0, 0.4)
	await hide_glow.finished
	bestiole_label.visible = false

	_run_phase_merlin_on_bestiole()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE B: MERLIN ON BESTIOLE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase_merlin_on_bestiole() -> void:
	current_phase = Phase.MERLIN_ON_BESTIOLE
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)

	var section: Dictionary = dialogue_data.get("merlin_sur_bestiole", {})
	var lines: Array = section.get("lines", [])

	if lines.is_empty():
		lines = [
			{"text": "Ah. Bestiole t'a trouve. Elle fait ca.", "emotion": "tendresse_masquee"},
			{"text": "Prends soin d'elle. Plus que de moi.", "emotion": "sincerite_breve"},
		]

	for i in range(lines.size()):
		if scene_finished:
			return
		var line: Dictionary = lines[i]
		var text: String = line.get("text", "")
		var emotion: String = line.get("emotion", "warm")
		text = await _llm_rephrase(text, emotion)

		var mood := _emotion_to_mood(emotion)
		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		await _show_text(text)
		skip_hint.visible = true
		await _wait_for_advance(5.0)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	_run_phase_ogham()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE C: OGHAM REVEAL
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase_ogham() -> void:
	current_phase = Phase.OGHAM_REVEAL

	var ogham_text: String = await _llm_rephrase("Tu portes deja trois Oghams. Les premiers. Ceux qui comptent le plus.", "sage")
	await _show_text(ogham_text)
	await get_tree().create_timer(1.0).timeout

	# Show ogham panel
	ogham_panel.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ogham_panel, "modulate:a", 1.0, 0.8)

	# Flash each ogham
	await tween.finished
	for child in ogham_panel.get_child(0).get_children():
		var flash := create_tween()
		flash.tween_property(child, "modulate", Color(1.4, 1.4, 1.0, 1.0), 0.15)
		flash.tween_property(child, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
		await flash.finished

	skip_hint.visible = true
	await _wait_for_advance(4.0)
	skip_hint.visible = false

	# Hide oghams
	var hide_tween := create_tween()
	hide_tween.tween_property(ogham_panel, "modulate:a", 0.0, 0.4)
	await hide_tween.finished
	ogham_panel.visible = false

	_run_phase_mission()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE D: MISSION BRIEFING
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase_mission() -> void:
	current_phase = Phase.MISSION_BRIEFING
	merlin_text.add_theme_color_override("default_color", PALETTE.ink)

	var section: Dictionary = dialogue_data.get("mission_briefing", {})
	var lines: Array = section.get("lines", [])

	if lines.is_empty():
		lines = [
			{"text": "Le monde. Sept terres, sept sanctuaires.", "emotion": "exposition_joviale"},
			{"text": "Forets, landes, cotes, villages, cercles, marais, collines.", "emotion": "avertissement_amuse"},
			{"text": "Ton travail? Traverser. Observer. Choisir.", "emotion": "verite_cachee_dans_humour"},
			{"text": "Tes choix comptent. Le monde regarde. Et moi aussi.", "emotion": "gravite_douce"},
		]

	for i in range(lines.size()):
		if scene_finished:
			return
		var line: Dictionary = lines[i]
		var text: String = line.get("text", "")
		var emotion: String = line.get("emotion", "sage")
		text = await _llm_rephrase(text, emotion)

		var mood := _emotion_to_mood(emotion)
		var screen_fx := get_node_or_null("/root/ScreenEffects")
		if screen_fx and screen_fx.has_method("set_merlin_mood"):
			screen_fx.set_merlin_mood(mood)

		await _show_text(text)
		skip_hint.visible = true
		await _wait_for_advance(5.5)
		skip_hint.visible = false

		if i < lines.size() - 1:
			var fade := create_tween()
			fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
			await fade.finished
			merlin_text.modulate.a = 1.0

	_run_phase_biome_selection()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE E: BIOME SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _run_phase_biome_selection() -> void:
	current_phase = Phase.BIOME_SELECTION

	# Show Merlin's class suggestion
	var suggestions: Dictionary = dialogue_data.get("class_biome_suggestions", {})
	var variants: Dictionary = suggestions.get("variants", {})
	if variants.has(player_class):
		var suggestion: Dictionary = variants[player_class]
		var text: String = suggestion.get("text", "")
		text = await _llm_rephrase(text, "suggestion")
		await _show_text(text)
		await get_tree().create_timer(1.5).timeout

	# Show carte text
	var carte: Dictionary = dialogue_data.get("carte_biomes", {})
	var carte_line: Dictionary = carte.get("line", {})
	var carte_text: String = carte_line.get("text", "Par ou veux-tu commencer?")
	carte_text = await _llm_rephrase(carte_text, "transition_vers_choix")

	var fade := create_tween()
	fade.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
	await fade.finished
	merlin_text.modulate.a = 1.0

	await _show_text(carte_text)

	# Switch to compact layout — hide portrait, shrink card, show biome panel below
	portrait_container.visible = false
	_biome_layout = true
	_layout_ui()

	biome_panel.visible = true
	var show_tween := create_tween()
	show_tween.tween_property(biome_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	# Enable buttons
	for key in biome_buttons:
		biome_buttons[key].disabled = false

	# Highlight suggested biome
	if biome_buttons.has(suggested_biome):
		var suggested_btn: Button = biome_buttons[suggested_biome]
		if _biome_pulse_tween:
			_biome_pulse_tween.kill()
		_biome_pulse_tween = create_tween().set_loops()
		_biome_pulse_tween.tween_property(suggested_btn, "modulate", Color(1.15, 1.10, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
		_biome_pulse_tween.tween_property(suggested_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

	skip_hint.text = "Choisis un sanctuaire"
	skip_hint.visible = true


func _on_biome_selected(biome_key: String) -> void:
	if current_phase != Phase.BIOME_SELECTION or scene_finished:
		return

	selected_biome = biome_key
	skip_hint.visible = false

	# Kill pulse tween on suggested biome
	if _biome_pulse_tween:
		_biome_pulse_tween.kill()
		_biome_pulse_tween = null

	# Disable all buttons
	for key in biome_buttons:
		biome_buttons[key].disabled = true

	# Show reaction
	var reactions: Dictionary = dialogue_data.get("player_reactions", {})
	var reaction_text: String
	if biome_key == suggested_biome:
		var acceptance: Dictionary = reactions.get("acceptance", {})
		reaction_text = acceptance.get("text", "Tu me fais confiance? En route.")
		reaction_text = await _llm_rephrase(reaction_text, "surprise_touchee")
	else:
		var rejection: Dictionary = reactions.get("rejection", {})
		reaction_text = rejection.get("text", "Tu refuses mes conseils. Excellent.")
		reaction_text = await _llm_rephrase(reaction_text, "amusement_respectueux")

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("amuse")

	var fade_txt := create_tween()
	fade_txt.tween_property(merlin_text, "modulate:a", 0.0, 0.3)
	await fade_txt.finished
	merlin_text.modulate.a = 1.0

	await _show_text(reaction_text)
	await get_tree().create_timer(2.0).timeout

	_save_and_transition()


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE & TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func _save_and_transition() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		run_data["current_biome"] = selected_biome
		run_data["active"] = true
		gm.set("run", run_data)

		var bestiole_data: Dictionary = gm.get("bestiole") if gm.get("bestiole") is Dictionary else {}
		bestiole_data["known_oghams"] = ["beith", "luis", "quert"]
		bestiole_data["equipped_oghams"] = ["beith", "luis", "quert", ""]
		gm.set("bestiole", bestiole_data)

	_transition_out()


func _transition_out() -> void:
	scene_finished = true
	current_phase = Phase.TRANSITIONING

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(celtic_top, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(celtic_bottom, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(biome_panel, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(mist_layer, "modulate:a", 0.6, 0.8)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))
	await tween.finished


func _clean_tags(text: String) -> String:
	text = text.replace("[long_pause]", "").replace("[pause]", "").replace("[beat]", "")
	while text.find("  ") != -1:
		text = text.replace("  ", " ")
	return text.strip_edges()


func _emotion_to_mood(emotion: String) -> String:
	if "humour" in emotion or "jovial" in emotion or "amuse" in emotion:
		return "amuse"
	if "vulnerabilite" in emotion or "soulagement" in emotion or "pensif" in emotion:
		return "pensif"
	if "accueil" in emotion or "warm" in emotion or "tendresse" in emotion:
		return "warm"
	if "serieux" in emotion or "gravite" in emotion:
		return "serieux"
	return "sage"


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func _show_text(text: String) -> void:
	text = _clean_tags(text)
	typing_active = true
	typing_abort = false

	merlin_text.text = text
	merlin_text.visible_characters = 0
	for i in range(text.length()):
		if typing_abort:
			break
		merlin_text.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		await get_tree().create_timer(delay).timeout
	merlin_text.visible_characters = -1
	typing_active = false


func _skip_typewriter() -> void:
	if typing_active:
		typing_abort = true
		merlin_text.visible_characters = -1
		if voice_ready and voicebox and voicebox.has_method("stop_speaking"):
			voicebox.stop_speaking()


func _wait_for_advance(max_wait: float) -> void:
	var elapsed := 0.0
	while elapsed < max_wait and not _advance_requested and not scene_finished:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_advance_requested = false


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

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
		elif current_phase != Phase.BIOME_SELECTION:
			_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	audio_player.volume_db = linear_to_db(BLIP_VOLUME)
	add_child(audio_player)


func _setup_voicebox() -> void:
	var script_path := "res://addons/acvoicebox/acvoicebox.gd"
	if ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr:
			voicebox = scr.new()
			if voicebox:
				voicebox.set("sound_bank", "whisper")
				voicebox.set("base_pitch", 3.2)
				voicebox.set("pitch_variation", 0.15)
				voicebox.set("speed_scale", 0.85)
				add_child(voicebox)
				await get_tree().process_frame
				if voicebox.has_method("is_ready") and voicebox.is_ready():
					voice_ready = true
				else:
					voice_ready = false


func _play_blip() -> void:
	## Soft keyboard click — procedural
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


func _on_resized() -> void:
	call_deferred("_layout_ui")
