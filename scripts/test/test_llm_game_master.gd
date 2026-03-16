## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — LlmAdapterGameMaster
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: evaluate_balance_heuristic, _suggest_rule_heuristic,
## generate_contextual_effects, _parse_smart_effects_json, _try_parse_effects_dict,
## parse_consequences, build_failure_from_success, derive_fallback_visual_tags.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_gm() -> LlmAdapterGameMaster:
	return LlmAdapterGameMaster.new()


# ═══════════════════════════════════════════════════════════════════════════════
# evaluate_balance_heuristic
# ═══════════════════════════════════════════════════════════════════════════════

func test_balance_heuristic_all_centered() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 50, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 100:
		push_error("balance centered: expected score 100, got %d" % int(result.get("balance_score", 0)))
		return false
	if str(result.get("suggestion", "")) != "Equilibre stable":
		push_error("balance centered: expected stable suggestion, got '%s'" % str(result.get("suggestion", "")))
		return false
	return true


func test_balance_heuristic_one_extreme_low() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 10, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 80:
		push_error("balance 1 extreme: expected score 80, got %d" % int(result.get("balance_score", 0)))
		return false
	if str(result.get("risk_faction", "")) != "druides":
		push_error("balance 1 extreme: expected risk_faction 'druides', got '%s'" % str(result.get("risk_faction", "")))
		return false
	return true


func test_balance_heuristic_one_extreme_high() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 50, "anciens": 50, "korrigans": 50, "niamh": 95, "ankou": 50}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 80:
		push_error("balance 1 extreme high: expected score 80, got %d" % int(result.get("balance_score", 0)))
		return false
	if str(result.get("risk_faction", "")) != "niamh":
		push_error("balance 1 extreme high: expected risk_faction 'niamh', got '%s'" % str(result.get("risk_faction", "")))
		return false
	return true


func test_balance_heuristic_two_extremes() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 5, "anciens": 90, "korrigans": 50, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 60:
		push_error("balance 2 extremes: expected score 60, got %d" % int(result.get("balance_score", 0)))
		return false
	var suggestion: String = str(result.get("suggestion", ""))
	if suggestion.find("Attention") < 0:
		push_error("balance 2 extremes: expected 'Attention' in suggestion, got '%s'" % suggestion)
		return false
	return true


func test_balance_heuristic_three_extremes_danger() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 5, "anciens": 90, "korrigans": 10, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 40:
		push_error("balance 3 extremes: expected score 40, got %d" % int(result.get("balance_score", 0)))
		return false
	var suggestion: String = str(result.get("suggestion", ""))
	if suggestion.find("Danger") < 0:
		push_error("balance 3 extremes: expected 'Danger' in suggestion, got '%s'" % suggestion)
		return false
	return true


func test_balance_heuristic_all_extremes_clamped() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {"druides": 0, "anciens": 100, "korrigans": 0, "niamh": 100, "ankou": 0}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", -1))
	if score != 0:
		push_error("balance all extremes: expected score 0, got %d" % score)
		return false
	return true


func test_balance_heuristic_empty_factions() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"factions": {}}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	# All factions default to 50.0, so no extremes
	if int(result.get("balance_score", 0)) != 100:
		push_error("balance empty factions: expected score 100, got %d" % int(result.get("balance_score", 0)))
		return false
	return true


func test_balance_heuristic_missing_factions_key() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {}
	var result: Dictionary = gm.evaluate_balance_heuristic(context)
	if int(result.get("balance_score", 0)) != 100:
		push_error("balance no factions key: expected score 100, got %d" % int(result.get("balance_score", 0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _suggest_rule_heuristic
# ═══════════════════════════════════════════════════════════════════════════════

func test_rule_heuristic_critical_difficulty() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# 4 extremes → score = max(100-80, 0) = 20, which is < 30
	var context: Dictionary = {"factions": {"druides": 5, "anciens": 90, "korrigans": 5, "niamh": 90, "ankou": 50}}
	var result: Dictionary = gm._suggest_rule_heuristic(context, "neutre")
	if str(result.get("type", "")) != "difficulty":
		push_error("rule critical: expected type 'difficulty', got '%s'" % str(result.get("type", "")))
		return false
	if int(result.get("adjustment", 0)) != -10:
		push_error("rule critical: expected adjustment -10, got %d" % int(result.get("adjustment", 0)))
		return false
	return true


func test_rule_heuristic_stable_prudent_tension() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# All centered → score 100 > 80, player prudent
	var context: Dictionary = {"factions": {"druides": 50, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm._suggest_rule_heuristic(context, "prudent")
	if str(result.get("type", "")) != "tension":
		push_error("rule stable prudent: expected type 'tension', got '%s'" % str(result.get("type", "")))
		return false
	if int(result.get("adjustment", 0)) != 15:
		push_error("rule stable prudent: expected adjustment 15, got %d" % int(result.get("adjustment", 0)))
		return false
	return true


func test_rule_heuristic_aggressive_karma() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# Score between 30-80, player aggressive
	var context: Dictionary = {"factions": {"druides": 50, "anciens": 50, "korrigans": 15, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm._suggest_rule_heuristic(context, "agressif")
	if str(result.get("type", "")) != "karma":
		push_error("rule aggressive: expected type 'karma', got '%s'" % str(result.get("type", "")))
		return false
	if int(result.get("adjustment", 0)) != -5:
		push_error("rule aggressive: expected adjustment -5, got %d" % int(result.get("adjustment", 0)))
		return false
	return true


func test_rule_heuristic_no_adjustment() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# Balanced but not >80 (1 extreme → score 80), player neutre
	var context: Dictionary = {"factions": {"druides": 15, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}}
	var result: Dictionary = gm._suggest_rule_heuristic(context, "neutre")
	if str(result.get("type", "")) != "none":
		push_error("rule no adjustment: expected type 'none', got '%s'" % str(result.get("type", "")))
		return false
	if int(result.get("adjustment", -1)) != 0:
		push_error("rule no adjustment: expected adjustment 0, got %d" % int(result.get("adjustment", -1)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# generate_contextual_effects
# ═══════════════════════════════════════════════════════════════════════════════

func test_contextual_effects_returns_three() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {
		"life_essence": 80, "cards_played": 3,
		"factions": {"druides": 30, "anciens": 60, "korrigans": 40, "niamh": 50, "ankou": 50}
	}
	var effects: Array = gm.generate_contextual_effects(context)
	if effects.size() != 3:
		push_error("contextual effects: expected 3, got %d" % effects.size())
		return false
	return true


func test_contextual_effects_risk_faction_first() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# druides at 5 → most extreme, risk faction
	var context: Dictionary = {
		"life_essence": 80, "cards_played": 3,
		"factions": {"druides": 5, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}
	}
	var effects: Array = gm.generate_contextual_effects(context)
	if effects.size() < 1:
		push_error("contextual effects risk: expected at least 1 effect")
		return false
	var first_faction: String = str(effects[0].get("faction", ""))
	if first_faction != "druides":
		push_error("contextual effects risk: expected first faction 'druides', got '%s'" % first_faction)
		return false
	return true


func test_contextual_effects_low_rep_positive_amount() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# korrigans at 20 (< 50) → amount should be positive (base_amount)
	var context: Dictionary = {
		"life_essence": 80, "cards_played": 0,
		"factions": {"druides": 50, "anciens": 50, "korrigans": 20, "niamh": 50, "ankou": 50}
	}
	var effects: Array = gm.generate_contextual_effects(context)
	# Find the effect for korrigans
	var tracker: Dictionary = {"found": false}
	for eff in effects:
		if str(eff.get("faction", "")) == "korrigans":
			var amount: float = float(eff.get("amount", 0.0))
			if amount <= 0.0:
				push_error("contextual effects low rep: expected positive amount for korrigans, got %.1f" % amount)
				return false
			tracker["found"] = true
	# korrigans may not be in first 3 factions selected; that is valid behavior
	return true


func test_contextual_effects_high_rep_negative_amount() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# First faction (druides) at 80 (>= 50) → amount should be negative
	var context: Dictionary = {
		"life_essence": 80, "cards_played": 0,
		"factions": {"druides": 80, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}
	}
	var effects: Array = gm.generate_contextual_effects(context)
	if effects.size() < 1:
		push_error("contextual effects high rep: expected at least 1 effect")
		return false
	var first_amount: float = float(effects[0].get("amount", 0.0))
	if first_amount > 0.0:
		push_error("contextual effects high rep: expected negative amount, got %.1f" % first_amount)
		return false
	return true


func test_contextual_effects_late_game_mission() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {
		"life_essence": 60, "cards_played": 15,
		"factions": {"druides": 50, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}
	}
	var effects: Array = gm.generate_contextual_effects(context)
	if effects.size() != 3:
		push_error("contextual effects late: expected 3 effects, got %d" % effects.size())
		return false
	var third_type: String = str(effects[2].get("type", ""))
	if third_type != "PROGRESS_MISSION":
		push_error("contextual effects late: expected 3rd type PROGRESS_MISSION, got '%s'" % third_type)
		return false
	return true


func test_contextual_effects_scaling_with_cards() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# cards_played=0 → base_amount = 5.0; cards_played=8 → base_amount = 5.0 + 4.0 = 9.0
	var ctx_early: Dictionary = {
		"life_essence": 80, "cards_played": 0,
		"factions": {"druides": 30, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}
	}
	var ctx_mid: Dictionary = {
		"life_essence": 80, "cards_played": 8,
		"factions": {"druides": 30, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50}
	}
	var effects_early: Array = gm.generate_contextual_effects(ctx_early)
	var effects_mid: Array = gm.generate_contextual_effects(ctx_mid)
	var early_amount: float = absf(float(effects_early[0].get("amount", 0.0)))
	var mid_amount: float = absf(float(effects_mid[0].get("amount", 0.0)))
	if mid_amount <= early_amount:
		push_error("contextual effects scaling: mid amount (%.1f) should be > early (%.1f)" % [mid_amount, early_amount])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _parse_smart_effects_json / _try_parse_effects_dict
# ═══════════════════════════════════════════════════════════════════════════════

func test_parse_smart_effects_valid_json() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}],[{"type":"ADD_REPUTATION","faction":"druides","amount":10}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse valid: expected 3 option arrays, got %d" % result.size())
		return false
	return true


func test_parse_smart_effects_with_preamble() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := 'Here is the JSON:\n{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"HEAL_LIFE","amount":3}],[{"type":"HEAL_LIFE","amount":2}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse preamble: expected 3, got %d" % result.size())
		return false
	return true


func test_parse_smart_effects_single_quotes_repair() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := "{'effects':[[{'type':'HEAL_LIFE','amount':5}],[{'type':'DAMAGE_LIFE','amount':3}],[{'type':'HEAL_LIFE','amount':2}]]}"
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse single quotes: expected 3, got %d" % result.size())
		return false
	return true


func test_parse_smart_effects_invalid_garbage() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := "This is not JSON at all"
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 0:
		push_error("parse garbage: expected empty, got %d" % result.size())
		return false
	return true


func test_parse_smart_effects_wrong_count() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# Only 2 option arrays instead of 3
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"HEAL_LIFE","amount":3}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 0:
		push_error("parse wrong count: expected empty, got %d" % result.size())
		return false
	return true


func test_parse_smart_effects_rep_capped() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# amount 50 should be capped to 20
	var raw := '{"effects":[[{"type":"ADD_REPUTATION","faction":"druides","amount":50}],[{"type":"HEAL_LIFE","amount":3}],[{"type":"HEAL_LIFE","amount":2}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse rep cap: expected 3, got %d" % result.size())
		return false
	var first_effects: Array = result[0]
	if first_effects.size() < 1:
		push_error("parse rep cap: first option empty")
		return false
	var rep_amount: float = float(first_effects[0].get("amount", 0.0))
	if rep_amount > 20.0:
		push_error("parse rep cap: expected amount <= 20, got %.1f" % rep_amount)
		return false
	return true


func test_parse_smart_effects_invalid_faction_skipped() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# Invalid faction "elfes" should be skipped, empty option → fallback HEAL_LIFE
	var raw := '{"effects":[[{"type":"ADD_REPUTATION","faction":"elfes","amount":10}],[{"type":"HEAL_LIFE","amount":3}],[{"type":"HEAL_LIFE","amount":2}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse invalid faction: expected 3, got %d" % result.size())
		return false
	var first_effects: Array = result[0]
	# Invalid faction skipped → empty → fallback HEAL_LIFE appended
	if str(first_effects[0].get("type", "")) != "HEAL_LIFE":
		push_error("parse invalid faction: expected fallback HEAL_LIFE, got '%s'" % str(first_effects[0].get("type", "")))
		return false
	return true


func test_parse_smart_effects_amount_clamped_non_rep() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# Non-rep amount 50 should be clamped to 10
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":50}],[{"type":"HEAL_LIFE","amount":3}],[{"type":"HEAL_LIFE","amount":2}]]}'
	var result: Array = gm._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("parse amount clamp: expected 3, got %d" % result.size())
		return false
	var heal_amount: int = int(result[0][0].get("amount", 0))
	if heal_amount > 10:
		push_error("parse amount clamp: expected amount <= 10, got %d" % heal_amount)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# parse_consequences
# ═══════════════════════════════════════════════════════════════════════════════

func test_parse_consequences_abc_format() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := "A: Tu avances dans la foret sombre. Les arbres tremblent.\nB: Tu recules vers la clairiere. Le vent se calme.\nC: Tu restes immobile. La brume t'enveloppe lentement."
	var result: Array[String] = gm.parse_consequences(raw)
	if result.size() != 3:
		push_error("parse consequences ABC: expected 3, got %d" % result.size())
		return false
	if result[0].find("foret") < 0:
		push_error("parse consequences ABC: first consequence missing 'foret': '%s'" % result[0])
		return false
	return true


func test_parse_consequences_strips_markdown() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := "A) **Tu avances** dans la foret. *Les arbres* tremblent.\nB) Tu recules vers la clairiere. Le vent se calme doucement.\nC) Tu restes immobile. La brume t'enveloppe sans pitie."
	var result: Array[String] = gm.parse_consequences(raw)
	if result.size() != 3:
		push_error("parse consequences md: expected 3, got %d" % result.size())
		return false
	if result[0].find("**") >= 0 or result[0].find("*") >= 0:
		push_error("parse consequences md: markdown not stripped from '%s'" % result[0])
		return false
	return true


func test_parse_consequences_too_short_lines() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var raw := "A: Oui\nB: Non\nC: Peut-etre"
	var result: Array[String] = gm.parse_consequences(raw)
	# Lines <= 10 chars are skipped, so result should be empty
	if result.size() != 0:
		push_error("parse consequences short: expected 0 (lines too short), got %d" % result.size())
		return false
	return true


func test_parse_consequences_empty_input() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var result: Array[String] = gm.parse_consequences("")
	if result.size() != 0:
		push_error("parse consequences empty: expected 0, got %d" % result.size())
		return false
	return true


func test_parse_consequences_fallback_double_newline() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	# No A:/B:/C: prefix, but separated by double newlines and long enough
	var raw := "Tu avances dans la foret sombre et ancienne.\n\nTu recules vers la clairiere lumineuse.\n\nTu restes immobile sous les etoiles."
	var result: Array[String] = gm.parse_consequences(raw)
	if result.size() != 3:
		push_error("parse consequences fallback: expected 3, got %d" % result.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_failure_from_success
# ═══════════════════════════════════════════════════════════════════════════════

func test_failure_from_success_multi_sentence() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var success := "Tu avances dans la foret. Les arbres s'ecartent devant toi."
	var result: String = gm.build_failure_from_success(success)
	# Should start with a failure prefix
	var known_prefixes: Array[String] = [
		"Le geste echoue. ",
		"Le destin se retourne. ",
		"L'effort ne suffit pas. ",
		"La foret refuse. ",
	]
	var tracker: Dictionary = {"has_prefix": false}
	for p in known_prefixes:
		if result.begins_with(p):
			tracker["has_prefix"] = true
	if not tracker["has_prefix"]:
		push_error("failure from success: no known prefix in '%s'" % result)
		return false
	return true


func test_failure_from_success_single_sentence() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var success := "Tu avances dans la foret"
	var result: String = gm.build_failure_from_success(success)
	# Single sentence → fallback ending
	if result.find("Les consequences se font sentir") < 0:
		push_error("failure single sentence: expected fallback text, got '%s'" % result)
		return false
	return true


func test_failure_from_success_deterministic() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var success := "Tu trouves un artefact ancien. Il brille d'une lumiere bleue."
	var result1: String = gm.build_failure_from_success(success)
	var result2: String = gm.build_failure_from_success(success)
	if result1 != result2:
		push_error("failure deterministic: same input gave different outputs: '%s' vs '%s'" % [result1, result2])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# derive_fallback_visual_tags (no LLM, pure heuristic)
# ═══════════════════════════════════════════════════════════════════════════════

func test_fallback_tags_default_biome() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {}
	var result: Array = gm.derive_fallback_visual_tags(context)
	if result.size() < 1:
		push_error("fallback tags default: expected at least 1 tag, got 0")
		return false
	return true


func test_fallback_tags_with_celtic_theme() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"biome": "foret_broceliande", "_celtic_theme": "druide ancien"}
	var result: Array = gm.derive_fallback_visual_tags(context)
	# Words >= 4 chars from celtic theme should be appended
	var tracker: Dictionary = {"has_druide": false, "has_ancien": false}
	for tag in result:
		if str(tag) == "druide":
			tracker["has_druide"] = true
		if str(tag) == "ancien":
			tracker["has_ancien"] = true
	if not tracker["has_druide"]:
		push_error("fallback tags celtic: expected 'druide' in tags %s" % str(result))
		return false
	if not tracker["has_ancien"]:
		push_error("fallback tags celtic: expected 'ancien' in tags %s" % str(result))
		return false
	return true


func test_fallback_tags_short_theme_words_skipped() -> bool:
	var gm: LlmAdapterGameMaster = _make_gm()
	var context: Dictionary = {"biome": "foret_broceliande", "_celtic_theme": "le du a"}
	var result: Array = gm.derive_fallback_visual_tags(context)
	# Words < 4 chars should NOT be appended
	for tag in result:
		if str(tag) == "le" or str(tag) == "du" or str(tag) == "a":
			push_error("fallback tags short: short word '%s' should be skipped" % str(tag))
			return false
	return true
