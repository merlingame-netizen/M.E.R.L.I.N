extends RefCounted
class_name MerlinConstants

# ═══════════════════════════════════════════════════════════════════════════════
# SHARED ENUMS & ELEMENT LIST
# ═══════════════════════════════════════════════════════════════════════════════

const MERLIN_TONES := ["Protecteur", "Aventureux", "Pragmatique", "Sombre", "Pedagogue"]

const ELEMENTS := [
	"NATURE", "FEU", "EAU", "TERRE", "AIR", "FOUDRE", "GLACE", "POISON",
	"METAL", "BETE", "ESPRIT", "OMBRE", "LUMIERE", "ARCANE"
]

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
# TRIADE SYSTEM (v2.0 - Replaces legacy gauges)
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

# ═══════════════════════════════════════════════════════════════════════════════
# REWARD TYPES — Badge display for card option hover (Phase UX)
# ═══════════════════════════════════════════════════════════════════════════════

const REWARD_TYPES := {
	"vie": {"icon": "\u2764", "label": "Vie", "color_key": "danger"},
	"essence": {"icon": "#", "label": "Essence", "color_key": "bestiole"},
	"souffle": {"icon": "*", "label": "Souffle", "color_key": "souffle"},
	"karma": {"icon": "\u2726", "label": "Karma", "color_key": "amber_bright"},
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
			"ADD_SOUFFLE":
				return "souffle"
			"USE_SOUFFLE":
				return "souffle"
			"ADD_KARMA":
				return "karma"
			"ADD_ESSENCE":
				return "essence"
	return "mystere"


# ═══════════════════════════════════════════════════════════════════════════════
# ESSENCE COLLECTIBLES — Fragments magiques lies aux categories Ogham
# ═══════════════════════════════════════════════════════════════════════════════

const ESSENCE_TYPES := {
	"eclat_bouleau": {"name": "Eclat de Bouleau", "category": "reveal", "rarity": "common", "icon": "<>"},
	"seve_sorbier": {"name": "Seve de Sorbier", "category": "protection", "rarity": "common", "icon": "^"},
	"coeur_chene": {"name": "Coeur de Chene", "category": "boost", "rarity": "uncommon", "icon": "\u2666"},
	"larme_saule": {"name": "Larme de Saule", "category": "recovery", "rarity": "uncommon", "icon": "\u2728"},
	"braise_prunellier": {"name": "Braise de Prunellier", "category": "narrative", "rarity": "rare", "icon": "\u2736"},
	"racine_if": {"name": "Racine d'If", "category": "special", "rarity": "rare", "icon": "\u2742"},
}

const ESSENCE_DROP_CHANCE := 0.2  # 20% on non-anchor SUCCESS
const ESSENCE_ANCHOR_DROP := 2    # Guaranteed +2 at anchor positions
const ESSENCE_NORMAL_DROP := 1    # +1 on SUCCESS (20% chance)
const ESSENCE_ANCHOR_CARDS: Array[int] = [3, 7, 12, 16]  # Guaranteed drop positions (0-indexed)

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

# Souffle d'Ogham — single-use run resource.
const SOUFFLE_MAX := 1
const SOUFFLE_START := 1
const SOUFFLE_SINGLE_USE := true

# Card options (3 per card — all FREE, no Souffle cost)
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
		"cost": 0,
		"description": "Action sage, equilibree"
	},
	CardOption.RIGHT: {
		"name": "right",
		"type": "risky",
		"cost": 0,
		"description": "Action audacieuse, consequences extremes"
	}
}

# ═══════════════════════════════════════════════════════════════════════════════
# LIFE ESSENCE — Survival gauge (Phase 43, inspired by Hand of Fate 2)
# At 0 = premature run end. Drains on critical failures, failed events, etc.
# ═══════════════════════════════════════════════════════════════════════════════

const LIFE_ESSENCE_MAX := 100
const LIFE_ESSENCE_START := 100
const LIFE_ESSENCE_DRAIN_PER_CARD := 1      # Base drain each card (survival pressure)
const MIN_CARDS_FOR_VICTORY := 25           # Must survive 25+ cards before victory allowed
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

# DC base ranges for variable DC system (replaces fixed 6/10/14)
const DC_BASE := {
	"left": {"min": 4, "max": 8, "default": 6},
	"center": {"min": 7, "max": 12, "default": 9},
	"right": {"min": 10, "max": 16, "default": 13},
}

# DC difficulty labels for UI display
const DC_DIFFICULTY_LABELS := {
	"easy": {"label": "Facile", "color": Color(0.35, 0.75, 0.35), "max_dc": 8},
	"normal": {"label": "Normal", "color": Color(0.85, 0.75, 0.25), "max_dc": 13},
	"hard": {"label": "Difficile", "color": Color(0.85, 0.30, 0.25), "max_dc": 20},
}

# B.3 — Archetype DC bonus: valeur negative = DC plus facile pour ce profil
# "default" s'applique a tous les choix; "biome" et "social" peuvent etre ajoutes
const ARCHETYPE_DC_BONUS := {
	"gardien":     -1,   # Defenseur: plus facile d'agir avec prudence
	"explorateur": +1,   # Aventureux: prend des risques, DC globalement plus eleve
	"sage":         0,   # Equilibre
	"heros":       -1,   # Heroique: facilite les actions directes
	"guerisseur":   0,   # Equilibre
	"stratege":    -1,   # Analytique: reduit les erreurs
	"mystique":     0,   # Equilibre intuitif
	"guide":       -1,   # Bienveillant: contexte social facilite
}

# B.4 — Aspect State DC modifiers
# Chaque etat d'aspect hors EQUILIBRE ajoute une penalite au DC.
# BAS = souffrance → actions plus difficiles.
# HAUT = debordement → risque accru, instabilite.
# Logique: nb_bas * PENALTY_BAS + nb_haut * PENALTY_HAUT (cumulatif par aspect).
const ASPECT_DC_PENALTY_BAS := 2    # Par aspect en etat BAS
const ASPECT_DC_PENALTY_HAUT := 1   # Par aspect en etat HAUT (surmenage)
const ASPECT_DC_BONUS_FULL_EQUILIBRE := -1  # Bonus si TOUS les aspects sont EQUILIBRE

# Labels narratifs pour les etats extremes (utilises dans le contexte RAG)
const ASPECT_STATE_NARRATIVE := {
	"Corps": {
		AspectState.BAS:  "Corps Epuise — tes forces te font defaut.",
		AspectState.HAUT: "Corps Surmene — tu te depenses au-dela du raisonnable.",
	},
	"Ame": {
		AspectState.BAS:  "Ame Perdue — tu doutes, la magie te fuit.",
		AspectState.HAUT: "Ame Possedee — les forces obscures te guidant avec trop de zele.",
	},
	"Monde": {
		AspectState.BAS:  "Monde: Tu es exile, les liens sociaux s'effritent.",
		AspectState.HAUT: "Monde: Tu rules en tyran, la resistance monte.",
	},
}

# Souffle Perk types (Phase B — stub for now)
const SOUFFLE_PERK_TYPES := {
	"bouclier": {
		"name": "Bouclier",
		"description": "Annule les effets negatifs du prochain choix",
		"uses_per_run": 1,
	},
	"surge": {
		"name": "Surge",
		"description": "Double les effets positifs + DC-5",
		"uses_per_run": 1,
	},
	"vision": {
		"name": "Vision",
		"description": "Revele tous les effets caches + predit prochaine carte",
		"uses_per_run": 1,
	},
	"canalisation": {
		"name": "Canalisation",
		"description": "Bestiole canalise une rune — effet puissant lie a l'Ogham equipe",
		"uses_per_run": 1,
	},
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
	},
	"tyran_juste": {
		"title": "Le Tyran Juste",
		"description": "Tu as conquis par la force, mais gouverne avec sagesse.",
		"condition": "Mission accomplie avec Monde=HAUT, Corps=EQUILIBRE, Ame=EQUILIBRE"
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

# ═══════════════════════════════════════════════════════════════════════════════
# POWER MILESTONES — Player gets stronger every 5 cards during a run
# ═══════════════════════════════════════════════════════════════════════════════

const POWER_MILESTONES := {
	5: {"type": "HEAL", "value": 15, "label": "Vigueur retrouvee", "desc": "+15 Vie"},
	10: {"type": "DC_REDUCTION", "value": 2, "label": "Instinct aiguise", "desc": "DCs -2"},
	15: {"type": "SOUFFLE_RECOVER", "value": 1, "label": "Souffle du druide", "desc": "+1 Souffle"},
	20: {"type": "HEAL", "value": 20, "label": "Benediction ancienne", "desc": "+20 Vie"},
}

# ═══════════════════════════════════════════════════════════════════════════════
# SOUFFLE D'AWEN — Bestiole Ogham Resource (separate from Souffle d'Ogham)
# ═══════════════════════════════════════════════════════════════════════════════

const AWEN_MAX := 5
const AWEN_START := 2
const AWEN_REGEN_INTERVAL := 5  # +1 every N cards played
const AWEN_REGEN_EQUILIBRE_BONUS := 1  # +1 extra if all 3 aspects balanced

# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM FULL SPECS — Complete Ogham definitions for Triade system
# ═══════════════════════════════════════════════════════════════════════════════

const OGHAM_CATEGORIES := ["reveal", "protection", "boost", "narrative", "recovery", "special"]

const OGHAM_CATEGORY_COLORS := {
	"reveal": Color(0.294, 0.706, 0.902),
	"protection": Color(0.314, 0.745, 0.529),
	"boost": Color(1.0, 0.824, 0.0),
	"narrative": Color(0.659, 0.529, 0.847),
	"recovery": Color(1.0, 0.706, 0.902),
	"special": Color(0.733, 0.290, 0.251),
}

const OGHAM_CATEGORY_LABELS := {
	"reveal": "Revelation",
	"protection": "Protection",
	"boost": "Force",
	"narrative": "Recit",
	"recovery": "Guerison",
	"special": "Secret",
}

const OGHAM_FULL_SPECS := {
	# ── REVEAL ──
	"beith": {
		"name": "Bouleau", "tree": "Betula", "unicode": "\u1681",
		"category": "reveal", "awen_cost": 1, "cooldown": 3, "starter": true,
		"effect": "reveal_one",
		"description": "Revele l'effet d'une option au choix",
		"bond_required": 0,
	},
	"coll": {
		"name": "Noisetier", "tree": "Corylus", "unicode": "\u1685",
		"category": "reveal", "awen_cost": 2, "cooldown": 5, "starter": false,
		"effect": "reveal_all",
		"description": "Revele les effets de toutes les options",
		"bond_required": 21,
	},
	"ailm": {
		"name": "Sapin", "tree": "Abies", "unicode": "\u168f",
		"category": "reveal", "awen_cost": 2, "cooldown": 4, "starter": false,
		"effect": "predict_next",
		"description": "Predit le theme de la prochaine carte",
		"bond_required": 41,
	},
	# ── PROTECTION ──
	"luis": {
		"name": "Sorbier", "tree": "Sorbus", "unicode": "\u1682",
		"category": "protection", "awen_cost": 1, "cooldown": 4, "starter": true,
		"effect": "shield_shift",
		"description": "Empeche le prochain shift negatif d'aspect",
		"bond_required": 0,
	},
	"gort": {
		"name": "Lierre", "tree": "Hedera", "unicode": "\u168c",
		"category": "protection", "awen_cost": 2, "cooldown": 6, "starter": false,
		"effect": "absorb_extreme",
		"description": "Si un aspect atteint un extreme, le ramene a equilibre",
		"bond_required": 41,
	},
	"eadhadh": {
		"name": "Tremble", "tree": "Populus", "unicode": "\u1690",
		"category": "protection", "awen_cost": 3, "cooldown": 8, "starter": false,
		"effect": "skip_negative",
		"description": "Annule tous les effets negatifs de la carte choisie",
		"bond_required": 61,
	},
	# ── BOOST ──
	"duir": {
		"name": "Chene", "tree": "Quercus", "unicode": "\u1687",
		"category": "boost", "awen_cost": 2, "cooldown": 4, "starter": false,
		"effect": "force_equilibre",
		"description": "Force un aspect au choix vers Equilibre",
		"bond_required": 21,
	},
	"tinne": {
		"name": "Houx", "tree": "Ilex", "unicode": "\u1688",
		"category": "boost", "awen_cost": 2, "cooldown": 5, "starter": false,
		"effect": "double_positive",
		"description": "Double les effets positifs de la prochaine carte",
		"bond_required": 41,
	},
	"onn": {
		"name": "Ajonc", "tree": "Ulex", "unicode": "\u1689",
		"category": "boost", "awen_cost": 3, "cooldown": 7, "starter": false,
		"effect": "souffle_boost",
		"description": "Regenere 2 Souffle d'Ogham",
		"bond_required": 61,
	},
	# ── NARRATIVE ──
	"nuin": {
		"name": "Frene", "tree": "Fraxinus", "unicode": "\u1684",
		"category": "narrative", "awen_cost": 2, "cooldown": 6, "starter": false,
		"effect": "add_option",
		"description": "Ajoute une 4eme option a la carte actuelle",
		"bond_required": 41,
	},
	"huath": {
		"name": "Aubepine", "tree": "Crataegus", "unicode": "\u1686",
		"category": "narrative", "awen_cost": 2, "cooldown": 5, "starter": false,
		"effect": "change_card",
		"description": "Remplace la carte actuelle par une autre",
		"bond_required": 21,
	},
	"straif": {
		"name": "Prunellier", "tree": "Prunus", "unicode": "\u1693",
		"category": "narrative", "awen_cost": 3, "cooldown": 10, "starter": false,
		"effect": "force_twist",
		"description": "Force un retournement de situation",
		"bond_required": 81,
	},
	# ── RECOVERY ──
	"quert": {
		"name": "Pommier", "tree": "Malus", "unicode": "\u168a",
		"category": "recovery", "awen_cost": 1, "cooldown": 4, "starter": true,
		"effect": "heal_worst",
		"description": "Ramene l'aspect le plus extreme vers Equilibre",
		"bond_required": 0,
	},
	"ruis": {
		"name": "Sureau", "tree": "Sambucus", "unicode": "\u1694",
		"category": "recovery", "awen_cost": 3, "cooldown": 8, "starter": false,
		"effect": "balance_all",
		"description": "Ramene tous les aspects vers Equilibre",
		"bond_required": 61,
	},
	"saille": {
		"name": "Saule", "tree": "Salix", "unicode": "\u1691",
		"category": "recovery", "awen_cost": 2, "cooldown": 6, "starter": false,
		"effect": "regen_awen",
		"description": "Regenere 2 Souffle d'Awen",
		"bond_required": 41,
	},
	# ── SPECIAL ──
	"muin": {
		"name": "Vigne", "tree": "Vitis", "unicode": "\u168d",
		"category": "special", "awen_cost": 2, "cooldown": 7, "starter": false,
		"effect": "invert_effects",
		"description": "Inverse les effets positifs et negatifs de la carte",
		"bond_required": 41,
	},
	"ioho": {
		"name": "If", "tree": "Taxus", "unicode": "\u1695",
		"category": "special", "awen_cost": 3, "cooldown": 12, "starter": false,
		"effect": "full_reroll",
		"description": "Regenere une carte completement nouvelle",
		"bond_required": 81,
	},
	"ur": {
		"name": "Bruyere", "tree": "Calluna", "unicode": "\u1692",
		"category": "special", "awen_cost": 3, "cooldown": 10, "starter": false,
		"effect": "sacrifice_trade",
		"description": "Sacrifie 1 aspect extreme pour booster les 2 autres",
		"bond_required": 61,
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# FLUX SYSTEM — Hidden energy balance (Phase 35)
# 3 axes: Terre (Environment), Esprit (Narrative), Lien (Difficulty)
# ═══════════════════════════════════════════════════════════════════════════════

const FLUX_START := {"terre": 50, "esprit": 30, "lien": 40}
const FLUX_MIN := 0
const FLUX_MAX := 100

# Choice → Flux modification
const FLUX_CHOICE_DELTA := {
	"left": {"terre": 5, "esprit": 2, "lien": -3},
	"center": {"terre": 3, "esprit": 8, "lien": -2},
	"right": {"terre": -5, "esprit": 3, "lien": 8},
}

# Tier thresholds for each Flux axis
const FLUX_TIERS := {
	"terre": {
		"hostile": {"min": 0, "max": 30, "label": "Hostile", "dc_mod": 0},
		"neutre": {"min": 31, "max": 69, "label": "Neutre", "dc_mod": 0},
		"harmonieux": {"min": 70, "max": 100, "label": "Harmonieux", "dc_mod": 0},
	},
	"esprit": {
		"stagnant": {"min": 0, "max": 30, "label": "Stagnant", "dc_mod": 0},
		"montee": {"min": 31, "max": 69, "label": "Montee", "dc_mod": 0},
		"climax": {"min": 70, "max": 100, "label": "Climax", "dc_mod": 0},
	},
	"lien": {
		"calme": {"min": 0, "max": 30, "label": "Calme", "dc_mod": -2},
		"modere": {"min": 31, "max": 69, "label": "Modere", "dc_mod": 0},
		"brutal": {"min": 70, "max": 100, "label": "Brutal", "dc_mod": 3},
	},
}

# Flux tier → LLM context hints
const FLUX_HINTS := {
	"terre": {
		"hostile": "Le monde est hostile, la nature se retourne.",
		"neutre": "",
		"harmonieux": "La nature murmure en ta faveur.",
	},
	"esprit": {
		"stagnant": "",
		"montee": "Le recit s'intensifie.",
		"climax": "Le destin se cristallise, chaque choix est decisif.",
	},
	"lien": {
		"calme": "Le chemin est calme.",
		"modere": "",
		"brutal": "Le danger rode, chaque pas est un defi.",
	},
}

# Flux → Essence rewards at run end
const FLUX_ESSENCE_REWARDS := {
	"terre_high": {"threshold": 70, "rewards": {"NATURE": 5, "EAU": 3}},
	"terre_low": {"threshold_below": 30, "rewards": {"METAL": 5, "POISON": 3}},
	"esprit_high": {"threshold": 70, "rewards": {"ESPRIT": 8, "ARCANE": 5}},
	"lien_high": {"threshold": 70, "rewards": {"FEU": 5, "FOUDRE": 3}},
}

# ═══════════════════════════════════════════════════════════════════════════════
# ESSENCE REWARDS — Run end rewards (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

const ESSENCE_BASE_REWARDS := {"TERRE": 5, "NATURE": 3}  # Always earned
const ESSENCE_VICTORY_BONUS := {"LUMIERE": 8, "FOUDRE": 5}
const ESSENCE_CHUTE_BONUS := {"OMBRE": 5, "GLACE": 3}
const ESSENCE_BALANCED_BONUS := {"LUMIERE": 10}  # All 3 aspects at EQUILIBRE
const ESSENCE_BOND_BONUS := {"BETE": 5, "NATURE": 3}  # Bond > 70
const ESSENCE_MINIGAME_BONUS := {"AIR": 4}  # 5+ mini-games won
const ESSENCE_OGHAM_BONUS := {"ARCANE": 5}  # 3+ Oghams used

# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE EVOLUTION — Persistent across runs (Phase 35)
# ═══════════════════════════════════════════════════════════════════════════════

const BESTIOLE_EVOLUTION_STAGES := {
	1: {"name": "Enfant", "bond_base": 10, "awen_bonus": 0, "runs_required": 0, "essence_cost": {}},
	2: {"name": "Compagnon", "bond_base": 30, "awen_bonus": 1, "runs_required": 15, "essence_cost": {}},
	3: {"name": "Gardien", "bond_base": 50, "awen_bonus": 2, "runs_required": 40, "essence_cost": {"BETE": 200}},
}

const BESTIOLE_EVOLUTION_PATHS := {
	"protecteur": {"name": "Protecteur", "aspect": "Corps", "runs_focused": 25, "cost": {"BETE": 150, "TERRE": 80}, "bonus": "negative_effects_minus_15"},
	"oracle": {"name": "Oracle", "aspect": "Ame", "runs_focused": 25, "cost": {"BETE": 150, "ESPRIT": 80}, "bonus": "card_preview_1"},
	"diplomate": {"name": "Diplomate", "aspect": "Monde", "runs_focused": 25, "cost": {"BETE": 150, "EAU": 80}, "bonus": "liens_plus_5"},
}

const BESTIOLE_BOND_RETENTION := 0.4  # Keep 40% of bond between runs

# ═══════════════════════════════════════════════════════════════════════════════
# ARBRE DE VIE — Talent Tree (Phase 35)
# 28 nodes: 8 Racines (Corps) + 8 Ramures (Ame) + 8 Feuillage (Monde) + 4 Tronc
# ═══════════════════════════════════════════════════════════════════════════════

const TALENT_NODES := {
	# ── RACINES (Corps / Sanglier) ──────────────────────────────────────────
	"racines_1": {
		"branch": "Corps", "tier": 1,
		"name": "Souffle Fortifie",
		"cost": {"TERRE": 15, "fragments": 1},
		"prerequisites": [],
		"effect": {"type": "modify_start", "target": "souffle", "value": 1},
		"description": "Commence chaque run avec 1 Souffle supplementaire.",
		"lore": "Les racines du Sanglier nourrissent le souffle de la terre.",
	},
	"racines_2": {
		"branch": "Corps", "tier": 1,
		"name": "Endurance Naturelle",
		"cost": {"NATURE": 20},
		"prerequisites": [],
		"effect": {"type": "cancel_first_shift", "aspect": "Corps", "direction": "down"},
		"description": "Annule le 1er shift Corps BAS de chaque run.",
		"lore": "La chair du Sanglier ne flanche pas au premier choc.",
	},
	"racines_3": {
		"branch": "Corps", "tier": 1,
		"name": "Peau de Chene",
		"cost": {"METAL": 15},
		"prerequisites": [],
		"effect": {"type": "modify_start", "target": "blessings", "value": 1},
		"description": "Commence chaque run avec 1 Benediction supplementaire.",
		"lore": "L'ecorce du chene protege ceux qui la meritent.",
	},
	"racines_4": {
		"branch": "Corps", "tier": 2,
		"name": "Coeur de Sanglier",
		"cost": {"TERRE": 50, "GLACE": 20, "fragments": 3},
		"prerequisites": ["racines_1", "racines_2"],
		"effect": {"type": "special_rule", "id": "corps_bas_souffle_bonus"},
		"description": "Quand Corps = BAS, gagne +2 Souffle au lieu de 0.",
		"lore": "Plus il tombe bas, plus le Sanglier puise dans ses reserves.",
	},
	"racines_5": {
		"branch": "Corps", "tier": 2,
		"name": "Racines Profondes",
		"cost": {"NATURE": 40, "METAL": 20},
		"prerequisites": ["racines_2", "racines_3"],
		"effect": {"type": "special_rule", "id": "equilibre_souffle_double"},
		"description": "Aspects equilibres: +2 Souffle (au lieu de +1).",
		"lore": "L'equilibre nourrit les racines les plus profondes.",
	},
	"racines_6": {
		"branch": "Corps", "tier": 3,
		"name": "Reservoir Vital",
		"cost": {"TERRE": 80, "NATURE": 30, "fragments": 6},
		"prerequisites": ["racines_4"],
		"effect": {"type": "modify_start", "target": "souffle_max", "value": 2},
		"description": "Souffle MAX +2 (de 5 a 7).",
		"lore": "Le Sanglier puise dans une source intarissable.",
	},
	"racines_7": {
		"branch": "Corps", "tier": 3,
		"name": "Os de la Terre",
		"cost": {"METAL": 60, "GLACE": 40, "fragments": 5},
		"prerequisites": ["racines_5"],
		"effect": {"type": "special_rule", "id": "survive_game_over_once"},
		"description": "Survit a 1 game over par run (consomme benediction).",
		"lore": "Les os de la terre ne se brisent qu'une fois.",
	},
	"racines_8": {
		"branch": "Corps", "tier": 4,
		"name": "Sanglier Ancestral",
		"cost": {"TERRE": 120, "NATURE": 60, "fragments": 10},
		"prerequisites": ["racines_6", "racines_7"],
		"effect": {"type": "special_rule", "id": "corps_haut_positive"},
		"description": "Corps HAUT devient positif (+1 Souffle, pas de game over).",
		"lore": "Le Sanglier Ancestral transcende ses limites.",
	},
	# ── RAMURES (Ame / Corbeau) ─────────────────────────────────────────────
	"ramures_1": {
		"branch": "Ame", "tier": 1,
		"name": "Clarte Interieure",
		"cost": {"LUMIERE": 15, "fragments": 1},
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "reveal_one_effect"},
		"description": "Revele 1 effet de choix par carte.",
		"lore": "Le Corbeau voit ce que les yeux ne percoivent pas.",
	},
	"ramures_2": {
		"branch": "Ame", "tier": 1,
		"name": "Flamme Spirituelle",
		"cost": {"ESPRIT": 20},
		"prerequisites": [],
		"effect": {"type": "modify_start", "target": "awen", "value": 1},
		"description": "Commence chaque run avec +1 Awen.",
		"lore": "L'esprit brule plus vif chez ceux qui ecoutent.",
	},
	"ramures_3": {
		"branch": "Ame", "tier": 1,
		"name": "Echo des Runes",
		"cost": {"ARCANE": 15},
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "show_minigame_type"},
		"description": "Voir le type de mini-jeu avant de jouer.",
		"lore": "Les runes chuchotent l'epreuve a venir.",
	},
	"ramures_4": {
		"branch": "Ame", "tier": 2,
		"name": "Maitrise d'Awen",
		"cost": {"ESPRIT": 50, "FOUDRE": 20, "fragments": 3},
		"prerequisites": ["ramures_1", "ramures_2"],
		"effect": {"type": "special_rule", "id": "awen_regen_faster"},
		"description": "Awen se regenere toutes les 4 cartes (au lieu de 5).",
		"lore": "Le flux d'Awen repond a la maitrise interieure.",
	},
	"ramures_5": {
		"branch": "Ame", "tier": 2,
		"name": "Troisieme Oeil",
		"cost": {"LUMIERE": 40, "ARCANE": 20},
		"prerequisites": ["ramures_1", "ramures_3"],
		"effect": {"type": "special_rule", "id": "predict_next_theme"},
		"description": "Predit le theme de la prochaine carte.",
		"lore": "Le troisieme oeil du Corbeau perce le voile du temps.",
	},
	"ramures_6": {
		"branch": "Ame", "tier": 3,
		"name": "Corbeau Omniscient",
		"cost": {"LUMIERE": 80, "ESPRIT": 30, "fragments": 6},
		"prerequisites": ["ramures_4"],
		"effect": {"type": "special_rule", "id": "reveal_oghams_cheaper"},
		"description": "Oghams 'reveal' coutent -1 Awen.",
		"lore": "Le Corbeau voit tout sans effort.",
	},
	"ramures_7": {
		"branch": "Ame", "tier": 3,
		"name": "Memoire des Boucles",
		"cost": {"ARCANE": 60, "FOUDRE": 40, "fragments": 5},
		"prerequisites": ["ramures_5"],
		"effect": {"type": "special_rule", "id": "know_ending_condition"},
		"description": "Connaitre 1 condition de fin aleatoire au debut de run.",
		"lore": "Merlin murmure: 'Je me souviens de cette boucle...'",
	},
	"ramures_8": {
		"branch": "Ame", "tier": 4,
		"name": "Fusion Ame-Bestiole",
		"cost": {"ESPRIT": 120, "LUMIERE": 60, "fragments": 10},
		"prerequisites": ["ramures_6", "ramures_7"],
		"effect": {"type": "modify_start", "target": "bond", "value": 60},
		"description": "Bond demarre a 60 (tier 'close').",
		"lore": "L'ame et la Bestiole ne font plus qu'un.",
	},
	# ── FEUILLAGE (Monde / Cerf) ────────────────────────────────────────────
	"feuillage_1": {
		"branch": "Monde", "tier": 1,
		"name": "Diplomatie Innee",
		"cost": {"EAU": 15, "fragments": 1},
		"prerequisites": [],
		"effect": {"type": "cancel_first_shift", "aspect": "Monde", "direction": "up"},
		"description": "Annule le 1er shift Monde HAUT de chaque run.",
		"lore": "Le Cerf apaise les conflits avant qu'ils n'eclatent.",
	},
	"feuillage_2": {
		"branch": "Monde", "tier": 1,
		"name": "Flux Harmonieux",
		"cost": {"AIR": 20},
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "free_center_once"},
		"description": "1 Centre gratuit par run (0 Souffle).",
		"lore": "L'air porte le souffle sans effort.",
	},
	"feuillage_3": {
		"branch": "Monde", "tier": 1,
		"name": "Instinct Animal",
		"cost": {"BETE": 15},
		"prerequisites": [],
		"effect": {"type": "special_rule", "id": "minigame_field_bonus"},
		"description": "Bonus +5% score sur detection du champ lexical mini-jeu.",
		"lore": "L'instinct du Cerf devine la nature de l'epreuve.",
	},
	"feuillage_4": {
		"branch": "Monde", "tier": 2,
		"name": "Ruse du Renard",
		"cost": {"POISON": 50, "AIR": 20, "fragments": 3},
		"prerequisites": ["feuillage_1", "feuillage_2"],
		"effect": {"type": "special_rule", "id": "critical_dc_reduced"},
		"description": "Choix critique: DC +2 (au lieu de +4).",
		"lore": "La ruse adoucit les epreuves les plus dures.",
	},
	"feuillage_5": {
		"branch": "Monde", "tier": 2,
		"name": "Courant Adaptable",
		"cost": {"EAU": 40, "BETE": 20},
		"prerequisites": ["feuillage_2", "feuillage_3"],
		"effect": {"type": "special_rule", "id": "biome_change_souffle"},
		"description": "Changement de biome: +2 Souffle.",
		"lore": "Comme l'eau, le druide s'adapte a chaque terrain.",
	},
	"feuillage_6": {
		"branch": "Monde", "tier": 3,
		"name": "Cerf Communaute",
		"cost": {"AIR": 80, "EAU": 30, "fragments": 6},
		"prerequisites": ["feuillage_4"],
		"effect": {"type": "special_rule", "id": "unlock_alliance_missions"},
		"description": "Debloque les missions 'Alliance' (haute recompense).",
		"lore": "Le troupeau du Cerf ouvre des chemins nouveaux.",
	},
	"feuillage_7": {
		"branch": "Monde", "tier": 3,
		"name": "Venin Bienveillant",
		"cost": {"POISON": 60, "BETE": 40, "fragments": 5},
		"prerequisites": ["feuillage_5"],
		"effect": {"type": "special_rule", "id": "negative_effects_reduced"},
		"description": "Effets negatifs -30% (arrondis).",
		"lore": "Le venin, a petite dose, devient remede.",
	},
	"feuillage_8": {
		"branch": "Monde", "tier": 4,
		"name": "Roi sans Couronne",
		"cost": {"EAU": 120, "AIR": 60, "fragments": 10},
		"prerequisites": ["feuillage_6", "feuillage_7"],
		"effect": {"type": "special_rule", "id": "tyran_juste_ending"},
		"description": "Monde HAUT debloque la fin secrete 'Tyran Juste'.",
		"lore": "Le Cerf qui guide sans regner atteint la vraie puissance.",
	},
	# ── TRONC (Universel) ───────────────────────────────────────────────────
	"tronc_1": {
		"branch": "Universel", "tier": 2,
		"name": "Equilibre des Feux",
		"cost": {"FEU": 40, "fragments": 3},
		"prerequisites": ["racines_1", "ramures_1", "feuillage_1"],
		"effect": {"type": "special_rule", "id": "flux_start_balanced"},
		"description": "Flux commencent a 50/50/50 (au lieu de 50/30/40).",
		"lore": "Les trois feux s'alignent a l'aurore.",
	},
	"tronc_2": {
		"branch": "Universel", "tier": 3,
		"name": "Voile Perce",
		"cost": {"OMBRE": 80, "FEU": 40, "fragments": 6},
		"prerequisites": ["tronc_1"],
		"effect": {"type": "special_rule", "id": "show_flux_hints"},
		"description": "Voir Karma et Flux (indices textuels) pendant la run.",
		"lore": "Derriere le voile, les courants se revelent.",
	},
	"tronc_3": {
		"branch": "Universel", "tier": 3,
		"name": "Triade Parfaite",
		"cost": {"FEU": 60, "OMBRE": 60, "fragments": 8},
		"prerequisites": ["racines_4", "ramures_4", "feuillage_4"],
		"effect": {"type": "special_rule", "id": "triade_parfaite_bonus"},
		"description": "3 aspects equilibres: +3 Souffle + ignore prochain shift negatif.",
		"lore": "L'harmonie parfaite accorde un souffle divin.",
	},
	"tronc_4": {
		"branch": "Universel", "tier": 4,
		"name": "Boucle Eternelle",
		"cost": {"FEU": 150, "OMBRE": 150, "fragments": 20},
		"prerequisites": ["tronc_2", "tronc_3"],
		"effect": {"type": "special_rule", "id": "new_game_plus"},
		"description": "New Game+: essences x1.5, fin secrete ultime.",
		"lore": "La boucle se referme. Et recommence, plus forte.",
	},
	# ── CALENDRIER DES BRUMES (CAL-REQ-050) ────────────────────────────────
	"calendrier_des_brumes": {
		"branch": "Ame", "tier": 2,
		"name": "Calendrier des Brumes",
		"cost": {"ESPRIT": 40, "OMBRE": 25, "fragments": 3},
		"prerequisites": ["ramures_1"],
		"effect": {"type": "special_rule", "id": "calendrier_des_brumes"},
		"description": "Revele 7 prochains evenements. Primes aux evenements atteints.",
		"lore": "A travers les brumes, Merlin te montre ce qui vient...",
	},
}

# Achievement for unlocking Calendrier des Brumes
const ACHIEVEMENT_PELERIN_DES_DATES := {
	"id": "pelerin_des_dates",
	"name": "Pelerin des Dates",
	"description": "Participe a 8 evenements calendaires.",
	"condition": {"events_participated": 8},
	"reward": "calendrier_des_brumes",
}

# Talent branch colors for UI
const TALENT_BRANCH_COLORS := {
	"Corps": Color(0.55, 0.40, 0.25),     # Earthy brown
	"Ame": Color(0.40, 0.45, 0.70),       # Ethereal blue
	"Monde": Color(0.35, 0.55, 0.35),     # Forest green
	"Universel": Color(0.65, 0.45, 0.20), # Amber
}

# Talent tier names
const TALENT_TIER_NAMES := {1: "Germe", 2: "Pousse", 3: "Branche", 4: "Cime"}

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME SYSTEM — 7 Celtic Biomes for TRIADE (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

const BIOME_KEYS := [
	"foret_broceliande", "landes_bruyere", "cotes_sauvages",
	"villages_celtes", "cercles_pierres", "marais_korrigans", "collines_dolmens"
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
	return {}

# Card type distribution weights (TRIADE mode)
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
		"aspect_bias": "Corps",
		"bias_direction": "up",
		"narrative_tone": "renouveau",
		"event_weight_mod": 1.1,
	},
	"summer": {
		"label": "Ete",
		"aspect_bias": "Monde",
		"bias_direction": "up",
		"narrative_tone": "aventure",
		"event_weight_mod": 1.0,
	},
	"autumn": {
		"label": "Automne",
		"aspect_bias": "Ame",
		"bias_direction": "up",
		"narrative_tone": "reflexion",
		"event_weight_mod": 1.15,
	},
	"winter": {
		"label": "Hiver",
		"aspect_bias": "Ame",
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
# MAP NODE TYPES — STS-like map for TRIADE (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

const TRIADE_NODE_TYPES := {
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
		"bonus": "+1 Souffle au depart",
		"bonus_field": "",
		"dc_bonus": 0,
		"initial_effect": {"type": "ADD_SOUFFLE", "amount": 1},
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

const DEPARTURE_CONDITIONS := {
	"jour": {
		"name": "Partir de jour",
		"icon": "\u2600",  # Sun
		"description": "Le chemin est clair",
		"effect_label": "Normal",
		"initial_effects": [],
	},
	"nuit": {
		"name": "Partir de nuit",
		"icon": "\u263D",  # Moon
		"description": "Plus risque, plus de karma",
		"effect_label": "+karma, DCs +2",
		"initial_effects": [{"type": "KARMA", "amount": 3}, {"type": "DC_OFFSET", "amount": 2}],
	},
	"compagnon": {
		"name": "Avec compagnon",
		"icon": "\u2660",  # Spade (companion)
		"description": "Le Monde repond mieux",
		"effect_label": "Monde +1",
		"initial_effects": [{"type": "HEAL_LIFE", "amount": 10}],
	},
	"leger": {
		"name": "Voyager leger",
		"icon": "\u2192",  # Arrow right
		"description": "Mission plus courte",
		"effect_label": "-2 cartes mission",
		"initial_effects": [{"type": "MISSION_REDUCTION", "amount": 2}],
	},
}

const EXPEDITION_MERLIN_REACTIONS := {
	"baton_marche": "Le Baton de Marche... un classique. Il ne te trahira pas.",
	"besace": "La Besace ! Provisions et prudence. Tu es sage.",
	"lanterne": "La Lanterne d'Ogham... elle revele ce que l'ombre cache.",
	"talisman": "Le Talisman vibre deja. Il sent le voyage.",
	"jour": "De jour. La lumiere protege... mais attire aussi.",
	"nuit": "De nuit ? Courageux. Les ombres seront plus bavard.",
	"compagnon": "Un compagnon ! Le Monde sourit aux liens.",
	"leger": "Voyager leger... rapide, mais tu sacrifies la preparation.",
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEME D'ALIGNEMENT — 5 Factions avec réputations pondérées
# Scores -100 à +100, persistance cross-run (state["meta"]["faction_rep"])
# Ref : docs/20_card_system/DOC_15_Faction_Alignment_System.md
# ═══════════════════════════════════════════════════════════════════════════════

const FACTIONS := ["druides", "korrigans", "humains", "anciens", "ankou"]

const FACTION_INFO := {
	"druides":   {"name": "Druides de Bretagne", "symbol": "chene",      "aspect_affinity": "Ame"},
	"korrigans": {"name": "Korrigans des Marais", "symbol": "champignon", "aspect_affinity": "Monde"},
	"humains":   {"name": "Clans Humains",         "symbol": "epee",      "aspect_affinity": "Corps"},
	"anciens":   {"name": "Les Anciens",            "symbol": "menhir",    "aspect_affinity": "Ame"},
	"ankou":     {"name": "L'Ankou",                "symbol": "faux",      "aspect_affinity": "Corps"},
}

const FACTION_SCORE_MIN := -100
const FACTION_SCORE_MAX := 100
const FACTION_SCORE_START := 0

# Bandes de seuil — évalués du plus haut (honore) au plus bas (hostile)
const FACTION_TIERS := {
	"honore":       {"min": 60,   "label": "Honore"},
	"sympathisant": {"min": 20,   "label": "Sympathisant"},
	"neutre":       {"min": -19,  "label": "Neutre"},
	"mefiant":      {"min": -59,  "label": "Mefiant"},
	"hostile":      {"min": -100, "label": "Hostile"},
}

# Bonus/malus de début de run selon tier × faction
# Tiers sans entrée = pas d'effet de début de run
const FACTION_RUN_BONUSES := {
	"druides":   {
		"honore":       {"type": "ADD_SOUFFLE", "amount": 2},
		"sympathisant": {"type": "ADD_KARMA",   "amount": 5},
		"hostile":      {"type": "ADD_TENSION", "amount": 25},
	},
	"korrigans": {
		"honore":       {"type": "HEAL_LIFE",   "amount": 20},
		"sympathisant": {"type": "ADD_SOUFFLE", "amount": 1},
		"hostile":      {"type": "DAMAGE_LIFE", "amount": 10},
	},
	"humains":   {
		"honore":       {"type": "HEAL_LIFE",   "amount": 15},
		"hostile":      {"type": "ADD_TENSION", "amount": 15},
	},
	"anciens":   {
		"honore":       {"type": "ADD_SOUFFLE", "amount": 1},
		"hostile":      {"type": "ADD_KARMA",   "amount": -10},
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
const FACTION_DECAY_RATE    := 0.08 # 8% de valeur absolue oublié par run

# Keywords pour auto-tag Path B (merlin_llm_adapter._wrap_text_as_card)
const FACTION_KEYWORDS := {
	"druides":   ["druide", "ogham", "nemeton", "chene", "barde"],
	"korrigans": ["korrigan", "farfadet", "marais", "lutin", "fee"],
	"humains":   ["clan", "village", "guerrier", "humain", "paysan"],
	"anciens":   ["ancien", "menhir", "dolmen", "eternite", "primordial"],
	"ankou":     ["ankou", "mort", "faucheuse", "ame", "trepas"],
}

# ═══════════════════════════════════════════════════════════════════════════════
# TYPOLOGIES DE RUN — Couche modificatrice orthogonale à la Triade
# Réf : docs/20_card_system/DOC_16_Run_Typologies.md
# ═══════════════════════════════════════════════════════════════════════════════

const RUN_TYPOLOGIES := {
	"classique": {
		"name": "Classique", "icon": "-",
		"timer_enabled": false, "d20_modifier": 0, "dc_modifier": 0,
		"card_bias": {}, "souffle_bonus": 0, "life_bonus": 0,
		"llm_hint": "",
	},
	"urgence": {
		"name": "Urgence", "icon": "!",
		"timer_enabled": true, "timer_seconds": 10,
		"d20_modifier": 0, "dc_modifier": 2,
		"card_bias": {"event": 0.15, "narrative": 0.75},
		"souffle_bonus": 1, "life_bonus": 0,
		"timeout_effect": "ADD_TENSION:15",
		"llm_hint": "URGENCE: crise immediate, options breves.",
	},
	"parieur": {
		"name": "Parieur", "icon": "?",
		"timer_enabled": false, "d20_modifier": 0, "dc_modifier": 0,
		"card_bias": {}, "d20_outcome_modifier": true,
		"crit_threshold": 17, "fumble_threshold": 4,
		"souffle_bonus": 0, "life_bonus": 10,
		"llm_hint": "PARIEUR: hasard capricieux, consequences imprevues.",
	},
	"diplomate": {
		"name": "Diplomate", "icon": "O",
		"timer_enabled": false, "d20_modifier": 2, "dc_modifier": -1,
		"card_bias": {"narrative": 0.90}, "faction_delta_mult": 2.0,
		"souffle_bonus": 0, "life_bonus": 0,
		"llm_hint": "DIPLOMATE: alliances, factions, negociation.",
	},
	"chasseur": {
		"name": "Chasseur", "icon": ">",
		"timer_enabled": false, "d20_modifier": 0, "dc_modifier": 0,
		"card_bias": {"event": 0.20, "narrative": 0.65},
		"minigame_chance_bonus": 0.25, "awen_regen_bonus": 1,
		"souffle_bonus": 0, "life_bonus": 0,
		"llm_hint": "CHASSEUR: traque, Bestiole, nature, instinct.",
	},
}
