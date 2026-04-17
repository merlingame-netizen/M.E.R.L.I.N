## merlin_reputation_system.gd
## Système de réputation 5 factions — stateless static helpers + stateful instance API.
## Valeurs float 0.0-100.0. Seuil contenu: 50. Seuil fin: 80. Cap: ±20/carte.
## Ref: docs/GAME_DESIGN_BIBLE.md v2.4 — factions, thresholds, caps

class_name MerlinReputationSystem extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS (mirrors MerlinConstants for convenience / forward-compat)
# ═══════════════════════════════════════════════════════════════════════════════

const FACTIONS: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
const THRESHOLD_CONTENT: float = 50.0  # Déblocage cartes spéciales faction
const THRESHOLD_ENDING: float = 80.0   # Déblocage fin narrative faction
const VALUE_MIN: float = 0.0
const VALUE_MAX: float = 100.0
const CAP_PER_CARD: float = 20.0       # Max ±20 reputation change per card


# ═══════════════════════════════════════════════════════════════════════════════
# INSTANCE STATE — Stateful API for systems that track reputation over time
# ═══════════════════════════════════════════════════════════════════════════════

var _reputations: Dictionary = {}


func _init() -> void:
	reset()


## Réinitialise toutes les réputations au niveau Neutre (20).
func reset() -> void:
	_reputations = build_default_factions()


## Ajoute de la réputation à une faction. Clampé [0, 100], cappé à ±20/carte.
## Retourne la nouvelle valeur (float), ou -1.0 si la faction est invalide.
func add_reputation(faction: String, amount: float) -> float:
	if not FACTIONS.has(faction):
		return -1.0
	var capped: float = clampf(amount, -CAP_PER_CARD, CAP_PER_CARD)
	var current: float = float(_reputations.get(faction, 0.0))
	var new_value: float = clampf(current + capped, VALUE_MIN, VALUE_MAX)
	_reputations[faction] = new_value
	return new_value


## Retourne la réputation d'une faction. 0 si invalide.
func get_reputation(faction: String) -> float:
	if not FACTIONS.has(faction):
		return 0.0
	return float(_reputations.get(faction, 0.0))


## Retourne un dict de toutes les réputations (copie).
func get_all_reputations() -> Dictionary:
	return _reputations.duplicate()


## Vérifie si une faction a atteint le seuil contenu (>= 50).
func has_content_threshold(faction: String) -> bool:
	return float(_reputations.get(faction, 0.0)) >= THRESHOLD_CONTENT


## Vérifie si une faction a atteint le seuil fin (>= 80).
func has_ending_threshold(faction: String) -> bool:
	return float(_reputations.get(faction, 0.0)) >= THRESHOLD_ENDING


## Retourne la faction dominante (plus haute rep). "" si toutes à 0.
func get_dominant() -> String:
	return get_dominant_faction(_reputations)


# ═══════════════════════════════════════════════════════════════════════════════
# STATIC HELPERS — Pure functions, no internal state (immutable pattern)
# ═══════════════════════════════════════════════════════════════════════════════

## Retourne un NOUVEAU dict factions avec le delta appliqué sur faction.
## L'original n'est jamais muté. Valeur clampée [0.0, 100.0].
static func apply_delta(factions: Dictionary, faction: String, delta: float) -> Dictionary:
	var result: Dictionary = factions.duplicate()
	if not FACTIONS.has(faction):
		return result
	var current: float = float(result.get(faction, 0.0))
	var new_value: float = clampf(current + delta, VALUE_MIN, VALUE_MAX)
	result[faction] = new_value
	return result


## Retourne les noms de factions dont la valeur >= THRESHOLD_ENDING (80).
## Plusieurs factions peuvent être disponibles simultanément (design Q2 2026-03-11).
static func get_available_endings(factions: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for faction in FACTIONS:
		var value: float = float(factions.get(faction, 0.0))
		if value >= THRESHOLD_ENDING:
			result.append(faction)
	return result


## Retourne les noms de factions dont la valeur >= THRESHOLD_CONTENT (50).
static func get_unlocked_content(factions: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for faction in FACTIONS:
		var value: float = float(factions.get(faction, 0.0))
		if value >= THRESHOLD_CONTENT:
			result.append(faction)
	return result


## Retourne la faction avec la valeur la plus haute.
## Retourne "" si toutes les valeurs sont à 0 ou si factions est vide.
static func get_dominant_faction(factions: Dictionary) -> String:
	var dominant: String = ""
	var dominant_value: float = 0.0
	for faction in FACTIONS:
		var value: float = float(factions.get(faction, 0.0))
		if value > dominant_value:
			dominant_value = value
			dominant = faction
	return dominant


## Retourne un résumé lisible pour le prompt LLM.
## Format: "Druides:45 Anciens:12 Korrigans:78 Niamh:5 Ankou:30"
static func describe_factions(factions: Dictionary) -> String:
	var parts: Array[String] = []
	for faction in FACTIONS:
		var value: float = float(factions.get(faction, 0.0))
		var label: String = faction.capitalize()
		parts.append(label + ":" + str(int(value)))
	return " ".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Vérifie qu'un nom de faction est valide.
static func is_valid_faction(faction: String) -> bool:
	return FACTIONS.has(faction)


## Retourne un dict factions au niveau Neutre (FACTION_SCORE_START) pour les 5 factions.
static func build_default_factions() -> Dictionary:
	var start: float = float(MerlinConstants.FACTION_SCORE_START)
	var result: Dictionary = {}
	for faction in FACTIONS:
		result[faction] = start
	return result


## Retourne le tier textuel d'une valeur de réputation (pour affichage UI).
## Paliers alignés sur FACTION_TIERS de MerlinConstants (bible v2.4).
static func get_tier_label(value: float) -> String:
	if value >= 80.0:
		return "Honore"
	elif value >= 50.0:
		return "Sympathisant"
	elif value >= 20.0:
		return "Neutre"
	elif value >= 5.0:
		return "Mefiant"
	else:
		return "Hostile"
