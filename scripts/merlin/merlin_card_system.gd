## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Card System — Gameplay Engine (v0.4.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Handles card generation, selection, and resolution.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinCardSystem

@warning_ignore("unused_signal")
signal card_displayed(card: Dictionary)
@warning_ignore("unused_signal")
signal choice_made(option: int, effects: Array)
@warning_ignore("unused_signal")
signal run_ended(ending: Dictionary)

const CARD_TYPES := ["narrative", "event", "promise", "merlin_direct"]

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

var _effects: MerlinEffectEngine
var _llm: MerlinLlmAdapter
var _rng: MerlinRng
var _event_cards_pool: Array = []
var _promise_cards_pool: Array = []
var _event_cards_seen: Array = []
var _promise_ids_taken: Array = []

# Phase 44 — Event category selector for weighted narrative events
var _event_selector: EventCategorySelector = null

# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(effects: MerlinEffectEngine, llm: MerlinLlmAdapter, rng: MerlinRng) -> void:
	_effects = effects
	_llm = llm
	_rng = rng
	_load_event_cards()
	_load_promise_cards()
	# Phase 44 — shared event selector (may be overridden by MOS)
	_event_selector = EventCategorySelector.new()


## Set a shared EventCategorySelector instance (from MerlinOmniscient).
func set_event_selector(selector: EventCategorySelector) -> void:
	_event_selector = selector


## Get the event category for the current game state.
func get_event_category(state: Dictionary) -> Dictionary:
	if _event_selector and _event_selector.is_loaded():
		return _event_selector.select_event(state)
	return {}






# ═══════════════════════════════════════════════════════════════════════════════
# RUN MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func init_run(state: Dictionary) -> void:
	"""Initialize a new run."""
	var run = state.get("run", {})
	run["cards_played"] = 0
	run["day"] = 1
	run["active"] = true
	run["story_log"] = []
	run["active_tags"] = []
	run["active_promises"] = []
	state["run"] = run


func check_run_end(_state: Dictionary) -> Dictionary:
	"""Run end is now handled by life essence in MerlinStore."""
	return {"ended": false}


# ═══════════════════════════════════════════════════════════════════════════════
# CARD GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func get_next_card(state: Dictionary) -> Dictionary:
	"""Get the next card, either from LLM or fallback."""
	var context = _build_llm_context(state)

	# Try LLM first
	if _llm != null:
		var llm_card = await _llm.generate_card(context)
		if llm_card.get("ok", false):
			var validated = _validate_card(llm_card.get("card", {}))
			if validated.get("valid", false):
				return validated["card"]

	# Fallback to pre-written cards
	return _select_fallback_card(state)


func _build_llm_context(state: Dictionary) -> Dictionary:
	"""Build context dictionary to send to LLM."""
	var run = state.get("run", {})

	return {
		"day": run.get("day", 1),
		"cards_played": run.get("cards_played", 0),
		"story_log": run.get("story_log", []).slice(-10),  # Last 10 entries
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
	}


func _select_fallback_card(_state: Dictionary) -> Dictionary:
	## Fallback cards removed — return empty, controller retries LLM.
	return {}


func _check_card_conditions(card: Dictionary, state: Dictionary) -> bool:
	"""Check if card conditions are met."""
	var conditions = card.get("conditions", {})
	var run = state.get("run", {})

	# Min day
	if conditions.has("min_day"):
		if run.get("day", 1) < conditions["min_day"]:
			return false

	# Required tags
	if conditions.has("required_tags"):
		var active_tags = run.get("active_tags", [])
		for tag in conditions["required_tags"]:
			if not active_tags.has(tag):
				return false

	# Forbidden tags
	if conditions.has("forbidden_tags"):
		var active_tags = run.get("active_tags", [])
		for tag in conditions["forbidden_tags"]:
			if active_tags.has(tag):
				return false

	return true


func _get_emergency_card() -> Dictionary:
	return {
		"id": "emergency_001",
		"type": "narrative",
		"text": "Le silence t'entoure. Que fais-tu?",
		"speaker": "",
		"options": [
			{"direction": "left", "label": "Attendre", "effects": []},
			{"direction": "right", "label": "Avancer", "effects": []}
		],
		"conditions": {},
		"weight": 1.0,
		"tags": []
	}


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CARD SELECTION — 3-option cards for TRIADE gameplay
# ═══════════════════════════════════════════════════════════════════════════════

func get_next_triade_card(state: Dictionary) -> Dictionary:
	"""Get a TRIADE card with type selection (narrative/event/promise/merlin_direct)."""
	var run: Dictionary = state.get("run", {})
	var cards_played: int = int(run.get("cards_played", 0))
	var card_type: String = _pick_card_type(cards_played, run)

	match card_type:
		"event":
			var biome_key: String = str(run.get("current_biome", ""))
			var event_card: Dictionary = _generate_event_card(state, biome_key)
			if not event_card.is_empty():
				return event_card
		"promise":
			var biome_key: String = str(run.get("current_biome", ""))
			var promise_card: Dictionary = _generate_promise_card(state, biome_key)
			if not promise_card.is_empty():
				return promise_card
		"merlin_direct":
			var merlin_card: Dictionary = _select_merlin_direct_card(state)
			if not merlin_card.is_empty():
				return merlin_card

	# No fallback — return empty, controller will retry LLM
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# CARD TYPE SELECTION — Event / Promise / Merlin Direct
# ═══════════════════════════════════════════════════════════════════════════════

func _load_event_cards() -> void:
	"""Load event cards from JSON pool."""
	var path := "res://data/ai/event_cards.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	for key in ["seasonal", "biome", "universal"]:
		var arr: Array = data.get(key, [])
		for card in arr:
			if card is Dictionary:
				_event_cards_pool.append(card)


func _load_promise_cards() -> void:
	"""Load promise cards from JSON pool."""
	var path := "res://data/ai/promise_cards.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var arr: Array = data.get("promises", [])
	for card in arr:
		if card is Dictionary:
			_promise_cards_pool.append(card)


func _pick_card_type(cards_played: int, run: Dictionary) -> String:
	"""Weighted selection of card type based on distribution constants."""
	var weights: Dictionary = MerlinConstants.CARD_TYPE_WEIGHTS
	var min_event: int = MerlinConstants.MIN_CARDS_BEFORE_EVENT
	var min_promise: int = MerlinConstants.MIN_CARDS_BEFORE_PROMISE
	var max_promises: int = MerlinConstants.MAX_ACTIVE_PROMISES

	# Build adjusted weights
	var adjusted: Dictionary = {}
	for type_key in weights:
		adjusted[type_key] = float(weights[type_key])

	# Remove event if too early or no pool
	if cards_played < min_event or _event_cards_pool.is_empty():
		adjusted["event"] = 0.0

	# Remove promise if too early, pool empty, or max active reached
	var active_promises: Array = run.get("active_promises", [])
	if cards_played < min_promise or _promise_cards_pool.is_empty() or active_promises.size() >= max_promises:
		adjusted["promise"] = 0.0

	# Calculate total
	var total: float = 0.0
	for w in adjusted.values():
		total += float(w)
	if total <= 0.0:
		return "narrative"

	# Weighted roll
	var roll: float = (_rng.randf() if _rng else randf()) * total
	var cumulative: float = 0.0
	for type_key in adjusted:
		cumulative += float(adjusted[type_key])
		if roll < cumulative:
			return type_key

	return "narrative"


func _generate_event_card(state: Dictionary, biome_key: String) -> Dictionary:
	"""Select an event card from pool, preferring season/biome matches."""
	if _event_cards_pool.is_empty():
		return {}

	var run: Dictionary = state.get("run", {})

	# Get current season from Calendar singleton or fallback
	var current_season: String = ""
	var active_festival: String = ""
	var calendar: Node = Engine.get_main_loop().root.get_node_or_null("Calendar") if Engine.get_main_loop() else null
	if calendar:
		current_season = str(calendar.get("current_season"))
		if calendar.has_method("get_active_festival"):
			active_festival = calendar.get_active_festival()

	# Score candidates
	var candidates: Array = []
	for card in _event_cards_pool:
		var cid: String = str(card.get("id", ""))
		if _event_cards_seen.has(cid):
			continue

		var score: float = 1.0
		# Season match bonus
		if not current_season.is_empty() and str(card.get("season", "")) == current_season:
			score += 3.0
		# Festival match bonus
		if not active_festival.is_empty() and str(card.get("festival", "")) == active_festival:
			score += 5.0
		# Biome match bonus
		if not biome_key.is_empty() and str(card.get("biome", "")) == biome_key:
			score += 4.0

		candidates.append({"card": card, "score": score})

	if candidates.is_empty():
		# Reset seen list if pool exhausted
		_event_cards_seen.clear()
		return {}

	# Weighted selection by score
	var total_score: float = 0.0
	for c in candidates:
		total_score += float(c["score"])

	var roll: float = (_rng.randf() if _rng else randf()) * total_score
	var cumul: float = 0.0
	for c in candidates:
		cumul += float(c["score"])
		if roll < cumul:
			var selected: Dictionary = c["card"].duplicate(true)
			_event_cards_seen.append(str(selected.get("id", "")))
			return selected

	var fallback: Dictionary = candidates[-1]["card"].duplicate(true)
	_event_cards_seen.append(str(fallback.get("id", "")))
	return fallback


func _generate_promise_card(state: Dictionary, _biome_key: String) -> Dictionary:
	"""Select a promise card, max 2 active, skip already-taken promises."""
	if _promise_cards_pool.is_empty():
		return {}

	var run: Dictionary = state.get("run", {})
	var active_promises: Array = run.get("active_promises", [])
	if active_promises.size() >= MerlinConstants.MAX_ACTIVE_PROMISES:
		return {}

	# Collect active promise IDs
	var active_ids: Array = []
	for p in active_promises:
		if p is Dictionary:
			active_ids.append(str(p.get("promise_id", "")))

	# Filter candidates
	var candidates: Array = []
	for card in _promise_cards_pool:
		var pid: String = str(card.get("promise_id", ""))
		if active_ids.has(pid) or _promise_ids_taken.has(pid):
			continue
		candidates.append(card)

	if candidates.is_empty():
		_promise_ids_taken.clear()
		return {}

	# Random selection
	var idx: int = (_rng.randi_range(0, candidates.size() - 1) if _rng else randi() % candidates.size())
	var selected: Dictionary = candidates[idx].duplicate(true)
	_promise_ids_taken.append(str(selected.get("promise_id", "")))
	return selected


func _select_merlin_direct_card(_state: Dictionary) -> Dictionary:
	## Merlin direct cards removed — return empty, LLM generates all content.
	return {}



# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_card(card: Dictionary) -> Dictionary:
	"""Validate a card structure and effects."""
	if not card.has("text") or card["text"].is_empty():
		return {"valid": false, "error": "Missing text"}

	if not card.has("options") or card["options"].size() < 2:
		return {"valid": false, "error": "Need at least 2 options"}

	# Validate effects in options
	for option in card["options"]:
		if not option.has("direction") or not ["left", "right"].has(option["direction"]):
			return {"valid": false, "error": "Invalid option direction"}

		var effects = option.get("effects", [])
		for effect in effects:
			if not _validate_effect(effect):
				return {"valid": false, "error": "Invalid effect: " + str(effect)}

	# Ensure we have both directions
	var has_left = false
	var has_right = false
	for option in card["options"]:
		if option["direction"] == "left": has_left = true
		if option["direction"] == "right": has_right = true

	if not has_left or not has_right:
		return {"valid": false, "error": "Need both left and right options"}

	return {"valid": true, "card": card}


func _validate_effect(effect: String) -> bool:
	"""Check if effect uses valid codes."""
	var parts = effect.split(":")
	if parts.size() < 2:
		return false

	var code = parts[0]
	if not ["ADD_TAG", "REMOVE_TAG", "SET_FLAG"].has(code):
		# Fallback to MerlinEffectEngine validation
		return _effects.validate_effect(effect) if _effects else false

	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════════

func resolve_choice(state: Dictionary, card: Dictionary, direction: String) -> Dictionary:
	"""Resolve the player's choice and apply effects."""
	var option = null
	for opt in card.get("options", []):
		if opt.get("direction", "") == direction:
			option = opt
			break

	if option == null:
		return {"ok": false, "error": "Invalid direction"}

	var effects = option.get("effects", [])
	var results = _apply_card_effects(state, effects)

	# Update run state
	var run = state.get("run", {})
	run["cards_played"] = int(run.get("cards_played", 0)) + 1

	# Log to story
	var story_log = run.get("story_log", [])
	story_log.append({
		"card_id": card.get("id", ""),
		"choice": direction,
		"effects_applied": results["applied"],
		"timestamp": int(Time.get_unix_time_from_system())
	})
	run["story_log"] = story_log

	# Add card tags to active tags
	var active_tags = run.get("active_tags", [])
	for tag in card.get("tags", []):
		if not active_tags.has(tag):
			active_tags.append(tag)
	run["active_tags"] = active_tags

	# Update day (every ~25 cards)
	if run["cards_played"] % 25 == 0:
		run["day"] = int(run.get("day", 1)) + 1

	state["run"] = run


	return {
		"ok": true,
		"effects_applied": results["applied"],
		"effects_rejected": results["rejected"],
		"new_gauges": run.get("gauges", {}),
	}


func _apply_card_effects(state: Dictionary, effects: Array) -> Dictionary:
	"""Apply effects from a card choice."""
	var applied = []
	var rejected = []

	var run = state.get("run", {})
	var gauges = run.get("gauges", {})

	for effect in effects:
		if typeof(effect) != TYPE_STRING:
			rejected.append(effect)
			continue

		var parts = effect.split(":")
		if parts.size() < 2:
			rejected.append(effect)
			continue

		var code = parts[0]

		match code:
			"ADD_TAG":
				if parts.size() >= 2:
					var tags = run.get("active_tags", [])
					if not tags.has(parts[1]):
						tags.append(parts[1])
					run["active_tags"] = tags
					applied.append(effect)
				else:
					rejected.append(effect)

			"REMOVE_TAG":
				if parts.size() >= 2:
					var tags = run.get("active_tags", [])
					tags.erase(parts[1])
					run["active_tags"] = tags
					applied.append(effect)
				else:
					rejected.append(effect)

			"SET_FLAG":
				if parts.size() >= 3:
					var flags = state.get("flags", {})
					flags[parts[1]] = parts[2] == "true" or parts[2] == "1"
					state["flags"] = flags
					applied.append(effect)
				else:
					rejected.append(effect)

			_:
				# Try MerlinEffectEngine for other effects
				if _effects:
					var result = _effects.apply_effects(state, [effect], "CARD")
					if not result["applied"].is_empty():
						applied.append(effect)
					else:
						rejected.append(effect)
				else:
					rejected.append(effect)

	run["gauges"] = gauges
	state["run"] = run

	return {"applied": applied, "rejected": rejected}


