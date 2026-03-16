## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinAI (pure-logic methods, no scene tree required)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   clean_response()             — ChatML token stripping, role prefix removal
##   _looks_complete()            — length + punctuation heuristic
##   _fill_sequential_template()  — placeholder substitution + cleanup
##   _parse_sequential_labels()   — A/B/C regex extraction, narrative split
##   _parse_sequential_effects()  — JSON effects array parsing
##   _deep_merge_dict()           — recursive overlay merge
##   _to_string_list()            — Array/PackedStringArray coercion
##   check_persona_compliance()   — forbidden words, English, length
##   _make_cache_key()            — deterministic hash from inputs
##   _ensure_session_map()        — legacy Array migration + init
##   add_session_entry()          — bounded history append per channel
##   get_session_context()        — limit + channel slicing
##   get_pool_idle_count()        — count false entries in _pool_busy
##   _get_brain_mode_name()       — brain_count -> string match
##   get_prompt_template()        — key lookup in prompt_templates
##
## Pattern: extends RefCounted, NO class_name, test_xxx() -> bool
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

const MerlinAIScript = preload("res://addons/merlin_ai/merlin_ai.gd")

# ─── Factory ───────────────────────────────────────────────────────────────────

func _make_ai():
	# Instantiate from script (NOT the autoload singleton).
	# _ready() will NOT be called — we set fields manually.
	var ai = MerlinAIScript.new()
	ai.session_contexts = {}
	ai._persona_forbidden_words = PackedStringArray()
	ai.response_cache = {}
	ai.prompt_templates = {}
	ai._pool_busy = []
	ai._pool_workers = []
	ai.brain_count = 1
	ai.active_backend = 0  # BackendType.NONE
	return ai


# ═══════════════════════════════════════════════════════════════════════════════
# clean_response() — strip ChatML artefacts
# ═══════════════════════════════════════════════════════════════════════════════

func test_clean_response_strips_im_end() -> bool:
	var ai: MerlinAI = _make_ai()
	var raw: String = "Salut !<|im_end|>"
	var result: String = ai.clean_response(raw)
	if result != "Salut !":
		push_error("clean_response im_end: expected 'Salut !', got '%s'" % result)
		return false
	return true


func test_clean_response_strips_endoftext() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai.clean_response("Bonjour<|endoftext|>")
	if result != "Bonjour":
		push_error("clean_response endoftext: got '%s'" % result)
		return false
	return true


func test_clean_response_strips_role_prefix_assistant() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai.clean_response("assistant\nTu es le sage.")
	if result != "Tu es le sage.":
		push_error("clean_response role prefix: got '%s'" % result)
		return false
	return true


func test_clean_response_strips_whitespace() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai.clean_response("   Texte propre.   ")
	if result != "Texte propre.":
		push_error("clean_response whitespace: got '%s'" % result)
		return false
	return true


func test_clean_response_empty_input() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai.clean_response("")
	if result != "":
		push_error("clean_response empty: got '%s'" % result)
		return false
	return true


func test_clean_response_no_tokens_unchanged() -> bool:
	var ai: MerlinAI = _make_ai()
	var text: String = "Le druide parle."
	var result: String = ai.clean_response(text)
	if result != text:
		push_error("clean_response unchanged: expected '%s', got '%s'" % [text, result])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _looks_complete() — stream completion heuristic
# ═══════════════════════════════════════════════════════════════════════════════

func test_looks_complete_short_text_false() -> bool:
	var ai: MerlinAI = _make_ai()
	# Fewer than 60 chars → always false
	if ai._looks_complete("Court."):
		push_error("_looks_complete short: expected false")
		return false
	return true


func test_looks_complete_ends_with_period() -> bool:
	var ai: MerlinAI = _make_ai()
	var long_text: String = "Le vieux druide leva les yeux vers le ciel et dit a voix basse."
	if not ai._looks_complete(long_text):
		push_error("_looks_complete period: expected true for '%s'" % long_text)
		return false
	return true


func test_looks_complete_contains_newline() -> bool:
	var ai: MerlinAI = _make_ai()
	var text: String = "Premiere ligne longue premiere ligne longue premiere ligne longue.\nDeuxieme ligne."
	if not ai._looks_complete(text):
		push_error("_looks_complete newline: expected true")
		return false
	return true


func test_looks_complete_question_mark() -> bool:
	var ai: MerlinAI = _make_ai()
	# Must be >= 60 chars AND end with '?' for this branch to fire
	var text: String = "Le chemin sinueux s'ouvre devant toi dans la foret, que vas-tu faire ?"
	if not ai._looks_complete(text):
		push_error("_looks_complete question: expected true for '%s'" % text)
		return false
	return true


func test_looks_complete_long_no_punctuation_false() -> bool:
	var ai: MerlinAI = _make_ai()
	# Long text but no terminal punctuation and no newline → false
	var text: String = "Le druide marche lentement vers la foret en observant les arbres anciens"
	if ai._looks_complete(text):
		push_error("_looks_complete no-punct: expected false")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _fill_sequential_template() — placeholder substitution
# ═══════════════════════════════════════════════════════════════════════════════

func test_fill_template_replaces_known_key() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai._fill_sequential_template("Biome: {biome}", {"biome": "foret"})
	if result != "Biome: foret":
		push_error("fill_template: expected 'Biome: foret', got '%s'" % result)
		return false
	return true


func test_fill_template_removes_unknown_placeholders() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai._fill_sequential_template("{biome} et {unknown}", {"biome": "lac"})
	if result != "lac et ":
		push_error("fill_template unknown: expected 'lac et ', got '%s'" % result)
		return false
	return true


func test_fill_template_empty_context() -> bool:
	var ai: MerlinAI = _make_ai()
	# All placeholders removed when context is empty
	var result: String = ai._fill_sequential_template("{biome}", {})
	if result != "":
		push_error("fill_template empty ctx: expected '', got '%s'" % result)
		return false
	return true


func test_fill_template_numeric_value() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: String = ai._fill_sequential_template("Cartes: {count}", {"count": 5})
	if result != "Cartes: 5":
		push_error("fill_template numeric: expected 'Cartes: 5', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _parse_sequential_labels() — A/B/C extraction from narrator output
# ═══════════════════════════════════════════════════════════════════════════════

func test_parse_labels_extracts_three_options() -> bool:
	var ai: MerlinAI = _make_ai()
	var text: String = """Le druide te regarde en silence.

A) Accepter son aide
B) Refuser poliment
C) Fuir dans la foret"""
	var result: Dictionary = ai._parse_sequential_labels(text)
	var labels: Array = result.get("labels", [])
	if labels.size() != 3:
		push_error("parse_labels count: expected 3, got %d" % labels.size())
		return false
	return true


func test_parse_labels_splits_narrative() -> bool:
	var ai: MerlinAI = _make_ai()
	var text: String = "Une lumiere etrange brille dans la foret.\n\nA) Approcher\nB) Fuir\nC) Observer"
	var result: Dictionary = ai._parse_sequential_labels(text)
	var narrative: String = result.get("narrative", "")
	if narrative.is_empty():
		push_error("parse_labels narrative: expected non-empty narrative")
		return false
	if "lumiere" not in narrative:
		push_error("parse_labels narrative content: expected 'lumiere' in '%s'" % narrative)
		return false
	return true


func test_parse_labels_empty_text() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: Dictionary = ai._parse_sequential_labels("")
	var labels: Array = result.get("labels", [])
	if labels.size() != 0:
		push_error("parse_labels empty: expected 0 labels, got %d" % labels.size())
		return false
	return true


func test_parse_labels_strips_markdown_bold() -> bool:
	var ai: MerlinAI = _make_ai()
	var text: String = "Scenario.\n\n**A)** Entrer dans la caverne\n**B)** Rebrousser chemin\n**C)** Crier pour alerter"
	var result: Dictionary = ai._parse_sequential_labels(text)
	var labels: Array = result.get("labels", [])
	if labels.size() < 1:
		push_error("parse_labels bold: expected labels, got 0")
		return false
	# Labels must not contain ** markers
	for lbl in labels:
		if "**" in str(lbl):
			push_error("parse_labels bold: label still contains '**': '%s'" % str(lbl))
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _parse_sequential_effects() — GM JSON effects parsing
# ═══════════════════════════════════════════════════════════════════════════════

func test_parse_effects_valid_json() -> bool:
	var ai: MerlinAI = _make_ai()
	var json_text: String = '[[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}],[{"type":"ADD_REPUTATION","aspect":"druides","direction":"positive","amount":10}]]'
	var result: Array = ai._parse_sequential_effects(json_text)
	if result.size() != 3:
		push_error("parse_effects size: expected 3, got %d" % result.size())
		return false
	var first_effect: Dictionary = result[0][0]
	if str(first_effect.get("type", "")) != "HEAL_LIFE":
		push_error("parse_effects type: expected HEAL_LIFE, got '%s'" % str(first_effect.get("type", "")))
		return false
	if int(first_effect.get("amount", 0)) != 5:
		push_error("parse_effects amount: expected 5, got %d" % int(first_effect.get("amount", 0)))
		return false
	return true


func test_parse_effects_no_json_returns_default() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: Array = ai._parse_sequential_effects("Aucun JSON ici.")
	if result.size() != 3:
		push_error("parse_effects no-json: expected 3 empty slots, got %d" % result.size())
		return false
	return true


func test_parse_effects_malformed_json_returns_default() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: Array = ai._parse_sequential_effects("[{broken json}")
	if result.size() != 3:
		push_error("parse_effects malformed: expected 3 slots, got %d" % result.size())
		return false
	return true


func test_parse_effects_skips_non_dict_items() -> bool:
	var ai: MerlinAI = _make_ai()
	# Third option has a string instead of dicts inside the array — should produce empty slot
	var json_text: String = '[[{"type":"HEAL_LIFE","amount":5}],[{"type":"DAMAGE_LIFE","amount":3}],["invalid"]]'
	var result: Array = ai._parse_sequential_effects(json_text)
	if result.size() != 3:
		push_error("parse_effects non-dict: expected 3 slots, got %d" % result.size())
		return false
	# Slot 2 (index 2) should be empty because "invalid" is not a dict
	if result[2].size() != 0:
		push_error("parse_effects non-dict: slot[2] should be empty, got size %d" % result[2].size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _deep_merge_dict() — recursive overlay
# ═══════════════════════════════════════════════════════════════════════════════

func test_deep_merge_adds_new_key() -> bool:
	var ai: MerlinAI = _make_ai()
	var base: Dictionary = {"a": 1}
	var overlay: Dictionary = {"b": 2}
	var result: Dictionary = ai._deep_merge_dict(base, overlay)
	if not result.has("a") or not result.has("b"):
		push_error("deep_merge add key: expected a=1 and b=2, got %s" % str(result))
		return false
	return true


func test_deep_merge_overlay_overrides_scalar() -> bool:
	var ai: MerlinAI = _make_ai()
	var base: Dictionary = {"x": 10}
	var overlay: Dictionary = {"x": 99}
	var result: Dictionary = ai._deep_merge_dict(base, overlay)
	if int(result.get("x", 0)) != 99:
		push_error("deep_merge override: expected 99, got %d" % int(result.get("x", 0)))
		return false
	return true


func test_deep_merge_recursion() -> bool:
	var ai: MerlinAI = _make_ai()
	var base: Dictionary = {"inner": {"a": 1, "b": 2}}
	var overlay: Dictionary = {"inner": {"b": 99, "c": 3}}
	var result: Dictionary = ai._deep_merge_dict(base, overlay)
	var inner: Dictionary = result.get("inner", {})
	if int(inner.get("a", 0)) != 1 or int(inner.get("b", 0)) != 99 or int(inner.get("c", 0)) != 3:
		push_error("deep_merge recursive: expected a=1 b=99 c=3, got %s" % str(inner))
		return false
	return true


func test_deep_merge_does_not_mutate_base() -> bool:
	var ai: MerlinAI = _make_ai()
	var base: Dictionary = {"key": "original"}
	var overlay: Dictionary = {"key": "changed"}
	var _result: Dictionary = ai._deep_merge_dict(base, overlay)
	if str(base.get("key", "")) != "original":
		push_error("deep_merge immutable: base was mutated")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _to_string_list() — type coercion to PackedStringArray
# ═══════════════════════════════════════════════════════════════════════════════

func test_to_string_list_from_array() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: PackedStringArray = ai._to_string_list(["druid", "elf", "  "])
	# "  " is blank after strip_edges → should be excluded
	if result.size() != 2:
		push_error("to_string_list array: expected 2, got %d" % result.size())
		return false
	return true


func test_to_string_list_from_packed_string_array() -> bool:
	var ai: MerlinAI = _make_ai()
	var input: PackedStringArray = PackedStringArray(["a", "b"])
	var result: PackedStringArray = ai._to_string_list(input)
	if result.size() != 2:
		push_error("to_string_list packed: expected 2, got %d" % result.size())
		return false
	return true


func test_to_string_list_empty_array() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: PackedStringArray = ai._to_string_list([])
	if result.size() != 0:
		push_error("to_string_list empty: expected 0, got %d" % result.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# check_persona_compliance() — forbidden words + English detection + length
# ═══════════════════════════════════════════════════════════════════════════════

func test_persona_compliance_clean_response() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._persona_forbidden_words = PackedStringArray(["simulation", "algorithme"])
	var result: Dictionary = ai.check_persona_compliance("Le druide parle a voix basse.")
	if not result.get("valid", false):
		push_error("persona compliance clean: expected valid=true, violations=%s" % str(result.get("violations", [])))
		return false
	return true


func test_persona_compliance_forbidden_word_detected() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._persona_forbidden_words = PackedStringArray(["simulation"])
	var result: Dictionary = ai.check_persona_compliance("Je suis une simulation de Merlin.")
	if result.get("valid", true):
		push_error("persona compliance forbidden: expected valid=false")
		return false
	return true


func test_persona_compliance_english_detected() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._persona_forbidden_words = PackedStringArray()
	var result: Dictionary = ai.check_persona_compliance("Hello, I am the wizard. Please follow me.")
	if result.get("valid", true):
		push_error("persona compliance english: expected valid=false (english detected)")
		return false
	return true


func test_persona_compliance_too_long() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._persona_forbidden_words = PackedStringArray()
	var long_text: String = "a".repeat(501)
	var result: Dictionary = ai.check_persona_compliance(long_text)
	if result.get("valid", true):
		push_error("persona compliance length: expected valid=false for 501 chars")
		return false
	return true


func test_persona_compliance_score_decreases_with_violations() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._persona_forbidden_words = PackedStringArray(["mot1", "mot2", "mot3", "mot4"])
	var result: Dictionary = ai.check_persona_compliance("mot1 mot2 mot3 mot4")
	var score: float = float(result.get("score", 1.0))
	if score >= 1.0:
		push_error("persona compliance score: expected score < 1.0 with 4 violations, got %f" % score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _make_cache_key() — deterministic string hash
# ═══════════════════════════════════════════════════════════════════════════════

func test_cache_key_same_inputs_same_key() -> bool:
	var ai: MerlinAI = _make_ai()
	var params: Dictionary = {"temperature": 0.7, "max_tokens": 100}
	var key1: String = ai._make_cache_key("system", "user", params)
	var key2: String = ai._make_cache_key("system", "user", params)
	if key1 != key2:
		push_error("cache_key deterministic: key1=%s key2=%s" % [key1, key2])
		return false
	return true


func test_cache_key_different_system_different_key() -> bool:
	var ai: MerlinAI = _make_ai()
	var params: Dictionary = {"temperature": 0.7}
	var key1: String = ai._make_cache_key("system_a", "user", params)
	var key2: String = ai._make_cache_key("system_b", "user", params)
	if key1 == key2:
		push_error("cache_key collision: same key for different systems")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _ensure_session_map() — legacy migration + default init
# ═══════════════════════════════════════════════════════════════════════════════

func test_ensure_session_map_creates_new_entry() -> bool:
	var ai: MerlinAI = _make_ai()
	var result: Dictionary = ai._ensure_session_map("new_session")
	if not result.has("default"):
		push_error("ensure_session_map new: expected 'default' key")
		return false
	return true


func test_ensure_session_map_migrates_legacy_array() -> bool:
	var ai: MerlinAI = _make_ai()
	# Legacy format: session stored directly as Array (no channel wrapper)
	ai.session_contexts["legacy"] = [{"role": "user", "content": "test"}]
	var result: Dictionary = ai._ensure_session_map("legacy")
	if not result.has("default"):
		push_error("ensure_session_map migrate: expected 'default' channel after migration")
		return false
	if not (result["default"] is Array):
		push_error("ensure_session_map migrate: expected Array in 'default'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# add_session_entry() + get_session_context() — bounded history per channel
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_session_entry_basic() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.add_session_entry("sess1", "user", "Bonjour")
	var ctx: Array = ai.get_session_context("sess1", 10)
	if ctx.size() != 1:
		push_error("add_session_entry: expected 1 entry, got %d" % ctx.size())
		return false
	var entry: Dictionary = ctx[0]
	if str(entry.get("role", "")) != "user":
		push_error("add_session_entry role: expected user, got '%s'" % str(entry.get("role", "")))
		return false
	return true


func test_add_session_entry_respects_channel() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.add_session_entry("sess2", "user", "msg default")
	ai.add_session_entry("sess2", "user", "msg narrative", "narrative")
	var default_ctx: Array = ai.get_session_context("sess2", 10, "default")
	var narrative_ctx: Array = ai.get_session_context("sess2", 10, "narrative")
	if default_ctx.size() != 1 or narrative_ctx.size() != 1:
		push_error("add_session_entry channel: default=%d narrative=%d" % [default_ctx.size(), narrative_ctx.size()])
		return false
	return true


func test_get_session_context_limit_slice() -> bool:
	var ai: MerlinAI = _make_ai()
	for i in range(10):
		ai.add_session_entry("sess3", "user", "msg %d" % i)
	var ctx: Array = ai.get_session_context("sess3", 3)
	if ctx.size() != 3:
		push_error("get_session_context limit: expected 3, got %d" % ctx.size())
		return false
	# Should return the LAST 3 entries
	if str(ctx[2].get("content", "")) != "msg 9":
		push_error("get_session_context last: expected 'msg 9', got '%s'" % str(ctx[2].get("content", "")))
		return false
	return true


func test_get_session_context_empty_session() -> bool:
	var ai: MerlinAI = _make_ai()
	var ctx: Array = ai.get_session_context("nonexistent", 5)
	if ctx.size() != 0:
		push_error("get_session_context empty: expected 0, got %d" % ctx.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_pool_idle_count() — count idle slots in _pool_busy
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_pool_idle_count_all_idle() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._pool_busy = [false, false, false]
	if ai.get_pool_idle_count() != 3:
		push_error("pool_idle all idle: expected 3, got %d" % ai.get_pool_idle_count())
		return false
	return true


func test_get_pool_idle_count_some_busy() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._pool_busy = [true, false, true, false]
	if ai.get_pool_idle_count() != 2:
		push_error("pool_idle some busy: expected 2, got %d" % ai.get_pool_idle_count())
		return false
	return true


func test_get_pool_idle_count_empty() -> bool:
	var ai: MerlinAI = _make_ai()
	ai._pool_busy = []
	if ai.get_pool_idle_count() != 0:
		push_error("pool_idle empty: expected 0, got %d" % ai.get_pool_idle_count())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _get_brain_mode_name() — brain_count match (legacy BitNet/MerlinLLM path)
# ═══════════════════════════════════════════════════════════════════════════════

func test_brain_mode_name_single() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.active_backend = 2  # BackendType.BITNET (non-Ollama → legacy path)
	ai.brain_count = 1
	var name: String = ai._get_brain_mode_name()
	if name != "Single (Narrator seul)":
		push_error("brain_mode single: got '%s'" % name)
		return false
	return true


func test_brain_mode_name_dual() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.active_backend = 2  # BackendType.BITNET
	ai.brain_count = 2
	var name: String = ai._get_brain_mode_name()
	if name != "Dual (Narrator + GM)":
		push_error("brain_mode dual: got '%s'" % name)
		return false
	return true


func test_brain_mode_name_unknown() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.active_backend = 2  # BackendType.BITNET
	ai.brain_count = 99
	var name: String = ai._get_brain_mode_name()
	if not name.begins_with("Unknown"):
		push_error("brain_mode unknown: expected 'Unknown...', got '%s'" % name)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_prompt_template() — key lookup
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_prompt_template_found() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.prompt_templates = {
		"narrator_card": {"system": "Tu es Merlin.", "max_tokens": 180}
	}
	var tmpl: Dictionary = ai.get_prompt_template("narrator", "card")
	if not tmpl.has("system"):
		push_error("get_prompt_template found: expected 'system' key")
		return false
	return true


func test_get_prompt_template_not_found_returns_empty() -> bool:
	var ai: MerlinAI = _make_ai()
	ai.prompt_templates = {}
	var tmpl: Dictionary = ai.get_prompt_template("narrator", "nonexistent")
	if not tmpl.is_empty():
		push_error("get_prompt_template missing: expected empty dict, got %s" % str(tmpl))
		return false
	return true
