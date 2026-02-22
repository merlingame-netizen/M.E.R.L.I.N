extends Control

## TRIADE LLM Benchmark — Test card generation pipeline
## Tests: JSON quality, schema validation, parameter sweep, E2E mini-run

const VERSION := "1.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# TEST SCENARIOS — Different game states for card generation
# ═══════════════════════════════════════════════════════════════════════════════

const SCENARIOS := [
	{
		"name": "Equilibre",
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"souffle": 3, "day": 1, "cards_played": 0,
		"active_tags": [],
	},
	{
		"name": "Crise Corps (bas)",
		"aspects": {"Corps": -1, "Ame": 0, "Monde": 0},
		"souffle": 2, "day": 5, "cards_played": 12,
		"active_tags": ["danger"],
	},
	{
		"name": "Double crise (Corps+Ame)",
		"aspects": {"Corps": -1, "Ame": -1, "Monde": 0},
		"souffle": 1, "day": 8, "cards_played": 20,
		"active_tags": ["crisis", "combat"],
	},
	{
		"name": "Fin de jeu (Monde haut)",
		"aspects": {"Corps": 0, "Ame": 1, "Monde": 1},
		"souffle": 5, "day": 15, "cards_played": 40,
		"active_tags": ["endgame", "tyran"],
	},
	{
		"name": "Sans souffle",
		"aspects": {"Corps": 0, "Ame": 0, "Monde": -1},
		"souffle": 0, "day": 3, "cards_played": 8,
		"active_tags": ["nature"],
	},
]

const PARAM_SWEEP := [
	{"label": "Low temp", "max_tokens": 200, "temperature": 0.3, "top_p": 0.8, "top_k": 25, "repetition_penalty": 1.6},
	{"label": "Default", "max_tokens": 200, "temperature": 0.6, "top_p": 0.85, "top_k": 30, "repetition_penalty": 1.5},
	{"label": "High temp", "max_tokens": 200, "temperature": 0.9, "top_p": 0.95, "top_k": 50, "repetition_penalty": 1.3},
	{"label": "Short output", "max_tokens": 150, "temperature": 0.6, "top_p": 0.85, "top_k": 30, "repetition_penalty": 1.5},
]

# ═══════════════════════════════════════════════════════════════════════════════
# UI
# ═══════════════════════════════════════════════════════════════════════════════

var _log_label: RichTextLabel
var _running := false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 20)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "TRIADE LLM Benchmark v%s" % VERSION
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(title)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_add_button(btn_row, "Cartes TRIADE", _run_card_benchmark, Vector2(180, 40))
	_add_button(btn_row, "Sweep Params", _run_param_sweep, Vector2(160, 40))
	_add_button(btn_row, "Mini-Run E2E", _run_e2e, Vector2(150, 40))
	_add_button(btn_row, "Streaming", _run_streaming, Vector2(140, 40))
	_add_button(btn_row, "Clear Cache", _clear_cache, Vector2(130, 40))
	_add_button(btn_row, "Retour", _go_back, Vector2(100, 40))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 13)
	_log_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	scroll.add_child(_log_label)

	_log_label.text = "Pret. Choisissez un benchmark.\n\nTests disponibles:\n"
	_log_label.text += "  [color=cyan]Cartes TRIADE[/color] — 5 scenarios, mesure JSON valide + schema\n"
	_log_label.text += "  [color=cyan]Sweep Params[/color] — 4 configs temperature/tokens\n"
	_log_label.text += "  [color=cyan]Mini-Run E2E[/color] — 5 cartes jouees via pipeline complet\n"
	_log_label.text += "  [color=cyan]Streaming[/color] — TTFC + latence par chunk\n"


func _add_button(parent: Node, text: String, callback: Callable, min_size: Vector2) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _log(msg: String) -> void:
	_log_label.text += "\n" + msg


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")


func _clear_cache() -> void:
	var merlin_ai := get_node_or_null("/root/MerlinAI")
	if merlin_ai and merlin_ai.has_method("clear_response_cache"):
		merlin_ai.clear_response_cache()
	_log("[color=yellow]Cache cleared.[/color]")


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK 1: TRIADE Card Generation
# ═══════════════════════════════════════════════════════════════════════════════

func _run_card_benchmark() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== TRIADE CARD BENCHMARK ==========[/color]"

	var adapter := _get_adapter()
	if adapter == null:
		_running = false
		return

	var total_ok := 0
	var total_json_valid := 0
	var total_schema_valid := 0
	var total_3_options := 0
	var total_time_ms := 0

	for i in range(SCENARIOS.size()):
		var scenario: Dictionary = SCENARIOS[i]
		_log("\n[color=cyan]--- Scenario %d/%d: %s ---[/color]" % [i + 1, SCENARIOS.size(), scenario.name])
		_log("  Aspects: %s | Souffle: %d | Jour: %d" % [_format_aspects(scenario.aspects), scenario.souffle, scenario.day])

		var t0 := Time.get_ticks_msec()
		var result: Dictionary = await adapter.generate_card(scenario)
		var elapsed := Time.get_ticks_msec() - t0
		total_time_ms += elapsed

		if result.get("ok", false):
			total_ok += 1
			total_json_valid += 1
			total_schema_valid += 1
			var card: Dictionary = result.get("card", {})
			var options: Array = card.get("options", [])
			if options.size() == 3:
				total_3_options += 1

			_log("  [color=green]OK[/color] — %dms" % elapsed)
			_log("  Text: %s" % str(card.get("text", "")).substr(0, 80))
			_log("  Options: %d" % options.size())
			for j in range(options.size()):
				var opt: Dictionary = options[j]
				_log("    [%d] %s (effects: %d%s)" % [
					j, opt.get("label", "?"), opt.get("effects", []).size(),
					" cost:%d" % opt.cost if opt.has("cost") else ""
				])
			_log("  Tags: %s" % str(card.get("tags", [])))
		else:
			var err: String = str(result.get("error", "unknown"))
			var raw: String = str(result.get("raw", "")).substr(0, 120)
			_log("  [color=red]FAIL[/color] — %dms — %s" % [elapsed, err])
			if not raw.is_empty():
				_log("  Raw: %s" % raw)
				# Check if JSON was at least parseable
				var json_start := raw.find("{")
				if json_start >= 0:
					total_json_valid += 1

	# Summary
	_log("\n[color=gold]========== RESULTATS ==========[/color]")
	_log("  Cartes generees: %d/%d (%.0f%%)" % [total_ok, SCENARIOS.size(), total_ok / float(SCENARIOS.size()) * 100])
	_log("  JSON valide: %d/%d" % [total_json_valid, SCENARIOS.size()])
	_log("  Schema TRIADE valide: %d/%d" % [total_schema_valid, SCENARIOS.size()])
	_log("  3 options: %d/%d" % [total_3_options, SCENARIOS.size()])
	if total_ok > 0:
		_log("  Temps moyen: %dms" % (total_time_ms / SCENARIOS.size()))
	_log("[color=gold]========== FIN ==========[/color]")
	_running = false


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK 2: Parameter Sweep
# ═══════════════════════════════════════════════════════════════════════════════

func _run_param_sweep() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== PARAMETER SWEEP ==========[/color]"

	var merlin_ai := get_node_or_null("/root/MerlinAI")
	if not merlin_ai or not merlin_ai.is_ready:
		_log("[color=red]MerlinAI non pret.[/color]")
		_running = false
		return

	var adapter := MerlinLlmAdapter.new()
	adapter.set_merlin_ai(merlin_ai)

	var base_scenario: Dictionary = SCENARIOS[0]  # Equilibre
	var system_prompt: String = adapter._build_triade_system_prompt()
	var user_prompt: String = adapter._build_triade_user_prompt(base_scenario)

	for i in range(PARAM_SWEEP.size()):
		var params: Dictionary = PARAM_SWEEP[i]
		_log("\n[color=cyan]--- Config %d/%d: %s ---[/color]" % [i + 1, PARAM_SWEEP.size(), params.label])
		_log("  temp=%.1f top_p=%.2f top_k=%d max_tokens=%d rep=%.1f" % [
			params.temperature, params.top_p, params.top_k, params.max_tokens, params.repetition_penalty
		])

		var sweep_params := params.duplicate()
		sweep_params.erase("label")

		var t0 := Time.get_ticks_msec()
		var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, sweep_params)
		var elapsed := Time.get_ticks_msec() - t0

		var raw_text := str(result.get("text", ""))
		_log("  Latence: %dms | Reponse: %d chars" % [elapsed, raw_text.length()])

		if raw_text.is_empty():
			_log("  [color=red]Reponse vide[/color]")
			continue

		# Try parsing
		var parsed: Dictionary = adapter._extract_json_from_response(raw_text)
		if parsed.is_empty():
			_log("  [color=red]JSON invalide[/color]: %s" % raw_text.substr(0, 100))
			continue

		var validated: Dictionary = adapter.validate_triade_card(parsed)
		if validated.get("ok", false):
			var card: Dictionary = validated.get("card", {})
			_log("  [color=green]VALIDE[/color] — %d options" % card.get("options", []).size())
			_log("  Text: %s" % str(card.get("text", "")).substr(0, 80))
		else:
			_log("  [color=yellow]JSON ok mais schema invalide[/color]: %s" % str(validated.get("errors", [])))

	_log("\n[color=gold]========== SWEEP DONE ==========[/color]")
	_running = false


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK 3: Mini-Run E2E (5 cards auto-played)
# ═══════════════════════════════════════════════════════════════════════════════

func _run_e2e() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== MINI-RUN E2E (5 cartes) ==========[/color]"

	var adapter := _get_adapter()
	if adapter == null:
		_running = false
		return

	# Simulated game state
	var state := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"souffle": MerlinConstants.SOUFFLE_START,
		"day": 1,
		"cards_played": 0,
		"active_tags": [],
	}

	var ok_count := 0
	var fallback_count := 0

	for turn in range(5):
		_log("\n[color=cyan]--- Tour %d/5 ---[/color]" % (turn + 1))
		_log("  Etat: %s | Souffle: %d" % [_format_aspects(state.aspects), state.souffle])

		var t0 := Time.get_ticks_msec()
		var result: Dictionary = await adapter.generate_card(state)
		var elapsed := Time.get_ticks_msec() - t0

		var card: Dictionary
		if result.get("ok", false):
			card = result.get("card", {})
			ok_count += 1
			_log("  [color=green]LLM[/color] — %dms" % elapsed)
		else:
			# Fallback card
			card = _get_fallback_card()
			fallback_count += 1
			_log("  [color=yellow]FALLBACK[/color] — %s" % str(result.get("error", "")))

		_log("  Carte: %s" % str(card.get("text", "?")).substr(0, 70))

		# Auto-play: pick random option
		var options: Array = card.get("options", [])
		if options.is_empty():
			_log("  [color=red]Aucune option![/color]")
			continue

		var choice: int = randi() % options.size()
		var chosen: Dictionary = options[choice]
		_log("  Choix auto: [%d] %s" % [choice, chosen.get("label", "?")])

		# Apply effects to state
		for effect in chosen.get("effects", []):
			if typeof(effect) == TYPE_DICTIONARY and effect.get("type") == "SHIFT_ASPECT":
				var aspect: String = str(effect.get("aspect", ""))
				var direction: String = str(effect.get("direction", ""))
				if state.aspects.has(aspect):
					var current: int = int(state.aspects[aspect])
					if direction == "up":
						state.aspects[aspect] = mini(current + 1, 1)
					elif direction == "down":
						state.aspects[aspect] = maxi(current - 1, -1)

		# Deduct souffle for center option
		if chosen.has("cost") and int(chosen.cost) > 0:
			state.souffle = maxi(int(state.souffle) - int(chosen.cost), 0)

		state.cards_played = int(state.cards_played) + 1
		if int(state.cards_played) % 25 == 0:
			state.day = int(state.day) + 1

	_log("\n[color=gold]========== E2E RESULTATS ==========[/color]")
	_log("  LLM: %d/5 | Fallback: %d/5" % [ok_count, fallback_count])
	_log("  Etat final: %s | Souffle: %d" % [_format_aspects(state.aspects), state.souffle])
	_log("[color=gold]========== FIN ==========[/color]")
	_running = false


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK 4: Streaming
# ═══════════════════════════════════════════════════════════════════════════════

func _run_streaming() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== STREAMING BENCHMARK ==========[/color]"

	var merlin_ai := get_node_or_null("/root/MerlinAI")
	if not merlin_ai or not merlin_ai.is_ready:
		_log("[color=red]MerlinAI non pret.[/color]")
		_running = false
		return

	if not merlin_ai.has_method("generate_with_system_stream"):
		_log("[color=red]Streaming non disponible dans cette version de MerlinAI.[/color]")
		_running = false
		return

	var adapter := MerlinLlmAdapter.new()
	adapter.set_merlin_ai(merlin_ai)
	var system_prompt: String = adapter._build_triade_system_prompt()

	for i in range(mini(SCENARIOS.size(), 3)):
		var scenario: Dictionary = SCENARIOS[i]
		var user_prompt: String = adapter._build_triade_user_prompt(scenario)
		_log("\n[color=cyan]--- Stream %d/3: %s ---[/color]" % [i + 1, scenario.name])

		var chunks: Array = []
		var first_chunk_ms := 0
		var t0 := Time.get_ticks_msec()

		var on_chunk := func(chunk: String, _done: bool) -> void:
			if not chunk.is_empty() and chunks.is_empty():
				first_chunk_ms = Time.get_ticks_msec() - t0
			if not chunk.is_empty():
				chunks.append(chunk)

		var result: Dictionary = await merlin_ai.generate_with_system_stream(
			system_prompt, user_prompt, adapter.TRIADE_LLM_PARAMS, on_chunk
		)
		var total_ms := Time.get_ticks_msec() - t0
		var full_text := str(result.get("text", ""))

		_log("  TTFC: %dms | Total: %dms | Chunks: %d" % [first_chunk_ms, total_ms, chunks.size()])
		_log("  Reponse (%d chars): %s" % [full_text.length(), full_text.substr(0, 100)])

		# Try validating the streamed response
		var parsed: Dictionary = adapter._extract_json_from_response(full_text)
		if not parsed.is_empty():
			var validated: Dictionary = adapter.validate_triade_card(parsed)
			if validated.get("ok", false):
				_log("  [color=green]JSON TRIADE valide[/color]")
			else:
				_log("  [color=yellow]JSON ok, schema invalide[/color]")
		else:
			_log("  [color=red]JSON invalide[/color]")

	_log("\n[color=gold]========== STREAMING DONE ==========[/color]")
	_running = false


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_adapter() -> MerlinLlmAdapter:
	var merlin_ai := get_node_or_null("/root/MerlinAI")
	if not merlin_ai:
		_log("[color=red]MerlinAI non disponible.[/color]")
		return null
	if not merlin_ai.is_ready:
		_log("[color=red]LLM non pret. Attendez le warmup.[/color]")
		return null

	var adapter := MerlinLlmAdapter.new()
	adapter.set_merlin_ai(merlin_ai)
	_log("LLM ready. Model: %s" % str(merlin_ai.get_model_info()) if merlin_ai.has_method("get_model_info") else "LLM ready.")
	return adapter


func _format_aspects(aspects: Dictionary) -> String:
	var parts: Array[String] = []
	for aspect in ["Corps", "Ame", "Monde"]:
		var val: int = int(aspects.get(aspect, 0))
		var label := "="
		if val < 0:
			label = "v"
		elif val > 0:
			label = "^"
		parts.append("%s%s" % [aspect.substr(0, 1), label])
	return " ".join(parts)


func _get_fallback_card() -> Dictionary:
	return {
		"text": "Le silence enveloppe la clairiere.",
		"speaker": "merlin",
		"options": [
			{"label": "Observer", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}]},
			{"label": "Mediter", "cost": 1, "effects": []},
			{"label": "Avancer", "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}]},
		],
		"tags": ["fallback"],
	}
