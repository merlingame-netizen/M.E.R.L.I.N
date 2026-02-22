## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Card System — TRIADE Gameplay Engine (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Handles card generation, selection, and resolution for TRIADE system.
## 3 Aspects (Corps/Ame/Monde), 3 States, 3 Options per card.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinCardSystem

@warning_ignore("unused_signal")
signal card_displayed(card: Dictionary)
@warning_ignore("unused_signal")
signal choice_made(option: int, effects: Array)
@warning_ignore("unused_signal")
signal aspect_warning(aspect: String, state: int)
@warning_ignore("unused_signal")
signal gauge_critical(gauge: String, value: int, direction: String)  # Legacy
@warning_ignore("unused_signal")
signal run_ended(ending: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS (Legacy - kept for compatibility)
# ═══════════════════════════════════════════════════════════════════════════════

const GAUGES := ["Vigueur", "Esprit", "Faveur", "Ressources"]
const GAUGE_MIN := 0
const GAUGE_MAX := 100
const GAUGE_START := 50
const GAUGE_CRITICAL_LOW := 15
const GAUGE_CRITICAL_HIGH := 85

const CARD_TYPES := ["narrative", "event", "promise", "merlin_direct"]

const ENDINGS := {
	"vigueur_low": {"gauge": "Vigueur", "direction": "low", "title": "L'Epuisement", "text": "Ton corps a cede sous le poids des epreuves..."},
	"vigueur_high": {"gauge": "Vigueur", "direction": "high", "title": "Le Surmenage", "text": "Tu t'es consume dans l'action sans jamais te reposer..."},
	"esprit_low": {"gauge": "Esprit", "direction": "low", "title": "La Folie", "text": "Ton esprit s'est perdu dans les brumes..."},
	"esprit_high": {"gauge": "Esprit", "direction": "high", "title": "La Possession", "text": "Les esprits anciens ont pris le controle..."},
	"faveur_low": {"gauge": "Faveur", "direction": "low", "title": "L'Exile", "text": "Banni par tous, tu erres seul dans les landes..."},
	"faveur_high": {"gauge": "Faveur", "direction": "high", "title": "La Tyrannie", "text": "Le pouvoir t'a corrompu, tu regnes par la peur..."},
	"ressources_low": {"gauge": "Ressources", "direction": "low", "title": "La Famine", "text": "Sans provisions, tu succombes au denument..."},
	"ressources_high": {"gauge": "Ressources", "direction": "high", "title": "Le Pillage", "text": "Ta cupidite a seme le chaos..."},
}

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
	"""Initialize a new run with starting gauges."""
	var run = state.get("run", {})
	run["gauges"] = {}
	for gauge in GAUGES:
		run["gauges"][gauge] = GAUGE_START
	run["cards_played"] = 0
	run["day"] = 1
	run["active"] = true
	run["story_log"] = []
	run["active_tags"] = []
	run["active_promises"] = []
	state["run"] = run


func check_run_end(state: Dictionary) -> Dictionary:
	"""Check if any gauge has hit 0 or 100, ending the run."""
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})

	for gauge in GAUGES:
		var value = int(gauges.get(gauge, GAUGE_START))
		if value <= GAUGE_MIN:
			var ending_key = gauge.to_lower() + "_low"
			return _get_ending(ending_key, state)
		if value >= GAUGE_MAX:
			var ending_key = gauge.to_lower() + "_high"
			return _get_ending(ending_key, state)

	return {"ended": false}


func _get_ending(ending_key: String, state: Dictionary) -> Dictionary:
	var ending = ENDINGS.get(ending_key, ENDINGS["vigueur_low"])
	var run = state.get("run", {})
	return {
		"ended": true,
		"ending": ending,
		"score": _calculate_score(run),
		"cards_played": run.get("cards_played", 0),
		"days_survived": run.get("day", 1),
	}


func _calculate_score(run: Dictionary) -> int:
	var cards = int(run.get("cards_played", 0))
	var days = int(run.get("day", 1))
	return cards * 10 + days * 50


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
	var bestiole = state.get("bestiole", {})

	return {
		"gauges": run.get("gauges", {}),
		"bestiole": {
			"mood": _get_mood_label(bestiole),
			"bond": bestiole.get("bond", 50),
			"skills_ready": _get_ready_skills(bestiole),
		},
		"day": run.get("day", 1),
		"cards_played": run.get("cards_played", 0),
		"story_log": run.get("story_log", []).slice(-10),  # Last 10 entries
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
		"critical_gauges": _get_critical_gauges(run),
	}


func _get_mood_label(bestiole: Dictionary) -> String:
	var mood = int(bestiole.get("needs", {}).get("Mood", 50))
	if mood >= 80: return "ecstatic"
	if mood >= 60: return "happy"
	if mood >= 40: return "content"
	if mood >= 20: return "sad"
	return "depressed"


func _get_ready_skills(bestiole: Dictionary) -> Array:
	var ready = []
	var cooldowns = bestiole.get("skill_cooldowns", {})
	var equipped = bestiole.get("skills_equipped", [])
	for skill in equipped:
		if int(cooldowns.get(skill, 0)) <= 0:
			ready.append(skill)
	return ready


func _get_critical_gauges(run: Dictionary) -> Array:
	var critical = []
	var gauges = run.get("gauges", {})
	for gauge in GAUGES:
		var value = int(gauges.get(gauge, GAUGE_START))
		if value <= GAUGE_CRITICAL_LOW:
			critical.append({"gauge": gauge, "direction": "low", "value": value})
		elif value >= GAUGE_CRITICAL_HIGH:
			critical.append({"gauge": gauge, "direction": "high", "value": value})
	return critical


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
	"""Check if effect uses valid gauge codes."""
	var parts = effect.split(":")
	if parts.size() < 2:
		return false

	var code = parts[0]
	if not ["ADD_GAUGE", "REMOVE_GAUGE", "SET_GAUGE", "ADD_TAG", "REMOVE_TAG", "SET_FLAG"].has(code):
		# Fallback to MerlinEffectEngine validation
		return _effects.validate_effect(effect) if _effects else false

	# Validate gauge name
	if code in ["ADD_GAUGE", "REMOVE_GAUGE", "SET_GAUGE"]:
		if parts.size() < 3:
			return false
		if not GAUGES.has(parts[1]):
			return false

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

	# Update bestiole cooldowns
	_tick_bestiole_cooldowns(state)

	# Check for critical gauges
	_check_critical_warnings(state)

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
			"ADD_GAUGE":
				if parts.size() >= 3 and GAUGES.has(parts[1]):
					var gauge = parts[1]
					var delta = int(parts[2])
					gauges[gauge] = clampi(int(gauges.get(gauge, GAUGE_START)) + delta, GAUGE_MIN, GAUGE_MAX)
					applied.append(effect)
				else:
					rejected.append(effect)

			"REMOVE_GAUGE":
				if parts.size() >= 3 and GAUGES.has(parts[1]):
					var gauge = parts[1]
					var delta = int(parts[2])
					gauges[gauge] = clampi(int(gauges.get(gauge, GAUGE_START)) - delta, GAUGE_MIN, GAUGE_MAX)
					applied.append(effect)
				else:
					rejected.append(effect)

			"SET_GAUGE":
				if parts.size() >= 3 and GAUGES.has(parts[1]):
					var gauge = parts[1]
					var value = int(parts[2])
					gauges[gauge] = clampi(value, GAUGE_MIN, GAUGE_MAX)
					applied.append(effect)
				else:
					rejected.append(effect)

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


func _tick_bestiole_cooldowns(state: Dictionary) -> void:
	"""Decrease all bestiole skill cooldowns by 1."""
	var bestiole = state.get("bestiole", {})
	var cooldowns = bestiole.get("skill_cooldowns", {})

	for skill in cooldowns:
		cooldowns[skill] = max(0, int(cooldowns[skill]) - 1)

	bestiole["skill_cooldowns"] = cooldowns
	state["bestiole"] = bestiole


func _check_critical_warnings(state: Dictionary) -> void:
	"""Emit signals for critical gauge levels."""
	var run = state.get("run", {})
	var gauges = run.get("gauges", {})

	for gauge in GAUGES:
		var value = int(gauges.get(gauge, GAUGE_START))
		if value <= GAUGE_CRITICAL_LOW:
			gauge_critical.emit(gauge, value, "low")
		elif value >= GAUGE_CRITICAL_HIGH:
			gauge_critical.emit(gauge, value, "high")


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE SKILL USAGE
# ═══════════════════════════════════════════════════════════════════════════════

func use_bestiole_skill(state: Dictionary, skill_id: String, card: Dictionary) -> Dictionary:
	"""Use a bestiole skill on the current card."""
	var bestiole = state.get("bestiole", {})
	var cooldowns = bestiole.get("skill_cooldowns", {})
	var equipped = bestiole.get("skills_equipped", [])

	# Check if skill is equipped
	if not equipped.has(skill_id):
		return {"ok": false, "error": "Skill not equipped"}

	# Check cooldown
	if int(cooldowns.get(skill_id, 0)) > 0:
		return {"ok": false, "error": "Skill on cooldown", "cooldown": cooldowns[skill_id]}

	# Check needs
	var needs = bestiole.get("needs", {})
	if int(needs.get("Hunger", 50)) < 30:
		return {"ok": false, "error": "Bestiole too hungry"}
	if int(needs.get("Energy", 50)) < 20:
		return {"ok": false, "error": "Bestiole too tired"}

	# Apply skill effect
	var result = _apply_skill(state, skill_id, card)

	if result["ok"]:
		# Set cooldown
		cooldowns[skill_id] = result.get("cooldown", 5)
		bestiole["skill_cooldowns"] = cooldowns
		state["bestiole"] = bestiole

	return result


func _apply_skill(state: Dictionary, skill_id: String, card: Dictionary) -> Dictionary:
	"""Apply a specific skill's effect."""
	match skill_id:
		# REVEAL skills
		"beith":
			# Reveal effects of one option (left by default)
			var left_option = null
			for opt in card.get("options", []):
				if opt.get("direction") == "left":
					left_option = opt
					break
			return {"ok": true, "type": "reveal_one", "revealed": left_option.get("effects", []) if left_option else [], "cooldown": 3}

		"coll":
			# Reveal both options
			var all_effects = {}
			for opt in card.get("options", []):
				all_effects[opt.get("direction", "")] = opt.get("effects", [])
			return {"ok": true, "type": "reveal_all", "revealed": all_effects, "cooldown": 5}

		"ailm":
			# No effect on current card, sets flag for next card prediction
			var run = state.get("run", {})
			run["predict_next"] = true
			state["run"] = run
			return {"ok": true, "type": "predict_next", "cooldown": 4}

		# PROTECTION skills
		"luis":
			# 30% reduction on negative effects
			var run = state.get("run", {})
			run["effect_modifier"] = {"type": "reduce_negative", "value": 0.3}
			state["run"] = run
			return {"ok": true, "type": "protection", "modifier": 0.3, "cooldown": 4}

		"gort":
			# Absorb one negative effect
			var run = state.get("run", {})
			run["effect_modifier"] = {"type": "absorb_one_negative", "count": 1}
			state["run"] = run
			return {"ok": true, "type": "absorb", "cooldown": 6}

		# RECOVERY skills
		"quert":
			# +15 to lowest gauge
			var run = state.get("run", {})
			var gauges = run.get("gauges", {})
			var lowest_gauge = ""
			var lowest_value = GAUGE_MAX + 1
			for gauge in GAUGES:
				var val = int(gauges.get(gauge, GAUGE_START))
				if val < lowest_value:
					lowest_value = val
					lowest_gauge = gauge
			if not lowest_gauge.is_empty():
				gauges[lowest_gauge] = clampi(lowest_value + 15, GAUGE_MIN, GAUGE_MAX)
				run["gauges"] = gauges
				state["run"] = run
			return {"ok": true, "type": "heal_lowest", "gauge": lowest_gauge, "amount": 15, "cooldown": 4}

		"ruis":
			# Balance gauges toward 50
			var run = state.get("run", {})
			var gauges = run.get("gauges", {})
			for gauge in GAUGES:
				var val = int(gauges.get(gauge, GAUGE_START))
				if val < 50:
					gauges[gauge] = mini(val + 10, 50)
				elif val > 50:
					gauges[gauge] = maxi(val - 10, 50)
			run["gauges"] = gauges
			state["run"] = run
			return {"ok": true, "type": "balance", "cooldown": 8}

		# NARRATIVE skills
		"huath":
			# Reroll the card
			return {"ok": true, "type": "reroll_card", "cooldown": 5}

		"ioho":
			# Full reroll with new context
			return {"ok": true, "type": "full_reroll", "cooldown": 12}

		_:
			return {"ok": false, "error": "Unknown skill"}


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE PASSIVE MODIFIERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_bestiole_modifier(state: Dictionary) -> float:
	"""Calculate the passive modifier from bestiole state."""
	var bestiole = state.get("bestiole", {})
	var needs = bestiole.get("needs", {})
	var bond = int(bestiole.get("bond", 50))

	var modifier = 1.0

	# Bond bonus
	if bond >= 91:
		modifier += 0.20
	elif bond >= 71:
		modifier += 0.15
	elif bond >= 51:
		modifier += 0.10
	elif bond >= 31:
		modifier += 0.05

	# Mood modifier
	var mood = int(needs.get("Mood", 50))
	if mood >= 80:
		modifier += 0.15
	elif mood >= 60:
		modifier += 0.10
	elif mood >= 40:
		modifier += 0.05
	elif mood < 25:
		modifier -= 0.10

	# Penalties for low needs
	if int(needs.get("Hunger", 50)) < 30:
		modifier -= 0.10
	if int(needs.get("Energy", 50)) < 20:
		modifier -= 0.10

	return maxf(modifier, 0.5)  # Never go below 50%
