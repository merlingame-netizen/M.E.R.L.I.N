extends Control

# ==============================================================================
# MENU PRINCIPAL - DRU: Le Jeu des Oghams
# Style Game Boy Color avec animations celtiques magiques
# ==============================================================================

# RÃ©fÃ©rences nodes
@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var vbox: VBoxContainer = $VBoxContainer
@onready var particles_container: Control = $ParticlesContainer
@onready var gameboy_frame: ColorRect = $GameboyFrame
@onready var black_overlay: ColorRect = $BlackOverlay
@onready var cursor_sprite: Control = $CursorSprite

# Polices
var font_celtic: FontFile
var font_celtic_thin: FontFile

# Ã‰tat animation
var intro_played := false
var time_elapsed := 0.0
var hovered_button: Button = null
var buttons: Array[Button] = []
var button_original_scales: Dictionary = {}
var magic_particles: Array[Dictionary] = []
var magic_comets: Array[Dictionary] = []
var runes_floating: Array[Dictionary] = []
var cursor_trail: Array[Dictionary] = []

# Day orb (24h) on an arc - positioned at top, full width
@export var day_arc_center_ratio := Vector2(0.5, 0.02)
@export var day_arc_radius_ratio := 0.48
@export var day_arc_width := 2.5
@export var day_arc_tick_count := 24
@export var day_arc_tick_length := 5.0
@export var day_orb_radius := 12.0
@export var day_orb_glow_scale := 4.0
@export var day_orb_use_system_time := true
@export var day_orb_hour_override := 12.0

var day_orb_fraction := 0.0

# Day orb color constants for time-based gradient
const DAY_ORB_COLORS = {
	"midnight": Color(0.3, 0.35, 0.45),      # Gray-blue at 0h
	"blue_hour": Color(0.2, 0.4, 0.8),       # Blue at 2h
	"dawn": Color(0.85, 0.85, 0.9),          # White-gray at 6h
	"noon": Color(1.0, 0.98, 0.9),           # Bright white at 12h
	"dusk": Color(0.05, 0.05, 0.08),         # Black at 18h
	"night": Color(0.15, 0.2, 0.35),         # Dark blue-gray at 22h
}

# Comet settings
const COMET_COUNT := 8
const COMET_MIN_SPEED := 140.0
const COMET_MAX_SPEED := 220.0
const COMET_MIN_TAIL := 40.0
const COMET_MAX_TAIL := 80.0
const COMET_MIN_LIFE := 1.2
const COMET_MAX_LIFE := 2.6

# Test scenes
const TEST_MERLIN_SCENE := "res://scenes/MerlinTest.tscn"
const TEST_TANIERE_SCENE := "res://scenes/TestTaniere.tscn"

# Couleurs GBC celtiques
const COLORS = {
	"bg_dark": Color(0.02, 0.05, 0.08),
	"bg_gradient_top": Color(0.05, 0.12, 0.15),
	"bg_gradient_bottom": Color(0.02, 0.04, 0.06),
	"gold": Color(0.85, 0.65, 0.2),
	"gold_bright": Color(1.0, 0.85, 0.4),
	"gold_dark": Color(0.5, 0.35, 0.1),
	"green_mystic": Color(0.2, 0.6, 0.3),
	"green_bright": Color(0.4, 0.85, 0.5),
	"purple_magic": Color(0.5, 0.2, 0.7),
	"blue_rune": Color(0.3, 0.5, 0.9),
	"white_glow": Color(0.95, 0.95, 0.9),
	"cream": Color(0.95, 0.9, 0.8),
}

# Runes Oghams pour dÃ©coration
const OGHAM_RUNES = ["áš", "áš‚", "ášƒ", "áš„", "áš…", "áš†", "áš‡", "ášˆ", "áš‰", "ášŠ", "áš‹", "ášŒ", "áš", "ášŽ", "áš", "áš", "áš‘", "áš’", "áš“", "áš”"]

func _ready() -> void:
	set_process(true)
	# Ensure the root Control covers the whole viewport so custom drawing is visible.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	# Charger les polices
	font_celtic = load("res://Resources/fonts/celtic_bit/celtic-bit.ttf")
	font_celtic_thin = load("res://Resources/fonts/celtic_bit/celtic-bit-thin.ttf")
	
	# CrÃ©er les Ã©lÃ©ments UI supplÃ©mentaires
	_setup_particles_container()
	_setup_gameboy_frame()
	_setup_black_overlay()
	_setup_cursor()
	_setup_background_shader()
	
	# Appliquer le style aux Ã©lÃ©ments existants
	_style_title()
	_style_subtitle()
	_style_buttons()
	
	# Initialiser les particules magiques
	_init_magic_particles(50)
	_init_magic_comets(COMET_COUNT)
	_init_floating_runes(12)
	
	# Cacher le curseur systÃ¨me
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Lancer l'animation d'intro
	_play_intro_animation()
	
	# Initial day orb position
	day_orb_fraction = _get_day_fraction()

func _setup_particles_container() -> void:
	if not has_node("ParticlesContainer"):
		particles_container = Control.new()
		particles_container.name = "ParticlesContainer"
		particles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particles_container)
		move_child(particles_container, 1)  # Juste aprÃ¨s background

func _setup_gameboy_frame() -> void:
	if not has_node("GameboyFrame"):
		gameboy_frame = ColorRect.new()
		gameboy_frame.name = "GameboyFrame"
		gameboy_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		gameboy_frame.color = Color(0.15, 0.15, 0.12)  # Gris Game Boy
		gameboy_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gameboy_frame)
		move_child(gameboy_frame, get_child_count() - 1)

func _setup_black_overlay() -> void:
	if not has_node("BlackOverlay"):
		black_overlay = ColorRect.new()
		black_overlay.name = "BlackOverlay"
		black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		black_overlay.color = Color.BLACK
		black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(black_overlay)
		move_child(black_overlay, get_child_count() - 1)

func _setup_cursor() -> void:
	if not has_node("CursorSprite"):
		cursor_sprite = Control.new()
		cursor_sprite.name = "CursorSprite"
		add_child(cursor_sprite)
		move_child(cursor_sprite, get_child_count() - 1)
	else:
		cursor_sprite = $CursorSprite
	
	cursor_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_sprite.z_index = 200
	cursor_sprite.size = get_viewport_rect().size
	
	if cursor_sprite.get_script() == null:
		var draw_script = GDScript.new()
		draw_script.source_code = "extends Control\nvar parent_menu\nfunc _ready():\n\tparent_menu = get_parent()\nfunc _draw():\n\tif parent_menu and parent_menu.has_method(\"_draw_cursor_layer\"):\n\t\tparent_menu._draw_cursor_layer(self)\n"
		draw_script.reload()
		cursor_sprite.set_script(draw_script)

func _setup_background_shader() -> void:
	# CrÃ©er un dÃ©gradÃ© animÃ© pour le fond
	if background:
		background.color = Color(0, 0, 0, 0)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _style_title() -> void:
	if not title_label:
		return
	
	title_label.text = "DRU"
	title_label.add_theme_font_override("font", font_celtic)
	title_label.add_theme_font_size_override("font_size", 120)
	title_label.add_theme_color_override("font_color", COLORS.gold)
	title_label.add_theme_color_override("font_shadow_color", COLORS.gold_dark)
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position.y = 80
	title_label.size = Vector2(400, 150)
	title_label.position.x = -200

func _style_subtitle() -> void:
	if not subtitle_label:
		return
	
	subtitle_label.text = "Le Jeu des Oghams"
	subtitle_label.add_theme_font_override("font", font_celtic_thin)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", COLORS.green_mystic)
	subtitle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Position sous le titre
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle_label.position.y = 200
	subtitle_label.size = Vector2(400, 40)
	subtitle_label.position.x = -200

func _style_buttons() -> void:
	if not vbox:
		return
	
	# Style du container
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-150, 50)
	vbox.size = Vector2(300, 400)
	vbox.add_theme_constant_override("separation", 15)
	
	# Style chaque bouton
	buttons.clear()
	for child in vbox.get_children():
		if child is Button:
			_style_single_button(child)
			buttons.append(child)
			button_original_scales[child] = Vector2.ONE

func _style_single_button(btn: Button) -> void:
	# Style de base
	btn.add_theme_font_override("font", font_celtic)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", COLORS.cream)
	btn.add_theme_color_override("font_hover_color", COLORS.gold_bright)
	btn.add_theme_color_override("font_pressed_color", COLORS.white_glow)
	btn.add_theme_color_override("font_focus_color", COLORS.gold)
	
	# StyleBox Normal
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.15, 0.12, 0.9)
	style_normal.border_color = COLORS.gold_dark
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(8)
	style_normal.content_margin_left = 20
	style_normal.content_margin_right = 20
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	style_normal.shadow_color = Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 4
	style_normal.shadow_offset = Vector2(2, 2)
	btn.add_theme_stylebox_override("normal", style_normal)
	
	# StyleBox Hover
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.25, 0.18, 0.95)
	style_hover.border_color = COLORS.gold
	style_hover.set_border_width_all(4)
	style_hover.set_corner_radius_all(8)
	style_hover.content_margin_left = 20
	style_hover.content_margin_right = 20
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	style_hover.shadow_color = COLORS.gold_dark
	style_hover.shadow_size = 8
	style_hover.shadow_offset = Vector2(0, 0)
	btn.add_theme_stylebox_override("hover", style_hover)
	
	# StyleBox Pressed
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.2, 0.35, 0.25, 1.0)
	style_pressed.border_color = COLORS.gold_bright
	style_pressed.set_border_width_all(4)
	style_pressed.set_corner_radius_all(6)
	style_pressed.content_margin_left = 20
	style_pressed.content_margin_right = 20
	style_pressed.content_margin_top = 14
	style_pressed.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	# StyleBox Focus
	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(0, 0, 0, 0)
	style_focus.border_color = COLORS.green_bright
	style_focus.set_border_width_all(2)
	style_focus.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("focus", style_focus)
	
	# Connecter les signaux hover
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_unhover.bind(btn))
	btn.pressed.connect(_on_button_pressed.bind(btn))
	
	# Taille minimum
	btn.custom_minimum_size = Vector2(280, 50)

func _init_magic_particles(count: int) -> void:
	magic_particles.clear()
	for i in range(count):
		magic_particles.append({
			"pos": Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y),
			"vel": Vector2(randf_range(-20, 20), randf_range(-30, -10)),
			"size": randf_range(2, 6),
			"alpha": randf_range(0.3, 0.8),
			"color_index": randi() % 3,  # 0: gold, 1: green, 2: blue
			"pulse_offset": randf() * TAU,
			"life": randf() * 5.0,
		})

func _init_magic_comets(count: int) -> void:
	magic_comets.clear()
	var viewport_size = get_viewport_rect().size
	for i in range(count):
		magic_comets.append(_spawn_comet(viewport_size, true))

func _spawn_comet(viewport_size: Vector2, random_delay: bool) -> Dictionary:
	var start_x = randf_range(-viewport_size.x * 0.2, viewport_size.x * 0.2)
	var start_y = randf_range(-viewport_size.y * 0.4, viewport_size.y * 0.2)
	var speed = randf_range(COMET_MIN_SPEED, COMET_MAX_SPEED)
	var dir = Vector2(randf_range(0.6, 1.0), randf_range(0.2, 0.6)).normalized()
	var vel = dir * speed
	var max_life = randf_range(COMET_MIN_LIFE, COMET_MAX_LIFE)
	var life = max_life
	if random_delay:
		var drift = randf_range(0.0, 1.0)
		start_x -= vel.x * drift
		start_y -= vel.y * drift
		life = max_life * randf_range(0.3, 1.0)
	return {
		"pos": Vector2(start_x, start_y),
		"vel": vel,
		"tail_len": randf_range(COMET_MIN_TAIL, COMET_MAX_TAIL),
		"size": randf_range(2, 4),
		"color_index": randi() % 3,
		"life": life,
		"max_life": max_life,
	}

func _init_floating_runes(count: int) -> void:
	runes_floating.clear()
	var viewport_size = get_viewport_rect().size
	for i in range(count):
		runes_floating.append({
			"rune": OGHAM_RUNES[randi() % OGHAM_RUNES.size()],
			"pos": Vector2(randf() * viewport_size.x, randf() * viewport_size.y),
			"vel": Vector2(randf_range(-10, 10), randf_range(-15, -5)),
			"rotation": randf() * TAU,
			"rot_speed": randf_range(-0.5, 0.5),
			"alpha": randf_range(0.1, 0.4),
			"size": randf_range(16, 32),
			"pulse_offset": randf() * TAU,
		})

func _play_intro_animation() -> void:
	if intro_played:
		return
	intro_played = true
	
	# Ã‰tat initial
	black_overlay.modulate.a = 1.0
	gameboy_frame.scale = Vector2(0.1, 0.1)
	gameboy_frame.pivot_offset = gameboy_frame.size / 2
	gameboy_frame.modulate.a = 1.0
	
	# Cacher les Ã©lÃ©ments
	title_label.modulate.a = 0
	subtitle_label.modulate.a = 0
	vbox.modulate.a = 0
	
	title_label.scale = Vector2(0.5, 0.5)
	title_label.pivot_offset = title_label.size / 2
	
	# Animation sÃ©quencÃ©e
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Phase 1: Zoom du cadre Game Boy (0.8s)
	tween.tween_property(gameboy_frame, "scale", Vector2.ONE, 0.8)
	tween.parallel().tween_property(gameboy_frame, "modulate:a", 0.0, 0.8).set_delay(0.3)
	
	# Phase 2: Fade du noir (0.5s)
	tween.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
	
	# Phase 3: Apparition du titre avec bounce
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
	tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.8)
	
	# Phase 4: Sous-titre
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.4)
	
	# Phase 5: Boutons un par un
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.3)
	
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.modulate.a = 0
		btn.position.x = -50
		tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(0.05)
		tween.parallel().tween_property(btn, "position:x", 0.0, 0.3)

func _on_button_hover(btn: Button) -> void:
	hovered_button = btn
	
	# Animation de scale
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	btn.pivot_offset = btn.size / 2
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.3)
	
	# Spawn particules autour du bouton
	_spawn_hover_particles(btn)

func _on_button_unhover(btn: Button) -> void:
	if hovered_button == btn:
		hovered_button = null
	
	# Retour Ã  l'Ã©chelle normale
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.2)

func _on_button_pressed(btn: Button) -> void:
	match btn.name:
		"BtnTestTaniere":
			_go_to_scene(TEST_TANIERE_SCENE)
		"BtnTest":
			_go_to_scene(TEST_MERLIN_SCENE)
		"BtnQuitter":
			get_tree().quit()
		_:
			print("Button pressed: ", btn.name)

func _go_to_scene(scene_path: String) -> void:
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_warning("Scene missing: " + scene_path)

func _spawn_hover_particles(btn: Button) -> void:
	var btn_center = btn.global_position + btn.size / 2
	for i in range(5):
		var angle = randf() * TAU
		var dist = randf_range(30, 60)
		magic_particles.append({
			"pos": btn_center + Vector2(cos(angle), sin(angle)) * dist,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(20, 50),
			"size": randf_range(3, 8),
			"alpha": 1.0,
			"color_index": 0,  # Gold pour hover
			"pulse_offset": randf() * TAU,
			"life": 1.5,
		})

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Mettre Ã  jour particules
	_update_comets(delta)
	_update_particles(delta)
	_update_runes(delta)
	_update_cursor(delta)
	
	# Update day orb position
	day_orb_fraction = _get_day_fraction()
	
	# Animer le titre
	_animate_title(delta)
	
	# Forcer le redraw
	queue_redraw()
	if cursor_sprite:
		cursor_sprite.queue_redraw()

func _update_particles(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	var to_remove: Array[int] = []
	
	for i in range(magic_particles.size()):
		var p = magic_particles[i]
		
		# Mouvement
		p.pos += p.vel * delta
		p.vel.y -= 10 * delta  # GravitÃ© inversÃ©e (monte)
		p.life -= delta
		
		# Pulse
		p.alpha = p.alpha * (0.95 + 0.05 * sin(time_elapsed * 3 + p.pulse_offset))
		
		# Recyclage ou suppression
		if p.life <= 0 or p.pos.y < -50:
			if magic_particles.size() < 60:  # Recycler
				p.pos = Vector2(randf() * viewport_size.x, viewport_size.y + 20)
				p.vel = Vector2(randf_range(-20, 20), randf_range(-30, -10))
				p.life = randf_range(3, 6)
				p.alpha = randf_range(0.3, 0.8)
			else:
				to_remove.append(i)
	
	# Supprimer les particules mortes
	for i in range(to_remove.size() - 1, -1, -1):
		magic_particles.remove_at(to_remove[i])

func _update_comets(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(magic_comets.size()):
		var comet = magic_comets[i]
		comet.pos += comet.vel * delta
		comet.life -= delta
		if comet.life <= 0.0 or comet.pos.x > viewport_size.x + 160 or comet.pos.y > viewport_size.y + 160:
			magic_comets[i] = _spawn_comet(viewport_size, true)

func _update_runes(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	
	for rune in runes_floating:
		rune.pos += rune.vel * delta
		rune.rotation += rune.rot_speed * delta
		rune.alpha = 0.1 + 0.15 * sin(time_elapsed * 0.5 + rune.pulse_offset)
		
		# Recycler
		if rune.pos.y < -50:
			rune.pos.y = viewport_size.y + 50
			rune.pos.x = randf() * viewport_size.x
			rune.rune = OGHAM_RUNES[randi() % OGHAM_RUNES.size()]

func _update_cursor(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	cursor_sprite.global_position = mouse_pos - Vector2(8, 8)
	
	# Trail du curseur
	cursor_trail.append({
		"pos": mouse_pos,
		"alpha": 0.8,
		"size": 6,
	})
	
	# Mettre Ã  jour le trail
	var to_remove: Array[int] = []
	for i in range(cursor_trail.size()):
		cursor_trail[i].alpha -= delta * 3
		cursor_trail[i].size -= delta * 8
		if cursor_trail[i].alpha <= 0:
			to_remove.append(i)
	
	for i in range(to_remove.size() - 1, -1, -1):
		cursor_trail.remove_at(to_remove[i])
	
	# Limiter la taille du trail
	while cursor_trail.size() > 15:
		cursor_trail.pop_front()

func _animate_title(delta: float) -> void:
	if not title_label:
		return
	
	# LÃ©gÃ¨re pulsation du titre
	var pulse = 1.0 + 0.02 * sin(time_elapsed * 2)
	title_label.scale = Vector2(pulse, pulse)
	
	# Variation de couleur subtile
	var gold_variation = COLORS.gold.lerp(COLORS.gold_bright, 0.5 + 0.5 * sin(time_elapsed * 1.5))
	title_label.add_theme_color_override("font_color", gold_variation)

func _draw() -> void:
	# Dessiner le fond gradient
	_draw_background()
	_draw_day_orb()
	_draw_comets()
	
	# Dessiner les particules magiques
	_draw_particles()
	
	# Dessiner les runes flottantes
	_draw_runes()
	
	# Dessiner le curseur personnalisÃ©
	
	# Effet de vignette
	_draw_vignette()

func _get_day_fraction() -> float:
	var hour_value: float
	if day_orb_use_system_time:
		var now = Time.get_datetime_dict_from_system()
		hour_value = float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
	else:
		hour_value = day_orb_hour_override
	hour_value = fposmod(hour_value, 24.0)
	return hour_value / 24.0

func _get_orb_color_for_hour(hour: float) -> Color:
	# Time-based color gradient for the orb
	# 0h: gray-blue (midnight)
	# 2h: blue (blue hour)
	# 6h: white-gray (dawn)
	# 12h: bright white (noon)
	# 18h: black (dusk)
	# 22h: dark blue-gray (night)
	hour = fposmod(hour, 24.0)

	if hour < 2.0:
		# 0h -> 2h: midnight gray-blue to blue
		var t = hour / 2.0
		return DAY_ORB_COLORS.midnight.lerp(DAY_ORB_COLORS.blue_hour, t)
	elif hour < 6.0:
		# 2h -> 6h: blue to white-gray (dawn)
		var t = (hour - 2.0) / 4.0
		return DAY_ORB_COLORS.blue_hour.lerp(DAY_ORB_COLORS.dawn, t)
	elif hour < 12.0:
		# 6h -> 12h: white-gray to bright white (noon)
		var t = (hour - 6.0) / 6.0
		return DAY_ORB_COLORS.dawn.lerp(DAY_ORB_COLORS.noon, t)
	elif hour < 18.0:
		# 12h -> 18h: bright white to black (dusk)
		var t = (hour - 12.0) / 6.0
		return DAY_ORB_COLORS.noon.lerp(DAY_ORB_COLORS.dusk, t)
	elif hour < 22.0:
		# 18h -> 22h: black to dark blue-gray (night)
		var t = (hour - 18.0) / 4.0
		return DAY_ORB_COLORS.dusk.lerp(DAY_ORB_COLORS.night, t)
	else:
		# 22h -> 24h: dark blue-gray to midnight gray-blue
		var t = (hour - 22.0) / 2.0
		return DAY_ORB_COLORS.night.lerp(DAY_ORB_COLORS.midnight, t)

func _get_orb_glow_intensity(hour: float) -> float:
	# Glow intensity based on time - brighter during day, dimmer at night
	hour = fposmod(hour, 24.0)
	if hour < 6.0:
		# Night to dawn: low to medium
		return lerp(0.3, 0.6, hour / 6.0)
	elif hour < 12.0:
		# Dawn to noon: medium to high
		return lerp(0.6, 1.0, (hour - 6.0) / 6.0)
	elif hour < 18.0:
		# Noon to dusk: high to low
		return lerp(1.0, 0.15, (hour - 12.0) / 6.0)
	else:
		# Dusk to night: very low to low
		return lerp(0.15, 0.3, (hour - 18.0) / 6.0)

func _draw_day_orb() -> void:
	var viewport_size = get_viewport_rect().size
	# Use width-based radius to span full screen width
	var radius = viewport_size.x * day_arc_radius_ratio
	var center = Vector2(viewport_size.x * day_arc_center_ratio.x, viewport_size.y * day_arc_center_ratio.y)

	# Get current hour for color calculations
	var current_hour: float
	if day_orb_use_system_time:
		var now = Time.get_datetime_dict_from_system()
		current_hour = float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0
	else:
		current_hour = day_orb_hour_override

	# Get time-based orb color and glow intensity
	var orb_base_color = _get_orb_color_for_hour(current_hour)
	var glow_intensity = _get_orb_glow_intensity(current_hour)

	# Simple arc line spanning full width at top (curves downward into screen)
	var arc_color = Color(0.5, 0.55, 0.65, 0.5)
	var segments = 96
	var arc_points := PackedVector2Array()
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var ang = lerp(PI, 0.0, t)
		var dir = Vector2(cos(ang), sin(ang))  # sin(ang) curves DOWN
		arc_points.append(center + dir * radius)
	draw_polyline(arc_points, arc_color, day_arc_width, true)

	# Hour tick marks
	if day_arc_tick_count > 0:
		var tick_color = arc_color
		tick_color.a = 0.3
		var denom = max(1.0, float(day_arc_tick_count - 1))
		for i in range(day_arc_tick_count):
			var t_tick = float(i) / denom
			var ang_tick = lerp(PI, 0.0, t_tick)
			var dir_tick = Vector2(cos(ang_tick), sin(ang_tick))  # sin curves DOWN
			var inner = center + dir_tick * (radius - day_arc_tick_length)
			var outer = center + dir_tick * (radius + day_arc_tick_length)
			# Longer ticks every 6 hours
			var tick_mult = 1.5 if (i % 6 == 0) else 1.0
			draw_line(inner, outer + dir_tick * day_arc_tick_length * (tick_mult - 1.0), tick_color, 1.0 if tick_mult == 1.0 else 1.5, true)

	# Luminous orb positioned by time of day
	var orb_angle = lerp(PI, 0.0, day_orb_fraction)
	var orb_dir = Vector2(cos(orb_angle), sin(orb_angle))  # sin curves DOWN
	var orb_pos = center + orb_dir * radius

	var pulse = 0.85 + 0.15 * sin(time_elapsed * 2.5)
	var orb_r = day_orb_radius * pulse

	# Outer glow - color tinted, intensity based on time
	var glow_outer = orb_base_color
	glow_outer.a = 0.15 * glow_intensity
	draw_circle(orb_pos, orb_r * day_orb_glow_scale * 1.5, glow_outer)

	# Middle glow - slightly brighter
	var glow_mid = orb_base_color
	glow_mid.a = 0.35 * glow_intensity
	draw_circle(orb_pos, orb_r * day_orb_glow_scale, glow_mid)

	# Inner glow
	var glow_inner = orb_base_color
	glow_inner = glow_inner.lerp(Color.WHITE, 0.3)
	glow_inner.a = 0.5 * glow_intensity
	draw_circle(orb_pos, orb_r * 1.8, glow_inner)

	# Main orb body
	var orb_color = orb_base_color
	orb_color.a = 0.95
	draw_circle(orb_pos, orb_r, orb_color)

	# Highlight (only visible when orb is bright enough)
	if glow_intensity > 0.3:
		var highlight = Color.WHITE
		highlight.a = 0.6 * glow_intensity
		draw_circle(orb_pos - Vector2(orb_r * 0.25, orb_r * 0.25), orb_r * 0.35, highlight)

func _draw_background() -> void:
	var viewport_size = get_viewport_rect().size
	
	# DÃ©gradÃ© de fond
	var gradient_steps = 20
	for i in range(gradient_steps):
		var t = float(i) / gradient_steps
		var color = COLORS.bg_gradient_top.lerp(COLORS.bg_gradient_bottom, t)
		var rect_y = viewport_size.y * t
		var rect_h = viewport_size.y / gradient_steps + 1
		draw_rect(Rect2(0, rect_y, viewport_size.x, rect_h), color)
	
	# Motif de dither GBC
	var dither_color = Color(0.05, 0.1, 0.08, 0.3)
	for y in range(0, int(viewport_size.y), 4):
		for x in range(0, int(viewport_size.x), 4):
			if int(x / 4.0 + y / 4.0) % 2 == 0:
				draw_rect(Rect2(x, y, 2, 2), dither_color)

func _draw_comets() -> void:
	for comet in magic_comets:
		var base_color: Color
		match comet.color_index:
			0: base_color = COLORS.gold_bright
			1: base_color = COLORS.blue_rune
			2: base_color = COLORS.purple_magic
			_: base_color = COLORS.gold_bright
		
		var fade = clamp(comet.life / comet.max_life, 0.0, 1.0)
		var color = base_color
		color.a = 0.6 * fade
		
		var dir = comet.vel.normalized()
		var head = comet.pos
		var tail = comet.pos - dir * comet.tail_len
		
		for i in range(3):
			var t = float(i) / 3.0
			var seg_start = head.lerp(tail, t)
			var seg_end = head.lerp(tail, min(t + 0.35, 1.0))
			var seg_color = color
			seg_color.a = color.a * (1.0 - t)
			draw_line(seg_start, seg_end, seg_color, maxf(1.0, comet.size - i))
		
		var head_color = base_color
		head_color.a = min(1.0, 0.8 * fade + 0.2)
		draw_circle(head, comet.size * 1.4, head_color)
		var core = Color.WHITE
		core.a = min(1.0, fade)
		draw_circle(head, comet.size * 0.6, core)

func _draw_particles() -> void:
	for p in magic_particles:
		var color: Color
		match p.color_index:
			0: color = COLORS.gold
			1: color = COLORS.green_mystic
			2: color = COLORS.blue_rune
			_: color = COLORS.gold
		
		color.a = p.alpha
		
		# Glow effect
		var glow_color = color
		glow_color.a = p.alpha * 0.3
		draw_circle(p.pos, p.size * 2, glow_color)
		
		# Core
		draw_circle(p.pos, p.size, color)
		
		# Highlight
		var highlight = Color.WHITE
		highlight.a = p.alpha * 0.5
		draw_circle(p.pos - Vector2(p.size * 0.3, p.size * 0.3), p.size * 0.3, highlight)

func _draw_runes() -> void:
	for rune in runes_floating:
		var color = COLORS.gold
		color.a = rune.alpha
		
		# Dessiner la rune avec transformation
		draw_set_transform(rune.pos, rune.rotation, Vector2.ONE)
		
		# Glow
		var glow = color
		glow.a = rune.alpha * 0.5
		
		# Note: Pour un vrai rendu de texte, il faudrait utiliser draw_string
		# Ici on fait un cercle stylisÃ© comme placeholder
		draw_circle(Vector2.ZERO, rune.size * 0.4, glow)
		draw_circle(Vector2.ZERO, rune.size * 0.2, color)
		
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_cursor() -> void:
	_draw_cursor_layer(self)

func _draw_cursor_layer(canvas: Control) -> void:
	# Trail
	for trail in cursor_trail:
		var color = COLORS.gold
		color.a = trail.alpha * 0.5
		canvas.draw_circle(trail.pos, trail.size, color)
	
	# Celtic cursor
	var mouse_pos = get_global_mouse_position()
	var pulse = 1.0 + 0.18 * sin(time_elapsed * 5)
	var highlight = hovered_button != null
	var size = 10.0 * pulse * (1.2 if highlight else 1.0)
	var cursor_color = COLORS.gold_bright if highlight else COLORS.gold
	var accent_color = COLORS.green_bright if highlight else COLORS.gold_bright
	
	# Glow
	var glow = cursor_color
	glow.a = 0.35
	canvas.draw_circle(mouse_pos, size * 1.6, glow)
	
	# Outer ring
	canvas.draw_arc(mouse_pos, size * 1.2, 0.0, TAU, 32, cursor_color, 2.0)
	
	# Celtic knot arcs
	for i in range(3):
		var ang = (TAU / 3.0) * i + time_elapsed * 0.6
		var arc_center = mouse_pos + Vector2(cos(ang), sin(ang)) * size * 0.45
		canvas.draw_arc(arc_center, size * 0.55, ang + 0.7, ang + TAU - 0.7, 18, accent_color, 2.0)
	
	# Center dot
	canvas.draw_circle(mouse_pos, 2.5, Color.WHITE)

func _draw_vignette() -> void:
	var viewport_size = get_viewport_rect().size
	var center = viewport_size / 2
	var max_dist = center.length()
	
	# Dessiner la vignette en cercles concentriques
	var steps = 10
	for i in range(steps):
		var t = float(i) / steps
		var radius = max_dist * (1.0 - t * 0.5)
		var alpha = t * t * 0.4  # Quadratique pour un effet doux
		var color = Color(0, 0, 0, alpha)
		
		# Approximation par rectangle (plus rapide que des cercles)
		var margin = viewport_size * t * 0.3
		var rect = Rect2(
			-margin.x, -margin.y,
			viewport_size.x + margin.x * 2,
			margin.y
		)
		draw_rect(rect, color)
		
		rect = Rect2(
			-margin.x, viewport_size.y - margin.y,
			viewport_size.x + margin.x * 2,
			margin.y + margin.y
		)
		draw_rect(rect, color)

func _exit_tree() -> void:
	# Restaurer le curseur systÃ¨me
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
