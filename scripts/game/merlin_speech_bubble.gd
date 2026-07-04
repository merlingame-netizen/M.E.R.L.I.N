class_name MerlinSpeechBubble
extends Control
## Bulle de parole de Merlin au menu (user 2026-06-29) : parchemin CREAM/bord GOLD AU-DESSUS de la
## tête, machine à écrire, suivi de la tête (flottement), queue vers le bas, auto-fondu. Le texte
## vient à 100% du LLM (merlin_menu_voice). DA flat : couleurs canon MerlinVisual (zéro hex).

const COL_BG: Color = MerlinVisual.CREAM
const COL_BORDER: Color = MerlinVisual.GOLD
const COL_TEXT: Color = MerlinVisual.INK
const MAX_W: float = 360.0          # largeur max du texte (autowrap)
const PAD: float = 14.0
const TAIL_H: float = 13.0          # hauteur de la queue (triangle vers la tête)
const TAIL_HALF: float = 11.0
const LIFT: float = 20.0            # marge au-dessus du sommet de la tête
const HOLD_S: float = 7.0           # durée d'affichage (cadence modérée) avant auto-fondu
const TYPE_CPS: float = 42.0        # vitesse machine à écrire (caractères/seconde)

var _panel: PanelContainer
var _label: Label
var _follow: Callable = Callable()  # () -> {"pos": Vector2 (écran), "hr": float} ; {} si indisponible
var _tail_x: float = 30.0           # abscisse locale de la queue (sous la tête)
var _active: bool = false
var _life_tw: Tween = null
# v10.20 — VOIX procédurale (R124) : un blip toutes les ~2 lettres pendant la frappe, pitch selon l'humeur.
var _mood: String = "neutral"
var _voiced_chars: int = 0
var _voicing: bool = false
var _voice_session: int = 0   # voix UNIQUE (anti-superposition) — ouverte au show_line
# v10.22 (user) — placement ALÉATOIRE : la bulle apparaît sur l'un de 5 emplacements libres de l'écran
# (hors colonne de boutons/wordmark) au lieu de suivre la tête ; identifiée par son EN-TÊTE (yeux + MERLIN).
const SLOTS: Array = [Vector2(0.55, 0.10), Vector2(0.66, 0.52), Vector2(0.38, 0.72), Vector2(0.12, 0.74), Vector2(0.42, 0.08)]
var _random_place: bool = false
var _last_slot: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20  # au-dessus de la scène, sous d'éventuels modaux (glitch=95)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.set_border_width_all(2)
	sb.border_color = COL_BORDER
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(PAD)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	# v10.22 — EN-TÊTE d'identification : deux mini-barres bleues (les yeux signature) + « MERLIN » +
	# filet — la bulle est attribuable d'un coup d'œil même placée loin de lui.
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)
	var head_row: HBoxContainer = HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 5)
	head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var eye: ColorRect = ColorRect.new()
		eye.color = MerlinVisual.EYE_NEUTRAL
		eye.custom_minimum_size = Vector2(4, 14)
		eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head_row.add_child(eye)
	var who: Label = Label.new()
	who.text = "  MERLIN"
	who.add_theme_color_override("font_color", MerlinVisual.GOLD_DARK)
	who.add_theme_font_size_override("font_size", 14)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(who)
	vb.add_child(head_row)
	var sep: ColorRect = ColorRect.new()
	sep.color = Color(MerlinVisual.GOLD_DARK.r, MerlinVisual.GOLD_DARK.g, MerlinVisual.GOLD_DARK.b, 0.45)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sep)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_W, 0.0)
	_label.add_theme_color_override("font_color", COL_TEXT)
	_label.add_theme_font_size_override("font_size", MerlinVisual.FS_CAPTION)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_label)
	set_process(true)


func is_active() -> bool:
	return _active


# Affiche une réplique au-dessus de la tête. `follow` renvoie la position écran de la tête à chaque frame.
# `mood` (neutral/surprise/angry) → pitch de la voix procédurale.
func show_line(text: String, follow: Callable, mood: String = "neutral", random_place: bool = false) -> void:
	var t: String = text.strip_edges()
	if t.is_empty():
		return
	_follow = follow
	_mood = mood
	_random_place = random_place
	_label.text = t
	_active = true
	visible = true
	_panel.reset_size()
	if _random_place:
		_place_random()  # v10.22 : emplacement aléatoire (identification par l'en-tête, pas par la queue)
	else:
		_update_follow()  # placement immédiat (évite un flash au mauvais endroit)
	var rm: bool = MerlinVisual.reduced_motion
	var m: float = MerlinVisual.motion()
	_voiced_chars = 0
	_voicing = not rm and MerlinVoicePrefs.is_enabled()  # voix synchronisée à la frappe (off si reduced_motion)
	if _voicing:
		_voice_session = MerlinAudio.begin_voice()  # prend la main sur la voix (coupe un locuteur précédent)
	if _life_tw != null and _life_tw.is_valid():
		_life_tw.kill()
	modulate.a = 0.0
	_label.visible_ratio = 1.0 if rm else 0.0
	_life_tw = create_tween()
	_life_tw.tween_property(self, "modulate:a", 1.0, 0.25 * m).set_trans(Tween.TRANS_SINE)
	if not rm:
		var n: int = _label.get_total_character_count()
		var type_dur: float = clampf(float(n) / TYPE_CPS, 0.4, 2.4)
		_life_tw.parallel().tween_property(_label, "visible_ratio", 1.0, type_dur).set_trans(Tween.TRANS_LINEAR)
	_life_tw.tween_interval(HOLD_S * (0.7 if rm else 1.0))
	_life_tw.tween_property(self, "modulate:a", 0.0, 0.45 * m).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_life_tw.tween_callback(_finish)


func _finish() -> void:
	_active = false
	visible = false


# v10.22 — Emplacement aléatoire : slot tiré parmi SLOTS (jamais deux fois le même d'affilée), clampé
# aux bords. La bulle ne suit plus la tête et n'a pas de queue — l'en-tête l'identifie.
func _place_random() -> void:
	var psize: Vector2 = _panel.size
	if psize.x < 4.0:
		psize = _panel.get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	var si: int = randi_range(0, SLOTS.size() - 1)
	if si == _last_slot:
		si = (si + 1) % SLOTS.size()
	_last_slot = si
	var anchor: Vector2 = Vector2(vp.x * (SLOTS[si] as Vector2).x, vp.y * (SLOTS[si] as Vector2).y)
	custom_minimum_size = psize
	size = psize
	global_position = Vector2(
		clampf(anchor.x - psize.x * 0.5, 12.0, maxf(12.0, vp.x - psize.x - 12.0)),
		clampf(anchor.y, 8.0, maxf(8.0, vp.y - psize.y - 8.0)))
	queue_redraw()


func _process(_delta: float) -> void:
	# Suivi du flottement de la tête (figé en reduced_motion ; jamais en placement aléatoire).
	if _active and not _random_place and not MerlinVisual.reduced_motion:
		_update_follow()
	# Voix : un blip toutes les ~2 lettres révélées (saute espaces/ponctuation), pitch selon l'humeur.
	if _voicing and _active:
		var total: int = _label.get_total_character_count()
		var cur: int = int(_label.visible_ratio * float(total))
		if cur - _voiced_chars >= 2:
			var idx: int = mini(cur - 1, _label.text.length() - 1)
			_voiced_chars = cur
			if idx >= 0:
				var ch: String = _label.text[idx]
				if ch != " " and "\n\t.,;:!?…»«-—'\"".find(ch) == -1:
					MerlinAudio.play_voice_session(_voice_session, _mood)  # voix unique (anti-superposition)
		if _label.visible_ratio >= 0.999:
			_voicing = false


func _update_follow() -> void:
	if not _follow.is_valid():
		return
	var info: Dictionary = _follow.call()
	if not (info is Dictionary) or info.is_empty():
		return
	var head: Vector2 = info.get("pos", Vector2.ZERO)
	var hr: float = float(info.get("hr", 20.0))
	var psize: Vector2 = _panel.size
	if psize.x < 4.0:
		psize = _panel.get_combined_minimum_size()
	if psize.x < 4.0:
		return
	var bubble_h: float = psize.y + TAIL_H
	custom_minimum_size = Vector2(psize.x, bubble_h)
	size = Vector2(psize.x, bubble_h)
	var vp: Vector2 = get_viewport_rect().size
	var want_x: float = clampf(head.x - psize.x * 0.5, 12.0, maxf(12.0, vp.x - psize.x - 12.0))
	var want_y: float = maxf(head.y - hr - LIFT - bubble_h, 8.0)
	global_position = Vector2(want_x, want_y)
	_tail_x = clampf(head.x - want_x, TAIL_HALF + 4.0, psize.x - TAIL_HALF - 4.0)
	queue_redraw()


# Queue (triangle) du parchemin vers la tête, dessinée SOUS le panneau (le panneau la recouvre d'1px).
# En placement aléatoire : PAS de queue (elle pointerait dans le vide) — l'en-tête identifie Merlin.
func _draw() -> void:
	if _random_place:
		return
	var psize: Vector2 = _panel.size
	if psize.x < 4.0:
		return
	var y0: float = psize.y - 1.0
	var tip: Vector2 = Vector2(_tail_x, psize.y + TAIL_H)
	draw_colored_polygon(PackedVector2Array([
		Vector2(_tail_x - TAIL_HALF, y0), Vector2(_tail_x + TAIL_HALF, y0), tip]), COL_BG)
	draw_line(Vector2(_tail_x - TAIL_HALF, y0), tip, COL_BORDER, 2.0, true)
	draw_line(Vector2(_tail_x + TAIL_HALF, y0), tip, COL_BORDER, 2.0, true)
