extends RefCounted
class_name MerlinConstants

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY (kept for compatibility, prefer REIGNS_ versions)
# ═══════════════════════════════════════════════════════════════════════════════

const VERBS := ["FORCE", "LOGIQUE", "FINESSE"]
const VERB_TO_ATTR := {
	"FORCE": "power",
	"LOGIQUE": "spirit",
	"FINESSE": "finesse",
}

const RUN_RESOURCES := ["Vigueur", "Concentration", "Materiel", "Faveur", "Nourriture"]
const RUN_RESOURCE_CAP := 9
const RUN_RESOURCE_CAPS := {
	"Vigueur": RUN_RESOURCE_CAP,
	"Concentration": RUN_RESOURCE_CAP,
	"Materiel": RUN_RESOURCE_CAP,
	"Faveur": RUN_RESOURCE_CAP,
	"Nourriture": RUN_RESOURCE_CAP,
}

const NEEDS := ["Hunger", "Energy", "Hygiene", "Mood", "Stress"]
const NEED_MIN := 0
const NEED_MAX := 100

const POSTURES := ["Prudence", "Agressif", "Ruse", "Serenite"]
const MERLIN_TONES := ["Protecteur", "Aventureux", "Pragmatique", "Sombre", "Pedagogue"]

const TEST_TYPES := ["DICE", "TIMING", "MEMORY", "AIM"]
const CHANCE_LEVELS := ["Low", "Medium", "High"]
const RISK_LEVELS := ["Light", "Moderate", "Severe"]

const ELEMENTS := [
	"NATURE", "FEU", "EAU", "TERRE", "AIR", "FOUDRE", "GLACE", "POISON",
	"METAL", "BETE", "ESPRIT", "OMBRE", "LUMIERE", "ARCANE"
]

const STATUS_IDS := [
	"BRULURE", "VENIN", "GEL", "PEUR", "CLAIRVOYANCE", "SURCHARGE"
]

const NODE_TYPES := ["COMBAT", "EVENT", "SHOP", "HEAL", "ELITE", "BOSS", "MYSTERY"]

# ═══════════════════════════════════════════════════════════════════════════════
# REIGNS-STYLE SYSTEM (NEW)
# ═══════════════════════════════════════════════════════════════════════════════

const REIGNS_GAUGES := ["Vigueur", "Esprit", "Faveur", "Ressources"]
const REIGNS_GAUGE_MIN := 0
const REIGNS_GAUGE_MAX := 100
const REIGNS_GAUGE_START := 50
const REIGNS_GAUGE_CRITICAL_LOW := 15
const REIGNS_GAUGE_CRITICAL_HIGH := 85

const REIGNS_CARD_TYPES := ["narrative", "event", "promise", "merlin_direct"]

const REIGNS_ENDINGS := {
	"vigueur_low": "L'Epuisement",
	"vigueur_high": "Le Surmenage",
	"esprit_low": "La Folie",
	"esprit_high": "La Possession",
	"faveur_low": "L'Exile",
	"faveur_high": "La Tyrannie",
	"ressources_low": "La Famine",
	"ressources_high": "Le Pillage",
}

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAMS AS BESTIOLE SKILLS
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_SKILLS := {
	# REVEAL category
	"beith": {"name": "Bouleau", "category": "reveal", "cooldown": 3, "effect": "reveal_one"},
	"coll": {"name": "Noisetier", "category": "reveal", "cooldown": 5, "effect": "reveal_all"},
	"ailm": {"name": "Sapin", "category": "reveal", "cooldown": 4, "effect": "predict_next"},
	# PROTECTION category
	"luis": {"name": "Sorbier", "category": "protection", "cooldown": 4, "effect": "reduce_30"},
	"gort": {"name": "Lierre", "category": "protection", "cooldown": 6, "effect": "absorb_one"},
	"eadhadh": {"name": "Tremble", "category": "protection", "cooldown": 8, "effect": "skip_negative"},
	# BOOST category
	"duir": {"name": "Chene", "category": "boost", "cooldown": 4, "effect": "boost_50"},
	"tinne": {"name": "Houx", "category": "boost", "cooldown": 5, "effect": "double_gain"},
	"onn": {"name": "Ajonc", "category": "boost", "cooldown": 7, "effect": "boost_20_3turns"},
	# NARRATIVE category
	"nuin": {"name": "Frene", "category": "narrative", "cooldown": 6, "effect": "add_option"},
	"huath": {"name": "Aubepine", "category": "narrative", "cooldown": 5, "effect": "change_card"},
	"straif": {"name": "Prunellier", "category": "narrative", "cooldown": 10, "effect": "force_rare"},
	# RECOVERY category
	"quert": {"name": "Pommier", "category": "recovery", "cooldown": 4, "effect": "heal_lowest_15"},
	"ruis": {"name": "Sureau", "category": "recovery", "cooldown": 8, "effect": "balance_gauges"},
	"saille": {"name": "Saule", "category": "recovery", "cooldown": 6, "effect": "regen_5_3turns"},
	# SPECIAL category
	"muin": {"name": "Vigne", "category": "special", "cooldown": 7, "effect": "invert_effects"},
	"ioho": {"name": "If", "category": "special", "cooldown": 12, "effect": "full_reroll"},
	"ur": {"name": "Bruyere", "category": "special", "cooldown": 10, "effect": "sacrifice_trade"},
}

const OGHAM_STARTER_SKILLS := ["beith", "luis", "quert"]

# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE BOND THRESHOLDS
# ═══════════════════════════════════════════════════════════════════════════════

const BOND_TIERS := {
	"distant": {"min": 0, "max": 30, "skills": 0, "modifier": 0.0},
	"friendly": {"min": 31, "max": 50, "skills": 1, "modifier": 0.05},
	"close": {"min": 51, "max": 70, "skills": 2, "modifier": 0.10},
	"bonded": {"min": 71, "max": 90, "skills": 3, "modifier": 0.15},
	"soulmate": {"min": 91, "max": 100, "skills": -1, "modifier": 0.20},  # -1 = all skills
}

# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM (v2.0 - Replaces Reigns gauges)
# ═══════════════════════════════════════════════════════════════════════════════

# 3 Aspects with 3 discrete states each
enum AspectState { BAS = -1, EQUILIBRE = 0, HAUT = 1 }

const TRIADE_ASPECTS := ["Corps", "Ame", "Monde"]

const TRIADE_ASPECT_INFO := {
	"Corps": {
		"symbol": "spirale",
		"animal": "sanglier",
		"theme": "Force physique, endurance, sante",
		"states": {
			AspectState.BAS: "Epuise",
			AspectState.EQUILIBRE: "Robuste",
			AspectState.HAUT: "Surmene"
		}
	},
	"Ame": {
		"symbol": "triskell",
		"animal": "corbeau",
		"theme": "Esprit, magie, equilibre mental",
		"states": {
			AspectState.BAS: "Perdue",
			AspectState.EQUILIBRE: "Centree",
			AspectState.HAUT: "Possedee"
		}
	},
	"Monde": {
		"symbol": "croix_celtique",
		"animal": "cerf",
		"theme": "Relations, reputation, harmonie sociale",
		"states": {
			AspectState.BAS: "Exile",
			AspectState.EQUILIBRE: "Integre",
			AspectState.HAUT: "Tyran"
		}
	}
}

# Souffle d'Ogham (resource for center option)
const SOUFFLE_MAX := 7
const SOUFFLE_START := 3
const SOUFFLE_CENTER_COST := 1

# Risk probabilities when using center without souffle
const SOUFFLE_EMPTY_RISK := {
	"normal": 0.50,       # 50% - effect as normal
	"aspect_down": 0.25,  # 25% - random aspect descends
	"aspect_up": 0.25     # 25% - random aspect ascends
}

# Card options (3 per card)
enum CardOption { LEFT = 0, CENTER = 1, RIGHT = 2 }

const TRIADE_OPTION_INFO := {
	CardOption.LEFT: {
		"name": "left",
		"type": "direct",
		"cost": 0,
		"description": "Action directe, consequences claires"
	},
	CardOption.CENTER: {
		"name": "center",
		"type": "wise",
		"cost": SOUFFLE_CENTER_COST,
		"description": "Action sage, souvent neutre"
	},
	CardOption.RIGHT: {
		"name": "right",
		"type": "risky",
		"cost": 0,
		"description": "Action audacieuse, consequences extremes"
	}
}

# Run end conditions: 2 aspects at extreme states
const TRIADE_ENDINGS := {
	# Corps Bas combinations
	"corps_bas_ame_basse": {
		"title": "La Mort Oubliee",
		"aspects": ["Corps", "Ame"],
		"states": [AspectState.BAS, AspectState.BAS]
	},
	"corps_bas_ame_haute": {
		"title": "Le Sacrifice Vain",
		"aspects": ["Corps", "Ame"],
		"states": [AspectState.BAS, AspectState.HAUT]
	},
	"corps_bas_monde_bas": {
		"title": "L'Abandon Total",
		"aspects": ["Corps", "Monde"],
		"states": [AspectState.BAS, AspectState.BAS]
	},
	"corps_bas_monde_haut": {
		"title": "L'Usurpation",
		"aspects": ["Corps", "Monde"],
		"states": [AspectState.BAS, AspectState.HAUT]
	},
	# Corps Haut combinations
	"corps_haut_ame_basse": {
		"title": "La Bete Sauvage",
		"aspects": ["Corps", "Ame"],
		"states": [AspectState.HAUT, AspectState.BAS]
	},
	"corps_haut_ame_haute": {
		"title": "L'Ascension Folle",
		"aspects": ["Corps", "Ame"],
		"states": [AspectState.HAUT, AspectState.HAUT]
	},
	"corps_haut_monde_bas": {
		"title": "Le Solitaire",
		"aspects": ["Corps", "Monde"],
		"states": [AspectState.HAUT, AspectState.BAS]
	},
	"corps_haut_monde_haut": {
		"title": "Le Conquerant",
		"aspects": ["Corps", "Monde"],
		"states": [AspectState.HAUT, AspectState.HAUT]
	},
	# Ame + Monde combinations (sans Corps)
	"ame_basse_monde_bas": {
		"title": "L'Errance Eternelle",
		"aspects": ["Ame", "Monde"],
		"states": [AspectState.BAS, AspectState.BAS]
	},
	"ame_basse_monde_haut": {
		"title": "Le Pantin",
		"aspects": ["Ame", "Monde"],
		"states": [AspectState.BAS, AspectState.HAUT]
	},
	"ame_haute_monde_bas": {
		"title": "Le Prophete Exile",
		"aspects": ["Ame", "Monde"],
		"states": [AspectState.HAUT, AspectState.BAS]
	},
	"ame_haute_monde_haut": {
		"title": "La Possession Divine",
		"aspects": ["Ame", "Monde"],
		"states": [AspectState.HAUT, AspectState.HAUT]
	}
}

# Victory endings
const TRIADE_VICTORY_ENDINGS := {
	"harmonie": {
		"title": "L'Harmonie",
		"condition": "Mission accomplie avec 3 aspects equilibres"
	},
	"prix_paye": {
		"title": "Le Prix Paye",
		"condition": "Mission accomplie avec 1 aspect extreme"
	},
	"victoire_amere": {
		"title": "La Victoire Amere",
		"condition": "Mission accomplie avec karma negatif"
	}
}

# Session duration targets
const TRIADE_SESSION := {
	"cards_min": 25,
	"cards_max": 35,
	"cards_target": 30,
	"seconds_per_card": 18,  # Average decision time
	"mission_reveal_card": 4,  # Mission revealed around card 4
	"climax_card_range": [20, 25]  # Climax around cards 20-25
}

# Hidden depth systems (for tracking)
const HIDDEN_DEPTH_LAYERS := [
	"resonances",
	"player_profile",
	"inter_run_echoes",
	"ogham_synergies",
	"hidden_quests",
	"lunar_cycles",
	"bestiole_personality",
	"narrative_debt"
]
