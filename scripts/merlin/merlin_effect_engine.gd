extends RefCounted
class_name MerlinEffectEngine

const VALID_CODES := {
	# ═══════════════════════════════════════════════════════════════════════════
	# MISSION & NARRATIVE
	# ═══════════════════════════════════════════════════════════════════════════
	"PROGRESS_MISSION": 1, # PROGRESS_MISSION:1
	"ADD_KARMA": 1,        # ADD_KARMA:10 (hidden)
	"ADD_TENSION": 1,      # ADD_TENSION:15 (hidden)
	"ADD_NARRATIVE_DEBT": 2, # ADD_NARRATIVE_DEBT:trahison:La trahison reviendra
	"DAMAGE_LIFE": 1,      # DAMAGE_LIFE:2 (reduce life essence)
	"HEAL_LIFE": 1,        # HEAL_LIFE:1 (restore life essence)
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
	"ADD_PROMISE": 2,      # ADD_PROMISE:promise_id:deadline_cards (lightweight, cap 2 active)
	"CREATE_PROMISE": 3,   # CREATE_PROMISE:oath_001:5:description
	"FULFILL_PROMISE": 1,  # FULFILL_PROMISE:oath_001
	"BREAK_PROMISE": 1,    # BREAK_PROMISE:oath_001
	# ═══════════════════════════════════════════════════════════════════════════
	# FACTION ALIGNMENT
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_REPUTATION": 2,   # ADD_REPUTATION:druides:15
	# ═══════════════════════════════════════════════════════════════════════════
	# ANAM & BIOME CURRENCY
	# ═══════════════════════════════════════════════════════════════════════════
	"ADD_ANAM": 1,         # ADD_ANAM:5
	"ADD_BIOME_CURRENCY": 1, # ADD_BIOME_CURRENCY:10
	# ═══════════════════════════════════════════════════════════════════════════
	# OGHAMS
	# ═══════════════════════════════════════════════════════════════════════════
	"UNLOCK_OGHAM": 1,     # UNLOCK_OGHAM:beith
	"OFFERING": 3,         # OFFERING:cost:reward_type:reward_value (biome currency trade)
	# ═══════════════════════════════════════════════════════════════════════════
	# UI / AUDIO (fire-and-forget, applied by controller)
	# ═══════════════════════════════════════════════════════════════════════════
	"PLAY_SFX": 1,         # PLAY_SFX:heal_chime
	"SHOW_DIALOG": 1,      # SHOW_DIALOG:merlin_warns
	"TRIGGER_EVENT": 1,    # TRIGGER_EVENT:merchant_appears
}

# Negative effect codes (used by ogham protection filtering)
const NEGATIVE_EFFECT_CODES: Array[String] = ["DAMAGE_LIFE"]


func validate_effect(effect_code: String) -> bool:
	var parsed = _parse_effect(effect_code)
	return parsed["ok"]


# ═══════════════════════════════════════════════════════════════════════════════
# 12-STEP CARD PIPELINE — Bible v2.4, section 13.3
# ═══════════════════════════════════════════════════════════════════════════════

## Orchestrates the full 12-step card resolution pipeline.
## Returns a result dict with all steps, applied effects, and end-of-card status.
## Steps: 1.DRAIN → 2.CARD → 3.OGHAM? → 4.CHOICE → 5.MINIGAME → 6.SCORE →
##         7.EFFECTS → 8.PROTECTION → 9.DEATH? → 10.PROMISES → 11.COOLDOWN → 12.RETURN
##
## Caller is responsible for steps 2 (display), 4 (player choice), 5 (minigame UI), 12 (3D return).
## This function handles: 1, 3, 6, 7, 8, 9, 10, 11.
func process_card(state: Dictionary, card: Dictionary, chosen_option: int,
		minigame_score: int, active_ogham: String = "") -> Dictionary:
	minigame_score = clampi(minigame_score, 0, 100)
	var run: Dictionary = state.get("run", {})
	var result: Dictionary = {
		"steps_completed": [],
		"effects_applied": [],
		"effects_rejected": [],
		"ogham_result": {},
		"multiplier": 1.0,
		"multiplier_label": "reussite",
		"life_before": int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)),
		"life_after": 0,
		"is_dead": false,
		"promises_expired": [],
	}

	# ── Step 1: DRAIN -1 PV ──
	_apply_life_delta(state, -MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD)
	result["steps_completed"].append("drain")

	# ── Step 3: OGHAM activation (before choice — already resolved by caller,
	#            but we apply state effects here if ogham is active) ──
	if not active_ogham.is_empty():
		result["ogham_result"] = activate_ogham(active_ogham, state, card)
		result["steps_completed"].append("ogham")

	# ── Step 6: SCORE → multiplier ──
	var is_merlin_direct: bool = str(card.get("type", "")).to_lower() == "merlin_direct"
	var multiplier: float = 1.0
	if not is_merlin_direct:
		multiplier = get_multiplier(minigame_score)
	result["multiplier"] = multiplier
	result["multiplier_label"] = get_multiplier_label(minigame_score) if not is_merlin_direct else "merlin_direct"
	result["steps_completed"].append("score")

	# ── Step 7: APPLY EFFECTS (option effects × multiplier) ──
	var options: Array = card.get("options", [])
	if chosen_option >= 0 and chosen_option < options.size():
		var option: Dictionary = options[chosen_option]
		var raw_effects: Array = option.get("effects", [])
		var scaled_effects: Array = []
		for effect_str in raw_effects:
			if typeof(effect_str) != TYPE_STRING:
				continue
			var parsed: Dictionary = _parse_effect(effect_str)
			if not parsed["ok"]:
				result["effects_rejected"].append(effect_str)
				continue
			# Scale numeric effects by multiplier
			var code: String = parsed["code"]
			if code == "ADD_REPUTATION":
				# ADD_REPUTATION:faction:amount — scale args[1] (amount), not args[0] (faction name)
				var raw_amount: int = _to_int(parsed["args"][1])
				var scaled_amount: int = scale_and_cap(code, raw_amount, multiplier)
				parsed["args"][1] = str(scaled_amount)
			elif code in ["DAMAGE_LIFE", "HEAL_LIFE", "ADD_BIOME_CURRENCY", "ADD_ANAM", "ADD_KARMA", "ADD_TENSION"]:
				var raw_amount: int = _to_int(parsed["args"][0])
				var scaled_amount: int = scale_and_cap(code, raw_amount, multiplier)
				parsed["args"][0] = str(scaled_amount)
			# Apply double_positives flag from ogham (tinne)
			var ogham_flags: Dictionary = result["ogham_result"]
			if ogham_flags.get("flag", "") == "double_positives":
				if code in ["HEAL_LIFE", "ADD_BIOME_CURRENCY", "ADD_ANAM"] or (code == "ADD_REPUTATION" and _to_int(parsed["args"][-1]) > 0):
					var current_val: int = _to_int(parsed["args"][0] if code != "ADD_REPUTATION" else parsed["args"][1])
					var doubled: int = current_val * 2
					if code == "ADD_REPUTATION":
						parsed["args"][1] = str(doubled)
					else:
						parsed["args"][0] = str(doubled)
			# Apply invert_effects flag from ogham (muin) — swap codes
			if ogham_flags.get("flag", "") == "invert_effects":
				if code == "DAMAGE_LIFE":
					parsed["code"] = "HEAL_LIFE"
				elif code == "HEAL_LIFE":
					parsed["code"] = "DAMAGE_LIFE"
			scaled_effects.append(parsed)
		# ── Step 8: OGHAM PROTECTION (luis/gort/eadhadh filter) ──
		# Filter effects through protection ogham BEFORE applying to state.
		if not active_ogham.is_empty() and result["ogham_result"].get("action", "") == "protection_active":
			scaled_effects = _filter_protection(scaled_effects, active_ogham)

		# Build effect strings and apply
		for parsed_eff in scaled_effects:
			var parts: Array = [parsed_eff["code"]]
			parts.append_array(parsed_eff["args"])
			var effect_str: String = ":".join(parts)
			var apply_result: Dictionary = apply_effects(state, [effect_str], "card")
			result["effects_applied"].append_array(apply_result.get("applied", []))
			result["effects_rejected"].append_array(apply_result.get("rejected", []))
	result["steps_completed"].append("protection")
	result["steps_completed"].append("effects")

	# ── Step 9: DEATH CHECK (AFTER effects) ──
	run = state.get("run", {})
	var life_after: int = int(run.get("life_essence", 0))
	result["life_after"] = life_after
	result["is_dead"] = life_after <= 0
	result["steps_completed"].append("death_check")

	# ── Step 10: PROMISES — countdown and expiration ──
	var promises: Array = run.get("promises", [])
	var cards_played: int = int(run.get("cards_played", 0)) + 1
	run["cards_played"] = cards_played
	for i in range(promises.size()):
		var p: Dictionary = promises[i]
		if str(p.get("status", "")) != "active":
			continue
		var made_at: int = int(p.get("made_at_card", 0))
		var deadline: int = int(p.get("deadline_cards", 0))
		if cards_played - made_at >= deadline:
			promises[i] = p.duplicate()
			promises[i]["status"] = "expired"
			result["promises_expired"].append(str(p.get("id", "")))
	run["promises"] = promises
	state["run"] = run
	result["steps_completed"].append("promises")

	# ── Step 11: COOLDOWN — decrement ogham cooldowns ──
	var cooldowns: Dictionary = run.get("cooldowns", {})
	var cd_keys: Array = cooldowns.keys().duplicate()
	for key in cd_keys:
		var remaining: int = int(cooldowns[key]) - 1
		if remaining <= 0:
			cooldowns.erase(key)
		else:
			cooldowns[key] = remaining
	run["cooldowns"] = cooldowns
	state["run"] = run
	result["steps_completed"].append("cooldown")

	return result


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
		# MISSION & NARRATIVE
		# ═══════════════════════════════════════════════════════════════════════
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
		"ADD_PROMISE":
			return _add_promise(state, args[0], _to_int(args[1]))
		"CREATE_PROMISE":
			return _create_promise(state, args[0], _to_int(args[1]), args[2])
		"FULFILL_PROMISE":
			return _fulfill_promise(state, args[0])
		"BREAK_PROMISE":
			return _break_promise(state, args[0])
		# ═══════════════════════════════════════════════════════════════════════
		# FACTION ALIGNMENT
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_REPUTATION":
			return _apply_faction_reputation(state, args[0], _to_int(args[1]))
		# ═══════════════════════════════════════════════════════════════════════
		# ANAM
		# ═══════════════════════════════════════════════════════════════════════
		"ADD_ANAM":
			return _apply_add_anam(state, _to_int(args[0]))
		# ═══════════════════════════════════════════════════════════════════════
		# OGHAMS
		# ═══════════════════════════════════════════════════════════════════════
		"UNLOCK_OGHAM":
			return _apply_unlock_ogham(state, args[0])
		"ADD_BIOME_CURRENCY":
			return _apply_biome_currency(state, _to_int(args[0]))
		"OFFERING":
			return _apply_offering(state, _to_int(args[0]), args[1], args[2])
		"PLAY_SFX", "SHOW_DIALOG", "TRIGGER_EVENT":
			# Fire-and-forget: recorded in effect_log, handled by controller
			return true
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


static func _to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return int(str(value))


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

func _add_promise(state: Dictionary, promise_id: String, deadline_cards: int) -> bool:
	if promise_id.is_empty():
		push_warning("[EffectEngine] _add_promise: empty promise_id")
		return false
	var run: Dictionary = state.get("run", {})
	var promises: Array = run.get("promises", [])
	# Cap: max 2 active promises (bible rule)
	var active_count: int = 0
	for p in promises:
		if str(p.get("status", "")) == "active":
			active_count += 1
	if active_count >= 2:
		return false
	var cards_played: int = int(run.get("cards_played", 0))
	var promise: Dictionary = {
		"id": promise_id,
		"deadline_cards": deadline_cards,
		"made_at_card": cards_played,
		"status": "active",
	}
	promises.append(promise)
	run["promises"] = promises
	state["run"] = run
	return true


func _create_promise(state: Dictionary, promise_id: String, deadline_days: int, description: String) -> bool:
	if promise_id.is_empty():
		push_warning("[EffectEngine] _create_promise: empty promise_id")
		return false
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
# MISSION & NARRATIVE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

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
	elif key == "karma":
		hidden[key] = clampi(current + delta, -100, 100)
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
	if score >= 80:
		return "honore"
	elif score >= 50:
		return "sympathisant"
	elif score >= 20:
		return "neutre"
	elif score >= 5:
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
		if score > dominant_score:
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
	# Enforce per-card cap (bible v2.4: ±20 per faction per card)
	var capped_delta: int = clampi(delta, -20, 20)
	var meta: Dictionary = state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var current: int = int(faction_rep.get(faction, MerlinConstants.FACTION_SCORE_START))
	var new_score: int = clampi(current + capped_delta, MerlinConstants.FACTION_SCORE_MIN, MerlinConstants.FACTION_SCORE_MAX)
	faction_rep[faction] = new_score
	meta["faction_rep"] = faction_rep
	state["meta"] = meta
	var run: Dictionary = state.get("run", {})
	if not run.is_empty():
		run["faction_context"] = _build_faction_context(faction_rep)
		state["run"] = run
	return true


func _apply_add_anam(state: Dictionary, amount: int) -> bool:
	if amount == 0:
		return false
	var run: Dictionary = state.get("run", {})
	var run_anam: int = int(run.get("anam", 0))
	run["anam"] = maxi(run_anam + amount, 0)
	state["run"] = run
	var meta: Dictionary = state.get("meta", {})
	var meta_anam: int = int(meta.get("anam", 0))
	meta["anam"] = maxi(meta_anam + amount, 0)
	state["meta"] = meta
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_unlock_ogham(state: Dictionary, ogham_name: String) -> bool:
	if not MerlinConstants.OGHAM_FULL_SPECS.has(ogham_name):
		return false
	var run: Dictionary = state.get("run", {})
	var unlocked: Array = run.get("unlocked_oghams", [])
	if not unlocked.has(ogham_name):
		unlocked.append(ogham_name)
	run["unlocked_oghams"] = unlocked
	state["run"] = run
	return true


func _apply_biome_currency(state: Dictionary, amount: int) -> bool:
	var run: Dictionary = state.get("run", {})
	var current: int = int(run.get("biome_currency", 0))
	run["biome_currency"] = maxi(current + amount, 0)
	state["run"] = run
	return true


func _apply_offering(state: Dictionary, cost: int, reward_type: String, reward_value: String) -> bool:
	var run: Dictionary = state.get("run", {})
	var current_currency: int = int(run.get("biome_currency", 0))
	if current_currency < cost:
		push_warning("OFFERING rejected: need %d biome currency, have %d" % [cost, current_currency])
		return false
	# Deduct biome currency
	run["biome_currency"] = current_currency - cost
	state["run"] = run
	# Build and apply the reward effect
	var reward_code: String = "%s:%s" % [reward_type, reward_value]
	var parsed: Dictionary = _parse_effect(reward_code)
	if not parsed["ok"]:
		push_warning("OFFERING reward invalid: %s — %s" % [reward_code, parsed.get("error", "")])
		return false
	return _apply_parsed(state, parsed)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER TABLE — Score → factor (bible v2.4 s.6.5)
# ═══════════════════════════════════════════════════════════════════════════════

static func get_multiplier(score: int) -> float:
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		if score >= int(entry["range_min"]) and score <= int(entry["range_max"]):
			return float(entry["factor"])
	return 1.0


static func get_multiplier_label(score: int) -> String:
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		if score >= int(entry["range_min"]) and score <= int(entry["range_max"]):
			return str(entry["label"])
	return "reussite"


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT CAPPING — Enforce bible v2.4 caps on effect amounts
# ═══════════════════════════════════════════════════════════════════════════════

static func cap_effect(effect_code: String, amount: int) -> int:
	var caps: Dictionary = MerlinConstants.EFFECT_CAPS
	match effect_code:
		"ADD_REPUTATION":
			var cap_data: Dictionary = caps.get("ADD_REPUTATION", {})
			return clampi(amount, int(cap_data.get("min", -20)), int(cap_data.get("max", 20)))
		"HEAL_LIFE":
			return mini(amount, int(caps.get("HEAL_LIFE", {}).get("max", 18)))
		"DAMAGE_LIFE":
			return mini(amount, int(caps.get("DAMAGE_LIFE", {}).get("max", 15)))
		"ADD_BIOME_CURRENCY":
			return mini(amount, int(caps.get("ADD_BIOME_CURRENCY", {}).get("max", 10)))
	return amount


## Apply multiplier to a raw effect amount, then cap it.
static func scale_and_cap(effect_code: String, raw_amount: int, multiplier: float) -> int:
	var scaled: int = int(float(raw_amount) * absf(multiplier))
	if multiplier < 0:
		scaled = -scaled
	return cap_effect(effect_code, scaled)


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM PROTECTION — Step 8 filter (luis → gort → eadhadh)
# ═══════════════════════════════════════════════════════════════════════════════

## Filters applied effects through active ogham protections.
## Returns the filtered effects array (new array, does not mutate input).
## active_ogham: the currently active ogham key (e.g. "luis")
## applied_effects: array of {"code": String, "amount": int, ...} dicts
## NOTE: This method works on structured effect dicts and is used by run_3d_controller.gd.
## For the process_card() pipeline (step 8), see _filter_protection() below which
## operates on the parsed {"code", "args"} format instead.
static func apply_ogham_protection(applied_effects: Array, active_ogham: String) -> Array:
	if active_ogham.is_empty():
		return applied_effects.duplicate()
	var ogham_spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(active_ogham, {})
	var effect_name: String = str(ogham_spec.get("effect", ""))
	var result: Array = applied_effects.duplicate(true)

	match effect_name:
		"block_first_negative":
			# luis: remove the first negative effect
			for i in range(result.size()):
				if _is_negative_effect(result[i]):
					result.remove_at(i)
					break
		"reduce_high_damage":
			# gort: reduce any DAMAGE_LIFE > threshold to reduced_to
			var params: Dictionary = ogham_spec.get("effect_params", {})
			var threshold: int = int(params.get("threshold", 10))
			var reduced_to: int = int(params.get("reduced_to", 5))
			for i in range(result.size()):
				var eff: Dictionary = result[i]
				if str(eff.get("code", "")) == "DAMAGE_LIFE" and int(eff.get("amount", 0)) > threshold:
					var updated: Dictionary = eff.duplicate()
					updated["amount"] = reduced_to
					result[i] = updated
					break  # 1 instance only
		"cancel_all_negatives":
			# eadhadh: remove ALL negative effects
			var filtered: Array = []
			for eff in result:
				if not _is_negative_effect(eff):
					filtered.append(eff)
			result = filtered

	return result


static func _is_negative_effect(effect: Dictionary) -> bool:
	var code: String = str(effect.get("code", ""))
	if code == "DAMAGE_LIFE":
		return true
	if code == "ADD_REPUTATION" and int(effect.get("amount", 0)) < 0:
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# PROTECTION FILTER — Operates on parsed effect dicts in process_card step 8
# ═══════════════════════════════════════════════════════════════════════════════

## Filters parsed effects (from process_card step 7) through protection ogham.
## Unlike apply_ogham_protection() which works on structured dicts, this works
## on the parsed format {"code": String, "args": Array} used by process_card.
static func _filter_protection(scaled_effects: Array, active_ogham: String) -> Array:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(active_ogham, {})
	var effect_name: String = str(spec.get("effect", ""))

	match effect_name:
		"block_first_negative":
			# luis: remove the first negative effect
			for i in range(scaled_effects.size()):
				if _is_negative_parsed(scaled_effects[i]):
					var filtered: Array = scaled_effects.duplicate()
					filtered.remove_at(i)
					return filtered
		"reduce_high_damage":
			# gort: reduce DAMAGE_LIFE > threshold to reduced_to
			var params: Dictionary = spec.get("effect_params", {})
			var threshold: int = int(params.get("threshold", 10))
			var reduced_to: int = int(params.get("reduced_to", 5))
			var result: Array = []
			var applied: bool = false
			for parsed_eff in scaled_effects:
				if not applied and parsed_eff["code"] == "DAMAGE_LIFE":
					var dmg: int = abs(_to_int(parsed_eff["args"][0]))
					if dmg > threshold:
						var modified: Dictionary = parsed_eff.duplicate(true)
						modified["args"][0] = str(reduced_to)
						result.append(modified)
						applied = true
						continue
				result.append(parsed_eff)
			return result
		"cancel_all_negatives":
			# eadhadh: remove ALL negative effects
			var result: Array = []
			for parsed_eff in scaled_effects:
				if not _is_negative_parsed(parsed_eff):
					result.append(parsed_eff)
			return result

	return scaled_effects.duplicate()


## Check if a parsed effect {"code": ..., "args": [...]} is negative.
## Aligned with _is_negative_effect() — only visible effects (life, reputation).
static func _is_negative_parsed(parsed: Dictionary) -> bool:
	var code: String = str(parsed.get("code", ""))
	if code == "DAMAGE_LIFE":
		return true
	if code == "ADD_REPUTATION" and parsed.get("args", []).size() >= 2:
		return _to_int(parsed["args"][1]) < 0
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM ACTIVATION — Step 3 dispatcher (before choice)
# Returns a result dict with what happened
# ═══════════════════════════════════════════════════════════════════════════════

func activate_ogham(ogham_key: String, state: Dictionary, card: Dictionary) -> Dictionary:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_key, {})
	if spec.is_empty():
		return {"ok": false, "reason": "unknown_ogham"}
	var effect_name: String = str(spec.get("effect", ""))
	var params: Dictionary = spec.get("effect_params", {})
	var result: Dictionary = {"ok": true, "ogham": ogham_key, "effect": effect_name}

	match effect_name:
		# ── REVEAL (step 3, before choice) ──
		"reveal_one_option":
			result["action"] = "reveal"
			result["reveal_count"] = 1
		"reveal_all_options":
			result["action"] = "reveal"
			result["reveal_count"] = 3
		"predict_next":
			result["action"] = "predict"

		# ── BOOST (step 3, immediate) ──
		"heal_immediate":
			var amount: int = int(params.get("amount", 0))
			amount = cap_effect("HEAL_LIFE", amount)
			_apply_life_delta(state, amount)
			result["action"] = "heal"
			result["healed"] = amount
		"double_positives":
			result["action"] = "flag"
			result["flag"] = "double_positives"
		"add_biome_currency":
			var amount: int = int(params.get("amount", 0))
			amount = cap_effect("ADD_BIOME_CURRENCY", amount)
			_apply_biome_currency(state, amount)
			result["action"] = "currency"
			result["amount"] = amount

		# ── NARRATIF (step 3, modifies card) ──
		"replace_worst_option":
			result["action"] = "replace_worst"
		"regenerate_all_options":
			result["action"] = "regenerate_all"
		"force_twist":
			result["action"] = "flag"
			result["flag"] = "twist_next_card"

		# ── RECOVERY (step 3, immediate) ──
		"heal_and_cost":
			var heal: int = cap_effect("HEAL_LIFE", int(params.get("heal", 0)))
			var cost: int = int(params.get("currency_cost", 0))
			_apply_life_delta(state, heal)
			_apply_biome_currency(state, -cost)
			result["action"] = "heal_and_cost"
			result["healed"] = heal
			result["currency_spent"] = cost
		"currency_and_heal":
			var currency: int = cap_effect("ADD_BIOME_CURRENCY", int(params.get("currency", 0)))
			var heal: int = int(params.get("heal", 0))
			_apply_biome_currency(state, currency)
			_apply_life_delta(state, heal)
			result["action"] = "currency_and_heal"
			result["currency_gained"] = currency
			result["healed"] = heal

		# ── SPECIAL ──
		"invert_effects":
			result["action"] = "flag"
			result["flag"] = "invert_effects"
		"full_reroll":
			result["action"] = "reroll_card"
		"sacrifice_trade":
			var life_cost: int = int(params.get("life_cost", 15))
			var currency_gain: int = int(params.get("currency_gain", 20))
			_apply_life_delta(state, -life_cost)
			_apply_biome_currency(state, currency_gain)
			result["action"] = "sacrifice"
			result["life_spent"] = life_cost
			result["currency_gained"] = currency_gain
			result["flag"] = "score_buff_1.3"

		# ── PROTECTION (handled in step 8, not step 3) ──
		"block_first_negative", "reduce_high_damage", "cancel_all_negatives":
			result["action"] = "protection_active"

		_:
			result["ok"] = false
			result["reason"] = "unhandled_effect: %s" % effect_name

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# VERB DETECTION — Map narrative verb to champ lexical
# ═══════════════════════════════════════════════════════════════════════════════

static func detect_field_from_verb(verb: String) -> String:
	var lower_verb: String = verb.to_lower().strip_edges()
	for field in MerlinConstants.ACTION_VERBS:
		var verbs: Array = MerlinConstants.ACTION_VERBS[field]
		for v in verbs:
			if lower_verb.contains(str(v)):
				return field
	return MerlinConstants.ACTION_VERB_FALLBACK_FIELD


static func pick_minigame_for_field(field: String) -> String:
	var minigames: Array = MerlinConstants.FIELD_MINIGAMES.get(field, [])
	if minigames.is_empty():
		return "apaisement"  # safe fallback
	var mg_hash: int = field.hash() % minigames.size()
	if mg_hash < 0:
		mg_hash = -mg_hash % minigames.size()
	return str(minigames[mg_hash])
