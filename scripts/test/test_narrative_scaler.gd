## ═══════════════════════════════════════════════════════════════════════════════
## Test NarrativeScaler — Unit tests for narrative complexity scaling
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: initialization, tier assignment, feature access, card filtering,
##           content gates, Merlin depth, tier info, progress tracking.
## Run via: python tools/cli.py godot test
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name — test runner discovers by filename prefix

# ─── helpers ────────────────────────────────────────────────────────────────

func _make_scaler() -> NarrativeScaler:
	return NarrativeScaler.new()


func _make_card(type: String, tags: Array, required_tier: int = 0, arc_id: String = "") -> Dictionary:
	var c: Dictionary = {
		"type": type,
		"tags": tags,
		"required_tier": required_tier,
	}
	if arc_id != "":
		c["arc_id"] = arc_id
	return c


# ─── T01: default tier is INITIATE ──────────────────────────────────────────

func test_default_tier_is_initiate() -> bool:
	var s: NarrativeScaler = _make_scaler()
	if s.current_tier != NarrativeScaler.Tier.INITIATE:
		push_error("Expected INITIATE (0), got %d" % s.current_tier)
		return false
	return true


# ─── T02: set_tier_from_runs — boundary 0 → INITIATE ───────────────────────

func test_set_tier_from_runs_zero() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(0)
	if s.current_tier != NarrativeScaler.Tier.INITIATE:
		push_error("runs=0 should be INITIATE, got %d" % s.current_tier)
		return false
	return true


# ─── T03: set_tier_from_runs — boundary 5 → INITIATE ───────────────────────

func test_set_tier_from_runs_five() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(5)
	if s.current_tier != NarrativeScaler.Tier.INITIATE:
		push_error("runs=5 should be INITIATE, got %d" % s.current_tier)
		return false
	return true


# ─── T04: set_tier_from_runs — 6 → APPRENTICE ───────────────────────────────

func test_set_tier_from_runs_six() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(6)
	if s.current_tier != NarrativeScaler.Tier.APPRENTICE:
		push_error("runs=6 should be APPRENTICE, got %d" % s.current_tier)
		return false
	return true


# ─── T05: set_tier_from_runs — 21 → JOURNEYER ───────────────────────────────

func test_set_tier_from_runs_journeyer() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(21)
	if s.current_tier != NarrativeScaler.Tier.JOURNEYER:
		push_error("runs=21 should be JOURNEYER, got %d" % s.current_tier)
		return false
	return true


# ─── T06: set_tier_from_runs — 101 → MASTER ─────────────────────────────────

func test_set_tier_from_runs_master() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(101)
	if s.current_tier != NarrativeScaler.Tier.MASTER:
		push_error("runs=101 should be MASTER, got %d" % s.current_tier)
		return false
	return true


# ─── T07: set_tier — accepts int directly ────────────────────────────────────

func test_set_tier_accepts_int() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier(3)  # ADEPT
	if s.current_tier != NarrativeScaler.Tier.ADEPT:
		push_error("set_tier(3) should set ADEPT, got %d" % s.current_tier)
		return false
	return true


# ─── T08: set_tier — unknown int falls back to INITIATE ─────────────────────

func test_set_tier_unknown_falls_back() -> bool:
	# Contract: non-int value with no matching branch → INITIATE via match fallback (_:)
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(10)  # put it in APPRENTICE first so we see it change
	s.set_tier("bad_value")   # String hits the non-int else branch, match _ → INITIATE
	if s.current_tier != NarrativeScaler.Tier.INITIATE:
		push_error("set_tier with unknown non-int should default to INITIATE, got %d" % s.current_tier)
		return false
	return true


# ─── T09: get_features — INITIATE has arc features disabled ─────────────────

func test_initiate_features_disabled() -> bool:
	var s: NarrativeScaler = _make_scaler()
	var f: Dictionary = s.get_features()
	if f["max_arc_length"] != 0:
		push_error("INITIATE max_arc_length should be 0")
		return false
	if f["foreshadowing"] != false:
		push_error("INITIATE foreshadowing should be false")
		return false
	if f["promise_cards"] != false:
		push_error("INITIATE promise_cards should be false")
		return false
	return true


# ─── T10: get_features — MASTER has all features enabled ────────────────────

func test_master_features_all_enabled() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(200)
	var f: Dictionary = s.get_features()
	if f["max_arc_length"] != 10:
		push_error("MASTER max_arc_length should be 10, got %d" % f["max_arc_length"])
		return false
	if f["foreshadowing"] != true:
		push_error("MASTER foreshadowing should be true")
		return false
	if f["merlin_comments_depth"] != 5:
		push_error("MASTER merlin_comments_depth should be 5")
		return false
	return true


# ─── T11: can_use_feature — boolean feature ──────────────────────────────────

func test_can_use_feature_boolean() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(25)  # JOURNEYER
	if not s.can_use_feature("foreshadowing"):
		push_error("JOURNEYER should be able to use foreshadowing")
		return false
	var s2: NarrativeScaler = _make_scaler()
	# INITIATE cannot use foreshadowing
	if s2.can_use_feature("foreshadowing"):
		push_error("INITIATE should NOT be able to use foreshadowing")
		return false
	return true


# ─── T12: can_use_feature — numeric feature (> 0 means true) ────────────────

func test_can_use_feature_numeric() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(10)  # APPRENTICE — max_arc_length = 2
	if not s.can_use_feature("max_arc_length"):
		push_error("APPRENTICE should be able to use max_arc_length (value=2)")
		return false
	var s2: NarrativeScaler = _make_scaler()
	# INITIATE max_arc_length = 0 → false
	if s2.can_use_feature("max_arc_length"):
		push_error("INITIATE max_arc_length=0 should return false from can_use_feature")
		return false
	return true


# ─── T13: can_use_feature — unknown feature returns false ────────────────────

func test_can_use_feature_unknown() -> bool:
	var s: NarrativeScaler = _make_scaler()
	if s.can_use_feature("nonexistent_feature"):
		push_error("Unknown feature should return false")
		return false
	return true


# ─── T14: is_content_unlocked — promise_cards gated at APPRENTICE ────────────

func test_content_gate_promise_cards() -> bool:
	var s: NarrativeScaler = _make_scaler()
	if s.is_content_unlocked("promise_cards"):
		push_error("INITIATE should NOT have promise_cards unlocked")
		return false
	s.set_tier_from_runs(10)  # APPRENTICE
	if not s.is_content_unlocked("promise_cards"):
		push_error("APPRENTICE should have promise_cards unlocked")
		return false
	return true


# ─── T15: is_content_unlocked — secret_ending_path requires MASTER ───────────

func test_content_gate_secret_ending() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(60)  # ADEPT
	if s.is_content_unlocked("secret_ending_path"):
		push_error("ADEPT should NOT have secret_ending_path unlocked")
		return false
	s.set_tier_from_runs(200)  # MASTER
	if not s.is_content_unlocked("secret_ending_path"):
		push_error("MASTER should have secret_ending_path unlocked")
		return false
	return true


# ─── T16: should_include_card — basic narrative card always passes ────────────

func test_should_include_basic_card() -> bool:
	var s: NarrativeScaler = _make_scaler()
	var card: Dictionary = _make_card("narrative", [])
	if not s.should_include_card(card):
		push_error("Basic narrative card should always be included at INITIATE")
		return false
	return true


# ─── T17: should_include_card — promise card blocked at INITIATE ─────────────

func test_should_exclude_promise_card_at_initiate() -> bool:
	var s: NarrativeScaler = _make_scaler()
	var card: Dictionary = _make_card("promise", [])
	if s.should_include_card(card):
		push_error("Promise card should be excluded at INITIATE tier")
		return false
	return true


# ─── T18: should_include_card — faction tag blocked below JOURNEYER ──────────

func test_should_exclude_faction_card_at_apprentice() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(10)  # APPRENTICE
	var card: Dictionary = _make_card("narrative", ["faction"])
	if s.should_include_card(card):
		push_error("Faction card should be excluded at APPRENTICE tier")
		return false
	return true


# ─── T19: should_include_card — required_tier blocks card ────────────────────

func test_should_include_card_respects_required_tier() -> bool:
	var s: NarrativeScaler = _make_scaler()
	# Card requiring ADEPT (3) at INITIATE (0)
	var card: Dictionary = _make_card("narrative", [], NarrativeScaler.Tier.ADEPT)
	if s.should_include_card(card):
		push_error("Card with required_tier=ADEPT should be excluded at INITIATE")
		return false
	s.set_tier_from_runs(60)  # ADEPT
	if not s.should_include_card(card):
		push_error("Card with required_tier=ADEPT should be included at ADEPT")
		return false
	return true


# ─── T20: filter_card_pool — removes ineligible cards ────────────────────────

func test_filter_card_pool() -> bool:
	var s: NarrativeScaler = _make_scaler()
	# INITIATE: basic + arc excluded
	var pool: Array = [
		_make_card("narrative", []),           # included
		_make_card("promise", []),              # excluded (promise gate)
		_make_card("narrative", ["arc"]),       # excluded (arc gate)
		_make_card("narrative", ["faction"]),   # excluded (faction gate)
		_make_card("narrative", [], 0),         # included
	]
	var filtered: Array = s.filter_card_pool(pool)
	if filtered.size() != 2:
		push_error("INITIATE filter should keep 2 cards, kept %d" % filtered.size())
		return false
	return true


# ─── T21: get_merlin_comment_depth — values per tier ─────────────────────────

func test_merlin_comment_depth_by_tier() -> bool:
	var depths: Dictionary = {
		0: 1,   # INITIATE
		6: 2,   # APPRENTICE
		25: 3,  # JOURNEYER
		60: 4,  # ADEPT
		200: 5, # MASTER
	}
	for runs in depths:
		var s: NarrativeScaler = _make_scaler()
		s.set_tier_from_runs(runs)
		var depth: int = s.get_merlin_comment_depth()
		var expected: int = depths[runs]
		if depth != expected:
			push_error("runs=%d: expected depth=%d, got %d" % [runs, expected, depth])
			return false
	return true


# ─── T22: can_merlin_reveal_lore_level — level vs depth ──────────────────────

func test_can_merlin_reveal_lore_level() -> bool:
	var s: NarrativeScaler = _make_scaler()
	s.set_tier_from_runs(25)  # JOURNEYER — depth 3
	if not s.can_merlin_reveal_lore_level(3):
		push_error("JOURNEYER (depth=3) should reveal lore level 3")
		return false
	if s.can_merlin_reveal_lore_level(4):
		push_error("JOURNEYER (depth=3) should NOT reveal lore level 4")
		return false
	return true


# ─── T23: can_merlin_show_melancholy / break_fourth_wall ─────────────────────

func test_merlin_advanced_behaviors() -> bool:
	var s: NarrativeScaler = _make_scaler()
	# JOURNEYER — neither melancholy nor fourth wall
	s.set_tier_from_runs(25)
	if s.can_merlin_show_melancholy():
		push_error("JOURNEYER should NOT show melancholy")
		return false
	if s.can_merlin_break_fourth_wall():
		push_error("JOURNEYER should NOT break fourth wall")
		return false
	# ADEPT — melancholy yes, fourth wall no
	s.set_tier_from_runs(60)
	if not s.can_merlin_show_melancholy():
		push_error("ADEPT should show melancholy")
		return false
	if s.can_merlin_break_fourth_wall():
		push_error("ADEPT should NOT break fourth wall")
		return false
	# MASTER — both
	s.set_tier_from_runs(200)
	if not s.can_merlin_show_melancholy():
		push_error("MASTER should show melancholy")
		return false
	if not s.can_merlin_break_fourth_wall():
		push_error("MASTER should break fourth wall")
		return false
	return true


# ─── T24: get_tier_name / get_tier_description — non-empty strings ───────────

func test_tier_name_and_description() -> bool:
	var runs_map: Array = [0, 6, 25, 60, 200]
	for runs in runs_map:
		var s: NarrativeScaler = _make_scaler()
		s.set_tier_from_runs(runs)
		var name_str: String = s.get_tier_name()
		var desc_str: String = s.get_tier_description()
		if name_str == "" or name_str == "Inconnu":
			push_error("runs=%d: tier name should not be empty/Inconnu, got '%s'" % [runs, name_str])
			return false
		if desc_str == "":
			push_error("runs=%d: tier description should not be empty" % runs)
			return false
	return true


# ─── T25: get_progress_to_next_tier — mid-run progress ───────────────────────

func test_progress_to_next_tier_mid() -> bool:
	var s: NarrativeScaler = _make_scaler()
	# runs=3 → INITIATE, threshold 5. prev=0, progress=3/5=0.6
	var result: Dictionary = s.get_progress_to_next_tier(3)
	if result["runs_needed"] != 2:
		push_error("runs=3 should need 2 more runs, got %d" % result["runs_needed"])
		return false
	if result["next_tier"] != "Apprenti":
		push_error("Next tier from INITIATE should be 'Apprenti', got '%s'" % result["next_tier"])
		return false
	var expected_progress: float = 3.0 / 5.0
	if absf(result["progress"] - expected_progress) > 0.001:
		push_error("Progress should be %.3f, got %.3f" % [expected_progress, result["progress"]])
		return false
	return true


# ─── T26: get_progress_to_next_tier — at MASTER cap ─────────────────────────

func test_progress_to_next_tier_at_master() -> bool:
	var s: NarrativeScaler = _make_scaler()
	var result: Dictionary = s.get_progress_to_next_tier(500)
	if result["next_tier"] != "Maximum":
		push_error("At MASTER, next_tier should be 'Maximum', got '%s'" % result["next_tier"])
		return false
	if result["progress"] != 1.0:
		push_error("At MASTER, progress should be 1.0, got %f" % result["progress"])
		return false
	if result["runs_needed"] != 0:
		push_error("At MASTER, runs_needed should be 0, got %d" % result["runs_needed"])
		return false
	return true
