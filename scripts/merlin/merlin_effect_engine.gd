extends RefCounted
class_name MerlinEffectEngine

const VALID_CODES := {
	# ═══════════════════════════════════════════════════════════════════════════
	# TRIADE SYSTEM (v0.3.0)
	# ═══════════════════════════════════════════════════════════════════════════
	"USE_SOUFFLE": 1,      # USE_SOUFFLE:1
	"ADD_SOUFFLE": 1,      # ADD_SOUFFLE:2
	"PROGRESS_MISSION": 1, # PROGRESS_MISSION:1
	"ADD_KARMA": 1,        # ADD_KARMA:10 (hidden)
	"ADD_TENSION": 1,      # ADD_TENSION:15 (hidden)
	"ADD_NARRATIVE_DEBT": 2, # ADD_NARRATIVE_DEBT:trahison:La trahison reviendra
	"DAMAGE_LIFE": 1,      # DAMAGE_LIFE:2 (reduce life essence)
	"HEAL_LIFE": 1,        # HEAL_LIFE:1 (restore life essence)
	# ═══════════════════════════════════════════════════════════════════════════
	# GAUGES (used by LLM adapter pipeline)
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_GAUGE": 2,        # ADD_GAUGE:Vigueur:10
	"REMOVE_GAUGE": 2,     # REMOVE_GAUGE:Esprit:15
	"SET_GAUGE": 2,        # SET_GAUGE:Faveur:50
	# ═══════════════════════════════════════════════════════════════════════════
	# FLAGS & NARRATIVE
	# ═══════════════════════════════════════════════════════════════════════════
	"SET_FLAG": 2,         # SET_FLAG:met_druide:true
	"ADD_TAG": 1,          # ADD_TAG:war_brewing
	"REMOVE_TAG": 1,       # REMOVE_TAG:peace
	"QUEUE_CARD": 1,       # QUEUE_CARD:card_finale
	"TRIGGER_ARC": 1,      # TRIGGER_ARC:druide_arc
	# ═══════════════════════════════════════════════════════════════════════════
	# PROMISE SYSTEM
	# ═══════════════════════════════════════════════════════════════════════════
	"CREATE_PROMISE": 3,   # CREATE_PROMISE:oath_001:5:description
	"FULFILL_PROMISE": 1,  # FULFILL_PROMISE:oath_001
	"BREAK_PROMISE": 1,    # BREAK_PROMISE:oath_001
	# ═══════════════════════════════════════════════════════════════════════════
	# BESTIOLE BOND
	# ═══════════════════════════════════════════════════════════════════════════
	"MODIFY_BOND": 1,      # MODIFY_BOND:5
	"SET_SKILL_COOLDOWN": 2,  # SET_SKILL_COOLDOWN:beith:3
	# ═══════════════════════════════════════════════════════════════════════════
	# FACTION ALIGNMENT
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_REPUTATION": 2,   # ADD_REPUTATION:druides:15
	# ═══════════════════════════════════════════════════════════════════════════
	# ESSENCES — Monnaie principale inter-run
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_ESSENCES": 1,     # ADD_ESSENCES:5
	# ═══════════════════════════════════════════════════════════════════════════
	# ALIGNEMENT — Score continu Corps/Ame/Monde (-100 a +100)
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_ASPECT_ALIGNMENT": 2, # ADD_ASPECT_ALIGNMENT:Corps:25
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
		"DAMAGE_LIFE":
			return _apply_life_delta(state, -abs(_to_int(args[0])))
		"HEAL_LIFE":
			return _apply_life_delta(state, abs(_to_int(args[0])))
		# ═══════════════════════════════════════════════════════════════════════
		# GAUGES
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
		# FACTION ALIGNMENT
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_REPUTATION":
			return _apply_faction_reputation(state, args[0], _to_int(args[1]))
		# ═══════════════════════════════════════════════════════════════════════
		# ESSENCES
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_ESSENCES":
			return _apply_add_essences(state, _to_int(args[0]))
		# ═══════════════════════════════════════════════════════════════════════
		# ALIGNEMENT ASPECTS
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_ASPECT_ALIGNMENT":
			return _apply_add_aspect_alignment(state, args[0], _to_int(args[1]))
		_:
			return false


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

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
# GAUGE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_gauge_delta(state: Dictionary, gauge: String, delta: int) -> bool:
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})
	var current = int(gauges.get(gauge, 50))
	gauges[gauge] = clampi(current + delta, 0, 100)
	run["gauges"] = gauges
	state["run"] = run
	return true


func _apply_gauge_set(state: Dictionary, gauge: String, value: int) -> bool:
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})
	gauges[gauge] = clampi(value, 0, 100)
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

func _apply_use_souffle(state: Dictionary, amount: int) -> bool:
	var run = state.get("run", {})
	var current = int(run.get("souffle", MerlinConstants.SOUFFLE_START))
	run["souffle"] = maxi(current - amount, 0)
	state["run"] = run
	return true


func _apply_add_souffle(state: Dictionary, amount: int) -> bool:
	var run = state.get("run", {})
	var current = int(run.get("souffle", MerlinConstants.SOUFFLE_START))
	run["souffle"] = mini(current + amount, MerlinConstants.SOUFFLE_MAX)
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


func _apply_life_delta(state: Dictionary, delta: int) -> bool:
	var run = state.get("run", {})
	var current = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	run["life_essence"] = clampi(current + delta, 0, MerlinConstants.LIFE_ESSENCE_MAX)
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


# ═══════════════════════════════════════════════════════════════════════════════
# FACTION ALIGNMENT HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _score_to_tier(score: int) -> String:
	if score >= 60:
		return "honore"
	elif score >= 20:
		return "sympathisant"
	elif score >= -19:
		return "neutre"
	elif score >= -59:
		return "mefiant"
	else:
		return "hostile"


func _build_faction_context(rep_dict: Dictionary) -> Dictionary:
	var tiers: Dictionary = {}
	var active_effects: Array = []
	var dominant: String = ""
	var dominant_score: int = 0
	for faction in MerlinConstants.FACTIONS:
		var score: int = int(rep_dict.get(faction, 0))
		var tier: String = _score_to_tier(score)
		tiers[faction] = tier
		if tier != "neutre":
			active_effects.append({"faction": faction, "tier": tier, "score": score})
		if abs(score) > abs(dominant_score):
			dominant = faction
			dominant_score = score
	return {
		"dominant": dominant,
		"tiers": tiers,
		"active_effects": active_effects,
	}


func _apply_faction_reputation(state: Dictionary, faction: String, delta: int) -> bool:
	if not MerlinConstants.FACTIONS.has(faction):
		return false
	var run: Dictionary = state.get("run", {})
	var typology: String = str(run.get("typology", "classique"))
	if typology == "diplomate":
		var mult: float = float(MerlinConstants.RUN_TYPOLOGIES.get("diplomate", {}).get("faction_delta_mult", 1.0))
		delta = int(float(delta) * mult)
	var meta: Dictionary = state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var current: int = int(faction_rep.get(faction, MerlinConstants.FACTION_SCORE_START))
	var new_score: int = clampi(current + delta, MerlinConstants.FACTION_SCORE_MIN, MerlinConstants.FACTION_SCORE_MAX)
	faction_rep[faction] = new_score
	meta["faction_rep"] = faction_rep
	state["meta"] = meta
	if not run.is_empty():
		run["faction_context"] = _build_faction_context(faction_rep)
		state["run"] = run
	return true


func _apply_add_essences(state: Dictionary, amount: int) -> bool:
	if amount == 0:
		return false
	var run: Dictionary = state.get("run", {})
	var run_essences: int = int(run.get("essences", 0))
	run["essences"] = run_essences + amount
	state["run"] = run
	var meta: Dictionary = state.get("meta", {})
	var meta_essences: int = int(meta.get("essences", 0))
	meta["essences"] = meta_essences + amount
	state["meta"] = meta
	return true


func _apply_add_aspect_alignment(state: Dictionary, aspect: String, delta: int) -> bool:
	if not ["Corps", "Ame", "Monde"].has(aspect):
		return false
	var meta: Dictionary = state.get("meta", {})
	var alignment: Dictionary = meta.get("aspects_alignment", {"Corps": 0, "Ame": 0, "Monde": 0})
	var current: int = int(alignment.get(aspect, 0))
	var new_score: int = clampi(current + delta, MerlinConstants.ASPECT_MIN, MerlinConstants.ASPECT_MAX)
	alignment[aspect] = new_score
	meta["aspects_alignment"] = alignment
	state["meta"] = meta
	return true
