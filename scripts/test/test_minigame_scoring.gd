## test_minigame_scoring.gd
## Comprehensive unit tests — MerlinEffectEngine scoring/multiplier and
## MerlinMiniGameSystem field dispatch. ~50 tests.
##
## Pattern: extends RefCounted (NO class_name), func test_xxx() -> bool:,
##   push_error() before return false, all deps initialised in _init().
## Run headless:
##   godot --headless --path . --script scripts/test/test_minigame_scoring.gd

extends RefCounted

# ── Test counters ──────────────────────────────────────────────────────────────
var _pass: int = 0
var _fail: int = 0

# ── Systems under test ────────────────────────────────────────────────────────
var _engine: MerlinEffectEngine
var _minigame: MerlinMiniGameSystem
var _rng: MerlinRng


func _init() -> void:
	_engine = MerlinEffectEngine.new()
	_minigame = MerlinMiniGameSystem.new()
	_rng = MerlinRng.new()
	_rng.set_seed(42)
	_minigame.set_rng(_rng)


# ══════════════════════════════════════════════════════════════════════════════
# MAIN RUNNER — called by test harness
# ══════════════════════════════════════════════════════════════════════════════

func run_all() -> bool:
	print("── test_minigame_scoring ──────────────────────────────────")

	# ── MULTIPLIER_TABLE coverage ─────────────────────────────────────────────
	test_score_range_full_coverage()

	# ── get_multiplier: all 5 bands, exact boundaries ─────────────────────────
	test_multiplier_echec_critique_score_0()
	test_multiplier_echec_critique_score_10()
	test_multiplier_echec_critique_score_20()
	test_multiplier_echec_score_21()
	test_multiplier_echec_score_35()
	test_multiplier_echec_score_50()
	test_multiplier_reussite_partielle_score_51()
	test_multiplier_reussite_partielle_score_65()
	test_multiplier_reussite_partielle_score_79()
	test_multiplier_reussite_score_80()
	test_multiplier_reussite_score_87()
	test_multiplier_reussite_score_94()
	test_multiplier_reussite_critique_score_95()
	test_multiplier_reussite_critique_score_100()
	test_multiplier_out_of_range_fallback()

	# ── get_multiplier_label ──────────────────────────────────────────────────
	test_label_echec_critique()
	test_label_echec()
	test_label_reussite_partielle()
	test_label_reussite()
	test_label_reussite_critique()
	test_label_out_of_range_fallback()

	# ── cap_effect ────────────────────────────────────────────────────────────
	test_cap_reputation_over_max()
	test_cap_reputation_under_min()
	test_cap_reputation_within_range()
	test_cap_heal_life_over_max()
	test_cap_heal_life_within_range()
	test_cap_damage_life_over_max()
	test_cap_damage_life_within_range()
	test_cap_biome_currency_over_max()
	test_cap_unknown_code_passthrough()

	# ── scale_and_cap ─────────────────────────────────────────────────────────
	test_scale_and_cap_heal_reussite()
	test_scale_and_cap_heal_reussite_partielle()
	test_scale_and_cap_heal_critique_caps_at_18()
	test_scale_and_cap_heal_echec_inverts()
	test_scale_and_cap_heal_zero_raw()
	test_scale_and_cap_reputation_caps_at_20()
	test_scale_and_cap_reputation_negative_multiplier()
	test_scale_and_cap_damage_result_within_cap()
	test_scale_and_cap_additive_bonus_logic()

	# ── detect_field_from_verb ────────────────────────────────────────────────
	test_detect_chance_verb()
	test_detect_bluff_verb()
	test_detect_observation_verb()
	test_detect_logique_verb()
	test_detect_finesse_verb()
	test_detect_vigueur_verb()
	test_detect_esprit_verb()
	test_detect_perception_verb()
	test_detect_unknown_verb_fallback()
	test_detect_case_insensitive()
	test_detect_padded_whitespace()

	# ── pick_minigame_for_field ───────────────────────────────────────────────
	test_pick_minigame_chance()
	test_pick_minigame_bluff()
	test_pick_minigame_observation()
	test_pick_minigame_logique()
	test_pick_minigame_finesse()
	test_pick_minigame_vigueur()
	test_pick_minigame_esprit()
	test_pick_minigame_perception()
	test_pick_minigame_unknown_returns_apaisement()
	test_pick_minigame_returns_valid_member()

	# ── MerlinMiniGameSystem.run() contract ───────────────────────────────────
	test_run_returns_four_keys()
	test_run_score_always_0_to_100()
	test_run_type_equals_input_field()
	test_run_success_true_when_score_gte_80()
	test_run_success_false_when_score_lt_80()
	test_run_all_eight_fields_structurally_valid()
	test_run_unknown_field_generic_fallback()
	test_run_difficulty_0_equals_difficulty_1()
	test_run_difficulty_99_equals_difficulty_10()
	test_run_bonus_modifier_additive()
	test_run_bonus_negative_forces_score_to_zero()
	test_run_time_ms_positive()

	# ── MerlinMiniGameSystem constants ───────────────────────────────────────
	test_success_threshold_is_80()
	test_valid_fields_count_is_8()
	test_valid_fields_contains_all_known()

	# ── Effect engine integration with state ──────────────────────────────────
	test_apply_heal_life_effect()
	test_apply_reputation_effect_clamped()
	test_score_bonus_cap_constant_is_2()

	print("── RESULT: %d passed, %d failed ─────────────────────────────" % [_pass, _fail])
	return _fail == 0


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — MULTIPLIER_TABLE full 0-100 coverage
# ══════════════════════════════════════════════════════════════════════════════

func test_score_range_full_coverage() -> bool:
	var covered: Array[bool] = []
	covered.resize(101)
	covered.fill(false)
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		var rmin: int = int(entry["range_min"])
		var rmax: int = int(entry["range_max"])
		for i in range(rmin, rmax + 1):
			if i >= 0 and i <= 100:
				covered[i] = true
	for i in range(101):
		if not covered[i]:
			push_error("Score %d has no MULTIPLIER_TABLE entry" % i)
			return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — get_multiplier: exact boundary values for all 5 tiers
# echec_critique: 0-20 → -1.5
# echec:          21-50 → -1.0
# reussite_partielle: 51-79 → 0.5
# reussite:       80-94 → 1.0
# reussite_critique: 95-100 → 1.5
# ══════════════════════════════════════════════════════════════════════════════

func test_multiplier_echec_critique_score_0() -> bool:
	return _check_multiplier(0, -1.5)


func test_multiplier_echec_critique_score_10() -> bool:
	return _check_multiplier(10, -1.5)


func test_multiplier_echec_critique_score_20() -> bool:
	return _check_multiplier(20, -1.5)


func test_multiplier_echec_score_21() -> bool:
	return _check_multiplier(21, -1.0)


func test_multiplier_echec_score_35() -> bool:
	return _check_multiplier(35, -1.0)


func test_multiplier_echec_score_50() -> bool:
	return _check_multiplier(50, -1.0)


func test_multiplier_reussite_partielle_score_51() -> bool:
	return _check_multiplier(51, 0.5)


func test_multiplier_reussite_partielle_score_65() -> bool:
	return _check_multiplier(65, 0.5)


func test_multiplier_reussite_partielle_score_79() -> bool:
	return _check_multiplier(79, 0.5)


func test_multiplier_reussite_score_80() -> bool:
	return _check_multiplier(80, 1.0)


func test_multiplier_reussite_score_87() -> bool:
	return _check_multiplier(87, 1.0)


func test_multiplier_reussite_score_94() -> bool:
	return _check_multiplier(94, 1.0)


func test_multiplier_reussite_critique_score_95() -> bool:
	return _check_multiplier(95, 1.5)


func test_multiplier_reussite_critique_score_100() -> bool:
	return _check_multiplier(100, 1.5)


func test_multiplier_out_of_range_fallback() -> bool:
	# Scores above 100 fall through every table entry; fallback returns 1.0
	var got: float = MerlinEffectEngine.get_multiplier(101)
	if not _approx(got, 1.0):
		push_error("get_multiplier(101) expected fallback 1.0, got %f" % got)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — get_multiplier_label
# ══════════════════════════════════════════════════════════════════════════════

func test_label_echec_critique() -> bool:
	return _check_label(0, "echec_critique")


func test_label_echec() -> bool:
	return _check_label(35, "echec")


func test_label_reussite_partielle() -> bool:
	return _check_label(65, "reussite_partielle")


func test_label_reussite() -> bool:
	return _check_label(87, "reussite")


func test_label_reussite_critique() -> bool:
	return _check_label(97, "reussite_critique")


func test_label_out_of_range_fallback() -> bool:
	var got: String = MerlinEffectEngine.get_multiplier_label(200)
	if got != "reussite":
		push_error("get_multiplier_label(200) expected fallback 'reussite', got '%s'" % got)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — cap_effect(effect_code, amount) -> int
# ADD_REPUTATION cap: max=20, min=-20
# HEAL_LIFE cap: max=18
# DAMAGE_LIFE cap: max=15
# ADD_BIOME_CURRENCY cap: max=10
# Unknown codes: pass through unchanged
# ══════════════════════════════════════════════════════════════════════════════

func test_cap_reputation_over_max() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 999)
	if got != 20:
		push_error("cap_effect(ADD_REPUTATION, 999) expected 20, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_reputation_under_min() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -999)
	if got != -20:
		push_error("cap_effect(ADD_REPUTATION, -999) expected -20, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_reputation_within_range() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 15)
	if got != 15:
		push_error("cap_effect(ADD_REPUTATION, 15) expected 15, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_heal_life_over_max() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 100)
	if got != 18:
		push_error("cap_effect(HEAL_LIFE, 100) expected 18, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_heal_life_within_range() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 12)
	if got != 12:
		push_error("cap_effect(HEAL_LIFE, 12) expected 12, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_damage_life_over_max() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 100)
	if got != 15:
		push_error("cap_effect(DAMAGE_LIFE, 100) expected 15, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_damage_life_within_range() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 8)
	if got != 8:
		push_error("cap_effect(DAMAGE_LIFE, 8) expected 8, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_biome_currency_over_max() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("ADD_BIOME_CURRENCY", 999)
	if got != 10:
		push_error("cap_effect(ADD_BIOME_CURRENCY, 999) expected 10, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_cap_unknown_code_passthrough() -> bool:
	var got: int = MerlinEffectEngine.cap_effect("ADD_ANAM", 42)
	if got != 42:
		push_error("cap_effect(ADD_ANAM, 42) expected passthrough 42, got %d" % got)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — scale_and_cap(effect_code, raw_amount, multiplier) -> int
# Formula: scaled = int(raw * abs(multiplier)); if multiplier<0: scaled=-scaled
#          then cap_effect(effect_code, scaled)
# ══════════════════════════════════════════════════════════════════════════════

func test_scale_and_cap_heal_reussite() -> bool:
	# raw=10, multiplier=1.0 → scaled=10; cap=18 → result=10
	var got: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, 1.0)
	if got != 10:
		push_error("scale_and_cap(HEAL_LIFE, 10, 1.0) expected 10, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_heal_reussite_partielle() -> bool:
	# raw=10, multiplier=0.5 → scaled=5; cap=18 → result=5
	var got: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, 0.5)
	if got != 5:
		push_error("scale_and_cap(HEAL_LIFE, 10, 0.5) expected 5, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_heal_critique_caps_at_18() -> bool:
	# raw=14, multiplier=1.5 → scaled=int(14*1.5)=21; cap=18 → result=18
	var got: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 14, 1.5)
	if got != 18:
		push_error("scale_and_cap(HEAL_LIFE, 14, 1.5) expected 18 (capped), got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_heal_echec_inverts() -> bool:
	# raw=10, multiplier=-1.0 → scaled=int(10*1.0)=10; negated=-10
	# cap_effect(HEAL_LIFE, -10) = mini(-10, 18) = -10
	var got: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, -1.0)
	if got != -10:
		push_error("scale_and_cap(HEAL_LIFE, 10, -1.0) expected -10, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_heal_zero_raw() -> bool:
	# raw=0 → result is always 0 regardless of multiplier
	var got: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 0, 1.5)
	if got != 0:
		push_error("scale_and_cap(HEAL_LIFE, 0, 1.5) expected 0, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_reputation_caps_at_20() -> bool:
	# raw=20, multiplier=1.5 → scaled=int(20*1.5)=30; cap=20 → result=20
	var got: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 20, 1.5)
	if got != 20:
		push_error("scale_and_cap(ADD_REPUTATION, 20, 1.5) expected 20 (capped), got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_reputation_negative_multiplier() -> bool:
	# raw=10, multiplier=-1.5 → scaled=int(10*1.5)=15; negated=-15; cap min=-20 → -15
	var got: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 10, -1.5)
	if got != -15:
		push_error("scale_and_cap(ADD_REPUTATION, 10, -1.5) expected -15, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_damage_result_within_cap() -> bool:
	# raw=5, multiplier=1.5 → scaled=int(5*1.5)=7; DAMAGE_LIFE cap=15 → result=7
	var got: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 5, 1.5)
	if got != 7:
		push_error("scale_and_cap(DAMAGE_LIFE, 5, 1.5) expected 7, got %d" % got)
		return _fail_test()
	return _pass_test()


func test_scale_and_cap_additive_bonus_logic() -> bool:
	# score_bonus_cap is 2.0; combining factors 1.5 + 0.3 = 1.8 < 2.0 → allowed
	var cap: float = float(MerlinConstants.EFFECT_CAPS.get("score_bonus_cap", 0.0))
	var combined: float = minf(1.5 + 0.3, cap)
	if not _approx(combined, 1.8):
		push_error("Additive bonus 1.5+0.3 expected 1.8, got %f" % combined)
		return _fail_test()
	# 1.5 + 0.8 = 2.3 → capped at 2.0
	var capped: float = minf(1.5 + 0.8, cap)
	if not _approx(capped, 2.0):
		push_error("Additive bonus 1.5+0.8 capped at 2.0, got %f" % capped)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — detect_field_from_verb(verb) -> String
# Uses MerlinConstants.ACTION_VERBS; fallback = "esprit"
# ══════════════════════════════════════════════════════════════════════════════

func test_detect_chance_verb() -> bool:
	return _check_field_verb("deviner", "chance")


func test_detect_bluff_verb() -> bool:
	return _check_field_verb("marchander", "bluff")


func test_detect_observation_verb() -> bool:
	return _check_field_verb("observer", "observation")


func test_detect_logique_verb() -> bool:
	return _check_field_verb("analyser", "logique")


func test_detect_finesse_verb() -> bool:
	return _check_field_verb("esquiver", "finesse")


func test_detect_vigueur_verb() -> bool:
	return _check_field_verb("combattre", "vigueur")


func test_detect_esprit_verb() -> bool:
	return _check_field_verb("apaiser", "esprit")


func test_detect_perception_verb() -> bool:
	return _check_field_verb("ecouter", "perception")


func test_detect_unknown_verb_fallback() -> bool:
	var got: String = MerlinEffectEngine.detect_field_from_verb("verb_inconnu_xyz")
	if got != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("unknown verb expected fallback '%s', got '%s'" % [MerlinConstants.ACTION_VERB_FALLBACK_FIELD, got])
		return _fail_test()
	return _pass_test()


func test_detect_case_insensitive() -> bool:
	# to_lower() is applied internally; uppercase must resolve the same way
	return _check_field_verb("COMBATTRE", "vigueur")


func test_detect_padded_whitespace() -> bool:
	# strip_edges() is applied internally; padded verb must resolve correctly
	return _check_field_verb("  analyser  ", "logique")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7 — pick_minigame_for_field(field) -> String
# Must return a string that is a member of FIELD_MINIGAMES[field]
# ══════════════════════════════════════════════════════════════════════════════

func test_pick_minigame_chance() -> bool:
	return _check_minigame("chance", ["herboristerie"])


func test_pick_minigame_bluff() -> bool:
	return _check_minigame("bluff", ["negociation"])


func test_pick_minigame_observation() -> bool:
	return _check_minigame("observation", ["fouille", "regard"])


func test_pick_minigame_logique() -> bool:
	return _check_minigame("logique", ["runes"])


func test_pick_minigame_finesse() -> bool:
	return _check_minigame("finesse", ["ombres", "equilibre"])


func test_pick_minigame_vigueur() -> bool:
	return _check_minigame("vigueur", ["combat_rituel", "course"])


func test_pick_minigame_esprit() -> bool:
	return _check_minigame("esprit", ["apaisement", "volonte", "sang_froid"])


func test_pick_minigame_perception() -> bool:
	return _check_minigame("perception", ["traces", "echo"])


func test_pick_minigame_unknown_returns_apaisement() -> bool:
	# Unknown field → minigames array is empty → safe fallback "apaisement"
	var got: String = MerlinEffectEngine.pick_minigame_for_field("champ_inexistant")
	if got != "apaisement":
		push_error("unknown field expected 'apaisement' fallback, got '%s'" % got)
		return _fail_test()
	return _pass_test()


func test_pick_minigame_returns_valid_member() -> bool:
	# pick_minigame_for_field uses randi() — result must always be a valid member of the field's list
	var valid: Array = ["combat_rituel", "course"]
	for i in range(10):
		var result: String = MerlinEffectEngine.pick_minigame_for_field("vigueur")
		if result not in valid:
			push_error("pick_minigame_for_field('vigueur') returned invalid '%s', expected one of %s" % [result, valid])
			return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8 — MerlinMiniGameSystem.run(field, difficulty, modifiers) contract
# Returns: {type: String, success: bool, score: int (0-100), time_ms: int}
# ══════════════════════════════════════════════════════════════════════════════

func test_run_returns_four_keys() -> bool:
	_rng.set_seed(1)
	var result: Dictionary = _minigame.run("esprit", 3)
	var required: Array[String] = ["type", "success", "score", "time_ms"]
	for key in required:
		if not result.has(key):
			push_error("run() result missing key '%s'" % key)
			return _fail_test()
	return _pass_test()


func test_run_score_always_0_to_100() -> bool:
	var fields: Array[String] = ["vigueur", "esprit", "bluff", "logique",
		"observation", "perception", "finesse", "chance"]
	for field in fields:
		for diff in [1, 5, 10]:
			_rng.set_seed(diff * 7 + 3)
			var result: Dictionary = _minigame.run(field, diff)
			var s: int = result["score"]
			if s < 0 or s > 100:
				push_error("run(%s, %d) score=%d not in [0,100]" % [field, diff, s])
				return _fail_test()
	return _pass_test()


func test_run_type_equals_input_field() -> bool:
	_rng.set_seed(2)
	var result: Dictionary = _minigame.run("bluff", 4)
	if result["type"] != "bluff":
		push_error("run('bluff').type expected 'bluff', got '%s'" % result["type"])
		return _fail_test()
	return _pass_test()


func test_run_success_true_when_score_gte_80() -> bool:
	# Force score to 100 via bonus=1.0: raw + int(1.0*100) = raw+100 → clamped 100
	_rng.set_seed(9)
	var result: Dictionary = _minigame.run("esprit", 10, {"bonus": 1.0})
	if result["score"] != 100:
		push_error("bonus=1.0 should force score=100, got %d" % result["score"])
		return _fail_test()
	if not result["success"]:
		push_error("score=100 should yield success=true")
		return _fail_test()
	return _pass_test()


func test_run_success_false_when_score_lt_80() -> bool:
	# Force score to 0 via bonus=-1.0: raw + int(-1.0*100) = raw-100 → clamped 0
	_rng.set_seed(7)
	var result: Dictionary = _minigame.run("esprit", 10, {"bonus": -1.0})
	if result["score"] != 0:
		push_error("bonus=-1.0 should force score=0, got %d" % result["score"])
		return _fail_test()
	if result["success"]:
		push_error("score=0 should yield success=false")
		return _fail_test()
	return _pass_test()


func test_run_all_eight_fields_structurally_valid() -> bool:
	var fields: Array[String] = ["vigueur", "esprit", "bluff", "logique",
		"observation", "perception", "finesse", "chance"]
	for field in fields:
		_rng.set_seed(99)
		var result: Dictionary = _minigame.run(field, 5)
		if not result.has("score"):
			push_error("run(%s) missing 'score'" % field)
			return _fail_test()
		if result["type"] != field:
			push_error("run(%s).type='%s' expected '%s'" % [field, result["type"], field])
			return _fail_test()
	return _pass_test()


func test_run_unknown_field_generic_fallback() -> bool:
	_rng.set_seed(3)
	var result: Dictionary = _minigame.run("champ_inconnu", 5)
	if not result.has("score"):
		push_error("unknown field fallback missing 'score'")
		return _fail_test()
	var s: int = result["score"]
	if s < 0 or s > 100:
		push_error("unknown field fallback score=%d out of [0,100]" % s)
		return _fail_test()
	return _pass_test()


func test_run_difficulty_0_equals_difficulty_1() -> bool:
	# difficulty is clamped to [1,10]; diff=0 must behave like diff=1
	_rng.set_seed(5)
	var r0: Dictionary = _minigame.run("vigueur", 0)
	_rng.set_seed(5)
	var r1: Dictionary = _minigame.run("vigueur", 1)
	if r0["score"] != r1["score"]:
		push_error("difficulty 0 vs 1: score %d vs %d (should be equal, both clamped to 1)" % [r0["score"], r1["score"]])
		return _fail_test()
	return _pass_test()


func test_run_difficulty_99_equals_difficulty_10() -> bool:
	# difficulty is clamped to [1,10]; diff=99 must behave like diff=10
	_rng.set_seed(5)
	var r99: Dictionary = _minigame.run("vigueur", 99)
	_rng.set_seed(5)
	var r10: Dictionary = _minigame.run("vigueur", 10)
	if r99["score"] != r10["score"]:
		push_error("difficulty 99 vs 10: score %d vs %d (should be equal, both clamped to 10)" % [r99["score"], r10["score"]])
		return _fail_test()
	return _pass_test()


func test_run_bonus_modifier_additive() -> bool:
	# bonus=0.3 adds int(0.3*100)=30 to raw score before clamping
	# With same seed, bonus result should be >= base result (unless already at 100)
	_rng.set_seed(8)
	var base_r: Dictionary = _minigame.run("logique", 8, {})
	_rng.set_seed(8)
	var bonus_r: Dictionary = _minigame.run("logique", 8, {"bonus": 0.3})
	if bonus_r["score"] < base_r["score"]:
		push_error("bonus=0.3 score %d < base score %d (must be >=)" % [bonus_r["score"], base_r["score"]])
		return _fail_test()
	return _pass_test()


func test_run_bonus_negative_forces_score_to_zero() -> bool:
	# bonus=-1.0 → int(-1.0 * 100) = -100, added to any raw score → clamped to 0
	_rng.set_seed(4)
	var result: Dictionary = _minigame.run("chance", 5, {"bonus": -1.0})
	if result["score"] != 0:
		push_error("bonus=-1.0 expected score=0, got %d" % result["score"])
		return _fail_test()
	return _pass_test()


func test_run_time_ms_positive() -> bool:
	# _simulate_time_ms always produces a value in roughly [4000, 17000] range
	_rng.set_seed(6)
	var result: Dictionary = _minigame.run("finesse", 5)
	var t: int = result["time_ms"]
	if t <= 0:
		push_error("time_ms expected > 0, got %d" % t)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9 — MerlinMiniGameSystem constants
# ══════════════════════════════════════════════════════════════════════════════

func test_success_threshold_is_80() -> bool:
	if MerlinMiniGameSystem.SUCCESS_THRESHOLD != 80:
		push_error("SUCCESS_THRESHOLD expected 80, got %d" % MerlinMiniGameSystem.SUCCESS_THRESHOLD)
		return _fail_test()
	return _pass_test()


func test_valid_fields_count_is_8() -> bool:
	if MerlinMiniGameSystem.VALID_FIELDS.size() != 8:
		push_error("VALID_FIELDS expected 8 entries, got %d" % MerlinMiniGameSystem.VALID_FIELDS.size())
		return _fail_test()
	return _pass_test()


func test_valid_fields_contains_all_known() -> bool:
	var expected: Array[String] = [
		"chance", "bluff", "observation", "logique",
		"finesse", "vigueur", "esprit", "perception",
	]
	for field in expected:
		if not MerlinMiniGameSystem.VALID_FIELDS.has(field):
			push_error("VALID_FIELDS missing '%s'" % field)
			return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10 — Effect engine integration (minimal state round-trips)
# ══════════════════════════════════════════════════════════════════════════════

func test_apply_heal_life_effect() -> bool:
	var state: Dictionary = _make_state()
	_engine.apply_effects(state, ["HEAL_LIFE:10"], "TEST")
	var life: int = int(state["run"]["life_essence"])
	# Started at 50, healed 10 → 60
	if life != 60:
		push_error("HEAL_LIFE:10 from 50 expected 60, got %d" % life)
		return _fail_test()
	return _pass_test()


func test_apply_reputation_effect_clamped() -> bool:
	var state: Dictionary = _make_state()
	# Faction starts at 10; add 25 → capped by engine at ±20 per card → 10+20=30
	_engine.apply_effects(state, ["ADD_REPUTATION:druides:25"], "TEST")
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 30:
		push_error("ADD_REPUTATION:druides:25 from 10 expected 30 (capped delta), got %d" % rep)
		return _fail_test()
	return _pass_test()


func test_score_bonus_cap_constant_is_2() -> bool:
	var cap: float = float(MerlinConstants.EFFECT_CAPS.get("score_bonus_cap", 0.0))
	if not _approx(cap, 2.0):
		push_error("score_bonus_cap expected 2.0, got %f" % cap)
		return _fail_test()
	return _pass_test()


# ══════════════════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"anam": 0,
			"biome_currency": 0,
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10,
				"niamh": 10, "ankou": 10,
			},
		},
		"effect_log": [],
	}


func _approx(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) < eps


func _check_multiplier(score: int, expected: float) -> bool:
	var got: float = MerlinEffectEngine.get_multiplier(score)
	if not _approx(got, expected):
		push_error("get_multiplier(%d) expected %f, got %f" % [score, expected, got])
		return _fail_test()
	return _pass_test()


func _check_label(score: int, expected: String) -> bool:
	var got: String = MerlinEffectEngine.get_multiplier_label(score)
	if got != expected:
		push_error("get_multiplier_label(%d) expected '%s', got '%s'" % [score, expected, got])
		return _fail_test()
	return _pass_test()


func _check_field_verb(verb: String, expected_field: String) -> bool:
	var got: String = MerlinEffectEngine.detect_field_from_verb(verb)
	if got != expected_field:
		push_error("detect_field_from_verb('%s') expected '%s', got '%s'" % [verb, expected_field, got])
		return _fail_test()
	return _pass_test()


func _check_minigame(field: String, valid: Array) -> bool:
	var got: String = MerlinEffectEngine.pick_minigame_for_field(field)
	if not valid.has(got):
		push_error("pick_minigame_for_field('%s') got '%s', not in %s" % [field, got, str(valid)])
		return _fail_test()
	return _pass_test()


func _pass_test() -> bool:
	_pass += 1
	return true


func _fail_test() -> bool:
	_fail += 1
	return false
