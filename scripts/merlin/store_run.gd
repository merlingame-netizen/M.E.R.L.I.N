## ═══════════════════════════════════════════════════════════════════════════════
## Store Run — Run lifecycle, choice resolution, mission, rewards
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_store.gd — pure delegation, no behavior changes.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name StoreRun


## Initialize a new run state.
static func init_run(state: Dictionary, rng: MerlinRng, scenarios: MerlinScenarioManager) -> void:
	var run: Dictionary = state.get("run", {})
	run["active"] = true
	run["life_essence"] = MerlinConstants.LIFE_ESSENCE_START
	run["anam"] = 0
	run["mission"] = generate_mission(rng)
	run["cards_played"] = 0
	run["day"] = 1
	run["story_log"] = []
	run["active_tags"] = []
	run["active_promises"] = []
	run["current_biome"] = ""
	run["biome_passive_counter"] = 0
	run["hidden"] = {
		"karma": 0,
		"tension": 0,
		"player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0},
		"resonances_active": [],
		"narrative_debt": [],
	}
	run["power_bonuses"] = {}
	state["run"] = run

	# Faction alignment — context + bonuses (no decay per bible v2.4)
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)

	# Select scenario for this run (Hand of Fate 2-style quest)
	var biome_for_scenario: String = str(run.get("current_biome", ""))
	var selected_scenario: Dictionary = scenarios.select_scenario(biome_for_scenario, state.get("meta", {}))
	if not selected_scenario.is_empty():
		scenarios.start_scenario(selected_scenario)
		run["active_scenario"] = str(selected_scenario.get("id", ""))
		state["run"] = run
	else:
		run["active_scenario"] = ""
		state["run"] = run

	StoreTalents.apply_talent_effects_for_run(state)


## Initialize calendar context for a run (real date).
static func init_calendar_context(state: Dictionary, merlin: MerlinOmniscient) -> String:
	var today := Time.get_date_dict_from_system()
	var run: Dictionary = state.get("run", {})
	run["start_date"] = {"year": today.year, "month": today.month, "day": today.day}
	run["events_seen"] = []
	run["event_locks"] = []
	run["event_rerolls_used"] = 0

	var month: int = int(today.month)
	var season := "winter"
	if month >= 3 and month <= 5:
		season = "spring"
	elif month >= 6 and month <= 8:
		season = "summer"
	elif month >= 9 and month <= 11:
		season = "autumn"
	run["season"] = season

	state["run"] = run

	# Update EventAdapter calendar context if available
	if merlin and merlin.event_adapter:
		var days_table := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		var doy := 0
		for m in range(1, month):
			doy += days_table[m]
		doy += int(today.day)
		merlin.event_adapter.update_calendar_context(season, month, int(today.day), doy)

	return season


## Generate a mission from templates using weighted random pick.
static func generate_mission(rng: MerlinRng) -> Dictionary:
	var templates: Dictionary = MerlinConstants.MISSION_TEMPLATES
	var total_weight: float = 0.0
	for key in templates:
		total_weight += float(templates[key].get("weight", 1.0))
	var roll: float = rng.randf() * total_weight
	var picked_key: String = ""
	var cumul: float = 0.0
	for key in templates:
		cumul += float(templates[key].get("weight", 1.0))
		if roll <= cumul:
			picked_key = key
			break
	if picked_key.is_empty():
		picked_key = templates.keys()[0]
	var tmpl: Dictionary = templates[picked_key]
	var target_val: int = 10
	for key in tmpl:
		if str(key).begins_with("target_"):
			target_val = int(tmpl[key])
			break
	return {
		"type": picked_key,
		"target": str(tmpl.get("name", picked_key)),
		"description": str(tmpl.get("description_template", "")),
		"progress": 0,
		"total": target_val,
		"revealed": false,
	}


## Progress mission by step. Returns result dict.
static func progress_mission(state: Dictionary, step: int) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var mission: Dictionary = run.get("mission", {})
	var old_progress: int = int(mission.get("progress", 0))
	var total: int = int(mission.get("total", 0))
	var new_progress: int = mini(old_progress + step, total)
	mission["progress"] = new_progress
	run["mission"] = mission
	state["run"] = run
	return {"ok": true, "progress": new_progress, "total": total, "complete": new_progress >= total}


## Resolve a player choice on a card. apply_effect_func: Callable(effect: Dictionary).
static func resolve_choice(state: Dictionary, card: Dictionary, option: int, modulated_effects: Array, apply_effect_func: Callable, biomes: MerlinBiomeSystem) -> Dictionary:
	var run: Dictionary = state.get("run", {})

	if modulated_effects.is_empty():
		var options: Array = card.get("options", [])
		if option >= 0 and option < options.size():
			var chosen: Dictionary = options[option]
			var card_effects: Array = chosen.get("effects", [])
			for effect in card_effects:
				apply_effect_func.call(effect)
	else:
		for effect in modulated_effects:
			apply_effect_func.call(effect)

	run["cards_played"] = int(run.get("cards_played", 0)) + 1

	# Record card text + choice in story_log for LLM context variety
	var story_log: Array = run.get("story_log", [])
	var card_text: String = str(card.get("text", "")).substr(0, 120)
	var options_arr: Array = card.get("options", [])
	var chosen_label: String = ""
	if option >= 0 and option < options_arr.size():
		chosen_label = str(options_arr[option].get("label", ""))
	story_log.append({"text": card_text, "choice": chosen_label, "card_idx": run["cards_played"]})
	if story_log.size() > 2:
		story_log = story_log.slice(-2)
	run["story_log"] = story_log

	state["run"] = run

	# Update player profile based on choice
	update_player_profile(state, option)

	# Tick Ogham cooldowns
	StoreOghams.tick_cooldowns(state)

	# Biome passive only in legacy path
	if modulated_effects.is_empty():
		var biome_key: String = str(run.get("current_biome", ""))
		if not biome_key.is_empty():
			var passive: Dictionary = biomes.get_passive_effect(biome_key, int(run.get("cards_played", 0)))
			if not passive.is_empty():
				apply_effect_func.call(passive)

	# Check promise deadlines
	check_promise_deadlines(state, apply_effect_func)

	return {"ok": true, "option": option, "cards_played": run["cards_played"]}


static func update_player_profile(state: Dictionary, option: int) -> void:
	var hidden: Dictionary = state["run"].get("hidden", {})
	var profile: Dictionary = hidden.get("player_profile", {})

	match option:
		MerlinConstants.CardOption.LEFT:
			profile["prudence"] = int(profile.get("prudence", 0)) + 1
		MerlinConstants.CardOption.CENTER:
			pass
		MerlinConstants.CardOption.RIGHT:
			profile["audace"] = int(profile.get("audace", 0)) + 1

	hidden["player_profile"] = profile
	state["run"]["hidden"] = hidden


static func check_run_end(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("run", {})

	var life: int = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	if life <= 0:
		return {
			"ended": true,
			"ending": {"title": "Essences Epuisees", "text": "Tes essences de vie se sont taries... la foret te rappelle a elle."},
			"score": int(run.get("cards_played", 0)) * 10,
			"cards_played": run.get("cards_played", 0),
			"days_survived": run.get("day", 1),
			"life_depleted": true,
		}

	var mission: Dictionary = run.get("mission", {})
	var cards_played: int = int(run.get("cards_played", 0))
	if int(mission.get("progress", 0)) >= int(mission.get("total", 0)) and int(mission.get("total", 0)) > 0 and cards_played >= MerlinConstants.MIN_CARDS_FOR_VICTORY:
		var victory_type: String = get_victory_type(state)
		var victory_endings: Dictionary = {
			"harmonie": {"title": "Harmonie Retrouvee", "text": "Tu as accompli ta quete avec sagesse et bienveillance."},
			"victoire_amere": {"title": "Victoire Amere", "text": "Ta quete est accomplie, mais a quel prix..."},
			"prix_paye": {"title": "Le Prix Paye", "text": "Tu as reussi, mais la foret se souviendra de tes choix."},
		}
		return {
			"ended": true,
			"ending": victory_endings.get(victory_type, {"title": "Victoire"}),
			"victory": true,
			"score": int(run.get("cards_played", 0)) * 20,
			"cards_played": run.get("cards_played", 0),
			"days_survived": run.get("day", 1),
		}

	# MOS tension tracking (bible v2.4 s.6.2)
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 8))
	var target_min: int = int(mos.get("target_cards_min", 20))
	var target_max: int = int(mos.get("target_cards_max", 25))
	var soft_max: int = int(mos.get("soft_max_cards", 40))
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	if cards_played >= hard_max:
		return {
			"ended": true,
			"ending": {"title": "Fin du Temps", "text": "Le temps s'est ecoule... la foret te rappelle."},
			"score": cards_played * 10,
			"cards_played": cards_played,
			"days_survived": run.get("day", 1),
			"hard_max": true,
		}

	var tension_zone: String = "none"
	var convergence_zone: bool = false
	var early_zone: bool = false
	if cards_played >= soft_max:
		tension_zone = "critical"
		convergence_zone = true
	elif cards_played >= target_max:
		tension_zone = "high"
		convergence_zone = true
	elif cards_played >= target_min:
		tension_zone = "rising"
		convergence_zone = true
	elif cards_played >= soft_min:
		tension_zone = "low"
		early_zone = true

	return {
		"ended": false,
		"tension_zone": tension_zone,
		"convergence_zone": convergence_zone,
		"early_zone": early_zone,
		"cards_played": cards_played,
	}


static func get_victory_type(state: Dictionary) -> String:
	var hidden: Dictionary = state.get("run", {}).get("hidden", {})
	var karma: int = int(hidden.get("karma", 0))
	if karma >= 5:
		return "harmonie"
	elif karma <= -5:
		return "victoire_amere"
	else:
		return "prix_paye"


static func handle_run_end(state: Dictionary, end_check: Dictionary, save_system: MerlinSaveSystem) -> Dictionary:
	var meta: Dictionary = state.get("meta", {})
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["total_cards_played"] = int(meta.get("total_cards_played", 0)) + int(end_check.get("cards_played", 0))

	var ending: Dictionary = end_check.get("ending", {})
	var ending_title: String = str(ending.get("title", ""))
	var endings_seen: Array = meta.get("endings_seen", [])
	if not endings_seen.has(ending_title):
		endings_seen.append(ending_title)
	meta["endings_seen"] = endings_seen
	state["meta"] = meta

	# Calculate and apply run rewards (Anam)
	var rewards: Dictionary = calculate_run_rewards(state, end_check)
	apply_run_rewards(state, rewards, save_system)
	end_check["rewards"] = rewards

	return end_check


static func check_promise_deadlines(state: Dictionary, apply_effect_func: Callable) -> void:
	var run: Dictionary = state.get("run", {})
	var promises: Array = run.get("active_promises", [])
	var cards_played: int = int(run.get("cards_played", 0))
	var broken_count: int = 0

	for promise in promises:
		if str(promise.get("status", "")) != "active":
			continue
		var made_at: int = int(promise.get("made_at_card", 0))
		var deadline_cards: int = int(promise.get("deadline_cards", 0))
		if deadline_cards > 0 and cards_played >= made_at + deadline_cards:
			promise["status"] = "broken"
			broken_count += 1

	if broken_count > 0:
		run["active_promises"] = promises
		state["run"] = run
		for i in broken_count:
			apply_effect_func.call({"type": "ADD_KARMA", "amount": -15})
			apply_effect_func.call({"type": "ADD_TENSION", "amount": 10})


static func calculate_run_rewards(state: Dictionary, run_data: Dictionary) -> Dictionary:
	var anam: int = MerlinConstants.ANAM_BASE_REWARD

	var is_victory: bool = bool(run_data.get("victory", false))
	if is_victory:
		anam += MerlinConstants.ANAM_VICTORY_BONUS

	var minigames_won: int = int(run_data.get("minigames_won", 0))
	var oghams_used: int = int(run_data.get("oghams_used", 0))
	var cards_played: int = int(run_data.get("cards_played", 0))

	anam += minigames_won * MerlinConstants.ANAM_PER_MINIGAME
	anam += oghams_used * MerlinConstants.ANAM_PER_OGHAM

	var faction_rep: Dictionary = state.get("meta", {}).get("faction_rep", {})
	for faction in faction_rep:
		if float(faction_rep[faction]) >= 80.0:
			anam += MerlinConstants.ANAM_FACTION_HONORE

	if not is_victory:
		var death_cap: int = int(MerlinConstants.ANAM_REWARDS.get("death_cap_cards", 30))
		if death_cap > 0:
			var ratio: float = minf(float(cards_played) / float(death_cap), 1.0)
			anam = int(float(anam) * ratio)
		else:
			anam = 0

	if StoreTalents.get_talent_modifier(state, "double_anam_rewards"):
		anam *= 2
	if StoreTalents.get_talent_modifier(state, "bonus_anam_per_run"):
		anam += 3
	if StoreTalents.get_talent_modifier(state, "low_life_bonus") and int(run_data.get("life_at_end", 100)) <= 25:
		anam = int(anam * 1.5)
	if StoreTalents.get_talent_modifier(state, "new_game_plus"):
		anam = int(anam * 1.5)

	anam = maxi(anam, 0)

	return {
		"anam": anam,
		"victory": is_victory,
		"cards_played": cards_played,
		"minigames_won": minigames_won,
		"oghams_used": oghams_used,
		"biome": str(run_data.get("current_biome", run_data.get("biome", ""))),
	}


static func apply_run_rewards(state: Dictionary, rewards: Dictionary, save_system: MerlinSaveSystem) -> void:
	var meta: Dictionary = state.get("meta", {})
	var anam_earned: int = int(rewards.get("anam", 0))
	meta["anam"] = int(meta.get("anam", 0)) + anam_earned
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	var stats: Dictionary = meta.get("stats", {})
	stats["total_anam_earned"] = int(stats.get("total_anam_earned", 0)) + anam_earned
	stats["total_cards"] = int(stats.get("total_cards", 0)) + int(rewards.get("cards_played", 0))
	stats["total_minigames_won"] = int(stats.get("total_minigames_won", 0)) + int(rewards.get("minigames_won", 0))
	if not bool(rewards.get("victory", false)):
		stats["total_deaths"] = int(stats.get("total_deaths", 0)) + 1
		stats["consecutive_deaths"] = int(stats.get("consecutive_deaths", 0)) + 1
	else:
		stats["consecutive_deaths"] = 0
	meta["stats"] = stats
	var biome: String = str(rewards.get("biome", ""))
	if not biome.is_empty():
		var biome_runs: Dictionary = meta.get("biome_runs", {})
		biome_runs[biome] = int(biome_runs.get(biome, 0)) + 1
		meta["biome_runs"] = biome_runs
	state["meta"] = meta
	save_system.save_profile(meta)


## Maturity score for biome unlock progression (bible v2.4 s.5.1).
static func calculate_maturity_score(state: Dictionary) -> int:
	var meta: Dictionary = state.get("meta", {})
	var weights: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	var score: int = 0
	score += int(meta.get("total_runs", 0)) * int(weights.get("total_runs", 2))
	score += meta.get("endings_seen", []).size() * int(weights.get("fins_vues", 5))
	score += meta.get("oghams", {}).get("owned", []).size() * int(weights.get("oghams_debloques", 3))
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var max_rep: float = 0.0
	for faction in faction_rep:
		max_rep = maxf(max_rep, float(faction_rep[faction]))
	score += int(max_rep) * int(weights.get("max_faction_rep", 1))
	return score


static func can_unlock_biome(state: Dictionary, biome_id: String) -> bool:
	var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_id, 999))
	return calculate_maturity_score(state) >= threshold


static func get_unlockable_biomes(state: Dictionary) -> Array:
	var result: Array = []
	for biome_id in MerlinConstants.BIOME_MATURITY_THRESHOLDS:
		if can_unlock_biome(state, biome_id):
			result.append(biome_id)
	return result
