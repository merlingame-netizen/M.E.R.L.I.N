## =============================================================================
## Unit Tests — StoreMap
## =============================================================================
## Tests: update_gauges, complete_biome, collect_item, add_reputation,
## select_biome, edge cases, idempotency, empty inputs.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"map_progression": {
			"gauges": {"esprit": 30, "vigueur": 50},
			"completed_biomes": [],
			"items_collected": [],
			"reputations": [],
			"visited_biomes": [],
			"current_biome": "",
			"tier_progress": 1,
		},
	}
	for key in overrides:
		state["map_progression"][key] = overrides[key]
	return state


# =============================================================================
# UPDATE GAUGES
# =============================================================================

func test_update_gauges_applies_delta() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {"esprit": 10}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges should return ok=true")
		return false
	var new_esprit: int = int(state["map_progression"]["gauges"].get("esprit", 0))
	if new_esprit != 40:
		push_error("esprit should be 40 after +10 delta, got %d" % new_esprit)
		return false
	return true


func test_update_gauges_empty_delta_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if result.get("ok", false):
		push_error("update_gauges with empty delta should return ok=false")
		return false
	if str(result.get("error", "")) != "No delta provided":
		push_error("Expected 'No delta provided' error, got '%s'" % result.get("error", ""))
		return false
	return true


func test_update_gauges_no_delta_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if result.get("ok", false):
		push_error("update_gauges with no delta key should return ok=false")
		return false
	return true


# =============================================================================
# COMPLETE BIOME
# =============================================================================

func test_complete_biome_adds_to_completed() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": "foret_broceliande"}
	var result: Dictionary = StoreMap.complete_biome(state, action)
	if not result.get("ok", false):
		push_error("complete_biome should return ok=true")
		return false
	var completed: Array = state["map_progression"]["completed_biomes"]
	if not "foret_broceliande" in completed:
		push_error("foret_broceliande should be in completed_biomes")
		return false
	return true


func test_complete_biome_no_duplicate() -> bool:
	var state: Dictionary = _make_state({"completed_biomes": ["foret_broceliande"]})
	var action: Dictionary = {"biome_key": "foret_broceliande"}
	StoreMap.complete_biome(state, action)
	var completed: Array = state["map_progression"]["completed_biomes"]
	var tracker: Dictionary = {"count": 0}
	for b in completed:
		if str(b) == "foret_broceliande":
			tracker["count"] = int(tracker["count"]) + 1
	if int(tracker["count"]) != 1:
		push_error("foret_broceliande should appear exactly once, got %d" % int(tracker["count"]))
		return false
	return true


func test_complete_biome_empty_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": ""}
	var result: Dictionary = StoreMap.complete_biome(state, action)
	if result.get("ok", false):
		push_error("complete_biome with empty key should return ok=false")
		return false
	return true


func test_complete_biome_updates_tier_progress() -> bool:
	var state: Dictionary = _make_state({"tier_progress": 1})
	# cotes_sauvages is tier 2 in MerlinBiomeTree
	var action: Dictionary = {"biome_key": "cotes_sauvages"}
	StoreMap.complete_biome(state, action)
	var tier: int = int(state["map_progression"].get("tier_progress", 0))
	if tier < 2:
		push_error("tier_progress should be >= 2 after completing tier-2 biome, got %d" % tier)
		return false
	return true


func test_complete_biome_does_not_decrease_tier() -> bool:
	var state: Dictionary = _make_state({"tier_progress": 3})
	# foret_broceliande is tier 1
	var action: Dictionary = {"biome_key": "foret_broceliande"}
	StoreMap.complete_biome(state, action)
	var tier: int = int(state["map_progression"].get("tier_progress", 0))
	if tier != 3:
		push_error("tier_progress should stay 3, got %d" % tier)
		return false
	return true


# =============================================================================
# COLLECT ITEM
# =============================================================================

func test_collect_item_adds_to_list() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"item_id": "bois_construction"}
	var result: Dictionary = StoreMap.collect_item(state, action)
	if not result.get("ok", false):
		push_error("collect_item should return ok=true")
		return false
	var items: Array = state["map_progression"]["items_collected"]
	if not "bois_construction" in items:
		push_error("bois_construction should be in items_collected")
		return false
	return true


func test_collect_item_no_duplicate() -> bool:
	var state: Dictionary = _make_state({"items_collected": ["bois_construction"]})
	var action: Dictionary = {"item_id": "bois_construction"}
	StoreMap.collect_item(state, action)
	var items: Array = state["map_progression"]["items_collected"]
	if items.size() != 1:
		push_error("items_collected should have 1 entry, got %d" % items.size())
		return false
	return true


func test_collect_item_empty_id_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"item_id": ""}
	var result: Dictionary = StoreMap.collect_item(state, action)
	if result.get("ok", false):
		push_error("collect_item with empty id should return ok=false")
		return false
	return true


# =============================================================================
# ADD REPUTATION
# =============================================================================

func test_add_reputation_adds_to_list() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"reputation_id": "druide"}
	var result: Dictionary = StoreMap.add_reputation(state, action)
	if not result.get("ok", false):
		push_error("add_reputation should return ok=true")
		return false
	var reps: Array = state["map_progression"]["reputations"]
	if not "druide" in reps:
		push_error("druide should be in reputations")
		return false
	return true


func test_add_reputation_no_duplicate() -> bool:
	var state: Dictionary = _make_state({"reputations": ["druide"]})
	var action: Dictionary = {"reputation_id": "druide"}
	StoreMap.add_reputation(state, action)
	var reps: Array = state["map_progression"]["reputations"]
	if reps.size() != 1:
		push_error("reputations should have 1 entry, got %d" % reps.size())
		return false
	return true


func test_add_reputation_empty_id_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"reputation_id": ""}
	var result: Dictionary = StoreMap.add_reputation(state, action)
	if result.get("ok", false):
		push_error("add_reputation with empty id should return ok=false")
		return false
	return true


# =============================================================================
# SELECT BIOME
# =============================================================================

func test_select_biome_sets_current() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": "villages_celtes"}
	var result: Dictionary = StoreMap.select_biome(state, action)
	if not result.get("ok", false):
		push_error("select_biome should return ok=true")
		return false
	var current: String = str(state["map_progression"].get("current_biome", ""))
	if current != "villages_celtes":
		push_error("current_biome should be 'villages_celtes', got '%s'" % current)
		return false
	return true


func test_select_biome_adds_to_visited() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": "villages_celtes"}
	StoreMap.select_biome(state, action)
	var visited: Array = state["map_progression"]["visited_biomes"]
	if not "villages_celtes" in visited:
		push_error("villages_celtes should be in visited_biomes")
		return false
	return true


func test_select_biome_visited_no_duplicate() -> bool:
	var state: Dictionary = _make_state({"visited_biomes": ["villages_celtes"]})
	var action: Dictionary = {"biome_key": "villages_celtes"}
	StoreMap.select_biome(state, action)
	var visited: Array = state["map_progression"]["visited_biomes"]
	if visited.size() != 1:
		push_error("visited_biomes should have 1 entry, got %d" % visited.size())
		return false
	return true


func test_select_biome_empty_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": ""}
	var result: Dictionary = StoreMap.select_biome(state, action)
	if result.get("ok", false):
		push_error("select_biome with empty key should return ok=false")
		return false
	return true
