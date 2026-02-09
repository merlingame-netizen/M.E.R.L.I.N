## MG_RUNE_CACHEE — Rune Cachée (Observation)
## Grid of 4x4 identical symbols. One is different. Find it before timeout.

extends MiniGameBase

const GRID_SIZE: int = 4
const SYMBOLS := ["◯", "△", "□", "◇", "☆", "✦", "⬡", "◈"]
var _correct_index: int = -1
var _timer: float = 4.0
var _buttons: Array[Button] = []
var _timer_label: Label


func _on_start() -> void:
	_build_overlay()

	# Difficulty affects time
	_timer = 5.0 - (_difficulty * 0.25)  # 4.75s to 2.5s

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -260
	vbox.offset_right = 220
	vbox.offset_bottom = 260
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	var title := _make_label("RUNE CACHÉE", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Trouve le symbole différent!", 16)
	vbox.add_child(subtitle)

	# Timer
	_timer_label = _make_label("Temps: %.1f s" % _timer, 18, MG_PALETTE.red)
	vbox.add_child(_timer_label)

	# Grid container
	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	# Pick symbols
	var normal_symbol: String = SYMBOLS[randi() % SYMBOLS.size()]
	var odd_symbol: String

	# Higher difficulty = more similar symbols
	if _difficulty >= 7:
		# Very similar (same category)
		odd_symbol = SYMBOLS[(SYMBOLS.find(normal_symbol) + 1) % SYMBOLS.size()]
	else:
		# Different enough
		odd_symbol = SYMBOLS[(randi() % (SYMBOLS.size() - 1)) + 1]
		while odd_symbol == normal_symbol:
			odd_symbol = SYMBOLS[randi() % SYMBOLS.size()]

	_correct_index = randi() % (GRID_SIZE * GRID_SIZE)

	# Create buttons
	for i in range(GRID_SIZE * GRID_SIZE):
		var symbol: String = odd_symbol if i == _correct_index else normal_symbol
		var btn := Button.new()
		btn.text = symbol
		btn.custom_minimum_size = Vector2(80, 80)
		btn.add_theme_font_size_override("font_size", 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_rune_clicked.bind(i))
		_buttons.append(btn)
		grid.add_child(btn)


func _process(delta: float) -> void:
	if _finished:
		return

	_timer -= delta
	_timer_label.text = "Temps: %.1f s" % maxf(_timer, 0.0)

	if _timer <= 0:
		_fail_game()


func _on_rune_clicked(index: int) -> void:
	if _finished:
		return

	if index == _correct_index:
		# Success
		_buttons[index].modulate = MG_PALETTE.green

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_success")

		await get_tree().create_timer(0.3).timeout
		_complete(true, 100)
	else:
		# Wrong
		_buttons[index].modulate = MG_PALETTE.red

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_fail")

		await get_tree().create_timer(0.3).timeout
		_fail_game()


func _fail_game() -> void:
	# Reveal correct answer
	if _correct_index >= 0 and _correct_index < _buttons.size():
		_buttons[_correct_index].modulate = MG_PALETTE.gold

	await get_tree().create_timer(0.5).timeout
	_complete(false, 0)
