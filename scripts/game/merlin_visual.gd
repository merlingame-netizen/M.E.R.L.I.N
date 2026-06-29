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

# ── Yeux de Merlin — humeurs (R124, user 2026-06-29) ──
const EYE_NEUTRAL: Color = Color("5FB8E8")  # bleu BRILLANT (humeur neutre)
const EYE_SURPRISE: Color = Color("F2D24A") # jaune lumineux (surprise / suspicion)
const EYE_ANGRY: Color = Color("E0483A")    # rouge (colère + sourcils froncés)

# ── Rareté (palier Épique) ──
const RARITY_EPIC: Color = Color("9A4FA8")

# ── Archétypes d'effet ──
const ARCHETYPE_OFFENSE: Color = Color("C0533A")
const ARCHETYPE_DEFENSE: Color = Color("4E7A6A")
const ARCHETYPE_SPEECH: Color = Color("B58A3A")
const ARCHETYPE_MYSTERY: Color = Color("6B5A9C")
const ARCHETYPE_CORRUPT: Color = Color("8B4FA3")

# ── Effets actifs ──
const EFFECT_HEAL: Color = Color("5E7A42")
const EFFECT_PURGE: Color = Color("6B4E8A")
const EFFECT_DRAW: Color = Color("3F5A6A")

# ── Degrés de résolution (fusion cinématique) ──
const DEGREE_FAIL: Color = Color("D04848")
const DEGREE_PARTIAL: Color = Color("D8A030")
const DEGREE_SUCCESS: Color = Color("E8C45A")
const DEGREE_BRILLIANT: Color = Color("F4E0A8")

# ── Scène & décor ──
const SCENE_BG: Color = Color("17130D")
const SILHOUETTE: Color = Color("0E0B07")
const MIST: Color = Color(0.79, 0.72, 0.58, 0.16)

# ── Overlays & dim ──
const DIM_MODAL: Color = Color(0.06, 0.05, 0.04, 0.82)
const DIM_LIGHT: Color = Color(0.04, 0.03, 0.02, 0.62)
const DIM_OPTIONS: Color = Color(0.0, 0.0, 0.0, 0.55)
const TOAST_BG: Color = Color(0.10, 0.08, 0.06, 0.94)
const DEBUG_BG: Color = Color(0.06, 0.05, 0.04, 0.90)

# ── Tailles de police canoniques ──
const FS_NARRATIVE: int = 36
const FS_TITLE_POPUP: int = 40
const FS_BTN: int = 26
const FS_CAPTION: int = 22
const FS_HINT: int = 20

# ── Vocabulaire d'animation canon (BIBLE §21, R116) — v10.13.1 ──
const DUR_TAP_DOWN: float = 0.06   # press de bouton (scale 0.97)
const DUR_TAP_UP: float = 0.10     # relâche (retour 1.0)
const DUR_FAST: float = 0.12       # hover carte/bouton, reflow d'éventail
const DUR_UI: float = 0.22         # vol de carte main↔combo (ghost, arc -18px)
const DUR_DEAL: float = 0.28       # distribution (BACK out)
const DUR_DISCARD: float = 0.25    # défausse (slide -40px, rot -6°, fade)
const DUR_VEIL_IN: float = 0.20    # voile de transition de beat (entrée)
const DUR_VEIL_OUT: float = 0.25   # voile (sortie)
const STAGGER: float = 0.05        # décalage par carte dans un groupe
const DUR_SLIDE_UP: float = 0.35   # situation slide-up à chaque beat
const DUR_BREATHE: float = 3.0     # demi-période de respiration (titre, prose)
const DUR_IMPACT_FREEZE: float = 0.08
const DUR_FLASH: float = 0.12
const DUR_INK_WIPE: float = 1.0    # transition plus lente/posée (user 2026-06-29) — couvre + révèle ~2s
const DUR_MOTE_FADE: float = 0.30
const DUR_WORLD_REACT: float = 1.50
const MOTE_COUNT_AMBIENT: int = 18
const SPARK_COUNT_IMPACT: int = 8
const DUR_SEAL_POP: float = 0.30
const DUR_SEAL_FADE: float = 0.15
const DUR_CARET_BLINK: float = 0.60
const DUR_GAUGE_ANIM: float = 0.30
const DUR_RING_BURST: float = 0.45
const DUR_PANEL_OPEN: float = 0.25
const DUR_FLOAT_LABEL: float = 0.60
const DUR_ENCART_TINT: float = 0.25

# ── Reduce-motion (BIBLE §23 R118 / R74) : atténue, ne supprime JAMAIS l'information ──
const PREFS_PATH: String = "user://options.cfg"
static var reduced_motion: bool = false


# Facteur de durée global : reduce-motion = durées ÷2 (amplitudes ÷2 côté appelant).
static func motion() -> float:
	return 0.5 if reduced_motion else 1.0


static func load_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		reduced_motion = bool(cfg.get_value("a11y", "reduced_motion", false))


static func save_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)  # préserve d'éventuelles autres clés
	cfg.set_value("a11y", "reduced_motion", reduced_motion)
	cfg.save(PREFS_PATH)


# Feedback canon de bouton (§21 `tap` + `fast`) : press scale 0.97→1.0, hover modulate 1.06.
# Tweens LIÉS au bouton (btn.create_tween) — jamais orphelins. Idempotent par bouton via meta.
static func connect_button_feedback(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("_fx_feedback"):
		return
	btn.set_meta("_fx_feedback", true)
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2.0)
	btn.button_down.connect(func() -> void:
		_btn_scale(btn, 0.97, DUR_TAP_DOWN)
		var audio: Node = btn.get_node_or_null("/root/MerlinAudio")
		if audio != null:
			audio.play_sfx("button_tap"))
	btn.button_up.connect(func() -> void: _btn_scale(btn, 1.0, DUR_TAP_UP))
	btn.mouse_entered.connect(func() -> void: _btn_tint(btn, Color(1.06, 1.06, 1.06, 1.0)))
	btn.mouse_exited.connect(func() -> void: _btn_tint(btn, Color(1, 1, 1, 1)))


static func _btn_scale(btn: Control, target: float, dur: float) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	if btn.has_meta("_fx_tw_scale"):
		var prev: Tween = btn.get_meta("_fx_tw_scale")
		if prev != null and prev.is_valid():
			prev.kill()
	var t: Tween = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(target, target), dur * motion())
	btn.set_meta("_fx_tw_scale", t)


static func _btn_tint(btn: Control, target: Color) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	if btn.has_meta("_fx_tw_tint"):
		var prev: Tween = btn.get_meta("_fx_tw_tint")
		if prev != null and prev.is_valid():
			prev.kill()
	var t: Tween = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate", target, DUR_FAST * motion())
	btn.set_meta("_fx_tw_tint", t)


# Couleur de degré — LISIBLE sur la bande crème (source : merlin_game._degree_color).
static func degree_color(degree: String) -> Color:
	match degree:
		"echec": return VIOLET
		"partiel": return INK_DIM
		"eclatante": return GREEN_DARK
		_: return GOLD_DARK  # réussite


static func degree_fusion_color(degree: String) -> Color:
	match degree:
		"echec": return DEGREE_FAIL
		"partiel": return DEGREE_PARTIAL
		"eclatante": return DEGREE_BRILLIANT
		_: return DEGREE_SUCCESS


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


# StyleBox bouton DA-conforme (GOLD sur SURFACE, bords arrondis).
static func button_style_normal() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_DARK
	sb.set_content_margin_all(10)
	return sb

static func button_style_hover() -> StyleBoxFlat:
	var sb: StyleBoxFlat = button_style_normal()
	sb.bg_color = Color(SURFACE.r + 0.06, SURFACE.g + 0.05, SURFACE.b + 0.04, 1.0)
	sb.border_color = GOLD
	return sb

static func button_style_pressed() -> StyleBoxFlat:
	var sb: StyleBoxFlat = button_style_normal()
	sb.bg_color = Color(SURFACE.r - 0.03, SURFACE.g - 0.02, SURFACE.b - 0.02, 1.0)
	sb.border_color = GOLD
	return sb

static func apply_button_da(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button_style_normal())
	btn.add_theme_stylebox_override("hover", button_style_hover())
	btn.add_theme_stylebox_override("pressed", button_style_pressed())
	btn.add_theme_stylebox_override("focus", button_style_normal())
	btn.add_theme_color_override("font_color", GOLD)
	btn.add_theme_color_override("font_hover_color", CREAM)
	btn.add_theme_color_override("font_pressed_color", GOLD_DARK)
	btn.add_theme_color_override("font_focus_color", GOLD)
