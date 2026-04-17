extends Control
## =============================================================================
## CALENDRIER CELTIQUE - Style Parchemin Mystique Breton
## Design sobre et épuré, cohérent avec le menu principal
## =============================================================================

const FONT_REGULAR_PATH_LEGACY := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"  # Legacy
const FONT_BOLD_PATH_LEGACY := "res://resources/fonts/morris/MorrisRomanBlack.ttf"  # Legacy
const MENU_SCENE_FALLBACK := "res://scenes/HubAntre.tscn"

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
	{"title": "Essences Epuisees", "condition": "Vie", "direction": 0},
	{"title": "Harmonie Retrouvee", "condition": "Victoire", "direction": 100},
	{"title": "Victoire Amere", "condition": "Victoire", "direction": 100},
	{"title": "Le Prix Paye", "condition": "Victoire", "direction": 100},
	{"title": "Transcendance", "condition": "Faction", "direction": 100},
	{"title": "Abandon", "condition": "MOS", "direction": 0},
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

## Extracted module helpers (RefCounted)
var ui_helper: CalendarUI
var tabs_helper: CalendarTabs


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_load_events_from_json()
	_determine_current_context()
	_load_meta_stats()
	ui_helper = CalendarUI.new(self)
	tabs_helper = CalendarTabs.new(self)
	ui_helper.configure_ui()
	tabs_helper.populate_all()
	tabs_helper.set_tab(TAB_EVENTS)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_responsive_layout()
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


func _parse_event_date(date_str: String) -> Dictionary:
	var parts := date_str.split("-")
	if parts.size() >= 2:
		return {"month": int(parts[0]), "day": int(parts[1])}
	return {"month": 1, "day": 1}


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
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	if mr:
		compact_mode = mr.is_mobile
	else:
		compact_mode = viewport_size.x < 560.0

	var card_w: float = minf(520.0, viewport_size.x * 0.88)
	if mr:
		card_w = mr.get_content_width(viewport_size, 520.0)
	var card_h := minf(580.0, viewport_size.y * 0.78)
	main_card.size = Vector2(card_w, card_h)
	main_card.position = (viewport_size - main_card.size) / 2

	celtic_ornament_top.size.x = viewport_size.x
	celtic_ornament_bottom.size.x = viewport_size.x
	celtic_ornament_bottom.position.y = viewport_size.y - 65

	back_button.position.y = viewport_size.y - 60

	# Apply safe area margins
	if mr:
		var safe_top: float = mr.get_safe_margin_top()
		var safe_btm: float = mr.get_safe_margin_bottom()
		if safe_top > 0:
			main_card.position.y = maxf(main_card.position.y, safe_top + 8.0)
		if safe_btm > 0:
			back_button.position.y = viewport_size.y - 60 - safe_btm
			celtic_ornament_bottom.position.y = viewport_size.y - 65 - safe_btm
		mr.apply_touch_margins(back_button)

	wheel_container.queue_redraw()
