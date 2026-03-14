class_name TutorialCardLayer
extends Control

## Tutorial Card Layer — Scripted 3-card express playthrough (v2.5)
## Deterministic, no LLM, effects visible (tutorial mode).
## Uses TutorialManager.TUTORIAL_CARDS with v2.5 mechanics:
## - Life bar (single bar, 0-100)
## - Faction reputation (5 factions)
## - Effects: HEAL_LIFE, DAMAGE_LIFE, ADD_REPUTATION

signal playthrough_complete

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const CARD_MAX_W := 560.0
const OPTION_STAGGER := 0.12
const TYPEWRITER_DELAY := 0.018
const TYPEWRITER_PUNCT := 0.050

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _life: int = MerlinConstants.LIFE_ESSENCE_START
var _life_max: int = MerlinConstants.LIFE_ESSENCE_MAX
var _faction_rep: Dictionary = {"druides": 0.0, "anciens": 0.0, "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0}
var _card_idx: int = 0
var _choice_made: int = -1
var _skip_requested: bool = false

# Nodes
var _card_panel: PanelContainer
var _title_label: Label
var _text_label: Label
var _life_bar: ProgressBar
var _life_label: Label
var _option_buttons: Array[Button] = []
var _effect_labels: Array[Label] = []
var _merlin_label: Label
var _continue_hint: Label

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_run_sequence.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_skip_requested = true
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Life bar at top
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 16.0
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.custom_minimum_size.y = 32.0

	_life_label = Label.new()
	_life_label.text = "PV: %d/%d" % [_life, _life_max]
	_life_label.add_theme_font_size_override("font_size", 16)
	_life_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	top_bar.add_child(_life_label)

	_life_bar = ProgressBar.new()
	_life_bar.min_value = 0
	_life_bar.max_value = _life_max
	_life_bar.value = _life
	_life_bar.show_percentage = false
	_life_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_life_bar.custom_minimum_size.y = 20.0
	top_bar.add_child(_life_bar)

	# Card panel centered
	_card_panel = PanelContainer.new()
	_card_panel.add_theme_stylebox_override("panel", MerlinVisual.make_modal_style(true))
	add_child(_card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_card_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", MerlinVisual.get_font("title"))
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(_title_label)

	# Separator
	var sep := Label.new()
	sep.text = "--- # ---"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	sep.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border_bright)
	vbox.add_child(sep)

	# Main text
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_text_label.add_theme_font_size_override("font_size", MerlinVisual.BODY_SIZE)
	_text_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_text_label.custom_minimum_size.x = 400.0
	vbox.add_child(_text_label)

	# Options container
	var options_box := VBoxContainer.new()
	options_box.name = "OptionsBox"
	options_box.add_theme_constant_override("separation", 6)
	add_child(options_box)

	# 3 option slots
	for i in 3:
		var option_row := VBoxContainer.new()
		option_row.add_theme_constant_override("separation", 2)
		options_box.add_child(option_row)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", MerlinVisual.get_font("body"))
		btn.add_theme_font_size_override("font_size", MerlinVisual.BODY_SMALL)
		var accent: Color = _get_option_accent(i)
		MerlinVisual.apply_celtic_option_theme(btn, accent)
		var idx := i
		btn.pressed.connect(func() -> void: _on_option_pressed(idx))
		option_row.add_child(btn)
		_option_buttons.append(btn)

		var eff_label := Label.new()
		eff_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_TINY)
		eff_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
		eff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		option_row.add_child(eff_label)
		_effect_labels.append(eff_label)

	# Merlin reaction
	_merlin_label = Label.new()
	_merlin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_merlin_label.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_merlin_label.add_theme_font_size_override("font_size", MerlinVisual.BODY_SMALL)
	_merlin_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.cyan)
	_merlin_label.visible = false
	add_child(_merlin_label)

	# Continue hint
	_continue_hint = Label.new()
	_continue_hint.text = "[espace] Continuer"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_hint.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	_continue_hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_continue_hint.visible = false
	add_child(_continue_hint)

	_layout_ui()


func _layout_ui() -> void:
	var vp: Vector2 = size
	if vp.x < 1.0:
		vp = get_viewport().get_visible_rect().size

	var card_w: float = minf(CARD_MAX_W, vp.x * 0.85)
	_card_panel.position = Vector2((vp.x - card_w) * 0.5, 70.0)
	_card_panel.size = Vector2(card_w, 0)

	var opts: Node = get_node_or_null("OptionsBox")
	if opts:
		var opt_w: float = minf(420.0, vp.x * 0.75)
		opts.position = Vector2((vp.x - opt_w) * 0.5, _card_panel.position.y + _card_panel.size.y + 20.0)
		opts.size = Vector2(opt_w, 0)
		for btn: Button in _option_buttons:
			btn.custom_minimum_size.x = opt_w

	_merlin_label.position = Vector2((vp.x - 400.0) * 0.5, vp.y - 120.0)
	_merlin_label.size = Vector2(400.0, 60.0)
	_continue_hint.position = Vector2(0, vp.y - 40.0)
	_continue_hint.size = Vector2(vp.x, 30.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _card_panel:
			_layout_ui()


# ═══════════════════════════════════════════════════════════════════════════════
# CARD SEQUENCE — Uses TutorialManager.TUTORIAL_CARDS
# ═══════════════════════════════════════════════════════════════════════════════

func _run_sequence() -> void:
	await get_tree().process_frame
	_layout_ui()

	for i in TutorialManager.TUTORIAL_CARDS.size():
		if _skip_requested:
			break
		_card_idx = i
		await _present_card(TutorialManager.TUTORIAL_CARDS[i])
		if not is_inside_tree():
			return

	# Show ending demo
	if not _skip_requested:
		await _show_ending_demo()

	playthrough_complete.emit()


func _present_card(card: Dictionary) -> void:
	if not is_inside_tree():
		return

	_choice_made = -1
	_merlin_label.visible = false
	_continue_hint.visible = false
	for btn: Button in _option_buttons:
		btn.visible = false
		btn.disabled = false
	for lbl: Label in _effect_labels:
		lbl.visible = false

	# Title
	_title_label.text = str(card.get("id", "")).to_upper().replace("_", " ")
	_title_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.3)
	await tw.finished
	if not is_inside_tree():
		return

	# Text (typewriter)
	var full_text: String = str(card.get("text", ""))
	_text_label.text = ""
	await _typewriter(_text_label, full_text)
	if not is_inside_tree():
		return

	# Show options with stagger
	var options: Array = card.get("options", [])
	for i in mini(options.size(), 3):
		var opt: Dictionary = options[i]
		_option_buttons[i].text = str(opt.get("label", ""))
		_option_buttons[i].visible = true
		_option_buttons[i].modulate.a = 0.0

		_effect_labels[i].text = _format_effects(opt.get("effects", []))
		_effect_labels[i].visible = true
		_effect_labels[i].modulate.a = 0.0

		var stw := create_tween()
		stw.tween_property(_option_buttons[i], "modulate:a", 1.0, 0.25)
		stw.parallel().tween_property(_effect_labels[i], "modulate:a", 1.0, 0.25)

		if i < mini(options.size(), 3) - 1:
			await get_tree().create_timer(OPTION_STAGGER).timeout
			if not is_inside_tree():
				return

	_layout_ui()

	# Wait for choice
	while _choice_made < 0 and not _skip_requested:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	if _skip_requested:
		return

	# Apply effects
	var chosen: Dictionary = options[_choice_made]
	var effects: Array = chosen.get("effects", [])
	_apply_effects(effects)

	# Disable buttons
	for btn: Button in _option_buttons:
		btn.disabled = true

	# Life warning
	if _life <= 20:
		MerlinVisual.glitch_pulse(0.06)
		SFXManager.play("error")

	# Continue hint
	_continue_hint.visible = true
	_start_hint_blink()

	await _wait_for_advance()

	# Dissolve
	var dtw := create_tween()
	dtw.tween_property(_card_panel, "modulate:a", 0.0, 0.25)
	dtw.parallel().tween_property(_merlin_label, "modulate:a", 0.0, 0.25)
	for btn: Button in _option_buttons:
		dtw.parallel().tween_property(btn, "modulate:a", 0.0, 0.2)
	for lbl: Label in _effect_labels:
		dtw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.2)
	dtw.parallel().tween_property(_continue_hint, "modulate:a", 0.0, 0.15)
	await dtw.finished
	if not is_inside_tree():
		return

	_card_panel.modulate.a = 1.0
	_continue_hint.modulate.a = 1.0
	_continue_hint.visible = false
	await get_tree().create_timer(0.3).timeout


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECTS — v2.5 (HEAL_LIFE, DAMAGE_LIFE, ADD_REPUTATION)
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var etype: String = str(effect.get("type", ""))
		var amount: int = int(effect.get("amount", 0))
		match etype:
			"HEAL_LIFE":
				_life = mini(_life + amount, _life_max)
			"DAMAGE_LIFE":
				_life = maxi(_life - amount, 0)
			"ADD_REPUTATION":
				var faction: String = str(effect.get("faction", ""))
				if _faction_rep.has(faction):
					_faction_rep[faction] = clampf(float(_faction_rep[faction]) + float(amount), 0.0, 100.0)
	_update_life_display()


func _update_life_display() -> void:
	_life_bar.value = _life
	_life_label.text = "PV: %d/%d" % [_life, _life_max]
	if _life <= 20:
		_life_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	else:
		_life_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)


func _format_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var etype: String = str(effect.get("type", ""))
		var amount: int = int(effect.get("amount", 0))
		match etype:
			"HEAL_LIFE":
				parts.append("PV +%d" % amount)
			"DAMAGE_LIFE":
				parts.append("PV -%d" % amount)
			"ADD_REPUTATION":
				var faction: String = str(effect.get("faction", ""))
				var sign_str: String = "+" if amount >= 0 else ""
				parts.append("%s %s%d" % [faction.capitalize(), sign_str, amount])
	return "  ".join(parts)


func _get_option_accent(index: int) -> Color:
	match index:
		0: return MerlinVisual.CRT_PALETTE.phosphor
		1: return MerlinVisual.CRT_PALETTE.cyan
		2: return MerlinVisual.CRT_PALETTE.amber
		_: return MerlinVisual.CRT_PALETTE.phosphor


# ═══════════════════════════════════════════════════════════════════════════════
# ENDING DEMO
# ═══════════════════════════════════════════════════════════════════════════════

func _show_ending_demo() -> void:
	if not is_inside_tree():
		return

	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.01, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var otw := create_tween()
	otw.tween_property(overlay, "color:a", 0.88, 0.6)
	await otw.finished
	if not is_inside_tree():
		return

	MerlinVisual.glitch_pulse(0.12)
	SFXManager.play("danger")

	var ending_label := Label.new()
	ending_label.text = "DEMO : FIN DE RUN\n\nSi ta vie tombe a 0, le run s'arrete.\nChaque carte draine 1 PV.\nChoisis bien tes options pour survivre !\n\nMerlin : 'Tu as compris les bases.\nLe vrai voyage commence maintenant.'"
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_label.add_theme_font_override("font", MerlinVisual.get_font("title"))
	ending_label.add_theme_font_size_override("font_size", 20)
	ending_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ending_label.size = Vector2(500, 250)
	ending_label.position -= Vector2(250, 125)
	overlay.add_child(ending_label)

	SFXManager.play("magic_reveal")
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree():
		return

	var ftw := create_tween()
	ftw.tween_property(overlay, "color:a", 0.0, 0.5)
	await ftw.finished
	if not is_inside_tree():
		return
	overlay.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_pressed(idx: int) -> void:
	_choice_made = idx
	SFXManager.play("choice_select")


func _typewriter(label: Label, full_text: String) -> void:
	label.text = ""
	for i in range(full_text.length()):
		if _skip_requested or not is_inside_tree():
			label.text = full_text
			return
		label.text += full_text[i]
		var ch: String = full_text[i]
		var delay: float = TYPEWRITER_DELAY
		if ch in ".!?;:":
			delay = TYPEWRITER_PUNCT
		await get_tree().create_timer(delay).timeout


func _wait_for_advance() -> void:
	while is_inside_tree() and not _skip_requested:
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
		await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame


func _start_hint_blink() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_continue_hint, "modulate:a", 0.3, 0.6)
	tw.tween_property(_continue_hint, "modulate:a", 1.0, 0.6)
