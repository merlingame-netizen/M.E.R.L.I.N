class_name MerlinVisual
extends RefCounted
## v10.13 (A1) — SOURCE DE VÉRITÉ visuelle : palette DA flat rétro-minimaliste (verrouillée
## 2026-05-26, R70 BIBLE.md) + factories de styles partagées. Classe STATIQUE volontairement
## (pas un autoload) : zéro ordre d'init, zéro get_node, utilisable depuis les probes hors-arbre.
## Convention : les écrans/components gardent leurs noms locaux (COL_GOLD…) mais ALIASÉS ici
## (`const COL_GOLD: Color = MerlinVisual.GOLD`) — un rebranding = UNE édition.

# ── Palette canonique (relevée hex par hex sur les 10 scripts, 2026-06-10) ──
const BG_PAGE: Color = Color("1E1A14")    # fond de page (game, menu)
const BG_DEEP: Color = Color("14100C")    # fond profond (end, options, selection, console)
const SURFACE: Color = Color("2A2018")    # panneaux sombres (== INK : même hex, sémantique distincte)
const INK: Color = Color("2A2018")        # trait / texte foncé sur crème
const CREAM: Color = Color("E8DCC0")      # parchemin / texte clair / lune / fond carte
const GOLD: Color = Color("C9A24B")       # accent or
const GOLD_DARK: Color = Color("8A6A2E")  # or sombre (degré réussite, captions discrètes)
const GREEN: Color = Color("7FA65C")      # vie / positif
const GREEN_DARK: Color = Color("4F6B3E") # vert sombre (éclatante, console)
const VIOLET: Color = Color("7B4FA3")     # corruption / échec
const DIM_WARM: Color = Color("9C8C6A")   # texte secondaire CLAIR (sur fonds sombres)
const INK_DIM: Color = Color("6E5A3C")    # texte secondaire FONCÉ (sur crème) — ≠ DIM_WARM !
const PANEL: Color = Color("241E16")      # surface de panneau (beat map)
const BORDER_BRUN: Color = Color("4A3B28")# liseré brun (panneau / carte Commune)
const RING_BG: Color = Color("3A3228")    # fond d'anneau de jauge / nœud futur de la map
const RARE_BLUE: Color = Color("5A7A8C")  # bleu-acier (rareté Rare / déviation map)

# ── Tailles de police canoniques ──
const FS_NARRATIVE: int = 36
const FS_TITLE_POPUP: int = 40
const FS_BTN: int = 26
const FS_CAPTION: int = 22
const FS_HINT: int = 20


# Couleur de degré — LISIBLE sur la bande crème (source : merlin_game._degree_color).
static func degree_color(degree: String) -> Color:
	match degree:
		"echec": return VIOLET
		"partiel": return INK_DIM
		"eclatante": return GREEN_DARK
		_: return GOLD_DARK  # réussite


# Panneau sombre standard (source : merlin_game._surface_style).
static func surface_style(radius: int = 6, margin: int = 16) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


# Encart crème à liseré or (source : merlin_game._cream_style).
static func cream_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.set_content_margin_all(18)
	return sb


# Label typé couleur+taille (source : merlin_game._mk_label).
static func make_label(col: Color, fsize: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", fsize)
	return l
