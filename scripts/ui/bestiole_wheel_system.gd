## =============================================================================
## Bestiole Wheel System — Radial Ogham Selector
## =============================================================================
## A radial menu for selecting Bestiole skills (Oghams).
## 18 skills organized in 6 categories, displayed as pie sectors.
## Integrated with MerlinStore for state management.
## =============================================================================

extends Control
class_name BestioleWheelSystem

signal ogham_selected(skill_id: String)
signal wheel_opened
signal wheel_closed

# =============================================================================
# CONFIGURATION
# =============================================================================

const WHEEL_RADIUS := 160.0
const INNER_RADIUS := 60.0
const CENTER_RADIUS := 40.0
const SECTOR_COUNT := 6
const ITEMS_PER_SECTOR := 3
const OPEN_DURATION := MerlinVisual.ANIM_NORMAL
const CLOSE_DURATION := MerlinVisual.ANIM_FAST
const MIN_TOUCH_TARGET := 48.0

const CATEGORY_ORDER: Array[String] = ["reveal", "protection", "boost", "narrative", "recovery", "special"]

const AWEN_ICON := "᚛"
const AWEN_EMPTY := "\u25cb"

# =============================================================================
# STATE
# =============================================================================

var is_open := false
var hovered_sector := -1
var hovered_item := -1
var hovered_skill_id := ""
var _open_tween: Tween = null
var _wheel_scale := 0.0

# Data from store (synced before opening)
var available_skills: Array = []
var all_skills: Dictionary = {}  # skill_id -> {spec, can_use, cooldown, category_index, item_index}
var current_awen: int = 0
var current_bond: int = 0

# =============================================================================
# NODE REFERENCES (scene nodes)
# =============================================================================

@onready var bestiole_button: Button = $BestioleButton
@onready var awen_display: HBoxContainer = $AwenDisplay
@onready var wheel_overlay: CanvasLayer = $WheelOverlay
@onready var dim_bg: ColorRect = $WheelOverlay/DimBG
@onready var wheel_container: Control = $WheelOverlay/WheelContainer
@onready var tooltip_panel: PanelContainer = $WheelOverlay/TooltipPanel
@onready var tooltip_name: Label = $WheelOverlay/TooltipPanel/TooltipVBox/TooltipName
@onready var tooltip_tree: Label = $WheelOverlay/TooltipPanel/TooltipVBox/TooltipTree
@onready var tooltip_effect: Label = $WheelOverlay/TooltipPanel/TooltipVBox/TooltipEffect
@onready var tooltip_cost: Label = $WheelOverlay/TooltipPanel/TooltipVBox/TooltipCost
var _tooltip_ogham_icon: PixelOghamIcon

# Font
var _font: Font = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_font()
	_configure_bestiole_button()
	_configure_awen_display()
	_configure_wheel_overlay()
	_configure_tooltip()


func _load_font() -> void:
	_font = MerlinVisual.get_font("body")
	if _font == null:
		_font = MerlinVisual.get_font("title")


func _configure_bestiole_button() -> void:
	# Runtime styling (depends on MerlinVisual palette)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.PALETTE.paper_warm
	style.border_color = MerlinVisual.PALETTE.accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	style.shadow_color = MerlinVisual.PALETTE.shadow
	style.shadow_size = 4
	bestiole_button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = MerlinVisual.PALETTE.paper
	hover_style.border_color = MerlinVisual.PALETTE.celtic_gold
	hover_style.set_border_width_all(3)
	bestiole_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = MerlinVisual.PALETTE.accent_glow
	bestiole_button.add_theme_stylebox_override("pressed", pressed_style)

	bestiole_button.add_theme_color_override("font_color", MerlinVisual.PALETTE.accent)
	if _font:
		bestiole_button.add_theme_font_override("font", _font)

	bestiole_button.pressed.connect(_on_bestiole_pressed)


func _configure_awen_display() -> void:
	# Populate awen icons (dynamic count from MerlinConstants)
	for i in range(MerlinConstants.AWEN_MAX):
		var icon := Label.new()
		icon.text = AWEN_EMPTY
		icon.add_theme_font_size_override("font_size", 14)
		icon.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink_soft)
		if _font:
			icon.add_theme_font_override("font", _font)
		awen_display.add_child(icon)


func _configure_wheel_overlay() -> void:
	# Runtime color (depends on MerlinVisual palette)
	var dim_color: Color = Color(
		MerlinVisual.PALETTE["shadow"].r,
		MerlinVisual.PALETTE["shadow"].g,
		MerlinVisual.PALETTE["shadow"].b,
		0.5
	)
	dim_bg.color = dim_color
	dim_bg.gui_input.connect(_on_dim_bg_input)

	# Initial wheel scale
	wheel_container.pivot_offset = Vector2.ZERO
	wheel_container.scale = Vector2.ZERO


func _configure_tooltip() -> void:
	# Tooltip panel style (runtime palette)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.PALETTE.paper
	style.border_color = MerlinVisual.PALETTE.accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = MerlinVisual.PALETTE.shadow
	style.shadow_size = 6
	style.set_content_margin_all(10)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	# Pixel art ogham icon (dynamic, added before first label)
	var tooltip_vbox: VBoxContainer = $WheelOverlay/TooltipPanel/TooltipVBox
	_tooltip_ogham_icon = PixelOghamIcon.new()
	_tooltip_ogham_icon.setup("beith", 32.0)
	_tooltip_ogham_icon.reveal(true)
	_tooltip_ogham_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_vbox.add_child(_tooltip_ogham_icon)
	tooltip_vbox.move_child(_tooltip_ogham_icon, 0)

	# Runtime color overrides
	tooltip_name.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink)
	if _font:
		tooltip_name.add_theme_font_override("font", _font)
	tooltip_tree.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink_soft)
	tooltip_effect.add_theme_color_override("font_color", MerlinVisual.PALETTE.accent)
	tooltip_cost.add_theme_color_override("font_color", MerlinVisual.PALETTE.celtic_gold)


# =============================================================================
# WHEEL OPEN/CLOSE
# =============================================================================

func open_wheel(store: MerlinStore) -> void:
	if is_open:
		return

	_sync_from_store(store)

	is_open = true
	wheel_overlay.visible = true
	wheel_opened.emit()

	# Animate in
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.set_trans(Tween.TRANS_BACK)
	_open_tween.tween_property(wheel_container, "scale", Vector2.ONE, OPEN_DURATION)

	wheel_container.queue_redraw()


func close_wheel() -> void:
	if not is_open:
		return

	is_open = false
	hovered_sector = -1
	hovered_item = -1
	hovered_skill_id = ""
	tooltip_panel.visible = false

	# Animate out
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.set_ease(Tween.EASE_IN)
	_open_tween.set_trans(Tween.TRANS_QUAD)
	_open_tween.tween_property(wheel_container, "scale", Vector2.ZERO, CLOSE_DURATION)
	_open_tween.tween_callback(func(): wheel_overlay.visible = false)

	wheel_closed.emit()


func _sync_from_store(store: MerlinStore) -> void:
	current_awen = store.get_awen()
	current_bond = store.get_bestiole_bond()
	available_skills = store.get_available_oghams()
	all_skills.clear()

	var bestiole: Dictionary = store.state.get("bestiole", {})
	var cooldowns: Dictionary = bestiole.get("skill_cooldowns", {})
	var unlocked: Array = bestiole.get("skills_unlocked", [])

	for cat_idx in range(CATEGORY_ORDER.size()):
		var category: String = CATEGORY_ORDER[cat_idx]
		var item_idx: int = 0
		for skill_id in MerlinConstants.OGHAM_FULL_SPECS:
			var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[skill_id]
			if str(spec.get("category", "")) == category:
				var cd: int = int(cooldowns.get(skill_id, 0))
				var is_starter: bool = bool(spec.get("starter", false))
				var is_unlocked: bool = is_starter or unlocked.has(skill_id)
				all_skills[skill_id] = {
					"spec": spec,
					"can_use": available_skills.has(skill_id),
					"cooldown": cd,
					"unlocked": is_unlocked,
					"category_index": cat_idx,
					"item_index": item_idx,
				}
				item_idx += 1


# =============================================================================
# UPDATE METHODS (called by controller)
# =============================================================================

func update_awen(awen: int) -> void:
	current_awen = awen
	if not awen_display:
		return
	for i in range(MerlinConstants.AWEN_MAX):
		if i < awen_display.get_child_count():
			var icon: Label = awen_display.get_child(i) as Label
			if icon:
				if i < awen:
					icon.text = AWEN_ICON
					icon.add_theme_color_override("font_color", MerlinVisual.PALETTE.celtic_gold)
				else:
					icon.text = AWEN_EMPTY
					icon.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink_soft)


func update_bond(bond: int) -> void:
	current_bond = bond
	# Update button style based on bond tier
	if not bestiole_button:
		return
	if bond >= 81:
		bestiole_button.add_theme_color_override("font_color", MerlinVisual.PALETTE.celtic_gold)
	elif bond >= 41:
		bestiole_button.add_theme_color_override("font_color", MerlinVisual.PALETTE.accent)
	else:
		bestiole_button.add_theme_color_override("font_color", MerlinVisual.PALETTE.ink_soft)


func set_wheel_enabled(enabled: bool) -> void:
	if bestiole_button:
		bestiole_button.disabled = not enabled
		bestiole_button.modulate.a = 1.0 if enabled else 0.4


# =============================================================================
# DRAWING
# =============================================================================

func _draw_wheel() -> void:
	"""Called via queue_redraw on wheel_container."""
	if not is_open:
		return
	# The wheel is drawn as overlapping Controls; we use _draw on wheel_container
	wheel_container.queue_redraw()


# Override _draw on wheel_container isn't possible since it's a Control we added.
# Instead we use a custom drawing node.

func _setup_wheel_drawing() -> void:
	pass  # Drawing is done via child controls


# =============================================================================
# INPUT
# =============================================================================

func _input(event: InputEvent) -> void:
	if not is_open:
		# Tab to open (handled by controller, but fallback here)
		if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
			# Signal to controller
			pass
		return

	# Close on Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_wheel()
		get_viewport().set_input_as_handled()
		return

	# Mouse movement for hover detection
	if event is InputEventMouseMotion and is_open:
		var screen_center := get_viewport_rect().size / 2.0
		var local_pos: Vector2 = event.position - screen_center
		_update_hover(local_pos)
		wheel_container.queue_redraw()
		get_viewport().set_input_as_handled()

	# Click to select
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_open:
		if not hovered_skill_id.is_empty():
			var info: Dictionary = all_skills.get(hovered_skill_id, {})
			if info.get("can_use", false):
				ogham_selected.emit(hovered_skill_id)
				close_wheel()
				get_viewport().set_input_as_handled()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_wheel()


func _on_bestiole_pressed() -> void:
	# This signal tells the controller to open the wheel with store context
	# The controller will call open_wheel(store) in response
	if not is_open:
		wheel_opened.emit()
	else:
		close_wheel()


func _update_hover(local_pos: Vector2) -> void:
	var dist: float = local_pos.length()

	# Outside wheel
	if dist > WHEEL_RADIUS + 20 or dist < CENTER_RADIUS:
		hovered_sector = -1
		hovered_item = -1
		hovered_skill_id = ""
		tooltip_panel.visible = false
		return

	# Calculate sector from angle
	var angle: float = fmod(atan2(local_pos.y, local_pos.x) + TAU + PI / 2.0, TAU)
	var sector_angle: float = TAU / float(SECTOR_COUNT)
	var sector: int = int(angle / sector_angle)
	sector = clampi(sector, 0, SECTOR_COUNT - 1)

	# Calculate item within sector
	var item_angle: float = sector_angle / float(ITEMS_PER_SECTOR)
	var angle_in_sector: float = fmod(angle, sector_angle)
	var item: int = int(angle_in_sector / item_angle)
	item = clampi(item, 0, ITEMS_PER_SECTOR - 1)

	hovered_sector = sector
	hovered_item = item

	# Find the skill at this position
	hovered_skill_id = ""
	for skill_id in all_skills:
		var info: Dictionary = all_skills[skill_id]
		if int(info.get("category_index", -1)) == sector and int(info.get("item_index", -1)) == item:
			hovered_skill_id = skill_id
			break

	# Update tooltip
	if not hovered_skill_id.is_empty():
		var info: Dictionary = all_skills.get(hovered_skill_id, {})
		var spec: Dictionary = info.get("spec", {})
		# Update pixel ogham icon
		_tooltip_ogham_icon.setup(hovered_skill_id, 32.0)
		_tooltip_ogham_icon.reveal(true)
		_tooltip_ogham_icon.set_active(bool(info.get("can_use", false)))
		tooltip_name.text = "%s  %s" % [str(spec.get("unicode", "")), str(spec.get("name", ""))]
		tooltip_tree.text = str(spec.get("tree", ""))
		tooltip_effect.text = str(spec.get("description", ""))
		var cost: int = int(spec.get("awen_cost", 1))
		var cd: int = int(info.get("cooldown", 0))
		var cost_text: String = "Cout: %d Awen" % cost
		if cd > 0:
			cost_text += "  |  Cooldown: %d tours" % cd
		if not info.get("can_use", false):
			if not info.get("unlocked", false):
				cost_text = "Verrouille (Lien: %d requis)" % int(spec.get("bond_required", 0))
			elif cd > 0:
				cost_text = "En recharge: %d tours" % cd
			elif current_awen < cost:
				cost_text = "Awen insuffisant (%d/%d)" % [current_awen, cost]
		tooltip_cost.text = cost_text
		tooltip_panel.visible = true
	else:
		tooltip_panel.visible = false
