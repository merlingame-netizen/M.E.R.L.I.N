extends Control
## GemmaConsole — Jalon 0 « Gemma parle » (PRIORITÉ #1, bible R96 / build plan §16).
## Dashboard debug : prompt envoyé + sortie (typewriter) + métriques perf.
## Prouve que le moteur natif Gemma 4 E2B tourne sur cette machine (dérisquage R94).
##
## Contrôles : prompt libre, régime créatif/structuré, max_tokens, Générer/Annuler.
## Métriques : temps total, tok/s approx, chars. (TTFT/seed = ajout C++ futur — non bindé.)

# Palette R70 (parchemin sombre) — aliasée sur MerlinVisual (v10.13 A1)
const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_GREEN: Color = MerlinVisual.GREEN_DARK
const COL_VIOLET: Color = MerlinVisual.VIOLET
const COL_INK: Color = MerlinVisual.INK
const ORB_SCENE: PackedScene = preload("res://scenes/MerlinOrb.tscn")

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
var _tw: Tween
var _title_lbl: Label
var _controls_row: HBoxContainer
var _out_panel: PanelContainer
var _orb: Node = null


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

	_title_lbl = Label.new()
	_title_lbl.text = "GEMMA PARLE — Console debug"
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 26)
	var fnt_title: FontFile = _load_font(MerlinVisual.FONT_IM_FELL)
	if fnt_title != null:
		_title_lbl.add_theme_font_override("font", fnt_title)
	root.add_child(_title_lbl)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	var fnt_ui: FontFile = _load_font(MerlinVisual.FONT_DM_SANS)
	if fnt_ui != null:
		_status.add_theme_font_override("font", fnt_ui)
	root.add_child(_status)

	var prompt_lbl: Label = Label.new()
	prompt_lbl.text = "Prompt (libre) :"
	prompt_lbl.add_theme_color_override("font_color", COL_TEXT)
	if fnt_ui != null:
		prompt_lbl.add_theme_font_override("font", fnt_ui)
	root.add_child(prompt_lbl)

	_prompt_edit = TextEdit.new()
	_prompt_edit.text = USER_TEST
	_prompt_edit.custom_minimum_size = Vector2(0, 120)
	_prompt_edit.add_theme_color_override("font_color", COL_TEXT)
	root.add_child(_prompt_edit)

	_controls_row = HBoxContainer.new()
	_controls_row.add_theme_constant_override("separation", 16)
	root.add_child(_controls_row)

	_creative_chk = CheckButton.new()
	_creative_chk.text = "Creatif (temp 0.85)"
	_creative_chk.button_pressed = true
	_creative_chk.custom_minimum_size = Vector2(0, 44)
	_controls_row.add_child(_creative_chk)

	var tok_lbl: Label = Label.new()
	tok_lbl.text = "max_tokens"
	tok_lbl.add_theme_color_override("font_color", COL_TEXT)
	_controls_row.add_child(tok_lbl)

	_tokens_spin = SpinBox.new()
	_tokens_spin.min_value = 32
	_tokens_spin.max_value = 600
	_tokens_spin.step = 16
	_tokens_spin.value = 120
	_tokens_spin.custom_minimum_size = Vector2(0, 44)
	_controls_row.add_child(_tokens_spin)

	_gen_btn = MerlinClaudeUI.make_primary_button("Générer")
	_gen_btn.custom_minimum_size = Vector2(120, 44)
	_gen_btn.pressed.connect(_on_generate_pressed)
	_gen_btn.disabled = true
	_controls_row.add_child(_gen_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Annuler"
	_cancel_btn.custom_minimum_size = Vector2(100, 44)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.disabled = true
	MerlinVisual.apply_button_da(_cancel_btn)
	MerlinVisual.connect_button_feedback(_cancel_btn)
	_controls_row.add_child(_cancel_btn)

	var out_lbl: Label = Label.new()
	out_lbl.text = "Sortie de Gemma :"
	out_lbl.add_theme_color_override("font_color", COL_TEXT)
	if fnt_ui != null:
		out_lbl.add_theme_font_override("font", fnt_ui)
	root.add_child(out_lbl)

	_out_panel = PanelContainer.new()
	_out_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out_panel.add_theme_stylebox_override("panel", MerlinClaudeUI.panel_style())
	root.add_child(_out_panel)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_active = true
	_output.add_theme_color_override("default_color", COL_TEXT)
	_output.add_theme_font_size_override("normal_font_size", 18)
	var fnt_body: FontFile = _load_font(MerlinVisual.FONT_EB_GARAMOND)
	if fnt_body != null:
		_output.add_theme_font_override("normal_font", fnt_body)
	_out_panel.add_child(_output)

	_metrics = Label.new()
	_metrics.add_theme_color_override("font_color", COL_GOLD)
	_metrics.add_theme_font_size_override("font_size", 15)
	if fnt_ui != null:
		_metrics.add_theme_font_override("font", fnt_ui)
	root.add_child(_metrics)
	# MerlinOrb 96×96 top-right
	_orb = ORB_SCENE.instantiate()
	_orb.custom_minimum_size = Vector2(96, 96)
	_orb.size = Vector2(96, 96)
	_orb.position = Vector2(size.x - 96 - 24, 24)
	add_child(_orb)
	resized.connect(func() -> void:
		if _orb != null and is_instance_valid(_orb):
			_orb.position = Vector2(size.x - 96 - 24, 24))
	_animate_entrance()


func _process(delta: float) -> void:
	if MerlinWoodcut.tick_boil(delta):
		queue_redraw()


static func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is FontFile:
			return res as FontFile
	return null


func _set_status(txt: String, col: Color) -> void:
	if _status != null:
		_status.text = txt
		_status.add_theme_color_override("font_color", col)


func _on_model_ready() -> void:
	_set_status("Modele PRET — Gemma 4 E2B (n_ctx=4096, natif, zero Ollama)", COL_GREEN)
	if _gen_btn != null:
		_gen_btn.disabled = false
	if _orb != null and _orb.has_method("set_mood"):
		_orb.set_mood("neutral")
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
	if _orb != null and _orb.has_method("set_generating"):
		_orb.set_generating(true)
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
	if _orb != null and _orb.has_method("set_generating"):
		_orb.set_generating(false)
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


func _animate_entrance() -> void:
	_fade_in(_title_lbl, 0.00, 0.35)
	_fade_in(_status, 0.10, 0.30)
	_fade_in(_prompt_edit, 0.20, 0.40)
	_fade_in(_controls_row, 0.35, 0.35)
	_fade_in(_out_panel, 0.45, 0.45)
	_fade_in(_metrics, 0.55, 0.30)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _typewriter(txt: String) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_output.text = txt
	_output.visible_characters = 0
	var n: int = _output.get_total_character_count()
	if n <= 0:
		return
	var dur: float = clampf(float(n) / 60.0, 0.3, 6.0)
	_tw = create_tween()
	_tw.tween_property(_output, "visible_characters", n, dur)
