class_name MenuPrincipalTheme
extends RefCounted

## Theme and style building for the main menu (card, buttons, corner buttons, clock).

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _host: Control
var _title_font: Font
var _body_font: Font

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func init(host: Control, title_font: Font, body_font: Font) -> void:
	_host = host
	_title_font = title_font
	_body_font = body_font


func apply(
	title_label: Label,
	main_buttons: VBoxContainer,
	calendar_button: Button,
	collections_button: Button,
	clock_label: Label,
) -> void:
	var menu_theme := _build_menu_theme()
	_host.theme = menu_theme
	_style_title(title_label)
	_style_menu_buttons(main_buttons)
	_apply_corner_button_style(calendar_button)
	_apply_corner_button_style(collections_button)
	_apply_clock_style(clock_label)

# ---------------------------------------------------------------------------
# Theme construction
# ---------------------------------------------------------------------------

func _build_menu_theme() -> Theme:
	var menu_theme := Theme.new()

	# Card style
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	card_style.border_color = MerlinVisual.CRT_PALETTE.border
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.shadow_color = MerlinVisual.CRT_PALETTE.shadow
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 4)
	card_style.content_margin_left = 36
	card_style.content_margin_top = 32
	card_style.content_margin_right = 36
	card_style.content_margin_bottom = 32
	menu_theme.set_stylebox("panel", "PanelContainer", card_style)

	# Button styles
	var phosphor: Color = MerlinVisual.CRT_PALETTE.phosphor
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(phosphor.r, phosphor.g, phosphor.b, 0.03)
	btn_normal.border_color = Color(phosphor.r, phosphor.g, phosphor.b, 0.25)
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.corner_radius_top_left = 3
	btn_normal.corner_radius_top_right = 3
	btn_normal.corner_radius_bottom_left = 3
	btn_normal.corner_radius_bottom_right = 3
	btn_normal.content_margin_left = 24
	btn_normal.content_margin_top = 16
	btn_normal.content_margin_right = 24
	btn_normal.content_margin_bottom = 16

	var cyan_c: Color = MerlinVisual.CRT_PALETTE.cyan
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(cyan_c.r, cyan_c.g, cyan_c.b, 0.08)
	btn_hover.border_color = MerlinVisual.CRT_PALETTE.cyan
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 3
	btn_hover.corner_radius_top_right = 3
	btn_hover.corner_radius_bottom_left = 3
	btn_hover.corner_radius_bottom_right = 3
	btn_hover.shadow_color = Color(cyan_c.r, cyan_c.g, cyan_c.b, 0.2)
	btn_hover.shadow_size = 8
	btn_hover.content_margin_left = 24
	btn_hover.content_margin_top = 16
	btn_hover.content_margin_right = 24
	btn_hover.content_margin_bottom = 16

	var amber_c: Color = MerlinVisual.CRT_PALETTE.amber
	var btn_pressed := btn_hover.duplicate()
	btn_pressed.bg_color = Color(amber_c.r, amber_c.g, amber_c.b, 0.12)
	btn_pressed.border_color = MerlinVisual.CRT_PALETTE.amber
	btn_pressed.shadow_color = Color(amber_c.r, amber_c.g, amber_c.b, 0.25)

	menu_theme.set_stylebox("normal", "Button", btn_normal)
	menu_theme.set_stylebox("hover", "Button", btn_hover)
	menu_theme.set_stylebox("pressed", "Button", btn_pressed)
	menu_theme.set_stylebox("focus", "Button", btn_hover)
	menu_theme.set_stylebox("disabled", "Button", btn_normal)

	menu_theme.set_color("font_color", "Button", MerlinVisual.CRT_PALETTE.phosphor)
	menu_theme.set_color("font_hover_color", "Button", MerlinVisual.CRT_PALETTE.amber)
	menu_theme.set_color("font_pressed_color", "Button", MerlinVisual.CRT_PALETTE.amber)
	menu_theme.set_color("font_disabled_color", "Button", MerlinVisual.CRT_PALETTE.border)

	menu_theme.set_color("font_color", "Label", MerlinVisual.CRT_PALETTE.phosphor)

	return menu_theme

# ---------------------------------------------------------------------------
# Per-element styles
# ---------------------------------------------------------------------------

func _style_title(title_label: Label) -> void:
	if title_label and _title_font:
		title_label.add_theme_font_override("font", _title_font)
		title_label.add_theme_font_size_override("font_size", 52)
		title_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)


func _style_menu_buttons(main_buttons: VBoxContainer) -> void:
	for btn in main_buttons.get_children():
		if btn is Button:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var priority: String = btn.get_meta("priority", "secondary")
			match priority:
				"primary":
					if _title_font:
						btn.add_theme_font_override("font", _title_font)
					btn.add_theme_font_size_override("font_size", 30)
					btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.cyan)
					btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE.cyan_bright)
					btn.add_theme_color_override("font_pressed_color", MerlinVisual.CRT_PALETTE.amber)
					var pri_style := StyleBoxFlat.new()
					var pri_cyan: Color = MerlinVisual.CRT_PALETTE.cyan
					pri_style.bg_color = Color(pri_cyan.r, pri_cyan.g, pri_cyan.b, 0.06)
					pri_style.border_color = Color(pri_cyan.r, pri_cyan.g, pri_cyan.b, 0.5)
					pri_style.border_width_left = 2
					pri_style.border_width_right = 2
					pri_style.border_width_top = 2
					pri_style.border_width_bottom = 2
					pri_style.corner_radius_top_left = 4
					pri_style.corner_radius_top_right = 4
					pri_style.corner_radius_bottom_left = 4
					pri_style.corner_radius_bottom_right = 4
					pri_style.shadow_color = Color(pri_cyan.r, pri_cyan.g, pri_cyan.b, 0.15)
					pri_style.shadow_size = 12
					pri_style.content_margin_left = 32
					pri_style.content_margin_top = 18
					pri_style.content_margin_right = 32
					pri_style.content_margin_bottom = 18
					btn.add_theme_stylebox_override("normal", pri_style)
				"secondary":
					if _body_font:
						btn.add_theme_font_override("font", _body_font)
					btn.add_theme_font_size_override("font_size", 22)
					btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
				"tertiary":
					if _body_font:
						btn.add_theme_font_override("font", _body_font)
					btn.add_theme_font_size_override("font_size", 18)
					btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)


func _apply_corner_button_style(btn: Button) -> void:
	if btn:
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		var corner_size := Vector2(52, 52)
		btn.pivot_offset = corner_size * 0.5


func _apply_clock_style(clock_label: Label) -> void:
	if not clock_label:
		return
	if _body_font:
		clock_label.add_theme_font_override("font", _body_font)
	clock_label.add_theme_font_size_override("font_size", 28)
	clock_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
