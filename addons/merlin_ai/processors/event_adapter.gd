## =============================================================================
## Event Adapter — Ponderation Dynamique des Evenements Calendaires
## =============================================================================
## Calcule weight_final pour chaque evenement en appliquant 7 facteurs:
##   f_skill, f_pity, f_crisis, f_conditions, f_fatigue, f_season, f_date_proximity
## Spec: CAL-REQ-060 a CAL-REQ-081
## =============================================================================

extends RefCounted
class_name EventAdapter

signal event_selected(event_id: String, weight_final: float)
signal event_resolved(event_id: String, choice: String)

# =============================================================================
# CONSTANTS
# =============================================================================

const W_MAX := 3.0
const W_MIN := 0.0
const EVENT_CARD_PROBABILITY := 0.15  # ~15% du pool (CAL-REQ-060)
const FATIGUE_PENALTY_PER_REPEAT := 0.15
const FATIGUE_HISTORY_WINDOW := 10
const DATE_PROXIMITY_BONUS_DAYS := 7
const DATE_PROXIMITY_MAX_BONUS := 1.4

# =============================================================================
# STATE
# =============================================================================

## Reference to DifficultyAdapter (read-only access to skill, pity, crisis)
var difficulty_adapter: DifficultyAdapter = null

## Full event catalogue loaded from JSON
var _event_catalogue: Array = []

## History of events seen this run (for fatigue)
var _events_seen: Array = []

## Current calendar context
var _current_season: String = "winter"
var _current_month: int = 1
var _current_day: int = 1
var _current_day_of_year: int = 1

## Logging
var _weight_log: Array = []

# =============================================================================
# SETUP
# =============================================================================

func setup(diff_adapter: DifficultyAdapter) -> void:
	difficulty_adapter = diff_adapter
	_load_event_catalogue()


func _load_event_catalogue() -> void:
	var path := "res://data/calendar_events.json"
	if not FileAccess.file_exists(path):
		push_warning("[EventAdapter] calendar_events.json not found")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[EventAdapter] JSON parse error: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	_event_catalogue = data.get("events", [])
	print("[EventAdapter] Loaded %d events from catalogue" % _event_catalogue.size())


func reset_for_new_run() -> void:
	_events_seen.clear()
	_weight_log.clear()


# =============================================================================
# CALENDAR CONTEXT UPDATE
# =============================================================================

func update_calendar_context(season: String, month: int, day: int, day_of_year: int) -> void:
	_current_season = season
	_current_month = month
	_current_day = day
	_current_day_of_year = day_of_year


# =============================================================================
# CORE: GET ACTIVE EVENTS (weighted)
# =============================================================================

func get_active_events(game_context: Dictionary) -> Array:
	## Return all eligible events with their weight_final, sorted by weight desc.
	var results: Array = []

	for ev in _event_catalogue:
		if not _is_in_window(ev):
			continue
		if _f_conditions(ev, game_context) <= 0.0:
			continue

		var weight_final := _compute_weight_final(ev, game_context)
		if weight_final <= W_MIN:
			continue

		results.append({
			"event": ev,
			"weight_final": weight_final,
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.weight_final > b.weight_final
	)

	return results


func select_event_for_card(game_context: Dictionary) -> Dictionary:
	## Select one event by weighted random from active pool.
	## Returns the event dict or empty if none eligible.
	var active := get_active_events(game_context)
	if active.is_empty():
		return {}

	var total_weight := 0.0
	for entry in active:
		total_weight += entry.weight_final

	if total_weight <= 0.0:
		return {}

	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in active:
		cumulative += entry.weight_final
		if roll <= cumulative:
			var selected: Dictionary = entry.event
			_log_weight(selected, entry.weight_final)
			event_selected.emit(selected.get("id", ""), entry.weight_final)
			return selected

	# Fallback: return highest weight
	var fallback: Dictionary = active[0].event
	event_selected.emit(fallback.get("id", ""), active[0].weight_final)
	return fallback


# =============================================================================
# WEIGHT COMPUTATION (7 FACTORS)
# =============================================================================

func _compute_weight_final(ev: Dictionary, ctx: Dictionary) -> float:
	var w: float = float(ev.get("weight_base", 1.0))

	var fs := _f_skill()
	var fp := _f_pity()
	var fc := _f_crisis(ctx)
	var fco := _f_conditions(ev, ctx)
	var ff := _f_fatigue(ev)
	var fse := _f_season(ev)
	var fd := _f_date_proximity(ev)

	w = w * fs * fp * fc * fco * ff * fse * fd
	w = clampf(w, W_MIN, W_MAX)

	return w


func _f_skill() -> float:
	## CAL-REQ-070: Reduce punishing events for weak players.
	if difficulty_adapter == null:
		return 1.0
	# Skill 0.0 -> factor 1.2 (more recovery), Skill 1.0 -> factor 0.9 (slightly less)
	return lerpf(1.2, 0.9, difficulty_adapter.player_skill)


func _f_pity() -> float:
	## CAL-REQ-071: Increase positive events after consecutive deaths.
	if difficulty_adapter == null:
		return 1.0
	if difficulty_adapter.pity_mode_active:
		return 1.5
	if difficulty_adapter.consecutive_deaths > 0:
		return 1.0 + (difficulty_adapter.consecutive_deaths * 0.1)
	return 1.0


func _f_crisis(ctx: Dictionary) -> float:
	## CAL-REQ-072: Favor recovery events when gauges are critical.
	## Uses faction_rep_delta and life_essence for crisis detection.
	var faction_rep_delta: Dictionary = ctx.get("faction_rep_delta", {})
	var extreme_count := 0
	for faction in faction_rep_delta:
		var delta: float = float(faction_rep_delta[faction])
		if absf(delta) > 15.0:
			extreme_count += 1

	# Low life is also a crisis signal
	var life: int = int(ctx.get("life_essence", 100))
	if life < 20:
		extreme_count += 1

	if extreme_count >= 2:
		return 1.5  # Boost all events during crisis (recovery ones have higher base weight)
	if extreme_count == 1:
		return 1.2
	return 1.0


func _f_conditions(ev: Dictionary, ctx: Dictionary) -> float:
	## CAL-REQ-073: Weight = 0 if conditions not met.
	var conditions: Dictionary = ev.get("conditions", {})
	if conditions.is_empty():
		return 1.0

	# Check min_run_index
	var min_run: int = int(conditions.get("min_run_index", 0))
	var total_runs: int = int(ctx.get("total_runs", 0))
	if total_runs < min_run:
		return 0.0

	# Check min_cards_played
	var min_cards: int = int(conditions.get("min_cards_played", 0))
	var cards_played: int = int(ctx.get("cards_played", 0))
	if cards_played < min_cards:
		return 0.0

	# Check hidden flag
	if conditions.get("hidden", false):
		var has_brumes: bool = ctx.get("calendrier_des_brumes", false)
		if not has_brumes:
			return 0.0

	# Check flags_required
	var required_flags: Array = conditions.get("flags_required", [])
	var active_flags: Dictionary = ctx.get("flags", {})
	for flag in required_flags:
		if not active_flags.has(flag):
			return 0.0

	# Check reputation thresholds (v2.5)
	var rep_above: Variant = conditions.get("reputation_above", null)
	if rep_above is Dictionary:
		var factions_state: Dictionary = ctx.get("factions", {})
		for faction in rep_above:
			var required: int = int(rep_above[faction])
			var current_rep: int = int(factions_state.get(faction, 0))
			if current_rep < required:
				return 0.0

	var rep_below: Variant = conditions.get("reputation_below", null)
	if rep_below is Dictionary:
		var factions_state2: Dictionary = ctx.get("factions", {})
		for faction in rep_below:
			var threshold: int = int(rep_below[faction])
			var current_rep: int = int(factions_state2.get(faction, 0))
			if current_rep >= threshold:
				return 0.0

	# Check life thresholds (v2.5)
	var life_below: int = int(conditions.get("life_below", -1))
	if life_below > -1:
		var current_life: int = int(ctx.get("life_essence", 100))
		if current_life >= life_below:
			return 0.0

	var life_above: int = int(conditions.get("life_above", -1))
	if life_above > -1:
		var current_life: int = int(ctx.get("life_essence", 100))
		if current_life < life_above:
			return 0.0

	# Check season
	var season_req = conditions.get("season", null)
	if season_req is Array and not season_req.is_empty():
		if _current_season not in season_req:
			return 0.0

	# Check karma thresholds
	var karma_above: int = int(conditions.get("karma_above", -999))
	var current_karma: int = int(ctx.get("karma", 0))
	if karma_above > -999 and current_karma < karma_above:
		return 0.0

	# Check tension thresholds
	var tension_above: int = int(conditions.get("tension_above", -999))
	var current_tension: int = int(ctx.get("tension", 0))
	if tension_above > -999 and current_tension < tension_above:
		return 0.0

	# Check dominant_faction_above
	var faction_min: int = int(conditions.get("dominant_faction_above", -1))
	if faction_min > -1:
		var factions: Dictionary = ctx.get("factions", {})
		var max_rep := 0.0
		for f_name in factions:
			max_rep = maxf(max_rep, float(factions[f_name]))
		if max_rep < faction_min:
			return 0.0

	# Check trust_merlin_above
	var trust_min: int = int(conditions.get("trust_merlin_above", -1))
	var current_trust: int = int(ctx.get("trust_merlin", 0))
	if trust_min > -1 and current_trust < trust_min:
		return 0.0

	# Check min_endings_seen
	var min_endings: int = int(conditions.get("min_endings_seen", 0))
	var endings_count: int = int(ctx.get("endings_seen_count", 0))
	if endings_count < min_endings:
		return 0.0

	return 1.0


func _f_fatigue(ev: Dictionary) -> float:
	## CAL-REQ-074: Penalize repetition of same tags/category.
	if _events_seen.is_empty():
		return 1.0

	var ev_id: String = ev.get("id", "")
	var ev_tags: Array = ev.get("tags", [])
	var ev_category: String = ev.get("category", "")

	var penalty := 0.0
	var window: Array = _events_seen.slice(-FATIGUE_HISTORY_WINDOW)

	for seen_id in window:
		if seen_id == ev_id:
			penalty += FATIGUE_PENALTY_PER_REPEAT * 2  # Same event = double penalty

	# Count category repetition in recent history
	# We only store IDs, so we check against catalogue for category
	var category_count := 0
	for seen_id in window:
		var seen_ev := _find_event_by_id(seen_id)
		if not seen_ev.is_empty() and seen_ev.get("category", "") == ev_category:
			category_count += 1

	penalty += category_count * (FATIGUE_PENALTY_PER_REPEAT * 0.5)

	return maxf(0.1, 1.0 - penalty)


func _f_season(ev: Dictionary) -> float:
	## CAL-REQ-075: Modulate slightly by season coherence.
	var ev_tags: Array = ev.get("tags", [])

	# Exact season match = small boost
	if _current_season in ev_tags:
		return 1.15

	# Opposite season = slight penalty
	var opposite := _get_opposite_season(_current_season)
	if opposite in ev_tags:
		return 0.85

	return 1.0


func _f_date_proximity(ev: Dictionary) -> float:
	## CAL-REQ-076: Bonus as event date approaches.
	var date_val = ev.get("date", null)
	if date_val == null or date_val == "floating":
		return 1.0

	var ev_month := 0
	var ev_day := 0
	if date_val is Dictionary:
		if date_val.has("window"):
			var w: Dictionary = date_val.window
			ev_month = int(w.get("start_month", 0))
			ev_day = int(w.get("start_day", 0))
		else:
			ev_month = int(date_val.get("month", 0))
			ev_day = int(date_val.get("day", 0))

	if ev_month == 0:
		return 1.0

	var ev_doy := _get_day_of_year(ev_month, ev_day)
	var diff := absi(ev_doy - _current_day_of_year)
	# Handle year wrap-around
	if diff > 182:
		diff = 365 - diff

	if diff <= DATE_PROXIMITY_BONUS_DAYS:
		var t := 1.0 - (float(diff) / float(DATE_PROXIMITY_BONUS_DAYS))
		return lerpf(1.0, DATE_PROXIMITY_MAX_BONUS, t)

	return 1.0


# =============================================================================
# EVENT LIFECYCLE
# =============================================================================

func record_event(event_id: String) -> void:
	## Called when an event is shown to the player.
	_events_seen.append(event_id)
	# Trim to prevent unbounded growth
	if _events_seen.size() > 50:
		_events_seen = _events_seen.slice(-30)


func on_event_resolved(event_id: String, choice: String) -> void:
	## Called when player resolves an event card.
	event_resolved.emit(event_id, choice)


func get_events_in_window_from_catalogue(days_ahead: int) -> Array:
	## Return events from catalogue that fall within the next N days.
	var results: Array = []
	for ev in _event_catalogue:
		var date_val = ev.get("date", null)
		if date_val == null or date_val == "floating":
			continue

		var ev_month := 0
		var ev_day := 0
		if date_val is Dictionary:
			if date_val.has("window"):
				var w: Dictionary = date_val.window
				ev_month = int(w.get("start_month", 0))
				ev_day = int(w.get("start_day", 0))
			else:
				ev_month = int(date_val.get("month", 0))
				ev_day = int(date_val.get("day", 0))

		if ev_month == 0:
			continue

		var ev_doy := _get_day_of_year(ev_month, ev_day)
		var diff := ev_doy - _current_day_of_year
		if diff < 0:
			diff += 365  # Next year
		if diff <= days_ahead:
			results.append(ev)

	return results


# =============================================================================
# HELPERS
# =============================================================================

func _is_in_window(ev: Dictionary) -> bool:
	## Check if an event is within its valid date window.
	var date_val = ev.get("date", null)

	# Floating events are always in window (conditions handle availability)
	if date_val == null or date_val == "floating":
		return true

	if date_val is Dictionary:
		if date_val.has("window"):
			var w: Dictionary = date_val.window
			var start_doy := _get_day_of_year(int(w.get("start_month", 1)), int(w.get("start_day", 1)))
			var end_doy := _get_day_of_year(int(w.get("end_month", 12)), int(w.get("end_day", 31)))
			if start_doy <= end_doy:
				return _current_day_of_year >= start_doy and _current_day_of_year <= end_doy
			else:
				# Window spans year boundary (e.g. Oct-Jan)
				return _current_day_of_year >= start_doy or _current_day_of_year <= end_doy
		else:
			# Fixed date: allow +/- 3 days
			var ev_doy := _get_day_of_year(int(date_val.get("month", 1)), int(date_val.get("day", 1)))
			var diff := absi(ev_doy - _current_day_of_year)
			if diff > 182:
				diff = 365 - diff
			return diff <= 3

	return false


func _find_event_by_id(event_id: String) -> Dictionary:
	for ev in _event_catalogue:
		if ev.get("id", "") == event_id:
			return ev
	return {}


func _get_opposite_season(season: String) -> String:
	match season:
		"winter": return "summer"
		"summer": return "winter"
		"spring": return "autumn"
		"autumn": return "spring"
	return ""


func _get_day_of_year(month: int, day: int) -> int:
	var days := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var total := 0
	for m in range(1, month):
		total += days[m]
	return total + day


# =============================================================================
# LOGGING (CAL-REQ-142)
# =============================================================================

func _log_weight(ev: Dictionary, weight_final: float) -> void:
	var entry := {
		"event_id": ev.get("id", ""),
		"weight_base": ev.get("weight_base", 0.0),
		"weight_final": weight_final,
		"season": _current_season,
		"day_of_year": _current_day_of_year,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	_weight_log.append(entry)
	# Keep log bounded
	if _weight_log.size() > 100:
		_weight_log = _weight_log.slice(-50)
	print("[EventAdapter] Selected %s — w_base=%.2f w_final=%.2f" % [
		entry.event_id, entry.weight_base, weight_final
	])


func get_weight_log() -> Array:
	return _weight_log.duplicate()


func get_debug_info() -> Dictionary:
	return {
		"catalogue_size": _event_catalogue.size(),
		"events_seen_count": _events_seen.size(),
		"current_season": _current_season,
		"current_day": _current_day,
		"current_month": _current_month,
		"weight_log_size": _weight_log.size(),
	}
