## ═══════════════════════════════════════════════════════════════════════════════
## M.E.R.L.I.N. — Version 7.0 - GameManager
## ═══════════════════════════════════════════════════════════════════════════════
## Autoload singleton managing game state, saves, and progression
## @author MaxCorp Interactive
## @version 7.0.0
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal game_state_changed(new_phase: String)
signal gold_changed(new_amount: int)
@warning_ignore("unused_signal")
signal transition_requested(transition_type: String, data: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# TYPES SYSTEM (14 types)
# ═══════════════════════════════════════════════════════════════════════════════

const TYPES := {
	"nature": {
		"name": "Nature", "icon": "🌿",
		"color": "grass", "color_light": "grass_light", "color_dark": "grass_dark",
		"strong": ["eau", "terre", "lumiere"],
		"weak": ["feu", "poison", "glace"],
		"resist": ["terre", "eau"],
		"immune": [],
		"status": {"name": "Enraciné", "effect": "heal_over_time"},
		"unlock_floor": 0
	},
	"feu": {
		"name": "Feu", "icon": "🔥",
		"color": "fire", "color_light": "fire_light", "color_dark": "fire_dark",
		"strong": ["nature", "glace", "bete"],
		"weak": ["eau", "terre", "air"],
		"resist": ["glace", "ombre"],
		"immune": [],
		"status": {"name": "Brûlure", "effect": "damage_over_time"},
		"unlock_floor": 0
	},
	"eau": {
		"name": "Eau", "icon": "💧",
		"color": "water", "color_light": "water_light", "color_dark": "water_dark",
		"strong": ["feu", "terre", "metal"],
		"weak": ["nature", "foudre", "poison"],
		"resist": ["feu", "air"],
		"immune": [],
		"status": {"name": "Trempé", "effect": "defense_down"},
		"unlock_floor": 0
	},
	"terre": {
		"name": "Terre", "icon": "🪨",
		"color": "earth", "color_light": "earth_light", "color_dark": "earth_dark",
		"strong": ["foudre", "feu", "poison"],
		"weak": ["eau", "nature", "air"],
		"resist": ["foudre", "poison"],
		"immune": ["foudre"],
		"status": {"name": "Enseveli", "effect": "speed_down"},
		"unlock_floor": 2
	},
	"air": {
		"name": "Air", "icon": "💨",
		"color": "light_gray", "color_light": "white", "color_dark": "gray",
		"strong": ["nature", "poison", "esprit"],
		"weak": ["foudre", "glace", "metal"],
		"resist": ["nature", "ombre"],
		"immune": [],
		"status": {"name": "Balayé", "effect": "accuracy_down"},
		"unlock_floor": 2
	},
	"foudre": {
		"name": "Foudre", "icon": "⚡",
		"color": "thunder", "color_light": "thunder_light", "color_dark": "thunder_dark",
		"strong": ["eau", "air", "esprit"],
		"weak": ["terre", "metal", "arcane"],
		"resist": ["air", "esprit"],
		"immune": [],
		"status": {"name": "Paralysie", "effect": "skip_turn_chance"},
		"unlock_floor": 3
	},
	"glace": {
		"name": "Glace", "icon": "❄️",
		"color": "ice", "color_light": "ice_light", "color_dark": "ice_dark",
		"strong": ["air", "nature", "terre"],
		"weak": ["feu", "metal", "ombre"],
		"resist": ["eau", "air"],
		"immune": [],
		"status": {"name": "Gel", "effect": "frozen"},
		"unlock_floor": 3
	},
	"poison": {
		"name": "Poison", "icon": "☠️",
		"color": "poison", "color_light": "poison_light", "color_dark": "poison_dark",
		"strong": ["nature", "bete", "lumiere"],
		"weak": ["terre", "metal", "esprit"],
		"resist": ["nature", "poison"],
		"immune": [],
		"status": {"name": "Empoisonné", "effect": "damage_over_time"},
		"unlock_floor": 4
	},
	"metal": {
		"name": "Métal", "icon": "⚙️",
		"color": "metal", "color_light": "metal_light", "color_dark": "metal_dark",
		"strong": ["foudre", "poison", "ombre"],
		"weak": ["feu", "eau", "arcane"],
		"resist": ["lumiere", "glace"],
		"immune": ["poison"],
		"status": {"name": "Corrodé", "effect": "defense_down"},
		"unlock_floor": 4
	},
	"bete": {
		"name": "Bête", "icon": "🐺",
		"color": "earth_dark", "color_light": "earth", "color_dark": "black",
		"strong": ["esprit", "lumiere", "arcane"],
		"weak": ["feu", "poison", "ombre"],
		"resist": ["terre", "nature"],
		"immune": [],
		"status": {"name": "Sauvagerie", "effect": "attack_up_defense_down"},
		"unlock_floor": 5
	},
	"esprit": {
		"name": "Esprit", "icon": "👻",
		"color": "mystic_light", "color_light": "white", "color_dark": "mystic",
		"strong": ["ombre", "arcane", "poison"],
		"weak": ["lumiere", "foudre", "bete"],
		"resist": ["air", "eau"],
		"immune": ["terre"],
		"status": {"name": "Possession", "effect": "confusion"},
		"unlock_floor": 5
	},
	"ombre": {
		"name": "Ombre", "icon": "🌑",
		"color": "shadow", "color_light": "shadow_light", "color_dark": "shadow_dark",
		"strong": ["lumiere", "esprit", "glace"],
		"weak": ["metal", "feu", "arcane"],
		"resist": ["poison", "air"],
		"immune": ["lumiere"],
		"status": {"name": "Terreur", "effect": "flee_chance"},
		"unlock_floor": 6
	},
	"lumiere": {
		"name": "Lumière", "icon": "✨",
		"color": "light", "color_light": "light_light", "color_dark": "light_dark",
		"strong": ["ombre", "esprit", "metal"],
		"weak": ["poison", "nature", "bete"],
		"resist": ["ombre", "arcane"],
		"immune": ["esprit"],
		"status": {"name": "Aveuglement", "effect": "accuracy_down"},
		"unlock_floor": 6
	},
	"arcane": {
		"name": "Arcane", "icon": "🔮",
		"color": "mystic", "color_light": "mystic_light", "color_dark": "mystic_dark",
		"strong": ["metal", "foudre", "ombre"],
		"weak": ["bete", "esprit", "lumiere"],
		"resist": ["arcane", "feu"],
		"immune": [],
		"status": {"name": "Surcharge", "effect": "damage_recoil"},
		"unlock_floor": 7
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAMS (Power Words) SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAMS := {
	# Starter Oghams
	"beith": {
		"name": "Beith",
		"meaning": "Bouleau - Nouveau Départ",
		"type": "nature",
		"power": 15,
		"accuracy": 95,
		"effect": null,
		"description": "Un souffle de vie primitive."
	},
	"luis": {
		"name": "Luis",
		"meaning": "Sorbier - Protection",
		"type": "nature",
		"power": 0,
		"accuracy": 100,
		"effect": {"type": "defense_up", "value": 2},
		"description": "Bouclier des anciens druides."
	},
	"saille": {
		"name": "Saille",
		"meaning": "Saule - Eau Vive",
		"type": "eau",
		"power": 18,
		"accuracy": 90,
		"effect": null,
		"description": "L'eau qui coule, l'eau qui frappe."
	},
	"nuin": {
		"name": "Nuin",
		"meaning": "Frêne - Connexion",
		"type": "arcane",
		"power": 20,
		"accuracy": 85,
		"effect": {"type": "drain", "value": 0.25},
		"description": "L'arbre monde qui lie tout."
	},
	"huath": {
		"name": "Huath",
		"meaning": "Aubépine - Terreur",
		"type": "ombre",
		"power": 12,
		"accuracy": 100,
		"effect": {"type": "fear", "chance": 0.3},
		"description": "Les épines qui glacent le sang."
	},
	"duir": {
		"name": "Duir",
		"meaning": "Chêne - Force",
		"type": "terre",
		"power": 25,
		"accuracy": 80,
		"effect": null,
		"description": "La puissance immuable du chêne."
	},
	"tinne": {
		"name": "Tinne",
		"meaning": "Houx - Feu Sacré",
		"type": "feu",
		"power": 22,
		"accuracy": 85,
		"effect": {"type": "burn", "chance": 0.2},
		"description": "Flammes de la forge divine."
	},
	"coll": {
		"name": "Coll",
		"meaning": "Noisetier - Sagesse",
		"type": "esprit",
		"power": 15,
		"accuracy": 95,
		"effect": {"type": "accuracy_up", "value": 1},
		"description": "La noix de connaissance."
	},
	"quert": {
		"name": "Quert",
		"meaning": "Pommier - Guérison",
		"type": "lumiere",
		"power": 0,
		"accuracy": 100,
		"effect": {"type": "heal", "value": 25},
		"description": "Le fruit de l'immortalité."
	},
	"muin": {
		"name": "Muin",
		"meaning": "Vigne - Ivresse",
		"type": "poison",
		"power": 18,
		"accuracy": 90,
		"effect": {"type": "confusion", "chance": 0.25},
		"description": "L'enivrement des sens."
	},
	"gort": {
		"name": "Gort",
		"meaning": "Lierre - Étreinte",
		"type": "nature",
		"power": 10,
		"accuracy": 95,
		"effect": {"type": "bind", "turns": 2},
		"description": "Les liens qui étouffent."
	},
	"straif": {
		"name": "Straif",
		"meaning": "Prunellier - Ténèbres",
		"type": "ombre",
		"power": 28,
		"accuracy": 75,
		"effect": {"type": "curse", "value": 5},
		"description": "L'épine maudite."
	},
	"ruis": {
		"name": "Ruis",
		"meaning": "Sureau - Mort et Renaissance",
		"type": "esprit",
		"power": 20,
		"accuracy": 85,
		"effect": {"type": "life_steal", "value": 0.3},
		"description": "Le cycle éternel."
	},
	"ailm": {
		"name": "Ailm",
		"meaning": "Sapin - Vision Claire",
		"type": "air",
		"power": 16,
		"accuracy": 100,
		"effect": null,
		"description": "L'air pur des sommets."
	},
	"onn": {
		"name": "Onn",
		"meaning": "Ajonc - Lumière Solaire",
		"type": "lumiere",
		"power": 24,
		"accuracy": 85,
		"effect": {"type": "blind", "chance": 0.2},
		"description": "L'or du soleil incarné."
	},
	"ur": {
		"name": "Ur",
		"meaning": "Bruyère - Passion",
		"type": "feu",
		"power": 30,
		"accuracy": 70,
		"effect": {"type": "recoil", "value": 0.1},
		"description": "Le feu qui consume tout."
	},
	"eadhadh": {
		"name": "Eadhadh",
		"meaning": "Tremble - Vent",
		"type": "air",
		"power": 14,
		"accuracy": 95,
		"effect": {"type": "speed_up", "value": 1},
		"description": "Le frisson du vent."
	},
	"ioho": {
		"name": "Ioho",
		"meaning": "If - Éternité",
		"type": "arcane",
		"power": 35,
		"accuracy": 65,
		"effect": {"type": "instant_death", "chance": 0.05},
		"description": "L'arbre entre les mondes."
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENEMIES DATA
# ═══════════════════════════════════════════════════════════════════════════════

const ENEMIES := {
	"korigan": {"name": "Korigan", "type": "terre", "hp": 35, "atk": 10, "def": 5, "gold": 20, "xp": 15},
	"spectre": {"name": "Spectre", "type": "esprit", "hp": 45, "atk": 14, "def": 3, "gold": 30, "xp": 25},
	"loup": {"name": "Loup Noir", "type": "ombre", "hp": 70, "atk": 18, "def": 8, "gold": 50, "xp": 40},
	"feu_follet": {"name": "Feu Follet", "type": "feu", "hp": 30, "atk": 16, "def": 2, "gold": 25, "xp": 20},
	"ondine": {"name": "Ondine", "type": "eau", "hp": 55, "atk": 12, "def": 10, "gold": 35, "xp": 30},
	"golem": {"name": "Golem", "type": "metal", "hp": 90, "atk": 15, "def": 15, "gold": 60, "xp": 50},
	"druide": {"name": "Druide Noir", "type": "arcane", "hp": 120, "atk": 25, "def": 12, "gold": 150, "xp": 100},
	"banshee": {"name": "Banshee", "type": "ombre", "hp": 100, "atk": 22, "def": 6, "gold": 80, "xp": 70},
}

# ═══════════════════════════════════════════════════════════════════════════════
# GAME STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_phase: String = "title"
var save_version: String = "7.0"

# Run state
var run := {
	"active": false,
	"gold": 100,
	"provisions": 3,
	"incense": 1,
	"floor": 0,
	"max_floor_reached": 0,
	"current_node": null,
	"map_seed": 0,
	"path_taken": [],
	"combats_won": 0,
	"map": [],
	"chronicle_name": "",
	"traveler_profile": {
		"verb_affinity": {"FORCE": 0, "LOGIQUE": 0, "FINESSE": 0},
		"traits": {
			"courage": 0,
			"curiosite": 0,
			"compassion": 0,
			"orgueil": 0,
			"verite": 0,
			"controle": 0,
		},
		"hooks": [],
		"answers": [],
	},
	"merlin_memory": [],
}

# Meta progression
var meta := {
	"total_runs": 0,
	"total_victories": 0,
	"unlocked_types": ["nature", "feu", "eau"],
	"unlocked_oghams": ["beith", "luis", "saille"],
	"unlocked_evolutions": [],
}

# Flags
var flags := {
	"intro_seen": false,
	"tutorial_done": false,
	"hub_tour_pending": false,
	"hub_tour_done": false,
	"events_encountered": [],
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRNG (Mulberry32)
# ═══════════════════════════════════════════════════════════════════════════════

var _prng_state: int = 0

func set_seed(seed_value: int) -> void:
	_prng_state = seed_value

func random() -> float:
	_prng_state = (_prng_state + 0x6D2B79F5) & 0x7FFFFFFF
	var t: int = _prng_state
	t = (t ^ (t >> 15)) * (1 | _prng_state)
	t = (t + ((t ^ (t >> 7)) * (61 | t))) ^ t
	return float((t ^ (t >> 14)) & 0x7FFFFFFF) / float(0x7FFFFFFF)

func random_int(min_val: int, max_val: int) -> int:
	return min_val + int(random() * (max_val - min_val + 1))

# ═══════════════════════════════════════════════════════════════════════════════
# TYPE SYSTEM HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_type_multiplier(attack_type: String, defense_type: String) -> float:
	if not TYPES.has(attack_type) or not TYPES.has(defense_type):
		return 1.0
	
	var atk_data: Dictionary = TYPES[attack_type]
	var def_data: Dictionary = TYPES[defense_type]
	
	if def_data.immune.has(attack_type):
		return 0.0
	if atk_data.strong.has(defense_type):
		return 2.0
	if def_data.resist.has(attack_type):
		return 0.5
	if atk_data.weak.has(defense_type):
		return 0.5
	return 1.0

func get_type_color(type_name: String) -> Color:
	if not TYPES.has(type_name):
		return MerlinVisual.GBC.gray
	return MerlinVisual.GBC[TYPES[type_name].color]

func is_type_unlocked(type_name: String) -> bool:
	return meta.unlocked_types.has(type_name)

func unlock_type(type_name: String) -> void:
	if not meta.unlocked_types.has(type_name):
		meta.unlocked_types.append(type_name)
		emit_signal("game_state_changed", "type_unlocked")

# ═══════════════════════════════════════════════════════════════════════════════
# GAME STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func change_phase(new_phase: String) -> void:
	current_phase = new_phase
	emit_signal("game_state_changed", new_phase)

func start_new_game() -> void:
	start_run()

func start_run() -> void:
	run.active = true
	run.gold = 100
	run.provisions = 3
	run.incense = 1
	run.floor = 0
	run.current_node = null
	run.map_seed = int(Time.get_unix_time_from_system())
	run.path_taken = []
	run.combats_won = 0
	set_seed(run.map_seed)
	run.map = generate_map(8)
	run.chronicle_name = ""
	run.traveler_profile = {
		"verb_affinity": {"FORCE": 0, "LOGIQUE": 0, "FINESSE": 0},
		"traits": {
			"courage": 0,
			"curiosite": 0,
			"compassion": 0,
			"orgueil": 0,
			"verite": 0,
			"controle": 0,
		},
		"hooks": [],
		"answers": [],
	}
	run.merlin_memory = []

	emit_signal("game_state_changed", "run_started")

func end_run(victory: bool) -> void:
	run.active = false
	meta.total_runs += 1
	if victory:
		meta.total_victories += 1
	
	# Check for type unlocks based on floor reached
	for type_name in TYPES:
		var unlock_floor: int = TYPES[type_name].unlock_floor
		if run.max_floor_reached >= unlock_floor and not is_type_unlocked(type_name):
			unlock_type(type_name)
	
	emit_signal("game_state_changed", "run_ended")

# ═══════════════════════════════════════════════════════════════════════════════
# MAP GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func generate_map(floors: int) -> Array:
	var map: Array = []
	
	for floor_idx in range(floors):
		var node_count: int
		if floor_idx == 0:
			node_count = 1
		elif floor_idx == floors - 1:
			node_count = 1
		else:
			node_count = random_int(2, 3)
		
		var floor_nodes: Array = []
		
		for i in range(node_count):
			var node_type: String
			if floor_idx == 0:
				node_type = "event"
			elif floor_idx == floors - 1:
				node_type = "boss"
			elif floor_idx == floori(floors / 2.0):
				node_type = "rest" if random() > 0.5 else "shop"
			else:
				var roll: float = random()
				if roll < 0.40:
					node_type = "combat"
				elif roll < 0.50:
					node_type = "elite"
				elif roll < 0.60:
					node_type = "shop"
				elif roll < 0.70:
					node_type = "rest"
				else:
					node_type = "event"
			
			var x_pos: float = 50.0 if node_count == 1 else 20.0 + (60.0 / float(node_count - 1)) * float(i)
			
			floor_nodes.append({
				"id": "%d-%d" % [floor_idx, i],
				"floor": floor_idx,
				"index": i,
				"type": node_type,
				"connections": [],
				"x": x_pos,
			})
		
		# Connect to previous floor
		if floor_idx > 0:
			var prev_floor: Array = map[floor_idx - 1]
			for node in floor_nodes:
				for prev_node in prev_floor:
					if random() > 0.3 or prev_floor.size() == 1:
						prev_node.connections.append(node.id)
			
			# Ensure all nodes have at least one connection
			for prev_node in prev_floor:
				if prev_node.connections.is_empty():
					prev_node.connections.append(floor_nodes[0].id)
		
		map.append(floor_nodes)
	
	return map

func add_gold(amount: int) -> void:
	run.gold += amount
	emit_signal("gold_changed", run.gold)

func spend_gold(amount: int) -> bool:
	if run.gold >= amount:
		run.gold -= amount
		emit_signal("gold_changed", run.gold)
		return true
	return false

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE/LOAD SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func save_to_slot(slot: int) -> bool:
	var save_data := {
		"version": save_version,
		"run": run.duplicate(true),
		"meta": meta.duplicate(true),
		"flags": flags.duplicate(true),
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	
	var json_string: String = JSON.stringify(save_data)
	var file := FileAccess.open("user://save_slot_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		return true
	return false

func load_from_slot(slot: int) -> bool:
	var file := FileAccess.open("user://save_slot_%d.json" % slot, FileAccess.READ)
	if not file:
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		return false
	
	var save_data: Dictionary = json.data
	
	run = save_data.run
	meta = save_data.meta
	flags = save_data.flags

	emit_signal("gold_changed", run.gold)
	return true

func get_save_slot_info(slot: int) -> Dictionary:
	var file := FileAccess.open("user://save_slot_%d.json" % slot, FileAccess.READ)
	if not file:
		return {}
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		return {}
	
	var save_data: Dictionary = json.data
	var run: Dictionary = save_data.get("run", {})
	return {
		"biome": run.get("biome", "foret_broceliande"),
		"life_essence": run.get("life_essence", 0),
		"card_index": run.get("card_index", 0),
		"chronicle_name": run.get("chronicle_name", ""),
		"timestamp": save_data.get("timestamp", ""),
	}

func delete_save_slot(slot: int) -> void:
	DirAccess.remove_absolute("user://save_slot_%d.json" % slot)

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Register MerlinStore as root singleton (class_name prevents autoload registration)
	if not get_node_or_null("/root/MerlinStore"):
		var store := MerlinStore.new()
		store.name = "MerlinStore"
		get_tree().root.call_deferred("add_child", store)

