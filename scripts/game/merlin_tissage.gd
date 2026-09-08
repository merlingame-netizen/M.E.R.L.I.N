class_name MerlinTissage
extends Control
## LE TISSAGE — ce qu'on regarde pendant que Merlin cherche les mots de l'issue (08/09).
##
## POURQUOI. Après le dé, l'issue pouvait mettre jusqu'à soixante-dix secondes à s'écrire, devant
## une lueur d'or, une barre et des étincelles. Maxime a choisi que Merlin tisse pour de vrai : de
## la lune, des fils fins descendent vers l'encart et se croisent en tissant la zone où l'issue va
## s'écrire ; ils se resserrent à mesure que le temps passe (le tissage remplace la barre) ; à
## l'arrivée de l'issue, le tissu se déchire en motes et le texte apparaît dessous.
##
## LE TEMPS, PAS LES IMAGES. La fusion baisse la cadence à 5 images par seconde pour rendre les
## cœurs au modèle : tout ici se calcule sur l'horloge. Un fil de plus toutes les 1,3 s, puis les
## fils de trame ; jamais plus de vingt-quatre fils au total.

const FILS_MAX: int = 16          # fils de chaîne (de la lune à l'encart)
const TRAMES_MAX: int = 8         # fils de trame (en travers de l'encart)
const CADENCE_S: float = 1.3      # un fil de plus toutes les 1,3 s
const COL_FIL: Color = MerlinVisual.CREAM
const COL_OR: Color = MerlinVisual.GOLD
const COL_ENCRE: Color = MerlinVisual.GOLD_DARK   # le fil sur le parchemin crème : sombre, pas crème

var _lune: Vector2 = Vector2.ZERO
var _cadre: Rect2 = Rect2()
var _t0: int = 0
var _graine: int = 0
var _dechire: float = 0.0        # 0 = tissé ; 1 = parti en motes
var _alpha: float = 1.0
var _fin: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Les fils partent de `lune` (coordonnées locales de ce Control) et tissent `cadre` (l'encart).
func demarrer(lune: Vector2, cadre: Rect2) -> void:
	_lune = lune
	_cadre = cadre
	_t0 = Time.get_ticks_msec()
	_graine = int(Time.get_ticks_msec())
	_dechire = 0.0
	_alpha = 1.0
	_fin = false
	set_process(true)
	queue_redraw()


## L'issue est là : le tissu se déchire en motes, puis tout s'efface. Rend quand c'est fini.
func dechirer(duree: float = 0.55) -> void:
	_fin = true
	if MerlinVisual.reduced_motion:
		_alpha = 0.0
		queue_redraw()
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "_dechire", 1.0, duree).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_alpha", 0.0, duree).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01 or _cadre.size.x < 4.0:
		return
	var t: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _graine
	var n_chaine: int = mini(FILS_MAX, 1 + int(t / CADENCE_S))
	var n_trame: int = clampi(int((t - float(FILS_MAX) * CADENCE_S * 0.5) / (CADENCE_S * 1.6)), 0, TRAMES_MAX)
	# LES FILS DE CHAÎNE : de la lune à un point du bord haut de l'encart, puis jusqu'au bas. Chaque
	# fil est une courbe qui ondule un peu (sur l'horloge), et le dernier venu s'écrit encore.
	for i in FILS_MAX:
		var u: float = (float(i) + 0.5) / float(FILS_MAX)
		var x_haut: float = _cadre.position.x + _cadre.size.x * (0.06 + 0.88 * u)
		var ph: float = rng.randf_range(0.0, TAU)
		var amp: float = rng.randf_range(6.0, 14.0)
		if i >= n_chaine:
			continue
		var age: float = t - float(i) * CADENCE_S
		var avance: float = clampf(age / 1.1, 0.0, 1.0)   # le fil descend en ~1 s
		var a: float = (0.35 + 0.25 * sin(t * 0.9 + ph)) * _alpha
		var pts: PackedVector2Array = PackedVector2Array()
		var haut: Vector2 = Vector2(x_haut, _cadre.position.y)
		var bas: Vector2 = Vector2(x_haut + rng.randf_range(-30.0, 30.0), _cadre.end.y - 8.0)
		var segs: int = 18
		for k in segs + 1:
			var f: float = float(k) / float(segs)
			if f > avance:
				break
			var p: Vector2
			if f < 0.5:
				var g: float = f * 2.0
				p = _lune.lerp(haut, g) + Vector2(sin(g * PI) * amp * sin(t * 1.1 + ph), 0.0)
			else:
				var g2: float = (f - 0.5) * 2.0
				p = haut.lerp(bas, g2) + Vector2(sin(g2 * PI * 2.0 + t * 0.7 + ph) * 3.0, 0.0)
			# La déchirure : chaque point s'écarte de sa place et tombe.
			if _dechire > 0.0:
				p += Vector2(sin(ph + float(k)) * 40.0, 30.0 + float(k) * 4.0) * _dechire
			pts.append(p)
		if pts.size() >= 2:
			_dessiner_fil(pts, a)
			if avance < 1.0:
				draw_circle(pts[pts.size() - 1], 2.6, Color(COL_OR.r, COL_OR.g, COL_OR.b, 0.9 * _alpha))
	# LES FILS DE TRAME : en travers de l'encart, ils arrivent quand la chaîne est à demi posée. Le
	# tissu se resserre : c'est l'avance sans mentir sur la fin.
	for j in n_trame:
		var v: float = (float(j) + 0.5) / float(TRAMES_MAX)
		var y: float = _cadre.position.y + _cadre.size.y * (0.10 + 0.80 * v)
		var age2: float = t - (float(FILS_MAX) * CADENCE_S * 0.5 + float(j) * CADENCE_S * 1.6)
		var avance2: float = clampf(age2 / 1.4, 0.0, 1.0)
		var sens: float = 1.0 if j % 2 == 0 else -1.0
		var x0: float = _cadre.position.x + 10.0 if sens > 0.0 else _cadre.end.x - 10.0
		var x1: float = x0 + sens * (_cadre.size.x - 20.0) * avance2
		var pts2: PackedVector2Array = PackedVector2Array()
		for k2 in 24:
			var f2: float = float(k2) / 23.0
			var p2: Vector2 = Vector2(lerpf(x0, x1, f2), y + sin(f2 * 14.0 + t * 0.8 + float(j)) * 2.0)
			if _dechire > 0.0:
				p2 += Vector2(0.0, (40.0 + float(k2) * 3.0) * _dechire * (0.5 + 0.5 * sin(float(k2) * 1.3)))
			pts2.append(p2)
		var a2: float = (0.30 + 0.14 * sin(t * 0.6 + float(j))) * _alpha
		draw_polyline(pts2, Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, a2), 1.2, true)
	# LES MOTES DE LA DÉCHIRURE : quelques points d'or qui s'envolent quand le tissu cède.
	if _dechire > 0.0:
		for m in 18:
			var mx: float = _cadre.position.x + _cadre.size.x * fmod(float(m) * 0.618, 1.0)
			var my: float = _cadre.position.y + _cadre.size.y * fmod(float(m) * 0.382, 1.0) - _dechire * (60.0 + float(m % 5) * 20.0)
			draw_circle(Vector2(mx, my), 2.0 + float(m % 3), Color(COL_OR.r, COL_OR.g, COL_OR.b, (1.0 - _dechire) * 0.8))


## Un fil : crème et doré au-dessus du monde, encre sombre sur le parchemin — sinon il disparaît
## dans le crème de l'encart. Coupé en deux polylignes au bord haut de l'encart.
func _dessiner_fil(pts: PackedVector2Array, a: float) -> void:
	var dehors: PackedVector2Array = PackedVector2Array()
	var dedans: PackedVector2Array = PackedVector2Array()
	for p in pts:
		if _cadre.has_point(p):
			if dedans.is_empty() and not dehors.is_empty():
				dedans.append(dehors[dehors.size() - 1])  # jonction
			dedans.append(p)
		else:
			dehors.append(p)
	if dehors.size() >= 2:
		draw_polyline(dehors, Color(COL_OR.r, COL_OR.g, COL_OR.b, a * 0.35), 3.0, true)
		draw_polyline(dehors, Color(COL_FIL.r, COL_FIL.g, COL_FIL.b, a), 1.2, true)
	if dedans.size() >= 2:
		draw_polyline(dedans, Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, a * 0.9), 1.4, true)
