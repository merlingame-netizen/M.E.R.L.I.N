class_name MerlinCardView
extends Control
## Vue de carte (bible R51-R53) : nom + pastilles de tags colorées (par famille) + évocation +
## coût Corruption ; bordure par RARETÉ (Commune=sépia mat, altérée violet si corruption>0).
## Compacte ; s'agrandit + se redresse + se soulève au survol (hover). Émet card_clicked au clic.

signal card_clicked(card)

const CARD_SIZE: Vector2 = Vector2(152, 196)
const CARD_SIZE_COMPACT: Vector2 = Vector2(150, 88)  # zone de combinaison (cartes posées)
const HOVER_SCALE: float = 1.18
const HOVER_LIFT: float = 30.0
const COMPACT_HOVER_SCALE: float = 1.06
const ANIM: float = 0.12

# Bordure par rareté (R53) — palette parchemin.
const RARITY_BORDER: Dictionary = {
	"Commune": Color("6E5A3C"),   # sépia mat
	"Rare": Color("AEB4BC"),      # argent
	"Épique": Color("C9A24B"),    # or
	"Mythique": Color("B57FD6"),  # irisé (approx statique)
}
const COL_SURFACE: Color = Color("241B12")
const COL_NAME: Color = Color("E8DCC0")
const COL_EVOC: Color = Color("B7A684")
const COL_GOLD: Color = Color("C9A24B")
const COL_VIOLET: Color = Color("7B4FA3")
const COL_PILL_TEXT: Color = Color("1A1410")

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
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	var border_col: Color = RARITY_BORDER.get(card.rarity, RARITY_BORDER["Commune"])
	if card.corruption > 0:
		border_col = border_col.lerp(COL_VIOLET, 0.55)  # altération Corruption (R53)
	sb.set_border_width_all(3)
	sb.border_color = border_col
	sb.set_content_margin_all(7 if _compact else 9)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	var name_lbl: Label = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_color_override("font_color", COL_NAME)
	name_lbl.add_theme_font_size_override("font_size", 13 if _compact else 14)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	var pills: HBoxContainer = HBoxContainer.new()
	pills.add_theme_constant_override("separation", 4)
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in card.tags:
		pills.add_child(_make_pill(str(t)))
	v.add_child(pills)

	if not _compact:
		var evoc: Label = Label.new()
		evoc.text = card.evocation
		evoc.add_theme_color_override("font_color", COL_EVOC)
		evoc.add_theme_font_size_override("font_size", 11)
		evoc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evoc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		evoc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(evoc)

	if role != "":
		var rlbl: Label = Label.new()
		rlbl.text = role
		rlbl.add_theme_color_override("font_color", COL_GOLD)
		rlbl.add_theme_font_size_override("font_size", 11)
		rlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(rlbl)

	if card.corruption > 0 and not _compact:
		var corr: Label = Label.new()
		corr.text = "⚠ Corruption %d" % card.corruption
		corr.add_theme_color_override("font_color", COL_VIOLET)
		corr.add_theme_font_size_override("font_size", 11)
		corr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(corr)


func _make_pill(tag: String) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(MerlinTags.color_of(tag))
	sb.set_corner_radius_all(7)
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = tag
	l.add_theme_color_override("font_color", COL_PILL_TEXT)
	l.add_theme_font_size_override("font_size", 11)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Position/rotation de base dans l'éventail (posées par le conteneur). Appliquées si pas survolé.
func set_fan_transform(pos: Vector2, rot: float) -> void:
	_base_pos = pos
	_base_rot = rot
	_base_z = z_index  # ordre de recouvrement de l'éventail (posé par le conteneur avant cet appel)
	if not _hovering:
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
