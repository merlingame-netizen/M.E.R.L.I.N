## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlay Effects — Card outcome animations, life delta, milestone, progressive
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlayEffects

var _ui: MerlinGameUI


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func show_reaction_text(text: String, outcome: String) -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		return
	flash_biome_for_outcome(outcome)
	_ui.switch_body_to_text()
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	_ui.card_text.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	_ui.card_text.visible_characters = -1
	_ui.card_text.modulate.a = 1.0


func show_result_text_transition(result_text: String, outcome: String) -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		return
	flash_biome_for_outcome(outcome)
	_ui.switch_body_to_text()
	var tw: Tween = _ui.create_tween()
	tw.tween_property(_ui.card_text, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not _ui.is_inside_tree():
		return
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		match outcome:
			"critical_success":
				_ui.card_speaker.text = "Reussite critique !"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
			"success":
				_ui.card_speaker.text = "Reussite"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
			"critical_failure":
				_ui.card_speaker.text = "Echec critique..."
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
			_:
				_ui.card_speaker.text = "Echec"
				_ui.card_speaker.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
	var color: Color = MerlinVisual.CRT_PALETTE.success if outcome.contains("success") else MerlinVisual.CRT_PALETTE.danger
	var bbcode_text: String = "[color=#%s]%s[/color]" % [color.to_html(false), result_text]
	_ui.card_text.modulate.a = 1.0
	_ui._narrator_module.typewriter_card_text(bbcode_text)


func flash_biome_for_outcome(outcome: String) -> void:
	_ui._biome_art.flash_biome_for_outcome(outcome)


func show_critical_badge() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	var base_style: StyleBox = _ui.card_panel.get_theme_stylebox("panel")
	if not base_style:
		return
	var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	if style:
		style.border_color = MerlinVisual.CRT_PALETTE.souffle_full
		style.set_border_width_all(3)
		_ui.card_panel.add_theme_stylebox_override("panel", style)
	_ui._critical_badge_tween = _ui.create_tween().set_loops(0)
	_ui._critical_badge_tween.tween_property(_ui.card_panel, "modulate", Color(1.15, 1.1, 0.9), 0.3)
	_ui._critical_badge_tween.tween_property(_ui.card_panel, "modulate", Color.WHITE, 0.3)


func show_biome_passive(passive: Dictionary) -> void:
	var text: String = str(passive.get("text", "Force du biome..."))
	var notif: Label = Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notif.add_theme_font_size_override("font_size", 14)
	notif.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.success)
	if _ui.body_font:
		notif.add_theme_font_override("font", _ui.body_font)
	notif.modulate.a = 0.0
	_ui.add_child(notif)
	var tw: Tween = _ui.create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(notif, "modulate:a", 0.0, 0.3)
	tw.tween_callback(notif.queue_free)


func animate_card_outcome(outcome: String) -> void:
	_ui._card_display.disable_card_3d()
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	match outcome:
		"critical_success":
			var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.08, 1.08), 0.2)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"success":
			var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.04, 1.04), 0.15)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.2)
		"failure":
			var origin_x: float = _ui._card_base_pos.x if _ui._card_base_pos != Vector2.ZERO else _ui.card_panel.position.x
			var tw: Tween = _ui.create_tween()
			for _i in range(3):
				tw.tween_property(_ui.card_panel, "position:x", origin_x + 8, 0.05).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_ui.card_panel, "position:x", origin_x - 8, 0.05).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_ui.card_panel, "position:x", origin_x, 0.05)
		"critical_failure":
			var origin_x: float = _ui._card_base_pos.x if _ui._card_base_pos != Vector2.ZERO else _ui.card_panel.position.x
			var tw: Tween = _ui.create_tween()
			for _i in range(5):
				tw.tween_property(_ui.card_panel, "position:x", origin_x + 14, 0.04).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_ui.card_panel, "position:x", origin_x - 14, 0.04).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_ui.card_panel, "position:x", origin_x, 0.04)
			tw.tween_property(_ui.card_panel, "scale", Vector2(0.97, 0.97), 0.1)
			tw.tween_property(_ui.card_panel, "scale", Vector2(1.0, 1.0), 0.15)


func show_milestone_popup(title_text: String, desc_text: String) -> void:
	if _ui.biome_art_layer and is_instance_valid(_ui.biome_art_layer):
		var gold_tint: Color = MerlinVisual.CRT_PALETTE["milestone_gold"]
		var tw_forest: Tween = _ui.create_tween()
		for _i in range(3):
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", gold_tint, 0.2).set_trans(Tween.TRANS_SINE)
			tw_forest.tween_property(_ui.biome_art_layer, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		_ui.card_speaker.text = title_text
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		_ui.card_speaker.add_theme_color_override("font_color", amber)
		_ui.card_speaker.visible = true
	if _ui.card_text and is_instance_valid(_ui.card_text):
		var amber: Color = MerlinVisual.CRT_PALETTE.get("amber_bright", Color(0.85, 0.65, 0.13))
		var bbcode: String = "[color=#%s]%s[/color]" % [amber.to_html(false), desc_text]
		_ui.card_text.text = bbcode
		_ui.card_text.modulate.a = 1.0


func show_life_delta(delta: int) -> void:
	if delta == 0:
		return
	var is_damage: bool = delta < 0
	var color: Color = MerlinVisual.CRT_PALETTE.danger if is_damage else MerlinVisual.CRT_PALETTE.success
	# Stage 1: Screen flash
	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 30
	_ui.add_child(flash)
	var tw_flash: Tween = _ui.create_tween()
	tw_flash.tween_property(flash, "color:a", 0.25 if is_damage else 0.15, 0.08)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.15)
	tw_flash.tween_callback(flash.queue_free)
	# Stage 2: Camera shake (damage only)
	if is_damage and _ui.main_vbox and is_instance_valid(_ui.main_vbox):
		var base_pos: Vector2 = _ui.main_vbox.position
		var shake_tw: Tween = _ui.create_tween()
		for i in range(4):
			var intensity: float = 4.0 * (1.0 - float(i) / 4.0)
			shake_tw.tween_property(_ui.main_vbox, "position:x", base_pos.x + intensity, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:y", base_pos.y - intensity * 0.5, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:x", base_pos.x - intensity, 0.035)
			shake_tw.tween_property(_ui.main_vbox, "position:y", base_pos.y + intensity * 0.5, 0.035)
		shake_tw.tween_property(_ui.main_vbox, "position", base_pos, 0.04)
	# Stage 3: Zoom life bar
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		_ui.life_panel.pivot_offset = _ui.life_panel.size * 0.5
		var tw_zoom: Tween = _ui.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_zoom.tween_property(_ui.life_panel, "scale", Vector2(1.6, 1.6), 0.2)
		tw_zoom.tween_property(_ui.life_panel, "scale", Vector2(1.0, 1.0), 0.4)
	# Stage 4: Smooth bar value tween
	if _ui._life_bar and is_instance_valid(_ui._life_bar):
		var old_val: float = _ui._life_bar.value
		var new_val: float = clampf(old_val + float(delta), 0.0, float(MerlinConstants.LIFE_ESSENCE_MAX))
		var tw_bar: Tween = _ui.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_bar.tween_property(_ui._life_bar, "value", new_val, 0.5)
	# Stage 5: BIG floating number
	var label: Label = Label.new()
	label.text = "+%d" % delta if delta > 0 else "%d" % delta
	if _ui.title_font:
		label.add_theme_font_override("font", _ui.title_font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 25
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		var bar_global: Vector2 = _ui.life_panel.global_position
		label.position = Vector2(bar_global.x + _ui.life_panel.size.x * 0.5 - 30, bar_global.y - 10)
	else:
		label.position = Vector2(_ui.size.x * 0.5 - 40, _ui.size.y * 0.15)
	label.pivot_offset = Vector2(30, 24)
	label.scale = Vector2(0.3, 0.3)
	_ui.add_child(label)
	var tw_num: Tween = _ui.create_tween()
	tw_num.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_num.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	tw_num.tween_property(label, "position:y", label.position.y - 80.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw_num.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw_num.tween_callback(label.queue_free)


func show_progressive_indicators() -> void:
	var essence_panel: Control = _ui._essence_counter.get_parent() if _ui._essence_counter and is_instance_valid(_ui._essence_counter) else null
	if _ui._top_status_bar and is_instance_valid(_ui._top_status_bar):
		_ui._top_status_bar.modulate.a = 1.0
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		_ui.life_panel.modulate.a = 0.0
	if _ui.souffle_panel and is_instance_valid(_ui.souffle_panel):
		_ui.souffle_panel.modulate.a = 0.0
	if essence_panel and is_instance_valid(essence_panel):
		essence_panel.modulate.a = 0.0
	await _ui.get_tree().create_timer(0.15).timeout
	if not _ui.is_inside_tree():
		return
	var pca: Node = _ui.get_node_or_null("/root/PixelContentAnimator")
	if _ui.life_panel and is_instance_valid(_ui.life_panel):
		if pca:
			pca.reveal(_ui.life_panel, {"duration": 0.3, "block_size": 6})
			await _ui.get_tree().create_timer(0.32).timeout
		else:
			_ui.life_panel.modulate.a = 1.0
	if _ui.souffle_panel and is_instance_valid(_ui.souffle_panel):
		SFXManager.play("ogham_chime")
		if pca:
			pca.reveal(_ui.souffle_panel, {"duration": 0.35, "block_size": 6})
			await _ui.get_tree().create_timer(0.38).timeout
		else:
			_ui.souffle_panel.modulate.a = 1.0
	if essence_panel and is_instance_valid(essence_panel):
		if pca:
			pca.reveal(essence_panel, {"duration": 0.28, "block_size": 6})
			await _ui.get_tree().create_timer(0.3).timeout
		else:
			essence_panel.modulate.a = 1.0
