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

# 08/09 — L'ENCRE SUIT LE SENS DU VOYAGE (décision de Maxime). « droite » : le balayage d'origine,
# gauche → droite ; « gauche » : le retour ; « haut » : du haut vers le bas, comme une page qu'on
# tourne (vers le jeu) ; « bas » : du bas vers le haut (vers la fin) ; « depuis » : un cercle qui
# s'ouvre depuis un point (depuis Merlin, au menu). Des MOTES D'OR courent sur le front d'encre.
var _sens: String = "droite"
var _origine: Vector2 = Vector2(-1.0, -1.0)
var _motes: Node2D = null
var _motes_graine: Array = []


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
	_motes = Node2D.new()
	_motes.draw.connect(_dessiner_les_motes)
	_overlay.add_child(_motes)
	for i in 28:
		_motes_graine.append(Vector3(randf(), randf_range(0.6, 1.0), randf_range(1.6, 3.4)))  # position le long du front, alpha, rayon


func change_scene(path: String, caption: String = "", sens: String = "droite",
		origine: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if _busy:
		return
	_sens = sens if sens in ["droite", "gauche", "haut", "bas", "depuis"] else "droite"
	_origine = origine
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
	_motes.queue_redraw()
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
	# Le front avance de `p` : à la couverture il va de 0 à 1 ; à la révélation, de 1 à 0 dans le
	# MÊME sens (l'encre se retire par où elle est venue : le regard suit un seul mouvement).
	var p: float = (1.0 - _progress) if _revealing else _progress
	match _sens:
		"droite", "gauche":
			var front_x: float = w * (p if _sens == "droite" else 1.0 - p)
			var cote: float = 0.0 if _sens == "droite" else w
			pts.append(Vector2(cote, 0.0))
			pts.append(Vector2(cote, h))
			pts.append(Vector2(front_x, h))
			for i in range(SEGMENTS, -1, -1):
				var y: float = float(i) / float(SEGMENTS) * h
				var nx: float = sin(y * 0.06 + _progress * 8.0 + float(i) * 0.7) * NOISE_AMP * noise_strength
				pts.append(Vector2(front_x + nx, y))
			pts.append(Vector2(front_x, 0.0))
		"haut", "bas":
			var front_y: float = h * (p if _sens == "haut" else 1.0 - p)
			var cote_y: float = 0.0 if _sens == "haut" else h
			pts.append(Vector2(0.0, cote_y))
			pts.append(Vector2(w, cote_y))
			pts.append(Vector2(w, front_y))
			for i in range(SEGMENTS, -1, -1):
				var x: float = float(i) / float(SEGMENTS) * w
				var ny: float = sin(x * 0.012 + _progress * 8.0 + float(i) * 0.7) * NOISE_AMP * noise_strength
				pts.append(Vector2(x, front_y + ny))
			pts.append(Vector2(0.0, front_y))
		"depuis":
			# Un disque d'encre qui s'ouvre depuis l'origine (Merlin) jusqu'à couvrir les quatre coins ;
			# la révélation le referme. Le polygone est le disque : à p = 0 il n'existe pas.
			var o: Vector2 = _origine if _origine.x >= 0.0 else Vector2(w * 0.5, h * 0.5)
			var rmax: float = 0.0
			for c in [Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(0.0, h), Vector2(w, h)]:
				rmax = maxf(rmax, o.distance_to(c))
			var r: float = rmax * p * p  # part lentement, finit vite : un souffle
			if r < 1.0:
				_poly.polygon = PackedVector2Array()
				_motes.queue_redraw()
				return
			for i in 48:
				var a: float = float(i) / 48.0 * TAU
				var nr: float = sin(a * 5.0 + _progress * 9.0) * NOISE_AMP * 0.6 * noise_strength
				pts.append(o + Vector2(cos(a), sin(a)) * (r + nr))
	_poly.polygon = pts
	_motes.queue_redraw()


## Les motes d'or sur le front d'encre : quelques points le long de la ligne, qui ne vivent qu'au
## milieu de la course (noise_strength) — l'encre en mouvement les soulève, l'encre posée les laisse.
func _dessiner_les_motes() -> void:
	if _poly == null or _poly.polygon.is_empty() or MerlinVisual.reduced_motion:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = vp.x
	var h: float = vp.y
	var vie: float = minf(_progress, 1.0 - _progress) * 2.0
	if vie < 0.05:
		return
	var p: float = (1.0 - _progress) if _revealing else _progress
	var gold: Color = MerlinVisual.GOLD
	for g in _motes_graine:
		var u: float = float((g as Vector3).x)
		var a: float = float((g as Vector3).y) * vie * 0.85
		var r: float = float((g as Vector3).z)
		var pos: Vector2
		var derive: float = sin(_progress * 6.0 + u * 20.0) * 14.0  # elles flottent un peu derrière le front
		match _sens:
			"droite":
				pos = Vector2(w * p - 6.0 + derive, u * h)
			"gauche":
				pos = Vector2(w * (1.0 - p) + 6.0 - derive, u * h)
			"haut":
				pos = Vector2(u * w, h * p - 6.0 + derive)
			"bas":
				pos = Vector2(u * w, h * (1.0 - p) + 6.0 - derive)
			_:
				var o: Vector2 = _origine if _origine.x >= 0.0 else Vector2(w * 0.5, h * 0.5)
				var rmax: float = maxf(maxf(o.distance_to(Vector2.ZERO), o.distance_to(Vector2(w, 0.0))),
					maxf(o.distance_to(Vector2(0.0, h)), o.distance_to(Vector2(w, h))))
				var ang: float = u * TAU
				pos = o + Vector2(cos(ang), sin(ang)) * (rmax * p * p - 8.0 + derive)
		_motes.draw_circle(pos, r, Color(gold.r, gold.g, gold.b, a))
