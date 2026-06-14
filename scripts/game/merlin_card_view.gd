class_name MerlinCardView
extends Control
## Vue de carte — DA flat rétro-minimaliste. v10.5 (user 2026-06-06) : cartes plus grandes, glyphe
## par TAG précis (logo reflète le concept), bordure ÉPAISSE colorée par RARETÉ (Commune/Rare/Épique/
## Mythique), bande d'ARCHÉTYPE d'effet en bas (Offensif/Défensif/Social/Mystique/Corrompu).
## S'agrandit/se soulève au survol. Émet card_clicked au clic.

signal card_clicked(card: MerlinCard)

const CARD_SIZE: Vector2 = Vector2(180, 240)          # v10.5 : + grandes (était 152×196)
const CARD_SIZE_COMPACT: Vector2 = Vector2(170, 104)  # zone de combinaison (était 150×88)
const HOVER_SCALE: float = 1.18
const HOVER_LIFT: float = 30.0
const COMPACT_HOVER_SCALE: float = 1.06
const ANIM: float = 0.12

# DA flat rétro-minimaliste (décision 2026-05-26).
const COL_CARD: Color = MerlinVisual.CREAM    # crème (fond carte)
const COL_INK: Color = MerlinVisual.INK       # trait / glyphe
const COL_INK_DIM: Color = MerlinVisual.INK_DIM
const COL_GOLD: Color = MerlinVisual.GOLD     # liseré « posée » (rôle)

# v10.5 — Rareté → couleur + épaisseur de bordure (le cadre EST la rareté, lisible d'un coup d'œil).
const RARITY_STYLE: Dictionary = {
	"Commune":  {"col": Color("4A3B28"), "w": 3},   # brun-ink sobre
	"Rare":     {"col": Color("5A7A8C"), "w": 4},   # bleu-acier
	"Épique":   {"col": Color("9A4FA8"), "w": 5},   # magenta-violet
	"Mythique": {"col": Color("C9A24B"), "w": 7},   # or épais (+ lueur)
}

# v10.5 — Archétype d'effet → couleur de bande + libellé (reflète « ce que fait la carte »).
const ARCHETYPE_STYLE: Dictionary = {
	"Offensif": {"col": Color("C0533A"), "label": "OFFENSE"},
	"Défensif": {"col": Color("4E7A6A"), "label": "DÉFENSE"},
	"Social":   {"col": Color("B58A3A"), "label": "PAROLE"},
	"Mystique": {"col": Color("6B5A9C"), "label": "MYSTÈRE"},
	"Corrompu": {"col": Color("8B4FA3"), "label": "CORRUPTION"},
}

# v10.11 — Effet actif (Rare+) → couleur + icône du badge (coin haut-droit) : « coût/effet en un coup d'œil » (StS).
const EFFECT_STYLE: Dictionary = {
	"HEAL":  {"col": Color("5E7A42"), "icon": "♥"},
	"PURGE": {"col": Color("6B4E8A"), "icon": "✦"},
	"DRAW":  {"col": Color("3F5A6A"), "icon": "✚"},
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

	# Nom (main) ou rôle (combinaison).
	var top: Label = Label.new()
	top.text = role if _compact else card.card_name
	top.add_theme_color_override("font_color", COL_INK_DIM if _compact else COL_INK)
	top.add_theme_font_size_override("font_size", 11 if _compact else 13)
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


# Marqueurs de coin (overlay absolu sur self, hors flux du VBox) : gemme rareté/coût + badge d'effet.
func _add_corner_markers(rar: String, rstyle: Dictionary) -> void:
	var sz: Vector2 = CARD_SIZE_COMPACT if _compact else CARD_SIZE
	var gsz: float = 18.0 if _compact else 24.0
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
		gl.add_theme_font_size_override("font_size", 11 if _compact else 13)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_child(gl)
	# Badge d'effet (coin haut-droit) — masqué en compact (zone de combinaison étroite).
	if not _compact and str(card.effect_type) != "" and EFFECT_STYLE.has(card.effect_type):
		var est: Dictionary = EFFECT_STYLE[card.effect_type]
		var bw: float = 52.0
		var badge: Panel = Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(sz.x - bw - 4.0, 4.0)
		badge.size = Vector2(bw, 22.0)
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
		bl.add_theme_font_size_override("font_size", 13)
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
	position = _base_pos + Vector2(sin(_sway_phase * 0.35) * 1.0, sin(_sway_phase * 0.9 + 0.7) * 2.8)


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
	if first or not animate_reflow or not is_inside_tree():
		position = pos
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
	_tw.tween_property(self, "position", pos, d)
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
		_animate(_base_pos, _base_rot, 1.0)
		if not _discarding:
			_sway_active = not _compact
			set_process(_wants_process())


func _scale_to(scl: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(scl, scl), ANIM)


func deal_in(delay: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_sway_active = false
	set_process(_rarity_rank >= 1)
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	position = _base_pos + Vector2(0.0, 140.0)
	rotation = _base_rot + deg_to_rad((randf() - 0.5) * 16.0)
	MerlinAudio.play_sfx("deal", randf_range(0.95, 1.05))
	var d: float = MerlinVisual.DUR_DEAL * MerlinVisual.motion() * 1.3
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, 0.18).set_delay(delay)
	_tw.tween_property(self, "position", _base_pos, d).set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE, d).set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
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
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "position", position + Vector2(dir * 60.0, 40.0), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "rotation", rotation + deg_to_rad(dir * -35.0), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "scale", Vector2(0.55, 0.55), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "modulate:a", 0.0, d * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(queue_free)


## Pose dans la combinaison : apparition pop (échelle + fondu). `delay` permet d'attendre
## l'arrivée du ghost de vol (§21 `ui`) — la carte compacte POP quand le ghost se pose.
func pop_in(delay: float = 0.0) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, 0.14).set_delay(delay)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)


func _animate(pos: Vector2, rot: float, scl: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", pos, ANIM)
	_tw.tween_property(self, "rotation", rot, ANIM)
	_tw.tween_property(self, "scale", Vector2(scl, scl), ANIM)


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
	var press_scale: float = 1.04 if _compact else 1.08
	_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(press_scale, press_scale), 0.06)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.10)  # retour systématique à 1.0 (couvre cas tactile sans hover)
