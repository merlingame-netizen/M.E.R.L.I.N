class_name MerlinClaudeUI
extends RefCounted
## DA v8 — Composants UI façon Claude : panneau latéral, bouton primaire, ligne de liste,
## carte de réponse mot-à-mot, pilule de sélection, section Récents.
## Classe STATIQUE (même convention que MerlinVisual / MerlinWoodcut).
## Source : SPEC.md §4, charte_p1.md §5, kit.md §B.

# Couleurs aliasées
const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_CREAM: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_GOLD_D: Color = MerlinVisual.GOLD_DARK
const COL_DIM: Color = MerlinVisual.DIM_WARM
const COL_INK: Color = MerlinVisual.INK
const COL_PANEL: Color = MerlinVisual.PANEL
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_CYAN: Color = MerlinVisual.MACHINE_CYAN
const COL_VIOLET: Color = MerlinVisual.VIOLET

# Polices
const FONT_BODY: String = MerlinVisual.FONT_EB_GARAMOND
const FONT_BODY_SEMI: String = MerlinVisual.FONT_EB_GARAMOND_SEMI
const FONT_TITLE: String = MerlinVisual.FONT_IM_FELL
const FONT_UI: String = MerlinVisual.FONT_DM_SANS
const FONT_UI_MED: String = MerlinVisual.FONT_DM_SANS_MEDIUM


# ── Panneau latéral (fond BG_DEEP 86-90 %, bord crème 16 %, rayon 16) ──
static func panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(COL_BG.r, COL_BG.g, COL_BG.b, MerlinVisual.PANEL_ALPHA)
	sb.set_corner_radius_all(MerlinVisual.PANEL_RADIUS)
	sb.set_border_width_all(1)
	sb.border_color = Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, MerlinVisual.PANEL_BORDER_ALPHA)
	sb.set_content_margin_all(20)
	return sb


# ── Bouton primaire (fond crème, texte encre, rayon 10, reflet) ──
static func make_primary_button(text: String, shortcut_hint: String = "") -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 48)
	# Normal style
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = COL_CREAM
	sn.set_corner_radius_all(MerlinVisual.BTN_PRIMARY_RADIUS)
	sn.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", sn)
	# Hover
	var sh: StyleBoxFlat = sn.duplicate()
	sh.bg_color = Color(COL_CREAM.r + 0.04, COL_CREAM.g + 0.03, COL_CREAM.b + 0.01, 1.0)
	btn.add_theme_stylebox_override("hover", sh)
	# Pressed
	var sp: StyleBoxFlat = sn.duplicate()
	sp.bg_color = Color(COL_CREAM.r - 0.06, COL_CREAM.g - 0.05, COL_CREAM.b - 0.04, 1.0)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", sn.duplicate())
	# Text colors
	btn.add_theme_color_override("font_color", COL_INK)
	btn.add_theme_color_override("font_hover_color", Color("0E0B07"))
	btn.add_theme_color_override("font_pressed_color", COL_GOLD_D)
	# Font
	var fnt: FontFile = _load_font(FONT_UI_MED)
	if fnt != null:
		btn.add_theme_font_override("font", fnt)
	btn.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	MerlinVisual.connect_button_feedback(btn)
	if shortcut_hint != "":
		btn.tooltip_text = shortcut_hint
	return btn


# ── Ligne de liste (icône + libellé + raccourci kbd au survol) ──
static func make_list_row(label_text: String, subtitle: String = "", kbd: String = "", glyph: String = "") -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	# Normal = transparent
	var sn: StyleBoxFlat = StyleBoxFlat.new()
	sn.bg_color = Color(0, 0, 0, 0)
	sn.set_corner_radius_all(8)
	sn.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", sn)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)
	# Glyph icon
	if glyph != "":
		var icon_lbl: Label = Label.new()
		icon_lbl.text = glyph
		icon_lbl.add_theme_color_override("font_color", COL_DIM)
		icon_lbl.add_theme_font_size_override("font_size", 20)
		icon_lbl.custom_minimum_size = Vector2(24, 0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(icon_lbl)
		icon_lbl.set_meta("_row_icon", true)
	# Labels column
	var vcol: VBoxContainer = VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vcol)
	var main_lbl: Label = Label.new()
	main_lbl.text = label_text
	main_lbl.add_theme_color_override("font_color", COL_CREAM)
	var fnt_ui: FontFile = _load_font(FONT_UI)
	if fnt_ui != null:
		main_lbl.add_theme_font_override("font", fnt_ui)
	main_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	vcol.add_child(main_lbl)
	main_lbl.set_meta("_row_label", true)
	if subtitle != "":
		var sub_lbl: Label = Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_color_override("font_color", COL_DIM)
		sub_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
		vcol.add_child(sub_lbl)
	# Kbd hint (hidden by default, shown on hover)
	if kbd != "":
		var kbd_lbl: Label = Label.new()
		kbd_lbl.text = kbd
		kbd_lbl.add_theme_color_override("font_color", COL_DIM)
		kbd_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
		kbd_lbl.modulate.a = 0.0
		hb.add_child(kbd_lbl)
		kbd_lbl.set_meta("_row_kbd", true)
	# Hover behavior
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_entered.connect(func() -> void:
		var hover_sb: StyleBoxFlat = sn.duplicate()
		hover_sb.bg_color = Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, 0.08)
		row.add_theme_stylebox_override("panel", hover_sb)
		for ch in hb.get_children():
			if ch.has_meta("_row_icon"):
				ch.add_theme_color_override("font_color", COL_GOLD)
			if ch.has_meta("_row_kbd") and is_instance_valid(ch):
				_fade_node(ch, 1.0, 0.15))
	row.mouse_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", sn)
		for ch in hb.get_children():
			if ch.has_meta("_row_icon"):
				ch.add_theme_color_override("font_color", COL_DIM)
			if ch.has_meta("_row_kbd") and is_instance_valid(ch):
				_fade_node(ch, 0.0, 0.15))
	return row


# ── Carte de réponse de Merlin (en-tête yeux + texte mot-à-mot + suggestions) ──
static func make_response_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(COL_SURFACE.r, COL_SURFACE.g, COL_SURFACE.b, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.set_border_width_all(1)
	sb.border_color = Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, 0.08)
	card.add_theme_stylebox_override("panel", sb)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	# Header: eyes + "Merlin" + spinner
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)
	# Two eye bars (cyan)
	var eye_left: ColorRect = ColorRect.new()
	eye_left.custom_minimum_size = Vector2(3, 12)
	eye_left.color = COL_CYAN
	header.add_child(eye_left)
	var eye_right: ColorRect = ColorRect.new()
	eye_right.custom_minimum_size = Vector2(3, 12)
	eye_right.color = COL_CYAN
	header.add_child(eye_right)
	var name_lbl: Label = Label.new()
	name_lbl.text = "Merlin"
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	var fnt_semi: FontFile = _load_font(FONT_BODY_SEMI)
	if fnt_semi != null:
		name_lbl.add_theme_font_override("font", fnt_semi)
	name_lbl.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
	header.add_child(name_lbl)
	# Spinner placeholder (star rotating during generation)
	var spinner: Label = Label.new()
	spinner.text = "✦"
	spinner.add_theme_color_override("font_color", COL_GOLD)
	spinner.add_theme_font_size_override("font_size", 16)
	spinner.visible = false
	spinner.set_meta("_card_spinner", true)
	header.add_child(spinner)
	# Body text (EB Garamond, filled word by word)
	var body: RichTextLabel = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_color_override("default_color", COL_CREAM)
	var fnt_body: FontFile = _load_font(FONT_BODY)
	if fnt_body != null:
		body.add_theme_font_override("normal_font", fnt_body)
	body.add_theme_font_size_override("normal_font_size", MerlinVisual.FS_CAPTION)
	body.set_meta("_card_body", true)
	vb.add_child(body)
	# Suggestions container (hidden until populated)
	var suggestions: HBoxContainer = HBoxContainer.new()
	suggestions.add_theme_constant_override("separation", 8)
	suggestions.visible = false
	suggestions.set_meta("_card_suggestions", true)
	vb.add_child(suggestions)
	card.set_meta("_card_vbox", vb)
	return card


# ── Pilule de suggestion (chip cliquable sous la réponse) ──
static func make_chip(text: String) -> Button:
	var chip: Button = Button.new()
	chip.text = text
	chip.custom_minimum_size = Vector2(0, 36)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, 0.06)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	chip.add_theme_stylebox_override("normal", sb)
	var sh: StyleBoxFlat = sb.duplicate()
	sh.bg_color = Color(COL_CREAM.r, COL_CREAM.g, COL_CREAM.b, 0.12)
	chip.add_theme_stylebox_override("hover", sh)
	chip.add_theme_stylebox_override("pressed", sb.duplicate())
	chip.add_theme_stylebox_override("focus", sb.duplicate())
	chip.add_theme_color_override("font_color", COL_CREAM)
	chip.add_theme_color_override("font_hover_color", COL_GOLD)
	chip.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
	var fnt: FontFile = _load_font(FONT_UI)
	if fnt != null:
		chip.add_theme_font_override("font", fnt)
	MerlinVisual.connect_button_feedback(chip)
	return chip


# ── Pilule de biome (sélecteur arrondi avec flèches + état coloré) ──
static func make_biome_pill(biome_id: String, biome_name: String, status_text: String, col: Color) -> HBoxContainer:
	var pill: HBoxContainer = HBoxContainer.new()
	pill.add_theme_constant_override("separation", 0)
	# Left arrow
	var arrow_l: Button = Button.new()
	arrow_l.text = "◀"
	arrow_l.add_theme_font_size_override("font_size", 14)
	arrow_l.add_theme_color_override("font_color", COL_DIM)
	_style_pill_arrow(arrow_l)
	pill.add_child(arrow_l)
	arrow_l.set_meta("_pill_prev", true)
	# Center
	var center: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(COL_SURFACE.r, COL_SURFACE.g, COL_SURFACE.b, 0.85)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	center.add_theme_stylebox_override("panel", sb)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	center.add_child(hb)
	var name_l: Label = Label.new()
	name_l.text = biome_name
	name_l.add_theme_color_override("font_color", COL_CREAM)
	name_l.add_theme_font_size_override("font_size", MerlinVisual.FS_HINT)
	hb.add_child(name_l)
	name_l.set_meta("_pill_name", true)
	# Status dot + text
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = col
	hb.add_child(dot)
	dot.set_meta("_pill_dot", true)
	var status_l: Label = Label.new()
	status_l.text = status_text
	status_l.add_theme_color_override("font_color", col)
	status_l.add_theme_font_size_override("font_size", 16)
	hb.add_child(status_l)
	status_l.set_meta("_pill_status", true)
	pill.add_child(center)
	center.set_meta("_pill_center", true)
	# Right arrow
	var arrow_r: Button = Button.new()
	arrow_r.text = "▶"
	arrow_r.add_theme_font_size_override("font_size", 14)
	arrow_r.add_theme_color_override("font_color", COL_DIM)
	_style_pill_arrow(arrow_r)
	pill.add_child(arrow_r)
	arrow_r.set_meta("_pill_next", true)
	pill.set_meta("_pill_biome", biome_id)
	return pill


# ── Section titre (séparateur) ──
static func make_section_title(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COL_DIM)
	var fnt: FontFile = _load_font(FONT_UI_MED)
	if fnt != null:
		lbl.add_theme_font_override("font", fnt)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.uppercase = true
	return lbl


# ── Status bar (Gemma · local · prêt) ──
static func make_status_bar(model_name: String, status: String, ready: bool) -> HBoxContainer:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	# Status dot
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = MerlinVisual.GREEN if ready else COL_DIM
	hb.add_child(dot)
	dot.set_meta("_status_dot", true)
	var lbl: Label = Label.new()
	lbl.text = model_name + " · " + status
	lbl.add_theme_color_override("font_color", COL_DIM)
	lbl.add_theme_font_size_override("font_size", 14)
	var fnt: FontFile = _load_font(FONT_UI)
	if fnt != null:
		lbl.add_theme_font_override("font", fnt)
	hb.add_child(lbl)
	lbl.set_meta("_status_label", true)
	return hb


# ── Helpers internes ──
static func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is FontFile:
			return res as FontFile
	return null


static func _fade_node(node: Control, target_alpha: float, dur: float) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	MerlinTween.kill_for(node, "fade")
	var t: Tween = MerlinTween.retween(node, "fade")
	t.tween_property(node, "modulate:a", target_alpha, dur * MerlinVisual.motion())


static func _style_pill_arrow(btn: Button) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.custom_minimum_size = Vector2(28, 28)
	MerlinVisual.connect_button_feedback(btn)
