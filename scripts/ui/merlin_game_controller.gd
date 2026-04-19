## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Game Controller — Store-UI Bridge (v2.0.0 — Modular Refactor)
## ═══════════════════════════════════════════════════════════════════════════════
## Full gameplay controller: delegates to focused modules for text processing,
## LLM integration, effects/mechanics, minigames, and signal handling.
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
var is_busy := false
var _intro_shown := false
var _cards_this_run := 0
const LLM_TIMEOUT_SEC := 360.0

# ═══════════════════════════════════════════════════════════════════════════════
# MODULES
# ═══════════════════════════════════════════════════════════════════════════════

var _text_processor: GameControllerTextProcessor
var _llm: GameControllerLLM
var _effects: GameControllerEffects
var _minigame_runner: GameControllerMinigame
var _signals: GameControllerSignals

# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE (reset each start_run)
# ═══════════════════════════════════════════════════════════════════════════════

var headless_mode := false
@export var dev_biome_override: String = ""

var _karma: int = 0
var _blessings: int = 0
var _quest_history: Array = []
var _is_critical_choice := false
var _critical_used := false
var _minigames_won: int = 0
var _free_center_remaining: int = 0
var _shield_corps_used := false
var _shield_monde_used := false

# Dynamic difficulty
var _dynamic_modifier: int = 0
var _cards_since_rule_check: int = 0

# Card buffer for smooth gameplay
var _card_buffer: Array[Dictionary] = []
const BUFFER_SIZE := 5

# Prerun choice tracking for sequel cards
var _prerun_choices: Array[Dictionary] = []

# Dream system
var _last_biome: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN INTRO SPEECH TEMPLATES (contextual biome + season)
# ═══════════════════════════════════════════════════════════════════════════════

const _BIOME_DISPLAY_NAMES: Dictionary = {
	"foret_broceliande": "la foret de Broceliande",
	"villages_celtes": "les villages celtes",
	"cotes_sauvages": "les cotes sauvages",
	"landes_bruyere": "les landes de bruyere",
	"marais_korrigans": "les marais des Korrigans",
	"cercles_pierres": "les cercles de pierres",
	"collines_dolmens": "les collines aux dolmens",
	"iles_mystiques": "les iles mystiques",
}

const _MERLIN_INTRO_SPEECHES: Array[String] = [
	"Les brumes de %s s'ouvrent devant toi, voyageur... Le terminal a capte des echos anciens.",
	"Merlin scrute %s a travers le cristal... Les chemins se dessinent, mais lequel choisiras-tu?",
	"Le cristal revele les sentiers de %s... Quelque chose t'attend au-dela du voile.",
	"Ah, %s... Les pierres murmurent ici des verites que peu osent entendre.",
	"Les runes pulsent et %s se devoile... Merlin sent le poids du destin, voyageur.",
]

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

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Initialize modules
	_text_processor = GameControllerTextProcessor.new()
	_llm = GameControllerLLM.new(self)
	_effects = GameControllerEffects.new()
	_minigame_runner = GameControllerMinigame.new(self)
	_signals = GameControllerSignals.new(self)

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

	_signals.connect_signals()
	_signals.load_tutorial_data()

	# Auto-start run after a frame so UI is fully ready
	await get_tree().process_frame
	await start_run()


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(seed_value: int = -1) -> void:
	## Start a new Merlin run with narrator intro.
	var _t0 := Time.get_ticks_msec()
	print("[Merlin] start_run() called at t=%d" % _t0)
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system())

	# Reset run-local state
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
	_llm.load_prerun_cards(_card_buffer)

	if not store:
		push_error("[Merlin] store is null in start_run, aborting")
		return

	# Apply talent bonuses at run start
	var talent_result: Dictionary = _effects.apply_talent_bonuses(store)
	_free_center_remaining = int(talent_result.get("free_center", 0))
	_blessings = int(talent_result.get("blessings", 0))

	# Read biome from GameManager run data
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
		biome_key = dev_biome_override
		print("[Merlin] dev_biome_override actif: %s" % biome_key)

	# Apply biome CRT profile
	MerlinVisual.apply_biome_crt(biome_key)

	# Start biome music
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
		_signals.sync_ui_with_state()
	if ui and is_instance_valid(ui) and ui.has_method("reset_run_visuals"):
		ui.reset_run_visuals()

	# Pre-run: generate skeleton graph + show parchment display
	if not headless_mode:
		await _generate_and_show_parchment(biome_key)

	# Opening sequence then narrator intro before first card
	if ui and is_instance_valid(ui) and not headless_mode:
		if ui.has_method("show_opening_sequence"):
			await ui.show_opening_sequence(biome_key, season_hint, hour_hint)
		await ui.show_narrator_intro(biome_key)
		_intro_shown = true
		# Scenario-specific intro
		if store and store.has_method("get_scenario_manager"):
			var scenario_mgr = store.get_scenario_manager()
			if scenario_mgr and scenario_mgr.is_scenario_active():
				var intro_data: Dictionary = scenario_mgr.get_dealer_intro_override()
				var intro_ctx: String = str(intro_data.get("context", ""))
				var intro_title: String = str(intro_data.get("title", ""))
				if not intro_ctx.is_empty() and ui and is_instance_valid(ui):
					await ui.show_scenario_intro(intro_title, intro_ctx)

		# Merlin contextual speech
		var merlin_speech: String = _llm.build_merlin_intro_speech(
			biome_key, season_hint, _BIOME_DISPLAY_NAMES,
			_MERLIN_INTRO_SPEECHES, _SEASON_FLAVOR)
		if not merlin_speech.is_empty() and ui.has_method("show_narrator_text"):
			await ui.show_narrator_text(merlin_speech)
		elif not merlin_speech.is_empty():
			print("[Merlin] Merlin speech: %s" % merlin_speech)

		# Progressive reveal of indicators
		if ui.has_method("show_progressive_indicators"):
			await ui.show_progressive_indicators()
		if ui.has_method("start_ambient_vfx"):
			ui.start_ambient_vfx(biome_key)
		print("[Merlin] narrator intro finished, requesting first card (dt=%dms)" % (Time.get_ticks_msec() - _t0))
	elif headless_mode:
		_intro_shown = true
		print("[Merlin] headless mode — skipped narrator intro (dt=%dms)" % (Time.get_ticks_msec() - _t0))

	# Verify card buffer before first card
	var buffer_ready: bool = await _llm.ensure_card_buffer_ready(_card_buffer, store, get_tree())
	if buffer_ready:
		print("[Merlin] Deck ready: %d cards buffered" % _card_buffer.size())
	else:
		print("[Merlin] Card buffer empty, LLM will generate on demand")
		if ui and is_instance_valid(ui) and ui.has_method("show_merlin_thinking_overlay"):
			ui.show_merlin_thinking_overlay()
			if is_inside_tree():
				await get_tree().create_timer(1.5).timeout
			if ui and is_instance_valid(ui) and ui.has_method("hide_merlin_thinking_overlay"):
				ui.hide_merlin_thinking_overlay()

	# Get first card
	print("[Merlin] start_run() about to await _request_next_card (dt=%dms)" % (Time.get_ticks_msec() - _t0))
	await _request_next_card()
	print("[Merlin] start_run() _request_next_card complete (dt=%dms)" % (Time.get_ticks_msec() - _t0))


## Parchment display reference (created once, reused).
var _parchment: ParchmentDisplay = null


func _generate_and_show_parchment(biome_key: String) -> void:
	## Generate the run skeleton graph and show the parchment animation.
	var t0: int = Time.get_ticks_msec()
	print("[Merlin] Generating run skeleton for biome=%s" % biome_key)

	# Gather state for generation.
	var game_state: Dictionary = store.state.get("meta", {}) if store else {}
	var ogham_id: String = str(store.state.get("run", {}).get("ogham_actif", "")) if store else ""
	var save_data: Dictionary = {}
	if store and store.has_method("get_save_data"):
		save_data = store.get_save_data()

	# Get MOS reference for LLM generation.
	var mos: MerlinOmniscient = null
	if store and store.has_method("get_mos"):
		mos = store.get_mos()

	var graph: MerlinRunGraph = null
	if mos:
		graph = await mos.generate_run_skeleton(biome_key, ogham_id, game_state, save_data)
	else:
		# Fallback: procedural generation without LLM.
		print("[Merlin] No MOS available, using procedural skeleton")
		graph = MerlinSkeletonGenerator._generate_procedural(
			MerlinSkeletonGenerator._build_context(biome_key, ogham_id, game_state, save_data))

	if graph == null:
		print("[Merlin] Skeleton generation failed, proceeding without graph")
		return

	# Store the graph in run state.
	if store:
		await store.dispatch({"type": "SET_RUN_GRAPH", "graph": graph.to_dict()})

	print("[Merlin] Skeleton ready in %dms: %d main + %d detour nodes" % [
		Time.get_ticks_msec() - t0, graph.total_main_nodes, graph.total_detour_nodes])

	# Show parchment display.
	if ui and is_instance_valid(ui):
		if _parchment == null:
			_parchment = ParchmentDisplay.new()
			ui.add_child(_parchment)
		_parchment.reveal(graph)
		await _parchment.animation_finished
		await _parchment.dismiss()
		print("[Merlin] Parchment display finished (dt=%dms)" % (Time.get_ticks_msec() - t0))


func _request_next_card() -> void:
	## Get and display the next card (LLM or fallback).
	var _rnc_t0 := Time.get_ticks_msec()
	print("[Merlin] _request_next_card() called at t=%d, is_busy=%s" % [_rnc_t0, str(is_busy)])
	if is_busy:
		return
	if not is_inside_tree():
		print("[Merlin] not inside tree, aborting _request_next_card")
		return
	if not store:
		push_error("[Merlin] store is null in _request_next_card")
		return

	is_busy = true
	_cards_this_run += 1

	# Step 1. Life drain BEFORE card (bible s.13.3: "1.DRAIN -1")
	if store and is_instance_valid(store):
		await store.dispatch({"type": "DAMAGE_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD})
		if store.get_life_essence() <= 0:
			print("[Merlin] Player died from life drain at card %d" % _cards_this_run)
			is_busy = false
			store.dispatch({"type": "END_RUN"})
			return

	# Tutorial: first card ever
	if _cards_this_run == 1:
		_signals.try_tutorial("first_card_ever")

	# Check power milestones
	_effects.check_power_milestone(_cards_this_run, store, ui)

	# Fast path: consume from pre-generated card buffer
	if not _card_buffer.is_empty():
		current_card = _card_buffer.pop_front()
		print("[Merlin] Using pre-generated card (%d remaining)" % _card_buffer.size())
		_handle_card_display()
		is_busy = false
		return

	# Sequel card: ~30% chance after prerun buffer exhausted
	if _card_buffer.is_empty() and not _prerun_choices.is_empty() and randf() < 0.30:
		var sequel_card: Dictionary = await _llm.try_sequel_card()
		if not sequel_card.is_empty():
			current_card = sequel_card
			print("[Merlin] Sequel card generated from prerun choice")
			_handle_card_display()
			is_busy = false
			return

	# Fast path: try consuming prefetched card
	if store and store.has_method("get_merlin"):
		var merlin_mos = store.get_merlin()
		if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
			var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
			if not prefetched.is_empty():
				print("[Merlin] Using prefetched card (fast path)")
				current_card = prefetched
				_handle_card_display()
				is_busy = false
				return

	# Show thinking animation while LLM generates
	print("[Merlin] show_thinking (dt=%dms)" % (Time.get_ticks_msec() - _rnc_t0))
	if ui and is_instance_valid(ui):
		ui.show_thinking()

	# Direct await dispatch
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
		is_busy = false
		return

	if not result.get("ok", false) or result.get("card", {}).is_empty():
		# Dispatch failed — use FastRoute fallback immediately
		print("[Merlin] dispatch failed, using FastRoute fallback (dt=%dms)" % dispatch_elapsed)
		var fr_card: Dictionary = _get_fastroute_card()
		if not fr_card.is_empty():
			current_card = fr_card
			print("[Merlin] FastRoute card loaded: %s" % str(fr_card.get("title", "")))
			_handle_card_display()
			is_busy = false
			return
		# FastRoute also empty — retry LLM as last resort
		print("[Merlin] FastRoute empty, retrying LLM")
		var retry_card: Dictionary = await _llm.retry_llm_generation(1)
		if retry_card.is_empty():
			await get_tree().create_timer(3.0).timeout
			is_busy = false
			await _request_next_card()
			return
		current_card = retry_card
		_handle_card_display()
		is_busy = false
		return

	print("[Merlin] card dispatch result ok=%s (dt=%dms)" % [str(result.get("ok", false)), Time.get_ticks_msec() - _rnc_t0])
	if result.get("ok", false):
		current_card = result.get("card", {})
		# Validate card has valid options array (size 3)
		var opts = current_card.get("options", [])
		if current_card.is_empty() or not opts is Array or opts.size() < 3:
			print("[Merlin] card malformed (options=%s), retrying LLM" % str(opts.size() if opts is Array else "missing"))
			var retry_card: Dictionary = await _llm.retry_llm_generation(2)
			if not retry_card.is_empty():
				current_card = retry_card
			else:
				is_busy = false
				await _request_next_card()
				return
		# NPC encounter: 15% chance after card 5
		if _cards_this_run > 5 and randf() < 0.15:
			var npc_card: Dictionary = await _llm.try_npc_encounter(store)
			if not npc_card.is_empty():
				current_card = npc_card
				print("[Merlin] NPC encounter triggered: %s" % npc_card.get("speaker", "?"))
		_handle_card_display()
	else:
		# Store dispatch failed — retry via direct LLM
		print("[Merlin] store dispatch failed, trying direct LLM retry")
		var llm_card: Dictionary = await _llm.retry_llm_generation(3)
		if llm_card.is_empty():
			if ui and is_instance_valid(ui):
				ui.show_merlin_thinking_overlay()
			await get_tree().create_timer(3.0).timeout
			if ui and is_instance_valid(ui):
				ui.hide_merlin_thinking_overlay()
			is_busy = false
			await _request_next_card()
			return
		current_card = llm_card
		_handle_card_display()
		_check_vision_perk_auto_reveal()

	print("[Merlin] _request_next_card() done (dt=%dms)" % (Time.get_ticks_msec() - _rnc_t0))
	is_busy = false


func _get_fastroute_card() -> Dictionary:
	## Pull a card from FastRoute pool when LLM fails.
	if not store or not is_instance_valid(store):
		return {}
	var meta: Dictionary = store.state.get("meta", {})
	var context: Dictionary = {
		"biome": store.state.get("biome", "broceliande"),
		"card_index": _cards_this_run,
		"faction_rep": meta.get("faction_rep", {}),
	}
	return store.cards.get_fastroute_card(context)


func _handle_card_display() -> void:
	## Common card display pipeline: detect critical, post-process text, show in UI.
	_detect_critical_choice()
	_text_processor.post_process_card_text(current_card)
	if ui and is_instance_valid(ui):
		ui.display_card(current_card)
	_check_vision_perk_auto_reveal()


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════════

func _resolve_choice(option: int) -> void:
	## Full resolution: choice -> minigame score -> resolve_card() -> effects -> travel -> next.
	if is_busy or current_card.is_empty():
		return
	if not store or not is_instance_valid(store):
		push_error("[Merlin] store invalid in _resolve_choice")
		return
	if not is_inside_tree():
		return

	is_busy = true
	var direction: String = ["left", "center", "right"][clampi(option, 0, 2)]
	var choice_label: String = _effects.get_choice_label(option, current_card)
	print("[Merlin] _resolve_choice option=%d direction=%s" % [option, direction])

	# 1. Get the selected option's pre-annotated minigame field
	var options_arr: Array = current_card.get("options", [])
	var selected_opt: Dictionary = options_arr[clampi(option, 0, options_arr.size() - 1)] if option < options_arr.size() else {}
	var mg_field: String = str(selected_opt.get("field", "esprit"))
	var mg_field_raw = current_card.get("minigame", "")
	var forced_field: String = ""
	if mg_field_raw is Dictionary:
		forced_field = str(mg_field_raw.get("id", ""))
	elif mg_field_raw is String:
		forced_field = mg_field_raw
	if not forced_field.is_empty():
		mg_field = forced_field

	SFXManager.play("card_draw")

	# 2. Run minigame or use fixed score in headless
	var score: int = 0
	if headless_mode:
		score = 75
	else:
		_signals.try_tutorial("first_minigame")
		score = await _minigame_runner.run_minigame(mg_field, _is_critical_choice)

	if not is_inside_tree():
		is_busy = false
		return

	# 3. Resolve card via MerlinCardSystem
	var run_state: Dictionary = store.state.get("run", {})
	var resolve_result: Dictionary = store.cards.resolve_card(run_state, current_card, option, score)
	var outcome: String = resolve_result.get("multiplier_label", "reussite_partielle")
	var modulated: Array = resolve_result.get("effects", [])
	print("[Merlin] score=%d -> %s (x%.2f)" % [score, outcome, float(resolve_result.get("multiplier", 1.0))])

	# 4. SFX for outcome
	if not headless_mode:
		_effects.play_outcome_sfx_score(score)

	# 5. Dramatic pause
	if not headless_mode and is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# 6. Show minigame score + multiplier label
	if not headless_mode and ui and is_instance_valid(ui) and ui.has_method("show_minigame_result"):
		ui.show_minigame_result(score, outcome)

	# 7. Apply talent shields
	var shield_result: Dictionary = _effects.apply_talent_shields(modulated, store, _shield_corps_used)
	modulated = shield_result.get("effects", modulated)
	_shield_corps_used = shield_result.get("shield_corps_used", _shield_corps_used)

	# 8. Dispatch to store
	var result = await store.dispatch({
		"type": "RESOLVE_CHOICE",
		"card": current_card,
		"option": option,
		"modulated_effects": modulated,
		"outcome": outcome,
	})
	if result == null:
		result = {"ok": false}

	# 9. Update karma
	var karma_result: Dictionary = _effects.update_karma_score(score, direction, _karma)
	_karma = karma_result.get("karma", _karma)
	_blessings = mini(_blessings + karma_result.get("blessings_delta", 0), GameControllerEffects.BLESSINGS_MAX)

	# 10. Record quest history
	_quest_history.append({"card_idx": _cards_this_run, "choice": direction, "outcome": outcome, "score": score})

	# 12a. Track prerun choices for sequel cards
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

	# 12b. Scenario anchor resolution
	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var anchor_id: String = str(current_card.get("anchor_id", ""))
			if not anchor_id.is_empty():
				scenario_mgr.resolve_anchor(anchor_id, option)
				var sc_flags: Dictionary = scenario_mgr.get_scenario_flags()
				for flag_key in sc_flags:
					store.dispatch({"type": "APPLY_EFFECTS", "effects": ["SET_FLAG:%s:%s" % [flag_key, str(sc_flags[flag_key])]], "source": "scenario"})

	# 12c. Auto-progress mission
	_effects.auto_progress_mission(outcome, store)

	# 13. Biome passive check
	_effects.check_biome_passive(store, _cards_this_run, ui)

	# 13b. Prefetch next card NOW (state is fully updated)
	_llm.trigger_prefetch(store)

	# 14. Narrative result text
	var _result_shown := false
	if not headless_mode and ui and is_instance_valid(ui) and current_card.size() > 0:
		var result_key: String = "result_success" if outcome.begins_with("reussite") else "result_failure"
		var result_text := ""
		var opts_for_result: Array = current_card.get("options", [])
		if option < opts_for_result.size() and opts_for_result[option] is Dictionary:
			var chosen_opt: Dictionary = opts_for_result[option]
			result_text = str(chosen_opt.get(result_key, ""))
		if result_text.is_empty():
			result_text = str(current_card.get(result_key, ""))
		if not result_text.is_empty():
			await ui.show_result_text_transition(result_text, outcome)
			_result_shown = true

	# 15. Card outcome animation
	if not headless_mode and ui and is_instance_valid(ui):
		ui.animate_card_outcome(outcome)

	# 15b. Show life delta flash
	var life_delta: int = 0
	for eff in modulated:
		if eff is Dictionary:
			if str(eff.get("type", "")) == "DAMAGE_LIFE":
				life_delta -= abs(int(eff.get("amount", 0)))
			elif str(eff.get("type", "")) == "HEAL_LIFE":
				life_delta += int(eff.get("amount", 0))
	if not headless_mode and ui and is_instance_valid(ui) and ui.has_method("show_life_delta"):
		ui.show_life_delta(life_delta)

	# Wait for player to see reaction
	if not headless_mode:
		if not is_inside_tree():
			is_busy = false
			return
		await get_tree().create_timer(3.0).timeout

	# 16. Check run end
	if result.get("ok", false) and result.get("run_ended", false):
		print("[Merlin] run ended!")
		var ending = result.get("ending", {})
		ending["story_log"] = _quest_history.duplicate()
		_effects.apply_run_rewards(ending, store, _minigames_won, _cards_this_run)
		if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
			ui.mark_card_completed()
		if not headless_mode and ui and is_instance_valid(ui):
			ui.show_end_screen(ending)
		is_busy = false
		return

	# 17. Travel animation -> next card
	_signals.sync_ui_with_state()
	if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
		ui.mark_card_completed()
	current_card = {}
	if not headless_mode and ui and is_instance_valid(ui):
		await ui.show_travel_animation("Le sentier continue...")
	elif not headless_mode and is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# 17b. Dream sequence on biome change
	if not headless_mode and store and is_instance_valid(store):
		var current_biome: String = str(store.state.get("run", {}).get("current_biome", ""))
		if not current_biome.is_empty() and not _last_biome.is_empty() and current_biome != _last_biome:
			_signals.try_tutorial("first_biome_change")
			var mos: MerlinOmniscient = store.get_merlin() if store.has_method("get_merlin") else null
			if mos and mos.has_method("generate_dream"):
				var dream_text: String = await mos.generate_dream(store.state)
				if not dream_text.is_empty() and ui and is_instance_valid(ui) and ui.has_method("show_dream_overlay"):
					await ui.show_dream_overlay(dream_text)
					_signals.write_context_entry("Reve: %s" % dream_text.left(80), _cards_this_run)
		_last_biome = current_biome

	# 18. Write RAG context
	_signals.write_context_entry("Choix: %s (%s, score=%d)" % [choice_label, outcome, score], _cards_this_run)

	# 18b. Dynamic difficulty check
	_cards_since_rule_check += 1
	if _cards_since_rule_check >= GameControllerEffects.RULE_CHECK_INTERVAL:
		_cards_since_rule_check = 0
		_dynamic_modifier = _effects.update_dynamic_difficulty(store, _dynamic_modifier)

	# 19. Next card
	is_busy = false
	await _request_next_card()


# ═══════════════════════════════════════════════════════════════════════════════
# CRITICAL CHOICE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func _detect_critical_choice() -> void:
	## Called when displaying a new card. Sets _is_critical_choice.
	_is_critical_choice = _effects.detect_critical_choice(_karma, _critical_used, _cards_this_run)
	if _is_critical_choice:
		_critical_used = true
		print("[Merlin] CRITICAL CHOICE detected!")
		SFXManager.play("critical_alert")
		if ui and is_instance_valid(ui):
			ui.show_critical_badge()
	# Show modifier badge
	_effects.show_card_modifier_indicator(current_card, ui)


# ═══════════════════════════════════════════════════════════════════════════════
# VISION PERK HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _check_vision_perk_auto_reveal() -> void:
	## Auto-reveal option effects if a talent grants vision. Stub for future use.
	pass


func _exit_tree() -> void:
	## Cleanup to prevent dangling coroutines on scene change.
	is_busy = false
