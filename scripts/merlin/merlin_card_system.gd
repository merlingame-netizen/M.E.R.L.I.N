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
var _fallback_cards: Array = []
var _triade_fallback_cards: Array = []  # NEW: 3-option cards

# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(effects: MerlinEffectEngine, llm: MerlinLlmAdapter, rng: MerlinRng) -> void:
	_effects = effects
	_llm = llm
	_rng = rng
	_load_fallback_cards()
	_load_triade_fallback_cards()


func _load_fallback_cards() -> void:
	# Base fallback cards when LLM is unavailable
	_fallback_cards = [
		{
			"id": "fb_intro_001",
			"type": "narrative",
			"text": "Le vent souffle fort ce soir. Que fais-tu?",
			"speaker": "",
			"options": [
				{"direction": "left", "label": "Se reposer", "effects": ["ADD_GAUGE:Vigueur:10", "REMOVE_GAUGE:Ressources:5"]},
				{"direction": "right", "label": "Continuer", "effects": ["REMOVE_GAUGE:Vigueur:5", "ADD_GAUGE:Ressources:5"]}
			],
			"conditions": {},
			"weight": 1.0,
			"tags": ["early"]
		},
		{
			"id": "fb_stranger_001",
			"type": "narrative",
			"text": "Un voyageur s'approche de ton campement...",
			"speaker": "",
			"options": [
				{"direction": "left", "label": "Le chasser", "effects": ["ADD_GAUGE:Vigueur:5", "REMOVE_GAUGE:Faveur:15"]},
				{"direction": "right", "label": "L'accueillir", "effects": ["ADD_GAUGE:Faveur:20", "REMOVE_GAUGE:Ressources:10"]}
			],
			"conditions": {},
			"weight": 1.0,
			"tags": ["social"]
		},
		{
			"id": "fb_merlin_001",
			"type": "merlin_direct",
			"text": "Prends garde, jeune druide. Les equilibres sont fragiles.",
			"speaker": "MERLIN",
			"options": [
				{"direction": "left", "label": "Merci du conseil", "effects": ["ADD_GAUGE:Esprit:5"]},
				{"direction": "right", "label": "Je sais ce que je fais", "effects": ["ADD_GAUGE:Faveur:5", "REMOVE_GAUGE:Esprit:5"]}
			],
			"conditions": {},
			"weight": 0.5,
			"tags": ["merlin", "advice"]
		},
		{
			"id": "fb_resource_001",
			"type": "narrative",
			"text": "Tu trouves un ancien cairn. Des offrandes y reposent.",
			"speaker": "",
			"options": [
				{"direction": "left", "label": "Respecter le lieu", "effects": ["ADD_GAUGE:Esprit:15", "ADD_GAUGE:Faveur:5"]},
				{"direction": "right", "label": "Prendre les offrandes", "effects": ["ADD_GAUGE:Ressources:20", "REMOVE_GAUGE:Esprit:10", "REMOVE_GAUGE:Faveur:10"]}
			],
			"conditions": {},
			"weight": 1.0,
			"tags": ["discovery", "moral"]
		},
		{
			"id": "fb_conflict_001",
			"type": "narrative",
			"text": "Deux villageois se disputent devant toi.",
			"speaker": "",
			"options": [
				{"direction": "left", "label": "Prendre parti", "effects": ["ADD_GAUGE:Faveur:10", "REMOVE_GAUGE:Faveur:15"]},
				{"direction": "right", "label": "Medier", "effects": ["REMOVE_GAUGE:Vigueur:10", "ADD_GAUGE:Esprit:10"]}
			],
			"conditions": {},
			"weight": 1.0,
			"tags": ["social", "conflict"]
		},
	]


func _load_triade_fallback_cards() -> void:
	# TRIADE fallback cards with 3 options (left/center/right)
	_triade_fallback_cards = [
		{
			"id": "triade_intro_001",
			"type": "narrative",
			"text": "Un druide noir te barre le chemin. Derriere lui, des villageois ligotes attendent leur sort.",
			"speaker": "MERLIN",
			"options": [
				{"position": "left", "label": "FUIR", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}]},
				{"position": "center", "label": "PARLEMENTER", "cost": 1, "effects": []},
				{"position": "right", "label": "ATTAQUER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}, {"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]}
			],
			"tags": ["confrontation", "druide_noir"]
		},
		{
			"id": "triade_stranger_001",
			"type": "narrative",
			"text": "Un voyageur epuise s'effondre a tes pieds. Il semble porter un message urgent.",
			"speaker": "",
			"options": [
				{"position": "left", "label": "IGNORER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}]},
				{"position": "center", "label": "L'ECOUTER", "cost": 1, "effects": [{"type": "ADD_KARMA", "amount": 5}]},
				{"position": "right", "label": "LE SOIGNER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}, {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}]}
			],
			"tags": ["social", "voyageur"]
		},
		{
			"id": "triade_sacred_001",
			"type": "narrative",
			"text": "Tu decouvres un ancien cairn. Des offrandes intactes y reposent depuis des siecles.",
			"speaker": "",
			"options": [
				{"position": "left", "label": "PRIER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]},
				{"position": "center", "label": "MEDITER", "cost": 1, "effects": [{"type": "ADD_SOUFFLE", "amount": 1}]},
				{"position": "right", "label": "PRENDRE", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}, {"type": "PROGRESS_MISSION", "step": 1}]}
			],
			"tags": ["sacred", "cairn", "moral"]
		},
		{
			"id": "triade_merlin_001",
			"type": "merlin_direct",
			"text": "Je t'observe depuis un moment. Tu as fait des choix... interessants. La foret murmure ton nom.",
			"speaker": "MERLIN",
			"options": [
				{"position": "left", "label": "MERCI", "effects": []},
				{"position": "center", "label": "CONSEILLE-MOI", "cost": 1, "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]},
				{"position": "right", "label": "TAIS-TOI", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}]}
			],
			"tags": ["merlin", "advice"]
		},
		{
			"id": "triade_conflict_001",
			"type": "narrative",
			"text": "Deux clans se disputent un territoire sacre. Les deux camps attendent ta decision.",
			"speaker": "",
			"options": [
				{"position": "left", "label": "CLAN A", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}, {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}]},
				{"position": "center", "label": "NEGOCIER", "cost": 1, "effects": [{"type": "ADD_KARMA", "amount": 10}]},
				{"position": "right", "label": "CLAN B", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}, {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}]}
			],
			"tags": ["conflict", "clans", "diplomacy"]
		},
		{
			"id": "triade_beast_001",
			"type": "narrative",
			"text": "Une bete sauvage te barre le passage. Elle semble blessée mais reste menaçante.",
			"speaker": "",
			"options": [
				{"position": "left", "label": "CONTOURNER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}]},
				{"position": "center", "label": "APAISER", "cost": 1, "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]},
				{"position": "right", "label": "AFFRONTER", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}, {"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}]}
			],
			"tags": ["beast", "nature", "danger"]
		},
	]


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
		var llm_card = _llm.generate_card(context)
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


func _select_fallback_card(state: Dictionary) -> Dictionary:
	"""Select a card from fallback pool based on conditions and weights."""
	var run = state.get("run", {})
	var story_log = run.get("story_log", [])
	var recent_ids = []
	for entry in story_log.slice(-5):
		if entry.has("card_id"):
			recent_ids.append(entry["card_id"])

	# Filter and weight cards
	var candidates = []
	var total_weight = 0.0

	for card in _fallback_cards:
		# Skip recently played
		if recent_ids.has(card.get("id", "")):
			continue

		# Check conditions (simplified)
		if _check_card_conditions(card, state):
			var weight = float(card.get("weight", 1.0))

			# Boost weight if pity needed
			var critical = _get_critical_gauges(run)
			if not critical.is_empty():
				# Prefer cards that help with critical gauges
				weight *= 1.5

			candidates.append({"card": card, "weight": weight})
			total_weight += weight

	if candidates.is_empty():
		# Emergency fallback
		return _fallback_cards[0] if not _fallback_cards.is_empty() else _get_emergency_card()

	# Weighted random selection
	var roll = _rng.randf() * total_weight if _rng else randf() * total_weight
	var cumulative = 0.0

	for candidate in candidates:
		cumulative += candidate["weight"]
		if roll <= cumulative:
			return candidate["card"].duplicate(true)

	return candidates[-1]["card"].duplicate(true)


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
