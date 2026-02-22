extends MiniGameBase
## Negociation — Find the hidden sweet spot on a slider (bluff-based)

var sweet_spot: int = 50
var current_attempt: int = 0
var max_attempts: int = 2
var best_score: int = 0

var attempt_label: Label
var slider: HSlider
var value_label: Label
var confirm_button: Button
var feedback_label: Label

func _on_start() -> void:
	_build_overlay()
	_setup_sweet_spot()
	_build_ui()

func _setup_sweet_spot() -> void:
	# Sweet spot between 30-70 initially
	sweet_spot = 30 + randi() % 41

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(300, 150)
	vbox.custom_minimum_size = Vector2(600, 500)
	add_child(vbox)

	var title: Label = _make_label("Négociation", 32, MG_PALETTE.gold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_spacer(20))

	var desc: Label = _make_label("Trouvez le prix idéal pour conclure l'accord.", 18, MG_PALETTE.ink)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(550, 40)
	vbox.add_child(desc)

	vbox.add_child(_make_spacer(20))

	attempt_label = _make_label("Tentative 1/2", 20, MG_PALETTE.ink)
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(attempt_label)

	vbox.add_child(_make_spacer(40))

	# Slider
	slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = 50
	slider.custom_minimum_size = Vector2(500, 40)
	slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(slider)

	vbox.add_child(_make_spacer(10))

	# Value display
	value_label = _make_label("50", 28, MG_PALETTE.accent)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)

	vbox.add_child(_make_spacer(40))

	# Confirm button
	confirm_button = _make_button("CONFIRMER L'OFFRE", _on_confirm_pressed)
	confirm_button.custom_minimum_size = Vector2(350, 60)
	vbox.add_child(confirm_button)

	vbox.add_child(_make_spacer(20))

	# Feedback label
	feedback_label = _make_label("", 20, MG_PALETTE.ink)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(550, 60)
	vbox.add_child(feedback_label)

func _make_spacer(height: int) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _on_key_pressed(keycode: int) -> void:
	if keycode == KEY_LEFT and slider.editable:
		slider.value = maxf(slider.value - 5.0, slider.min_value)
	elif keycode == KEY_RIGHT and slider.editable:
		slider.value = minf(slider.value + 5.0, slider.max_value)
	elif keycode == KEY_ENTER or keycode == KEY_SPACE:
		_on_confirm_pressed()


func _on_slider_changed(value: float) -> void:
	value_label.text = str(int(value))

	# Visual hint: color changes as you get closer (subtle)
	var distance: int = absi(int(value) - sweet_spot)
	if distance < 10:
		value_label.modulate = MG_PALETTE.green
	elif distance < 25:
		value_label.modulate = MG_PALETTE.gold
	else:
		value_label.modulate = MG_PALETTE.accent

func _on_confirm_pressed() -> void:
	current_attempt += 1
	confirm_button.disabled = true
	slider.editable = false

	var chosen_value: int = int(slider.value)
	var distance: int = absi(chosen_value - sweet_spot)
	var score: int = maxi(0, 100 - distance)

	if score > best_score:
		best_score = score

	# Feedback
	if distance == 0:
		feedback_label.text = "Parfait ! Prix idéal trouvé : " + str(score) + " points !"
		feedback_label.modulate = MG_PALETTE.green
	elif distance < 15:
		feedback_label.text = "Très proche ! Score : " + str(score) + " points."
		feedback_label.modulate = MG_PALETTE.gold
	else:
		feedback_label.text = "Trop éloigné... Score : " + str(score) + " points."
		feedback_label.modulate = MG_PALETTE.red

	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")

	# Next attempt or finish
	await get_tree().create_timer(2.0).timeout

	if current_attempt < max_attempts:
		_next_attempt()
	else:
		_finish_game()

func _next_attempt() -> void:
	attempt_label.text = "Tentative 2/2"
	feedback_label.text = "Nouvelle négociation... Le prix a peut-être changé."
	feedback_label.modulate = MG_PALETTE.ink

	# Shift sweet spot at high difficulty
	if _difficulty >= 6:
		var shift: int = -20 + randi() % 41
		sweet_spot = clampi(sweet_spot + shift, 20, 80)

	slider.value = 50
	value_label.text = "50"
	value_label.modulate = MG_PALETTE.accent
	slider.editable = true
	confirm_button.disabled = false

func _finish_game() -> void:
	_complete(best_score >= 50, best_score)
