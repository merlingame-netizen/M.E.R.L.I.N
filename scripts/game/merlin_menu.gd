extends Control
## MerlinMenu — écran-titre, DA flat rétro-minimaliste (mockup validé 2026-05-26).
## Gauche : wordmark M·E·R·L·I·N + filet/triskèle + rangée de runes + liste à icônes (focus or).
## Droite : scène en silhouettes (MerlinSceneArt). Coins : émblèmes-anneaux. Bas : barre ornementale.

const COL_BG: Color = Color("1E1A14")
const COL_CREAM: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_DIM: Color = Color("6E5A3C")
const COL_GREEN: Color = Color("7FA65C")
const COL_VIOLET: Color = Color("7B4FA3")

const SELECTION_SCENE: String = "res://scenes/MerlinSelection.tscn"
const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const OPTIONS_SCENE: String = "res://scenes/MerlinOptions.tscn"

var _rows: Array = []  # [{btn, glyph, lbl, disc, key}]


func _ready() -> void:
	_build_ui()
	# Le LLM chauffe + pré-génère les 3 scénarios DÈS le menu (avant le clic Nouvelle Partie).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.is_ready():
			_trigger_warmup()
		elif not mn.model_ready.is_connected(_trigger_warmup):
			mn.model_ready.connect(_trigger_warmup)


func _trigger_warmup() -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null:
		sc.warmup_and_prefetch_selection()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- Scène en silhouettes à droite (~58%) ---
	var scene: MerlinSceneArt = MerlinSceneArt.new()
	scene.anchor_left = 0.42
	scene.anchor_right = 1.0
	scene.anchor_top = 0.0
	scene.anchor_bottom = 1.0
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	scene.set_menu_decor(true)
	scene.set_beat("Rencontre")  # figure encapuchonnée devant la lune

	# --- Colonne gauche ---
	var left: VBoxContainer = VBoxContainer.new()
	left.anchor_left = 0.0
	left.anchor_top = 0.0
	left.anchor_right = 0.42
	left.anchor_bottom = 1.0
	left.offset_left = 56
	left.offset_top = 64
	left.offset_right = -16
	left.offset_bottom = -70
	left.add_theme_constant_override("separation", 10)
	add_child(left)

	var title: Label = Label.new()
	title.text = "M·E·R·L·I·N"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 64)
	left.add_child(title)

	# Filet + triskèle.
	var rule: HBoxContainer = HBoxContainer.new()
	rule.add_theme_constant_override("separation", 8)
	rule.custom_minimum_size = Vector2(0, 22)
	rule.add_child(_hline())
	var tris: MerlinGlyph = _icon("triskele", COL_GOLD, Vector2(22, 22), 1.6)
	rule.add_child(tris)
	rule.add_child(_hline())
	left.add_child(rule)

	# Rangée de runes décoratives.
	var runes: HBoxContainer = HBoxContainer.new()
	runes.add_theme_constant_override("separation", 16)
	for k in ["rune", "triskele", "burst", "spark", "rift"]:
		runes.add_child(_icon(k, COL_DIM, Vector2(20, 22), 1.5))
	left.add_child(runes)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	left.add_child(gap)

	# Liste de menu.
	var has_save: bool = get_node("/root/MerlinRun").has_save()
	var menu: VBoxContainer = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	left.add_child(menu)
	menu.add_child(_menu_row("spark", "CONTINUER", _on_continue, has_save))
	menu.add_child(_menu_row("burst", "NOUVELLE PARTIE", _on_new, true))
	menu.add_child(_menu_row("book", "CHRONIQUES", Callable(), false))
	menu.add_child(_menu_row("cards", "CARTES", Callable(), false))
	menu.add_child(_menu_row("target", "OPTIONS", _on_options, true))
	menu.add_child(_menu_row("cross", "QUITTER", _on_quit, true))

	# Émblèmes des coins (anneaux partiels + glyphe), comme le mockup.
	_corner_emblem("leaf", COL_GREEN, true)
	_corner_emblem("tree", COL_VIOLET, false)

	_build_bottom_bar()

	# Focus initial : CONTINUER si sauvegarde, sinon NOUVELLE PARTIE.
	var first_idx: int = 0 if has_save else 1
	(_rows[first_idx]["btn"] as Button).call_deferred("grab_focus")


func _menu_row(glyph_key: String, label_txt: String, cb: Callable, enabled: bool) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(520, 66)  # ≥44px (tactile) — agrandi (user 2026-06-06)
	btn.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	btn.disabled = not enabled
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	# Icône dans un disque (disque or plein si sélectionné).
	var icon_box: Control = Control.new()
	icon_box.custom_minimum_size = Vector2(52, 52)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _disc_style(false))
	icon_box.add_child(disc)
	var g: MerlinGlyph = MerlinGlyph.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_left = 9
	g.offset_top = 9
	g.offset_right = -9
	g.offset_bottom = -9
	g.setup(glyph_key, COL_DIM, 1.8)
	icon_box.add_child(g)
	row.add_child(icon_box)

	var lbl: Label = Label.new()
	lbl.text = _spaced(label_txt)
	lbl.add_theme_color_override("font_color", COL_CREAM if enabled else COL_DIM)
	lbl.add_theme_font_size_override("font_size", 27)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var line: ColorRect = _hline()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	row.add_child(_diamond())

	var data: Dictionary = {"btn": btn, "glyph": g, "lbl": lbl, "disc": disc, "key": glyph_key}
	_rows.append(data)
	if enabled:
		if cb.is_valid():
			btn.pressed.connect(cb)
		btn.focus_entered.connect(_on_row_focus.bind(data, true))
		btn.focus_exited.connect(_on_row_focus.bind(data, false))
		btn.mouse_entered.connect(btn.grab_focus)  # survol = focus (highlight unifié)
	return btn


func _on_row_focus(data: Dictionary, on: bool) -> void:
	(data["disc"] as Panel).add_theme_stylebox_override("panel", _disc_style(on))
	(data["glyph"] as MerlinGlyph).setup(str(data["key"]), COL_BG if on else COL_DIM, 1.8)
	(data["lbl"] as Label).add_theme_color_override("font_color", COL_GOLD if on else COL_CREAM)


func _disc_style(selected: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	if selected:
		sb.bg_color = COL_GOLD
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = COL_DIM
	return sb


func _corner_emblem(glyph_key: String, col: Color, is_left: bool) -> void:
	var box: Control = Control.new()
	box.custom_minimum_size = Vector2(64, 64)
	box.size = Vector2(64, 64)
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	box.offset_top = 22
	box.offset_bottom = 86
	if is_left:
		box.anchor_left = 0.0
		box.anchor_right = 0.0
		box.offset_left = 28
		box.offset_right = 92
	else:
		box.anchor_left = 1.0
		box.anchor_right = 1.0
		box.offset_left = -92
		box.offset_right = -28
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var ring: MerlinRingGauge = MerlinRingGauge.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.setup(col)
	box.add_child(ring)
	ring.set_ratio(0.4)
	var g: MerlinGlyph = MerlinGlyph.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.offset_left = 16
	g.offset_top = 16
	g.offset_right = -16
	g.offset_bottom = -16
	g.setup(glyph_key, col, 1.8)
	box.add_child(g)


func _build_bottom_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 36
	bar.offset_right = -36
	bar.offset_top = -56
	bar.offset_bottom = -22
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)

	bar.add_child(_icon("crown", COL_GOLD, Vector2(24, 24), 1.6))
	bar.add_child(_dots(3))
	var sp1: Control = Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp1)
	bar.add_child(_hline())
	bar.add_child(_icon("compass", COL_GOLD, Vector2(28, 28), 1.6))
	bar.add_child(_hline())
	var sp2: Control = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp2)
	bar.add_child(_dots(3))
	bar.add_child(_icon("eye", COL_GOLD, Vector2(24, 24), 1.6))


func _icon(glyph_key: String, col: Color, sz: Vector2, w: float) -> MerlinGlyph:
	var g: MerlinGlyph = MerlinGlyph.new()
	g.custom_minimum_size = sz
	g.setup(glyph_key, col, w)
	return g


func _hline() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = COL_DIM
	r.custom_minimum_size = Vector2(24, 1)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _diamond() -> Control:
	var d: Panel = Panel.new()
	d.custom_minimum_size = Vector2(8, 8)
	d.size = Vector2(8, 8)
	d.pivot_offset = Vector2(4, 4)
	d.rotation = deg_to_rad(45)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_DIM
	d.add_theme_stylebox_override("panel", sb)
	return d


func _dots(n: int) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in n:
		var d: Panel = Panel.new()
		d.custom_minimum_size = Vector2(6, 6)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = COL_DIM
		sb.set_corner_radius_all(3)
		d.add_theme_stylebox_override("panel", sb)
		h.add_child(d)
	return h


func _spaced(s: String) -> String:
	var out: String = ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out


func _on_new() -> void:
	MerlinTransition.change_scene(SELECTION_SCENE)


func _on_continue() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.has_save() and run.load_run():
		MerlinTransition.change_scene(GAME_SCENE)


func _on_options() -> void:
	if ResourceLoader.exists(OPTIONS_SCENE):
		MerlinTransition.change_scene(OPTIONS_SCENE)


func _on_quit() -> void:
	get_tree().quit()
