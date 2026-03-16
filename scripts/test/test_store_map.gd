## =============================================================================
## Unit Tests — StoreMap (comprehensive)
## =============================================================================
## Tests: update_gauges, complete_biome, collect_item, add_reputation,
## select_biome — all branches, edge cases, idempotency, state isolation.
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


func test_update_gauges_returns_new_gauges_dict() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {"vigueur": 5}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.has("gauges"):
		push_error("update_gauges result should contain 'gauges' key")
		return false
	return true


func test_update_gauges_multiple_keys_in_delta() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {"esprit": 10, "vigueur": -5}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges with multi-key delta should succeed")
		return false
	return true


func test_update_gauges_negative_delta() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {"esprit": -20}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges with negative delta should succeed")
		return false
	# MerlinGaugeSystem clamps to min 0, so esprit = max(30-20, 0) = 10
	var val: int = int(state["map_progression"]["gauges"].get("esprit", -1))
	if val != 10:
		push_error("esprit should be 10 after -20 delta from 30, got %d" % val)
		return false
	return true


func test_update_gauges_clamps_to_zero() -> bool:
	var state: Dictionary = _make_state({"gauges": {"esprit": 5}})
	var action: Dictionary = {"delta": {"esprit": -100}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges should succeed even with large negative")
		return false
	var val: int = int(state["map_progression"]["gauges"].get("esprit", -1))
	if val != 0:
		push_error("esprit should clamp to 0, got %d" % val)
		return false
	return true


func test_update_gauges_clamps_to_hundred() -> bool:
	var state: Dictionary = _make_state({"gauges": {"esprit": 90}})
	var action: Dictionary = {"delta": {"esprit": 50}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges should succeed even with overflow")
		return false
	var val: int = int(state["map_progression"]["gauges"].get("esprit", -1))
	if val != 100:
		push_error("esprit should clamp to 100, got %d" % val)
		return false
	return true


func test_update_gauges_unknown_gauge_key_ignored() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"delta": {"unknown_gauge": 50}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges with unknown gauge key should still return ok=true")
		return false
	return true


func test_update_gauges_state_mutated_in_place() -> bool:
	var state: Dictionary = _make_state()
	var original_gauges: Dictionary = state["map_progression"]["gauges"].duplicate()
	var action: Dictionary = {"delta": {"esprit": 10}}
	StoreMap.update_gauges(state, action)
	var after: int = int(state["map_progression"]["gauges"].get("esprit", 0))
	var before: int = int(original_gauges.get("esprit", 0))
	if after == before:
		push_error("State should be mutated after update_gauges")
		return false
	return true


func test_update_gauges_no_map_progression_creates_it() -> bool:
	var state: Dictionary = {}
	var action: Dictionary = {"delta": {"esprit": 10}}
	var result: Dictionary = StoreMap.update_gauges(state, action)
	if not result.get("ok", false):
		push_error("update_gauges should succeed on empty state")
		return false
	if not state.has("map_progression"):
		push_error("map_progression should be created")
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
	var count: int = 0
	for b in completed:
		if str(b) == "foret_broceliande":
			count += 1
	if count != 1:
		push_error("foret_broceliande should appear exactly once, got %d" % count)
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


func test_complete_biome_no_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {}
	var result: Dictionary = StoreMap.complete_biome(state, action)
	if result.get("ok", false):
		push_error("complete_biome with no biome_key should return ok=false")
		return false
	if str(result.get("error", "")) != "No biome_key":
		push_error("Expected 'No biome_key' error")
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


func test_complete_biome_returns_completed_list() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": "villages_celtes"}
	var result: Dictionary = StoreMap.complete_biome(state, action)
	if not result.has("completed_biomes"):
		push_error("Result should contain completed_biomes array")
		return false
	var arr: Array = result["completed_biomes"]
	if not "villages_celtes" in arr:
		push_error("villages_celtes should be in result completed_biomes")
		return false
	return true


func test_complete_biome_multiple_biomes() -> bool:
	var state: Dictionary = _make_state()
	StoreMap.complete_biome(state, {"biome_key": "foret_broceliande"})
	StoreMap.complete_biome(state, {"biome_key": "villages_celtes"})
	StoreMap.complete_biome(state, {"biome_key": "cotes_sauvages"})
	var completed: Array = state["map_progression"]["completed_biomes"]
	if completed.size() != 3:
		push_error("Should have 3 completed biomes, got %d" % completed.size())
		return false
	return true


func test_complete_biome_tier4_biome() -> bool:
	var state: Dictionary = _make_state({"tier_progress": 3})
	var action: Dictionary = {"biome_key": "collines_dolmens"}
	StoreMap.complete_biome(state, action)
	var tier: int = int(state["map_progression"].get("tier_progress", 0))
	if tier != 4:
		push_error("tier_progress should be 4 after completing tier-4 biome, got %d" % tier)
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


func test_collect_item_no_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {}
	var result: Dictionary = StoreMap.collect_item(state, action)
	if result.get("ok", false):
		push_error("collect_item with no item_id should return ok=false")
		return false
	if str(result.get("error", "")) != "No item_id":
		push_error("Expected 'No item_id' error")
		return false
	return true


func test_collect_item_returns_items_list() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"item_id": "amulette_marais"}
	var result: Dictionary = StoreMap.collect_item(state, action)
	if not result.has("items_collected"):
		push_error("Result should contain items_collected array")
		return false
	return true


func test_collect_item_multiple_items() -> bool:
	var state: Dictionary = _make_state()
	StoreMap.collect_item(state, {"item_id": "bois_construction"})
	StoreMap.collect_item(state, {"item_id": "essences_bruyere"})
	StoreMap.collect_item(state, {"item_id": "amulette_marais"})
	var items: Array = state["map_progression"]["items_collected"]
	if items.size() != 3:
		push_error("Should have 3 items, got %d" % items.size())
		return false
	return true


func test_collect_item_preserves_existing() -> bool:
	var state: Dictionary = _make_state({"items_collected": ["ancien_item"]})
	StoreMap.collect_item(state, {"item_id": "nouveau_item"})
	var items: Array = state["map_progression"]["items_collected"]
	if not "ancien_item" in items:
		push_error("ancien_item should still be present")
		return false
	if not "nouveau_item" in items:
		push_error("nouveau_item should be added")
		return false
	return true


func test_collect_item_integer_coerced_to_string() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"item_id": 42}
	var result: Dictionary = StoreMap.collect_item(state, action)
	if not result.get("ok", false):
		push_error("collect_item with integer id should still work (str coercion)")
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


func test_add_reputation_no_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {}
	var result: Dictionary = StoreMap.add_reputation(state, action)
	if result.get("ok", false):
		push_error("add_reputation with no reputation_id should return ok=false")
		return false
	if str(result.get("error", "")) != "No reputation_id":
		push_error("Expected 'No reputation_id' error")
		return false
	return true


func test_add_reputation_returns_list() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"reputation_id": "ankou"}
	var result: Dictionary = StoreMap.add_reputation(state, action)
	if not result.has("reputations"):
		push_error("Result should contain reputations array")
		return false
	return true


func test_add_reputation_multiple() -> bool:
	var state: Dictionary = _make_state()
	StoreMap.add_reputation(state, {"reputation_id": "druide"})
	StoreMap.add_reputation(state, {"reputation_id": "ankou"})
	StoreMap.add_reputation(state, {"reputation_id": "korrigan"})
	var reps: Array = state["map_progression"]["reputations"]
	if reps.size() != 3:
		push_error("Should have 3 reputations, got %d" % reps.size())
		return false
	return true


func test_add_reputation_preserves_existing() -> bool:
	var state: Dictionary = _make_state({"reputations": ["ancien"]})
	StoreMap.add_reputation(state, {"reputation_id": "nouveau"})
	var reps: Array = state["map_progression"]["reputations"]
	if not "ancien" in reps or not "nouveau" in reps:
		push_error("Both old and new reputations should be present")
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


func test_select_biome_no_key_returns_error() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {}
	var result: Dictionary = StoreMap.select_biome(state, action)
	if result.get("ok", false):
		push_error("select_biome with no biome_key should return ok=false")
		return false
	if str(result.get("error", "")) != "No biome_key":
		push_error("Expected 'No biome_key' error")
		return false
	return true


func test_select_biome_returns_current() -> bool:
	var state: Dictionary = _make_state()
	var action: Dictionary = {"biome_key": "marais_korrigans"}
	var result: Dictionary = StoreMap.select_biome(state, action)
	if str(result.get("current_biome", "")) != "marais_korrigans":
		push_error("Result current_biome should be marais_korrigans")
		return false
	return true


func test_select_biome_overwrites_current() -> bool:
	var state: Dictionary = _make_state({"current_biome": "foret_broceliande"})
	StoreMap.select_biome(state, {"biome_key": "cotes_sauvages"})
	var current: String = str(state["map_progression"].get("current_biome", ""))
	if current != "cotes_sauvages":
		push_error("current_biome should be overwritten to cotes_sauvages, got '%s'" % current)
		return false
	return true


func test_select_biome_accumulates_visited() -> bool:
	var state: Dictionary = _make_state()
	StoreMap.select_biome(state, {"biome_key": "foret_broceliande"})
	StoreMap.select_biome(state, {"biome_key": "villages_celtes"})
	StoreMap.select_biome(state, {"biome_key": "cotes_sauvages"})
	var visited: Array = state["map_progression"]["visited_biomes"]
	if visited.size() != 3:
		push_error("Should have 3 visited biomes, got %d" % visited.size())
		return false
	return true


func test_select_biome_revisit_does_not_add_duplicate() -> bool:
	var state: Dictionary = _make_state()
	StoreMap.select_biome(state, {"biome_key": "foret_broceliande"})
	StoreMap.select_biome(state, {"biome_key": "villages_celtes"})
	StoreMap.select_biome(state, {"biome_key": "foret_broceliande"})
	var visited: Array = state["map_progression"]["visited_biomes"]
	if visited.size() != 2:
		push_error("Revisiting should not duplicate, expected 2, got %d" % visited.size())
		return false
	return true


# =============================================================================
# CROSS-METHOD / STATE ISOLATION
# =============================================================================

func test_collect_item_does_not_affect_reputations() -> bool:
	var state: Dictionary = _make_state({"reputations": ["druide"]})
	StoreMap.collect_item(state, {"item_id": "bois_construction"})
	var reps: Array = state["map_progression"]["reputations"]
	if reps.size() != 1 or str(reps[0]) != "druide":
		push_error("collect_item should not alter reputations")
		return false
	return true


func test_add_reputation_does_not_affect_items() -> bool:
	var state: Dictionary = _make_state({"items_collected": ["bois_construction"]})
	StoreMap.add_reputation(state, {"reputation_id": "ankou"})
	var items: Array = state["map_progression"]["items_collected"]
	if items.size() != 1 or str(items[0]) != "bois_construction":
		push_error("add_reputation should not alter items_collected")
		return false
	return true


func test_select_biome_does_not_affect_completed() -> bool:
	var state: Dictionary = _make_state({"completed_biomes": ["foret_broceliande"]})
	StoreMap.select_biome(state, {"biome_key": "villages_celtes"})
	var completed: Array = state["map_progression"]["completed_biomes"]
	if completed.size() != 1:
		push_error("select_biome should not alter completed_biomes")
		return false
	return true


func test_complete_biome_does_not_affect_visited() -> bool:
	var state: Dictionary = _make_state({"visited_biomes": ["foret_broceliande"]})
	StoreMap.complete_biome(state, {"biome_key": "villages_celtes"})
	var visited: Array = state["map_progression"]["visited_biomes"]
	if "villages_celtes" in visited:
		push_error("complete_biome should not add to visited_biomes")
		return false
	return true


func test_empty_state_collect_item() -> bool:
	var state: Dictionary = {}
	var result: Dictionary = StoreMap.collect_item(state, {"item_id": "test_item"})
	if not result.get("ok", false):
		push_error("collect_item on empty state should succeed")
		return false
	return true


func test_empty_state_add_reputation() -> bool:
	var state: Dictionary = {}
	var result: Dictionary = StoreMap.add_reputation(state, {"reputation_id": "test_rep"})
	if not result.get("ok", false):
		push_error("add_reputation on empty state should succeed")
		return false
	return true


func test_empty_state_select_biome() -> bool:
	var state: Dictionary = {}
	var result: Dictionary = StoreMap.select_biome(state, {"biome_key": "test_biome"})
	if not result.get("ok", false):
		push_error("select_biome on empty state should succeed")
		return false
	return true
