class_name MenuPrincipalVoicePanel
extends RefCounted

## Combined Voice + LLM test panel for the main menu.

const VOICE_TEST_TEXT := "Bienvenue, voyageur. Je suis Merlin, le dernier druide de Broceliande."
const LLM_DEFAULT_PROMPT := "Dis bonjour au joueur."
const LLM_SYSTEM_PROMPT := "Tu es Merlin, druide taquin d'une lande celtique. Court, percutant, 1-2 phrases max. Tutoiement. Humour et metaphores naturelles."
const CONFIG_PATH := "user://settings.cfg"

const LLM_PARAMS_OVERRIDE := {
	"max_tokens": 60,
	"temperature": 0.4,
	"top_p": 0.75,
	"top_k": 25,
	"repetition_penalty": 1.6,
}

const PANEL_VOICE_LABELS := [
	"AC Voice (Animalese)",
	"Desactivee",
]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _host: Control
var _body_font: Font

var _voice_panel: CanvasLayer
var _voice_vb: Node
var _voice_pitch_slider: HSlider
var _voice_variation_slider: HSlider
var _voice_speed_slider: HSlider
var _voice_test_label: RichTextLabel
var _llm_test_badge: PanelContainer
var _voice_pitch_value: Label
var _voice_variation_value: Label
var _voice_speed_value: Label

var _panel_voice_idx: int = 0
var _panel_voice_bank: String = "default"
var _panel_preset: String = "Merlin"
var _panel_prompt_input: TextEdit

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func init(host: Control, body_font: Font) -> void:
	_host = host
	_body_font = body_font


func show() -> void:
	if _voice_panel and is_instance_valid(_voice_panel):
		_voice_panel.visible = true
		for child in _voice_panel.get_children():
			if child is Control:
				child.modulate.a = 0.0
				var tw := _host.create_tween()
				tw.tween_property(child, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		return
	_load_voice_settings()
	_build_panel()

# ---------------------------------------------------------------------------
# Settings persistence
# ---------------------------------------------------------------------------

func _load_voice_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		_panel_voice_idx = config.get_value("voice", "panel_idx", 0)
		_panel_voice_bank = config.get_value("voice", "bank", "default")
		_panel_preset = config.get_value("voice", "preset", "Merlin")

# ---------------------------------------------------------------------------
# Panel construction
# ---------------------------------------------------------------------------

func _build_panel() -> void:
	_voice_panel = CanvasLayer.new()
	_voice_panel.layer = 50
	_host.add_child(_voice_panel)

	# Dim background
	var dim := ColorRect.new()
	var black_base: Color = MerlinVisual.GBC.black
	dim.color = Color(black_base.r, black_base.g, black_base.b, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	_voice_panel.add_child(dim)

	# Scrollable panel
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.offset_left = -280
	scroll.offset_right = 280
	scroll.offset_top = -300
	scroll.offset_bottom = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_voice_panel.add_child(scroll)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	style.border_color = MerlinVisual.CRT_PALETTE.amber
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	style.shadow_size = 12
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	scroll.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Test Voix & LLM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _body_font:
		title.add_theme_font_override("font", _body_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Voice type selector
	var mode_row := _create_row(vbox, "Type voix :")
	var mode_opt := OptionButton.new()
	mode_opt.name = "PanelVoiceTypeOpt"
	for lbl in PANEL_VOICE_LABELS:
		mode_opt.add_item(lbl)
	mode_opt.selected = _panel_voice_idx
	mode_opt.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	mode_opt.item_selected.connect(func(idx: int):
		_panel_voice_idx = idx
		_update_voice_controls()
	)
	mode_row.add_child(mode_opt)

	# Sound bank (AC Voice only)
	var bank_row := _create_row(vbox, "Banque :")
	bank_row.name = "PanelBankRow"
	var bank_opt := OptionButton.new()
	bank_opt.name = "PanelBankOpt"
	var bank_names := ["default", "high", "low", "lowest", "med", "robot", "glitch", "whisper", "droid"]
	var bank_labels := {"default": "Classique", "high": "Aigu (Peppy)", "low": "Grave (Cranky)", "lowest": "Tres grave", "med": "Medium", "robot": "Robot Beep", "glitch": "Glitch Bot", "whisper": "Synth Whisper", "droid": "Droid (R2D2)"}
	for bname in bank_names:
		bank_opt.add_item(bank_labels.get(bname, bname))
		bank_opt.set_item_metadata(bank_opt.item_count - 1, bname)
	for i in range(bank_opt.item_count):
		if bank_opt.get_item_metadata(i) == _panel_voice_bank:
			bank_opt.selected = i
			break
	bank_opt.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	bank_opt.item_selected.connect(func(idx: int):
		_panel_voice_bank = bank_opt.get_item_metadata(idx)
		if _voice_vb and _voice_vb.has_method("set_sound_bank"):
			_voice_vb.set_sound_bank(_panel_voice_bank)
	)
	bank_row.add_child(bank_opt)

	# Preset (AC Voice only)
	var preset_row := _create_row(vbox, "Preset :")
	preset_row.name = "PanelPresetRow"
	var preset_opt := OptionButton.new()
	preset_opt.name = "PanelPresetOpt"
	var presets := ["Merlin", "Normal", "Grave", "Sage", "Mysterieux", "Joyeux", "Aigu", "Enfant"]
	for p in presets:
		preset_opt.add_item(p)
	for i in range(preset_opt.item_count):
		if preset_opt.get_item_text(i) == _panel_preset:
			preset_opt.selected = i
			break
	preset_opt.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	preset_opt.item_selected.connect(func(idx: int):
		_panel_preset = presets[idx]
		_on_preset_selected(idx)
	)
	preset_row.add_child(preset_opt)

	# Sliders
	_voice_pitch_slider = _create_slider(vbox, "Pitch", 0.5, 5.0, 3.2, "_voice_pitch_value")
	_voice_variation_slider = _create_slider(vbox, "Variation", 0.0, 1.0, 0.28, "_voice_variation_value")
	_voice_speed_slider = _create_slider(vbox, "Vitesse", 0.3, 2.5, 0.95, "_voice_speed_value")

	# LLM prompt input
	var prompt_lbl := Label.new()
	prompt_lbl.text = "Prompt LLM :"
	prompt_lbl.add_theme_font_size_override("font_size", 14)
	prompt_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	vbox.add_child(prompt_lbl)

	_panel_prompt_input = TextEdit.new()
	_panel_prompt_input.text = LLM_DEFAULT_PROMPT
	_panel_prompt_input.custom_minimum_size = Vector2(460, 50)
	_panel_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_prompt_input.scroll_fit_content_height = true
	_panel_prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_panel_prompt_input.add_theme_font_size_override("font_size", 14)
	_panel_prompt_input.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	var input_style := StyleBoxFlat.new()
	var white_base: Color = MerlinVisual.GBC.white
	input_style.bg_color = Color(white_base.r, white_base.g, white_base.b, 0.5)
	input_style.border_color = MerlinVisual.CRT_PALETTE.border
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(6)
	_panel_prompt_input.add_theme_stylebox_override("normal", input_style)
	vbox.add_child(_panel_prompt_input)

	# Test text display (output)
	_voice_test_label = RichTextLabel.new()
	_voice_test_label.text = ""
	_voice_test_label.bbcode_enabled = true
	_voice_test_label.fit_content = true
	_voice_test_label.scroll_active = false
	_voice_test_label.custom_minimum_size = Vector2(460, 40)
	if _body_font:
		_voice_test_label.add_theme_font_override("normal_font", _body_font)
	_voice_test_label.add_theme_font_size_override("normal_font_size", 15)
	_voice_test_label.add_theme_color_override("default_color", MerlinVisual.CRT_PALETTE.phosphor)
	vbox.add_child(_voice_test_label)

	# LLM source badge
	_llm_test_badge = LLMSourceBadge.create("static")
	_llm_test_badge.visible = false
	vbox.add_child(_llm_test_badge)

	# Buttons row 1
	var btn_row1 := HBoxContainer.new()
	btn_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row1.add_theme_constant_override("separation", 10)

	var test_voice_btn := _create_button("Test Voix", func(): _on_test_voice_only())
	btn_row1.add_child(test_voice_btn)

	var test_llm_btn := _create_button("Test LLM", func(): _on_test_llm_only())
	btn_row1.add_child(test_llm_btn)

	var test_both_btn := _create_button("Voix + LLM", func(): _on_test_voice_and_llm())
	btn_row1.add_child(test_both_btn)

	vbox.add_child(btn_row1)

	# Buttons row 2
	var btn_row2 := HBoxContainer.new()
	btn_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row2.add_theme_constant_override("separation", 10)

	var stop_btn := _create_button("Stop", func(): _on_voice_stop())
	btn_row2.add_child(stop_btn)

	var close_btn := _create_button("Fermer", func(): close())
	btn_row2.add_child(close_btn)

	vbox.add_child(btn_row2)

	# Initialize voicebox
	_setup_voicebox()
	_on_preset_selected(0)
	_update_voice_controls()

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _create_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	row.add_child(lbl)
	parent.add_child(row)
	return row


func _create_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(110, 36)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(callback)
	return btn


func _create_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float, value_var: String) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_val
	val_lbl.custom_minimum_size.x = 40
	val_lbl.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	val_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	hbox.add_child(val_lbl)

	if value_var == "_voice_pitch_value":
		_voice_pitch_value = val_lbl
	elif value_var == "_voice_variation_value":
		_voice_variation_value = val_lbl
	elif value_var == "_voice_speed_value":
		_voice_speed_value = val_lbl

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		_sync_voice_params()
	)

	parent.add_child(hbox)
	return slider

# ---------------------------------------------------------------------------
# Voice controls
# ---------------------------------------------------------------------------

func _update_voice_controls() -> void:
	if not _voice_panel:
		return
	var bank_row: Node = _find_node_recursive(_voice_panel, "PanelBankRow")
	var preset_row: Node = _find_node_recursive(_voice_panel, "PanelPresetRow")
	var is_ac: bool = (_panel_voice_idx == 0)
	if bank_row:
		bank_row.visible = is_ac
	if preset_row:
		preset_row.visible = is_ac


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_recursive(child, target_name)
		if found:
			return found
	return null


func _setup_voicebox() -> void:
	if _voice_vb and is_instance_valid(_voice_vb):
		return
	var script_path := "res://addons/acvoicebox/acvoicebox.gd"
	if ResourceLoader.exists(script_path):
		var scr: GDScript = load(script_path)
		if scr:
			_voice_vb = scr.new()
			_voice_vb.set("base_pitch", 3.2)
			_voice_vb.set("pitch_variation", 0.28)
			_voice_vb.set("speed_scale", 0.95)
			_host.add_child(_voice_vb)
			if _voice_vb.has_method("set_sound_bank"):
				_voice_vb.set_sound_bank(_panel_voice_bank)


func _sync_voice_params() -> void:
	if not _voice_vb or not is_instance_valid(_voice_vb):
		return
	if _voice_pitch_slider:
		_voice_vb.set("base_pitch", _voice_pitch_slider.value)
	if _voice_variation_slider:
		_voice_vb.set("pitch_variation", _voice_variation_slider.value)
	if _voice_speed_slider:
		_voice_vb.set("speed_scale", _voice_speed_slider.value)


func _on_preset_selected(index: int) -> void:
	var presets := ["Merlin", "Normal", "Grave", "Sage", "Mysterieux", "Joyeux", "Aigu", "Enfant"]
	if index < 0 or index >= presets.size():
		return
	_panel_preset = presets[index]
	if _voice_vb and _voice_vb.has_method("apply_preset"):
		_voice_vb.apply_preset(presets[index])
	if _voice_vb:
		if _voice_pitch_slider:
			_voice_pitch_slider.value = _voice_vb.get("base_pitch")
		if _voice_variation_slider:
			_voice_variation_slider.value = _voice_vb.get("pitch_variation")
		if _voice_speed_slider:
			_voice_speed_slider.value = _voice_vb.get("speed_scale")

# ---------------------------------------------------------------------------
# Test actions
# ---------------------------------------------------------------------------

func _on_test_voice_only() -> void:
	_on_voice_stop()
	if _panel_voice_idx == 0:
		_play_voice()


func _play_voice() -> void:
	if not _voice_vb or not is_instance_valid(_voice_vb):
		_setup_voicebox()
	if not _voice_vb:
		return
	_sync_voice_params()
	if _voice_vb.has_method("stop_speaking"):
		_voice_vb.stop_speaking()
	_voice_vb.set("text_label", _voice_test_label)
	_voice_test_label.text = VOICE_TEST_TEXT
	_voice_test_label.visible_characters = 0
	_voice_vb.play_string(VOICE_TEST_TEXT)


func _on_test_llm_only() -> void:
	_on_voice_stop()
	_voice_test_label.text = "Envoi au LLM..."
	_voice_test_label.visible_characters = -1

	var prompt := _get_prompt()
	var text: String = await _call_llm(prompt)
	_voice_test_label.text = text
	_voice_test_label.visible_characters = -1


func _on_test_voice_and_llm() -> void:
	_on_voice_stop()
	_voice_test_label.text = "Envoi au LLM..."
	_voice_test_label.visible_characters = -1

	var prompt := _get_prompt()
	var text: String = await _call_llm(prompt)

	if _panel_voice_idx == 0 and _voice_vb and is_instance_valid(_voice_vb):
		_sync_voice_params()
		_voice_vb.set("text_label", _voice_test_label)
		_voice_test_label.text = text
		_voice_test_label.visible_characters = 0
		_voice_vb.play_string(text)
	else:
		_voice_test_label.text = text
		_voice_test_label.visible_characters = -1


func _get_prompt() -> String:
	if _panel_prompt_input and _panel_prompt_input.text.strip_edges() != "":
		return _panel_prompt_input.text.strip_edges()
	return LLM_DEFAULT_PROMPT


func _update_llm_badge(source: String) -> void:
	if _llm_test_badge and is_instance_valid(_llm_test_badge):
		LLMSourceBadge.update_badge(_llm_test_badge, source)
		_llm_test_badge.visible = true


func _call_llm(user_prompt: String) -> String:
	var merlin_ai: Node = _host.get_node_or_null("/root/MerlinAI")
	if not merlin_ai:
		_update_llm_badge("error")
		return "MerlinAI non disponible."

	if merlin_ai.has_method("generate_with_system_stream"):
		var on_chunk := func(chunk: String, _done: bool) -> void:
			if _voice_test_label:
				var current := _voice_test_label.text
				if current == "Envoi au LLM..." or current == "Generation...":
					current = ""
				_voice_test_label.text = current + chunk
				_voice_test_label.visible_characters = -1
		_voice_test_label.text = "Generation..."
		var result: Dictionary = await merlin_ai.generate_with_system_stream(
			LLM_SYSTEM_PROMPT, user_prompt, LLM_PARAMS_OVERRIDE, on_chunk
		)
		if result.has("error"):
			_update_llm_badge("error")
			return "Erreur LLM: " + str(result.error)
		_update_llm_badge("llm")
		return _clean_llm_response(str(result.get("text", "")))

	if merlin_ai.has_method("generate_with_system"):
		var result: Dictionary = await merlin_ai.generate_with_system(
			LLM_SYSTEM_PROMPT, user_prompt, LLM_PARAMS_OVERRIDE
		)
		if result.has("error"):
			_update_llm_badge("error")
			return "Erreur LLM: " + str(result.error)
		_update_llm_badge("llm")
		return _clean_llm_response(str(result.get("text", "")))

	return "LLM: aucune methode disponible."


func _clean_llm_response(raw: String) -> String:
	var text := raw.strip_edges()
	var stop_tokens := [
		"<|im_end|>", "<|im_start|>", "<|endoftext|>",
		"<|im_end>", "<|im_start>", "<|endoftext>",
		"<im_end>", "<im_start>",
		"<|im_end", "<|im_start",
	]
	for stop_token in stop_tokens:
		var idx := text.find(stop_token)
		if idx >= 0:
			text = text.substr(0, idx)
	var regex := RegEx.new()
	regex.compile("<\\|?im_(?:end|start)\\|?>")
	text = regex.sub(text, "", true)
	regex.compile("<\\|?endoftext\\|?>")
	text = regex.sub(text, "", true)
	for prefix in ["system\n", "user\n", "assistant\n"]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length())
	text = text.strip_edges()
	if text == "":
		return "(Reponse vide du LLM)"
	return text

# ---------------------------------------------------------------------------
# Stop & Close
# ---------------------------------------------------------------------------

func _on_voice_stop() -> void:
	if _voice_vb and _voice_vb.has_method("stop_speaking"):
		_voice_vb.stop_speaking()
	if _voice_test_label:
		_voice_test_label.visible_characters = -1


func close() -> void:
	_on_voice_stop()
	if _voice_panel:
		var tw := _host.create_tween()
		for child in _voice_panel.get_children():
			if child is Control:
				tw.tween_property(child, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(): _voice_panel.visible = false)
