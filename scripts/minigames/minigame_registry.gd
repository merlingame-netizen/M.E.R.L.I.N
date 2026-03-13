## MiniGameRegistry — Selects mini-games by lexical field keywords (Phase 33)
## Maps narrative text keywords to appropriate mini-game types.
## Usage: MiniGameRegistry.select(narrative_text, gm_hint) -> MiniGameBase

class_name MiniGameRegistry extends RefCounted

# Lexical field keyword mappings
const FIELDS := {
	"chance": ["chance", "destin", "sort", "fortune", "hasard", "tirage", "de", "etoile"],
	"bluff": ["parler", "negocier", "convaincre", "mentir", "persuader", "discuter", "diplomate", "bluff", "ruse"],
	"observation": ["observer", "guetter", "voir", "chercher", "scruter", "regarder", "epier", "decouvrir", "cache"],
	"logique": ["penser", "resoudre", "comprendre", "enigme", "deduire", "puzzle", "noeud", "rune", "symbole"],
	"finesse": ["esquiver", "attraper", "lancer", "viser", "combattre", "frapper", "courir", "sauter", "reflexe"],
	"vigueur": ["force", "endurance", "puissance", "resistance", "muscle", "soulever", "pousser", "tenir", "effort"],
	"esprit": ["volonte", "mental", "concentration", "mediter", "calme", "serenite", "focus", "respirer", "esprit"],
	"perception": ["sentir", "entendre", "percevoir", "instinct", "flair", "ombre", "echo", "memoire", "sens"],
}

# Mini-game scenes per field
const GAMES := {
	"chance": ["mg_de_du_destin", "mg_pile_ou_face", "mg_roue_fortune"],
	"bluff": ["mg_joute_verbale", "mg_bluff_druide", "mg_negociation"],
	"observation": ["mg_oeil_corbeau", "mg_trace_cerf", "mg_rune_cachee"],
	"logique": ["mg_enigme_ogham", "mg_noeud_celtique", "mg_pierre_feuille_racine"],
	"finesse": ["mg_tir_a_larc", "mg_lame_druide", "mg_pas_renard"],
	"vigueur": ["mg_combat_rituel", "mg_sang_froid", "mg_course"],
	"esprit": ["mg_volonte", "mg_apaisement", "mg_meditation"],
	"perception": ["mg_ombres", "mg_regard", "mg_echo"],
}

# Ogham category -> field bonus mapping
const OGHAM_FIELD_BONUS := {
	"reveal": "observation",
	"protection": "logique",
	"boost": "finesse",
	"narrative": "bluff",
	"recovery": "chance",
	"combat": "vigueur",
	"focus": "esprit",
	"sense": "perception",
}


## Select the best mini-game field from narrative text
## Tag-to-field mapping for contextual mini-game selection
const TAG_FIELD_MAP := {
	"combat": "finesse",
	"danger": "finesse",
	"stranger": "bluff",
	"social": "bluff",
	"npc": "bluff",
	"mystery": "logique",
	"magic": "logique",
	"lore": "logique",
	"exploration": "observation",
	"nature": "observation",
	"choice": "chance",
	"merchant": "bluff",
	"trade": "bluff",
	"recovery": "chance",
	"balance": "logique",
	"strength": "vigueur",
	"physical": "vigueur",
	"endurance": "vigueur",
	"willpower": "esprit",
	"meditation": "esprit",
	"spirit": "esprit",
	"stealth": "perception",
	"tracking": "perception",
	"senses": "perception",
}


static func detect_field(narrative_text: String, gm_hint: String = "", tags: Array = []) -> String:
	# GM hint takes priority
	if gm_hint != "" and FIELDS.has(gm_hint):
		return gm_hint

	# Tag-based detection (higher priority than keyword)
	for tag in tags:
		var tag_str: String = str(tag).to_lower()
		if TAG_FIELD_MAP.has(tag_str):
			return TAG_FIELD_MAP[tag_str]

	# Keyword matching in narrative text
	var lower := narrative_text.to_lower()
	var scores := {"chance": 0, "bluff": 0, "observation": 0, "logique": 0, "finesse": 0, "vigueur": 0, "esprit": 0, "perception": 0}
	for field in FIELDS:
		for keyword in FIELDS[field]:
			if lower.find(keyword) >= 0:
				scores[field] += 1

	# Find highest scoring field
	var best_field := "chance"  # Default
	var best_score: int = 0
	for field in scores:
		if scores[field] > best_score:
			best_score = scores[field]
			best_field = field

	return best_field


## Create a mini-game instance for the given field
static func create_minigame(field: String, difficulty: int = 5, modifiers: Dictionary = {}) -> MiniGameBase:
	if not GAMES.has(field):
		field = "chance"

	var game_list: Array = GAMES[field]
	var game_id: String = game_list[randi() % game_list.size()]

	var game: MiniGameBase = null
	match game_id:
		# Tier 1
		"mg_de_du_destin": game = preload("res://scripts/minigames/mg_de_du_destin.gd").new()
		"mg_pile_ou_face": game = preload("res://scripts/minigames/mg_pile_ou_face.gd").new()
		"mg_pierre_feuille_racine": game = preload("res://scripts/minigames/mg_pierre_feuille_racine.gd").new()
		"mg_tir_a_larc": game = preload("res://scripts/minigames/mg_tir_a_larc.gd").new()
		"mg_joute_verbale": game = preload("res://scripts/minigames/mg_joute_verbale.gd").new()
		# Tier 2
		"mg_roue_fortune": game = preload("res://scripts/minigames/mg_roue_fortune.gd").new()
		"mg_bluff_druide": game = preload("res://scripts/minigames/mg_bluff_druide.gd").new()
		"mg_negociation": game = preload("res://scripts/minigames/mg_negociation.gd").new()
		"mg_oeil_corbeau": game = preload("res://scripts/minigames/mg_oeil_corbeau.gd").new()
		"mg_enigme_ogham": game = preload("res://scripts/minigames/mg_enigme_ogham.gd").new()
		# Tier 3
		"mg_trace_cerf": game = preload("res://scripts/minigames/mg_trace_cerf.gd").new()
		"mg_rune_cachee": game = preload("res://scripts/minigames/mg_rune_cachee.gd").new()
		"mg_noeud_celtique": game = preload("res://scripts/minigames/mg_noeud_celtique.gd").new()
		"mg_lame_druide": game = preload("res://scripts/minigames/mg_lame_druide.gd").new()
		"mg_pas_renard": game = preload("res://scripts/minigames/mg_pas_renard.gd").new()
		# Vigueur
		"mg_combat_rituel": game = preload("res://scripts/minigames/mg_combat_rituel.gd").new()
		"mg_sang_froid": game = preload("res://scripts/minigames/mg_sang_froid.gd").new()
		"mg_course": game = preload("res://scripts/minigames/mg_course.gd").new()
		# Esprit
		"mg_volonte": game = preload("res://scripts/minigames/mg_volonte.gd").new()
		"mg_apaisement": game = preload("res://scripts/minigames/mg_apaisement.gd").new()
		"mg_meditation": game = preload("res://scripts/minigames/mg_meditation.gd").new()
		# Perception
		"mg_ombres": game = preload("res://scripts/minigames/mg_ombres.gd").new()
		"mg_regard": game = preload("res://scripts/minigames/mg_regard.gd").new()
		"mg_echo": game = preload("res://scripts/minigames/mg_echo.gd").new()

	if game == null:
		# Ultimate fallback: De du Destin
		game = preload("res://scripts/minigames/mg_de_du_destin.gd").new()

	game.setup(difficulty, modifiers)
	return game


## Get Ogham score bonus for a field
static func get_ogham_bonus(ogham_category: String, game_field: String) -> int:
	var bonus_field: String = OGHAM_FIELD_BONUS.get(ogham_category, "")
	if bonus_field == game_field:
		return 10  # +10% score bonus for matching field
	if ogham_category == "special":
		return 5   # +5% universal bonus
	return 0
