## ═══════════════════════════════════════════════════════════════════════════════
## Test DifficultyAdapter — Unit tests for dynamic difficulty scaling
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: initialization, pity system, pity auto-disable, effect scaling,
##           card weighting, crisis detection (life/gauge/faction), card
##           complexity, debug info, constants, boundary values, edge cases.
## Run via: python tools/cli.py godot test
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name — test runner discovers by filename prefix

# ─── state ───────────────────────────────────────────────────────────────────

var _a: DifficultyAdapter

# ─── lifecycle ───────────────────────────────────────────────────────────────

func _init() -> void:
	_a = DifficultyAdapter.new()


# ─── helpers ─────────────────────────────────────────────────────────────────

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _reset() -> void:
	_a = DifficultyAdapter.new()


func _ctx(life: int = 50, gauges: Dictionary = {}, faction_deltas: Dictionary = {}) -> Dictionary:
	return {
		"life_essence": life,
		"gauges": gauges,
		"faction_rep_delta": faction_deltas,
	}


func _card(tags: Array = [], options: Array = []) -> Dictionary:
	return {"tags": tags, "options": options}


func _option(effects: Array) -> Dictionary:
	return {"effects": effects}


func _effect(value: int) -> Dictionary:
	return {"value": value}


# ─── T01: default state ───────────────────────────────────────────────────────

func test_default_player_skill() -> bool:
	_reset()
	if absf(_a.player_skill - 0.5) > 0.001:
		return _fail("Default player_skill should be 0.5, got %f" % _a.player_skill)
	return true


func test_default_pity_inactive() -> bool:
	_reset()
	if _a.pity_mode_active:
		return _fail("pity_mode_active should be false by default")
	if _a.pity_cards_remaining != 0:
		return _fail("pity_cards_remaining should be 0 by default, got %d" % _a.pity_cards_remaining)
	return true


func test_default_death_counters_zero() -> bool:
	_reset()
	if _a.consecutive_deaths != 0:
		return _fail("consecutive_deaths should be 0 by default, got %d" % _a.consecutive_deaths)
	if _a.session_deaths != 0:
		return _fail("session_deaths should be 0 by default, got %d" % _a.session_deaths)
	if _a.session_quick_deaths != 0:
		return _fail("session_quick_deaths should be 0 by default, got %d" % _a.session_quick_deaths)
	return true


func test_default_cards_since_crisis() -> bool:
	_reset()
	if _a.cards_since_crisis != 999:
		return _fail("cards_since_crisis should be 999 by default, got %d" % _a.cards_since_crisis)
	return true


# ─── T05: constants ───────────────────────────────────────────────────────────

func test_constants_values() -> bool:
	if DifficultyAdapter.PITY_THRESHOLD_DEATHS != 3:
		return _fail("PITY_THRESHOLD_DEATHS should be 3, got %d" % DifficultyAdapter.PITY_THRESHOLD_DEATHS)
	if DifficultyAdapter.PITY_DURATION_CARDS != 10:
		return _fail("PITY_DURATION_CARDS should be 10, got %d" % DifficultyAdapter.PITY_DURATION_CARDS)
	if DifficultyAdapter.QUICK_DEATH_THRESHOLD != 20:
		return _fail("QUICK_DEATH_THRESHOLD should be 20, got %d" % DifficultyAdapter.QUICK_DEATH_THRESHOLD)
	if absf(DifficultyAdapter.MIN_SKILL_FACTOR - 0.6) > 0.001:
		return _fail("MIN_SKILL_FACTOR should be 0.6, got %f" % DifficultyAdapter.MIN_SKILL_FACTOR)
	if absf(DifficultyAdapter.MAX_SKILL_FACTOR - 1.4) > 0.001:
		return _fail("MAX_SKILL_FACTOR should be 1.4, got %f" % DifficultyAdapter.MAX_SKILL_FACTOR)
	return true


# ─── T06: enable_pity_mode ───────────────────────────────────────────────────

func test_enable_pity_mode_sets_active_and_duration() -> bool:
	_reset()
	_a.enable_pity_mode()
	if not _a.pity_mode_active:
		return _fail("pity_mode_active should be true after enable_pity_mode()")
	if _a.pity_cards_remaining != DifficultyAdapter.PITY_DURATION_CARDS:
		return _fail("pity_cards_remaining should be %d, got %d" % [
			DifficultyAdapter.PITY_DURATION_CARDS, _a.pity_cards_remaining])
	return true


# ─── T07: disable_pity_mode ──────────────────────────────────────────────────

func test_disable_pity_mode_clears_state() -> bool:
	_reset()
	_a.enable_pity_mode()
	_a.disable_pity_mode()
	if _a.pity_mode_active:
		return _fail("pity_mode_active should be false after disable_pity_mode()")
	if _a.pity_cards_remaining != 0:
		return _fail("pity_cards_remaining should be 0 after disable, got %d" % _a.pity_cards_remaining)
	return true


# ─── T08: on_death — counting ────────────────────────────────────────────────

func test_on_death_increments_consecutive() -> bool:
	_reset()
	_a.on_death(30)
	if _a.consecutive_deaths != 1:
		return _fail("consecutive_deaths should be 1 after one death, got %d" % _a.consecutive_deaths)
	_a.on_death(30)
	if _a.consecutive_deaths != 2:
		return _fail("consecutive_deaths should be 2 after two deaths, got %d" % _a.consecutive_deaths)
	return true


func test_on_death_quick_death_counted_below_threshold() -> bool:
	_reset()
	var qt: int = DifficultyAdapter.QUICK_DEATH_THRESHOLD
	_a.on_death(qt - 1)
	if _a.session_quick_deaths != 1:
		return _fail("run_length < threshold should count as quick death, got %d" % _a.session_quick_deaths)
	return true


func test_on_death_not_quick_at_threshold() -> bool:
	_reset()
	var qt: int = DifficultyAdapter.QUICK_DEATH_THRESHOLD
	_a.on_death(qt)  # equal = NOT quick
	if _a.session_quick_deaths != 0:
		return _fail("run_length == threshold should NOT count as quick death, got %d" % _a.session_quick_deaths)
	return true


func test_on_death_auto_triggers_pity_at_threshold() -> bool:
	_reset()
	var threshold: int = DifficultyAdapter.PITY_THRESHOLD_DEATHS
	for i in range(threshold - 1):
		_a.on_death(30)
		if _a.pity_mode_active:
			return _fail("Pity should not activate before threshold (%d deaths), activated at %d" % [threshold, i + 1])
	_a.on_death(30)
	if not _a.pity_mode_active:
		return _fail("Pity should activate at threshold=%d deaths" % threshold)
	return true


func test_on_death_pity_not_triggered_below_threshold() -> bool:
	_reset()
	_a.on_death(30)
	_a.on_death(30)
	if _a.pity_mode_active:
		return _fail("Pity must not activate before %d deaths" % DifficultyAdapter.PITY_THRESHOLD_DEATHS)
	return true


# ─── T13: on_run_start ───────────────────────────────────────────────────────

func test_on_run_start_resets_cards_since_crisis() -> bool:
	_reset()
	_a.cards_since_crisis = 5
	_a.on_run_start()
	if _a.cards_since_crisis != 999:
		return _fail("cards_since_crisis should be 999 after on_run_start, got %d" % _a.cards_since_crisis)
	return true


func test_on_run_start_does_not_reset_consecutive_deaths() -> bool:
	_reset()
	_a.on_death(30)
	_a.on_death(30)
	_a.on_run_start()
	if _a.consecutive_deaths != 2:
		return _fail("on_run_start must NOT reset consecutive_deaths (session-based), got %d" % _a.consecutive_deaths)
	return true


# ─── T15: on_successful_run ──────────────────────────────────────────────────

func test_on_successful_run_resets_deaths_and_disables_pity() -> bool:
	_reset()
	_a.on_death(30)
	_a.on_death(30)
	_a.enable_pity_mode()
	_a.on_successful_run()
	if _a.consecutive_deaths != 0:
		return _fail("consecutive_deaths should be 0 after successful run, got %d" % _a.consecutive_deaths)
	if _a.pity_mode_active:
		return _fail("pity_mode_active should be false after successful run")
	return true


# ─── T16: scale_effect — zero base ───────────────────────────────────────────

func test_scale_effect_zero_base_returns_zero() -> bool:
	_reset()
	var result: int = _a.scale_effect(0, "negative", _ctx())
	if result != 0:
		return _fail("scale_effect(0, ...) should return 0, got %d" % result)
	return true


func test_scale_effect_zero_base_positive_returns_zero() -> bool:
	_reset()
	var result: int = _a.scale_effect(0, "positive", _ctx())
	if result != 0:
		return _fail("scale_effect(0, 'positive', ...) should return 0, got %d" % result)
	return true


# ─── T18: scale_effect — skill-based scaling ─────────────────────────────────

func test_scale_effect_novice_gets_weaker_negative() -> bool:
	_reset()
	_a.player_skill = 0.0
	# skill_factor = lerp(0.6, 1.4, 0.0) = 0.6 → negative: factor=0.6 → round(10*0.6)=6
	var result: int = _a.scale_effect(10, "negative", _ctx())
	if result != 6:
		return _fail("Novice negative: expected 6, got %d" % result)
	return true


func test_scale_effect_master_gets_stronger_negative() -> bool:
	_reset()
	_a.player_skill = 1.0
	# skill_factor = lerp(0.6, 1.4, 1.0) = 1.4 → negative: factor=1.4 → round(10*1.4)=14
	var result: int = _a.scale_effect(10, "negative", _ctx())
	if result != 14:
		return _fail("Master negative: expected 14, got %d" % result)
	return true


func test_scale_effect_novice_gets_stronger_positive() -> bool:
	_reset()
	_a.player_skill = 0.0
	# positive → factor = 2.0 - 0.6 = 1.4 → round(10*1.4)=14
	var result: int = _a.scale_effect(10, "positive", _ctx())
	if result != 14:
		return _fail("Novice positive: expected 14, got %d" % result)
	return true


func test_scale_effect_master_gets_weaker_positive() -> bool:
	_reset()
	_a.player_skill = 1.0
	# positive → factor = 2.0 - 1.4 = 0.6 → round(100*0.6)=60
	var result: int = _a.scale_effect(100, "positive", _ctx())
	if result != 60:
		return _fail("Master positive 100: expected 60, got %d" % result)
	return true


# ─── T22: scale_effect — pity adjustments ────────────────────────────────────

func test_pity_reduces_negative_effect() -> bool:
	_reset()
	_a.player_skill = 0.5
	_a.enable_pity_mode()
	# skill_factor=1.0 → negative factor=1.0, pity*0.6=0.6 → round(10*0.6)=6
	var result: int = _a.scale_effect(10, "negative", _ctx())
	if result != 6:
		return _fail("Pity negative: expected 6, got %d" % result)
	return true


func test_pity_boosts_positive_effect() -> bool:
	_reset()
	_a.player_skill = 0.5
	_a.enable_pity_mode()
	# positive factor=1.0, pity*1.4=1.4 → round(10*1.4)=14
	var result: int = _a.scale_effect(10, "positive", _ctx())
	if result != 14:
		return _fail("Pity positive: expected 14, got %d" % result)
	return true


func test_pity_auto_disables_after_duration() -> bool:
	_reset()
	_a.player_skill = 0.5
	_a.enable_pity_mode()
	var duration: int = DifficultyAdapter.PITY_DURATION_CARDS
	var ctx: Dictionary = _ctx()
	for i in range(duration):
		_a.scale_effect(10, "negative", ctx)
	if _a.pity_mode_active:
		return _fail("Pity should auto-disable after %d cards, still active" % duration)
	return true


# ─── T25: consecutive deaths mercy ───────────────────────────────────────────

func test_consecutive_deaths_mercy_reduces_negative() -> bool:
	_reset()
	_a.player_skill = 0.5
	var ctx: Dictionary = _ctx()
	var base_result: int = _a.scale_effect(100, "negative", ctx)
	_a.on_death(30)
	var mercy_result: int = _a.scale_effect(100, "negative", ctx)
	if mercy_result >= base_result:
		return _fail("Mercy after 1 death: result (%d) should be less than base (%d)" % [mercy_result, base_result])
	return true


func test_mercy_factor_capped_at_0_5() -> bool:
	# 6 deaths → mercy_factor = 1.0 - 0.6 = 0.4 < 0.5, so maxf(0.5, 0.4) = 0.5
	# factor for negative with skill=0.5 → 1.0 * 0.5 = 0.5 → round(100 * 0.5) = 50
	_reset()
	_a.player_skill = 0.5
	for i in range(6):
		_a.on_death(30)
	# Pity will have been triggered at death 3, but disable it to isolate mercy
	_a.disable_pity_mode()
	var ctx: Dictionary = _ctx()
	var result: int = _a.scale_effect(100, "negative", ctx)
	# mercy_factor = 1.0 - 0.6 = 0.4, capped to 0.5. base factor = 1.0, result = round(100 * 0.5) = 50
	if result > 50:
		return _fail("Mercy cap: expected at most 50 for 6 deaths, got %d" % result)
	return true


# ─── T27: crisis detection — life ────────────────────────────────────────────

func test_crisis_low_life_reduces_negative() -> bool:
	_reset()
	_a.player_skill = 0.5
	var crisis_ctx: Dictionary = _ctx(15)  # life < 20
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_result: int = _a.scale_effect(10, "negative", crisis_ctx)
	var safe_result: int = _a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		return _fail("Crisis (life<20) negative (%d) should be less than safe (%d)" % [crisis_result, safe_result])
	return true


func test_crisis_low_life_boosts_positive() -> bool:
	_reset()
	_a.player_skill = 0.5
	var crisis_ctx: Dictionary = _ctx(15)
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_result: int = _a.scale_effect(10, "positive", crisis_ctx)
	var safe_result: int = _a.scale_effect(10, "positive", safe_ctx)
	if crisis_result <= safe_result:
		return _fail("Crisis (life<20) positive (%d) should be more than safe (%d)" % [crisis_result, safe_result])
	return true


func test_crisis_life_boundary_exactly_20_not_crisis() -> bool:
	_reset()
	_a.player_skill = 0.5
	var boundary_ctx: Dictionary = _ctx(20)  # NOT < 20, so not crisis
	var safe_ctx: Dictionary = _ctx(50)
	# Both should produce equal results (no crisis modifier)
	var b_result: int = _a.scale_effect(10, "negative", boundary_ctx)
	var s_result: int = _a.scale_effect(10, "negative", safe_ctx)
	if b_result != s_result:
		return _fail("life=20 should not trigger crisis, boundary=%d safe=%d" % [b_result, s_result])
	return true


# ─── T30: crisis detection — gauge ───────────────────────────────────────────

func test_crisis_low_gauge_reduces_negative() -> bool:
	_reset()
	_a.player_skill = 0.5
	var ctx: Dictionary = _ctx(50, {"mana": 10})  # gauge < 15 = crisis
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_result: int = _a.scale_effect(10, "negative", ctx)
	var safe_result: int = _a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		return _fail("Low gauge crisis negative (%d) should be less than safe (%d)" % [crisis_result, safe_result])
	return true


func test_crisis_high_gauge_triggers_crisis() -> bool:
	_reset()
	_a.player_skill = 0.5
	var ctx: Dictionary = _ctx(50, {"pressure": 90})  # gauge > 85 = crisis
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_result: int = _a.scale_effect(10, "negative", ctx)
	var safe_result: int = _a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		return _fail("High gauge crisis negative (%d) should be less than safe (%d)" % [crisis_result, safe_result])
	return true


func test_no_crisis_when_gauge_in_safe_range() -> bool:
	_reset()
	_a.player_skill = 0.5
	var ctx: Dictionary = _ctx(50, {"mana": 50})  # 15 <= 50 <= 85 = not crisis
	var safe_ctx: Dictionary = _ctx(50)
	var result_with: int = _a.scale_effect(10, "negative", ctx)
	var result_without: int = _a.scale_effect(10, "negative", safe_ctx)
	if result_with != result_without:
		return _fail("Gauge in safe range should not trigger crisis: with_gauge=%d vs none=%d" % [result_with, result_without])
	return true


# ─── T33: crisis detection — faction deltas ──────────────────────────────────

func test_crisis_two_extreme_faction_deltas() -> bool:
	_reset()
	_a.player_skill = 0.5
	var factions: Dictionary = {"druides": 20.0, "ankou": -18.0}  # both abs > 15
	var ctx: Dictionary = _ctx(50, {}, factions)
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_result: int = _a.scale_effect(10, "negative", ctx)
	var safe_result: int = _a.scale_effect(10, "negative", safe_ctx)
	if crisis_result >= safe_result:
		return _fail("Two extreme faction deltas crisis (%d) should be less than safe (%d)" % [crisis_result, safe_result])
	return true


func test_no_crisis_with_only_one_extreme_faction_delta() -> bool:
	_reset()
	_a.player_skill = 0.5
	var factions: Dictionary = {"druides": 20.0, "ankou": 5.0}  # only one abs > 15
	var ctx: Dictionary = _ctx(50, {}, factions)
	var safe_ctx: Dictionary = _ctx(50)
	var result_with: int = _a.scale_effect(10, "negative", ctx)
	var result_without: int = _a.scale_effect(10, "negative", safe_ctx)
	if result_with != result_without:
		return _fail("One extreme delta should not trigger crisis: with=%d vs none=%d" % [result_with, result_without])
	return true


# ─── T35: get_card_weight_modifier ───────────────────────────────────────────

func test_card_weight_default_is_1() -> bool:
	_reset()
	var card: Dictionary = _card([], [])
	var weight: float = _a.get_card_weight_modifier(card, _ctx())
	if absf(weight - 1.0) > 0.001:
		return _fail("Default card weight should be 1.0, got %f" % weight)
	return true


func test_card_weight_dangerous_card_penalised_when_deaths() -> bool:
	_reset()
	_a.on_death(30)  # consecutive_deaths = 1
	var effects: Array = [_effect(-25)]
	var opts: Array = [_option(effects)]
	var card: Dictionary = _card([], opts)
	var weight: float = _a.get_card_weight_modifier(card, _ctx())
	if weight > 0.31:
		return _fail("Dangerous card with deaths should have weight ~0.3, got %f" % weight)
	return true


func test_card_weight_dangerous_card_penalised_when_pity() -> bool:
	_reset()
	_a.enable_pity_mode()
	var effects: Array = [_effect(-25)]
	var opts: Array = [_option(effects)]
	var card: Dictionary = _card([], opts)
	var weight: float = _a.get_card_weight_modifier(card, _ctx())
	if weight > 0.31:
		return _fail("Dangerous card in pity mode should have weight ~0.3, got %f" % weight)
	return true


func test_card_weight_recovery_boosted_in_crisis() -> bool:
	_reset()
	var card: Dictionary = _card(["recovery"], [])
	var crisis_ctx: Dictionary = _ctx(10)  # life < 20 = crisis
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_weight: float = _a.get_card_weight_modifier(card, crisis_ctx)
	var safe_weight: float = _a.get_card_weight_modifier(card, safe_ctx)
	if crisis_weight <= safe_weight:
		return _fail("Recovery card weight in crisis (%f) should exceed safe (%f)" % [crisis_weight, safe_weight])
	return true


func test_card_weight_healing_tag_boosted_in_crisis() -> bool:
	_reset()
	var card: Dictionary = _card(["healing"], [])
	var crisis_ctx: Dictionary = _ctx(10)
	var safe_ctx: Dictionary = _ctx(50)
	var crisis_weight: float = _a.get_card_weight_modifier(card, crisis_ctx)
	var safe_weight: float = _a.get_card_weight_modifier(card, safe_ctx)
	if crisis_weight <= safe_weight:
		return _fail("'healing' tag weight in crisis (%f) should exceed safe (%f)" % [crisis_weight, safe_weight])
	return true


func test_card_weight_rest_tag_boosted_in_crisis() -> bool:
	_reset()
	var card: Dictionary = _card(["rest"], [])
	var crisis_ctx: Dictionary = _ctx(10)
	var safe_ctx: Dictionary = _ctx(50)
	if _a.get_card_weight_modifier(card, crisis_ctx) <= _a.get_card_weight_modifier(card, safe_ctx):
		return _fail("'rest' tag should be recognized as recovery and boosted in crisis")
	return true


func test_card_weight_complex_card_penalised_for_novice() -> bool:
	_reset()
	_a.player_skill = 0.2  # < 0.3 threshold
	# Build a high-complexity card: 3 options (0.3), 9 effects (0.4 capped),
	# "promise" tag (0.2), "arc" tag (0.1) → total 1.0, which exceeds 0.7
	var rich_opts: Array = []
	for i in range(3):
		rich_opts.append(_option([_effect(5), _effect(3), _effect(-2)]))
	var complex_card: Dictionary = _card(["promise", "arc"], rich_opts)
	var weight: float = _a.get_card_weight_modifier(complex_card, _ctx())
	if weight > 0.51:
		return _fail("Complex card for novice should have weight ~0.5, got %f" % weight)
	return true


func test_card_weight_complex_not_penalised_for_skilled_player() -> bool:
	_reset()
	_a.player_skill = 0.8  # > 0.3, no complexity penalty
	var rich_opts: Array = []
	for i in range(3):
		rich_opts.append(_option([_effect(5), _effect(3), _effect(-2)]))
	var complex_card: Dictionary = _card(["promise", "arc"], rich_opts)
	var weight: float = _a.get_card_weight_modifier(complex_card, _ctx())
	# No complexity penalty, so weight should be 1.0 (no other modifiers trigger)
	if absf(weight - 1.0) > 0.001:
		return _fail("Complex card for skilled player should have weight 1.0, got %f" % weight)
	return true


# ─── T44: get_debug_info ─────────────────────────────────────────────────────

func test_debug_info_has_all_required_keys() -> bool:
	_reset()
	var info: Dictionary = _a.get_debug_info()
	var required: Array = [
		"player_skill", "consecutive_deaths", "pity_mode_active",
		"pity_cards_remaining", "session_deaths", "session_quick_deaths",
	]
	for key in required:
		if not info.has(key):
			return _fail("get_debug_info() missing key: %s" % key)
	return true


func test_debug_info_values_reflect_state() -> bool:
	_reset()
	_a.player_skill = 0.75
	_a.enable_pity_mode()
	_a.on_death(30)
	var info: Dictionary = _a.get_debug_info()
	if absf(float(info["player_skill"]) - 0.75) > 0.001:
		return _fail("debug_info player_skill mismatch: expected 0.75, got %s" % str(info["player_skill"]))
	if not info["pity_mode_active"]:
		return _fail("debug_info pity_mode_active should be true")
	if int(info["pity_cards_remaining"]) != DifficultyAdapter.PITY_DURATION_CARDS:
		return _fail("debug_info pity_cards_remaining should be %d, got %s" % [
			DifficultyAdapter.PITY_DURATION_CARDS, str(info["pity_cards_remaining"])])
	if int(info["consecutive_deaths"]) != 1:
		return _fail("debug_info consecutive_deaths should be 1, got %s" % str(info["consecutive_deaths"]))
	return true


# ─── T46: edge cases ─────────────────────────────────────────────────────────

func test_scale_effect_empty_context_no_crash() -> bool:
	_reset()
	# Empty context: no life_essence, no gauges, no faction_rep_delta
	var result: int = _a.scale_effect(10, "negative", {})
	# Should not crash, and produce a reasonable result
	if result < 0:
		return _fail("scale_effect with empty context should not produce negative result, got %d" % result)
	return true


func test_scale_effect_unknown_effect_type_behaves_as_positive() -> bool:
	_reset()
	_a.player_skill = 0.5
	# Unknown type falls through to the else branch: factor = 2.0 - skill_factor = 1.0
	var unknown: int = _a.scale_effect(10, "unknown_type", _ctx())
	var positive: int = _a.scale_effect(10, "positive", _ctx())
	if unknown != positive:
		return _fail("Unknown effect type should behave like 'positive', unknown=%d positive=%d" % [unknown, positive])
	return true


func test_multiple_deaths_then_successful_run_resets_clean() -> bool:
	_reset()
	# Simulate a frustrating session then a win
	for i in range(5):
		_a.on_death(10)
	_a.on_successful_run()
	if _a.consecutive_deaths != 0:
		return _fail("consecutive_deaths must be 0 after successful run, got %d" % _a.consecutive_deaths)
	if _a.pity_mode_active:
		return _fail("pity must be off after successful run")
	return true


func test_on_run_start_after_death_sequence() -> bool:
	_reset()
	_a.on_death(30)
	_a.on_run_start()
	# cards_since_crisis reset; consecutive_deaths stays
	if _a.cards_since_crisis != 999:
		return _fail("cards_since_crisis must be 999 after on_run_start, got %d" % _a.cards_since_crisis)
	if _a.consecutive_deaths != 1:
		return _fail("consecutive_deaths must persist across on_run_start, got %d" % _a.consecutive_deaths)
	return true
