class_name MerlinCardView
extends Control
## Vue de carte — DA flat rétro-minimaliste. v10.5 (user 2026-06-06) : cartes plus grandes, glyphe
## par TAG précis (logo reflète le concept), bordure ÉPAISSE colorée par RARETÉ (Commune/Rare/Épique/
## Mythique), bande d'ARCHÉTYPE d'effet en bas (Offensif/Défensif/Social/Mystique/Corrompu).
## S'agrandit/se soulève au survol. Émet card_clicked au clic.

signal card_clicked(card)

const CARD_SIZE: Vector2 = Vector2(180, 240)          # v10.5 : + grandes (était 152×196)
const CARD_SIZE_COMPACT: Vector2 = Vector2(170, 104)  # zone de combinaison (était 150×88)
const HOVER_SCALE: float = 1.18
const HOVER_LIFT: float = 30.0
const COMPACT_HOVER_SCALE: float = 1.06
const ANIM: float = 0.12

# DA flat rétro-minimaliste (décision 2026-05-26).
const COL_CARD: Color = Color("E8DCC0")    # crème (fond carte)
const COL_INK: Color = Color("2A2018")     # trait / glyphe
const COL_INK_DIM: Color = Color("6E5A3C")
const COL_GOLD: Color = Color("C9A24B")    # liseré « posée » (rôle)

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

var card: MerlinCard
var _compact: bool = false
var _base_pos: Vector2 = Vector2.ZERO
var _base_rot: float = 0.0
var _base_z: int = 0
var _hovering: bool = false
var _tw: Tween


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
	var arch: String = card.archetype()
	var astyle: Dictionary = ARCHETYPE_STYLE.get(arch, ARCHETYPE_STYLE["Mystique"])

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(8)
	# Bordure ÉPAISSE = RARETÉ (v10.5). Liseré or si carte posée (rôle), sinon couleur de rareté.
	sb.set_border_width_all(int(rstyle["w"]))
	sb.border_color = COL_GOLD if role != "" else (rstyle["col"] as Color)
	# Mythique : lueur dorée (shadow StyleBox — glow bon marché sans shader).
	if rar == "Mythique":
		sb.shadow_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45)
		sb.shadow_size = 8
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

	# Rangée de pastilles = TOUS les tags (couleur de famille). Omise en compact (place réduite).
	if not _compact and card.tags.size() > 0:
		var dotrow: HBoxContainer = HBoxContainer.new()
		dotrow.alignment = BoxContainer.ALIGNMENT_CENTER
		dotrow.add_theme_constant_override("separation", 5)
		dotrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(dotrow)
		for t in card.tags:
			var dot: Panel = Panel.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var dsb: StyleBoxFlat = StyleBoxFlat.new()
			dsb.bg_color = Color(MerlinTags.color_of(str(t)))
			dsb.set_corner_radius_all(6)
			dot.add_theme_stylebox_override("panel", dsb)
			dotrow.add_child(dot)

	# Bande ARCHÉTYPE d'effet en bas (couleur + libellé) + pips de corruption si coût > 0.
	var band: PanelContainer = PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = (astyle["col"] as Color)
	bsb.set_corner_radius_all(4)
	bsb.content_margin_top = 2.0
	bsb.content_margin_bottom = 2.0
	bsb.content_margin_left = 6.0
	bsb.content_margin_right = 6.0
	band.add_theme_stylebox_override("panel", bsb)
	v.add_child(band)
	var band_lbl: Label = Label.new()
	var band_txt: String = str(astyle["label"])
	if card.corruption > 0:
		band_txt += "  " + "◆".repeat(card.corruption)  # pips = intensité de corruption
	band_lbl.text = band_txt
	band_lbl.add_theme_color_override("font_color", COL_CARD)
	band_lbl.add_theme_font_size_override("font_size", 9 if _compact else 11)
	band_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(band_lbl)


## Position/rotation de base dans l'éventail (posées par le conteneur). Appliquées si pas survolé.
func set_fan_transform(pos: Vector2, rot: float) -> void:
	_base_pos = pos
	_base_rot = rot
	_base_z = z_index  # ordre de recouvrement de l'éventail (posé par le conteneur avant cet appel)
	# Hors survol, un re-layout (resize) doit reprendre la main : on tue une anim en cours (deal/pop)
	# et on pose la carte à sa place. La distribution initiale relance deal_in JUSTE APRÈS cet appel.
	if not _hovering:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		position = pos
		rotation = rot
		scale = Vector2.ONE
		modulate.a = 1.0  # garantit l'opacité si un deal_in (tween a:0→1) est interrompu par un re-layout (fix cartes invisibles, user 2026-06-06)


func _on_enter() -> void:
	_hovering = true
	z_index = 50
	if _compact:
		_scale_to(COMPACT_HOVER_SCALE)  # carte posée (HBox) : agrandir seulement, pas de lift/rotation
	else:
		_animate(_base_pos + Vector2(0, -HOVER_LIFT), 0.0, HOVER_SCALE)


func _on_exit() -> void:
	_hovering = false
	z_index = _base_z  # rétablit l'ordre de l'éventail (pas 0 → évite le z-fighting entre voisines)
	if _compact:
		_scale_to(1.0)
	else:
		_animate(_base_pos, _base_rot, 1.0)


func _scale_to(scl: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(scl, scl), ANIM)


## Distribution : la carte arrive depuis le bas en fondu vers sa place d'éventail (stagger via delay).
func deal_in(delay: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 0.0
	position = _base_pos + Vector2(0.0, 40.0)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, 0.24).set_delay(delay)
	_tw.tween_property(self, "position", _base_pos, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pose dans la combinaison : apparition pop (échelle + fondu).
func pop_in() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "modulate:a", 1.0, 0.14)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
