## ═══════════════════════════════════════════════════════════════════════════════
## LLM Skeleton Test Bench — Interactive parchment + map generation
## ═══════════════════════════════════════════════════════════════════════════════
## Full visual test scene: pick biome/ogham/params, generate skeleton (LLM or
## procedural), display animated parchment. Regenerate on the fly.
## Launch: godot --path . scenes/demo_parchment.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Control


# ── State ──────────────────────────────────────────────────────────────────

var _parchment: ParchmentDisplay = null
var _is_generating: bool = false

# ── UI refs ────────────────────────────────────────────────────────────────

var _sidebar: VBoxContainer = null
var _biome_option: OptionButton = null
var _ogham_option: OptionButton = null
var _rep_slider: HSlider = null
var _rep_value_label: Label = null
var _trust_slider: HSlider = null
var _trust_value_label: Label = null
var _runs_spin: SpinBox = null
var _weather_option: OptionButton = null
var _mode_option: OptionButton = null  # Procedural / LLM
var _generate_btn: Button = null
var _status_label: RichTextLabel = null
var _log_label: RichTextLabel = null
var _parchment_area: Control = null  # Right side where parchment appears


func _ready() -> void:
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		if event.keycode == KEY_G:
			_on_generate_pressed()


# ═══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Full background.
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.018, 0.012, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main split: sidebar (left 300px) + parchment area (right).
	var hsplit: HSplitContainer = HSplitContainer.new()
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.split_offset = 320
	add_child(hsplit)

	# ── LEFT SIDEBAR ──────────────────────────────────────────────────────
	var sidebar_scroll: ScrollContainer = ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 300
	hsplit.add_child(sidebar_scroll)

	var sidebar_panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.035, 0.025, 0.95)
	panel_style.border_color = Color(0.25, 0.2, 0.1)
	panel_style.border_width_right = 1
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	sidebar_panel.add_theme_stylebox_override("panel", panel_style)
	sidebar_scroll.add_child(sidebar_panel)

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 8)
	sidebar_panel.add_child(_sidebar)

	# Title.
	var title: Label = _make_header("SKELETON TEST BENCH")
	_sidebar.add_child(title)
	_sidebar.add_child(_make_sep())

	# Biome selector.
	_sidebar.add_child(_make_label("Biome"))
	_biome_option = OptionButton.new()
	_biome_option.add_theme_font_size_override("font_size", 13)
	var biome_idx: int = 0
	for biome_id in MerlinConstants.BIOMES:
		var biome_name: String = str(MerlinConstants.BIOMES[biome_id].get("name", biome_id))
		_biome_option.add_item(biome_name, biome_idx)
		_biome_option.set_item_metadata(biome_idx, biome_id)
		biome_idx += 1
	_sidebar.add_child(_biome_option)

	# Ogham selector.
	_sidebar.add_child(_make_label("Ogham"))
	_ogham_option = OptionButton.new()
	_ogham_option.add_theme_font_size_override("font_size", 13)
	var ogham_idx: int = 0
	for ogham_id in MerlinConstants.OGHAM_FULL_SPECS:
		var ogham_name: String = str(MerlinConstants.OGHAM_FULL_SPECS[ogham_id].get("name", ogham_id))
		_ogham_option.add_item("%s (%s)" % [ogham_name, ogham_id], ogham_idx)
		_ogham_option.set_item_metadata(ogham_idx, ogham_id)
		ogham_idx += 1
	_sidebar.add_child(_ogham_option)

	_sidebar.add_child(_make_sep())

	# Faction rep slider.
	_sidebar.add_child(_make_label("Reputation faction"))
	var rep_hbox: HBoxContainer = HBoxContainer.new()
	_rep_slider = HSlider.new()
	_rep_slider.min_value = 0
	_rep_slider.max_value = 100
	_rep_slider.value = 30
	_rep_slider.step = 5
	_rep_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rep_slider.value_changed.connect(_on_rep_changed)
	rep_hbox.add_child(_rep_slider)
	_rep_value_label = Label.new()
	_rep_value_label.text = "30"
	_rep_value_label.custom_minimum_size.x = 35
	_rep_value_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	_rep_value_label.add_theme_font_size_override("font_size", 13)
	rep_hbox.add_child(_rep_value_label)
	_sidebar.add_child(rep_hbox)

	# Trust slider.
	_sidebar.add_child(_make_label("Confiance Merlin"))
	var trust_hbox: HBoxContainer = HBoxContainer.new()
	_trust_slider = HSlider.new()
	_trust_slider.min_value = 0
	_trust_slider.max_value = 100
	_trust_slider.value = 50
	_trust_slider.step = 5
	_trust_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trust_slider.value_changed.connect(_on_trust_changed)
	trust_hbox.add_child(_trust_slider)
	_trust_value_label = Label.new()
	_trust_value_label.text = "50"
	_trust_value_label.custom_minimum_size.x = 35
	_trust_value_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	_trust_value_label.add_theme_font_size_override("font_size", 13)
	trust_hbox.add_child(_trust_value_label)
	_sidebar.add_child(trust_hbox)

	# Previous runs.
	_sidebar.add_child(_make_label("Runs precedents"))
	_runs_spin = SpinBox.new()
	_runs_spin.min_value = 0
	_runs_spin.max_value = 20
	_runs_spin.value = 0
	_runs_spin.step = 1
	_runs_spin.add_theme_font_size_override("font_size", 13)
	_sidebar.add_child(_runs_spin)

	# Weather override.
	_sidebar.add_child(_make_label("Meteo"))
	_weather_option = OptionButton.new()
	_weather_option.add_theme_font_size_override("font_size", 13)
	_weather_option.add_item("Auto (saison)", 0)
	_weather_option.set_item_metadata(0, "auto")
	var w_idx: int = 1
	for weather_id in MerlinConstants.WEATHER_TYPES:
		var tone: String = str(MerlinConstants.WEATHER_TYPES[weather_id].get("tone", ""))
		_weather_option.add_item("%s (%s)" % [weather_id, tone], w_idx)
		_weather_option.set_item_metadata(w_idx, weather_id)
		w_idx += 1
	_sidebar.add_child(_weather_option)

	_sidebar.add_child(_make_sep())

	# Generation mode.
	_sidebar.add_child(_make_label("Mode de generation"))
	_mode_option = OptionButton.new()
	_mode_option.add_theme_font_size_override("font_size", 13)
	_mode_option.add_item("Procedural (fallback)", 0)
	_mode_option.set_item_metadata(0, "procedural")
	_mode_option.add_item("LLM (Ollama)", 1)
	_mode_option.set_item_metadata(1, "llm")
	_sidebar.add_child(_mode_option)

	_sidebar.add_child(_make_sep())

	# Generate button.
	_generate_btn = Button.new()
	_generate_btn.text = "  GENERER SCENARIO  (G)"
	_generate_btn.custom_minimum_size.y = 44
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.6, 0.45, 0.08, 0.9)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 8
	btn_style.content_margin_right = 8
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	_generate_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.75, 0.55, 0.1, 0.95)
	_generate_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.45, 0.33, 0.06, 0.9)
	_generate_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_generate_btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_generate_btn.add_theme_font_size_override("font_size", 15)
	_generate_btn.pressed.connect(_on_generate_pressed)
	_sidebar.add_child(_generate_btn)

	_sidebar.add_child(_make_sep())

	# Status label.
	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.scroll_active = false
	_status_label.fit_content = true
	_status_label.add_theme_color_override("default_color", Color(0.6, 0.55, 0.2))
	_status_label.add_theme_font_size_override("normal_font_size", 12)
	_sidebar.add_child(_status_label)
	_update_status("Pret. Choisissez les parametres et cliquez Generer.")

	# Log area.
	_sidebar.add_child(_make_label("Log"))
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = true
	_log_label.custom_minimum_size.y = 200
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_color_override("default_color", Color(0.5, 0.45, 0.2, 0.8))
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	_sidebar.add_child(_log_label)

	# Keyboard hint.
	var hint: Label = Label.new()
	hint.text = "G = Generer | Echap = Quitter"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.35, 0.3, 0.15, 0.4))
	hint.add_theme_font_size_override("font_size", 11)
	_sidebar.add_child(hint)

	# ── RIGHT PARCHMENT AREA ─────────────────────────────────────────────
	_parchment_area = Control.new()
	_parchment_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parchment_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(_parchment_area)

	# Placeholder text.
	var placeholder: Label = Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Cliquez GENERER pour afficher le parchemin"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.add_theme_color_override("font_color", Color(0.3, 0.25, 0.12, 0.3))
	placeholder.add_theme_font_size_override("font_size", 20)
	_parchment_area.add_child(placeholder)


# ═══════════════════════════════════════════════════════════════════════════════
# GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _on_generate_pressed() -> void:
	if _is_generating:
		return
	_is_generating = true
	_generate_btn.disabled = true
	_update_status("[color=yellow]Generation en cours...[/color]")
	_log_msg("--- Nouvelle generation ---")

	# Gather params from UI.
	var biome_id: String = str(_biome_option.get_selected_metadata())
	var ogham_id: String = str(_ogham_option.get_selected_metadata())
	var rep_val: int = int(_rep_slider.value)
	var trust_val: int = int(_trust_slider.value)
	var runs_val: int = int(_runs_spin.value)
	var mode: String = str(_mode_option.get_selected_metadata())

	var weather_meta: String = str(_weather_option.get_selected_metadata())
	var weather: String = ""
	if weather_meta == "auto":
		var biome_data: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
		var season: String = str(biome_data.get("season", "printemps"))
		weather = MerlinSkeletonGenerator._pick_weather(season)
		_log_msg("Meteo auto: %s (saison %s)" % [weather, season])
	else:
		weather = weather_meta
		_log_msg("Meteo forcee: %s" % weather)

	_log_msg("Biome: %s | Ogham: %s | Rep: %d | Trust: %d | Runs: %d" % [
		biome_id, ogham_id, rep_val, trust_val, runs_val])

	var ctx: Dictionary = {
		"biome_id": biome_id,
		"ogham_id": ogham_id,
		"faction_rep": rep_val,
		"previous_runs": runs_val,
		"explored_detours": [],
		"weather": weather,
		"festival": MerlinSkeletonGenerator._detect_festival(),
		"trust_tier": MerlinSkeletonGenerator._trust_to_tier(trust_val),
		"trust_value": trust_val,
	}

	var graph: MerlinRunGraph = null

	if mode == "llm":
		graph = await _generate_llm(ctx)
	else:
		graph = _generate_procedural(ctx)

	if graph == null:
		_update_status("[color=red]Echec de generation.[/color]")
		_log_msg("[color=red]ERREUR: graph null[/color]")
		_is_generating = false
		_generate_btn.disabled = false
		return

	# Validate.
	var validation: Dictionary = graph.validate()
	if not validation["valid"]:
		_log_msg("[color=red]Validation echouee:[/color]")
		for err in validation["errors"]:
			_log_msg("  - %s" % err)
		_update_status("[color=red]Graph invalide (%d erreurs)[/color]" % validation["errors"].size())
		_is_generating = false
		_generate_btn.disabled = false
		return

	# Log graph stats.
	_log_msg("[color=green]VALIDE[/color] — %d noeuds main, %d detour, %d cartes est." % [
		graph.main_path.size(), graph.total_detour_nodes, graph.estimated_cards])
	_log_msg("Titre: %s" % graph.scenario_title)
	for nid in graph.main_path:
		var node: Dictionary = graph.nodes.get(nid, {})
		var det_txt: String = ""
		var det_entry: String = str(node.get("detour_entry", ""))
		if det_entry != "" and det_entry != "null" and det_entry != "<null>":
			det_txt = " [D:%s]" % det_entry
		_log_msg("  [%s] %s — %s%s" % [nid, str(node.get("type", "")), str(node.get("label", "")), det_txt])

	# Show parchment.
	await _show_parchment(graph)

	_update_status("[color=green]Generation complete. Re-generez a volonte.[/color]")
	_is_generating = false
	_generate_btn.disabled = false


func _generate_procedural(ctx: Dictionary) -> MerlinRunGraph:
	_log_msg("Mode: Procedural fallback")
	var t0: int = Time.get_ticks_msec()
	var graph: MerlinRunGraph = MerlinSkeletonGenerator._generate_procedural(ctx)
	var elapsed: int = Time.get_ticks_msec() - t0
	_log_msg("Generation procedurale: %d ms" % elapsed)
	return graph


func _generate_llm(ctx: Dictionary) -> MerlinRunGraph:
	_log_msg("Mode: LLM (Ollama)")

	# Check if MerlinAI autoload exists.
	var ai_node: Node = get_node_or_null("/root/MerlinAI")
	if ai_node == null:
		_log_msg("[color=yellow]MerlinAI autoload introuvable — fallback procedural[/color]")
		return _generate_procedural(ctx)

	# Build prompts.
	var system_prompt: String = LlmAdapterMapPrompt.build_system_prompt()
	var user_prompt: String = LlmAdapterMapPrompt.build_user_prompt(ctx)
	_log_msg("System prompt: %d chars" % system_prompt.length())
	_log_msg("User prompt: %d chars" % user_prompt.length())

	# Try calling generate_structured.
	var params: Dictionary = {
		"temperature": 0.4,
		"max_tokens": 1500,
		"skip_scene_contract": true,
	}

	_update_status("[color=yellow]Attente reponse LLM...[/color]")
	var t0: int = Time.get_ticks_msec()

	var has_method: bool = ai_node.has_method("generate_structured")
	if not has_method:
		_log_msg("[color=yellow]MerlinAI n'a pas generate_structured — fallback[/color]")
		return _generate_procedural(ctx)

	var result: Dictionary = await ai_node.generate_structured(system_prompt, user_prompt, "", params)
	var elapsed: int = Time.get_ticks_msec() - t0
	_log_msg("LLM response: %d ms" % elapsed)

	if result.has("error"):
		_log_msg("[color=red]LLM error: %s[/color]" % str(result["error"]))
		_log_msg("[color=yellow]Fallback procedural[/color]")
		return _generate_procedural(ctx)

	var raw_text: String = str(result.get("text", ""))
	if raw_text.is_empty():
		_log_msg("[color=red]LLM returned empty[/color]")
		return _generate_procedural(ctx)

	_log_msg("LLM raw: %d chars" % raw_text.length())
	# Show first 200 chars of raw response.
	var preview: String = raw_text.substr(0, 200).replace("\n", " ")
	_log_msg("Preview: %s..." % preview)

	# Parse JSON.
	var parsed: Dictionary = MerlinSkeletonGenerator._parse_json_response(raw_text)
	if parsed.is_empty():
		_log_msg("[color=red]JSON parse failed[/color]")
		return _generate_procedural(ctx)

	_log_msg("[color=green]JSON parse OK[/color] — %d nodes" % parsed.get("nodes", []).size())
	var graph: MerlinRunGraph = MerlinRunGraph.from_dict(parsed)
	return graph


# ═══════════════════════════════════════════════════════════════════════════════
# PARCHMENT DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

func _show_parchment(graph: MerlinRunGraph) -> void:
	# Remove placeholder.
	var placeholder: Node = _parchment_area.get_node_or_null("Placeholder")
	if placeholder:
		placeholder.queue_free()

	# Remove old parchment.
	if _parchment and is_instance_valid(_parchment):
		_parchment.queue_free()
		await get_tree().process_frame

	_parchment = ParchmentDisplay.new()
	_parchment.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parchment_area.add_child(_parchment)
	_parchment.reveal(graph)
	await _parchment.animation_finished
	_log_msg("Animation parchemin terminee.")


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_rep_changed(val: float) -> void:
	_rep_value_label.text = str(int(val))


func _on_trust_changed(val: float) -> void:
	_trust_value_label.text = str(int(val))


func _update_status(bbcode: String) -> void:
	if _status_label:
		_status_label.text = ""
		_status_label.append_text(bbcode)


func _log_msg(text: String) -> void:
	print("[TEST] %s" % text)
	if _log_label:
		_log_label.append_text(text + "\n")


func _make_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13))
	label.add_theme_font_size_override("font_size", 16)
	return label


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.2, 0.8))
	label.add_theme_font_size_override("font_size", 12)
	return label


func _make_sep() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	var style: StyleBoxLine = StyleBoxLine.new()
	style.color = Color(0.25, 0.2, 0.1, 0.3)
	style.thickness = 1
	sep.add_theme_stylebox_override("separator", style)
	return sep
