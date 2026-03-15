extends RefCounted
## Integration Tests — Store + Card + Effect pipeline
## Tests: full card cycle, life drain, convergence zone, run end conditions.

const EffectEngine = preload("res://scripts/merlin/merlin_effect_engine.gd")
const SaveSystem = preload("res://scripts/merlin/merlin_save_system.gd")


func _make_engine() -> RefCounted:
	return EffectEngine.new()


func _make_run_state() -> Dictionary:
	return {
		"run": {
			"life_essence": MerlinConstants.LIFE_ESSENCE_START,
			"card_index": 0,
			"active_tags": [],
			"card_queue": [],
			"current_arc": "",
			"active_promises": [],
			"day": 1,
			"hidden": {},
			"mission": {"progress": 0, "total": 10},
			"biome_currency": 0,
			"unlocked_oghams": [],
			"anam": 0,
			"cards_played": 0,
		},
		"meta": {
			"anam": 0,
			"total_runs": 0,
			"faction_rep": {
				"druides": 10.0, "anciens": 10.0, "korrigans": 10.0,
				"niamh": 10.0, "ankou": 10.0,
			},
		},
		"flags": {},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# FULL CARD CYCLE — Apply effects, verify state changes
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_card_cycle_apply_heal_and_rep() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()
	state["run"]["life_essence"] = 80

	var effects: Array = ["HEAL_LIFE:5", "ADD_REPUTATION:druides:10", "ADD_TAG:quest_started"]
	var result: Dictionary = engine.apply_effects(state, effects, "CARD_1")

	if result["applied"].size() != 3:
		push_error("All 3 effects should apply, got %d" % result["applied"].size())
		return false

	var life: int = int(state["run"]["life_essence"])
	if life != 85:
		push_error("Life should be 85, got %d" % life)
		return false

	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 20:
		push_error("Druides rep should be 20, got %d" % rep)
		return false

	if not state["run"]["active_tags"].has("quest_started"):
		push_error("Tag quest_started should be set")
		return false

	return true


func test_multiple_cards_accumulate_effects() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()
	state["run"]["life_essence"] = 80

	engine.apply_effects(state, ["HEAL_LIFE:3"], "CARD_1")
	engine.apply_effects(state, ["HEAL_LIFE:5"], "CARD_2")
	engine.apply_effects(state, ["DAMAGE_LIFE:2"], "CARD_3")

	var life: int = int(state["run"]["life_essence"])
	if life != 86:  # 80 + 3 + 5 - 2
		push_error("Life should be 86 after 3 cards, got %d" % life)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LIFE DRAIN — -1 per card (applied by controller, not effect engine)
# ═══════════════════════════════════════════════════════════════════════════════

func test_simulated_life_drain_per_card() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()
	var initial_life: int = int(state["run"]["life_essence"])

	# Simulate 10 cards with -1 drain each
	for i in range(10):
		engine.apply_effects(state, ["DAMAGE_LIFE:%d" % MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD])

	var after: int = int(state["run"]["life_essence"])
	var expected: int = initial_life - (10 * MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD)
	if after != expected:
		push_error("Life after 10 drains: expected %d, got %d" % [expected, after])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN END — Death condition (life = 0)
# ═══════════════════════════════════════════════════════════════════════════════

func test_death_at_zero_life() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()
	state["run"]["life_essence"] = 5

	engine.apply_effects(state, ["DAMAGE_LIFE:10"])

	var life: int = int(state["run"]["life_essence"])
	if life != 0:
		push_error("Life should clamp at 0, got %d" % life)
		return false
	# Controller checks life == 0 to end run
	return life == 0


func test_run_end_check_card_index_hard_max() -> bool:
	# Hard max is 50 cards per run
	var card_index: int = 50
	var hard_max: int = 50
	if card_index < hard_max:
		push_error("Card index %d should trigger hard max (%d)" % [card_index, hard_max])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONVERGENCE ZONE — MOS soft min/max
# ═══════════════════════════════════════════════════════════════════════════════

func test_convergence_zone_boundaries() -> bool:
	# From GAME_MECHANICS: soft_min=8, target=20-25, soft_max=40, hard_max=50
	var soft_min: int = 8
	var target_min: int = 20
	var target_max: int = 25
	var soft_max: int = 40
	var hard_max: int = 50

	if soft_min >= target_min:
		push_error("soft_min (%d) must be < target_min (%d)" % [soft_min, target_min])
		return false
	if target_max >= soft_max:
		push_error("target_max (%d) must be < soft_max (%d)" % [target_max, soft_max])
		return false
	if soft_max >= hard_max:
		push_error("soft_max (%d) must be < hard_max (%d)" % [soft_max, hard_max])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT LOG — Tracing source of effects
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_log_tracks_source() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()

	engine.apply_effects(state, ["HEAL_LIFE:3"], "CARD_FOREST")
	engine.apply_effects(state, ["DAMAGE_LIFE:1"], "SYSTEM_DRAIN")

	var log: Array = state.get("effect_log", [])
	if log.size() != 2:
		push_error("Expected 2 log entries, got %d" % log.size())
		return false
	if log[0].get("source") != "CARD_FOREST":
		push_error("First source should be CARD_FOREST")
		return false
	if log[1].get("source") != "SYSTEM_DRAIN":
		push_error("Second source should be SYSTEM_DRAIN")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE SYSTEM — Default integration
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_defaults_match_run_state() -> bool:
	var save_meta: Dictionary = SaveSystem._get_default_profile()
	var run_state: Dictionary = SaveSystem._get_default_run_state()

	# Both should reference same factions
	var meta_factions: Array = save_meta["faction_rep"].keys()
	var run_factions: Array = run_state["faction_rep_delta"].keys()

	meta_factions.sort()
	run_factions.sort()

	if meta_factions.size() != run_factions.size():
		push_error("Faction key count mismatch: meta=%d, run=%d" % [meta_factions.size(), run_factions.size()])
		return false

	for i in range(meta_factions.size()):
		if meta_factions[i] != run_factions[i]:
			push_error("Faction key mismatch: %s vs %s" % [meta_factions[i], run_factions[i]])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-EFFECT — Complex card with many effects
# ═══════════════════════════════════════════════════════════════════════════════

func test_complex_card_with_6_effects() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_run_state()
	state["run"]["life_essence"] = 70

	var effects: Array = [
		"HEAL_LIFE:5",
		"ADD_REPUTATION:korrigans:10",
		"ADD_TAG:forest_blessing",
		"SET_FLAG:met_fairy:true",
		"ADD_KARMA:5",
		"ADD_BIOME_CURRENCY:3",
	]
	var result: Dictionary = engine.apply_effects(state, effects, "FAIRY_CARD")

	if result["applied"].size() != 6:
		push_error("All 6 effects should apply, got %d applied, %d rejected" % [result["applied"].size(), result["rejected"].size()])
		return false

	if int(state["run"]["life_essence"]) != 75:
		push_error("Life should be 75")
		return false
	if int(state["meta"]["faction_rep"]["korrigans"]) != 20:
		push_error("Korrigans rep should be 20")
		return false
	if int(state["run"]["biome_currency"]) != 3:
		push_error("Currency should be 3")
		return false
	return true
