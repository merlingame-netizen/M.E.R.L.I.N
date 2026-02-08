## ═══════════════════════════════════════════════════════════════════════════════
## Reigns Game Controller — Links Store and UI
## ═══════════════════════════════════════════════════════════════════════════════
## Orchestrates the Reigns-style gameplay loop.
## Updated 2026-02-05 for Reigns-style gameplay.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name ReignsGameController

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

@export var ui: ReignsGameUI
@export var store: MerlinStore

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var is_run_active := false

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Auto-find store if not set
	if not store:
		store = _find_or_create_store()

	# Connect store signals
	if store:
		store.state_changed.connect(_on_state_changed)
		store.phase_changed.connect(_on_phase_changed)
		store.run_ended.connect(_on_run_ended)

	# Connect UI signals
	if ui:
		ui.choice_made.connect(_on_choice_made)
		ui.skill_activated.connect(_on_skill_activated)
		ui.pause_requested.connect(_on_pause_requested)

	# Start run automatically if in card phase
	call_deferred("_check_and_start")


func _find_or_create_store() -> MerlinStore:
	"""Find existing store or create a new one."""
	# Check if store exists in autoloads
	if Engine.has_singleton("MerlinStore"):
		return Engine.get_singleton("MerlinStore")

	# Check parent nodes
	var parent = get_parent()
	while parent:
		if parent is MerlinStore:
			return parent
		for child in parent.get_children():
			if child is MerlinStore:
				return child
		parent = parent.get_parent()

	# Create new store
	var new_store = MerlinStore.new()
	new_store.name = "MerlinStore"
	add_child(new_store)
	return new_store


func _check_and_start() -> void:
	"""Check current state and start if needed."""
	if store and not store.is_run_active():
		start_new_run()


# ═══════════════════════════════════════════════════════════════════════════════
# RUN MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func start_new_run(seed_value: int = 0) -> void:
	"""Start a new Reigns-style run."""
	if not store:
		push_error("ReignsGameController: No store available")
		return

	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system())

	var result = await store.dispatch({"type": "REIGNS_START_RUN", "seed": seed_value})
	if result.get("ok", false):
		is_run_active = true
		_sync_ui_with_state()
		_request_next_card()


func end_run() -> void:
	"""Manually end the current run."""
	if not store:
		return

	await store.dispatch({"type": "REIGNS_END_RUN"})
	is_run_active = false


# ═══════════════════════════════════════════════════════════════════════════════
# CARD FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func _request_next_card() -> void:
	"""Request the next card from the store."""
	if not store or not is_run_active:
		return

	var result = await store.dispatch({"type": "REIGNS_GET_CARD"})
	if result.get("ok", false):
		current_card = result.get("card", {})
		if ui:
			ui.display_card(current_card)
	else:
		push_warning("Failed to get next card: %s" % result.get("error", "unknown"))


func _resolve_choice(direction: String) -> void:
	"""Resolve the player's choice."""
	if not store or current_card.is_empty():
		return

	var result = await store.dispatch({
		"type": "REIGNS_RESOLVE_CHOICE",
		"card": current_card,
		"direction": direction,
	})

	if result.get("ok", false):
		if result.get("run_ended", false):
			# Run ended, show end screen
			is_run_active = false
			if ui:
				ui.show_end_screen(result.get("ending", {}))
		else:
			# Continue with next card
			_sync_ui_with_state()
			_request_next_card()
	else:
		push_warning("Failed to resolve choice: %s" % result.get("error", "unknown"))


func _use_skill(skill_id: String) -> void:
	"""Use a Bestiole skill on the current card."""
	if not store or current_card.is_empty():
		return

	var result = await store.dispatch({
		"type": "REIGNS_USE_SKILL",
		"skill_id": skill_id,
		"card": current_card,
	})

	if result.get("ok", false):
		# Update the displayed card with modified effects
		if result.has("modified_card"):
			current_card = result["modified_card"]
			if ui:
				ui.display_card(current_card)

		# Update bestiole display (cooldowns changed)
		_sync_bestiole_ui()


# ═══════════════════════════════════════════════════════════════════════════════
# UI SYNC
# ═══════════════════════════════════════════════════════════════════════════════

func _sync_ui_with_state() -> void:
	"""Sync all UI elements with current state."""
	if not store or not ui:
		return

	var state = store.state

	# Update gauges
	var gauges = state.get("run", {}).get("gauges", {})
	ui.update_gauges(gauges)

	# Update info
	var day = int(state.get("run", {}).get("day", 1))
	var cards = int(state.get("run", {}).get("cards_played", 0))
	ui.update_info(day, cards)

	# Update bestiole
	_sync_bestiole_ui()


func _sync_bestiole_ui() -> void:
	"""Sync bestiole display with state."""
	if not store or not ui:
		return

	var bestiole = store.state.get("bestiole", {})

	# Compute mood from needs
	var needs = bestiole.get("needs", {})
	var avg_needs = (int(needs.get("Hunger", 50)) + int(needs.get("Energy", 50)) +
					int(needs.get("Mood", 50)) - int(needs.get("Stress", 0))) / 4.0
	var mood := "neutral"
	if avg_needs >= 70:
		mood = "happy"
	elif avg_needs >= 40:
		mood = "content"
	elif avg_needs >= 20:
		mood = "tired"
	else:
		mood = "distressed"

	ui.update_bestiole({
		"bond": bestiole.get("bond", 50),
		"mood": mood,
	})

	# Update skills
	var equipped = bestiole.get("skills_equipped", [])
	var cooldowns = bestiole.get("skill_cooldowns", {})
	ui.update_skills(equipped, cooldowns)


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — UI
# ═══════════════════════════════════════════════════════════════════════════════

func _on_choice_made(direction: String) -> void:
	_resolve_choice(direction)


func _on_skill_activated(skill_id: String) -> void:
	_use_skill(skill_id)


func _on_pause_requested() -> void:
	# Show pause menu or return to main menu
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Store
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_changed(state: Dictionary) -> void:
	_sync_ui_with_state()


func _on_phase_changed(phase: String) -> void:
	print("Phase changed to: ", phase)
	if phase == "end":
		is_run_active = false


func _on_run_ended(ending: Dictionary) -> void:
	is_run_active = false
	if ui:
		ui.show_end_screen(ending)


func _on_gauge_updated(gauge: String, value: int, old_value: int) -> void:
	# Could add visual feedback for gauge changes
	print("Gauge %s: %d -> %d" % [gauge, old_value, value])
