extends Button
class_name MenuReturnButton
## Reusable button to return to main menu from any scene.
## Add this scene/node to any game scene that needs a menu return option.
##
## Usage:
##   1. Add this script to a Button node
##   2. Or instantiate the packed scene: res://scenes/ui/MenuReturnButton.tscn

const MENU_SCENE := "res://scenes/MenuPrincipal.tscn"
const BUTTON_SIZE := Vector2(100, 40)
const BUTTON_MARGIN := 16

@export var button_text: String = "Menu"
@export var position_corner: int = 0  # 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
@export var confirm_before_exit: bool = false
@export var custom_menu_scene: String = ""

var _tween: Tween
var _confirm_dialog: AcceptDialog


func _ready() -> void:
	text = button_text
	custom_minimum_size = BUTTON_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_apply_style()
	_position_button()

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	get_viewport().size_changed.connect(_position_button)


func _apply_style() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = MerlinVisual.PALETTE.paper
	normal.border_color = MerlinVisual.PALETTE.ink_soft
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)

	var hover := normal.duplicate()
	hover.bg_color = MerlinVisual.PALETTE.paper_dark
	hover.border_color = MerlinVisual.PALETTE.accent

	var pressed_style := hover.duplicate()
	pressed_style.bg_color = Color(MerlinVisual.PALETTE.paper_dark.r, MerlinVisual.PALETTE.paper_dark.g, MerlinVisual.PALETTE.paper_dark.b, 0.9)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", hover)

	add_theme_color_override("font_color", MerlinVisual.PALETTE.ink)
	add_theme_color_override("font_hover_color", MerlinVisual.PALETTE.accent)
	add_theme_color_override("font_pressed_color", MerlinVisual.PALETTE.accent)
	add_theme_font_size_override("font_size", 16)

	pivot_offset = BUTTON_SIZE / 2


func _position_button() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	match position_corner:
		0:  # Top-left
			position = Vector2(BUTTON_MARGIN, BUTTON_MARGIN)
		1:  # Top-right
			position = Vector2(viewport_size.x - BUTTON_SIZE.x - BUTTON_MARGIN, BUTTON_MARGIN)
		2:  # Bottom-left
			position = Vector2(BUTTON_MARGIN, viewport_size.y - BUTTON_SIZE.y - BUTTON_MARGIN)
		3:  # Bottom-right
			position = Vector2(viewport_size.x - BUTTON_SIZE.x - BUTTON_MARGIN, viewport_size.y - BUTTON_SIZE.y - BUTTON_MARGIN)


func _on_hover(hovering: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hovering:
		_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	else:
		_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)


func _on_pressed() -> void:
	if confirm_before_exit:
		_show_confirm_dialog()
	else:
		_return_to_menu()


func _show_confirm_dialog() -> void:
	if _confirm_dialog == null:
		_confirm_dialog = AcceptDialog.new()
		_confirm_dialog.title = "Retour au menu"
		_confirm_dialog.dialog_text = "Voulez-vous vraiment quitter et retourner au menu principal?"
		_confirm_dialog.ok_button_text = "Oui"
		_confirm_dialog.add_cancel_button("Non")
		_confirm_dialog.confirmed.connect(_return_to_menu)
		add_child(_confirm_dialog)

	_confirm_dialog.popup_centered()


func _return_to_menu() -> void:
	var target_scene: String = custom_menu_scene if custom_menu_scene != "" else MENU_SCENE

	# Animate out
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(get_tree().current_scene, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func():
		PixelTransition.transition_to(target_scene)
	)


## Static helper to add menu button to any scene
static func add_to_scene(scene_root: Node, corner: int = 0, confirm: bool = false) -> MenuReturnButton:
	var btn := MenuReturnButton.new()
	btn.position_corner = corner
	btn.confirm_before_exit = confirm
	scene_root.add_child(btn)
	return btn
