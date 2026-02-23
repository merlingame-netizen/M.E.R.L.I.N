extends Control
## =============================================================================
## CALENDRIER CELTIQUE - Style Parchemin Mystique Breton
## Design sobre et épuré, cohérent avec le menu principal
## =============================================================================

const FONT_REGULAR_PATH_LEGACY := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"  # Legacy
const FONT_BOLD_PATH_LEGACY := "res://resources/fonts/morris/MorrisRomanBlack.ttf"  # Legacy
const MENU_SCENE_FALLBACK := "res://scenes/HubAntre.tscn"
const MOBILE_BREAKPOINT := 560.0

const TAB_EVENTS := 0
const TAB_STATS := 1
const TAB_BRUMES := 2
const EVENTS_JSON_PATH := "res://data/calendar_events.json"
const BRUMES_LOOKAHEAD_EVENTS := 7


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
	"new": {"name": "Nouvelle Lune", "icon": "\u25cf", "power": 0.0},
	"waxing_crescent": {"name": "Premier Croissant", "icon": "\u263d", "power": 0.25},
	"first_quarter": {"name": "Premier Quartier", "icon": "\u25d0", "power": 0.5},
	"waxing_gibbous": {"name": "Lune Gibbeuse", "icon": "\u25d1", "power": 0.75},
	"full": {"name": "Pleine Lune", "icon": "\u25cb", "power": 1.0},
	"waning_gibbous": {"name": "Lune Decroissante", "icon": "\u25d1", "power": 0.75},
	"last_quarter": {"name": "Dernier Quartier", "icon": "\u25d0", "power": 0.5},
	"waning_crescent": {"name": "Dernier Croissant", "icon": "\u263e", "power": 0.25},
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

# Scene nodes (@onready)
@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer
@onready var main_card: PanelContainer = $MainCard
@onready var wheel_container: Control = $MainCard/CardVBox/WheelContainer
@onready var event_panel: PanelContainer = $MainCard/CardVBox/EventPanel
@onready var tabs_container: HBoxContainer = $MainCard/CardVBox/TabsContainer
@onready var content_scroll: ScrollContainer = $MainCard/CardVBox/ContentScroll
@onready var events_section: VBoxContainer = $MainCard/CardVBox/ContentScroll/ContentVBox/EventsSection
@onready var stats_section: VBoxContainer = $MainCard/CardVBox/ContentScroll/ContentVBox/StatsSection
@onready var brumes_section: VBoxContainer = $MainCard/CardVBox/ContentScroll/ContentVBox/BrumesSection
@onready var back_button: Button = $BackButton
@onready var celtic_ornament_top: Label = $CelticOrnamentTop
@onready var celtic_ornament_bottom: Label = $CelticOrnamentBottom

# Dynamic nodes (created at runtime)
var events_tab_btn: Button
var stats_tab_btn: Button
var brumes_tab_btn: Button

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

## Events loaded from JSON (or fallback to CALENDAR_EVENTS)
var calendar_events_display: Array = []
var has_brumes_upgrade := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_load_events_from_json()
	_determine_current_context()
	_load_meta_stats()
	_configure_ui()
	_populate_all()
	_set_tab(TAB_EVENTS)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_play_entry_animation()


func _load_fonts() -> void:
	font_bold = MerlinVisual.get_font("title")
	font_regular = MerlinVisual.get_font("body")
	if font_regular == null:
		font_regular = font_bold
	if font_bold == null:
		font_bold = font_regular


func _load_events_from_json() -> void:
	if not FileAccess.file_exists(EVENTS_JSON_PATH):
		push_warning("Calendar: JSON not found at %s, using hardcoded fallback" % EVENTS_JSON_PATH)
		_use_fallback_events()
		return

	var file := FileAccess.open(EVENTS_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("Calendar: Cannot open %s, using fallback" % EVENTS_JSON_PATH)
		_use_fallback_events()
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("Calendar: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		_use_fallback_events()
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var raw_events: Array = data.get("events", [])
	if raw_events.is_empty():
		push_warning("Calendar: No events in JSON, using fallback")
		_use_fallback_events()
		return

	calendar_events_display.clear()
	for ev in raw_events:
		var display := _json_event_to_display(ev)
		if not display.is_empty():
			calendar_events_display.append(display)

	calendar_events_display.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.date < b.date
	)


func _json_event_to_display(ev: Dictionary) -> Dictionary:
	## Convert a JSON event entry to the display format used by _populate_events.
	## Returns empty dict for floating/window events that have no fixed date.
	var date_val = ev.get("date", null)
	if date_val == null or (date_val is String and date_val == "floating"):
		return {}

	var month := 0
	var day := 0
	if date_val is Dictionary:
		if date_val.has("window"):
			# Window events: use start date for display
			var w: Dictionary = date_val.window
			month = int(w.get("start_month", 0))
			day = int(w.get("start_day", 0))
		else:
			month = int(date_val.get("month", 0))
			day = int(date_val.get("day", 0))

	if month == 0 or day == 0:
		return {}

	return {
		"date": "%02d-%02d" % [month, day],
		"name": ev.get("name", ""),
		"desc": ev.get("text", ""),
		"id": ev.get("id", ""),
		"category": ev.get("category", ""),
		"tags": ev.get("tags", []),
		"effects": ev.get("effects", []),
		"visual": ev.get("visual", {}),
	}


func _use_fallback_events() -> void:
	calendar_events_display.clear()
	for ev in CALENDAR_EVENTS:
		calendar_events_display.append(ev.duplicate())


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
	var events: Array = calendar_events_display if not calendar_events_display.is_empty() else CALENDAR_EVENTS
	var today_str: String = "%02d-%02d" % [current_date.month, current_date.day]
	for event in events:
		if event.date >= today_str:
			return event
	return events[0] if events.size() > 0 else {}


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
	@warning_ignore("integer_division")
	var a := (14 - m) / 12
	var yr := y + 4800 - a
	var mo := m + 12 * a - 3
	@warning_ignore("integer_division")
	return d + (153 * mo + 2) / 5 + 365 * yr + yr / 4 - yr / 100 + yr / 400 - 32045


func get_active_festival() -> String:
	## Return the ID of the currently active Celtic festival (+-1 day tolerance), or "".
	for festival_id in CELTIC_FESTIVALS:
		var festival: Dictionary = CELTIC_FESTIVALS[festival_id]
		var fm: int = int(festival.get("month", 0))
		var fd: int = int(festival.get("day", 0))
		# Check today, yesterday, and tomorrow
		for offset in [-1, 0, 1]:
			var check_day: int = fd + offset
			var check_month: int = fm
			if check_day <= 0:
				check_month -= 1
				check_day = 28  # Approximate
			elif check_day > 31:
				check_month += 1
				check_day = 1
			if check_month == current_date.get("month", 0) and check_day == current_date.get("day", 0):
				return festival_id
	return ""


func get_all_events() -> Array:
	## Public accessor for other systems (EventAdapter, card generation).
	return calendar_events_display.duplicate()


func get_events_for_month(month: int) -> Array:
	## Return all display events for a specific month.
	var month_str: String = "%02d" % month
	var result: Array = []
	for ev in calendar_events_display:
		if ev.date.substr(0, 2) == month_str:
			result.append(ev)
	return result


func get_events_in_window(from_date: String, to_date: String) -> Array:
	## Return events between two dates (inclusive). Dates as "MM-DD".
	var result: Array = []
	for ev in calendar_events_display:
		if ev.date >= from_date and ev.date <= to_date:
			result.append(ev)
	return result


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
		var unlocked: Array = meta.get("talent_tree", {}).get("unlocked", [])
		has_brumes_upgrade = unlocked.has("calendrier_des_brumes")
	else:
		meta_stats = {"total_runs": 0, "total_cards_played": 0, "endings_seen": [], "gloire_points": 0}
		has_brumes_upgrade = false


# =============================================================================
# UI BUILDING
# =============================================================================

func _configure_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	compact_mode = viewport_size.x < MOBILE_BREAKPOINT

	# CRT terminal background (no paper shader — CRT post-process handles vignette/grain)
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_panel

	# Configure mist
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist

	# Configure celtic ornaments
	_configure_celtic_ornaments(viewport_size)

	# Configure main card
	_configure_main_card(viewport_size)

	# Configure back button
	_configure_back_button(viewport_size)


func _configure_celtic_ornaments(viewport_size: Vector2) -> void:
	var ornament_line := _create_celtic_line(35)

	celtic_ornament_top.text = ornament_line
	celtic_ornament_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	celtic_ornament_top.size = Vector2(viewport_size.x, 30)
	celtic_ornament_top.position = Vector2(0, 35)

	celtic_ornament_bottom.text = ornament_line
	celtic_ornament_bottom.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	celtic_ornament_bottom.size = Vector2(viewport_size.x, 30)
	celtic_ornament_bottom.position = Vector2(0, viewport_size.y - 65)


func _create_celtic_line(length: int) -> String:
	var line := ""
	var pattern := ["\u2500", "\u2022", "\u2500", "\u2500", "\u25c6", "\u2500", "\u2500", "\u2022", "\u2500"]
	for i in range(length):
		line += pattern[i % pattern.size()]
	return line


func _configure_main_card(viewport_size: Vector2) -> void:
	var card_w := minf(520.0, viewport_size.x * 0.88)
	var card_h := minf(580.0, viewport_size.y * 0.78)
	main_card.size = Vector2(card_w, card_h)
	main_card.position = (viewport_size - main_card.size) / 2
	main_card.pivot_offset = main_card.size / 2

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	card_style.border_color = MerlinVisual.CRT_PALETTE.border
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 4)
	card_style.set_content_margin_all(20)
	main_card.add_theme_stylebox_override("panel", card_style)

	# Style title
	var title_label: Label = $MainCard/CardVBox/TitleLabel
	if font_bold:
		title_label.add_theme_font_override("font", font_bold)
	title_label.add_theme_font_size_override("font_size", 28 if not compact_mode else 22)
	title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Style subtitle (season + moon)
	var subtitle_label: Label = $MainCard/CardVBox/SubtitleLabel
	var moon_info: Dictionary = MOON_PHASES.get(current_moon_phase, {})
	subtitle_label.text = "%s  %s" % [SEASON_NAMES.get(current_season, ""), moon_info.get("icon", "\u25cf")]
	if font_regular:
		subtitle_label.add_theme_font_override("font", font_regular)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get(current_season, MerlinVisual.CRT_PALETTE.phosphor_dim))

	# Style separator
	var sep_left: ColorRect = $MainCard/CardVBox/SeparatorContainer/SepLeft
	var sep_diamond: Label = $MainCard/CardVBox/SeparatorContainer/SepDiamond
	var sep_right: ColorRect = $MainCard/CardVBox/SeparatorContainer/SepRight
	sep_left.color = MerlinVisual.CRT_PALETTE.line
	sep_diamond.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	sep_right.color = MerlinVisual.CRT_PALETTE.line

	# Configure wheel
	wheel_container.custom_minimum_size = Vector2(0, 140 if not compact_mode else 100)
	wheel_container.draw.connect(_on_wheel_draw)

	# Configure next event panel
	_configure_event_panel()

	# Configure tabs (dynamic buttons)
	_configure_tabs()


func _configure_event_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	event_panel.add_theme_stylebox_override("panel", style)

	var evbox := VBoxContainer.new()
	evbox.add_theme_constant_override("separation", 4)
	event_panel.add_child(evbox)

	var header := Label.new()
	header.text = "Prochain evenement"
	if font_regular:
		header.add_theme_font_override("font", font_regular)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	evbox.add_child(header)

	if not next_event.is_empty():
		var event_date := _parse_event_date(next_event.date)
		var date_lbl := Label.new()
		date_lbl.text = "%d %s" % [event_date.day, MONTH_NAMES[event_date.month]]
		if font_bold:
			date_lbl.add_theme_font_override("font", font_bold)
		date_lbl.add_theme_font_size_override("font_size", 14)
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
		evbox.add_child(date_lbl)

		var name_lbl := Label.new()
		name_lbl.text = next_event.name
		if font_bold:
			name_lbl.add_theme_font_override("font", font_bold)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		evbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = next_event.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font_regular:
			desc_lbl.add_theme_font_override("font", font_regular)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		evbox.add_child(desc_lbl)


func _parse_event_date(date_str: String) -> Dictionary:
	var parts := date_str.split("-")
	if parts.size() >= 2:
		return {"month": int(parts[0]), "day": int(parts[1])}
	return {"month": 1, "day": 1}


func _configure_tabs() -> void:
	events_tab_btn = _create_tab_button("Evenements")
	events_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		_set_tab(TAB_EVENTS)
	)
	tabs_container.add_child(events_tab_btn)

	stats_tab_btn = _create_tab_button("Statistiques")
	stats_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		_set_tab(TAB_STATS)
	)
	tabs_container.add_child(stats_tab_btn)

	brumes_tab_btn = _create_tab_button("Brumes")
	brumes_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		_set_tab(TAB_BRUMES)
	)
	tabs_container.add_child(brumes_tab_btn)
	brumes_tab_btn.visible = has_brumes_upgrade


func _create_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font_regular:
		btn.add_theme_font_override("font", font_regular)
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _configure_back_button(viewport_size: Vector2) -> void:
	if font_bold:
		back_button.add_theme_font_override("font", font_bold)
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	back_button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	btn_style.border_color = MerlinVisual.CRT_PALETTE.border
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)
	btn_style.content_margin_left = 14
	btn_style.content_margin_right = 14
	back_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow
	btn_hover.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	back_button.add_theme_stylebox_override("hover", btn_hover)

	back_button.size = Vector2(110, 40)
	back_button.position = Vector2(28, viewport_size.y - 56)
	back_button.pressed.connect(_on_back_pressed)


# =============================================================================
# TABS & POPULATION
# =============================================================================

func _set_tab(tab: int) -> void:
	current_tab = tab
	events_section.visible = (tab == TAB_EVENTS)
	stats_section.visible = (tab == TAB_STATS)
	brumes_section.visible = (tab == TAB_BRUMES)
	_style_tab_button(events_tab_btn, tab == TAB_EVENTS)
	_style_tab_button(stats_tab_btn, tab == TAB_STATS)
	_style_tab_button(brumes_tab_btn, tab == TAB_BRUMES)


func _style_tab_button(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow if selected else Color(1, 1, 1, 0)
	style.border_color = MerlinVisual.CRT_PALETTE.amber if selected else MerlinVisual.CRT_PALETTE.border
	style.border_width_bottom = 1 if selected else 0
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber if selected else MerlinVisual.CRT_PALETTE.phosphor_dim)


func _populate_all() -> void:
	_populate_events()
	_populate_stats()
	_populate_brumes()
	wheel_container.queue_redraw()


func _populate_events() -> void:
	for child in events_section.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "%s %d" % [MONTH_NAMES[current_date.month].to_upper(), current_date.year]
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	events_section.add_child(header)

	var events: Array = calendar_events_display if not calendar_events_display.is_empty() else CALENDAR_EVENTS
	var current_month_str: String = "%02d" % current_date.month
	for event in events:
		var event_month: String = event.date.substr(0, 2)
		if event_month == current_month_str:
			var row := _create_event_row(event)
			events_section.add_child(row)


func _create_event_row(event: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.tooltip_text = _build_event_tooltip(event)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

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
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
	elif is_past:
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_past)
	else:
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
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
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
	elif is_past:
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_past)
	else:
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	row.add_child(name_lbl)

	var state := Label.new()
	state.text = "\u25c6" if is_today else ("\u2500" if is_past else "\u25cb")
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today if is_today else MerlinVisual.CRT_PALETTE.border)
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
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
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
	endings_header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	stats_section.add_child(endings_header)

	for ending in ALL_ENDINGS:
		var seen: bool = meta_stats.endings_seen.has(ending.title)
		var end_lbl := Label.new()
		end_lbl.text = ("[x] " if seen else "[ ] ") + ending.title
		if font_regular:
			end_lbl.add_theme_font_override("font", font_regular)
		end_lbl.add_theme_font_size_override("font_size", 12)
		end_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor if seen else MerlinVisual.CRT_PALETTE.border)
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
	label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font_bold:
		value.add_theme_font_override("font", font_bold)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	row.add_child(value)

	stats_section.add_child(row)


# =============================================================================
# CALENDRIER DES BRUMES
# =============================================================================

func _populate_brumes() -> void:
	for child in brumes_section.get_children():
		child.queue_free()

	if not has_brumes_upgrade:
		return

	var header := Label.new()
	header.text = "Calendrier des Brumes"
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	brumes_section.add_child(header)

	var desc := Label.new()
	desc.text = "Les %d prochains evenements reveles par les brumes..." % BRUMES_LOOKAHEAD_EVENTS
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_regular:
		desc.add_theme_font_override("font", font_regular)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	brumes_section.add_child(desc)

	var upcoming := _get_upcoming_events(BRUMES_LOOKAHEAD_EVENTS)
	if upcoming.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucun evenement a l'horizon..."
		if font_regular:
			empty_lbl.add_theme_font_override("font", font_regular)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
		brumes_section.add_child(empty_lbl)
		return

	for ev in upcoming:
		var row := _create_brumes_event_row(ev)
		brumes_section.add_child(row)


func _get_upcoming_events(count: int) -> Array:
	## Return the next N events from today, wrapping to next year if needed.
	var today_str: String = "%02d-%02d" % [current_date.month, current_date.day]
	var future: Array = []
	var wrapped: Array = []

	for ev in calendar_events_display:
		if ev.date >= today_str:
			future.append(ev)
		else:
			wrapped.append(ev)

	var combined: Array = future + wrapped
	return combined.slice(0, count)


func _create_brumes_event_row(event: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.tooltip_text = _build_event_tooltip(event)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)

	# Apply iridescent border if shader available
	var iridescent_shader: Shader = null
	if ResourceLoader.exists("res://shaders/iridescent_border.gdshader"):
		iridescent_shader = load("res://shaders/iridescent_border.gdshader")
	if iridescent_shader:
		style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
		style.set_border_width_all(2)
		var mat := ShaderMaterial.new()
		mat.shader = iridescent_shader
		panel.material = mat
	else:
		style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var event_date := _parse_event_date(event.date)
	var date_lbl := Label.new()
	date_lbl.text = "%d %s" % [event_date.day, MONTH_NAMES[event_date.month].substr(0, 3)]
	date_lbl.custom_minimum_size = Vector2(55, 0)
	if font_bold:
		date_lbl.add_theme_font_override("font", font_bold)
	date_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	hbox.add_child(date_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = event.name
	if font_bold:
		name_lbl.add_theme_font_override("font", font_bold)
	name_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = event.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_regular:
		desc_lbl.add_theme_font_override("font", font_regular)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	info.add_child(desc_lbl)

	# Reroll/Lock actions (only if upgrade active)
	if has_brumes_upgrade:
		_add_brumes_actions(info, event)

	# Category icon
	var cat: String = event.get("category", "")
	var icon_text := "\u25cb"
	match cat:
		"sabbat": icon_text = "\u263d"
		"transition": icon_text = "\u25c6"
		"consequence": icon_text = "\u25c7"
		"secret": icon_text = "?"
	var icon_lbl := Label.new()
	icon_lbl.text = icon_text
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	hbox.add_child(icon_lbl)

	return panel


# =============================================================================
# TOOLTIPS & REROLL/LOCK
# =============================================================================

const MAX_EVENT_REROLLS := 3
const MAX_EVENT_LOCKS := 3
const REROLL_AWEN_COST := 1

func _build_event_tooltip(event: Dictionary) -> String:
	var parts: Array = []
	parts.append(event.get("name", ""))
	var desc: String = event.get("desc", "")
	if desc != "":
		parts.append(desc)
	var cat: String = event.get("category", "")
	if cat != "":
		parts.append("Categorie: %s" % cat)
	var tags: Array = event.get("tags", [])
	if not tags.is_empty():
		parts.append("Tags: %s" % ", ".join(tags))
	var effects: Array = event.get("effects", [])
	if not effects.is_empty():
		var fx_lines: Array = []
		for fx in effects:
			var fx_type: String = str(fx.get("type", ""))
			var fx_target: String = str(fx.get("aspect", fx.get("target", "")))
			var fx_val: String = str(fx.get("direction", fx.get("amount", "")))
			if fx_type != "":
				fx_lines.append("%s %s %s" % [fx_type, fx_target, fx_val])
		if not fx_lines.is_empty():
			parts.append("Effets: %s" % ", ".join(fx_lines))
	return "\n".join(parts)


func _add_brumes_actions(parent: VBoxContainer, event: Dictionary) -> void:
	## Add Reroll/Lock buttons for a Brumes event row.
	var merlin_store = get_node_or_null("/root/MerlinStore")
	if merlin_store == null:
		return
	var run: Dictionary = merlin_store.state.get("run", {})
	var event_id: String = event.get("id", "")

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	parent.add_child(actions)

	# Lock button
	var locked: Array = run.get("event_locks", [])
	var is_locked: bool = locked.has(event_id)
	var lock_btn := Button.new()
	lock_btn.text = "Verrouille" if is_locked else "Verrouiller"
	lock_btn.disabled = is_locked or (locked.size() >= MAX_EVENT_LOCKS and not is_locked)
	lock_btn.focus_mode = Control.FOCUS_NONE
	lock_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font_regular:
		lock_btn.add_theme_font_override("font", font_regular)
	lock_btn.add_theme_font_size_override("font_size", 11)
	lock_btn.pressed.connect(func():
		_on_lock_event(event_id)
	)
	actions.add_child(lock_btn)

	# Reroll button
	var rerolls_used: int = run.get("event_rerolls_used", 0)
	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (1 Awen)"
	reroll_btn.disabled = rerolls_used >= MAX_EVENT_REROLLS or is_locked
	reroll_btn.focus_mode = Control.FOCUS_NONE
	reroll_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font_regular:
		reroll_btn.add_theme_font_override("font", font_regular)
	reroll_btn.add_theme_font_size_override("font_size", 11)
	reroll_btn.pressed.connect(func():
		_on_reroll_event(event_id)
	)
	actions.add_child(reroll_btn)

	# Counter label
	var counter := Label.new()
	counter.text = "(%d/%d)" % [rerolls_used, MAX_EVENT_REROLLS]
	if font_regular:
		counter.add_theme_font_override("font", font_regular)
	counter.add_theme_font_size_override("font_size", 10)
	counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	actions.add_child(counter)


func _on_lock_event(event_id: String) -> void:
	var merlin_store = get_node_or_null("/root/MerlinStore")
	if merlin_store == null:
		return
	var run: Dictionary = merlin_store.state.get("run", {})
	var locks: Array = run.get("event_locks", [])
	if locks.size() >= MAX_EVENT_LOCKS or locks.has(event_id):
		return
	locks.append(event_id)
	run["event_locks"] = locks
	merlin_store.state["run"] = run
	SFXManager.play("click")
	_populate_brumes()


func _on_reroll_event(_event_id: String) -> void:
	var merlin_store = get_node_or_null("/root/MerlinStore")
	if merlin_store == null:
		return
	var run: Dictionary = merlin_store.state.get("run", {})
	var rerolls: int = run.get("event_rerolls_used", 0)
	if rerolls >= MAX_EVENT_REROLLS:
		return
	# Check Awen cost
	var awen: int = run.get("awen", 0)
	if awen < REROLL_AWEN_COST:
		return
	run["awen"] = awen - REROLL_AWEN_COST
	run["event_rerolls_used"] = rerolls + 1
	merlin_store.state["run"] = run
	SFXManager.play("click")
	_populate_brumes()


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
	wheel_container.draw_arc(center, radius - 18, 0, TAU, 64, MerlinVisual.CRT_PALETTE.border, 1.0)

	# Marqueurs festivals
	for festival_id in CELTIC_FESTIVALS:
		var festival: Dictionary = CELTIC_FESTIVALS[festival_id]
		var angle := _date_to_angle(festival.month, festival.day)
		var pos := center + Vector2.from_angle(angle) * (radius - 6)
		wheel_container.draw_circle(pos, 3, MerlinVisual.CRT_PALETTE.amber)

	# Marqueur jour actuel
	var today_angle := _date_to_angle(current_date.month, current_date.day)
	var today_pos := center + Vector2.from_angle(today_angle) * (radius - 6)
	wheel_container.draw_circle(today_pos, 6, MerlinVisual.CRT_PALETTE.event_today)
	wheel_container.draw_circle(today_pos, 4, MerlinVisual.CRT_PALETTE.bg_panel)

	# Lune au centre
	var moon_r := radius * 0.25
	var moon_info: Dictionary = MOON_PHASES.get(current_moon_phase, {})
	wheel_container.draw_circle(center, moon_r, MerlinVisual.CRT_PALETTE.border)
	wheel_container.draw_arc(center, moon_r, 0, TAU, 32, MerlinVisual.CRT_PALETTE.amber_dim, 1.5)


func _draw_season_arc(center: Vector2, radius: float, width: float, start: float, end: float, season: String) -> void:
	var color: Color = MerlinVisual.CRT_PALETTE.get(season, MerlinVisual.CRT_PALETTE.phosphor_dim)
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

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await get_tree().process_frame
		pca.reveal(celtic_ornament_top, {"duration": 0.4, "block_size": 10})
		pca.reveal(celtic_ornament_bottom, {"duration": 0.4, "block_size": 10})
		await get_tree().create_timer(0.2).timeout
		# Slide main_card into position while pixel revealing
		var tween := create_tween()
		tween.tween_property(main_card, "position:y", main_card.position.y - 30, 0.5).set_ease(Tween.EASE_OUT)
		pca.reveal(main_card, {"duration": 0.4, "block_size": 8})
		pca.reveal(back_button, {"duration": 0.3, "block_size": 8})
	else:
		var tween := create_tween()
		tween.tween_property(celtic_ornament_top, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(celtic_ornament_bottom, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(main_card, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(main_card, "position:y", main_card.position.y - 30, 0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(back_button, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)


func _on_back_pressed() -> void:
	SFXManager.play("click")
	var se := get_node_or_null("/root/ScreenEffects")
	var target: String = se.return_scene if se and se.return_scene != "" else MENU_SCENE_FALLBACK
	var pca_back: Node = get_node_or_null("/root/PixelContentAnimator")
	if pca_back:
		pca_back.dissolve(main_card, {"duration": 0.25, "block_size": 10})
		await get_tree().create_timer(0.3).timeout
		PixelTransition.transition_to(target)
	else:
		var tween := create_tween()
		tween.tween_property(main_card, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): PixelTransition.transition_to(target))


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
