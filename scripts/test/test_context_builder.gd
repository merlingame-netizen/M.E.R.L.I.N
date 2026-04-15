## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinContextBuilder
## ═══════════════════════════════════════════════════════════════════════════════
## Tests pure logic that does NOT require registry instances, file I/O, or LLM:
## - build_full_context: field extraction from game_state, defaults
## - build_llm_prompt_context: string formatting, heure periods, life danger tiers,
##   faction line, late-day label, session flags, fatigued/recommended themes
## - get_experience_tier: null registry path
## - _trust_tier_name: all tiers (0-3, out-of-range)
## - _calculate_theme_weights: null narrative path
##
## MerlinContextBuilder extends RefCounted, so instantiation is straightforward.
## Registry dependencies are left null (all branches guard with `if registry`).
##
## Pattern: extends RefCounted, NO class_name, func test_xxx() -> bool,
## push_error()+return false on failure. NEVER assert(). NEVER :=.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_builder() -> MerlinContextBuilder:
	var b: MerlinContextBuilder = MerlinContextBuilder.new()
	# All registries remain null — guards in the source handle this safely
	return b


func _make_run(
	life: int = 80,
	day: int = 1,
	cards: int = 0,
	heure: float = 0.3,
	karma: int = 0,
	tension: float = 0.0
) -> Dictionary:
	return {
		"run": {
			"life_essence": life,
			"day": day,
			"cards_played": cards,
			"heure_normalisee": heure,
			"tour": 1,
			"ogham_actif": "",
			"oghams_decouverts": [],
			"factions": {
				"druides": 50, "anciens": 50, "korrigans": 50, "niamh": 50, "ankou": 50,
			},
			"active_promises": [],
			"active_tags": [],
			"hidden": {"karma": karma, "tension": tension},
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. build_full_context — field extraction
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_full_context_returns_dictionary() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run())
	if not (result is Dictionary):
		push_error("build_full_context should return a Dictionary")
		return false
	return true


func test_build_full_context_has_required_keys() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run())
	var required: Array[String] = [
		"tour", "ogham_actif", "oghams_decouverts",
		"factions", "heure_normalisee", "life_essence", "day",
		"cards_played", "active_promises", "active_tags",
		"player", "patterns", "trust", "narrative", "session", "_hidden",
	]
	for key in required:
		if not result.has(key):
			push_error("build_full_context missing key '%s'" % key)
			return false
	return true


func test_build_full_context_life_essence_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run(42))
	var life: int = int(result.get("life_essence", -1))
	if life != 42:
		push_error("build_full_context should extract life_essence=42, got %d" % life)
		return false
	return true


func test_build_full_context_day_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run(80, 7))
	var day: int = int(result.get("day", -1))
	if day != 7:
		push_error("build_full_context should extract day=7, got %d" % day)
		return false
	return true


func test_build_full_context_cards_played_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run(80, 1, 13))
	var cards: int = int(result.get("cards_played", -1))
	if cards != 13:
		push_error("build_full_context should extract cards_played=13, got %d" % cards)
		return false
	return true


func test_build_full_context_heure_normalisee_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.62))
	var heure: float = float(result.get("heure_normalisee", -1.0))
	if abs(heure - 0.62) > 0.001:
		push_error("build_full_context should extract heure_normalisee=0.62, got %.3f" % heure)
		return false
	return true


func test_build_full_context_factions_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["factions"]["druides"] = 75
	var result: Dictionary = b.build_full_context(state)
	var factions: Dictionary = result.get("factions", {})
	if int(factions.get("druides", 0)) != 75:
		push_error("build_full_context should extract factions.druides=75, got %d" % int(factions.get("druides", 0)))
		return false
	return true


func test_build_full_context_hidden_karma_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.3, 7))
	var hidden: Dictionary = result.get("_hidden", {})
	var karma: int = int(hidden.get("karma", -99))
	if karma != 7:
		push_error("build_full_context should extract hidden.karma=7, got %d" % karma)
		return false
	return true


func test_build_full_context_defaults_when_empty_run() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	# Provide an empty game_state — all defaults should apply
	var result: Dictionary = b.build_full_context({})
	var life: int = int(result.get("life_essence", -1))
	if life != 100:
		push_error("Empty state should default life_essence=100, got %d" % life)
		return false
	var day: int = int(result.get("day", -1))
	if day != 1:
		push_error("Empty state should default day=1, got %d" % day)
		return false
	return true


func test_build_full_context_null_registries_return_empty_containers() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run())
	# With null registries, player/patterns/trust/narrative/session should be
	# empty containers (not errors)
	var player = result.get("player")
	if not (player is Dictionary):
		push_error("player should be Dictionary when registry is null, got: %s" % type_string(typeof(player)))
		return false
	var patterns = result.get("patterns")
	if not (patterns is String):
		push_error("patterns should be String when registry is null")
		return false
	return true


func test_build_full_context_oghams_list_extracted() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["oghams_decouverts"] = ["beith", "luis", "nion"]
	var result: Dictionary = b.build_full_context(state)
	var oghams: Array = result.get("oghams_decouverts", [])
	if oghams.size() != 3:
		push_error("oghams_decouverts should have 3 entries, got %d" % oghams.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. build_llm_prompt_context — string output
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_llm_prompt_context_returns_string() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	var result = b.build_llm_prompt_context(full)
	if not (result is String):
		push_error("build_llm_prompt_context should return a String")
		return false
	return true


func test_build_llm_prompt_context_contains_tour() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["tour"] = 5
	var full: Dictionary = b.build_full_context(state)
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Tour: 5"):
		push_error("Prompt context should contain 'Tour: 5', got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_contains_faction_line() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Réputation"):
		push_error("Prompt context should contain 'Réputation' line, got: '%s'" % result)
		return false
	if not result.contains("Druides"):
		push_error("Prompt context should contain 'Druides' faction, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_heure_aube() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.1))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("aube"):
		push_error("heure=0.1 should produce 'aube' period, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_heure_jour() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.35))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("jour"):
		push_error("heure=0.35 should produce 'jour' period, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_heure_crepuscule() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.6))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("crépuscule"):
		push_error("heure=0.6 should produce 'crépuscule' period, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_heure_nuit() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80, 1, 0, 0.9))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("nuit"):
		push_error("heure=0.9 should produce 'nuit' period, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_life_critical() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(10))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("CRITIQUE"):
		push_error("life=10 should produce VIE CRITIQUE line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_life_low() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(20))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("BASSE"):
		push_error("life=20 should produce VIE BASSE line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_life_medium() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(40))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Vie: 40"):
		push_error("life=40 should produce 'Vie: 40/100' line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_life_safe_not_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80))
	var result: String = b.build_llm_prompt_context(full)
	# life >= 51 should NOT produce any life line
	if result.contains("Vie:") or result.contains("VIE"):
		push_error("life=80 should not produce any Vie line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_contains_day_and_cards() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run(80, 3, 7))
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Jour 3") or not result.contains("7 cartes"):
		push_error("Prompt should contain 'Jour 3' and '7 cartes', got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_ogham_actif_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["ogham_actif"] = "beith"
	var full: Dictionary = b.build_full_context(state)
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("beith"):
		push_error("Active ogham 'beith' should appear in prompt, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_ogham_actif_empty_not_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	var result: String = b.build_llm_prompt_context(full)
	if result.contains("Ogham actif:"):
		push_error("Empty ogham_actif should not produce 'Ogham actif:' line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_trust_line_present() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	# Inject a trust dict directly since registry is null
	full["trust"] = {"tier_name": "Prudent", "trust_points": 35}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Confiance:"):
		push_error("Prompt context should contain 'Confiance:' line, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_session_frustrated_note() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["session"] = {"seems_frustrated": true, "seems_fatigued": false, "is_long_session": false}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("frustre"):
		push_error("seems_frustrated=true should produce 'frustre' note, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_session_fatigued_note() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["session"] = {"seems_frustrated": false, "seems_fatigued": true, "is_long_session": false}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("fatigue"):
		push_error("seems_fatigued=true should produce 'fatigue' note, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_session_long_session_note() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["session"] = {"seems_frustrated": false, "seems_fatigued": false, "is_long_session": true}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("Longue"):
		push_error("is_long_session=true should produce 'Longue session' note, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_fatigued_themes_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["narrative"] = {
		"active_arcs": [],
		"fatigued_themes": ["combat", "mystere"],
		"recommended_themes": [],
	}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("combat") or not result.contains("mystere"):
		push_error("Fatigued themes should appear in prompt, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_recommended_themes_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["narrative"] = {
		"active_arcs": [],
		"fatigued_themes": [],
		"recommended_themes": ["spiritual", "politique"],
	}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("spiritual") or not result.contains("politique"):
		push_error("Recommended themes should appear in prompt, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_active_arcs_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["narrative"] = {
		"active_arcs": ["arc_forgeron", "arc_druid"],
		"fatigued_themes": [],
		"recommended_themes": [],
	}
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("arc_forgeron"):
		push_error("Active arcs should appear in prompt, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_patterns_shown() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	full["patterns"] = "explorateur confirmé"
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("explorateur"):
		push_error("Patterns string should appear in prompt, got: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. get_experience_tier
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_experience_tier_null_registry_returns_initie() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var tier: String = b.get_experience_tier()
	if tier != "Initie":
		push_error("Null player_profile should return 'Initie', got '%s'" % tier)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. _trust_tier_name (private helper — tested directly)
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tier_0_is_distant() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(0)
	if name != "Distant":
		push_error("Tier 0 should be 'Distant', got '%s'" % name)
		return false
	return true


func test_trust_tier_1_is_prudent() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(1)
	if name != "Prudent":
		push_error("Tier 1 should be 'Prudent', got '%s'" % name)
		return false
	return true


func test_trust_tier_2_is_attentif() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(2)
	if name != "Attentif":
		push_error("Tier 2 should be 'Attentif', got '%s'" % name)
		return false
	return true


func test_trust_tier_3_is_lie() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(3)
	if name != "Lie":
		push_error("Tier 3 should be 'Lie', got '%s'" % name)
		return false
	return true


func test_trust_tier_out_of_range_returns_inconnu() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(99)
	if name != "Inconnu":
		push_error("Out-of-range tier should be 'Inconnu', got '%s'" % name)
		return false
	return true


func test_trust_tier_negative_returns_inconnu() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var name: String = b._trust_tier_name(-1)
	if name != "Inconnu":
		push_error("Negative tier should be 'Inconnu', got '%s'" % name)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. _calculate_theme_weights (via build_full_context)
# ═══════════════════════════════════════════════════════════════════════════════

func test_theme_weights_empty_with_null_narrative() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context(_make_run())
	var hidden: Dictionary = result.get("_hidden", {})
	var weights = hidden.get("theme_weights")
	if not (weights is Dictionary):
		push_error("_hidden.theme_weights should be a Dictionary, got: %s" % type_string(typeof(weights)))
		return false
	if not weights.is_empty():
		push_error("theme_weights should be empty with null narrative registry, got: %s" % str(weights))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. build_full_context — edge cases
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_full_context_factions_default_when_missing() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	# game_state with no factions key
	var state: Dictionary = {"run": {"life_essence": 50}}
	var result: Dictionary = b.build_full_context(state)
	var factions: Dictionary = result.get("factions", {})
	# Should default to the 5-faction dict with zeros
	if not factions.has("druides"):
		push_error("Factions default should include 'druides', got: %s" % str(factions))
		return false
	return true


func test_build_full_context_active_promises_default_empty() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var result: Dictionary = b.build_full_context({})
	var promises: Array = result.get("active_promises", [])
	if not (promises is Array):
		push_error("active_promises default should be Array, got: %s" % type_string(typeof(promises)))
		return false
	return true


func test_build_full_context_active_tags_propagated() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["active_tags"] = ["forest_visited", "met_druid"]
	var result: Dictionary = b.build_full_context(state)
	var tags: Array = result.get("active_tags", [])
	if tags.size() != 2:
		push_error("active_tags should have 2 entries, got %d" % tags.size())
		return false
	return true


func test_build_llm_prompt_context_oghams_decouverts_listed() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var state: Dictionary = _make_run()
	state["run"]["oghams_decouverts"] = ["beith", "luis"]
	var full: Dictionary = b.build_full_context(state)
	var result: String = b.build_llm_prompt_context(full)
	if not result.contains("beith") or not result.contains("luis"):
		push_error("Oghams discovered should appear in prompt, got: '%s'" % result)
		return false
	return true


func test_build_llm_prompt_context_empty_oghams_not_listed() -> bool:
	var b: MerlinContextBuilder = _make_builder()
	var full: Dictionary = b.build_full_context(_make_run())
	var result: String = b.build_llm_prompt_context(full)
	if result.contains("découverts"):
		push_error("Empty oghams_decouverts should not produce 'découverts' line, got: '%s'" % result)
		return false
	return true
