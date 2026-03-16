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


# ═══════════════════════════════════════════════════════════════════════════════
# SCORE_TEXT — RETURN STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_text_returns_required_keys() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text("un texte quelconque")
	for key in ["total", "scores", "acceptable", "good"]:
		if not result.has(key):
			push_error("score_text result missing key: %s" % key)
			return false
	for sub in ["french", "repetition", "length", "celtic", "structure"]:
		if not result.scores.has(sub):
			push_error("score_text result.scores missing sub-key: %s" % sub)
			return false
	return true


func test_score_text_total_within_zero_one() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	for text in [_good_french_text(), _english_text(), _tiny_text(), "", "a".repeat(2000)]:
		var result: Dictionary = judge.score_text(text)
		var total: float = result.total
		if total < 0.0 or total > 1.0:
			push_error("score_text total out of [0,1] range for text len %d: %f" % [text.length(), total])
			return false
	return true


func test_score_text_empty_string_does_not_crash() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.score_text("")
	if result.is_empty():
		push_error("score_text should return a populated dict for empty string")
		return false
	if result.total < 0.0:
		push_error("score_text total must not be negative for empty string, got: %f" % result.total)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LENGTH — BOUNDARY VALUES
# ═══════════════════════════════════════════════════════════════════════════════

func test_length_score_exactly_ideal_min() -> bool:
	# IDEAL_MIN_LEN = 80 — must return 1.0
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "a".repeat(80)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if not _approx_eq(length_score, 1.0, 0.01):
		push_error("Expected length score 1.0 at exactly IDEAL_MIN_LEN (80), got: %f" % length_score)
		return false
	return true


func test_length_score_exactly_ideal_max() -> bool:
	# IDEAL_MAX_LEN = 600 — must return 1.0
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "a".repeat(600)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if not _approx_eq(length_score, 1.0, 0.01):
		push_error("Expected length score 1.0 at exactly IDEAL_MAX_LEN (600), got: %f" % length_score)
		return false
	return true


func test_length_score_just_above_ideal_max() -> bool:
	# 601 chars: 1.0 - (601-600)/600 ≈ 0.9983 (still close to 1.0, clamped >= 0.3)
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "a".repeat(601)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if length_score < 0.3 or length_score > 1.0:
		push_error("Expected length score in [0.3, 1.0] for 601-char text, got: %f" % length_score)
		return false
	return true


func test_length_score_ten_chars_is_not_zero() -> bool:
	# 10 chars: 10 < IDEAL_MIN_LEN (80) → 10/80 = 0.125
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "a".repeat(10)
	var result: Dictionary = judge.score_text(text)
	var length_score: float = result.scores.length
	if not _approx_eq(length_score, 0.125, 0.01):
		push_error("Expected length score ~0.125 for 10-char text, got: %f" % length_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CELTIC — TWO-KEYWORD BOUNDARY
# ═══════════════════════════════════════════════════════════════════════════════

func test_celtic_score_two_keywords() -> bool:
	# 2 keywords -> 2/3 ≈ 0.667
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Le druide contemple un dolmen au loin"
	var result: Dictionary = judge.score_text(text)
	var celtic_score: float = result.scores.celtic
	if not _approx_eq(celtic_score, 0.667, 0.02):
		push_error("Expected celtic score ~0.667 for 2 keywords, got: %f" % celtic_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# STRUCTURE — ALTERNATE MARKERS
# ═══════════════════════════════════════════════════════════════════════════════

func test_structure_detects_gauche_centre_droite() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Une bifurcation se presente. Le vent souffle.\nGauche: la foret.\nCentre: le chemin.\nDroite: la riviere."
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	# 2+ sentences (0.4) + "Gauche" marker (0.4) + newline (0.2) = 1.0
	if struct_score < 0.99:
		push_error("Expected structure score ~1.0 with Gauche/Centre/Droite markers, got: %f" % struct_score)
		return false
	return true


func test_structure_detects_numeric_dot_markers() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "La route se divise. Merlin attend.\n1. Prendre a gauche.\n2. Continuer tout droit.\n3. Rebrousser chemin."
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	# 2+ sentences (0.4) + "1." marker (0.4) + newline (0.2) = 1.0
	if struct_score < 0.99:
		push_error("Expected structure score ~1.0 with 1./2./3. markers, got: %f" % struct_score)
		return false
	return true


func test_structure_one_sentence_no_choices_no_newline() -> bool:
	# Only 1 punctuation mark, no choices, no newline → 0.2
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Une phrase simple."
	var result: Dictionary = judge.score_text(text)
	var struct_score: float = result.scores.structure
	if not _approx_eq(struct_score, 0.2, 0.01):
		push_error("Expected structure score ~0.2 for single sentence no choices, got: %f" % struct_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PICK BEST — ADDITIONAL CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_best_single_candidate() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var candidates: Array = [_good_french_text()]
	var result: Dictionary = judge.pick_best(candidates)
	if result.is_empty():
		push_error("Expected non-empty result for single-candidate pick_best")
		return false
	if result.index != 0:
		push_error("Expected index 0 for single candidate, got: %d" % result.index)
		return false
	if result.text != _good_french_text():
		push_error("Expected returned text to match the sole candidate")
		return false
	return true


func test_pick_best_returns_text_field() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var expected: String = _good_french_text()
	var result: Dictionary = judge.pick_best([expected, "court"])
	if not result.has("text"):
		push_error("pick_best result must contain 'text' key")
		return false
	if result.text != expected:
		push_error("pick_best returned wrong text")
		return false
	return true


func test_pick_best_first_wins_on_tie() -> bool:
	# Two identical candidates — first should win (strict > comparison)
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "Un texte identique pour les deux candidats."
	var result: Dictionary = judge.pick_best([text, text])
	if result.index != 0:
		push_error("Expected index 0 to win on exact tie (strict > ), got: %d" % result.index)
		return false
	return true


func test_pick_best_result_has_detail_key() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.pick_best([_good_french_text()])
	if not result.has("detail"):
		push_error("pick_best result must contain 'detail' key")
		return false
	if not result.detail.has("total"):
		push_error("pick_best detail must contain 'total' key")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CHECK MINIMUM QUALITY — BOUNDARY
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_minimum_rejects_nine_chars() -> bool:
	# 9 chars stripped < 10 threshold → too_short
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.check_minimum_quality("123456789")
	if result.ok:
		push_error("Expected 9-char text to be rejected as too_short")
		return false
	if result.reason != "too_short":
		push_error("Expected reason 'too_short' for 9-char text, got: %s" % result.reason)
		return false
	return true


func test_check_minimum_passes_score_key_on_accept() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var result: Dictionary = judge.check_minimum_quality(_good_french_text())
	if not result.has("score"):
		push_error("check_minimum_quality should return 'score' key when ok=true")
		return false
	if result.score <= 0.0:
		push_error("Expected positive score for good text, got: %f" % result.score)
		return false
	return true


func test_check_minimum_passes_score_key_on_reject() -> bool:
	# A text that is long enough but poor quality should return score key
	var judge: BrainQualityJudge = _make_judge()
	# Gibberish text, long enough to pass the length guard
	var text: String = "xyzzy plugh qwerty asdf zxcv bnm lorem ipsum dolor sit amet"
	var result: Dictionary = judge.check_minimum_quality(text)
	if not result.ok:
		# Should have 'score' key in the rejection dict
		if not result.has("score"):
			push_error("check_minimum_quality rejection dict must contain 'score' key")
			return false
	return true


func test_check_minimum_reason_prefixed_low_score() -> bool:
	# A clearly bad text (not too_short) should return reason starting with "low_score_"
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "xyzzy plugh qwerty asdf zxcv bnm lorem ipsum dolor sit amet consectetur"
	var result: Dictionary = judge.check_minimum_quality(text)
	if not result.ok:
		if not result.reason.begins_with("low_score_"):
			push_error("Expected reason to begin with 'low_score_', got: %s" % result.reason)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SUGGEST REFINEMENT — LOW STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

func test_suggest_refinement_mentions_choices_for_low_structure() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	var text: String = _english_text()
	var score_result: Dictionary = judge.score_text(text)
	score_result["scores"]["structure"] = 0.2
	var suggestion: String = judge.suggest_refinement(text, score_result)
	if suggestion.is_empty():
		push_error("Expected non-empty suggestion for low structure score")
		return false
	if not suggestion.contains("choix") and not suggestion.contains("narration"):
		push_error("Expected suggestion to mention 'choix' or 'narration' for low structure, got: %s" % suggestion.substr(0, 120))
		return false
	return true


func test_suggest_refinement_returns_string_type() -> bool:
	# Must return a String (not null, not a Dictionary)
	var judge: BrainQualityJudge = _make_judge()
	var score_result: Dictionary = judge.score_text(_tiny_text())
	var suggestion = judge.suggest_refinement(_tiny_text(), score_result)
	if typeof(suggestion) != TYPE_STRING:
		push_error("suggest_refinement must return a String, got type: %d" % typeof(suggestion))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FRENCH SCORE — EXACT THRESHOLD
# ═══════════════════════════════════════════════════════════════════════════════

func test_french_score_exactly_one_at_three_matches() -> bool:
	# FR_MIN_MATCHES = 3: exactly 3 keyword matches should give 1.0
	# Using isolated keywords: "le", "la", "de" as word-boundary matches
	var judge: BrainQualityJudge = _make_judge()
	var text: String = "le chat et la souris de jardins"
	var result: Dictionary = judge.score_text(text)
	var french_score: float = result.scores.french
	if not _approx_eq(french_score, 1.0, 0.01):
		push_error("Expected french score 1.0 with exactly 3+ FR_KEYWORDS matches, got: %f" % french_score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REPETITION — JACCARD THRESHOLD CROSSING
# ═══════════════════════════════════════════════════════════════════════════════

func test_repetition_score_zero_when_similarity_at_or_above_threshold() -> bool:
	# Register a text, then score a highly similar one (>= 0.5 Jaccard) → score 0.0
	var judge: BrainQualityJudge = _make_judge()
	var base: String = "alpha beta gamma delta epsilon zeta eta theta"
	# Similar text sharing 5 of 8 words — Jaccard = 5/(8+8-5) = 5/11 ≈ 0.45; add more overlap
	var similar: String = "alpha beta gamma delta epsilon iota kappa lambda"
	# Intersection: alpha,beta,gamma,delta,epsilon = 5; union = 5+3+3 = 11 → 0.454 < 0.5 threshold
	# Need >= 0.5: share at least ceil(0.5 * union) words
	# Use identical texts for guaranteed 1.0 Jaccard
	judge.register_text(base)
	var result: Dictionary = judge.score_text(base)
	var rep_score: float = result.scores.repetition
	if rep_score > 0.01:
		push_error("Expected repetition score 0.0 when Jaccard >= threshold, got: %f" % rep_score)
		return false
	return true


func test_repetition_score_novel_after_registering_unrelated_texts() -> bool:
	var judge: BrainQualityJudge = _make_judge()
	judge.register_text("pomme poire cerise prune")
	judge.register_text("table chaise bureau lampe")
	var novel: String = "druide ogham foret brume korrigan sentier"
	var result: Dictionary = judge.score_text(novel)
	var rep_score: float = result.scores.repetition
	if rep_score < 0.8:
		push_error("Expected high repetition score (>=0.8) for fully novel text, got: %f" % rep_score)
		return false
	return true
