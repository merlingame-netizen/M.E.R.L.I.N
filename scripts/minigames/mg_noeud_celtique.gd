## MG_NOEUD_CELTIQUE — Noeud Celtique (Logique)
## 3 paths labeled A, B, C. One leads to destination. Visual hint shows correct path.
## Player picks one. 2 rounds.

extends MiniGameBase

var _round: int = 0
const MAX_ROUNDS: int = 2
var _correct_path: String = ""
var _score_total: int = 0
var _paths := ["A", "B", "C"]
var _path_colors := {}
var _button_container: HBoxContainer


func _on_start() -> void:
	_build_overlay()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_top = -220
	vbox.offset_right = 250
	vbox.offset_bottom = 220
	vbox.add_theme_constant_override("separation", 25)
	add_child(vbox)

	# Title
	var title := _make_label("NOEUD CELTIQUE", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Suis le chemin doré vers la destination", 16)
	vbox.add_child(subtitle)

	# Round label
	var round_lbl := _make_label("", 18)
	round_lbl.name = "RoundLabel"
	vbox.add_child(round_lbl)

	# Path visual (simple colored bars)
	var path_container := HBoxContainer.new()
	path_container.alignment = BoxContainer.ALIGNMENT_CENTER
	path_container.add_theme_constant_override("separation", 20)
	path_container.name = "PathContainer"
	vbox.add_child(path_container)

	# Buttons
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 15)
	vbox.add_child(_button_container)

	_next_round()


func _next_round() -> void:
	_round += 1

	if _round > MAX_ROUNDS:
		_finish_game()
		return

	# Pick correct path
	_correct_path = _paths[randi() % _paths.size()]

	# Update round label
	var lbl := get_node_or_null("VBoxContainer/RoundLabel") as Label
	if lbl:
		lbl.text = "Manche %d/%d" % [_round, MAX_ROUNDS]

	# Assign colors (correct = gold, others = grey)
	_path_colors.clear()
	for path in _paths:
		if path == _correct_path:
			_path_colors[path] = MG_PALETTE.gold
		else:
			_path_colors[path] = MG_PALETTE.accent

	# Update path visual
	var path_container := get_node_or_null("VBoxContainer/PathContainer") as HBoxContainer
	if path_container:
		for child in path_container.get_children():
			child.queue_free()

		for path in _paths:
			var path_vis := VBoxContainer.new()
			path_vis.add_theme_constant_override("separation", 8)

			var path_lbl := _make_label(path, 24, MG_PALETTE.ink)
			path_vis.add_child(path_lbl)

			var color_bar := ColorRect.new()
			color_bar.color = _path_colors[path]
			color_bar.custom_minimum_size = Vector2(80, 120)
			path_vis.add_child(color_bar)

			path_container.add_child(path_vis)

	# Clear and recreate buttons
	for child in _button_container.get_children():
		child.queue_free()

	for path in _paths:
		var btn := _make_button(path, _on_path_chosen.bind(path))
		_button_container.add_child(btn)

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")


func _on_key_pressed(keycode: int) -> void:
	# Keys 1-3 map to paths A, B, C
	if keycode >= KEY_1 and keycode <= KEY_3:
		var path_index: int = keycode - KEY_1
		if path_index < _paths.size():
			_on_path_chosen(_paths[path_index])


func _on_path_chosen(path: String) -> void:
	if _finished:
		return

	# Disable all buttons
	for btn in _button_container.get_children():
		if btn is Button:
			btn.disabled = true

	var correct: bool = (path == _correct_path)

	if correct:
		_score_total += 50

		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_success")
	else:
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_fail")

	await get_tree().create_timer(0.8).timeout
	_next_round()


func _finish_game() -> void:
	var success: bool = _score_total >= 50
	_complete(success, _score_total)
