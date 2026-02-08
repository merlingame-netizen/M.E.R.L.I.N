## ═══════════════════════════════════════════════════════════════════════════════
## Narrative Scaler — Adaptation de Complexite Narrative
## ═══════════════════════════════════════════════════════════════════════════════
## Ajuste la complexite narrative selon l'experience du joueur.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name NarrativeScaler

# ═══════════════════════════════════════════════════════════════════════════════
# TIERS
# ═══════════════════════════════════════════════════════════════════════════════

enum Tier {
	INITIATE,    # Runs 0-5: Simple cards, clear consequences
	APPRENTICE,  # Runs 6-20: 2-card arcs, simple twists
	JOURNEYER,   # Runs 21-50: 3-5 card arcs, foreshadowing
	ADEPT,       # Runs 51-100: Complex arcs, multiple twists
	MASTER       # Runs 100+: Meta-narrative, deep lore
}

var current_tier: Tier = Tier.INITIATE

# ═══════════════════════════════════════════════════════════════════════════════
# TIER FEATURES
# ═══════════════════════════════════════════════════════════════════════════════

const TIER_FEATURES := {
	Tier.INITIATE: {
		"max_arc_length": 0,
		"max_active_arcs": 0,
		"foreshadowing": false,
		"twist_probability": 0.0,
		"lore_frequency": 0.0,
		"npc_recurrence": false,
		"faction_dynamics": false,
		"promise_cards": false,
		"merlin_comments_depth": 1,
	},
	Tier.APPRENTICE: {
		"max_arc_length": 2,
		"max_active_arcs": 1,
		"foreshadowing": false,
		"twist_probability": 0.05,
		"lore_frequency": 0.02,
		"npc_recurrence": true,
		"faction_dynamics": false,
		"promise_cards": true,
		"merlin_comments_depth": 2,
	},
	Tier.JOURNEYER: {
		"max_arc_length": 5,
		"max_active_arcs": 2,
		"foreshadowing": true,
		"twist_probability": 0.10,
		"lore_frequency": 0.05,
		"npc_recurrence": true,
		"faction_dynamics": true,
		"promise_cards": true,
		"merlin_comments_depth": 3,
	},
	Tier.ADEPT: {
		"max_arc_length": 7,
		"max_active_arcs": 2,
		"foreshadowing": true,
		"twist_probability": 0.15,
		"lore_frequency": 0.08,
		"npc_recurrence": true,
		"faction_dynamics": true,
		"promise_cards": true,
		"merlin_comments_depth": 4,
	},
	Tier.MASTER: {
		"max_arc_length": 10,
		"max_active_arcs": 3,
		"foreshadowing": true,
		"twist_probability": 0.20,
		"lore_frequency": 0.12,
		"npc_recurrence": true,
		"faction_dynamics": true,
		"promise_cards": true,
		"merlin_comments_depth": 5,
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONTENT GATES
# ═══════════════════════════════════════════════════════════════════════════════

const CONTENT_GATES := {
	"basic_cards": Tier.INITIATE,
	"promise_cards": Tier.APPRENTICE,
	"character_arcs": Tier.JOURNEYER,
	"faction_cards": Tier.JOURNEYER,
	"deep_lore_cards": Tier.ADEPT,
	"secret_ending_path": Tier.MASTER,
	"merlin_revelation": Tier.MASTER,  # Easter egg 1000 runs
}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func set_tier(tier) -> void:
	## Set tier from PlayerProfileRegistry experience tier.
	if typeof(tier) == TYPE_INT:
		current_tier = tier
	else:
		# Map from PlayerProfileRegistry enum
		match tier:
			0: current_tier = Tier.INITIATE
			1: current_tier = Tier.APPRENTICE
			2: current_tier = Tier.JOURNEYER
			3: current_tier = Tier.ADEPT
			4: current_tier = Tier.MASTER
			_: current_tier = Tier.INITIATE


func set_tier_from_runs(runs_completed: int) -> void:
	## Set tier based on runs completed.
	if runs_completed <= 5:
		current_tier = Tier.INITIATE
	elif runs_completed <= 20:
		current_tier = Tier.APPRENTICE
	elif runs_completed <= 50:
		current_tier = Tier.JOURNEYER
	elif runs_completed <= 100:
		current_tier = Tier.ADEPT
	else:
		current_tier = Tier.MASTER

# ═══════════════════════════════════════════════════════════════════════════════
# FEATURE ACCESS
# ═══════════════════════════════════════════════════════════════════════════════

func get_features() -> Dictionary:
	## Get all features for current tier.
	return TIER_FEATURES.get(current_tier, TIER_FEATURES[Tier.INITIATE])


func get_feature(feature_name: String) -> Variant:
	## Get a specific feature value.
	var features := get_features()
	return features.get(feature_name, null)


func can_use_feature(feature_name: String) -> bool:
	## Check if a feature is available at current tier.
	var features := get_features()
	var value = features.get(feature_name, null)

	if typeof(value) == TYPE_BOOL:
		return value
	elif typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return value > 0

	return false


func is_content_unlocked(content_type: String) -> bool:
	## Check if specific content is unlocked.
	var required_tier = CONTENT_GATES.get(content_type, Tier.INITIATE)
	return current_tier >= required_tier

# ═══════════════════════════════════════════════════════════════════════════════
# CARD FILTERING
# ═══════════════════════════════════════════════════════════════════════════════

func should_include_card(card: Dictionary) -> bool:
	## Determine if a card should be included based on current tier.
	var card_type: String = card.get("type", "narrative")
	var tags: Array = card.get("tags", [])
	var required_tier = card.get("required_tier", Tier.INITIATE)

	# Check tier requirement
	if current_tier < required_tier:
		return false

	# Check content gates
	if card_type == "promise":
		if not is_content_unlocked("promise_cards"):
			return false

	if "arc" in tags or card.get("arc_id", "") != "":
		if not is_content_unlocked("character_arcs"):
			return false

	if "faction" in tags:
		if not is_content_unlocked("faction_cards"):
			return false

	if "deep_lore" in tags:
		if not is_content_unlocked("deep_lore_cards"):
			return false

	return true


func filter_card_pool(cards: Array) -> Array:
	## Filter a pool of cards based on current tier.
	return cards.filter(func(card): return should_include_card(card))

# ═══════════════════════════════════════════════════════════════════════════════
# NARRATIVE COMPLEXITY
# ═══════════════════════════════════════════════════════════════════════════════

func get_max_arc_length() -> int:
	return get_feature("max_arc_length")


func get_max_active_arcs() -> int:
	return get_feature("max_active_arcs")


func can_use_foreshadowing() -> bool:
	return get_feature("foreshadowing") == true


func get_twist_probability() -> float:
	return float(get_feature("twist_probability"))


func get_lore_frequency() -> float:
	return float(get_feature("lore_frequency"))


func should_trigger_lore_drop() -> bool:
	var freq := get_lore_frequency()
	return randf() < freq


func should_trigger_twist(base_tension: float) -> bool:
	var twist_prob := get_twist_probability()
	var combined_prob := twist_prob + (base_tension * 0.1)
	return randf() < combined_prob

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN'S DEPTH
# ═══════════════════════════════════════════════════════════════════════════════

func get_merlin_comment_depth() -> int:
	## Depth level for Merlin's comments (1-5).
	return get_feature("merlin_comments_depth")


func can_merlin_reveal_lore_level(level: int) -> bool:
	## Can Merlin reveal lore of this depth level?
	var depth := get_merlin_comment_depth()
	return level <= depth


func can_merlin_show_melancholy() -> bool:
	## Can Merlin show his true sadness?
	return current_tier >= Tier.ADEPT


func can_merlin_break_fourth_wall() -> bool:
	## Can Merlin make meta comments?
	return current_tier >= Tier.MASTER

# ═══════════════════════════════════════════════════════════════════════════════
# TIER INFO
# ═══════════════════════════════════════════════════════════════════════════════

func get_tier_name() -> String:
	match current_tier:
		Tier.INITIATE: return "Initie"
		Tier.APPRENTICE: return "Apprenti"
		Tier.JOURNEYER: return "Voyageur"
		Tier.ADEPT: return "Adepte"
		Tier.MASTER: return "Maitre"
	return "Inconnu"


func get_tier_description() -> String:
	match current_tier:
		Tier.INITIATE:
			return "Decouverte du monde, choix simples"
		Tier.APPRENTICE:
			return "Premiers arcs narratifs, promesses"
		Tier.JOURNEYER:
			return "Intrigues complexes, foreshadowing"
		Tier.ADEPT:
			return "Lore profond, twists multiples"
		Tier.MASTER:
			return "Secrets ultimes, meta-narration"
	return ""


func get_progress_to_next_tier(runs_completed: int) -> Dictionary:
	## Returns progress to next tier.
	var thresholds := [5, 20, 50, 100]
	var tier_names := ["Apprenti", "Voyageur", "Adepte", "Maitre"]

	for i in range(thresholds.size()):
		if runs_completed < thresholds[i]:
			var prev_threshold: int = 0 if i == 0 else thresholds[i - 1]
			var progress := float(runs_completed - prev_threshold) / float(thresholds[i] - prev_threshold)
			return {
				"next_tier": tier_names[i],
				"progress": progress,
				"runs_needed": thresholds[i] - runs_completed,
			}

	return {
		"next_tier": "Maximum",
		"progress": 1.0,
		"runs_needed": 0,
	}
