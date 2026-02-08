extends Node
class_name DruStore

signal state_changed(state: Dictionary)
signal phase_changed(phase: String)
signal transition_logged(entry: Dictionary)

const VERSION := "0.1.0"

var state: Dictionary = {}
var rng: DruRng = DruRng.new()
var save_system: DruSaveSystem = DruSaveSystem.new()
var effects: DruEffectEngine = DruEffectEngine.new()
var action_resolver: DruActionResolver = DruActionResolver.new()
var minigames: DruMiniGameSystem = DruMiniGameSystem.new()
var map_system: DruMapSystem = DruMapSystem.new()
var llm: DruLlmAdapter = DruLlmAdapter.new()
var events: DruEventSystem = DruEventSystem.new()
var combat: DruCombatSystem = DruCombatSystem.new()

func _ready() -> void:
	minigames.set_rng(rng)
	events.setup(action_resolver, minigames, effects, llm)
	combat.setup(action_resolver, minigames, effects, rng)
	state = build_default_state()
	_emit_state_changed()


func dispatch(action: Dictionary) -> Dictionary:
	var prev_phase: String = str(state.get("phase", ""))
	var result: Dictionary = _reduce(action)
	if prev_phase != state.get("phase", ""):
		emit_signal("phase_changed", state.get("phase", ""))
	_emit_state_changed()
	return result


func build_default_state() -> Dictionary:
	var resources: Dictionary = {
		"Vigueur": 2,
		"Concentration": 2,
		"Materiel": 2,
		"Faveur": 0,
		"Nourriture": 1,
	}
	var resource_caps: Dictionary = {
		"Vigueur": 9,
		"Concentration": 9,
		"Materiel": 9,
		"Faveur": 9,
		"Nourriture": 9,
	}
	var essence: Dictionary = {}
	for element in DruConstants.ELEMENTS:
		essence[element] = 0
	return {
		"version": VERSION,
		"phase": "title",
		"timestamp": int(Time.get_unix_time_from_system()),
		"run": {
			"active": false,
			"resources": resources,
			"resource_caps": resource_caps,
			"floor": 0,
			"map_seed": 0,
			"map": [],
			"path": [],
			"posture": "Prudence",
			"momentum": 0,
			"fail_streak": 0,
			"difficulty_mod_next": 0,
			"force_soft_success": false,
			"next_node_override": "",
			"map_reveals": [],
			"inventory": {},
			"relics": [],
		},
		"bestiole": {
			"name": "Bestiole",
			"hp": 100,
			"max_hp": 100,
			"stats": {"power": 10, "spirit": 10, "finesse": 10},
			"needs": {"Hunger": 50, "Energy": 50, "Hygiene": 50, "Mood": 50, "Stress": 0},
			"tendency": {"Wild": 0, "Light": 0, "Discipline": 0},
			"xp": 0,
			"bond_xp": 0,
			"evolve_ready": false,
		},
		"meta": {
			"essence": essence,
			"ogham_fragments": 0,
			"liens": 0,
			"achievements": {},
			"ach_unlocked": [],
			"unlocks": [],
			"packages": [],
			"active_package": "",
			"unlocked_evolutions": [],
		},
		"combat": {
			"enemy": {},
			"enemy_intent": {},
			"player_statuses": [],
			"enemy_statuses": [],
			"player_buffs": [],
			"enemy_buffs": [],
		},
		"story_log": [],
		"effect_log": [],
		"transition_log": [],
	}


func snapshot_for_save() -> Dictionary:
	var data: Dictionary = state.duplicate(true)
	data["timestamp"] = int(Time.get_unix_time_from_system())
	return data


func _reduce(action: Dictionary) -> Dictionary:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"SET_PHASE":
			state["phase"] = action.get("phase", state.get("phase", "title"))
			_log_transition("phase", {"phase": state["phase"]})
			return {"ok": true}
		"SET_SEED":
			var seed: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed)
			state["run"]["map_seed"] = seed
			return {"ok": true, "seed": seed}
		"START_RUN":
			var seed: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed)
			var run: Dictionary = state["run"]
			run["active"] = true
			run["floor"] = 0
			run["map_seed"] = seed
			run["path"] = []
			run["map"] = map_system.generate_map(int(action.get("floors", 8)), rng, action.get("map_config", {}))
			state["run"] = run
			state["phase"] = "map"
			_log_transition("run_start", {"seed": seed})
			return {"ok": true}
		"END_RUN":
			state["run"]["active"] = false
			state["phase"] = "end"
			_log_transition("run_end", {"victory": action.get("victory", false)})
			return {"ok": true}
		"APPLY_EFFECTS":
			var result: Dictionary = effects.apply_effects(state, action.get("effects", []), action.get("source", "SYSTEM"))
			return {"ok": true, "result": result}
		"RUN_EVENT":
			var result: Dictionary = events.run_scene(
				action.get("scene", {}),
				action.get("verb", ""),
				int(action.get("choice_index", 0)),
				state
			)
			return result
		"COMBAT_ENTER":
			var result: Dictionary = combat.enter(action.get("enemy", {}), state)
			state["phase"] = "combat"
			return {"ok": true, "combat": result}
		"COMBAT_STEP":
			return combat.step(action.get("verb", ""), action.get("move", {}), state)
		"COMBAT_EXIT":
			combat.exit(state)
			state["phase"] = "map"
			return {"ok": true}
		"SAVE_SLOT":
			var slot: int = int(action.get("slot", 1))
			var ok: bool = save_system.save_slot(slot, snapshot_for_save())
			return {"ok": ok}
		"LOAD_SLOT":
			var slot: int = int(action.get("slot", 1))
			var loaded: Dictionary = save_system.load_slot(slot, build_default_state())
			if loaded.is_empty():
				return {"ok": false}
			state = loaded
			return {"ok": true}
		_:
			return {"ok": false, "error": "Unknown action"}


func _log_transition(kind: String, data: Dictionary) -> void:
	var log: Array = state.get("transition_log", [])
	var entry = {
		"type": kind,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	log.append(entry)
	state["transition_log"] = log
	emit_signal("transition_logged", entry)


func _emit_state_changed() -> void:
	emit_signal("state_changed", state)
