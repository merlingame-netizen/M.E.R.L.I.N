class_name MerlinRingGauge
extends Control
## Jauge en anneau (DA flat rétro-minimaliste, 2026-05-26) : anneau de fond fin + arc rempli
## proportionnel au ratio (0..1), dessiné en moteur. Le ratio s'anime via tween_method(set_ratio).

const RING_SIZE: float = 78.0  # HUD agrandi (user 2026-06-06 : scale tout)
const RING_WIDTH: float = 6.0
const COL_BG_RING: Color = MerlinVisual.RING_BG
const BREATH_IDLE_MIN: float = 0.82  # respiration de repos : subtile (jauge « vivante »)
const BREATH_IDLE_DUR: float = 1.4
const BREATH_CRIT_MIN: float = 0.40  # critique : respiration marquée + rapide
const BREATH_CRIT_DUR: float = 0.55

# N4-P1 (chantier 6, panel MAJEUR : anneaux anonymes) : alphas du glyphe central grave et du
# lisere de presence a vide. Dessin 100 % procedural (_draw), couleur = color_fill (palette canon).
const GLYPH_ALPHA_HEART: float = 0.55   # souffle/coeur (Integrite) : grave net
const GLYPH_ALPHA_SPIRAL: float = 0.42  # spirale VOILEE (Corruption) : plus sourde
const PRESENCE_ALPHA: float = 0.26      # fil de couleur quand l'anneau est a 0 (la jauge existe)
const GLYPH_WIDTH: float = 1.6

var _ratio: float = 0.0
var color_fill: Color = MerlinVisual.GREEN
var _critical: bool = false
var _crit_tw: Tween
var _glyph: String = ""  # "" (aucun) | "coeur" (Integrite) | "spirale" (Corruption)


# N4-P1 : `glyph` identifie l'anneau d'un signe grave au centre ("" = rendu historique intact).
func setup(p_color: Color, alive: bool = false, glyph: String = "") -> void:
	color_fill = p_color
	_glyph = glyph
	custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	size = Vector2(RING_SIZE, RING_SIZE)
	pivot_offset = Vector2(RING_SIZE, RING_SIZE) * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	if alive:
		_start_breath(false)  # respiration « vivante » dès l'affichage (jauges du jeu)


## Respiration alpha CONTINUE (jauge « vivante ») : idle lent & subtil par défaut, fort &
## rapide quand la stat devient critique (vie basse / corruption haute). Demande user 2026-05-27.
func set_critical(on: bool) -> void:
	if on == _critical:
		return
	_critical = on
	_start_breath(on)


func _start_breath(crit: bool) -> void:
	if _crit_tw != null and _crit_tw.is_valid():
		_crit_tw.kill()
	var lo: float = BREATH_CRIT_MIN if crit else BREATH_IDLE_MIN
	var dur: float = BREATH_CRIT_DUR if crit else BREATH_IDLE_DUR
	modulate.a = 1.0
	_crit_tw = create_tween().set_loops()
	_crit_tw.tween_property(self, "modulate:a", lo, dur).set_trans(Tween.TRANS_SINE)
	_crit_tw.tween_property(self, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE)


func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	queue_redraw()


func get_ratio() -> float:
	return _ratio


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	var rad: float = minf(s.x, s.y) * 0.5 - RING_WIDTH
	if rad <= 0.0:
		return
	draw_arc(c, rad, 0.0, TAU, 56, COL_BG_RING, RING_WIDTH, true)
	if _ratio > 0.0:
		var start: float = -PI / 2.0  # départ en haut, sens horaire
		draw_arc(c, rad, start, start + _ratio * TAU, 56, color_fill, RING_WIDTH, true)
	else:
		# N4-P1 (chantier 6) : LISERE DE PRESENCE a vide : un fil discret de la couleur de la jauge
		# (l'anneau de corruption a 0 dit « une 2e jauge existe » sans peser, pilier MINIMAL).
		draw_arc(c, rad, 0.0, TAU, 56,
			Color(color_fill.r, color_fill.g, color_fill.b, PRESENCE_ALPHA), 2.0, true)
	# N4-P1 (chantier 6) : mini-GLYPHE grave au centre : identite de l'anneau sans texte.
	match _glyph:
		"coeur":
			_draw_heart(c, rad * 0.52)
		"spirale":
			_draw_spiral(c, rad * 0.55)


# Coeur/souffle procedural (courbe cardioide parametrique fermee), trace grave couleur de jauge.
func _draw_heart(center: Vector2, r: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 25:
		var t: float = float(i) / 24.0 * TAU
		var hx: float = 16.0 * pow(sin(t), 3.0)
		var hy: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(hx, -hy) * (r / 17.0))
	draw_polyline(pts, Color(color_fill.r, color_fill.g, color_fill.b, GLYPH_ALPHA_HEART), GLYPH_WIDTH, true)


# Spirale VOILEE (archimedienne ~2,6 tours), plus sourde que le coeur : l'Emprise se devine.
func _draw_spiral(center: Vector2, r: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 46:
		var t: float = float(i) / 45.0
		var a: float = t * 2.6 * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * (r * t))
	draw_polyline(pts, Color(color_fill.r, color_fill.g, color_fill.b, GLYPH_ALPHA_SPIRAL), GLYPH_WIDTH, true)
