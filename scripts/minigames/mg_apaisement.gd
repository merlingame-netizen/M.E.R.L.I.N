## MG_APAISEMENT — Apaisement (Esprit)
## Rhythm breathing: a circle pulses. Press SPACE in sync with the pulse.
## 5 beats. Score based on timing accuracy.

extends MiniGameBase

const BEAT_COUNT: int = 5

var _beat_interval: float = 1.5
var _beat_timer: float = 0.0
var _beat_phase: float = 0.0
var _current_beat: int = 0
var _scores: Array[int] = []
var _can_press: bool = true

var _circle_rect: ColorRect
var _status_label: Label
var _timing_label: Label
var _beat_label: Label


func _on_start() -> void:
	_build_overlay()

	_beat_interval = 1.8 - (_difficulty * 0.08)
	_beat_interval = maxf(_beat_interval, 0.9)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -220
	vbox.offset_right = 220
	vbox.offset_bottom = 220
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	var title := _make_label("APAISEMENT", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Respire avec le rythme. ESPACE au sommet!", 16)
	vbox.add_child(subtitle)

	_status_label = _make_label("Observe le rythme...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	# Pulsing circle (simulated with ColorRect + scale)
	var circle_center := CenterContainer.new()
	circle_center.custom_minimum_size = Vector2(120, 120)
	vbox.add_child(circle_center)

	_circle_rect = ColorRect.new()
	_circle_rect.color = MG_PALETTE.accent
	_circle_rect.custom_minimum_size = Vector2(80, 80)
	_circle_rect.pivot_offset = Vector2(40, 40)
	circle_center.add_child(_circle_rect)

	_timing_label = _make_label("", 24, MG_PALETTE.green)
	vbox.add_child(_timing_label)

	_beat_label = _make_label("Beat: 0/%d" % BEAT_COUNT, 18, MG_PALETTE.ink)
	vbox.add_child(_beat_label)

	var hint := _make_label("ESPACE quand le carré est au maximum", 14, MG_PALETTE.ink)
	vbox.add_child(hint)

	# Let player observe 2 pulses before starting
	_beat_timer = 0.0
	_current_beat = -2


func _process(delta: float) -> void:
	if _finished:
		return

	_beat_timer += delta
	_beat_phase = fmod(_beat_timer, _beat_interval) / _beat_interval

	# Pulse: scale from 0.6 to 1.4 using sine
	var pulse: float = 0.6 + 0.8 * sin(_beat_phase * PI)
	if is_instance_valid(_circle_rect):
		_circle_rect.scale = Vector2(pulse, pulse)

		# Color feedback: bright at peak
		var brightness: float = sin(_beat_phase * PI)
		_circle_rect.color = MG_PALETTE.accent.lerp(MG_PALETTE.gold, brightness)

	# Track beats (peak at phase ~0.5)
	if _beat_phase < 0.1 and _can_press == false:
		_can_press = true
		if _current_beat >= 0:
			_beat_label.text = "Beat: %d/%d" % [mini(_current_beat + 1, BEAT_COUNT), BEAT_COUNT]


func _on_key_pressed(keycode: int) -> void:
	if keycode != KEY_SPACE or not _can_press:
		return

	_can_press = false
	_current_beat += 1

	if _current_beat <= 0:
		# Still in observation phase
		_timing_label.text = "Observe encore..."
		_timing_label.modulate = MG_PALETTE.ink
		return

	if _current_beat > BEAT_COUNT:
		return

	# Calculate timing accuracy (peak is at phase 0.5)
	var distance: float = absf(_beat_phase - 0.5)
	var accuracy: int = 0

	if distance < 0.08:
		accuracy = 100
		_timing_label.text = "Parfait!"
		_timing_label.modulate = MG_PALETTE.gold
	elif distance < 0.15:
		accuracy = 75
		_timing_label.text = "Bien!"
		_timing_label.modulate = MG_PALETTE.green
	elif distance < 0.25:
		accuracy = 40
		_timing_label.text = "Passable"
		_timing_label.modulate = MG_PALETTE.accent
	else:
		accuracy = 10
		_timing_label.text = "Raté"
		_timing_label.modulate = MG_PALETTE.red

	_scores.append(accuracy)

	if _current_beat >= BEAT_COUNT:
		_finish_game()


func _finish_game() -> void:
	if _scores.is_empty():
		_complete(false, 10)
		return

	var total: int = 0
	for s in _scores:
		total += s
	var score: int = clampi(int(float(total) / float(_scores.size())), 0, 100)
	var success: bool = score >= 50

	_status_label.text = "Apaisé! (%d pts)" % score if success else "Agité... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
