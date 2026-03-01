## ═══════════════════════════════════════════════════════════════════════════════
## TestLLMBenchmarkRun — Bi-brain pipeline benchmark: full run simulation
## ═══════════════════════════════════════════════════════════════════════════════
## Simulates a complete game run (biome + season + time → N cards → resolutions)
## with per-card quality metrics, narrative coherence judge, multi-model comparison.
## No UI — all output goes to console + JSON/Markdown reports.
## Run: godot --path . --headless scenes/TestLLMBenchmarkRun.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

@export var biome: String = "foret_broceliande"
@export var season: String = "automne"
@export var time_of_day: String = "crepuscule"
@export var num_cards: int = 15
@export var model_name: String = "qwen2.5:1.5b"
@export var auto_strategy: int = 0  # 0=MIXED 1=RANDOM 2=CAUTIOUS 3=AGGRESSIVE
@export var generate_resolutions: bool = true
@export var run_coherence_judge: bool = true
@export var compare_models: PackedStringArray = []

enum Strategy { MIXED, RANDOM, CAUTIOUS, AGGRESSIVE }

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const FR_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et",
	"est", "que", "qui", "dans", "pour", "sur", "par", "au", "aux", "son",
	"sa", "ses", "ce", "cette", "il", "elle", "nous", "vous", "mais", "ou"]

const FORBIDDEN_WORDS := ["simulation", "programme", "ia", "intelligence artificielle",
	"modele de langage", "llm", "serveur", "algorithme", "token", "api",
	"machine learning", "neural", "dataset", "artificial", "language model",
	"computer", "software"]

const CELTIC_VOCAB := [
	"druide", "ogham", "nemeton", "menhir", "dolmen", "korrigan", "sidhe",
	"brume", "chene", "gui", "beltaine", "samhain", "imbolc", "lughnasadh",
	"torque", "cairn", "triskell", "fee", "barde", "avalon", "broceliande",
	"merlin", "fae", "awen", "korrigane", "chaudron", "betula", "sorbier",
	"if", "houx", "aubepine", "saule", "frene"]

const JACCARD_THRESHOLD := 0.5
const FR_MIN_RATIO := 0.6
const MIN_TEXT_LEN := 30

const TIME_TONES := {
	"aube":       {"label": "Aube", "tone": "mystique et contemplative, lueur naissante", "danger_mod": -0.15},
	"zenith":     {"label": "Zenith", "tone": "vibrante et active, soleil haut", "danger_mod": 0.0},
	"crepuscule": {"label": "Crepuscule", "tone": "menacante et transitoire, ombres longues", "danger_mod": 0.15},
	"nuit":       {"label": "Nuit", "tone": "obscure et dangereuse, brume epaisse", "danger_mod": 0.3},
}

const SEASON_TONES := {
	"printemps": {"label": "Printemps", "tone": "renouveau, seve montante, esprits eveilles", "aspect_bias": "Monde"},
	"ete":       {"label": "Ete", "tone": "chaleur, force, fetes celestes", "aspect_bias": "Corps"},
	"automne":   {"label": "Automne", "tone": "melancolie, passage, voile mince entre les mondes", "aspect_bias": "Ame"},
	"hiver":     {"label": "Hiver", "tone": "survie, silence, froid mordant, esprits endormis", "aspect_bias": "Corps"},
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

class BenchRunState:
	var life: int = 100
	var souffle: int = 3
	var karma: int = 0
	var aspects: Dictionary = {"Corps": 0, "Ame": 0, "Monde": 0}
	var tension: int = 0
	var cards_played: int = 0
	var day: int = 1
	var story_log: Array[Dictionary] = []
	var previous_texts: Array[String] = []

var _merlin_ai: Node = null
var _store: Node = null
var _mos: Node = null
var _adapter: RefCounted = null
var _ram_start: int = 0
var _all_runs: Array[Dictionary] = []


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_ram_start = OS.get_static_memory_usage()
	_log("═══════════════════════════════════════════════════════")
	_log("  LLM BENCHMARK RUN — BI-BRAIN PIPELINE")
	_log("═══════════════════════════════════════════════════════")
	_log("  Biome: %s | Season: %s | Time: %s" % [biome, season, time_of_day])
	_log("  Cards: %d | Model: %s | Strategy: %s" % [num_cards, model_name, Strategy.keys()[auto_strategy]])
	_log("  Resolutions: %s | Coherence judge: %s" % [str(generate_resolutions), str(run_coherence_judge)])
	if compare_models.size() > 0:
		_log("  Compare with: %s" % ", ".join(Array(compare_models)))
	_log("═══════════════════════════════════════════════════════")

	await get_tree().process_frame
	await get_tree().process_frame

	# Get autoloads
	_store = get_node_or_null("/root/MerlinStore")
	if not _store:
		_log("FATAL: MerlinStore autoload missing")
		get_tree().quit(1)
		return

	if "llm" in _store and _store.llm != null:
		_adapter = _store.llm
	_mos = _store.get_merlin() if _store.has_method("get_merlin") else null

	_merlin_ai = get_node_or_null("/root/MerlinAI")
	if not _merlin_ai:
		_log("FATAL: MerlinAI autoload missing")
		get_tree().quit(1)
		return

	# Warmup
	if not await _warmup_llm():
		_log("FATAL: LLM warmup failed")
		get_tree().quit(1)
		return

	_log("LLM ready: brain_count=%d backend=%s" % [
		_merlin_ai.brain_count,
		"ollama" if _merlin_ai.active_backend == 1 else "other"])

	# Run benchmark
	await _run_benchmark()

	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)


func _warmup_llm() -> bool:
	if _merlin_ai.is_ready:
		return true
	_log("Warming up LLM (90s timeout)...")
	_merlin_ai.start_warmup()
	var t := Time.get_ticks_msec()
	while not _merlin_ai.is_ready:
		if Time.get_ticks_msec() - t > 90000:
			_log("Warmup timeout after 90s")
			return false
		await get_tree().process_frame
	_log("LLM warm in %dms" % (Time.get_ticks_msec() - t))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════════════════

func _run_benchmark() -> void:
	# Primary model run
	var primary_report: Dictionary = await _run_single_model(model_name)
	_all_runs.append(primary_report)

	# Comparison models
	for cmp_model in compare_models:
		_log("\n\n═══ SWITCHING MODEL: %s ═══\n" % cmp_model)
		if _switch_model(cmp_model):
			await get_tree().create_timer(3.0).timeout  # let model load
			var cmp_report: Dictionary = await _run_single_model(cmp_model)
			_all_runs.append(cmp_report)
		else:
			_log("SKIP: Could not switch to model %s" % cmp_model)

	# Restore primary model
	if compare_models.size() > 0:
		_switch_model(model_name)

	# Export
	_export_json_report()
	_export_markdown_report()

	# Print comparison if multi-model
	if _all_runs.size() > 1:
		_print_comparison()


func _switch_model(new_model: String) -> bool:
	if not _merlin_ai or not _merlin_ai.narrator_llm:
		return false
	if _merlin_ai.narrator_llm.has_method("set") or "model" in _merlin_ai.narrator_llm:
		_merlin_ai.narrator_llm.model = new_model
		if _merlin_ai.gamemaster_llm and _merlin_ai.gamemaster_llm != _merlin_ai.narrator_llm:
			_merlin_ai.gamemaster_llm.model = new_model
		_log("Model switched to: %s" % new_model)
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# SINGLE MODEL RUN
# ═══════════════════════════════════════════════════════════════════════════════

func _run_single_model(current_model: String) -> Dictionary:
	_log("\n┌── RUN: %s ──────────────────────────────" % current_model)
	_log("│  Biome: %s | %s | %s" % [biome, season, time_of_day])

	var state := BenchRunState.new()
	var card_log: Array[Dictionary] = []
	var gen_times: Array[int] = []
	var run_ended_early := false

	for card_idx in range(num_cards):
		if not is_inside_tree():
			break

		state.cards_played = card_idx
		state.day = 1 + int(card_idx / 4)

		# Build context
		var ctx: Dictionary = _build_context(state)

		# Generate card
		_log("│")
		_log("├── CARD %d/%d" % [card_idx + 1, num_cards])
		var t_start := Time.get_ticks_msec()
		var card: Dictionary = await _generate_card(ctx)
		var gen_ms: int = Time.get_ticks_msec() - t_start
		gen_times.append(gen_ms)

		if card.is_empty():
			_log("│   └── GENERATION FAILED (%dms)" % gen_ms)
			card_log.append({"card_num": card_idx + 1, "gen_ms": gen_ms, "failed": true})
			continue

		var text: String = str(card.get("text", ""))
		var options: Array = card.get("options", [])

		# Measure quality
		var quality: Dictionary = _measure_quality(text, options, state.previous_texts)

		# Log card
		_log("│   ├── TEXT (%d chars): \"%s\"" % [text.length(), text.substr(0, 90)])
		_log("│   ├── OPTIONS: %d" % options.size())
		for oi in range(mini(options.size(), 3)):
			var opt: Dictionary = options[oi] if options[oi] is Dictionary else {}
			var label: String = str(opt.get("label", "?"))
			var effects: Array = opt.get("effects", [])
			_log("│   │   %s) %s [%s]" % [["A", "B", "C"][oi], label, _effects_str(effects)])
		_log("│   ├── QUALITY: format=%s fr=%.0f%% celtic=%d jaccard=%.2f" % [
			"OK" if quality.format_ok else "FAIL",
			quality.french_rate * 100.0,
			quality.celtic_count,
			quality.max_jaccard])

		# Pick choice
		var choice_idx: int = _pick_choice(options, state)
		var chosen_opt: Dictionary = options[choice_idx] if choice_idx < options.size() else {}
		var chosen_label: String = str(chosen_opt.get("label", "?"))
		var chosen_effects: Array = chosen_opt.get("effects", [])

		# Apply effects
		var pre_state: Dictionary = {"life": state.life, "aspects": state.aspects.duplicate(), "souffle": state.souffle}
		_apply_effects(state, chosen_effects)

		_log("│   ├── CHOICE: %s → \"%s\"" % [["A", "B", "C"][choice_idx], chosen_label])
		_log("│   ├── STATE: life=%d aspects=%s souffle=%d" % [state.life, str(state.aspects), state.souffle])

		# Generate resolution
		var resolution_text := ""
		var resolution_ms: int = 0
		if generate_resolutions:
			var rt_start := Time.get_ticks_msec()
			resolution_text = await _generate_resolution(text, chosen_label, chosen_effects)
			resolution_ms = Time.get_ticks_msec() - rt_start
			if not resolution_text.is_empty():
				_log("│   ├── RESOLUTION (%dms): \"%s\"" % [resolution_ms, resolution_text.substr(0, 80)])

		# Update story log
		state.story_log.append({
			"card_num": card_idx + 1,
			"text": text.substr(0, 200),
			"choice": chosen_label,
			"resolution": resolution_text,
			"effects": _effects_str(chosen_effects),
		})
		state.previous_texts.append(text)

		# Card log entry
		card_log.append({
			"card_num": card_idx + 1,
			"gen_ms": gen_ms,
			"resolution_ms": resolution_ms,
			"text": text,
			"options_count": options.size(),
			"labels": _extract_labels(options),
			"format_ok": quality.format_ok,
			"french_rate": quality.french_rate,
			"celtic_count": quality.celtic_count,
			"celtic_words": quality.celtic_words,
			"max_jaccard": quality.max_jaccard,
			"forbidden_found": quality.forbidden_found,
			"choice_idx": choice_idx,
			"choice_label": chosen_label,
			"resolution": resolution_text,
			"state_before": pre_state,
			"state_after": {"life": state.life, "aspects": state.aspects.duplicate(), "souffle": state.souffle},
		})

		# Degrade state
		_degrade_state(state, card_idx)

		# Check run end
		var extreme_count: int = 0
		for asp_val in state.aspects.values():
			if int(asp_val) != 0:
				extreme_count += 1
		if extreme_count >= 2 or state.life <= 0:
			_log("│")
			_log("│   !! RUN END: %s at card %d" % [
				"life=0" if state.life <= 0 else "%d extreme aspects" % extreme_count,
				card_idx + 1])
			run_ended_early = true
			break

	_log("│")
	_log("└── END OF RUN (%d cards generated)" % card_log.size())

	# Aggregate metrics
	var aggregate: Dictionary = _compute_aggregate(card_log, gen_times, run_ended_early)
	_print_aggregate(aggregate)

	# Coherence judge
	var coherence: Dictionary = {}
	if run_coherence_judge and state.story_log.size() >= 3:
		_log("\n┌── COHERENCE JUDGE ────────────────────")
		coherence = await _judge_coherence(state.story_log)
		if coherence.has("score"):
			_log("│  Score: %s/10" % str(coherence.score))
			_log("│  Strengths: %s" % str(coherence.get("strengths", "")))
			_log("│  Weaknesses: %s" % str(coherence.get("weaknesses", "")))
			_log("│  Reasoning: %s" % str(coherence.get("reasoning", "")).substr(0, 200))
		else:
			_log("│  Judge failed: %s" % str(coherence.get("error", "unknown")))
		_log("└───────────────────────────────────────")

	return {
		"model": current_model,
		"config": {"biome": biome, "season": season, "time_of_day": time_of_day,
			"num_cards": num_cards, "strategy": Strategy.keys()[auto_strategy]},
		"cards": card_log,
		"aggregate": aggregate,
		"coherence": coherence,
		"story_log": state.story_log,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# CARD GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_card(ctx: Dictionary) -> Dictionary:
	# Strategy 1: MerlinOmniscient (full pipeline)
	if _mos and _mos.has_method("generate_card"):
		var game_state: Dictionary = _ctx_to_game_state(ctx)
		var card: Dictionary = await _mos.generate_card(game_state)
		if not card.is_empty():
			return card

	# Strategy 2: Adapter two-stage (fallback)
	if _adapter and _adapter.has_method("_generate_card_two_stage"):
		var result: Dictionary = await _adapter._generate_card_two_stage(ctx)
		if result.get("ok", false):
			return result.get("card", {})

	# Strategy 3: Direct LLM call (last resort)
	if _merlin_ai and _merlin_ai.has_method("generate_with_system"):
		var sys_prompt := _build_narrator_system_prompt(ctx)
		var user_prompt := _build_narrator_user_prompt(ctx)
		var result: Dictionary = await _merlin_ai.generate_with_system(sys_prompt, user_prompt, {"max_tokens": 180, "temperature": 0.65})
		if not result.has("error"):
			return _parse_raw_response(str(result.get("text", "")))

	return {}


func _ctx_to_game_state(ctx: Dictionary) -> Dictionary:
	# Convert benchmark context to the game_state format MOS expects
	return {
		"run": {
			"cards_played": ctx.get("cards_played", 0),
			"day": ctx.get("day", 1),
			"biome": ctx.get("biome", "foret_broceliande"),
		},
		"triade": {
			"aspects": ctx.get("aspects", {"Corps": 0, "Ame": 0, "Monde": 0}),
			"souffle": ctx.get("souffle", 3),
		},
		"life_essence": ctx.get("life_essence", 100),
		"karma": ctx.get("karma", 0),
		"story_log": ctx.get("story_log", []),
		"flags": {},
	}


func _build_narrator_system_prompt(ctx: Dictionary) -> String:
	var time_info: Dictionary = TIME_TONES.get(time_of_day, TIME_TONES["crepuscule"])
	var season_info: Dictionary = SEASON_TONES.get(season, SEASON_TONES["automne"])
	return "Narrateur celtique de %s. C'est %s en %s. Ton %s, %s. " % [
		biome, str(time_info.label), str(season_info.label),
		str(time_info.tone), str(season_info.tone)] + \
		"Ecris en francais une scene courte (2-3 phrases) avec vocabulaire druidique " + \
		"(nemeton, ogham, sidhe, dolmen, korrigans). " + \
		"Puis donne EXACTEMENT 3 choix:\nA) [verbe action]\nB) [verbe action]\nC) [verbe action]"


func _build_narrator_user_prompt(ctx: Dictionary) -> String:
	var aspects: Dictionary = ctx.get("aspects", {"Corps": 0, "Ame": 0, "Monde": 0})
	var aspect_labels := {"Corps": "", "Ame": "", "Monde": ""}
	for asp_key in aspects:
		var v: int = int(aspects[asp_key])
		aspect_labels[asp_key] = "bas" if v == -1 else ("haut" if v == 1 else "eq")
	return "Aspects: Corps=%s Ame=%s Monde=%s\nSouffle:%d Jour:%d Carte:%d Vie:%d\nEcris la scene puis les 3 choix A) B) C) en francais." % [
		aspect_labels["Corps"], aspect_labels["Ame"], aspect_labels["Monde"],
		int(ctx.get("souffle", 3)), int(ctx.get("day", 1)),
		int(ctx.get("cards_played", 0)), int(ctx.get("life_essence", 100))]


func _parse_raw_response(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	# Try to extract A) B) C) labels
	var labels: Array[String] = []
	var narrative := text
	var regex := RegEx.new()
	regex.compile("(?m)^\\s*(?:\\*{0,2})([A-C])[):.\\]]\\s*(.+)")
	var matches: Array = regex.search_all(text)
	for m in matches:
		labels.append(m.get_string(2).strip_edges())
	# Narrative = everything before first match
	if matches.size() > 0:
		narrative = text.substr(0, matches[0].get_start()).strip_edges()
	if labels.size() < 3:
		labels = ["Avancer prudemment", "Observer en silence", "Agir sans hesiter"]
	var options: Array[Dictionary] = []
	var directions := ["left", "center", "right"]
	for i in range(3):
		options.append({
			"label": labels[i] if i < labels.size() else "?",
			"effects": _default_effects(i),
			"direction": directions[i],
		})
	return {"text": narrative, "options": options, "tags": ["llm_generated", "raw_fallback"]}


func _default_effects(option_idx: int) -> Array:
	match option_idx:
		0: return [{"type": "HEAL_LIFE", "amount": 5}]
		1: return [{"type": "ADD_KARMA", "amount": 3}]
		2: return [{"type": "DAMAGE_LIFE", "amount": 3}]
		_: return []


# ═══════════════════════════════════════════════════════════════════════════════
# RESOLUTION GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_resolution(card_text: String, chosen_label: String, effects: Array) -> String:
	if not _merlin_ai or not _merlin_ai.has_method("generate_with_system"):
		return ""
	var effects_summary := _effects_str(effects)
	var sys_prompt := "Tu es Merlin, druide narrateur. Decris en 1-2 phrases courtes la consequence du choix du voyageur. Francais uniquement. Ton poetique et celtique."
	var user_prompt := "Scene: %s\nChoix: %s\nEffets: %s\nDecris la consequence." % [
		card_text.substr(0, 200), chosen_label, effects_summary]
	var result: Dictionary = await _merlin_ai.generate_with_system(
		sys_prompt, user_prompt, {"max_tokens": 60, "temperature": 0.55})
	if result.has("error"):
		return ""
	return str(result.get("text", "")).strip_edges()


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func _build_context(state: BenchRunState) -> Dictionary:
	var time_info: Dictionary = TIME_TONES.get(time_of_day, TIME_TONES["crepuscule"])
	var season_info: Dictionary = SEASON_TONES.get(season, SEASON_TONES["automne"])

	# Danger signals
	var danger_signals: Array[String] = []
	if state.life <= 25:
		danger_signals.append("VIE BASSE (%d) — favorise options de soin" % state.life)
	var extreme_count: int = 0
	for v in state.aspects.values():
		if int(v) != 0:
			extreme_count += 1
	if extreme_count >= 2:
		danger_signals.append("CRISE ASPECTS: %d/3 non-equilibres" % extreme_count)

	# Temporal guidance
	var temporal_hint := "C'est %s en %s. Ton %s, %s." % [
		str(time_info.label), str(season_info.label),
		str(time_info.tone), str(season_info.tone)]

	# Recent events summary
	var recent_events := ""
	if state.story_log.size() > 0:
		var parts: Array[String] = []
		for entry in state.story_log.slice(-3):
			var t: String = str(entry.get("text", "")).substr(0, 60)
			var c: String = str(entry.get("choice", ""))
			if not t.is_empty():
				parts.append("%s (choix: %s)" % [t, c])
		recent_events = ". ".join(parts)

	return {
		"aspects": state.aspects.duplicate(),
		"souffle": state.souffle,
		"life_essence": state.life,
		"cards_played": state.cards_played,
		"day": state.day,
		"active_tags": [],
		"biome": biome,
		"story_log": state.story_log.slice(-10),
		"karma": state.karma,
		"danger_signals": danger_signals,
		"narrator_guidance": temporal_hint,
		"recent_events": recent_events,
		"season": season,
		"time_of_day": time_of_day,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# QUALITY METRICS
# ═══════════════════════════════════════════════════════════════════════════════

func _measure_quality(text: String, options: Array, prev_texts: Array[String]) -> Dictionary:
	var format_ok := text.length() >= MIN_TEXT_LEN and options.size() == 3
	if format_ok:
		for opt in options:
			if not opt is Dictionary or str(opt.get("label", "")).is_empty():
				format_ok = false
				break

	var french_rate := _compute_fr_ratio(text)

	var celtic_result := _count_celtic(text)

	var max_jaccard := 0.0
	for prev in prev_texts:
		var j: float = _jaccard(text, prev)
		if j > max_jaccard:
			max_jaccard = j

	var forbidden_found := _find_forbidden(text)

	return {
		"format_ok": format_ok,
		"french_rate": french_rate,
		"celtic_count": celtic_result.count,
		"celtic_words": celtic_result.words,
		"max_jaccard": max_jaccard,
		"forbidden_found": forbidden_found,
	}


func _compute_fr_ratio(text: String) -> float:
	var words: PackedStringArray = text.to_lower().split(" ", false)
	if words.size() == 0:
		return 0.0
	var hits: int = 0
	for w in words:
		if w in FR_KEYWORDS:
			hits += 1
	return float(hits) / float(words.size())


func _count_celtic(text: String) -> Dictionary:
	var lower: String = text.to_lower()
	var count: int = 0
	var found: Array[String] = []
	for word in CELTIC_VOCAB:
		if lower.contains(word):
			count += 1
			found.append(word)
	return {"count": count, "words": found}


func _find_forbidden(text: String) -> String:
	var lower: String = text.to_lower()
	for word in FORBIDDEN_WORDS:
		if lower.contains(" " + word + " ") or lower.begins_with(word + " ") \
		   or lower.ends_with(" " + word) or lower == word:
			return word
	return ""


func _jaccard(a: String, b: String) -> float:
	var set_a: Dictionary = {}
	var set_b: Dictionary = {}
	for w in a.to_lower().split(" ", false):
		set_a[w] = true
	for w in b.to_lower().split(" ", false):
		set_b[w] = true
	if set_a.is_empty() and set_b.is_empty():
		return 0.0
	var intersection: int = 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE STRATEGY + EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func _pick_choice(options: Array, state: BenchRunState) -> int:
	var max_idx: int = mini(options.size(), 3) - 1
	if max_idx < 0:
		return 0
	match auto_strategy:
		Strategy.RANDOM:
			return randi_range(0, max_idx)
		Strategy.CAUTIOUS:
			return 0  # always left (often defensive)
		Strategy.AGGRESSIVE:
			return max_idx  # always right (often risky)
		_:  # MIXED
			if state.life < 30:
				return 0  # heal when in danger
			elif state.cards_played > num_cards * 0.7:
				return max_idx  # aggressive late game
			else:
				return randi_range(0, max_idx)


func _apply_effects(state: BenchRunState, effects: Array) -> void:
	for eff in effects:
		if not eff is Dictionary:
			continue
		var eff_type: String = str(eff.get("type", ""))
		var amount: int = int(eff.get("amount", 0))
		match eff_type:
			"HEAL_LIFE":
				state.life = mini(state.life + amount, 100)
			"DAMAGE_LIFE":
				state.life = maxi(state.life - amount, 0)
			"ADD_KARMA":
				state.karma += amount
			"ADD_SOUFFLE":
				state.souffle = mini(state.souffle + amount, 7)
			"USE_SOUFFLE":
				state.souffle = maxi(state.souffle - 1, 0)
			"SHIFT_ASPECT":
				var asp: String = str(eff.get("aspect", ""))
				var dir: String = str(eff.get("direction", ""))
				if state.aspects.has(asp):
					var current: int = int(state.aspects[asp])
					if dir == "up":
						state.aspects[asp] = mini(current + 1, 1)
					elif dir == "down":
						state.aspects[asp] = maxi(current - 1, -1)
			"ADD_TENSION":
				state.tension = mini(state.tension + amount, 100)


func _degrade_state(state: BenchRunState, card_idx: int) -> void:
	# Progressive degradation to test danger scenarios
	if card_idx == 4:
		state.aspects["Corps"] = -1
	elif card_idx == 9:
		state.aspects["Ame"] = -1
	elif card_idx == 13:
		state.aspects["Monde"] = -1
	state.tension = mini(state.tension + 5, 100)


# ═══════════════════════════════════════════════════════════════════════════════
# COHERENCE JUDGE
# ═══════════════════════════════════════════════════════════════════════════════

func _judge_coherence(story_log: Array[Dictionary]) -> Dictionary:
	if not _merlin_ai or not _merlin_ai.has_method("generate_with_system"):
		return {"error": "MerlinAI unavailable"}

	# Build condensed story (max ~2000 chars to fit context)
	var story_text := ""
	for entry in story_log:
		var line := "Carte %d: %s" % [int(entry.get("card_num", 0)), str(entry.get("text", "")).substr(0, 120)]
		if not str(entry.get("choice", "")).is_empty():
			line += " → Choix: %s" % str(entry.choice)
		if not str(entry.get("resolution", "")).is_empty():
			line += " → %s" % str(entry.resolution).substr(0, 80)
		story_text += line + "\n"
		if story_text.length() > 2000:
			break

	var sys_prompt := "Tu es un critique litteraire specialise en recits celtiques. " + \
		"Evalue la coherence narrative de cette histoire. " + \
		"Reponds UNIQUEMENT en JSON valide: " + \
		"{\"score\": N, \"strengths\": \"...\", \"weaknesses\": \"...\", \"reasoning\": \"...\"} " + \
		"Score 1-10. Criteres: progression logique, cause-effet, unite thematique, " + \
		"continuite des personnages, credibilite du monde."

	var user_prompt := "HISTOIRE COMPLETE:\n%s\nBIOME: %s, SAISON: %s, HEURE: %s\nEvalue la coherence." % [
		story_text, biome, season, time_of_day]

	var result: Dictionary = await _merlin_ai.generate_with_system(
		sys_prompt, user_prompt, {"max_tokens": 250, "temperature": 0.2})

	if result.has("error"):
		return {"error": str(result.error)}

	var raw_text: String = str(result.get("text", ""))

	# Try JSON parse
	var json_start: int = raw_text.find("{")
	var json_end: int = raw_text.rfind("}")
	if json_start >= 0 and json_end > json_start:
		var json_str: String = raw_text.substr(json_start, json_end - json_start + 1)
		var parsed = JSON.parse_string(json_str)
		if typeof(parsed) == TYPE_DICTIONARY:
			parsed["raw"] = raw_text
			return parsed

	# Regex fallback: extract score
	var regex := RegEx.new()
	regex.compile("(?i)(?:score|note)[^0-9]*([0-9]+)")
	var m := regex.search(raw_text)
	var score: int = int(m.get_string(1)) if m else 0
	return {"score": score, "reasoning": raw_text, "raw": raw_text, "parse_method": "regex_fallback"}


# ═══════════════════════════════════════════════════════════════════════════════
# AGGREGATE METRICS
# ═══════════════════════════════════════════════════════════════════════════════

func _compute_aggregate(card_log: Array[Dictionary], gen_times: Array[int], ended_early: bool) -> Dictionary:
	var valid_cards: int = 0
	var format_ok_count: int = 0
	var total_french: float = 0.0
	var total_celtic: int = 0
	var total_jaccard: float = 0.0
	var forbidden_count: int = 0

	for entry in card_log:
		if entry.get("failed", false):
			continue
		valid_cards += 1
		if entry.get("format_ok", false):
			format_ok_count += 1
		total_french += float(entry.get("french_rate", 0.0))
		total_celtic += int(entry.get("celtic_count", 0))
		total_jaccard += float(entry.get("max_jaccard", 0.0))
		if not str(entry.get("forbidden_found", "")).is_empty():
			forbidden_count += 1

	var total_ms: int = 0
	for t in gen_times:
		total_ms += t

	return {
		"total_cards": card_log.size(),
		"valid_cards": valid_cards,
		"failed_cards": card_log.size() - valid_cards,
		"run_ended_early": ended_early,
		"total_time_s": total_ms / 1000,
		"cards_per_min": (60000.0 / (float(total_ms) / float(gen_times.size()))) if gen_times.size() > 0 else 0.0,
		"p50_ms": _percentile(gen_times, 50),
		"p90_ms": _percentile(gen_times, 90),
		"format_pct": (float(format_ok_count) / float(valid_cards) * 100.0) if valid_cards > 0 else 0.0,
		"avg_french": (total_french / float(valid_cards)) if valid_cards > 0 else 0.0,
		"avg_celtic": (float(total_celtic) / float(valid_cards)) if valid_cards > 0 else 0.0,
		"avg_jaccard": (total_jaccard / float(valid_cards)) if valid_cards > 0 else 0.0,
		"forbidden_count": forbidden_count,
		"ram_start_mb": _ram_start / 1048576.0,
		"ram_end_mb": OS.get_static_memory_usage() / 1048576.0,
	}


func _percentile(arr: Array[int], pct: int) -> int:
	if arr.is_empty():
		return 0
	var sorted_arr: Array[int] = arr.duplicate()
	sorted_arr.sort()
	var idx: int = clampi(int(sorted_arr.size() * pct / 100), 0, sorted_arr.size() - 1)
	return sorted_arr[idx]


func _print_aggregate(agg: Dictionary) -> void:
	_log("\n┌── AGGREGATE METRICS ──────────────────")
	_log("│  Cards: %d valid / %d total (%d failed)" % [
		int(agg.valid_cards), int(agg.total_cards), int(agg.failed_cards)])
	_log("│  Latency p50: %dms | p90: %dms" % [int(agg.p50_ms), int(agg.p90_ms)])
	_log("│  Throughput: %.1f cards/min | Total: %ds" % [float(agg.cards_per_min), int(agg.total_time_s)])
	_log("│  Format compliance: %.0f%%" % float(agg.format_pct))
	_log("│  French rate: %.0f%%" % (float(agg.avg_french) * 100.0))
	_log("│  Celtic vocab/card: %.1f" % float(agg.avg_celtic))
	_log("│  Avg Jaccard: %.2f" % float(agg.avg_jaccard))
	_log("│  Forbidden words: %d" % int(agg.forbidden_count))
	_log("│  RAM: %.1f → %.1f MB (%+.1f)" % [
		float(agg.ram_start_mb), float(agg.ram_end_mb),
		float(agg.ram_end_mb) - float(agg.ram_start_mb)])
	_log("│  Run ended early: %s" % str(agg.run_ended_early))
	_log("└───────────────────────────────────────")


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-MODEL COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════

func _print_comparison() -> void:
	if _all_runs.size() < 2:
		return
	_log("\n╔══ MODEL COMPARISON ════════════════════════════════")
	_log("║  %-25s" % "Metric" + "".join(Array(_all_runs.map(func(r): return " | %-15s" % str(r.model).substr(0, 15)))))
	_log("║  " + "-".repeat(25 + _all_runs.size() * 18))

	var metrics := ["format_pct", "avg_french", "avg_celtic", "avg_jaccard", "p50_ms", "cards_per_min"]
	var labels := ["Format %", "French rate", "Celtic/card", "Avg Jaccard", "Latency p50", "Cards/min"]
	for i in range(metrics.size()):
		var line := "║  %-25s" % labels[i]
		for run in _all_runs:
			var val = run.get("aggregate", {}).get(metrics[i], 0)
			if metrics[i] in ["avg_french"]:
				line += " | %-15s" % ("%.0f%%" % (float(val) * 100.0))
			elif metrics[i] in ["avg_celtic", "avg_jaccard", "cards_per_min"]:
				line += " | %-15s" % ("%.1f" % float(val))
			else:
				line += " | %-15s" % str(val)
		_log(line)

	# Coherence scores
	var coherence_line := "║  %-25s" % "Coherence"
	for run in _all_runs:
		var score = run.get("coherence", {}).get("score", "N/A")
		coherence_line += " | %-15s" % ("%s/10" % str(score))
	_log(coherence_line)
	_log("╚════════════════════════════════════════════════════")


# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT
# ═══════════════════════════════════════════════════════════════════════════════

func _export_json_report() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"config": {
			"biome": biome, "season": season, "time_of_day": time_of_day,
			"num_cards": num_cards, "model": model_name,
			"strategy": Strategy.keys()[auto_strategy],
			"resolutions": generate_resolutions,
			"coherence_judge": run_coherence_judge,
		},
		"runs": _all_runs,
	}
	var json_str: String = JSON.stringify(data, "  ")

	# Write to user:// and Downloads
	for path in ["user://benchmark_run_%s.json" % timestamp,
				  "C:/Users/PGNK2128/Downloads/benchmark_run_%s.json" % timestamp]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file.close()
			_log("Exported: %s" % path)


func _export_markdown_report() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var md := "# LLM Benchmark Run Report\n\n"
	md += "**Date**: %s\n" % Time.get_datetime_string_from_system()
	md += "**Config**: %s | %s | %s | %d cards | strategy=%s\n\n" % [
		biome, season, time_of_day, num_cards, Strategy.keys()[auto_strategy]]

	for run in _all_runs:
		md += "## Model: %s\n\n" % str(run.model)

		# Aggregate table
		var agg: Dictionary = run.get("aggregate", {})
		md += "| Metric | Value |\n|--------|-------|\n"
		md += "| Cards | %d/%d |\n" % [int(agg.get("valid_cards", 0)), int(agg.get("total_cards", 0))]
		md += "| Latency p50 | %dms |\n" % int(agg.get("p50_ms", 0))
		md += "| Latency p90 | %dms |\n" % int(agg.get("p90_ms", 0))
		md += "| Format | %.0f%% |\n" % float(agg.get("format_pct", 0))
		md += "| French rate | %.0f%% |\n" % (float(agg.get("avg_french", 0)) * 100.0)
		md += "| Celtic/card | %.1f |\n" % float(agg.get("avg_celtic", 0))
		md += "| Jaccard | %.2f |\n" % float(agg.get("avg_jaccard", 0))
		md += "| Throughput | %.1f cards/min |\n\n" % float(agg.get("cards_per_min", 0))

		# Coherence
		var coh: Dictionary = run.get("coherence", {})
		if coh.has("score"):
			md += "### Coherence: %s/10\n\n" % str(coh.score)
			md += "- **Forces**: %s\n" % str(coh.get("strengths", ""))
			md += "- **Faiblesses**: %s\n" % str(coh.get("weaknesses", ""))
			md += "- **Raisonnement**: %s\n\n" % str(coh.get("reasoning", ""))

		# Card log
		md += "### Decision Tree\n\n"
		for entry in run.get("cards", []):
			if entry.get("failed", false):
				md += "- **Card %d**: FAILED\n" % int(entry.get("card_num", 0))
				continue
			var text_preview: String = str(entry.get("text", "")).substr(0, 60)
			md += "- **Card %d** (%dms, fr=%.0f%%, celtic=%d): \"%s...\" → %s" % [
				int(entry.card_num), int(entry.gen_ms),
				float(entry.get("french_rate", 0)) * 100.0,
				int(entry.get("celtic_count", 0)),
				text_preview,
				str(entry.get("choice_label", "?"))]
			if not str(entry.get("resolution", "")).is_empty():
				md += " → \"%s\"" % str(entry.resolution).substr(0, 60)
			md += "\n"
		md += "\n"

	var file := FileAccess.open("C:/Users/PGNK2128/Downloads/benchmark_run_%s.md" % timestamp, FileAccess.WRITE)
	if file:
		file.store_string(md)
		file.close()
		_log("Exported: Downloads/benchmark_run_%s.md" % timestamp)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _effects_str(effects: Array) -> String:
	var parts: Array[String] = []
	for eff in effects:
		if not eff is Dictionary:
			continue
		var t: String = str(eff.get("type", "?"))
		var a: String = str(eff.get("amount", ""))
		var asp: String = str(eff.get("aspect", ""))
		var dir: String = str(eff.get("direction", ""))
		if t == "SHIFT_ASPECT":
			parts.append("%s:%s:%s" % [t, asp, dir])
		elif not a.is_empty():
			parts.append("%s:%s" % [t, a])
		else:
			parts.append(t)
	return ", ".join(parts) if not parts.is_empty() else "none"


func _extract_labels(options: Array) -> Array[String]:
	var labels: Array[String] = []
	for opt in options:
		if opt is Dictionary:
			labels.append(str(opt.get("label", "?")))
	return labels


func _log(msg: String) -> void:
	print("[BENCH] %s" % msg)
