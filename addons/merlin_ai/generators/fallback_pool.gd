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
	"npc_encounter": [],   # NPC dialogue cards
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

	# Par factions (reputation extremes)
	var factions: Dictionary = context.get("factions", {})
	var any_extreme := false
	for faction in factions:
		var val: float = float(factions[faction])
		if val <= 20.0 or val >= 80.0:
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
	var factions: Dictionary = context.get("factions", {})

	# Find most hostile faction to offer a reconciliation opportunity
	var worst_faction := "druides"
	var worst_val := 50.0
	for faction in factions:
		var val: float = float(factions[faction])
		if val < worst_val:
			worst_val = val
			worst_faction = str(faction)

	return {
		"id": "emergency_%d" % Time.get_ticks_msec(),
		"text": "Un moment de calme dans la tempete...",
		"type": "narrative",
		"options": [
			{
				"direction": "left",
				"label": "Tendre la main",
				"effects": [
					{"type": "ADD_REPUTATION", "faction": worst_faction, "amount": 10}
				],
				"preview": "+Rep"
			},
			{
				"direction": "center",
				"label": "Mediter sur les oghams",
				"effects": [
					{"type": "ADD_REPUTATION", "faction": worst_faction, "amount": 5}
				],
				"preview": "+Rep",
			},
			{
				"direction": "right",
				"label": "Continuer sans s'arreter",
				"effects": [],
				"preview": "Neutre"
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
					{"type": "ADD_TENSION", "amount": 5}
				], "preview": "Prudent"},
				{"direction": "center", "label": "Observer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Approcher", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
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
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "Spirituel"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Vers l'ombre", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}
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
					{"type": "HEAL_LIFE", "amount": 5},
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Vie"},
				{"direction": "center", "label": "Observer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Continuer", "effects": [
					{"type": "DAMAGE_LIFE", "amount": 3}
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
					{"type": "ADD_TENSION", "amount": 5}
				], "preview": "Prudent"},
				{"direction": "center", "label": "Parlementer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Ecouter", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
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
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5},
					{"type": "ADD_ANAM", "amount": 15}
				], "preview": "Magie"},
				{"direction": "center", "label": "Observer", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Les ignorer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}
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
					{"type": "HEAL_LIFE", "amount": 5},
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "Recuperation"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Boire vite et partir", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"}
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
					{"type": "HEAL_LIFE", "amount": 5}
				], "preview": "Repos"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Pousser encore", "effects": [
					{"type": "DAMAGE_LIFE", "amount": 3},
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
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
					{"type": "DAMAGE_LIFE", "amount": 3}
				], "preview": "Calme"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Tenir bon", "effects": [
					{"type": "ADD_ANAM", "amount": 15}
				], "preview": "+Anam"}
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
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "center", "label": "Observer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Agir", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
				], "preview": "+Anciens"}
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
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Ignorer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}
				], "preview": "+Ankou"}
			],
			"tags": ["nature", "mystery"]
		},
		{
			"id": "universal_002",
			"text": "La route continue. Chaque pas compte.",
			"type": "narrative",
			"options": [
				{"direction": "left", "label": "Prudemment", "effects": [
					{"type": "HEAL_LIFE", "amount": 5}
				], "preview": "Prudent"},
				{"direction": "center", "label": "Observer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Rapidement", "effects": [
					{"type": "DAMAGE_LIFE", "amount": 3}
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
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "La voie audacieuse", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
				], "preview": "+Anciens"}
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
				{"direction": "center", "label": "Mediter", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Je sais", "effects": [], "preview": ""}
			],
			"tags": ["merlin", "encouragement"]
		},
	]

	# NPC encounter cards
	cards_by_context.npc_encounter = [
		{
			"id": "npc_druide_001",
			"text": "Un vieux druide emerge de la brume, son baton orne de gui. 'Les esprits m'ont parle de toi, voyageur.'",
			"speaker": "Druide Ancien",
			"type": "npc_encounter",
			"options": [
				{"direction": "left", "label": "Demander conseil", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "center", "label": "Offrir de l'Anam", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Passer son chemin", "effects": [
					{"type": "HEAL_LIFE", "amount": 5}
				], "preview": "+Vie"},
			],
			"tags": ["npc", "magic", "lore"]
		},
		{
			"id": "npc_villageois_001",
			"text": "Une villageoise t'interpelle depuis le seuil de sa chaumiere. 'Etranger ! Les loups rodent plus pres chaque nuit.'",
			"speaker": "Villageoise",
			"type": "npc_encounter",
			"options": [
				{"direction": "left", "label": "Proposer de l'aide", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
				], "preview": "+Anciens"},
				{"direction": "center", "label": "Ecouter attentivement", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Ignorer l'appel", "effects": [
					{"type": "ADD_TENSION", "amount": 5}
				], "preview": "+Tension"},
			],
			"tags": ["npc", "social", "danger"]
		},
		{
			"id": "npc_barde_001",
			"text": "Un barde assis pres du feu gratte sa lyre. 'Chaque histoire a trois faces, ami. Laquelle veux-tu entendre ?'",
			"speaker": "Barde Errant",
			"type": "npc_encounter",
			"options": [
				{"direction": "left", "label": "L'histoire du heros", "effects": [
					{"type": "HEAL_LIFE", "amount": 5}
				], "preview": "+Vie"},
				{"direction": "center", "label": "L'histoire du sage", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "L'histoire du roi", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
				], "preview": "+Anciens"},
			],
			"tags": ["npc", "social", "lore"]
		},
		{
			"id": "npc_guerrier_001",
			"text": "Un guerrier balafre bloque le passage, lance au poing. 'On ne passe pas sans prouver sa valeur.'",
			"speaker": "Guerrier du Gue",
			"type": "npc_encounter",
			"options": [
				{"direction": "left", "label": "Affronter le defi", "effects": [
					{"type": "HEAL_LIFE", "amount": 5}
				], "preview": "+Vie"},
				{"direction": "center", "label": "Ruser pour passer", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Contourner le gue", "effects": [
					{"type": "DAMAGE_LIFE", "amount": 3}
				], "preview": "-Vie"},
			],
			"tags": ["npc", "combat", "danger"]
		},
		{
			"id": "npc_marchand_001",
			"text": "Un marchand itinerant etale ses curiosites sur un tapis use. 'Tout se troque, voyageur. Meme le temps.'",
			"speaker": "Marchand des Ombres",
			"type": "npc_encounter",
			"options": [
				{"direction": "left", "label": "Troquer un souvenir", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}
				], "preview": "+Ankou"},
				{"direction": "center", "label": "Observer ses merveilles", "effects": [
					{"type": "ADD_ANAM", "amount": 10}
				], "preview": "+Anam"},
				{"direction": "right", "label": "Marchander dur", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}
				], "preview": "+Anciens"},
			],
			"tags": ["npc", "merchant", "trade"]
		},
		{
			"id": "npc_gwenn_merchant",
			"text": "Gwenn, herboriste de Broceliande, prepare des potions sous un chene. 'Mes remedes guerissent tout... pour un prix.'",
			"speaker": "Gwenn",
			"type": "npc_encounter",
			"biome": "foret_broceliande",
			"options": [
				{"direction": "left", "label": "Acheter une potion de soin", "effects": [
					{"type": "HEAL_LIFE", "amount": 12}, {"type": "ADD_BIOME_CURRENCY", "amount": -3}
				], "preview": "+12 Vie / -3 Monnaie"},
				{"direction": "center", "label": "Demander un conseil", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}
				], "preview": "+Druides"},
				{"direction": "right", "label": "Proposer des herbes", "effects": [
					{"type": "ADD_BIOME_CURRENCY", "amount": 5}
				], "preview": "+5 Monnaie"},
			],
			"tags": ["npc", "merchant", "foret", "gwenn"]
		},
		{
			"id": "npc_erwan_merchant",
			"text": "Erwan taille des pierres au bord du sentier. 'Les cairns protegent les voyageurs... pour qui sait les honorer.'",
			"speaker": "Erwan",
			"type": "npc_encounter",
			"biome": "landes_bruyere",
			"options": [
				{"direction": "left", "label": "Acheter un talisman", "effects": [
					{"type": "HEAL_LIFE", "amount": 8}, {"type": "ADD_BIOME_CURRENCY", "amount": -2}
				], "preview": "+8 Vie / -2 Monnaie"},
				{"direction": "center", "label": "Ecouter ses recits", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}
				], "preview": "+Anciens"},
				{"direction": "right", "label": "Aider a la taille", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}, {"type": "HEAL_LIFE", "amount": 3}
				], "preview": "+Anciens +Vie"},
			],
			"tags": ["npc", "merchant", "landes", "erwan"]
		},
		{
			"id": "npc_maelle_merchant",
			"text": "Maelle, pecheuse aux yeux verts, repare ses filets. 'La mer donne et reprend. Veux-tu troquer ?'",
			"speaker": "Maelle",
			"type": "npc_encounter",
			"biome": "cotes_sauvages",
			"options": [
				{"direction": "left", "label": "Acheter du poisson seche", "effects": [
					{"type": "HEAL_LIFE", "amount": 10}, {"type": "ADD_BIOME_CURRENCY", "amount": -3}
				], "preview": "+10 Vie / -3 Monnaie"},
				{"direction": "center", "label": "Aider a reparer les filets", "effects": [
					{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 8}
				], "preview": "+Korrigans"},
				{"direction": "right", "label": "Echanger des coquillages", "effects": [
					{"type": "ADD_BIOME_CURRENCY", "amount": 5}
				], "preview": "+5 Monnaie"},
			],
			"tags": ["npc", "merchant", "cotes", "maelle"]
		},
		{
			"id": "npc_cadogan_merchant",
			"text": "Cadogan le forgeron souffle sur les braises. 'Les armes ne servent a rien ici. Mais les amulettes...'",
			"speaker": "Cadogan",
			"type": "npc_encounter",
			"biome": "villages_celtes",
			"options": [
				{"direction": "left", "label": "Acheter une amulette", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 10}, {"type": "ADD_BIOME_CURRENCY", "amount": -4}
				], "preview": "+Anciens / -4 Monnaie"},
				{"direction": "center", "label": "Apprendre a forger", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}, {"type": "DAMAGE_LIFE", "amount": 2}
				], "preview": "+Anciens / -Vie"},
				{"direction": "right", "label": "Vendre des metaux", "effects": [
					{"type": "ADD_BIOME_CURRENCY", "amount": 8}
				], "preview": "+8 Monnaie"},
			],
			"tags": ["npc", "merchant", "villages", "cadogan"]
		},
		{
			"id": "npc_brennos_merchant",
			"text": "Brennos medite entre deux menhirs. 'Le savoir des pierres se negocie en silence, pas en or.'",
			"speaker": "Brennos",
			"type": "npc_encounter",
			"biome": "cercles_pierres",
			"options": [
				{"direction": "left", "label": "Offrir du silence", "effects": [
					{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}, {"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}
				], "preview": "+Druides +Ankou"},
				{"direction": "center", "label": "Partager un secret", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 10}
				], "preview": "+Anciens"},
				{"direction": "right", "label": "Demander une rune", "effects": [
					{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_BIOME_CURRENCY", "amount": -2}
				], "preview": "+Vie / -2 Monnaie"},
			],
			"tags": ["npc", "merchant", "cercles", "brennos"]
		},
		{
			"id": "npc_gwen_du_merchant",
			"text": "Gwen Du emerge d'un tertre, les mains pleines de champignons lumineux. 'Gouter, c'est risquer. Mais quel profit !'",
			"speaker": "Gwen Du",
			"type": "npc_encounter",
			"biome": "marais_korrigans",
			"options": [
				{"direction": "left", "label": "Gouter un champignon", "effects": [
					{"type": "HEAL_LIFE", "amount": 15}, {"type": "DAMAGE_LIFE", "amount": 5}
				], "preview": "Net +10 Vie (risque)"},
				{"direction": "center", "label": "Troquer des herbes", "effects": [
					{"type": "ADD_BIOME_CURRENCY", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 5}
				], "preview": "+Monnaie +Korrigans"},
				{"direction": "right", "label": "Refuser poliment", "effects": [
					{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 3}
				], "preview": "+Niamh"},
			],
			"tags": ["npc", "merchant", "marais", "gwen_du"]
		},
		{
			"id": "npc_ildiko_merchant",
			"text": "Ildiko grave des os dans sa caverne. 'Les morts parlent, si tu paies le prix.'",
			"speaker": "Ildiko",
			"type": "npc_encounter",
			"biome": "collines_dolmens",
			"options": [
				{"direction": "left", "label": "Consulter les os", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 10}, {"type": "DAMAGE_LIFE", "amount": 3}
				], "preview": "+Ankou / -Vie"},
				{"direction": "center", "label": "Acheter un os grave", "effects": [
					{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}, {"type": "ADD_BIOME_CURRENCY", "amount": -3}
				], "preview": "+Anciens / -3 Monnaie"},
				{"direction": "right", "label": "Offrir un souvenir", "effects": [
					{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "niamh", "amount": 3}
				], "preview": "+Ankou +Niamh"},
			],
			"tags": ["npc", "merchant", "collines", "ildiko"]
		},
		{
			"id": "npc_morgane_merchant",
			"text": "Morgane apparait dans un halo brumeux. 'Les brumes d'Avalon s'ouvrent pour ceux qui osent rever.'",
			"speaker": "Morgane",
			"type": "npc_encounter",
			"biome": "iles_mystiques",
			"options": [
				{"direction": "left", "label": "Rever avec elle", "effects": [
					{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 12}, {"type": "DAMAGE_LIFE", "amount": 3}
				], "preview": "+Niamh / -Vie"},
				{"direction": "center", "label": "Demander passage vers Avalon", "effects": [
					{"type": "ADD_REPUTATION", "faction": "niamh", "amount": 8}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}
				], "preview": "+Niamh +Druides"},
				{"direction": "right", "label": "Echanger une vision", "effects": [
					{"type": "HEAL_LIFE", "amount": 8}, {"type": "ADD_BIOME_CURRENCY", "amount": -2}
				], "preview": "+Vie / -2 Monnaie"},
			],
			"tags": ["npc", "merchant", "iles", "morgane"]
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


func get_npc_card() -> Dictionary:
	## Retourne une carte PNJ aleatoire du pool npc_encounter.
	var pool: Array = cards_by_context.get("npc_encounter", [])
	if pool.is_empty():
		return {}
	var filtered := pool.filter(func(c): return c.get("id", "") not in recently_used)
	if filtered.is_empty():
		filtered = pool
	var selected: Dictionary = filtered[randi() % filtered.size()]
	recently_used.append(selected.get("id", ""))
	if recently_used.size() > RECENT_LIMIT:
		recently_used.pop_front()
	return selected


func get_pool_sizes() -> Dictionary:
	## Retourne la taille de chaque pool.
	var sizes := {}
	for context in cards_by_context:
		sizes[context] = cards_by_context[context].size()
	return sizes
