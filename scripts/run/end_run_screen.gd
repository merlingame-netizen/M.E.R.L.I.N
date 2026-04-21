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
const TYPEWRITER_CHAR_DELAY: float = 0.025
const STAGGER_DELAY: float = 0.12

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _run_data: Dictionary = {}
var _is_victory: bool = false
var _headless: bool = false
var _faction_choices: Array[String] = []
var _ending_text: String = ""

# UI references (built programmatically)
var _bg_panel: Panel = null
var _title_label: Label = null
var _narrative_label: RichTextLabel = null
var _stats_container: VBoxContainer = null
var _anam_label: Label = null
var _continue_button: Button = null
var _journey_map: JourneyMapDisplay = null
var _faction_panel: VBoxContainer = null
var _anim_items: Array[Control] = []


# ═══════════════════════════════════════════════════════════════════════════════
# AUTOLOAD WIRING
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var gfc: Node = get_node_or_null("/root/GameFlow")
	if gfc and gfc.has_method("get_last_run_data"):
		var data: Dictionary = gfc.get_last_run_data()
		if not data.is_empty():
			if gfc.has_method("wire_end_screen"):
				gfc.wire_end_screen(self)
			show_results(data)
			return
	push_warning("[EndRunScreen] No GameFlow or empty run data — waiting for manual setup()")


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(run_data: Dictionary, headless: bool = false) -> void:
	_run_data = run_data
	_is_victory = bool(run_data.get("victory", false))
	_headless = headless
	_ending_text = str(run_data.get("ending_text", ""))


func show_results(run_data: Dictionary) -> void:
	_run_data = run_data
	_is_victory = bool(run_data.get("victory", false))
	_ending_text = str(run_data.get("ending_text", ""))
	_build_ui()
	visible = true
	_animate_reveal()


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_anim_items.clear()

	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_bg_panel = _create_bg_panel()
	add_child(_bg_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var m: int = MerlinVisual.responsive_size(PANEL_MARGIN)
	margin.add_theme_constant_override("margin_left", m)
	margin.add_theme_constant_override("margin_right", m)
	margin.add_theme_constant_override("margin_top", m)
	margin.add_theme_constant_override("margin_bottom", m)
	_bg_panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SECTION_SPACING)
	scroll.add_child(vbox)

	_title_label = _create_title_label()
	_title_label.modulate.a = 0.0
	_anim_items.append(_title_label)
	vbox.add_child(_title_label)

	var sep1: HSeparator = _create_separator()
	sep1.modulate.a = 0.0
	_anim_items.append(sep1)
	vbox.add_child(sep1)

	# Narrative ending text
	var ending: String = _ending_text
	if ending.is_empty():
		var reason: String = str(_run_data.get("reason", ""))
		ending = _get_fallback_ending(reason)
	_narrative_label = _create_narrative_label(ending)
	_narrative_label.modulate.a = 0.0
	_anim_items.append(_narrative_label)
	vbox.add_child(_narrative_label)

	var sep2: HSeparator = _create_separator()
	sep2.modulate.a = 0.0
	_anim_items.append(sep2)
	vbox.add_child(sep2)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_stats_container)
	_populate_stats()

	var sep3: HSeparator = _create_separator()
	sep3.modulate.a = 0.0
	_anim_items.append(sep3)
	vbox.add_child(sep3)

	_journey_map = JourneyMapDisplay.new()
	var story_log: Array = _run_data.get("story_log", [])
	_journey_map.setup(story_log, _is_victory)
	_journey_map.custom_minimum_size = Vector2(0, MerlinVisual.responsive_size(160))
	_journey_map.modulate.a = 0.0
	_anim_items.append(_journey_map)
	vbox.add_child(_journey_map)

	var sep4: HSeparator = _create_separator()
	sep4.modulate.a = 0.0
	_anim_items.append(sep4)
	vbox.add_child(sep4)

	_anam_label = _create_anam_display()
	_anam_label.modulate.a = 0.0
	_anim_items.append(_anam_label)
	vbox.add_child(_anam_label)

	_continue_button = _create_continue_button()
	_continue_button.modulate.a = 0.0
	_anim_items.append(_continue_button)
	vbox.add_child(_continue_button)


func _create_bg_panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var style: StyleBoxFlat = MerlinVisual.make_card_panel_style(true)
	if _is_victory:
		style.bg_color = MerlinVisual.CRT_PALETTE["bg_deep"]
	else:
		style.bg_color = MerlinVisual.CRT_PALETTE["bg_death"]
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
			"death": label.text = "FIN DU VOYAGE"
			"abandon": label.text = "ABANDON"
			_: label.text = "FIN DE RUN"
		label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["danger"])
	MerlinVisual.apply_responsive_font(label, 28, "terminal")
	return label


func _create_narrative_label(text: String) -> RichTextLabel:
	var rtl: RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled = false
	rtl.text = text
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		rtl.add_theme_font_override("normal_font", font)
	rtl.add_theme_font_size_override("normal_font_size", MerlinVisual.responsive_size(15))
	rtl.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	return rtl


func _get_fallback_ending(reason: String) -> String:
	match reason:
		"death":
			return "Les tenebres t'enveloppent doucement. Le monde celtique s'estompe, mais ton ame persiste, gravee dans les racines de Broceliande. Tu reviendras."
		"abandon":
			return "Tu quittes le sentier, portant avec toi les echos de ce qui aurait pu etre. Les esprits murmurent ton nom dans la brume."
		"hard_max":
			return "Le voyage touche a sa fin. Les chemins se referment, les etoiles s'alignent vers un nouvel horizon. Il est temps de rentrer a l'antre."
		_:
			return "Le vent tourne. Une page se ferme dans le grand livre des Runes. Une autre s'ouvrira bientot."


func _create_separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", _make_line_style())
	return sep


func _create_anam_display() -> Label:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var anam: int = int(_run_data.get("rewards", {}).get("anam", 0))
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if _is_victory:
		label.text = "ANAM  +%d" % anam
		label.add_theme_color_override("font_color", pal["amber_bright"])
	else:
		var cards: int = int(_run_data.get("cards_played", 0))
		var pct: int = int(minf(float(cards) / float(DEATH_CAP_CARDS), 1.0) * 100.0)
		label.text = "ANAM  +%d  (x%d%%)" % [anam, pct]
		label.add_theme_color_override("font_color", pal["amber"])
	MerlinVisual.apply_responsive_font(label, 24, "terminal")
	return label


func _create_continue_button() -> Button:
	var btn: Button = Button.new()
	btn.text = "Retour au Hub"
	btn.custom_minimum_size = Vector2(MerlinVisual.responsive_size(240), MerlinVisual.MIN_TOUCH_TARGET)
	btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	MerlinVisual.apply_celtic_option_theme(btn, _get_accent_color())
	MerlinVisual.apply_responsive_font(btn, 17, "terminal")
	btn.pressed.connect(_on_continue_pressed)
	return btn


# ═══════════════════════════════════════════════════════════════════════════════
# STATS POPULATION
# ═══════════════════════════════════════════════════════════════════════════════

func _populate_stats() -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var cards_played: int = int(_run_data.get("cards_played", 0))
	var mos_target: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_max", 25))
	_add_stat_line("Cartes jouees", "%d / %d" % [cards_played, mos_target])

	var life: int = int(_run_data.get("life_essence", 0))
	var life_max: int = int(_run_data.get("life_max", 100))
	if _is_victory:
		_add_stat_line("Vie restante", "%d / %d" % [life, life_max], pal["success"])
	else:
		_add_stat_line("Vie", "0 / %d" % life_max, pal["danger"])

	var faction_deltas: Dictionary = _run_data.get("faction_rep_delta", {})
	if not faction_deltas.is_empty():
		_add_section_header("Reputation")
		for faction in FACTION_LIST:
			var delta: float = float(faction_deltas.get(faction, 0.0))
			if absf(delta) > 0.01:
				_add_stat_line("  %s" % faction.capitalize(), _format_delta(delta), _get_delta_color(delta))

	var oghams_used: int = int(_run_data.get("oghams_used", 0))
	_add_stat_line("Runes activees", str(oghams_used))

	var minigames_played: int = int(_run_data.get("minigames_played", 0))
	var avg_score: float = float(_run_data.get("avg_minigame_score", 0.0))
	if minigames_played > 0:
		_add_stat_line("Minigames", "%d (moy. %d%%)" % [minigames_played, int(avg_score)])
	else:
		_add_stat_line("Minigames", "0")

	_add_stat_line("MOS", str(cards_played), pal["cyan"])


func _add_stat_line(label_text: String, value_text: String, color: Color = Color.TRANSPARENT) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, MerlinVisual.responsive_size(STAT_LINE_HEIGHT))
	hbox.modulate.a = 0.0
	_anim_items.append(hbox)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	MerlinVisual.apply_responsive_font(lbl, 15, "terminal")
	hbox.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var val_color: Color = color if color.a > 0.01 else MerlinVisual.CRT_PALETTE["phosphor"]
	val.add_theme_color_override("font_color", val_color)
	MerlinVisual.apply_responsive_font(val, 15, "terminal")
	hbox.add_child(val)

	_stats_container.add_child(hbox)


func _add_section_header(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", _get_accent_color())
	lbl.modulate.a = 0.0
	_anim_items.append(lbl)
	MerlinVisual.apply_responsive_font(lbl, 17, "terminal")
	_stats_container.add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

func _animate_reveal() -> void:
	if _headless or _anim_items.is_empty():
		for item in _anim_items:
			item.modulate.a = 1.0
		return

	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")

	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)

	for i in _anim_items.size():
		tw.tween_property(_anim_items[i], "modulate:a", 1.0, ANIM_DURATION).set_delay(float(i) * STAGGER_DELAY)

	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(SFXManager):
			SFXManager.play("success" if _is_victory else "neutral")
	)


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
		faction_ending_chosen.emit(_faction_choices[0])
		hub_requested.emit()
	else:
		_continue_button.hide()
		_show_faction_choice_panel(_faction_choices)


func _show_faction_choice_panel(factions: Array[String]) -> void:
	_faction_panel = VBoxContainer.new()
	_faction_panel.add_theme_constant_override("separation", 12)

	var title: Label = Label.new()
	title.text = "Vers qui vous tournez-vous ?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_bright"])
	MerlinVisual.apply_responsive_font(title, 20, "terminal")
	_faction_panel.add_child(title)

	_faction_panel.add_child(_create_separator())

	for faction in factions:
		var btn: Button = Button.new()
		btn.text = faction.capitalize()
		btn.custom_minimum_size = Vector2(MerlinVisual.responsive_size(240), MerlinVisual.MIN_TOUCH_TARGET)
		btn.size_flags_horizontal = SIZE_SHRINK_CENTER
		MerlinVisual.apply_celtic_option_theme(btn, _get_accent_color())
		MerlinVisual.apply_responsive_font(btn, 17, "terminal")
		btn.pressed.connect(_on_faction_btn_pressed.bind(faction))
		_faction_panel.add_child(btn)

	var parent: Node = _continue_button.get_parent()
	parent.add_child(_faction_panel)

	if is_instance_valid(SFXManager):
		SFXManager.play("magic_reveal")


func _on_faction_btn_pressed(faction: String) -> void:
	faction_ending_chosen.emit(faction)
	hub_requested.emit()
