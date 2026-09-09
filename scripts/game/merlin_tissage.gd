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
	# 09/09 (Maxime : « les liens tissés ne sont pas design ») — UN MÉTIER, PAS UN FOUILLIS. Neuf fils
	# de chaîne symétriques, en courbes lisses, de la lune au bord haut de l'encart ; dedans, une
	# navette d'or va et vient et laisse derrière elle une bande tissée qui descend avec le temps.
	# Rien ne tremble : la seule chose qui bouge est la navette, et la bande qui grandit.
	var n_fils: int = 9
	var poses: int = mini(n_fils, 1 + int(t / CADENCE_S))
	for i in n_fils:
		var u: float = (float(i) + 0.5) / float(n_fils)
		var x_haut: float = _cadre.position.x + _cadre.size.x * (0.08 + 0.84 * u)
		if i >= poses:
			continue
		var ordre: int = absi(i - n_fils / 2)   # du centre vers les bords
		var age: float = t - float(ordre) * CADENCE_S * 0.6
		var avance: float = clampf(age / 1.2, 0.0, 1.0)
		var haut: Vector2 = Vector2(x_haut, _cadre.position.y)
		var ctrl: Vector2 = Vector2(lerpf(_lune.x, x_haut, 0.35), lerpf(_lune.y, haut.y, 0.62))
		var pts: PackedVector2Array = PackedVector2Array()
		var segs: int = 20
		for k in segs + 1:
			var f: float = float(k) / float(segs)
			if f > avance:
				break
			var p: Vector2 = _lune.lerp(ctrl, f).lerp(ctrl.lerp(haut, f), f)  # quadratique
			if _dechire > 0.0:
				p += Vector2(sin(float(i) * 1.3 + float(k) * 0.4) * 30.0, 40.0 + float(k) * 3.0) * _dechire
			pts.append(p)
		if pts.size() >= 2:
			var a: float = (0.55 - 0.03 * float(ordre)) * _alpha
			draw_polyline(pts, Color(COL_OR.r, COL_OR.g, COL_OR.b, a * 0.30), 3.0, true)
			draw_polyline(pts, Color(COL_FIL.r, COL_FIL.g, COL_FIL.b, a), 1.3, true)
			if avance < 1.0:
				draw_circle(pts[pts.size() - 1], 2.4, Color(COL_OR.r, COL_OR.g, COL_OR.b, 0.9 * _alpha))
	# LA BANDE TISSÉE : elle descend du bord haut à raison d'un huitième de l'encart toutes les 6 s,
	# sans jamais atteindre le bas (l'issue arrive quand elle arrive). Hachures fines, encre sombre.
	var debut_bande: float = float(n_fils / 2) * CADENCE_S * 0.6 + 1.2
	var hauteur: float = 0.0
	if t > debut_bande:
		hauteur = _cadre.size.y * 0.85 * (1.0 - exp(-(t - debut_bande) / 40.0))
	if hauteur > 2.0 and _dechire < 1.0:
		var y0: float = _cadre.position.y + 6.0
		var pas: float = 7.0
		var k2: int = 0
		var y: float = y0
		while y < y0 + hauteur:
			var decal: float = (pas * 0.5) if k2 % 2 == 0 else 0.0
			var x_a: float = _cadre.position.x + 12.0 + decal + sin(float(k2) * 0.7) * 2.0
			var x_b: float = _cadre.end.x - 12.0 - decal
			var chute: float = _dechire * (30.0 + float(k2 % 5) * 12.0)
			draw_line(Vector2(x_a, y + chute), Vector2(x_b, y + chute), Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.22 * _alpha * (1.0 - _dechire)), 1.0, true)
			y += pas
			k2 += 1
		# LA NAVETTE : un losange d'or qui va et vient sur la ligne en train de se tisser.
		var va: float = fmod(t * 0.45, 2.0)
		var f_nav: float = va if va <= 1.0 else 2.0 - va
		var nx: float = lerpf(_cadre.position.x + 14.0, _cadre.end.x - 14.0, f_nav)
		var ny: float = y0 + hauteur
		draw_colored_polygon(PackedVector2Array([Vector2(nx - 9.0, ny), Vector2(nx, ny - 4.0), Vector2(nx + 9.0, ny), Vector2(nx, ny + 4.0)]),
			Color(COL_OR.r, COL_OR.g, COL_OR.b, 0.9 * _alpha * (1.0 - _dechire)))
		draw_line(Vector2(_cadre.position.x + 12.0, ny), Vector2(nx, ny), Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.35 * _alpha), 1.2, true)
	# LES MOTES DE LA DÉCHIRURE : quelques points d'or qui s'envolent quand le tissu cède.
	if _dechire > 0.0:
		for m in 14:
			var mx: float = _cadre.position.x + _cadre.size.x * fmod(float(m) * 0.618, 1.0)
			var my: float = _cadre.position.y + _cadre.size.y * fmod(float(m) * 0.382, 1.0) - _dechire * (60.0 + float(m % 5) * 20.0)
			draw_circle(Vector2(mx, my), 2.0 + float(m % 3), Color(COL_OR.r, COL_OR.g, COL_OR.b, (1.0 - _dechire) * 0.8))
