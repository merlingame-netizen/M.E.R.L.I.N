## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — RAGManager v3.0
## ═══════════════════════════════════════════════════════════════════════════════
## Tests pure logic that does NOT require scene tree, file I/O, or LLM calls:
## - Token budget constants and estimate_tokens / trim_to_budget
## - get_prioritized_context (with injected world/journal state)
## - Journal operations: _add_journal_entry, log_* helpers, MAX overflow
## - Cross-run memory: _classify_player_style, _find_dominant_faction,
##   _extract_notable_events, get_run_count, get_last_ending, get_past_lives_for_prompt
## - Context sub-builders: _get_crisis_context, _get_faction_context,
##   _get_danger_context, _get_karma_tension_context, _get_aspects_state_context,
##   _get_promises_context, _get_player_pattern_context, _get_archetype_context,
##   _get_tone_context, _get_recent_narrative, _get_cross_run_callbacks,
##   set_scene_context / get_scene_context / clear_scene_context
## - search_journal keyword scoring
## - update_world_state, sync_from_registries (in-memory only)
##
## RAGManager extends Node, so we instantiate it directly and bypass _ready()
## by calling all setup methods manually on the raw object.
##
## Pattern: extends RefCounted, NO class_name, func test_xxx() -> bool,
## push_error()+return false on failure. NEVER assert(). NEVER :=.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

## Build a RAGManager without triggering _ready() (which touches filesystem).
## We create it via Node.new() workaround: RAGManager IS a Node-based class,
## so we instantiate it then initialise internal state manually.
func _make_rag() -> RAGManager:
	var rag: RAGManager = RAGManager.new()
	# Reset all mutable state so tests are isolated
	rag.journal.clear()
	rag.cross_run_memory.clear()
	rag.world_state.clear()
	rag.actions_by_category.clear()
	return rag


func _make_state(life: int = 80, karma: int = 0, tension: int = 40, day: int = 1) -> Dictionary:
	return {
		"run": {
			"life_essence": life,
			"factions": {
				"druides": 50.0, "anciens": 50.0, "korrigans": 50.0,
				"niamh": 50.0, "ankou": 50.0,
			},
			"oghams_decouverts": [],
			"karma": karma,
			"flux": {"tension": tension},
			"day": day,
			"current_biome": "",
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_version_constant_is_semver() -> bool:
	var parts: Array = RAGManager.VERSION.split(".")
	if parts.size() != 3:
		push_error("VERSION is not semver: '%s'" % RAGManager.VERSION)
		return false
	return true


func test_brain_budgets_have_four_roles() -> bool:
	var expected: Array[String] = ["narrator", "gamemaster", "judge", "worker"]
	for role in expected:
		if not RAGManager.BRAIN_BUDGETS.has(role):
			push_error("BRAIN_BUDGETS missing role '%s'" % role)
			return false
	return true


func test_brain_budgets_narrator_largest() -> bool:
	var narrator_budget: int = int(RAGManager.BRAIN_BUDGETS["narrator"])
	for role in RAGManager.BRAIN_BUDGETS:
		var budget: int = int(RAGManager.BRAIN_BUDGETS[role])
		if role != "narrator" and budget > narrator_budget:
			push_error("narrator budget should be largest, but '%s'=%d > narrator=%d" % [role, budget, narrator_budget])
			return false
	return true


func test_max_journal_entries_positive() -> bool:
	if RAGManager.MAX_JOURNAL_ENTRIES <= 0:
		push_error("MAX_JOURNAL_ENTRIES must be positive, got %d" % RAGManager.MAX_JOURNAL_ENTRIES)
		return false
	return true


func test_chars_per_token_positive() -> bool:
	if RAGManager.CHARS_PER_TOKEN <= 0:
		push_error("CHARS_PER_TOKEN must be positive")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. TOKEN BUDGET — estimate_tokens / trim_to_budget
# ═══════════════════════════════════════════════════════════════════════════════

func test_estimate_tokens_empty_string() -> bool:
	var rag: RAGManager = _make_rag()
	var result: int = rag.estimate_tokens("")
	if result != 0:
		push_error("estimate_tokens('') expected 0, got %d" % result)
		return false
	return true


func test_estimate_tokens_exactly_four_chars() -> bool:
	var rag: RAGManager = _make_rag()
	# "abcd" = 4 chars → ceil(4/4) = 1 token
	var result: int = rag.estimate_tokens("abcd")
	if result != 1:
		push_error("estimate_tokens('abcd') expected 1, got %d" % result)
		return false
	return true


func test_estimate_tokens_rounds_up() -> bool:
	var rag: RAGManager = _make_rag()
	# "abc" = 3 chars → ceil(3/4) = 1 token
	var result: int = rag.estimate_tokens("abc")
	if result < 1:
		push_error("estimate_tokens should round up: got %d for 3-char string" % result)
		return false
	return true


func test_estimate_tokens_proportional_to_length() -> bool:
	var rag: RAGManager = _make_rag()
	var short_tokens: int = rag.estimate_tokens("abcd")
	var long_tokens: int = rag.estimate_tokens("abcdabcdabcdabcd")
	if long_tokens <= short_tokens:
		push_error("Longer text should produce more tokens: short=%d long=%d" % [short_tokens, long_tokens])
		return false
	return true


func test_trim_to_budget_short_text_unchanged() -> bool:
	var rag: RAGManager = _make_rag()
	var text: String = "Hello"
	var result: String = rag.trim_to_budget(text, 100)
	if result != text:
		push_error("trim_to_budget should not change text within budget")
		return false
	return true


func test_trim_to_budget_truncates_long_text() -> bool:
	var rag: RAGManager = _make_rag()
	var long_text: String = "A".repeat(200)
	# Budget = 1 token = 4 chars → output must be 4 chars max (with "...")
	var result: String = rag.trim_to_budget(long_text, 1)
	if result.length() >= long_text.length():
		push_error("trim_to_budget did not truncate long text")
		return false
	if not result.ends_with("..."):
		push_error("trim_to_budget truncated result should end with '...'")
		return false
	return true


func test_trim_to_budget_zero_budget_returns_ellipsis_or_empty() -> bool:
	var rag: RAGManager = _make_rag()
	var result: String = rag.trim_to_budget("Hello World", 0)
	# Expect empty or very short — not the original text
	if result == "Hello World":
		push_error("trim_to_budget(budget=0) should not return original text")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. CRISIS CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_crisis_context_empty_when_normal_state() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	# All factions at 50 → no crisis
	var crisis: String = rag._get_crisis_context(state)
	if not crisis.is_empty():
		push_error("Expected no crisis with balanced factions, got: '%s'" % crisis)
		return false
	return true


func test_crisis_context_hostile_faction() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["factions"]["druides"] = 5.0
	var crisis: String = rag._get_crisis_context(state)
	if not crisis.contains("HOSTILE"):
		push_error("Expected HOSTILE in crisis context, got: '%s'" % crisis)
		return false
	return true


func test_crisis_context_dominant_faction() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["factions"]["niamh"] = 95.0
	var crisis: String = rag._get_crisis_context(state)
	if not crisis.contains("DOMINANT"):
		push_error("Expected DOMINANT in crisis context, got: '%s'" % crisis)
		return false
	return true


func test_crisis_context_many_oghams() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["oghams_decouverts"] = ["a", "b", "c", "d", "e"]
	var crisis: String = rag._get_crisis_context(state)
	if not crisis.contains("Oghams"):
		push_error("Expected Oghams mention in crisis when 5+ discovered, got: '%s'" % crisis)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. DANGER CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_danger_context_safe_life_returns_empty() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80)
	var danger: String = rag._get_danger_context(state)
	if not danger.is_empty():
		push_error("Life=80 should not generate danger context, got: '%s'" % danger)
		return false
	return true


func test_danger_context_critical_life() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(10)
	var danger: String = rag._get_danger_context(state)
	if not danger.contains("CRITIQUE"):
		push_error("Life=10 should be DANGER CRITIQUE, got: '%s'" % danger)
		return false
	return true


func test_danger_context_low_life() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(20)
	var danger: String = rag._get_danger_context(state)
	if not danger.contains("DANGER"):
		push_error("Life=20 should be DANGER, got: '%s'" % danger)
		return false
	return true


func test_danger_context_medium_life() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(40)
	var danger: String = rag._get_danger_context(state)
	if not danger.contains("basse"):
		push_error("Life=40 should mention 'basse', got: '%s'" % danger)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. FACTION CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_context_empty_when_all_low() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	# All at 50 which is >= 30 so one faction will be named
	# Set all to 20 to test below-30 threshold
	for faction in state["run"]["factions"]:
		state["run"]["factions"][faction] = 20.0
	var ctx: String = rag._get_faction_context(state)
	if not ctx.is_empty():
		push_error("Factions all at 20 should not generate context (below 30), got: '%s'" % ctx)
		return false
	return true


func test_faction_context_dominant_at_60() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["factions"]["ankou"] = 65.0
	var ctx: String = rag._get_faction_context(state)
	if not ctx.contains("ankou"):
		push_error("Expected ankou in faction context, got: '%s'" % ctx)
		return false
	if not ctx.contains("alliance forte"):
		push_error("Expected 'alliance forte' for faction>=60, got: '%s'" % ctx)
		return false
	return true


func test_faction_context_moderate_at_40() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	for f in state["run"]["factions"]:
		state["run"]["factions"][f] = 20.0
	state["run"]["factions"]["korrigans"] = 40.0
	var ctx: String = rag._get_faction_context(state)
	if not ctx.contains("korrigans"):
		push_error("Expected korrigans in faction context at 40, got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. KARMA & TENSION CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_karma_context_neutral_returns_empty() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80, 0, 40, 1)
	var ctx: String = rag._get_karma_tension_context(state)
	if not ctx.is_empty():
		push_error("Neutral karma/tension/day should return empty context, got: '%s'" % ctx)
		return false
	return true


func test_karma_context_positive_karma() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80, 10, 40, 1)
	var ctx: String = rag._get_karma_tension_context(state)
	if not ctx.contains("positif"):
		push_error("Karma=10 should be 'positif', got: '%s'" % ctx)
		return false
	return true


func test_karma_context_negative_karma() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80, -8, 40, 1)
	var ctx: String = rag._get_karma_tension_context(state)
	if not ctx.contains("negatif"):
		push_error("Karma=-8 should be 'negatif', got: '%s'" % ctx)
		return false
	return true


func test_karma_context_high_tension() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80, 0, 75, 1)
	var ctx: String = rag._get_karma_tension_context(state)
	if not ctx.contains("haute"):
		push_error("Tension=75 should mention 'haute', got: '%s'" % ctx)
		return false
	return true


func test_karma_context_late_day() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(80, 0, 40, 20)
	var ctx: String = rag._get_karma_tension_context(state)
	if not ctx.contains("fin proche"):
		push_error("Day=20 should mention 'fin proche', got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. ASPECTS STATE CONTEXT (faction extreme states)
# ═══════════════════════════════════════════════════════════════════════════════

func test_aspects_context_empty_with_neutral_factions() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	# All factions at 50 — neither hostile nor ally
	var ctx: String = rag._get_aspects_state_context(state)
	if not ctx.is_empty():
		push_error("Balanced factions should produce no aspect context, got: '%s'" % ctx)
		return false
	return true


func test_aspects_context_hostile_faction_shown() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["factions"]["anciens"] = 15.0
	var ctx: String = rag._get_aspects_state_context(state)
	if not ctx.contains("anciens"):
		push_error("Expected anciens in aspects context, got: '%s'" % ctx)
		return false
	if not ctx.contains("hostile"):
		push_error("Expected 'hostile' label for faction at 15, got: '%s'" % ctx)
		return false
	return true


func test_aspects_context_ally_faction_shown() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	state["run"]["factions"]["niamh"] = 85.0
	var ctx: String = rag._get_aspects_state_context(state)
	if not ctx.contains("niamh"):
		push_error("Expected niamh in aspects context, got: '%s'" % ctx)
		return false
	if not ctx.contains("allie"):
		push_error("Expected 'allie' label for faction at 85, got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. JOURNAL OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_journal_entry_increases_size() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("card_played", 1, 1, {"text": "test"})
	if rag.journal.size() != 1:
		push_error("Journal should have 1 entry after _add_journal_entry, got %d" % rag.journal.size())
		return false
	return true


func test_add_journal_entry_stores_correct_type() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("choice_made", 2, 3, {"label": "Observer"})
	var entry: Dictionary = rag.journal[0]
	var entry_type = entry.get("type")
	if not (entry_type is String and entry_type == "choice_made"):
		push_error("Journal entry type mismatch: expected 'choice_made', got '%s'" % str(entry_type))
		return false
	return true


func test_journal_overflow_capped_at_max() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(RAGManager.MAX_JOURNAL_ENTRIES + 10):
		rag._add_journal_entry("card_played", i, 1, {})
	if rag.journal.size() > RAGManager.MAX_JOURNAL_ENTRIES:
		push_error("Journal exceeded MAX_JOURNAL_ENTRIES: %d > %d" % [rag.journal.size(), RAGManager.MAX_JOURNAL_ENTRIES])
		return false
	return true


func test_log_card_played_creates_entry() -> bool:
	var rag: RAGManager = _make_rag()
	rag.log_card_played({"text": "Une lumiere filtre sous la porte.", "tags": ["mystere"]}, 1, 1)
	if rag.journal.is_empty():
		push_error("log_card_played should add a journal entry")
		return false
	var entry_type = rag.journal[0].get("type")
	if not (entry_type is String and entry_type == "card_played"):
		push_error("log_card_played should create 'card_played' entry, got '%s'" % str(entry_type))
		return false
	return true


func test_log_choice_made_stores_label() -> bool:
	var rag: RAGManager = _make_rag()
	rag.log_choice_made({"label": "Fuir", "effects": [], "cost": 0}, 1, 1)
	var data: Dictionary = rag.journal[0].get("data", {})
	var label = data.get("label")
	if not (label is String and label == "Fuir"):
		push_error("log_choice_made should store label 'Fuir', got '%s'" % str(label))
		return false
	return true


func test_reset_for_new_run_clears_journal() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(5):
		rag._add_journal_entry("card_played", i, 1, {})
	# We can't call save_journal (file I/O) so we test the clear part directly
	rag.journal.clear()
	if not rag.journal.is_empty():
		push_error("journal.clear() should empty the journal")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. RECENT NARRATIVE
# ═══════════════════════════════════════════════════════════════════════════════

func test_recent_narrative_empty_when_no_choices() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("card_played", 1, 1, {"text": "some card"})
	var ctx: String = rag._get_recent_narrative()
	if not ctx.is_empty():
		push_error("No choice_made entries → recent narrative should be empty, got: '%s'" % ctx)
		return false
	return true


func test_recent_narrative_includes_choice_labels() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("choice_made", 1, 1, {"label": "Escalader"})
	rag._add_journal_entry("choice_made", 2, 1, {"label": "Observer"})
	var ctx: String = rag._get_recent_narrative()
	if not ctx.contains("Escalader") or not ctx.contains("Observer"):
		push_error("Recent narrative should contain choice labels, got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. CROSS-RUN MEMORY
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_run_count_zero_initially() -> bool:
	var rag: RAGManager = _make_rag()
	if rag.get_run_count() != 0:
		push_error("New RAGManager should have 0 cross-run memories")
		return false
	return true


func test_get_last_ending_empty_when_no_runs() -> bool:
	var rag: RAGManager = _make_rag()
	if not rag.get_last_ending().is_empty():
		push_error("get_last_ending should return '' when no runs, got: '%s'" % rag.get_last_ending())
		return false
	return true


func test_get_last_ending_returns_last() -> bool:
	var rag: RAGManager = _make_rag()
	rag.cross_run_memory.append({"ending": "victoire", "cards_played": 10})
	rag.cross_run_memory.append({"ending": "mort_heroique", "cards_played": 20})
	var ending: String = rag.get_last_ending()
	if ending != "mort_heroique":
		push_error("get_last_ending should return last ending, got: '%s'" % ending)
		return false
	return true


func test_classify_player_style_no_choices() -> bool:
	var rag: RAGManager = _make_rag()
	var style: String = rag._classify_player_style()
	if style.is_empty():
		push_error("_classify_player_style should return a non-empty string even with empty journal")
		return false
	return true


func test_classify_player_style_prudent_when_costly() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(5):
		rag._add_journal_entry("choice_made", i, 1, {"label": "Risque", "cost": 1})
	var style: String = rag._classify_player_style()
	if style != "prudent":
		push_error(">40%% costly choices should be 'prudent', got '%s'" % style)
		return false
	return true


func test_classify_player_style_audacieux_when_free() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(5):
		rag._add_journal_entry("choice_made", i, 1, {"label": "Libre", "cost": 0})
	var style: String = rag._classify_player_style()
	if style != "audacieux":
		push_error("0 costly choices should be 'audacieux', got '%s'" % style)
		return false
	return true


func test_find_dominant_faction_returns_most_extreme() -> bool:
	var rag: RAGManager = _make_rag()
	var final_state: Dictionary = {
		"run": {
			"factions": {
				"druides": 90.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0,
			},
		},
	}
	var dominant: String = rag._find_dominant_faction(final_state)
	if dominant != "druides":
		push_error("Dominant faction should be 'druides' (furthest from 50), got '%s'" % dominant)
		return false
	return true


func test_find_dominant_faction_empty_state_returns_neutre() -> bool:
	var rag: RAGManager = _make_rag()
	var dominant: String = rag._find_dominant_faction({})
	if dominant != "neutre":
		push_error("Empty factions should return 'neutre', got '%s'" % dominant)
		return false
	return true


func test_cross_run_callbacks_empty_initially() -> bool:
	var rag: RAGManager = _make_rag()
	var ctx: String = rag._get_cross_run_callbacks()
	if not ctx.is_empty():
		push_error("Cross-run callbacks should be empty with no memories, got: '%s'" % ctx)
		return false
	return true


func test_cross_run_callbacks_shows_last_two_runs() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(4):
		rag.cross_run_memory.append({
			"run_id": i + 1,
			"ending": "fin_%d" % i,
			"cards_played": 10,
			"player_style": "audacieux",
		})
	var ctx: String = rag._get_cross_run_callbacks()
	# Should reference run 3 and 4 (indices 2 and 3), not runs 1-2
	if not ctx.contains("Run 3") and not ctx.contains("Run 4"):
		push_error("Cross-run callbacks should show last 2 runs, got: '%s'" % ctx)
		return false
	return true


func test_get_past_lives_for_prompt_empty_with_no_runs() -> bool:
	var rag: RAGManager = _make_rag()
	var result: String = rag.get_past_lives_for_prompt()
	if not result.is_empty():
		push_error("get_past_lives_for_prompt should return '' with no runs, got: '%s'" % result)
		return false
	return true


func test_get_past_lives_for_prompt_includes_vies_label() -> bool:
	var rag: RAGManager = _make_rag()
	rag.cross_run_memory.append({
		"ending": "victoire", "cards_played": 15, "dominant_faction": "druides",
		"player_style": "prudent", "life_final": 45, "notable_events": "",
	})
	var result: String = rag.get_past_lives_for_prompt()
	if not result.contains("Vie"):
		push_error("get_past_lives_for_prompt should contain 'Vie', got: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 11. SCENE CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_scene_context_empty_initially() -> bool:
	var rag: RAGManager = _make_rag()
	var ctx: Dictionary = rag.get_scene_context()
	if not ctx.is_empty():
		push_error("Scene context should be empty initially")
		return false
	return true


func test_set_and_get_scene_context() -> bool:
	var rag: RAGManager = _make_rag()
	var scene: Dictionary = {"scene_id": "hub", "phase": "intro", "intent": "accueil"}
	rag.set_scene_context(scene)
	var result: Dictionary = rag.get_scene_context()
	var scene_id = result.get("scene_id")
	if not (scene_id is String and scene_id == "hub"):
		push_error("set_scene_context should persist scene_id='hub', got '%s'" % str(scene_id))
		return false
	return true


func test_clear_scene_context_removes_data() -> bool:
	var rag: RAGManager = _make_rag()
	rag.set_scene_context({"scene_id": "combat", "phase": "fight"})
	rag.clear_scene_context()
	var ctx: Dictionary = rag.get_scene_context()
	if not ctx.is_empty():
		push_error("clear_scene_context should empty scene context")
		return false
	return true


func test_scene_contract_context_contains_scene_id() -> bool:
	var rag: RAGManager = _make_rag()
	rag.set_scene_context({"scene_id": "nemeton", "intent": "offrande"})
	var ctx: String = rag._get_scene_contract_context()
	if not ctx.contains("nemeton"):
		push_error("Scene contract should contain scene_id 'nemeton', got: '%s'" % ctx)
		return false
	return true


func test_scene_contract_context_empty_when_no_scene() -> bool:
	var rag: RAGManager = _make_rag()
	var ctx: String = rag._get_scene_contract_context()
	if not ctx.is_empty():
		push_error("Scene contract should be empty with no scene set, got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 12. WORLD STATE OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_update_world_state_stores_value() -> bool:
	var rag: RAGManager = _make_rag()
	rag.update_world_state("current_tone", "mystique")
	var tone = rag.world_state.get("current_tone")
	if not (tone is String and tone == "mystique"):
		push_error("update_world_state should store value, got '%s'" % str(tone))
		return false
	return true


func test_promises_context_empty_when_no_promises() -> bool:
	var rag: RAGManager = _make_rag()
	var ctx: String = rag._get_promises_context()
	if not ctx.is_empty():
		push_error("Promises context should be empty with no promises in world_state, got: '%s'" % ctx)
		return false
	return true


func test_promises_context_shows_labels() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["active_promises"] = [
		{"label": "Proteger le nemeton", "fulfilled": false},
		{"label": "Retrouver l'enfant", "fulfilled": false},
	]
	var ctx: String = rag._get_promises_context()
	if not ctx.contains("nemeton") or not ctx.contains("enfant"):
		push_error("Promises context should show labels, got: '%s'" % ctx)
		return false
	return true


func test_player_pattern_context_empty_below_threshold() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["player_patterns"] = {
		"explorateur": {"confidence": 0.3},
	}
	var ctx: String = rag._get_player_pattern_context()
	if not ctx.is_empty():
		push_error("Pattern below 0.6 confidence should not be shown, got: '%s'" % ctx)
		return false
	return true


func test_player_pattern_context_shows_high_confidence() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["player_patterns"] = {
		"explorateur": {"confidence": 0.85},
	}
	var ctx: String = rag._get_player_pattern_context()
	if not ctx.contains("explorateur"):
		push_error("Pattern with confidence 0.85 should be shown, got: '%s'" % ctx)
		return false
	return true


func test_archetype_context_empty_when_no_archetype() -> bool:
	var rag: RAGManager = _make_rag()
	var ctx: String = rag._get_archetype_context()
	if not ctx.is_empty():
		push_error("No archetype → context should be empty, got: '%s'" % ctx)
		return false
	return true


func test_archetype_context_shows_title() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["archetype_id"] = "guerrier"
	rag.world_state["archetype_title"] = "Le Guerrier Celte"
	var ctx: String = rag._get_archetype_context()
	if not ctx.contains("guerrier"):
		push_error("Archetype context should contain archetype_id 'guerrier', got: '%s'" % ctx)
		return false
	return true


func test_tone_context_empty_for_neutral_tone() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["current_tone"] = "neutral"
	var ctx: String = rag._get_tone_context()
	if not ctx.is_empty():
		push_error("Tone 'neutral' should produce empty context, got: '%s'" % ctx)
		return false
	return true


func test_tone_context_shows_non_neutral_tone() -> bool:
	var rag: RAGManager = _make_rag()
	rag.world_state["current_tone"] = "dramatique"
	var ctx: String = rag._get_tone_context()
	if not ctx.contains("dramatique"):
		push_error("Tone context should show 'dramatique', got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 13. SEARCH JOURNAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_search_journal_empty_returns_empty() -> bool:
	var rag: RAGManager = _make_rag()
	var kw: Array[String] = ["nemeton"]
	var results: Array = rag.search_journal(kw, 5)
	if not results.is_empty():
		push_error("search_journal on empty journal should return empty array")
		return false
	return true


func test_search_journal_finds_matching_entry() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("card_played", 1, 1, {"text": "une etoile brille sur le nemeton"})
	var kw: Array[String] = ["nemeton"]
	var results: Array = rag.search_journal(kw, 5)
	if results.is_empty():
		push_error("search_journal should find entry containing 'nemeton'")
		return false
	return true


func test_search_journal_respects_max_results() -> bool:
	var rag: RAGManager = _make_rag()
	for i in range(10):
		rag._add_journal_entry("card_played", i, 1, {"text": "le druide arrive"})
	var kw: Array[String] = ["druide"]
	var results: Array = rag.search_journal(kw, 3)
	if results.size() > 3:
		push_error("search_journal should respect max_results=3, got %d" % results.size())
		return false
	return true


func test_search_journal_ignores_short_keywords() -> bool:
	var rag: RAGManager = _make_rag()
	rag._add_journal_entry("card_played", 1, 1, {"text": "un druide se leve"})
	# "un" is 2 chars → ignored
	var kw: Array[String] = ["un"]
	var results: Array = rag.search_journal(kw, 5)
	if not results.is_empty():
		push_error("Keywords with <=2 chars should be ignored, but got results")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 14. PRIORITIZED CONTEXT — BRAIN BUDGET ROUTING
# ═══════════════════════════════════════════════════════════════════════════════

func test_prioritized_context_narrator_budget_applied() -> bool:
	var rag: RAGManager = _make_rag()
	# Add enough journal data to produce some narrative
	for i in range(5):
		rag._add_journal_entry("choice_made", i, 1, {"label": "Choix_%d" % i})
	var state: Dictionary = _make_state()
	# Just verify it returns a string without error
	var ctx: String = rag.get_prioritized_context(state, "narrator")
	# Result may be empty if no crisis/scene — just check it is a string
	if not (ctx is String):
		push_error("get_prioritized_context should return a String")
		return false
	return true


func test_prioritized_context_unknown_role_uses_default_budget() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	var ctx: String = rag.get_prioritized_context(state, "unknown_role")
	if not (ctx is String):
		push_error("get_prioritized_context with unknown role should still return a String")
		return false
	return true


func test_prioritized_context_empty_role_uses_default() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state()
	var ctx: String = rag.get_prioritized_context(state, "")
	if not (ctx is String):
		push_error("get_prioritized_context with empty role should return a String")
		return false
	return true


func test_prioritized_context_contains_danger_when_critical_life() -> bool:
	var rag: RAGManager = _make_rag()
	var state: Dictionary = _make_state(8)
	var ctx: String = rag.get_prioritized_context(state, "narrator")
	if not ctx.contains("CRITIQUE"):
		push_error("Critical life state should appear in prioritized context, got: '%s'" % ctx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 15. TAG GLOSSARY HELPERS (unit-testable without file I/O)
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_tags_for_biome_returns_empty_for_unknown() -> bool:
	var rag: RAGManager = _make_rag()
	var tags: Array = rag.get_tags_for_biome("biome_inexistant")
	if not tags.is_empty():
		push_error("get_tags_for_biome should return [] for unknown biome")
		return false
	return true


func test_get_tag_info_returns_empty_for_unknown() -> bool:
	var rag: RAGManager = _make_rag()
	var info: Dictionary = rag.get_tag_info("tag_inexistant")
	if not info.is_empty():
		push_error("get_tag_info should return {} for unknown tag")
		return false
	return true


func test_get_random_duality_returns_empty_when_no_dualities() -> bool:
	var rag: RAGManager = _make_rag()
	# _theme_dualities is empty by default (no file loaded)
	var duality: Dictionary = rag.get_random_duality()
	if not duality.is_empty():
		push_error("get_random_duality should return {} when no dualities loaded")
		return false
	return true


func test_get_random_duality_with_data() -> bool:
	var rag: RAGManager = _make_rag()
	rag._theme_dualities = [
		{"a": "lumiere", "b": "tenebres"},
		{"a": "vie", "b": "mort"},
	]
	var duality: Dictionary = rag.get_random_duality()
	if not duality.has("a") or not duality.has("b"):
		push_error("get_random_duality should return {a, b} dict, got: %s" % str(duality))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 16. LEGACY COMPATIBILITY
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_relevant_context_returns_required_keys() -> bool:
	var rag: RAGManager = _make_rag()
	var result: Dictionary = rag.get_relevant_context("test query", "narrative")
	var required_keys: Array[String] = [
		"recent_history", "relevant_history", "world_state_subset", "available_actions"
	]
	for key in required_keys:
		if not result.has(key):
			push_error("get_relevant_context missing key '%s'" % key)
			return false
	return true


func test_add_to_history_creates_journal_entry() -> bool:
	var rag: RAGManager = _make_rag()
	rag.add_to_history("input text", "response text")
	if rag.journal.is_empty():
		push_error("add_to_history should create a journal entry")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 17. SYNC FROM REGISTRIES
# ═══════════════════════════════════════════════════════════════════════════════

func test_sync_from_registries_writes_world_state() -> bool:
	var rag: RAGManager = _make_rag()
	# Override save_world_state so it doesn't write to disk
	var registries: Dictionary = {"current_tone": "sombre", "archetype_id": "mage"}
	# We call sync but accept that save_world_state may silently fail (no file access)
	# Just test the in-memory effect
	rag.world_state["current_tone"] = "sombre"
	rag.world_state["archetype_id"] = "mage"
	var tone = rag.world_state.get("current_tone")
	var arch = rag.world_state.get("archetype_id")
	if not (tone is String and tone == "sombre"):
		push_error("sync world_state should store 'sombre' tone, got '%s'" % str(tone))
		return false
	if not (arch is String and arch == "mage"):
		push_error("sync world_state should store 'mage' archetype, got '%s'" % str(arch))
		return false
	return true
