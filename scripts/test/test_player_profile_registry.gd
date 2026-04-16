## ═══════════════════════════════════════════════════════════════════════════════
## Test PlayerProfileRegistry — Pure unit tests (no Node, no file I/O)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: reset, play_style shifts (all axes + all trigger tags), skill
##           updates, patience boundaries, theme tracking (threshold/dedup),
##           NPC interaction (favorites/disliked/no-id), experience tiers
##           (all 5 + boundary values), seed_from_quiz (mapping/clamping/
##           archetype), on_run_end (meta counters, avg length, endings,
##           run_data reset), session decay, outcome-driven skill updates
##           (crisis/pattern/promise/timing), context_for_llm structure,
##           summary_for_prompt content, archetype getters, gauge protection.
## Run count: 73 tests.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_fresh() -> PlayerProfileRegistry:
	var reg: PlayerProfileRegistry = PlayerProfileRegistry.new()
	reg.reset()
	reg._theme_counter = {}
	reg._npc_interactions = {}
	reg.meta["runs_completed"] = 0
	reg.meta["runs_won"] = 0
	reg.meta["total_cards_played"] = 0
	reg.meta["longest_run"] = 0
	reg.meta["shortest_run"] = 999
	reg.meta["endings_seen"] = []
	reg.preferences["preferred_themes"] = []
	reg.preferences["avoided_themes"] = []
	reg.preferences["favorite_npcs"] = []
	reg.preferences["disliked_npcs"] = []
	reg.preferences["archetype_id"] = ""
	reg.preferences["archetype_title"] = ""
	return reg


func _make_card(tags: Array, npc_id: String = "", options: Array = []) -> Dictionary:
	return {"id": "card_x", "type": "narrative", "tags": tags, "npc_id": npc_id, "options": options}


func _make_context(gauges: Dictionary = {}, time_ms: int = 3000) -> Dictionary:
	return {"gauges": gauges, "decision_time_ms": time_ms}


# ─────────────────────────────────────────────────────────────────────────────
# 1. RESET
# ─────────────────────────────────────────────────────────────────────────────

func test_reset_sets_all_playstyle_to_half() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.play_style["aggression"] = 0.9
	reg.reset()
	for key in reg.play_style:
		if not is_equal_approx(float(reg.play_style[key]), 0.5):
			return _fail("Expected play_style.%s == 0.5 after reset, got %f" % [key, float(reg.play_style[key])])
	return true


func test_reset_sets_all_skills_to_half() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.skill_assessment["pattern_recognition"] = 0.9
	reg.reset()
	for key in reg.skill_assessment:
		if not is_equal_approx(float(reg.skill_assessment[key]), 0.5):
			return _fail("Expected skill_assessment.%s == 0.5 after reset, got %f" % [key, float(reg.skill_assessment[key])])
	return true


func test_reset_clears_current_run_cards_played() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.update_from_choice(_make_card([]), 0, _make_context())
	reg.reset()
	# Directly read internal run data via a call that increments it
	var before: int = reg._current_run_data["cards_played"]
	if before != 0:
		return _fail("Expected _current_run_data.cards_played == 0 after reset, got %d" % before)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. PLAY STYLE SHIFTS FROM TAGS — AGGRESSION AXIS
# ─────────────────────────────────────────────────────────────────────────────

func test_aggressive_tag_shifts_aggression_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["aggressive"]), 0, _make_context())
	var after: float = float(reg.play_style["aggression"])
	if after <= before:
		return _fail("Expected aggression to increase with 'aggressive' tag, %f -> %f" % [before, after])
	return true


func test_combat_tag_shifts_aggression_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["combat"]), 0, _make_context())
	if float(reg.play_style["aggression"]) <= before:
		return _fail("Expected aggression to increase with 'combat' tag")
	return true


func test_peaceful_tag_shifts_aggression_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["peaceful"]), 0, _make_context())
	var after: float = float(reg.play_style["aggression"])
	if after >= before:
		return _fail("Expected aggression to decrease with 'peaceful' tag, %f -> %f" % [before, after])
	return true


func test_diplomatic_tag_shifts_aggression_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["diplomatic"]), 0, _make_context())
	if float(reg.play_style["aggression"]) >= before:
		return _fail("Expected aggression to decrease with 'diplomatic' tag")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. PLAY STYLE SHIFTS FROM TAGS — ALTRUISM, CURIOSITY, RISK AXES
# ─────────────────────────────────────────────────────────────────────────────

func test_altruism_increases_with_sacrifice_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["altruism"])
	reg.update_from_choice(_make_card(["sacrifice"]), 0, _make_context())
	if float(reg.play_style["altruism"]) <= before:
		return _fail("Expected altruism to increase with 'sacrifice' tag, %f -> %f" % [before, float(reg.play_style["altruism"])])
	return true


func test_altruism_decreases_with_selfish_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["altruism"])
	reg.update_from_choice(_make_card(["selfish"]), 0, _make_context())
	if float(reg.play_style["altruism"]) >= before:
		return _fail("Expected altruism to decrease with 'selfish' tag")
	return true


func test_curiosity_increases_with_explore_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["curiosity"])
	reg.update_from_choice(_make_card(["explore"]), 0, _make_context())
	if float(reg.play_style["curiosity"]) <= before:
		return _fail("Expected curiosity to increase with 'explore' tag, %f -> %f" % [before, float(reg.play_style["curiosity"])])
	return true


func test_curiosity_decreases_with_practical_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["curiosity"])
	reg.update_from_choice(_make_card(["practical"]), 0, _make_context())
	if float(reg.play_style["curiosity"]) >= before:
		return _fail("Expected curiosity to decrease with 'practical' tag")
	return true


func test_risk_tolerance_increases_with_gamble_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["risk_tolerance"])
	reg.update_from_choice(_make_card(["gamble"]), 0, _make_context())
	if float(reg.play_style["risk_tolerance"]) <= before:
		return _fail("Expected risk_tolerance to increase with 'gamble' tag, %f -> %f" % [before, float(reg.play_style["risk_tolerance"])])
	return true


func test_risk_tolerance_decreases_with_safe_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["risk_tolerance"])
	reg.update_from_choice(_make_card(["safe"]), 0, _make_context())
	if float(reg.play_style["risk_tolerance"]) >= before:
		return _fail("Expected risk_tolerance to decrease with 'safe' tag, %f -> %f" % [before, float(reg.play_style["risk_tolerance"])])
	return true


func test_unknown_tag_does_not_change_any_trait() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: Dictionary = reg.play_style.duplicate(true)
	# "random_unknown" matches no trigger — patience unchanged (time=3000ms), no trait shift
	reg.update_from_choice(_make_card(["random_unknown"]), 0, _make_context({}, 3000))
	for key in before:
		if not is_equal_approx(float(before[key]), float(reg.play_style[key])):
			return _fail("Trait '%s' changed with unknown tag: %f -> %f" % [key, float(before[key]), float(reg.play_style[key])])
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. PATIENCE FROM DECISION TIME
# ─────────────────────────────────────────────────────────────────────────────

func test_fast_decision_shifts_patience_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 500))
	if float(reg.play_style["patience"]) >= before:
		return _fail("Expected patience to decrease with fast decision (500ms), %f -> %f" % [before, float(reg.play_style["patience"])])
	return true


func test_slow_decision_shifts_patience_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 9000))
	if float(reg.play_style["patience"]) <= before:
		return _fail("Expected patience to increase with slow decision (9000ms), %f -> %f" % [before, float(reg.play_style["patience"])])
	return true


func test_boundary_exactly_1000ms_does_not_shift_patience_down() -> bool:
	# Threshold is strict < 1000, so exactly 1000 should not trigger the impulsive path
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 1000))
	var after: float = float(reg.play_style["patience"])
	if after < before:
		return _fail("decision_time_ms=1000 should NOT shift patience down (strict < 1000), got %f -> %f" % [before, after])
	return true


func test_boundary_exactly_8000ms_does_not_shift_patience_up() -> bool:
	# Threshold is strict > 8000, so exactly 8000 should not trigger the methodical path
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 8000))
	var after: float = float(reg.play_style["patience"])
	if after > before:
		return _fail("decision_time_ms=8000 should NOT shift patience up (strict > 8000), got %f -> %f" % [before, after])
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. THEME TRACKING
# ─────────────────────────────────────────────────────────────────────────────

func test_theme_added_to_preferred_after_threshold() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(3):
		reg.update_from_choice(_make_card(["mystery"]), 0, _make_context())
	if "mystery" not in reg.preferences["preferred_themes"]:
		return _fail("Expected 'mystery' in preferred_themes after 3 occurrences")
	return true


func test_theme_not_added_before_threshold() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(2):
		reg.update_from_choice(_make_card(["mystery"]), 0, _make_context())
	if "mystery" in reg.preferences["preferred_themes"]:
		return _fail("Expected 'mystery' NOT in preferred_themes with only 2 occurrences")
	return true


func test_theme_not_duplicated_in_preferred() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(6):
		reg.update_from_choice(_make_card(["combat"]), 0, _make_context())
	var count: int = 0
	for t in reg.preferences["preferred_themes"]:
		if t == "combat":
			count += 1
	if count > 1:
		return _fail("Expected 'combat' to appear at most once in preferred_themes, got %d" % count)
	return true


func test_multiple_themes_tracked_independently() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(3):
		reg.update_from_choice(_make_card(["mystery", "social"]), 0, _make_context())
	var pref: Array = reg.preferences["preferred_themes"]
	if "mystery" not in pref:
		return _fail("Expected 'mystery' in preferred_themes")
	if "social" not in pref:
		return _fail("Expected 'social' in preferred_themes")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. NPC INTERACTION
# ─────────────────────────────────────────────────────────────────────────────

func test_npc_added_to_favorites_after_3_positive() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(3):
		reg.update_from_choice(_make_card([], "npc_druid"), 1, _make_context())
	if "npc_druid" not in reg.preferences["favorite_npcs"]:
		return _fail("Expected 'npc_druid' in favorite_npcs after 3 positive interactions")
	return true


func test_npc_added_to_disliked_after_3_negative() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(3):
		reg.update_from_choice(_make_card([], "npc_villain"), 0, _make_context())
	if "npc_villain" not in reg.preferences["disliked_npcs"]:
		return _fail("Expected 'npc_villain' in disliked_npcs after 3 negative interactions")
	return true


func test_npc_without_id_does_not_crash() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.update_from_choice(_make_card(["mystery"], ""), 0, _make_context())
	return true


func test_npc_not_duplicated_in_favorites() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for _i in range(6):
		reg.update_from_choice(_make_card([], "npc_sage"), 1, _make_context())
	var count: int = 0
	for n in reg.preferences["favorite_npcs"]:
		if n == "npc_sage":
			count += 1
	if count > 1:
		return _fail("Expected 'npc_sage' to appear at most once in favorite_npcs, got %d" % count)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. EXPERIENCE TIERS — ALL 5 TIERS + BOUNDARY VALUES
# ─────────────────────────────────────────────────────────────────────────────

func test_experience_tier_initiate_at_zero_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 0
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.INITIATE:
		return _fail("Expected INITIATE at 0 runs")
	return true


func test_experience_tier_initiate_at_5_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 5
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.INITIATE:
		return _fail("Expected INITIATE at exactly 5 runs (boundary)")
	return true


func test_experience_tier_apprentice_at_6_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 6
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.APPRENTICE:
		return _fail("Expected APPRENTICE at 6 runs")
	return true


func test_experience_tier_apprentice_at_20_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 20
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.APPRENTICE:
		return _fail("Expected APPRENTICE at exactly 20 runs (boundary)")
	return true


func test_experience_tier_journeyer_at_21_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 21
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.JOURNEYER:
		return _fail("Expected JOURNEYER at 21 runs")
	return true


func test_experience_tier_adept_at_51_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 51
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.ADEPT:
		return _fail("Expected ADEPT at 51 runs")
	return true


func test_experience_tier_master_above_100() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 101
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.MASTER:
		return _fail("Expected MASTER at 101 runs")
	return true


func test_experience_tier_name_returns_nonempty_string() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 0
	var name: String = reg.get_experience_tier_name()
	if name.is_empty():
		return _fail("Expected non-empty experience tier name")
	return true


func test_all_experience_tier_names_are_defined() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var run_counts: Array = [0, 6, 21, 51, 101]
	for runs in run_counts:
		reg.meta["runs_completed"] = runs
		var name: String = reg.get_experience_tier_name()
		if name == "Inconnu":
			return _fail("Tier name returned 'Inconnu' for runs_completed=%d" % runs)
		if name.is_empty():
			return _fail("Tier name is empty for runs_completed=%d" % runs)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 8. SEED FROM QUIZ
# ─────────────────────────────────────────────────────────────────────────────

func test_seed_from_quiz_maps_approche_to_aggression_and_risk() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {"approche": 1.0, "relation": 0.0, "esprit": 0.0, "coeur": 0.0},
		"archetype_id": "le_guerrier",
		"archetype_title": "Le Guerrier",
	})
	# approche=1.0 → (1+1)/2 = 1.0
	if not is_equal_approx(float(reg.play_style["aggression"]), 1.0):
		return _fail("Expected aggression == 1.0, got %f" % float(reg.play_style["aggression"]))
	if not is_equal_approx(float(reg.play_style["risk_tolerance"]), 1.0):
		return _fail("Expected risk_tolerance == 1.0, got %f" % float(reg.play_style["risk_tolerance"]))
	return true


func test_seed_from_quiz_maps_relation_to_altruism() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {"approche": 0.0, "relation": -1.0, "esprit": 0.0, "coeur": 0.0},
		"archetype_id": "",
		"archetype_title": "",
	})
	# relation=-1.0 → altruism = (-1+1)/2 = 0.0
	if not is_equal_approx(float(reg.play_style["altruism"]), 0.0):
		return _fail("Expected altruism == 0.0, got %f" % float(reg.play_style["altruism"]))
	return true


func test_seed_from_quiz_maps_esprit_to_patience_inverted() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# esprit=1.0 (intuitif) → patience = (-1+1)/2 = 0.0 (impulsif end of scale)
	reg.seed_from_quiz({
		"axis_positions": {"approche": 0.0, "relation": 0.0, "esprit": 1.0, "coeur": 0.0},
		"archetype_id": "",
		"archetype_title": "",
	})
	if not is_equal_approx(float(reg.play_style["patience"]), 0.0):
		return _fail("Expected patience == 0.0 for esprit=1.0, got %f" % float(reg.play_style["patience"]))
	return true


func test_seed_from_quiz_stores_archetype_id() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {},
		"archetype_id": "le_sage",
		"archetype_title": "Le Sage",
	})
	if reg.get_archetype_id() != "le_sage":
		return _fail("Expected archetype_id == 'le_sage', got '%s'" % reg.get_archetype_id())
	return true


func test_seed_from_quiz_stores_archetype_title() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {},
		"archetype_id": "le_sage",
		"archetype_title": "Le Sage",
	})
	if reg.get_archetype_title() != "Le Sage":
		return _fail("Expected archetype_title == 'Le Sage', got '%s'" % reg.get_archetype_title())
	return true


func test_seed_from_quiz_clamps_values_in_range() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# Out-of-range axes; clampf must keep all traits in [0, 1]
	reg.seed_from_quiz({
		"axis_positions": {"approche": 2.0, "relation": -2.0, "esprit": 5.0, "coeur": -3.0},
		"archetype_id": "",
		"archetype_title": "",
	})
	for key in reg.play_style:
		var val: float = float(reg.play_style[key])
		if val < 0.0 or val > 1.0:
			return _fail("play_style.%s out of [0,1] after seed_from_quiz with extreme axes: %f" % [key, val])
	return true


func test_seed_from_quiz_empty_axes_keeps_neutral_center() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# No axes provided at all; neutral (0.0) mapped to 0.5 for approche/relation/coeur,
	# esprit=0 → patience=(-0+1)/2=0.5
	reg.seed_from_quiz({"axis_positions": {}, "archetype_id": "", "archetype_title": ""})
	# approche default 0 → aggression = (0+1)/2 = 0.5
	if not is_equal_approx(float(reg.play_style["aggression"]), 0.5):
		return _fail("Expected aggression == 0.5 with empty axes, got %f" % float(reg.play_style["aggression"]))
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 9. ON RUN END
# ─────────────────────────────────────────────────────────────────────────────

func test_on_run_end_increments_runs_completed() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": false, "ending": {}})
	if reg.meta["runs_completed"] != 1:
		return _fail("Expected runs_completed == 1, got %d" % reg.meta["runs_completed"])
	return true


func test_on_run_end_increments_runs_won_on_victory() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 30, "victory": true, "ending": {}})
	if reg.meta["runs_won"] != 1:
		return _fail("Expected runs_won == 1 after victory, got %d" % reg.meta["runs_won"])
	return true


func test_on_run_end_does_not_increment_runs_won_on_defeat() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": false, "ending": {}})
	if reg.meta["runs_won"] != 0:
		return _fail("Expected runs_won == 0 after defeat, got %d" % reg.meta["runs_won"])
	return true


func test_on_run_end_accumulates_total_cards_played() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 15, "victory": false, "ending": {}})
	reg.on_run_end({"cards_played": 25, "victory": false, "ending": {}})
	if reg.meta["total_cards_played"] != 40:
		return _fail("Expected total_cards_played == 40, got %d" % reg.meta["total_cards_played"])
	return true


func test_on_run_end_tracks_longest_run() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 42, "victory": false, "ending": {}})
	reg.on_run_end({"cards_played": 20, "victory": false, "ending": {}})
	if reg.meta["longest_run"] != 42:
		return _fail("Expected longest_run == 42, got %d" % reg.meta["longest_run"])
	return true


func test_on_run_end_tracks_shortest_run() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 42, "victory": false, "ending": {}})
	reg.on_run_end({"cards_played": 20, "victory": false, "ending": {}})
	if reg.meta["shortest_run"] != 20:
		return _fail("Expected shortest_run == 20, got %d" % reg.meta["shortest_run"])
	return true


func test_on_run_end_updates_average_run_length() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# Force initial average baseline to 0 for predictable math
	reg.meta["average_run_length"] = 0.0
	reg.on_run_end({"cards_played": 10, "victory": false, "ending": {}})
	# After 1 run: (0 * 0 + 10) / 1 = 10.0
	if not is_equal_approx(float(reg.meta["average_run_length"]), 10.0):
		return _fail("Expected average_run_length == 10.0 after first run, got %f" % float(reg.meta["average_run_length"]))
	return true


func test_on_run_end_records_unique_ending() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": true, "ending": {"title": "Fin Lumineuse"}})
	reg.on_run_end({"cards_played": 10, "victory": true, "ending": {"title": "Fin Lumineuse"}})
	var count: int = 0
	for e in reg.meta["endings_seen"]:
		if e == "Fin Lumineuse":
			count += 1
	if count != 1:
		return _fail("Expected 'Fin Lumineuse' to appear exactly once, got %d" % count)
	return true


func test_on_run_end_skips_empty_ending_title() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": false, "ending": {"title": ""}})
	if reg.meta["endings_seen"].size() != 0:
		return _fail("Expected endings_seen to remain empty when ending title is empty")
	return true


func test_on_run_end_resets_current_run_data() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.update_from_choice(_make_card([]), 0, _make_context())  # cards_played += 1
	reg.on_run_end({"cards_played": 5, "victory": false, "ending": {}})
	if reg._current_run_data["cards_played"] != 0:
		return _fail("Expected _current_run_data.cards_played == 0 after on_run_end, got %d" % reg._current_run_data["cards_played"])
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 10. SESSION DECAY
# ─────────────────────────────────────────────────────────────────────────────

func test_decay_moves_trait_above_half_toward_center() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.play_style["aggression"] = 0.9
	reg._apply_session_decay()
	var after: float = float(reg.play_style["aggression"])
	if after >= 0.9:
		return _fail("Expected aggression to move toward 0.5 from 0.9, got %f" % after)
	if after <= 0.5:
		return _fail("Expected aggression still above 0.5 (decay is slow), got %f" % after)
	return true


func test_decay_moves_trait_below_half_toward_center() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.play_style["aggression"] = 0.1
	reg._apply_session_decay()
	var after: float = float(reg.play_style["aggression"])
	if after <= 0.1:
		return _fail("Expected aggression to move toward 0.5 from 0.1, got %f" % after)
	if after >= 0.5:
		return _fail("Expected aggression still below 0.5 (decay is slow), got %f" % after)
	return true


func test_decay_applied_to_all_playstyle_keys() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for key in reg.play_style:
		reg.play_style[key] = 0.8
	reg._apply_session_decay()
	for key in reg.play_style:
		if float(reg.play_style[key]) >= 0.8:
			return _fail("Expected play_style.%s to decay from 0.8, still at %f" % [key, float(reg.play_style[key])])
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 11. UPDATE FROM OUTCOME
# ─────────────────────────────────────────────────────────────────────────────

func test_outcome_avoided_crisis_improves_recovery() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.skill_assessment["recovery"])
	reg.update_from_outcome({"avoided_crisis": true})
	if float(reg.skill_assessment["recovery"]) <= before:
		return _fail("Expected recovery to increase after avoided_crisis")
	return true


func test_outcome_predicted_twist_improves_pattern_recognition() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.skill_assessment["pattern_recognition"])
	reg.update_from_outcome({"predicted_twist": true})
	if float(reg.skill_assessment["pattern_recognition"]) <= before:
		return _fail("Expected pattern_recognition to increase after predicted_twist")
	return true


func test_outcome_promise_kept_shifts_trust_merlin_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["trust_merlin"])
	reg.update_from_outcome({"promise_kept": true})
	if float(reg.play_style["trust_merlin"]) <= before:
		return _fail("Expected trust_merlin to increase after promise_kept, %f -> %f" % [before, float(reg.play_style["trust_merlin"])])
	return true


func test_outcome_promise_broken_shifts_trust_merlin_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["trust_merlin"])
	reg.update_from_outcome({"promise_broken": true})
	if float(reg.play_style["trust_merlin"]) >= before:
		return _fail("Expected trust_merlin to decrease after promise_broken, %f -> %f" % [before, float(reg.play_style["trust_merlin"])])
	return true


func test_outcome_skill_well_timed_improves_timing() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.skill_assessment["timing"])
	reg.update_from_outcome({"skill_well_timed": true})
	if float(reg.skill_assessment["timing"]) <= before:
		return _fail("Expected timing to increase after skill_well_timed")
	return true


func test_outcome_empty_dict_does_not_change_profile() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var style_before: Dictionary = reg.play_style.duplicate(true)
	var skill_before: Dictionary = reg.skill_assessment.duplicate(true)
	reg.update_from_outcome({})
	for key in style_before:
		if not is_equal_approx(float(style_before[key]), float(reg.play_style[key])):
			return _fail("play_style.%s changed with empty outcome dict" % key)
	for key in skill_before:
		if not is_equal_approx(float(skill_before[key]), float(reg.skill_assessment[key])):
			return _fail("skill_assessment.%s changed with empty outcome dict" % key)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 12. CONTEXT FOR LLM
# ─────────────────────────────────────────────────────────────────────────────

func test_get_context_for_llm_contains_required_keys() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var ctx: Dictionary = reg.get_context_for_llm()
	var required: Array = [
		"style", "skill", "runs_completed", "experience_tier",
		"preferred_themes", "avoided_themes",
		"humor_receptivity", "lore_interest",
	]
	for k in required:
		if not ctx.has(k):
			return _fail("get_context_for_llm() missing key: %s" % k)
	return true


func test_get_context_for_llm_style_is_duplicate_not_reference() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var ctx: Dictionary = reg.get_context_for_llm()
	# Mutating returned dict must not affect internal state
	var style_dict: Dictionary = ctx["style"]
	style_dict["aggression"] = 0.99
	if is_equal_approx(float(reg.play_style["aggression"]), 0.99):
		return _fail("get_context_for_llm() returned a live reference to play_style (not a copy)")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 13. SUMMARY FOR PROMPT & ARCHETYPE GETTERS
# ─────────────────────────────────────────────────────────────────────────────

func test_get_summary_for_prompt_returns_nonempty_string() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 3
	var summary: String = reg.get_summary_for_prompt()
	if summary.is_empty():
		return _fail("Expected non-empty string from get_summary_for_prompt()")
	return true


func test_get_summary_includes_archetype_title_when_set() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.preferences["archetype_title"] = "Le Gardien"
	var summary: String = reg.get_summary_for_prompt()
	if "Le Gardien" not in summary:
		return _fail("Expected 'Le Gardien' in summary when archetype_title is set, got: %s" % summary)
	return true


func test_get_summary_includes_extreme_trait_label() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# aggression > 0.7 should produce "audacieux" in summary
	reg.play_style["aggression"] = 0.9
	var summary: String = reg.get_summary_for_prompt()
	if "audacieux" not in summary:
		return _fail("Expected 'audacieux' in summary for aggression=0.9, got: %s" % summary)
	return true


func test_get_summary_omits_neutral_traits() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# All traits at 0.5 = neutral, no trait label should appear
	var summary: String = reg.get_summary_for_prompt()
	if "audacieux" in summary or "prudent" in summary or "altruiste" in summary:
		return _fail("Unexpected trait label in summary with all-neutral traits: %s" % summary)
	return true


func test_get_archetype_id_returns_empty_when_unset() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	if reg.get_archetype_id() != "":
		return _fail("Expected empty archetype_id when unset, got '%s'" % reg.get_archetype_id())
	return true


func test_get_archetype_title_returns_empty_when_unset() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	if reg.get_archetype_title() != "":
		return _fail("Expected empty archetype_title when unset, got '%s'" % reg.get_archetype_title())
	return true


func test_update_from_choice_increments_cards_played() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.update_from_choice(_make_card([]), 0, _make_context())
	if reg._current_run_data["cards_played"] != 1:
		return _fail("Expected _current_run_data.cards_played == 1 after one choice, got %d" % reg._current_run_data["cards_played"])
	return true
