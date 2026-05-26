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
		_:
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)
