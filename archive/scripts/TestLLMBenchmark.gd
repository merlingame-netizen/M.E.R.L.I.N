extends Control

## LLM Benchmark — Mesure TTFT, latence totale, cache hits, tokens/sec
## Lance une série de prompts et affiche les résultats en temps réel

const BENCH_PROMPTS := [
	{"label": "Salut court", "system": "Reponds en 1 phrase.", "user": "Bonjour."},
	{"label": "Question simple", "system": "Reponds en 1 phrase.", "user": "Quel temps fait-il?"},
	{"label": "Merlin RP", "system": "Tu es Merlin, druide taquin. 1-2 phrases max.", "user": "Dis bonjour au joueur."},
	{"label": "Narration carte", "system": "Genere une carte narrative courte pour un jeu celtique.", "user": "Le joueur marche dans la foret."},
	{"label": "Classification", "system": "Reponds par UN MOT: combat, dialogue, exploration.", "user": "Je veux me battre."},
	{"label": "Cache hit (repeat)", "system": "Reponds en 1 phrase.", "user": "Bonjour."},
	{"label": "Longue reponse", "system": "Raconte une legende celtique en 3 phrases.", "user": "Parle-moi des druides."},
	{"label": "Streaming", "system": "Tu es Merlin. Court.", "user": "Que penses-tu du joueur?"},
]

const PARAMS_SHORT := {"max_tokens": 60, "temperature": 0.4, "top_p": 0.75, "top_k": 25, "repetition_penalty": 1.6}
const PARAMS_MED := {"max_tokens": 120, "temperature": 0.7, "top_p": 0.9, "top_k": 40, "repetition_penalty": 1.3}

var _log_label: RichTextLabel
var _results: Array[Dictionary] = []
var _running := false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 20)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "LLM Benchmark — Qwen2.5-3B-Instruct Q4_K_M"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(title)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_row)

	var run_btn := Button.new()
	run_btn.text = "Lancer Benchmark"
	run_btn.custom_minimum_size = Vector2(200, 40)
	run_btn.pressed.connect(_run_benchmark)
	btn_row.add_child(run_btn)

	var run_stream_btn := Button.new()
	run_stream_btn.text = "Benchmark Streaming"
	run_stream_btn.custom_minimum_size = Vector2(200, 40)
	run_stream_btn.pressed.connect(_run_streaming_benchmark)
	btn_row.add_child(run_stream_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Cache"
	clear_btn.custom_minimum_size = Vector2(150, 40)
	clear_btn.pressed.connect(_clear_cache)
	btn_row.add_child(clear_btn)

	var back_btn := Button.new()
	back_btn.text = "Retour"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	btn_row.add_child(back_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.fit_content = true
	_log_label.scroll_active = false
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	_log_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	scroll.add_child(_log_label)

	_log_label.text = "Pret. Cliquez sur 'Lancer Benchmark' pour demarrer.\n\nTests: %d prompts x 2 modes (generate_with_system + streaming)\nMetrics: TTFT, Total, Tokens/sec, Cache hits" % BENCH_PROMPTS.size()


func _log(msg: String) -> void:
	_log_label.text += "\n" + msg


func _clear_cache() -> void:
	var merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai and merlin_ai.has_method("clear_response_cache"):
		merlin_ai.clear_response_cache()
	_log("[color=yellow]Cache cleared.[/color]")


func _run_benchmark() -> void:
	if _running:
		return
	_running = true
	_results.clear()
	_log_label.text = "[color=gold]========== BENCHMARK START ==========[/color]"

	var merlin_ai = get_node_or_null("/root/MerlinAI")
	if not merlin_ai:
		_log("[color=red]MerlinAI non disponible.[/color]")
		_running = false
		return

	if not merlin_ai.is_ready:
		_log("[color=red]LLM non pret. Attendez le warmup.[/color]")
		_running = false
		return

	_log("Model: %s" % str(merlin_ai.get_model_info()))
	_log("Executor params: %s" % str(merlin_ai.get_executor_params()))
	_log("")

	# Reset stats
	if merlin_ai.has_method("reset_routing_stats"):
		merlin_ai.reset_routing_stats()

	for i in range(BENCH_PROMPTS.size()):
		var p: Dictionary = BENCH_PROMPTS[i]
		var params: Dictionary = PARAMS_SHORT if p.label.find("court") >= 0 or p.label.find("Classification") >= 0 else PARAMS_MED
		_log("[color=cyan]--- Test %d/%d: %s ---[/color]" % [i + 1, BENCH_PROMPTS.size(), p.label])
		_log("  System: %s" % p.system.substr(0, 60))
		_log("  User: %s" % p.user)
		_log("  Params: max_tokens=%d temp=%.1f rep=%.1f" % [params.max_tokens, params.temperature, params.repetition_penalty])

		var t0 := Time.get_ticks_msec()
		var result: Dictionary = await merlin_ai.generate_with_system(p.system, p.user, params)
		var elapsed := Time.get_ticks_msec() - t0

		var text := str(result.get("text", ""))
		var source := str(result.get("source", "llm"))
		var is_cache := source == "cache"

		var entry := {
			"label": p.label,
			"elapsed_ms": elapsed,
			"text_len": text.length(),
			"cached": is_cache,
			"text": text.substr(0, 80),
		}
		_results.append(entry)

		if is_cache:
			_log("  [color=green]CACHE HIT[/color] — %dms" % elapsed)
		else:
			_log("  [color=white]LLM[/color] — %dms" % elapsed)
		_log("  Reponse (%d chars): %s" % [text.length(), text.substr(0, 100)])
		_log("")

	# Summary
	_print_summary(merlin_ai)
	_running = false


func _run_streaming_benchmark() -> void:
	if _running:
		return
	_running = true
	_log_label.text = "[color=gold]========== STREAMING BENCHMARK ==========[/color]"

	var merlin_ai = get_node_or_null("/root/MerlinAI")
	if not merlin_ai or not merlin_ai.is_ready:
		_log("[color=red]MerlinAI non pret.[/color]")
		_running = false
		return

	if not merlin_ai.has_method("generate_with_system_stream"):
		_log("[color=red]Streaming non disponible.[/color]")
		_running = false
		return

	var test_prompts := BENCH_PROMPTS.slice(0, 4)
	for i in range(test_prompts.size()):
		var p: Dictionary = test_prompts[i]
		_log("[color=cyan]--- Stream %d/%d: %s ---[/color]" % [i + 1, test_prompts.size(), p.label])

		var chunks := []
		var first_chunk_ms := 0
		var t0 := Time.get_ticks_msec()

		var on_chunk := func(chunk: String, done: bool) -> void:
			if chunk != "" and chunks.is_empty():
				first_chunk_ms = Time.get_ticks_msec() - t0
			if chunk != "":
				chunks.append(chunk)

		var result: Dictionary = await merlin_ai.generate_with_system_stream(
			p.system, p.user, PARAMS_MED, on_chunk
		)
		var total_ms := Time.get_ticks_msec() - t0
		var full_text := str(result.get("text", ""))

		_log("  TTFC (first chunk): %dms" % first_chunk_ms)
		_log("  Total: %dms" % total_ms)
		_log("  Chunks: %d" % chunks.size())
		_log("  Reponse (%d chars): %s" % [full_text.length(), full_text.substr(0, 100)])
		_log("")

	_log("[color=gold]========== STREAMING BENCHMARK DONE ==========[/color]")
	_running = false


func _print_summary(merlin_ai: Node) -> void:
	_log("[color=gold]========== SUMMARY ==========[/color]")

	var total_ms := 0
	var llm_count := 0
	var cache_count := 0
	var llm_total_ms := 0

	for r in _results:
		total_ms += r.elapsed_ms
		if r.cached:
			cache_count += 1
		else:
			llm_count += 1
			llm_total_ms += r.elapsed_ms

	_log("Tests: %d total, %d LLM calls, %d cache hits" % [_results.size(), llm_count, cache_count])
	_log("Total time: %dms" % total_ms)
	if llm_count > 0:
		_log("Avg LLM latency: %dms" % (llm_total_ms / llm_count))
	_log("Cache hit rate: %.0f%%" % (cache_count / float(_results.size()) * 100.0))

	# MerlinAI internal stats
	if merlin_ai.has_method("get_performance_stats"):
		var perf: Dictionary = merlin_ai.get_performance_stats()
		_log("\nMerlinAI internal stats:")
		_log("  Avg TTFT: %s ms" % str(perf.get("avg_ttft_ms", "N/A")))
		_log("  Avg Total: %s ms" % str(perf.get("avg_total_ms", "N/A")))
		_log("  LLM calls: %s" % str(perf.get("llm_calls", 0)))

	if merlin_ai.has_method("get_routing_stats"):
		var routing: Dictionary = merlin_ai.get_routing_stats()
		_log("\nRouting stats:")
		_log("  FastRoute rate: %s" % str(routing.get("fast_route_rate", "N/A")))
		_log("  LLM route rate: %s" % str(routing.get("llm_route_rate", "N/A")))

	_log("\n[color=gold]========== BENCHMARK DONE ==========[/color]")
