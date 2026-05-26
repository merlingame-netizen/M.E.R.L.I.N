class_name MerlinCardView
extends Control
## Vue de carte — DA flat rétro-minimaliste (décision 2026-05-26) : carte crème, glyphe-ligne
## celtique centré (par famille de tag), petit nom, point-tag coloré ; bordure or si posée,
## violet si corruption. S'agrandit/se redresse/se soulève au survol. Émet card_clicked au clic.

signal card_clicked(card)

const CARD_SIZE: Vector2 = Vector2(152, 196)
const CARD_SIZE_COMPACT: Vector2 = Vector2(150, 88)  # zone de combinaison (cartes posées)
const HOVER_SCALE: float = 1.18
const HOVER_LIFT: float = 30.0
const COMPACT_HOVER_SCALE: float = 1.06
const ANIM: float = 0.12

# DA flat rétro-minimaliste (décision 2026-05-26).
const COL_CARD: Color = Color("E8DCC0")    # crème (fond carte)
const COL_INK: Color = Color("2A2018")     # trait / bordure / glyphe
const COL_INK_DIM: Color = Color("6E5A3C")
const COL_GOLD: Color = Color("C9A24B")    # bordure si carte posée/sélectionnée
const COL_VIOLET: Color = Color("7B4FA3")  # bordure si corruption

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
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(6)
	# Bordure : or si posée (rôle), violet si corruption, sinon trait ink fin.
	var border_col: Color = COL_GOLD if role != "" else COL_INK
	if card.corruption > 0:
		border_col = COL_VIOLET
	sb.set_border_width_all(2)
	sb.border_color = border_col
	sb.set_content_margin_all(8 if _compact else 10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# Libellé sobre en haut : nom (main) ou rôle (combinaison).
	var top: Label = Label.new()
	top.text = role if _compact else card.card_name
	top.add_theme_color_override("font_color", COL_INK_DIM if _compact else COL_INK)
	top.add_theme_font_size_override("font_size", 10 if _compact else 11)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)

	# Glyphe-ligne celtique centré (élément héros), couleur ink — choisi par famille de tag.
	var fam: String = MerlinTags.family_of(str(card.tags[0])) if card.tags.size() > 0 else ""
	var glyph: MerlinGlyph = MerlinGlyph.new()
	glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	glyph.setup(MerlinGlyph.for_family(fam), COL_INK, 2.0 if _compact else 2.5)
	v.add_child(glyph)

	# Point-tag coloré (famille primaire) en bas.
	var dotrow: CenterContainer = CenterContainer.new()
	dotrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(dotrow)
	var dot: Panel = Panel.new()
	dot.custom_minimum_size = Vector2(11, 11)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = Color(MerlinTags.color_of(str(card.tags[0]))) if card.tags.size() > 0 else COL_INK_DIM
	dsb.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", dsb)
	dotrow.add_child(dot)


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
		card_clicked.emit(card)
