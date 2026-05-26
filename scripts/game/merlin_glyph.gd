class_name MerlinGlyph
extends Control
## Icône-ligne celtique minimaliste, dessinée en moteur (DA flat rétro-minimaliste, décision 2026-05-26).
## Glyphe choisi par FAMILLE de tag. Trait fin "ink" sur fond crème. Aucun asset externe.

var glyph: String = "eye"
var line_color: Color = Color("2A2018")
var line_w: float = 2.5


# Famille de tag (MerlinTags) → clé de glyphe.
static func for_family(fam: String) -> String:
	match fam:
		"Perception": return "eye"
		"Corps": return "sword"
		"Parole": return "spiral"
		"Intuition": return "crescent"
		"Monde": return "sun"
		"Corrompu": return "rift"
		_: return "eye"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(p_glyph: String, p_color: Color = Color("2A2018"), p_width: float = 2.5) -> void:
	glyph = p_glyph
	line_color = p_color
	line_w = p_width
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	var r: float = minf(s.x, s.y) * 0.34
	match glyph:
		"eye":
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)
			draw_circle(c, r * 0.30, line_color)
		"sword":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.65), line_color, line_w, true)        # lame
			draw_line(c + Vector2(-r * 0.55, -r * 0.42), c + Vector2(r * 0.55, -r * 0.42), line_color, line_w, true)  # garde
			var tip: PackedVector2Array = PackedVector2Array([
				c + Vector2(-r * 0.16, -r), c + Vector2(0, -r * 1.28), c + Vector2(r * 0.16, -r)])
			draw_polyline(tip, line_color, line_w, true)                                              # pointe
			draw_line(c + Vector2(0, r * 0.65), c + Vector2(0, r), line_color, line_w * 1.7, true)    # pommeau
		"spiral":
			var pts: PackedVector2Array = PackedVector2Array()
			var steps: int = 64
			for i in steps + 1:
				var t: float = float(i) / float(steps)
				var ang: float = t * 2.4 * TAU
				pts.append(c + Vector2(cos(ang), sin(ang)) * (r * t))
			draw_polyline(pts, line_color, line_w, true)
		"crescent":
			draw_arc(c, r, deg_to_rad(45), deg_to_rad(315), 40, line_color, line_w, true)
		"sun":
			draw_arc(c, r * 0.60, 0.0, TAU, 40, line_color, line_w, true)
			for i in 8:
				var a: float = float(i) / 8.0 * TAU
				var d: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + d * (r * 0.78), c + d * (r * 1.05), line_color, line_w, true)
		"rift":
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)
			var crack: PackedVector2Array = PackedVector2Array([
				c + Vector2(-r * 0.16, -r), c + Vector2(r * 0.12, -r * 0.32),
				c + Vector2(-r * 0.14, r * 0.06), c + Vector2(r * 0.18, r)])
			draw_polyline(crack, line_color, line_w, true)
		"spark":  # étoile à 4 branches (✦) — item sélectionné
			var spk: PackedVector2Array = PackedVector2Array()
			for spk_i in 8:
				var spk_a: float = float(spk_i) / 8.0 * TAU - PI / 2.0
				var spk_r: float = r if spk_i % 2 == 0 else r * 0.34
				spk.append(c + Vector2(cos(spk_a), sin(spk_a)) * spk_r)
			spk.append(spk[0])
			draw_polyline(spk, line_color, line_w, true)
		"burst":  # astérisque à 8 rais
			for brs_i in 8:
				var brs_a: float = float(brs_i) / 8.0 * TAU
				var brs_d: Vector2 = Vector2(cos(brs_a), sin(brs_a))
				draw_line(c + brs_d * (r * 0.22), c + brs_d * r, line_color, line_w, true)
		"book":  # livre ouvert
			var bk_mid: Vector2 = c + Vector2(0.0, r * 0.12)
			draw_polyline(PackedVector2Array([c + Vector2(-r, -r * 0.55), c + Vector2(-r, r * 0.5), bk_mid, c + Vector2(0.0, -r * 0.45), c + Vector2(-r, -r * 0.55)]), line_color, line_w, true)
			draw_polyline(PackedVector2Array([c + Vector2(r, -r * 0.55), c + Vector2(r, r * 0.5), bk_mid, c + Vector2(0.0, -r * 0.45)]), line_color, line_w, true)
			draw_line(c + Vector2(0.0, -r * 0.45), bk_mid, line_color, line_w, true)
		"cards":  # deux cartes superposées
			var cd: Vector2 = Vector2(r * 0.78, r * 1.1)
			draw_rect(Rect2(c + Vector2(-cd.x * 0.1, -cd.y * 0.55), cd), line_color, false, line_w)
			draw_rect(Rect2(c + Vector2(-cd.x * 0.6, -cd.y * 0.4), cd), line_color, false, line_w)
		"target":  # cible / réticule
			draw_arc(c, r, 0.0, TAU, 40, line_color, line_w, true)
			draw_arc(c, r * 0.5, 0.0, TAU, 32, line_color, line_w, true)
			draw_circle(c, r * 0.12, line_color)
			for tg_i in 4:
				var tg_a: float = float(tg_i) / 4.0 * TAU
				var tg_d: Vector2 = Vector2(cos(tg_a), sin(tg_a))
				draw_line(c + tg_d * (r * 0.85), c + tg_d * (r * 1.18), line_color, line_w, true)
		"cross":  # X (quitter)
			draw_line(c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.7), line_color, line_w, true)
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), line_color, line_w, true)
		"leaf":  # pousse / feuilles
			draw_line(c + Vector2(0.0, r), c + Vector2(0.0, -r * 0.2), line_color, line_w, true)
			draw_arc(c + Vector2(-r * 0.28, 0.0), r * 0.5, deg_to_rad(-40), deg_to_rad(150), 20, line_color, line_w, true)
			draw_arc(c + Vector2(r * 0.28, -r * 0.25), r * 0.5, deg_to_rad(30), deg_to_rad(220), 20, line_color, line_w, true)
		"tree":  # arbre (icône)
			draw_line(c + Vector2(0.0, r), c + Vector2(0.0, -r), line_color, line_w, true)
			draw_line(c + Vector2(0.0, r * 0.15), c + Vector2(-r * 0.6, -r * 0.5), line_color, line_w, true)
			draw_line(c + Vector2(0.0, -r * 0.15), c + Vector2(r * 0.6, -r * 0.6), line_color, line_w, true)
			draw_line(c + Vector2(0.0, -r * 0.45), c + Vector2(-r * 0.4, -r * 0.95), line_color, line_w, true)
		"crown":  # couronne
			draw_polyline(PackedVector2Array([
				c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.25), c + Vector2(-r * 0.5, r * 0.15),
				c + Vector2(0.0, -r * 0.55), c + Vector2(r * 0.5, r * 0.15), c + Vector2(r, -r * 0.25),
				c + Vector2(r, r * 0.5), c + Vector2(-r, r * 0.5)]), line_color, line_w, true)
		"compass":  # rose des vents (8 pointes pleines)
			for cmp_i in 4:
				var cmp_a: float = float(cmp_i) / 4.0 * TAU - PI / 2.0
				var cmp_d: Vector2 = Vector2(cos(cmp_a), sin(cmp_a))
				var cmp_p: Vector2 = Vector2(-cmp_d.y, cmp_d.x)
				draw_colored_polygon(PackedVector2Array([c + cmp_d * r, c + cmp_p * (r * 0.16), c - cmp_p * (r * 0.16)]), line_color)
			for cmp_j in 4:
				var cmp_b: float = float(cmp_j) / 4.0 * TAU
				var cmp_e: Vector2 = Vector2(cos(cmp_b), sin(cmp_b))
				var cmp_q: Vector2 = Vector2(-cmp_e.y, cmp_e.x)
				draw_colored_polygon(PackedVector2Array([c + cmp_e * (r * 0.62), c + cmp_q * (r * 0.1), c - cmp_q * (r * 0.1)]), line_color)
		"triskele":  # triskèle (3 arcs)
			for tk_i in 3:
				var tk_a: float = float(tk_i) / 3.0 * TAU
				var tk_o: Vector2 = c + Vector2(cos(tk_a), sin(tk_a)) * (r * 0.42)
				draw_arc(tk_o, r * 0.42, tk_a, tk_a + PI * 1.25, 24, line_color, line_w, true)
		"rune":  # marque ogham simple
			draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), line_color, line_w, true)
			for rn_i in 3:
				var rn_y: float = lerpf(-r * 0.55, r * 0.55, float(rn_i) / 2.0)
				draw_line(c + Vector2(0.0, rn_y), c + Vector2(r * 0.5, rn_y - r * 0.14), line_color, line_w, true)
		_:
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)
