class_name MerlinSceneArt
extends Control
## v10.16 — Décor vivant : silhouettes plates + lune réactive + god rays + 18 motes 3 catégories
## + brume parallaxe réactive + arbres réactifs. DA flat rétro-minimaliste (2026-05-26).

const COL_SCENE_BG: Color = MerlinVisual.SCENE_BG
const COL_SIL: Color = MerlinVisual.SILHOUETTE
const COL_MOON: Color = MerlinVisual.CREAM
const COL_STONE: Color = MerlinVisual.INK
const COL_INK: Color = MerlinVisual.SILHOUETTE
const COL_MIST: Color = MerlinVisual.MIST

var _beat: String = "Exploration"
var _menu_decor: bool = false
var _animated: bool = false
var _t: float = 0.0

const HALO_SPEED_IDLE: float = 0.45
const HALO_SPEED_THINK: float = 1.6
var _thinking: bool = false
var _halo_phase: float = 0.0

var _moon_flash: float = 0.0
var _moon_dim: float = 0.0
var _mist_factor: float = 1.0
var _tree_sway: float = 0.0
var _react_tw: Tween = null

# v10.18 (menu Phase 2) — densité de motes + parallaxe + aura de curseur, pilotés par merlin_menu.gd.
var _mote_density: float = 1.0
var _parallax: Vector2 = Vector2.ZERO
var _cursor_pos: Vector2 = Vector2.ZERO
var _cursor_inside: bool = false

# v10.18 — Variation selon l'heure RÉELLE (aube/jour/crépuscule/nuit) : teinte du ciel + chaleur de
# la lune. Dérivé des couleurs canon (zéro hex). Défaut = nuit canon → in-game inchangé.
var _tod_sky: Color = MerlinVisual.SCENE_BG
var _tod_moon_warm: float = 0.0

# v10.18 — Étoiles filantes occasionnelles (MENU uniquement) : traînée crème le long d'un court arc.
var _shoot_t: float = -1.0            # <0 = inactive ; sinon progression 0→1
var _shoot_next: float = 4.0          # compte à rebours avant la prochaine
var _shoot_a: Vector2 = Vector2.ZERO  # départ (normalisé 0-1)
var _shoot_b: Vector2 = Vector2.ZERO  # arrivée (normalisé 0-1)


func set_beat(beat_type: String) -> void:
	_beat = beat_type
	queue_redraw()


func set_menu_decor(on: bool) -> void:
	_menu_decor = on
	queue_redraw()


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	queue_redraw()


func set_thinking(on: bool) -> void:
	if on == _thinking:
		return
	_thinking = on
	queue_redraw()


func flash_moon() -> void:
	if _react_tw != null and _react_tw.is_valid():
		_react_tw.kill()
	_moon_dim = 0.0
	_moon_flash = 1.0
	_react_tw = create_tween()
	_react_tw.tween_property(self, "_moon_flash", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func dim_moon() -> void:
	if _react_tw != null and _react_tw.is_valid():
		_react_tw.kill()
	_moon_flash = 0.0
	_moon_dim = 0.6
	_react_tw = create_tween()
	_react_tw.tween_property(self, "_moon_dim", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func thicken_mist() -> void:
	_mist_factor = 2.2
	var tw: Tween = create_tween()
	tw.tween_property(self, "_mist_factor", 1.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func sway_trees() -> void:
	_tree_sway = 4.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "_tree_sway", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion() * 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# v10.18 (menu Phase 2) — réactions composées + contrôles continus pilotés par merlin_menu.gd.

# Souffle de forêt : les arbres oscillent ET la brume s'épaissit brièvement (réutilise l'existant).
func trigger_gust() -> void:
	sway_trees()
	thicken_mist()


# Pulse rare de l'orbe lunaire (réutilise le flash réactif).
func moon_pulse() -> void:
	flash_moon()


# Densité de motes (1.0 = canon) — le menu monte à ~1.35 pour un fond plus vivant. Borné.
func set_mote_density(factor: float) -> void:
	_mote_density = clampf(factor, 0.0, 3.0)
	queue_redraw()


# Décalage de parallaxe (px) suivant le curseur : lune/motes = couche lointaine (facteur < 1) dans _draw.
func set_parallax(offset: Vector2) -> void:
	_parallax = offset
	queue_redraw()


# Curseur (coordonnées locales au node) + dedans/dehors → aura GOLD douce près du curseur dans _draw.
func set_cursor(pos: Vector2, inside: bool) -> void:
	_cursor_pos = pos
	_cursor_inside = inside
	queue_redraw()


# v10.18 — Le décor change selon l'heure réelle (passer Time...["hour"]). 4 périodes : la teinte du
# ciel et la chaleur de la lune varient ; le menu reste nocturne-merveilleux (variations subtiles).
# Teintes DÉRIVÉES des couleurs canon (zéro hex hors merlin_visual.gd).
func set_time_of_day(hour: int) -> void:
	var h: int = clampi(hour, 0, 23)
	if h >= 5 and h < 9:        # aube — chaleur dorée naissante
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.GOLD, 0.10)
		_tod_moon_warm = 0.55
	elif h >= 9 and h < 17:     # jour — ciel plus froid/clair, lune ténue
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.RARE_BLUE, 0.13)
		_tod_moon_warm = 0.20
	elif h >= 17 and h < 21:    # crépuscule — violet
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.VIOLET, 0.14)
		_tod_moon_warm = 0.65
	else:                        # nuit — bleu profond, lune froide brillante
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.RARE_BLUE, 0.05)
		_tod_moon_warm = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_halo_phase += delta * (HALO_SPEED_THINK if _thinking else HALO_SPEED_IDLE)
	if _menu_decor and not MerlinVisual.reduced_motion:
		_update_shooting_star(delta)
	queue_redraw()


# Étoile filante (menu) : minuterie aléatoire (6-13s) puis traversée ~0.85s d'un court arc.
func _update_shooting_star(delta: float) -> void:
	if _shoot_t < 0.0:
		_shoot_next -= delta
		if _shoot_next <= 0.0:
			_shoot_next = randf_range(6.0, 13.0)
			_shoot_t = 0.0
			_shoot_a = Vector2(randf_range(0.10, 0.62), randf_range(0.05, 0.26))
			_shoot_b = _shoot_a + Vector2(randf_range(0.18, 0.32), randf_range(0.09, 0.17))
	else:
		_shoot_t += delta / 0.85
		if _shoot_t > 1.0:
			_shoot_t = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 4.0 or s.y <= 4.0:
		return
	var w: float = s.x
	var h: float = s.y
	var rm: bool = MerlinVisual.reduced_motion

	draw_rect(Rect2(Vector2.ZERO, s), _tod_sky, true)  # v10.18 : teinte du ciel selon l'heure

	var moon_c: Vector2 = Vector2(w * 0.5, h * 0.40) + _parallax * 0.5  # parallaxe : la lune = couche lointaine
	var moon_r: float = minf(w, h) * 0.13

	# God rays (behind everything except background)
	if _animated and not rm:
		for ri in 3:
			var angle: float = -0.35 + float(ri) * 0.35 + sin(_t * 0.03 + float(ri) * 1.7) * 0.08
			var top_half: float = w * 0.018
			var bot_half: float = w * 0.06
			var ray_len: float = h * 0.50
			var ca: float = cos(angle)
			var sa: float = sin(angle)
			var tip: Vector2 = moon_c + Vector2(sa, ca) * ray_len
			var pts: PackedVector2Array = PackedVector2Array([
				moon_c + Vector2(-ca * top_half, sa * top_half),
				moon_c + Vector2(ca * top_half, -sa * top_half),
				tip + Vector2(ca * bot_half, -sa * bot_half),
				tip + Vector2(-ca * bot_half, sa * bot_half),
			])
			var ra: float = 0.025 + 0.010 * sin(_t * 0.12 + float(ri) * 2.1)
			draw_colored_polygon(pts, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, ra))

	# Moon halos + disk
	if _animated:
		var halo_outer_r: float = moon_r * (1.45 + 0.08 * sin(_halo_phase * 0.6))
		var halo_outer_a: float = 0.025 + 0.012 * (0.5 + 0.5 * sin(_halo_phase * 0.6))
		if rm:
			halo_outer_a *= 0.5
		draw_circle(moon_c, halo_outer_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_outer_a))
		var halo_r: float = moon_r * (1.22 + 0.06 * sin(_halo_phase))
		var halo_a: float = 0.05 + 0.025 * (0.5 + 0.5 * sin(_halo_phase))
		draw_circle(moon_c, halo_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_a))

	# Moon flash/dim reactive (+ chaleur selon l'heure, v10.18)
	var moon_col: Color = COL_MOON.lerp(MerlinVisual.GOLD, _tod_moon_warm * 0.35)
	if _moon_flash > 0.01:
		moon_col = moon_col.lerp(Color.WHITE, _moon_flash * 0.6)
	if _moon_dim > 0.01:
		moon_col = moon_col.lerp(COL_SCENE_BG, _moon_dim)
	draw_circle(moon_c, moon_r, moon_col)

	# v10.18 — étoile filante (menu) : traînée crème qui apparaît/disparaît le long de l'arc.
	if _menu_decor and _shoot_t >= 0.0 and _shoot_t <= 1.0 and not rm:
		var sh_head: Vector2 = Vector2(lerpf(_shoot_a.x, _shoot_b.x, _shoot_t) * w, lerpf(_shoot_a.y, _shoot_b.y, _shoot_t) * h)
		var sh_tt: float = maxf(_shoot_t - 0.14, 0.0)
		var sh_tail: Vector2 = Vector2(lerpf(_shoot_a.x, _shoot_b.x, sh_tt) * w, lerpf(_shoot_a.y, _shoot_b.y, sh_tt) * h)
		var sh_a: float = sin(_shoot_t * PI) * 0.7
		draw_line(sh_tail, sh_head, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, sh_a), 2.0, true)
		draw_circle(sh_head, 2.6, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, sh_a))

	# Background trees (with reactive sway)
	_tree(Vector2(w * 0.12 + _tree_sway * 0.8, h), h * 0.74, w)
	_tree(Vector2(w * 0.27 + _tree_sway * 0.5, h), h * 0.60, w)
	_tree(Vector2(w * 0.80 - _tree_sway * 0.5, h), h * 0.66, w)
	_tree(Vector2(w * 0.91 - _tree_sway * 0.8, h), h * 0.78, w)

	# Menhir
	_menhir(Vector2(w * 0.66, h * 0.46), Vector2(w * 0.052, h * 0.40))

	# Thinking mote
	if _thinking and _animated:
		var menhir_c: Vector2 = Vector2(w * 0.686, h * 0.66)
		var mote: Vector2 = menhir_c + Vector2(cos(_t * 2.2) * w * 0.045, sin(_t * 2.2) * h * 0.10)
		draw_circle(mote, maxf(minf(w, h) * 0.008, 2.5), MerlinVisual.GOLD)

	# Figure
	if _beat == "Rencontre" or _beat == "Climax" or _beat == "Dilemme":
		_figure(Vector2(w * 0.5, h * 0.84), h * 0.50, w * 0.075)

	# 18 ambient motes (3 categories: firefly/dust/ember)
	if _animated:
		var mcount: int = int(MerlinVisual.MOTE_COUNT_AMBIENT * _mote_density)  # v10.18 : densité pilotée
		for mi in mcount:
			var mf: float = float(mi)
			var cat: int = mi % 3
			var base_x: float = w * fmod(mf * 0.618 + 0.1, 1.0)
			var base_y: float
			var mr: float
			var speed: float
			var ma: float
			match cat:
				0:
					base_y = h * (0.15 + 0.25 * fmod(mf * 0.382, 1.0))
					mr = maxf(minf(w, h) * 0.003, 1.5)
					speed = 0.12 + mf * 0.03
					var flicker: float = sin(_t * (2.5 + mf * 0.7) + mf * 3.1)
					ma = 0.08 + 0.14 * maxf(flicker, 0.0)
				1:
					base_y = h * (0.40 + 0.25 * fmod(mf * 0.271, 1.0))
					mr = maxf(minf(w, h) * 0.005, 2.0)
					speed = 0.20 + mf * 0.02
					ma = lerpf(0.10, 0.18, fmod(mf * 0.5, 1.0)) * (0.6 + 0.4 * sin(_t * 0.45 + mf))
				_:
					base_y = h * (0.70 + 0.20 * fmod(mf * 0.437, 1.0))
					mr = maxf(minf(w, h) * 0.007, 2.5)
					speed = 0.08 + mf * 0.015
					ma = lerpf(0.14, 0.26, fmod(mf * 0.3, 1.0)) * (0.5 + 0.5 * sin(_t * 0.3 + mf * 1.9))
			var mx: float = base_x + sin(_t * speed + mf * 1.7) * w * 0.030
			var my: float = base_y + cos(_t * (speed * 0.7) + mf * 2.3) * h * 0.020
			if cat == 1:
				mx += _t * 0.8
				mx = fmod(mx, w)
			if rm:
				ma *= 0.5
			draw_circle(Vector2(mx, my) + _parallax, mr, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, ma))

	# Ground contour
	if _animated:
		var gnd_pts: PackedVector2Array = PackedVector2Array()
		var gnd_steps: int = 16
		for gi in gnd_steps + 1:
			var gx: float = float(gi) / float(gnd_steps) * w
			var gy: float = h * 0.88 + sin(gx * 0.012 + _t * 0.1) * h * 0.02
			gnd_pts.append(Vector2(gx, gy))
		gnd_pts.append(Vector2(w, h))
		gnd_pts.append(Vector2(0.0, h))
		var gnd_a: float = 0.35
		if rm:
			gnd_a *= 0.5
		draw_colored_polygon(gnd_pts, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, gnd_a))

	# Mist layers (reactive via _mist_factor)
	var mist_layers: Array = [
		{"y": 0.55, "speed": 0.12, "alpha": 0.10, "width": 0.55},
		{"y": 0.66, "speed": 0.18, "alpha": 0.14, "width": 0.60},
		{"y": 0.78, "speed": 0.25, "alpha": 0.18, "width": 0.65},
	]
	for li in mist_layers.size():
		var ml: Dictionary = mist_layers[li]
		var y: float = h * float(ml["y"])
		var bw: float = w * float(ml["width"])
		var bx: float = w * 0.5 - bw * 0.5
		var alpha: float = float(ml["alpha"]) * _mist_factor
		if _animated:
			bx += sin(_t * float(ml["speed"]) + float(li) * 2.1) * w * 0.020
		if rm:
			alpha *= 0.5
		draw_rect(Rect2(Vector2(bx, y), Vector2(bw, h * 0.035)), Color(COL_MIST.r, COL_MIST.g, COL_MIST.b, alpha), true)

	# Foreground silhouettes (2 edge trees, slow drift)
	if _animated:
		var fg_a: float = 0.12
		if rm:
			fg_a = 0.08
		var fg_drift: float = 0.0
		if not rm:
			fg_drift = sin(_t * 0.06) * w * 0.008
		_tree(Vector2(w * 0.02 - fg_drift, h), h * 0.90, w, fg_a)
		_tree(Vector2(w * 0.97 + fg_drift, h), h * 0.85, w, fg_a)

	# v10.18 (menu) — aura douce qui suit le curseur : 3 cercles GOLD très discrets (off en reduced_motion).
	if _animated and _cursor_inside and not rm:
		for ck in 3:
			var aura_r: float = minf(w, h) * 0.045 * (1.0 + float(ck) * 0.9)
			var aura_a: float = 0.05 / (float(ck) + 1.0)
			draw_circle(_cursor_pos, aura_r, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, aura_a))

	# Menu decor
	if _menu_decor:
		var drift: float = sin(_t * 0.16) * w * 0.012 if _animated else 0.0
		draw_rect(Rect2(Vector2(0.0 + drift, h * 0.80), Vector2(w * 0.44, h * 0.045)), Color(0.50, 0.65, 0.36, 0.22), true)
		draw_rect(Rect2(Vector2(w * 0.58 - drift, h * 0.84), Vector2(w * 0.42, h * 0.045)), Color(0.48, 0.31, 0.64, 0.22), true)
		var star_i: int = 0
		for sp in [Vector2(0.40, 0.18), Vector2(0.62, 0.28), Vector2(0.72, 0.50), Vector2(0.30, 0.40)]:
			var a: float = 1.0
			if _animated:
				a = 0.40 + 0.60 * (0.5 + 0.5 * sin(_t * 1.1 + float(star_i) * 1.9))
			_star(Vector2(w * sp.x, h * sp.y), maxf(minf(w, h) * 0.010, 2.5), a)
			star_i += 1


func _star(p: Vector2, rr: float, alpha: float = 1.0) -> void:
	var col: Color = Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, alpha)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0.0, -rr), p + Vector2(rr * 0.5, 0.0), p + Vector2(0.0, rr), p + Vector2(-rr * 0.5, 0.0)]), col)


func _tree(base: Vector2, height: float, w_ref: float, alpha: float = 1.0) -> void:
	var top: Vector2 = base + Vector2(0.0, -height)
	var trunk_w: float = maxf(w_ref * 0.012, 3.0)
	var col: Color = COL_SIL if alpha >= 1.0 else Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, alpha)
	draw_line(base, top, col, trunk_w, true)
	var bl: float = height * 0.26
	for frac in [0.55, 0.70, 0.84]:
		var p: Vector2 = base.lerp(top, frac)
		var side: float = 1.0 if (int(frac * 100.0) % 2 == 0) else -1.0
		draw_line(p, p + Vector2(side * bl * 0.6, -bl * 0.7), col, trunk_w * 0.7, true)
		draw_line(p, p + Vector2(-side * bl * 0.45, -bl * 0.6), col, trunk_w * 0.6, true)


func _menhir(pos: Vector2, dim: Vector2) -> void:
	draw_rect(Rect2(pos, dim), COL_STONE, true)
	var cx: float = pos.x + dim.x * 0.5
	var y0: float = pos.y + dim.y * 0.18
	var y1: float = pos.y + dim.y * 0.82
	draw_line(Vector2(cx, y0), Vector2(cx, y1), COL_INK, 2.0, true)
	var tick: float = dim.x * 0.42
	for i in 4:
		var ty: float = lerpf(y0, y1, float(i + 1) / 5.0)
		draw_line(Vector2(cx - tick, ty), Vector2(cx + tick, ty), COL_INK, 2.0, true)


func _figure(base: Vector2, height: float, half_w: float) -> void:
	var top: float = base.y - height
	var shoulder: float = base.y - height * 0.62
	var cloak: PackedVector2Array = PackedVector2Array([
		Vector2(base.x - half_w * 0.45, top + height * 0.10),
		Vector2(base.x - half_w, base.y),
		Vector2(base.x + half_w, base.y),
		Vector2(base.x + half_w * 0.45, top + height * 0.10),
		Vector2(base.x + half_w * 0.30, shoulder),
		Vector2(base.x - half_w * 0.30, shoulder),
	])
	draw_colored_polygon(cloak, COL_SIL)
	draw_circle(Vector2(base.x, top + height * 0.06), half_w * 0.42, COL_SIL)
