## =============================================================================
## Event Category Selector — Weighted narrative event picker (Phase 44)
## =============================================================================
## Loads event_categories.json and selects categories + sub-types based on
## game state, frequency matrix, pity system, and anti-repetition rules.
## =============================================================================

extends RefCounted
class_name EventCategorySelector

const VERSION := "2.0.0"

# =============================================================================
# LOADED DATA
# =============================================================================

var _categories: Dictionary = {}
var _frequency_matrix: Dictionary = {}
var _pity_system: Dictionary = {}
var _anti_repetition: Dictionary = {}
var _is_loaded := false

# =============================================================================
# MODIFIER DATA (Phase card-typology)
# =============================================================================

var _modifiers: Dictionary = {}
var _modifier_rules: Dictionary = {}
var _modifiers_loaded := false

# =============================================================================
# HISTORY — For anti-repetition
# =============================================================================

var _history: Array[Dictionary] = []
## Each: { category: String, sub_type: String, card_num: int }

var _modifier_history: Array[String] = []
## Tracks recent modifier names for anti-repetition

const DEFAULT_HISTORY_WINDOW := 10

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	_load_config()


func _load_config() -> void:
	var path := "res://data/ai/config/event_categories.json"
	if not FileAccess.file_exists(path):
		push_warning("[EventCategorySelector] Config not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[EventCategorySelector] Cannot open: %s" % path)
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary:
		push_warning("[EventCategorySelector] Invalid JSON format")
		return

	_categories = data.get("categories", {})
	_frequency_matrix = data.get("frequency_matrix", {})
	_pity_system = data.get("pity_system", {})
	_anti_repetition = data.get("anti_repetition", {})
	_is_loaded = not _categories.is_empty()

	if _is_loaded:
		print("[EventCategorySelector] Loaded %d categories, %d matrix states" % [
			_categories.size(), _frequency_matrix.size()
		])

	# Load card modifiers
	_load_modifiers()


func is_loaded() -> bool:
	return _is_loaded


# =============================================================================
# MAIN SELECTION — Returns { category, sub_type, label, weight }
# =============================================================================

func select_event(game_state: Dictionary) -> Dictionary:
	## Select an event category and sub-type based on game state.
	## Returns empty dict if not loaded.
	if not _is_loaded:
		return {}

	var run: Dictionary = game_state.get("run", {})

	# Step 1: Compute weighted categories
	var weights := _compute_category_weights(run)

	# Step 2: Apply anti-repetition penalties
	weights = _apply_anti_repetition(weights)

	# Step 3: Normalize and select
	var category := _weighted_select(weights)
	if category.is_empty():
		return {}

	# Step 4: Select sub-type within category
	var sub_type := _select_sub_type(category, run)

	var cat_data: Dictionary = _categories.get(category, {})
	return {
		"category": category,
		"sub_type": sub_type,
		"label": str(cat_data.get("label", category)),
		"narrator_guidance": str(cat_data.get("narrator_guidance", "")),
		"effect_profile": cat_data.get("effect_profile", {}),
	}


# =============================================================================
# WEIGHT COMPUTATION
# =============================================================================

func _compute_category_weights(run: Dictionary) -> Dictionary:
	## Compute final weights for each category.
	## base_weight x matrix_multiplier x pity_override
	var weights: Dictionary = {}

	# Start with base weights
	for cat_key in _categories:
		var cat: Dictionary = _categories[cat_key]
		weights[cat_key] = float(cat.get("base_weight", 0.1))

	# Apply frequency matrix multipliers (multiplicative)
	var matrix_multipliers := _get_matrix_multipliers(run)
	for cat_key in weights:
		if matrix_multipliers.has(cat_key):
			weights[cat_key] *= float(matrix_multipliers[cat_key])

	# Apply pity system overrides (replace weight if condition met)
	var pity_overrides := _get_pity_overrides(run)
	for cat_key in pity_overrides:
		if weights.has(cat_key):
			# Pity overrides replace the multiplied weight
			weights[cat_key] = float(weights[cat_key]) * float(pity_overrides[cat_key])

	return weights


func _get_matrix_multipliers(run: Dictionary) -> Dictionary:
	## Find which frequency matrix states apply and combine multipliers.
	var cards_played: int = int(run.get("cards_played", 0))
	var aspects: Dictionary = run.get("aspects", {})
	var combined: Dictionary = {}

	for state_key in _frequency_matrix:
		if state_key == "_meta":
			continue
		var state_data: Dictionary = _frequency_matrix[state_key]
		var condition: Dictionary = state_data.get("condition", {})

		if not _check_matrix_condition(condition, cards_played, aspects):
			continue

		var multipliers: Dictionary = state_data.get("multipliers", {})
		for cat_key in multipliers:
			var mult: float = float(multipliers[cat_key])
			if combined.has(cat_key):
				# Combine multiple matching states: multiply
				combined[cat_key] = float(combined[cat_key]) * mult
			else:
				combined[cat_key] = mult

	return combined


func _check_matrix_condition(condition: Dictionary, cards_played: int, aspects: Dictionary) -> bool:
	## Check if a frequency matrix condition is met.

	# cards_played range
	if condition.has("cards_played_max"):
		if cards_played > int(condition["cards_played_max"]):
			return false
	if condition.has("cards_played_min"):
		if cards_played < int(condition["cards_played_min"]):
			return false

	# all_aspects condition
	if condition.has("all_aspects"):
		var required_state: String = str(condition["all_aspects"])
		for aspect in aspects:
			var val: int = int(aspects[aspect])
			if required_state == "EQUILIBRE" and val != 0:
				return false

	# any_aspect condition
	if condition.has("any_aspect"):
		var target_states: Array = condition["any_aspect"]
		var found := false
		for aspect in aspects:
			var val: int = int(aspects[aspect])
			var state_name := _aspect_val_to_state(val)
			if state_name in target_states:
				found = true
				break
		if not found:
			return false

	return true


func _get_pity_overrides(run: Dictionary) -> Dictionary:
	## Check pity system conditions and return override multipliers.
	var overrides: Dictionary = {}
	var life: int = int(run.get("life_essence", 100))
	var aspects: Dictionary = run.get("aspects", {})

	for pity_key in _pity_system:
		if pity_key == "_meta":
			continue
		var pity_data: Dictionary = _pity_system[pity_key]
		var condition: Dictionary = pity_data.get("condition", {})
		var pity_overrides: Dictionary = pity_data.get("overrides", {})

		var matched := true

		if condition.has("life_below"):
			if life >= int(condition["life_below"]):
				matched = false

		if condition.has("life_above"):
			if life <= int(condition["life_above"]):
				matched = false

		if condition.has("all_aspects"):
			var required: String = str(condition["all_aspects"])
			for aspect in aspects:
				var val: int = int(aspects[aspect])
				if required == "EQUILIBRE" and val != 0:
					matched = false
					break

		if matched:
			for cat_key in pity_overrides:
				overrides[cat_key] = float(pity_overrides[cat_key])

	return overrides


# =============================================================================
# SUB-TYPE SELECTION
# =============================================================================

func _select_sub_type(category: String, run: Dictionary) -> String:
	## Select a sub-type within a category based on trigger conditions.
	var cat_data: Dictionary = _categories.get(category, {})
	var sub_types: Dictionary = cat_data.get("sub_types", {})
	if sub_types.is_empty():
		return ""

	var aspects: Dictionary = run.get("aspects", {})
	var cards_played: int = int(run.get("cards_played", 0))
	var life: int = int(run.get("life_essence", 100))
	var biome: String = str(run.get("current_biome", ""))
	var flags: Dictionary = run.get("flags", {})
	var hidden: Dictionary = run.get("hidden", {})
	var tension: int = int(hidden.get("tension", 40))
	var karma: int = int(hidden.get("karma", 0))

	# Score each sub-type
	var candidates: Dictionary = {}
	for sub_key in sub_types:
		var sub: Dictionary = sub_types[sub_key]
		var weight: float = float(sub.get("weight", 0.25))
		var triggers: Dictionary = sub.get("triggers", {})

		# Check trigger conditions (boost weight if matched)
		var factions: Dictionary = run.get("factions", {})
		var trigger_bonus := _evaluate_triggers(triggers, aspects, cards_played, life, biome, flags, tension, karma, factions)
		weight *= trigger_bonus

		# Anti-repetition for sub-types
		var gap := _cards_since_last_subtype(sub_key)
		var min_gap: int = int(_anti_repetition.get("min_gap_same_subtype", 4))
		if gap >= 0 and gap < min_gap:
			weight *= 0.1  # Strong penalty

		if weight > 0.001:
			candidates[sub_key] = weight

	if candidates.is_empty():
		# Fallback: return first sub-type
		return sub_types.keys()[0] if not sub_types.is_empty() else ""

	return _weighted_select(candidates)


func _evaluate_triggers(triggers: Dictionary, aspects: Dictionary, cards_played: int,
		life: int, biome: String, flags: Dictionary, tension: int, karma: int,
		factions: Dictionary = {}) -> float:
	## Evaluate trigger conditions. Returns a multiplier (>1 if conditions met).
	var bonus: float = 1.0

	# Biome match
	if triggers.has("biome"):
		var biome_list: Array = triggers["biome"]
		if biome in biome_list:
			bonus *= 2.0
		else:
			bonus *= 0.5

	# Aspect condition
	if triggers.has("aspect_condition"):
		var aspect_cond: Dictionary = triggers["aspect_condition"]
		var any_matched := false
		for aspect in aspect_cond:
			var required_states: Array = aspect_cond[aspect]
			var val: int = int(aspects.get(aspect, 0))
			var state_name := _aspect_val_to_state(val)
			if state_name in required_states:
				any_matched = true
				break
		if any_matched:
			bonus *= 1.5
		else:
			bonus *= 0.3

	# Min cards played
	if triggers.has("min_cards_played"):
		if cards_played < int(triggers["min_cards_played"]):
			bonus *= 0.0  # Block

	# Flags required
	if triggers.has("flags_required"):
		var required_flags: Array = triggers["flags_required"]
		var all_present := true
		for flag in required_flags:
			if not flags.get(str(flag), false):
				all_present = false
				break
		if not all_present:
			bonus *= 0.1

	# Tension threshold
	if triggers.has("tension_above"):
		if tension >= int(triggers["tension_above"]):
			bonus *= 1.5
		else:
			bonus *= 0.5

	# Life threshold
	if triggers.has("life_below"):
		if life < int(triggers["life_below"]):
			bonus *= 1.5
		else:
			bonus *= 0.5

	# Dominant faction bonus
	if triggers.has("dominant_faction_above"):
		var max_rep := 0.0
		for f_name in factions:
			max_rep = maxf(max_rep, float(factions[f_name]))
		if max_rep >= float(triggers["dominant_faction_above"]):
			bonus *= 1.5
		else:
			bonus *= 0.5

	# Karma threshold
	if triggers.has("karma_above"):
		if karma >= int(triggers["karma_above"]):
			bonus *= 1.5
		else:
			bonus *= 0.5

	# Season match
	if triggers.has("season"):
		# Season would come from Calendar singleton
		bonus *= 1.0  # Neutral if we can't check

	return bonus


# =============================================================================
# ANTI-REPETITION
# =============================================================================

func _apply_anti_repetition(weights: Dictionary) -> Dictionary:
	## Reduce weight of recently used categories.
	var min_gap: int = int(_anti_repetition.get("min_gap_same_category", 2))
	var max_consecutive: int = int(_anti_repetition.get("max_consecutive_same_category", 2))

	var result := weights.duplicate()

	for cat_key in result:
		var gap := _cards_since_last_category(cat_key)
		if gap >= 0 and gap < min_gap:
			result[cat_key] *= 0.1  # Strong penalty

		# Check consecutive uses
		var consecutive := _count_consecutive(cat_key)
		if consecutive >= max_consecutive:
			result[cat_key] *= 0.05  # Near-zero

	return result


func _cards_since_last_category(category: String) -> int:
	## Returns -1 if never used, otherwise cards since last use.
	for i in range(_history.size() - 1, -1, -1):
		if _history[i].get("category", "") == category:
			return (_history.size() - 1) - i
	return -1


func _cards_since_last_subtype(sub_type: String) -> int:
	for i in range(_history.size() - 1, -1, -1):
		if _history[i].get("sub_type", "") == sub_type:
			return (_history.size() - 1) - i
	return -1


func _count_consecutive(category: String) -> int:
	## Count consecutive recent uses of this category.
	var count := 0
	for i in range(_history.size() - 1, -1, -1):
		if _history[i].get("category", "") == category:
			count += 1
		else:
			break
	return count


# =============================================================================
# MODIFIER SYSTEM (Phase card-typology)
# =============================================================================

func _load_modifiers() -> void:
	var path := "res://data/ai/config/card_modifiers.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary:
		return

	_modifiers = data.get("modifiers", {})
	_modifier_rules = data.get("selection_rules", {})
	_modifiers_loaded = not _modifiers.is_empty()

	if _modifiers_loaded:
		print("[EventCategorySelector] Loaded %d modifiers" % _modifiers.size())


func select_modifier(game_state: Dictionary, category: String) -> Dictionary:
	## Select a modifier overlay for the current card.
	## Returns empty dict if no modifier applies.
	if not _modifiers_loaded:
		return {}

	# Never modify scenario anchor cards
	if bool(_modifier_rules.get("scenario_anchor_never_modified", true)):
		var run: Dictionary = game_state.get("run", {})
		if run.get("current_card_is_anchor", false):
			return {}

	# Check max consecutive modified
	var max_consecutive: int = int(_modifier_rules.get("max_consecutive_modified", 2))
	var consecutive_modified := 0
	for i in range(_modifier_history.size() - 1, -1, -1):
		if _modifier_history[i] != "":
			consecutive_modified += 1
		else:
			break
	if consecutive_modified >= max_consecutive:
		return {}

	# Evaluate each modifier
	var run: Dictionary = game_state.get("run", {})
	var candidates: Array[Dictionary] = []

	for mod_key in _modifiers:
		var mod: Dictionary = _modifiers[mod_key]

		# Check category exclusion
		var exclusions: Array = mod.get("category_exclusions", [])
		if category in exclusions:
			continue

		# Check trigger conditions
		if not _check_modifier_trigger(mod.get("trigger", {}), run):
			continue

		# Check min gap
		var min_gap: int = int(_modifier_rules.get("min_gap_same_modifier", 5))
		var gap := _modifier_gap(mod_key)
		if gap >= 0 and gap < min_gap:
			continue

		var prob: float = float(mod.get("probability", 0.05))
		candidates.append({"key": mod_key, "probability": prob, "data": mod})

	# Roll for each candidate independently
	for c in candidates:
		if randf() < float(c["probability"]):
			return {
				"modifier": str(c["key"]),
				"label": str(c["data"].get("label", "")),
				"prompt_injection": str(c["data"].get("prompt_injection", "")),
				"effect_modifier": c["data"].get("effect_modifier", {}),
				"minigame_pool": c["data"].get("minigame_pool", []),
			}

	return {}


func _check_modifier_trigger(trigger: Dictionary, run: Dictionary) -> bool:
	## Check if modifier trigger conditions are met.
	if trigger.is_empty():
		return true

	var hidden: Dictionary = run.get("hidden", {})

	# dominant_faction_above
	if trigger.has("dominant_faction_above"):
		var factions: Dictionary = run.get("factions", {})
		var max_rep := 0.0
		for f_name in factions:
			max_rep = maxf(max_rep, float(factions[f_name]))
		if max_rep < float(trigger["dominant_faction_above"]):
			return false

	# cards_played_min
	if trigger.has("cards_played_min"):
		var cards: int = int(run.get("cards_played", 0))
		if cards < int(trigger["cards_played_min"]):
			return false

	# biome_has_ogham_bonus
	if trigger.has("biome_has_ogham_bonus"):
		# Simplified: always true if biome is set
		if str(run.get("current_biome", "")).is_empty():
			return false

	# season_active
	if trigger.has("season_active"):
		# Season is always active in the game
		pass

	return true


func _modifier_gap(modifier_name: String) -> int:
	## Returns cards since last use of this modifier, or -1 if never used.
	for i in range(_modifier_history.size() - 1, -1, -1):
		if _modifier_history[i] == modifier_name:
			return (_modifier_history.size() - 1) - i
	return -1


func record_modifier(modifier_name: String) -> void:
	## Record a modifier selection (or empty string if none).
	_modifier_history.append(modifier_name)
	if _modifier_history.size() > 20:
		_modifier_history = _modifier_history.slice(-20)


# =============================================================================
# HISTORY MANAGEMENT
# =============================================================================

func record_selection(category: String, sub_type: String, card_num: int) -> void:
	## Record a selection for anti-repetition tracking.
	var window: int = int(_anti_repetition.get("history_window", DEFAULT_HISTORY_WINDOW))
	_history.append({"category": category, "sub_type": sub_type, "card_num": card_num})
	if _history.size() > window:
		_history = _history.slice(-window)


func get_history() -> Array[Dictionary]:
	return _history.duplicate()


func clear_history() -> void:
	_history.clear()


# =============================================================================
# UTILITY
# =============================================================================

func _weighted_select(weights: Dictionary) -> String:
	## Weighted random selection from a {key: weight} dictionary.
	var total: float = 0.0
	for w in weights.values():
		total += float(w)
	if total <= 0.0:
		return weights.keys()[0] if not weights.is_empty() else ""

	var roll: float = randf() * total
	var cumulative: float = 0.0
	for key in weights:
		cumulative += float(weights[key])
		if roll < cumulative:
			return key

	return weights.keys()[-1] if not weights.is_empty() else ""


func _aspect_val_to_state(val: int) -> String:
	if val < 0:
		return "BAS"
	elif val > 0:
		return "HAUT"
	return "EQUILIBRE"


# =============================================================================
# DEBUG / QUERY
# =============================================================================

func get_category_info(category: String) -> Dictionary:
	return _categories.get(category, {})


func get_all_categories() -> Array[String]:
	var keys: Array[String] = []
	for k in _categories:
		keys.append(str(k))
	return keys


func get_sub_types(category: String) -> Array[String]:
	var cat: Dictionary = _categories.get(category, {})
	var sub_types: Dictionary = cat.get("sub_types", {})
	var keys: Array[String] = []
	for k in sub_types:
		keys.append(str(k))
	return keys


func get_debug_weights(game_state: Dictionary) -> Dictionary:
	## Returns computed weights for all categories (for debug UI).
	if not _is_loaded:
		return {}
	var run: Dictionary = game_state.get("run", {})
	var weights := _compute_category_weights(run)
	weights = _apply_anti_repetition(weights)
	return weights
