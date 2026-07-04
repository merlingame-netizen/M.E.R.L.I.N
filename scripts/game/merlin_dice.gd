class_name MerlinDice
extends Control
## v10.23 (user) — DÉ 2D fausse-3D : culbute (faces qui défilent + squash/rotation) → ralenti → pose
## sur la face tirée, avec flash d'or si le sort a souri (die_mod > 0), gris muet sinon. Le liseré porte
## la RARETÉ de la carte principale (c'est ELLE qui donne la qualité du dé — enfin lisible, O2).
## Tout procédural (_draw), palette canon, durées ×motion(), reduced_motion = face finale directe.

signal done

const SIZE_PX: float = 96.0
const TUMBLE_S: float = 0.55     # phase 1 : culbute rapide
const SLOW_S: float = 0.65       # phase 2 : le défilement ralentit
const SETTLE_S: float = 0.35     # phase 3 : pose + rebond
const PIP_R: float = 7.0

var _face: int = 1               # face AFFICHÉE (défile pendant la culbute)
var _final_face: int = 1
var _die_mod: int = 0
var _rim: Color = MerlinVisual.BORDER_BRUN
var _squash: Vector2 = Vector2.ONE
var _settled: bool = false
var _flash: float = 0.0          # 0-1 : éclat d'or à la pose (si le sort sourit)
var _static_mode: bool = false   # mode INDICE (près du bouton Résoudre) : face « ? », aucun roll


static func rim_for_rarity(rarity: String) -> Color:
	match rarity:
		"Rare": return MerlinVisual.RARE_BLUE
		"Épique": return MerlinVisual.RARITY_EPIC
		"Mythique": return MerlinVisual.GOLD
	return MerlinVisual.BORDER_BRUN


# Lance le dé au-dessus du parent : culbute → ralenti → pose. `await dice.done` puis auto-fondu.
static func roll(parent: Control, final_face: int, rarity: String, die_mod: int) -> MerlinDice:
	var d: MerlinDice = MerlinDice.new()
	d._final_face = clampi(final_face, 1, 6)
	d._die_mod = die_mod
	d._rim = rim_for_rarity(rarity)
	d.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	d.size = Vector2(SIZE_PX, SIZE_PX)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.z_index = 30
	parent.add_child(d)
	var vp: Vector2 = parent.get_viewport_rect().size
	d.position = Vector2(vp.x * 0.5 - SIZE_PX * 0.5, vp.y * 0.34 - SIZE_PX * 0.5)
	d.pivot_offset = Vector2(SIZE_PX, SIZE_PX) * 0.5
	d._run()
	return d


# Mode INDICE statique (feedforward « ce choix jettera un dé ») : petite face « ? » au liseré de rareté.
static func hint(size_px: float = 26.0) -> MerlinDice:
	var d: MerlinDice = MerlinDice.new()
	d._static_mode = true
	d.custom_minimum_size = Vector2(size_px, size_px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func set_hint_rarity(rarity: String) -> void:
	_rim = rim_for_rarity(rarity)
	queue_redraw()


func _run() -> void:
	var m: float = MerlinVisual.motion()
	if MerlinVisual.reduced_motion:
		_face = _final_face
		_settled = true
		_flash = 1.0 if _die_mod > 0 else 0.0
		queue_redraw()
		await get_tree().create_timer(0.5).timeout
		_fade_out()
		return
	MerlinAudio.play_sfx("card_pick", 0.7)  # petit claquement de lancer (recette existante, grave)
	# Phase 1+2 — culbute : les faces défilent (vite puis lentement), squash/rotation fausse-3D.
	var t0: int = Time.get_ticks_msec()
	var total_ms: int = int((TUMBLE_S + SLOW_S) * 1000.0 * m)
	var next_flip_ms: int = 0
	var flip_gap: float = 60.0
	modulate.a = 0.0
	var ain: Tween = create_tween()
	ain.tween_property(self, "modulate:a", 1.0, 0.18 * m)
	while Time.get_ticks_msec() - t0 < total_ms and is_inside_tree():
		var now: int = Time.get_ticks_msec() - t0
		var prog: float = float(now) / float(total_ms)
		if now >= next_flip_ms:
			flip_gap = lerpf(60.0, 240.0, prog * prog)  # le défilement RALENTIT (fausse inertie)
			next_flip_ms = now + int(flip_gap)
			var nf: int = randi_range(1, 6)
			_face = nf if nf != _face else (nf % 6) + 1
			MerlinAudio.play_sfx("slider_tick", 1.2 - prog * 0.4)
		rotation = sin(float(now) * 0.011) * (0.5 - prog * 0.42)          # bascule qui s'amortit
		_squash = Vector2(1.0 + sin(float(now) * 0.02) * (0.16 - prog * 0.13),
			1.0 - sin(float(now) * 0.02) * (0.16 - prog * 0.13))          # respiration fausse-3D
		queue_redraw()
		await get_tree().process_frame
	# Phase 3 — pose : face finale, rebond squash, éclat.
	_face = _final_face
	_settled = true
	rotation = 0.0
	MerlinAudio.play_sfx("seal_stamp", 1.1)
	var settle: Tween = create_tween()
	settle.tween_method(func(v: float) -> void:
		_squash = Vector2(1.0 + 0.22 * (1.0 - v), 1.0 - 0.22 * (1.0 - v))
		queue_redraw(), 0.0, 1.0, SETTLE_S * m).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _die_mod > 0:
		var fl: Tween = create_tween()
		fl.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 0.0, 1.0, 0.20 * m)
		fl.tween_interval(0.5 * m)
		fl.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 1.0, 0.6, 0.3 * m)
	await settle.finished
	await get_tree().create_timer(0.55 * m).timeout
	done.emit()
	_fade_out()


# (Jamais appelé en mode indice — l'indice vit avec le bouton Résolution, pas de cycle de vie propre.)
func _fade_out() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var out: Tween = create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.30 * MerlinVisual.motion())
	out.tween_callback(queue_free)


func _draw() -> void:
	var s: Vector2 = size
	var half: Vector2 = s * 0.5
	var ext: Vector2 = half * 0.92 * _squash
	var face_col: Color = MerlinVisual.CREAM
	if _settled and _die_mod <= 0 and not _static_mode:
		face_col = MerlinVisual.CREAM.lerp(MerlinVisual.INK_DIM, 0.35)  # le sort resta muet — face terne
	# Ombre portée (ancre le dé), face arrondie, liseré rareté, éclat d'or à la pose.
	draw_rect(Rect2(half - ext + Vector2(3, 5), ext * 2.0), Color(0, 0, 0, 0.30), true)
	var r: Rect2 = Rect2(half - ext, ext * 2.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = face_col
	sb.set_corner_radius_all(int(ext.x * 0.22))
	sb.set_border_width_all(3 if not _static_mode else 2)
	sb.border_color = _rim if _flash <= 0.0 else _rim.lerp(MerlinVisual.GOLD, _flash)
	draw_style_box(sb, r)
	if _flash > 0.0:
		draw_rect(r.grow(4.0 * _flash), Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, 0.25 * _flash), false, 3.0)
	# Pips (ou « ? » en mode indice).
	var pip: Color = MerlinVisual.INK
	if _static_mode:
		draw_circle(half, ext.x * 0.16, Color(pip.r, pip.g, pip.b, 0.8))
		return
	var k: float = ext.x * 0.42
	var pts: Array = []
	match _face:
		1: pts = [Vector2.ZERO]
		2: pts = [Vector2(-k, -k), Vector2(k, k)]
		3: pts = [Vector2(-k, -k), Vector2.ZERO, Vector2(k, k)]
		4: pts = [Vector2(-k, -k), Vector2(k, -k), Vector2(-k, k), Vector2(k, k)]
		5: pts = [Vector2(-k, -k), Vector2(k, -k), Vector2.ZERO, Vector2(-k, k), Vector2(k, k)]
		6: pts = [Vector2(-k, -k), Vector2(k, -k), Vector2(-k, 0), Vector2(k, 0), Vector2(-k, k), Vector2(k, k)]
	var pr: float = maxf(ext.x * 0.11, 3.0)
	for p in pts:
		draw_circle(half + (p as Vector2) * _squash, pr, pip)
