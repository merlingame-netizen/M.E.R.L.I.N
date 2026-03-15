## =============================================================================
## Unit Tests -- Anam Economy (cross-run currency)
## =============================================================================
## Tests: death penalty formula, accumulation, cross-run persistence,
## edge cases (0 cards, 0 anam, negative guard), victory vs death rewards.
## Bible v2.4 s.2.4: Anam final = Anam_calc x min(cards_played / 30, 1.0)
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

## Build a minimal MerlinStore-compatible state for reward calculation.
## The store's calculate_run_rewards reads from state.meta.faction_rep and
## talent_tree, so we wire those up here.
func _make_store() -> MerlinStore:
	var store: MerlinStore = MerlinStore.new()
	# Minimal init without signals/children -- just set state dict
	store.state = {
		"run": {
			"life_essence": 50,
			"anam": 0,
			"cards_played": 0,
		},
		"meta": {
			"anam": 0,
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10,
				"niamh": 10, "ankou": 10,
			},
			"talent_tree": {
				"unlocked": [],
			},
			"stats": {},
		},
	}
	return store


func _make_run_data(cards_played: int, victory: bool, minigames_won: int = 0, oghams_used: int = 0) -> Dictionary:
	return {
		"cards_played": cards_played,
		"victory": victory,
		"minigames_won": minigames_won,
		"oghams_used": oghams_used,
		"life_at_end": 50,
	}


# =============================================================================
# CONSTANTS VERIFICATION
# =============================================================================

func test_anam_constants_exist() -> bool:
	if MerlinConstants.ANAM_BASE_REWARD != 10:
		push_error("ANAM_BASE_REWARD: expected 10, got %d" % MerlinConstants.ANAM_BASE_REWARD)
		return false
	if MerlinConstants.ANAM_VICTORY_BONUS != 15:
		push_error("ANAM_VICTORY_BONUS: expected 15, got %d" % MerlinConstants.ANAM_VICTORY_BONUS)
		return false
	var death_cap: int = int(MerlinConstants.ANAM_REWARDS.get("death_cap_cards", -1))
	if death_cap != 30:
		push_error("death_cap_cards: expected 30, got %d" % death_cap)
		return false
	return true


func test_anam_rewards_dict_keys() -> bool:
	var rewards: Dictionary = MerlinConstants.ANAM_REWARDS
	var required_keys: Array[String] = ["base", "victory_bonus", "death_cap_cards"]
	for key in required_keys:
		if not rewards.has(key):
			push_error("ANAM_REWARDS missing key: %s" % key)
			return false
	return true


# =============================================================================
# DEATH PENALTY FORMULA: min(cards_played / 30, 1.0)
# =============================================================================

func test_death_zero_cards_gives_zero_anam() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(0, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# 0 cards / 30 = 0.0 ratio -> base(10) * 0.0 = 0
	if anam != 0:
		push_error("Death at 0 cards: expected 0 anam, got %d" % anam)
		return false
	return true


func test_death_at_15_cards_gives_half_anam() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(15, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# 15/30 = 0.5 -> base(10) * 0.5 = 5
	if anam != 5:
		push_error("Death at 15 cards: expected 5 anam, got %d" % anam)
		return false
	return true


func test_death_at_10_cards_gives_third_anam() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(10, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# 10/30 = 0.333 -> base(10) * 0.333 = int(3.33) = 3
	if anam != 3:
		push_error("Death at 10 cards: expected 3 anam, got %d" % anam)
		return false
	return true


func test_death_at_30_cards_gives_full_anam() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(30, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# 30/30 = 1.0 -> base(10) * 1.0 = 10
	if anam != 10:
		push_error("Death at 30 cards: expected 10 anam, got %d" % anam)
		return false
	return true


func test_death_at_45_cards_capped_at_full() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(45, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# min(45/30, 1.0) = 1.0 -> base(10) * 1.0 = 10 (cap, not 15)
	if anam != 10:
		push_error("Death at 45 cards: expected 10 anam (capped), got %d" % anam)
		return false
	return true


func test_death_at_1_card_gives_minimal_anam() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(1, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# 1/30 = 0.033 -> base(10) * 0.033 = int(0.33) = 0
	if anam != 0:
		push_error("Death at 1 card: expected 0 anam, got %d" % anam)
		return false
	return true


# =============================================================================
# VICTORY (no penalty)
# =============================================================================

func test_victory_no_penalty_applied() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(10, true)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# Victory: base(10) + victory_bonus(15) = 25 (no penalty even at 10 cards)
	if anam != 25:
		push_error("Victory at 10 cards: expected 25 anam, got %d" % anam)
		return false
	return true


func test_victory_base_plus_bonus() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(30, true)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	if anam != 25:
		push_error("Victory base+bonus: expected 25, got %d" % anam)
		return false
	return true


# =============================================================================
# ACCUMULATION (minigames, oghams, faction honore)
# =============================================================================

func test_minigame_bonus_accumulates() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(30, true, 5, 0)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# Victory: 10 + 15 + 5*2(minigames) = 35
	if anam != 35:
		push_error("Minigame bonus: expected 35, got %d" % anam)
		return false
	return true


func test_ogham_bonus_accumulates() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(30, true, 0, 3)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# Victory: 10 + 15 + 3*1(oghams) = 28
	if anam != 28:
		push_error("Ogham bonus: expected 28, got %d" % anam)
		return false
	return true


func test_faction_honore_bonus() -> bool:
	var store: MerlinStore = _make_store()
	# Set 2 factions to honored (>= 80)
	store.state["meta"]["faction_rep"]["druides"] = 85
	store.state["meta"]["faction_rep"]["anciens"] = 80
	var run_data: Dictionary = _make_run_data(30, true)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# Victory: 10 + 15 + 2*5(factions) = 35
	if anam != 35:
		push_error("Faction honore bonus: expected 35, got %d" % anam)
		return false
	return true


func test_death_penalty_applies_to_total_with_bonuses() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(15, false, 5, 2)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	# Death: base(10) + 5*2(minigames) + 2*1(oghams) = 22
	# Penalty: 22 * min(15/30, 1.0) = 22 * 0.5 = int(11.0) = 11
	if anam != 11:
		push_error("Death with bonuses at 15 cards: expected 11, got %d" % anam)
		return false
	return true


# =============================================================================
# CROSS-RUN PERSISTENCE
# =============================================================================

func test_apply_rewards_adds_to_meta_anam() -> bool:
	var store: MerlinStore = _make_store()
	store.state["meta"]["anam"] = 50
	# Manually build rewards dict (simulating calculate_run_rewards output)
	var rewards: Dictionary = {"anam": 10, "victory": false, "cards_played": 30, "minigames_won": 0, "oghams_used": 0, "biome": ""}
	store.apply_run_rewards(rewards)
	var meta_anam: int = int(store.state["meta"]["anam"])
	if meta_anam != 60:
		push_error("Cross-run persistence: expected 60, got %d" % meta_anam)
		return false
	return true


func test_apply_rewards_tracks_total_anam_earned() -> bool:
	var store: MerlinStore = _make_store()
	store.state["meta"]["stats"] = {"total_anam_earned": 100}
	var rewards: Dictionary = {"anam": 25, "victory": true, "cards_played": 30, "minigames_won": 0, "oghams_used": 0, "biome": ""}
	store.apply_run_rewards(rewards)
	var total: int = int(store.state["meta"]["stats"]["total_anam_earned"])
	if total != 125:
		push_error("Total anam earned: expected 125, got %d" % total)
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_negative_anam_guard() -> bool:
	var store: MerlinStore = _make_store()
	# Even with death at 0 cards, anam should be 0, not negative
	var run_data: Dictionary = _make_run_data(0, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var anam: int = int(rewards.get("anam", -1))
	if anam < 0:
		push_error("Negative anam guard: anam should never be < 0, got %d" % anam)
		return false
	return true


func test_rewards_dict_includes_cards_played() -> bool:
	var store: MerlinStore = _make_store()
	var run_data: Dictionary = _make_run_data(17, false)
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	var cards: int = int(rewards.get("cards_played", -1))
	if cards != 17:
		push_error("Rewards should include cards_played=17, got %d" % cards)
		return false
	return true


func test_rewards_dict_includes_victory_flag() -> bool:
	var store: MerlinStore = _make_store()
	var run_data_win: Dictionary = _make_run_data(30, true)
	var rewards_win: Dictionary = store.calculate_run_rewards(run_data_win)
	if not bool(rewards_win.get("victory", false)):
		push_error("Rewards should include victory=true for victory run")
		return false
	var run_data_death: Dictionary = _make_run_data(30, false)
	var rewards_death: Dictionary = store.calculate_run_rewards(run_data_death)
	if bool(rewards_death.get("victory", true)):
		push_error("Rewards should include victory=false for death run")
		return false
	return true


func test_add_anam_effect_engine_accumulates_in_run() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {
		"run": {"anam": 0},
		"meta": {"anam": 100},
	}
	engine._apply_add_anam(state, 5)
	if int(state["run"]["anam"]) != 5:
		push_error("ADD_ANAM run: expected 5, got %d" % int(state["run"]["anam"]))
		return false
	if int(state["meta"]["anam"]) != 105:
		push_error("ADD_ANAM meta: expected 105, got %d" % int(state["meta"]["anam"]))
		return false
	# Second application
	engine._apply_add_anam(state, 3)
	if int(state["run"]["anam"]) != 8:
		push_error("ADD_ANAM run after 2nd: expected 8, got %d" % int(state["run"]["anam"]))
		return false
	if int(state["meta"]["anam"]) != 108:
		push_error("ADD_ANAM meta after 2nd: expected 108, got %d" % int(state["meta"]["anam"]))
		return false
	return true


func test_add_anam_zero_amount_rejected() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = {
		"run": {"anam": 10},
		"meta": {"anam": 50},
	}
	var result: bool = engine._apply_add_anam(state, 0)
	if result:
		push_error("ADD_ANAM with 0 should return false (rejected)")
		return false
	if int(state["run"]["anam"]) != 10:
		push_error("ADD_ANAM 0: run anam should stay 10, got %d" % int(state["run"]["anam"]))
		return false
	return true


# =============================================================================
# RUN ALL
# =============================================================================

func run_all() -> void:
	var tests: Array[Callable] = [
		# Constants
		test_anam_constants_exist,
		test_anam_rewards_dict_keys,
		# Death penalty formula
		test_death_zero_cards_gives_zero_anam,
		test_death_at_15_cards_gives_half_anam,
		test_death_at_10_cards_gives_third_anam,
		test_death_at_30_cards_gives_full_anam,
		test_death_at_45_cards_capped_at_full,
		test_death_at_1_card_gives_minimal_anam,
		# Victory
		test_victory_no_penalty_applied,
		test_victory_base_plus_bonus,
		# Accumulation
		test_minigame_bonus_accumulates,
		test_ogham_bonus_accumulates,
		test_faction_honore_bonus,
		test_death_penalty_applies_to_total_with_bonuses,
		# Cross-run persistence
		test_apply_rewards_adds_to_meta_anam,
		test_apply_rewards_tracks_total_anam_earned,
		# Edge cases
		test_negative_anam_guard,
		test_rewards_dict_includes_cards_played,
		test_rewards_dict_includes_victory_flag,
		test_add_anam_effect_engine_accumulates_in_run,
		test_add_anam_zero_amount_rejected,
	]

	var passed: int = 0
	var failed: int = 0

	for test in tests:
		var ok: bool = test.call()
		if ok:
			passed += 1
		else:
			failed += 1

	print("[test_anam_economy] %d passed, %d failed (total %d)" % [passed, failed, tests.size()])
