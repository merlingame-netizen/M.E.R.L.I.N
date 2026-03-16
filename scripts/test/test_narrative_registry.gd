## test_narrative_registry.gd
## Unit tests for NarrativeRegistry — RefCounted pattern, no GUT dependency.
## Covers: arc management, foreshadowing, NPC tracking, theme detection,
##         world state, run phase progression, LLM context generation.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error+return false.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _make_registry() -> NarrativeRegistry:
	## Create a fresh registry with disk I/O bypassed (no save file needed).
	var reg: NarrativeRegistry = NarrativeRegistry.new()
	reg.reset_run()
	return reg


static func _approx_eq(a: float, b: float, epsilon: float = 0.01) -> bool:
	return absf(a - b) < epsilon


static func _play_cards(reg: NarrativeRegistry, count: int, card_template: Dictionary = {}) -> void:
	for i in range(count):
		var card: Dictionary = card_template.duplicate()
		if not card.has("id"):
			card["id"] = "card_%d" % (i + 1)
		reg.process_card(card)


# ═══════════════════════════════════════════════════════════════════════════════
# ARC MANAGEMENT — start_arc, has_active_arc, get_active_arc
# ═══════════════════════════════════════════════════════════════════════════════

func test_start_arc_basic() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var ok: bool = reg.start_arc("quest_forest")
	if not ok:
		push_error("start_arc should return true for first arc")
		return false
	if not reg.has_active_arc("quest_forest"):
		push_error("has_active_arc should return true after start")
		return false
	return true


func test_start_arc_with_flags() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var flags: Dictionary = {"urgent": true, "faction": "druides"}
	reg.start_arc("quest_druid", flags)
	var arc: Dictionary = reg.get_active_arc("quest_druid")
	if arc.is_empty():
		push_error("get_active_arc returned empty for active arc")
		return false
	if arc.get("flags", {}).get("urgent", false) != true:
		push_error("Arc flags not preserved")
		return false
	return true


func test_start_arc_max_active_limit() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("arc_1")
	reg.start_arc("arc_2")
	var third: bool = reg.start_arc("arc_3")
	if third:
		push_error("Should reject 3rd arc when MAX_ACTIVE_ARCS=2")
		return false
	return true


func test_start_arc_duplicate_rejected() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("arc_dup")
	var second: bool = reg.start_arc("arc_dup")
	if second:
		push_error("Should reject duplicate arc_id")
		return false
	return true


func test_get_active_arc_not_found() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var arc: Dictionary = reg.get_active_arc("nonexistent")
	if not arc.is_empty():
		push_error("get_active_arc should return empty dict for unknown arc")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ARC PROGRESSION — process_card with arc_id, arc_stage, arc_resolution
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_progress_via_card() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("quest_a")
	reg.process_card({"id": "c1", "arc_id": "quest_a"})
	var arc: Dictionary = reg.get_active_arc("quest_a")
	if arc.is_empty():
		push_error("Arc should still be active after 1 card")
		return false
	var cards_in: Array = arc.get("cards_in_arc", [])
	if cards_in.size() != 1:
		push_error("Expected 1 card in arc, got %d" % cards_in.size())
		return false
	return true


func test_arc_completion_via_resolution() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("quest_b")
	reg.process_card({"id": "c1", "arc_id": "quest_b", "arc_resolution": true, "arc_outcome": "victory"})
	if reg.has_active_arc("quest_b"):
		push_error("Arc should be completed after arc_resolution=true")
		return false
	if reg.completed_arcs.size() < 1:
		push_error("completed_arcs should have the resolved arc")
		return false
	var completed: Dictionary = reg.completed_arcs[reg.completed_arcs.size() - 1]
	if completed.get("resolution", "") != "victory":
		push_error("Expected resolution 'victory', got: " + completed.get("resolution", ""))
		return false
	return true


func test_arc_completion_via_stage_4() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("quest_c")
	reg.process_card({"id": "c1", "arc_id": "quest_c", "arc_stage": NarrativeRegistry.ArcPhase.RESOLUTION})
	if reg.has_active_arc("quest_c"):
		push_error("Arc should complete when stage >= 4 (RESOLUTION)")
		return false
	return true


func test_arc_flags_update_via_card() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("quest_d", {"key1": "val1"})
	reg.process_card({"id": "c1", "arc_id": "quest_d", "arc_flags": {"key2": "val2"}})
	var arc: Dictionary = reg.get_active_arc("quest_d")
	if arc.get("flags", {}).get("key2", "") != "val2":
		push_error("arc_flags from card should merge into arc flags")
		return false
	if arc.get("flags", {}).get("key1", "") != "val1":
		push_error("Original flag key1 should be preserved")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ARC DEADLINE — auto-close after ARC_AUTO_CLOSE_CARDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_deadline_expires() -> bool:
	## Arc auto-completes via stage progression (~11 cards) or deadline (30 cards).
	## _auto_progress_arc_stages() advances stages every few cards, so the arc
	## resolves as "auto_resolved" before the 30-card deadline triggers.
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("quest_expire")
	for i in range(35):
		reg.process_card({"id": "filler_%d" % i})
	if reg.has_active_arc("quest_expire"):
		push_error("Arc should have completed after 35 cards")
		return false
	# Check it landed in completed_arcs (auto_resolved or expired)
	var tracker: Dictionary = {"found": false}
	for arc in reg.completed_arcs:
		if arc.get("id", "") == "quest_expire":
			tracker["found"] = true
	if not tracker["found"]:
		push_error("Completed arc should be in completed_arcs")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FORESHADOWING — plant, reveal, revealable list
# ═══════════════════════════════════════════════════════════════════════════════

func test_plant_foreshadowing_basic() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var ok: bool = reg.plant_foreshadowing("hint_1", "Something lurks in shadows", "identity_hidden")
	if not ok:
		push_error("plant_foreshadowing should return true")
		return false
	if reg.foreshadowing.size() != 1:
		push_error("Expected 1 foreshadowing element, got %d" % reg.foreshadowing.size())
		return false
	var hint: Dictionary = reg.foreshadowing[0]
	if hint.get("twist_type", "") != "identity_hidden":
		push_error("twist_type should be 'identity_hidden'")
		return false
	return true


func test_plant_foreshadowing_max_limit() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	for i in range(5):
		reg.plant_foreshadowing("hint_%d" % i, "hint text %d" % i)
	var sixth: bool = reg.plant_foreshadowing("hint_6", "too many")
	if sixth:
		push_error("Should reject 6th foreshadowing when MAX_FORESHADOWING=5")
		return false
	return true


func test_reveal_foreshadowing_too_early() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.plant_foreshadowing("hint_early", "early hint")
	# min_reveal_card = 0 + FORESHADOWING_MIN_CARDS = 5
	# Without playing cards, _current_card_number = 0, so reveal should fail
	var revealed: bool = reg.reveal_foreshadowing("hint_early")
	if revealed:
		push_error("Should not reveal before min_reveal_card (need 5 cards)")
		return false
	return true


func test_reveal_foreshadowing_after_min_cards() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.plant_foreshadowing("hint_ok", "ready hint", "fausse_victoire")
	# Play 6 cards to pass min_reveal_card threshold (5)
	_play_cards(reg, 6)
	var revealed: bool = reg.reveal_foreshadowing("hint_ok")
	if not revealed:
		push_error("Should reveal after playing enough cards past min_reveal")
		return false
	return true


func test_get_revealable_foreshadowing() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.plant_foreshadowing("h1", "hint 1")
	reg.plant_foreshadowing("h2", "hint 2")
	# Play enough cards to make both revealable
	_play_cards(reg, 6)
	var revealable: Array = reg.get_revealable_foreshadowing()
	if revealable.size() != 2:
		push_error("Expected 2 revealable hints, got %d" % revealable.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NPC TRACKING — encounter, relationship, secrets
# ═══════════════════════════════════════════════════════════════════════════════

func test_npc_encounter_tracking() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "npc_id": "merlin"})
	reg.process_card({"id": "c2", "npc_id": "merlin"})
	var npc: Dictionary = reg.get_npc_info("merlin")
	if npc.is_empty():
		push_error("NPC 'merlin' should be tracked after encounter")
		return false
	if npc.get("encounters", 0) != 2:
		push_error("Expected 2 encounters, got %d" % npc.get("encounters", 0))
		return false
	return true


func test_npc_relationship_change() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "npc_id": "viviane", "npc_relationship_change": 30})
	reg.process_card({"id": "c2", "npc_id": "viviane", "npc_relationship_change": -10})
	var npc: Dictionary = reg.get_npc_info("viviane")
	var rel: int = npc.get("relationship", 0)
	if rel != 20:
		push_error("Expected relationship 20 (30-10), got %d" % rel)
		return false
	return true


func test_npc_relationship_clamp() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "npc_id": "ankou", "npc_relationship_change": 200})
	var npc: Dictionary = reg.get_npc_info("ankou")
	if npc.get("relationship", 0) != 100:
		push_error("Relationship should clamp to 100, got %d" % npc.get("relationship", 0))
		return false
	return true


func test_npc_secrets_tracking() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "npc_id": "korrigan", "npc_secrets_revealed": ["true_name"]})
	reg.process_card({"id": "c2", "npc_id": "korrigan", "npc_secrets_revealed": ["true_name", "weakness"]})
	var npc: Dictionary = reg.get_npc_info("korrigan")
	var secrets: Array = npc.get("secrets_known", [])
	if secrets.size() != 2:
		push_error("Expected 2 unique secrets, got %d" % secrets.size())
		return false
	return true


func test_npc_callback_availability() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "npc_id": "fairy"})
	# Play 12 more cards without fairy (min_cards_since default=10)
	_play_cards(reg, 12)
	var callbacks: Array = reg.get_npcs_for_callback()
	var tracker: Dictionary = {"found": false}
	for cb in callbacks:
		if cb.get("npc_id", "") == "fairy":
			tracker["found"] = true
	if not tracker["found"]:
		push_error("fairy should be available for callback after 12 cards since last seen")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# THEME MANAGEMENT — fatigue, weights, recommendations
# ═══════════════════════════════════════════════════════════════════════════════

func test_theme_fatigue_accumulates() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "themes": ["combat"]})
	reg.process_card({"id": "c2", "themes": ["combat"]})
	reg.process_card({"id": "c3", "themes": ["combat"]})
	# fatigue = 3 * 1.0 - 3 * THEME_FATIGUE_DECAY(0.1) = 2.7
	# (each process_card adds 1.0 then decays all by 0.1)
	var fatigued: Array = reg.get_fatigued_themes()
	# After 3 repetitions, fatigue should have hit the warning threshold
	# The exact value depends on decay timing, but "combat" should be fatigued
	# fatigue after card1: 1.0 - 0.1 = 0.9
	# fatigue after card2: 0.9 + 1.0 - 0.1 = 1.8
	# fatigue after card3: 1.8 + 1.0 - 0.1 = 2.7
	# Warning threshold = 3, so NOT yet fatigued. Need one more.
	reg.process_card({"id": "c4", "themes": ["combat"]})
	# fatigue after card4: 2.7 + 1.0 = 3.7, then decay to 3.6
	fatigued = reg.get_fatigued_themes()
	if "combat" not in fatigued:
		push_error("'combat' should be fatigued after 4 repetitions")
		return false
	return true


func test_theme_weight_decreases_with_fatigue() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var weight_fresh: float = reg.get_theme_weight("mystery")
	if not _approx_eq(weight_fresh, 1.0):
		push_error("Fresh theme weight should be 1.0, got %.2f" % weight_fresh)
		return false
	# Add fatigue manually
	reg.theme_fatigue["mystery"] = 4.0
	var weight_fatigued: float = reg.get_theme_weight("mystery")
	# Expected: max(0.1, 1.0 - 4.0 * 0.15) = max(0.1, 0.4) = 0.4
	if not _approx_eq(weight_fatigued, 0.4):
		push_error("Fatigued theme weight should be ~0.4, got %.2f" % weight_fatigued)
		return false
	return true


func test_theme_weight_floor() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.theme_fatigue["horror"] = 20.0
	var weight: float = reg.get_theme_weight("horror")
	# Expected: max(0.1, 1.0 - 20.0 * 0.15) = max(0.1, -2.0) = 0.1
	if not _approx_eq(weight, 0.1):
		push_error("Theme weight floor should be 0.1, got %.2f" % weight)
		return false
	return true


func test_recommended_themes_excludes_fatigued() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	# Fatigue the first 3 themes heavily
	reg.theme_fatigue["mystery"] = 10.0
	reg.theme_fatigue["combat"] = 10.0
	reg.theme_fatigue["social"] = 10.0
	var recommended: Array = reg.get_recommended_themes()
	if recommended.size() != 3:
		push_error("get_recommended_themes should return 3 themes, got %d" % recommended.size())
		return false
	for theme in recommended:
		if theme in ["mystery", "combat", "social"]:
			push_error("Fatigued theme '%s' should not be in recommendations" % theme)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN PHASE PROGRESSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_run_phase_setup_initial() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	if reg.run_phase != NarrativeRegistry.ArcPhase.SETUP:
		push_error("Initial run_phase should be SETUP(1), got %d" % reg.run_phase)
		return false
	if reg.get_run_phase_name() != "Mise en place":
		push_error("Expected 'Mise en place', got: " + reg.get_run_phase_name())
		return false
	return true


func test_run_phase_progresses_with_cards() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	# After 6 cards -> RISING (threshold SETUP=5)
	_play_cards(reg, 6)
	if reg.run_phase != NarrativeRegistry.ArcPhase.RISING:
		push_error("After 6 cards, run_phase should be RISING(2), got %d" % reg.run_phase)
		return false
	# After 16 total -> CLIMAX (threshold RISING=15)
	_play_cards(reg, 10)
	if reg.run_phase != NarrativeRegistry.ArcPhase.CLIMAX:
		push_error("After 16 cards, run_phase should be CLIMAX(3), got %d" % reg.run_phase)
		return false
	# After 26 total -> RESOLUTION (threshold CLIMAX=25)
	_play_cards(reg, 10)
	if reg.run_phase != NarrativeRegistry.ArcPhase.RESOLUTION:
		push_error("After 26 cards, run_phase should be RESOLUTION(4), got %d" % reg.run_phase)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# WORLD STATE — biome, tension, tags
# ═══════════════════════════════════════════════════════════════════════════════

func test_world_biome_update() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.set_biome("avalon")
	if reg.world.get("biome", "") != "avalon":
		push_error("set_biome should update world.biome to 'avalon'")
		return false
	return true


func test_world_tension_increase_decrease() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var initial: float = reg.world.get("global_tension", 0.0)
	reg.increase_tension(0.2)
	var after_inc: float = reg.world.get("global_tension", 0.0)
	if not _approx_eq(after_inc, initial + 0.2):
		push_error("Tension should increase by 0.2, got %.2f" % after_inc)
		return false
	reg.decrease_tension(0.1)
	var after_dec: float = reg.world.get("global_tension", 0.0)
	if not _approx_eq(after_dec, after_inc - 0.1):
		push_error("Tension should decrease by 0.1, got %.2f" % after_dec)
		return false
	return true


func test_world_tension_clamp() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.increase_tension(5.0)
	if reg.world.get("global_tension", 0.0) > 1.0:
		push_error("Tension should clamp at 1.0")
		return false
	reg.decrease_tension(10.0)
	if reg.world.get("global_tension", 0.0) < 0.0:
		push_error("Tension should clamp at 0.0")
		return false
	return true


func test_world_tags_via_card() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.process_card({"id": "c1", "add_tags": ["cursed", "moonlit"]})
	var tags: Array = reg.world.get("active_tags", [])
	if "cursed" not in tags or "moonlit" not in tags:
		push_error("Tags 'cursed' and 'moonlit' should be in active_tags")
		return false
	reg.process_card({"id": "c2", "remove_tags": ["cursed"]})
	tags = reg.world.get("active_tags", [])
	if "cursed" in tags:
		push_error("Tag 'cursed' should have been removed")
		return false
	if "moonlit" not in tags:
		push_error("Tag 'moonlit' should still be present")
		return false
	return true


func test_world_twist_card_reduces_tension() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.world["global_tension"] = 0.8
	reg.process_card({"id": "twist_card", "type": "twist"})
	var tension: float = reg.world.get("global_tension", 0.0)
	# Twist reduces by 0.2 -> 0.6
	if not _approx_eq(tension, 0.6):
		push_error("Twist card should reduce tension by 0.2, got %.2f" % tension)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RESET & LLM CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_run_clears_state() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("arc_x")
	reg.plant_foreshadowing("hint_x", "test")
	reg.process_card({"id": "c1", "npc_id": "npc_x", "themes": ["combat"]})
	reg.reset_run()
	if reg.active_arcs.size() != 0:
		push_error("active_arcs should be empty after reset")
		return false
	if reg.foreshadowing.size() != 0:
		push_error("foreshadowing should be empty after reset")
		return false
	if reg.npcs.size() != 0:
		push_error("npcs should be empty after reset")
		return false
	if reg.recent_themes.size() != 0:
		push_error("recent_themes should be empty after reset")
		return false
	if reg.run_phase != NarrativeRegistry.ArcPhase.SETUP:
		push_error("run_phase should reset to SETUP")
		return false
	return true


func test_get_context_for_llm_structure() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("test_arc")
	_play_cards(reg, 3)
	var ctx: Dictionary = reg.get_context_for_llm()
	var required_keys: Array = [
		"run_phase", "run_phase_name", "active_arcs",
		"active_foreshadowing", "revealable_twists",
		"recent_themes", "fatigued_themes", "recommended_themes",
		"tension_level", "known_npcs", "npcs_for_callback",
		"world_state"
	]
	for key in required_keys:
		if not ctx.has(key):
			push_error("LLM context missing key: " + key)
			return false
	return true


func test_get_summary_for_prompt_not_empty() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.start_arc("summary_arc")
	_play_cards(reg, 3)
	var summary: String = reg.get_summary_for_prompt()
	if summary.length() < 10:
		push_error("Summary should be a meaningful string, got length %d" % summary.length())
		return false
	if "Phase narrative" not in summary:
		push_error("Summary should contain 'Phase narrative'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADVANCE DAY — time, season, weather
# ═══════════════════════════════════════════════════════════════════════════════

func test_advance_day_increments() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	var day_before: int = reg.world.get("day", 1)
	reg.advance_day()
	var day_after: int = reg.world.get("day", 1)
	if day_after != day_before + 1:
		push_error("advance_day should increment day by 1, got %d -> %d" % [day_before, day_after])
		return false
	return true


func test_advance_day_cycles_time_of_day() -> bool:
	var reg: NarrativeRegistry = _make_registry()
	reg.world["time_of_day"] = "aube"
	reg.advance_day()
	if reg.world.get("time_of_day", "") != "jour":
		push_error("Time of day should cycle aube -> jour, got: " + reg.world.get("time_of_day", ""))
		return false
	return true
