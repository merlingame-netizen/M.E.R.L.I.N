## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Game Controller — Store-UI Bridge (v1.0.0 — Fusion Phase 37)
## ═══════════════════════════════════════════════════════════════════════════════
## Full gameplay controller: minigames (8 champs lexicaux), critical choices,
## talents/biome passives, karma/blessings/adaptive difficulty,
## factions, oghams, SFX choreography.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MerlinGameController

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

var store: MerlinStore
var ui: MerlinGameUI
var merlin_ai: Node = null  # MerlinAI autoload reference

var current_card: Dictionary = {}
var is_processing := false
var _intro_shown := false
var _cards_this_run := 0
## _dispatch_result removed — P0.1.1: direct await replaces polling pattern
const LLM_TIMEOUT_SEC := 360.0  # CPU-only Qwen 3B: Strategy B (120s) + C (120s) + overhead

# ═══════════════════════════════════════════════════════════════════════════════
# D20 DICE SYSTEM (from TestBrainPool fusion)
# ═══════════════════════════════════════════════════════════════════════════════

# DC now uses variable ranges from MerlinConstants.DC_BASE (Phase 43)
# Left: 4-8, Center: 7-12, Right: 10-16 + aspect modifiers
const DICE_ROLL_DURATION := 3.0  # Extended for LLM prefetch time

const KARMA_MIN := -10
const KARMA_MAX := 10
const BLESSINGS_MAX := 2
var minigame_chance := 0.3  # 30% mini-game, 70% dice (settable for headless testing)
var headless_mode := false   # Disables all minigames (set by auto_play_runner)

## DEV — override biome pour test direct (sans passer par Hub/BiomeRadial)
## Valeurs: "broceliande" | "landes" | "cotes" | "villages" | "cercles" | "marais" | "collines"
## Laisser vide ("") pour utiliser GameManager ou BIOME_DEFAULT (foret_broceliande)
@export var dev_biome_override: String = ""

# Run-local state (reset each start_run)
var _karma: int = 0
var _blessings: int = 0
var _quest_history: Array = []
var _is_critical_choice := false
var _critical_used := false
var _minigames_won: int = 0
var _free_center_remaining: int = 0
var _shield_corps_used := false
var _shield_monde_used := false

# Dynamic difficulty (balance-driven, Phase 5 LLM Intelligence Pipeline)
var _dynamic_modifier: int = 0
var _cards_since_rule_check: int = 0
const RULE_CHECK_INTERVAL := 3

# LLM cards include result_success/result_failure — no static reaction pools needed.
# Travel text is inline — no static pools needed.

# Card buffer for smooth gameplay
var _card_buffer: Array[Dictionary] = []
const BUFFER_SIZE := 5  # Ollama backend: <3s/card, 5 cards = ~15s at biome load

# Prerun choice tracking for sequel cards
var _prerun_choices: Array[Dictionary] = []

# Dream system: track biome for inter-biome dream trigger (P3.18.3)
var _last_biome: String = ""

# Tutorial system: diegetic narrative hints (P3.19)
var _tutorial_shown: Dictionary = {}  # { "trigger_key": true }
var _tutorial_data: Dictionary = {}   # Loaded from tutorial_narratives.json

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN INTRO SPEECH TEMPLATES (contextual biome + season)
# ═══════════════════════════════════════════════════════════════════════════════

## Biome display names for intro speeches (poetic, French, immersive)
const _BIOME_DISPLAY_NAMES: Dictionary = {
	"foret_broceliande": "la foret de Broceliande",
	"villages_celtes": "les villages celtes",
	"cotes_sauvages": "les cotes sauvages",
	"landes_bruyere": "les landes de bruyere",
	"marais_korrigans": "les marais des Korrigans",
	"cercles_pierres": "les cercles de pierres",
	"collines_dolmens": "les collines aux dolmens",
}

## Merlin intro speech templates — %s = biome display name
const _MERLIN_INTRO_SPEECHES: Array[String] = [
	"Les brumes de %s s'ouvrent devant toi, voyageur... Le terminal a capte des echos anciens.",
	"Merlin scrute %s a travers le cristal... Les chemins se dessinent, mais lequel choisiras-tu?",
	"Le cristal revele les sentiers de %s... Quelque chose t'attend au-dela du voile.",
	"Ah, %s... Les pierres murmurent ici des verites que peu osent entendre.",
	"Les runes pulsent et %s se devoile... Merlin sent le poids du destin, voyageur.",
]

## Season-specific flavor appended to intro (optional)
const _SEASON_FLAVOR: Dictionary = {
	"printemps": " La seve monte et la terre s'eveille.",
	"ete": " Le soleil brule haut et les ombres sont courtes.",
	"automne": " Les feuilles tombent et les esprits s'agitent.",
	"hiver": " Le givre mord et le silence est roi.",
	"spring": " La seve monte et la terre s'eveille.",
	"summer": " Le soleil brule haut et les ombres sont courtes.",
	"autumn": " Les feuilles tombent et les esprits s'agitent.",
	"winter": " Le givre mord et le silence est roi.",
}

# RAG context for LLM
const CONTEXT_FILE := "user://game_context.txt"
const CONTEXT_MAX_ENTRIES := 5

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Find store (singleton or child)
	store = get_node_or_null("/root/MerlinStore")

	# Find or create UI
	ui = get_node_or_null("MerlinGameUI")
	if not ui:
		ui = MerlinGameUI.new()
		ui.name = "MerlinGameUI"
		add_child(ui)

	# Find LLM interface
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		print("[MerlinController] MerlinAI found, LLM generation available")
	else:
		push_warning("[MerlinController] MerlinAI not found — LLM unavailable")

	_connect_signals()
	_load_tutorial_data()

	# Auto-start run after a frame so UI is fully ready
	await get_tree().process_frame
	await start_run()


func _connect_signals() -> void:
	# Store signals
	if store:
		store.state_changed.connect(_on_state_changed)
		store.life_changed.connect(_on_life_changed)
		store.run_ended.connect(_on_run_ended)
		store.mission_progress.connect(_on_mission_progress)

	# UI signals
	if ui:
		ui.option_chosen.connect(_on_option_chosen)
		ui.pause_requested.connect(_on_pause_requested)
		if ui.has_signal("merlin_dialogue_requested"):
			ui.merlin_dialogue_requested.connect(_on_merlin_dialogue_requested)
		if ui.has_signal("journal_requested"):
			ui.journal_requested.connect(_on_journal_requested)

	# Ogham wheel signals
	if ui and ui.has("ogham_wheel") and ui.ogham_wheel:
		if ui.ogham_wheel.has_signal("ogham_selected"):
			ui.ogham_wheel.ogham_selected.connect(_on_ogham_selected)


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(seed_value: int = -1) -> void:
	## Start a new Merlin run with narrator intro.
	var _t0 := Time.get_ticks_msec()
	print("[Merlin] start_run() called at t=%d" % _t0)
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system())

	_cards_this_run = 0
	_intro_shown = false
	_karma = 0
	_blessings = 0
	_quest_history = []
	_is_critical_choice = false
	_critical_used = false
	_minigames_won = 0
	_free_center_remaining = 0
	_shield_corps_used = false
	_shield_monde_used = false
	_dynamic_modifier = 0
	_cards_since_rule_check = 0
	_card_buffer.clear()
	_prerun_choices.clear()
	_last_biome = ""
	_load_prerun_cards()

	if not store:
		push_error("[Merlin] store is null in start_run, aborting")
		return

	# Apply talent bonuses at run start
	_apply_talent_bonuses()

	# Read biome from GameManager run data
	# Fallback chain: GameManager.run → dev_biome_override → BIOME_DEFAULT (broceliande)
	var biome_key: String = MerlinConstants.BIOME_DEFAULT
	var season_hint := ""
	var hour_hint := -1
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data = gm.get("run")
		if run_data is Dictionary:
			biome_key = str(run_data.get("current_biome", run_data.get("biome", {}).get("id", biome_key)))
			season_hint = str(run_data.get("season", run_data.get("saison", "")))
			if run_data.has("hour"):
				hour_hint = int(run_data.get("hour", -1))
			elif run_data.has("heure"):
				hour_hint = int(run_data.get("heure", -1))
	elif not dev_biome_override.is_empty():
		# Lancement direct (sans Hub) avec override éditeur — idéal pour tests rapides
		biome_key = dev_biome_override
		print("[Merlin] dev_biome_override actif: %s" % biome_key)

	# Apply biome CRT profile (phosphor tint + distortion)
	MerlinVisual.apply_biome_crt(biome_key)

	# Start biome music (crossfade from menu music)
	var music_mgr: Node = get_node_or_null("/root/MusicManager")
	if music_mgr and music_mgr.has_method("play_biome_music"):
		music_mgr.play_biome_music(biome_key)

	print("[Merlin] dispatching START_RUN biome=%s (dt=%dms)" % [biome_key, Time.get_ticks_msec() - _t0])
	var result = await store.dispatch({
		"type": "START_RUN",
		"seed": seed_value,
		"biome": biome_key,
	})
	print("[Merlin] START_RUN result: %s" % str(result))

	if result.get("ok", false):
		_sync_ui_with_state()
	if ui and is_instance_valid(ui) and ui.has_method("reset_run_visuals"):
		ui.reset_run_visuals()

	# Opening sequence then narrator intro before first card.
	# In headless mode (autoplay), skip all blocking UI sequences (click-to-continue, typewriter, etc.)
	if ui and is_instance_valid(ui) and not headless_mode:
		if ui.has_method("show_opening_sequence"):
			await ui.show_opening_sequence(biome_key, season_hint, hour_hint)
		await ui.show_narrator_intro(biome_key)
		_intro_shown = true
		# Scenario-specific intro (dealer_intro_context) before first card
		if store and store.has_method("get_scenario_manager"):
			var scenario_mgr = store.get_scenario_manager()
			if scenario_mgr and scenario_mgr.is_scenario_active():
				var intro_data: Dictionary = scenario_mgr.get_dealer_intro_override()
				var intro_ctx: String = str(intro_data.get("context", ""))
				var intro_title: String = str(intro_data.get("title", ""))
				if not intro_ctx.is_empty() and ui and is_instance_valid(ui):
					await ui.show_scenario_intro(intro_title, intro_ctx)

		# --- Merlin contextual speech (biome + season) before first card ---
		var merlin_speech: String = _build_merlin_intro_speech(biome_key, season_hint)
		if not merlin_speech.is_empty() and ui.has_method("show_narrator_text"):
			await ui.show_narrator_text(merlin_speech)
		elif not merlin_speech.is_empty():
			print("[Merlin] Merlin speech: %s" % merlin_speech)

		# Progressive reveal of indicators
		if ui.has_method("show_progressive_indicators"):
			await ui.show_progressive_indicators()
		# Start biome ambient VFX
		if ui.has_method("start_ambient_vfx"):
			ui.start_ambient_vfx(biome_key)
		print("[Merlin] narrator intro finished, requesting first card (dt=%dms)" % (Time.get_ticks_msec() - _t0))
	elif headless_mode:
		_intro_shown = true
		print("[Merlin] headless mode — skipped narrator intro (dt=%dms)" % (Time.get_ticks_msec() - _t0))

	# --- Verify card buffer before first card ---
	var buffer_ready: bool = await _ensure_card_buffer_ready()
	if buffer_ready:
		print("[Merlin] Deck ready: %d cards buffered" % _card_buffer.size())
	else:
		print("[Merlin] Card buffer empty, LLM will generate on demand")
		# Show contextual waiting message instead of generic spinner
		if ui and is_instance_valid(ui) and ui.has_method("show_merlin_thinking_overlay"):
			ui.show_merlin_thinking_overlay()
			if is_inside_tree():
				await get_tree().create_timer(1.5).timeout
			if ui and is_instance_valid(ui) and ui.has_method("hide_merlin_thinking_overlay"):
				ui.hide_merlin_thinking_overlay()

	# Then get first card (P0.1.3: await ensures intro finishes before card appears)
	print("[Merlin] start_run() about to await _request_next_card (dt=%dms)" % (Time.get_ticks_msec() - _t0))
	await _request_next_card()
	print("[Merlin] start_run() _request_next_card complete (dt=%dms)" % (Time.get_ticks_msec() - _t0))


func _request_next_card() -> void:
	## Get and display the next card (LLM or fallback).
	## Shows thinking animation while generating, with timeout protection.
	var _rnc_t0 := Time.get_ticks_msec()
	print("[Merlin] _request_next_card() called at t=%d, is_processing=%s" % [_rnc_t0, str(is_processing)])
	if is_processing:
		return
	if not is_inside_tree():
		print("[Merlin] not inside tree, aborting _request_next_card")
		return
	if not store:
		push_error("[Merlin] store is null in _request_next_card")
		return

	is_processing = true
	_cards_this_run += 1

	# --- Step 1. Life drain BEFORE card (bible s.13.3: "1.DRAIN -1") ---
	if store and is_instance_valid(store):
		store.dispatch({"type": "DAMAGE_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD})
		# Death guard: if drain killed the player, end run immediately (3D parity)
		if store.get_life_essence() <= 0:
			print("[Merlin] Player died from life drain at card %d" % _cards_this_run)
			is_processing = false
			store.dispatch({"type": "END_RUN"})
			return

	# Tutorial: first card ever (P3.19)
	if _cards_this_run == 1:
		_try_tutorial("first_card_ever")

	# Check power milestones (player gets stronger every 5 cards)
	_check_power_milestone()

	# Fast path: consume from pre-generated card buffer (from TransitionBiome)
	if not _card_buffer.is_empty():
		current_card = _card_buffer.pop_front()
		var remaining: int = _card_buffer.size()
		print("[Merlin] Using pre-generated card (%d remaining)" % remaining)
		_detect_critical_choice()
		_post_process_card_text()
		# Prefetch moved to _resolve_choice() — state must be updated first
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
		_check_vision_perk_auto_reveal()
		is_processing = false
		return

	# Sequel card: ~30% chance after prerun buffer exhausted, if we have prerun choices
	if _card_buffer.is_empty() and not _prerun_choices.is_empty() and randf() < 0.30:
		var sequel_card := await _try_sequel_card()
		if not sequel_card.is_empty():
			current_card = sequel_card
			print("[Merlin] Sequel card generated from prerun choice")
			_detect_critical_choice()
			_post_process_card_text()
			if ui and is_instance_valid(ui):
				ui.display_card(current_card)
			_check_vision_perk_auto_reveal()
			is_processing = false
			return

	# Fast path: try consuming prefetched card directly (skips full LLM pipeline)
	if store and store.has_method("get_merlin"):
		var merlin_mos = store.get_merlin()
		if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
			var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
			if not prefetched.is_empty():
				print("[Merlin] Using prefetched card (fast path)")
				current_card = prefetched
				_detect_critical_choice()
				_post_process_card_text()
				if ui and is_instance_valid(ui):
					ui.display_card(current_card)
				_check_vision_perk_auto_reveal()
				is_processing = false
				return

	# Show thinking animation while LLM generates
	print("[Merlin] show_thinking (dt=%dms)" % (Time.get_ticks_msec() - _rnc_t0))
	if ui and is_instance_valid(ui):
		ui.show_thinking()

	# Direct await dispatch (store.dispatch has internal timeouts via Ollama backend)
	print("[Merlin] awaiting store.dispatch GET_CARD (dt=%dms)" % (Time.get_ticks_msec() - _rnc_t0))
	var result: Dictionary = {}
	if store and is_instance_valid(store):
		result = await store.dispatch({"type": "GET_CARD"})
		if result == null:
			result = {"ok": false, "error": "null_result"}
	else:
		push_error("[Merlin] store invalid during card dispatch")
		result = {"ok": false, "error": "store_null"}

	# Hide thinking animation
	var dispatch_elapsed := Time.get_ticks_msec() - _rnc_t0
	print("[Merlin] dispatch complete (dt=%dms)" % dispatch_elapsed)
	if ui and is_instance_valid(ui):
		ui.hide_thinking()

	if not is_inside_tree():
		print("[Merlin] removed from tree after dispatch, aborting")
		is_processing = false
		return

	if not result.get("ok", false) or result.get("card", {}).is_empty():
		# Dispatch failed or empty — retry via direct LLM
		print("[Merlin] dispatch failed or empty, retrying LLM (dt=%dms)" % dispatch_elapsed)
		var retry_card := await _retry_llm_generation(3)
		if retry_card.is_empty():
			if ui and is_instance_valid(ui):
				ui.show_merlin_thinking_overlay()
			await get_tree().create_timer(5.0).timeout
			if ui and is_instance_valid(ui):
				ui.hide_merlin_thinking_overlay()
			is_processing = false
			await _request_next_card()
			return
		current_card = retry_card
		_detect_critical_choice()
		_post_process_card_text()
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
		is_processing = false
		return

	print("[Merlin] card dispatch result ok=%s (dt=%dms)" % [str(result.get("ok", false)), Time.get_ticks_msec() - _rnc_t0])
	if result.get("ok", false):
		current_card = result.get("card", {})
		# Validate card has valid options array (size 3)
		var opts = current_card.get("options", [])
		if current_card.is_empty() or not opts is Array or opts.size() < 3:
			print("[Merlin] card malformed (options=%s), retrying LLM" % str(opts.size() if opts is Array else "missing"))
			var retry_card := await _retry_llm_generation(2)
			if not retry_card.is_empty():
				current_card = retry_card
			else:
				# Wait and re-request
				is_processing = false
				await _request_next_card()
				return
		# NPC encounter: 15% chance after card 5
		if _cards_this_run > 5 and randf() < 0.15:
			var npc_card := await _try_npc_encounter()
			if not npc_card.is_empty():
				current_card = npc_card
				print("[Merlin] NPC encounter triggered: %s" % npc_card.get("speaker", "?"))
		# Detect critical choice before displaying
		_detect_critical_choice()
		_post_process_card_text()
		# Prefetch moved to _resolve_choice() — triggers after state update
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
	else:
		# Store dispatch failed — retry via direct LLM
		print("[Merlin] store dispatch failed, trying direct LLM retry")
		var llm_card := await _retry_llm_generation(3)
		if llm_card.is_empty():
			# Show thinking overlay and wait
			if ui and is_instance_valid(ui):
				ui.show_merlin_thinking_overlay()
			await get_tree().create_timer(3.0).timeout
			if ui and is_instance_valid(ui):
				ui.hide_merlin_thinking_overlay()
			is_processing = false
			await _request_next_card()
			return
		current_card = llm_card
		_detect_critical_choice()
		_post_process_card_text()
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
		_check_vision_perk_auto_reveal()

	print("[Merlin] _request_next_card() done (dt=%dms)" % (Time.get_ticks_msec() - _rnc_t0))
	is_processing = false


## _async_card_dispatch() removed — P0.1.1: direct await in _request_next_card() replaces this


func _retry_llm_generation(max_retries: int) -> Dictionary:
	## Retry LLM generation with escalating temperature. Returns card or {}.
	if merlin_ai == null or not merlin_ai.get("is_ready"):
		# Try triggering warmup for next attempt
		if merlin_ai and merlin_ai.has_method("ensure_ready"):
			merlin_ai.ensure_ready()
		return {}
	if not merlin_ai.has_method("generate_with_system"):
		return {}
	# Don't retry if LLM is already busy (prefetch or MOS generation)
	if merlin_ai.has_method("is_llm_busy") and merlin_ai.is_llm_busy():
		print("[Merlin] _retry_llm_generation: LLM busy, skipping retry")
		return {}

	var temperatures := [0.6, 0.7, 0.8]
	var system_prompt := "Tu es Merlin, druide FOU de Broceliande. Decris une SITUATION que le voyageur VIT (danger, enigme, rencontre). PAS ce que Merlin fait. Les 3 choix = REACTIONS du voyageur. Verbes SPECIFIQUES (jamais 'avancer'/'observer'/'fuir'/'suivre'). TU (jamais nous/je). Phrases courtes. Pas de 'Voici'. Pas de meta.\nExemple:\nHa! Un dolmen fissure bloque le sentier... Des runes pulsent sur la pierre, voyageur. Quelque chose gratte de l'autre cote.\nA) Escalader\nB) Dechiffrer\nC) Contourner\n4-5 phrases puis A) B) C). RIEN d'autre."

	for i in range(mini(max_retries, temperatures.size())):
		var temp: float = temperatures[i]
		var user_prompt := "Carte %d. Decris une SITUATION que le voyageur vit. Puis A) B) C) = ses REACTIONS. Verbes SPECIFIQUES lies a la scene." % _cards_this_run

		var result: Dictionary = await merlin_ai.generate_with_system(
			system_prompt, user_prompt,
			{"max_tokens": 180, "temperature": temp}
		)

		if result.has("error") or str(result.get("text", "")).length() < 20:
			print("[Merlin] LLM retry %d failed (temp=%.1f, err=%s)" % [i + 1, temp, str(result.get("error", "short"))])
			continue

		var raw_text: String = str(result.get("text", ""))
		print("[Merlin] LLM retry %d got %d chars" % [i + 1, raw_text.length()])

		# Parse labels — permissive regex for 1.5B output variants
		var labels: Array[String] = []
		var rx := RegEx.new()
		rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+(.+)")
		var matches := rx.search_all(raw_text)
		for m in matches:
			var label := m.get_string(1).strip_edges().replace("**", "").replace("*", "")
			if label.length() > 2 and label.length() < 120:
				labels.append(label)

		# Extract narrative (text before first label)
		var narrative := raw_text
		var rx2 := RegEx.new()
		rx2.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+")
		var first_choice := rx2.search(raw_text)
		if first_choice:
			narrative = raw_text.substr(0, first_choice.get_start()).strip_edges()
		narrative = narrative.replace("**", "").replace("*", "")

		# Accept narrative even with < 3 labels — pad with fallbacks
		if narrative.length() < 10:
			print("[Merlin] LLM retry %d: narrative too short, skipping" % (i + 1))
			continue

		# Pad labels to 3 if needed
		var fallback_labels := [tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")]
		while labels.size() < 3:
			labels.append(fallback_labels[labels.size()])
		print("[Merlin] LLM retry %d: %d labels extracted" % [i + 1, matches.size()])

		# Build card with Vie/Reputation effects
		var effect_sets: Array = [
			[{"type": "HEAL_LIFE", "amount": 5}],
			[{"type": "ADD_KARMA", "amount": 1}],
			[{"type": "DAMAGE_LIFE", "amount": 3}],
		]
		var options: Array = []
		var directions := ["left", "center", "right"]
		for j in range(3):
			var opt: Dictionary = {
				"direction": directions[j],
				"label": labels[j],
				"effects": effect_sets[j],
			}
			if j == 1:
				opt["cost"] = 1
			options.append(opt)

		print("[Merlin] LLM retry %d succeeded (temp=%.1f)" % [i + 1, temp])
		return {
			"id": "retry_%d_%d" % [_cards_this_run, i],
			"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 400)),
			"speaker": "Merlin",
			"type": "narrative",
			"options": options,
			"tags": ["llm_generated", "retry"],
		}

	print("[Merlin] All %d LLM retries exhausted" % max_retries)
	return {}


func _trigger_prefetch() -> void:
	## Start pre-generating the next card in background.
	if not store or not store.is_merlin_active():
		return
	var merlin_mos: MerlinOmniscient = store.get_merlin()
	if merlin_mos:
		merlin_mos.prefetch_next_card(store.state)


func _load_prerun_cards() -> void:
	## Load pre-generated cards from TransitionBiome temp file into buffer.
	var prerun_path := "user://temp_run_cards.json"
	if not FileAccess.file_exists(prerun_path):
		print("[Merlin] No prerun cards file found at %s" % prerun_path)
		print("[Merlin] Card buffer empty, LLM will generate on demand")
		return
	var file := FileAccess.open(prerun_path, FileAccess.READ)
	if not file:
		print("[Merlin] Failed to open prerun cards file")
		return
	var raw_text: String = file.get_as_text()
	file.close()
	DirAccess.remove_absolute(prerun_path)
	var data = JSON.parse_string(raw_text)
	if not data is Array:
		print("[Merlin] Prerun cards file invalid (not Array): %s" % raw_text.left(100))
		return
	for card in data:
		if card is Dictionary and card.has("text") and card.has("options"):
			_card_buffer.append(card)
	if not _card_buffer.is_empty():
		print("[Merlin] Loaded %d pre-generated cards from TransitionBiome" % _card_buffer.size())
	else:
		print("[Merlin] Prerun file had %d entries but none valid" % data.size())


func _build_merlin_intro_speech(biome_key: String, season_hint: String) -> String:
	## Build a contextual Merlin intro speech from templates.
	## Returns a single sentence with biome name and optional season flavor.
	var biome_display: String = _BIOME_DISPLAY_NAMES.get(biome_key, "")
	if biome_display.is_empty():
		# Fallback: humanize the key
		biome_display = biome_key.replace("_", " ")
	var template: String = _MERLIN_INTRO_SPEECHES[randi() % _MERLIN_INTRO_SPEECHES.size()]
	var speech: String = template % biome_display
	# Append season flavor if available
	var season_lower: String = season_hint.strip_edges().to_lower()
	if not season_lower.is_empty():
		var flavor: String = str(_SEASON_FLAVOR.get(season_lower, ""))
		if not flavor.is_empty():
			speech += flavor
	return speech


func _ensure_card_buffer_ready() -> bool:
	## Verify that the card buffer has at least one card ready.
	## If empty, attempt to wait for a prefetched card (up to 5s).
	## Returns true if at least one card is available, false otherwise.
	if not _card_buffer.is_empty():
		return true
	# Try consuming a prefetched card from MerlinOmniscient
	if store and store.has_method("get_merlin"):
		var merlin_mos = store.get_merlin()
		if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
			var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
			if not prefetched.is_empty():
				_card_buffer.append(prefetched)
				return true
	# Wait up to 5 seconds for a prefetched card to become available
	var wait_deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < wait_deadline:
		if not is_inside_tree():
			return false
		if store and store.has_method("get_merlin"):
			var merlin_mos = store.get_merlin()
			if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
				var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
				if not prefetched.is_empty():
					_card_buffer.append(prefetched)
					return true
		await get_tree().process_frame
	return false


func _try_npc_encounter() -> Dictionary:
	## Try to generate an NPC encounter card (LLM first, then fallback pool).
	if not store:
		return {}
	var merlin_mos: MerlinOmniscient = store.get_merlin()
	if merlin_mos and merlin_mos.has_method("generate_npc_card"):
		var npc_card: Dictionary = await merlin_mos.generate_npc_card(store.state)
		if not npc_card.is_empty():
			return npc_card
	return {}



func _try_sequel_card() -> Dictionary:
	## Generate a sequel card referencing a previous prerun choice.
	if _prerun_choices.is_empty() or not merlin_ai or not merlin_ai.get("is_ready"):
		return {}
	if not merlin_ai.has_method("generate_with_system"):
		return {}

	# Pick a random prerun choice with a sequel hook
	var candidates: Array[Dictionary] = []
	for pc in _prerun_choices:
		if not str(pc.get("sequel_hook", "")).is_empty():
			candidates.append(pc)
	if candidates.is_empty():
		candidates.assign(_prerun_choices)

	var chosen: Dictionary = candidates[randi() % candidates.size()]
	var context := _build_prerun_context_string(chosen)

	var system_prompt := "Tu es Merlin l'Enchanteur. Le joueur a fait un choix plus tot dans son voyage. Ecris une scene (5-7 phrases, 420-620 caracteres) qui est une CONSEQUENCE directe de ce choix passe. Propose 3 options (A/B/C) avec verbes d'action."
	var user_prompt := "Contexte du choix passe: %s. Carte %d du run. Genere une suite narrative coherente avec ce qui s'est passe avant." % [context, _cards_this_run]

	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, {"max_tokens": 380, "temperature": 0.72})
	if result.has("error") or str(result.get("text", "")).length() < 20:
		return {}

	var raw_text: String = str(result.get("text", ""))

	# Extract labels
	var labels: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+(.+)")
	var matches := rx.search_all(raw_text)
	for m in matches:
		var label := m.get_string(1).strip_edges()
		if label.length() > 2 and label.length() < 80:
			labels.append(label)

	var narrative := raw_text
	if labels.size() >= 2:
		var rx2 := RegEx.new()
		rx2.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+")
		var first_choice := rx2.search(raw_text)
		if first_choice:
			narrative = raw_text.substr(0, first_choice.get_start()).strip_edges()

	if labels.size() < 3:
		# LLM-only: reject sequel with insufficient labels
		return {}

	var sequel_effects: Array = [
		[{"type": "HEAL_LIFE", "amount": 5}],
		[{"type": "ADD_KARMA", "amount": 1}],
		[{"type": "DAMAGE_LIFE", "amount": 3}],
	]
	var options: Array = []
	for j in range(3):
		var opt: Dictionary = {
			"direction": ["left", "center", "right"][j],
			"label": labels[j] if j < labels.size() else "Choix %d" % (j + 1),
			"effects": sequel_effects[j],
		}
		options.append(opt)

	return {
		"id": "sequel_%d_%s" % [_cards_this_run, chosen.get("thread_id", "")],
		"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 300)),
		"speaker": "Merlin",
		"type": "narrative",
		"options": options,
		"result_success": "Les echos du passe resonent en ta faveur.",
		"result_failure": "Les consequences de tes choix passés te rattrapent.",
		"tags": ["sequel", "llm_generated"],
		"source_prerun": chosen.get("thread_id", ""),
	}


func _build_prerun_context_string(choice: Dictionary) -> String:
	## Build a context string from a prerun choice for sequel prompt.
	var parts: Array[String] = []
	var label: String = str(choice.get("chosen_label", ""))
	if not label.is_empty():
		parts.append("Le joueur a choisi: '%s'" % label)
	var hook: String = str(choice.get("sequel_hook", ""))
	if not hook.is_empty():
		parts.append("Consequence annoncee: '%s'" % hook)
	var outcome: String = str(choice.get("outcome", ""))
	if not outcome.is_empty():
		parts.append("Resultat: %s" % outcome)
	var card_text: String = str(choice.get("card_text", ""))
	if not card_text.is_empty():
		parts.append("Scene d'origine: '%s'" % card_text)
	return ". ".join(parts) if not parts.is_empty() else "Un choix anterieur"


func _resolve_choice(option: int) -> void:
	## Full resolution: choice → D20 or minigame → effects → reactions → travel → next.
	if is_processing or current_card.is_empty():
		return
	if not store or not is_instance_valid(store):
		push_error("[Merlin] store invalid in _resolve_choice")
		return
	if not is_inside_tree():
		return

	is_processing = true
	var direction: String = ["left", "center", "right"][clampi(option, 0, 2)]
	var choice_label: String = _get_choice_label(option)
	print("[Merlin] _resolve_choice option=%d direction=%s" % [option, direction])

	# --- 1. Compute DC ---
	var dc: int = _get_dc_for_direction(direction)

	# --- 2. Determine dice roll or minigame ---
	var dice_result: int = 0
	var use_minigame: bool = not headless_mode and randf() < minigame_chance and _cards_this_run >= 2
	if _is_critical_choice and not headless_mode:
		use_minigame = true

	# Chance modifier: force minigame with specific type from card
	# "minigame" can be a Dict (from _detect_minigame) or empty string
	var mg_field_raw = current_card.get("minigame", "")
	var chance_minigame: String = ""
	if mg_field_raw is Dictionary:
		chance_minigame = str(mg_field_raw.get("id", ""))
	elif mg_field_raw is String:
		chance_minigame = mg_field_raw
	if not chance_minigame.is_empty() and not headless_mode:
		use_minigame = true

	SFXManager.play("card_draw")

	if headless_mode:
		# Headless: instant dice roll, no UI animations
		dice_result = randi_range(1, 20)
	elif use_minigame:
		dice_result = await _run_minigame(direction, dc, chance_minigame)
	else:
		dice_result = await _run_dice_roll(dc)

	if not is_inside_tree():
		is_processing = false
		return

	# --- 4. Determine outcome ---
	var outcome: String = _classify_outcome(dice_result, dc)
	print("[Merlin] D20=%d vs DC=%d → %s" % [dice_result, dc, outcome])

	# --- 5. SFX for outcome ---
	if not headless_mode:
		_play_outcome_sfx(outcome)

	# --- 6. Dramatic pause before result reveal ---
	if not headless_mode and is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# --- 6b. Show dice result in UI ---
	if not headless_mode and ui and is_instance_valid(ui):
		ui.show_dice_result(dice_result, dc, outcome)

	# --- 7. Compute modulated effects ---
	var options: Array = current_card.get("options", [])
	var base_effects: Array = options[clampi(option, 0, options.size() - 1)].get("effects", []) if option < options.size() else []
	var modulated: Array = _modulate_effects(base_effects, outcome, direction)

	# --- 7b. Chance modifier: double positive on success, add penalty on failure ---
	if not chance_minigame.is_empty():
		modulated = _apply_chance_modifier_effects(modulated, outcome)

	# --- 8. Apply talent shields & blessings ---
	modulated = _apply_talent_shields(modulated)

	# --- 9. Dispatch to store (applies effects, checks run end) ---
	var result = await store.dispatch({
		"type": "RESOLVE_CHOICE",
		"card": current_card,
		"option": option,
		"modulated_effects": modulated,
		"outcome": outcome,
	})
	if result == null:
		result = {"ok": false}

	# --- 10. Update karma ---
	_update_karma(outcome, direction)

	# --- 11. Record quest history ---
	_quest_history.append({"card_idx": _cards_this_run, "choice": direction, "outcome": outcome, "d20": dice_result, "dc": dc})

	# --- 12a. Track prerun choices for sequel cards ---
	var card_tags: Array = current_card.get("tags", [])
	if card_tags.has("prerun"):
		var chosen_opt: Dictionary = {}
		var opts_arr: Array = current_card.get("options", [])
		if option < opts_arr.size() and opts_arr[option] is Dictionary:
			chosen_opt = opts_arr[option]
		_prerun_choices.append({
			"thread_id": str(current_card.get("id", "")),
			"card_text": str(current_card.get("text", "")).substr(0, 120),
			"chosen_label": str(chosen_opt.get("label", "")),
			"sequel_hook": str(chosen_opt.get("sequel_hook", "")),
			"card_index": _cards_this_run,
			"outcome": outcome,
		})

	# --- 12b. Scenario anchor resolution ---
	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var anchor_id: String = str(current_card.get("anchor_id", ""))
			if not anchor_id.is_empty():
				scenario_mgr.resolve_anchor(anchor_id, option)
				# Apply scenario flags as game effects
				var sc_flags: Dictionary = scenario_mgr.get_scenario_flags()
				for flag_key in sc_flags:
					store.dispatch({"type": "APPLY_EFFECTS", "effects": ["SET_FLAG:%s:%s" % [flag_key, str(sc_flags[flag_key])]], "source": "scenario"})

	# --- 12c. Auto-progress mission (Phase 43) ---
	_auto_progress_mission(outcome)

	# --- 13. Biome passive check ---
	_check_biome_passive()

	# --- 13b. Prefetch next card NOW (state is fully updated) ---
	# Runs in background while player sees result text + travel animation (~4-6s)
	_trigger_prefetch()

	# --- 14. Narrative result text (per-option first, then card-level, then reaction) ---
	var _result_shown := false
	if not headless_mode and ui and is_instance_valid(ui) and current_card.size() > 0:
		var result_key: String = "result_success" if outcome.contains("success") else "result_failure"
		# Try per-option result text first (richer, contextual)
		var result_text := ""
		var opts_for_result: Array = current_card.get("options", [])
		if option < opts_for_result.size() and opts_for_result[option] is Dictionary:
			var chosen_opt: Dictionary = opts_for_result[option]
			result_text = str(chosen_opt.get(result_key, ""))
		# Fallback to card-level result text
		if result_text.is_empty():
			result_text = str(current_card.get(result_key, ""))
		if not result_text.is_empty():
			await ui.show_result_text_transition(result_text, outcome)
			_result_shown = true
	# --- 15. Card outcome animation ---
	if not headless_mode and ui and is_instance_valid(ui):
		ui.animate_card_outcome(outcome)

	# --- 15b. Show life delta flash ---
	var life_delta: int = 0
	for eff in modulated:
		if eff is Dictionary:
			if str(eff.get("type", "")) == "DAMAGE_LIFE":
				life_delta -= abs(int(eff.get("amount", 0)))
			elif str(eff.get("type", "")) == "HEAL_LIFE":
				life_delta += int(eff.get("amount", 0))
	if not headless_mode and ui and is_instance_valid(ui) and ui.has_method("show_life_delta"):
		ui.show_life_delta(life_delta)

	# Wait for player to see reaction (skip in headless)
	if not headless_mode:
		if not is_inside_tree():
			is_processing = false
			return
		await get_tree().create_timer(3.0).timeout  # Extended for LLM prefetch

	# --- 16. Check run end ---
	if result.get("ok", false) and result.get("run_ended", false):
		print("[Merlin] run ended!")
		var ending = result.get("ending", {})
		ending["story_log"] = _quest_history.duplicate()
		# Calculate and apply rewards
		_apply_run_rewards(ending)
		if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
			ui.mark_card_completed()
		if not headless_mode and ui and is_instance_valid(ui):
			ui.show_end_screen(ending)
		is_processing = false
		return

	# --- 17. Travel animation → next card ---
	_sync_ui_with_state()
	if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
		ui.mark_card_completed()
	current_card = {}
	if not headless_mode and ui and is_instance_valid(ui):
		await ui.show_travel_animation("Le sentier continue...")
	elif not headless_mode and is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# --- 17b. Dream sequence on biome change (P3.18.3) ---
	if not headless_mode and store and is_instance_valid(store):
		var current_biome: String = str(store.state.get("run", {}).get("current_biome", ""))
		if not current_biome.is_empty() and not _last_biome.is_empty() and current_biome != _last_biome:
			_try_tutorial("first_biome_change")
			var mos: MerlinOmniscient = store.get_merlin() if store.has_method("get_merlin") else null
			if mos and mos.has_method("generate_dream"):
				var dream_text: String = await mos.generate_dream(store.state)
				if not dream_text.is_empty() and ui and is_instance_valid(ui) and ui.has_method("show_dream_overlay"):
					await ui.show_dream_overlay(dream_text)
					_write_context_entry("Reve: %s" % dream_text.left(80))
		_last_biome = current_biome

	# --- 18. Write RAG context ---
	_write_context_entry("Choix: %s (%s, D20=%d vs DC%d)" % [choice_label, outcome, dice_result, dc])

	# --- 18b. Dynamic difficulty check (every N cards) ---
	_cards_since_rule_check += 1
	if _cards_since_rule_check >= RULE_CHECK_INTERVAL:
		_cards_since_rule_check = 0
		_update_dynamic_difficulty()

	# --- 19. Next card ---
	is_processing = false
	_request_next_card()


## Check power milestones — player gets stronger every 5 cards during a run.
func _check_power_milestone() -> void:
	var cards: int = _cards_this_run
	if not MerlinConstants.POWER_MILESTONES.has(cards):
		return
	var ms: Dictionary = MerlinConstants.POWER_MILESTONES[cards]
	var mtype: String = str(ms.get("type", ""))
	var mval: int = int(ms.get("value", 0))
	print("[Merlin] Power milestone at card %d: %s +%d" % [cards, mtype, mval])
	match mtype:
		"HEAL":
			if store:
				store.dispatch({"type": "HEAL_LIFE", "amount": mval})
		"DC_REDUCTION":
			if store:
				var run_state: Dictionary = store.state.get("run", {})
				var bonuses: Dictionary = run_state.get("power_bonuses", {})
				bonuses["dc_reduction"] = int(bonuses.get("dc_reduction", 0)) + mval
				run_state["power_bonuses"] = bonuses
	# Show popup + sound
	if ui and is_instance_valid(ui) and ui.has_method("show_milestone_popup"):
		ui.show_milestone_popup(str(ms.get("label", "")), str(ms.get("desc", "")))
	SFXManager.play("ogham_chime")


## Update dynamic difficulty using balance heuristic (0ms, no LLM).
func _update_dynamic_difficulty() -> void:
	if not store or not store.llm:
		return
	var ctx: Dictionary = store.state.get("run", {}).duplicate()
	var tendency: String = str(ctx.get("player_tendency", "neutre"))
	var rule_change: Dictionary = store.llm._suggest_rule_heuristic(ctx, tendency)

	var rule_type: String = str(rule_change.get("type", "none"))
	var adjustment: int = int(rule_change.get("adjustment", 0))

	match rule_type:
		"difficulty":
			_dynamic_modifier = clampi(_dynamic_modifier + int(adjustment / 5), -3, 3)
		"tension":
			if store:
				store.dispatch({"type": "ADD_TENSION", "amount": adjustment})
		"karma":
			if store:
				store.dispatch({"type": "ADD_KARMA", "amount": adjustment})
	print("[Merlin] Rule check: type=%s adj=%d -> dynamic_modifier=%d" % [rule_type, adjustment, _dynamic_modifier])


# ═══════════════════════════════════════════════════════════════════════════════
# D20 RESOLUTION ENGINE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_dice_roll(dc: int) -> int:
	## Animate D20 dice roll. Returns final value (1-20).
	_try_tutorial("first_dice_roll")
	var target: int = randi_range(1, 20)

	SFXManager.play("dice_shake")
	if is_inside_tree():
		get_tree().create_timer(0.3).timeout.connect(func(): SFXManager.play("dice_roll"), CONNECT_ONE_SHOT)

	if ui and is_instance_valid(ui):
		await ui.show_dice_roll(dc, target)
	elif is_inside_tree():
		await get_tree().create_timer(DICE_ROLL_DURATION).timeout

	SFXManager.play("dice_land")
	return target


func _run_minigame(direction: String, dc: int, override_field: String = "") -> int:
	## Launch a minigame, convert score to D20. Fallback to dice if no registry.
	var narrative_text: String = str(current_card.get("text", ""))
	var gm_hint: String = str(current_card.get("minigame_hint", ""))

	# Detect field from narrative + tags
	var card_tags: Array = current_card.get("tags", [])
	var field: String = override_field if not override_field.is_empty() else MiniGameRegistry.detect_field(narrative_text, gm_hint, card_tags)
	var base_diff: int = clampi(int(dc / 2.0), 1, 10)
	if _is_critical_choice:
		base_diff = mini(base_diff + 3, 10)

	# Tool bonus: check if equipped tool gives bonus for this field
	var tool_bonus: int = 0
	var tool_bonus_text: String = ""
	var run_data: Dictionary = {}
	var gm_node: Node = get_node_or_null("/root/GameManager")
	if gm_node and "run" in gm_node:
		run_data = gm_node.run if gm_node.run is Dictionary else {}
	if run_data.is_empty() and store:
		run_data = store.state.get("run", {})
	var tool_id: String = str(run_data.get("tool", ""))
	if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
		var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
		var bonus_field: String = str(tool_info.get("bonus_field", ""))
		if bonus_field != "" and bonus_field == field:
			tool_bonus = int(tool_info.get("dc_bonus", 0))
			tool_bonus_text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", ""))]

	# Show minigame intro overlay
	if ui and is_instance_valid(ui):
		ui.show_minigame_intro(field, tool_bonus_text, tool_bonus)
		if is_inside_tree():
			await get_tree().create_timer(1.2).timeout

	var modifiers := {}
	var game: Node = MiniGameRegistry.create_minigame(field, base_diff, modifiers)
	if game == null:
		print("[Merlin] minigame creation failed, falling back to dice")
		return await _run_dice_roll(dc)

	SFXManager.play("minigame_start")
	# Host minigame inside card body if UI has content host
	var mg_host: Control = null
	if ui and is_instance_valid(ui) and ui.has_method("get_body_content_host"):
		mg_host = ui.get_body_content_host()
	if mg_host and is_instance_valid(mg_host):
		if game.has_method("setup_in_card"):
			game.setup_in_card(mg_host)
		else:
			mg_host.add_child(game)
		ui.switch_body_to_content()
	else:
		add_child(game)
	# Hide option buttons during minigame so player uses minigame controls
	if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
		ui.set_options_visible(false)
	game.start()

	# Timeout safety: don't hang forever if minigame fails to emit
	# Use Array container because GDScript lambdas capture by value
	var mg_state: Array = [false, {}]  # [done, result]
	game.game_completed.connect(func(result: Dictionary):
		mg_state[0] = true
		mg_state[1] = result
	, CONNECT_ONE_SHOT)
	var mg_timeout := 30.0
	var mg_deadline := Time.get_ticks_msec() + int(mg_timeout * 1000.0)
	while not mg_state[0] and Time.get_ticks_msec() < mg_deadline:
		if not is_inside_tree() or not is_instance_valid(game):
			break
		await get_tree().process_frame
	if not mg_state[0]:
		push_warning("[Merlin] minigame timed out after %.0fs, using dice fallback" % mg_timeout)
		if is_instance_valid(game):
			game.queue_free()
		if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
			ui.set_options_visible(true)
		return await _run_dice_roll(dc)
	var mg_result: Dictionary = mg_state[1]
	var score: int = int(mg_result.get("score", 50))
	var mg_success: bool = bool(mg_result.get("success", false))
	if mg_success:
		_minigames_won += 1
		SFXManager.play("minigame_success")
	else:
		SFXManager.play("minigame_fail")

	# Cleanup minigame
	if is_instance_valid(game):
		game.queue_free()
	# Restore option buttons after minigame
	if ui and is_instance_valid(ui) and ui.has_method("set_options_visible"):
		ui.set_options_visible(true)

	# Convert score to D20 + apply tool bonus
	var d20: int = MiniGameBase.score_to_d20(score)
	if tool_bonus != 0:
		d20 = clampi(d20 - tool_bonus, 1, 20)  # Negative bonus = easier (higher effective roll)
		print("[Merlin] tool bonus: %d → D20 adjusted to %d" % [tool_bonus, d20])
	print("[Merlin] minigame done: score=%d → D20=%d" % [score, d20])

	# Show score→D20 feedback then dice confirmation
	if ui and is_instance_valid(ui):
		ui.show_score_to_d20(score, d20, tool_bonus)
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		ui.show_dice_instant(dc, d20)
	SFXManager.play("dice_land")
	if is_inside_tree():
		await get_tree().create_timer(0.6).timeout

	return d20


func _classify_outcome(roll: int, dc: int) -> String:
	if roll == 20:
		return "critical_success"
	elif roll >= dc:
		return "success"
	elif roll > 1:
		return "failure"
	else:
		return "critical_failure"


func _get_dc_for_direction(direction: String) -> int:
	# Variable DC from ranges (Phase 43)
	var dc_info: Dictionary = MerlinConstants.DC_BASE.get(direction, MerlinConstants.DC_BASE.get("center", {}))
	var dc_min: int = int(dc_info.get("min", 7))
	var dc_max: int = int(dc_info.get("max", 12))
	var base_dc: int = randi_range(dc_min, dc_max)

	# Blend with card's dc_hint if available (60% base + 40% card hint)
	var option_idx: int = ["left", "center", "right"].find(direction)
	if option_idx >= 0:
		var opts: Array = current_card.get("options", [])
		if option_idx < opts.size() and opts[option_idx] is Dictionary:
			var hint: Dictionary = opts[option_idx].get("dc_hint", {})
			if hint.has("min") and hint.has("max"):
				var hint_dc: int = randi_range(int(hint["min"]), int(hint["max"]))
				base_dc = int(base_dc * 0.6 + hint_dc * 0.4)

	var modifier: int = 0

	# Adaptive difficulty (pity / challenge)
	if _quest_history.size() >= 3:
		var last_3: Array = _quest_history.slice(-3)
		var consecutive_fails: int = 0
		var consecutive_wins: int = 0
		for entry in last_3:
			var o: String = str(entry.get("outcome", ""))
			if o == "failure" or o == "critical_failure":
				consecutive_fails += 1
			elif o == "success" or o == "critical_success":
				consecutive_wins += 1
		if consecutive_fails >= 3:
			modifier = -4  # Pity mode
		elif consecutive_wins >= 3:
			modifier = 2  # Challenge mode

	# Critical choice modifier
	if _is_critical_choice:
		var crit_penalty: int = 4
		if store and store.has_method("is_talent_active") and store.is_talent_active("feuillage_4"):
			crit_penalty = 2
		modifier += crit_penalty

	# Biome difficulty modifier
	if store and store.biomes:
		var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
		if not biome_key.is_empty():
			var biome_data: Dictionary = store.biomes.get_biome_data(biome_key) if store.biomes.has_method("get_biome_data") else {}
			modifier += int(biome_data.get("difficulty", 0))

	# Power milestone DC reduction
	var dc_bonus: int = 0
	if store:
		dc_bonus = int(store.state.get("run", {}).get("power_bonuses", {}).get("dc_reduction", 0))

	# B.3 — Archetype DC bonus (read from GameManager.player_traits)
	var archetype_modifier: int = 0
	var gm_arch := get_node_or_null("/root/GameManager")
	if gm_arch:
		var traits = gm_arch.get("player_traits")
		if traits is Dictionary:
			var arch_id: String = str(traits.get("archetype_id", ""))
			if MerlinConstants.ARCHETYPE_DC_BONUS.has(arch_id):
				archetype_modifier = int(MerlinConstants.ARCHETYPE_DC_BONUS[arch_id])

	# B.4 — Faction reputation DC modifier (extreme rep = harder)
	var faction_modifier: int = 0
	if store:
		var factions: Dictionary = store.state.get("run", {}).get("factions", {})
		var extremes: int = 0
		for faction_key in MerlinReputationSystem.FACTIONS:
			var rep: float = float(factions.get(faction_key, 0.0))
			if rep < 20.0 or rep > 80.0:
				extremes += 1
				faction_modifier += 1
		if extremes == 0:
			faction_modifier = -2  # All factions neutral = easier

	return clampi(base_dc + modifier + _dynamic_modifier - dc_bonus + archetype_modifier + faction_modifier, 2, 19)


func _get_choice_label(option: int) -> String:
	var options: Array = current_card.get("options", [])
	if option < options.size():
		return str(options[option].get("label", ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]))
	return ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT MODULATION
# ═══════════════════════════════════════════════════════════════════════════════

func _modulate_effects(base_effects: Array, outcome: String, _direction: String) -> Array:
	## Modulate card effects based on minigame outcome.
	## Effects: DAMAGE_LIFE, HEAL_LIFE, ADD_REPUTATION.
	var result: Array = []
	for effect in base_effects:
		var e: Dictionary = effect.duplicate() if effect is Dictionary else {}
		var etype: String = str(e.get("type", ""))
		match outcome:
			"critical_success":
				# Double positive effects
				if etype == "HEAL_LIFE" or etype == "ADD_REPUTATION":
					var boosted: Dictionary = e.duplicate()
					boosted["amount"] = int(e.get("amount", 0)) * 2
					result.append(boosted)
				elif etype == "DAMAGE_LIFE":
					# Cancel damage on crit success
					pass
				else:
					result.append(e)
			"success":
				result.append(e)
			"failure":
				# Reverse: heals become damage, damage becomes heal
				if etype == "HEAL_LIFE":
					result.append({"type": "DAMAGE_LIFE", "amount": int(e.get("amount", 0))})
				elif etype == "DAMAGE_LIFE":
					result.append({"type": "HEAL_LIFE", "amount": int(e.get("amount", 0))})
				else:
					result.append(e)
			"critical_failure":
				# Reverse heals to damage, keep damage as-is (bonus penalty applied separately)
				if etype == "HEAL_LIFE":
					result.append({"type": "DAMAGE_LIFE", "amount": int(e.get("amount", 0))})
				elif etype == "DAMAGE_LIFE":
					result.append(e)
				else:
					result.append(e)

	# Life damage on critical failure (bonus penalty)
	if outcome == "critical_failure" and store:
		store.dispatch({"type": "DAMAGE_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_CRIT_FAIL_DAMAGE})
		print("[Merlin] Critical failure! Life essence -%d" % MerlinConstants.LIFE_ESSENCE_CRIT_FAIL_DAMAGE)

	# Life heal on critical success (bonus heal)
	if outcome == "critical_success" and store:
		store.dispatch({"type": "HEAL_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_CRIT_SUCCESS_HEAL})
		print("[Merlin] Critical success! Life essence +%d" % MerlinConstants.LIFE_ESSENCE_CRIT_SUCCESS_HEAL)

	# Talent: feuillage_7 — Negative effects -30%
	if store and store.has_method("is_talent_active") and store.is_talent_active("feuillage_7"):
		for e in result:
			if str(e.get("type", "")) == "DAMAGE_LIFE":
				e["amount"] = int(int(e.get("amount", 0)) * 0.7)

	return result


func _apply_talent_shields(effects: Array) -> Array:
	## Apply talent shields (cancel first damage, 1/run).
	if not store or not store.has_method("is_talent_active"):
		return effects

	var result: Array = []
	for e in effects:
		var etype: String = str(e.get("type", ""))

		# Shield (racines_2): cancel first DAMAGE_LIFE
		if etype == "DAMAGE_LIFE" and not _shield_corps_used:
			if store.is_talent_active("racines_2"):
				_shield_corps_used = true
				print("[Merlin] Talent: Endurance Naturelle absorbe les degats!")
				SFXManager.play("skill_activate")
				continue  # Skip this effect

		result.append(e)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# KARMA & BLESSINGS
# ═══════════════════════════════════════════════════════════════════════════════

func _update_karma(outcome: String, direction: String) -> void:
	match outcome:
		"critical_success":
			_karma = clampi(_karma + 2, KARMA_MIN, KARMA_MAX)
			_blessings = mini(_blessings + 1, BLESSINGS_MAX)
		"critical_failure":
			_karma = clampi(_karma - 2, KARMA_MIN, KARMA_MAX)
		"success":
			if direction == "right":
				_karma = clampi(_karma + 1, KARMA_MIN, KARMA_MAX)
			elif direction == "left":
				_karma = clampi(_karma - 1, KARMA_MIN, KARMA_MAX)



func _apply_talent_bonuses() -> void:
	## Apply talent effects at the start of a run.
	if not store or not store.has_method("is_talent_active"):
		return
	# Free center uses (feuillage_2)
	if store.is_talent_active("feuillage_2"):
		_free_center_remaining = 1
	# Starting blessings (racines_3)
	if store.is_talent_active("racines_3"):
		_blessings = 1


# ═══════════════════════════════════════════════════════════════════════════════
# CARD TEXT POST-PROCESSING (FIX 33)
# ═══════════════════════════════════════════════════════════════════════════════

func _post_process_card_text() -> void:
	## FIX 33: Post-process current_card text before display.
	## Applies meta stripping, person conversion, label cleanup.
	## Mirrors TransitionBiome._strip_meta_text() + _convert_first_to_second_person().
	if current_card.is_empty():
		return
	var text: String = str(current_card.get("text", ""))
	if text.is_empty():
		return

	# --- Meta-text stripping (strip entire lines containing meta patterns) ---
	var meta_words: Array[String] = [
		"decrochez le choix", "choisir entre", "(a)", "(b)", "(c)", "a/b/c",
		"regle stricte", "meta-commentaire", "vocabulaire celtique",
		"ecris une scene", "3 choix", "biome:", "carte:", "role:",
		"scene narrative", "trois options", "trois choix",
		"je suis merlin", "je suis le druide", "je suis un druide",
		"je suis une voix", "je suis un ancien", "je suis le gardien",
		"voici les choix", "voici trois", "voici les options",
		"voici une introduction", "voici ta reponse", "voici la reponse",
		"je suis pret", "merlin est un", "merlin est le",
		"tu as choisi", "avec une voix", "d'une voix",
		"ensemble nous formons", "c'est une situation",
		"narration:", "narrateur:", "scenario:",
		"voici une description", "description ambiante", "basee sur le scenario",
		"bienvenue dans", "bienvenue en", "ce voyageur est",
		"le lieu est", "le parc national", "heures de train",
		# FIX 38: Meta-text describing narrative structure
		"sert de catalyseur", "met l'accent sur", "complication suivante",
		"la suite de l'histoire", "dans cette scene", "cette carte",
		"cette situation sert", "voici une complication", "voici un",
		"ce passage montre", "ce moment revele", "cela introduit",
		# FIX 41: Prompt structure leaks (VERBE:, B/C, FORCE label)
		"verbe :", "verbe:", "b/c)", "a/b)", "a) ", "b) ", "c) ",
		"a/ ", "b/ ", "c/ ", "a/'", "b/'", "c/'",
		"force:", "force :", "option a", "option b", "option c",
		# FIX 43: Identity leaks (LLM assigns Merlin identity to player)
		"tu es merlin", "tu es le druide", "tu es un druide",
		"tu es l'enchanteur", "merlin l'enchanteur",
		# FIX 44: Card generation meta-text + scene structure
		"voici ta carte", "entierement generee", "informations fournies",
		"premiere scene", "deuxieme scene", "troisieme scene",
		"point de depart", "genere en fonction",
		# FIX 45: Prompt instruction leaks (raw template output)
		"titre poetique", "action en 1 phrase", "vers de complication",
		"action differente", "tu puis ai", "equipe principale",
		# FIX 46: Narrative structure leaks ("la complication est causée par...")
		"la complication est", "causee par", "causée par",
		"est causee par", "est causée par",
		# FIX 47: Scenario suggestion + tag description leaks
		"voici la suggestion", "suggestion du scenario",
		"theme ambiant", "thème ambiant", "tags appropries", "tags appropriés",
		"pour le biome", "carte ambiante pour",
		"jour 1 de ce voyage", "jour 2 de ce voyage", "jour 3 de ce voyage",
		# FIX 48: Option labeling leaks + "phrase finale"
		"phrase finale", "phrase initiale", "phrase de transition",
		# FIX 49: Arc prefix + season/session labels
		"saison spring", "saison summer", "saison autumn", "saison winter",
		"saison :", "séance:", "seance:", "séance :",
		# FIX 50: Screenplay format + "cette scène"
		"cette scene", "cette scène", "the scene is",
		# FIX 51: Dash-prefixed arc names
		"- voyage en", "- exploration de", "- complication",
		# FIX 52: "Scene N" without separator + "in the" English intro
		"scene 1", "scene 2", "scene 3", "scene 4", "scene 5",
		"in the forest", "in the mist", "in the cave",
		# FIX 55: Card type labels leaked from prompt
		"carte ambiante", "carte narrative", "carte ambiance",
		"carte événement", "carte evenement", "carte merlin",
		"carte promesse", "ambient card", "narrative card",
	]
	var result := text
	# Strip "Etape N:" / "Scene N -" / "Acte N:" / "Scene :" / "Scene 1" prefixes
	# FIX 52: require digits OR separator (not neither) to avoid stripping legit "Scene" text
	var rx := RegEx.new()
	rx.compile("(?im)^\\s*(?:[eé]tape|scene|sc[eè]ne|acte|chapitre|séance)\\s*(?:\\d+\\s*[:\\-]?|[:\\-])\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx.sub(result, "", true)
	# FIX 36: Strip arc phase prefixes (Complication:, Climax:, Resolution:, etc.)
	rx.compile("(?im)^\\s*(?:complication|climax|resolution|introduction|exploration|twist|epilogue|prologue|transition|aurore druidique)\\s*:?\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx.sub(result, "", true)
	# Strip markdown bold
	rx.compile("\\*\\*[^*]{0,60}\\*\\*:?")
	result = rx.sub(result, "", true)
	# FIX 50: Strip screenplay format headers (INT./EXT. LOCATION - TIME)
	rx.compile("(?im)^\\s*(?:INT|EXT|int|ext)\\.\\s*[A-ZÀ-Ü ]{2,50}\\s*[-–—]\\s*[A-ZÀ-Ü ]{2,20}\\s*\\n?")
	result = rx.sub(result, "", true)
	# FIX 46: Strip lines starting with backslash (raw markup leak)
	rx.compile("(?m)^\\s*\\\\\\s*.+$")
	result = rx.sub(result, "", true)
	# Strip lines containing meta-words
	for mw in meta_words:
		var pos := result.to_lower().find(mw)
		while pos >= 0:
			var line_start := result.rfind("\n", pos)
			var line_end := result.find("\n", pos)
			if line_start < 0: line_start = 0
			if line_end < 0: line_end = result.length()
			var candidate: String = result.substr(0, line_start) + result.substr(line_end)
			# FIX 47: If line-strip would destroy all text, use sentence-strip instead
			if candidate.strip_edges().length() < 10:
				# Sentence-level: find sentence boundary (.:;!) around meta word
				var sent_start := pos
				for ch in [".", ":", ";", "!"]:
					var ss := result.rfind(ch, pos)
					if ss >= 0 and ss > line_start:
						sent_start = ss + 1
						break
				if sent_start == pos:
					sent_start = line_start
				var sent_end := result.length()
				for ch in [".", ":", ";", "!"]:
					var se := result.find(ch, pos + mw.length())
					if se >= 0 and se < sent_end:
						sent_end = se + 1
				result = result.substr(0, sent_start) + result.substr(sent_end)
			else:
				result = candidate
			pos = result.to_lower().find(mw)

	# FIX 47: Strip "→ choix:" template arrows and ALL-CAPS option labels
	rx.compile("(?m)→\\s*choix\\s*:\\s*[A-ZÀ-Ü]+")
	result = rx.sub(result, "", true)

	# --- Person conversion: 1st→2nd (je→tu), vous→tu ---
	# FIX 40: Handle j'ai/j'avais/j'étais BEFORE generic j'→t' (prevents "t'ai")
	rx.compile("(?i)\\bj'ai\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?i)\\bj'avais\\b")
	result = rx.sub(result, "tu avais", true)
	rx.compile("(?i)\\bj'[eé]tais\\b")
	result = rx.sub(result, "tu étais", true)
	rx.compile("(?i)\\bj'aurai\\b")
	result = rx.sub(result, "tu auras", true)
	rx.compile("(?i)\\bj'")
	result = rx.sub(result, "t'", true)
	rx.compile("(?i)\\bje\\b")
	result = rx.sub(result, "tu", true)
	rx.compile("(?i)\\bm'")
	result = rx.sub(result, "t'", true)
	rx.compile("(?i)\\bme\\b")
	result = rx.sub(result, "te", true)
	rx.compile("(?i)\\bmoi\\b")
	result = rx.sub(result, "toi", true)
	rx.compile("(?i)\\bvous avez\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?i)\\bvous [eê]tes\\b")
	result = rx.sub(result, "tu es", true)
	rx.compile("(?i)\\bvous\\b")
	result = rx.sub(result, "tu", true)
	rx.compile("(?i)\\bvotre\\b")
	result = rx.sub(result, "ton", true)
	rx.compile("(?i)\\bvos\\b")
	result = rx.sub(result, "tes", true)
	rx.compile("(?i)\\bmes\\b")
	result = rx.sub(result, "tes", true)
	rx.compile("(?i)\\bmon\\b")
	result = rx.sub(result, "ton", true)
	rx.compile("(?i)\\bma\\b")
	result = rx.sub(result, "ta", true)

	# FIX 42: Fix avoir conjugation after "je"→"tu" conversion
	# "je n'ai" becomes "tu n'ai" (wrong) → fix to "tu n'as"
	rx.compile("(?i)\\btu n'ai\\b")
	result = rx.sub(result, "tu n'as", true)
	rx.compile("(?i)\\btu ai\\b")
	result = rx.sub(result, "tu as", true)

	# --- Capitalize "tu" at sentence start ---
	rx.compile("(?m)^tu\\b")
	result = rx.sub(result, "Tu", true)

	# Clean multiple blank lines
	while result.contains("\n\n\n"):
		result = result.replace("\n\n\n", "\n\n")
	result = result.strip_edges()

	if result.length() >= 10:
		current_card["text"] = result

	# --- FIX 34+37: Deduplicate + sanitize option labels ---
	var options: Array = current_card.get("options", [])
	if options.size() >= 2:
		var seen: Dictionary = {}
		var fallback_verbs: Array[String] = [
			"Explorer", "Fuir", "Grimper", "Creuser",
			"Soigner", "Briser", "Chanter", "Mediter", "Nager",
			"Siffler", "Gravir", "Plonger", "Negocier", "Traquer",
		]
		var fb_idx := 0
		for i in range(options.size()):
			var lbl: String = str(options[i].get("label", "")).strip_edges()
			# FIX 44: Normalize Unicode dashes to ASCII hyphen before checks
			lbl = lbl.replace("\u2010", "-").replace("\u2011", "-").replace("\u2012", "-").replace("\u2013", "-").replace("\u2014", "-")
			# FIX 53: Strip parentheses and brackets from labels, then re-strip edges
			lbl = lbl.replace("(", "").replace(")", "").replace("[", "").replace("]", "").strip_edges()
			if lbl.length() > 0:
				lbl = lbl[0].to_upper() + lbl.substr(1)
			options[i]["label"] = lbl
			var lbl_lower: String = lbl.to_lower()
			var needs_replace := false
			# FIX 37: Reject malformed labels
			if lbl.length() < 3:
				needs_replace = true
			elif lbl.contains(")") or lbl.contains("(") or lbl.contains(":"):
				needs_replace = true
			# FIX 39: Reject pronoun-suffixed labels (e.g. "Apaisét-tu")
			elif lbl.to_lower().ends_with("-tu") or lbl.to_lower().ends_with("-moi") \
					or lbl.to_lower().ends_with("-toi") or lbl.to_lower().ends_with("-nous") \
					or lbl.to_lower().ends_with("-vous") or lbl.to_lower().ends_with("-les") \
					or lbl.to_lower().ends_with("-la") or lbl.to_lower().ends_with("-le"):
				needs_replace = true
			# FIX 43: Reject truncated labels ending with dash (e.g. "Vise-")
			elif lbl.ends_with("-"):
				needs_replace = true
			elif lbl_lower in seen:
				needs_replace = true
			# Reject common nouns that aren't action verbs
			elif lbl_lower in ["l'air", "merveille", "chute", "parcours",
					"situation", "ombre", "lumiere", "silence", "nature",
					"foret", "chemin", "route", "pierre", "eau", "feu",
					"terre", "ciel", "nuit", "jour", "lune", "soleil",
					# FIX 41: Prompt structure words + invented suffixes
					"verbe", "force", "option", "choix", "action",
					"travaux", "travail",
					# FIX 45: Common nouns used as labels instead of verbs
					"vue", "lumieres", "lumières", "scene", "scène",
					"valuer", "titre", "merveille", "paradis",
					"complication", "introduction", "exploration",
					# FIX 48: More nouns seen in MC29
					"facette", "amour", "l'amour", "silence",
					"lumiere", "lumière", "ombre", "sentier",
					# FIX 51: Nouns seen in MC33
					"voyage", "recherche", "aventure", "mystere",
					"mystère", "destin", "histoire", "legende",
					"légende", "vision", "memoire", "mémoire",
					# FIX 53: Nouns seen in MC35
					"danger", "courage", "combat", "fuite",
					"secret", "enigme", "énigme", "tresor",
					"trésor", "refuge", "passage", "sentier",
					# FIX 54: Character/role nouns seen in MC36
					"guerrier", "guerriere", "guerrière",
					"druide", "chasseur", "voyageur",
					"gardien", "sorcier", "esprit",
					# FIX 55: English words + adjectives as labels
					"run", "fight", "hide", "go",
					"première", "premier", "dernière", "dernier",
					"ancienne", "ancien"]:
				needs_replace = true
			if needs_replace:
				while fb_idx < fallback_verbs.size():
					var fb_lower: String = fallback_verbs[fb_idx].to_lower()
					fb_idx += 1
					if fb_lower not in seen:
						options[i]["label"] = fallback_verbs[fb_idx - 1]
						seen[fb_lower] = true
						break
			else:
				seen[lbl_lower] = true


# ═══════════════════════════════════════════════════════════════════════════════
# CRITICAL CHOICE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _detect_critical_choice() -> void:
	## Called when displaying a new card. Sets _is_critical_choice.
	_is_critical_choice = false
	if _critical_used or _cards_this_run < 3:
		return

	# Karma extreme → higher chance
	if _karma >= 6 and randf() < 0.4:
		_is_critical_choice = true
	elif _karma <= -6 and randf() < 0.5:
		_is_critical_choice = true
	# Random 15%
	elif randf() < 0.15:
		_is_critical_choice = true

	if _is_critical_choice:
		_critical_used = true
		print("[Merlin] CRITICAL CHOICE detected!")
		SFXManager.play("critical_alert")
		if ui and is_instance_valid(ui):
			ui.show_critical_badge()

	# Show modifier badge if card has a modifier
	_show_card_modifier_indicator()


func _show_card_modifier_indicator() -> void:
	## Show badge for card modifiers (chance, ogham, nocturne, saisonnier).
	if not ui or not is_instance_valid(ui):
		return
	var modifier_name: String = str(current_card.get("modifier", ""))
	if modifier_name.is_empty():
		return
	if ui.has_method("show_modifier_badge"):
		ui.show_modifier_badge(modifier_name)
	if modifier_name == "chance":
		SFXManager.play("dice_shake")
		print("[Merlin] Chance modifier active! Minigame: %s" % str(current_card.get("minigame", "")))
	elif modifier_name == "nocturne":
		print("[Merlin] Nocturne modifier active!")


func _apply_chance_modifier_effects(effects: Array, outcome: String) -> Array:
	## Chance modifier: double positive effects on success, add penalty on failure.
	var is_success: bool = outcome == "success" or outcome == "critical_success"
	if is_success:
		var result: Array = []
		for e in effects:
			var eff: Dictionary = e.duplicate() if e is Dictionary else {}
			var etype: String = str(eff.get("type", ""))
			if etype == "HEAL_LIFE" or etype == "ADD_REPUTATION":
				eff["amount"] = int(eff.get("amount", 0)) * 2
			result.append(eff)
		print("[Merlin] Chance modifier: doubled positive effects (success)")
		return result
	else:
		var result: Array = effects.duplicate()
		result.append({"type": "DAMAGE_LIFE", "amount": 8})
		print("[Merlin] Chance modifier: added penalty (failure)")
		return result


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME PASSIVES
# ═══════════════════════════════════════════════════════════════════════════════

func _auto_progress_mission(outcome: String) -> void:
	## Auto-progress the run mission based on card outcomes (Phase 43).
	if not store:
		return
	var mission: Dictionary = store.get_mission()
	var mission_type: String = str(mission.get("type", ""))
	if mission_type.is_empty():
		return

	var step: int = 0
	match mission_type:
		"survive":
			# Progress +1 per card played (survive N cards)
			step = 1
		"equilibre":
			# Progress +1 if all aspects balanced after this card
			if store.is_all_aspects_balanced():
				step = 1
		"explore":
			# Progress +1 per success/crit_success
			if outcome == "success" or outcome == "critical_success":
				step = 1
		"artefact":
			# Progress +1 on critical success only
			if outcome == "critical_success":
				step = 1

	if step > 0:
		store.dispatch({"type": "PROGRESS_MISSION", "step": step})


func _check_biome_passive() -> void:
	if not store or not store.biomes:
		return
	var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
	if biome_key.is_empty():
		return
	if store.biomes.has_method("should_trigger_passive") and store.biomes.should_trigger_passive(biome_key, _cards_this_run):
		var passive: Dictionary = store.biomes.get_passive_effect(biome_key, _cards_this_run) if store.biomes.has_method("get_passive_effect") else {}
		if not passive.is_empty():
			print("[Merlin] Biome passive triggered: %s" % str(passive))
			var passive_type: String = str(passive.get("type", ""))
			if passive_type.contains("HEAL"):
				store.dispatch({"type": "HEAL_LIFE", "amount": int(passive.get("amount", 5))})
			else:
				store.dispatch({"type": "DAMAGE_LIFE", "amount": int(passive.get("amount", 5))})
			if ui and is_instance_valid(ui):
				ui.show_biome_passive(passive)



# ═══════════════════════════════════════════════════════════════════════════════
# NARRATIVE REACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _play_outcome_sfx(outcome: String) -> void:
	match outcome:
		"critical_success": SFXManager.play("dice_crit_success")
		"success": SFXManager.play("aspect_up")
		"failure": SFXManager.play("aspect_down")
		"critical_failure": SFXManager.play("dice_crit_fail")


# ═══════════════════════════════════════════════════════════════════════════════
# RUN REWARDS
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_run_rewards(ending: Dictionary) -> void:
	if not store or not store.has_method("calculate_run_rewards"):
		return
	var run_data := {
		"victory": ending.get("victory", false),
		"minigames_won": _minigames_won,
		"score": ending.get("score", 0),
		"cards_played": _cards_this_run,
	}
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	store.apply_run_rewards(rewards)
	# Attach rewards to ending for end screen display
	ending["rewards"] = rewards
	print("[Merlin] Rewards applied: %s" % str(rewards))


# ═══════════════════════════════════════════════════════════════════════════════
# RAG CONTEXT (persistent cross-card)
# ═══════════════════════════════════════════════════════════════════════════════

func _write_context_entry(entry: String) -> void:
	## Write choice history to file for RAG context injection.
	var existing: String = ""
	if FileAccess.file_exists(CONTEXT_FILE):
		var f := FileAccess.open(CONTEXT_FILE, FileAccess.READ)
		if f:
			existing = f.get_as_text()
			f.close()
	var lines: PackedStringArray = existing.split("\n", false)
	lines.append("[%d] %s" % [_cards_this_run, entry])
	if lines.size() > CONTEXT_MAX_ENTRIES:
		lines = lines.slice(-CONTEXT_MAX_ENTRIES)
	var fw := FileAccess.open(CONTEXT_FILE, FileAccess.WRITE)
	if fw:
		fw.store_string("\n".join(lines))
		fw.close()


func _use_skill(skill_id: String) -> void:
	"""Activate a skill."""
	if skill_id.strip_edges().is_empty():
		return
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "USE_SKILL",
		"skill_id": skill_id,
		"card": current_card,
	})
	var result: Dictionary = raw_result if raw_result is Dictionary else {"ok": false, "error": "invalid_result"}

	if not result.get("ok", false):
		return

	# Handle skill result
	var skill_type := str(result.get("type", ""))
	match skill_type:
		"reveal_one", "reveal_all":
			# Show hidden effects on option buttons
			var options: Array = current_card.get("options", [])
			if ui and is_instance_valid(ui) and ui.has_method("show_reveal_effects"):
				if skill_type == "reveal_all":
					ui.show_reveal_effects(options, -1)
				else:
					# Reveal center option (most valuable info)
					ui.show_reveal_effects(options, 1)
		"reroll_card", "full_reroll":
			if not is_processing:
				_request_next_card()
		_:
			# Other skills just update state
			_sync_ui_with_state()


# ═══════════════════════════════════════════════════════════════════════════════
# UI SYNCHRONIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _sync_ui_with_state() -> void:
	"""Sync UI with current store state."""
	if not ui or not is_instance_valid(ui) or not store or not is_instance_valid(store):
		return

	# Life essence (Phase 43)
	var life: int = store.get_life_essence() if store.has_method("get_life_essence") else MerlinConstants.LIFE_ESSENCE_START
	if ui.has_method("update_life_essence"):
		ui.update_life_essence(life)

	# Mission
	var mission: Dictionary = store.get_mission() if store.has_method("get_mission") else {}
	ui.update_mission(mission)

	# Cards count
	var cards_played: int = store.get_cards_played() if store.has_method("get_cards_played") else 0
	ui.update_cards_count(cards_played)

	# Biome indicator
	var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
	if not biome_key.is_empty() and store.biomes:
		ui.update_biome_indicator(store.biomes.get_biome_name(biome_key), store.biomes.get_biome_color(biome_key))

	# Resource bar (tool + day + mission progress)
	var run: Dictionary = store.state.get("run", {})
	var tool_id: String = str(run.get("tool", ""))
	var day: int = int(run.get("day", 1))
	var mission_data: Dictionary = run.get("mission", {})
	var m_current: int = int(mission_data.get("progress", 0))
	var m_total: int = int(mission_data.get("target", 0))
	var essences_collected: int = int(run.get("essences_collected", 0))
	if ui.has_method("update_resource_bar"):
		ui.update_resource_bar(tool_id, day, m_current, m_total, essences_collected)
	if ui.has_method("update_essences_collected"):
		ui.update_essences_collected(essences_collected)


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Store
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_changed(_state: Dictionary) -> void:
	_sync_ui_with_state()
	# B.1 — Sync perk badge when state changes
	if ui and is_instance_valid(ui) and ui.has_method("update_selected_perk") and store:
		var selected_perk: String = str(store.state.get("run", {}).get("perks", {}).get("selected_perk", ""))
		ui.update_selected_perk(selected_perk)





func _on_life_changed(old_value: int, new_value: int) -> void:
	if ui and ui.has_method("update_life_essence"):
		ui.update_life_essence(new_value)
	if new_value < old_value:
		SFXManager.play("aspect_down")
		print("[Merlin] Life essence: %d → %d" % [old_value, new_value])
		if new_value <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and new_value > 0:
			print("[Merlin] WARNING: Life essence low!")
	elif new_value > old_value:
		SFXManager.play("ogham_chime")


func _on_run_ended(ending: Dictionary) -> void:
	print("[Merlin] _on_run_ended signal received")
	ending["story_log"] = _quest_history.duplicate()
	# Archive run in RAG cross-run memory
	if merlin_ai and is_instance_valid(merlin_ai) and merlin_ai.get("rag_manager"):
		var ending_title: String = ending.get("ending", {}).get("title", "")
		merlin_ai.rag_manager.summarize_and_archive_run(ending_title, store.state if store else {})

	# Auto-save meta state
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("save_to_slot"):
		gm.save_to_slot(1)

	# Show end screen
	if ui and is_instance_valid(ui):
		ui.show_end_screen(ending)


func _on_mission_progress(step: int, total: int) -> void:
	if ui:
		var mission = store.get_mission()
		ui.update_mission(mission)

	if step >= total and total > 0:
		print("[Merlin] Mission complete!")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — UI
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_chosen(option: int) -> void:
	_resolve_choice(option)


func _on_pause_requested() -> void:
	if get_tree().paused:
		if ui and is_instance_valid(ui) and ui.has_method("hide_pause_menu"):
			ui.hide_pause_menu()
		get_tree().paused = false
	else:
		get_tree().paused = true
		if ui and is_instance_valid(ui) and ui.has_method("show_pause_menu"):
			ui.show_pause_menu()


func _on_merlin_dialogue_requested(player_input: String) -> void:
	## Player talks to Merlin — generate LLM response, display in bubble, log to RAG.
	if is_processing:
		return
	is_processing = true
	print("[Merlin] Dialogue: player asks '%s'" % player_input)

	# Show thinking state
	if ui:
		ui.show_merlin_thinking_overlay()

	# Build context from current game state
	var context := player_input
	if store:
		var state: Dictionary = store.get_state()
		var life: int = state.get("life_essence", 100)
		context = "Le voyageur demande: %s\n(Vie=%d)" % [player_input, life]

	# Generate response via MerlinOmniscient
	var response: String = ""
	var mos: MerlinOmniscient = store.get_merlin() if store else null
	if mos and mos.has_method("get_merlin_comment"):
		response = await mos.get_merlin_comment(context)

	if response.is_empty():
		response = "Les pierres murmurent... mais je n'entends pas clairement. Repose ta question, voyageur."

	# Hide thinking, show response
	if ui:
		ui.hide_merlin_thinking_overlay()
		ui.show_merlin_dialogue_response(response)

	# Log to RAG context
	_write_context_entry("Dialogue: %s -> %s" % [player_input, response.left(80)])
	is_processing = false


func _on_journal_requested() -> void:
	## Open the visual journal of past lives (P3.20.3).
	if not store or not is_instance_valid(store):
		return
	var mos: MerlinOmniscient = store.get_merlin() if store.has_method("get_merlin") else null
	var run_summaries: Array[Dictionary] = []
	if mos and mos.rag_manager and mos.rag_manager.has_method("get_run_summaries_for_journal"):
		run_summaries = mos.rag_manager.get_run_summaries_for_journal()
	if run_summaries.is_empty():
		# No past runs — show a message via bubble
		if ui and is_instance_valid(ui) and ui.has_method("show_merlin_dialogue_response"):
			ui.show_merlin_dialogue_response("Tu n'as pas encore vecu de vies anterieures, voyageur. Ton histoire commence ici.")
		return
	if ui and is_instance_valid(ui) and ui.has_method("show_journal_popup"):
		ui.show_journal_popup(run_summaries)


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Ogham Wheel
# ═══════════════════════════════════════════════════════════════════════════════

func _on_ogham_selected(skill_id: String) -> void:
	_use_ogham(skill_id)


func _use_ogham(skill_id: String) -> void:
	"""Activate an Ogham skill via the store."""
	if skill_id.strip_edges().is_empty():
		return
	_try_tutorial("first_ogham_used")
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "USE_OGHAM",
		"skill_id": skill_id,
		"card": current_card,
	})
	var result: Dictionary = raw_result if raw_result is Dictionary else {"ok": false, "error": "invalid_result"}

	if result.get("ok", false):
		_sync_ui_with_state()


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL SYSTEM — Diegetic narrative hints (P3.19)
# ═══════════════════════════════════════════════════════════════════════════════

func _load_tutorial_data() -> void:
	## Load tutorial narratives from JSON. Silent fail if missing.
	var path := "res://data/ai/tutorial_narratives.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_tutorial_data = json.data.get("mechanics", {})
	file.close()


func _try_tutorial(trigger_key: String) -> void:
	## Show a diegetic tutorial hint via Merlin bubble if not already shown.
	## Non-blocking — shows as a brief overlay and returns immediately.
	if _tutorial_shown.get(trigger_key, false):
		return
	if _tutorial_data.is_empty():
		return

	# Find matching mechanic by trigger key
	var entry: Dictionary = {}
	for key in _tutorial_data:
		var mech: Dictionary = _tutorial_data[key]
		if mech is Dictionary and str(mech.get("trigger", "")) == trigger_key:
			entry = mech
			break
	if entry.is_empty():
		return

	_tutorial_shown[trigger_key] = true
	var text: String = str(entry.get("text", ""))
	if text.is_empty():
		return

	print("[TUTORIAL] Showing hint: %s" % trigger_key)
	# Show via Merlin bubble (non-blocking, auto-dismiss)
	if ui and is_instance_valid(ui) and ui.has_method("show_merlin_dialogue_response"):
		ui.show_merlin_dialogue_response(text)


# ═══════════════════════════════════════════════════════════════════════════════
# VISION PERK HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _check_vision_perk_auto_reveal() -> void:
	## Auto-reveal option effects if a talent grants vision.
	## Currently: no talent provides this. Stub kept for future use.
	pass


func _exit_tree() -> void:
	## Cleanup to prevent dangling coroutines on scene change.
	is_processing = false
