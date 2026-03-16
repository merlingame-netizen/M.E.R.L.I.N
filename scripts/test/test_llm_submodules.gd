## ═══════════════════════════════════════════════════════════════════════════════
## Test LLM Submodules — Unit tests for 5 LLM adapter sub-modules
## ═══════════════════════════════════════════════════════════════════════════════
## Modules tested:
##   1. LlmAdapterTextSanitizer  (text cleanup, label extraction, verb parsing)
##   2. LlmAdapterValidation     (effect codes, faction validation)
##   3. LlmAdapterJsonRepair     (JSON extraction, repair, regex fallback)
##   4. LlmAdapterPrompts        (arc phases, Jaccard, motifs, templates)
##   5. LlmAdapterGameMaster     (balance heuristic, effects, consequences)
## Pattern: func test_xxx() -> bool, push_error on failure, NO assert/await.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _sanitizer: LlmAdapterTextSanitizer
var _validator: LlmAdapterValidation
var _json_repair: LlmAdapterJsonRepair
var _prompts: LlmAdapterPrompts
var _game_master: LlmAdapterGameMaster

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	_sanitizer = LlmAdapterTextSanitizer.new()
	_validator = LlmAdapterValidation.new()
	_json_repair = LlmAdapterJsonRepair.new()
	_prompts = LlmAdapterPrompts.new()
	_game_master = LlmAdapterGameMaster.new()


func run_all() -> Dictionary:
	var tests: Array[String] = []
	var method_list := get_method_list()
	for m in method_list:
		var mname: String = str(m.get("name", ""))
		if mname.begins_with("test_"):
			tests.append(mname)

	_pass_count = 0
	_fail_count = 0

	for test_name in tests:
		var result: bool = call(test_name)
		if result:
			_pass_count += 1
		else:
			_fail_count += 1
			print("[FAIL] %s" % test_name)

	print("═══════════════════════════════════════")
	print("  LLM SUBMODULES: %d passed, %d failed / %d total" % [_pass_count, _fail_count, tests.size()])
	print("═══════════════════════════════════════")

	return {"pass": _pass_count, "fail": _fail_count, "total": tests.size()}


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE 1: LlmAdapterTextSanitizer
# ═══════════════════════════════════════════════════════════════════════════════

# --- extract_verb_from_label ---

func test_sanitizer_extract_verb_basic() -> bool:
	var result := _sanitizer.extract_verb_from_label("Plonger dans les eaux")
	if result != "plonger":
		push_error("Expected 'plonger', got '%s'" % result)
		return false
	return true


func test_sanitizer_extract_verb_single_word() -> bool:
	var result := _sanitizer.extract_verb_from_label("FUIR")
	if result != "fuir":
		push_error("Expected 'fuir', got '%s'" % result)
		return false
	return true


func test_sanitizer_extract_verb_empty() -> bool:
	var result := _sanitizer.extract_verb_from_label("")
	if result != "":
		push_error("Expected '' for empty label, got '%s'" % result)
		return false
	return true


func test_sanitizer_extract_verb_whitespace() -> bool:
	var result := _sanitizer.extract_verb_from_label("   ")
	if result != "":
		push_error("Expected '' for whitespace label, got '%s'" % result)
		return false
	return true


func test_sanitizer_extract_verb_uppercase() -> bool:
	var result := _sanitizer.extract_verb_from_label("ESCALADER les rochers")
	if result != "escalader":
		push_error("Expected 'escalader', got '%s'" % result)
		return false
	return true


# --- split_verb_desc ---

func test_sanitizer_split_verb_desc_em_dash() -> bool:
	var result := _sanitizer.split_verb_desc("PLONGER — Tu enfonces les mains")
	if str(result.get("verb", "")) != "PLONGER":
		push_error("Expected verb 'PLONGER', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")).is_empty():
		push_error("Expected non-empty desc")
		return false
	return true


func test_sanitizer_split_verb_desc_dash() -> bool:
	var result := _sanitizer.split_verb_desc("Fuir - courir dans la foret")
	if str(result.get("verb", "")) != "FUIR":
		push_error("Expected verb 'FUIR', got '%s'" % str(result.get("verb", "")))
		return false
	return true


func test_sanitizer_split_verb_desc_colon() -> bool:
	var result := _sanitizer.split_verb_desc("Graver : un ogham sur la pierre")
	if str(result.get("verb", "")) != "GRAVER":
		push_error("Expected verb 'GRAVER', got '%s'" % str(result.get("verb", "")))
		return false
	return true


func test_sanitizer_split_verb_desc_no_separator() -> bool:
	var result := _sanitizer.split_verb_desc("Plonger")
	if str(result.get("verb", "")) != "PLONGER":
		push_error("Expected verb 'PLONGER', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")) != "":
		push_error("Expected empty desc for single word")
		return false
	return true


func test_sanitizer_split_verb_desc_long_phrase() -> bool:
	var result := _sanitizer.split_verb_desc("Plonger dans les eaux sombres et froides du lac ancien")
	if str(result.get("verb", "")) != "PLONGER":
		push_error("Expected verb 'PLONGER', got '%s'" % str(result.get("verb", "")))
		return false
	if str(result.get("desc", "")).is_empty():
		push_error("Expected non-empty desc for long phrase")
		return false
	return true


# --- strip_meta_and_leakage ---

func test_sanitizer_strip_meta_choisissez() -> bool:
	var text := "Choisissez une option parmi les suivantes.\nTu marches dans la foret."
	var result := _sanitizer.strip_meta_and_leakage(text)
	if result.find("choisissez") >= 0 or result.find("Choisissez") >= 0:
		push_error("Meta line 'choisissez' not stripped")
		return false
	if result.find("Tu marches") < 0:
		push_error("Narrative line lost during stripping")
		return false
	return true


func test_sanitizer_strip_meta_ai_self_ref() -> bool:
	var text := "Je m'excuse pour cette erreur.\nLa brume envahit la clairiere."
	var result := _sanitizer.strip_meta_and_leakage(text)
	if result.find("excuse") >= 0:
		push_error("AI self-reference not stripped")
		return false
	if result.find("brume") < 0:
		push_error("Narrative line lost")
		return false
	return true


func test_sanitizer_strip_meta_prompt_leak() -> bool:
	var text := "[verbe a l'infinitif en majuscules]\nTu sens une presence."
	var result := _sanitizer.strip_meta_and_leakage(text)
	if result.find("[") >= 0:
		push_error("Bracketed leak not stripped")
		return false
	return true


func test_sanitizer_strip_meta_preserves_narrative() -> bool:
	var text := "Tu decouvres une source bouillonnante entre les racines.\nL'eau noircit et une voix chante depuis les profondeurs."
	var result := _sanitizer.strip_meta_and_leakage(text)
	if result.find("source bouillonnante") < 0:
		push_error("Narrative content lost when no meta present")
		return false
	return true


func test_sanitizer_strip_meta_short_colon_line() -> bool:
	var text := "Voici mes choix :\nTu avances dans les tenebres."
	var result := _sanitizer.strip_meta_and_leakage(text)
	if result.find("Voici mes choix") >= 0:
		push_error("Short colon header not stripped")
		return false
	return true


# --- strip_choice_lines ---

func test_sanitizer_strip_choice_lines() -> bool:
	var text := "Tu marches.\nA) PLONGER — Tu plonges.\nB) FUIR — Tu fuis.\nFin."
	var result := _sanitizer.strip_choice_lines(text)
	if result.find("PLONGER") >= 0 or result.find("FUIR") >= 0:
		push_error("Choice lines not stripped")
		return false
	if result.find("Tu marches") < 0:
		push_error("Non-choice lines lost")
		return false
	return true


# --- strip_scenario_echo ---

func test_sanitizer_strip_scenario_echo() -> bool:
	var text := "Scenario: La foret mysterieuse\nTu avances."
	var result := _sanitizer.strip_scenario_echo(text)
	if result.strip_edges().begins_with("Scenario"):
		push_error("Scenario echo not stripped")
		return false
	if result.find("foret mysterieuse") < 0:
		push_error("Content after colon lost")
		return false
	return true


func test_sanitizer_strip_scenario_echo_situation() -> bool:
	var text := "Situation : un dilemme ancien\nTu hesites."
	var result := _sanitizer.strip_scenario_echo(text)
	if result.find("Situation") >= 0:
		push_error("Situation echo not stripped")
		return false
	return true


# --- strip_markdown ---

func test_sanitizer_strip_markdown_bold() -> bool:
	var text := "**Une lumiere** apparait *dans la nuit*."
	var result := _sanitizer.strip_markdown(text)
	if result.find("**") >= 0 or result.find("*") >= 0:
		push_error("Markdown bold/italic markers not stripped")
		return false
	if result.find("lumiere") < 0:
		push_error("Content lost during markdown stripping")
		return false
	return true


func test_sanitizer_strip_markdown_headers() -> bool:
	var text := "### Scene de la foret\nTu avances."
	var result := _sanitizer.strip_markdown(text)
	if result.find("###") >= 0:
		push_error("Header markers not stripped")
		return false
	return true


# --- enforce_length ---

func test_sanitizer_enforce_length_under_limit() -> bool:
	var text := "Court texte."
	var result := _sanitizer.enforce_length(text, 350, 120)
	if result != "Court texte.":
		push_error("Short text should not be modified")
		return false
	return true


func test_sanitizer_enforce_length_over_limit() -> bool:
	# Build a text longer than 350 chars
	var text := ""
	for i in range(40):
		text += "Mot%d. " % i
	var result := _sanitizer.enforce_length(text, 350, 10)
	if result.length() > 350:
		push_error("Text should be capped at ~350 chars, got %d" % result.length())
		return false
	return true


func test_sanitizer_enforce_length_sentence_boundary() -> bool:
	var text := "Premiere phrase courte. Deuxieme phrase plus longue qui devrait etre gardee. Troisieme phrase."
	var result := _sanitizer.enforce_length(text, 60, 10)
	# Should cut at a sentence boundary
	if not result.ends_with("."):
		push_error("enforce_length should cut at sentence boundary (ends with '.')")
		return false
	return true


func test_sanitizer_enforce_length_custom_params() -> bool:
	var text := "A. B. C. D. E. F. G. H. I. J. K. L. M. N."
	var result := _sanitizer.enforce_length(text, 20, 5)
	if result.length() > 20:
		push_error("Custom max_chars not respected")
		return false
	return true


# --- enforce_pronouns ---

func test_sanitizer_enforce_pronouns_je() -> bool:
	var text := "Je suis perdu dans la foret."
	var result := _sanitizer.enforce_pronouns(text)
	if result.find("Je suis") >= 0:
		push_error("'Je suis' should be replaced by 'Tu es'")
		return false
	if result.find("Tu es") < 0:
		push_error("Expected 'Tu es' in result")
		return false
	return true


func test_sanitizer_enforce_pronouns_il() -> bool:
	var text := "Il marche dans la brume."
	var result := _sanitizer.enforce_pronouns(text)
	if result.find("Il marche") >= 0:
		push_error("'Il marche' should be replaced by 'Tu marches'")
		return false
	return true


func test_sanitizer_enforce_pronouns_nous() -> bool:
	var text := "Nous avançons sur le chemin. Nos pieds glissent."
	var result := _sanitizer.enforce_pronouns(text)
	if result.find(" nous ") >= 0 or result.find("Nous ") >= 0:
		push_error("'nous' should be replaced")
		return false
	if result.find("nos pieds") >= 0:
		push_error("'nos pieds' should be 'tes pieds'")
		return false
	return true


func test_sanitizer_enforce_pronouns_tu_unchanged() -> bool:
	var text := "Tu decouvres un sentier cache."
	var result := _sanitizer.enforce_pronouns(text)
	if result != text:
		push_error("Text already in 'tu' should not be modified")
		return false
	return true


# --- build_result_text ---

func test_sanitizer_build_result_success() -> bool:
	var effect := {"type": "HEAL_LIFE", "amount": 5}
	var result := _sanitizer.build_result_text("plonger", "Plonger dans l'eau", effect, true)
	if result.is_empty():
		push_error("Success result text should not be empty")
		return false
	if result.find("vigueur") < 0:
		push_error("HEAL_LIFE success should mention 'vigueur'")
		return false
	return true


func test_sanitizer_build_result_failure() -> bool:
	var effect := {"type": "DAMAGE_LIFE", "amount": 3}
	var result := _sanitizer.build_result_text("fuir", "Fuir le danger", effect, false)
	if result.is_empty():
		push_error("Failure result text should not be empty")
		return false
	if result.find("douleur") < 0:
		push_error("DAMAGE_LIFE failure should mention 'douleur'")
		return false
	return true


func test_sanitizer_build_result_anam_success() -> bool:
	var effect := {"type": "ADD_ANAM", "amount": 2}
	var result := _sanitizer.build_result_text("invoquer", "Invoquer les esprits", effect, true)
	if result.find("Anam") < 0:
		push_error("ADD_ANAM success should mention 'Anam'")
		return false
	return true


func test_sanitizer_build_result_karma_success() -> bool:
	var effect := {"type": "ADD_KARMA", "amount": 3}
	var result := _sanitizer.build_result_text("mediter", "Mediter", effect, true)
	if result.find("karmique") < 0:
		push_error("ADD_KARMA success should mention 'karmique'")
		return false
	return true


# --- extract_labels_from_text ---

func test_sanitizer_extract_labels_abc() -> bool:
	var text := "Tu decouvres une grotte.\nA) PLONGER — Tu entres dans la grotte\nB) GRAVER — Tu traces un symbole\nC) SIFFLER — Tu appelles les esprits"
	var labels := _sanitizer.extract_labels_from_text(text)
	if labels.size() < 3:
		push_error("Expected 3 labels, got %d" % labels.size())
		return false
	if str(labels[0].get("verb", "")) != "PLONGER":
		push_error("First verb should be PLONGER, got '%s'" % str(labels[0].get("verb", "")))
		return false
	return true


func test_sanitizer_extract_labels_numbered() -> bool:
	var text := "Scene.\n1) CREUSER — fouiller\n2) NAGER — traverser\n3) GRIMPER — escalader"
	var labels := _sanitizer.extract_labels_from_text(text)
	if labels.size() < 3:
		push_error("Expected 3 labels from numbered format, got %d" % labels.size())
		return false
	return true


func test_sanitizer_extract_labels_rejects_determinants() -> bool:
	var text := "A) Le chemin est sombre\nB) La foret est dense\nC) PLONGER — dans l'eau"
	var labels := _sanitizer.extract_labels_from_text(text)
	for l in labels:
		var verb: String = str(l.get("verb", ""))
		if verb in ["LE", "LA"]:
			push_error("Determinant '%s' should be rejected as verb" % verb)
			return false
	return true


func test_sanitizer_extract_labels_rejects_overused() -> bool:
	var text := "A) AVANCER — continuer\nB) OBSERVER — regarder\nC) PLONGER — nager"
	var labels := _sanitizer.extract_labels_from_text(text)
	for l in labels:
		var verb: String = str(l.get("verb", ""))
		if verb in ["AVANCER", "OBSERVER"]:
			push_error("Overused verb '%s' should be rejected" % verb)
			return false
	return true


func test_sanitizer_extract_labels_max_three() -> bool:
	var text := "A) PLONGER — a\nB) GRAVER — b\nC) SIFFLER — c\nD) NAGER — d"
	var labels := _sanitizer.extract_labels_from_text(text)
	if labels.size() > 3:
		push_error("Labels should be capped at 3, got %d" % labels.size())
		return false
	return true


# --- extract_verbs_relaxed ---

func test_sanitizer_extract_verbs_relaxed() -> bool:
	var text := "Il faudrait plonger dans le lac ou escalader la falaise. Peut-etre graver un symbole."
	var labels := _sanitizer.extract_verbs_relaxed(text)
	if labels.size() < 1:
		push_error("Relaxed extraction should find at least 1 verb")
		return false
	var found_verbs: Array[String] = []
	for l in labels:
		found_verbs.append(str(l.get("verb", "")))
	# At least one of these should be found
	var found_any := false
	for v in ["PLONGER", "ESCALADER", "GRAVER"]:
		if v in found_verbs:
			found_any = true
			break
	if not found_any:
		push_error("Expected at least one of PLONGER/ESCALADER/GRAVER in relaxed extraction")
		return false
	return true


func test_sanitizer_extract_verbs_relaxed_excludes_nouns() -> bool:
	var text := "La lumiere brille sur la pierre ancienne. Le dernier sentier."
	var labels := _sanitizer.extract_verbs_relaxed(text)
	for l in labels:
		var verb: String = str(l.get("verb", ""))
		if verb in ["DERNIER", "SENTIER", "LUMIERE", "PIERRE"]:
			push_error("Noun '%s' should be excluded from relaxed verbs" % verb)
			return false
	return true


func test_sanitizer_extract_verbs_relaxed_max_three() -> bool:
	var text := "Plonger, escalader, graver, nager, courir, siffler, toucher dans la foret."
	var labels := _sanitizer.extract_verbs_relaxed(text)
	if labels.size() > 3:
		push_error("Relaxed extraction should cap at 3, got %d" % labels.size())
		return false
	return true


# --- detect_minigame ---

func test_sanitizer_detect_minigame_runes() -> bool:
	var text := "Tu decouvres un ogham grave dans la pierre. Un symbole ancien brille sous tes doigts."
	var verbs: Array[String] = ["DECHIFFRER", "GRAVER"]
	var result := _sanitizer.detect_minigame(text, verbs)
	if result.is_empty():
		push_error("Should detect 'runes' minigame with ogham+symbole+inscription keywords")
		return false
	if str(result.get("id", "")) != "runes":
		push_error("Expected minigame 'runes', got '%s'" % str(result.get("id", "")))
		return false
	return true


func test_sanitizer_detect_minigame_no_match() -> bool:
	var text := "Tu es dans une clairiere paisible."
	var verbs: Array[String] = ["MEDITER"]
	var result := _sanitizer.detect_minigame(text, verbs)
	if not result.is_empty():
		push_error("Should not detect minigame for generic peaceful text")
		return false
	return true


func test_sanitizer_detect_minigame_herboristerie() -> bool:
	var text := "Tu cueilles une plante rare. La racine brille sous la lune."
	var verbs: Array[String] = ["CUEILLIR"]
	var result := _sanitizer.detect_minigame(text, verbs)
	if result.is_empty():
		push_error("Should detect 'herboristerie' with plante+cueillir+racine")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE 2: LlmAdapterValidation
# ═══════════════════════════════════════════════════════════════════════════════

# --- effects_to_codes ---

func test_validation_effects_to_codes_heal() -> bool:
	var effects := [{"type": "HEAL_LIFE", "amount": 5}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code, got %d" % codes.size())
		return false
	if str(codes[0]) != "HEAL_LIFE:5":
		push_error("Expected 'HEAL_LIFE:5', got '%s'" % str(codes[0]))
		return false
	return true


func test_validation_effects_to_codes_damage() -> bool:
	var effects := [{"type": "DAMAGE_LIFE", "amount": 3}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "DAMAGE_LIFE:3":
		push_error("Expected 'DAMAGE_LIFE:3'")
		return false
	return true


func test_validation_effects_to_codes_reputation() -> bool:
	var effects := [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "ADD_REPUTATION:druides:10":
		push_error("Expected 'ADD_REPUTATION:druides:10', got '%s'" % str(codes[0] if codes.size() > 0 else ""))
		return false
	return true


func test_validation_effects_to_codes_set_flag() -> bool:
	var effects := [{"type": "SET_FLAG", "flag": "met_korrigan", "value": true}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "SET_FLAG:met_korrigan:true":
		push_error("Expected 'SET_FLAG:met_korrigan:true'")
		return false
	return true


func test_validation_effects_to_codes_add_tag() -> bool:
	var effects := [{"type": "ADD_TAG", "tag": "forest_explored"}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "ADD_TAG:forest_explored":
		push_error("Expected 'ADD_TAG:forest_explored'")
		return false
	return true


func test_validation_effects_to_codes_multiple() -> bool:
	var effects := [
		{"type": "HEAL_LIFE", "amount": 5},
		{"type": "ADD_REPUTATION", "faction": "anciens", "amount": -3},
		{"type": "ADD_ANAM", "amount": 2},
	]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 3:
		push_error("Expected 3 codes, got %d" % codes.size())
		return false
	return true


func test_validation_effects_to_codes_empty() -> bool:
	var codes := _validator.effects_to_codes([])
	if codes.size() != 0:
		push_error("Empty effects should produce empty codes")
		return false
	return true


func test_validation_effects_to_codes_non_dict() -> bool:
	var effects := ["not_a_dict", 42]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 0:
		push_error("Non-dict effects should be skipped")
		return false
	return true


func test_validation_effects_to_codes_unknown_type() -> bool:
	var effects := [{"type": "UNKNOWN_EFFECT", "amount": 5}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 0:
		push_error("Unknown effect type should produce empty code")
		return false
	return true


func test_validation_effects_to_codes_anam() -> bool:
	var effects := [{"type": "ADD_ANAM", "amount": 3}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "ADD_ANAM:3":
		push_error("Expected 'ADD_ANAM:3'")
		return false
	return true


func test_validation_effects_to_codes_biome_currency() -> bool:
	var effects := [{"type": "ADD_BIOME_CURRENCY", "amount": 2}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "ADD_BIOME_CURRENCY:2":
		push_error("Expected 'ADD_BIOME_CURRENCY:2'")
		return false
	return true


func test_validation_effects_to_codes_unlock_ogham() -> bool:
	var effects := [{"type": "UNLOCK_OGHAM", "ogham": "beith"}]
	var codes := _validator.effects_to_codes(effects)
	if codes.size() != 1 or str(codes[0]) != "UNLOCK_OGHAM:beith":
		push_error("Expected 'UNLOCK_OGHAM:beith'")
		return false
	return true


# --- validate_faction_effect ---

func test_validation_faction_effect_reputation() -> bool:
	var effect := {"type": "ADD_REPUTATION", "faction": "druides", "amount": 10.0}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Valid ADD_REPUTATION should not be rejected")
		return false
	if str(result.get("faction", "")) != "druides":
		push_error("Faction should be 'druides'")
		return false
	return true


func test_validation_faction_effect_reputation_capped() -> bool:
	var effect := {"type": "ADD_REPUTATION", "faction": "ankou", "amount": 50.0}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Should not reject, just cap amount")
		return false
	var amount: float = float(result.get("amount", 0.0))
	if amount > 20.0:
		push_error("Amount should be capped at 20, got %.1f" % amount)
		return false
	return true


func test_validation_faction_effect_reputation_negative_capped() -> bool:
	var effect := {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": -50.0}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Should not reject, just cap negative amount")
		return false
	var amount: float = float(result.get("amount", 0.0))
	if amount < -20.0:
		push_error("Amount should be capped at -20, got %.1f" % amount)
		return false
	return true


func test_validation_faction_effect_invalid_faction() -> bool:
	var effect := {"type": "ADD_REPUTATION", "faction": "invalid_faction", "amount": 5.0}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if not result.is_empty():
		push_error("Invalid faction should produce empty result")
		return false
	return true


func test_validation_faction_effect_heal_life() -> bool:
	var effect := {"type": "HEAL_LIFE", "amount": 5}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Valid HEAL_LIFE should not be rejected")
		return false
	if int(result.get("amount", 0)) != 5:
		push_error("Amount should be 5")
		return false
	return true


func test_validation_faction_effect_heal_life_capped() -> bool:
	var effect := {"type": "HEAL_LIFE", "amount": 100}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	var amount: int = int(result.get("amount", 0))
	if amount > 20:
		push_error("HEAL_LIFE amount should be capped at 20, got %d" % amount)
		return false
	return true


func test_validation_faction_effect_damage_life() -> bool:
	var effect := {"type": "DAMAGE_LIFE", "amount": 3}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Valid DAMAGE_LIFE should not be rejected")
		return false
	return true


func test_validation_faction_effect_not_allowed() -> bool:
	var effect := {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5.0}
	var allowed := ["HEAL_LIFE"]  # Restricted allowlist
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if not result.is_empty():
		push_error("Effect type not in allowed list should be rejected")
		return false
	return true


func test_validation_faction_effect_set_flag() -> bool:
	var effect := {"type": "SET_FLAG", "flag": "quest_started", "value": true}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("SET_FLAG with valid flag should not be rejected")
		return false
	if bool(result.get("value", false)) != true:
		push_error("SET_FLAG value should be true")
		return false
	return true


func test_validation_faction_effect_set_flag_empty() -> bool:
	var effect := {"type": "SET_FLAG", "flag": "", "value": true}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if not result.is_empty():
		push_error("SET_FLAG with empty flag should be rejected")
		return false
	return true


func test_validation_faction_effect_add_anam() -> bool:
	var effect := {"type": "ADD_ANAM", "amount": 5}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("Valid ADD_ANAM should not be rejected")
		return false
	var amount: int = int(result.get("amount", 0))
	if amount < 1 or amount > 10:
		push_error("ADD_ANAM amount should be clamped 1-10, got %d" % amount)
		return false
	return true


func test_validation_faction_effect_promise() -> bool:
	var effect := {"type": "CREATE_PROMISE", "promise_id": "protect_grove"}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if result.is_empty():
		push_error("CREATE_PROMISE with valid id should not be rejected")
		return false
	return true


func test_validation_faction_effect_promise_empty_id() -> bool:
	var effect := {"type": "CREATE_PROMISE", "promise_id": ""}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_effect(effect, allowed, factions)
	if not result.is_empty():
		push_error("CREATE_PROMISE with empty id should be rejected")
		return false
	return true


# --- validate_faction_card ---

func test_validation_faction_card_valid() -> bool:
	var card := {
		"text": "Tu decouvres un sentier cache.",
		"options": [
			{"label": "Plonger", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "Graver", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
			{"label": "Fuir", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8.0}]},
		],
		"speaker": "merlin",
		"tags": ["forest"],
	}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_card(card, allowed, factions)
	if not bool(result.get("ok", false)):
		push_error("Valid card should pass validation: %s" % str(result.get("errors", [])))
		return false
	return true


func test_validation_faction_card_missing_text() -> bool:
	var card := {"options": [{"label": "A", "effects": []}, {"label": "B", "effects": []}]}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_card(card, allowed, factions)
	if bool(result.get("ok", false)):
		push_error("Card without text should fail validation")
		return false
	return true


func test_validation_faction_card_two_options_gets_center() -> bool:
	var card := {
		"text": "Scene.",
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
		],
	}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_card(card, allowed, factions)
	if not bool(result.get("ok", false)):
		push_error("Two-option card should pass with auto-inserted center")
		return false
	var card_out: Dictionary = result.get("card", {})
	var options_out: Array = card_out.get("options", [])
	if options_out.size() != 3:
		push_error("Should have 3 options after center insertion, got %d" % options_out.size())
		return false
	return true


func test_validation_faction_card_adds_llm_tag() -> bool:
	var card := {
		"text": "Scene.",
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
			{"label": "C", "effects": []},
		],
	}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_card(card, allowed, factions)
	var card_out: Dictionary = result.get("card", {})
	var tags: Array = card_out.get("tags", [])
	if "llm_generated" not in tags:
		push_error("Card should have 'llm_generated' tag added")
		return false
	return true


func test_validation_faction_card_default_speaker() -> bool:
	var card := {
		"text": "Scene.",
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
			{"label": "C", "effects": []},
		],
	}
	var allowed := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var factions := MerlinLlmAdapter.FACTIONS
	var result := _validator.validate_faction_card(card, allowed, factions)
	var card_out: Dictionary = result.get("card", {})
	if str(card_out.get("speaker", "")) != "merlin":
		push_error("Default speaker should be 'merlin'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE 3: LlmAdapterJsonRepair
# ═══════════════════════════════════════════════════════════════════════════════

# --- extract_json_from_response ---

func test_json_repair_extract_clean_json() -> bool:
	var raw := '{"text": "Scene", "speaker": "merlin"}'
	var result := _json_repair.extract_json_from_response(raw)
	if result.is_empty():
		push_error("Clean JSON should parse successfully")
		return false
	if str(result.get("text", "")) != "Scene":
		push_error("Expected text 'Scene'")
		return false
	return true


func test_json_repair_extract_with_markdown() -> bool:
	var raw := "Here is the card:\n```json\n{\"text\": \"Hello\", \"speaker\": \"merlin\"}\n```"
	var result := _json_repair.extract_json_from_response(raw)
	if result.is_empty():
		push_error("JSON in markdown block should be extracted")
		return false
	if str(result.get("text", "")) != "Hello":
		push_error("Expected text 'Hello'")
		return false
	return true


func test_json_repair_extract_no_json() -> bool:
	var raw := "This is just plain text without any JSON."
	var result := _json_repair.extract_json_from_response(raw)
	# Should return empty or regex fallback (which also returns empty for no fields)
	# The function tries regex extraction as last resort
	if result.has("text"):
		push_error("No JSON in text should not produce a text field")
		return false
	return true


func test_json_repair_extract_with_prefix() -> bool:
	var raw := "Voici la carte:\n{\"text\": \"Foret\", \"speaker\": \"merlin\"}"
	var result := _json_repair.extract_json_from_response(raw)
	if result.is_empty():
		push_error("JSON with text prefix should be extracted")
		return false
	return true


# --- fix_common_json_errors ---

func test_json_repair_fix_trailing_comma() -> bool:
	var text := '{"a": 1, "b": 2,}'
	var result := _json_repair.fix_common_json_errors(text)
	var parsed = JSON.parse_string(result)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Trailing comma fix should produce valid JSON")
		return false
	return true


func test_json_repair_fix_single_quotes() -> bool:
	var text := "{'text': 'hello'}"
	var result := _json_repair.fix_common_json_errors(text)
	if result.find("'") >= 0:
		push_error("Single quotes should be replaced with double quotes")
		return false
	return true


func test_json_repair_fix_unquoted_keys() -> bool:
	var text := '{text: "hello", amount: 5}'
	var result := _json_repair.fix_common_json_errors(text)
	var parsed = JSON.parse_string(result)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Unquoted keys should be fixed, got: %s" % result)
		return false
	return true


# --- aggressive_json_repair ---

func test_json_repair_aggressive_truncated() -> bool:
	var text := '{"text": "Scene", "options": [{"label": "A"'
	var result := _json_repair.aggressive_json_repair(text)
	# Should close unclosed brackets/braces
	if result.count("{") != result.count("}"):
		push_error("Aggressive repair should balance braces")
		return false
	if result.count("[") != result.count("]"):
		push_error("Aggressive repair should balance brackets")
		return false
	return true


func test_json_repair_aggressive_control_chars() -> bool:
	var text := "{\"text\":\t\"Scene\",\r\"a\": 1}"
	var result := _json_repair.aggressive_json_repair(text)
	if result.find("\t") >= 0:
		push_error("Tab characters should be replaced")
		return false
	if result.find("\r") >= 0:
		push_error("Carriage returns should be removed")
		return false
	return true


func test_json_repair_aggressive_unclosed_string() -> bool:
	var text := '{"text": "Scene with unclosed string'
	var result := _json_repair.aggressive_json_repair(text)
	# Should close the unclosed string
	var quote_count := result.count("\"") - result.count("\\\"")
	# After repair, quotes should be balanced (even number)
	if quote_count % 2 != 0:
		push_error("Unclosed string should be closed, quote_count=%d" % quote_count)
		return false
	return true


# --- _regex_extract_card_fields ---

func test_json_repair_regex_extract() -> bool:
	var raw := 'broken json but "text": "Scene magique" and "label": "Plonger" and "label": "Fuir" and "speaker": "merlin"'
	var result := _json_repair._regex_extract_card_fields(raw)
	if result.is_empty():
		push_error("Regex extraction should find text and labels")
		return false
	if str(result.get("text", "")) != "Scene magique":
		push_error("Expected text 'Scene magique'")
		return false
	return true


func test_json_repair_regex_extract_no_text() -> bool:
	var raw := 'no text field here, just "label": "Plonger"'
	var result := _json_repair._regex_extract_card_fields(raw)
	if not result.is_empty():
		push_error("Missing text field should return empty dict")
		return false
	return true


func test_json_repair_regex_extract_insufficient_labels() -> bool:
	var raw := '"text": "Scene" and only "label": "Plonger"'
	var result := _json_repair._regex_extract_card_fields(raw)
	if not result.is_empty():
		push_error("Fewer than 2 labels should return empty dict")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE 4: LlmAdapterPrompts
# ═══════════════════════════════════════════════════════════════════════════════

# --- get_arc_phase ---

func test_prompts_arc_phase_intro() -> bool:
	var result := _prompts.get_arc_phase(0)
	if result != "mini_arc_intro":
		push_error("Cards 0 should be mini_arc_intro, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_ambient() -> bool:
	var result := _prompts.get_arc_phase(1)
	if result != "scenario_ambient_card":
		push_error("Cards 1 should be scenario_ambient_card, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_complication() -> bool:
	var result := _prompts.get_arc_phase(3)
	if result != "mini_arc_complication":
		push_error("Cards 3 should be mini_arc_complication, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_climax() -> bool:
	var result := _prompts.get_arc_phase(5)
	if result != "mini_arc_climax":
		push_error("Cards 5 should be mini_arc_climax, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_twist() -> bool:
	var result := _prompts.get_arc_phase(7)
	if result != "twist_climax":
		push_error("Cards 7 should be twist_climax, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_late_even() -> bool:
	var result := _prompts.get_arc_phase(10)
	if result != "mini_arc_climax":
		push_error("Even late cards should be mini_arc_climax, got '%s'" % result)
		return false
	return true


func test_prompts_arc_phase_late_odd() -> bool:
	var result := _prompts.get_arc_phase(11)
	if result != "scenario_ambient_card":
		push_error("Odd late cards should be scenario_ambient_card, got '%s'" % result)
		return false
	return true


# --- jaccard_similarity ---

func test_prompts_jaccard_identical() -> bool:
	var result := _prompts.jaccard_similarity("hello world", "hello world")
	if not is_equal_approx(result, 1.0):
		push_error("Identical texts should have Jaccard=1.0, got %.3f" % result)
		return false
	return true


func test_prompts_jaccard_disjoint() -> bool:
	var result := _prompts.jaccard_similarity("hello world", "foo bar")
	if not is_equal_approx(result, 0.0):
		push_error("Disjoint texts should have Jaccard=0.0, got %.3f" % result)
		return false
	return true


func test_prompts_jaccard_partial() -> bool:
	var result := _prompts.jaccard_similarity("hello world foo", "hello bar baz")
	# intersection=1 (hello), union=5 -> 0.2
	if result < 0.15 or result > 0.25:
		push_error("Partial overlap Jaccard should be ~0.2, got %.3f" % result)
		return false
	return true


func test_prompts_jaccard_empty_both() -> bool:
	var result := _prompts.jaccard_similarity("", "")
	if not is_equal_approx(result, 1.0):
		push_error("Both empty should return 1.0, got %.3f" % result)
		return false
	return true


func test_prompts_jaccard_one_empty() -> bool:
	var result := _prompts.jaccard_similarity("hello", "")
	if result > 0.01:
		push_error("One empty should return ~0.0, got %.3f" % result)
		return false
	return true


func test_prompts_jaccard_case_insensitive() -> bool:
	var result := _prompts.jaccard_similarity("Hello World", "hello world")
	if not is_equal_approx(result, 1.0):
		push_error("Jaccard should be case-insensitive, got %.3f" % result)
		return false
	return true


# --- extract_recurring_motifs ---

func test_prompts_recurring_motifs_found() -> bool:
	var story_log := [
		{"text": "Le dolmen brille dans la brume epaisse du matin."},
		{"text": "Un autre dolmen apparait, plus ancien, couvert de mousse."},
		{"text": "La lumiere danse autour du troisieme dolmen."},
	]
	var motifs := _prompts.extract_recurring_motifs(story_log)
	var found_dolmen := false
	for m in motifs:
		if str(m) == "dolmen":
			found_dolmen = true
	if not found_dolmen:
		push_error("'dolmen' should be detected as recurring motif")
		return false
	return true


func test_prompts_recurring_motifs_common_excluded() -> bool:
	var story_log := [
		{"text": "Le chemin passe par la foret de Merlin."},
		{"text": "Merlin attend sur le chemin dans la foret."},
	]
	var motifs := _prompts.extract_recurring_motifs(story_log)
	for m in motifs:
		if str(m) in ["foret", "merlin", "chemin"]:
			push_error("Common word '%s' should be excluded from motifs" % str(m))
			return false
	return true


func test_prompts_recurring_motifs_max_five() -> bool:
	var story_log: Array = []
	for i in range(10):
		story_log.append({"text": "motif_alpha motif_beta motif_gamma motif_delta motif_epsilon motif_zeta unique_%d" % i})
	var motifs := _prompts.extract_recurring_motifs(story_log)
	if motifs.size() > 5:
		push_error("Motifs should be capped at 5, got %d" % motifs.size())
		return false
	return true


func test_prompts_recurring_motifs_empty_log() -> bool:
	var motifs := _prompts.extract_recurring_motifs([])
	if motifs.size() != 0:
		push_error("Empty log should produce no motifs")
		return false
	return true


# --- format_instructions ---

func test_prompts_format_instructions_contains_tu() -> bool:
	var result := _prompts.format_instructions(0)
	if result.find("TU") < 0:
		push_error("Format instructions should contain 'TU'")
		return false
	return true


func test_prompts_format_instructions_contains_abc() -> bool:
	var result := _prompts.format_instructions(0)
	if result.find("A)") < 0 or result.find("B)") < 0 or result.find("C)") < 0:
		push_error("Format instructions should mention A) B) C)")
		return false
	return true


func test_prompts_format_instructions_rotation() -> bool:
	var r0 := _prompts.format_instructions(0)
	var r1 := _prompts.format_instructions(1)
	var r2 := _prompts.format_instructions(2)
	# Each should have a different example (rotation)
	if r0 == r1 or r1 == r2:
		push_error("Format instructions should rotate examples across cards_played")
		return false
	return true


# --- substitute_template_vars ---

func test_prompts_substitute_template_vars_basic() -> bool:
	var tpl := "Biome: {biome}, Jour: {day}, Vie: {life}"
	var context := {"biome": "marais_brumeux", "day": 3, "life_essence": 75}
	var result := _prompts.substitute_template_vars(tpl, context)
	if result.find("marais_brumeux") < 0:
		push_error("Biome not substituted")
		return false
	if result.find("3") < 0:
		push_error("Day not substituted")
		return false
	if result.find("75") < 0:
		push_error("Life not substituted")
		return false
	return true


func test_prompts_substitute_template_vars_factions() -> bool:
	var tpl := "Dominant: {dominant_faction}"
	var context := {"factions": {"druides": 80.0, "anciens": 40.0, "korrigans": 30.0}}
	var result := _prompts.substitute_template_vars(tpl, context)
	if result.find("druides") < 0:
		push_error("Dominant faction should be 'druides'")
		return false
	return true


func test_prompts_substitute_template_vars_defaults() -> bool:
	var tpl := "Biome: {biome}, Titre: {scenario_title}"
	var context := {}
	var result := _prompts.substitute_template_vars(tpl, context)
	if result.find("foret_broceliande") < 0:
		push_error("Default biome should be 'foret_broceliande'")
		return false
	return true


# --- build_narrative_system_prompt ---

func test_prompts_narrative_system_prompt_not_empty() -> bool:
	var result := _prompts.build_narrative_system_prompt()
	if result.is_empty():
		push_error("Narrative system prompt should not be empty")
		return false
	return true


func test_prompts_narrative_system_prompt_contains_json() -> bool:
	var result := _prompts.build_narrative_system_prompt()
	if result.find("{") < 0 or result.find("text") < 0:
		push_error("Narrative system prompt should contain JSON example")
		return false
	return true


func test_prompts_narrative_system_prompt_mentions_factions() -> bool:
	var result := _prompts.build_narrative_system_prompt()
	if result.find("druides") < 0 or result.find("ankou") < 0:
		push_error("System prompt should mention factions")
		return false
	return true


# --- build_narrative_user_prompt ---

func test_prompts_narrative_user_prompt_basic() -> bool:
	var context := {"cards_played": 5, "day": 2, "biome": "lande_sauvage", "life_essence": 80}
	var result := _prompts.build_narrative_user_prompt(context)
	if result.is_empty():
		push_error("User prompt should not be empty")
		return false
	if result.find("Jour:2") < 0:
		push_error("User prompt should contain day info")
		return false
	return true


func test_prompts_narrative_user_prompt_includes_prev() -> bool:
	var context := {
		"cards_played": 3, "day": 1, "biome": "foret", "life_essence": 90,
		"story_log": [{"text": "La brume envahit le sentier ancien."}]
	}
	var result := _prompts.build_narrative_user_prompt(context)
	if result.find("Precedent") < 0:
		push_error("User prompt should include previous story excerpt")
		return false
	return true


# --- build_context_enrichment ---

func test_prompts_context_enrichment_empty() -> bool:
	var context := {}
	var result := _prompts.build_context_enrichment(context)
	if not result.is_empty():
		push_error("Empty context should produce empty enrichment")
		return false
	return true


func test_prompts_context_enrichment_high_tension() -> bool:
	var context := {"tension": 70}
	var result := _prompts.build_context_enrichment(context)
	if result.find("haute") < 0:
		push_error("High tension should mention 'haute'")
		return false
	return true


func test_prompts_context_enrichment_moderate_tension() -> bool:
	var context := {"tension": 45}
	var result := _prompts.build_context_enrichment(context)
	if result.find("moderee") < 0:
		push_error("Moderate tension should mention 'moderee'")
		return false
	return true


func test_prompts_context_enrichment_tendency() -> bool:
	var context := {"player_tendency": "agressif"}
	var result := _prompts.build_context_enrichment(context)
	if result.find("agressif") < 0:
		push_error("Player tendency should be included")
		return false
	return true


func test_prompts_context_enrichment_tendency_neutre_excluded() -> bool:
	var context := {"player_tendency": "neutre"}
	var result := _prompts.build_context_enrichment(context)
	if result.find("neutre") >= 0:
		push_error("Neutral tendency should be excluded")
		return false
	return true


func test_prompts_context_enrichment_talents() -> bool:
	var context := {"talent_names": ["Herboriste", "Guerrier"]}
	var result := _prompts.build_context_enrichment(context)
	if result.find("Herboriste") < 0:
		push_error("Talent names should be included")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE 5: LlmAdapterGameMaster
# ═══════════════════════════════════════════════════════════════════════════════

# --- evaluate_balance_heuristic ---

func test_gm_balance_all_neutral() -> bool:
	var context := {"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", 0))
	if score != 100:
		push_error("All neutral factions should give score 100, got %d" % score)
		return false
	if str(result.get("suggestion", "")).find("stable") < 0:
		push_error("All neutral should suggest 'stable'")
		return false
	return true


func test_gm_balance_one_extreme() -> bool:
	var context := {"factions": {"druides": 90.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", 0))
	if score != 80:
		push_error("One extreme faction should give score 80, got %d" % score)
		return false
	return true


func test_gm_balance_three_extremes() -> bool:
	var context := {"factions": {"druides": 95.0, "anciens": 10.0, "korrigans": 5.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", 0))
	if score > 40:
		push_error("Three extreme factions should give low score, got %d" % score)
		return false
	if str(result.get("suggestion", "")).find("Danger") < 0:
		push_error("Three extremes should trigger 'Danger' suggestion")
		return false
	return true


func test_gm_balance_risk_faction_identified() -> bool:
	var context := {"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 5.0}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var risk: String = str(result.get("risk_faction", ""))
	if risk != "ankou":
		push_error("Risk faction should be 'ankou' (most extreme), got '%s'" % risk)
		return false
	return true


func test_gm_balance_empty_factions() -> bool:
	var context := {"factions": {}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", 0))
	if score != 100:
		push_error("Empty factions should default to score 100, got %d" % score)
		return false
	return true


func test_gm_balance_all_extremes() -> bool:
	var context := {"factions": {"druides": 95.0, "anciens": 5.0, "korrigans": 90.0, "niamh": 10.0, "ankou": 85.0}}
	var result := _game_master.evaluate_balance_heuristic(context)
	var score: int = int(result.get("balance_score", 0))
	if score != 0:
		push_error("All 5 extreme factions should give score 0, got %d" % score)
		return false
	return true


# --- _suggest_rule_heuristic ---

func test_gm_suggest_rule_critical() -> bool:
	var context := {"factions": {"druides": 95.0, "anciens": 5.0, "korrigans": 90.0, "niamh": 10.0, "ankou": 85.0}}
	var result := _game_master._suggest_rule_heuristic(context, "neutre")
	if str(result.get("type", "")) != "difficulty":
		push_error("Critical balance should suggest difficulty change, got '%s'" % str(result.get("type", "")))
		return false
	if int(result.get("adjustment", 0)) != -10:
		push_error("Critical adjustment should be -10")
		return false
	return true


func test_gm_suggest_rule_stable_prudent() -> bool:
	var context := {"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master._suggest_rule_heuristic(context, "prudent")
	if str(result.get("type", "")) != "tension":
		push_error("Stable balance + prudent player should suggest tension, got '%s'" % str(result.get("type", "")))
		return false
	return true


func test_gm_suggest_rule_agressif() -> bool:
	var context := {"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master._suggest_rule_heuristic(context, "agressif")
	if str(result.get("type", "")) != "karma":
		push_error("Aggressive player should trigger karma adjustment, got '%s'" % str(result.get("type", "")))
		return false
	return true


func test_gm_suggest_rule_none() -> bool:
	var context := {"factions": {"druides": 60.0, "anciens": 55.0, "korrigans": 45.0, "niamh": 50.0, "ankou": 50.0}}
	var result := _game_master._suggest_rule_heuristic(context, "neutre")
	if str(result.get("type", "")) != "none":
		push_error("Balanced + neutral should suggest 'none', got '%s'" % str(result.get("type", "")))
		return false
	return true


# --- generate_contextual_effects ---

func test_gm_contextual_effects_three_returned() -> bool:
	var context := {
		"life_essence": 80, "cards_played": 5,
		"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}
	}
	var effects := _game_master.generate_contextual_effects(context)
	if effects.size() != 3:
		push_error("Should generate exactly 3 effects, got %d" % effects.size())
		return false
	return true


func test_gm_contextual_effects_faction_types() -> bool:
	var context := {
		"life_essence": 80, "cards_played": 3,
		"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}
	}
	var effects := _game_master.generate_contextual_effects(context)
	for e in effects:
		var etype: String = str(e.get("type", ""))
		if etype != "ADD_REPUTATION" and etype != "PROGRESS_MISSION":
			push_error("Early game effects should be ADD_REPUTATION or PROGRESS_MISSION, got '%s'" % etype)
			return false
	return true


func test_gm_contextual_effects_late_game_progress() -> bool:
	var context := {
		"life_essence": 80, "cards_played": 12,
		"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 50.0}
	}
	var effects := _game_master.generate_contextual_effects(context)
	var has_progress := false
	for e in effects:
		if str(e.get("type", "")) == "PROGRESS_MISSION":
			has_progress = true
	if not has_progress:
		push_error("Late game (cards>=10) should include PROGRESS_MISSION")
		return false
	return true


func test_gm_contextual_effects_risk_faction_prioritized() -> bool:
	var context := {
		"life_essence": 80, "cards_played": 3,
		"factions": {"druides": 50.0, "anciens": 50.0, "korrigans": 50.0, "niamh": 50.0, "ankou": 5.0}
	}
	var effects := _game_master.generate_contextual_effects(context)
	# Risk faction (ankou at 5.0) should be included in first option
	var first_faction: String = str(effects[0].get("faction", ""))
	if first_faction != "ankou":
		push_error("Risk faction 'ankou' should be prioritized in first effect, got '%s'" % first_faction)
		return false
	return true


# --- parse_consequences ---

func test_gm_parse_consequences_valid() -> bool:
	var raw := "A) Tu plonges dans le lac sombre. L'eau glacee te saisit.\nB) Tu gravis la falaise en tremblant. Le vent fouette ton visage.\nC) Tu invoques les esprits anciens. Un murmure repond."
	var result := _game_master.parse_consequences(raw)
	if result.size() != 3:
		push_error("Should parse 3 consequences, got %d" % result.size())
		return false
	return true


func test_gm_parse_consequences_strips_markdown() -> bool:
	var raw := "A) **Tu plonges** dans le lac sombre. L'eau glacee te saisit.\nB) **Tu gravis** la falaise. Le vent fouette.\nC) **Tu invoques** les esprits. Un murmure repond."
	var result := _game_master.parse_consequences(raw)
	if result.size() < 3:
		push_error("Should parse 3 consequences even with markdown")
		return false
	for r in result:
		if str(r).find("**") >= 0:
			push_error("Markdown should be stripped from consequences")
			return false
	return true


func test_gm_parse_consequences_too_short_rejected() -> bool:
	var raw := "A) Short.\nB) Also.\nC) Third too short text line here ok."
	var result := _game_master.parse_consequences(raw)
	# Lines <= 10 chars are rejected, so A and B should be skipped
	# Result should have fewer than 3
	if result.size() >= 3:
		push_error("Short consequence lines (<= 10 chars) should be rejected")
		return false
	return true


func test_gm_parse_consequences_empty() -> bool:
	var result := _game_master.parse_consequences("")
	if result.size() != 0:
		push_error("Empty input should produce no consequences")
		return false
	return true


# --- build_failure_from_success ---

func test_gm_build_failure_from_success() -> bool:
	var success := "Tu plonges dans le lac. L'eau te revigore et une lueur emeraude enveloppe ton corps."
	var failure := _game_master.build_failure_from_success(success)
	if failure.is_empty():
		push_error("Failure text should not be empty")
		return false
	# Should contain one of the failure prefixes
	var has_prefix := false
	for p in ["echoue", "retourne", "suffit", "refuse"]:
		if failure.find(p) >= 0:
			has_prefix = true
	if not has_prefix:
		push_error("Failure text should contain a failure prefix word")
		return false
	return true


func test_gm_build_failure_from_success_single_sentence() -> bool:
	var success := "Tu avances dans la brume"
	var failure := _game_master.build_failure_from_success(success)
	if failure.is_empty():
		push_error("Failure text should not be empty for single sentence")
		return false
	# When only one sentence, fallback message is used
	if failure.find("consequences") < 0 and failure.find("brume") < 0:
		push_error("Single sentence failure should use fallback or include original text")
		return false
	return true


# --- _parse_smart_effects_json ---

func test_gm_parse_smart_effects_valid() -> bool:
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}],[{"type":"ADD_REPUTATION","faction":"druides","amount":10}]]}'
	var result := _game_master._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("Should parse 3 effect arrays, got %d" % result.size())
		return false
	return true


func test_gm_parse_smart_effects_invalid_json() -> bool:
	var raw := "not json at all"
	var result := _game_master._parse_smart_effects_json(raw)
	if result.size() != 0:
		push_error("Invalid JSON should return empty array")
		return false
	return true


func test_gm_parse_smart_effects_wrong_count() -> bool:
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}]]}'
	var result := _game_master._parse_smart_effects_json(raw)
	if result.size() != 0:
		push_error("Only 2 effect arrays should return empty (need exactly 3)")
		return false
	return true


func test_gm_parse_smart_effects_with_repair() -> bool:
	var raw := "{'effects':[[{'type':'HEAL_LIFE','amount':5}],[{'type':'DAMAGE_LIFE','amount':3}],[{'type':'HEAL_LIFE','amount':2}],]}"
	var result := _game_master._parse_smart_effects_json(raw)
	if result.size() != 3:
		push_error("Should repair single quotes and trailing comma, got %d arrays" % result.size())
		return false
	return true


# --- _try_parse_effects_dict ---

func test_gm_try_parse_effects_caps_reputation() -> bool:
	var raw := '{"effects":[[{"type":"ADD_REPUTATION","faction":"druides","amount":50}],[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}]]}'
	var result := _game_master._try_parse_effects_dict(raw)
	if result.size() != 3:
		push_error("Should parse 3 arrays")
		return false
	var rep_effect: Dictionary = result[0][0]
	var amount: float = float(rep_effect.get("amount", 0.0))
	if amount > 20.0:
		push_error("Reputation amount should be capped at 20, got %.1f" % amount)
		return false
	return true


func test_gm_try_parse_effects_invalid_faction_skipped() -> bool:
	var raw := '{"effects":[[{"type":"ADD_REPUTATION","faction":"invalid","amount":10}],[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}]]}'
	var result := _game_master._try_parse_effects_dict(raw)
	if result.size() != 3:
		push_error("Should still return 3 arrays")
		return false
	# First array should have fallback HEAL_LIFE since invalid faction was skipped
	var first_type: String = str(result[0][0].get("type", ""))
	if first_type != "HEAL_LIFE":
		push_error("Invalid faction should be skipped, fallback HEAL_LIFE expected, got '%s'" % first_type)
		return false
	return true


func test_gm_try_parse_effects_amount_clamped() -> bool:
	var raw := '{"effects":[[{"type":"HEAL_LIFE","amount":100}],[{"type":"DAMAGE_LIFE","amount":50}],[{"type":"HEAL_LIFE","amount":-5}]]}'
	var result := _game_master._try_parse_effects_dict(raw)
	if result.size() != 3:
		push_error("Should parse 3 arrays")
		return false
	var amount1: int = int(result[0][0].get("amount", 0))
	if amount1 > 10:
		push_error("Amount should be clamped to 10, got %d" % amount1)
		return false
	var amount2: int = int(result[1][0].get("amount", 0))
	if amount2 > 10:
		push_error("Amount should be clamped to 10, got %d" % amount2)
		return false
	return true
