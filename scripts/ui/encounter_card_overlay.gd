extends CanvasLayer
## EncounterCardOverlay — Narrative card with rune activation + 3 choices + minigame.
## Flow: Card appears → Rune phase (optional) → Choice → Minigame → Score → Fade.
## Emits `card_resolved(choice_idx, score)` then self-destructs.

class_name EncounterCardOverlay

signal card_resolved(choice_idx: int, score: int)

var _card_data: Dictionary = {}
var _bg: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _rune_container: HBoxContainer
var _rune_label: Label
var _skip_rune_btn: Button
var _buttons: Array[Button] = []
var _activated_ogham: String = ""
var _ogham_modifiers: Dictionary = {}
var _rune_phase_active: bool = false
var _font: Font


func _init(card: Dictionary = {}) -> void:
	_card_data = card


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")

	_font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null

	_build_bg()
	_build_panel()

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_build_title(vbox)
	vbox.add_child(HSeparator.new())
	_build_body(vbox)
	vbox.add_child(HSeparator.new())
	_build_rune_row(vbox)
	_build_choices(vbox)


func _build_bg() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.02, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	var tw: Tween = create_tween()
	tw.tween_property(_bg, "color:a", 0.85, 0.6)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.15; _panel.anchor_right = 0.85
	_panel.anchor_top = 0.1; _panel.anchor_bottom = 0.9
	_panel.offset_left = 0; _panel.offset_right = 0
	_panel.offset_top = 0; _panel.offset_bottom = 0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.02, 0.95)
	style.border_color = Color(0.12, 0.60, 0.24, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.theme = Theme.new()
	add_child(_panel)


func _build_title(parent: VBoxContainer) -> void:
	_title_label = Label.new()
	_title_label.text = str(_card_data.get("title", "Rencontre en Broceliande"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: _title_label.add_theme_font_override("font", _font)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	parent.add_child(_title_label)


func _build_body(parent: VBoxContainer) -> void:
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.text = str(_card_data.get("text", "Les brumes s'ecartent..."))
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.scroll_active = true
	if _font: _text_label.add_theme_font_override("normal_font", _font)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.2, 1.0, 0.4))
	parent.add_child(_text_label)


func _build_rune_row(parent: VBoxContainer) -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if not store or not store.has_method("get_available_oghams"):
		return

	var available: Array = store.get_available_oghams()
	if available.is_empty():
		return

	_rune_label = Label.new()
	_rune_label.text = "Activer une Rune ?"
	_rune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: _rune_label.add_theme_font_override("font", _font)
	_rune_label.add_theme_font_size_override("font_size", 14)
	_rune_label.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0))
	parent.add_child(_rune_label)

	_rune_container = HBoxContainer.new()
	_rune_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_rune_container.add_theme_constant_override("separation", 8)
	parent.add_child(_rune_container)

	for ogham_id in available:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		if spec.is_empty():
			continue
		var rune_btn: Button = Button.new()
		var unicode_char: String = str(spec.get("unicode", "?"))
		var ogham_name: String = str(spec.get("name", ogham_id))
		rune_btn.text = "%s %s" % [unicode_char, ogham_name]
		rune_btn.tooltip_text = str(spec.get("description", ""))
		rune_btn.custom_minimum_size = Vector2(0, 40)
		if _font: rune_btn.add_theme_font_override("font", _font)
		rune_btn.add_theme_font_size_override("font_size", 14)
		rune_btn.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0))
		rune_btn.add_theme_color_override("font_hover_color", Color(0.8, 0.6, 1.0))
		var rune_style: StyleBoxFlat = StyleBoxFlat.new()
		rune_style.bg_color = Color(0.04, 0.02, 0.08, 0.7)
		rune_style.border_color = Color(0.4, 0.3, 0.7, 0.4)
		rune_style.set_border_width_all(1)
		rune_style.set_corner_radius_all(4)
		rune_style.set_content_margin_all(6)
		rune_btn.add_theme_stylebox_override("normal", rune_style)
		var hover_style: StyleBoxFlat = rune_style.duplicate()
		hover_style.border_color = Color(0.6, 0.5, 1.0, 0.7)
		hover_style.bg_color = Color(0.06, 0.03, 0.12, 0.85)
		rune_btn.add_theme_stylebox_override("hover", hover_style)
		rune_btn.pressed.connect(_on_rune_selected.bind(ogham_id))
		_rune_container.add_child(rune_btn)

	_skip_rune_btn = Button.new()
	_skip_rune_btn.text = "Passer"
	_skip_rune_btn.custom_minimum_size = Vector2(0, 40)
	if _font: _skip_rune_btn.add_theme_font_override("font", _font)
	_skip_rune_btn.add_theme_font_size_override("font_size", 14)
	_skip_rune_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	var skip_style: StyleBoxFlat = StyleBoxFlat.new()
	skip_style.bg_color = Color(0.04, 0.04, 0.04, 0.5)
	skip_style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	skip_style.set_border_width_all(1)
	skip_style.set_corner_radius_all(4)
	skip_style.set_content_margin_all(6)
	_skip_rune_btn.add_theme_stylebox_override("normal", skip_style)
	_skip_rune_btn.pressed.connect(_on_rune_skipped)
	_rune_container.add_child(_skip_rune_btn)

	_rune_phase_active = true


func _build_choices(parent: VBoxContainer) -> void:
	var choices: Array = _card_data.get("choices", []) as Array
	if choices.is_empty():
		choices = [
			{"label": "Observer prudemment", "preview": "Sagesse"},
			{"label": "S'approcher avec respect", "preview": "Courage"},
			{"label": "Invoquer les esprits", "preview": "Mystique"},
		]

	for i in mini(choices.size(), 3):
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {"label": str(choices[i])}
		var btn: Button = Button.new()
		btn.text = str(choice.get("label", "..."))
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _font: btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.2))
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.03, 0.06, 0.03, 0.8)
		btn_style.border_color = Color(0.12, 0.60, 0.24, 0.3)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_s: StyleBoxFlat = btn_style.duplicate()
		hover_s.border_color = Color(1.0, 0.75, 0.2, 0.5)
		hover_s.bg_color = Color(0.05, 0.08, 0.03, 0.9)
		btn.add_theme_stylebox_override("hover", hover_s)
		btn.pressed.connect(_on_choice.bind(i))
		if _rune_phase_active:
			btn.disabled = true
		parent.add_child(btn)
		_buttons.append(btn)


func _on_rune_selected(ogham_id: String) -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if not store or not store.has_method("can_use_ogham"):
		_on_rune_skipped()
		return

	if not store.can_use_ogham(ogham_id):
		return

	_activated_ogham = ogham_id
	var result: Dictionary = await store.dispatch({"type": "USE_SKILL", "skill_id": ogham_id})
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})

	if result.get("ok", false):
		_ogham_modifiers = {"score_bonus": int(spec.get("tier", 0)) * 3}

		if is_instance_valid(SFXManager):
			SFXManager.play("rune_activate")

		_rune_label.text = "%s %s active !" % [str(spec.get("unicode", "")), str(spec.get("name", ogham_id))]
		_rune_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))

	_finish_rune_phase()


func _on_rune_skipped() -> void:
	_finish_rune_phase()


func _finish_rune_phase() -> void:
	if _rune_container:
		_rune_container.queue_free()
		_rune_container = null
	if _skip_rune_btn:
		_skip_rune_btn = null
	for btn in _buttons:
		btn.disabled = false


func _on_choice(idx: int) -> void:
	for btn in _buttons:
		btn.disabled = true

	var choice: Dictionary = {}
	var choices: Array = _card_data.get("choices", []) as Array
	if idx < choices.size() and choices[idx] is Dictionary:
		choice = choices[idx] as Dictionary

	var card_text: String = str(_card_data.get("text", "")) + " " + str(choice.get("label", ""))
	var field: String = MiniGameRegistry.detect_field(card_text)
	var minigame: MiniGameBase = MiniGameRegistry.create_minigame(field, 5, _ogham_modifiers)

	var score: int = 0
	if minigame:
		print("[EncounterCard] Minigame: %s (field: %s, ogham: %s)" % [minigame.get_class(), field, _activated_ogham])
		add_child(minigame)
		minigame.start()
		var timeout: SceneTreeTimer = get_tree().create_timer(30.0)
		timeout.timeout.connect(func() -> void:
			if not minigame._finished:
				print("[EncounterCard] Minigame timed out after 30s")
				minigame._complete(false, 50)
		, CONNECT_ONE_SHOT)
		var result: Dictionary = await minigame.game_completed
		score = int(result.get("score", 50))
		minigame.queue_free()
	else:
		score = randi_range(40, 95)

	print("[EncounterCard] Choice %d -> score %d (field: %s)" % [idx, score, field])
	_show_result(idx, score, choice)


func _show_result(idx: int, score: int, choice: Dictionary) -> void:
	var tier: String = _score_tier(score)
	var tier_color: Color = Color(1.0, 0.2, 0.15) if score < 50 else (Color(1.0, 0.75, 0.2) if score < 80 else Color(0.2, 1.0, 0.4))

	_title_label.text = "%s — %d/100" % [tier, score]
	_title_label.add_theme_color_override("font_color", tier_color)

	var response: String = _score_narrative(score)
	_text_label.text = str(choice.get("label", "")) + "\n\n" + response

	if _activated_ogham != "":
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(_activated_ogham, {})
		_text_label.text += "\n[%s %s]" % [str(spec.get("unicode", "")), str(spec.get("name", _activated_ogham))]

	if is_instance_valid(SFXManager):
		if score >= 80:
			SFXManager.play("success")
		elif score < 50:
			SFXManager.play("fail")
		else:
			SFXManager.play("neutral")

	var pulse_tw: Tween = create_tween()
	pulse_tw.tween_property(_bg, "color:a", 0.92, 0.2)
	pulse_tw.tween_property(_bg, "color:a", 0.85, 0.3)

	await get_tree().create_timer(2.5).timeout

	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.0, 0.5)
	fade_tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func() -> void:
		card_resolved.emit(idx, score)
		queue_free()
	)


static func _score_tier(score: int) -> String:
	if score < 20: return "Echec critique"
	if score < 50: return "Echec"
	if score < 80: return "Reussite partielle"
	if score < 95: return "Reussite!"
	return "Reussite critique!"


static func _score_narrative(score: int) -> String:
	if score >= 95:
		return "Les etoiles s'alignent. Le pouvoir des anciens coule en toi."
	if score >= 80:
		return "La foret approuve ton choix. Les esprits sourient."
	if score >= 50:
		return "Un resultat mitige. La brume hesite entre ombre et lumiere."
	if score >= 20:
		return "Les esprits detournent le regard. Le prix sera lourd."
	return "Un echec cuisant. La foret gronde de mecontentement."
