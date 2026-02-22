## MiniGameBase — Base class for all M.E.R.L.I.N. mini-games (Phase 33)
## Each mini-game is a Control overlay that emits game_completed when done.
## Result: {success: bool, score: int (0-100), time_ms: int}

class_name MiniGameBase extends Control

signal game_completed(result: Dictionary)

var _difficulty: int = 5        # 1-10, affects speed/complexity
var _modifiers: Dictionary = {} # Ogham bonuses, karma, etc.
var _started: bool = false
var _finished: bool = false
var _start_time_ms: int = 0

# Colors matching the CRT terminal theme
const MG_PALETTE := {
	"bg": Color(0.06, 0.12, 0.06, 0.95),
	"ink": Color(0.20, 1.00, 0.40),
	"accent": Color(1.00, 0.75, 0.20),
	"gold": Color(1.00, 0.85, 0.40),
	"green": Color(0.20, 1.00, 0.40),
	"red": Color(1.00, 0.25, 0.20),
	"paper": Color(0.04, 0.08, 0.04),
}


var _in_card_mode: bool = false
var _card_host: Control = null


func setup(difficulty: int, modifiers: Dictionary = {}) -> void:
	_difficulty = clampi(difficulty, 1, 10)
	_modifiers = modifiers


func setup_in_card(host: Control) -> void:
	## Host this minigame inside the card body content area.
	_in_card_mode = true
	_card_host = host
	host.add_child(self)


func start() -> void:
	_started = true
	_finished = false
	_start_time_ms = Time.get_ticks_msec()
	_on_start()


func _on_start() -> void:
	# Override in subclasses
	pass


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key_pressed(event.keycode)


func _on_key_pressed(_keycode: int) -> void:
	pass  # Override in subclasses


func _complete(success: bool, score: int) -> void:
	if _finished:
		return
	_finished = true
	var elapsed: int = Time.get_ticks_msec() - _start_time_ms

	# Apply Ogham modifier bonus
	var bonus: int = int(_modifiers.get("score_bonus", 0))
	score = clampi(score + bonus, 0, 100)

	var result := {"success": success, "score": score, "time_ms": elapsed}

	# SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		if success:
			sfx.play("minigame_success")
		else:
			sfx.play("minigame_fail")

	game_completed.emit(result)

	# Auto-remove after short delay
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _build_overlay() -> void:
	# Standard overlay setup
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = MG_PALETTE.bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _make_label(text: String, font_size: int = 22, color: Color = MG_PALETTE.ink) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(100, 36)
	b.pressed.connect(callback)
	return b


## Convert score (0-100) to D20 equivalent
static func score_to_d20(score: int) -> int:
	if score <= 10:
		return 1
	elif score <= 25:
		return randi_range(2, 5)
	elif score <= 50:
		return randi_range(6, 10)
	elif score <= 75:
		return randi_range(11, 15)
	elif score <= 95:
		return randi_range(16, 19)
	else:
		return 20
