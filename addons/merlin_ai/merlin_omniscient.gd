## ═══════════════════════════════════════════════════════════════════════════════
## MERLIN OMNISCIENT SYSTEM (MOS) — Main Orchestrator
## ═══════════════════════════════════════════════════════════════════════════════
## M.E.R.L.I.N. = Memoire Eternelle des Recits et Legendes d'Incarnations Narratives
##
## Cet orchestrateur coordonne tous les registres et systemes pour faire de Merlin
## une intelligence narrative veritablement omnisciente.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MerlinOmniscient

signal card_generated(card: Dictionary)
signal fallback_used(reason: String)
signal context_built(context: Dictionary)
signal trust_tier_changed(old_tier: int, new_tier: int)
signal pattern_detected(pattern: String, confidence: float)
signal wellness_alert(alert_type: String, data: Dictionary)
signal merlin_speaks(text: String, tone: String)

const VERSION := "1.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# REGISTRIES
# ═══════════════════════════════════════════════════════════════════════════════

var player_profile: PlayerProfileRegistry
var decision_history: DecisionHistoryRegistry
var relationship: RelationshipRegistry
var narrative: NarrativeRegistry
var session: SessionRegistry

# ═══════════════════════════════════════════════════════════════════════════════
# PROCESSORS
# ═══════════════════════════════════════════════════════════════════════════════

var context_builder: MerlinContextBuilder
var difficulty_adapter: DifficultyAdapter
var narrative_scaler: NarrativeScaler
var tone_controller: ToneController

# ═══════════════════════════════════════════════════════════════════════════════
# GENERATORS
# ═══════════════════════════════════════════════════════════════════════════════

var llm_interface: MerlinAI  # Reference to merlin_ai.gd
var fast_route: FastRoute
var fallback_pool: MerlinFallbackPool

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _store: Node = null  # Reference to DruStore
var _is_ready := false
var _current_context: Dictionary = {}
var _generation_in_progress := false
var _last_card_time_ms := 0

# LLM Configuration
const LLM_TIMEOUT_MS := 5000
const MAX_RETRIES := 2
const FALLBACK_BLEND_RATE := 0.2  # 20% fallback pour variete

# Cache
var _response_cache := {}
const CACHE_LIMIT := 100

# Stats
var stats := {
	"cards_generated": 0,
	"llm_successes": 0,
	"llm_failures": 0,
	"fallback_uses": 0,
	"fast_route_hits": 0,
	"average_generation_time_ms": 0.0,
}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_init_registries()
	_init_processors()
	_init_generators()
	_connect_signals()


func setup(store: Node) -> void:
	"""Configure avec reference au DruStore."""
	_store = store
	_is_ready = true
	print("[MerlinOmniscient] Setup complete. M.E.R.L.I.N. is watching.")


func _init_registries() -> void:
	player_profile = PlayerProfileRegistry.new()
	decision_history = DecisionHistoryRegistry.new()
	relationship = RelationshipRegistry.new()
	narrative = NarrativeRegistry.new()
	session = SessionRegistry.new()


func _init_processors() -> void:
	context_builder = MerlinContextBuilder.new()
	context_builder.setup(player_profile, decision_history, relationship, narrative, session)

	difficulty_adapter = DifficultyAdapter.new()
	narrative_scaler = NarrativeScaler.new()
	tone_controller = ToneController.new()


func _init_generators() -> void:
	# Try to get existing MerlinAI node
	llm_interface = get_node_or_null("/root/MerlinAI")
	if llm_interface == null:
		# Create if not exists
		var merlin_ai_scene = load("res://addons/merlin_ai/merlin_ai.gd")
		if merlin_ai_scene:
			llm_interface = merlin_ai_scene.new()
			llm_interface.name = "MerlinAI_Omniscient"
			add_child(llm_interface)

	fallback_pool = MerlinFallbackPool.new()


func _connect_signals() -> void:
	# Registry signals
	relationship.trust_changed.connect(_on_trust_changed)
	decision_history.pattern_detected.connect(_on_pattern_detected)
	session.wellness_alert.connect(_on_wellness_alert)

	# Narrative signals
	narrative.arc_completed.connect(_on_arc_completed)
	narrative.twist_triggered.connect(_on_twist_triggered)


func is_ready() -> bool:
	return _is_ready

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN CARD GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func generate_card(game_state: Dictionary) -> Dictionary:
	"""Genere une carte en utilisant toute l'omniscience de Merlin."""
	if _generation_in_progress:
		return fallback_pool.get_fallback_card(_current_context)

	_generation_in_progress = true
	var start_time := Time.get_ticks_msec()

	# Build full context
	_current_context = context_builder.build_full_context(game_state)
	context_built.emit(_current_context)

	# Apply adaptive processing
	_apply_adaptive_processing()

	# Determine generation strategy
	var card := await _generate_with_strategy()

	# Validate and sanitize
	card = _validate_card(card)

	# Post-process (apply difficulty scaling, etc.)
	card = _post_process_card(card)

	# Update stats
	var generation_time := Time.get_ticks_msec() - start_time
	_update_stats(generation_time, card)

	_generation_in_progress = false
	_last_card_time_ms = Time.get_ticks_msec()

	card_generated.emit(card)
	return card


func _apply_adaptive_processing() -> void:
	# Update difficulty based on player profile
	difficulty_adapter.update_from_profile(player_profile)
	difficulty_adapter.update_from_session(session)

	# Update narrative features based on experience
	var tier := player_profile.get_experience_tier()
	narrative_scaler.set_tier(tier)

	# Update tone based on relationship
	tone_controller.update_from_relationship(relationship)
	tone_controller.update_from_session(session)


func _generate_with_strategy() -> Dictionary:
	"""Choisit et execute la strategie de generation."""

	# Strategy 1: Force fallback sometimes for variety
	if randf() < FALLBACK_BLEND_RATE:
		stats.fallback_uses += 1
		return fallback_pool.get_fallback_card(_current_context)

	# Strategy 2: Try LLM if available
	if llm_interface != null and llm_interface.is_ready:
		var llm_card := await _try_llm_generation()
		if not llm_card.is_empty():
			stats.llm_successes += 1
			return llm_card
		else:
			stats.llm_failures += 1

	# Strategy 3: Fallback pool
	stats.fallback_uses += 1
	fallback_used.emit("llm_unavailable")
	return fallback_pool.get_fallback_card(_current_context)


func _try_llm_generation() -> Dictionary:
	"""Tente de generer via LLM avec retries."""
	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()

	for attempt in range(MAX_RETRIES):
		var result := await llm_interface.generate_with_system(
			system_prompt,
			user_prompt,
			{"max_tokens": 256, "temperature": 0.7}
		)

		if result.has("error"):
			continue

		var text: String = result.get("text", "")
		var parsed := _parse_llm_response(text)

		if not parsed.is_empty():
			return parsed

	return {}


func _build_system_prompt() -> String:
	"""Construit le system prompt avec contexte complet."""
	var base := """Tu es Merlin, une intelligence narrative omnisciente.
Tu connais le joueur intimement: ses choix, ses patterns, ses preferences.
Tu generes des cartes narratives qui s'adaptent parfaitement a lui.

%s

REGLES ABSOLUES:
1. Chaque carte a 2-3 options (gauche, [centre], droite)
2. Chaque option affecte les aspects: Corps, Ame, Monde
3. Les effets sont des tradeoffs (+ et -)
4. Reflete les patterns du joueur dans tes propositions
5. Adapte ton ton au niveau de confiance

FORMAT JSON:
{
  "text": "Texte narratif...",
  "options": [
    {"direction": "left", "label": "...", "effects": [...], "preview": "..."},
    {"direction": "right", "label": "...", "effects": [...], "preview": "..."}
  ],
  "tags": ["tag1", "tag2"],
  "tone": "neutral|mysterious|warning|playful|melancholy"
}"""

	# Add context summaries
	var context_text := ""
	context_text += "\n=== PROFIL JOUEUR ===\n"
	context_text += player_profile.get_summary_for_prompt()
	context_text += "\n\n=== PATTERNS DETECTES ===\n"
	context_text += decision_history.get_pattern_for_llm()
	context_text += "\n\n=== RELATION ===\n"
	context_text += relationship.get_summary_for_prompt()
	context_text += "\n\n=== NARRATIF ===\n"
	context_text += narrative.get_summary_for_prompt()
	context_text += "\n\n=== SESSION ===\n"
	context_text += session.get_summary_for_prompt()

	return base % context_text


func _build_user_prompt() -> String:
	"""Construit le user prompt avec l'etat actuel."""
	var prompt := "Genere une carte pour cette situation:\n\n"

	# Current game state
	var aspects = _current_context.get("aspects", {})
	prompt += "Aspects actuels:\n"
	for aspect in aspects:
		var state: int = int(aspects[aspect])
		var state_name := "Equilibre" if state == 0 else ("Haut" if state > 0 else "Bas")
		prompt += "- %s: %s\n" % [aspect, state_name]

	# Souffle
	prompt += "\nSouffle: %d\n" % _current_context.get("souffle", 0)

	# Day and progression
	prompt += "Jour: %d, Cartes jouees: %d\n" % [
		_current_context.get("day", 1),
		_current_context.get("cards_played", 0)
	]

	# Active arcs
	var arcs = _current_context.get("narrative", {}).get("active_arcs", [])
	if arcs.size() > 0:
		prompt += "\nArcs actifs: %s\n" % ", ".join(arcs.map(func(a): return str(a)))

	# Recommendations
	var themes := narrative.get_recommended_themes()
	prompt += "\nThemes recommandes: %s\n" % ", ".join(themes)

	# Tone
	var tone_mods := relationship.get_tone_modifiers()
	if tone_mods.get("darkness", 0) > 0.1:
		prompt += "\nTon: Peut inclure de la profondeur/melancolie\n"

	return prompt


func _parse_llm_response(text: String) -> Dictionary:
	"""Parse la reponse LLM en carte valide."""
	# Find JSON in response
	var json_start := text.find("{")
	var json_end := text.rfind("}")

	if json_start == -1 or json_end == -1:
		return {}

	var json_text := text.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	# Validate structure
	if not parsed.has("text") or not parsed.has("options"):
		return {}

	return parsed

# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION & POST-PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_card(card: Dictionary) -> Dictionary:
	"""Valide et sanitize une carte."""
	if card.is_empty():
		return fallback_pool.get_fallback_card(_current_context)

	# Validate text
	if typeof(card.get("text", null)) != TYPE_STRING:
		card["text"] = "..."

	# Validate options
	if typeof(card.get("options", null)) != TYPE_ARRAY:
		card["options"] = []

	if card.options.size() < 2:
		return fallback_pool.get_fallback_card(_current_context)

	# Validate each option
	for i in range(card.options.size()):
		card.options[i] = _validate_option(card.options[i])

	# Ensure tags is array
	if typeof(card.get("tags", null)) != TYPE_ARRAY:
		card["tags"] = []

	# Add generated flag
	card["_generated_by"] = "merlin_omniscient"
	card["_timestamp"] = Time.get_unix_time_from_system()

	return card


func _validate_option(option: Dictionary) -> Dictionary:
	if typeof(option) != TYPE_DICTIONARY:
		return {"direction": "left", "label": "...", "effects": []}

	# Ensure direction
	if not option.has("direction"):
		option["direction"] = "left"

	# Ensure label
	if not option.has("label"):
		option["label"] = "..."

	# Validate effects
	if typeof(option.get("effects", null)) != TYPE_ARRAY:
		option["effects"] = []

	# Clamp effect values
	for effect in option.effects:
		if effect.has("value"):
			effect.value = clampi(int(effect.value), -40, 40)

	return option


func _post_process_card(card: Dictionary) -> Dictionary:
	"""Applique les modifications post-generation."""

	# Scale effects based on difficulty
	for option in card.get("options", []):
		for effect in option.get("effects", []):
			if effect.has("value"):
				var original := int(effect.value)
				var effect_type := "negative" if original < 0 else "positive"
				effect.value = difficulty_adapter.scale_effect(original, effect_type, _current_context)

	# Add ID if missing
	if not card.has("id"):
		card["id"] = "gen_%d" % Time.get_ticks_msec()

	# Add narrative elements if appropriate
	card = _add_narrative_elements(card)

	return card


func _add_narrative_elements(card: Dictionary) -> Dictionary:
	"""Ajoute des elements narratifs contextuels."""

	# Check if should trigger foreshadowing
	var features := narrative_scaler.get_features()
	if features.get("foreshadowing", false):
		if randf() < 0.1:  # 10% chance
			var twist_types := ["identity_hidden", "consequence_differee"]
			var twist_type := twist_types[randi() % twist_types.size()]
			card["_foreshadowing"] = twist_type

	# Check if should callback NPC
	var callbacks := narrative.get_npcs_for_callback()
	if callbacks.size() > 0 and randf() < 0.2:  # 20% chance
		var npc := callbacks[randi() % callbacks.size()]
		card["npc_callback"] = npc.npc_id
		card["npc_relationship"] = npc.relationship

	return card

# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RECORDING
# ═══════════════════════════════════════════════════════════════════════════════

func record_choice(card: Dictionary, option: int, outcome: Dictionary) -> void:
	"""Enregistre un choix et met a jour tous les registres."""
	var decision_time_ms := Time.get_ticks_msec() - _last_card_time_ms

	var context := {
		"gauges": outcome.get("gauges_before", {}),
		"decision_time_ms": decision_time_ms,
		"day": narrative.world.day,
		"biome": narrative.world.biome,
	}

	# Update all registries
	player_profile.update_from_choice(card, option, context)
	player_profile.update_from_outcome(outcome)

	decision_history.record_choice(card, option, context)
	decision_history.update_last_entry_gauges(outcome.get("gauges_after", {}))

	session.record_decision(decision_time_ms)

	narrative.process_card(card)

	# Check for relationship updates
	if outcome.get("promise_kept", false):
		relationship.record_interaction("promises_kept")
	if outcome.get("promise_broken", false):
		relationship.record_interaction("promises_broken")

	# Skill usage
	if outcome.get("skill_used", false):
		session.record_skill_use()


func on_run_start() -> void:
	"""Appele au debut d'une run."""
	session.record_run_start()
	decision_history.reset_run()
	narrative.reset_run()


func on_run_end(run_data: Dictionary) -> void:
	"""Appele a la fin d'une run."""
	player_profile.on_run_end(run_data)
	decision_history.on_run_end(run_data)
	narrative.on_run_end()

	# Check for relationship updates
	var cards_played: int = run_data.get("cards_played", 0)
	if cards_played >= 100:
		relationship.update_trust("long_run_100")
	if cards_played >= 150:
		relationship.update_trust("long_run_150")
	if cards_played < 20:
		relationship.update_trust("quick_death")

	session.record_death()

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN'S VOICE
# ═══════════════════════════════════════════════════════════════════════════════

func get_merlin_comment(context: String) -> String:
	"""Genere un commentaire de Merlin adapte au contexte."""
	var tone := tone_controller.get_current_tone()
	var trust_tier := relationship.trust_tier

	# Get appropriate comment
	var comment := await _generate_merlin_comment(context, tone)

	merlin_speaks.emit(comment, tone)
	return comment


func _generate_merlin_comment(context: String, tone: String) -> String:
	"""Genere un commentaire via LLM ou fallback."""
	if llm_interface == null or not llm_interface.is_ready:
		return _get_fallback_comment(context, tone)

	var system := """Tu es Merlin. Genere UN SEUL commentaire court (1-2 phrases).
Ton: %s
Niveau de confiance avec le joueur: %s

Contexte: %s

Reponds uniquement avec le commentaire, sans guillemets.""" % [
		tone,
		relationship.get_trust_tier_name(),
		context
	]

	var result := await llm_interface.generate_with_router(system, "", {"max_tokens": 64})
	if result.has("text"):
		return str(result.text).strip_edges()

	return _get_fallback_comment(context, tone)


func _get_fallback_comment(context: String, tone: String) -> String:
	"""Commentaires fallback par ton."""
	var comments := {
		"playful": [
			"Interessant choix...",
			"Tu me surprends, voyageur.",
			"Ah, je n'aurais pas fait ca. Mais bon.",
		],
		"mysterious": [
			"Le chemin se revele...",
			"Les fils du destin s'entrelacent.",
			"Certaines portes ne s'ouvrent qu'une fois.",
		],
		"warning": [
			"Attention au chemin que tu prends.",
			"Reflechis bien avant d'agir.",
			"Les consequences arrivent toujours.",
		],
		"melancholy": [
			"...parfois, je me demande...",
			"Le temps passe si vite.",
			"Certaines choses ne reviennent jamais.",
		],
	}

	var tone_comments: Array = comments.get(tone, comments.playful)
	return tone_comments[randi() % tone_comments.size()]

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_trust_changed(old_tier: int, new_tier: int, points: int) -> void:
	trust_tier_changed.emit(old_tier, new_tier)


func _on_pattern_detected(pattern: String, confidence: float) -> void:
	pattern_detected.emit(pattern, confidence)


func _on_wellness_alert(alert_type: String, data: Dictionary) -> void:
	wellness_alert.emit(alert_type, data)

	# Adjust generation based on wellness
	if alert_type == "frustration":
		difficulty_adapter.enable_pity_mode()
	elif alert_type == "fatigue":
		# Prefer simpler cards
		pass


func _on_arc_completed(arc_id: String, resolution: String) -> void:
	relationship.update_trust("completed_arc")


func _on_twist_triggered(twist_type: String) -> void:
	narrative.decrease_tension(0.2)

# ═══════════════════════════════════════════════════════════════════════════════
# STATS
# ═══════════════════════════════════════════════════════════════════════════════

func _update_stats(generation_time: int, card: Dictionary) -> void:
	stats.cards_generated += 1

	# Update average generation time
	stats.average_generation_time_ms = (
		(stats.average_generation_time_ms * (stats.cards_generated - 1) + generation_time)
		/ float(stats.cards_generated)
	)


func get_stats() -> Dictionary:
	var s := stats.duplicate()
	s["success_rate"] = (
		float(stats.llm_successes) / maxf(1.0, float(stats.llm_successes + stats.llm_failures))
	)
	return s


func get_debug_info() -> Dictionary:
	return {
		"is_ready": _is_ready,
		"stats": get_stats(),
		"player_experience": player_profile.get_experience_tier_name(),
		"trust_tier": relationship.get_trust_tier_name(),
		"trust_points": relationship.trust_points,
		"active_arcs": narrative.active_arcs.size(),
		"patterns_detected": decision_history.patterns_detected.size(),
		"session_cards": session.current.cards_this_session,
		"current_tone": tone_controller.get_current_tone() if tone_controller else "unknown",
	}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func save_all() -> void:
	"""Sauvegarde tous les registres."""
	player_profile.save_to_disk()
	decision_history.save_to_disk()
	relationship.save_to_disk()
	narrative.save_to_disk()
	session.save_to_disk()


func _exit_tree() -> void:
	save_all()
