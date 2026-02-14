## ═══════════════════════════════════════════════════════════════════════════════
## Session Registry — Contexte Temps Reel
## ═══════════════════════════════════════════════════════════════════════════════
## Track le comportement en temps reel du joueur pendant la session.
## Detecte fatigue, frustration, engagement.
## Persistance: Cross-session (historique)
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name SessionRegistry

signal wellness_alert(alert_type: String, data: Dictionary)
signal engagement_changed(level: String)
signal session_ended(summary: Dictionary)

const VERSION := "1.0.0"
const SAVE_PATH := "user://merlin_session_history.json"

# ═══════════════════════════════════════════════════════════════════════════════
# CURRENT SESSION
# ═══════════════════════════════════════════════════════════════════════════════

var current := {
	"start_time": 0,
	"cards_this_session": 0,
	"runs_this_session": 0,
	"deaths_this_session": 0,
	"breaks_taken": 0,
	"total_decision_time_ms": 0,
	"rushed_decisions": 0,       # < 1 seconde
	"contemplated_decisions": 0, # > 10 secondes
	"skill_uses": 0,
	"bestiole_interactions": 0,
}

# Computed metrics
var average_decision_time: float = 4.5
var decision_time_trend: float = 0.0  # Positive = slowing down

# ═══════════════════════════════════════════════════════════════════════════════
# HISTORICAL DATA
# ═══════════════════════════════════════════════════════════════════════════════

var history := {
	"total_sessions": 0,
	"total_playtime_seconds": 0,
	"average_session_minutes": 38.0,
	"preferred_play_times": [],    # ["morning", "evening", "night"]
	"days_since_last_play": 0,
	"longest_streak": 0,           # Jours consecutifs
	"current_streak": 0,
	"session_lengths": [],         # Last 20 session lengths in minutes
	"last_session_date": 0,
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENGAGEMENT TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

enum EngagementLevel { LOW, MEDIUM, HIGH, VERY_HIGH }

var engagement := {
	"current_level": EngagementLevel.MEDIUM,
	"card_reading_speed": "normal",  # "fast", "normal", "slow", "variable"
	"bestiole_care_frequency": 0.5,  # 0-1
	"skill_usage_rate": 0.3,         # 0-1
	"menu_time_ratio": 0.15,         # Temps en menu vs gameplay
	"dialogue_skip_rate": 0.0,       # 0-1
}

# ═══════════════════════════════════════════════════════════════════════════════
# WELLNESS FLAGS
# ═══════════════════════════════════════════════════════════════════════════════

var wellness := {
	"long_session_warned": false,
	"break_suggested": false,
	"frustration_detected": false,
	"fatigue_detected": false,
	"tilt_detected": false,           # Decisions de plus en plus mauvaises
	"positive_momentum": false,       # Joueur dans le flow
}

# ═══════════════════════════════════════════════════════════════════════════════
# THRESHOLDS
# ═══════════════════════════════════════════════════════════════════════════════

const RUSHED_DECISION_MS := 1000
const CONTEMPLATED_DECISION_MS := 10000
const FRUSTRATION_THRESHOLD := 3       # Quick deaths + rushed in short time
const LONG_SESSION_MINUTES := 90
const BREAK_SUGGEST_MINUTES := 60
const FATIGUE_SLOWDOWN_FACTOR := 1.5   # Decisions 50% plus lentes = fatigue
const TILT_DEATH_THRESHOLD := 3        # Morts rapides consecutives

# Decision time window for trend calculation
var _recent_decision_times: Array[int] = []
const DECISION_TIME_WINDOW := 20

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	load_from_disk()
	start_new_session()


func start_new_session() -> void:
	## Demarre une nouvelle session.
	# Calculate days since last play
	if history.last_session_date > 0:
		var now := int(Time.get_unix_time_from_system())
		history.days_since_last_play = int((now - history.last_session_date) / 86400.0)

		# Update streak
		if history.days_since_last_play <= 1:
			history.current_streak += 1
			history.longest_streak = maxi(history.longest_streak, history.current_streak)
		else:
			history.current_streak = 1

	# Reset current session
	current = {
		"start_time": int(Time.get_unix_time_from_system()),
		"cards_this_session": 0,
		"runs_this_session": 0,
		"deaths_this_session": 0,
		"breaks_taken": 0,
		"total_decision_time_ms": 0,
		"rushed_decisions": 0,
		"contemplated_decisions": 0,
		"skill_uses": 0,
		"bestiole_interactions": 0,
	}

	# Reset wellness flags
	wellness = {
		"long_session_warned": false,
		"break_suggested": false,
		"frustration_detected": false,
		"fatigue_detected": false,
		"tilt_detected": false,
		"positive_momentum": false,
	}

	_recent_decision_times.clear()
	average_decision_time = 4.5
	decision_time_trend = 0.0

	# Detect preferred play time
	var hour: int = int(Time.get_datetime_dict_from_system().hour)
	var time_of_day := _get_time_of_day(hour)
	if time_of_day not in history.preferred_play_times:
		# Count occurrences
		history.preferred_play_times.append(time_of_day)
		if history.preferred_play_times.size() > 50:
			history.preferred_play_times.pop_front()


func _get_time_of_day(hour: int) -> String:
	if hour >= 5 and hour < 12:
		return "morning"
	elif hour >= 12 and hour < 18:
		return "afternoon"
	elif hour >= 18 and hour < 22:
		return "evening"
	else:
		return "night"

# ═══════════════════════════════════════════════════════════════════════════════
# DECISION TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func record_decision(time_ms: int) -> void:
	## Enregistre une decision et son temps.
	current.cards_this_session += 1
	current.total_decision_time_ms += time_ms

	# Track decision speed
	if time_ms < RUSHED_DECISION_MS:
		current.rushed_decisions += 1
	elif time_ms > CONTEMPLATED_DECISION_MS:
		current.contemplated_decisions += 1

	# Update recent times for trend
	_recent_decision_times.append(time_ms)
	if _recent_decision_times.size() > DECISION_TIME_WINDOW:
		_recent_decision_times.pop_front()

	# Calculate average
	var n: int = int(current.cards_this_session)
	average_decision_time = current.total_decision_time_ms / float(n) / 1000.0

	# Calculate trend (comparing first half to second half of recent)
	_calculate_decision_trend()

	# Update engagement level
	_update_engagement()

	# Check wellness
	_check_wellness()


func _calculate_decision_trend() -> void:
	if _recent_decision_times.size() < 10:
		decision_time_trend = 0.0
		return

	var half := int(_recent_decision_times.size() / 2.0)
	var first_half_avg := 0.0
	var second_half_avg := 0.0

	for i in range(half):
		first_half_avg += _recent_decision_times[i]
	first_half_avg /= half

	for i in range(half, _recent_decision_times.size()):
		second_half_avg += _recent_decision_times[i]
	second_half_avg /= (_recent_decision_times.size() - half)

	# Trend: positive = slowing down, negative = speeding up
	if first_half_avg > 0:
		decision_time_trend = (second_half_avg - first_half_avg) / first_half_avg


func _update_engagement() -> void:
	var old_level: int = int(engagement.current_level)

	# Calculate engagement score
	var score := 0.5

	# Rushed decisions = low engagement
	var rush_ratio: float = float(current.rushed_decisions) / maxf(1.0, float(current.cards_this_session))
	score -= rush_ratio * 0.3

	# Contemplated decisions = high engagement
	var contemplate_ratio: float = float(current.contemplated_decisions) / maxf(1.0, float(current.cards_this_session))
	score += contemplate_ratio * 0.2

	# Skill usage = engagement
	score += engagement.skill_usage_rate * 0.2

	# Bestiole care = engagement
	score += engagement.bestiole_care_frequency * 0.1

	# Dialogue skipping = low engagement
	score -= engagement.dialogue_skip_rate * 0.3

	score = clampf(score, 0.0, 1.0)

	# Set level
	if score < 0.3:
		engagement.current_level = EngagementLevel.LOW
	elif score < 0.5:
		engagement.current_level = EngagementLevel.MEDIUM
	elif score < 0.7:
		engagement.current_level = EngagementLevel.HIGH
	else:
		engagement.current_level = EngagementLevel.VERY_HIGH

	# Determine reading speed
	if average_decision_time < 2.0:
		engagement.card_reading_speed = "fast"
	elif average_decision_time > 8.0:
		engagement.card_reading_speed = "slow"
	elif absf(decision_time_trend) > 0.3:
		engagement.card_reading_speed = "variable"
	else:
		engagement.card_reading_speed = "normal"

	if old_level != engagement.current_level:
		engagement_changed.emit(_engagement_level_name(engagement.current_level))


func _engagement_level_name(level: EngagementLevel) -> String:
	match level:
		EngagementLevel.LOW: return "low"
		EngagementLevel.MEDIUM: return "medium"
		EngagementLevel.HIGH: return "high"
		EngagementLevel.VERY_HIGH: return "very_high"
	return "unknown"

# ═══════════════════════════════════════════════════════════════════════════════
# WELLNESS CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

func _check_wellness() -> void:
	var session_minutes := get_session_length_minutes()

	# Long session warning
	if session_minutes >= LONG_SESSION_MINUTES and not wellness.long_session_warned:
		wellness.long_session_warned = true
		wellness_alert.emit("long_session", {"minutes": session_minutes})

	# Break suggestion
	if session_minutes >= BREAK_SUGGEST_MINUTES and not wellness.break_suggested:
		wellness.break_suggested = true
		wellness_alert.emit("break_suggested", {"minutes": session_minutes})

	# Frustration detection
	_detect_frustration()

	# Fatigue detection
	_detect_fatigue()

	# Tilt detection
	_detect_tilt()

	# Positive momentum
	_detect_positive_momentum()


func _detect_frustration() -> void:
	if wellness.frustration_detected:
		return

	# Frustration = many deaths + rushed decisions in short time
	if current.deaths_this_session >= FRUSTRATION_THRESHOLD:
		var recent_rush_ratio: float = float(current.rushed_decisions) / maxf(1.0, float(current.cards_this_session))
		if recent_rush_ratio > 0.4:
			wellness.frustration_detected = true
			wellness_alert.emit("frustration", {
				"deaths": current.deaths_this_session,
				"rushed_ratio": recent_rush_ratio
			})


func _detect_fatigue() -> void:
	if wellness.fatigue_detected:
		return

	# Fatigue = decision times slowing down significantly
	if decision_time_trend > FATIGUE_SLOWDOWN_FACTOR - 1.0:  # 50% slower
		if current.cards_this_session > 30:  # Enough data
			wellness.fatigue_detected = true
			wellness_alert.emit("fatigue", {
				"trend": decision_time_trend,
				"average_time": average_decision_time
			})


func _detect_tilt() -> void:
	if wellness.tilt_detected:
		return

	# Tilt = multiple quick deaths in same session
	if current.deaths_this_session >= TILT_DEATH_THRESHOLD:
		var session_minutes := get_session_length_minutes()
		if session_minutes < 30:  # Many deaths in short time
			wellness.tilt_detected = true
			wellness_alert.emit("tilt", {
				"deaths": current.deaths_this_session,
				"minutes": session_minutes
			})


func _detect_positive_momentum() -> void:
	# Positive momentum = good run length without issues
	if current.cards_this_session > 50:
		if current.deaths_this_session == 0:
			if not wellness.frustration_detected and not wellness.fatigue_detected:
				if not wellness.positive_momentum:
					wellness.positive_momentum = true
					wellness_alert.emit("flow", {"cards": current.cards_this_session})

# ═══════════════════════════════════════════════════════════════════════════════
# EVENT TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func record_death() -> void:
	current.deaths_this_session += 1
	_check_wellness()


func record_run_start() -> void:
	current.runs_this_session += 1


func record_skill_use() -> void:
	current.skill_uses += 1
	engagement.skill_usage_rate = current.skill_uses / maxf(1.0, current.cards_this_session)


func record_bestiole_interaction() -> void:
	current.bestiole_interactions += 1
	engagement.bestiole_care_frequency = minf(1.0, current.bestiole_interactions / maxf(1.0, current.runs_this_session * 5))


func record_dialogue_skip() -> void:
	engagement.dialogue_skip_rate = lerpf(engagement.dialogue_skip_rate, 1.0, 0.1)


func record_break() -> void:
	current.breaks_taken += 1
	wellness.break_suggested = false  # Reset after break

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION END
# ═══════════════════════════════════════════════════════════════════════════════

func end_session() -> Dictionary:
	## Termine la session et retourne un resume.
	var session_minutes := get_session_length_minutes()

	# Update history
	history.total_sessions += 1
	history.total_playtime_seconds += int(session_minutes * 60)
	history.last_session_date = int(Time.get_unix_time_from_system())

	# Update average session length
	history.session_lengths.append(session_minutes)
	if history.session_lengths.size() > 20:
		history.session_lengths.pop_front()

	var sum := 0.0
	for length in history.session_lengths:
		sum += length
	history.average_session_minutes = sum / history.session_lengths.size()

	var summary := {
		"duration_minutes": session_minutes,
		"cards_played": current.cards_this_session,
		"runs": current.runs_this_session,
		"deaths": current.deaths_this_session,
		"average_decision_time": average_decision_time,
		"engagement_level": _engagement_level_name(engagement.current_level),
		"wellness_alerts": _get_wellness_summary(),
	}

	save_to_disk()
	session_ended.emit(summary)

	return summary


func _get_wellness_summary() -> Array:
	var alerts := []
	if wellness.frustration_detected:
		alerts.append("frustration")
	if wellness.fatigue_detected:
		alerts.append("fatigue")
	if wellness.tilt_detected:
		alerts.append("tilt")
	if wellness.long_session_warned:
		alerts.append("long_session")
	return alerts

# ═══════════════════════════════════════════════════════════════════════════════
# GETTERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_session_length_minutes() -> float:
	var now := int(Time.get_unix_time_from_system())
	return (now - current.start_time) / 60.0


func is_returning_player() -> bool:
	return history.total_sessions > 0


func get_days_since_last_play() -> int:
	return history.days_since_last_play


func get_preferred_play_time() -> String:
	if history.preferred_play_times.is_empty():
		return "unknown"

	# Count occurrences
	var counts := {}
	for time in history.preferred_play_times:
		counts[time] = counts.get(time, 0) + 1

	# Find most common
	var best := ""
	var best_count := 0
	for time in counts:
		if counts[time] > best_count:
			best_count = counts[time]
			best = time

	return best

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT FOR LLM
# ═══════════════════════════════════════════════════════════════════════════════

func get_context_for_llm() -> Dictionary:
	return {
		"cards_this_session": current.cards_this_session,
		"session_length_minutes": get_session_length_minutes(),
		"is_returning_player": is_returning_player(),
		"days_away": history.days_since_last_play,
		"is_long_session": wellness.long_session_warned,
		"seems_frustrated": wellness.frustration_detected,
		"seems_fatigued": wellness.fatigue_detected,
		"in_tilt": wellness.tilt_detected,
		"in_flow": wellness.positive_momentum,
		"engagement_level": _engagement_level_name(engagement.current_level),
		"reading_speed": engagement.card_reading_speed,
		"total_sessions": history.total_sessions,
		"current_streak": history.current_streak,
	}


func get_summary_for_prompt() -> String:
	## Resume textuel pour le prompt LLM.
	var lines := []

	# Session info
	var minutes := get_session_length_minutes()
	lines.append("Session: %d minutes, %d cartes" % [int(minutes), current.cards_this_session])

	# Returning player
	if is_returning_player():
		if history.days_since_last_play > 0:
			lines.append("Retour apres %d jours" % history.days_since_last_play)
		if history.current_streak > 1:
			lines.append("Serie de %d jours" % history.current_streak)

	# Wellness
	if wellness.frustration_detected:
		lines.append("ATTENTION: Joueur frustre, adoucir")
	if wellness.fatigue_detected:
		lines.append("ATTENTION: Joueur fatigue, simplifier")
	if wellness.tilt_detected:
		lines.append("ATTENTION: Joueur en tilt, proposer pause")
	if wellness.positive_momentum:
		lines.append("Joueur en flow, maintenir le rythme")

	# Engagement
	if engagement.current_level == EngagementLevel.LOW:
		lines.append("Engagement bas, stimuler l'interet")
	elif engagement.current_level == EngagementLevel.VERY_HIGH:
		lines.append("Engagement tres eleve")

	return "\n".join(lines)

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func save_to_disk() -> void:
	var data := {
		"version": VERSION,
		"history": history,
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

	if data.has("history"):
		for key in data.history:
			if history.has(key):
				history[key] = data.history[key]
