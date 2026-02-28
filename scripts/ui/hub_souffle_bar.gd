class_name HubSouffleBar
extends Control

## Souffle d'Ogham bar for HubAntre — Shows current Souffle count as glowing dots
## CRT terminal aesthetic with breathing animation

const DOT_RADIUS := 5.0
const DOT_SPACING := 16.0
const BAR_HEIGHT := 28.0
const MAX_SOUFFLE := 7
const BREATHE_SPEED := 3.0

var _souffle: int = 0
var _max_souffle: int = MAX_SOUFFLE
var _breathe_t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_breathe_t += delta * BREATHE_SPEED
	queue_redraw()

func update_souffle(current: int, max_val: int = MAX_SOUFFLE) -> void:
	_souffle = clampi(current, 0, max_val)
	_max_souffle = max_val

func _draw() -> void:
	var font: Font = MerlinVisual.get_font("body")
	if font == null:
		return

	var total_dots_w: float = float(_max_souffle) * DOT_SPACING
	var label_text := "SOUFFLE"
	var label_w: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MerlinVisual.CAPTION_SIZE).x
	var total_w: float = label_w + 10.0 + total_dots_w
	var start_x: float = (size.x - total_w) * 0.5
	var cy: float = BAR_HEIGHT * 0.5

	# Label "SOUFFLE"
	var label_color: Color = MerlinVisual.CRT_PALETTE["cyan_dim"]
	draw_string(font, Vector2(start_x, cy + 5.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, MerlinVisual.CAPTION_SIZE, label_color)

	# Dots
	var dots_start: float = start_x + label_w + 10.0
	for i in _max_souffle:
		var cx: float = dots_start + float(i) * DOT_SPACING + DOT_RADIUS
		var is_active: bool = i < _souffle
		_draw_souffle_dot(Vector2(cx, cy), is_active, i)


func _draw_souffle_dot(pos: Vector2, active: bool, index: int) -> void:
	if active:
		# Breathing glow
		var breath: float = sin(_breathe_t + float(index) * 0.8) * 0.15 + 0.85
		var c_glow: Color = MerlinVisual.CRT_PALETTE["cyan"]
		c_glow.a = 0.2 * breath
		draw_circle(pos, DOT_RADIUS + 3.0, c_glow)
		# Active dot
		var c_dot: Color = MerlinVisual.CRT_PALETTE["cyan"]
		c_dot.a = breath
		draw_circle(pos, DOT_RADIUS, c_dot)
		# Bright center
		var c_center: Color = MerlinVisual.CRT_PALETTE["cyan_bright"]
		c_center.a = 0.6 * breath
		draw_circle(pos, DOT_RADIUS * 0.4, c_center)
	else:
		# Empty dot
		var c_empty: Color = MerlinVisual.CRT_PALETTE["inactive_dark"]
		draw_circle(pos, DOT_RADIUS, c_empty)
		draw_arc(pos, DOT_RADIUS, 0.0, TAU, 16, MerlinVisual.CRT_PALETTE["border"], 1.0)
