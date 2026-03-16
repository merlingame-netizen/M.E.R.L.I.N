## ═══════════════════════════════════════════════════════════════════════════════
## Test PlayerProfileRegistry — Pure unit tests (no Node, no file I/O)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: reset, play_style shifts, skill updates, patience, theme tracking,
##           NPC interaction, experience tiers, seed_from_quiz, on_run_end,
##           decay, context for LLM, summary for prompt, archetype getters.
## Run count: 22 tests.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_fresh() -> PlayerProfileRegistry:
	var reg: PlayerProfileRegistry = PlayerProfileRegistry.new()
	reg.reset()
	# Clear internal counters bypassed by reset()
	reg._theme_counter = {}
	reg._npc_interactions = {}
	reg._gauge_protection_count = {}
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
			push_error("Expected play_style.%s == 0.5 after reset, got %f" % [key, float(reg.play_style[key])])
			return false
	return true


func test_reset_sets_all_skills_to_half() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.skill_assessment["gauge_management"] = 0.9
	reg.reset()
	for key in reg.skill_assessment:
		if not is_equal_approx(float(reg.skill_assessment[key]), 0.5):
			push_error("Expected skill_assessment.%s == 0.5 after reset, got %f" % [key, float(reg.skill_assessment[key])])
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. PLAY STYLE SHIFTS FROM TAGS
# ─────────────────────────────────────────────────────────────────────────────

func test_aggressive_tag_shifts_aggression_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["aggressive"]), 0, _make_context())
	var after: float = float(reg.play_style["aggression"])
	if after <= before:
		push_error("Expected aggression to increase with 'aggressive' tag, %f -> %f" % [before, after])
		return false
	return true


func test_peaceful_tag_shifts_aggression_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["aggression"])
	reg.update_from_choice(_make_card(["peaceful"]), 0, _make_context())
	var after: float = float(reg.play_style["aggression"])
	if after >= before:
		push_error("Expected aggression to decrease with 'peaceful' tag, %f -> %f" % [before, after])
		return false
	return true


func test_altruism_increases_with_sacrifice_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["altruism"])
	reg.update_from_choice(_make_card(["sacrifice"]), 0, _make_context())
	var after: float = float(reg.play_style["altruism"])
	if after <= before:
		push_error("Expected altruism to increase with 'sacrifice' tag, %f -> %f" % [before, after])
		return false
	return true


func test_curiosity_increases_with_explore_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["curiosity"])
	reg.update_from_choice(_make_card(["explore"]), 0, _make_context())
	var after: float = float(reg.play_style["curiosity"])
	if after <= before:
		push_error("Expected curiosity to increase with 'explore' tag, %f -> %f" % [before, after])
		return false
	return true


func test_risk_tolerance_increases_with_gamble_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["risk_tolerance"])
	reg.update_from_choice(_make_card(["gamble"]), 0, _make_context())
	var after: float = float(reg.play_style["risk_tolerance"])
	if after <= before:
		push_error("Expected risk_tolerance to increase with 'gamble' tag, %f -> %f" % [before, after])
		return false
	return true


func test_risk_tolerance_decreases_with_safe_tag() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["risk_tolerance"])
	reg.update_from_choice(_make_card(["safe"]), 0, _make_context())
	var after: float = float(reg.play_style["risk_tolerance"])
	if after >= before:
		push_error("Expected risk_tolerance to decrease with 'safe' tag, %f -> %f" % [before, after])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. PATIENCE FROM DECISION TIME
# ─────────────────────────────────────────────────────────────────────────────

func test_fast_decision_shifts_patience_down() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	# < 1000ms = impulsive → patience shifts toward 0
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 500))
	var after: float = float(reg.play_style["patience"])
	if after >= before:
		push_error("Expected patience to decrease with fast decision (500ms), %f -> %f" % [before, after])
		return false
	return true


func test_slow_decision_shifts_patience_up() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	# > 8000ms = methodical → patience shifts toward 1
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 9000))
	var after: float = float(reg.play_style["patience"])
	if after <= before:
		push_error("Expected patience to increase with slow decision (9000ms), %f -> %f" % [before, after])
		return false
	return true


func test_normal_decision_time_does_not_change_patience() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before: float = float(reg.play_style["patience"])
	# 3000ms is neither < 1000 nor > 8000
	reg.update_from_choice(_make_card([]), 0, _make_context({}, 3000))
	var after: float = float(reg.play_style["patience"])
	if not is_equal_approx(before, after):
		push_error("Expected patience unchanged with normal decision time, %f -> %f" % [before, after])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. THEME TRACKING
# ─────────────────────────────────────────────────────────────────────────────

func test_theme_added_to_preferred_after_threshold() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# PREFERENCE_THRESHOLD = 3; trigger 3 times
	for i in range(3):
		reg.update_from_choice(_make_card(["mystery"]), 0, _make_context())
	var pref: Array = reg.preferences["preferred_themes"]
	if "mystery" not in pref:
		push_error("Expected 'mystery' in preferred_themes after 3 occurrences")
		return false
	return true


func test_theme_not_added_before_threshold() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for i in range(2):
		reg.update_from_choice(_make_card(["mystery"]), 0, _make_context())
	var pref: Array = reg.preferences["preferred_themes"]
	if "mystery" in pref:
		push_error("Expected 'mystery' NOT in preferred_themes with only 2 occurrences")
		return false
	return true


func test_theme_not_duplicated_in_preferred() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for i in range(6):
		reg.update_from_choice(_make_card(["combat"]), 0, _make_context())
	var pref: Array = reg.preferences["preferred_themes"]
	var count: int = 0
	for t in pref:
		if t == "combat":
			count += 1
	if count > 1:
		push_error("Expected 'combat' to appear at most once in preferred_themes, got %d" % count)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. NPC INTERACTION
# ─────────────────────────────────────────────────────────────────────────────

func test_npc_added_to_favorites_after_3_positive() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for i in range(3):
		reg.update_from_choice(_make_card([], "npc_druid"), 1, _make_context())  # option 1 = positive
	var favs: Array = reg.preferences["favorite_npcs"]
	if "npc_druid" not in favs:
		push_error("Expected 'npc_druid' in favorite_npcs after 3 positive interactions")
		return false
	return true


func test_npc_added_to_disliked_after_3_negative() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	for i in range(3):
		reg.update_from_choice(_make_card([], "npc_villain"), 0, _make_context())  # option 0 = negative
	var dis: Array = reg.preferences["disliked_npcs"]
	if "npc_villain" not in dis:
		push_error("Expected 'npc_villain' in disliked_npcs after 3 negative interactions")
		return false
	return true


func test_npc_without_id_does_not_crash() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# Card with no npc_id — should not raise errors
	reg.update_from_choice(_make_card(["mystery"], ""), 0, _make_context())
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. EXPERIENCE TIERS
# ─────────────────────────────────────────────────────────────────────────────

func test_experience_tier_initiate_at_zero_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 0
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.INITIATE:
		push_error("Expected INITIATE at 0 runs")
		return false
	return true


func test_experience_tier_apprentice_at_10_runs() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 10
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.APPRENTICE:
		push_error("Expected APPRENTICE at 10 runs")
		return false
	return true


func test_experience_tier_master_above_100() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 101
	if reg.get_experience_tier() != PlayerProfileRegistry.ExperienceTier.MASTER:
		push_error("Expected MASTER at 101 runs")
		return false
	return true


func test_experience_tier_name_returns_string() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 0
	var name: String = reg.get_experience_tier_name()
	if name.is_empty():
		push_error("Expected non-empty experience tier name")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. SEED FROM QUIZ
# ─────────────────────────────────────────────────────────────────────────────

func test_seed_from_quiz_maps_axes_to_play_style() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {"approche": 1.0, "relation": -1.0, "esprit": 0.0, "coeur": 0.5},
		"archetype_id": "le_guerrier",
		"archetype_title": "Le Guerrier",
		"dominant_traits": ["audacieux"],
	})
	# approche=1.0 → aggression = (1+1)/2 = 1.0
	if not is_equal_approx(float(reg.play_style["aggression"]), 1.0):
		push_error("Expected aggression == 1.0, got %f" % float(reg.play_style["aggression"]))
		return false
	# relation=-1.0 → altruism = (-1+1)/2 = 0.0
	if not is_equal_approx(float(reg.play_style["altruism"]), 0.0):
		push_error("Expected altruism == 0.0, got %f" % float(reg.play_style["altruism"]))
		return false
	return true


func test_seed_from_quiz_stores_archetype_id() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.seed_from_quiz({
		"axis_positions": {},
		"archetype_id": "le_sage",
		"archetype_title": "Le Sage",
	})
	if reg.get_archetype_id() != "le_sage":
		push_error("Expected archetype_id == 'le_sage', got '%s'" % reg.get_archetype_id())
		return false
	return true


func test_seed_from_quiz_clamps_values_in_range() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	# approche=2.0 is out of -1..1 range — should clamp to [0, 1]
	reg.seed_from_quiz({
		"axis_positions": {"approche": 2.0, "relation": -2.0, "esprit": 0.0, "coeur": 0.0},
		"archetype_id": "",
		"archetype_title": "",
	})
	for key in reg.play_style:
		var val: float = float(reg.play_style[key])
		if val < 0.0 or val > 1.0:
			push_error("play_style.%s out of [0,1] range after seed_from_quiz: %f" % [key, val])
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 8. ON RUN END & DECAY
# ─────────────────────────────────────────────────────────────────────────────

func test_on_run_end_increments_runs_completed() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": false, "ending": {}})
	if reg.meta["runs_completed"] != 1:
		push_error("Expected runs_completed == 1, got %d" % reg.meta["runs_completed"])
		return false
	return true


func test_on_run_end_increments_runs_won_on_victory() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 30, "victory": true, "ending": {}})
	if reg.meta["runs_won"] != 1:
		push_error("Expected runs_won == 1 after victory, got %d" % reg.meta["runs_won"])
		return false
	return true


func test_on_run_end_tracks_longest_run() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 42, "victory": false, "ending": {}})
	reg.on_run_end({"cards_played": 20, "victory": false, "ending": {}})
	if reg.meta["longest_run"] != 42:
		push_error("Expected longest_run == 42, got %d" % reg.meta["longest_run"])
		return false
	return true


func test_on_run_end_tracks_shortest_run() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 42, "victory": false, "ending": {}})
	reg.on_run_end({"cards_played": 20, "victory": false, "ending": {}})
	if reg.meta["shortest_run"] != 20:
		push_error("Expected shortest_run == 20, got %d" % reg.meta["shortest_run"])
		return false
	return true


func test_on_run_end_records_unique_ending() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.on_run_end({"cards_played": 10, "victory": true, "ending": {"title": "Fin Lumineuse"}})
	reg.on_run_end({"cards_played": 10, "victory": true, "ending": {"title": "Fin Lumineuse"}})
	var seen: Array = reg.meta["endings_seen"]
	var count: int = 0
	for e in seen:
		if e == "Fin Lumineuse":
			count += 1
	if count != 1:
		push_error("Expected 'Fin Lumineuse' to appear exactly once, got %d" % count)
		return false
	return true


func test_decay_moves_traits_toward_center() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.play_style["aggression"] = 0.9
	reg._apply_session_decay()
	var after: float = float(reg.play_style["aggression"])
	if after >= 0.9:
		push_error("Expected aggression to move toward 0.5 after decay, was 0.9, got %f" % after)
		return false
	if after <= 0.5:
		push_error("Expected aggression still above 0.5 (decay is slow), got %f" % after)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 9. CONTEXT FOR LLM & SUMMARY
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
			push_error("get_context_for_llm() missing key: %s" % k)
			return false
	return true


func test_get_summary_for_prompt_returns_non_empty_string() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.meta["runs_completed"] = 3
	var summary: String = reg.get_summary_for_prompt()
	if summary.is_empty():
		push_error("Expected non-empty string from get_summary_for_prompt()")
		return false
	return true


func test_get_summary_includes_archetype_title_when_set() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	reg.preferences["archetype_title"] = "Le Gardien"
	var summary: String = reg.get_summary_for_prompt()
	if "Le Gardien" not in summary:
		push_error("Expected 'Le Gardien' in summary when archetype_title is set, got: %s" % summary)
		return false
	return true


func test_get_archetype_id_returns_empty_when_unset() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	if reg.get_archetype_id() != "":
		push_error("Expected empty archetype_id when unset, got '%s'" % reg.get_archetype_id())
		return false
	return true


func test_skill_update_from_outcome_avoided_crisis() -> bool:
	var reg: PlayerProfileRegistry = _make_fresh()
	var before_gm: float = float(reg.skill_assessment["gauge_management"])
	var before_rec: float = float(reg.skill_assessment["recovery"])
	reg.update_from_outcome({"avoided_crisis": true})
	if float(reg.skill_assessment["gauge_management"]) <= before_gm:
		push_error("Expected gauge_management to increase after avoided_crisis")
		return false
	if float(reg.skill_assessment["recovery"]) <= before_rec:
		push_error("Expected recovery to increase after avoided_crisis")
		return false
	return true
