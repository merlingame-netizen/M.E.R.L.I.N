extends CanvasLayer
## EncounterCardOverlay v2 — Cinematic narrative card over frozen 3D scene.
## CRT/PSX styled: typewriter reveals, staggered options, minigame integration.
## Emits card_resolved(choice_idx, score) then self-destructs.

class_name EncounterCardOverlay

signal card_resolved(choice_idx: int, score: int)

const TW_CHAR_S: float = 0.022
const TW_PUNCT_S: float = 0.065
const BTN_STAGGER: float = 0.12
const RESULT_HOLD: float = 2.5
const EXIT_FADE: float = 0.5

var _card_data: Dictionary = {}
var _bg: ColorRect
var _card_panel: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _field_label: Label
var _btn_box: VBoxContainer
var _buttons: Array[Button] = []
var _typing: bool = false


func _init(card: Dictionary = {}) -> void:
	_card_data = card


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")
	_build_ui()
	_animate_entry()


func _unhandled_input(event: InputEvent) -> void:
	if not _typing:
		return
	if (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventKey and event.pressed and not event.echo):
		_typing = false


func _build_ui() -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var font: Font = MerlinVisual.get_font("terminal")

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.012, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	_card_panel = PanelContainer.new()
	_card_panel.anchor_left = 0.1
	_card_panel.anchor_right = 0.9
	_card_panel.anchor_top = 0.08
	_card_panel.anchor_bottom = 0.92
	_card_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_panel_style(true))
	_card_panel.modulate.a = 0.0
	add_child(_card_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_card_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font:
		_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(28))
	_title_label.add_theme_color_override("font_color", pal["amber"])
	vbox.add_child(_title_label)

	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = pal["border"]
	vbox.add_child(sep)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = false
	_body_label.text = ""
	_body_label.visible_characters = 0
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.scroll_active = true
	if font:
		_body_label.add_theme_font_override("normal_font", font)
	_body_label.add_theme_font_size_override("normal_font_size", MerlinVisual.responsive_size(17))
	_body_label.add_theme_color_override("default_color", pal["phosphor"])
	vbox.add_child(_body_label)

	_field_label = Label.new()
	_field_label.text = ""
	_field_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field_label.visible = false
	if font:
		_field_label.add_theme_font_override("font", font)
	_field_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(13))
	_field_label.add_theme_color_override("font_color", pal["phosphor_dim"])
	vbox.add_child(_field_label)

	var sep2: ColorRect = ColorRect.new()
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.color = Color(pal["border"].r, pal["border"].g, pal["border"].b, 0.4)
	vbox.add_child(sep2)

	_btn_box = VBoxContainer.new()
	_btn_box.add_theme_constant_override("separation", 8)
	_btn_box.visible = false
	vbox.add_child(_btn_box)

	var choices: Array = _card_data.get("choices", []) as Array
	if choices.is_empty():
		choices = [
			{"label": "Observer prudemment"},
			{"label": "S'approcher avec respect"},
			{"label": "Invoquer les esprits"},
		]
	var accents: Array[Color] = [pal["phosphor"], pal["amber"], pal["amber_dim"]]
	for i in mini(choices.size(), 3):
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {"label": str(choices[i])}
		var btn: Button = Button.new()
		btn.text = str(choice.get("label", "..."))
		btn.custom_minimum_size = Vector2(0, MerlinVisual.MIN_TOUCH_TARGET)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MerlinVisual.apply_celtic_option_theme(btn, accents[i])
		btn.modulate.a = 0.0
		btn.pressed.connect(_on_choice.bind(i))
		_btn_box.add_child(btn)
		_buttons.append(btn)


func _animate_entry() -> void:
	var bg_tw: Tween = create_tween()
	bg_tw.tween_property(_bg, "color:a", 0.85, 0.6)
	await bg_tw.finished

	var card_tw: Tween = create_tween()
	card_tw.tween_property(_card_panel, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	await card_tw.finished

	await _typewrite_label(_title_label, str(_card_data.get("title", "Rencontre en Broceliande")))
	await _typewrite_richtext(_body_label, str(_card_data.get("text", "Les brumes s'ecartent...")))

	var full_text: String = str(_card_data.get("text", ""))
	for c in _card_data.get("choices", []):
		if c is Dictionary:
			full_text += " " + str(c.get("label", ""))
	var field: String = MiniGameRegistry.detect_field(full_text)
	var field_names: Dictionary = {
		"chance": "Chance", "bluff": "Joute Verbale", "observation": "Observation",
		"logique": "Logique", "finesse": "Finesse", "vigueur": "Vigueur",
		"esprit": "Esprit", "perception": "Perception",
	}
	_field_label.text = "Epreuve : %s" % field_names.get(field, field.capitalize())
	_field_label.visible = true

	_btn_box.visible = true
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		var btn_tw: Tween = btn.create_tween()
		btn_tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(float(i) * BTN_STAGGER)
	if _buttons.size() > 0:
		await get_tree().create_timer(float(_buttons.size()) * BTN_STAGGER + 0.35).timeout
		if _buttons[0].is_inside_tree():
			_buttons[0].grab_focus()


func _on_choice(idx: int) -> void:
	for btn in _buttons:
		btn.disabled = true

	var choice: Dictionary = {}
	var choices: Array = _card_data.get("choices", []) as Array
	if idx < choices.size() and choices[idx] is Dictionary:
		choice = choices[idx] as Dictionary

	var card_text: String = str(_card_data.get("text", "")) + " " + str(choice.get("label", ""))
	var field: String = MiniGameRegistry.detect_field(card_text)
	var minigame: MiniGameBase = MiniGameRegistry.create_minigame(field, 5)

	_btn_box.visible = false
	_field_label.text = "Epreuve en cours..."

	var score: int = 0
	if minigame:
		add_child(minigame)
		minigame.start()
		var result: Dictionary = await minigame.game_completed
		score = int(result.get("score", 50))
		minigame.queue_free()
	else:
		score = randi_range(40, 95)

	await _show_result(idx, score, choice)


func _show_result(idx: int, score: int, choice: Dictionary) -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var tier: String
	var tier_color: Color

	if score >= 95:
		tier = "Reussite critique!"
		tier_color = pal["success"]
	elif score >= 80:
		tier = "Reussite"
		tier_color = pal["success"]
	elif score >= 50:
		tier = "Reussite partielle"
		tier_color = pal["amber"]
	elif score >= 20:
		tier = "Echec"
		tier_color = pal["amber_dim"]
	else:
		tier = "Echec critique"
		tier_color = pal["danger"]

	_title_label.text = "%s — %d/100" % [tier, score]
	_title_label.add_theme_color_override("font_color", tier_color)

	var response: String
	if score >= 95:
		response = "Les etoiles s'alignent. Le pouvoir des anciens coule en toi."
	elif score >= 80:
		response = "La foret approuve ton choix. Les esprits sourient."
	elif score >= 50:
		response = "Un resultat mitige. La brume hesite entre ombre et lumiere."
	elif score >= 20:
		response = "Les esprits detournent le regard. Le prix sera lourd."
	else:
		response = "Un echec cuisant. La foret gronde de mecontentement."

	_body_label.visible_characters = -1
	_body_label.text = str(choice.get("label", "")) + "\n\n" + response
	_field_label.visible = false

	if is_instance_valid(SFXManager):
		if score >= 80:
			SFXManager.play("success")
		elif score < 50:
			SFXManager.play("fail")
		else:
			SFXManager.play("neutral")

	var pulse: Tween = create_tween()
	pulse.tween_property(_bg, "color:a", 0.92, 0.15)
	pulse.tween_property(_bg, "color:a", 0.85, 0.25)

	await get_tree().create_timer(RESULT_HOLD).timeout

	var exit_tw: Tween = create_tween().set_parallel(true)
	exit_tw.tween_property(_bg, "color:a", 0.0, EXIT_FADE)
	exit_tw.tween_property(_card_panel, "modulate:a", 0.0, EXIT_FADE)
	await exit_tw.finished
	card_resolved.emit(idx, score)
	queue_free()


func _typewrite_label(label: Label, text: String) -> void:
	_typing = true
	label.text = ""
	for i in text.length():
		if not is_inside_tree() or not _typing:
			label.text = text
			_typing = false
			return
		label.text = text.substr(0, i + 1)
		var ch: String = text[i]
		var delay: float = TW_PUNCT_S if ch == "." or ch == "," or ch == ":" or ch == ";" or ch == "!" or ch == "?" else TW_CHAR_S
		await get_tree().create_timer(delay).timeout
	_typing = false


func _typewrite_richtext(label: RichTextLabel, text: String) -> void:
	_typing = true
	label.text = text
	label.visible_characters = 0
	for i in text.length():
		if not is_inside_tree() or not _typing:
			label.visible_characters = -1
			_typing = false
			return
		label.visible_characters = i + 1
		var ch: String = text[i]
		var delay: float = TW_PUNCT_S if ch == "." or ch == "," or ch == ":" or ch == ";" or ch == "!" or ch == "?" else TW_CHAR_S
		await get_tree().create_timer(delay).timeout
	label.visible_characters = -1
	_typing = false
