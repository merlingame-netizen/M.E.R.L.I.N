class_name TutorialCardLayer
extends Control

## Tutorial Card Layer — Scripted 3-card express playthrough
## Deterministic, no LLM, effects visible (tutorial mode).
## Instanciated by IntroTutorial.gd during Phase 2.

signal playthrough_complete

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const CARD_MAX_W := 560.0
const CARD_MAX_H := 420.0
const OPTION_STAGGER := 0.12
const TYPEWRITER_DELAY := 0.018
const TYPEWRITER_PUNCT := 0.050

const TUTORIAL_CARDS: Array[Dictionary] = [
	{
		"title": "LE CARREFOUR",
		"text": "Un druide blesse git au bord du chemin.\nSa bestiole tourne en cercles desesperes.\nQue fais-tu ?",
		"options": [
			{"label": "Soigner ses blessures", "effects": {"Corps": -10, "Ame": 15}, "merlin": "Un geste noble. Ton corps en paie le prix."},
			{"label": "Partager ton Awen", "effects": {"Ame": 10, "Monde": 5, "Souffle": -1}, "merlin": "L'Awen partagee brille plus fort."},
			{"label": "Passer sans s'arreter", "effects": {"Monde": -15}, "merlin": "Le monde note chaque pas que tu ignores."},
		],
	},
	{
		"title": "LA CONFRONTATION",
		"text": "Des villageois accusent un vieillard de sorcellerie.\nLa foule est en colere.",
		"alert": "Attention — observe tes jauges avant de choisir.",
		"options": [
			{"label": "Defendre le vieillard", "effects": {"Corps": -15, "Monde": 10}, "merlin": "Courageux. Mais ton corps s'affaiblit."},
			{"label": "Chercher des preuves", "effects": {"Ame": 10}, "merlin": "La verite demande de la patience."},
			{"label": "Rallier la foule", "effects": {"Monde": -20, "Corps": 5}, "merlin": "La foule t'ecoute... pour l'instant."},
		],
	},
	{
		"title": "LA TEMPETE",
		"text": "La brume se leve en tempete soudaine.\nUn pont s'effondre. Tu dois choisir vite.",
		"options": [
			{"label": "Sauter avant la chute", "effects": {"Corps": -20, "Ame": -10}, "merlin": ""},
			{"label": "Canaliser l'Awen", "effects": {"Souffle": -1, "Corps": 5}, "merlin": "L'Awen stabilise tout. Temporairement."},
			{"label": "Chercher un autre chemin", "effects": {"Monde": -10, "Ame": -5}, "merlin": ""},
		],
	},
]

const ASPECT_NAMES: Array[String] = ["Corps", "Ame", "Monde"]

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _aspects: Dictionary = {"Corps": 50, "Ame": 50, "Monde": 50}
var _souffle: int = 3
var _card_idx: int = 0
var _choice_made: int = -1
var _skip_requested: bool = false

# Nodes
var _card_panel: PanelContainer
var _title_label: Label
var _text_label: Label
var _alert_label: Label
var _option_buttons: Array[Button] = []
var _effect_labels: Array[Label] = []
var _merlin_label: Label
var _triade_hud: HubTriadeHud
var _souffle_bar: HubSouffleBar
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
	# Triade HUD at top
	_triade_hud = HubTriadeHud.new()
	add_child(_triade_hud)
	_triade_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_triade_hud.position.y = 16.0
	_triade_hud.size = Vector2(size.x, 48.0)
	_triade_hud.update_aspects(_aspects)

	# Souffle bar below Triade
	_souffle_bar = HubSouffleBar.new()
	add_child(_souffle_bar)
	_souffle_bar.position = Vector2(0, 72.0)
	_souffle_bar.size = Vector2(size.x, 28.0)
	_souffle_bar.update_souffle(_souffle, 7)

	# Card panel
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
	sep.add_theme_font_override("font", MerlinVisual.get_font("body"))
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

	# Alert label (hidden by default)
	_alert_label = Label.new()
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_label.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_alert_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	_alert_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.warning)
	_alert_label.visible = false
	vbox.add_child(_alert_label)

	# Options container (below card, separate)
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

		# Effect annotation label
		var eff_label := Label.new()
		eff_label.add_theme_font_override("font", MerlinVisual.get_font("body"))
		eff_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_TINY)
		eff_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_dim)
		eff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		option_row.add_child(eff_label)
		_effect_labels.append(eff_label)

	# Merlin reaction (below options)
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
	_continue_hint.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_continue_hint.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	_continue_hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_continue_hint.visible = false
	add_child(_continue_hint)

	# Initial layout
	_layout_ui()


func _layout_ui() -> void:
	var vp: Vector2 = size
	if vp.x < 1.0:
		vp = get_viewport().get_visible_rect().size

	# Triade + Souffle sizing
	_triade_hud.size.x = vp.x
	_souffle_bar.size.x = vp.x

	# Card panel centered
	var card_w: float = minf(CARD_MAX_W, vp.x * 0.85)
	_card_panel.position = Vector2((vp.x - card_w) * 0.5, 110.0)
	_card_panel.size = Vector2(card_w, 0)  # auto-height

	# Options box below card
	var opts: Node = get_node_or_null("OptionsBox")
	if opts:
		var opt_w: float = minf(420.0, vp.x * 0.75)
		opts.position = Vector2((vp.x - opt_w) * 0.5, _card_panel.position.y + _card_panel.size.y + 20.0)
		opts.size = Vector2(opt_w, 0)
		for btn: Button in _option_buttons:
			btn.custom_minimum_size.x = opt_w

	# Merlin reaction
	_merlin_label.position = Vector2((vp.x - 400.0) * 0.5, vp.y - 120.0)
	_merlin_label.size = Vector2(400.0, 60.0)

	# Continue hint
	_continue_hint.position = Vector2(0, vp.y - 40.0)
	_continue_hint.size = Vector2(vp.x, 30.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _card_panel:
			_layout_ui()


# ═══════════════════════════════════════════════════════════════════════════════
# CARD SEQUENCE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_sequence() -> void:
	await get_tree().process_frame
	_layout_ui()

	for i in TUTORIAL_CARDS.size():
		if _skip_requested:
			break
		_card_idx = i
		await _present_card(TUTORIAL_CARDS[i])
		if not is_inside_tree():
			return

	# Check ending demo on card 3
	if not _skip_requested:
		var has_two_extreme := _count_extremes() >= 2
		if has_two_extreme:
			await _show_ending_demo()
		else:
			# Demonstrate ending anyway with a brief flash
			await _show_ending_demo_forced()

	playthrough_complete.emit()


func _present_card(card: Dictionary) -> void:
	if not is_inside_tree():
		return

	# Reset UI
	_choice_made = -1
	_merlin_label.visible = false
	_continue_hint.visible = false
	_alert_label.visible = false
	for btn: Button in _option_buttons:
		btn.visible = false
		btn.disabled = false
	for lbl: Label in _effect_labels:
		lbl.visible = false

	# Title
	_title_label.text = str(card.get("title", ""))
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

	# Alert if present
	var alert_text: String = str(card.get("alert", ""))
	if alert_text.length() > 0:
		_alert_label.text = "[!] " + alert_text
		_alert_label.visible = true
		_alert_label.modulate.a = 0.0
		var atw := create_tween()
		atw.tween_property(_alert_label, "modulate:a", 1.0, 0.3)
		await atw.finished
		if not is_inside_tree():
			return

	# Show options with stagger
	var options: Array = card.get("options", [])
	for i in mini(options.size(), 3):
		var opt: Dictionary = options[i]
		_option_buttons[i].text = str(opt.get("label", ""))
		_option_buttons[i].visible = true
		_option_buttons[i].modulate.a = 0.0

		# Effect annotation
		_effect_labels[i].text = _format_effects(opt.get("effects", {}))
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
	var effects: Dictionary = chosen.get("effects", {})
	_apply_effects(effects)

	# Disable buttons
	for btn: Button in _option_buttons:
		btn.disabled = true

	# Show Merlin reaction
	var merlin_text: String = str(chosen.get("merlin", ""))
	if merlin_text.length() > 0:
		_merlin_label.text = "Merlin : \"" + merlin_text + "\""
		_merlin_label.visible = true
		MerlinVisual.phosphor_reveal(_merlin_label, 0.4)
		# Replace font color to cyan after reveal
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
		_merlin_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.cyan)

	# Check aspect warnings
	_flash_extreme_aspects()

	# Continue hint
	_continue_hint.visible = true
	_start_hint_blink()

	# Wait for advance
	await _wait_for_advance()

	# Dissolve card content
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

	# Reset for next card
	_card_panel.modulate.a = 1.0
	_continue_hint.modulate.a = 1.0
	_continue_hint.visible = false
	await get_tree().create_timer(0.3).timeout


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_effects(effects: Dictionary) -> void:
	for key: String in effects:
		var delta: int = int(effects[key])
		if key == "Souffle":
			_souffle = clampi(_souffle + delta, 0, 7)
			_souffle_bar.update_souffle(_souffle, 7)
		elif _aspects.has(key):
			_aspects[key] = clampi(int(_aspects[key]) + delta, 0, 100)
	_triade_hud.update_aspects(_aspects)


func _count_extremes() -> int:
	var count := 0
	for aspect_name: String in ASPECT_NAMES:
		var val: int = int(_aspects.get(aspect_name, 50))
		if val <= 20 or val >= 80:
			count += 1
	return count


func _flash_extreme_aspects() -> void:
	for aspect_name: String in ASPECT_NAMES:
		var val: int = int(_aspects.get(aspect_name, 50))
		if val <= 20:
			# Red flash warning
			MerlinVisual.glitch_pulse(0.06)
			SFXManager.play("error")


func _format_effects(effects: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in effects:
		var delta: int = int(effects[key])
		var sign_str: String = "+" if delta > 0 else ""
		parts.append(key + " " + sign_str + str(delta))
	return "  ".join(parts)


func _get_option_accent(index: int) -> Color:
	match index:
		0: return MerlinVisual.CRT_ASPECT_COLORS["Corps"]  # Red-orange (direct)
		1: return MerlinVisual.CRT_PALETTE.cyan             # Cyan (wise/balanced)
		2: return MerlinVisual.CRT_PALETTE.amber            # Amber (risky)
		_: return MerlinVisual.CRT_PALETTE.phosphor


# ═══════════════════════════════════════════════════════════════════════════════
# ENDING DEMO
# ═══════════════════════════════════════════════════════════════════════════════

func _show_ending_demo() -> void:
	# Find which 2 aspects are extreme
	var extreme_names: Array[String] = []
	for aspect_name: String in ASPECT_NAMES:
		var val: int = int(_aspects.get(aspect_name, 50))
		if val <= 20 or val >= 80:
			extreme_names.append(aspect_name)

	await _display_ending_overlay(extreme_names)


func _show_ending_demo_forced() -> void:
	# Force a visible demo even if player avoided extremes
	# Temporarily push 2 aspects to extreme for visual effect
	var saved_aspects: Dictionary = _aspects.duplicate()
	_aspects["Corps"] = 15
	_aspects["Ame"] = 12
	_triade_hud.update_aspects(_aspects)

	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return

	await _display_ending_overlay(["Corps", "Ame"])

	# Restore
	_aspects = saved_aspects
	_triade_hud.update_aspects(_aspects)


func _display_ending_overlay(extreme_names: Array[String]) -> void:
	if not is_inside_tree():
		return

	# Build ending overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.01, 0.01, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Fade in overlay
	var otw := create_tween()
	otw.tween_property(overlay, "color:a", 0.88, 0.6)
	await otw.finished
	if not is_inside_tree():
		return

	MerlinVisual.glitch_pulse(0.12)
	SFXManager.play("danger")

	# Ending text
	var ending_label := Label.new()
	var ending_text := "FIN DE RUN"
	if extreme_names.size() >= 2:
		var state_a: String = "Epuise" if int(_aspects.get(extreme_names[0], 50)) <= 20 else "Surmene"
		var state_b: String = "Perdue" if int(_aspects.get(extreme_names[1], 50)) <= 20 else "Possedee"
		ending_text += "\n" + extreme_names[0] + " " + state_a + " + " + extreme_names[1] + " " + state_b
		ending_text += "\n\nLe brouillard t'engloutit..."
	ending_label.text = ending_text
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_label.add_theme_font_override("font", MerlinVisual.get_font("title"))
	ending_label.add_theme_font_size_override("font_size", 26)
	ending_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	ending_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ending_label.size = Vector2(500, 200)
	ending_label.position -= Vector2(250, 100)
	overlay.add_child(ending_label)

	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return

	# Merlin interrupts
	ending_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	ending_label.add_theme_font_size_override("font_size", 20)
	ending_label.text = "Voila ce qui arrive.\nDeux aspects a l'extreme = fin du run.\n\nMais c'etait une demonstration.\nCette fois, je te sauve."
	SFXManager.play("magic_reveal")

	await get_tree().create_timer(3.5).timeout
	if not is_inside_tree():
		return

	# Fade out overlay
	var ftw := create_tween()
	ftw.tween_property(overlay, "color:a", 0.0, 0.5)
	await ftw.finished
	if not is_inside_tree():
		return
	overlay.queue_free()

	# Reset aspects to equilibrium
	_aspects = {"Corps": 50, "Ame": 50, "Monde": 50}
	_souffle = 3
	_triade_hud.update_aspects(_aspects)
	_souffle_bar.update_souffle(_souffle, 7)


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
	# Wait for space/enter/click
	while is_inside_tree() and not _skip_requested:
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
		await get_tree().process_frame
	# Debounce
	if is_inside_tree():
		await get_tree().process_frame


func _start_hint_blink() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_continue_hint, "modulate:a", 0.3, 0.6)
	tw.tween_property(_continue_hint, "modulate:a", 1.0, 0.6)
