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
#   gauges_before, gauges_after,
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
	"protects_bestiole": {
		"filter_tags": ["bestiole_risk"],
		"expected_option": 0,  # Left = protect
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
# GAUGE PATTERN TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

var gauge_patterns := {
	"protects_vigueur": {"count": 0, "opportunities": 0},
	"protects_esprit": {"count": 0, "opportunities": 0},
	"protects_faveur": {"count": 0, "opportunities": 0},
	"protects_ressources": {"count": 0, "opportunities": 0},
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
	"center_ratio": 0.0,  # For TRIADE system
	"right_ratio": 0.5,
	"promise_acceptance_rate": 0.0,
	"average_gauge_at_death": {},
	"most_common_death_gauge": "",
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
		"average_gauge_at_death": {},
		"most_common_death_gauge": "",
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
		"gauges_before": context.get("gauges", {}).duplicate(),
		"gauges_after": {},  # Filled by update_last_entry_gauges
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

	# Track gauge protection
	_track_gauge_protection(entry, context)

	# Detect patterns
	_detect_patterns()


func update_last_entry_gauges(gauges_after: Dictionary) -> void:
	## Met a jour les jauges finales du dernier choix.
	if current_run.is_empty():
		return
	current_run[-1].gauges_after = gauges_after.duplicate()


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
# GAUGE PROTECTION TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func _track_gauge_protection(entry: Dictionary, context: Dictionary) -> void:
	var gauges: Dictionary = context.get("gauges", {})
	var effects: Array = entry.effects

	for gauge_name in gauges:
		var value: int = int(gauges[gauge_name])
		var pattern_key: String = "protects_" + str(gauge_name).to_lower()

		if not gauge_patterns.has(pattern_key):
			continue

		# Check if this was a protection opportunity
		if value < 25 or value > 75:
			gauge_patterns[pattern_key].opportunities += 1

			# Check if player protected it
			for effect in effects:
				if effect.get("target", "") == gauge_name:
					var effect_value: int = int(effect.get("value", 0))
					# Protecting = raising low gauge or lowering high gauge
					if (value < 25 and effect_value > 0) or (value > 75 and effect_value < 0):
						gauge_patterns[pattern_key].count += 1
						break

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

	# Detect gauge protection patterns
	for pattern_key in gauge_patterns:
		var data: Dictionary = gauge_patterns[pattern_key]
		if data.opportunities >= PATTERN_MIN_OCCURRENCES:
			var rate: float = float(data.count) / float(data.opportunities)
			if rate >= PATTERN_DETECTION_THRESHOLD:
				patterns_detected[pattern_key] = {
					"confidence": rate,
					"occurrences": data.opportunities,
					"last_updated": int(Time.get_unix_time_from_system()),
				}


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
	# Track death gauges
	var gauges: Dictionary = ending_data.get("final_gauges", {})
	for gauge_name in gauges:
		var value: int = int(gauges[gauge_name])
		# Gauge that caused death (0 or 100)
		if value <= 0 or value >= 100:
			var death_counts: Dictionary = historical_summary.get("death_gauge_counts", {})
			death_counts[gauge_name] = death_counts.get(gauge_name, 0) + 1
			historical_summary["death_gauge_counts"] = death_counts

			# Update most common
			var max_deaths := 0
			var most_common := ""
			for g in death_counts:
				if death_counts[g] > max_deaths:
					max_deaths = death_counts[g]
					most_common = g
			historical_summary.most_common_death_gauge = most_common

	# Track average gauges at death
	if not ending_data.get("victory", false):
		for gauge_name in gauges:
			var current_avg: float = float(historical_summary.average_gauge_at_death.get(gauge_name, 50))
			var new_value: float = float(gauges[gauge_name])
			var count: int = historical_summary.get("death_count", 0) + 1
			historical_summary.average_gauge_at_death[gauge_name] = (
				(current_avg * (count - 1) + new_value) / count
			)
		historical_summary["death_count"] = historical_summary.get("death_count", 0) + 1

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
		"most_common_death_gauge": historical_summary.most_common_death_gauge,
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
		"protects_bestiole":
			return "Le joueur %s protege Bestiole" % conf_text
		"takes_risks":
			return "Le joueur %s prend des risques" % conf_text
		"avoids_conflict":
			return "Le joueur %s evite les conflits" % conf_text
		"protects_vigueur":
			return "Le joueur %s protege sa Vigueur" % conf_text
		"protects_esprit":
			return "Le joueur %s protege son Esprit" % conf_text
		"protects_faveur":
			return "Le joueur %s protege sa Faveur" % conf_text
		"protects_ressources":
			return "Le joueur %s protege ses Ressources" % conf_text

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
		"gauge_patterns": gauge_patterns,
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
	if data.has("gauge_patterns"):
		for key in data.gauge_patterns:
			if gauge_patterns.has(key):
				gauge_patterns[key] = data.gauge_patterns[key]
	if data.has("historical_summary"):
		for key in data.historical_summary:
			if historical_summary.has(key):
				historical_summary[key] = data.historical_summary[key]
