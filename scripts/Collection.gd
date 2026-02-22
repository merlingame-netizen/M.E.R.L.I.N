extends Control
## Collection - Style Parchemin Celtique
## Hauts faits, progression et collection d'objets

const FONT_REGULAR_PATH := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
const FONT_BOLD_PATH := "res://resources/fonts/morris/MorrisRomanBlack.ttf"
const MOBILE_BREAKPOINT := 560.0

const VIEW_PROGRESSION := 0
const VIEW_RECENTS := 1
const VIEW_COLLECTION := 2


const CELTIC_ORNAMENT := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25c6", "\u2500", "\u2500", "\u2022", "\u2500"]

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

var store: Node  # MerlinStore reference

var font_regular: Font
var font_bold: Font
var compact_mode := false
var current_view := VIEW_PROGRESSION

var glory_value := 0
var rank_value := "Novice"
var pass_value := 0
var pass_max := 100

var body_font_size := 14
var section_font_size := 18
var small_font_size := 12
var icon_tile_size := 32
var row_min_height := 48

# Scene nodes (@onready)
@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer
@onready var ornament_top: Label = $OrnamentTop
@onready var ornament_bottom: Label = $OrnamentBottom
@onready var main_container: MarginContainer = $MainContainer
@onready var layout: VBoxContainer = $MainContainer/Layout
@onready var header: HBoxContainer = $MainContainer/Layout/Header
@onready var title_label: Label = $MainContainer/Layout/Header/TitleLabel
@onready var glory_label: Label = $MainContainer/Layout/Header/StatsVBox/GloryLabel
@onready var rank_label: Label = $MainContainer/Layout/Header/StatsVBox/RankLabel
@onready var pass_panel: PanelContainer = $MainContainer/Layout/PassPanel
@onready var pass_title_label: Label = $MainContainer/Layout/PassPanel/PassVBox/PassTitleLabel
@onready var pass_progress: ProgressBar = $MainContainer/Layout/PassPanel/PassVBox/PassProgress
@onready var pass_progress_label: Label = $MainContainer/Layout/PassPanel/PassVBox/PassProgressLabel
@onready var view_tabs: HBoxContainer = $MainContainer/Layout/ViewTabs
@onready var btn_progression: Button = $MainContainer/Layout/ViewTabs/BtnProgression
@onready var btn_recents: Button = $MainContainer/Layout/ViewTabs/BtnRecents
@onready var btn_collection: Button = $MainContainer/Layout/ViewTabs/BtnCollection
@onready var content_scroll: ScrollContainer = $MainContainer/Layout/ContentPanel/ContentScroll
@onready var content_stack: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack
@onready var progress_section: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/ProgressSection
@onready var progress_title_label: Label = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/ProgressSection/ProgressTitleLabel
@onready var progress_hint_label: Label = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/ProgressSection/ProgressHintLabel
@onready var progress_list: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/ProgressSection/ProgressList
@onready var recent_section: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/RecentSection
@onready var recent_title_label: Label = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/RecentSection/RecentTitleLabel
@onready var recent_list: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/RecentSection/RecentList
@onready var collection_section: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/CollectionSection
@onready var collection_title_label: Label = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/CollectionSection/CollectionTitleLabel
@onready var collection_subtitle_label: Label = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/CollectionSection/CollectionSubtitleLabel
@onready var collection_grid: HFlowContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/CollectionSection/CollectionGrid
@onready var collection_list: VBoxContainer = $MainContainer/Layout/ContentPanel/ContentScroll/ContentStack/CollectionSection/CollectionList
@onready var bottom_bar: HBoxContainer = $MainContainer/Layout/BottomBar
@onready var back_button: Button = $MainContainer/Layout/BottomBar/BackButton

func _ready() -> void:
	store = get_node_or_null("/root/MerlinStore")
	_load_real_data()
	_load_fonts()
	_configure_ui()
	_apply_style()
	_update_responsive_style()
	_populate_all()
	_set_view(VIEW_PROGRESSION)
	_start_mist_animation()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _load_real_data() -> void:
	"""Load meta-progression data from store if available."""
	if not store:
		return
	var meta: Dictionary = store.state.get("meta", {})
	glory_value = int(meta.get("gloire_points", 0))
	rank_value = _rank_from_gloire(glory_value)
	pass_value = glory_value % 100
	pass_max = 100


func _rank_from_gloire(gloire: int) -> String:
	if gloire >= 1000: return "Archidruide"
	if gloire >= 500: return "Druide"
	if gloire >= 200: return "Ovate"
	if gloire >= 100: return "Barde"
	if gloire >= 50: return "Eclaireur"
	if gloire >= 20: return "Apprenti"
	return "Novice"


func _get_real_progression_stats() -> Array:
	if not store:
		return PROGRESSION_STATS
	var meta: Dictionary = store.state.get("meta", {})
	var endings_seen: Array = meta.get("endings_seen", [])
	var unlocked_talents: Array = meta.get("talent_tree", {}).get("unlocked", [])
	var skills_unlocked: Array = store.state.get("bestiole", {}).get("skills_unlocked", [])
	var total_runs: int = int(meta.get("total_runs", 0))
	var total_cards: int = int(meta.get("total_cards_played", 0))
	var total_essence: int = _count_total_essence()
	return [
		{"label": "Fins vues", "current": endings_seen.size(), "max": 16},
		{"label": "Oghams", "current": skills_unlocked.size(), "max": 18},
		{"label": "Talents", "current": unlocked_talents.size(), "max": 28},
		{"label": "Runs", "current": total_runs, "max": 50},
		{"label": "Cartes", "current": total_cards, "max": 500},
		{"label": "Essences", "current": total_essence, "max": 999},
	]


func _count_total_essence() -> int:
	if not store:
		return 0
	var essence: Dictionary = store.state.get("meta", {}).get("essence", {})
	var total: int = 0
	for elem in essence:
		total += int(essence[elem])
	return total


func _get_real_achievements() -> Array:
	"""Get discovered endings as 'recent achievements'."""
	if not store:
		return SAMPLE_ACHIEVEMENTS
	var endings_seen: Array = store.state.get("meta", {}).get("endings_seen", [])
	if endings_seen.is_empty():
		return [{"title": "Aucune fin decouverte", "desc": "Completez votre premiere run", "date": "", "icon": "?"}]
	var result: Array = []
	for i in range(mini(endings_seen.size(), 5)):
		var idx: int = endings_seen.size() - 1 - i
		var title: String = str(endings_seen[idx])
		result.append({"title": title, "desc": _get_ending_desc(title), "date": "", "icon": title.left(1)})
	return result


func _get_ending_desc(ending_title: String) -> String:
	"""Find the description/condition for an ending by title."""
	# Victory endings
	for key in MerlinConstants.TRIADE_VICTORY_ENDINGS:
		if MerlinConstants.TRIADE_VICTORY_ENDINGS[key].get("title", "") == ending_title:
			return str(MerlinConstants.TRIADE_VICTORY_ENDINGS[key].get("condition", "Victoire"))
	# Life essence depletion
	if ending_title == "Essences Epuisees":
		return "Essences de vie taries"
	return "Fin decouverte"


func _get_real_collection() -> Array:
	"""Build collection from endings + Oghams with real unlock state."""
	var items: Array = []
	var endings_seen: Array = []
	var skills_unlocked: Array = []
	if store:
		endings_seen = store.state.get("meta", {}).get("endings_seen", [])
		skills_unlocked = store.state.get("bestiole", {}).get("skills_unlocked", [])

	# Victory endings (no more 12 chute endings — Phase 43)
	for key in MerlinConstants.TRIADE_VICTORY_ENDINGS:
		var ending: Dictionary = MerlinConstants.TRIADE_VICTORY_ENDINGS[key]
		var title: String = str(ending.get("title", ""))
		var discovered: bool = endings_seen.has(title)
		items.append({
			"icon": title.left(1) if discovered else "?",
			"name": title if discovered else "???",
			"req": str(ending.get("condition", "")) if discovered else "???",
			"locked": not discovered,
			"hidden": not discovered,
		})

	# Secret ending placeholder
	items.append({
		"icon": "?", "name": "???", "req": "???",
		"locked": true, "hidden": true,
	})

	# 18 Oghams
	for key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[key]
		var name_val: String = str(spec.get("name", key))
		var discovered: bool = skills_unlocked.has(key) or MerlinConstants.OGHAM_STARTER_SKILLS.has(key)
		items.append({
			"icon": str(spec.get("unicode", "\u2726")) if discovered else "?",
			"name": name_val if discovered else "???",
			"req": str(spec.get("tree", "")) + " | " + str(spec.get("description", "")) if discovered else "???",
			"locked": not discovered,
			"hidden": not discovered,
			"ogham_key": key,
		})

	return items

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

func _configure_ui() -> void:
	# CRT terminal background
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_panel

	# Configure mist + ornaments
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist
	ornament_top.text = "".join(CELTIC_ORNAMENT)
	ornament_bottom.text = "".join(CELTIC_ORNAMENT)

	# Configure separator colors
	var sep_top: ColorRect = $MainContainer/Layout/SepTop
	var sep_bottom: ColorRect = $MainContainer/Layout/SepBottom
	sep_top.color = MerlinVisual.CRT_PALETTE.line
	sep_bottom.color = MerlinVisual.CRT_PALETTE.line

	# Wire tab button signals
	btn_progression.pressed.connect(func():
		SFXManager.play("click")
		_set_view(VIEW_PROGRESSION)
	)
	btn_recents.pressed.connect(func():
		SFXManager.play("click")
		_set_view(VIEW_RECENTS)
	)
	btn_collection.pressed.connect(func():
		SFXManager.play("click")
		_set_view(VIEW_COLLECTION)
	)

	# Wire back button
	back_button.pressed.connect(func():
		SFXManager.play("click")
		var se := get_node_or_null("/root/ScreenEffects")
		var target: String = se.return_scene if se and se.return_scene != "" else "res://scenes/HubAntre.tscn"
		PixelTransition.transition_to(target)
	)

func _apply_style() -> void:
	# Panel styles - parchment look
	_apply_panel_style(pass_panel, MerlinVisual.CRT_PALETTE.bg_panel)

	# Content panel - subtle border
	var content_panel := layout.get_node_or_null("ContentPanel")
	if content_panel:
		_apply_panel_style(content_panel, MerlinVisual.CRT_PALETTE.bg_dark)

	# Progress bar styling
	var pass_bg := StyleBoxFlat.new()
	pass_bg.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	pass_bg.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	pass_bg.set_border_width_all(1)
	pass_bg.corner_radius_top_left = 4
	pass_bg.corner_radius_top_right = 4
	pass_bg.corner_radius_bottom_left = 4
	pass_bg.corner_radius_bottom_right = 4
	pass_progress.add_theme_stylebox_override("background", pass_bg)

	var pass_fill := StyleBoxFlat.new()
	pass_fill.bg_color = MerlinVisual.CRT_PALETTE.success
	pass_fill.corner_radius_top_left = 3
	pass_fill.corner_radius_top_right = 3
	pass_fill.corner_radius_bottom_left = 3
	pass_fill.corner_radius_bottom_right = 3
	pass_progress.add_theme_stylebox_override("fill", pass_fill)

func _apply_panel_style(panel: PanelContainer, fill_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = MerlinVisual.CRT_PALETTE.line
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
	ornament_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	ornament_bottom.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	if font_regular:
		ornament_top.add_theme_font_override("font", font_regular)
		ornament_bottom.add_theme_font_override("font", font_regular)

	# Tab buttons sizing
	for tab_btn in [btn_progression, btn_recents, btn_collection]:
		tab_btn.custom_minimum_size = Vector2(0, 32 if compact_mode else 38)

	# Colors
	title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	pass_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	progress_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	recent_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	collection_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	glory_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	rank_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	progress_hint_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	collection_subtitle_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	pass_progress_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	# Back button styling
	_style_back_button()

func _style_back_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	normal.border_color = MerlinVisual.CRT_PALETTE.amber_dim
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
	hover.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	hover.border_color = MerlinVisual.CRT_PALETTE.amber

	var pressed := normal.duplicate()
	pressed.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow
	pressed.border_color = MerlinVisual.CRT_PALETTE.amber

	back_button.add_theme_stylebox_override("normal", normal)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_stylebox_override("pressed", pressed)
	back_button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	back_button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)
	if font_regular:
		back_button.add_theme_font_override("font", font_regular)

func _apply_font_recursive(node: Node, font: Font, font_size: int) -> void:
	if node is Label:
		var lbl := node as Label
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
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
	var stats: Array = _get_real_progression_stats()
	for stat in stats:
		var row := _create_progress_row(stat)
		progress_list.add_child(row)

func _create_progress_row(stat: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = str(stat.get("label", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(label, MerlinVisual.CRT_PALETTE.phosphor, body_font_size, true)
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
	bar_bg.color = MerlinVisual.CRT_PALETTE.bg_dark
	bar_container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = ratio
	bar_fill.color = MerlinVisual.CRT_PALETTE.amber_dim
	bar_container.add_child(bar_fill)

	var count_label := Label.new()
	count_label.text = "%d / %d" % [current, max_val]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size = Vector2(50 if compact_mode else 60, 0)
	_style_label(count_label, MerlinVisual.CRT_PALETTE.phosphor_dim, small_font_size)
	row.add_child(count_label)

	return row

func _populate_recent_list() -> void:
	_clear_children(recent_list)
	var achievements: Array = _get_real_achievements()
	for item in achievements:
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
		_style_label(title, MerlinVisual.CRT_PALETTE.phosphor, body_font_size, true)
		text_box.add_child(title)

		var desc := Label.new()
		desc.text = str(item.get("desc", ""))
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_label(desc, MerlinVisual.CRT_PALETTE.phosphor_dim, small_font_size)
		text_box.add_child(desc)

		row.add_child(text_box)
		recent_list.add_child(row)

func _populate_collection() -> void:
	collection_title_label.text = "Fins & Oghams"
	collection_subtitle_label.text = "Fins decouvertes et Oghams debloques"

	_clear_children(collection_grid)
	_clear_children(collection_list)
	var collection_items: Array = _get_real_collection()
	for item in collection_items:
		var is_hidden := bool(item.get("hidden", false))
		var is_locked := bool(item.get("locked", true))
		var icon_text := "?" if is_hidden else str(item.get("icon", "?"))
		var name_text := "???" if is_hidden else str(item.get("name", "Objet inconnu"))
		var req_text := "Condition: ???" if is_hidden else (
			"Debloque" if not is_locked else "Condition: %s" % str(item.get("req", ""))
		)

		var ogham_key: String = str(item.get("ogham_key", ""))
		if not ogham_key.is_empty() and not is_hidden:
			collection_grid.add_child(_create_ogham_icon_tile(ogham_key, is_locked))
		else:
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
		normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		normal.border_color = MerlinVisual.CRT_PALETTE.amber
	else:
		normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		normal.border_color = MerlinVisual.CRT_PALETTE.line
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	hover.border_color = MerlinVisual.CRT_PALETTE.amber_dim

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber if selected else MerlinVisual.CRT_PALETTE.phosphor)
	btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)
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
		style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
		style.border_color = MerlinVisual.CRT_PALETTE.locked
	else:
		style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
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
	_style_label(label, MerlinVisual.CRT_PALETTE.locked if locked else MerlinVisual.CRT_PALETTE.amber, small_font_size + 1, true)
	panel.add_child(label)
	return panel

func _create_ogham_icon_tile(ogham_key: String, locked: bool) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(icon_tile_size, icon_tile_size)
	var style := StyleBoxFlat.new()
	if locked:
		style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
		style.border_color = MerlinVisual.CRT_PALETTE.locked
	else:
		style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var icon := PixelOghamIcon.new()
	icon.setup(ogham_key, icon_tile_size - 8.0)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2(4, 4)
	if not locked:
		icon.reveal(true)
	else:
		icon.modulate.a = 0.3
		icon.reveal(true)
	panel.add_child(icon)
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
	_style_label(name_label, MerlinVisual.CRT_PALETTE.phosphor_dim if hidden else MerlinVisual.CRT_PALETTE.phosphor, body_font_size, true)
	text_box.add_child(name_label)

	var req_label := Label.new()
	req_label.text = req_text
	req_label.clip_text = true
	req_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(req_label, MerlinVisual.CRT_PALETTE.border if locked else MerlinVisual.CRT_PALETTE.success, small_font_size)
	text_box.add_child(req_label)

	row.add_child(text_box)
	return row
