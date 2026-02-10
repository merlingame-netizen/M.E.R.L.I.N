extends Control
## Curseur anime minimaliste — point central + anneau pulsant
## Epure, sobre, style parchemin celtique

var _ring_radius: float = 10.0
var _ring_base: float = 10.0
var _dot_radius: float = 2.0
var _ring_width: float = 1.0
var _ring_color := Color(0.22, 0.18, 0.14, 0.45)
var _dot_color := Color(0.22, 0.18, 0.14, 0.8)
var _time: float = 0.0
var _target_pos := Vector2.ZERO
var _smoothing: float = 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 4096
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _process(delta: float) -> void:
	_time += delta
	# Breathing animation on ring
	_ring_radius = _ring_base + sin(_time * 2.0) * 1.5
	# Smooth follow
	_target_pos = get_viewport().get_mouse_position()
	global_position = global_position.lerp(_target_pos, clampf(_smoothing * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	# Ring — thin, breathing
	var alpha_pulse: float = 0.35 + 0.15 * sin(_time * 2.0)
	var ring_c := Color(_ring_color.r, _ring_color.g, _ring_color.b, alpha_pulse)
	draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 36, ring_c, _ring_width, true)
	# Dot — solid center
	draw_circle(Vector2.ZERO, _dot_radius, _dot_color)


func set_palette(dot_color: Color, ring_color: Color) -> void:
	_dot_color = dot_color
	_ring_color = ring_color


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
