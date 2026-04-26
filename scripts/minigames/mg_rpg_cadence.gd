extends MiniGameBase
## RPG Cadence — Souffle test. Press SPACE/click on the highlighted word as it scrolls.
## Score 0-100 by hit timing precision. Used in walk_event_overlay card body.

const HIT_WINDOW_MS: int = 350           # +/- 175ms hit window
const TOTAL_BEATS: int = 5
const BEAT_INTERVAL_MS: int = 850

var _beats: Array[int] = []               # ms timestamps relative to start
var _beat_index: int = 0
var _hits: Array[bool] = []
var _phrase_label: Label
var _highlight_label: Label
var _progress_label: Label
var _phrase_words: Array[String] = [
	"Le", "souffle", "monte", "et", "porte", "ton", "pas", "vers", "le", "seuil"
]


func _on_start() -> void:
	for i in TOTAL_BEATS:
		_beats.append((i + 1) * BEAT_INTERVAL_MS)
		_hits.append(false)
	_build()
	_tick()


func _build() -> void:
	if not _in_card_mode:
		_build_overlay()
	custom_minimum_size = Vector2(0, 120)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var hint: Label = Label.new()
	hint.text = "[SPACE] sur les mots-cles"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.30, 0.15))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	_phrase_label = Label.new()
	_phrase_label.add_theme_font_size_override("font_size", 18)
	_phrase_label.add_theme_color_override("font_color", Color(0.22, 0.13, 0.07))
	_phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phrase_label.text = " ".join(_phrase_words)
	vbox.add_child(_phrase_label)
	_highlight_label = Label.new()
	_highlight_label.add_theme_font_size_override("font_size", 22)
	_highlight_label.add_theme_color_override("font_color", Color(0.65, 0.13, 0.10))
	_highlight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_highlight_label)
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", Color(0.45, 0.28, 0.12))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_progress_label)


func _tick() -> void:
	while _started and not _finished:
		await get_tree().create_timer(0.05).timeout
		if _finished:
			return
		var now: int = Time.get_ticks_msec() - _start_time_ms
		# Update highlight when within hit window of next beat
		if _beat_index < _beats.size():
			var target: int = _beats[_beat_index]
			var diff: int = abs(now - target)
			if diff <= HIT_WINDOW_MS / 2:
				_highlight_label.text = "♦ %s ♦" % _phrase_words[(_beat_index * 2) % _phrase_words.size()]
			elif now > target + HIT_WINDOW_MS / 2:
				# Missed this beat
				_beat_index += 1
				_highlight_label.text = ""
				_progress_label.text = "Cadence : %d/%d" % [_beat_index, TOTAL_BEATS]
				if _beat_index >= TOTAL_BEATS:
					_finalize()
					return
			else:
				_highlight_label.text = ""


func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_SPACE:
		_register_hit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_register_hit()


func _register_hit() -> void:
	if _beat_index >= _beats.size():
		return
	var now: int = Time.get_ticks_msec() - _start_time_ms
	var target: int = _beats[_beat_index]
	var diff: int = abs(now - target)
	if diff <= HIT_WINDOW_MS:
		_hits[_beat_index] = true
	_beat_index += 1
	_progress_label.text = "Cadence : %d/%d" % [_beat_index, TOTAL_BEATS]
	if _beat_index >= TOTAL_BEATS:
		_finalize()


func _finalize() -> void:
	var hit_count: int = 0
	for h in _hits:
		if h: hit_count += 1
	var score: int = int(round(float(hit_count) / float(TOTAL_BEATS) * 100.0))
	var success: bool = hit_count >= 4
	_complete(success, score)
