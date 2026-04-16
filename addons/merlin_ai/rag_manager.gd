## ═══════════════════════════════════════════════════════════════════════════════
## RAG Manager v3.0 — Retrieval Augmented Generation for Qwen 3.5 Multi-Brain
## ═══════════════════════════════════════════════════════════════════════════════
## Structured retrieval with per-brain token budget, game journal, cross-run memory.
## v3.0: Budget scales per brain role (4B=800, 2B=400, 0.8B=200 tokens).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name RAGManager

const VERSION := "3.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN BUDGET — Per-brain, scaled to model context capacity
# ═══════════════════════════════════════════════════════════════════════════════

## Approximate tokens: 1 token ~= 4 chars (rough heuristic for multilingual)
const CHARS_PER_TOKEN := 4
const CONTEXT_BUDGET := 400  # Default budget (backward compat)

## Per-brain budgets: larger models get richer context
const BRAIN_BUDGETS := {
	"narrator": 800,     # 4B model, 8192 context — rich narrative history
	"gamemaster": 400,   # 2B model, 4096 context — game state focused
	"judge": 200,        # 0.8B model, 2048 context — minimal, just text to score
	"worker": 200,       # 0.8B model, 2048 context — fast tasks
}

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
## Each: { run_id, ending, cards_played, dominant_faction, notable_events, player_style, score }

# ═══════════════════════════════════════════════════════════════════════════════
# WORLD STATE — Synced from MOS registries
# ═══════════════════════════════════════════════════════════════════════════════

var world_state: Dictionary = {}
var actions_by_category: Dictionary = {}
var _scene_context: Dictionary = {}

# Phase 44 — Tag glossary for narrative context enrichment
var _tag_glossary: Dictionary = {}
var _theme_dualities: Array = []
var _biome_tags: Dictionary = {}
var _tag_glossary_loaded := false

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_ensure_storage()
	_load_journal()
	_load_cross_run_memory()
	_load_world_state()
	_load_actions()
	_load_tag_glossary()


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

func get_prioritized_context(game_state: Dictionary, brain_role: String = "") -> String:
	## Build context string within token budget, prioritized by importance.
	## brain_role: "narrator", "gamemaster", "judge", "worker" — scales budget per brain.
	var sections: Array[Dictionary] = []

	var crisis := _get_crisis_context(game_state)
	if not crisis.is_empty():
		sections.append({"text": crisis, "priority": Priority.CRITICAL})

	var scene_ctx := _get_scene_contract_context()
	if not scene_ctx.is_empty():
		sections.append({"text": scene_ctx, "priority": Priority.CRITICAL})

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

	var faction_ctx := _get_faction_context(game_state)
	if not faction_ctx.is_empty():
		sections.append({"text": faction_ctx, "priority": Priority.MEDIUM})

	# Phase 44: Event category context from tag glossary
	var event_ctx := _get_event_category_context(game_state)
	if not event_ctx.is_empty():
		sections.append({"text": event_ctx, "priority": Priority.MEDIUM})

	# P1.10.1: Player profile context (compact summary from registry)
	var profile_ctx := _get_player_profile_context()
	if not profile_ctx.is_empty():
		sections.append({"text": profile_ctx, "priority": Priority.MEDIUM})

	# B.3: Archetype context (~40 tokens, helps narrator align tone with archetype)
	var archetype_ctx := _get_archetype_context()
	if not archetype_ctx.is_empty():
		sections.append({"text": archetype_ctx, "priority": Priority.MEDIUM})

	# B.4: Aspect states context — informs LLM of extreme states for narrative coherence
	var aspects_ctx := _get_aspects_state_context(game_state)
	if not aspects_ctx.is_empty():
		sections.append({"text": aspects_ctx, "priority": Priority.HIGH})

	# P1.10.1: Danger level context (life-based urgency)
	var danger_ctx := _get_danger_context(game_state)
	if not danger_ctx.is_empty():
		sections.append({"text": danger_ctx, "priority": Priority.CRITICAL})

	# P1.10.2: Cross-run memory (past run summaries)
	var callbacks := _get_cross_run_callbacks()
	if not callbacks.is_empty():
		sections.append({"text": callbacks, "priority": Priority.LOW})

	sections.sort_custom(func(a, b): return int(a.priority) > int(b.priority))

	# Resolve budget for this brain role
	var budget: int = CONTEXT_BUDGET
	if brain_role != "" and brain_role in BRAIN_BUDGETS:
		budget = int(BRAIN_BUDGETS[brain_role])

	var result := ""
	var tokens_used := 0
	for section in sections:
		var section_tokens := estimate_tokens(section.text)
		if tokens_used + section_tokens <= budget:
			result += section.text + "\n"
			tokens_used += section_tokens
		else:
			var remaining := maxi(budget - tokens_used, 0)
			if remaining > 10:
				result += trim_to_budget(section.text, remaining) + "\n"
			break

	return result.strip_edges()


func _to_string_list(value) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "":
				out.append(text)
	return out


func _get_scene_contract_context() -> String:
	var ctx := get_scene_context()
	if ctx.is_empty():
		return ""
	var parts: Array[String] = []
	var scene_id := str(ctx.get("scene_id", ""))
	if scene_id != "":
		parts.append("Scene=%s" % scene_id)
	var phase := str(ctx.get("phase", ""))
	if phase != "":
		parts.append("Phase=%s" % phase)
	var intent := str(ctx.get("intent", ""))
	if intent != "":
		parts.append("Intent=%s" % intent)
	var tone := str(ctx.get("tone_target", ""))
	if tone != "":
		parts.append("Tone=%s" % tone)
	var allowed := _to_string_list(ctx.get("allowed_topics", []))
	if not allowed.is_empty():
		parts.append("Allowed=" + ", ".join(allowed.slice(0, mini(allowed.size(), 5))))
	var required := _to_string_list(ctx.get("must_reference", []))
	if not required.is_empty():
		parts.append("Must=" + ", ".join(required.slice(0, mini(required.size(), 5))))
	var forbidden := _to_string_list(ctx.get("forbidden_topics", []))
	if not forbidden.is_empty():
		parts.append("Forbidden=" + ", ".join(forbidden.slice(0, mini(forbidden.size(), 5))))
	if parts.is_empty():
		return ""
	return "SceneContract: " + " | ".join(parts)


func _get_crisis_context(game_state: Dictionary) -> String:
	var run: Dictionary = game_state.get("run", {})
	var factions: Dictionary = game_state.get("meta", {}).get("faction_rep", {})
	var oghams: Array = run.get("oghams_decouverts", [])
	var crises: Array[String] = []
	for faction in factions:
		var val: float = float(factions[faction])
		if val <= 10.0:
			crises.append("%s=HOSTILE" % faction)
		elif val >= 90.0:
			crises.append("%s=DOMINANT" % faction)
	if oghams.size() >= 5:
		crises.append("Oghams=%d (avance)" % oghams.size())
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
			var stage_name: String = str(arc.get("stage_name", ""))
			var cards_count: int = int(arc.get("cards_in_arc", 0))
			if stage_name != "":
				parts.append("%s (%s, %d cartes)" % [arc_id, stage_name, cards_count])
			else:
				# Fallback: use stage number
				var stage: int = int(arc.get("stage", 1))
				parts.append("%s (etape %d)" % [arc_id, stage])
	if parts.is_empty():
		return ""
	# Include run-level phase if available
	var run_phase_name: String = str(world_state.get("run_phase_name", ""))
	var prefix := ""
	if run_phase_name != "":
		prefix = "Phase: %s | " % run_phase_name
	return prefix + "Arcs: " + ", ".join(parts)


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


func _get_faction_context(game_state: Dictionary) -> String:
	var factions: Dictionary = game_state.get("meta", {}).get("faction_rep", {})
	if factions.is_empty():
		return ""
	var best_name := ""
	var best_val := 0.0
	for f_name in factions:
		var val: float = float(factions[f_name])
		if val > best_val:
			best_val = val
			best_name = str(f_name)
	if best_val >= 60:
		return "Faction dominante: %s (alliance forte)" % best_name
	elif best_val >= 30:
		return "Faction dominante: %s" % best_name
	return ""


func _get_player_profile_context() -> String:
	## P1.10.1: Inject player profile summary from world_state (synced from MOS).
	var profile_summary: String = str(world_state.get("player_profile_summary", ""))
	if profile_summary.is_empty():
		return ""
	return profile_summary


func _get_archetype_context() -> String:
	## B.3: Inject archetype label + dominant traits into RAG context (~40 tokens).
	## Helps narrator align tone and challenges with the player's archetype.
	var arch_id: String = str(world_state.get("archetype_id", ""))
	var arch_title: String = str(world_state.get("archetype_title", ""))
	if arch_id.is_empty():
		return ""
	if arch_title.is_empty():
		arch_title = arch_id.capitalize()
	return "Archetype: %s — guide les enjeux vers le style %s" % [arch_title, arch_id]


func _get_aspects_state_context(game_state: Dictionary) -> String:
	## B.4: Inject faction reputation states into RAG.
	## Only factions with extreme reputation (low/high) are mentioned — keeps tokens minimal.
	## Priority HIGH so LLM colours narrative around the player's current alliances.
	var factions: Dictionary = game_state.get("meta", {}).get("faction_rep", {})
	if factions.is_empty():
		return ""

	var lines: Array = []
	for faction in factions:
		var val: float = float(factions[faction])
		if val <= 20.0:
			lines.append("%s: hostile (%.0f)" % [faction, val])
		elif val >= 80.0:
			lines.append("%s: allie (%.0f)" % [faction, val])

	if lines.is_empty():
		return ""
	return "FACTIONS: " + " | ".join(lines)


func _get_danger_context(game_state: Dictionary) -> String:
	## P1.10.1: Inject danger level based on life essence.
	var run: Dictionary = game_state.get("run", {})
	var life: int = int(run.get("life_essence", 100))
	if life <= 15:
		return "DANGER CRITIQUE: Vie=%d — mort imminente, proteger le voyageur" % life
	elif life <= 25:
		return "DANGER: Vie=%d — favoriser options de soin" % life
	elif life <= 50:
		return "Vie basse: %d/100" % life
	return ""


var _biome_cache_key: String = ""
var _biome_cache_text: String = ""

func _get_biome_context(game_state: Dictionary) -> String:
	var run: Dictionary = game_state.get("run", {})
	var biome_key: String = str(run.get("current_biome", ""))
	if biome_key.is_empty():
		return ""
	# Cache: avoid re-instantiating MerlinBiomeSystem on every call
	if biome_key == _biome_cache_key and not _biome_cache_text.is_empty():
		return _biome_cache_text
	var BiomeSystemClass: GDScript = load("res://scripts/merlin/merlin_biome_system.gd")
	var biome_sys = BiomeSystemClass.new()
	_biome_cache_text = biome_sys.get_biome_context_for_llm(biome_key)
	_biome_cache_key = biome_key
	return _biome_cache_text


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
	var hidden: Dictionary = run.get("hidden", {})
	var tension: int = int(hidden.get("tension", 0))
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


func _get_event_category_context(game_state: Dictionary) -> String:
	## Phase 44: Build context from event category + tag glossary.
	if not _tag_glossary_loaded:
		return ""

	var run: Dictionary = game_state.get("run", {})
	var biome: String = str(run.get("current_biome", ""))
	var event_category: String = str(world_state.get("event_category", ""))
	var parts: Array[String] = []

	# Biome-specific tags (if available)
	if not biome.is_empty() and _biome_tags.has(biome):
		var b_tags: Array = _biome_tags[biome]
		if not b_tags.is_empty():
			var tag_strs: Array[String] = []
			for t in b_tags.slice(0, mini(b_tags.size(), 5)):
				tag_strs.append(str(t))
			parts.append("Themes biome: " + ", ".join(tag_strs))

	# Event category guidance
	if not event_category.is_empty():
		parts.append("Categorie: " + event_category)

	if parts.is_empty():
		return ""
	return " | ".join(parts)


func get_random_duality() -> Dictionary:
	## Phase 44: Return a random theme duality pair for dilemma generation.
	## Returns { a: String, b: String } or empty.
	if _theme_dualities.is_empty():
		return {}
	var idx: int = randi() % _theme_dualities.size()
	var duality = _theme_dualities[idx]
	if duality is Dictionary:
		return duality
	return {}


func get_tags_for_biome(biome: String) -> Array:
	## Phase 44: Get tags associated with a specific biome.
	return _biome_tags.get(biome, [])


func get_tag_info(tag_name: String) -> Dictionary:
	## Phase 44: Get info for a specific tag from glossary.
	return _tag_glossary.get(tag_name, {})


func _get_cross_run_callbacks() -> String:
	if cross_run_memory.is_empty():
		return ""
	# P1.10.2: Include last 2 runs for richer cross-run context
	var summaries: Array[String] = []
	var start_idx: int = maxi(0, cross_run_memory.size() - 2)
	for i in range(start_idx, cross_run_memory.size()):
		var run_mem: Dictionary = cross_run_memory[i]
		var ending: String = str(run_mem.get("ending", ""))
		var cards: int = int(run_mem.get("cards_played", 0))
		var style: String = str(run_mem.get("player_style", ""))
		var parts: Array[String] = []
		if not ending.is_empty():
			parts.append(ending)
		if cards > 0:
			parts.append("%d cartes" % cards)
		if not style.is_empty():
			parts.append(style)
		if not parts.is_empty():
			summaries.append("Run %d: %s" % [i + 1, ", ".join(parts)])
	if summaries.is_empty():
		return ""
	return "Memoire: " + " | ".join(summaries)


## Reset journal for a new run (called at run start).
func reset_for_new_run() -> void:
	journal.clear()
	save_journal()


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


func log_run_generic(event_name: String, data: Dictionary, card_num: int, day: int) -> void:
	_add_journal_entry(event_name, card_num, day, data)


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
	## P1.10.2: Enhanced with life_final and timestamp for cross-run context.
	cross_run_memory.append({
		"run_id": cross_run_memory.size() + 1,
		"ending": ending,
		"cards_played": journal.size(),
		"dominant_faction": _find_dominant_faction(final_state),
		"notable_events": _extract_notable_events(),
		"player_style": _classify_player_style(),
		"score": int(final_state.get("score", 0)),
		"life_final": int(final_state.get("run", {}).get("life_essence", 0)),
		"timestamp": Time.get_unix_time_from_system(),
	})
	if cross_run_memory.size() > MAX_CROSS_RUN_SUMMARIES:
		cross_run_memory = cross_run_memory.slice(-MAX_CROSS_RUN_SUMMARIES)
	_save_cross_run_memory()
	journal.clear()
	save_journal()


func _find_dominant_faction(final_state: Dictionary) -> String:
	var factions: Dictionary = final_state.get("meta", {}).get("faction_rep", {})
	var max_val := 0.0
	var dominant := "neutre"
	for faction in factions:
		var val: float = absf(float(factions[faction]) - 50.0)
		if val > max_val:
			max_val = val
			dominant = str(faction)
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


func set_scene_context(scene_context: Dictionary) -> void:
	_scene_context = scene_context.duplicate(true)
	if _scene_context.is_empty():
		world_state.erase("scene_context")
	else:
		world_state["scene_context"] = _scene_context


func clear_scene_context() -> void:
	_scene_context.clear()
	world_state.erase("scene_context")


func get_scene_context() -> Dictionary:
	if not _scene_context.is_empty():
		return _scene_context.duplicate(true)
	if world_state.has("scene_context") and world_state["scene_context"] is Dictionary:
		return world_state["scene_context"].duplicate(true)
	return {}


func sync_from_registries(registries: Dictionary) -> void:
	for key in registries:
		world_state[key] = registries[key]
	if world_state.has("scene_context") and world_state["scene_context"] is Dictionary:
		_scene_context = world_state["scene_context"].duplicate(true)
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


func get_past_lives_for_prompt() -> String:
	## P3.20.2: Format past run summaries for Merlin to reference past lives.
	## Returns a prompt-friendly string describing previous runs.
	if cross_run_memory.is_empty():
		return ""
	var lines: Array[String] = []
	var start_idx: int = maxi(0, cross_run_memory.size() - 3)
	for i in range(start_idx, cross_run_memory.size()):
		var run: Dictionary = cross_run_memory[i]
		var ending: String = str(run.get("ending", "inconnu"))
		var cards: int = int(run.get("cards_played", 0))
		var dom: String = str(run.get("dominant_faction", ""))
		var style: String = str(run.get("player_style", ""))
		var life: int = int(run.get("life_final", 0))
		var events: String = str(run.get("notable_events", ""))
		var parts: Array[String] = ["Vie %d" % (i + 1)]
		if not ending.is_empty():
			parts.append("fin: %s" % ending)
		if cards > 0:
			parts.append("%d cartes" % cards)
		if not dom.is_empty():
			parts.append("dominant: %s" % dom)
		if not style.is_empty():
			parts.append("style: %s" % style)
		if life > 0:
			parts.append("vie restante: %d" % life)
		if not events.is_empty() and events.length() < 80:
			parts.append(events)
		lines.append(", ".join(parts))
	if lines.is_empty():
		return ""
	return "Vies passees du voyageur: " + " | ".join(lines)


func get_run_summaries_for_journal() -> Array[Dictionary]:
	## P3.20.3: Return all run summaries for the visual journal UI.
	return cross_run_memory.duplicate()


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
				if world_state.has("scene_context") and world_state["scene_context"] is Dictionary:
					_scene_context = world_state["scene_context"].duplicate(true)


func _load_actions() -> void:
	var path := "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary and data.has("categories"):
				actions_by_category = data.categories


func _load_tag_glossary() -> void:
	## Phase 44: Load tag glossary for narrative context enrichment.
	var path := "res://data/ai/config/tag_glossary.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return

	# Load tags
	var tags_dict: Dictionary = data.get("tags", {})
	_tag_glossary = tags_dict

	# Load theme dualities for dilemma generation
	var dualities_raw = data.get("theme_dualities", {})
	if dualities_raw is Dictionary:
		_theme_dualities = dualities_raw.get("pairs", [])
	elif dualities_raw is Array:
		_theme_dualities = dualities_raw

	# Load biome-specific tags
	var biome_tags: Dictionary = data.get("biome_tags", {})
	_biome_tags = biome_tags

	_tag_glossary_loaded = not _tag_glossary.is_empty()
	if _tag_glossary_loaded:
		print("[RAGManager] Tag glossary loaded: %d tags, %d dualities, %d biomes" % [
			_tag_glossary.size(), _theme_dualities.size(), _biome_tags.size()
		])


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY COMPATIBILITY
# ═══════════════════════════════════════════════════════════════════════════════

func get_relevant_context(query: String, _category: String) -> Dictionary:
	var keywords: Array[String] = []
	for word in query.split(" "):
		keywords.append(word)
	var relevant: Array = search_journal(keywords, 3)
	var relevant_entries: Array = []
	for item in relevant:
		relevant_entries.append(item.get("entry", {}))
	return {
		"recent_history": journal.slice(-5) if journal.size() >= 5 else journal.duplicate(),
		"relevant_history": relevant_entries,
		"world_state_subset": world_state,
		"available_actions": [],
	}


func add_to_history(input_text: String, response: String) -> void:
	log_run_event("legacy_exchange", {"input": input_text, "response": response.substr(0, 100)}, journal.size(), 0)
