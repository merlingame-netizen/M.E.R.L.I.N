## MG_COMBAT_RITUEL — Combat Rituel (Vigueur)
## QTE sequence: symbols appear, player must press matching direction quickly.
## 5 rounds. Score = hits/total * 80 + speed bonus (up to 20).

extends MiniGameBase

const DIRECTIONS := ["left", "right", "up", "down"]
const DIRECTION_SYMBOLS := {"left": "◄", "right": "►", "up": "▲", "down": "▼"}
const DIRECTION_KEYS := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
const ROUND_COUNT: int = 5

var _current_round: int = 0
var _expected_dir: String = ""
var _round_timer: float = 0.0
var _round_delay: float = 2.0
var _hits: int = 0
var _total_reaction_ms: int = 0
var _round_start_ms: int = 0
var _waiting_input: bool = false

var _symbol_label: Label
var _status_label: Label
var _feedback_label: Label


func _on_start() -> void:
	_build_overlay()

	_round_delay = 2.5 - (_difficulty * 0.15)
	_round_delay = maxf(_round_delay, 0.8)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_top = -220
	vbox.offset_right = 220
	vbox.offset_bottom = 220
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var title := _make_label("COMBAT RITUEL", 28, MG_PALETTE.accent)
	vbox.add_child(title)

	var subtitle := _make_label("Frappe dans la bonne direction!", 16)
	vbox.add_child(subtitle)

	_status_label = _make_label("Prépare-toi...", 20, MG_PALETTE.ink)
	vbox.add_child(_status_label)

	_symbol_label = _make_label("", 72, MG_PALETTE.gold)
	_symbol_label.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(_symbol_label)

	_feedback_label = _make_label("", 22, MG_PALETTE.green)
	vbox.add_child(_feedback_label)

	var hint := _make_label("Utilise les flèches ← ↑ → ↓", 14, MG_PALETTE.ink)
	vbox.add_child(hint)

	await get_tree().create_timer(1.0).timeout
	_next_round()


func _next_round() -> void:
	_current_round += 1

	if _current_round > ROUND_COUNT:
		_finish_game()
		return

	_expected_dir = DIRECTIONS[randi() % DIRECTIONS.size()]
	_symbol_label.text = DIRECTION_SYMBOLS[_expected_dir]
	_symbol_label.modulate = Color.WHITE
	_status_label.text = "Round %d/%d" % [_current_round, ROUND_COUNT]
	_feedback_label.text = ""
	_round_timer = _round_delay
	_round_start_ms = Time.get_ticks_msec()
	_waiting_input = true


func _process(delta: float) -> void:
	if _finished or not _waiting_input:
		return

	_round_timer -= delta
	if _round_timer <= 0:
		_waiting_input = false
		_symbol_label.modulate = MG_PALETTE.red
		_feedback_label.text = "Trop lent!"
		_feedback_label.modulate = MG_PALETTE.red

		await get_tree().create_timer(0.5).timeout
		_next_round()


func _on_key_pressed(keycode: int) -> void:
	if not _waiting_input:
		return

	var pressed_dir := ""
	for dir in DIRECTION_KEYS:
		if keycode == DIRECTION_KEYS[dir]:
			pressed_dir = dir
			break

	if pressed_dir == "":
		return

	_waiting_input = false
	var reaction_ms: int = Time.get_ticks_msec() - _round_start_ms

	if pressed_dir == _expected_dir:
		_hits += 1
		_total_reaction_ms += reaction_ms
		_symbol_label.modulate = MG_PALETTE.green
		_feedback_label.text = "Touché! (%d ms)" % reaction_ms
		_feedback_label.modulate = MG_PALETTE.green
	else:
		_symbol_label.modulate = MG_PALETTE.red
		_feedback_label.text = "Raté!"
		_feedback_label.modulate = MG_PALETTE.red

	await get_tree().create_timer(0.5).timeout
	_next_round()


func _finish_game() -> void:
	var base_score: int = int(float(_hits) / float(ROUND_COUNT) * 80.0)

	var speed_bonus: int = 0
	if _hits > 0:
		var avg_ms: float = float(_total_reaction_ms) / float(_hits)
		speed_bonus = clampi(int(20.0 - avg_ms / 50.0), 0, 20)

	var score: int = clampi(base_score + speed_bonus, 0, 100)
	var success: bool = _hits >= 3

	_symbol_label.text = "%d/%d" % [_hits, ROUND_COUNT]
	_status_label.text = "Victoire! (%d pts)" % score if success else "Défaite... (%d pts)" % score
	_status_label.modulate = MG_PALETTE.green if success else MG_PALETTE.red

	await get_tree().create_timer(1.0).timeout
	_complete(success, score)
