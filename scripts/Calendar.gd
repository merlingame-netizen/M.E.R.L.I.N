extends Control
## =============================================================================
## CALENDRIER CELTIQUE - Style Parchemin Mystique Breton
## Design sobre et épuré, cohérent avec le menu principal
## =============================================================================

const FONT_REGULAR_PATH := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
const FONT_BOLD_PATH := "res://resources/fonts/morris/MorrisRomanBlack.ttf"
const MENU_SCENE_FALLBACK := "res://scenes/HubAntre.tscn"
const MOBILE_BREAKPOINT := 560.0

const TAB_EVENTS := 0
const TAB_STATS := 1

# Palette Parchemin Mystique Breton (cohérente avec MenuPrincipalReigns)
const PALETTE := {
	# Fond parchemin
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"paper_warm": Color(0.955, 0.930, 0.890),
	"mist": Color(0.94, 0.92, 0.88, 0.35),

	# Encres
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),

	# Accents bronze/or
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),

	# Saisons
	"spring": Color(0.45, 0.55, 0.35),
	"summer": Color(0.70, 0.58, 0.30),
	"autumn": Color(0.60, 0.40, 0.25),
	"winter": Color(0.40, 0.45, 0.50),

	# États événements
	"event_past": Color(0.55, 0.50, 0.45, 0.6),
	"event_today": Color(0.68, 0.55, 0.32),
	"event_future": Color(0.22, 0.18, 0.14),

	# Ombres
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.15),
}

const MONTH_NAMES := [
	"", "Janvier", "Fevrier", "Mars", "Avril", "Mai", "Juin",
	"Juillet", "Aout", "Septembre", "Octobre", "Novembre", "Decembre"
]

const SEASON_NAMES := {
	"spring": "Printemps",
	"summer": "Ete",
	"autumn": "Automne",
	"winter": "Hiver"
}

const MOON_PHASES := {
	"new": {"name": "Nouvelle Lune", "icon": "●", "power": 0.0},
	"waxing_crescent": {"name": "Premier Croissant", "icon": "☽", "power": 0.25},
	"first_quarter": {"name": "Premier Quartier", "icon": "◐", "power": 0.5},
	"waxing_gibbous": {"name": "Lune Gibbeuse", "icon": "◑", "power": 0.75},
	"full": {"name": "Pleine Lune", "icon": "○", "power": 1.0},
	"waning_gibbous": {"name": "Lune Decroissante", "icon": "◑", "power": 0.75},
	"last_quarter": {"name": "Dernier Quartier", "icon": "◐", "power": 0.5},
	"waning_crescent": {"name": "Dernier Croissant", "icon": "☾", "power": 0.25},
}

const CELTIC_FESTIVALS := {
	"samhain": {"month": 10, "day": 31, "name": "Samhain"},
	"yule": {"month": 12, "day": 21, "name": "Yule"},
	"imbolc": {"month": 2, "day": 1, "name": "Imbolc"},
	"ostara": {"month": 3, "day": 21, "name": "Ostara"},
	"beltane": {"month": 5, "day": 1, "name": "Beltane"},
	"litha": {"month": 6, "day": 21, "name": "Litha"},
	"lughnasadh": {"month": 8, "day": 1, "name": "Lughnasadh"},
	"mabon": {"month": 9, "day": 21, "name": "Mabon"},
}

const CALENDAR_EVENTS := [
	{"date": "01-05", "name": "Veillee des Menhirs", "desc": "Les pierres anciennes veillent sous les etoiles."},
	{"date": "01-21", "name": "Brume de l'Ankou", "desc": "La brume enveloppe les landes, l'Ankou rode."},
	{"date": "02-02", "name": "Serment des Sources", "desc": "Les sources sacrees murmurent des promesses anciennes."},
	{"date": "02-14", "name": "Lueur du Gui", "desc": "Les branches de gui brillent sous la lune."},
	{"date": "03-21", "name": "Ostara", "desc": "Equinoxe de printemps - les menhirs s'ouvrent au soleil."},
	{"date": "05-01", "name": "Beltane", "desc": "Les feux de mai illuminent les collines."},
	{"date": "06-21", "name": "Litha", "desc": "Solstice d'ete - la nuit la plus courte."},
	{"date": "08-01", "name": "Lughnasadh", "desc": "Fete des moissons et du dieu Lugh."},
	{"date": "09-21", "name": "Mabon", "desc": "Equinoxe d'automne - le voile s'amincit."},
	{"date": "10-31", "name": "Samhain", "desc": "Le voile entre les mondes est au plus fin."},
	{"date": "12-21", "name": "Yule", "desc": "Solstice d'hiver - la longue nuit."},
]

const ALL_ENDINGS := [
	{"title": "L'Epuisement", "gauge": "Vigueur", "direction": 0},
	{"title": "Le Surmenage", "gauge": "Vigueur", "direction": 100},
	{"title": "La Folie", "gauge": "Esprit", "direction": 0},
	{"title": "La Possession", "gauge": "Esprit", "direction": 100},
	{"title": "L'Exile", "gauge": "Faveur", "direction": 0},
	{"title": "La Tyrannie", "gauge": "Faveur", "direction": 100},
	{"title": "La Famine", "gauge": "Ressources", "direction": 0},
	{"title": "Le Pillage", "gauge": "Ressources", "direction": 100},
]

# UI Elements
var parchment_bg: ColorRect
var mist_layer: ColorRect
var main_card: PanelContainer
var wheel_container: Control
var event_panel: PanelContainer
var tabs_container: HBoxContainer
var events_tab_btn: Button
var stats_tab_btn: Button
var content_scroll: ScrollContainer
var events_section: VBoxContainer
var stats_section: VBoxContainer
var back_button: Button
var celtic_ornament_top: Label
var celtic_ornament_bottom: Label

var font_regular: Font
var font_bold: Font
var compact_mode := false
var current_tab := TAB_EVENTS

var current_date: Dictionary = {}
var current_season: String = "winter"
var current_day_of_year: int = 1
var next_event: Dictionary = {}
var meta_stats: Dictionary = {}
var current_moon_phase: String = "new"
var moon_power: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_determine_current_context()
	_load_meta_stats()
	_build_ui()
	_populate_all()
	_set_tab(TAB_EVENTS)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_play_entry_animation()


func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_BOLD_PATH):
		font_bold = load(FONT_BOLD_PATH)
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		font_regular = load(FONT_REGULAR_PATH)
	if font_regular == null:
		font_regular = font_bold
	if font_bold == null:
		font_bold = font_regular


func _determine_current_context() -> void:
	var today := Time.get_date_dict_from_system()
	current_date = {"year": today.year, "month": today.month, "day": today.day}
	current_season = _get_season_for_date(current_date.month)
	current_day_of_year = _get_day_of_year(current_date.month, current_date.day)
	next_event = _find_next_event()
	current_moon_phase = _calculate_moon_phase()
	moon_power = MOON_PHASES.get(current_moon_phase, {}).get("power", 0.0)


func _get_season_for_date(month: int) -> String:
	if month >= 11 or month <= 1:
		return "winter"
	elif month >= 2 and month <= 4:
		return "spring"
	elif month >= 5 and month <= 7:
		return "summer"
	return "autumn"


func _get_day_of_year(month: int, day: int) -> int:
	var days := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var total := 0
	for m in range(1, month):
		total += days[m]
	return total + day


func _find_next_event() -> Dictionary:
	var today_str: String = "%02d-%02d" % [current_date.month, current_date.day]
	for event in CALENDAR_EVENTS:
		if event.date >= today_str:
			return event
	return CALENDAR_EVENTS[0] if CALENDAR_EVENTS.size() > 0 else {}


func _calculate_moon_phase() -> String:
	var ref_year := 2000
	var ref_month := 1
	var ref_day := 6
	var days_since := _days_between(ref_year, ref_month, ref_day, current_date.year, current_date.month, current_date.day)
	var lunar_age := fmod(float(days_since), 29.53)
	if lunar_age < 0:
		lunar_age += 29.53
	var phase_idx := int(lunar_age / (29.53 / 8.0)) % 8
	var phases := ["new", "waxing_crescent", "first_quarter", "waxing_gibbous", "full", "waning_gibbous", "last_quarter", "waning_crescent"]
	return phases[phase_idx]


func _days_between(y1: int, m1: int, d1: int, y2: int, m2: int, d2: int) -> int:
	return _julian_day(y2, m2, d2) - _julian_day(y1, m1, d1)


func _julian_day(y: int, m: int, d: int) -> int:
	var a := (14 - m) / 12
	var yr := y + 4800 - a
	var mo := m + 12 * a - 3
	return d + (153 * mo + 2) / 5 + 365 * yr + yr / 4 - yr / 100 + yr / 400 - 32045


func _load_meta_stats() -> void:
	var merlin_store = get_node_or_null("/root/MerlinStore")
	if merlin_store and merlin_store.state.has("meta"):
		var meta = merlin_store.state.meta
		meta_stats = {
			"total_runs": meta.get("total_runs", 0),
			"total_cards_played": meta.get("total_cards_played", 0),
			"endings_seen": meta.get("endings_seen", []),
			"gloire_points": meta.get("gloire_points", 0),
		}
	else:
		meta_stats = {"total_runs": 0, "total_cards_played": 0, "endings_seen": [], "gloire_points": 0}


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	compact_mode = viewport_size.x < MOBILE_BREAKPOINT

	# Fond parchemin avec shader
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

	# Brume subtile
	mist_layer = ColorRect.new()
	mist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist_layer.color = PALETTE.mist
	mist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mist_layer)

	# Ornements celtiques
	_build_celtic_ornaments(viewport_size)

	# Carte principale
	_build_main_card(viewport_size)

	# Bouton retour
	_build_back_button(viewport_size)


func _build_celtic_ornaments(viewport_size: Vector2) -> void:
	var ornament_line := _create_celtic_line(35)

	celtic_ornament_top = Label.new()
	celtic_ornament_top.text = ornament_line
	celtic_ornament_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celtic_ornament_top.add_theme_color_override("font_color", PALETTE.ink_faded)
	celtic_ornament_top.add_theme_font_size_override("font_size", 14)
	celtic_ornament_top.size = Vector2(viewport_size.x, 30)
	celtic_ornament_top.position = Vector2(0, 35)
	celtic_ornament_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celtic_ornament_top)

	celtic_ornament_bottom = Label.new()
	celtic_ornament_bottom.text = ornament_line
	celtic_ornament_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celtic_ornament_bottom.add_theme_color_override("font_color", PALETTE.ink_faded)
	celtic_ornament_bottom.add_theme_font_size_override("font_size", 14)
	celtic_ornament_bottom.size = Vector2(viewport_size.x, 30)
	celtic_ornament_bottom.position = Vector2(0, viewport_size.y - 65)
	celtic_ornament_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celtic_ornament_bottom)


func _create_celtic_line(length: int) -> String:
	var line := ""
	var pattern := ["─", "•", "─", "─", "◆", "─", "─", "•", "─"]
	for i in range(length):
		line += pattern[i % pattern.size()]
	return line


func _build_main_card(viewport_size: Vector2) -> void:
	main_card = PanelContainer.new()
	var card_w := minf(520.0, viewport_size.x * 0.88)
	var card_h := minf(580.0, viewport_size.y * 0.78)
	main_card.size = Vector2(card_w, card_h)
	main_card.position = (viewport_size - main_card.size) / 2
	main_card.pivot_offset = main_card.size / 2

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PALETTE.paper_warm
	card_style.border_color = PALETTE.ink_faded
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.shadow_color = PALETTE.shadow
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 4)
	card_style.set_content_margin_all(20)
	main_card.add_theme_stylebox_override("panel", card_style)
	add_child(main_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main_card.add_child(vbox)

	# Titre
	var title := Label.new()
	title.text = "Calendrier Celtique"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 28 if not compact_mode else 22)
	title.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(title)

	# Sous-titre saison + lune
	var moon_info: Dictionary = MOON_PHASES.get(current_moon_phase, {})
	var subtitle := Label.new()
	subtitle.text = "%s  %s" % [SEASON_NAMES.get(current_season, ""), moon_info.get("icon", "●")]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_regular:
		subtitle.add_theme_font_override("font", font_regular)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", PALETTE.get(current_season, PALETTE.ink_soft))
	vbox.add_child(subtitle)

	# Séparateur
	var sep := _create_separator()
	vbox.add_child(sep)

	# Wheel container
	wheel_container = Control.new()
	wheel_container.custom_minimum_size = Vector2(0, 140 if not compact_mode else 100)
	wheel_container.draw.connect(_on_wheel_draw)
	vbox.add_child(wheel_container)

	# Prochain événement
	_build_next_event_panel(vbox)

	# Tabs
	_build_tabs(vbox)

	# Contenu scrollable
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(content_scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_vbox)

	events_section = VBoxContainer.new()
	events_section.add_theme_constant_override("separation", 6)
	content_vbox.add_child(events_section)

	stats_section = VBoxContainer.new()
	stats_section.add_theme_constant_override("separation", 8)
	content_vbox.add_child(stats_section)


func _create_separator() -> HBoxContainer:
	var sep := HBoxContainer.new()
	sep.alignment = BoxContainer.ALIGNMENT_CENTER
	sep.add_theme_constant_override("separation", 8)

	var left := ColorRect.new()
	left.color = PALETTE.line
	left.custom_minimum_size = Vector2(50, 1)
	sep.add_child(left)

	var diamond := Label.new()
	diamond.text = "◆"
	diamond.add_theme_color_override("font_color", PALETTE.accent)
	diamond.add_theme_font_size_override("font_size", 10)
	sep.add_child(diamond)

	var right := ColorRect.new()
	right.color = PALETTE.line
	right.custom_minimum_size = Vector2(50, 1)
	sep.add_child(right)

	return sep


func _build_next_event_panel(parent: VBoxContainer) -> void:
	event_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.paper_dark
	style.border_color = PALETTE.accent_soft
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	event_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(event_panel)

	var evbox := VBoxContainer.new()
	evbox.add_theme_constant_override("separation", 4)
	event_panel.add_child(evbox)

	var header := Label.new()
	header.text = "Prochain evenement"
	if font_regular:
		header.add_theme_font_override("font", font_regular)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", PALETTE.ink_soft)
	evbox.add_child(header)

	if not next_event.is_empty():
		var event_date := _parse_event_date(next_event.date)
		var date_lbl := Label.new()
		date_lbl.text = "%d %s" % [event_date.day, MONTH_NAMES[event_date.month]]
		if font_bold:
			date_lbl.add_theme_font_override("font", font_bold)
		date_lbl.add_theme_font_size_override("font_size", 14)
		date_lbl.add_theme_color_override("font_color", PALETTE.event_today)
		evbox.add_child(date_lbl)

		var name_lbl := Label.new()
		name_lbl.text = next_event.name
		if font_bold:
			name_lbl.add_theme_font_override("font", font_bold)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", PALETTE.ink)
		evbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = next_event.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font_regular:
			desc_lbl.add_theme_font_override("font", font_regular)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
		evbox.add_child(desc_lbl)


func _parse_event_date(date_str: String) -> Dictionary:
	var parts := date_str.split("-")
	if parts.size() >= 2:
		return {"month": int(parts[0]), "day": int(parts[1])}
	return {"month": 1, "day": 1}


func _build_tabs(parent: VBoxContainer) -> void:
	tabs_container = HBoxContainer.new()
	tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_container.add_theme_constant_override("separation", 12)
	parent.add_child(tabs_container)

	events_tab_btn = _create_tab_button("Evenements")
	events_tab_btn.pressed.connect(func(): _set_tab(TAB_EVENTS))
	tabs_container.add_child(events_tab_btn)

	stats_tab_btn = _create_tab_button("Statistiques")
	stats_tab_btn.pressed.connect(func(): _set_tab(TAB_STATS))
	tabs_container.add_child(stats_tab_btn)


func _create_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font_regular:
		btn.add_theme_font_override("font", font_regular)
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _build_back_button(viewport_size: Vector2) -> void:
	back_button = Button.new()
	back_button.text = "< Retour"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font_bold:
		back_button.add_theme_font_override("font", font_bold)
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.add_theme_color_override("font_color", PALETTE.ink)
	back_button.add_theme_color_override("font_hover_color", PALETTE.accent)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = PALETTE.paper_dark
	btn_style.border_color = PALETTE.ink_faded
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)
	btn_style.content_margin_left = 14
	btn_style.content_margin_right = 14
	back_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = PALETTE.accent_glow
	btn_hover.border_color = PALETTE.accent_soft
	back_button.add_theme_stylebox_override("hover", btn_hover)

	back_button.size = Vector2(110, 40)
	back_button.position = Vector2(28, viewport_size.y - 56)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)


# =============================================================================
# TABS & POPULATION
# =============================================================================

func _set_tab(tab: int) -> void:
	current_tab = tab
	events_section.visible = (tab == TAB_EVENTS)
	stats_section.visible = (tab == TAB_STATS)
	_style_tab_button(events_tab_btn, tab == TAB_EVENTS)
	_style_tab_button(stats_tab_btn, tab == TAB_STATS)


func _style_tab_button(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PALETTE.accent_glow if selected else Color(1, 1, 1, 0)
	style.border_color = PALETTE.accent if selected else PALETTE.ink_faded
	style.border_width_bottom = 1 if selected else 0
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", PALETTE.accent if selected else PALETTE.ink_soft)


func _populate_all() -> void:
	_populate_events()
	_populate_stats()
	wheel_container.queue_redraw()


func _populate_events() -> void:
	for child in events_section.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "%s %d" % [MONTH_NAMES[current_date.month].to_upper(), current_date.year]
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", PALETTE.accent)
	events_section.add_child(header)

	var current_month_str: String = "%02d" % current_date.month
	for event in CALENDAR_EVENTS:
		var event_month: String = event.date.substr(0, 2)
		if event_month == current_month_str:
			var row := _create_event_row(event)
			events_section.add_child(row)


func _create_event_row(event: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var event_date := _parse_event_date(event.date)
	var is_past := _is_date_past(event_date.month, event_date.day)
	var is_today := _is_date_today(event_date.month, event_date.day)

	var date_lbl := Label.new()
	date_lbl.text = "%02d" % event_date.day
	date_lbl.custom_minimum_size = Vector2(30, 0)
	if font_regular:
		date_lbl.add_theme_font_override("font", font_regular)
	date_lbl.add_theme_font_size_override("font_size", 12)
	if is_today:
		date_lbl.add_theme_color_override("font_color", PALETTE.event_today)
	elif is_past:
		date_lbl.add_theme_color_override("font_color", PALETTE.event_past)
	else:
		date_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
	row.add_child(date_lbl)

	var name_lbl := Label.new()
	name_lbl.text = event.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_today and font_bold:
		name_lbl.add_theme_font_override("font", font_bold)
	elif font_regular:
		name_lbl.add_theme_font_override("font", font_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	if is_today:
		name_lbl.add_theme_color_override("font_color", PALETTE.event_today)
	elif is_past:
		name_lbl.add_theme_color_override("font_color", PALETTE.event_past)
	else:
		name_lbl.add_theme_color_override("font_color", PALETTE.ink)
	row.add_child(name_lbl)

	var state := Label.new()
	state.text = "◆" if is_today else ("─" if is_past else "○")
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", PALETTE.event_today if is_today else PALETTE.ink_faded)
	row.add_child(state)

	return row


func _is_date_past(month: int, day: int) -> bool:
	if month < current_date.month:
		return true
	return month == current_date.month and day < current_date.day


func _is_date_today(month: int, day: int) -> bool:
	return month == current_date.month and day == current_date.day


func _populate_stats() -> void:
	for child in stats_section.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "Statistiques"
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", PALETTE.accent)
	stats_section.add_child(header)

	_add_stat_row("Runs", str(meta_stats.total_runs))
	_add_stat_row("Cartes jouees", str(meta_stats.total_cards_played))
	_add_stat_row("Fins vues", "%d / 8" % meta_stats.endings_seen.size())
	_add_stat_row("Points de Gloire", str(meta_stats.gloire_points))

	var endings_header := Label.new()
	endings_header.text = "Fins debloquees"
	if font_bold:
		endings_header.add_theme_font_override("font", font_bold)
	endings_header.add_theme_font_size_override("font_size", 14)
	endings_header.add_theme_color_override("font_color", PALETTE.ink)
	stats_section.add_child(endings_header)

	for ending in ALL_ENDINGS:
		var seen: bool = meta_stats.endings_seen.has(ending.title)
		var end_lbl := Label.new()
		end_lbl.text = ("[x] " if seen else "[ ] ") + ending.title
		if font_regular:
			end_lbl.add_theme_font_override("font", font_regular)
		end_lbl.add_theme_font_size_override("font_size", 12)
		end_lbl.add_theme_color_override("font_color", PALETTE.ink if seen else PALETTE.ink_faded)
		stats_section.add_child(end_lbl)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_regular:
		label.add_theme_font_override("font", font_regular)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", PALETTE.ink_soft)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_bold:
		value.add_theme_font_override("font", font_bold)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", PALETTE.accent)
	row.add_child(value)

	stats_section.add_child(row)


# =============================================================================
# WHEEL OF THE YEAR
# =============================================================================

func _on_wheel_draw() -> void:
	if not is_inside_tree():
		return

	var center := wheel_container.size / 2
	var radius := minf(center.x, center.y) - 12

	# Arcs des saisons
	var arc_width := 8.0
	var arc_radius := radius - arc_width / 2
	_draw_season_arc(center, arc_radius, arc_width, -PI/2, 0, "winter")
	_draw_season_arc(center, arc_radius, arc_width, 0, PI/2, "spring")
	_draw_season_arc(center, arc_radius, arc_width, PI/2, PI, "summer")
	_draw_season_arc(center, arc_radius, arc_width, PI, 3*PI/2, "autumn")

	# Cercle intérieur
	wheel_container.draw_arc(center, radius - 18, 0, TAU, 64, PALETTE.ink_faded, 1.0)

	# Marqueurs festivals
	for festival_id in CELTIC_FESTIVALS:
		var festival: Dictionary = CELTIC_FESTIVALS[festival_id]
		var angle := _date_to_angle(festival.month, festival.day)
		var pos := center + Vector2.from_angle(angle) * (radius - 6)
		wheel_container.draw_circle(pos, 3, PALETTE.accent)

	# Marqueur jour actuel
	var today_angle := _date_to_angle(current_date.month, current_date.day)
	var today_pos := center + Vector2.from_angle(today_angle) * (radius - 6)
	wheel_container.draw_circle(today_pos, 6, PALETTE.event_today)
	wheel_container.draw_circle(today_pos, 4, PALETTE.paper)

	# Lune au centre
	var moon_r := radius * 0.25
	var moon_info: Dictionary = MOON_PHASES.get(current_moon_phase, {})
	wheel_container.draw_circle(center, moon_r, PALETTE.ink_faded)
	wheel_container.draw_arc(center, moon_r, 0, TAU, 32, PALETTE.accent_soft, 1.5)


func _draw_season_arc(center: Vector2, radius: float, width: float, start: float, end: float, season: String) -> void:
	var color: Color = PALETTE.get(season, PALETTE.ink_soft)
	var is_current := (season == current_season)
	if is_current:
		color = color.lightened(0.15)
		width += 3
	wheel_container.draw_arc(center, radius, start, end, 32, color, width)


func _date_to_angle(month: int, day: int) -> float:
	var doy := _get_day_of_year(month, day)
	var samhain := _get_day_of_year(10, 31)
	var adjusted := (doy - samhain) % 365
	if adjusted < 0:
		adjusted += 365
	return -PI/2 + float(adjusted) / 365.0 * TAU


# =============================================================================
# ANIMATION & NAVIGATION
# =============================================================================

func _play_entry_animation() -> void:
	main_card.modulate.a = 0.0
	main_card.position.y += 30
	celtic_ornament_top.modulate.a = 0.0
	celtic_ornament_bottom.modulate.a = 0.0
	back_button.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(celtic_ornament_top, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(celtic_ornament_bottom, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(main_card, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(main_card, "position:y", main_card.position.y - 30, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(back_button, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)


func _on_back_pressed() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = se.return_scene if se and se.return_scene != "" else MENU_SCENE_FALLBACK
	var tween := create_tween()
	tween.tween_property(main_card, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): get_tree().change_scene_to_file(target))


func _on_viewport_resized() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	compact_mode = viewport_size.x < MOBILE_BREAKPOINT

	var card_w := minf(520.0, viewport_size.x * 0.88)
	var card_h := minf(580.0, viewport_size.y * 0.78)
	main_card.size = Vector2(card_w, card_h)
	main_card.position = (viewport_size - main_card.size) / 2

	celtic_ornament_top.size.x = viewport_size.x
	celtic_ornament_bottom.size.x = viewport_size.x
	celtic_ornament_bottom.position.y = viewport_size.y - 65

	back_button.position.y = viewport_size.y - 60

	wheel_container.queue_redraw()
