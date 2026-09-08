class_name MerlinAnneauxFin
extends Control
## Les deux anneaux de l'écran de fin (08/09) : l'intégrité et la corruption, dessinés en arcs qui
## s'écrivent en une seconde et demie. Le chiffre est dans l'anneau ; le texte dessous le redit.

const R: float = 30.0
const EP: float = 5.0

var _integ: int = 10
var _corr: int = 0
var _f: float = 0.0   # part dessinée des arcs (0..1)


func _ready() -> void:
	custom_minimum_size = Vector2(220.0, R * 2.0 + 16.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func montrer(integrite: int, corruption: int) -> void:
	_integ = clampi(integrite, 0, MerlinRun.MAX_INTEGRITE)
	_corr = clampi(corruption, 0, MerlinRun.CORRUPTION_CAP)
	_f = 0.0
	if MerlinVisual.reduced_motion:
		_f = 1.0
		queue_redraw()
		return
	var tw: Tween = create_tween()
	tw.tween_interval(0.8)
	tw.tween_method(func(v: float) -> void: _f = v; queue_redraw(), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var cy: float = size.y * 0.5
	var c1: Vector2 = Vector2(size.x * 0.5 - R - 24.0, cy)
	var c2: Vector2 = Vector2(size.x * 0.5 + R + 24.0, cy)
	var fond: Color = MerlinVisual.RING_BG
	draw_arc(c1, R, 0.0, TAU, 40, fond, EP, true)
	draw_arc(c2, R, 0.0, TAU, 40, fond, EP, true)
	var p_i: float = float(_integ) / float(MerlinRun.MAX_INTEGRITE) * _f
	var p_c: float = float(_corr) / float(MerlinRun.CORRUPTION_CAP) * _f
	if p_i > 0.001:
		draw_arc(c1, R, -PI * 0.5, -PI * 0.5 + TAU * p_i, 48, MerlinVisual.GOLD, EP, true)
	if p_c > 0.001:
		draw_arc(c2, R, -PI * 0.5, -PI * 0.5 + TAU * p_c, 48, MerlinVisual.VIOLET, EP, true)
	var font: Font = ThemeDB.fallback_font
	var t1: String = "%d" % int(round(float(_integ) * _f))
	var t2: String = "%d" % int(round(float(_corr) * _f))
	draw_string(font, c1 + Vector2(-font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x * 0.5, 8.0), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, MerlinVisual.CREAM)
	draw_string(font, c2 + Vector2(-font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x * 0.5, 8.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, MerlinVisual.CREAM)
