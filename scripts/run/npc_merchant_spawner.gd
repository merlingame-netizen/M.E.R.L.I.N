extends Node
class_name NpcMerchantSpawner
## NPC merchant spawn system for 3D biome walks.
## Manages 4 recurring merchant NPCs with biome affinity, pricing, and card generation.

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal merchant_spawned(npc_name: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const MIN_CARDS_BEFORE_MERCHANT: int = 3
const SPAWN_INTERVAL_MIN: int = 5
const SPAWN_INTERVAL_MAX: int = 8

const NPC_ROSTER: Dictionary = {
	"gwenn": {
		"name": "Gwenn",
		"faction": "druides",
		"price_modifier": 0.7,
		"biome_affinity": ["foret_broceliande", "grotte_merlin"],
		"description": "Druidesse herboriste aux prix doux, gardienne des secrets vegetaux.",
	},
	"puck": {
		"name": "Puck",
		"faction": "korrigans",
		"price_modifier": 1.4,
		"biome_affinity": ["landes_bruyere", "marais_korrigans"],
		"description": "Korrigan farceur aux marchandises rares mais couteuses.",
	},
	"bran": {
		"name": "Bran",
		"faction": "anciens",
		"price_modifier": 1.0,
		"biome_affinity": ["collines_dolmens", "cercles_pierres"],
		"description": "Guerrier erudit, marchand de reliques a prix juste.",
	},
	"seren": {
		"name": "Seren",
		"faction": "niamh",
		"price_modifier": 1.2,
		"biome_affinity": ["iles_mystiques", "cotes_sauvages"],
		"description": "Navigatrice des etoiles, vendeuse d'objets mystiques.",
	},
}

# Card text templates per NPC
const _CARD_TEXTS: Dictionary = {
	"gwenn": "Gwenn emerge du sous-bois, sa besace debordant d'herbes rares. Elle vous salue d'un sourire.",
	"puck": "Puck surgit d'un buisson en ricanant, deployant un tapis de babioles scintillantes.",
	"bran": "Bran s'appuie sur sa lance, sa sacoche de reliques posee a ses pieds. Il vous jauge du regard.",
	"seren": "Seren leve les yeux de sa carte celeste et vous tend un coffret nacre.",
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _next_spawn_card: int = -1

# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════


## Returns NPCs whose biome_affinity includes the given biome (1-2 per biome).
func get_npcs_for_biome(biome: String) -> Array:
	var result: Array = []
	for npc_key: String in NPC_ROSTER:
		var npc: Dictionary = NPC_ROSTER[npc_key]
		var affinity: Array = npc.get("biome_affinity", [])
		if affinity.has(biome):
			result.append(npc_key)
	return result


## Determines whether a merchant should spawn at this card count.
## Merchants never appear in the first 3 cards and respawn every 5-8 cards.
func should_spawn_merchant(cards_played: int, last_merchant_card: int) -> bool:
	if cards_played < MIN_CARDS_BEFORE_MERCHANT:
		return false

	# Initialize spawn target on first call or after a merchant appeared
	if _next_spawn_card < 0 or last_merchant_card >= _next_spawn_card:
		var base: int = maxi(last_merchant_card, MIN_CARDS_BEFORE_MERCHANT)
		_next_spawn_card = base + _rand_interval()

	return cards_played >= _next_spawn_card


## Builds a merchant card dictionary with 3 options: buy, trade, decline.
func get_merchant_card(npc_name: String, biome: String) -> Dictionary:
	if not NPC_ROSTER.has(npc_name):
		return {}

	var npc: Dictionary = NPC_ROSTER[npc_name]
	var faction: String = str(npc.get("faction", "druides"))
	var text: String = _CARD_TEXTS.get(npc_name, "Un marchand vous aborde.")
	var base_cost: int = 10

	var card: Dictionary = {
		"text": text,
		"type": "merchant",
		"npc": npc_name,
		"biome": biome,
		"options": [
			{
				"label": "Acheter (%d)" % apply_price_modifier(base_cost, npc_name),
				"verb": "acheter",
				"effects": [
					{"type": "HEAL_LIFE", "amount": 8},
					{"type": "ADD_REPUTATION", "faction": faction, "amount": 5},
				],
			},
			{
				"label": "Troquer (reputation)",
				"verb": "troquer",
				"effects": [
					{"type": "ADD_REPUTATION", "faction": faction, "amount": -10},
					{"type": "HEAL_LIFE", "amount": 15},
				],
			},
			{
				"label": "Decliner poliment",
				"verb": "refuser",
				"effects": [
					{"type": "ADD_REPUTATION", "faction": faction, "amount": 2},
				],
			},
		],
	}

	merchant_spawned.emit(npc_name)
	return card


## Applies NPC-specific price modifier to a base cost, returns integer result.
func apply_price_modifier(base_cost: int, npc_name: String) -> int:
	if not NPC_ROSTER.has(npc_name):
		return base_cost
	var modifier: float = float(NPC_ROSTER[npc_name].get("price_modifier", 1.0))
	return maxi(1, int(float(base_cost) * modifier))


## Picks a random NPC for the given biome (from those with affinity).
## Falls back to a random NPC if none have affinity.
func pick_merchant_for_biome(biome: String) -> String:
	var candidates: Array = get_npcs_for_biome(biome)
	if candidates.is_empty():
		var all_keys: Array = NPC_ROSTER.keys()
		return str(all_keys[randi() % all_keys.size()])
	return str(candidates[randi() % candidates.size()])


## Resets internal spawn tracking (call at run start).
func reset() -> void:
	_next_spawn_card = -1

# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE
# ═══════════════════════════════════════════════════════════════════════════════


func _rand_interval() -> int:
	return SPAWN_INTERVAL_MIN + (randi() % (SPAWN_INTERVAL_MAX - SPAWN_INTERVAL_MIN + 1))
