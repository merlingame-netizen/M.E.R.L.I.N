## ═══════════════════════════════════════════════════════════════════════════════
## Test DifficultyAdapter — Unit tests for dynamic difficulty scaling
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: initialization, pity system, effect scaling, card weighting,
##           crisis detection, card complexity, debug info.
## Run via: python tools/cli.py godot test
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name — test runner discovers by filename prefix

# ─── helpers ────────────────────────────────────────────────────────────────

func _make_adapter() -> DifficultyAdapter:
	return DifficultyAdapter.new()


func _make_context(life: int = 50, gauges: Dictionary = {}, faction_deltas: Dictionary = {}) -> Dictionary:
	return {
		"life_essence": life,
		"gauges": gauges,
		"faction_rep_delta": faction_deltas,
	}


func _make_card(tags: Array = [], options: Array = []) -> Dictionary:
	return {
		"tags": tags,
		"options": options,
	}


func _make_option(effects: Array) -> Dictionary:
	return {"effects": effects}


func _make_effect(value: int) -> Dictionary:
	return {"value": value}


# ─── T01: default state values ───────────────────────────────────────────────

func test_default_state() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	if absf(a.player_skill - 0.5) > 0.001:
		push_error("Default player_skill should be 0.5, got %f" % a.player_skill)
		return false
	if a.consecutive_deaths != 0:
		push_error("Default consecutive_deaths should be 0, got %d" % a.consecutive_deaths)
		return false
	if a.pity_mode_active != false:
		push_error("Default pity_mode_active should be false")
		return false
	if a.pity_cards_remaining != 0:
		push_error("Default pity_cards_remaining should be 0, got %d" % a.pity_cards_remaining)
		return false
	return true


# ─── T02: enable_pity_mode sets correct state ────────────────────────────────

func test_enable_pity_mode() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.enable_pity_mode()
	if not a.pity_mode_active:
		push_error("pity_mode_active should be true after enable_pity_mode()")
		return false
	if a.pity_cards_remaining != DifficultyAdapter.PITY_DURATION_CARDS:
		push_error("pity_cards_remaining should be %d, got %d" % [
			DifficultyAdapter.PITY_DURATION_CARDS, a.pity_cards_remaining])
		return false
	return true


# ─── T03: disable_pity_mode clears state ─────────────────────────────────────

func test_disable_pity_mode() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.enable_pity_mode()
	a.disable_pity_mode()
	if a.pity_mode_active:
		push_error("pity_mode_active should be false after disable_pity_mode()")
		return false
	if a.pity_cards_remaining != 0:
		push_error("pity_cards_remaining should be 0 after disable, got %d" % a.pity_cards_remaining)
		return false
	return true


# ─── T04: on_death increments consecutive_deaths ─────────────────────────────

func test_on_death_increments_consecutive() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.on_death(30)  # long run, not a quick death
	if a.consecutive_deaths != 1:
		push_error("consecutive_deaths should be 1 after one death, got %d" % a.consecutive_deaths)
		return false
	a.on_death(30)
	if a.consecutive_deaths != 2:
		push_error("consecutive_deaths should be 2 after two deaths, got %d" % a.consecutive_deaths)
		return false
	return true


# ─── T05: on_death auto-triggers pity at threshold ───────────────────────────

func test_on_death_triggers_pity_at_threshold() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	var threshold: int = DifficultyAdapter.PITY_THRESHOLD_DEATHS
	for i in range(threshold - 1):
		a.on_death(30)
		if a.pity_mode_active:
			push_error("Pity should not activate before threshold (%d deaths)" % threshold)
			return false
	a.on_death(30)  # threshold reached
	if not a.pity_mode_active:
		push_error("Pity should activate at threshold=%d deaths" % threshold)
		return false
	return true


# ─── T06: on_death counts quick deaths correctly ─────────────────────────────

func test_on_death_counts_quick_deaths() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	var quick_threshold: int = DifficultyAdapter.QUICK_DEATH_THRESHOLD
	a.on_death(quick_threshold - 1)  # below threshold = quick
	if a.session_quick_deaths != 1:
		push_error("run_length < threshold should count as quick death")
		return false
	a.on_death(quick_threshold)  # equal = NOT quick
	if a.session_quick_deaths != 1:
		push_error("run_length == threshold should NOT count as quick death")
		return false
	return true


# ─── T07: on_successful_run resets death counters ────────────────────────────

func test_on_successful_run_resets() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.on_death(30)
	a.on_death(30)
	a.enable_pity_mode()
	a.on_successful_run()
	if a.consecutive_deaths != 0:
		push_error("consecutive_deaths should be 0 after successful run, got %d" % a.consecutive_deaths)
		return false
	if a.pity_mode_active:
		push_error("pity_mode_active should be false after successful run")
		return false
	return true


# ─── T08: on_run_start resets cards_since_crisis ─────────────────────────────

func test_on_run_start_resets_crisis_counter() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.cards_since_crisis = 5
	a.on_run_start()
	if a.cards_since_crisis != 999:
		push_error("cards_since_crisis should be 999 after on_run_start, got %d" % a.cards_since_crisis)
		return false
	return true


# ─── T09: scale_effect returns 0 for base_value 0 ───────────────────────────

func test_scale_effect_zero_base() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	var ctx: Dictionary = _make_context()
	var result: int = a.scale_effect(0, "negative", ctx)
	if result != 0:
		push_error("scale_effect(0, ...) should return 0, got %d" % result)
		return false
	return true


# ─── T10: scale_effect — novice gets weaker negative effects ─────────────────

func test_scale_effect_novice_negative() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.0  # pure novice
	var ctx: Dictionary = _make_context()
	# skill_factor = lerp(0.6, 1.4, 0.0) = 0.6
	# negative → factor = 0.6
	var result: int = a.scale_effect(10, "negative", ctx)
	# Expected: round(10 * 0.6) = 6
	if result != 6:
		push_error("Novice negative effect: expected 6, got %d" % result)
		return false
	return true


# ─── T11: scale_effect — master gets stronger negative effects ───────────────

func test_scale_effect_master_negative() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 1.0  # master
	var ctx: Dictionary = _make_context()
	# skill_factor = lerp(0.6, 1.4, 1.0) = 1.4
	# negative → factor = 1.4
	var result: int = a.scale_effect(10, "negative", ctx)
	# Expected: round(10 * 1.4) = 14
	if result != 14:
		push_error("Master negative effect: expected 14, got %d" % result)
		return false
	return true


# ─── T12: scale_effect — novice gets stronger positive effects ───────────────

func test_scale_effect_novice_positive() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.0
	var ctx: Dictionary = _make_context()
	# positive → factor = 2.0 - skill_factor = 2.0 - 0.6 = 1.4
	var result: int = a.scale_effect(10, "positive", ctx)
	# Expected: round(10 * 1.4) = 14
	if result != 14:
		push_error("Novice positive effect: expected 14, got %d" % result)
		return false
	return true


# ─── T13: scale_effect — pity reduces negative effects ───────────────────────

func test_scale_effect_pity_reduces_negative() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5  # neutral skill
	a.enable_pity_mode()
	var ctx: Dictionary = _make_context()
	# skill_factor = lerp(0.6, 1.4, 0.5) = 1.0
	# negative → factor = 1.0, then pity * 0.6 = 0.6
	var result: int = a.scale_effect(10, "negative", ctx)
	# Expected: round(10 * 0.6) = 6
	if result != 6:
		push_error("Pity negative effect: expected 6, got %d" % result)
		return false
	return true


# ─── T14: scale_effect — pity increases positive effects ─────────────────────

func test_scale_effect_pity_boosts_positive() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	a.enable_pity_mode()
	var ctx: Dictionary = _make_context()
	# positive → factor = 2.0 - 1.0 = 1.0, then pity * 1.4 = 1.4
	var result: int = a.scale_effect(10, "positive", ctx)
	# Expected: round(10 * 1.4) = 14
	if result != 14:
		push_error("Pity positive effect: expected 14, got %d" % result)
		return false
	return true


# ─── T15: pity_cards_remaining depletes and auto-disables ────────────────────

func test_pity_auto_disables_after_duration() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	a.enable_pity_mode()
	var duration: int = DifficultyAdapter.PITY_DURATION_CARDS
	var ctx: Dictionary = _make_context()
	# Each scale_effect call on a pity-active adapter decrements remaining
	for i in range(duration):
		a.scale_effect(10, "negative", ctx)
	# After exactly duration calls, pity should be disabled
	if a.pity_mode_active:
		push_error("Pity should auto-disable after %d cards, still active" % duration)
		return false
	return true


# ─── T16: _is_in_crisis — low life triggers crisis ───────────────────────────

func test_crisis_low_life() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	# life < 20 should trigger crisis → factor multiplied
	var ctx_crisis: Dictionary = _make_context(15)
	var ctx_safe: Dictionary = _make_context(50)
	# With neutral skill, negative base factor = 1.0
	# Crisis: factor *= 0.5 → result = round(10 * 0.5) = 5
	var crisis_result: int = a.scale_effect(10, "negative", ctx_crisis)
	var safe_result: int = a.scale_effect(10, "negative", ctx_safe)
	if crisis_result >= safe_result:
		push_error("Crisis negative effect (%d) should be less than safe (%d)" % [crisis_result, safe_result])
		return false
	return true


# ─── T17: _is_in_crisis — low gauge value triggers crisis ────────────────────

func test_crisis_low_gauge() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	var gauges: Dictionary = {"mana": 10}  # < 15 → crisis
	var ctx: Dictionary = _make_context(50, gauges)
	var safe_ctx: Dictionary = _make_context(50)
	var crisis_result: int = a.scale_effect(10, "negative", ctx)
	var safe_result: int = a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		push_error("Low gauge crisis negative (%d) should be less than safe (%d)" % [crisis_result, safe_result])
		return false
	return true


# ─── T18: _is_in_crisis — two extreme faction deltas triggers crisis ──────────

func test_crisis_faction_deltas() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	# Two factions with abs(delta) > 15.0
	var factions: Dictionary = {"druides": 20.0, "ankou": -18.0}
	var ctx: Dictionary = _make_context(50, {}, factions)
	var safe_ctx: Dictionary = _make_context(50)
	var crisis_result: int = a.scale_effect(10, "negative", ctx)
	var safe_result: int = a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		push_error("Extreme faction deltas crisis (%d) should be less than safe (%d)" % [crisis_result, safe_result])
		return false
	return true


# ─── T19: consecutive_deaths mercy reduces negative effects ──────────────────

func test_consecutive_deaths_mercy() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	var ctx: Dictionary = _make_context()
	var base_result: int = a.scale_effect(100, "negative", ctx)
	a.on_death(30)  # consecutive_deaths = 1
	var mercy_result: int = a.scale_effect(100, "negative", ctx)
	if mercy_result >= base_result:
		push_error("Mercy after 1 death: result (%d) should be less than base (%d)" % [mercy_result, base_result])
		return false
	return true


# ─── T20: get_card_weight_modifier — dangerous card penalised when struggling ─

func test_card_weight_dangerous_card_penalised() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.on_death(30)  # consecutive_deaths = 1
	# Card with option having a large negative effect
	var effects: Array = [_make_effect(-25)]
	var options: Array = [_make_option(effects)]
	var card: Dictionary = _make_card([], options)
	var ctx: Dictionary = _make_context()
	var weight: float = a.get_card_weight_modifier(card, ctx)
	if weight > 0.31:
		push_error("Dangerous card with deaths should have weight ~0.3, got %f" % weight)
		return false
	return true


# ─── T21: get_card_weight_modifier — recovery card boosted in crisis ──────────

func test_card_weight_recovery_boosted_in_crisis() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.5
	var card: Dictionary = _make_card(["recovery"], [])
	var crisis_ctx: Dictionary = _make_context(10)  # life < 20 = crisis
	var safe_ctx: Dictionary = _make_context(50)
	var crisis_weight: float = a.get_card_weight_modifier(card, crisis_ctx)
	var safe_weight: float = a.get_card_weight_modifier(card, safe_ctx)
	if crisis_weight <= safe_weight:
		push_error("Recovery card weight in crisis (%f) should exceed safe (%f)" % [crisis_weight, safe_weight])
		return false
	return true


# ─── T22: get_card_weight_modifier — complex card penalised for novice ────────

func test_card_weight_complex_penalised_for_novice() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 0.2  # < 0.3 threshold
	# Complexity breakdown:
	#   3 options           → +0.3
	#   9 effects total     → +0.4 (capped at 0.4 since 9*0.1=0.9 > 0.4)
	#   "promise" tag       → +0.2
	#   "arc" tag           → +0.1
	#   minf(1.0, 1.0)      → 1.0 (> 0.7 threshold)
	# → weight *= 0.5
	var rich_opts: Array = []
	for i in range(3):
		rich_opts.append(_make_option([_make_effect(5), _make_effect(3), _make_effect(-2)]))
	var complex_card: Dictionary = _make_card(["promise", "arc"], rich_opts)
	var ctx: Dictionary = _make_context()
	var weight: float = a.get_card_weight_modifier(complex_card, ctx)
	if weight > 0.51:
		push_error("Complex card for novice should have weight ~0.5, got %f" % weight)
		return false
	return true


# ─── T23: get_debug_info — returns expected keys ─────────────────────────────

func test_debug_info_keys() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	var info: Dictionary = a.get_debug_info()
	var required_keys: Array = [
		"player_skill", "consecutive_deaths", "pity_mode_active",
		"pity_cards_remaining", "session_deaths", "session_quick_deaths",
	]
	for key in required_keys:
		if not info.has(key):
			push_error("debug_info missing key: %s" % key)
			return false
	return true


# ─── T24: scale_effect large positive value with master skill ────────────────

func test_scale_effect_large_positive_master() -> bool:
	var a: DifficultyAdapter = _make_adapter()
	a.player_skill = 1.0  # master
	var ctx: Dictionary = _make_context()
	# positive → factor = 2.0 - 1.4 = 0.6
	# Master players get weaker positive bonuses (earned them)
	var result: int = a.scale_effect(100, "positive", ctx)
	# Expected: round(100 * 0.6) = 60
	if result != 60:
		push_error("Master positive 100: expected 60, got %d" % result)
		return false
	return true


# ─── T25: constants have expected values ─────────────────────────────────────

func test_constants_values() -> bool:
	if DifficultyAdapter.PITY_THRESHOLD_DEATHS != 3:
		push_error("PITY_THRESHOLD_DEATHS should be 3, got %d" % DifficultyAdapter.PITY_THRESHOLD_DEATHS)
		return false
	if DifficultyAdapter.PITY_DURATION_CARDS != 10:
		push_error("PITY_DURATION_CARDS should be 10, got %d" % DifficultyAdapter.PITY_DURATION_CARDS)
		return false
	if DifficultyAdapter.QUICK_DEATH_THRESHOLD != 20:
		push_error("QUICK_DEATH_THRESHOLD should be 20, got %d" % DifficultyAdapter.QUICK_DEATH_THRESHOLD)
		return false
	if absf(DifficultyAdapter.MIN_SKILL_FACTOR - 0.6) > 0.001:
		push_error("MIN_SKILL_FACTOR should be 0.6, got %f" % DifficultyAdapter.MIN_SKILL_FACTOR)
		return false
	if absf(DifficultyAdapter.MAX_SKILL_FACTOR - 1.4) > 0.001:
		push_error("MAX_SKILL_FACTOR should be 1.4, got %f" % DifficultyAdapter.MAX_SKILL_FACTOR)
		return false
	return true
