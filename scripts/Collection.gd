extends Control
## Collection - Style Parchemin Celtique
## Hauts faits, progression et collection d'objets

const FONT_REGULAR_PATH := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
const FONT_BOLD_PATH := "res://resources/fonts/morris/MorrisRomanBlack.ttf"
const MOBILE_BREAKPOINT := 560.0

const VIEW_PROGRESSION := 0
const VIEW_RECENTS := 1
const VIEW_COLLECTION := 2

# Palette Parchemin Celtique - identique au MenuPrincipalReigns
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
	"line": Color(0.40, 0.34, 0.28, 0.15),
	"mist": Color(0.94, 0.92, 0.88, 0.35),
	"celtic_gold": Color(0.68, 0.55, 0.32),
	"celtic_brown": Color(0.45, 0.36, 0.28),
	"success": Color(0.35, 0.55, 0.40),
	"locked": Color(0.55, 0.50, 0.45, 0.6),
}

const CELTIC_ORNAMENT := ["─", "•", "─", "─", "◆", "─", "─", "•", "─"]

const PROGRESSION_STATS := [
	{"label": "General", "current": 6, "max": 24},
	{"label": "Quetes", "current": 3, "max": 18},
	{"label": "Conflits", "current": 2, "max": 12},
	{"label": "Donjons", "current": 4, "max": 16},
	{"label": "Metiers", "current": 5, "max": 20},
	{"label": "Reputation", "current": 3, "max": 10},
]

const SAMPLE_ACHIEVEMENTS := [
	{
		"title": "Serment tenu",
		"desc": "Tenir 3 promesses majeures.",
		"date": "31/01",
		"icon": "S"
	},
	{
		"title": "Bestiole apaisee",
		"desc": "Atteindre un lien de 50.",
		"date": "31/01",
		"icon": "B"
	},
	{
		"title": "Anomalie devoilee",
		"desc": "Resoudre une faille de Merlin.",
		"date": "30/01",
		"icon": "A"
	}
]

const SAMPLE_COLLECTION := [
	{
		"icon": "C",
		"name": "Clef d'Ancrage",
		"req": "Tenir 3 serments",
		"locked": false,
		"hidden": false
	},
	{
		"icon": "R",
		"name": "Rune d'Echo",
		"req": "Terminer 2 routes de brume",
		"locked": false,
		"hidden": false
	},
	{
		"icon": "L",
		"name": "Lanterne des Brumes",
		"req": "Explorer a minuit",
		"locked": true,
		"hidden": false
	},
	{
		"icon": "?",
		"name": "???",
		"req": "???",
		"locked": true,
		"hidden": true
	},
	{
		"icon": "?",
		"name": "???",
		"req": "???",
		"locked": true,
		"hidden": true
	},
	{
		"icon": "S",
		"name": "Sceau des Marais",
		"req": "Finir la route des landes",
		"locked": true,
		"hidden": false
	}
]

var font_regular: Font
var font_bold: Font
var compact_mode := false
var current_view := VIEW_PROGRESSION

var glory_value := 1280
var rank_value := "Eclaireur"
var pass_value := 62
var pass_max := 100

var body_font_size := 14
var section_font_size := 18
var small_font_size := 12
var icon_tile_size := 32
var row_min_height := 48

# UI References
var parchment_bg: ColorRect
var mist_layer: ColorRect
var ornament_top: Label
var ornament_bottom: Label
var main_container: MarginContainer
var layout: VBoxContainer
var header: HBoxContainer
var title_label: Label
var glory_label: Label
var rank_label: Label
var pass_panel: PanelContainer
var pass_title_label: Label
var pass_progress: ProgressBar
var pass_progress_label: Label
var view_tabs: HBoxContainer
var btn_progression: Button
var btn_recents: Button
var btn_collection: Button
var content_scroll: ScrollContainer
var content_stack: VBoxContainer
var progress_section: VBoxContainer
var progress_title_label: Label
var progress_hint_label: Label
var progress_list: VBoxContainer
var recent_section: VBoxContainer
var recent_title_label: Label
var recent_list: VBoxContainer
var collection_section: VBoxContainer
var collection_title_label: Label
var collection_subtitle_label: Label
var collection_grid: HFlowContainer
var collection_list: VBoxContainer
var bottom_bar: HBoxContainer
var back_button: Button

func _ready() -> void:
	_load_fonts()
	_build_ui()
	_apply_style()
	_update_responsive_style()
	_populate_all()
	_set_view(VIEW_PROGRESSION)
	_start_mist_animation()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_update_responsive_style()
	_populate_all()
	_set_view(current_view)

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		font_regular = load(FONT_REGULAR_PATH)
	if ResourceLoader.exists(FONT_BOLD_PATH):
		font_bold = load(FONT_BOLD_PATH)
	if font_regular == null:
		font_regular = font_bold
	if font_bold == null:
		font_bold = font_regular

func _build_ui() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Parchment background with shader
	parchment_bg = ColorRect.new()
	parchment_bg.name = "ParchmentBg"
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)

	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		parchment_bg.material = mat

	# Mist layer for atmosphere
	mist_layer = ColorRect.new()
	mist_layer.name = "MistLayer"
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist_layer)

	# Celtic ornament top
	ornament_top = Label.new()
	ornament_top.name = "OrnamentTop"
	ornament_top.text = "".join(CELTIC_ORNAMENT)
	ornament_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ornament_top.offset_top = 8
	ornament_top.offset_bottom = 28
	add_child(ornament_top)

	# Celtic ornament bottom
	ornament_bottom = Label.new()
	ornament_bottom.name = "OrnamentBottom"
	ornament_bottom.text = "".join(CELTIC_ORNAMENT)
	ornament_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ornament_bottom.offset_top = -28
	ornament_bottom.offset_bottom = -8
	add_child(ornament_bottom)

	# Main container
	main_container = MarginContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	# Main layout
	layout = VBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(layout)

	# Header
	header = HBoxContainer.new()
	header.name = "Header"
	layout.add_child(header)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Collection"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.add_theme_constant_override("separation", 2)
	header.add_child(stats_vbox)

	glory_label = Label.new()
	glory_label.name = "GloryLabel"
	glory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_vbox.add_child(glory_label)

	rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_vbox.add_child(rank_label)

	# Separator line
	var sep_top := ColorRect.new()
	sep_top.name = "SeparatorTop"
	sep_top.custom_minimum_size = Vector2(0, 1)
	sep_top.color = PALETTE.line
	layout.add_child(sep_top)

	# Pass panel
	pass_panel = PanelContainer.new()
	pass_panel.name = "PassPanel"
	layout.add_child(pass_panel)

	var pass_vbox := VBoxContainer.new()
	pass_vbox.name = "PassVBox"
	pass_vbox.add_theme_constant_override("separation", 6)
	pass_panel.add_child(pass_vbox)

	pass_title_label = Label.new()
	pass_title_label.name = "PassTitleLabel"
	pass_title_label.text = "Passe de Gloire"
	pass_vbox.add_child(pass_title_label)

	pass_progress = ProgressBar.new()
	pass_progress.name = "PassProgress"
	pass_progress.custom_minimum_size = Vector2(0, 16)
	pass_progress.show_percentage = false
	pass_vbox.add_child(pass_progress)

	pass_progress_label = Label.new()
	pass_progress_label.name = "PassProgressLabel"
	pass_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_vbox.add_child(pass_progress_label)

	# View tabs
	view_tabs = HBoxContainer.new()
	view_tabs.name = "ViewTabs"
	view_tabs.add_theme_constant_override("separation", 8)
	layout.add_child(view_tabs)

	btn_progression = Button.new()
	btn_progression.name = "BtnProgression"
	btn_progression.text = "Progression"
	btn_progression.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_progression.pressed.connect(func(): _set_view(VIEW_PROGRESSION))
	view_tabs.add_child(btn_progression)

	btn_recents = Button.new()
	btn_recents.name = "BtnRecents"
	btn_recents.text = "Recents"
	btn_recents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_recents.pressed.connect(func(): _set_view(VIEW_RECENTS))
	view_tabs.add_child(btn_recents)

	btn_collection = Button.new()
	btn_collection.name = "BtnCollection"
	btn_collection.text = "Objets"
	btn_collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_collection.pressed.connect(func(): _set_view(VIEW_COLLECTION))
	view_tabs.add_child(btn_collection)

	# Content panel
	var content_panel := PanelContainer.new()
	content_panel.name = "ContentPanel"
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content_panel)

	content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(content_scroll)

	content_stack = VBoxContainer.new()
	content_stack.name = "ContentStack"
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_stack)

	# Progress section
	progress_section = VBoxContainer.new()
	progress_section.name = "ProgressSection"
	progress_section.add_theme_constant_override("separation", 8)
	content_stack.add_child(progress_section)

	progress_title_label = Label.new()
	progress_title_label.name = "ProgressTitleLabel"
	progress_title_label.text = "Progression par categorie"
	progress_section.add_child(progress_title_label)

	progress_hint_label = Label.new()
	progress_hint_label.name = "ProgressHintLabel"
	progress_hint_label.text = "Accomplissez des hauts faits pour debloquer des recompenses"
	progress_section.add_child(progress_hint_label)

	progress_list = VBoxContainer.new()
	progress_list.name = "ProgressList"
	progress_list.add_theme_constant_override("separation", 6)
	progress_section.add_child(progress_list)

	# Recent section
	recent_section = VBoxContainer.new()
	recent_section.name = "RecentSection"
	recent_section.add_theme_constant_override("separation", 8)
	content_stack.add_child(recent_section)

	recent_title_label = Label.new()
	recent_title_label.name = "RecentTitleLabel"
	recent_title_label.text = "Hauts faits recents"
	recent_section.add_child(recent_title_label)

	recent_list = VBoxContainer.new()
	recent_list.name = "RecentList"
	recent_list.add_theme_constant_override("separation", 6)
	recent_section.add_child(recent_list)

	# Collection section
	collection_section = VBoxContainer.new()
	collection_section.name = "CollectionSection"
	collection_section.add_theme_constant_override("separation", 8)
	content_stack.add_child(collection_section)

	collection_title_label = Label.new()
	collection_title_label.name = "CollectionTitleLabel"
	collection_title_label.text = "Apercu de la Collection"
	collection_section.add_child(collection_title_label)

	collection_subtitle_label = Label.new()
	collection_subtitle_label.name = "CollectionSubtitleLabel"
	collection_subtitle_label.text = "Objets visibles, verrouilles et mysteres"
	collection_section.add_child(collection_subtitle_label)

	collection_grid = HFlowContainer.new()
	collection_grid.name = "CollectionGrid"
	collection_section.add_child(collection_grid)

	collection_list = VBoxContainer.new()
	collection_list.name = "CollectionList"
	collection_list.add_theme_constant_override("separation", 6)
	collection_section.add_child(collection_list)

	# Separator bottom
	var sep_bottom := ColorRect.new()
	sep_bottom.name = "SeparatorBottom"
	sep_bottom.custom_minimum_size = Vector2(0, 1)
	sep_bottom.color = PALETTE.line
	layout.add_child(sep_bottom)

	# Bottom bar
	bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(bottom_bar)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "Retour"
	back_button.pressed.connect(func():
		var se := get_node_or_null("/root/ScreenEffects")
		var target: String = se.return_scene if se and se.return_scene != "" else "res://scenes/HubAntre.tscn"
		get_tree().change_scene_to_file(target)
	)
	bottom_bar.add_child(back_button)

func _apply_style() -> void:
	# Panel styles - parchment look
	_apply_panel_style(pass_panel, PALETTE.paper_warm)

	# Content panel - subtle border
	var content_panel := layout.get_node_or_null("ContentPanel")
	if content_panel:
		_apply_panel_style(content_panel, PALETTE.paper_dark)

	# Progress bar styling
	var pass_bg := StyleBoxFlat.new()
	pass_bg.bg_color = PALETTE.paper_dark
	pass_bg.border_color = PALETTE.accent_soft
	pass_bg.set_border_width_all(1)
	pass_bg.corner_radius_top_left = 4
	pass_bg.corner_radius_top_right = 4
	pass_bg.corner_radius_bottom_left = 4
	pass_bg.corner_radius_bottom_right = 4
	pass_progress.add_theme_stylebox_override("background", pass_bg)

	var pass_fill := StyleBoxFlat.new()
	pass_fill.bg_color = PALETTE.success
	pass_fill.corner_radius_top_left = 3
	pass_fill.corner_radius_top_right = 3
	pass_fill.corner_radius_bottom_left = 3
	pass_fill.corner_radius_bottom_right = 3
	pass_progress.add_theme_stylebox_override("fill", pass_fill)

func _apply_panel_style(panel: PanelContainer, fill_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = PALETTE.line
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _update_responsive_style() -> void:
	var viewport_size := get_viewport_rect().size
	compact_mode = viewport_size.x <= MOBILE_BREAKPOINT

	var margin_h := 16 if compact_mode else 32
	var margin_v := 36 if compact_mode else 44
	main_container.add_theme_constant_override("margin_left", margin_h)
	main_container.add_theme_constant_override("margin_top", margin_v)
	main_container.add_theme_constant_override("margin_right", margin_h)
	main_container.add_theme_constant_override("margin_bottom", margin_v)

	layout.add_theme_constant_override("separation", 10 if compact_mode else 14)
	header.add_theme_constant_override("separation", 10)
	collection_grid.add_theme_constant_override("h_separation", 6 if compact_mode else 8)
	collection_grid.add_theme_constant_override("v_separation", 6 if compact_mode else 8)
	collection_list.add_theme_constant_override("separation", 8)
	progress_list.add_theme_constant_override("separation", 6)
	recent_list.add_theme_constant_override("separation", 8)

	body_font_size = 12 if compact_mode else 15
	section_font_size = 15 if compact_mode else 19
	small_font_size = 10 if compact_mode else 12
	icon_tile_size = 28 if compact_mode else 36
	row_min_height = 44 if compact_mode else 52

	# Apply fonts
	if font_regular:
		_apply_font_recursive(self, font_regular, body_font_size)

	# Title styling
	if font_bold:
		title_label.add_theme_font_override("font", font_bold)
		pass_title_label.add_theme_font_override("font", font_bold)
		progress_title_label.add_theme_font_override("font", font_bold)
		recent_title_label.add_theme_font_override("font", font_bold)
		collection_title_label.add_theme_font_override("font", font_bold)
		glory_label.add_theme_font_override("font", font_bold)

	title_label.add_theme_font_size_override("font_size", 24 if compact_mode else 32)
	pass_title_label.add_theme_font_size_override("font_size", 14 if compact_mode else 17)
	progress_title_label.add_theme_font_size_override("font_size", section_font_size)
	recent_title_label.add_theme_font_size_override("font_size", section_font_size)
	collection_title_label.add_theme_font_size_override("font_size", section_font_size)
	progress_hint_label.add_theme_font_size_override("font_size", small_font_size)
	collection_subtitle_label.add_theme_font_size_override("font_size", small_font_size)
	glory_label.add_theme_font_size_override("font_size", small_font_size + 2)
	rank_label.add_theme_font_size_override("font_size", small_font_size + 1)
	pass_progress_label.add_theme_font_size_override("font_size", small_font_size)
	back_button.add_theme_font_size_override("font_size", body_font_size)

	# Ornament styling
	ornament_top.add_theme_font_size_override("font_size", 14 if compact_mode else 18)
	ornament_bottom.add_theme_font_size_override("font_size", 14 if compact_mode else 18)
	ornament_top.add_theme_color_override("font_color", PALETTE.accent_soft)
	ornament_bottom.add_theme_color_override("font_color", PALETTE.accent_soft)
	if font_regular:
		ornament_top.add_theme_font_override("font", font_regular)
		ornament_bottom.add_theme_font_override("font", font_regular)

	# Tab buttons sizing
	for tab_btn in [btn_progression, btn_recents, btn_collection]:
		tab_btn.custom_minimum_size = Vector2(0, 32 if compact_mode else 38)

	# Colors
	title_label.add_theme_color_override("font_color", PALETTE.celtic_gold)
	pass_title_label.add_theme_color_override("font_color", PALETTE.accent)
	progress_title_label.add_theme_color_override("font_color", PALETTE.accent)
	recent_title_label.add_theme_color_override("font_color", PALETTE.accent)
	collection_title_label.add_theme_color_override("font_color", PALETTE.accent)
	glory_label.add_theme_color_override("font_color", PALETTE.celtic_gold)
	rank_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	progress_hint_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	collection_subtitle_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	pass_progress_label.add_theme_color_override("font_color", PALETTE.ink_soft)

	# Back button styling
	_style_back_button()

func _style_back_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.paper_warm
	normal.border_color = PALETTE.accent_soft
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = PALETTE.paper_dark
	hover.border_color = PALETTE.accent

	var pressed := normal.duplicate()
	pressed.bg_color = PALETTE.accent_glow
	pressed.border_color = PALETTE.accent

	back_button.add_theme_stylebox_override("normal", normal)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_stylebox_override("pressed", pressed)
	back_button.add_theme_color_override("font_color", PALETTE.ink)
	back_button.add_theme_color_override("font_hover_color", PALETTE.accent)
	if font_regular:
		back_button.add_theme_font_override("font", font_regular)

func _apply_font_recursive(node: Node, font: Font, font_size: int) -> void:
	if node is Label:
		var lbl := node as Label
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", PALETTE.ink)
	if node is Button:
		var btn := node as Button
		btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", font_size)
	for child in node.get_children():
		_apply_font_recursive(child, font, font_size)

func _start_mist_animation() -> void:
	if not mist_layer:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(mist_layer, "modulate:a", 0.6, 4.0)
	tween.tween_property(mist_layer, "modulate:a", 1.0, 4.0)

func _populate_all() -> void:
	_refresh_header_and_pass()
	_populate_progress_list()
	_populate_recent_list()
	_populate_collection()

func _refresh_header_and_pass() -> void:
	title_label.text = "Collection"
	if compact_mode:
		glory_label.text = "Gloire %d" % glory_value
		rank_label.text = "Rang %s" % rank_value
	else:
		glory_label.text = "Gloire: %d" % glory_value
		rank_label.text = "Rang: %s" % rank_value

	pass_title_label.text = "Passe de Gloire"
	pass_progress.min_value = 0
	pass_progress.max_value = pass_max
	pass_progress.value = pass_value
	pass_progress_label.text = "Palier %d - %d / %d" % [int(pass_value / 10), pass_value, pass_max]

func _populate_progress_list() -> void:
	_clear_children(progress_list)
	for stat in PROGRESSION_STATS:
		var row := _create_progress_row(stat)
		progress_list.add_child(row)

func _create_progress_row(stat: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = str(stat.get("label", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(label, PALETTE.ink, body_font_size, true)
	row.add_child(label)

	var current: int = stat.get("current", 0)
	var max_val: int = stat.get("max", 1)
	var ratio := float(current) / float(max_val)

	# Mini progress bar
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(80 if compact_mode else 100, 12)
	row.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.color = PALETTE.paper_dark
	bar_container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = ratio
	bar_fill.color = PALETTE.accent_soft
	bar_container.add_child(bar_fill)

	var count_label := Label.new()
	count_label.text = "%d / %d" % [current, max_val]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(50 if compact_mode else 60, 0)
	_style_label(count_label, PALETTE.ink_soft, small_font_size)
	row.add_child(count_label)

	return row

func _populate_recent_list() -> void:
	_clear_children(recent_list)
	for item in SAMPLE_ACHIEVEMENTS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, row_min_height)
		row.add_theme_constant_override("separation", 12)

		var icon := _create_icon_tile(str(item.get("icon", "*")), false)
		row.add_child(icon)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 2)

		var title := Label.new()
		title.text = "%s  (%s)" % [str(item.get("title", "")), str(item.get("date", ""))]
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_label(title, PALETTE.ink, body_font_size, true)
		text_box.add_child(title)

		var desc := Label.new()
		desc.text = str(item.get("desc", ""))
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_label(desc, PALETTE.ink_soft, small_font_size)
		text_box.add_child(desc)

		row.add_child(text_box)
		recent_list.add_child(row)

func _populate_collection() -> void:
	collection_title_label.text = "Apercu de la Collection"
	collection_subtitle_label.text = "Objets visibles, verrouilles et mysteres"

	_clear_children(collection_grid)
	_clear_children(collection_list)
	for item in SAMPLE_COLLECTION:
		var is_hidden := bool(item.get("hidden", false))
		var is_locked := bool(item.get("locked", true))
		var icon_text := "?" if is_hidden else str(item.get("icon", "?"))
		var name_text := "???" if is_hidden else str(item.get("name", "Objet inconnu"))
		var req_text := "Condition: ???" if is_hidden else (
			"Debloque" if not is_locked else "Condition: %s" % str(item.get("req", ""))
		)

		collection_grid.add_child(_create_icon_tile(icon_text, is_locked))
		collection_list.add_child(_create_collection_row(icon_text, name_text, req_text, is_locked, is_hidden))

func _set_view(view_id: int) -> void:
	current_view = view_id
	progress_section.visible = (view_id == VIEW_PROGRESSION)
	recent_section.visible = (view_id == VIEW_RECENTS)
	collection_section.visible = (view_id == VIEW_COLLECTION)
	_style_tab_button(btn_progression, view_id == VIEW_PROGRESSION)
	_style_tab_button(btn_recents, view_id == VIEW_RECENTS)
	_style_tab_button(btn_collection, view_id == VIEW_COLLECTION)

func _style_tab_button(btn: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	if selected:
		normal.bg_color = PALETTE.paper_warm
		normal.border_color = PALETTE.accent
	else:
		normal.bg_color = PALETTE.paper
		normal.border_color = PALETTE.line
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = PALETTE.paper_dark
	hover.border_color = PALETTE.accent_soft

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", PALETTE.accent if selected else PALETTE.ink)
	btn.add_theme_color_override("font_hover_color", PALETTE.accent)
	if font_regular:
		btn.add_theme_font_override("font", font_regular)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _style_label(label: Label, color: Color, font_size: int, bold := false) -> void:
	var used_font: Font = font_regular
	if bold and font_bold != null:
		used_font = font_bold
	if used_font:
		label.add_theme_font_override("font", used_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size = Vector2(0, font_size + (6 if compact_mode else 8))

func _create_icon_tile(text_value: String, locked: bool) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(icon_tile_size, icon_tile_size)

	var style := StyleBoxFlat.new()
	if locked:
		style.bg_color = PALETTE.paper_dark
		style.border_color = PALETTE.locked
	else:
		style.bg_color = PALETTE.paper_warm
		style.border_color = PALETTE.accent_soft
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	_style_label(label, PALETTE.locked if locked else PALETTE.accent, small_font_size + 1, true)
	panel.add_child(label)
	return panel

func _create_collection_row(icon_text: String, name_text: String, req_text: String, locked: bool, hidden: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, row_min_height)
	row.add_theme_constant_override("separation", 12)

	var icon := _create_icon_tile(icon_text, locked)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(name_label, PALETTE.ink_soft if hidden else PALETTE.ink, body_font_size, true)
	text_box.add_child(name_label)

	var req_label := Label.new()
	req_label.text = req_text
	req_label.clip_text = true
	req_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(req_label, PALETTE.ink_faded if locked else PALETTE.success, small_font_size)
	text_box.add_child(req_label)

	row.add_child(text_box)
	return row
