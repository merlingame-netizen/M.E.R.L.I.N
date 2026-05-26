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


func set_beat(beat_type: String) -> void:
	_beat = beat_type
	queue_redraw()


func set_menu_decor(on: bool) -> void:
	_menu_decor = on
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

	# Lune (cercle crème), haut-centre.
	var moon_c: Vector2 = Vector2(w * 0.5, h * 0.40)
	var moon_r: float = minf(w, h) * 0.13
	draw_circle(moon_c, moon_r, COL_MOON)

	# Arbres nus en silhouette, encadrant (arrière-plan).
	_tree(Vector2(w * 0.12, h), h * 0.74, w)
	_tree(Vector2(w * 0.27, h), h * 0.60, w)
	_tree(Vector2(w * 0.80, h), h * 0.66, w)
	_tree(Vector2(w * 0.91, h), h * 0.78, w)

	# Menhir gravé d'oghams (droite du centre).
	_menhir(Vector2(w * 0.66, h * 0.46), Vector2(w * 0.052, h * 0.40))

	# Motif central : figure encapuchonnée devant la lune (Rencontre/Climax/Dilemme).
	if _beat == "Rencontre" or _beat == "Climax" or _beat == "Dilemme":
		_figure(Vector2(w * 0.5, h * 0.84), h * 0.50, w * 0.075)

	# Brume : bandes horizontales plates translucides (avant-plan).
	for band in [0.60, 0.71, 0.81]:
		var y: float = h * band
		var bw: float = w * (0.5 + 0.18 * band)
		var bx: float = w * 0.5 - bw * 0.5
		draw_rect(Rect2(Vector2(bx, y), Vector2(bw, h * 0.035)), COL_MIST, true)

	if _menu_decor:
		# Brume teintée faction : vert à gauche, violet à droite (couleurs des Pôles) + étoiles.
		draw_rect(Rect2(Vector2(0.0, h * 0.80), Vector2(w * 0.44, h * 0.045)), Color(0.50, 0.65, 0.36, 0.22), true)
		draw_rect(Rect2(Vector2(w * 0.58, h * 0.84), Vector2(w * 0.42, h * 0.045)), Color(0.48, 0.31, 0.64, 0.22), true)
		for sp in [Vector2(0.40, 0.18), Vector2(0.62, 0.28), Vector2(0.72, 0.50), Vector2(0.30, 0.40)]:
			_star(Vector2(w * sp.x, h * sp.y), maxf(minf(w, h) * 0.010, 2.5))


func _star(p: Vector2, rr: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0.0, -rr), p + Vector2(rr * 0.5, 0.0), p + Vector2(0.0, rr), p + Vector2(-rr * 0.5, 0.0)]), COL_MOON)


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
