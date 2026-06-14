class_name MerlinSceneArt
extends Control
## Décor de scène en SILHOUETTES PLATES, dessiné en moteur (DA flat rétro-minimaliste, 2026-05-26).
## Lune (cercle crème) + arbres nus + menhir gravé d'oghams + bandes de brume ; motif central
## (figure encapuchonnée) selon le type de beat. Aucun asset externe. Reproduit le mockup validé.

const COL_SCENE_BG: Color = Color("17130D")  # fond de la fenêtre de scène (un peu + sombre que la page)
const COL_SIL: Color = Color("0E0B07")        # silhouettes (arbres, figure) — quasi noir
const COL_MOON: Color = Color("E8DCC0")        # lune / parchemin
const COL_STONE: Color = Color("2A2018")       # menhir
const COL_INK: Color = Color("0E0B07")         # gravures oghams
const COL_MIST: Color = Color(0.79, 0.72, 0.58, 0.16)  # brume tan translucide

var _beat: String = "Exploration"
var _menu_decor: bool = false  # menu : brume teintée faction (vert/violet) + étoiles
var _animated: bool = false    # scène « vivante » (brume qui dérive, étoiles, halo de lune)
var _t: float = 0.0

# v10.13 (B7) — « Merlin pense » : signal HONNÊTE d'activité du moteur natif. Quand on : le halo
# de lune respire plus vite + une mote or plate orbite le menhir. Phase ACCUMULÉE (pas de saut
# visuel quand la vitesse change en cours de respiration).
const HALO_SPEED_IDLE: float = 0.45
const HALO_SPEED_THINK: float = 1.6
var _thinking: bool = false
var _halo_phase: float = 0.0


func set_beat(beat_type: String) -> void:
	_beat = beat_type
	queue_redraw()


func set_menu_decor(on: bool) -> void:
	_menu_decor = on
	queue_redraw()


## Anime la scène en continu (opt-in — menu depuis 2026-06-10, jeu depuis v10.13 B7).
func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	queue_redraw()


## v10.13 (B7) — « Merlin pense » : halo accéléré + mote or en orbite tant que le moteur écrit.
func set_thinking(on: bool) -> void:
	if on == _thinking:
		return
	_thinking = on
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_halo_phase += delta * (HALO_SPEED_THINK if _thinking else HALO_SPEED_IDLE)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 4.0 or s.y <= 4.0:
		return
	var w: float = s.x
	var h: float = s.y

	# Fond de la fenêtre de scène (coin légèrement arrondi simulé par un simple rect plein).
	draw_rect(Rect2(Vector2.ZERO, s), COL_SCENE_BG, true)

	var moon_c: Vector2 = Vector2(w * 0.5, h * 0.40)
	var moon_r: float = minf(w, h) * 0.13
	if _animated:
		var halo_outer_r: float = moon_r * (1.45 + 0.08 * sin(_halo_phase * 0.6))
		var halo_outer_a: float = 0.025 + 0.012 * (0.5 + 0.5 * sin(_halo_phase * 0.6))
		if MerlinVisual.reduced_motion:
			halo_outer_a *= 0.5
		draw_circle(moon_c, halo_outer_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_outer_a))
		var halo_r: float = moon_r * (1.22 + 0.06 * sin(_halo_phase))
		var halo_a: float = 0.05 + 0.025 * (0.5 + 0.5 * sin(_halo_phase))
		draw_circle(moon_c, halo_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_a))
	draw_circle(moon_c, moon_r, COL_MOON)

	if _animated and not MerlinVisual.reduced_motion:
		var ray_len: float = minf(w, h) * 0.35
		for ri in 4:
			var angle: float = _t * 0.08 + float(ri) * PI * 0.5
			var ray_end: Vector2 = moon_c + Vector2(cos(angle), sin(angle)) * ray_len
			var ray_a: float = 0.03 + 0.01 * sin(_t * 0.15 + float(ri) * 1.3)
			draw_line(moon_c, ray_end, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, ray_a), 1.5)

	# Arbres nus en silhouette, encadrant (arrière-plan).
	_tree(Vector2(w * 0.12, h), h * 0.74, w)
	_tree(Vector2(w * 0.27, h), h * 0.60, w)
	_tree(Vector2(w * 0.80, h), h * 0.66, w)
	_tree(Vector2(w * 0.91, h), h * 0.78, w)

	# Menhir gravé d'oghams (droite du centre).
	_menhir(Vector2(w * 0.66, h * 0.46), Vector2(w * 0.052, h * 0.40))

	# v10.13 (B7) — « Merlin pense » : une mote or plate orbite le menhir pendant que le moteur
	# écrit (orbite elliptique = profondeur suggérée, DA flat : simple cercle plein, zéro dégradé).
	if _thinking and _animated:
		var menhir_c: Vector2 = Vector2(w * 0.686, h * 0.66)
		var mote: Vector2 = menhir_c + Vector2(cos(_t * 2.2) * w * 0.045, sin(_t * 2.2) * h * 0.10)
		draw_circle(mote, maxf(minf(w, h) * 0.008, 2.5), MerlinVisual.GOLD)

	# Motif central : figure encapuchonnée devant la lune (Rencontre/Climax/Dilemme).
	if _beat == "Rencontre" or _beat == "Climax" or _beat == "Dilemme":
		_figure(Vector2(w * 0.5, h * 0.84), h * 0.50, w * 0.075)

	if _animated:
		for mi in 10:
			var mf: float = float(mi)
			var mx: float = w * (0.10 + 0.80 * fmod(mf * 0.618 + 0.1, 1.0))
			var my: float = h * (0.20 + 0.55 * fmod(mf * 0.382 + 0.05, 1.0))
			var speed: float = 0.18 + mf * 0.04
			mx += sin(_t * speed + mf * 1.7) * w * 0.025
			my += cos(_t * (speed * 0.75) + mf * 2.3) * h * 0.018
			var depth: float = my / h
			var mr: float = maxf(minf(w, h) * lerpf(0.003, 0.007, depth), 1.5)
			var ma: float = lerpf(0.08, 0.22, depth) * (0.5 + 0.5 * sin(_t * 0.55 + mf * 1.1))
			if MerlinVisual.reduced_motion:
				ma *= 0.5
			draw_circle(Vector2(mx, my), mr, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, ma))

	# v10.15 — contour de sol organique (avant brume, derrière le menu_decor).
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
		if MerlinVisual.reduced_motion:
			gnd_a *= 0.5
		draw_colored_polygon(gnd_pts, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, gnd_a))

	# Brume parallaxe : 3 couches à vitesses/opacités distinctes (profondeur).
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
		var alpha: float = float(ml["alpha"])
		if _animated:
			bx += sin(_t * float(ml["speed"]) + float(li) * 2.1) * w * 0.020
		if MerlinVisual.reduced_motion:
			alpha *= 0.5
		draw_rect(Rect2(Vector2(bx, y), Vector2(bw, h * 0.035)), Color(COL_MIST.r, COL_MIST.g, COL_MIST.b, alpha), true)

	if _menu_decor:
		# Brume teintée faction : vert à gauche, violet à droite (couleurs des Pôles) + étoiles.
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


# Arbre nu : tronc + quelques branches angulaires (silhouette plate).
func _tree(base: Vector2, height: float, w_ref: float) -> void:
	var top: Vector2 = base + Vector2(0.0, -height)
	var trunk_w: float = maxf(w_ref * 0.012, 3.0)
	draw_line(base, top, COL_SIL, trunk_w, true)
	var bl: float = height * 0.26  # longueur de branche
	for frac in [0.55, 0.70, 0.84]:
		var p: Vector2 = base.lerp(top, frac)
		var side: float = 1.0 if (int(frac * 100.0) % 2 == 0) else -1.0
		draw_line(p, p + Vector2(side * bl * 0.6, -bl * 0.7), COL_SIL, trunk_w * 0.7, true)
		draw_line(p, p + Vector2(-side * bl * 0.45, -bl * 0.6), COL_SIL, trunk_w * 0.6, true)


# Menhir : pierre dressée + ligne verticale + ticks oghams horizontaux.
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


# Figure encapuchonnée : cape (polygone évasé) + capuche (cercle).
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
	draw_circle(Vector2(base.x, top + height * 0.06), half_w * 0.42, COL_SIL)  # capuche
