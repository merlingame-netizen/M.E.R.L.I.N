## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game UI — Main Gameplay Interface (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## UI for TRIADE system: 3 Aspects, 3 States, 3 Options per card.
## Celtic symbols: Sanglier (Corps), Corbeau (Ame), Cerf (Monde)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name TriadeGameUI

signal option_chosen(option: int)  # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)
signal pause_requested

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const ASPECT_COLORS := {
	"Corps": Color(0.8, 0.4, 0.2),   # Orange-brown (earth)
	"Ame": Color(0.5, 0.3, 0.7),     # Purple (spirit)
	"Monde": Color(0.3, 0.6, 0.4),   # Green (nature)
}

const STATE_LABELS := {
	MerlinConstants.AspectState.BAS: "\u25BC",
	MerlinConstants.AspectState.EQUILIBRE: "\u25CF",
	MerlinConstants.AspectState.HAUT: "\u25B2",
}

const SOUFFLE_ICON := "\u0DA7"  # Celtic spiral (Sinhala character shaped like a spiral)
const SOUFFLE_EMPTY := "\u25CB"

const OPTION_KEYS := {
	MerlinConstants.CardOption.LEFT: "A",
	MerlinConstants.CardOption.CENTER: "B",
	MerlinConstants.CardOption.RIGHT: "C",
}

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES (set by scene or dynamically created)
# ═══════════════════════════════════════════════════════════════════════════════

var aspect_panel: Control
var aspect_displays: Dictionary = {}  # {"Corps": {container, icon, state_indicator}}

var souffle_panel: Control
var souffle_display: HBoxContainer

var card_container: Control
var card_panel: Panel
var card_text: RichTextLabel
var card_speaker: Label

var options_container: HBoxContainer
var option_buttons: Array[Button] = []
var option_labels: Array[Label] = []

var info_panel: Control
var mission_label: Label
var cards_label: Label

var bestiole_wheel: BestioleWheelSystem
var _pixel_portrait: PixelCharacterPortrait
var _current_speaker_key: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var current_aspects: Dictionary = {}
var current_souffle: int = 3

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_ui()
	_update_aspects({
		"Corps": MerlinConstants.AspectState.EQUILIBRE,
		"Ame": MerlinConstants.AspectState.EQUILIBRE,
		"Monde": MerlinConstants.AspectState.EQUILIBRE,
	})
	_update_souffle(MerlinConstants.SOUFFLE_START)


const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"accent": Color(0.58, 0.44, 0.26),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
}

var title_font: Font
var body_font: Font
var parchment_bg: ColorRect
var main_vbox: VBoxContainer
var narrator_overlay: Control  # For narrator intro + NPC pixel cascade


func _setup_ui() -> void:
	_load_fonts()

	# Parchment background
	parchment_bg = ColorRect.new()
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.08)
		mat.set_shader_parameter("warp_strength", 0.001)
		parchment_bg.material = mat
	else:
		parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)

	# Main layout
	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Top bar: Aspects + Souffle
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 20)
	main_vbox.add_child(top_bar)

	_create_aspect_displays(top_bar)
	_create_souffle_display(top_bar)

	# Spacer
	var spacer1 := Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer1)

	# Card area (with NPC cascade support)
	_create_card_display(main_vbox)

	# Spacer
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)

	# Options bar (3 buttons)
	_create_options_bar(main_vbox)

	# Bottom info bar
	_create_info_bar(main_vbox)

	# Bestiole Ogham Wheel (overlay, self-positioned bottom-right)
	bestiole_wheel = BestioleWheelSystem.new()
	bestiole_wheel.name = "BestioleWheel"
	add_child(bestiole_wheel)
	bestiole_wheel.ogham_selected.connect(func(skill_id: String): skill_activated.emit(skill_id))

	# Narrator overlay (for Merlin intro + NPC pixel cascade)
	narrator_overlay = Control.new()
	narrator_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	narrator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrator_overlay.visible = false
	add_child(narrator_overlay)


func _load_fonts() -> void:
	title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _create_aspect_displays(parent: Control) -> void:
	aspect_panel = HBoxContainer.new()
	aspect_panel.add_theme_constant_override("separation", 16)
	parent.add_child(aspect_panel)

	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var container := VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Drawn Celtic animal icon (custom Control with _draw)
		var icon := _create_animal_icon(aspect)
		container.add_child(icon)

		# Aspect name
		var name_label := Label.new()
		name_label.text = aspect
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
		if title_font:
			name_label.add_theme_font_override("font", title_font)
		name_label.add_theme_font_size_override("font_size", 13)
		container.add_child(name_label)

		# State indicator (3 dots)
		var state_container := HBoxContainer.new()
		state_container.alignment = BoxContainer.ALIGNMENT_CENTER
		state_container.add_theme_constant_override("separation", 4)

		for i in range(3):
			var circle := Label.new()
			circle.text = "\u25CB"
			circle.add_theme_font_size_override("font_size", 14)
			circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_container.add_child(circle)

		container.add_child(state_container)

		# State name
		var state_name := Label.new()
		state_name.text = "Equilibre"
		state_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			state_name.add_theme_font_override("font", body_font)
		state_name.add_theme_font_size_override("font_size", 11)
		state_name.add_theme_color_override("font_color", PALETTE.ink_soft)
		container.add_child(state_name)

		aspect_panel.add_child(container)

		aspect_displays[aspect] = {
			"container": container,
			"icon": icon,
			"state_container": state_container,
			"state_name": state_name,
		}


func _create_animal_icon(aspect: String) -> Control:
	## Creates a custom-drawn Celtic animal icon for each aspect.
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(40, 36)
	var aspect_color: Color = ASPECT_COLORS.get(aspect, Color.WHITE)
	var animal: String = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {}).get("animal", "")
	icon.draw.connect(_draw_animal.bind(icon, animal, aspect_color))
	return icon


func _draw_animal(ctrl: Control, animal: String, color: Color) -> void:
	## Draw Celtic-style animal silhouettes using vector shapes.
	var sz := ctrl.size
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	var r := mini(int(sz.x), int(sz.y)) * 0.4

	match animal:
		"sanglier":  # Boar — Corps (strength)
			_draw_sanglier(ctrl, cx, cy, r, color)
		"corbeau":  # Raven — Ame (spirit)
			_draw_corbeau(ctrl, cx, cy, r, color)
		"cerf":  # Stag — Monde (world)
			_draw_cerf(ctrl, cx, cy, r, color)
		_:
			# Fallback: Celtic spiral
			ctrl.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, color, 2.0)


func _draw_sanglier(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Sanglier (boar) — stocky body with tusks, Celtic knotwork style.
	var body := PackedVector2Array()
	# Body shape (rounded rectangle-ish)
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	body.append(Vector2(cx - r * 0.7, cy - r * 0.5))
	body.append(Vector2(cx - r * 0.2, cy - r * 0.7))
	body.append(Vector2(cx + r * 0.3, cy - r * 0.6))
	body.append(Vector2(cx + r * 0.8, cy - r * 0.3))
	body.append(Vector2(cx + r * 1.0, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.3, cy + r * 0.7))
	body.append(Vector2(cx - r * 0.4, cy + r * 0.6))
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Tusks
	ctrl.draw_line(Vector2(cx + r * 0.85, cy - r * 0.1), Vector2(cx + r * 1.1, cy - r * 0.5), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 0.85, cy + r * 0.0), Vector2(cx + r * 1.1, cy + r * 0.1), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.5, cy - r * 0.2), r * 0.12, color)
	# Legs (front + back)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.6), Vector2(cx - r * 0.5, cy + r * 1.0), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy + r * 0.65), Vector2(cx + r * 0.4, cy + r * 1.0), color, 1.5)


func _draw_corbeau(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Corbeau (raven) — wings spread, Celtic knot-style.
	# Body
	var body := PackedVector2Array()
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.5, cy - r * 0.3))
	body.append(Vector2(cx + r * 0.1, cy - r * 0.2))
	body.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	body.append(Vector2(cx - r * 0.5, cy + r * 0.4))
	body.append(Vector2(cx + r * 0.2, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Beak
	ctrl.draw_line(Vector2(cx + r * 0.8, cy + r * 0.1), Vector2(cx + r * 1.2, cy - r * 0.05), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 1.2, cy - r * 0.05), Vector2(cx + r * 0.8, cy + r * 0.2), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.55, cy - r * 0.1), r * 0.1, color)
	# Left wing (spread)
	var wing := PackedVector2Array()
	wing.append(Vector2(cx - r * 0.1, cy - r * 0.1))
	wing.append(Vector2(cx - r * 0.7, cy - r * 0.8))
	wing.append(Vector2(cx - r * 1.0, cy - r * 0.5))
	wing.append(Vector2(cx - r * 0.8, cy - r * 0.2))
	wing.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	ctrl.draw_polyline(wing, color, 1.5, true)
	# Tail feathers
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.9, cy + r * 0.7), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.7, cy + r * 0.8), color, 1.5)


func _draw_cerf(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Cerf (stag) — proud head with antlers, Celtic knotwork style.
	# Head
	var head := PackedVector2Array()
	head.append(Vector2(cx, cy + r * 0.8))
	head.append(Vector2(cx - r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx - r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx, cy - r * 0.4))
	head.append(Vector2(cx + r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx + r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx, cy + r * 0.8))
	ctrl.draw_polyline(head, color, 2.0, true)
	# Eye
	ctrl.draw_circle(Vector2(cx, cy), r * 0.1, color)
	# Left antler (branching)
	ctrl.draw_line(Vector2(cx - r * 0.25, cy - r * 0.2), Vector2(cx - r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.4, cy - r * 0.5), Vector2(cx - r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.55, cy - r * 0.7), Vector2(cx - r * 0.9, cy - r * 0.9), color, 1.5)
	# Right antler (mirrored)
	ctrl.draw_line(Vector2(cx + r * 0.25, cy - r * 0.2), Vector2(cx + r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy - r * 0.5), Vector2(cx + r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.55, cy - r * 0.7), Vector2(cx + r * 0.9, cy - r * 0.9), color, 1.5)
	# Ears
	ctrl.draw_line(Vector2(cx - r * 0.2, cy - r * 0.3), Vector2(cx - r * 0.35, cy - r * 0.45), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.2, cy - r * 0.3), Vector2(cx + r * 0.35, cy - r * 0.45), color, 1.5)


func _create_souffle_display(parent: Control) -> void:
	souffle_panel = VBoxContainer.new()
	souffle_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "Souffle"
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", PALETTE.ink_soft)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	souffle_panel.add_child(title)

	souffle_display = HBoxContainer.new()
	souffle_display.alignment = BoxContainer.ALIGNMENT_CENTER
	souffle_display.add_theme_constant_override("separation", 4)

	for i in range(MerlinConstants.SOUFFLE_MAX):
		var icon := Label.new()
		icon.text = SOUFFLE_EMPTY
		icon.add_theme_font_size_override("font_size", 20)
		souffle_display.add_child(icon)

	souffle_panel.add_child(souffle_display)
	parent.add_child(souffle_panel)


func _create_card_display(parent: Control) -> void:
	card_container = CenterContainer.new()
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(380, 280)

	# Celtic-style card border
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PALETTE.paper_dark
	card_style.border_color = PALETTE.accent
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.shadow_color = PALETTE.shadow
	card_style.shadow_size = 6
	card_style.shadow_offset = Vector2(0, 3)
	card_panel.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_vbox.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_child(card_vbox)
	card_panel.add_child(margin)

	# Speaker
	card_speaker = Label.new()
	card_speaker.text = "MERLIN"
	if title_font:
		card_speaker.add_theme_font_override("font", title_font)
	card_speaker.add_theme_font_size_override("font_size", 18)
	card_speaker.add_theme_color_override("font_color", PALETTE.accent)
	card_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(card_speaker)

	# Pixel portrait (character visualization)
	var portrait_center := CenterContainer.new()
	portrait_center.name = "PortraitCenter"
	portrait_center.custom_minimum_size = Vector2(0, 68)
	card_vbox.add_child(portrait_center)

	_pixel_portrait = PixelCharacterPortrait.new()
	_pixel_portrait.name = "PixelPortrait"
	_pixel_portrait.setup("merlin", 4.0)
	portrait_center.add_child(_pixel_portrait)

	# Card text
	card_text = RichTextLabel.new()
	card_text.text = "Le vent souffle sur les landes..."
	card_text.bbcode_enabled = true
	card_text.fit_content = true
	card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body_font:
		card_text.add_theme_font_override("normal_font", body_font)
	card_text.add_theme_font_size_override("normal_font_size", 16)
	card_text.add_theme_color_override("default_color", PALETTE.ink)
	card_vbox.add_child(card_text)

	card_container.add_child(card_panel)
	parent.add_child(card_container)


func _create_options_bar(parent: Control) -> void:
	options_container = HBoxContainer.new()
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 12)
	parent.add_child(options_container)

	var option_configs := [
		{"key": "A", "pos": "left", "color": Color(0.35, 0.55, 0.72)},
		{"key": "B", "pos": "center", "color": PALETTE.accent},
		{"key": "C", "pos": "right", "color": Color(0.72, 0.35, 0.32)},
	]

	for i in range(3):
		var config = option_configs[i]
		var option_vbox := VBoxContainer.new()
		option_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# Option label
		var label := Label.new()
		label.text = "Option"
		if body_font:
			label.add_theme_font_override("font", body_font)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", PALETTE.ink_soft)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_labels.append(label)
		option_vbox.add_child(label)

		# Button with parchment style
		var btn := Button.new()
		btn.text = "[%s] Choisir" % config["key"]
		btn.custom_minimum_size = Vector2(120, 46)
		if title_font:
			btn.add_theme_font_override("font", title_font)
		btn.add_theme_font_size_override("font_size", 15)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = PALETTE.paper
		btn_style.border_color = config["color"]
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(4)
		btn_style.content_margin_left = 12
		btn_style.content_margin_right = 12
		btn_style.content_margin_top = 8
		btn_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = PALETTE.paper_dark
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(config["color"].r, config["color"].g, config["color"].b, 0.15)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		btn.add_theme_color_override("font_color", config["color"])
		btn.add_theme_color_override("font_hover_color", config["color"])
		btn.pressed.connect(_on_option_pressed.bind(i))
		option_buttons.append(btn)
		option_vbox.add_child(btn)

		# Cost indicator (for center)
		if i == 1:
			var cost := Label.new()
			cost.text = "(1 %s)" % SOUFFLE_ICON
			if body_font:
				cost.add_theme_font_override("font", body_font)
			cost.add_theme_font_size_override("font_size", 10)
			cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost.add_theme_color_override("font_color", PALETTE.ink_soft)
			option_vbox.add_child(cost)

		options_container.add_child(option_vbox)


func _create_info_bar(parent: Control) -> void:
	info_panel = HBoxContainer.new()
	info_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_theme_constant_override("separation", 30)

	mission_label = Label.new()
	mission_label.text = "Mission: ???"
	if body_font:
		mission_label.add_theme_font_override("font", body_font)
	mission_label.add_theme_font_size_override("font_size", 13)
	mission_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	info_panel.add_child(mission_label)

	cards_label = Label.new()
	cards_label.text = "Cartes: 0"
	if body_font:
		cards_label.add_theme_font_override("font", body_font)
	cards_label.add_theme_font_size_override("font_size", 13)
	cards_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	info_panel.add_child(cards_label)

	parent.add_child(info_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func update_aspects(aspects: Dictionary) -> void:
	_update_aspects(aspects)


func _update_aspects(aspects: Dictionary) -> void:
	current_aspects = aspects

	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var display = aspect_displays.get(aspect, {})
		if display.is_empty():
			continue

		var aspect_state: int = int(aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))

		# Update state indicator circles
		var state_container: HBoxContainer = display.get("state_container")
		if state_container:
			for i in range(3):
				var circle: Label = state_container.get_child(i) as Label
				if circle:
					var target_state: int = i - 1  # -1, 0, 1
					if target_state == aspect_state:
						circle.text = "●"
						circle.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
					else:
						circle.text = "○"
						circle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		# Update state name
		var state_name: Label = display.get("state_name")
		if state_name:
			var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
			var states = info.get("states", {})
			state_name.text = str(states.get(aspect_state, "???"))

			# Color based on extreme state
			if aspect_state == MerlinConstants.AspectState.EQUILIBRE:
				state_name.add_theme_color_override("font_color", PALETTE.ink_soft)
			else:
				state_name.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))

		# Animate icon if extreme (now a Control, not Label)
		var icon: Control = display.get("icon")
		if icon:
			if aspect_state != MerlinConstants.AspectState.EQUILIBRE:
				var tween := create_tween()
				tween.set_loops(2)
				tween.tween_property(icon, "modulate:a", 0.5, 0.3)
				tween.tween_property(icon, "modulate:a", 1.0, 0.3)


func update_souffle(souffle: int) -> void:
	_update_souffle(souffle)


func _update_souffle(souffle: int) -> void:
	current_souffle = souffle

	if not souffle_display:
		return

	for i in range(MerlinConstants.SOUFFLE_MAX):
		var icon: Label = souffle_display.get_child(i) as Label
		if icon:
			if i < souffle:
				icon.text = SOUFFLE_ICON
				icon.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
			else:
				icon.text = SOUFFLE_EMPTY
				icon.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	# Update center button based on souffle
	if option_buttons.size() > 1:
		var center_btn := option_buttons[1]
		if souffle < MerlinConstants.SOUFFLE_CENTER_COST:
			center_btn.text = "[B] Risque!"
			center_btn.add_theme_color_override("font_color", Color(0.78, 0.35, 0.22))
		else:
			center_btn.text = "[B] Choisir"
			center_btn.add_theme_color_override("font_color", PALETTE.accent)


func display_card(card: Dictionary) -> void:
	current_card = card

	# Resolve speaker and pixel portrait
	var speaker: String = card.get("speaker", "")
	var speaker_key := PixelCharacterPortrait.resolve_character_key(speaker) if speaker != "" else ""
	var is_new_speaker := speaker_key != "" and speaker_key != _current_speaker_key

	# Update speaker label
	if card_speaker:
		card_speaker.text = PixelCharacterPortrait.get_character_name(speaker_key) if speaker_key != "" else ""
		card_speaker.visible = not speaker.is_empty()

	# Pixel portrait: assemble new character if speaker changed
	if is_new_speaker and _pixel_portrait:
		_current_speaker_key = speaker_key
		_pixel_portrait.setup(speaker_key, 4.0)
		_pixel_portrait.assemble(false)  # Animated assembly

	# Update text with typewriter
	if card_text:
		_typewriter_card_text(card.get("text", "..."))

	# Update options
	var options: Array = card.get("options", [])
	for i in range(mini(options.size(), 3)):
		var option: Dictionary = options[i]
		if i < option_labels.size():
			option_labels[i].text = option.get("label", "...")
		if i < option_buttons.size():
			var key: String = OPTION_KEYS.get(i, "?")
			option_buttons[i].text = "[%s] %s" % [key, option.get("label", "?")]


# ═══════════════════════════════════════════════════════════════════════════════
# PIXEL CHARACTER PORTRAIT — Now handled by PixelCharacterPortrait class
# ═══════════════════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN NARRATOR INTRO — Run opening narration
# ═══════════════════════════════════════════════════════════════════════════════

signal narrator_intro_finished

const NARRATOR_INTROS := [
	"Les brumes de Bretagne s'ouvrent devant toi... Le chemin serpente, et l'avenir est incertain.",
	"La foret murmure ton nom. Merlin veille... mais pour combien de temps encore?",
	"Le vent porte des echos anciens. Un nouveau cycle commence, voyageur.",
	"Les pierres se souviennent de chaque pas. Pret a ecrire un nouveau chapitre?",
	"L'aube se leve sur les landes. Quelque chose attend au bout du sentier.",
]

var _narrator_active := false
var _typewriter_active := false
var _typewriter_abort := false


func show_narrator_intro() -> void:
	## Show Merlin as narrator before the first card of a run.
	_narrator_active = true

	# Hide game UI during intro
	if options_container:
		options_container.modulate.a = 0.0
	if info_panel:
		info_panel.modulate.a = 0.0

	# Show Merlin as speaker
	if card_speaker:
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Pick intro text
	var intro_text: String = NARRATOR_INTROS[randi() % NARRATOR_INTROS.size()]

	# Typewriter the intro
	await _typewriter_card_text(intro_text)

	# Wait for player to acknowledge
	await get_tree().create_timer(1.5).timeout

	# Fade in game UI
	if options_container:
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.4)
	if info_panel:
		var tw2 := create_tween()
		tw2.tween_property(info_panel, "modulate:a", 1.0, 0.4)

	_narrator_active = false
	narrator_intro_finished.emit()


func _typewriter_card_text(full_text: String) -> void:
	## Typewriter effect for card text with procedural blip sound.
	if card_text == null:
		return

	_typewriter_active = true
	_typewriter_abort = false
	card_text.text = ""
	card_text.visible_characters = 0

	# Set full text but reveal character by character
	card_text.text = full_text
	var total := full_text.length()

	for i in range(total):
		if _typewriter_abort:
			card_text.visible_characters = -1
			break
		card_text.visible_characters = i + 1
		var ch := full_text[i]
		# Procedural blip
		if ch != " " and ch != "\n":
			_play_blip()
		# Punctuation pause
		if ch in [".", ",", "!", "?", ":"]:
			await get_tree().create_timer(0.08).timeout
		else:
			await get_tree().create_timer(0.025).timeout

	card_text.visible_characters = -1
	_typewriter_active = false


func _play_blip() -> void:
	## Procedural keyboard click sound.
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.02
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = linear_to_db(0.04)
	add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var freq := randf_range(280.0, 380.0)
	var samples := int(22050.0 * 0.015)
	for s in range(samples):
		var t := float(s) / 22050.0
		var envelope := exp(-t * 200.0)
		var val := sin(TAU * freq * t) * envelope * 0.3
		val += randf_range(-0.05, 0.05) * envelope
		playback.push_frame(Vector2(val, val))
	# Auto cleanup
	var tw := create_tween()
	tw.tween_callback(player.queue_free).set_delay(0.05)


func update_mission(mission: Dictionary) -> void:
	if mission_label:
		if mission.get("revealed", false):
			var progress: int = int(mission.get("progress", 0))
			var total: int = int(mission.get("total", 0))
			mission_label.text = "Mission: %d/%d" % [progress, total]
		else:
			mission_label.text = "Mission: ???"


func update_cards_count(count: int) -> void:
	if cards_label:
		cards_label.text = "Cartes: %d" % count


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_requested.emit()
		return

	# Skip typewriter on click/tap
	if _typewriter_active and event is InputEventMouseButton and event.pressed:
		_typewriter_abort = true
		return

	# Keyboard shortcuts for options
	if event is InputEventKey and event.pressed:
		# Skip typewriter on any key
		if _typewriter_active:
			_typewriter_abort = true
			return
		match event.keycode:
			KEY_A, KEY_LEFT:
				_on_option_pressed(MerlinConstants.CardOption.LEFT)
			KEY_B, KEY_UP:
				_on_option_pressed(MerlinConstants.CardOption.CENTER)
			KEY_C, KEY_RIGHT:
				_on_option_pressed(MerlinConstants.CardOption.RIGHT)


func _on_option_pressed(option: int) -> void:
	if current_card.is_empty():
		return

	# Animate button
	if option < option_buttons.size():
		var btn := option_buttons[option]
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

	option_chosen.emit(option)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	# Hide main UI
	if card_container:
		card_container.visible = false
	if options_container:
		options_container.visible = false

	# Create parchment overlay
	var overlay := ColorRect.new()
	overlay.color = Color(PALETTE.paper.r, PALETTE.paper.g, PALETTE.paper.b, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	add_child(overlay)

	# Fade in
	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.8)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Celtic ornament top
	var orn_top := Label.new()
	orn_top.text = "\u2500\u2500\u2500 \u25C6 \u2500\u2500\u2500"
	orn_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_top.add_theme_font_size_override("font_size", 14)
	orn_top.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(orn_top)

	# Ending title
	var title := Label.new()
	var ending_data: Dictionary = ending.get("ending", {})
	title.text = ending_data.get("title", "Fin")
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if ending.get("victory", false):
		title.add_theme_color_override("font_color", Color(0.32, 0.58, 0.28))
	else:
		title.add_theme_color_override("font_color", Color(0.72, 0.28, 0.22))

	vbox.add_child(title)

	# Ending text
	if ending_data.has("text"):
		var text := Label.new()
		text.text = ending_data.get("text", "")
		if body_font:
			text.add_theme_font_override("font", body_font)
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", PALETTE.ink)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	# Score
	var score := Label.new()
	score.text = "Gloire: %d" % ending.get("score", 0)
	if title_font:
		score.add_theme_font_override("font", title_font)
	score.add_theme_font_size_override("font_size", 22)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(score)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Cartes: %d  \u2502  Jours: %d" % [
		ending.get("cards_played", 0),
		ending.get("days_survived", 1)
	]
	if body_font:
		stats_lbl.add_theme_font_override("font", body_font)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# Celtic ornament bottom
	var orn_bot := Label.new()
	orn_bot.text = "\u2500\u2500\u2500 \u25C6 \u2500\u2500\u2500"
	orn_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_bot.add_theme_font_size_override("font_size", 14)
	orn_bot.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(orn_bot)

	# Aspects final state
	var aspects_label := Label.new()
	var aspects_text := "Aspects finaux: "
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var state_val: int = current_aspects.get(aspect, 0)
		var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
		var states = info.get("states", {})
		var animal: Dictionary = {"Corps": "Sanglier", "Ame": "Corbeau", "Monde": "Cerf"}
		aspects_text += "%s %s (%s) | " % [animal.get(aspect, "?"), aspect, states.get(state_val, "?")]
	aspects_label.text = aspects_text.trim_suffix(" | ")
	aspects_label.add_theme_font_size_override("font_size", 12)
	aspects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aspects_label)

	# Return button
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Retour au menu"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn"))
	vbox.add_child(btn)
