extends Control
## ArbreDeVie — Talent Tree full-screen UI (Phase 37)
## Visual tree layout: Racines (bottom) → Tronc → Ramures → Feuillage (top)
## Each node shows state (locked/available/unlocked), cost, and lore.

const FONT_REGULAR_PATH := "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"
const FONT_BOLD_PATH := "res://resources/fonts/morris/MorrisRomanBlack.ttf"

# Layout: branches organized by section, bottom to top
const BRANCH_ORDER := ["Corps", "Universel", "Ame", "Monde"]
const BRANCH_LABELS := {
	"Corps": "Racines (Sanglier)",
	"Universel": "Tronc (Universel)",
	"Ame": "Ramures (Corbeau)",
	"Monde": "Feuillage (Cerf)",
}

var store: Node
var font_regular: Font
var font_bold: Font
var compact_mode := false

# UI references (scene nodes)
@onready var parchment_bg: ColorRect = $ParchmentBG
@onready var main_margin: MarginContainer = $MainMargin
@onready var header_bar: HBoxContainer = $MainMargin/RootVBox/HeaderBar
@onready var title_label: Label = $MainMargin/RootVBox/HeaderBar/TitleLabel
@onready var currency_label: Label = $MainMargin/RootVBox/HeaderBar/CurrencyLabel
@onready var separator: ColorRect = $MainMargin/RootVBox/Separator
@onready var scroll: ScrollContainer = $MainMargin/RootVBox/HSplit/TreeScroll
@onready var tree_vbox: VBoxContainer = $MainMargin/RootVBox/HSplit/TreeScroll/TreeVBox
@onready var detail_panel: PanelContainer = $MainMargin/RootVBox/HSplit/DetailPanel
@onready var detail_vbox: VBoxContainer = $MainMargin/RootVBox/HSplit/DetailPanel/DetailVBox
@onready var back_button: Button = $MainMargin/RootVBox/BottomBar/BackButton

# Node buttons map for refresh
var _node_buttons: Dictionary = {}
var _selected_node_id: String = ""


func _ready() -> void:
	store = get_node_or_null("/root/MerlinStore")
	_load_fonts()
	_configure_ui()
	_refresh_tree()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	compact_mode = get_viewport_rect().size.x <= 560.0


func _load_fonts() -> void:
	font_regular = MerlinVisual.get_font("body")
	font_bold = MerlinVisual.get_font("title")
	if font_regular == null:
		font_regular = font_bold
	if font_bold == null:
		font_bold = font_regular


func _configure_ui() -> void:
	compact_mode = get_viewport_rect().size.x <= 560.0

	# CRT terminal background
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_panel

	# Compact mode margins
	var m: int = 16 if compact_mode else 28
	main_margin.add_theme_constant_override("margin_left", m)
	main_margin.add_theme_constant_override("margin_top", m)
	main_margin.add_theme_constant_override("margin_right", m)
	main_margin.add_theme_constant_override("margin_bottom", m)

	# Font + color overrides (runtime — depends on MerlinVisual)
	if font_bold:
		title_label.add_theme_font_override("font", font_bold)
	title_label.add_theme_font_size_override("font_size", 28 if not compact_mode else 22)
	title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)

	if font_regular:
		currency_label.add_theme_font_override("font", font_regular)
	currency_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	separator.color = MerlinVisual.CRT_PALETTE.line

	# Detail panel style (runtime StyleBoxFlat)
	var dp_style := StyleBoxFlat.new()
	dp_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	dp_style.border_color = MerlinVisual.CRT_PALETTE.line
	dp_style.set_border_width_all(1)
	dp_style.corner_radius_top_left = 6
	dp_style.corner_radius_top_right = 6
	dp_style.corner_radius_bottom_left = 6
	dp_style.corner_radius_bottom_right = 6
	dp_style.content_margin_left = 12
	dp_style.content_margin_top = 12
	dp_style.content_margin_right = 12
	dp_style.content_margin_bottom = 12
	detail_panel.add_theme_stylebox_override("panel", dp_style)

	# Back button
	if font_regular:
		back_button.add_theme_font_override("font", font_regular)
	_style_button(back_button)
	back_button.pressed.connect(func():
		PixelTransition.transition_to("res://scenes/HubAntre.tscn")
	)


func _refresh_tree() -> void:
	"""Rebuild the tree nodes and update currency display."""
	_update_currency_label()
	_build_tree_nodes()
	_update_detail_panel()


func _update_currency_label() -> void:
	if not store:
		currency_label.text = "Store non disponible"
		return
	var meta: Dictionary = store.state.get("meta", {})
	var fragments: int = int(meta.get("ogham_fragments", 0))
	var unlocked: int = meta.get("talent_tree", {}).get("unlocked", []).size()

	# Show top essences
	var essence: Dictionary = meta.get("essence", {})
	var top_essences: Array = []
	for elem in ["TERRE", "NATURE", "ESPRIT", "LUMIERE", "FEU", "OMBRE"]:
		var val: int = int(essence.get(elem, 0))
		if val > 0:
			top_essences.append("%s:%d" % [elem.left(3), val])

	var ess_text: String = " | ".join(top_essences) if not top_essences.is_empty() else "Aucune essence"
	currency_label.text = "Fragments: %d | Talents: %d/28\n%s" % [fragments, unlocked, ess_text]


func _build_tree_nodes() -> void:
	"""Build the visual tree organized by branch (bottom to top)."""
	# Clear existing
	for child in tree_vbox.get_children():
		child.queue_free()
	_node_buttons.clear()

	# Build from bottom (Racines) to top (Feuillage)
	for branch in BRANCH_ORDER:
		var branch_label_text: String = BRANCH_LABELS.get(branch, branch)
		var branch_color: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(branch, MerlinVisual.CRT_PALETTE.phosphor)

		# Branch header
		var header := Label.new()
		header.text = branch_label_text
		if font_bold:
			header.add_theme_font_override("font", font_bold)
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", branch_color)
		tree_vbox.add_child(header)

		# Collect nodes for this branch, grouped by tier
		var tiers: Dictionary = {}
		for node_id in MerlinConstants.TALENT_NODES:
			var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
			if str(node.get("branch", "")) != branch:
				continue
			var tier: int = int(node.get("tier", 1))
			if not tiers.has(tier):
				tiers[tier] = []
			tiers[tier].append(node_id)

		# Sort tiers ascending
		var tier_keys: Array = tiers.keys()
		tier_keys.sort()

		for tier in tier_keys:
			var tier_name: String = str(MerlinConstants.TALENT_TIER_NAMES.get(tier, "Tier %d" % tier))

			# Tier label
			var tier_lbl := Label.new()
			tier_lbl.text = "  %s (Tier %d)" % [tier_name, tier]
			if font_regular:
				tier_lbl.add_theme_font_override("font", font_regular)
			tier_lbl.add_theme_font_size_override("font_size", 11)
			tier_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
			tree_vbox.add_child(tier_lbl)

			# Nodes row
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			tree_vbox.add_child(row)

			var node_ids: Array = tiers[tier]
			for node_id in node_ids:
				var btn := _create_talent_button(node_id, branch_color)
				row.add_child(btn)
				_node_buttons[node_id] = btn

		# Separator between branches
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(0, 1)
		sep.color = MerlinVisual.CRT_PALETTE.line
		tree_vbox.add_child(sep)


func _create_talent_button(node_id: String, branch_color: Color) -> Button:
	"""Create a styled button for a single talent node."""
	var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
	var name_val: String = str(node.get("name", node_id))
	var is_unlocked: bool = store.is_talent_active(node_id) if store else false
	var is_available: bool = store.can_unlock_talent(node_id) if store else false

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100 if compact_mode else 120, 52)
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if is_unlocked:
		btn.text = "\u2713 %s" % name_val  # Checkmark
	else:
		btn.text = name_val

	if font_regular:
		btn.add_theme_font_override("font", font_regular)
	btn.add_theme_font_size_override("font_size", 11)

	# Styling based on state
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	if is_unlocked:
		normal.bg_color = branch_color.lerp(MerlinVisual.CRT_PALETTE.bg_panel, 0.5)
		normal.border_color = branch_color
		normal.set_border_width_all(2)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	elif is_available:
		normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
		normal.border_color = MerlinVisual.CRT_PALETTE.phosphor_glow
		normal.set_border_width_all(2)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	else:
		normal.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
		normal.border_color = MerlinVisual.CRT_PALETTE.locked
		normal.set_border_width_all(1)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.border_color = MerlinVisual.CRT_PALETTE.amber

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	# Tooltip
	btn.tooltip_text = _get_talent_tooltip(node_id)

	# Click handler
	btn.pressed.connect(_on_talent_clicked.bind(node_id))

	return btn


func _get_talent_tooltip(node_id: String) -> String:
	var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
	var name_val: String = str(node.get("name", node_id))
	var desc: String = str(node.get("description", ""))
	var cost: Dictionary = node.get("cost", {})
	var prereqs: Array = node.get("prerequisites", [])

	var lines: Array = [name_val, desc]

	# Cost
	var cost_parts: Array = []
	for c in cost:
		cost_parts.append("%s: %d" % [c, int(cost[c])])
	if not cost_parts.is_empty():
		lines.append("Cout: %s" % ", ".join(cost_parts))

	# Prerequisites
	if not prereqs.is_empty():
		var prereq_names: Array = []
		for p in prereqs:
			var pn: Dictionary = MerlinConstants.TALENT_NODES.get(p, {})
			prereq_names.append(str(pn.get("name", p)))
		lines.append("Requiert: %s" % ", ".join(prereq_names))

	return "\n".join(lines)


func _on_talent_clicked(node_id: String) -> void:
	_selected_node_id = node_id
	_update_detail_panel()
	detail_panel.visible = true


func _update_detail_panel() -> void:
	"""Update the right-side detail panel with selected node info."""
	# Clear
	for child in detail_vbox.get_children():
		child.queue_free()

	if _selected_node_id == "":
		detail_panel.visible = false
		return

	var node: Dictionary = MerlinConstants.TALENT_NODES.get(_selected_node_id, {})
	if node.is_empty():
		detail_panel.visible = false
		return

	var name_val: String = str(node.get("name", _selected_node_id))
	var branch: String = str(node.get("branch", ""))
	var desc: String = str(node.get("description", ""))
	var lore: String = str(node.get("lore", ""))
	var cost: Dictionary = node.get("cost", {})
	var prereqs: Array = node.get("prerequisites", [])
	var is_unlocked: bool = store.is_talent_active(_selected_node_id) if store else false
	var is_available: bool = store.can_unlock_talent(_selected_node_id) if store else false
	var branch_color: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(branch, MerlinVisual.CRT_PALETTE.phosphor)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = name_val
	if font_bold:
		name_lbl.add_theme_font_override("font", font_bold)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", branch_color)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_vbox.add_child(name_lbl)

	# Branch + tier
	var tier_name: String = str(MerlinConstants.TALENT_TIER_NAMES.get(int(node.get("tier", 1)), ""))
	var branch_lbl := Label.new()
	branch_lbl.text = "%s — %s" % [branch, tier_name]
	if font_regular:
		branch_lbl.add_theme_font_override("font", font_regular)
	branch_lbl.add_theme_font_size_override("font_size", 11)
	branch_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	detail_vbox.add_child(branch_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	if font_regular:
		desc_lbl.add_theme_font_override("font", font_regular)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_vbox.add_child(desc_lbl)

	# Lore (italic feel via color)
	if lore != "":
		var lore_lbl := Label.new()
		lore_lbl.text = "\"%s\"" % lore
		if font_regular:
			lore_lbl.add_theme_font_override("font", font_regular)
		lore_lbl.add_theme_font_size_override("font_size", 11)
		lore_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border)
		lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		detail_vbox.add_child(lore_lbl)

	# Cost breakdown
	var cost_header := Label.new()
	cost_header.text = "Cout:"
	if font_bold:
		cost_header.add_theme_font_override("font", font_bold)
	cost_header.add_theme_font_size_override("font_size", 12)
	cost_header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	detail_vbox.add_child(cost_header)

	var meta: Dictionary = store.state.get("meta", {}) if store else {}
	var essence: Dictionary = meta.get("essence", {})
	var fragments: int = int(meta.get("ogham_fragments", 0))

	for c in cost:
		var needed: int = int(cost[c])
		var have: int = 0
		if c == "fragments":
			have = fragments
		else:
			have = int(essence.get(c, 0))
		var enough: bool = have >= needed
		var cost_line := Label.new()
		cost_line.text = "  %s: %d / %d" % [c, have, needed]
		if font_regular:
			cost_line.add_theme_font_override("font", font_regular)
		cost_line.add_theme_font_size_override("font_size", 11)
		var cost_color: Color = MerlinVisual.CRT_PALETTE["success"] if enough else MerlinVisual.CRT_PALETTE["danger"]
		cost_line.add_theme_color_override("font_color", cost_color)
		detail_vbox.add_child(cost_line)

	# Prerequisites
	if not prereqs.is_empty():
		var prereq_header := Label.new()
		prereq_header.text = "Prerequis:"
		if font_bold:
			prereq_header.add_theme_font_override("font", font_bold)
		prereq_header.add_theme_font_size_override("font_size", 12)
		prereq_header.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		detail_vbox.add_child(prereq_header)

		for p in prereqs:
			var pn: Dictionary = MerlinConstants.TALENT_NODES.get(p, {})
			var p_name: String = str(pn.get("name", p))
			var p_unlocked: bool = store.is_talent_active(p) if store else false
			var prereq_lbl := Label.new()
			prereq_lbl.text = "  %s %s" % ["\u2713" if p_unlocked else "\u2717", p_name]
			if font_regular:
				prereq_lbl.add_theme_font_override("font", font_regular)
			prereq_lbl.add_theme_font_size_override("font_size", 11)
			var prereq_color: Color = MerlinVisual.CRT_PALETTE["success"] if p_unlocked else MerlinVisual.CRT_PALETTE["danger"]
			prereq_lbl.add_theme_color_override("font_color", prereq_color)
			detail_vbox.add_child(prereq_lbl)

	# Status + Action button
	var status_lbl := Label.new()
	if is_unlocked:
		status_lbl.text = "\u2713 Debloque"
		status_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	elif is_available:
		status_lbl.text = "Disponible"
		status_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	else:
		status_lbl.text = "Verrouille"
		status_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.locked)
	if font_bold:
		status_lbl.add_theme_font_override("font", font_bold)
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(status_lbl)

	# Unlock button (only if available)
	if is_available and not is_unlocked:
		var unlock_btn := Button.new()
		unlock_btn.text = "Debloquer"
		unlock_btn.custom_minimum_size = Vector2(0, 36)
		if font_bold:
			unlock_btn.add_theme_font_override("font", font_bold)
		unlock_btn.add_theme_font_size_override("font_size", 14)
		_style_button(unlock_btn, MerlinVisual.CRT_PALETTE.success)
		unlock_btn.pressed.connect(_on_unlock_pressed.bind(_selected_node_id))
		detail_vbox.add_child(unlock_btn)


func _on_unlock_pressed(node_id: String) -> void:
	"""Unlock a talent node via the store."""
	if not store:
		return

	var result: Dictionary = store.unlock_talent(node_id)
	if result.get("ok", false):
		var name_val: String = str(result.get("name", node_id))
		print("[ARBRE] Talent debloque: %s" % name_val)
		var sfx: Node = get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("skill_unlock")
		_refresh_tree()
	else:
		print("[ARBRE] Echec: %s" % str(result.get("error", "")))


func _style_button(btn: Button, accent_color: Color = Color.TRANSPARENT) -> void:
	var color: Color = accent_color if accent_color.a > 0.1 else MerlinVisual.CRT_PALETTE.amber_dim
	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	hover.border_color = color.lightened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	btn.add_theme_color_override("font_hover_color", color)
