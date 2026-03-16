## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlays Module — End screen, dice, travel, dream, pause, dialogue, journal
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles all full-screen and modal overlays.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlaysModule

var _ui: MerlinGameUI

# Dice overlay state
var _dice_overlay: Control = null
var _dice_display: Label = null
var _dice_dc_label: Label = null
var _dice_result_label: Label = null
var _dice_bg_panel: PanelContainer = null

# Merlin thinking overlay
var _merlin_overlay: Control = null

# Pause overlay
var _pause_overlay: Control = null

# Dialogue state
var _dialogue_btn: Button
var _dialogue_popup: Control
var _dialogue_bubble: MerlinBubble
var _is_dialogue_open: bool = false

# Typology
var _typology_timer_bar: ProgressBar = null
var _typology_badge: Label = null
var _typology_timer_max: float = 10.0

const DIALOGUE_PRESETS: Array[String] = [
	"Qui es-tu vraiment, Merlin ?",
	"Que me conseilles-tu ?",
	"Parle-moi de cet endroit.",
	"Journal des Vies",
]
const JOURNAL_PRESET_INDEX := 3

const MINIGAME_FIELD_ICONS: Dictionary = {
	"combat": "\u2694",
	"exploration": "\uD83D\uDD0D",
	"mysticisme": "\u2728",
	"survie": "\u2605",
	"diplomatie": "\u2696",
}


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
# DICE UI
# ═══════════════════════════════════════════════════════════════════════════════

func show_dice_roll(dc: int, target: int) -> void:
	_ensure_dice_overlay()
	_ui.switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 0.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = "?"
	_dice_display.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_dice_display.scale = Vector2.ONE
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.scale = Vector2.ONE
		_dice_bg_panel.rotation = 0.0

	var tw_in: Tween = _ui.create_tween()
	tw_in.tween_property(_dice_overlay, "modulate:a", 1.0, 0.2)
	await tw_in.finished

	var duration: float = 3.0
	var elapsed: float = 0.0
	while elapsed < duration and _ui.is_inside_tree():
		var progress: float = elapsed / duration
		var cycle_speed: float = lerpf(0.07, 0.35, progress * progress)
		_dice_display.text = str(randi_range(1, 20))
		if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
			_dice_bg_panel.rotation = randf_range(-0.1, 0.1) * (1.0 - progress)
		await _ui.get_tree().create_timer(cycle_speed).timeout
		elapsed += cycle_speed

	_dice_display.text = str(target)
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.rotation = 0.0
		var tw_bounce: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_bounce.tween_property(_dice_bg_panel, "scale", Vector2(1.25, 1.25), 0.15)
		tw_bounce.tween_property(_dice_bg_panel, "scale", Vector2(1.0, 1.0), 0.3)
		await tw_bounce.finished
	else:
		_dice_display.pivot_offset = _dice_display.size / 2.0
		var tw_bounce: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_bounce.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
		tw_bounce.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)
		await tw_bounce.finished


func show_dice_instant(dc: int, value: int) -> void:
	_ensure_dice_overlay()
	_ui.switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = str(value)
	var glow: Color = _dice_outcome_color(value, dc)
	_dice_display.add_theme_color_override("font_color", glow)
	if _dice_bg_panel and is_instance_valid(_dice_bg_panel):
		_dice_bg_panel.rotation = 0.0
		var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_bg_panel, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(_dice_bg_panel, "scale", Vector2(1.0, 1.0), 0.3)
	else:
		_dice_display.pivot_offset = _dice_display.size / 2.0
		var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
		tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)


func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	_ensure_dice_overlay()
	var glow: Color = _dice_outcome_color(roll, dc)
	_dice_display.add_theme_color_override("font_color", glow)

	match outcome:
		"critical_success":
			_dice_result_label.text = "Coup Critique !"
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
		"success":
			_dice_result_label.text = "Reussite ! (%d >= %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
		"failure":
			_dice_result_label.text = "Echec... (%d < %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		"critical_failure":
			_dice_result_label.text = "Echec Critique !"
			_dice_result_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)


func _dice_outcome_color(roll: int, dc: int) -> Color:
	if roll == 20:
		return MerlinVisual.CRT_PALETTE.souffle_full
	elif roll == 1:
		return MerlinVisual.CRT_PALETTE.danger
	elif roll >= dc:
		return MerlinVisual.CRT_PALETTE.success
	else:
		return MerlinVisual.CRT_PALETTE.danger


func _ensure_dice_overlay() -> void:
	if _dice_overlay and is_instance_valid(_dice_overlay):
		return
	if not _ui._card_body_content_host or not is_instance_valid(_ui._card_body_content_host):
		return
	_dice_overlay = Control.new()
	_dice_overlay.name = "DiceOverlay"
	_dice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.visible = false
	_ui._card_body_content_host.add_child(_dice_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	_dice_dc_label = Label.new()
	_dice_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_dc_label.add_theme_font_size_override("font_size", 12)
	_dice_dc_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	if _ui.body_font:
		_dice_dc_label.add_theme_font_override("font", _ui.body_font)
	vbox.add_child(_dice_dc_label)

	var dice_center: CenterContainer = CenterContainer.new()
	vbox.add_child(dice_center)

	_dice_bg_panel = PanelContainer.new()
	_dice_bg_panel.custom_minimum_size = Vector2(70, 70)
	var dice_style: StyleBoxFlat = StyleBoxFlat.new()
	dice_style.bg_color = MerlinVisual.CRT_PALETTE.bg_dark
	dice_style.border_color = MerlinVisual.CRT_PALETTE.amber
	dice_style.set_border_width_all(2)
	dice_style.set_corner_radius_all(10)
	dice_style.content_margin_left = 6
	dice_style.content_margin_right = 6
	dice_style.content_margin_top = 6
	dice_style.content_margin_bottom = 6
	dice_style.shadow_color = Color(0, 0, 0, 0.2)
	dice_style.shadow_size = 3
	dice_style.shadow_offset = Vector2(1, 2)
	_dice_bg_panel.add_theme_stylebox_override("panel", dice_style)
	_dice_bg_panel.pivot_offset = Vector2(35, 35)
	dice_center.add_child(_dice_bg_panel)

	_dice_display = Label.new()
	_dice_display.text = "?"
	_dice_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _ui.title_font:
		_dice_display.add_theme_font_override("font", _ui.title_font)
	_dice_display.add_theme_font_size_override("font_size", 48)
	_dice_display.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_dice_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dice_bg_panel.add_child(_dice_display)

	_dice_result_label = Label.new()
	_dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_label.add_theme_font_size_override("font_size", 13)
	if _ui.body_font:
		_dice_result_label.add_theme_font_override("font", _ui.body_font)
	vbox.add_child(_dice_result_label)


func hide_dice_overlay() -> void:
	if _dice_overlay and is_instance_valid(_dice_overlay):
		var tw: Tween = _ui.create_tween()
		tw.tween_property(_dice_overlay, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			_dice_overlay.visible = false
			_ui.switch_body_to_text()
		)


func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	_ensure_dice_overlay()
	_ui.switch_body_to_content()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	var bonus_text: String = ""
	if tool_bonus != 0:
		bonus_text = " (bonus %d)" % tool_bonus
	_dice_dc_label.text = "Score: %d \u2192 D20: %d%s" % [score, d20, bonus_text]
	_dice_dc_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.get("green", Color(0.6, 0.8, 0.5)))
	_dice_display.text = str(d20)
	_dice_result_label.text = ""


func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	if not _ui._card_body_content_host or not is_instance_valid(_ui._card_body_content_host):
		return
	_ui.switch_body_to_content()

	var overlay: Control = Control.new()
	overlay.name = "MinigameIntro"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	_ui._card_body_content_host.add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	center.add_child(vbox)

	var icon_label: Label = Label.new()
	var field_icon: String = MINIGAME_FIELD_ICONS.get(field, "\u2726")
	icon_label.text = field_icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)

	var name_label: Label = Label.new()
	name_label.text = "Epreuve: %s" % field.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui.title_font:
		name_label.add_theme_font_override("font", _ui.title_font)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(name_label)

	if tool_bonus != 0 and tool_bonus_text != "":
		var bonus_label: Label = Label.new()
		bonus_label.text = "%s DC %d" % [tool_bonus_text, tool_bonus]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _ui.body_font:
			bonus_label.add_theme_font_override("font", _ui.body_font)
		bonus_label.add_theme_font_size_override("font_size", 13)
		bonus_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
		vbox.add_child(bonus_label)

	var tw: Tween = _ui.create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(overlay.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL & DREAM OVERLAYS
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String) -> void:
	hide_dice_overlay()
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


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	var is_victory: bool = ending.get("victory", false)
	if _ui.biome_art_layer and is_instance_valid(_ui.biome_art_layer):
		var tw_forest: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if is_victory:
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", MerlinVisual.CRT_PALETTE["victory_flash"], 1.2)
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", MerlinVisual.CRT_PALETTE["victory_settle"], 0.6)
		else:
			tw_forest.tween_property(_ui.biome_art_layer, "modulate:a", 0.06, 1.5)
		await tw_forest.finished

	if _ui.card_container:
		_ui.card_container.visible = false
	if _ui.options_container:
		_ui.options_container.visible = false

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(MerlinVisual.CRT_PALETTE.bg_panel.r, MerlinVisual.CRT_PALETTE.bg_panel.g, MerlinVisual.CRT_PALETTE.bg_panel.b, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	_ui.add_child(overlay)

	var fade_tw: Tween = _ui.create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.8)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var orn_top: Label = Label.new()
	orn_top.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_top.add_theme_font_size_override("font_size", 14)
	orn_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_top)

	var ending_data: Dictionary = ending.get("ending", {})
	var title: Label = Label.new()
	title.text = ending_data.get("title", "Fin")
	if _ui.title_font:
		title.add_theme_font_override("font", _ui.title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ending.get("victory", false):
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	else:
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	vbox.add_child(title)

	if ending_data.has("text"):
		var text: Label = Label.new()
		text.text = ending_data.get("text", "")
		if _ui.body_font:
			text.add_theme_font_override("font", _ui.body_font)
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	var score_lbl: Label = Label.new()
	score_lbl.text = "Gloire: %d" % ending.get("score", 0)
	if _ui.title_font:
		score_lbl.add_theme_font_override("font", _ui.title_font)
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(score_lbl)

	if ending.get("life_depleted", false):
		var life_lbl: Label = Label.new()
		life_lbl.text = "Essences de vie epuisees"
		if _ui.body_font:
			life_lbl.add_theme_font_override("font", _ui.body_font)
		life_lbl.add_theme_font_size_override("font_size", 14)
		life_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(life_lbl)

	var stats_lbl: Label = Label.new()
	stats_lbl.text = "Cartes: %d  \u2502  Jours: %d" % [ending.get("cards_played", 0), ending.get("days_survived", 1)]
	if _ui.body_font:
		stats_lbl.add_theme_font_override("font", _ui.body_font)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	_build_end_screen_story_log(vbox, ending)
	_build_end_screen_rewards(vbox, ending)

	var orn_bot: Label = Label.new()
	orn_bot.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_bot.add_theme_font_size_override("font_size", 14)
	orn_bot.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_bot)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_hub: Button = Button.new()
	btn_hub.text = "Retour au Hub"
	btn_hub.custom_minimum_size = Vector2(200, 50)
	btn_hub.pressed.connect(func(): PixelTransition.transition_to("res://scenes/HubAntre.tscn"))
	btn_box.add_child(btn_hub)

	var btn_new: Button = Button.new()
	btn_new.text = "Nouvelle Aventure"
	btn_new.custom_minimum_size = Vector2(200, 50)
	btn_new.pressed.connect(func(): PixelTransition.transition_to("res://scenes/TransitionBiome.tscn"))
	btn_box.add_child(btn_new)


func _build_end_screen_story_log(vbox: VBoxContainer, ending: Dictionary) -> void:
	var story_log: Array = ending.get("story_log", [])
	if story_log.size() <= 0:
		return

	var path_title: Label = Label.new()
	path_title.text = "Ton chemin"
	if _ui.title_font:
		path_title.add_theme_font_override("font", _ui.title_font)
	path_title.add_theme_font_size_override("font_size", 16)
	path_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	path_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(path_title)

	var last_entries: Array = story_log.slice(-5) if story_log.size() > 5 else story_log
	var path_parts: PackedStringArray = []
	for entry in last_entries:
		var choice_text: String = str(entry.get("choice", ""))
		if not choice_text.is_empty():
			path_parts.append(choice_text)
	if path_parts.size() > 0:
		var path_lbl: Label = Label.new()
		path_lbl.text = " > ".join(path_parts)
		if _ui.body_font:
			path_lbl.add_theme_font_override("font", _ui.body_font)
		path_lbl.add_theme_font_size_override("font_size", 12)
		path_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		path_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		path_lbl.custom_minimum_size.x = 400
		vbox.add_child(path_lbl)


func _build_end_screen_rewards(vbox: VBoxContainer, ending: Dictionary) -> void:
	var rewards: Dictionary = ending.get("rewards", {})
	if rewards.size() <= 0:
		return

	if rewards.get("partial", false):
		var partial_lbl: Label = Label.new()
		partial_lbl.text = "Run incomplete \u2014 recompenses x0.25"
		if _ui.body_font:
			partial_lbl.add_theme_font_override("font", _ui.body_font)
		partial_lbl.add_theme_font_size_override("font_size", 14)
		partial_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		partial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(partial_lbl)

	var rewards_title: Label = Label.new()
	rewards_title.text = "Recompenses obtenues"
	if _ui.title_font:
		rewards_title.add_theme_font_override("font", _ui.title_font)
	rewards_title.add_theme_font_size_override("font_size", 18)
	rewards_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rewards_title)

	var ess: Dictionary = rewards.get("essence", {})
	if ess.size() > 0:
		var parts: PackedStringArray = []
		for elem in ess:
			if int(ess[elem]) > 0:
				parts.append("%s +%d" % [str(elem).left(4), int(ess[elem])])
		if parts.size() > 0:
			var ess_lbl: Label = Label.new()
			ess_lbl.text = "Essences: " + " | ".join(parts)
			if _ui.body_font:
				ess_lbl.add_theme_font_override("font", _ui.body_font)
			ess_lbl.add_theme_font_size_override("font_size", 13)
			ess_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
			ess_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			ess_lbl.custom_minimum_size.x = 400
			vbox.add_child(ess_lbl)

	var currency_parts: PackedStringArray = []
	var frag: int = int(rewards.get("fragments", 0))
	var liens: int = int(rewards.get("liens", 0))
	var gloire_r: int = int(rewards.get("gloire", 0))
	if frag > 0:
		currency_parts.append("Fragments +%d" % frag)
	if liens > 0:
		currency_parts.append("Liens +%d" % liens)
	if gloire_r > 0:
		currency_parts.append("Gloire +%d" % gloire_r)
	if currency_parts.size() > 0:
		var cur_lbl: Label = Label.new()
		cur_lbl.text = " | ".join(currency_parts)
		if _ui.body_font:
			cur_lbl.add_theme_font_override("font", _ui.body_font)
		cur_lbl.add_theme_font_size_override("font_size", 14)
		cur_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cur_lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# JOURNAL POPUP
# ═══════════════════════════════════════════════════════════════════════════════

func show_journal_popup(run_summaries: Array[Dictionary]) -> void:
	if run_summaries.is_empty():
		return

	var popup: ColorRect = ColorRect.new()
	popup.name = "JournalPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.color = Color(MerlinVisual.CRT_PALETTE.bg_deep.r, MerlinVisual.CRT_PALETTE.bg_deep.g, MerlinVisual.CRT_PALETTE.bg_deep.b, 0.92)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(popup)

	var title: Label = Label.new()
	title.text = "Journal des Vies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 30.0
	title.offset_left = -200.0
	title.offset_right = 200.0
	var title_font_res: Font = MerlinVisual.get_font("title")
	if title_font_res:
		title.add_theme_font_override("font", title_font_res)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	popup.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 70.0
	scroll.offset_bottom = -60.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	popup.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var body_font_res: Font = MerlinVisual.get_font("body")
	var entry_color: Color = MerlinVisual.CRT_PALETTE.phosphor
	var dim_color: Color = MerlinVisual.CRT_PALETTE.phosphor_dim

	for i in range(run_summaries.size()):
		var run: Dictionary = run_summaries[i]
		var entry: RichTextLabel = RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.scroll_active = false
		if body_font_res:
			entry.add_theme_font_override("normal_font", body_font_res)
		entry.add_theme_font_size_override("normal_font_size", 13)
		entry.add_theme_color_override("default_color", entry_color)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var ending_str: String = str(run.get("ending", "inconnu"))
		var cards: int = int(run.get("cards_played", 0))
		var dom: String = str(run.get("dominant_aspect", ""))
		var run_style: String = str(run.get("player_style", ""))
		var life: int = int(run.get("life_final", 0))
		var events: String = str(run.get("notable_events", ""))

		var text: String = "[b]Vie %d[/b] -- %s\n" % [i + 1, ending_str]
		if cards > 0:
			text += "Cartes: %d | " % cards
		if not dom.is_empty():
			text += "Aspect: %s | " % dom
		if not run_style.is_empty():
			text += "Style: %s | " % run_style
		if life > 0:
			text += "Vie: %d" % life
		if not events.is_empty():
			text += "\n%s" % events
		entry.text = text
		vbox.add_child(entry)

		if i < run_summaries.size() - 1:
			var sep: HSeparator = HSeparator.new()
			sep.add_theme_color_override("separator", dim_color)
			vbox.add_child(sep)

	var close_btn: Button = Button.new()
	close_btn.text = "Fermer"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_bottom = -20.0
	close_btn.offset_top = -50.0
	close_btn.offset_left = -60.0
	close_btn.offset_right = 60.0
	if title_font_res:
		close_btn.add_theme_font_override("font", title_font_res)
	close_btn.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	close_btn.custom_minimum_size = Vector2(120, 48)
	MerlinVisual.apply_button_theme(close_btn)
	popup.add_child(close_btn)

	popup.modulate.a = 0.0
	var tw: Tween = _ui.create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.3)

	close_btn.pressed.connect(func():
		var tw_out: Tween = _ui.create_tween()
		tw_out.tween_property(popup, "modulate:a", 0.0, 0.2)
		tw_out.tween_callback(popup.queue_free)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# TYPOLOGY UI
# ═══════════════════════════════════════════════════════════════════════════════

func show_typology_timer(total_seconds: float) -> void:
	_typology_timer_max = total_seconds
	if _typology_timer_bar == null or not is_instance_valid(_typology_timer_bar):
		_typology_timer_bar = ProgressBar.new()
		_typology_timer_bar.custom_minimum_size = Vector2(120.0, 14.0)
		_typology_timer_bar.min_value = 0.0
		_typology_timer_bar.max_value = total_seconds
		_typology_timer_bar.value = total_seconds
		_typology_timer_bar.show_percentage = false
		_typology_timer_bar.modulate = MerlinVisual.CRT_PALETTE.warning
		if is_instance_valid(_ui._top_status_bar):
			_ui._top_status_bar.add_child(_typology_timer_bar)
	_typology_timer_bar.max_value = total_seconds
	_typology_timer_bar.value = total_seconds
	_typology_timer_bar.visible = true


func update_typology_timer(remaining: float) -> void:
	if _typology_timer_bar and is_instance_valid(_typology_timer_bar):
		_typology_timer_bar.value = maxf(remaining, 0.0)
		var alpha: float = 1.0 if remaining > 3.0 else 0.6 + 0.4 * sin(remaining * 6.0)
		var warn: Color = MerlinVisual.CRT_PALETTE.warning
		warn.a = alpha
		_typology_timer_bar.modulate = warn


func hide_typology_timer() -> void:
	if _typology_timer_bar and is_instance_valid(_typology_timer_bar):
		_typology_timer_bar.visible = false


func show_typology_badge(_typology: String) -> void:
	hide_typology_badge()


func hide_typology_badge() -> void:
	if _typology_badge and is_instance_valid(_typology_badge):
		_typology_badge.visible = false


func show_typology_event(event: String) -> void:
	var label: Label = Label.new()
	var vs: Vector2 = _ui.get_viewport_rect().size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200.0, 40.0)
	label.position = Vector2((vs.x - 200.0) / 2.0, vs.y * 0.35)
	label.add_theme_font_size_override("font_size", 20)
	if event == "critique":
		label.text = "CRITIQUE !"
		label.modulate = MerlinVisual.CRT_PALETTE.success
	else:
		label.text = "FUMBLE..."
		label.modulate = MerlinVisual.CRT_PALETTE.danger
	_ui.add_child(label)
	var tw: Tween = _ui.create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OUTCOME ANIMATIONS (shake, pulse, reaction text, life delta)
# ═══════════════════════════════════════════════════════════════════════════════

func show_reaction_text(text: String, outcome: String) -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		return
	flash_biome_for_outcome(outcome)
	_ui.switch_body_to_text()
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	_ui.card_text.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	_ui.card_text.visible_characters = -1
	_ui.card_text.modulate.a = 1.0


func show_result_text_transition(result_text: String, outcome: String) -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		return
	flash_biome_for_outcome(outcome)
	_ui.switch_body_to_text()
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_ui.card_text, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not _ui.is_inside_tree():
		return
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		match outcome:
			"critical_success":
				_ui.card_speaker.text = "Reussite critique !"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
			"success":
				_ui.card_speaker.text = "Reussite"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
			"critical_failure":
				_ui.card_speaker.text = "Echec critique..."
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
			_:
				_ui.card_speaker.text = "Echec"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	var bbcode_text: String = "[color=#%s]%s[/color]" % [color.to_html(false), result_text]
	_ui.card_text.modulate.a = 1.0
	_ui._narrator_module.typewriter_card_text(bbcode_text)


func flash_biome_for_outcome(outcome: String) -> void:
	if not _ui.biome_art_layer or not is_instance_valid(_ui.biome_art_layer):
		return
	var is_success: bool = outcome.contains("success")
	var intensity: float = 1.6 if outcome.contains("critical") else 1.3
	var tint: Color = Color(0.7, intensity, 0.7) if is_success else Color(intensity, 0.7, 0.7)
	var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_ui.biome_art_layer, "modulate", tint, 0.12)
	tw.tween_property(_ui.biome_art_layer, "modulate", Color.WHITE, 0.25)


func show_critical_badge() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	var base_style: StyleBox = _ui.card_panel.get_theme_stylebox("panel")
	if not base_style:
		return
	var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	if style:
		style.border_color = MerlinVisual.CRT_PALETTE.souffle_full
		style.set_border_width_all(3)
		_ui.card_panel.add_theme_stylebox_override("panel", style)
	_ui._critical_badge_tween = _ui.create_tween().set_loops(0)
	_ui._critical_badge_tween.tween_property(_ui.card_panel, "modulate", Color(1.15, 1.1, 0.9), 0.3)
	_ui._critical_badge_tween.tween_property(_ui.card_panel, "modulate", Color.WHITE, 0.3)


func show_biome_passive(passive: Dictionary) -> void:
	var text: String = str(passive.get("text", "Force du biome..."))
	var notif: Label = Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notif.add_theme_font_size_override("font_size", 14)
	notif.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	if _ui.body_font:
		notif.add_theme_font_override("font", _ui.body_font)
	notif.modulate.a = 0.0
	_ui.add_child(notif)
	var tw: Tween = _ui.create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(notif, "modulate:a", 0.0, 0.3)
	tw.tween_callback(notif.queue_free)


func animate_card_outcome(outcome: String) -> void:
	_ui._card_display.disable_card_3d()
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	match outcome:
		"critical_success":
			var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.08, 1.08), 0.2)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"success":
			var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.04, 1.04), 0.15)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.2)
		"failure":
			var origin_x: float = _ui._card_base_pos.x if _ui._card_base_pos != Vector2.ZERO else _ui.card_panel.position.x
			var tw: Tween = _ui.create_tween()
			for _i in range(3):
				tw.tween_property(_ui.card_panel, "position:x", origin_x + 8, 0.05).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_ui.card_panel, "position:x", origin_x - 8, 0.05).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_ui.card_panel, "position:x", origin_x, 0.05)
		"critical_failure":
			var origin_x: float = _ui._card_base_pos.x if _ui._card_base_pos != Vector2.ZERO else _ui.card_panel.position.x
			var tw: Tween = _ui.create_tween()
			for _i in range(5):
				tw.tween_property(_ui.card_panel, "position:x", origin_x + 14, 0.04).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_ui.card_panel, "position:x", origin_x - 14, 0.04).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_ui.card_panel, "position:x", origin_x, 0.04)
			tw.tween_property(_ui.card_panel, "scale", Vector2(0.97, 0.97), 0.1)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.15)


func show_milestone_popup(title_text: String, desc_text: String) -> void:
	if _ui.biome_art_layer and is_instance_valid(_ui.biome_art_layer):
		var gold_tint: Color = MerlinVisual.CRT_PALETTE["milestone_gold"]
		var tw_forest: Tween = _ui.create_tween()
		for _i in range(3):
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", gold_tint, 0.2).set_trans(Tween.TRANS_SINE)
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		_ui.card_speaker.text = title_text
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		_ui.card_speaker.add_theme_color_override("font_color", amber)
		_ui.card_speaker.visible = true
	if _ui.card_text and is_instance_valid(_ui.card_text):
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		var bbcode: String = "[color=#%s]%s[/color]" % [amber.to_html(false), desc_text]
		_ui.card_text.text = bbcode
		_ui.card_text.modulate.a = 1.0


func show_life_delta(delta: int) -> void:
	if delta == 0:
		return
	var is_damage: bool = delta < 0
	var color: Color = MerlinVisual.CRT_PALETTE.danger if is_damage else MerlinVisual.CRT_PALETTE.success
	# Stage 1: Screen flash
	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 30
	_ui.add_child(flash)
	var tw_flash: Tween = _ui.create_tween()
	tw_flash.tween_property(flash, "color:a", 0.25 if is_damage else 0.15, 0.08)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.15)
	tw_flash.tween_callback(flash.queue_free)
	# Stage 2: Camera shake (damage only)
	if is_damage and _ui.main_vbox and is_instance_valid(_ui.main_vbox):
		var base_pos: Vector2 = _ui.main_vbox.position
		var shake_tw: Tween = _ui.create_tween()
		for i in range(4):
			var intensity: float = 4.0 * (1.0 - float(i) / 4.0)
			shake_tw.tween_property(_ui.main_vbox, "position:x", base_pos.x + intensity, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:y", base_pos.y - intensity * 0.5, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:x", base_pos.x - intensity, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:y", base_pos.y + intensity * 0.5, 0.035)
		shake_tw.tween_property(_ui.main_vbox, "position", base_pos, 0.04)
	# Stage 3: Zoom life bar
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		_ui.life_panel.pivot_offset = _ui.life_panel.size * 0.5
		var tw_zoom: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_zoom.tween_property(_ui.life_panel, "scale", Vector2(1.6, 1.6), 0.2)
		tw_zoom.tween_property(_ui.life_panel, "scale", Vector2(1.0, 1.0), 0.4)
	# Stage 4: Smooth bar value tween
	if _ui._life_bar and is_instance_valid(_ui._life_bar):
		var old_val: float = _ui._life_bar.value
		var new_val: float = clampf(old_val + float(delta), 0.0, float(MerlinConstants.LIFE_ESSENCE_MAX))
		var tw_bar: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_bar.tween_property(_ui._life_bar, "value", new_val, 0.5)
	# Stage 5: BIG floating number
	var label: Label = Label.new()
	label.text = "+%d" % delta if delta > 0 else "%d" % delta
	if _ui.title_font:
		label.add_theme_font_override("font", _ui.title_font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 25
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		var bar_global: Vector2 = _ui.life_panel.global_position
		label.position = Vector2(bar_global.x + _ui.life_panel.size.x * 0.5 - 30, bar_global.y - 10)
	else:
		label.position = Vector2(_ui.size.x * 0.5 - 40, _ui.size.y * 0.15)
	label.pivot_offset = Vector2(30, 24)
	label.scale = Vector2(0.3, 0.3)
	_ui.add_child(label)
	var tw_num: Tween = _ui.create_tween()
	tw_num.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_num.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tw_num.tween_property(label, "position:y", label.position.y - 80.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw_num.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw_num.tween_callback(label.queue_free)


func show_progressive_indicators() -> void:
	var essence_panel: Control = _ui._essence_counter.get_parent() if _ui._essence_counter and is_instance_valid(_ui._essence_counter) else null
	if _ui._top_status_bar and is_instance_valid(_ui._top_status_bar):
		_ui._top_status_bar.modulate.a = 1.0
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		_ui.life_panel.modulate.a = 0.0
	if _ui.souffle_panel and is_instance_valid(_ui.souffle_panel):
		_ui.souffle_panel.modulate.a = 0.0
	if essence_panel and is_instance_valid(essence_panel):
		essence_panel.modulate.a = 0.0
	await _ui.get_tree().create_timer(0.15).timeout
	if not _ui.is_inside_tree():
		return
	var pca: Node = _ui.get_node_or_null("/root/PixelContentAnimator")
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		if pca:
			pca.reveal(_ui.life_panel, {"duration": 0.3, "block_size": 6})
			await _ui.get_tree().create_timer(0.32).timeout
		else:
			_ui.life_panel.modulate.a = 1.0
	if _ui.souffle_panel and is_instance_valid(_ui.souffle_panel):
		SFXManager.play("ogham_chime")
		if pca:
			pca.reveal(_ui.souffle_panel, {"duration": 0.35, "block_size": 6})
			await _ui.get_tree().create_timer(0.38).timeout
		else:
			_ui.souffle_panel.modulate.a = 1.0
	if essence_panel and is_instance_valid(essence_panel):
		if pca:
			pca.reveal(essence_panel, {"duration": 0.28, "block_size": 6})
			await _ui.get_tree().create_timer(0.3).timeout
		else:
			essence_panel.modulate.a = 1.0
