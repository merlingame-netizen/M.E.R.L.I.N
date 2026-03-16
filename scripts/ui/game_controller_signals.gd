## ═══════════════════════════════════════════════════════════════════════════════
## Game Controller — Signal Handlers & UI Sync Module
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_controller.gd.
## Handles store signal callbacks, UI signal callbacks, ogham/skill usage,
## UI synchronization, RAG context writing, tutorial system, and journal.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name GameControllerSignals

# RAG context for LLM
const CONTEXT_FILE := "user://game_context.txt"
const CONTEXT_MAX_ENTRIES := 5

var _ctrl: Node  # MerlinGameController reference

# Tutorial system
var tutorial_shown: Dictionary = {}  # { "trigger_key": true }
var tutorial_data: Dictionary = {}   # Loaded from tutorial_narratives.json


func _init(controller: Node) -> void:
	_ctrl = controller


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func connect_signals() -> void:
	## Wire up all store/UI/ogham signals.
	var store: Node = _ctrl.store
	var ui: Node = _ctrl.ui

	# Store signals
	if store:
		store.state_changed.connect(_on_state_changed)
		store.life_changed.connect(_on_life_changed)
		store.run_ended.connect(_on_run_ended)
		store.mission_progress.connect(_on_mission_progress)
		store.trust_changed.connect(_on_trust_changed)
		store.card_resolved.connect(_on_card_resolved)
		store.ogham_activated.connect(_on_ogham_activated)
		store.season_changed.connect(_on_season_changed)
		store.faveurs_changed.connect(_on_faveurs_changed)

	# MerlinOmniscient signals
	if store and store.merlin:
		store.merlin.trust_tier_changed.connect(_on_trust_tier_changed)

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


func load_tutorial_data() -> void:
	## Load tutorial narratives from JSON. Silent fail if missing.
	var path := "res://data/ai/tutorial_narratives.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		tutorial_data = json.data.get("mechanics", {})
	file.close()


# ═══════════════════════════════════════════════════════════════════════════════
# UI SYNCHRONIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func sync_ui_with_state() -> void:
	## Sync UI with current store state.
	var store: Node = _ctrl.store
	var ui: Node = _ctrl.ui
	if not ui or not is_instance_valid(ui) or not store or not is_instance_valid(store):
		return

	# Life essence
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

	# Resource bar
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
# STORE SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_state_changed(_state: Dictionary) -> void:
	sync_ui_with_state()
	var ui: Node = _ctrl.ui
	var store: Node = _ctrl.store
	if ui and is_instance_valid(ui) and ui.has_method("update_selected_perk") and store:
		var selected_perk: String = str(store.state.get("run", {}).get("perks", {}).get("selected_perk", ""))
		ui.update_selected_perk(selected_perk)


func _on_life_changed(old_value: int, new_value: int) -> void:
	var ui: Node = _ctrl.ui
	if ui and ui.has_method("update_life_essence"):
		ui.update_life_essence(new_value)
	if new_value < old_value:
		SFXManager.play("aspect_down")
		print("[Merlin] Life essence: %d -> %d" % [old_value, new_value])
		if new_value <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and new_value > 0:
			print("[Merlin] WARNING: Life essence low!")
	elif new_value > old_value:
		SFXManager.play("ogham_chime")


func _on_run_ended(ending: Dictionary) -> void:
	print("[Merlin] _on_run_ended signal received")
	ending["story_log"] = _ctrl._quest_history.duplicate()
	var merlin_ai: Node = _ctrl.merlin_ai
	var store: Node = _ctrl.store
	# Archive run in RAG cross-run memory
	if merlin_ai and is_instance_valid(merlin_ai) and merlin_ai.get("rag_manager"):
		var ending_title: String = ending.get("ending", {}).get("title", "")
		merlin_ai.rag_manager.summarize_and_archive_run(ending_title, store.state if store else {})

	# Auto-save meta state
	var gm: Node = _ctrl.get_node_or_null("/root/GameManager")
	if gm and gm.has_method("save_to_slot"):
		gm.save_to_slot(1)

	# Show end screen
	var ui: Node = _ctrl.ui
	if ui and is_instance_valid(ui):
		ui.show_end_screen(ending)


func _on_mission_progress(step: int, total: int) -> void:
	var ui: Node = _ctrl.ui
	var store: Node = _ctrl.store
	if ui:
		var mission = store.get_mission()
		ui.update_mission(mission)
	if step >= total and total > 0:
		print("[Merlin] Mission complete!")


func _on_card_resolved(card_id: String, option: int) -> void:
	_ctrl._cards_this_run += 1
	_ctrl._quest_history.append({"card_id": card_id, "option": option, "index": _ctrl._cards_this_run})
	print("[Merlin] Card resolved: %s (option %d, total %d)" % [card_id, option, _ctrl._cards_this_run])


func _on_ogham_activated(skill_id: String, effect: String) -> void:
	SFXManager.play("ogham_chime")
	print("[Merlin] Ogham activated: %s -> %s" % [skill_id, effect])


func _on_season_changed(new_season: String) -> void:
	print("[Merlin] Season changed: %s" % new_season)


func _on_faveurs_changed(old_val: int, new_val: int) -> void:
	if new_val > old_val:
		SFXManager.play("ogham_chime")
	print("[Merlin] Faveurs: %d -> %d" % [old_val, new_val])


func _on_trust_changed(old_value: int, new_value: int, tier: String) -> void:
	print("[Merlin] Trust Merlin: %d -> %d (tier: %s)" % [old_value, new_value, tier])
	var ui: Node = _ctrl.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_life_delta"):
		var delta: int = new_value - old_value
		if delta != 0:
			SFXManager.play("ogham_chime" if delta > 0 else "aspect_down")


func _on_trust_tier_changed(old_tier: int, new_tier: int) -> void:
	var tier_names: Array[String] = ["T0", "T1", "T2", "T3"]
	var old_name: String = tier_names[clampi(old_tier, 0, 3)]
	var new_name: String = tier_names[clampi(new_tier, 0, 3)]
	print("[Merlin] Trust tier changed: %s -> %s" % [old_name, new_name])
	var ui: Node = _ctrl.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_milestone_popup"):
		if new_tier > old_tier:
			ui.show_milestone_popup("Confiance accrue", "Merlin te fait davantage confiance (%s)" % new_name)
		else:
			ui.show_milestone_popup("Confiance en recul", "Merlin se montre plus distant (%s)" % new_name)


# ═══════════════════════════════════════════════════════════════════════════════
# UI SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_chosen(option: int) -> void:
	_ctrl._resolve_choice(option)


func _on_pause_requested() -> void:
	var ui: Node = _ctrl.ui
	if _ctrl.get_tree().paused:
		if ui and is_instance_valid(ui) and ui.has_method("hide_pause_menu"):
			ui.hide_pause_menu()
		_ctrl.get_tree().paused = false
	else:
		_ctrl.get_tree().paused = true
		if ui and is_instance_valid(ui) and ui.has_method("show_pause_menu"):
			ui.show_pause_menu()


func _on_merlin_dialogue_requested(player_input: String) -> void:
	## Player talks to Merlin — generate LLM response.
	if _ctrl.is_processing:
		return
	_ctrl.is_processing = true
	print("[Merlin] Dialogue: player asks '%s'" % player_input)

	var ui: Node = _ctrl.ui
	var store: Node = _ctrl.store
	if ui:
		ui.show_merlin_thinking_overlay()

	var context: String = player_input
	if store:
		var state: Dictionary = store.get_state()
		var life: int = state.get("life_essence", 100)
		context = "Le voyageur demande: %s\n(Vie=%d)" % [player_input, life]

	var response: String = ""
	var mos: MerlinOmniscient = store.get_merlin() if store else null
	if mos and mos.has_method("get_merlin_comment"):
		response = await mos.get_merlin_comment(context)

	if response.is_empty():
		response = "Les pierres murmurent... mais je n'entends pas clairement. Repose ta question, voyageur."

	if ui:
		ui.hide_merlin_thinking_overlay()
		ui.show_merlin_dialogue_response(response)

	write_context_entry("Dialogue: %s -> %s" % [player_input, response.left(80)], _ctrl._cards_this_run)
	_ctrl.is_processing = false


func _on_journal_requested() -> void:
	## Open the visual journal of past lives.
	var store: Node = _ctrl.store
	var ui: Node = _ctrl.ui
	if not store or not is_instance_valid(store):
		return
	var mos: MerlinOmniscient = store.get_merlin() if store.has_method("get_merlin") else null
	var run_summaries: Array[Dictionary] = []
	if mos and mos.rag_manager and mos.rag_manager.has_method("get_run_summaries_for_journal"):
		run_summaries = mos.rag_manager.get_run_summaries_for_journal()
	if run_summaries.is_empty():
		if ui and is_instance_valid(ui) and ui.has_method("show_merlin_dialogue_response"):
			ui.show_merlin_dialogue_response("Tu n'as pas encore vecu de vies anterieures, voyageur. Ton histoire commence ici.")
		return
	if ui and is_instance_valid(ui) and ui.has_method("show_journal_popup"):
		ui.show_journal_popup(run_summaries)


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM / SKILL USAGE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_ogham_selected(skill_id: String) -> void:
	_use_ogham(skill_id)


func _use_ogham(skill_id: String) -> void:
	## Activate an Ogham skill via the store.
	if skill_id.strip_edges().is_empty():
		return
	try_tutorial("first_ogham_used")
	var store: Node = _ctrl.store
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "USE_OGHAM",
		"skill_id": skill_id,
		"card": _ctrl.current_card,
	})
	var result: Dictionary = raw_result if raw_result is Dictionary else {"ok": false, "error": "invalid_result"}

	if result.get("ok", false):
		sync_ui_with_state()


func use_skill(skill_id: String) -> void:
	## Activate a skill.
	if skill_id.strip_edges().is_empty():
		return
	var store: Node = _ctrl.store
	if not store or not is_instance_valid(store):
		return

	var raw_result: Variant = await store.dispatch({
		"type": "USE_SKILL",
		"skill_id": skill_id,
		"card": _ctrl.current_card,
	})
	var result: Dictionary = raw_result if raw_result is Dictionary else {"ok": false, "error": "invalid_result"}

	if not result.get("ok", false):
		return

	var skill_type: String = str(result.get("type", ""))
	var ui: Node = _ctrl.ui
	match skill_type:
		"reveal_one", "reveal_all":
			var options: Array = _ctrl.current_card.get("options", [])
			if ui and is_instance_valid(ui) and ui.has_method("show_reveal_effects"):
				if skill_type == "reveal_all":
					ui.show_reveal_effects(options, -1)
				else:
					ui.show_reveal_effects(options, 1)
		"reroll_card", "full_reroll":
			if not _ctrl.is_processing:
				_ctrl._request_next_card()
		_:
			sync_ui_with_state()


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func try_tutorial(trigger_key: String) -> void:
	## Show a diegetic tutorial hint via Merlin bubble if not already shown.
	if tutorial_shown.get(trigger_key, false):
		return
	if tutorial_data.is_empty():
		return

	var entry: Dictionary = {}
	for key in tutorial_data:
		var mech: Dictionary = tutorial_data[key]
		if mech is Dictionary and str(mech.get("trigger", "")) == trigger_key:
			entry = mech
			break
	if entry.is_empty():
		return

	tutorial_shown[trigger_key] = true
	var text: String = str(entry.get("text", ""))
	if text.is_empty():
		return

	print("[TUTORIAL] Showing hint: %s" % trigger_key)
	var ui: Node = _ctrl.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_merlin_dialogue_response"):
		ui.show_merlin_dialogue_response(text)


# ═══════════════════════════════════════════════════════════════════════════════
# RAG CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func write_context_entry(entry: String, cards_this_run: int) -> void:
	## Write choice history to file for RAG context injection.
	var existing: String = ""
	if FileAccess.file_exists(CONTEXT_FILE):
		var f := FileAccess.open(CONTEXT_FILE, FileAccess.READ)
		if f:
			existing = f.get_as_text()
			f.close()
	var lines: PackedStringArray = existing.split("\n", false)
	lines.append("[%d] %s" % [cards_this_run, entry])
	if lines.size() > CONTEXT_MAX_ENTRIES:
		lines = lines.slice(-CONTEXT_MAX_ENTRIES)
	var fw := FileAccess.open(CONTEXT_FILE, FileAccess.WRITE)
	if fw:
		fw.store_string("\n".join(lines))
		fw.close()
