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

	# Lune (cercle crème), haut-centre. En mode animé : halo qui respire très lentement.
	# v10.13 (B7) : la phase est accumulée dans _process → la respiration ACCÉLÈRE sans saut
	# quand « Merlin pense » (set_thinking), et reprend son rythme lent au repos.
	var moon_c: Vector2 = Vector2(w * 0.5, h * 0.40)
	var moon_r: float = minf(w, h) * 0.13
	if _animated:
		var halo_r: float = moon_r * (1.22 + 0.06 * sin(_halo_phase))
		var halo_a: float = 0.05 + 0.025 * (0.5 + 0.5 * sin(_halo_phase))
		draw_circle(moon_c, halo_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_a))
	draw_circle(moon_c, moon_r, COL_MOON)

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

	# v10.15 — Motes ambiantes (golden fireflies) : entre figure et brume (profondeur correcte).
	if _animated:
		for mi in 6:
			var mf: float = float(mi)
			var mx: float = w * (0.15 + 0.70 * fmod(mf * 0.618 + 0.1, 1.0))
			var my: float = h * (0.25 + 0.50 * fmod(mf * 0.382 + 0.05, 1.0))
			mx += sin(_t * 0.28 + mf * 1.7) * w * 0.025
			my += cos(_t * 0.21 + mf * 2.3) * h * 0.018
			var ma: float = 0.12 + 0.10 * (0.5 + 0.5 * sin(_t * 0.55 + mf * 1.1))
			if MerlinVisual.reduced_motion:
				ma *= 0.5
			var mr: float = maxf(minf(w, h) * 0.005, 1.8)
			draw_circle(Vector2(mx, my), mr, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, ma))

	# Brume : bandes horizontales plates translucides (avant-plan). Dérive lente en mode animé.
	var band_i: int = 0
	for band in [0.60, 0.71, 0.81]:
		var y: float = h * band
		var bw: float = w * (0.5 + 0.18 * band)
		var bx: float = w * 0.5 - bw * 0.5
		if _animated:
			bx += sin(_t * 0.20 + float(band_i) * 2.1) * w * 0.014
		draw_rect(Rect2(Vector2(bx, y), Vector2(bw, h * 0.035)), COL_MIST, true)
		band_i += 1

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
