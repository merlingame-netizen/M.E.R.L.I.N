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
var _await_tw: Tween              # v11-W3 : pulse « en attente de cible » du draft de greffe
var _slot_pop_i: int = -1         # v11-W3 : index du slot qui vient d'être rempli (micro-anim de pose)
var _slot_pop_k: float = 1.0      # échelle courante du slot posé (tweenée TRANS_BACK)
var _flash_a: float = 0.0         # flash GOLD du cadre à la pose d'une greffe
var _slot_tw: Tween               # tweens de pose stockés → killés avant re-pose (un seul écrivain)
var _flash_tw: Tween
var _tw: Tween
var _blessed_badge: Control = null
var _blessed_tag: String = ""
var _talent_lbl: Label = null     # v2-W2 : badge « +N » = niveau de talent du verbe (skill_mod, R120)
var _talent_lvl: int = 0


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

	# VERBE — l'identité de la tuile (FS_BTN 26 px, CREAM sur SURFACE). v2-W2 : le verbe et le badge de
	# talent « +N » vivent sur une rangée (le +N apparaît quand le talent monte, style charte GOLD).
	var verb_row: HBoxContainer = HBoxContainer.new()
	verb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	verb_row.add_theme_constant_override("separation", 6)
	verb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(verb_row)
	var verb: Label = Label.new()
	verb.text = card.card_name
	verb.add_theme_color_override("font_color", MerlinVisual.CREAM)
	verb.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	verb_row.add_child(verb)
	# Badge de talent « +N » (skill_mod du verbe, R120) : GOLD sur SURFACE, caché à 0 (jamais de bruit).
	_talent_lbl = Label.new()
	_talent_lbl.text = ""
	_talent_lbl.add_theme_color_override("font_color", MerlinVisual.GOLD)
	_talent_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	_talent_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_lbl.visible = false
	verb_row.add_child(_talent_lbl)

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
	# 3 slots de greffe FIXES, toujours dessinés : vide = cercle pointillé BORDER_BRUN (greffabilité
	# ÉVIDENTE) ; rempli = glyphe du KIND sans hover (v11-W3 : pastille famille = tag, pip or = bande
	# de dé, ✚n/❖n/✦n = charges avec compteur restant — épuisée = estompée).
	var cy: float = size.y - 24.0
	var total_w: float = SLOT_PX * 3.0 + SLOT_GAP * 2.0
	var x0: float = (size.x - total_w) / 2.0 + SLOT_PX / 2.0
	var grafts: Array = (card.grafts as Array) if card != null else []
	for i in 3:
		var c: Vector2 = Vector2(x0 + float(i) * (SLOT_PX + SLOT_GAP), cy)
		if i < grafts.size() and grafts[i] is Dictionary:
			var k: float = _slot_pop_k if i == _slot_pop_i else 1.0
			_draw_graft_slot(c, (SLOT_PX / 2.0) * k, grafts[i])
		else:
			_draw_dashed_circle(c, SLOT_PX / 2.0, MerlinVisual.BORDER_BRUN)
	# Souligné FEEDFORWARD (spec §I) : la tuile couvre ≥1 tag requis → trait GOLD alpha 0.4 pulsé.
	if _ff_alpha > 0.005:
		var g: Color = MerlinVisual.GOLD
		draw_rect(Rect2(14.0, size.y - 6.0, size.x - 28.0, 3.0), Color(g.r, g.g, g.b, _ff_alpha))
	# Flash GOLD de POSE (v11-W3) : le cadre s'embrase brièvement quand une greffe se pose.
	if _flash_a > 0.005:
		var fg: Color = MerlinVisual.GOLD
		draw_rect(Rect2(Vector2(-2.0, -2.0), size + Vector2(4.0, 4.0)),
			Color(fg.r, fg.g, fg.b, 0.35 * _flash_a), false, 3.0)


# v11-W3 — slot REMPLI : le glyphe dit le type sans hover (spec §E).
func _draw_graft_slot(center: Vector2, radius: float, g: Dictionary) -> void:
	match str(g.get("kind", "")):
		"tag":
			# Pastille pleine à la couleur de FAMILLE du tag greffé (même langage que les tags de base).
			draw_circle(center, radius * 0.80, Color(MerlinTags.color_of(str(g.get("tag", "")))))
			draw_arc(center, radius * 0.92, 0.0, TAU, 20, MerlinVisual.BORDER_BRUN, 1.5)
		"die":
			# Pip OR cerclé : la greffe élargit la bande de dé (langage R133, liseré = qualité).
			draw_arc(center, radius * 0.85, 0.0, TAU, 20, MerlinVisual.GOLD, 2.0)
			draw_circle(center, radius * 0.34, MerlinVisual.GOLD)
		"charge":
			var left: int = int(g.get("charges", 0))
			var icon: String = "✦"
			var col: Color = MerlinVisual.EFFECT_DRAW
			match str(g.get("effect_type", "")):
				"HEAL":
					icon = "✚"
					col = MerlinVisual.EFFECT_HEAL
				"PURGE":
					icon = "❖"
					col = MerlinVisual.EFFECT_PURGE
			col = col.lightened(0.35)  # lisible sur SURFACE (même dérivation que les chips vignette)
			if left <= 0:
				col.a = 0.35  # épuisée : l'information reste, estompée
			var font: Font = get_theme_default_font()
			if font != null:
				draw_string(font, Vector2(center.x - SLOT_PX, center.y + 5.0), "%s%d" % [icon, left],
					HORIZONTAL_ALIGNMENT_CENTER, SLOT_PX * 2.0, 13, col)


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
	if _await_tw != null and _await_tw.is_valid():
		return  # v11-W3 : idem pour le pulse d'attente de cible (un seul propriétaire du scale)
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
	if _await_tw != null and _await_tw.is_valid():
		return  # v11-W3 : le clic-cible a son propre feedback (graft_pop) — pas de bagarre de scale
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


# v2-W2 — niveau de talent du verbe : badge « +N » à côté du nom (le joueur VOIT son skill_mod).
# 0 → badge caché (pilier MINIMAL : aucun élément UI sans rôle actif). Idempotent.
func set_talent(level: int) -> void:
	if level == _talent_lvl and _talent_lbl != null:
		return
	_talent_lvl = level
	if _talent_lbl == null or not is_instance_valid(_talent_lbl):
		return
	if level > 0:
		_talent_lbl.text = "+%d" % level
		_talent_lbl.visible = true
	else:
		_talent_lbl.text = ""
		_talent_lbl.visible = false


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


# v11-W3 (spec §E) — pulse « EN ATTENTE DE CIBLE » : la tuile ÉLIGIBLE respire pendant l'étape 2
# du draft de greffe (cousine de fusion_pulse, plus douce). Reduce-motion : rien — l'éligibilité
# reste lisible par contraste (les tuiles pleines sont estompées par le jeu).
func await_pulse(on: bool) -> void:
	if _await_tw != null and _await_tw.is_valid():
		_await_tw.kill()
	_await_tw = null
	if not on:
		if not (_pulse_tw != null and _pulse_tw.is_valid()):
			scale = Vector2.ONE
		return
	if MerlinVisual.reduced_motion:
		return
	_await_tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_await_tw.tween_property(self, "scale", Vector2(1.045, 1.045), _dur(0.45))
	_await_tw.tween_property(self, "scale", Vector2.ONE, _dur(0.45))


# v11-W3 — micro-anim de POSE d'une greffe : le glyphe du slot POP (TRANS_BACK) + flash GOLD du
# cadre. Appelée par merlin_game après run.apply_graft (le slot vient d'être rempli).
func graft_pop() -> void:
	queue_redraw()  # le slot rempli + le nouveau liseré se dessinent immédiatement
	var n: int = (card.grafts as Array).size() if card != null else 0
	if n <= 0:
		return
	_slot_pop_i = n - 1
	MerlinAudio.play_sfx("draft_reveal")  # le retour SONORE n'est pas du motion (R74)
	if MerlinVisual.reduced_motion:
		_slot_pop_k = 1.0
		_flash_a = 0.0
		return
	if _slot_tw != null and _slot_tw.is_valid():
		_slot_tw.kill()
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_slot_pop_k = 0.2
	_slot_tw = create_tween()
	_slot_tw.tween_method(func(v: float) -> void:
		_slot_pop_k = v
		queue_redraw(), 0.2, 1.0, _dur(0.28)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tw = create_tween()
	_flash_tw.tween_method(func(v: float) -> void:
		_flash_a = v
		queue_redraw(), 0.9, 0.0, _dur(0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
