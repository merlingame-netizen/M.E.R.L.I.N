class_name MerlinParchemin
extends Control
## LE PAPIER DE L'ENCART — grain de parchemin, bords irréguliers, fibres (08/09).
##
## POURQUOI. L'encart était un rectangle crème à coins ronds : propre, et mort. Maxime a choisi que le
## cœur de l'écran devienne un objet : un grain procédural (des points d'encre presque invisibles),
## des bords qui ne sont pas tout à fait droits, quelques fibres. Aucune texture importée, aucune
## palette nouvelle : l'encre du jeu sur le crème du jeu, à des alphas qu'on ne voit qu'en somme.
##
## POSÉ EN PREMIER ENFANT du PanelContainer : il se dessine sous le texte et sur le fond du panneau.
## Le grain est tiré UNE fois (graine stable) et ne se redessine qu'au redimensionnement : rien par
## image, le coût est nul pendant la lecture.

const GRAINS: int = 320
const COL_ENCRE: Color = MerlinVisual.INK

var _pts: PackedVector2Array = PackedVector2Array()
var _tailles: PackedFloat32Array = PackedFloat32Array()
var _fibres: Array = []
var _graine: int = 1789


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_retirer)
	_retirer()


func _retirer() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _graine
	_pts = PackedVector2Array()
	_tailles = PackedFloat32Array()
	for i in GRAINS:
		_pts.append(Vector2(rng.randf() * w, rng.randf() * h))
		_tailles.append(rng.randf_range(0.6, 1.6))
	_fibres = []
	for f in 5:
		var y: float = rng.randf_range(0.08, 0.92) * h
		var x0: float = rng.randf_range(0.02, 0.5) * w
		var lon: float = rng.randf_range(0.08, 0.22) * w
		_fibres.append([Vector2(x0, y), Vector2(minf(x0 + lon, w - 8.0), y + rng.randf_range(-3.0, 3.0))])
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0 or _pts.is_empty():
		return
	# LE GRAIN : des points d'encre à 3,5 % — invisibles un à un, une matière en somme.
	var grain: Color = Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.035)
	for i in _pts.size():
		draw_circle(_pts[i], _tailles[i], grain)
	# LES FIBRES : cinq traits à peine plus sombres, comme dans une feuille faite main.
	var fibre: Color = Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.035)
	for f in _fibres:
		draw_line(f[0], f[1], fibre, 1.0, true)
	# LES BORDS IRRÉGULIERS : le haut et le bas ne sont pas des droites. Une ligne d'encre pâle qui
	# ondule à deux pixels du bord, par-dessus le liseré du panneau.
	var bord: Color = Color(COL_ENCRE.r, COL_ENCRE.g, COL_ENCRE.b, 0.08)
	for cote in 2:
		var y0: float = 5.0 if cote == 0 else h - 5.0
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 41:
			var u: float = float(k) / 40.0
			var x: float = 8.0 + u * (w - 16.0)
			var d: float = sin(u * 23.0 + float(cote) * 3.0) * 1.2 + sin(u * 61.0 + float(cote)) * 0.6
			pts.append(Vector2(x, y0 + d))
		draw_polyline(pts, bord, 1.2, true)
