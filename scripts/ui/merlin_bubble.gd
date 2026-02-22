class_name MerlinBubble
extends Control

## Floating speech bubble for Merlin with typewriter effect
## Shows temporary messages with auto-dismiss and click-to-dismiss

signal bubble_dismissed
signal typing_complete

const MAX_WIDTH: int = 400
const CORNER_RADIUS: int = 8
const BORDER_WIDTH: int = 1
const TYPEWRITER_SPEED: float = 0.025
const PUNCTUATION_PAUSE: float = 0.080
const ENTRY_DURATION: float = 0.3
const EXIT_DURATION: float = 0.5
const TOP_OFFSET_PERCENT: float = 0.15
const SLIDE_OFFSET: float = -20.0

var _panel: PanelContainer
var _label: Label
var _is_showing: bool = false
var _is_typing: bool = false
var _dismiss_timer: Timer
var _full_text: String = ""
var _current_index: int = 0

# Colors
var _bg_color: Color = Color(0.20, 0.20, 0.18, 0.88)
var _border_color: Color
var _text_color: Color


func _ready() -> void:
	# Load colors from MerlinVisual
	_border_color = MerlinVisual.PALETTE["celtic_gold"]
	_border_color.a = 0.3
	_text_color = MerlinVisual.PALETTE["paper"]

	# Setup control
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(MAX_WIDTH, 0)

	# Create panel container
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Create custom StyleBox
	var style := StyleBoxFlat.new()
	style.bg_color = _bg_color
	style.border_color = _border_color
	style.border_width_left = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)

	# Create label
	_label = Label.new()
	_label.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", _text_color)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(MAX_WIDTH - 32, 0)
	_panel.add_child(_label)

	# Create dismiss timer
	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_on_dismiss_timer_timeout)
	add_child(_dismiss_timer)

	# Connect click to dismiss
	_panel.gui_input.connect(_on_panel_input)

	# Start hidden
	modulate.a = 0.0
	visible = false

	# Reposition on parent resize
	if get_parent():
		get_parent().resized.connect(_reposition)


func show_message(text: String, duration: float = 4.0) -> void:
	# If already showing, dismiss current and show new
	if _is_showing:
		dismiss()
		await bubble_dismissed

	_full_text = text
	_current_index = 0
	_is_showing = true
	_is_typing = true

	_label.text = ""
	visible = true

	# Reposition
	_reposition()

	# Entry animation
	_animate_entry()

	# Start typewriter
	_type_next_character()

	# Start dismiss timer (from typing complete)
	await typing_complete
	_dismiss_timer.start(duration)


func dismiss() -> void:
	if not _is_showing:
		return

	_is_showing = false
	_is_typing = false
	_dismiss_timer.stop()

	# Exit animation
	_animate_exit()


func is_showing() -> bool:
	return _is_showing


func _reposition() -> void:
	if not get_parent():
		return

	var parent_size: Vector2 = get_parent().size
	_panel.position = Vector2(
		(parent_size.x - MAX_WIDTH) * 0.5,
		parent_size.y * TOP_OFFSET_PERCENT
	)


func _animate_entry() -> void:
	var start_pos: Vector2 = _panel.position + Vector2(0, SLIDE_OFFSET)
	var end_pos: Vector2 = _panel.position

	_panel.position = start_pos
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "position", end_pos, ENTRY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, ENTRY_DURATION)


func _animate_exit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, EXIT_DURATION)
	await tween.finished

	visible = false
	bubble_dismissed.emit()


func _type_next_character() -> void:
	if not _is_typing or _current_index >= _full_text.length():
		_is_typing = false
		typing_complete.emit()
		return

	var char: String = _full_text[_current_index]
	_label.text += char
	_current_index += 1

	# Optional SFX blip
	if SFXManager and SFXManager.has_method("play_ui_click"):
		SFXManager.play_ui_click()

	# Calculate delay
	var delay: float = TYPEWRITER_SPEED
	if char in ".,!?;:":
		delay = PUNCTUATION_PAUSE

	await get_tree().create_timer(delay).timeout
	_type_next_character()


func _on_dismiss_timer_timeout() -> void:
	dismiss()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss()
