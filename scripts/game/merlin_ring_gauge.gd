class_name MerlinRingGauge
extends Control
## Jauge en anneau (DA flat rétro-minimaliste, 2026-05-26) : anneau de fond fin + arc rempli
## proportionnel au ratio (0..1), dessiné en moteur. Le ratio s'anime via tween_method(set_ratio).

const RING_SIZE: float = 52.0
const RING_WIDTH: float = 4.0
const COL_BG_RING: Color = Color("3A3228")
const BREATH_IDLE_MIN: float = 0.82  # respiration de repos : subtile (jauge « vivante »)
const BREATH_IDLE_DUR: float = 1.4
const BREATH_CRIT_MIN: float = 0.40  # critique : respiration marquée + rapide
const BREATH_CRIT_DUR: float = 0.55

var _ratio: float = 0.0
var color_fill: Color = Color("7FA65C")
var _critical: bool = false
var _crit_tw: Tween


func setup(p_color: Color, alive: bool = false) -> void:
	color_fill = p_color
	custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	size = Vector2(RING_SIZE, RING_SIZE)
	pivot_offset = Vector2(RING_SIZE, RING_SIZE) * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	if alive:
		_start_breath(false)  # respiration « vivante » dès l'affichage (jauges du jeu)


## Respiration alpha CONTINUE (jauge « vivante ») : idle lent & subtil par défaut, fort &
## rapide quand la stat devient critique (vie basse / corruption haute). Demande user 2026-05-27.
func set_critical(on: bool) -> void:
	if on == _critical:
		return
	_critical = on
	_start_breath(on)


func _start_breath(crit: bool) -> void:
	if _crit_tw != null and _crit_tw.is_valid():
		_crit_tw.kill()
	var lo: float = BREATH_CRIT_MIN if crit else BREATH_IDLE_MIN
	var dur: float = BREATH_CRIT_DUR if crit else BREATH_IDLE_DUR
	modulate.a = 1.0
	_crit_tw = create_tween().set_loops()
	_crit_tw.tween_property(self, "modulate:a", lo, dur).set_trans(Tween.TRANS_SINE)
	_crit_tw.tween_property(self, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE)


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
