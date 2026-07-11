class_name MerlinGlyph
extends Control
## Icône-ligne celtique minimaliste, dessinée en moteur (DA flat rétro-minimaliste, décision 2026-05-26).
## Glyphe choisi par FAMILLE de tag. Trait fin "ink" sur fond crème. Aucun asset externe.

var glyph: String = "eye"
var line_color: Color = MerlinVisual.INK
var line_w: float = 2.5
# N4-RUNES (2026-07-11) : >= 0 = mode RUNE OGHAM INVENTÉE (le _draw dessine le motif procédural
# via draw_rune_on au lieu du glyphe nommé). -1 = mode glyphe nommé historique (menu, ornements).
var rune_pattern: int = -1

# N4-RUNES : tag canon -> motif de REPLI (cartes de présentation de greffe/talent, pips de slot).
# La rune du CONCEPT quand la carte n'a pas de motif propre. Clés normalisées (MerlinTags.to_canon).
# Revue de code N4 (MEDIUM-2) : plage 50-74, DISJOINTE des motifs propres des cartes canon (0-46)
# et du motif générique 47 : un pip de tag ne peut jamais être confondu avec la rune d'une carte
# (les motifs >= 50 portent leur propre marque, un anneau gravé au pied de la tige).
const TAG_PATTERN_BASE: int = 50
const PATTERN_GENERIC: int = 47  # rune générique (cartes de présentation roll/charge sans tag)
const TAG_PATTERNS: Dictionary = {
	"sens": 50, "savoir": 51, "memoire": 52, "vigilance": 53,
	"force": 54, "agilite": 55, "endurance": 56, "finesse": 57,
	"empathie": 58, "verbe": 59, "ruse": 60, "autorite": 61, "franchise": 62,
	"instinct": 63, "nature": 64, "vision": 65,
	"rituel": 66, "sacrifice": 67, "equilibre": 68, "mystere": 69,
	"vide": 70, "glitch": 71, "dissolution": 72, "murmure": 73, "emprise": 74,
}


# N4-RUNES : motif ogham stable d'un tag-concept (repli des cartes sans motif propre).
# Tag inconnu (garde-fou LLM) -> rune générique 47, jamais la rune d'une carte canon.
static func pattern_for_tag(tag: String) -> int:
	var n: String = MerlinTags.to_canon(tag)
	return int(TAG_PATTERNS.get(n, PATTERN_GENERIC))


# N4-RUNES : dessine le motif ogham `pattern` sur n'importe quel CanvasItem (grande carte-rune,
# pip de slot de greffe). Style gravure : ligne-tige VERTICALE pleine hauteur + 1-5 traits
# latéraux/traversants/obliques/chevrons. Encodage procédural du motif p :
#   série  = p % 5   (0 droite, 1 gauche, 2 traversant, 3 oblique, 4 chevron)
#   nombre = 1 + (p / 5) % 5   (1 à 5 traits)
# Plages DISJOINTES (revue de code N4, MEDIUM-2) :
#   0-24  = runes canon simples ; 25-49 = runes canon à marque-point (sommet de tige) ;
#   50-74 = motifs de TAG-CONCEPT, marqués d'un ANNEAU gravé au pied de la tige (jamais confondus).
static func draw_rune_on(ci: CanvasItem, center: Vector2, half_h: float, pattern: int, col: Color, w: float) -> void:
	var p: int = maxi(pattern, 0)
	var series: int = p % 5
	var count: int = 1 + int(float(p) / 5.0) % 5
	var len_x: float = half_h * 0.55
	ci.draw_line(center + Vector2(0.0, -half_h), center + Vector2(0.0, half_h), col, w, true)
	var span: float = half_h * 1.2
	for i in count:
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var y: float = -span * 0.5 + span * t
		match series:
			0:  # traits perpendiculaires à DROITE de la tige
				ci.draw_line(center + Vector2(0.0, y), center + Vector2(len_x, y), col, w, true)
			1:  # traits perpendiculaires à GAUCHE
				ci.draw_line(center + Vector2(-len_x, y), center + Vector2(0.0, y), col, w, true)
			2:  # traits TRAVERSANTS perpendiculaires
				ci.draw_line(center + Vector2(-len_x, y), center + Vector2(len_x, y), col, w, true)
			3:  # traits traversants OBLIQUES (gravure inclinée)
				ci.draw_line(center + Vector2(-len_x, y + len_x * 0.35),
					center + Vector2(len_x, y - len_x * 0.35), col, w, true)
			4:  # CHEVRONS : pointe sur la tige, branches vers la droite
				ci.draw_polyline(PackedVector2Array([
					center + Vector2(len_x, y - len_x * 0.45), center + Vector2(0.0, y),
					center + Vector2(len_x, y + len_x * 0.45)]), col, w, true)
	if p >= TAG_PATTERN_BASE:
		# Plage tag-concept (50-74) : ANNEAU gravé au pied de la tige, marque propre de la plage.
		ci.draw_arc(center + Vector2(half_h * 0.35, half_h * 0.82), maxf(w * 1.1, 2.4),
			0.0, TAU, 12, col, maxf(w * 0.6, 1.2), true)
	elif p >= 25:
		ci.draw_circle(center + Vector2(half_h * 0.35, -half_h * 0.82), maxf(w * 0.9, 2.0), col)


# Famille de tag (MerlinTags) → clé de glyphe. (conservé : utilisé ailleurs)
static func for_family(fam: String) -> String:
	match fam:
		"Perception": return "eye"
		"Corps": return "sword"
		"Parole": return "spiral"
		"Intuition": return "crescent"
		"Monde": return "sun"
		"Corrompu": return "rift"
		_: return "eye"


# v10.5 (user 2026-06-06) — un glyphe DISTINCT par tag-concept (25), pour que le logo de la carte
# reflète son concept exact et plus seulement sa famille. Normalise via MerlinTags.to_canon.
static func for_tag(tag: String) -> String:
	var n: String = MerlinTags.to_canon(tag)
	match n:
		# Perception
		"sens": return "eye"
		"savoir": return "book"
		"memoire": return "spiral"
		"vigilance": return "target"
		# Corps
		"force": return "sword"
		"agilite": return "wind"
		"endurance": return "tree"
		"finesse": return "compass"
		# Parole
		"empathie": return "heart"
		"verbe": return "speech"
		"ruse": return "knot"
		"autorite": return "crown"
		"franchise": return "sun"
		# Intuition
		"instinct": return "spark"
		"nature": return "leaf"
		"vision": return "crescent"
		# Monde
		"rituel": return "triskele"
		"sacrifice": return "flame"
		"equilibre": return "balance"
		"mystere": return "rune"
		# Corrompu
		"vide": return "void"
		"glitch": return "rift"
		"dissolution": return "ash"
		"murmure": return "waves"
		"emprise": return "chain"
		_: return "eye"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(p_glyph: String, p_color: Color = MerlinVisual.INK, p_width: float = 2.5) -> void:
	glyph = p_glyph
	rune_pattern = -1
	line_color = p_color
	line_w = p_width
	queue_redraw()


# N4-RUNES : bascule la vue en mode rune ogham (motif procédural, voir draw_rune_on).
func setup_rune(p_pattern: int, p_color: Color = MerlinVisual.INK, p_width: float = 2.5) -> void:
	rune_pattern = maxi(p_pattern, 0)
	line_color = p_color
	line_w = p_width
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c: Vector2 = s * 0.5
	if rune_pattern >= 0:  # N4-RUNES : mode rune ogham (grand glyphe gravé, cartes-runes)
		# fix flake bugres : appel SANS préfixe de classe (l'auto-référence MerlinGlyph. dans son
		# propre _draw créait une arête de dépendance inutile pour le résolveur GDScript).
		draw_rune_on(self, c, minf(s.x, s.y) * 0.45, rune_pattern, line_color, line_w)
		return
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
		# === v10.5 — glyphes par tag (user 2026-06-06) ===
		"wind":  # agilité — 3 rafales courbes
			for wd_i in 3:
				var wd_y: float = lerpf(-r * 0.5, r * 0.5, float(wd_i) / 2.0)
				var wd_len: float = r * (1.0 - 0.18 * float(wd_i))
				draw_arc(c + Vector2(-wd_len * 0.2, wd_y), wd_len * 0.6, deg_to_rad(-70), deg_to_rad(90), 16, line_color, line_w, true)
		"heart":  # empathie — cœur (2 arcs + pointe)
			draw_arc(c + Vector2(-r * 0.42, -r * 0.25), r * 0.45, deg_to_rad(150), deg_to_rad(390), 20, line_color, line_w, true)
			draw_arc(c + Vector2(r * 0.42, -r * 0.25), r * 0.45, deg_to_rad(150), deg_to_rad(390), 20, line_color, line_w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.02), c + Vector2(0.0, r), c + Vector2(r * 0.8, r * 0.02)]), line_color, line_w, true)
		"speech":  # verbe — bulle de parole avec queue
			draw_arc(c + Vector2(0.0, -r * 0.1), r * 0.85, 0.0, TAU, 40, line_color, line_w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.65), c + Vector2(-r * 0.55, r * 1.1), c + Vector2(0.05, r * 0.7)]), line_color, line_w, true)
		"knot":  # ruse — nœud celtique entrelacé (2 boucles croisées)
			draw_arc(c + Vector2(-r * 0.3, 0.0), r * 0.55, deg_to_rad(-90), deg_to_rad(180), 24, line_color, line_w, true)
			draw_arc(c + Vector2(r * 0.3, 0.0), r * 0.55, deg_to_rad(90), deg_to_rad(360), 24, line_color, line_w, true)
		"flame":  # sacrifice — flamme
			draw_polyline(PackedVector2Array([
				c + Vector2(0.0, r), c + Vector2(-r * 0.55, r * 0.3), c + Vector2(-r * 0.2, -r * 0.2),
				c + Vector2(0.0, -r), c + Vector2(r * 0.3, -r * 0.1), c + Vector2(r * 0.55, r * 0.35),
				c + Vector2(0.0, r)]), line_color, line_w, true)
			draw_arc(c + Vector2(0.0, r * 0.35), r * 0.3, 0.0, TAU, 16, line_color, line_w, true)
		"balance":  # équilibre — balance (fléau + 2 plateaux)
			draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r * 0.6), line_color, line_w, true)
			draw_line(c + Vector2(-r, -r * 0.65), c + Vector2(r, -r * 0.65), line_color, line_w, true)
			draw_arc(c + Vector2(-r, -r * 0.4), r * 0.4, 0.0, PI, 14, line_color, line_w, true)
			draw_arc(c + Vector2(r, -r * 0.4), r * 0.4, 0.0, PI, 14, line_color, line_w, true)
			draw_line(c + Vector2(-r * 0.45, r * 0.6), c + Vector2(r * 0.45, r * 0.6), line_color, line_w, true)
		"void":  # vide — anneau brisé évidé (cercle pointillé)
			for vd_i in 12:
				if vd_i % 2 == 0:
					var vd_a0: float = float(vd_i) / 12.0 * TAU
					var vd_a1: float = float(vd_i + 1) / 12.0 * TAU
					draw_arc(c, r, vd_a0, vd_a1, 6, line_color, line_w, true)
		"ash":  # dissolution — particules tombantes
			draw_arc(c + Vector2(0.0, -r * 0.5), r * 0.55, deg_to_rad(200), deg_to_rad(340), 16, line_color, line_w, true)
			for as_i in 6:
				var as_x: float = lerpf(-r * 0.6, r * 0.6, float(as_i) / 5.0)
				var as_y: float = r * (0.1 + 0.55 * fmod(float(as_i) * 0.37, 1.0))
				draw_circle(c + Vector2(as_x, as_y), line_w * 1.1, line_color)
		"waves":  # murmure — ondes sonores concentriques (arcs)
			for wv_i in 3:
				var wv_r: float = r * (0.35 + 0.32 * float(wv_i))
				draw_arc(c + Vector2(-r * 0.6, 0.0), wv_r, deg_to_rad(-55), deg_to_rad(55), 16, line_color, line_w, true)
		"chain":  # emprise — 2 maillons de chaîne
			draw_arc(c + Vector2(-r * 0.35, 0.0), r * 0.42, 0.0, TAU, 20, line_color, line_w, true)
			draw_arc(c + Vector2(r * 0.35, 0.0), r * 0.42, 0.0, TAU, 20, line_color, line_w, true)
		_:
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)
