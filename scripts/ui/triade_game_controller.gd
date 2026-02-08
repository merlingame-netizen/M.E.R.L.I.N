## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game Controller — Store-UI Bridge (v0.4.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Connects MerlinStore TRIADE actions to TriadeGameUI.
## Manages game flow: narrator intro, start run, get cards, resolve choices.
## LLM integration via MerlinOmniscient for real narrative card generation.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name TriadeGameController

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

var store: MerlinStore
var ui: TriadeGameUI
var merlin_ai: Node = null  # MerlinAI autoload reference

var current_card: Dictionary = {}
var is_processing := false
var _intro_shown := false
var _cards_this_run := 0

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Find store (singleton or child)
	store = get_node_or_null("/root/MerlinStore")
	if not store:
		store = MerlinStore.new()
		add_child(store)

	# Find or create UI
	ui = get_node_or_null("TriadeGameUI")
	if not ui:
		ui = TriadeGameUI.new()
		ui.name = "TriadeGameUI"
		add_child(ui)

	# Find LLM interface
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		print("[TriadeController] MerlinAI found, LLM generation available")
	else:
		print("[TriadeController] MerlinAI not found, using fallback cards")

	_connect_signals()

	# Auto-start run after a frame so UI is fully ready
	await get_tree().process_frame
	start_run()


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

	# Bestiole wheel signals
	if ui and ui.bestiole_wheel:
		ui.bestiole_wheel.wheel_opened.connect(_on_wheel_open_requested)
		ui.bestiole_wheel.ogham_selected.connect(_on_ogham_selected)

	# Store bestiole signals
	if store:
		if store.has_signal("awen_changed"):
			store.awen_changed.connect(_on_awen_changed)
		if store.has_signal("bond_tier_changed"):
			store.bond_tier_changed.connect(_on_bond_tier_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(seed_value: int = -1) -> void:
	## Start a new TRIADE run with Merlin narrator intro.
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system())

	_cards_this_run = 0
	_intro_shown = false

	var result = await store.dispatch({
		"type": "TRIADE_START_RUN",
		"seed": seed_value,
	})

	if result.get("ok", false):
		_sync_ui_with_state()

		# Show narrator intro BEFORE first card
		if ui:
			await ui.show_narrator_intro()
			_intro_shown = true

		# Then get first card
		_request_next_card()


func _request_next_card() -> void:
	## Get and display the next card (LLM or fallback).
	if is_processing:
		return

	is_processing = true
	_cards_this_run += 1

	var result = await store.dispatch({"type": "TRIADE_GET_CARD"})

	if result.get("ok", false):
		current_card = result.get("card", {})
		if ui:
			ui.display_card(current_card)
	else:
		# If store fails, try direct LLM generation
		var llm_card := await _try_direct_llm_card()
		if not llm_card.is_empty():
			current_card = llm_card
			if ui:
				ui.display_card(current_card)

	is_processing = false


func _try_direct_llm_card() -> Dictionary:
	## Attempt to generate a card directly via MerlinAI when store pipeline fails.
	if merlin_ai == null or not merlin_ai.get("is_ready"):
		return {}

	if not merlin_ai.has_method("generate_with_system"):
		return {}

	var system_prompt := "Tu es un narrateur celtique. Genere une scene en 1-2 phrases, avec 2 options (gauche/droite)."
	var user_prompt := "Carte %d. Aspects: Corps=equilibre, Ame=equilibre, Monde=equilibre." % _cards_this_run

	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, {"max_tokens": 128, "temperature": 0.7})

	if result.has("error"):
		return {}

	var text: String = result.get("text", "")
	if text.is_empty():
		return {}

	# Parse simple text into card format
	return {
		"id": "llm_%d" % _cards_this_run,
		"text": text.strip_edges(),
		"speaker": "Merlin",
		"type": "narrative",
		"options": [
			{"direction": "left", "label": "Accepter", "effects": [
				{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
			], "preview": "Ouvert"},
			{"direction": "right", "label": "Refuser", "effects": [
				{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}
			], "preview": "Prudent"}
		],
		"tags": ["llm_generated"],
	}


func _resolve_choice(option: int) -> void:
	"""Resolve the player's choice."""
	if is_processing or current_card.is_empty():
		return

	is_processing = true

	var result = await store.dispatch({
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
	var result = await store.dispatch({
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

	# Bestiole wheel
	if ui.bestiole_wheel:
		ui.bestiole_wheel.update_awen(store.get_awen())
		ui.bestiole_wheel.update_bond(store.get_bestiole_bond())


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
# SIGNAL HANDLERS — Bestiole Wheel
# ═══════════════════════════════════════════════════════════════════════════════

func _on_wheel_open_requested() -> void:
	if store and ui and ui.bestiole_wheel:
		ui.bestiole_wheel.open_wheel(store)


func _on_ogham_selected(skill_id: String) -> void:
	_use_ogham(skill_id)


func _on_awen_changed(_old_value: int, new_value: int) -> void:
	if ui and ui.bestiole_wheel:
		ui.bestiole_wheel.update_awen(new_value)


func _on_bond_tier_changed(_old_tier: String, _new_tier: String) -> void:
	if store and ui and ui.bestiole_wheel:
		ui.bestiole_wheel.update_bond(store.get_bestiole_bond())


func _use_ogham(skill_id: String) -> void:
	"""Activate a Bestiole Ogham skill via the store."""
	if not store:
		return

	var result = await store.dispatch({
		"type": "TRIADE_USE_OGHAM",
		"skill_id": skill_id,
		"card": current_card,
	})

	if result.get("ok", false):
		_sync_ui_with_state()


func _unhandled_input(event: InputEvent) -> void:
	# Tab key toggles Bestiole wheel
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if ui and ui.bestiole_wheel:
			if ui.bestiole_wheel.is_open:
				ui.bestiole_wheel.close_wheel()
			elif store:
				ui.bestiole_wheel.open_wheel(store)
			get_viewport().set_input_as_handled()


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
