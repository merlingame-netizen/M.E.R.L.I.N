## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game Controller — Store-UI Bridge (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Connects DruStore TRIADE actions to TriadeGameUI.
## Manages game flow: start run, get cards, resolve choices, end run.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name TriadeGameController

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

var store: DruStore
var ui: TriadeGameUI

var current_card: Dictionary = {}
var is_processing := false

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Find store (singleton or child)
	store = get_node_or_null("/root/DruStore")
	if not store:
		store = DruStore.new()
		add_child(store)

	# Find or create UI
	ui = get_node_or_null("TriadeGameUI")
	if not ui:
		ui = TriadeGameUI.new()
		ui.name = "TriadeGameUI"
		add_child(ui)

	_connect_signals()


func _connect_signals() -> void:
	# Store signals
	if store:
		store.state_changed.connect(_on_state_changed)
		store.aspect_shifted.connect(_on_aspect_shifted)
		store.souffle_changed.connect(_on_souffle_changed)
		store.run_ended.connect(_on_run_ended)
		store.mission_progress.connect(_on_mission_progress)

	# UI signals
	if ui:
		ui.option_chosen.connect(_on_option_chosen)
		ui.skill_activated.connect(_on_skill_activated)
		ui.pause_requested.connect(_on_pause_requested)


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(seed_value: int = -1) -> void:
	"""Start a new TRIADE run."""
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system())

	var result = store.dispatch({
		"type": "TRIADE_START_RUN",
		"seed": seed_value,
	})

	if result.get("ok", false):
		_sync_ui_with_state()
		_request_next_card()


func _request_next_card() -> void:
	"""Get and display the next card."""
	if is_processing:
		return

	is_processing = true

	var result = store.dispatch({"type": "TRIADE_GET_CARD"})

	if result.get("ok", false):
		current_card = result.get("card", {})
		if ui:
			ui.display_card(current_card)

	is_processing = false


func _resolve_choice(option: int) -> void:
	"""Resolve the player's choice."""
	if is_processing or current_card.is_empty():
		return

	is_processing = true

	var result = store.dispatch({
		"type": "TRIADE_RESOLVE_CHOICE",
		"card": current_card,
		"option": option,
	})

	if result.get("ok", false):
		if result.get("run_ended", false):
			# Run has ended
			var ending = result.get("ending", {})
			if ui:
				ui.show_end_screen(ending)
		else:
			# Continue with next card
			_sync_ui_with_state()
			current_card = {}

			# Small delay before next card
			await get_tree().create_timer(0.3).timeout
			_request_next_card()

	is_processing = false


func _use_skill(skill_id: String) -> void:
	"""Activate a Bestiole skill."""
	var result = store.dispatch({
		"type": "TRIADE_USE_SKILL",
		"skill_id": skill_id,
		"card": current_card,
	})

	if result.get("ok", false):
		# Handle skill result
		var skill_type = result.get("type", "")

		match skill_type:
			"reveal_one", "reveal_all":
				# TODO: Show revealed effects in UI
				pass
			"reroll_card", "full_reroll":
				# Get new card
				_request_next_card()
			_:
				# Other skills just update state
				_sync_ui_with_state()


# ═══════════════════════════════════════════════════════════════════════════════
# UI SYNCHRONIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _sync_ui_with_state() -> void:
	"""Sync UI with current store state."""
	if not ui or not store:
		return

	# Aspects
	var aspects = store.get_all_aspects()
	ui.update_aspects(aspects)

	# Souffle
	var souffle = store.get_souffle()
	ui.update_souffle(souffle)

	# Mission
	var mission = store.get_mission()
	ui.update_mission(mission)

	# Cards count
	var cards_played = store.get_cards_played()
	ui.update_cards_count(cards_played)


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Store
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_changed(_state: Dictionary) -> void:
	_sync_ui_with_state()


func _on_aspect_shifted(aspect: String, old_state: int, new_state: int) -> void:
	# Update UI with animation
	if ui:
		var aspects = store.get_all_aspects()
		ui.update_aspects(aspects)

	# Check for danger (2 extreme aspects)
	var extreme_count = store.count_extreme_aspects()
	if extreme_count >= 2:
		# Show warning
		print("[TRIADE] WARNING: 2+ extreme aspects - run may end soon!")


func _on_souffle_changed(old_value: int, new_value: int) -> void:
	if ui:
		ui.update_souffle(new_value)

	# Feedback for regeneration
	if new_value > old_value:
		print("[TRIADE] Souffle regenerated: +%d" % (new_value - old_value))


func _on_run_ended(ending: Dictionary) -> void:
	if ui:
		ui.show_end_screen(ending)


func _on_mission_progress(step: int, total: int) -> void:
	if ui:
		var mission = store.get_mission()
		ui.update_mission(mission)

	if step >= total and total > 0:
		print("[TRIADE] Mission complete!")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — UI
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_chosen(option: int) -> void:
	_resolve_choice(option)


func _on_skill_activated(skill_id: String) -> void:
	_use_skill(skill_id)


func _on_pause_requested() -> void:
	# TODO: Show pause menu
	get_tree().paused = not get_tree().paused


# ═══════════════════════════════════════════════════════════════════════════════
# CONVENIENCE
# ═══════════════════════════════════════════════════════════════════════════════

func get_aspect_state(aspect: String) -> int:
	return store.get_aspect_state(aspect) if store else 0


func get_aspect_name(aspect: String) -> String:
	return store.get_aspect_name(aspect) if store else "???"


func get_souffle() -> int:
	return store.get_souffle() if store else 0


func is_run_active() -> bool:
	return store.is_run_active() if store else false
