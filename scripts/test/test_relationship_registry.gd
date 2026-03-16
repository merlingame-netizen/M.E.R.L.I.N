## test_relationship_registry.gd
## Unit tests for RelationshipRegistry — RefCounted pattern, no GUT dependency.
## Covers: initialization, trust tiers, rapport shifts, interaction recording,
##         special moments, tone modifiers, voice patterns, LLM context, decay math.
##
## BYPASS strategy for _init():
##   var reg = RelationshipRegistry.new()
##   reg.reset()                   # wipe any save file pollution
##   reg.last_session_date = 0     # prevent _apply_absence_decay side effects
## This gives a clean zero-state for every test.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _make() -> RelationshipRegistry:
	var reg: RelationshipRegistry = RelationshipRegistry.new()
	reg.reset()
	reg.last_session_date = 0
	return reg


static func _approx_eq(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) < epsilon


# ═══════════════════════════════════════════════════════════════════════════════
# 1. INITIALIZATION — fresh instance has expected defaults
# ═══════════════════════════════════════════════════════════════════════════════

func test_init_default_tier_is_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.trust_tier != RelationshipRegistry.TrustTier.DISTANT:
		push_error("Expected DISTANT tier after reset, got: " + str(reg.trust_tier))
		return false
	return true


func test_init_trust_points_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.trust_points != 0:
		push_error("Expected 0 trust_points after reset, got: " + str(reg.trust_points))
		return false
	return true


func test_init_rapport_keys_present() -> bool:
	var reg: RelationshipRegistry = _make()
	for key in ["respect", "warmth", "complicity", "reverence", "familiarity"]:
		if not reg.rapport.has(key):
			push_error("Rapport missing key: " + key)
			return false
	return true


func test_init_rapport_default_values() -> bool:
	var reg: RelationshipRegistry = _make()
	if not _approx_eq(reg.rapport["respect"], 0.3):
		push_error("Default respect should be 0.3, got: " + str(reg.rapport["respect"]))
		return false
	if not _approx_eq(reg.rapport["warmth"], 0.2):
		push_error("Default warmth should be 0.2, got: " + str(reg.rapport["warmth"]))
		return false
	if not _approx_eq(reg.rapport["reverence"], 0.1):
		push_error("Default reverence should be 0.1, got: " + str(reg.rapport["reverence"]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. TRUST TIER TRANSITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_update_trust_unknown_event_is_noop() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.update_trust("nonexistent_event_xyz")
	if reg.trust_points != 0:
		push_error("Unknown event should not change trust_points, got: " + str(reg.trust_points))
		return false
	return true


func test_update_trust_promise_kept_adds_10() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.update_trust("promise_kept")
	if reg.trust_points != 10:
		push_error("promise_kept should add 10 points, got: " + str(reg.trust_points))
		return false
	return true


func test_update_trust_promise_broken_subtracts_15() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 20
	reg.update_trust("promise_broken")
	if reg.trust_points != 5:
		push_error("promise_broken should subtract 15, got: " + str(reg.trust_points))
		return false
	return true


func test_update_trust_clamped_at_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 2
	reg.update_trust("promise_broken")  # -15
	if reg.trust_points != 0:
		push_error("trust_points should not go below 0, got: " + str(reg.trust_points))
		return false
	return true


func test_update_trust_clamped_at_100() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 97
	reg.update_trust("promise_kept")  # +10 would exceed 100
	if reg.trust_points != 100:
		push_error("trust_points should not exceed 100, got: " + str(reg.trust_points))
		return false
	return true


func test_tier_becomes_cautious_at_threshold_25() -> bool:
	var reg: RelationshipRegistry = _make()
	# Accumulate to exactly 25 via followed_hint (+3 each)
	for _i in range(8):
		reg.update_trust("followed_hint")  # 8 * 3 = 24
	reg.update_trust("followed_hint")  # -> 27, crosses 25
	if reg.trust_tier != RelationshipRegistry.TrustTier.CAUTIOUS:
		push_error("Expected CAUTIOUS at >= 25 points, got tier: " + str(reg.trust_tier))
		return false
	return true


func test_tier_becomes_attentive_at_threshold_50() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 48
	reg.update_trust("promise_kept")  # +10 -> 58
	if reg.trust_tier != RelationshipRegistry.TrustTier.ATTENTIVE:
		push_error("Expected ATTENTIVE at >= 50 points, got tier: " + str(reg.trust_tier))
		return false
	return true


func test_tier_becomes_bound_at_threshold_75() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 74
	reg.update_trust("followed_hint")  # +3 -> 77
	if reg.trust_tier != RelationshipRegistry.TrustTier.BOUND:
		push_error("Expected BOUND at >= 75 points, got tier: " + str(reg.trust_tier))
		return false
	return true


func test_tier_stays_distant_below_25() -> bool:
	# Start at 22 points. quick_death = -2 -> 20. Still below threshold 25.
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 22
	reg.trust_tier = RelationshipRegistry.TrustTier.DISTANT
	reg.update_trust("quick_death")  # -2 -> 20, still < 25
	if reg.trust_tier != RelationshipRegistry.TrustTier.DISTANT:
		push_error("24 points should still be DISTANT (threshold is 25), got tier: " + str(reg.trust_tier))
		return false
	if reg.trust_points != 20:
		push_error("Expected 20 trust_points, got: " + str(reg.trust_points))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. RAPPORT SHIFTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_promise_kept_shifts_respect_up() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["respect"]
	reg.update_trust("promise_kept")
	if reg.rapport["respect"] <= before:
		push_error("promise_kept should increase respect")
		return false
	return true


func test_promise_broken_shifts_warmth_down() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["warmth"]
	reg.trust_points = 20  # Avoid going negative on trust_points floor interaction
	reg.update_trust("promise_broken")
	if reg.rapport["warmth"] >= before:
		push_error("promise_broken should decrease warmth, before=" + str(before) + " after=" + str(reg.rapport["warmth"]))
		return false
	return true


func test_rapport_values_clamped_at_1_0() -> bool:
	var reg: RelationshipRegistry = _make()
	# Drive respect up by repeating promise_kept many times
	for _i in range(20):
		reg.update_trust("promise_kept")
	if reg.rapport["respect"] > 1.0:
		push_error("rapport respect exceeded 1.0: " + str(reg.rapport["respect"]))
		return false
	return true


func test_rapport_values_clamped_at_0_0() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 100  # Max so subtractions don't floor to 0
	# Drive warmth down by repeating promise_broken
	for _i in range(20):
		reg.update_trust("promise_broken")
	if reg.rapport["warmth"] < 0.0:
		push_error("rapport warmth went below 0.0: " + str(reg.rapport["warmth"]))
		return false
	return true


func test_thanked_merlin_shifts_warmth_and_complicity() -> bool:
	var reg: RelationshipRegistry = _make()
	var w_before: float = reg.rapport["warmth"]
	var c_before: float = reg.rapport["complicity"]
	reg.update_trust("thanked_merlin")
	if reg.rapport["warmth"] <= w_before:
		push_error("thanked_merlin should increase warmth")
		return false
	if reg.rapport["complicity"] <= c_before:
		push_error("thanked_merlin should increase complicity")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. INTERACTION RECORDING
# ═══════════════════════════════════════════════════════════════════════════════

func test_record_interaction_increments_counter() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("promises_proposed")
	reg.record_interaction("promises_proposed")
	if reg.interactions["promises_proposed"] != 2:
		push_error("promises_proposed should be 2, got: " + str(reg.interactions["promises_proposed"]))
		return false
	return true


func test_record_interaction_unknown_key_is_ignored() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("completely_unknown_interaction")
	# Should not crash and no new key should appear
	if reg.interactions.has("completely_unknown_interaction"):
		push_error("Unknown interaction key should not be added to dict")
		return false
	return true


func test_record_interaction_promises_kept_triggers_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("promises_kept")
	# record_interaction("promises_kept") calls update_trust("promise_kept") -> +10
	if reg.trust_points != 10:
		push_error("promises_kept interaction should trigger +10 trust, got: " + str(reg.trust_points))
		return false
	return true


func test_record_interaction_hints_followed_triggers_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("hints_followed")
	# calls update_trust("followed_hint") -> +3
	if reg.trust_points != 3:
		push_error("hints_followed interaction should trigger +3 trust, got: " + str(reg.trust_points))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. SPECIAL MOMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_trigger_special_moment_returns_true_first_time() -> bool:
	var reg: RelationshipRegistry = _make()
	var result: bool = reg.trigger_special_moment("has_seen_melancholy")
	if not result:
		push_error("First trigger of has_seen_melancholy should return true")
		return false
	return true


func test_trigger_special_moment_returns_false_second_time() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trigger_special_moment("has_seen_melancholy")
	var result: bool = reg.trigger_special_moment("has_seen_melancholy")
	if result:
		push_error("Second trigger of already-triggered moment should return false")
		return false
	return true


func test_trigger_special_moment_unknown_key_returns_false() -> bool:
	var reg: RelationshipRegistry = _make()
	var result: bool = reg.trigger_special_moment("nonexistent_moment_xyz")
	if result:
		push_error("Triggering unknown moment should return false")
		return false
	return true


func test_trigger_special_moment_grants_bonus_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	var points_before: int = reg.trust_points
	reg.trigger_special_moment("witnessed_prophecy")
	# Should have called update_trust("discovered_lore") -> +2
	if reg.trust_points != points_before + 2:
		push_error("Triggering special moment should grant +2 trust, got delta: " + str(reg.trust_points - points_before))
		return false
	return true


func test_check_special_moment_thanked_at_3_triggers() -> bool:
	var reg: RelationshipRegistry = _make()
	# Need 3 thank_yous interactions to trigger thanked_merlin_sincerely
	reg.record_interaction("thank_yous")
	reg.record_interaction("thank_yous")
	if reg.special_moments["thanked_merlin_sincerely"]:
		push_error("Should not trigger after only 2 thank_yous")
		return false
	reg.record_interaction("thank_yous")
	if not reg.special_moments["thanked_merlin_sincerely"]:
		push_error("Should trigger thanked_merlin_sincerely after 3 thank_yous")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. CAN-SHOW PREDICATES
# ═══════════════════════════════════════════════════════════════════════════════

func test_can_show_melancholy_false_when_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	# DISTANT and has_seen_melancholy = false
	if reg.can_show_melancholy():
		push_error("DISTANT tier without flag should not be able to show melancholy")
		return false
	return true


func test_can_show_melancholy_true_when_bound() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	if not reg.can_show_melancholy():
		push_error("BOUND tier should be able to show melancholy")
		return false
	return true


func test_can_show_melancholy_true_with_flag_even_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.special_moments["has_seen_melancholy"] = true
	if not reg.can_show_melancholy():
		push_error("Flag has_seen_melancholy should allow showing melancholy even at DISTANT")
		return false
	return true


func test_can_show_slip_false_when_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.can_show_slip():
		push_error("DISTANT should not be able to show slip")
		return false
	return true


func test_can_show_slip_true_at_attentive() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	if not reg.can_show_slip():
		push_error("ATTENTIVE should be able to show slip")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. TONE MODIFIERS & VOICE PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

func test_tone_modifiers_keys_present() -> bool:
	var reg: RelationshipRegistry = _make()
	var mods: Dictionary = reg.get_tone_modifiers()
	for key in ["humor", "darkness", "warmth", "verbosity"]:
		if not mods.has(key):
			push_error("get_tone_modifiers missing key: " + key)
			return false
	return true


func test_tone_warmth_higher_at_bound_than_distant() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var warmth_distant: float = reg_d.get_tone_modifiers()["warmth"]
	var warmth_bound: float = reg_b.get_tone_modifiers()["warmth"]
	if warmth_bound <= warmth_distant:
		push_error("BOUND warmth should exceed DISTANT warmth, got bound=%s distant=%s" % [warmth_bound, warmth_distant])
		return false
	return true


func test_sentence_length_modifier_increases_with_tier() -> bool:
	var reg: RelationshipRegistry = _make()
	var distant_mod: float = reg.get_sentence_length_modifier()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var bound_mod: float = reg.get_sentence_length_modifier()
	if bound_mod <= distant_mod:
		push_error("BOUND sentence modifier should exceed DISTANT, got bound=%s distant=%s" % [bound_mod, distant_mod])
		return false
	return true


func test_should_use_player_name_false_at_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.should_use_player_name():
		push_error("DISTANT should not use player name")
		return false
	return true


func test_should_use_player_name_true_at_cautious() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	if not reg.should_use_player_name():
		push_error("CAUTIOUS should use player name")
		return false
	return true


func test_taunt_intensity_higher_at_bound_than_distant() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var taunt_d: float = reg_d.get_taunt_intensity()
	var taunt_b: float = reg_b.get_taunt_intensity()
	if taunt_b <= taunt_d:
		push_error("BOUND taunt intensity should exceed DISTANT, got bound=%s distant=%s" % [taunt_b, taunt_d])
		return false
	return true


func test_can_reveal_lore_depth_1_always() -> bool:
	var reg: RelationshipRegistry = _make()
	if not reg.can_reveal_lore_depth(1):
		push_error("DISTANT should always allow lore depth 1")
		return false
	return true


func test_can_reveal_lore_depth_2_requires_cautious() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_c: RelationshipRegistry = _make()
	reg_c.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	if reg_d.can_reveal_lore_depth(2):
		push_error("DISTANT should NOT allow lore depth 2")
		return false
	if not reg_c.can_reveal_lore_depth(2):
		push_error("CAUTIOUS should allow lore depth 2")
		return false
	return true


func test_can_reveal_lore_depth_5_impossible_even_bound() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	if reg.can_reveal_lore_depth(5):
		push_error("BOUND should NOT allow lore depth 5 (max is 4)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. LLM CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_context_for_llm_has_required_keys() -> bool:
	var reg: RelationshipRegistry = _make()
	var ctx: Dictionary = reg.get_context_for_llm()
	for key in ["trust_tier", "trust_tier_name", "trust_points", "rapport", "tone_mods",
				"can_show_darkness", "can_show_melancholy", "taunt_intensity"]:
		if not ctx.has(key):
			push_error("get_context_for_llm missing key: " + key)
			return false
	return true


func test_get_trust_tier_name_all_tiers() -> bool:
	var reg: RelationshipRegistry = _make()
	var names: Array[String] = ["Distant", "Prudent", "Attentif", "Lie"]
	var tiers: Array[int] = [
		RelationshipRegistry.TrustTier.DISTANT,
		RelationshipRegistry.TrustTier.CAUTIOUS,
		RelationshipRegistry.TrustTier.ATTENTIVE,
		RelationshipRegistry.TrustTier.BOUND,
	]
	for i in range(4):
		reg.trust_tier = tiers[i]
		var name: String = reg.get_trust_tier_name()
		if name != names[i]:
			push_error("Tier %d should be named '%s', got '%s'" % [tiers[i], names[i], name])
			return false
	return true


func test_get_summary_for_prompt_contains_tier_name() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	reg.trust_points = 55
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("Attentif"):
		push_error("Summary should contain tier name 'Attentif', got: " + summary)
		return false
	if not summary.contains("55"):
		push_error("Summary should contain trust_points 55, got: " + summary)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. RESET
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_zeroes_trust_points() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 80
	reg.reset()
	if reg.trust_points != 0:
		push_error("reset() should zero trust_points, got: " + str(reg.trust_points))
		return false
	return true


func test_reset_restores_default_rapport() -> bool:
	var reg: RelationshipRegistry = _make()
	# Dirty the rapport
	reg.rapport["warmth"] = 0.99
	reg.rapport["respect"] = 0.01
	reg.reset()
	if not _approx_eq(reg.rapport["warmth"], 0.2):
		push_error("reset() should restore warmth to 0.2, got: " + str(reg.rapport["warmth"]))
		return false
	if not _approx_eq(reg.rapport["respect"], 0.3):
		push_error("reset() should restore respect to 0.3, got: " + str(reg.rapport["respect"]))
		return false
	return true


func test_reset_zeroes_interactions() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.interactions["defiances"] = 99
	reg.reset()
	if reg.interactions["defiances"] != 0:
		push_error("reset() should zero interactions, got defiances=" + str(reg.interactions["defiances"]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_init_default_tier_is_distant",
		"test_init_trust_points_zero",
		"test_init_rapport_keys_present",
		"test_init_rapport_default_values",
		"test_update_trust_unknown_event_is_noop",
		"test_update_trust_promise_kept_adds_10",
		"test_update_trust_promise_broken_subtracts_15",
		"test_update_trust_clamped_at_zero",
		"test_update_trust_clamped_at_100",
		"test_tier_becomes_cautious_at_threshold_25",
		"test_tier_becomes_attentive_at_threshold_50",
		"test_tier_becomes_bound_at_threshold_75",
		"test_tier_stays_distant_below_25",
		"test_promise_kept_shifts_respect_up",
		"test_promise_broken_shifts_warmth_down",
		"test_rapport_values_clamped_at_1_0",
		"test_rapport_values_clamped_at_0_0",
		"test_thanked_merlin_shifts_warmth_and_complicity",
		"test_record_interaction_increments_counter",
		"test_record_interaction_unknown_key_is_ignored",
		"test_record_interaction_promises_kept_triggers_trust",
		"test_record_interaction_hints_followed_triggers_trust",
		"test_trigger_special_moment_returns_true_first_time",
		"test_trigger_special_moment_returns_false_second_time",
		"test_trigger_special_moment_unknown_key_returns_false",
		"test_trigger_special_moment_grants_bonus_trust",
		"test_check_special_moment_thanked_at_3_triggers",
		"test_can_show_melancholy_false_when_distant",
		"test_can_show_melancholy_true_when_bound",
		"test_can_show_melancholy_true_with_flag_even_distant",
		"test_can_show_slip_false_when_distant",
		"test_can_show_slip_true_at_attentive",
		"test_tone_modifiers_keys_present",
		"test_tone_warmth_higher_at_bound_than_distant",
		"test_sentence_length_modifier_increases_with_tier",
		"test_should_use_player_name_false_at_distant",
		"test_should_use_player_name_true_at_cautious",
		"test_taunt_intensity_higher_at_bound_than_distant",
		"test_can_reveal_lore_depth_1_always",
		"test_can_reveal_lore_depth_2_requires_cautious",
		"test_can_reveal_lore_depth_5_impossible_even_bound",
		"test_get_context_for_llm_has_required_keys",
		"test_get_trust_tier_name_all_tiers",
		"test_get_summary_for_prompt_contains_tier_name",
		"test_reset_zeroes_trust_points",
		"test_reset_restores_default_rapport",
		"test_reset_zeroes_interactions",
	]
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		var result: bool = call(test_name)
		if result:
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"failures": failures,
	}
