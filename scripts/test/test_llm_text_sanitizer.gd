## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — LlmAdapterTextSanitizer
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: extract_verb_from_label, split_verb_desc, strip_meta_and_leakage,
## strip_choice_lines, strip_scenario_echo, strip_markdown, enforce_length,
## enforce_pronouns, extract_verbs_relaxed.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_sanitizer() -> LlmAdapterTextSanitizer:
	return LlmAdapterTextSanitizer.new()


# ═══════════════════════════════════════════════════════════════════════════════
# extract_verb_from_label
# ═══════════════════════════════════════════════════════════════════════════════

func test_extract_verb_normal() -> bool:
	var s := _make_sanitizer()
	var result: String = s.extract_verb_from_label("Avancer prudemment")
	if result != "avancer":
		push_error("extract_verb_from_label: expected 'avancer', got '%s'" % result)
		return false
	return true


func test_extract_verb_empty() -> bool:
	var s := _make_sanitizer()
	var result: String = s.extract_verb_from_label("")
	# Empty string split produces [""], so returns "" (not "agir")
	if result != "":
		push_error("extract_verb_from_label empty: expected '', got '%s'" % result)
		return false
	return true


func test_extract_verb_single_word() -> bool:
	var s := _make_sanitizer()
	var result: String = s.extract_verb_from_label("FUIR")
	if result != "fuir":
		push_error("extract_verb_from_label single: expected 'fuir', got '%s'" % result)
		return false
	return true


func test_extract_verb_whitespace_only() -> bool:
	var s := _make_sanitizer()
	var result: String = s.extract_verb_from_label("   ")
	# strip_edges() → "" → split → [""] → returns ""
	if result != "":
		push_error("extract_verb_from_label whitespace: expected '', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# split_verb_desc
# ═══════════════════════════════════════════════════════════════════════════════

func test_split_verb_desc_em_dash() -> bool:
	var s := _make_sanitizer()
	var result: Dictionary = s.split_verb_desc("FUIR — Dans la foret")
	if str(result.get("verb", "")) != "FUIR":
		push_error("split_verb_desc em-dash verb: expected 'FUIR', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")) != "Dans la foret":
		push_error("split_verb_desc em-dash desc: expected 'Dans la foret', got '%s'" % str(result.get("desc", "")))
		return false
	return true


func test_split_verb_desc_regular_dash() -> bool:
	var s := _make_sanitizer()
	var result: Dictionary = s.split_verb_desc("FUIR - dans la nuit")
	if str(result.get("verb", "")) != "FUIR":
		push_error("split_verb_desc dash verb: expected 'FUIR', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")) != "dans la nuit":
		push_error("split_verb_desc dash desc: expected 'dans la nuit', got '%s'" % str(result.get("desc", "")))
		return false
	return true


func test_split_verb_desc_no_separator() -> bool:
	var s := _make_sanitizer()
	var result: Dictionary = s.split_verb_desc("FUIR")
	if str(result.get("verb", "")) != "FUIR":
		push_error("split_verb_desc no sep verb: expected 'FUIR', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")) != "":
		push_error("split_verb_desc no sep desc: expected '', got '%s'" % str(result.get("desc", "")))
		return false
	return true


func test_split_verb_desc_colon_separator() -> bool:
	var s := _make_sanitizer()
	var result: Dictionary = s.split_verb_desc("EXPLORER : les ruines anciennes")
	if str(result.get("verb", "")) != "EXPLORER":
		push_error("split_verb_desc colon verb: expected 'EXPLORER', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")) != "les ruines anciennes":
		push_error("split_verb_desc colon desc: expected 'les ruines anciennes', got '%s'" % str(result.get("desc", "")))
		return false
	return true


func test_split_verb_desc_long_phrase_no_sep() -> bool:
	var s := _make_sanitizer()
	# Long phrase (>= 20 chars, has space) without separator: first word as verb
	var result: Dictionary = s.split_verb_desc("Avancer dans la clairiere sombre et brumeuse")
	if str(result.get("verb", "")) != "AVANCER":
		push_error("split_verb_desc long phrase: expected 'AVANCER', got '%s'" % str(result.get("verb", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# strip_meta_and_leakage
# ═══════════════════════════════════════════════════════════════════════════════

func test_strip_meta_choisissez() -> bool:
	var s := _make_sanitizer()
	var input := "La foret est sombre.\nChoisissez une option.\nLes arbres murmurent."
	var result: String = s.strip_meta_and_leakage(input)
	if result.to_lower().find("choisissez") >= 0:
		push_error("strip_meta: 'choisissez' line not removed: '%s'" % result)
		return false
	return true


func test_strip_meta_voici_trois() -> bool:
	var s := _make_sanitizer()
	var input := "Voici trois options pour vous.\nTu avances dans la brume."
	var result: String = s.strip_meta_and_leakage(input)
	if result.to_lower().find("voici trois") >= 0:
		push_error("strip_meta: 'voici trois' line not removed: '%s'" % result)
		return false
	return true


func test_strip_meta_keeps_narrative() -> bool:
	var s := _make_sanitizer()
	var input := "Tu marches le long du sentier. Les fougeres bruissent sous tes pas."
	var result: String = s.strip_meta_and_leakage(input)
	if result != input:
		push_error("strip_meta: narrative text modified: expected '%s', got '%s'" % [input, result])
		return false
	return true


func test_strip_meta_ai_self_reference() -> bool:
	var s := _make_sanitizer()
	var input := "La lune se leve.\nJe suis desole, je ne peux pas.\nLes etoiles brillent."
	var result: String = s.strip_meta_and_leakage(input)
	if result.to_lower().find("je suis desole") >= 0:
		push_error("strip_meta: AI self-reference not removed: '%s'" % result)
		return false
	if result.to_lower().find("la lune") < 0:
		push_error("strip_meta: narrative lost after AI ref removal: '%s'" % result)
		return false
	return true


func test_strip_meta_bracketed_content() -> bool:
	var s := _make_sanitizer()
	var input := "Tu avances [verbe a l'infinitif] dans la clairiere."
	var result: String = s.strip_meta_and_leakage(input)
	if result.find("[verbe") >= 0:
		push_error("strip_meta: bracketed content not removed: '%s'" % result)
		return false
	return true


func test_strip_meta_short_colon_header() -> bool:
	var s := _make_sanitizer()
	var input := "Mes choix :\nTu avances dans la brume."
	var result: String = s.strip_meta_and_leakage(input)
	if result.to_lower().find("mes choix") >= 0:
		push_error("strip_meta: short colon header not removed: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# strip_choice_lines
# ═══════════════════════════════════════════════════════════════════════════════

func test_strip_choice_lines_removes_abc() -> bool:
	var s := _make_sanitizer()
	var input := "La brume se leve.\nA) FUIR — courir vite\nB) RESTER — attendre\nLa foret attend."
	var result: String = s.strip_choice_lines(input)
	if result.find("FUIR") >= 0 or result.find("RESTER") >= 0:
		push_error("strip_choice_lines: choice lines not removed: '%s'" % result)
		return false
	if result.find("La brume") < 0:
		push_error("strip_choice_lines: narrative lost: '%s'" % result)
		return false
	return true


func test_strip_choice_lines_keeps_narrative() -> bool:
	var s := _make_sanitizer()
	var input := "Tu decouvres une grotte ancienne. Des runes ornent les murs."
	var result: String = s.strip_choice_lines(input)
	if result.strip_edges() != input:
		push_error("strip_choice_lines: narrative modified: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# strip_scenario_echo
# ═══════════════════════════════════════════════════════════════════════════════

func test_strip_scenario_echo_removes_header() -> bool:
	var s := _make_sanitizer()
	var input := "Scenario: Tu marches dans la foret enchantee."
	var result: String = s.strip_scenario_echo(input)
	if result.strip_edges().begins_with("Scenario"):
		push_error("strip_scenario_echo: 'Scenario:' header not stripped: '%s'" % result)
		return false
	if result.strip_edges().find("Tu marches") < 0:
		push_error("strip_scenario_echo: content after header lost: '%s'" % result)
		return false
	return true


func test_strip_scenario_echo_no_header() -> bool:
	var s := _make_sanitizer()
	var input := "Tu marches dans la foret."
	var result: String = s.strip_scenario_echo(input)
	if result != input:
		push_error("strip_scenario_echo: text without header modified: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# strip_markdown
# ═══════════════════════════════════════════════════════════════════════════════

func test_strip_markdown_bold() -> bool:
	var s := _make_sanitizer()
	var input := "Tu vois une **creature** dans les bois."
	var result: String = s.strip_markdown(input)
	if result.find("**") >= 0:
		push_error("strip_markdown: bold markers not removed: '%s'" % result)
		return false
	if result.find("creature") < 0:
		push_error("strip_markdown: content lost: '%s'" % result)
		return false
	return true


func test_strip_markdown_header() -> bool:
	var s := _make_sanitizer()
	var input := "### La clairiere enchantee dans la brume du matin\nTu avances."
	var result: String = s.strip_markdown(input)
	if result.find("###") >= 0:
		push_error("strip_markdown: header markers not removed: '%s'" % result)
		return false
	if result.find("clairiere") < 0:
		push_error("strip_markdown: header content lost: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# enforce_length
# ═══════════════════════════════════════════════════════════════════════════════

func test_enforce_length_under_limit() -> bool:
	var s := _make_sanitizer()
	var input := "Tu marches dans la foret."
	var result: String = s.enforce_length(input, 350, 120)
	if result != input:
		push_error("enforce_length under limit: text changed: '%s'" % result)
		return false
	return true


func test_enforce_length_cuts_at_sentence() -> bool:
	var s := _make_sanitizer()
	# Build text longer than 200 chars with sentence boundaries
	var input := "Tu marches dans la foret sombre. Les arbres murmurent autour de toi. " + \
		"Le vent souffle entre les branches. La lune eclaire le sentier. " + \
		"Des creatures se cachent dans les ombres. Tu sens une presence derriere toi."
	var result: String = s.enforce_length(input, 200, 50)
	if result.length() > 200:
		push_error("enforce_length: result too long: %d chars (max 200)" % result.length())
		return false
	# Should end at a sentence boundary (period)
	var trimmed: String = result.strip_edges()
	if not trimmed.ends_with(".") and not trimmed.ends_with("!") and not trimmed.ends_with("?"):
		push_error("enforce_length: did not cut at sentence boundary: '%s'" % trimmed)
		return false
	return true


func test_enforce_length_respects_min_cut() -> bool:
	var s := _make_sanitizer()
	# Text with an early period and late period; min_cut should prevent cutting too early
	var input := "A. " + "B".repeat(300)
	var result: String = s.enforce_length(input, 200, 120)
	# The period at position 1 is before min_cut=120, so it should NOT cut there
	if result.length() <= 5:
		push_error("enforce_length min_cut: cut too early, len=%d" % result.length())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# enforce_pronouns
# ═══════════════════════════════════════════════════════════════════════════════

func test_enforce_pronouns_nous() -> bool:
	var s := _make_sanitizer()
	var input := "Nous marchons dans la foret."
	var result: String = s.enforce_pronouns(input)
	if result.find("Nous ") >= 0:
		push_error("enforce_pronouns: 'Nous' not replaced: '%s'" % result)
		return false
	if result.find("Tu ") < 0:
		push_error("enforce_pronouns: 'Tu' not present: '%s'" % result)
		return false
	return true


func test_enforce_pronouns_il_entre() -> bool:
	var s := _make_sanitizer()
	var input := "Il entre dans la grotte."
	var result: String = s.enforce_pronouns(input)
	if result.find("Il entre") >= 0:
		push_error("enforce_pronouns: 'Il entre' not replaced: '%s'" % result)
		return false
	if result.find("Tu entres") < 0:
		push_error("enforce_pronouns: 'Tu entres' not present: '%s'" % result)
		return false
	return true


func test_enforce_pronouns_le_voyageur() -> bool:
	var s := _make_sanitizer()
	var input := "Le voyageur marche dans la brume."
	var result: String = s.enforce_pronouns(input)
	if result.find("Le voyageur") >= 0:
		push_error("enforce_pronouns: 'Le voyageur' not replaced: '%s'" % result)
		return false
	if result.find("Tu ") < 0:
		push_error("enforce_pronouns: 'Tu' not present: '%s'" % result)
		return false
	return true


func test_enforce_pronouns_fairy_tale() -> bool:
	var s := _make_sanitizer()
	var input := "Il était une fois un druide. Le druide parlait aux arbres."
	var result: String = s.enforce_pronouns(input)
	if result.begins_with("Il était une fois"):
		push_error("enforce_pronouns: fairy tale opening not stripped: '%s'" % result)
		return false
	return true


func test_enforce_pronouns_je_suis() -> bool:
	var s := _make_sanitizer()
	var input := "Je suis dans la clairiere."
	var result: String = s.enforce_pronouns(input)
	if result.find("Je suis") >= 0:
		push_error("enforce_pronouns: 'Je suis' not replaced: '%s'" % result)
		return false
	if result.find("Tu es") < 0:
		push_error("enforce_pronouns: 'Tu es' not present: '%s'" % result)
		return false
	return true


func test_enforce_pronouns_no_change_needed() -> bool:
	var s := _make_sanitizer()
	var input := "Tu avances dans la foret. Les fougeres bruissent."
	var result: String = s.enforce_pronouns(input)
	if result != input:
		push_error("enforce_pronouns: text changed when no pronoun fix needed: '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# extract_verbs_relaxed
# ═══════════════════════════════════════════════════════════════════════════════

func test_extract_verbs_relaxed_finds_infinitives() -> bool:
	var s := _make_sanitizer()
	var input := "Tu peux explorer la grotte ou chercher un sentier."
	var result: Array[Dictionary] = s.extract_verbs_relaxed(input)
	if result.size() < 1:
		push_error("extract_verbs_relaxed: expected at least 1 verb, got 0")
		return false
	var verbs: Array[String] = []
	for entry in result:
		verbs.append(str(entry.get("verb", "")))
	if "EXPLORER" not in verbs and "CHERCHER" not in verbs:
		push_error("extract_verbs_relaxed: expected EXPLORER or CHERCHER in %s" % str(verbs))
		return false
	return true


func test_extract_verbs_relaxed_skips_non_verbs() -> bool:
	var s := _make_sanitizer()
	var input := "Le dernier premier sentier mene a la riviere et la lumiere."
	var result: Array[Dictionary] = s.extract_verbs_relaxed(input)
	var verbs: Array[String] = []
	for entry in result:
		verbs.append(str(entry.get("verb", "")))
	if "DERNIER" in verbs:
		push_error("extract_verbs_relaxed: should skip 'DERNIER' but found in %s" % str(verbs))
		return false
	if "PREMIER" in verbs:
		push_error("extract_verbs_relaxed: should skip 'PREMIER' but found in %s" % str(verbs))
		return false
	return true


func test_extract_verbs_relaxed_max_three() -> bool:
	var s := _make_sanitizer()
	var input := "Tu peux marcher, courir, nager, voler, chanter dans la foret."
	var result: Array[Dictionary] = s.extract_verbs_relaxed(input)
	if result.size() > 3:
		push_error("extract_verbs_relaxed: expected max 3, got %d" % result.size())
		return false
	return true


func test_extract_verbs_relaxed_empty_text() -> bool:
	var s := _make_sanitizer()
	var result: Array[Dictionary] = s.extract_verbs_relaxed("")
	if result.size() != 0:
		push_error("extract_verbs_relaxed empty: expected 0, got %d" % result.size())
		return false
	return true


func test_extract_verbs_relaxed_skips_common_nouns() -> bool:
	var s := _make_sanitizer()
	var input := "La lumiere de la pierre eclaire la riviere."
	var result: Array[Dictionary] = s.extract_verbs_relaxed(input)
	var verbs: Array[String] = []
	for entry in result:
		verbs.append(str(entry.get("verb", "")))
	if "LUMIERE" in verbs:
		push_error("extract_verbs_relaxed: should skip 'LUMIERE' but found in %s" % str(verbs))
		return false
	if "PIERRE" in verbs:
		push_error("extract_verbs_relaxed: should skip 'PIERRE' but found in %s" % str(verbs))
		return false
	if "RIVIERE" in verbs:
		push_error("extract_verbs_relaxed: should skip 'RIVIERE' but found in %s" % str(verbs))
		return false
	return true
