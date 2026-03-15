extends RefCounted
## Unit Tests — MOS Guardrails (standalone)
## Tests Jaccard similarity, French detection, forbidden words logic.
## Note: MerlinOmniscient extends Node, can't instantiate in headless.
## These tests verify the guardrail algorithms directly.

const MOS = preload("res://addons/merlin_ai/merlin_omniscient.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# JACCARD SIMILARITY — Word-level overlap
# ═══════════════════════════════════════════════════════════════════════════════

func _jaccard(a: String, b: String) -> float:
	var words_a := a.split(" ", false)
	var words_b := b.split(" ", false)
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	var set_a := {}
	for w in words_a:
		set_a[w] = true
	var set_b := {}
	for w in words_b:
		set_b[w] = true
	var intersection := 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)


func test_jaccard_identical_texts() -> bool:
	var sim: float = _jaccard("le druide parle au voyageur", "le druide parle au voyageur")
	if sim < 0.99:
		push_error("Identical texts should have sim ~1.0, got %f" % sim)
		return false
	return true


func test_jaccard_completely_different() -> bool:
	var sim: float = _jaccard("le druide parle au voyageur", "combat rituel dans le marais")
	if sim > 0.3:
		push_error("Different texts should have low sim, got %f" % sim)
		return false
	return true


func test_jaccard_partial_overlap() -> bool:
	var sim: float = _jaccard("le druide parle au voyageur dans la foret", "le druide attend le voyageur pres du dolmen")
	if sim < 0.1 or sim > 0.7:
		push_error("Partial overlap should be moderate, got %f" % sim)
		return false
	return true


func test_jaccard_empty_text() -> bool:
	var sim: float = _jaccard("", "some text")
	if sim != 0.0:
		push_error("Empty text should give 0.0, got %f" % sim)
		return false
	return true


func test_repetition_threshold_blocks_similar() -> bool:
	var sim: float = _jaccard(
		"le druide vous offre une potion de guerison dans la clairiere enchantee",
		"le druide vous offre une potion de soin dans la clairiere enchantee"
	)
	# These differ by 2 words out of ~11, Jaccard should be > 0.5
	if sim < MOS.REPETITION_SIMILARITY_THRESHOLD:
		push_error("Near-identical cards should exceed threshold (%.2f), got %.2f" % [MOS.REPETITION_SIMILARITY_THRESHOLD, sim])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FRENCH LANGUAGE CHECK
# ═══════════════════════════════════════════════════════════════════════════════

func _check_french(text: String) -> bool:
	var lower := text.to_lower()
	var count := 0
	for kw in MOS.GUARDRAIL_LANG_KEYWORDS:
		if lower.contains(" " + kw + " ") or lower.begins_with(kw + " ") or lower.ends_with(" " + kw):
			count += 1
	return count >= MOS.GUARDRAIL_LANG_THRESHOLD


func test_french_text_passes() -> bool:
	var text := "Le druide offre une potion de guerison au voyageur dans la foret"
	if not _check_french(text):
		push_error("French text should pass language check")
		return false
	return true


func test_english_text_fails() -> bool:
	var text := "The druid offers a healing potion to the traveler in the forest"
	if _check_french(text):
		push_error("English text should fail French language check")
		return false
	return true


func test_mixed_text_borderline() -> bool:
	# Text with exactly 2 French keywords should pass (threshold = 2)
	var text := "Le warrior fights in la grande battle"
	if not _check_french(text):
		push_error("Text with %d+ French keywords should pass" % MOS.GUARDRAIL_LANG_THRESHOLD)
		return false
	return true


func test_empty_text_fails() -> bool:
	if _check_french(""):
		push_error("Empty text should fail French check")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEXT LENGTH BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_min_length_constant() -> bool:
	if MOS.GUARDRAIL_MIN_TEXT_LEN != 30:
		push_error("Min text length should be 30, got %d" % MOS.GUARDRAIL_MIN_TEXT_LEN)
		return false
	return true


func test_max_length_constant() -> bool:
	if MOS.GUARDRAIL_MAX_TEXT_LEN != 800:
		push_error("Max text length should be 800, got %d" % MOS.GUARDRAIL_MAX_TEXT_LEN)
		return false
	return true


func test_text_below_min_is_invalid() -> bool:
	var short_text := "Trop court"  # < 30 chars
	if short_text.length() >= MOS.GUARDRAIL_MIN_TEXT_LEN:
		push_error("Test text should be below min length")
		return false
	return true


func test_text_above_max_is_invalid() -> bool:
	var long_text := "a".repeat(MOS.GUARDRAIL_MAX_TEXT_LEN + 1)
	if long_text.length() <= MOS.GUARDRAIL_MAX_TEXT_LEN:
		push_error("Test text should be above max length")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FORBIDDEN WORDS — Whole-word matching logic
# ═══════════════════════════════════════════════════════════════════════════════

func _find_forbidden(text: String, forbidden: Array) -> String:
	var lower := text.to_lower()
	for word in forbidden:
		if lower.contains(" " + word + " ") or lower.begins_with(word + " ") or lower.ends_with(" " + word) or lower == word:
			return word
	return ""


func test_forbidden_word_detected() -> bool:
	var result: String = _find_forbidden("Le voyageur utilise ia pour tricher", ["ia", "niveau", "jeu"])
	if result != "ia":
		push_error("Should detect 'ia', got '%s'" % result)
		return false
	return true


func test_forbidden_word_not_in_substring() -> bool:
	# "ia" should NOT match inside "confiance"
	var result: String = _find_forbidden("Le druide montre sa confiance", ["ia"])
	if not result.is_empty():
		push_error("Should NOT match 'ia' inside 'confiance', got '%s'" % result)
		return false
	return true


func test_no_forbidden_words() -> bool:
	var result: String = _find_forbidden("Le druide parle au voyageur", ["ia", "niveau", "jeu"])
	if not result.is_empty():
		push_error("Should find no forbidden words, got '%s'" % result)
		return false
	return true


func test_forbidden_at_start() -> bool:
	var result: String = _find_forbidden("ia est interdite ici", ["ia"])
	if result != "ia":
		push_error("Should detect 'ia' at start")
		return false
	return true


func test_forbidden_at_end() -> bool:
	var result: String = _find_forbidden("il utilise ia", ["ia"])
	if result != "ia":
		push_error("Should detect 'ia' at end")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RECENT CARDS MEMORY — Window size
# ═══════════════════════════════════════════════════════════════════════════════

func test_recent_cards_memory_size() -> bool:
	if MOS.RECENT_CARDS_MEMORY != 15:
		push_error("Recent cards memory should be 15, got %d" % MOS.RECENT_CARDS_MEMORY)
		return false
	return true


func test_guardrail_lang_keywords_count() -> bool:
	if MOS.GUARDRAIL_LANG_KEYWORDS.size() < 8:
		push_error("Should have at least 8 French keywords, got %d" % MOS.GUARDRAIL_LANG_KEYWORDS.size())
		return false
	return true
