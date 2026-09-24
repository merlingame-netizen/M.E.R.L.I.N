class_name MerlinWoodcut
extends RefCounted
## DA v8 — Grammaire de gravure sur bois P1 : hachures, bouillonnement, étoiles, lune,
## reliefs facettés, brume. Classe STATIQUE (même convention que MerlinVisual/MerlinTween).
## Source : charte_p1.md §2-§5, SPEC.md §2.

# Hachure : direction + pas + épaisseur. Le bouillonnement (boil) décale et tourne
# les hachures toutes les 1/BOIL_FPS s pour l'effet « gravure animée ».

const _TWO_PI: float = TAU

# Pas et largeurs canoniques (aliasés depuis MerlinVisual)
const ENC: float = MerlinVisual.STROKE_ENC
const INT_W: float = MerlinVisual.STROKE_INT
const HACH: float = MerlinVisual.STROKE_HACH
const P4: int = MerlinVisual.HATCH_PITCH_4
const P6: int = MerlinVisual.HATCH_PITCH_6

# Couleurs gravure
const COL_TAILLE: Color = MerlinVisual.GRAV_TAILLE
const COL_INK: Color = MerlinVisual.SILHOUETTE
const COL_CREAM: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_SCENE_BG: Color = MerlinVisual.SCENE_BG


# ── Bouillonnement global ──
# Chaque scène appelle tick_boil(delta) dans _process ; l'accumulateur avance à BOIL_FPS.
# Les fonctions de dessin lisent boil_offset / boil_angle pour décaler les hachures.
static var boil_offset: float = 0.0
static var boil_angle: float = 0.0
static var _boil_acc: float = 0.0
static var _boil_rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func tick_boil(delta: float) -> bool:
	if MerlinVisual.reduced_motion:
		boil_offset = 0.0
		boil_angle = 0.0
		return false
	_boil_acc += delta
	var interval: float = 1.0 / MerlinVisual.BOIL_FPS
	if _boil_acc < interval:
		return false
	_boil_acc -= interval
	boil_offset = _boil_rng.randf_range(-MerlinVisual.BOIL_OFFSET_MAX, MerlinVisual.BOIL_OFFSET_MAX)
	boil_angle = deg_to_rad(_boil_rng.randf_range(-MerlinVisual.BOIL_ANGLE_MAX, MerlinVisual.BOIL_ANGLE_MAX))
	return true


# ── Dessin de hachures sur un rectangle (h6 / h4 / x4) ──
# `ci` = CanvasItem (le node qui appelle depuis _draw).
# `rect` = zone à hachurer. `pitch` = espacement entre traits.
# `col` = couleur du trait. `cross` = true pour hachures croisées (x4).
# Tient compte du boil_offset + boil_angle courant.
static func draw_hatch(ci: CanvasItem, rect: Rect2, pitch: int, col: Color, cross: bool = false) -> void:
	var w: float = HACH
	var ox: float = boil_offset
	var ca: float = cos(boil_angle)
	var sa: float = sin(boil_angle)
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	# Hachures à 45° (du bas-gauche vers haut-droite)
	var diag: float = rect.size.x + rect.size.y
	var start: float = -diag * 0.5
	var i: float = start + fmod(ox * float(pitch), float(pitch))
	while i < diag * 0.5:
		var x0: float = rect.position.x + i
		var y0: float = rect.position.y + rect.size.y
		var x1: float = x0 + rect.size.y
		var y1: float = rect.position.y
		# Clamp to rect
		if x0 < rect.position.x:
			y0 -= (rect.position.x - x0)
			x0 = rect.position.x
		if x1 > rect.end.x:
			y1 += (x1 - rect.end.x)
			x1 = rect.end.x
		if y0 > rect.end.y:
			y0 = rect.end.y
		if y1 < rect.position.y:
			y1 = rect.position.y
		# Rotate around center
		var a: Vector2 = _rot(Vector2(x0, y0), cx, cy, ca, sa)
		var b: Vector2 = _rot(Vector2(x1, y1), cx, cy, ca, sa)
		ci.draw_line(a, b, col, w, true)
		i += float(pitch)
	if cross:
		# Counter-diagonal (135°)
		i = start + fmod(-ox * float(pitch), float(pitch))
		while i < diag * 0.5:
			var x0: float = rect.position.x + i
			var y0: float = rect.position.y
			var x1: float = x0 + rect.size.y
			var y1: float = rect.position.y + rect.size.y
			if x0 < rect.position.x:
				y0 += (rect.position.x - x0)
				x0 = rect.position.x
			if x1 > rect.end.x:
				y1 -= (x1 - rect.end.x)
				x1 = rect.end.x
			var a: Vector2 = _rot(Vector2(x0, y0), cx, cy, ca, sa)
			var b: Vector2 = _rot(Vector2(x1, y1), cx, cy, ca, sa)
			ci.draw_line(a, b, col, w, true)
			i += float(pitch)


static func _rot(p: Vector2, cx: float, cy: float, ca: float, sa: float) -> Vector2:
	var dx: float = p.x - cx
	var dy: float = p.y - cy
	return Vector2(cx + dx * ca - dy * sa, cy + dx * sa + dy * ca)


# ── Étoile-croix (scintillement gravure) ──
static func draw_star_cross(ci: CanvasItem, pos: Vector2, arm: float, col: Color, w: float = HACH) -> void:
	ci.draw_line(pos + Vector2(-arm, 0), pos + Vector2(arm, 0), col, w, true)
	ci.draw_line(pos + Vector2(0, -arm), pos + Vector2(0, arm), col, w, true)


# ── Lune gravée (disque crème cerné, croissant d'ombre en hachure, gloire, anneau) ──
# `t` = temps global pour les rotations de gloire et d'anneau.
static func draw_moon(ci: CanvasItem, center: Vector2, radius: float, t: float, col_disk: Color = COL_CREAM) -> void:
	# Disque crème cerné
	ci.draw_circle(center, radius, col_disk)
	ci.draw_arc(center, radius, 0.0, _TWO_PI, 48, COL_INK, ENC, true)
	# Croissant d'ombre (hachures sur le quart droit)
	var shadow_rect: Rect2 = Rect2(center.x, center.y - radius, radius, radius * 2.0)
	draw_hatch(ci, shadow_rect, P6, Color(COL_INK.r, COL_INK.g, COL_INK.b, 0.4))
	# Gloire (16 rayons)
	var ray_len: float = radius * 0.55
	var ray_inner: float = radius * 1.15
	for j in 16:
		var angle: float = t * 0.12 + float(j) * _TWO_PI / 16.0
		var d: Vector2 = Vector2(cos(angle), sin(angle))
		var a: Vector2 = center + d * ray_inner
		var b: Vector2 = center + d * (ray_inner + ray_len)
		var alpha: float = 0.25 + 0.15 * sin(t * 1.5 + float(j) * 0.9)
		ci.draw_line(a, b, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, alpha), INT_W, true)
	# Anneau runique (24 ticks, tourne en sens inverse)
	var ring_r: float = radius * 1.5
	for j in 24:
		var angle: float = -t * 0.08 + float(j) * _TWO_PI / 24.0
		var d: Vector2 = Vector2(cos(angle), sin(angle))
		ci.draw_line(center + d * (ring_r - 3.0), center + d * (ring_r + 3.0), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.18), HACH, true)


# ── Colline facettée (segments de 8-14 u, jamais de Bézier) ──
# Retourne les points du profil pour chaîner avec le sol.
static func draw_hill(ci: CanvasItem, baseline_y: float, left_x: float, right_x: float,
		peak_y: float, col: Color, col_hatch: Color, segments: int = 12) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(left_x * 100 + peak_y * 10) # Deterministic per hill
	pts.append(Vector2(left_x, baseline_y))
	for i in range(1, segments):
		var frac: float = float(i) / float(segments)
		var x: float = lerpf(left_x, right_x, frac)
		var env: float = 1.0 - (frac * 2.0 - 1.0) * (frac * 2.0 - 1.0) # parabolic envelope
		var y: float = lerpf(baseline_y, peak_y, env) + rng.randf_range(-4.0, 4.0)
		pts.append(Vector2(x, y))
	pts.append(Vector2(right_x, baseline_y))
	# Fill
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)
	# Contour facetté
	for i in range(pts.size() - 1):
		ci.draw_line(pts[i], pts[i + 1], COL_INK, ENC, true)
	# Hachure sous la crête (bande de ~20px sous le sommet)
	var band_top: float = peak_y
	var band_bot: float = peak_y + 20.0
	var band_left: float = left_x + (right_x - left_x) * 0.2
	var band_right: float = right_x - (right_x - left_x) * 0.2
	draw_hatch(ci, Rect2(band_left, band_top, band_right - band_left, band_bot - band_top), P6, col_hatch)
	return pts


# ── Pierre / menhir ──
static func draw_stone(ci: CanvasItem, base: Vector2, w: float, h: float, col_face: Color = MerlinVisual.RING_BG) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(base + Vector2(-w * 0.5, 0))
	pts.append(base + Vector2(-w * 0.45, -h * 0.3))
	pts.append(base + Vector2(-w * 0.35, -h * 0.7))
	pts.append(base + Vector2(-w * 0.1, -h * 0.95))
	pts.append(base + Vector2(w * 0.15, -h))
	pts.append(base + Vector2(w * 0.4, -h * 0.75))
	pts.append(base + Vector2(w * 0.48, -h * 0.35))
	pts.append(base + Vector2(w * 0.5, 0))
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col_face)
	# Cerne
	for i in range(pts.size() - 1):
		ci.draw_line(pts[i], pts[i + 1], COL_INK, ENC, true)
	ci.draw_line(pts[pts.size() - 1], pts[0], COL_INK, ENC, true)
	# Ombre droite (x4)
	var shadow_rect: Rect2 = Rect2(base.x + w * 0.1, base.y - h * 0.85, w * 0.35, h * 0.7)
	draw_hatch(ci, shadow_rect, P4, Color(COL_INK.r, COL_INK.g, COL_INK.b, 0.35), true)
	# Fissures
	ci.draw_line(base + Vector2(-w * 0.1, -h * 0.6), base + Vector2(w * 0.05, -h * 0.3), COL_INK, INT_W, true)
	# Liseré lumière (haut gauche)
	ci.draw_line(pts[3], pts[4], Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, 0.3), HACH, true)


# ── Brume gravée (lignes hachurées qui dérivent) ──
static func draw_mist(ci: CanvasItem, y: float, width: float, t: float, col: Color, count: int = 5) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(y * 73)
	for i in count:
		var base_x: float = rng.randf_range(-100, width + 100)
		var drift: float = fmod(t * (15.0 + rng.randf_range(0, 10)), width + 200) - 100
		var x: float = fmod(base_x + drift, width + 200) - 100
		var seg_w: float = rng.randf_range(60, 180)
		var alpha: float = 0.08 + 0.06 * sin(t * 0.4 + float(i) * 1.3)
		ci.draw_line(Vector2(x, y + rng.randf_range(-8, 8)), Vector2(x + seg_w, y + rng.randf_range(-4, 4)), Color(col.r, col.g, col.b, alpha), HACH, true)


# ── Ciel bande de tirets (plus dense vers l'horizon) ──
static func draw_sky_bands(ci: CanvasItem, rect: Rect2, t: float, col: Color) -> void:
	var band_count: int = 12
	for i in band_count:
		var frac: float = float(i) / float(band_count)
		var y: float = rect.position.y + rect.size.y * frac
		var density: float = 0.3 + frac * 0.7 # denser at bottom (horizon)
		var dash_count: int = int(density * 20.0)
		var drift: float = t * (5.0 + frac * 8.0)
		for j in dash_count:
			var x: float = fmod(float(j) * rect.size.x / float(dash_count) + drift, rect.size.x)
			var dash_len: float = 8.0 + frac * 16.0
			var alpha: float = (0.06 + frac * 0.12) * (0.7 + 0.3 * sin(t * 0.6 + float(j) * 0.8))
			ci.draw_line(Vector2(rect.position.x + x, y), Vector2(rect.position.x + x + dash_len, y), Color(col.r, col.g, col.b, alpha), HACH, true)
