extends CanvasLayer
## EncounterCardOverlay — Shows a narrative card with 3 choices over the frozen 3D scene.
## Emits `card_resolved(choice_idx, score)` when the player picks and plays a minigame.
## Self-destructs after resolution.

class_name EncounterCardOverlay

signal card_resolved(choice_idx: int, score: int)

var _card_data: Dictionary = {}
var _bg: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _buttons: Array[Button] = []


func _init(card: Dictionary = {}) -> void:
	_card_data = card


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	# SFX
	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")

	# Dark overlay bg
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.02, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Fade in
	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.85, 0.6)

	var font: Font = MerlinVisual.get_font("terminal") if is_instance_valid(MerlinVisual) else null

	# Card panel (centered)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.15; _panel.anchor_right = 0.85
	_panel.anchor_top = 0.1; _panel.anchor_bottom = 0.9
	_panel.offset_left = 0; _panel.offset_right = 0
	_panel.offset_top = 0; _panel.offset_bottom = 0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.02, 0.95)
	panel_style.border_color = Color(0.12, 0.60, 0.24, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.theme = Theme.new()
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = str(_card_data.get("title", "Rencontre en Broceliande"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: _title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	vbox.add_child(_title_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Text body
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.text = str(_card_data.get("text", "Les brumes s'ecartent..."))
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.scroll_active = true
	if font: _text_label.add_theme_font_override("normal_font", font)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.2, 1.0, 0.4))
	vbox.add_child(_text_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# 3 Choice buttons
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
		if font: btn.add_theme_font_override("font", font)
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
		vbox.add_child(btn)
		_buttons.append(btn)


func _on_choice(idx: int) -> void:
	for btn in _buttons:
		btn.disabled = true

	var choice: Dictionary = {}
	var choices: Array = _card_data.get("choices", []) as Array
	if idx < choices.size() and choices[idx] is Dictionary:
		choice = choices[idx] as Dictionary

	# Try to launch a real minigame via MerlinMiniGameSystem
	# Detect lexical field from card text → launch matching minigame
	var card_text: String = str(_card_data.get("text", "")) + " " + str(choice.get("label", ""))
	var field: String = MiniGameRegistry.detect_field(card_text)
	var minigame: MiniGameBase = MiniGameRegistry.create_minigame(field, 5)

	var score: int = 0
	if minigame:
		print("[EncounterCard] Launching minigame: %s (field: %s)" % [minigame.get_class(), field])
		add_child(minigame)
		# Wait for minigame completion
		var result: Dictionary = await minigame.game_completed
		score = int(result.get("score", 50))
		minigame.queue_free()
	else:
		# Fallback: random score if no minigame available
		score = randi_range(40, 95)

	print("[EncounterCard] Choice %d → score %d (field: %s)" % [idx, score, field])

	# Show result with tier label
	var tier: String = "Echec critique" if score < 20 else ("Echec" if score < 50 else ("Reussite partielle" if score < 80 else ("Reussite!" if score < 95 else "Reussite critique!")))
	var tier_color: Color = Color(1.0, 0.2, 0.15) if score < 50 else (Color(1.0, 0.75, 0.2) if score < 80 else Color(0.2, 1.0, 0.4))

	_title_label.text = "%s — %d/100" % [tier, score]
	_title_label.add_theme_color_override("font_color", tier_color)
	_text_label.text = str(choice.get("label", "")) + "\n\nLes esprits de la foret repondent..."

	await get_tree().create_timer(2.5).timeout

	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.0, 0.5)
	fade_tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func():
		card_resolved.emit(idx, score)
		queue_free()
	)
