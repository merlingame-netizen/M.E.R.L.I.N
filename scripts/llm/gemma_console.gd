extends Control
## GemmaConsole — Jalon 0 « Gemma parle » (PRIORITÉ #1, bible R96 / build plan §16).
## Dashboard debug : prompt envoyé + sortie (typewriter) + métriques perf.
## Prouve que le moteur natif Gemma 4 E2B tourne sur cette machine (dérisquage R94).
##
## Contrôles : prompt libre, régime créatif/structuré, max_tokens, Générer/Annuler.
## Métriques : temps total, tok/s approx, chars. (TTFT/seed = ajout C++ futur — non bindé.)

# Palette R70 (parchemin sombre)
const COL_BG: Color = Color("14100C")
const COL_SURFACE: Color = Color("2A2018")
const COL_TEXT: Color = Color("E8DCC0")
const COL_GOLD: Color = Color("C9A24B")
const COL_GREEN: Color = Color("4F6B3E")
const COL_VIOLET: Color = Color("7B4FA3")

const SYSTEM_TEST: String = "Tu es Merlin, maitre du jeu enigmatique de la foret de Broceliande. Reponds en francais, ton merveilleux-inquietant, bref et image."
const USER_TEST: String = "Le voyageur arrive a l'oree de la foret au crepuscule. Decris ce qu'il voit, en 2 phrases."

var _status: Label
var _prompt_edit: TextEdit
var _output: RichTextLabel
var _metrics: Label
var _gen_btn: Button
var _cancel_btn: Button
var _creative_chk: CheckButton
var _tokens_spin: SpinBox
var _full_text: String = ""


func _ready() -> void:
	_build_ui()
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.model_ready.connect(_on_model_ready)
		mn.model_failed.connect(_on_model_failed)
		mn.generation_finished.connect(_on_generation_finished)
		if mn.is_ready():
			_on_model_ready()
		else:
			_set_status("Chargement de Gemma 4 E2B...", COL_GOLD)
	else:
		_set_status("ERREUR : autoload MerlinNative absent", COL_VIOLET)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title: Label = Label.new()
	title.text = "GEMMA PARLE — Console debug (Gemma 4 E2B natif)"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	root.add_child(_status)

	var prompt_lbl: Label = Label.new()
	prompt_lbl.text = "Prompt (libre) :"
	prompt_lbl.add_theme_color_override("font_color", COL_TEXT)
	root.add_child(prompt_lbl)

	_prompt_edit = TextEdit.new()
	_prompt_edit.text = USER_TEST
	_prompt_edit.custom_minimum_size = Vector2(0, 120)
	_prompt_edit.add_theme_color_override("font_color", COL_TEXT)
	root.add_child(_prompt_edit)

	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	root.add_child(controls)

	_creative_chk = CheckButton.new()
	_creative_chk.text = "Creatif (temp 0.85)"
	_creative_chk.button_pressed = true
	_creative_chk.custom_minimum_size = Vector2(0, 44)
	controls.add_child(_creative_chk)

	var tok_lbl: Label = Label.new()
	tok_lbl.text = "max_tokens"
	tok_lbl.add_theme_color_override("font_color", COL_TEXT)
	controls.add_child(tok_lbl)

	_tokens_spin = SpinBox.new()
	_tokens_spin.min_value = 32
	_tokens_spin.max_value = 600
	_tokens_spin.step = 16
	_tokens_spin.value = 120
	_tokens_spin.custom_minimum_size = Vector2(0, 44)
	controls.add_child(_tokens_spin)

	_gen_btn = Button.new()
	_gen_btn.text = "Generer"
	_gen_btn.custom_minimum_size = Vector2(120, 44)
	_gen_btn.pressed.connect(_on_generate_pressed)
	_gen_btn.disabled = true
	controls.add_child(_gen_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Annuler"
	_cancel_btn.custom_minimum_size = Vector2(100, 44)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.disabled = true
	controls.add_child(_cancel_btn)

	var out_lbl: Label = Label.new()
	out_lbl.text = "Sortie de Gemma :"
	out_lbl.add_theme_color_override("font_color", COL_TEXT)
	root.add_child(out_lbl)

	var out_panel: PanelContainer = PanelContainer.new()
	out_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	out_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(out_panel)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_active = true
	_output.add_theme_color_override("default_color", COL_TEXT)
	_output.add_theme_font_size_override("normal_font_size", 18)
	out_panel.add_child(_output)

	_metrics = Label.new()
	_metrics.add_theme_color_override("font_color", COL_GOLD)
	_metrics.add_theme_font_size_override("font_size", 15)
	root.add_child(_metrics)


func _set_status(txt: String, col: Color) -> void:
	if _status != null:
		_status.text = txt
		_status.add_theme_color_override("font_color", col)


func _on_model_ready() -> void:
	_set_status("Modele PRET — Gemma 4 E2B (n_ctx=4096, natif, zero Ollama)", COL_GREEN)
	if _gen_btn != null:
		_gen_btn.disabled = false
	# Auto-test : prouve que la generation tourne (utile en smoke + a l'ouverture).
	_run_generation(SYSTEM_TEST, USER_TEST)


func _on_model_failed(reason: String) -> void:
	_set_status("ECHEC chargement modele : %s" % reason, COL_VIOLET)


func _on_generate_pressed() -> void:
	var user_text: String = _prompt_edit.text.strip_edges()
	if user_text.is_empty():
		return
	_run_generation(SYSTEM_TEST, user_text)


func _on_cancel_pressed() -> void:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.cancel()


func _run_generation(system_text: String, user_text: String) -> void:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null or not mn.is_ready() or mn.is_busy():
		return
	_gen_btn.disabled = true
	_cancel_btn.disabled = false
	_output.text = ""
	_set_status("Generation en cours...", COL_GOLD)
	_metrics.text = ""
	var opts: Dictionary = {
		"creative": _creative_chk.button_pressed,
		"max_tokens": int(_tokens_spin.value),
	}
	# Fire-and-forget : le résultat revient via le signal generation_finished.
	mn.generate(system_text, user_text, opts)


func _on_generation_finished(result: Dictionary) -> void:
	_gen_btn.disabled = false
	_cancel_btn.disabled = true
	var mn: Node = get_node_or_null("/root/MerlinNative")
	var metrics: Dictionary = mn.last_metrics() if mn != null else {}
	if result.has("error"):
		_set_status("ERREUR : %s" % str(result["error"]), COL_VIOLET)
		_output.text = "[color=#7B4FA3]%s[/color]" % str(result["error"])
		return
	_set_status("Termine.", COL_GREEN)
	_full_text = str(result.get("text", "")).strip_edges()
	_typewriter(_full_text)
	var total_ms: int = int(metrics.get("total_ms", 0))
	var toks: int = int(metrics.get("approx_tokens", 0))
	var tps: float = float(metrics.get("tok_per_s", 0.0))
	_metrics.text = "total %d ms  |  ~%d tokens  |  ~%.1f tok/s  |  %d chars" % [total_ms, toks, tps, _full_text.length()]
	print("[GemmaConsole] %s" % _metrics.text)


func _typewriter(txt: String) -> void:
	_output.text = txt
	_output.visible_characters = 0
	var n: int = _output.get_total_character_count()
	if n <= 0:
		return
	var tw: Tween = create_tween()
	# ~60 chars/s (R63 typewriter).
	var dur: float = clampf(float(n) / 60.0, 0.3, 6.0)
	tw.tween_property(_output, "visible_characters", n, dur)
