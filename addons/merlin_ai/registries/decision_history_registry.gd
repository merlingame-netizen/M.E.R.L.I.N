## ═══════════════════════════════════════════════════════════════════════════════
## Decision History Registry — Memoire des Choix
## ═══════════════════════════════════════════════════════════════════════════════
## Track tous les choix pour detecter les patterns et permettre les callbacks.
## Persistance: Per-run + compressed cross-run summary
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name DecisionHistoryRegistry

signal pattern_detected(pattern: String, confidence: float)
signal callback_opportunity(npc_id: String, card_id: String)

const VERSION := "1.0.0"
const SAVE_PATH := "user://merlin_decision_history.json"

# ═══════════════════════════════════════════════════════════════════════════════
# CURRENT RUN HISTORY
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_CURRENT_RUN_ENTRIES := 200

var current_run: Array[Dictionary] = []
# Each entry: {
#   card_id, card_type, option, effects,
#   timestamp, day, biome, tags,
#   decision_time_ms, npc_id
# }

# ═══════════════════════════════════════════════════════════════════════════════
# PATTERN DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

const PATTERN_DETECTION_THRESHOLD := 0.7
const PATTERN_MIN_OCCURRENCES := 5

var patterns_detected := {}
# Structure: {
#   "pattern_name": {"confidence": float, "occurrences": int, "last_updated": int}
# }

# Pattern types
const PATTERNS := {
	# Behavioral patterns
	"always_helps_strangers": {
		"filter_tags": ["stranger", "help_request"],
		"expected_option": 1,  # Right = help
	},
	"avoids_promises": {
		"filter_tags": ["promise"],
		"expected_option": 0,  # Left = decline
	},
	"seeks_mystery": {
		"filter_tags": ["mystery", "investigate", "lore"],
		"expected_option": 1,  # Right = investigate
	},
	"favors_factions": {
		"filter_tags": ["faction_choice"],
		"expected_option": 0,  # Left = favor dominant faction
	},
	"takes_risks": {
		"filter_tags": ["risky", "dangerous", "gamble"],
		"expected_option": 1,  # Right = risk
	},
	"avoids_conflict": {
		"filter_tags": ["conflict", "fight", "aggressive"],
		"expected_option": 0,  # Left = avoid
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# NPC KARMA TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

var npc_karma := {}  # {npc_id: int (-100 to 100)}
var npc_last_seen := {}  # {npc_id: card_number}

# ═══════════════════════════════════════════════════════════════════════════════
# HISTORICAL SUMMARY (Cross-run)
# ═══════════════════════════════════════════════════════════════════════════════

var historical_summary := {
	"total_choices": 0,
	"left_ratio": 0.5,
	"center_ratio": 0.0,  # Center choice ratio
	"right_ratio": 0.5,
	"promise_acceptance_rate": 0.0,
	"patterns_over_time": {},  # Track pattern evolution
}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	load_from_disk()


func reset_run() -> void:
	## Reset pour une nouvelle run.
	current_run.clear()
	npc_last_seen.clear()


func reset_all() -> void:
	## Reset complet (pour debug).
	current_run.clear()
	patterns_detected.clear()
	npc_karma.clear()
	npc_last_seen.clear()
	historical_summary = {
		"total_choices": 0,
		"left_ratio": 0.5,
		"center_ratio": 0.0,
		"right_ratio": 0.5,
		"promise_acceptance_rate": 0.0,
		"patterns_over_time": {},
	}

# ═══════════════════════════════════════════════════════════════════════════════
# RECORD CHOICE
# ═══════════════════════════════════════════════════════════════════════════════

func record_choice(card: Dictionary, option: int, context: Dictionary) -> void:
	## Enregistre un choix.
	var entry := {
		"card_id": card.get("id", "unknown_%d" % Time.get_ticks_msec()),
		"card_type": card.get("type", "narrative"),
		"option": option,
		"effects": _get_option_effects(card, option),
		"timestamp": int(Time.get_unix_time_from_system()),
		"day": context.get("day", 1),
		"biome": context.get("biome", ""),
		"tags": card.get("tags", []),
		"decision_time_ms": context.get("decision_time_ms", 3000),
		"npc_id": card.get("npc_id", ""),
	}

	current_run.append(entry)

	# Limit size
	if current_run.size() > MAX_CURRENT_RUN_ENTRIES:
		current_run.pop_front()

	# Update historical ratios
	historical_summary.total_choices += 1
	_update_choice_ratios(option)

	# Track NPC interactions
	if entry.npc_id != "":
		_track_npc_interaction(entry)

	# Detect patterns
	_detect_patterns()


func _update_choice_ratios(option: int) -> void:
	var total := float(historical_summary.total_choices)
	var left_count: float = float(historical_summary.left_ratio) * (total - 1)
	var center_count: float = float(historical_summary.center_ratio) * (total - 1)
	var right_count: float = float(historical_summary.right_ratio) * (total - 1)

	match option:
		0: left_count += 1
		1: center_count += 1
		2: right_count += 1

	historical_summary.left_ratio = left_count / total
	historical_summary.center_ratio = center_count / total
	historical_summary.right_ratio = right_count / total


func _get_option_effects(card: Dictionary, option: int) -> Array:
	var options: Array = card.get("options", [])
	if option >= 0 and option < options.size():
		return options[option].get("effects", [])
	return []

# ═══════════════════════════════════════════════════════════════════════════════
# NPC TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func _track_npc_interaction(entry: Dictionary) -> void:
	var npc_id: String = entry.npc_id
	var option: int = entry.option
	var tags: Array = entry.tags

	# Initialize if needed
	if not npc_karma.has(npc_id):
		npc_karma[npc_id] = 0

	# Update karma based on choice
	var karma_change := 0
	if "help" in tags or "gift" in tags or "trust" in tags:
		karma_change = 10 if option == 1 else -5
	elif "refuse" in tags or "betray" in tags:
		karma_change = -10 if option == 1 else 5
	elif "attack" in tags or "steal" in tags:
		karma_change = -15 if option == 1 else 0

	npc_karma[npc_id] = clampi(npc_karma[npc_id] + karma_change, -100, 100)
	npc_last_seen[npc_id] = current_run.size()

	# Check for callback opportunity
	_check_npc_callback(npc_id)


func _check_npc_callback(npc_id: String) -> void:
	## Verifie si un NPC peut revenir dans la narration.
	var last_seen: int = npc_last_seen.get(npc_id, 0)
	var current_card := current_run.size()

	# NPC can return after 10+ cards
	if current_card - last_seen >= 10:
		var karma: int = npc_karma.get(npc_id, 0)
		# Strong karma = callback opportunity
		if abs(karma) >= 30:
			callback_opportunity.emit(npc_id, current_run[-1].card_id)


func get_npc_karma(npc_id: String) -> int:
	return npc_karma.get(npc_id, 0)


func get_npc_relationship_summary(npc_id: String) -> String:
	var karma: int = npc_karma.get(npc_id, 0)
	if karma >= 50:
		return "allie_fidele"
	elif karma >= 20:
		return "ami"
	elif karma >= -20:
		return "neutre"
	elif karma >= -50:
		return "mefiant"
	else:
		return "ennemi"

# ═══════════════════════════════════════════════════════════════════════════════
# PATTERN DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _detect_patterns() -> void:
	## Detecte les patterns comportementaux.
	for pattern_name in PATTERNS:
		var pattern_def: Dictionary = PATTERNS[pattern_name]
		var filter_tags: Array = pattern_def.filter_tags
		var expected_option: int = pattern_def.expected_option

		# Filter relevant entries
		var relevant := current_run.filter(func(e):
			for tag in filter_tags:
				if tag in e.tags:
					return true
			return false
		)

		if relevant.size() < PATTERN_MIN_OCCURRENCES:
			continue

		# Calculate consistency
		var matching := relevant.filter(func(e): return e.option == expected_option)
		var consistency: float = float(matching.size()) / float(relevant.size())

		if consistency >= PATTERN_DETECTION_THRESHOLD:
			var was_new := not patterns_detected.has(pattern_name)
			patterns_detected[pattern_name] = {
				"confidence": consistency,
				"occurrences": relevant.size(),
				"last_updated": int(Time.get_unix_time_from_system()),
			}

			if was_new:
				pattern_detected.emit(pattern_name, consistency)


func get_pattern(pattern_name: String) -> Dictionary:
	return patterns_detected.get(pattern_name, {})


func has_pattern(pattern_name: String, min_confidence: float = PATTERN_DETECTION_THRESHOLD) -> bool:
	var pattern := get_pattern(pattern_name)
	return pattern.get("confidence", 0.0) >= min_confidence

# ═══════════════════════════════════════════════════════════════════════════════
# RUN END
# ═══════════════════════════════════════════════════════════════════════════════

func on_run_end(ending_data: Dictionary) -> void:
	## Appele a la fin d'une run.

	# Track promise acceptance rate
	var promises_seen := 0
	var promises_accepted := 0
	for entry in current_run:
		if "promise" in entry.tags:
			promises_seen += 1
			if entry.option == 1:  # Right = accept
				promises_accepted += 1

	if promises_seen > 0:
		var old_rate: float = historical_summary.promise_acceptance_rate
		var old_count: int = historical_summary.get("promise_count", 0)
		var new_rate: float = float(promises_accepted) / float(promises_seen)
		var new_count: int = old_count + promises_seen

		historical_summary.promise_acceptance_rate = (
			(old_rate * old_count + new_rate * promises_seen) / new_count
		)
		historical_summary["promise_count"] = new_count

	# Save patterns over time
	for pattern_name in patterns_detected:
		if not historical_summary.patterns_over_time.has(pattern_name):
			historical_summary.patterns_over_time[pattern_name] = []
		historical_summary.patterns_over_time[pattern_name].append(
			patterns_detected[pattern_name].confidence
		)

	save_to_disk()
	reset_run()

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT FOR LLM
# ═══════════════════════════════════════════════════════════════════════════════

func get_context_for_llm() -> Dictionary:
	return {
		"cards_this_run": current_run.size(),
		"patterns": _get_patterns_summary(),
		"npc_karma": npc_karma.duplicate(),
		"npcs_met_count": npc_karma.size(),
		"recent_choices": _get_recent_choices_summary(5),
		"promise_acceptance_rate": historical_summary.promise_acceptance_rate,
	}


func _get_patterns_summary() -> Dictionary:
	var summary := {}
	for pattern_name in patterns_detected:
		summary[pattern_name] = patterns_detected[pattern_name].confidence
	return summary


func _get_recent_choices_summary(count: int) -> Array:
	var recent := []
	var start := maxi(0, current_run.size() - count)
	for i in range(start, current_run.size()):
		var entry: Dictionary = current_run[i]
		recent.append({
			"type": entry.card_type,
			"option": entry.option,
			"tags": entry.tags,
		})
	return recent


func get_pattern_for_llm() -> String:
	## Genere une description textuelle des patterns pour le LLM.
	var lines := []

	for pattern_name in patterns_detected:
		var data: Dictionary = patterns_detected[pattern_name]
		if data.confidence >= 0.7:
			lines.append(_pattern_to_french(pattern_name, data))

	return "\n".join(lines)


func _pattern_to_french(pattern_name: String, data: Dictionary) -> String:
	var confidence: float = data.confidence
	var conf_text := "toujours" if confidence > 0.9 else "souvent"

	match pattern_name:
		"always_helps_strangers":
			return "Le joueur %s aide les etrangers" % conf_text
		"avoids_promises":
			return "Le joueur %s refuse les promesses" % conf_text
		"seeks_mystery":
			return "Le joueur %s explore les mysteres" % conf_text
		"favors_factions":
			return "Le joueur %s favorise les factions" % conf_text
		"takes_risks":
			return "Le joueur %s prend des risques" % conf_text
		"avoids_conflict":
			return "Le joueur %s evite les conflits" % conf_text

	return "Pattern: %s (%.0f%%)" % [pattern_name, confidence * 100]

# ═══════════════════════════════════════════════════════════════════════════════
# CALLBACK GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func get_callback_npcs() -> Array:
	## Retourne les NPCs qui pourraient revenir.
	var callbacks := []

	for npc_id in npc_karma:
		var karma: int = npc_karma[npc_id]
		var last_seen: int = npc_last_seen.get(npc_id, 0)
		var cards_since := current_run.size() - last_seen

		if cards_since >= 10 and abs(karma) >= 20:
			callbacks.append({
				"npc_id": npc_id,
				"karma": karma,
				"relationship": get_npc_relationship_summary(npc_id),
				"cards_since": cards_since,
			})

	return callbacks


func get_previous_choice_on_tag(tag: String) -> Dictionary:
	## Retourne le dernier choix fait sur un tag specifique.
	for i in range(current_run.size() - 1, -1, -1):
		var entry: Dictionary = current_run[i]
		if tag in entry.tags:
			return entry
	return {}

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func save_to_disk() -> void:
	var data := {
		"version": VERSION,
		"patterns_detected": patterns_detected,
		"npc_karma": npc_karma,
		"historical_summary": historical_summary,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.has("patterns_detected"):
		patterns_detected = data.patterns_detected
	if data.has("npc_karma"):
		npc_karma = data.npc_karma
	if data.has("historical_summary"):
		for key in data.historical_summary:
			if historical_summary.has(key):
				historical_summary[key] = data.historical_summary[key]
