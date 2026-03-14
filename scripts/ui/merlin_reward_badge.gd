## ═══════════════════════════════════════════════════════════════════════════════
## Reward Badge — Hover tooltip showing reward type for card options
## ═══════════════════════════════════════════════════════════════════════════════
## Displays a colored icon + keyword (e.g., red heart + "Vie") above the
## hovered option button. Uses MerlinConstants.REWARD_TYPES for definitions
## and MerlinConstants.infer_reward_type() as fallback.
## ═══════════════════════════════════════════════════════════════════════════════

extends PanelContainer
class_name MerlinRewardBadge

var _icon_label: Label
var _text_label: Label
var _dc_label: Label
var _effect_label: Label
var _current_type: String = ""
var _vbox: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	_setup_style()
	_create_content()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.REWARD_BADGE.bg
	style.border_color = MerlinVisual.REWARD_BADGE.border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)


func _create_content() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

	# Row 1: Icon + type
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	_vbox.add_child(hbox)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(_icon_label)

	_text_label = Label.new()
	var font: Font = MerlinVisual.get_font("body")
	if font:
		_text_label.add_theme_font_override("font", font)
	_text_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
	hbox.add_child(_text_label)

	# Row 2: DC hint
	_dc_label = Label.new()
	_dc_label.add_theme_font_size_override("font_size", 11)
	_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_dc_label.add_theme_font_override("font", font)
	_vbox.add_child(_dc_label)

	# Row 3: Effect preview
	_effect_label = Label.new()
	_effect_label.add_theme_font_size_override("font_size", 11)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_effect_label.add_theme_font_override("font", font)
	_vbox.add_child(_effect_label)


## Shows the badge above a button for the given card option.
func show_for_option(option: Dictionary, above_node: Control) -> void:
	var reward_type: String = str(option.get("reward_type", ""))
	if reward_type.is_empty():
		reward_type = MerlinConstants.infer_reward_type(option.get("effects", []))

	var info: Dictionary = MerlinConstants.REWARD_TYPES.get(
		reward_type, MerlinConstants.REWARD_TYPES["mystere"]
	)
	_icon_label.text = str(info.get("icon", "?"))
	_text_label.text = str(info.get("label", "Mystere"))

	# Risk-based color: green for faible, orange for moyen, red for eleve
	var risk_level: String = str(option.get("risk_level", "moyen"))
	var badge_color: Color
	match risk_level:
		"faible":
			badge_color = MerlinVisual.CRT_PALETTE.get("primary", Color(0.2, 0.7, 0.3))
		"eleve":
			badge_color = MerlinVisual.CRT_PALETTE.get("danger", Color(0.8, 0.2, 0.2))
		_:
			var color_key: String = str(info.get("color_key", "amber"))
			badge_color = MerlinVisual.CRT_PALETTE.get(color_key, MerlinVisual.CRT_PALETTE.amber)

	_icon_label.add_theme_color_override("font_color", badge_color)
	_text_label.add_theme_color_override("font_color", badge_color)

	# DC hint
	var dc_hint: Dictionary = option.get("dc_hint", {})
	if not dc_hint.is_empty():
		var dc_min: int = int(dc_hint.get("min", 0))
		var dc_max: int = int(dc_hint.get("max", 0))
		var difficulty_word := "facile" if dc_max <= 10 else ("moyen" if dc_max <= 14 else "difficile")
		_dc_label.text = "DC %d-%d (%s)" % [dc_min, dc_max, difficulty_word]
		_dc_label.add_theme_color_override("font_color", badge_color.lerp(Color.WHITE, 0.3))
		_dc_label.visible = true
	else:
		_dc_label.visible = false

	# Effect preview
	var effects: Array = option.get("effects", [])
	if not effects.is_empty():
		var effect_parts: Array[String] = []
		for eff in effects:
			if eff is Dictionary:
				var eff_type: String = str(eff.get("type", ""))
				var amount: int = int(eff.get("amount", 0))
				match eff_type:
					"HEAL_LIFE":
						effect_parts.append("+%d Vie" % amount)
					"DAMAGE_LIFE":
						effect_parts.append("-%d Vie" % amount)
					"ADD_REPUTATION":
						var faction: String = str(eff.get("faction", ""))
						effect_parts.append("+%d %s" % [amount, faction.capitalize()])
					"ADD_ANAM":
						effect_parts.append("+%d Anam" % amount)
					"ADD_TENSION":
						effect_parts.append("+%d Tension" % amount)
					"CREATE_PROMISE":
						effect_parts.append("Promesse")
		if not effect_parts.is_empty():
			_effect_label.text = " | ".join(effect_parts)
			_effect_label.add_theme_color_override("font_color", badge_color.lerp(Color.WHITE, 0.5))
			_effect_label.visible = true
		else:
			_effect_label.visible = false
	else:
		_effect_label.visible = false

	_current_type = reward_type
	visible = true

	# Position above the button after layout settles
	if is_instance_valid(above_node):
		await get_tree().process_frame
		if is_instance_valid(above_node) and is_inside_tree():
			global_position = Vector2(
				above_node.global_position.x + above_node.size.x * 0.5 - size.x * 0.5,
				above_node.global_position.y - size.y - 8.0
			)


## Hides the badge.
func hide_badge() -> void:
	visible = false
	_current_type = ""
