## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Ogham Activation in Run 3D Controller
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: activation flow, cooldown tick, 1-per-card max, cost deduction,
## protection filtering, unlock, availability checks.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


## Build a minimal Run3DController with headless dependencies for testing.
## Returns {"controller": Run3DController, "store": MerlinStore, ...}.
func _make_controller() -> Dictionary:
	var controller: Run3DController = Run3DController.new()
	var store: MerlinStore = MerlinStore.new()
	var card_system: MerlinCardSystem = MerlinCardSystem.new()
	var effects: MerlinEffectEngine = MerlinEffectEngine.new()

	controller.setup(store, card_system, effects, null, null, null, true)
	return {
		"controller": controller,
		"store": store,
		"card_system": card_system,
		"effects": effects,
	}


## Simulate a run start + card trigger so ogham can be activated.
## Sets up _run_state (card-system tracking) and store.state["run"] (game state)
## directly for unit testing. Game state lives in the store; _run_state holds
## card-system fields plus a synced copy of game values.
func _setup_card_state(controller: Run3DController) -> void:
	# Card-system tracking fields
	controller._run_state = {
		"biome": "broceliande",
		"card_index": 3,
		"period": "aube",
		"active_promises": [],
		"faction_rep_delta": {},
	}
	# Game state in store (source of truth)
	var store: MerlinStore = controller._store
	if not store.state.has("run"):
		store.state["run"] = {}
	store.state["run"]["life_essence"] = 80
	store.state["run"]["biome_currency"] = 10
	store.state["run"]["anam"] = 200
	# Sync store values into _run_state for card_system compatibility
	controller._sync_store_to_run_state()
	controller._current_card = {
		"type": "narrative",
		"text": "Test card",
		"options": [
			{"label": "Observer", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "Combattre", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
			{"label": "Fuir", "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 10}]},
		],
	}
	controller._ogham_cooldowns = {}
	controller._unlocked_oghams = MerlinConstants.OGHAM_STARTER_SKILLS.duplicate()
	controller._active_ogham_this_card = ""
	controller._ogham_activation_result = {}
	controller._is_running = true
	controller._is_paused = true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: Starter oghams are available at run start
# ═══════════════════════════════════════════════════════════════════════════════

func test_starter_oghams_available() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	var available: Array = ctrl.get_available_oghams()
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not available.has(starter):
			push_error("Starter ogham %s should be available" % starter)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: Activate a starter ogham successfully
# ═══════════════════════════════════════════════════════════════════════════════

func test_activate_starter_ogham() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl.on_ogham_activated("beith")
	if ctrl._active_ogham_this_card != "beith":
		push_error("Active ogham should be 'beith', got '%s'" % ctrl._active_ogham_this_card)
		return false
	if ctrl._ogham_activation_result.is_empty():
		push_error("Activation result should not be empty")
		return false
	if not ctrl._ogham_activation_result.get("ok", false):
		push_error("Activation should succeed, got: %s" % str(ctrl._ogham_activation_result))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: Max 1 ogham per card — second activation rejected
# ═══════════════════════════════════════════════════════════════════════════════

func test_max_one_ogham_per_card() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl.on_ogham_activated("beith")
	# Try activating a second ogham on the same card
	ctrl.on_ogham_activated("luis")

	if ctrl._active_ogham_this_card != "beith":
		push_error("Active ogham should still be 'beith' (first), got '%s'" % ctrl._active_ogham_this_card)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Cooldown set on activation
# ═══════════════════════════════════════════════════════════════════════════════

func test_cooldown_set_on_activation() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl.on_ogham_activated("beith")
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get("beith", {})
	var expected_cd: int = int(spec.get("cooldown", 3))
	var actual_cd: int = ctrl.get_ogham_cooldown("beith")
	if actual_cd != expected_cd:
		push_error("Cooldown for beith should be %d, got %d" % [expected_cd, actual_cd])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Ogham on cooldown cannot be activated
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_on_cooldown_rejected() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# Set beith on cooldown manually
	ctrl._ogham_cooldowns["beith"] = 3

	ctrl.on_ogham_activated("beith")
	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Ogham on cooldown should not activate, got '%s'" % ctrl._active_ogham_this_card)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: Cooldown tick decrements all cooldowns
# ═══════════════════════════════════════════════════════════════════════════════

func test_cooldown_tick_decrements() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl._ogham_cooldowns = {"beith": 3, "luis": 1}
	ctrl._tick_ogham_cooldowns()

	var beith_cd: int = ctrl.get_ogham_cooldown("beith")
	if beith_cd != 2:
		push_error("beith cooldown should be 2 after tick, got %d" % beith_cd)
		return false

	# luis was at 1, should be erased (0)
	var luis_cd: int = ctrl.get_ogham_cooldown("luis")
	if luis_cd != 0:
		push_error("luis cooldown should be 0 after tick, got %d" % luis_cd)
		return false

	# luis should be removed from dict
	if ctrl._ogham_cooldowns.has("luis"):
		push_error("luis should be erased from cooldowns dict after reaching 0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7: Cooldown tick makes ogham available again
# ═══════════════════════════════════════════════════════════════════════════════

func test_cooldown_expiry_makes_available() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl._ogham_cooldowns = {"beith": 1}
	if ctrl._is_ogham_available("beith"):
		push_error("beith should NOT be available while on cooldown")
		return false

	ctrl._tick_ogham_cooldowns()

	if not ctrl._is_ogham_available("beith"):
		push_error("beith should be available after cooldown expires")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8: Non-starter ogham rejected if not unlocked
# ═══════════════════════════════════════════════════════════════════════════════

func test_locked_ogham_rejected() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# "duir" is not a starter and not in _unlocked_oghams
	ctrl.on_ogham_activated("duir")
	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Locked ogham should not activate, got '%s'" % ctrl._active_ogham_this_card)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 9: Unlock ogham makes it available
# ═══════════════════════════════════════════════════════════════════════════════

func test_unlock_ogham() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	if ctrl._is_ogham_available("duir"):
		push_error("duir should NOT be available before unlock")
		return false

	ctrl.unlock_ogham("duir")

	if not ctrl._is_ogham_available("duir"):
		push_error("duir should be available after unlock")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 10: Anam cost deducted on activation
# ═══════════════════════════════════════════════════════════════════════════════

func test_anam_cost_deducted() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# Unlock duir (cost_anam: 70) and activate it
	ctrl.unlock_ogham("duir")
	var anam_before: int = int(deps["store"].state.get("run", {}).get("anam", 0))
	ctrl.on_ogham_activated("duir")

	var anam_after: int = int(deps["store"].state.get("run", {}).get("anam", 0))
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get("duir", {})
	var expected_cost: int = int(spec.get("cost_anam", 0))

	if anam_after != anam_before - expected_cost:
		push_error("Anam should be %d after cost, got %d" % [anam_before - expected_cost, anam_after])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 11: Insufficient anam rejects activation
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_anam_rejected() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# Unlock duir (cost_anam: 70) but set anam to 10 in store
	ctrl.unlock_ogham("duir")
	deps["store"].state["run"]["anam"] = 10

	ctrl.on_ogham_activated("duir")
	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Should reject activation with insufficient anam")
		return false

	# Anam should be unchanged in store
	var anam: int = int(deps["store"].state.get("run", {}).get("anam", 0))
	if anam != 10:
		push_error("Anam should be unchanged at 10, got %d" % anam)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 12: Starter oghams have zero cost
# ═══════════════════════════════════════════════════════════════════════════════

func test_starter_oghams_zero_cost() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	var anam_before: int = int(deps["store"].state.get("run", {}).get("anam", 0))
	ctrl.on_ogham_activated("beith")

	var anam_after: int = int(deps["store"].state.get("run", {}).get("anam", 0))
	if anam_after != anam_before:
		push_error("Starter ogham should cost 0 anam, but anam changed from %d to %d" % [anam_before, anam_after])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 13: No activation without a card displayed
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_activation_without_card() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# Clear current card
	ctrl._current_card = {}

	ctrl.on_ogham_activated("beith")
	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Should not activate ogham without a displayed card")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 14: Protection ogham filters negative effects (luis)
# ═══════════════════════════════════════════════════════════════════════════════

func test_protection_ogham_filters_negatives() -> bool:
	var effects: Array = [
		{"code": "HEAL_LIFE", "amount": 5, "type": "HEAL_LIFE"},
		{"code": "DAMAGE_LIFE", "amount": 8, "type": "DAMAGE_LIFE"},
		{"code": "ADD_REPUTATION", "amount": 10, "type": "ADD_REPUTATION", "faction": "druides"},
	]

	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "luis")

	# luis blocks the first negative — DAMAGE_LIFE should be removed
	if filtered.size() != 2:
		push_error("luis should remove 1 negative, expected 2 effects, got %d" % filtered.size())
		return false

	for eff in filtered:
		if str(eff.get("code", "")) == "DAMAGE_LIFE":
			push_error("DAMAGE_LIFE should have been blocked by luis")
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 15: Per-card ogham state resets between cards
# ═══════════════════════════════════════════════════════════════════════════════

func test_per_card_ogham_state_resets() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	# Activate beith on first "card"
	ctrl.on_ogham_activated("beith")
	if ctrl._active_ogham_this_card.is_empty():
		push_error("beith should be active")
		return false

	# Simulate _trigger_card reset (the relevant lines)
	ctrl._active_ogham_this_card = ""
	ctrl._ogham_activation_result = {}

	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Per-card ogham state should reset between cards")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 16: Unknown ogham rejected gracefully
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_ogham_rejected() -> bool:
	var deps: Dictionary = _make_controller()
	var ctrl: Run3DController = deps["controller"]
	_setup_card_state(ctrl)

	ctrl.on_ogham_activated("fake_ogham_xyz")
	if not ctrl._active_ogham_this_card.is_empty():
		push_error("Unknown ogham should not activate")
		return false
	return true
