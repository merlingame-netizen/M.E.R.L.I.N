## MG_SANG_FROID — Sang-Froid (Vigueur)
## Hold a key while a bar fills. Release too early or too late = lower score.
## The bar has a sweet spot zone. Difficulty affects bar speed and sweet spot size.

extends MiniGameBase

var _bar_value: float = 0.0
var _bar_speed: float = 0.3
var _sweet_min: float = 0.65
var _sweet_max: float = 0.85
var _holding: bool = false
var _released: bool = false
var _hold_start_ms: int = 0

var _bar_rect: ColorRect
var _fill_rect: ColorRect
var _sweet_rect: ColorRect
var _status_label: Label
var _instruction_label: Label

const BAR_WIDTH: float = 300.0
const BAR_HEIGHT: float = 40.0


func _on_start() -> void:
	_build_overlay()

	_bar_speed = 0.2 + (_difficulty * 0.05)
	var sweet_size: float = 0.25 - (_difficulty * 0.015)
	sweet_size = maxf(sweet_size, 0.08)
	_sweet_min = 0.6 + randf() * 0.15
	_sweet_max = _sweet_min + sweet_size

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -200
	vbox.offset_right = 220
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var title := _make_label("SANG-FROID", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	_instruction_label = _make_label("Maintiens ESPACE pour remplir la barre!", 16)
	vbox.add_child(_instruction_label)

	_status_label = _make_label("Vise la zone dorée!", 20, MG_PALETTE.gold)
	vbox.add_child(_status_label)

	# Bar container
	var bar_center := CenterContainer.new()
	bar_center.custom_minimum_size = Vector2(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	vbox.add_child(bar_center)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_center.add_child(bar_container)

	# Background bar
	_bar_rect = ColorRect.new()
	_bar_rect.color = MG_PALETTE.paper
	_bar_rect.position = Vector2.ZERO
	_bar_rect.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_container.add_child(_bar_rect)

	# Sweet spot zone
	_sweet_rect = ColorRect.new()
	_sweet_rect.color = Color(MG_PALETTE.gold.r, MG_PALETTE.gold.g, MG_PALETTE.gold.b, 0.3)
	_sweet_rect.position = Vector2(_sweet_min * BAR_WIDTH, 0)
	_sweet_rect.size = Vector2((_sweet_max - _sweet_min) * BAR_WIDTH, BAR_HEIGHT)
	bar_container.add_child(_sweet_rect)

	# Fill bar
	_fill_rect = ColorRect.new()
	_fill_rect.color = MG_PALETTE.green
	_fill_rect.position = Vector2.ZERO
	_fill_rect.size = Vector2(0, BAR_HEIGHT)
	bar_container.add_child(_fill_rect)

	var hint := _make_label("ESPACE pour maintenir, relâche dans la zone dorée", 14, MG_PALETTE.ink)
	vbox.add_child(hint)


func _process(delta: float) -> void:
	if _finished or _released:
		return

	if _holding:
		_bar_value += _bar_speed * delta
		_bar_value = minf(_bar_value, 1.0)
		_fill_rect.size.x = _bar_value * BAR_WIDTH

		# Color feedback
		if _bar_value >= _sweet_min and _bar_value <= _sweet_max:
			_fill_rect.color = MG_PALETTE.gold
		elif _bar_value > _sweet_max:
			_fill_rect.color = MG_PALETTE.red

		# Auto-fail at max
		if _bar_value >= 1.0:
			_release()


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE and not _holding and not _released:
		_holding = true
		_hold_start_ms = Time.get_ticks_msec()
		_instruction_label.text = "Maintiens... relâche dans la zone dorée!"


func _unhandled_input(event: InputEvent) -> void:
	if _finished or _released:
		return

	if event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE and _holding:
		_release()
		return

	super._unhandled_input(event)


func _release() -> void:
	if _released:
		return
	_released = true
	_holding = false

	var score: int = 0
	var success: bool = false

	if _bar_value >= _sweet_min and _bar_value <= _sweet_max:
		# Perfect zone
		var sweet_center: float = (_sweet_min + _sweet_max) / 2.0
		var precision: float = 1.0 - absf(_bar_value - sweet_center) / ((_sweet_max - _sweet_min) / 2.0)
		score = 70 + int(precision * 30.0)
		success = true
		_fill_rect.color = MG_PALETTE.green
		_status_label.text = "Parfait! (%d pts)" % score
		_status_label.modulate = MG_PALETTE.green
	elif _bar_value > _sweet_max:
		# Overshoot
		var overshoot: float = (_bar_value - _sweet_max) / (1.0 - _sweet_max)
		score = clampi(int(50.0 * (1.0 - overshoot)), 10, 50)
		_fill_rect.color = MG_PALETTE.red
		_status_label.text = "Trop fort! (%d pts)" % score
		_status_label.modulate = MG_PALETTE.red
	else:
		# Undershoot
		var undershoot: float = _bar_value / _sweet_min
		score = clampi(int(40.0 * undershoot), 5, 40)
		_fill_rect.color = MG_PALETTE.red
		_status_label.text = "Trop tôt! (%d pts)" % score
		_status_label.modulate = MG_PALETTE.red

	await get_tree().create_timer(1.5).timeout
	_complete(success, score)
