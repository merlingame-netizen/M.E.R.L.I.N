extends Control
## Curseur anime CRT — point central + anneau pulsant + particle trail
## Style terminal phosphor avec trainee lumineuse

var _ring_radius: float = 10.0
var _ring_base: float = 10.0
var _dot_radius: float = 2.5
var _ring_width: float = 1.5
var _ring_color := Color(0.22, 0.18, 0.14, 0.45)
var _dot_color := Color(0.22, 0.18, 0.14, 0.8)
var _time: float = 0.0
var _target_pos := Vector2.ZERO
var _smoothing: float = 18.0

# Particle trail
const TRAIL_MAX := 16
var _trail: Array[Dictionary] = []  # {pos, age, size}
var _trail_spawn_timer: float = 0.0
const TRAIL_SPAWN_INTERVAL := 0.03
const TRAIL_LIFETIME := 0.5
var _prev_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 4096
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _process(delta: float) -> void:
	_time += delta
	# Breathing animation on ring
	_ring_radius = _ring_base + sin(_time * 2.5) * 2.0
	# Smooth follow
	_target_pos = get_viewport().get_mouse_position()
	global_position = global_position.lerp(_target_pos, clampf(_smoothing * delta, 0.0, 1.0))

	# Trail particles
	_trail_spawn_timer += delta
	var speed: float = global_position.distance_to(_prev_pos) / maxf(delta, 0.001)
	if _trail_spawn_timer >= TRAIL_SPAWN_INTERVAL and speed > 20.0:
		_trail_spawn_timer = 0.0
		if _trail.size() >= TRAIL_MAX:
			_trail.pop_front()
		_trail.append({
			"pos": global_position,
			"age": 0.0,
			"size": clampf(speed * 0.008, 1.0, 3.0),
		})
	_prev_pos = global_position

	# Age trail particles
	var i := _trail.size() - 1
	while i >= 0:
		_trail[i].age += delta
		if _trail[i].age >= TRAIL_LIFETIME:
			_trail.remove_at(i)
		i -= 1

	queue_redraw()


func _draw() -> void:
	# Trail particles — fading dots behind cursor
	for p in _trail:
		var t: float = 1.0 - (p.age / TRAIL_LIFETIME)
		var alpha: float = t * t * 0.6  # Quadratic fade
		var trail_c := Color(_dot_color.r, _dot_color.g, _dot_color.b, alpha)
		var local_pos: Vector2 = p.pos - global_position
		draw_circle(local_pos, p.size * t, trail_c)

	# Ring — thin, breathing
	var alpha_pulse: float = 0.4 + 0.2 * sin(_time * 2.5)
	var ring_c := Color(_ring_color.r, _ring_color.g, _ring_color.b, alpha_pulse)
	draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 36, ring_c, _ring_width, true)
	# Dot — solid center
	draw_circle(Vector2.ZERO, _dot_radius, _dot_color)


func set_palette(dot_color: Color, ring_color: Color) -> void:
	_dot_color = dot_color
	_ring_color = ring_color


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
