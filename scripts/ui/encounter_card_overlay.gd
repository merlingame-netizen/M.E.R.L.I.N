extends CanvasLayer
## EncounterCardOverlay v2 — Cinematic CRT card with typewriter text and staggered buttons.
## Emits card_resolved(choice_idx, score) when the player picks and plays a minigame.

class_name EncounterCardOverlay

signal card_resolved(choice_idx: int, score: int)

const _MINIGAME_TIMEOUT_SEC: float = 90.0

var _card_data: Dictionary = {}
var _bg: ColorRect
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _text_label: RichTextLabel
var _field_hint: Label
var _buttons: Array[Button] = []
var _font: Font


func _init(card: Dictionary = {}) -> void:
	_card_data = card


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	_font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null
	var P: Dictionary = MerlinVisual.CRT_PALETTE if is_instance_valid(MerlinVisual) else {}

	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.02, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.85, 0.6)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = P.get("bg_dark", Color(0.04, 0.08, 0.04, 0.95))
	panel_style.border_color = P.get("border", Color(0.12, 0.30, 0.14))
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.modulate.a = 0.0
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)

	# Title (starts empty for typewriter)
	_title_label = Label.new()
	_title_label.text = ""
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		_title_label.add_theme_font_override("font", _font)
	_title_label.add_theme_font_size_override("font_size", MerlinVisual.TITLE_SMALL if is_instance_valid(MerlinVisual) else 28)
	_title_label.add_theme_color_override("font_color", P.get("amber", Color(1.0, 0.75, 0.2)))
	_vbox.add_child(_title_label)

	var sep1: HSeparator = HSeparator.new()
	sep1.add_theme_color_override("separator", P.get("border", Color(0.12, 0.30, 0.14)))
	_vbox.add_child(sep1)

	# Body (starts empty for typewriter)
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.text = ""
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.scroll_active = true
	if _font:
		_text_label.add_theme_font_override("normal_font", _font)
	_text_label.add_theme_font_size_override("normal_font_size", MerlinVisual.BODY_SIZE if is_instance_valid(MerlinVisual) else 18)
	_text_label.add_theme_color_override("default_color", P.get("phosphor", Color(0.2, 1.0, 0.4)))
	_vbox.add_child(_text_label)

	# Field hint (hidden until buttons appear)
	_field_hint = Label.new()
	_field_hint.text = ""
	_field_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		_field_hint.add_theme_font_override("font", _font)
	_field_hint.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE if is_instance_valid(MerlinVisual) else 14)
	_field_hint.add_theme_color_override("font_color", P.get("cyan_dim", Color(0.15, 0.42, 0.40)))
	_field_hint.visible = false
	_vbox.add_child(_field_hint)

	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_color_override("separator", P.get("border", Color(0.12, 0.30, 0.14)))
	_vbox.add_child(sep2)

	_build_buttons(P)

	# Animate: panel fade in → typewriter title → typewriter body → stagger buttons
	var panel_tw: Tween = create_tween()
	panel_tw.tween_property(_panel, "modulate:a", 1.0, 0.4)
	panel_tw.tween_callback(_start_typewriter)


func _build_buttons(P: Dictionary) -> void:
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
		btn.custom_minimum_size = Vector2(0, MerlinVisual.MIN_TOUCH_TARGET if is_instance_valid(MerlinVisual) else 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _font:
			btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", MerlinVisual.BUTTON_SIZE if is_instance_valid(MerlinVisual) else 18)
		btn.add_theme_color_override("font_color", P.get("phosphor", Color(0.2, 1.0, 0.4)))
		btn.add_theme_color_override("font_hover_color", P.get("amber", Color(1.0, 0.75, 0.2)))
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = P.get("bg_panel", Color(0.06, 0.12, 0.06, 0.8))
		btn_style.border_color = P.get("phosphor_dim", Color(0.12, 0.60, 0.24, 0.3))
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_s: StyleBoxFlat = btn_style.duplicate()
		hover_s.border_color = P.get("amber", Color(1.0, 0.75, 0.2, 0.5))
		hover_s.bg_color = P.get("bg_highlight", Color(0.08, 0.16, 0.08, 0.9))
		btn.add_theme_stylebox_override("hover", hover_s)
		btn.pressed.connect(_on_choice.bind(i))
		btn.modulate.a = 0.0
		_vbox.add_child(btn)
		_buttons.append(btn)


func _start_typewriter() -> void:
	var title_text: String = str(_card_data.get("title", "Rencontre en Broceliande"))
	var body_text: String = str(_card_data.get("text", "Les brumes s'ecartent..."))
	var tw_delay: float = MerlinVisual.TW_DELAY if is_instance_valid(MerlinVisual) else 0.015
	var tw_punct: float = MerlinVisual.TW_PUNCT_DELAY if is_instance_valid(MerlinVisual) else 0.06

	# Typewriter title
	for ch_idx in title_text.length():
		_title_label.text += title_text[ch_idx]
		var delay: float = tw_punct if title_text[ch_idx] in ".,:;!?" else tw_delay
		await get_tree().create_timer(delay).timeout

	# Typewriter body
	for ch_idx in body_text.length():
		_text_label.text += body_text[ch_idx]
		var delay: float = tw_punct if body_text[ch_idx] in ".,:;!?" else tw_delay
		await get_tree().create_timer(delay).timeout

	# Detect and show field hint
	var card_text: String = str(_card_data.get("text", ""))
	var tags: Array = _card_data.get("tags", []) as Array
	var gm_hint: String = str(_card_data.get("field", ""))
	var field: String = MiniGameRegistry.detect_field(card_text, gm_hint, tags)
	var field_names: Dictionary = {
		"chance": "Chance", "bluff": "Bluff", "observation": "Observation",
		"logique": "Logique", "finesse": "Finesse", "vigueur": "Vigueur",
		"esprit": "Esprit", "perception": "Perception", "neutre": "Neutre",
	}
	_field_hint.text = "~ %s ~" % field_names.get(field, field.capitalize())
	_field_hint.visible = true

	# Stagger buttons in
	var stagger: float = MerlinVisual.OPTION_STAGGER_DELAY if is_instance_valid(MerlinVisual) else 0.12
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		var btn_tw: Tween = create_tween()
		btn_tw.set_ease(Tween.EASE_OUT)
		btn_tw.set_trans(Tween.TRANS_BACK)
		btn.position.y += 20.0
		btn_tw.tween_property(btn, "modulate:a", 1.0, 0.3)
		btn_tw.parallel().tween_property(btn, "position:y", btn.position.y - 20.0, 0.3)
		await get_tree().create_timer(stagger).timeout


func _on_choice(idx: int) -> void:
	for btn in _buttons:
		btn.disabled = true

	var choice: Dictionary = {}
	var choices: Array = _card_data.get("choices", []) as Array
	if idx < choices.size() and choices[idx] is Dictionary:
		choice = choices[idx] as Dictionary

	var card_text: String = str(_card_data.get("text", "")) + " " + str(choice.get("label", ""))
	var tags: Array = _card_data.get("tags", []) as Array
	var gm_hint: String = str(_card_data.get("field", ""))
	var field: String = MiniGameRegistry.detect_field(card_text, gm_hint, tags)
	var minigame: MiniGameBase = MiniGameRegistry.create_minigame(field, 5)

	var score: int = 0
	if minigame:
		print("[EncounterCard] Launching minigame (field: %s)" % field)
		add_child(minigame)
		minigame.start()

		# Timeout guard: if minigame hangs, auto-resolve with penalty score
		var timeout_timer: SceneTreeTimer = get_tree().create_timer(_MINIGAME_TIMEOUT_SEC)
		timeout_timer.timeout.connect(func() -> void:
			if is_instance_valid(minigame) and not minigame._finished:
				print("[EncounterCard] Minigame timed out after %ds" % int(_MINIGAME_TIMEOUT_SEC))
				minigame._complete(false, 15)
		)

		var result: Dictionary = await minigame.game_completed
		score = int(result.get("score", 50))
		if is_instance_valid(minigame) and not minigame.is_queued_for_deletion():
			minigame.queue_free()
	else:
		score = randi_range(40, 95)

	print("[EncounterCard] Choice %d -> score %d (field: %s)" % [idx, score, field])

	_show_result(idx, score, choice, field)


func _show_result(idx: int, score: int, choice: Dictionary, field: String) -> void:
	var P: Dictionary = MerlinVisual.CRT_PALETTE if is_instance_valid(MerlinVisual) else {}

	var tier: String = _score_tier(score)
	var tier_color: Color = P.get("danger", Color(1.0, 0.2, 0.15)) if score < 50 else (P.get("amber", Color(1.0, 0.75, 0.2)) if score < 80 else P.get("success", Color(0.2, 1.0, 0.4)))

	_title_label.text = "%s  %d/100" % [tier, score]
	_title_label.add_theme_color_override("font_color", tier_color)

	var response: String = _score_narrative(score)
	_text_label.text = str(choice.get("label", "")) + "\n\n" + response

	_field_hint.visible = false
	for btn in _buttons:
		btn.visible = false

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
	if score < 20:
		return "Echec critique"
	if score < 50:
		return "Echec"
	if score < 80:
		return "Reussite partielle"
	if score < 95:
		return "Reussite!"
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
