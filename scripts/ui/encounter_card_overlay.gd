extends CanvasLayer
## EncounterCardOverlay — CRT-styled narrative card with 3 choices.
## Emits card_resolved(choice_idx, score) after minigame. Self-destructs.

class_name EncounterCardOverlay

signal card_resolved(choice_idx: int, score: int)

const _FIELD_LABELS := {
	"chance": "Chance", "bluff": "Eloquence", "observation": "Observation",
	"logique": "Logique", "finesse": "Finesse", "vigueur": "Vigueur",
	"esprit": "Esprit", "perception": "Perception", "neutre": "Intuition",
}

const _FIELD_COLORS := {
	"chance": Color(1.0, 0.85, 0.3),
	"bluff": Color(0.9, 0.5, 1.0),
	"observation": Color(0.3, 0.85, 0.8),
	"logique": Color(0.5, 0.7, 1.0),
	"finesse": Color(1.0, 0.5, 0.3),
	"vigueur": Color(1.0, 0.3, 0.3),
	"esprit": Color(0.6, 1.0, 0.8),
	"perception": Color(0.8, 0.8, 0.5),
	"neutre": Color(0.6, 0.6, 0.6),
}

const _OGHAM_CAT_COLORS := {
	"reveal": Color(0.30, 0.85, 1.0),
	"protection": Color(1.0, 0.85, 0.30),
	"boost": Color(0.30, 1.0, 0.50),
	"narrative": Color(0.80, 0.50, 1.0),
	"recovery": Color(1.0, 0.50, 0.70),
	"special": Color(0.50, 0.90, 0.90),
}

var _card_data: Dictionary = {}
var _bg: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _buttons: Array[Button] = []
var _field_hints: Array[Label] = []
var _store: MerlinStore
var _ogham_buttons: Array[Button] = []
var _ogham_id_map: Dictionary = {}
var _ogham_used: bool = false


func _init(card: Dictionary = {}) -> void:
	_card_data = card


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	if is_instance_valid(SFXManager):
		SFXManager.play("card_draw")

	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(pal.bg_deep.r, pal.bg_deep.g, pal.bg_deep.b, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.88, 0.5)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.12; _panel.anchor_right = 0.88
	_panel.anchor_top = 0.08; _panel.anchor_bottom = 0.92
	_panel.offset_left = 0; _panel.offset_right = 0
	_panel.offset_top = 0; _panel.offset_bottom = 0
	_panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_panel_style(true))
	_panel.modulate.a = 0.0
	add_child(_panel)

	var panel_tw: Tween = create_tween()
	panel_tw.tween_property(_panel, "modulate:a", 1.0, 0.4).set_delay(0.15)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = str(_card_data.get("title", "Rencontre en Broceliande"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MerlinVisual.apply_responsive_font(_title_label, 26, "terminal")
	_title_label.add_theme_color_override("font_color", pal.amber)
	vbox.add_child(_title_label)

	var sep1: HSeparator = HSeparator.new()
	sep1.add_theme_color_override("separator", pal.border)
	vbox.add_child(sep1)

	# Body text
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.text = str(_card_data.get("text", "Les brumes s'ecartent..."))
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.scroll_active = true
	var body_font: Font = MerlinVisual.get_font("terminal")
	if body_font:
		_text_label.add_theme_font_override("normal_font", body_font)
	_text_label.add_theme_font_size_override("normal_font_size", MerlinVisual.responsive_size(16))
	_text_label.add_theme_color_override("default_color", pal.phosphor)
	vbox.add_child(_text_label)

	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_color_override("separator", pal.border)
	vbox.add_child(sep2)

	# Rune activation row (Bible s.2.2: activate before choosing)
	_store = get_node_or_null("/root/MerlinStore") as MerlinStore
	if _store:
		var equipped: Array = _store.state.get("oghams", {}).get("skills_equipped", [])
		if not equipped.is_empty():
			var cooldowns: Dictionary = _store.state.get("oghams", {}).get("skill_cooldowns", {})
			var rune_row: HBoxContainer = HBoxContainer.new()
			rune_row.alignment = BoxContainer.ALIGNMENT_CENTER
			rune_row.add_theme_constant_override("separation", 6)

			var rune_header: Label = Label.new()
			rune_header.text = "RUNES"
			rune_header.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(10))
			rune_header.add_theme_color_override("font_color", pal.phosphor_dim)
			rune_row.add_child(rune_header)

			for ogham_id in equipped:
				var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
				if spec.is_empty():
					continue
				var cat: String = str(spec.get("category", "special"))
				var cat_color: Color = _OGHAM_CAT_COLORS.get(cat, pal.phosphor_dim)
				var sym: String = str(spec.get("unicode", "\u25C6"))
				var ogham_name: String = str(spec.get("name", ogham_id))
				var cd: int = int(cooldowns.get(ogham_id, 0))

				var btn: Button = Button.new()
				if cd > 0:
					btn.text = "%s %s [%d]" % [sym, ogham_name, cd]
					btn.disabled = true
				else:
					btn.text = "%s %s" % [sym, ogham_name]
				MerlinVisual.apply_celtic_option_theme(btn, cat_color)
				MerlinVisual.apply_responsive_font(btn, 13, "terminal")
				btn.pressed.connect(_on_ogham_pressed.bind(ogham_id))
				rune_row.add_child(btn)
				_ogham_buttons.append(btn)
				_ogham_id_map[ogham_id] = btn

			rune_row.modulate.a = 0.0
			vbox.add_child(rune_row)
			var rune_tw: Tween = create_tween()
			rune_tw.tween_property(rune_row, "modulate:a", 1.0, 0.3).set_delay(0.25)

	# Choice buttons with field hints
	var choices: Array = _card_data.get("choices", []) as Array
	if choices.is_empty():
		choices = [
			{"label": "Observer prudemment", "preview": "Sagesse"},
			{"label": "S'approcher avec respect", "preview": "Courage"},
			{"label": "Invoquer les esprits", "preview": "Mystique"},
		]

	var card_text: String = str(_card_data.get("text", ""))
	var tags: Array = _card_data.get("tags", []) as Array

	for i in mini(choices.size(), 3):
		var choice: Dictionary = choices[i] if choices[i] is Dictionary else {"label": str(choices[i])}
		var choice_label: String = str(choice.get("label", "..."))

		var field: String = MiniGameRegistry.detect_field(
			card_text + " " + choice_label,
			str(choice.get("field", "")),
			tags
		)

		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn: Button = Button.new()
		btn.text = choice_label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent: Color = _FIELD_COLORS.get(field, pal.phosphor_dim)
		MerlinVisual.apply_celtic_option_theme(btn, accent)
		MerlinVisual.apply_responsive_font(btn, 17, "terminal")
		btn.pressed.connect(_on_choice.bind(i))
		row.add_child(btn)
		_buttons.append(btn)

		var hint: Label = Label.new()
		hint.text = "  %s" % _FIELD_LABELS.get(field, field)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hint.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(11))
		hint.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.6))
		row.add_child(hint)
		_field_hints.append(hint)

		row.modulate.a = 0.0
		vbox.add_child(row)

		var row_tw: Tween = create_tween()
		row_tw.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(0.4 + i * 0.12)


func _on_ogham_pressed(ogham_id: String) -> void:
	if _ogham_used or not _store:
		return
	_ogham_used = true
	for btn in _ogham_buttons:
		btn.disabled = true
	for btn in _buttons:
		btn.disabled = true

	var result: Dictionary = await _store.dispatch({"type": "USE_OGHAM", "skill_id": ogham_id})
	if not result.get("ok", false):
		_ogham_used = false
		var oghams_state: Dictionary = _store.state.get("oghams", {})
		var cooldowns: Dictionary = oghams_state.get("skill_cooldowns", {})
		for oid in _ogham_id_map:
			var b: Button = _ogham_id_map[oid] as Button
			if int(cooldowns.get(oid, 0)) <= 0:
				b.disabled = false
		for btn in _buttons:
			btn.disabled = false
		return

	for btn in _buttons:
		btn.disabled = false
	var activated_btn: Button = _ogham_id_map.get(ogham_id) as Button
	if activated_btn:
		var pal_ref: Dictionary = MerlinVisual.CRT_PALETTE
		activated_btn.text = activated_btn.text + " \u2713"
		activated_btn.add_theme_color_override("font_color", pal_ref.cyan_bright)
		activated_btn.disabled = true
		activated_btn.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(SFXManager):
		SFXManager.play("magic_reveal")


func _on_choice(idx: int) -> void:
	for btn in _buttons:
		btn.disabled = true
	for btn in _ogham_buttons:
		btn.disabled = true

	var choice: Dictionary = {}
	var choices: Array = _card_data.get("choices", []) as Array
	if idx < choices.size() and choices[idx] is Dictionary:
		choice = choices[idx] as Dictionary

	var card_text: String = str(_card_data.get("text", "")) + " " + str(choice.get("label", ""))
	var tags: Array = _card_data.get("tags", []) as Array
	var field: String = MiniGameRegistry.detect_field(card_text, str(choice.get("field", "")), tags)
	var minigame: MiniGameBase = MiniGameRegistry.create_minigame(field, 5)

	var score: int = 0
	if minigame:
		add_child(minigame)
		minigame.start()
		var result: Dictionary = await minigame.game_completed
		score = int(result.get("score", 50))
		minigame.queue_free()
	else:
		score = randi_range(40, 95)

	var pal: Dictionary = MerlinVisual.CRT_PALETTE

	# Result tier
	var tier: String
	var tier_color: Color
	if score >= 95:
		tier = "Reussite critique!"
		tier_color = pal.cyan_bright
	elif score >= 80:
		tier = "Reussite!"
		tier_color = pal.success
	elif score >= 50:
		tier = "Reussite partielle"
		tier_color = pal.amber
	elif score >= 20:
		tier = "Echec"
		tier_color = pal.amber_dim
	else:
		tier = "Echec critique"
		tier_color = pal.danger

	_title_label.text = "%s  %d/100" % [tier, score]
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

	_text_label.text = str(choice.get("label", "")) + "\n\n" + response

	if is_instance_valid(SFXManager):
		if score >= 80:
			SFXManager.play("success")
		elif score < 50:
			SFXManager.play("fail")
		else:
			SFXManager.play("neutral")

	var pulse_tw: Tween = create_tween()
	pulse_tw.tween_property(_bg, "color:a", 0.92, 0.2)
	pulse_tw.tween_property(_bg, "color:a", 0.88, 0.3)

	await get_tree().create_timer(2.5).timeout

	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(_bg, "color:a", 0.0, 0.5)
	fade_tw.parallel().tween_property(_panel, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func() -> void:
		card_resolved.emit(idx, score)
		queue_free()
	)
