extends RefCounted
class_name DruEffectEngine

const MAX_STATUS_TURNS := 5
const MAX_BUFF_TURNS := 5
const MAX_BUFF_DELTA := 30
const MAX_MOMENTUM := 100
const MIN_HP_OUTSIDE_COMBAT := 1
const PITY_CAP := 3

const VALID_CODES := {
	# ═══════════════════════════════════════════════════════════════════════════
	# TRIADE SYSTEM (v0.3.0)
	# ═══════════════════════════════════════════════════════════════════════════
	"SHIFT_ASPECT": 2,     # SHIFT_ASPECT:Corps:up / SHIFT_ASPECT:Ame:down
	"SET_ASPECT": 2,       # SET_ASPECT:Monde:0 (0=EQUILIBRE, -1=BAS, 1=HAUT)
	"USE_SOUFFLE": 1,      # USE_SOUFFLE:1
	"ADD_SOUFFLE": 1,      # ADD_SOUFFLE:2
	"PROGRESS_MISSION": 1, # PROGRESS_MISSION:1
	"ADD_KARMA": 1,        # ADD_KARMA:10 (hidden)
	"ADD_TENSION": 1,      # ADD_TENSION:15 (hidden)
	"ADD_NARRATIVE_DEBT": 2, # ADD_NARRATIVE_DEBT:trahison:La trahison reviendra
	# ═══════════════════════════════════════════════════════════════════════════
	# REIGNS-STYLE GAUGES (DEPRECATED - kept for compatibility)
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_GAUGE": 2,        # ADD_GAUGE:Vigueur:10
	"REMOVE_GAUGE": 2,     # REMOVE_GAUGE:Esprit:15
	"SET_GAUGE": 2,        # SET_GAUGE:Faveur:50
	# ═══════════════════════════════════════════════════════════════════════════
	# FLAGS & NARRATIVE (NEW)
	# ═══════════════════════════════════════════════════════════════════════════
	"SET_FLAG": 2,         # SET_FLAG:met_druide:true
	"ADD_TAG": 1,          # ADD_TAG:war_brewing
	"REMOVE_TAG": 1,       # REMOVE_TAG:peace
	"QUEUE_CARD": 1,       # QUEUE_CARD:card_finale
	"TRIGGER_ARC": 1,      # TRIGGER_ARC:druide_arc
	# ═══════════════════════════════════════════════════════════════════════════
	# PROMISE SYSTEM (NEW)
	# ═══════════════════════════════════════════════════════════════════════════
	"CREATE_PROMISE": 3,   # CREATE_PROMISE:oath_001:5:description
	"FULFILL_PROMISE": 1,  # FULFILL_PROMISE:oath_001
	"BREAK_PROMISE": 1,    # BREAK_PROMISE:oath_001
	# ═══════════════════════════════════════════════════════════════════════════
	# BESTIOLE BOND (NEW)
	# ═══════════════════════════════════════════════════════════════════════════
	"MODIFY_BOND": 1,      # MODIFY_BOND:5
	"SET_SKILL_COOLDOWN": 2,  # SET_SKILL_COOLDOWN:beith:3
	# ═══════════════════════════════════════════════════════════════════════════
	# LEGACY RUN RESOURCES (kept for compatibility)
	# ═══════════════════════════════════════════════════════════════════════════
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
		# ═══════════════════════════════════════════════════════════════════════
		# TRIADE SYSTEM (v0.3.0)
		# ═══════════════════════════════════════════════════════════════════════
		"SHIFT_ASPECT":
			return _apply_shift_aspect(state, args[0], args[1])
		"SET_ASPECT":
			return _apply_set_aspect(state, args[0], _to_int(args[1]))
		"USE_SOUFFLE":
			return _apply_use_souffle(state, _to_int(args[0]))
		"ADD_SOUFFLE":
			return _apply_add_souffle(state, _to_int(args[0]))
		"PROGRESS_MISSION":
			return _apply_progress_mission(state, _to_int(args[0]))
		"ADD_KARMA":
			return _apply_hidden_counter(state, "karma", _to_int(args[0]))
		"ADD_TENSION":
			return _apply_hidden_counter(state, "tension", _to_int(args[0]))
		"ADD_NARRATIVE_DEBT":
			return _apply_narrative_debt(state, args[0], args[1])
		# ═══════════════════════════════════════════════════════════════════════
		# REIGNS-STYLE GAUGES (deprecated)
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_GAUGE":
			return _apply_gauge_delta(state, args[0], _to_int(args[1]))
		"REMOVE_GAUGE":
			return _apply_gauge_delta(state, args[0], -abs(_to_int(args[1])))
		"SET_GAUGE":
			return _apply_gauge_set(state, args[0], _to_int(args[1]))
		# ═══════════════════════════════════════════════════════════════════════
		# FLAGS & NARRATIVE
		# ═══════════════════════════════════════════════════════════════════════
		"SET_FLAG":
			return _apply_global_flag(state, args[0], args[1])
		"ADD_TAG":
			return _apply_tag(state, args[0], true)
		"REMOVE_TAG":
			return _apply_tag(state, args[0], false)
		"QUEUE_CARD":
			return _queue_card(state, args[0])
		"TRIGGER_ARC":
			return _trigger_arc(state, args[0])
		# ═══════════════════════════════════════════════════════════════════════
		# PROMISE SYSTEM
		# ═══════════════════════════════════════════════════════════════════════
		"CREATE_PROMISE":
			return _create_promise(state, args[0], _to_int(args[1]), args[2])
		"FULFILL_PROMISE":
			return _fulfill_promise(state, args[0])
		"BREAK_PROMISE":
			return _break_promise(state, args[0])
		# ═══════════════════════════════════════════════════════════════════════
		# BESTIOLE BOND
		# ═══════════════════════════════════════════════════════════════════════
		"MODIFY_BOND":
			return _apply_bond_delta(state, _to_int(args[0]))
		"SET_SKILL_COOLDOWN":
			return _set_skill_cooldown(state, args[0], _to_int(args[1]))
		# ═══════════════════════════════════════════════════════════════════════
		# LEGACY
		# ═══════════════════════════════════════════════════════════════════════
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
	var story_log = state.get("story_log", [])
	story_log.append(entry)
	state["story_log"] = story_log
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
	var effect_log = state.get("effect_log", [])
	effect_log.append({
		"effect": effect,
		"source": source,
		"status": status,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	state["effect_log"] = effect_log


func _to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return int(str(value))


# ═══════════════════════════════════════════════════════════════════════════════
# REIGNS-STYLE GAUGE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_gauge_delta(state: Dictionary, gauge: String, delta: int) -> bool:
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})
	var current = int(gauges.get(gauge, DruConstants.REIGNS_GAUGE_START))
	gauges[gauge] = clampi(current + delta, DruConstants.REIGNS_GAUGE_MIN, DruConstants.REIGNS_GAUGE_MAX)
	run["gauges"] = gauges
	state["run"] = run
	return true


func _apply_gauge_set(state: Dictionary, gauge: String, value: int) -> bool:
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})
	gauges[gauge] = clampi(value, DruConstants.REIGNS_GAUGE_MIN, DruConstants.REIGNS_GAUGE_MAX)
	run["gauges"] = gauges
	state["run"] = run
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FLAGS & NARRATIVE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_global_flag(state: Dictionary, flag_name: String, value: String) -> bool:
	var flags = state.get("flags", {})
	flags[flag_name] = (value == "true" or value == "1" or value == "flag_on")
	state["flags"] = flags
	return true


func _apply_tag(state: Dictionary, tag: String, add: bool) -> bool:
	var run = state.get("run", {})
	var tags = run.get("active_tags", [])
	if add:
		if not tags.has(tag):
			tags.append(tag)
	else:
		tags.erase(tag)
	run["active_tags"] = tags
	state["run"] = run
	return true


func _queue_card(state: Dictionary, card_id: String) -> bool:
	var run = state.get("run", {})
	var queue = run.get("card_queue", [])
	queue.append(card_id)
	run["card_queue"] = queue
	state["run"] = run
	return true


func _trigger_arc(state: Dictionary, arc_id: String) -> bool:
	var run = state.get("run", {})
	run["current_arc"] = arc_id
	state["run"] = run
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE SYSTEM FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _create_promise(state: Dictionary, promise_id: String, deadline_days: int, description: String) -> bool:
	var run = state.get("run", {})
	var promises = run.get("active_promises", [])
	var current_day = int(run.get("day", 1))
	var promise = {
		"id": promise_id,
		"description": description,
		"created_day": current_day,
		"deadline_day": current_day + deadline_days,
		"status": "active",
	}
	promises.append(promise)
	run["active_promises"] = promises
	state["run"] = run
	return true


func _fulfill_promise(state: Dictionary, promise_id: String) -> bool:
	var run = state.get("run", {})
	var promises = run.get("active_promises", [])
	for i in range(promises.size()):
		if promises[i].get("id", "") == promise_id:
			promises[i]["status"] = "fulfilled"
			run["active_promises"] = promises
			state["run"] = run
			return true
	return false


func _break_promise(state: Dictionary, promise_id: String) -> bool:
	var run = state.get("run", {})
	var promises = run.get("active_promises", [])
	for i in range(promises.size()):
		if promises[i].get("id", "") == promise_id:
			promises[i]["status"] = "broken"
			run["active_promises"] = promises
			state["run"] = run
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE BOND FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_bond_delta(state: Dictionary, delta: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var current = int(bestiole.get("bond", 50))
	bestiole["bond"] = clampi(current + delta, 0, 100)
	state["bestiole"] = bestiole
	return true


func _set_skill_cooldown(state: Dictionary, skill_id: String, turns: int) -> bool:
	var bestiole = state.get("bestiole", {})
	var cooldowns = bestiole.get("skill_cooldowns", {})
	cooldowns[skill_id] = max(0, turns)
	bestiole["skill_cooldowns"] = cooldowns
	state["bestiole"] = bestiole
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM FUNCTIONS (v0.3.0)
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_shift_aspect(state: Dictionary, aspect: String, direction: String) -> bool:
	if aspect not in DruConstants.TRIADE_ASPECTS:
		return false

	var run = state.get("run", {})
	var aspects = run.get("aspects", {})
	var current_state: int = int(aspects.get(aspect, DruConstants.AspectState.EQUILIBRE))
	var new_state: int = current_state

	if direction == "up":
		new_state = mini(current_state + 1, DruConstants.AspectState.HAUT)
	elif direction == "down":
		new_state = maxi(current_state - 1, DruConstants.AspectState.BAS)
	else:
		return false

	aspects[aspect] = new_state
	run["aspects"] = aspects
	state["run"] = run
	return true


func _apply_set_aspect(state: Dictionary, aspect: String, new_state: int) -> bool:
	if aspect not in DruConstants.TRIADE_ASPECTS:
		return false

	new_state = clampi(new_state, DruConstants.AspectState.BAS, DruConstants.AspectState.HAUT)

	var run = state.get("run", {})
	var aspects = run.get("aspects", {})
	aspects[aspect] = new_state
	run["aspects"] = aspects
	state["run"] = run
	return true


func _apply_use_souffle(state: Dictionary, amount: int) -> bool:
	var run = state.get("run", {})
	var current = int(run.get("souffle", DruConstants.SOUFFLE_START))
	run["souffle"] = maxi(current - amount, 0)
	state["run"] = run
	return true


func _apply_add_souffle(state: Dictionary, amount: int) -> bool:
	var run = state.get("run", {})
	var current = int(run.get("souffle", DruConstants.SOUFFLE_START))
	run["souffle"] = mini(current + amount, DruConstants.SOUFFLE_MAX)
	state["run"] = run
	return true


func _apply_progress_mission(state: Dictionary, step: int) -> bool:
	var run = state.get("run", {})
	var mission = run.get("mission", {})
	var current = int(mission.get("progress", 0))
	var total = int(mission.get("total", 0))
	mission["progress"] = mini(current + step, total)
	run["mission"] = mission
	state["run"] = run
	return true


func _apply_hidden_counter(state: Dictionary, key: String, delta: int) -> bool:
	var run = state.get("run", {})
	var hidden = run.get("hidden", {})
	var current = int(hidden.get(key, 0))

	if key == "tension":
		hidden[key] = clampi(current + delta, 0, 100)
	else:
		hidden[key] = current + delta

	run["hidden"] = hidden
	state["run"] = run
	return true


func _apply_narrative_debt(state: Dictionary, debt_type: String, description: String) -> bool:
	var run = state.get("run", {})
	var hidden = run.get("hidden", {})
	var debts = hidden.get("narrative_debt", [])

	var debt = {
		"type": debt_type,
		"description": description,
		"created_card": int(run.get("cards_played", 0)),
		"resolved": false,
	}
	debts.append(debt)

	hidden["narrative_debt"] = debts
	run["hidden"] = hidden
	state["run"] = run
	return true
