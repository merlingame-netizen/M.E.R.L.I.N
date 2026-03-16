## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlay Dice — Dice roll, minigame intro, score-to-D20 display
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlayDice

var _ui: MerlinGameUI

# Dice overlay state
var _dice_overlay: Control = null
var _dice_display: Label = null
var _dice_dc_label: Label = null
var _dice_result_label: Label = null
var _dice_bg_panel: PanelContainer = null

const MINIGAME_FIELD_ICONS: Dictionary = {
	"combat": "\u2694",
	"exploration": "\uD83D\uDD0D",
	"mysticisme": "\u2728",
	"survie": "\u2605",
	"diplomatie": "\u2696",
}


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


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
