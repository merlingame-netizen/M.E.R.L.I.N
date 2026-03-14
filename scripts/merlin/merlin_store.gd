## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Store — Central State Management
## ═══════════════════════════════════════════════════════════════════════════════
## Redux-like state management for Merlin game.
## Updated 2026-03-11 — TRIADE-CORE-2: removed Triade aspect/souffle state.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MerlinStore

signal state_changed(state: Dictionary)
signal phase_changed(phase: String)
signal transition_logged(entry: Dictionary)
signal life_changed(old_value: int, new_value: int)
signal reputation_changed(faction: String, value: float, delta: float)
signal run_ended(ending: Dictionary)
signal card_resolved(card_id: String, option: int)
signal mission_progress(step: int, total: int)
signal ogham_activated(skill_id: String, effect: String)
signal season_changed(new_season: String)
signal event_available(event_id: String, event_data: Dictionary)
signal faveurs_changed(old_val: int, new_val: int)

const VERSION := "0.4.0"  # Updated for World Map gauge system

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEMS
# ═══════════════════════════════════════════════════════════════════════════════

var state: Dictionary = {}
var rng := MerlinRng.new()
var save_system := MerlinSaveSystem.new()
var effects := MerlinEffectEngine.new()
var action_resolver := MerlinActionResolver.new()
var minigames := MerlinMiniGameSystem.new()
var map_system := MerlinMapSystem.new()
var llm := MerlinLlmAdapter.new()
var events := MerlinEventSystem.new()
var cards := MerlinCardSystem.new()
var biomes := MerlinBiomeSystem.new()
var scenarios := MerlinScenarioManager.new()

# Auto-save (debounced)
const AUTOSAVE_DEBOUNCE_SEC := 30.0
var _autosave_timer: Timer = null
var _autosave_pending := false

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN OMNISCIENT SYSTEM (MOS)
# ═══════════════════════════════════════════════════════════════════════════════
var merlin: MerlinOmniscient = null

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	minigames.set_rng(rng)
	events.setup(action_resolver, minigames, effects, llm)
	cards.setup(effects, llm, rng)

	# Connect card system signals
	cards.run_ended.connect(_on_run_ended)

	# Wire MerlinAI autoload to the LLM adapter
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		llm.set_merlin_ai(merlin_ai_node)
	else:
		call_deferred("_deferred_wire_merlin_ai")

	# Initialize MERLIN OMNISCIENT SYSTEM
	_init_merlin_omniscient()

	state = build_default_state()

	# Load saved profile (meta-progression)
	var saved_meta: Dictionary = save_system.load_profile()
	if not saved_meta.is_empty():
		state["meta"] = saved_meta

	_emit_state_changed()

	# Setup autosave timer
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DEBOUNCE_SEC
	_autosave_timer.timeout.connect(_do_autosave)
	add_child(_autosave_timer)


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN OMNISCIENT INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init_merlin_omniscient() -> void:
	"""Initialize the Merlin Omniscient System if available."""
	# Check if MerlinOmniscient class exists (addon loaded)
	if ClassDB.class_exists("MerlinOmniscient"):
		merlin = MerlinOmniscient.new()
		merlin.setup(self)
		add_child(merlin)
		print("[MerlinStore] MERLIN OMNISCIENT SYSTEM initialized")
	else:
		# Try to instantiate directly (for RefCounted classes)
		var script_path := "res://addons/merlin_ai/merlin_omniscient.gd"
		if ResourceLoader.exists(script_path):
			var script = load(script_path)
			if script:
				merlin = script.new()
				merlin.setup(self)
				# MerlinOmniscient extends Node, so add as child
				add_child(merlin)
				print("[MerlinStore] MERLIN OMNISCIENT SYSTEM initialized (script load)")
		else:
			print("[MerlinStore] MerlinOmniscient not available - using legacy LLM")


func get_merlin() -> MerlinOmniscient:
	"""Get the Merlin Omniscient instance."""
	return merlin


func is_merlin_active() -> bool:
	"""Check if Merlin Omniscient is active."""
	return merlin != null


func get_scenario_manager() -> MerlinScenarioManager:
	return scenarios


func get_event_adapter() -> EventAdapter:
	"""Get the EventAdapter from MerlinOmniscient."""
	if merlin and merlin.event_adapter:
		return merlin.event_adapter
	return null


func _deferred_wire_merlin_ai() -> void:
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		llm.set_merlin_ai(merlin_ai_node)
		print("[MerlinStore] MerlinAI wired to LLM adapter (deferred)")


# ═══════════════════════════════════════════════════════════════════════════════
# STATE BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func build_default_state() -> Dictionary:
	return {
		"version": VERSION,
		"phase": "title",
		"mode": "triade",
		"timestamp": int(Time.get_unix_time_from_system()),
		"run": {
			"active": false,
			"floor": 0,
			"map_seed": 0,
			"map": [],
			"path": [],
			"life_essence": MerlinConstants.LIFE_ESSENCE_START,
			"anam_run": 0,
			"faveurs": MerlinConstants.FAVEURS_START,
			"mission": {
				"type": "",
				"target": "",
				"description": "",
				"progress": 0,
				"total": 0,
				"revealed": false,
			},
			"cards_played": 0,
			"day": 1,
			"start_date": Time.get_date_dict_from_system(),
			"events_seen": [],
			"event_locks": [],        # Locked event IDs (Brumes feature, max 3/run)
			"event_rerolls_used": 0,  # Reroll count this run (Brumes, max 3/run)
			"story_log": [],
			"active_tags": [],
			"active_promises": [],
			"effect_modifier": {},
			# Hidden depth tracking
			"hidden": {
				"karma": 0,
				"tension": 0,
				"player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0},
				"resonances_active": [],
				"narrative_debt": [],
			},
			# Faction context (snapshot meta.faction_rep en début de run)
			"faction_context": {
				"dominant": "",
				"tiers": {},
				"active_effects": [],
			},
			# Faction reputation per run
			"factions": {
				"druides": 0.0,
				"anciens": 0.0,
				"korrigans": 0.0,
				"niamh": 0.0,
				"ankou": 0.0,
			},
			"tour": 0,
			"run_active": false,
			"ogham_actif": "",
			"oghams_decouverts": [],
			"cartes_jouees": [],
			"heure_debut_run": 0,
		},
		# Ogham skills state (formerly on bestiole)
		"oghams": {
			"skills_unlocked": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skills_equipped": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skill_cooldowns": {},
		},
		"meta": {
			"anam": 0,
			# Faction alignment — reputation cross-run (0-100 par faction)
			"faction_rep": {
				"druides": MerlinConstants.FACTION_SCORE_START,
				"korrigans": MerlinConstants.FACTION_SCORE_START,
				"niamh": MerlinConstants.FACTION_SCORE_START,
				"anciens": MerlinConstants.FACTION_SCORE_START,
				"ankou": MerlinConstants.FACTION_SCORE_START,
			},
			"achievements": {},
			"ach_unlocked": [],
			"unlocks": [],
			"packages": [],
			"active_package": "",
			"total_runs": 0,
			"total_cards_played": 0,
			"endings_seen": [],
			# Arbre de Vie — Talent Tree v2.1 (faction-based, cout Anam)
			"talent_tree": {
				"unlocked": [],  # Array of talent node IDs
			},
		},
		# World Map progression — persistent across runs
		"map_progression": {
			"gauges": MerlinGaugeSystem.new().build_default_gauges(),
			"current_biome": "foret_broceliande",
			"completed_biomes": [],
			"visited_biomes": ["foret_broceliande"],
			"items_collected": [],
			"reputations": [],
			"tier_progress": 1,
		},
		"flags": {},  # Global flags for narrative
		"story_log": [],
		"effect_log": [],
		"transition_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# DISPATCH (Action Handler)
# ═══════════════════════════════════════════════════════════════════════════════

func dispatch(action: Dictionary) -> Dictionary:
	var prev_phase: String = str(state.get("phase", ""))
	var result: Dictionary = await _reduce(action)
	if prev_phase != state.get("phase", ""):
		emit_signal("phase_changed", state.get("phase", ""))
	_emit_state_changed()
	return result


func _reduce(action: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		# ═══════════════════════════════════════════════════════════════════════
		# CORE ACTIONS
		# ═══════════════════════════════════════════════════════════════════════
		"SET_PHASE":
			state["phase"] = action.get("phase", state.get("phase", "title"))
			_log_transition("phase", {"phase": state["phase"]})
			return {"ok": true}

		"SET_SEED":
			var seed: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed)
			state["run"]["map_seed"] = seed
			return {"ok": true, "seed": seed}

		# ═══════════════════════════════════════════════════════════════════════
		# RUN ACTIONS
		# ═══════════════════════════════════════════════════════════════════════
		"START_RUN":
			var seed_val: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed_val)
			_init_run()
			_reset_ai_for_new_run()
			state["run"]["map_seed"] = seed_val
			# Set biome from action (default: Broceliande)
			var biome_key: String = str(action.get("biome", MerlinConstants.BIOME_DEFAULT))
			state["run"]["current_biome"] = biome_key
			state["phase"] = "card"
			state["mode"] = "run"
			# Initialize calendar context for this run (real date)
			_init_calendar_context()
			_log_transition("run_start", {"seed": seed_val, "biome": biome_key})
			# Notify MERLIN OMNISCIENT
			if merlin != null:
				merlin.on_run_start()
				# Reset EventAdapter for new run
				if merlin.event_adapter:
					merlin.event_adapter.reset_for_new_run()
			return {"ok": true, "biome": biome_key}

		"GET_CARD":
			var card: Dictionary = {}
			# LLM-only: use MERLIN OMNISCIENT or direct LLM, no static fallback
			if merlin != null and is_instance_valid(merlin):
				print("[MerlinStore] GET_CARD: using MerlinOmniscient")
				var mos_card = await merlin.generate_card(state)
				if mos_card is Dictionary and not mos_card.is_empty():
					card = mos_card
				else:
					print("[MerlinStore] MOS returned empty, controller will retry LLM")
			elif llm != null and llm.is_llm_ready():
				# Direct adapter path (no MOS)
				print("[MerlinStore] GET_CARD: using direct LLM")
				var ctx: Dictionary = state.get("run", {}).duplicate()
				var llm_result: Dictionary = await llm.generate_card(ctx)
				if llm_result.get("ok", false) and llm_result.has("card"):
					card = llm_result["card"]
				else:
					print("[MerlinStore] Direct LLM failed, controller will retry")
			else:
				push_warning("[MerlinStore] GET_CARD: no LLM available — controller must retry")
			# Validate card has usable options (LLM-only: no emergency fallback)
			if card.is_empty() or not card.has("options") or card.get("options", []).size() < 2:
				return {"ok": false, "error": "llm_no_card"}
			return {"ok": true, "card": card}

		"RESOLVE_CHOICE":
			var card = action.get("card", {})
			var option: int = int(action.get("option", MerlinConstants.CardOption.LEFT))
			var mod_effects: Array = action.get("modulated_effects", [])
			var result = _resolve_choice(card, option, mod_effects)
			if result["ok"]:
				# Record choice with MERLIN OMNISCIENT
				if merlin != null:
					merlin.record_choice(card, option, state)
				card_resolved.emit(card.get("id", ""), option)
				_trigger_autosave()
				var end_check = _check_run_end()
				if end_check["ended"]:
					state["run"]["active"] = false
					state["phase"] = "end"
					_handle_run_end(end_check)
					# Notify Merlin of run end
					if merlin != null:
						merlin.on_run_end(end_check)
					return {"ok": true, "run_ended": true, "ending": end_check}
			return result

		"PROGRESS_MISSION":
			var step: int = int(action.get("step", 1))
			return _progress_mission(step)


		"USE_OGHAM":
			var skill_id: String = str(action.get("skill_id", ""))
			return _use_ogham(skill_id)

		"END_RUN":
			var end_check = _check_run_end()
			if not end_check["ended"]:
				end_check = {
					"ended": true,
					"ending": {"title": "Abandon", "text": "Tu abandonnes ta quete..."},
					"score": state["run"].get("cards_played", 0) * 5,
					"cards_played": state["run"].get("cards_played", 0),
					"days_survived": state["run"].get("day", 1),
				}
			state["run"]["active"] = false
			state["phase"] = "end"
			_handle_run_end(end_check)
			# Notify MERLIN OMNISCIENT
			if merlin != null:
				merlin.on_run_end(end_check)
			return {"ok": true, "ending": end_check}

		# ═══════════════════════════════════════════════════════════════════════
		# MAP ACTIONS (Phase 37 — STS-like world map)
		# ═══════════════════════════════════════════════════════════════════════
		"GENERATE_MAP":
			var floors: int = int(action.get("floors", MerlinConstants.DEFAULT_MAP_FLOORS))
			var config: Dictionary = {}
			var biome_key_map: String = str(state.get("run", {}).get("current_biome", ""))
			if not biome_key_map.is_empty():
				config["biome"] = biome_key_map
				config["difficulty"] = biomes.get_difficulty_modifier(biome_key_map)
			var map_data: Array = map_system.generate_map(floors, rng, config)
			state["run"]["map"] = map_data
			state["run"]["floor"] = 0
			state["run"]["current_node_id"] = ""
			return {"ok": true, "map": map_data}

		"SELECT_NODE":
			var node_id: String = str(action.get("node_id", ""))
			var map_data: Array = state["run"].get("map", [])
			for floor_nodes in map_data:
				if not floor_nodes is Array:
					continue
				for node in floor_nodes:
					if not node is Dictionary:
						continue
					if str(node.get("id", "")) == node_id:
						node["visited"] = true
						state["run"]["floor"] = int(node.get("floor", 0))
						state["run"]["current_node_id"] = node_id
						# Reveal next floor
						var next_floor: int = int(node.get("floor", 0)) + 1
						if next_floor < map_data.size() and map_data[next_floor] is Array:
							for n in map_data[next_floor]:
								if n is Dictionary:
									n["revealed"] = true
						return {"ok": true, "node": node}
			return {"ok": false, "error": "Node not found: " + node_id}

		# ═══════════════════════════════════════════════════════════════════════
		# SAVE/LOAD
		# ═══════════════════════════════════════════════════════════════════════
		"SAVE_PROFILE":
			var ok: bool = save_system.save_profile(state.get("meta", {}))
			return {"ok": ok}

		"LOAD_PROFILE":
			var meta: Dictionary = save_system.load_profile()
			if meta.is_empty():
				return {"ok": false}
			state["meta"] = meta
			return {"ok": true}

		# ═══════════════════════════════════════════════════════════════════════
		# LIFE ESSENCE ACTIONS (Phase 43)
		# ═══════════════════════════════════════════════════════════════════════
		"DAMAGE_LIFE":
			var amount: int = int(action.get("amount", 1))
			return _damage_life(amount)

		"HEAL_LIFE":
			var amount: int = int(action.get("amount", 1))
			return _heal_life(amount)

		"FAVEUR_ADD":
			var amount: int = int(action.get("amount", MerlinConstants.FAVEURS_PER_MINIGAME_PLAY))
			return _add_faveur(amount)

		# ═══════════════════════════════════════════════════════════════════════
		# WORLD MAP PROGRESSION ACTIONS
		# ═══════════════════════════════════════════════════════════════════════
		"MAP_UPDATE_GAUGES":
			return _map_update_gauges(action)

		"MAP_COMPLETE_BIOME":
			return _map_complete_biome(action)

		"MAP_COLLECT_ITEM":
			return _map_collect_item(action)

		"MAP_ADD_REPUTATION":
			return _map_add_reputation(action)

		"MAP_SELECT_BIOME":
			return _map_select_biome(action)

		_:
			return {"ok": false, "error": "Unknown action"}


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func snapshot_for_save() -> Dictionary:
	var data: Dictionary = state.duplicate(true)
	data["timestamp"] = int(Time.get_unix_time_from_system())
	data["scenario_state"] = scenarios.save_state()
	return data


func _trigger_autosave() -> void:
	_autosave_pending = true
	if _autosave_timer and not _autosave_timer.is_stopped():
		return
	if _autosave_timer:
		_autosave_timer.start()


func _do_autosave() -> void:
	if not _autosave_pending:
		return
	_autosave_pending = false
	save_system.save_profile(state.get("meta", {}))
	if merlin:
		merlin.save_all()


func _restore_ai_state() -> void:
	## Restore MOS registries and session history after loading a save slot.
	if merlin:
		merlin.reload_registries()
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node and merlin_ai_node.has_method("load_session_history"):
		merlin_ai_node.load_session_history()
	# Restore scenario state from save data
	scenarios.load_state(state.get("scenario_state", {}))


func _reset_ai_for_new_run() -> void:
	## Reset per-run AI state while preserving cross-run memory.
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		merlin_ai_node.session_contexts.clear()



func _damage_life(amount: int) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var old_life: int = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	var new_life: int = maxi(old_life - amount, 0)
	run["life_essence"] = new_life
	state["run"] = run
	life_changed.emit(old_life, new_life)
	return {"ok": true, "old": old_life, "new": new_life, "damage": old_life - new_life}


func _heal_life(amount: int) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var old_life: int = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	var new_life: int = mini(old_life + amount, MerlinConstants.LIFE_ESSENCE_MAX)
	run["life_essence"] = new_life
	state["run"] = run
	life_changed.emit(old_life, new_life)
	return {"ok": true, "old": old_life, "new": new_life, "healed": new_life - old_life}


func _add_faveur(amount: int) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var old_val: int = int(run.get("faveurs", MerlinConstants.FAVEURS_START))
	var new_val: int = old_val + amount
	run["faveurs"] = new_val
	state["run"] = run
	faveurs_changed.emit(old_val, new_val)
	return {"ok": true, "old": old_val, "new": new_val, "added": amount}


# ─── Faction Alignment ───────────────────────────────────────────────────────

## Applique la décroissance 8% des réputations vers 0 (début de run).
func _decay_faction_rep() -> void:
	var meta: Dictionary = state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		var score: int = int(faction_rep.get(faction, 0))
		if score == 0:
			continue
		var decayed: int = int(float(score) * (1.0 - MerlinConstants.FACTION_DECAY_RATE))
		faction_rep[faction] = decayed
	meta["faction_rep"] = faction_rep
	state["meta"] = meta


## Snapshot faction_rep (meta) → run["faction_context"].
func _build_and_store_faction_context() -> void:
	var meta: Dictionary = state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var run: Dictionary = state.get("run", {})
	var context: Dictionary = {"dominant": "", "tiers": {}, "active_effects": []}
	var dominant_score: int = 0
	for faction in MerlinConstants.FACTIONS:
		var score: int = int(faction_rep.get(faction, 0))
		var tier: String = _faction_score_to_tier(score)
		context["tiers"][faction] = tier
		if tier != "neutre":
			context["active_effects"].append({"faction": faction, "tier": tier, "score": score})
		if score > dominant_score:
			context["dominant"] = faction
			dominant_score = score
	run["faction_context"] = context
	state["run"] = run


## Convertit un score faction en tier string.
func _faction_score_to_tier(score: int) -> String:
	if score >= 80:    return "honore"
	elif score >= 50:  return "sympathisant"
	elif score >= 20:  return "neutre"
	elif score >= 5:   return "mefiant"
	else:              return "hostile"


## Applique les bonus/malus de début de run selon les tiers actuels.
func _apply_faction_run_bonuses() -> void:
	var run: Dictionary = state.get("run", {})
	var faction_context: Dictionary = run.get("faction_context", {})
	var tiers: Dictionary = faction_context.get("tiers", {})
	for faction in MerlinConstants.FACTIONS:
		var tier: String = str(tiers.get(faction, "neutre"))
		var bonuses: Dictionary = MerlinConstants.FACTION_RUN_BONUSES.get(faction, {})
		var bonus: Dictionary = bonuses.get(tier, {})
		if bonus.is_empty():
			continue
		var bonus_type: String = str(bonus.get("type", ""))
		var amount: int = int(bonus.get("amount", 0))
		match bonus_type:
			"ADD_KARMA":
				var hidden: Dictionary = run.get("hidden", {})
				hidden["karma"] = int(hidden.get("karma", 0)) + amount
				run["hidden"] = hidden
			"ADD_TENSION":
				var hidden: Dictionary = run.get("hidden", {})
				hidden["tension"] = clampi(int(hidden.get("tension", 0)) + amount, 0, 100)
				run["hidden"] = hidden
			"HEAL_LIFE":
				run["life_essence"] = mini(int(run.get("life_essence", 0)) + amount, MerlinConstants.LIFE_ESSENCE_MAX)
			"DAMAGE_LIFE":
				run["life_essence"] = maxi(int(run.get("life_essence", 0)) - abs(amount), 0)
	state["run"] = run


func _generate_mission() -> Dictionary:
	var templates: Dictionary = MerlinConstants.MISSION_TEMPLATES
	# Weighted random pick
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
	# Extract target from type-specific key (target_cards, target_nodes, etc.)
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


func _on_run_ended(ending: Dictionary) -> void:
	pass  # Handled in RESOLVE_CHOICE


# ═══════════════════════════════════════════════════════════════════════════════
# RUN SYSTEM HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _init_run() -> void:
	var run = state.get("run", {})
	run["active"] = true
	run["life_essence"] = MerlinConstants.LIFE_ESSENCE_START
	run["anam"] = 0
	# Generate a mission from templates
	run["mission"] = _generate_mission()
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

	# Faction alignment — decay + context + bonuses (dans l'ordre)
	_decay_faction_rep()
	_build_and_store_faction_context()
	_apply_faction_run_bonuses()

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

	_apply_talent_effects_for_run()


func _init_calendar_context() -> void:
	## Set real-date calendar context for this run (CAL-REQ-001).
	var today := Time.get_date_dict_from_system()
	var run: Dictionary = state.get("run", {})
	run["start_date"] = {"year": today.year, "month": today.month, "day": today.day}
	run["events_seen"] = []
	run["event_locks"] = []
	run["event_rerolls_used"] = 0

	# Determine season from real date
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
	season_changed.emit(season)

	# Update EventAdapter calendar context if available
	if merlin and merlin.event_adapter:
		var days_table := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		var doy := 0
		for m in range(1, month):
			doy += days_table[m]
		doy += int(today.day)
		merlin.event_adapter.update_calendar_context(season, month, int(today.day), doy)


# ═══════════════════════════════════════════════════════════════════════════════
# TALENT EFFECTS — Applied at run start (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_talent_effects_for_run() -> void:
	"""Scan unlocked talents and apply their effects to the current run."""
	var unlocked: Array = state.get("meta", {}).get("talent_tree", {}).get("unlocked", [])
	if unlocked.is_empty():
		return

	var run: Dictionary = state.get("run", {})
	var modifiers: Dictionary = {}
	var life_max: int = MerlinConstants.LIFE_ESSENCE_MAX

	for node_id in unlocked:
		var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
		if node.is_empty():
			continue
		var effect: Dictionary = node.get("effect", {})
		var effect_type: String = str(effect.get("type", ""))

		match effect_type:
			"modify_start":
				var target: String = str(effect.get("target", ""))
				var value: int = int(effect.get("value", 0))
				match target:
					"life":
						run["life_essence"] = mini(int(run.get("life_essence", 0)) + value, life_max)
					"life_max":
						life_max += value
						run["life_max"] = life_max
						run["life_essence"] = mini(int(run.get("life_essence", 0)) + value, life_max)

			"cooldown_reduction":
				var category: Variant = effect.get("category", null)
				var value: int = int(effect.get("value", 0))
				if category == null:
					modifiers["cooldown_reduction_global"] = int(modifiers.get("cooldown_reduction_global", 0)) + value
				else:
					var key: String = "cooldown_reduction_" + str(category)
					modifiers[key] = int(modifiers.get(key, 0)) + value

			"minigame_bonus":
				var field: Variant = effect.get("field", null)
				var value: float = float(effect.get("value", 0.0))
				if field == null:
					modifiers["minigame_bonus_all"] = float(modifiers.get("minigame_bonus_all", 0.0)) + value
				else:
					var key: String = "minigame_bonus_" + str(field)
					modifiers[key] = float(modifiers.get(key, 0.0)) + value

			"score_global_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["score_global_bonus"] = float(modifiers.get("score_global_bonus", 0.0)) + value

			"drain_reduction":
				var value: int = int(effect.get("value", 0))
				modifiers["drain_reduction"] = int(modifiers.get("drain_reduction", 0)) + value

			"heal_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["heal_multiplier"] = float(modifiers.get("heal_multiplier", 0.0)) + value

			"rep_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["rep_gain_multiplier"] = float(modifiers.get("rep_gain_multiplier", 0.0)) + value

			"special_rule":
				var rule_id: String = str(effect.get("id", ""))
				modifiers[rule_id] = true

	run["talent_modifiers"] = modifiers
	state["run"] = run


func _get_talent_modifier(key: String, default_value: Variant = false) -> Variant:
	"""Helper to read a talent modifier from the current run."""
	return state.get("run", {}).get("talent_modifiers", {}).get(key, default_value)


func _consume_talent_modifier(key: String) -> bool:
	"""Consume a one-shot talent modifier (sets it to false). Returns true if was active."""
	var run: Dictionary = state.get("run", {})
	var modifiers: Dictionary = run.get("talent_modifiers", {})
	if modifiers.get(key, false):
		modifiers[key] = false
		run["talent_modifiers"] = modifiers
		state["run"] = run
		return true
	return false

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _use_ogham(skill_id: String) -> Dictionary:
	"""Activate an Ogham skill and apply cooldown."""
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return {"ok": false, "error": "Unknown ogham: " + skill_id}

	# Check cooldown
	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	var remaining: int = int(cooldowns.get(skill_id, 0))
	if remaining > 0:
		return {"ok": false, "error": "On cooldown", "remaining": remaining}

	# Check unlocked
	var unlocked: Array = oghams.get("skills_unlocked", [])
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter and not unlocked.has(skill_id):
		return {"ok": false, "error": "Skill not unlocked"}

	# Set cooldown
	cooldowns[skill_id] = int(spec.get("cooldown", 3))
	oghams["skill_cooldowns"] = cooldowns
	state["oghams"] = oghams

	# Emit signal
	ogham_activated.emit(skill_id, str(spec.get("effect", "")))

	# Apply effect
	_apply_ogham_effect(skill_id, spec)

	return {
		"ok": true,
		"skill_id": skill_id,
		"effect": spec.get("effect", ""),
	}


func _apply_ogham_effect(_skill_id: String, spec: Dictionary) -> void:
	"""Apply the actual Ogham effect on the game state."""
	var effect_id: String = str(spec.get("effect", ""))
	match effect_id:
		"heal_worst":
			# Quert: Aspect system removed — heal life instead
			_heal_life(10)
		"shield_shift":
			# Luis: Set a flag that prevents next negative shift
			var run: Dictionary = state.get("run", {})
			var modifiers: Dictionary = run.get("effect_modifier", {})
			modifiers["shield_next_negative"] = true
			run["effect_modifier"] = modifiers
			state["run"] = run
		"reveal_one", "reveal_all", "predict_next":
			# Handled by UI (controller reads the result)
			pass
		"force_equilibre":
			# Duir: Aspect system removed — heal life instead
			_heal_life(15)
		"balance_all":
			# Ruis: Aspect system removed — heal life instead
			_heal_life(20)
		"heal_life":
			# Onn: Heal life
			_heal_life(5)
		"reduce_cooldowns":
			# Saille: Reduce all cooldowns by 1
			tick_cooldowns()
		"skip_negative":
			# Eadhadh: Flag to cancel negatives on next choice
			var run: Dictionary = state.get("run", {})
			var modifiers: Dictionary = run.get("effect_modifier", {})
			modifiers["skip_all_negative"] = true
			run["effect_modifier"] = modifiers
			state["run"] = run
		"absorb_extreme":
			# Gort: If an aspect hits extreme after next card, revert it
			var run: Dictionary = state.get("run", {})
			var modifiers: Dictionary = run.get("effect_modifier", {})
			modifiers["absorb_extreme"] = true
			run["effect_modifier"] = modifiers
			state["run"] = run
		"double_positive":
			# Tinne: Double positives on next card
			var run: Dictionary = state.get("run", {})
			var modifiers: Dictionary = run.get("effect_modifier", {})
			modifiers["double_positive"] = true
			run["effect_modifier"] = modifiers
			state["run"] = run
		"invert_effects":
			# Muin: Invert positive/negative on current card
			var run: Dictionary = state.get("run", {})
			var modifiers: Dictionary = run.get("effect_modifier", {})
			modifiers["invert_effects"] = true
			run["effect_modifier"] = modifiers
			state["run"] = run
		"change_card", "full_reroll", "add_option", "force_twist", "sacrifice_trade":
			# These effects require UI/controller cooperation — flagged for controller
			pass


func tick_cooldowns() -> void:
	"""Decrement all Ogham cooldowns by 1. Call after each card resolved."""
	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	var to_remove: Array = []
	for skill_id in cooldowns:
		cooldowns[skill_id] = maxi(int(cooldowns[skill_id]) - 1, 0)
		if int(cooldowns[skill_id]) <= 0:
			to_remove.append(skill_id)
	for skill_id in to_remove:
		cooldowns.erase(skill_id)
	oghams["skill_cooldowns"] = cooldowns
	state["oghams"] = oghams


func can_use_ogham(skill_id: String) -> bool:
	"""Check if an Ogham can be activated right now."""
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return false
	var oghams: Dictionary = state.get("oghams", {})
	var cooldowns: Dictionary = oghams.get("skill_cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		return false
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter:
		var unlocked: Array = oghams.get("skills_unlocked", [])
		if not unlocked.has(skill_id):
			return false
	return true


func get_available_oghams() -> Array:
	"""Return list of Ogham IDs that can be used right now."""
	var available: Array = []
	for skill_id in MerlinConstants.OGHAM_FULL_SPECS:
		if can_use_ogham(skill_id):
			available.append(skill_id)
	return available


func _progress_mission(step: int) -> Dictionary:
	var run = state.get("run", {})
	var mission = run.get("mission", {})
	var old_progress: int = int(mission.get("progress", 0))
	var total: int = int(mission.get("total", 0))
	var new_progress: int = mini(old_progress + step, total)
	mission["progress"] = new_progress
	run["mission"] = mission
	state["run"] = run
	mission_progress.emit(new_progress, total)
	return {"ok": true, "progress": new_progress, "total": total, "complete": new_progress >= total}


func _resolve_choice(card: Dictionary, option: int, modulated_effects: Array = []) -> Dictionary:
	var run = state.get("run", {})

	if modulated_effects.is_empty():
		# Legacy path: controller did NOT pre-modulate → apply raw effects
		# Center is now FREE (no Souffle cost)
		var options = card.get("options", [])
		if option >= 0 and option < options.size():
			var chosen = options[option]
			var card_effects = chosen.get("effects", [])
			for effect in card_effects:
				_apply_effect(effect)
	else:
		# New path: controller already modulated effects (D20, talents, shields)
		# Souffle cost already handled by controller
		for effect in modulated_effects:
			_apply_effect(effect)

	# Update run state
	run["cards_played"] = int(run.get("cards_played", 0)) + 1

	# Record card text + choice in story_log for LLM context variety
	var story_log: Array = run.get("story_log", [])
	var card_text: String = str(card.get("text", "")).substr(0, 120)
	var options_arr: Array = card.get("options", [])
	var chosen_label: String = ""
	if option >= 0 and option < options_arr.size():
		chosen_label = str(options_arr[option].get("label", ""))
	story_log.append({"text": card_text, "choice": chosen_label, "card_idx": run["cards_played"]})
	# Keep only last 2 entries to bound token usage (~60 tokens saved)
	if story_log.size() > 2:
		story_log = story_log.slice(-2)
	run["story_log"] = story_log

	state["run"] = run

	# Update player profile based on choice
	_update_player_profile(option)

	# Tick Ogham cooldowns
	tick_cooldowns()

	# Biome passive only in legacy path (controller handles it in new path)
	if modulated_effects.is_empty():
		var biome_key: String = str(run.get("current_biome", ""))
		if not biome_key.is_empty():
			var passive: Dictionary = biomes.get_passive_effect(biome_key, int(run.get("cards_played", 0)))
			if not passive.is_empty():
				_apply_effect(passive)

	# Check promise deadlines
	_check_promise_deadlines()

	return {"ok": true, "option": option, "cards_played": run["cards_played"]}


func _apply_effect(effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"DAMAGE_LIFE":
			var amount: int = int(effect.get("amount", 0))
			_damage_life(amount)
		"HEAL_LIFE":
			var amount: int = int(effect.get("amount", 0))
			_heal_life(amount)
		"PROGRESS_MISSION":
			var step: int = int(effect.get("step", 1))
			_progress_mission(step)
		"ADD_KARMA":
			var amount: int = int(effect.get("amount", 0))
			var hidden = state["run"].get("hidden", {})
			hidden["karma"] = int(hidden.get("karma", 0)) + amount
			state["run"]["hidden"] = hidden
		"ADD_TENSION":
			var amount: int = int(effect.get("amount", 0))
			var hidden = state["run"].get("hidden", {})
			hidden["tension"] = clampi(int(hidden.get("tension", 0)) + amount, 0, 100)
			state["run"]["hidden"] = hidden
		"ADD_REPUTATION":
			var faction: String = str(effect.get("faction", ""))
			var rep_delta: int = int(effect.get("amount", MerlinConstants.FACTION_DELTA_MINOR))
			effects._apply_faction_reputation(state, faction, rep_delta)
		"ADD_ANAM":
			var anam_amount: int = int(effect.get("amount", MerlinConstants.ANAM_BASE_REWARD))
			effects._apply_add_anam(state, anam_amount)


func _update_player_profile(option: int) -> void:
	var hidden = state["run"].get("hidden", {})
	var profile = hidden.get("player_profile", {})

	match option:
		MerlinConstants.CardOption.LEFT:
			profile["prudence"] = int(profile.get("prudence", 0)) + 1
		MerlinConstants.CardOption.CENTER:
			# Center is neutral/wise - no profile change
			pass
		MerlinConstants.CardOption.RIGHT:
			profile["audace"] = int(profile.get("audace", 0)) + 1

	hidden["player_profile"] = profile
	state["run"]["hidden"] = hidden


func _check_run_end() -> Dictionary:
	var run = state.get("run", {})

	# Life essence = 0 → premature run end
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

	# Check for victory (mission complete + minimum cards played)
	var mission = run.get("mission", {})
	var cards_played: int = int(run.get("cards_played", 0))
	if int(mission.get("progress", 0)) >= int(mission.get("total", 0)) and int(mission.get("total", 0)) > 0 and cards_played >= MerlinConstants.MIN_CARDS_FOR_VICTORY:
		var victory_type: String = _get_victory_type()
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

	return {"ended": false}


func _get_victory_type() -> String:
	# Aspect system removed — victory type based on life/karma
	var hidden: Dictionary = state.get("run", {}).get("hidden", {})
	var karma: int = int(hidden.get("karma", 0))
	if karma >= 5:
		return "harmonie"
	elif karma <= -5:
		return "victoire_amere"
	else:
		return "prix_paye"


func _handle_run_end(end_check: Dictionary) -> void:
	var meta = state.get("meta", {})
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["total_cards_played"] = int(meta.get("total_cards_played", 0)) + int(end_check.get("cards_played", 0))

	var ending = end_check.get("ending", {})
	var ending_title = ending.get("title", "")
	var endings_seen = meta.get("endings_seen", [])
	if not endings_seen.has(ending_title):
		endings_seen.append(ending_title)
	meta["endings_seen"] = endings_seen
	state["meta"] = meta

	# Calculate and apply run rewards (Anam)
	var rewards: Dictionary = calculate_run_rewards(end_check)
	apply_run_rewards(rewards)
	end_check["rewards"] = rewards

	_log_transition("triade_run_end", end_check)
	run_ended.emit(end_check)


func _check_promise_deadlines() -> void:
	var run: Dictionary = state.get("run", {})
	var promises: Array = run.get("active_promises", [])
	var current_day: int = int(run.get("day", 1))
	var broken_count: int = 0

	for promise in promises:
		if str(promise.get("status", "")) != "active":
			continue
		var deadline: int = int(promise.get("deadline_day", 0))
		if deadline > 0 and current_day > deadline:
			promise["status"] = "broken"
			broken_count += 1

	if broken_count > 0:
		run["active_promises"] = promises
		state["run"] = run
		# Apply penalties for broken promises
		for i in broken_count:
			_apply_effect({"type": "ADD_KARMA", "amount": -15})
			_apply_effect({"type": "ADD_TENSION", "amount": 10})


# ═══════════════════════════════════════════════════════════════════════════════
# WORLD MAP PROGRESSION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _map_update_gauges(action: Dictionary) -> Dictionary:
	var delta: Dictionary = action.get("delta", {})
	if delta.is_empty():
		return {"ok": false, "error": "No delta provided"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var gauges: Dictionary = map_prog.get("gauges", {})
	var gauge_sys := MerlinGaugeSystem.new()
	var new_gauges: Dictionary = gauge_sys.apply_delta(gauges, delta)
	map_prog["gauges"] = new_gauges
	state["map_progression"] = map_prog
	emit_signal("gauges_changed", new_gauges)
	return {"ok": true, "gauges": new_gauges}


func _map_complete_biome(action: Dictionary) -> Dictionary:
	var biome_key: String = str(action.get("biome_key", ""))
	if biome_key.is_empty():
		return {"ok": false, "error": "No biome_key"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var completed: Array = map_prog.get("completed_biomes", [])
	if not biome_key in completed:
		completed.append(biome_key)
	map_prog["completed_biomes"] = completed
	# Update tier progress
	var tree := MerlinBiomeTree.new()
	var tier: int = tree.get_tier(biome_key)
	var current_tier: int = int(map_prog.get("tier_progress", 1))
	if tier > current_tier:
		map_prog["tier_progress"] = tier
	state["map_progression"] = map_prog
	return {"ok": true, "completed_biomes": completed}


func _map_collect_item(action: Dictionary) -> Dictionary:
	var item_id: String = str(action.get("item_id", ""))
	if item_id.is_empty():
		return {"ok": false, "error": "No item_id"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var items: Array = map_prog.get("items_collected", [])
	if not item_id in items:
		items.append(item_id)
	map_prog["items_collected"] = items
	state["map_progression"] = map_prog
	return {"ok": true, "items_collected": items}


func _map_add_reputation(action: Dictionary) -> Dictionary:
	var rep_id: String = str(action.get("reputation_id", ""))
	if rep_id.is_empty():
		return {"ok": false, "error": "No reputation_id"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var reps: Array = map_prog.get("reputations", [])
	if not rep_id in reps:
		reps.append(rep_id)
	map_prog["reputations"] = reps
	state["map_progression"] = map_prog
	return {"ok": true, "reputations": reps}


func _map_select_biome(action: Dictionary) -> Dictionary:
	var biome_key: String = str(action.get("biome_key", ""))
	if biome_key.is_empty():
		return {"ok": false, "error": "No biome_key"}
	var map_prog: Dictionary = state.get("map_progression", {})
	map_prog["current_biome"] = biome_key
	var visited: Array = map_prog.get("visited_biomes", [])
	if not biome_key in visited:
		visited.append(biome_key)
	map_prog["visited_biomes"] = visited
	state["map_progression"] = map_prog
	return {"ok": true, "current_biome": biome_key}


func _log_transition(kind: String, data: Dictionary) -> void:
	var transition_log: Array = state.get("transition_log", [])
	var entry = {
		"type": kind,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	transition_log.append(entry)
	state["transition_log"] = transition_log
	emit_signal("transition_logged", entry)


func _emit_state_changed() -> void:
	emit_signal("state_changed", state)


# ═══════════════════════════════════════════════════════════════════════════════
# CONVENIENCE GETTERS
# ═══════════════════════════════════════════════════════════════════════════════


# Common getters
func get_life_essence() -> int:
	return int(state.get("run", {}).get("life_essence", MerlinConstants.LIFE_ESSENCE_START))


func get_mission() -> Dictionary:
	return state.get("run", {}).get("mission", {}).duplicate()


func get_hidden_data() -> Dictionary:
	return state.get("run", {}).get("hidden", {}).duplicate()


func is_run_active() -> bool:
	return bool(state.get("run", {}).get("active", false))


func get_mode() -> String:
	return str(state.get("mode", "triade"))


# World Map getters
func get_map_progression() -> Dictionary:
	return state.get("map_progression", {}).duplicate(true)


func get_map_gauges() -> Dictionary:
	return state.get("map_progression", {}).get("gauges", {}).duplicate()


func get_map_gauge(gauge_key: String) -> int:
	return int(state.get("map_progression", {}).get("gauges", {}).get(gauge_key, 0))


func get_current_biome() -> String:
	return str(state.get("map_progression", {}).get("current_biome", "foret_broceliande"))


func get_completed_biomes() -> Array:
	return state.get("map_progression", {}).get("completed_biomes", []).duplicate()


func get_cards_played() -> int:
	return int(state.get("run", {}).get("cards_played", 0))


# ═══════════════════════════════════════════════════════════════════════════════
# TALENT TREE — Arbre de Vie (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

func is_talent_active(node_id: String) -> bool:
	var unlocked: Array = state.get("meta", {}).get("talent_tree", {}).get("unlocked", [])
	return unlocked.has(node_id)


func can_unlock_talent(node_id: String) -> bool:
	if not MerlinConstants.TALENT_NODES.has(node_id):
		return false
	if is_talent_active(node_id):
		return false

	var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]

	# Check prerequisites
	for prereq in node.get("prerequisites", []):
		if not is_talent_active(prereq):
			return false

	# Check Anam cost
	var cost: int = int(node.get("cost", 0))
	var anam: int = int(state.get("meta", {}).get("anam", 0))
	if anam < cost:
		return false
	return true


func unlock_talent(node_id: String) -> Dictionary:
	if not can_unlock_talent(node_id):
		return {"ok": false, "error": "Cannot unlock"}

	var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
	var cost: int = int(node.get("cost", 0))

	# Spend Anam
	state["meta"]["anam"] = int(state.get("meta", {}).get("anam", 0)) - cost

	# Add to unlocked list
	state["meta"]["talent_tree"]["unlocked"].append(node_id)

	# Auto-save profile
	save_system.save_profile(state.get("meta", {}))

	state_changed.emit(state)
	return {"ok": true, "node_id": node_id, "name": node.get("name", "")}


func get_unlocked_talents() -> Array:
	return state.get("meta", {}).get("talent_tree", {}).get("unlocked", []).duplicate()


func get_affordable_talents() -> Array:
	var affordable: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		if can_unlock_talent(node_id):
			affordable.append(node_id)
	return affordable


# ═══════════════════════════════════════════════════════════════════════════════
# RUN REWARDS — Anam (monnaie unique cross-run)
# ═══════════════════════════════════════════════════════════════════════════════

func calculate_run_rewards(run_data: Dictionary) -> Dictionary:
	var anam: int = MerlinConstants.ANAM_BASE_REWARD

	var is_victory: bool = bool(run_data.get("victory", false))
	if is_victory:
		anam += MerlinConstants.ANAM_VICTORY_BONUS

	# Per minigame won
	anam += int(run_data.get("minigames_won", 0)) * MerlinConstants.ANAM_PER_MINIGAME

	# Per ogham used
	anam += int(run_data.get("oghams_used", 0)) * MerlinConstants.ANAM_PER_OGHAM

	# Faction honore bonus (+5 per faction >= 80)
	var faction_rep: Dictionary = state.get("meta", {}).get("faction_rep", {})
	for faction in faction_rep:
		if float(faction_rep[faction]) >= 80.0:
			anam += MerlinConstants.ANAM_FACTION_HONORE

	# Partial: death before 25 cards = /4
	var cards_played: int = int(run_data.get("cards_played", 0))
	if not is_victory and cards_played < MerlinConstants.MIN_CARDS_FOR_VICTORY:
		anam = int(anam / 4.0)

	# Talent modifiers
	if _get_talent_modifier("double_anam_rewards"):
		anam *= 2
	if _get_talent_modifier("bonus_anam_per_run"):
		anam += 3
	if _get_talent_modifier("low_life_bonus") and int(run_data.get("life_at_end", 100)) <= 25:
		anam = int(anam * 1.5)
	if _get_talent_modifier("new_game_plus"):
		anam = int(anam * 1.5)

	return {"anam": anam}


func apply_run_rewards(rewards: Dictionary) -> void:
	var meta: Dictionary = state.get("meta", {})
	meta["anam"] = int(meta.get("anam", 0)) + int(rewards.get("anam", 0))
	state["meta"] = meta
	save_system.save_profile(meta)
	state_changed.emit(state)


