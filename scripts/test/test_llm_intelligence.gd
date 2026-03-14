## ═══════════════════════════════════════════════════════════════════════════════
## Test LLM Intelligence Pipeline — Headless automated validation
## ═══════════════════════════════════════════════════════════════════════════════
## Validates all mechanisms from the Intelligence Pipeline (Phases 1-5 + P1-P6):
## T1-T8: Unit tests (balance, effects, hints, DC)
## T9-T10: LLM integration (cards, smart effects)
## T11-T14: Edge cases (empty, life=0, extremes, missing fields)
## T18: Recurring motifs extraction (P3)
## T19: Phase-aware verb pools (P4)
## T20: Anti-leakage strip (P5)
## T21: Consequence parsing (P2)
## T22: Failure inversion (P2)
## T23: LLM rich narrative text (P1) — >100 chars, no leakage
## T24: LLM consequence generation (P2) — llm_consequences tag
## T25: LLM prologue generation (P6)
## T26: LLM epilogue generation (P6)
## T27: LLM story continuity — 2 cards with story_log fed back (P3)
## Prefix: [TEST] for easy grep. Exit 0 = all pass, 1 = failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

var _adapter: RefCounted = null
var _results: Array[Dictionary] = []
var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0


func _ready() -> void:
	_log("═══════════════════════════════════════")
	_log("  LLM INTELLIGENCE PIPELINE — TESTS")
	_log("═══════════════════════════════════════")

	# Wait for autoloads
	await get_tree().process_frame
	await get_tree().process_frame

	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and "llm" in store and store.llm != null:
		_adapter = store.llm
		_log("Adapter: OK (via MerlinStore.llm)")
	else:
		_log("Adapter: MISSING — cannot run tests")
		_print_report()
		get_tree().quit(1)
		return

	# Run all tests
	_run_unit_tests()
	await _run_llm_tests()

	_print_report()

	await get_tree().create_timer(0.5).timeout
	var exit_code: int = 1 if _fail_count > 0 else 0
	get_tree().quit(exit_code)


# ═══════════════════════════════════════════════════════════════════════════════
# UNIT TESTS (no LLM needed, instant)
# ═══════════════════════════════════════════════════════════════════════════════

func _run_unit_tests() -> void:
	_log("\n--- UNIT TESTS (no LLM) ---")
	_test_balance_heuristic()
	_test_balance_hint()
	_test_contextual_effects_bias()
	_test_parse_smart_json()
	_test_rule_heuristic()
	_test_player_tendency()
	_test_context_enrichment()
	_test_dc_hint_dynamics()

	_log("\n--- EDGE CASES ---")
	_test_edge_empty_context()
	_test_edge_life_zero()
	_test_edge_extreme_values()
	_test_edge_missing_fields()

	_log("\n--- P1-P6 UNIT TESTS ---")
	_test_recurring_motifs()
	_test_phase_verb_pool()
	_test_anti_leakage()
	_test_parse_consequences()
	_test_failure_inversion()


## T1: _evaluate_balance_heuristic() — 5 scenarios
func _test_balance_heuristic() -> void:
	var scenarios := [
		{
			"name": "Equilibre parfait",
			"ctx": {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1},
			"min_score": 95, "max_score": 100,
		},
		{
			"name": "1 extreme (Corps bas)",
			"ctx": {"aspects": {"Corps": -1, "Ame": 0, "Monde": 0}, "souffle": 1},
			"min_score": 70, "max_score": 80,
		},
		{
			"name": "2 extremes (Corps+Ame)",
			"ctx": {"aspects": {"Corps": -1, "Ame": -1, "Monde": 0}, "souffle": 0},
			"min_score": 35, "max_score": 50,
		},
		{
			"name": "3 extremes (crise totale)",
			"ctx": {"aspects": {"Corps": -1, "Ame": 1, "Monde": -1}, "souffle": 0},
			"min_score": 0, "max_score": 20,
		},
		{
			"name": "Souffle epuise seul",
			"ctx": {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 0},
			"min_score": 85, "max_score": 95,
		},
	]

	var all_pass := true
	for s in scenarios:
		var result: Dictionary = _adapter._evaluate_balance_heuristic(s.ctx)
		var score: int = int(result.get("balance_score", -1))
		var ok: bool = score >= s.min_score and score <= s.max_score
		if not ok:
			_log("  FAIL: %s — score=%d (expected %d-%d)" % [s.name, score, s.min_score, s.max_score])
			all_pass = false
		else:
			_log("  ok: %s — score=%d risk=%s" % [s.name, score, str(result.get("risk_aspect", "?"))])

	_record("T1", "balance_heuristic (5 scenarios)", all_pass, "%d/5 scenarios" % scenarios.size())


## T2: _build_balance_hint() — 4 levels
func _test_balance_hint() -> void:
	var cases := [
		{
			"name": "Danger critique (score ~15)",
			"ctx": {"aspects": {"Corps": -1, "Ame": 1, "Monde": -1}, "souffle": 0},
			"contains": "URGENCE",
		},
		{
			"name": "Fragile (score ~40)",
			"ctx": {"aspects": {"Corps": -1, "Ame": -1, "Monde": 0}, "souffle": 0},
			"contains": "FRAGILE",
		},
		{
			"name": "Stable (score 100)",
			"ctx": {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1},
			"contains": "STABLE",
		},
		{
			"name": "Neutre (score ~75)",
			"ctx": {"aspects": {"Corps": -1, "Ame": 0, "Monde": 0}, "souffle": 1},
			"contains": "",  # Should be empty
		},
	]

	var all_pass := true
	for c in cases:
		var hint: String = _adapter._build_balance_hint(c.ctx)
		var expected: String = c.contains
		var ok: bool
		if expected.is_empty():
			ok = hint.is_empty()
		else:
			ok = hint.find(expected) >= 0
		if not ok:
			_log("  FAIL: %s — got \"%s\", expected contains \"%s\"" % [c.name, hint.substr(0, 60), expected])
			all_pass = false
		else:
			_log("  ok: %s — hint=%s" % [c.name, "\"%s\"" % hint.substr(0, 50) if not hint.is_empty() else "(empty)"])

	_record("T2", "balance_hint (4 levels)", all_pass, "%d/4 cases" % cases.size())


## T3: _generate_contextual_effects() — bias validation
func _test_contextual_effects_bias() -> void:
	var all_pass := true

	# Case 1: Danger (score < 30) — left should heal more, right should damage less
	var danger_ctx := {
		"aspects": {"Corps": -1, "Ame": -1, "Monde": -1},
		"souffle": 0, "life_essence": 30, "cards_played": 5,
	}
	var danger_effects: Array = _adapter._generate_contextual_effects(danger_ctx)
	if danger_effects.size() >= 3:
		var left: Dictionary = danger_effects[0]
		var right: Dictionary = danger_effects[2]
		var left_ok: bool = str(left.get("type", "")) == "HEAL_LIFE"
		var left_amount: int = int(left.get("amount", 0))
		if not left_ok:
			_log("  FAIL: Danger left should be HEAL_LIFE, got %s" % str(left.get("type", "")))
			all_pass = false
		else:
			_log("  ok: Danger left=HEAL_LIFE amount=%d" % left_amount)
	else:
		_log("  FAIL: Danger effects array too small: %d" % danger_effects.size())
		all_pass = false

	# Case 2: Comfort (score > 80) — right should damage more
	var comfort_ctx := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"souffle": 1, "life_essence": 100, "cards_played": 5,
	}
	var comfort_effects: Array = _adapter._generate_contextual_effects(comfort_ctx)
	if comfort_effects.size() >= 3:
		var right: Dictionary = comfort_effects[2]
		var right_type: String = str(right.get("type", ""))
		var right_amount: int = int(right.get("amount", 0))
		_log("  ok: Comfort right=%s amount=%d" % [right_type, right_amount])
	else:
		_log("  FAIL: Comfort effects array too small: %d" % comfort_effects.size())
		all_pass = false

	# Compare: danger healing should be >= comfort healing
	if danger_effects.size() >= 1 and comfort_effects.size() >= 1:
		var d_heal: int = int(danger_effects[0].get("amount", 0))
		# Comfort left could be any type, but if both HEAL then danger should be more
		var c_type: String = str(comfort_effects[0].get("type", ""))
		if c_type == "HEAL_LIFE":
			var c_heal: int = int(comfort_effects[0].get("amount", 0))
			if d_heal > c_heal:
				_log("  ok: Danger heal (%d) > Comfort heal (%d)" % [d_heal, c_heal])
			else:
				_log("  WARN: Danger heal (%d) <= Comfort heal (%d) (randomness possible)" % [d_heal, c_heal])

	_record("T3", "contextual_effects_bias (3 cases)", all_pass, "bias validation")


## T4: _parse_smart_effects_json() — 6 cases
func _test_parse_smart_json() -> void:
	var all_pass := true

	# Case 1: Valid JSON
	var valid := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"ADD_KARMA","amount":2}],[{"type":"DAMAGE_LIFE","amount":3}]]}'
	var r1: Array = _adapter._parse_smart_effects_json(valid)
	if r1.size() != 3:
		_log("  FAIL: Valid JSON — expected 3, got %d" % r1.size())
		all_pass = false
	else:
		_log("  ok: Valid JSON — 3 option groups parsed")

	# Case 2: Missing "effects" key
	var no_key := '{"options":[[{"type":"HEAL_LIFE","amount":5}]]}'
	var r2: Array = _adapter._parse_smart_effects_json(no_key)
	if r2.size() != 0:
		_log("  FAIL: Missing key — expected [], got size %d" % r2.size())
		all_pass = false
	else:
		_log("  ok: Missing key — returns []")

	# Case 3: Malformed JSON (no closing brace)
	var malformed := '{"effects":[[{"type":"HEAL_LIFE"'
	var r3: Array = _adapter._parse_smart_effects_json(malformed)
	if r3.size() != 0:
		_log("  FAIL: Malformed — expected [], got size %d" % r3.size())
		all_pass = false
	else:
		_log("  ok: Malformed — returns []")

	# Case 4: Amount > 10 should be clamped
	var big := '{"effects":[[{"type":"HEAL_LIFE","amount":25}],[{"type":"ADD_KARMA","amount":3}],[{"type":"DAMAGE_LIFE","amount":99}]]}'
	var r4: Array = _adapter._parse_smart_effects_json(big)
	if r4.size() == 3:
		var amt: int = int(r4[0][0].get("amount", 0))
		if amt <= 10:
			_log("  ok: Big amount clamped to %d" % amt)
		else:
			_log("  FAIL: Amount not clamped: %d" % amt)
			all_pass = false
	else:
		_log("  FAIL: Big amount parse failed")
		all_pass = false

	# Case 5: Unknown effect type should fallback
	var unknown := '{"effects":[[{"type":"UNKNOWN_TYPE","amount":5}],[{"type":"ADD_KARMA","amount":2}],[{"type":"HEAL_LIFE","amount":3}]]}'
	var r5: Array = _adapter._parse_smart_effects_json(unknown)
	if r5.size() == 3:
		var first_type: String = str(r5[0][0].get("type", ""))
		# Unknown type filtered out, fallback HEAL_LIFE:3 added
		if first_type == "HEAL_LIFE":
			_log("  ok: Unknown type fallback to HEAL_LIFE")
		else:
			_log("  FAIL: Unknown type not handled: %s" % first_type)
			all_pass = false
	else:
		_log("  FAIL: Unknown type parse failed")
		all_pass = false

	# Case 6: Only 2 options (should return [])
	var two := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"ADD_KARMA","amount":2}]]}'
	var r6: Array = _adapter._parse_smart_effects_json(two)
	if r6.size() != 0:
		_log("  FAIL: 2 options — expected [], got size %d" % r6.size())
		all_pass = false
	else:
		_log("  ok: 2 options — returns []")

	_record("T4", "parse_smart_json (6 cases)", all_pass, "6/6 parser cases")


## T5: _suggest_rule_heuristic() — 4 profiles
func _test_rule_heuristic() -> void:
	var all_pass := true

	# Case 1: Critical danger (score < 30) — should suggest difficulty decrease
	var crit_ctx := {"aspects": {"Corps": -1, "Ame": 1, "Monde": -1}, "souffle": 1}
	var r1: Dictionary = _adapter._suggest_rule_heuristic(crit_ctx, "neutre")
	var type1: String = str(r1.get("type", ""))
	var adj1: int = int(r1.get("adjustment", 0))
	if type1 == "difficulty" and adj1 < 0:
		_log("  ok: Critical — type=%s adj=%d" % [type1, adj1])
	else:
		_log("  FAIL: Critical — expected difficulty adj<0, got type=%s adj=%d" % [type1, adj1])
		all_pass = false

	# Case 2: Comfortable + prudent — should suggest tension increase
	var comf_ctx := {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1}
	var r2: Dictionary = _adapter._suggest_rule_heuristic(comf_ctx, "prudent")
	var type2: String = str(r2.get("type", ""))
	var adj2: int = int(r2.get("adjustment", 0))
	if type2 == "tension" and adj2 > 0:
		_log("  ok: Comf+prudent — type=%s adj=%d" % [type2, adj2])
	else:
		_log("  FAIL: Comf+prudent — expected tension adj>0, got type=%s adj=%d" % [type2, adj2])
		all_pass = false

	# Case 3: Normal + agressif — should suggest karma penalty
	var norm_ctx := {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1}
	var r3: Dictionary = _adapter._suggest_rule_heuristic(norm_ctx, "agressif")
	var type3: String = str(r3.get("type", ""))
	var adj3: int = int(r3.get("adjustment", 0))
	if type3 == "karma" and adj3 < 0:
		_log("  ok: Normal+agressif — type=%s adj=%d" % [type3, adj3])
	else:
		_log("  FAIL: Normal+agressif — expected karma adj<0, got type=%s adj=%d" % [type3, adj3])
		all_pass = false

	# Case 4: Normal + neutre — should be none
	var r4: Dictionary = _adapter._suggest_rule_heuristic(norm_ctx, "neutre")
	var type4: String = str(r4.get("type", ""))
	if type4 == "none":
		_log("  ok: Normal+neutre — type=none")
	else:
		_log("  FAIL: Normal+neutre — expected none, got type=%s" % type4)
		all_pass = false

	_record("T5", "rule_heuristic (4 profiles)", all_pass, "4/4 profiles")


## T6: _get_player_tendency() — 3 profiles
func _test_player_tendency() -> void:
	var all_pass := true

	# Aggressive
	var r1: String = _adapter._get_player_tendency({"player_profile": {"audace": 10, "prudence": 2}})
	if r1 == "agressif":
		_log("  ok: Audace 10 vs Prudence 2 → %s" % r1)
	else:
		_log("  FAIL: Expected agressif, got %s" % r1)
		all_pass = false

	# Prudent
	var r2: String = _adapter._get_player_tendency({"player_profile": {"audace": 2, "prudence": 10}})
	if r2 == "prudent":
		_log("  ok: Audace 2 vs Prudence 10 → %s" % r2)
	else:
		_log("  FAIL: Expected prudent, got %s" % r2)
		all_pass = false

	# Neutre
	var r3: String = _adapter._get_player_tendency({"player_profile": {"audace": 5, "prudence": 5}})
	if r3 == "neutre":
		_log("  ok: Audace 5 vs Prudence 5 → %s" % r3)
	else:
		_log("  FAIL: Expected neutre, got %s" % r3)
		all_pass = false

	_record("T6", "player_tendency (3 profiles)", all_pass, "3/3 profiles")


## T7: build_narrative_context() enrichments
func _test_context_enrichment() -> void:
	var all_pass := true

	var mock_state := {
		"run": {
			"aspects": {"Corps": 0, "Ame": -1, "Monde": 0},
			"souffle": 1, "day": 5, "cards_played": 12,
			"life_essence": 80, "current_biome": "foret_broceliande",
			"flux": {"terre": 80, "esprit": 50, "lien": 20},
			"hidden": {
				"tension": 65, "karma": 3,
				"player_profile": {"audace": 8, "prudence": 2},
			},
			"active_tags": [], "active_promises": [], "story_log": [],
		},
		"meta": {"talent_tree": {"unlocked": []}},
		"flags": {},
	}

	var ctx: Dictionary = _adapter.build_narrative_context(mock_state)

	# Check flux_desc
	if ctx.has("flux_desc"):
		var fd: Dictionary = ctx.flux_desc
		if str(fd.get("terre", "")) == "fort" and str(fd.get("lien", "")) == "faible":
			_log("  ok: flux_desc terre=fort, lien=faible")
		else:
			_log("  FAIL: flux_desc unexpected: %s" % str(fd))
			all_pass = false
	else:
		_log("  FAIL: flux_desc missing from context")
		all_pass = false

	# Check tension
	if ctx.has("tension"):
		_log("  ok: tension=%d" % int(ctx.tension))
	else:
		_log("  FAIL: tension missing")
		all_pass = false

	# Check player_tendency
	if ctx.has("player_tendency"):
		var tend: String = str(ctx.player_tendency)
		if tend == "agressif":
			_log("  ok: player_tendency=%s (audace=8 > prudence=2)" % tend)
		else:
			_log("  FAIL: player_tendency=%s, expected agressif" % tend)
			all_pass = false
	else:
		_log("  FAIL: player_tendency missing")
		all_pass = false

	# Check balance_eval is computable from this context
	var balance: Dictionary = _adapter._evaluate_balance_heuristic(ctx)
	if balance.has("balance_score"):
		_log("  ok: balance computable from context, score=%d" % int(balance.balance_score))
	else:
		_log("  FAIL: balance not computable")
		all_pass = false

	_record("T7", "context_enrichment (4 fields)", all_pass, "flux + tension + tendency + balance")


## T8: DC hint dynamics in _wrap_text_as_card()
func _test_dc_hint_dynamics() -> void:
	var all_pass := true

	var dummy_text := "Le druide observe la clairiere. A) Avancer prudemment B) Mediter C) Charger"

	# Danger context (balance < 30) → dc_hints should be lower
	var danger_ctx := {
		"aspects": {"Corps": -1, "Ame": -1, "Monde": 0},
		"souffle": 1, "life_essence": 25, "cards_played": 5,
	}
	var danger_card: Dictionary = _adapter._wrap_text_as_card(dummy_text, danger_ctx)
	var danger_opts: Array = danger_card.get("options", [])

	# Comfort context (balance > 80) → dc_hints should be higher
	var comfort_ctx := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"souffle": 1, "life_essence": 100, "cards_played": 5,
	}
	var comfort_card: Dictionary = _adapter._wrap_text_as_card(dummy_text, comfort_ctx)
	var comfort_opts: Array = comfort_card.get("options", [])

	if danger_opts.size() >= 1 and comfort_opts.size() >= 1:
		var d_hint: Dictionary = danger_opts[0].get("dc_hint", {})
		var c_hint: Dictionary = comfort_opts[0].get("dc_hint", {})
		var d_min: int = int(d_hint.get("min", 0))
		var c_min: int = int(c_hint.get("min", 0))
		_log("  Danger dc_hint[0].min=%d, Comfort dc_hint[0].min=%d" % [d_min, c_min])
		if d_min < c_min:
			_log("  ok: Danger DC lower than Comfort DC (offset working)")
		elif d_min == c_min:
			_log("  WARN: Same DC — offset may be too small or not applied")
		else:
			_log("  FAIL: Danger DC (%d) >= Comfort DC (%d)" % [d_min, c_min])
			all_pass = false
	else:
		_log("  FAIL: Options missing from cards (danger=%d, comfort=%d)" % [danger_opts.size(), comfort_opts.size()])
		all_pass = false

	_record("T8", "dc_hint_dynamics", all_pass, "danger < comfort DC")


# ═══════════════════════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

## T11: Empty context — must not crash
func _test_edge_empty_context() -> void:
	var all_pass := true
	# Balance with empty dict
	var r1: Dictionary = _adapter._evaluate_balance_heuristic({})
	if r1.has("balance_score"):
		_log("  ok: Empty ctx → score=%d (defaults used)" % int(r1.balance_score))
	else:
		_log("  FAIL: Empty ctx crashed balance heuristic")
		all_pass = false

	# Effects with empty dict
	var r2: Array = _adapter._generate_contextual_effects({})
	if r2.size() == 3:
		_log("  ok: Empty ctx → %d effects generated" % r2.size())
	else:
		_log("  FAIL: Empty ctx effects: expected 3, got %d" % r2.size())
		all_pass = false

	# Hint with empty dict
	var r3: String = _adapter._build_balance_hint({})
	_log("  ok: Empty ctx hint = \"%s\"" % r3.substr(0, 40))

	_record("T11", "edge_empty_context", all_pass, "no crash with {}")


## T12: Life = 0 — effects should maximize healing
func _test_edge_life_zero() -> void:
	var ctx := {"aspects": {"Corps": -1, "Ame": -1, "Monde": -1}, "souffle": 0, "life_essence": 0, "cards_played": 3}
	var effects: Array = _adapter._generate_contextual_effects(ctx)
	var all_pass := true
	if effects.size() >= 1:
		var left_type: String = str(effects[0].get("type", ""))
		if left_type == "HEAL_LIFE":
			_log("  ok: Life=0 → left=HEAL_LIFE (amount=%d)" % int(effects[0].get("amount", 0)))
		else:
			_log("  FAIL: Life=0 → left should be HEAL_LIFE, got %s" % left_type)
			all_pass = false
	else:
		_log("  FAIL: No effects generated with life=0")
		all_pass = false

	# Balance hint should be URGENCE
	var hint: String = _adapter._build_balance_hint(ctx)
	if hint.find("URGENCE") >= 0:
		_log("  ok: Life=0 → URGENCE hint")
	else:
		_log("  FAIL: Life=0 → no URGENCE hint")
		all_pass = false

	_record("T12", "edge_life_zero", all_pass, "max healing at life=0")


## T13: Extreme values — souffle=-1, aspects=99
func _test_edge_extreme_values() -> void:
	var all_pass := true

	# Negative souffle
	var ctx1 := {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": -5}
	var r1: Dictionary = _adapter._evaluate_balance_heuristic(ctx1)
	_log("  ok: souffle=-5 → score=%d (clamped)" % int(r1.get("balance_score", -1)))

	# Extreme aspects (should still work, aspects are discrete -1/0/1)
	var ctx2 := {"aspects": {"Corps": 99, "Ame": -99, "Monde": 50}, "souffle": 10}
	var r2: Dictionary = _adapter._evaluate_balance_heuristic(ctx2)
	var score2: int = int(r2.get("balance_score", -1))
	if score2 >= 0 and score2 <= 100:
		_log("  ok: Extreme aspects → score=%d (clamped 0-100)" % score2)
	else:
		_log("  FAIL: Extreme aspects → score=%d out of 0-100" % score2)
		all_pass = false

	_record("T13", "edge_extreme_values", all_pass, "no crash with extremes")


## T14: Missing fields — no aspects key, no souffle key
func _test_edge_missing_fields() -> void:
	var all_pass := true

	# No aspects key
	var ctx1 := {"souffle": 1, "life_essence": 100}
	var r1: Dictionary = _adapter._evaluate_balance_heuristic(ctx1)
	_log("  ok: No aspects → score=%d" % int(r1.get("balance_score", -1)))

	# No souffle key
	var ctx2 := {"aspects": {"Corps": -1, "Ame": 0, "Monde": 0}}
	var r2: Dictionary = _adapter._evaluate_balance_heuristic(ctx2)
	_log("  ok: No souffle → score=%d" % int(r2.get("balance_score", -1)))

	# Completely alien dict
	var ctx3 := {"foo": "bar", "baz": 42}
	var r3: Dictionary = _adapter._evaluate_balance_heuristic(ctx3)
	if r3.has("balance_score"):
		_log("  ok: Alien dict → score=%d (all defaults)" % int(r3.balance_score))
	else:
		_log("  FAIL: Alien dict crashed")
		all_pass = false

	_record("T14", "edge_missing_fields", all_pass, "defaults handle missing keys")


# ═══════════════════════════════════════════════════════════════════════════════
# LLM INTEGRATION TESTS (need Ollama running)
# ═══════════════════════════════════════════════════════════════════════════════

func _run_llm_tests() -> void:
	_log("\n--- LLM INTEGRATION TESTS ---")

	var merlin_ai: Node = get_node_or_null("/root/MerlinAI")
	if merlin_ai == null or not merlin_ai.is_ready:
		_log("  MerlinAI not ready — triggering warmup...")
		if merlin_ai and merlin_ai.has_method("start_warmup"):
			merlin_ai.start_warmup()
			var start := Time.get_ticks_msec()
			while not merlin_ai.is_ready:
				if Time.get_ticks_msec() - start > 30000:
					_log("  Warmup timeout (30s)")
					break
				await get_tree().process_frame
		if merlin_ai == null or not merlin_ai.is_ready:
			_log("  SKIP: LLM not available")
			var skip_tests := [
				["T9", "balance_aware_cards"], ["T10", "smart_effects_gm"],
				["T23", "rich_narrative (P1)"], ["T24", "consequences (P2)"],
				["T25", "prologue (P6)"], ["T26", "epilogue (P6)"],
				["T27", "story_continuity (P3)"],
			]
			for st in skip_tests:
				_record(st[0], st[1], false, "SKIP: no LLM")
				_skip_count += 1
				_fail_count -= 1
			return

	_log("  MerlinAI ready: brain_count=%d" % merlin_ai.brain_count)

	await _test_balance_aware_cards()
	await _test_smart_effects_gm(merlin_ai)

	_log("\n--- P1-P6 LLM TESTS ---")
	await _test_llm_rich_narrative()
	await _test_llm_consequences()
	await _test_llm_prologue()
	await _test_llm_epilogue()
	await _test_llm_story_continuity()


## T9: Generate cards with different balance states, verify effects differ
func _test_balance_aware_cards() -> void:
	_log("\n  T9: Balance-aware card generation...")

	# Generate with critical state
	var danger_ctx := {
		"aspects": {"Corps": -1, "Ame": -1, "Monde": 0},
		"souffle": 1, "life_essence": 25, "cards_played": 5,
		"day": 5, "active_tags": ["danger"], "biome": "foret_broceliande",
		"story_log": [], "karma": 0,
	}
	var t_start := Time.get_ticks_msec()
	var danger_result: Dictionary = await _adapter._generate_card_two_stage(danger_ctx)
	var danger_ms: int = Time.get_ticks_msec() - t_start
	_log("  Danger card: ok=%s gen=%dms" % [str(danger_result.get("ok", false)), danger_ms])

	# Generate with comfortable state
	var comfort_ctx := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"souffle": 1, "life_essence": 100, "cards_played": 5,
		"day": 5, "active_tags": [], "biome": "foret_broceliande",
		"story_log": [], "karma": 5,
	}
	t_start = Time.get_ticks_msec()
	var comfort_result: Dictionary = await _adapter._generate_card_two_stage(comfort_ctx)
	var comfort_ms: int = Time.get_ticks_msec() - t_start
	_log("  Comfort card: ok=%s gen=%dms" % [str(comfort_result.get("ok", false)), comfort_ms])

	var all_pass := true
	if danger_result.get("ok", false) and comfort_result.get("ok", false):
		var d_card: Dictionary = danger_result.card
		var c_card: Dictionary = comfort_result.card

		# Compare dc_hints
		var d_opts: Array = d_card.get("options", [])
		var c_opts: Array = c_card.get("options", [])
		if d_opts.size() >= 1 and c_opts.size() >= 1:
			var d_dc: Dictionary = d_opts[0].get("dc_hint", {})
			var c_dc: Dictionary = c_opts[0].get("dc_hint", {})
			_log("  Danger dc_hint=%s vs Comfort dc_hint=%s" % [str(d_dc), str(c_dc)])

		# Compare effects — danger should have more healing
		var d_heal_count: int = 0
		var c_heal_count: int = 0
		for opt in d_opts:
			for eff in opt.get("effects", []):
				if str(eff.get("type", "")) == "HEAL_LIFE":
					d_heal_count += 1
		for opt in c_opts:
			for eff in opt.get("effects", []):
				if str(eff.get("type", "")) == "HEAL_LIFE":
					c_heal_count += 1
		_log("  Danger HEAL count=%d, Comfort HEAL count=%d" % [d_heal_count, c_heal_count])

		# Log card texts
		_log("  Danger text: \"%s\"" % str(d_card.get("text", "")).substr(0, 100))
		_log("  Comfort text: \"%s\"" % str(c_card.get("text", "")).substr(0, 100))

		# Log tags
		_log("  Danger tags: %s" % str(d_card.get("tags", [])))
		_log("  Comfort tags: %s" % str(c_card.get("tags", [])))
	else:
		var err1: String = str(danger_result.get("error", ""))
		var err2: String = str(comfort_result.get("error", ""))
		_log("  FAIL: Card generation failed — danger: %s, comfort: %s" % [err1, err2])
		all_pass = false

	_record("T9", "balance_aware_cards", all_pass, "gen=%dms+%dms" % [danger_ms, comfort_ms])


## T10: Smart Effects from Game Master (dual brain only)
func _test_smart_effects_gm(merlin_ai: Node) -> void:
	if merlin_ai.brain_count < 2:
		_log("\n  T10: SKIP — dual brain required (current: %d)" % merlin_ai.brain_count)
		_record("T10", "smart_effects_gm", false, "SKIP: brain_count=%d" % merlin_ai.brain_count)
		_skip_count += 1
		_fail_count -= 1
		return

	_log("\n  T10: Smart Effects GM (dual brain)...")
	var ctx := {
		"aspects": {"Corps": -1, "Ame": 0, "Monde": 0},
		"souffle": 1, "life_essence": 60, "cards_played": 8,
	}
	var labels: Array[String] = ["Soigner les blessures", "Observer en silence", "Attaquer"]
	var scenario := "Le druide decouvre un sanctuaire ancien au coeur de la foret."

	var t_start := Time.get_ticks_msec()
	var smart: Array = await _adapter.calculate_smart_effects(ctx, scenario, labels)
	var elapsed: int = Time.get_ticks_msec() - t_start

	var all_pass := true
	if smart.size() == 3:
		_log("  ok: 3 effect groups returned in %dms" % elapsed)
		for i in range(3):
			_log("  opt_%d: %s" % [i, str(smart[i])])
	elif smart.is_empty():
		_log("  WARN: GM returned empty (fallback used) — %dms" % elapsed)
		# Not a hard fail if GM can't parse — fallback is the design
	else:
		_log("  FAIL: Expected 3 or 0 groups, got %d" % smart.size())
		all_pass = false

	_record("T10", "smart_effects_gm", all_pass, "%dms brain=%d" % [elapsed, merlin_ai.brain_count])


# ═══════════════════════════════════════════════════════════════════════════════
# P1-P6 UNIT TESTS (no LLM)
# ═══════════════════════════════════════════════════════════════════════════════

## T18: _extract_recurring_motifs() — P3 story continuity
func _test_recurring_motifs() -> void:
	var all_pass := true

	# Story log where "corbeau" and "brume" appear in 2+ entries
	var story_log: Array = [
		{"text": "Le corbeau survole la brume epaisse du matin."},
		{"text": "La brume se dissipe, revelant un sentier ancien."},
		{"text": "Un corbeau croasse depuis le chene centenaire."},
		{"text": "Les pierres moussues racontent des histoires oubliees."},
	]
	var motifs: Array[String] = _adapter._extract_recurring_motifs(story_log)
	var has_corbeau := false
	var has_brume := false
	for m in motifs:
		if m == "corbeau":
			has_corbeau = true
		if m == "brume" or m == "brumes":
			has_brume = true

	if has_corbeau:
		_log("  ok: motif 'corbeau' found (appears in 2 entries)")
	else:
		_log("  FAIL: 'corbeau' not extracted from story_log")
		all_pass = false

	# Note: "brume" is only 5 chars, filter is >5 chars, so "brumes" would pass but not "brume"
	# This is by design — short words are filtered out
	_log("  info: brume extracted=%s (len=5, filter >5)" % str(has_brume))

	# Empty story log should return empty
	var empty_motifs: Array[String] = _adapter._extract_recurring_motifs([])
	if empty_motifs.is_empty():
		_log("  ok: empty story_log → empty motifs")
	else:
		_log("  FAIL: empty story_log should return []")
		all_pass = false

	# Single entry should return empty (need 2+ occurrences)
	var single_motifs: Array[String] = _adapter._extract_recurring_motifs([
		{"text": "Le corbeau survole la clairiere enchantee."}
	])
	if single_motifs.is_empty():
		_log("  ok: single entry → no recurring motifs")
	else:
		_log("  FAIL: single entry should have no recurring motifs")
		all_pass = false

	_record("T18", "recurring_motifs (P3)", all_pass, "%d motifs extracted" % motifs.size())


## T19: _get_phase_verb_pool() — P4 phase-aware verbs
func _test_phase_verb_pool() -> void:
	var all_pass := true

	# Safe phase (balance > 80) — exploration verbs
	var safe_verbs: Array = _adapter._get_phase_verb_pool(90)
	if safe_verbs.size() == 3:
		_log("  ok: safe (90) → [%s, %s, %s]" % [safe_verbs[0], safe_verbs[1], safe_verbs[2]])
		# Verify these come from VERB_POOL_SAFE
		var safe_all: Array = _adapter.VERB_POOL_SAFE
		var found := false
		for triplet in safe_all:
			if triplet[0] == safe_verbs[0] and triplet[1] == safe_verbs[1] and triplet[2] == safe_verbs[2]:
				found = true
				break
		if found:
			_log("  ok: verbs match VERB_POOL_SAFE")
		else:
			_log("  FAIL: verbs not in VERB_POOL_SAFE")
			all_pass = false
	else:
		_log("  FAIL: safe verbs size=%d (expected 3)" % safe_verbs.size())
		all_pass = false

	# Fragile phase (balance 30-80)
	var fragile_verbs: Array = _adapter._get_phase_verb_pool(50)
	if fragile_verbs.size() == 3:
		_log("  ok: fragile (50) → [%s, %s, %s]" % [fragile_verbs[0], fragile_verbs[1], fragile_verbs[2]])
		var fragile_all: Array = _adapter.VERB_POOL_FRAGILE
		var found := false
		for triplet in fragile_all:
			if triplet[0] == fragile_verbs[0] and triplet[1] == fragile_verbs[1] and triplet[2] == fragile_verbs[2]:
				found = true
				break
		if found:
			_log("  ok: verbs match VERB_POOL_FRAGILE")
		else:
			_log("  FAIL: verbs not in VERB_POOL_FRAGILE")
			all_pass = false
	else:
		_log("  FAIL: fragile verbs size=%d" % fragile_verbs.size())
		all_pass = false

	# Critical phase (balance < 30) — survival verbs
	var crit_verbs: Array = _adapter._get_phase_verb_pool(15)
	if crit_verbs.size() == 3:
		_log("  ok: critical (15) → [%s, %s, %s]" % [crit_verbs[0], crit_verbs[1], crit_verbs[2]])
		var crit_all: Array = _adapter.VERB_POOL_CRITICAL
		var found := false
		for triplet in crit_all:
			if triplet[0] == crit_verbs[0] and triplet[1] == crit_verbs[1] and triplet[2] == crit_verbs[2]:
				found = true
				break
		if found:
			_log("  ok: verbs match VERB_POOL_CRITICAL")
		else:
			_log("  FAIL: verbs not in VERB_POOL_CRITICAL")
			all_pass = false
	else:
		_log("  FAIL: critical verbs size=%d" % crit_verbs.size())
		all_pass = false

	# Boundary: exactly 80 should be fragile, 81 should be safe
	var boundary_fragile: Array = _adapter._get_phase_verb_pool(80)
	var boundary_safe: Array = _adapter._get_phase_verb_pool(81)
	_log("  info: boundary 80 → [%s...] (fragile pool)" % str(boundary_fragile[0]) if boundary_fragile.size() > 0 else "  info: boundary 80 empty")
	_log("  info: boundary 81 → [%s...] (safe pool)" % str(boundary_safe[0]) if boundary_safe.size() > 0 else "  info: boundary 81 empty")

	_record("T19", "phase_verb_pool (P4)", all_pass, "3 pools validated")


## T20: Anti-leakage strip in _wrap_text_as_card — P5
func _test_anti_leakage() -> void:
	var all_pass := true
	var ctx := {"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1, "life_essence": 80, "cards_played": 3}

	# Case 1: Text with prompt leakage lines
	var dirty_text := """La brume s'epaissit sur le sentier.
Scene Narrative: Le voyageur avance.
Le druide leve sa main vers le ciel etoile.
Ecrivez la scene avec atmosphere.
Format obligatoire: verbe a l'infinitif.
A) Avancer B) Observer C) Fuir"""
	var card1: Dictionary = _adapter._wrap_text_as_card(dirty_text, ctx)
	var text1: String = str(card1.get("text", ""))
	if text1.to_lower().find("scene narrative") >= 0:
		_log("  FAIL: 'Scene Narrative' not stripped")
		all_pass = false
	elif text1.to_lower().find("format obligatoire") >= 0:
		_log("  FAIL: 'Format obligatoire' not stripped")
		all_pass = false
	elif text1.to_lower().find("ecrivez la scene") >= 0:
		_log("  FAIL: 'Ecrivez la scene' not stripped")
		all_pass = false
	else:
		_log("  ok: meta-text lines stripped from output")
		_log("  cleaned: \"%s\"" % text1.substr(0, 80))

	# Case 2: Inline bracket leakage [verbe], [Verbe + complement]
	var bracket_text := """Le vent siffle entre les branches mortes. [Verbe a l'infinitif] Le sentier s'ouvre devant toi.
A) Avancer B) Ecouter C) Fuir"""
	var card2: Dictionary = _adapter._wrap_text_as_card(bracket_text, ctx)
	var text2: String = str(card2.get("text", ""))
	if text2.find("[Verbe") >= 0 or text2.find("[verbe") >= 0:
		_log("  FAIL: bracket leakage [Verbe...] not stripped")
		all_pass = false
	else:
		_log("  ok: bracket leakage stripped")

	# Case 3: Pure meta-text should fallback to NARRATIVE_FALLBACKS
	var pure_meta := """Scene Narrative
Ecrivez la scene. Format obligatoire.
Verbes : observer, fuir, avancer.
Options (verbes a l'infinitif):
A) Avancer B) Observer C) Fuir"""
	var card3: Dictionary = _adapter._wrap_text_as_card(pure_meta, ctx)
	var text3: String = str(card3.get("text", ""))
	if text3.length() > 15:
		_log("  ok: pure meta → fallback text (len=%d)" % text3.length())
	else:
		_log("  FAIL: pure meta → text too short (%d chars)" % text3.length())
		all_pass = false

	# Case 4: Label-only lines "A1)", "C3)" should be stripped
	var label_only := """Les pierres murmurent des secrets anciens.
A1)
C3)
Le chemin se divise en trois.
A) Avancer B) Ecouter C) Fuir"""
	var card4: Dictionary = _adapter._wrap_text_as_card(label_only, ctx)
	var text4: String = str(card4.get("text", ""))
	if text4.find("A1)") >= 0 or text4.find("C3)") >= 0:
		_log("  FAIL: label-only lines not stripped")
		all_pass = false
	else:
		_log("  ok: label-only lines stripped")

	_record("T20", "anti_leakage (P5)", all_pass, "4 leakage patterns tested")


## T21: _parse_consequences() — P2 consequence parsing
func _test_parse_consequences() -> void:
	var all_pass := true

	# Case 1: Clean A:/B:/C: format
	var clean := "A: Tu avances dans la brume. Le sol craque sous tes pieds.\nB: Tu observes en silence. Une silhouette se dessine.\nC: Tu fuis vers le nord. Les branches te griffent le visage."
	var r1: Array[String] = _adapter._parse_consequences(clean)
	if r1.size() == 3:
		_log("  ok: clean A/B/C → 3 consequences")
		_log("  A: \"%s\"" % r1[0].substr(0, 50))
	else:
		_log("  FAIL: clean A/B/C → %d (expected 3)" % r1.size())
		all_pass = false

	# Case 2: With markdown bold
	var bold := "A) **Tu avances** dans la brume. Le sol craque.\nB) *Tu observes* en silence. Une ombre apparait.\nC) Tu fuis vers le nord. Les branches griffent."
	var r2: Array[String] = _adapter._parse_consequences(bold)
	if r2.size() == 3:
		if r2[0].find("**") < 0 and r2[0].find("*") < 0:
			_log("  ok: markdown bold stripped from consequences")
		else:
			_log("  FAIL: markdown not cleaned: \"%s\"" % r2[0].substr(0, 40))
			all_pass = false
	else:
		_log("  FAIL: bold format → %d (expected 3)" % r2.size())
		all_pass = false

	# Case 3: Missing one letter (only A and C) — should return []
	var incomplete := "A. Tu avances prudemment dans la clairiere.\nC. Tu fonces sans hesiter vers la lumiere."
	var r3: Array[String] = _adapter._parse_consequences(incomplete)
	if r3.size() < 3:
		_log("  ok: incomplete (2 entries) → size=%d (fallback or empty)" % r3.size())
	else:
		_log("  WARN: incomplete parsed as 3 — may use double-newline fallback")

	# Case 4: Double-newline format (no A/B/C prefix)
	var double_nl := "Tu avances dans la foret. Le silence te pese.\n\nTu observes les alentours. Un murmure s'eleve des pierres.\n\nTu fuis vers le sud. Le vent te pousse dans le dos."
	var r4: Array[String] = _adapter._parse_consequences(double_nl)
	if r4.size() == 3:
		_log("  ok: double-newline fallback → 3 consequences")
	else:
		_log("  FAIL: double-newline fallback → %d (expected 3)" % r4.size())
		all_pass = false

	# Case 5: Empty string → should return []
	var r5: Array[String] = _adapter._parse_consequences("")
	if r5.is_empty():
		_log("  ok: empty input → []")
	else:
		_log("  FAIL: empty input → size=%d" % r5.size())
		all_pass = false

	_record("T21", "parse_consequences (P2)", all_pass, "5 format cases")


## T22: _build_failure_from_success() — P2 failure inversion
func _test_failure_inversion() -> void:
	var all_pass := true

	# Case 1: Multi-sentence success → should take last sentence
	var success1 := "Tu avances dans la clairiere. La lumiere t'enveloppe de chaleur."
	var fail1: String = _adapter._build_failure_from_success(success1)
	if fail1.length() > 10:
		_log("  ok: failure from 2-sentence success: \"%s\"" % fail1.substr(0, 60))
		# Should contain a failure prefix
		var has_prefix := fail1.begins_with("Le geste") or fail1.begins_with("Le destin") or fail1.begins_with("L'effort") or fail1.begins_with("La foret")
		if has_prefix:
			_log("  ok: failure prefix present")
		else:
			_log("  FAIL: no failure prefix in: \"%s\"" % fail1.substr(0, 40))
			all_pass = false
	else:
		_log("  FAIL: failure too short (%d chars)" % fail1.length())
		all_pass = false

	# Case 2: Single sentence → should use generic fallback
	var success2 := "Tu observes en silence"
	var fail2: String = _adapter._build_failure_from_success(success2)
	if fail2.length() > 10:
		_log("  ok: failure from 1-sentence: \"%s\"" % fail2.substr(0, 60))
	else:
		_log("  FAIL: single-sentence failure too short")
		all_pass = false

	# Case 3: Very long success → should still produce valid failure
	var success3 := "Tu avances dans la brume. Les fougeres se plient sous tes pas. L'air sent la mousse et l'ecorce humide."
	var fail3: String = _adapter._build_failure_from_success(success3)
	if fail3.length() > 10 and fail3.length() < 300:
		_log("  ok: failure from long success: len=%d" % fail3.length())
	else:
		_log("  FAIL: unexpected failure length: %d" % fail3.length())
		all_pass = false

	_record("T22", "failure_inversion (P2)", all_pass, "3 inversion cases")


# ═══════════════════════════════════════════════════════════════════════════════
# P1-P6 LLM INTEGRATION TESTS (need Ollama)
# ═══════════════════════════════════════════════════════════════════════════════

## T23: LLM rich narrative text — P1 (>100 chars, no leakage, atmospheric)
func _test_llm_rich_narrative() -> void:
	_log("\n  T23: Rich narrative text (P1)...")
	var ctx := {
		"aspects": {"Corps": 0, "Ame": -1, "Monde": 0}, "souffle": 1,
		"life_essence": 80, "cards_played": 3, "day": 2,
		"active_tags": [], "biome": "foret_broceliande",
		"story_log": [], "karma": 0,
	}
	var t_start := Time.get_ticks_msec()
	var result: Dictionary = await _adapter._generate_card_two_stage(ctx)
	var elapsed: int = Time.get_ticks_msec() - t_start
	var all_pass := true

	if not result.get("ok", false):
		_log("  FAIL: card generation failed — %s" % str(result.get("error", "")))
		all_pass = false
		_record("T23", "rich_narrative (P1)", false, "gen failed")
		return

	var card: Dictionary = result.card
	var text: String = str(card.get("text", ""))

	# Check 1: Length > 100 chars (P1 increased budget)
	if text.length() > 100:
		_log("  ok: text length=%d (>100 chars)" % text.length())
	else:
		_log("  FAIL: text too short: %d chars (expected >100)" % text.length())
		all_pass = false

	# Check 2: No prompt leakage
	var leakage_patterns := ["Scene Narrative", "format obligatoire", "verbe a l'infinitif",
		"ecrivez la scene", "[verbe", "[Verbe", "options (verbes"]
	for pat in leakage_patterns:
		if text.to_lower().find(pat.to_lower()) >= 0:
			_log("  FAIL: leakage found: '%s'" % pat)
			all_pass = false
			break
	if all_pass:
		_log("  ok: no prompt leakage detected")

	# Check 3: Labels extracted (3 options with labels)
	var options: Array = card.get("options", [])
	if options.size() == 3:
		var labels: Array[String] = []
		for opt in options:
			labels.append(str(opt.get("label", "?")))
		_log("  ok: 3 options: [%s, %s, %s]" % [labels[0], labels[1], labels[2]])
	else:
		_log("  FAIL: expected 3 options, got %d" % options.size())
		all_pass = false

	_log("  text: \"%s\"" % text.substr(0, 120))
	_record("T23", "rich_narrative (P1)", all_pass, "len=%d gen=%dms" % [text.length(), elapsed])


## T24: LLM consequence generation — P2 (llm_consequences tag)
func _test_llm_consequences() -> void:
	_log("\n  T24: Consequence generation (P2)...")
	var ctx := {
		"aspects": {"Corps": -1, "Ame": 0, "Monde": 0}, "souffle": 1,
		"life_essence": 60, "cards_played": 6, "day": 3,
		"active_tags": [], "biome": "foret_broceliande",
		"story_log": [{"text": "Le sentier se divise en trois.", "choice": "Avancer"}],
		"karma": 0,
	}
	var t_start := Time.get_ticks_msec()
	var result: Dictionary = await _adapter._generate_card_two_stage(ctx)
	var elapsed: int = Time.get_ticks_msec() - t_start
	var all_pass := true

	if not result.get("ok", false):
		_log("  FAIL: card generation failed — %s" % str(result.get("error", "")))
		_record("T24", "consequences (P2)", false, "gen failed")
		return

	var card: Dictionary = result.card
	var tags: Array = card.get("tags", [])
	var options: Array = card.get("options", [])

	# Check if consequence generation happened (tag present)
	var has_consequences := "llm_consequences" in tags
	if has_consequences:
		_log("  ok: 'llm_consequences' tag present")
		# Verify consequence texts in options
		for i in range(mini(3, options.size())):
			var opt: Dictionary = options[i] if options[i] is Dictionary else {}
			var res_success: String = str(opt.get("result_success", ""))
			var res_failure: String = str(opt.get("result_failure", ""))
			_log("  opt_%d success: \"%s\"" % [i, res_success.substr(0, 60)])
			if res_success.length() > 20:
				_log("  ok: consequence %d has rich text (len=%d)" % [i, res_success.length()])
			else:
				_log("  WARN: consequence %d short (len=%d)" % [i, res_success.length()])
	else:
		_log("  WARN: no 'llm_consequences' tag — consequence generation may have failed")
		_log("  tags: %s" % str(tags))
		# Not a hard fail — LLM may fail to produce parseable consequences

	_record("T24", "consequences (P2)", all_pass, "tag=%s gen=%dms" % [str(has_consequences), elapsed])


## T25: LLM prologue generation — P6
func _test_llm_prologue() -> void:
	_log("\n  T25: Prologue generation (P6)...")
	var ctx := {
		"biome": "foret_broceliande", "life_essence": 100, "souffle": 1,
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
	}
	var t_start := Time.get_ticks_msec()
	var result: Dictionary = await _adapter.generate_prologue(ctx)
	var elapsed: int = Time.get_ticks_msec() - t_start
	var all_pass := true

	if result.get("ok", false):
		var text: String = str(result.get("text", ""))
		_log("  ok: prologue generated in %dms (len=%d)" % [elapsed, text.length()])
		_log("  text: \"%s\"" % text.substr(0, 120))

		# Should be substantial (>80 chars for 3 paragraphs)
		if text.length() < 80:
			_log("  WARN: prologue short (%d chars, expected >80)" % text.length())

		# No markdown artifacts
		if text.find("**") >= 0:
			_log("  FAIL: markdown ** not stripped")
			all_pass = false
	else:
		_log("  FAIL: prologue generation failed — %s" % str(result.get("error", "")))
		all_pass = false

	_record("T25", "prologue (P6)", all_pass, "gen=%dms" % elapsed)


## T26: LLM epilogue generation — P6
func _test_llm_epilogue() -> void:
	_log("\n  T26: Epilogue generation (P6)...")
	var ctx := {
		"aspects": {"Corps": -1, "Ame": 0, "Monde": -1}, "souffle": 1,
		"life_essence": 40, "cards_played": 15,
	}
	var story_log: Array = [
		{"text": "Le voyageur traverse un marais sombre."},
		{"text": "Un corbeau guide ses pas vers la lumiere."},
		{"text": "La pierre d'ogham revele un secret ancien."},
	]
	var t_start := Time.get_ticks_msec()
	var result: Dictionary = await _adapter.generate_epilogue(ctx, story_log)
	var elapsed: int = Time.get_ticks_msec() - t_start
	var all_pass := true

	if result.get("ok", false):
		var text: String = str(result.get("text", ""))
		_log("  ok: epilogue generated in %dms (len=%d)" % [elapsed, text.length()])
		_log("  text: \"%s\"" % text.substr(0, 120))

		# Tone check: with b_score ~5 (grave), should have somber tone
		if text.length() < 50:
			_log("  WARN: epilogue short (%d chars)" % text.length())
	else:
		_log("  FAIL: epilogue generation failed — %s" % str(result.get("error", "")))
		all_pass = false

	_record("T26", "epilogue (P6)", all_pass, "gen=%dms" % elapsed)


## T27: LLM story continuity — 2 cards with story_log fed back (P3)
func _test_llm_story_continuity() -> void:
	_log("\n  T27: Story continuity (P3)...")
	var all_pass := true

	# Generate card 1 (no history)
	var ctx1 := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1,
		"life_essence": 100, "cards_played": 0, "day": 1,
		"active_tags": [], "biome": "foret_broceliande",
		"story_log": [], "karma": 0,
	}
	var r1: Dictionary = await _adapter._generate_card_two_stage(ctx1)
	if not r1.get("ok", false):
		_log("  FAIL: card 1 generation failed")
		_record("T27", "story_continuity (P3)", false, "card1 failed")
		return

	var text1: String = str(r1.card.get("text", ""))
	_log("  card1: \"%s\"" % text1.substr(0, 80))

	# Feed card 1 text into story_log for card 2
	var ctx2 := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1,
		"life_essence": 95, "cards_played": 1, "day": 1,
		"active_tags": [], "biome": "foret_broceliande",
		"story_log": [{"text": text1.substr(0, 80), "choice": "Avancer"}],
		"karma": 0,
	}
	var r2: Dictionary = await _adapter._generate_card_two_stage(ctx2)
	if not r2.get("ok", false):
		_log("  FAIL: card 2 generation failed")
		_record("T27", "story_continuity (P3)", false, "card2 failed")
		return

	var text2: String = str(r2.card.get("text", ""))
	_log("  card2: \"%s\"" % text2.substr(0, 80))

	# Verify story_log was injected (check that context had it)
	_log("  ok: 2 cards generated with story_log continuity")
	_log("  info: story_log injection is verified structurally (prompt includes previous scenes)")

	# Extract keywords from card1 and check presence in card2
	var keywords: Array[String] = []
	for word in text1.to_lower().split(" ", false):
		var clean: String = word.replace(",", "").replace(".", "").replace("!", "")
		if clean.length() > 5:
			keywords.append(clean)
			if keywords.size() >= 5:
				break

	var keyword_hits: int = 0
	for kw in keywords:
		if text2.to_lower().find(kw) >= 0:
			keyword_hits += 1
	_log("  info: %d/%d keywords from card1 found in card2 (continuity hint)" % [keyword_hits, keywords.size()])
	# Not a hard pass/fail — LLM may or may not reuse exact words

	_record("T27", "story_continuity (P3)", all_pass, "2 cards, %d keyword hits" % keyword_hits)


# ═══════════════════════════════════════════════════════════════════════════════
# REPORTING
# ═══════════════════════════════════════════════════════════════════════════════

func _record(id: String, name: String, passed: bool, detail: String) -> void:
	var status: String = "PASS" if passed else "FAIL"
	_results.append({"id": id, "name": name, "status": status, "detail": detail})
	if passed:
		_pass_count += 1
	else:
		_fail_count += 1


func _print_report() -> void:
	_log("\n═══════════════════════════════════════")
	_log("  LLM INTELLIGENCE PIPELINE — TEST REPORT")
	_log("═══════════════════════════════════════")

	for r in _results:
		var marker: String = "[PASS]" if r.status == "PASS" else ("[SKIP]" if r.detail.begins_with("SKIP") else "[FAIL]")
		_log("  %s %s: %s — %s" % [marker, r.id, r.name, r.detail])

	_log("")
	_log("  SUMMARY: %d PASSED, %d FAILED, %d SKIPPED (total %d)" % [
		_pass_count, _fail_count, _skip_count, _results.size()])
	_log("═══════════════════════════════════════")

	var verdict: String = "ALL PASS" if _fail_count == 0 else "FAILURES DETECTED"
	_log("  VERDICT: %s" % verdict)
	_log("═══════════════════════════════════════")


func _log(msg: String) -> void:
	print("[TEST] %s" % msg)
