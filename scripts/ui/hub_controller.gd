## ═══════════════════════════════════════════════════════════════════════════════
## Hub Controller — Hub 2D bridge (Phase 7, DEV_PLAN_V2.5)
## ═══════════════════════════════════════════════════════════════════════════════
## Manages the hub screen: Merlin dialogue (LLM), talent tree, biome select,
## stats, oghams, journal, options. Bridges HubAntre scene with game systems.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name HubController

signal hub_ready()
signal run_requested(biome: String, ogham: String)
signal talent_unlocked(talent_id: String)

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

var _store: MerlinStore
var _save: MerlinSaveSystem
var _llm: MerlinLlmAdapter
var _profile: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(store: MerlinStore, save: MerlinSaveSystem, llm: MerlinLlmAdapter) -> void:
	_store = store
	_save = save
	_llm = llm


# ═══════════════════════════════════════════════════════════════════════════════
# HUB LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func show_hub() -> void:
	_profile = _save.load_or_create_profile()
	hub_ready.emit()


func get_profile_summary() -> Dictionary:
	return _save.get_profile_info()


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN DIALOGUE — LLM-generated contextual greeting
# ═══════════════════════════════════════════════════════════════════════════════

func generate_merlin_dialogue(last_run: Dictionary) -> Dictionary:
	if _llm == null:
		return _get_fallback_dialogue(last_run)

	var context: Dictionary = {
		"type": "hub_greeting",
		"total_runs": int(_profile.get("total_runs", 0)),
		"trust_merlin": int(_profile.get("trust_merlin", 0)),
		"last_biome": str(last_run.get("biome", "")),
		"last_reason": str(last_run.get("reason", "")),
		"faction_rep": _profile.get("faction_rep", {}),
		"endings_seen": _profile.get("endings_seen", []),
		"oghams_owned": _profile.get("oghams", {}).get("owned", []),
	}

	var result: Dictionary = await _llm.generate_card(context)
	if result.get("ok", false):
		var card: Dictionary = result.get("card", {})
		return {
			"text": str(card.get("text", "")),
			"speaker": "merlin",
		}

	return _get_fallback_dialogue(last_run)


func _get_fallback_dialogue(last_run: Dictionary) -> Dictionary:
	var runs: int = int(_profile.get("total_runs", 0))
	var reason: String = str(last_run.get("reason", ""))

	if runs == 0:
		return {"text": "Bienvenue, jeune druide. Le chemin t'attend.", "speaker": "merlin"}

	match reason:
		"death":
			return {"text": "La mort n'est qu'un passage. Tu reviendras plus fort.", "speaker": "merlin"}
		"hard_max":
			return {"text": "Tu as parcouru un long chemin. Repose-toi avant de repartir.", "speaker": "merlin"}
		_:
			var texts: Array = [
				"Les arbres murmurent ton nom. Es-tu pret ?",
				"Chaque run revele un fragment de verite.",
				"Le vent porte des nouvelles des biomes lointains.",
				"Les oghams brillent dans l'obscurite. Ils t'appellent.",
			]
			return {"text": texts[runs % texts.size()], "speaker": "merlin"}


# ═══════════════════════════════════════════════════════════════════════════════
# TALENT TREE
# ═══════════════════════════════════════════════════════════════════════════════

func show_talent_tree() -> Dictionary:
	var talent_tree: Dictionary = _profile.get("talent_tree", {"unlocked": []})
	var anam: int = int(_profile.get("anam", 0))
	var tiers: Dictionary = MerlinConstants.TALENT_TIERS

	var available: Array = []
	var unlocked: Array = talent_tree.get("unlocked", [])

	for tier_key in tiers:
		var tier: Dictionary = tiers[tier_key]
		var talents: Array = tier.get("talents", [])
		var cost: int = int(tier.get("cost", 0))

		for talent in talents:
			var tid: String = str(talent.get("id", ""))
			if unlocked.has(tid):
				continue
			# Check prerequisites
			var prereqs: Array = talent.get("requires", [])
			var can_unlock: bool = true
			for prereq in prereqs:
				if not unlocked.has(str(prereq)):
					can_unlock = false
					break
			if can_unlock and anam >= cost:
				available.append({
					"id": tid,
					"name": str(talent.get("name", "")),
					"description": str(talent.get("description", "")),
					"cost": cost,
					"tier": tier_key,
				})

	return {
		"unlocked": unlocked,
		"available": available,
		"anam": anam,
	}


func unlock_talent(talent_id: String) -> Dictionary:
	if _store == null:
		return {"ok": false, "error": "No store"}

	var talent_tree: Dictionary = _profile.get("talent_tree", {"unlocked": []})
	var unlocked: Array = talent_tree.get("unlocked", [])
	if unlocked.has(talent_id):
		return {"ok": false, "error": "Already unlocked"}

	# Find cost
	var cost: int = _find_talent_cost(talent_id)
	var anam: int = int(_profile.get("anam", 0))
	if anam < cost:
		return {"ok": false, "error": "Not enough anam"}

	# Unlock
	unlocked.append(talent_id)
	talent_tree["unlocked"] = unlocked
	_profile["talent_tree"] = talent_tree
	_profile["anam"] = anam - cost

	# Save
	_save.save_profile(_profile)
	talent_unlocked.emit(talent_id)

	return {"ok": true, "talent_id": talent_id, "anam_remaining": anam - cost}


func _find_talent_cost(talent_id: String) -> int:
	var tiers: Dictionary = MerlinConstants.TALENT_TIERS
	for tier_key in tiers:
		var tier: Dictionary = tiers[tier_key]
		var talents: Array = tier.get("talents", [])
		for talent in talents:
			if str(talent.get("id", "")) == talent_id:
				return int(tier.get("cost", 0))
	return 999


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME SELECT
# ═══════════════════════════════════════════════════════════════════════════════

func show_biome_select() -> Dictionary:
	var maturity: int = 0
	if _store:
		maturity = _store.calculate_maturity_score()

	var biomes: Dictionary = MerlinConstants.BIOMES
	var available: Array = []
	var locked: Array = []

	for biome_key in biomes:
		var biome: Dictionary = biomes[biome_key]
		var threshold: int = int(biome.get("maturity_threshold", 0))
		var info: Dictionary = MerlinConstants.get_mission_template(biome_key)
		var entry: Dictionary = {
			"id": biome_key,
			"name": str(info.get("name", biome_key)),
			"title": str(info.get("title", "")),
			"text": str(info.get("text", "")),
			"threshold": threshold,
			"maturity": maturity,
		}
		if maturity >= threshold:
			available.append(entry)
		else:
			entry["locked"] = true
			locked.append(entry)

	return {
		"available": available,
		"locked": locked,
		"maturity_score": maturity,
	}


func request_run(biome: String, ogham: String) -> void:
	run_requested.emit(biome, ogham)


# ═══════════════════════════════════════════════════════════════════════════════
# WORLD MAP — Full progression view for carte du monde
# ═══════════════════════════════════════════════════════════════════════════════

func get_world_map() -> Dictionary:
	var arc_tags: Array = _profile.get("arc_tags", [])
	var biome_runs: Dictionary = _profile.get("biome_runs", {})
	var endings: Array = _profile.get("endings_seen", [])
	var whispers: Array = _profile.get("whispers_seen", [])

	var biome_data: Array = []
	for biome_key in MerlinConstants.BIOME_KEYS:
		var biome: Dictionary = MerlinConstants.BIOMES.get(biome_key, {})
		var arc_id: String = str(biome.get("arc", ""))
		var arc_total: int = int(biome.get("arc_cards", 0))

		# Count completed arc stages from arc_tags
		var arc_completed: int = 0
		for tag in arc_tags:
			if str(tag).begins_with(arc_id):
				arc_completed += 1

		var runs_here: int = int(biome_runs.get(biome_key, 0))
		var deaths_here: int = int(_profile.get("echo_memory", {}).get("deaths_by_biome", {}).get(biome_key, 0))

		biome_data.append({
			"id": biome_key,
			"name": str(biome.get("name", biome_key)),
			"pnj": str(biome.get("pnj", "")),
			"arc": arc_id,
			"arc_progress": arc_completed,
			"arc_total": arc_total,
			"arc_complete": arc_completed >= arc_total and arc_total > 0,
			"runs": runs_here,
			"deaths": deaths_here,
			"unlocked": _profile.get("biomes_unlocked", []).has(biome_key),
		})

	return {
		"biomes": biome_data,
		"total_runs": int(_profile.get("total_runs", 0)),
		"endings_seen": endings,
		"whispers_found": whispers.size(),
		"whispers_total": 10,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# STATS
# ═══════════════════════════════════════════════════════════════════════════════

func get_stats() -> Dictionary:
	return {
		"profile": _save.get_profile_info(),
		"stats": _profile.get("stats", {}),
		"biome_runs": _profile.get("biome_runs", {}),
		"oghams": _profile.get("oghams", {}),
		"endings_seen": _profile.get("endings_seen", []),
		"arc_tags": _profile.get("arc_tags", []),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# WHISPER MEMORIES — Collected meta-narrative breadcrumbs
# ═══════════════════════════════════════════════════════════════════════════════

func get_whisper_memories() -> Dictionary:
	var whispers_seen: Array = _profile.get("whispers_seen", [])
	var total_whispers: int = 10  # Total whisper cards in event_cards.json
	return {
		"collected": whispers_seen,
		"count": whispers_seen.size(),
		"total": total_whispers,
		"progress": float(whispers_seen.size()) / float(maxi(total_whispers, 1)),
		"all_found": whispers_seen.size() >= total_whispers,
	}


func record_whisper_seen(whisper_id: String) -> void:
	var whispers_seen: Array = _profile.get("whispers_seen", [])
	if not whispers_seen.has(whisper_id):
		whispers_seen.append(whisper_id)
		_profile["whispers_seen"] = whispers_seen
		if _save:
			_save.save_profile(_profile)


# ═══════════════════════════════════════════════════════════════════════════════
# JOURNAL — Cross-run history for "vies passées"
# ═══════════════════════════════════════════════════════════════════════════════

func get_journal() -> Dictionary:
	var run_history: Array = _profile.get("run_history", [])
	return {
		"total_runs": int(_profile.get("total_runs", 0)),
		"runs": run_history,
		"endings_seen": _profile.get("endings_seen", []),
		"arc_tags": _profile.get("arc_tags", []),
		"whispers_found": _profile.get("whispers_seen", []).size(),
	}


func record_run_end(run_summary: Dictionary) -> void:
	var run_history: Array = _profile.get("run_history", [])
	# Keep last 20 runs
	run_history.append({
		"biome": str(run_summary.get("biome", "")),
		"cards_played": int(run_summary.get("cards_played", 0)),
		"ending": str(run_summary.get("ending", "")),
		"life_remaining": int(run_summary.get("life_remaining", 0)),
		"dominant_faction": str(run_summary.get("dominant_faction", "")),
		"whisper_seen": str(run_summary.get("whisper_seen", "")),
	})
	if run_history.size() > 20:
		run_history = run_history.slice(run_history.size() - 20)
	_profile["run_history"] = run_history
	if _save:
		_save.save_profile(_profile)


# ═══════════════════════════════════════════════════════════════════════════════
# ECHO MEMORY — Cross-run choice tracking for echo cards
# ═══════════════════════════════════════════════════════════════════════════════

func record_death_in_biome(biome: String) -> void:
	var echo: Dictionary = _profile.get("echo_memory", {})
	var deaths: Dictionary = echo.get("deaths_by_biome", {})
	deaths[biome] = int(deaths.get(biome, 0)) + 1
	echo["deaths_by_biome"] = deaths
	_profile["echo_memory"] = echo


func record_dominant_faction(faction: String) -> void:
	var echo: Dictionary = _profile.get("echo_memory", {})
	var factions: Array = echo.get("dominant_factions_seen", [])
	if not factions.has(faction):
		factions.append(faction)
	echo["dominant_factions_seen"] = factions
	_profile["echo_memory"] = echo


func check_echo_condition(condition: String, context: Dictionary) -> bool:
	var echo: Dictionary = _profile.get("echo_memory", {})
	var biome: String = str(context.get("biome", ""))
	match condition:
		"previous_death_in_biome":
			return int(echo.get("deaths_by_biome", {}).get(biome, 0)) > 0
		"dominant_faction_above_50":
			var factions: Dictionary = _profile.get("faction_rep", {})
			for f in factions:
				if float(factions[f]) >= 50.0:
					return true
			return false
		"oghams_owned_above_5":
			return _profile.get("oghams", {}).get("owned", []).size() > 5
		_:
			return false


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func get_ogham_shop() -> Dictionary:
	var owned: Array = _profile.get("oghams", {}).get("owned", [])
	var anam: int = int(_profile.get("anam", 0))
	var available: Array = []

	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		if owned.has(ogham_key):
			continue
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		var cost: int = int(spec.get("cost_anam", 0))
		if _store:
			cost = _store.get_ogham_cost(ogham_key)
		available.append({
			"id": ogham_key,
			"name": str(spec.get("name", "")),
			"description": str(spec.get("description", "")),
			"cost": cost,
			"can_afford": anam >= cost,
			"category": str(spec.get("category", "")),
			"branch": str(spec.get("branch", "")),
		})

	return {
		"owned": owned,
		"available": available,
		"anam": anam,
		"equipped": str(_profile.get("oghams", {}).get("equipped", "beith")),
	}
