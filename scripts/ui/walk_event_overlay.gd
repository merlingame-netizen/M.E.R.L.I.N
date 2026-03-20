## ═══════════════════════════════════════════════════════════════════════════════
## WalkEventOverlay — Darkened overlay with typewriter text + 3 choice buttons
## ═══════════════════════════════════════════════════════════════════════════════
## Displayed over the 3D viewport during LLM-generated events.
## Player movement freezes while active. CRT phosphor aesthetic.
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

signal choice_selected(option: int)  # 0=A, 1=B, 2=C
signal overlay_closed

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const FADE_DURATION: float = 0.4
const DIMMER_ALPHA: float = 0.75
const TYPEWRITER_SPEED: float = 40.0  # chars per second
const BUTTON_APPEAR_DELAY: float = 0.15  # after text done
const FONT_SIZE_TEXT: int = 18
const FONT_SIZE_BUTTON: int = 16

# ═══════════════════════════════════════════════════════════════════════════════
# NODES (built in _ready)
# ═══════════════════════════════════════════════════════════════════════════════

var _dimmer: ColorRect
var _text_label: RichTextLabel
var _button_container: HBoxContainer
var _buttons: Array[Button] = []
var _root: Control

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _active: bool = false
var _typing: bool = false
var _visible_chars: int = 0
var _total_chars: int = 0
var _type_timer: float = 0.0
var _current_labels: Array[String] = []
var _fade_tween: Tween
var _auto_respond_timer: float = 0.0
const AUTO_RESPOND_TIMEOUT: float = 30.0  # Auto-select option A after 30s (for auto-test)


func _ready() -> void:
	layer = 10
	_build_ui()
	_hide_immediate()


func _process(delta: float) -> void:
	# Auto-respond if overlay idle too long (for headless/auto-test)
	if _active and not _typing and _button_container.visible:
		_auto_respond_timer += delta
		if _auto_respond_timer >= AUTO_RESPOND_TIMEOUT:
			_auto_respond_timer = 0.0
			_on_button_pressed(0)  # Auto-select option A
			return
	if not _typing:
		return
	_type_timer += delta * TYPEWRITER_SPEED
	var new_count: int = int(_type_timer)
	if new_count > _total_chars:
		new_count = _total_chars
	if new_count != _visible_chars:
		_visible_chars = new_count
		_text_label.visible_characters = _visible_chars
	if _visible_chars >= _total_chars:
		_typing = false
		_show_buttons_delayed()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func show_event(text: String, labels: Array[String]) -> void:
	if _active:
		return
	_active = true
	_current_labels = labels
	_auto_respond_timer = 0.0

	# Reset text
	_text_label.text = text
	_total_chars = text.length()
	_visible_chars = 0
	_type_timer = 0.0
	_text_label.visible_characters = 0
	_text_label.visible = true

	# Hide buttons until text finishes
	_button_container.visible = false
	for i in _buttons.size():
		if i < labels.size():
			_buttons[i].text = "[%s] %s" % [["A", "B", "C"][i], labels[i]]
			_buttons[i].visible = true
		else:
			_buttons[i].visible = false

	# Fade in dimmer
	_root.visible = true
	_dimmer.color.a = 0.0
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_dimmer, "color:a", DIMMER_ALPHA, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void: _typing = true)


func close_overlay() -> void:
	if not _active:
		return
	_typing = false
	_button_container.visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_dimmer, "color:a", 0.0, FADE_DURATION * 0.6)
	_fade_tween.tween_callback(_on_fade_out_done)


func is_active() -> bool:
	return _active


func skip_typewriter() -> void:
	if _typing:
		_typing = false
		_visible_chars = _total_chars
		_text_label.visible_characters = _total_chars
		_show_buttons_delayed()


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var font: Font = MerlinVisual.get_font("terminal")
	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	# Root control (full screen)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dimmer background
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dimmer)

	# Center container for text + buttons (bottom third)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 180)
	margin.add_theme_constant_override("margin_bottom", 40)
	_root.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Narrative text
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", FONT_SIZE_TEXT)
	_text_label.add_theme_color_override("default_color", pal["phosphor"])
	_text_label.visible_characters = 0
	vbox.add_child(_text_label)

	# Scanline separator
	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(0.0, 1.0)
	sep.color = pal["border"]
	vbox.add_child(sep)

	# Button row
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 24)
	_button_container.visible = false
	vbox.add_child(_button_container)

	for i in 3:
		var btn: Button = _create_choice_button(font, pal, i)
		_button_container.add_child(btn)
		_buttons.append(btn)


func _create_choice_button(font: Font, pal: Dictionary, index: int) -> Button:
	var btn: Button = Button.new()
	btn.text = "[%s] ..." % ["A", "B", "C"][index]
	btn.custom_minimum_size = Vector2(140.0, 36.0)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BUTTON)
	btn.add_theme_color_override("font_color", pal["phosphor"])
	btn.add_theme_color_override("font_hover_color", pal["amber"])
	btn.add_theme_color_override("font_pressed_color", pal["amber_bright"])

	# Dark CRT button style
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = pal["bg_dark"]
	style_normal.border_color = pal["border"]
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(2)
	style_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.border_color = pal["amber"]
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed: StyleBoxFlat = style_normal.duplicate()
	style_pressed.bg_color = pal["bg_highlight"]
	style_pressed.border_color = pal["amber_bright"]
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_button_pressed.bind(index))
	return btn


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _hide_immediate() -> void:
	_root.visible = false
	_active = false
	_typing = false


func _show_buttons_delayed() -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(BUTTON_APPEAR_DELAY)
	tw.tween_callback(func() -> void:
		_button_container.visible = true
		# Staggered slide-in + scale for each button
		var stagger: float = 0.0
		for btn in _buttons:
			if not btn.visible:
				continue
			btn.pivot_offset = btn.size * 0.5
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.8, 0.8)
			btn.position.y += 20.0
			var entry: Tween = btn.create_tween()
			entry.set_parallel(true)
			entry.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(stagger)
			entry.tween_property(btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(stagger)
			entry.tween_property(btn, "position:y", btn.position.y - 20.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(stagger)
			stagger += 0.12
		# Keyboard focus on first button after animation
		if _buttons.size() > 0 and _buttons[0].visible:
			var focus_tw: Tween = create_tween()
			focus_tw.tween_interval(stagger + 0.15)
			focus_tw.tween_callback(func() -> void:
				if _buttons[0].is_inside_tree():
					_buttons[0].grab_focus()
			)
	)


func _on_button_pressed(index: int) -> void:
	if not _active:
		return
	choice_selected.emit(index)
	close_overlay()


func _on_fade_out_done() -> void:
	_root.visible = false
	_active = false
	overlay_closed.emit()
