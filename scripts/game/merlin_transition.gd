extends CanvasLayer
## v10.16 — Transition encre organique : Polygon2D à front irrégulier (24 segments + bruit
## sinusoïdal). Remplace le fondu noir. Caption pendant le recouvrement complet.

const COL_INK: Color = MerlinVisual.SILHOUETTE
const SEGMENTS: int = 24
const NOISE_AMP: float = 40.0
const DUR_WIPE: float = MerlinVisual.DUR_INK_WIPE

var _poly: Polygon2D
var _caption_lbl: Label
var _overlay: Control
var _tw: Tween = null
var _revealing: bool = false
var _progress: float = 0.0
var _busy: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		_busy = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_poly = Polygon2D.new()
	_poly.color = COL_INK
	_overlay.add_child(_poly)
	_caption_lbl = Label.new()
	_caption_lbl.add_theme_color_override("font_color", MerlinVisual.CREAM)
	_caption_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_CAPTION)
	_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caption_lbl.visible = false
	_caption_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_caption_lbl)


func change_scene(path: String, caption: String = "") -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("[MerlinTransition] scene not found: %s" % path)
		return
	MerlinAudio.play_sfx("ink_wash")
	# Coupe le FLUX DE BASE sous le voile (anti double-musique, user 2026-06-29) : on STOPPE la piste
	# courante au lieu de la ducker. La scène suivante démarre sa musique de zéro (play_music depuis le
	# silence) → plus aucun chevauchement de deux mélodies pendant le chargement.
	MerlinAudio.stop_music(DUR_WIPE * MerlinVisual.motion())
	_busy = true
	_revealing = false
	_progress = 0.0
	_caption_lbl.text = caption
	_caption_lbl.visible = false
	_update_polygon()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = DUR_WIPE * MerlinVisual.motion()
	_tw = create_tween()
	_tw.tween_method(_set_progress, 0.0, 1.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _tw.finished
	_caption_lbl.visible = caption != ""
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[MerlinTransition] change_scene err=%d path=%s" % [err, path])
		_caption_lbl.visible = false
		_poly.polygon = PackedVector2Array()
		_busy = false
		return
	await get_tree().process_frame
	_caption_lbl.visible = false
	_revealing = true
	_progress = 0.0
	_update_polygon()
	_tw = create_tween()
	_tw.tween_method(_set_progress, 0.0, 1.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _tw.finished
	_poly.polygon = PackedVector2Array()
	# Plus de restore_music : la scène suivante a relancé sa propre piste (play_music) depuis le silence.
	_busy = false


func _set_progress(v: float) -> void:
	_progress = v
	_update_polygon()


func _update_polygon() -> void:
	if _poly == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var w: float = vp.x
	var h: float = vp.y
	var pts: PackedVector2Array = PackedVector2Array()
	var noise_strength: float = minf(_progress, 1.0 - _progress) * 2.0
	if _revealing:
		var front_x: float = w * _progress
		pts.append(Vector2(front_x, 0.0))
		for i in SEGMENTS + 1:
			var y: float = float(i) / float(SEGMENTS) * h
			var nx: float = sin(y * 0.06 + _progress * 8.0 + float(i) * 0.7) * NOISE_AMP * noise_strength
			pts.append(Vector2(front_x + nx, y))
		pts.append(Vector2(front_x, h))
		pts.append(Vector2(w, h))
		pts.append(Vector2(w, 0.0))
	else:
		var front_x: float = w * _progress
		pts.append(Vector2(0.0, 0.0))
		pts.append(Vector2(0.0, h))
		pts.append(Vector2(front_x, h))
		for i in range(SEGMENTS, -1, -1):
			var y: float = float(i) / float(SEGMENTS) * h
			var nx: float = sin(y * 0.06 + _progress * 8.0 + float(i) * 0.7) * NOISE_AMP * noise_strength
			pts.append(Vector2(front_x + nx, y))
		pts.append(Vector2(front_x, 0.0))
	_poly.polygon = pts
