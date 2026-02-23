extends Control

## TRIADE LLM Benchmark — Test card generation pipeline
## Tests: JSON quality, schema validation, parameter sweep, E2E mini-run

const VERSION := "2.0.0"

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

	_add_button(btn_row, "Cartes TRIADE", _run_card_benchmark, Vector2(160, 40))
	_add_button(btn_row, "Sweep Params", _run_param_sweep, Vector2(140, 40))
	_add_button(btn_row, "Mini-Run E2E", _run_e2e, Vector2(130, 40))
	_add_button(btn_row, "Perf (p50/p90)", _run_perf_benchmark, Vector2(140, 40))
	_add_button(btn_row, "Zero Fallback", _run_zero_fallback_test, Vector2(130, 40))
	_add_button(btn_row, "Clear Cache", _clear_cache, Vector2(110, 40))
	_add_button(btn_row, "Retour", _go_back, Vector2(90, 40))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", MerlinVisual.CAPTION_SMALL)
	_log_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	scroll.add_child(_log_label)

	_log_label.text = "Pret. Choisissez un benchmark.\n\nTests disponibles:\n"
	_log_label.text += "  [color=cyan]Cartes TRIADE[/color] — 5 scenarios, mesure JSON valide + schema\n"
	_log_label.text += "  [color=cyan]Sweep Params[/color] — 4 configs temperature/tokens\n"
	_log_label.text += "  [color=cyan]Mini-Run E2E[/color] — 5 cartes jouees via pipeline complet\n"
	_log_label.text += "  [color=cyan]Perf (p50/p90)[/color] — Cold/warm, percentiles, buffer hit rate\n"
	_log_label.text += "  [color=cyan]Zero Fallback[/color] — Assert 100% LLM, variete texte\n"


func _add_button(parent: Node, text: String, callback: Callable, min_size: Vector2) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _log(msg: String) -> void:
	_log_label.text += "\n" + msg


func _go_back() -> void:
	PixelTransition.transition_to("res://scenes/MenuPrincipal.tscn")


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
# BENCHMARK 4: Performance (cold/warm, p50/p90/p99, buffer hit rate)
# ═══════════════════════════════════════════════════════════════════════════════

const PERF_RUNS := 10

func _run_perf_benchmark() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== PERF BENCHMARK (cold/warm, percentiles) ==========[/color]"

	var adapter := _get_adapter()
	if adapter == null:
		_running = false
		return

	var latencies: Array[float] = []
	var cold_latency_ms := 0
	var warm_latencies: Array[float] = []

	# Cold start: first call after cache clear
	var merlin_ai := get_node_or_null("/root/MerlinAI")
	if merlin_ai and merlin_ai.has_method("clear_response_cache"):
		merlin_ai.clear_response_cache()
	_log("\n[color=cyan]--- COLD START ---[/color]")

	var t0 := Time.get_ticks_msec()
	var cold_result: Dictionary = await adapter.generate_card(SCENARIOS[0])
	cold_latency_ms = Time.get_ticks_msec() - t0
	latencies.append(float(cold_latency_ms))

	if cold_result.get("ok", false):
		_log("  [color=green]OK[/color] — %dms (cold)" % cold_latency_ms)
	else:
		_log("  [color=red]FAIL[/color] — %dms (cold) — %s" % [cold_latency_ms, str(cold_result.get("error", ""))])

	# Warm runs: PERF_RUNS x SCENARIOS
	_log("\n[color=cyan]--- WARM RUNS (%d x %d = %d calls) ---[/color]" % [
		PERF_RUNS, SCENARIOS.size(), PERF_RUNS * SCENARIOS.size()])

	var success_count := 0
	var fallback_count := 0
	var total_calls := PERF_RUNS * SCENARIOS.size()

	for run_idx in range(PERF_RUNS):
		for sc_idx in range(SCENARIOS.size()):
			var scenario: Dictionary = SCENARIOS[sc_idx]
			var tw := Time.get_ticks_msec()
			var result: Dictionary = await adapter.generate_card(scenario)
			var elapsed_ms: int = Time.get_ticks_msec() - tw
			var elapsed_f := float(elapsed_ms)
			latencies.append(elapsed_f)
			warm_latencies.append(elapsed_f)

			if result.get("ok", false):
				success_count += 1
			else:
				fallback_count += 1

			var status_color := "green" if elapsed_ms < 8000 else "red"
			if run_idx == 0:
				_log("  [color=%s]%s[/color] %dms — %s" % [
					status_color,
					"OK" if result.get("ok", false) else "FAIL",
					elapsed_ms, scenario.name])

		if run_idx > 0 and run_idx % 5 == 0:
			_log("  ... run %d/%d complete" % [run_idx, PERF_RUNS])

	# Compute percentiles
	latencies.sort()
	warm_latencies.sort()

	var p50 := _percentile(latencies, 50.0)
	var p90 := _percentile(latencies, 90.0)
	var p99 := _percentile(latencies, 99.0)
	var wp50 := _percentile(warm_latencies, 50.0)
	var wp90 := _percentile(warm_latencies, 90.0)

	var avg_ms := 0.0
	for l in latencies:
		avg_ms += l
	if not latencies.is_empty():
		avg_ms /= float(latencies.size())

	# Buffer/prefetch stats from MerlinOmniscient
	var omniscient := get_node_or_null("/root/MerlinAI")
	var buffer_stats := ""
	if omniscient and omniscient.has_method("get_generation_stats"):
		var gen_stats: Dictionary = omniscient.get_generation_stats()
		var prefetch_hits: int = int(gen_stats.get("prefetch_hits", 0))
		var prefetch_misses: int = int(gen_stats.get("prefetch_misses", 0))
		var prefetch_total: int = prefetch_hits + prefetch_misses
		var hit_rate := 0.0
		if prefetch_total > 0:
			hit_rate = float(prefetch_hits) / float(prefetch_total) * 100.0
		buffer_stats = "Prefetch hit rate: %.0f%% (%d/%d)" % [hit_rate, prefetch_hits, prefetch_total]

	# Report
	_log("\n[color=gold]========== PERF RESULTS ==========[/color]")
	_log("  Total calls:  %d (1 cold + %d warm)" % [latencies.size(), warm_latencies.size()])
	_log("  Success:      %d/%d (%.0f%%)" % [success_count, total_calls, float(success_count) / float(total_calls) * 100.0])
	_log("  Cold start:   %dms" % cold_latency_ms)
	_log("  [color=cyan]All (incl. cold):[/color]")
	_log("    p50: %.0fms | p90: %.0fms | p99: %.0fms" % [p50, p90, p99])
	_log("    avg: %.0fms | min: %.0fms | max: %.0fms" % [avg_ms, latencies[0], latencies[-1]])
	_log("  [color=cyan]Warm only:[/color]")
	_log("    p50: %.0fms | p90: %.0fms" % [wp50, wp90])
	if not buffer_stats.is_empty():
		_log("  %s" % buffer_stats)

	# Alerts
	if wp90 > 8000.0:
		_log("\n  [color=red]ALERT: warm p90 %.0fms > 8000ms threshold![/color]" % wp90)
	else:
		_log("\n  [color=green]OK: warm p90 %.0fms < 8000ms[/color]" % wp90)

	if fallback_count > 0:
		_log("  [color=red]ALERT: %d fallbacks detected (zero-fallback policy violated)[/color]" % fallback_count)
	else:
		_log("  [color=green]OK: 0 fallbacks (zero-fallback policy respected)[/color]")

	_log("[color=gold]========== FIN PERF ==========[/color]")
	_running = false


func _percentile(sorted_arr: Array[float], p: float) -> float:
	if sorted_arr.is_empty():
		return 0.0
	var k: float = (float(sorted_arr.size()) - 1.0) * p / 100.0
	var f_idx: int = int(k)
	var c_idx: int = f_idx + 1
	if c_idx >= sorted_arr.size():
		return sorted_arr[-1]
	return sorted_arr[f_idx] + (k - float(f_idx)) * (sorted_arr[c_idx] - sorted_arr[f_idx])


# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK 5: Zero Fallback Assertion Test
# ═══════════════════════════════════════════════════════════════════════════════

func _run_zero_fallback_test() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== ZERO FALLBACK ASSERTION ==========[/color]"

	var adapter := _get_adapter()
	if adapter == null:
		_running = false
		return

	var total := SCENARIOS.size()
	var llm_ok := 0
	var llm_fail := 0
	var texts_seen: Array[String] = []

	_log("\nGenerating %d cards — asserting ALL are LLM-generated (no static fallback)...\n" % total)

	for i in range(total):
		var scenario: Dictionary = SCENARIOS[i]
		_log("[color=cyan]--- %d/%d: %s ---[/color]" % [i + 1, total, scenario.name])

		var t0 := Time.get_ticks_msec()
		var result: Dictionary = await adapter.generate_card(scenario)
		var elapsed := Time.get_ticks_msec() - t0

		if result.get("ok", false):
			llm_ok += 1
			var card: Dictionary = result.get("card", {})
			var text: String = str(card.get("text", ""))
			texts_seen.append(text)
			_log("  [color=green]LLM OK[/color] — %dms — %s" % [elapsed, text.substr(0, 60)])
		else:
			llm_fail += 1
			_log("  [color=red]FAIL[/color] — %dms — %s" % [elapsed, str(result.get("error", ""))])

	# Variety check (Jaccard similarity between consecutive texts)
	var variety_ok := true
	if texts_seen.size() >= 2:
		for j in range(1, texts_seen.size()):
			var words_a: PackedStringArray = texts_seen[j - 1].to_lower().split(" ")
			var words_b: PackedStringArray = texts_seen[j].to_lower().split(" ")
			var set_a := {}
			for w in words_a:
				set_a[w] = true
			var intersection := 0
			var union_count: int = set_a.size()
			for w in words_b:
				if set_a.has(w):
					intersection += 1
				else:
					union_count += 1
			var jaccard := float(intersection) / float(maxi(union_count, 1))
			if jaccard > 0.7:
				variety_ok = false
				_log("  [color=yellow]WARN: Cards %d-%d too similar (Jaccard=%.2f)[/color]" % [j, j + 1, jaccard])

	# Report
	_log("\n[color=gold]========== ZERO FALLBACK RESULTS ==========[/color]")
	_log("  LLM success:  %d/%d" % [llm_ok, total])
	_log("  LLM fail:     %d/%d" % [llm_fail, total])

	if llm_fail == 0:
		_log("  [color=green]PASS: Zero fallback policy — all cards from LLM[/color]")
	else:
		_log("  [color=red]FAIL: %d cards failed LLM generation[/color]" % llm_fail)

	if variety_ok:
		_log("  [color=green]PASS: Text variety — no duplicate cards[/color]")
	else:
		_log("  [color=red]FAIL: Some cards too similar (possible repetition)[/color]")

	_log("[color=gold]========== FIN ==========[/color]")
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
