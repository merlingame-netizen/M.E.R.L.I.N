extends RefCounted
class_name MerlinConstants

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM STARTER SET — 3 Oghams debloques au depart
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_STARTER_SKILLS := ["beith", "luis", "quert"]


# ═══════════════════════════════════════════════════════════════════════════════
# REWARD TYPES — Badge display for card option hover (Phase UX)
# ═══════════════════════════════════════════════════════════════════════════════

const REWARD_TYPES := {
	"vie": {"icon": "\u2764", "label": "Vie", "color_key": "danger"},
	"anam": {"icon": "#", "label": "Anam", "color_key": "amber_bright"},
	"reputation": {"icon": "\u2726", "label": "Reputation", "color_key": "amber_bright"},
	"mystere": {"icon": "?", "label": "Mystere", "color_key": "amber"},
}


## Infers the reward type from an option's effects array.
## Returns one of the REWARD_TYPES keys.
static func infer_reward_type(effects: Array) -> String:
	for e in effects:
		if not (e is Dictionary):
			continue
		var etype: String = str(e.get("type", ""))
		match etype:
			"HEAL_LIFE":
				return "vie"
			"DAMAGE_LIFE":
				return "vie"
			"ADD_REPUTATION":
				return "reputation"
			"ADD_ANAM":
				return "anam"
	return "mystere"



# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME CATALOGUE — Epreuves detectees par mots-cles dans le texte narratif
# ═══════════════════════════════════════════════════════════════════════════════

const MINIGAME_CATALOGUE := {
	"traces": {"name": "Traces", "desc": "Suivre une sequence d'empreintes sans sortir du chemin", "trigger": "piste|trace|empreinte|pas|sentier"},
	"runes": {"name": "Runes", "desc": "Dechiffrer un ogham cache dans la pierre", "trigger": "rune|ogham|symbole|gravure|inscription"},
	"equilibre": {"name": "Equilibre", "desc": "Maintenir l'equilibre sur un passage instable", "trigger": "pont|equilibre|vertige|gouffre|precipice"},
	"herboristerie": {"name": "Herboristerie", "desc": "Identifier la bonne plante parmi les toxiques", "trigger": "plante|herbe|champignon|racine|cueillir|potion"},
	"negociation": {"name": "Negociation", "desc": "Convaincre un esprit par les mots justes", "trigger": "esprit|fae|parler|negocier|korrigan|convaincre|marchander"},
	"combat_rituel": {"name": "Combat Rituel", "desc": "Esquiver dans un cercle sacre", "trigger": "combat|defi|guerrier|lame|epee|duel"},
	"apaisement": {"name": "Apaisement", "desc": "Calmer un gardien par le rythme et la respiration", "trigger": "apaiser|calmer|respir|gardien|rage|colere"},
	"sang_froid": {"name": "Sang-froid", "desc": "Maintenir le curseur stable malgre les pulsations", "trigger": "piege|danger|froid|sang|approcher|appat"},
	"course": {"name": "Course", "desc": "QTE pour maintenir la poursuite ou fuir", "trigger": "courir|pourchasser|fuir|sprint|trouee|course"},
	"fouille": {"name": "Fouille", "desc": "Trouver l'indice cache en temps limite", "trigger": "fouille|chercher|indice|recueillir|ruban|preuve"},
	"ombres": {"name": "Ombres", "desc": "Se deplacer entre couvertures sans etre vu", "trigger": "cacher|ombre|discret|invisible|embuscade"},
	"volonte": {"name": "Volonte", "desc": "Tenir le focus malgre les murmures et le doute", "trigger": "douter|murmure|resister|volonte|doute|hesiter"},
	"regard": {"name": "Regard", "desc": "Memoriser puis reproduire une sequence de formes", "trigger": "vision|forme|memoriser|fixer|apparition|spectr"},
	"echo": {"name": "Echo", "desc": "Suivre l'intensite sonore vers la bonne direction", "trigger": "voix|appel|son|echo|ecouter|cri|chant"},
}

# Card options (3 per card)
enum CardOption { LEFT = 0, CENTER = 1, RIGHT = 2 }

# ═══════════════════════════════════════════════════════════════════════════════
# VIE — Barre de vie unique (Phase 43)
# At 0 = premature run end. Drains on critical failures, failed events, etc.
# ═══════════════════════════════════════════════════════════════════════════════

const LIFE_ESSENCE_MAX := 100
const LIFE_ESSENCE_START := 100
const LIFE_ESSENCE_DRAIN_PER_CARD := 1      # Base drain each card (survival pressure)
const MIN_CARDS_FOR_VICTORY := 25           # Victory requires 25+ cards (= MOS target_cards_max). See MOS_CONVERGENCE for full zones.
const LIFE_ESSENCE_CRIT_FAIL_DAMAGE := 10   # Damage on critical failure
const LIFE_ESSENCE_FAIL_DAMAGE := 0         # Normal failure = no life damage
const LIFE_ESSENCE_EVENT_FAIL_DAMAGE := 6   # Failed event/palier
const LIFE_ESSENCE_CRIT_SUCCESS_HEAL := 5   # Heal on critical success
const LIFE_ESSENCE_HEAL_PER_REST := 18      # Heal at REST nodes
const LIFE_ESSENCE_LOW_THRESHOLD := 25      # UI warning threshold

# ═══════════════════════════════════════════════════════════════════════════════
# FAVEURS — Récompenses du mini-jeu de chargement (TransitionBiome)
# Accumulées en jouant pendant la génération de cartes LLM.
# ═══════════════════════════════════════════════════════════════════════════════

const FAVEURS_START := 0
const FAVEURS_PER_MINIGAME_WIN := 3    # Score >= 80
const FAVEURS_PER_MINIGAME_PLAY := 1  # Score < 80

# Minigame difficulty labels for UI display
const MINIGAME_DIFFICULTY_LABELS := {
	"easy": {"label": "Facile", "color": Color(0.35, 0.75, 0.35), "max_score": 40},
	"normal": {"label": "Normal", "color": Color(0.85, 0.75, 0.25), "max_score": 70},
	"hard": {"label": "Difficile", "color": Color(0.85, 0.30, 0.25), "max_score": 100},
}

# Session duration targets
const SESSION_CARDS_MIN := 25
const SESSION_CARDS_MAX := 35
const SESSION_CARDS_TARGET := 30
const SESSION_SECONDS_PER_CARD := 18   # Average decision time
const SESSION_MISSION_REVEAL_CARD := 4 # Mission revealed around card 4

# ═══════════════════════════════════════════════════════════════════════════════
# MISSION TEMPLATES — Hybrid system (template + LLM narrative dressing)
# ═══════════════════════════════════════════════════════════════════════════════

const MISSION_TEMPLATES := {
	"survive": {
		"type": "survive",
		"target_cards": 30,
		"description_template": "Survie dans {biome} — atteins la fin du chemin.",
		"weight": 0.30,
	},
	"equilibre": {
		"type": "equilibre",
		"target_balanced_turns": 8,
		"description_template": "Maintiens l'equilibre — reste centre {target} tours.",
		"weight": 0.20,
	},
	"explore": {
		"type": "explore",
		"target_nodes": 6,
		"description_template": "Explore {biome} — visite {target} lieux differents.",
		"weight": 0.25,
	},
	"artefact": {
		"type": "artefact",
		"target_progress": 5,
		"description_template": "Retrouve l'artefact cache au coeur de {biome}.",
		"weight": 0.25,
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# POWER MILESTONES — Player gets stronger every 5 cards during a run
# ═══════════════════════════════════════════════════════════════════════════════

const POWER_MILESTONES := {
	5: {"type": "HEAL", "value": 15, "label": "Vigueur retrouvee", "desc": "+15 Vie"},
	10: {"type": "MINIGAME_BONUS", "value": 5, "label": "Instinct aiguise", "desc": "+5% minigame"},
	15: {"type": "HEAL", "value": 10, "label": "Souffle du druide", "desc": "+10 Vie"},
	20: {"type": "HEAL", "value": 20, "label": "Benediction ancienne", "desc": "+20 Vie"},
}

# ═══════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM FULL SPECS — Complete Ogham definitions (18 Oghams, hybrid active+narrative)
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_FULL_SPECS := {
	# ── REVEAL ──────────────────────────────────────────────────────────────
	"beith": {
		"name": "Bouleau", "tree": "Betula", "unicode": "\u1681",
		"category": "reveal", "cooldown": 3, "starter": true,
		"cost_anam": 0, "branch": "central", "tier": 0,
		"effect": "reveal_one_option",
		"description": "Revele l'effet complet d'1 option au choix",
		"effect_params": {"target": "single_option"},
	},
	"coll": {
		"name": "Noisetier", "tree": "Corylus", "unicode": "\u1685",
		"category": "reveal", "cooldown": 5, "starter": false,
		"cost_anam": 80, "branch": "druides", "tier": 1,
		"effect": "reveal_all_options",
		"description": "Revele les effets de toutes les options",
		"effect_params": {"target": "all_options"},
	},
	"ailm": {
		"name": "Sapin", "tree": "Abies", "unicode": "\u168f",
		"category": "reveal", "cooldown": 4, "starter": false,
		"cost_anam": 60, "branch": "anciens", "tier": 1,
		"effect": "predict_next",
		"description": "Predit le theme + champ lexical de la prochaine carte",
		"effect_params": {"target": "next_card"},
	},
	# ── PROTECTION ──────────────────────────────────────────────────────────
	"luis": {
		"name": "Sorbier", "tree": "Sorbus", "unicode": "\u1682",
		"category": "protection", "cooldown": 4, "starter": true,
		"cost_anam": 0, "branch": "central", "tier": 0,
		"effect": "block_first_negative",
		"description": "Bloque le prochain effet negatif unique (le premier applique)",
		"effect_params": {"count": 1},
	},
	"gort": {
		"name": "Lierre", "tree": "Hedera", "unicode": "\u168c",
		"category": "protection", "cooldown": 6, "starter": false,
		"cost_anam": 100, "branch": "niamh", "tier": 2,
		"effect": "reduce_high_damage",
		"description": "Reduit tout degat > 10 PV a 5 PV (1 instance, ce tour)",
		"effect_params": {"threshold": 10, "reduced_to": 5},
	},
	"eadhadh": {
		"name": "Tremble", "tree": "Populus", "unicode": "\u1690",
		"category": "protection", "cooldown": 8, "starter": false,
		"cost_anam": 150, "branch": "ankou", "tier": 1,
		"effect": "cancel_all_negatives",
		"description": "Annule tous les effets negatifs de la carte courante",
		"effect_params": {},
	},
	# ── BOOST ───────────────────────────────────────────────────────────────
	"duir": {
		"name": "Chene", "tree": "Quercus", "unicode": "\u1687",
		"category": "boost", "cooldown": 4, "starter": false,
		"cost_anam": 70, "branch": "druides", "tier": 2,
		"effect": "heal_immediate",
		"description": "Soin immediat de +12 PV",
		"effect_params": {"amount": 12},
	},
	"tinne": {
		"name": "Houx", "tree": "Ilex", "unicode": "\u1688",
		"category": "boost", "cooldown": 5, "starter": false,
		"cost_anam": 120, "branch": "anciens", "tier": 2,
		"effect": "double_positives",
		"description": "Double les effets positifs de l'option choisie",
		"effect_params": {"multiplier": 2.0},
	},
	"onn": {
		"name": "Ajonc", "tree": "Ulex", "unicode": "\u1689",
		"category": "boost", "cooldown": 7, "starter": false,
		"cost_anam": 90, "branch": "korrigans", "tier": 1,
		"effect": "add_biome_currency",
		"description": "Genere +10 monnaie biome instantanement",
		"effect_params": {"amount": 10},
	},
	# ── NARRATIF ────────────────────────────────────────────────────────────
	"nuin": {
		"name": "Frene", "tree": "Fraxinus", "unicode": "\u1684",
		"category": "narrative", "cooldown": 6, "starter": false,
		"cost_anam": 80, "branch": "druides", "tier": 3,
		"effect": "replace_worst_option",
		"description": "Remplace la pire option (plus de negatifs) par une nouvelle",
		"effect_params": {"target": "worst_option"},
	},
	"huath": {
		"name": "Aubepine", "tree": "Crataegus", "unicode": "\u1686",
		"category": "narrative", "cooldown": 5, "starter": false,
		"cost_anam": 100, "branch": "korrigans", "tier": 3,
		"effect": "regenerate_all_options",
		"description": "Regenere les 3 options de la carte (nouveau LLM call ou FastRoute)",
		"effect_params": {"count": 3},
	},
	"straif": {
		"name": "Prunellier", "tree": "Prunus", "unicode": "\u1693",
		"category": "narrative", "cooldown": 10, "starter": false,
		"cost_anam": 140, "branch": "anciens", "tier": 3,
		"effect": "force_twist",
		"description": "Force un retournement : le MOS insere un twist narratif majeur dans la carte suivante",
		"effect_params": {"target": "next_card"},
	},
	# ── RECOVERY ────────────────────────────────────────────────────────────
	"quert": {
		"name": "Pommier", "tree": "Malus", "unicode": "\u168a",
		"category": "recovery", "cooldown": 4, "starter": true,
		"cost_anam": 0, "branch": "central", "tier": 0,
		"effect": "heal_immediate",
		"description": "Soin de +8 PV",
		"effect_params": {"amount": 8},
	},
	"ruis": {
		"name": "Sureau", "tree": "Sambucus", "unicode": "\u1694",
		"category": "recovery", "cooldown": 8, "starter": false,
		"cost_anam": 130, "branch": "niamh", "tier": 3,
		"effect": "heal_and_cost",
		"description": "Soin massif +18 PV mais -5 monnaie biome",
		"effect_params": {"heal": 18, "currency_cost": 5},
	},
	"saille": {
		"name": "Saule", "tree": "Salix", "unicode": "\u1691",
		"category": "recovery", "cooldown": 6, "starter": false,
		"cost_anam": 90, "branch": "niamh", "tier": 1,
		"effect": "currency_and_heal",
		"description": "Regenere +8 monnaie biome + +3 PV",
		"effect_params": {"currency": 8, "heal": 3},
	},
	# ── SPECIAL ─────────────────────────────────────────────────────────────
	"muin": {
		"name": "Vigne", "tree": "Vitis", "unicode": "\u168d",
		"category": "special", "cooldown": 7, "starter": false,
		"cost_anam": 110, "branch": "korrigans", "tier": 2,
		"effect": "invert_effects",
		"description": "Inverse positifs/negatifs de l'option choisie. Echec critique = bonus x1.5, succes = malus x1.5",
		"effect_params": {},
	},
	"ioho": {
		"name": "If", "tree": "Taxus", "unicode": "\u1695",
		"category": "special", "cooldown": 12, "starter": false,
		"cost_anam": 160, "branch": "ankou", "tier": 2,
		"effect": "full_reroll",
		"description": "Defausse la carte entiere et en genere une completement nouvelle",
		"effect_params": {},
	},
	"ur": {
		"name": "Bruyere", "tree": "Calluna", "unicode": "\u1692",
		"category": "special", "cooldown": 10, "starter": false,
		"cost_anam": 140, "branch": "ankou", "tier": 3,
		"effect": "sacrifice_trade",
		"description": "Sacrifie 15 PV, gagne +20 monnaie biome + buff x1.3 score au prochain minigame",
		"effect_params": {"life_cost": 15, "currency_gain": 20, "score_buff": 1.3},
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# ACTION VERBS — 45+ verbes mappes aux 8 champs lexicaux (bible v2.4 s.6.1)
# Utilises par le LLM pour generer les options narratives et detecter le minigame
# ═══════════════════════════════════════════════════════════════════════════════

const ACTION_VERBS := {
	"chance": ["cueillir", "chercher au hasard", "tenter sa chance", "deviner", "fouiller a l'aveugle"],
	"bluff": ["marchander", "convaincre", "mentir", "negocier", "charmer", "amadouer"],
	"observation": ["observer", "scruter", "memoriser", "examiner", "fixer", "inspecter"],
	"logique": ["dechiffrer", "analyser", "resoudre", "decoder", "interpreter", "etudier"],
	"finesse": ["se faufiler", "esquiver", "contourner", "se cacher", "escalader", "traverser"],
	"vigueur": ["combattre", "courir", "fuir", "forcer", "pousser", "resister physiquement"],
	"esprit": ["calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer",
			   "parler", "accepter", "refuser", "attendre", "s'approcher"],
	"perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"],
}

# Fallback: si le LLM genere un verbe hors des 45, mapper a "esprit"
const ACTION_VERB_FALLBACK_FIELD := "esprit"

# ═══════════════════════════════════════════════════════════════════════════════
# FIELD → MINIGAME MAPPING — Champ lexical → minigames possibles (bible v2.4)
# ═══════════════════════════════════════════════════════════════════════════════

const FIELD_MINIGAMES := {
	"chance": ["herboristerie"],
	"bluff": ["negociation"],
	"observation": ["fouille", "regard"],
	"logique": ["runes"],
	"finesse": ["ombres", "equilibre"],
	"vigueur": ["combat_rituel", "course"],
	"esprit": ["apaisement", "volonte", "sang_froid"],
	"perception": ["traces", "echo"],
}

# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT CAPS — Limites des effets (bible v2.4 s.6.5)
# ═══════════════════════════════════════════════════════════════════════════════

const EFFECT_CAPS := {
	"ADD_REPUTATION": {"max": 20, "min": -20},
	"HEAL_LIFE": {"max": 18},
	"HEAL_CRITICAL": {"max": 5},
	"DAMAGE_LIFE": {"max": 15},
	"DAMAGE_CRITICAL": {"max": 22},
	"ADD_BIOME_CURRENCY": {"max": 10},
	"UNLOCK_OGHAM": {"max_per_card": 1},
	"LIFE_MAX": 100,
	"LIFE_MIN": 0,
	"effects_per_option": 3,
	"score_bonus_cap": 2.0,
	"drain_per_card": 1,
}

# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER TABLE — Score → multiplicateur d'effets (bible v2.4 s.6.5)
# ═══════════════════════════════════════════════════════════════════════════════

const MULTIPLIER_TABLE: Array = [
	{"range_min": 0, "range_max": 20, "label": "echec_critique", "factor": -1.5},
	{"range_min": 21, "range_max": 50, "label": "echec", "factor": -1.0},
	{"range_min": 51, "range_max": 79, "label": "reussite_partielle", "factor": 0.5},
	{"range_min": 80, "range_max": 94, "label": "reussite", "factor": 1.0},
	{"range_min": 95, "range_max": 100, "label": "reussite_critique", "factor": 1.5},
]

# ═══════════════════════════════════════════════════════════════════════════════
# ANAM REWARDS — Run end rewards (bible v2.4 s.2.4)
# ═══════════════════════════════════════════════════════════════════════════════

const ANAM_REWARDS := {
	"base": 10,
	"victory_bonus": 15,
	"minigame_won": 2,
	"minigame_threshold": 80,
	"ogham_used": 1,
	"faction_honored": 5,
	"faction_threshold": 80,
	"death_cap_cards": 30,
	"ogham_already_owned_bonus": 5,
}

# Legacy flat consts (kept for backward compat until Phase 4 migration)
const ANAM_BASE_REWARD := 10
const ANAM_VICTORY_BONUS := 15
const ANAM_PER_MINIGAME := 2
const ANAM_PER_OGHAM := 1
const ANAM_FACTION_HONORE := 5

# ═══════════════════════════════════════════════════════════════════════════════
# TALENT TIERS — Cout Anam par tier (bible v2.4 s.2.4)
# ═══════════════════════════════════════════════════════════════════════════════

const TALENT_TIERS := {
	1: {"cost_range_min": 50, "cost_range_max": 80},
	2: {"cost_range_min": 80, "cost_range_max": 120},
	3: {"cost_range_min": 120, "cost_range_max": 180},
	4: {"cost_range_min": 180, "cost_range_max": 250},
	5: {"cost_range_min": 250, "cost_range_max": 350},
}

# ═══════════════════════════════════════════════════════════════════════════════
# BIOMES — 8 biomes complets (bible v2.4 s.4.2)
# ═══════════════════════════════════════════════════════════════════════════════

const BIOMES := {
	"foret_broceliande": {
		"name": "Foret de Broceliande", "subtitle": "Ou les arbres ont des yeux",
		"season": "printemps", "difficulty": 0, "maturity_threshold": 0,
		"oghams_affinity": ["quert", "huath", "coll"],
		"currency_name": "Herbes enchantees",
		"card_interval_range_min": 12, "card_interval_range_max": 15,
		"pnj": "gwenn", "arc": "le_chene_chantant", "arc_cards": 3,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "druides", "arc_condition_value": 30,
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere", "subtitle": "Ou le vent raconte des histoires",
		"season": "automne", "difficulty": 1, "maturity_threshold": 15,
		"oghams_affinity": ["luis", "onn", "saille"],
		"currency_name": "Brins de bruyere",
		"card_interval_range_min": 12, "card_interval_range_max": 15,
		"pnj": "erwan", "arc": "le_chant_des_cairns", "arc_cards": 3,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "anciens", "arc_condition_value": 25,
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages", "subtitle": "Ou la mer defie la terre",
		"season": "ete", "difficulty": 1, "maturity_threshold": 15,
		"oghams_affinity": ["muin", "nuin", "tinne"],
		"currency_name": "Coquillages",
		"card_interval_range_min": 12, "card_interval_range_max": 15,
		"pnj": "maelle", "arc": "le_signal_de_sein", "arc_cards": 4,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "korrigans", "arc_condition_value": 20,
	},
	"villages_celtes": {
		"name": "Villages Celtes", "subtitle": "Ou les hommes forment le destin",
		"season": "ete", "difficulty": 2, "maturity_threshold": 25,
		"oghams_affinity": ["duir", "coll", "beith"],
		"currency_name": "Pieces de cuivre",
		"card_interval_range_min": 10, "card_interval_range_max": 14,
		"pnj": "cadogan", "arc": "le_puits_des_souhaits", "arc_cards": 4,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "anciens", "arc_condition_value": 35,
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres", "subtitle": "Ou le temps se fissure",
		"season": "printemps", "difficulty": 3, "maturity_threshold": 30,
		"oghams_affinity": ["ioho", "straif", "ruis"],
		"currency_name": "Fragments de rune",
		"card_interval_range_min": 10, "card_interval_range_max": 14,
		"pnj": "brennos", "arc": "l_alignement_perdu", "arc_cards": 5,
		"arc_condition_type": "oghams_owned", "arc_condition_faction": "", "arc_condition_value": 5,
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans", "subtitle": "Ou la lumiere ment",
		"season": "automne", "difficulty": 3, "maturity_threshold": 40,
		"oghams_affinity": ["gort", "eadhadh", "luis"],
		"currency_name": "Pierres phosphorescentes",
		"card_interval_range_min": 10, "card_interval_range_max": 14,
		"pnj": "gwen_du", "arc": "le_tertre_du_silence", "arc_cards": 5,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "korrigans", "arc_condition_value": 50,
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens", "subtitle": "Ou les morts veillent",
		"season": "hiver", "difficulty": 4, "maturity_threshold": 50,
		"oghams_affinity": ["quert", "ailm", "coll"],
		"currency_name": "Os graves",
		"card_interval_range_min": 8, "card_interval_range_max": 12,
		"pnj": "ildiko", "arc": "la_voix_de_l_if", "arc_cards": 5,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "ankou", "arc_condition_value": 40,
	},
	"iles_mystiques": {
		"name": "Iles Mystiques", "subtitle": "Ou le monde visible s'acheve",
		"season": "hiver", "difficulty": 5, "maturity_threshold": 75,
		"oghams_affinity": ["ailm", "ruis", "ioho"],
		"currency_name": "Ecume solidifiee",
		"card_interval_range_min": 8, "card_interval_range_max": 12,
		"pnj": "morgane", "arc": "le_passage_d_avalon", "arc_cards": 6,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "niamh", "arc_condition_value": 60,
	},
}

const BIOME_MATURITY_THRESHOLDS := {
	"foret_broceliande": 0,
	"landes_bruyere": 15,
	"cotes_sauvages": 15,
	"villages_celtes": 25,
	"cercles_pierres": 30,
	"marais_korrigans": 40,
	"collines_dolmens": 50,
	"iles_mystiques": 75,
}

const MATURITY_WEIGHTS := {
	"total_runs": 2,
	"fins_vues": 5,
	"oghams_debloques": 3,
	"max_faction_rep": 1,
}

# ═══════════════════════════════════════════════════════════════════════════════
# MOS CONVERGENCE — Duree de run + confiance Merlin (bible v2.4 s.6.2, s.6.3)
# ═══════════════════════════════════════════════════════════════════════════════

const MOS_CONVERGENCE := {
	"soft_min_cards": 8,
	"target_cards_min": 20,
	"target_cards_max": 25,
	"soft_max_cards": 40,
	"hard_max_cards": 50,
	"max_active_promises": 2,
}

const TRUST_TIERS := {
	"T0": {"range_min": 0, "range_max": 24, "label": "cryptique"},
	"T1": {"range_min": 25, "range_max": 49, "label": "indices"},
	"T2": {"range_min": 50, "range_max": 74, "label": "avertissements"},
	"T3": {"range_min": 75, "range_max": 100, "label": "secrets"},
}

const TRUST_DELTAS := {
	"promise_kept": 10,
	"promise_broken": -15,
	"courageous_choice_min": 3,
	"courageous_choice_max": 5,
	"selfish_choice_min": -5,
	"selfish_choice_max": -3,
}

# ═══════════════════════════════════════════════════════════════════════════════
# IN-GAME PERIODS — Periodes du jour avec bonus faction (bible v2.4 s.6.4)
# ═══════════════════════════════════════════════════════════════════════════════

const IN_GAME_PERIODS := {
	"aube": {"cards_min": 1, "cards_max": 5, "factions": ["druides"], "bonus": 0.10},
	"jour": {"cards_min": 6, "cards_max": 10, "factions": ["anciens", "niamh"], "bonus": 0.10},
	"crepuscule": {"cards_min": 11, "cards_max": 15, "factions": ["korrigans"], "bonus": 0.10},
	"nuit": {"cards_min": 16, "cards_max": 20, "factions": ["ankou"], "bonus": 0.15},
}

# ═══════════════════════════════════════════════════════════════════════════════
# ARBRE DE VIE — Talent Tree v2.1 (Faction-based, 34 noeuds, cout Anam)
# 5 branches factions × 5 noeuds + 4 central + 5 speciaux = 34 total
# ═══════════════════════════════════════════════════════════════════════════════

const TALENT_NODES := {
	# ── DRUIDES (Nature, rituels, guerison) ─────────────────────────────────
	"druides_1": {
		"branch": "druides", "tier": 1,
		"name": "Vigueur du Chene",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "modify_start", "target": "life", "value": 10},
		"description": "+10 vie au depart de chaque run.",
		"lore": "Le chene partage sa force avec ceux qui l'ecoutent.",
	},
	"druides_2": {
		"branch": "druides", "tier": 2,
		"name": "Symbiose Vegetale",
		"cost": 25,
		"prerequisites": ["druides_1"],
		"effect": {"type": "cooldown_reduction", "category": "nature", "value": 1},
		"description": "Reduit de 1 le cooldown des Oghams de categorie nature.",
		"lore": "Les racines murmurent les secrets du temps.",
	},
	"druides_3": {
		"branch": "druides", "tier": 3,
		"name": "Esprit du Nemeton",
		"cost": 50,
		"prerequisites": ["druides_2"],
		"effect": {"type": "minigame_bonus", "field": "logique", "value": 0.15},
		"description": "+15% score aux minigames du champ logique.",
		"lore": "Le nemeton revele l'ordre cache dans le chaos.",
	},
	"druides_4": {
		"branch": "druides", "tier": 4,
		"name": "Guerison Profonde",
		"cost": 80,
		"prerequisites": ["druides_3"],
		"effect": {"type": "heal_bonus", "value": 1.0},
		"description": "Double l'effet de guerison des Oghams Recovery.",
		"lore": "La seve de l'arbre-monde coule dans tes veines.",
	},
	"druides_5": {
		"branch": "druides", "tier": 5,
		"name": "Racine Celeste",
		"cost": 120,
		"prerequisites": ["druides_4"],
		"effect": {"type": "drain_reduction", "value": 2},
		"description": "Le drain de vie par carte passe de 1 a 0 (annule).",
		"lore": "L'arbre-monde te nourrit a chaque pas.",
	},
	# ── ANCIENS (Sagesse, tradition, connaissance) ──────────────────────────
	"anciens_1": {
		"branch": "anciens", "tier": 1,
		"name": "Clairvoyance",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "reveal_one_effect"},
		"description": "Revele 1 effet cache par carte.",
		"lore": "Les ancetres guident ton regard au-dela du visible.",
	},
	"anciens_2": {
		"branch": "anciens", "tier": 2,
		"name": "Sagesse Accumulee",
		"cost": 25,
		"prerequisites": ["anciens_1"],
		"effect": {"type": "score_global_bonus", "value": 0.05},
		"description": "+5% score a tous les minigames.",
		"lore": "Chaque generation transmet un fragment de maitrise.",
	},
	"anciens_3": {
		"branch": "anciens", "tier": 3,
		"name": "Troisieme Oeil",
		"cost": 50,
		"prerequisites": ["anciens_2"],
		"effect": {"type": "special_rule", "id": "predict_next_theme"},
		"description": "Predit le theme de la prochaine carte.",
		"lore": "Le troisieme oeil perce le voile du temps.",
	},
	"anciens_4": {
		"branch": "anciens", "tier": 4,
		"name": "Bouclier Ancestral",
		"cost": 80,
		"prerequisites": ["anciens_3"],
		"effect": {"type": "special_rule", "id": "resist_damage_once"},
		"description": "Annule 1 source de degats par run (bouclier).",
		"lore": "L'armure des ancetres absorbe le premier coup.",
	},
	"anciens_5": {
		"branch": "anciens", "tier": 5,
		"name": "Immortalite du Souvenir",
		"cost": 120,
		"prerequisites": ["anciens_4"],
		"effect": {"type": "special_rule", "id": "survive_death_once"},
		"description": "Survit a la mort 1 fois par run (revient a 10 vie).",
		"lore": "Tant que quelqu'un se souvient, tu ne meurs jamais.",
	},
	# ── KORRIGANS (Chaos, malice, fortune) ──────────────────────────────────
	"korrigans_1": {
		"branch": "korrigans", "tier": 1,
		"name": "Doigts de Fee",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "bonus_anam_per_run"},
		"description": "+3 Anam bonus par run completee.",
		"lore": "Les korrigans savent ou se cachent les tresors.",
	},
	"korrigans_2": {
		"branch": "korrigans", "tier": 2,
		"name": "Chance du Lutin",
		"cost": 25,
		"prerequisites": ["korrigans_1"],
		"effect": {"type": "minigame_bonus", "field": "chance", "value": 0.10},
		"description": "+10% score aux minigames du champ chance.",
		"lore": "La chance sourit aux esprits farceurs.",
	},
	"korrigans_3": {
		"branch": "korrigans", "tier": 3,
		"name": "Miroir Inverseur",
		"cost": 50,
		"prerequisites": ["korrigans_2"],
		"effect": {"type": "special_rule", "id": "invert_negative_once"},
		"description": "Inverse 1 effet negatif en positif par run.",
		"lore": "Le korrigan retourne la malchance comme un gant.",
	},
	"korrigans_4": {
		"branch": "korrigans", "tier": 4,
		"name": "Rythme du Chaos",
		"cost": 80,
		"prerequisites": ["korrigans_3"],
		"effect": {"type": "cooldown_reduction", "category": null, "value": 1},
		"description": "-1 cooldown global sur tous les Oghams.",
		"lore": "Le chaos accelere le cycle des pouvoirs.",
	},
	"korrigans_5": {
		"branch": "korrigans", "tier": 5,
		"name": "Tresor du Tertre",
		"cost": 120,
		"prerequisites": ["korrigans_4"],
		"effect": {"type": "special_rule", "id": "double_anam_rewards"},
		"description": "Double les recompenses Anam en fin de run.",
		"lore": "Le tertre s'ouvre et revele ses richesses infinies.",
	},
	# ── NIAMH (Amour, diplomatie, equilibre) ────────────────────────────────
	"niamh_1": {
		"branch": "niamh", "tier": 1,
		"name": "Douceur de Niamh",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "crit_success_heal"},
		"description": "+5 vie sur chaque succes critique.",
		"lore": "L'amour de Niamh guerit les blessures invisibles.",
	},
	"niamh_2": {
		"branch": "niamh", "tier": 2,
		"name": "Charme Diplomatique",
		"cost": 25,
		"prerequisites": ["niamh_1"],
		"effect": {"type": "rep_bonus", "value": 0.10},
		"description": "+10% gains de reputation avec toutes les factions.",
		"lore": "Ta voix porte la douceur des eaux de Tir na nOg.",
	},
	"niamh_3": {
		"branch": "niamh", "tier": 3,
		"name": "Voile d'Oubli",
		"cost": 50,
		"prerequisites": ["niamh_2"],
		"effect": {"type": "special_rule", "id": "reduce_rep_loss"},
		"description": "Les pertes de reputation sont reduites de 50%.",
		"lore": "Les offenses s'effacent comme brume au soleil.",
	},
	"niamh_4": {
		"branch": "niamh", "tier": 4,
		"name": "Quatrieme Voie",
		"cost": 80,
		"prerequisites": ["niamh_3"],
		"effect": {"type": "special_rule", "id": "extra_card_option"},
		"description": "+1 option narrative par carte (3 → 4 choix).",
		"lore": "La ou les autres voient trois chemins, tu en vois quatre.",
	},
	"niamh_5": {
		"branch": "niamh", "tier": 5,
		"name": "Source Eternelle",
		"cost": 120,
		"prerequisites": ["niamh_4"],
		"effect": {"type": "special_rule", "id": "passive_heal"},
		"description": "+2 vie toutes les 5 cartes (regeneration passive).",
		"lore": "La source de Tir na nOg coule en toi sans fin.",
	},
	# ── ANKOU (Mort, sacrifice, risque) ─────────────────────────────────────
	"ankou_1": {
		"branch": "ankou", "tier": 1,
		"name": "Marche avec l'Ombre",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "drain_reduction", "value": 1},
		"description": "Le drain de vie par carte passe de 1 a 0.",
		"lore": "L'Ankou ralentit ta chute vers le neant.",
	},
	"ankou_2": {
		"branch": "ankou", "tier": 2,
		"name": "Regard Sombre",
		"cost": 25,
		"prerequisites": ["ankou_1"],
		"effect": {"type": "minigame_bonus", "field": "esprit", "value": 0.15},
		"description": "+15% score aux minigames du champ esprit.",
		"lore": "Celui qui a vu la mort ne craint plus les epreuves.",
	},
	"ankou_3": {
		"branch": "ankou", "tier": 3,
		"name": "Pacte Sanglant",
		"cost": 50,
		"prerequisites": ["ankou_2"],
		"effect": {"type": "special_rule", "id": "sacrifice_life_for_anam"},
		"description": "Sacrifie 10 vie pour gagner 20 Anam (1 fois par run).",
		"lore": "Le sang verse nourrit les racines du monde.",
	},
	"ankou_4": {
		"branch": "ankou", "tier": 4,
		"name": "Prescience Funebre",
		"cost": 80,
		"prerequisites": ["ankou_3"],
		"effect": {"type": "special_rule", "id": "see_next_card_full"},
		"description": "Voir le theme ET les effets de la prochaine carte.",
		"lore": "L'Ankou connait le destin de chaque ame.",
	},
	"ankou_5": {
		"branch": "ankou", "tier": 5,
		"name": "Recolte Sombre",
		"cost": 120,
		"prerequisites": ["ankou_4"],
		"effect": {"type": "special_rule", "id": "low_life_bonus"},
		"description": "Recompenses Anam +50% si vie <= 25 en fin de run.",
		"lore": "Plus tu frolais la mort, plus ta recolte est riche.",
	},
	# ── CENTRAL (Universel, equilibre, progression) ─────────────────────────
	"central_1": {
		"branch": "central", "tier": 1,
		"name": "Coeur Fortifie",
		"cost": 20,
		"prerequisites": [],
		"effect": {"type": "modify_start", "target": "life_max", "value": 10},
		"description": "Vie max +10 (100 → 110).",
		"lore": "Le coeur du druide bat plus fort que la pierre.",
	},
	"central_2": {
		"branch": "central", "tier": 2,
		"name": "Flux Accelere",
		"cost": 25,
		"prerequisites": ["central_1"],
		"effect": {"type": "cooldown_reduction", "category": null, "value": 1},
		"description": "-1 cooldown global sur tous les Oghams.",
		"lore": "Le flux d'Ogham repond plus vite a ta volonte.",
	},
	"central_3": {
		"branch": "central", "tier": 3,
		"name": "Oeil de Merlin",
		"cost": 50,
		"prerequisites": ["central_2"],
		"effect": {"type": "special_rule", "id": "show_karma_tension"},
		"description": "Affiche karma et tension dans le HUD.",
		"lore": "Merlin te revele les courants invisibles du monde.",
	},
	"central_4": {
		"branch": "central", "tier": 4,
		"name": "Maitrise Universelle",
		"cost": 80,
		"prerequisites": ["central_3"],
		"effect": {"type": "score_global_bonus", "value": 0.10},
		"description": "+10% score a tous les minigames.",
		"lore": "La maitrise transcende les frontieres du savoir.",
	},
	# ── SPECIAUX (Cross-faction, tier 2-3) ──────────────────────────────────
	"calendrier_des_brumes": {
		"branch": "central", "tier": 2,
		"name": "Calendrier des Brumes",
		"cost": 30,
		"prerequisites": ["central_1"],
		"effect": {"type": "special_rule", "id": "calendrier_des_brumes"},
		"description": "Revele 7 prochains evenements. Primes aux evenements atteints.",
		"lore": "A travers les brumes, Merlin te montre ce qui vient...",
	},
	"harmonie_factions": {
		"branch": "central", "tier": 3,
		"name": "Harmonie des Factions",
		"cost": 60,
		"prerequisites": ["druides_1", "anciens_1", "korrigans_1"],
		"effect": {"type": "special_rule", "id": "harmony_anam_bonus"},
		"description": "+5 Anam/run si toutes les factions sont >= 50.",
		"lore": "L'harmonie entre les peuples nourrit l'ame du monde.",
	},
	"pacte_ombre_lumiere": {
		"branch": "central", "tier": 3,
		"name": "Pacte Ombre-Lumiere",
		"cost": 60,
		"prerequisites": ["niamh_1", "ankou_1"],
		"effect": {"type": "special_rule", "id": "invert_heal_damage_once"},
		"description": "Inverse heal et damage 1 fois par run.",
		"lore": "Quand l'ombre et la lumiere s'unissent, tout s'inverse.",
	},
	"eveil_ogham": {
		"branch": "central", "tier": 2,
		"name": "Eveil d'Ogham",
		"cost": 35,
		"prerequisites": ["druides_1"],
		"effect": {"type": "special_rule", "id": "extra_ogham_slot"},
		"description": "Equipe 1 Ogham supplementaire (1 → 2 actifs).",
		"lore": "L'eveil ouvre un second canal vers le pouvoir ancien.",
	},
	"instinct_sauvage": {
		"branch": "central", "tier": 2,
		"name": "Instinct Sauvage",
		"cost": 35,
		"prerequisites": ["korrigans_1", "anciens_1"],
		"effect": {"type": "special_rule", "id": "minigame_retry_once"},
		"description": "1 retry gratuit de minigame par run.",
		"lore": "L'instinct sauvage offre une seconde chance.",
	},
	"boucle_eternelle": {
		"branch": "central", "tier": 4,
		"name": "Boucle Eternelle",
		"cost": 150,
		"prerequisites": ["central_4", "harmonie_factions"],
		"effect": {"type": "special_rule", "id": "new_game_plus"},
		"description": "New Game+: Anam x1.5 par run.",
		"lore": "La boucle se referme. Et recommence, plus forte.",
	},
}

# Talent branch colors for UI
const TALENT_BRANCH_COLORS := {
	"druides": Color(0.35, 0.55, 0.35),    # Forest green
	"anciens": Color(0.55, 0.50, 0.40),    # Stone grey-brown
	"korrigans": Color(0.45, 0.30, 0.55),  # Purple mischief
	"niamh": Color(0.40, 0.55, 0.70),      # Lake blue
	"ankou": Color(0.30, 0.30, 0.35),      # Dark shadow
	"central": Color(0.65, 0.45, 0.20),    # Amber
}

# Talent tier names
const TALENT_TIER_NAMES := {1: "Germe", 2: "Pousse", 3: "Branche", 4: "Cime", 5: "Racine Celeste"}

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME SYSTEM — 8 Celtic Biomes (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

const BIOME_KEYS := [
	"foret_broceliande", "landes_bruyere", "cotes_sauvages",
	"villages_celtes", "cercles_pierres", "marais_korrigans", "collines_dolmens",
	"iles_mystiques"
]

const BIOME_DEFAULT := "foret_broceliande"

# Mission templates per biome — quest briefing shown at run start (from SPEC_TRANSITION_SCENES)
# Static func because nested dict literals are not always valid const expressions in GDScript 4.x.
static func get_mission_template(biome_key: String) -> Dictionary:
	match biome_key:
		"broceliande", "foret_broceliande":
			return {"title": "Le Souffle de Barenton", "text": "La Fontaine de Barenton s'assombrit. Trouve ce qui la trouble et ramene la clarte.", "name": "Foret de Broceliande"}
		"landes", "landes_bruyere":
			return {"title": "Le Chant des Cairns", "text": "Les cairns du vent se taisent. Retrouve la melodie perdue avant que le silence ne gagne.", "name": "Landes de Bruyere"}
		"cotes", "cotes_sauvages":
			return {"title": "Le Signal de Sein", "text": "L'ile de Sein ne repond plus. Navigue jusqu'au phare et decouvre pourquoi.", "name": "Cotes Sauvages"}
		"villages", "villages_celtes":
			return {"title": "Le Puits des Souhaits", "text": "L'eau du puits sacre est tarie. Aide le village a retrouver sa source.", "name": "Villages Celtes"}
		"cercles", "cercles_pierres":
			return {"title": "L'Alignement Perdu", "text": "Les menhirs de Carnac sont desalignes. Le temps se detraque. Restaure l'accord.", "name": "Cercles de Pierres"}
		"marais", "marais_korrigans":
			return {"title": "Le Tertre du Silence", "text": "Le chef des korrigans ne rit plus. Descends dans le tertre et affronte le Vide.", "name": "Marais des Korrigans"}
		"collines", "collines_dolmens":
			return {"title": "La Voix de l'If", "text": "L'if millenaire perd ses branches. Ecoute ses dernieres paroles avant qu'il ne se taise.", "name": "Collines aux Dolmens"}
		"iles", "iles_mystiques":
			return {"title": "Le Passage d'Avalon", "text": "Au-dela des brumes, une ile apparait puis s'efface. Trouve le passage avant que la maree ne le scelle.", "name": "Iles Mystiques"}
	return {}

# Card type distribution weights
const CARD_TYPE_WEIGHTS := {
	"narrative": 0.80,
	"event": 0.10,
	"promise": 0.05,
	"merlin_direct": 0.05,
}

# Event card probability (CAL-REQ-060 — ~15% of pool when EventAdapter active)
const EVENT_CARD_PROBABILITY := 0.15

# Seasonal effects on gameplay (CAL-REQ-120)
const SEASONAL_EFFECTS := {
	"spring": {
		"label": "Printemps",
		"faction_bias": "druides",
		"bias_direction": "up",
		"narrative_tone": "renouveau",
		"event_weight_mod": 1.1,
	},
	"summer": {
		"label": "Ete",
		"faction_bias": "anciens",
		"bias_direction": "up",
		"narrative_tone": "aventure",
		"event_weight_mod": 1.0,
	},
	"autumn": {
		"label": "Automne",
		"faction_bias": "korrigans",
		"bias_direction": "up",
		"narrative_tone": "reflexion",
		"event_weight_mod": 1.15,
	},
	"winter": {
		"label": "Hiver",
		"faction_bias": "ankou",
		"bias_direction": "down",
		"narrative_tone": "survie",
		"event_weight_mod": 1.2,
	},
}

# Minimum cards before allowing event/promise cards
const MIN_CARDS_BEFORE_EVENT := 3
const MIN_CARDS_BEFORE_PROMISE := 5
const MAX_ACTIVE_PROMISES := 2

# ═══════════════════════════════════════════════════════════════════════════════
# MAP NODE TYPES — STS-like map (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

const NODE_TYPES := {
	"NARRATIVE": {"weight": 0.40, "label": "Recit", "cards_min": 2, "cards_max": 4, "icon": "\u2731"},
	"EVENT": {"weight": 0.15, "label": "Evenement", "cards_min": 1, "cards_max": 2, "icon": "\u2606"},
	"PROMISE": {"weight": 0.08, "label": "Promesse", "cards_min": 1, "cards_max": 1, "icon": "\u2662"},
	"REST": {"weight": 0.12, "label": "Repos", "cards_min": 0, "cards_max": 0, "icon": "\u2665"},
	"MERCHANT": {"weight": 0.08, "label": "Marchand", "cards_min": 0, "cards_max": 0, "icon": "<>"},
	"MYSTERY": {"weight": 0.10, "label": "Mystere", "cards_min": 1, "cards_max": 3, "icon": "\u003F"},
	"MERLIN": {"weight": 0.07, "label": "Merlin", "cards_min": 3, "cards_max": 5, "icon": "\u2726"},
}

const DEFAULT_MAP_FLOORS := 8

# ═══════════════════════════════════════════════════════════════════════════════
# EXPEDITION SYSTEM — Tools & Departure Conditions (Phase 39)
# ═══════════════════════════════════════════════════════════════════════════════

const EXPEDITION_TOOLS := {
	"baton_marche": {
		"name": "Baton de Marche",
		"icon": "\u2694",  # Crossed swords
		"description": "Arme naturelle du voyageur",
		"bonus": "Corps +1 DC en combat",
		"bonus_field": "combat",
		"dc_bonus": -3,
		"initial_effect": {},
	},
	"besace": {
		"name": "Besace du Druide",
		"icon": "<>",  # Diamond
		"description": "Provisions et herbes medicinales",
		"bonus": "+10 Vie au depart",
		"bonus_field": "",
		"dc_bonus": 0,
		"initial_effect": {"type": "HEAL_LIFE", "amount": 10},
	},
	"lanterne": {
		"name": "Lanterne d'Ogham",
		"icon": "\u2736",  # Star
		"description": "Eclaire les chemins oublies",
		"bonus": "Exploration +3 DC",
		"bonus_field": "exploration",
		"dc_bonus": -3,
		"initial_effect": {},
	},
	"talisman": {
		"name": "Talisman Ancien",
		"icon": "\u2726",  # Four-pointed star
		"description": "Resonne avec les forces invisibles",
		"bonus": "Mysticisme +3 DC",
		"bonus_field": "mysticisme",
		"dc_bonus": -3,
		"initial_effect": {},
	},
}


const EXPEDITION_MERLIN_REACTIONS := {
	"baton_marche": "Le Baton de Marche... un classique. Il ne te trahira pas.",
	"besace": "La Besace ! Provisions et prudence. Tu es sage.",
	"lanterne": "La Lanterne d'Ogham... elle revele ce que l'ombre cache.",
	"talisman": "Le Talisman vibre deja. Il sent le voyage.",
	"jour": "De jour. La lumiere protege... mais attire aussi.",
	"nuit": "De nuit ? Courageux. Les ombres seront plus bavard.",
	"compagnon": "Un compagnon ! Les esprits sourient aux liens.",
	"leger": "Voyager leger... rapide, mais tu sacrifies la preparation.",
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEME D'ALIGNEMENT — 5 Factions avec réputations pondérées
# Scores -100 à +100, persistance cross-run (state["meta"]["faction_rep"])
# Ref : docs/20_card_system/DOC_15_Faction_Alignment_System.md
# ═══════════════════════════════════════════════════════════════════════════════

# Factions (réputation 0-100)
const FACTIONS: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
const FACTION_THRESHOLD_CONTENT: int = 50    # déblocage cartes spéciales
const FACTION_THRESHOLD_ENDING: int = 80     # déblocage fin de faction

const FACTION_INFO := {
	"druides":   {"name": "Druides de Bretagne", "symbol": "chene"},
	"anciens":   {"name": "Les Anciens",          "symbol": "menhir"},
	"korrigans": {"name": "Korrigans des Marais", "symbol": "champignon"},
	"niamh":     {"name": "Niamh et Tir na nOg",  "symbol": "lac"},
	"ankou":     {"name": "L'Ankou",               "symbol": "faux"},
}

const FACTION_SCORE_MIN := 0
const FACTION_SCORE_MAX := 100
const FACTION_SCORE_START := 10

# Bandes de seuil — évalués du plus haut (honore) au plus bas (hostile)
const FACTION_TIERS := {
	"honore":       {"min": 80,  "label": "Honore"},
	"sympathisant": {"min": 50,  "label": "Sympathisant"},
	"neutre":       {"min": 20,  "label": "Neutre"},
	"mefiant":      {"min": 5,   "label": "Mefiant"},
	"hostile":      {"min": 0,   "label": "Hostile"},
}

# Bonus/malus de début de run selon tier × faction
# Tiers sans entrée = pas d'effet de début de run
const FACTION_RUN_BONUSES := {
	"druides":   {
		"honore":       {"type": "HEAL_LIFE",   "amount": 15},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 10},
	},
	"anciens":   {
		"honore":       {"type": "HEAL_LIFE",   "amount": 10},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 5},
	},
	"korrigans": {
		"honore":       {"type": "HEAL_LIFE",   "amount": 20},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 10},
	},
	"niamh":     {
		"honore":       {"type": "HEAL_LIFE",   "amount": 15},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 5},
	},
	"ankou":     {
		"honore":       {"type": "HEAL_LIFE",   "amount": 10},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 15},
	},
}

# Valeurs de delta pour ADD_REPUTATION
const FACTION_DELTA_MINOR   := 5    # Auto-tag keyword, geste mineur
const FACTION_DELTA_MAJOR   := 15   # Choix narratif significatif
const FACTION_DELTA_EXTREME := 30   # Acte héroïque ou trahison majeure
# FACTION_DECAY_RATE removed — bible v2.4 s.5.5: "Reputation factions (pas de decay)"

# Keywords pour auto-tag Path B (merlin_llm_adapter._wrap_text_as_card)
const FACTION_KEYWORDS := {
	"druides":   ["druide", "ogham", "nemeton", "chene", "barde"],
	"korrigans": ["korrigan", "farfadet", "marais", "lutin", "fee"],
	"niamh":     ["niamh", "eau", "lac", "amour", "nostalgie"],
	"anciens":   ["ancien", "menhir", "dolmen", "eternite", "primordial"],
	"ankou":     ["ankou", "mort", "faucheuse", "ame", "trepas"],
}

# ═══════════════════════════════════════════════════════════════════════════════
# ANAM — Monnaie principale inter-run (cross-run currency)
# Réf : docs/20_card_system/DOC_17_Run_Rules_Officiel.md
# ═══════════════════════════════════════════════════════════════════════════════

const ANAM_START := 0                # Anam au démarrage d'un run (cross-run currency)


# ═══════════════════════════════════════════════════════════════════════════════
# VIE — Affichage segmenté
# Réf : docs/20_card_system/DOC_17_Run_Rules_Officiel.md
# ═══════════════════════════════════════════════════════════════════════════════

const LIFE_BAR_SEGMENTS := 10       # 10 barres pixelisées de 10 PV chacune
