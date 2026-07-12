class_name MerlinActionView
extends Control
## v11-W2 (pivot ACTION+TRAIT, spec §I) — TUILE d'action 260×116 : grammaire SURFACE volontairement
## DISTINCTE de la carte-trait CREAM (anti-confusion « je cherche à jouer 2 cartes »).
## Anatomie N4-RUNES (2026-07-11) : VERBE 26 px CREAM en tête, SANS pastilles de tags de base
## (le jargon quitte l'écran : l'affinité se lit au souligné feedforward + preview R120 ; slot
## « tag » rempli = pip de RUNE neutre, zéro mot)
## · 3 slots de greffe 24 px TOUJOURS dessinés en pied (W2 : vides = cercles
## pointillés BORDER_BRUN — la greffabilité doit être ÉVIDENTE, les greffes arrivent en W3).
## Liseré = qualité de dé (MerlinDice.rim_for_rarity de la rareté de l'action, langage R133).
## Sélection = bordure GOLD 3 px + press 0.96 (langage §21). Toutes les durées ×MerlinVisual.motion().

signal action_clicked(card: MerlinCard)

# N4-RUNES (fix flake bugres) : référence par PRELOAD, jamais par nom de classe globale (course du
# résolveur GDScript sur les arêtes class_name : Parse Error intermittent au boot). Déterministe.
const _Glyph: GDScript = preload("res://scripts/game/merlin_glyph.gd")

const TILE_SIZE: Vector2 = Vector2(260, 116)
const HOVER_SCALE: float = 1.03
const SLOT_PX: float = 24.0       # slot de greffe (3 fixes, spec §E)
const SLOT_GAP: float = 12.0
const SLOT_DASHES: int = 8        # segments du cercle pointillé (slot vide)
const DUR_HOVER: float = 0.12     # §21 `fast`
const DUR_PRESS: float = 0.06     # §21 `tap`
# N4-P1 (chantier 1) : le feedforward passe du souligné 3 px au CADRE lumineux GOLD (liseré +
# halo autour de la tuile), même vocabulaire que l'affinité des cartes-runes. Alphas relevés :
# le souligné 0.15-0.4 « ne portait pas la décision » (panel BLOQUANT_FUN).
const FF_ALPHA_MAX: float = 0.65  # pic du pulse (lueur nette)
const FF_ALPHA_MIN: float = 0.35  # creux du pulse

var card: MerlinCard
var _sb: StyleBoxFlat
var _rim: Color = MerlinVisual.BORDER_BRUN
var _selected: bool = false
var _hovering: bool = false
var _ff_on: bool = false
var _ff_alpha: float = 0.0        # alpha courant du cadre lumineux (source du _draw, tweené)
var _ff_tw: Tween
var _ff_rings: Array = []         # StyleBoxFlat border-only du cadre lumineux (cachés, N4-P1)
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
# N5-C2 : JAUGE de MAÎTRISE par usage (progression vers le prochain palier). Le « +N courant » est sur
# le badge de talent (fondu talent+maîtrise) ; cette jauge montre « combien avant le prochain +1 ».
var _mastery_bonus: int = 0
var _mastery_frac: float = 0.0
var _mastery_at_cap: bool = false
const MASTERY_SEGMENTS: int = 2   # miroir MerlinRun.MASTERY_CAP (nb de paliers de maîtrise)
# P3 (chantier 7, F2) — LISIBILITÉ des greffes posées SANS hover (viole §23 pilier 4) : à la SÉLECTION
# de la tuile (tap = geste déjà fait pour jouer le verbe), une pastille lisible au-dessus liste ce que
# les greffes apportent (libellés d'INTENTION, zéro nom de tag brut R147). Poussée par merlin_game.
const REVEAL_W: float = 300.0
var _graft_summary: String = ""
var _reveal: PanelContainer = null


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
	# Badge de talent « +N » (skill_mod du verbe, R120) : GOLD sur SURFACE. Vague A (A2) : TOUJOURS
	# visible dès l'apparition de la tuile, « +0 » compris — le niveau d'action est lisible d'emblée.
	_talent_lbl = Label.new()
	_talent_lbl.text = "+0"
	_talent_lbl.add_theme_color_override("font_color", MerlinVisual.GOLD)
	_talent_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	_talent_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talent_lbl.visible = true
	verb_row.add_child(_talent_lbl)

	# N4-RUNES : les 2 pastilles de tags de base sont SUPPRIMÉES (zéro jargon à l'écran). Les tags
	# de base restent 100 % MÉCANIQUES (couverture, feedforward, moteur d20) : seul l'affichage part.


func _draw() -> void:
	# 3 slots de greffe FIXES, toujours dessinés : vide = cercle pointillé BORDER_BRUN (greffabilité
	# ÉVIDENTE) ; rempli = glyphe du KIND sans hover (v11-W3 : pastille famille = tag, badge « +N » OR
	# = bonus au jet d20 (v2-W3), ✚n/❖n/✦n = charges avec compteur restant — épuisée = estompée).
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
	_draw_mastery_gauge()  # N5-C2 : progression de maîtrise (jauge de paliers) sous le verbe
	# N4-P1 (chantier 1) : FEEDFORWARD = CADRE lumineux GOLD (liseré net + halo diffus), cohérent
	# avec l'affinité des cartes-runes. StyleBoxFlat border-only cachés (zéro alloc par frame).
	if _ff_alpha > 0.005:
		if _ff_rings.is_empty():
			for w in [3, 5]:
				var rsb: StyleBoxFlat = StyleBoxFlat.new()
				rsb.draw_center = false
				rsb.set_border_width_all(int(w))
				rsb.set_corner_radius_all(10)
				rsb.anti_aliasing = true
				_ff_rings.append(rsb)
		var g: Color = MerlinVisual.GOLD
		var rect_ff: Rect2 = Rect2(Vector2.ZERO, size)
		(_ff_rings[0] as StyleBoxFlat).border_color = Color(g.r, g.g, g.b, _ff_alpha)
		draw_style_box(_ff_rings[0], rect_ff.grow(2.0))
		(_ff_rings[1] as StyleBoxFlat).border_color = Color(g.r, g.g, g.b, _ff_alpha * 0.40)
		draw_style_box(_ff_rings[1], rect_ff.grow(6.0))
	# Flash GOLD de POSE (v11-W3) : le cadre s'embrase brièvement quand une greffe se pose.
	if _flash_a > 0.005:
		var fg: Color = MerlinVisual.GOLD
		draw_rect(Rect2(Vector2(-2.0, -2.0), size + Vector2(4.0, 4.0)),
			Color(fg.r, fg.g, fg.b, 0.35 * _flash_a), false, 3.0)


# v11-W3 — slot REMPLI : le glyphe dit le type sans hover (spec §E).
func _draw_graft_slot(center: Vector2, radius: float, g: Dictionary) -> void:
	match str(g.get("kind", "")):
		"tag":
			# N4-RUNES : la pastille famille (jargon couleur) devient un PIP DE RUNE neutre, le mini
			# ogham du concept greffé (même vocabulaire gravé que les cartes-runes), CREAM sur SURFACE.
			draw_arc(center, radius * 0.92, 0.0, TAU, 20, MerlinVisual.BORDER_BRUN, 1.5)
			_Glyph.draw_rune_on(self, center, radius * 0.62,
				_Glyph.pattern_for_tag(str(g.get("tag", ""))), MerlinVisual.CREAM, 1.6)
		"roll", "die":
			# v2-W3 — badge « +N » OR cerclé : la greffe ajoute N au jet d20 (graft_bonus, moteur W1).
			# ("die" toléré : slot d'une greffe legacy pré-pivot, rendu identique — proxy +ROLL_BONUS_DEFAULT.)
			var amt: int = int(g.get("amount", MerlinCard.ROLL_BONUS_DEFAULT)) if str(g.get("kind", "")) == "roll" else MerlinCard.ROLL_BONUS_DEFAULT
			draw_arc(center, radius * 0.92, 0.0, TAU, 20, MerlinVisual.GOLD, 2.0)
			var font_r: Font = get_theme_default_font()
			if font_r != null:
				draw_string(font_r, Vector2(center.x - SLOT_PX, center.y + 5.0), "+%d" % amt,
					HORIZONTAL_ALIGNMENT_CENTER, SLOT_PX * 2.0, 13, MerlinVisual.GOLD)
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
	# P3 (chantier 7) : révèle la lecture des greffes À LA SÉLECTION (tap), jamais au survol.
	if on and _graft_summary != "":
		_build_reveal_pill()
	else:
		_hide_graft_reveal()


# P3 (chantier 7) — texte lisible des greffes posées (libellés d'intention, poussé par merlin_game).
# "" = aucune greffe. Mis à jour à chaque refresh ; ré-affiché si la tuile est sélectionnée.
func set_graft_summary(text: String) -> void:
	if text == _graft_summary:
		return
	_graft_summary = text
	if _selected:
		if text != "":
			_build_reveal_pill()
		else:
			_hide_graft_reveal()


func _build_reveal_pill() -> void:
	_hide_graft_reveal()
	if _graft_summary == "":
		return
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.z_index = 6  # au-dessus de l'éventail voisin (qui déborde sur la rangée d'actions)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = MerlinVisual.TOAST_BG
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = MerlinVisual.GOLD_DARK
	sb.set_content_margin_all(8)
	pill.add_theme_stylebox_override("panel", sb)
	var lbl: Label = Label.new()
	lbl.text = _graft_summary
	lbl.add_theme_color_override("font_color", MerlinVisual.CREAM)
	lbl.add_theme_font_size_override("font_size", 16)  # ≥16 px (lisibilité CDC-UX-12)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(REVEAL_W - 16.0, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	add_child(pill)
	_reveal = pill
	# Centrée AU-DESSUS de la tuile ; position recalée après le layout (la taille dépend du texte).
	pill.resized.connect(func() -> void:
		if is_instance_valid(pill):
			pill.position = Vector2((TILE_SIZE.x - pill.size.x) * 0.5, -pill.size.y - 8.0))
	if not MerlinVisual.reduced_motion and pill.is_inside_tree():
		pill.modulate.a = 0.0
		pill.create_tween().tween_property(pill, "modulate:a", 1.0, _dur(0.14)).set_trans(Tween.TRANS_SINE)


func _hide_graft_reveal() -> void:
	if _reveal != null and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null


# v2-W2 — niveau de talent du verbe : badge « +N » à côté du nom (le joueur VOIT son skill_mod).
# Vague A (A2) : le badge est TOUJOURS affiché (« +0 » compris) pour que le niveau d'action soit
# lisible dès l'apparition des tuiles — l'ancienne garde « 0 → caché » est levée. Idempotent.
func set_talent(level: int) -> void:
	if level == _talent_lvl and _talent_lbl != null:
		return
	_talent_lvl = level
	if _talent_lbl == null or not is_instance_valid(_talent_lbl):
		return
	# A2 (item 6) : le niveau d'action reste TOUJOURS affiché, « +0 » compris (plus de garde level > 0).
	_talent_lbl.text = "+%d" % level
	_talent_lbl.visible = true


# N5-C2 - JAUGE de maîtrise (progression vers le prochain palier). bonus = paliers atteints (0..cap),
# frac = progression [0,1] dans le palier courant, at_cap = plafond atteint. Idempotente ; redraw si change.
func set_mastery(bonus: int, frac: float, at_cap: bool) -> void:
	if bonus == _mastery_bonus and is_equal_approx(frac, _mastery_frac) and at_cap == _mastery_at_cap:
		return
	_mastery_bonus = bonus
	_mastery_frac = frac
	_mastery_at_cap = at_cap
	queue_redraw()


# N5-C2 - 2 segments (les 2 paliers de maîtrise) dessinés dans la bande libre sous le verbe : segment
# atteint = plein GOLD, segment en cours = rempli par frac, sinon piste BORDER_BRUN. Rien tant que le
# verbe n'a jamais été joué (pilier MINIMAL : aucune jauge morte). Statique (pas de motion → reduce-motion OK).
func _draw_mastery_gauge() -> void:
	if _mastery_bonus <= 0 and _mastery_frac <= 0.0:
		return
	var total_w: float = 150.0
	var gap: float = 4.0
	var seg_w: float = (total_w - gap * float(MASTERY_SEGMENTS - 1)) / float(MASTERY_SEGMENTS)
	var y: float = 40.0
	var h: float = 4.0
	var x0: float = (size.x - total_w) / 2.0
	for i in MASTERY_SEGMENTS:
		var sx: float = x0 + float(i) * (seg_w + gap)
		draw_rect(Rect2(sx, y, seg_w, h), MerlinVisual.BORDER_BRUN, true)
		var fill: float = 0.0
		if i < _mastery_bonus:
			fill = 1.0
		elif i == _mastery_bonus and not _mastery_at_cap:
			fill = _mastery_frac
		if fill > 0.0:
			draw_rect(Rect2(sx, y, seg_w * fill, h), MerlinVisual.GOLD, true)


# W3 : le liseré se re-dérive quand les greffes changent la bande de dé (langage R133 conservé).
func set_die_rarity(rarity: String) -> void:
	_rim = MerlinDice.rim_for_rarity(rarity)
	if _sb != null and not _selected:
		_sb.border_color = _rim


# Feedforward (spec §I, rendu N4-P1) : CADRE lumineux GOLD pulsé quand la tuile couvre ≥1 tag
# requis du beat. Reduce-motion : alpha statique au pic — l'information survit sans boucle (R74).
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
	# N4-RUNES : libellé neutre (le mot de tag quitte l'écran ; le bonus reste mécanique, R120).
	lbl.text = "✦ Bénie"
	lbl.add_theme_color_override("font_color", MerlinVisual.INK)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	badge.position = Vector2(TILE_SIZE.x * 0.5 - 34.0, -10.0)
	add_child(badge)
	_blessed_badge = badge
