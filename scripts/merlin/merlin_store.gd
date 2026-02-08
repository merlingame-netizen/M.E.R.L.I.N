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

	# Initialize MERLIN OMNISCIENT SYSTEM
	_init_merlin_omniscient()

	state = build_default_state()
	_emit_state_changed()


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
			# Reigns meta (NEW)
			"total_runs": 0,
			"total_cards_played": 0,
			"endings_seen": [],
			"gloire_points": 0,
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
			state["run"]["map_seed"] = seed_val
			state["phase"] = "card"
			state["mode"] = "triade"
			_log_transition("triade_run_start", {"seed": seed_val})
			# Notify MERLIN OMNISCIENT
			if merlin != null:
				merlin.on_run_start()
			return {"ok": true}

		"TRIADE_GET_CARD":
			var card: Dictionary
			# Use MERLIN OMNISCIENT if available
			if merlin != null:
				card = await merlin.generate_card(state)
			else:
				card = cards.get_next_card(state)
			return {"ok": true, "card": card}

		"TRIADE_RESOLVE_CHOICE":
			var card = action.get("card", {})
			var option: int = int(action.get("option", MerlinConstants.CardOption.LEFT))
			var result = _resolve_triade_choice(card, option)
			if result["ok"]:
				# Record choice with MERLIN OMNISCIENT
				if merlin != null:
					merlin.record_choice(card, option, state)
				card_resolved.emit(card.get("id", ""), option)
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
			var card = cards.get_next_card(state)
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
	run["hidden"] = {
		"karma": 0,
		"tension": 0,
		"player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0},
		"resonances_active": [],
		"narrative_debt": [],
	}
	state["run"] = run


func _shift_aspect(aspect: String, direction: String) -> Dictionary:
	if aspect not in MerlinConstants.TRIADE_ASPECTS:
		return {"ok": false, "error": "Invalid aspect: " + aspect}

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
		_add_souffle(1)


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

	if counter >= MerlinConstants.AWEN_REGEN_INTERVAL:
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


func _resolve_triade_choice(card: Dictionary, option: int) -> Dictionary:
	var run = state.get("run", {})

	# Handle center option cost
	if option == MerlinConstants.CardOption.CENTER:
		var souffle_result = _use_souffle(MerlinConstants.SOUFFLE_CENTER_COST)
		if souffle_result.get("risk", false):
			# Apply risk: 50% normal, 25% random down, 25% random up
			var roll: float = rng.randf()
			if roll < MerlinConstants.SOUFFLE_EMPTY_RISK["normal"]:
				pass  # Normal effect
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

	# Update run state
	run["cards_played"] = int(run.get("cards_played", 0)) + 1
	state["run"] = run

	# Update player profile based on choice
	_update_player_profile(option)

	# Tick Ogham cooldowns and Awen regen
	tick_cooldowns()
	_tick_awen_regen()

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
	_log_transition("triade_run_end", end_check)
	run_ended.emit(end_check)


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
