## ═══════════════════════════════════════════════════════════════════════════════
## GameFlowController — Scene integration layer for the full game loop
## ═══════════════════════════════════════════════════════════════════════════════
## Manages the lifecycle: Menu → Hub → Run → EndScreen → Hub (repeat).
## Connects signals between HubScreen, Run3DController, and EndRunScreen.
## Reads/writes profile via MerlinStore and MerlinSaveSystem.
## Uses PixelTransition (autoload) for fades between phases.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name GameFlowController

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal phase_changed(old_phase: String, new_phase: String)
signal game_quit_requested

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE ENUM
# ═══════════════════════════════════════════════════════════════════════════════

enum GamePhase {
	MENU,
	HUB,
	RUN,
	END_SCREEN,
	TALENT_TREE,
}

const PHASE_NAMES: Dictionary = {
	GamePhase.MENU: "menu",
	GamePhase.HUB: "hub",
	GamePhase.RUN: "run",
	GamePhase.END_SCREEN: "end_screen",
	GamePhase.TALENT_TREE: "talent_tree",
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCENE PATHS
# ═══════════════════════════════════════════════════════════════════════════════

const SCENE_HUB: String = "res://scenes/MerlinCabinHub.tscn"
const SCENE_RUN: String = "res://scenes/Run3D.tscn"
const SCENE_END: String = "res://scenes/EndRunScreen.tscn"
const SCENE_MENU: String = "res://scenes/Menu3DPC.tscn"
const SCENE_TALENT_TREE: String = "res://scenes/TalentTree.tscn"

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _current_phase: int = GamePhase.MENU
var _store: MerlinStore = null
var _save_system: MerlinSaveSystem = null
var _transition_manager: TransitionManager = null
var _last_run_data: Dictionary = {}

# Active screen references (set during wiring, cleared on phase exit)
# NOTE: _hub_screen is duck-typed (Node) so any hub implementation that emits
# `run_requested(biome_id, oghams)`, `talent_tree_requested()`, and
# `quit_requested()` can register itself — including MerlinCabinHub.
var _hub_screen: Node = null
var _run_controller: Run3DController = null
var _end_screen: EndRunScreen = null


# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-INIT (autoload _ready)
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# MerlinStore is added to root deferred by GameManager, so wait one frame.
	call_deferred("_auto_setup")


func _auto_setup() -> void:
	if _store != null:
		return
	var store_node: Node = get_node_or_null("/root/MerlinStore")
	if store_node is MerlinStore:
		var store: MerlinStore = store_node as MerlinStore
		setup(store, store.save_system)
		print("[GameFlow] Auto-setup complete (store + save_system)")
	else:
		# MerlinStore not yet available — retry next frame.
		get_tree().process_frame.connect(_auto_setup, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(store: MerlinStore, save_system: MerlinSaveSystem,
		transition_manager: TransitionManager = null) -> void:
	_store = store
	_save_system = save_system
	_transition_manager = transition_manager


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func get_current_phase() -> int:
	return _current_phase


func get_current_phase_name() -> String:
	return PHASE_NAMES.get(_current_phase, "unknown")


func is_in_phase(phase: int) -> bool:
	return _current_phase == phase


# ═══════════════════════════════════════════════════════════════════════════════
# GAME LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

## Entry point: load hub with current profile data.
## Called after menu or when returning from end screen.
func start_game() -> void:
	if _store == null:
		push_error("[GameFlow] Cannot start game: MerlinStore not set")
		return
	_set_phase(GamePhase.HUB)


## Transition from hub to run.
## Called when HubScreen emits run_requested.
func _on_run_requested(biome_id: String, selected_oghams: Array) -> void:
	if _current_phase != GamePhase.HUB:
		push_warning("[GameFlow] run_requested ignored: not in HUB phase (current: %s)" % get_current_phase_name())
		return

	if biome_id.is_empty():
		push_warning("[GameFlow] run_requested ignored: empty biome_id")
		return

	# Save run intent to run_state before transition
	if _save_system:
		var run_state: Dictionary = MerlinSaveSystem._get_default_run_state()
		run_state["biome"] = biome_id
		run_state["equipped_oghams"] = selected_oghams.duplicate()
		if selected_oghams.size() > 0:
			run_state["active_ogham"] = str(selected_oghams[0])
		_save_system.save_run_state(run_state)

	# Initialize run in store
	if _store:
		var run: Dictionary = _store.state.get("run", {})
		run["active"] = true
		run["current_biome"] = biome_id
		run["life_essence"] = MerlinConstants.LIFE_ESSENCE_START
		run["cards_played"] = 0
		run["story_log"] = []
		run["active_tags"] = []
		run["active_promises"] = []
		_store.state["run"] = run

	_set_phase(GamePhase.RUN)


## Transition from run to end screen.
## Called when Run3DController emits run_ended.
func _on_run_ended(reason: String, data: Dictionary) -> void:
	if _current_phase != GamePhase.RUN:
		push_warning("[GameFlow] run_ended ignored: not in RUN phase (current: %s)" % get_current_phase_name())
		return

	_last_run_data = _build_end_run_data(reason, data)

	# Apply rewards to profile
	if _store:
		var rewards: Dictionary = _compute_run_rewards(_last_run_data)
		_store.apply_run_rewards(rewards)

	# Clear saved run_state (run is finished)
	if _save_system:
		_save_system.clear_run_state()

	_set_phase(GamePhase.END_SCREEN)


## Transition from end screen back to hub.
## Called when EndRunScreen emits hub_requested.
func _on_hub_requested() -> void:
	if _current_phase != GamePhase.END_SCREEN:
		push_warning("[GameFlow] hub_requested ignored: not in END_SCREEN phase (current: %s)" % get_current_phase_name())
		return

	_last_run_data = {}
	_set_phase(GamePhase.HUB)


## Navigate to talent tree.
## Called when HubScreen emits talent_tree_requested.
func _on_talent_tree_requested() -> void:
	if _current_phase != GamePhase.HUB:
		push_warning("[GameFlow] talent_tree_requested ignored: not in HUB phase")
		return
	_set_phase(GamePhase.TALENT_TREE)


## Return from talent tree to hub.
func _on_talent_tree_closed() -> void:
	if _current_phase != GamePhase.TALENT_TREE:
		push_warning("[GameFlow] talent_tree_closed ignored: not in TALENT_TREE phase")
		return
	_set_phase(GamePhase.HUB)


## Save profile and request quit.
func _on_quit_requested() -> void:
	_save_profile()
	game_quit_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL WIRING — Connect/disconnect screen signals per phase
# ═══════════════════════════════════════════════════════════════════════════════

## Wire a hub instance. Accepts any Node that exposes the three hub signals
## (`run_requested(biome_id, selected_oghams)`, `talent_tree_requested()`,
## `quit_requested()`). Both HubScreen (2D) and MerlinCabinHub (FPS) qualify.
func wire_hub(hub: Node) -> void:
	if hub == null:
		return
	_disconnect_hub()
	_hub_screen = hub
	if hub.has_signal("run_requested"):
		hub.connect("run_requested", _on_run_requested)
	if hub.has_signal("talent_tree_requested"):
		hub.connect("talent_tree_requested", _on_talent_tree_requested)
	if hub.has_signal("quit_requested"):
		hub.connect("quit_requested", _on_quit_requested)


## Wire a Run3DController instance. Call after instantiating the run scene.
## Also performs the setup() call to initialize dependencies from the store.
func wire_run(run_controller: Run3DController) -> void:
	_disconnect_run()
	_run_controller = run_controller
	run_controller.run_ended.connect(_on_run_ended)
	# Setup the controller with dependencies from the store
	if _store != null:
		var spawner: CollectibleSpawner = CollectibleSpawner.new()
		run_controller.add_child(spawner)
		run_controller.setup(
			_store,
			_store.cards,
			_store.effects,
			_transition_manager,
			spawner,
			_store.minigames,
			true  # headless mode: no 3D world needed — card system drives the run
		)
		# Start the run
		if run_controller.has_method("start_run"):
			var run_data: Dictionary = _store.state.get("run", {})
			var biome_id: String = str(run_data.get("current_biome", "foret_broceliande"))
			var ogham_id: String = str(run_data.get("ogham_actif", "beith"))
			if ogham_id.is_empty():
				ogham_id = "beith"
			run_controller.start_run(biome_id, ogham_id)


## Wire an EndRunScreen instance. Call after instantiating the end screen.
func wire_end_screen(end_screen: EndRunScreen) -> void:
	_disconnect_end_screen()
	_end_screen = end_screen
	end_screen.hub_requested.connect(_on_hub_requested)


func _disconnect_hub() -> void:
	if _hub_screen != null and is_instance_valid(_hub_screen):
		if _hub_screen.has_signal("run_requested") \
				and _hub_screen.is_connected("run_requested", _on_run_requested):
			_hub_screen.disconnect("run_requested", _on_run_requested)
		if _hub_screen.has_signal("talent_tree_requested") \
				and _hub_screen.is_connected("talent_tree_requested", _on_talent_tree_requested):
			_hub_screen.disconnect("talent_tree_requested", _on_talent_tree_requested)
		if _hub_screen.has_signal("quit_requested") \
				and _hub_screen.is_connected("quit_requested", _on_quit_requested):
			_hub_screen.disconnect("quit_requested", _on_quit_requested)
	_hub_screen = null


func _disconnect_run() -> void:
	if _run_controller != null:
		if _run_controller.run_ended.is_connected(_on_run_ended):
			_run_controller.run_ended.disconnect(_on_run_ended)
		_run_controller = null


func _disconnect_end_screen() -> void:
	if _end_screen != null:
		if _end_screen.hub_requested.is_connected(_on_hub_requested):
			_end_screen.hub_requested.disconnect(_on_hub_requested)
		_end_screen = null


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE TRANSITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _set_phase(new_phase: int) -> void:
	var old_phase: int = _current_phase
	if old_phase == new_phase:
		return

	var old_name: String = PHASE_NAMES.get(old_phase, "unknown")
	var new_name: String = PHASE_NAMES.get(new_phase, "unknown")
	print("[GameFlow] Phase: %s -> %s" % [old_name, new_name])

	_current_phase = new_phase
	phase_changed.emit(old_name, new_name)

	# Transition to the scene for the new phase.
	_transition_to_phase_scene(new_phase)


## Perform the actual scene transition via PixelTransition (or fallback).
func _transition_to_phase_scene(phase: int) -> void:
	var target: String = ""
	match phase:
		GamePhase.HUB:
			target = SCENE_HUB
		GamePhase.RUN:
			target = SCENE_RUN
		GamePhase.END_SCREEN:
			target = SCENE_END
		GamePhase.MENU:
			target = SCENE_MENU
		GamePhase.TALENT_TREE:
			target = SCENE_TALENT_TREE

	if target.is_empty():
		return

	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("transition_to"):
		pt.transition_to(target)
	else:
		get_tree().change_scene_to_file(target)


# ═══════════════════════════════════════════════════════════════════════════════
# HUB DATA — Build data dictionary for HubScreen.setup()
# ═══════════════════════════════════════════════════════════════════════════════

func build_hub_data() -> Dictionary:
	if _store == null:
		return {}

	var meta: Dictionary = _store.state.get("meta", {})
	# Oghams live in state.oghams (store) or meta.oghams (save profile)
	var store_oghams: Dictionary = _store.state.get("oghams", {})
	var meta_oghams: Dictionary = meta.get("oghams", {})
	var owned_oghams: Array = store_oghams.get("skills_unlocked", meta_oghams.get("owned", []))
	var equipped_list: Array = store_oghams.get("skills_equipped", [])
	if equipped_list.is_empty():
		var equipped_val = meta_oghams.get("equipped", "")
		if equipped_val is String and not str(equipped_val).is_empty():
			equipped_list = [str(equipped_val)]
		elif equipped_val is Array:
			equipped_list = equipped_val

	# Build biome lists
	var biomes_unlocked: Array = meta.get("biomes_unlocked", ["foret_broceliande"])
	var available_biomes: Array = []
	var locked_biomes: Array = []

	for biome_id in MerlinConstants.BIOMES:
		var biome_spec: Dictionary = MerlinConstants.BIOMES[biome_id]
		var biome_entry: Dictionary = {
			"id": biome_id,
			"name": str(biome_spec.get("name", biome_id)),
		}
		if biomes_unlocked.has(biome_id):
			available_biomes.append(biome_entry)
		else:
			var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_id, 999))
			biome_entry["threshold"] = threshold
			locked_biomes.append(biome_entry)

	return {
		"player_name": str(meta.get("player_name", "Druide")),
		"anam": int(meta.get("anam", 0)),
		"total_runs": int(meta.get("total_runs", 0)),
		"faction_rep": meta.get("faction_rep", {}).duplicate(),
		"unlocked_oghams": owned_oghams.duplicate(),
		"selected_oghams": equipped_list.duplicate(),
		"maturity_score": _store.calculate_maturity_score(),
		"biomes": available_biomes,
		"locked_biomes": locked_biomes,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# END RUN DATA — Build summary for EndRunScreen
# ═══════════════════════════════════════════════════════════════════════════════

func _build_end_run_data(reason: String, run_data: Dictionary) -> Dictionary:
	var is_victory: bool = (reason != "death" and reason != "abandon")
	var cards_played: int = int(run_data.get("card_index", 0))
	var life: int = int(run_data.get("life_essence", 0))

	var rewards: Dictionary = _compute_run_rewards_from_raw(is_victory, cards_played, run_data)

	return {
		"reason": reason,
		"victory": is_victory,
		"cards_played": cards_played,
		"life_essence": life,
		"life_max": MerlinConstants.LIFE_ESSENCE_MAX,
		"biome": str(run_data.get("biome", "")),
		"biome_currency": int(run_data.get("biome_currency", 0)),
		"faction_rep_delta": run_data.get("faction_rep_delta", {}),
		"promises": run_data.get("promises", []),
		"story_log": run_data.get("story_log", []),
		"oghams_used": int(run_data.get("oghams_used", 0)),
		"minigames_played": int(run_data.get("minigames_played", 0)),
		"minigames_won": int(run_data.get("minigames_won", 0)),
		"avg_minigame_score": float(run_data.get("avg_minigame_score", 0.0)),
		"rewards": rewards,
	}


func _compute_run_rewards_from_raw(is_victory: bool, cards_played: int,
		run_data: Dictionary) -> Dictionary:
	var base_anam: int = MerlinConstants.ANAM_BASE_REWARD
	var minigames_won: int = int(run_data.get("minigames_won", 0))
	var oghams_used: int = int(run_data.get("oghams_used", 0))
	var raw_anam: int = base_anam + (minigames_won * MerlinConstants.ANAM_PER_MINIGAME) + (oghams_used * MerlinConstants.ANAM_PER_OGHAM)

	var final_anam: int = raw_anam
	if not is_victory:
		var penalty_ratio: float = minf(float(cards_played) / 30.0, 1.0)
		final_anam = int(float(raw_anam) * penalty_ratio)

	return {
		"anam": maxi(final_anam, 0),
		"cards_played": cards_played,
		"minigames_won": minigames_won,
		"victory": is_victory,
		"biome": str(run_data.get("biome", "")),
	}


func _compute_run_rewards(end_data: Dictionary) -> Dictionary:
	return end_data.get("rewards", {})


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE
# ═══════════════════════════════════════════════════════════════════════════════

func _save_profile() -> void:
	if _store == null or _save_system == null:
		push_warning("[GameFlow] Cannot save: store or save_system not set")
		return
	var meta: Dictionary = _store.state.get("meta", {})
	_save_system.save_profile(meta)


# ═══════════════════════════════════════════════════════════════════════════════
# RESUME — Check for interrupted run on startup
# ═══════════════════════════════════════════════════════════════════════════════

func has_interrupted_run() -> bool:
	if _save_system == null:
		return false
	return _save_system.has_active_run()


func get_interrupted_run_state() -> Dictionary:
	if _save_system == null:
		return {}
	return _save_system.load_run_state()


func clear_interrupted_run() -> void:
	if _save_system:
		_save_system.clear_run_state()


# ═══════════════════════════════════════════════════════════════════════════════
# ACCESSORS
# ═══════════════════════════════════════════════════════════════════════════════

func get_last_run_data() -> Dictionary:
	return _last_run_data


func get_store() -> MerlinStore:
	return _store
