## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Store — Central State Management
## ═══════════════════════════════════════════════════════════════════════════════
## Redux-like state management for Merlin game.
## Updated 2026-02-08 for TRIADE system (3 aspects, 3 states, 3 options).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MerlinStore

signal state_changed(state: Dictionary)
signal phase_changed(phase: String)
signal transition_logged(entry: Dictionary)
signal aspect_shifted(aspect: String, old_state: int, new_state: int)
signal souffle_changed(old_value: int, new_value: int)
signal run_ended(ending: Dictionary)
signal card_resolved(card_id: String, option: int)
signal mission_progress(step: int, total: int)
signal awen_changed(old_value: int, new_value: int)
signal ogham_activated(skill_id: String, effect: String)
signal bond_tier_changed(old_tier: String, new_tier: String)

const VERSION := "0.3.0"  # Updated for TRIADE system

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
	cards.gauge_critical.connect(_on_gauge_critical)
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


func _deferred_wire_merlin_ai() -> void:
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		llm.set_merlin_ai(merlin_ai_node)
		print("[MerlinStore] MerlinAI wired to LLM adapter (deferred)")


# ═══════════════════════════════════════════════════════════════════════════════
# STATE BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func build_default_state() -> Dictionary:
	# Legacy resources (for compatibility)
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

	# TRIADE system - 3 Aspects with 3 discrete states
	var aspects: Dictionary = {
		"Corps": MerlinConstants.AspectState.EQUILIBRE,
		"Ame": MerlinConstants.AspectState.EQUILIBRE,
		"Monde": MerlinConstants.AspectState.EQUILIBRE,
	}

	var essence: Dictionary = {}
	for element in MerlinConstants.ELEMENTS:
		essence[element] = 0

	return {
		"version": VERSION,
		"phase": "title",
		"mode": "triade",  # "triade" (new), "reigns" (deprecated), or "legacy"
		"timestamp": int(Time.get_unix_time_from_system()),
		"run": {
			"active": false,
			# Legacy fields (for compatibility)
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
			# TRIADE fields (NEW v0.3.0)
			"aspects": aspects,
			"souffle": MerlinConstants.SOUFFLE_START,
			"mission": {
				"type": "",
				"target": "",
				"progress": 0,
				"total": 0,
				"revealed": false,
			},
			"cards_played": 0,
			"day": 1,
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
		},
		"bestiole": {
			"name": "Bestiole",
			# Needs
			"needs": {"Hunger": 50, "Energy": 50, "Hygiene": 50, "Mood": 50, "Stress": 0},
			"tendency": {"Wild": 0, "Light": 0, "Discipline": 0},
			"xp": 0,
			"bond_xp": 0,
			"evolve_ready": false,
			# Bond & Skills
			"bond": 50,
			"skills_unlocked": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skills_equipped": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
			"skill_cooldowns": {},
			# Souffle d'Awen (Ogham activation resource)
			"awen": MerlinConstants.AWEN_START,
			"awen_regen_counter": 0,  # Cards since last regen
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
			# Reigns meta
			"total_runs": 0,
			"total_cards_played": 0,
			"endings_seen": [],
			"gloire_points": 0,
			# Arbre de Vie — Talent Tree (Phase 35)
			"talent_tree": {
				"unlocked": [],  # Array of talent node IDs
			},
			# Bestiole Evolution (Phase 35)
			"bestiole_evolution": {
				"stage": 1,      # 1=Enfant, 2=Compagnon, 3=Gardien
				"path": "",      # "" | "protecteur" | "oracle" | "diplomate"
			},
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
		# TRIADE SYSTEM ACTIONS (v0.3.0)
		# ═══════════════════════════════════════════════════════════════════════
		"TRIADE_START_RUN":
			var seed_val: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed_val)
			_init_triade_run()
			_reset_ai_for_new_run()
			state["run"]["map_seed"] = seed_val
			# Set biome from action (default: Broceliande)
			var biome_key: String = str(action.get("biome", MerlinConstants.BIOME_DEFAULT))
			state["run"]["current_biome"] = biome_key
			# Apply biome flux offset
			var flux_offset: Dictionary = biomes.get_flux_offset(biome_key)
			var flux: Dictionary = state["run"].get("flux", MerlinConstants.FLUX_START.duplicate())
			for axis in flux_offset:
				flux[axis] = clampi(int(flux.get(axis, 50)) + int(flux_offset.get(axis, 0)), MerlinConstants.FLUX_MIN, MerlinConstants.FLUX_MAX)
			state["run"]["flux"] = flux
			state["phase"] = "card"
			state["mode"] = "triade"
			_log_transition("triade_run_start", {"seed": seed_val, "biome": biome_key})
			# Notify MERLIN OMNISCIENT
			if merlin != null:
				merlin.on_run_start()
			return {"ok": true, "biome": biome_key}

		"TRIADE_GET_CARD":
			var card: Dictionary = {}
			# Use MERLIN OMNISCIENT if available
			if merlin != null and is_instance_valid(merlin):
				print("[MerlinStore] TRIADE_GET_CARD: using MerlinOmniscient")
				var mos_card = await merlin.generate_card(state)
				if mos_card is Dictionary and not mos_card.is_empty():
					card = mos_card
				else:
					print("[MerlinStore] MOS returned empty, falling back")
					card = cards.get_next_triade_card(state)
			elif llm != null and llm.is_llm_ready():
				# Direct adapter path (no MOS)
				print("[MerlinStore] TRIADE_GET_CARD: using direct LLM")
				var ctx: Dictionary = llm.build_triade_context(state)
				var llm_result: Dictionary = await llm.generate_card(ctx)
				if llm_result.get("ok", false) and llm_result.has("card"):
					card = llm_result["card"]
				else:
					card = cards.get_next_triade_card(state)
			else:
				print("[MerlinStore] TRIADE_GET_CARD: using fallback cards")
				card = cards.get_next_triade_card(state)
			# Final safety: ensure card is never empty
			if card.is_empty():
				push_warning("[MerlinStore] All card generation paths returned empty")
				card = cards.get_next_triade_card(state)
			return {"ok": true, "card": card}

		"TRIADE_RESOLVE_CHOICE":
			var card = action.get("card", {})
			var option: int = int(action.get("option", MerlinConstants.CardOption.LEFT))
			var mod_effects: Array = action.get("modulated_effects", [])
			var result = _resolve_triade_choice(card, option, mod_effects)
			if result["ok"]:
				# Record choice with MERLIN OMNISCIENT
				if merlin != null:
					merlin.record_choice(card, option, state)
				card_resolved.emit(card.get("id", ""), option)
				_trigger_autosave()
				var end_check = _check_triade_run_end()
				if end_check["ended"]:
					state["run"]["active"] = false
					state["phase"] = "end"
					_handle_triade_run_end(end_check)
					# Notify Merlin of run end
					if merlin != null:
						merlin.on_run_end(end_check)
					return {"ok": true, "run_ended": true, "ending": end_check}
			return result

		"TRIADE_SHIFT_ASPECT":
			var aspect: String = action.get("aspect", "")
			var direction: String = action.get("direction", "")  # "up" or "down"
			return _shift_aspect(aspect, direction)

		"TRIADE_USE_SOUFFLE":
			var amount: int = int(action.get("amount", 1))
			return _use_souffle(amount)

		"TRIADE_ADD_SOUFFLE":
			var amount: int = int(action.get("amount", 1))
			return _add_souffle(amount)

		"TRIADE_PROGRESS_MISSION":
			var step: int = int(action.get("step", 1))
			return _progress_mission(step)

		"TRIADE_USE_SKILL":
			var skill_id = action.get("skill_id", "")
			var card = action.get("card", {})
			var result = cards.use_bestiole_skill(state, skill_id, card)
			return result

		"TRIADE_USE_OGHAM":
			var skill_id: String = str(action.get("skill_id", ""))
			return _use_ogham(skill_id)

		"TRIADE_ADD_AWEN":
			var amount: int = int(action.get("amount", 1))
			return _add_awen(amount)

		"TRIADE_USE_AWEN":
			var amount: int = int(action.get("amount", 1))
			return _use_awen(amount)

		"TRIADE_UPDATE_FLUX":
			var delta: Dictionary = action.get("delta", {})
			var flux: Dictionary = state["run"].get("flux", MerlinConstants.FLUX_START.duplicate())
			for axis in delta:
				flux[axis] = clampi(int(flux.get(axis, 50)) + int(delta.get(axis, 0)), MerlinConstants.FLUX_MIN, MerlinConstants.FLUX_MAX)
			state["run"]["flux"] = flux
			return {"ok": true, "flux": flux}

		"TRIADE_END_RUN":
			var end_check = _check_triade_run_end()
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
			_handle_triade_run_end(end_check)
			# Notify MERLIN OMNISCIENT
			if merlin != null:
				merlin.on_run_end(end_check)
			return {"ok": true, "ending": end_check}

		# ═══════════════════════════════════════════════════════════════════════
		# MAP ACTIONS (Phase 37 — STS-like world map)
		# ═══════════════════════════════════════════════════════════════════════
		"TRIADE_GENERATE_MAP":
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

		"TRIADE_SELECT_NODE":
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
		# REIGNS-STYLE ACTIONS (DEPRECATED - kept for compatibility)
		# ═══════════════════════════════════════════════════════════════════════
		"REIGNS_START_RUN":
			var seed_val: int = int(action.get("seed", int(Time.get_unix_time_from_system())))
			rng.set_seed(seed_val)
			cards.init_run(state)
			state["run"]["map_seed"] = seed_val
			state["phase"] = "card"
			state["mode"] = "reigns"
			_log_transition("reigns_run_start", {"seed": seed_val})
			return {"ok": true}

		"REIGNS_GET_CARD":
			var card = await cards.get_next_card(state)
			return {"ok": true, "card": card}

		"REIGNS_RESOLVE_CHOICE":
			var card = action.get("card", {})
			var direction = action.get("direction", "")
			var result = cards.resolve_choice(state, card, direction)
			if result["ok"]:
				card_resolved.emit(card.get("id", ""), 0 if direction == "left" else 1)
				var end_check = cards.check_run_end(state)
				if end_check["ended"]:
					state["run"]["active"] = false
					state["phase"] = "end"
					_handle_run_end(end_check)
					return {"ok": true, "run_ended": true, "ending": end_check}
			return result

		"REIGNS_USE_SKILL":
			var skill_id = action.get("skill_id", "")
			var card = action.get("card", {})
			var result = cards.use_bestiole_skill(state, skill_id, card)
			return result

		"REIGNS_END_RUN":
			var end_check = cards.check_run_end(state)
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
			return {"ok": true, "ending": end_check}

		# ═══════════════════════════════════════════════════════════════════════
		# LEGACY ACTIONS (kept for compatibility)
		# ═══════════════════════════════════════════════════════════════════════
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
			state["mode"] = "legacy"
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

		# ═══════════════════════════════════════════════════════════════════════
		# SAVE/LOAD
		# ═══════════════════════════════════════════════════════════════════════
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
			_restore_ai_state()
			return {"ok": true}

		"LOAD_AUTOSAVE":
			var loaded: Dictionary = save_system.load_autosave(build_default_state())
			if loaded.is_empty():
				return {"ok": false}
			state = loaded
			_restore_ai_state()
			return {"ok": true}

		# ═══════════════════════════════════════════════════════════════════════
		# BESTIOLE CARE
		# ═══════════════════════════════════════════════════════════════════════
		"BESTIOLE_CARE":
			var action_name = action.get("action", "")
			return _handle_bestiole_care(action_name)

		_:
			return {"ok": false, "error": "Unknown action"}


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func snapshot_for_save() -> Dictionary:
	var data: Dictionary = state.duplicate(true)
	data["timestamp"] = int(Time.get_unix_time_from_system())
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
	var payload := snapshot_for_save()
	save_system.save_autosave(payload)
	if merlin:
		merlin.save_all()


func _restore_ai_state() -> void:
	## Restore MOS registries and session history after loading a save slot.
	if merlin:
		merlin.reload_registries()
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node and merlin_ai_node.has_method("load_session_history"):
		merlin_ai_node.load_session_history()


func _reset_ai_for_new_run() -> void:
	## Reset per-run AI state while preserving cross-run memory.
	var merlin_ai_node := get_node_or_null("/root/MerlinAI")
	if merlin_ai_node:
		merlin_ai_node.session_contexts.clear()


func _handle_run_end(end_check: Dictionary) -> void:
	var meta = state.get("meta", {})
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["total_cards_played"] = int(meta.get("total_cards_played", 0)) + int(end_check.get("cards_played", 0))

	# Track ending seen
	var ending = end_check.get("ending", {})
	var ending_title = ending.get("title", "")
	var endings_seen = meta.get("endings_seen", [])
	if not endings_seen.has(ending_title):
		endings_seen.append(ending_title)
	meta["endings_seen"] = endings_seen

	# Award gloire points
	meta["gloire_points"] = int(meta.get("gloire_points", 0)) + int(end_check.get("score", 0) / 100)

	state["meta"] = meta
	_log_transition("reigns_run_end", end_check)
	run_ended.emit(end_check)


func _handle_bestiole_care(action_name: String) -> Dictionary:
	var bestiole = state.get("bestiole", {})
	var needs = bestiole.get("needs", {})

	match action_name:
		"feed":
			needs["Hunger"] = mini(int(needs.get("Hunger", 50)) + 30, 100)
			needs["Mood"] = mini(int(needs.get("Mood", 50)) + 5, 100)
			bestiole["bond"] = mini(int(bestiole.get("bond", 50)) + 2, 100)
		"play":
			needs["Mood"] = mini(int(needs.get("Mood", 50)) + 20, 100)
			needs["Energy"] = maxi(int(needs.get("Energy", 50)) - 10, 0)
			bestiole["bond"] = mini(int(bestiole.get("bond", 50)) + 3, 100)
		"groom":
			needs["Hygiene"] = mini(int(needs.get("Hygiene", 50)) + 25, 100)
			bestiole["bond"] = mini(int(bestiole.get("bond", 50)) + 2, 100)
		"rest":
			needs["Energy"] = mini(int(needs.get("Energy", 50)) + 40, 100)
			needs["Stress"] = maxi(int(needs.get("Stress", 0)) - 10, 0)
		"gift":
			bestiole["bond"] = mini(int(bestiole.get("bond", 50)) + 15, 100)
			needs["Mood"] = mini(int(needs.get("Mood", 50)) + 10, 100)
		_:
			return {"ok": false, "error": "Unknown care action"}

	bestiole["needs"] = needs
	state["bestiole"] = bestiole
	return {"ok": true, "needs": needs, "bond": bestiole["bond"]}


func _on_gauge_critical(gauge: String, value: int, direction: String) -> void:
	pass  # Deprecated for TRIADE system


func _on_run_ended(ending: Dictionary) -> void:
	pass  # Handled in TRIADE_RESOLVE_CHOICE


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _init_triade_run() -> void:
	var run = state.get("run", {})
	run["active"] = true
	run["aspects"] = {
		"Corps": MerlinConstants.AspectState.EQUILIBRE,
		"Ame": MerlinConstants.AspectState.EQUILIBRE,
		"Monde": MerlinConstants.AspectState.EQUILIBRE,
	}
	run["souffle"] = MerlinConstants.SOUFFLE_START
	run["mission"] = {"type": "", "target": "", "progress": 0, "total": 0, "revealed": false}
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
	state["run"] = run
	_apply_talent_effects_for_run()


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
					"souffle":
						run["souffle"] = int(run.get("souffle", 0)) + value
					"blessings":
						modifiers["extra_blessings"] = int(modifiers.get("extra_blessings", 0)) + value
					"awen":
						var bestiole: Dictionary = state.get("bestiole", {})
						bestiole["awen"] = mini(int(bestiole.get("awen", 0)) + value, MerlinConstants.AWEN_MAX)
						state["bestiole"] = bestiole
					"souffle_max":
						modifiers["souffle_max_bonus"] = int(modifiers.get("souffle_max_bonus", 0)) + value
					"bond":
						var bestiole: Dictionary = state.get("bestiole", {})
						bestiole["bond"] = maxi(int(bestiole.get("bond", 0)), value)
						state["bestiole"] = bestiole

			"cancel_first_shift":
				var aspect: String = str(effect.get("aspect", ""))
				var direction: String = str(effect.get("direction", ""))
				var key: String = "cancel_%s_%s" % [aspect.to_lower(), direction]
				modifiers[key] = true

			"special_rule":
				var rule_id: String = str(effect.get("id", ""))
				modifiers[rule_id] = true

	# Apply flux_start_balanced if unlocked
	if modifiers.get("flux_start_balanced", false):
		run["flux"] = {"terre": 50, "esprit": 50, "lien": 50}
	elif not run.has("flux"):
		run["flux"] = MerlinConstants.FLUX_START.duplicate()

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


func _shift_aspect(aspect: String, direction: String) -> Dictionary:
	if aspect not in MerlinConstants.TRIADE_ASPECTS:
		return {"ok": false, "error": "Invalid aspect: " + aspect}

	# Talent: cancel_first_shift (one-shot per run)
	var cancel_key: String = "cancel_%s_%s" % [aspect.to_lower(), direction]
	if _consume_talent_modifier(cancel_key):
		var cur_state: int = int(state.get("run", {}).get("aspects", {}).get(aspect, 0))
		return {"ok": true, "aspect": aspect, "cancelled": true, "old_state": cur_state, "new_state": cur_state}

	var run = state.get("run", {})
	var aspects = run.get("aspects", {})
	var old_state: int = int(aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
	var new_state: int = old_state

	if direction == "up":
		new_state = mini(old_state + 1, MerlinConstants.AspectState.HAUT)
	elif direction == "down":
		new_state = maxi(old_state - 1, MerlinConstants.AspectState.BAS)
	else:
		return {"ok": false, "error": "Invalid direction: " + direction}

	if new_state != old_state:
		aspects[aspect] = new_state
		run["aspects"] = aspects
		state["run"] = run
		aspect_shifted.emit(aspect, old_state, new_state)
		_log_transition("aspect_shift", {"aspect": aspect, "from": old_state, "to": new_state})

		# Check for souffle regeneration (all 3 aspects balanced)
		_check_souffle_regen()

	return {"ok": true, "aspect": aspect, "old_state": old_state, "new_state": new_state}


func _use_souffle(amount: int) -> Dictionary:
	# Talent: free_center_once (one free center per run)
	if amount > 0 and _consume_talent_modifier("free_center_once"):
		var cur_souffle: int = int(state.get("run", {}).get("souffle", 0))
		return {"ok": true, "used": 0, "risk": false, "souffle": cur_souffle, "free": true}

	var run = state.get("run", {})
	var old_souffle: int = int(run.get("souffle", 0))

	if old_souffle < amount:
		# Allow use but with risk
		return {"ok": true, "used": 0, "risk": true, "souffle": old_souffle}

	var new_souffle: int = old_souffle - amount
	run["souffle"] = new_souffle
	state["run"] = run
	souffle_changed.emit(old_souffle, new_souffle)
	return {"ok": true, "used": amount, "risk": false, "souffle": new_souffle}


func _add_souffle(amount: int) -> Dictionary:
	var run = state.get("run", {})
	var old_souffle: int = int(run.get("souffle", 0))
	var new_souffle: int = mini(old_souffle + amount, MerlinConstants.SOUFFLE_MAX)
	run["souffle"] = new_souffle
	state["run"] = run
	souffle_changed.emit(old_souffle, new_souffle)
	return {"ok": true, "added": new_souffle - old_souffle, "souffle": new_souffle}


func _check_souffle_regen() -> void:
	var run = state.get("run", {})
	var aspects = run.get("aspects", {})

	# Check if all 3 aspects are balanced
	var all_balanced: bool = true
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		if int(aspects.get(aspect, 0)) != MerlinConstants.AspectState.EQUILIBRE:
			all_balanced = false
			break

	if all_balanced:
		# Talent: equilibre_souffle_double → +2 instead of +1
		var amount: int = 2 if _get_talent_modifier("equilibre_souffle_double") else 1
		_add_souffle(amount)


# ═══════════════════════════════════════════════════════════════════════════════
# AWEN / OGHAM SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _use_awen(amount: int) -> Dictionary:
	var bestiole: Dictionary = state.get("bestiole", {})
	var old_awen: int = int(bestiole.get("awen", 0))
	if old_awen < amount:
		return {"ok": false, "error": "Not enough Awen", "awen": old_awen}
	var new_awen: int = old_awen - amount
	bestiole["awen"] = new_awen
	state["bestiole"] = bestiole
	awen_changed.emit(old_awen, new_awen)
	return {"ok": true, "used": amount, "awen": new_awen}


func _add_awen(amount: int) -> Dictionary:
	var bestiole: Dictionary = state.get("bestiole", {})
	var old_awen: int = int(bestiole.get("awen", 0))
	var new_awen: int = mini(old_awen + amount, MerlinConstants.AWEN_MAX)
	bestiole["awen"] = new_awen
	state["bestiole"] = bestiole
	awen_changed.emit(old_awen, new_awen)
	return {"ok": true, "added": new_awen - old_awen, "awen": new_awen}


func _tick_awen_regen() -> void:
	"""Called after each card resolved. Regenerates Awen every N cards."""
	var bestiole: Dictionary = state.get("bestiole", {})
	var counter: int = int(bestiole.get("awen_regen_counter", 0)) + 1

	# Talent: awen_regen_faster → interval 4 instead of 5
	var regen_interval: int = MerlinConstants.AWEN_REGEN_INTERVAL
	if _get_talent_modifier("awen_regen_faster"):
		regen_interval = maxi(regen_interval - 1, 1)

	if counter >= regen_interval:
		counter = 0
		var regen: int = 1
		if is_all_aspects_balanced():
			regen += MerlinConstants.AWEN_REGEN_EQUILIBRE_BONUS
		_add_awen(regen)

	bestiole["awen_regen_counter"] = counter
	state["bestiole"] = bestiole


func _use_ogham(skill_id: String) -> Dictionary:
	"""Activate an Ogham skill, spending Awen and applying cooldown."""
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return {"ok": false, "error": "Unknown ogham: " + skill_id}

	# Check bond requirement
	var bond: int = get_bestiole_bond()
	var bond_required: int = int(spec.get("bond_required", 0))
	if bond < bond_required:
		return {"ok": false, "error": "Bond too low", "bond": bond, "required": bond_required}

	# Check cooldown
	var bestiole: Dictionary = state.get("bestiole", {})
	var cooldowns: Dictionary = bestiole.get("skill_cooldowns", {})
	var remaining: int = int(cooldowns.get(skill_id, 0))
	if remaining > 0:
		return {"ok": false, "error": "On cooldown", "remaining": remaining}

	# Check unlocked
	var unlocked: Array = bestiole.get("skills_unlocked", [])
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter and not unlocked.has(skill_id):
		return {"ok": false, "error": "Skill not unlocked"}

	# Spend Awen
	var awen_cost: int = int(spec.get("awen_cost", 1))
	var awen_result: Dictionary = _use_awen(awen_cost)
	if not awen_result.get("ok", false):
		return awen_result

	# Set cooldown
	cooldowns[skill_id] = int(spec.get("cooldown", 3))
	bestiole["skill_cooldowns"] = cooldowns
	state["bestiole"] = bestiole

	# Emit signal
	ogham_activated.emit(skill_id, str(spec.get("effect", "")))

	# Apply effect
	_apply_ogham_effect(skill_id, spec)

	# Bond gain from using ogham
	_modify_bond(2)

	return {
		"ok": true,
		"skill_id": skill_id,
		"effect": spec.get("effect", ""),
		"awen": int(state.get("bestiole", {}).get("awen", 0)),
	}


func _apply_ogham_effect(_skill_id: String, spec: Dictionary) -> void:
	"""Apply the actual Ogham effect on the game state."""
	var effect_id: String = str(spec.get("effect", ""))
	match effect_id:
		"heal_worst":
			# Quert: Bring worst aspect toward Equilibre
			var worst_aspect: String = ""
			var worst_distance: int = 0
			var aspects: Dictionary = get_all_aspects()
			for aspect in MerlinConstants.TRIADE_ASPECTS:
				var s: int = int(aspects.get(aspect, 0))
				if absi(s) > worst_distance:
					worst_distance = absi(s)
					worst_aspect = aspect
			if not worst_aspect.is_empty() and worst_distance > 0:
				var s: int = int(aspects.get(worst_aspect, 0))
				var dir: String = "down" if s > 0 else "up"
				_shift_aspect(worst_aspect, dir)
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
			# Duir: Force any one aspect to Equilibre (best = worst extreme)
			var aspects: Dictionary = get_all_aspects()
			var worst_aspect: String = ""
			var worst_distance: int = 0
			for aspect in MerlinConstants.TRIADE_ASPECTS:
				var s: int = int(aspects.get(aspect, 0))
				if absi(s) > worst_distance:
					worst_distance = absi(s)
					worst_aspect = aspect
			if not worst_aspect.is_empty():
				var run: Dictionary = state.get("run", {})
				var run_aspects: Dictionary = run.get("aspects", {})
				var old_s: int = int(run_aspects.get(worst_aspect, 0))
				run_aspects[worst_aspect] = MerlinConstants.AspectState.EQUILIBRE
				run["aspects"] = run_aspects
				state["run"] = run
				if old_s != MerlinConstants.AspectState.EQUILIBRE:
					aspect_shifted.emit(worst_aspect, old_s, MerlinConstants.AspectState.EQUILIBRE)
		"balance_all":
			# Ruis: All aspects toward Equilibre
			var run: Dictionary = state.get("run", {})
			var aspects: Dictionary = run.get("aspects", {})
			for aspect in MerlinConstants.TRIADE_ASPECTS:
				var s: int = int(aspects.get(aspect, 0))
				if s != MerlinConstants.AspectState.EQUILIBRE:
					aspects[aspect] = MerlinConstants.AspectState.EQUILIBRE
					aspect_shifted.emit(aspect, s, MerlinConstants.AspectState.EQUILIBRE)
			run["aspects"] = aspects
			state["run"] = run
		"souffle_boost":
			# Onn: Regenerate Souffle d'Ogham
			_add_souffle(2)
		"regen_awen":
			# Saille: Regenerate Awen
			_add_awen(2)
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


func _modify_bond(amount: int) -> void:
	"""Modify Bestiole bond, checking for tier changes."""
	var bestiole: Dictionary = state.get("bestiole", {})
	var old_bond: int = int(bestiole.get("bond", 50))
	var new_bond: int = clampi(old_bond + amount, 0, 100)
	bestiole["bond"] = new_bond
	state["bestiole"] = bestiole

	var old_tier: String = _get_bond_tier(old_bond)
	var new_tier: String = _get_bond_tier(new_bond)
	if old_tier != new_tier:
		bond_tier_changed.emit(old_tier, new_tier)


func _get_bond_tier(bond: int) -> String:
	for tier_name in MerlinConstants.BOND_TIERS:
		var tier: Dictionary = MerlinConstants.BOND_TIERS[tier_name]
		if bond >= int(tier.get("min", 0)) and bond <= int(tier.get("max", 100)):
			return tier_name
	return "distant"


func tick_cooldowns() -> void:
	"""Decrement all Ogham cooldowns by 1. Call after each card resolved."""
	var bestiole: Dictionary = state.get("bestiole", {})
	var cooldowns: Dictionary = bestiole.get("skill_cooldowns", {})
	var to_remove: Array = []
	for skill_id in cooldowns:
		cooldowns[skill_id] = maxi(int(cooldowns[skill_id]) - 1, 0)
		if int(cooldowns[skill_id]) <= 0:
			to_remove.append(skill_id)
	for skill_id in to_remove:
		cooldowns.erase(skill_id)
	bestiole["skill_cooldowns"] = cooldowns
	state["bestiole"] = bestiole


func can_use_ogham(skill_id: String) -> bool:
	"""Check if an Ogham can be activated right now."""
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(skill_id, {})
	if spec.is_empty():
		return false
	var bestiole: Dictionary = state.get("bestiole", {})
	var bond: int = int(bestiole.get("bond", 0))
	if bond < int(spec.get("bond_required", 0)):
		return false
	var cooldowns: Dictionary = bestiole.get("skill_cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		return false
	var awen: int = int(bestiole.get("awen", 0))
	if awen < int(spec.get("awen_cost", 1)):
		return false
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter:
		var unlocked: Array = bestiole.get("skills_unlocked", [])
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


func get_awen() -> int:
	return int(state.get("bestiole", {}).get("awen", MerlinConstants.AWEN_START))


func get_awen_max() -> int:
	return MerlinConstants.AWEN_MAX


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


func _resolve_triade_choice(card: Dictionary, option: int, modulated_effects: Array = []) -> Dictionary:
	var run = state.get("run", {})

	if modulated_effects.is_empty():
		# Legacy path: controller did NOT pre-modulate → apply raw effects
		# Handle center option cost
		if option == MerlinConstants.CardOption.CENTER:
			var souffle_result = _use_souffle(MerlinConstants.SOUFFLE_CENTER_COST)
			if souffle_result.get("risk", false):
				var roll: float = rng.randf()
				if roll < MerlinConstants.SOUFFLE_EMPTY_RISK["normal"]:
					pass
				elif roll < MerlinConstants.SOUFFLE_EMPTY_RISK["normal"] + MerlinConstants.SOUFFLE_EMPTY_RISK["aspect_down"]:
					var random_aspect: String = MerlinConstants.TRIADE_ASPECTS[rng.randi() % 3]
					_shift_aspect(random_aspect, "down")
				else:
					var random_aspect: String = MerlinConstants.TRIADE_ASPECTS[rng.randi() % 3]
					_shift_aspect(random_aspect, "up")

		# Get effects for chosen option
		var options = card.get("options", [])
		if option >= 0 and option < options.size():
			var chosen = options[option]
			var card_effects = chosen.get("effects", [])
			for effect in card_effects:
				_apply_triade_effect(effect)
	else:
		# New path: controller already modulated effects (D20, talents, shields)
		# Souffle cost already handled by controller
		for effect in modulated_effects:
			_apply_triade_effect(effect)

	# Update run state
	run["cards_played"] = int(run.get("cards_played", 0)) + 1
	state["run"] = run

	# Update player profile based on choice
	_update_player_profile(option)

	# Tick Ogham cooldowns and Awen regen
	tick_cooldowns()
	_tick_awen_regen()

	# Biome passive only in legacy path (controller handles it in new path)
	if modulated_effects.is_empty():
		var biome_key: String = str(run.get("current_biome", ""))
		if not biome_key.is_empty():
			var passive: Dictionary = biomes.get_passive_effect(biome_key, int(run.get("cards_played", 0)))
			if not passive.is_empty():
				_apply_triade_effect(passive)

	# Check promise deadlines
	_check_promise_deadlines()

	return {"ok": true, "option": option, "cards_played": run["cards_played"]}


func _apply_triade_effect(effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"SHIFT_ASPECT":
			var aspect: String = effect.get("aspect", "")
			var direction: String = effect.get("direction", "")
			_shift_aspect(aspect, direction)
		"SET_ASPECT":
			var aspect: String = effect.get("aspect", "")
			var new_state: int = int(effect.get("state", MerlinConstants.AspectState.EQUILIBRE))
			var run = state.get("run", {})
			var aspects = run.get("aspects", {})
			var old_state: int = int(aspects.get(aspect, 0))
			aspects[aspect] = new_state
			run["aspects"] = aspects
			state["run"] = run
			if old_state != new_state:
				aspect_shifted.emit(aspect, old_state, new_state)
		"USE_SOUFFLE":
			var amount: int = int(effect.get("amount", 1))
			_use_souffle(amount)
		"ADD_SOUFFLE":
			var amount: int = int(effect.get("amount", 1))
			_add_souffle(amount)
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


func _check_triade_run_end() -> Dictionary:
	var run = state.get("run", {})
	var aspects = run.get("aspects", {})

	# Count extreme aspects
	var extremes: Array = []
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var aspect_state: int = int(aspects.get(aspect, 0))
		if aspect_state == MerlinConstants.AspectState.BAS or aspect_state == MerlinConstants.AspectState.HAUT:
			extremes.append({"aspect": aspect, "state": aspect_state})

	# Game ends if 2+ aspects are extreme
	if extremes.size() >= 2:
		var ending = _get_triade_ending(extremes[0], extremes[1])
		return {
			"ended": true,
			"ending": ending,
			"score": int(run.get("cards_played", 0)) * 10,
			"cards_played": run.get("cards_played", 0),
			"days_survived": run.get("day", 1),
		}

	# Check for victory (mission complete)
	var mission = run.get("mission", {})
	if int(mission.get("progress", 0)) >= int(mission.get("total", 0)) and int(mission.get("total", 0)) > 0:
		var victory_type = _get_victory_type(aspects)
		return {
			"ended": true,
			"ending": MerlinConstants.TRIADE_VICTORY_ENDINGS.get(victory_type, {"title": "Victoire"}),
			"victory": true,
			"score": int(run.get("cards_played", 0)) * 20,
			"cards_played": run.get("cards_played", 0),
			"days_survived": run.get("day", 1),
		}

	return {"ended": false}


func _get_triade_ending(extreme1: Dictionary, extreme2: Dictionary) -> Dictionary:
	# Build ending key from the two extreme aspects
	var aspect1: String = extreme1.get("aspect", "").to_lower()
	var state1: int = extreme1.get("state", 0)
	var aspect2: String = extreme2.get("aspect", "").to_lower()
	var state2: int = extreme2.get("state", 0)

	var state1_str: String = "bas" if state1 == MerlinConstants.AspectState.BAS else "haut"
	var state2_str: String = "bas" if state2 == MerlinConstants.AspectState.BAS else "haut"

	# Try both orderings to find the ending
	var key1: String = aspect1 + "_" + state1_str + "_" + aspect2 + "_" + state2_str
	var key2: String = aspect2 + "_" + state2_str + "_" + aspect1 + "_" + state1_str

	if MerlinConstants.TRIADE_ENDINGS.has(key1):
		return MerlinConstants.TRIADE_ENDINGS[key1]
	elif MerlinConstants.TRIADE_ENDINGS.has(key2):
		return MerlinConstants.TRIADE_ENDINGS[key2]

	return {"title": "Fin Inconnue", "text": "Le destin a pris un chemin inattendu..."}


func _get_victory_type(aspects: Dictionary) -> String:
	var extreme_count: int = 0
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var aspect_state: int = int(aspects.get(aspect, 0))
		if aspect_state != MerlinConstants.AspectState.EQUILIBRE:
			extreme_count += 1

	# Check for "Tyran Juste": Monde=HAUT, Corps=EQUILIBRE, Ame=EQUILIBRE
	if int(aspects.get("Monde", 0)) == MerlinConstants.AspectState.HAUT \
		and int(aspects.get("Corps", 0)) == MerlinConstants.AspectState.EQUILIBRE \
		and int(aspects.get("Ame", 0)) == MerlinConstants.AspectState.EQUILIBRE:
		return "tyran_juste"

	if extreme_count == 0:
		return "harmonie"
	elif extreme_count == 1:
		return "prix_paye"
	else:
		return "victoire_amere"


func _handle_triade_run_end(end_check: Dictionary) -> void:
	var meta = state.get("meta", {})
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["total_cards_played"] = int(meta.get("total_cards_played", 0)) + int(end_check.get("cards_played", 0))

	var ending = end_check.get("ending", {})
	var ending_title = ending.get("title", "")
	var endings_seen = meta.get("endings_seen", [])
	if not endings_seen.has(ending_title):
		endings_seen.append(ending_title)
	meta["endings_seen"] = endings_seen
	meta["gloire_points"] = int(meta.get("gloire_points", 0)) + int(end_check.get("score", 0) / 100)

	state["meta"] = meta

	# Calculate and apply run rewards (essences, fragments, liens, gloire)
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
			_apply_triade_effect({"type": "ADD_KARMA", "amount": -15})
			_apply_triade_effect({"type": "ADD_TENSION", "amount": 10})


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

# TRIADE getters
func get_aspect_state(aspect: String) -> int:
	return int(state.get("run", {}).get("aspects", {}).get(aspect, MerlinConstants.AspectState.EQUILIBRE))


func get_aspect_name(aspect: String) -> String:
	var aspect_state: int = get_aspect_state(aspect)
	var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
	var states = info.get("states", {})
	return str(states.get(aspect_state, "Inconnu"))


func get_all_aspects() -> Dictionary:
	return state.get("run", {}).get("aspects", {}).duplicate()


func get_souffle() -> int:
	return int(state.get("run", {}).get("souffle", MerlinConstants.SOUFFLE_START))


func get_mission() -> Dictionary:
	return state.get("run", {}).get("mission", {}).duplicate()


func is_all_aspects_balanced() -> bool:
	var aspects = get_all_aspects()
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		if int(aspects.get(aspect, 0)) != MerlinConstants.AspectState.EQUILIBRE:
			return false
	return true


func count_extreme_aspects() -> int:
	var count: int = 0
	var aspects = get_all_aspects()
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var aspect_state: int = int(aspects.get(aspect, 0))
		if aspect_state != MerlinConstants.AspectState.EQUILIBRE:
			count += 1
	return count


func get_hidden_data() -> Dictionary:
	return state.get("run", {}).get("hidden", {}).duplicate()


# Legacy getters (deprecated but kept for compatibility)
func get_gauge(gauge_name: String) -> int:
	return int(state.get("run", {}).get("gauges", {}).get(gauge_name, 50))


func get_all_gauges() -> Dictionary:
	return state.get("run", {}).get("gauges", {}).duplicate()


# Common getters
func get_bestiole_bond() -> int:
	return int(state.get("bestiole", {}).get("bond", 50))


func get_bestiole_modifier() -> float:
	return cards.get_bestiole_modifier(state)


func is_run_active() -> bool:
	return bool(state.get("run", {}).get("active", false))


func get_mode() -> String:
	return str(state.get("mode", "triade"))


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

	# Check cost
	var cost: Dictionary = node.get("cost", {})
	var meta: Dictionary = state.get("meta", {})
	for currency in cost:
		if currency == "fragments":
			if int(meta.get("ogham_fragments", 0)) < int(cost[currency]):
				return false
		else:
			var essence_val: int = int(meta.get("essence", {}).get(currency, 0))
			if essence_val < int(cost[currency]):
				return false
	return true


func unlock_talent(node_id: String) -> Dictionary:
	if not can_unlock_talent(node_id):
		return {"ok": false, "error": "Cannot unlock"}

	var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
	var cost: Dictionary = node.get("cost", {})

	# Spend currency
	for currency in cost:
		if currency == "fragments":
			state.meta.ogham_fragments -= int(cost[currency])
		else:
			state.meta.essence[currency] -= int(cost[currency])

	# Add to unlocked list
	state.meta.talent_tree.unlocked.append(node_id)

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
# RUN REWARDS — Essence + Fragments + Liens + Gloire (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

func calculate_run_rewards(run_data: Dictionary) -> Dictionary:
	var rewards: Dictionary = {"essence": {}, "fragments": 0, "liens": 0, "gloire": 0}

	# Initialize all essences to 0
	for element in MerlinConstants.ELEMENTS:
		rewards.essence[element] = 0

	# Base rewards (always)
	for elem in MerlinConstants.ESSENCE_BASE_REWARDS:
		rewards.essence[elem] += int(MerlinConstants.ESSENCE_BASE_REWARDS[elem])

	# Victory vs Chute
	var is_victory: bool = bool(run_data.get("victory", false))
	if is_victory:
		for elem in MerlinConstants.ESSENCE_VICTORY_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_VICTORY_BONUS[elem])
	else:
		for elem in MerlinConstants.ESSENCE_CHUTE_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_CHUTE_BONUS[elem])

	# Flux-based rewards
	var flux: Dictionary = run_data.get("flux", {})
	if int(flux.get("terre", 50)) >= 70:
		var r: Dictionary = MerlinConstants.FLUX_ESSENCE_REWARDS.get("terre_high", {}).get("rewards", {})
		for elem in r:
			rewards.essence[elem] += int(r[elem])
	if int(flux.get("terre", 50)) <= 30:
		var r: Dictionary = MerlinConstants.FLUX_ESSENCE_REWARDS.get("terre_low", {}).get("rewards", {})
		for elem in r:
			rewards.essence[elem] += int(r[elem])
	if int(flux.get("esprit", 30)) >= 70:
		var r: Dictionary = MerlinConstants.FLUX_ESSENCE_REWARDS.get("esprit_high", {}).get("rewards", {})
		for elem in r:
			rewards.essence[elem] += int(r[elem])
	if int(flux.get("lien", 40)) >= 70:
		var r: Dictionary = MerlinConstants.FLUX_ESSENCE_REWARDS.get("lien_high", {}).get("rewards", {})
		for elem in r:
			rewards.essence[elem] += int(r[elem])

	# Balanced aspects bonus
	var all_balanced: bool = bool(run_data.get("all_balanced", false))
	if all_balanced:
		for elem in MerlinConstants.ESSENCE_BALANCED_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_BALANCED_BONUS[elem])

	# Bond bonus
	if int(run_data.get("bond", 0)) > 70:
		for elem in MerlinConstants.ESSENCE_BOND_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_BOND_BONUS[elem])

	# Mini-game bonus
	if int(run_data.get("minigames_won", 0)) >= 5:
		for elem in MerlinConstants.ESSENCE_MINIGAME_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_MINIGAME_BONUS[elem])

	# Ogham bonus
	if int(run_data.get("oghams_used", 0)) >= 3:
		for elem in MerlinConstants.ESSENCE_OGHAM_BONUS:
			rewards.essence[elem] += int(MerlinConstants.ESSENCE_OGHAM_BONUS[elem])

	# Fragments: 1 + floor(awen_spent / 3), max 3
	var awen_spent: int = int(run_data.get("awen_spent", 0))
	rewards.fragments = mini(1 + int(awen_spent / 3), 3)

	# Liens: 2 + mission bonus
	rewards.liens = 2 + (5 if is_victory else 0)

	# Gloire: score/50 + first ending bonus
	var score: int = int(run_data.get("score", 0))
	rewards.gloire = int(score / 50)
	var ending_title: String = str(run_data.get("ending_title", ""))
	if ending_title != "" and not state.meta.endings_seen.has(ending_title):
		rewards.gloire += 20

	return rewards


func apply_run_rewards(rewards: Dictionary) -> void:
	# Apply essences
	var ess: Dictionary = rewards.get("essence", {})
	for elem in ess:
		if state.meta.essence.has(elem):
			state.meta.essence[elem] += int(ess[elem])

	# Apply fragments
	state.meta.ogham_fragments += int(rewards.get("fragments", 0))

	# Apply liens
	state.meta.liens += int(rewards.get("liens", 0))

	# Apply gloire
	state.meta.gloire_points += int(rewards.get("gloire", 0))

	state_changed.emit(state)


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE EVOLUTION (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

func get_bestiole_evolution_stage() -> int:
	return int(state.get("meta", {}).get("bestiole_evolution", {}).get("stage", 1))


func get_bestiole_evolution_path() -> String:
	return str(state.get("meta", {}).get("bestiole_evolution", {}).get("path", ""))


func check_bestiole_evolution() -> Dictionary:
	var current_stage: int = get_bestiole_evolution_stage()
	if current_stage >= 3:
		return {"can_evolve": false}

	var next_stage: int = current_stage + 1
	var stage_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_STAGES.get(next_stage, {})
	var runs_required: int = int(stage_data.get("runs_required", 999))
	var essence_cost: Dictionary = stage_data.get("essence_cost", {})

	if int(state.meta.total_runs) < runs_required:
		return {"can_evolve": false, "reason": "runs", "need": runs_required, "have": state.meta.total_runs}

	for elem in essence_cost:
		if int(state.meta.essence.get(elem, 0)) < int(essence_cost[elem]):
			return {"can_evolve": false, "reason": "essence", "need_elem": elem, "need": essence_cost[elem]}

	return {"can_evolve": true, "next_stage": next_stage, "name": stage_data.get("name", "")}


func evolve_bestiole(path: String = "") -> Dictionary:
	var check: Dictionary = check_bestiole_evolution()
	if not check.get("can_evolve", false):
		return {"ok": false}

	var next_stage: int = int(check.get("next_stage", 2))
	var stage_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_STAGES.get(next_stage, {})

	# Spend stage essence cost
	for elem in stage_data.get("essence_cost", {}):
		state.meta.essence[elem] -= int(stage_data.essence_cost[elem])

	# Apply evolution path if provided (typically for stage 2 → 3)
	if path != "":
		var path_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_PATHS.get(path, {})
		if path_data.is_empty():
			return {"ok": false, "error": "Invalid evolution path: " + path}
		# Check and spend path cost
		var path_cost: Dictionary = path_data.get("cost", {})
		for elem in path_cost:
			if int(state.meta.essence.get(elem, 0)) < int(path_cost[elem]):
				return {"ok": false, "error": "Cannot afford path cost"}
		for elem in path_cost:
			state.meta.essence[elem] -= int(path_cost[elem])
		state.meta.bestiole_evolution.path = path

	state.meta.bestiole_evolution.stage = next_stage
	state_changed.emit(state)
	return {"ok": true, "stage": next_stage, "name": stage_data.get("name", ""), "path": path}


func can_afford_evolution_path(path_id: String) -> bool:
	"""Check if player can afford a specific evolution path cost."""
	var path_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_PATHS.get(path_id, {})
	if path_data.is_empty():
		return false
	var cost: Dictionary = path_data.get("cost", {})
	for elem in cost:
		if int(state.meta.essence.get(elem, 0)) < int(cost[elem]):
			return false
	return true


func get_bestiole_bond_start() -> int:
	var stage: int = get_bestiole_evolution_stage()
	var stage_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_STAGES.get(stage, {})
	var base_bond: int = int(stage_data.get("bond_base", 10))
	var previous_bond: int = int(state.get("bestiole", {}).get("bond", 50))
	return maxi(int(previous_bond * MerlinConstants.BESTIOLE_BOND_RETENTION), base_bond)
