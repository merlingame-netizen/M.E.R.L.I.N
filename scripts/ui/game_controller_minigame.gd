## ═══════════════════════════════════════════════════════════════════════════════
## Game Controller — Minigame Runner Module
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_controller.gd.
## Handles minigame launching, scoring, tool bonuses, and timeout safety.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name GameControllerMinigame

var _ctrl: Node  # MerlinGameController reference


func _init(controller: Node) -> void:
	_ctrl = controller


func run_minigame(field: String, is_critical: bool) -> int:
	## Launch a minigame for the given lexical field. Returns raw score 0-100.
	## Fallback: score 50 (reussite_partielle) if minigame unavailable.
	var store: Node = _ctrl.store
	var ui: Node = _ctrl.ui

	# Tool bonus: check if equipped tool gives bonus for this field
	var tool_bonus: int = 0
	var tool_bonus_text: String = ""
	var run_data: Dictionary = {}
	var gm_node: Node = _ctrl.get_node_or_null("/root/GameManager")
	if gm_node and "run" in gm_node:
		run_data = gm_node.run if gm_node.run is Dictionary else {}
	if run_data.is_empty() and store:
		run_data = store.state.get("run", {})
	var tool_id: String = str(run_data.get("tool", ""))
	if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
		var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
		var bonus_field: String = str(tool_info.get("bonus_field", ""))
		if bonus_field != "" and bonus_field == field:
			tool_bonus = int(tool_info.get("dc_bonus", 0))
			tool_bonus_text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", ""))]

	# Show minigame intro overlay
	if ui and is_instance_valid(ui):
		ui.show_minigame_intro(field, tool_bonus_text, tool_bonus)
		if _ctrl.is_inside_tree():
			await _ctrl.get_tree().create_timer(1.2).timeout

	var base_diff: int = 5  # Fixed moderate difficulty (no DC influence)
	if is_critical:
		base_diff = mini(base_diff + 3, 10)

	var modifiers: Dictionary = {}
	var game: Node = MiniGameRegistry.create_minigame(field, base_diff, modifiers)
	if game == null:
		push_warning("[Merlin] minigame creation failed for field '%s', using fallback score 50" % field)
		return 50

	SFXManager.play("minigame_start")
	# Host minigame inside card body if UI has content host
	var mg_host: Control = null
	if ui and is_instance_valid(ui) and ui.has_method("get_body_content_host"):
		mg_host = ui.get_body_content_host()
	if mg_host and is_instance_valid(mg_host):
		if game.has_method("setup_in_card"):
			game.setup_in_card(mg_host)
		else:
			mg_host.add_child(game)
		ui.switch_body_to_content()
	else:
		_ctrl.add_child(game)
	# Hide option buttons during minigame
	if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
		ui.set_options_visible(false)
	game.start()

	# Timeout safety: don't hang forever if minigame fails to emit
	var mg_state: Array = [false, {}]  # [done, result]
	game.game_completed.connect(func(result: Dictionary):
		mg_state[0] = true
		mg_state[1] = result
	, CONNECT_ONE_SHOT)
	var mg_timeout: float = 30.0
	var mg_deadline: int = Time.get_ticks_msec() + int(mg_timeout * 1000.0)
	while not mg_state[0] and Time.get_ticks_msec() < mg_deadline:
		if not _ctrl.is_inside_tree() or not is_instance_valid(game):
			break
		await _ctrl.get_tree().process_frame
	if not mg_state[0]:
		push_warning("[Merlin] minigame timed out after %.0fs, using fallback score 50" % mg_timeout)
		if is_instance_valid(game):
			game.queue_free()
		if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
			ui.set_options_visible(true)
		return 50

	var mg_result: Dictionary = mg_state[1]
	var score: int = int(mg_result.get("score", 50))
	var mg_success: bool = bool(mg_result.get("success", false))
	if mg_success:
		_ctrl._minigames_won += 1
		SFXManager.play("minigame_success")
	else:
		SFXManager.play("minigame_fail")

	# Cleanup: let base class tween handle fade-out (0.3s), then free
	# Don't call queue_free here — _complete() already schedules it via tween
	# Double queue_free cancels the fade animation
	# Restore option buttons after minigame
	if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
		ui.set_options_visible(true)

	# Apply tool score bonus
	if tool_bonus != 0:
		score = clampi(score + tool_bonus * 5, 0, 100)
		print("[Merlin] tool bonus: %d -> score adjusted to %d" % [tool_bonus, score])

	print("[Merlin] minigame done: field=%s score=%d" % [field, score])

	# Show score feedback in UI
	if ui and is_instance_valid(ui) and ui.has_method("show_minigame_score"):
		ui.show_minigame_score(score)
		if _ctrl.is_inside_tree():
			await _ctrl.get_tree().create_timer(1.0).timeout

	return score
