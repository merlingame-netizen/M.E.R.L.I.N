class_name MerlinBeatMap
extends Control
## v10.12 — Carte « map » façon Slay the Spire : dessine le CHEMIN du run dans un petit panneau-carte
## (coin droit du HUD). Sentier vertical en zigzag (nœuds reliés), position « tu es ici » mise en valeur,
## beats passés/à-venir distincts, + marqueur de déviation quand le joueur DRAFTE une carte.
## DA flat verrouillée (crème/encre/or, zéro dégradé). Dessiné via _draw (panneau + sentier net).
## v1 LINÉAIRE ; la vraie ramification (branches découvertes au beat) = chantier suivant (roadmap B1).

const W: float = 120.0
const SPACING: float = 52.0        # centre-à-centre des nœuds
const TOP_PAD: float = 44.0        # place pour l'en-tête « CHEMIN »
const NODE_R: float = 6.0
const NODE_R_CUR: float = 9.0      # nœud courant « tu es ici »
const WIND: float = 14.0           # amplitude du zigzag (sentier)

const COL_PANEL: Color = MerlinVisual.PANEL        # surface du panneau (un peu plus clair que le fond)
const COL_BORDER: Color = MerlinVisual.BORDER_BRUN # liseré brun (comme une carte Commune)
const COL_PARCH: Color = MerlinVisual.CREAM
const COL_INK: Color = MerlinVisual.INK
const COL_DIM: Color = MerlinVisual.INK_DIM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_FUTURE: Color = MerlinVisual.RING_BG
const COL_DEV: Color = MerlinVisual.RARE_BLUE      # déviation = bleu-acier (rareté Rare)

var _total: int = 0
var _current: int = 0
var _draft_marks: Dictionary = {}   # index de beat → déviation draftée


func setup(total: int) -> void:
	_total = maxi(total, 1)
	_draft_marks = {}
	queue_redraw()


func set_current(idx: int) -> void:
	_current = clampi(idx, 0, maxi(_total - 1, 0))
	queue_redraw()


func mark_draft() -> void:
	_draft_marks[_current] = true
	queue_redraw()


func _node_pos(i: int) -> Vector2:
	var x: float = W * 0.5 + (WIND if (i % 2 == 1) else -WIND)  # zigzag = sentier
	var y: float = TOP_PAD + NODE_R_CUR + float(i) * SPACING
	return Vector2(x, y)


func _draw() -> void:
	if _total <= 0:
		return
	var sz: Vector2 = size
	# Panneau-carte (fond plat + liseré) → lisible comme une « carte map », pas une barre.
	draw_rect(Rect2(Vector2.ZERO, sz), COL_PANEL, true)
	draw_rect(Rect2(Vector2.ZERO, sz), COL_BORDER, false, 2.0)
	# En-tête « CHEMIN ».
	var font: Font = get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(0.0, 26.0), "CHEMIN", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, COL_GOLD)
	# Connecteurs du sentier : déjà parcouru = encre, à-venir = encre claire.
	for i in range(_total - 1):
		var col: Color = COL_INK if i < _current else COL_DIM
		draw_line(_node_pos(i), _node_pos(i + 1), col, 3.0)
	# Nœuds.
	for i in _total:
		var p: Vector2 = _node_pos(i)
		if _draft_marks.has(i):
			# Déviation draftée : embranchement latéral (« on peut sortir du chemin »).
			var d: Vector2 = p + Vector2(18.0, -4.0)
			draw_line(p, d, COL_DEV, 2.0)
			draw_circle(d, 5.0, COL_DEV)
		if i < _current:
			draw_circle(p, NODE_R, COL_INK)                 # passé (plein encre)
		elif i == _current:
			draw_circle(p, NODE_R_CUR + 3.0, COL_GOLD)      # halo « tu es ici »
			draw_circle(p, NODE_R_CUR, COL_PANEL)
			draw_circle(p, NODE_R_CUR - 3.0, COL_GOLD)
		else:
			draw_circle(p, NODE_R, COL_DIM)                 # à venir (anneau)
			draw_circle(p, NODE_R - 2.0, COL_FUTURE)
