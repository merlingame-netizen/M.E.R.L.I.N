## ═══════════════════════════════════════════════════════════════════════════════
## UI Config Module — Dynamic node creation and theming
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles _configure_ui() and
## _apply_label_theming() so the main file stays under 800 lines.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIConfigModule

var _ui: MerlinGameUI


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


## Main configuration — creates dynamic nodes, applies styling, wires signals.
## Called once from _ready() after all modules are initialized.
func configure_ui() -> void:
	# Fonts
	_ui.title_font = MerlinVisual.get_font("title")
	_ui.body_font = MerlinVisual.get_font("body")
	if _ui.body_font == null:
		_ui.body_font = _ui.title_font

	# Background transparent
	_ui.parchment_bg.material = null
	_ui.parchment_bg.color = Color(0.0, 0.0, 0.0, 0.0)

	# Clock panel
	_ui._status_clock_panel.add_theme_stylebox_override("panel", MerlinVisual.make_clock_panel_style())
	_ui._status_clock_timer.timeout.connect(_ui._status_bar.update_clock_status)
	_ui._status_bar.update_clock_status()

	# Card panel styling
	_ui.card_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_panel_style())
	_ui.card_panel.pivot_offset = Vector2(320, 200)
	_ui.card_panel.clip_contents = true
	if _ui.card_container and is_instance_valid(_ui.card_container):
		_ui.card_container.clip_contents = true
	_ui._card_illustration_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_illustration_style())
	_ui._card_body_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_body_style())
	var ink_bg: Color = MerlinVisual.CRT_PALETTE.phosphor
	_ui._illo_bg.color = Color(ink_bg.r, ink_bg.g, ink_bg.b, 0.95)

	# Dynamic nodes: scene compositor
	_setup_scene_compositor()

	# Portraits suppressed
	_ui._pixel_portrait = null
	_ui._npc_portrait = null
	if _ui._portrait_center and is_instance_valid(_ui._portrait_center):
		_ui._portrait_center.visible = false

	# LLM source badge
	_ui._card_source_badge = LLMSourceBadge.create("static")
	_ui._card_source_badge.visible = false
	_ui._card_body_vbox.add_child(_ui._card_source_badge)

	# Option buttons
	_setup_option_buttons()

	# Action description labels
	_setup_desc_labels()

	# What-if labels
	_setup_what_if_labels()

	# Minigame badge
	_setup_minigame_badge()

	# Reward badge
	_ui._reward_badge = MerlinRewardBadge.new()
	_ui.add_child(_ui._reward_badge)

	# Perk badge
	_setup_perk_badge()

	# Dialogue button (hidden)
	_setup_dialogue_button()

	# Dialogue bubble
	_ui._dialogue_bubble = MerlinBubble.new()
	_ui._dialogue_bubble.name = "DialogueBubble"
	_ui._dialogue_bubble.z_index = 25
	_ui.add_child(_ui._dialogue_bubble)

	# Biome indicator
	_ui.biome_indicator = Label.new()
	_ui.biome_indicator.visible = false

	# Apply font/color theming
	_apply_label_theming()

	# Dynamic deck stacks + layout
	_ui._deck_module.build_remaining_deck_stack()
	_ui._deck_module.build_discard_stack()
	_ui._ui_blocks_for_intro = [_ui._top_status_bar, _ui.options_container, _ui._pioche_column, _ui._cimetiere_column]
	_ui._layout_run_zones()
	_ui.call_deferred("_layout_card_stage")


func _setup_scene_compositor() -> void:
	if MerlinVisual.USE_LAYERED_SPRITES:
		_ui._scene_compositor_v2 = MerlinGameUI.CardSceneCompositorClass.new()
		_ui._scene_compositor_v2.name = "LayeredCompositor"
		_ui._scene_compositor_v2.setup(MerlinVisual.LAYER_ILLUSTRATION_SIZE)
		_ui._tile_center.add_child(_ui._scene_compositor_v2)
	else:
		_ui._scene_compositor = MerlinGameUI.PixelSceneCompositor.new()
		_ui._scene_compositor.name = "SceneCompositor"
		_ui._scene_compositor.setup(220.0)
		_ui._tile_center.add_child(_ui._scene_compositor)


func _setup_option_buttons() -> void:
	_ui.option_buttons = [_ui._btn_a, _ui._btn_b, _ui._btn_c]
	var option_configs: Array[Dictionary] = [
		{"key": "A", "color": MerlinVisual.CRT_PALETTE.phosphor},
		{"key": "B", "color": MerlinVisual.CRT_PALETTE.amber},
		{"key": "C", "color": MerlinVisual.CRT_PALETTE.danger},
	]
	# Touch-friendly minimum height
	var mr: Node = Engine.get_main_loop().root.get_node_or_null("MerlinResponsive") if Engine.get_main_loop() else null
	var btn_min_h: int = 80
	if mr:
		btn_min_h = maxi(btn_min_h, MerlinVisual.MIN_TOUCH_TARGET)
		if mr.is_mobile:
			btn_min_h = maxi(btn_min_h, 56)
	for i in range(3):
		var btn: Button = _ui.option_buttons[i]
		MerlinVisual.apply_celtic_option_theme(btn, option_configs[i]["color"])
		btn.pressed.connect(_ui._options_module.on_option_pressed.bind(i))
		btn.mouse_entered.connect(_ui._options_module.on_option_hover_enter.bind(i))
		btn.mouse_exited.connect(_ui._options_module.on_option_hover_exit)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, btn_min_h)
		btn.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mr:
			mr.apply_touch_margins(btn)

	if _ui.options_container and is_instance_valid(_ui.options_container):
		_ui.options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ui.options_container.add_theme_constant_override("separation", 10)

	if _ui._bottom_zone and is_instance_valid(_ui._bottom_zone):
		_ui._bottom_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	if _ui.options_container and is_instance_valid(_ui.options_container):
		_ui.options_container.mouse_filter = Control.MOUSE_FILTER_PASS


func _setup_desc_labels() -> void:
	var desc_color: Color = MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.20, 1.00, 0.40))
	_ui._option_desc_labels.clear()
	for i2 in range(3):
		var desc_lbl: Label = Label.new()
		desc_lbl.name = "DescLabel%s" % ["A", "B", "C"][i2]
		if _ui.body_font:
			desc_lbl.add_theme_font_override("font", _ui.body_font)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", desc_color)
		desc_lbl.custom_minimum_size = Vector2(0, 18)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.visible = false
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var parent_vbox: Control = _ui.option_buttons[i2].get_parent()
		parent_vbox.add_child(desc_lbl)
		parent_vbox.move_child(desc_lbl, 0)
		_ui._option_desc_labels.append(desc_lbl)


func _setup_what_if_labels() -> void:
	var whatif_color: Color = MerlinVisual.CRT_PALETTE.get("phosphor_dim", Color(0.45, 0.4, 0.35))
	_ui._what_if_labels.clear()
	for i3 in range(3):
		var wif_lbl: Label = Label.new()
		wif_lbl.name = "WhatIfLabel%s" % ["A", "B", "C"][i3]
		if _ui.body_font:
			wif_lbl.add_theme_font_override("font", _ui.body_font)
		wif_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_TINY)
		wif_lbl.add_theme_color_override("font_color", whatif_color)
		wif_lbl.custom_minimum_size = Vector2(0, 0)
		wif_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wif_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		wif_lbl.visible = false
		wif_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wif_parent: Control = _ui.option_buttons[i3].get_parent()
		wif_parent.add_child(wif_lbl)
		_ui._what_if_labels.append(wif_lbl)


func _setup_minigame_badge() -> void:
	_ui._minigame_badge = Label.new()
	_ui._minigame_badge.name = "MinigameBadge"
	if _ui.body_font:
		_ui._minigame_badge.add_theme_font_override("font", _ui.body_font)
	_ui._minigame_badge.add_theme_font_size_override("font_size", 11)
	_ui._minigame_badge.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	_ui._minigame_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui._minigame_badge.visible = false
	_ui._card_body_vbox.add_child(_ui._minigame_badge)


func _setup_perk_badge() -> void:
	_ui._perk_badge = Label.new()
	_ui._perk_badge.name = "PerkBadge"
	_ui._perk_badge.text = ""
	_ui._perk_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui._perk_badge.add_theme_font_size_override("font_size", 9)
	_ui._perk_badge.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	_ui._perk_badge.visible = false
	_ui._perk_badge.z_index = 20
	_ui.add_child(_ui._perk_badge)


func _setup_dialogue_button() -> void:
	_ui._dialogue_btn = Button.new()
	_ui._dialogue_btn.name = "DialogueBtn"
	_ui._dialogue_btn.text = "Parler"
	_ui._dialogue_btn.custom_minimum_size = Vector2(72, 36)
	_ui._dialogue_btn.tooltip_text = "Parler a Merlin"
	MerlinVisual.apply_celtic_option_theme(_ui._dialogue_btn, MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13)))
	_ui._dialogue_btn.z_index = 20
	_ui._dialogue_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui._dialogue_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	_ui.add_child(_ui._dialogue_btn)
	_ui._dialogue_btn.visible = false


func _apply_label_theming() -> void:
	# Hide redundant titles
	for lbl: Label in [
		_ui.get_node("MainVBox/TopStatusBar/LifePanel/LifeTitle"),
		_ui.get_node("MainVBox/TopStatusBar/EssencePanel/EssenceTitle"),
	]:
		lbl.visible = false

	# Life counter
	_ui._life_counter.text = "%d/%d" % [MerlinConstants.LIFE_ESSENCE_START, MerlinConstants.LIFE_ESSENCE_MAX]
	if _ui.body_font:
		_ui._life_counter.add_theme_font_override("font", _ui.body_font)
	_ui._life_counter.add_theme_font_size_override("font_size", 16)
	_ui._life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)

	# Essence counter
	if _ui.body_font:
		_ui._essence_counter.add_theme_font_override("font", _ui.body_font)
	_ui._essence_counter.add_theme_font_size_override("font_size", 16)
	_ui._essence_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)

	# Essence caption
	var caption: Label = _ui.get_node("MainVBox/TopStatusBar/EssencePanel/EssenceCaption")
	if _ui.body_font:
		caption.add_theme_font_override("font", _ui.body_font)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	# Clock label
	_ui._status_clock_label.add_theme_font_size_override("font_size", 15)
	_ui._status_clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	if _ui.body_font:
		_ui._status_clock_label.add_theme_font_override("font", _ui.body_font)

	# Pioche + Cimetiere titles
	for lbl: Label in [
		_ui.get_node("MainVBox/MiddleZone/PiocheColumn/PiocheTitle"),
		_ui.get_node("MainVBox/MiddleZone/CimetiereColumn/CimetiereTitle"),
	]:
		if _ui.title_font:
			lbl.add_theme_font_override("font", _ui.title_font)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

	# Deck + discard count labels
	for lbl: Label in [_ui._remaining_deck_label, _ui._discard_label]:
		if _ui.body_font:
			lbl.add_theme_font_override("font", _ui.body_font)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

	# Card title
	_ui._card_title_label = Label.new()
	_ui._card_title_label.name = "CardTitle"
	_ui._card_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui._card_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _ui.title_font:
		_ui._card_title_label.add_theme_font_override("font", _ui.title_font)
	_ui._card_title_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_LARGE)
	_ui._card_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_ui._card_title_label.visible = false
	if _ui._card_body_vbox and is_instance_valid(_ui._card_body_vbox):
		_ui._card_body_vbox.add_child(_ui._card_title_label)
		_ui._card_body_vbox.move_child(_ui._card_title_label, 0)

	# Card speaker
	if _ui.title_font:
		_ui.card_speaker.add_theme_font_override("font", _ui.title_font)
	_ui.card_speaker.add_theme_font_size_override("font_size", 17)
	_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)

	# Card text
	if _ui.body_font:
		_ui.card_text.add_theme_font_override("normal_font", _ui.body_font)
	_ui.card_text.add_theme_font_size_override("normal_font_size", 15)
	_ui.card_text.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	_ui.card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Option buttons font
	for btn: Button in _ui.option_buttons:
		if _ui.title_font:
			btn.add_theme_font_override("font", _ui.title_font)
		btn.add_theme_font_size_override("font_size", 17)

	# Info panel labels
	for lbl: Label in [_ui.mission_label, _ui.cards_label]:
		if _ui.body_font:
			lbl.add_theme_font_override("font", _ui.body_font)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
