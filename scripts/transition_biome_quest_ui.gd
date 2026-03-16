## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Quest UI Module
## ═══════════════════════════════════════════════════════════════════════════════
## Quest preparation UI: dice minigame, faveur reward, quest button.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeQuestUI
extends RefCounted


func show_de_du_destin_minigame(vs: Vector2, host: Control, biome_key: String, cards_generated_ref: Array) -> Dictionary:
	## Mini-jeu inline "De du Destin" : lancer un D20 pour gagner des Faveurs.
	## cards_generated_ref is [bool] array used as reference wrapper.
	const PANEL_W := 300.0
	const PANEL_H := 220.0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.position = (vs - Vector2(PANEL_W, PANEL_H)) / 2.0
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	panel_style.border_color = MerlinVisual.CRT_PALETTE.amber
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	host.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Titre
	var title_lbl := Label.new()
	title_lbl.text = "Le De du Destin"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	title_lbl.add_theme_font_size_override("font_size", 18)
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		title_lbl.add_theme_font_override("font", title_font)
	vbox.add_child(title_lbl)

	# Sous-titre
	var sub_lbl := Label.new()
	sub_lbl.text = "Lancez en attendant que Merlin\ntisse votre scenario..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	sub_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(sub_lbl)

	# Affichage de
	var die_lbl := Label.new()
	die_lbl.text = "[ ? ]"
	die_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	die_lbl.add_theme_font_size_override("font_size", 44)
	vbox.add_child(die_lbl)

	# Bouton Lancer
	var roll_btn := Button.new()
	roll_btn.text = "Lancer le De"
	roll_btn.custom_minimum_size = Vector2(180, 40)
	roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = MerlinVisual.CRT_PALETTE.amber
	btn_style.set_corner_radius_all(5)
	btn_style.set_content_margin_all(10)
	roll_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = MerlinVisual.CRT_PALETTE.amber.lightened(0.15)
	roll_btn.add_theme_stylebox_override("hover", btn_hover)
	roll_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
	roll_btn.add_theme_font_size_override("font_size", 15)
	vbox.add_child(roll_btn)

	# Fade in
	var fade_in := host.create_tween()
	fade_in.tween_property(panel, "modulate:a", 1.0, 0.3)
	await fade_in.finished

	# Attendre clic (ou fin generation si ultra-rapide)
	var clicked: Array = [false]
	var scene_finished_ref: Array = [false]
	roll_btn.pressed.connect(func(): clicked[0] = true, CONNECT_ONE_SHOT)
	while not clicked[0] and not scene_finished_ref[0] and not cards_generated_ref[0]:
		if not host.is_inside_tree():
			break
		await host.get_tree().process_frame

	roll_btn.disabled = true

	# Animation spin
	var die_rng := RandomNumberGenerator.new()
	die_rng.randomize()
	var final_roll: int = die_rng.randi_range(1, 20)
	for spin_i in range(16):
		die_lbl.text = "[ %d ]" % die_rng.randi_range(1, 20)
		var delay: float = 0.04 + spin_i * 0.012
		if host.is_inside_tree():
			await host.get_tree().create_timer(maxf(0.01, delay)).timeout
	die_lbl.text = "[ %d ]" % final_roll

	# Couleur resultat
	var result_color: Color = MerlinVisual.CRT_PALETTE.amber if final_roll >= 10 else MerlinVisual.CRT_PALETTE.phosphor_dim
	die_lbl.add_theme_color_override("font_color", result_color)
	SFXManager.play("magic_reveal")

	# Calcul Faveurs
	var faveurs: int
	var result_text: String
	if final_roll >= 17:
		faveurs = MerlinConstants.FAVEURS_PER_MINIGAME_WIN
		result_text = "Reussite Critique !"
	elif final_roll >= 10:
		faveurs = 2
		result_text = "Succes !"
	else:
		faveurs = MerlinConstants.FAVEURS_PER_MINIGAME_PLAY
		result_text = "Le destin s'eveille..."
	sub_lbl.text = result_text
	sub_lbl.add_theme_color_override("font_color", result_color)

	if host.is_inside_tree():
		await host.get_tree().create_timer(1.0).timeout

	# Fade out
	var fade_out := host.create_tween()
	fade_out.tween_property(panel, "modulate:a", 0.0, 0.3)
	await fade_out.finished
	panel.queue_free()

	return {"roll": final_roll, "faveurs": faveurs}


func show_faveur_reward(vs: Vector2, amount: int, host: Control) -> void:
	var lbl := Label.new()
	lbl.text = "+%d Faveur%s" % [amount, "s" if amount > 1 else ""]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	lbl.add_theme_font_size_override("font_size", 26)
	var reward_font: Font = MerlinVisual.get_font("title")
	if reward_font:
		lbl.add_theme_font_override("font", reward_font)
	lbl.modulate.a = 0.0
	lbl.size = Vector2(280, 50)
	lbl.position = Vector2((vs.x - 280.0) / 2.0, vs.y * 0.38)
	host.add_child(lbl)

	var tw := host.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.7)
	await tw.finished
	lbl.queue_free()


func create_quest_button(vs: Vector2, biome_key: String) -> Button:
	var btn := Button.new()
	btn.text = "Partir en quete"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.position = Vector2(vs.x / 2.0 - 120, vs.y * 0.86)
	btn.pivot_offset = Vector2(120, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE.amber
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = MerlinVisual.CRT_PALETTE.amber.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = MerlinVisual.CRT_PALETTE.amber.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
	btn.add_theme_font_size_override("font_size", 18)
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		btn.add_theme_font_override("font", title_font)
	btn.modulate.a = 0.0
	return btn
