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
var _souffle_counter: Label

# Life essence (Phase 43)
var life_panel: Control
var _life_counter: Label
var _life_bar: ProgressBar

var card_container: Control
var card_panel: Panel
var card_text: RichTextLabel
var card_speaker: Label
var _card_source_badge: PanelContainer
var _encounter_tile: PixelEncounterTile

var options_container: HBoxContainer
var option_buttons: Array[Button] = []
var option_labels: Array[Label] = []
var _effect_preview_panel: Panel
var _effect_preview_label: RichTextLabel
var _preview_visible_for: int = -1  # Which option index is previewed

var _resource_bar: HBoxContainer
var _tool_label: Label
var _day_label: Label
var _mission_progress_label: Label

var info_panel: Control
var mission_label: Label
var cards_label: Label

var bestiole_wheel: BestioleWheelSystem
var _pixel_portrait: PixelCharacterPortrait
var _current_speaker_key: String = ""
var biome_indicator: Label

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var current_aspects: Dictionary = {}
var _previous_aspects: Dictionary = {}
var current_souffle: int = 3
var _previous_souffle: int = -1
var _blip_pool: Array[AudioStreamPlayer] = []
var _blip_idx: int = 0
const BLIP_POOL_SIZE := 4

# Card stacking
var _card_shadows: Array[Panel] = []
const MAX_CARD_SHADOWS := 3

# Ambient VFX
var _ambient_timer: Timer
var _ambient_particles: Array[ColorRect] = []
const MAX_AMBIENT_PARTICLES := 10
var _ambient_biome_key: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_ui()
	_init_blip_pool()
	_update_aspects({
		"Corps": MerlinConstants.AspectState.EQUILIBRE,
		"Ame": MerlinConstants.AspectState.EQUILIBRE,
		"Monde": MerlinConstants.AspectState.EQUILIBRE,
	})
	_update_souffle(MerlinConstants.SOUFFLE_START)


func _init_blip_pool() -> void:
	## Pre-create a pool of AudioStreamPlayers to avoid per-character allocation.
	for i in range(BLIP_POOL_SIZE):
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.02
		var player := AudioStreamPlayer.new()
		player.stream = gen
		player.volume_db = linear_to_db(0.04)
		add_child(player)
		_blip_pool.append(player)


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

	# Biome indicator (small label showing current biome)
	biome_indicator = Label.new()
	biome_indicator.text = ""
	biome_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_indicator.add_theme_font_size_override("font_size", 11)
	biome_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	if body_font:
		biome_indicator.add_theme_font_override("font", body_font)
	main_vbox.add_child(biome_indicator)

	# Resource bar (tool + day + mission)
	_create_resource_bar(main_vbox)

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

	# Effect preview tooltip (floating, added to self so it overlays everything)
	_create_effect_preview_panel()

	# Bottom info bar
	_create_info_bar(main_vbox)

	# Bestiole Ogham Wheel (overlay, self-positioned bottom-right)
	bestiole_wheel = BestioleWheelSystem.new()
	bestiole_wheel.name = "BestioleWheel"
	add_child(bestiole_wheel)
	bestiole_wheel.ogham_selected.connect(func(skill_id: String):
		SFXManager.play("skill_activate")
		skill_activated.emit(skill_id)
	)

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

		# State name + shift arrow (inline)
		var state_row := HBoxContainer.new()
		state_row.alignment = BoxContainer.ALIGNMENT_CENTER
		state_row.add_theme_constant_override("separation", 3)

		var state_name := Label.new()
		state_name.text = "Equilibre"
		state_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			state_name.add_theme_font_override("font", body_font)
		state_name.add_theme_font_size_override("font_size", 11)
		state_name.add_theme_color_override("font_color", PALETTE.ink_soft)
		state_row.add_child(state_name)

		var shift_arrow := Label.new()
		shift_arrow.text = ""
		shift_arrow.add_theme_font_size_override("font_size", 11)
		shift_arrow.add_theme_color_override("font_color", Color.GRAY)
		state_row.add_child(shift_arrow)
		container.add_child(state_row)

		aspect_panel.add_child(container)

		aspect_displays[aspect] = {
			"container": container,
			"icon": icon,
			"state_container": state_container,
			"state_name": state_name,
			"shift_arrow": shift_arrow,
		}


func _create_animal_icon(aspect: String) -> Control:
	## Creates a custom-drawn Celtic animal icon for each aspect.
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(56, 48)
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
		icon.add_theme_font_size_override("font_size", 28)
		souffle_display.add_child(icon)

	souffle_panel.add_child(souffle_display)

	# Numeric counter "3/7"
	_souffle_counter = Label.new()
	_souffle_counter.text = "3/%d" % MerlinConstants.SOUFFLE_MAX
	_souffle_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		_souffle_counter.add_theme_font_override("font", body_font)
	_souffle_counter.add_theme_font_size_override("font_size", 12)
	_souffle_counter.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
	souffle_panel.add_child(_souffle_counter)

	parent.add_child(souffle_panel)


func _create_resource_bar(parent: Control) -> void:
	_resource_bar = HBoxContainer.new()
	_resource_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_resource_bar.add_theme_constant_override("separation", 20)

	# Tool equipped
	_tool_label = Label.new()
	_tool_label.text = ""
	if body_font:
		_tool_label.add_theme_font_override("font", body_font)
	_tool_label.add_theme_font_size_override("font_size", 11)
	_tool_label.add_theme_color_override("font_color", PALETTE.accent)
	_resource_bar.add_child(_tool_label)

	# Day counter
	_day_label = Label.new()
	_day_label.text = "Jour 1"
	if body_font:
		_day_label.add_theme_font_override("font", body_font)
	_day_label.add_theme_font_size_override("font_size", 11)
	_day_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_resource_bar.add_child(_day_label)

	# Mission progress
	_mission_progress_label = Label.new()
	_mission_progress_label.text = ""
	if body_font:
		_mission_progress_label.add_theme_font_override("font", body_font)
	_mission_progress_label.add_theme_font_size_override("font_size", 11)
	_mission_progress_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_resource_bar.add_child(_mission_progress_label)

	parent.add_child(_resource_bar)


func _create_card_display(parent: Control) -> void:
	card_container = CenterContainer.new()
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(460, 360)

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
	portrait_center.custom_minimum_size = Vector2(0, 96)
	card_vbox.add_child(portrait_center)

	_pixel_portrait = PixelCharacterPortrait.new()
	_pixel_portrait.name = "PixelPortrait"
	_pixel_portrait.setup("merlin", 4.0)
	portrait_center.add_child(_pixel_portrait)

	# Encounter tile (pixel art per card type)
	var tile_center := CenterContainer.new()
	tile_center.name = "TileCenter"
	tile_center.custom_minimum_size = Vector2(0, 72)
	card_vbox.add_child(tile_center)

	_encounter_tile = PixelEncounterTile.new()
	_encounter_tile.name = "EncounterTile"
	_encounter_tile.setup("mystery", 3.0)
	tile_center.add_child(_encounter_tile)

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

	# Card source badge (dev indicator: LLM / Fallback / JSON)
	_card_source_badge = LLMSourceBadge.create("static")
	_card_source_badge.visible = false
	card_vbox.add_child(_card_source_badge)

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
		btn.mouse_entered.connect(_on_option_hover_enter.bind(i))
		btn.mouse_exited.connect(_on_option_hover_exit)
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


func _create_effect_preview_panel() -> void:
	_effect_preview_panel = Panel.new()
	_effect_preview_panel.visible = false
	_effect_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_preview_panel.z_index = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PALETTE.paper_dark.r, PALETTE.paper_dark.g, PALETTE.paper_dark.b, 0.95)
	style.border_color = PALETTE.accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_effect_preview_panel.add_theme_stylebox_override("panel", style)

	_effect_preview_label = RichTextLabel.new()
	_effect_preview_label.bbcode_enabled = true
	_effect_preview_label.fit_content = true
	_effect_preview_label.scroll_active = false
	_effect_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		_effect_preview_label.add_theme_font_override("normal_font", body_font)
	_effect_preview_label.add_theme_font_size_override("normal_font_size", 12)
	_effect_preview_label.add_theme_color_override("default_color", PALETTE.ink)
	_effect_preview_panel.add_child(_effect_preview_label)

	add_child(_effect_preview_panel)


func _on_option_hover_enter(option_index: int) -> void:
	SFXManager.play("hover")
	_show_effect_preview(option_index)


func _on_option_hover_exit() -> void:
	_hide_effect_preview()


func _show_effect_preview(option_index: int) -> void:
	if current_card.is_empty():
		return
	var options: Array = current_card.get("options", [])
	if option_index >= options.size():
		return

	var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	var effects: Array = option.get("effects", [])

	# Build preview text
	var lines: Array[String] = []

	# DC info
	var dc_values := [6, 10, 14]  # LEFT, CENTER, RIGHT
	var dc: int = dc_values[clampi(option_index, 0, 2)]
	var dc_color: String = "green" if dc <= 6 else ("yellow" if dc <= 10 else "red")
	lines.append("[color=%s]DC %d[/color]" % [dc_color, dc])

	# Souffle cost for center
	if option_index == 1:
		lines.append("[color=#b08040]-%s 1 Souffle[/color]" % SOUFFLE_ICON)

	# Aspect effects
	if effects.is_empty():
		lines.append("[color=gray]Pas d'effet direct[/color]")
	else:
		for e in effects:
			if not (e is Dictionary):
				continue
			var etype: String = str(e.get("type", ""))
			if etype == "SHIFT_ASPECT":
				var aspect: String = str(e.get("aspect", ""))
				var dir: String = str(e.get("direction", ""))
				var arrow: String = "\u2191" if dir == "up" else "\u2193"
				var preview_text := _format_aspect_shift_preview(aspect, dir)
				var shift_color: String = _get_shift_color(aspect, dir)
				lines.append("[color=%s]%s %s %s[/color]" % [shift_color, aspect, arrow, preview_text])
			elif etype == "ADD_KARMA":
				lines.append("[color=#c0a030]+%d Karma[/color]" % int(e.get("amount", 0)))
			elif etype == "ADD_SOUFFLE":
				lines.append("[color=#40a060]+%d Souffle[/color]" % int(e.get("amount", 0)))
			elif etype == "PROGRESS_MISSION":
				lines.append("[color=#6080c0]+%d Mission[/color]" % int(e.get("step", 1)))

	# Build BBCode
	_effect_preview_label.text = "\n".join(lines)

	# Position above the hovered button
	_preview_visible_for = option_index
	_effect_preview_panel.visible = true
	_effect_preview_panel.custom_minimum_size = Vector2(180, 0)
	_effect_preview_panel.size = Vector2(180, 0)

	# Wait one frame for the label to compute its size
	await get_tree().process_frame
	_position_preview_above_button(option_index)


func _position_preview_above_button(option_index: int) -> void:
	if option_index >= option_buttons.size():
		return
	if not _effect_preview_panel or not _effect_preview_panel.visible:
		return
	var btn: Button = option_buttons[option_index]
	if not is_instance_valid(btn):
		return

	var btn_global := btn.global_position
	var panel_h: float = maxf(_effect_preview_label.get_content_height() + 16.0, 40.0)
	_effect_preview_panel.size.y = panel_h
	_effect_preview_panel.global_position = Vector2(
		btn_global.x + btn.size.x * 0.5 - 90.0,
		btn_global.y - panel_h - 6.0
	)


func _hide_effect_preview() -> void:
	_preview_visible_for = -1
	if _effect_preview_panel:
		_effect_preview_panel.visible = false


func _format_aspect_shift_preview(aspect: String, direction: String) -> String:
	## Returns "(Robuste → Surmené)" based on current state + shift direction.
	var current_state: int = int(current_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
	var new_state: int = current_state + (1 if direction == "up" else -1)
	new_state = clampi(new_state, MerlinConstants.AspectState.BAS, MerlinConstants.AspectState.HAUT)
	var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
	var states: Dictionary = info.get("states", {})
	var current_name: String = states.get(current_state, "?")
	var new_name: String = states.get(new_state, "?")
	if current_state == new_state:
		return "(%s, max)" % current_name
	return "(%s \u2192 %s)" % [current_name, new_name]


func _get_shift_color(aspect: String, direction: String) -> String:
	## Returns a color hex for the shift preview. Red if dangerous (toward extreme), green if safe.
	var current_state: int = int(current_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
	var new_state: int = current_state + (1 if direction == "up" else -1)
	new_state = clampi(new_state, MerlinConstants.AspectState.BAS, MerlinConstants.AspectState.HAUT)
	# BAS or HAUT = dangerous
	if new_state == MerlinConstants.AspectState.BAS or new_state == MerlinConstants.AspectState.HAUT:
		return "#c04040"  # Red — dangerous
	return "#40a060"  # Green — safe (toward equilibre)


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
# THINKING ANIMATION — Shown while LLM generates next card
# ═══════════════════════════════════════════════════════════════════════════════

var _thinking_active := false
var _thinking_dots := 0
var _thinking_timer: Timer = null
var _thinking_spiral: Control = null

func show_thinking() -> void:
	## Show "Merlin is thinking" animation on the card area.
	if _thinking_active:
		return
	_thinking_active = true

	# Dim options
	if options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 0.3, 0.2)

	# Update card text with animated dots
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Show Celtic spiral animation (reuse if already created)
	if card_panel and is_instance_valid(card_panel):
		if _thinking_spiral != null and is_instance_valid(_thinking_spiral):
			_thinking_spiral.visible = true
		else:
			_thinking_spiral = Control.new()
			_thinking_spiral.name = "ThinkingSpiral"
			_thinking_spiral.custom_minimum_size = Vector2(60, 60)
			_thinking_spiral.set_anchors_preset(Control.PRESET_CENTER)
			var panel_size: Vector2 = card_panel.size if card_panel.size.length() > 0 else Vector2(460, 360)
			_thinking_spiral.position = panel_size * 0.5 - Vector2(30, 50)
			_thinking_spiral.draw.connect(_draw_thinking_spiral.bind(_thinking_spiral))
			card_panel.add_child(_thinking_spiral)

	# Start dot animation timer
	_thinking_dots = 0
	if _thinking_timer == null:
		_thinking_timer = Timer.new()
		_thinking_timer.wait_time = 0.4
		_thinking_timer.timeout.connect(_on_thinking_tick)
		add_child(_thinking_timer)
	_thinking_timer.start()
	_on_thinking_tick()  # First tick immediately


func hide_thinking() -> void:
	## Hide thinking animation and restore UI.
	if not _thinking_active:
		return
	_thinking_active = false

	# Stop timer
	if _thinking_timer:
		_thinking_timer.stop()

	# Hide spiral (keep for reuse — avoids node leak)
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		_thinking_spiral.visible = false

	# Restore options opacity
	if options_container:
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.2)


func _on_thinking_tick() -> void:
	## Animate thinking dots on the card text.
	_thinking_dots = (_thinking_dots + 1) % 4
	var dots := ".".repeat(_thinking_dots)
	if card_text:
		card_text.text = "Merlin reflechit" + dots

	# Rotate spiral
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		var tw := create_tween()
		tw.tween_property(_thinking_spiral, "rotation", _thinking_spiral.rotation + PI * 0.5, 0.35)
		_thinking_spiral.queue_redraw()


func _draw_thinking_spiral(ctrl: Control) -> void:
	## Draw an animated Celtic triple spiral (triskelion).
	var cx := ctrl.size.x * 0.5
	var cy := ctrl.size.y * 0.5
	var r := mini(int(ctrl.size.x), int(ctrl.size.y)) * 0.35

	# Draw 3 spiraling arms (triskelion)
	for arm in range(3):
		var angle_offset := TAU * arm / 3.0
		var points := PackedVector2Array()
		for i in range(20):
			var t := float(i) / 19.0
			var spiral_r := r * t
			var angle := angle_offset + t * TAU * 0.75
			points.append(Vector2(
				cx + cos(angle) * spiral_r,
				cy + sin(angle) * spiral_r
			))
		if points.size() >= 2:
			ctrl.draw_polyline(points, PALETTE.accent, 2.0, true)

	# Center dot
	ctrl.draw_circle(Vector2(cx, cy), 3.0, PALETTE.accent)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func update_biome_indicator(biome_name: String, biome_color: Color) -> void:
	if biome_indicator:
		biome_indicator.text = "\u25C6 %s \u25C6" % biome_name
		biome_indicator.add_theme_color_override("font_color", Color(biome_color.r, biome_color.g, biome_color.b, 0.7))


func update_aspects(aspects: Dictionary) -> void:
	_update_aspects(aspects)


func _update_aspects(aspects: Dictionary) -> void:
	# Play SFX based on aspect changes (skip on first call when _previous_aspects is empty)
	if not _previous_aspects.is_empty():
		for aspect_name in MerlinConstants.TRIADE_ASPECTS:
			var old_state: int = int(_previous_aspects.get(aspect_name, MerlinConstants.AspectState.EQUILIBRE))
			var new_state: int = int(aspects.get(aspect_name, MerlinConstants.AspectState.EQUILIBRE))
			if new_state != old_state:
				if new_state > old_state:
					SFXManager.play("aspect_up")
				else:
					SFXManager.play("aspect_down")

	_previous_aspects = aspects.duplicate()
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

		# Shift arrow (shows last change direction)
		var shift_arrow: Label = display.get("shift_arrow")
		if shift_arrow and not _previous_aspects.is_empty():
			var old_st: int = int(_previous_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
			if aspect_state > old_st:
				shift_arrow.text = "\u2191"
				shift_arrow.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))
			elif aspect_state < old_st:
				shift_arrow.text = "\u2193"
				shift_arrow.add_theme_color_override("font_color", Color(0.25, 0.45, 0.72))
			else:
				shift_arrow.text = ""

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
	var old_souffle := _previous_souffle
	_previous_souffle = souffle
	current_souffle = souffle

	# Update numeric counter
	if _souffle_counter and is_instance_valid(_souffle_counter):
		_souffle_counter.text = "%d/%d" % [souffle, MerlinConstants.SOUFFLE_MAX]
		if souffle == 0:
			_souffle_counter.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))
		elif souffle <= 2:
			_souffle_counter.add_theme_color_override("font_color", Color(0.72, 0.50, 0.10))
		else:
			_souffle_counter.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))

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

	# VFX: Regen animation (gained souffle)
	if old_souffle >= 0 and souffle > old_souffle:
		for i in range(old_souffle, mini(souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.scale = Vector2(0.3, 0.3)
				icon.pivot_offset = icon.size * 0.5
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 * (i - old_souffle))
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.15)
		SFXManager.play("souffle_regen")

	# VFX: Consumption animation (lost souffle)
	if old_souffle >= 0 and souffle < old_souffle:
		for i in range(souffle, mini(old_souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.2) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)

	# VFX: Full souffle glow (7/7)
	if souffle >= MerlinConstants.SOUFFLE_MAX:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
		if old_souffle >= 0 and old_souffle < MerlinConstants.SOUFFLE_MAX:
			SFXManager.play("souffle_full")

	# VFX: Empty souffle blink (0/7)
	if souffle <= 0:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.set_loops(3)
				tw.tween_property(icon, "modulate:a", 0.3, 0.4)
				tw.tween_property(icon, "modulate:a", 1.0, 0.4)

	# Center is now free (Phase 43) — no risk indicator needed


func update_life_essence(life: int) -> void:
	## Update the life essence display (Phase 43).
	if _life_counter and is_instance_valid(_life_counter):
		_life_counter.text = "%d/%d" % [life, MerlinConstants.LIFE_ESSENCE_MAX]
		if life <= 0:
			_life_counter.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))
		elif life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			_life_counter.add_theme_color_override("font_color", Color(0.72, 0.50, 0.10))
		else:
			_life_counter.add_theme_color_override("font_color", Color(0.35, 0.65, 0.30))
	if _life_bar and is_instance_valid(_life_bar):
		_life_bar.value = life
		if life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			var tw := create_tween()
			tw.set_loops(2)
			tw.tween_property(_life_bar, "modulate:a", 0.5, 0.3)
			tw.tween_property(_life_bar, "modulate:a", 1.0, 0.3)


func update_resource_bar(tool_id: String, day: int, mission_current: int, mission_total: int) -> void:
	if _tool_label:
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
			_tool_label.text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", tool_id))]
		else:
			_tool_label.text = ""
	if _day_label:
		_day_label.text = "Jour %d" % day
	if _mission_progress_label:
		if mission_total > 0:
			_mission_progress_label.text = "Mission %d/%d" % [mission_current, mission_total]
		else:
			_mission_progress_label.text = ""


func display_card(card: Dictionary) -> void:
	if card.is_empty():
		push_warning("[TriadeUI] display_card called with empty card")
		return
	current_card = card

	# Card stacking: push shadow of previous card behind
	_push_card_shadow()

	SFXManager.play("card_draw")

	# Resolve speaker and pixel portrait
	var speaker: String = str(card.get("speaker", ""))
	var speaker_key := PixelCharacterPortrait.resolve_character_key(speaker) if speaker != "" else ""
	var is_new_speaker := speaker_key != "" and speaker_key != _current_speaker_key

	# Update speaker label
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = PixelCharacterPortrait.get_character_name(speaker_key) if speaker_key != "" else ""
		card_speaker.visible = not speaker.is_empty()

	# Pixel portrait: assemble new character if speaker changed
	if is_new_speaker and _pixel_portrait and is_instance_valid(_pixel_portrait):
		_current_speaker_key = speaker_key
		_pixel_portrait.setup(speaker_key, 4.0)
		_pixel_portrait.assemble(false)  # Animated assembly

	# Animate card entrance — flip + scale + fade
	if card_panel and is_instance_valid(card_panel):
		card_panel.pivot_offset = card_panel.custom_minimum_size / 2.0
		card_panel.modulate.a = 0.0
		card_panel.scale = Vector2(0.8, 0.8)
		card_panel.rotation_degrees = 90.0
		var entry_tw := create_tween()
		entry_tw.set_parallel(true)
		entry_tw.tween_property(card_panel, "rotation_degrees", 0.0, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		entry_tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		entry_tw.tween_property(card_panel, "modulate:a", 1.0, 0.2).set_delay(0.1)

	# Update text with typewriter
	if card_text and is_instance_valid(card_text):
		_typewriter_card_text(card.get("text", "..."))

	# Update source badge (dev indicator)
	if _card_source_badge and is_instance_valid(_card_source_badge):
		var card_source := _detect_card_source(card)
		LLMSourceBadge.update_badge(_card_source_badge, card_source)
		_card_source_badge.visible = true

	# Update encounter tile (pixel art per card type)
	if _encounter_tile and is_instance_valid(_encounter_tile):
		var enc_type := PixelEncounterTile.detect_type(card)
		_encounter_tile.setup(enc_type, 3.0)
		_encounter_tile.assemble(true)

	# Update options — always show all 3 buttons
	var options: Array = card.get("options", [])
	for i in range(3):
		var has_option: bool = i < options.size() and options[i] is Dictionary
		var option: Dictionary = options[i] if has_option else {}
		if i < option_labels.size() and is_instance_valid(option_labels[i]):
			option_labels[i].text = str(option.get("label", "...")) if has_option else "..."
			option_labels[i].modulate.a = 1.0 if has_option else 0.4
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			var key: String = OPTION_KEYS.get(i, "?")
			option_buttons[i].text = "[%s] %s" % [key, str(option.get("label", "?"))] if has_option else "[%s] —" % key
			option_buttons[i].disabled = not has_option
			option_buttons[i].modulate.a = 1.0 if has_option else 0.35


func _detect_card_source(card: Dictionary) -> String:
	## Detect whether a card was generated by LLM, fallback pool, or static.
	var tags: Array = card.get("tags", [])
	if "llm_generated" in tags:
		return "llm"
	if "emergency_fallback" in tags:
		return "fallback"
	var gen_by: String = str(card.get("_generated_by", ""))
	if gen_by.contains("llm"):
		return "llm"
	if gen_by != "":
		return "llm"  # Any _generated_by means LLM pipeline
	# Check if card has omniscient pipeline marker
	if card.has("_omniscient"):
		return "llm"
	return "fallback"


# ═══════════════════════════════════════════════════════════════════════════════
# CARD STACKING — Shadow cards pile up behind the active card
# ═══════════════════════════════════════════════════════════════════════════════

func _push_card_shadow() -> void:
	if not card_panel or not is_instance_valid(card_panel) or not card_container:
		return
	# Remove oldest shadow if at max
	if _card_shadows.size() >= MAX_CARD_SHADOWS:
		var oldest: Panel = _card_shadows.pop_front()
		if is_instance_valid(oldest):
			var fade_tw := create_tween()
			fade_tw.tween_property(oldest, "modulate:a", 0.0, 0.2)
			fade_tw.tween_callback(oldest.queue_free)

	# Create shadow from current card position
	var shadow := Panel.new()
	shadow.custom_minimum_size = card_panel.custom_minimum_size
	shadow.size = card_panel.size
	shadow.position = card_panel.position + Vector2(2, 2) * float(_card_shadows.size() + 1)
	shadow.modulate.a = maxf(0.06, 0.18 - 0.04 * float(_card_shadows.size()))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_style = card_panel.get_theme_stylebox("panel")
	if base_style:
		var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
		if style:
			style.bg_color = style.bg_color.darkened(0.15)
			shadow.add_theme_stylebox_override("panel", style)

	card_container.add_child(shadow)
	card_container.move_child(shadow, 0)  # Behind main card
	_card_shadows.append(shadow)


# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESSIVE INDICATORS — Reveal aspects and souffle one by one
# ═══════════════════════════════════════════════════════════════════════════════

func show_progressive_indicators() -> void:
	## Animate aspect and souffle indicators appearing one by one.
	if aspect_panel and is_instance_valid(aspect_panel):
		aspect_panel.modulate.a = 0.0
	if souffle_panel and is_instance_valid(souffle_panel):
		souffle_panel.modulate.a = 0.0

	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return

	# Reveal each aspect sequentially
	if aspect_panel and is_instance_valid(aspect_panel):
		aspect_panel.modulate.a = 1.0
	for aspect_name in MerlinConstants.TRIADE_ASPECTS:
		if aspect_displays.has(aspect_name):
			var container: Control = aspect_displays[aspect_name].get("container")
			if container and is_instance_valid(container):
				container.modulate.a = 0.0
				SFXManager.play_varied("aspect_shift", 0.1)
				var tw := create_tween()
				tw.tween_property(container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
				await tw.finished
				if not is_inside_tree():
					return
				await get_tree().create_timer(0.15).timeout

	# Reveal souffle
	if souffle_panel and is_instance_valid(souffle_panel):
		SFXManager.play("ogham_chime")
		var tw := create_tween()
		tw.tween_property(souffle_panel, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		await tw.finished


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT VFX — Biome-themed simple particles behind the card
# ═══════════════════════════════════════════════════════════════════════════════

func start_ambient_vfx(biome_key: String) -> void:
	## Start subtle ambient particle effects based on biome.
	_ambient_biome_key = biome_key
	if _ambient_timer:
		_ambient_timer.queue_free()
	_ambient_timer = Timer.new()
	_ambient_timer.wait_time = 2.0
	_ambient_timer.autostart = true
	_ambient_timer.timeout.connect(_spawn_ambient_particle)
	add_child(_ambient_timer)


func _spawn_ambient_particle() -> void:
	if _ambient_particles.size() >= MAX_AMBIENT_PARTICLES or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	var px := ColorRect.new()
	px.size = Vector2(randf_range(3.0, 5.0), randf_range(3.0, 5.0))
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.z_index = -1
	px.modulate.a = randf_range(0.15, 0.35)

	var start_pos := Vector2.ZERO
	var end_pos := Vector2.ZERO
	var duration: float = randf_range(4.0, 7.0)

	var key: String = _ambient_biome_key.replace("foret_", "").replace("landes_", "") \
		.replace("cotes_", "").replace("villages_", "").replace("cercles_", "") \
		.replace("marais_", "").replace("collines_", "")

	match key:
		"broceliande":
			# Falling leaves (green/brown)
			px.color = [Color(0.35, 0.55, 0.28), Color(0.55, 0.40, 0.25)][randi() % 2]
			start_pos = Vector2(randf_range(0, vp.x), -10)
			end_pos = start_pos + Vector2(randf_range(-60, 60), vp.y + 20)
		"bruyere":
			# Wind dust (horizontal)
			px.color = Color(0.55, 0.40, 0.55, 0.5)
			start_pos = Vector2(-10, randf_range(vp.y * 0.3, vp.y * 0.8))
			end_pos = Vector2(vp.x + 10, start_pos.y + randf_range(-30, 30))
			duration = randf_range(3.0, 5.0)
		"sauvages":
			# Rising mist (blue)
			px.color = Color(0.38, 0.58, 0.75, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-20, 20), -vp.y * 0.4)
		"celtes":
			# Rising smoke (gray)
			px.color = Color(0.5, 0.48, 0.45, 0.3)
			start_pos = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-15, 15), -vp.y * 0.5)
		"pierres":
			# Fireflies (warm yellow glow)
			px.color = Color(0.85, 0.75, 0.30, 0.6)
			px.size = Vector2(3, 3)
			start_pos = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), randf_range(vp.y * 0.2, vp.y * 0.8))
			end_pos = start_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			duration = randf_range(2.0, 4.0)
		"korrigans":
			# Phosphorescence (dark green)
			px.color = Color(0.20, 0.45, 0.25, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.6, 0.95))
			end_pos = start_pos + Vector2(randf_range(-25, 25), randf_range(-20, -50))
			duration = randf_range(3.0, 5.0)
		"dolmens":
			# Grass swaying (green tufts)
			px.color = Color(0.40, 0.60, 0.30, 0.3)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.7, 0.95))
			end_pos = start_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
			duration = randf_range(2.0, 4.0)
		_:
			# Default: gentle floating motes
			px.color = Color(0.6, 0.55, 0.45, 0.2)
			start_pos = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
			end_pos = start_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	px.position = start_pos
	add_child(px)
	_ambient_particles.append(px)

	var tw := create_tween()
	tw.tween_property(px, "position", end_pos, duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(px, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_callback(func():
		_ambient_particles.erase(px)
		if is_instance_valid(px):
			px.queue_free()
	)


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
	print("[TriadeUI] show_narrator_intro()")
	SFXManager.play("whoosh")
	_narrator_active = true

	# Hide game UI during intro
	if options_container and is_instance_valid(options_container):
		options_container.modulate.a = 0.0
	if info_panel and is_instance_valid(info_panel):
		info_panel.modulate.a = 0.0

	# Show Merlin as speaker
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Pick intro text
	var intro_text: String = NARRATOR_INTROS[randi() % NARRATOR_INTROS.size()]

	# Static badge for narrator intro
	if _card_source_badge and is_instance_valid(_card_source_badge):
		LLMSourceBadge.update_badge(_card_source_badge, "static")
		_card_source_badge.visible = true

	# Typewriter the intro
	await _typewriter_card_text(intro_text)

	# Wait for player to acknowledge
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.5).timeout

	# Fade in game UI
	if options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.4)
	if info_panel and is_instance_valid(info_panel):
		var tw2 := create_tween()
		tw2.tween_property(info_panel, "modulate:a", 1.0, 0.4)

	_narrator_active = false
	narrator_intro_finished.emit()
	print("[TriadeUI] narrator intro finished")


func _typewriter_card_text(full_text: String) -> void:
	## Typewriter effect for card text with procedural blip sound.
	if card_text == null or not is_instance_valid(card_text):
		return

	_typewriter_active = true
	_typewriter_abort = false
	card_text.text = ""
	card_text.visible_characters = 0

	# Set full text but reveal character by character
	card_text.text = full_text
	var total := full_text.length()

	for i in range(total):
		if _typewriter_abort or not is_inside_tree():
			if is_instance_valid(card_text):
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

	if is_instance_valid(card_text):
		card_text.visible_characters = -1
	_typewriter_active = false


func _play_blip() -> void:
	## Procedural keyboard click sound (pooled — no node leak).
	if _blip_pool.is_empty():
		return
	var player: AudioStreamPlayer = _blip_pool[_blip_idx]
	_blip_idx = (_blip_idx + 1) % BLIP_POOL_SIZE
	if player.playing:
		player.stop()
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
		SFXManager.play("click")
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

	SFXManager.play("choice_select")

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

	# Life depleted indicator
	if ending.get("life_depleted", false):
		var life_lbl := Label.new()
		life_lbl.text = "Essences de vie epuisees"
		if body_font:
			life_lbl.add_theme_font_override("font", body_font)
		life_lbl.add_theme_font_size_override("font_size", 14)
		life_lbl.add_theme_color_override("font_color", Color(0.78, 0.35, 0.22))
		life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(life_lbl)

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

	# Rewards section
	var rewards: Dictionary = ending.get("rewards", {})
	if rewards.size() > 0:
		var rewards_title := Label.new()
		rewards_title.text = "Recompenses obtenues"
		if title_font:
			rewards_title.add_theme_font_override("font", title_font)
		rewards_title.add_theme_font_size_override("font_size", 18)
		rewards_title.add_theme_color_override("font_color", PALETTE.accent)
		rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rewards_title)

		# Essences earned
		var ess: Dictionary = rewards.get("essence", {})
		if ess.size() > 0:
			var parts: PackedStringArray = []
			for elem in ess:
				if int(ess[elem]) > 0:
					parts.append("%s +%d" % [str(elem).left(4), int(ess[elem])])
			if parts.size() > 0:
				var ess_lbl := Label.new()
				ess_lbl.text = "Essences: " + " | ".join(parts)
				if body_font:
					ess_lbl.add_theme_font_override("font", body_font)
				ess_lbl.add_theme_font_size_override("font_size", 13)
				ess_lbl.add_theme_color_override("font_color", PALETTE.ink)
				ess_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				ess_lbl.custom_minimum_size.x = 400
				vbox.add_child(ess_lbl)

		# Fragments, Liens, Gloire
		var currency_parts: PackedStringArray = []
		var frag: int = int(rewards.get("fragments", 0))
		var liens: int = int(rewards.get("liens", 0))
		var gloire_r: int = int(rewards.get("gloire", 0))
		if frag > 0:
			currency_parts.append("Fragments +%d" % frag)
		if liens > 0:
			currency_parts.append("Liens +%d" % liens)
		if gloire_r > 0:
			currency_parts.append("Gloire +%d" % gloire_r)
		if currency_parts.size() > 0:
			var cur_lbl := Label.new()
			cur_lbl.text = " | ".join(currency_parts)
			if body_font:
				cur_lbl.add_theme_font_override("font", body_font)
			cur_lbl.add_theme_font_size_override("font_size", 14)
			cur_lbl.add_theme_color_override("font_color", PALETTE.accent)
			cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(cur_lbl)

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

	# Action buttons
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_hub := Button.new()
	btn_hub.text = "Retour au Hub"
	btn_hub.custom_minimum_size = Vector2(200, 50)
	btn_hub.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/HubAntre.tscn"))
	btn_box.add_child(btn_hub)

	var btn_new := Button.new()
	btn_new.text = "Nouvelle Aventure"
	btn_new.custom_minimum_size = Vector2(200, 50)
	btn_new.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TransitionBiome.tscn"))
	btn_box.add_child(btn_new)


# ═══════════════════════════════════════════════════════════════════════════════
# D20 DICE UI (Phase 37 — Fusion)
# ═══════════════════════════════════════════════════════════════════════════════

var _dice_overlay: Control = null
var _dice_display: Label = null
var _dice_dc_label: Label = null
var _dice_result_label: Label = null

func show_dice_roll(dc: int, target: int) -> void:
	## Show D20 dice animation (2.2s deceleration + bounce). Await this.
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 0.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = "?"
	_dice_display.add_theme_color_override("font_color", PALETTE.ink)
	_dice_display.scale = Vector2.ONE
	_dice_display.rotation = 0.0

	# Fade in dice area
	var tw_in := create_tween()
	tw_in.tween_property(_dice_overlay, "modulate:a", 1.0, 0.2)
	await tw_in.finished

	# Dice roll animation: decelerate over 2.2s
	var duration := 2.2
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		var progress: float = elapsed / duration
		var cycle_speed: float = lerpf(0.07, 0.35, progress * progress)
		_dice_display.text = str(randi_range(1, 20))
		_dice_display.rotation = randf_range(-0.08, 0.08) * (1.0 - progress)
		await get_tree().create_timer(cycle_speed).timeout
		elapsed += cycle_speed

	# Land on target
	_dice_display.text = str(target)
	_dice_display.rotation = 0.0
	# Bounce elastic
	_dice_display.pivot_offset = _dice_display.size / 2.0
	var tw_bounce := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_bounce.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
	tw_bounce.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)
	await tw_bounce.finished


func show_dice_instant(dc: int, value: int) -> void:
	## Show dice result instantly (after minigame).
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = str(value)
	_dice_display.rotation = 0.0
	var glow: Color = _dice_outcome_color(value, dc)
	_dice_display.add_theme_color_override("font_color", glow)
	# Bounce
	_dice_display.pivot_offset = _dice_display.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)


func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	## Show final dice result text + color.
	_ensure_dice_overlay()
	var glow: Color = _dice_outcome_color(roll, dc)
	_dice_display.add_theme_color_override("font_color", glow)

	match outcome:
		"critical_success":
			_dice_result_label.text = "Coup Critique !"
			_dice_result_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.2))
		"success":
			_dice_result_label.text = "Reussite ! (%d >= %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
		"failure":
			_dice_result_label.text = "Echec... (%d < %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		"critical_failure":
			_dice_result_label.text = "Echec Critique !"
			_dice_result_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))


func _dice_outcome_color(roll: int, dc: int) -> Color:
	if roll == 20:
		return Color(0.85, 0.72, 0.2)  # Gold
	elif roll == 1:
		return Color(0.7, 0.2, 0.2)  # Dark red
	elif roll >= dc:
		return Color(0.3, 0.7, 0.3)  # Green
	else:
		return Color(0.7, 0.3, 0.3)  # Red


func _ensure_dice_overlay() -> void:
	## Create dice UI elements if not yet built.
	if _dice_overlay and is_instance_valid(_dice_overlay):
		return
	_dice_overlay = Control.new()
	_dice_overlay.name = "DiceOverlay"
	_dice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.visible = false
	add_child(_dice_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	_dice_dc_label = Label.new()
	_dice_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_dc_label.add_theme_font_size_override("font_size", 14)
	_dice_dc_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	if body_font:
		_dice_dc_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_dc_label)

	_dice_display = Label.new()
	_dice_display.text = "?"
	_dice_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		_dice_display.add_theme_font_override("font", title_font)
	_dice_display.add_theme_font_size_override("font_size", 72)
	_dice_display.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(_dice_display)

	_dice_result_label = Label.new()
	_dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_label.add_theme_font_size_override("font_size", 16)
	if body_font:
		_dice_result_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_result_label)


func _hide_dice_overlay() -> void:
	if _dice_overlay and is_instance_valid(_dice_overlay):
		var tw := create_tween()
		tw.tween_property(_dice_overlay, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _dice_overlay.visible = false)


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME INTRO & SCORE DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

const MINIGAME_FIELD_ICONS := {
	"combat": "\u2694",
	"exploration": "\uD83D\uDD0D",
	"mysticisme": "\u2728",
	"survie": "\u2605",
	"diplomatie": "\u2696",
}

func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	## Brief overlay announcing the minigame type and any tool bonus.
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.04, 0.03, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	# Field icon
	var icon_label := Label.new()
	var field_icon: String = MINIGAME_FIELD_ICONS.get(field, "\u2726")
	icon_label.text = field_icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_label)

	# Field name
	var name_label := Label.new()
	name_label.text = "Epreuve: %s" % field.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		name_label.add_theme_font_override("font", title_font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", PALETTE.paper)
	vbox.add_child(name_label)

	# Tool bonus
	if tool_bonus != 0 and tool_bonus_text != "":
		var bonus_label := Label.new()
		bonus_label.text = "%s DC %d" % [tool_bonus_text, tool_bonus]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			bonus_label.add_theme_font_override("font", body_font)
		bonus_label.add_theme_font_size_override("font_size", 16)
		bonus_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		vbox.add_child(bonus_label)

	# Animate in then auto-remove
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(overlay.queue_free)


func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	## Brief display: "Score: 78 → D20: 17" (optional tool bonus shown).
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	var bonus_text: String = ""
	if tool_bonus != 0:
		bonus_text = " (bonus %d)" % tool_bonus
	_dice_dc_label.text = "Score: %d \u2192 D20: %d%s" % [score, d20, bonus_text]
	_dice_dc_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_dice_display.text = str(d20)
	_dice_result_label.text = ""


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL ANIMATION (fog overlay between cards)
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String) -> void:
	## Full-screen fog overlay with contextual text. Awaitable.
	_hide_dice_overlay()
	SFXManager.play("mist_breath")

	var fog := ColorRect.new()
	fog.name = "TravelFog"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.color = Color(0.08, 0.06, 0.04, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if body_font:
		lbl.add_theme_font_override("font", body_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	fog.add_child(lbl)

	# Fade in
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(fog, "color:a", 0.85, 0.6)
	tw_in.tween_property(lbl, "theme_override_colors/font_color:a", 1.0, 0.6)
	await tw_in.finished

	# Hold
	if is_inside_tree():
		await get_tree().create_timer(1.2).timeout

	# Fade out
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(fog, "color:a", 0.0, 0.6)
	tw_out.tween_property(lbl, "theme_override_colors/font_color:a", 0.0, 0.6)
	await tw_out.finished

	if is_instance_valid(fog):
		fog.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# REACTION TEXT + CRITICAL BADGE + BIOME PASSIVE
# ═══════════════════════════════════════════════════════════════════════════════

func show_reaction_text(text: String, outcome: String) -> void:
	## Show narrative reaction on the card text area.
	if not card_text or not is_instance_valid(card_text):
		return
	var color: Color = Color(0.3, 0.65, 0.3) if outcome.contains("success") else Color(0.7, 0.3, 0.3)
	card_text.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	card_text.visible_characters = -1


func show_critical_badge() -> void:
	## Pulse gold border on the card panel to indicate critical choice.
	if not card_panel or not is_instance_valid(card_panel):
		return
	var base_style = card_panel.get_theme_stylebox("panel")
	if not base_style:
		return
	var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	if style:
		style.border_color = Color(0.85, 0.72, 0.2)
		style.set_border_width_all(3)
		card_panel.add_theme_stylebox_override("panel", style)
	# Pulse animation (infinite, stop on next card display)
	var tw := create_tween().set_loops(0)
	tw.tween_property(card_panel, "modulate", Color(1.15, 1.1, 0.9), 0.3)
	tw.tween_property(card_panel, "modulate", Color.WHITE, 0.3)


func show_biome_passive(passive: Dictionary) -> void:
	## Brief notification for biome passive effect.
	var text: String = str(passive.get("text", "Force du biome..."))
	var notif := Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notif.add_theme_font_size_override("font_size", 14)
	notif.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5))
	if body_font:
		notif.add_theme_font_override("font", body_font)
	notif.modulate.a = 0.0
	add_child(notif)
	var tw := create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(notif, "modulate:a", 0.0, 0.3)
	tw.tween_callback(notif.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OUTCOME ANIMATIONS (shake, pulse, particles)
# ═══════════════════════════════════════════════════════════════════════════════

func animate_card_outcome(outcome: String) -> void:
	## Animate card panel based on D20 outcome.
	if not card_panel or not is_instance_valid(card_panel):
		return
	match outcome:
		"critical_success":
			# Gold pulse
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.08, 1.08), 0.2)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"success":
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.04, 1.04), 0.15)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.2)
		"failure":
			# Shake horizontal x3
			var tw := create_tween()
			for i in range(3):
				tw.tween_property(card_panel, "position:x", card_panel.position.x + 8, 0.05).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", card_panel.position.x - 8, 0.05).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", card_panel.position.x, 0.05)
		"critical_failure":
			# Violent shake x5 + shrink
			var tw := create_tween()
			for i in range(5):
				tw.tween_property(card_panel, "position:x", card_panel.position.x + 14, 0.04).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", card_panel.position.x - 14, 0.04).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", card_panel.position.x, 0.04)
			tw.tween_property(card_panel, "scale", Vector2(0.97, 0.97), 0.1)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.15)


func _exit_tree() -> void:
	## Cleanup to prevent orphaned nodes and dangling signals.
	_typewriter_abort = true
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
