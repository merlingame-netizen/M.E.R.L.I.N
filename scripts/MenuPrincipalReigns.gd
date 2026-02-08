extends Control

# =============================================================================
# MENU PRINCIPAL "PARCHEMIN MYSTIQUE BRETON"
# Design celtique sobre et épuré - Ambiance sanctuaire ancien
# =============================================================================

# Palette "Parchemin Mystique Breton" - Sobre et épurée
const PALETTE := {
	# Fond parchemin ivoire chaleureux
	"paper": Color(0.965, 0.945, 0.905),        # Ivoire ancien
	"paper_dark": Color(0.935, 0.905, 0.855),   # Parchemin usé
	"paper_warm": Color(0.955, 0.930, 0.890),   # Parchemin tiède

	# Encres sépia/brun profond
	"ink": Color(0.22, 0.18, 0.14),             # Encre brune profonde
	"ink_soft": Color(0.38, 0.32, 0.26),        # Encre diluée
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35), # Encre très pâle

	# Accents bronze/or vieilli
	"accent": Color(0.58, 0.44, 0.26),          # Bronze ancien
	"accent_soft": Color(0.65, 0.52, 0.34),     # Or terni
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),# Lueur dorée subtile

	# Effets atmosphériques
	"shadow": Color(0.25, 0.20, 0.16, 0.18),    # Ombre chaude légère
	"line": Color(0.40, 0.34, 0.28, 0.12),      # Lignes subtiles
	"mist": Color(0.94, 0.92, 0.88, 0.35),      # Brume bretonne

	# Ornements celtiques
	"celtic_gold": Color(0.68, 0.55, 0.32),     # Or celtique
	"celtic_brown": Color(0.45, 0.36, 0.28),    # Brun enluminure
}

const TITLE_TEXT := "M  E  R  L  I  N"
const SUBTITLE_TEXT := "Le Dernier Druide"

const MAIN_MENU_ITEMS := [
	{"text": "Nouvelle Partie", "scene": "res://scenes/IntroPersonalityQuiz.tscn"},
	{"text": "Continuer", "scene": "res://scenes/SelectionSauvegarde.tscn"},
	{"text": "Test LLM", "scene": "res://scenes/TestLLMSceneUltimate.tscn"},
	{"text": "Options", "scene": "res://scenes/MenuOptions.tscn"},
	{"text": "Quitter", "scene": "__quit__"},
]

# Ornements celtiques (caractères Unicode)
const CELTIC_ORNAMENTS := {
	"triskel": "☘",           # Trèfle (proche triskel)
	"spiral": "◎",            # Spirale
	"knot_simple": "❋",       # Nœud simplifié
	"diamond": "◆",           # Losange
	"dot": "•",               # Point
	"line_h": "─",            # Ligne horizontale
	"corner_tl": "╭",         # Coin haut-gauche
	"corner_tr": "╮",         # Coin haut-droite
	"corner_bl": "╰",         # Coin bas-gauche
	"corner_br": "╯",         # Coin bas-droite
}

const CORNER_BUTTON_SIZE := Vector2(52, 52)
const CORNER_BUTTON_MARGIN := 28
const CARD_MAX_WIDTH := 480.0
const CARD_MAX_HEIGHT := 520.0
const COLLECTION_SCENE := "res://scenes/Collection.tscn"
const CALENDAR_SCENE := "res://scenes/Calendar.tscn"
const CONFIG_PATH := "user://settings.cfg"

# Calendar settings
var calendar_override := false
var calendar_day := 1
var calendar_month := 1
var calendar_year := 2026

# UI Elements
var parchment_background: ColorRect
var mist_layer: ColorRect
var celtic_ornament_top: Label
var celtic_ornament_bottom: Label
var card: PanelContainer
var card_contents: VBoxContainer
var main_buttons: VBoxContainer
var title_label: Label
var subtitle_label: Label
var separator_line: ColorRect

# Corner buttons
var calendar_button: Button
var collections_button: Button
var _corner_hover_tweens: Dictionary = {}

# Fonts
var title_font: Font
var body_font: Font
var celtic_font: Font

# Animation state
var card_target_pos := Vector2.ZERO
var swipe_in_progress := false
var swipe_tween: Tween
var _entry_tween: Tween
var _mist_tween: Tween

# Audio
var _sfx_player: AudioStreamPlayer

const UI_SOUNDS := {
	"hover": "res://audio/sfx/ui/ui_hover.ogg",
	"click": "res://audio/sfx/ui/ui_click.ogg",
	"whoosh": "res://audio/sfx/ui/card_swipe.ogg",
}

# Season for atmosphere
var current_season := "HIVER"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_calendar_settings()
	_determine_season()
	_load_fonts()
	_setup_audio()
	_build_parchment_background()
	_build_mist_layer()
	_build_celtic_ornaments()
	_build_ui()
	_build_corner_buttons()
	_apply_theme()
	_layout_ui()
	resized.connect(_on_resized)
	_play_entry_animation.call_deferred()
	_start_mist_animation()


func _load_calendar_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		calendar_override = config.get_value("calendar", "override", false)
		calendar_day = config.get_value("calendar", "day", 1)
		calendar_month = config.get_value("calendar", "month", 1)
		calendar_year = config.get_value("calendar", "year", 2026)


func _get_current_date() -> Dictionary:
	if calendar_override:
		return {"day": calendar_day, "month": calendar_month, "year": calendar_year}
	return Time.get_date_dict_from_system()


func _determine_season() -> void:
	var date := _get_current_date()
	var month: int = date.month
	if month >= 3 and month <= 5:
		current_season = "PRINTEMPS"
	elif month >= 6 and month <= 8:
		current_season = "ETE"
	elif month >= 9 and month <= 11:
		current_season = "AUTOMNE"
	else:
		current_season = "HIVER"


func _load_fonts() -> void:
	# Morris Roman pour l'élégance celtique
	title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font
	# Celtic font for ornaments
	celtic_font = _load_font("res://resources/fonts/celtic_bit/celtic-bit.ttf")
	if celtic_font == null:
		celtic_font = body_font


func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return ThemeDB.fallback_font


func _setup_audio() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	_sfx_player.volume_db = -10.0
	add_child(_sfx_player)


# =============================================================================
# FOND PARCHEMIN MYSTIQUE
# =============================================================================

func _build_parchment_background() -> void:
	# Fond parchemin avec shader paper
	parchment_background = ColorRect.new()
	parchment_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Charger le shader de parchemin
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		# Paramètres pour un parchemin doux et sobre
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)      # Grain très subtil
		mat.set_shader_parameter("vignette_strength", 0.08)    # Vignette légère
		mat.set_shader_parameter("vignette_softness", 0.65)    # Bords doux
		mat.set_shader_parameter("grain_scale", 1200.0)        # Grain fin
		mat.set_shader_parameter("grain_speed", 0.08)          # Mouvement lent
		mat.set_shader_parameter("warp_strength", 0.001)       # Ondulation minimale
		parchment_background.material = mat
	else:
		# Fallback: couleur unie
		parchment_background.color = PALETTE.paper

	add_child(parchment_background)


func _build_mist_layer() -> void:
	# Couche de brume légère pour l'atmosphère mystique
	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_layer.modulate.a = 0.0  # Commence invisible
	add_child(mist_layer)


func _start_mist_animation() -> void:
	# Animation subtile de la brume (respiration douce)
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 8.0).set_trans(Tween.TRANS_SINE)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.08, 8.0).set_trans(Tween.TRANS_SINE)


# =============================================================================
# ORNEMENTS CELTIQUES
# =============================================================================

func _build_celtic_ornaments() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	# Ornement haut - ligne décorative celtique
	celtic_ornament_top = Label.new()
	celtic_ornament_top.text = _create_celtic_line(40)
	celtic_ornament_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celtic_ornament_top.add_theme_color_override("font_color", PALETTE.ink_faded)
	celtic_ornament_top.add_theme_font_size_override("font_size", 14)
	celtic_ornament_top.position = Vector2(0, 50)
	celtic_ornament_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celtic_ornament_top)

	# Ornement bas - motif celtique
	celtic_ornament_bottom = Label.new()
	celtic_ornament_bottom.text = _create_celtic_line(40)
	celtic_ornament_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celtic_ornament_bottom.add_theme_color_override("font_color", PALETTE.ink_faded)
	celtic_ornament_bottom.add_theme_font_size_override("font_size", 14)
	celtic_ornament_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celtic_ornament_bottom)


func _create_celtic_line(length: int) -> String:
	# Crée une ligne décorative celtique sobre
	var line := ""
	var pattern := ["─", "•", "─", "─", "◆", "─", "─", "•", "─"]
	for i in range(length):
		line += pattern[i % pattern.size()]
	return line


func _layout_celtic_ornaments(viewport_size: Vector2) -> void:
	if celtic_ornament_top:
		celtic_ornament_top.size = Vector2(viewport_size.x, 30)
		celtic_ornament_top.position = Vector2(0, 45)

	if celtic_ornament_bottom:
		celtic_ornament_bottom.size = Vector2(viewport_size.x, 30)
		celtic_ornament_bottom.position = Vector2(0, viewport_size.y - 75)


# =============================================================================
# UI PRINCIPALE
# =============================================================================

func _build_ui() -> void:
	# Carte centrale (style manuscrit enluminé)
	card = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)

	card_contents = VBoxContainer.new()
	card_contents.name = "CardContents"
	card_contents.alignment = BoxContainer.ALIGNMENT_CENTER
	card_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_contents.add_theme_constant_override("separation", 16)
	card.add_child(card_contents)

	# Titre principal avec espacement élégant
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = TITLE_TEXT
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_contents.add_child(title_label)

	# Sous-titre poétique
	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = SUBTITLE_TEXT
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_contents.add_child(subtitle_label)

	# Séparateur élégant avec motif central
	var separator_container := HBoxContainer.new()
	separator_container.alignment = BoxContainer.ALIGNMENT_CENTER
	separator_container.add_theme_constant_override("separation", 8)
	card_contents.add_child(separator_container)

	var sep_left := ColorRect.new()
	sep_left.color = PALETTE.line
	sep_left.custom_minimum_size = Vector2(60, 1)
	separator_container.add_child(sep_left)

	var sep_diamond := Label.new()
	sep_diamond.text = "◆"
	sep_diamond.add_theme_color_override("font_color", PALETTE.accent)
	sep_diamond.add_theme_font_size_override("font_size", 10)
	separator_container.add_child(sep_diamond)

	var sep_right := ColorRect.new()
	sep_right.color = PALETTE.line
	sep_right.custom_minimum_size = Vector2(60, 1)
	separator_container.add_child(sep_right)

	# Boutons du menu
	main_buttons = VBoxContainer.new()
	main_buttons.name = "MainButtons"
	main_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	main_buttons.add_theme_constant_override("separation", 8)
	card_contents.add_child(main_buttons)

	for item in MAIN_MENU_ITEMS:
		var btn := _create_button(item.text, item.scene, true)
		main_buttons.add_child(btn)


func _build_corner_buttons() -> void:
	# Bouton Calendrier (bas-gauche)
	calendar_button = Button.new()
	calendar_button.name = "CalendarButton"
	calendar_button.text = "◎"  # Symbole spirale
	calendar_button.custom_minimum_size = CORNER_BUTTON_SIZE
	calendar_button.focus_mode = Control.FOCUS_NONE
	calendar_button.flat = true
	calendar_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	calendar_button.pressed.connect(_on_calendar_pressed)
	calendar_button.mouse_entered.connect(func(): _on_corner_button_hover(calendar_button, true))
	calendar_button.mouse_exited.connect(func(): _on_corner_button_hover(calendar_button, false))
	add_child(calendar_button)

	# Bouton Collections (bas-droite)
	collections_button = Button.new()
	collections_button.name = "CollectionsButton"
	collections_button.text = "❋"  # Symbole nœud
	collections_button.custom_minimum_size = CORNER_BUTTON_SIZE
	collections_button.focus_mode = Control.FOCUS_NONE
	collections_button.flat = true
	collections_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	collections_button.pressed.connect(_on_collections_pressed)
	collections_button.mouse_entered.connect(func(): _on_corner_button_hover(collections_button, true))
	collections_button.mouse_exited.connect(func(): _on_corner_button_hover(collections_button, false))
	add_child(collections_button)


# =============================================================================
# THÈME ET STYLES
# =============================================================================

func _apply_theme() -> void:
	var menu_theme := Theme.new()

	# Style carte - parchemin élégant avec bordure fine
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PALETTE.paper_warm
	card_style.border_color = PALETTE.ink_faded
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.shadow_color = PALETTE.shadow
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 4)
	card_style.content_margin_left = 36
	card_style.content_margin_top = 32
	card_style.content_margin_right = 36
	card_style.content_margin_bottom = 32
	menu_theme.set_stylebox("panel", "PanelContainer", card_style)

	# Style boutons - minimaliste, élégant
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(1, 1, 1, 0.0)
	btn_normal.border_color = Color(0, 0, 0, 0)
	btn_normal.content_margin_left = 16
	btn_normal.content_margin_top = 14
	btn_normal.content_margin_right = 16
	btn_normal.content_margin_bottom = 14

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = PALETTE.accent_glow
	btn_hover.border_color = PALETTE.accent
	btn_hover.border_width_bottom = 1
	btn_hover.corner_radius_top_left = 2
	btn_hover.corner_radius_top_right = 2
	btn_hover.corner_radius_bottom_left = 2
	btn_hover.corner_radius_bottom_right = 2
	btn_hover.content_margin_left = 16
	btn_hover.content_margin_top = 14
	btn_hover.content_margin_right = 16
	btn_hover.content_margin_bottom = 14

	var btn_pressed := btn_hover.duplicate()
	btn_pressed.bg_color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.15)

	menu_theme.set_stylebox("normal", "Button", btn_normal)
	menu_theme.set_stylebox("hover", "Button", btn_hover)
	menu_theme.set_stylebox("pressed", "Button", btn_pressed)
	menu_theme.set_stylebox("focus", "Button", btn_hover)
	menu_theme.set_stylebox("disabled", "Button", btn_normal)

	menu_theme.set_color("font_color", "Button", PALETTE.ink)
	menu_theme.set_color("font_hover_color", "Button", PALETTE.accent)
	menu_theme.set_color("font_pressed_color", "Button", PALETTE.accent)
	menu_theme.set_color("font_disabled_color", "Button", PALETTE.ink_faded)

	menu_theme.set_color("font_color", "Label", PALETTE.ink)

	self.theme = menu_theme

	# Style titre
	if title_label and title_font:
		title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", 52)
		title_label.add_theme_color_override("font_color", PALETTE.ink)

	# Style sous-titre
	if subtitle_label and body_font:
		subtitle_label.add_theme_font_override("font", body_font)
		subtitle_label.add_theme_font_size_override("font_size", 16)
		subtitle_label.add_theme_color_override("font_color", PALETTE.ink_soft)

	# Style boutons menu
	for btn in main_buttons.get_children():
		if btn is Button and body_font:
			btn.add_theme_font_override("font", body_font)
			btn.add_theme_font_size_override("font_size", 22)
			btn.add_theme_color_override("font_color", PALETTE.ink)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Style boutons coins
	_apply_corner_button_style(calendar_button)
	_apply_corner_button_style(collections_button)


func _apply_corner_button_style(btn: Button) -> void:
	if btn:
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", PALETTE.ink_soft)
		btn.pivot_offset = CORNER_BUTTON_SIZE * 0.5


# =============================================================================
# ANIMATIONS
# =============================================================================

func _play_entry_animation() -> void:
	if not card:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	# État initial: carte invisible, légèrement en bas
	card.position.y = card_target_pos.y + 40
	card.modulate.a = 0.0

	# Ornements invisibles
	if celtic_ornament_top:
		celtic_ornament_top.modulate.a = 0.0
	if celtic_ornament_bottom:
		celtic_ornament_bottom.modulate.a = 0.0

	# Boutons invisibles
	for btn in main_buttons.get_children():
		if btn is Button:
			btn.modulate.a = 0.0

	# Animation d'entrée douce et élégante
	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = create_tween()

	# Fade in des ornements
	_entry_tween.tween_property(celtic_ornament_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(celtic_ornament_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	# Entrée de la carte
	_entry_tween.tween_property(card, "position:y", card_target_pos.y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

	# Apparition des boutons en cascade
	_entry_tween.tween_callback(func(): _animate_buttons_entry())


func _animate_buttons_entry() -> void:
	var delay := 0.0
	for btn in main_buttons.get_children():
		if btn is Button:
			var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_interval(delay)
			tween.tween_property(btn, "modulate:a", 1.0, 0.3)
			delay += 0.05


func _create_button(label: String, scene: String, _is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.pressed.connect(func(): _on_menu_action(scene))
	btn.mouse_entered.connect(func(): _on_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_button_hover(btn, false))
	return btn


func _on_button_hover(btn: Button, hovering: bool) -> void:
	if hovering:
		_play_ui_sound("hover")
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.15)
	else:
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)


func _on_corner_button_hover(btn: Button, hovering: bool) -> void:
	if _corner_hover_tweens.has(btn) and _corner_hover_tweens[btn]:
		_corner_hover_tweens[btn].kill()
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_corner_hover_tweens[btn] = tween
	if hovering:
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.2)
		btn.add_theme_color_override("font_color", PALETTE.accent)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
		btn.add_theme_color_override("font_color", PALETTE.ink_soft)


# =============================================================================
# LAYOUT
# =============================================================================

func _layout_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var card_w: float = minf(CARD_MAX_WIDTH, viewport_size.x * 0.85)
	var card_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * 0.72)
	var content_min: Vector2 = card_contents.get_combined_minimum_size()
	if content_min.y > 0.0:
		var max_h: float = minf(CARD_MAX_HEIGHT, viewport_size.y * 0.88)
		card_h = minf(maxf(card_h, content_min.y + 48.0), max_h)
	card.size = Vector2(card_w, card_h)
	card.position = (viewport_size - card.size) * 0.5
	card.pivot_offset = card.size * 0.5
	card_target_pos = card.position

	_layout_corner_buttons(viewport_size)
	_layout_celtic_ornaments(viewport_size)


func _layout_corner_buttons(viewport_size: Vector2) -> void:
	if calendar_button:
		calendar_button.position = Vector2(
			CORNER_BUTTON_MARGIN,
			viewport_size.y - CORNER_BUTTON_SIZE.y - CORNER_BUTTON_MARGIN
		)
		calendar_button.size = CORNER_BUTTON_SIZE

	if collections_button:
		collections_button.position = Vector2(
			viewport_size.x - CORNER_BUTTON_SIZE.x - CORNER_BUTTON_MARGIN,
			viewport_size.y - CORNER_BUTTON_SIZE.y - CORNER_BUTTON_MARGIN
		)
		collections_button.size = CORNER_BUTTON_SIZE


# =============================================================================
# ACTIONS
# =============================================================================

func _on_menu_action(scene: String) -> void:
	_play_ui_sound("click")
	if scene == "__quit__":
		get_tree().quit()
		return
	if scene == "" or swipe_in_progress:
		return
	swipe_in_progress = true
	_play_ui_sound("whoosh")

	var dir := 1.0
	if card:
		var mouse_pos := get_viewport().get_mouse_position()
		var card_center := card.global_position + card.size * 0.5
		if mouse_pos.x < card_center.x:
			dir = -1.0
	_play_swipe(dir)
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file(scene)


func _on_calendar_pressed() -> void:
	if swipe_in_progress:
		return
	swipe_in_progress = true
	_play_swipe(-1.0)
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file(CALENDAR_SCENE)


func _on_collections_pressed() -> void:
	if swipe_in_progress:
		return
	swipe_in_progress = true
	_play_swipe(1.0)
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file(COLLECTION_SCENE)


func _play_swipe(dir: float) -> void:
	if swipe_tween:
		swipe_tween.kill()
	var angle := deg_to_rad(5.0) * dir
	var offset := Vector2(120.0 * dir, -8.0)
	swipe_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	swipe_tween.tween_property(card, "rotation", angle, 0.25)
	swipe_tween.parallel().tween_property(card, "position", card.position + offset, 0.25)
	swipe_tween.parallel().tween_property(card, "modulate:a", 0.0, 0.2)


func _play_ui_sound(sound_name: String) -> void:
	if not UI_SOUNDS.has(sound_name):
		return
	var path: String = UI_SOUNDS[sound_name]
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			_sfx_player.stream = stream
			_sfx_player.play()


func _on_resized() -> void:
	call_deferred("_layout_ui")
