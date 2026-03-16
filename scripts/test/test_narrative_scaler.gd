## ═══════════════════════════════════════════════════════════════════════════════
## Test — NarrativeScaler
## ═══════════════════════════════════════════════════════════════════════════════
## Unit tests for addons/merlin_ai/processors/narrative_scaler.gd
## Covers: default state, tier-from-runs boundaries, set_tier (int path),
##         get_features, get_feature, can_use_feature, is_content_unlocked,
##         should_include_card, filter_card_pool, Merlin depth helpers,
##         get_tier_name, get_tier_description, get_progress_to_next_tier.
## Run via: python tools/cli.py godot test
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name — test runner discovers by filename prefix

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────

var _s: NarrativeScaler

func _init() -> void:
	_s = NarrativeScaler.new()

# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _reset() -> void:
	_s = NarrativeScaler.new()


func _card(type: String, tags: Array, required_tier: int = 0, arc_id: String = "") -> Dictionary:
	var c: Dictionary = {"type": type, "tags": tags, "required_tier": required_tier}
	if arc_id != "":
		c["arc_id"] = arc_id
	return c

# ─────────────────────────────────────────────────────────────────────────────
# T01 — Default state
# ─────────────────────────────────────────────────────────────────────────────

func test_default_tier_is_initiate() -> bool:
	_reset()
	if _s.current_tier != NarrativeScaler.Tier.INITIATE:
		return _fail("Default tier must be INITIATE (0), got %d" % _s.current_tier)
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T02–T11 — set_tier_from_runs boundary tests
# ─────────────────────────────────────────────────────────────────────────────

func test_tier_from_runs_zero_is_initiate() -> bool:
	_reset()
	_s.set_tier_from_runs(0)
	if _s.current_tier != NarrativeScaler.Tier.INITIATE:
		return _fail("0 runs must yield INITIATE, got %d" % _s.current_tier)
	return true


func test_tier_from_runs_five_is_initiate() -> bool:
	_reset()
	_s.set_tier_from_runs(5)
	if _s.current_tier != NarrativeScaler.Tier.INITIATE:
		return _fail("5 runs must yield INITIATE (upper boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_six_is_apprentice() -> bool:
	_reset()
	_s.set_tier_from_runs(6)
	if _s.current_tier != NarrativeScaler.Tier.APPRENTICE:
		return _fail("6 runs must yield APPRENTICE (lower boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_twenty_is_apprentice() -> bool:
	_reset()
	_s.set_tier_from_runs(20)
	if _s.current_tier != NarrativeScaler.Tier.APPRENTICE:
		return _fail("20 runs must yield APPRENTICE (upper boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_twentyone_is_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(21)
	if _s.current_tier != NarrativeScaler.Tier.JOURNEYER:
		return _fail("21 runs must yield JOURNEYER (lower boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_fifty_is_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(50)
	if _s.current_tier != NarrativeScaler.Tier.JOURNEYER:
		return _fail("50 runs must yield JOURNEYER (upper boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_fiftyone_is_adept() -> bool:
	_reset()
	_s.set_tier_from_runs(51)
	if _s.current_tier != NarrativeScaler.Tier.ADEPT:
		return _fail("51 runs must yield ADEPT (lower boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_hundred_is_adept() -> bool:
	_reset()
	_s.set_tier_from_runs(100)
	if _s.current_tier != NarrativeScaler.Tier.ADEPT:
		return _fail("100 runs must yield ADEPT (upper boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_hundredone_is_master() -> bool:
	_reset()
	_s.set_tier_from_runs(101)
	if _s.current_tier != NarrativeScaler.Tier.MASTER:
		return _fail("101 runs must yield MASTER (lower boundary), got %d" % _s.current_tier)
	return true


func test_tier_from_runs_large_value_is_master() -> bool:
	_reset()
	_s.set_tier_from_runs(9999)
	if _s.current_tier != NarrativeScaler.Tier.MASTER:
		return _fail("9999 runs must yield MASTER, got %d" % _s.current_tier)
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T12–T13 — set_tier integer path
# ─────────────────────────────────────────────────────────────────────────────

func test_set_tier_int_adept() -> bool:
	_reset()
	_s.set_tier(NarrativeScaler.Tier.ADEPT)
	if _s.current_tier != NarrativeScaler.Tier.ADEPT:
		return _fail("set_tier(ADEPT) must set ADEPT, got %d" % _s.current_tier)
	return true


func test_set_tier_unknown_non_int_falls_back_to_initiate() -> bool:
	# Non-int value hits the else branch; match fallback (_:) sets INITIATE
	_reset()
	_s.set_tier_from_runs(30)  # advance to JOURNEYER first
	_s.set_tier("invalid")
	if _s.current_tier != NarrativeScaler.Tier.INITIATE:
		return _fail("set_tier with unknown string must default to INITIATE, got %d" % _s.current_tier)
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T14–T16 — get_features / get_feature
# ─────────────────────────────────────────────────────────────────────────────

func test_features_initiate_arc_and_foreshadowing_disabled() -> bool:
	_reset()
	var f: Dictionary = _s.get_features()
	if f["max_arc_length"] != 0:
		return _fail("INITIATE max_arc_length must be 0, got %s" % str(f["max_arc_length"]))
	if f["foreshadowing"] != false:
		return _fail("INITIATE foreshadowing must be false")
	if f["promise_cards"] != false:
		return _fail("INITIATE promise_cards must be false")
	return true


func test_features_master_all_maximised() -> bool:
	_reset()
	_s.set_tier_from_runs(200)
	var f: Dictionary = _s.get_features()
	if f["max_arc_length"] != 10:
		return _fail("MASTER max_arc_length must be 10, got %s" % str(f["max_arc_length"]))
	if f["foreshadowing"] != true:
		return _fail("MASTER foreshadowing must be true")
	if f["merlin_comments_depth"] != 5:
		return _fail("MASTER merlin_comments_depth must be 5")
	if f["max_active_arcs"] != 3:
		return _fail("MASTER max_active_arcs must be 3, got %s" % str(f["max_active_arcs"]))
	return true


func test_get_feature_unknown_key_returns_null() -> bool:
	_reset()
	var val = _s.get_feature("key_that_does_not_exist")
	if val != null:
		return _fail("get_feature for unknown key must return null, got %s" % str(val))
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T17–T19 — can_use_feature
# ─────────────────────────────────────────────────────────────────────────────

func test_can_use_feature_bool_true_at_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(25)
	if not _s.can_use_feature("foreshadowing"):
		return _fail("JOURNEYER must be able to use foreshadowing")
	return true


func test_can_use_feature_numeric_zero_returns_false() -> bool:
	_reset()
	# INITIATE max_arc_length = 0
	if _s.can_use_feature("max_arc_length"):
		return _fail("INITIATE max_arc_length=0 must return false from can_use_feature")
	return true


func test_can_use_feature_unknown_returns_false() -> bool:
	_reset()
	_s.set_tier_from_runs(200)
	if _s.can_use_feature("nonexistent_feature_xyz"):
		return _fail("Unknown feature name must return false from can_use_feature")
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T20–T25 — is_content_unlocked (CONTENT_GATES)
# ─────────────────────────────────────────────────────────────────────────────

func test_basic_cards_always_unlocked_at_initiate() -> bool:
	_reset()
	if not _s.is_content_unlocked("basic_cards"):
		return _fail("basic_cards must be unlocked at INITIATE")
	return true


func test_promise_cards_locked_at_initiate_unlocked_at_apprentice() -> bool:
	_reset()
	if _s.is_content_unlocked("promise_cards"):
		return _fail("promise_cards must be locked at INITIATE")
	_s.set_tier_from_runs(10)
	if not _s.is_content_unlocked("promise_cards"):
		return _fail("promise_cards must be unlocked at APPRENTICE")
	return true


func test_character_arcs_locked_below_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(10)  # APPRENTICE
	if _s.is_content_unlocked("character_arcs"):
		return _fail("character_arcs must be locked at APPRENTICE")
	_s.set_tier_from_runs(25)  # JOURNEYER
	if not _s.is_content_unlocked("character_arcs"):
		return _fail("character_arcs must be unlocked at JOURNEYER")
	return true


func test_deep_lore_locked_at_journeyer_unlocked_at_adept() -> bool:
	_reset()
	_s.set_tier_from_runs(25)  # JOURNEYER
	if _s.is_content_unlocked("deep_lore_cards"):
		return _fail("deep_lore_cards must be locked at JOURNEYER")
	_s.set_tier_from_runs(60)  # ADEPT
	if not _s.is_content_unlocked("deep_lore_cards"):
		return _fail("deep_lore_cards must be unlocked at ADEPT")
	return true


func test_secret_ending_locked_at_adept_unlocked_at_master() -> bool:
	_reset()
	_s.set_tier_from_runs(60)  # ADEPT
	if _s.is_content_unlocked("secret_ending_path"):
		return _fail("secret_ending_path must be locked at ADEPT")
	_s.set_tier_from_runs(200)  # MASTER
	if not _s.is_content_unlocked("secret_ending_path"):
		return _fail("secret_ending_path must be unlocked at MASTER")
	return true


func test_unknown_content_type_defaults_to_initiate_gate() -> bool:
	# CONTENT_GATES.get() returns Tier.INITIATE for unknown keys → always unlocked
	_reset()
	if not _s.is_content_unlocked("completely_unknown_content_type"):
		return _fail("Unknown content type must default to INITIATE gate (unlocked for all tiers)")
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T26–T31 — should_include_card / filter_card_pool
# ─────────────────────────────────────────────────────────────────────────────

func test_plain_narrative_card_included_at_initiate() -> bool:
	_reset()
	if not _s.should_include_card(_card("narrative", [])):
		return _fail("Plain narrative card must be included at INITIATE")
	return true


func test_promise_card_excluded_at_initiate_included_at_apprentice() -> bool:
	_reset()
	if _s.should_include_card(_card("promise", [])):
		return _fail("Promise card must be excluded at INITIATE")
	_s.set_tier_from_runs(10)
	if not _s.should_include_card(_card("promise", [])):
		return _fail("Promise card must be included at APPRENTICE")
	return true


func test_arc_tag_excluded_below_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(10)  # APPRENTICE
	if _s.should_include_card(_card("narrative", ["arc"])):
		return _fail("Card with 'arc' tag must be excluded below JOURNEYER")
	return true


func test_arc_id_field_excluded_below_journeyer() -> bool:
	_reset()
	_s.set_tier_from_runs(10)  # APPRENTICE
	if _s.should_include_card(_card("narrative", [], 0, "arc_druid_001")):
		return _fail("Card with non-empty arc_id must be excluded below JOURNEYER")
	return true


func test_required_tier_field_blocks_card_below_requirement() -> bool:
	_reset()
	var card: Dictionary = _card("narrative", [], NarrativeScaler.Tier.ADEPT)
	if _s.should_include_card(card):
		return _fail("Card with required_tier=ADEPT must be blocked at INITIATE")
	_s.set_tier_from_runs(60)  # ADEPT
	if not _s.should_include_card(card):
		return _fail("Card with required_tier=ADEPT must be included at ADEPT")
	return true


func test_filter_card_pool_correct_count_at_initiate() -> bool:
	_reset()
	var pool: Array = [
		_card("narrative", []),         # pass
		_card("promise", []),           # blocked: promise gate
		_card("narrative", ["arc"]),    # blocked: arc gate
		_card("narrative", ["faction"]),# blocked: faction gate
		_card("narrative", [], 0),      # pass
	]
	var filtered: Array = _s.filter_card_pool(pool)
	if filtered.size() != 2:
		return _fail("INITIATE must keep 2 cards from pool of 5, kept %d" % filtered.size())
	return true


func test_filter_card_pool_empty_input() -> bool:
	_reset()
	_s.set_tier_from_runs(200)
	var filtered: Array = _s.filter_card_pool([])
	if filtered.size() != 0:
		return _fail("Filtering empty pool must return empty array, got size %d" % filtered.size())
	return true


func test_filter_card_pool_all_pass_at_master() -> bool:
	_reset()
	_s.set_tier_from_runs(200)
	var pool: Array = [
		_card("narrative", []),
		_card("promise", []),
		_card("narrative", ["arc"]),
		_card("narrative", ["faction"]),
		_card("narrative", ["deep_lore"]),
	]
	var filtered: Array = _s.filter_card_pool(pool)
	if filtered.size() != pool.size():
		return _fail("MASTER must pass all %d cards, got %d" % [pool.size(), filtered.size()])
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T32–T35 — Narrative complexity convenience methods
# ─────────────────────────────────────────────────────────────────────────────

func test_get_max_arc_length_and_active_arcs_by_tier() -> bool:
	var cases: Array = [
		[NarrativeScaler.Tier.INITIATE, 0, 0],
		[NarrativeScaler.Tier.APPRENTICE, 2, 1],
		[NarrativeScaler.Tier.JOURNEYER, 5, 2],
		[NarrativeScaler.Tier.ADEPT, 7, 2],
		[NarrativeScaler.Tier.MASTER, 10, 3],
	]
	for row in cases:
		_s.set_tier(row[0])
		if _s.get_max_arc_length() != row[1]:
			return _fail("Tier %d: max_arc_length expected %d, got %d" % [row[0], row[1], _s.get_max_arc_length()])
		if _s.get_max_active_arcs() != row[2]:
			return _fail("Tier %d: max_active_arcs expected %d, got %d" % [row[0], row[2], _s.get_max_active_arcs()])
	return true


func test_can_use_foreshadowing_threshold() -> bool:
	_reset()
	if _s.can_use_foreshadowing():
		return _fail("INITIATE must not use foreshadowing")
	_s.set_tier_from_runs(10)  # APPRENTICE
	if _s.can_use_foreshadowing():
		return _fail("APPRENTICE must not use foreshadowing")
	_s.set_tier_from_runs(25)  # JOURNEYER
	if not _s.can_use_foreshadowing():
		return _fail("JOURNEYER must be able to use foreshadowing")
	return true


func test_get_twist_probability_per_tier() -> bool:
	var expected: Dictionary = {
		NarrativeScaler.Tier.INITIATE: 0.0,
		NarrativeScaler.Tier.APPRENTICE: 0.05,
		NarrativeScaler.Tier.JOURNEYER: 0.10,
		NarrativeScaler.Tier.ADEPT: 0.15,
		NarrativeScaler.Tier.MASTER: 0.20,
	}
	for tier in expected:
		_s.set_tier(tier)
		var prob: float = _s.get_twist_probability()
		if abs(prob - expected[tier]) > 0.0001:
			return _fail("Tier %d twist_probability: expected %f, got %f" % [tier, expected[tier], prob])
	return true


func test_get_lore_frequency_per_tier() -> bool:
	var expected: Dictionary = {
		NarrativeScaler.Tier.INITIATE: 0.0,
		NarrativeScaler.Tier.APPRENTICE: 0.02,
		NarrativeScaler.Tier.JOURNEYER: 0.05,
		NarrativeScaler.Tier.ADEPT: 0.08,
		NarrativeScaler.Tier.MASTER: 0.12,
	}
	for tier in expected:
		_s.set_tier(tier)
		var freq: float = _s.get_lore_frequency()
		if abs(freq - expected[tier]) > 0.0001:
			return _fail("Tier %d lore_frequency: expected %f, got %f" % [tier, expected[tier], freq])
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T36–T40 — Merlin depth helpers
# ─────────────────────────────────────────────────────────────────────────────

func test_merlin_comment_depth_all_tiers() -> bool:
	var expected: Dictionary = {
		NarrativeScaler.Tier.INITIATE: 1,
		NarrativeScaler.Tier.APPRENTICE: 2,
		NarrativeScaler.Tier.JOURNEYER: 3,
		NarrativeScaler.Tier.ADEPT: 4,
		NarrativeScaler.Tier.MASTER: 5,
	}
	for tier in expected:
		_s.set_tier(tier)
		var d: int = _s.get_merlin_comment_depth()
		if d != expected[tier]:
			return _fail("Tier %d: merlin_comments_depth expected %d, got %d" % [tier, expected[tier], d])
	return true


func test_can_merlin_reveal_lore_level_within_depth() -> bool:
	_reset()
	_s.set_tier_from_runs(25)  # JOURNEYER depth=3
	if not _s.can_merlin_reveal_lore_level(3):
		return _fail("JOURNEYER (depth=3) must allow lore level 3")
	return true


func test_can_merlin_reveal_lore_level_exceeds_depth() -> bool:
	_reset()
	_s.set_tier_from_runs(25)  # JOURNEYER depth=3
	if _s.can_merlin_reveal_lore_level(4):
		return _fail("JOURNEYER (depth=3) must block lore level 4")
	return true


func test_can_merlin_show_melancholy_threshold() -> bool:
	_reset()
	_s.set_tier_from_runs(25)  # JOURNEYER — below ADEPT
	if _s.can_merlin_show_melancholy():
		return _fail("JOURNEYER must not show melancholy (requires ADEPT)")
	_s.set_tier_from_runs(60)  # ADEPT
	if not _s.can_merlin_show_melancholy():
		return _fail("ADEPT must allow melancholy")
	return true


func test_can_merlin_break_fourth_wall_threshold() -> bool:
	_reset()
	_s.set_tier_from_runs(60)  # ADEPT — below MASTER
	if _s.can_merlin_break_fourth_wall():
		return _fail("ADEPT must not break the fourth wall (requires MASTER)")
	_s.set_tier_from_runs(200)  # MASTER
	if not _s.can_merlin_break_fourth_wall():
		return _fail("MASTER must allow fourth wall breaks")
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T41–T43 — Tier info helpers
# ─────────────────────────────────────────────────────────────────────────────

func test_get_tier_name_all_tiers() -> bool:
	var expected: Dictionary = {
		NarrativeScaler.Tier.INITIATE: "Initie",
		NarrativeScaler.Tier.APPRENTICE: "Apprenti",
		NarrativeScaler.Tier.JOURNEYER: "Voyageur",
		NarrativeScaler.Tier.ADEPT: "Adepte",
		NarrativeScaler.Tier.MASTER: "Maitre",
	}
	for tier in expected:
		_s.set_tier(tier)
		var name_str: String = _s.get_tier_name()
		if name_str != expected[tier]:
			return _fail("Tier %d name: expected '%s', got '%s'" % [tier, expected[tier], name_str])
	return true


func test_get_tier_description_non_empty_all_tiers() -> bool:
	for tier in [
		NarrativeScaler.Tier.INITIATE,
		NarrativeScaler.Tier.APPRENTICE,
		NarrativeScaler.Tier.JOURNEYER,
		NarrativeScaler.Tier.ADEPT,
		NarrativeScaler.Tier.MASTER,
	]:
		_s.set_tier(tier)
		var desc: String = _s.get_tier_description()
		if desc.is_empty():
			return _fail("Tier %d must have a non-empty description" % tier)
	return true


func test_get_tier_name_never_returns_inconnu() -> bool:
	for tier in [
		NarrativeScaler.Tier.INITIATE,
		NarrativeScaler.Tier.APPRENTICE,
		NarrativeScaler.Tier.JOURNEYER,
		NarrativeScaler.Tier.ADEPT,
		NarrativeScaler.Tier.MASTER,
	]:
		_s.set_tier(tier)
		if _s.get_tier_name() == "Inconnu":
			return _fail("Tier %d must not return 'Inconnu'" % tier)
	return true

# ─────────────────────────────────────────────────────────────────────────────
# T44–T47 — get_progress_to_next_tier
# ─────────────────────────────────────────────────────────────────────────────

func test_progress_result_has_required_keys() -> bool:
	_reset()
	var result: Dictionary = _s.get_progress_to_next_tier(3)
	for key in ["next_tier", "progress", "runs_needed"]:
		if not result.has(key):
			return _fail("get_progress_to_next_tier result missing key '%s'" % key)
	return true


func test_progress_zero_runs_to_apprenti() -> bool:
	_reset()
	var result: Dictionary = _s.get_progress_to_next_tier(0)
	if result["next_tier"] != "Apprenti":
		return _fail("0 runs: next_tier must be 'Apprenti', got '%s'" % result["next_tier"])
	if result["runs_needed"] != 5:
		return _fail("0 runs: runs_needed must be 5, got %d" % result["runs_needed"])
	if abs(float(result["progress"]) - 0.0) > 0.001:
		return _fail("0 runs: progress must be 0.0, got %f" % float(result["progress"]))
	return true


func test_progress_midpoint_initiate_range() -> bool:
	# runs=3 out of 0-5 → prev=0, threshold=5, progress=3/5=0.6, runs_needed=2
	_reset()
	var result: Dictionary = _s.get_progress_to_next_tier(3)
	if result["runs_needed"] != 2:
		return _fail("3 runs: runs_needed must be 2, got %d" % result["runs_needed"])
	var expected_progress: float = 3.0 / 5.0
	var actual_progress: float = float(result["progress"])
	if abs(actual_progress - expected_progress) > 0.001:
		return _fail("3 runs: progress must be ~0.6, got %f" % actual_progress)
	return true


func test_progress_at_master_returns_maximum() -> bool:
	_reset()
	var result: Dictionary = _s.get_progress_to_next_tier(9999)
	if result["next_tier"] != "Maximum":
		return _fail("9999 runs: next_tier must be 'Maximum', got '%s'" % result["next_tier"])
	if result["progress"] != 1.0:
		return _fail("9999 runs: progress must be 1.0, got %f" % float(result["progress"]))
	if result["runs_needed"] != 0:
		return _fail("9999 runs: runs_needed must be 0, got %d" % result["runs_needed"])
	return true
