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


# v10.19 — Transition « zoom vers Merlin qui parle » (user 2026-06-29) : couvre la scène, révèle Merlin
# zoomé qui prononce `line` (réplique LLM PRÉ-FETCHÉE — pas de génération ici, single-flight préservé),
# zoom qui pousse vers lui, puis enchaîne sur `path`. `gate` optionnel : on attend ce prédicat (cap 6s)
# avant le swap (sert au montage d'arc). Utilisé pour Nouvelle Partie + Continuer (remplace le voile).
func change_scene_merlin(path: String, line: String, gate: Callable = Callable()) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("[MerlinTransition] scene not found: %s" % path)
		return
	_busy = true
	var m: float = MerlinVisual.motion()
	var rm: bool = MerlinVisual.reduced_motion
	MerlinAudio.play_sfx("ink_wash")
	MerlinAudio.stop_music(0.9 * m)  # coupe le flux de base (la scène suivante relance le sien)

	# 1) Voile sombre qui couvre la scène courante.
	var cover: ColorRect = ColorRect.new()
	cover.color = MerlinVisual.BG_DEEP
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.modulate.a = 0.0
	_overlay.add_child(cover)
	var t_cover: Tween = create_tween()
	t_cover.tween_property(cover, "modulate:a", 1.0, 0.35 * m).set_trans(Tween.TRANS_SINE)
	await t_cover.finished

	# 2) Merlin zoomé (décor caché → portrait) + bulle de parole.
	var art: MerlinSceneArt = MerlinSceneArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(art)
	art.set_menu_decor(true)
	art.set_beat("Climax")
	art.set_season(MerlinSceneArt.season_for_now())
	var hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	art.set_time_of_day(hour)
	art.set_decor_reveal(0.0)
	art.set_figure_reveal(1.0)
	art.set_animated(true)
	await get_tree().process_frame  # laisse le layout calculer la taille avant le pivot
	var ss: Vector2 = art.size
	if ss.x > 4.0:
		art.pivot_offset = Vector2(ss.x * 0.5, ss.y * 0.37)  # pivot = yeux
	var z1: float = 1.0 if rm else 1.7
	art.scale = Vector2.ONE
	art.modulate.a = 0.0
	var bubble: MerlinSpeechBubble = MerlinSpeechBubble.new()
	bubble.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_overlay.add_child(bubble)
	var t_in: Tween = create_tween().set_parallel(true)
	t_in.tween_property(art, "modulate:a", 1.0, 0.4 * m).set_trans(Tween.TRANS_SINE)
	if not rm:
		t_in.tween_property(art, "scale", Vector2(z1, z1), 2.2 * m).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var spoken: String = line.strip_edges()
	if spoken == "":
		spoken = "Le sentier s'ouvre, Voyageur… avançons."  # filet si la réplique LLM n'était pas prête
	var mood: String = MerlinSceneArt.mood_for_text(spoken)
	art.set_eye_mood(mood)
	bubble.show_line(spoken, _montage_head.bind(art), mood)

	# 3) Laisse parler, + éventuel gate (montage d'arc) borné.
	await get_tree().create_timer((1.2 if rm else 2.6) * m).timeout
	if gate.is_valid():
		var waited: float = 0.0
		while not bool(gate.call()) and waited < 6.0:
			await get_tree().create_timer(0.15).timeout
			waited += 0.15

	# 4) Fondu du montage → swap → révélation.
	var t_out: Tween = create_tween().set_parallel(true)
	t_out.tween_property(art, "modulate:a", 0.0, 0.35 * m).set_trans(Tween.TRANS_SINE)
	t_out.tween_property(bubble, "modulate:a", 0.0, 0.25 * m).set_trans(Tween.TRANS_SINE)
	await t_out.finished
	if is_instance_valid(art):
		art.queue_free()
	if is_instance_valid(bubble):
		bubble.queue_free()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var t_rev: Tween = create_tween()
	t_rev.tween_property(cover, "modulate:a", 0.0, 0.5 * m).set_trans(Tween.TRANS_SINE)
	await t_rev.finished
	if is_instance_valid(cover):
		cover.queue_free()
	_busy = false


# Position ÉCRAN de la tête de Merlin dans une MerlinSceneArt SCALÉE (pour ancrer la bulle du montage).
func _montage_head(art: MerlinSceneArt) -> Dictionary:
	if art == null or not is_instance_valid(art):
		return {}
	var h: Vector2 = art._fig_head
	if h == Vector2.ZERO:
		return {}
	var piv: Vector2 = art.pivot_offset
	var s: float = art.scale.x
	var screen: Vector2 = art.global_position + piv + (h - piv) * s  # transforme par le scale autour du pivot
	return {"pos": screen, "hr": art._fig_hr * s}


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
