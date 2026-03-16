class_name MenuPrincipalAnimations
extends RefCounted

## Entry animations, card float, button cascade, hover effects, swipe transitions.

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _host: Control
var _card: PanelContainer
var _title_label: Label
var _main_buttons: VBoxContainer
var _celtic_ornament_top: Label
var _celtic_ornament_bottom: Label

var card_target_pos := Vector2.ZERO
var swipe_in_progress := false

var _entry_tween: Tween
var _swipe_tween: Tween
var _card_float_tween: Tween
var _cta_pulse_tween: Tween
var _corner_hover_tweens: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func init(
	host: Control,
	card_node: PanelContainer,
	title_label: Label,
	main_buttons: VBoxContainer,
	celtic_top: Label,
	celtic_bottom: Label,
) -> void:
	_host = host
	_card = card_node
	_title_label = title_label
	_main_buttons = main_buttons
	_celtic_ornament_top = celtic_top
	_celtic_ornament_bottom = celtic_bottom

# ---------------------------------------------------------------------------
# Entry animation
# ---------------------------------------------------------------------------

func play_entry(matrix_bg: Control) -> void:
	if not _card:
		return

	# Fade in matrix background
	if is_instance_valid(matrix_bg):
		var matrix_tween := _host.create_tween()
		matrix_tween.tween_property(matrix_bg, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)

	var sfx := _host.get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("scene_transition")

	# Initial state: card invisible, below + slightly scaled down
	_card.position.y = card_target_pos.y + 80
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.9, 0.9)

	# Title invisible for letter reveal
	if _title_label:
		_title_label.modulate.a = 0.0
		_title_label.scale = Vector2(0.7, 0.7)
		_title_label.pivot_offset = _title_label.size * 0.5

	# Ornaments invisible
	if _celtic_ornament_top:
		_celtic_ornament_top.modulate.a = 0.0
		_celtic_ornament_top.position.y -= 20
	if _celtic_ornament_bottom:
		_celtic_ornament_bottom.modulate.a = 0.0
		_celtic_ornament_bottom.position.y += 20

	# Buttons hidden
	for btn in _main_buttons.get_children():
		if btn is Button:
			btn.modulate.a = 0.0

	# Animation sequence
	if _entry_tween:
		_entry_tween.kill()
	_entry_tween = _host.create_tween()

	# Phase 1: Ornaments slide in + fade
	var orn_top_target_y: float = _celtic_ornament_top.position.y + 20 if _celtic_ornament_top else 0.0
	var orn_bot_target_y: float = _celtic_ornament_bottom.position.y - 20 if _celtic_ornament_bottom else 0.0
	_entry_tween.tween_property(_celtic_ornament_top, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(_celtic_ornament_top, "position:y", orn_top_target_y, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(_celtic_ornament_bottom, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_entry_tween.parallel().tween_property(_celtic_ornament_bottom, "position:y", orn_bot_target_y, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Phase 2: Card rises + fades in + scales to full
	_entry_tween.parallel().tween_property(_card, "position:y", card_target_pos.y, 0.9) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	_entry_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.15)
	_entry_tween.parallel().tween_property(_card, "scale", Vector2(1.0, 1.0), 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

	# Phase 3: Title dramatic scale-in with overshoot
	_entry_tween.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.5)
	_entry_tween.parallel().tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5)

	# Phase 4: Buttons cascade entry
	_entry_tween.tween_callback(func(): _animate_buttons_entry())
	# Phase 5: Start floating bob on card
	_entry_tween.tween_callback(func(): _start_card_float())

# ---------------------------------------------------------------------------
# Card float
# ---------------------------------------------------------------------------

func _start_card_float() -> void:
	var float_tween := _host.create_tween().set_loops()
	var base_y: float = _card.position.y
	float_tween.tween_property(_card, "position:y", base_y - 4.0, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(_card, "position:y", base_y + 4.0, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
# Button cascade
# ---------------------------------------------------------------------------

func _animate_buttons_entry() -> void:
	var sfx := _host.get_node_or_null("/root/SFXManager")
	var delay := 0.0
	var primary_btn: Button = null
	var idx := 0
	for btn in _main_buttons.get_children():
		if btn is Button:
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.85, 0.85)
			var slide_offset := -60.0 - idx * 15.0
			var base_x: float = btn.position.x
			btn.position.x = base_x + slide_offset

			var tween := _host.create_tween()
			tween.tween_interval(delay)
			tween.tween_callback(func():
				if sfx and sfx.has_method("play_varied"):
					sfx.play_varied("button_appear", 0.15)
			)
			tween.tween_property(btn, "position:x", base_x, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.35) \
				.set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			if btn.get_meta("priority", "") == "primary":
				primary_btn = btn
			delay += 0.12
			idx += 1

	if primary_btn:
		_start_cta_pulse.call_deferred(primary_btn)


func _start_cta_pulse(btn: Button) -> void:
	var pulse := _host.create_tween().set_loops()
	pulse.tween_property(btn, "scale", Vector2(1.03, 1.03), 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(btn, "scale", Vector2(1.0, 1.0), 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
# Hover effects
# ---------------------------------------------------------------------------

func on_button_hover(btn: Button, hovering: bool) -> void:
	if hovering:
		_play_ui_sound("hover")
		var tween := _host.create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "position:y", btn.position.y - 2.0, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var tween := _host.create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "position:y", btn.position.y + 2.0, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func on_corner_button_hover(btn: Button, hovering: bool) -> void:
	if _corner_hover_tweens.has(btn) and _corner_hover_tweens[btn]:
		_corner_hover_tweens[btn].kill()
	var tween := _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_corner_hover_tweens[btn] = tween
	if hovering:
		tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.2)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)

# ---------------------------------------------------------------------------
# Swipe transition
# ---------------------------------------------------------------------------

func play_swipe(dir: float) -> void:
	if _swipe_tween:
		_swipe_tween.kill()
	var angle := deg_to_rad(5.0) * dir
	var offset := Vector2(120.0 * dir, -8.0)
	_swipe_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_swipe_tween.tween_property(_card, "rotation", angle, 0.25)
	_swipe_tween.parallel().tween_property(_card, "position", _card.position + offset, 0.25)
	_swipe_tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.2)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _play_ui_sound(sound_name: String) -> void:
	var sfx := _host.get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play(sound_name)
