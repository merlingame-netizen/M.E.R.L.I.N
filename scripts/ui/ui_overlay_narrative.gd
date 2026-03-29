## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlay Narrative — Travel, dream, merlin thinking, dialogue, pause
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlayNarrative

var _ui: MerlinGameUI

# Merlin thinking overlay
var _merlin_overlay: Control = null

# Pause overlay
var _pause_overlay: Control = null

# Dialogue state
var _dialogue_btn: Button
var _dialogue_popup: Control
var _dialogue_bubble: MerlinBubble
var _is_dialogue_open: bool = false

const DIALOGUE_PRESETS: Array[String] = [
	"Qui es-tu vraiment, Merlin ?",
	"Que me conseilles-tu ?",
	"Parle-moi de cet endroit.",
	"Journal des Vies",
]
const JOURNAL_PRESET_INDEX := 3


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func setup_dialogue_nodes() -> void:
	_dialogue_btn = Button.new()
	_dialogue_btn.name = "DialogueBtn"
	_dialogue_btn.text = "Parler"
	_dialogue_btn.custom_minimum_size = Vector2(72, 36)
	_dialogue_btn.tooltip_text = "Parler a Merlin"
	MerlinVisual.apply_celtic_option_theme(_dialogue_btn, MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13)))
	_dialogue_btn.z_index = 20
	_dialogue_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_btn.pressed.connect(_on_dialogue_btn_pressed)
	_dialogue_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	_ui.add_child(_dialogue_btn)
	_dialogue_btn.visible = false

	_dialogue_bubble = MerlinBubble.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.z_index = 25
	_ui.add_child(_dialogue_bubble)


func get_dialogue_btn() -> Button:
	return _dialogue_btn


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL & DREAM OVERLAYS
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String, dice_module: UIOverlayDice) -> void:
	dice_module.hide_dice_overlay()
	SFXManager.play("mist_breath")

	var fog: ColorRect = ColorRect.new()
	fog.name = "TravelFog"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fog_base: Color = MerlinVisual.CRT_PALETTE.phosphor
	fog.color = Color(fog_base.r * 0.4, fog_base.g * 0.4, fog_base.b * 0.4, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(fog)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _ui.body_font:
		lbl.add_theme_font_override("font", _ui.body_font)
	lbl.add_theme_font_size_override("font_size", 18)
	var lbl_base: Color = MerlinVisual.CRT_PALETTE.bg_panel
	lbl.add_theme_color_override("font_color", Color(lbl_base.r, lbl_base.g, lbl_base.b, 0.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	fog.add_child(lbl)

	var tw_in: Tween = _ui.create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(fog, "color:a", 0.85, 0.6)
	tw_in.tween_property(lbl, "theme_override_colors/font_color:a", 1.0, 0.6)
	await tw_in.finished

	if _ui.is_inside_tree():
		await _ui.get_tree().create_timer(1.8).timeout

	var tw_out: Tween = _ui.create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(fog, "color:a", 0.0, 0.6)
	tw_out.tween_property(lbl, "theme_override_colors/font_color:a", 0.0, 0.6)
	await tw_out.finished

	if is_instance_valid(fog):
		fog.queue_free()


func show_dream_overlay(dream_text: String) -> void:
	SFXManager.play("mist_breath")

	var dream_bg: ColorRect = ColorRect.new()
	dream_bg.name = "DreamOverlay"
	dream_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dream_bg.color = Color(MerlinVisual.CRT_PALETTE.bg_deep.r, MerlinVisual.CRT_PALETTE.bg_deep.g, MerlinVisual.CRT_PALETTE.bg_deep.b, 0.0)
	dream_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(dream_bg)

	var header: Label = Label.new()
	header.text = "~ Reve ~"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.offset_top = 60.0
	header.offset_left = -200.0
	header.offset_right = 200.0
	var t_font: Font = MerlinVisual.get_font("title")
	if t_font:
		header.add_theme_font_override("font", t_font)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(MerlinVisual.CRT_PALETTE.cyan.r, MerlinVisual.CRT_PALETTE.cyan.g, MerlinVisual.CRT_PALETTE.cyan.b, 0.0))
	dream_bg.add_child(header)

	var lbl: RichTextLabel = RichTextLabel.new()
	lbl.text = ""
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -260.0
	lbl.offset_right = 260.0
	lbl.offset_top = -80.0
	lbl.offset_bottom = 80.0
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var b_font: Font = MerlinVisual.get_font("body")
	if b_font:
		lbl.add_theme_font_override("normal_font", b_font)
	lbl.add_theme_font_size_override("normal_font_size", 15)
	lbl.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.cyan_bright)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	dream_bg.add_child(lbl)

	var tw_in: Tween = _ui.create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(dream_bg, "color:a", 0.92, 1.0).set_trans(Tween.TRANS_SINE)
	tw_in.tween_property(header, "theme_override_colors/font_color:a", 0.8, 1.2)
	tw_in.tween_property(lbl, "modulate:a", 1.0, 1.0)
	await tw_in.finished

	for i in range(dream_text.length()):
		lbl.text = dream_text.left(i + 1)
		if _ui.is_inside_tree():
			await _ui.get_tree().create_timer(0.03).timeout

	var read_time: float = clampf(dream_text.length() * 0.04, 2.0, 6.0)
	var pulse_tw: Tween = _ui.create_tween()
	pulse_tw.set_loops(int(read_time / 1.6))
	pulse_tw.tween_property(dream_bg, "color:a", 0.85, 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tw.tween_property(dream_bg, "color:a", 0.92, 0.8).set_trans(Tween.TRANS_SINE)

	if _ui.is_inside_tree():
		await _ui.get_tree().create_timer(read_time).timeout

	pulse_tw.kill()

	if not _ui.is_inside_tree():
		if is_instance_valid(dream_bg):
			dream_bg.queue_free()
		return

	var tw_out: Tween = _ui.create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(dream_bg, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw_out.tween_property(header, "theme_override_colors/font_color:a", 0.0, 0.8)
	tw_out.tween_property(lbl, "modulate:a", 0.0, 1.0)
	await tw_out.finished

	if is_instance_valid(dream_bg):
		dream_bg.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN THINKING OVERLAY
# ═══════════════════════════════════════════════════════════════════════════════

func show_merlin_thinking_overlay() -> void:
	if _merlin_overlay and is_instance_valid(_merlin_overlay):
		_merlin_overlay.visible = true
		_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_merlin_overlay = Control.new()
	_merlin_overlay.name = "MerlinThinkingOverlay"
	_merlin_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merlin_overlay.z_index = 20
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p: Color = MerlinVisual.CRT_PALETTE.bg_panel
	bg.color = Color(p.r, p.g, p.b, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merlin_overlay.add_child(bg)
	var lbl: Label = Label.new()
	lbl.text = "Merlin reflechit..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	if _ui.title_font:
		lbl.add_theme_font_override("font", _ui.title_font)
	_merlin_overlay.add_child(lbl)
	_ui.add_child(_merlin_overlay)
	_merlin_overlay.modulate.a = 0.0
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_merlin_overlay, "modulate:a", 1.0, 0.4)


func hide_merlin_thinking_overlay() -> void:
	if not _merlin_overlay or not is_instance_valid(_merlin_overlay):
		return
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_merlin_overlay, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if _merlin_overlay and is_instance_valid(_merlin_overlay):
			_merlin_overlay.visible = false
			_merlin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


# ═══════════════════════════════════════════════════════════════════════════════
# PAUSE MENU
# ═══════════════════════════════════════════════════════════════════════════════

func show_pause_menu() -> void:
	if _pause_overlay and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = true
		return

	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.add_child(_pause_overlay)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -120.0
	vbox.offset_right = 120.0
	vbox.offset_top = -80.0
	vbox.offset_bottom = 80.0
	vbox.add_theme_constant_override("separation", 16)
	_pause_overlay.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "PAUSE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_font: Font = MerlinVisual.get_font("title")
	if pause_font:
		title_lbl.add_theme_font_override("font", pause_font)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get("amber", Color(1.0, 0.75, 0.0)))
	vbox.add_child(title_lbl)

	var btn_resume: Button = Button.new()
	btn_resume.text = "Reprendre"
	btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
	@warning_ignore("static_called_on_instance")
	MerlinVisual.apply_button_theme(btn_resume)
	btn_resume.pressed.connect(func():
		_ui.pause_requested.emit())
	vbox.add_child(btn_resume)

	var btn_quit: Button = Button.new()
	btn_quit.text = "Quitter la Partie"
	btn_quit.process_mode = Node.PROCESS_MODE_ALWAYS
	@warning_ignore("static_called_on_instance")
	MerlinVisual.apply_button_theme(btn_quit)
	btn_quit.pressed.connect(func():
		_ui.get_tree().paused = false
		var pt: Node = _ui.get_node_or_null("/root/PixelTransition")
		if pt and pt.has_method("transition_to"):
			pt.transition_to("res://scenes/MenuPrincipal.tscn")
		else:
			_ui.get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	vbox.add_child(btn_quit)


func hide_pause_menu() -> void:
	if _pause_overlay and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# DIALOGUE MERLIN
# ═══════════════════════════════════════════════════════════════════════════════

func _on_dialogue_btn_pressed() -> void:
	if _is_dialogue_open:
		return
	SFXManager.play("card_draw")
	_show_dialogue_popup()


func _show_dialogue_popup() -> void:
	if _dialogue_popup and is_instance_valid(_dialogue_popup):
		_dialogue_popup.queue_free()

	_is_dialogue_open = true
	_dialogue_popup = Control.new()
	_dialogue_popup.name = "DialoguePopup"
	_dialogue_popup.z_index = 30
	_dialogue_popup.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shadow_c: Color = MerlinVisual.CRT_PALETTE.shadow
	dim.color = Color(shadow_c.r, shadow_c.g, shadow_c.b, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_dialogue_popup()
	)
	_dialogue_popup.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg_dark: Color = MerlinVisual.CRT_PALETTE.get("bg_dark", Color(0.05, 0.05, 0.08))
	style.bg_color = Color(bg_dark.r, bg_dark.g, bg_dark.b, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
	style.border_color = Color(amber.r, amber.g, amber.b, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(340, 0)
	var vp_size: Vector2 = _ui.get_viewport_rect().size
	panel.position = Vector2((vp_size.x - 340) * 0.5, vp_size.y * 0.25)
	_dialogue_popup.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Parler a Merlin"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui.title_font:
		title.add_theme_font_override("font", _ui.title_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", amber)
	vbox.add_child(title)

	for i in range(DIALOGUE_PRESETS.size()):
		var btn: Button = Button.new()
		btn.text = DIALOGUE_PRESETS[i]
		btn.custom_minimum_size = Vector2(300, 36)
		MerlinVisual.apply_celtic_option_theme(btn, MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.20, 1.00, 0.40)))
		btn.pressed.connect(_on_dialogue_preset_chosen.bind(i))
		btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		vbox.add_child(btn)

	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	vbox.add_child(input_row)

	var line_edit: LineEdit = LineEdit.new()
	line_edit.name = "FreeTextInput"
	line_edit.placeholder_text = "Ecris ta question..."
	line_edit.custom_minimum_size = Vector2(240, 32)
	if _ui.body_font:
		line_edit.add_theme_font_override("font", _ui.body_font)
	line_edit.add_theme_font_size_override("font_size", 14)
	line_edit.text_submitted.connect(_on_dialogue_free_text_submitted)
	input_row.add_child(line_edit)

	var send_btn: Button = Button.new()
	send_btn.text = ">"
	send_btn.custom_minimum_size = Vector2(48, 48)
	MerlinVisual.apply_button_theme(send_btn)
	send_btn.pressed.connect(func():
		var text: String = line_edit.text.strip_edges()
		if text.length() > 0:
			_on_dialogue_free_text_submitted(text)
	)
	input_row.add_child(send_btn)

	_ui.add_child(_dialogue_popup)

	_dialogue_popup.modulate.a = 0.0
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_dialogue_popup, "modulate:a", 1.0, 0.2)

	line_edit.grab_focus()


func _close_dialogue_popup() -> void:
	_is_dialogue_open = false
	if _dialogue_popup and is_instance_valid(_dialogue_popup):
		var tw: Tween = _ui.create_tween()
		tw.tween_property(_dialogue_popup, "modulate:a", 0.0, 0.15)
		tw.tween_callback(_dialogue_popup.queue_free)


func _on_dialogue_preset_chosen(index: int) -> void:
	if index < 0 or index >= DIALOGUE_PRESETS.size():
		return
	_close_dialogue_popup()
	SFXManager.play("card_draw")
	if index == JOURNAL_PRESET_INDEX:
		_ui.journal_requested.emit()
		return
	var question: String = DIALOGUE_PRESETS[index]
	_ui.merlin_dialogue_requested.emit(question)


func _on_dialogue_free_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_close_dialogue_popup()
	SFXManager.play("card_draw")
	_ui.merlin_dialogue_requested.emit(text.strip_edges())


func show_merlin_dialogue_response(text: String) -> void:
	if _dialogue_bubble and is_instance_valid(_dialogue_bubble):
		_dialogue_bubble.show_message(text, 6.0)
