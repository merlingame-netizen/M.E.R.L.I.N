## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — ToneController (addons/merlin_ai/processors/tone_controller.gd)
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: tone enum, tone_to_string, get_tone_characteristics, weight
## recalculation per trust tier, rapport adjustments, session adjustments,
## crisis detection, arc climax override, melancholy gate, weighted selection,
## sentence prefix/suffix, prompt guidance, defaults.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_controller() -> ToneController:
	var tc: ToneController = ToneController.new()
	return tc


func _approx_eq(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_initial_tone_is_neutral",
		"test_tone_to_string_all_values",
		"test_tone_to_string_neutral_fallback",
		"test_get_current_tone_reflects_current",
		"test_characteristics_neutral_keys",
		"test_characteristics_all_tones_have_four_keys",
		"test_default_weights",
		"test_recalculate_trust_tier_0_distant",
		"test_recalculate_trust_tier_1_cautious",
		"test_recalculate_trust_tier_2_attentive",
		"test_recalculate_trust_tier_3_bound",
		"test_rapport_warmth_boosts_warm_weight",
		"test_rapport_complicity_boosts_playful_weight",
		"test_session_frustrated_adjustments",
		"test_session_flow_boosts_playful",
		"test_session_long_boosts_warm",
		"test_crisis_low_gauge",
		"test_crisis_high_gauge",
		"test_crisis_extreme_faction_deltas",
		"test_no_crisis_normal_values",
		"test_arc_climax_forces_mysterious",
		"test_sentence_prefix_returns_string",
		"test_sentence_suffix_returns_string",
		"test_prompt_guidance_contains_tone_name",
		"test_weighted_selection_returns_valid_tone",
	]

	var passed := 0
	var failed := 0
	var errors: Array[String] = []

	for test_name in tests:
		var result: bool = call(test_name)
		if result:
			passed += 1
		else:
			failed += 1
			errors.append(test_name)

	return {"passed": passed, "failed": failed, "errors": errors}


# ═══════════════════════════════════════════════════════════════════════════════
# INITIAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_initial_tone_is_neutral() -> bool:
	var tc: ToneController = _make_controller()
	if tc.current_tone != ToneController.Tone.NEUTRAL:
		push_error("Initial tone should be NEUTRAL, got %d" % tc.current_tone)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TONE TO STRING
# ═══════════════════════════════════════════════════════════════════════════════

func test_tone_to_string_all_values() -> bool:
	var tc: ToneController = _make_controller()
	var expected: Dictionary = {
		ToneController.Tone.NEUTRAL: "neutral",
		ToneController.Tone.PLAYFUL: "playful",
		ToneController.Tone.MYSTERIOUS: "mysterious",
		ToneController.Tone.WARNING: "warning",
		ToneController.Tone.MELANCHOLY: "melancholy",
		ToneController.Tone.WARM: "warm",
		ToneController.Tone.CRYPTIC: "cryptic",
	}
	for tone_val in expected:
		var result: String = tc.tone_to_string(tone_val)
		var expect: String = expected[tone_val]
		if result != expect:
			push_error("tone_to_string(%d) expected '%s', got '%s'" % [tone_val, expect, result])
			return false
	return true


func test_tone_to_string_neutral_fallback() -> bool:
	var tc: ToneController = _make_controller()
	# Passing an out-of-range int should fall through to "neutral"
	var result: String = tc.tone_to_string(999)
	if result != "neutral":
		push_error("tone_to_string(999) should fallback to 'neutral', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GET CURRENT TONE
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_current_tone_reflects_current() -> bool:
	var tc: ToneController = _make_controller()
	tc.current_tone = ToneController.Tone.WARM
	var result: String = tc.get_current_tone()
	if result != "warm":
		push_error("get_current_tone should return 'warm', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TONE CHARACTERISTICS
# ═══════════════════════════════════════════════════════════════════════════════

func test_characteristics_neutral_keys() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.NEUTRAL)
	var required_keys: Array[String] = ["sentence_length", "punctuation", "vocabulary", "emotion"]
	for key in required_keys:
		if not chars.has(key):
			push_error("NEUTRAL characteristics missing key '%s'" % key)
			return false
	if chars["emotion"] != "detached":
		push_error("NEUTRAL emotion should be 'detached', got '%s'" % str(chars["emotion"]))
		return false
	return true


func test_characteristics_all_tones_have_four_keys() -> bool:
	var tc: ToneController = _make_controller()
	var tones: Array = [
		ToneController.Tone.NEUTRAL,
		ToneController.Tone.PLAYFUL,
		ToneController.Tone.MYSTERIOUS,
		ToneController.Tone.WARNING,
		ToneController.Tone.MELANCHOLY,
		ToneController.Tone.WARM,
		ToneController.Tone.CRYPTIC,
	]
	for tone_val in tones:
		var chars: Dictionary = tc.get_tone_characteristics(tone_val)
		if chars.size() != 4:
			push_error("Tone %d characteristics should have 4 keys, got %d" % [tone_val, chars.size()])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_weights() -> bool:
	var tc: ToneController = _make_controller()
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.NEUTRAL]), 1.0):
		push_error("Default NEUTRAL weight should be 1.0")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MELANCHOLY]), 0.0):
		push_error("Default MELANCHOLY weight should be 0.0")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARNING]), 0.3):
		push_error("Default WARNING weight should be 0.3")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# WEIGHT RECALCULATION — TRUST TIERS
# ═══════════════════════════════════════════════════════════════════════════════

func test_recalculate_trust_tier_0_distant() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 0
	tc._recalculate_weights()

	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 0.5):
		push_error("Tier 0: PLAYFUL should be 0.5, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.0):
		push_error("Tier 0: WARM should be 0.0")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MYSTERIOUS]), 0.8):
		push_error("Tier 0: MYSTERIOUS should be 0.8")
		return false
	return true


func test_recalculate_trust_tier_1_cautious() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc._recalculate_weights()

	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 0.8):
		push_error("Tier 1: PLAYFUL should be 0.8")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.3):
		push_error("Tier 1: WARM should be 0.3")
		return false
	return true


func test_recalculate_trust_tier_2_attentive() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 2
	tc._recalculate_weights()

	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 1.0):
		push_error("Tier 2: PLAYFUL should be 1.0")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.5):
		push_error("Tier 2: WARM should be 0.5")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.CRYPTIC]), 0.4):
		push_error("Tier 2: CRYPTIC should be 0.4")
		return false
	return true


func test_recalculate_trust_tier_3_bound() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 3
	tc._recalculate_weights()

	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 1.2):
		push_error("Tier 3: PLAYFUL should be 1.2")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.7):
		push_error("Tier 3: WARM should be 0.7")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MELANCHOLY]), 0.15):
		push_error("Tier 3: MELANCHOLY should be 0.15")
		return false
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.CRYPTIC]), 0.5):
		push_error("Tier 3: CRYPTIC should be 0.5")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RAPPORT ADJUSTMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_rapport_warmth_boosts_warm_weight() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.rapport_warmth = 0.8
	tc._recalculate_weights()

	# Tier 1 base WARM = 0.3, plus rapport_warmth * 0.3 = 0.24 => 0.54
	var expected_warm: float = 0.3 + 0.8 * 0.3
	var actual_warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	if not _approx_eq(actual_warm, expected_warm):
		push_error("Rapport warmth: WARM should be ~%f, got %f" % [expected_warm, actual_warm])
		return false
	return true


func test_rapport_complicity_boosts_playful_weight() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.rapport_complicity = 0.6
	tc._recalculate_weights()

	# Tier 1 base PLAYFUL = 0.8, plus rapport_complicity * 0.2 = 0.12 => 0.92
	var expected_playful: float = 0.8 + 0.6 * 0.2
	var actual_playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(actual_playful, expected_playful):
		push_error("Rapport complicity: PLAYFUL should be ~%f, got %f" % [expected_playful, actual_playful])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SESSION ADJUSTMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_session_frustrated_adjustments() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 2
	tc.session_seems_frustrated = true
	tc._recalculate_weights()

	# Tier 2 base: WARM=0.5 +0.3=0.8, PLAYFUL=1.0 -0.2=0.8, WARNING=0.3 -0.2=0.1
	var warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	var warning: float = float(tc.tone_weights[ToneController.Tone.WARNING])

	if not _approx_eq(warm, 0.8):
		push_error("Frustrated: WARM should be 0.8, got %f" % warm)
		return false
	if not _approx_eq(playful, 0.8):
		push_error("Frustrated: PLAYFUL should be 0.8, got %f" % playful)
		return false
	if not _approx_eq(warning, 0.1):
		push_error("Frustrated: WARNING should be 0.1, got %f" % warning)
		return false
	return true


func test_session_flow_boosts_playful() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.player_in_flow = true
	tc._recalculate_weights()

	# Tier 1 base PLAYFUL = 0.8, + flow 0.2 = 1.0
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(playful, 1.0):
		push_error("Flow: PLAYFUL should be 1.0, got %f" % playful)
		return false
	return true


func test_session_long_boosts_warm() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.session_is_long = true
	tc._recalculate_weights()

	# Tier 1 base WARM = 0.3, + long 0.1 = 0.4
	var warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	if not _approx_eq(warm, 0.4):
		push_error("Long session: WARM should be 0.4, got %f" % warm)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CRISIS DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_crisis_low_gauge() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {"gauges": {"health": 10}}
	var is_crisis: bool = tc._is_crisis_context(context)
	if not is_crisis:
		push_error("Gauge at 10 should trigger crisis")
		return false
	return true


func test_crisis_high_gauge() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {"gauges": {"tension": 90}}
	var is_crisis: bool = tc._is_crisis_context(context)
	if not is_crisis:
		push_error("Gauge at 90 should trigger crisis")
		return false
	return true


func test_crisis_extreme_faction_deltas() -> bool:
	var tc: ToneController = _make_controller()
	# Need 2+ factions with abs delta > 15
	var context: Dictionary = {
		"gauges": {},
		"faction_rep_delta": {"druides": 18.0, "anciens": -20.0, "korrigans": 2.0},
	}
	var is_crisis: bool = tc._is_crisis_context(context)
	if not is_crisis:
		push_error("2 extreme faction deltas should trigger crisis")
		return false
	return true


func test_no_crisis_normal_values() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {
		"gauges": {"health": 50, "mana": 40},
		"faction_rep_delta": {"druides": 5.0, "anciens": -3.0},
	}
	var is_crisis: bool = tc._is_crisis_context(context)
	if is_crisis:
		push_error("Normal gauges and deltas should NOT trigger crisis")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ARC CLIMAX OVERRIDE
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_climax_forces_mysterious() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {"is_arc_climax": true, "gauges": {}}
	var tone: int = tc.get_tone_for_context(context)
	if tone != ToneController.Tone.MYSTERIOUS:
		push_error("Arc climax should force MYSTERIOUS, got %d" % tone)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SENTENCE PREFIX / SUFFIX
# ═══════════════════════════════════════════════════════════════════════════════

func test_sentence_prefix_returns_string() -> bool:
	var tc: ToneController = _make_controller()
	var tones: Array = [
		ToneController.Tone.NEUTRAL,
		ToneController.Tone.PLAYFUL,
		ToneController.Tone.MYSTERIOUS,
		ToneController.Tone.WARNING,
		ToneController.Tone.MELANCHOLY,
		ToneController.Tone.WARM,
		ToneController.Tone.CRYPTIC,
	]
	for tone_val in tones:
		var prefix: String = tc.get_sentence_prefix(tone_val)
		if prefix == null:
			push_error("Prefix for tone %d returned null" % tone_val)
			return false
		# prefix can be empty string, that's valid
	return true


func test_sentence_suffix_returns_string() -> bool:
	var tc: ToneController = _make_controller()
	var tones: Array = [
		ToneController.Tone.NEUTRAL,
		ToneController.Tone.PLAYFUL,
		ToneController.Tone.MYSTERIOUS,
		ToneController.Tone.WARNING,
		ToneController.Tone.MELANCHOLY,
		ToneController.Tone.WARM,
		ToneController.Tone.CRYPTIC,
	]
	for tone_val in tones:
		var suffix: String = tc.get_sentence_suffix(tone_val)
		if suffix.length() == 0:
			push_error("Suffix for tone %d should not be empty" % tone_val)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMPT GUIDANCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_prompt_guidance_contains_tone_name() -> bool:
	var tc: ToneController = _make_controller()
	tc.current_tone = ToneController.Tone.PLAYFUL
	var guidance: String = tc.get_tone_prompt_guidance()
	if guidance.find("playful") == -1:
		push_error("Prompt guidance should contain 'playful', got: %s" % guidance)
		return false
	if guidance.find("Ton actuel") == -1:
		push_error("Prompt guidance should contain 'Ton actuel'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# WEIGHTED SELECTION — STATISTICAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_weighted_selection_returns_valid_tone() -> bool:
	var tc: ToneController = _make_controller()
	var valid_tones: Array = [
		ToneController.Tone.NEUTRAL,
		ToneController.Tone.PLAYFUL,
		ToneController.Tone.MYSTERIOUS,
		ToneController.Tone.WARNING,
		ToneController.Tone.MELANCHOLY,
		ToneController.Tone.WARM,
		ToneController.Tone.CRYPTIC,
	]
	# Run 50 selections, all should be valid tone enum values
	for i in range(50):
		var selected: int = tc._weighted_tone_selection()
		if not (selected in valid_tones):
			push_error("Weighted selection returned invalid tone: %d" % selected)
			return false
	return true
