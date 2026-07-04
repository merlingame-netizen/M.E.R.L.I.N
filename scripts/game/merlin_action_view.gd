class_name MerlinActionView
extends Control
## v11-W2 (pivot ACTION+TRAIT, spec §I) — TUILE d'action 260×116 : grammaire SURFACE volontairement
## DISTINCTE de la carte-trait CREAM (anti-confusion « je cherche à jouer 2 cartes »).
## Anatomie : VERBE 26 px CREAM en tête · 2 pastilles rondes 18 px = tags de base (couleur
## MerlinTags.color_of) · 3 slots de greffe 24 px TOUJOURS dessinés en pied (W2 : vides = cercles
## pointillés BORDER_BRUN — la greffabilité doit être ÉVIDENTE, les greffes arrivent en W3).
## Liseré = qualité de dé (MerlinDice.rim_for_rarity de la rareté de l'action, langage R133).
## Sélection = bordure GOLD 3 px + press 0.96 (langage §21). Toutes les durées ×MerlinVisual.motion().

signal action_clicked(card: MerlinCard)

const TILE_SIZE: Vector2 = Vector2(260, 116)
const HOVER_SCALE: float = 1.03
const DOT_PX: float = 18.0        # pastille de tag de base
const SLOT_PX: float = 24.0       # slot de greffe (3 fixes, spec §E)
const SLOT_GAP: float = 12.0
const SLOT_DASHES: int = 8        # segments du cercle pointillé (slot vide)
const DUR_HOVER: float = 0.12     # §21 `fast`
const DUR_PRESS: float = 0.06     # §21 `tap`
const FF_ALPHA_MAX: float = 0.4   # souligné feedforward GOLD (spec §I : alpha 0.4 pulsé)
const FF_ALPHA_MIN: float = 0.15

var card: MerlinCard
var _sb: StyleBoxFlat
var _rim: Color = MerlinVisual.BORDER_BRUN
var _selected: bool = false
var _hovering: bool = false
var _ff_on: bool = false
var _ff_alpha: float = 0.0        # alpha courant du souligné (source du _draw, tweené)
var _ff_tw: Tween
var _pulse_tw: Tween              # pulse SUR PLACE pendant la fusion (la tuile n'est jamais aspirée)
var _tw: Tween
var _blessed_badge: Control = null
var _blessed_tag: String = ""


func _dur(base: float) -> float:
	return base * MerlinVisual.motion()


func setup(c: MerlinCard) -> void:
	card = c
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	pivot_offset = TILE_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rim = MerlinDice.rim_for_rarity(card.rarity)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_gui_input)
	_build()


func _build() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb = StyleBoxFlat.new()
	_sb.bg_color = MerlinVisual.SURFACE
	_sb.set_corner_radius_all(8)
	_sb.set_border_width_all(2)
	_sb.border_color = _rim
	_sb.content_margin_left = 10.0
	_sb.content_margin_right = 10.0
	_sb.content_margin_top = 4.0
	_sb.content_margin_bottom = 42.0  # pied réservé aux 3 slots de greffe (dessinés en _draw)
	panel.add_theme_stylebox_override("panel", _sb)
	add_child(panel)

	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# VERBE — l'identité de la tuile (FS_BTN 26 px, CREAM sur SURFACE).
	var verb: Label = Label.new()
	verb.text = card.card_name
	verb.add_theme_color_override("font_color", MerlinVisual.CREAM)
	verb.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(verb)

	# Les 2 tags de base : pastille ronde 18 px (couleur de famille) + nom court (lisible <2 s, §23).
	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 12)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag_row)
	for t in card.tags:
		tag_row.add_child(_tag_dot(str(t)))


# Pastille de tag : rond 18 px FAMILY_COLORS + libellé DIM_WARM (deux tags d'une même famille
# resteraient indiscernables en couleur seule — le mot lève l'ambiguïté).
func _tag_dot(tag: String) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot: Panel = Panel.new()
	dot.custom_minimum_size = Vector2(DOT_PX, DOT_PX)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = Color(MerlinTags.color_of(tag))
	dsb.set_corner_radius_all(int(DOT_PX / 2.0))
	dot.add_theme_stylebox_override("panel", dsb)
	box.add_child(dot)
	var lbl: Label = Label.new()
	lbl.text = tag
	lbl.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return box


func _draw() -> void:
	# 3 slots de greffe FIXES, toujours dessinés (W2 : tous vides → cercle pointillé BORDER_BRUN).
	var cy: float = size.y - 24.0
	var total_w: float = SLOT_PX * 3.0 + SLOT_GAP * 2.0
	var x0: float = (size.x - total_w) / 2.0 + SLOT_PX / 2.0
	for i in 3:
		var c: Vector2 = Vector2(x0 + float(i) * (SLOT_PX + SLOT_GAP), cy)
		_draw_dashed_circle(c, SLOT_PX / 2.0, MerlinVisual.BORDER_BRUN)
	# Souligné FEEDFORWARD (spec §I) : la tuile couvre ≥1 tag requis → trait GOLD alpha 0.4 pulsé.
	if _ff_alpha > 0.005:
		var g: Color = MerlinVisual.GOLD
		draw_rect(Rect2(14.0, size.y - 6.0, size.x - 28.0, 3.0), Color(g.r, g.g, g.b, _ff_alpha))


func _draw_dashed_circle(center: Vector2, radius: float, col: Color) -> void:
	var span: float = TAU / float(SLOT_DASHES)
	for k in SLOT_DASHES:
		var a0: float = float(k) * span
		draw_arc(center, radius, a0, a0 + span * 0.55, 5, col, 2.0)


func _on_enter() -> void:
	_hovering = true
	_scale_to(HOVER_SCALE)


func _on_exit() -> void:
	_hovering = false
	_scale_to(1.0)


func _scale_to(s: float) -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		return  # la fusion pulse sur place — le hover ne se bat pas avec elle
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(s, s), _dur(DUR_HOVER))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press_feedback()
		action_clicked.emit(card)


# Langage §21 `tap` : PRESS 0.96 puis retour CONTEXTUEL (hover ou neutre) — même grammaire que
# les boutons et les cartes (retour visuel ≤100 ms, pilier TACTILE).
func _press_feedback() -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var back: float = HOVER_SCALE if _hovering else 1.0
	_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(0.96, 0.96) * back, _dur(DUR_PRESS))
	_tw.tween_property(self, "scale", Vector2(back, back), _dur(0.10))


# Sélection = bordure GOLD 3 px (l'état se lit SUR l'élément — plus de combo panel).
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	if _sb != null:
		_sb.border_color = MerlinVisual.GOLD if on else _rim
		_sb.set_border_width_all(3 if on else 2)


# W3 : le liseré se re-dérive quand les greffes changent la bande de dé (langage R133 conservé).
func set_die_rarity(rarity: String) -> void:
	_rim = MerlinDice.rim_for_rarity(rarity)
	if _sb != null and not _selected:
		_sb.border_color = _rim


# Feedforward (spec §I) : souligné GOLD pulsé quand la tuile couvre ≥1 tag requis du beat.
# Reduce-motion : alpha statique 0.4 — l'information survit sans boucle (R74).
func set_feedforward(on: bool) -> void:
	if _ff_on == on:
		return
	_ff_on = on
	if _ff_tw != null and _ff_tw.is_valid():
		_ff_tw.kill()
	_ff_tw = null
	if not on:
		_set_ff_alpha(0.0)
		return
	if MerlinVisual.reduced_motion:
		_set_ff_alpha(FF_ALPHA_MAX)
		return
	_set_ff_alpha(FF_ALPHA_MIN)
	_ff_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ff_tw.tween_method(_set_ff_alpha, FF_ALPHA_MIN, FF_ALPHA_MAX, _dur(0.9))
	_ff_tw.tween_method(_set_ff_alpha, FF_ALPHA_MAX, FF_ALPHA_MIN, _dur(0.9))


func _set_ff_alpha(v: float) -> void:
	_ff_alpha = v
	queue_redraw()


# Pendant la fusion, l'ACTION pulse SUR PLACE (tuile permanente — jamais aspirée par MerlinFx,
# contrairement à la vue du trait). Reduce-motion : rien (le geste est déjà porté par la fusion).
func fusion_pulse(on: bool) -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	if not on:
		scale = Vector2.ONE
		return
	if MerlinVisual.reduced_motion:
		return
	_pulse_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tw.tween_property(self, "scale", Vector2(1.06, 1.06), _dur(0.22))
	_pulse_tw.tween_property(self, "scale", Vector2.ONE, _dur(0.22))


# R131 (v11-W2) — bénédiction VISIBLE : badge GOLD « ✦ tag » à cheval sur le bord haut de la tuile
# (zéro info cachée, pilier ÉVIDENT). "" = retire le badge (bénédiction consommée).
func set_blessed(tag: String) -> void:
	if tag == _blessed_tag:
		return
	_blessed_tag = tag
	if _blessed_badge != null and is_instance_valid(_blessed_badge):
		_blessed_badge.queue_free()
	_blessed_badge = null
	if tag == "":
		return
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = MerlinVisual.GOLD
	bsb.set_corner_radius_all(8)
	bsb.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", bsb)
	var lbl: Label = Label.new()
	lbl.text = "✦ " + tag
	lbl.add_theme_color_override("font_color", MerlinVisual.INK)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	badge.position = Vector2(TILE_SIZE.x * 0.5 - 34.0, -10.0)
	add_child(badge)
	_blessed_badge = badge
