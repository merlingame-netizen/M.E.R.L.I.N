class_name MerlinRingGauge
extends Control
## Jauge en anneau (DA flat rétro-minimaliste, 2026-05-26) : anneau de fond fin + arc rempli
## proportionnel au ratio (0..1), dessiné en moteur. Le ratio s'anime via tween_method(set_ratio).

const RING_SIZE: float = 52.0
const RING_WIDTH: float = 4.0
const COL_BG_RING: Color = Color("3A3228")

var _ratio: float = 0.0
var color_fill: Color = Color("7FA65C")


func setup(p_color: Color) -> void:
	color_fill = p_color
	custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	size = Vector2(RING_SIZE, RING_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	queue_redraw()


func get_ratio() -> float:
	return _ratio


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	var rad: float = minf(s.x, s.y) * 0.5 - RING_WIDTH
	if rad <= 0.0:
		return
	draw_arc(c, rad, 0.0, TAU, 56, COL_BG_RING, RING_WIDTH, true)
	if _ratio > 0.0:
		var start: float = -PI / 2.0  # départ en haut, sens horaire
		draw_arc(c, rad, start, start + _ratio * TAU, 56, color_fill, RING_WIDTH, true)
