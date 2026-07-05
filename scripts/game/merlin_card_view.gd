class_name MerlinCardView
extends Control
## Vue de carte — DA flat rétro-minimaliste. v10.5 (user 2026-06-06) : cartes plus grandes, glyphe
## par TAG précis (logo reflète le concept), bordure ÉPAISSE colorée par RARETÉ (Commune/Rare/Épique/
## Mythique), bande d'ARCHÉTYPE d'effet en bas (Offensif/Défensif/Social/Mystique/Corrompu).
## S'agrandit/se soulève au survol. Émet card_clicked au clic.

signal card_clicked(card: MerlinCard)

const CARD_SIZE: Vector2 = Vector2(150, 190)          # v11-W2 : mode TRAIT (spec §I — éventail de 4)
const CARD_SIZE_COMPACT: Vector2 = Vector2(170, 104)  # legacy (l'ancienne zone de combinaison)
const HOVER_SCALE: float = 1.18
const HOVER_LIFT: float = 30.0
const SELECT_LIFT: float = 20.0                       # v11-W2 : trait sélectionné = levée +20 px + bordure GOLD
const COMPACT_HOVER_SCALE: float = 1.06
# v10.24 (user : « animations de cartes cohérentes et travaillées ») — CHARTE DE MOUVEMENT unique :
#   ARRIVÉES  (deal, pop)   = TRANS_BACK  EASE_OUT (un seul overshoot franc, jamais de double-élastique)
#   SORTIES   (défausse)    = anticipation brève PUIS chute parabolique TRANS_CUBIC EASE_IN + tumble
#   FEEDBACK  (tap)         = PRESS 0.96 (même langage que les boutons §21) → retour CONTEXTUEL
#   REFLOW/HOVER            = TRANS_CUBIC EASE_OUT, base ANIM — TOUT ×MerlinVisual.motion() via _dur()
const ANIM: float = 0.12  # base hover/reflow (multipliée par motion() via _dur)

# DA flat rétro-minimaliste (décision 2026-05-26).
const COL_CARD: Color = MerlinVisual.CREAM    # crème (fond carte)
const COL_INK: Color = MerlinVisual.INK       # trait / glyphe
const COL_INK_DIM: Color = MerlinVisual.INK_DIM
const COL_GOLD: Color = MerlinVisual.GOLD     # liseré « posée » (rôle)

# v10.5 — Rareté → couleur + épaisseur de bordure (le cadre EST la rareté, lisible d'un coup d'œil).
const RARITY_STYLE: Dictionary = {
	"Commune":  {"col": MerlinVisual.BORDER_BRUN, "w": 3},
	"Rare":     {"col": MerlinVisual.RARE_BLUE, "w": 4},
	"Épique":   {"col": MerlinVisual.RARITY_EPIC, "w": 5},
	"Mythique": {"col": MerlinVisual.GOLD, "w": 7},
}

# v10.5 — Archétype d'effet → couleur de bande + libellé (reflète « ce que fait la carte »).
const ARCHETYPE_STYLE: Dictionary = {
	"Offensif": {"col": MerlinVisual.ARCHETYPE_OFFENSE, "label": "OFFENSE"},
	"Défensif": {"col": MerlinVisual.ARCHETYPE_DEFENSE, "label": "DÉFENSE"},
	"Social":   {"col": MerlinVisual.ARCHETYPE_SPEECH, "label": "PAROLE"},
	"Mystique": {"col": MerlinVisual.ARCHETYPE_MYSTERY, "label": "MYSTÈRE"},
	"Corrompu": {"col": MerlinVisual.ARCHETYPE_CORRUPT, "label": "CORRUPTION"},
}

# v10.11 — Effet actif (Rare+) → couleur + icône du badge (coin haut-droit) : « coût/effet en un coup d'œil » (StS).
const EFFECT_STYLE: Dictionary = {
	"HEAL":  {"col": MerlinVisual.EFFECT_HEAL, "icon": "♥"},
	"PURGE": {"col": MerlinVisual.EFFECT_PURGE, "icon": "✦"},
	"DRAW":  {"col": MerlinVisual.EFFECT_DRAW, "icon": "✚"},
}

var card: MerlinCard
var _compact: bool = false
var _base_pos: Vector2 = Vector2.ZERO
var _base_rot: float = 0.0
var _base_z: int = 0
var _hovering: bool = false
var _tw: Tween
var _fan_inited: bool = false  # v10.13.1 : 1er layout = snap ; suivants = reflow animé (§21 `fast`)
var _discarding: bool = false  # v10.13.1 : en sortie discard_out → exclue du reuse (review HIGH-2)
var _sway_phase: float = 0.0
var _sway_active: bool = false
var _t: float = 0.0
var _rarity_rank: int = 0
var _panel_sb: StyleBoxFlat
var _glow_col: Color = MerlinVisual.GOLD
# v11-W2 — sélection SUR l'élément (le combo panel est supprimé) : bordure GOLD + levée +20 px,
# désélection au re-clic. Style de repos mémorisé pour restaurer la bordure de rareté.
var _selected: bool = false
var _rest_border_col: Color = MerlinVisual.BORDER_BRUN
var _rest_border_w: int = 3


func _dur(base: float) -> float:
	return base * MerlinVisual.motion()


func setup(c: MerlinCard, role: String = "", compact: bool = false) -> void:
	card = c
	_compact = compact
	var sz: Vector2 = CARD_SIZE_COMPACT if compact else CARD_SIZE
	custom_minimum_size = sz
	size = sz
	pivot_offset = sz / 2.0  # scale/rotation autour du centre
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_gui_input)
	_build(role)


func _build(role: String) -> void:
	var rar: String = card.rarity if card.rarity != "" else "Commune"
	var rstyle: Dictionary = RARITY_STYLE.get(rar, RARITY_STYLE["Commune"])

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(int(rstyle["w"]))
	sb.border_color = COL_GOLD if role != "" else (rstyle["col"] as Color)
	_rest_border_col = sb.border_color  # v11-W2 : restauré à la désélection
	_rest_border_w = int(rstyle["w"])
	_rarity_rank = ["Commune", "Rare", "Épique", "Mythique"].find(rar)
	if _rarity_rank < 0:
		_rarity_rank = 0
	_glow_col = COL_GOLD if rar == "Mythique" else (rstyle["col"] as Color)
	if _rarity_rank >= 1:
		sb.shadow_color = Color(_glow_col.r, _glow_col.g, _glow_col.b, 0.0)
		sb.shadow_size = 6 + _rarity_rank * 2
	_panel_sb = sb
	sb.set_content_margin_all(7 if _compact else 9)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3 if _compact else 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# Nom (main) ou rôle (compact legacy). v11-W2 : nom ≥16 px (spec §I, carte-trait 150×190).
	var top: Label = Label.new()
	top.text = role if _compact else card.card_name
	top.add_theme_color_override("font_color", COL_INK_DIM if _compact else COL_INK)
	top.add_theme_font_size_override("font_size", 11 if _compact else 16)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)

	# Glyphe HÉROS — par TAG précis (v10.5 : le logo reflète le concept exact, plus la famille).
	var primary: String = str(card.tags[0]) if card.tags.size() > 0 else ""
	var glyph: MerlinGlyph = MerlinGlyph.new()
	glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glyph.setup(MerlinGlyph.for_tag(primary), COL_INK, 2.4 if _compact else 3.2)
	v.add_child(glyph)

	# v10.12 — Tags EN CLAIR (mots) = « ce que tu joues » : les forces apportées à la combinaison
	# (elles déterminent la couverture/résolution). Remplace la rangée de pastilles + la bande archétype
	# (surcharge, user 2026-06-07). 2 tags max affichés. Coût + effet portés par les gemmes de coin.
	if not _compact and card.tags.size() > 0:
		var tag_row: HBoxContainer = HBoxContainer.new()
		tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
		tag_row.add_theme_constant_override("separation", 6)
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tag_row)
		var shown: int = 0
		for t in card.tags:
			if shown >= 2:
				break
			var chip: PanelContainer = PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var csb: StyleBoxFlat = StyleBoxFlat.new()
			csb.bg_color = Color(0.16, 0.12, 0.08, 0.30)  # encre transparente (lisibilité sans bordure)
			csb.set_corner_radius_all(3)
			csb.content_margin_left = 6.0
			csb.content_margin_right = 6.0
			csb.content_margin_top = 1.0
			csb.content_margin_bottom = 1.0
			chip.add_theme_stylebox_override("panel", csb)
			var clbl: Label = Label.new()
			clbl.text = str(t).to_upper()
			clbl.add_theme_color_override("font_color", Color(MerlinTags.color_of(str(t))))
			clbl.add_theme_font_size_override("font_size", 11)
			clbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(clbl)
			tag_row.add_child(chip)
			shown += 1

	# v10.11 — Gemme rareté/coût (coin haut-gauche) + badge d'effet (coin haut-droit). DA flat conservée.
	_add_corner_markers(rar, rstyle)


# v11-W2 — position de REPOS : la sélection lève la carte de 20 px (l'état se lit sur l'élément).
func _rest_pos() -> Vector2:
	return _base_pos + (Vector2(0.0, -SELECT_LIFT) if _selected else Vector2.ZERO)


# v11-W2 — sélection du TRAIT sur l'élément : bordure GOLD + levée +20 px ; désélection au re-clic
# (gérée par merlin_game._on_trait_card). Ne combat jamais le hover (retour via _on_exit).
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	if _panel_sb != null:
		_panel_sb.border_color = COL_GOLD if on else _rest_border_col
		_panel_sb.set_border_width_all(maxi(_rest_border_w, 4) if on else _rest_border_w)
	if not _hovering and not _discarding and _fan_inited:
		_animate(_rest_pos(), _base_rot, 1.0)


# v10.21 (Wave I, R131) — badge de BÉNÉDICTION : pastille GOLD portant le tag temporaire offert par le
# pilier (zéro info cachée, pilier ÉVIDENT). Posée par merlin_game._render_hand quand la carte est bénie.
func set_blessed(tag: String) -> void:
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb2: StyleBoxFlat = StyleBoxFlat.new()
	sb2.bg_color = MerlinVisual.GOLD
	sb2.set_corner_radius_all(8)
	sb2.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", sb2)
	var lbl2: Label = Label.new()
	lbl2.text = "✦ " + tag
	lbl2.add_theme_color_override("font_color", MerlinVisual.INK)
	lbl2.add_theme_font_size_override("font_size", 12)
	lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl2)
	var sz2: Vector2 = CARD_SIZE_COMPACT if _compact else CARD_SIZE
	badge.position = Vector2(sz2.x * 0.5 - 34.0, -10.0)  # à cheval sur le bord haut (visible dans l'éventail)
	add_child(badge)


# v2-W2 — badge NŒUD DE TALENT : pastille GOLD « ✦ +N TALENT » à cheval sur le bord haut de la carte
# de draft (distinction du nœud de talent des greffes d'action — zéro info cachée, pilier ÉVIDENT).
# Rendu comme set_blessed (même grammaire), texte distinct. Appelé par merlin_game au build du draft.
func set_talent_node(amount: int) -> void:
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb2: StyleBoxFlat = StyleBoxFlat.new()
	sb2.bg_color = MerlinVisual.GOLD
	sb2.set_corner_radius_all(8)
	sb2.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", sb2)
	var lbl2: Label = Label.new()
	lbl2.text = "✦ +%d TALENT" % maxi(amount, 1)
	lbl2.add_theme_color_override("font_color", MerlinVisual.INK)
	lbl2.add_theme_font_size_override("font_size", 12)
	lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl2)
	var sz2: Vector2 = CARD_SIZE_COMPACT if _compact else CARD_SIZE
	badge.position = Vector2(sz2.x * 0.5 - 44.0, -10.0)  # centré sur le bord haut
	add_child(badge)


# Marqueurs de coin (overlay absolu sur self, hors flux du VBox) : gemme rareté/coût + badge d'effet.
func _add_corner_markers(rar: String, rstyle: Dictionary) -> void:
	var sz: Vector2 = CARD_SIZE_COMPACT if _compact else CARD_SIZE
	# v10.21 (L-c) — pastille de coût plus FRANCHE : lisible dans l'éventail SANS hover (28px, fonte 16).
	var gsz: float = 20.0 if _compact else 28.0
	# Gemme (coin haut-gauche) : couleur = rareté ; chiffre = coût Corruption si > 0.
	var gem: Panel = Panel.new()
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.position = Vector2(4, 4)
	gem.size = Vector2(gsz, gsz)
	var gsb: StyleBoxFlat = StyleBoxFlat.new()
	gsb.bg_color = (rstyle["col"] as Color)
	gsb.set_corner_radius_all(int(gsz / 2.0))
	gsb.set_border_width_all(2)
	gsb.border_color = COL_CARD
	gem.add_theme_stylebox_override("panel", gsb)
	add_child(gem)
	if card.corruption > 0:
		var gl: Label = Label.new()
		gl.text = str(card.corruption)
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.add_theme_color_override("font_color", COL_CARD)
		gl.add_theme_font_size_override("font_size", 13 if _compact else 16)  # v10.21 (L-c) : coût lisible de loin
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_child(gl)
	# Badge d'effet (coin haut-droit) — masqué en compact (zone de combinaison étroite).
	if not _compact and str(card.effect_type) != "" and EFFECT_STYLE.has(card.effect_type):
		var est: Dictionary = EFFECT_STYLE[card.effect_type]
		var bw: float = 58.0  # v10.21 (L-c) : badge d'effet plus franc (58×25, fonte 15)
		var badge: Panel = Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(sz.x - bw - 4.0, 4.0)
		badge.size = Vector2(bw, 25.0)
		var bsb: StyleBoxFlat = StyleBoxFlat.new()
		bsb.bg_color = (est["col"] as Color)
		bsb.set_corner_radius_all(6)
		badge.add_theme_stylebox_override("panel", bsb)
		add_child(badge)
		var bl: Label = Label.new()
		bl.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sign: String = "−" if str(card.effect_type) == "PURGE" else "+"
		bl.text = "%s%s%d" % [str(est["icon"]), sign, int(card.effect_value)]
		bl.add_theme_color_override("font_color", COL_CARD)
		bl.add_theme_font_size_override("font_size", 15)  # v10.21 (L-c)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(bl)


func _wants_process() -> bool:
	if _rarity_rank >= 1:
		return true
	if _hovering and not _compact:
		return true
	return _sway_active and not MerlinVisual.reduced_motion


func _process(delta: float) -> void:
	_t += delta
	if _rarity_rank >= 1 and _panel_sb != null:
		var ga: float = [0.0, 0.20, 0.30, 0.50][_rarity_rank]
		var gamp: float = [0.0, 0.10, 0.15, 0.20][_rarity_rank]
		if MerlinVisual.reduced_motion:
			gamp = 0.0
		var gspd: float = [0.0, 0.8, 1.0, 1.3][_rarity_rank]
		_panel_sb.shadow_color = Color(_glow_col.r, _glow_col.g, _glow_col.b,
			ga + gamp * sin(_t * gspd + _sway_phase))
	if _hovering and not _compact:
		if not MerlinVisual.reduced_motion:
			var center: Vector2 = global_position + pivot_offset
			var mouse: Vector2 = get_global_mouse_position()
			var dx: float = clampf((mouse.x - center.x) / (size.x * 0.5), -1.0, 1.0)
			rotation = lerpf(rotation, dx * deg_to_rad(3.0), 0.15)
		return
	if not _sway_active or _discarding:
		return
	_sway_phase += delta
	if MerlinVisual.reduced_motion:
		return
	var w: float = sin(_sway_phase * 1.3) * 0.7 + sin(_sway_phase * 2.7 + 1.4) * 0.4 + sin(_sway_phase * 0.4) * 0.2
	rotation = _base_rot + deg_to_rad(w)
	position = _rest_pos() + Vector2(sin(_sway_phase * 0.35) * 1.0, sin(_sway_phase * 0.9 + 0.7) * 2.8)


## Position/rotation de base dans l'éventail (posées par le conteneur). Appliquées si pas survolé.
## v10.13.1 (§21 `fast`) : reflow ANIMÉ quand la carte a déjà été layoutée (l'éventail glisse
## vers sa nouvelle place au lieu de snapper). 1er layout / deal en attente = snap (deal_in anime).
func set_fan_transform(pos: Vector2, rot: float, animate_reflow: bool = true) -> void:
	var first: bool = not _fan_inited
	_fan_inited = true
	_base_pos = pos
	_base_rot = rot
	_base_z = z_index  # ordre de recouvrement de l'éventail (posé par le conteneur avant cet appel)
	if _hovering:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var target: Vector2 = _rest_pos()  # v11-W2 : la sélection lève la position de repos de 20 px
	if first or not animate_reflow or not is_inside_tree():
		position = target
		rotation = rot
		scale = Vector2.ONE
		modulate.a = 1.0  # garantit l'opacité si un deal_in (tween a:0→1) est interrompu par un re-layout (fix cartes invisibles, user 2026-06-06)
		_sway_active = not _compact
		_sway_phase = rot * 3.0
		set_process(_wants_process())
		return
	scale = Vector2.ONE
	modulate.a = 1.0
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var d: float = MerlinVisual.DUR_FAST * MerlinVisual.motion()
	_tw.tween_property(self, "position", target, d)
	_tw.tween_property(self, "rotation", rot, d)
	_tw.chain().tween_callback(func() -> void:
		_sway_active = not _compact
		_sway_phase = rot * 3.0
		set_process(_wants_process())
	)


func _on_enter() -> void:
	_hovering = true
	_sway_active = false
	z_index = 50
	if _compact:
		set_process(_rarity_rank >= 1)
		_scale_to(COMPACT_HOVER_SCALE)
	else:
		set_process(true)
		_animate(_base_pos + Vector2(0, -HOVER_LIFT), 0.0, HOVER_SCALE)


func _on_exit() -> void:
	_hovering = false
	z_index = _base_z
	if _compact:
		_scale_to(1.0)
		set_process(_rarity_rank >= 1)
	else:
		_animate(_rest_pos(), _base_rot, 1.0)  # v11-W2 : retour à la position de repos (levée si sélectionnée)
		if not _discarding:
			_sway_active = not _compact
			set_process(_wants_process())


func _scale_to(scl: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(scl, scl), _dur(ANIM))


func deal_in(delay: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_sway_active = false
	set_process(_rarity_rank >= 1)
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	# ARC d'entrée : la carte vole vers sa place depuis le bas, décalée du CÔTÉ de son inclinaison
	# d'éventail (trajectoire courbe crédible, plus une montée verticale mécanique).
	position = _base_pos + Vector2(-_base_rot * 220.0, 140.0)
	rotation = _base_rot + deg_to_rad((randf() - 0.5) * 16.0)
	MerlinAudio.play_sfx("deal", randf_range(0.95, 1.05))
	var d: float = MerlinVisual.DUR_DEAL * MerlinVisual.motion() * 1.3
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, _dur(0.18)).set_delay(delay)
	# Charte ARRIVÉE : BACK out unique (un overshoot franc) — fini le double-élastique caoutchouteux.
	_tw.tween_property(self, "position", _base_pos, d).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE, d * 0.85).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "rotation", _base_rot, d * 0.7).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_callback(func() -> void:
		_sway_active = not _compact
		_sway_phase = _base_rot * 3.0
		set_process(_wants_process())
	)


func discard_out() -> void:
	MerlinAudio.play_sfx("card_discard")
	_discarding = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = MerlinVisual.DUR_DISCARD * MerlinVisual.motion()
	var dir: float = -1.0 if randf() < 0.7 else 1.0
	# Charte SORTIE : ANTICIPATION brève (la carte se soulève — le regard la suit) PUIS chute
	# PARABOLIQUE (x régulier, y accéléré) avec tumble ample. Plus travaillé qu'une glissade raide.
	_tw = create_tween()
	_tw.tween_property(self, "position:y", position.y - 12.0, _dur(0.07)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.set_parallel(true)
	_tw.tween_property(self, "position:x", position.x + dir * 90.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", position.y + 110.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "rotation", rotation + deg_to_rad(dir * -55.0), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "scale", Vector2(0.5, 0.5), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "modulate:a", 0.0, d * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(queue_free)


## Pose dans la combinaison : apparition pop (échelle + fondu). `delay` permet d'attendre
## l'arrivée du ghost de vol (§21 `ui`) — la carte compacte POP quand le ghost se pose.
func pop_in(delay: float = 0.0) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, _dur(0.14)).set_delay(delay)
	_tw.tween_property(self, "scale", Vector2.ONE, _dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)


func _animate(pos: Vector2, rot: float, scl: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = _dur(ANIM)
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", pos, d)
	_tw.tween_property(self, "rotation", rot, d)
	# Le scale d'ENTRÉE en survol a une pointe BACK (la carte « répond ») ; le retour reste CUBIC (calme).
	var st: Tween.TransitionType = Tween.TRANS_BACK if scl > 1.0 else Tween.TRANS_CUBIC
	_tw.tween_property(self, "scale", Vector2(scl, scl), d).set_trans(st)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap_feedback()
		card_clicked.emit(card)


# v10/H3 (audit UX bible §21.1 pilier TACTILE+DESKTOP) — retour visuel <100 ms garanti même sans
# hover (tactile : pas d'événement mouse_entered persistant). Pop d'échelle puis retour à neutre
# (revue 2026-05-31 : sans retour, la carte restait gonflée sur tactile si pas de hover ultérieur).
func _tap_feedback() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	# Charte FEEDBACK : PRESS vers le bas (0.96) — même langage que les boutons (§21), fini le pop
	# vers le haut incohérent. Retour CONTEXTUEL : la carte survolée REVIENT à sa scale de survol
	# (avant : elle retombait à 1.0 sous le curseur — rétraction fantôme).
	var back_scale: float = 1.0
	if _hovering:
		back_scale = COMPACT_HOVER_SCALE if _compact else HOVER_SCALE
	_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(0.96, 0.96) * back_scale, _dur(0.06))
	_tw.tween_property(self, "scale", Vector2(back_scale, back_scale), _dur(0.10))
