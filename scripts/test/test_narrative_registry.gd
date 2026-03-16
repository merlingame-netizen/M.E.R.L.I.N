## ═══════════════════════════════════════════════════════════════════════════════
## Test Suite — NarrativeRegistry
## ═══════════════════════════════════════════════════════════════════════════════
## Unit tests for NarrativeRegistry covering:
##   - init / reset
##   - arc FSM (start, flags, progress, resolution, deadline, auto-progress)
##   - run phase FSM
##   - foreshadowing (plant, reveal, auto-miss, twist types)
##   - NPC tracking (encounters, relationship, clamp, secrets, callbacks)
##   - theme fatigue (accumulation, decay, weight, floor, fatigued list)
##   - world state (biome, tags, tension, advance_day)
##   - LLM context helpers
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


var _reg: NarrativeRegistry


func _init() -> void:
	_reg = NarrativeRegistry.new()
	_reg.reset_run()


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _fail(msg: String) -> bool:
	push_error("[FAIL] " + msg)
	return false


func _fresh() -> NarrativeRegistry:
	_reg.reset_run()
	return _reg


func _play(reg: NarrativeRegistry, n: int, extra: Dictionary = {}) -> void:
	## Play n cards without side-effect card data unless extra is provided.
	for i in range(n):
		var card: Dictionary = extra.duplicate()
		if not card.has("id"):
			card["id"] = "filler_%d" % i
		reg.process_card(card)


func _approx(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) < eps


# ─────────────────────────────────────────────────────────────────────────────
# 1. INIT & RESET
# ─────────────────────────────────────────────────────────────────────────────

func test_initial_biome_is_broceliande() -> bool:
	var r := _fresh()
	if r.world.biome != "broceliande":
		return _fail("Expected biome 'broceliande', got '%s'" % r.world.biome)
	return true


func test_initial_day_is_1() -> bool:
	var r := _fresh()
	if r.world.day != 1:
		return _fail("Expected day 1, got %d" % r.world.day)
	return true


func test_initial_run_phase_is_setup() -> bool:
	var r := _fresh()
	if r.run_phase != NarrativeRegistry.ArcPhase.SETUP:
		return _fail("Expected SETUP on init, got %d" % r.run_phase)
	return true


func test_reset_clears_active_arcs() -> bool:
	var r := _fresh()
	r.start_arc("a1")
	r.reset_run()
	if r.active_arcs.size() != 0:
		return _fail("active_arcs not cleared by reset_run()")
	return true


func test_reset_clears_npcs() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "merlin"})
	r.reset_run()
	if r.npcs.size() != 0:
		return _fail("npcs not cleared by reset_run()")
	return true


func test_reset_clears_foreshadowing() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("f1", "shadow hint")
	r.reset_run()
	if r.foreshadowing.size() != 0:
		return _fail("foreshadowing not cleared by reset_run()")
	return true


func test_reset_clears_theme_fatigue() -> bool:
	var r := _fresh()
	r.theme_fatigue["mystery"] = 5.0
	r.reset_run()
	if r.theme_fatigue.size() != 0:
		return _fail("theme_fatigue not cleared by reset_run()")
	return true


func test_reset_restores_run_phase_to_setup() -> bool:
	var r := _fresh()
	_play(r, 10)
	r.reset_run()
	if r.run_phase != NarrativeRegistry.ArcPhase.SETUP:
		return _fail("run_phase should reset to SETUP, got %d" % r.run_phase)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. ARC MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

func test_start_arc_returns_true() -> bool:
	var r := _fresh()
	if not r.start_arc("quest_alpha"):
		return _fail("start_arc should return true for first arc")
	return true


func test_start_arc_visible_in_active_arcs() -> bool:
	var r := _fresh()
	r.start_arc("quest_alpha")
	if not r.has_active_arc("quest_alpha"):
		return _fail("has_active_arc should be true after start_arc")
	return true


func test_start_arc_stores_initial_flags() -> bool:
	var r := _fresh()
	r.start_arc("quest_flags", {"urgent": true, "faction": "druides"})
	var arc := r.get_active_arc("quest_flags")
	if arc.is_empty():
		return _fail("get_active_arc returned empty for 'quest_flags'")
	if arc.get("flags", {}).get("urgent", false) != true:
		return _fail("Initial flag 'urgent' not preserved")
	if arc.get("flags", {}).get("faction", "") != "druides":
		return _fail("Initial flag 'faction' not preserved")
	return true


func test_start_arc_max_active_enforced() -> bool:
	var r := _fresh()
	r.start_arc("a1")
	r.start_arc("a2")
	if r.start_arc("a3"):
		return _fail("Should reject 3rd arc (MAX_ACTIVE_ARCS=%d)" % NarrativeRegistry.MAX_ACTIVE_ARCS)
	return true


func test_start_arc_duplicate_rejected() -> bool:
	var r := _fresh()
	r.start_arc("dup")
	if r.start_arc("dup"):
		return _fail("Duplicate arc_id should return false")
	return true


func test_get_active_arc_unknown_returns_empty() -> bool:
	var r := _fresh()
	if not r.get_active_arc("ghost").is_empty():
		return _fail("get_active_arc for unknown id should return empty dict")
	return true


func test_arc_initial_stage_is_setup_enum() -> bool:
	var r := _fresh()
	r.start_arc("arc_stage_test")
	var arc := r.get_active_arc("arc_stage_test")
	if arc.get("stage", -1) != NarrativeRegistry.ArcPhase.SETUP:
		return _fail("New arc stage should be SETUP(1), got %d" % arc.get("stage", -1))
	return true


func test_arc_deadline_is_positive() -> bool:
	var r := _fresh()
	r.start_arc("arc_dl")
	var arc := r.get_active_arc("arc_dl")
	if arc.get("deadline_card", 0) <= 0:
		return _fail("deadline_card should be positive, got %d" % arc.get("deadline_card", 0))
	return true


func test_arc_progress_card_adds_to_cards_in_arc() -> bool:
	var r := _fresh()
	r.start_arc("arc_prog")
	r.process_card({"id": "c1", "arc_id": "arc_prog"})
	var arc := r.get_active_arc("arc_prog")
	if arc.is_empty():
		return _fail("Arc 'arc_prog' should still be active after 1 card")
	var cards: Array = arc.get("cards_in_arc", [])
	if cards.size() != 1:
		return _fail("Expected 1 card in arc, got %d" % cards.size())
	return true


func test_arc_resolution_card_completes_arc() -> bool:
	var r := _fresh()
	r.start_arc("arc_res")
	r.process_card({"arc_id": "arc_res", "arc_resolution": true, "arc_outcome": "victory"})
	if r.has_active_arc("arc_res"):
		return _fail("Arc should be complete after arc_resolution=true")
	var found := false
	for ca in r.completed_arcs:
		if ca.get("id") == "arc_res" and ca.get("resolution") == "victory":
			found = true
			break
	if not found:
		return _fail("Completed arc with outcome 'victory' not in completed_arcs")
	return true


func test_arc_stage_4_completes_arc() -> bool:
	var r := _fresh()
	r.start_arc("arc_s4")
	r.process_card({"arc_id": "arc_s4", "arc_stage": NarrativeRegistry.ArcPhase.RESOLUTION})
	if r.has_active_arc("arc_s4"):
		return _fail("Arc should complete when arc_stage reaches RESOLUTION(4)")
	return true


func test_arc_flags_merged_from_card() -> bool:
	var r := _fresh()
	r.start_arc("arc_mf", {"orig": "yes"})
	r.process_card({"arc_id": "arc_mf", "arc_flags": {"extra": "added"}})
	var arc := r.get_active_arc("arc_mf")
	if arc.get("flags", {}).get("orig", "") != "yes":
		return _fail("Original flag 'orig' should persist after card merge")
	if arc.get("flags", {}).get("extra", "") != "added":
		return _fail("Card flag 'extra' should be merged into arc flags")
	return true


func test_arc_expires_after_deadline() -> bool:
	var r := _fresh()
	r.start_arc("arc_exp")
	## ARC_AUTO_CLOSE_CARDS = 30; _auto_progress_arc_stages will auto-complete
	## around card 11 (3+6+2). Either way it must not be active after 35 cards.
	_play(r, 35)
	if r.has_active_arc("arc_exp"):
		return _fail("arc_exp should have closed within 35 cards")
	return true


func test_on_run_end_closes_all_arcs() -> bool:
	var r := _fresh()
	r.start_arc("e1")
	r.start_arc("e2")
	r.on_run_end()
	if r.active_arcs.size() != 0:
		return _fail("on_run_end() should close all active arcs, %d remain" % r.active_arcs.size())
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. RUN PHASE FSM
# ─────────────────────────────────────────────────────────────────────────────

func test_run_phase_name_setup() -> bool:
	var r := _fresh()
	if r.get_run_phase_name() != "Mise en place":
		return _fail("Expected 'Mise en place', got '%s'" % r.get_run_phase_name())
	return true


func test_run_phase_advances_to_rising() -> bool:
	## RUN_PHASE_THRESHOLDS[SETUP]=5 → after card 6 phase must be RISING
	var r := _fresh()
	_play(r, 6)
	if r.run_phase != NarrativeRegistry.ArcPhase.RISING:
		return _fail("Expected RISING after 6 cards, got %d" % r.run_phase)
	return true


func test_run_phase_advances_to_climax() -> bool:
	## RUN_PHASE_THRESHOLDS[RISING]=15 → after card 16 phase must be CLIMAX
	var r := _fresh()
	_play(r, 16)
	if r.run_phase != NarrativeRegistry.ArcPhase.CLIMAX:
		return _fail("Expected CLIMAX after 16 cards, got %d" % r.run_phase)
	return true


func test_run_phase_advances_to_resolution() -> bool:
	## RUN_PHASE_THRESHOLDS[CLIMAX]=25 → after card 26 phase must be RESOLUTION
	var r := _fresh()
	_play(r, 26)
	if r.run_phase != NarrativeRegistry.ArcPhase.RESOLUTION:
		return _fail("Expected RESOLUTION after 26 cards, got %d" % r.run_phase)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. FORESHADOWING
# ─────────────────────────────────────────────────────────────────────────────

func test_plant_foreshadowing_returns_true() -> bool:
	var r := _fresh()
	if not r.plant_foreshadowing("h1", "A raven circles"):
		return _fail("plant_foreshadowing should return true on first hint")
	return true


func test_plant_foreshadowing_stored_in_array() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("h1", "hint text")
	if r.foreshadowing.size() != 1:
		return _fail("Expected 1 foreshadowing entry, got %d" % r.foreshadowing.size())
	return true


func test_plant_foreshadowing_max_enforced() -> bool:
	var r := _fresh()
	for i in range(NarrativeRegistry.MAX_FORESHADOWING):
		r.plant_foreshadowing("h%d" % i, "text")
	if r.plant_foreshadowing("h_overflow", "too many"):
		return _fail("Should reject hint beyond MAX_FORESHADOWING=%d" % NarrativeRegistry.MAX_FORESHADOWING)
	return true


func test_reveal_too_early_returns_false() -> bool:
	## min_reveal = card_number + FORESHADOWING_MIN_CARDS(5); card_number=0 at plant
	var r := _fresh()
	r.plant_foreshadowing("early", "not yet")
	if r.reveal_foreshadowing("early"):
		return _fail("Should not reveal before min_reveal_card window")
	return true


func test_reveal_after_min_cards_returns_true() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("ready", "ready hint", "ami_ennemi")
	_play(r, NarrativeRegistry.FORESHADOWING_MIN_CARDS + 1)
	if not r.reveal_foreshadowing("ready"):
		return _fail("Should reveal after min_reveal_card is passed")
	return true


func test_revealable_empty_before_window() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("window", "hint")
	if r.get_revealable_foreshadowing().size() != 0:
		return _fail("No hints should be revealable before min window")
	return true


func test_revealable_after_min_cards() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("hA", "hint A")
	r.plant_foreshadowing("hB", "hint B")
	_play(r, NarrativeRegistry.FORESHADOWING_MIN_CARDS + 1)
	var rv: int = r.get_revealable_foreshadowing().size()
	if rv != 2:
		return _fail("Expected 2 revealable hints, got %d" % rv)
	return true


func test_hint_auto_marked_missed_after_max_cards() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("miss_me", "will be missed")
	_play(r, NarrativeRegistry.FORESHADOWING_MAX_CARDS + 2)
	var hint: Dictionary = {}
	for h in r.foreshadowing:
		if h.get("id") == "miss_me":
			hint = h
			break
	if hint.is_empty():
		return _fail("hint 'miss_me' not found in foreshadowing array")
	if not hint.get("revealed", false):
		return _fail("hint should be auto-revealed (missed) after max_reveal_card")
	if not hint.get("missed", false):
		return _fail("hint should have missed=true flag after max_reveal_card")
	return true


func test_explicit_twist_type_preserved() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("twt", "twist hint", "identity_hidden")
	var hint: Dictionary = {}
	for h in r.foreshadowing:
		if h.get("id") == "twt":
			hint = h
			break
	if hint.get("twist_type") != "identity_hidden":
		return _fail("Expected twist_type 'identity_hidden', got '%s'" % hint.get("twist_type", ""))
	return true


func test_empty_twist_type_assigns_from_list() -> bool:
	var r := _fresh()
	r.plant_foreshadowing("rand_twist", "random", "")
	var hint: Dictionary = {}
	for h in r.foreshadowing:
		if h.get("id") == "rand_twist":
			hint = h
			break
	var twist: String = hint.get("twist_type", "")
	if twist not in NarrativeRegistry.TWIST_TYPES:
		return _fail("Auto-assigned twist_type '%s' not in TWIST_TYPES" % twist)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. NPC TRACKING
# ─────────────────────────────────────────────────────────────────────────────

func test_npc_created_on_first_encounter() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "viviane"})
	if r.get_npc_info("viviane").is_empty():
		return _fail("NPC 'viviane' should be created on first encounter")
	return true


func test_npc_encounter_count_increments() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "viviane"})
	r.process_card({"npc_id": "viviane"})
	var enc: int = r.get_npc_info("viviane").get("encounters", 0)
	if enc != 2:
		return _fail("Expected 2 encounters, got %d" % enc)
	return true


func test_npc_relationship_positive_change() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "morgan", "npc_relationship_change": 25})
	if r.get_npc_info("morgan").get("relationship", 0) != 25:
		return _fail("Expected relationship 25")
	return true


func test_npc_relationship_cumulative() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "morgan", "npc_relationship_change": 30})
	r.process_card({"npc_id": "morgan", "npc_relationship_change": -10})
	if r.get_npc_info("morgan").get("relationship", 0) != 20:
		return _fail("Expected cumulative relationship 20 (30-10)")
	return true


func test_npc_relationship_clamp_high() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "ankou", "npc_relationship_change": 500})
	if r.get_npc_info("ankou").get("relationship", 0) != 100:
		return _fail("Relationship must clamp at 100")
	return true


func test_npc_relationship_clamp_low() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "ankou", "npc_relationship_change": -500})
	if r.get_npc_info("ankou").get("relationship", 0) != -100:
		return _fail("Relationship must clamp at -100")
	return true


func test_npc_secret_added() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "druid", "npc_secrets_revealed": ["true_name"]})
	if "true_name" not in r.get_npc_info("druid").get("secrets_known", []):
		return _fail("'true_name' should be in secrets_known")
	return true


func test_npc_secret_not_duplicated() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "druid", "npc_secrets_revealed": ["true_name"]})
	r.process_card({"npc_id": "druid", "npc_secrets_revealed": ["true_name"]})
	var secrets: Array = r.get_npc_info("druid").get("secrets_known", [])
	var count := 0
	for s in secrets:
		if s == "true_name":
			count += 1
	if count != 1:
		return _fail("Secret 'true_name' should not be duplicated, count=%d" % count)
	return true


func test_npc_not_in_callback_too_soon() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "korrigan"})
	## Seen at card 1; min_cards_since default=10 → must not appear yet
	for entry in r.get_npcs_for_callback(10):
		if entry.get("npc_id") == "korrigan":
			return _fail("korrigan should not be in callbacks so soon")
	return true


func test_npc_available_for_callback_after_gap() -> bool:
	var r := _fresh()
	r.process_card({"npc_id": "korrigan"})
	_play(r, 11)
	var found := false
	for entry in r.get_npcs_for_callback(10):
		if entry.get("npc_id") == "korrigan":
			found = true
			break
	if not found:
		return _fail("korrigan should appear in callbacks after 11 cards")
	return true


func test_get_npc_info_unknown_returns_empty() -> bool:
	var r := _fresh()
	if not r.get_npc_info("nobody").is_empty():
		return _fail("get_npc_info for unknown NPC should return empty dict")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. THEME FATIGUE
# ─────────────────────────────────────────────────────────────────────────────

func test_theme_fatigue_accumulates() -> bool:
	var r := _fresh()
	r.process_card({"themes": ["mystery"]})
	if r.theme_fatigue.get("mystery", 0.0) <= 0.0:
		return _fail("mystery fatigue should be positive after 1 card")
	return true


func test_theme_weight_fresh_is_one() -> bool:
	var r := _fresh()
	if not _approx(r.get_theme_weight("adventure"), 1.0):
		return _fail("Fresh theme weight should be 1.0")
	return true


func test_theme_weight_decreases_with_fatigue() -> bool:
	var r := _fresh()
	r.theme_fatigue["adventure"] = 4.0
	## Expected: max(0.1, 1.0 - 4.0 * 0.15) = max(0.1, 0.4) = 0.4
	if not _approx(r.get_theme_weight("adventure"), 0.4):
		return _fail("Expected weight ~0.4 at fatigue=4.0, got %.2f" % r.get_theme_weight("adventure"))
	return true


func test_theme_weight_floor_at_0_1() -> bool:
	var r := _fresh()
	r.theme_fatigue["horror"] = 100.0
	if r.get_theme_weight("horror") < 0.1 - 0.001:
		return _fail("Theme weight must not go below 0.1")
	return true


func test_fatigued_themes_returns_list_at_threshold() -> bool:
	## THEME_FATIGUE_WARNING=3; inject directly to skip timing of decay
	var r := _fresh()
	r.theme_fatigue["combat"] = 3.5
	if "combat" not in r.get_fatigued_themes():
		return _fail("'combat' should appear in fatigued themes at fatigue=3.5")
	return true


func test_get_recommended_themes_returns_3() -> bool:
	var r := _fresh()
	if r.get_recommended_themes().size() != 3:
		return _fail("get_recommended_themes() must return exactly 3 themes")
	return true


func test_recommended_themes_exclude_fatigued() -> bool:
	var r := _fresh()
	r.theme_fatigue["mystery"] = 10.0
	r.theme_fatigue["combat"] = 10.0
	r.theme_fatigue["social"] = 10.0
	var rec := r.get_recommended_themes()
	for t in rec:
		if t in ["mystery", "combat", "social"]:
			return _fail("Fatigued theme '%s' should not be recommended" % t)
	return true


func test_recent_themes_capped_at_10() -> bool:
	var r := _fresh()
	for i in range(15):
		r.process_card({"themes": ["mystery"]})
	if r.recent_themes.size() > 10:
		return _fail("recent_themes exceeded 10, got %d" % r.recent_themes.size())
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. WORLD STATE
# ─────────────────────────────────────────────────────────────────────────────

func test_set_biome_updates_world() -> bool:
	var r := _fresh()
	r.set_biome("avalon")
	if r.world.biome != "avalon":
		return _fail("Expected biome 'avalon', got '%s'" % r.world.biome)
	return true


func test_process_card_biome_field_updates_world() -> bool:
	var r := _fresh()
	r.process_card({"biome": "tir_na_nog"})
	if r.world.biome != "tir_na_nog":
		return _fail("Expected biome 'tir_na_nog', got '%s'" % r.world.biome)
	return true


func test_add_tags_via_card() -> bool:
	var r := _fresh()
	r.process_card({"add_tags": ["cursed", "fog"]})
	if "cursed" not in r.world.active_tags:
		return _fail("Tag 'cursed' should be in active_tags")
	if "fog" not in r.world.active_tags:
		return _fail("Tag 'fog' should be in active_tags")
	return true


func test_remove_tags_via_card() -> bool:
	var r := _fresh()
	r.process_card({"add_tags": ["rain"]})
	r.process_card({"remove_tags": ["rain"]})
	if "rain" in r.world.active_tags:
		return _fail("Tag 'rain' should be removed after remove_tags card")
	return true


func test_increase_tension_clamps_at_1() -> bool:
	var r := _fresh()
	r.increase_tension(99.0)
	if r.world.global_tension > 1.0:
		return _fail("global_tension exceeded 1.0 after increase_tension(99)")
	return true


func test_decrease_tension_clamps_at_0() -> bool:
	var r := _fresh()
	r.decrease_tension(99.0)
	if r.world.global_tension < 0.0:
		return _fail("global_tension went below 0.0 after decrease_tension(99)")
	return true


func test_twist_card_reduces_tension() -> bool:
	var r := _fresh()
	r.world.global_tension = 0.8
	r.process_card({"type": "twist"})
	## Twist decreases by 0.2 → ~0.6
	if r.world.global_tension >= 0.8:
		return _fail("Tension should drop after twist card, got %.2f" % r.world.global_tension)
	return true


func test_regular_card_raises_tension() -> bool:
	var r := _fresh()
	r.world.global_tension = 0.3
	r.process_card({})
	if r.world.global_tension <= 0.3:
		return _fail("Normal card should raise tension slightly, got %.2f" % r.world.global_tension)
	return true


func test_advance_day_increments_day_counter() -> bool:
	var r := _fresh()
	var before: int = r.world.day
	r.advance_day()
	if r.world.day != before + 1:
		return _fail("advance_day() should add 1 to day, got %d -> %d" % [before, r.world.day])
	return true


func test_advance_day_cycles_time_of_day() -> bool:
	var r := _fresh()
	## Force known starting point
	r.world.time_of_day = "aube"
	r.advance_day()
	if r.world.time_of_day != "jour":
		return _fail("Expected time_of_day 'jour' after aube, got '%s'" % r.world.time_of_day)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 8. LLM CONTEXT HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func test_get_context_for_llm_is_dict() -> bool:
	var r := _fresh()
	if not r.get_context_for_llm() is Dictionary:
		return _fail("get_context_for_llm() must return a Dictionary")
	return true


func test_get_context_for_llm_required_keys() -> bool:
	var r := _fresh()
	var ctx := r.get_context_for_llm()
	var required := [
		"run_phase", "run_phase_name", "active_arcs", "active_foreshadowing",
		"revealable_twists", "recent_themes", "fatigued_themes",
		"recommended_themes", "tension_level", "known_npcs",
		"npcs_for_callback", "world_state"
	]
	for key in required:
		if not ctx.has(key):
			return _fail("Missing required key in LLM context: '%s'" % key)
	return true


func test_get_context_tension_level_reflects_world() -> bool:
	var r := _fresh()
	r.world.global_tension = 0.77
	var ctx := r.get_context_for_llm()
	if not _approx(ctx.get("tension_level", 0.0), 0.77):
		return _fail("tension_level in context should match world.global_tension")
	return true


func test_get_summary_for_prompt_is_nonempty_string() -> bool:
	var r := _fresh()
	var s: String = r.get_summary_for_prompt()
	if not s is String or s.length() < 5:
		return _fail("get_summary_for_prompt() must return a meaningful String")
	return true


func test_get_summary_contains_phase_name() -> bool:
	var r := _fresh()
	var s: String = r.get_summary_for_prompt()
	if "Mise en place" not in s:
		return _fail("Summary must include phase name 'Mise en place'")
	return true


func test_get_summary_contains_biome() -> bool:
	var r := _fresh()
	var s: String = r.get_summary_for_prompt()
	if "broceliande" not in s:
		return _fail("Summary must include default biome 'broceliande'")
	return true
