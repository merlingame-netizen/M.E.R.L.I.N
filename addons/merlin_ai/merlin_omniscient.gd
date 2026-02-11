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

var llm_interface: Node  # Reference to merlin_ai.gd (autoload, no class_name)
var fast_route: FastRoute
var fallback_pool: MerlinFallbackPool
var rag_manager: RAGManager  # RAG v2.0 — priority-based context

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

# Guardrails
const GUARDRAIL_MIN_TEXT_LEN := 10
const GUARDRAIL_MAX_TEXT_LEN := 500
const GUARDRAIL_LANG_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et"]
const GUARDRAIL_LANG_THRESHOLD := 2  # min French keywords to pass
var _recent_card_texts: Array[String] = []
const RECENT_CARDS_MEMORY := 10
const REPETITION_SIMILARITY_THRESHOLD := 0.7

# Cache
var _response_cache := {}
const CACHE_LIMIT := 300

# Async pre-generation pipeline
var _prefetched_card: Dictionary = {}
var _prefetch_in_progress := false
var _prefetch_context_hash: int = 0  # Hash of game state when prefetch started
var _prefetch_aspects: Dictionary = {}  # Aspect values when prefetch started
var _prefetch_biome: String = ""  # Biome when prefetch started
signal prefetch_ready

# Stats
var stats := {
	"cards_generated": 0,
	"llm_successes": 0,
	"llm_failures": 0,
	"fallback_uses": 0,
	"fast_route_hits": 0,
	"prefetch_hits": 0,
	"prefetch_misses": 0,
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
	## Configure avec reference au DruStore.
	_store = store
	_is_ready = true
	print("[MerlinOmniscient] Setup complete. M.E.R.L.I.N. is watching.")


func _init_registries() -> void:
	player_profile = PlayerProfileRegistry.new()
	decision_history = DecisionHistoryRegistry.new()
	relationship = RelationshipRegistry.new()
	narrative = NarrativeRegistry.new()
	session = SessionRegistry.new()
	# Load persisted data for each registry
	player_profile.load_from_disk()
	decision_history.load_from_disk()
	relationship.load_from_disk()
	narrative.load_from_disk()
	session.load_from_disk()


func _init_processors() -> void:
	context_builder = MerlinContextBuilder.new()
	context_builder.setup(player_profile, decision_history, relationship, narrative, session)

	difficulty_adapter = DifficultyAdapter.new()
	narrative_scaler = NarrativeScaler.new()
	tone_controller = ToneController.new()


func _init_generators() -> void:
	# Use the autoload MerlinAI — never create a duplicate instance
	llm_interface = get_node_or_null("/root/MerlinAI")
	if llm_interface == null:
		# Autoload may not be ready yet, defer lookup
		call_deferred("_deferred_find_merlin_ai")

	fallback_pool = MerlinFallbackPool.new()

	# RAG v2.0 — get from MerlinAI autoload or create standalone
	if llm_interface and llm_interface.rag_manager:
		rag_manager = llm_interface.rag_manager
	else:
		rag_manager = RAGManager.new()
		add_child(rag_manager)


func _deferred_find_merlin_ai() -> void:
	llm_interface = get_node_or_null("/root/MerlinAI")
	if llm_interface:
		print("[MerlinOmniscient] Found MerlinAI autoload (deferred)")
		if llm_interface.rag_manager and rag_manager != llm_interface.rag_manager:
			# Switch to shared RAG instance
			if rag_manager and rag_manager.get_parent() == self:
				rag_manager.queue_free()
			rag_manager = llm_interface.rag_manager


func _connect_signals() -> void:
	# Registry signals
	relationship.trust_changed.connect(_on_trust_changed)
	decision_history.pattern_detected.connect(_on_pattern_detected)
	session.wellness_alert.connect(_on_wellness_alert)

	# Narrative signals
	narrative.arc_completed.connect(_on_arc_completed)
	narrative.twist_triggered.connect(_on_twist_triggered)

	# Screen distortion reacts to Merlin's tone
	merlin_speaks.connect(_on_merlin_speaks_screen_fx)


func is_ready() -> bool:
	return _is_ready

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN CARD GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func generate_card(game_state: Dictionary) -> Dictionary:
	## Genere une carte en utilisant toute l'omniscience de Merlin.
	## Utilise le prefetch si disponible et pertinent.
	## Protected: always returns a valid card, never crashes.
	if _generation_in_progress:
		if fallback_pool:
			return fallback_pool.get_fallback_card(_current_context)
		return _emergency_card()

	_generation_in_progress = true
	var start_time := Time.get_ticks_msec()
	var card: Dictionary = {}

	# Build full context (protected)
	if context_builder:
		_current_context = context_builder.build_full_context(game_state)
		context_built.emit(_current_context)
	else:
		push_warning("[MOS] context_builder is null, using empty context")
		_current_context = {}

	# Check if prefetched card is available and relevant
	card = _try_use_prefetch(game_state)
	if not card.is_empty():
		stats.prefetch_hits += 1
	else:
		stats.prefetch_misses += 1

		# Sync MOS registries to RAG v2.0 for prioritized retrieval
		if context_builder and narrative:
			_sync_mos_to_rag()

		# Apply adaptive processing
		if difficulty_adapter:
			_apply_adaptive_processing()

		# Determine generation strategy
		card = await _generate_with_strategy()

	# Guardrails: validate language, repetition, length
	card = _apply_guardrails(card)

	# Validate and sanitize
	card = _validate_card(card)

	# Post-process (apply difficulty scaling, etc.)
	if difficulty_adapter:
		card = _post_process_card(card)

	# Journal: log the generated card in RAG
	if rag_manager:
		var day: int = int(_current_context.get("day", 1))
		var cards_played: int = int(_current_context.get("cards_played", 0))
		rag_manager.log_card_played(card, cards_played, day)

	# Update stats
	var generation_time := Time.get_ticks_msec() - start_time
	_update_stats(generation_time, card)

	_generation_in_progress = false
	_last_card_time_ms = Time.get_ticks_msec()

	card_generated.emit(card)
	return card


func generate_npc_card(game_state: Dictionary) -> Dictionary:
	## Genere une carte de rencontre PNJ via LLM, fallback sur pool statique.
	var npc_names := ["Druide Ancien", "Villageoise", "Barde Errant", "Guerrier du Gue", "Marchand des Ombres"]
	var npc_name: String = npc_names[randi() % npc_names.size()]

	# Try LLM generation
	if llm_interface and llm_interface.is_ready and llm_interface.has_method("generate_with_system"):
		var aspects_str := ""
		if _current_context.has("aspects"):
			var asp: Dictionary = _current_context.get("aspects", {})
			aspects_str = "Corps=%s, Ame=%s, Monde=%s" % [str(asp.get("Corps", 0)), str(asp.get("Ame", 0)), str(asp.get("Monde", 0))]

		var system_prompt := "Tu es %s, un PNJ celtique. Parle en 1-2 phrases, ton mysterieux. Reponds en francais." % npc_name
		var user_prompt := "Le voyageur te croise en Broceliande. Aspects: %s. Dis une replique immersive." % aspects_str

		var result: Dictionary = await llm_interface.generate_with_system(
			system_prompt, user_prompt,
			{"max_tokens": 60, "temperature": 0.8, "timeout": 5.0}
		)

		var text: String = result.get("text", "").strip_edges()
		if text.length() > 10:
			return {
				"id": "npc_llm_%d" % Time.get_ticks_msec(),
				"text": text,
				"speaker": npc_name,
				"type": "npc_encounter",
				"options": [
					{"direction": "left", "label": "Ecouter", "effects": [
						{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}
					], "preview": "+Ame"},
					{"direction": "center", "label": "Mediter", "effects": [
						{"type": "ADD_SOUFFLE", "amount": 1}
					], "preview": "+Souffle", "cost": 1},
					{"direction": "right", "label": "Continuer", "effects": [
						{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
					], "preview": "+Corps"},
				],
				"tags": ["npc", "llm_generated"],
				"source": "llm",
			}

	# Fallback: pool statique
	if fallback_pool and fallback_pool.has_method("get_npc_card"):
		var card: Dictionary = fallback_pool.get_npc_card()
		if not card.is_empty():
			card["source"] = "fallback"
			return card

	# Ultra-fallback
	return {
		"id": "npc_emergency_%d" % Time.get_ticks_msec(),
		"text": "Une silhouette se dessine dans la brume. 'Voyageur... nos chemins se croisent pour une raison.'",
		"speaker": "Inconnu",
		"type": "npc_encounter",
		"options": [
			{"direction": "left", "label": "S'approcher", "effects": [
				{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}
			], "preview": "+Monde"},
			{"direction": "center", "label": "Observer", "effects": [
				{"type": "ADD_SOUFFLE", "amount": 1}
			], "preview": "+Souffle", "cost": 1},
			{"direction": "right", "label": "S'eloigner", "effects": [
				{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
			], "preview": "+Corps"},
		],
		"tags": ["npc", "emergency"],
		"source": "emergency",
	}


func _emergency_card() -> Dictionary:
	## Absolute last-resort card when even fallback_pool is null.
	return {
		"id": "emergency_%d" % Time.get_ticks_msec(),
		"text": "Le vent murmure entre les pierres dressees. Tu sens le poids du destin peser sur tes epaules...",
		"speaker": "Merlin",
		"type": "narrative",
		"options": [
			{"direction": "left", "label": "Ecouter le vent", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}], "preview": "Sagesse"},
			{"direction": "center", "label": "Mediter", "effects": [{"type": "ADD_SOUFFLE", "amount": 1}], "preview": "+Souffle", "cost": 1},
			{"direction": "right", "label": "Avancer", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}], "preview": "Action"},
		],
		"tags": ["emergency"],
	}


func prefetch_next_card(game_state: Dictionary) -> void:
	## Pre-generate the next card in background while player reads current card.
	## Uses the worker pool: dedicated workers (3-4 brains) or idle primary brains (2 brains).
	## Called by the controller after displaying a card.
	if _prefetch_in_progress or _generation_in_progress:
		return
	if llm_interface == null or not llm_interface.is_ready:
		return

	_prefetch_in_progress = true
	_prefetch_context_hash = _compute_context_hash(game_state)
	_prefetched_card = {}
	var run: Dictionary = game_state.get("run", {})
	_prefetch_aspects = run.get("aspects", {}).duplicate()
	_prefetch_biome = str(run.get("current_biome", ""))

	# Build context for next card (simulate state after a neutral choice)
	var prefetch_context := context_builder.build_full_context(game_state)
	_current_context = prefetch_context

	# Sync and process
	_sync_mos_to_rag()
	_apply_adaptive_processing()

	# Pool path: use generate_prefetch (leases best available brain)
	if llm_interface.has_method("generate_prefetch") and llm_interface.has_prefetcher():
		var card := await _prefetch_via_pool()
		if _prefetch_in_progress and not card.is_empty():
			_prefetched_card = card
			_prefetch_in_progress = false
			prefetch_ready.emit()
			return

	# Fallback: use full strategy pipeline
	var card := await _generate_with_strategy()

	# Only store if still relevant (no new generation started)
	if _prefetch_in_progress:
		_prefetched_card = card
		_prefetch_in_progress = false
		prefetch_ready.emit()


func _prefetch_via_pool() -> Dictionary:
	## Use the worker pool for background card pre-generation.
	## Leases the best available brain (pool worker > idle primary).
	if llm_interface == null:
		return {}

	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()

	var result: Dictionary = await llm_interface.generate_prefetch(
		system_prompt,
		user_prompt,
		{"max_tokens": 200, "temperature": 0.5}
	)

	if result.has("error"):
		return {}

	var text: String = result.get("text", "")
	var parsed := _parse_llm_response(text)

	if not parsed.is_empty():
		parsed["_prefetched"] = true
		parsed["_pool_brain"] = result.get("_pool_brain", false)
		return parsed

	return {}


func _try_use_prefetch(game_state: Dictionary) -> Dictionary:
	## Check if prefetched card is available and relevant to current state.
	## Uses tolerance-based matching: accepts prefetch if aspects shifted by at most 1 step.
	if _prefetched_card.is_empty():
		return {}

	var card := _prefetched_card
	_prefetched_card = {}

	# Fast path: exact hash match
	var current_hash := _compute_context_hash(game_state)
	if current_hash == _prefetch_context_hash:
		return card

	# Relaxed match: accept if same biome and aspects within tolerance
	var run: Dictionary = game_state.get("run", {})
	var current_biome: String = str(run.get("current_biome", ""))
	if current_biome != _prefetch_biome:
		return {}  # Biome changed — narrative context too different

	var aspects: Dictionary = run.get("aspects", {})
	for aspect in ["Corps", "Ame", "Monde"]:
		var current_val: int = int(aspects.get(aspect, 0))
		var prefetch_val: int = int(_prefetch_aspects.get(aspect, 0))
		if absi(current_val - prefetch_val) > 1:
			return {}  # Aspect shifted too far (2+ steps)

	# Within tolerance — prefetch is still contextually relevant
	return card


func try_consume_prefetch(game_state: Dictionary) -> Dictionary:
	## Public entry point for controller fast-path prefetch consumption.
	return _try_use_prefetch(game_state)


func _compute_context_hash(game_state: Dictionary) -> int:
	## Compute a hash of the game state for prefetch validation.
	## Two states with the same aspects are considered equivalent.
	var run: Dictionary = game_state.get("run", {})
	var aspects: Dictionary = run.get("aspects", {})
	var hash_val: int = 0
	for aspect in ["Corps", "Ame", "Monde"]:
		hash_val = hash_val * 7 + int(aspects.get(aspect, 0)) + 2
	hash_val = hash_val * 13 + int(run.get("souffle", 0))
	return hash_val


func invalidate_prefetch() -> void:
	## Cancel any ongoing prefetch (e.g., when game state changes significantly).
	_prefetched_card = {}
	_prefetch_in_progress = false


func _apply_adaptive_processing() -> void:
	# Update difficulty based on player profile
	difficulty_adapter.update_from_profile(player_profile)
	difficulty_adapter.update_from_session(session)

	# Update narrative features based on experience
	var tier: int = player_profile.get_experience_tier()
	narrative_scaler.set_tier(tier)

	# Update tone based on relationship
	tone_controller.update_from_relationship(relationship)
	tone_controller.update_from_session(session)


func _generate_with_strategy() -> Dictionary:
	## Choisit et execute la strategie de generation.

	# Strategy 1: Force fallback sometimes for variety
	if randf() < FALLBACK_BLEND_RATE and fallback_pool:
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
	if fallback_pool:
		return fallback_pool.get_fallback_card(_current_context)
	return _emergency_card()


func _try_llm_generation() -> Dictionary:
	## Tente de generer via LLM avec retries.
	## Phase 32: Priorite au pipeline parallele (Narrator + Game Master)

	if llm_interface == null or not llm_interface.is_ready:
		return {}

	# Switch LoRA adapter to match current tone (covers all strategies)
	if llm_interface.has_method("set_narrator_tone") and tone_controller:
		llm_interface.set_narrator_tone(tone_controller.get_current_tone())

	# Strategy A: Parallel generation (Phase 32 — requires 2+ brains)
	if llm_interface.has_method("generate_parallel") and llm_interface.brain_count >= 2:
		var parallel_card := await _try_parallel_generation()
		if not parallel_card.is_empty():
			parallel_card["_strategy"] = "parallel"
			return parallel_card

	# Strategy B: Use MerlinLlmAdapter if available (TRIADE-validated, single-instance)
	if _store and _store.llm and _store.llm.is_llm_ready():
		var adapter: MerlinLlmAdapter = _store.llm
		var ctx: Dictionary = adapter.build_triade_context(_store.state)
		var adapter_result: Dictionary = await adapter.generate_card(ctx)
		if adapter_result.get("ok", false):
			return adapter_result.get("card", {})

	# Strategy C: Direct LLM call (fallback)
	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()

	for attempt in range(MAX_RETRIES):
		var result: Dictionary = await llm_interface.generate_with_system(
			system_prompt,
			user_prompt,
			{"max_tokens": 200, "temperature": 0.6}
		)

		if result.has("error"):
			continue

		var text: String = result.get("text", "")
		var parsed := _parse_llm_response(text)

		if not parsed.is_empty():
			return parsed

	return {}


func _try_parallel_generation() -> Dictionary:
	## Phase 32: Generate narrative text + effects in parallel using dual instances.
	## Narrator generates the story text, Game Master generates the effects JSON.

	# Switch LoRA adapter to match current tone (Multi-LoRA mode)
	if llm_interface and llm_interface.has_method("set_narrator_tone") and tone_controller:
		llm_interface.set_narrator_tone(tone_controller.get_current_tone())

	# Build prompts for both instances
	var narrator_system := _build_narrator_prompt()
	var narrator_input := _build_narrator_input()
	var gm_system := _build_gm_prompt()
	var gm_input := _build_gm_input()

	# Load Game Master grammar
	var gm_grammar := ""
	var gm_grammar_path := "res://data/ai/gamemaster_effects.gbnf"
	if FileAccess.file_exists(gm_grammar_path):
		var f := FileAccess.open(gm_grammar_path, FileAccess.READ)
		gm_grammar = f.get_as_text()
		f.close()

	# Launch parallel generation
	var result: Dictionary = await llm_interface.generate_parallel(
		narrator_system, narrator_input,
		gm_system, gm_input,
		gm_grammar
	)

	if result.has("error"):
		return {}

	# Merge narrative text + structured effects into a TRIADE card
	var narrative: Dictionary = result.get("narrative", {})
	var structured: Dictionary = result.get("structured", {})

	if narrative.has("error") or structured.has("error"):
		return {}

	var card := _merge_parallel_results(narrative, structured)
	if card.is_empty():
		return {}

	card["_parallel"] = result.get("parallel", false)
	card["_generation_time_ms"] = result.get("time_ms", 0)
	return card


func _build_narrator_prompt() -> String:
	## System prompt for the Narrator instance — creative, poetic, Celtic.
	var base := "Tu es Merlin l'Enchanteur, druide ancestral des forets de Broceliande. Ecris un scenario immersif (2-3 phrases) pour un jeu de cartes celtique. Propose 3 choix: A) prudent B) mystique C) audacieux. Adapte ton registre: poetique face a la nature, grave quand tu avertis, espiegle quand tu taquines. Vocabulaire: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, pierre dressee. Ecris en francais."

	# Tone guidance from ToneController (detailed register instructions)
	if tone_controller:
		var tone_guidance := tone_controller.get_tone_prompt_guidance()
		if not tone_guidance.is_empty():
			base += "\n" + tone_guidance

	# RAG context for narrative richness
	if rag_manager:
		var rag_ctx := rag_manager.get_prioritized_context(_current_context)
		if not rag_ctx.is_empty():
			base += "\n" + rag_ctx

	return base


func _build_narrator_input() -> String:
	## User prompt for Narrator — game state in natural language.
	var aspects: Dictionary = _current_context.get("aspects", {})
	var parts: Array[String] = []

	for aspect in aspects:
		var s: int = int(aspects[aspect])
		var state_name := "equilibre" if s == 0 else ("haut" if s > 0 else "bas")
		parts.append("%s est %s" % [aspect, state_name])

	parts.append("Jour %d. Souffle: %d." % [
		_current_context.get("day", 1),
		_current_context.get("souffle", 0)
	])

	# Tone hint
	var tone := tone_controller.get_current_tone() if tone_controller else "neutral"
	if tone != "neutral":
		parts.append("Ton: %s." % tone)

	# Themes
	var themes := narrative.get_recommended_themes() if narrative else []
	if themes.size() > 0:
		var theme_strs: Array[String] = []
		for t in themes.slice(0, mini(themes.size(), 2)):
			theme_strs.append(str(t))
		parts.append("Themes: %s." % ", ".join(theme_strs))

	parts.append("Ecris le scenario puis les 3 choix (A/B/C).")
	return " ".join(parts)


func _build_gm_prompt() -> String:
	## System prompt for Game Master — logic, effects, balance.
	return "Tu es le Maitre du Jeu. Genere les effets mecaniques pour 3 options de carte. Reponds UNIQUEMENT en JSON valide. Effets: SHIFT_ASPECT (aspect=Corps/Ame/Monde, direction=up/down), ADD_KARMA (amount), ADD_TENSION (amount)."


func _build_gm_input() -> String:
	## User prompt for Game Master — structured game state.
	var aspects: Dictionary = _current_context.get("aspects", {})
	var parts: Array[String] = []

	for aspect in ["Corps", "Ame", "Monde"]:
		var s: int = int(aspects.get(aspect, 0))
		parts.append("%s=%d" % [aspect, s])

	parts.append("Souffle=%d" % int(_current_context.get("souffle", 0)))
	parts.append("Jour=%d" % int(_current_context.get("day", 1)))
	parts.append("Carte=%d" % int(_current_context.get("cards_played", 0)))

	# Template to guide output format
	parts.append("\n{\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Corps\",\"direction\":\"up\"}]},{\"label\":\"...\",\"cost\":1,\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Ame\",\"direction\":\"up\"}]},{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Monde\",\"direction\":\"down\"}]}]}")

	return " ".join(parts)


func _merge_parallel_results(narrative: Dictionary, structured: Dictionary) -> Dictionary:
	## Merge Narrator text + Game Master effects into a valid TRIADE card.
	var narrative_text: String = str(narrative.get("text", ""))
	var gm_text: String = str(structured.get("text", ""))

	if narrative_text.length() < 10:
		return {}

	# Extract scenario text and choice labels from narrator output
	var scenario_text := narrative_text
	var narrator_labels: Array[String] = []

	# Extract A) B) C) labels
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+(.+)")
	var matches := rx.search_all(narrative_text)
	for m in matches:
		var label := m.get_string(1).strip_edges()
		if label.length() > 2 and label.length() < 80:
			narrator_labels.append(label)

	# Remove choice lines from scenario text
	if narrator_labels.size() >= 2:
		rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+")
		var first_choice := rx.search(scenario_text)
		if first_choice:
			scenario_text = scenario_text.substr(0, first_choice.get_start()).strip_edges()

	# Parse Game Master JSON effects
	var gm_effects: Dictionary = {}
	if not gm_text.is_empty():
		var json_start := gm_text.find("{")
		var json_end := gm_text.rfind("}")
		if json_start >= 0 and json_end > json_start:
			var json_str := gm_text.substr(json_start, json_end - json_start + 1)
			var parsed = JSON.parse_string(json_str)
			if typeof(parsed) == TYPE_DICTIONARY:
				gm_effects = parsed

	# Build merged card
	var gm_options: Array = gm_effects.get("options", [])

	# Merge: use narrator labels + GM effects
	var merged_options: Array = []
	for i in range(3):
		var opt: Dictionary = {}

		# Label: prefer narrator, fallback to GM
		if i < narrator_labels.size():
			opt["label"] = narrator_labels[i]
		elif i < gm_options.size() and gm_options[i] is Dictionary:
			opt["label"] = str(gm_options[i].get("label", "..."))
		else:
			var defaults := ["Agir avec prudence", "Mediter en silence", "Foncer tete baissee"]
			opt["label"] = defaults[i]

		# Cost: center option (index 1)
		if i == 1:
			opt["cost"] = 1

		# Effects: from GM output
		if i < gm_options.size() and gm_options[i] is Dictionary:
			opt["effects"] = gm_options[i].get("effects", [])
		else:
			# Fallback effects
			var aspects_list := ["Corps", "Ame", "Monde"]
			opt["effects"] = [{"type": "SHIFT_ASPECT", "aspect": aspects_list[i], "direction": "up" if i < 2 else "down"}]

		merged_options.append(opt)

	return {
		"text": scenario_text if scenario_text.length() > 5 else narrative_text.substr(0, mini(narrative_text.length(), 200)),
		"speaker": "merlin",
		"options": merged_options,
		"tags": ["llm_generated", "parallel"],
	}


func _sync_mos_to_rag() -> void:
	## Sync MOS registries into RAG v2.0 world state for priority-based retrieval.
	if rag_manager == null:
		return
	var registry_data := {}
	if player_profile:
		var patterns: Dictionary = decision_history.patterns_detected if decision_history else {}
		var player_patterns := {}
		for p_name in patterns:
			var p_data = patterns[p_name]
			if p_data is Dictionary:
				player_patterns[str(p_name)] = p_data
		registry_data["player_patterns"] = player_patterns
	if narrative:
		registry_data["active_arcs"] = narrative.active_arcs if narrative.active_arcs else []
	if relationship:
		registry_data["trust_tier"] = relationship.trust_tier
		registry_data["trust_tier_name"] = relationship.get_trust_tier_name()
	if session:
		registry_data["session_frustration"] = session.current.get("seems_frustrated", false) if session.current is Dictionary else false
	# Sync current tone for RAG tone context section
	if tone_controller:
		registry_data["current_tone"] = tone_controller.get_current_tone()
		registry_data["tone_characteristics"] = tone_controller.get_tone_characteristics()
	rag_manager.sync_from_registries(registry_data)


func _build_system_prompt() -> String:
	## Enriched system prompt for Qwen2.5-3B-Instruct.
	## JSON template moved to user prompt to reduce hallucination.
	## RAG context + tone guidance injected via priority budget.
	var base := "Merlin druide narrateur celtique. Genere 1 carte JSON francais. 3 options avec tradeoffs. Vocabulaire druidique: nemeton, ogham, sidhe, dolmen, korrigans. Reponds UNIQUEMENT en JSON valide."

	# Tone guidance from ToneController
	if tone_controller:
		var tone_guidance := tone_controller.get_tone_prompt_guidance()
		if not tone_guidance.is_empty():
			base += "\n" + tone_guidance

	# RAG v2.0: priority-based dynamic context within token budget
	var rag_context := ""
	if rag_manager:
		rag_context = rag_manager.get_prioritized_context(_current_context)

	if not rag_context.is_empty():
		base += "\n" + rag_context

	return base


func _build_user_prompt() -> String:
	## User prompt with game state AND JSON template (anti-hallucination).
	## Moving the template here forces the model to see it right before generation.
	var aspects: Dictionary = _current_context.get("aspects", {})
	var parts: Array[String] = []

	# Aspects (compact)
	var aspect_parts: Array[String] = []
	for aspect in aspects:
		var s: int = int(aspects[aspect])
		var state_name := "eq" if s == 0 else ("haut" if s > 0 else "bas")
		aspect_parts.append("%s=%s" % [aspect, state_name])
	parts.append("Aspects: " + " ".join(aspect_parts))

	# Souffle + Day
	parts.append("Souffle:%d Jour:%d Carte:%d" % [
		_current_context.get("souffle", 0),
		_current_context.get("day", 1),
		_current_context.get("cards_played", 0)
	])

	# Tone hint from relationship
	var tone := tone_controller.get_current_tone() if tone_controller else "neutral"
	if tone != "neutral":
		parts.append("Ton:%s" % tone)

	# Recommended themes (compact)
	var themes := narrative.get_recommended_themes() if narrative else []
	if themes.size() > 0:
		var theme_slice: Array = themes.slice(0, mini(themes.size(), 3))
		var theme_strs: Array[String] = []
		for t in theme_slice:
			theme_strs.append(str(t))
		parts.append("Themes:" + ",".join(theme_strs))

	# JSON template in user prompt (anti-hallucination: model sees template last)
	parts.append("Effets: SHIFT_ASPECT aspect=Corps/Ame/Monde direction=up/down. Option centre cost:1.")
	parts.append("{\"text\":\"...\",\"speaker\":\"merlin\",\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Corps\",\"direction\":\"up\"}]},{\"label\":\"...\",\"cost\":1,\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Ame\",\"direction\":\"up\"}]},{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Monde\",\"direction\":\"down\"}]}],\"tags\":[\"tag\"]}")

	return "\n".join(parts)


func _parse_llm_response(text: String) -> Dictionary:
	## Parse la reponse LLM en carte TRIADE valide.
	# Delegate to adapter's robust extraction if available
	if _store and _store.llm:
		var adapter: MerlinLlmAdapter = _store.llm
		var extracted: Dictionary = adapter._extract_json_from_response(text)
		if extracted.is_empty():
			return {}
		var validated: Dictionary = adapter.validate_triade_card(extracted)
		if validated.get("ok", false):
			return validated.get("card", {})
		return {}

	# Fallback: basic extraction
	var json_start := text.find("{")
	var json_end := text.rfind("}")
	if json_start == -1 or json_end == -1:
		return {}

	var json_text := text.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	# Basic TRIADE validation
	if not parsed.has("text") or not parsed.has("options"):
		return {}
	if typeof(parsed["options"]) != TYPE_ARRAY or parsed["options"].size() < 2:
		return {}

	return parsed

# ═══════════════════════════════════════════════════════════════════════════════
# GUARDRAILS — Language, repetition, length, content safety
# ═══════════════════════════════════════════════════════════════════════════════

func _safe_fallback() -> Dictionary:
	## Get a fallback card, or emergency card if fallback_pool is null.
	if fallback_pool:
		return fallback_pool.get_fallback_card(_current_context)
	return _emergency_card()


func _apply_guardrails(card: Dictionary) -> Dictionary:
	## Apply output guardrails. Returns fallback if card fails checks.
	if card.is_empty():
		return card

	var text: String = str(card.get("text", ""))

	# 1. Length check
	if text.length() < GUARDRAIL_MIN_TEXT_LEN or text.length() > GUARDRAIL_MAX_TEXT_LEN:
		stats.llm_failures += 1
		fallback_used.emit("guardrail_length")
		return _safe_fallback()

	# 2. Language check (must contain French keywords)
	if not _check_french_language(text):
		stats.llm_failures += 1
		fallback_used.emit("guardrail_language")
		return _safe_fallback()

	# 3. Repetition check (reject if too similar to recent cards)
	if _is_repetitive(text):
		stats.llm_failures += 1
		fallback_used.emit("guardrail_repetition")
		return _safe_fallback()

	# 4. JSON conformity (must have valid structure — already checked by parser)
	# 5. Track card text for future repetition checks
	_recent_card_texts.append(text)
	if _recent_card_texts.size() > RECENT_CARDS_MEMORY:
		_recent_card_texts = _recent_card_texts.slice(-RECENT_CARDS_MEMORY)

	return card


func _check_french_language(text: String) -> bool:
	## Verify text contains enough French keywords.
	var lower := text.to_lower()
	var count := 0
	for kw in GUARDRAIL_LANG_KEYWORDS:
		# Check as whole word (space-delimited)
		if lower.contains(" " + kw + " ") or lower.begins_with(kw + " ") or lower.ends_with(" " + kw):
			count += 1
	return count >= GUARDRAIL_LANG_THRESHOLD


func _is_repetitive(text: String) -> bool:
	## Check if text is too similar to recently generated cards.
	var lower := text.to_lower()
	for recent in _recent_card_texts:
		var similarity := _jaccard_similarity(lower, recent.to_lower())
		if similarity >= REPETITION_SIMILARITY_THRESHOLD:
			return true
	return false


func _jaccard_similarity(a: String, b: String) -> float:
	## Word-level Jaccard similarity between two texts.
	var words_a := a.split(" ", false)
	var words_b := b.split(" ", false)
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	var set_a := {}
	for w in words_a:
		set_a[w] = true
	var set_b := {}
	for w in words_b:
		set_b[w] = true
	var intersection := 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION & POST-PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_card(card: Dictionary) -> Dictionary:
	## Valide et sanitize une carte.
	if card.is_empty():
		return _safe_fallback()

	# Validate text
	if typeof(card.get("text", null)) != TYPE_STRING:
		card["text"] = "..."

	# Validate options
	if typeof(card.get("options", null)) != TYPE_ARRAY:
		card["options"] = []

	if card.options.size() < 2:
		return _safe_fallback()

	# Pad to 3 options if LLM only returned 2
	_pad_options_to_three(card)

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


func _pad_options_to_three(card: Dictionary) -> void:
	## Ensure every card has exactly 3 options (left, center, right).
	## If LLM returned only 2, insert a generic center option.
	var opts: Array = card.get("options", [])
	if opts.size() >= 3:
		return

	# Determine card context for thematic center option
	var tags: Array = card.get("tags", [])
	var center_label := "Mediter"
	var center_preview := "+Souffle"
	var center_effects: Array = [{"type": "ADD_SOUFFLE", "amount": 1}]

	if "combat" in tags or "danger" in tags:
		center_label = "Ruser"
		center_preview = "Equilibre"
		center_effects = [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}]
	elif "stranger" in tags or "social" in tags:
		center_label = "Parlementer"
		center_preview = "+Monde"
		center_effects = [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}]
	elif "magic" in tags or "lore" in tags or "mystery" in tags:
		center_label = "Observer"
		center_preview = "+Ame"
		center_effects = [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]

	var center_option := {
		"direction": "center",
		"label": center_label,
		"effects": center_effects,
		"preview": center_preview,
		"cost": 1,
	}

	# Insert center at position 1 (between left and right)
	if opts.size() == 2:
		opts.insert(1, center_option)
	elif opts.size() == 1:
		opts.append(center_option)
		opts.append({"direction": "right", "label": "Continuer", "effects": [], "preview": ""})
	elif opts.size() == 0:
		opts.append({"direction": "left", "label": "Agir", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}], "preview": "+Corps"})
		opts.append(center_option)
		opts.append({"direction": "right", "label": "Continuer", "effects": [], "preview": ""})

	card["options"] = opts


func _post_process_card(card: Dictionary) -> Dictionary:
	## Applique les modifications post-generation.

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
	## Ajoute des elements narratifs contextuels.

	# Check if should trigger foreshadowing
	var features := narrative_scaler.get_features()
	if features.get("foreshadowing", false):
		if randf() < 0.1:  # 10% chance
			var twist_types := ["identity_hidden", "consequence_differee"]
			var twist_type: String = twist_types[randi() % twist_types.size()]
			card["_foreshadowing"] = twist_type

	# Check if should callback NPC
	var callbacks := narrative.get_npcs_for_callback()
	if callbacks.size() > 0 and randf() < 0.2:  # 20% chance
		var npc: Dictionary = callbacks[randi() % callbacks.size()]
		card["npc_callback"] = npc.npc_id
		card["npc_relationship"] = npc.relationship

	return card

# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RECORDING
# ═══════════════════════════════════════════════════════════════════════════════

func record_choice(card: Dictionary, option: int, outcome: Dictionary) -> void:
	## Enregistre un choix et met a jour tous les registres + RAG journal.
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

	# RAG v2.0: Log choice + aspect shifts to game journal
	if rag_manager:
		var day: int = int(context.get("day", 1))
		var cards_played: int = int(_current_context.get("cards_played", 0))
		var options_arr: Array = card.get("options", [])
		if option >= 0 and option < options_arr.size():
			rag_manager.log_choice_made(options_arr[option], cards_played, day)
		# Log aspect shifts from outcome
		var aspects_before: Dictionary = outcome.get("aspects_before", {})
		var aspects_after: Dictionary = outcome.get("aspects_after", {})
		for aspect in aspects_after:
			var old_val: int = int(aspects_before.get(aspect, 0))
			var new_val: int = int(aspects_after[aspect])
			if old_val != new_val:
				rag_manager.log_aspect_shifted(str(aspect), old_val, new_val, cards_played, day)


func on_run_start() -> void:
	## Appele au debut d'une run.
	session.record_run_start()
	decision_history.reset_run()
	narrative.reset_run()


func on_run_end(run_data: Dictionary) -> void:
	## Appele a la fin d'une run.
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

	# RAG v2.0: Archive run summary for cross-run memory
	if rag_manager:
		var ending: String = str(run_data.get("ending", "unknown"))
		rag_manager.summarize_and_archive_run(ending, run_data)

	# Persist all registries + RAG after run end
	save_all()

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN'S VOICE
# ═══════════════════════════════════════════════════════════════════════════════

func get_merlin_comment(context: String) -> String:
	## Genere un commentaire de Merlin adapte au contexte.
	var tone := tone_controller.get_current_tone()
	var trust_tier := relationship.trust_tier

	# Get appropriate comment
	var comment := await _generate_merlin_comment(context, tone)

	merlin_speaks.emit(comment, tone)
	return comment


func _generate_merlin_comment(context: String, tone: String) -> String:
	## Genere un commentaire via pool (ne bloque pas Narrator/GM) ou fallback.
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

	# Use pool-based voice generation (prefers pool worker, falls back to idle primary)
	var result: Dictionary
	if llm_interface.has_method("generate_voice"):
		result = await llm_interface.generate_voice(system, "")
	else:
		result = await llm_interface.generate_with_router(system, "", {"max_tokens": 64})
	if result.has("text"):
		return str(result.text).strip_edges()

	return _get_fallback_comment(context, tone)


func _get_fallback_comment(context: String, tone: String) -> String:
	## Commentaires fallback par ton.
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
	# Narrative twists cause a screen distortion spike
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("narrative_shock"):
		screen_fx.narrative_shock(0.5)


func _on_merlin_speaks_screen_fx(text: String, tone: String) -> void:
	## Sync screen distortion to Merlin's current tone when he speaks.
	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_mood_from_tone"):
		screen_fx.set_mood_from_tone(tone)


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
	var info := {
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
	if rag_manager:
		info["rag_journal_size"] = rag_manager.journal.size()
		info["rag_cross_runs"] = rag_manager.get_run_count()
		info["rag_last_ending"] = rag_manager.get_last_ending()
	return info

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func save_all() -> void:
	## Sauvegarde tous les registres + RAG journal.
	player_profile.save_to_disk()
	decision_history.save_to_disk()
	relationship.save_to_disk()
	narrative.save_to_disk()
	session.save_to_disk()
	if rag_manager:
		rag_manager.save_journal()
		rag_manager.save_world_state()


func reload_registries() -> void:
	## Re-load all registries from disk. Called when loading a save slot.
	player_profile.load_from_disk()
	decision_history.load_from_disk()
	relationship.load_from_disk()
	narrative.load_from_disk()
	session.load_from_disk()
	_sync_mos_to_rag()
	print("[MerlinOmniscient] Registries reloaded from disk")


func _exit_tree() -> void:
	save_all()
