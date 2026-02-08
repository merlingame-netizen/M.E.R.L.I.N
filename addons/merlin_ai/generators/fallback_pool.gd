## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Fallback Pool — Cartes de Secours
## ═══════════════════════════════════════════════════════════════════════════════
## Pool de cartes pre-ecrites avec matching contextuel.
## Garantit que Merlin ne soit JAMAIS silencieux.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinFallbackPool

const DATA_PATH := "res://data/ai/fallback_cards.json"

# ═══════════════════════════════════════════════════════════════════════════════
# CARD POOLS BY CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

var cards_by_context := {
	"early_game": [],      # Cards 1-30
	"mid_game": [],        # Cards 31-70
	"late_game": [],       # Cards 71+
	"crisis_low": [],      # Gauge < 15
	"crisis_high": [],     # Gauge > 85
	"recovery": [],        # Balancing cards
	"universal": [],       # Always valid
	"merlin_direct": [],   # Merlin commentary
	"promise": [],         # Promise cards
}

# ═══════════════════════════════════════════════════════════════════════════════
# TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

var recently_used: Array[String] = []
const RECENT_LIMIT := 20

var _rng := RandomNumberGenerator.new()

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	_rng.randomize()
	_load_cards_from_file()
	if _count_total_cards() == 0:
		_generate_default_cards()


func _load_cards_from_file() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return

	for context in cards_by_context:
		if data.has(context):
			cards_by_context[context] = data[context]


func _count_total_cards() -> int:
	var total := 0
	for context in cards_by_context:
		total += cards_by_context[context].size()
	return total

# ═══════════════════════════════════════════════════════════════════════════════
# CARD RETRIEVAL
# ═══════════════════════════════════════════════════════════════════════════════

func get_fallback_card(context: Dictionary) -> Dictionary:
	## Retourne une carte fallback appropriee au contexte.
	var pools := _select_pools(context)
	var valid := _filter_valid(pools, context)
	var weighted := _apply_weights(valid, context)

	if weighted.is_empty():
		# Dernier recours: universal pool
		weighted = cards_by_context.universal.duplicate()

	# Eviter repetitions
	var filtered := weighted.filter(func(c): return c.get("id", "") not in recently_used)

	if filtered.is_empty():
		# Reset recent si on a tout epuise
		recently_used.clear()
		filtered = weighted

	if filtered.is_empty():
		# Ultra fallback: generate minimal card
		return _generate_emergency_card(context)

	var selected := _weighted_random(filtered)

	# Track usage
	recently_used.append(selected.get("id", ""))
	if recently_used.size() > RECENT_LIMIT:
		recently_used.pop_front()

	return selected


func _select_pools(context: Dictionary) -> Array:
	var pools := []
	var cards_played: int = int(context.get("cards_played", 0))

	# Par progression
	if cards_played < 30:
		pools.append_array(cards_by_context.early_game)
	elif cards_played < 70:
		pools.append_array(cards_by_context.mid_game)
	else:
		pools.append_array(cards_by_context.late_game)

	# Par etat de crise
	var gauges: Dictionary = context.get("gauges", {})
	for gauge_name in gauges:
		var value: int = int(gauges[gauge_name])
		if value < 15:
			pools.append_array(cards_by_context.crisis_low)
		elif value > 85:
			pools.append_array(cards_by_context.crisis_high)

	# Par aspects (TRIADE)
	var aspects: Dictionary = context.get("aspects", {})
	var any_extreme := false
	for aspect in aspects:
		if int(aspects[aspect]) != 0:
			any_extreme = true
			break
	if any_extreme:
		pools.append_array(cards_by_context.recovery)

	# Toujours inclure universal
	pools.append_array(cards_by_context.universal)

	return pools


func _filter_valid(cards: Array, context: Dictionary) -> Array:
	return cards.filter(func(card):
		# Check conditions
		var conditions: Dictionary = card.get("conditions", {})

		# Min/max card check
		var cards_played: int = int(context.get("cards_played", 0))
		if conditions.has("min_card"):
			if cards_played < int(conditions.min_card):
				return false
		if conditions.has("max_card"):
			if cards_played > int(conditions.max_card):
				return false

		# Required tags
		var required_tags: Array = conditions.get("requires_tags", [])
		var active_tags: Array = context.get("active_tags", [])
		for tag in required_tags:
			if tag not in active_tags:
				return false

		return true
	)


func _apply_weights(cards: Array, context: Dictionary) -> Array:
	var weighted := []
	var theme_weights: Dictionary = context.get("_hidden", {}).get("theme_weights", {})
	var biome: String = context.get("narrative", {}).get("world_state", {}).get("biome", "")
	var active_arcs: Array = context.get("narrative", {}).get("active_arcs", [])

	for card in cards:
		var weight := 1.0

		# Theme fatigue
		var tags: Array = card.get("tags", [])
		for tag in tags:
			if theme_weights.has(tag):
				weight *= float(theme_weights[tag])

		# Bonus si correspond au biome
		if card.get("biome", "") == biome:
			weight *= 1.5

		# Bonus si resolution d'arc
		if card.get("arc_id", "") in active_arcs:
			weight *= 2.0

		# Priority boost
		if card.get("priority", "") == "high":
			weight *= 2.0

		weighted.append({"card": card, "weight": weight})

	return weighted


func _weighted_random(weighted_cards: Array) -> Dictionary:
	if weighted_cards.is_empty():
		return {}

	var total_weight := 0.0
	for item in weighted_cards:
		total_weight += float(item.get("weight", 1.0))

	var roll := _rng.randf() * total_weight
	var cumulative := 0.0

	for item in weighted_cards:
		cumulative += float(item.get("weight", 1.0))
		if roll < cumulative:
			return item.get("card", {})

	return weighted_cards[0].get("card", {})

# ═══════════════════════════════════════════════════════════════════════════════
# EMERGENCY FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_emergency_card(context: Dictionary) -> Dictionary:
	## Genere une carte minimale en cas d'urgence.
	var aspects: Dictionary = context.get("aspects", {})

	# Find most critical aspect
	var worst_aspect := "Corps"
	var worst_state := 0

	for aspect in aspects:
		var state: int = int(aspects[aspect])
		if abs(state) > abs(worst_state):
			worst_state = state
			worst_aspect = aspect

	# Generate balancing card
	var direction := "down" if worst_state > 0 else "up"
	var opposite_direction := "up" if direction == "down" else "down"

	return {
		"id": "emergency_%d" % Time.get_ticks_msec(),
		"text": "Un moment de calme dans la tempete...",
		"type": "narrative",
		"options": [
			{
				"direction": "left",
				"label": "Se reposer",
				"effects": [
					{"type": "SHIFT_ASPECT", "aspect": worst_aspect, "direction": direction}
				],
				"preview": "Equilibrer"
			},
			{
				"direction": "right",
				"label": "Continuer",
				"effects": [
					{"type": "ADD_SOUFFLE", "amount": 1}
				],
				"preview": "+1 Souffle"
			}
		],
		"tags": ["recovery", "emergency"],
		"_generated": true,
	}

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT CARDS GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_default_cards() -> void:
	## Genere un set de cartes par defaut.

	# Early game cards
	cards_by_context.early_game = [
		{
			"id": "early_001",
			"text": "Le vent se leve, portant une odeur de fumee. Un campement, pas loin.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "L'eviter", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}
				], "preview": "Prudent"},
				{"direction": "right", "label": "Approcher", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
				], "preview": "Social"}
			],
			"tags": ["exploration", "stranger"],
			"conditions": {"max_card": 30}
		},
		{
			"id": "early_002",
			"text": "Un chemin se divise. L'un monte vers la lumiere, l'autre descend vers l'ombre.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Vers la lumiere", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}
				], "preview": "Spirituel"},
				{"direction": "right", "label": "Vers l'ombre", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}
				], "preview": "Mystere"}
			],
			"tags": ["exploration", "choice"],
			"conditions": {"max_card": 30}
		},
		{
			"id": "early_003",
			"text": "Un ruisseau chante entre les pierres. L'eau semble pure.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Se reposer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"},
					{"type": "ADD_SOUFFLE", "amount": 1}
				], "preview": "+Corps"},
				{"direction": "right", "label": "Continuer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}
				], "preview": "Fatigue"}
			],
			"tags": ["nature", "rest"],
			"conditions": {"max_card": 30}
		},
	]

	# Mid game cards
	cards_by_context.mid_game = [
		{
			"id": "mid_001",
			"text": "Un voyageur t'interpelle. Il semble connaitre ton nom.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Se mefier", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"}
				], "preview": "Prudent"},
				{"direction": "right", "label": "Ecouter", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
				], "preview": "Ouvert"}
			],
			"tags": ["stranger", "mystery"],
			"conditions": {"min_card": 31, "max_card": 70}
		},
	]

	# Late game cards
	cards_by_context.late_game = [
		{
			"id": "late_001",
			"text": "Les anciens signes brillent sur les pierres. Le temps presse.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Les dechiffrer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"},
					{"type": "USE_SOUFFLE", "amount": 1}
				], "preview": "Magie"},
				{"direction": "right", "label": "Les ignorer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}
				], "preview": "Pratique"}
			],
			"tags": ["magic", "lore"],
			"conditions": {"min_card": 71}
		},
	]

	# Crisis low cards
	cards_by_context.crisis_low = [
		{
			"id": "crisis_low_001",
			"text": "Une source claire emerge entre les roches. L'eau chante.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Se reposer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"},
					{"type": "ADD_SOUFFLE", "amount": 1}
				], "preview": "Recuperation"},
				{"direction": "right", "label": "Boire vite et partir", "effects": [
					{"type": "ADD_SOUFFLE", "amount": 1}
				], "preview": "+Souffle"}
			],
			"tags": ["recovery", "nature"],
			"priority": "high"
		},
		{
			"id": "crisis_low_002",
			"text": "Un abri naturel s'offre a toi. Le moment de reprendre des forces?",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "S'abriter", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
				], "preview": "Repos"},
				{"direction": "right", "label": "Pousser encore", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"},
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
				], "preview": "Risque"}
			],
			"tags": ["recovery", "choice"],
			"priority": "high"
		},
	]

	# Crisis high cards
	cards_by_context.crisis_high = [
		{
			"id": "crisis_high_001",
			"text": "La pression monte. Il faut relacher quelque chose.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Lacher prise", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}
				], "preview": "Calme"},
				{"direction": "right", "label": "Tenir bon", "effects": [
					{"type": "USE_SOUFFLE", "amount": 1}
				], "preview": "-Souffle"}
			],
			"tags": ["balance", "tension"],
			"priority": "high"
		},
	]

	# Recovery cards
	cards_by_context.recovery = [
		{
			"id": "recovery_001",
			"text": "Un moment de calme. L'equilibre est proche.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Mediter", "effects": [
					{"type": "ADD_SOUFFLE", "amount": 1}
				], "preview": "+Souffle"},
				{"direction": "right", "label": "Agir", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
				], "preview": "+Monde"}
			],
			"tags": ["balance", "spiritual"]
		},
	]

	# Universal cards (always valid)
	cards_by_context.universal = [
		{
			"id": "universal_001",
			"text": "Le vent murmure des secrets anciens...",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Ecouter", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}
				], "preview": "+Ame"},
				{"direction": "right", "label": "Ignorer", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}
				], "preview": "-Ame"}
			],
			"tags": ["nature", "mystery"]
		},
		{
			"id": "universal_002",
			"text": "La route continue. Chaque pas compte.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Prudemment", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
				], "preview": "Prudent"},
				{"direction": "right", "label": "Rapidement", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"}
				], "preview": "Rapide"}
			],
			"tags": ["travel", "choice"]
		},
		{
			"id": "universal_003",
			"text": "Un choix simple, mais pas sans consequences.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "La voie sage", "effects": [
					{"type": "ADD_SOUFFLE", "amount": 1}
				], "preview": "+Souffle"},
				{"direction": "right", "label": "La voie audacieuse", "effects": [
					{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
				], "preview": "+Monde"}
			],
			"tags": ["choice"]
		},
	]

	# Merlin direct cards
	cards_by_context.merlin_direct = [
		{
			"id": "merlin_001",
			"text": "Tu te debrouilles bien, voyageur. Mais la route est encore longue.",
			"speaker": "MERLIN",
			"type": "merlin",
			"options": [
				{"direction": "left", "label": "Merci", "effects": [], "preview": ""},
				{"direction": "right", "label": "Je sais", "effects": [], "preview": ""}
			],
			"tags": ["merlin", "encouragement"]
		},
	]


func save_cards_to_file() -> void:
	## Sauvegarde les cartes actuelles dans un fichier.
	var dir := DATA_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cards_by_context, "\t"))
		file.close()


func add_card(context: String, card: Dictionary) -> bool:
	## Ajoute une carte a un contexte.
	if not cards_by_context.has(context):
		return false

	cards_by_context[context].append(card)
	return true


func get_pool_sizes() -> Dictionary:
	## Retourne la taille de chaque pool.
	var sizes := {}
	for context in cards_by_context:
		sizes[context] = cards_by_context[context].size()
	return sizes
