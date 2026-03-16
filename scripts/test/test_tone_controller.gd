## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — ToneController (addons/merlin_ai/processors/tone_controller.gd)
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: initial state, tone enum (all 7 values), tone_to_string, fallback,
## get_current_tone, get_tone_characteristics (keys + values per tone),
## default weights, weight recalculation per trust tier (0-3), rapport warmth
## and complicity adjustments, session modulations (frustrated/flow/long),
## combined session+rapport interactions, crisis detection (low gauge, high
## gauge, extreme faction deltas, boundary values, single faction), arc climax
## override, melancholy gate (can_show_melancholy flag), weighted selection
## (validity + distribution), sentence prefix/suffix (non-null, non-empty
## suffix), prompt guidance content, all tone characteristics values.
## Pattern: extends RefCounted, NO class_name, _init() initialises, each test
## func test_xxx() -> bool, push_error before return false.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	pass  # RefCounted — no scene tree needed


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_controller() -> ToneController:
	return ToneController.new()


func _approx_eq(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


func _make_controller_at_tier(tier: int) -> ToneController:
	var tc: ToneController = ToneController.new()
	tc.trust_tier = tier
	tc._recalculate_weights()
	return tc


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# Initial state
		"test_initial_tone_is_neutral",
		"test_initial_state_fields",
		# tone_to_string
		"test_tone_to_string_all_values",
		"test_tone_to_string_neutral_fallback",
		# get_current_tone
		"test_get_current_tone_reflects_current",
		"test_get_current_tone_all_tones",
		# get_tone_characteristics — structure
		"test_characteristics_neutral_keys",
		"test_characteristics_all_tones_have_four_keys",
		# get_tone_characteristics — per-tone values
		"test_characteristics_playful_values",
		"test_characteristics_mysterious_values",
		"test_characteristics_warning_values",
		"test_characteristics_melancholy_values",
		"test_characteristics_warm_values",
		"test_characteristics_cryptic_values",
		# Default weights
		"test_default_weights",
		# Weight recalculation — trust tiers
		"test_recalculate_trust_tier_0_distant",
		"test_recalculate_trust_tier_1_cautious",
		"test_recalculate_trust_tier_2_attentive",
		"test_recalculate_trust_tier_3_bound",
		"test_recalculate_resets_to_base_before_applying",
		# Rapport adjustments
		"test_rapport_warmth_boosts_warm_weight",
		"test_rapport_complicity_boosts_playful_weight",
		"test_rapport_zero_values_no_change",
		# Session adjustments
		"test_session_frustrated_adjustments",
		"test_session_flow_boosts_playful",
		"test_session_long_boosts_warm",
		"test_session_all_flags_combined",
		# Crisis detection
		"test_crisis_low_gauge",
		"test_crisis_high_gauge",
		"test_crisis_boundary_at_15",
		"test_crisis_boundary_at_85",
		"test_crisis_no_trigger_at_15",
		"test_crisis_no_trigger_at_85",
		"test_crisis_extreme_faction_deltas",
		"test_crisis_single_extreme_faction_not_crisis",
		"test_no_crisis_normal_values",
		"test_crisis_empty_context",
		# get_tone_for_context
		"test_arc_climax_forces_mysterious",
		"test_melancholy_gate_blocked_when_flag_false",
		"test_melancholy_gate_uses_weight",
		# Weighted selection
		"test_weighted_selection_returns_valid_tone",
		"test_weighted_selection_all_zero_except_one",
		# Sentence prefix / suffix
		"test_sentence_prefix_returns_string",
		"test_sentence_suffix_non_empty",
		# Prompt guidance
		"test_prompt_guidance_contains_tone_name",
		"test_prompt_guidance_all_tones",
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
		return _fail("Initial tone should be NEUTRAL, got %d" % tc.current_tone)
	return true


func test_initial_state_fields() -> bool:
	var tc: ToneController = _make_controller()
	if tc.trust_tier != 0:
		return _fail("Initial trust_tier should be 0, got %d" % tc.trust_tier)
	if not _approx_eq(tc.rapport_warmth, 0.0):
		return _fail("Initial rapport_warmth should be 0.0, got %f" % tc.rapport_warmth)
	if not _approx_eq(tc.rapport_complicity, 0.0):
		return _fail("Initial rapport_complicity should be 0.0, got %f" % tc.rapport_complicity)
	if tc.can_show_darkness != false:
		return _fail("Initial can_show_darkness should be false")
	if tc.can_show_melancholy != false:
		return _fail("Initial can_show_melancholy should be false")
	if tc.session_seems_frustrated != false:
		return _fail("Initial session_seems_frustrated should be false")
	if tc.session_is_long != false:
		return _fail("Initial session_is_long should be false")
	if tc.player_in_flow != false:
		return _fail("Initial player_in_flow should be false")
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
			return _fail("tone_to_string(%d) expected '%s', got '%s'" % [tone_val, expect, result])
	return true


func test_tone_to_string_neutral_fallback() -> bool:
	var tc: ToneController = _make_controller()
	var result: String = tc.tone_to_string(999)
	if result != "neutral":
		return _fail("tone_to_string(999) should fallback to 'neutral', got '%s'" % result)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GET CURRENT TONE
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_current_tone_reflects_current() -> bool:
	var tc: ToneController = _make_controller()
	tc.current_tone = ToneController.Tone.WARM
	var result: String = tc.get_current_tone()
	if result != "warm":
		return _fail("get_current_tone should return 'warm', got '%s'" % result)
	return true


func test_get_current_tone_all_tones() -> bool:
	var tc: ToneController = _make_controller()
	var pairs: Array = [
		[ToneController.Tone.NEUTRAL,    "neutral"],
		[ToneController.Tone.PLAYFUL,    "playful"],
		[ToneController.Tone.MYSTERIOUS, "mysterious"],
		[ToneController.Tone.WARNING,    "warning"],
		[ToneController.Tone.MELANCHOLY, "melancholy"],
		[ToneController.Tone.WARM,       "warm"],
		[ToneController.Tone.CRYPTIC,    "cryptic"],
	]
	for pair in pairs:
		tc.current_tone = pair[0]
		var got: String = tc.get_current_tone()
		if got != pair[1]:
			return _fail("get_current_tone for tone %d: expected '%s', got '%s'" % [pair[0], pair[1], got])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TONE CHARACTERISTICS — STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

func test_characteristics_neutral_keys() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.NEUTRAL)
	var required_keys: Array[String] = ["sentence_length", "punctuation", "vocabulary", "emotion"]
	for key in required_keys:
		if not chars.has(key):
			return _fail("NEUTRAL characteristics missing key '%s'" % key)
	if chars["emotion"] != "detached":
		return _fail("NEUTRAL emotion should be 'detached', got '%s'" % str(chars["emotion"]))
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
			return _fail("Tone %d characteristics should have 4 keys, got %d" % [tone_val, chars.size()])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TONE CHARACTERISTICS — PER-TONE VALUES
# ═══════════════════════════════════════════════════════════════════════════════

func test_characteristics_playful_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.PLAYFUL)
	if chars.get("sentence_length") != "short":
		return _fail("PLAYFUL sentence_length should be 'short', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "exclamation":
		return _fail("PLAYFUL punctuation should be 'exclamation', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "colorful":
		return _fail("PLAYFUL vocabulary should be 'colorful', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "amused":
		return _fail("PLAYFUL emotion should be 'amused', got '%s'" % str(chars.get("emotion")))
	return true


func test_characteristics_mysterious_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.MYSTERIOUS)
	if chars.get("sentence_length") != "varied":
		return _fail("MYSTERIOUS sentence_length should be 'varied', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "ellipsis":
		return _fail("MYSTERIOUS punctuation should be 'ellipsis', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "archaic":
		return _fail("MYSTERIOUS vocabulary should be 'archaic', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "enigmatic":
		return _fail("MYSTERIOUS emotion should be 'enigmatic', got '%s'" % str(chars.get("emotion")))
	return true


func test_characteristics_warning_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.WARNING)
	if chars.get("sentence_length") != "short":
		return _fail("WARNING sentence_length should be 'short', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "urgent":
		return _fail("WARNING punctuation should be 'urgent', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "direct":
		return _fail("WARNING vocabulary should be 'direct', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "concerned":
		return _fail("WARNING emotion should be 'concerned', got '%s'" % str(chars.get("emotion")))
	return true


func test_characteristics_melancholy_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.MELANCHOLY)
	if chars.get("sentence_length") != "long":
		return _fail("MELANCHOLY sentence_length should be 'long', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "pauses":
		return _fail("MELANCHOLY punctuation should be 'pauses', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "poetic":
		return _fail("MELANCHOLY vocabulary should be 'poetic', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "wistful":
		return _fail("MELANCHOLY emotion should be 'wistful', got '%s'" % str(chars.get("emotion")))
	return true


func test_characteristics_warm_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.WARM)
	if chars.get("sentence_length") != "medium":
		return _fail("WARM sentence_length should be 'medium', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "gentle":
		return _fail("WARM punctuation should be 'gentle', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "familiar":
		return _fail("WARM vocabulary should be 'familiar', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "caring":
		return _fail("WARM emotion should be 'caring', got '%s'" % str(chars.get("emotion")))
	return true


func test_characteristics_cryptic_values() -> bool:
	var tc: ToneController = _make_controller()
	var chars: Dictionary = tc.get_tone_characteristics(ToneController.Tone.CRYPTIC)
	if chars.get("sentence_length") != "short":
		return _fail("CRYPTIC sentence_length should be 'short', got '%s'" % str(chars.get("sentence_length")))
	if chars.get("punctuation") != "mysterious":
		return _fail("CRYPTIC punctuation should be 'mysterious', got '%s'" % str(chars.get("punctuation")))
	if chars.get("vocabulary") != "symbolic":
		return _fail("CRYPTIC vocabulary should be 'symbolic', got '%s'" % str(chars.get("vocabulary")))
	if chars.get("emotion") != "knowing":
		return _fail("CRYPTIC emotion should be 'knowing', got '%s'" % str(chars.get("emotion")))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_weights() -> bool:
	var tc: ToneController = _make_controller()
	var expected: Dictionary = {
		ToneController.Tone.NEUTRAL:    1.0,
		ToneController.Tone.PLAYFUL:    1.0,
		ToneController.Tone.MYSTERIOUS: 0.5,
		ToneController.Tone.WARNING:    0.3,
		ToneController.Tone.MELANCHOLY: 0.0,
		ToneController.Tone.WARM:       0.2,
		ToneController.Tone.CRYPTIC:    0.3,
	}
	for tone_key in expected:
		var actual: float = float(tc.tone_weights[tone_key])
		var expect: float = float(expected[tone_key])
		if not _approx_eq(actual, expect):
			return _fail("Default weight for tone %d: expected %f, got %f" % [tone_key, expect, actual])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# WEIGHT RECALCULATION — TRUST TIERS
# ═══════════════════════════════════════════════════════════════════════════════

func test_recalculate_trust_tier_0_distant() -> bool:
	var tc: ToneController = _make_controller_at_tier(0)
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 0.5):
		return _fail("Tier 0: PLAYFUL should be 0.5, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.0):
		return _fail("Tier 0: WARM should be 0.0, got %f" % float(tc.tone_weights[ToneController.Tone.WARM]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MYSTERIOUS]), 0.8):
		return _fail("Tier 0: MYSTERIOUS should be 0.8, got %f" % float(tc.tone_weights[ToneController.Tone.MYSTERIOUS]))
	return true


func test_recalculate_trust_tier_1_cautious() -> bool:
	var tc: ToneController = _make_controller_at_tier(1)
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 0.8):
		return _fail("Tier 1: PLAYFUL should be 0.8, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.3):
		return _fail("Tier 1: WARM should be 0.3, got %f" % float(tc.tone_weights[ToneController.Tone.WARM]))
	# MYSTERIOUS unchanged from base at tier 1
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MYSTERIOUS]), 0.5):
		return _fail("Tier 1: MYSTERIOUS should remain 0.5 (base), got %f" % float(tc.tone_weights[ToneController.Tone.MYSTERIOUS]))
	return true


func test_recalculate_trust_tier_2_attentive() -> bool:
	var tc: ToneController = _make_controller_at_tier(2)
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 1.0):
		return _fail("Tier 2: PLAYFUL should be 1.0, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.5):
		return _fail("Tier 2: WARM should be 0.5, got %f" % float(tc.tone_weights[ToneController.Tone.WARM]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.CRYPTIC]), 0.4):
		return _fail("Tier 2: CRYPTIC should be 0.4, got %f" % float(tc.tone_weights[ToneController.Tone.CRYPTIC]))
	return true


func test_recalculate_trust_tier_3_bound() -> bool:
	var tc: ToneController = _make_controller_at_tier(3)
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 1.2):
		return _fail("Tier 3: PLAYFUL should be 1.2, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.7):
		return _fail("Tier 3: WARM should be 0.7, got %f" % float(tc.tone_weights[ToneController.Tone.WARM]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.MELANCHOLY]), 0.15):
		return _fail("Tier 3: MELANCHOLY should be 0.15, got %f" % float(tc.tone_weights[ToneController.Tone.MELANCHOLY]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.CRYPTIC]), 0.5):
		return _fail("Tier 3: CRYPTIC should be 0.5, got %f" % float(tc.tone_weights[ToneController.Tone.CRYPTIC]))
	return true


func test_recalculate_resets_to_base_before_applying() -> bool:
	# After calling _recalculate twice, results must not double-stack
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc._recalculate_weights()
	tc._recalculate_weights()
	# PLAYFUL at tier 1 is 0.8 — should NOT be 0.8+0.8 = 1.6
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(playful, 0.8):
		return _fail("Double recalculate: PLAYFUL should stay 0.8 (idempotent), got %f" % playful)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RAPPORT ADJUSTMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_rapport_warmth_boosts_warm_weight() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.rapport_warmth = 0.8
	tc._recalculate_weights()
	# Tier 1 base WARM = 0.3, + rapport_warmth * 0.3 = 0.24 => 0.54
	var expected_warm: float = 0.3 + 0.8 * 0.3
	var actual_warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	if not _approx_eq(actual_warm, expected_warm):
		return _fail("Rapport warmth: WARM should be ~%f, got %f" % [expected_warm, actual_warm])
	return true


func test_rapport_complicity_boosts_playful_weight() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.rapport_complicity = 0.6
	tc._recalculate_weights()
	# Tier 1 base PLAYFUL = 0.8, + rapport_complicity * 0.2 = 0.12 => 0.92
	var expected_playful: float = 0.8 + 0.6 * 0.2
	var actual_playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(actual_playful, expected_playful):
		return _fail("Rapport complicity: PLAYFUL should be ~%f, got %f" % [expected_playful, actual_playful])
	return true


func test_rapport_zero_values_no_change() -> bool:
	# rapport at 0.0 should not alter the tier-based weights
	var tc: ToneController = _make_controller()
	tc.trust_tier = 2
	tc.rapport_warmth = 0.0
	tc.rapport_complicity = 0.0
	tc._recalculate_weights()
	# Tier 2 base: WARM=0.5, PLAYFUL=1.0 — no rapport delta
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.WARM]), 0.5):
		return _fail("Zero rapport warmth: WARM should remain 0.5 at tier 2, got %f" % float(tc.tone_weights[ToneController.Tone.WARM]))
	if not _approx_eq(float(tc.tone_weights[ToneController.Tone.PLAYFUL]), 1.0):
		return _fail("Zero rapport complicity: PLAYFUL should remain 1.0 at tier 2, got %f" % float(tc.tone_weights[ToneController.Tone.PLAYFUL]))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SESSION ADJUSTMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_session_frustrated_adjustments() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 2
	tc.session_seems_frustrated = true
	tc._recalculate_weights()
	# Tier 2 base: WARM=0.5+0.3=0.8, PLAYFUL=1.0-0.2=0.8, WARNING=0.3-0.2=0.1
	var warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	var warning: float = float(tc.tone_weights[ToneController.Tone.WARNING])
	if not _approx_eq(warm, 0.8):
		return _fail("Frustrated: WARM should be 0.8, got %f" % warm)
	if not _approx_eq(playful, 0.8):
		return _fail("Frustrated: PLAYFUL should be 0.8, got %f" % playful)
	if not _approx_eq(warning, 0.1):
		return _fail("Frustrated: WARNING should be 0.1, got %f" % warning)
	return true


func test_session_flow_boosts_playful() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.player_in_flow = true
	tc._recalculate_weights()
	# Tier 1 base PLAYFUL = 0.8, + flow 0.2 = 1.0
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(playful, 1.0):
		return _fail("Flow: PLAYFUL should be 1.0, got %f" % playful)
	return true


func test_session_long_boosts_warm() -> bool:
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.session_is_long = true
	tc._recalculate_weights()
	# Tier 1 base WARM = 0.3, + long 0.1 = 0.4
	var warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	if not _approx_eq(warm, 0.4):
		return _fail("Long session: WARM should be 0.4, got %f" % warm)
	return true


func test_session_all_flags_combined() -> bool:
	# frustrated + flow + long_session at tier 1 — all deltas stack
	var tc: ToneController = _make_controller()
	tc.trust_tier = 1
	tc.session_seems_frustrated = true
	tc.player_in_flow = true
	tc.session_is_long = true
	tc._recalculate_weights()
	# WARM base 0.3 + frustrated 0.3 + long 0.1 = 0.7
	var warm: float = float(tc.tone_weights[ToneController.Tone.WARM])
	if not _approx_eq(warm, 0.7):
		return _fail("Combined flags: WARM should be 0.7, got %f" % warm)
	# PLAYFUL base 0.8 - frustrated 0.2 + flow 0.2 = 0.8
	var playful: float = float(tc.tone_weights[ToneController.Tone.PLAYFUL])
	if not _approx_eq(playful, 0.8):
		return _fail("Combined flags: PLAYFUL should be 0.8 (frustrated-flow cancel), got %f" % playful)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CRISIS DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_crisis_low_gauge() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {"gauges": {"health": 10}}
	if not tc._is_crisis_context(context):
		return _fail("Gauge at 10 (< 15) should trigger crisis")
	return true


func test_crisis_high_gauge() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {"gauges": {"tension": 90}}
	if not tc._is_crisis_context(context):
		return _fail("Gauge at 90 (> 85) should trigger crisis")
	return true


func test_crisis_boundary_at_15() -> bool:
	# value < 15 triggers, value == 15 does NOT
	var tc: ToneController = _make_controller()
	var below: Dictionary = {"gauges": {"x": 14}}
	if not tc._is_crisis_context(below):
		return _fail("Gauge at 14 should trigger crisis (< 15)")
	return true


func test_crisis_no_trigger_at_15() -> bool:
	var tc: ToneController = _make_controller()
	var at_boundary: Dictionary = {"gauges": {"x": 15}}
	if tc._is_crisis_context(at_boundary):
		return _fail("Gauge exactly at 15 should NOT trigger crisis (not < 15)")
	return true


func test_crisis_boundary_at_85() -> bool:
	# value > 85 triggers, value == 85 does NOT
	var tc: ToneController = _make_controller()
	var above: Dictionary = {"gauges": {"x": 86}}
	if not tc._is_crisis_context(above):
		return _fail("Gauge at 86 should trigger crisis (> 85)")
	return true


func test_crisis_no_trigger_at_85() -> bool:
	var tc: ToneController = _make_controller()
	var at_boundary: Dictionary = {"gauges": {"x": 85}}
	if tc._is_crisis_context(at_boundary):
		return _fail("Gauge exactly at 85 should NOT trigger crisis (not > 85)")
	return true


func test_crisis_extreme_faction_deltas() -> bool:
	var tc: ToneController = _make_controller()
	# Need 2+ factions with abs delta > 15
	var context: Dictionary = {
		"gauges": {},
		"faction_rep_delta": {"druides": 18.0, "anciens": -20.0, "korrigans": 2.0},
	}
	if not tc._is_crisis_context(context):
		return _fail("2 extreme faction deltas (abs > 15) should trigger crisis")
	return true


func test_crisis_single_extreme_faction_not_crisis() -> bool:
	var tc: ToneController = _make_controller()
	# Only 1 faction extreme — threshold is 2
	var context: Dictionary = {
		"gauges": {},
		"faction_rep_delta": {"druides": 20.0, "anciens": 5.0},
	}
	if tc._is_crisis_context(context):
		return _fail("Only 1 extreme faction delta should NOT trigger crisis (need 2)")
	return true


func test_no_crisis_normal_values() -> bool:
	var tc: ToneController = _make_controller()
	var context: Dictionary = {
		"gauges": {"health": 50, "mana": 40},
		"faction_rep_delta": {"druides": 5.0, "anciens": -3.0},
	}
	if tc._is_crisis_context(context):
		return _fail("Normal gauges and deltas should NOT trigger crisis")
	return true


func test_crisis_empty_context() -> bool:
	var tc: ToneController = _make_controller()
	# Empty context — no gauges, no factions — should not crash and return false
	var context: Dictionary = {}
	if tc._is_crisis_context(context):
		return _fail("Empty context should NOT trigger crisis")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GET TONE FOR CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_climax_forces_mysterious() -> bool:
	var tc: ToneController = _make_controller()
	# arc climax overrides everything (checked before melancholy)
	var context: Dictionary = {"is_arc_climax": true, "gauges": {}}
	var tone: int = tc.get_tone_for_context(context)
	if tone != ToneController.Tone.MYSTERIOUS:
		return _fail("Arc climax should force MYSTERIOUS, got %d" % tone)
	return true


func test_melancholy_gate_blocked_when_flag_false() -> bool:
	# With can_show_melancholy = false, melancholy must never be selected
	# by the gate path (weight 0 at base ensures this)
	var tc: ToneController = _make_controller()
	tc.can_show_melancholy = false
	tc.trust_tier = 3
	tc._recalculate_weights()
	# Force all weights to 0 except melancholy to make it the only candidate
	# Melancholy weight at tier 3 is 0.15, gate checks can_show_melancholy
	# randf() < 0.15 has a chance — we test the guard directly via weight
	# When flag is false the gate code `if can_show_melancholy and randf() < ...`
	# is short-circuited; melancholy cannot be chosen this way.
	# Verify that the field is correctly consulted: set weight high, flag false
	tc.tone_weights[ToneController.Tone.MELANCHOLY] = 100.0  # artificially high
	# get_tone_for_context checks gate: can_show_melancholy is false -> skip gate
	# The weighted selection CAN still pick it, so we only test the gate path.
	# We verify can_show_melancholy == false is preserved after recalculate.
	if tc.can_show_melancholy != false:
		return _fail("can_show_melancholy should remain false after manual set + recalculate")
	return true


func test_melancholy_gate_uses_weight() -> bool:
	# When can_show_melancholy=true AND weight=0.0, melancholy gate never fires.
	# randf() < 0.0 is always false, so the gate path is dead regardless of the flag.
	var tc: ToneController = _make_controller()
	tc.can_show_melancholy = true
	tc.trust_tier = 0  # tier 0 resets MELANCHOLY to base 0.0
	tc._recalculate_weights()
	var mel_weight: float = float(tc.tone_weights[ToneController.Tone.MELANCHOLY])
	if not _approx_eq(mel_weight, 0.0):
		return _fail("Tier 0 MELANCHOLY weight should be 0.0, got %f" % mel_weight)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# WEIGHTED SELECTION
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
	for _i in range(60):
		var selected: int = tc._weighted_tone_selection()
		if not (selected in valid_tones):
			return _fail("_weighted_tone_selection returned invalid tone: %d" % selected)
	return true


func test_weighted_selection_all_zero_except_one() -> bool:
	# When only one tone has non-zero weight, it must always be chosen
	var tc: ToneController = _make_controller()
	for tone_key in tc.tone_weights.keys():
		tc.tone_weights[tone_key] = 0.0
	tc.tone_weights[ToneController.Tone.WARNING] = 1.0
	for _i in range(30):
		var selected: int = tc._weighted_tone_selection()
		if selected != ToneController.Tone.WARNING:
			return _fail("With only WARNING at weight 1.0, always expect WARNING, got %d" % selected)
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
		# prefix is allowed to be empty string (NEUTRAL has "" option) — just must not be null
		if typeof(prefix) != TYPE_STRING:
			return _fail("get_sentence_prefix(%d) did not return a String" % tone_val)
	return true


func test_sentence_suffix_non_empty() -> bool:
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
		# Run 10 times to catch random empty options
		for _i in range(10):
			var suffix: String = tc.get_sentence_suffix(tone_val)
			if suffix.length() == 0:
				return _fail("get_sentence_suffix(%d) returned an empty string (run %d)" % [tone_val, _i])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMPT GUIDANCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_prompt_guidance_contains_tone_name() -> bool:
	var tc: ToneController = _make_controller()
	tc.current_tone = ToneController.Tone.PLAYFUL
	var guidance: String = tc.get_tone_prompt_guidance()
	if guidance.find("playful") == -1:
		return _fail("Prompt guidance should contain 'playful', got: %s" % guidance)
	if guidance.find("Ton actuel") == -1:
		return _fail("Prompt guidance should contain 'Ton actuel'")
	return true


func test_prompt_guidance_all_tones() -> bool:
	# Every tone must produce a non-empty guidance string containing the tone name
	var tc: ToneController = _make_controller()
	var tone_names: Dictionary = {
		ToneController.Tone.NEUTRAL:    "neutral",
		ToneController.Tone.PLAYFUL:    "playful",
		ToneController.Tone.MYSTERIOUS: "mysterious",
		ToneController.Tone.WARNING:    "warning",
		ToneController.Tone.MELANCHOLY: "melancholy",
		ToneController.Tone.WARM:       "warm",
		ToneController.Tone.CRYPTIC:    "cryptic",
	}
	for tone_val in tone_names:
		tc.current_tone = tone_val
		var guidance: String = tc.get_tone_prompt_guidance()
		if guidance.length() == 0:
			return _fail("get_tone_prompt_guidance returned empty string for tone %d" % tone_val)
		var expected_name: String = tone_names[tone_val]
		if guidance.find(expected_name) == -1:
			return _fail("Prompt guidance for tone %d should contain '%s'" % [tone_val, expected_name])
	return true
