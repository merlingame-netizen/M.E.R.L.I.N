## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Card System — Phase 5 (DEV_PLAN_V2.5)
## ═══════════════════════════════════════════════════════════════════════════════
## 3 options per card, lexical field detection, Merlin Direct, promises,
## FastRoute fallback pool, standalone mode (no MOS dependency).
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinCardSystem

@warning_ignore("unused_signal")
signal card_displayed(card: Dictionary)
@warning_ignore("unused_signal")
signal choice_made(option_index: int, effects: Array)
@warning_ignore("unused_signal")
signal run_ended(ending: Dictionary)
@warning_ignore("unused_signal")
signal promise_created(promise: Dictionary)
@warning_ignore("unused_signal")
signal promise_resolved(promise_id: String, kept: bool)

const CARD_TYPES := ["narrative", "event", "promise", "merlin_direct"]


# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

var _effects: MerlinEffectEngine
var _llm: MerlinLlmAdapter
var _rng: MerlinRng

# Card pools (loaded from JSON)
var _event_cards_pool: Array = []
var _promise_cards_pool: Array = []
var _fastroute_narrative_pool: Array = []
var _fastroute_merlin_pool: Array = []

# Run-scoped tracking
var _event_cards_seen: Array = []
var _promise_ids_taken: Array = []
var _fastroute_seen: Array = []

# Phase 44 — Event category selector (optional, from MOS)
var _event_selector: EventCategorySelector = null

# Promise subsystem (extracted module)
var _promises: MerlinPromiseSystem = MerlinPromiseSystem.new()


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(effects: MerlinEffectEngine, llm: MerlinLlmAdapter, rng: MerlinRng) -> void:
	_effects = effects
	_llm = llm
	_rng = rng
	_load_event_cards()
	_load_promise_cards()
	_load_fastroute_cards()
	_event_selector = EventCategorySelector.new()


func set_event_selector(selector: EventCategorySelector) -> void:
	_event_selector = selector


func get_event_category(state: Dictionary) -> Dictionary:
	if _event_selector and _event_selector.is_loaded():
		return _event_selector.select_event(state)
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# RUN MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func init_run(biome: String, ogham: String) -> Dictionary:
	_event_cards_seen.clear()
	_promise_ids_taken.clear()
	_fastroute_seen.clear()
	var festival: Dictionary = StoreFactions.get_active_festival()
	return {
		"biome": biome,
		"active_ogham": ogham,
		"card_index": 0,
		"cards_played": 0,
		"active_promises": [],
		"promise_tracking": {},
		"story_log": [],
		"active_tags": [],
		"minigame_wins_this_run": 0,
		"total_healing_this_run": 0,
		"damage_taken_this_run": 0,
		"festival": festival,
	}


## Apply festival rep bonus to state at run start (call after init_run).
## Returns the bonus applied or 0 if no festival active.
static func apply_festival_bonus(state: Dictionary, run_state: Dictionary) -> int:
	var festival: Dictionary = run_state.get("festival", {})
	if not festival.get("active", false):
		return 0
	var faction: String = str(festival.get("faction", ""))
	var bonus: int = int(festival.get("rep_bonus", 0))
	if faction.is_empty() or bonus <= 0:
		return 0
	var meta: Dictionary = state.get("meta", {})
	var rep: Dictionary = meta.get("faction_rep", {})
	rep[faction] = clampi(int(rep.get(faction, 0)) + bonus, 0, 100)
	meta["faction_rep"] = rep
	state["meta"] = meta
	return bonus


# ═══════════════════════════════════════════════════════════════════════════════
# CARD GENERATION — LLM first, FastRoute fallback
# ═══════════════════════════════════════════════════════════════════════════════

func generate_card(context: Dictionary) -> Dictionary:
	var card_type: String = _pick_card_type(context)

	# Special types use pool directly (no LLM)
	# _validate_card MUST run before _ensure_3_options (padding effects are trusted).
	match card_type:
		"event":
			var event_card: Dictionary = _generate_event_card(context)
			if not event_card.is_empty():
				var v: Dictionary = _validate_card(event_card)
				if v.get("valid", false):
					var final: Dictionary = _ensure_3_options(v["card"])
					_annotate_fields(final)
					return final
				push_warning("Event card invalid: %s" % v.get("error", ""))
		"promise":
			var promise_card: Dictionary = _generate_promise_card(context)
			if not promise_card.is_empty():
				var v: Dictionary = _validate_card(promise_card)
				if v.get("valid", false):
					var final: Dictionary = _ensure_3_options(v["card"])
					_annotate_fields(final)
					return final
				push_warning("Promise card invalid: %s" % v.get("error", ""))
		"merlin_direct":
			var md_card: Dictionary = _generate_merlin_direct_card(context)
			if not md_card.is_empty():
				var v: Dictionary = _validate_card(md_card)
				if v.get("valid", false):
					var final: Dictionary = _ensure_3_options(v["card"])
					_annotate_fields(final)
					return final
				push_warning("Merlin direct card invalid: %s" % v.get("error", ""))

	# Narrative: try LLM first
	if _llm != null:
		var llm_context: Dictionary = _build_llm_context(context)
		var llm_result: Dictionary = await _llm.generate_card(llm_context)
		if llm_result.get("ok", false):
			var card: Dictionary = llm_result.get("card", {})
			var validated: Dictionary = _validate_card(card)
			if validated.get("valid", false):
				var final_card: Dictionary = _ensure_3_options(validated["card"])
				# Detect lexical fields for each option
				_annotate_fields(final_card)
				return final_card

	# FastRoute fallback
	return get_fastroute_card(context)


func get_fastroute_card(context: Dictionary) -> Dictionary:
	var biome: String = str(context.get("biome", ""))
	var candidates: Array = []
	var generic: Array = []

	for card in _fastroute_narrative_pool:
		var card_id: String = str(card.get("id", ""))
		if _fastroute_seen.has(card_id):
			continue
		var card_biome: String = str(card.get("biome", ""))
		if card_biome == biome:
			candidates.append(card)
		elif card_biome.is_empty():
			generic.append(card)

	# Prefer biome-specific, fallback to generic
	if candidates.is_empty():
		candidates = generic
	if candidates.is_empty():
		# Pool exhausted, reset and use all
		_fastroute_seen.clear()
		candidates = _fastroute_narrative_pool.duplicate()

	if candidates.is_empty():
		return _get_emergency_card()

	var idx: int = _randi_range(0, candidates.size() - 1)
	var selected: Dictionary = candidates[idx].duplicate(true)
	_fastroute_seen.append(str(selected.get("id", "")))

	# Set type, validate, annotate, pad
	selected["type"] = "narrative"
	var v: Dictionary = _validate_card(selected)
	if not v.get("valid", false):
		push_warning("FastRoute card %s invalid: %s" % [str(selected.get("id", "")), v.get("error", "")])
		return _get_emergency_card()
	_annotate_fields(v["card"])
	return _ensure_3_options(v["card"])


# ═══════════════════════════════════════════════════════════════════════════════
# LEXICAL FIELD DETECTION — 45 verbes → 8+1 champs
# ═══════════════════════════════════════════════════════════════════════════════

func detect_lexical_field(option_label: String) -> String:
	var lower: String = option_label.to_lower().strip_edges()
	# Try each verb in ACTION_VERBS
	for field in MerlinConstants.ACTION_VERBS:
		var verbs: Array = MerlinConstants.ACTION_VERBS[field]
		for verb in verbs:
			if lower.contains(str(verb)):
				return field
	return MerlinConstants.ACTION_VERB_FALLBACK_FIELD


func select_minigame(field: String) -> String:
	var minigames: Array = MerlinConstants.FIELD_MINIGAMES.get(field, [])
	if minigames.is_empty():
		return MerlinConstants.ACTION_VERB_FALLBACK_FIELD  # "esprit" — valid field name
	if minigames.size() == 1:
		return str(minigames[0])
	var idx: int = _randi_range(0, minigames.size() - 1)
	return str(minigames[idx])


func _annotate_fields(card: Dictionary) -> void:
	var options: Array = card.get("options", [])
	for option in options:
		if not (option is Dictionary):
			continue
		# Use explicit verb if present, else detect from label
		var verb: String = str(option.get("verb", ""))
		if verb.is_empty():
			var label: String = str(option.get("label", ""))
			var field: String = detect_lexical_field(label)
			option["field"] = field
		else:
			option["field"] = MerlinEffectEngine.detect_field_from_verb(verb)
		# Pre-select minigame
		option["minigame"] = select_minigame(str(option["field"]))


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN DIRECT — No minigame, effects at ×1.0
# ═══════════════════════════════════════════════════════════════════════════════

func handle_merlin_direct(card: Dictionary, chosen_option_index: int) -> Dictionary:
	var options: Array = card.get("options", [])
	if chosen_option_index < 0 or chosen_option_index >= options.size():
		return {"ok": false, "error": "Invalid option index"}
	var option: Dictionary = options[chosen_option_index]
	var effects: Array = option.get("effects", [])
	return {"ok": true, "effects": effects, "multiplier": 1.0, "skip_minigame": true}


func _generate_merlin_direct_card(context: Dictionary) -> Dictionary:
	if _fastroute_merlin_pool.is_empty():
		return {}
	var trust_tier: String = str(context.get("trust_tier", "T0"))
	var tier_index: int = _trust_tier_to_index(trust_tier)

	# Filter by trust tier
	var candidates: Array = []
	for card in _fastroute_merlin_pool:
		var required_tier: String = str(card.get("trust_tier_min", "T0"))
		if _trust_tier_to_index(required_tier) <= tier_index:
			candidates.append(card)

	if candidates.is_empty():
		return {}

	var idx: int = _randi_range(0, candidates.size() - 1)
	var selected: Dictionary = candidates[idx].duplicate(true)
	selected["type"] = "merlin_direct"
	return selected


static func _trust_tier_to_index(tier: String) -> int:
	match tier:
		"T0": return 0
		"T1": return 1
		"T2": return 2
		"T3": return 3
	return 0


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE SYSTEM — Max 2 active, countdown, trust_merlin ±10/±15
# ═══════════════════════════════════════════════════════════════════════════════

func create_promise(run_state: Dictionary, promise_data: Dictionary) -> bool:
	return _promises.create_promise(run_state, promise_data)


func resolve_promise(promise_id: String, kept: bool) -> Dictionary:
	return _promises.resolve_promise(promise_id, kept)


func check_promises(run_state: Dictionary) -> Array:
	return _promises.check_promises(run_state)


func update_promise_tracking(run_state: Dictionary, event_type: String, data: Dictionary) -> void:
	_promises.update_promise_tracking(run_state, event_type, data)


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM NARRATIVE — nuin, huath, ioho modify the card
# ═══════════════════════════════════════════════════════════════════════════════

func apply_ogham_narrative(ogham_id: String, card: Dictionary) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	match ogham_id:
		"nuin":
			# Replace the worst option with a better one
			var options: Array = result.get("options", [])
			if options.size() >= 3:
				var worst_idx: int = _find_worst_option(options)
				options[worst_idx] = {
					"label": "Invoquer la sagesse du Frene",
					"verb": "mediter",
					"field": "esprit",
					"minigame": select_minigame("esprit"),
					"effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}],
				}
				result["options"] = options
				result["ogham_modified"] = "nuin"
		"huath":
			# Reveal hidden effects (add tooltip flag)
			var options: Array = result.get("options", [])
			for option in options:
				if option is Dictionary:
					option["effects_visible"] = true
			result["options"] = options
			result["ogham_modified"] = "huath"
		"ioho":
			# Add death/rebirth twist — extra effect on all options
			var options: Array = result.get("options", [])
			for option in options:
				if option is Dictionary:
					var effects: Array = option.get("effects", [])
					effects.append({"type": "ADD_REPUTATION", "faction": "ankou", "amount": 3})
					option["effects"] = effects
			result["options"] = options
			result["ogham_modified"] = "ioho"
	return result


func _find_worst_option(options: Array) -> int:
	var worst_idx: int = 0
	var worst_score: float = 999.0
	for i in range(options.size()):
		var option: Dictionary = options[i] if options[i] is Dictionary else {}
		var effects: Array = option.get("effects", [])
		var score: float = 0.0
		for effect in effects:
			if effect is Dictionary:
				var amount: float = float(effect.get("amount", 0))
				var etype: String = str(effect.get("type", ""))
				if etype == "DAMAGE_LIFE":
					score -= amount
				elif etype == "HEAL_LIFE":
					score += amount
				elif etype == "ADD_REPUTATION":
					score += amount * 0.5
		if score < worst_score:
			worst_score = score
			worst_idx = i
	return worst_idx


# ═══════════════════════════════════════════════════════════════════════════════
# RUN END CHECK — life=0 or MOS convergence
# ═══════════════════════════════════════════════════════════════════════════════

func check_run_end(state: Dictionary) -> Dictionary:
	var life: int = int(state.get("life_essence", 100))
	var card_index: int = int(state.get("card_index", 0))
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE

	# Death
	if life <= 0:
		return {"ended": true, "reason": "death", "card_index": card_index}

	# Hard max
	var hard_max: int = int(mos.get("hard_max_cards", 50))
	if card_index >= hard_max:
		return {"ended": true, "reason": "hard_max", "card_index": card_index}

	# MOS tension tracking (bible v2.4 s.6.2)
	var soft_min: int = int(mos.get("soft_min_cards", 8))
	var target_min: int = int(mos.get("target_cards_min", 20))
	var target_max: int = int(mos.get("target_cards_max", 25))
	var soft_max: int = int(mos.get("soft_max_cards", 40))

	# Key is "tension_zone" (string) to avoid collision with run.hidden.tension (int 0-100)
	var tension_zone: String = "none"
	var convergence_zone: bool = false
	var early_zone: bool = false
	if card_index >= soft_max:
		tension_zone = "critical"
		convergence_zone = true
	elif card_index >= target_max:
		tension_zone = "high"
		convergence_zone = true
	elif card_index >= target_min:
		tension_zone = "rising"
		convergence_zone = true
	elif card_index >= soft_min:
		tension_zone = "low"
		early_zone = true

	return {
		"ended": false,
		"tension_zone": tension_zone,
		"convergence_zone": convergence_zone,
		"early_zone": early_zone,
		"card_index": card_index,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RESOLUTION — (replaces old resolve_choice)
# ═══════════════════════════════════════════════════════════════════════════════

func resolve_card(run_state: Dictionary, card: Dictionary, option_index: int, score: int) -> Dictionary:
	var options: Array = card.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return {"ok": false, "error": "Invalid option index"}

	var option: Dictionary = options[option_index]
	var card_type: String = str(card.get("type", "narrative"))
	var effects: Array = option.get("effects", [])
	var applied: Array = []
	var rejected: Array = []

	# Merlin Direct: no minigame, effects at ×1.0
	var multiplier: float = 1.0
	if card_type != "merlin_direct":
		multiplier = MerlinEffectEngine.get_multiplier(score)

	# Scale and apply effects
	for effect in effects:
		if not (effect is Dictionary):
			rejected.append(effect)
			continue
		var etype: String = str(effect.get("type", ""))
		var raw_amount: int = int(effect.get("amount", 0))
		var scaled: int = MerlinEffectEngine.scale_and_cap(etype, raw_amount, multiplier)
		var applied_effect: Dictionary = effect.duplicate(true)
		applied_effect["amount"] = scaled
		applied_effect["raw_amount"] = raw_amount
		applied_effect["multiplier"] = multiplier
		applied.append(applied_effect)

	# Handle card-level effects (tags, promises)
	_process_card_tags(run_state, card)

	# Process CREATE_PROMISE effects
	for eff in applied:
		if str(eff.get("type", "")) == "CREATE_PROMISE":
			var pid: String = str(eff.get("promise_id", ""))
			var promise_data: Dictionary = _find_promise_data(pid)
			if not promise_data.is_empty():
				create_promise(run_state, promise_data)
			else:
				rejected.append({"type": "CREATE_PROMISE", "promise_id": pid, "reason": "promise_not_found"})

	# Log to story
	var story_log: Array = run_state.get("story_log", [])
	story_log.append({
		"card_id": str(card.get("id", "")),
		"option_index": option_index,
		"score": score,
		"multiplier": multiplier,
		"effects_count": applied.size(),
	})
	if story_log.size() > 50:
		story_log = story_log.slice(-50)
	run_state["story_log"] = story_log

	return {
		"ok": true,
		"effects": applied,
		"rejected": rejected,
		"multiplier": multiplier,
		"multiplier_label": MerlinEffectEngine.get_multiplier_label(score),
		"card_type": card_type,
	}


func _process_card_tags(run_state: Dictionary, card: Dictionary) -> void:
	var tags: Array = card.get("tags", [])
	var active_tags: Array = run_state.get("active_tags", [])
	for tag in tags:
		var t: String = str(tag)
		if not active_tags.has(t):
			active_tags.append(t)
			update_promise_tracking(run_state, "tag_acquired", {"tag": t})
	run_state["active_tags"] = active_tags


# ═══════════════════════════════════════════════════════════════════════════════
# CARD TYPE SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _pick_card_type(context: Dictionary) -> String:
	# If a run graph is active, use its current node type.
	var graph_type: String = _get_graph_card_type(context)
	if graph_type != "":
		return graph_type

	var cards_played: int = int(context.get("cards_played", 0))
	var weights: Dictionary = MerlinConstants.CARD_TYPE_WEIGHTS.duplicate()

	# Remove event if too early or no pool
	if cards_played < MerlinConstants.MIN_CARDS_BEFORE_EVENT or _event_cards_pool.is_empty():
		weights["event"] = 0.0

	# Remove promise if too early, pool empty, or max active reached
	var active_promises: Array = context.get("active_promises", [])
	if cards_played < MerlinConstants.MIN_CARDS_BEFORE_PROMISE or _promise_cards_pool.is_empty() \
			or active_promises.size() >= MerlinConstants.MAX_ACTIVE_PROMISES:
		weights["promise"] = 0.0

	# Merlin direct requires at least some cards played
	if cards_played < 2:
		weights["merlin_direct"] = 0.0

	# Calculate total
	var total: float = 0.0
	for w in weights.values():
		total += float(w)
	if total <= 0.0:
		return "narrative"

	# Weighted roll
	var roll: float = _randf() * total
	var cumul: float = 0.0
	for type_key in weights:
		cumul += float(weights[type_key])
		if roll < cumul:
			return type_key

	return "narrative"


## Consult the pre-generated run graph for the current node's card type.
## Returns the mapped card type or "" if no graph / no mapping.
func _get_graph_card_type(context: Dictionary) -> String:
	var graph_data: Dictionary = context.get("run_graph", {})
	if graph_data.is_empty():
		return ""
	var graph: MerlinRunGraph = MerlinRunGraph.from_dict(graph_data)
	if graph.main_path.is_empty():
		return ""
	var current: Dictionary = graph.current_node()
	if current.is_empty():
		return ""
	var ntype: String = str(current.get("type", ""))
	# Map skeleton node types to card system types.
	match ntype:
		"narrative":
			return "narrative"
		"event":
			return "event"
		"promise":
			return "promise"
		"merlin":
			return "merlin_direct"
		"rest", "merchant", "mystery":
			return "event"
		"detour_start", "detour_end":
			return "narrative"
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# EVENT CARDS
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_event_card(context: Dictionary) -> Dictionary:
	if _event_cards_pool.is_empty():
		return {}

	var biome: String = str(context.get("biome", ""))
	var candidates: Array = []

	for card in _event_cards_pool:
		var cid: String = str(card.get("id", ""))
		if _event_cards_seen.has(cid):
			continue
		var score: float = 1.0
		# Biome match
		if not biome.is_empty() and str(card.get("biome", "")) == biome:
			score += 4.0
		candidates.append({"card": card, "score": score})

	if candidates.is_empty():
		_event_cards_seen.clear()
		return {}

	# Weighted selection
	var total: float = 0.0
	for c in candidates:
		total += float(c["score"])
	var roll: float = _randf() * total
	var cumul: float = 0.0
	for c in candidates:
		cumul += float(c["score"])
		if roll < cumul:
			var selected: Dictionary = c["card"].duplicate(true)
			_event_cards_seen.append(str(selected.get("id", "")))
			selected["type"] = "event"
			return selected

	var fallback: Dictionary = candidates[-1]["card"].duplicate(true)
	_event_cards_seen.append(str(fallback.get("id", "")))
	fallback["type"] = "event"
	return fallback


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE CARDS
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_promise_card(context: Dictionary) -> Dictionary:
	if _promise_cards_pool.is_empty():
		return {}

	var active_promises: Array = context.get("active_promises", [])
	if active_promises.size() >= MerlinConstants.MAX_ACTIVE_PROMISES:
		return {}

	var active_ids: Array = []
	for p in active_promises:
		if p is Dictionary:
			active_ids.append(str(p.get("promise_id", "")))

	var candidates: Array = []
	for card in _promise_cards_pool:
		var pid: String = str(card.get("promise_id", ""))
		if active_ids.has(pid) or _promise_ids_taken.has(pid):
			continue
		candidates.append(card)

	if candidates.is_empty():
		_promise_ids_taken.clear()
		return {}

	var idx: int = _randi_range(0, candidates.size() - 1)
	var selected: Dictionary = candidates[idx].duplicate(true)
	_promise_ids_taken.append(str(selected.get("promise_id", "")))
	selected["type"] = "promise"
	return selected


func _find_promise_data(promise_id: String) -> Dictionary:
	for card in _promise_cards_pool:
		if str(card.get("promise_id", "")) == promise_id:
			return card
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION — Always 3 options
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_card(card: Dictionary) -> Dictionary:
	if not card.has("text") or str(card.get("text", "")).is_empty():
		return {"valid": false, "error": "Missing text"}

	var options: Array = card.get("options", [])
	if options.size() < 2:
		return {"valid": false, "error": "Need at least 2 options"}

	# Validate each option: label, effects whitelist, effect count cap
	for i in range(options.size()):
		var option: Variant = options[i]
		if not (option is Dictionary):
			return {"valid": false, "error": "Invalid option format at index %d" % i}
		if str(option.get("label", "")).is_empty():
			return {"valid": false, "error": "Option %d missing label" % i}

		var effects: Array = option.get("effects", [])
		# Bible rule: max 3 effects per option
		if effects.size() > 3:
			return {"valid": false, "error": "Option %d has %d effects (max 3)" % [i, effects.size()]}

		for eff in effects:
			if not (eff is Dictionary):
				return {"valid": false, "error": "Option %d: non-dict effect" % i}
			var etype: String = str(eff.get("type", ""))
			if etype.is_empty():
				return {"valid": false, "error": "Option %d: effect missing type" % i}
			if not MerlinEffectEngine.VALID_CODES.has(etype):
				return {"valid": false, "error": "Option %d: unknown effect type '%s'" % [i, etype]}

	return {"valid": true, "card": card}


## Pad/trim options to exactly 3. Padding effects are trusted (not LLM-sourced).
## INVARIANT: _validate_card() MUST run before this function.
func _ensure_3_options(card: Dictionary) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	var options: Array = result.get("options", [])

	# If more than 3, take first 3
	if options.size() > 3:
		options = options.slice(0, 3)

	# If less than 3, pad with safe default
	while options.size() < 3:
		options.append({
			"label": "Attendre et observer",
			"verb": "attendre",
			"effects": [{"type": "HEAL_LIFE", "amount": 2}],
		})

	result["options"] = options
	return result


func _get_emergency_card() -> Dictionary:
	return {
		"id": "emergency_001",
		"type": "narrative",
		"text": "Le silence t'entoure. Le vent murmure a travers les branches.",
		"options": [
			{"label": "Observer les environs", "verb": "observer", "field": "observation", "minigame": "fouille", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Mediter un instant", "verb": "mediter", "field": "esprit", "minigame": "apaisement", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "Avancer prudemment", "verb": "s'approcher", "field": "esprit", "minigame": "sang_froid", "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 3}]},
		],
		"tags": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# LLM CONTEXT BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

func _build_llm_context(context: Dictionary) -> Dictionary:
	return {
		"biome": str(context.get("biome", "foret_broceliande")),
		"card_index": int(context.get("card_index", 0)),
		"cards_played": int(context.get("cards_played", 0)),
		"active_ogham": str(context.get("active_ogham", "beith")),
		"life_essence": int(context.get("life_essence", 100)),
		"period": str(context.get("period", "aube")),
		"story_log": context.get("story_log", []),
		"active_tags": context.get("active_tags", []),
		"active_promises": context.get("active_promises", []),
		"trust_tier": str(context.get("trust_tier", "T0")),
		"faction_rep": context.get("faction_rep", {}),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# FILE LOADERS
# ═══════════════════════════════════════════════════════════════════════════════

func _load_event_cards() -> void:
	var data: Dictionary = _load_json("res://data/ai/event_cards.json")
	if data.is_empty():
		return
	# Seasonal cards
	for card in data.get("seasonal", []):
		if card is Dictionary:
			_event_cards_pool.append(card)
	# Biome-specific cards
	var biome_specific: Dictionary = data.get("biome_specific", {})
	for biome_key in biome_specific:
		var cards: Array = biome_specific[biome_key]
		for card in cards:
			if card is Dictionary:
				var c: Dictionary = card.duplicate(true)
				c["biome"] = biome_key
				_event_cards_pool.append(c)
	# Universal cards
	for card in data.get("universal", []):
		if card is Dictionary:
			_event_cards_pool.append(card)


func _load_promise_cards() -> void:
	var data: Dictionary = _load_json("res://data/ai/promise_cards.json")
	if data.is_empty():
		return
	for card in data.get("promises", []):
		if card is Dictionary:
			_promise_cards_pool.append(card)


func _load_fastroute_cards() -> void:
	var data: Dictionary = _load_json("res://data/ai/fastroute_cards.json")
	if data.is_empty():
		return
	for card in data.get("narrative", []):
		if card is Dictionary:
			_fastroute_narrative_pool.append(card)
	for card in data.get("merlin_direct", []):
		if card is Dictionary:
			_fastroute_merlin_pool.append(card)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text: String = file.get_as_text()
	file.close()
	if json_text.strip_edges().is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		push_warning("[MerlinCards] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data = json.get_data()
	if not (data is Dictionary):
		return {}
	return data


# ═══════════════════════════════════════════════════════════════════════════════
# RNG HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _randf() -> float:
	if _rng:
		return _rng.randf()
	return randf()


func _randi_range(from: int, to: int) -> int:
	if _rng:
		return _rng.randi_range(from, to)
	# Fallback: use randf to avoid modulo bias
	return from + int(randf() * float(to - from + 1)) % (to - from + 1)
