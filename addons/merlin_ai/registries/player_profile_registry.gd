## ═══════════════════════════════════════════════════════════════════════════════
## Player Profile Registry — Qui est le joueur
## ═══════════════════════════════════════════════════════════════════════════════
## Maintient un profil psychologique du joueur a travers toutes les sessions.
## Persistance: Cross-run (sauvegarde disque)
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name PlayerProfileRegistry

signal profile_updated(trait_name: String, old_value: float, new_value: float)
signal skill_assessed(skill: String, level: float)
signal preference_detected(preference: String, value: Variant)

const VERSION := "1.0.0"
const SAVE_PATH := "user://merlin_player_profile.json"

# ═══════════════════════════════════════════════════════════════════════════════
# PLAY STYLE (0.0 = extreme gauche, 1.0 = extreme droite)
# ═══════════════════════════════════════════════════════════════════════════════

var play_style := {
	"aggression": 0.5,      # Prudent (0) ↔ Reckless (1)
	"altruism": 0.5,        # Egoiste (0) ↔ Altruiste (1)
	"curiosity": 0.5,       # Pragmatique (0) ↔ Explorateur (1)
	"patience": 0.5,        # Impulsif (0) ↔ Methodique (1)
	"trust_merlin": 0.5,    # Mefiant (0) ↔ Confiant (1)
	"risk_tolerance": 0.5,  # Risk-averse (0) ↔ Risk-seeking (1)
}

# ═══════════════════════════════════════════════════════════════════════════════
# SKILL ASSESSMENT (0.0 = novice, 1.0 = maitre)
# ═══════════════════════════════════════════════════════════════════════════════

var skill_assessment := {
	"gauge_management": 0.5,    # Capacite a equilibrer les jauges
	"pattern_recognition": 0.5, # Detecte les setups narratifs
	"risk_assessment": 0.5,     # Fait des tradeoffs informes
	"memory": 0.5,              # Se souvient des events/NPCs
	"timing": 0.5,              # Utilise les skills au bon moment
	"recovery": 0.5,            # Capacite a se sortir des crises
}

# ═══════════════════════════════════════════════════════════════════════════════
# PREFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

var preferences := {
	"preferred_themes": [],     # ["mystere", "combat", "social"]
	"avoided_themes": [],       # Themes evites
	"favorite_npcs": [],        # NPCs avec interactions positives
	"disliked_npcs": [],        # NPCs avec interactions negatives
	"humor_receptivity": 0.5,   # 0=serieux, 1=aime l'humour
	"lore_interest": 0.5,       # Interet pour le lore profond
	"preferred_gauges": [],     # Jauges que le joueur protege
	"preferred_biomes": [],     # Biomes ou il passe du temps
}

# ═══════════════════════════════════════════════════════════════════════════════
# META-PROGRESSION
# ═══════════════════════════════════════════════════════════════════════════════

var meta := {
	"runs_completed": 0,
	"runs_won": 0,
	"total_cards_played": 0,
	"average_run_length": 50.0,
	"longest_run": 0,
	"shortest_run": 999,
	"endings_seen": [],
	"lore_fragments_discovered": [],
	"first_seen_date": 0,           # Unix timestamp
	"last_seen_date": 0,
	"total_play_time_seconds": 0,
	"total_sessions": 0,
	"achievements_unlocked": [],
}

# ═══════════════════════════════════════════════════════════════════════════════
# LEARNING RATES
# ═══════════════════════════════════════════════════════════════════════════════

const TRAIT_LEARNING_RATE := 0.05
const SKILL_LEARNING_RATE := 0.03
const PREFERENCE_THRESHOLD := 3  # Occurrences avant detection
const DECAY_RATE := 0.995  # Par session (lent retour vers 0.5)

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

var _theme_counter := {}  # Pour detecter preferences
var _npc_interactions := {}  # {npc_id: {positive: int, negative: int}}
var _gauge_protection_count := {}  # {gauge: int} pour detecter preferences
var _current_run_data := {
	"cards_played": 0,
	"crises_survived": 0,
	"crises_failed": 0,
	"promises_kept": 0,
	"promises_broken": 0,
}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	load_from_disk()


func reset() -> void:
	play_style = {
		"aggression": 0.5,
		"altruism": 0.5,
		"curiosity": 0.5,
		"patience": 0.5,
		"trust_merlin": 0.5,
		"risk_tolerance": 0.5,
	}
	skill_assessment = {
		"gauge_management": 0.5,
		"pattern_recognition": 0.5,
		"risk_assessment": 0.5,
		"memory": 0.5,
		"timing": 0.5,
		"recovery": 0.5,
	}
	_current_run_data = {
		"cards_played": 0,
		"crises_survived": 0,
		"crises_failed": 0,
		"promises_kept": 0,
		"promises_broken": 0,
	}

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE FROM CHOICE
# ═══════════════════════════════════════════════════════════════════════════════

func update_from_choice(card: Dictionary, option: int, context: Dictionary) -> void:
	## Analyse un choix et met a jour le profil.
	var tags: Array = card.get("tags", [])
	var effects: Array = _get_option_effects(card, option)
	var decision_time_ms: int = context.get("decision_time_ms", 3000)

	_current_run_data["cards_played"] += 1

	# === Update play style based on tags ===
	_update_play_style_from_tags(tags)

	# === Update play style based on effects ===
	_update_play_style_from_effects(effects, context)

	# === Update patience based on decision time ===
	_update_patience_from_time(decision_time_ms)

	# === Track themes for preferences ===
	_track_themes(tags)

	# === Track NPC interactions ===
	_track_npc_interaction(card, option)


func _update_play_style_from_tags(tags: Array) -> void:
	# Aggression
	if "aggressive" in tags or "combat" in tags or "attack" in tags:
		_shift_trait("aggression", 1.0)
	elif "peaceful" in tags or "diplomatic" in tags or "avoid" in tags:
		_shift_trait("aggression", 0.0)

	# Altruism
	if "help_others" in tags or "sacrifice" in tags or "generous" in tags:
		_shift_trait("altruism", 1.0)
	elif "self_interest" in tags or "selfish" in tags or "take" in tags:
		_shift_trait("altruism", 0.0)

	# Curiosity
	if "explore" in tags or "investigate" in tags or "mystery" in tags:
		_shift_trait("curiosity", 1.0)
	elif "ignore" in tags or "practical" in tags or "direct" in tags:
		_shift_trait("curiosity", 0.0)

	# Risk tolerance
	if "risky" in tags or "dangerous" in tags or "gamble" in tags:
		_shift_trait("risk_tolerance", 1.0)
	elif "safe" in tags or "cautious" in tags or "careful" in tags:
		_shift_trait("risk_tolerance", 0.0)


func _update_play_style_from_effects(effects: Array, context: Dictionary) -> void:
	var gauges: Dictionary = context.get("gauges", {})

	for effect in effects:
		var effect_type: String = effect.get("type", "")
		var target: String = effect.get("target", "")
		var value: int = int(effect.get("value", 0))

		if effect_type in ["ADD_GAUGE", "REMOVE_GAUGE"]:
			# Track gauge protection patterns
			var gauge_value: int = int(gauges.get(target, 50))
			if gauge_value < 25 and value > 0:
				# Joueur protege une jauge basse
				_gauge_protection_count[target] = _gauge_protection_count.get(target, 0) + 1
				_update_skill("gauge_management", 0.02)
			elif gauge_value > 75 and value < 0:
				# Joueur baisse une jauge haute
				_gauge_protection_count[target] = _gauge_protection_count.get(target, 0) + 1
				_update_skill("gauge_management", 0.02)


func _update_patience_from_time(decision_time_ms: int) -> void:
	if decision_time_ms < 1000:
		_shift_trait("patience", 0.0)  # Impulsif
	elif decision_time_ms > 8000:
		_shift_trait("patience", 1.0)  # Methodique


func _shift_trait(trait_name: String, target: float) -> void:
	if not play_style.has(trait_name):
		return
	var old_value: float = play_style[trait_name]
	play_style[trait_name] = lerpf(old_value, target, TRAIT_LEARNING_RATE)
	if absf(old_value - play_style[trait_name]) > 0.01:
		profile_updated.emit(trait_name, old_value, play_style[trait_name])


func _update_skill(skill: String, delta: float) -> void:
	if not skill_assessment.has(skill):
		return
	var old_value: float = skill_assessment[skill]
	skill_assessment[skill] = clampf(old_value + delta, 0.0, 1.0)
	if absf(old_value - skill_assessment[skill]) > 0.01:
		skill_assessed.emit(skill, skill_assessment[skill])


func _track_themes(tags: Array) -> void:
	for tag in tags:
		_theme_counter[tag] = _theme_counter.get(tag, 0) + 1
		if _theme_counter[tag] == PREFERENCE_THRESHOLD:
			var pref_themes: Array = preferences["preferred_themes"]
			if tag not in pref_themes:
				pref_themes.append(tag)
				preference_detected.emit("theme", tag)


func _track_npc_interaction(card: Dictionary, option: int) -> void:
	var npc_id: String = card.get("npc_id", "")
	if npc_id.is_empty():
		return

	if not _npc_interactions.has(npc_id):
		_npc_interactions[npc_id] = {"positive": 0, "negative": 0}

	# Determine if interaction was positive or negative
	var npc_data: Dictionary = _npc_interactions[npc_id]
	var is_positive: bool = option == 1  # Assume right = positive for now
	if is_positive:
		npc_data["positive"] += 1
	else:
		npc_data["negative"] += 1

	# Update favorites/disliked lists
	var fav_npcs: Array = preferences["favorite_npcs"]
	var dis_npcs: Array = preferences["disliked_npcs"]
	if npc_data["positive"] >= 3 and npc_id not in fav_npcs:
		fav_npcs.append(npc_id)
		preference_detected.emit("favorite_npc", npc_id)
	elif npc_data["negative"] >= 3 and npc_id not in dis_npcs:
		dis_npcs.append(npc_id)
		preference_detected.emit("disliked_npc", npc_id)


func _get_option_effects(card: Dictionary, option: int) -> Array:
	var options: Array = card.get("options", [])
	if option >= 0 and option < options.size():
		return options[option].get("effects", [])
	return []

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE FROM OUTCOME
# ═══════════════════════════════════════════════════════════════════════════════

func update_from_outcome(outcome: Dictionary) -> void:
	## Met a jour les skills basees sur les resultats.

	# Crisis management
	if outcome.get("avoided_crisis", false):
		_current_run_data["crises_survived"] += 1
		_update_skill("gauge_management", SKILL_LEARNING_RATE)
		_update_skill("recovery", SKILL_LEARNING_RATE)
	elif outcome.get("entered_crisis", false):
		_current_run_data["crises_failed"] += 1
		_update_skill("gauge_management", -SKILL_LEARNING_RATE * 0.5)

	# Pattern recognition (if player predicted correctly)
	if outcome.get("predicted_twist", false):
		_update_skill("pattern_recognition", SKILL_LEARNING_RATE * 2)

	# Promise keeping
	if outcome.get("promise_kept", false):
		_current_run_data["promises_kept"] += 1
		_shift_trait("trust_merlin", 1.0)
	elif outcome.get("promise_broken", false):
		_current_run_data["promises_broken"] += 1
		_shift_trait("trust_merlin", 0.0)

	# Skill timing
	if outcome.get("skill_well_timed", false):
		_update_skill("timing", SKILL_LEARNING_RATE)

# ═══════════════════════════════════════════════════════════════════════════════
# RUN END
# ═══════════════════════════════════════════════════════════════════════════════

func on_run_end(run_data: Dictionary) -> void:
	## Appele a la fin de chaque run.
	var cards_played: int = run_data.get("cards_played", 0)
	var is_victory: bool = run_data.get("victory", false)
	var ending: String = run_data.get("ending", {}).get("title", "")

	# Update meta
	meta["runs_completed"] += 1
	if is_victory:
		meta["runs_won"] += 1
	meta["total_cards_played"] += cards_played
	meta["last_seen_date"] = int(Time.get_unix_time_from_system())

	# Update average run length
	meta["average_run_length"] = (
		(meta["average_run_length"] * (meta["runs_completed"] - 1) + cards_played)
		/ float(meta["runs_completed"])
	)

	# Track longest/shortest
	meta["longest_run"] = maxi(meta["longest_run"], cards_played)
	meta["shortest_run"] = mini(meta["shortest_run"], cards_played)

	# Track endings
	var seen: Array = meta["endings_seen"]
	if ending != "" and ending not in seen:
		seen.append(ending)

	# Apply session decay to traits (slow return to center)
	_apply_session_decay()

	# Reset run data
	_current_run_data = {
		"cards_played": 0,
		"crises_survived": 0,
		"crises_failed": 0,
		"promises_kept": 0,
		"promises_broken": 0,
	}

	# Save to disk
	save_to_disk()


func _apply_session_decay() -> void:
	## Applique un leger decay vers 0.5 pour eviter les extremes.
	for key in play_style:
		var current: float = play_style[key]
		play_style[key] = lerpf(current, 0.5, 1.0 - DECAY_RATE)

# ═══════════════════════════════════════════════════════════════════════════════
# EXPERIENCE TIER
# ═══════════════════════════════════════════════════════════════════════════════

enum ExperienceTier { INITIATE, APPRENTICE, JOURNEYER, ADEPT, MASTER }

func get_experience_tier() -> ExperienceTier:
	var runs: int = meta["runs_completed"]
	if runs <= 5:
		return ExperienceTier.INITIATE
	elif runs <= 20:
		return ExperienceTier.APPRENTICE
	elif runs <= 50:
		return ExperienceTier.JOURNEYER
	elif runs <= 100:
		return ExperienceTier.ADEPT
	else:
		return ExperienceTier.MASTER


func get_experience_tier_name() -> String:
	match get_experience_tier():
		ExperienceTier.INITIATE: return "Initie"
		ExperienceTier.APPRENTICE: return "Apprenti"
		ExperienceTier.JOURNEYER: return "Voyageur"
		ExperienceTier.ADEPT: return "Adepte"
		ExperienceTier.MASTER: return "Maitre"
	return "Inconnu"

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT FOR LLM
# ═══════════════════════════════════════════════════════════════════════════════

func get_context_for_llm() -> Dictionary:
	## Retourne un resume du profil pour le LLM.
	var pref_themes: Array = preferences["preferred_themes"]
	var avoid_themes: Array = preferences["avoided_themes"]
	return {
		"style": play_style.duplicate(),
		"skill": skill_assessment.duplicate(),
		"runs_completed": meta["runs_completed"],
		"experience_tier": get_experience_tier_name(),
		"preferred_themes": pref_themes.duplicate(),
		"avoided_themes": avoid_themes.duplicate(),
		"humor_receptivity": preferences["humor_receptivity"],
		"lore_interest": preferences["lore_interest"],
	}


func get_summary_for_prompt() -> String:
	## Retourne un resume textuel compact pour le prompt LLM (tous les 6 axes).
	var traits := []

	# 6 axes play_style — chacun avec seuil haut/bas
	var _axis_labels := {
		"aggression":     ["prudent", "audacieux"],
		"altruism":       ["pragmatique", "altruiste"],
		"curiosity":      ["pragmatique", "explorateur"],
		"patience":       ["impulsif", "methodique"],
		"trust_merlin":   ["mefiant envers Merlin", "confiant envers Merlin"],
		"risk_tolerance": ["prudent face au risque", "preneur de risques"],
	}
	for axis in _axis_labels:
		var val: float = play_style.get(axis, 0.5)
		var labels: Array = _axis_labels[axis]
		if val < 0.3:
			traits.append(labels[0])
		elif val > 0.7:
			traits.append(labels[1])

	# Skill level compact
	var avg_skill: float = 0.0
	for s in skill_assessment.values():
		avg_skill += s
	avg_skill /= maxf(skill_assessment.size(), 1.0)

	var skill_tag := ""
	if avg_skill > 0.7:
		skill_tag = "experimente"
	elif avg_skill < 0.3:
		skill_tag = "debutant"

	# Assemble
	var line := "Joueur %s" % get_experience_tier_name()
	if skill_tag != "":
		line += " (%s)" % skill_tag
	if traits.size() > 0:
		line += ": " + ", ".join(traits)
	return line


func seed_from_quiz(quiz_result: Dictionary) -> void:
	## Initialise le profil a partir des resultats du quiz de personnalite.
	## quiz_result: {axis_positions: {approche, relation, esprit, coeur}, archetype_id, ...}
	var axes: Dictionary = quiz_result.get("axis_positions", {})

	# Mapping quiz axes (-1..+1) → play_style (0..1)
	# approche: prudent(-1) ↔ audacieux(+1) → aggression + risk_tolerance
	var approche: float = float(axes.get("approche", 0.0))
	play_style["aggression"] = clampf((approche + 1.0) / 2.0, 0.0, 1.0)
	play_style["risk_tolerance"] = clampf((approche + 1.0) / 2.0, 0.0, 1.0)

	# relation: solitaire(-1) ↔ social(+1) → altruism + trust_merlin
	var relation: float = float(axes.get("relation", 0.0))
	play_style["altruism"] = clampf((relation + 1.0) / 2.0, 0.0, 1.0)
	play_style["trust_merlin"] = clampf((relation * 0.5 + 1.0) / 2.0, 0.0, 1.0)

	# esprit: analytique(-1) ↔ intuitif(+1) → patience (inverse: analytique=methodique)
	var esprit: float = float(axes.get("esprit", 0.0))
	play_style["patience"] = clampf((-esprit + 1.0) / 2.0, 0.0, 1.0)

	# coeur: pragmatique(-1) ↔ compassionnel(+1) → curiosity (sensibilite ≈ ouverture)
	var coeur: float = float(axes.get("coeur", 0.0))
	play_style["curiosity"] = clampf((coeur + 1.0) / 2.0, 0.0, 1.0)

	# Store archetype for reference
	preferences["archetype_id"] = quiz_result.get("archetype_id", "")
	preferences["dominant_traits"] = quiz_result.get("dominant_traits", [])

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func save_to_disk() -> void:
	var data := {
		"version": VERSION,
		"play_style": play_style,
		"skill_assessment": skill_assessment,
		"preferences": preferences,
		"meta": meta,
		"_theme_counter": _theme_counter,
		"_npc_interactions": _npc_interactions,
		"_gauge_protection_count": _gauge_protection_count,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		meta["first_seen_date"] = int(Time.get_unix_time_from_system())
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return

	# Load each section with fallbacks
	if data.has("play_style"):
		for key in data["play_style"]:
			if play_style.has(key):
				play_style[key] = float(data["play_style"][key])

	if data.has("skill_assessment"):
		for key in data["skill_assessment"]:
			if skill_assessment.has(key):
				skill_assessment[key] = float(data["skill_assessment"][key])

	if data.has("preferences"):
		for key in data["preferences"]:
			if preferences.has(key):
				preferences[key] = data["preferences"][key]

	if data.has("meta"):
		for key in data["meta"]:
			if meta.has(key):
				meta[key] = data["meta"][key]

	if data.has("_theme_counter"):
		_theme_counter = data["_theme_counter"]
	if data.has("_npc_interactions"):
		_npc_interactions = data["_npc_interactions"]
	if data.has("_gauge_protection_count"):
		_gauge_protection_count = data["_gauge_protection_count"]
