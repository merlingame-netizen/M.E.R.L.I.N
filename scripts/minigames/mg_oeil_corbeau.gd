extends MiniGameBase
## Oeil du Corbeau — Spot the different symbol in a 3x3 grid (observation-based)

const SYMBOLS: Array[String] = ["\u25b2", "\u25cf", "\u25a0", "\u2726", "\u25c6", "\u25bc", "\u25cb", "\u25a1"]

var grid_cells: Array[Button] = []
var different_index: int = -1
var time_left: float = 5.0
var max_time: float = 5.0
var game_over: bool = false

var timer_label: Label
var grid_container: GridContainer

func _on_start() -> void:
	_build_overlay()
	_calculate_time()
	_build_ui()
	_generate_grid()

func _calculate_time() -> void:
	# Time decreases with difficulty
	max_time = 5.0 - (_difficulty * 0.3)
	max_time = maxf(2.0, max_time)
	time_left = max_time

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(350, 100)
	vbox.custom_minimum_size = Vector2(500, 650)
	add_child(vbox)

	var title: Label = _make_label("Œil du Corbeau", 32, MG_PALETTE.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_spacer(20))

	var desc: Label = _make_label("Trouvez le symbole différent !", 20, MG_PALETTE.ink)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	vbox.add_child(_make_spacer(30))

	# Timer
	timer_label = _make_label("Temps : " + str(snappedf(time_left, 0.1)) + "s", 24, MG_PALETTE.accent)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(timer_label)

	vbox.add_child(_make_spacer(30))

	# Grid container
	grid_container = GridContainer.new()
	grid_container.columns = 3
	grid_container.add_theme_constant_override("h_separation", 15)
	grid_container.add_theme_constant_override("v_separation", 15)
	vbox.add_child(grid_container)

func _make_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _generate_grid() -> void:
	# Pick main symbol and different symbol
	var main_symbol: String = SYMBOLS[randi() % SYMBOLS.size()]
	var diff_symbol: String = SYMBOLS[randi() % SYMBOLS.size()]
	while diff_symbol == main_symbol:
		diff_symbol = SYMBOLS[randi() % SYMBOLS.size()]

	# Place different symbol randomly
	different_index = randi() % 9

	# Create 9 cells
	for i in range(9):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(120, 120)
		button.text = diff_symbol if i == different_index else main_symbol

		# Style button
		var font_size: int = 48
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_color_override("font_color", MG_PALETTE.ink)
		button.add_theme_color_override("font_hover_color", MG_PALETTE.accent)
		button.add_theme_color_override("font_pressed_color", MG_PALETTE.gold)

		button.pressed.connect(_on_cell_clicked.bind(i))
		grid_container.add_child(button)
		grid_cells.append(button)

	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_start")

func _process(delta: float) -> void:
	if game_over:
		return

	time_left -= delta
	timer_label.text = "Temps : " + str(snappedf(maxf(0, time_left), 0.1)) + "s"

	# Color warning
	if time_left < 2.0:
		timer_label.modulate = MG_PALETTE.red
	elif time_left < 3.5:
		timer_label.modulate = MG_PALETTE.gold

	# Timeout
	if time_left <= 0.0:
		_game_over(false)

func _on_key_pressed(keycode: int) -> void:
	# Keys 1-9 map to grid cells
	if keycode >= KEY_1 and keycode <= KEY_9:
		var cell_index: int = keycode - KEY_1
		if cell_index < grid_cells.size():
			_on_cell_clicked(cell_index)


func _on_cell_clicked(index: int) -> void:
	if game_over:
		return

	game_over = true

	# Disable all buttons
	for button in grid_cells:
		button.disabled = true

	# Check if correct
	var correct: bool = index == different_index

	if correct:
		grid_cells[index].add_theme_color_override("font_color", MG_PALETTE.green)
		_game_over(true)
	else:
		grid_cells[index].add_theme_color_override("font_color", MG_PALETTE.red)
		grid_cells[different_index].add_theme_color_override("font_color", MG_PALETTE.gold)
		_game_over(false)

func _game_over(success: bool) -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_success" if success else "minigame_fail")

	# Proportional scoring: base 50 for correct + time bonus (up to 50)
	# Failure: partial credit based on difficulty (15-30)
	var score: int = 0
	if success:
		var time_ratio: float = clampf(time_left / max_time, 0.0, 1.0)
		var time_bonus: int = int(time_ratio * 50.0)
		score = 50 + time_bonus
	else:
		score = clampi(int(_difficulty * 2.5), 15, 30)

	timer_label.text = "Trouvé ! (%d pts)" % score if success else "Raté... (%d pts)" % score
	timer_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(2.0).timeout
	_complete(success, score)
