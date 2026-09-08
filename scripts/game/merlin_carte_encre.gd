class_name MerlinCarteEncre
extends Control
## LA CARTE À L'ENCRE — ce qu'on regarde pendant que Merlin rêve les trois sentiers (08/09).
##
## POURQUOI. L'attente de la sélection durait jusqu'à trente-huit secondes devant une forêt à
## demi-teinte et une ligne dorée. Maxime a choisi que l'attente devienne une scène : depuis l'orbe
## de Merlin, trois traits d'encre s'écrivent lentement vers trois horizons, comme une carte qui se
## dessine ; le parchemin d'un sentier vient se poser au bout de son trait quand il arrive ; après le
## choix, le trait du sentier choisi se prolonge vers l'horizon et les deux autres s'effacent.
##
## LE TEMPS, PAS LES IMAGES. Cet écran tourne à 5 images par seconde pendant que le modèle écrit
## (les cœurs lui sont rendus) : tout ici se calcule sur l'horloge, jamais sur un compte d'images.
## Un trait avance vers 90 % de sa longueur en asymptote (18 s de constante), et ne se ferme
## qu'à l'arrivée de son titre : la fin de l'attente est visible, jamais mentie.

const POINTS: int = 72
const CONSTANTE_S: float = 18.0    # e-folding de l'avance sans nouvelle
const PLAFOND_ATTENTE: float = 0.90
const COL_ENCRE: Color = MerlinVisual.CREAM
const COL_HALO: Color = MerlinVisual.GOLD

var _chemins: Array = []       # Array[PackedVector2Array]
var _progres: Array = []       # float par chemin, 0..1 (part dessinée)
var _fini: Array = []          # bool par chemin
var _fondu: Array = []         # alpha par chemin (les non-choisis s'effacent)
var _origine: Vector2 = Vector2.ZERO
var _t0: int = 0
var _actif: bool = false
var _choisi: int = -1
var _horizon: PackedVector2Array = PackedVector2Array()   # le prolongement du chemin choisi
var _horizon_p: float = 0.0
var _alpha: float = 1.0
var _graine: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Trois chemins depuis `origine` vers `cibles`. Les chemins sont tracés une fois (graine stable
## par écran) : un trait d'encre ne bouge pas une fois posé, il ne fait que s'allonger.
func demarrer(origine: Vector2, cibles: Array, graine: int = 0) -> void:
	_origine = origine
	_graine = graine if graine != 0 else int(Time.get_ticks_msec())
	_chemins.clear()
	_progres.clear()
	_fini.clear()
	_fondu.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _graine
	for i in cibles.size():
		_chemins.append(_tracer(origine, cibles[i], rng, i))
		_progres.append(0.0)
		_fini.append(false)
		_fondu.append(1.0)
	_choisi = -1
	_horizon = PackedVector2Array()
	_horizon_p = 0.0
	_alpha = 1.0
	_t0 = Time.get_ticks_msec()
	_actif = true
	set_process(true)
	queue_redraw()


## Le titre du chemin `i` est arrivé : le trait se ferme.
func terminer(i: int) -> void:
	if i >= 0 and i < _fini.size():
		_fini[i] = true


## Après le choix : le chemin `i` se prolonge vers `horizon`, les autres s'effacent.
func prolonger(i: int, horizon: Vector2) -> void:
	if i < 0 or i >= _chemins.size():
		return
	_choisi = i
	_fini[i] = true
	_progres[i] = 1.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _graine + 97 + i
	var depart: Vector2 = (_chemins[i] as PackedVector2Array)[POINTS - 1]
	_horizon = _tracer(depart, horizon, rng, 7)
	_horizon_p = 0.0
	_t0 = Time.get_ticks_msec()


func arreter(fondu_s: float = 0.6) -> void:
	_actif = false
	if fondu_s <= 0.0 or MerlinVisual.reduced_motion:
		_alpha = 0.0
		set_process(false)
		queue_redraw()
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "_alpha", 0.0, fondu_s).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: set_process(false); queue_redraw())


func est_actif() -> bool:
	return _actif


func _process(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var base: float = PLAFOND_ATTENTE * (1.0 - exp(-t / CONSTANTE_S))
	for i in _chemins.size():
		var cible: float = 1.0 if bool(_fini[i]) else minf(base + float(i) * 0.03, PLAFOND_ATTENTE)
		var p: float = float(_progres[i])
		# On n'avance qu'en avant, et un trait qui se ferme le fait en une seconde environ.
		if cible > p:
			_progres[i] = minf(cible, p + (0.9 if bool(_fini[i]) else 0.25) * _delta)
		if _choisi >= 0 and i != _choisi:
			_fondu[i] = maxf(0.0, float(_fondu[i]) - _delta * 0.8)
	if _choisi >= 0 and _horizon_p < 1.0:
		_horizon_p = minf(1.0, _horizon_p + _delta * 0.12)   # ~8 s vers l'horizon
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	for i in _chemins.size():
		_dessiner_trait(_chemins[i], float(_progres[i]), float(_fondu[i]) * _alpha, i == _choisi)
	if _choisi >= 0 and not _horizon.is_empty():
		_dessiner_trait(_horizon, _horizon_p, _alpha, true)
	# La goutte d'origine : l'orbe où tout commence.
	draw_circle(_origine, 4.0, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, 0.9 * _alpha))
	draw_circle(_origine, 9.0, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, 0.18 * _alpha))


func _dessiner_trait(chemin: PackedVector2Array, p: float, a: float, fort: bool) -> void:
	if a <= 0.01 or p <= 0.0:
		return
	var n: int = int(floor(p * float(POINTS - 1)))
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n + 1:
		pts.append(chemin[k])
	# Le bout du trait est interpolé : à 5 images par seconde, c'est ce qui le fait glisser.
	if n < POINTS - 1:
		var f: float = p * float(POINTS - 1) - float(n)
		pts.append(chemin[n].lerp(chemin[n + 1], f))
	if pts.size() < 2:
		return
	var w: float = 3.8 if fort else 3.0
	draw_polyline(pts, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, 0.14 * a), w * 3.0, true)
	draw_polyline(pts, Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.85 * a), w, true)
	var bout: Vector2 = pts[pts.size() - 1]
	if p < 1.0:
		# La plume : un point d'or, et trois motes qui traînent derrière (sur l'horloge).
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		draw_circle(bout, 3.0, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, 0.95 * a))
		for m in 3:
			var recul: int = maxi(0, pts.size() - 1 - (2 + m * 3))
			var mp: Vector2 = pts[recul] + Vector2(sin(t * 1.7 + float(m) * 2.1), cos(t * 1.3 + float(m))) * 4.0
			draw_circle(mp, 1.6, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, (0.5 - 0.12 * float(m)) * a))
	else:
		# Le trait fermé finit sur une tache d'encre : le sentier est là.
		draw_circle(bout, 5.0, Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.9 * a))
		draw_circle(bout, 10.0, Color(COL_HALO.r, COL_HALO.g, COL_HALO.b, 0.2 * a))


## Un chemin qui serpente : l'axe droit, plus deux sinusoïdes d'amplitude décroissante vers les
## bouts (il part de l'orbe et arrive au parchemin sans hésiter).
func _tracer(a: Vector2, b: Vector2, rng: RandomNumberGenerator, i: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var d: Vector2 = b - a
	var n: Vector2 = Vector2(-d.y, d.x).normalized()
	var amp: float = d.length() * rng.randf_range(0.06, 0.11)
	var f1: float = rng.randf_range(1.6, 2.6)
	var f2: float = rng.randf_range(4.0, 6.5)
	var ph: float = rng.randf_range(0.0, TAU) + float(i)
	for k in POINTS:
		var u: float = float(k) / float(POINTS - 1)
		var enveloppe: float = sin(u * PI)
		var ecart: float = (sin(u * f1 * PI + ph) * amp + sin(u * f2 * PI + ph * 2.0) * amp * 0.25) * enveloppe
		out.append(a + d * u + n * ecart)
	return out
