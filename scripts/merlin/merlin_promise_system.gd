## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Promise System — Promise lifecycle management
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from MerlinCardSystem. Handles creation, tracking, evaluation,
## and resolution of narrative promises during runs.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinPromiseSystem


func create_promise(run_state: Dictionary, promise_data: Dictionary) -> bool:
	var active: Array = run_state.get("active_promises", [])
	if active.size() >= MerlinConstants.MAX_ACTIVE_PROMISES:
		push_warning("[MerlinPromises] Max promises reached (%d)" % MerlinConstants.MAX_ACTIVE_PROMISES)
		return false

	var promise_id: String = str(promise_data.get("promise_id", ""))
	if promise_id.is_empty():
		return false

	# Check not already active
	for p in active:
		if p is Dictionary and str(p.get("promise_id", "")) == promise_id:
			push_warning("[MerlinPromises] Promise already active: %s" % promise_id)
			return false

	var card_index: int = int(run_state.get("card_index", 0))
	var deadline: int = int(promise_data.get("deadline_cards", 5))

	var promise: Dictionary = {
		"promise_id": promise_id,
		"created_at_card": card_index,
		"deadline_card": card_index + deadline,
		"condition_type": str(promise_data.get("condition_type", "")),
		"condition_value": promise_data.get("condition_value", 0),
		"condition_faction": str(promise_data.get("condition_faction", "")),
		"reward_trust": int(promise_data.get("reward_trust", 10)),
		"penalty_trust": int(promise_data.get("penalty_trust", -15)),
		"description": str(promise_data.get("description", "")),
	}

	active.append(promise)
	run_state["active_promises"] = active

	# Init tracking counters
	var tracking: Dictionary = run_state.get("promise_tracking", {})
	tracking[promise_id] = {
		"faction_gained": {},
		"minigame_wins": 0,
		"healing_done": 0,
		"damage_taken": 0,
		"safe_choices": 0,
		"tags_acquired": [],
	}
	run_state["promise_tracking"] = tracking

	return true


func resolve_promise(promise_id: String, kept: bool) -> Dictionary:
	var trust_delta: int
	if kept:
		trust_delta = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 10))
	else:
		trust_delta = int(MerlinConstants.TRUST_DELTAS.get("promise_broken", -15))
	return {"promise_id": promise_id, "kept": kept, "trust_delta": trust_delta}


func check_promises(run_state: Dictionary) -> Array:
	var card_index: int = int(run_state.get("card_index", 0))
	var active: Array = run_state.get("active_promises", [])
	var tracking: Dictionary = run_state.get("promise_tracking", {})
	var results: Array = []
	var remaining: Array = []

	for promise in active:
		if not (promise is Dictionary):
			continue
		var pid: String = str(promise.get("promise_id", ""))
		var deadline: int = int(promise.get("deadline_card", 0))

		if card_index >= deadline:
			# Check if condition was met
			var kept: bool = _evaluate_promise_condition(promise, run_state, tracking.get(pid, {}))
			results.append(resolve_promise(pid, kept))
			# Cleanup tracking
			tracking.erase(pid)
		else:
			remaining.append(promise)

	run_state["active_promises"] = remaining
	run_state["promise_tracking"] = tracking
	return results


func _evaluate_promise_condition(promise: Dictionary, run_state: Dictionary, track: Dictionary) -> bool:
	var ctype: String = str(promise.get("condition_type", ""))
	var cvalue = promise.get("condition_value", 0)

	match ctype:
		"life_above":
			return int(run_state.get("life_essence", 0)) >= int(cvalue)
		"faction_gain":
			var faction: String = str(promise.get("condition_faction", ""))
			var gained: Dictionary = track.get("faction_gained", {})
			return float(gained.get(faction, 0.0)) >= float(cvalue)
		"minigame_wins":
			return int(track.get("minigame_wins", 0)) >= int(cvalue)
		"no_safe":
			return int(track.get("safe_choices", 0)) == 0
		"tag_acquired":
			var tags: Array = track.get("tags_acquired", [])
			return tags.has(str(cvalue))
		"accept_damage":
			return int(track.get("damage_taken", 0)) >= int(cvalue)
		"total_healing":
			return int(track.get("healing_done", 0)) >= int(cvalue)
	return false


func update_promise_tracking(run_state: Dictionary, event_type: String, data: Dictionary) -> void:
	var tracking: Dictionary = run_state.get("promise_tracking", {})
	for pid in tracking:
		var track: Dictionary = tracking[pid]

		match event_type:
			"faction_gain":
				var faction: String = str(data.get("faction", ""))
				var amount: float = float(data.get("amount", 0))
				var gained: Dictionary = track.get("faction_gained", {})
				gained[faction] = float(gained.get(faction, 0.0)) + amount
				track["faction_gained"] = gained
			"minigame_win":
				track["minigame_wins"] = int(track.get("minigame_wins", 0)) + 1
			"healing":
				track["healing_done"] = int(track.get("healing_done", 0)) + int(data.get("amount", 0))
			"damage":
				track["damage_taken"] = int(track.get("damage_taken", 0)) + 1
			"safe_choice":
				track["safe_choices"] = int(track.get("safe_choices", 0)) + 1
			"tag_acquired":
				var tags: Array = track.get("tags_acquired", [])
				var tag: String = str(data.get("tag", ""))
				if not tags.has(tag):
					tags.append(tag)
				track["tags_acquired"] = tags

		tracking[pid] = track
	run_state["promise_tracking"] = tracking
