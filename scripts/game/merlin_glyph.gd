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
			# R159 (Chantier 3) : oeil en AMANDE (vesica celtique) — 2 paupieres se rejoignant en pointe,
			# iris cercle + pupille pleine + reflet. Silhouette d'oeil lisible (vs l'ancien cercle+point).
			var ey_w: float = r * 1.15
			var ey_h: float = r * 0.66
			var ey_top: PackedVector2Array = PackedVector2Array()
			var ey_bot: PackedVector2Array = PackedVector2Array()
			for ey_i in 25:
				var ey_t: float = float(ey_i) / 24.0
				var ey_x: float = lerpf(-ey_w, ey_w, ey_t)
				var ey_k: float = sin(ey_t * PI)  # 0 aux commissures, 1 au centre
				ey_top.append(c + Vector2(ey_x, -ey_h * ey_k))
				ey_bot.append(c + Vector2(ey_x, ey_h * ey_k))
			draw_polyline(ey_top, line_color, line_w, true)
			draw_polyline(ey_bot, line_color, line_w, true)
			draw_arc(c, r * 0.40, 0.0, TAU, 32, line_color, line_w, true)   # iris
			draw_circle(c, r * 0.17, line_color)                            # pupille pleine
			draw_circle(c + Vector2(-r * 0.14, -r * 0.14), maxf(line_w * 0.55, 1.2), MerlinVisual.CREAM)  # reflet vif
		"sword":
			# R159 (Chantier 3) : epee — lame en FEUILLE pleine (silhouette solide) + garde relevee +
			# fusee + pommeau annele. Remplace l'ancienne lame-fil + fleche (trop grele, « cheap »).
			var sw_top: float = -r * 1.2
			var sw_guard: float = r * 0.3
			var sw_bw: float = r * 0.17
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, sw_top),
				c + Vector2(sw_bw, sw_top + r * 0.42),
				c + Vector2(sw_bw * 0.5, sw_guard),
				c + Vector2(-sw_bw * 0.5, sw_guard),
				c + Vector2(-sw_bw, sw_top + r * 0.42)]), line_color)   # lame pleine
			draw_line(c + Vector2(0.0, sw_top + r * 0.5), c + Vector2(0.0, sw_guard - r * 0.05),
				MerlinVisual.SURFACE, maxf(line_w * 0.7, 1.4), true)   # gouttiere (fuller) gravee
			draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.62, sw_guard + r * 0.08),
				c + Vector2(-r * 0.5, sw_guard - r * 0.02),
				c + Vector2(r * 0.5, sw_guard - r * 0.02),
				c + Vector2(r * 0.62, sw_guard + r * 0.08)]), line_color, line_w, true)   # garde
			draw_line(c + Vector2(0.0, sw_guard), c + Vector2(0.0, r * 0.78), line_color, line_w * 1.5, true)  # fusee
			draw_arc(c + Vector2(0.0, r * 0.92), r * 0.15, 0.0, TAU, 20, line_color, line_w, true)   # pommeau annele
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
		"speech":  # R159 (Chantier 3) : bulle de parole — ovale + queue triangulaire + 3 points (le propos)
			var sp_w: float = r * 1.02
			var sp_h: float = r * 0.72
			var sp_cy: float = -r * 0.16
			var sp_bub: PackedVector2Array = PackedVector2Array()
			for sp_i in 41:
				var sp_a: float = float(sp_i) / 40.0 * TAU
				sp_bub.append(c + Vector2(cos(sp_a) * sp_w, sp_cy + sin(sp_a) * sp_h))
			draw_polyline(sp_bub, line_color, line_w, true)          # contour de la bulle (ovale)
			draw_polyline(PackedVector2Array([                       # queue triangulaire (le locuteur)
				c + Vector2(-r * 0.34, sp_cy + sp_h * 0.72),
				c + Vector2(-r * 0.52, r * 1.02),
				c + Vector2(r * 0.02, sp_cy + sp_h * 0.86)]), line_color, line_w, true)
			for sp_j in 3:                                           # « … » : le propos, lisible a petite taille
				draw_circle(c + Vector2(lerpf(-r * 0.42, r * 0.42, float(sp_j) / 2.0), sp_cy),
					maxf(line_w * 0.95, 1.6), line_color)
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
		"chain":  # emprise : 2 maillons de chaine
			draw_arc(c + Vector2(-r * 0.35, 0.0), r * 0.42, 0.0, TAU, 20, line_color, line_w, true)
			draw_arc(c + Vector2(r * 0.35, 0.0), r * 0.42, 0.0, TAU, 20, line_color, line_w, true)
		"coin":  # Vague Economie V1 (bourse), piece frappee : 2 anneaux concentriques + 4 marques de
			# tranche (distinct de "sun", rais courts hors-anneau, et de "target", croix centrale).
			draw_arc(c, r, 0.0, TAU, 32, line_color, line_w, true)
			draw_arc(c, r * 0.6, 0.0, TAU, 24, line_color, maxf(line_w * 0.75, 1.4), true)
			for cn_i in 4:
				var cn_a: float = float(cn_i) / 4.0 * TAU + PI / 4.0
				var cn_d: Vector2 = Vector2(cos(cn_a), sin(cn_a))
				draw_line(c + cn_d * (r * 0.62), c + cn_d * r, line_color, maxf(line_w * 0.6, 1.2), true)
		"hand":  # R159 (Chantier 3) : main ouverte — paume arrondie + 4 doigts a bouts ronds (longueurs variees) + pouce ecarte
			draw_arc(c + Vector2(0.0, r * 0.28), r * 0.6, deg_to_rad(8), deg_to_rad(172), 24, line_color, line_w, true)  # paume (base ronde)
			draw_line(c + Vector2(-r * 0.6, r * 0.32), c + Vector2(-r * 0.5, -r * 0.02), line_color, line_w, true)   # cote gauche paume
			draw_line(c + Vector2(r * 0.6, r * 0.32), c + Vector2(r * 0.5, -r * 0.05), line_color, line_w, true)     # cote droit
			var hd_x: Array = [-r * 0.42, -r * 0.14, r * 0.14, r * 0.42]
			var hd_top: Array = [-r * 0.64, -r * 0.98, -r * 0.9, -r * 0.66]  # majeur le plus long (proportions de main)
			for hd_i in 4:
				var hd_ft: Vector2 = c + Vector2(hd_x[hd_i] * 1.08, hd_top[hd_i])
				draw_line(c + Vector2(hd_x[hd_i], -r * 0.02), hd_ft, line_color, line_w, true)
				draw_circle(hd_ft, maxf(line_w * 0.7, 1.3), line_color)  # bout de doigt arrondi
			var hd_tt: Vector2 = c + Vector2(-r * 0.95, -r * 0.12)
			draw_line(c + Vector2(-r * 0.52, r * 0.28), hd_tt, line_color, line_w, true)  # pouce ecarte
			draw_circle(hd_tt, maxf(line_w * 0.7, 1.3), line_color)
		"magie":  # R159 (Chantier 3, revue design) : BAGUETTE druidique (tige + anneau au manche) qui
			# lance une etincelle PLEINE a la pointe, + 2 petits eclats. La tige ANCRE « magie gravee »
			# (distinct d'une simple etincelle flottante, cf. icones IA generiques). Silhouette lisible.
			var mg_handle: Vector2 = c + Vector2(-r * 0.72, r * 0.92)
			var mg_tip: Vector2 = c + Vector2(r * 0.3, -r * 0.34)
			draw_line(mg_handle, mg_tip, line_color, line_w * 1.25, true)           # tige de baguette
			draw_arc(mg_handle, r * 0.15, 0.0, TAU, 16, line_color, line_w, true)    # anneau grave au manche (celtique)
			draw_colored_polygon(_sparkle_poly(mg_tip, r * 0.8, r * 0.22), line_color)               # grande etincelle a la pointe
			draw_colored_polygon(_sparkle_poly(c + Vector2(-r * 0.16, -r * 0.52), r * 0.26, r * 0.08), line_color)  # petit eclat
			draw_colored_polygon(_sparkle_poly(c + Vector2(-r * 0.46, r * 0.1), r * 0.19, r * 0.06), line_color)    # petit eclat
		_:
			draw_arc(c, r, 0.0, TAU, 48, line_color, line_w, true)


# R159 (Chantier 3) : etoile-etincelle 4 branches CONCAVE (pleine) — sommets N/E/S/O a `outer`, creux
# aux diagonales a `inner`. Sert le glyphe « magie » (sortilege). PackedVector2Array pour draw_colored_polygon.
func _sparkle_poly(ctr: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 8:
		var a: float = float(k) / 8.0 * TAU - PI / 2.0
		var rr: float = outer if k % 2 == 0 else inner
		pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts
