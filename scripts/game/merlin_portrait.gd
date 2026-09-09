class_name MerlinPortrait
extends Control
## LE PORTRAIT — quand une figure parle, elle a un visage, un nom, une attitude et sa parole (09/09).
##
## POURQUOI. Une parole noyée dans la prose se lit comme le reste ; Maxime a demandé qu'un monstre
## ou un PNJ qui parle ouvre un portrait avec ce qu'il dit et comment il se comporte. Le portrait est
## une carte sombre posée sur le coin haut-gauche de l'encart, avec une silhouette procédurale par
## figure (le même plat deux tons que le décor), le nom en or, l'attitude en petit, la parole en crème.
## Rien d'importé : treize silhouettes en polygones, une par figure du canon, et une pour l'inconnu.

const LARGEUR: float = 460.0
const HAUTEUR: float = 132.0
const COL_SIL: Color = MerlinVisual.SILHOUETTE

var _qui: String = ""
var _nom: String = ""
var _attitude: String = ""
var _dit: String = ""
var _t: float = 0.0
var _visible_f: float = 0.0   # 0 = caché, 1 = posé (glisse + fondu)
var _nom_lbl: Label
var _att_lbl: Label
var _dit_lbl: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LARGEUR, HAUTEUR)
	size = Vector2(LARGEUR, HAUTEUR)
	_nom_lbl = MerlinVisual.make_label(MerlinVisual.GOLD, MerlinVisual.FS_CAPTION)
	_nom_lbl.position = Vector2(118.0, 10.0)
	_nom_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nom_lbl)
	_att_lbl = MerlinVisual.make_label(MerlinVisual.DIM_WARM, MerlinVisual.FS_HINT - 2)
	_att_lbl.position = Vector2(118.0, 36.0)
	_att_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_att_lbl)
	_dit_lbl = RichTextLabel.new()
	_dit_lbl.bbcode_enabled = true
	_dit_lbl.fit_content = true
	_dit_lbl.scroll_active = false
	_dit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dit_lbl.add_theme_color_override("default_color", MerlinVisual.CREAM)
	_dit_lbl.add_theme_font_size_override("normal_font_size", MerlinVisual.FS_HINT)
	_dit_lbl.position = Vector2(118.0, 58.0)
	_dit_lbl.size = Vector2(LARGEUR - 132.0, HAUTEUR - 66.0)
	_dit_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dit_lbl)
	modulate.a = 0.0
	visible = false
	set_process(false)


## Pose le portrait : `qui` est une clé de MerlinProse.FIGURES (ou « inconnu »).
func montrer(qui: String, nom: String, attitude: String, dit: String) -> void:
	_qui = qui if qui != "" else "inconnu"
	_nom = nom if nom != "" else str(MerlinProse.NOMS_EN_CLAIR.get(_qui, "Une voix"))
	_attitude = attitude
	_dit = dit
	_nom_lbl.text = _nom
	_att_lbl.text = ("— " + attitude) if attitude != "" else ""
	_dit_lbl.text = "[i]« %s »[/i]" % dit
	visible = true
	set_process(true)
	if MerlinVisual.reduced_motion:
		modulate.a = 1.0
		_visible_f = 1.0
		queue_redraw()
		return
	var tw: Tween = MerlinTween.retween(self, "portrait")
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_visible_f", 1.0, 0.36).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func cacher() -> void:
	if not visible:
		return
	if MerlinVisual.reduced_motion:
		visible = false
		modulate.a = 0.0
		set_process(false)
		return
	var tw: Tween = MerlinTween.retween(self, "portrait")
	tw.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: visible = false; set_process(false))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# La carte : sombre, liseré d'or, glissée depuis la gauche.
	var dx: float = (1.0 - _visible_f) * -24.0
	var cadre: Rect2 = Rect2(Vector2(dx, 0.0), size)
	var fond: Color = MerlinVisual.BG_DEEP.lerp(MerlinVisual.MERLIN_SPEECH_BG, 0.35)
	draw_rect(cadre, Color(fond.r, fond.g, fond.b, 0.96), true)
	draw_rect(cadre, MerlinVisual.GOLD, false, 2.0)
	# Le médaillon : un disque d'encre, et la silhouette dedans.
	var c: Vector2 = Vector2(dx + 60.0, HAUTEUR * 0.5)
	draw_circle(c, 48.0, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, 1.0))
	draw_arc(c, 48.0, 0.0, TAU, 40, MerlinVisual.GOLD_DARK, 1.5, true)
	_silhouette(_qui, c, 40.0)


## La silhouette d'une figure, dans un cercle de rayon `r`. Plat, deux tons, un accent.
func _silhouette(qui: String, c: Vector2, r: float) -> void:
	var accent: Color = MerlinVisual.GOLD
	var corps: Color = COL_SIL.lerp(MerlinVisual.CREAM, 0.22)
	var bob: float = 0.0 if MerlinVisual.reduced_motion else sin(_t * 0.9) * 1.2
	var pied: Vector2 = c + Vector2(0.0, r * 0.95 + bob)
	match qui:
		"choeur":
			accent = MerlinVisual.GREEN
			_robe(pied, r * 1.7, r * 0.34, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.55), r * 0.30, corps)
			draw_line(pied + Vector2(r * 0.5, 0.0), pied + Vector2(r * 0.5, -r * 1.9), corps, 2.5, true)
			draw_circle(pied + Vector2(r * 0.5, -r * 1.95), r * 0.12, accent)
		"ankou":
			accent = MerlinVisual.DIM_WARM
			_robe(pied, r * 1.8, r * 0.26, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.62), r * 0.24, corps)
			draw_line(pied + Vector2(-r * 0.55, -r * 1.72), pied + Vector2(r * 0.55, -r * 1.72), corps, 3.0, true)  # le chapeau
			draw_line(pied + Vector2(-r * 0.6, 0.0), pied + Vector2(-r * 0.6, -r * 2.0), corps, 2.0, true)      # la faux
			draw_line(pied + Vector2(-r * 0.6, -r * 2.0), pied + Vector2(-r * 0.15, -r * 1.85), accent, 2.0, true)
		"lavandiere":
			accent = MerlinVisual.CREAM
			draw_colored_polygon(PackedVector2Array([pied + Vector2(-r * 0.5, 0.0), pied + Vector2(r * 0.55, 0.0),
				pied + Vector2(r * 0.35, -r * 0.9), pied + Vector2(-r * 0.2, -r * 1.0)]), corps)
			draw_circle(pied + Vector2(0.05 * r, -r * 1.2), r * 0.24, corps)
			draw_rect(Rect2(pied + Vector2(-r * 0.9, -r * 0.35), Vector2(r * 0.6, r * 0.3)), accent, true)  # le linge
		"korrigan":
			accent = MerlinVisual.EYE_ANGRY
			_robe(pied, r * 0.9, r * 0.3, corps)
			draw_circle(pied + Vector2(0.0, -r * 0.95), r * 0.3, corps)
			for s in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([pied + Vector2(s * r * 0.12, -r * 1.15), pied + Vector2(s * r * 0.32, -r * 1.15),
					pied + Vector2(s * r * 0.3, -r * 1.5)]), accent)
		"fanch":
			accent = MerlinVisual.GOLD
			_robe(pied, r * 1.3, r * 0.34, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.2), r * 0.26, corps)
			draw_rect(Rect2(pied + Vector2(r * 0.25, -r * 1.15), Vector2(r * 0.45, r * 0.7)), COL_SIL.lerp(accent, 0.35), true)  # la balle
		"kado":
			accent = MerlinVisual.GOLD_DARK
			draw_colored_polygon(PackedVector2Array([pied + Vector2(-r * 0.55, 0.0), pied + Vector2(r * 0.55, 0.0),
				pied + Vector2(r * 0.4, -r * 1.1), pied + Vector2(-r * 0.4, -r * 1.1)]), corps)
			draw_circle(pied + Vector2(0.0, -r * 1.3), r * 0.26, corps)
			draw_arc(pied + Vector2(0.0, -r * 0.45), r * 0.3, 0.0, TAU, 20, accent, 2.0, true)  # la corde enroulée
		"chevalier":
			accent = MerlinVisual.GOLD.lerp(MerlinVisual.DIM_WARM, 0.45)
			draw_colored_polygon(PackedVector2Array([pied + Vector2(-r * 0.6, 0.0), pied + Vector2(r * 0.6, 0.0),
				pied + Vector2(r * 0.45, -r * 1.3), pied + Vector2(-r * 0.45, -r * 1.3)]), corps)
			draw_circle(pied + Vector2(r * 0.1, -r * 1.42), r * 0.24, corps)
			draw_line(pied + Vector2(-r * 0.8, -r * 0.9), pied + Vector2(-r * 0.8, 0.0), accent, 2.0, true)  # la lame plantée
		"enfant":
			accent = MerlinVisual.CREAM
			_robe(pied, r * 0.8, r * 0.22, corps)
			draw_circle(pied + Vector2(0.0, -r * 0.95), r * 0.3, corps)
			_etoile(pied + Vector2(r * 0.5, -r * 0.5), r * 0.1, accent)
		"etre":
			accent = MerlinVisual.RARE_BLUE
			draw_colored_polygon(PackedVector2Array([pied + Vector2(-r * 0.25, 0.0), pied + Vector2(r * 0.25, 0.0),
				pied + Vector2(r * 0.35, -r * 1.85), pied + Vector2(0.05 * r, -r * 1.85)]), corps)
			draw_circle(pied + Vector2(r * 0.25, -r * 1.95), r * 0.14, corps)
			draw_circle(pied + Vector2(r * 0.19, -r * 1.97), 1.6, accent)
			draw_circle(pied + Vector2(r * 0.31, -r * 1.97), 1.6, accent)
		"arthur":
			accent = MerlinVisual.GOLD
			_robe(pied, r * 1.0, r * 0.36, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.05), r * 0.26, corps)
			for k in 3:
				var x: float = (float(k) - 1.0) * r * 0.16
				draw_colored_polygon(PackedVector2Array([pied + Vector2(x - r * 0.07, -r * 1.28), pied + Vector2(x + r * 0.07, -r * 1.28), pied + Vector2(x, -r * 1.45)]), accent)
		"marcharit":
			accent = MerlinVisual.RARE_BLUE.lerp(MerlinVisual.CREAM, 0.4)
			_robe(pied, r * 1.6, r * 0.28, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.5), r * 0.26, corps)
			for k in 3:
				var y: float = -r * (1.4 - 0.25 * float(k))
				draw_line(pied + Vector2(-r * 0.3, y), pied + Vector2(-r * 0.75 + sin(_t + float(k)) * 3.0, y + r * 0.25), accent, 1.6, true)  # les cheveux qui flottent
		"erwan":
			accent = MerlinVisual.CREAM
			_robe(pied, r * 1.5, r * 0.3, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.4), r * 0.25, corps)
			draw_rect(Rect2(pied + Vector2(r * 0.3, -r * 0.9), Vector2(r * 0.4, r * 0.5)), COL_SIL.lerp(accent, 0.3), true)  # l'ardoise
			for k in 3:
				draw_line(pied + Vector2(r * 0.36 + float(k) * r * 0.1, -r * 0.85), pied + Vector2(r * 0.36 + float(k) * r * 0.1, -r * 0.5), accent, 1.2, true)
		"aveline":
			accent = MerlinVisual.VIOLET
			_robe(pied, r * 1.6, r * 0.32, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.5), r * 0.26, corps)
			draw_line(pied + Vector2(r * 0.4, -r * 1.75), pied + Vector2(r * 0.7, -r * 1.65), accent, 2.0, true)  # un corbeau
			draw_line(pied + Vector2(r * 0.7, -r * 1.65), pied + Vector2(r * 1.0, -r * 1.75), accent, 2.0, true)
		_:
			_robe(pied, r * 1.5, r * 0.32, corps)
			draw_circle(pied + Vector2(0.0, -r * 1.45), r * 0.26, corps)
	if _attitude != "":
		# L'attitude teinte le liseré du médaillon : menace en rouge, supplique en violet, moquerie en or.
		var a: String = _attitude.to_lower()
		var col: Color = accent
		if a.contains("menac") or a.contains("colère") or a.contains("colere") or a.contains("furi"):
			col = MerlinVisual.EYE_ANGRY
		elif a.contains("suppli") or a.contains("triste") or a.contains("las"):
			col = MerlinVisual.VIOLET
		elif a.contains("moqu") or a.contains("malic") or a.contains("rieur"):
			col = MerlinVisual.GOLD
		draw_arc(c, 44.0, -PI * 0.5, PI * 0.5, 24, Color(col.r, col.g, col.b, 0.8), 2.0, true)


func _robe(pied: Vector2, haut: float, demi: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([pied + Vector2(-demi, 0.0), pied + Vector2(demi, 0.0),
		pied + Vector2(demi * 0.55, -haut * 0.82), pied + Vector2(-demi * 0.55, -haut * 0.82)]), col)


func _etoile(p: Vector2, r: float, col: Color) -> void:
	draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 1.5, true)
	draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 1.5, true)
