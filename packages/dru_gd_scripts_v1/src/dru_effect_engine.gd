extends RefCounted
class_name DruEffectEngine

const MAX_STATUS_TURNS := 5
const MAX_BUFF_TURNS := 5
const MAX_BUFF_DELTA := 30
const MAX_MOMENTUM := 100
const MIN_HP_OUTSIDE_COMBAT := 1
const PITY_CAP := 3

const VALID_CODES := {
	"ADD_RUN_RESOURCE": 2,
	"SET_RUN_RESOURCE": 2,
	"CONSUME_RUN_RESOURCE": 2,
	"GAIN_ESSENCE": 2,
	"CONSUME_ESSENCE": 2,
	"GAIN_OGHAM": 1,
	"CONSUME_OGHAM": 1,
	"GAIN_LIENS": 1,
	"CONSUME_LIENS": 1,
	"BESTIOLE_NEED": 2,
	"BESTIOLE_SET_NEED": 2,
	"BESTIOLE_TENDENCY": 2,
	"BOND_XP": 1,
	"BESTIOLE_XP": 1,
	"BESTIOLE_EVOLVE_READY": 1,
	"UNLOCK_EVOLUTION_STAGE": 1,
	"HP_DELTA": 2,
	"SET_HP": 2,
	"APPLY_STATUS": 3,
	"REMOVE_STATUS": 2,
	"CLEANSE_ALL_NEG": 1,
	"BUFF_STAT": 4,
	"DEBUFF_STAT": 4,
	"SET_POSTURE": 1,
	"MOMENTUM_DELTA": 1,
	"ADVANCE_FLOOR": 1,
	"SET_NODE_TYPE_NEXT": 1,
	"REVEAL_MAP_INFO": 2,
	"ADD_ITEM": 2,
	"REMOVE_ITEM": 2,
	"ADD_RELIC": 1,
	"REMOVE_RELIC": 1,
	"ACH_PROGRESS": 2,
	"ACH_UNLOCK": 1,
	"UNLOCK": 1,
	"GRANT_LOADOUT_PACKAGE": 1,
	"SET_ACTIVE_PACKAGE": 1,
	"LOG_STORY_TAG": 1,
	"LOG_MERLIN_TONE": 1,
	"LOG_BESTIOLE_REACTION": 1,
	"GRANT_PITY": 1,
	"REDUCE_DIFFICULTY_NEXT": 1,
	"FORCE_SOFT_SUCCESS": 1,
}


func validate_effect(effect_code: String) -> bool:
	var parsed = _parse_effect(effect_code)
	return parsed["ok"]


func apply_effects(state: Dictionary, effects: Array, source: String = "SYSTEM") -> Dictionary:
	var result := {
		"applied": [],
		"rejected": [],
		"errors": [],
	}
	for effect in effects:
		if typeof(effect) != TYPE_STRING:
			result["rejected"].append(effect)
			continue
		var parsed = _parse_effect(effect)
		if not parsed["ok"]:
			result["rejected"].append(effect)
			result["errors"].append(parsed["error"])
			_record(state, effect, source, "rejected")
			continue
		if _apply_parsed(state, parsed):
			result["applied"].append(effect)
			_record(state, effect, source, "applied")
		else:
			result["rejected"].append(effect)
			_record(state, effect, source, "rejected")
	return result


func _parse_effect(effect_code: String) -> Dictionary:
	var parts := effect_code.split(":")
	if parts.is_empty():
		return {"ok": false, "error": "Empty effect"}
	var code := parts[0]
	if not VALID_CODES.has(code):
		return {"ok": false, "error": "Unknown effect: %s" % code}
	var expected := int(VALID_CODES[code])
	var args := parts.slice(1, parts.size())
	if args.size() != expected:
		return {"ok": false, "error": "Bad arg count for %s" % code}
	return {
		"ok": true,
		"code": code,
		"args": args,
	}


func _apply_parsed(state: Dictionary, parsed: Dictionary) -> bool:
	var code: String = parsed["code"]
	var args: Array = parsed["args"]
	match code:
		"ADD_RUN_RESOURCE":
			return _apply_run_resource_delta(state, args[0], _to_int(args[1]))
		"SET_RUN_RESOURCE":
			return _apply_run_resource_set(state, args[0], _to_int(args[1]))
		"CONSUME_RUN_RESOURCE":
			return _apply_run_resource_delta(state, args[0], -abs(_to_int(args[1])))
		"GAIN_ESSENCE":
			return _apply_meta_essence(state, args[0], _to_int(args[1]))
		"CONSUME_ESSENCE":
			return _apply_meta_essence(state, args[0], -abs(_to_int(args[1])))
		"GAIN_OGHAM":
			return _apply_meta_counter(state, "ogham_fragments", _to_int(args[0]))
		"CONSUME_OGHAM":
			return _apply_meta_counter(state, "ogham_fragments", -abs(_to_int(args[0])))
		"GAIN_LIENS":
			return _apply_meta_counter(state, "liens", _to_int(args[0]))
		"CONSUME_LIENS":
			return _apply_meta_counter(state, "liens", -abs(_to_int(args[0])))
		"BESTIOLE_NEED":
			return _apply_need_delta(state, args[0], _to_int(args[1]))
		"BESTIOLE_SET_NEED":
			return _apply_need_set(state, args[0], _to_int(args[1]))
		"BESTIOLE_TENDENCY":
			return _apply_tendency_delta(state, args[0], _to_int(args[1]))
		"BOND_XP":
			return _apply_bestiole_counter(state, "bond_xp", _to_int(args[0]))
		"BESTIOLE_XP":
			return _apply_bestiole_counter(state, "xp", _to_int(args[0]))
		"BESTIOLE_EVOLVE_READY":
			return _apply_flag(state, "bestiole", "evolve_ready", args[0])
		"UNLOCK_EVOLUTION_STAGE":
			return _apply_unlock_list(state, "unlocked_evolutions", args[0])
		"HP_DELTA":
			return _apply_hp_delta(state, args[0], _to_int(args[1]))
		"SET_HP":
			return _apply_hp_set(state, args[0], _to_int(args[1]))
		"APPLY_STATUS":
			return _apply_status(state, args[0], args[1], _to_int(args[2]))
		"REMOVE_STATUS":
			return _remove_status(state, args[0], args[1])
		"CLEANSE_ALL_NEG":
			return _cleanse_all(state, args[0])
		"BUFF_STAT":
			return _apply_buff(state, args[0], args[1], _to_int(args[2]), _to_int(args[3]))
		"DEBUFF_STAT":
			return _apply_buff(state, args[0], args[1], -abs(_to_int(args[2])), _to_int(args[3]))
		"SET_POSTURE":
			return _set_posture(state, args[0])
		"MOMENTUM_DELTA":
			return _apply_momentum_delta(state, _to_int(args[0]))
		"ADVANCE_FLOOR":
			return _apply_floor_delta(state, _to_int(args[0]))
		"SET_NODE_TYPE_NEXT":
			return _set_next_node_type(state, args[0])
		"REVEAL_MAP_INFO":
			return _reveal_map_info(state, args[0], _to_int(args[1]))
		"ADD_ITEM":
			return _apply_item_delta(state, args[0], _to_int(args[1]))
		"REMOVE_ITEM":
			return _apply_item_delta(state, args[0], -abs(_to_int(args[1])))
		"ADD_RELIC":
			return _apply_relic(state, args[0], true)
		"REMOVE_RELIC":
			return _apply_relic(state, args[0], false)
		"ACH_PROGRESS":
			return _apply_achievement_progress(state, args[0], _to_int(args[1]))
		"ACH_UNLOCK":
			return _apply_achievement_unlock(state, args[0])
		"UNLOCK":
			return _apply_unlock_list(state, "unlocks", args[0])
		"GRANT_LOADOUT_PACKAGE":
			return _apply_unlock_list(state, "packages", args[0])
		"SET_ACTIVE_PACKAGE":
			return _set_meta_value(state, "active_package", args[0])
		"LOG_STORY_TAG":
			return _log_story(state, {"tag": args[0]})
		"LOG_MERLIN_TONE":
			return _log_story(state, {"tone": args[0]})
		"LOG_BESTIOLE_REACTION":
			return _log_story(state, {"reaction": args[0]})
		"GRANT_PITY":
			return _apply_pity(state, _to_int(args[0]))
		"REDUCE_DIFFICULTY_NEXT":
			return _apply_difficulty_mod(state, _to_int(args[0]))
		"FORCE_SOFT_SUCCESS":
			return _apply_force_soft_success(state, args[0])
		_:
			return false


func _apply_run_resource_delta(state: Dictionary, res: String, delta: int) -> bool:
	var run = state.get("run", {})
	var resources = run.get("resources", {})
	var cap = run.get("resource_caps", {}).get(res, 9)
	var current = int(resources.get(res, 0))
	resources[res] = clampi(current + delta, 0, cap)
	run["resources"] = resources
	state["run"] = run
	return true


func _apply_run_resource_set(state: Dictionary, res: String, value: int) -> bool:
	var run = state.get("run", {})
	var resources = run.get("resources", {})
	var cap = run.get("resource_caps", {}).get(res, 9)
	resources[res] = clampi(value, 0, cap)
	run["resources"] = resources
	state["run"] = run
	return true


func _apply_meta_essence(state: Dictionary, element: String, delta: int) -> bool:
	var meta = state.get("meta", {})
	var essence = meta.get("essence", {})
	var current = int(essence.get(element, 0))
	essence[element] = max(0, current + delta)
	meta["essence"] = essence
	state["meta"] = meta
	return true


func _apply_meta_counter(state: Dictionary, key: String, delta: int) -> bool:
	var meta = state.get("meta", {})
	var current = int(meta.get(key, 0))
	meta[key] = max(0, current + delta)
	state["meta"] = meta
	return true


func _apply_need_delta(state: Dictionary, need: String, delta: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var needs = bestiole.get("needs", {})
	var current = int(needs.get(need, 50))
	needs[need] = clampi(current + delta, 0, 100)
	bestiole["needs"] = needs
	state["bestiole"] = bestiole
	return true


func _apply_need_set(state: Dictionary, need: String, value: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var needs = bestiole.get("needs", {})
	needs[need] = clampi(value, 0, 100)
	bestiole["needs"] = needs
	state["bestiole"] = bestiole
	return true


func _apply_tendency_delta(state: Dictionary, key: String, delta: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var tendency = bestiole.get("tendency", {})
	var current = int(tendency.get(key, 0))
	tendency[key] = clampi(current + delta, -100, 100)
	bestiole["tendency"] = tendency
	state["bestiole"] = bestiole
	return true


func _apply_bestiole_counter(state: Dictionary, key: String, delta: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var current = int(bestiole.get(key, 0))
	bestiole[key] = max(0, current + delta)
	state["bestiole"] = bestiole
	return true


func _apply_flag(state: Dictionary, section: String, key: String, flag: String) -> bool:
	var container = state.get(section, {})
	container[key] = (flag == "flag_on")
	state[section] = container
	return true


func _apply_unlock_list(state: Dictionary, key: String, value: String) -> bool:
	var meta = state.get("meta", {})
	var list = meta.get(key, [])
	if not list.has(value):
		list.append(value)
	meta[key] = list
	state["meta"] = meta
	return true


func _apply_hp_delta(state: Dictionary, target: String, delta: int) -> bool:
	if target == "player":
		var bestiole = state.get("bestiole", {})
		var max_hp = int(bestiole.get("max_hp", 1))
		var hp = int(bestiole.get("hp", max_hp))
		hp = clampi(hp + delta, MIN_HP_OUTSIDE_COMBAT, max_hp)
		bestiole["hp"] = hp
		state["bestiole"] = bestiole
		return true
	if target == "enemy":
		var combat = state.get("combat", {})
		var enemy = combat.get("enemy", {})
		var max_hp = int(enemy.get("max_hp", enemy.get("hp", 1)))
		var hp = int(enemy.get("hp", max_hp))
		hp = clampi(hp + delta, 0, max_hp)
		enemy["hp"] = hp
		combat["enemy"] = enemy
		state["combat"] = combat
		return true
	return false


func _apply_hp_set(state: Dictionary, target: String, value: int) -> bool:
	if target == "player":
		var bestiole = state.get("bestiole", {})
		var max_hp = int(bestiole.get("max_hp", 1))
		bestiole["hp"] = clampi(value, MIN_HP_OUTSIDE_COMBAT, max_hp)
		state["bestiole"] = bestiole
		return true
	if target == "enemy":
		var combat = state.get("combat", {})
		var enemy = combat.get("enemy", {})
		var max_hp = int(enemy.get("max_hp", enemy.get("hp", 1)))
		enemy["hp"] = clampi(value, 0, max_hp)
		combat["enemy"] = enemy
		state["combat"] = combat
		return true
	return false


func _apply_status(state: Dictionary, target: String, status_id: String, turns: int) -> bool:
	turns = clampi(turns, 1, MAX_STATUS_TURNS)
	var entry = {"id": status_id, "turns": turns}
	var combat = state.get("combat", {})
	if target == "player":
		var list = combat.get("player_statuses", [])
		list.append(entry)
		combat["player_statuses"] = list
	elif target == "enemy":
		var list = combat.get("enemy_statuses", [])
		list.append(entry)
		combat["enemy_statuses"] = list
	else:
		return false
	state["combat"] = combat
	return true


func _remove_status(state: Dictionary, target: String, status_id: String) -> bool:
	var combat = state.get("combat", {})
	var key = "player_statuses" if target == "player" else "enemy_statuses"
	var list = combat.get(key, [])
	var filtered := []
	for entry in list:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id", "") == status_id:
			continue
		filtered.append(entry)
	combat[key] = filtered
	state["combat"] = combat
	return true


func _cleanse_all(state: Dictionary, target: String) -> bool:
	var combat = state.get("combat", {})
	if target == "player":
		combat["player_statuses"] = []
	elif target == "enemy":
		combat["enemy_statuses"] = []
	else:
		return false
	state["combat"] = combat
	return true


func _apply_buff(state: Dictionary, target: String, stat: String, delta: int, turns: int) -> bool:
	turns = clampi(turns, 1, MAX_BUFF_TURNS)
	delta = clampi(delta, -MAX_BUFF_DELTA, MAX_BUFF_DELTA)
	var entry = {"stat": stat, "delta": delta, "turns": turns}
	var combat = state.get("combat", {})
	var key = "player_buffs" if target == "player" else "enemy_buffs"
	var list = combat.get(key, [])
	list.append(entry)
	combat[key] = list
	state["combat"] = combat
	return true


func _set_posture(state: Dictionary, posture: String) -> bool:
	var run = state.get("run", {})
	run["posture"] = posture
	state["run"] = run
	return true


func _apply_momentum_delta(state: Dictionary, delta: int) -> bool:
	var run = state.get("run", {})
	var momentum = int(run.get("momentum", 0))
	run["momentum"] = clampi(momentum + delta, 0, MAX_MOMENTUM)
	state["run"] = run
	return true


func _apply_floor_delta(state: Dictionary, delta: int) -> bool:
	var run = state.get("run", {})
	run["floor"] = max(0, int(run.get("floor", 0)) + delta)
	state["run"] = run
	return true


func _set_next_node_type(state: Dictionary, node_type: String) -> bool:
	var run = state.get("run", {})
	run["next_node_override"] = node_type
	state["run"] = run
	return true


func _reveal_map_info(state: Dictionary, info_type: String, amount: int) -> bool:
	var run = state.get("run", {})
	var reveals = run.get("map_reveals", [])
	reveals.append({"type": info_type, "amount": amount})
	run["map_reveals"] = reveals
	state["run"] = run
	return true


func _apply_item_delta(state: Dictionary, item_id: String, delta: int) -> bool:
	var run = state.get("run", {})
	var items = run.get("inventory", {})
	var current = int(items.get(item_id, 0))
	items[item_id] = max(0, current + delta)
	run["inventory"] = items
	state["run"] = run
	return true


func _apply_relic(state: Dictionary, relic_id: String, add: bool) -> bool:
	var run = state.get("run", {})
	var relics = run.get("relics", [])
	if add:
		if not relics.has(relic_id):
			relics.append(relic_id)
	else:
		relics.erase(relic_id)
	run["relics"] = relics
	state["run"] = run
	return true


func _apply_achievement_progress(state: Dictionary, ach_id: String, delta: int) -> bool:
	var meta = state.get("meta", {})
	var achievements = meta.get("achievements", {})
	var current = int(achievements.get(ach_id, 0))
	achievements[ach_id] = max(0, current + delta)
	meta["achievements"] = achievements
	state["meta"] = meta
	return true


func _apply_achievement_unlock(state: Dictionary, ach_id: String) -> bool:
	var meta = state.get("meta", {})
	var unlocked = meta.get("ach_unlocked", [])
	if not unlocked.has(ach_id):
		unlocked.append(ach_id)
	meta["ach_unlocked"] = unlocked
	state["meta"] = meta
	return true


func _set_meta_value(state: Dictionary, key: String, value: Variant) -> bool:
	var meta = state.get("meta", {})
	meta[key] = value
	state["meta"] = meta
	return true


func _log_story(state: Dictionary, entry: Dictionary) -> bool:
	var log = state.get("story_log", [])
	log.append(entry)
	state["story_log"] = log
	return true


func _apply_pity(state: Dictionary, delta: int) -> bool:
	var run = state.get("run", {})
	var streak = int(run.get("fail_streak", 0))
	run["fail_streak"] = clampi(streak + delta, 0, PITY_CAP)
	state["run"] = run
	return true


func _apply_difficulty_mod(state: Dictionary, delta: int) -> bool:
	var run = state.get("run", {})
	run["difficulty_mod_next"] = delta
	state["run"] = run
	return true


func _apply_force_soft_success(state: Dictionary, flag: String) -> bool:
	var run = state.get("run", {})
	run["force_soft_success"] = (flag == "true" or flag == "1" or flag == "flag_on")
	state["run"] = run
	return true


func _record(state: Dictionary, effect: String, source: String, status: String) -> void:
	var log = state.get("effect_log", [])
	log.append({
		"effect": effect,
		"source": source,
		"status": status,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	state["effect_log"] = log


func _to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return int(str(value))
