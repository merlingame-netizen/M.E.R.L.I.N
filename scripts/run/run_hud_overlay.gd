extends CanvasLayer
class_name RunHudOverlay

signal ogham_pressed(ogham_id: String)
signal ogham_switch_requested()

var _top_bar: PanelContainer
var _bottom_bar: PanelContainer
var _life_bar: ProgressBar
var _life_label: Label
var _ogham_button: Button
var _period_label: Label
var _card_counter: Label
var _promise_container: HBoxContainer
var _currency_label: Label

var _current_ogham_id: String = ""
var _card_index: int = 0
var _mos_target: int = 25
var _press_timer: Timer


func _ready() -> void:
	layer = 10
	_mos_target = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_max", 25))
	_build_top_bar()
	_build_bottom_bar()
	_build_press_timer()
	_fade_in()


func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.add_theme_stylebox_override("panel", _make_bar_panel())
	var margin := _wrap_in_margin(_top_bar)
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_bottom = 48
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var safe_top: float = mr.get_safe_margin_top() if mr else 0.0
	margin.offset_top = safe_top

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)

	# Life section
	var life_hbox := HBoxContainer.new()
	life_hbox.add_theme_constant_override("separation", 6)
	var heart := Label.new()
	heart.text = "\u2665"
	_apply_font(heart, MerlinVisual.BODY_SIZE)
	heart.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["success"])
	life_hbox.add_child(heart)

	_life_bar = ProgressBar.new()
	_life_bar.custom_minimum_size = Vector2(100, 14)
	_life_bar.max_value = 100
	_life_bar.value = 100
	_life_bar.show_percentage = false
	MerlinVisual.apply_bar_theme(_life_bar, "success")
	life_hbox.add_child(_life_bar)

	_life_label = Label.new()
	_life_label.text = "100/100"
	_apply_font(_life_label, MerlinVisual.BODY_SMALL)
	_life_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
	life_hbox.add_child(_life_label)

	life_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(life_hbox)

	# Ogham button
	_ogham_button = Button.new()
	_ogham_button.text = ""
	MerlinVisual.apply_button_theme(_ogham_button)
	_ogham_button.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	_ogham_button.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["amber_bright"])
	_ogham_button.custom_minimum_size.y = MerlinVisual.MIN_TOUCH_TARGET
	_ogham_button.custom_minimum_size.x = 120
	_ogham_button.pressed.connect(_on_ogham_pressed)
	hbox.add_child(_ogham_button)

	# Period label
	_period_label = Label.new()
	_period_label.text = "Aube"
	_period_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(_period_label, MerlinVisual.BODY_SIZE)
	_period_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	hbox.add_child(_period_label)

	_top_bar.add_child(hbox)


func _build_bottom_bar() -> void:
	_bottom_bar = PanelContainer.new()
	_bottom_bar.add_theme_stylebox_override("panel", _make_bar_panel())
	var margin := _wrap_in_margin(_bottom_bar)
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -44
	var mr: Node = get_node_or_null("/root/MerlinResponsive")
	var safe_bottom: float = mr.get_safe_margin_bottom() if mr else 0.0
	margin.offset_bottom = -safe_bottom

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)

	# Card counter
	_card_counter = Label.new()
	_card_counter.text = "Carte 0 / %d" % _mos_target
	_apply_font(_card_counter, MerlinVisual.BODY_SMALL)
	_card_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])
	_card_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_card_counter)

	# Promise container
	_promise_container = HBoxContainer.new()
	_promise_container.add_theme_constant_override("separation", 8)
	_promise_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_promise_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(_promise_container)

	# Currency
	var currency_hbox := HBoxContainer.new()
	currency_hbox.add_theme_constant_override("separation", 4)
	currency_hbox.alignment = BoxContainer.ALIGNMENT_END
	var coin := Label.new()
	coin.text = "\u25C9"
	_apply_font(coin, MerlinVisual.BODY_SIZE)
	coin.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	currency_hbox.add_child(coin)

	_currency_label = Label.new()
	_currency_label.text = "0"
	_apply_font(_currency_label, MerlinVisual.BODY_SIZE)
	_currency_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
	currency_hbox.add_child(_currency_label)

	hbox.add_child(currency_hbox)
	_bottom_bar.add_child(hbox)


func _build_press_timer() -> void:
	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = 0.6
	_press_timer.timeout.connect(_on_long_press)
	add_child(_press_timer)
	_ogham_button.button_down.connect(func() -> void: _press_timer.start())
	_ogham_button.button_up.connect(func() -> void:
		if not _press_timer.is_stopped():
			_press_timer.stop()
	)


func _fade_in() -> void:
	_top_bar.modulate.a = 0.0
	_bottom_bar.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_top_bar, "modulate:a", 1.0, MerlinVisual.ANIM_NORMAL)
	tw.tween_property(_bottom_bar, "modulate:a", 1.0, MerlinVisual.ANIM_NORMAL)


# Public API

func update_life(current: int, maximum: int) -> void:
	_life_bar.max_value = maximum
	_life_bar.value = current
	_life_label.text = "%d/%d" % [current, maximum]
	var low_threshold: int = MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD
	if current <= low_threshold:
		var danger: Color = MerlinVisual.CRT_PALETTE["danger"]
		_life_bar.add_theme_stylebox_override("fill", MerlinVisual.make_bar_fill_style("danger", true))
		_life_label.add_theme_color_override("font_color", danger)
	else:
		_life_bar.add_theme_stylebox_override("fill", MerlinVisual.make_bar_fill_style("success", true))
		_life_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])


func update_currency(amount: int) -> void:
	_currency_label.text = str(amount)


func update_ogham(ogham_id: String, cooldown: int) -> void:
	_current_ogham_id = ogham_id
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var rune_name: String = str(spec.get("name", ogham_id))
	var rune_char: String = str(spec.get("unicode", ""))
	if cooldown > 0:
		_ogham_button.text = "%s %s (%d)" % [rune_char, rune_name, cooldown]
		_ogham_button.disabled = true
	else:
		_ogham_button.text = "%s %s" % [rune_char, rune_name]
		_ogham_button.disabled = false


func update_period(period: String) -> void:
	var labels: Dictionary = {
		"aube": "Aube",
		"jour": "Jour",
		"crepuscule": "Cr\u00e9puscule",
		"nuit": "Nuit",
	}
	_period_label.text = str(labels.get(period, period))


func update_card_index(index: int) -> void:
	_card_index = index
	_card_counter.text = "Carte %d / %d" % [index, _mos_target]


func update_promises(promises: Array) -> void:
	for child in _promise_container.get_children():
		child.queue_free()
	for promise in promises:
		if not (promise is Dictionary):
			continue
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _make_promise_style())
		var lbl := Label.new()
		var desc: String = str(promise.get("description", "?"))
		if desc.length() > 16:
			desc = desc.left(14) + ".."
		lbl.text = desc
		_apply_font(lbl, MerlinVisual.CAPTION_SIZE)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["cyan"])
		badge.add_child(lbl)
		_promise_container.add_child(badge)


func set_hud_visible(visible_flag: bool) -> void:
	_top_bar.visible = visible_flag
	_bottom_bar.visible = visible_flag


# Internal

func _on_ogham_pressed() -> void:
	if _current_ogham_id.is_empty():
		return
	ogham_pressed.emit(_current_ogham_id)


func _on_long_press() -> void:
	ogham_switch_requested.emit()


func _wrap_in_margin(panel: PanelContainer) -> Control:
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.add_child(panel)
	return ctrl


func _make_bar_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var bg: Color = MerlinVisual.CRT_PALETTE["bg_panel"]
	s.bg_color = Color(bg.r, bg.g, bg.b, 0.7)
	s.border_color = MerlinVisual.CRT_PALETTE["border"]
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _make_promise_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var cyan: Color = MerlinVisual.CRT_PALETTE["cyan_dim"]
	s.bg_color = Color(cyan.r, cyan.g, cyan.b, 0.2)
	s.border_color = MerlinVisual.CRT_PALETTE["cyan_dim"]
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _apply_font(control: Control, base_size: int) -> void:
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(base_size))
