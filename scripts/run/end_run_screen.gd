## ═══════════════════════════════════════════════════════════════════════════════
## EndRunScreen — End-of-run results display (Bible s.5.3)
## ═══════════════════════════════════════════════════════════════════════════════
## Shows run summary after death or completion:
## - Cards played / MOS target
## - Life remaining (or death message)
## - Reputation changes per faction (delta display)
## - Oghams activated count
## - Anam earned (with death penalty factor shown)
## - Minigames played + average score
## - MOS (Mesure d'Opportunite de Survie) value
## Victory vs Death have different visual treatment.
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name EndRunScreen

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal hub_requested
signal faction_ending_chosen(faction: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const FACTION_LIST: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
const DEATH_CAP_CARDS: int = 30
const ANIM_DURATION: float = 0.6
const STAT_LINE_HEIGHT: int = 36
const SECTION_SPACING: int = 20
const PANEL_MARGIN: int = 32

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _run_data: Dictionary = {}
var _is_victory: bool = false
var _headless: bool = false
var _faction_choices: Array[String] = []

# UI references (built programmatically)
var _bg_panel: Panel = null
var _title_label: Label = null
var _stats_container: VBoxContainer = null
var _continue_button: Button = null
var _journey_map: JourneyMapDisplay = null
var _faction_panel: VBoxContainer = null


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(run_data: Dictionary, headless: bool = false) -> void:
	_run_data = run_data
	_is_victory = bool(run_data.get("victory", false))
	_headless = headless


func show_results(run_data: Dictionary) -> void:
	_run_data = run_data
	_is_victory = bool(run_data.get("victory", false))
	_build_ui()
	visible = true


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Clear previous children
	for child in get_children():
		child.queue_free()

	# Full-screen anchor
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Background panel
	_bg_panel = _create_bg_panel()
	add_child(_bg_panel)

	# Main layout
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PANEL_MARGIN)
	_bg_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SECTION_SPACING)
	margin.add_child(vbox)

	# Title
	_title_label = _create_title_label()
	vbox.add_child(_title_label)

	# Separator
	vbox.add_child(_create_separator())

	# Stats container
	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_stats_container)

	_populate_stats()

	# Journey map display (compact)
	_journey_map = JourneyMapDisplay.new()
	var story_log: Array = _run_data.get("story_log", [])
	_journey_map.setup(story_log, _is_victory)
	_journey_map.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(_journey_map)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Continue button
	_continue_button = _create_continue_button()
	vbox.add_child(_continue_button)


func _create_bg_panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _is_victory:
		style.bg_color = MerlinVisual.CRT_PALETTE["bg_deep"]
	else:
		style.bg_color = MerlinVisual.CRT_PALETTE["bg_death"]
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = _get_accent_color()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_title_label() -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _is_victory:
		label.text = "VICTOIRE"
		label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	else:
		var reason: String = str(_run_data.get("reason", "death"))
		match reason:
			"death":
				label.text = "FIN DU VOYAGE"
			"abandon":
				label.text = "ABANDON"
			_:
				label.text = "FIN DE RUN"
		label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["danger"])

	label.add_theme_font_size_override("font_size", 28)
	return label


func _create_separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", _make_line_style())
	return sep


func _create_continue_button() -> Button:
	var btn: Button = Button.new()
	btn.text = "Retour au Hub"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
	btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	btn.pressed.connect(_on_continue_pressed)

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = MerlinVisual.CRT_PALETTE["bg_panel"]
	style_normal.border_width_bottom = 2
	style_normal.border_width_top = 2
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_color = _get_accent_color()
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = MerlinVisual.CRT_PALETTE["bg_highlight"]
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn


# ═══════════════════════════════════════════════════════════════════════════════
# STATS POPULATION
# ═══════════════════════════════════════════════════════════════════════════════

func _populate_stats() -> void:
	var cards_played: int = int(_run_data.get("cards_played", 0))
	var mos_target: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_max", 25))
	_add_stat_line("Cartes jouees", "%d / %d" % [cards_played, mos_target])

	# Life
	var life: int = int(_run_data.get("life_essence", 0))
	var life_max: int = int(_run_data.get("life_max", 100))
	if _is_victory:
		_add_stat_line("Vie restante", "%d / %d" % [life, life_max], MerlinVisual.CRT_PALETTE["success"])
	else:
		_add_stat_line("Vie", "0 / %d — Essences taries" % life_max, MerlinVisual.CRT_PALETTE["danger"])

	# Faction rep deltas
	var faction_deltas: Dictionary = _run_data.get("faction_rep_delta", {})
	if not faction_deltas.is_empty():
		_add_section_header("Reputation")
		for faction in FACTION_LIST:
			var delta: float = float(faction_deltas.get(faction, 0.0))
			if absf(delta) > 0.01:
				var delta_text: String = _format_delta(delta)
				var delta_color: Color = _get_delta_color(delta)
				_add_stat_line("  %s" % faction.capitalize(), delta_text, delta_color)

	# Oghams
	var oghams_used: int = int(_run_data.get("oghams_used", 0))
	_add_stat_line("Oghams actives", str(oghams_used))

	# Minigames
	var minigames_played: int = int(_run_data.get("minigames_played", 0))
	var avg_score: float = float(_run_data.get("avg_minigame_score", 0.0))
	if minigames_played > 0:
		_add_stat_line("Minigames joues", "%d (score moy. %d%%)" % [minigames_played, int(avg_score)])
	else:
		_add_stat_line("Minigames joues", "0")

	# MOS value
	var mos_value: int = cards_played
	_add_stat_line("MOS", str(mos_value), MerlinVisual.CRT_PALETTE["cyan"])

	# Anam section
	_add_section_header("Anam gagne")
	var anam: int = int(_run_data.get("rewards", {}).get("anam", 0))
	var anam_color: Color = MerlinVisual.CRT_PALETTE["amber"]

	if _is_victory:
		_add_stat_line("  Anam total", "+%d" % anam, anam_color)
	else:
		# Show death penalty factor
		var penalty_ratio: float = minf(float(cards_played) / float(DEATH_CAP_CARDS), 1.0)
		var penalty_pct: int = int(penalty_ratio * 100.0)
		_add_stat_line("  Anam (avant penalite)", str(_compute_anam_before_penalty()), anam_color)
		_add_stat_line("  Penalite mort", "x%d%% (%d/%d cartes)" % [penalty_pct, cards_played, DEATH_CAP_CARDS], MerlinVisual.CRT_PALETTE["danger"])
		_add_stat_line("  Anam final", "+%d" % anam, anam_color)


func _add_stat_line(label_text: String, value_text: String, color: Color = Color.TRANSPARENT) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, STAT_LINE_HEIGHT)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var val_color: Color = color if color.a > 0.01 else MerlinVisual.CRT_PALETTE["phosphor"]
	val.add_theme_color_override("font_color", val_color)
	val.add_theme_font_size_override("font_size", 16)
	hbox.add_child(val)

	_stats_container.add_child(hbox)


func _add_section_header(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", _get_accent_color())
	lbl.add_theme_font_size_override("font_size", 18)
	_stats_container.add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# DATA ACCESSORS (pure functions for testability)
# ═══════════════════════════════════════════════════════════════════════════════

func get_title_text() -> String:
	if _title_label:
		return _title_label.text
	if _is_victory:
		return "VICTOIRE"
	var reason: String = str(_run_data.get("reason", "death"))
	match reason:
		"death":
			return "FIN DU VOYAGE"
		"abandon":
			return "ABANDON"
		_:
			return "FIN DE RUN"


func get_is_victory() -> bool:
	return _is_victory


func get_anam_earned() -> int:
	return int(_run_data.get("rewards", {}).get("anam", 0))


func get_death_penalty_ratio() -> float:
	if _is_victory:
		return 1.0
	var cards_played: int = int(_run_data.get("cards_played", 0))
	return minf(float(cards_played) / float(DEATH_CAP_CARDS), 1.0)


func get_cards_played() -> int:
	return int(_run_data.get("cards_played", 0))


func get_life_remaining() -> int:
	return int(_run_data.get("life_essence", 0))


func get_faction_deltas() -> Dictionary:
	return _run_data.get("faction_rep_delta", {})


func get_oghams_used() -> int:
	return int(_run_data.get("oghams_used", 0))


func get_minigames_played() -> int:
	return int(_run_data.get("minigames_played", 0))


func get_avg_minigame_score() -> float:
	return float(_run_data.get("avg_minigame_score", 0.0))


func get_run_data() -> Dictionary:
	return _run_data


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_accent_color() -> Color:
	if _is_victory:
		return MerlinVisual.CRT_PALETTE["phosphor"]
	return MerlinVisual.CRT_PALETTE["danger"]


func _format_delta(delta: float) -> String:
	if delta > 0:
		return "+%d" % int(delta)
	return "%d" % int(delta)


func _get_delta_color(delta: float) -> Color:
	if delta > 0:
		return MerlinVisual.CRT_PALETTE["success"]
	if delta < 0:
		return MerlinVisual.CRT_PALETTE["danger"]
	return MerlinVisual.CRT_PALETTE["phosphor_dim"]


func _compute_anam_before_penalty() -> int:
	## Compute the raw anam amount before death penalty is applied.
	var anam: int = MerlinConstants.ANAM_BASE_REWARD
	var minigames_won: int = int(_run_data.get("minigames_won", 0))
	var oghams_used: int = int(_run_data.get("oghams_used", 0))
	anam += minigames_won * MerlinConstants.ANAM_PER_MINIGAME
	anam += oghams_used * MerlinConstants.ANAM_PER_OGHAM
	return maxi(anam, 0)


func _make_line_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_bottom = 1
	style.border_color = MerlinVisual.CRT_PALETTE["line"]
	return style


func _on_continue_pressed() -> void:
	var endings: Array = _run_data.get("faction_endings_available", [])
	_faction_choices.clear()
	for f in endings:
		_faction_choices.append(str(f))

	if _faction_choices.size() == 0:
		hub_requested.emit()
	elif _faction_choices.size() == 1:
		# Single faction: auto-select, no UI needed
		faction_ending_chosen.emit(_faction_choices[0])
		hub_requested.emit()
	else:
		# 2+ factions: replace bottom area with choice panel
		_continue_button.hide()
		_show_faction_choice_panel(_faction_choices)


func _show_faction_choice_panel(factions: Array[String]) -> void:
	_faction_panel = VBoxContainer.new()
	_faction_panel.add_theme_constant_override("separation", 12)

	var title: Label = Label.new()
	title.text = "Vers qui vous tournez-vous ?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	title.add_theme_font_size_override("font_size", 20)
	_faction_panel.add_child(title)

	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_faction_panel.add_child(sep)

	for faction in factions:
		var btn: Button = Button.new()
		btn.text = faction.capitalize()
		btn.custom_minimum_size = Vector2(240, MerlinVisual.MIN_TOUCH_TARGET)
		btn.size_flags_horizontal = SIZE_SHRINK_CENTER
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
		btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = MerlinVisual.CRT_PALETTE["bg_panel"]
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = _get_accent_color()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		var style_hover: StyleBoxFlat = style.duplicate()
		style_hover.bg_color = MerlinVisual.CRT_PALETTE["bg_highlight"]
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.pressed.connect(_on_faction_btn_pressed.bind(faction))
		_faction_panel.add_child(btn)

	# Insert faction panel after continue button's parent vbox
	var parent: Node = _continue_button.get_parent()
	parent.add_child(_faction_panel)


func _on_faction_btn_pressed(faction: String) -> void:
	faction_ending_chosen.emit(faction)
	hub_requested.emit()
