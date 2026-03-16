## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — LlmAdapterPrompts
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: get_arc_phase, get_scenario_template, build_balance_hint,
## format_instructions, build_scenario_injection, substitute_template_vars,
## build_arc_system_prompt, build_arc_user_prompt, build_context_enrichment,
## extract_recurring_motifs, jaccard_similarity, get_phase_verb_pool,
## build_narrative_system_prompt, build_narrative_user_prompt.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_prompts() -> LlmAdapterPrompts:
	return LlmAdapterPrompts.new()


## Dummy balance evaluator returning a controlled dictionary.
func _make_balance_evaluator(score: int, risk: String = "none") -> Callable:
	var result: Dictionary = {"balance_score": score, "risk_faction": risk}
	return func(_ctx: Dictionary) -> Dictionary: return result


# ═══════════════════════════════════════════════════════════════════════════════
# get_arc_phase
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_phase_intro() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(0)
	if result != "mini_arc_intro":
		push_error("get_arc_phase(0): expected 'mini_arc_intro', got '%s'" % result)
		return false
	return true


func test_arc_phase_negative() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(-1)
	if result != "mini_arc_intro":
		push_error("get_arc_phase(-1): expected 'mini_arc_intro', got '%s'" % result)
		return false
	return true


func test_arc_phase_ambient() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(1)
	if result != "scenario_ambient_card":
		push_error("get_arc_phase(1): expected 'scenario_ambient_card', got '%s'" % result)
		return false
	return true


func test_arc_phase_complication() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(3)
	if result != "mini_arc_complication":
		push_error("get_arc_phase(3): expected 'mini_arc_complication', got '%s'" % result)
		return false
	return true


func test_arc_phase_climax() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(5)
	if result != "mini_arc_climax":
		push_error("get_arc_phase(5): expected 'mini_arc_climax', got '%s'" % result)
		return false
	return true


func test_arc_phase_twist() -> bool:
	var p := _make_prompts()
	var result: String = p.get_arc_phase(7)
	if result != "twist_climax":
		push_error("get_arc_phase(7): expected 'twist_climax', got '%s'" % result)
		return false
	return true


func test_arc_phase_late_game_even() -> bool:
	var p := _make_prompts()
	# cards_played=10 (even, >8) → mini_arc_climax
	var result: String = p.get_arc_phase(10)
	if result != "mini_arc_climax":
		push_error("get_arc_phase(10): expected 'mini_arc_climax', got '%s'" % result)
		return false
	return true


func test_arc_phase_late_game_odd() -> bool:
	var p := _make_prompts()
	# cards_played=11 (odd, >8) → scenario_ambient_card
	var result: String = p.get_arc_phase(11)
	if result != "scenario_ambient_card":
		push_error("get_arc_phase(11): expected 'scenario_ambient_card', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_scenario_template
# ═══════════════════════════════════════════════════════════════════════════════

func test_scenario_template_not_loaded() -> bool:
	var p := _make_prompts()
	# _scenario_prompts_loaded defaults to false
	var result: Dictionary = p.get_scenario_template("mini_arc_intro")
	if not result.is_empty():
		push_error("get_scenario_template not loaded: expected empty, got %s" % str(result))
		return false
	return true


func test_scenario_template_loaded_missing_key() -> bool:
	var p := _make_prompts()
	p._scenario_prompts_loaded = true
	p._scenario_prompts = {"mini_arc_intro": {"system": "test"}}
	var result: Dictionary = p.get_scenario_template("nonexistent_key")
	if not result.is_empty():
		push_error("get_scenario_template missing key: expected empty, got %s" % str(result))
		return false
	return true


func test_scenario_template_loaded_found() -> bool:
	var p := _make_prompts()
	p._scenario_prompts_loaded = true
	var tpl: Dictionary = {"system": "Tu es Merlin", "user_template": "Carte {arc_progress}"}
	p._scenario_prompts = {"mini_arc_intro": tpl}
	var result: Dictionary = p.get_scenario_template("mini_arc_intro")
	if not result.has("system"):
		push_error("get_scenario_template found: missing 'system' key in %s" % str(result))
		return false
	if str(result["system"]) != "Tu es Merlin":
		push_error("get_scenario_template found: wrong system value '%s'" % str(result["system"]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_balance_hint
# ═══════════════════════════════════════════════════════════════════════════════

func test_balance_hint_critical_with_risk() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var evaluator: Callable = _make_balance_evaluator(20, "druides")
	var result: String = p.build_balance_hint(ctx, evaluator)
	if result.find("URGENCE") < 0:
		push_error("build_balance_hint critical+risk: expected 'URGENCE', got '%s'" % result)
		return false
	if result.find("druides") < 0:
		push_error("build_balance_hint critical+risk: expected 'druides' in '%s'" % result)
		return false
	return true


func test_balance_hint_critical_no_risk() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var evaluator: Callable = _make_balance_evaluator(25, "none")
	var result: String = p.build_balance_hint(ctx, evaluator)
	if result.find("URGENCE") < 0:
		push_error("build_balance_hint critical no risk: expected 'URGENCE', got '%s'" % result)
		return false
	if result.find("repos") < 0:
		push_error("build_balance_hint critical no risk: expected 'repos', got '%s'" % result)
		return false
	return true


func test_balance_hint_fragile() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var evaluator: Callable = _make_balance_evaluator(45, "korrigans")
	var result: String = p.build_balance_hint(ctx, evaluator)
	if result.find("FRAGILE") < 0:
		push_error("build_balance_hint fragile: expected 'FRAGILE', got '%s'" % result)
		return false
	return true


func test_balance_hint_stable() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var evaluator: Callable = _make_balance_evaluator(85)
	var result: String = p.build_balance_hint(ctx, evaluator)
	if result.find("STABLE") < 0:
		push_error("build_balance_hint stable: expected 'STABLE', got '%s'" % result)
		return false
	return true


func test_balance_hint_neutral() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var evaluator: Callable = _make_balance_evaluator(65)
	var result: String = p.build_balance_hint(ctx, evaluator)
	if result != "":
		push_error("build_balance_hint neutral: expected empty, got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# format_instructions
# ═══════════════════════════════════════════════════════════════════════════════

func test_format_instructions_contains_tu_rule() -> bool:
	var p := _make_prompts()
	var result: String = p.format_instructions(0)
	if result.find("TU") < 0:
		push_error("format_instructions: missing 'TU' rule in output")
		return false
	if result.find("A)") < 0 or result.find("B)") < 0 or result.find("C)") < 0:
		push_error("format_instructions: missing A)/B)/C) format spec")
		return false
	return true


func test_format_instructions_rotates_examples() -> bool:
	var p := _make_prompts()
	var r0: String = p.format_instructions(0)
	var r1: String = p.format_instructions(1)
	var r2: String = p.format_instructions(2)
	# All three should contain different example verbs
	if r0 == r1 or r1 == r2:
		push_error("format_instructions: examples not rotating across cards 0,1,2")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_scenario_injection
# ═══════════════════════════════════════════════════════════════════════════════

func test_scenario_injection_with_title() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"scenario_title": "Le Chene Ancien"}
	var result: String = p.build_scenario_injection(ctx)
	if result.find("Le Chene Ancien") < 0:
		push_error("build_scenario_injection: title not found in '%s'" % result)
		return false
	if result.find("QUETE") < 0:
		push_error("build_scenario_injection: 'QUETE' prefix missing in '%s'" % result)
		return false
	return true


func test_scenario_injection_empty_context() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {}
	var result: String = p.build_scenario_injection(ctx)
	if result != "":
		push_error("build_scenario_injection empty ctx: expected '', got '%s'" % result)
		return false
	return true


func test_scenario_injection_anchor() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"anchor_context": "Un loup apparait"}
	var result: String = p.build_scenario_injection(ctx)
	if result.find("MOMENT CLE") < 0:
		push_error("build_scenario_injection anchor: missing 'MOMENT CLE' in '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_context_enrichment
# ═══════════════════════════════════════════════════════════════════════════════

func test_context_enrichment_high_tension() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"tension": 70}
	var result: String = p.build_context_enrichment(ctx)
	if result.find("haute") < 0:
		push_error("build_context_enrichment high tension: expected 'haute' in '%s'" % result)
		return false
	return true


func test_context_enrichment_empty() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"tension": 0, "player_tendency": "neutre"}
	var result: String = p.build_context_enrichment(ctx)
	if result != "":
		push_error("build_context_enrichment empty: expected '', got '%s'" % result)
		return false
	return true


func test_context_enrichment_with_talents() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"talent_names": ["Guerison", "Force", "Vision", "Sagesse"]}
	var result: String = p.build_context_enrichment(ctx)
	if result.find("Talents") < 0:
		push_error("build_context_enrichment talents: missing 'Talents' in '%s'" % result)
		return false
	# Should cap at 3 talent names
	if result.find("Sagesse") >= 0:
		push_error("build_context_enrichment talents: 4th talent 'Sagesse' should not appear in '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# extract_recurring_motifs
# ═══════════════════════════════════════════════════════════════════════════════

func test_extract_motifs_recurring() -> bool:
	var p := _make_prompts()
	var log: Array = [
		{"text": "La clairiere brillait sous les etoiles anciennes"},
		{"text": "Les etoiles guidaient le chemin vers la clairiere"},
	]
	var result: Array[String] = p.extract_recurring_motifs(log)
	# "clairiere" (9 chars, appears in 2 entries) and "etoiles" (7 chars, in 2 entries)
	var tracker: Dictionary = {"found_clairiere": false, "found_etoiles": false}
	for m in result:
		if m == "clairiere":
			tracker["found_clairiere"] = true
		if m == "etoiles":
			tracker["found_etoiles"] = true
	if not tracker["found_clairiere"] and not tracker["found_etoiles"]:
		push_error("extract_recurring_motifs: expected recurring words, got %s" % str(result))
		return false
	return true


func test_extract_motifs_no_repeats() -> bool:
	var p := _make_prompts()
	var log: Array = [
		{"text": "Le soleil brille"},
		{"text": "La lune eclaire"},
	]
	var result: Array[String] = p.extract_recurring_motifs(log)
	if result.size() > 0:
		push_error("extract_recurring_motifs no repeats: expected empty, got %s" % str(result))
		return false
	return true


func test_extract_motifs_filters_common_words() -> bool:
	var p := _make_prompts()
	var log: Array = [
		{"text": "La foret enchantee brillait magnifiquement"},
		{"text": "La foret ancienne brillait doucement"},
	]
	var result: Array[String] = p.extract_recurring_motifs(log)
	# "foret" is in common_words list, should be filtered out
	var tracker: Dictionary = {"has_foret": false}
	for m in result:
		if m == "foret":
			tracker["has_foret"] = true
	if tracker["has_foret"]:
		push_error("extract_recurring_motifs: common word 'foret' should be filtered, got %s" % str(result))
		return false
	return true


func test_extract_motifs_max_five() -> bool:
	var p := _make_prompts()
	# Create entries with many recurring long words
	var log: Array = [
		{"text": "cristal diamant rubis emeraude saphir topaze amethyste"},
		{"text": "cristal diamant rubis emeraude saphir topaze amethyste"},
	]
	var result: Array[String] = p.extract_recurring_motifs(log)
	if result.size() > 5:
		push_error("extract_recurring_motifs max: expected <=5, got %d" % result.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# jaccard_similarity
# ═══════════════════════════════════════════════════════════════════════════════

func test_jaccard_identical() -> bool:
	var p := _make_prompts()
	var result: float = p.jaccard_similarity("tu marches", "tu marches")
	if result < 0.99:
		push_error("jaccard identical: expected 1.0, got %f" % result)
		return false
	return true


func test_jaccard_disjoint() -> bool:
	var p := _make_prompts()
	var result: float = p.jaccard_similarity("le soleil brille", "une lune eclaire")
	if result > 0.01:
		push_error("jaccard disjoint: expected 0.0, got %f" % result)
		return false
	return true


func test_jaccard_empty_both() -> bool:
	var p := _make_prompts()
	var result: float = p.jaccard_similarity("", "")
	if result < 0.99:
		push_error("jaccard empty both: expected 1.0, got %f" % result)
		return false
	return true


func test_jaccard_partial_overlap() -> bool:
	var p := _make_prompts()
	# "tu marches" vs "tu cours" → intersection={tu}, union={tu,marches,cours} → 1/3
	var result: float = p.jaccard_similarity("tu marches", "tu cours")
	if result < 0.3 or result > 0.4:
		push_error("jaccard partial: expected ~0.33, got %f" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_arc_system_prompt (fallback path, no scenario templates loaded)
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_system_prompt_fallback() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"biome": "foret_broceliande", "life_essence": 80, "karma": 5}
	var evaluator: Callable = _make_balance_evaluator(70)
	var result: String = p.build_arc_system_prompt(0, "mystere", ctx, evaluator)
	if result.find("Merlin") < 0:
		push_error("build_arc_system_prompt fallback: missing 'Merlin' in output")
		return false
	if result.find("TU") < 0:
		push_error("build_arc_system_prompt fallback: missing 'TU' rule")
		return false
	return true


func test_arc_system_prompt_convergence_hint_late() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"biome": "marais", "life_essence": 50, "karma": 0}
	var evaluator: Callable = _make_balance_evaluator(60)
	# cards_played=42 → >= soft_max_cards(40) → URGENCE NARRATIVE
	var result: String = p.build_arc_system_prompt(42, "ombre", ctx, evaluator)
	if result.find("URGENCE NARRATIVE") < 0:
		push_error("build_arc_system_prompt late: expected 'URGENCE NARRATIVE' in output")
		return false
	return true


func test_arc_system_prompt_with_template() -> bool:
	var p := _make_prompts()
	p._scenario_prompts_loaded = true
	p._scenario_prompts = {
		"mini_arc_intro": {
			"system": "Bienvenue dans {scenario_title}. Theme: {scenario_theme}.",
			"user_template": "Carte {arc_progress}."
		}
	}
	var ctx: Dictionary = {"scenario_title": "La Source", "scenario_theme": "eau"}
	var evaluator: Callable = _make_balance_evaluator(70)
	var result: String = p.build_arc_system_prompt(0, "eau", ctx, evaluator)
	if result.find("La Source") < 0:
		push_error("build_arc_system_prompt template: scenario_title not substituted in '%s'" % result.substr(0, 100))
		return false
	if result.find("TU") < 0:
		push_error("build_arc_system_prompt template: format_instructions missing")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_arc_user_prompt
# ═══════════════════════════════════════════════════════════════════════════════

func test_arc_user_prompt_fallback() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {"biome": "foret_broceliande", "life_essence": 80}
	var evaluator: Callable = _make_balance_evaluator(90)
	var result: String = p.build_arc_user_prompt(0, "foret_broceliande", "nature", ctx, evaluator)
	if result.find("Carte 1") < 0:
		push_error("build_arc_user_prompt fallback: missing 'Carte 1' in '%s'" % result.substr(0, 100))
		return false
	if result.find("Tu decouvres") < 0:
		push_error("build_arc_user_prompt fallback: missing opening hook 'Tu decouvres'")
		return false
	return true


func test_arc_user_prompt_injects_scenario() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {
		"scenario_title": "Le Druide Perdu",
		"anchor_context": "Un chant resonne",
	}
	var evaluator: Callable = _make_balance_evaluator(70)
	var result: String = p.build_arc_user_prompt(2, "marais", "brume", ctx, evaluator)
	if result.find("Le Druide Perdu") < 0:
		push_error("build_arc_user_prompt scenario: title not injected in '%s'" % result.substr(0, 150))
		return false
	if result.find("MOMENT CLE") < 0:
		push_error("build_arc_user_prompt scenario: anchor not injected")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_narrative_system_prompt & build_narrative_user_prompt
# ═══════════════════════════════════════════════════════════════════════════════

func test_narrative_system_prompt_structure() -> bool:
	var p := _make_prompts()
	var result: String = p.build_narrative_system_prompt()
	if result.find("JSON") < 0:
		push_error("build_narrative_system_prompt: missing 'JSON' in output")
		return false
	if result.find("ADD_REPUTATION") < 0:
		push_error("build_narrative_system_prompt: missing 'ADD_REPUTATION' effect type")
		return false
	if result.find("HEAL_LIFE") < 0:
		push_error("build_narrative_system_prompt: missing 'HEAL_LIFE' effect type")
		return false
	return true


func test_narrative_user_prompt_basic() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {
		"cards_played": 3,
		"day": 2,
		"biome": "lande_sauvage",
		"life_essence": 75,
		"faction_status": "druides:60,ankou:20",
	}
	var result: String = p.build_narrative_user_prompt(ctx)
	if result.find("Jour:2") < 0:
		push_error("build_narrative_user_prompt: missing 'Jour:2' in '%s'" % result)
		return false
	if result.find("Carte:3") < 0:
		push_error("build_narrative_user_prompt: missing 'Carte:3' in '%s'" % result)
		return false
	if result.find("lande_sauvage") < 0:
		push_error("build_narrative_user_prompt: missing biome in '%s'" % result)
		return false
	if result.find("Vie:75") < 0:
		push_error("build_narrative_user_prompt: missing 'Vie:75' in '%s'" % result)
		return false
	return true


func test_narrative_user_prompt_with_tags() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {
		"cards_played": 1,
		"day": 1,
		"biome": "foret",
		"life_essence": 100,
		"active_tags": ["mystere", "danger", "magie", "ombre"],
	}
	var result: String = p.build_narrative_user_prompt(ctx)
	if result.find("Tags:") < 0:
		push_error("build_narrative_user_prompt tags: missing 'Tags:' in '%s'" % result)
		return false
	# Should cap at 3 tags
	if result.find("ombre") >= 0:
		push_error("build_narrative_user_prompt tags: 4th tag 'ombre' should not appear")
		return false
	return true


func test_narrative_user_prompt_with_story_log() -> bool:
	var p := _make_prompts()
	var ctx: Dictionary = {
		"cards_played": 5,
		"day": 1,
		"biome": "foret",
		"life_essence": 50,
		"story_log": [{"text": "Tu as traverse le pont de pierre ancien."}],
	}
	var result: String = p.build_narrative_user_prompt(ctx)
	if result.find("Precedent") < 0:
		push_error("build_narrative_user_prompt story_log: missing 'Precedent' in '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# substitute_template_vars
# ═══════════════════════════════════════════════════════════════════════════════

func test_substitute_template_vars_basic() -> bool:
	var p := _make_prompts()
	var tpl_str: String = "Biome: {biome}, Jour: {day}, Vie: {life}"
	var ctx: Dictionary = {"biome": "marais_sombre", "day": 3, "life_essence": 42}
	var result: String = p.substitute_template_vars(tpl_str, ctx, 5, "brume")
	if result.find("marais_sombre") < 0:
		push_error("substitute_template_vars: biome not replaced in '%s'" % result)
		return false
	if result.find("Jour: 3") < 0:
		push_error("substitute_template_vars: day not replaced in '%s'" % result)
		return false
	if result.find("Vie: 42") < 0:
		push_error("substitute_template_vars: life not replaced in '%s'" % result)
		return false
	return true


func test_substitute_template_vars_dominant_faction() -> bool:
	var p := _make_prompts()
	var tpl_str: String = "Faction dominante: {dominant_faction}"
	var ctx: Dictionary = {"factions": {"druides": 80, "ankou": 30, "korrigans": 50}}
	var result: String = p.substitute_template_vars(tpl_str, ctx)
	if result.find("druides") < 0:
		push_error("substitute_template_vars faction: expected 'druides' in '%s'" % result)
		return false
	return true
