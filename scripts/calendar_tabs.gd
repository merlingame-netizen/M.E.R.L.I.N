class_name CalendarTabs
extends RefCounted
## Extracted tab content rendering logic for Calendar.gd
## Handles: _set_tab, _style_tab_button, _populate_all, _populate_events,
##          _populate_stats, _populate_brumes, tooltips, reroll/lock actions

const MAX_EVENT_REROLLS: int = 3
const MAX_EVENT_LOCKS: int = 3

var cal: Control


func _init(calendar_node: Control) -> void:
	cal = calendar_node


func set_tab(tab: int) -> void:
	cal.current_tab = tab
	cal.events_section.visible = (tab == cal.TAB_EVENTS)
	cal.stats_section.visible = (tab == cal.TAB_STATS)
	cal.brumes_section.visible = (tab == cal.TAB_BRUMES)
	_style_tab_button(cal.events_tab_btn, tab == cal.TAB_EVENTS)
	_style_tab_button(cal.stats_tab_btn, tab == cal.TAB_STATS)
	_style_tab_button(cal.brumes_tab_btn, tab == cal.TAB_BRUMES)


func _style_tab_button(btn: Button, selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow if selected else Color(1, 1, 1, 0)
	style.border_color = MerlinVisual.CRT_PALETTE.amber if selected else MerlinVisual.CRT_PALETTE.border
	style.border_width_bottom = 1 if selected else 0
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber if selected else MerlinVisual.CRT_PALETTE.phosphor_dim)


func populate_all() -> void:
	_populate_events()
	_populate_stats()
	_populate_brumes()
	cal.wheel_container.queue_redraw()


func _populate_events() -> void:
	for child in cal.events_section.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "%s %d" % [cal.MONTH_NAMES[cal.current_date.month].to_upper(), cal.current_date.year]
	if cal.font_bold:
		header.add_theme_font_override("font", cal.font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	cal.events_section.add_child(header)

	var events: Array = cal.calendar_events_display if not cal.calendar_events_display.is_empty() else cal.CALENDAR_EVENTS
	var current_month_str: String = "%02d" % cal.current_date.month
	for event in events:
		var event_month: String = event.date.substr(0, 2)
		if event_month == current_month_str:
			var row: HBoxContainer = _create_event_row(event)
			cal.events_section.add_child(row)


func _create_event_row(event: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.tooltip_text = _build_event_tooltip(event)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var event_date: Dictionary = cal._parse_event_date(event.date)
	var is_past: bool = _is_date_past(event_date.month, event_date.day)
	var is_today: bool = _is_date_today(event_date.month, event_date.day)

	var date_lbl: Label = Label.new()
	date_lbl.text = "%02d" % event_date.day
	date_lbl.custom_minimum_size = Vector2(30, 0)
	if cal.font_regular:
		date_lbl.add_theme_font_override("font", cal.font_regular)
	date_lbl.add_theme_font_size_override("font_size", 12)
	if is_today:
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
	elif is_past:
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_past)
	else:
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	row.add_child(date_lbl)

	var name_lbl: Label = Label.new()
	name_lbl.text = event.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_today and cal.font_bold:
		name_lbl.add_theme_font_override("font", cal.font_bold)
	elif cal.font_regular:
		name_lbl.add_theme_font_override("font", cal.font_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	if is_today:
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
	elif is_past:
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_past)
	else:
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	row.add_child(name_lbl)

	var state: Label = Label.new()
	state.text = "\u25c6" if is_today else ("\u2500" if is_past else "\u25cb")
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today if is_today else MerlinVisual.CRT_PALETTE.border)
	row.add_child(state)

	return row


func _is_date_past(month: int, day: int) -> bool:
	if month < cal.current_date.month:
		return true
	return month == cal.current_date.month and day < cal.current_date.day


func _is_date_today(month: int, day: int) -> bool:
	return month == cal.current_date.month and day == cal.current_date.day


func _populate_stats() -> void:
	for child in cal.stats_section.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Statistiques"
	if cal.font_bold:
		header.add_theme_font_override("font", cal.font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	cal.stats_section.add_child(header)

	_add_stat_row("Runs", str(cal.meta_stats.total_runs))
	_add_stat_row("Cartes jouees", str(cal.meta_stats.total_cards_played))
	_add_stat_row("Fins vues", "%d / %d" % [cal.meta_stats.endings_seen.size(), cal.ALL_ENDINGS.size()])
	_add_stat_row("Points de Gloire", str(cal.meta_stats.gloire_points))

	var endings_header: Label = Label.new()
	endings_header.text = "Fins debloquees"
	if cal.font_bold:
		endings_header.add_theme_font_override("font", cal.font_bold)
	endings_header.add_theme_font_size_override("font_size", 14)
	endings_header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	cal.stats_section.add_child(endings_header)

	for ending in cal.ALL_ENDINGS:
		var seen: bool = cal.meta_stats.endings_seen.has(ending.title)
		var end_lbl: Label = Label.new()
		end_lbl.text = ("[x] " if seen else "[ ] ") + ending.title
		if cal.font_regular:
			end_lbl.add_theme_font_override("font", cal.font_regular)
		end_lbl.add_theme_font_size_override("font_size", 12)
		end_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor if seen else MerlinVisual.CRT_PALETTE.border)
		cal.stats_section.add_child(end_lbl)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cal.font_regular:
		label.add_theme_font_override("font", cal.font_regular)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	row.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if cal.font_bold:
		value.add_theme_font_override("font", cal.font_bold)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	row.add_child(value)

	cal.stats_section.add_child(row)


# =============================================================================
# CALENDRIER DES BRUMES
# =============================================================================

func _populate_brumes() -> void:
	for child in cal.brumes_section.get_children():
		child.queue_free()

	if not cal.has_brumes_upgrade:
		return

	var header: Label = Label.new()
	header.text = "Calendrier des Brumes"
	if cal.font_bold:
		header.add_theme_font_override("font", cal.font_bold)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	cal.brumes_section.add_child(header)

	var desc: Label = Label.new()
	desc.text = "Les %d prochains evenements reveles par les brumes..." % cal.BRUMES_LOOKAHEAD_EVENTS
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if cal.font_regular:
		desc.add_theme_font_override("font", cal.font_regular)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	cal.brumes_section.add_child(desc)

	var upcoming: Array = _get_upcoming_events(cal.BRUMES_LOOKAHEAD_EVENTS)
	if upcoming.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Aucun evenement a l'horizon..."
		if cal.font_regular:
			empty_lbl.add_theme_font_override("font", cal.font_regular)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
		cal.brumes_section.add_child(empty_lbl)
		return

	for ev in upcoming:
		var row: PanelContainer = _create_brumes_event_row(ev)
		cal.brumes_section.add_child(row)


func _get_upcoming_events(count: int) -> Array:
	## Return the next N events from today, wrapping to next year if needed.
	var today_str: String = "%02d-%02d" % [cal.current_date.month, cal.current_date.day]
	var future: Array = []
	var wrapped: Array = []

	for ev in cal.calendar_events_display:
		if ev.date >= today_str:
			future.append(ev)
		else:
			wrapped.append(ev)

	var combined: Array = future + wrapped
	return combined.slice(0, count)


func _create_brumes_event_row(event: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.tooltip_text = _build_event_tooltip(event)
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = iridescent_shader
		panel.material = mat
	else:
		style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var event_date: Dictionary = cal._parse_event_date(event.date)
	var date_lbl: Label = Label.new()
	date_lbl.text = "%d %s" % [event_date.day, cal.MONTH_NAMES[event_date.month].substr(0, 3)]
	date_lbl.custom_minimum_size = Vector2(55, 0)
	if cal.font_bold:
		date_lbl.add_theme_font_override("font", cal.font_bold)
	date_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	hbox.add_child(date_lbl)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl: Label = Label.new()
	name_lbl.text = event.name
	if cal.font_bold:
		name_lbl.add_theme_font_override("font", cal.font_bold)
	name_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	info.add_child(name_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = event.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if cal.font_regular:
		desc_lbl.add_theme_font_override("font", cal.font_regular)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	info.add_child(desc_lbl)

	# Reroll/Lock actions (only if upgrade active)
	if cal.has_brumes_upgrade:
		_add_brumes_actions(info, event)

	# Category icon
	var cat: String = event.get("category", "")
	var icon_text: String = "\u25cb"
	match cat:
		"sabbat": icon_text = "\u263d"
		"transition": icon_text = "\u25c6"
		"consequence": icon_text = "\u25c7"
		"secret": icon_text = "?"
	var icon_lbl: Label = Label.new()
	icon_lbl.text = icon_text
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
	hbox.add_child(icon_lbl)

	return panel


# =============================================================================
# TOOLTIPS & REROLL/LOCK
# =============================================================================

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
	var merlin_store: Node = cal.get_node_or_null("/root/MerlinStore")
	if merlin_store == null:
		return
	var run: Dictionary = merlin_store.state.get("run", {})
	var event_id: String = event.get("id", "")

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	parent.add_child(actions)

	# Lock button
	var locked: Array = run.get("event_locks", [])
	var is_locked: bool = locked.has(event_id)
	var lock_btn: Button = Button.new()
	lock_btn.text = "Verrouille" if is_locked else "Verrouiller"
	lock_btn.disabled = is_locked or (locked.size() >= MAX_EVENT_LOCKS and not is_locked)
	lock_btn.focus_mode = Control.FOCUS_NONE
	lock_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cal.font_regular:
		lock_btn.add_theme_font_override("font", cal.font_regular)
	lock_btn.add_theme_font_size_override("font_size", 11)
	lock_btn.pressed.connect(func():
		_on_lock_event(event_id)
	)
	actions.add_child(lock_btn)

	# Reroll button
	var rerolls_used: int = run.get("event_rerolls_used", 0)
	var reroll_btn: Button = Button.new()
	reroll_btn.text = "Reroll"
	reroll_btn.disabled = rerolls_used >= MAX_EVENT_REROLLS or is_locked
	reroll_btn.focus_mode = Control.FOCUS_NONE
	reroll_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cal.font_regular:
		reroll_btn.add_theme_font_override("font", cal.font_regular)
	reroll_btn.add_theme_font_size_override("font_size", 11)
	reroll_btn.pressed.connect(func():
		_on_reroll_event(event_id)
	)
	actions.add_child(reroll_btn)

	# Counter label
	var counter: Label = Label.new()
	counter.text = "(%d/%d)" % [rerolls_used, MAX_EVENT_REROLLS]
	if cal.font_regular:
		counter.add_theme_font_override("font", cal.font_regular)
	counter.add_theme_font_size_override("font_size", 10)
	counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	actions.add_child(counter)


func _on_lock_event(event_id: String) -> void:
	var merlin_store: Node = cal.get_node_or_null("/root/MerlinStore")
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
	var merlin_store: Node = cal.get_node_or_null("/root/MerlinStore")
	if merlin_store == null:
		return
	var run: Dictionary = merlin_store.state.get("run", {})
	var rerolls: int = run.get("event_rerolls_used", 0)
	if rerolls >= MAX_EVENT_REROLLS:
		return
	run["event_rerolls_used"] = rerolls + 1
	merlin_store.state["run"] = run
	SFXManager.play("click")
	_populate_brumes()
