extends Control
## ╔═══════════════════════════════════════════════════════════════════╗
## ║  DRU: Le Jeu des Oghams — Menu Principal Celtique                 ║
## ║  Style GBC enrichi avec animations mystiques                       ║
## ╚═══════════════════════════════════════════════════════════════════╝

# ═══════════════════════════════════════════════════════════════════
# SIGNAUX
# ═══════════════════════════════════════════════════════════════════
signal nouvelle_partie_pressed
signal continuer_pressed
signal options_pressed
signal test_merlin_pressed
signal quitter_pressed

# ═══════════════════════════════════════════════════════════════════
# RÉFÉRENCES AUX NŒUDS
# ═══════════════════════════════════════════════════════════════════
@onready var title_label: Label = $TitleContainer/TitleLabel
@onready var subtitle_label: Label = $TitleContainer/SubtitleLabel
@onready var separator_label: Label = $TitleContainer/Separator if has_node("TitleContainer/Separator") else null
@onready var buttons_container: VBoxContainer = $ButtonsContainer
@onready var background: ColorRect = $Background
@onready var vignette: ColorRect = $Vignette if has_node("Vignette") else null
@onready var runes_container: Control = $RunesContainer if has_node("RunesContainer") else null
@onready var deco_left: Label = $DecoLeft if has_node("DecoLeft") else null
@onready var deco_right: Label = $DecoRight if has_node("DecoRight") else null
@onready var version_label: Label = $VersionLabel if has_node("VersionLabel") else null

# ═══════════════════════════════════════════════════════════════════
# VARIABLES D'ANIMATION
# ═══════════════════════════════════════════════════════════════════
var time_elapsed: float = 0.0
var title_base_pos: Vector2 = Vector2.ZERO
var selected_button_index: int = 0
var buttons: Array[Button] = []
var floating_runes: Array[Label] = []
var magic_particles: Array[Dictionary] = []

# ═══════════════════════════════════════════════════════════════════
# CONSTANTES VISUELLES CELTIQUES
# ═══════════════════════════════════════════════════════════════════
const COLORS = {
	# Fond mystique
	"bg_deep": Color(0.03, 0.05, 0.08, 1.0),
	"bg_mid": Color(0.06, 0.10, 0.15, 1.0),
	"bg_accent": Color(0.08, 0.15, 0.22, 1.0),
	
	# Or celtique
	"gold_bright": Color(1.0, 0.85, 0.40, 1.0),
	"gold": Color(0.85, 0.68, 0.28, 1.0),
	"gold_dark": Color(0.65, 0.50, 0.20, 1.0),
	
	# Nature druidique
	"green_bright": Color(0.35, 0.75, 0.45, 1.0),
	"green": Color(0.20, 0.55, 0.35, 1.0),
	"green_dark": Color(0.12, 0.35, 0.22, 1.0),
	
	# Mysticisme
	"mystic_blue": Color(0.30, 0.50, 0.75, 1.0),
	"mystic_purple": Color(0.45, 0.30, 0.65, 1.0),
	
	# Textes
	"cream": Color(0.96, 0.93, 0.87, 1.0),
	"cream_dim": Color(0.80, 0.77, 0.72, 0.7),
	"shadow": Color(0.0, 0.0, 0.0, 0.8),
}

# Symboles Oghams authentiques
const OGHAM_SYMBOLS = [
	"᚛", "᚜",  # Marques de début/fin
	"ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ",  # Aicme Beithe (B, L, F, S, N)
	"ᚆ", "ᚇ", "ᚈ", "ᚉ", "ᚊ",  # Aicme hÚatha (H, D, T, C, Q)
	"ᚋ", "ᚌ", "ᚍ", "ᚎ", "ᚏ",  # Aicme Muine (M, G, NG, STR, R)
	"ᚐ", "ᚑ", "ᚒ", "ᚓ", "ᚔ",  # Aicme Ailme (A, O, U, E, I)
]

# Icônes celtiques pour les boutons
const CELTIC_ICONS = {
	"nouvelle": "🌿",
	"continuer": "📜",
	"options": "⚙️",
	"test": "🧙",
	"quitter": "🚪",
}

# ═══════════════════════════════════════════════════════════════════
# INITIALISATION
# ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Configuration initiale
	_setup_scene()
	_setup_background_effects()
	_setup_title()
	_setup_buttons()
	_create_floating_runes()
	_create_magic_particles()
	_animate_deco_runes()
	
	# Animation d'entrée
	_play_intro_animation()
	
	# Focus initial
	if buttons.size() > 0:
		buttons[0].grab_focus()

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Animations continues
	_animate_title(delta)
	_animate_background(delta)
	_animate_buttons(delta)
	_animate_floating_runes(delta)
	_animate_magic_particles(delta)
	_animate_separator(delta)

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION DE LA SCÈNE
# ═══════════════════════════════════════════════════════════════════

func _setup_scene() -> void:
	# S'assurer que la scène prend tout l'écran
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Désactiver le filtre souris pour les éléments décoratifs
	if runes_container:
		runes_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vignette:
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_background_effects() -> void:
	if background:
		background.color = COLORS.bg_deep
	
	# Ajouter un gradient overlay si pas présent
	var gradient_overlay = get_node_or_null("GradientOverlay")
	if gradient_overlay:
		gradient_overlay.color = Color(COLORS.mystic_blue.r, COLORS.mystic_blue.g, COLORS.mystic_blue.b, 0.15)

func _setup_title() -> void:
	if title_label:
		title_base_pos = title_label.position
		
		# Couleur dorée avec ombre portée
		title_label.add_theme_color_override("font_color", COLORS.gold_bright)
		title_label.add_theme_color_override("font_shadow_color", COLORS.shadow)
		title_label.add_theme_constant_override("shadow_offset_x", 5)
		title_label.add_theme_constant_override("shadow_offset_y", 5)
		
		# Opacité initiale pour l'animation
		title_label.modulate.a = 0.0
	
	if subtitle_label:
		subtitle_label.add_theme_color_override("font_color", COLORS.cream)
		subtitle_label.modulate.a = 0.0
	
	if separator_label:
		separator_label.add_theme_color_override("font_color", COLORS.gold_dark)
		separator_label.modulate.a = 0.0

func _setup_buttons() -> void:
	if not buttons_container:
		return
	
	buttons.clear()
	
	for child in buttons_container.get_children():
		if child is Button:
			buttons.append(child)
			_style_celtic_button(child)
			
			# Connexions
			child.mouse_entered.connect(_on_button_hover.bind(child))
			child.mouse_exited.connect(_on_button_unhover.bind(child))
			child.pressed.connect(_on_button_pressed.bind(child))
			child.focus_entered.connect(_on_button_focus.bind(child))
			
			# État initial pour animation
			child.modulate.a = 0.0
			child.position.x += 80

func _style_celtic_button(btn: Button) -> void:
	# ═══════════════════════════════════════════════════════════════
	# Style Normal — Fond sombre avec bordure dorée
	# ═══════════════════════════════════════════════════════════════
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style_normal.border_color = COLORS.gold_dark
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(6)
	style_normal.content_margin_left = 20
	style_normal.content_margin_right = 20
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	style_normal.shadow_color = Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 4
	style_normal.shadow_offset = Vector2(3, 3)
	
	# ═══════════════════════════════════════════════════════════════
	# Style Hover — Lueur dorée mystique
	# ═══════════════════════════════════════════════════════════════
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.12, 0.18, 0.25, 0.98)
	style_hover.border_color = COLORS.gold_bright
	style_hover.set_border_width_all(4)
	style_hover.set_corner_radius_all(6)
	style_hover.content_margin_left = 20
	style_hover.content_margin_right = 20
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	style_hover.shadow_color = Color(COLORS.gold.r, COLORS.gold.g, COLORS.gold.b, 0.4)
	style_hover.shadow_size = 12
	style_hover.shadow_offset = Vector2(0, 0)
	
	# ═══════════════════════════════════════════════════════════════
	# Style Pressed — Vert druidique
	# ═══════════════════════════════════════════════════════════════
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.06, 0.10, 0.14, 1.0)
	style_pressed.border_color = COLORS.green_bright
	style_pressed.set_border_width_all(4)
	style_pressed.set_corner_radius_all(6)
	style_pressed.content_margin_left = 20
	style_pressed.content_margin_right = 20
	style_pressed.content_margin_top = 12
	style_pressed.content_margin_bottom = 12
	
	# ═══════════════════════════════════════════════════════════════
	# Style Focus — Identique à hover pour le clavier
	# ═══════════════════════════════════════════════════════════════
	var style_focus = style_hover.duplicate()
	style_focus.border_color = COLORS.mystic_blue
	
	# Appliquer les styles
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_focus)
	
	# Couleurs du texte
	btn.add_theme_color_override("font_color", COLORS.cream)
	btn.add_theme_color_override("font_hover_color", COLORS.gold_bright)
	btn.add_theme_color_override("font_pressed_color", COLORS.green_bright)
	btn.add_theme_color_override("font_focus_color", COLORS.gold)

# ═══════════════════════════════════════════════════════════════════
# CRÉATION DES ÉLÉMENTS DÉCORATIFS
# ═══════════════════════════════════════════════════════════════════

func _create_floating_runes() -> void:
	if not runes_container:
		return
	
	# Nettoyer les anciennes runes
	for child in runes_container.get_children():
		child.queue_free()
	floating_runes.clear()
	
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		viewport_size = Vector2(1280, 720)  # Fallback
	
	# Créer des runes flottantes
	for i in range(15):
		var rune = Label.new()
		rune.name = "FloatingRune_%d" % i
		rune.text = OGHAM_SYMBOLS[randi() % OGHAM_SYMBOLS.size()]
		rune.add_theme_font_size_override("font_size", randi_range(20, 40))
		
		# Position aléatoire sur les côtés
		var side = randi() % 4
		match side:
			0:  # Gauche
				rune.position = Vector2(randf_range(20, 100), randf_range(100, viewport_size.y - 100))
			1:  # Droite
				rune.position = Vector2(randf_range(viewport_size.x - 100, viewport_size.x - 20), randf_range(100, viewport_size.y - 100))
			2:  # Haut
				rune.position = Vector2(randf_range(100, viewport_size.x - 100), randf_range(20, 80))
			3:  # Bas
				rune.position = Vector2(randf_range(100, viewport_size.x - 100), randf_range(viewport_size.y - 80, viewport_size.y - 20))
		
		# Métadonnées pour l'animation
		rune.set_meta("base_pos", rune.position)
		rune.set_meta("float_speed", randf_range(0.4, 1.0))
		rune.set_meta("float_offset", randf_range(0, TAU))
		rune.set_meta("float_amplitude", randf_range(10, 25))
		rune.set_meta("rotation_speed", randf_range(-0.3, 0.3))
		rune.set_meta("base_alpha", randf_range(0.08, 0.20))
		
		# Couleur dorée transparente
		var alpha = rune.get_meta("base_alpha")
		rune.add_theme_color_override("font_color", Color(COLORS.gold.r, COLORS.gold.g, COLORS.gold.b, alpha))
		rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		runes_container.add_child(rune)
		floating_runes.append(rune)

func _create_magic_particles() -> void:
	# Créer des particules magiques simulées
	magic_particles.clear()
	
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		viewport_size = Vector2(1280, 720)
	
	for i in range(30):
		magic_particles.append({
			"pos": Vector2(randf() * viewport_size.x, randf() * viewport_size.y),
			"vel": Vector2(randf_range(-20, 20), randf_range(-30, -10)),
			"life": randf(),
			"max_life": randf_range(2.0, 5.0),
			"size": randf_range(2, 6),
			"color": COLORS.gold if randf() > 0.3 else COLORS.green,
		})

func _animate_deco_runes() -> void:
	# Animation des runes décoratives sur les côtés
	if deco_left:
		deco_left.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(deco_left, "modulate:a", 0.15, 2.0).set_delay(1.5)
	
	if deco_right:
		deco_right.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(deco_right, "modulate:a", 0.15, 2.0).set_delay(1.7)

# ═══════════════════════════════════════════════════════════════════
# ANIMATIONS
# ═══════════════════════════════════════════════════════════════════

func _play_intro_animation() -> void:
	# ═══════════════════════════════════════════════════════════════
	# Animation du titre — Apparition mystique
	# ═══════════════════════════════════════════════════════════════
	if title_label:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(title_label, "modulate:a", 1.0, 1.2)
	
	# ═══════════════════════════════════════════════════════════════
	# Animation du sous-titre — Apparition décalée
	# ═══════════════════════════════════════════════════════════════
	if subtitle_label:
		var tween = create_tween()
		tween.tween_property(subtitle_label, "modulate:a", 0.85, 1.0).set_delay(0.4)
	
	# ═══════════════════════════════════════════════════════════════
	# Animation du séparateur — Expansion
	# ═══════════════════════════════════════════════════════════════
	if separator_label:
		var tween = create_tween()
		tween.tween_property(separator_label, "modulate:a", 0.5, 0.8).set_delay(0.7)
	
	# ═══════════════════════════════════════════════════════════════
	# Animation des boutons — Cascade depuis la droite
	# ═══════════════════════════════════════════════════════════════
	for i in range(buttons.size()):
		var btn = buttons[i]
		var original_x = btn.position.x - 80  # Récupérer la position originale
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		
		var delay = 0.6 + i * 0.12
		tween.tween_property(btn, "modulate:a", 1.0, 0.5).set_delay(delay)
		tween.tween_property(btn, "position:x", original_x, 0.6).set_delay(delay)
	
	# ═══════════════════════════════════════════════════════════════
	# Animation du label de version
	# ═══════════════════════════════════════════════════════════════
	if version_label:
		version_label.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(version_label, "modulate:a", 0.5, 1.0).set_delay(1.5)

func _animate_title(delta: float) -> void:
	if not title_label:
		return
	
	# Flottement sinusoïdal doux
	var float_offset = sin(time_elapsed * 1.2) * 6
	title_label.position.y = title_base_pos.y + float_offset
	
	# Pulsation lumineuse subtile
	var pulse = 0.92 + sin(time_elapsed * 2.5) * 0.08
	var current_color = COLORS.gold_bright
	title_label.add_theme_color_override("font_color", Color(
		current_color.r * pulse,
		current_color.g * pulse,
		current_color.b * pulse,
		1.0
	))

func _animate_separator(delta: float) -> void:
	if not separator_label:
		return
	
	# Pulsation de l'opacité du séparateur
	var pulse = 0.3 + sin(time_elapsed * 1.5) * 0.2
	separator_label.modulate.a = pulse

func _animate_background(delta: float) -> void:
	if not background:
		return
	
	# Variation subtile de la couleur de fond
	var shift = sin(time_elapsed * 0.3) * 0.015
	background.color = Color(
		COLORS.bg_deep.r + shift,
		COLORS.bg_deep.g + shift * 1.5,
		COLORS.bg_deep.b + shift * 2.5,
		1.0
	)

func _animate_buttons(delta: float) -> void:
	for i in range(buttons.size()):
		var btn = buttons[i]
		
		# Animation de survol avec pulsation
		if btn.is_hovered() or btn.has_focus():
			var pulse = 1.0 + sin(time_elapsed * 5.0 + i * 0.5) * 0.02
			btn.scale = Vector2(pulse, pulse)
		else:
			# Retour doux à l'échelle normale
			btn.scale = btn.scale.lerp(Vector2.ONE, delta * 8.0)

func _animate_floating_runes(delta: float) -> void:
	for rune in floating_runes:
		if not is_instance_valid(rune):
			continue
		
		var base_pos: Vector2 = rune.get_meta("base_pos", rune.position)
		var speed: float = rune.get_meta("float_speed", 0.5)
		var offset: float = rune.get_meta("float_offset", 0.0)
		var amplitude: float = rune.get_meta("float_amplitude", 15.0)
		var rot_speed: float = rune.get_meta("rotation_speed", 0.1)
		var base_alpha: float = rune.get_meta("base_alpha", 0.15)
		
		# Mouvement flottant
		rune.position.x = base_pos.x + sin(time_elapsed * speed + offset) * amplitude * 0.5
		rune.position.y = base_pos.y + sin(time_elapsed * speed * 0.7 + offset) * amplitude
		
		# Rotation douce
		rune.rotation = sin(time_elapsed * rot_speed + offset) * 0.15
		
		# Pulsation d'opacité
		var alpha_pulse = base_alpha + sin(time_elapsed * speed * 1.5 + offset) * (base_alpha * 0.5)
		rune.modulate.a = alpha_pulse

func _animate_magic_particles(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0:
		return
	
	for particle in magic_particles:
		# Mise à jour de la vie
		particle.life += delta / particle.max_life
		
		# Reset si mort
		if particle.life >= 1.0:
			particle.life = 0.0
			particle.pos = Vector2(randf() * viewport_size.x, viewport_size.y + 10)
			particle.vel = Vector2(randf_range(-20, 20), randf_range(-40, -20))
		
		# Mise à jour de la position
		particle.pos += particle.vel * delta
		particle.vel.y -= 5 * delta  # Légère ascension

# ═══════════════════════════════════════════════════════════════════
# GESTION DES ÉVÉNEMENTS
# ═══════════════════════════════════════════════════════════════════

func _on_button_hover(btn: Button) -> void:
	# Animation d'agrandissement
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.2)
	
	# Mise à jour de l'index sélectionné
	selected_button_index = buttons.find(btn)

func _on_button_unhover(btn: Button) -> void:
	if not btn.has_focus():
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15)

func _on_button_focus(btn: Button) -> void:
	selected_button_index = buttons.find(btn)
	_on_button_hover(btn)

func _on_button_pressed(btn: Button) -> void:
	# Animation de pression
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Traitement selon le bouton
	await get_tree().create_timer(0.1).timeout
	
	match btn.name:
		"BtnNouvelle":
			emit_signal("nouvelle_partie_pressed")
			_transition_to("res://scenes/SelectionType.tscn")
		"BtnContinuer":
			emit_signal("continuer_pressed")
			_transition_to("res://scenes/SelectionSauvegarde.tscn")
		"BtnOptions":
			emit_signal("options_pressed")
			_show_options_menu()
		"BtnTest":
			emit_signal("test_merlin_pressed")
			_transition_to("res://scenes/TestMerlinGBA.tscn")
		"BtnQuitter":
			emit_signal("quitter_pressed")
			_quit_game()

# ═══════════════════════════════════════════════════════════════════
# TRANSITIONS
# ═══════════════════════════════════════════════════════════════════

func _transition_to(scene_path: String) -> void:
	# Vérifier l'existence de la scène
	if not ResourceLoader.exists(scene_path):
		push_warning("Scène introuvable: %s" % scene_path)
		_show_error("Scène en développement...")
		return
	
	# Animation de fondu
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))

func _show_options_menu() -> void:
	# TODO: Implémenter le menu d'options
	_show_error("Options à venir...")

func _show_error(message: String) -> void:
	# Afficher un message temporaire
	var error_label = Label.new()
	error_label.text = message
	error_label.add_theme_color_override("font_color", COLORS.gold)
	error_label.add_theme_font_size_override("font_size", 16)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.set_anchors_preset(Control.PRESET_CENTER)
	error_label.position.y += 50
	add_child(error_label)
	
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(error_label.queue_free)

func _quit_game() -> void:
	# Animation de fermeture
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().quit())

# ═══════════════════════════════════════════════════════════════════
# INPUT CLAVIER
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_navigate_buttons(-1)
			KEY_DOWN, KEY_S:
				_navigate_buttons(1)
			KEY_ENTER, KEY_SPACE:
				if buttons.size() > selected_button_index:
					_on_button_pressed(buttons[selected_button_index])
			KEY_ESCAPE:
				_quit_game()

func _navigate_buttons(direction: int) -> void:
	if buttons.is_empty():
		return
	
	# Retirer le focus de l'ancien bouton
	if selected_button_index < buttons.size():
		buttons[selected_button_index].release_focus()
	
	# Calculer le nouvel index
	selected_button_index = wrapi(selected_button_index + direction, 0, buttons.size())
	
	# Donner le focus au nouveau bouton
	buttons[selected_button_index].grab_focus()

# ═══════════════════════════════════════════════════════════════════
# DESSIN PERSONNALISÉ (Particules)
# ═══════════════════════════════════════════════════════════════════

func _draw() -> void:
	# Dessiner les particules magiques
	for particle in magic_particles:
		var alpha = 1.0 - particle.life
		alpha = alpha * alpha  # Ease out
		var color = Color(particle.color.r, particle.color.g, particle.color.b, alpha * 0.6)
		draw_circle(particle.pos, particle.size * (1.0 - particle.life * 0.5), color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		queue_redraw()
