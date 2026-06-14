class_name MerlinBeatMap
extends Control
## v10.15 — Beat map HORIZONTAL : bandeau de progression dans le HUD (entre les deux jauges).
## Nœuds reliés par des connecteurs, position « tu es ici » mise en valeur,
## beats passés/à-venir distincts, + marqueur de déviation quand le joueur DRAFTE une carte.
## DA flat verrouillée (crème/encre/or, zéro dégradé). Dessiné via _draw.

const H: float = 28.0
const SPACING_H: float = 30.0
const NODE_R: float = 5.0
const NODE_R_CUR: float = 7.0

const COL_PARCH: Color = MerlinVisual.CREAM
const COL_INK: Color = MerlinVisual.INK
const COL_DIM: Color = MerlinVisual.INK_DIM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_FUTURE: Color = MerlinVisual.RING_BG
const COL_DEV: Color = MerlinVisual.RARE_BLUE

var _total: int = 0
var _current: int = 0
var _draft_marks: Dictionary = {}

var _growth: float = 1.0
var _growth_idx: int = -1
var _halo_scale: float = 1.0
var _adv_tw: Tween = null


func setup(total: int) -> void:
	_total = maxi(total, 1)
	_draft_marks = {}
	queue_redraw()


func set_current(idx: int) -> void:
	_current = clampi(idx, 0, maxi(_total - 1, 0))
	if _adv_tw != null and _adv_tw.is_valid():
		_adv_tw.kill()
	_growth = 1.0
	_growth_idx = -1
	_halo_scale = 1.0
	queue_redraw()


func animate_advance(idx: int) -> void:
	var target: int = clampi(idx, 0, maxi(_total - 1, 0))
	if target == _current or target <= 0:
		set_current(target)
		return
	_current = target
	_growth_idx = target - 1
	_growth = 0.0
	_halo_scale = 1.0
	if _adv_tw != null and _adv_tw.is_valid():
		_adv_tw.kill()
	_adv_tw = create_tween()
	_adv_tw.tween_method(_set_growth, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_adv_tw.tween_method(_set_halo_scale, 1.7, 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# AUDIO_HOOK: beat_advance (node ping)
	_adv_tw.tween_callback(_sparks_at_current)


func _set_growth(v: float) -> void:
	_growth = v
	queue_redraw()


func _set_halo_scale(v: float) -> void:
	_halo_scale = v
	queue_redraw()


func mark_draft() -> void:
	_draft_marks[_current] = true
	queue_redraw()


func _node_pos(i: int) -> Vector2:
	var total_w: float = float(maxi(_total - 1, 0)) * SPACING_H
	var start_x: float = (size.x - total_w) * 0.5
	return Vector2(start_x + float(i) * SPACING_H, H * 0.5)


func _draw() -> void:
	if _total <= 0:
		return
	for i in range(_total - 1):
		var p0: Vector2 = _node_pos(i)
		var p1: Vector2 = _node_pos(i + 1)
		if i == _growth_idx and _growth < 1.0:
			draw_line(p0, p1, COL_DIM, 2.0)
			if _growth > 0.0:
				draw_line(p0, p0.lerp(p1, _growth), COL_INK, 2.0)
		else:
			var col: Color = COL_INK if i < _current else COL_DIM
			draw_line(p0, p1, col, 2.0)
	for i in _total:
		var p: Vector2 = _node_pos(i)
		if _draft_marks.has(i):
			var d: Vector2 = p + Vector2(0.0, -10.0)
			draw_line(p, d, COL_DEV, 2.0)
			draw_circle(d, 3.0, COL_DEV)
		if i < _current:
			draw_circle(p, NODE_R, COL_INK)
		elif i == _current:
			draw_circle(p, (NODE_R_CUR + 3.0) * _halo_scale, COL_GOLD)
			draw_circle(p, NODE_R_CUR * _halo_scale, Color(0, 0, 0, 0))
			draw_circle(p, maxf((NODE_R_CUR - 3.0) * _halo_scale, 1.0), COL_GOLD)
		else:
			draw_circle(p, NODE_R, COL_DIM)
			draw_circle(p, NODE_R - 2.0, COL_FUTURE)


func _sparks_at_current() -> void:
	if MerlinVisual.reduced_motion:
		return
	var p: Vector2 = _node_pos(_current)
	for si in 6:
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(3.0, 3.0)
		spark.color = COL_GOLD
		spark.position = p - Vector2(1.5, 1.5)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var angle: float = float(si) / 6.0 * TAU + randf() * 0.5
		var dist: float = 18.0 + randf() * 22.0
		var dest: Vector2 = p + Vector2(cos(angle), sin(angle)) * dist
		var tw: Tween = spark.create_tween().set_parallel(true)
		tw.tween_property(spark, "position", dest - Vector2(1.5, 1.5), MerlinVisual.DUR_MOTE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, MerlinVisual.DUR_MOTE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)
