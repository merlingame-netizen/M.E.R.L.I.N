extends RefCounted
class_name MerlinTestEngine
## Roll engine for the RPG test system (see docs/RPG_TEST_SYSTEM.md).
##
## Pure logic, no UI, no signals. Gives a deterministic-when-seeded resolution path
## for: stat + ogham_modifier + narrative_modifier + d10 vs DC.
##
## Usage:
##   var engine := MerlinTestEngine.new()
##   var outcome := engine.roll_test({
##       "axis": "esprit",
##       "stat": 6,
##       "dc": 11,
##       "ogham_modifier": 1,
##       "narrative_modifier": 0,
##   })
##   # outcome = {"result": "success", "roll": 14, "dc": 11, "delta": 3, "xp_gain": 10}


# RNG injection point so tests can seed reproducibly.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Roll a test. `params` keys:
##   - axis (String) : "souffle" | "esprit" | "coeur"
##   - stat (int) : 0..10
##   - dc (int) : 6..18
##   - ogham_modifier (int, default 0) : -1..+3
##   - narrative_modifier (int, default 0) : -4..+4 (capped)
##   - minigame_modifier (int, default 0) : -4..+2 (from minigame performance)
##   - force_min_failure (bool, default false) : minigame timeout/abort flag
##   - run_modifiers (Dictionary, optional) : Vampire-Survivors-style gift effects
##       reads stat_buffs[axis], crit_next_test, reroll_charges, narrative_modifier.
##       MUTATED in-place (consumes one-shots like crit_next_test, reroll_charges).
## Returns:
##   - result : "critical_failure" | "failure" | "success" | "critical"
##   - roll, dc, delta, components (for logs/UI), xp_gain
##   - rerolled (bool) — set when reroll_charges salvaged a failure
func roll_test(params: Dictionary) -> Dictionary:
	var axis: String = String(params.get("axis", "esprit"))
	var stat: int = clampi(int(params.get("stat", MerlinConstants.STAT_DEFAULT)), MerlinConstants.STAT_MIN, MerlinConstants.STAT_MAX)
	var dc: int = clampi(int(params.get("dc", MerlinConstants.DC_DEFAULT)), MerlinConstants.DC_MIN, MerlinConstants.DC_MAX)
	var ogham_modifier: int = clampi(int(params.get("ogham_modifier", 0)), -1, 3)
	var narrative_modifier: int = clampi(int(params.get("narrative_modifier", 0)), -4, 4)
	var minigame_modifier: int = clampi(int(params.get("minigame_modifier", 0)), -4, 2)
	var force_min_failure: bool = bool(params.get("force_min_failure", false))
	var run_mods: Dictionary = params.get("run_modifiers", {}) as Dictionary

	# C23 — Apply gift-side stat buffs (compound stat_buffs[axis]) and the
	# narrative_modifier compound (cumulative across gifts taken).
	if not run_mods.is_empty():
		var stat_buffs: Dictionary = run_mods.get("stat_buffs", {}) as Dictionary
		var axis_buff: int = int(stat_buffs.get(axis, 0))
		stat = clampi(stat + axis_buff, MerlinConstants.STAT_MIN, MerlinConstants.STAT_MAX + 4)
		var nm_compound: int = int(run_mods.get("narrative_modifier", 0))
		narrative_modifier = clampi(narrative_modifier + nm_compound, -4, 4)

	var d10: int = _rng.randi_range(1, 10)
	var roll: int = stat + ogham_modifier + narrative_modifier + minigame_modifier + d10
	var delta: int = roll - dc
	var result_tier: int = _classify_result(delta)
	var rerolled: bool = false

	# C23 — Reroll: if the first roll lands on FAILURE or CRITICAL_FAILURE and
	# the player has a reroll charge, consume one and re-roll the d10 once.
	if not run_mods.is_empty() and result_tier <= MerlinConstants.TestResult.FAILURE:
		var charges: int = int(run_mods.get("reroll_charges", 0))
		if charges > 0:
			run_mods["reroll_charges"] = charges - 1
			d10 = _rng.randi_range(1, 10)
			roll = stat + ogham_modifier + narrative_modifier + minigame_modifier + d10
			delta = roll - dc
			result_tier = _classify_result(delta)
			rerolled = true

	# Minigame timeout / abort floors at FAILURE (cannot be SUCCESS or CRITICAL).
	if force_min_failure and result_tier > MerlinConstants.TestResult.FAILURE:
		result_tier = MerlinConstants.TestResult.FAILURE

	# C23 — crit_next_test (one-shot from gift) bumps tier up by one and consumes the flag.
	if not run_mods.is_empty() and bool(run_mods.get("crit_next_test", false)):
		if result_tier < MerlinConstants.TestResult.CRITICAL:
			result_tier += 1
		run_mods["crit_next_test"] = false

	var result_key: String = MerlinConstants.TEST_RESULT_KEYS[result_tier]
	# C23 — xp_multiplier from gifts (memoire_chaude=1.25, graines_de_serment=1.5, …).
	var xp_base: int = _xp_for_tier(result_tier)
	var xp_multiplier: float = float(run_mods.get("xp_multiplier", 1.0)) if not run_mods.is_empty() else 1.0
	var xp_gain: int = int(round(float(xp_base) * xp_multiplier))
	return {
		"axis": axis,
		"result": result_key,
		"result_tier": result_tier,
		"roll": roll,
		"dc": dc,
		"delta": delta,
		"d10": d10,
		"rerolled": rerolled,
		"components": {
			"stat": stat,
			"ogham": ogham_modifier,
			"narrative": narrative_modifier,
			"minigame": minigame_modifier,
		},
		"xp_gain": xp_gain,
	}


## Apply a roll outcome to the store's player state. Mutates state.player.
## Returns dict with side-effect summary: {axis_xp_added, stat_levelups, traits_unlocked}
func apply_outcome_to_state(state: Dictionary, outcome: Dictionary) -> Dictionary:
	var axis: String = String(outcome.get("axis", "esprit"))
	var xp_gain: int = int(outcome.get("xp_gain", 0))
	var summary: Dictionary = {"axis_xp_added": xp_gain, "stat_levelups": [], "traits_unlocked": []}
	if not state.has("player"):
		return summary
	var player: Dictionary = state["player"] as Dictionary
	# XP cumulation
	var xp_dict: Dictionary = player.get("xp", {}) as Dictionary
	var prev_xp: int = int(xp_dict.get(axis, 0))
	var new_xp: int = prev_xp + xp_gain
	xp_dict[axis] = new_xp
	player["xp"] = xp_dict
	# Stat level-ups (each XP_PER_STAT_LEVEL milestone crossed = +1 stat, capped)
	var stats_dict: Dictionary = player.get("stats", {}) as Dictionary
	var prev_level: int = prev_xp / MerlinConstants.XP_PER_STAT_LEVEL
	var new_level: int = new_xp / MerlinConstants.XP_PER_STAT_LEVEL
	if new_level > prev_level:
		var current_stat: int = int(stats_dict.get(axis, MerlinConstants.STAT_DEFAULT))
		var gained: int = new_level - prev_level
		var new_stat: int = mini(current_stat + gained, MerlinConstants.STAT_MAX)
		stats_dict[axis] = new_stat
		player["stats"] = stats_dict
		summary["stat_levelups"].append({"axis": axis, "from": current_stat, "to": new_stat})
	# Memory log roll (5 most recent test outcomes for LLM context)
	var mem: Array = player.get("memory_log", []) as Array
	mem.append({
		"axis": axis,
		"result": String(outcome.get("result", "")),
		"dc": int(outcome.get("dc", 0)),
		"roll": int(outcome.get("roll", 0)),
	})
	while mem.size() > 5:
		mem.pop_front()
	player["memory_log"] = mem
	return summary


## Compute narrative_modifier from store state for a given axis.
##   - faction rep >= 50 → +1, >= 80 → +2 (only on the matching faction; here generic +1 if any rep is high)
##   - faction rep <= 0 → -1
##   - life < 30% → -1 (panic)
## Capped to [-4..+4].
func compute_narrative_modifier(state: Dictionary, _axis: String) -> int:
	var modifier: int = 0
	var run: Dictionary = state.get("run", {}) as Dictionary
	var life: int = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	var max_life: int = int(MerlinConstants.LIFE_ESSENCE_MAX) if MerlinConstants.get("LIFE_ESSENCE_MAX") != null else 100
	if max_life > 0 and float(life) / float(max_life) < 0.30:
		modifier -= 1
	var meta: Dictionary = state.get("meta", {}) as Dictionary
	var rep: Dictionary = meta.get("faction_rep", {}) as Dictionary
	var max_rep: float = 0.0
	var min_rep: float = 0.0
	for f in rep:
		var v: float = float(rep[f])
		if v > max_rep: max_rep = v
		if v < min_rep: min_rep = v
	if max_rep >= 80:
		modifier += 2
	elif max_rep >= 50:
		modifier += 1
	if min_rep <= -50:
		modifier -= 1
	return clampi(modifier, -4, 4)


# ─────────────────────────────────────────────────────────────────────────────
# Internals
# ─────────────────────────────────────────────────────────────────────────────

func _classify_result(delta: int) -> int:
	if delta >= 5:
		return MerlinConstants.TestResult.CRITICAL
	if delta >= 0:
		return MerlinConstants.TestResult.SUCCESS
	if delta >= -4:
		return MerlinConstants.TestResult.FAILURE
	return MerlinConstants.TestResult.CRITICAL_FAILURE


## Compute the scaled DC for a given card index (1-5 typically).
## Returns a DC clamped to [DC_MIN..DC_MAX]. See docs/BALANCE_FORMULA.md.
##   DC(card_index) = 8 + (card_index * 1.2)
##   Card 1: DC 9, Card 2: 10, Card 3: 11, Card 4: 12, Card 5: 13.
static func scaled_dc(card_index: int, base_override: int = -1) -> int:
	if base_override > 0:
		return clampi(base_override, MerlinConstants.DC_MIN, MerlinConstants.DC_MAX)
	var dc: int = int(round(8.0 + float(card_index) * 1.2))
	return clampi(dc, MerlinConstants.DC_MIN, MerlinConstants.DC_MAX)


## Format the rolling memory_log into a Merlin-voice context block injectable in
## any LLM user prompt. Empty string if no memory.
##   Output example:
##     "Le voyageur se souvient: il a dechiffre une pierre (esprit, succes critique),
##      croise un loup (coeur, succes), trebuche au seuil (souffle, echec)."
static func format_memory_log_for_llm(state: Dictionary) -> String:
	var player: Dictionary = state.get("player", {}) as Dictionary
	var mem: Array = player.get("memory_log", []) as Array
	if mem.is_empty():
		return ""
	var fragments: Array[String] = []
	for entry in mem:
		var d: Dictionary = entry as Dictionary
		var axis: String = String(d.get("axis", ""))
		var result: String = String(d.get("result", ""))
		var verb: String = ""
		match result:
			"critical":         verb = "succes eclatant"
			"success":          verb = "succes"
			"failure":          verb = "echec"
			"critical_failure": verb = "echec catastrophique"
			_:                  verb = result
		fragments.append("%s (%s)" % [verb, axis])
	return "Memoire du voyageur: " + ", ".join(fragments) + "."


func _xp_for_tier(tier: int) -> int:
	match tier:
		MerlinConstants.TestResult.CRITICAL:         return MerlinConstants.XP_CRITICAL
		MerlinConstants.TestResult.SUCCESS:          return MerlinConstants.XP_SUCCESS
		MerlinConstants.TestResult.FAILURE:          return MerlinConstants.XP_FAILURE
		MerlinConstants.TestResult.CRITICAL_FAILURE: return MerlinConstants.XP_CRITICAL_FAILURE
	return 0
