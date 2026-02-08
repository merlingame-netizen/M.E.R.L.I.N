extends RefCounted
class_name DruConstants

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
