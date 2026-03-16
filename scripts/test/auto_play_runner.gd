## ═══════════════════════════════════════════════════════════════════════════════
## Auto-Play Runner — Headless E2E Test for MerlinGame (v2 — detailed logging)
## ═══════════════════════════════════════════════════════════════════════════════
## Simulates a complete run by auto-selecting choices. Logs every card with:
## - Full text, all tags, speaker, card source, generation time
## - D20/DC/outcome, minigame type (if triggered), effect modulation
## - Life/karma/flux/mission state per card
## Prefix: [AUTOPLAY] for easy grep.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

enum Strategy { RANDOM, ALWAYS_LEFT, ALWAYS_RIGHT, ALWAYS_CENTER, MIXED }

const MAX_CARDS := 40
const POLL_TIMEOUT_SEC := 420.0  # 7 min — CPU LLM cold start + generation can take 300s
const INTER_CARD_DELAY := 0.1

# 15 minigames available in the game
const MINIGAME_LIST := [
	"mg_de_du_destin", "mg_pile_ou_face", "mg_rune_cachee", "mg_roue_fortune",
	"mg_lame_druide", "mg_pas_renard", "mg_enigme_ogham", "mg_joute_verbale",
	"mg_oeil_corbeau", "mg_noeud_celtique", "mg_tir_a_larc", "mg_negociation",
	"mg_bluff_druide", "mg_pierre_feuille_racine", "mg_trace_cerf",
]

var strategy: int = Strategy.MIXED
var _controller: Node = null
var _ui: Node = null
var _store: Node = null
var _cards_played: int = 0
var _run_log: Array[Dictionary] = []
var _run_active: bool = true
var _total_life_drain: int = 0
var _llm_count: int = 0
var _fallback_count: int = 0
var _animations_log: Dictionary = {}
var _card_gen_times: Array[int] = []  # ms per card generation
var _run_start_ms: int = 0


func _ready() -> void:
	_run_start_ms = Time.get_ticks_msec()
	_log("=== AUTO-PLAY RUNNER START (v2 detailed) ===")
	_log("strategy=%s max_cards=%d" % [Strategy.keys()[strategy], MAX_CARDS])
	_log("minigames_available=%d: %s" % [MINIGAME_LIST.size(), ", ".join(MINIGAME_LIST)])

	_load_config()

	# Trigger LLM warmup
	var merlin_ai: Node = get_node_or_null("/root/MerlinAI")
	if merlin_ai and merlin_ai.has_method("start_warmup"):
		_log("Triggering MerlinAI.start_warmup()...")
		merlin_ai.start_warmup()
		var warmup_start := Time.get_ticks_msec()
		while not merlin_ai.is_ready:
			if Time.get_ticks_msec() - warmup_start > 60000:
				_log("WARNING: LLM warmup timeout (60s)")
				break
			await get_tree().process_frame
		_log("LLM warmup: ready=%s elapsed=%dms" % [str(merlin_ai.is_ready), Time.get_ticks_msec() - warmup_start])
	else:
		_log("WARNING: MerlinAI autoload not found")

	# Wait for MerlinStore
	_log("Waiting for MerlinStore...")
	for i in range(10):
		await get_tree().process_frame
		if get_node_or_null("/root/MerlinStore"):
			break
	_store = get_node_or_null("/root/MerlinStore")
	_log("MerlinStore: %s" % ("OK" if _store else "MISSING"))

	# Instantiate MerlinGame
	var game_scene: PackedScene = load("res://scenes/MerlinGame.tscn")
	if game_scene == null:
		_log("ERROR: Cannot load MerlinGame.tscn")
		get_tree().quit(1)
		return

	var game_instance: Node = game_scene.instantiate()
	# Set headless_mode BEFORE add_child — _ready() → start_run() triggers during add_child
	game_instance.headless_mode = true
	game_instance.minigame_chance = 0.0
	add_child(game_instance)
	_log("MerlinGame instantiated (headless_mode set pre-ready)")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_controller = _find_node_by_class("MerlinGameController")
	_ui = _find_node_by_class("MerlinGameUI")
	_store = get_node_or_null("/root/MerlinStore")

	if not _controller or not _ui:
		_log("ERROR: controller=%s ui=%s" % [str(_controller != null), str(_ui != null)])
		get_tree().quit(1)
		return

	_log("controller=OK ui=OK store=%s" % ("OK" if _store else "MISSING"))

	# headless_mode already set pre-ready (before add_child)
	_log("headless_mode=true (minigames skipped, dice fallback used)")

	# Connect signals
	if _store and _store.has_signal("run_ended"):
		_store.run_ended.connect(_on_run_ended)

	# Log initial state
	_log_initial_state()

	_log("Waiting for game init (2s)...")
	await get_tree().create_timer(2.0).timeout

	_auto_play_loop()


func _load_config() -> void:
	var config_path := "user://autoplay_config.json"
	if not FileAccess.file_exists(config_path):
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var strat_name: String = str(data.get("strategy", "MIXED")).to_upper()
		match strat_name:
			"RANDOM": strategy = Strategy.RANDOM
			"ALWAYS_LEFT": strategy = Strategy.ALWAYS_LEFT
			"ALWAYS_RIGHT": strategy = Strategy.ALWAYS_RIGHT
			"ALWAYS_CENTER": strategy = Strategy.ALWAYS_CENTER
			_: strategy = Strategy.MIXED
		_log("Config loaded: strategy=%s" % strat_name)


func _log_initial_state() -> void:
	if not _store:
		return
	var run: Dictionary = _store.state.get("run", {})
	var mission: Dictionary = run.get("mission", {})
	_log("--- INITIAL STATE ---")
	_log("life_essence=%d" % int(run.get("life_essence", 100)))
	_log("mission: type=%s total=%d description=\"%s\"" % [
		str(mission.get("type", "?")),
		int(mission.get("total", 0)),
		str(mission.get("description", "")),
	])
	var biome: String = str(run.get("current_biome", "?"))
	_log("biome=%s" % biome)
	_log("--- END INITIAL STATE ---")


func _auto_play_loop() -> void:
	_log("=== AUTO-PLAY LOOP STARTED ===")

	while _run_active and _cards_played < MAX_CARDS:
		if not is_inside_tree():
			_log("Removed from tree, aborting")
			break

		# Measure card generation time
		var gen_start := Time.get_ticks_msec()

		# Wait for card
		var card_ready := false
		while not card_ready:
			if not is_inside_tree():
				break
			if Time.get_ticks_msec() - gen_start > int(POLL_TIMEOUT_SEC * 1000.0):
				_log("TIMEOUT waiting for card #%d (%.0fs)" % [_cards_played + 1, POLL_TIMEOUT_SEC])
				_run_active = false
				break

			var is_proc: bool = _controller.get("is_processing") if "is_processing" in _controller else true
			var cur_card: Dictionary = _controller.get("current_card") if "current_card" in _controller else {}

			if not is_proc and not cur_card.is_empty():
				card_ready = true
			else:
				await get_tree().process_frame

		if not _run_active or not is_inside_tree():
			break

		# Check run ended during wait
		if _store:
			var run: Dictionary = _store.state.get("run", {})
			if not run.get("active", true):
				_log("Run ended during card wait")
				_run_active = false
				break

		var gen_time_ms: int = Time.get_ticks_msec() - gen_start
		_card_gen_times.append(gen_time_ms)

		# Capture pre-choice state
		_cards_played += 1
		var card: Dictionary = _controller.get("current_card")
		var pre_life: int = _get_life()
		var pre_karma: int = _controller.get("_karma") if "_karma" in _controller else 0

		# ---- DETAILED CARD LOG ----
		_log_card_detailed(card, gen_time_ms)

		# Pick option
		var option: int = _pick_option()
		var direction: String = ["left", "center", "right"][clampi(option, 0, 2)]
		var opt_label: String = _get_option_label(card, option)
		_log("CHOSEN=%s dir=%s label=\"%s\" strategy=%s" % [
			["A", "B", "C"][option], direction, opt_label, Strategy.keys()[strategy]])

		# Track source
		var tags: Array = card.get("tags", [])
		var source: String = _classify_source(card, tags)
		if source in ["llm_native", "llm_retry", "prefetch"]:
			_llm_count += 1
		else:
			_fallback_count += 1

		# Emit choice
		_ui.option_chosen.emit(option)
		_count_animation("card_choice")

		# Wait for resolution: detect current_card becoming empty (controller clears it)
		# Then the next loop iteration waits for the new card to appear.
		var resolve_start := Time.get_ticks_msec()
		var resolved := false
		while not resolved:
			if not is_inside_tree():
				break
			if Time.get_ticks_msec() - resolve_start > 300000:
				_log("TIMEOUT resolution card #%d (300s)" % _cards_played)
				_run_active = false
				break
			# Resolution detected when: current_card cleared OR is_processing goes false
			var cur_card2: Dictionary = _controller.get("current_card") if "current_card" in _controller else {}
			var is_proc2: bool = _controller.get("is_processing") if "is_processing" in _controller else false
			if cur_card2.is_empty() or not is_proc2:
				resolved = true
			else:
				await get_tree().process_frame

		if not _run_active or not is_inside_tree():
			break

		var resolve_time_ms: int = Time.get_ticks_msec() - resolve_start

		# Capture post-choice state
		var post_life: int = _get_life()
		var post_karma: int = _controller.get("_karma") if "_karma" in _controller else 0
		var life_delta: int = post_life - pre_life
		_total_life_drain += life_delta

		# Get D20/DC/outcome from quest_history
		var d20: int = 0
		var dc: int = 0
		var outcome: String = "?"
		if _controller and "_quest_history" in _controller:
			var history: Array = _controller.get("_quest_history")
			if not history.is_empty():
				var last: Dictionary = history[history.size() - 1]
				outcome = str(last.get("outcome", "?"))
				d20 = int(last.get("d20", 0))
				dc = int(last.get("dc", 0))

		# Get flux + mission
		var flux: Dictionary = {}
		var mission: Dictionary = {}
		if _store:
			flux = _store.state.get("run", {}).get("flux", {})
			mission = _store.state.get("run", {}).get("mission", {})

		# ---- DETAILED POST-CHOICE LOG ----
		_log("D20=%d DC=%d outcome=%s resolve_time=%dms" % [d20, dc, outcome, resolve_time_ms])
		_log("life:%d->%d (%+d) karma:%d->%d (%+d)" % [
			pre_life, post_life, life_delta,
			pre_karma, post_karma, post_karma - pre_karma])
		_log("flux: terre=%d esprit=%d lien=%d (total=%d)" % [
			int(flux.get("terre", 0)), int(flux.get("esprit", 0)), int(flux.get("lien", 0)),
			int(flux.get("terre", 0)) + int(flux.get("esprit", 0)) + int(flux.get("lien", 0))])
		_log("mission: %s %d/%d" % [str(mission.get("type", "?")), int(mission.get("progress", 0)), int(mission.get("total", 0))])
		_log("source=%s tags=%s" % [source, str(tags)])

		# Count animations
		_count_animation("card_entry")
		_count_animation("dice_roll")
		_count_animation("card_outcome")
		if life_delta != 0:
			_count_animation("life_delta_flash")
		_count_animation("travel_animation")

		# Record in run log
		_run_log.append({
			"card_num": _cards_played,
			"type": str(card.get("type", "?")),
			"speaker": str(card.get("speaker", "?")),
			"text": str(card.get("text", "")),
			"option": option,
			"direction": direction,
			"opt_label": opt_label,
			"d20": d20, "dc": dc, "outcome": outcome,
			"pre_life": pre_life, "post_life": post_life,
			"life_delta": life_delta,
			"pre_souffle": pre_souffle, "post_souffle": post_souffle,
			"karma_delta": post_karma - pre_karma,
			"source": source,
			"tags": tags.duplicate(),
			"gen_time_ms": gen_time_ms,
			"resolve_time_ms": resolve_time_ms,
			"flux": flux.duplicate(),
			"mission_type": str(mission.get("type", "")),
			"mission_progress": int(mission.get("progress", 0)),
			"mission_total": int(mission.get("total", 0)),
		})

		# Check run end
		if _store:
			var run: Dictionary = _store.state.get("run", {})
			if not run.get("active", true):
				_log("Run no longer active after card #%d" % _cards_played)
				_run_active = false
				break

		if is_inside_tree():
			await get_tree().create_timer(INTER_CARD_DELAY).timeout

	_print_summary()

	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)


func _log_card_detailed(card: Dictionary, gen_time_ms: int) -> void:
	_log("═══════════════════════════════════════")
	_log("=== CARD %d === (gen_time=%dms)" % [_cards_played, gen_time_ms])
	_log("═══════════════════════════════════════")

	var card_type: String = str(card.get("type", "narrative"))
	var speaker: String = str(card.get("speaker", "?"))
	var generated_by: String = str(card.get("_generated_by", "unknown"))
	var card_id: String = str(card.get("id", "?"))
	_log("id=%s type=%s speaker=%s generated_by=%s" % [card_id, card_type, speaker, generated_by])

	# FULL TEXT (no truncation)
	var text: String = str(card.get("text", ""))
	_log("text=\"%s\"" % text)
	_log("text_length=%d chars" % text.length())

	# All tags
	var tags: Array = card.get("tags", [])
	_log("tags=%s" % str(tags))

	# Options with full effects
	var options: Array = card.get("options", [])
	var labels := ["A (left)", "B (center)", "C (right)"]
	for i in range(mini(options.size(), 3)):
		var opt: Dictionary = options[i] if options[i] is Dictionary else {}
		var label: String = str(opt.get("label", "?"))
		var effects: Array = opt.get("effects", [])
		var cost: int = int(opt.get("cost", 0))
		var reward: String = str(opt.get("reward_type", "?"))
		var sequel: String = str(opt.get("sequel_hook", ""))
		var fx_str: String = _effects_to_string_detailed(effects)
		_log("  opt_%s: \"%s\" | effects=[%s] | cost=%d reward=%s%s" % [
			labels[i], label, fx_str, cost, reward,
			" sequel=\"%s\"" % sequel if not sequel.is_empty() else ""])

	# Result texts if present
	var result_success: String = str(card.get("result_success", ""))
	var result_failure: String = str(card.get("result_failure", ""))
	if not result_success.is_empty():
		_log("  result_success=\"%s\"" % result_success)
	if not result_failure.is_empty():
		_log("  result_failure=\"%s\"" % result_failure)


func _effects_to_string_detailed(effects: Array) -> String:
	var parts: Array[String] = []
	for e in effects:
		if e is Dictionary:
			var etype: String = str(e.get("type", "?"))
			var amount: String = str(e.get("amount", "?"))
			var aspect: String = str(e.get("aspect", ""))
			if not aspect.is_empty():
				parts.append("%s(%s):%s" % [etype, aspect, amount])
			else:
				parts.append("%s:%s" % [etype, amount])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _get_option_label(card: Dictionary, option: int) -> String:
	var options: Array = card.get("options", [])
	if option < options.size() and options[option] is Dictionary:
		return str(options[option].get("label", "?"))
	return "?"


func _classify_source(card: Dictionary, tags: Array) -> String:
	var gen_by: String = str(card.get("_generated_by", ""))
	var strategy_tag: String = str(card.get("_strategy", ""))
	if gen_by == "emergency_fallback":
		return "emergency_fallback"
	if tags.has("llm_generated") or strategy_tag == "adapter" or strategy_tag == "direct_c":
		return "llm_native"
	if tags.has("retry"):
		return "llm_retry"
	if tags.has("prefetch") or strategy_tag == "prefetch":
		return "prefetch"
	if tags.has("sequel"):
		return "sequel"
	if tags.has("fallback_pool"):
		return "fallback_pool"
	# Event/promise cards come from card system
	var card_type: String = str(card.get("type", ""))
	if card_type == "event":
		return "event_pool"
	if card_type == "promise":
		return "promise_pool"
	return "unknown"


func _pick_option() -> int:
	match strategy:
		Strategy.ALWAYS_LEFT: return 0
		Strategy.ALWAYS_RIGHT: return 2
		Strategy.ALWAYS_CENTER: return 1
		Strategy.RANDOM: return randi() % 3
		Strategy.MIXED:
			var r := randf()
			if r < 0.4: return 0
			elif r < 0.7: return 1
			else: return 2
	return 0


func _get_life() -> int:
	if _store and _store.has_method("get_life_essence"):
		return int(_store.get_life_essence())
	if _store:
		return int(_store.state.get("run", {}).get("life_essence", 100))
	return 100


func _on_run_ended(ending: Dictionary) -> void:
	_log("=== RUN ENDED (signal) ===")
	_log("ending=%s" % str(ending))
	_run_active = false


func _count_animation(anim_name: String) -> void:
	_animations_log[anim_name] = int(_animations_log.get(anim_name, 0)) + 1


func _print_summary() -> void:
	var run_elapsed_ms: int = Time.get_ticks_msec() - _run_start_ms
	_log("")
	_log("═══════════════════════════════════════════════════════")
	_log("=== RUN SUMMARY ===")
	_log("═══════════════════════════════════════════════════════")
	_log("cards_played=%d / max=%d" % [_cards_played, MAX_CARDS])
	_log("strategy=%s" % Strategy.keys()[strategy])
	_log("total_run_time=%dms (%.1fs)" % [run_elapsed_ms, float(run_elapsed_ms) / 1000.0])

	# Card generation times
	if not _card_gen_times.is_empty():
		var sum_gen: int = 0
		var max_gen: int = 0
		var min_gen: int = 999999
		for t in _card_gen_times:
			sum_gen += t
			max_gen = maxi(max_gen, t)
			min_gen = mini(min_gen, t)
		@warning_ignore("integer_division")
		_log("card_gen_time: avg=%dms min=%dms max=%dms" % [
			sum_gen / _card_gen_times.size(), min_gen, max_gen])

	# Final state
	var final_life: int = _get_life()
	var final_karma: int = _controller.get("_karma") if _controller and "_karma" in _controller else 0
	_log("final_life=%d final_karma=%d" % [final_life, final_karma])

	# LLM stats
	_log("llm_cards=%d fallback_cards=%d llm_ratio=%.0f%%" % [
		_llm_count, _fallback_count,
		(float(_llm_count) / float(maxi(_llm_count + _fallback_count, 1))) * 100.0])

	# Outcomes from quest_history
	var outcomes: Dictionary = {"critical_success": 0, "success": 0, "failure": 0, "critical_failure": 0}
	var total_outcomes: int = 0
	if _controller and "_quest_history" in _controller:
		var history: Array = _controller.get("_quest_history")
		for entry in history:
			var o: String = str(entry.get("outcome", ""))
			if outcomes.has(o):
				outcomes[o] += 1
		total_outcomes = history.size()

	if total_outcomes > 0:
		_log("outcomes: crit_success=%d(%.0f%%) success=%d(%.0f%%) failure=%d(%.0f%%) crit_fail=%d(%.0f%%)" % [
			outcomes["critical_success"], float(outcomes["critical_success"]) / float(total_outcomes) * 100.0,
			outcomes["success"], float(outcomes["success"]) / float(total_outcomes) * 100.0,
			outcomes["failure"], float(outcomes["failure"]) / float(total_outcomes) * 100.0,
			outcomes["critical_failure"], float(outcomes["critical_failure"]) / float(total_outcomes) * 100.0,
		])

	# Life drain
	if _cards_played > 0:
		_log("total_life_change=%d avg_per_card=%.1f" % [_total_life_drain, float(_total_life_drain) / float(_cards_played)])

	# Mission
	if _store:
		var mission: Dictionary = _store.state.get("run", {}).get("mission", {})
		_log("mission: type=%s progress=%d/%d completed=%s" % [
			str(mission.get("type", "?")),
			int(mission.get("progress", 0)),
			int(mission.get("total", 0)),
			"YES" if int(mission.get("progress", 0)) >= int(mission.get("total", 1)) else "NO",
		])

	# Flux final
	if _store:
		var flux: Dictionary = _store.state.get("run", {}).get("flux", {})
		_log("final_flux: terre=%d esprit=%d lien=%d (total=%d)" % [
			int(flux.get("terre", 0)), int(flux.get("esprit", 0)), int(flux.get("lien", 0)),
			int(flux.get("terre", 0)) + int(flux.get("esprit", 0)) + int(flux.get("lien", 0))])

	# Minigame inventory
	_log("")
	_log("=== MINIGAME INVENTORY (15 available) ===")
	for mg in MINIGAME_LIST:
		_log("  %s" % mg)
	_log("(all skipped in headless mode — dice fallback used)")

	# Animation inventory
	_log("")
	_log("=== ANIMATION INVENTORY ===")
	for anim_name in _animations_log:
		_log("anim:%s count=%d" % [anim_name, _animations_log[anim_name]])

	# Per-card detail table
	_log("")
	_log("=== PER-CARD DETAIL TABLE ===")
	_log("# | Type | Dir | D20 | DC | Outcome | Life | Delta | Karma | Mission | Source | GenTime | Tags")
	_log("--|------|-----|-----|-----|---------|------|-------|-------|---------|--------|---------|-----")
	for e in _run_log:
		var tags_short: String = ""
		for t in e.get("tags", []):
			if str(t) != "fallback_pool":
				tags_short += str(t) + " "
		_log("%d | %s | %s | %d | %d | %s | %d->%d | %+d | %+d | %s %d/%d | %s | %dms | %s" % [
			e["card_num"], e["type"], e["direction"],
			e["d20"], e["dc"], e["outcome"],
			e["pre_life"], e["post_life"], e["life_delta"],
			e["karma_delta"],
			e["mission_type"], e["mission_progress"], e["mission_total"],
			e["source"], e["gen_time_ms"],
			tags_short.strip_edges(),
		])

	# Full text dump
	_log("")
	_log("=== FULL CARD TEXTS ===")
	for e in _run_log:
		_log("Card %d [%s]: \"%s\"" % [e["card_num"], e["source"], e["text"]])
		_log("  Chosen: %s \"%s\" -> %s (D20=%d DC=%d)" % [
			e["direction"], e["opt_label"], e["outcome"], e["d20"], e["dc"]])

	# Export structured JSON for AUTODEV stats pipeline
	_export_json_results(outcomes, total_outcomes)

	_log("")
	_log("=== AUTO-PLAY RUNNER END ===")


func _export_json_results(outcomes: Dictionary, total_outcomes: int) -> void:
	var final_life: int = 0
	var final_factions: Dictionary = {}
	var ending_type: String = "unknown"
	if _store:
		final_life = int(_store.state.get("run", {}).get("life_essence", 0))
		final_factions = _store.state.get("run", {}).get("faction_rep_delta", {})
		ending_type = str(_store.state.get("run", {}).get("ending", "survived"))

	var p50_gen: int = 0
	var p90_gen: int = 0
	var avg_gen: int = 0
	if _card_gen_times.size() > 0:
		var sorted: Array[int] = _card_gen_times.duplicate()
		sorted.sort()
		p50_gen = sorted[int(sorted.size() * 0.5)]
		p90_gen = sorted[mini(int(sorted.size() * 0.9), sorted.size() - 1)]
		var total_gen: int = 0
		for t in sorted:
			total_gen += t
		avg_gen = int(total_gen / sorted.size())

	var life_trajectory: Array[Dictionary] = []
	for e in _run_log:
		life_trajectory.append({
			"card": e["card_num"],
			"life_essence": e.get("life_essence", 0),
		})

	var result: Dictionary = {
		"strategy": Strategy.keys()[strategy],
		"cards_played": _cards_played,
		"final_life": final_life,
		"final_factions": final_factions,
		"ending_type": ending_type,
		"total_life_drain": _total_life_drain,
		"llm_count": _llm_count,
		"fallback_count": _fallback_count,
		"llm_ratio": float(_llm_count) / float(maxi(_llm_count + _fallback_count, 1)),
		"avg_gen_time_ms": avg_gen,
		"p50_gen_time_ms": p50_gen,
		"p90_gen_time_ms": p90_gen,
		"outcome_distribution": outcomes,
		"total_outcomes": total_outcomes,
		"life_trajectory": life_trajectory,
		"run_duration_ms": Time.get_ticks_msec() - _run_start_ms,
		"timestamp": Time.get_datetime_string_from_system(),
	}

	# Read output path from config, default to user://autoplay_results.json
	var output_path: String = "user://autoplay_results.json"
	var config_path: String = "user://autoplay_config.json"
	if FileAccess.file_exists(config_path):
		var cf: FileAccess = FileAccess.open(config_path, FileAccess.READ)
		if cf:
			var json: JSON = JSON.new()
			if json.parse(cf.get_as_text()) == OK and json.data is Dictionary:
				output_path = str(json.data.get("output_path", output_path))
			cf.close()

	var f: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()
		_log("JSON results exported to: %s" % output_path)
	else:
		_log("WARNING: Could not export JSON results to %s" % output_path)


func _find_node_by_class(class_name_str: String) -> Node:
	return _find_in_children(get_tree().root, class_name_str)


func _find_in_children(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	var script: Script = node.get_script()
	if script:
		var script_class: String = ""
		if script.has_method("get_global_name"):
			script_class = str(script.get_global_name())
		if script_class == class_name_str:
			return node
		var path: String = str(script.resource_path)
		if class_name_str == "MerlinGameController" and path.ends_with("merlin_game_controller.gd"):
			return node
		if class_name_str == "MerlinGameUI" and path.ends_with("merlin_game_ui.gd"):
			return node

	for child in node.get_children():
		var found: Node = _find_in_children(child, class_name_str)
		if found:
			return found
	return null


func _log(msg: String) -> void:
	print("[AUTOPLAY] %s" % msg)
