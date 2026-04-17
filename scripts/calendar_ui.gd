class_name CalendarUI
extends RefCounted
## Extracted UI configuration logic for Calendar.gd
## Handles: _configure_ui, _configure_celtic_ornaments, _configure_main_card,
##          _configure_event_panel, _configure_tabs, _configure_back_button

var cal: Control


func _init(calendar_node: Control) -> void:
	cal = calendar_node


func configure_ui() -> void:
	var viewport_size: Vector2 = cal.get_viewport().get_visible_rect().size
	var mr: Node = cal.get_node_or_null("/root/MerlinResponsive")
	if mr:
		cal.compact_mode = mr.is_mobile
	else:
		cal.compact_mode = viewport_size.x < 560.0

	# CRT terminal background (no paper shader — CRT post-process handles vignette/grain)
	cal.parchment_bg.material = null
	cal.parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_panel

	# Configure mist
	cal.mist_layer.color = MerlinVisual.CRT_PALETTE.mist

	# Configure celtic ornaments
	_configure_celtic_ornaments(viewport_size)

	# Configure main card
	_configure_main_card(viewport_size)

	# Configure back button
	_configure_back_button(viewport_size)


func _configure_celtic_ornaments(viewport_size: Vector2) -> void:
	var ornament_line: String = _create_celtic_line(35)

	cal.celtic_ornament_top.text = ornament_line
	cal.celtic_ornament_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	cal.celtic_ornament_top.size = Vector2(viewport_size.x, 30)
	cal.celtic_ornament_top.position = Vector2(0, 35)

	cal.celtic_ornament_bottom.text = ornament_line
	cal.celtic_ornament_bottom.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
	cal.celtic_ornament_bottom.size = Vector2(viewport_size.x, 30)
	cal.celtic_ornament_bottom.position = Vector2(0, viewport_size.y - 65)


func _create_celtic_line(length: int) -> String:
	var line: String = ""
	var pattern: Array = ["\u2500", "\u2022", "\u2500", "\u2500", "\u25c6", "\u2500", "\u2500", "\u2022", "\u2500"]
	for i in range(length):
		line += pattern[i % pattern.size()]
	return line


func _configure_main_card(viewport_size: Vector2) -> void:
	var card_w: float = minf(520.0, viewport_size.x * 0.88)
	var card_h: float = minf(580.0, viewport_size.y * 0.78)
	cal.main_card.size = Vector2(card_w, card_h)
	cal.main_card.position = (viewport_size - cal.main_card.size) / 2
	cal.main_card.pivot_offset = cal.main_card.size / 2

	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	card_style.border_color = MerlinVisual.CRT_PALETTE.border
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 4)
	card_style.set_content_margin_all(20)
	cal.main_card.add_theme_stylebox_override("panel", card_style)

	# Style title
	var title_label: Label = cal.main_card.get_node("CardVBox/TitleLabel")
	if cal.font_bold:
		title_label.add_theme_font_override("font", cal.font_bold)
	title_label.add_theme_font_size_override("font_size", 28 if not cal.compact_mode else 22)
	title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Style subtitle (season + moon)
	var subtitle_label: Label = cal.main_card.get_node("CardVBox/SubtitleLabel")
	var moon_info: Dictionary = cal.MOON_PHASES.get(cal.current_moon_phase, {})
	subtitle_label.text = "%s  %s" % [cal.SEASON_NAMES.get(cal.current_season, ""), moon_info.get("icon", "\u25cf")]
	if cal.font_regular:
		subtitle_label.add_theme_font_override("font", cal.font_regular)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get(cal.current_season, MerlinVisual.CRT_PALETTE.phosphor_dim))

	# Style separator
	var sep_left: ColorRect = cal.main_card.get_node("CardVBox/SeparatorContainer/SepLeft")
	var sep_diamond: Label = cal.main_card.get_node("CardVBox/SeparatorContainer/SepDiamond")
	var sep_right: ColorRect = cal.main_card.get_node("CardVBox/SeparatorContainer/SepRight")
	sep_left.color = MerlinVisual.CRT_PALETTE.line
	sep_diamond.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	sep_right.color = MerlinVisual.CRT_PALETTE.line

	# Configure wheel
	cal.wheel_container.custom_minimum_size = Vector2(0, 140 if not cal.compact_mode else 100)
	cal.wheel_container.draw.connect(cal._on_wheel_draw)

	# Configure next event panel
	_configure_event_panel()

	# Configure tabs (dynamic buttons)
	_configure_tabs()


func _configure_event_panel() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	style.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	cal.event_panel.add_theme_stylebox_override("panel", style)

	var evbox: VBoxContainer = VBoxContainer.new()
	evbox.add_theme_constant_override("separation", 4)
	cal.event_panel.add_child(evbox)

	var header: Label = Label.new()
	header.text = "Prochain evenement"
	if cal.font_regular:
		header.add_theme_font_override("font", cal.font_regular)
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	evbox.add_child(header)

	if not cal.next_event.is_empty():
		var event_date: Dictionary = cal._parse_event_date(cal.next_event.date)
		var date_lbl: Label = Label.new()
		date_lbl.text = "%d %s" % [event_date.day, cal.MONTH_NAMES[event_date.month]]
		if cal.font_bold:
			date_lbl.add_theme_font_override("font", cal.font_bold)
		date_lbl.add_theme_font_size_override("font_size", 14)
		date_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.event_today)
		evbox.add_child(date_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = cal.next_event.name
		if cal.font_bold:
			name_lbl.add_theme_font_override("font", cal.font_bold)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		evbox.add_child(name_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = cal.next_event.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cal.font_regular:
			desc_lbl.add_theme_font_override("font", cal.font_regular)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		evbox.add_child(desc_lbl)


func _configure_tabs() -> void:
	cal.events_tab_btn = _create_tab_button("Evenements")
	cal.events_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		cal.tabs_helper.set_tab(cal.TAB_EVENTS)
	)
	cal.tabs_container.add_child(cal.events_tab_btn)

	cal.stats_tab_btn = _create_tab_button("Statistiques")
	cal.stats_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		cal.tabs_helper.set_tab(cal.TAB_STATS)
	)
	cal.tabs_container.add_child(cal.stats_tab_btn)

	cal.brumes_tab_btn = _create_tab_button("Brumes")
	cal.brumes_tab_btn.pressed.connect(func():
		SFXManager.play("click")
		cal.tabs_helper.set_tab(cal.TAB_BRUMES)
	)
	cal.tabs_container.add_child(cal.brumes_tab_btn)
	cal.brumes_tab_btn.visible = cal.has_brumes_upgrade


func _create_tab_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cal.font_regular:
		btn.add_theme_font_override("font", cal.font_regular)
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _configure_back_button(viewport_size: Vector2) -> void:
	if cal.font_bold:
		cal.back_button.add_theme_font_override("font", cal.font_bold)
	cal.back_button.add_theme_font_size_override("font_size", 16)
	cal.back_button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	cal.back_button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.amber)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	btn_style.border_color = MerlinVisual.CRT_PALETTE.border
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)
	btn_style.content_margin_left = 14
	btn_style.content_margin_right = 14
	cal.back_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = MerlinVisual.CRT_PALETTE.phosphor_glow
	btn_hover.border_color = MerlinVisual.CRT_PALETTE.amber_dim
	cal.back_button.add_theme_stylebox_override("hover", btn_hover)

	cal.back_button.size = Vector2(110, 40)
	cal.back_button.position = Vector2(28, viewport_size.y - 56)
	cal.back_button.pressed.connect(cal._on_back_pressed)
