## MG_TRACE_CERF — Trace du Cerf (Observation)
## A marker moves across screen. Player must click it before it moves.
## 5 rounds, 2s per round (less at high difficulty).

extends MiniGameBase

var _round: int = 0
const MAX_ROUNDS: int = 5
var _hits: int = 0
var _marker: ColorRect
var _timer: float = 0.0
var _move_interval: float = 2.0
var _marker_size: float = 60.0
var _container: Control


func _on_start() -> void:
	_build_overlay()

	# Difficulty affects speed and size
	_move_interval = 2.5 - (_difficulty * 0.15)  # 2.35s to 1.0s
	_marker_size = 70.0 - (_difficulty * 3.0)    # 70px to 40px

	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	# Title
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.offset_top = 40
	vbox.add_theme_constant_override("separation", 12)
	_container.add_child(vbox)

	var title := _make_label("TRACE DU CERF", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Touche la marque avant qu'elle bouge!", 16)
	vbox.add_child(subtitle)

	# Score label
	var score_lbl := _make_label("Rond 0/5 — Touché: 0", 18)
	score_lbl.name = "ScoreLabel"
	vbox.add_child(score_lbl)

	# Create marker
	_marker = ColorRect.new()
	_marker.color = MG_PALETTE.gold
	_marker.size = Vector2(_marker_size, _marker_size)
	_marker.mouse_filter = Control.MOUSE_FILTER_STOP
	_marker.gui_input.connect(_on_marker_clicked)
	_container.add_child(_marker)

	_next_round()


func _next_round() -> void:
	_round += 1
	_timer = _move_interval

	if _round > MAX_ROUNDS:
		_finish_game()
		return

	# Move marker to random position
	var viewport_size := get_viewport_rect().size
	var margin: float = 100.0
	var safe_width: float = viewport_size.x - margin * 2 - _marker_size
	var safe_height: float = viewport_size.y - margin * 2 - _marker_size - 150  # Top UI space

	_marker.position = Vector2(
		margin + randf() * safe_width,
		150 + margin + randf() * safe_height
	)

	# Update score label
	var lbl := _container.get_node_or_null("VBoxContainer/ScoreLabel") as Label
	if lbl:
		lbl.text = "Rond %d/%d — Touché: %d" % [_round, MAX_ROUNDS, _hits]

	# Pulse animation
	_marker.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_marker, "modulate:a", 1.0, 0.2)

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("minigame_tick")


func _process(delta: float) -> void:
	if _finished or _round == 0:
		return

	_timer -= delta
	if _timer <= 0:
		# Missed this round
		_next_round()


func _on_marker_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hits += 1

		# Flash green
		var original_color: Color = _marker.color
		_marker.color = MG_PALETTE.green

		var tw := create_tween()
		tw.tween_property(_marker, "color", original_color, 0.15)

		# SFX
		var sfx := get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("minigame_success")

		_next_round()


func _finish_game() -> void:
	_marker.visible = false

	var score: int = int((_hits / float(MAX_ROUNDS)) * 100.0)
	var success: bool = _hits >= 3

	_complete(success, score)
