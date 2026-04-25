## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlay EndScreen — End screen, journal popup
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlayEndScreen

var _ui: MerlinGameUI

func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	var is_victory: bool = ending.get("victory", false)
	if _ui.biome_art_layer and is_instance_valid(_ui.biome_art_layer):
		var tw_forest: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if is_victory:
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", MerlinVisual.CRT_PALETTE["victory_flash"], 1.2)
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", MerlinVisual.CRT_PALETTE["victory_settle"], 0.6)
		else:
			tw_forest.tween_property(_ui.biome_art_layer, "modulate:a", 0.06, 1.5)
		await tw_forest.finished

	if _ui.card_container:
		_ui.card_container.visible = false
	if _ui.options_container:
		_ui.options_container.visible = false

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(MerlinVisual.CRT_PALETTE.bg_panel.r, MerlinVisual.CRT_PALETTE.bg_panel.g, MerlinVisual.CRT_PALETTE.bg_panel.b, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	_ui.add_child(overlay)

	var fade_tw: Tween = _ui.create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.8)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var orn_top: Label = Label.new()
	orn_top.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_top.add_theme_font_size_override("font_size", 14)
	orn_top.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_top)

	var ending_data: Dictionary = ending.get("ending", {})
	var title: Label = Label.new()
	title.text = ending_data.get("title", "Fin")
	if _ui.title_font:
		title.add_theme_font_override("font", _ui.title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ending.get("victory", false):
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	else:
		title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	vbox.add_child(title)

	if ending_data.has("text"):
		var text: Label = Label.new()
		text.text = ending_data.get("text", "")
		if _ui.body_font:
			text.add_theme_font_override("font", _ui.body_font)
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	var score_lbl: Label = Label.new()
	score_lbl.text = "Gloire: %d" % ending.get("score", 0)
	if _ui.title_font:
		score_lbl.add_theme_font_override("font", _ui.title_font)
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(score_lbl)

	if ending.get("life_depleted", false):
		var life_lbl: Label = Label.new()
		life_lbl.text = "Essences de vie epuisees"
		if _ui.body_font:
			life_lbl.add_theme_font_override("font", _ui.body_font)
		life_lbl.add_theme_font_size_override("font_size", 14)
		life_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(life_lbl)

	var stats_lbl: Label = Label.new()
	stats_lbl.text = "Cartes: %d  \u2502  Jours: %d" % [ending.get("cards_played", 0), ending.get("days_survived", 1)]
	if _ui.body_font:
		stats_lbl.add_theme_font_override("font", _ui.body_font)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	_build_end_screen_story_log(vbox, ending)
	_build_end_screen_rewards(vbox, ending)

	var orn_bot: Label = Label.new()
	orn_bot.text = "\u2500\u2500\u2500 # \u2500\u2500\u2500"
	orn_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_bot.add_theme_font_size_override("font_size", 14)
	orn_bot.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	vbox.add_child(orn_bot)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_hub: Button = Button.new()
	btn_hub.text = "Retour au Hub"
	btn_hub.custom_minimum_size = Vector2(200, 50)
	btn_hub.pressed.connect(func(): PixelTransition.transition_to("res://scenes/MerlinCabinHub.tscn"))
	btn_box.add_child(btn_hub)

	var btn_new: Button = Button.new()
	btn_new.text = "Nouvelle Aventure"
	btn_new.custom_minimum_size = Vector2(200, 50)
	btn_new.pressed.connect(func(): PixelTransition.transition_to("res://scenes/BroceliandeForest3D.tscn"))
	btn_box.add_child(btn_new)


func _build_end_screen_story_log(vbox: VBoxContainer, ending: Dictionary) -> void:
	var story_log: Array = ending.get("story_log", [])
	if story_log.size() <= 0:
		return

	var path_title: Label = Label.new()
	path_title.text = "Ton chemin"
	if _ui.title_font:
		path_title.add_theme_font_override("font", _ui.title_font)
	path_title.add_theme_font_size_override("font_size", 16)
	path_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	path_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(path_title)

	var last_entries: Array = story_log.slice(-5) if story_log.size() > 5 else story_log
	var path_parts: PackedStringArray = []
	for entry in last_entries:
		var choice_text: String = str(entry.get("choice", ""))
		if not choice_text.is_empty():
			path_parts.append(choice_text)
	if path_parts.size() > 0:
		var path_lbl: Label = Label.new()
		path_lbl.text = " > ".join(path_parts)
		if _ui.body_font:
			path_lbl.add_theme_font_override("font", _ui.body_font)
		path_lbl.add_theme_font_size_override("font_size", 12)
		path_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		path_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		path_lbl.custom_minimum_size.x = 400
		vbox.add_child(path_lbl)


func _build_end_screen_rewards(vbox: VBoxContainer, ending: Dictionary) -> void:
	var rewards: Dictionary = ending.get("rewards", {})
	if rewards.size() <= 0:
		return

	if rewards.get("partial", false):
		var partial_lbl: Label = Label.new()
		partial_lbl.text = "Run incomplete \u2014 recompenses x0.25"
		if _ui.body_font:
			partial_lbl.add_theme_font_override("font", _ui.body_font)
		partial_lbl.add_theme_font_size_override("font_size", 14)
		partial_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		partial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(partial_lbl)

	var rewards_title: Label = Label.new()
	rewards_title.text = "Recompenses obtenues"
	if _ui.title_font:
		rewards_title.add_theme_font_override("font", _ui.title_font)
	rewards_title.add_theme_font_size_override("font_size", 18)
	rewards_title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rewards_title)

	var ess: Dictionary = rewards.get("essence", {})
	if ess.size() > 0:
		var parts: PackedStringArray = []
		for elem in ess:
			if int(ess[elem]) > 0:
				parts.append("%s +%d" % [str(elem).left(4), int(ess[elem])])
		if parts.size() > 0:
			var ess_lbl: Label = Label.new()
			ess_lbl.text = "Essences: " + " | ".join(parts)
			if _ui.body_font:
				ess_lbl.add_theme_font_override("font", _ui.body_font)
			ess_lbl.add_theme_font_size_override("font_size", 13)
			ess_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
			ess_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			ess_lbl.custom_minimum_size.x = 400
			vbox.add_child(ess_lbl)

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
		var cur_lbl: Label = Label.new()
		cur_lbl.text = " | ".join(currency_parts)
		if _ui.body_font:
			cur_lbl.add_theme_font_override("font", _ui.body_font)
		cur_lbl.add_theme_font_size_override("font_size", 14)
		cur_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cur_lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# JOURNAL POPUP
# ═══════════════════════════════════════════════════════════════════════════════

func show_journal_popup(run_summaries: Array[Dictionary]) -> void:
	if run_summaries.is_empty():
		return

	var popup: ColorRect = ColorRect.new()
	popup.name = "JournalPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.color = Color(MerlinVisual.CRT_PALETTE.bg_deep.r, MerlinVisual.CRT_PALETTE.bg_deep.g, MerlinVisual.CRT_PALETTE.bg_deep.b, 0.92)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(popup)

	var title: Label = Label.new()
	title.text = "Journal des Vies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 30.0
	title.offset_left = -200.0
	title.offset_right = 200.0
	var title_font_res: Font = MerlinVisual.get_font("title")
	if title_font_res:
		title.add_theme_font_override("font", title_font_res)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	popup.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 70.0
	scroll.offset_bottom = -60.0
	scroll.offset_left = 40.0
	scroll.offset_right = -40.0
	popup.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var body_font_res: Font = MerlinVisual.get_font("body")
	var entry_color: Color = MerlinVisual.CRT_PALETTE.phosphor
	var dim_color: Color = MerlinVisual.CRT_PALETTE.phosphor_dim

	for i in range(run_summaries.size()):
		var run: Dictionary = run_summaries[i]
		var entry: RichTextLabel = RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.scroll_active = false
		if body_font_res:
			entry.add_theme_font_override("normal_font", body_font_res)
		entry.add_theme_font_size_override("normal_font_size", 13)
		entry.add_theme_color_override("default_color", entry_color)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var ending_str: String = str(run.get("ending", "inconnu"))
		var cards: int = int(run.get("cards_played", 0))
		var dom: String = str(run.get("dominant_aspect", ""))
		var run_style: String = str(run.get("player_style", ""))
		var life: int = int(run.get("life_final", 0))
		var events: String = str(run.get("notable_events", ""))

		var text: String = "[b]Vie %d[/b] -- %s\n" % [i + 1, ending_str]
		if cards > 0:
			text += "Cartes: %d | " % cards
		if not dom.is_empty():
			text += "Aspect: %s | " % dom
		if not run_style.is_empty():
			text += "Style: %s | " % run_style
		if life > 0:
			text += "Vie: %d" % life
		if not events.is_empty():
			text += "\n%s" % events
		entry.text = text
		vbox.add_child(entry)

		if i < run_summaries.size() - 1:
			var sep: HSeparator = HSeparator.new()
			sep.add_theme_color_override("separator", dim_color)
			vbox.add_child(sep)

	var close_btn: Button = Button.new()
	close_btn.text = "Fermer"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_bottom = -20.0
	close_btn.offset_top = -50.0
	close_btn.offset_left = -60.0
	close_btn.offset_right = 60.0
	if title_font_res:
		close_btn.add_theme_font_override("font", title_font_res)
	close_btn.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	close_btn.custom_minimum_size = Vector2(120, 48)
	MerlinVisual.apply_button_theme(close_btn)
	popup.add_child(close_btn)

	popup.modulate.a = 0.0
	var tw: Tween = _ui.create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.3)

	close_btn.pressed.connect(func():
		var tw_out: Tween = _ui.create_tween()
		tw_out.tween_property(popup, "modulate:a", 0.0, 0.2)
		tw_out.tween_callback(popup.queue_free)
	)


