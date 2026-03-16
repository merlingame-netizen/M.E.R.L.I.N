## test_relationship_registry.gd
## Unit tests for RelationshipRegistry — RefCounted pattern, no GUT dependency.
## Covers: initialization, trust tiers, rapport shifts, interaction recording,
##         special moments, tone modifiers, voice patterns, LLM context, decay math,
##         negative trust events, lore depth boundaries, promise tracking,
##         defiances moment, long_run rapport, ignored_warning paths.
##
## Rules: extends RefCounted, no class_name, no assert, no await.
## Helper _fail(msg) -> bool: push_error + return false.
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

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


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
		return _fail("Expected DISTANT tier after reset, got: " + str(reg.trust_tier))
	return true


func test_init_trust_points_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.trust_points != 0:
		return _fail("Expected 0 trust_points after reset, got: " + str(reg.trust_points))
	return true


func test_init_rapport_keys_present() -> bool:
	var reg: RelationshipRegistry = _make()
	for key in ["respect", "warmth", "complicity", "reverence", "familiarity"]:
		if not reg.rapport.has(key):
			return _fail("Rapport missing key: " + key)
	return true


func test_init_rapport_default_values() -> bool:
	var reg: RelationshipRegistry = _make()
	if not _approx_eq(reg.rapport["respect"], 0.3):
		return _fail("Default respect should be 0.3, got: " + str(reg.rapport["respect"]))
	if not _approx_eq(reg.rapport["warmth"], 0.2):
		return _fail("Default warmth should be 0.2, got: " + str(reg.rapport["warmth"]))
	if not _approx_eq(reg.rapport["reverence"], 0.1):
		return _fail("Default reverence should be 0.1, got: " + str(reg.rapport["reverence"]))
	if not _approx_eq(reg.rapport["complicity"], 0.2):
		return _fail("Default complicity should be 0.2, got: " + str(reg.rapport["complicity"]))
	if not _approx_eq(reg.rapport["familiarity"], 0.2):
		return _fail("Default familiarity should be 0.2, got: " + str(reg.rapport["familiarity"]))
	return true


func test_init_interaction_counters_all_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	for key in reg.interactions:
		if reg.interactions[key] != 0:
			return _fail("Interaction counter '%s' should be 0 after reset, got: %d" % [key, reg.interactions[key]])
	return true


func test_init_special_moments_all_false() -> bool:
	var reg: RelationshipRegistry = _make()
	for key in reg.special_moments:
		if reg.special_moments[key] != false:
			return _fail("Special moment '%s' should be false after reset, got: %s" % [key, str(reg.special_moments[key])])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. TRUST TIER TRANSITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_update_trust_unknown_event_is_noop() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.update_trust("nonexistent_event_xyz")
	if reg.trust_points != 0:
		return _fail("Unknown event should not change trust_points, got: " + str(reg.trust_points))
	return true


func test_update_trust_promise_kept_adds_10() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.update_trust("promise_kept")
	if reg.trust_points != 10:
		return _fail("promise_kept should add 10 points, got: " + str(reg.trust_points))
	return true


func test_update_trust_promise_broken_subtracts_15() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 20
	reg.update_trust("promise_broken")
	if reg.trust_points != 5:
		return _fail("promise_broken should subtract 15, got: " + str(reg.trust_points))
	return true


func test_update_trust_clamped_at_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 2
	reg.update_trust("promise_broken")  # -15
	if reg.trust_points != 0:
		return _fail("trust_points should not go below 0, got: " + str(reg.trust_points))
	return true


func test_update_trust_clamped_at_100() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 97
	reg.update_trust("promise_kept")  # +10 would exceed 100
	if reg.trust_points != 100:
		return _fail("trust_points should not exceed 100, got: " + str(reg.trust_points))
	return true


func test_tier_becomes_cautious_at_threshold_25() -> bool:
	var reg: RelationshipRegistry = _make()
	# 9 * followed_hint (+3) = 27 points, crosses threshold 25
	for _i in range(9):
		reg.update_trust("followed_hint")
	if reg.trust_tier != RelationshipRegistry.TrustTier.CAUTIOUS:
		return _fail("Expected CAUTIOUS at >= 25 points, got tier: " + str(reg.trust_tier))
	return true


func test_tier_becomes_attentive_at_threshold_50() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 48
	reg.update_trust("promise_kept")  # +10 -> 58
	if reg.trust_tier != RelationshipRegistry.TrustTier.ATTENTIVE:
		return _fail("Expected ATTENTIVE at >= 50 points, got tier: " + str(reg.trust_tier))
	return true


func test_tier_becomes_bound_at_threshold_75() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 74
	reg.update_trust("followed_hint")  # +3 -> 77
	if reg.trust_tier != RelationshipRegistry.TrustTier.BOUND:
		return _fail("Expected BOUND at >= 75 points, got tier: " + str(reg.trust_tier))
	return true


func test_tier_stays_distant_below_25() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 22
	reg.trust_tier = RelationshipRegistry.TrustTier.DISTANT
	reg.update_trust("quick_death")  # -2 -> 20, still < 25
	if reg.trust_tier != RelationshipRegistry.TrustTier.DISTANT:
		return _fail("20 points should still be DISTANT (threshold is 25), got tier: " + str(reg.trust_tier))
	if reg.trust_points != 20:
		return _fail("Expected 20 trust_points, got: " + str(reg.trust_points))
	return true


func test_negative_events_reduce_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 30
	reg.update_trust("abandoned_run")         # -5
	reg.update_trust("rushed_many_decisions") # -3
	reg.update_trust("skipped_dialogue")      # -1
	# 30 - 5 - 3 - 1 = 21
	if reg.trust_points != 21:
		return _fail("Expected 21 after three negative events, got: " + str(reg.trust_points))
	return true


func test_positive_events_accumulate_correctly() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.update_trust("long_run_100")    # +5
	reg.update_trust("survived_crisis") # +2
	reg.update_trust("completed_arc")   # +5
	# 0 + 5 + 2 + 5 = 12
	if reg.trust_points != 12:
		return _fail("Expected 12 after three positive events, got: " + str(reg.trust_points))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. RAPPORT SHIFTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_promise_kept_shifts_respect_up() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["respect"]
	reg.update_trust("promise_kept")
	if reg.rapport["respect"] <= before:
		return _fail("promise_kept should increase respect")
	return true


func test_promise_broken_shifts_warmth_down() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["warmth"]
	reg.trust_points = 20
	reg.update_trust("promise_broken")
	if reg.rapport["warmth"] >= before:
		return _fail("promise_broken should decrease warmth, before=%s after=%s" % [before, reg.rapport["warmth"]])
	return true


func test_rapport_values_clamped_at_1_0() -> bool:
	var reg: RelationshipRegistry = _make()
	for _i in range(20):
		reg.update_trust("promise_kept")
	if reg.rapport["respect"] > 1.0:
		return _fail("rapport respect exceeded 1.0: " + str(reg.rapport["respect"]))
	return true


func test_rapport_values_clamped_at_0_0() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 100
	for _i in range(20):
		reg.update_trust("promise_broken")
	if reg.rapport["warmth"] < 0.0:
		return _fail("rapport warmth went below 0.0: " + str(reg.rapport["warmth"]))
	return true


func test_thanked_merlin_shifts_warmth_and_complicity() -> bool:
	var reg: RelationshipRegistry = _make()
	var w_before: float = reg.rapport["warmth"]
	var c_before: float = reg.rapport["complicity"]
	reg.update_trust("thanked_merlin")
	if reg.rapport["warmth"] <= w_before:
		return _fail("thanked_merlin should increase warmth")
	if reg.rapport["complicity"] <= c_before:
		return _fail("thanked_merlin should increase complicity")
	return true


func test_followed_hint_shifts_reverence_and_familiarity() -> bool:
	var reg: RelationshipRegistry = _make()
	var rev_before: float = reg.rapport["reverence"]
	var fam_before: float = reg.rapport["familiarity"]
	reg.update_trust("followed_hint")
	if reg.rapport["reverence"] <= rev_before:
		return _fail("followed_hint should increase reverence")
	if reg.rapport["familiarity"] <= fam_before:
		return _fail("followed_hint should increase familiarity")
	return true


func test_ignored_warning_survived_shifts_respect() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["respect"]
	reg.update_trust("ignored_warning_survived")
	if reg.rapport["respect"] <= before:
		return _fail("ignored_warning_survived should increase respect (autonomy)")
	return true


func test_ignored_warning_died_shifts_warmth_up() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["warmth"]
	reg.trust_points = 10  # Avoid floor clamping confusion
	reg.update_trust("ignored_warning_died")
	if reg.rapport["warmth"] <= before:
		return _fail("ignored_warning_died should increase warmth (Merlin cares), before=%s after=%s" % [before, reg.rapport["warmth"]])
	return true


func test_long_run_100_shifts_familiarity_and_complicity() -> bool:
	var reg: RelationshipRegistry = _make()
	var fam_before: float = reg.rapport["familiarity"]
	var com_before: float = reg.rapport["complicity"]
	reg.update_trust("long_run_100")
	if reg.rapport["familiarity"] <= fam_before:
		return _fail("long_run_100 should increase familiarity")
	if reg.rapport["complicity"] <= com_before:
		return _fail("long_run_100 should increase complicity")
	return true


func test_long_run_150_shifts_familiarity_and_complicity() -> bool:
	var reg: RelationshipRegistry = _make()
	var fam_before: float = reg.rapport["familiarity"]
	var com_before: float = reg.rapport["complicity"]
	reg.update_trust("long_run_150")
	if reg.rapport["familiarity"] <= fam_before:
		return _fail("long_run_150 should increase familiarity")
	if reg.rapport["complicity"] <= com_before:
		return _fail("long_run_150 should increase complicity")
	return true


func test_asked_good_question_shifts_familiarity() -> bool:
	var reg: RelationshipRegistry = _make()
	var before: float = reg.rapport["familiarity"]
	reg.update_trust("asked_good_question")
	if reg.rapport["familiarity"] <= before:
		return _fail("asked_good_question should increase familiarity")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. INTERACTION RECORDING
# ═══════════════════════════════════════════════════════════════════════════════

func test_record_interaction_increments_counter() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("promises_proposed")
	reg.record_interaction("promises_proposed")
	if reg.interactions["promises_proposed"] != 2:
		return _fail("promises_proposed should be 2, got: " + str(reg.interactions["promises_proposed"]))
	return true


func test_record_interaction_unknown_key_is_ignored() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("completely_unknown_interaction")
	if reg.interactions.has("completely_unknown_interaction"):
		return _fail("Unknown interaction key should not be added to dict")
	return true


func test_record_interaction_promises_kept_triggers_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("promises_kept")
	# record_interaction("promises_kept") calls update_trust("promise_kept") -> +10
	if reg.trust_points != 10:
		return _fail("promises_kept interaction should trigger +10 trust, got: " + str(reg.trust_points))
	return true


func test_record_interaction_promises_broken_triggers_negative_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 20
	reg.record_interaction("promises_broken")
	# calls update_trust("promise_broken") -> -15 -> 5
	if reg.trust_points != 5:
		return _fail("promises_broken interaction should trigger -15 trust, got: " + str(reg.trust_points))
	return true


func test_record_interaction_hints_followed_triggers_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("hints_followed")
	# calls update_trust("followed_hint") -> +3
	if reg.trust_points != 3:
		return _fail("hints_followed interaction should trigger +3 trust, got: " + str(reg.trust_points))
	return true


func test_record_interaction_thank_yous_triggers_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("thank_yous")
	# calls update_trust("thanked_merlin") -> +4
	if reg.trust_points != 4:
		return _fail("thank_yous interaction should trigger +4 trust, got: " + str(reg.trust_points))
	return true


func test_record_interaction_defiances_increments_counter() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("defiances")
	if reg.interactions["defiances"] != 1:
		return _fail("defiances counter should be 1, got: " + str(reg.interactions["defiances"]))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. SPECIAL MOMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_trigger_special_moment_returns_true_first_time() -> bool:
	var reg: RelationshipRegistry = _make()
	var result: bool = reg.trigger_special_moment("has_seen_melancholy")
	if not result:
		return _fail("First trigger of has_seen_melancholy should return true")
	return true


func test_trigger_special_moment_returns_false_second_time() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trigger_special_moment("has_seen_melancholy")
	var result: bool = reg.trigger_special_moment("has_seen_melancholy")
	if result:
		return _fail("Second trigger of already-triggered moment should return false")
	return true


func test_trigger_special_moment_unknown_key_returns_false() -> bool:
	var reg: RelationshipRegistry = _make()
	var result: bool = reg.trigger_special_moment("nonexistent_moment_xyz")
	if result:
		return _fail("Triggering unknown moment should return false")
	return true


func test_trigger_special_moment_grants_bonus_trust() -> bool:
	var reg: RelationshipRegistry = _make()
	var points_before: int = reg.trust_points
	reg.trigger_special_moment("witnessed_prophecy")
	# Should have called update_trust("discovered_lore") -> +2
	if reg.trust_points != points_before + 2:
		return _fail("Triggering special moment should grant +2 trust, got delta: " + str(reg.trust_points - points_before))
	return true


func test_trigger_special_moment_sets_flag() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trigger_special_moment("shared_silence")
	if not reg.special_moments["shared_silence"]:
		return _fail("shared_silence flag should be true after trigger")
	return true


func test_check_special_moment_thanked_at_3_triggers() -> bool:
	var reg: RelationshipRegistry = _make()
	# Need 3 thank_yous interactions to trigger thanked_merlin_sincerely
	reg.record_interaction("thank_yous")
	reg.record_interaction("thank_yous")
	if reg.special_moments["thanked_merlin_sincerely"]:
		return _fail("Should not trigger after only 2 thank_yous")
	reg.record_interaction("thank_yous")
	if not reg.special_moments["thanked_merlin_sincerely"]:
		return _fail("Should trigger thanked_merlin_sincerely after 3 thank_yous")
	return true


func test_check_special_moment_defied_merlin_triggers_at_2() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.record_interaction("defiances")
	if reg.special_moments["defied_merlin"]:
		return _fail("Should not trigger defied_merlin after only 1 defiance")
	reg.record_interaction("defiances")
	if not reg.special_moments["defied_merlin"]:
		return _fail("Should trigger defied_merlin after 2 defiances")
	return true


func test_trigger_all_nine_special_moments() -> bool:
	var reg: RelationshipRegistry = _make()
	var moments: Array[String] = [
		"has_seen_melancholy", "has_seen_slip", "questioned_merlin_nature",
		"thanked_merlin_sincerely", "defied_merlin", "shared_silence",
		"witnessed_prophecy", "saved_by_merlin", "1000_runs_revelation",
	]
	for m in moments:
		var result: bool = reg.trigger_special_moment(m)
		if not result:
			return _fail("Expected trigger to return true for moment: " + m)
	for m in moments:
		if not reg.special_moments[m]:
			return _fail("Expected special_moment flag to be true: " + m)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. CAN-SHOW PREDICATES
# ═══════════════════════════════════════════════════════════════════════════════

func test_can_show_melancholy_false_when_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.can_show_melancholy():
		return _fail("DISTANT tier without flag should not be able to show melancholy")
	return true


func test_can_show_melancholy_true_when_bound() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	if not reg.can_show_melancholy():
		return _fail("BOUND tier should be able to show melancholy")
	return true


func test_can_show_melancholy_true_with_flag_even_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.special_moments["has_seen_melancholy"] = true
	if not reg.can_show_melancholy():
		return _fail("Flag has_seen_melancholy should allow showing melancholy even at DISTANT")
	return true


func test_can_show_slip_false_when_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.can_show_slip():
		return _fail("DISTANT should not be able to show slip")
	return true


func test_can_show_slip_false_at_cautious() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	if reg.can_show_slip():
		return _fail("CAUTIOUS should not be able to show slip (threshold is ATTENTIVE)")
	return true


func test_can_show_slip_true_at_attentive() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	if not reg.can_show_slip():
		return _fail("ATTENTIVE should be able to show slip")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. TONE MODIFIERS & VOICE PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

func test_tone_modifiers_keys_present() -> bool:
	var reg: RelationshipRegistry = _make()
	var mods: Dictionary = reg.get_tone_modifiers()
	for key in ["humor", "darkness", "warmth", "verbosity"]:
		if not mods.has(key):
			return _fail("get_tone_modifiers missing key: " + key)
	return true


func test_tone_warmth_higher_at_bound_than_distant() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var warmth_distant: float = reg_d.get_tone_modifiers()["warmth"]
	var warmth_bound: float = reg_b.get_tone_modifiers()["warmth"]
	if warmth_bound <= warmth_distant:
		return _fail("BOUND warmth should exceed DISTANT warmth, got bound=%s distant=%s" % [warmth_bound, warmth_distant])
	return true


func test_tone_darkness_increases_with_tier() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var dark_d: float = reg_d.get_tone_modifiers()["darkness"]
	var dark_b: float = reg_b.get_tone_modifiers()["darkness"]
	if dark_b <= dark_d:
		return _fail("BOUND darkness should exceed DISTANT, got bound=%s distant=%s" % [dark_b, dark_d])
	return true


func test_taunt_reduced_by_high_warmth() -> bool:
	var reg_low: RelationshipRegistry = _make()
	var reg_high: RelationshipRegistry = _make()
	reg_low.trust_tier = RelationshipRegistry.TrustTier.BOUND
	reg_high.trust_tier = RelationshipRegistry.TrustTier.BOUND
	reg_high.rapport["warmth"] = 1.0
	var taunt_low: float = reg_low.get_taunt_intensity()
	var taunt_high: float = reg_high.get_taunt_intensity()
	if taunt_high >= taunt_low:
		return _fail("High warmth should reduce taunt intensity, got low=%s high=%s" % [taunt_low, taunt_high])
	return true


func test_sentence_length_modifier_increases_with_tier() -> bool:
	var reg: RelationshipRegistry = _make()
	var distant_mod: float = reg.get_sentence_length_modifier()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var bound_mod: float = reg.get_sentence_length_modifier()
	if bound_mod <= distant_mod:
		return _fail("BOUND sentence modifier should exceed DISTANT, got bound=%s distant=%s" % [bound_mod, distant_mod])
	return true


func test_should_use_player_name_false_at_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	if reg.should_use_player_name():
		return _fail("DISTANT should not use player name")
	return true


func test_should_use_player_name_true_at_cautious() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	if not reg.should_use_player_name():
		return _fail("CAUTIOUS should use player name")
	return true


func test_taunt_intensity_higher_at_bound_than_distant() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	var taunt_d: float = reg_d.get_taunt_intensity()
	var taunt_b: float = reg_b.get_taunt_intensity()
	if taunt_b <= taunt_d:
		return _fail("BOUND taunt intensity should exceed DISTANT, got bound=%s distant=%s" % [taunt_b, taunt_d])
	return true


func test_can_reveal_lore_depth_1_always() -> bool:
	var reg: RelationshipRegistry = _make()
	if not reg.can_reveal_lore_depth(1):
		return _fail("DISTANT should always allow lore depth 1")
	return true


func test_can_reveal_lore_depth_2_requires_cautious() -> bool:
	var reg_d: RelationshipRegistry = _make()
	var reg_c: RelationshipRegistry = _make()
	reg_c.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	if reg_d.can_reveal_lore_depth(2):
		return _fail("DISTANT should NOT allow lore depth 2")
	if not reg_c.can_reveal_lore_depth(2):
		return _fail("CAUTIOUS should allow lore depth 2")
	return true


func test_can_reveal_lore_depth_3_requires_attentive() -> bool:
	var reg_c: RelationshipRegistry = _make()
	var reg_a: RelationshipRegistry = _make()
	reg_c.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	reg_a.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	if reg_c.can_reveal_lore_depth(3):
		return _fail("CAUTIOUS should NOT allow lore depth 3")
	if not reg_a.can_reveal_lore_depth(3):
		return _fail("ATTENTIVE should allow lore depth 3")
	return true


func test_can_reveal_lore_depth_4_requires_bound() -> bool:
	var reg_a: RelationshipRegistry = _make()
	var reg_b: RelationshipRegistry = _make()
	reg_a.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	reg_b.trust_tier = RelationshipRegistry.TrustTier.BOUND
	if reg_a.can_reveal_lore_depth(4):
		return _fail("ATTENTIVE should NOT allow lore depth 4")
	if not reg_b.can_reveal_lore_depth(4):
		return _fail("BOUND should allow lore depth 4")
	return true


func test_can_reveal_lore_depth_5_impossible_even_bound() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	if reg.can_reveal_lore_depth(5):
		return _fail("BOUND should NOT allow lore depth 5 (max is 4)")
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
			return _fail("get_context_for_llm missing key: " + key)
	return true


func test_get_context_can_show_darkness_false_at_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	var ctx: Dictionary = reg.get_context_for_llm()
	if ctx["can_show_darkness"]:
		return _fail("DISTANT should have can_show_darkness = false")
	return true


func test_get_context_can_show_darkness_true_at_cautious() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.CAUTIOUS
	var ctx: Dictionary = reg.get_context_for_llm()
	if not ctx["can_show_darkness"]:
		return _fail("CAUTIOUS should have can_show_darkness = true")
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
			return _fail("Tier %d should be named '%s', got '%s'" % [tiers[i], names[i], name])
	return true


func test_get_summary_for_prompt_contains_tier_name() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	reg.trust_points = 55
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("Attentif"):
		return _fail("Summary should contain tier name 'Attentif', got: " + summary)
	if not summary.contains("55"):
		return _fail("Summary should contain trust_points 55, got: " + summary)
	return true


func test_get_summary_attentive_mentions_depth() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.ATTENTIVE
	reg.trust_points = 60
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("profondeur"):
		return _fail("ATTENTIVE summary should mention 'profondeur', got: " + summary)
	return true


func test_get_summary_bound_mentions_vulnerabilite() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	reg.trust_points = 80
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("vulnerabilite"):
		return _fail("BOUND summary should mention 'vulnerabilite', got: " + summary)
	return true


func test_get_summary_high_warmth_mentions_chaleureux() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.rapport["warmth"] = 0.8
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("chaleureux"):
		return _fail("High warmth summary should mention 'chaleureux', got: " + summary)
	return true


func test_get_summary_high_complicity_mentions_complicite() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.rapport["complicity"] = 0.7
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("Complicit"):
		return _fail("High complicity summary should mention 'Complicit', got: " + summary)
	return true


func test_get_summary_has_seen_melancholy_flag_in_summary() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.special_moments["has_seen_melancholy"] = true
	var summary: String = reg.get_summary_for_prompt()
	if not summary.contains("melancolie"):
		return _fail("Summary should mention melancolie when flag is set, got: " + summary)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. RESET
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_zeroes_trust_points() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 80
	reg.reset()
	if reg.trust_points != 0:
		return _fail("reset() should zero trust_points, got: " + str(reg.trust_points))
	return true


func test_reset_sets_tier_to_distant() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_tier = RelationshipRegistry.TrustTier.BOUND
	reg.reset()
	if reg.trust_tier != RelationshipRegistry.TrustTier.DISTANT:
		return _fail("reset() should restore tier to DISTANT, got: " + str(reg.trust_tier))
	return true


func test_reset_restores_default_rapport() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.rapport["warmth"] = 0.99
	reg.rapport["respect"] = 0.01
	reg.reset()
	if not _approx_eq(reg.rapport["warmth"], 0.2):
		return _fail("reset() should restore warmth to 0.2, got: " + str(reg.rapport["warmth"]))
	if not _approx_eq(reg.rapport["respect"], 0.3):
		return _fail("reset() should restore respect to 0.3, got: " + str(reg.rapport["respect"]))
	return true


func test_reset_zeroes_interactions() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.interactions["defiances"] = 99
	reg.interactions["promises_kept"] = 12
	reg.reset()
	if reg.interactions["defiances"] != 0:
		return _fail("reset() should zero defiances, got: " + str(reg.interactions["defiances"]))
	if reg.interactions["promises_kept"] != 0:
		return _fail("reset() should zero promises_kept, got: " + str(reg.interactions["promises_kept"]))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. ABSENCE DECAY (pure math — no file I/O)
# ═══════════════════════════════════════════════════════════════════════════════

func test_absence_decay_reduces_trust_points() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 30
	# Simulate 5 days of absence by manipulating last_session_date directly
	var five_days_ago: int = int(Time.get_unix_time_from_system()) - (5 * 86400)
	reg.last_session_date = five_days_ago
	reg._apply_absence_decay()
	# 30 - (5 * 1) = 25
	if reg.trust_points != 25:
		return _fail("5 days absence should decay 5 points, expected 25, got: " + str(reg.trust_points))
	return true


func test_absence_decay_capped_at_max_decay_days() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 50
	# Simulate 60 days (beyond MAX_DECAY_DAYS=30) of absence
	var sixty_days_ago: int = int(Time.get_unix_time_from_system()) - (60 * 86400)
	reg.last_session_date = sixty_days_ago
	reg._apply_absence_decay()
	# Max decay = 30 * 1 = 30, so 50 - 30 = 20
	if reg.trust_points != 20:
		return _fail("60 days absence should only decay MAX_DECAY_DAYS=30 points, expected 20, got: " + str(reg.trust_points))
	return true


func test_absence_decay_does_not_go_below_zero() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 5
	var forty_days_ago: int = int(Time.get_unix_time_from_system()) - (40 * 86400)
	reg.last_session_date = forty_days_ago
	reg._apply_absence_decay()
	if reg.trust_points < 0:
		return _fail("Decay should not bring trust_points below 0, got: " + str(reg.trust_points))
	return true


func test_absence_decay_no_decay_same_day() -> bool:
	var reg: RelationshipRegistry = _make()
	reg.trust_points = 40
	# Set last_session_date to today (less than 1 day ago)
	var now: int = int(Time.get_unix_time_from_system())
	reg.last_session_date = now - 3600  # 1 hour ago
	reg._apply_absence_decay()
	if reg.trust_points != 40:
		return _fail("No decay should occur when less than 1 day has passed, got: " + str(reg.trust_points))
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
		"test_init_interaction_counters_all_zero",
		"test_init_special_moments_all_false",
		"test_update_trust_unknown_event_is_noop",
		"test_update_trust_promise_kept_adds_10",
		"test_update_trust_promise_broken_subtracts_15",
		"test_update_trust_clamped_at_zero",
		"test_update_trust_clamped_at_100",
		"test_tier_becomes_cautious_at_threshold_25",
		"test_tier_becomes_attentive_at_threshold_50",
		"test_tier_becomes_bound_at_threshold_75",
		"test_tier_stays_distant_below_25",
		"test_negative_events_reduce_trust",
		"test_positive_events_accumulate_correctly",
		"test_promise_kept_shifts_respect_up",
		"test_promise_broken_shifts_warmth_down",
		"test_rapport_values_clamped_at_1_0",
		"test_rapport_values_clamped_at_0_0",
		"test_thanked_merlin_shifts_warmth_and_complicity",
		"test_followed_hint_shifts_reverence_and_familiarity",
		"test_ignored_warning_survived_shifts_respect",
		"test_ignored_warning_died_shifts_warmth_up",
		"test_long_run_100_shifts_familiarity_and_complicity",
		"test_long_run_150_shifts_familiarity_and_complicity",
		"test_asked_good_question_shifts_familiarity",
		"test_record_interaction_increments_counter",
		"test_record_interaction_unknown_key_is_ignored",
		"test_record_interaction_promises_kept_triggers_trust",
		"test_record_interaction_promises_broken_triggers_negative_trust",
		"test_record_interaction_hints_followed_triggers_trust",
		"test_record_interaction_thank_yous_triggers_trust",
		"test_record_interaction_defiances_increments_counter",
		"test_trigger_special_moment_returns_true_first_time",
		"test_trigger_special_moment_returns_false_second_time",
		"test_trigger_special_moment_unknown_key_returns_false",
		"test_trigger_special_moment_grants_bonus_trust",
		"test_trigger_special_moment_sets_flag",
		"test_check_special_moment_thanked_at_3_triggers",
		"test_check_special_moment_defied_merlin_triggers_at_2",
		"test_trigger_all_nine_special_moments",
		"test_can_show_melancholy_false_when_distant",
		"test_can_show_melancholy_true_when_bound",
		"test_can_show_melancholy_true_with_flag_even_distant",
		"test_can_show_slip_false_when_distant",
		"test_can_show_slip_false_at_cautious",
		"test_can_show_slip_true_at_attentive",
		"test_tone_modifiers_keys_present",
		"test_tone_warmth_higher_at_bound_than_distant",
		"test_tone_darkness_increases_with_tier",
		"test_taunt_reduced_by_high_warmth",
		"test_sentence_length_modifier_increases_with_tier",
		"test_should_use_player_name_false_at_distant",
		"test_should_use_player_name_true_at_cautious",
		"test_taunt_intensity_higher_at_bound_than_distant",
		"test_can_reveal_lore_depth_1_always",
		"test_can_reveal_lore_depth_2_requires_cautious",
		"test_can_reveal_lore_depth_3_requires_attentive",
		"test_can_reveal_lore_depth_4_requires_bound",
		"test_can_reveal_lore_depth_5_impossible_even_bound",
		"test_get_context_for_llm_has_required_keys",
		"test_get_context_can_show_darkness_false_at_distant",
		"test_get_context_can_show_darkness_true_at_cautious",
		"test_get_trust_tier_name_all_tiers",
		"test_get_summary_for_prompt_contains_tier_name",
		"test_get_summary_attentive_mentions_depth",
		"test_get_summary_bound_mentions_vulnerabilite",
		"test_get_summary_high_warmth_mentions_chaleureux",
		"test_get_summary_high_complicity_mentions_complicite",
		"test_get_summary_has_seen_melancholy_flag_in_summary",
		"test_reset_zeroes_trust_points",
		"test_reset_sets_tier_to_distant",
		"test_reset_restores_default_rapport",
		"test_reset_zeroes_interactions",
		"test_absence_decay_reduces_trust_points",
		"test_absence_decay_capped_at_max_decay_days",
		"test_absence_decay_does_not_go_below_zero",
		"test_absence_decay_no_decay_same_day",
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
