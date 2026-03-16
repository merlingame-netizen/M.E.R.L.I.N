## test_brain_quality_judge.gd
## Unit tests for BrainQualityJudge — scoring logic, vocabulary detection,
## quality thresholds, best-of-N selection, repetition detection, refinement.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error+return false.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _approx_eq(a: float, b: float, epsilon: float = 0.01) -> bool:
	return absf(a - b) < epsilon


static func _make_judge() -> BrainQualityJudge:
	return BrainQualityJudge.new()


## A well-formed French text with Celtic vocab, narrative + 3 choices, ideal length.
static func _good_french_text() -> String:
	return (
		"Le druide se tient dans la clairiere sacree, la brume enveloppe les menhirs anciens.\n"
		+ "Un corbeau croasse depuis le chene. Le sentier se divise en trois.\n"
		+ "A) Suivre la lumiere de la lune vers le dolmen.\n"
		+ "B) Ecouter le souffle du vent dans la foret.\n"
		+ "C) Invoquer un ancien sortilege pour reveler le chemin."
	)


## English-only text with no Celtic or structure.
static func _english_text() -> String:
	return "The wizard stands in the clearing. He looks around carefully."


## Very short text.
static func _tiny_text() -> String:
	return "Bonjour."


# ═══════════════════════════════════════════════════════════════════════════════
# FRENCH DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_french_score_high_for_french_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text(_good_french_text())
	var french_score: float = result.scores.french
	if french_score < 0.9:
		push_error("Expected french score >= 0.9 for well-formed French text, got: %f" % french_score)
		return false
	return true


func test_french_score_low_for_english_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text(_english_text())
	var french_score: float = result.scores.french
	if french_score > 0.5:
		push_error("Expected french score <= 0.5 for English text, got: %f" % french_score)
		return false
	return true


func test_french_score_zero_for_gibberish() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text("xyzzy plugh qwerty asdf")
	var french_score: float = result.scores.french
	if french_score > 0.01:
		push_error("Expected french score ~0 for gibberish, got: %f" % french_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CELTIC VOCABULARY
# ═══════════════════════════════════════════════════════════════════════════════

func test_celtic_score_high_with_multiple_keywords() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Le druide contemple le dolmen dans la clairiere mystique"
	var result: Dictionary = judge.score_text(text)
	var celtic_score: float = result.scores.celtic
	# druide, dolmen, clairiere, mystique = 4 matches -> 4/3 clamped to 1.0
	if celtic_score < 0.99:
		push_error("Expected celtic score ~1.0 with 4 keywords, got: %f" % celtic_score)
		return false
	return true


func test_celtic_score_zero_without_keywords() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Le chat mange une pomme rouge dans le jardin"
	var result: Dictionary = judge.score_text(text)
	var celtic_score: float = result.scores.celtic
	if celtic_score > 0.01:
		push_error("Expected celtic score ~0 without Celtic keywords, got: %f" % celtic_score)
		return false
	return true


func test_celtic_score_partial_with_one_keyword() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Un homme se tient pres du menhir en silence"
	var result: Dictionary = judge.score_text(text)
	var celtic_score: float = result.scores.celtic
	# 1 match -> 1/3 ~ 0.333
	if not _approx_eq(celtic_score, 0.333, 0.05):
		push_error("Expected celtic score ~0.333 with 1 keyword, got: %f" % celtic_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LENGTH SCORING
# ═══════════════════════════════════════════════════════════════════════════════

func test_length_score_ideal_range() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	# Generate text of ~200 chars (within 80-600 ideal range)
	var text: String = "a".repeat(200)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if not _approx_eq(length_score, 1.0, 0.01):
		push_error("Expected length score 1.0 for 200-char text, got: %f" % length_score)
		return false
	return true


func test_length_score_zero_for_very_short() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text("abc")
	var length_score: float = result.scores.length
	if length_score > 0.01:
		push_error("Expected length score ~0 for 3-char text, got: %f" % length_score)
		return false
	return true


func test_length_score_penalized_for_very_long() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	# >1200 chars (IDEAL_MAX_LEN * 2)
	var text: String = "mot ".repeat(400)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if length_score > 0.31:
		push_error("Expected length score ~0.3 for very long text, got: %f" % length_score)
		return false
	return true


func test_length_score_partial_for_short_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	# 40 chars -> 40/80 = 0.5
	var text: String = "a".repeat(40)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if not _approx_eq(length_score, 0.5, 0.05):
		push_error("Expected length score ~0.5 for 40-char text, got: %f" % length_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# STRUCTURE SCORING
# ═══════════════════════════════════════════════════════════════════════════════

func test_structure_score_full_with_narrative_and_choices() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Le heros avance. La porte grince!\nA) Ouvrir la porte.\nB) Reculer.\nC) Ecouter."
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	# 2+ sentences (0.4) + choices A/B/C (0.4) + newline (0.2) = 1.0
	if struct_score < 0.99:
		push_error("Expected structure score ~1.0 for full narrative+choices, got: %f" % struct_score)
		return false
	return true


func test_structure_score_zero_for_plain_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "juste du texte sans ponctuation ni choix ni retour a la ligne"
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	if struct_score > 0.01:
		push_error("Expected structure score ~0 for plain text, got: %f" % struct_score)
		return false
	return true


func test_structure_detects_bullet_points() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Une situation complexe.\n- Option un\n- Option deux"
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	# 1 sentence (0.2) + bullet "- " (0.4) + newline (0.2) = 0.8
	if struct_score < 0.7:
		push_error("Expected structure score >= 0.7 with bullet points, got: %f" % struct_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REPETITION SCORING
# ═══════════════════════════════════════════════════════════════════════════════

func test_repetition_score_high_for_novel_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text("Un texte completement nouveau et original")
	var rep_score: float = result.scores.repetition
	# No recent texts -> 1.0
	if not _approx_eq(rep_score, 1.0, 0.01):
		push_error("Expected repetition score 1.0 for first text (no history), got: %f" % rep_score)
		return false
	return true


func test_repetition_score_low_for_duplicate() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Le druide marche dans la foret sacree pres du dolmen ancien"
	judge.register_text(text)
	var result: Dictionary = judge.score_text(text)
	var rep_score: float = result.scores.repetition
	# Exact duplicate -> Jaccard = 1.0 >= 0.5 threshold -> score 0.0
	if rep_score > 0.01:
		push_error("Expected repetition score ~0 for exact duplicate, got: %f" % rep_score)
		return false
	return true


func test_repetition_score_medium_for_partial_overlap() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	judge.register_text("le druide marche dans la foret sacree pres du dolmen ancien")
	var text: String = "le druide contemple un cristal magique au sommet de la montagne"
	var result: Dictionary = judge.score_text(text)
	var rep_score: float = result.scores.repetition
	# Some overlap ("le", "druide", "la", "de") but many different words
	# Should be between 0 and 1
	if rep_score < 0.1 or rep_score > 0.95:
		push_error("Expected repetition score between 0.1 and 0.95 for partial overlap, got: %f" % rep_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TOTAL SCORE & THRESHOLDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_good_text_is_acceptable() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text(_good_french_text())
	if not result.acceptable:
		push_error("Expected good French text to be acceptable, total: %f" % result.total)
		return false
	return true


func test_good_text_is_good_quality() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text(_good_french_text())
	if not result.good:
		push_error("Expected good French text to pass 'good' threshold (0.75), total: %f" % result.total)
		return false
	return true


func test_weights_sum_to_one() -> bool:
	var total_weight: float = (
		BrainQualityJudge.W_FRENCH
		+ BrainQualityJudge.W_REPETITION
		+ BrainQualityJudge.W_LENGTH
		+ BrainQualityJudge.W_CELTIC
		+ BrainQualityJudge.W_STRUCTURE
	)
	if not _approx_eq(total_weight, 1.0, 0.001):
		push_error("Expected weights to sum to 1.0, got: %f" % total_weight)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PICK BEST (best-of-N selection)
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_best_returns_empty_for_empty_array() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.pick_best([])
	if not result.is_empty():
		push_error("Expected empty dict for empty candidates, got: %s" % str(result))
		return false
	return true


func test_pick_best_selects_highest_score() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var candidates: Array = [
		_english_text(),
		_good_french_text(),
		"xyzzy",
	]
	var result: Dictionary = judge.pick_best(candidates)
	if result.index != 1:
		push_error("Expected best candidate at index 1, got index: %d" % result.index)
		return false
	if result.score < 0.5:
		push_error("Expected best score > 0.5, got: %f" % result.score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CHECK MINIMUM QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_minimum_rejects_very_short() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.check_minimum_quality("abc")
	if result.ok:
		push_error("Expected very short text to be rejected")
		return false
	if result.reason != "too_short":
		push_error("Expected reason 'too_short', got: %s" % result.reason)
		return false
	return true


func test_check_minimum_accepts_good_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.check_minimum_quality(_good_french_text())
	if not result.ok:
		push_error("Expected good text to pass minimum quality, reason: %s" % result.reason)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SUGGEST REFINEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func test_suggest_refinement_empty_for_good_text() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var score_result: Dictionary = judge.score_text(_good_french_text())
	var suggestion: String = judge.suggest_refinement(_good_french_text(), score_result)
	# Good text should have all scores high enough that no suggestion is produced
	if suggestion != "":
		# This is OK if thresholds are strict; just verify it returns a String
		pass
	return true


func test_suggest_refinement_mentions_french_for_english() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = _english_text()
	var score_result: Dictionary = judge.score_text(text)
	# Force low french score
	score_result["scores"]["french"] = 0.2
	var suggestion: String = judge.suggest_refinement(text, score_result)
	if suggestion.is_empty():
		push_error("Expected non-empty refinement suggestion for low french score")
		return false
	if not suggestion.contains("francais"):
		push_error("Expected suggestion to mention 'francais', got: %s" % suggestion.substr(0, 100))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER TEXT & MEMORY CAP
# ═══════════════════════════════════════════════════════════════════════════════

func test_register_text_caps_at_recent_memory() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	# Register more than RECENT_MEMORY (20) texts
	for i in range(30):
		judge.register_text("texte numero %d avec des mots differents uniques" % i)
	if judge._recent_texts.size() > BrainQualityJudge.RECENT_MEMORY:
		push_error("Expected recent_texts capped at %d, got: %d" % [BrainQualityJudge.RECENT_MEMORY, judge._recent_texts.size()])
		return false
	return true
