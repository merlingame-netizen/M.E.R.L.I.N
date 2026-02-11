## ═══════════════════════════════════════════════════════════════════════════════
## RAG Manager v2.0 — Retrieval Augmented Generation for Qwen2.5-3B-Instruct
## ═══════════════════════════════════════════════════════════════════════════════
## Structured retrieval with token budget, game journal, and cross-run memory.
## Optimized for nano models (~2048 token context window).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name RAGManager

const VERSION := "2.1.0"

# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN BUDGET — Critical for nano models
# ═══════════════════════════════════════════════════════════════════════════════

## Approximate tokens: 1 token ~= 4 chars (rough heuristic for multilingual)
const CHARS_PER_TOKEN := 4
const CONTEXT_BUDGET := 600  # max tokens for dynamic context injection (v2.2: 300→600, Qwen 2.5-3B has 8192 ctx, ~11% usage)

# Priority levels for context sections (higher = more important, kept first)
enum Priority { CRITICAL = 4, HIGH = 3, MEDIUM = 2, LOW = 1, OPTIONAL = 0 }

# ═══════════════════════════════════════════════════════════════════════════════
# STORAGE PATHS
# ═══════════════════════════════════════════════════════════════════════════════

const JOURNAL_PATH := "user://ai/memory/game_journal.json"
const CROSS_RUN_PATH := "user://ai/memory/cross_run_memory.json"
const WORLD_STATE_PATH := "user://ai/memory/world_state.json"

# ═══════════════════════════════════════════════════════════════════════════════
# GAME JOURNAL — Structured event log for current run
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_JOURNAL_ENTRIES := 100

var journal: Array[Dictionary] = []
## Each entry: {
##   type: "card_played"|"choice_made"|"effect_applied"|"aspect_shifted"|"ogham_used"|"run_event",
##   card_num: int, day: int, data: Dictionary, timestamp: float
## }

# ═══════════════════════════════════════════════════════════════════════════════
# CROSS-RUN MEMORY — Compressed summaries from past runs
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_CROSS_RUN_SUMMARIES := 20

var cross_run_memory: Array[Dictionary] = []
## Each: { run_id, ending, cards_played, dominant_aspect, notable_events, player_style, score }

# ═══════════════════════════════════════════════════════════════════════════════
# WORLD STATE — Synced from MOS registries
# ═══════════════════════════════════════════════════════════════════════════════

var world_state: Dictionary = {}
var actions_by_category: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_ensure_storage()
	_load_journal()
	_load_cross_run_memory()
	_load_world_state()
	_load_actions()


func _ensure_storage() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://ai/memory")
	)


# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN BUDGET MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func estimate_tokens(text: String) -> int:
	return ceili(text.length() / float(CHARS_PER_TOKEN))


func trim_to_budget(text: String, max_tokens: int) -> String:
	var max_chars := max_tokens * CHARS_PER_TOKEN
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars - 3) + "..."


# ═══════════════════════════════════════════════════════════════════════════════
# STRUCTURED CONTEXT RETRIEVAL — Priority-based for nano models
# ═══════════════════════════════════════════════════════════════════════════════

func get_prioritized_context(game_state: Dictionary) -> String:
	## Build context string within token budget, prioritized by importance.
	var sections: Array[Dictionary] = []

	var crisis := _get_crisis_context(game_state)
	if not crisis.is_empty():
		sections.append({"text": crisis, "priority": Priority.CRITICAL})

	var recent := _get_recent_narrative()
	if not recent.is_empty():
		sections.append({"text": recent, "priority": Priority.HIGH})

	var arcs := _get_active_arcs_context()
	if not arcs.is_empty():
		sections.append({"text": arcs, "priority": Priority.HIGH})

	var biome_ctx := _get_biome_context(game_state)
	if not biome_ctx.is_empty():
		sections.append({"text": biome_ctx, "priority": Priority.HIGH})

	var tone_ctx := _get_tone_context()
	if not tone_ctx.is_empty():
		sections.append({"text": tone_ctx, "priority": Priority.HIGH})

	var karma_tension := _get_karma_tension_context(game_state)
	if not karma_tension.is_empty():
		sections.append({"text": karma_tension, "priority": Priority.HIGH})

	var promises := _get_promises_context()
	if not promises.is_empty():
		sections.append({"text": promises, "priority": Priority.MEDIUM})

	var pattern := _get_player_pattern_context()
	if not pattern.is_empty():
		sections.append({"text": pattern, "priority": Priority.MEDIUM})

	var bestiole := _get_bestiole_context(game_state)
	if not bestiole.is_empty():
		sections.append({"text": bestiole, "priority": Priority.MEDIUM})

	var callbacks := _get_cross_run_callbacks()
	if not callbacks.is_empty():
		sections.append({"text": callbacks, "priority": Priority.LOW})

	sections.sort_custom(func(a, b): return int(a.priority) > int(b.priority))

	var result := ""
	var tokens_used := 0
	for section in sections:
		var section_tokens := estimate_tokens(section.text)
		if tokens_used + section_tokens <= CONTEXT_BUDGET:
			result += section.text + "\n"
			tokens_used += section_tokens
		else:
			var remaining := maxi(CONTEXT_BUDGET - tokens_used, 0)
			if remaining > 10:
				result += trim_to_budget(section.text, remaining) + "\n"
			break

	return result.strip_edges()


func _get_crisis_context(game_state: Dictionary) -> String:
	var run: Dictionary = game_state.get("run", {})
	var aspects: Dictionary = run.get("aspects", {})
	var souffle: int = int(run.get("souffle", 3))
	var crises: Array[String] = []
	for aspect in aspects:
		var val: int = int(aspects[aspect])
		if val <= -1:
			crises.append("%s=BAS" % aspect)
		elif val >= 1:
			crises.append("%s=HAUT" % aspect)
	if souffle <= 1:
		crises.append("Souffle=%d" % souffle)
	if crises.is_empty():
		return ""
	return "CRISE: " + ", ".join(crises)


func _get_recent_narrative() -> String:
	if journal.is_empty():
		return ""
	var recent := journal.slice(-mini(journal.size(), 10))
	var parts: Array[String] = []
	for entry in recent:
		if entry.get("type") == "choice_made":
			var data: Dictionary = entry.get("data", {})
			parts.append(str(data.get("label", "?")))
	if parts.is_empty():
		return ""
	return "Recents: " + ", ".join(parts)


func _get_active_arcs_context() -> String:
	var arcs: Array = world_state.get("active_arcs", [])
	if arcs.is_empty():
		return ""
	var parts: Array[String] = []
	for arc in arcs:
		if arc is Dictionary:
			var arc_id: String = str(arc.get("id", "?"))
			var progress: int = int(arc.get("progress", 0))
			var total: int = int(arc.get("total", 0))
			if total > 0:
				parts.append("%s (%d/%d)" % [arc_id, progress, total])
			else:
				parts.append(arc_id)
	if parts.is_empty():
		return ""
	return "Arcs: " + ", ".join(parts)


func _get_player_pattern_context() -> String:
	var patterns: Dictionary = world_state.get("player_patterns", {})
	if patterns.is_empty():
		return ""
	var best_pattern := ""
	var best_confidence := 0.0
	for p_name in patterns:
		var conf: float = float(patterns[p_name].get("confidence", 0))
		if conf > best_confidence and conf > 0.6:
			best_confidence = conf
			best_pattern = p_name
	if best_pattern.is_empty():
		return ""
	return "Style: " + best_pattern


func _get_bestiole_context(game_state: Dictionary) -> String:
	var bestiole: Dictionary = game_state.get("bestiole", {})
	var bond: int = int(bestiole.get("bond", 50))
	if bond >= 80:
		return "Bestiole: lien fort"
	elif bond <= 20:
		return "Bestiole: lien faible"
	return ""


func _get_biome_context(game_state: Dictionary) -> String:
	var run: Dictionary = game_state.get("run", {})
	var biome_key: String = str(run.get("current_biome", ""))
	if biome_key.is_empty():
		return ""
	# Access MerlinBiomeSystem via explicit load (avoids parse-order issues)
	var BiomeSystemClass: GDScript = load("res://scripts/merlin/merlin_biome_system.gd")
	var biome_sys = BiomeSystemClass.new()
	return biome_sys.get_biome_context_for_llm(biome_key)


func _get_tone_context() -> String:
	## Build tone/register context from synced world state.
	var tone: String = str(world_state.get("current_tone", ""))
	if tone.is_empty() or tone == "neutral":
		return ""
	var chars: Dictionary = world_state.get("tone_characteristics", {})
	var parts: Array[String] = ["Registre: " + tone]
	var vocab: String = str(chars.get("vocabulary", ""))
	if not vocab.is_empty() and vocab != "standard":
		parts.append("vocab=" + vocab)
	var emotion: String = str(chars.get("emotion", ""))
	if not emotion.is_empty() and emotion != "detached":
		parts.append("emotion=" + emotion)
	return " ".join(parts)


func _get_karma_tension_context(game_state: Dictionary) -> String:
	## Build karma and tension context from game state.
	var run: Dictionary = game_state.get("run", {})
	var parts: Array[String] = []
	var karma: int = int(run.get("karma", 0))
	if karma >= 5:
		parts.append("Karma: positif fort (%d)" % karma)
	elif karma <= -5:
		parts.append("Karma: negatif fort (%d)" % karma)
	var flux: Dictionary = run.get("flux", {})
	var tension: int = int(flux.get("tension", 40))
	if tension >= 70:
		parts.append("Tension: haute")
	elif tension <= 20:
		parts.append("Tension: basse")
	var day: int = int(run.get("day", 1))
	if day >= 15:
		parts.append("Jour %d (fin proche)" % day)
	if parts.is_empty():
		return ""
	return "Etat: " + ", ".join(parts)


func _get_promises_context() -> String:
	## Build active promises/engagements context from world state.
	var promises: Array = world_state.get("active_promises", [])
	if promises.is_empty():
		return ""
	var labels: Array[String] = []
	for promise in promises:
		if promise is Dictionary:
			var label: String = str(promise.get("label", ""))
			if not label.is_empty():
				labels.append(label)
	if labels.is_empty():
		return ""
	return "Promesses: " + ", ".join(labels)


func _get_cross_run_callbacks() -> String:
	if cross_run_memory.is_empty():
		return ""
	var last_run: Dictionary = cross_run_memory[-1]
	var ending: String = str(last_run.get("ending", ""))
	if not ending.is_empty():
		return "Run precedent: " + ending
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# JOURNAL OPERATIONS — Structured game event logging
# ═══════════════════════════════════════════════════════════════════════════════

func log_card_played(card: Dictionary, card_num: int, day: int) -> void:
	_add_journal_entry("card_played", card_num, day, {
		"text": str(card.get("text", "")).substr(0, 60),
		"tags": card.get("tags", []),
		"generated_by": card.get("_generated_by", "unknown"),
	})


func log_choice_made(option: Dictionary, card_num: int, day: int) -> void:
	_add_journal_entry("choice_made", card_num, day, {
		"label": option.get("label", "?"),
		"effects": option.get("effects", []),
		"cost": option.get("cost", 0),
	})


func log_aspect_shifted(aspect: String, old_state: int, new_state: int, card_num: int, day: int) -> void:
	_add_journal_entry("aspect_shifted", card_num, day, {
		"aspect": aspect, "from": old_state, "to": new_state,
	})


func log_ogham_used(ogham_id: String, card_num: int, day: int) -> void:
	_add_journal_entry("ogham_used", card_num, day, {"ogham": ogham_id})


func log_run_event(event_type: String, details: Dictionary, card_num: int, day: int) -> void:
	_add_journal_entry("run_event", card_num, day, {"event": event_type, "details": details})


func _add_journal_entry(type: String, card_num: int, day: int, data: Dictionary) -> void:
	journal.append({
		"type": type, "card_num": card_num, "day": day,
		"data": data, "timestamp": Time.get_unix_time_from_system(),
	})
	if journal.size() > MAX_JOURNAL_ENTRIES:
		journal = journal.slice(-MAX_JOURNAL_ENTRIES)


# ═══════════════════════════════════════════════════════════════════════════════
# CROSS-RUN MEMORY — Compressed run summaries
# ═══════════════════════════════════════════════════════════════════════════════

func summarize_and_archive_run(ending: String, final_state: Dictionary) -> void:
	cross_run_memory.append({
		"run_id": cross_run_memory.size() + 1,
		"ending": ending,
		"cards_played": journal.size(),
		"dominant_aspect": _find_dominant_aspect(final_state),
		"notable_events": _extract_notable_events(),
		"player_style": _classify_player_style(),
		"score": int(final_state.get("score", 0)),
	})
	if cross_run_memory.size() > MAX_CROSS_RUN_SUMMARIES:
		cross_run_memory = cross_run_memory.slice(-MAX_CROSS_RUN_SUMMARIES)
	_save_cross_run_memory()
	journal.clear()
	save_journal()


func _find_dominant_aspect(final_state: Dictionary) -> String:
	var aspects: Dictionary = final_state.get("run", {}).get("aspects", {})
	var max_abs := 0
	var dominant := "equilibre"
	for aspect in aspects:
		if absi(int(aspects[aspect])) > max_abs:
			max_abs = absi(int(aspects[aspect]))
			dominant = str(aspect)
	return dominant


func _extract_notable_events() -> Array:
	var notable: Array = []
	for entry in journal:
		if entry.get("type") == "aspect_shifted":
			var d: Dictionary = entry.get("data", {})
			if absi(int(d.get("to", 0))) >= 1:
				notable.append("%s extreme" % str(d.get("aspect", "?")))
		elif entry.get("type") == "ogham_used":
			notable.append("ogham:" + str(entry.get("data", {}).get("ogham", "?")))
	if notable.size() > 3:
		notable = notable.slice(-3)
	return notable


func _classify_player_style() -> String:
	var center_count := 0
	var total := 0
	for entry in journal:
		if entry.get("type") == "choice_made":
			total += 1
			if int(entry.get("data", {}).get("cost", 0)) > 0:
				center_count += 1
	if total == 0:
		return "equilibre"
	if center_count > total * 0.4:
		return "prudent"
	return "audacieux"


# ═══════════════════════════════════════════════════════════════════════════════
# WORLD STATE — Sync with MOS registries
# ═══════════════════════════════════════════════════════════════════════════════

func update_world_state(key: String, value) -> void:
	world_state[key] = value


func sync_from_registries(registries: Dictionary) -> void:
	for key in registries:
		world_state[key] = registries[key]
	save_world_state()


# ═══════════════════════════════════════════════════════════════════════════════
# RETRIEVAL — Search across all memory sources
# ═══════════════════════════════════════════════════════════════════════════════

func search_journal(keywords: Array[String], max_results: int = 5) -> Array:
	var scored: Array = []
	for entry in journal:
		var text := JSON.stringify(entry.get("data", {})).to_lower()
		var score := 0
		for kw in keywords:
			if kw.length() > 2 and text.contains(kw.to_lower()):
				score += 1
		if score > 0:
			scored.append({"entry": entry, "score": score})
	scored.sort_custom(func(a, b): return int(a.score) > int(b.score))
	return scored.slice(0, mini(scored.size(), max_results))


func get_run_count() -> int:
	return cross_run_memory.size()


func get_last_ending() -> String:
	if cross_run_memory.is_empty():
		return ""
	return str(cross_run_memory[-1].get("ending", ""))


# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func save_journal() -> void:
	var file := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(journal))
		file.close()


func _load_journal() -> void:
	if FileAccess.file_exists(JOURNAL_PATH):
		var file := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Array:
				journal.assign(data)


func _save_cross_run_memory() -> void:
	var file := FileAccess.open(CROSS_RUN_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cross_run_memory))
		file.close()


func _load_cross_run_memory() -> void:
	if FileAccess.file_exists(CROSS_RUN_PATH):
		var file := FileAccess.open(CROSS_RUN_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Array:
				cross_run_memory.assign(data)


func save_world_state() -> void:
	var file := FileAccess.open(WORLD_STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(world_state))
		file.close()


func _load_world_state() -> void:
	if FileAccess.file_exists(WORLD_STATE_PATH):
		var file := FileAccess.open(WORLD_STATE_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary:
				world_state = data


func _load_actions() -> void:
	var path := "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary and data.has("categories"):
				actions_by_category = data.categories


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY COMPATIBILITY
# ═══════════════════════════════════════════════════════════════════════════════

func get_relevant_context(query: String, _category: String) -> Dictionary:
	return {
		"recent_history": journal.slice(-5) if journal.size() >= 5 else journal,
		"relevant_history": search_journal(query.split(" ") as Array[String], 3).map(func(x): return x.entry),
		"world_state_subset": world_state,
		"available_actions": [],
	}


func add_to_history(input_text: String, response: String) -> void:
	log_run_event("legacy_exchange", {"input": input_text, "response": response.substr(0, 100)}, journal.size(), 0)
