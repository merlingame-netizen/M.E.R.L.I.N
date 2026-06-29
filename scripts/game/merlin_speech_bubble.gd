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
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_W, 0.0)
	_label.add_theme_color_override("font_color", COL_TEXT)
	_label.add_theme_font_size_override("font_size", MerlinVisual.FS_CAPTION)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	set_process(true)


func is_active() -> bool:
	return _active


# Affiche une réplique au-dessus de la tête. `follow` renvoie la position écran de la tête à chaque frame.
# `mood` (neutral/surprise/angry) → pitch de la voix procédurale.
func show_line(text: String, follow: Callable, mood: String = "neutral") -> void:
	var t: String = text.strip_edges()
	if t.is_empty():
		return
	_follow = follow
	_mood = mood
	_label.text = t
	_active = true
	visible = true
	_panel.reset_size()
	_update_follow()  # placement immédiat (évite un flash au mauvais endroit)
	var rm: bool = MerlinVisual.reduced_motion
	var m: float = MerlinVisual.motion()
	_voiced_chars = 0
	_voicing = not rm and MerlinVoicePrefs.is_enabled()  # voix synchronisée à la frappe (off si reduced_motion)
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


func _process(_delta: float) -> void:
	# Suivi du flottement de la tête (figé en reduced_motion : placement unique au show).
	if _active and not MerlinVisual.reduced_motion:
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
					MerlinAudio.play_voice(_voice_pitch())
		if _label.visible_ratio >= 0.999:
			_voicing = false


# Pitch de la voix selon l'humeur (grave-mystérieux par défaut) + légère variation.
func _voice_pitch() -> float:
	var base: float = 0.95
	match _mood:
		"surprise": base = 1.18
		"angry": base = 0.82
	return base * randf_range(0.94, 1.06)


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
func _draw() -> void:
	var psize: Vector2 = _panel.size
	if psize.x < 4.0:
		return
	var y0: float = psize.y - 1.0
	var tip: Vector2 = Vector2(_tail_x, psize.y + TAIL_H)
	draw_colored_polygon(PackedVector2Array([
		Vector2(_tail_x - TAIL_HALF, y0), Vector2(_tail_x + TAIL_HALF, y0), tip]), COL_BG)
	draw_line(Vector2(_tail_x - TAIL_HALF, y0), tip, COL_BORDER, 2.0, true)
	draw_line(Vector2(_tail_x + TAIL_HALF, y0), tip, COL_BORDER, 2.0, true)
