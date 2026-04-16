## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Store — Central State Management
## ═══════════════════════════════════════════════════════════════════════════════
## Redux-like state management for Merlin game.
## Delegates to: StoreFactions, StoreOghams, StoreTalents, StoreRun, StoreMap.
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
signal gauges_changed(gauges: Dictionary)
signal trust_changed(old_value: int, new_value: int, tier: String)

const VERSION := "0.4.0"  # Updated for World Map gauge system

# SEC-4: Allowlist for valid game phases (prevents arbitrary phase injection)
const VALID_PHASES: Array[String] = ["title", "card", "end"]

# --- SYSTEMS ---

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

# --- MERLIN OMNISCIENT SYSTEM (MOS) ---
var merlin: MerlinOmniscient = null

# --- INITIALIZATION ---

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

# --- MERLIN OMNISCIENT INITIALIZATION ---

func _init_merlin_omniscient() -> void:
	var script_path: String = "res://addons/merlin_ai/merlin_omniscient.gd"
	if ResourceLoader.exists(script_path):
		var script: GDScript = load(script_path) as GDScript
		if script:
			merlin = script.new()
			merlin.setup(self)
			add_child(merlin)
			print("[MerlinStore] MERLIN OMNISCIENT SYSTEM initialized")
			return
	print("[MerlinStore] MerlinOmniscient not available - using legacy LLM")

func get_merlin() -> MerlinOmniscient:
	return merlin

func is_merlin_active() -> bool:
	return merlin != null

func get_scenario_manager() -> MerlinScenarioManager:
	return scenarios

func get_event_adapter() -> EventAdapter:
	if merlin and merlin.event_adapter:
		return merlin.event_adapter
	return null

func _deferred_wire_merlin_ai() -> void:
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		llm.set_merlin_ai(merlin_ai_node)
		print("[MerlinStore] MerlinAI wired to LLM adapter (deferred)")

# --- STATE BUILDING ---

func build_default_state() -> Dictionary:
	return {
		"version": VERSION,
		"phase": "title",
		"mode": "narrative",
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
			"event_locks": [],
			"event_rerolls_used": 0,
			"story_log": [],
			"active_tags": [],
			"active_promises": [],
			"effect_modifier": {},
			"hidden": {
				"karma": 0,
				"tension": 0,
				"player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0},
				"resonances_active": [],
				"narrative_debt": [],
			},
			"faction_context": {
				"dominant": "",
				"tiers": {},
				"active_effects": [],
			},
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
			"run_graph": {},
		},
		"oghams": {
			"skills_unlocked": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skills_equipped": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skill_cooldowns": {},
		},
		"meta": {
			"anam": 0,
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
			"talent_tree": {
				"unlocked": [],
			},
		},
		"map_progression": {
			"gauges": MerlinGaugeSystem.build_default_gauges(),
			"current_biome": "foret_broceliande",
			"completed_biomes": [],
			"visited_biomes": ["foret_broceliande"],
			"items_collected": [],
			"reputations": [],
			"tier_progress": 1,
		},
		"flags": {},
		"story_log": [],
		"effect_log": [],
		"transition_log": [],
	}

# --- DISPATCH (Action Handler) ---

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
		# --- CORE ACTIONS ---
		"SET_PHASE":
			var phase_value: String = str(action.get("phase", state.get("phase", "title")))
			if phase_value not in VALID_PHASES:
				push_warning("[MerlinStore] SET_PHASE rejected unknown phase: %s" % phase_value)
				return {"ok": false, "error": "invalid_phase"}
			state["phase"] = phase_value
			_log_transition("phase", {"phase": state["phase"]})
			return {"ok": true}

		"SET_SEED":
			var seed: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed)
			state["run"]["map_seed"] = seed
			return {"ok": true, "seed": seed}

		# --- RUN ACTIONS ---
		"START_RUN":
			var seed_val: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed_val)
			StoreRun.init_run(state, rng, scenarios)
			_reset_ai_for_new_run()
			state["run"]["map_seed"] = seed_val
			var biome_key: String = str(action.get("biome", MerlinConstants.BIOME_DEFAULT))
			if biome_key not in MerlinConstants.BIOMES:
				push_warning("[MerlinStore] START_RUN rejected unknown biome: %s" % biome_key)
				biome_key = MerlinConstants.BIOME_DEFAULT
			state["run"]["current_biome"] = biome_key
			state["phase"] = "card"
			state["mode"] = "run"
			var season: String = StoreRun.init_calendar_context(state, merlin)
			season_changed.emit(season)
			_log_transition("run_start", {"seed": seed_val, "biome": biome_key})
			if merlin != null:
				merlin.on_run_start()
				if merlin.event_adapter:
					merlin.event_adapter.reset_for_new_run()
			return {"ok": true, "biome": biome_key}

		"GET_CARD":
			var card: Dictionary = {}
			if merlin != null and is_instance_valid(merlin):
				print("[MerlinStore] GET_CARD: using MerlinOmniscient")
				var mos_card = await merlin.generate_card(state)
				if mos_card is Dictionary and not mos_card.is_empty():
					card = mos_card
				else:
					print("[MerlinStore] MOS returned empty, controller will retry LLM")
			elif llm != null and llm.is_llm_ready():
				print("[MerlinStore] GET_CARD: using direct LLM")
				var ctx: Dictionary = state.get("run", {}).duplicate()
				var llm_result: Dictionary = await llm.generate_card(ctx)
				if llm_result.get("ok", false) and llm_result.has("card"):
					card = llm_result["card"]
				else:
					print("[MerlinStore] Direct LLM failed, controller will retry")
			else:
				push_warning("[MerlinStore] GET_CARD: no LLM available — controller must retry")
			if card.is_empty() or not card.has("options") or card.get("options", []).size() < 2:
				return {"ok": false, "error": "llm_no_card"}
			return {"ok": true, "card": card}

		"RESOLVE_CHOICE":
			var card: Dictionary = action.get("card", {})
			var option: int = int(action.get("option", MerlinConstants.CardOption.LEFT))
			var mod_effects: Array = action.get("modulated_effects", [])
			var result: Dictionary = StoreRun.resolve_choice(state, card, option, mod_effects, _apply_effect, biomes)
			if result["ok"]:
				if merlin != null:
					merlin.record_choice(card, option, state)
				card_resolved.emit(card.get("id", ""), option)
				_trigger_autosave()
				var end_check: Dictionary = StoreRun.check_run_end(state)
				if end_check["ended"]:
					state["run"]["active"] = false
					state["phase"] = "end"
					StoreRun.handle_run_end(state, end_check, save_system)
					_log_transition("run_end", end_check)
					run_ended.emit(end_check)
					if merlin != null:
						merlin.on_run_end(end_check)
					return {"ok": true, "run_ended": true, "ending": end_check}
				else:
					var run_ref: Dictionary = state.get("run", {})
					run_ref["tension_zone"] = str(end_check.get("tension_zone", "none"))
					run_ref["convergence_zone"] = end_check.get("convergence_zone", false)
					state["run"] = run_ref
			return result

		"PROGRESS_MISSION":
			var step: int = int(action.get("step", 1))
			var result: Dictionary = StoreRun.progress_mission(state, step)
			if result["ok"]:
				mission_progress.emit(result["progress"], result["total"])
			return result

		"USE_OGHAM":
			var skill_id: String = str(action.get("skill_id", ""))
			return _use_ogham(skill_id)

		"END_RUN":
			var end_check: Dictionary = StoreRun.check_run_end(state)
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
			StoreRun.handle_run_end(state, end_check, save_system)
			_log_transition("run_end", end_check)
			run_ended.emit(end_check)
			if merlin != null:
				merlin.on_run_end(end_check)
			return {"ok": true, "ending": end_check}

		# --- MAP ACTIONS (Phase 37 — STS-like world map) ---
		"SET_RUN_GRAPH":
			var graph_data: Dictionary = action.get("graph", {})
			state["run"]["run_graph"] = graph_data
			return {"ok": true}

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
						var next_floor: int = int(node.get("floor", 0)) + 1
						if next_floor < map_data.size() and map_data[next_floor] is Array:
							for n in map_data[next_floor]:
								if n is Dictionary:
									n["revealed"] = true
						return {"ok": true, "node": node}
			return {"ok": false, "error": "Node not found: " + node_id}

		# --- SAVE/LOAD ---
		"SAVE_PROFILE":
			var ok: bool = save_system.save_profile(state.get("meta", {}))
			return {"ok": ok}

		"LOAD_PROFILE":
			var meta: Dictionary = save_system.load_profile()
			if meta.is_empty():
				return {"ok": false}
			state["meta"] = meta
			return {"ok": true}

		# --- LIFE ESSENCE ACTIONS (Phase 43) ---
		"DAMAGE_LIFE":
			var amount: int = int(action.get("amount", 1))
			return _damage_life(amount)

		"HEAL_LIFE":
			var amount: int = int(action.get("amount", 1))
			return _heal_life(amount)

		"FAVEUR_ADD":
			var amount: int = int(action.get("amount", MerlinConstants.FAVEURS_PER_MINIGAME_PLAY))
			return _add_faveur(amount)

		# --- WORLD MAP PROGRESSION ACTIONS ---
		"MAP_UPDATE_GAUGES":
			var result: Dictionary = StoreMap.update_gauges(state, action)
			if result["ok"]:
				emit_signal("gauges_changed", result["gauges"])
			return result

		"MAP_COMPLETE_BIOME":
			return StoreMap.complete_biome(state, action)

		"MAP_COLLECT_ITEM":
			return StoreMap.collect_item(state, action)

		"MAP_ADD_REPUTATION":
			return StoreMap.add_reputation(state, action)

		"MAP_SELECT_BIOME":
			return StoreMap.select_biome(state, action)

		# --- TALENT TREE ACTIONS ---
		"UNLOCK_TALENT":
			var node_id: String = str(action.get("node_id", ""))
			var unlocked: Array = state.get("meta", {}).get("talent_tree", {}).get("unlocked", [])
			var anam: int = int(state.get("meta", {}).get("anam", 0))
			var result: Dictionary = MerlinTalentSystem.unlock_talent(node_id, unlocked, anam)
			if result.get("ok", false):
				state["meta"]["talent_tree"]["unlocked"] = result["new_unlocked"]
				state["meta"]["anam"] = result["new_anam"]
				save_system.save_profile(state.get("meta", {}))
				state_changed.emit(state)
			return result

		# --- KARMA / TENSION / EFFECTS / SKILL ---
		"ADD_KARMA":
			var value: int = int(action.get("value", 0))
			var run: Dictionary = state.get("run", {})
			var old_karma: int = int(run.get("karma", 0))
			var new_karma: int = clampi(old_karma + value, -20, 20)
			run["karma"] = new_karma
			state["run"] = run
			return {"ok": true, "karma": new_karma, "delta": new_karma - old_karma}

		"ADD_TENSION":
			var value: float = float(action.get("value", 0.0))
			var run: Dictionary = state.get("run", {})
			var old_tension: float = float(run.get("tension", 0.0))
			var new_tension: float = clampf(old_tension + value, 0.0, 1.0)
			run["tension"] = new_tension
			state["run"] = run
			return {"ok": true, "tension": new_tension, "delta": new_tension - old_tension}

		"APPLY_EFFECTS":
			var effect_list: Array = action.get("effects", [])
			if effect_list.is_empty():
				return {"ok": false, "error": "No effects provided"}
			var source: String = str(action.get("source", "DISPATCH"))
			var result: Dictionary = effects.apply_effects(state, effect_list, source)
			return {"ok": true, "applied": result.get("applied", []), "rejected": result.get("rejected", [])}

		"USE_SKILL":
			var skill_id: String = str(action.get("skill_id", ""))
			if skill_id.is_empty():
				return {"ok": false, "error": "No skill_id provided"}
			return _use_ogham(skill_id)

		_:
			return {"ok": false, "error": "Unknown action"}

# --- HELPERS ---

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
	var run: Dictionary = state.get("run", {})
	if bool(run.get("active", false)):
		var run_snapshot: Dictionary = run.duplicate(true)
		run_snapshot["biome"] = str(run.get("current_biome", ""))
		run_snapshot["card_index"] = int(run.get("cards_played", 0))
		save_system.save_run_state(run_snapshot)
	if merlin:
		merlin.save_all()

func _restore_ai_state() -> void:
	if merlin:
		merlin.reload_registries()
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node and merlin_ai_node.has_method("load_session_history"):
		merlin_ai_node.load_session_history()
	scenarios.load_state(state.get("scenario_state", {}))

func _reset_ai_for_new_run() -> void:
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node and merlin_ai_node.get("session_contexts") != null:
		merlin_ai_node.session_contexts.clear()

# --- LIFE / FAVEUR — Kept in main store (emits signals directly) ---

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

# --- EFFECT APPLICATION — Central dispatcher for individual effects ---

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
			StoreRun.progress_mission(state, step)
		"ADD_KARMA":
			var amount: int = int(effect.get("amount", 0))
			var hidden: Dictionary = state["run"].get("hidden", {})
			hidden["karma"] = clampi(int(hidden.get("karma", 0)) + amount, -20, 20)
			state["run"]["hidden"] = hidden
		"ADD_TENSION":
			var amount: int = int(effect.get("amount", 0))
			var hidden: Dictionary = state["run"].get("hidden", {})
			hidden["tension"] = clampi(int(hidden.get("tension", 0)) + amount, 0, 100)
			state["run"]["hidden"] = hidden
		"ADD_REPUTATION":
			var faction: String = str(effect.get("faction", ""))
			var rep_delta: int = int(effect.get("amount", MerlinConstants.FACTION_DELTA_MINOR))
			var old_rep: float = float(state.get("meta", {}).get("faction_rep", {}).get(faction, MerlinConstants.FACTION_SCORE_START))
			var effect_str: String = "ADD_REPUTATION:%s:%d" % [faction, rep_delta]
			var result: Dictionary = effects.apply_effects(state, [effect_str], "RESOLVE_CHOICE")
			if not result.get("applied", []).is_empty():
				var new_val: float = float(state.get("meta", {}).get("faction_rep", {}).get(faction, 0))
				var actual_delta: float = new_val - old_rep
				reputation_changed.emit(faction, new_val, actual_delta)
		"ADD_ANAM":
			var anam_amount: int = int(effect.get("amount", MerlinConstants.ANAM_BASE_REWARD))
			effects._apply_add_anam(state, anam_amount)

# --- OGHAM SYSTEM — Delegates to StoreOghams ---

func _use_ogham(skill_id: String) -> Dictionary:
	var result: Dictionary = StoreOghams.use_ogham(state, skill_id)
	if result.get("ok", false):
		ogham_activated.emit(skill_id, str(result.get("effect", "")))
		var spec: Dictionary = result.get("spec", {})
		StoreOghams.apply_ogham_effect(skill_id, spec, state, _heal_life)
		result.erase("spec")
	return result

func tick_cooldowns() -> void:
	StoreOghams.tick_cooldowns(state)

func can_use_ogham(skill_id: String) -> bool:
	return StoreOghams.can_use_ogham(state, skill_id)

func get_available_oghams() -> Array:
	return StoreOghams.get_available_oghams(state)

func _on_run_ended(ending: Dictionary) -> void:
	pass  # Handled in RESOLVE_CHOICE

# --- LOGGING ---

func _log_transition(kind: String, data: Dictionary) -> void:
	var transition_log: Array = state.get("transition_log", [])
	var entry: Dictionary = {
		"type": kind,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	transition_log.append(entry)
	state["transition_log"] = transition_log
	emit_signal("transition_logged", entry)

func _emit_state_changed() -> void:
	emit_signal("state_changed", state)

# --- CONVENIENCE GETTERS ---

## Returns the full saved profile for biome skeleton generation context.
## Provides biome_runs, fins_vues, oghams — used by MerlinSkeletonGenerator.
## Director decision 2026-04-14: always return disk-synced load_profile().
func get_save_data() -> Dictionary:
	return save_system.load_profile()


func get_life_essence() -> int:
	return int(state.get("run", {}).get("life_essence", MerlinConstants.LIFE_ESSENCE_START))

func get_mission() -> Dictionary:
	return state.get("run", {}).get("mission", {}).duplicate()

func get_hidden_data() -> Dictionary:
	return state.get("run", {}).get("hidden", {}).duplicate()

func is_run_active() -> bool:
	return bool(state.get("run", {}).get("active", false))

func get_mode() -> String:
	return str(state.get("mode", "narrative"))

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

# --- TALENT TREE — Delegates to StoreTalents ---

func is_talent_active(node_id: String) -> bool:
	return StoreTalents.is_talent_active(state, node_id)

func can_unlock_talent(node_id: String) -> bool:
	return StoreTalents.can_unlock_talent(state, node_id)

func unlock_talent(node_id: String) -> Dictionary:
	var result: Dictionary = StoreTalents.unlock_talent(state, node_id, save_system)
	if result.get("ok", false):
		state_changed.emit(state)
	return result

func get_unlocked_talents() -> Array:
	return StoreTalents.get_unlocked_talents(state)

func get_affordable_talents() -> Array:
	return StoreTalents.get_affordable_talents(state)

# --- RUN REWARDS — Delegates to StoreRun ---

func calculate_run_rewards(run_data: Dictionary) -> Dictionary:
	return StoreRun.calculate_run_rewards(state, run_data)

func apply_run_rewards(rewards: Dictionary) -> void:
	StoreRun.apply_run_rewards(state, rewards, save_system)
	state_changed.emit(state)

# --- MATURITY / BIOME UNLOCK — Delegates to StoreRun ---

func calculate_maturity_score() -> int:
	return StoreRun.calculate_maturity_score(state)

func can_unlock_biome(biome_id: String) -> bool:
	return StoreRun.can_unlock_biome(state, biome_id)

func get_unlockable_biomes() -> Array:
	return StoreRun.get_unlockable_biomes(state)

# --- TRUST MERLIN — Delegates to StoreFactions ---

func update_trust_merlin(delta: int) -> void:
	var result: Dictionary = StoreFactions.update_trust(state, delta)
	if not result.is_empty():
		trust_changed.emit(result["old"], result["new"], result["tier"])
		state_changed.emit(state)

func get_trust_tier() -> String:
	return StoreFactions.get_trust_tier(state)

# --- OGHAM ECONOMY — Delegates to StoreOghams ---

func get_ogham_cost(ogham_id: String) -> int:
	return StoreOghams.get_ogham_cost(state, ogham_id)

func apply_ogham_discount(ogham_id: String) -> void:
	StoreOghams.apply_ogham_discount(state, ogham_id)

func buy_ogham(ogham_id: String) -> Dictionary:
	var result: Dictionary = StoreOghams.buy_ogham(state, ogham_id, save_system)
	if result.get("ok", false):
		state_changed.emit(state)
	return result

# --- IN-GAME PERIODS — Delegates to StoreFactions (static) ---

static func get_period(card_index: int) -> String:
	return StoreFactions.get_period(card_index)

static func get_period_bonus(card_index: int, faction: String) -> float:
	return StoreFactions.get_period_bonus(card_index, faction)

# --- BIOME AFFINITY — Delegates to StoreFactions (static) ---

static func get_biome_affinity_bonus(biome_id: String, ogham_id: String) -> Dictionary:
	return StoreFactions.get_biome_affinity_bonus(biome_id, ogham_id)
