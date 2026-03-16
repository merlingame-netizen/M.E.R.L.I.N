## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — FastRoute classify() / debug_scores() / _score_category()
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   classify()         — category detection, confidence thresholds, meta detection
##   _is_meta_question()— keyword + phrase matching
##   _score_category()  — keyword scoring, phrase bonus, multi-match bonus, excludes
##   debug_scores()     — all categories scored + _is_meta + _input normalization
##
## Pattern: extends RefCounted, no class_name, test_xxx() -> bool
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — COMBAT category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_combat_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("je frappe l'ennemi")
	if str(result.get("category", "")) != "combat":
		push_error("classify combat keyword: expected 'combat', got '%s'" % str(result.get("category", "")))
		return false
	if float(result.get("confidence", 0.0)) < 0.3:
		push_error("classify combat keyword: confidence too low: %f" % float(result.get("confidence", 0.0)))
		return false
	return true


func test_classify_combat_phrase_high_confidence() -> bool:
	var result: Dictionary = FastRoute.classify("j'attaque le monstre")
	if str(result.get("category", "")) != "combat":
		push_error("classify combat phrase: expected 'combat', got '%s'" % str(result.get("category", "")))
		return false
	if float(result.get("confidence", 0.0)) < 0.6:
		push_error("classify combat phrase: confidence should be >= 0.6, got %f" % float(result.get("confidence", 0.0)))
		return false
	if str(result.get("method", "")) != "pattern_match":
		push_error("classify combat phrase: expected method 'pattern_match', got '%s'" % str(result.get("method", "")))
		return false
	return true


func test_classify_combat_excluded_by_meta_word() -> bool:
	# "comment attaquer" contains both "attaquer" (combat keyword) and "comment" (meta keyword)
	# Meta detection takes priority and overrides category to dialogue
	var result: Dictionary = FastRoute.classify("comment attaquer les ennemis")
	if not bool(result.get("is_meta", false)):
		push_error("classify combat excluded meta: is_meta should be true for 'comment attaquer'")
		return false
	return true


func test_classify_combat_exclude_phrase_zeroes_score() -> bool:
	# "regles de combat" is in combat's excludes list — score must be 0.
	# We verify via debug_scores: the exclude phrase short-circuits the scorer to 0.0.
	var scores: Dictionary = FastRoute.debug_scores("regles de combat expliquees")
	if float(scores.get("combat", 1.0)) != 0.0:
		push_error("classify combat exclude: combat score must be 0.0 when exclude phrase matches, got %f" % float(scores.get("combat", -1.0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — DIALOGUE category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_dialogue_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("je salue le marchand")
	if str(result.get("category", "")) != "dialogue":
		push_error("classify dialogue keyword: expected 'dialogue', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_dialogue_phrase() -> bool:
	# "je lui parle" phrase (0.4) + "parle" keyword (0.15) + "demande" keyword (0.15) = 0.7
	var result: Dictionary = FastRoute.classify("je lui parle et je demande")
	if str(result.get("category", "")) != "dialogue":
		push_error("classify dialogue phrase: expected 'dialogue', got '%s'" % str(result.get("category", "")))
		return false
	if float(result.get("confidence", 0.0)) < 0.6:
		push_error("classify dialogue phrase: confidence should be >= 0.6, got %f" % float(result.get("confidence", 0.0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — EXPLORATION category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_exploration_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("j'explore la foret")
	if str(result.get("category", "")) != "exploration":
		push_error("classify exploration keyword: expected 'exploration', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_exploration_phrase() -> bool:
	var result: Dictionary = FastRoute.classify("je fouille la piece")
	if str(result.get("category", "")) != "exploration":
		push_error("classify exploration phrase: expected 'exploration', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_exploration_directional() -> bool:
	var result: Dictionary = FastRoute.classify("je vais vers le nord")
	if str(result.get("category", "")) != "exploration":
		push_error("classify exploration directional: expected 'exploration', got '%s'" % str(result.get("category", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — INVENTAIRE category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_inventaire_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("je prends la potion")
	if str(result.get("category", "")) != "inventaire":
		push_error("classify inventaire keyword: expected 'inventaire', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_inventaire_phrase() -> bool:
	var result: Dictionary = FastRoute.classify("j'equipe l'armure")
	if str(result.get("category", "")) != "inventaire":
		push_error("classify inventaire phrase: expected 'inventaire', got '%s'" % str(result.get("category", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — MAGIE category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_magie_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("j'active l'ogham beith")
	if str(result.get("category", "")) != "magie":
		push_error("classify magie ogham: expected 'magie', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_magie_phrase() -> bool:
	var result: Dictionary = FastRoute.classify("je lance un sortilege de feu")
	if str(result.get("category", "")) != "magie":
		push_error("classify magie phrase: expected 'magie', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_magie_exclude_zeroes_score() -> bool:
	# "regles magie" is in magie's excludes list
	var scores: Dictionary = FastRoute.debug_scores("regles magie du druide")
	if float(scores.get("magie", 1.0)) != 0.0:
		push_error("classify magie exclude: magie score must be 0.0, got %f" % float(scores.get("magie", -1.0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — QUETE category
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_quete_keyword() -> bool:
	var result: Dictionary = FastRoute.classify("j'accepte la quete du mage")
	if str(result.get("category", "")) != "quete":
		push_error("classify quete keyword: expected 'quete', got '%s'" % str(result.get("category", "")))
		return false
	return true


func test_classify_quete_phrase() -> bool:
	var result: Dictionary = FastRoute.classify("j'accepte la quete")
	if str(result.get("category", "")) != "quete":
		push_error("classify quete phrase: expected 'quete', got '%s'" % str(result.get("category", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — META detection (is_meta = true)
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_meta_keyword_comment() -> bool:
	var result: Dictionary = FastRoute.classify("comment ca marche ce jeu")
	if not bool(result.get("is_meta", false)):
		push_error("classify meta comment: is_meta should be true")
		return false
	if str(result.get("category", "")) != "dialogue":
		push_error("classify meta comment: category should be 'dialogue', got '%s'" % str(result.get("category", "")))
		return false
	if absf(float(result.get("confidence", 0.0)) - 0.8) > 0.001:
		push_error("classify meta comment: confidence should be 0.8, got %f" % float(result.get("confidence", 0.0)))
		return false
	if str(result.get("method", "")) != "meta_detection":
		push_error("classify meta comment: method should be 'meta_detection', got '%s'" % str(result.get("method", "")))
		return false
	return true


func test_classify_meta_keyword_aide() -> bool:
	var result: Dictionary = FastRoute.classify("aide-moi a comprendre les oghams")
	if not bool(result.get("is_meta", false)):
		push_error("classify meta aide: is_meta should be true")
		return false
	return true


func test_classify_meta_phrase_explique_moi() -> bool:
	var result: Dictionary = FastRoute.classify("explique-moi comment fonctionne la magie")
	if not bool(result.get("is_meta", false)):
		push_error("classify meta explique-moi: is_meta should be true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — No match / empty input / boundary conditions
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_empty_input_returns_no_category() -> bool:
	var result: Dictionary = FastRoute.classify("")
	if str(result.get("category", "")) != "":
		push_error("classify empty: category should be empty string, got '%s'" % str(result.get("category", "")))
		return false
	if str(result.get("method", "")) != "none":
		push_error("classify empty: method should be 'none', got '%s'" % str(result.get("method", "")))
		return false
	return true


func test_classify_whitespace_only_returns_no_category() -> bool:
	var result: Dictionary = FastRoute.classify("     ")
	if str(result.get("method", "")) != "none":
		push_error("classify whitespace: method should be 'none', got '%s'" % str(result.get("method", "")))
		return false
	return true


func test_classify_unrecognized_input_no_confident_match() -> bool:
	# Gibberish that matches nothing
	var result: Dictionary = FastRoute.classify("zzqxkmwvb")
	if float(result.get("confidence", 0.0)) >= 0.6:
		push_error("classify unrecognized: confidence should be < 0.6 for gibberish, got %f" % float(result.get("confidence", 0.0)))
		return false
	return true


func test_classify_result_is_never_meta_without_is_meta_flag() -> bool:
	# A normal combat input must have is_meta = false
	var result: Dictionary = FastRoute.classify("je combats le dragon")
	if bool(result.get("is_meta", false)):
		push_error("classify non-meta input: is_meta should be false for 'je combats le dragon'")
		return false
	return true


func test_classify_case_insensitive() -> bool:
	# Input with uppercase should classify same as lowercase
	var result_lower: Dictionary = FastRoute.classify("je frappe l'ennemi")
	var result_upper: Dictionary = FastRoute.classify("JE FRAPPE L'ENNEMI")
	if str(result_lower.get("category", "")) != str(result_upper.get("category", "")):
		push_error("classify case insensitive: lower '%s' != upper '%s'" % [
			str(result_lower.get("category", "")), str(result_upper.get("category", "")),
		])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _score_category() — multi-keyword bonus thresholds
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_three_keywords_triggers_bonus() -> bool:
	# "attaque ennemi monstre" = 3 combat keywords → +0.2 bonus in addition to 3 * 0.15 = 0.45+0.2 = 0.65
	var scores: Dictionary = FastRoute.debug_scores("j'attaque l'ennemi le monstre")
	var combat_score: float = float(scores.get("combat", 0.0))
	# Three keywords found: attaque, ennemi, monstre → base 0.45 + bonus 0.2 = 0.65
	if combat_score < 0.6:
		push_error("score 3 keyword bonus: combat score should be >= 0.6, got %f" % combat_score)
		return false
	return true


func test_score_two_keywords_triggers_small_bonus() -> bool:
	# "attaque ennemi" = 2 keywords → base 0.3 + bonus 0.1 = 0.4
	var scores: Dictionary = FastRoute.debug_scores("attaque ennemi simple")
	var combat_score: float = float(scores.get("combat", 0.0))
	if combat_score < 0.35:
		push_error("score 2 keyword bonus: combat score should be >= 0.35, got %f" % combat_score)
		return false
	return true


func test_score_phrase_worth_0_4() -> bool:
	# "je frappe" alone = 1 phrase (0.4) + 1 keyword "frappe" (0.15) = 0.55, but clamped ≤ 1.0
	var scores: Dictionary = FastRoute.debug_scores("je frappe")
	var combat_score: float = float(scores.get("combat", 0.0))
	if combat_score < 0.4:
		push_error("score phrase 0.4: combat score should be >= 0.4, got %f" % combat_score)
		return false
	return true


func test_score_clamped_at_1_0() -> bool:
	# Massive overlap should never exceed 1.0
	var huge_input: String = "je frappe attaque combattre tue blesse defend esquive pare riposte degat coup epee monstre adversaire ennemi"
	var scores: Dictionary = FastRoute.debug_scores(huge_input)
	var combat_score: float = float(scores.get("combat", 0.0))
	if combat_score > 1.0:
		push_error("score clamp: combat score must be <= 1.0, got %f" % combat_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# debug_scores() — structural validation
# ═══════════════════════════════════════════════════════════════════════════════

func test_debug_scores_returns_all_categories() -> bool:
	var expected_keys: Array[String] = ["combat", "dialogue", "exploration", "inventaire", "magie", "quete"]
	var scores: Dictionary = FastRoute.debug_scores("test input")
	for key in expected_keys:
		if not scores.has(key):
			push_error("debug_scores: missing key '%s'" % key)
			return false
	return true


func test_debug_scores_has_meta_and_input_keys() -> bool:
	var scores: Dictionary = FastRoute.debug_scores("bonjour")
	if not scores.has("_is_meta"):
		push_error("debug_scores: missing '_is_meta' key")
		return false
	if not scores.has("_input"):
		push_error("debug_scores: missing '_input' key")
		return false
	return true


func test_debug_scores_normalizes_input_to_lowercase() -> bool:
	var scores: Dictionary = FastRoute.debug_scores("BONJOUR PNJ")
	var stored_input: String = str(scores.get("_input", ""))
	if stored_input != "bonjour pnj":
		push_error("debug_scores normalize: expected 'bonjour pnj', got '%s'" % stored_input)
		return false
	return true


func test_debug_scores_is_meta_true_on_meta_input() -> bool:
	var scores: Dictionary = FastRoute.debug_scores("comment ca marche")
	if not bool(scores.get("_is_meta", false)):
		push_error("debug_scores: _is_meta should be true for 'comment ca marche'")
		return false
	return true


func test_debug_scores_all_scores_in_0_1_range() -> bool:
	var categories: Array[String] = ["combat", "dialogue", "exploration", "inventaire", "magie", "quete"]
	var scores: Dictionary = FastRoute.debug_scores("je frappe l'ogham dans la foret avec une potion")
	for cat in categories:
		var s: float = float(scores.get(cat, -1.0))
		if s < 0.0 or s > 1.0:
			push_error("debug_scores: category '%s' score %f out of [0, 1]" % [cat, s])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# classify() — return shape is always a valid Dictionary with required keys
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_always_returns_required_keys() -> bool:
	var inputs: Array[String] = ["", "test", "je frappe", "comment ca marche", "zzz"]
	var required_keys: Array[String] = ["category", "confidence", "is_meta", "method"]
	for inp in inputs:
		var result: Dictionary = FastRoute.classify(inp)
		for key in required_keys:
			if not result.has(key):
				push_error("classify shape: missing key '%s' for input '%s'" % [key, inp])
				return false
	return true


func test_classify_method_is_none_when_no_match() -> bool:
	var result: Dictionary = FastRoute.classify("xkzqwmvbplr")
	if str(result.get("method", "")) != "none":
		push_error("classify no match method: expected 'none', got '%s'" % str(result.get("method", "")))
		return false
	return true


func test_classify_method_is_pattern_suggest_on_weak_match() -> bool:
	# A single keyword with score >= 0.3 but < 0.6 → "pattern_suggest"
	# "attaque" alone = 0.15 (one keyword, no multi-bonus) — below 0.3, method stays "none"
	# Two keywords needed for 0.3: e.g. "attaque" + "ennemi" = 0.3 + bonus 0.1 = 0.4
	var result: Dictionary = FastRoute.classify("attaque ennemi")
	var method: String = str(result.get("method", ""))
	if method != "pattern_suggest" and method != "pattern_match":
		push_error("classify weak match method: expected 'pattern_suggest' or 'pattern_match', got '%s'" % method)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# Combat (4)
		"test_classify_combat_keyword",
		"test_classify_combat_phrase_high_confidence",
		"test_classify_combat_excluded_by_meta_word",
		"test_classify_combat_exclude_phrase_zeroes_score",
		# Dialogue (2)
		"test_classify_dialogue_keyword",
		"test_classify_dialogue_phrase",
		# Exploration (3)
		"test_classify_exploration_keyword",
		"test_classify_exploration_phrase",
		"test_classify_exploration_directional",
		# Inventaire (2)
		"test_classify_inventaire_keyword",
		"test_classify_inventaire_phrase",
		# Magie (3)
		"test_classify_magie_keyword",
		"test_classify_magie_phrase",
		"test_classify_magie_exclude_zeroes_score",
		# Quete (2)
		"test_classify_quete_keyword",
		"test_classify_quete_phrase",
		# Meta detection (3)
		"test_classify_meta_keyword_comment",
		"test_classify_meta_keyword_aide",
		"test_classify_meta_phrase_explique_moi",
		# Edge cases / boundary (5)
		"test_classify_empty_input_returns_no_category",
		"test_classify_whitespace_only_returns_no_category",
		"test_classify_unrecognized_input_no_confident_match",
		"test_classify_result_is_never_meta_without_is_meta_flag",
		"test_classify_case_insensitive",
		# Score internals (4)
		"test_score_three_keywords_triggers_bonus",
		"test_score_two_keywords_triggers_small_bonus",
		"test_score_phrase_worth_0_4",
		"test_score_clamped_at_1_0",
		# debug_scores (5)
		"test_debug_scores_returns_all_categories",
		"test_debug_scores_has_meta_and_input_keys",
		"test_debug_scores_normalizes_input_to_lowercase",
		"test_debug_scores_is_meta_true_on_meta_input",
		"test_debug_scores_all_scores_in_0_1_range",
		# Return shape (3)
		"test_classify_always_returns_required_keys",
		"test_classify_method_is_none_when_no_match",
		"test_classify_method_is_pattern_suggest_on_weak_match",
	]
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		if call(test_name):
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	var total: int = passed + failed
	print("[FastRouteUnit] %d/%d passed (%d failed)" % [passed, total, failed])
	for f in failures:
		print("  FAIL: %s" % f)
	return {"passed": passed, "failed": failed, "total": total, "failures": failures}
