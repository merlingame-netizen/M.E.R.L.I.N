## ═══════════════════════════════════════════════════════════════════════════════
## DRU v7 - Main Game Controller
## ═══════════════════════════════════════════════════════════════════════════════
## Main scene that handles all game phases and transitions
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

# References to subscenes (will be loaded dynamically)
var title_screen: Control
var map_screen: Control
var combat_screen: Control
var event_screen: Control
var hub_screen: Control
var pause_menu: Control

# Transition system
var transition_overlay: ColorRect
var transition_tween: Tween
var is_transitioning: bool = false

# Current screen reference
var current_screen: Control = null

func _ready() -> void:
	# Setup transition overlay
	_setup_transition_overlay()
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)
		GameManager.transition_requested.connect(_on_transition_requested)
	
	# Start with launch animation then title
	_play_launch_animation()

func _setup_transition_overlay() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = GameManager.PALETTE.black
	transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.modulate.a = 0
	add_child(transition_overlay)
	move_child(transition_overlay, get_child_count() - 1)

func _play_launch_animation() -> void:
	# Create launch animation container
	var launch_container := Control.new()
	launch_container.name = "LaunchAnimation"
	launch_container.anchors_preset = Control.PRESET_FULL_RECT
	add_child(launch_container)
	
	# Black background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.black
	bg.anchors_preset = Control.PRESET_FULL_RECT
	launch_container.add_child(bg)
	
	# Logo text
	var logo := Label.new()
	logo.text = "MaxCorp Interactive"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.anchors_preset = Control.PRESET_CENTER
	logo.add_theme_color_override("font_color", GameManager.PALETTE.cream)
	logo.add_theme_font_size_override("font_size", 16)
	logo.modulate.a = 0
	launch_container.add_child(logo)
	
	# "Presents" text
	var presents := Label.new()
	presents.text = "présente"
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	presents.anchors_preset = Control.PRESET_CENTER
	presents.position.y = 30
	presents.add_theme_color_override("font_color", GameManager.PALETTE.gray)
	presents.add_theme_font_size_override("font_size", 10)
	presents.modulate.a = 0
	launch_container.add_child(presents)
	
	# Animate
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Fade in logo
	tween.tween_property(logo, "modulate:a", 1.0, 0.8)
	tween.tween_property(presents, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	
	# Fade out
	tween.tween_property(logo, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(presents, "modulate:a", 0.0, 0.5)
	tween.tween_interval(0.3)
	
	# Clean up and show title
	tween.tween_callback(func():
		launch_container.queue_free()
		_show_title_screen()
	)

func _show_title_screen() -> void:
	_transition_to_screen("title")

func _transition_to_screen(screen_name: String, data: Dictionary = {}) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Fade to black
	var tween := create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, 0.3)
	
	await tween.finished
	
	# Remove current screen
	if current_screen:
		current_screen.queue_free()
		current_screen = null
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Load new screen
	var new_screen: Control = null
	match screen_name:
		"title":
			new_screen = _create_title_screen()
		"map":
			new_screen = _create_map_screen()
		"combat":
			new_screen = _create_combat_screen(data)
		"event":
			new_screen = _create_event_screen(data)
		"hub":
			new_screen = _create_hub_screen()
		"rest", "shop":
			new_screen = _create_rest_shop_screen(screen_name)
		"end":
			new_screen = _create_end_screen(data)
		"intro":
			new_screen = _create_intro_screen()
	
	if new_screen:
		add_child(new_screen)
		move_child(transition_overlay, get_child_count() - 1)
		current_screen = new_screen
	
	# Fade from black
	var fade_tween := create_tween()
	fade_tween.tween_property(transition_overlay, "modulate:a", 0.0, 0.3)
	
	await fade_tween.finished
	is_transitioning = false

func _on_game_state_changed(new_phase: String) -> void:
	match new_phase:
		"run_started":
			if GameManager.flags.intro_seen:
				_transition_to_screen("map")
			else:
				_transition_to_screen("intro")
		"run_ended":
			_transition_to_screen("end", {"victory": GameManager.bestiole.hp > 0})

func _on_transition_requested(transition_type: String, data: Dictionary) -> void:
	_transition_to_screen(transition_type, data)

# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN CREATION METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func _create_title_screen() -> Control:
	var screen := Control.new()
	screen.name = "TitleScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	# Background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.grass_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	# Dither overlay
	var dither := _create_dither_overlay(GameManager.PALETTE.black, 0.3)
	screen.add_child(dither)
	
	# Center container
	var center := VBoxContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(center)
	
	# Title
	var title := Label.new()
	title.text = "DRU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", GameManager.PALETTE.cream)
	center.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Le Jeu des Oghams"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", GameManager.PALETTE.grass)
	center.add_child(subtitle)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)
	
	# Type icon
	var type_label := Label.new()
	type_label.text = GameManager.TYPES[GameManager.bestiole.type].icon
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 64)
	center.add_child(type_label)
	
	# Animate type label
	var tween := create_tween().set_loops()
	tween.tween_property(type_label, "position:y", -5, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(type_label, "position:y", 0, 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# Bestiole info
	var info := Label.new()
	info.text = "%s — %s Nv.%d" % [
		GameManager.bestiole.name,
		GameManager.TYPES[GameManager.bestiole.type].name,
		GameManager.bestiole.level
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", GameManager.PALETTE.cream)
	center.add_child(info)
	
	# Buttons container
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(200, 0)
	buttons.add_theme_constant_override("separation", 10)
	center.add_child(buttons)
	
	# New game button
	var new_btn := _create_gbc_button("★ NOUVELLE PARTIE", GameManager.PALETTE.water)
	new_btn.pressed.connect(func():
		GameManager.start_new_game()
	)
	buttons.add_child(new_btn)
	
	# Hub button
	var hub_btn := _create_gbc_button("🏠 REPÈRE", GameManager.PALETTE.mystic)
	hub_btn.pressed.connect(func():
		_transition_to_screen("hub")
	)
	buttons.add_child(hub_btn)
	
	# Version label
	var version := Label.new()
	version.text = "v7.0 — MaxCorp Interactive"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.anchors_preset = Control.PRESET_BOTTOM_WIDE
	version.position.y = -20
	version.add_theme_font_size_override("font_size", 8)
	version.add_theme_color_override("font_color", GameManager.PALETTE.gray)
	screen.add_child(version)
	
	return screen

func _create_intro_screen() -> Control:
	var screen := Control.new()
	screen.name = "IntroScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	# Background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.black
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	# Dialogue box will be added as child
	var dialogue_data := [
		{"speaker": "", "text": "Dans les brumes éternelles de Brocéliande..."},
		{"speaker": "", "text": "Là où le temps lui-même hésite à s'écouler..."},
		{"speaker": "", "text": "Une prophétie ancestrale refait surface."},
		{"speaker": "", "text": "Les Oghams — ces mots de pouvoir gravés par les premiers druides —"},
		{"speaker": "", "text": "s'éveillent après des millénaires de sommeil."},
		{"speaker": "MERLIN", "text": "Te voilà enfin, jeune druide."},
		{"speaker": "MERLIN", "text": "J'ai préparé pour toi un compagnon spécial..."},
		{"speaker": "MERLIN", "text": "Une créature liée aux éléments, née de la magie ancienne."},
		{"speaker": "MERLIN", "text": "Son nom est Bestiole. Prends-en soin."},
		{"speaker": "MERLIN", "text": "Car c'est ensemble que vous affronterez les ténèbres."},
	]
	
	var dialogue_box := _create_dialogue_box(dialogue_data, func():
		GameManager.flags.intro_seen = true
		_transition_to_screen("map")
	)
	dialogue_box.anchors_preset = Control.PRESET_CENTER
	dialogue_box.custom_minimum_size = Vector2(450, 150)
	dialogue_box.position = Vector2(-225, -75)
	screen.add_child(dialogue_box)
	
	return screen

func _create_map_screen() -> Control:
	var screen := Control.new()
	screen.name = "MapScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	# Background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.earth_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	# Header bar
	var header := _create_header_bar()
	screen.add_child(header)
	
	# Progress bar (floors)
	var progress := _create_floor_progress()
	progress.position = Vector2(20, 70)
	screen.add_child(progress)
	
	# Node selection area
	var node_container := HBoxContainer.new()
	node_container.name = "NodeContainer"
	node_container.anchors_preset = Control.PRESET_CENTER
	node_container.alignment = BoxContainer.ALIGNMENT_CENTER
	node_container.add_theme_constant_override("separation", 20)
	screen.add_child(node_container)
	
	# Get available nodes
	var next_nodes := _get_next_nodes()
	
	if next_nodes.is_empty():
		# Run complete
		var complete_label := Label.new()
		complete_label.text = "✔ Voyage terminé!"
		complete_label.add_theme_font_size_override("font_size", 16)
		complete_label.add_theme_color_override("font_color", GameManager.PALETTE.grass)
		node_container.add_child(complete_label)
		
		GameManager.end_run(true)
	else:
		for node in next_nodes:
			var node_btn := _create_node_button(node)
			node_container.add_child(node_btn)
	
	# Pause button
	var pause_btn := _create_gbc_button("⏸", GameManager.PALETTE.gray)
	pause_btn.custom_minimum_size = Vector2(40, 40)
	pause_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	pause_btn.position = Vector2(-60, 20)
	pause_btn.pressed.connect(func():
		_show_pause_menu()
	)
	screen.add_child(pause_btn)
	
	return screen

func _create_combat_screen(data: Dictionary) -> Control:
	var screen := Control.new()
	screen.name = "CombatScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	var enemy_data: Dictionary = data.get("enemy", GameManager.ENEMIES.korigan)
	var enemy_hp: int = enemy_data.hp
	var enemy_max_hp: int = enemy_data.hp
	var is_player_turn: bool = true
	var combat_log: Array = []
	
	# Battle arena (top half)
	var arena := ColorRect.new()
	arena.name = "Arena"
	arena.color = GameManager.PALETTE.grass_dark
	arena.anchors_preset = Control.PRESET_TOP_WIDE
	arena.size.y = get_viewport_rect().size.y * 0.6
	screen.add_child(arena)
	
	# Grass dither
	var grass := _create_dither_overlay(GameManager.PALETTE.grass, 0.5)
	grass.anchors_preset = Control.PRESET_BOTTOM_WIDE
	grass.size.y = arena.size.y * 0.4
	arena.add_child(grass)
	
	# Enemy side (top right)
	var enemy_container := VBoxContainer.new()
	enemy_container.anchors_preset = Control.PRESET_TOP_RIGHT
	enemy_container.position = Vector2(-180, 20)
	arena.add_child(enemy_container)
	
	var enemy_panel := _create_gbc_panel()
	enemy_panel.custom_minimum_size = Vector2(150, 60)
	enemy_container.add_child(enemy_panel)
	
	var enemy_name := Label.new()
	enemy_name.text = "%s %s" % [GameManager.TYPES[enemy_data.type].icon, enemy_data.name]
	enemy_name.add_theme_font_size_override("font_size", 10)
	enemy_panel.add_child(enemy_name)
	
	var enemy_hp_bar := _create_stat_bar("", enemy_hp, enemy_max_hp, GameManager.PALETTE.hp_green)
	enemy_hp_bar.name = "EnemyHPBar"
	enemy_panel.add_child(enemy_hp_bar)
	
	# Enemy sprite placeholder
	var enemy_sprite := Label.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.text = "👹"
	enemy_sprite.add_theme_font_size_override("font_size", 64)
	enemy_sprite.position = Vector2(50, 20)
	enemy_container.add_child(enemy_sprite)
	
	# Player side (bottom left of arena)
	var player_container := VBoxContainer.new()
	player_container.anchors_preset = Control.PRESET_BOTTOM_LEFT
	player_container.position = Vector2(20, -120)
	arena.add_child(player_container)
	
	var player_panel := _create_gbc_panel()
	player_panel.custom_minimum_size = Vector2(150, 60)
	player_container.add_child(player_panel)
	
	var player_name := Label.new()
	player_name.text = "%s %s" % [GameManager.TYPES[GameManager.bestiole.type].icon, GameManager.bestiole.name]
	player_name.add_theme_font_size_override("font_size", 10)
	player_panel.add_child(player_name)
	
	var player_hp_bar := _create_stat_bar("", GameManager.bestiole.hp, GameManager.bestiole.max_hp, GameManager.PALETTE.hp_green)
	player_hp_bar.name = "PlayerHPBar"
	player_panel.add_child(player_hp_bar)
	
	# Player sprite
	var player_sprite := Label.new()
	player_sprite.name = "PlayerSprite"
	player_sprite.text = GameManager.TYPES[GameManager.bestiole.type].icon
	player_sprite.add_theme_font_size_override("font_size", 64)
	player_sprite.position = Vector2(50, -80)
	player_container.add_child(player_sprite)
	
	# UI panel (bottom half)
	var ui_panel := ColorRect.new()
	ui_panel.color = GameManager.PALETTE.cream
	ui_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	ui_panel.offset_top = -get_viewport_rect().size.y * 0.4
	screen.add_child(ui_panel)
	
	# Combat log
	var log_panel := _create_gbc_panel()
	log_panel.custom_minimum_size = Vector2(get_viewport_rect().size.x - 40, 60)
	log_panel.position = Vector2(20, 10)
	ui_panel.add_child(log_panel)
	
	var log_label := Label.new()
	log_label.name = "CombatLog"
	log_label.text = "Un %s sauvage apparaît!" % enemy_data.name
	log_label.add_theme_font_size_override("font_size", 10)
	log_label.add_theme_color_override("font_color", GameManager.PALETTE.black)
	log_panel.add_child(log_label)
	
	# Ogham buttons (2x2 grid)
	var ogham_grid := GridContainer.new()
	ogham_grid.name = "OghamGrid"
	ogham_grid.columns = 2
	ogham_grid.add_theme_constant_override("h_separation", 10)
	ogham_grid.add_theme_constant_override("v_separation", 10)
	ogham_grid.position = Vector2(20, 80)
	ui_panel.add_child(ogham_grid)
	
	for i in range(4):
		var ogham_id: String = GameManager.bestiole.equipped_oghams[i] if i < GameManager.bestiole.equipped_oghams.size() else ""
		if ogham_id.is_empty():
			var empty_btn := _create_gbc_button("---", GameManager.PALETTE.gray)
			empty_btn.custom_minimum_size = Vector2(150, 50)
			empty_btn.disabled = true
			ogham_grid.add_child(empty_btn)
		else:
			var ogham_data: Dictionary = GameManager.OGHAMS.get(ogham_id, {})
			var ogham_type: String = ogham_data.get("type", "nature")
			var btn := _create_gbc_button(
				"%s %s" % [GameManager.TYPES[ogham_type].icon, ogham_data.get("name", "???")],
				GameManager.get_type_color(ogham_type)
			)
			btn.custom_minimum_size = Vector2(150, 50)
			
			# Store reference for combat logic
			btn.set_meta("ogham_id", ogham_id)
			btn.pressed.connect(_on_ogham_selected.bind(screen, ogham_id, enemy_data))
			ogham_grid.add_child(btn)
	
	# Run button
	var run_btn := _create_gbc_button("🏃 FUIR", GameManager.PALETTE.fire)
	run_btn.custom_minimum_size = Vector2(100, 40)
	run_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	run_btn.position = Vector2(-120, -60)
	run_btn.pressed.connect(func():
		# 50% chance to escape
		if randf() > 0.5:
			_transition_to_screen("map")
		else:
			var log_label = screen.get_node_or_null("CombatLog")
			if log_label:
				log_label.text = "Impossible de fuir!"
	)
	ui_panel.add_child(run_btn)
	
	return screen

func _on_ogham_selected(combat_screen: Control, ogham_id: String, enemy_data: Dictionary) -> void:
	var ogham_data: Dictionary = GameManager.OGHAMS.get(ogham_id, {})
	var log_label: Label = combat_screen.find_child("CombatLog", true, false)
	var enemy_hp_bar: ProgressBar = combat_screen.find_child("EnemyHPBar", true, false)
	var player_hp_bar: ProgressBar = combat_screen.find_child("PlayerHPBar", true, false)
	
	# Calculate damage
	var multiplier: float = GameManager.get_type_multiplier(ogham_data.type, enemy_data.type)
	var base_damage: int = ogham_data.power + GameManager.bestiole.atk
	var damage: int = int(base_damage * multiplier)
	
	# Update log
	var effectiveness: String = ""
	if multiplier > 1:
		effectiveness = " (Super efficace!)"
	elif multiplier < 1 and multiplier > 0:
		effectiveness = " (Peu efficace...)"
	elif multiplier == 0:
		effectiveness = " (Aucun effet!)"
	
	if log_label:
		log_label.text = "%s utilise %s! %d dégâts%s" % [
			GameManager.bestiole.name,
			ogham_data.name,
			damage,
			effectiveness
		]
	
	# Apply damage to enemy (simplified - would need proper state management)
	# For now, just transition back to map after "winning"
	await get_tree().create_timer(1.5).timeout
	
	# Enemy turn
	var enemy_damage: int = enemy_data.atk - int(GameManager.bestiole.def / 2.0)
	enemy_damage = max(1, enemy_damage)
	GameManager.damage_bestiole(enemy_damage)
	
	if log_label:
		log_label.text = "%s attaque! %d dégâts" % [enemy_data.name, enemy_damage]
	
	await get_tree().create_timer(1.5).timeout
	
	# Check victory/defeat
	if GameManager.bestiole.hp <= 0:
		GameManager.end_run(false)
	else:
		# Simplified: win after first exchange
		GameManager.add_gold(enemy_data.gold)
		GameManager.add_xp(enemy_data.xp)
		GameManager.run.combats_won += 1
		GameManager.run.floor += 1
		GameManager.run.max_floor_reached = max(GameManager.run.max_floor_reached, GameManager.run.floor)
		_transition_to_screen("map")

func _create_event_screen(data: Dictionary) -> Control:
	var screen := Control.new()
	screen.name = "EventScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	# Background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.shadow_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	# Mystic dither
	var dither := _create_dither_overlay(GameManager.PALETTE.mystic_dark, 0.2)
	screen.add_child(dither)
	
	# Event panel
	var panel := _create_gbc_panel()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-200, -150)
	screen.add_child(panel)
	
	var title := Label.new()
	title.text = "⭐ ÉVÉNEMENT MYSTIQUE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", GameManager.PALETTE.mystic)
	panel.add_child(title)
	
	var description := Label.new()
	description.text = "Tu découvres un lieu étrange..."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(360, 80)
	description.add_theme_font_size_override("font_size", 11)
	panel.add_child(description)
	
	# Choices
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	panel.add_child(choices)
	
	var choice1 := _create_gbc_button("🎲 Tenter sa chance (TEST: DÉ ≥4)", GameManager.PALETTE.mystic)
	choice1.pressed.connect(func():
		_show_test_preview("DÉ", 4, func(success: bool):
			if success:
				GameManager.heal_bestiole(30)
			GameManager.run.floor += 1
			_transition_to_screen("map")
		)
	)
	choices.add_child(choice1)
	
	var choice2 := _create_gbc_button("🏃 Partir prudemment", GameManager.PALETTE.gray)
	choice2.pressed.connect(func():
		GameManager.run.floor += 1
		_transition_to_screen("map")
	)
	choices.add_child(choice2)
	
	return screen

func _create_hub_screen() -> Control:
	var screen := Control.new()
	screen.name = "HubScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	# Background
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.earth_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	# Header
	var header := HBoxContainer.new()
	header.position = Vector2(20, 20)
	screen.add_child(header)
	
	var back_btn := _create_gbc_button("← Retour", GameManager.PALETTE.gray)
	back_btn.pressed.connect(func():
		_transition_to_screen("title")
	)
	header.add_child(back_btn)
	
	var gold_panel := _create_gbc_panel()
	gold_panel.custom_minimum_size = Vector2(100, 40)
	header.add_child(gold_panel)
	
	var gold_label := Label.new()
	gold_label.text = "💰 %d" % GameManager.run.gold
	gold_label.add_theme_font_size_override("font_size", 12)
	gold_panel.add_child(gold_label)
	
	# Main panel
	var main_panel := _create_gbc_panel()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(320, 350)
	main_panel.anchors_preset = Control.PRESET_CENTER
	main_panel.position = Vector2(-160, -150)
	screen.add_child(main_panel)
	
	var panel_title := Label.new()
	panel_title.text = "🏠 REPÈRE DE BESTIOLE"
	panel_title.add_theme_font_size_override("font_size", 12)
	panel_title.add_theme_color_override("font_color", GameManager.PALETTE.earth)
	main_panel.add_child(panel_title)
	
	# Bestiole icon
	var bestiole_icon := Label.new()
	bestiole_icon.text = GameManager.TYPES[GameManager.bestiole.type].icon
	bestiole_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bestiole_icon.add_theme_font_size_override("font_size", 64)
	main_panel.add_child(bestiole_icon)
	
	# Animate
	var tween := create_tween().set_loops()
	tween.tween_property(bestiole_icon, "position:y", -5, 0.5)
	tween.tween_property(bestiole_icon, "position:y", 0, 0.5)
	
	# Stats
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	main_panel.add_child(stats)
	
	stats.add_child(_create_stat_bar("PV", GameManager.bestiole.hp, GameManager.bestiole.max_hp, GameManager.PALETTE.hp_green))
	stats.add_child(_create_stat_bar("Faim", GameManager.bestiole.hunger, 100, GameManager.PALETTE.hunger_orange))
	stats.add_child(_create_stat_bar("Bonheur", GameManager.bestiole.happiness, 100, GameManager.PALETTE.happy_pink))
	stats.add_child(_create_stat_bar("Énergie", GameManager.bestiole.energy, 100, GameManager.PALETTE.energy_blue))
	
	# Actions
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	main_panel.add_child(actions)
	
	var feed_btn := _create_gbc_button("🍖 Nourrir (10)", GameManager.PALETTE.hunger_orange)
	feed_btn.pressed.connect(func():
		if GameManager.spend_gold(10):
			GameManager.bestiole.hunger = min(100, GameManager.bestiole.hunger + 40)
			GameManager.emit_signal("bestiole_updated")
			_transition_to_screen("hub")  # Refresh
	)
	actions.add_child(feed_btn)
	
	var play_btn := _create_gbc_button("🎾 Jouer", GameManager.PALETTE.happy_pink)
	play_btn.pressed.connect(func():
		GameManager.bestiole.happiness = min(100, GameManager.bestiole.happiness + 30)
		GameManager.bestiole.energy = max(0, GameManager.bestiole.energy - 10)
		GameManager.emit_signal("bestiole_updated")
		_transition_to_screen("hub")
	)
	actions.add_child(play_btn)
	
	var rest_btn := _create_gbc_button("😴 Repos", GameManager.PALETTE.energy_blue)
	rest_btn.pressed.connect(func():
		GameManager.bestiole.energy = min(100, GameManager.bestiole.energy + 50)
		GameManager.emit_signal("bestiole_updated")
		_transition_to_screen("hub")
	)
	actions.add_child(rest_btn)
	
	var heal_btn := _create_gbc_button("💊 Soigner (20)", GameManager.PALETTE.hp_green)
	heal_btn.pressed.connect(func():
		if GameManager.spend_gold(20):
			GameManager.heal_bestiole(40)
			_transition_to_screen("hub")
	)
	actions.add_child(heal_btn)
	
	# Type change section
	var type_panel := _create_gbc_panel()
	type_panel.custom_minimum_size = Vector2(320, 120)
	type_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	type_panel.position.y = -140
	type_panel.position.x = (get_viewport_rect().size.x - 320) / 2
	screen.add_child(type_panel)
	
	var type_title := Label.new()
	type_title.text = "CHANGER TYPE (30💰)"
	type_title.add_theme_font_size_override("font_size", 10)
	type_panel.add_child(type_title)
	
	var type_grid := GridContainer.new()
	type_grid.columns = 7
	type_grid.add_theme_constant_override("h_separation", 5)
	type_grid.add_theme_constant_override("v_separation", 5)
	type_panel.add_child(type_grid)
	
	for type_name in GameManager.TYPES:
		var type_data: Dictionary = GameManager.TYPES[type_name]
		var unlocked: bool = GameManager.is_type_unlocked(type_name)
		var is_current: bool = GameManager.bestiole.type == type_name
		
		var type_btn := Button.new()
		type_btn.text = type_data.icon if unlocked else "🔒"
		type_btn.custom_minimum_size = Vector2(35, 35)
		type_btn.disabled = not unlocked or is_current
		
		if unlocked and not is_current:
			type_btn.pressed.connect(func():
				_animate_type_change(type_name)
			)
		
		type_grid.add_child(type_btn)
	
	return screen

func _animate_type_change(new_type: String) -> void:
	if not GameManager.spend_gold(30):
		return
	
	# Create flash animation
	var flash := ColorRect.new()
	flash.color = GameManager.get_type_color(new_type)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.modulate.a = 0
	add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		GameManager.change_bestiole_type(new_type)
	)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		flash.queue_free()
		_transition_to_screen("hub")
	)

func _create_rest_shop_screen(screen_type: String) -> Control:
	var screen := Control.new()
	screen.name = "RestShopScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.grass_dark if screen_type == "rest" else GameManager.PALETTE.earth_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	var panel := _create_gbc_panel()
	panel.custom_minimum_size = Vector2(350, 300)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-175, -150)
	screen.add_child(panel)
	
	var title := Label.new()
	title.text = "🏕️ FEU DE CAMP" if screen_type == "rest" else "🛒 BOUTIQUE"
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)
	
	# Bestiole icon
	var icon := Label.new()
	icon.text = GameManager.TYPES[GameManager.bestiole.type].icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	panel.add_child(icon)
	
	# HP bar
	var hp_bar := _create_stat_bar("PV", GameManager.bestiole.hp, GameManager.bestiole.max_hp, GameManager.PALETTE.hp_green)
	panel.add_child(hp_bar)
	
	# Gold display
	var gold_label := Label.new()
	gold_label.text = "💰 %d" % GameManager.run.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(gold_label)
	
	# Actions
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)
	
	if screen_type == "rest":
		var rest_btn := _create_gbc_button("😴 Se reposer (+40 PV, +30 Énergie)", GameManager.PALETTE.grass)
		rest_btn.pressed.connect(func():
			GameManager.heal_bestiole(40)
			GameManager.bestiole.energy = min(100, GameManager.bestiole.energy + 30)
			rest_btn.disabled = true
		)
		actions.add_child(rest_btn)
	else:
		var potion_btn := _create_gbc_button("💊 Potion (25💰) +40 PV", GameManager.PALETTE.hp_green)
		potion_btn.pressed.connect(func():
			if GameManager.spend_gold(25):
				GameManager.heal_bestiole(40)
				_transition_to_screen(screen_type)
		)
		actions.add_child(potion_btn)
		
		var food_btn := _create_gbc_button("🍖 Nourriture (15💰) +50 Faim", GameManager.PALETTE.hunger_orange)
		food_btn.pressed.connect(func():
			if GameManager.spend_gold(15):
				GameManager.bestiole.hunger = min(100, GameManager.bestiole.hunger + 50)
				_transition_to_screen(screen_type)
		)
		actions.add_child(food_btn)
	
	var continue_btn := _create_gbc_button("Continuer →", GameManager.PALETTE.water)
	continue_btn.pressed.connect(func():
		GameManager.run.floor += 1
		_transition_to_screen("map")
	)
	actions.add_child(continue_btn)
	
	return screen

func _create_end_screen(data: Dictionary) -> Control:
	var screen := Control.new()
	screen.name = "EndScreen"
	screen.anchors_preset = Control.PRESET_FULL_RECT
	
	var victory: bool = data.get("victory", false)
	
	var bg := ColorRect.new()
	bg.color = GameManager.PALETTE.grass_dark if victory else GameManager.PALETTE.fire_dark
	bg.anchors_preset = Control.PRESET_FULL_RECT
	screen.add_child(bg)
	
	var dither := _create_dither_overlay(GameManager.PALETTE.black, 0.4)
	screen.add_child(dither)
	
	var center := VBoxContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(center)
	
	var title := Label.new()
	title.text = "VICTOIRE!" if victory else "DÉFAITE..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GameManager.PALETTE.grass if victory else GameManager.PALETTE.fire)
	center.add_child(title)
	
	var icon := Label.new()
	icon.text = GameManager.TYPES[GameManager.bestiole.type].icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	center.add_child(icon)
	
	var stats_panel := _create_gbc_panel()
	stats_panel.custom_minimum_size = Vector2(220, 120)
	center.add_child(stats_panel)
	
	var stats_text := "Étage atteint: %d\nCombats gagnés: %d\nOr collecté: %d\nNiveau final: %d" % [
		GameManager.run.floor,
		GameManager.run.combats_won,
		GameManager.run.gold,
		GameManager.bestiole.level
	]
	var stats_label := Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_panel.add_child(stats_label)
	
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	center.add_child(buttons)
	
	var restart_btn := _create_gbc_button("🔄 RECOMMENCER", GameManager.PALETTE.grass)
	restart_btn.pressed.connect(func():
		GameManager.start_new_game()
	)
	buttons.add_child(restart_btn)
	
	var menu_btn := _create_gbc_button("🏠 MENU PRINCIPAL", GameManager.PALETTE.gray)
	menu_btn.pressed.connect(func():
		_transition_to_screen("title")
	)
	buttons.add_child(menu_btn)
	
	return screen

# ═══════════════════════════════════════════════════════════════════════════════
# TEST PREVIEW SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _show_test_preview(test_type: String, objective: int, callback: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.name = "TestOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(overlay)
	
	var panel := _create_gbc_panel()
	panel.custom_minimum_size = Vector2(300, 200)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-150, -100)
	overlay.add_child(panel)
	
	var title := Label.new()
	title.text = "⚠️ TEST EN APPROCHE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", GameManager.PALETTE.fire)
	panel.add_child(title)
	
	var type_label := Label.new()
	type_label.text = "Type: %s" % test_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(type_label)
	
	var obj_label := Label.new()
	obj_label.text = "Objectif: %d+" % objective
	obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_label.add_theme_font_size_override("font_size", 12)
	obj_label.add_theme_color_override("font_color", GameManager.PALETTE.mystic)
	panel.add_child(obj_label)
	
	var start_btn := _create_gbc_button("▶ COMMENCER", GameManager.PALETTE.grass)
	start_btn.pressed.connect(func():
		overlay.queue_free()
		_run_test(test_type, objective, callback)
	)
	panel.add_child(start_btn)
	
	var cancel_btn := _create_gbc_button("✕ ANNULER", GameManager.PALETTE.fire)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
	)
	panel.add_child(cancel_btn)

func _run_test(test_type: String, objective: int, callback: Callable) -> void:
	# Simple dice test for now
	var result: int = randi_range(1, 6)
	var success: bool = result >= objective
	
	var overlay := ColorRect.new()
	overlay.name = "TestResultOverlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(overlay)
	
	var result_label := Label.new()
	result_label.text = "🎲 %d" % result
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.anchors_preset = Control.PRESET_CENTER
	result_label.add_theme_font_size_override("font_size", 64)
	result_label.add_theme_color_override("font_color", GameManager.PALETTE.grass if success else GameManager.PALETTE.fire)
	overlay.add_child(result_label)
	
	var status_label := Label.new()
	status_label.text = "✔ SUCCÈS!" if success else "✗ ÉCHEC..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.anchors_preset = Control.PRESET_CENTER
	status_label.position.y = 60
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", GameManager.PALETTE.grass if success else GameManager.PALETTE.fire)
	overlay.add_child(status_label)
	
	# Animate dice roll
	var tween := create_tween()
	for i in range(10):
		tween.tween_callback(func():
			result_label.text = "🎲 %d" % randi_range(1, 6)
		)
		tween.tween_interval(0.1)
	tween.tween_callback(func():
		result_label.text = "🎲 %d" % result
	)
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		overlay.queue_free()
		callback.call(success)
	)

# ═══════════════════════════════════════════════════════════════════════════════
# PAUSE MENU
# ═══════════════════════════════════════════════════════════════════════════════

func _show_pause_menu() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	add_child(overlay)
	
	var panel := _create_gbc_panel()
	panel.custom_minimum_size = Vector2(250, 200)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-125, -100)
	overlay.add_child(panel)
	
	var title := Label.new()
	title.text = "⏸️ PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	
	var resume_btn := _create_gbc_button("▶ Reprendre", GameManager.PALETTE.grass)
	resume_btn.pressed.connect(func():
		overlay.queue_free()
	)
	buttons.add_child(resume_btn)
	
	var save_btn := _create_gbc_button("💾 Sauvegarder", GameManager.PALETTE.water)
	save_btn.pressed.connect(func():
		GameManager.save_to_slot(1)
		overlay.queue_free()
	)
	buttons.add_child(save_btn)
	
	var quit_btn := _create_gbc_button("🚪 Quitter", GameManager.PALETTE.fire)
	quit_btn.pressed.connect(func():
		overlay.queue_free()
		_transition_to_screen("title")
	)
	buttons.add_child(quit_btn)

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_next_nodes() -> Array:
	if GameManager.run.map.is_empty():
		return []
	
	var current_floor: int = GameManager.run.floor
	if current_floor >= GameManager.run.map.size():
		return []
	
	if current_floor == 0 and GameManager.run.current_node == null:
		return GameManager.run.map[0]
	
	if GameManager.run.current_node:
		var current: Dictionary = {}
		for floor_nodes in GameManager.run.map:
			for node in floor_nodes:
				if node.id == GameManager.run.current_node:
					current = node
					break
		
		if current.is_empty():
			return GameManager.run.map[current_floor] if current_floor < GameManager.run.map.size() else []
		
		var next_nodes: Array = []
		for floor_nodes in GameManager.run.map:
			for node in floor_nodes:
				if current.connections.has(node.id):
					next_nodes.append(node)
		return next_nodes
	
	return GameManager.run.map[current_floor] if current_floor < GameManager.run.map.size() else []

func _create_header_bar() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.position = Vector2(20, 20)
	header.add_theme_constant_override("separation", 10)
	
	# Bestiole mini panel
	var bestiole_panel := _create_gbc_panel()
	bestiole_panel.custom_minimum_size = Vector2(150, 50)
	header.add_child(bestiole_panel)
	
	var bestiole_container := HBoxContainer.new()
	bestiole_container.add_theme_constant_override("separation", 8)
	bestiole_panel.add_child(bestiole_container)
	
	var icon := Label.new()
	icon.text = GameManager.TYPES[GameManager.bestiole.type].icon
	icon.add_theme_font_size_override("font_size", 24)
	bestiole_container.add_child(icon)
	
	var stats := VBoxContainer.new()
	bestiole_container.add_child(stats)
	
	var name_label := Label.new()
	name_label.text = GameManager.bestiole.name
	name_label.add_theme_font_size_override("font_size", 9)
	stats.add_child(name_label)
	
	var hp_bar := _create_stat_bar("", GameManager.bestiole.hp, GameManager.bestiole.max_hp, GameManager.PALETTE.hp_green)
	hp_bar.custom_minimum_size = Vector2(80, 15)
	stats.add_child(hp_bar)
	
	# Gold panel
	var gold_panel := _create_gbc_panel()
	gold_panel.custom_minimum_size = Vector2(80, 50)
	header.add_child(gold_panel)
	
	var gold_label := Label.new()
	gold_label.text = "💰 %d" % GameManager.run.gold
	gold_label.add_theme_font_size_override("font_size", 12)
	gold_panel.add_child(gold_label)
	
	return header

func _create_floor_progress() -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	
	for i in range(GameManager.run.map.size()):
		var marker := ColorRect.new()
		marker.custom_minimum_size = Vector2(16, 16)
		
		if i < GameManager.run.floor:
			marker.color = GameManager.PALETTE.grass
		elif i == GameManager.run.floor:
			marker.color = GameManager.PALETTE.mystic
		else:
			marker.color = GameManager.PALETTE.dark_gray
		
		container.add_child(marker)
		
		if i < GameManager.run.map.size() - 1:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(8, 2)
			line.color = GameManager.PALETTE.dark_gray if i >= GameManager.run.floor else GameManager.PALETTE.grass
			container.add_child(line)
	
	return container

func _create_node_button(node: Dictionary) -> Control:
	var node_types := {
		"combat": {"color": GameManager.PALETTE.fire, "label": "Combat", "icon": "⚔"},
		"elite": {"color": GameManager.PALETTE.fire_dark, "label": "Élite", "icon": "💀"},
		"event": {"color": GameManager.PALETTE.mystic, "label": "Mystère", "icon": "?"},
		"boss": {"color": GameManager.PALETTE.black, "label": "Boss", "icon": "👑"},
		"shop": {"color": GameManager.PALETTE.thunder, "label": "Boutique", "icon": "$"},
		"rest": {"color": GameManager.PALETTE.grass, "label": "Repos", "icon": "♥"},
	}
	
	var data: Dictionary = node_types.get(node.type, node_types.event)
	
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 90)
	btn.text = data.icon
	btn.add_theme_font_size_override("font_size", 32)
	
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_color = GameManager.PALETTE.black
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	btn.pressed.connect(func():
		GameManager.run.current_node = node.id
		GameManager.run.path_taken.append(node.id)
		
		match node.type:
			"combat", "elite":
				var enemies := ["korigan", "spectre", "feu_follet", "ondine"]
				var enemy_key: String = enemies[randi() % enemies.size()]
				if node.type == "elite":
					enemy_key = "loup"
				_transition_to_screen("combat", {"enemy": GameManager.ENEMIES[enemy_key]})
			"boss":
				_transition_to_screen("combat", {"enemy": GameManager.ENEMIES.druide})
			"event":
				_transition_to_screen("event", {})
			"rest", "shop":
				_transition_to_screen(node.type)
	)
	
	container.add_child(btn)
	
	var label := Label.new()
	label.text = data.label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", GameManager.PALETTE.cream)
	container.add_child(label)
	
	# Pulse animation
	var tween := create_tween().set_loops()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.5)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.5)
	
	return container

func _create_gbc_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	style.bg_color = GameManager.PALETTE.cream
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_color = GameManager.PALETTE.black
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_bottom = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.shadow_color = GameManager.PALETTE.dark_gray
	style.shadow_offset = Vector2(4, 4)
	style.shadow_size = 0
	
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	return panel

func _create_gbc_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_color = color.darkened(0.3)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.shadow_color = GameManager.PALETTE.dark_gray
	style.shadow_offset = Vector2(3, 3)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = color.lightened(0.1)
	
	var pressed_style := style.duplicate()
	pressed_style.shadow_offset = Vector2(0, 0)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", GameManager.PALETTE.white)
	
	return btn

func _create_stat_bar(label_text: String, value: int, max_value: int, color: Color) -> Control:
	var container := VBoxContainer.new()
	
	if not label_text.is_empty():
		var header := HBoxContainer.new()
		container.add_child(header)
		
		var label := Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 8)
		header.add_child(label)
		
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		
		var value_label := Label.new()
		value_label.text = "%d/%d" % [value, max_value]
		value_label.add_theme_font_size_override("font_size", 7)
		value_label.add_theme_color_override("font_color", GameManager.PALETTE.dark_gray)
		header.add_child(value_label)
	
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = GameManager.PALETTE.dark_gray
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	container.add_child(bar)
	
	return container

func _create_dither_overlay(color: Color, opacity: float) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.color = color
	overlay.modulate.a = opacity
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return overlay

func _create_dialogue_box(dialogues: Array, on_complete: Callable) -> Control:
	var container := PanelContainer.new()
	
	var style := StyleBoxFlat.new()
	style.bg_color = GameManager.PALETTE.cream
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_color = GameManager.PALETTE.black
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_bottom = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	container.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	container.add_child(vbox)
	
	var speaker_label := Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.add_theme_font_size_override("font_size", 10)
	speaker_label.add_theme_color_override("font_color", GameManager.PALETTE.mystic)
	vbox.add_child(speaker_label)
	
	var text_label := Label.new()
	text_label.name = "TextLabel"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(400, 60)
	text_label.add_theme_font_size_override("font_size", 12)
	text_label.add_theme_color_override("font_color", GameManager.PALETTE.black)
	vbox.add_child(text_label)
	
	var footer := HBoxContainer.new()
	vbox.add_child(footer)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	
	var progress_label := Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.add_theme_font_size_override("font_size", 8)
	progress_label.add_theme_color_override("font_color", GameManager.PALETTE.gray)
	footer.add_child(progress_label)
	
	var cursor := Label.new()
	cursor.name = "Cursor"
	cursor.text = " ▼"
	cursor.add_theme_font_size_override("font_size", 8)
	cursor.add_theme_color_override("font_color", GameManager.PALETTE.gray)
	footer.add_child(cursor)
	
	# Blink cursor
	var tween := create_tween().set_loops()
	tween.tween_property(cursor, "modulate:a", 0.0, 0.5)
	tween.tween_property(cursor, "modulate:a", 1.0, 0.5)
	
	# Dialogue state
	var current_index := 0
	var displayed_chars := 0
	var current_text := ""
	var is_typing := false
	
	var update_dialogue := func():
		var dialogue = dialogues[current_index]
		var speaker: String = ""
		var text: String = ""
		
		if dialogue is String:
			text = dialogue
		elif dialogue is Dictionary:
			speaker = dialogue.get("speaker", "")
			text = dialogue.get("text", "")
		
		speaker_label.text = speaker
		speaker_label.visible = not speaker.is_empty()
		current_text = text
		text_label.text = ""
		displayed_chars = 0
		is_typing = true
		progress_label.text = "%d/%d" % [current_index + 1, dialogues.size()]
	
	# Call initial
	update_dialogue.call()
	
	# Typewriter effect
	var type_timer := Timer.new()
	type_timer.wait_time = 0.03
	type_timer.autostart = true
	container.add_child(type_timer)
	
	type_timer.timeout.connect(func():
		if is_typing and displayed_chars < current_text.length():
			displayed_chars += 1
			text_label.text = current_text.substr(0, displayed_chars)
		else:
			is_typing = false
	)
	
	# Click to advance (NO AUTO-ADVANCE - key requirement)
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_typing:
				# Skip typing
				displayed_chars = current_text.length()
				text_label.text = current_text
				is_typing = false
			else:
				# Next dialogue
				current_index += 1
				if current_index >= dialogues.size():
					on_complete.call()
				else:
					update_dialogue.call()
	)
	
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return container
