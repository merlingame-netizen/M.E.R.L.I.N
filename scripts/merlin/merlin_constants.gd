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
	"runes": {"name": "Runes", "desc": "Dechiffrer une rune cachee dans la pierre", "trigger": "rune|ogham|symbole|gravure|inscription"},
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
const LIFE_ESSENCE_DRAIN_PER_CARD := 0      # No drain per card (director decision q-20260412-001)
const MIN_CARDS_FOR_VICTORY := 25           # Victory requires 25+ cards (= MOS target_cards_max). See MOS_CONVERGENCE for full zones.
const CARDS_PER_DAY := 5                    # Cards played per in-game day (day counter for LLM context)
const LIFE_ESSENCE_FAIL_DAMAGE := 0         # Normal failure = no life damage
const LIFE_ESSENCE_EVENT_FAIL_DAMAGE := 6   # Failed event/palier
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
	"esprit": ["calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer"],
	"perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"],
	"neutre": ["parler", "accepter", "refuser", "attendre", "s'approcher"],
}

# Verbes neutres — mappes au champ "esprit" pour les minigames (bible v2.4 s.6.4)
# Ils sont inclus dans ACTION_VERBS["esprit"] pour la detection, mais identifies ici
# pour que le LLM puisse distinguer les verbes neutres des verbes actifs.
const NEUTRAL_VERBS: Array[String] = ["parler", "accepter", "refuser", "attendre", "s'approcher"]

# Fallback: si le LLM genere un verbe hors des 45, mapper a "esprit"
const ACTION_VERB_FALLBACK_FIELD := "esprit"

# ═══════════════════════════════════════════════════════════════════════════════
# FIELD → MINIGAME MAPPING — Champ lexical → minigames possibles (bible v2.4)
# ═══════════════════════════════════════════════════════════════════════════════

const FIELD_MINIGAMES := {
	"chance": ["chance"],
	"bluff": ["bluff"],
	"observation": ["observation"],
	"logique": ["logique"],
	"finesse": ["finesse"],
	"vigueur": ["vigueur"],
	"esprit": ["esprit"],
	"perception": ["perception"],
	"neutre": ["esprit"],
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
	"drain_per_card": 0,
}

# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT PIPELINE — Ordre d'application des effets (bible v2.4 s.13.3)
# Reference absolue pour le code — toute implementation doit suivre cet ordre.
# ═══════════════════════════════════════════════════════════════════════════════

const EFFECT_PIPELINE: Array[String] = [
	"DRAIN_VIE",          # 1. -1 PV (debut de carte)
	"AFFICHAGE_CARTE",    # 2. texte + 3 options
	"ACTIVATION_OGHAM",   # 3. optionnel: le joueur clique sur l'Ogham actif
	"CHOIX_OPTION",       # 4. le joueur choisit 1 des 3 options
	"MINIGAME",           # 5. le joueur joue le minigame (sauf Merlin Direct)
	"SCORE",              # 6. 0-100, multiplicateur calcule
	"APPLICATION_EFFETS", # 7. effets de l'option choisie, multiplies par le score
	"OGHAM_POST_EFFECT",  # 8. Oghams de protection filtrent les negatifs APRES le calcul
	"VERIFICATION_VIE",   # 9. si vie = 0, fin de run
	"VERIFICATION_PROMESSES", # 10. countdown -1, si expire → carte resolution inseree
	"COOLDOWN",           # 11. -1 sur l'Ogham actif
	"RETOUR_3D",          # 12. fondu, marche reprend
]

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM AFFINITY — Bonus quand un Ogham est utilise dans son biome d'affinite
# (bible v2.4 s.2.2: +10% score, -1 cooldown)
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_AFFINITY_SCORE_BONUS: float = 0.10   # +10% score au prochain minigame
const OGHAM_AFFINITY_COOLDOWN_BONUS: int = 1      # -1 cooldown (recharge plus rapide)

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
		"season": "printemps", "difficulty": 0, "maturity_threshold": 0,  # bible v2.4 s.4.1: starter, diff 0
		"dominant_faction": "druides",
		"oghams_affinity": ["quert", "huath", "coll"],
		"currency_name": "Herbes enchantees",
		"card_interval_range_min": 12, "card_interval_range_max": 15,  # bible v2.4 s.4.3: calme
		"pnj": "gwenn", "arc": "le_chene_chantant", "arc_cards": 3,
		"arc_condition_type": "faction_rep", "arc_condition_faction": "druides", "arc_condition_value": 30,
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere", "subtitle": "L'horizon sans fin",
		"season": "automne", "difficulty": 1, "maturity_threshold": 15,  # bible v2.4 s.4.1
		"dominant_faction": "anciens",
		"oghams_affinity": ["luis", "onn", "saille"],
		"currency_name": "Brins de bruyere",
		"card_interval_range_min": 8, "card_interval_range_max": 10,  # bible v2.4 s.4.3: modere
		"pnj": "aedan", "arc": "l_ermite_du_vent", "arc_cards": 4,  # bible v2.4 s.3.6
		"arc_condition_type": "biome_runs", "arc_condition_faction": "", "arc_condition_value": 3,
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages", "subtitle": "L'ocean murmurant",
		"season": "ete", "difficulty": 0, "maturity_threshold": 15,  # bible v2.4 s.4.1: diff 0
		"dominant_faction": "niamh",
		"oghams_affinity": ["muin", "nuin", "tinne"],
		"currency_name": "Coquillages",
		"card_interval_range_min": 6, "card_interval_range_max": 8,  # bible v2.4 s.4.3: rythme par les vagues
		"pnj": "bran", "arc": "le_phoque_d_argent", "arc_cards": 3,  # bible v2.4 s.3.6
		"arc_condition_type": "faction_rep", "arc_condition_faction": "niamh", "arc_condition_value": 30,
	},
	"villages_celtes": {
		"name": "Villages Celtes", "subtitle": "Flammes obstinees",
		"season": "ete", "difficulty": -1, "maturity_threshold": 25,  # bible v2.4 s.4.1: diff -1
		"dominant_faction": "anciens",
		"oghams_affinity": ["duir", "coll", "beith"],
		"currency_name": "Pieces de cuivre",
		"card_interval_range_min": 8, "card_interval_range_max": 10,  # bible v2.4 s.4.3: social, modere
		"pnj": "morwenna", "arc": "l_assemblee_secrete", "arc_cards": 5,  # bible v2.4 s.3.6
		"arc_condition_type": "faction_rep", "arc_condition_faction": "anciens", "arc_condition_value": 40,
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres", "subtitle": "Ou le temps hesite",
		"season": "hiver", "difficulty": 1, "maturity_threshold": 30,  # bible v2.4 s.4.1: hiver, diff 1
		"dominant_faction": "druides",
		"oghams_affinity": ["ioho", "straif", "ruis"],
		"currency_name": "Fragments de rune",
		"card_interval_range_min": 10, "card_interval_range_max": 12,  # bible v2.4 s.4.3: lent, mystique
		"pnj": "seren", "arc": "le_rituel_oublie", "arc_cards": 4,  # bible v2.4 s.3.6
		"arc_condition_type": "oghams_owned", "arc_condition_faction": "", "arc_condition_value": 2,
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans", "subtitle": "Deception et feux follets",
		"season": "automne", "difficulty": 2, "maturity_threshold": 40,  # bible v2.4 s.4.1: diff 2
		"dominant_faction": "korrigans",
		"oghams_affinity": ["gort", "eadhadh", "luis"],
		"currency_name": "Pierres phosphorescentes",
		"card_interval_range_min": 4, "card_interval_range_max": 6,  # bible v2.4 s.4.3: frenetique, piegeux
		"pnj": "puck", "arc": "le_tresor_des_feux", "arc_cards": 4,  # bible v2.4 s.3.6
		"arc_condition_type": "faction_rep", "arc_condition_faction": "korrigans", "arc_condition_value": 40,
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens", "subtitle": "Les os de la terre",
		"season": "printemps", "difficulty": 0, "maturity_threshold": 50,  # bible v2.4 s.4.1: printemps, diff 0
		"dominant_faction": "ankou",
		"oghams_affinity": ["quert", "ailm", "coll"],
		"currency_name": "Os graves",
		"card_interval_range_min": 10, "card_interval_range_max": 12,  # bible v2.4 s.4.3: paisible
		"pnj": "taliesin", "arc": "la_voix_des_rois", "arc_cards": 3,  # bible v2.4 s.3.6
		"arc_condition_type": "endings_seen", "arc_condition_faction": "", "arc_condition_value": 5,
	},
	"iles_mystiques": {
		"name": "Iles Mystiques", "subtitle": "Au-dela des brumes",
		"season": "samhain", "difficulty": 3, "maturity_threshold": 75,  # bible v2.4 s.4.1: samhain, diff 3
		"dominant_faction": "niamh",
		"oghams_affinity": ["ailm", "ruis", "ioho"],
		"currency_name": "Ecume solidifiee",
		"card_interval_range_min": 3, "card_interval_range_max": 15,  # bible v2.4 s.4.3: imprevisible
		"pnj": "branwen", "arc": "le_passage_de_morgane", "arc_cards": 5,  # bible v2.4 s.3.6
		"arc_condition_type": "faction_rep", "arc_condition_faction": "ankou", "arc_condition_value": 50,
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
# PNJ RECURRENTS — 1 par biome (bible v2.4 s.3.7)
# ═══════════════════════════════════════════════════════════════════════════════

const BIOME_PNJ_INFO := {
	"gwenn":    {"name": "Gwenn la Cueilleuse", "biome": "foret_broceliande", "role": "Guide nature, marchande d'herbes", "faction": "druides"},
	"aedan":    {"name": "Aedan l'Ermite",      "biome": "landes_bruyere",    "role": "Sage solitaire, enigmes",        "faction": ""},
	"bran":     {"name": "Bran le Passeur",      "biome": "cotes_sauvages",    "role": "Marchand maritime, informations", "faction": "anciens"},
	"morwenna": {"name": "Morwenna la Forge",    "biome": "villages_celtes",   "role": "Forgeronne, politique locale",   "faction": ""},
	"seren":    {"name": "Seren l'Etoilee",      "biome": "cercles_pierres",   "role": "Druidesse mystique, rituels",    "faction": "druides"},
	"puck":     {"name": "Puck le Lutin",        "biome": "marais_korrigans",  "role": "Farceur, marchand de pieges",    "faction": "korrigans"},
	"taliesin": {"name": "Taliesin le Barde",    "biome": "collines_dolmens",  "role": "Conteur, gardien de memoire",    "faction": "anciens"},
	"branwen":  {"name": "Branwen la Spectrale", "biome": "iles_mystiques",    "role": "Esprit enigmatique, epreuves",   "faction": "ankou"},
}

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM DISCOVERY — Probabilites de decouverte en run (bible v2.4 s.2.2)
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_DISCOVERY_TRIGGERS := {
	"pnj_merchant":    {"probability": 0.40, "max_per_run": 1, "label": "PNJ marchand propose une Rune"},
	"arc_milestone":   {"probability": 0.30, "max_per_run": 1, "label": "Arc narratif du biome atteint une etape-cle"},
	"random_3d_event": {"probability": 0.20, "max_per_run": 1, "label": "Evenement aleatoire 3D (rune/inscription)"},
	"fastroute_tag":   {"probability": 0.10, "max_per_run": 1, "label": "Carte FastRoute avec tag ogham_discovery"},
}
const OGHAM_DISCOVERY_MAX_PER_RUN: int = 2
const OGHAM_ALREADY_OWNED_ANAM_BONUS: int = 5  # +5 Anam si Ogham deja possede
const OGHAM_DISCOUNT_AFTER_DISCOVERY: float = 0.5  # -50% cout Anam post-decouverte

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
		"description": "Reduit de 1 le cooldown des Runes de categorie nature.",
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
		"description": "Double l'effet de guerison des Runes Recovery.",
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
		"description": "-1 cooldown global sur toutes les Runes.",
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
		"description": "-1 cooldown global sur toutes les Runes.",
		"lore": "Le flux des Runes repond plus vite a ta volonte.",
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
		"name": "Eveil de Rune",
		"cost": 35,
		"prerequisites": ["druides_1"],
		"effect": {"type": "special_rule", "id": "extra_ogham_slot"},
		"description": "Equipe 1 Rune supplementaire (1 → 2 actifs).",
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
			return {"title": "L'Ermite du Vent", "text": "Un sage solitaire a disparu dans les landes. Le vent porte encore ses paroles.", "name": "Landes de Bruyere"}
		"cotes", "cotes_sauvages":
			return {"title": "Le Phoque d'Argent", "text": "Un phoque d'argent apparait au large. Son chant te guide vers un mystere enfoui.", "name": "Cotes Sauvages"}
		"villages", "villages_celtes":
			return {"title": "L'Assemblee Secrete", "text": "Les anciens se reunissent en secret. Decouvre ce qu'ils preparent.", "name": "Villages Celtes"}
		"cercles", "cercles_pierres":
			return {"title": "Le Rituel Oublie", "text": "Les menhirs de Carnac resonnent d'un rituel oublie. Retrouve les gestes anciens.", "name": "Cercles de Pierres"}
		"marais", "marais_korrigans":
			return {"title": "Le Tresor des Feux", "text": "Les feux follets mènent a un tresor oublie. Mais les korrigans veillent.", "name": "Marais des Korrigans"}
		"collines", "collines_dolmens":
			return {"title": "La Voix des Rois", "text": "Les anciens rois parlent depuis les dolmens. Ecoute leur sagesse avant qu'elle ne s'eteigne.", "name": "Collines aux Dolmens"}
		"iles", "iles_mystiques":
			return {"title": "Le Passage de Morgane", "text": "Au-dela des brumes, Morgane attend. Trouve le passage avant que la maree ne le scelle.", "name": "Iles Mystiques"}
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

# Celtic festivals — real-world date ranges trigger themed card modifiers
const FESTIVALS := {
	"imbolc": {"month_start": 2, "day_start": 1, "month_end": 2, "day_end": 2,
		"label": "Imbolc", "faction": "druides", "rep_bonus": 5, "description": "Fete du renouveau et de la purification"},
	"beltane": {"month_start": 5, "day_start": 1, "month_end": 5, "day_end": 2,
		"label": "Beltane", "faction": "niamh", "rep_bonus": 5, "description": "Fete des feux et de la fertilite"},
	"lughnasadh": {"month_start": 8, "day_start": 1, "month_end": 8, "day_end": 2,
		"label": "Lughnasadh", "faction": "anciens", "rep_bonus": 5, "description": "Fete des moissons et de la force"},
	"samhain": {"month_start": 10, "day_start": 31, "month_end": 11, "day_end": 1,
		"label": "Samhain", "faction": "ankou", "rep_bonus": 5, "description": "Fete des morts et du passage"},
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
		"name": "Lanterne des Runes",
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
	"lanterne": "La Lanterne des Runes... elle revele ce que l'ombre cache.",
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
const FACTION_SCORE_START := 20  # Neutral on run 1 (was 0 = Hostile = -45 HP penalty)

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
	"druides":   ["druide", "ogham", "rune", "nemeton", "chene", "barde"],
	"anciens":   ["ancien", "ancetre", "tradition", "sagesse"],
	"korrigans": ["korrigan", "fee", "feu follet", "farce", "tresor"],
	"niamh":     ["niamh", "eau", "lac", "amour", "nostalgie"],
	"ankou":     ["ankou", "mort", "passage", "nuit", "ombre"],
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


# ═══════════════════════════════════════════════════════════════════════════════
# MAP SKELETON — Pre-run graph generation (biome-based node ranges)
# ═══════════════════════════════════════════════════════════════════════════════

## Main path node count per biome (before modifiers).
## detours_min/max = optional side-paths (each 2-4 extra cards).
const BIOME_NODE_RANGES: Dictionary = {
	"foret_broceliande": {"main_min": 10, "main_max": 15, "detours_min": 1, "detours_max": 2},
	"landes_bruyere":    {"main_min": 12, "main_max": 18, "detours_min": 1, "detours_max": 2},
	"cotes_sauvages":    {"main_min": 12, "main_max": 18, "detours_min": 1, "detours_max": 2},
	"villages_celtes":   {"main_min": 14, "main_max": 20, "detours_min": 2, "detours_max": 3},
	"cercles_pierres":   {"main_min": 16, "main_max": 25, "detours_min": 2, "detours_max": 3},
	"marais_korrigans":  {"main_min": 16, "main_max": 25, "detours_min": 2, "detours_max": 3},
	"collines_dolmens":  {"main_min": 20, "main_max": 30, "detours_min": 2, "detours_max": 3},
	"iles_mystiques":    {"main_min": 22, "main_max": 35, "detours_min": 3, "detours_max": 3},
}

## Reputation-based path modifiers.
const MAP_REP_SHORTCUT_THRESHOLD: int = 50   # -2 main nodes (known shortcut)
const MAP_REP_SHORTCUT_NODES: int = 2
const MAP_REP_SECRET_THRESHOLD: int = 80     # -4 main nodes + 1 secret detour
const MAP_REP_SECRET_NODES: int = 4

## Weather types — affect tone and event bias, chosen per-run by RNG + season.
const WEATHER_TYPES: Dictionary = {
	"clair":            {"tone": "serein",        "event_bias": "narrative", "season_weight": {"printemps": 3, "ete": 4, "automne": 2, "hiver": 1}},
	"brume_legere":     {"tone": "mystere",       "event_bias": "mystery",  "season_weight": {"printemps": 3, "ete": 1, "automne": 4, "hiver": 2}},
	"pluie":            {"tone": "melancolie",    "event_bias": "promise",  "season_weight": {"printemps": 2, "ete": 1, "automne": 4, "hiver": 3}},
	"orage":            {"tone": "tension",       "event_bias": "event",    "season_weight": {"printemps": 1, "ete": 3, "automne": 2, "hiver": 1}},
	"neige":            {"tone": "contemplation", "event_bias": "rest",     "season_weight": {"printemps": 0, "ete": 0, "automne": 1, "hiver": 4}},
	"brouillard_epais": {"tone": "danger",        "event_bias": "event",    "season_weight": {"printemps": 1, "ete": 0, "automne": 3, "hiver": 3}},
}

## Detour reward types — assigned by LLM or fallback generator.
const DETOUR_REWARDS: Dictionary = {
	"ogham_hint":       {"label": "Indice de Rune",      "icon": "\u1681", "description": "Revele une Rune cachee dans ce biome"},
	"anam_bonus":       {"label": "Source d'Anam",       "icon": "#",     "description": "Anam bonus (+15-25)", "min": 15, "max": 25},
	"lore_fragment":    {"label": "Fragment de Lore",    "icon": "\u2731", "description": "Texte exclusif sur l'histoire du biome"},
	"reputation_boost": {"label": "Faveur de Faction",   "icon": "\u2726", "description": "Bonus reputation (+10 faction du biome)", "amount": 10},
}

## Detour card count range (each detour = 2-4 extra cards).
const DETOUR_CARDS_MIN: int = 2
const DETOUR_CARDS_MAX: int = 4

## Map skeleton node types (extends NODE_TYPES with detour-specific types).
const SKELETON_NODE_TYPES: Array[String] = [
	"narrative", "event", "promise", "rest", "merchant",
	"mystery", "merlin", "detour_start", "detour_end",
]

## Tone progression template for arc structure.
const TONE_ARC: Array[String] = [
	"mystere", "exploration", "tension", "climax", "resolution", "sagesse",
]
