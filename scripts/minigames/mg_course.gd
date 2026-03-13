## MG_COURSE — Course Druidique (Vigueur)
## Mash SPACE as fast as possible to fill a progress bar before timeout.
## Score = progress percentage. Difficulty affects required taps and time.

extends MiniGameBase

var _taps: int = 0
var _required_taps: int = 20
var _time_left: float = 5.0
var _max_time: float = 5.0
var _game_over: bool = false

var _progress_rect: ColorRect
var _progress_bg: ColorRect
var _tap_label: Label
var _timer_label: Label
var _status_label: Label

const BAR_WIDTH: float = 350.0
const BAR_HEIGHT: float = 30.0


func _on_start() -> void:
	_build_overlay()

	_required_taps = 15 + (_difficulty * 3)
	_max_time = 6.0 - (_difficulty * 0.2)
	_max_time = maxf(_max_time, 3.0)
	_time_left = _max_time

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -200
	vbox.offset_right = 220
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title := _make_label("COURSE DRUIDIQUE", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Martèle ESPACE le plus vite possible!", 16)
	vbox.add_child(subtitle)

	_timer_label = _make_label("Temps: %.1f s" % _time_left, 20, MG_PALETTE.gold)
	vbox.add_child(_timer_label)

	# Progress bar
	var bar_center := CenterContainer.new()
	bar_center.custom_minimum_size = Vector2(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	vbox.add_child(bar_center)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_center.add_child(bar_container)

	_progress_bg = ColorRect.new()
	_progress_bg.color = MG_PALETTE.paper
	_progress_bg.position = Vector2.ZERO
	_progress_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_container.add_child(_progress_bg)

	_progress_rect = ColorRect.new()
	_progress_rect.color = MG_PALETTE.green
	_progress_rect.position = Vector2.ZERO
	_progress_rect.size = Vector2(0, BAR_HEIGHT)
	bar_container.add_child(_progress_rect)

	_tap_label = _make_label("0 / %d" % _required_taps, 22, MG_PALETTE.ink)
	vbox.add_child(_tap_label)

	_status_label = _make_label("", 20, MG_PALETTE.green)
	vbox.add_child(_status_label)


func _process(delta: float) -> void:
	if _finished or _game_over:
		return

	_time_left -= delta
	_timer_label.text = "Temps: %.1f s" % maxf(_time_left, 0.0)

	if _time_left < 1.5:
		_timer_label.modulate = MG_PALETTE.red

	if _time_left <= 0:
		_game_over = true
		_end_game()


func _on_key_pressed(keycode: int) -> void:
	if _game_over:
		return

	if keycode == KEY_SPACE:
		_taps += 1
		var progress: float = minf(float(_taps) / float(_required_taps), 1.0)
		_progress_rect.size.x = progress * BAR_WIDTH
		_tap_label.text = "%d / %d" % [mini(_taps, _required_taps), _required_taps]

		# Color ramp
		if progress >= 1.0:
			_progress_rect.color = MG_PALETTE.gold
		elif progress >= 0.6:
			_progress_rect.color = MG_PALETTE.green
		else:
			_progress_rect.color = MG_PALETTE.accent

		if _taps >= _required_taps:
			_game_over = true
			_end_game()


func _end_game() -> void:
	var progress: float = minf(float(_taps) / float(_required_taps), 1.0)
	var base_score: int = int(progress * 70.0)

	var time_bonus: int = 0
	if _taps >= _required_taps and _time_left > 0:
		var time_ratio: float = clampf(_time_left / _max_time, 0.0, 1.0)
		time_bonus = int(time_ratio * 30.0)

	var score: int = clampi(base_score + time_bonus, 0, 100)
	var success: bool = progress >= 0.7

	_status_label.text = "Terminé! (%d pts)" % score if success else "Trop lent... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
