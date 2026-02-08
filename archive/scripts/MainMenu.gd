extends Control
## MainMenu.gd - Menu principal DRU avec animations magiques et curseur celtique
## Version GBC pixel art style - v3.0 (Fixed z-ordering)

# =============================================================================
# CONSTANTES - Palette GBC stricte
# =============================================================================
const PALETTE = {
	"black": Color("#181810"),
	"dark_gray": Color("#484840"),
	"gray": Color("#787870"),
	"light_gray": Color("#b8b0a0"),
	"cream": Color("#f8f0d8"),
	"white": Color("#e8e8e8"),
	
	"grass_dark": Color("#1a2f18"),
	"grass": Color("#48a028"),
	"grass_light": Color("#88d850"),
	
	"mystic_dark": Color("#504078"),
	"mystic": Color("#8868b0"),
	"mystic_light": Color("#c0a0e0"),
	
	"fire": Color("#e07028"),
	"fire_light": Color("#f8a850"),
	
	"water": Color("#3888c8"),
	"water_light": Color("#78c8f0"),
	
	"thunder": Color("#e8c830"),
	"thunder_light": Color("#f8f080"),
	
	"earth": Color("#a08058"),
	"earth_dark": Color("#685030"),
	
	"shadow": Color("#0d0d15"),
	"shadow_light": Color("#1a1a2a"),
}

# =============================================================================
# VARIABLES
# =============================================================================
var particles: Array = []
var runes: Array = []
var standing_stones: Array = []
var stars: Array = []
var ogham_symbols: Array = ["ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ", "ᚈ", "ᚉ", "ᚊ", "ᚋ", "ᚌ", "ᚍ", "ᚎ", "ᚏ", "ᚐ", "ᚑ", "ᚒ", "ᚓ", "ᚔ"]
var time_elapsed: float = 0.0
var cursor_pos: Vector2 = Vector2(400, 300)
var cursor_trail: Array = []
var title_offset: float = 0.0
var is_ready: bool = false

# Nodes créés dynamiquement
var bg_gradient: Control
var stars_canvas: Control
var stone_canvas: Control
var particle_canvas: Control
var rune_canvas: Control
var fog_overlay: Control
var vignette_overlay: Control
var scanlines_overlay: Control
var cursor_canvas: Control

# Références
var title_label: Label
var all_buttons: Array = []
var center_container: Control

# =============================================================================
# LIFECYCLE
# =============================================================================
func _ready() -> void:
	print("[MainMenu] v3.0 Initializing magical background...")
	
	# Attendre un frame pour que tout soit prêt
	await get_tree().process_frame
	
	# Trouver et configurer le CenterContainer pour qu'il soit au-dessus
	center_container = get_node_or_null("CenterContainer")
	if center_container:
		center_container.z_index = 10
		print("[MainMenu] CenterContainer z_index set to 10")
	
	# Créer les layers d'animation (z_index bas pour être derrière l'UI)
	_setup_background_gradient()
	_setup_stars(100)
	_setup_standing_stones()
	_setup_layers()
	_init_particles(80)
	_init_runes(15)
	_setup_overlays()
	_setup_custom_cursor()
	
	# Récupérer les labels
	title_label = _find_node_recursive(self, "TitleLabel")
	if title_label:
		_style_title()
		print("[MainMenu] TitleLabel found and styled")
	
	# Connecter TOUS les boutons
	_connect_all_buttons()
	
	is_ready = true
	print("[MainMenu] Ready! Particles:", particles.size(), " Runes:", runes.size(), " Stars:", stars.size())

func _process(delta: float) -> void:
	if not is_ready:
		return
	
	time_elapsed += delta
	
	_update_particles(delta)
	_update_runes(delta)
	_update_title_animation(delta)
	
	# Forcer le redessin de tous les canvas
	if bg_gradient: bg_gradient.queue_redraw()
	if stars_canvas: stars_canvas.queue_redraw()
	if stone_canvas: stone_canvas.queue_redraw()
	if particle_canvas: particle_canvas.queue_redraw()
	if rune_canvas: rune_canvas.queue_redraw()
	if fog_overlay: fog_overlay.queue_redraw()
	if cursor_canvas: cursor_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_pos = event.position
		cursor_trail.push_front(cursor_pos)
		if cursor_trail.size() > 12:
			cursor_trail.pop_back()

# =============================================================================
# HELPER - Trouver un node récursivement
# =============================================================================
func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	return null

func _find_all_buttons(node: Node) -> Array:
	var buttons = []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	return buttons

# =============================================================================
# SETUP - Background Gradient (Ciel nocturne mystique)
# =============================================================================
func _setup_background_gradient() -> void:
	bg_gradient = Control.new()
	bg_gradient.name = "BGGradient"
	bg_gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_gradient.z_index = -100  # Tout au fond
	add_child(bg_gradient)
	move_child(bg_gradient, 0)
	bg_gradient.draw.connect(_draw_background)
	print("[MainMenu] BGGradient created with z_index -100")

func _draw_background() -> void:
	var screen_size = get_viewport_rect().size
	
	# Dégradé vertical: ciel nocturne mystique
	var bands = 30
	for i in range(bands):
		var ratio = float(i) / float(bands)
		var y_start = ratio * screen_size.y
		var y_height = screen_size.y / float(bands) + 1
		
		# Interpoler entre shadow (haut) et shadow_light (bas)
		var color = PALETTE.shadow.lerp(PALETTE.shadow_light, ratio * 0.7)
		# Ajouter une teinte mystique subtile animée
		var mystic_blend = 0.08 + sin(time_elapsed * 0.2 + ratio * 2) * 0.04
		color = color.lerp(PALETTE.mystic_dark, mystic_blend)
		
		bg_gradient.draw_rect(Rect2(0, y_start, screen_size.x, y_height), color)

# =============================================================================
# SETUP - Étoiles scintillantes
# =============================================================================
func _setup_stars(count: int) -> void:
	var screen_size = get_viewport_rect().size
	for i in range(count):
		stars.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y * 0.75),
			"size": randf_range(1, 4),
			"phase": randf() * TAU,
			"speed": randf_range(1.5, 5.0),
			"twinkle_type": randi() % 3  # 0: normal, 1: cross, 2: diamond
		})
	
	stars_canvas = Control.new()
	stars_canvas.name = "StarsCanvas"
	stars_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_canvas.z_index = -90
	add_child(stars_canvas)
	stars_canvas.draw.connect(_draw_stars)
	print("[MainMenu] StarsCanvas created with", count, "stars")

func _draw_stars() -> void:
	for star in stars:
		var twinkle = 0.2 + 0.8 * ((sin(time_elapsed * star.speed + star.phase) + 1) / 2)
		var color = PALETTE.cream
		color.a = twinkle * 0.9
		
		var size = star.size
		var pos = star.pos
		
		# Point central
		stars_canvas.draw_rect(
			Rect2(pos.x - size/2, pos.y - size/2, size, size),
			color
		)
		
		# Effets spéciaux pour grosses étoiles
		if star.size > 2.5:
			var cross_color = color
			cross_color.a *= 0.4
			
			if star.twinkle_type == 1:  # Croix
				stars_canvas.draw_rect(Rect2(pos.x - size*1.5, pos.y - 0.5, size * 3, 1), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x - 0.5, pos.y - size*1.5, 1, size * 3), cross_color)
			elif star.twinkle_type == 2:  # Diamant
				var d = size * 0.7
				stars_canvas.draw_rect(Rect2(pos.x - d, pos.y - 0.5, d*2, 1), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x - 0.5, pos.y - d, 1, d*2), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x - d*0.7, pos.y - d*0.7, 1, 1), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x + d*0.7, pos.y - d*0.7, 1, 1), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x - d*0.7, pos.y + d*0.7, 1, 1), cross_color)
				stars_canvas.draw_rect(Rect2(pos.x + d*0.7, pos.y + d*0.7, 1, 1), cross_color)

# =============================================================================
# SETUP - Menhirs (Standing Stones)
# =============================================================================
func _setup_standing_stones() -> void:
	var screen_size = get_viewport_rect().size
	standing_stones = [
		{"x": screen_size.x * 0.06, "height": 220, "width": 45, "rune_idx": 0},
		{"x": screen_size.x * 0.15, "height": 300, "width": 55, "rune_idx": 5},
		{"x": screen_size.x * 0.85, "height": 280, "width": 50, "rune_idx": 10},
		{"x": screen_size.x * 0.94, "height": 200, "width": 42, "rune_idx": 15},
	]

func _draw_stones() -> void:
	var screen_size = get_viewport_rect().size
	var ground_y = screen_size.y * 0.95
	
	for stone in standing_stones:
		var x = stone.x
		var h = stone.height
		var w = stone.width
		
		# Ombre du menhir
		var shadow_color = PALETTE.black
		shadow_color.a = 0.5
		stone_canvas.draw_rect(Rect2(x + 10, ground_y - 10, w + 20, 20), shadow_color)
		
		# Corps du menhir (segments pixelisés)
		var segments = int(h / 5)
		for i in range(segments):
			var y = ground_y - h + i * 5
			var shade = lerp(0.25, 0.55, float(i) / float(segments))
			var color = PALETTE.gray.darkened(1.0 - shade)
			
			# Rétrécissement vers le haut
			var taper = 1.0 - (float(i) / float(segments)) * 0.4
			var current_w = w * taper
			
			# Variations pour effet pierre naturelle
			var offset_x = sin(float(i) * 0.5 + stone.x * 0.01) * 3
			stone_canvas.draw_rect(Rect2(x - current_w/2 + offset_x, y, current_w, 5), color)
		
		# Sommet arrondi
		var top_y = ground_y - h
		var top_color = PALETTE.gray.darkened(0.45)
		stone_canvas.draw_rect(Rect2(x - w*0.15, top_y - 10, w*0.3, 12), top_color)
		
		# Rune gravée illuminée
		var rune_glow = 0.4 + 0.4 * sin(time_elapsed * 2.5 + stone.x * 0.01)
		var rune_color = PALETTE.mystic_light
		rune_color.a = rune_glow
		var rune_y = ground_y - h * 0.5
		var font = ThemeDB.fallback_font
		var symbol = ogham_symbols[stone.rune_idx % ogham_symbols.size()]
		
		# Glow derrière la rune (plusieurs couches)
		var glow_color = PALETTE.mystic
		glow_color.a = rune_glow * 0.2
		stone_canvas.draw_rect(Rect2(x - 18, rune_y - 32, 36, 48), glow_color)
		glow_color.a = rune_glow * 0.35
		stone_canvas.draw_rect(Rect2(x - 12, rune_y - 26, 24, 38), glow_color)
		
		stone_canvas.draw_string(font, Vector2(x - 10, rune_y), symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, 32, rune_color)
	
	# Sol avec herbe pixelisée dense
	var grass_colors = [PALETTE.grass_dark, PALETTE.grass_dark.darkened(0.25), PALETTE.grass.darkened(0.6)]
	for i in range(int(screen_size.x / 4)):
		var grass_x = i * 4
		var grass_h = 4 + (hash(i) % 8)
		var grass_color = grass_colors[hash(i) % grass_colors.size()]
		stone_canvas.draw_rect(Rect2(grass_x, ground_y - grass_h, 3, grass_h + 40), grass_color)

# =============================================================================
# SETUP - Layers de rendu
# =============================================================================
func _setup_layers() -> void:
	# Layer menhirs (derrière les particules)
	stone_canvas = Control.new()
	stone_canvas.name = "StoneCanvas"
	stone_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	stone_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone_canvas.z_index = -80
	add_child(stone_canvas)
	stone_canvas.draw.connect(_draw_stones)
	
	# Layer particules
	particle_canvas = Control.new()
	particle_canvas.name = "ParticleCanvas"
	particle_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	particle_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle_canvas.z_index = -70
	add_child(particle_canvas)
	particle_canvas.draw.connect(_draw_particles)
	
	# Layer runes flottantes
	rune_canvas = Control.new()
	rune_canvas.name = "RuneCanvas"
	rune_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	rune_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune_canvas.z_index = -60
	add_child(rune_canvas)
	rune_canvas.draw.connect(_draw_runes)
	
	# Layer brume
	fog_overlay = Control.new()
	fog_overlay.name = "FogOverlay"
	fog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_overlay.z_index = -50
	add_child(fog_overlay)
	fog_overlay.draw.connect(_draw_fog)
	
	print("[MainMenu] Animation layers created (z: -80 to -50)")

func _setup_overlays() -> void:
	# Vignette (au-dessus de tout sauf cursor)
	vignette_overlay = Control.new()
	vignette_overlay.name = "Vignette"
	vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_overlay.z_index = 50
	add_child(vignette_overlay)
	vignette_overlay.draw.connect(_draw_vignette)
	
	# Scanlines
	scanlines_overlay = Control.new()
	scanlines_overlay.name = "Scanlines"
	scanlines_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanlines_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanlines_overlay.z_index = 51
	add_child(scanlines_overlay)
	scanlines_overlay.draw.connect(_draw_scanlines)
	
	print("[MainMenu] Overlay layers created (vignette, scanlines)")

# =============================================================================
# PARTICULES MAGIQUES
# =============================================================================
func _init_particles(count: int) -> void:
	var screen_size = get_viewport_rect().size
	particles.clear()
	for i in range(count):
		particles.append(_create_particle(screen_size, true))

func _create_particle(screen_size: Vector2, random_y: bool = false) -> Dictionary:
	var p_types = ["firefly", "spark", "dust", "ogham", "orb"]
	var y_pos = randf() * screen_size.y if random_y else screen_size.y + randf_range(10, 50)
	
	# Éviter le centre pour ne pas polluer le menu
	var x_pos = randf() * screen_size.x
	if randf() > 0.3:  # 70% des particules sur les côtés
		if randf() > 0.5:
			x_pos = randf_range(0, screen_size.x * 0.25)
		else:
			x_pos = randf_range(screen_size.x * 0.75, screen_size.x)
	
	return {
		"pos": Vector2(x_pos, y_pos),
		"vel": Vector2(randf_range(-20, 20), randf_range(-40, -100)),
		"size": randf_range(2, 7),
		"life": randf_range(4, 10),
		"max_life": randf_range(4, 10),
		"type": p_types[randi() % p_types.size()],
		"phase": randf() * TAU,
		"color_idx": randi() % 5
	}

func _update_particles(delta: float) -> void:
	var screen_size = get_viewport_rect().size
	for i in range(particles.size()):
		var p = particles[i]
		p.pos.x += p.vel.x * delta + sin(time_elapsed * 2 + p.phase) * 0.8
		p.pos.y += p.vel.y * delta
		p.life -= delta
		
		if p.life <= 0 or p.pos.y < -50:
			particles[i] = _create_particle(screen_size, false)

func _draw_particles() -> void:
	var colors = [PALETTE.mystic_light, PALETTE.thunder_light, PALETTE.grass_light, PALETTE.fire_light, PALETTE.water_light]
	
	for p in particles:
		var alpha = clamp(p.life / p.max_life, 0, 1)
		var pulse = 0.3 + 0.7 * sin(time_elapsed * 5 + p.phase)
		var color = colors[p.color_idx]
		color.a = alpha * pulse
		
		var sz = p.size * (0.4 + 0.6 * alpha)
		
		match p.type:
			"firefly":
				# Point central brillant
				particle_canvas.draw_rect(Rect2(p.pos - Vector2(sz/2, sz/2), Vector2(sz, sz)), color)
				# Halo
				var halo = color
				halo.a *= 0.2
				particle_canvas.draw_rect(Rect2(p.pos - Vector2(sz, sz), Vector2(sz*2, sz*2)), halo)
			"spark":
				# Croix scintillante
				particle_canvas.draw_rect(Rect2(p.pos.x - 1, p.pos.y - sz, 2, sz*2), color)
				particle_canvas.draw_rect(Rect2(p.pos.x - sz, p.pos.y - 1, sz*2, 2), color)
			"dust":
				# Petit point
				particle_canvas.draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(2, 2)), color)
			"ogham":
				# Trait vertical (style ogham)
				particle_canvas.draw_rect(Rect2(p.pos.x - 1, p.pos.y - sz, 2, sz * 2), color)
				# Petite barre horizontale
				if randf() > 0.5:
					particle_canvas.draw_rect(Rect2(p.pos.x - sz*0.5, p.pos.y, sz, 2), color)
			"orb":
				# Cercle avec anneau
				particle_canvas.draw_rect(Rect2(p.pos - Vector2(sz/2, sz/2), Vector2(sz, sz)), color)
				var ring = color
				ring.a *= 0.35
				particle_canvas.draw_rect(Rect2(p.pos.x - sz - 1, p.pos.y - 1, sz*2 + 2, 2), ring)
				particle_canvas.draw_rect(Rect2(p.pos.x - 1, p.pos.y - sz - 1, 2, sz*2 + 2), ring)

# =============================================================================
# RUNES FLOTTANTES
# =============================================================================
func _init_runes(count: int) -> void:
	var screen_size = get_viewport_rect().size
	runes.clear()
	for i in range(count):
		# Éviter le centre où se trouve le menu
		var x: float
		if randf() > 0.5:
			x = randf_range(10, screen_size.x * 0.22)
		else:
			x = randf_range(screen_size.x * 0.78, screen_size.x - 10)
		
		runes.append({
			"pos": Vector2(x, randf_range(50, screen_size.y - 80)),
			"symbol": ogham_symbols[randi() % ogham_symbols.size()],
			"size": randf_range(18, 38),
			"phase": randf() * TAU,
			"float_speed": randf_range(0.5, 1.2),
			"alpha": randf_range(0.08, 0.25),
			"drift_x": randf_range(-0.3, 0.3)
		})

func _update_runes(delta: float) -> void:
	var screen_size = get_viewport_rect().size
	for r in runes:
		r.phase += delta * 0.4
		r.pos.x += r.drift_x
		# Reboucler si sort de l'écran
		if r.pos.x < -20:
			r.pos.x = screen_size.x + 10
		elif r.pos.x > screen_size.x + 20:
			r.pos.x = -10

func _draw_runes() -> void:
	var font = ThemeDB.fallback_font
	
	for r in runes:
		var float_y = sin(time_elapsed * r.float_speed + r.phase) * 18
		var pulse = 0.4 + 0.6 * sin(time_elapsed * 1.5 + r.phase)
		
		var color = PALETTE.mystic
		color.a = r.alpha * pulse
		
		var pos = r.pos + Vector2(0, float_y)
		
		# Glow multicouche
		var glow = PALETTE.mystic_light
		glow.a = color.a * 0.2
		rune_canvas.draw_string(font, pos + Vector2(3, 3), r.symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, int(r.size), glow)
		glow.a = color.a * 0.4
		rune_canvas.draw_string(font, pos + Vector2(1, 1), r.symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, int(r.size), glow)
		
		# Rune principale
		rune_canvas.draw_string(font, pos, r.symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, int(r.size), color)

# =============================================================================
# BRUME ANIMÉE
# =============================================================================
func _draw_fog() -> void:
	var screen_size = get_viewport_rect().size
	
	# Plusieurs couches de brume
	for layer in range(6):
		var y_base = screen_size.y * (0.45 + layer * 0.09)
		var x_off = sin(time_elapsed * 0.15 + layer * 0.7) * 120
		var fog_color = PALETTE.mystic_dark
		fog_color.a = 0.06 - layer * 0.008
		
		for j in range(25):
			var rx = fmod(j * 70 + x_off + layer * 40, screen_size.x + 180) - 90
			var ry = y_base + sin(time_elapsed * 0.4 + j * 0.4 + layer) * 35
			var rw = 50 + (hash(j + layer * 100) % 80)
			var rh = 6 + (hash(j * 3 + layer) % 12)
			fog_overlay.draw_rect(Rect2(rx, ry, rw, rh), fog_color)

# =============================================================================
# VIGNETTE & SCANLINES
# =============================================================================
func _draw_vignette() -> void:
	var screen_size = get_viewport_rect().size
	
	for i in range(20):
		var ratio = float(i) / 20.0
		var alpha = ratio * ratio * 0.6
		var color = PALETTE.black
		color.a = alpha
		var margin = ratio * min(screen_size.x, screen_size.y) * 0.3
		
		# Bords latéraux
		vignette_overlay.draw_rect(Rect2(0, 0, margin, screen_size.y), color)
		vignette_overlay.draw_rect(Rect2(screen_size.x - margin, 0, margin, screen_size.y), color)
		# Bords haut/bas
		vignette_overlay.draw_rect(Rect2(0, 0, screen_size.x, margin * 0.6), color)
		vignette_overlay.draw_rect(Rect2(0, screen_size.y - margin * 0.6, screen_size.x, margin * 0.6), color)

func _draw_scanlines() -> void:
	var screen_size = get_viewport_rect().size
	var line_color = PALETTE.black
	line_color.a = 0.05
	
	for y in range(0, int(screen_size.y), 3):
		scanlines_overlay.draw_rect(Rect2(0, y, screen_size.x, 1), line_color)

# =============================================================================
# CURSEUR CELTIQUE
# =============================================================================
func _setup_custom_cursor() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	cursor_canvas = Control.new()
	cursor_canvas.name = "CelticCursor"
	cursor_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_canvas.z_index = 100  # Au-dessus de tout
	add_child(cursor_canvas)
	cursor_canvas.draw.connect(_draw_cursor)
	print("[MainMenu] Celtic cursor initialized")

func _draw_cursor() -> void:
	# Traînée magique
	for i in range(cursor_trail.size()):
		var pos = cursor_trail[i]
		var alpha = 1.0 - float(i) / float(cursor_trail.size())
		var sz = 6 - i * 0.45
		if sz > 0:
			var trail_col = PALETTE.mystic_light
			trail_col.a = alpha * 0.45
			cursor_canvas.draw_rect(Rect2(pos - Vector2(sz/2, sz/2), Vector2(sz, sz)), trail_col)
	
	var pos = cursor_pos
	var pulse = 0.75 + 0.25 * sin(time_elapsed * 12)
	var s: float = 2.5  # Taille pixel
	
	var outline = PALETTE.black
	var main = PALETTE.cream
	var accent = PALETTE.mystic_light
	accent.a = pulse
	
	# Forme de lance/flèche celtique - Contour noir
	_draw_cursor_shape(pos, s, outline, 1)
	# Remplissage crème
	_draw_cursor_shape(pos, s, main, 0)
	# Accents mystiques
	_draw_cursor_accents(pos, s, accent)
	
	# Glow pulsant à la pointe
	var glow_sz = s * 2 + sin(time_elapsed * 15) * 1
	var glow_col = PALETTE.mystic_light
	glow_col.a = 0.4 + 0.3 * pulse
	cursor_canvas.draw_rect(Rect2(pos.x - glow_sz/2, pos.y - glow_sz/2, glow_sz, glow_sz), glow_col)

func _draw_cursor_shape(pos: Vector2, s: float, color: Color, o: int) -> void:
	var of = float(o)
	# Pointe de flèche
	cursor_canvas.draw_rect(Rect2(pos.x - of, pos.y - of, s + of*2, s*4 + of*2), color)
	# Tête élargie
	cursor_canvas.draw_rect(Rect2(pos.x - s - of, pos.y + s*3 - of, s*3 + of*2, s*2 + of*2), color)
	# Corps principal
	cursor_canvas.draw_rect(Rect2(pos.x - of, pos.y + s*5 - of, s + of*2, s*8 + of*2), color)
	# Spirale gauche
	cursor_canvas.draw_rect(Rect2(pos.x - s*2 - of, pos.y + s*7 - of, s + of*2, s + of*2), color)
	cursor_canvas.draw_rect(Rect2(pos.x - s*3 - of, pos.y + s*8 - of, s + of*2, s*2 + of*2), color)
	# Spirale droite
	cursor_canvas.draw_rect(Rect2(pos.x + s - of, pos.y + s*7 - of, s + of*2, s + of*2), color)
	cursor_canvas.draw_rect(Rect2(pos.x + s*2 - of, pos.y + s*8 - of, s + of*2, s*2 + of*2), color)
	# Base
	cursor_canvas.draw_rect(Rect2(pos.x - s - of, pos.y + s*12 - of, s*3 + of*2, s + of*2), color)

func _draw_cursor_accents(pos: Vector2, s: float, color: Color) -> void:
	# Ligne centrale lumineuse
	cursor_canvas.draw_rect(Rect2(pos.x, pos.y + s*6, s, s*5), color)
	# Points clignotants sur les spirales
	if int(time_elapsed * 10) % 2 == 0:
		cursor_canvas.draw_rect(Rect2(pos.x - s*3, pos.y + s*9, s, s), color)
		cursor_canvas.draw_rect(Rect2(pos.x + s*2, pos.y + s*9, s, s), color)

# =============================================================================
# STYLE TITRE
# =============================================================================
func _style_title() -> void:
	if not title_label:
		return
	title_label.add_theme_color_override("font_color", PALETTE.thunder)
	title_label.add_theme_color_override("font_shadow_color", PALETTE.black)
	title_label.add_theme_constant_override("shadow_offset_x", 5)
	title_label.add_theme_constant_override("shadow_offset_y", 5)

func _update_title_animation(_delta: float) -> void:
	if not title_label:
		return
	title_offset = sin(time_elapsed * 1.0) * 5
	title_label.position.y = title_offset
	
	# Pulsation de couleur
	var pulse = 0.8 + 0.2 * sin(time_elapsed * 2.0)
	var col = PALETTE.thunder.lerp(PALETTE.thunder_light, 1.0 - pulse)
	title_label.add_theme_color_override("font_color", col)

# =============================================================================
# BOUTONS - Effets hover/click
# =============================================================================
func _connect_all_buttons() -> void:
	all_buttons = _find_all_buttons(self)
	print("[MainMenu] Found", all_buttons.size(), "buttons")
	
	for btn in all_buttons:
		if btn is Button:
			# Effets hover
			if not btn.mouse_entered.is_connected(_on_btn_hover):
				btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			if not btn.mouse_exited.is_connected(_on_btn_unhover):
				btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			if not btn.pressed.is_connected(_on_btn_pressed):
				btn.pressed.connect(_on_btn_pressed.bind(btn))

func _on_btn_hover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
	
	# Spawn particules autour du bouton
	var btn_center = btn.global_position + btn.size / 2
	for i in range(6):
		var screen_size = get_viewport_rect().size
		var np = _create_particle(screen_size, true)
		np.pos = btn_center + Vector2(randf_range(-50, 50), randf_range(-20, 20))
		np.vel = Vector2(randf_range(-30, 30), randf_range(-60, -120))
		np.life = 1.0
		np.max_life = 1.0
		np.type = "spark"
		np.color_idx = 0  # Mystic
		particles.append(np)

func _on_btn_unhover(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _on_btn_pressed(btn: Button) -> void:
	print("[MainMenu] Button pressed:", btn.name)
	# Burst de particules depuis le centre
	var center = get_viewport_rect().size / 2
	for i in range(25):
		var screen_size = get_viewport_rect().size
		var np = _create_particle(screen_size, true)
		np.pos = center
		var angle = randf() * TAU
		np.vel = Vector2(cos(angle), sin(angle)) * randf_range(120, 220)
		np.life = 0.7
		np.max_life = 0.7
		np.type = "orb"
		np.color_idx = randi() % 5
		particles.append(np)

# =============================================================================
# CLEANUP
# =============================================================================
func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
