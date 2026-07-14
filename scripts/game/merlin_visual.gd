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

# ── Vague D (D3) - VOIX DE MERLIN : registre BLEUTÉ distinct du récit de scène (crème/INK) et des
# jauges. Le guide/narrateur qui s'adresse au Voyageur parle en bleu, dans un cartouche bleu-nuit.
# Calibré sur EYE_NEUTRAL / RARE_BLUE mais ÉCLAIRCI pour rester LISIBLE (pilier §23) sur fond sombre. ──
const MERLIN_BLUE: Color = Color("A6CFF0")         # texte de la voix de Merlin (clair, fort contraste sur bleu-nuit)
const MERLIN_SPEECH_BG: Color = Color(0.08, 0.11, 0.17, 0.94)  # cartouche bleu-nuit (récit reste crème)
const MERLIN_SPEECH_BORDER: Color = Color("5F8FBE") # liseré bleuté (≠ liseré or du récit)
const MERLIN_FONT_PATH: String = "res://resources/fonts/morris/MorrisRomanBlack.ttf"  # serif roman élégant + lisible

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

# ── Halo binaire du jet d20 (v2-W4) — réussi/raté du geste, PAS le degré fin (§K success). Charte
# gravure : vert SOURD de mousse (jamais fluo), rouge SOURD de braise (jamais alarme vive). Distincts
# des DEGREE_* (couleurs de fusion vives, saturées) : le halo est un liseré/glow feutré autour du dé. ──
const HALO_SUCCESS: Color = Color("6E9450")  # vert mousse sourd (réussite du jet)
const HALO_FAIL: Color = Color("A5453A")     # rouge braise sourd (échec du jet)

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
const DUR_BREATHE: float = 3.0     # demi-période de respiration (titre, prose)
const DUR_IMPACT_FREEZE: float = 0.08
const DUR_FLASH: float = 0.12
const DUR_INK_WIPE: float = 1.0    # transition plus lente/posée (user 2026-06-29) — couvre + révèle ~2s
const DUR_MOTE_FADE: float = 0.30
const DUR_WORLD_REACT: float = 1.50
const MOTE_COUNT_AMBIENT: int = 18
const SPARK_COUNT_IMPACT: int = 8
const DUR_SEAL_FADE: float = 0.15
const DUR_CARET_BLINK: float = 0.60
const DUR_GAUGE_ANIM: float = 0.30
const DUR_RING_BURST: float = 0.45
const DUR_PANEL_OPEN: float = 0.25
const DUR_FLOAT_LABEL: float = 0.60
const DUR_ENCART_TINT: float = 0.25
const DUR_ZONE_FADE: float = 0.22  # v11-V2a (spec écran stable) : cross-fade du CONTENU d'une zone fixe

# ── Reduce-motion (BIBLE §23 R118 / R74) : atténue, ne supprime JAMAIS l'information ──
const PREFS_PATH: String = "user://options.cfg"
static var reduced_motion: bool = false

# ── v11-V2b (spec §tuto) — micro-tuto : 2 hints one-shot (labels passifs Z4), persistés [tuto] ──
static var tuto_hint_a_done: bool = false  # hint A (beat 1) : « verbe + manière, puis Résous »
static var tuto_hint_b_done: bool = false  # hint B (beat 2) : « tuiles soulignées d'or »

# ── P3 (CDC-UX-06) — PACK LECTURE : vitesse du typewriter + taille du récit, persistés [reading].
# Indépendants de reduce-motion (CDC-DA-17/UX-06 : confort de lecture ≠ accessibilité vestibulaire).
# Défauts = comportement HISTORIQUE (Normal = 30 c/s, Standard = FS_NARRATIVE) → soak/autoplay ISO.
const TW_LENT: int = 0
const TW_NORMAL: int = 1
const TW_RAPIDE: int = 2
const TW_INSTANT: int = 3
const TW_LABELS: Array = ["Lent", "Normal", "Rapide", "Instantané"]
const TW_CPS: Array = [16.0, 30.0, 60.0]   # caractères/seconde par palier (index INSTANT = pas d'anim)
const TEXT_STANDARD: int = 0
const TEXT_CONFORT: int = 1
const TEXT_LABELS: Array = ["Standard", "Confort"]
const TEXT_FS: Array = [FS_NARRATIVE, 44]  # tailles de police du récit (Z3) — au moins 2 crans
static var typewriter_speed: int = TW_NORMAL  # 0 Lent · 1 Normal · 2 Rapide · 3 Instantané
static var text_scale: int = TEXT_STANDARD    # 0 Standard · 1 Confort


# Facteur de durée global : reduce-motion = durées ÷2 (amplitudes ÷2 côté appelant).
static func motion() -> float:
	return 0.5 if reduced_motion else 1.0


# P3 (chantier 2) — « Instantané » : le récit se révèle d'un coup (aucune animation de frappe).
static func typewriter_instant() -> bool:
	return typewriter_speed == TW_INSTANT


# P3 (chantier 2) — vitesse de frappe (caractères/seconde) du palier courant. Bornée pour rester
# valide même si une pref corrompue sort de l'intervalle (clamp) ; Instantané n'appelle jamais ceci.
static func typewriter_cps() -> float:
	var i: int = clampi(typewriter_speed, TW_LENT, TW_RAPIDE)
	return float(TW_CPS[i])


# P3 (chantier 2) — taille de police du récit selon le cran de lecture (Standard/Confort).
static func narrative_font_size() -> int:
	var i: int = clampi(text_scale, TEXT_STANDARD, TEXT_CONFORT)
	return int(TEXT_FS[i])


# v1.0-V4b (#52) — Garde de dégénérescence AVANT tout draw_colored_polygon / polygon= GÉNÉRÉ
# (boucles sin/randf) : la triangulation Godot échoue (« Invalid polygon data, triangulation
# failed ») si le polygone a <3 points uniques ou une aire quasi-nulle (points dupliqués /
# colinéaires). Ne détecte PAS l'auto-intersection : les générateurs doivent la rendre
# impossible par construction (amplitudes bornées — cf. merlin_scene_art.gd v10.22).
static func polygon_drawable(pts: PackedVector2Array) -> bool:
	if pts.size() < 3:
		return false
	var uniq: int = 1
	var area2: float = 0.0  # aire signée ×2 (shoelace)
	var prev: Vector2 = pts[pts.size() - 1]
	for i in pts.size():
		var p: Vector2 = pts[i]
		area2 += prev.x * p.y - p.x * prev.y
		if i > 0 and not p.is_equal_approx(pts[i - 1]):
			uniq += 1
		prev = p
	return uniq >= 3 and absf(area2) > 1.0  # aire réelle > 0.5 px²


static func load_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		reduced_motion = bool(cfg.get_value("a11y", "reduced_motion", false))
		tuto_hint_a_done = bool(cfg.get_value("tuto", "hint_a_done", false))
		tuto_hint_b_done = bool(cfg.get_value("tuto", "hint_b_done", false))
		# P3 (chantier 2) — pack lecture (défauts = comportement historique si la section manque).
		typewriter_speed = clampi(int(cfg.get_value("reading", "typewriter_speed", TW_NORMAL)), TW_LENT, TW_INSTANT)
		text_scale = clampi(int(cfg.get_value("reading", "text_scale", TEXT_STANDARD)), TEXT_STANDARD, TEXT_CONFORT)


static func save_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)  # préserve d'éventuelles autres clés
	cfg.set_value("a11y", "reduced_motion", reduced_motion)
	cfg.set_value("tuto", "hint_a_done", tuto_hint_a_done)
	cfg.set_value("tuto", "hint_b_done", tuto_hint_b_done)
	cfg.set_value("reading", "typewriter_speed", typewriter_speed)  # P3 (chantier 2)
	cfg.set_value("reading", "text_scale", text_scale)
	cfg.save(PREFS_PATH)


# ── v11-V2a (spec écran stable) — grammaire des ZONES : chaque zone existe 100 % du temps ;
# seul son CONTENU change (cross-fade), son interactivité s'éteint par mouse_filter, jamais par visible. ──

# Swap du contenu d'une zone : fade-out 0.18 s → build.call() (repose le contenu) → fade-in
# DUR_ZONE_FADE. reduced_motion : swap sec, alpha restitué à 1 (l'information ne s'efface jamais).
# Tween LIÉ à la zone (jamais orphelin) ; un swap relancé tue le précédent (meta).
static func swap_zone(zone: Control, build: Callable) -> void:
	if zone == null or not is_instance_valid(zone) or not zone.is_inside_tree():
		if build.is_valid():
			build.call()  # zone absente → au moins poser le contenu (jamais de beat perdu)
		return
	if reduced_motion:
		build.call()
		zone.modulate.a = 1.0
		return
	# R159 (fix softlock, classe R148) : un swap relance TUE le tween precedent AVANT que son
	# tween_callback(build) n'ait pu s'executer si le relance survient dans la fenetre de fade-out
	# (0.18 s). Or ce `build` repose le contenu ET pose l'ETAT CRITIQUE du beat (_beat_transition=false,
	# _state=1). Un build perdu => l'encart reste fige, le choix ne s'ouvre JAMAIS (« le jeu se bloque »).
	# Correctif : on suit le build EN ATTENTE en meta et on le JOUE avant de le remplacer (exactement-une-fois :
	# soit le tween_callback le joue et efface le flag, soit ce kill-handler le joue et efface le flag).
	if zone.has_meta("_fx_tw_swap"):
		var prev: Tween = zone.get_meta("_fx_tw_swap")
		if prev != null and prev.is_valid():
			prev.kill()
		if zone.has_meta("_fx_swap_build_pending"):
			var pend: Callable = zone.get_meta("_fx_swap_build_pending")
			zone.remove_meta("_fx_swap_build_pending")
			if pend.is_valid():
				pend.call()  # build precedent JAMAIS perdu (etat critique du beat preserve)
	var t: Tween = zone.create_tween()
	t.tween_property(zone, "modulate:a", 0.0, 0.18 * motion()).set_trans(Tween.TRANS_SINE)
	zone.set_meta("_fx_swap_build_pending", build)
	t.tween_callback(func() -> void:
		if zone != null and is_instance_valid(zone) and zone.has_meta("_fx_swap_build_pending"):
			zone.remove_meta("_fx_swap_build_pending")
		if build.is_valid():
			build.call())
	t.tween_property(zone, "modulate:a", 1.0, DUR_ZONE_FADE * motion()).set_trans(Tween.TRANS_SINE)
	zone.set_meta("_fx_tw_swap", t)


# Active/estompe une zone : modulate 1.0 / 0.35 + souris ON/OFF récursif. Les mouse_filter
# d'origine sont mémorisés en meta puis RESTAURÉS — les IGNORE permanents des éléments
# décoratifs ne sont jamais écrasés (on ne stocke que les nodes réellement interactifs).
static func set_zone_active(zone: Control, on: bool) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	var target: float = 1.0 if on else 0.35
	if zone.has_meta("_fx_tw_zone"):
		var prev: Tween = zone.get_meta("_fx_tw_zone")
		if prev != null and prev.is_valid():
			prev.kill()
	if zone.is_inside_tree():
		var t: Tween = zone.create_tween()
		t.tween_property(zone, "modulate:a", target, DUR_ZONE_FADE * motion()).set_trans(Tween.TRANS_SINE)
		zone.set_meta("_fx_tw_zone", t)
	else:
		zone.modulate.a = target  # hors arbre : pas de tween possible, l'état reste juste
	_set_zone_mouse(zone, on)


# Récursif : OFF → mouse_filter d'origine mémorisé (meta) puis IGNORE ; ON → restauration.
# Les nodes déjà IGNORE ne sont ni stockés ni modifiés. Idempotent (double OFF sans risque).
static func _set_zone_mouse(node: Node, on: bool) -> void:
	if node is Control:
		var c: Control = node
		if on:
			if c.has_meta("_zone_mf"):
				c.mouse_filter = int(c.get_meta("_zone_mf"))
				c.remove_meta("_zone_mf")
		elif c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not c.has_meta("_zone_mf"):
			c.set_meta("_zone_mf", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in node.get_children():
		_set_zone_mouse(ch, on)


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


# Vague D (D3) - Cartouche de la VOIX DE MERLIN : fond bleu-nuit + liseré bleuté, même géométrie que
# cream_style (respiration identique) mais registre DISTINCT du récit de scène (crème). N'habille QUE
# la parole de Merlin (guide, proposition, cadrage d'intro) ; jamais le récit du monde ni les piliers.
static func merlin_speech_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = MERLIN_SPEECH_BG
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = MERLIN_SPEECH_BORDER
	sb.set_content_margin_all(18)
	return sb


# Vague D (D3) - Fonte distincte de la voix de Merlin (serif roman élégant, lisible). Chargée à la
# demande et mise en cache. Renvoie null si la ressource manque : l'appelant garde alors la fonte de
# thème (teinte + cartouche bleutés suffisent à distinguer la voix). Jamais appelée par les probes/soak.
static var _merlin_font: FontFile = null
static func merlin_speech_font() -> FontFile:
	if _merlin_font == null and ResourceLoader.exists(MERLIN_FONT_PATH):
		var res: Resource = load(MERLIN_FONT_PATH)
		if res is FontFile:
			_merlin_font = res
	return _merlin_font


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
