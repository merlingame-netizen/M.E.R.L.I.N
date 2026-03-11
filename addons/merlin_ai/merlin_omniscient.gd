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
signal generation_failed(reason: String)
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
var event_adapter: EventAdapter
var narrative_scaler: NarrativeScaler
var tone_controller: ToneController

# ═══════════════════════════════════════════════════════════════════════════════
# GENERATORS
# ═══════════════════════════════════════════════════════════════════════════════

var llm_interface: Node  # Reference to merlin_ai.gd (autoload, no class_name)
var fast_route: FastRoute
var rag_manager: RAGManager  # RAG v2.0 — priority-based context
var event_selector: EventCategorySelector  # Phase 44 — weighted event picker

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _store: Node = null  # Reference to DruStore
var _is_ready := false
var _quality_judge: BrainQualityJudge = null  # Phase 4 — scoring + best-of-N
var _current_context: Dictionary = {}
var _scene_context: Dictionary = {}
var _generation_in_progress := false
var _last_card_time_ms := 0
var _last_event_selection: Dictionary = {}  # Phase 44 — last selected category

# LLM Configuration
const LLM_TIMEOUT_MS := 300000  # 300s — CPU-only Qwen 3B, generous for cold start
const MAX_RETRIES := 2

# Guardrails
const GUARDRAIL_MIN_TEXT_LEN := 30
const GUARDRAIL_MAX_TEXT_LEN := 800   # LLM with 200 max_tokens can produce up to ~1000 chars
const GUARDRAIL_LANG_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et"]
const GUARDRAIL_LANG_THRESHOLD := 2  # min French keywords to pass
var _recent_card_texts: Array[String] = []
const RECENT_CARDS_MEMORY := 15
const REPETITION_SIMILARITY_THRESHOLD := 0.5

# Persona guardrails — forbidden words loaded from merlin_persona.json via MerlinAI
var _persona_forbidden_words: PackedStringArray = []

# Danger detection thresholds (P1.8.1)
const DANGER_LIFE_CRITICAL := 15     # Mort imminente
const DANGER_LIFE_LOW := 25          # Danger — baisser la difficulte
const DANGER_LIFE_WOUNDED := 50      # Blesse — signaler au LLM
const DANGER_BLOCK_CATASTROPHE_AT := 15  # Bloquer event_catastrophe en-dessous

# Cache
var _response_cache := {}
const CACHE_LIMIT := 300

# Async pre-generation pipeline
var _prefetched_card: Dictionary = {}
var _prefetch_in_progress := false
var _prefetch_context_hash: int = 0  # Hash of game state when prefetch started
var _prefetch_biome: String = ""  # Biome when prefetch started
signal prefetch_ready

# Deep prefetch buffer (Phase 5 — BitNet swarm)
var _prefetch_buffer: Array = []  # Array of {card, context_hash, biome}
const PREFETCH_BUFFER_MAX := 3     # Max pre-generated cards
var _prefetch_depth: int = 1       # Current depth (1 = legacy, 2-3 = swarm)

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
	_quality_judge = BrainQualityJudge.new()


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
	event_adapter = EventAdapter.new()
	event_adapter.setup(difficulty_adapter)
	narrative_scaler = NarrativeScaler.new()
	tone_controller = ToneController.new()


func _init_generators() -> void:
	# Use the autoload MerlinAI — never create a duplicate instance
	llm_interface = get_node_or_null("/root/MerlinAI")
	if llm_interface == null:
		# Autoload may not be ready yet, defer lookup
		call_deferred("_deferred_find_merlin_ai")
	else:
		_sync_persona_forbidden_words()


	# Phase 44 — Event category selector (weighted narrative event picker)
	event_selector = EventCategorySelector.new()
	if event_selector.is_loaded():
		print("[MerlinOmniscient] EventCategorySelector loaded (%d categories)" % event_selector.get_all_categories().size())

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
		_sync_persona_forbidden_words()


func _sync_persona_forbidden_words() -> void:
	if llm_interface and llm_interface.get("_persona_forbidden_words") != null:
		_persona_forbidden_words = llm_interface._persona_forbidden_words.duplicate()
		print("[MerlinOmniscient] Synced %d forbidden words from persona config" % _persona_forbidden_words.size())


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
		# Wait for current generation to finish instead of returning empty
		print("[MOS] generate_card: generation already in progress, waiting...")
		var gen_wait_start := Time.get_ticks_msec()
		while _generation_in_progress and (Time.get_ticks_msec() - gen_wait_start) < 180000:
			await get_tree().create_timer(0.5).timeout
		if _generation_in_progress:
			print("[MOS] generate_card: still busy after 180s, returning empty")
			return {}
		print("[MOS] generate_card: previous generation finished in %dms" % (Time.get_ticks_msec() - gen_wait_start))

	# If prefetch is in progress, wait for it to finish instead of cancelling
	# (cancel_generation + generate_async causes ~80s blocking in C++ backend)
	if _prefetch_in_progress:
		print("[MOS] generate_card: prefetch in progress, waiting for completion...")
		var pfx_wait_start := Time.get_ticks_msec()
		while _prefetch_in_progress and (Time.get_ticks_msec() - pfx_wait_start) < 120000:
			await get_tree().create_timer(0.5).timeout
		if _prefetch_in_progress:
			# Timeout — force cancel as last resort
			print("[MOS] generate_card: prefetch still running after 120s, force cancel")
			_prefetch_in_progress = false
			if llm_interface and llm_interface.has_method("cancel_current_generation"):
				llm_interface.cancel_current_generation()
				await get_tree().create_timer(1.0).timeout
		else:
			print("[MOS] generate_card: prefetch completed in %dms" % (Time.get_ticks_msec() - pfx_wait_start))

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
	_refresh_scene_context()

	# Danger rules: inject danger signals into context BEFORE generation
	_apply_danger_rules(game_state)

	# Scenario system: inject anchor/theme into context
	if _store and _store.has_method("get_scenario_manager"):
		var scenario_mgr = _store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var cards_played: int = int(game_state.get("run", {}).get("cards_played", 0))
			var game_flags: Dictionary = game_state.get("flags", {})
			var anchor: Dictionary = scenario_mgr.get_anchor_for_card(cards_played, game_flags)
			if not anchor.is_empty():
				_current_context["scenario_anchor"] = anchor
				_current_context["force_anchor"] = true
			_current_context["scenario_theme"] = scenario_mgr.get_theme_injection()
			_current_context["scenario_tone"] = scenario_mgr.get_scenario_tone()
			_current_context["scenario_title"] = scenario_mgr.get_scenario_title()
			_current_context["scenario_ambient_tags"] = scenario_mgr.get_ambient_tags()

	# Check if prefetched card is available and relevant
	card = _try_use_prefetch(game_state)
	if not card.is_empty():
		stats.prefetch_hits += 1
	else:
		stats.prefetch_misses += 1

		# Phase 44: Select event category for this card
		_last_event_selection = {}
		if event_selector and event_selector.is_loaded():
			_last_event_selection = event_selector.select_event(game_state)
			if not _last_event_selection.is_empty():
				_current_context["event_category"] = _last_event_selection.get("category", "")
				_current_context["event_sub_type"] = _last_event_selection.get("sub_type", "")
				_current_context["narrator_guidance"] = _last_event_selection.get("narrator_guidance", "")
				_current_context["effect_profile"] = _last_event_selection.get("effect_profile", {})

			# Card modifier selection (card-typology phase)
			var category_str: String = str(_current_context.get("event_category", ""))
			var modifier: Dictionary = event_selector.select_modifier(game_state, category_str)
			if not modifier.is_empty():
				_current_context["card_modifier"] = modifier
				event_selector.record_modifier(str(modifier.get("modifier", "")))
			else:
				event_selector.record_modifier("")

		# Calendar event injection (CAL-REQ-060: ~15% chance)
		var calendar_card := _try_calendar_event(game_state)
		if not calendar_card.is_empty():
			card = calendar_card

		# Sync MOS registries to RAG v2.0 for prioritized retrieval
		if context_builder and narrative:
			_sync_mos_to_rag()

		# Apply adaptive processing
		if difficulty_adapter:
			_apply_adaptive_processing()

		# Determine generation strategy
		card = await _generate_with_strategy()

	# Guardrails: validate language, repetition, length
	print("[MOS] pre-guardrails: card empty=%s text_len=%d opts=%d" % [str(card.is_empty()), str(card.get("text", "")).length(), card.get("options", []).size()])
	card = _apply_guardrails(card)
	print("[MOS] post-guardrails: card empty=%s text_len=%d opts=%d" % [str(card.is_empty()), str(card.get("text", "")).length(), card.get("options", []).size()])

	# Validate and sanitize
	card = _validate_card(card)
	print("[MOS] post-validate: card empty=%s opts=%d" % [str(card.is_empty()), card.get("options", []).size()])

	# Post-process (apply difficulty scaling, etc.)
	if difficulty_adapter:
		card = _post_process_card(card)

	# Tag scenario anchor cards for controller resolution
	if _current_context.get("force_anchor", false) and not card.is_empty():
		var anchor: Dictionary = _current_context.get("scenario_anchor", {})
		card["anchor_id"] = str(anchor.get("anchor_id", ""))
		var card_tags: Array = card.get("tags", [])
		if not card_tags.has("scenario_anchor"):
			card_tags.append("scenario_anchor")
		card["tags"] = card_tags

	# Card-typology: apply modifier to generated card
	if not card.is_empty():
		var card_mod: Dictionary = _current_context.get("card_modifier", {})
		if not card_mod.is_empty():
			card["modifier"] = str(card_mod.get("modifier", ""))
			# Chance modifier: select random minigame
			var mg_pool: Array = card_mod.get("minigame_pool", [])
			if not mg_pool.is_empty():
				var mg_idx: int = randi() % mg_pool.size()
				card["minigame"] = str(mg_pool[mg_idx])
			# Effect modifier: add extra effect
			var eff_mod: Dictionary = card_mod.get("effect_modifier", {})
			var add_eff: String = str(eff_mod.get("add_effect", ""))
			if not add_eff.is_empty():
				var card_tags_m: Array = card.get("tags", [])
				card_tags_m.append("modifier_" + str(card_mod.get("modifier", "")))
				card["tags"] = card_tags_m

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
		var factions: Dictionary = _current_context.get("factions", {})
		var factions_str := "Druides=%d, Anciens=%d, Korrigans=%d" % [
			int(factions.get("druides", 0)),
			int(factions.get("anciens", 0)),
			int(factions.get("korrigans", 0))
		]

		var system_prompt := "Tu es %s, un PNJ celtique. Parle en 1-2 phrases, ton mysterieux. Reponds en francais." % npc_name
		var user_prompt := "Le voyageur te croise en Broceliande. Reputation: %s. Dis une replique immersive." % factions_str

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
					{"label": "Ecouter", "effects": [
						{"type": "ADD_REPUTATION", "faction": "druides", "amount": 3}
					], "preview": "+Druides"},
					{"label": "Continuer", "effects": [
						{"type": "ADD_KARMA", "amount": 2}
					], "preview": "+Karma"},
				],
				"tags": ["npc", "llm_generated"],
				"source": "llm",
			}

	# LLM failed — return empty, controller will retry
	return {}


func _try_calendar_event(game_state: Dictionary) -> Dictionary:
	## Check if a calendar event should be injected as the next card.
	## Returns a TRIADE-format card, or empty dict if no event fires.
	if event_adapter == null:
		return {}

	var run: Dictionary = game_state.get("run", {})
	var cards_played: int = int(run.get("cards_played", 0))

	# Don't inject events in the first few cards
	if cards_played < MerlinConstants.MIN_CARDS_BEFORE_EVENT:
		return {}

	# Roll for event probability (~15%)
	var prob: float = MerlinConstants.EVENT_CARD_PROBABILITY
	# Boost near sabbats (date proximity already handled by EventAdapter weights)
	if randf() > prob:
		return {}

	# Build context for EventAdapter
	var ctx := _build_event_context(game_state)

	# Ask EventAdapter for best event
	var selected: Dictionary = event_adapter.select_event_for_card(ctx)
	if selected.is_empty():
		return {}

	# Record event seen
	var ev_id: String = str(selected.get("id", ""))
	event_adapter.record_event(ev_id)
	var events_seen: Array = run.get("events_seen", [])
	events_seen.append(ev_id)
	run["events_seen"] = events_seen

	print("[MOS] Calendar event injected: %s" % ev_id)

	# Convert to card format
	return _calendar_event_to_card(selected)


func _build_event_context(game_state: Dictionary) -> Dictionary:
	## Build the context dictionary that EventAdapter needs for condition checks.
	var run: Dictionary = game_state.get("run", {})
	var meta: Dictionary = game_state.get("meta", {})
	var hidden: Dictionary = run.get("hidden", {})

	return {
		"factions": run.get("factions", {}),
		"cards_played": int(run.get("cards_played", 0)),
		"total_runs": int(meta.get("total_runs", 0)),
		"karma": int(hidden.get("karma", 0)),
		"tension": int(hidden.get("tension", 0)),
		"flags": game_state.get("flags", {}),
		"bestiole_bond": int(game_state.get("bestiole", {}).get("bond", 0)),
		"trust_merlin": relationship.trust_points if relationship else 0,
		"endings_seen_count": int(meta.get("endings_seen", []).size()),
		"calendrier_des_brumes": meta.get("talent_tree", {}).get("unlocked", []).has("calendrier_des_brumes"),
		"life_essence": int(run.get("life_essence", 100)),
	}


func _calendar_event_to_card(ev: Dictionary) -> Dictionary:
	## Convert a calendar event from JSON to card format (variable options).
	var ev_id: String = str(ev.get("id", ""))
	var text: String = str(ev.get("text", ""))
	var effects: Array = ev.get("effects", [])
	var visual: Dictionary = ev.get("visual", {})
	var tags: Array = ev.get("tags", [])
	var category: String = str(ev.get("category", ""))

	# Build options: Accept / Observe
	# Left: primary effects from event
	# Right: cautious observation (minor karma)
	var left_effects: Array = effects.duplicate()
	var center_effects: Array = []
	if effects.size() > 0:
		center_effects.append(effects[0].duplicate())
	var right_effects: Array = [{"type": "ADD_KARMA", "amount": 3}]

	# Adjust labels based on category
	var left_label := "Accueillir l'evenement"
	var center_label := "Mediter sur son sens"
	var right_label := "Observer de loin"

	if category == "sabbat":
		left_label = "Participer au rituel"
		center_label = "Communier avec les esprits"
		right_label = "Observer la ceremonie"
	elif category == "transition":
		left_label = "Embrasser le changement"
		center_label = "S'adapter en douceur"
		right_label = "Resister au passage"
	elif category == "secret":
		left_label = "Plonger dans le mystere"
		center_label = "Dechiffrer les signes"
		right_label = "Garder ses distances"

	return {
		"id": "cal_%s_%d" % [ev_id, Time.get_ticks_msec()],
		"text": text,
		"speaker": "Merlin",
		"type": "event",
		"calendar_event_id": ev_id,
		"options": [
			{
				"direction": "left",
				"label": left_label,
				"effects": left_effects,
				"preview": ev.get("name", ""),
			},
			{
				"direction": "center",
				"label": center_label,
				"effects": center_effects,
				"preview": "+Ogham",
			},
			{
				"direction": "right",
				"label": right_label,
				"effects": right_effects,
				"preview": "+Karma",
			},
		],
		"tags": tags + ["calendar_event", category],
		"visual_theme": str(visual.get("theme", "")),
	}



func prefetch_next_card(game_state: Dictionary) -> void:
	## Pre-generate the next card(s) in background while player reads current card.
	## Deep prefetch: with BitNet swarm, generates up to _prefetch_depth cards.
	## Called by the controller after displaying a card.
	if _prefetch_in_progress or _generation_in_progress:
		return
	if llm_interface == null or not llm_interface.is_ready:
		return

	_prefetch_in_progress = true
	_prefetch_context_hash = _compute_context_hash(game_state)
	_prefetched_card = {}
	var run: Dictionary = game_state.get("run", {})
	_prefetch_biome = str(run.get("current_biome", ""))

	# Build context for next card (simulate state after a neutral choice)
	var prefetch_context := context_builder.build_full_context(game_state)
	_current_context = prefetch_context
	_refresh_scene_context()

	# Sync and process
	_sync_mos_to_rag()
	_apply_adaptive_processing()

	# Generate card N+1 (always)
	var card := await _generate_with_strategy()

	if _prefetch_in_progress:
		_prefetched_card = card
		# Deep prefetch: fill buffer with cards N+2, N+3 (if swarm active)
		if _prefetch_depth > 1 and not card.is_empty():
			_prefetch_buffer.clear()
			_prefetch_buffer.append({
				"card": card,
				"context_hash": _prefetch_context_hash,
				"biome": _prefetch_biome,
			})
			# Generate additional cards via background tasks (non-blocking)
			var extra: int = mini(_prefetch_depth - 1, PREFETCH_BUFFER_MAX - 1)
			for i in range(extra):
				_submit_deep_prefetch(game_state, i + 2)
		_prefetch_in_progress = false
		prefetch_ready.emit()


func _submit_deep_prefetch(game_state: Dictionary, card_index: int) -> void:
	## Submit a deep prefetch card generation as a background task.
	if llm_interface == null or not llm_interface.has_method("submit_background_task"):
		return
	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()
	# Slight temperature variation for diversity
	var temp: float = 0.55 + card_index * 0.08
	var biome: String = _prefetch_biome

	llm_interface.submit_background_task("prefetch", system_prompt, user_prompt,
		{"max_tokens": 200, "temperature": temp},
		func(result: Dictionary) -> void:
			if result.has("text"):
				var parsed := _parse_llm_response(str(result.text))
				if not parsed.is_empty():
					parsed["_prefetched"] = true
					parsed["_deep_index"] = card_index
					if _prefetch_buffer.size() < PREFETCH_BUFFER_MAX:
						_prefetch_buffer.append({
							"card": parsed,
							"context_hash": _prefetch_context_hash,
							"biome": biome,
						})
					print("[MOS] Deep prefetch card %d buffered (buffer=%d)" % [card_index, _prefetch_buffer.size()])
	)


func _try_use_prefetch(game_state: Dictionary) -> Dictionary:
	## Check if prefetched card is available and relevant to current state.
	## Uses biome + context hash matching for prefetch validation.
	## Phase 5: Also checks deep prefetch buffer.

	# Try primary prefetch first
	if not _prefetched_card.is_empty():
		var card := _prefetched_card
		_prefetched_card = {}
		if _is_prefetch_valid(game_state, _prefetch_context_hash, _prefetch_biome):
			# Promote next buffer entry to primary slot
			if not _prefetch_buffer.is_empty():
				var next: Dictionary = _prefetch_buffer.pop_front()
				_prefetched_card = next.get("card", {})
			stats.prefetch_hits += 1
			return card

	# Try deep buffer entries
	for i in range(_prefetch_buffer.size()):
		var entry: Dictionary = _prefetch_buffer[i]
		var buf_hash: int = int(entry.get("context_hash", 0))
		var buf_biome: String = str(entry.get("biome", ""))
		if _is_prefetch_valid(game_state, buf_hash, buf_biome):
			var card: Dictionary = entry.get("card", {})
			_prefetch_buffer.remove_at(i)
			stats.prefetch_hits += 1
			return card

	return {}


func _is_prefetch_valid(game_state: Dictionary, context_hash: int, prefetch_biome: String) -> bool:
	## Validate a prefetched card against current game state.
	var current_hash := _compute_context_hash(game_state)
	if current_hash == context_hash:
		return true
	var run: Dictionary = game_state.get("run", {})
	var current_biome: String = str(run.get("current_biome", ""))
	return current_biome == prefetch_biome


func try_consume_prefetch(game_state: Dictionary) -> Dictionary:
	## Public entry point for controller fast-path prefetch consumption.
	var card := _try_use_prefetch(game_state)
	if card.is_empty() and not _prefetched_card.is_empty():
		stats.prefetch_misses += 1
	return card


func _compute_context_hash(game_state: Dictionary) -> int:
	## Compute a hash of the game state for prefetch validation.
	## Includes factions, cards_played and life_essence to detect state changes.
	var run: Dictionary = game_state.get("run", {})
	var factions: Dictionary = run.get("factions", {})
	var hash_val: int = 0
	for faction in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		hash_val = hash_val * 7 + int(factions.get(faction, 0)) + 2
	hash_val = hash_val * 17 + int(run.get("cards_played", 0))
	hash_val = hash_val * 23 + int(run.get("life_essence", 100))
	return hash_val


func invalidate_prefetch() -> void:
	## Cancel any ongoing prefetch (e.g., when game state changes significantly).
	_prefetched_card = {}
	_prefetch_buffer.clear()
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
	## LLM generation — zero fallback policy.
	## Returns empty dict on failure. Controller handles retry + UI overlay.

	# Ensure LLM warmup is triggered if not ready
	if llm_interface != null and not llm_interface.is_ready:
		print("[MOS] LLM not ready, triggering ensure_ready()")
		if llm_interface.has_method("ensure_ready"):
			llm_interface.ensure_ready()
		# Wait up to 20s for warmup to complete
		var wait_start := Time.get_ticks_msec()
		while llm_interface != null and not llm_interface.is_ready:
			if Time.get_ticks_msec() - wait_start > 20000:
				print("[MOS] LLM warmup timeout after 20s")
				break
			await get_tree().create_timer(0.5).timeout
		if llm_interface != null and llm_interface.is_ready:
			print("[MOS] LLM became ready after %dms" % (Time.get_ticks_msec() - wait_start))

	if llm_interface != null and llm_interface.is_ready:
		var llm_card := await _try_llm_generation()
		if not llm_card.is_empty():
			stats.llm_successes += 1
			# P3.17.1: Generate poetic title (non-blocking, use fallback if slow)
			llm_card["title"] = await _generate_card_title(llm_card)
			return llm_card
		else:
			stats.llm_failures += 1

	# Zero fallback: signal failure, let controller retry with backoff
	generation_failed.emit("llm_unavailable")
	return {}


# Zero fallback policy: _get_emergency_fallback_card() removed.
# All cards must be LLM-generated. Controller handles retry + UI overlay.


func _try_llm_generation() -> Dictionary:
	## Tente de generer via LLM avec retries.
	## Phase 32: Priorite au pipeline parallele (Narrator + Game Master)

	if llm_interface == null or not llm_interface.is_ready:
		print("[MOS] _try_llm_generation: llm_interface null or not ready (is_ready=%s)" % str(llm_interface.is_ready if llm_interface else "null"))
		return {}
	_refresh_scene_context()

	var start_time := Time.get_ticks_msec()

	# Switch LoRA adapter to match current tone (covers all strategies)
	if llm_interface.has_method("set_narrator_tone") and tone_controller:
		llm_interface.set_narrator_tone(tone_controller.get_current_tone())

	# Strategy S: Swarm pipeline (BitNet) — Narrator generates, Judge scores, best-of-N
	if llm_interface.active_backend == 2 and _quality_judge != null:  # BackendType.BITNET = 2
		var swarm_card := await _try_swarm_generation()
		if not swarm_card.is_empty():
			swarm_card["_strategy"] = "swarm"
			print("[MOS] Strategy S (swarm): SUCCESS in %dms (score=%.2f)" % [
				Time.get_ticks_msec() - start_time,
				float(swarm_card.get("_quality_score", 0.0))
			])
			return swarm_card
		print("[MOS] Strategy S: failed, falling through to B/C")

	# Strategy B: Use MerlinLlmAdapter if available (single-instance)
	if _store and _store.llm and _store.llm.is_llm_ready():
		var adapter: MerlinLlmAdapter = _store.llm
		var ctx: Dictionary = _current_context.duplicate()
		if not _scene_context.is_empty():
			ctx["scene_context"] = _scene_context
		print("[MOS] Strategy B: starting adapter.generate_card()...")
		var adapter_result: Dictionary = await adapter.generate_card(ctx)
		var b_elapsed := Time.get_ticks_msec() - start_time
		if adapter_result.get("ok", false):
			var card: Dictionary = adapter_result.get("card", {})
			card["_strategy"] = "adapter"
			card["_generation_time_ms"] = b_elapsed
			print("[MOS] Strategy B: SUCCESS in %dms" % b_elapsed)
			return card
		else:
			print("[MOS] Strategy B: FAILED in %dms — %s" % [b_elapsed, str(adapter_result.get("error", "unknown"))])

	# Strategy SEQ: Sequential pipeline (P1.5) — narrator(card_full) → parse → gm(effects)
	if llm_interface.has_method("generate_sequential") and not llm_interface.prompt_templates.get("sequential_card_full", {}).is_empty():
		var seq_card := await _try_sequential_generation()
		if not seq_card.is_empty():
			seq_card["_strategy"] = "sequential"
			print("[MOS] Strategy SEQ: SUCCESS in %dms" % (Time.get_ticks_msec() - start_time))
			return seq_card
		print("[MOS] Strategy SEQ: failed, falling through to C")

	# Strategy C: Direct LLM call (fallback)
	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()

	for attempt in range(MAX_RETRIES):
		var c_start := Time.get_ticks_msec()
		print("[MOS] Strategy C attempt %d/%d starting..." % [attempt + 1, MAX_RETRIES])
		var result: Dictionary = await llm_interface.generate_with_system(
			system_prompt,
			user_prompt,
			{"max_tokens": 200, "temperature": _get_temperature_for_context()}
		)
		var c_elapsed := Time.get_ticks_msec() - c_start

		if result.has("error"):
			print("[MOS] Strategy C attempt %d: error in %dms — %s" % [attempt + 1, c_elapsed, str(result.get("error", ""))])
			continue

		var text: String = result.get("text", "")
		print("[MOS] Strategy C attempt %d: got %d chars in %dms" % [attempt + 1, text.length(), c_elapsed])
		var parsed := _parse_llm_response(text)

		if not parsed.is_empty():
			parsed["_strategy"] = "direct_c"
			parsed["_generation_time_ms"] = Time.get_ticks_msec() - start_time
			print("[MOS] Strategy C: SUCCESS (total %dms)" % (Time.get_ticks_msec() - start_time))
			return parsed
		else:
			print("[MOS] Strategy C attempt %d: parse failed (text=%s...)" % [attempt + 1, text.substr(0, 80)])

	print("[MOS] ALL strategies FAILED (total %dms)" % (Time.get_ticks_msec() - start_time))
	return {}


func _try_swarm_generation() -> Dictionary:
	## Strategy S: BitNet swarm pipeline.
	## 1. Narrator brain generates N=2 variants
	## 2. Quality Judge scores both and picks the best
	## 3. If score < threshold, request refinement via a second pass
	## 4. Parse the winning text into a card

	var system_prompt := _build_system_prompt()
	var user_prompt := _build_user_prompt()
	var n_variants: int = BrainQualityJudge.BEST_OF_N_DEFAULT

	# ── Step 1: Generate N variants via narrator ──────────────────────────
	var candidates: Array = []
	for i in range(n_variants):
		var result: Dictionary = await llm_interface.generate_with_system(
			system_prompt,
			user_prompt,
			{"max_tokens": 200, "temperature": _get_temperature_for_context() + i * 0.1}  # Phase-based + variation
		)
		if result.has("text") and result.text.strip_edges().length() > 10:
			candidates.append(result.text)
		else:
			print("[MOS] Swarm variant %d: failed (%s)" % [i + 1, str(result.get("error", "empty"))])

	if candidates.is_empty():
		print("[MOS] Swarm: no valid candidates generated")
		return {}

	# ── Step 2: Judge picks the best ──────────────────────────────────────
	var best: Dictionary = _quality_judge.pick_best(candidates)
	var best_text: String = best.get("text", "")
	var best_score: float = best.get("score", 0.0)
	print("[MOS] Swarm: %d candidates, best score=%.2f (idx=%d)" % [candidates.size(), best_score, best.get("index", 0)])

	# ── Step 3: Refinement if score is low ────────────────────────────────
	if best_score < BrainQualityJudge.GOOD_SCORE and best_score >= BrainQualityJudge.MIN_ACCEPTABLE_SCORE:
		var refinement_prompt: String = _quality_judge.suggest_refinement(best_text, best.get("detail", {}))
		if refinement_prompt != "":
			print("[MOS] Swarm: requesting refinement (score %.2f < %.2f)" % [best_score, BrainQualityJudge.GOOD_SCORE])
			var refined: Dictionary = await llm_interface.generate_with_system(
				system_prompt,
				refinement_prompt,
				{"max_tokens": 200, "temperature": _get_temperature_for_context()}
			)
			if refined.has("text"):
				var refined_score: Dictionary = _quality_judge.score_text(refined.text)
				if refined_score.total > best_score:
					best_text = refined.text
					best_score = refined_score.total
					print("[MOS] Swarm: refinement improved score to %.2f" % best_score)
				else:
					print("[MOS] Swarm: refinement did not improve (%.2f vs %.2f)" % [refined_score.total, best_score])

	# ── Step 4: Reject if still too low ───────────────────────────────────
	if best_score < BrainQualityJudge.MIN_ACCEPTABLE_SCORE:
		print("[MOS] Swarm: best score %.2f below minimum %.2f — rejecting" % [best_score, BrainQualityJudge.MIN_ACCEPTABLE_SCORE])
		return {}

	# ── Step 5: Parse into card ───────────────────────────────────────────
	var parsed := _parse_llm_response(best_text)
	if parsed.is_empty():
		print("[MOS] Swarm: parse failed for winning text (%.0f chars)" % best_text.length())
		return {}

	# Register with judge for future repetition detection
	_quality_judge.register_text(best_text)
	parsed["_quality_score"] = best_score
	return parsed


func _try_sequential_generation() -> Dictionary:
	## Strategy SEQ: Sequential pipeline (P1.5).
	## narrator(card_full) → parse(labels) → gm(effects) → assemble card.
	## Builds context dict from _current_context for template variable filling.

	# Map _current_context to template variables
	var factions: Dictionary = _current_context.get("factions", {})
	var ogham_actif: String = str(_current_context.get("ogham_actif", ""))

	var life_val: int = int(_current_context.get("life_essence", 100))
	var danger_level: int = int(_current_context.get("danger_level", 0))

	# Narrative phase name
	var phase_text := ""
	if narrative:
		var phase_names: Dictionary = {1: "Mise en place", 2: "Montee dramatique", 3: "Climax", 4: "Resolution"}
		phase_text = "Phase: %s. " % phase_names.get(narrative.run_phase, "Mise en place")

	# Danger context string
	var danger_text := ""
	var danger_signals: Array = _current_context.get("danger_signals", [])
	if danger_signals.size() > 0:
		danger_text = "[DANGER] %s. " % " | ".join(danger_signals)

	# Player summary
	var player_text := ""
	if player_profile:
		var summary: String = player_profile.get_summary_for_prompt()
		if not summary.is_empty():
			player_text = summary + " "

	# Narrator guidance from event selector
	var guidance_text: String = str(_current_context.get("narrator_guidance", ""))
	if not guidance_text.is_empty():
		guidance_text = guidance_text + " "

	# Biome
	var biome: String = str(_current_context.get("biome", "foret"))

	var seq_context: Dictionary = {
		"biome": biome,
		"day": _current_context.get("day", 1),
		"ogham_actif": ogham_actif,
		"factions": factions,
		"life": life_val,
		"narrative_phase": phase_text,
		"danger_context": danger_text,
		"player_summary": player_text,
		"narrator_guidance": guidance_text,
		"danger_level": danger_level,
		"temperature": _get_temperature_for_context(),
	}

	var card: Dictionary = await llm_interface.generate_sequential(seq_context)

	if card.has("error"):
		print("[MOS] Strategy SEQ: error — %s" % str(card.error))
		return {}

	# Validate minimum card structure
	var card_text: String = str(card.get("text", ""))
	var card_options: Array = card.get("options", [])
	if card_text.length() < 10 or card_options.size() < 3:
		print("[MOS] Strategy SEQ: invalid card (text=%d chars, options=%d)" % [card_text.length(), card_options.size()])
		return {}

	# Register with quality judge for repetition tracking
	if _quality_judge:
		_quality_judge.register_text(card_text)

	return card


func _build_narrator_prompt() -> String:
	## System prompt for the Narrator instance — creative, poetic, Celtic.
	## Phase 44: Use category-specific template from scenario_prompts.json if available.
	var base := ""

	# Try category-specific prompt from scenario_prompts.json
	var category: String = str(_current_context.get("event_category", ""))
	if not category.is_empty() and _store and _store.llm:
		var adapter: MerlinLlmAdapter = _store.llm
		var cat_prompt := adapter.build_category_system_prompt(category)
		if not cat_prompt.is_empty():
			base = cat_prompt

	if base.is_empty():
		base = "Tu es Merlin l'Enchanteur, druide ancestral des forets de Broceliande. Ecris un scenario immersif (2-3 phrases) pour un jeu de cartes celtique. Propose 3 choix: A) prudent B) mystique C) audacieux. Adapte ton registre: poetique face a la nature, grave quand tu avertis, espiegle quand tu taquines. Vocabulaire: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, pierre dressee. Ecris en francais."
	_refresh_scene_context()
	var scene_block := _build_scene_contract_block()
	if not scene_block.is_empty():
		base += "\n" + scene_block

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

	# Past lives for cross-run continuity (P3.20.2)
	if rag_manager and rag_manager.has_method("get_past_lives_for_prompt"):
		var past_lives: String = rag_manager.get_past_lives_for_prompt()
		if not past_lives.is_empty():
			base += "\n" + past_lives

	# Scenario theme injection (ambient context for all cards in a scenario run)
	var scenario_theme: String = str(_current_context.get("scenario_theme", ""))
	if not scenario_theme.is_empty():
		base += "\nCONTEXTE SCENARIO: " + scenario_theme

	return base


func _build_narrator_input() -> String:
	## User prompt for Narrator — game state in natural language.
	## If a scenario anchor is active, its prompt_override takes priority.
	var factions: Dictionary = _current_context.get("factions", {})
	var ogham: String = str(_current_context.get("ogham_actif", ""))
	var parts: Array[String] = []

	if ogham != "":
		parts.append("Ogham actif: %s." % ogham)

	var faction_parts: Array[String] = []
	for faction in factions:
		var val: int = int(factions[faction])
		if val > 0:
			faction_parts.append("%s=%d" % [faction, val])
	if faction_parts.size() > 0:
		parts.append("Réputation: %s." % ", ".join(faction_parts))

	parts.append("Jour %d." % _current_context.get("day", 1))

	var biome: String = str(_current_context.get("biome", "foret"))
	parts.append("Biome: %s." % biome)
	if not _scene_context.is_empty():
		var scene_id := str(_scene_context.get("scene_id", ""))
		var phase := str(_scene_context.get("phase", ""))
		if scene_id != "":
			parts.append("Scene: %s." % scene_id)
		if phase != "":
			parts.append("Phase: %s." % phase)

	# Tone hint (scenario tone overrides if present)
	var scenario_tone: String = str(_current_context.get("scenario_tone", ""))
	var tone: String = scenario_tone if not scenario_tone.is_empty() else (tone_controller.get_current_tone() if tone_controller else "neutral")
	if tone != "neutral" and not tone.is_empty():
		parts.append("Ton: %s." % tone)

	# Themes
	var themes := narrative.get_recommended_themes() if narrative else []
	if themes.size() > 0:
		var theme_strs: Array[String] = []
		for t in themes.slice(0, mini(themes.size(), 2)):
			theme_strs.append(str(t))
		parts.append("Themes: %s." % ", ".join(theme_strs))

	# Scenario anchor: prepend prompt_override for anchor cards
	if _current_context.get("force_anchor", false):
		var anchor: Dictionary = _current_context.get("scenario_anchor", {})
		var prompt_override: String = str(anchor.get("prompt_override", ""))
		if not prompt_override.is_empty():
			parts.insert(0, "CARTE-ANCRE DE SCENARIO: " + prompt_override)
			var must_refs: Array = anchor.get("must_reference", [])
			if not must_refs.is_empty():
				var refs_str: Array[String] = []
				for r in must_refs:
					refs_str.append(str(r))
				parts.append("References obligatoires: %s." % ", ".join(refs_str))

	# Card modifier injection (card-typology phase)
	var card_modifier: Dictionary = _current_context.get("card_modifier", {})
	if not card_modifier.is_empty():
		var injection: String = str(card_modifier.get("prompt_injection", ""))
		if not injection.is_empty():
			parts.append("MODIFICATEUR: " + injection)

	parts.append("Ecris le scenario puis les 3 choix (A/B/C).")
	return " ".join(parts)


func _build_gm_prompt() -> String:
	## System prompt for Game Master — logic, effects, balance.
	_refresh_scene_context()
	var base := "Tu es le Maitre du Jeu. Genere les effets mecaniques pour les options de carte. Reponds UNIQUEMENT en JSON valide. Effets: ADD_REPUTATION (faction=druides/anciens/korrigans/niamh/ankou, amount), ADD_KARMA (amount), ADD_TENSION (amount), UNLOCK_OGHAM (ogham_name)."
	var scene_block := _build_scene_contract_block()
	if not scene_block.is_empty():
		base += "\n" + scene_block + "\nNe genere aucun effet hors contrat de scene."

	# Card-typology: inject effect_profile constraints from category
	var effect_profile: Dictionary = _current_context.get("effect_profile", {})
	if not effect_profile.is_empty():
		var primary: String = str(effect_profile.get("primary", ""))
		var intensity: String = str(effect_profile.get("intensity", "medium"))
		var secondary: Array = effect_profile.get("secondary", [])
		if not primary.is_empty():
			var sec_str: Array[String] = []
			for s in secondary:
				sec_str.append(str(s))
			base += "\nCategorie: %s. Effet primaire: %s. Secondaires: %s. Intensite: %s." % [
				str(_current_context.get("event_category", "")),
				primary,
				", ".join(sec_str) if not sec_str.is_empty() else "aucun",
				intensity
			]

	return base


func _build_gm_input() -> String:
	## User prompt for Game Master — structured game state.
	var factions: Dictionary = _current_context.get("factions", {})
	var parts: Array[String] = []

	for faction in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		parts.append("%s=%d" % [faction, int(factions.get(faction, 0))])

	parts.append("Jour=%d" % int(_current_context.get("day", 1)))
	parts.append("Carte=%d" % int(_current_context.get("cards_played", 0)))
	if not _scene_context.is_empty():
		var scene_id := str(_scene_context.get("scene_id", ""))
		var phase := str(_scene_context.get("phase", ""))
		if scene_id != "":
			parts.append("Scene=%s" % scene_id)
		if phase != "":
			parts.append("Phase=%s" % phase)

	# Template to guide output format
	parts.append("\n{\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"ADD_REPUTATION\",\"faction\":\"druides\",\"amount\":5}]},{\"label\":\"...\",\"effects\":[{\"type\":\"ADD_KARMA\",\"amount\":3}]}]}")

	return " ".join(parts)


func _get_live_scene_context() -> Dictionary:
	if llm_interface and llm_interface.has_method("get_scene_context"):
		var ctx = llm_interface.get_scene_context()
		if ctx is Dictionary:
			return ctx.duplicate(true)
	return {}


var _scene_context_version: int = -1

func _refresh_scene_context() -> void:
	# Deduplicated: skip refresh if scene context hasn't changed since last call
	if llm_interface and llm_interface.has_method("get_scene_context_version"):
		var new_version: int = llm_interface.get_scene_context_version()
		if new_version == _scene_context_version and not _scene_context.is_empty():
			return  # Cache hit — skip redundant refresh
		_scene_context_version = new_version
	_scene_context = _get_live_scene_context()
	if _scene_context.is_empty():
		_current_context.erase("scene_context")
	else:
		_current_context["scene_context"] = _scene_context


func _scene_list_to_strings(value) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "":
				out.append(text)
	return out


func _build_scene_contract_block() -> String:
	if _scene_context.is_empty():
		return ""
	var parts: Array[String] = []
	var scene_id := str(_scene_context.get("scene_id", ""))
	if scene_id != "":
		parts.append("Scene=%s" % scene_id)
	var phase := str(_scene_context.get("phase", ""))
	if phase != "":
		parts.append("Phase=%s" % phase)
	var intent := str(_scene_context.get("intent", ""))
	if intent != "":
		parts.append("Intent=%s" % intent)
	var tone := str(_scene_context.get("tone_target", ""))
	if tone != "":
		parts.append("Tone=%s" % tone)
	var must_ref := _scene_list_to_strings(_scene_context.get("must_reference", []))
	if not must_ref.is_empty():
		parts.append("Must=%s" % ", ".join(must_ref.slice(0, mini(must_ref.size(), 4))))
	var forbidden := _scene_list_to_strings(_scene_context.get("forbidden_topics", []))
	if not forbidden.is_empty():
		parts.append("Forbidden=%s" % ", ".join(forbidden.slice(0, mini(forbidden.size(), 4))))
	if parts.is_empty():
		return ""
	return "[CONTRAT_SCENE] " + " | ".join(parts)


func _get_temperature_for_context() -> float:
	## Temperature dynamique basee sur run_phase et danger_level.
	## SETUP=calme, RISING=creatif, CLIMAX=intense, RESOLUTION=apaise.
	var base_temp := 0.6
	if narrative:
		# ArcPhase: SETUP=1, RISING=2, CLIMAX=3, RESOLUTION=4
		match narrative.run_phase:
			1:  # SETUP
				base_temp = 0.55  # Etablir le monde, modere
			2:  # RISING
				base_temp = 0.7   # Montee dramatique, plus creatif
			3:  # CLIMAX
				base_temp = 0.75  # Climax, maximum de creativite
			4:  # RESOLUTION
				base_temp = 0.5   # Resolution, calme et coherent

	# Override danger (toujours prioritaire)
	var danger_override: float = float(_current_context.get("temperature_override", 0.0))
	if danger_override > 0.0:
		return danger_override

	return base_temp


func _apply_danger_rules(game_state: Dictionary) -> void:
	## 5 regles danger pre-LLM: injecte des signaux dans _current_context
	## pour que le LLM adapte le ton et la difficulte de la carte.
	var run: Dictionary = game_state.get("run", {})
	var life: int = int(run.get("life_essence", 100))
	var danger_signals: Array[String] = []
	var danger_level := 0  # 0=safe, 1=wounded, 2=low, 3=critical

	# REGLE 1: Vie critique (<= 15) — mort imminente
	if life <= DANGER_LIFE_CRITICAL:
		danger_level = 3
		danger_signals.append("VIE CRITIQUE (%d) — genere une situation de SURVIE, pas de degats supplementaires" % life)

	# REGLE 2: Vie basse (<= 25) — danger, favoriser repos/soin
	elif life <= DANGER_LIFE_LOW:
		danger_level = 2
		danger_signals.append("VIE BASSE (%d) — favorise options de soin ou repos" % life)

	# REGLE 3: Blesse (<= 50) — signaler au LLM
	elif life <= DANGER_LIFE_WOUNDED:
		danger_level = 1
		danger_signals.append("Joueur blesse (%d vie)" % life)

	# REGLE 4: Bloquer event_catastrophe + forcer template danger si vie < seuil
	if life < DANGER_BLOCK_CATASTROPHE_AT:
		var event_cat: String = str(_current_context.get("event_category", ""))
		if event_cat == "event_catastrophe" or event_cat == "event_conflit":
			_current_context["event_category"] = "event_agonie"
			_current_context["narrator_guidance"] = "Le voyageur est entre la vie et la mort. Scene onirique de grace."
			danger_signals.append("event redirige vers event_agonie (vie=%d)" % life)
	elif life <= DANGER_LIFE_LOW:
		var event_cat: String = str(_current_context.get("event_category", ""))
		if event_cat == "event_catastrophe":
			_current_context["event_category"] = "event_survie"
			_current_context["narrator_guidance"] = "Le voyageur est affaibli. Scene de survie protectrice."
			danger_signals.append("event_catastrophe redirige vers event_survie (vie=%d)" % life)

	# Injecter dans le contexte
	if danger_signals.size() > 0:
		_current_context["danger_signals"] = danger_signals
		_current_context["danger_level"] = danger_level

		# Temperature adjustment: higher danger → lower creativity (safer cards)
		if danger_level >= 2:
			_current_context["temperature_override"] = 0.4
		elif danger_level >= 1:
			_current_context["temperature_override"] = 0.5


func _sync_mos_to_rag() -> void:
	## Sync MOS registries into RAG v2.0 world state for priority-based retrieval.
	if rag_manager == null:
		return
	_refresh_scene_context()
	var registry_data := {}
	if player_profile:
		var patterns: Dictionary = decision_history.patterns_detected if decision_history else {}
		var player_patterns := {}
		for p_name in patterns:
			var p_data = patterns[p_name]
			if p_data is Dictionary:
				player_patterns[str(p_name)] = p_data
		registry_data["player_patterns"] = player_patterns
		# P1.10.1: Sync player profile summary for RAG context
		registry_data["player_profile_summary"] = player_profile.get_summary_for_prompt()
		# B.3: Sync archetype for RAG context injection
		registry_data["archetype_id"] = player_profile.get_archetype_id()
		registry_data["archetype_title"] = player_profile.get_archetype_title()
	if narrative:
		var ctx: Dictionary = narrative.get_context_for_llm()
		registry_data["active_arcs"] = ctx.get("active_arcs", [])
		registry_data["run_phase_name"] = ctx.get("run_phase_name", "")
	if relationship:
		registry_data["trust_tier"] = relationship.trust_tier
		registry_data["trust_tier_name"] = relationship.get_trust_tier_name()
	if session:
		registry_data["session_frustration"] = session.current.get("seems_frustrated", false) if session.current is Dictionary else false
	# Sync current tone for RAG tone context section
	if tone_controller:
		registry_data["current_tone"] = tone_controller.get_current_tone()
		registry_data["tone_characteristics"] = tone_controller.get_tone_characteristics()
	if not _scene_context.is_empty():
		registry_data["scene_context"] = _scene_context
	rag_manager.sync_from_registries(registry_data)


func _build_system_prompt() -> String:
	## Enriched system prompt for Qwen 2.5-3B-Instruct.
	## JSON template moved to user prompt to reduce hallucination.
	## RAG context + tone guidance injected via priority budget.
	var base := "Narrateur celtique de Broceliande. Ecris une scene courte (2-3 phrases) avec vocabulaire druidique (nemeton, ogham, sidhe, dolmen, korrigans). Puis donne EXACTEMENT 3 choix:\nA) [verbe action]\nB) [verbe action]\nC) [verbe action]"
	# Inject language directive from LocaleManager
	var locale_mgr = Engine.get_singleton("LocaleManager") if Engine.has_singleton("LocaleManager") else null
	if locale_mgr == null:
		locale_mgr = get_node_or_null("/root/LocaleManager")
	if locale_mgr and locale_mgr.has_method("get_llm_directive"):
		var directive: String = locale_mgr.get_llm_directive()
		if not directive.is_empty():
			base += "\n" + directive
	_refresh_scene_context()
	var scene_block := _build_scene_contract_block()
	if not scene_block.is_empty():
		base += "\n" + scene_block

	# Tone guidance from ToneController
	if tone_controller:
		var tone_guidance := tone_controller.get_tone_prompt_guidance()
		if not tone_guidance.is_empty():
			base += "\n" + tone_guidance

	# Danger signals (P1.8.1): injected with high priority
	var danger_signals: Array = _current_context.get("danger_signals", [])
	if danger_signals.size() > 0:
		base += "\n[DANGER] " + " | ".join(danger_signals)

	# Narrative context (P1.7.1): run phase + arcs
	if narrative:
		var narr_summary: String = narrative.get_summary_for_prompt()
		if not narr_summary.is_empty():
			base += "\n" + narr_summary

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
	var factions: Dictionary = _current_context.get("factions", {})
	var parts: Array[String] = []

	# Factions (compact)
	var faction_parts: Array[String] = []
	for faction in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		faction_parts.append("%s=%d" % [faction, int(factions.get(faction, 0))])
	parts.append("Factions: " + " ".join(faction_parts))

	# Day + Life
	var life_val: int = int(_current_context.get("life_essence", 100))
	parts.append("Jour:%d Carte:%d Vie:%d" % [
		_current_context.get("day", 1),
		_current_context.get("cards_played", 0),
		life_val,
	])
	if not _scene_context.is_empty():
		var scene_id := str(_scene_context.get("scene_id", ""))
		var phase := str(_scene_context.get("phase", ""))
		if scene_id != "":
			parts.append("Scene:%s" % scene_id)
		if phase != "":
			parts.append("Phase:%s" % phase)

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

	# Plain text format — no JSON for small models
	parts.append("Ecris la scene puis les 3 choix A) B) C) en francais.")

	return "\n".join(parts)


func _parse_llm_response(text: String) -> Dictionary:
	## Parse la reponse LLM en carte valide (factions/oghams).
	## Supports both JSON and plain text format.

	# Strategy 1: Try JSON extraction via adapter
	if _store and _store.llm:
		var adapter: MerlinLlmAdapter = _store.llm
		var extracted: Dictionary = adapter._extract_json_from_response(text)
		if not extracted.is_empty():
			# Validate new card schema: requires "text" + at least 1 option
			var card_text: String = str(extracted.get("text", ""))
			var card_opts: Array = extracted.get("options", [])
			if card_text.length() >= 10 and card_opts.size() >= 1:
				return extracted

	# Strategy 2: Plain text extraction (A/B/C choices)
	var plain_card := _parse_plain_text_response(text)
	if not plain_card.is_empty():
		return plain_card

	# Strategy 3: Basic JSON extraction (no adapter)
	var json_start := text.find("{")
	var json_end := text.rfind("}")
	if json_start != -1 and json_end > json_start:
		var json_text := text.substr(json_start, json_end - json_start + 1)
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("text") and parsed.has("options"):
				if typeof(parsed["options"]) == TYPE_ARRAY and parsed["options"].size() >= 2:
					return parsed

	return {}


func _parse_plain_text_response(text: String) -> Dictionary:
	## Extract narrative + A/B/C choices from plain text LLM output.
	## Handles markdown bold markers (**A)**), arrow sequel hooks, etc.
	# Permissive regex for 1.5B output variants: A), **A)**, A:, Action A:, - **B**:, etc.
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+(.+)")
	var matches := rx.search_all(text)

	var labels: Array[String] = []
	for m in matches:
		var label := m.get_string(1).strip_edges().replace("**", "").replace("*", "")
		# Strip arrow sequel hooks
		var arrow_pos := label.find(" -> ")
		if arrow_pos > 0:
			label = label.substr(0, arrow_pos).strip_edges()
		if label.length() > 2 and label.length() < 120:
			labels.append(label)

	# Accept even with 0 labels — narrative text alone is still useful
	# (fallback labels will be used)

	# Extract narrative text (everything before first choice)
	var rx2 := RegEx.new()
	rx2.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+")
	var first_choice := rx2.search(text)
	var narrative := text.strip_edges()
	if first_choice:
		narrative = text.substr(0, first_choice.get_start()).strip_edges()
	# Strip any remaining markdown
	narrative = narrative.replace("**", "").replace("*", "")

	if narrative.length() < 10:
		return {}

	# Pad to 3 labels if needed
	while labels.size() < 3:
		var fallback_labels := [tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")]
		labels.append(fallback_labels[labels.size()])

	# Build card with default effects
	var effect_cycle := [
		[{"type": "HEAL_LIFE", "amount": 5}],
		[{"type": "ADD_KARMA", "amount": 3}],
		[{"type": "DAMAGE_LIFE", "amount": 3}],
	]
	var options: Array = []
	for j in range(3):
		var opt: Dictionary = {
			"label": labels[j],
			"effects": effect_cycle[j],
		}
		if j == 1:
			opt["cost"] = 1
		options.append(opt)

	return {
		"text": narrative,
		"speaker": "merlin",
		"options": options,
		"tags": ["llm_generated", "plain_text_parsed"],
		"_generated_by": "mos_plain_text",
	}

# ═══════════════════════════════════════════════════════════════════════════════
# GUARDRAILS — Language, repetition, length, content safety
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_guardrails(card: Dictionary) -> Dictionary:
	## Apply output guardrails. LLM-sourced cards get soft warnings instead of hard rejects.
	if card.is_empty():
		return card

	var text: String = str(card.get("text", ""))
	var source: String = str(card.get("_generated_by", card.get("_strategy", "")))
	var is_llm: bool = not source.is_empty()

	# 1. Length check — hard reject only for extreme violations
	if text.length() < 5:
		stats.llm_failures += 1
		generation_failed.emit("guardrail_length_critical")
		return {}
	if text.length() < GUARDRAIL_MIN_TEXT_LEN or text.length() > GUARDRAIL_MAX_TEXT_LEN:
		if is_llm:
			push_warning("[MOS] Guardrail soft: text length %d (bounds %d-%d)" % [text.length(), GUARDRAIL_MIN_TEXT_LEN, GUARDRAIL_MAX_TEXT_LEN])
		else:
			stats.llm_failures += 1
			generation_failed.emit("guardrail_length")
			return {}

	# 2. Language check — soft for LLM (Qwen sometimes mixes languages)
	if not _check_french_language(text):
		if is_llm:
			push_warning("[MOS] Guardrail soft: French language check failed")
		else:
			stats.llm_failures += 1
			generation_failed.emit("guardrail_language")
			return {}

	# 3. Persona forbidden words — hard reject for non-LLM, soft for LLM
	var forbidden_hit: String = _find_forbidden_word(text)
	if not forbidden_hit.is_empty():
		if is_llm:
			push_warning("[MOS] Guardrail soft: forbidden word '%s' in LLM text (allowing)" % forbidden_hit)
		else:
			stats.llm_failures += 1
			generation_failed.emit("guardrail_persona_forbidden")
			return {}

	# 4. Repetition check — soft for LLM (prefer similar card over fallback)
	if _is_repetitive(text):
		if is_llm:
			push_warning("[MOS] Guardrail soft: repetitive text detected")
		else:
			stats.llm_failures += 1
			generation_failed.emit("guardrail_repetition")
			return {}

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


func _find_forbidden_word(text: String) -> String:
	## Check if text contains any persona-forbidden word as a WHOLE WORD.
	## Returns the matched word, or "" if none found.
	if _persona_forbidden_words.is_empty():
		return ""
	var lower := text.to_lower()
	for word in _persona_forbidden_words:
		# Whole-word match: space-delimited (prevents "ia" matching "confiance")
		if lower.contains(" " + word + " ") or lower.begins_with(word + " ") or lower.ends_with(" " + word) or lower == word:
			return word
	return ""


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
		return {}

	# Validate text
	if typeof(card.get("text", null)) != TYPE_STRING:
		card["text"] = "..."

	# Validate options
	if typeof(card.get("options", null)) != TYPE_ARRAY:
		card["options"] = []

	if card.options.size() < 2:
		return {}

	# Pad to 3 options if LLM only returned 2
	_pad_options_to_minimum(card)

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


func _pad_options_to_minimum(card: Dictionary) -> void:
	## Ensure every card has at least 1 option (1-4 options supported).
	## If LLM returned empty options, insert a generic fallback.
	var opts: Array = card.get("options", [])
	if opts.size() >= 1:
		return

	# Determine thematic fallback based on tags
	var tags: Array = card.get("tags", [])
	var fallback_effects: Array = []

	if "combat" in tags or "danger" in tags:
		fallback_effects = [{"type": "ADD_KARMA", "amount": 2}]
	elif "stranger" in tags or "social" in tags:
		fallback_effects = [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 3}]
	elif "magic" in tags or "lore" in tags or "mystery" in tags:
		fallback_effects = [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 3}]

	opts.append({"label": "Continuer", "effects": fallback_effects, "preview": ""})
	card["options"] = opts


func _post_process_card(card: Dictionary) -> Dictionary:
	## Applique les modifications post-generation.
	if card.is_empty() or not card.has("options"):
		return card

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
		# Log reputation changes from outcome
		var rep_before: Dictionary = outcome.get("factions_before", {})
		var rep_after: Dictionary = outcome.get("factions_after", {})
		for faction in rep_after:
			var old_val: int = int(rep_before.get(faction, 0))
			var new_val: int = int(rep_after[faction])
			if old_val != new_val and rag_manager.has_method("log_reputation_changed"):
				rag_manager.log_reputation_changed(str(faction), old_val, new_val, cards_played, day)


func on_run_start() -> void:
	## Appele au debut d'une run.
	session.record_run_start()
	decision_history.reset_run()
	narrative.reset_run()
	# P1.10.2: Reset journal for the new run
	if rag_manager:
		rag_manager.reset_for_new_run()

	# Bridge quiz → player profile (first run only)
	if player_profile and player_profile.meta.get("runs_completed", 0) == 0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			var quiz_traits = gm.get("player_traits")
			if quiz_traits is Dictionary and not quiz_traits.is_empty():
				player_profile.seed_from_quiz(quiz_traits)
				print("[MOS] Player profile seeded from quiz: archetype=%s" % str(quiz_traits.get("archetype_id", "?")))


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

	# For dialogue (player explicitly talks to Merlin), use richer generation
	if context.begins_with("Le voyageur demande:"):
		var response := await _generate_dialogue_response(context, tone)
		merlin_speaks.emit(response, tone)
		return response

	# Get appropriate comment (short, 1-2 sentences)
	var comment := await _generate_merlin_comment(context, tone)

	merlin_speaks.emit(comment, tone)
	return comment


func _generate_dialogue_response(context: String, tone: String) -> String:
	## Genere une reponse de dialogue riche (3-4 phrases, 150 tokens).
	if llm_interface == null or not llm_interface.is_ready:
		return _get_fallback_dialogue(tone)

	var system := """Tu es Merlin l'Enchanteur, druide immortel de Broceliande.
Le voyageur te parle directement. Reponds en 3-4 phrases, ton %s.
Vocabulaire celtique (ogham, nemeton, sidhe, brume, pierre, souffle).
Niveau de confiance: %s
Sois poetique mais concret. Francais uniquement. Pas de guillemets.""" % [
		tone,
		relationship.get_trust_tier_name(),
	]

	var _raw_result = null
	if llm_interface.has_method("generate_with_router"):
		_raw_result = await llm_interface.generate_with_router(system, context, {"max_tokens": 150, "temperature": 0.75})
	elif llm_interface.has_method("generate_with_system"):
		_raw_result = await llm_interface.generate_with_system(system, context, {"max_tokens": 150, "temperature": 0.75})
	else:
		return _get_fallback_dialogue(tone)
	var result: Dictionary = _raw_result if _raw_result is Dictionary else {}

	if result.has("text") and not str(result.text).strip_edges().is_empty():
		return str(result.text).strip_edges()

	return _get_fallback_dialogue(tone)


func _get_fallback_dialogue(tone: String) -> String:
	## Fallback dialogue responses when LLM is unavailable.
	var responses := {
		"playful": "Ah, tu veux parler ? Les pierres ont des oreilles ici, voyageur. Mais entre nous, la brume cache plus de secrets que tu ne crois. Pose bien tes questions.",
		"mysterious": "Les fils du destin tremblent quand tu parles. Je vois des chemins qui se croisent dans la brume du nemeton. Certaines reponses ne viennent qu'a ceux qui savent attendre.",
		"warning": "Ecoute bien, voyageur. Les ombres s'allongent et le vent porte des murmures inquietants. Chaque mot que tu prononces ici a un poids. Choisis-les avec soin.",
		"melancholy": "Tant de voyageurs sont passes avant toi. Leurs voix resonnent encore dans les pierres de ce cercle ancien. Parfois, je me demande si les mots suffisent.",
	}
	return responses.get(tone, responses["mysterious"])


func _generate_merlin_comment(context: String, tone: String) -> String:
	## Genere un commentaire via pool/voice brain (ne bloque pas Narrator/GM) ou fallback.
	## Phase 5: Routes to dedicated Voice brain via swarm scheduler when available.
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

	# Phase 5: Submit as LOW priority background task via voice brain
	if llm_interface.has_method("submit_background_task"):
		var comment_done := {"text": ""}
		llm_interface.submit_background_task("voice", system, "",
			{"max_tokens": 64, "temperature": 0.7},
			func(result: Dictionary) -> void:
				if result.has("text"):
					comment_done.text = str(result.text).strip_edges()
		)
		# Brief wait for voice brain response (non-blocking timeout)
		var wait_start := Time.get_ticks_msec()
		while comment_done.text == "" and Time.get_ticks_msec() - wait_start < 5000:
			await get_tree().create_timer(0.1).timeout
		if comment_done.text != "":
			return comment_done.text

	# Fallback: direct generation (legacy path)
	var _raw_legacy = null
	if llm_interface.has_method("generate_voice"):
		_raw_legacy = await llm_interface.generate_voice(system, "")
	else:
		_raw_legacy = await llm_interface.generate_with_router(system, "", {"max_tokens": 64})
	var result: Dictionary = _raw_legacy if _raw_legacy is Dictionary else {}
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
# CARD TITLE GENERATION (P3.17.1)
# ═══════════════════════════════════════════════════════════════════════════════

const FALLBACK_TITLES: Array[String] = [
	"Le Murmure des Pierres",
	"L'Ombre du Nemeton",
	"Le Souffle des Anciens",
	"La Brume Parle",
	"Le Chemin des Oghams",
	"Sous le Chene Sacre",
	"L'Appel du Sidhe",
	"Entre Brume et Pierre",
	"La Voix du Cairn",
	"Le Seuil du Crépuscule",
]

func _generate_card_title(card: Dictionary) -> String:
	## Generate a short poetic title (3-6 words) for the card via GM brain.
	## Uses a tight 20-token budget. Falls back instantly if LLM unavailable.
	if llm_interface == null or not llm_interface.is_ready:
		return _get_fallback_title()

	var card_text: String = str(card.get("text", "")).left(120)
	if card_text.is_empty():
		return _get_fallback_title()

	var system := "Genere UN titre poetique en francais (3-6 mots) pour cette scene. Vocabulaire celtique. Reponds UNIQUEMENT avec le titre, rien d'autre."

	var _raw_result = null
	if llm_interface.has_method("generate_with_router"):
		_raw_result = await llm_interface.generate_with_router(system, card_text, {"max_tokens": 20, "temperature": 0.8})
	elif llm_interface.has_method("generate_with_system"):
		_raw_result = await llm_interface.generate_with_system(system, card_text, {"max_tokens": 20, "temperature": 0.8})
	else:
		return _get_fallback_title()
	var result: Dictionary = _raw_result if _raw_result is Dictionary else {}

	var title: String = str(result.get("text", "")).strip_edges()
	# Clean: remove quotes, trailing dots, limit length
	title = title.trim_prefix('"').trim_suffix('"').trim_prefix("*").trim_suffix("*").strip_edges()
	if title.length() < 3 or title.length() > 60:
		return _get_fallback_title()
	return title


func _get_fallback_title() -> String:
	return FALLBACK_TITLES[randi() % FALLBACK_TITLES.size()]


# ═══════════════════════════════════════════════════════════════════════════════
# DREAM GENERATION (P3.18.1)
# ═══════════════════════════════════════════════════════════════════════════════

const FALLBACK_DREAMS: Array[String] = [
	"Tu marches dans une foret de cristal. Les arbres chantent en ogham. Un cerf blanc te regarde, puis s'efface dans la brume.",
	"L'eau d'un lac noir reflete trois lunes. Chacune porte le visage d'un choix que tu as fait. Les rides troublent les images.",
	"Des pierres levees dansent en cercle lent. Le sol vibre sous tes pieds. Une voix ancienne murmure ton nom vrai.",
	"Tu voles au-dessus de Broceliande. Les sentiers forment un ogham geant. Le message s'efface avant que tu ne le comprennes.",
	"Le Sanglier, le Corbeau et le Cerf parlent ensemble. Ils debattent de ton avenir. Tu ne comprends que les silences.",
	"Un chaudron deborde de lumiere. Chaque goutte qui tombe cree un monde. Tu bois, et oublies ce que tu as vu.",
]

func generate_dream(game_state: Dictionary) -> String:
	## Generate a dream sequence (50-80 tokens) reflecting the player's journey.
	## Triggered during biome transitions. Uses player profile and aspects for context.
	if llm_interface == null or not llm_interface.is_ready:
		return FALLBACK_DREAMS[randi() % FALLBACK_DREAMS.size()]

	# Build dream context from game state
	var run: Dictionary = game_state.get("run", {})
	var factions: Dictionary = run.get("factions", {})
	var ogham: String = str(run.get("ogham_actif", ""))
	var biome: String = str(run.get("current_biome", "foret_broceliande"))
	var cards_played: int = int(run.get("cards_this_run", 0))

	var dominant_faction := ""
	var dominant_val := 0
	for f in factions:
		if int(factions[f]) > dominant_val:
			dominant_val = int(factions[f])
			dominant_faction = f

	var profile_hint := ""
	if player_profile:
		profile_hint = player_profile.get_summary_for_prompt()

	var system := "Tu es un generateur de reves celtiques. Ecris un reve court (3-5 phrases), onirique et symbolique. Le reve reflète le voyage du joueur. Vocabulaire mythologique breton/celtique. Reponds UNIQUEMENT avec le texte du reve."
	var faction_hint: String = ("Affinite: %s." % dominant_faction) if dominant_faction != "" else ""
	var ogham_hint: String = ("Ogham: %s." % ogham) if ogham != "" else ""
	var user_msg := "Voyageur: Biome=%s. Cartes jouees=%d. %s%s%s\nGenere un reve." % [
		biome, cards_played, faction_hint, ogham_hint,
		(" Profil: " + profile_hint) if not profile_hint.is_empty() else "",
	]

	var _raw_result = null
	if llm_interface.has_method("generate_with_router"):
		_raw_result = await llm_interface.generate_with_router(system, user_msg, {"max_tokens": 80, "temperature": 0.9})
	elif llm_interface.has_method("generate_with_system"):
		_raw_result = await llm_interface.generate_with_system(system, user_msg, {"max_tokens": 80, "temperature": 0.9})
	else:
		return FALLBACK_DREAMS[randi() % FALLBACK_DREAMS.size()]
	var result: Dictionary = _raw_result if _raw_result is Dictionary else {}

	var text: String = str(result.get("text", "")).strip_edges()
	if text.length() < 20 or text.length() > 400:
		return FALLBACK_DREAMS[randi() % FALLBACK_DREAMS.size()]
	return text


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

	# Phase 44: Record event category selection for anti-repetition
	if event_selector and not _last_event_selection.is_empty():
		event_selector.record_selection(
			str(_last_event_selection.get("category", "")),
			str(_last_event_selection.get("sub_type", "")),
			stats.cards_generated
		)
		# Tag card with category
		if card.has("tags") and card["tags"] is Array:
			var cat: String = str(_last_event_selection.get("category", ""))
			if not cat.is_empty() and not card["tags"].has("cat_" + cat):
				card["tags"].append("cat_" + cat)

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
	if event_selector and event_selector.is_loaded():
		info["event_selector_loaded"] = true
		info["event_history_size"] = event_selector.get_history().size()
		info["last_event_category"] = _last_event_selection.get("category", "none")
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
