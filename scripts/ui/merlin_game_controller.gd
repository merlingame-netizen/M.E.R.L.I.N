## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game Controller — Store-UI Bridge (v1.0.0 — Fusion Phase 37)
## ═══════════════════════════════════════════════════════════════════════════════
## Full gameplay controller: D20 dice, 15 minigames, critical choices,
## flux/talents/biome passives, karma/blessings/adaptive difficulty,
## narrative reactions, travel animations, SFX choreography.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name TriadeGameController

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ═══════════════════════════════════════════════════════════════════════════════

var store: MerlinStore
var ui: TriadeGameUI
var merlin_ai: Node = null  # MerlinAI autoload reference

var current_card: Dictionary = {}
var is_processing := false
var _intro_shown := false
var _cards_this_run := 0
var _dispatch_result: Array = [false, {}]  # [done, result] — shared with async dispatch
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

# LLM cards include result_success/result_failure — no static reaction pools needed.
# Travel text is inline — no static pools needed.

# Card buffer for smooth gameplay
var _card_buffer: Array[Dictionary] = []
const BUFFER_SIZE := 3

# Prerun choice tracking for sequel cards
var _prerun_choices: Array[Dictionary] = []

# RAG context for LLM
const CONTEXT_FILE := "user://triade_context.txt"
const CONTEXT_MAX_ENTRIES := 5

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Find store (singleton or child)
	store = get_node_or_null("/root/MerlinStore")

	# Find or create UI
	ui = get_node_or_null("TriadeGameUI")
	if not ui:
		ui = TriadeGameUI.new()
		ui.name = "TriadeGameUI"
		add_child(ui)

	# Find LLM interface
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		print("[TriadeController] MerlinAI found, LLM generation available")
	else:
		push_warning("[TriadeController] MerlinAI not found — LLM unavailable")

	_connect_signals()

	# Auto-start run after a frame so UI is fully ready
	await get_tree().process_frame
	start_run()


func _connect_signals() -> void:
	# Store signals
	if store:
		store.state_changed.connect(_on_state_changed)
		store.souffle_changed.connect(_on_souffle_changed)
		store.life_changed.connect(_on_life_changed)
		store.run_ended.connect(_on_run_ended)
		store.mission_progress.connect(_on_mission_progress)

	# UI signals
	if ui:
		ui.option_chosen.connect(_on_option_chosen)
		ui.pause_requested.connect(_on_pause_requested)

	# Bestiole wheel signals
	if ui and ui.bestiole_wheel:
		ui.bestiole_wheel.wheel_opened.connect(_on_wheel_open_requested)
		ui.bestiole_wheel.ogham_selected.connect(_on_ogham_selected)

	# Store bestiole signals
	if store:
		if store.has_signal("awen_changed"):
			store.awen_changed.connect(_on_awen_changed)
		if store.has_signal("bond_tier_changed"):
			store.bond_tier_changed.connect(_on_bond_tier_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(seed_value: int = -1) -> void:
	## Start a new TRIADE run with Merlin narrator intro.
	print("[TRIADE] start_run() called")
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
	_card_buffer.clear()
	_prerun_choices.clear()
	_load_prerun_cards()

	if not store:
		push_error("[TRIADE] store is null in start_run, aborting")
		return

	# Apply talent bonuses at run start
	_apply_talent_bonuses()

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

	print("[TRIADE] dispatching TRIADE_START_RUN biome=%s" % biome_key)
	var result = await store.dispatch({
		"type": "TRIADE_START_RUN",
		"seed": seed_value,
		"biome": biome_key,
	})
	print("[TRIADE] TRIADE_START_RUN result: %s" % str(result))

	if result.get("ok", false):
		_sync_ui_with_state()
		if ui and is_instance_valid(ui) and ui.has_method("reset_run_visuals"):
			ui.reset_run_visuals()

		# Opening sequence then narrator intro before first card.
		if ui and is_instance_valid(ui):
			if ui.has_method("show_opening_sequence"):
				await ui.show_opening_sequence(biome_key, season_hint, hour_hint)
			await ui.show_narrator_intro()
			_intro_shown = true
			# Progressive reveal of aspect/souffle indicators
			if ui.has_method("show_progressive_indicators"):
				await ui.show_progressive_indicators()
			# Start biome ambient VFX
			if ui.has_method("start_ambient_vfx"):
				ui.start_ambient_vfx(biome_key)
			print("[TRIADE] narrator intro finished, requesting first card")

		# Then get first card
		_request_next_card()


func _request_next_card() -> void:
	## Get and display the next card (LLM or fallback).
	## Shows thinking animation while generating, with timeout protection.
	print("[TRIADE] _request_next_card() called, is_processing=%s" % str(is_processing))
	if is_processing:
		return
	if not is_inside_tree():
		print("[TRIADE] not inside tree, aborting _request_next_card")
		return
	if not store:
		push_error("[TRIADE] store is null in _request_next_card")
		return

	is_processing = true
	_cards_this_run += 1

	# Fast path: consume from pre-generated card buffer (from TransitionBiome)
	if not _card_buffer.is_empty():
		current_card = _card_buffer.pop_front()
		print("[TRIADE] Using pre-generated card (%d remaining)" % _card_buffer.size())
		_detect_critical_choice()
		# Prefetch moved to _resolve_choice() — state must be updated first
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
		is_processing = false
		return

	# Sequel card: ~30% chance after prerun buffer exhausted, if we have prerun choices
	if _card_buffer.is_empty() and not _prerun_choices.is_empty() and randf() < 0.30:
		var sequel_card := await _try_sequel_card()
		if not sequel_card.is_empty():
			current_card = sequel_card
			print("[TRIADE] Sequel card generated from prerun choice")
			_detect_critical_choice()
			if ui and is_instance_valid(ui):
				ui.display_card(current_card)
			is_processing = false
			return

	# Fast path: try consuming prefetched card directly (skips full LLM pipeline)
	if store and store.has_method("get_merlin"):
		var merlin_mos = store.get_merlin()
		if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
			var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
			if not prefetched.is_empty():
				print("[TRIADE] Using prefetched card (fast path)")
				current_card = prefetched
				_detect_critical_choice()
				if ui and is_instance_valid(ui):
					ui.display_card(current_card)
				is_processing = false
				return

	# Show thinking animation while LLM generates
	if ui and is_instance_valid(ui):
		ui.show_thinking()

	# Launch dispatch asynchronously (runs in its own coroutine)
	_dispatch_result = [false, {}]
	_async_card_dispatch()

	# Wait for completion — frame-accurate polling (responds within 1 frame when LLM finishes)
	var deadline := Time.get_ticks_msec() + int(LLM_TIMEOUT_SEC * 1000.0)
	while not _dispatch_result[0] and Time.get_ticks_msec() < deadline:
		if not is_inside_tree():
			print("[TRIADE] removed from tree during card poll, aborting")
			is_processing = false
			return
		await get_tree().process_frame

	# Hide thinking animation
	if ui and is_instance_valid(ui):
		ui.hide_thinking()

	if not _dispatch_result[0]:
		push_warning("[TriadeController] Card generation timed out after %.0fs, retrying LLM" % LLM_TIMEOUT_SEC)
		var retry_card := await _retry_llm_generation(3)
		if retry_card.is_empty():
			# Show thinking overlay and wait for prefetch
			if ui and is_instance_valid(ui):
				ui.show_merlin_thinking_overlay()
			await get_tree().create_timer(5.0).timeout
			if ui and is_instance_valid(ui):
				ui.hide_merlin_thinking_overlay()
			is_processing = false
			_request_next_card()
			return
		current_card = retry_card
		_detect_critical_choice()
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
		is_processing = false
		return

	var result: Dictionary = _dispatch_result[1]
	print("[TRIADE] card dispatch result ok=%s" % str(result.get("ok", false)))
	if result.get("ok", false):
		current_card = result.get("card", {})
		# Validate card has valid options array (size 3)
		var opts = current_card.get("options", [])
		if current_card.is_empty() or not opts is Array or opts.size() < 3:
			print("[TRIADE] card malformed (options=%s), retrying LLM" % str(opts.size() if opts is Array else "missing"))
			var retry_card := await _retry_llm_generation(2)
			if not retry_card.is_empty():
				current_card = retry_card
			else:
				# Wait and re-request
				is_processing = false
				_request_next_card()
				return
		# NPC encounter: 15% chance after card 5
		if _cards_this_run > 5 and randf() < 0.15:
			var npc_card := await _try_npc_encounter()
			if not npc_card.is_empty():
				current_card = npc_card
				print("[TRIADE] NPC encounter triggered: %s" % npc_card.get("speaker", "?"))
		# Detect critical choice before displaying
		_detect_critical_choice()
		# Prefetch moved to _resolve_choice() — triggers after state update
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)
	else:
		# Store dispatch failed — retry via direct LLM
		print("[TRIADE] store dispatch failed, trying direct LLM retry")
		var llm_card := await _retry_llm_generation(3)
		if llm_card.is_empty():
			# Show thinking overlay and wait
			if ui and is_instance_valid(ui):
				ui.show_merlin_thinking_overlay()
			await get_tree().create_timer(3.0).timeout
			if ui and is_instance_valid(ui):
				ui.hide_merlin_thinking_overlay()
			is_processing = false
			_request_next_card()
			return
		current_card = llm_card
		_detect_critical_choice()
		if ui and is_instance_valid(ui):
			ui.display_card(current_card)

	is_processing = false


func _async_card_dispatch() -> void:
	## Runs store dispatch in a separate coroutine for timeout safety.
	if not store or not is_instance_valid(store):
		push_error("[TRIADE] store invalid in _async_card_dispatch")
		_dispatch_result = [true, {"ok": false, "error": "store_null"}]
		return
	print("[TRIADE] _async_card_dispatch: dispatching TRIADE_GET_CARD")
	var result: Dictionary = await store.dispatch({"type": "TRIADE_GET_CARD"})
	if result == null:
		result = {"ok": false, "error": "null_result"}
	print("[TRIADE] _async_card_dispatch: got result, card=%s" % ("yes" if result.get("card", {}).size() > 0 else "empty"))
	_dispatch_result = [true, result]


func _retry_llm_generation(max_retries: int) -> Dictionary:
	## Retry LLM generation with escalating temperature. Returns card or {}.
	if merlin_ai == null or not merlin_ai.get("is_ready"):
		return {}
	if not merlin_ai.has_method("generate_with_system"):
		return {}
	# Don't retry if LLM is already busy (prefetch or MOS generation)
	if merlin_ai.has_method("is_llm_busy") and merlin_ai.is_llm_busy():
		print("[TRIADE] _retry_llm_generation: LLM busy, skipping retry")
		return {}

	var temperatures := [0.6, 0.7, 0.8]
	var system_prompt := "Tu es Merlin l'Enchanteur, narrateur celtique. Genere une scene immersive en 5-7 phrases (420-620 caracteres). Puis propose exactement 3 options d'action:\nA) [verbe d'action]\nB) [verbe d'action]\nC) [verbe d'action]"

	for i in range(mini(max_retries, temperatures.size())):
		var temp: float = temperatures[i]
		var user_prompt := "Carte %d du voyage. Genere une scene narrative unique et poetique avec 3 choix." % _cards_this_run

		var result: Dictionary = await merlin_ai.generate_with_system(
			system_prompt, user_prompt,
			{"max_tokens": 250, "temperature": temp}
		)

		if result.has("error") or str(result.get("text", "")).length() < 30:
			print("[TRIADE] LLM retry %d failed (temp=%.1f)" % [i + 1, temp])
			continue

		var raw_text: String = str(result.get("text", ""))

		# Parse labels from A/B/C or 1/2/3 patterns
		var labels: Array[String] = []
		var rx := RegEx.new()
		rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+(.+)")
		var matches := rx.search_all(raw_text)
		for m in matches:
			var label := m.get_string(1).strip_edges()
			if label.length() > 2 and label.length() < 80:
				labels.append(label)

		# Extract narrative (text before first label)
		var narrative := raw_text
		if labels.size() >= 2:
			var rx2 := RegEx.new()
			rx2.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+")
			var first_choice := rx2.search(raw_text)
			if first_choice:
				narrative = raw_text.substr(0, first_choice.get_start()).strip_edges()

		if labels.size() < 3:
			# Rotate fallback labels by card count for variety
			var fallback_sets: Array = [
				["Avancer prudemment", "Observer en silence", "Agir sans hesiter"],
				["Explorer les ruines", "Invoquer un esprit", "Braver le peril"],
				["Offrir une priere", "Dechiffrer le signe", "Forcer le passage"],
				["Chercher un guide", "Ecouter le vent", "Plonger dans l'ombre"],
			]
			var fb_idx: int = _cards_this_run % fallback_sets.size()
			var fb_set: Array = fallback_sets[fb_idx]
			labels = [str(fb_set[0]), str(fb_set[1]), str(fb_set[2])]

		# Build card with Vie/Karma/Souffle effects (no SHIFT_ASPECT)
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
				"label": labels[j] if j < labels.size() else "Choix %d" % (j + 1),
				"effects": effect_sets[j],
			}
			options.append(opt)

		print("[TRIADE] LLM retry %d succeeded (temp=%.1f)" % [i + 1, temp])
		return {
			"id": "retry_%d_%d" % [_cards_this_run, i],
			"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 400)),
			"speaker": "Merlin",
			"type": "narrative",
			"options": options,
			"tags": ["llm_generated", "retry"],
		}

	print("[TRIADE] All %d LLM retries exhausted" % max_retries)
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
		return
	var file := FileAccess.open(prerun_path, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	DirAccess.remove_absolute(prerun_path)
	if not data is Array:
		return
	for card in data:
		if card is Dictionary and card.has("text") and card.has("options"):
			_card_buffer.append(card)
	if not _card_buffer.is_empty():
		print("[TRIADE] Loaded %d pre-generated cards from TransitionBiome" % _card_buffer.size())


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
		labels = ["Assumer les consequences", "Chercher une alternative", "Ignorer les signes"]

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
		push_error("[TRIADE] store invalid in _resolve_choice")
		return
	if not is_inside_tree():
		return

	is_processing = true
	var direction: String = ["left", "center", "right"][clampi(option, 0, 2)]
	var choice_label: String = _get_choice_label(option)
	print("[TRIADE] _resolve_choice option=%d direction=%s" % [option, direction])

	# --- 1. Compute DC ---
	var dc: int = _get_dc_for_direction(direction)

	# --- 2. Update Flux based on choice direction ---
	_update_flux(direction)

	# --- 3. Determine dice roll or minigame ---
	var dice_result: int = 0
	var use_minigame: bool = not headless_mode and randf() < minigame_chance and _cards_this_run >= 2
	if _is_critical_choice and not headless_mode:
		use_minigame = true

	SFXManager.play("card_draw")

	if use_minigame:
		dice_result = await _run_minigame(direction, dc)
	else:
		dice_result = await _run_dice_roll(dc)

	if not is_inside_tree():
		is_processing = false
		return

	# --- 4. Determine outcome ---
	var outcome: String = _classify_outcome(dice_result, dc)
	print("[TRIADE] D20=%d vs DC=%d → %s" % [dice_result, dc, outcome])

	# --- 5. SFX for outcome ---
	_play_outcome_sfx(outcome)

	# --- 6. Dramatic pause before result reveal ---
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# --- 6b. Show dice result in UI ---
	if ui and is_instance_valid(ui):
		ui.show_dice_result(dice_result, dc, outcome)

	# --- 7. Compute modulated effects ---
	var options: Array = current_card.get("options", [])
	var base_effects: Array = options[clampi(option, 0, options.size() - 1)].get("effects", []) if option < options.size() else []
	var modulated: Array = _modulate_effects(base_effects, outcome, direction)

	# --- 8. Apply talent shields & blessings ---
	modulated = _apply_talent_shields(modulated)

	# --- 9. Dispatch to store (applies effects, checks run end) ---
	var result = await store.dispatch({
		"type": "TRIADE_RESOLVE_CHOICE",
		"card": current_card,
		"option": option,
		"modulated_effects": modulated,
		"outcome": outcome,
	})
	if result == null:
		result = {"ok": false}

	# --- 9b. Base life drain per card (survival pressure) ---
	if store and is_instance_valid(store):
		store.dispatch({"type": "TRIADE_DAMAGE_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD})

	# --- 10. Update karma ---
	_update_karma(outcome, direction)

	# --- 11. Souffle bonus ---
	_apply_souffle_bonus(outcome)

	# --- 12. Record quest history ---
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

	# --- 12b. Auto-progress mission (Phase 43) ---
	_auto_progress_mission(outcome)

	# --- 12c. Apply GAUGE_DELTA effects to WorldMapSystem ---
	_apply_gauge_deltas(modulated)

	# --- 13. Biome passive check ---
	_check_biome_passive()

	# --- 13b. Prefetch next card NOW (state is fully updated) ---
	# Runs in background while player sees result text + travel animation (~4-6s)
	_trigger_prefetch()

	# --- 14. Narrative result text (immersive) or reaction fallback ---
	var _result_shown := false
	if ui and is_instance_valid(ui) and current_card.size() > 0:
		var result_key: String = "result_success" if outcome.contains("success") else "result_failure"
		var result_text: String = str(current_card.get(result_key, ""))
		if not result_text.is_empty():
			ui.show_result_text_transition(result_text, outcome)
			_result_shown = true
	if not _result_shown and ui and is_instance_valid(ui):
		var reaction_text: String = _get_reaction_text(outcome, choice_label)
		if not reaction_text.is_empty():
			ui.show_reaction_text(reaction_text, outcome)

	# --- 15. Card outcome animation ---
	if ui and is_instance_valid(ui):
		ui.animate_card_outcome(outcome)

	# --- 15b. Show life delta flash ---
	var life_delta: int = 0
	for eff in modulated:
		if eff is Dictionary:
			if str(eff.get("type", "")) == "DAMAGE_LIFE":
				life_delta -= abs(int(eff.get("amount", 0)))
			elif str(eff.get("type", "")) == "HEAL_LIFE":
				life_delta += int(eff.get("amount", 0))
	if ui and is_instance_valid(ui) and ui.has_method("show_life_delta"):
		ui.show_life_delta(life_delta)

	# Wait for player to see reaction
	if not is_inside_tree():
		is_processing = false
		return
	await get_tree().create_timer(3.0).timeout  # Extended for LLM prefetch

	# --- 16. Check run end ---
	if result.get("ok", false) and result.get("run_ended", false):
		print("[TRIADE] run ended!")
		var ending = result.get("ending", {})
		# Calculate and apply rewards
		_apply_run_rewards(ending)
		if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
			ui.mark_card_completed()
		if ui and is_instance_valid(ui):
			ui.show_end_screen(ending)
		is_processing = false
		return

	# --- 17. Travel animation → next card ---
	_sync_ui_with_state()
	if ui and is_instance_valid(ui) and ui.has_method("mark_card_completed"):
		ui.mark_card_completed()
	current_card = {}
	if ui and is_instance_valid(ui):
		var travel_text: String = _pick_travel_text(outcome)
		await ui.show_travel_animation(travel_text)
	elif is_inside_tree():
		await get_tree().create_timer(0.5).timeout

	# --- 18. Write RAG context ---
	_write_context_entry("Choix: %s (%s, D20=%d vs DC%d)" % [choice_label, outcome, dice_result, dc])

	# --- 19. Next card ---
	is_processing = false
	_request_next_card()


# ═══════════════════════════════════════════════════════════════════════════════
# D20 RESOLUTION ENGINE
# ═══════════════════════════════════════════════════════════════════════════════

func _run_dice_roll(dc: int) -> int:
	## Animate D20 dice roll. Returns final value (1-20).
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


func _run_minigame(direction: String, dc: int) -> int:
	## Launch a minigame, convert score to D20. Fallback to dice if no registry.
	var narrative_text: String = str(current_card.get("text", ""))
	var gm_hint: String = str(current_card.get("minigame_hint", ""))

	# Detect field from narrative + tags
	var card_tags: Array = current_card.get("tags", [])
	var field: String = MiniGameRegistry.detect_field(narrative_text, gm_hint, card_tags)
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
		print("[TRIADE] minigame creation failed, falling back to dice")
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
		push_warning("[TRIADE] minigame timed out after %.0fs, using dice fallback" % mg_timeout)
		if is_instance_valid(game):
			game.queue_free()
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

	# Convert score to D20 + apply tool bonus
	var d20: int = MiniGameBase.score_to_d20(score)
	if tool_bonus != 0:
		d20 = clampi(d20 - tool_bonus, 1, 20)  # Negative bonus = easier (higher effective roll)
		print("[TRIADE] tool bonus: %d → D20 adjusted to %d" % [tool_bonus, d20])
	print("[TRIADE] minigame done: score=%d → D20=%d" % [score, d20])

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
			if store:
				store.dispatch({"type": "TRIADE_ADD_SOUFFLE", "amount": 1})
		elif consecutive_wins >= 3:
			modifier = 2  # Challenge mode

	# Critical choice modifier
	if _is_critical_choice:
		var crit_penalty: int = 4
		if store and store.has_method("is_talent_active") and store.is_talent_active("feuillage_4"):
			crit_penalty = 2
		modifier += crit_penalty

	# Flux Lien modifier
	if store:
		var flux: Dictionary = store.state.get("run", {}).get("flux", {})
		var lien_val: int = int(flux.get("lien", 40))
		if lien_val <= 30:
			modifier -= 2
		elif lien_val >= 70:
			modifier += 3

	# Biome difficulty modifier
	if store and store.biomes:
		var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
		if not biome_key.is_empty():
			var biome_data: Dictionary = store.biomes.get_biome_data(biome_key) if store.biomes.has_method("get_biome_data") else {}
			modifier += int(biome_data.get("difficulty", 0))

	return clampi(base_dc + modifier, 2, 19)


func _get_choice_label(option: int) -> String:
	var options: Array = current_card.get("options", [])
	if option < options.size():
		return str(options[option].get("label", ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]))
	return ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT MODULATION
# ═══════════════════════════════════════════════════════════════════════════════

func _modulate_effects(base_effects: Array, outcome: String, _direction: String) -> Array:
	## Modulate card effects based on D20 outcome.
	## Effects: DAMAGE_LIFE, HEAL_LIFE, ADD_KARMA, ADD_SOUFFLE, GAUGE_DELTA.
	var result: Array = []
	for effect in base_effects:
		var e: Dictionary = effect.duplicate() if effect is Dictionary else {}
		var etype: String = str(e.get("type", ""))
		match outcome:
			"critical_success":
				# Double positive effects
				if etype == "HEAL_LIFE" or etype == "ADD_KARMA" or etype == "ADD_SOUFFLE":
					var boosted: Dictionary = e.duplicate()
					boosted["amount"] = int(e.get("amount", 0)) * 2
					result.append(boosted)
				elif etype == "DAMAGE_LIFE":
					# Cancel damage on crit success
					pass
				elif etype == "GAUGE_DELTA":
					var boosted: Dictionary = e.duplicate()
					var delta: Dictionary = boosted.get("delta", {})
					var doubled: Dictionary = {}
					for k in delta:
						doubled[k] = int(delta[k]) * 2
					boosted["delta"] = doubled
					result.append(boosted)
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
				elif etype == "ADD_KARMA":
					result.append({"type": "ADD_KARMA", "amount": -int(e.get("amount", 0))})
				elif etype == "GAUGE_DELTA":
					var reversed_g: Dictionary = e.duplicate()
					var delta: Dictionary = reversed_g.get("delta", {})
					var negated: Dictionary = {}
					for k in delta:
						negated[k] = -int(delta[k])
					reversed_g["delta"] = negated
					result.append(reversed_g)
				else:
					result.append(e)
			"critical_failure":
				# Reverse heals to damage, keep damage as-is (bonus penalty applied separately)
				if etype == "HEAL_LIFE":
					result.append({"type": "DAMAGE_LIFE", "amount": int(e.get("amount", 0))})
				elif etype == "DAMAGE_LIFE":
					result.append(e)
				elif etype == "ADD_KARMA":
					result.append({"type": "ADD_KARMA", "amount": -int(e.get("amount", 0)) * 2})
				elif etype == "GAUGE_DELTA":
					var reversed_g: Dictionary = e.duplicate()
					var delta: Dictionary = reversed_g.get("delta", {})
					var negated_x2: Dictionary = {}
					for k in delta:
						negated_x2[k] = -int(delta[k]) * 2
					reversed_g["delta"] = negated_x2
					result.append(reversed_g)
				else:
					result.append(e)

	# Life damage on critical failure (bonus penalty)
	if outcome == "critical_failure" and store:
		store.dispatch({"type": "TRIADE_DAMAGE_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_CRIT_FAIL_DAMAGE})
		print("[TRIADE] Critical failure! Life essence -%d" % MerlinConstants.LIFE_ESSENCE_CRIT_FAIL_DAMAGE)

	# Life heal on critical success (bonus heal)
	if outcome == "critical_success" and store:
		store.dispatch({"type": "TRIADE_HEAL_LIFE", "amount": MerlinConstants.LIFE_ESSENCE_CRIT_SUCCESS_HEAL})
		print("[TRIADE] Critical success! Life essence +%d" % MerlinConstants.LIFE_ESSENCE_CRIT_SUCCESS_HEAL)

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
				print("[TRIADE] Talent: Endurance Naturelle absorbe les degats!")
				SFXManager.play("skill_activate")
				continue  # Skip this effect

		result.append(e)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# KARMA, BLESSINGS, SOUFFLE
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


func _apply_souffle_bonus(outcome: String) -> void:
	if not store:
		return
	if MerlinConstants.SOUFFLE_SINGLE_USE:
		return
	match outcome:
		"critical_success":
			store.dispatch({"type": "TRIADE_ADD_SOUFFLE", "amount": 2})
		"success":
			store.dispatch({"type": "TRIADE_ADD_SOUFFLE", "amount": 1})

	# Souffle regen on success streak
	if store.has_method("is_talent_active") and store.is_talent_active("racines_5"):
		store.dispatch({"type": "TRIADE_ADD_SOUFFLE", "amount": 1})


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
		print("[TRIADE] CRITICAL CHOICE detected!")
		SFXManager.play("critical_alert")
		if ui and is_instance_valid(ui):
			ui.show_critical_badge()


# ═══════════════════════════════════════════════════════════════════════════════
# FLUX SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _update_flux(direction: String) -> void:
	if not store:
		return
	var delta: Dictionary = MerlinConstants.FLUX_CHOICE_DELTA.get(direction, {})
	if not delta.is_empty():
		store.dispatch({"type": "TRIADE_UPDATE_FLUX", "delta": delta})


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
		store.dispatch({"type": "TRIADE_PROGRESS_MISSION", "step": step})


func _check_biome_passive() -> void:
	if not store or not store.biomes:
		return
	var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
	if biome_key.is_empty():
		return
	if store.biomes.has_method("should_trigger_passive") and store.biomes.should_trigger_passive(biome_key, _cards_this_run):
		var passive: Dictionary = store.biomes.get_passive_effect(biome_key, _cards_this_run) if store.biomes.has_method("get_passive_effect") else {}
		if not passive.is_empty():
			print("[TRIADE] Biome passive triggered: %s" % str(passive))
			var passive_type: String = str(passive.get("type", ""))
			if passive_type.contains("HEAL"):
				store.dispatch({"type": "TRIADE_HEAL_LIFE", "amount": int(passive.get("amount", 5))})
			else:
				store.dispatch({"type": "TRIADE_DAMAGE_LIFE", "amount": int(passive.get("amount", 5))})
			if ui and is_instance_valid(ui):
				ui.show_biome_passive(passive)


## Apply GAUGE_DELTA effects to WorldMapSystem (5 continuous gauges).
## Effect format: {"type": "GAUGE_DELTA", "delta": {"esprit": 10, "vigueur": -5}}
func _apply_gauge_deltas(effects: Array) -> void:
	var wms: Node = get_node_or_null("/root/WorldMapSystem")
	if wms == null or not wms.has_method("update_gauges"):
		return

	# Merge all GAUGE_DELTA effects into a single delta
	var merged_delta: Dictionary = {}
	for e in effects:
		if not e is Dictionary:
			continue
		if str(e.get("type", "")) != "GAUGE_DELTA":
			continue
		var delta: Dictionary = e.get("delta", {})
		for key in delta:
			merged_delta[key] = int(merged_delta.get(key, 0)) + int(delta[key])

	if merged_delta.is_empty():
		return

	print("[TRIADE] Applying gauge delta: %s" % str(merged_delta))
	wms.update_gauges(merged_delta)


# ═══════════════════════════════════════════════════════════════════════════════
# NARRATIVE REACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_reaction_text(_outcome: String, _choice_label: String) -> String:
	## LLM cards include result_success / result_failure. No static pool needed.
	return ""


func _pick_travel_text(_outcome: String) -> String:
	## Minimal inline text — no static pool.
	return "Le sentier continue..."


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
		"flux": store.state.get("run", {}).get("flux", {}).duplicate(),
		"all_balanced": store.is_all_aspects_balanced() if store.has_method("is_all_aspects_balanced") else false,
		"bond": store.get_bestiole_bond() if store.has_method("get_bestiole_bond") else 0,
		"minigames_won": _minigames_won,
		"score": ending.get("score", 0),
	}
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	store.apply_run_rewards(rewards)
	# Attach rewards to ending for end screen display
	ending["rewards"] = rewards
	print("[TRIADE] Rewards applied: %s" % str(rewards))


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
	"""Activate a Bestiole skill."""
	if skill_id.strip_edges().is_empty():
		return
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "TRIADE_USE_SKILL",
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
			# TODO: Show revealed effects in UI
			pass
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

	# Souffle
	var souffle: int = store.get_souffle() if store.has_method("get_souffle") else MerlinConstants.SOUFFLE_START
	ui.update_souffle(souffle)

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

	# Bestiole wheel
	if ui.bestiole_wheel and is_instance_valid(ui.bestiole_wheel):
		ui.bestiole_wheel.update_awen(store.get_awen() if store.has_method("get_awen") else 0)
		ui.bestiole_wheel.update_bond(store.get_bestiole_bond() if store.has_method("get_bestiole_bond") else 0)


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Store
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_changed(_state: Dictionary) -> void:
	_sync_ui_with_state()




func _on_souffle_changed(old_value: int, new_value: int) -> void:
	if ui:
		ui.update_souffle(new_value)

	# Feedback for regeneration / drain
	if new_value > old_value:
		SFXManager.play("ogham_chime")
		print("[TRIADE] Souffle regenerated: +%d" % (new_value - old_value))
	elif new_value < old_value:
		SFXManager.play("aspect_down")


func _on_life_changed(old_value: int, new_value: int) -> void:
	if ui and ui.has_method("update_life_essence"):
		ui.update_life_essence(new_value)
	if new_value < old_value:
		SFXManager.play("aspect_down")
		print("[TRIADE] Life essence: %d → %d" % [old_value, new_value])
		if new_value <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and new_value > 0:
			print("[TRIADE] WARNING: Life essence low!")
	elif new_value > old_value:
		SFXManager.play("ogham_chime")


func _on_run_ended(ending: Dictionary) -> void:
	print("[TRIADE] _on_run_ended signal received")
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

	# Check bestiole evolution eligibility after run
	_check_evolution_after_run()


func _on_mission_progress(step: int, total: int) -> void:
	if ui:
		var mission = store.get_mission()
		ui.update_mission(mission)

	if step >= total and total > 0:
		print("[TRIADE] Mission complete!")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — UI
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_chosen(option: int) -> void:
	_resolve_choice(option)


func _on_skill_activated(skill_id: String) -> void:
	_use_skill(skill_id)


func _on_pause_requested() -> void:
	# TODO: Show pause menu
	get_tree().paused = not get_tree().paused


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — Bestiole Wheel
# ═══════════════════════════════════════════════════════════════════════════════

func _on_wheel_open_requested() -> void:
	if store and ui and ui.bestiole_wheel:
		ui.bestiole_wheel.open_wheel(store)


func _on_ogham_selected(skill_id: String) -> void:
	_use_ogham(skill_id)


func _on_awen_changed(_old_value: int, new_value: int) -> void:
	if ui and ui.bestiole_wheel:
		ui.bestiole_wheel.update_awen(new_value)


func _on_bond_tier_changed(_old_tier: String, _new_tier: String) -> void:
	if store and ui and ui.bestiole_wheel:
		ui.bestiole_wheel.update_bond(store.get_bestiole_bond())


func _use_ogham(skill_id: String) -> void:
	"""Activate a Bestiole Ogham skill via the store."""
	if skill_id.strip_edges().is_empty():
		return
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "TRIADE_USE_OGHAM",
		"skill_id": skill_id,
		"card": current_card,
	})
	var result: Dictionary = raw_result if raw_result is Dictionary else {"ok": false, "error": "invalid_result"}

	if result.get("ok", false):
		_sync_ui_with_state()


func _unhandled_input(event: InputEvent) -> void:
	# Tab key toggles Bestiole wheel
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if ui and ui.bestiole_wheel:
			if ui.bestiole_wheel.is_open:
				ui.bestiole_wheel.close_wheel()
			elif store:
				ui.bestiole_wheel.open_wheel(store)
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# CONVENIENCE
# ═══════════════════════════════════════════════════════════════════════════════

func get_aspect_state(aspect: String) -> int:
	return store.get_aspect_state(aspect) if store else 0


func get_aspect_name(aspect: String) -> String:
	return store.get_aspect_name(aspect) if store else "???"


func get_souffle() -> int:
	return store.get_souffle() if store else 0


func is_run_active() -> bool:
	return store.is_run_active() if store else false


# ═══════════════════════════════════════════════════════════════════════════════
# BESTIOLE EVOLUTION — Path choice UI (Phase 37)
# ═══════════════════════════════════════════════════════════════════════════════

func _check_evolution_after_run() -> void:
	"""Check if Bestiole can evolve after a run ends."""
	if not store:
		return
	var evo_check: Dictionary = store.check_bestiole_evolution()
	if not evo_check.get("can_evolve", false):
		return

	# Show evolution choice after a delay (let end screen settle)
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	_show_evolution_choice(evo_check)


func _show_evolution_choice(evo_data: Dictionary) -> void:
	"""Display evolution path choice overlay (Protecteur/Oracle/Diplomate)."""
	if not ui:
		return

	var next_stage: int = int(evo_data.get("next_stage", 2))
	var stage_name: String = str(evo_data.get("name", ""))

	# Build overlay
	var overlay := ColorRect.new()
	overlay.name = "EvolutionOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(overlay)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.custom_minimum_size = Vector2(500, 400)
	center.add_theme_constant_override("separation", 16)
	overlay.add_child(center)

	# Title
	var title := Label.new()
	title.text = "Evolution de Bestiole"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.68, 0.55, 0.32))
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Stade %d: %s — Choisissez une voie" % [next_stage, stage_name]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	center.add_child(subtitle)

	# Path cards row
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)

	# Colors per aspect
	var aspect_colors := {
		"Corps": Color(0.55, 0.40, 0.25),
		"Ame": Color(0.40, 0.45, 0.70),
		"Monde": Color(0.35, 0.55, 0.35),
	}

	for path_id in MerlinConstants.BESTIOLE_EVOLUTION_PATHS:
		var path_data: Dictionary = MerlinConstants.BESTIOLE_EVOLUTION_PATHS[path_id]
		var path_name: String = str(path_data.get("name", path_id))
		var aspect: String = str(path_data.get("aspect", ""))
		var bonus: String = str(path_data.get("bonus", ""))
		var cost: Dictionary = path_data.get("cost", {})
		var can_afford: bool = store.can_afford_evolution_path(path_id)
		var aspect_color: Color = aspect_colors.get(aspect, Color.WHITE)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(150, 200)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.10, 0.08)
		card_style.border_color = aspect_color if can_afford else Color(0.3, 0.3, 0.3, 0.5)
		card_style.set_border_width_all(2)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 10
		card_style.content_margin_top = 10
		card_style.content_margin_right = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)
		row.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		# Path name
		var name_lbl := Label.new()
		name_lbl.text = path_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", aspect_color)
		vbox.add_child(name_lbl)

		# Aspect
		var aspect_lbl := Label.new()
		aspect_lbl.text = "(%s)" % aspect
		aspect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aspect_lbl.add_theme_font_size_override("font_size", 12)
		aspect_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		vbox.add_child(aspect_lbl)

		# Bonus
		var bonus_lbl := Label.new()
		bonus_lbl.text = bonus.replace("_", " ").capitalize()
		bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		bonus_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
		vbox.add_child(bonus_lbl)

		# Cost
		var cost_parts: Array = []
		for elem in cost:
			cost_parts.append("%s: %d" % [elem, int(cost[elem])])
		var cost_lbl := Label.new()
		cost_lbl.text = ", ".join(cost_parts)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.35) if can_afford else Color(0.7, 0.3, 0.3))
		vbox.add_child(cost_lbl)

		# Choose button
		var btn := Button.new()
		btn.text = "Choisir" if can_afford else "Insuffisant"
		btn.disabled = not can_afford
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 13)
		var _path_id: String = path_id  # Capture for closure
		btn.pressed.connect(func():
			_confirm_evolution(_path_id, overlay)
		)
		vbox.add_child(btn)

	# Skip button (evolve without path — only for stage 1 → 2)
	if next_stage <= 2:
		var skip_btn := Button.new()
		skip_btn.text = "Evoluer sans voie"
		skip_btn.custom_minimum_size = Vector2(200, 32)
		skip_btn.add_theme_font_size_override("font_size", 13)
		skip_btn.pressed.connect(func():
			_confirm_evolution("", overlay)
		)
		center.add_child(skip_btn)


func _confirm_evolution(path: String, overlay: Control) -> void:
	"""Apply evolution and dismiss the overlay."""
	if not store:
		return
	var result: Dictionary = store.evolve_bestiole(path)
	if result.get("ok", false):
		var stage_name: String = str(result.get("name", ""))
		var path_name: String = str(result.get("path", ""))
		var msg: String = "Bestiole a evolue en %s" % stage_name
		if path_name != "":
			msg += " (voie %s)" % path_name.capitalize()
		print("[EVOLUTION] %s" % msg)
		# Play SFX
		var sfx: Node = get_node_or_null("/root/SFXManager")
		if sfx and sfx.has_method("play"):
			sfx.play("evolution_confirm")
	else:
		print("[EVOLUTION] Failed: %s" % str(result.get("error", "unknown")))

	# Remove overlay
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()


func _exit_tree() -> void:
	## Cleanup to prevent dangling coroutines on scene change.
	is_processing = false
