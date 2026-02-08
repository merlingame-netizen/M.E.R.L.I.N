extends Control
## Menu Principal DRU - Effets GBC authentiques
## Reproduction fidèle des effets React (TitleScreen)

# ══════════════════════════════════════════════════════════════════════════════
# PALETTE GBC (identique au React)
# ══════════════════════════════════════════════════════════════════════════════

const PALETTE = {
	"white": Color("#e8e8e8"),
	"cream": Color("#f8f0d8"),
	"light_gray": Color("#b8b0a0"),
	"gray": Color("#787870"),
	"dark_gray": Color("#484840"),
	"black": Color("#181810"),
	
	"grass_light": Color("#88d850"),
	"grass": Color("#48a028"),
	"grass_dark": Color("#306018"),
	
	"water_light": Color("#78c8f0"),
	"water": Color("#3888c8"),
	"water_dark": Color("#205898"),
	
	"fire_light": Color("#f8a850"),
	"fire": Color("#e07028"),
	"fire_dark": Color("#a04818"),
	
	"mystic_light": Color("#c0a0e0"),
	"mystic": Color("#8868b0"),
	"mystic_dark": Color("#504078"),
	
	"thunder": Color("#e8c830"),
}

# ══════════════════════════════════════════════════════════════════════════════
# RÉFÉRENCES NODES
# ══════════════════════════════════════════════════════════════════════════════

@onready var background: ColorRect = $Background
@onready var dither_overlay: ColorRect = $DitherOverlay
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var bestiole_sprite: TextureRect = $VBoxContainer/BestioleContainer/BestioleSprite
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var buttons_container: VBoxContainer = $VBoxContainer/MenuContainer
@onready var version_label: Label = $VersionLabel

# Boutons
@onready var btn_continuer: Button = $VBoxContainer/MenuContainer/BtnContinuer
@onready var btn_nouvelle: Button = $VBoxContainer/MenuContainer/BtnNouvelle
@onready var btn_charger: Button = $VBoxContainer/MenuContainer/BtnCharger
@onready var btn_repere: Button = $VBoxContainer/MenuContainer/BtnRepere

# ══════════════════════════════════════════════════════════════════════════════
# VARIABLES D'ANIMATION
# ══════════════════════════════════════════════════════════════════════════════

var frame_counter: int = 0
var title_base_y: float = 0.0
var selected_button_index: int = 0
var buttons: Array[Button] = []

# Animation Bestiole (4 frames comme React)
var bestiole_anim_frame: int = 0
var bestiole_bounce_values: Array = [0, -2, 0, -1]  # Identique React
var bestiole_squish_values: Array = [1.0, 1.05, 1.0, 0.98]

# ══════════════════════════════════════════════════════════════════════════════
# INITIALISATION
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_palette()
	_setup_dither_pattern()
	_setup_title_style()
	_setup_buttons()
	_setup_version()
	
	# Stocker position initiale du titre
	if title_label:
		title_base_y = title_label.position.y
	
	# Collecter les boutons
	if buttons_container:
		for child in buttons_container.get_children():
			if child is Button:
				buttons.append(child)
				_style_gbc_button(child)
	
	# Sélection initiale
	_update_button_selection()

func _setup_palette() -> void:
	# Fond vert foncé GBC
	if background:
		background.color = PALETTE.grass_dark

func _setup_dither_pattern() -> void:
	# Le dither sera géré par un shader ou une texture
	if dither_overlay:
		dither_overlay.color = Color(0, 0, 0, 0)  # Transparent par défaut
		# Appliquer le shader dither
		var shader_material = ShaderMaterial.new()
		shader_material.shader = _create_dither_shader()
		dither_overlay.material = shader_material

func _create_dither_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.094, 0.094, 0.063, 0.3);
uniform float line_height : hint_range(1.0, 10.0) = 2.0;
uniform float gap_height : hint_range(1.0, 10.0) = 2.0;

void fragment() {
	float y = UV.y * (1.0 / TEXTURE_PIXEL_SIZE.y);
	float pattern = mod(y, line_height + gap_height);
	
	if (pattern < line_height) {
		COLOR = line_color;
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
"""
	return shader

func _setup_title_style() -> void:
	if title_label:
		title_label.text = "DRU"
		title_label.add_theme_color_override("font_color", PALETTE.cream)
		title_label.add_theme_color_override("font_shadow_color", PALETTE.black)
		title_label.add_theme_constant_override("shadow_offset_x", 4)
		title_label.add_theme_constant_override("shadow_offset_y", 4)
	
	if subtitle_label:
		subtitle_label.text = "Le Jeu des Oghams"
		subtitle_label.add_theme_color_override("font_color", PALETTE.grass)

func _setup_buttons() -> void:
	# Configuration des boutons avec style GBC
	pass

func _setup_version() -> void:
	if version_label:
		version_label.text = "v6.0 — MaxCorp Interactive"
		version_label.add_theme_color_override("font_color", PALETTE.gray)

# ══════════════════════════════════════════════════════════════════════════════
# STYLE BOUTON GBC
# ══════════════════════════════════════════════════════════════════════════════

func _style_gbc_button(button: Button, variant: String = "default") -> void:
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	var style_focus = StyleBoxFlat.new()
	
	# Couleurs selon variante (identique React)
	var bg_color: Color
	var border_color: Color
	var text_color: Color
	
	match variant:
		"primary":
			bg_color = PALETTE.grass
			border_color = PALETTE.grass_dark
			text_color = PALETTE.white
		"water":
			bg_color = PALETTE.water
			border_color = PALETTE.water_dark
			text_color = PALETTE.white
		"mystic":
			bg_color = PALETTE.mystic
			border_color = PALETTE.mystic_dark
			text_color = PALETTE.white
		"danger":
			bg_color = PALETTE.fire
			border_color = PALETTE.fire_dark
			text_color = PALETTE.white
		_:  # default
			bg_color = PALETTE.cream
			border_color = PALETTE.black
			text_color = PALETTE.black
	
	# Style normal avec ombre portée (3px comme React)
	style_normal.bg_color = bg_color
	style_normal.border_color = border_color
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(4)
	style_normal.shadow_color = PALETTE.dark_gray
	style_normal.shadow_offset = Vector2(3, 3)
	style_normal.shadow_size = 0
	
	# Style hover
	style_hover.bg_color = bg_color.lightened(0.1)
	style_hover.border_color = border_color
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(4)
	style_hover.shadow_color = PALETTE.dark_gray
	style_hover.shadow_offset = Vector2(3, 3)
	
	# Style pressed (sans ombre, décalé comme React)
	style_pressed.bg_color = bg_color.darkened(0.1)
	style_pressed.border_color = border_color
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(4)
	style_pressed.shadow_size = 0
	
	# Style focus
	style_focus.bg_color = bg_color
	style_focus.border_color = PALETTE.mystic
	style_focus.set_border_width_all(3)
	style_focus.set_corner_radius_all(4)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("focus", style_focus)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)

# ══════════════════════════════════════════════════════════════════════════════
# BOUCLE D'ANIMATION (reproduit useFrameCounter React)
# ══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	frame_counter += 1
	
	_animate_title_bounce()
	_animate_bestiole()
	_animate_button_selection()

func _animate_title_bounce() -> void:
	# Effet bounce identique React: Math.floor(frame / 20) % 2 * 2
	if title_label:
		var bounce_phase = int(frame_counter / 20) % 2
		var bounce_offset = bounce_phase * 2.0
		title_label.position.y = title_base_y + bounce_offset

func _animate_bestiole() -> void:
	# Animation 4 frames identique React: Math.floor(frame / 12) % 4
	if bestiole_sprite:
		bestiole_anim_frame = int(frame_counter / 12) % 4
		
		# Bounce Y
		var bounce_y = bestiole_bounce_values[bestiole_anim_frame]
		bestiole_sprite.position.y = bounce_y
		
		# Squish (scale)
		var squish = bestiole_squish_values[bestiole_anim_frame]
		bestiole_sprite.scale = Vector2(squish, 1.0 / squish)

func _animate_button_selection() -> void:
	# Clignotement de la flèche de sélection: Math.floor(frame / 15) % 2
	var blink = int(frame_counter / 15) % 2
	
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == selected_button_index:
			# Ajouter/retirer la flèche clignotante
			var arrow = "▶ " if blink == 1 else "  "
			if not btn.text.begins_with("▶") and not btn.text.begins_with("  "):
				btn.text = arrow + btn.text.strip_edges()
			else:
				btn.text = arrow + btn.text.substr(2).strip_edges()
		else:
			# Retirer la flèche
			if btn.text.begins_with("▶ ") or btn.text.begins_with("  "):
				btn.text = btn.text.substr(2).strip_edges()

func _update_button_selection() -> void:
	for i in range(buttons.size()):
		if i == selected_button_index:
			buttons[i].grab_focus()

# ══════════════════════════════════════════════════════════════════════════════
# INPUT (navigation clavier GBC style)
# ══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		selected_button_index = (selected_button_index + 1) % buttons.size()
		_update_button_selection()
	elif event.is_action_pressed("ui_up"):
		selected_button_index = (selected_button_index - 1 + buttons.size()) % buttons.size()
		_update_button_selection()
	elif event.is_action_pressed("ui_accept"):
		if buttons.size() > selected_button_index:
			buttons[selected_button_index].emit_signal("pressed")

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAUX BOUTONS
# ══════════════════════════════════════════════════════════════════════════════

func _on_btn_continuer_pressed() -> void:
	print("Continuer la partie")
	# get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_btn_nouvelle_pressed() -> void:
	print("Nouvelle partie")
	# get_tree().change_scene_to_file("res://scenes/Intro.tscn")

func _on_btn_charger_pressed() -> void:
	print("Charger une partie")
	# Afficher menu de sauvegarde

func _on_btn_repere_pressed() -> void:
	print("Aller au repère")
	# get_tree().change_scene_to_file("res://scenes/Hub.tscn")
