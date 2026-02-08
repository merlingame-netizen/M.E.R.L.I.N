## ═══════════════════════════════════════════════════════════════════════════════
## Narrative Registry — Memoire Narrative
## ═══════════════════════════════════════════════════════════════════════════════
## Track les elements narratifs actifs pour coherence et callbacks.
## Persistance: Per-run + major arcs cross-run
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name NarrativeRegistry

signal arc_started(arc_id: String)
signal arc_progressed(arc_id: String, stage: int)
signal arc_completed(arc_id: String, resolution: String)
signal foreshadowing_planted(hint_id: String)
signal foreshadowing_revealed(hint_id: String)
signal twist_triggered(twist_type: String)
signal theme_fatigue_warning(theme: String)

const VERSION := "1.0.0"
const SAVE_PATH := "user://merlin_narrative.json"

# ═══════════════════════════════════════════════════════════════════════════════
# ARCS NARRATIFS
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_ACTIVE_ARCS := 2
const ARC_AUTO_CLOSE_CARDS := 30  # Ferme auto si pas de resolution

var active_arcs: Array[Dictionary] = []
# Structure: {
#   id: String,
#   stage: int,  # 1=intro, 2=development, 3=climax, 4=resolution
#   cards_in_arc: Array[String],
#   flags: Dictionary,
#   started_at_card: int,
#   deadline_card: int
# }

var completed_arcs: Array[Dictionary] = []  # Cross-run
# Structure: {id, resolution, cards_played, outcome}

# ═══════════════════════════════════════════════════════════════════════════════
# FORESHADOWING
# ═══════════════════════════════════════════════════════════════════════════════

const MAX_FORESHADOWING := 5
const FORESHADOWING_MIN_CARDS := 5
const FORESHADOWING_MAX_CARDS := 30

var foreshadowing: Array[Dictionary] = []
# Structure: {
#   id: String,
#   hint: String,
#   planted_at_card: int,
#   min_reveal_card: int,
#   max_reveal_card: int,
#   revealed: bool,
#   twist_type: String
# }

const TWIST_TYPES := [
	"identity_hidden",      # NPC n'est pas ce qu'il semble
	"motivation_inverse",   # Motivations cachees
	"consequence_differee", # Choix passe a des consequences
	"fausse_victoire",      # Ce qui semblait bon ne l'est pas
	"ami_ennemi",           # Allié devient adversaire
	"ennemi_ami",           # Adversaire devient allié
]

# ═══════════════════════════════════════════════════════════════════════════════
# NPC TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

var npcs := {}
# Structure: {
#   npc_id: {
#     encounters: int,
#     last_seen_card: int,
#     relationship: int,  # -100 to 100
#     secrets_known: Array[String],
#     can_return: bool,
#     arc_id: String  # Arc associe
#   }
# }

# ═══════════════════════════════════════════════════════════════════════════════
# WORLD STATE
# ═══════════════════════════════════════════════════════════════════════════════

var world := {
	"biome": "broceliande",
	"day": 1,
	"season": "autumn",
	"time_of_day": "jour",
	"active_tags": [],
	"global_tension": 0.3,  # 0-1, affecte probabilite de twist
	"weather": "clear",
	"moon_phase": "waxing",  # Pour magie
}

const SEASONS := ["spring", "summer", "autumn", "winter"]
const TIMES_OF_DAY := ["aube", "jour", "soir", "nuit"]
const WEATHERS := ["clear", "cloudy", "rain", "storm", "mist", "snow"]

# ═══════════════════════════════════════════════════════════════════════════════
# THEME MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

const THEME_FATIGUE_DECAY := 0.1
const THEME_FATIGUE_WARNING := 3  # Avertir apres X repetitions

var recent_themes: Array[String] = []
var theme_fatigue := {}  # {theme: float}

const THEMES := [
	"mystery", "combat", "social", "survival",
	"spiritual", "political", "romantic", "horror",
	"comedy", "tragedy", "adventure", "introspection"
]

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _current_card_number := 0
var _rng := RandomNumberGenerator.new()

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	_rng.randomize()
	load_from_disk()


func reset_run() -> void:
	"""Reset pour nouvelle run."""
	active_arcs.clear()
	foreshadowing.clear()
	npcs.clear()
	recent_themes.clear()
	theme_fatigue.clear()
	_current_card_number = 0

	world = {
		"biome": "broceliande",
		"day": 1,
		"season": _get_random_season(),
		"time_of_day": "jour",
		"active_tags": [],
		"global_tension": 0.3,
		"weather": "clear",
		"moon_phase": "waxing",
	}


func _get_random_season() -> String:
	return SEASONS[_rng.randi() % SEASONS.size()]

# ═══════════════════════════════════════════════════════════════════════════════
# CARD PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

func process_card(card: Dictionary) -> void:
	"""Appele apres chaque carte jouee."""
	_current_card_number += 1

	# Track themes
	var themes: Array = card.get("themes", card.get("tags", []))
	_track_themes(themes)

	# Track NPC
	var npc_id: String = card.get("npc_id", "")
	if npc_id != "":
		_track_npc_encounter(npc_id, card)

	# Progress arcs
	var arc_id: String = card.get("arc_id", "")
	if arc_id != "":
		_progress_arc(arc_id, card)

	# Check foreshadowing reveals
	_check_foreshadowing_reveals()

	# Check arc deadlines
	_check_arc_deadlines()

	# Update world state
	_update_world_state(card)

	# Decay fatigue
	_decay_theme_fatigue()


func _track_themes(themes: Array) -> void:
	for theme in themes:
		if theme in THEMES or theme.length() > 0:
			recent_themes.append(theme)
			theme_fatigue[theme] = theme_fatigue.get(theme, 0.0) + 1.0

			# Check for fatigue warning
			if theme_fatigue[theme] >= THEME_FATIGUE_WARNING:
				theme_fatigue_warning.emit(theme)

	# Keep only last 10
	while recent_themes.size() > 10:
		recent_themes.pop_front()


func _decay_theme_fatigue() -> void:
	for theme in theme_fatigue.keys():
		theme_fatigue[theme] = maxf(0.0, theme_fatigue[theme] - THEME_FATIGUE_DECAY)
		if theme_fatigue[theme] <= 0.0:
			theme_fatigue.erase(theme)


func _update_world_state(card: Dictionary) -> void:
	# Update tags
	var add_tags: Array = card.get("add_tags", [])
	var remove_tags: Array = card.get("remove_tags", [])

	for tag in add_tags:
		if tag not in world.active_tags:
			world.active_tags.append(tag)
	for tag in remove_tags:
		world.active_tags.erase(tag)

	# Update biome if card specifies
	var biome: String = card.get("biome", "")
	if biome != "":
		world.biome = biome

	# Update tension based on card type
	if card.get("type", "") == "twist":
		world.global_tension = maxf(0.0, world.global_tension - 0.2)  # Release after twist
	else:
		world.global_tension = minf(1.0, world.global_tension + 0.02)  # Slowly build

# ═══════════════════════════════════════════════════════════════════════════════
# ARC MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func start_arc(arc_id: String, initial_flags: Dictionary = {}) -> bool:
	"""Demarre un nouvel arc narratif."""
	if active_arcs.size() >= MAX_ACTIVE_ARCS:
		return false

	# Check if already active
	for arc in active_arcs:
		if arc.id == arc_id:
			return false

	var arc := {
		"id": arc_id,
		"stage": 1,
		"cards_in_arc": [],
		"flags": initial_flags,
		"started_at_card": _current_card_number,
		"deadline_card": _current_card_number + ARC_AUTO_CLOSE_CARDS,
	}

	active_arcs.append(arc)
	arc_started.emit(arc_id)
	return true


func _progress_arc(arc_id: String, card: Dictionary) -> void:
	for arc in active_arcs:
		if arc.id == arc_id:
			arc.cards_in_arc.append(card.get("id", ""))

			# Check for stage progression
			var new_stage: int = card.get("arc_stage", arc.stage)
			if new_stage > arc.stage:
				arc.stage = new_stage
				arc_progressed.emit(arc_id, new_stage)

			# Check for resolution
			if new_stage >= 4 or card.get("arc_resolution", false):
				_complete_arc(arc, card.get("arc_outcome", "resolved"))

			# Update flags
			var new_flags: Dictionary = card.get("arc_flags", {})
			for key in new_flags:
				arc.flags[key] = new_flags[key]

			return


func _complete_arc(arc: Dictionary, resolution: String) -> void:
	active_arcs.erase(arc)

	var completed := {
		"id": arc.id,
		"resolution": resolution,
		"cards_played": arc.cards_in_arc.size(),
		"outcome": resolution,
		"completed_at": _current_card_number,
	}
	completed_arcs.append(completed)

	arc_completed.emit(arc.id, resolution)


func _check_arc_deadlines() -> void:
	var to_close := []

	for arc in active_arcs:
		if _current_card_number >= arc.deadline_card:
			to_close.append(arc)

	for arc in to_close:
		_complete_arc(arc, "expired")


func get_active_arc(arc_id: String) -> Dictionary:
	for arc in active_arcs:
		if arc.id == arc_id:
			return arc
	return {}


func has_active_arc(arc_id: String) -> bool:
	return not get_active_arc(arc_id).is_empty()

# ═══════════════════════════════════════════════════════════════════════════════
# FORESHADOWING
# ═══════════════════════════════════════════════════════════════════════════════

func plant_foreshadowing(hint_id: String, hint_text: String, twist_type: String = "") -> bool:
	"""Plante un element de foreshadowing."""
	if foreshadowing.size() >= MAX_FORESHADOWING:
		return false

	var hint := {
		"id": hint_id,
		"hint": hint_text,
		"planted_at_card": _current_card_number,
		"min_reveal_card": _current_card_number + FORESHADOWING_MIN_CARDS,
		"max_reveal_card": _current_card_number + FORESHADOWING_MAX_CARDS,
		"revealed": false,
		"twist_type": twist_type if twist_type != "" else TWIST_TYPES[_rng.randi() % TWIST_TYPES.size()],
	}

	foreshadowing.append(hint)
	foreshadowing_planted.emit(hint_id)
	return true


func _check_foreshadowing_reveals() -> void:
	for hint in foreshadowing:
		if hint.revealed:
			continue

		# Auto-reveal if past max
		if _current_card_number >= hint.max_reveal_card:
			hint.revealed = true
			# Mark as missed opportunity
			hint["missed"] = true


func reveal_foreshadowing(hint_id: String) -> bool:
	"""Revele un element de foreshadowing."""
	for hint in foreshadowing:
		if hint.id == hint_id and not hint.revealed:
			if _current_card_number >= hint.min_reveal_card:
				hint.revealed = true
				foreshadowing_revealed.emit(hint_id)
				return true
	return false


func get_revealable_foreshadowing() -> Array:
	"""Retourne les hints qui peuvent etre reveles maintenant."""
	var revealable := []
	for hint in foreshadowing:
		if not hint.revealed and _current_card_number >= hint.min_reveal_card:
			revealable.append(hint)
	return revealable


func should_trigger_twist() -> bool:
	"""Determine si un twist devrait se produire."""
	return _rng.randf() < world.global_tension


func get_available_twist() -> Dictionary:
	"""Retourne un twist disponible a partir du foreshadowing."""
	var revealable := get_revealable_foreshadowing()
	if revealable.is_empty():
		return {}

	var hint: Dictionary = revealable[_rng.randi() % revealable.size()]
	hint.revealed = true
	foreshadowing_revealed.emit(hint.id)
	twist_triggered.emit(hint.twist_type)

	return {
		"hint_id": hint.id,
		"twist_type": hint.twist_type,
		"original_hint": hint.hint,
	}

# ═══════════════════════════════════════════════════════════════════════════════
# NPC TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func _track_npc_encounter(npc_id: String, card: Dictionary) -> void:
	if not npcs.has(npc_id):
		npcs[npc_id] = {
			"encounters": 0,
			"last_seen_card": 0,
			"relationship": 0,
			"secrets_known": [],
			"can_return": true,
			"arc_id": "",
		}

	npcs[npc_id].encounters += 1
	npcs[npc_id].last_seen_card = _current_card_number

	# Update relationship if card specifies
	var rel_change: int = card.get("npc_relationship_change", 0)
	npcs[npc_id].relationship = clampi(npcs[npc_id].relationship + rel_change, -100, 100)

	# Track secrets
	var secrets: Array = card.get("npc_secrets_revealed", [])
	for secret in secrets:
		if secret not in npcs[npc_id].secrets_known:
			npcs[npc_id].secrets_known.append(secret)

	# Link to arc
	var arc_id: String = card.get("arc_id", "")
	if arc_id != "":
		npcs[npc_id].arc_id = arc_id


func get_npc_info(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})


func get_npcs_for_callback(min_cards_since: int = 10) -> Array:
	"""Retourne les NPCs disponibles pour un retour."""
	var available := []
	for npc_id in npcs:
		var npc: Dictionary = npcs[npc_id]
		if not npc.can_return:
			continue
		var cards_since: int = _current_card_number - npc.last_seen_card
		if cards_since >= min_cards_since:
			available.append({
				"npc_id": npc_id,
				"cards_since": cards_since,
				"relationship": npc.relationship,
				"encounters": npc.encounters,
			})
	return available

# ═══════════════════════════════════════════════════════════════════════════════
# THEME WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func get_theme_weight(theme: String) -> float:
	"""Retourne le poids d'un theme (fatigue = poids bas)."""
	var base_weight := 1.0
	var fatigue: float = theme_fatigue.get(theme, 0.0)
	var fatigue_penalty: float = fatigue * 0.15
	return maxf(0.1, base_weight - fatigue_penalty)


func get_recommended_themes() -> Array:
	"""Retourne les themes a privilegier (peu de fatigue)."""
	var weights := {}
	for theme in THEMES:
		weights[theme] = get_theme_weight(theme)

	# Sort by weight descending
	var sorted_themes := THEMES.duplicate()
	sorted_themes.sort_custom(func(a, b): return weights[a] > weights[b])

	return sorted_themes.slice(0, 3)


func get_fatigued_themes() -> Array:
	"""Retourne les themes a eviter."""
	var fatigued := []
	for theme in theme_fatigue:
		if theme_fatigue[theme] >= THEME_FATIGUE_WARNING:
			fatigued.append(theme)
	return fatigued

# ═══════════════════════════════════════════════════════════════════════════════
# WORLD PROGRESSION
# ═══════════════════════════════════════════════════════════════════════════════

func advance_day() -> void:
	"""Avance d'un jour."""
	world.day += 1

	# Progress time of day
	var time_idx := TIMES_OF_DAY.find(world.time_of_day)
	time_idx = (time_idx + 1) % TIMES_OF_DAY.size()
	world.time_of_day = TIMES_OF_DAY[time_idx]

	# Progress season every 30 days
	if world.day % 30 == 0:
		var season_idx := SEASONS.find(world.season)
		season_idx = (season_idx + 1) % SEASONS.size()
		world.season = SEASONS[season_idx]

	# Random weather change
	if _rng.randf() < 0.3:
		world.weather = WEATHERS[_rng.randi() % WEATHERS.size()]


func set_biome(biome: String) -> void:
	world.biome = biome


func increase_tension(amount: float = 0.05) -> void:
	world.global_tension = minf(1.0, world.global_tension + amount)


func decrease_tension(amount: float = 0.1) -> void:
	world.global_tension = maxf(0.0, world.global_tension - amount)

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT FOR LLM
# ═══════════════════════════════════════════════════════════════════════════════

func get_context_for_llm() -> Dictionary:
	return {
		"active_arcs": active_arcs.map(func(a): return {"id": a.id, "stage": a.stage}),
		"active_foreshadowing": foreshadowing.filter(func(f): return not f.revealed).size(),
		"revealable_twists": get_revealable_foreshadowing().size(),
		"recent_themes": recent_themes.duplicate(),
		"fatigued_themes": get_fatigued_themes(),
		"recommended_themes": get_recommended_themes(),
		"tension_level": world.global_tension,
		"known_npcs": npcs.keys(),
		"npcs_for_callback": get_npcs_for_callback().map(func(n): return n.npc_id),
		"world_state": world.duplicate(),
	}


func get_summary_for_prompt() -> String:
	"""Resume textuel pour le prompt LLM."""
	var lines := []

	# World state
	lines.append("Jour %d, %s, %s" % [world.day, world.time_of_day, world.season])
	lines.append("Lieu: %s, Meteo: %s" % [world.biome, world.weather])

	# Active arcs
	if active_arcs.size() > 0:
		var arc_names := active_arcs.map(func(a): return "%s (etape %d)" % [a.id, a.stage])
		lines.append("Arcs actifs: " + ", ".join(arc_names))

	# Tension
	if world.global_tension > 0.7:
		lines.append("Tension narrative ELEVEE - twist imminent")
	elif world.global_tension > 0.5:
		lines.append("Tension narrative montante")

	# Themes
	var fatigued := get_fatigued_themes()
	if fatigued.size() > 0:
		lines.append("Eviter themes: " + ", ".join(fatigued))

	var recommended := get_recommended_themes()
	if recommended.size() > 0:
		lines.append("Privilegier themes: " + ", ".join(recommended))

	# NPCs
	var callbacks := get_npcs_for_callback()
	if callbacks.size() > 0:
		var npc_names := callbacks.map(func(n): return n.npc_id)
		lines.append("NPCs disponibles pour retour: " + ", ".join(npc_names))

	return "\n".join(lines)

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func on_run_end() -> void:
	"""Appele a la fin d'une run."""
	# Close all active arcs
	for arc in active_arcs:
		_complete_arc(arc, "run_ended")

	save_to_disk()


func save_to_disk() -> void:
	var data := {
		"version": VERSION,
		"completed_arcs": completed_arcs,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.has("completed_arcs"):
		completed_arcs = data.completed_arcs
